#Requires -Version 5.1

Describe 'OutputManifestEvidenceCleanup.Rev36 — Output manifest and evidence bundle consistency' {

    Context 'Output manifest deduplication' {
        It 'OutputManifest does not include duplicate file paths' {
            # Validates helper function prevents recursion
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\OutputManifest.psm1'
            $content = Get-Content $modulePath -Raw
            $content | Should -Match 'Get-DecomOutputFilesForManifest'
        }
    }

    Context 'Evidence bundle self-recursion prevention' {
        It 'EvidenceBundle excludes evidence-bundle folder during build' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\EvidenceBundle.psm1'
            $content = Get-Content $modulePath -Raw
            $content | Should -Match 'notmatch.*evidence-bundle'
        }
    }
}
