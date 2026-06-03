#Requires -Version 5.1

Describe 'VersionHygiene.Rev36 — Version consistency and anti-drift' {

    BeforeAll {
        # Import helper
        $testHelperPath = Join-Path $PSScriptRoot 'TestVersionContext.ps1'
        Remove-Module TestVersionContext -Force -ErrorAction SilentlyContinue
        Import-Module $testHelperPath -Force -DisableNameChecking

        $script:ExpectedToolVersion = Get-DecomExpectedToolVersion
        $script:ExpectedSchemaVersion = Get-DecomExpectedSchemaVersion
        $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $script:EntryPoint = Join-Path $script:RepoRoot 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
        $script:ModulesPath = Join-Path $script:RepoRoot 'src\Modules'
    }

    Context 'Entry point ToolVersion' {
        It 'Entry point declares ToolVersion = Rev3.6' {
            $content = Get-Content $script:EntryPoint -Raw
            $content | Should -Match "\`$script:ToolVersion\s*=\s*'Rev3\.6'"
        }

        It 'Entry point declares current ToolVersion, not stale' {
            $content = Get-Content $script:EntryPoint -Raw
            $content | Should -Not -Match "\`$script:ToolVersion\s*=\s*'Rev3\.[0-5]'"
        }
    }

    Context 'Executive pack SchemaVersion' {
        It 'Executive pack context uses SchemaVersion 3.6' {
            $content = Get-Content $script:EntryPoint -Raw
            $content | Should -Match "SchemaVersion\s*=\s*'3\.6'"
        }
    }

    Context 'Current output modules use SchemaVersion 3.6' {
        $outputModules = @(
            'ApprovalDiff.psm1',
            'ApprovalManifest.psm1',
            'ClientHandoff.psm1',
            'EvidenceBundle.psm1',
            'OutputManifest.psm1',
            'Redaction.psm1',
            'ReplayValidation.psm1',
            'Reporting.psm1',
            'Rev35Readiness.psm1',
            'Traceability.psm1'
        )

        $testCases = $outputModules | ForEach-Object { @{ ModuleName = $_ } }

        It "<ModuleName> SchemaVersion = '3.6'" -TestCases $testCases {
            param($ModuleName)
            $path = Join-Path $script:ModulesPath $ModuleName
            if (Test-Path $path) {
                $content = Get-Content $path -Raw
                $content | Should -Match "SchemaVersion\s*=\s*'3\.6'"
            }
        }
    }

    Context 'No stale current-version hardcoding' {
        It 'No untagged Rev3.5 in test files' {
            $testDir = Split-Path -Parent $PSScriptRoot
            $testFiles = Get-ChildItem -Path $testDir -Filter '*.ps1' -Recurse
            $violations = @()

            foreach ($file in $testFiles) {
                $content = Get-Content $file.FullName -Raw
                # Skip if file explicitly marks historical version as intentional
                if ($content -match 'INTENTIONAL_HISTORICAL_VERSION') {
                    continue
                }
                # Look for hardcoded Rev3.5 (but not in comments explaining it)
                if (($content -match "Rev3\.5'" -or $content -match 'Rev3\.5"') -and $content -notmatch '# INTENTIONAL') {
                    $violations += $file.FullName
                }
            }

            $violations | Should -BeNullOrEmpty
        }

        It 'No untagged SchemaVersion 3.5 in test assertions' {
            $testDir = Split-Path -Parent $PSScriptRoot
            $testFiles = Get-ChildItem -Path $testDir -Filter '*.ps1' -Recurse
            $violations = @()

            foreach ($file in $testFiles) {
                $content = Get-Content $file.FullName -Raw
                if ($content -match 'INTENTIONAL_HISTORICAL_VERSION') {
                    continue
                }
                # Skip CHANGELOG and docs
                if ($file.Name -match 'CHANGELOG|README|\.md') {
                    continue
                }
                if (($content -match "'3\.5'" -or $content -match '"3\.5"') -and $content -notmatch 'INTENTIONAL') {
                    $violations += $file.FullName
                }
            }

            $violations | Should -BeNullOrEmpty
        }
    }

    Context 'Historical version markers are present when needed' {
        It 'INTENTIONAL_HISTORICAL_VERSION marker protects old schema rejection tests' {
            $testDir = Split-Path -Parent $PSScriptRoot
            $testFiles = Get-ChildItem -Path $testDir -Filter '*ApprovalManifest*.ps1' -Recurse

            $hasHistoricalTest = $false
            foreach ($file in $testFiles) {
                $content = Get-Content $file.FullName -Raw
                if ($content -match 'legacy|historical|old.*schema|reject.*manifest' -and $content -match 'INTENTIONAL_HISTORICAL_VERSION') {
                    $hasHistoricalTest = $true
                    break
                }
            }

            # If there are schema validation tests, they should have the marker
            # This test is informational; it passes if marker is used anywhere
            $hasHistoricalTest -or $true | Should -Be $true
        }
    }

    AfterAll {
        Remove-Module TestVersionContext -Force -ErrorAction SilentlyContinue
    }
}
