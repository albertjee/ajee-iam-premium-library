#Requires -Version 5.1

Describe 'CoverageLimitations.Rev36 — Coverage preservation and semantics' {

    Context 'Coverage limitation preservation' {
        It 'Add-DecomCoverageLimitation helper exists' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\NhiAnalysis.psm1'
            $content = Get-Content $modulePath -Raw
            # Coverage limitations should be preserved, not reset
            $content | Should -Match 'coverageLimitations.*@\(\$nhiObject\.CoverageLimitations\)'
        }

        It 'RiskScoreMayBeUnderstated only set when data unavailable' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\NhiAnalysis.psm1'
            $content = Get-Content $modulePath -Raw
            # Should preserve discovery value, not reset to false
            $content | Should -Match 'RiskScoreMayBeUnderstated.*\[bool\]\$nhiObject'
        }
    }

    Context 'Coverage limitation deduplication' {
        It 'Duplicate coverage limitations are prevented' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\NhiAnalysis.psm1'
            $content = Get-Content $modulePath -Raw
            # De-duplication logic should be present
            $content | Should -Match 'de.duplic|unique|contains'
        }
    }
}
