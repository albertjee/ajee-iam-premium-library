#Requires -Version 5.1

Describe 'NhiPipelineState.Rev36 — NHI execution consolidation' {

    Context 'NHI pipeline runs once per execution' {
        It 'Script declares NhiInventory, NhiAnalyzed, NhiGovernanceFindings, NhiPipelineRan variables' {
            # M4: region F (initial variable declarations) moved to
            # src/EntryPoint/AssessmentFlow.ps1. Target the companion specifically
            # (not corpus) so this assertion verifies the declaration, not region G's
            # later reassignment of the same names.
            $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            $content = Get-Content (Join-Path $repoRoot 'src\EntryPoint\AssessmentFlow.ps1') -Raw
            $content | Should -Match '\$NhiInventory\s*='
            $content | Should -Match '\$NhiAnalyzed\s*='
            $content | Should -Match '\$NhiGovernanceFindings\s*='
            $content | Should -Match '\$NhiPipelineRan\s*='
        }

        It 'NhiPipelineRan flag prevents duplicate execution' {
            # M7: region I (the -not $NhiPipelineRan guard) moved to
            # src/EntryPoint/Rev35GovernancePack.ps1
            $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            $content = Get-Content (Join-Path $repoRoot 'src\EntryPoint\Rev35GovernancePack.ps1') -Raw
            $content | Should -Match 'if\s*\(\s*-not\s*\$NhiPipelineRan\s*\)'
        }

        It 'Later sections reuse cached NHI state' {
            # M7: region I (Invoke-DecomNhiReporting reuse) moved to
            # src/EntryPoint/Rev35GovernancePack.ps1
            $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
            $content = Get-Content (Join-Path $repoRoot 'src\EntryPoint\Rev35GovernancePack.ps1') -Raw
            $content | Should -Match 'Invoke-DecomNhiReporting.*\$NhiAnalyzed'
            $content | Should -Match 'Invoke-DecomNhiReporting.*\$NhiGovernanceFindings'
        }
    }
}
