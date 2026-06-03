#Requires -Version 5.1

Describe 'PS51Compatibility.Rev36 — PowerShell 5.1 compliance' {

    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $entryPoint = Join-Path $repoRoot 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
        $modulesPath = Join-Path $repoRoot 'src\Modules'
    }

    Context 'No PS7-only syntax' {
        It 'No null-coalescing operator (??) in production code' {
            Get-ChildItem -Path $modulesPath -Filter '*.psm1' | ForEach-Object {
                $content = Get-Content $_.FullName -Raw
                $content | Should -Not -Match '\?\?'
            }
        }

        It 'No ForEach-Object -Parallel in production code' {
            Get-ChildItem -Path $modulesPath -Filter '*.psm1' | ForEach-Object {
                $content = Get-Content $_.FullName -Raw
                $content | Should -Not -Match 'ForEach-Object.*-Parallel'
            }
        }
    }

    Context 'PS5.1 parser compatibility' {
        It 'Entry point parses under PS5.1 parser' {
            $errors = $null
            [System.Management.Automation.Language.Parser]::ParseFile($entryPoint, [ref]$null, [ref]$errors) | Out-Null
            $errors | Should -BeNullOrEmpty
        }

        It 'All production modules parse under PS5.1 parser' {
            Get-ChildItem -Path $modulesPath -Filter '*.psm1' | ForEach-Object {
                $errors = $null
                [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors) | Out-Null
                $errors | Should -BeNullOrEmpty
            }
        }
    }

    Context '#Requires version declaration' {
        It 'Entry point has #Requires -Version 5.1' {
            $content = Get-Content $entryPoint -Raw
            $content | Should -Match '#Requires.*-Version.*5\.1'
        }
    }
}
