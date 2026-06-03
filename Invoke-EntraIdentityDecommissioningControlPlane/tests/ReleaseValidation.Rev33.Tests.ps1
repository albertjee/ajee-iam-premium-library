#Requires -Version 5.1
# INTENTIONAL_HISTORICAL_VERSION: Rev3.5 references are for historical test fixtures

Describe 'ReleaseValidation.Rev33 — Safety Invariants and Rev3.3 Action Safety' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        $script:EntryPoint  = Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'

        foreach ($m in @('Utilities','ReleaseValidation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')         -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ReleaseValidation.psm1') -Force -DisableNameChecking

        $script:testOutputDir = Join-Path $env:TEMP 'Decom-Rev33-Safety'
        New-Item -ItemType Directory -Path $script:testOutputDir -Force | Out-Null

        $script:context33 = [PSCustomObject]@{
            ToolVersion  = 'Rev3.3'
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'ENG-SAFETY-33'
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

    # ── Item 1-2: Entry point and version checks ──

    It 'Entry point ToolVersion is Rev3.6' {
        $content = Get-Content $script:EntryPoint -Raw
        $content | Should -Match '\$script:ToolVersion\s*=\s*[''"]Rev3\.6[''"]'
    }

    It 'ReleaseValidation.psm1 source references Rev3.2 (backward compat case)' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ReleaseValidation.psm1') -Raw
        $content | Should -Match 'Rev3\.2'
    }

    It 'Safety invariant passes on Rev3.3 context' {
        $result = Test-DecomSafetyInvariant -Context $script:context33
        $result.Passed | Should -Be $true
        $result.Errors.Count | Should -Be 0
    }

    It 'Safety invariant passes on Rev3.1 context (read-only modules are clean)' {
        $result = Test-DecomSafetyInvariant -Context $script:context31
        $result.NoUnexpectedWriteCmdlet | Should -Be $true
        $result.NoUnexpectedWriteScope  | Should -Be $true
    }

    # ── Items 1-3: Assessment/Demo/WhatIf mode write scope checks ──

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

    It 'DemoMode does not request GroupMember.ReadWrite.All' {
        $content = Get-Content $script:EntryPoint -Raw
        $demoBlock = $content -replace '(?s)ExecuteRemediation.*', ''
        $demoBlock | Should -Not -Match 'GroupMember\.ReadWrite\.All'
    }

    # ── Item 4: Write scopes gated behind ExecuteRemediation ──

    It 'Gate ordering unchanged — WhatIf and Approval gates before Connect-MgGraph' {
        $content = Get-Content $script:EntryPoint -Raw
        $posA    = $content.IndexOf('Test-DecomWhatIfManifest')
        $posB    = $content.IndexOf('Test-DecomApprovalManifest')
        $posConn = $content.IndexOf('Connect-MgGraph')
        $posA    | Should -BeGreaterThan 0
        $posB    | Should -BeGreaterThan 0
        $posConn | Should -BeGreaterThan 0
        $posA    | Should -BeLessThan $posConn
        $posB    | Should -BeLessThan $posConn
    }

    # ── Items 5-9: Module write-clean checks ──

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

    # ── Item 9: Rev3CapabilityMatrix is read-only ──

    It 'Rev3CapabilityMatrix.psm1 contains no write cmdlets' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Rev3CapabilityMatrix.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication|Invoke-MgGraphRequest'
    }

    It 'Rev3CapabilityMatrix.psm1 does not operationally request ReadWrite scopes' {
        # Module documents scope names as capability matrix data; check no Connect-MgGraph present
        $content = Get-Content (Join-Path $script:ModulesPath 'Rev3CapabilityMatrix.psm1') -Raw
        $content | Should -Not -Match 'Connect-MgGraph'
    }

    # ── Items 13-16: Deletion and mutation checks ──

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

    # ── Item 16: No Policy.ReadWrite.* anywhere ──

    It 'No Policy.ReadWrite.* scope appears in any operational module' {
        # Rev3CapabilityMatrix.psm1 documents it as deferred-reason text; ReleaseValidation.psm1 and WriteReadiness.psm1 reference it as forbidden/deferred scope documentation
        # NhiDiscovery.psm1 defines Policy.ReadWrite.All as a high-risk permission to detect, not as a scope to request
        $excluded = @('Rev3CapabilityMatrix.psm1', 'ReleaseValidation.psm1', 'WriteReadiness.psm1', 'NhiDiscovery.psm1')
        $files = Get-ChildItem (Join-Path $script:ModulesPath '*.psm1') | Where-Object { $_.Name -notin $excluded }
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw
            $content | Should -Not -Match 'Policy\.ReadWrite' -Because "$($f.Name) must not request Policy.ReadWrite"
        }
    }

    It 'Entry point does not reference Policy.ReadWrite' {
        $content = Get-Content $script:EntryPoint -Raw
        $content | Should -Not -Match 'Policy\.ReadWrite'
    }

    # ── Rev3.2 backward-compat checks ──

    It 'RemoveExpiredApplicationCredential allowed in Remediation' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        $content | Should -Match 'RemoveExpiredApplicationCredential'
    }

    It 'ApplicationGovernance.psm1 does not request write scopes' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Raw
        $content | Should -Not -Match 'ReadWrite\.All'
    }

    It 'ConditionalAccessGovernance.psm1 does not contain CA mutation scope strings' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
        $content | Should -Not -Match 'New-MgIdentityConditionalAccessPolicy|Update-MgIdentityConditionalAccessPolicy'
    }

    It 'EmergencyAccessGovernance.psm1 does not request write scopes' {
        $content = Get-Content (Join-Path $script:ModulesPath 'EmergencyAccessGovernance.psm1') -Raw
        $content | Should -Not -Match 'ReadWrite\.All'
    }

    # ── Rev3.3 new actions in Remediation ──

    It 'AddApplicationOwner is present in Remediation.psm1 ExecutionMap' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        $content | Should -Match 'AddApplicationOwner'
    }

    It 'RemoveCAExclusionGroupMember is present in Remediation.psm1 ExecutionMap' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        $content | Should -Match 'RemoveCAExclusionGroupMember'
    }

    It 'Rev3CapabilityMatrix module is loaded in entry point' {
        $content = Get-Content $script:EntryPoint -Raw
        $content | Should -Match 'Rev3CapabilityMatrix'
    }
}
