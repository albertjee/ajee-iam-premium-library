#Requires -Version 5.1

Describe 'WarningHygiene.Rev36 — Silent catch elimination' {

    BeforeAll {
        $modulesPath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'src\Modules'
    }

    Context 'No silent catch blocks' {
        It 'Hardening modules do not use catch { }' {
            $hardeningModules = @('Redaction.psm1', 'EvidenceBundle.psm1', 'OutputManifest.psm1', 'ClientHandoff.psm1')

            foreach ($mod in $hardeningModules) {
                $path = Join-Path $modulesPath $mod
                if (Test-Path $path) {
                    $content = Get-Content $path -Raw
                    # Allow catch blocks only if they have a body (not empty)
                    $content | Should -Not -Match 'catch\s*\{\s*\}'
                }
            }
        }

        It 'Failed operations are recorded as warnings' {
            $modulePath = Join-Path $modulesPath 'Redaction.psm1'
            $content = Get-Content $modulePath -Raw
            $content | Should -Match 'Write-DecomWarn|Write-Warning'
        }
    }

    Context 'Warning capture in output manifests' {
        It 'ClientHandoff includes hardening warnings' {
            $modulePath = Join-Path $modulesPath 'ClientHandoff.psm1'
            $content = Get-Content $modulePath -Raw
            # Should have mechanism to capture and report warnings
            $content | Should -Match 'warning|Warning'
        }
    }
}
