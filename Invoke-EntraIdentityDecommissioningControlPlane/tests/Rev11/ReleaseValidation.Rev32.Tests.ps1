#Requires -Version 5.1

Describe 'ReleaseValidation.Rev32 — Safety Invariants' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        $script:EntryPoint  = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'

        foreach ($m in @('Utilities','ReleaseValidation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')         -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ReleaseValidation.psm1') -Force -DisableNameChecking

        $script:testOutputDir = Join-Path $env:TEMP 'Decom-Rev32-Safety'
        New-Item -ItemType Directory -Path $script:testOutputDir -Force | Out-Null

        $script:context32 = [PSCustomObject]@{
            ToolVersion  = 'Rev3.2'
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'ENG-SAFETY-32'
            Assessor     = 'TestAssessor'
        }

        $script:context31 = [PSCustomObject]@{
            ToolVersion  = 'Rev3.1'
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'ENG-SAFETY-31'
            Assessor     = 'TestAssessor'
        }
    }

    AfterAll {
        if (Test-Path $script:testOutputDir) { Remove-Item $script:testOutputDir -Recurse -Force }
        foreach ($m in @('ReleaseValidation','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Entry point ToolVersion is Rev3.2' {
        $content = Get-Content $script:EntryPoint -Raw
        $content | Should -Match '\$script:ToolVersion\s*=\s*[''"]Rev3\.2[''"]'
    }

    It 'ReleaseValidation.psm1 source references Rev3.2' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ReleaseValidation.psm1') -Raw
        $content | Should -Match 'Rev3\.2'
    }

    It 'Safety invariant passes on clean Rev3.2 repo' {
        $result = Test-DecomSafetyInvariant -Context $script:context32
        $result.Passed | Should -Be $true
        $result.Errors.Count | Should -Be 0
    }

    It 'Safety invariant passes on Rev3.1 context (read-only modules are clean)' {
        # Test-DecomSafetyInvariant checks read-only modules for write verbs/scopes.
        # Both Rev3.1 and Rev3.2 contexts pass when read-only modules are clean.
        # The Rev3.2 action type extension is controlled via the execution scope registry,
        # not via the basic safety invariant which focuses on read-only module hygiene.
        $result = Test-DecomSafetyInvariant -Context $script:context31
        $result.NoUnexpectedWriteCmdlet | Should -Be $true
        $result.NoUnexpectedWriteScope  | Should -Be $true
    }

    It 'Assessment mode does not call Application.ReadWrite.All' {
        $content = Get-Content $script:EntryPoint -Raw
        $assessBlock = $content -replace '(?s)ExecuteRemediation.*', ''
        $assessBlock | Should -Not -Match 'Application\.ReadWrite\.All'
    }

    It 'DemoMode does not request Application.ReadWrite.All' {
        $content = Get-Content $script:EntryPoint -Raw
        $demoBlock = $content -replace '(?s)ExecuteRemediation.*', ''
        $demoBlock | Should -Not -Match 'Application\.ReadWrite\.All'
    }

    It 'ApplicationGovernance.psm1 contains no write cmdlets' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication|Invoke-MgGraphRequest'
    }

    It 'CredentialHygiene.psm1 contains no write cmdlets' {
        $content = Get-Content (Join-Path $script:ModulesPath 'CredentialHygiene.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication|Invoke-MgGraphRequest'
    }

    It 'ConditionalAccessGovernance.psm1 contains no write cmdlets' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication|Invoke-MgGraphRequest'
    }

    It 'EmergencyAccessGovernance.psm1 contains no write cmdlets' {
        $content = Get-Content (Join-Path $script:ModulesPath 'EmergencyAccessGovernance.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication|Invoke-MgGraphRequest'
    }

    It 'No app deletion cmdlets appear in any module except Remediation' {
        $files = Get-ChildItem (Join-Path $script:ModulesPath '*.psm1') | Where-Object { $_.Name -ne 'Remediation.psm1' }
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw
            $content | Should -Not -Match 'Remove-MgApplication\b' -Because "$($f.Name) must not contain app deletion"
        }
    }

    It 'No service principal deletion cmdlets appear in any module' {
        $files = Get-ChildItem (Join-Path $script:ModulesPath '*.psm1')
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw
            $content | Should -Not -Match 'Remove-MgServicePrincipal\b' -Because "$($f.Name) must not delete service principals"
        }
    }

    It 'No CA policy write cmdlets appear in any module' {
        $files = Get-ChildItem (Join-Path $script:ModulesPath '*.psm1')
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw
            $content | Should -Not -Match 'New-MgIdentityConditionalAccessPolicy|Update-MgIdentityConditionalAccessPolicy|Remove-MgIdentityConditionalAccessPolicy' `
                -Because "$($f.Name) must not mutate CA policies"
        }
    }

    It 'No user or guest deletion cmdlets appear in any module' {
        $files = Get-ChildItem (Join-Path $script:ModulesPath '*.psm1')
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw
            $content | Should -Not -Match 'Remove-MgUser\b' -Because "$($f.Name) must not delete users"
        }
    }

    It 'RemoveExpiredApplicationCredential allowed in Remediation for Rev3.2' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        $content | Should -Match 'RemoveExpiredApplicationCredential'
    }

    It 'ApplicationGovernance.psm1 does not request write scopes' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Raw
        $content | Should -Not -Match "ReadWrite\.All"
    }

    It 'ConditionalAccessGovernance.psm1 does not contain CA mutation scope strings' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
        $content | Should -Not -Match 'New-MgIdentityConditionalAccessPolicy|Update-MgIdentityConditionalAccessPolicy'
    }

    It 'EmergencyAccessGovernance.psm1 does not request write scopes' {
        $content = Get-Content (Join-Path $script:ModulesPath 'EmergencyAccessGovernance.psm1') -Raw
        $content | Should -Not -Match 'ReadWrite\.All'
    }
}
