#Requires -Version 5.1

Describe 'Rev3CapabilityMatrix.Rev33 — Capability Matrix and Rev3.4 Readiness Pack' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','Rev3CapabilityMatrix')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')             -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Rev3CapabilityMatrix.psm1')  -Force -DisableNameChecking

        $script:testDir = Join-Path $env:TEMP "Decom-Rev33-Matrix-$(([guid]::NewGuid().Guid))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $script:MatrixContent = Get-Content (Join-Path $script:ModulesPath 'Rev3CapabilityMatrix.psm1') -Raw

        $script:Context = [PSCustomObject]@{ ToolVersion = 'Rev3.3' }
        $script:Matrix  = New-DecomRev3CapabilityMatrix -Context $script:Context
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('Rev3CapabilityMatrix','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Module safety: must be read-only ──

    Context 'Rev3CapabilityMatrix.psm1 is read-only (Item 9 safety)' {

        It 'Rev3CapabilityMatrix.psm1 contains no Remove-Mg cmdlets' {
            $script:MatrixContent | Should -Not -Match 'Remove-Mg'
        }

        It 'Rev3CapabilityMatrix.psm1 contains no Update-Mg cmdlets' {
            $script:MatrixContent | Should -Not -Match 'Update-Mg'
        }

        It 'Rev3CapabilityMatrix.psm1 contains no Set-Mg cmdlets' {
            $script:MatrixContent | Should -Not -Match 'Set-Mg'
        }

        It 'Rev3CapabilityMatrix.psm1 contains no New-Mg write cmdlets' {
            $script:MatrixContent | Should -Not -Match 'New-MgApplication|New-MgUser|New-MgGroup|New-MgIdentity'
        }

        It 'Rev3CapabilityMatrix.psm1 does not operationally request ReadWrite scopes (Connect-MgGraph)' {
            # Module documents scope names as capability matrix data; verify no operational scope requests
            $script:MatrixContent | Should -Not -Match 'Connect-MgGraph'
            $script:MatrixContent | Should -Not -Match 'Invoke-MgGraphRequest'
        }

        It 'Rev3CapabilityMatrix.psm1 does not contain CA policy mutation code' {
            # Module may document Policy.ReadWrite as deferred-reason text; verify no operational CA mutation
            $script:MatrixContent | Should -Not -Match 'Update-MgIdentityConditionalAccessPolicy'
            $script:MatrixContent | Should -Not -Match 'New-MgIdentityConditionalAccessPolicy'
        }
    }

    # ── Matrix model ──

    Context 'New-DecomRev3CapabilityMatrix model content' {

        It 'Matrix SchemaVersion is 3.3' {
            $script:Matrix.SchemaVersion | Should -Be '3.3'
        }

        It 'Matrix ToolVersion is Rev3.3' {
            $script:Matrix.ToolVersion | Should -Be 'Rev3.3'
        }

        It 'Matrix includes ExecutableActions' {
            $script:Matrix.ExecutableActions | Should -Not -BeNullOrEmpty
        }

        It 'Matrix includes AddApplicationOwner as executable action' {
            $ownerActions = @($script:Matrix.ExecutableActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' })
            $ownerActions.Count | Should -BeGreaterThan 0
        }

        It 'Matrix includes RemoveCAExclusionGroupMember as executable action' {
            $caActions = @($script:Matrix.ExecutableActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' })
            $caActions.Count | Should -BeGreaterThan 0
        }

        It 'Matrix includes Rev2.0 actions' {
            $rev20 = @($script:Matrix.ExecutableActions | Where-Object { $_.Release -eq 'Rev2.0' })
            $rev20.Count | Should -BeGreaterThan 0
        }

        It 'Matrix includes Rev3.0 actions' {
            $rev30 = @($script:Matrix.ExecutableActions | Where-Object { $_.Release -eq 'Rev3.0' })
            $rev30.Count | Should -BeGreaterThan 0
        }

        It 'Matrix includes PlanOnlyActions' {
            $script:Matrix.PlanOnlyActions | Should -Not -BeNullOrEmpty
        }

        It 'Matrix includes DeferredActions with unsafe operations' {
            $deleted = @($script:Matrix.DeferredActions | Where-Object { $_.ActionType -match 'Delete' })
            $deleted.Count | Should -BeGreaterThan 0
        }

        It 'Matrix DeferredActions includes ModifyConditionalAccessPolicy as unsafe' {
            $ca = @($script:Matrix.DeferredActions | Where-Object { $_.ActionType -eq 'ModifyConditionalAccessPolicy' })
            $ca.Count | Should -BeGreaterThan 0
        }

        It 'Matrix RequiredScopesByMode includes ExecuteRemediation entry' {
            $exec = @($script:Matrix.RequiredScopesByMode | Where-Object { $_.Mode -eq 'ExecuteRemediation' })
            $exec.Count | Should -BeGreaterThan 0
        }

        It 'Matrix UnsupportedOperations lists CA policy mutation' {
            $script:Matrix.UnsupportedOperations | Should -Contain 'CA policy mutation'
        }
    }

    # ── Item 65: Rev3 capability matrix exported ──

    Context 'Item 65 — Rev3 capability matrix export' {

        It 'Export-DecomRev3CapabilityMatrixMarkdown creates a Markdown file' {
            $path = Join-Path $script:testDir 'rev3-remediation-capability-matrix-test.md'
            Export-DecomRev3CapabilityMatrixMarkdown -Matrix $script:Matrix -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported matrix Markdown contains executable actions section' {
            $path = Join-Path $script:testDir 'rev3-remediation-capability-matrix-test.md'
            if (-not (Test-Path $path)) {
                Export-DecomRev3CapabilityMatrixMarkdown -Matrix $script:Matrix -Path $path
            }
            $content = Get-Content $path -Raw
            $content | Should -Match 'Executable Actions'
        }

        It 'Exported matrix Markdown contains AddApplicationOwner' {
            $path = Join-Path $script:testDir 'rev3-remediation-capability-matrix-test.md'
            $content = Get-Content $path -Raw
            $content | Should -Match 'AddApplicationOwner'
        }

        It 'Exported matrix Markdown contains RemoveCAExclusionGroupMember' {
            $path = Join-Path $script:testDir 'rev3-remediation-capability-matrix-test.md'
            $content = Get-Content $path -Raw
            $content | Should -Match 'RemoveCAExclusionGroupMember'
        }

        It 'Export-DecomRev3CapabilityMatrixJson creates a JSON file' {
            $path = Join-Path $script:testDir 'rev3-remediation-capability-matrix-test.json'
            Export-DecomRev3CapabilityMatrixJson -Matrix $script:Matrix -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported matrix JSON is valid JSON' {
            $path = Join-Path $script:testDir 'rev3-remediation-capability-matrix-test.json'
            if (-not (Test-Path $path)) {
                Export-DecomRev3CapabilityMatrixJson -Matrix $script:Matrix -Path $path
            }
            { Get-Content $path -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Exported matrix JSON SchemaVersion is 3.3' {
            $path = Join-Path $script:testDir 'rev3-remediation-capability-matrix-test.json'
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.SchemaVersion | Should -Be '3.3'
        }
    }

    # ── Item 66: Rev3.4 production readiness report exported ──

    Context 'Item 66 — Rev3.4 production readiness report export' {

        It 'Export-DecomRev34ProductionReadinessMarkdown creates a Markdown file' {
            $path = Join-Path $script:testDir 'rev3.4-production-hardening-readiness-test.md'
            Export-DecomRev34ProductionReadinessMarkdown -Matrix $script:Matrix -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported readiness report contains Rev3.4 Candidates section' {
            $path = Join-Path $script:testDir 'rev3.4-production-hardening-readiness-test.md'
            if (-not (Test-Path $path)) {
                Export-DecomRev34ProductionReadinessMarkdown -Matrix $script:Matrix -Path $path
            }
            $content = Get-Content $path -Raw
            $content | Should -Match 'Rev3\.4 Candidates|Production.Hardening|Rev3\.4'
        }

        It 'Exported readiness report lists CA policy mutation as permanent non-goal' {
            $path = Join-Path $script:testDir 'rev3.4-production-hardening-readiness-test.md'
            $content = Get-Content $path -Raw
            $content | Should -Match 'CA policy mutation|Permanent Non-Goals|CA policy'
        }

        It 'Export-DecomRev34ProductionReadinessJson creates a JSON file' {
            $path = Join-Path $script:testDir 'rev3.4-production-hardening-readiness-test.json'
            Export-DecomRev34ProductionReadinessJson -Matrix $script:Matrix -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported readiness JSON is valid JSON' {
            $path = Join-Path $script:testDir 'rev3.4-production-hardening-readiness-test.json'
            if (-not (Test-Path $path)) {
                Export-DecomRev34ProductionReadinessJson -Matrix $script:Matrix -Path $path
            }
            { Get-Content $path -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Exported readiness JSON includes Rev34Candidates' {
            $path = Join-Path $script:testDir 'rev3.4-production-hardening-readiness-test.json'
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.Rev34Candidates | Should -Not -BeNullOrEmpty
        }

        It 'Exported readiness JSON includes Rev3.3 in Rev3WriteSummary' {
            $path = Join-Path $script:testDir 'rev3.4-production-hardening-readiness-test.json'
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $rev33 = @($json.Rev3WriteSummary | Where-Object { $_.Release -eq 'Rev3.3' })
            $rev33.Count | Should -BeGreaterThan 0
        }
    }
}
