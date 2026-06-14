#Requires -Version 5.1

#Requires -Version 5.1

if (-not (Get-Command Get-DecomToolVersion -ErrorAction SilentlyContinue)) {
    function Get-DecomToolVersion { 'Rev4.10' }
}

function Compare-DecomWhatIfToApproval {
    <#
    .SYNOPSIS
    Compares a WhatIf action plan to an ApprovalManifest and returns a structured diff.
    .DESCRIPTION
    Matches WhatIf actions to approval actions by ActionId and classifies each as
    ApprovedUnchanged, ApprovedModified, RejectedOrOmitted, ApprovalOnlyNotInWhatIf,
    HashChanged, TargetChanged, ActionTypeChanged, RiskChanged, or ProtectedObjectAttempted.
    ApprovalOnlyNotInWhatIf sets overall Passed=$false (hard validation failure).
    .PARAMETER WhatIfActions
    Array of action objects from the WhatIf run.
    .PARAMETER ApprovalActions
    Array of action objects from the approval manifest.
    .PARAMETER RunId
    Optional run identifier for correlation.
    .RETURNS
    A PSCustomObject containing SchemaVersion, ToolVersion, RunId, GeneratedUtc,
    Passed, DiffItems, and Summary.
    #>
    param(
        [pscustomobject[]]$WhatIfActions   = @(),
        [pscustomobject[]]$ApprovalActions  = @(),
        [string]$RunId = ''
    )

    $diff = [pscustomobject]@{
        SchemaVersion = '3.6'
        ToolVersion   = Get-DecomToolVersion
        RunId         = $RunId
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Passed        = $true
        DiffItems     = @()
        Summary       = [ordered]@{
            Total                   = 0
            ApprovedUnchanged       = 0
            ApprovedModified        = 0
            RejectedOrOmitted       = 0
            ApprovalOnlyNotInWhatIf = 0
            HighRisk                = 0
        }
    }

    # Build lookup: ApprovalActions by ActionId
    $approvalLookup = @{}
    foreach ($aa in $ApprovalActions) {
        if ($null -ne $aa -and $aa.ActionId) {
            $approvalLookup[$aa.ActionId] = $aa
        }
    }

    # Track which approval ActionIds were matched
    $matchedApprovalIds = @{}

    # Process each WhatIf action
    foreach ($wa in $WhatIfActions) {
        if ($null -eq $wa) { continue }

        $actionId   = [string]$wa.ActionId
        $actionType = [string]$wa.ActionType

        # ProtectedObjectAttempted check first
        if ($wa.IsProtectedObject -eq $true -or $wa.ProtectedObject -eq $true) {
            # Mark the matching approval action as consumed so it isn't flagged ApprovalOnlyNotInWhatIf
            if ($approvalLookup.ContainsKey($actionId)) {
                $matchedApprovalIds[$actionId] = $true
            }
            $item = [pscustomobject]@{
                ActionId       = $actionId
                ActionType     = $actionType
                DiffCategory   = 'ProtectedObjectAttempted'
                RiskLevel      = 'High'
                WhatIfAction   = $wa
                ApprovalAction = $approvalLookup[$actionId]
                Notes          = 'WhatIf action targets a protected object.'
            }
            $diff.DiffItems += $item
            $diff.Summary.Total++
            $diff.Summary.HighRisk++
            continue
        }

        $aa = $approvalLookup[$actionId]

        if ($null -eq $aa) {
            # Not found in approval manifest
            $item = [pscustomobject]@{
                ActionId       = $actionId
                ActionType     = $actionType
                DiffCategory   = 'RejectedOrOmitted'
                RiskLevel      = 'Medium'
                WhatIfAction   = $wa
                ApprovalAction = $null
                Notes          = 'WhatIf action was not found in the approval manifest.'
            }
            $diff.DiffItems += $item
            $diff.Summary.Total++
            $diff.Summary.RejectedOrOmitted++
        } else {
            $matchedApprovalIds[$actionId] = $true

            # Determine diff category — evaluate in priority order
            $category  = 'ApprovedUnchanged'
            $riskLevel = 'Low'
            $notes     = ''

            # TargetChanged check
            $waTarget = [string]$wa.TargetObjectId
            $aaTarget = [string]$aa.TargetObjectId
            if ($waTarget -ne $aaTarget -and ($waTarget -or $aaTarget)) {
                $category  = 'TargetChanged'
                $riskLevel = 'High'
                $notes     = "TargetObjectId changed from '$waTarget' (WhatIf) to '$aaTarget' (Approval)."
            }

            # ActionTypeChanged check
            if ($category -eq 'ApprovedUnchanged') {
                $waType = [string]$wa.ActionType
                $aaType = [string]$aa.ActionType
                if ($waType -ne $aaType -and ($waType -or $aaType)) {
                    $category  = 'ActionTypeChanged'
                    $riskLevel = 'Medium'
                    $notes     = "ActionType changed from '$waType' (WhatIf) to '$aaType' (Approval)."
                }
            }

            # HashChanged check
            if ($category -eq 'ApprovedUnchanged') {
                $waHash = [string]$wa.Hash
                $aaHash = [string]$aa.Hash
                if ($waHash -and $aaHash -and $waHash -ne $aaHash) {
                    $category  = 'HashChanged'
                    $riskLevel = 'Medium'
                    $notes     = 'Action hash differs between WhatIf and Approval records.'
                }
            }

            # RiskChanged check
            if ($category -eq 'ApprovedUnchanged') {
                $waRisk = [string]$wa.RiskScore
                $aaRisk = [string]$aa.RiskScore
                if ($waRisk -and $aaRisk -and $waRisk -ne $aaRisk) {
                    $category  = 'RiskChanged'
                    $riskLevel = 'Medium'
                    $notes     = "RiskScore changed from '$waRisk' (WhatIf) to '$aaRisk' (Approval)."
                }
            }

            # ApprovedModified — any other meaningful field difference not caught above
            # Note: intentionally omit ProtectedObject/IsProtectedObject — WhatIf-only fields that
            # are legitimately absent from approval manifests and should not trigger a diff.
            if ($category -eq 'ApprovedUnchanged') {
                $waDisplayName = [string]$wa.DisplayName
                $aaDisplayName = [string]$aa.DisplayName
                if ($waDisplayName -and $aaDisplayName -and $waDisplayName -ne $aaDisplayName) {
                    $category = 'ApprovedModified'
                    $riskLevel = 'Low'
                    $notes = 'DisplayName differs between WhatIf and Approval records.'
                }
            }

            $item = [pscustomobject]@{
                ActionId       = $actionId
                ActionType     = $actionType
                DiffCategory   = $category
                RiskLevel      = $riskLevel
                WhatIfAction   = $wa
                ApprovalAction = $aa
                Notes          = $notes
            }

            $diff.DiffItems += $item
            $diff.Summary.Total++

            switch ($category) {
                'ApprovedUnchanged'  { $diff.Summary.ApprovedUnchanged++ }
                'ApprovedModified'   { $diff.Summary.ApprovedModified++ }
                'HashChanged'        { $diff.Summary.ApprovedModified++ }
                'ActionTypeChanged'  { $diff.Summary.ApprovedModified++ }
                'RiskChanged'        { $diff.Summary.ApprovedModified++ }
                'TargetChanged'      { $diff.Summary.ApprovedModified++ }
            }

            if ($riskLevel -eq 'High') {
                $diff.Summary.HighRisk++
            }
        }
    }

    # Process approval actions not found in WhatIf
    foreach ($aa in $ApprovalActions) {
        if ($null -eq $aa -or -not $aa.ActionId) { continue }
        $actionId = [string]$aa.ActionId
        if ($matchedApprovalIds.ContainsKey($actionId)) { continue }

        $item = [pscustomobject]@{
            ActionId       = $actionId
            ActionType     = [string]$aa.ActionType
            DiffCategory   = 'ApprovalOnlyNotInWhatIf'
            RiskLevel      = 'High'
            WhatIfAction   = $null
            ApprovalAction = $aa
            Notes          = 'Approval action has no corresponding WhatIf action — hard validation failure.'
        }

        $diff.DiffItems  += $item
        $diff.Passed      = $false
        $diff.Summary.Total++
        $diff.Summary.ApprovalOnlyNotInWhatIf++
        $diff.Summary.HighRisk++
    }

    return $diff
}

