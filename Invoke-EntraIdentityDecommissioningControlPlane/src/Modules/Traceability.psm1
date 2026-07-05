#Requires -Version 5.1

#Requires -Version 5.1

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function New-DecomTraceabilityModel {
    <#
    .SYNOPSIS
    Builds an end-to-end traceability model linking Findings to WhatIf actions,
    Approval actions, and Execution Evidence.
    .DESCRIPTION
    Joins Findings -> WhatIf (by FindingId) -> Approval (by ActionId) -> Execution
    (by ActionId) to produce a row-per-finding trace with TraceStatus classification.
    .PARAMETER Findings
    Array of assessment finding objects.
    .PARAMETER WhatIfActions
    Array of WhatIf action objects.
    .PARAMETER ApprovalActions
    Array of approval manifest action objects.
    .PARAMETER ExecutionResults
    Array of execution evidence/result objects.
    .PARAMETER RunId
    Optional run identifier for correlation.
    .RETURNS
    A PSCustomObject containing SchemaVersion, ToolVersion, RunId, GeneratedUtc,
    Rows, and Summary.
    #>
    param(
        [pscustomobject[]]$Findings         = @(),
        [pscustomobject[]]$WhatIfActions    = @(),
        [pscustomobject[]]$ApprovalActions  = @(),
        [pscustomobject[]]$ExecutionResults = @(),
        [string]$RunId = ''
    )

    $model = [pscustomobject]@{
        SchemaVersion = '3.6'
        ToolVersion = Get-DecomToolVersion
        RunId         = $RunId
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Rows          = @()
        Summary       = [ordered]@{
            Total            = 0
            FindingOnly      = 0
            WhatIfGenerated  = 0
            Approved         = 0
            Executed         = 0
            Skipped          = 0
            Blocked          = 0
            Failed           = 0
            EvidenceMissing  = 0
            TraceGap         = 0
        }
    }

    # Build lookups
    # WhatIf: by FindingId (one finding may have multiple WhatIf actions)
    $whatIfByFindingId = @{}
    foreach ($wa in $WhatIfActions) {
        if ($null -eq $wa) { continue }
        $fid = [string]$wa.FindingId
        if (-not $whatIfByFindingId.ContainsKey($fid)) {
            $whatIfByFindingId[$fid] = [System.Collections.Generic.List[object]]::new()
        }
        $whatIfByFindingId[$fid].Add($wa)
    }

    # Approval: by ActionId
    $approvalByActionId = @{}
    foreach ($aa in $ApprovalActions) {
        if ($null -eq $aa -or -not $aa.ActionId) { continue }
        $approvalByActionId[[string]$aa.ActionId] = $aa
    }

    # Execution: by ActionId
    $execByActionId = @{}
    foreach ($ex in $ExecutionResults) {
        if ($null -eq $ex -or -not $ex.ActionId) { continue }
        $execByActionId[[string]$ex.ActionId] = $ex
    }

    foreach ($finding in $Findings) {
        if ($null -eq $finding) { continue }

        $findingId         = [string]$finding.FindingId
        $findingInstanceId = [string]$finding.FindingInstanceId
        $severity          = [string]$finding.Severity
        $riskScore         = [string]$finding.RiskScore
        $objectId          = [string]$finding.ObjectId
        $displayName       = [string]$finding.DisplayName

        $matchedWhatIf = $whatIfByFindingId[$findingId]

        if ($null -eq $matchedWhatIf -or $matchedWhatIf.Count -eq 0) {
            # FindingOnly — no WhatIf action exists
            $row = _New-TraceRow `
                -FindingId $findingId `
                -FindingInstanceId $findingInstanceId `
                -Severity $severity `
                -RiskScore $riskScore `
                -ObjectId $objectId `
                -DisplayName $displayName `
                -TraceStatus 'FindingOnly' `
                -TraceGapReason ''

            $model.Rows          += $row
            $model.Summary.Total++
            $model.Summary.FindingOnly++
        } else {
            # One row per WhatIf action associated with this finding
            foreach ($wa in $matchedWhatIf) {
                $actionId   = [string]$wa.ActionId
                $actionType = [string]$wa.ActionType

                $aa = $approvalByActionId[$actionId]
                $ex = $execByActionId[$actionId]

                $approvalStatus       = 'NotRequested'
                $approvedBy           = ''
                $approvalTicket       = ''
                $approvalManifestHash = ''
                $executionOutcome     = 'NotExecuted'
                $executedUtc          = ''
                $graphWriteCmdlet     = ''
                $postWriteStatus      = ''
                $evidenceFile         = ''
                $rollbackGuidance     = ''
                $traceStatus          = 'WhatIfGenerated'
                $traceGapReason       = ''

                if ($null -ne $aa) {
                    $approvalStatus       = [string]$aa.ApprovalStatus
                    $approvedBy           = [string]$aa.ApprovedBy
                    $approvalTicket       = [string]$aa.ApprovalTicket
                    $approvalManifestHash = [string]$aa.ApprovalManifestHash

                    $traceStatus = switch ($approvalStatus) {
                        'Approved' { 'Approved' }
                        'Rejected' { 'Rejected' }
                        default    { 'WhatIfGenerated' }
                    }
                }

                if ($null -ne $ex) {
                    $executionOutcome  = [string]$ex.ExecutionOutcome
                    $executedUtc       = [string]$ex.ExecutedUtc
                    $graphWriteCmdlet  = [string]$ex.GraphWriteCmdlet
                    $postWriteStatus   = [string]$ex.PostWriteRequeryStatus
                    $evidenceFile      = [string]$ex.EvidenceFile
                    $rollbackGuidance  = [string]$ex.RollbackGuidance

                    $traceStatus = switch ($executionOutcome) {
                        'Executed'      {
                            if (-not $evidenceFile) {
                                'EvidenceMissing'
                            } else {
                                'Executed'
                            }
                        }
                        'Skipped'       { 'Skipped' }
                        'Blocked'       { 'Blocked' }
                        'Failed'        { 'Failed' }
                        'PartialFailed' { 'PartialFailed' }
                        default         {
                            # Execution record exists but outcome is unknown
                            $traceGapReason = "Unrecognised ExecutionOutcome: '$executionOutcome'"
                            'TraceGap'
                        }
                    }
                }

                # Consistency check: Approved but no execution record and outcome not expected
                if ($traceStatus -eq 'Approved' -and ($null -eq $ex -or $executionOutcome -eq 'NotExecuted')) {
                    $traceStatus    = 'TraceGap'
                    $traceGapReason = 'Approval record present but execution outcome is NotExecuted.'
                }

                $targetObjectIds = @()
                if ($null -ne $wa.TargetObjectIds) {
                    $targetObjectIds = @($wa.TargetObjectIds)
                }

                $row = _New-TraceRow `
                    -FindingId $findingId `
                    -FindingInstanceId $findingInstanceId `
                    -Severity $severity `
                    -RiskScore $riskScore `
                    -ObjectId $objectId `
                    -DisplayName $displayName `
                    -ActionId $actionId `
                    -ActionType $actionType `
                    -TargetObjectIds $targetObjectIds `
                    -WhatIfRunId ([string]$wa.WhatIfRunId) `
                    -ApprovalStatus $approvalStatus `
                    -ApprovedBy $approvedBy `
                    -ApprovalTicket $approvalTicket `
                    -ApprovalManifestHash $approvalManifestHash `
                    -ExecutionOutcome $executionOutcome `
                    -ExecutedUtc $executedUtc `
                    -GraphWriteCmdlet $graphWriteCmdlet `
                    -PostWriteRequeryStatus $postWriteStatus `
                    -EvidenceFile $evidenceFile `
                    -RollbackGuidance $rollbackGuidance `
                    -TraceStatus $traceStatus `
                    -TraceGapReason $traceGapReason

                $model.Rows += $row
                $model.Summary.Total++

                switch ($traceStatus) {
                    'FindingOnly'     { $model.Summary.FindingOnly++ }
                    'WhatIfGenerated' { $model.Summary.WhatIfGenerated++ }
                    'Approved'        { $model.Summary.Approved++ }
                    'Rejected'        { /* no dedicated counter */ }
                    'Executed'        { $model.Summary.Executed++ }
                    'Skipped'         { $model.Summary.Skipped++ }
                    'Blocked'         { $model.Summary.Blocked++ }
                    'Failed'          { $model.Summary.Failed++ }
                    'PartialFailed'   { $model.Summary.Failed++ }
                    'EvidenceMissing' { $model.Summary.EvidenceMissing++ }
                    'TraceGap'        { $model.Summary.TraceGap++ }
                }
            }
        }
    }

    return $model
}

