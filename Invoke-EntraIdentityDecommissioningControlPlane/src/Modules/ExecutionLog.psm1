#Requires -Version 5.1

function New-DecomExecutionLog {
    param(
        [string]$RunFolder,
        [string]$EngagementId,
        [string]$RunId
    )

    $logPath = Join-Path $RunFolder "execution-log-$RunId.json"

    $log = [ordered]@{
        SchemaVersion = '2.0'
        RunId = $RunId
        EngagementId = $EngagementId
        StartedUtc = (Get-Date).ToUniversalTime().ToString('o')
        CompletedUtc = $null
        Actions = [System.Collections.Generic.List[object]]::new()
    }

    return [PSCustomObject]@{
        Log = $log
        Path = $logPath
    }
}

function Add-DecomExecutionAction {
    param(
        [PSCustomObject]$ExecutionLog,
        [string]$ActionId,
        [string]$FindingId,
        [string]$ObjectId,
        [string]$DisplayName,
        [string]$ActionType,
        [ValidateSet('Executed','PartialFailed','Failed','Skipped','Blocked','OperatorDeclined','OutOfScope')]
        [string]$Outcome,
        [string[]]$TargetObjectIds,
        [string[]]$TargetsBefore,
        [string[]]$TargetsAfter,
        [string]$ErrorDetail
    )

    $entry = [ordered]@{
        Timestamp = (Get-Date).ToUniversalTime().ToString('o')
        ActionId = $ActionId
        FindingId = $FindingId
        ObjectId = $ObjectId
        DisplayName = $DisplayName
        ActionType = $ActionType
        Outcome = $Outcome
        TargetObjectIds = $TargetObjectIds
        TargetsBefore = $TargetsBefore
        TargetsAfter = $TargetsAfter
        ErrorDetail = $ErrorDetail
    }

    $ExecutionLog.Log.Actions.Add($entry)
}

function Save-DecomExecutionLog {
    param([PSCustomObject]$ExecutionLog)

    $ExecutionLog.Log.CompletedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $ExecutionLog.Log | ConvertTo-Json -Depth 12 |
        Set-Content -Path $ExecutionLog.Path -Encoding UTF8
}

function Export-DecomExecutionEvidence {
    param(
        [PSCustomObject]$ExecutionLog,
        [object]$ApprovalManifest,
        [string]$CsvPath,
        [string]$JsonPath
    )

    $approvalHash = if ($ApprovalManifest.ApprovedActionsHash) {
        $ApprovalManifest.ApprovedActionsHash
    } else { '' }

    $approvedBy = if ($ApprovalManifest.ApprovedBy) {
        $ApprovalManifest.ApprovedBy
    } else { '' }

    $rows = [System.Collections.Generic.List[object]]::new()

    foreach ($action in $ExecutionLog.Log.Actions) {
        $targetIds     = @($action.TargetObjectIds)
        $targetsBefore = @($action.TargetsBefore)
        $targetsAfter  = @($action.TargetsAfter)

        $maxRows = [Math]::Max(1, $targetIds.Count)
        for ($i = 0; $i -lt $maxRows; $i++) {
            $tid    = if ($i -lt $targetIds.Count)     { $targetIds[$i] }     else { '' }
            $before = if ($i -lt $targetsBefore.Count) { $targetsBefore[$i] } else { '' }
            $after  = if ($i -lt $targetsAfter.Count)  { $targetsAfter[$i] }  else { '' }

            $row = [ordered]@{
                RunId                = $ExecutionLog.Log.RunId
                ActionId             = $action.ActionId
                FindingId            = $action.FindingId
                ActionType           = $action.ActionType
                ObjectId             = $action.ObjectId
                DisplayName          = $action.DisplayName
                TargetObjectId       = $tid
                BeforeState          = $before
                AfterState           = $after
                Outcome              = $action.Outcome
                ErrorDetail          = $action.ErrorDetail
                ApprovedBy           = $approvedBy
                ApprovalManifestHash = $approvalHash
                ExecutedUtc          = $action.Timestamp
            }
            $rows.Add($row)
        }
    }

    if ($rows.Count -gt 0) {
        $rows | ForEach-Object { [PSCustomObject]$_ } |
            Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
    } else {
        'RunId,ActionId,FindingId,ActionType,ObjectId,DisplayName,TargetObjectId,BeforeState,AfterState,Outcome,ErrorDetail,ApprovedBy,ApprovalManifestHash,ExecutedUtc' |
            Set-Content -Path $CsvPath -Encoding UTF8
    }

    $evidencePayload = [ordered]@{
        SchemaVersion        = '2.1'
        RunId                = $ExecutionLog.Log.RunId
        GeneratedUtc         = (Get-Date).ToUniversalTime().ToString('o')
        ApprovedBy           = $approvedBy
        ApprovalManifestHash = $approvalHash
        Actions              = $rows.ToArray()
    }
    $evidencePayload | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -Encoding UTF8
}

