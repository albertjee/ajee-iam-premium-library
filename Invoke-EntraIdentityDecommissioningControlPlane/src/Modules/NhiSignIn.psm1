#Requires -Version 5.1

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

# Threshold constants
$script:SignInStale90Days  = 90
$script:SignInStale180Days = 180
$script:SignInStale365Days = 365
$script:SignInRecentDays   = 30

function Invoke-NhiSignInScan {
    [CmdletBinding()]
    param(
        [object[]]$ServicePrincipals,
        [hashtable]$SignInByAppId,
        [hashtable]$SignInByServicePrincipalId,
        [hashtable]$PermissionSummaryByObjectId
    )

    $findings = @()

    foreach ($sp in $ServicePrincipals) {
        $null = Set-DecomFindingTraceContext -SourceObject $sp -ClassificationSource 'NhiSignIn'
        # Determine sign-in record
        $signIn = $null
        if ($SignInByAppId -and $SignInByAppId.ContainsKey($sp.AppId)) {
            $signIn = $SignInByAppId[$sp.AppId]
        } elseif ($SignInByServicePrincipalId -and $SignInByServicePrincipalId.ContainsKey($sp.Id)) {
            $signIn = $SignInByServicePrincipalId[$sp.Id]
        }

        # Check if SP has active credentials
        $hasActiveCred = $false
        $now = Get-Date
        if ($sp.passwordCredentials -or $sp.keyCredentials) {
            $pwdCreds = if ($sp.passwordCredentials -is [array]) { $sp.passwordCredentials } else { @($sp.passwordCredentials) }
            $keyCreds = if ($sp.keyCredentials -is [array]) { $sp.keyCredentials } else { @($sp.keyCredentials) }
            foreach ($c in $pwdCreds) {
                if ($c.EndDateTime) {
                    try {
                        $end = [DateTime]::Parse($c.EndDateTime)
                        if ($end -gt $now) { $hasActiveCred = $true; break }
                    } catch { }
                }
            }
            if (-not $hasActiveCred) {
                foreach ($c in $keyCreds) {
                    if ($c.EndDateTime) {
                        try {
                            $end = [DateTime]::Parse($c.EndDateTime)
                            if ($end -gt $now) { $hasActiveCred = $true; break }
                        } catch { }
                    }
                }
            }
        }

        # Determine sign-in days
        $daysSince = $null
        $confidence = 'High'
        if ($signIn -and $signIn.LastSignInDate) {
            $lastSignIn = $signIn.LastSignInDate
            if ($lastSignIn -is [string]) {
                try { $lastSignIn = [DateTime]::Parse($lastSignIn) } catch { }
            }
            if ($lastSignIn -is [DateTime]) {
                $daysSince = [math]::Floor(($now - $lastSignIn).TotalDays)
            }
        }

        # OwnerCount
        $ownerCount = 0
        if ($null -ne $sp.OwnerCount) { $ownerCount = $sp.OwnerCount }

        # PermissionSummary
        $permSummary = $null
        if ($PermissionSummaryByObjectId -and $PermissionSummaryByObjectId.ContainsKey($sp.Id)) {
            $permSummary = $PermissionSummaryByObjectId[$sp.Id]
        }
        $hasHighRiskApp = $false
        if ($permSummary -and $permSummary.HasHighRiskApplicationPermission) {
            $hasHighRiskApp = $true
        }

        $spFindings = @()

        # SIGNIN-003: >= 365 days OR absent record with active credentials
        if (($null -ne $daysSince -and $daysSince -ge $script:SignInStale365Days) -or
            ($null -eq $daysSince -and $hasActiveCred)) {
            if ($null -eq $daysSince) {
                $evidence = 'No service principal sign-in observed in available sign-in dataset.'
                $confidence = 'Medium'
            } else {
                $evidence = "No sign-in for $daysSince days (>= $($script:SignInStale365Days))"
                $confidence = 'High'
            }
            $spFindings += New-DecomFinding -FindingId 'NHI-SIGNIN-003' -Category 'SignInActivity' -Severity 'Critical' -RiskScore 20 -Confidence $confidence -ObjectType 'ServicePrincipal' -ObjectId $sp.Id -DisplayName $sp.DisplayName -Evidence $evidence -EvidenceSource 'graph' -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals' -RecommendedAction 'Review SP activity; if unused, decommission' -RemediationMode 'ManualApprovalRequired' -ConsultantNote 'Inactive service principal with stale or absent sign-in record'
        }

        # SIGNIN-002: >= 180 and < 365 days
        if ($null -ne $daysSince -and $daysSince -ge $script:SignInStale180Days -and $daysSince -lt $script:SignInStale365Days -and $hasActiveCred) {
            $spFindings += New-DecomFinding -FindingId 'NHI-SIGNIN-002' -Category 'SignInActivity' -Severity 'High' -RiskScore 15 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $sp.Id -DisplayName $sp.DisplayName -Evidence "No sign-in for $daysSince days (>= $($script:SignInStale180Days), < $($script:SignInStale365Days))" -EvidenceSource 'graph' -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals' -RecommendedAction 'Review SP activity; if unused, decommission' -RemediationMode 'ManualApprovalRequired' -ConsultantNote 'Inactive service principal'
        }

        # SIGNIN-001: >= 90 and < 180 days
        if ($null -ne $daysSince -and $daysSince -ge $script:SignInStale90Days -and $daysSince -lt $script:SignInStale180Days -and $hasActiveCred) {
            $spFindings += New-DecomFinding -FindingId 'NHI-SIGNIN-001' -Category 'SignInActivity' -Severity 'Medium' -RiskScore 10 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $sp.Id -DisplayName $sp.DisplayName -Evidence "No sign-in for $daysSince days (>= $($script:SignInStale90Days), < $($script:SignInStale180Days))" -EvidenceSource 'graph' -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals' -RecommendedAction 'Review SP activity; consider decommission if unused' -RemediationMode 'InformationOnly' -ConsultantNote 'Inactive service principal'
        }

        # SIGNIN-004: Recent sign-in (< 30 days) AND no owner
        if ($null -ne $daysSince -and $daysSince -lt $script:SignInRecentDays -and ($ownerCount -eq 0 -or $null -eq $ownerCount)) {
            $spFindings += New-DecomFinding -FindingId 'NHI-SIGNIN-004' -Category 'SignInActivity' -Severity 'High' -RiskScore 10 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $sp.Id -DisplayName $sp.DisplayName -Evidence "Recently active ($daysSince days) but no owner assigned" -EvidenceSource 'graph' -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals' -RecommendedAction 'Assign owner immediately' -RemediationMode 'ManualApprovalRequired' -ConsultantNote 'Active SP with no ownership accountability'
        }

        # SIGNIN-005: Recent sign-in (< 30 days) AND high-risk application permission
        if ($null -ne $daysSince -and $daysSince -lt $script:SignInRecentDays -and $hasHighRiskApp) {
            $spFindings += New-DecomFinding -FindingId 'NHI-SIGNIN-005' -Category 'SignInActivity' -Severity 'High' -RiskScore 10 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $sp.Id -DisplayName $sp.DisplayName -Evidence "Recently active ($daysSince days) with high-risk application permission" -EvidenceSource 'graph' -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals' -RecommendedAction 'Audit high-risk permissions; ensure justification documented' -RemediationMode 'ManualApprovalRequired' -ConsultantNote 'Active SP with high-risk permissions; verify legitimate use'
        }

        $findings += $spFindings
    }

    Clear-DecomFindingTraceContext
    return $findings
}

Export-ModuleMember -Function Invoke-NhiSignInScan
