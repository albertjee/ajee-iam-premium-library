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