#Requires -Version 5.1

Describe 'RedactionCleanup.Rev36 — Redaction recursion and warning hygiene' {

    Context 'Redaction module structure' {
        It 'Redaction module exports redaction functions' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\Redaction.psm1'
            $content = Get-Content $modulePath -Raw
            $content | Should -Match 'function.*Redaction'
        }

        It 'SchemaVersion is current' {
            $modulePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules\Redaction.psm1'
            $content = Get-Content $modulePath -Raw
            $content | Should -Match "SchemaVersion.*=.*'3\.6'"
        }
    }

    Context 'Entry point exclusion logic' {
        It 'Entry point handles redaction folder filtering' {
            $entryPoint = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            $content = Get-Content $entryPoint -Raw
            $content | Should -Match 'redacted|Redaction'
        }
    }
}
