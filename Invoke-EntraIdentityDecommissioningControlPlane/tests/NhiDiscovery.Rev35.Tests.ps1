#Requires -Version 5.1

Describe 'NhiDiscovery.Rev35 — NHI Discovery Module' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','NhiDiscovery')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')      -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiDiscovery.psm1')   -Force -DisableNameChecking

        $script:DemoContext = [PSCustomObject]@{ DemoMode = $true;  OutputPath = $env:TEMP }
        $script:RealContext = [PSCustomObject]@{ DemoMode = $false; OutputPath = $env:TEMP }
    }

    AfterAll {
        foreach ($m in @('NhiDiscovery','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Module structure ───────────────────────────────────────────────────────

    Context 'Module exports and safety' {

        It 'Exports Invoke-DecomNhiDiscovery' {
            Get-Command Invoke-DecomNhiDiscovery -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports New-DecomNhiSyntheticData' {
            Get-Command New-DecomNhiSyntheticData -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Get-DecomNhiHighRiskPermissions' {
            Get-Command Get-DecomNhiHighRiskPermissions -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Module contains no write cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication|Invoke-MgGraphRequest'
        }

        It 'Module does not request write scopes' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Connect-MgGraph.*Application\.ReadWrite|Connect-MgGraph.*GroupMember\.ReadWrite|Connect-MgGraph.*RoleManagement\.ReadWrite|Connect-MgGraph.*EntitlementManagement\.ReadWrite'
        }
    }

    # ── DemoMode discovery ─────────────────────────────────────────────────────

    Context 'Invoke-DecomNhiDiscovery in DemoMode' {

        BeforeAll {
            $script:DemoResults = Invoke-DecomNhiDiscovery -Context $script:DemoContext
        }

        It 'Returns a non-empty collection' {
            $script:DemoResults | Should -Not -BeNullOrEmpty
        }

        It 'Returns at least 3 NHI objects' {
            $script:DemoResults.Count | Should -BeGreaterOrEqual 3
        }

        It 'Each NHI object has ObjectId' {
            $script:DemoResults | ForEach-Object { $_.ObjectId | Should -Not -BeNullOrEmpty }
        }

        It 'Each NHI object has DisplayName' {
            $script:DemoResults | ForEach-Object { $_.DisplayName | Should -Not -BeNullOrEmpty }
        }

        It 'Each NHI object has ObjectType' {
            $script:DemoResults | ForEach-Object { $_.ObjectType | Should -BeIn @('ServicePrincipal','Application') }
        }

        It 'Includes a ServiceIdentity type service principal' {
            $serviceIdentity = $script:DemoResults | Where-Object { $_.ServicePrincipalType -eq 'ServiceIdentity' }
            $serviceIdentity | Should -Not -BeNullOrEmpty
        }

        It 'Includes an SP with naming pattern matching agent/automation' {
            $agentLike = $script:DemoResults | Where-Object { $_.DisplayName -match 'agent|copilot|automation|workflow|runner' }
            $agentLike | Should -Not -BeNullOrEmpty
        }

        It 'SP with credential has CredentialCount > 0' {
            $withCred = $script:DemoResults | Where-Object { $_.DisplayName -match 'copilot' }
            if ($withCred) { $withCred.CredentialCount | Should -BeGreaterThan 0 }
        }

        It 'SP with owner has OwnerCount > 0' {
            $withOwner = $script:DemoResults | Where-Object { $_.OwnerCount -gt 0 }
            $withOwner | Should -Not -BeNullOrEmpty
        }

        It 'Each NHI object has CoverageMode property' {
            $script:DemoResults | ForEach-Object { $_.CoverageMode | Should -Not -BeNullOrEmpty }
        }

        It 'Each NHI object has EvidenceSource set to graph' {
            $script:DemoResults | ForEach-Object { $_.EvidenceSource | Should -Be 'graph' }
        }
    }

    # ── Synthetic data structure ───────────────────────────────────────────────

    Context 'New-DecomNhiSyntheticData structure' {

        BeforeAll {
            $script:SyntheticData = New-DecomNhiSyntheticData
        }

        It 'Returns object with ServicePrincipals' {
            $script:SyntheticData.ServicePrincipals | Should -Not -BeNullOrEmpty
        }

        It 'Has at least 4 service principals' {
            $script:SyntheticData.ServicePrincipals.Count | Should -BeGreaterOrEqual 4
        }

        It 'Includes Microsoft first-party SP' {
            $msft = $script:SyntheticData.ServicePrincipals | Where-Object { $_.PublisherName -eq 'Microsoft Corporation' }
            $msft | Should -Not -BeNullOrEmpty
        }

        It 'Includes SP with pre-populated Owners field' {
            $withOwner = $script:SyntheticData.ServicePrincipals | Where-Object { $_.PSObject.Properties.Name -contains 'Owners' }
            $withOwner | Should -Not -BeNullOrEmpty
        }

        It 'Includes SP with pre-populated Credentials field' {
            $withCred = $script:SyntheticData.ServicePrincipals | Where-Object { $_.PSObject.Properties.Name -contains 'Credentials' }
            $withCred | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Live-shaped Microsoft metadata normalization' {
        It 'Recognizes Microsoft platform service principal from nested live metadata' {
            $sp = [PSCustomObject]@{
                id                    = 'sp-live-001'
                appId                 = '1b730954-1685-4b74-9bfd-dac224a7b894'
                displayName           = 'Microsoft Graph PowerShell'
                appDisplayName        = 'Microsoft Graph PowerShell'
                servicePrincipalType   = 'Application'
                publisherName         = $null
                verifiedPublisher     = [PSCustomObject]@{ displayName = 'Microsoft' }
                signInAudience        = 'AzureADMyOrg'
                accountEnabled        = $true
                createdDateTime       = '2024-01-01T00:00:00Z'
                tags                  = @('WindowsAzureActiveDirectoryIntegratedApp')
                homepage              = 'https://example.invalid'
                appOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
                keyCredentials        = @()
                passwordCredentials   = @()
            }

            Mock Get-MgServicePrincipal { @($sp) } -ModuleName NhiDiscovery
            Mock Get-MgApplication { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOwner { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalAppRoleAssignment { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOauth2PermissionGrant { @() } -ModuleName NhiDiscovery

            $ctx = [PSCustomObject]@{ DemoMode = $false; OutputPath = $env:TEMP }
            $results = Invoke-DecomNhiDiscovery -Context $ctx
            $msft = $results | Where-Object { $_.ObjectId -eq 'sp-live-001' }

            $msft | Should -Not -BeNullOrEmpty
            $msft.MicrosoftPlatform | Should -Be $true
            $msft.MicrosoftFirstParty | Should -Be $true
            $msft.VerifiedPublisherName | Should -Be 'Microsoft'
            $msft.AppOwnerOrganizationId | Should -Be 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
        }

        It 'Recognizes exact live Microsoft platform app IDs and preserves Apple vendor attribution' {
            $liveServicePrincipals = @(
                [PSCustomObject]@{
                    id                    = 'sp-live-graph'
                    appId                 = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
                    displayName           = 'Microsoft Graph PowerShell'
                    appDisplayName        = 'Microsoft Graph PowerShell'
                    servicePrincipalType   = 'Application'
                    publisherName         = ''
                    verifiedPublisher     = [PSCustomObject]@{ displayName = 'Microsoft Corporation' }
                    appOwnerOrganizationId = '72f988bf-86f1-41af-91ab-2d7cd011db47'
                    tags                  = @('WindowsAzureActiveDirectoryIntegratedApp')
                    signInAudience        = 'AzureADMyOrg'
                    accountEnabled        = $true
                    createdDateTime       = '2024-01-01T00:00:00Z'
                    keyCredentials        = @()
                    passwordCredentials   = @()
                },
                [PSCustomObject]@{
                    id                    = 'sp-live-tech'
                    appId                 = '09213cdc-9f30-4e82-aa6f-9b6e8d82dab3'
                    displayName           = 'Microsoft Tech Community'
                    appDisplayName        = 'Microsoft Tech Community'
                    servicePrincipalType   = 'Application'
                    publisherName         = ''
                    verifiedPublisher     = $null
                    appOwnerOrganizationId = 'cdc5aeea-15c5-4db6-b079-fcadd2505dc2'
                    tags                  = @()
                    signInAudience        = 'AzureADMyOrg'
                    accountEnabled        = $true
                    createdDateTime       = '2024-01-01T00:00:00Z'
                    keyCredentials        = @()
                    passwordCredentials   = @()
                },
                [PSCustomObject]@{
                    id                    = 'sp-live-flipgrid'
                    appId                 = 'f1143447-b07a-4557-b878-b78df8d45c13'
                    displayName           = 'Flipgrid'
                    appDisplayName        = 'Flipgrid'
                    servicePrincipalType   = 'Application'
                    publisherName         = ''
                    verifiedPublisher     = $null
                    appOwnerOrganizationId = '1bf12738-0df6-4c07-97c3-0b0642a2f1a0'
                    tags                  = @()
                    signInAudience        = 'AzureADMyOrg'
                    accountEnabled        = $true
                    createdDateTime       = '2024-01-01T00:00:00Z'
                    keyCredentials        = @()
                    passwordCredentials   = @()
                },
                [PSCustomObject]@{
                    id                    = 'sp-live-ios'
                    appId                 = 'f8d98a96-0999-43f5-8af3-69971c7bb423'
                    displayName           = 'iOS Accounts'
                    appDisplayName        = 'iOS Accounts'
                    servicePrincipalType   = 'Application'
                    publisherName         = ''
                    verifiedPublisher     = [PSCustomObject]@{ displayName = 'Apple Inc.' }
                    appOwnerOrganizationId = 'e0fad04c-a04c-41ab-b35e-dc523af755a1'
                    tags                  = @()
                    signInAudience        = 'AzureADMyOrg'
                    accountEnabled        = $true
                    createdDateTime       = '2024-01-01T00:00:00Z'
                    keyCredentials        = @()
                    passwordCredentials   = @()
                }
            )

            Mock Get-MgServicePrincipal { @($liveServicePrincipals) } -ModuleName NhiDiscovery
            Mock Get-MgApplication { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOwner { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalAppRoleAssignment { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOauth2PermissionGrant { @() } -ModuleName NhiDiscovery

            $ctx = [PSCustomObject]@{ DemoMode = $false; OutputPath = $env:TEMP }
            $results = Invoke-DecomNhiDiscovery -Context $ctx

            ($results | Where-Object { $_.AppId -eq '14d82eec-204b-4c2f-b7e8-296a70dab67e' }).MicrosoftPlatform | Should -Be $true
            ($results | Where-Object { $_.AppId -eq '09213cdc-9f30-4e82-aa6f-9b6e8d82dab3' }).MicrosoftPlatform | Should -Be $true
            ($results | Where-Object { $_.AppId -eq 'f1143447-b07a-4557-b878-b78df8d45c13' }).MicrosoftPlatform | Should -Be $true
            ($results | Where-Object { $_.AppId -eq '14d82eec-204b-4c2f-b7e8-296a70dab67e' }).MicrosoftPlatformReason | Should -Not -BeNullOrEmpty
            ($results | Where-Object { $_.AppId -eq '14d82eec-204b-4c2f-b7e8-296a70dab67e' }).IsVerifiedPublisher | Should -Be $true
            ($results | Where-Object { $_.AppId -eq '09213cdc-9f30-4e82-aa6f-9b6e8d82dab3' }).IsVerifiedPublisher | Should -Be $false
            ($results | Where-Object { $_.AppId -eq 'f1143447-b07a-4557-b878-b78df8d45c13' }).IsVerifiedPublisher | Should -Be $false

            $ios = $results | Where-Object { $_.AppId -eq 'f8d98a96-0999-43f5-8af3-69971c7bb423' }
            $ios.MicrosoftPlatform | Should -Be $false
            $ios.MicrosoftFirstParty | Should -Be $false
            $ios.VerifiedPublisherName | Should -Be 'Apple Inc.'
            $ios.IsVerifiedPublisher | Should -Be $true
        }
    }

    # ── High-risk permission detection ─────────────────────────────────────────

    Context 'Get-DecomNhiHighRiskPermissions detection' {

        It 'Returns empty for no assignments or grants' {
            $result = Get-DecomNhiHighRiskPermissions -AppRoleAssignments @() -OAuthGrants @()
            $result.Count | Should -Be 0
        }

        It 'Detects high-risk app role assignment' {
            $assignment = [PSCustomObject]@{
                AdditionalProperties = @{ appRoleId = 'Directory.ReadWrite.All' }
            }
            $result = Get-DecomNhiHighRiskPermissions -AppRoleAssignments @($assignment) -OAuthGrants @()
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Detects high-risk delegated OAuth grant scope' {
            $grant = [PSCustomObject]@{ Scope = 'offline_access Directory.AccessAsUser.All' }
            $result = Get-DecomNhiHighRiskPermissions -AppRoleAssignments @() -OAuthGrants @($grant)
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Does not flag low-risk scope as high-risk' {
            $grant = [PSCustomObject]@{ Scope = 'User.Read openid profile' }
            $result = Get-DecomNhiHighRiskPermissions -AppRoleAssignments @() -OAuthGrants @($grant)
            $result.Count | Should -Be 0
        }
    }

    # ── PS5.1 requirement ─────────────────────────────────────────────────────

    Context 'Module PS version requirement' {

        It 'NhiDiscovery module declares PS5.1 requirement' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Match '#Requires -Version 5\.1'
        }
    }

    # ── RiskScoreMayBeUnderstated flag ────────────────────────────────────────

    Context 'RiskScoreMayBeUnderstated coverage flag' {

        It 'RiskScoreMayBeUnderstated is true when OAuth grant collection fails' {
            # Mock Get-MgServicePrincipalOauth2PermissionGrant to throw
            Mock Get-MgServicePrincipalOauth2PermissionGrant { throw 'Insufficient privileges' } -ModuleName NhiDiscovery

            $sp = [PSCustomObject]@{
                Id = 'sp-test-001'; AppId = 'app-001'; DisplayName = 'test-sp'
                ServicePrincipalType = 'Application'; PublisherName = 'TestCorp'
                VerifiedPublisher = $null; AccountEnabled = $true; Tags = @()
                AppOwnerOrganizationId = 'tenant-001'
                KeyCredentials = @(); PasswordCredentials = @()
            }
            Mock Get-MgServicePrincipal { @($sp) } -ModuleName NhiDiscovery
            Mock Get-MgApplication { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOwner { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalAppRoleAssignment { @() } -ModuleName NhiDiscovery

            $ctx = [PSCustomObject]@{ DemoMode = $false; OutputPath = $env:TEMP }
            $results = Invoke-DecomNhiDiscovery -Context $ctx
            $results | Where-Object { $_.DisplayName -eq 'test-sp' } |
                Select-Object -ExpandProperty RiskScoreMayBeUnderstated |
                Should -Be $true
        }

        It 'RiskScoreMayBeUnderstated is true when app role assignment collection fails' {
            Mock Get-MgServicePrincipalAppRoleAssignment { throw 'Insufficient privileges' } -ModuleName NhiDiscovery

            $sp = [PSCustomObject]@{
                Id = 'sp-test-002'; AppId = 'app-002'; DisplayName = 'test-sp-approle'
                ServicePrincipalType = 'Application'; PublisherName = 'TestCorp'
                VerifiedPublisher = $null; AccountEnabled = $true; Tags = @()
                AppOwnerOrganizationId = 'tenant-001'
                KeyCredentials = @(); PasswordCredentials = @()
            }
            Mock Get-MgServicePrincipal { @($sp) } -ModuleName NhiDiscovery
            Mock Get-MgApplication { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOwner { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOauth2PermissionGrant { @() } -ModuleName NhiDiscovery

            $ctx = [PSCustomObject]@{ DemoMode = $false; OutputPath = $env:TEMP }
            $results = Invoke-DecomNhiDiscovery -Context $ctx
            $results | Where-Object { $_.DisplayName -eq 'test-sp-approle' } |
                Select-Object -ExpandProperty RiskScoreMayBeUnderstated |
                Should -Be $true
        }

        It 'RiskScoreMayBeUnderstated is false when all evidence collected successfully' {
            $sp = [PSCustomObject]@{
                Id = 'sp-test-003'; AppId = 'app-003'; DisplayName = 'test-sp-clean'
                ServicePrincipalType = 'Application'; PublisherName = 'TestCorp'
                VerifiedPublisher = $null; AccountEnabled = $true; Tags = @()
                AppOwnerOrganizationId = 'tenant-001'
                KeyCredentials = @(); PasswordCredentials = @()
            }
            Mock Get-MgServicePrincipal { @($sp) } -ModuleName NhiDiscovery
            Mock Get-MgApplication { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOwner { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalAppRoleAssignment { @() } -ModuleName NhiDiscovery
            Mock Get-MgServicePrincipalOauth2PermissionGrant { @() } -ModuleName NhiDiscovery

            $ctx = [PSCustomObject]@{ DemoMode = $false; OutputPath = $env:TEMP }
            $results = Invoke-DecomNhiDiscovery -Context $ctx
            $results | Where-Object { $_.DisplayName -eq 'test-sp-clean' } |
                Select-Object -ExpandProperty RiskScoreMayBeUnderstated |
                Should -Be $false
        }
    }
}
