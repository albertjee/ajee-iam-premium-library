#Requires -Version 5.1

Describe 'Rev4.10 Microsoft platform live-path suppression' {
    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @(
            'Utilities',
            'ApprovalManifest',
            'NhiGovernance',
            'NhiPublisher',
            'NhiPermission',
            'NhiOwner',
            'NhiCredential',
            'NhiSignIn',
            'Discovery'
        )) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
            Import-Module (Join-Path $script:ModulesPath "$m.psm1") -Force -DisableNameChecking
        }
    }

    AfterAll {
        foreach ($m in @(
            'Discovery',
            'NhiSignIn',
            'NhiCredential',
            'NhiOwner',
            'NhiPermission',
            'NhiPublisher',
            'NhiGovernance',
            'ApprovalManifest',
            'Utilities'
        )) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'New-DecomFinding sanitizes Microsoft platform remediation fields' {
        $finding = New-DecomFinding `
            -FindingId 'DEC-NHI-002' `
            -Category 'NHI Ownership' `
            -Severity 'High' `
            -RiskScore 62 `
            -Confidence 'High' `
            -ObjectType 'ServicePrincipal' `
            -ObjectId 'spn-001' `
            -DisplayName 'Microsoft Graph PowerShell' `
            -Evidence 'NHI has no owner assigned' `
            -EvidenceSource 'graph' `
            -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/spn-001/owners' `
            -RecommendedAction 'Assign accountable owner / AddApplicationOwner / revoke consent' `
            -RemediationMode 'ManualApprovalRequired' `
            -FirstPartyMicrosoftApp $true `
            -MicrosoftPlatform $true `
            -MicrosoftPlatformReason 'MicrosoftOwnerTenant' `
            -ClassificationSource 'Test'

        $finding.FirstPartyMicrosoftApp | Should -Be $true
        $finding.MicrosoftPlatform | Should -Be $true
        $finding.EvidenceOnly | Should -Be $true
        $finding.Classification | Should -Be 'MicrosoftPlatform'
        $finding.RemediationMode | Should -Be 'InformationOnly'
        $finding.RecommendedAction | Should -Be 'Evidence only - Microsoft platform identity'
        $finding.ClassificationSource | Should -Be 'Test'
    }

    It 'Microsoft platform service principals do not produce customer-actionable permission or publisher remediation' {
        $sp = [pscustomobject]@{
            Id                              = [guid]::NewGuid().Guid
            AppId                           = '1b730954-1685-4b74-9bfd-dac224a7b894'
            DisplayName                     = 'Microsoft Graph PowerShell'
            appDisplayName                  = 'Microsoft Graph PowerShell'
            servicePrincipalType            = 'Application'
            publisherName                   = ''
            verifiedPublisher               = [pscustomobject]@{ displayName = 'Microsoft' }
            appOwnerOrganizationId          = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
            tags                            = @('WindowsAzureActiveDirectoryIntegratedApp')
            OwnerCount                      = 0
            HighRiskPermissionCount         = 2
            HighRiskOAuthGrantCount         = 1
            CredentialCount                 = 1
            TenantWideConsent               = $true
            Classification                  = 'LikelyAutomation'
            ClassificationConfidence        = 'Medium'
            ClassificationSignals           = @('legacy-signal')
            ClassificationSource            = 'LiveGraph'
            MicrosoftPlatformReason         = 'MicrosoftOwnerTenant'
            MicrosoftFirstParty             = $true
            FirstPartyMicrosoftApp          = $true
            MicrosoftPlatform               = $true
            EvidenceOnly                    = $true
            NormalizedAppId                 = '1b730954-1685-4b74-9bfd-dac224a7b894'
            NormalizedPublisherName         = ''
            NormalizedVerifiedPublisherName = 'Microsoft'
            NormalizedAppOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
            NormalizedServicePrincipalType  = 'Application'
            NormalizedTags                  = @('WindowsAzureActiveDirectoryIntegratedApp')
        }
        $permissionFindings = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @(
            [pscustomobject]@{ PrincipalId = $sp.Id; ResolvedRoleValue = 'Directory.ReadWrite.All'; ResourceDisplayName = 'Microsoft Graph' }
        ) -OAuthGrants @(
            [pscustomobject]@{ ClientId = $sp.Id; Scope = 'Mail.Send offline_access'; ConsentType = 'AllPrincipals' }
        )
        $publisherFindings = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{}

        $permissionFindings.Count | Should -Be 0
        $publisherFindings.Count | Should -Be 0
    }

    It 'Recognizes exact live Microsoft and Apple metadata without display-name-only classification' {
        $graphPowerShell = [pscustomobject]@{
            Id                         = 'sp-live-graph'
            AppId                      = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
            DisplayName                = 'Microsoft Graph PowerShell'
            appDisplayName             = 'Microsoft Graph PowerShell'
            servicePrincipalType       = 'Application'
            publisherName              = ''
            verifiedPublisher          = [pscustomobject]@{ displayName = 'Microsoft Corporation' }
            appOwnerOrganizationId     = '72f988bf-86f1-41af-91ab-2d7cd011db47'
            tags                       = @('WindowsAzureActiveDirectoryIntegratedApp')
            NormalizedAppId            = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
            NormalizedPublisherName    = ''
            NormalizedVerifiedPublisherName = 'Microsoft Corporation'
            NormalizedAppOwnerOrganizationId = '72f988bf-86f1-41af-91ab-2d7cd011db47'
            NormalizedServicePrincipalType   = 'Application'
            NormalizedTags             = @('WindowsAzureActiveDirectoryIntegratedApp')
        }
        $techCommunity = [pscustomobject]@{
            Id                         = 'sp-live-tech'
            AppId                      = '09213cdc-9f30-4e82-aa6f-9b6e8d82dab3'
            DisplayName                = 'Microsoft Tech Community'
            appDisplayName             = 'Microsoft Tech Community'
            servicePrincipalType       = 'Application'
            publisherName              = ''
            verifiedPublisher          = $null
            appOwnerOrganizationId     = 'cdc5aeea-15c5-4db6-b079-fcadd2505dc2'
            tags                       = @()
            NormalizedAppId            = '09213cdc-9f30-4e82-aa6f-9b6e8d82dab3'
            NormalizedPublisherName    = ''
            NormalizedVerifiedPublisherName = ''
            NormalizedAppOwnerOrganizationId = 'cdc5aeea-15c5-4db6-b079-fcadd2505dc2'
            NormalizedServicePrincipalType   = 'Application'
            NormalizedTags             = @()
        }
        $flipgrid = [pscustomobject]@{
            Id                         = 'sp-live-flipgrid'
            AppId                      = 'f1143447-b07a-4557-b878-b78df8d45c13'
            DisplayName                = 'Flipgrid'
            appDisplayName             = 'Flipgrid'
            servicePrincipalType       = 'Application'
            publisherName              = ''
            verifiedPublisher          = $null
            appOwnerOrganizationId     = '1bf12738-0df6-4c07-97c3-0b0642a2f1a0'
            tags                       = @()
            NormalizedAppId            = 'f1143447-b07a-4557-b878-b78df8d45c13'
            NormalizedPublisherName    = ''
            NormalizedVerifiedPublisherName = ''
            NormalizedAppOwnerOrganizationId = '1bf12738-0df6-4c07-97c3-0b0642a2f1a0'
            NormalizedServicePrincipalType   = 'Application'
            NormalizedTags             = @()
        }
        $iosAccounts = [pscustomobject]@{
            Id                         = 'sp-live-ios'
            AppId                      = 'f8d98a96-0999-43f5-8af3-69971c7bb423'
            DisplayName                = 'iOS Accounts'
            appDisplayName             = 'iOS Accounts'
            servicePrincipalType       = 'Application'
            publisherName              = ''
            verifiedPublisher          = [pscustomobject]@{ displayName = 'Apple Inc.' }
            appOwnerOrganizationId     = 'e0fad04c-a04c-41ab-b35e-dc523af755a1'
            tags                       = @()
            NormalizedAppId            = 'f8d98a96-0999-43f5-8af3-69971c7bb423'
            NormalizedPublisherName    = ''
            NormalizedVerifiedPublisherName = 'Apple Inc.'
            NormalizedAppOwnerOrganizationId = 'e0fad04c-a04c-41ab-b35e-dc523af755a1'
            NormalizedServicePrincipalType   = 'Application'
            NormalizedTags             = @()
        }

        (Test-DecomMicrosoftPlatformIdentity -NhiObject $graphPowerShell).MicrosoftPlatform | Should -Be $true
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $graphPowerShell).Reason | Should -Not -BeNullOrEmpty
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $techCommunity).MicrosoftPlatform | Should -Be $true
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $techCommunity).CatalogSource | Should -Be 'PlatformCatalog'
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $techCommunity).Reason | Should -Not -BeNullOrEmpty
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $flipgrid).MicrosoftPlatform | Should -Be $true
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $flipgrid).CatalogSource | Should -Be 'PlatformCatalog'
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $flipgrid).Reason | Should -Not -BeNullOrEmpty
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $iosAccounts).Classification | Should -Be 'ExternalVendorPlatform'
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $iosAccounts).MicrosoftPlatform | Should -Be $false
        (Test-DecomMicrosoftPlatformIdentity -NhiObject $iosAccounts).MicrosoftFirstParty | Should -Be $false

        $null = Set-DecomFindingTraceContext -SourceObject $graphPowerShell -ClassificationSource 'LiveGraph'
        $sanitized = New-DecomFinding `
            -FindingId 'DEC-NHI-002' `
            -Category 'NHI Ownership' `
            -Severity 'High' `
            -RiskScore 62 `
            -Confidence 'High' `
            -ObjectType 'ServicePrincipal' `
            -ObjectId 'sp-live-graph' `
            -DisplayName 'Microsoft Graph PowerShell' `
            -Evidence 'NHI has no owner assigned' `
            -EvidenceSource 'graph' `
            -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/sp-live-graph/owners' `
            -RecommendedAction 'Assign accountable owner / AddApplicationOwner / revoke consent' `
            -RemediationMode 'ManualApprovalRequired'

        $sanitized.MicrosoftPlatform | Should -Be $true
        $sanitized.FirstPartyMicrosoftApp | Should -Be $true
        $sanitized.Classification | Should -Be 'MicrosoftPlatform'
        $sanitized.RemediationMode | Should -Be 'InformationOnly'
        $sanitized.RecommendedAction | Should -Be 'Evidence only - Microsoft platform identity'
        $sanitized.NormalizedAppId | Should -Be '14d82eec-204b-4c2f-b7e8-296a70dab67e'
        $sanitized.NormalizedVerifiedPublisherName | Should -Be 'Microsoft Corporation'

        $null = Set-DecomFindingTraceContext -SourceObject $iosAccounts -ClassificationSource 'LiveGraph'
        $iosFinding = New-DecomFinding `
            -FindingId 'NHI-PERM-002' `
            -Category 'PermissionScopeRisk' `
            -Severity 'Medium' `
            -RiskScore 8 `
            -Confidence 'High' `
            -ObjectType 'ServicePrincipal' `
            -ObjectId 'sp-live-ios' `
            -DisplayName 'iOS Accounts' `
            -Evidence 'Permission unit count is 6 (>= 5 and < 10)' `
            -EvidenceSource 'graph' `
            -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/sp-live-ios' `
            -RecommendedAction 'Review permissions for necessity; reduce if possible' `
            -RemediationMode 'ManualApprovalRequired'

        $iosFinding.Classification | Should -Be 'ExternalVendorPlatform'
        $iosFinding.MicrosoftPlatform | Should -Be $false
        $iosFinding.FirstPartyMicrosoftApp | Should -Be $false
        $iosFinding.RemediationMode | Should -Be 'InformationOnly'
        $iosFinding.RecommendedAction | Should -Be 'Evidence only - external vendor platform identity'

        Clear-DecomFindingTraceContext
    }

    It 'Microsoft platform service principals do not produce owner, credential, or sign-in remediation strings' {
        $sp = [pscustomobject]@{
            Id                              = [guid]::NewGuid().Guid
            AppId                           = '1b730954-1685-4b74-9bfd-dac224a7b894'
            DisplayName                     = 'Microsoft Graph PowerShell'
            appDisplayName                  = 'Microsoft Graph PowerShell'
            servicePrincipalType            = 'Application'
            publisherName                   = ''
            verifiedPublisher               = [pscustomobject]@{ displayName = 'Microsoft' }
            appOwnerOrganizationId          = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
            tags                            = @('WindowsAzureActiveDirectoryIntegratedApp')
            OwnerCount                      = 0
            HighRiskPermissionCount         = 2
            HighRiskOAuthGrantCount         = 1
            CredentialCount                 = 1
            TenantWideConsent               = $true
            Classification                  = 'LikelyAutomation'
            ClassificationConfidence        = 'Medium'
            ClassificationSignals           = @('legacy-signal')
            ClassificationSource            = 'LiveGraph'
            MicrosoftPlatformReason         = 'MicrosoftOwnerTenant'
            MicrosoftFirstParty             = $true
            FirstPartyMicrosoftApp          = $true
            MicrosoftPlatform               = $true
            EvidenceOnly                    = $true
            NormalizedAppId                 = '1b730954-1685-4b74-9bfd-dac224a7b894'
            NormalizedPublisherName         = ''
            NormalizedVerifiedPublisherName = 'Microsoft'
            NormalizedAppOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
            NormalizedServicePrincipalType  = 'Application'
            NormalizedTags                  = @('WindowsAzureActiveDirectoryIntegratedApp')
        }
        $owners = @{}
        $owners[$sp.Id] = @()
        $ownerFindings = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $owners
        $credentialFindings = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
        $signInFindings = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}

        foreach ($finding in @(@($ownerFindings) + @($credentialFindings) + @($signInFindings))) {
            $finding.MicrosoftPlatform | Should -Be $true
            $finding.FirstPartyMicrosoftApp | Should -Be $true
            $finding.RemediationMode | Should -Be 'InformationOnly'
            $finding.RecommendedAction | Should -Be 'Evidence only - Microsoft platform identity'
            $finding.RecommendedAction | Should -Not -Match 'ManualApprovalRequired|Assign accountable owner|AddApplicationOwner|Revoke consent|Verify publisher|Reduce permission scope'
        }
    }

    It 'Microsoft platform findings do not resolve executable targets for approval planning' {
        $finding = New-DecomFinding `
            -FindingId 'DEC-SPN-001' `
            -Category 'Application' `
            -Severity 'Medium' `
            -RiskScore 44 `
            -Confidence 'High' `
            -ObjectType 'ServicePrincipal' `
            -ObjectId 'spn-002' `
            -DisplayName 'Flipgrid' `
            -Evidence 'Service principal has no owner assigned' `
            -EvidenceSource 'graph' `
            -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/spn-002/owners' `
            -RecommendedAction 'Assign accountable owner to service principal' `
            -RemediationMode 'ManualApprovalRequired' `
            -FirstPartyMicrosoftApp $true `
            -MicrosoftPlatform $true `
            -MicrosoftPlatformReason 'MicrosoftOwnerTenant'

        $targets = Resolve-DecomExecutableTargets -Finding $finding
        $targets.Resolved | Should -Be $false
        $targets.TargetObjects.Count | Should -Be 0
        $targets.ErrorDetail | Should -Match 'evidence-only'
    }
}