function Export-DecomApprovalDiffJson {
    <#
    .SYNOPSIS
    Exports an approval diff result to a JSON file.
    .PARAMETER Diff
    The diff object returned by Compare-DecomWhatIfToApproval.
    .PARAMETER Path
    Full path to the output JSON file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Diff,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $json = $Diff | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.Encoding]::UTF8)
}

function Export-DecomApprovalDiffMarkdown {
    <#
    .SYNOPSIS
    Exports an approval diff result to a Markdown file.
    .PARAMETER Diff
    The diff object returned by Compare-DecomWhatIfToApproval.
    .PARAMETER Path
    Full path to the output Markdown file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Diff,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $passedLabel = if ($Diff.Passed) { 'PASSED' } else { 'FAILED' }

    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('# Approval Diff Report')
    $lines.Add('')
    $lines.Add("| Field | Value |")
    $lines.Add('|---|---|')
    $lines.Add("| SchemaVersion | $($Diff.SchemaVersion) |")
    $lines.Add("| ToolVersion | $($Diff.ToolVersion) |")
    $lines.Add("| RunId | $($Diff.RunId) |")
    $lines.Add("| GeneratedUtc | $($Diff.GeneratedUtc) |")
    $lines.Add("| Passed | $passedLabel |")
    $lines.Add('')
    $lines.Add('## Summary')
    $lines.Add('')
    $lines.Add('| Category | Count |')
    $lines.Add('|---|---|')
    $lines.Add("| Total | $($Diff.Summary.Total) |")
    $lines.Add("| ApprovedUnchanged | $($Diff.Summary.ApprovedUnchanged) |")
    $lines.Add("| ApprovedModified | $($Diff.Summary.ApprovedModified) |")
    $lines.Add("| RejectedOrOmitted | $($Diff.Summary.RejectedOrOmitted) |")
    $lines.Add("| ApprovalOnlyNotInWhatIf | $($Diff.Summary.ApprovalOnlyNotInWhatIf) |")
    $lines.Add("| HighRisk | $($Diff.Summary.HighRisk) |")
    $lines.Add('')
    $lines.Add('## Diff Items')
    $lines.Add('')
    $lines.Add('| ActionId | ActionType | DiffCategory | RiskLevel | Notes |')
    $lines.Add('|---|---|---|---|---|')

    foreach ($item in $Diff.DiffItems) {
        $aid   = [string]$item.ActionId
        $atype = [string]$item.ActionType
        $cat   = [string]$item.DiffCategory
        $risk  = [string]$item.RiskLevel
        $notes = ([string]$item.Notes) -replace '\|', '&#124;'
        $lines.Add("| $aid | $atype | $cat | $risk | $notes |")
    }

    $content = $lines -join "`n"
    [System.IO.File]::WriteAllText($Path, $content, [System.Text.Encoding]::UTF8)
}

