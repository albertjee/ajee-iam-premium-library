# StartEntraIAMAssessment.Rev311.Tests.ps1
# Rev3.11 milestone 2 - wrapper tests, 16 tests

BeforeAll {
    $ScriptFile = Join-Path $PSScriptRoot '..\Start-EntraIAMAssessment.ps1'
    $EntryPointTarget = 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
}

Describe 'Start-EntraIAMAssessment wrapper' {

    # ---------- Presence and load ----------

    It 'Script file exists at repo root' {
        $ScriptFile | Should -Exist
    }

    It 'Script parses with 0 errors' {
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptFile, [ref]$tokens, [ref]$errors
        )
        $errors.Count | Should -Be 0
    }

    It 'Script dot-sources silently (no output)' {
        $output = & {
            $ErrorActionPreference = 'Continue'
            . $ScriptFile 2>&1
        }
        $output.Count | Should -Be 0
    }

    # ---------- Parameter metadata ----------

    It '-Mode parameter exists' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptFile, [ref]$null, [ref]$null
        )
        $paramBlock = $ast.ParamBlock
        $paramBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Mode' } |
            Should -Not -BeNullOrEmpty
    }

    It '-Mode ValidateSet contains exactly QuickNHI, FullAssessment, DemoMode, WhatIfRemediation' {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $ScriptFile, [ref]$null, [ref]$null
        )
        $modeParam = $ast.ParamBlock.Parameters |
            Where-Object { $_.Name.VariablePath.UserPath -eq 'Mode' }
        $modeParam.Attributes |
            Where-Object { $_.TypeName.Name -eq 'ValidateSet' } |
            ForEach-Object { $_.PositionalArguments.Value } |
            Should -Be @('QuickNHI', 'FullAssessment', 'DemoMode', 'WhatIfRemediation')
    }

    It 'Executing wrapper without -Mode throws a clear error' {
        { & $ScriptFile -ErrorAction Stop } |
            Should -Throw '*Mode is required*'
    }

    # ---------- Help content ----------

    It 'Help content: SYNOPSIS is not empty' {
        $content = Get-Content $ScriptFile -Raw
        $content | Should -Match '\.SYNOPSIS\s*\n\s*\S'
    }

    It 'Help content: at least 4 EXAMPLE blocks present' {
        $content = Get-Content $ScriptFile -Raw
        $exampleCount = ([regex]::Matches($content, '(?m)^\.EXAMPLE')).Count
        $exampleCount | Should -BeGreaterOrEqual 4
    }

    # ---------- Splat tests via TestDrive fake entry point ----------

    BeforeAll {
        # Copy wrapper into TestDrive
        Copy-Item $ScriptFile "$TestDrive\Start-EntraIAMAssessment.ps1"

        # Create fake main entry point that captures the splat
        $fakeMainContent = @'
[CmdletBinding()]
param(
    [string]$Mode,
    [string]$TenantId,
    [string]$ClientId,
    [string]$EngagementId,
    [string]$ClientName,
    [string]$Assessor,
    [string]$OutputPath,
    [switch]$NonInteractive,
    [switch]$NoLogo,
    [switch]$DemoMode,
    [switch]$GenerateNhiGovernancePack,
    [switch]$GenerateExecutivePack
)
$PSBoundParameters |
    ConvertTo-Json -Depth 3 |
    Out-File -FilePath "$TestDrive\captured-params.json" -Encoding utf8
'@
        # Write with CRLF: use line array
        $lines = $fakeMainContent -split "`n"
        [System.IO.File]::WriteAllLines(
            (Join-Path $TestDrive 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'),
            $lines,
            [System.Text.UTF8Encoding]::new($false)
        )
    }

    Context 'QuickNHI preset' {
        BeforeAll {
            $null, $stderr = & (Join-Path $TestDrive 'Start-EntraIAMAssessment.ps1') -Mode QuickNHI 2>&1
            $captured = $null
            if (Test-Path "$TestDrive\captured-params.json") {
                $captured = Get-Content "$TestDrive\captured-params.json" -Raw | ConvertFrom-Json
            }
        }

        It 'QuickNHI: Mode=Assessment' {
            $captured.Mode | Should -Be 'Assessment'
        }

        It 'QuickNHI: no extra switch params' {
            $captured.DemoMode                   | Should -BeNullOrEmpty
            $captured.GenerateNhiGovernancePack  | Should -BeNullOrEmpty
            $captured.GenerateExecutivePack      | Should -BeNullOrEmpty
        }
    }

    Context 'FullAssessment preset' {
        BeforeAll {
            $null, $stderr = & (Join-Path $TestDrive 'Start-EntraIAMAssessment.ps1') -Mode FullAssessment 2>&1
            $captured = Get-Content "$TestDrive\captured-params.json" -Raw | ConvertFrom-Json
        }

        It 'FullAssessment: Mode=Assessment' {
            $captured.Mode | Should -Be 'Assessment'
        }

        It 'FullAssessment: GenerateNhiGovernancePack is present' {
            $captured.GenerateNhiGovernancePack | Should -Be $true
        }

        It 'FullAssessment: GenerateExecutivePack is present' {
            $captured.GenerateExecutivePack | Should -Be $true
        }
    }

    Context 'DemoMode preset' {
        BeforeAll {
            $null, $stderr = & (Join-Path $TestDrive 'Start-EntraIAMAssessment.ps1') -Mode DemoMode 2>&1
            $captured = Get-Content "$TestDrive\captured-params.json" -Raw | ConvertFrom-Json
        }

        It 'DemoMode: Mode=Assessment' {
            $captured.Mode | Should -Be 'Assessment'
        }

        It 'DemoMode: DemoMode switch is present' {
            $captured.DemoMode | Should -Be $true
        }

        It 'DemoMode: GenerateNhiGovernancePack is present' {
            $captured.GenerateNhiGovernancePack | Should -Be $true
        }

        It 'DemoMode: GenerateExecutivePack is present' {
            $captured.GenerateExecutivePack | Should -Be $true
        }
    }

    Context 'WhatIfRemediation preset' {
        BeforeAll {
            $null, $stderr = & (Join-Path $TestDrive 'Start-EntraIAMAssessment.ps1') -Mode WhatIfRemediation 2>&1
            $captured = Get-Content "$TestDrive\captured-params.json" -Raw | ConvertFrom-Json
        }

        It 'WhatIfRemediation: Mode=WhatIfRemediation' {
            $captured.Mode | Should -Be 'WhatIfRemediation'
        }

        It 'WhatIfRemediation: no extra switch params' {
            $captured.DemoMode                   | Should -BeNullOrEmpty
            $captured.GenerateNhiGovernancePack  | Should -BeNullOrEmpty
            $captured.GenerateExecutivePack      | Should -BeNullOrEmpty
        }
    }

    # ---------- Optional param wiring ----------

    Context 'Optional params absent from splat when not supplied' {
        BeforeAll {
            $null, $stderr = & (Join-Path $TestDrive 'Start-EntraIAMAssessment.ps1') -Mode QuickNHI 2>&1
            $captured = Get-Content "$TestDrive\captured-params.json" -Raw | ConvertFrom-Json
        }

        It 'TenantId absent when not supplied' {
            $captured.TenantId | Should -BeNullOrEmpty
        }

        It 'EngagementId absent when not supplied' {
            $captured.EngagementId | Should -BeNullOrEmpty
        }

        It 'NonInteractive absent when not supplied' {
            $captured.NonInteractive | Should -BeNullOrEmpty
        }

        It 'NoLogo absent when not supplied' {
            $captured.NoLogo | Should -BeNullOrEmpty
        }
    }

    Context 'Optional params present in splat when supplied' {
        BeforeAll {
            $null, $stderr = & (Join-Path $TestDrive 'Start-EntraIAMAssessment.ps1') `
                -Mode QuickNHI -TenantId 'test-tenant' -ClientId 'test-client' `
                -EngagementId 'ENG-001' -ClientName 'Acme Corp' 2>&1
            $captured = Get-Content "$TestDrive\captured-params.json" -Raw | ConvertFrom-Json
        }

        It 'TenantId present in splat when supplied' {
            $captured.TenantId | Should -Be 'test-tenant'
        }

        It 'ClientId present in splat when supplied' {
            $captured.ClientId | Should -Be 'test-client'
        }

        It 'EngagementId present in splat when supplied' {
            $captured.EngagementId | Should -Be 'ENG-001'
        }

        It 'ClientName present in splat when supplied' {
            $captured.ClientName | Should -Be 'Acme Corp'
        }
    }

    # ---------- ShouldProcess guard ----------

    Context '-WhatIf prevents invocation of main entry point' {
        BeforeAll {
            if (Test-Path "$TestDrive\captured-params.json") {
                Remove-Item "$TestDrive\captured-params.json" -Force
            }
            $null, $stderr = & (Join-Path $TestDrive 'Start-EntraIAMAssessment.ps1') `
                -Mode QuickNHI -WhatIf 2>&1
        }

        It 'captured-params.json does not exist when -WhatIf is used' {
            Test-Path "$TestDrive\captured-params.json" | Should -Be $false
        }
    }

    # ---------- No hardcoded absolute paths ----------

    It 'No hardcoded absolute paths in wrapper script content' {
        $content = Get-Content $ScriptFile -Raw
        # Match drive-letter roots, UNC roots
        $absolutePathPattern = '(?m)^[A-Za-z]:\\|\\\\[\w\-\.]+\\'
        $matches = [regex]::Matches($content, $absolutePathPattern)
        $matches.Count | Should -Be 0
    }
}