function _New-TraceRow {
    param(
        [string]$FindingId            = '',
        [string]$FindingInstanceId    = '',
        [string]$Severity             = '',
        [string]$RiskScore            = '',
        [string]$ObjectId             = '',
        [string]$DisplayName          = '',
        [string]$ActionId             = '',
        [string]$ActionType           = '',
        [object[]]$TargetObjectIds    = @(),
        [string]$WhatIfRunId          = '',
        [string]$ApprovalStatus       = 'NotRequested',
        [string]$ApprovedBy           = '',
        [string]$ApprovalTicket       = '',
        [string]$ApprovalManifestHash = '',
        [string]$ExecutionOutcome     = 'NotExecuted',
        [string]$ExecutedUtc          = '',
        [string]$GraphWriteCmdlet     = '',
        [string]$PostWriteRequeryStatus = '',
        [string]$EvidenceFile         = '',
        [string]$RollbackGuidance     = '',
        [string]$TraceStatus          = 'FindingOnly',
        [string]$TraceGapReason       = ''
    )

    return [pscustomobject]@{
        FindingId             = $FindingId
        FindingInstanceId     = $FindingInstanceId
        Severity              = $Severity
        RiskScore             = $RiskScore
        ObjectId              = $ObjectId
        DisplayName           = $DisplayName
        ActionId              = $ActionId
        ActionType            = $ActionType
        TargetObjectIds       = $TargetObjectIds
        WhatIfRunId           = $WhatIfRunId
        ApprovalStatus        = $ApprovalStatus
        ApprovedBy            = $ApprovedBy
        ApprovalTicket        = $ApprovalTicket
        ApprovalManifestHash  = $ApprovalManifestHash
        ExecutionOutcome      = $ExecutionOutcome
        ExecutedUtc           = $ExecutedUtc
        GraphWriteCmdlet      = $GraphWriteCmdlet
        PostWriteRequeryStatus = $PostWriteRequeryStatus
        EvidenceFile          = $EvidenceFile
        RollbackGuidance      = $RollbackGuidance
        TraceStatus           = $TraceStatus
        TraceGapReason        = $TraceGapReason
    }
}

