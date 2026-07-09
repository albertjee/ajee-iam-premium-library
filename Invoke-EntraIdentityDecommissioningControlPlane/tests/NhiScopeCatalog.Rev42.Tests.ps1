# NhiScopeCatalog.Rev42.Tests.ps1
# Rev4.2 - canonical high-risk scope catalog (target I of docs/refactoring-plan.md).
# Verifies the catalog module exports the four lists verbatim and that the two
# consumer modules (NhiDiscovery, NhiPermission) source their lists from the
# catalog instead of defining inline copies.

BeforeAll {
    $script:ToolRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulesPath = Join-Path $script:ToolRoot 'src\Modules'
    $script:CatalogPath = Join-Path $script:ModulesPath 'NhiScopeCatalog.psm1'

    Remove-Module NhiScopeCatalog -Force -ErrorAction SilentlyContinue
    Import-Module $script:CatalogPath -Force -DisableNameChecking
    $script:Catalog = Get-NhiScopeCatalog
}

Describe 'NhiScopeCatalog module contract (Rev4.2)' {

    It 'parses with zero errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:CatalogPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'exports exactly one function: Get-NhiScopeCatalog' {
        $mod = Get-Module NhiScopeCatalog
        $mod | Should -Not -BeNullOrEmpty
        @($mod.ExportedFunctions.Keys) | Should -Be @('Get-NhiScopeCatalog')
    }

    It 'returns a hashtable with exactly the four expected keys' {
        $script:Catalog | Should -BeOfType [hashtable]
        @($script:Catalog.Keys | Sort-Object) | Should -Be @(
            'DiscoveryHighRiskAppPermissions',
            'DiscoveryHighRiskDelegatedScopes',
            'PermissionHighRiskAppRoles',
            'PermissionHighRiskDelegatedScopes'
        )
    }

    It 'contains no Graph connection or mutation cmdlets (data-only module)' {
        $content = Get-Content $script:CatalogPath -Raw
        $content | Should -Not -Match 'Connect-MgGraph'
        $content | Should -Not -Match '\b(New|Update|Remove|Set)-Mg[A-Za-z]'
    }
}

Describe 'NhiScopeCatalog list contents (verbatim snapshots)' {

    It 'DiscoveryHighRiskAppPermissions matches the pre-refactor NhiDiscovery list (14 entries)' {
        @($script:Catalog.DiscoveryHighRiskAppPermissions) | Should -Be @(
            'Directory.ReadWrite.All', 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All',
            'RoleManagement.ReadWrite.Directory', 'PrivilegedAccess.ReadWrite.AzureAD',
            'Group.ReadWrite.All', 'User.ReadWrite.All', 'Mail.ReadWrite', 'Mail.Send',
            'Files.ReadWrite.All', 'Sites.FullControl.All', 'AuditLog.Read.All',
            'Policy.ReadWrite.All', 'EntitlementManagement.ReadWrite.All'
        )
    }

    It 'DiscoveryHighRiskDelegatedScopes matches the pre-refactor NhiDiscovery list (12 entries)' {
        @($script:Catalog.DiscoveryHighRiskDelegatedScopes) | Should -Be @(
            'Directory.AccessAsUser.All', 'Directory.ReadWrite.All', 'Application.ReadWrite.All',
            'AppRoleAssignment.ReadWrite.All', 'User.Read.All', 'User.ReadWrite.All', 'Group.ReadWrite.All',
            'Mail.ReadWrite', 'Mail.Send', 'Files.ReadWrite.All', 'Sites.FullControl.All', 'offline_access'
        )
    }

    It 'PermissionHighRiskAppRoles matches the pre-refactor NhiPermission list (12 entries)' {
        @($script:Catalog.PermissionHighRiskAppRoles) | Should -Be @(
            'Directory.ReadWrite.All', 'User.ReadWrite.All', 'Group.ReadWrite.All',
            'Mail.ReadWrite', 'Mail.Send', 'Files.ReadWrite.All', 'Sites.FullControl.All',
            'RoleManagement.ReadWrite.Directory', 'Application.ReadWrite.All',
            'AppRoleAssignment.ReadWrite.All', 'Directory.AccessAsUser.All',
            'EntitlementManagement.ReadWrite.All'
        )
    }

    It 'PermissionHighRiskDelegatedScopes matches the pre-refactor NhiPermission list (8 entries)' {
        @($script:Catalog.PermissionHighRiskDelegatedScopes) | Should -Be @(
            'Directory.ReadWrite.All', 'User.ReadWrite.All', 'Mail.ReadWrite', 'Mail.Send',
            'Files.ReadWrite.All', 'Sites.FullControl.All', 'RoleManagement.ReadWrite.Directory',
            'Directory.AccessAsUser.All'
        )
    }

    It 'documents known Discovery vs Permission drift (Discovery-only detection scopes preserved)' {
        # These three were present in the Discovery list but absent from the Permission
        # lists before consolidation. The catalog must preserve that drift verbatim
        # until unification is decided deliberately (see module header comment).
        foreach ($scope in @('PrivilegedAccess.ReadWrite.AzureAD', 'AuditLog.Read.All', 'Policy.ReadWrite.All')) {
            $script:Catalog.DiscoveryHighRiskAppPermissions | Should -Contain $scope
            $script:Catalog.PermissionHighRiskAppRoles | Should -Not -Contain $scope
        }
    }
}

