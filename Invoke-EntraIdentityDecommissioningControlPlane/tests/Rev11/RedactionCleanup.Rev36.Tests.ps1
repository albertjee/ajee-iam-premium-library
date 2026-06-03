#Requires -Version 5.1

Describe 'RedactionCleanup.Rev36 — Redaction recursion and warning hygiene' {

    Context 'Redaction prevents self-recursion' {
        It 'Redaction skips redacted folder' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\Redaction.psm1'
            $content = Get-Content $modulePath -Raw
            $content | Should -Match 'notmatch.*\\redacted\\'
        }

        It 'Redaction does not re-redact already-redacted files' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\Redaction.psm1'
            $content = Get-Content $modulePath -Raw
            $content | Should -Match 'redacted.*notmatch|notmatch.*redacted'
        }
    }

    Context 'Redaction reports failures instead of silent catch' {
        It 'No silent catch blocks in Redaction module' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\Redaction.psm1'
            $content = Get-Content $modulePath -Raw
            $content | Should -Not -Match 'catch\s*\{\s*\}'
        }
    }
}