function Export-DecomApprovalDiffHtml {
    <#
    .SYNOPSIS
    Exports an approval diff result to an HTML file.
    .PARAMETER Diff
    The diff object returned by Compare-DecomWhatIfToApproval.
    .PARAMETER Path
    Full path to the output HTML file.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Diff,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $passedLabel = if ($Diff.Passed) { 'PASSED' } else { 'FAILED' }
    $passedColor = if ($Diff.Passed) { '#2e7d32' } else { '#c62828' }

    $rows = [System.Text.StringBuilder]::new()
    foreach ($item in $Diff.DiffItems) {
        $riskColor = switch ([string]$item.RiskLevel) {
            'High'   { '#c62828' }
            'Medium' { '#e65100' }
            default  { '#1b5e20' }
        }
        $aid   = [System.Web.HttpUtility]::HtmlEncode([string]$item.ActionId)
        $atype = [System.Web.HttpUtility]::HtmlEncode([string]$item.ActionType)
        $cat   = [System.Web.HttpUtility]::HtmlEncode([string]$item.DiffCategory)
        $risk  = [System.Web.HttpUtility]::HtmlEncode([string]$item.RiskLevel)
        $notes = [System.Web.HttpUtility]::HtmlEncode([string]$item.Notes)
        [void]$rows.Append("<tr><td>$aid</td><td>$atype</td><td>$cat</td><td style='color:$riskColor;font-weight:bold'>$risk</td><td>$notes</td></tr>`n")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"/>
<title>Approval Diff Report</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:24px;background:#fafafa;color:#212121}
h1{font-size:1.6em;margin-bottom:8px}
h2{font-size:1.2em;margin-top:24px}
table{border-collapse:collapse;width:100%;margin-top:8px}
th{background:#1565c0;color:#fff;padding:8px 12px;text-align:left;font-size:.85em}
td{padding:7px 12px;font-size:.85em;border-bottom:1px solid #e0e0e0}
tr:hover td{background:#e3f2fd}
.badge{display:inline-block;padding:2px 10px;border-radius:12px;font-size:.8em;font-weight:bold}
</style>
</head>
<body>
<h1>Approval Diff Report</h1>
<table>
<tr><th>Field</th><th>Value</th></tr>
<tr><td>SchemaVersion</td><td>$($Diff.SchemaVersion)</td></tr>
<tr><td>ToolVersion</td><td>$($Diff.ToolVersion)</td></tr>
<tr><td>RunId</td><td>$($Diff.RunId)</td></tr>
<tr><td>GeneratedUtc</td><td>$($Diff.GeneratedUtc)</td></tr>
<tr><td>Passed</td><td style='color:$passedColor;font-weight:bold'>$passedLabel</td></tr>
</table>
<h2>Summary</h2>
<table>
<tr><th>Category</th><th>Count</th></tr>
<tr><td>Total</td><td>$($Diff.Summary.Total)</td></tr>
<tr><td>ApprovedUnchanged</td><td>$($Diff.Summary.ApprovedUnchanged)</td></tr>
<tr><td>ApprovedModified</td><td>$($Diff.Summary.ApprovedModified)</td></tr>
<tr><td>RejectedOrOmitted</td><td>$($Diff.Summary.RejectedOrOmitted)</td></tr>
<tr><td>ApprovalOnlyNotInWhatIf</td><td>$($Diff.Summary.ApprovalOnlyNotInWhatIf)</td></tr>
<tr><td>HighRisk</td><td>$($Diff.Summary.HighRisk)</td></tr>
</table>
<h2>Diff Items</h2>
<table>
<tr><th>ActionId</th><th>ActionType</th><th>DiffCategory</th><th>RiskLevel</th><th>Notes</th></tr>
$($rows.ToString())</table>
</body>
</html>
"@

    [System.IO.File]::WriteAllText($Path, $html, [System.Text.Encoding]::UTF8)
}