function Write-DecomExecutionManifest {
    param(
        [PSCustomObject]$ExecutionLog,
        [object]$ApprovalManifest,
        [string]$Path,
        [string]$EngagementId,
        [string]$ClientName,
        [string]$TenantId,
        [string]$Assessor,
        [string]$EvidenceCsvPath,
        [string]$EvidenceJsonPath,
        [string]$ReportPath
    )

    $actions = $ExecutionLog.Log.Actions

    $results = [ordered]@{
        Executed         = @($actions | Where-Object { $_.Outcome -eq 'Executed' }).Count
        PartialFailed    = @($actions | Where-Object { $_.Outcome -eq 'PartialFailed' }).Count
        Failed           = @($actions | Where-Object { $_.Outcome -eq 'Failed' }).Count
        Blocked          = @($actions | Where-Object { $_.Outcome -eq 'Blocked' }).Count
        OperatorDeclined = @($actions | Where-Object { $_.Outcome -eq 'OperatorDeclined' }).Count
        OutOfScope       = @($actions | Where-Object { $_.Outcome -eq 'OutOfScope' }).Count
        Total            = $actions.Count
    }

    $manifest = [ordered]@{
        SchemaVersion        = '2.1'
        Mode                 = 'ExecuteRemediation'
        ExecutionRunId       = $ExecutionLog.Log.RunId
        WhatIfRunId          = if ($ApprovalManifest.WhatIfRunId)          { $ApprovalManifest.WhatIfRunId }          else { '' }
        EngagementId         = $EngagementId
        ClientName           = $ClientName
        TenantId             = $TenantId
        Assessor             = $Assessor
        ApprovedBy           = if ($ApprovalManifest.ApprovedBy)           { $ApprovalManifest.ApprovedBy }           else { '' }
        ApprovalTicket       = if ($ApprovalManifest.ApprovalTicket)       { $ApprovalManifest.ApprovalTicket }       else { '' }
        ApprovalSystem       = if ($ApprovalManifest.ApprovalSystem)       { $ApprovalManifest.ApprovalSystem }       else { '' }
        StartedUtc           = $ExecutionLog.Log.StartedUtc
        CompletedUtc         = $ExecutionLog.Log.CompletedUtc
        ApprovalActionsHash  = if ($ApprovalManifest.ApprovedActionsHash)  { $ApprovalManifest.ApprovedActionsHash }  else { '' }
        ApprovalEnvelopeHash = if ($ApprovalManifest.ApprovalEnvelopeHash) { $ApprovalManifest.ApprovalEnvelopeHash } else { '' }
        Results              = $results
        EvidenceFiles        = [ordered]@{
            ExecutionLog = $ExecutionLog.Path
            Csv          = $EvidenceCsvPath
            Json         = $EvidenceJsonPath
            Html         = $ReportPath
        }
    }

    $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}