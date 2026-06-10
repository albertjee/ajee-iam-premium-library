# NhiTokenForensics.psm1 - Rev4.1
# Pre-decom token lifecycle and credential usage analysis.
# Read-only. No write cmdlets.
Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function Invoke-NhiTokenForensicsScan {
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
    $agVal = $NhiObject.AgenticCandidate
    if ($null -eq $agVal -or $agVal -ne $true) { return @() }

    $objectId    = if ($NhiObject.ObjectId)    { $NhiObject.ObjectId }    else { 'UNKNOWN' }
    $displayName = if ($NhiObject.DisplayName) { $NhiObject.DisplayName } else { 'UNKNOWN' }
    $objectType  = if ($NhiObject.ObjectType)  { $NhiObject.ObjectType }  else { 'Unknown' }
    $upn         = if ($NhiObject.UserPrincipalName) { $NhiObject.UserPrincipalName } else { $null }

    $nhiBool  = $NhiObject.NhiCandidate        -is [bool] -and $NhiObject.NhiCandidate
    $agBool   = $NhiObject.AgenticCandidate    -is [bool] -and $NhiObject.AgenticCandidate
    $autoBool = $NhiObject.AutomationCandidate -is [bool] -and $NhiObject.AutomationCandidate
    $workBool = $NhiObject.WorkloadCandidate   -is [bool] -and $NhiObject.WorkloadCandidate

    # TokenRefreshCount: sign-ins where ClientAppUsed indicates OAuth/token client
    $tokenRefreshCount = 0
    if ($SignInLogs -and $SignInLogs.Count -gt 0) {
        foreach ($log in $SignInLogs) {
            $ca = if ($log.ClientAppUsed) { $log.ClientAppUsed } else { '' }
            if ($ca -match 'MSAL|OAuth|Token') { $tokenRefreshCount++ }
        }
    }

    # LongLivedTokenSignal: same IP spans > 7 days
    $longLivedTokenSignal = $false
    $longLivedDays = 0
    if ($SignInLogs -and $SignInLogs.Count -gt 1) {
        $byIp = $SignInLogs | Group-Object -Property IpAddress -ErrorAction SilentlyContinue
        foreach ($grp in $byIp) {
            if ($grp.Count -lt 2) { continue }
            $dates = @()
            foreach ($e in $grp.Group) {
                foreach ($prop in @('CreatedDateTime','Date','IssueInstant')) {
                    $v = $e.$prop
                    if ($null -ne $v) {
                        try { $dates += [datetime]$v; break } catch {}
                    }
                }
            }
            if ($dates.Count -lt 2) { continue }
            $span = (($dates | Sort-Object -Descending)[0] - ($dates | Sort-Object)[0]).TotalDays
            if ($span -gt 7) { $longLivedTokenSignal = $true; $longLivedDays = [math]::Round($span,1); break }
        }
    }

    # BurstRefreshSignal: > 5 token refreshes in 1-hour rolling window
    $burstRefreshSignal = $false
    $burstCount = 0
    if ($SignInLogs -and $SignInLogs.Count -gt 0) {
        $tokenEntries = @()
        foreach ($log in $SignInLogs) {
            $ca = if ($log.ClientAppUsed) { $log.ClientAppUsed } else { '' }
            if ($ca -match 'MSAL|OAuth|Token') {
                $dt = $null
                foreach ($prop in @('CreatedDateTime','Date','IssueInstant')) {
                    if ($log.$prop) { try { $dt = [datetime]$log.$prop; break } catch {} }
                }
                if ($null -ne $dt) { $tokenEntries += [PSCustomObject]@{ Timestamp = $dt } }
            }
        }
        if ($tokenEntries.Count -gt 0) {
            $sorted = $tokenEntries | Sort-Object Timestamp
            for ($i = 0; $i -lt $sorted.Count; $i++) {
                $wEnd = $sorted[$i].Timestamp.AddHours(1)
                $cnt = ($sorted[$i..($sorted.Count-1)] | Where-Object { $_.Timestamp -le $wEnd }).Count
                if ($cnt -gt 5) { $burstRefreshSignal = $true; $burstCount = $cnt; break }
            }
        }
    }

    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($longLivedTokenSignal) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-TOKEN-001' -Category 'NhiTokenForensics' -Severity 'High' -RiskScore 70 -Confidence 'Medium' -ObjectType $objectType -ObjectId $objectId -DisplayName $displayName -UserPrincipalName $upn -Evidence "Long-lived token pattern: same source IP active across ${longLivedDays}-day span without credential rotation" -EvidenceSource 'Invoke-NhiTokenForensicsScan' -RecommendedAction 'Rotate token/credential; enforce short TTL.' -RemediationMode 'ManualApprovalRequired' -AgenticCandidate $true -NhiCandidate ($nhiBool -or $false) -AutomationCandidate ($autoBool -or $false) -WorkloadCandidate ($workBool -or $false)))
    }
    if ($burstRefreshSignal) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-TOKEN-002' -Category 'NhiTokenForensics' -Severity 'Medium' -RiskScore 50 -Confidence 'High' -ObjectType $objectType -ObjectId $objectId -DisplayName $displayName -UserPrincipalName $upn -Evidence "Burst token refresh: ${burstCount} refreshes within 1 hour" -EvidenceSource 'Invoke-NhiTokenForensicsScan' -RecommendedAction 'Investigate source of repeated token acquisition.' -RemediationMode 'ManualApprovalRequired' -AgenticCandidate $true -NhiCandidate ($nhiBool -or $false) -AutomationCandidate ($autoBool -or $false) -WorkloadCandidate ($workBool -or $false)))
    }
    if ($tokenRefreshCount -eq 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-TOKEN-003' -Category 'NhiTokenForensics' -Severity 'Informational' -RiskScore 0 -Confidence 'High' -ObjectType $objectType -ObjectId $objectId -DisplayName $displayName -UserPrincipalName $upn -Evidence 'No token refresh activity detected in assessment window' -EvidenceSource 'Invoke-NhiTokenForensicsScan' -RecommendedAction 'Passive account or no interactive sign-in activity.' -RemediationMode 'InformationOnly' -AgenticCandidate $true -NhiCandidate ($nhiBool -or $false) -AutomationCandidate ($autoBool -or $false) -WorkloadCandidate ($workBool -or $false)))
    }

    return $findings.ToArray()
}

Export-ModuleMember -Function Invoke-NhiTokenForensicsScan
