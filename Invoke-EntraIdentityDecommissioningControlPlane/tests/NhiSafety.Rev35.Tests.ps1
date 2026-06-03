#Requires -Version 5.1

Describe 'NhiSafety.Rev35 — NHI Module Safety Invariants' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        $script:NhiModules = @('NhiDiscovery', 'NhiAnalysis', 'NhiGovernance', 'NhiReporting')
        $script:NhiModulePaths = $script:NhiModules | ForEach-Object {
            Join-Path $script:ModulesPath "$_.psm1"
        }
    }

    # ── No write cmdlets in any NHI module ────────────────────────────────────

    Context 'Write cmdlet exclusion' {

        It 'NhiDiscovery contains no Remove-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg'
        }

        It 'NhiDiscovery contains no Update-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Update-Mg'
        }

        It 'NhiDiscovery contains no Set-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Set-Mg'
        }

        It 'NhiDiscovery contains no New-MgApplication cmdlet' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'New-MgApplication'
        }

        It 'NhiAnalysis contains no Remove-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg'
        }

        It 'NhiAnalysis contains no Update-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'Update-Mg'
        }

        It 'NhiAnalysis contains no Set-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'Set-Mg'
        }

        It 'NhiGovernance contains no Remove-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg'
        }

        It 'NhiGovernance contains no Update-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Update-Mg'
        }

        It 'NhiGovernance contains no Set-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Set-Mg'
        }

        It 'NhiReporting contains no Remove-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiReporting.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg'
        }

        It 'NhiReporting contains no Update-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiReporting.psm1') -Raw
            $content | Should -Not -Match 'Update-Mg'
        }

        It 'NhiReporting contains no Set-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiReporting.psm1') -Raw
            $content | Should -Not -Match 'Set-Mg'
        }
    }

    # ── No write scopes in NHI discovery ──────────────────────────────────────

    Context 'Write scope exclusion' {

        It 'NhiDiscovery does not request Application.ReadWrite scope' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Connect-MgGraph.*Application\.ReadWrite'
        }

        It 'NhiDiscovery does not request GroupMember.ReadWrite scope' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'GroupMember\.ReadWrite'
        }

        It 'NhiDiscovery does not request RoleManagement.ReadWrite scope' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Connect-MgGraph.*RoleManagement\.ReadWrite'
        }

        It 'NhiDiscovery does not request EntitlementManagement.ReadWrite scope' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Connect-MgGraph.*EntitlementManagement\.ReadWrite'
        }

        It 'NhiAnalysis does not request any ReadWrite scope' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'ReadWrite'
        }

        It 'NhiGovernance does not request any ReadWrite scope' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'ReadWrite'
        }

        It 'NhiReporting does not request any ReadWrite scope' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiReporting.psm1') -Raw
            $content | Should -Not -Match 'ReadWrite'
        }
    }

    # ── No Invoke-MgGraphRequest in NHI modules ────────────────────────────────

    Context 'Invoke-MgGraphRequest exclusion' {

        It 'NhiDiscovery does not use Invoke-MgGraphRequest' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Invoke-MgGraphRequest'
        }

        It 'NhiAnalysis does not use Invoke-MgGraphRequest' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'Invoke-MgGraphRequest'
        }

        It 'NhiGovernance does not use Invoke-MgGraphRequest' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Invoke-MgGraphRequest'
        }
    }

    # ── Finding ID namespace compliance ───────────────────────────────────────

    Context 'Finding ID namespace — DEC-NHI-* and DEC-AGENT-*' {

        It 'NhiGovernance uses DEC-NHI- prefix for NHI findings' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Match 'DEC-NHI-'
        }

        It 'NhiGovernance uses DEC-AGENT- prefix for agentic findings' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Match 'DEC-AGENT-'
        }

        It 'NhiGovernance does not use legacy DEC-CRED- finding IDs' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'DEC-CRED-'
        }

        It 'NhiGovernance does not use DEC-PERM- finding IDs' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'DEC-PERM-'
        }
    }

    # ── No service principal / application destructive cmdlets ────────────────

    Context 'Destructive identity cmdlet exclusion' {

        It 'NhiDiscovery does not call Remove-MgServicePrincipal' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Remove-MgServicePrincipal'
        }

        It 'NhiAnalysis does not call Remove-MgServicePrincipal' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'Remove-MgServicePrincipal'
        }

        It 'NhiGovernance does not call Remove-MgServicePrincipal' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Remove-MgServicePrincipal'
        }

        It 'NhiDiscovery does not call Remove-MgApplication' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Remove-MgApplication'
        }

        It 'NhiAnalysis does not call Remove-MgApplication' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'Remove-MgApplication'
        }

        It 'NhiGovernance does not call Remove-MgApplication' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Remove-MgApplication'
        }
    }

    # ── Module files exist ─────────────────────────────────────────────────────

    Context 'NHI module files present' {

        It 'NhiDiscovery.psm1 exists' {
            Test-Path (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') | Should -Be $true
        }

        It 'NhiAnalysis.psm1 exists' {
            Test-Path (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') | Should -Be $true
        }

        It 'NhiGovernance.psm1 exists' {
            Test-Path (Join-Path $script:ModulesPath 'NhiGovernance.psm1') | Should -Be $true
        }

        It 'NhiReporting.psm1 exists' {
            Test-Path (Join-Path $script:ModulesPath 'NhiReporting.psm1') | Should -Be $true
        }
    }

    # ── Policy.ReadWrite exclusion ─────────────────────────────────────────────

    Context 'Policy write scope exclusion' {

        It 'NhiDiscovery does not request Policy.ReadWrite' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Raw
            $content | Should -Not -Match 'Connect-MgGraph.*Policy\.ReadWrite'
        }

        It 'NhiAnalysis does not request Policy.ReadWrite' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'Policy\.ReadWrite'
        }

        It 'NhiGovernance does not request Policy.ReadWrite' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Policy\.ReadWrite'
        }

        It 'NhiReporting does not request Policy.ReadWrite' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiReporting.psm1') -Raw
            $content | Should -Not -Match 'Policy\.ReadWrite'
        }
    }
}