function Export-DecomTraceabilityReportJson {
    <#
    .SYNOPSIS
    Exports a traceability model to a JSON file.
    .PARAMETER Model
    The traceability model returned by New-DecomTraceabilityModel.
    .PARAMETER Path
    Full path to the output JSON file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $json = $Model | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
}

function Export-DecomTraceabilityReportCsv {
    <#
    .SYNOPSIS
    Exports traceability rows to a CSV file.
    .PARAMETER Model
    The traceability model returned by New-DecomTraceabilityModel.
    .PARAMETER Path
    Full path to the output CSV file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $rows = @($Model.Rows)

    if ($rows.Count -eq 0) {
        $header = 'FindingId,FindingInstanceId,Severity,RiskScore,ObjectId,DisplayName,ActionId,ActionType,WhatIfRunId,ApprovalStatus,ApprovedBy,ApprovalTicket,ApprovalManifestHash,ExecutionOutcome,ExecutedUtc,GraphWriteCmdlet,PostWriteRequeryStatus,EvidenceFile,RollbackGuidance,TraceStatus,TraceGapReason'
        [System.IO.File]::WriteAllText($Path, $header + "`n", [System.Text.Encoding]::UTF8)
        return
    }

    # Build flat rows (TargetObjectIds joined as semicolons)
    $flatRows = $rows | ForEach-Object {
        [pscustomobject]@{
            FindingId             = $_.FindingId
            FindingInstanceId     = $_.FindingInstanceId
            Severity              = $_.Severity
            RiskScore             = $_.RiskScore
            ObjectId              = $_.ObjectId
            DisplayName           = $_.DisplayName
            ActionId              = $_.ActionId
            ActionType            = $_.ActionType
            TargetObjectIds       = ($_.TargetObjectIds -join ';')
            WhatIfRunId           = $_.WhatIfRunId
            ApprovalStatus        = $_.ApprovalStatus
            ApprovedBy            = $_.ApprovedBy
            ApprovalTicket        = $_.ApprovalTicket
            ApprovalManifestHash  = $_.ApprovalManifestHash
            ExecutionOutcome      = $_.ExecutionOutcome
            ExecutedUtc           = $_.ExecutedUtc
            GraphWriteCmdlet      = $_.GraphWriteCmdlet
            PostWriteRequeryStatus = $_.PostWriteRequeryStatus
            EvidenceFile          = $_.EvidenceFile
            RollbackGuidance      = $_.RollbackGuidance
            TraceStatus           = $_.TraceStatus
            TraceGapReason        = $_.TraceGapReason
        }
    }

    $csv = $flatRows | ConvertTo-Csv -NoTypeInformation
    [System.IO.File]::WriteAllText($Path, ($csv -join "`n"), [System.Text.Encoding]::UTF8)
}