Describe 'NhiScopeCatalog consumer wiring (Rev4.2)' {

    It 'NhiDiscovery.psm1 imports the catalog and no longer defines inline high-risk arrays' {
        $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
        $content | Should -Match "Import-Module \(Join-Path \`$PSScriptRoot 'NhiScopeCatalog\.psm1'\)"
        $content | Should -Match '\$script:HighRiskAppPermissions = \$script:NhiScopeCatalog\.DiscoveryHighRiskAppPermissions'
        $content | Should -Match '\$script:HighRiskDelegatedScopes = \$script:NhiScopeCatalog\.DiscoveryHighRiskDelegatedScopes'
        $content | Should -Not -Match "\`$script:HighRiskAppPermissions = @\("
    }

    It 'NhiPermission.psm1 imports the catalog and no longer defines inline high-risk arrays' {
        $content = Get-Content (Join-Path $script:ModulesPath 'NhiPermission.psm1') -Raw
        $content | Should -Match "Import-Module \(Join-Path \`$PSScriptRoot 'NhiScopeCatalog\.psm1'\)"
        $content | Should -Match '\$script:HighRiskAppRoles = \$script:NhiScopeCatalog\.PermissionHighRiskAppRoles'
        $content | Should -Match '\$script:HighRiskDelegatedScopes = \$script:NhiScopeCatalog\.PermissionHighRiskDelegatedScopes'
        $content | Should -Not -Match "\`$script:HighRiskAppRoles = @\("
    }

    It 'NhiDiscovery.psm1 imports silently with the catalog wired in' {
        Remove-Module NhiDiscovery -Force -ErrorAction SilentlyContinue
        { Import-Module (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Force -DisableNameChecking -WarningAction Stop } | Should -Not -Throw
    }

    It 'NhiPermission.psm1 imports silently with the catalog wired in' {
        Remove-Module NhiPermission -Force -ErrorAction SilentlyContinue
        { Import-Module (Join-Path $script:ModulesPath 'NhiPermission.psm1') -Force -DisableNameChecking -WarningAction Stop } | Should -Not -Throw
    }

    It 'NhiPermission scan still flags a catalog-sourced high-risk delegated scope (no override)' {
        Remove-Module NhiPermission -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'NhiPermission.psm1') -Force -DisableNameChecking
        $sp = [PSCustomObject]@{ Id = 'sp-cat-001'; AppId = 'app-cat-001'; DisplayName = 'Catalog Test SP' }
        $grant = [PSCustomObject]@{ ClientId = 'sp-cat-001'; ConsentType = 'Principal'; Scope = 'Directory.ReadWrite.All' }
        $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants @($grant)
        $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-004' }
        $f | Should -Not -BeNullOrEmpty
        @($f)[0].Evidence | Should -Match 'Directory\.ReadWrite\.All'
    }
}
