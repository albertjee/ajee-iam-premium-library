#Requires -Version 5.1

Describe 'ReleasePackaging.psm1 — Required Docs' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module ReleasePackaging,Utilities -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ReleasePackaging.psm1') -Force -DisableNameChecking

        $script:testOutputDir  = Join-Path $env:TEMP 'Decom-RP-DocsTest'
        $script:releaseDir     = Join-Path $env:TEMP 'Decom-RP-DocsRelease'
        New-Item -ItemType Directory -Path $script:testOutputDir  -Force | Out-Null
        New-Item -ItemType Directory -Path $script:releaseDir     -Force | Out-Null

        $script:context = [PSCustomObject]@{
            ToolVersion  = 'Rev2.5'
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'test-eng'
            Assessor     = 'TestAssessor'
        }

        # Run from project root so ReleasePackaging can find docs\
        Push-Location (Join-Path $PSScriptRoot '..\..')
        New-DecomReleasePackage -Context $script:context -OutputPath $script:releaseDir
        Pop-Location

        $script:releaseRevDir = Join-Path $script:releaseDir 'Rev2.5'
    }

    AfterAll {
        if (Test-Path $script:testOutputDir)  { Remove-Item $script:testOutputDir  -Recurse -Force }
        if (Test-Path $script:releaseDir)     { Remove-Item $script:releaseDir     -Recurse -Force }
        Remove-Module ReleasePackaging,Utilities -Force -ErrorAction SilentlyContinue
    }

    It 'Release package copies Required-Permissions.md' {
        $f = Join-Path $script:releaseRevDir 'docs\Required-Permissions.md'
        Test-Path $f | Should -Be $true
    }

    It 'Release package copies Findings-Catalog.md' {
        $f = Join-Path $script:releaseRevDir 'docs\Findings-Catalog.md'
        Test-Path $f | Should -Be $true
    }

    It 'Release package copies Schema-Contracts.md' {
        $f = Join-Path $script:releaseRevDir 'docs\Schema-Contracts.md'
        Test-Path $f | Should -Be $true
    }

    It 'Release package copies Rev3-Write-Readiness.md' {
        $f = Join-Path $script:releaseRevDir 'docs\Rev3-Write-Readiness.md'
        Test-Path $f | Should -Be $true
    }

    It 'Missing required docs causes package generation to fail' {
        $fakeRoot    = Join-Path $env:TEMP 'Decom-RP-MissingDocs'
        $releaseOut  = Join-Path $env:TEMP 'Decom-RP-MissingRelease'
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'docs')     -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'runbooks') -Force | Out-Null
        try {
            Push-Location $fakeRoot
            $ctx = [PSCustomObject]@{
                ToolVersion  = 'Rev2.5'
                OutputPath   = $fakeRoot
                ClientName   = 'TestClient'
                EngagementId = 'test-eng'
                Assessor     = 'TestAssessor'
            }
            { New-DecomReleasePackage -Context $ctx -OutputPath $releaseOut } | Should -Throw
        } finally {
            Pop-Location
            if (Test-Path $fakeRoot)   { Remove-Item $fakeRoot   -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path $releaseOut) { Remove-Item $releaseOut -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}

Describe 'ReleasePackaging.psm1 — Validation Outputs' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module ReleasePackaging,Utilities -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ReleasePackaging.psm1') -Force -DisableNameChecking

        # Create a run output dir with a fake release-validation-report JSON
        $script:runOutputDir = Join-Path $env:TEMP 'Decom-RP-ValOutput'
        New-Item -ItemType Directory -Path $script:runOutputDir -Force | Out-Null
        '{"SchemaVersion":"2.5","Passed":true}' |
            Out-File -FilePath (Join-Path $script:runOutputDir 'release-validation-report-20260601_120000.json') -Encoding UTF8

        $script:releaseDir = Join-Path $env:TEMP 'Decom-RP-ValRelease'
        New-Item -ItemType Directory -Path $script:releaseDir -Force | Out-Null

        $script:context = [PSCustomObject]@{
            ToolVersion  = 'Rev2.5'
            OutputPath   = $script:runOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'test-eng'
            Assessor     = 'TestAssessor'
        }

        Push-Location (Join-Path $PSScriptRoot '..\..')
        New-DecomReleasePackage -Context $script:context -OutputPath $script:releaseDir
        Pop-Location

        $script:releaseRevDir  = Join-Path $script:releaseDir 'Rev2.5'
        $manifestPath          = Join-Path $script:releaseRevDir 'release-package-manifest.json'
        $script:manifest       = Get-Content $manifestPath -Raw | ConvertFrom-Json
    }

    AfterAll {
        if (Test-Path $script:runOutputDir) { Remove-Item $script:runOutputDir -Recurse -Force }
        if (Test-Path $script:releaseDir)   { Remove-Item $script:releaseDir   -Recurse -Force }
        Remove-Module ReleasePackaging,Utilities -Force -ErrorAction SilentlyContinue
    }

    It 'Release package copies latest release-validation-report JSON when present' {
        $dest = Join-Path $script:releaseRevDir 'validation\release-validation-report.json'
        Test-Path $dest | Should -Be $true
    }

    It 'Validation output manifest entry has Missing=false when copied' {
        $entry = @($script:manifest.Contents | Where-Object { $_.Path -match 'release-validation-report' })
        $entry.Count | Should -Be 1
        $entry[0].Missing | Should -Be $false
    }

    It 'Missing validation outputs are accurately marked Missing=true in manifest' {
        $missing = @($script:manifest.Contents |
            Where-Object { $_.Type -eq 'validation' -and $_.Path -notmatch 'release-validation-report' })
        $missing.Count | Should -BeGreaterThan 0
        foreach ($m in $missing) {
            $m.Missing | Should -Be $true -Because "no source file for $($m.Path)"
        }
    }
}
