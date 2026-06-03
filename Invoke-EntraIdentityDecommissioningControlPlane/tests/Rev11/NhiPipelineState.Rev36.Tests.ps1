#Requires -Version 5.1

Describe 'NhiPipelineState.Rev36 — NHI execution consolidation' {

    Context 'NHI pipeline runs once per execution' {
        It 'Script declares NhiInventory, NhiAnalyzed, NhiGovernanceFindings, NhiPipelineRan variables' {
            $content = Get-Content (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Invoke-EntraIdentityDecommissioningControlPlane.ps1') -Raw
            $content | Should -Match '\$NhiInventory\s*='
            $content | Should -Match '\$NhiAnalyzed\s*='
            $content | Should -Match '\$NhiGovernanceFindings\s*='
            $content | Should -Match '\$NhiPipelineRan\s*='
        }

        It 'NhiPipelineRan flag prevents duplicate execution' {
            $content = Get-Content (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Invoke-EntraIdentityDecommissioningControlPlane.ps1') -Raw
            $content | Should -Match 'if\s*\(\s*-not\s*\$NhiPipelineRan\s*\)'
        }

        It 'Later sections reuse cached NHI state' {
            $content = Get-Content (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Invoke-EntraIdentityDecommissioningControlPlane.ps1') -Raw
            $content | Should -Match 'Invoke-DecomNhiReporting.*\$NhiAnalyzed'
            $content | Should -Match 'Invoke-DecomNhiReporting.*\$NhiGovernanceFindings'
        }
    }
}
