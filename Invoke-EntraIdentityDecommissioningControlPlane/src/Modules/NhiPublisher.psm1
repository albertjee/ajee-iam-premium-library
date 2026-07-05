Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function Invoke-NhiPublisherScan {
    [CmdletBinding()]
    param(
        [object[]]$ServicePrincipals,
        [hashtable]$AppRegistrationByAppId,
        [string]$TenantId
    )

    $findings = @()

    foreach ($sp in $ServicePrincipals) {
        $null = Set-DecomFindingTraceContext -SourceObject $sp -ClassificationSource 'NhiPublisher'
        $platformClassification = Test-DecomMicrosoftPlatformIdentity -NhiObject $sp
        if ($platformClassification.MicrosoftPlatform) {
            continue
        }

        $appReg = $null
        if ($AppRegistrationByAppId -and $AppRegistrationByAppId.ContainsKey($sp.AppId)) {
            $appReg = $AppRegistrationByAppId[$sp.AppId]
        }

        # NHI-PUB-001: External publisher
        if ($appReg -and $null -ne $appReg.PublisherTenantId -and
            $appReg.PublisherTenantId -ne $TenantId -and $TenantId -ne '') {
            $findings += New-DecomFinding `
                -FindingId 'NHI-PUB-001' `
                -Category 'Publisher Trust' `
                -Severity 'Medium' `
                -RiskScore 30 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "Publisher is in tenant $($appReg.PublisherTenantId) (external to assessment tenant $TenantId)" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/applications/$($sp.AppId)" `
                -RecommendedAction 'Verify publisher identity and business justification for cross-tenant publisher relationship' `
                -RemediationMode 'InformationOnly' `
                -ConsultantNote 'External publisher increases supply-chain risk - review necessity'
        }

        # NHI-PUB-002: No verified publisher
        if ($appReg) {
            $vp = $appReg.VerifiedPublisher
            $vpEmpty = $null -eq $vp -or $null -eq $vp.DisplayName -or $vp.DisplayName.Trim() -eq ''
            if ($vpEmpty) {
                $findings += New-DecomFinding `
                    -FindingId 'NHI-PUB-002' `
                    -Category 'Publisher Trust' `
                    -Severity 'Medium' `
                    -RiskScore 25 `
                    -Confidence 'High' `
                    -ObjectType 'ServicePrincipal' `
                    -ObjectId $sp.Id `
                    -DisplayName $sp.DisplayName `
                    -Evidence 'App registration has no verified publisher' `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint "https://graph.microsoft.com/v1.0/applications/$($sp.AppId)" `
                    -RecommendedAction 'Enroll in verified publisher through Microsoft Partner Center' `
                    -RemediationMode 'InformationOnly' `
                    -ConsultantNote 'Verified publisher establishes identity accountability'
            }
        }

        # NHI-REG-001: Multi-tenant or personal account sign-in
        if ($appReg -and $appReg.SignInAudience -ne 'AzureADMyOrg') {
            $findings += New-DecomFinding `
                -FindingId 'NHI-REG-001' `
                -Category 'App Registration Hygiene' `
                -Severity 'High' `
                -RiskScore 45 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "SignInAudience is '$($appReg.SignInAudience)' - not AzureADMyOrg" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/applications/$($sp.AppId)" `
                -RecommendedAction 'Restrict signInAudience to AzureADMyOrg; migrate if multi-tenant is required with business justification' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'Multi-tenant apps allow sign-in from any organization - increases exposure'
        }
    }

    Clear-DecomFindingTraceContext
    return $findings
}

Export-ModuleMember -Function Invoke-NhiPublisherScan
