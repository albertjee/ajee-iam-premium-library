Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

# Threshold constants
$script:CredWarningDays       = 90
$script:CredCriticalDays       = 180
$script:CredExpiryWarningDays  = 30
$script:CredStaleSignInDays    = 180

function Invoke-NhiCredentialScan {
    [CmdletBinding()]
    param(
        [object[]]$ServicePrincipals,
        [hashtable]$SignInByAppId,
        [hashtable]$SignInByServicePrincipalId
    )

    $findings = @()

    foreach ($sp in $ServicePrincipals) {
        $null = Set-DecomFindingTraceContext -SourceObject $sp -ClassificationSource 'NhiCredential'
        # Determine sign-in record
        $signIn = $null
        if ($SignInByAppId -and $SignInByAppId.ContainsKey($sp.AppId)) {
            $signIn = $SignInByAppId[$sp.AppId]
        } elseif ($SignInByServicePrincipalId -and $SignInByServicePrincipalId.ContainsKey($sp.Id)) {
            $signIn = $SignInByServicePrincipalId[$sp.Id]
        }

        $passwordCreds = @()
        $keyCreds = @()
        if ($sp.passwordCredentials -is [array]) {
            $passwordCreds = $sp.passwordCredentials
        } elseif ($sp.passwordCredentials) {
            $passwordCreds = @($sp.passwordCredentials)
        }
        if ($sp.keyCredentials -is [array]) {
            $keyCreds = $sp.keyCredentials
        } elseif ($sp.keyCredentials) {
            $keyCreds = @($sp.keyCredentials)
        }

        # NHI-CRED-001: Uses client secret (password credential present)
        if ($passwordCreds.Count -ge 1) {
            $findings += New-DecomFinding `
                -FindingId 'NHI-CRED-001' `
                -Category 'CredentialHygiene' `
                -Severity 'Medium' `
                -RiskScore 10 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "Service principal has $($passwordCreds.Count) password credential(s); client secret detected" `
                -EvidenceSource 'graph' `
                -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)' `
                -RecommendedAction 'Replace client secrets with certificate or managed identity' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'Client secrets cannot be rotated without downtime; prefer certificate or managed identity'
        }

        # Collect all credentials with metadata for age-based analysis
        $now = Get-Date
        $allCreds = @()
        foreach ($pc in $passwordCreds) {
            $allCreds += @{
                Type     = 'Password'
                KeyId    = $pc.KeyId
                Start    = $pc.StartDateTime
                End      = $pc.EndDateTime
                HasSignIn = $false
            }
        }
        foreach ($kc in $keyCreds) {
            $allCreds += @{
                Type     = 'Key'
                KeyId    = $kc.KeyId
                Start    = $kc.StartDateTime
                End      = $kc.EndDateTime
                HasSignIn = $false
            }
        }

        # Determine sign-in presence for CRED-004
        $hasRecentSignIn = $false
        if ($signIn) {
            $lastSignIn = $signIn.LastSignInDate
            if ($lastSignIn) {
                $daysSince = ($now - $lastSignIn).Days
                if ($daysSince -le $script:CredStaleSignInDays) {
                    $hasRecentSignIn = $true
                }
            }
        }

        # NHI-CRED-002, CRED-003, CRED-005: Per-credential analysis
        foreach ($cred in $allCreds) {
            $startDate = $null
            $endDate = $null
            try { $startDate = [DateTime]::Parse($cred.Start) } catch { }
            try { $endDate = [DateTime]::Parse($cred.End) } catch { }

            $ageDays = $null
            $daysUntilExpiry = $null
            if ($startDate) { $ageDays = [math]::Floor(($now - $startDate).TotalDays) }
            if ($endDate) { $daysUntilExpiry = [math]::Floor(($endDate - $now).TotalDays) }

            # NHI-CRED-002: Secret age >= 90 and < 180
            if ($null -ne $ageDays -and $ageDays -ge $script:CredWarningDays -and $ageDays -lt $script:CredCriticalDays) {
                $findings += New-DecomFinding `
                    -FindingId 'NHI-CRED-002' `
                    -Category 'CredentialHygiene' `
                    -Severity 'Medium' `
                    -RiskScore 10 `
                    -Confidence 'High' `
                    -ObjectType 'ServicePrincipal' `
                    -ObjectId $sp.Id `
                    -DisplayName $sp.DisplayName `
                    -Evidence "Password/key credential $($cred.KeyId) age is $ageDays days (>= $($script:CredWarningDays), < $($script:CredCriticalDays))" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)' `
                    -RecommendedAction 'Rotate credential; prefer certificate or managed identity' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -ConsultantNote "Credential type: $($cred.Type)"
            }

            # NHI-CRED-003: Secret age >= 180
            if ($null -ne $ageDays -and $ageDays -ge $script:CredCriticalDays) {
                $findings += New-DecomFinding `
                    -FindingId 'NHI-CRED-003' `
                    -Category 'CredentialHygiene' `
                    -Severity 'High' `
                    -RiskScore 15 `
                    -Confidence 'High' `
                    -ObjectType 'ServicePrincipal' `
                    -ObjectId $sp.Id `
                    -DisplayName $sp.DisplayName `
                    -Evidence "Password/key credential $($cred.KeyId) age is $ageDays days (>= $($script:CredCriticalDays))" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)' `
                    -RecommendedAction 'Rotate credential immediately; prefer certificate or managed identity' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -ConsultantNote "Credential type: $($cred.Type)"
            }

            # NHI-CRED-005: Expiring within 30 days (not yet expired)
            if ($null -ne $daysUntilExpiry -and $daysUntilExpiry -ge 0 -and $daysUntilExpiry -le $script:CredExpiryWarningDays) {
                $findings += New-DecomFinding `
                    -FindingId 'NHI-CRED-005' `
                    -Category 'CredentialHygiene' `
                    -Severity 'Medium' `
                    -RiskScore 5 `
                    -Confidence 'High' `
                    -ObjectType 'ServicePrincipal' `
                    -ObjectId $sp.Id `
                    -DisplayName $sp.DisplayName `
                    -Evidence "Credential $($cred.KeyId) expires in $daysUntilExpiry days" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)' `
                    -RecommendedAction 'Renew credential before expiry to avoid service interruption' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -ConsultantNote "Credential type: $($cred.Type)"
            }
        }

        # NHI-CRED-004: Expired credential on SP with recent sign-in activity
        foreach ($cred in $allCreds) {
            $endDate = $null
            try { $endDate = [DateTime]::Parse($cred.End) } catch { }
            if ($endDate -and $endDate -lt $now -and $hasRecentSignIn) {
                $findings += New-DecomFinding `
                    -FindingId 'NHI-CRED-004' `
                    -Category 'CredentialHygiene' `
                    -Severity 'High' `
                    -RiskScore 10 `
                    -Confidence 'High' `
                    -ObjectType 'ServicePrincipal' `
                    -ObjectId $sp.Id `
                    -DisplayName $sp.DisplayName `
                    -Evidence "Expired credential $($cred.KeyId) found on SP with sign-in activity within $($script:CredStaleSignInDays) days" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)' `
                    -RecommendedAction 'Remove expired credential; ensure rotation process is in place' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -ConsultantNote "Credential type: $($cred.Type)"
            }
        }
    }

    Clear-DecomFindingTraceContext
    return $findings
}

Export-ModuleMember -Function Invoke-NhiCredentialScan
