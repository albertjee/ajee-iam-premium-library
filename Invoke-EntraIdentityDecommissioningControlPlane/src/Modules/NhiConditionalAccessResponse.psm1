# NhiConditionalAccessResponse.psm1 - Rev4.1
# Pre-decom Conditional Access policy trigger analysis.
# Read-only. No write cmdlets.
Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function Invoke-NhiConditionalAccessResponseScan {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$NhiObject,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SignInLogs
    )

    if ($null -eq $NhiObject) { return @() }
    if ($NhiObject.AgenticCandidate -ne $true) { return @() }

    $objectId    = if ($NhiObject.ObjectId)          { $NhiObject.ObjectId }          else { 'UNKNOWN' }
    $displayName = if ($NhiObject.DisplayName)        { $NhiObject.DisplayName }        else { 'UNKNOWN' }
    $objectType  = if ($NhiObject.ObjectType)         { $NhiObject.ObjectType }         else { 'Unknown' }
    $upn         = if ($NhiObject.UserPrincipalName)  { $NhiObject.UserPrincipalName }  else { $null }

    $nhiBool  = $NhiObject.NhiCandidate        -is [bool] -and $NhiObject.NhiCandidate
    $agBool   = $NhiObject.AgenticCandidate    -is [bool] -and $NhiObject.AgenticCandidate
    $autoBool = $NhiObject.AutomationCandidate -is [bool] -and $NhiObject.AutomationCandidate
    $workBool = $NhiObject.WorkloadCandidate   -is [bool] -and $NhiObject.WorkloadCandidate

    $totalSignIns = if ($SignInLogs) { $SignInLogs.Count } else { 0 }
    $caBlockCount = 0
    $caGrantCount = 0

    foreach ($log in $SignInLogs) {
        $caStatus = if ($null -ne $log.ConditionalAccessStatus) { $log.ConditionalAccessStatus } else { '' }
        if ($caStatus -ieq 'failure') { $caBlockCount++ }
        $policies = $log.AppliedConditionalAccessPolicies
        if ($caStatus -ieq 'success' -and $null -ne $policies -and $policies.Count -gt 0) {
            $caGrantCount++
        }
    }

    $allBlockedSignal = $false
    if ($caBlockCount -gt 0 -and $totalSignIns -gt 0) {
        if (([double]$caBlockCount / [double]$totalSignIns) -gt 0.8) {
            $allBlockedSignal = $true
        }
    }

    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($caBlockCount -gt 5) {
        $findings.Add((New-DecomFinding `
            -FindingId 'NHI-CA-001' -Category 'ConditionalAccessResponse' `
            -Severity 'Medium' -RiskScore 40 -Confidence 'Medium' `
            -ObjectType $objectType -ObjectId $objectId -DisplayName $displayName `
            -UserPrincipalName $upn `
            -Evidence "Conditional Access blocked $caBlockCount sign-ins" `
            -EvidenceSource 'Invoke-NhiConditionalAccessResponseScan' `
            -RecommendedAction 'Review CA policies blocking this identity.' `
            -RemediationMode 'ManualApprovalRequired' `
            -NhiCandidate ($nhiBool -or $false) -AgenticCandidate ($agBool -or $false) `
            -AutomationCandidate ($autoBool -or $false) -WorkloadCandidate ($workBool -or $false)
        ))
    }

    if ($allBlockedSignal) {
        $findings.Add((New-DecomFinding `
            -FindingId 'NHI-CA-002' -Category 'ConditionalAccessResponse' `
            -Severity 'High' -RiskScore 60 -Confidence 'High' `
            -ObjectType $objectType -ObjectId $objectId -DisplayName $displayName `
            -UserPrincipalName $upn `
            -Evidence "Agent is largely blocked by Conditional Access ($caBlockCount/$totalSignIns sign-ins blocked). Decommission may already be partially enforced by policy." `
            -EvidenceSource 'Invoke-NhiConditionalAccessResponseScan' `
            -RecommendedAction 'Confirm CA policy intent with security team.' `
            -RemediationMode 'ManualApprovalRequired' `
            -NhiCandidate ($nhiBool -or $false) -AgenticCandidate ($agBool -or $false) `
            -AutomationCandidate ($autoBool -or $false) -WorkloadCandidate ($workBool -or $false)
        ))
    }

    if ($caBlockCount -eq 0) {
        $findings.Add((New-DecomFinding `
            -FindingId 'NHI-CA-003' -Category 'ConditionalAccessResponse' `
            -Severity 'Informational' -RiskScore 0 -Confidence 'High' `
            -ObjectType $objectType -ObjectId $objectId -DisplayName $displayName `
            -UserPrincipalName $upn `
            -Evidence 'No Conditional Access blocks detected in assessment window' `
            -EvidenceSource 'Invoke-NhiConditionalAccessResponseScan' `
            -RecommendedAction 'No action required.' `
            -RemediationMode 'InformationOnly' `
            -NhiCandidate ($nhiBool -or $false) -AgenticCandidate ($agBool -or $false) `
            -AutomationCandidate ($autoBool -or $false) -WorkloadCandidate ($workBool -or $false)
        ))
    }

    return $findings.ToArray()
}

Export-ModuleMember -Function Invoke-NhiConditionalAccessResponseScan
