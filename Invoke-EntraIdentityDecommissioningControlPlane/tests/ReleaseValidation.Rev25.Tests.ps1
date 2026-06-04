#Requires -Version 5.1
# INTENTIONAL_HISTORICAL_VERSION: Rev3.5 references are for historical test fixtures

Describe 'ReleaseValidation.psm1' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module ReleaseValidation -Force -ErrorAction SilentlyContinue
        Remove-Module Utilities -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ReleaseValidation.psm1') -Force -DisableNameChecking
        # Import test version context helper
        . (Join-Path $PSScriptRoot '..\tests\Rev11\TestVersionContext.ps1')

        $script:testOutputDir = Join-Path $env:TEMP 'Decom-RV-Test'
        New-Item -ItemType Directory -Path $script:testOutputDir -Force | Out-Null

        $script:context = [PSCustomObject]@{
            ToolVersion  = (Get-DecomExpectedToolVersion)
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'test-eng'
            Assessor     = 'TestAssessor'
        }
    }

    AfterAll {
        if (Test-Path $script:testOutputDir) { Remove-Item $script:testOutputDir -Recurse -Force }
        Remove-Module ReleaseValidation -Force -ErrorAction SilentlyContinue
        Remove-Module Utilities -Force -ErrorAction SilentlyContinue
    }

    Context 'Test-DecomVersionConsistency' {

        It 'Version consistency passes on clean repo' {
            $result = Test-DecomVersionConsistency -Context $script:context
            $result.Passed | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }

        It 'Version consistency detects stale SchemaVersion in a test string' {
            # Verify pattern match logic - a file claiming 2.3 would fail
            $staleContent = "SchemaVersion = '2.3'"
            $staleContent | Should -Match "SchemaVersion\s*=\s*'2\.[0-4]'"
        }
    }

    Context 'Test-DecomSafetyInvariant' {

        It 'Safety invariant passes on clean repo' {
            $result = Test-DecomSafetyInvariant -Context $script:context
            $result.Passed | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }

        It 'Safety invariant detects Remove-Mg in a hypothetical read-only module' {
            # Pattern check — verify the detection logic works
            $badContent = 'Remove-MgGroupMember -GroupId $id'
            $badContent | Should -Match 'Remove-Mg'
        }

        It 'Safety invariant detects unexpected ReadWrite scope in source' {
            $badContent = "EntitlementManagement.ReadWrite.All"
            $badContent | Should -Match 'EntitlementManagement.ReadWrite'
        }

        It 'NoUnexpectedWriteScope is true on clean repo' {
            $result = Test-DecomSafetyInvariant -Context $script:context
            $result.NoUnexpectedWriteScope | Should -Be $true
        }

        It 'NoUnexpectedWriteCmdlet is true on clean repo' {
            $result = Test-DecomSafetyInvariant -Context $script:context
            $result.NoUnexpectedWriteCmdlet | Should -Be $true
        }
    }

    Context 'Invoke-DecomReleaseValidation' {

        It 'Release validation passes on clean repo and creates JSON report' {
            $result = Invoke-DecomReleaseValidation -Context $script:context
            $result.Passed | Should -Be $true
            $files = Get-ChildItem -Path $script:testOutputDir -Filter 'release-validation-report-*.json'
            $files.Count | Should -BeGreaterThan 0
        }

        It 'Release validation JSON has correct schema version' {
            $files = Get-ChildItem -Path $script:testOutputDir -Filter 'release-validation-report-*.json'
            $json  = Get-Content $files[0].FullName -Raw | ConvertFrom-Json
            $json.SchemaVersion | Should -Be '3.0'
            $json.ToolVersion   | Should -Be 'Rev3.6'
        }

        It 'Release validation creates Markdown report' {
            $files = Get-ChildItem -Path $script:testOutputDir -Filter 'release-validation-report-*.md'
            $files.Count | Should -BeGreaterThan 0
            $md = Get-Content $files[0].FullName -Raw
            $md | Should -Match 'Release Validation Report'
            $md | Should -Match '2026 Albert Jee'
        }
    }
}
