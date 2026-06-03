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