function Export-DecomTraceabilityReportHtml {
    <#
    .SYNOPSIS
    Exports a traceability model to an HTML file.
    .PARAMETER Model
    The traceability model returned by New-DecomTraceabilityModel.
    .PARAMETER Path
    Full path to the output HTML file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $rows = [System.Text.StringBuilder]::new()
    foreach ($row in $Model.Rows) {
        $statusColor = switch ([string]$row.TraceStatus) {
            'Executed'        { '#2e7d32' }
            'EvidenceMissing' { '#c62828' }
            'TraceGap'        { '#c62828' }
            'Failed'          { '#c62828' }
            'Blocked'         { '#e65100' }
            'Skipped'         { '#e65100' }
            'Approved'        { '#1565c0' }
            default           { '#757575' }
        }
        $fid     = [System.Web.HttpUtility]::HtmlEncode([string]$row.FindingId)
        $sev     = [System.Web.HttpUtility]::HtmlEncode([string]$row.Severity)
        $obj     = [System.Web.HttpUtility]::HtmlEncode([string]$row.DisplayName)
        $aid     = [System.Web.HttpUtility]::HtmlEncode([string]$row.ActionId)
        $atype   = [System.Web.HttpUtility]::HtmlEncode([string]$row.ActionType)
        $appr    = [System.Web.HttpUtility]::HtmlEncode([string]$row.ApprovalStatus)
        $exec    = [System.Web.HttpUtility]::HtmlEncode([string]$row.ExecutionOutcome)
        $ts      = [System.Web.HttpUtility]::HtmlEncode([string]$row.TraceStatus)
        $tgr     = [System.Web.HttpUtility]::HtmlEncode([string]$row.TraceGapReason)
        [void]$rows.Append("<tr><td>$fid</td><td>$sev</td><td>$obj</td><td>$aid</td><td>$atype</td><td>$appr</td><td>$exec</td><td style='color:$statusColor;font-weight:bold'>$ts</td><td>$tgr</td></tr>`n")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<title>Traceability Report</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;background:#fafafa;color:#212121}
h1{font-size:1.6em;margin-bottom:8px}
h2{font-size:1.2em;margin-top:24px}
table{border-collapse:collapse;width:100%;margin-top:8px}
th{background:#1565c0;color:#fff;padding:8px 12px;text-align:left;font-size:.85em}
td{padding:7px 12px;font-size:.85em;border-bottom:1px solid #e0e0e0}
tr:hover td{background:#e3f2fd}
</style>
</head>
<body>
<h1>Traceability Report</h1>
<table>
<tr><th>Field</th><th>Value</th></tr>
<tr><td>SchemaVersion</td><td>$($Model.SchemaVersion)</td></tr>
<tr><td>ToolVersion</td><td>$($Model.ToolVersion)</td></tr>
<tr><td>RunId</td><td>$($Model.RunId)</td></tr>
<tr><td>GeneratedUtc</td><td>$($Model.GeneratedUtc)</td></tr>
</table>
<h2>Summary</h2>
<table>
<tr><th>Category</th><th>Count</th></tr>
<tr><td>Total</td><td>$($Model.Summary.Total)</td></tr>
<tr><td>FindingOnly</td><td>$($Model.Summary.FindingOnly)</td></tr>
<tr><td>WhatIfGenerated</td><td>$($Model.Summary.WhatIfGenerated)</td></tr>
<tr><td>Approved</td><td>$($Model.Summary.Approved)</td></tr>
<tr><td>Executed</td><td>$($Model.Summary.Executed)</td></tr>
<tr><td>Skipped</td><td>$($Model.Summary.Skipped)</td></tr>
<tr><td>Blocked</td><td>$($Model.Summary.Blocked)</td></tr>
<tr><td>Failed</td><td>$($Model.Summary.Failed)</td></tr>
<tr><td>EvidenceMissing</td><td>$($Model.Summary.EvidenceMissing)</td></tr>
<tr><td>TraceGap</td><td>$($Model.Summary.TraceGap)</td></tr>
</table>
<h2>Trace Rows</h2>
<table>
<tr><th>FindingId</th><th>Severity</th><th>DisplayName</th><th>ActionId</th><th>ActionType</th><th>ApprovalStatus</th><th>ExecutionOutcome</th><th>TraceStatus</th><th>TraceGapReason</th></tr>
$($rows.ToString())</table>
</body>
</html>
"@

    [System.IO.File]::WriteAllText($Path, $html, [System.Text.Encoding]::UTF8)
}

