#Requires -Version 5.1

Describe 'ReleasePackaging.psm1 — Rev3.4 Hardening Artifact Copy' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module ReleasePackaging,Utilities -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ReleasePackaging.psm1') -Force -DisableNameChecking

        $script:testOutputDir  = Join-Path $env:TEMP 'Decom-RP-Rev34-Test'
        $script:releaseDir     = Join-Path $env:TEMP 'Decom-RP-Rev34-Release'
        New-Item -ItemType Directory -Path $script:testOutputDir  -Force | Out-Null
        New-Item -ItemType Directory -Path $script:releaseDir     -Force | Out-Null

        # Create fake hardening artifacts in testOutputDir
        $artifacts = @(
            'output-manifest.json',
            'evidence-bundle-manifest.json',
            'evidence-hashes.json',
            'replay-validation-report.json',
            'traceability-report.json',
            'redaction-report.json',
            'client-handoff-index.md',
            'rev35-readiness-report.json'
        )
        foreach ($artifact in $artifacts) {
            $path = Join-Path $script:testOutputDir $artifact
            if ($artifact -like '*.json') {
                # Simple JSON content
                '{}' | Out-File -FilePath $path -Encoding UTF8
            } elseif ($artifact -like '*.md') {
                # Simple markdown content
                '# Test' | Out-File -FilePath $path -Encoding UTF8
            }
        }

        $script:context = [PSCustomObject]@{
            ToolVersion  = 'Rev3.6'
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'test-eng'
            Assessor     = 'TestAssessor'
        }

        # Run from project root so ReleasePackaging can find docs\
        Push-Location (Join-Path $PSScriptRoot '..')
        New-DecomReleasePackage -Context $script:context -OutputPath $script:releaseDir -RequireHardeningArtifacts
        Pop-Location

        $script:releaseRevDir = Join-Path $script:releaseDir 'Rev3.4'
    }

    AfterAll {
        if (Test-Path $script:testOutputDir)  { Remove-Item $script:testOutputDir  -Recurse -Force }
        if (Test-Path $script:releaseDir)     { Remove-Item $script:releaseDir     -Recurse -Force }
        Remove-Module ReleasePackaging,Utilities -Force -ErrorAction SilentlyContinue
    }

    It 'Release package directory is Rev3.4' {
        Test-Path $script:releaseRevDir | Should -Be $true
    }

    It 'Release package copies required documentation' {
        $requiredDocs = @(
            'Required-Permissions.md',
            'Findings-Catalog.md',
            'Schema-Contracts.md',
            'Rev3-Write-Readiness.md'
        )
        foreach ($doc in $requiredDocs) {
            $f = Join-Path $script:releaseRevDir "docs\$doc"
            Test-Path $f | Should -Be $true -Because "Missing documentation: $doc"
        }
    }

    It 'Release package copies required runbooks' {
        $requiredRunbooks = @(
            'Assessment-Runbook.md',
            'WhatIf-Approval-Runbook.md',
            'ExecuteRemediation-Runbook.md',
            'Executive-Pack-Runbook.md',
            'Troubleshooting.md',
            'Rev3-Write-Readiness-Runbook.md'
        )
        foreach ($runbook in $requiredRunbooks) {
            $f = Join-Path $script:releaseRevDir "runbooks\$runbook"
            Test-Path $f | Should -Be $true -Because "Missing runbook: $runbook"
        }
    }

    It 'Release package copies hardening artifacts to correct subdirectories' {
        $expected = @(
            @{ artifact = 'output-manifest.json';          subdir = 'handoff' },
            @{ artifact = 'evidence-bundle-manifest.json'; subdir = 'evidence' },
            @{ artifact = 'evidence-hashes.json';          subdir = 'evidence' },
            @{ artifact = 'replay-validation-report.json'; subdir = 'validation' },
            @{ artifact = 'traceability-report.json';      subdir = 'validation' },
            @{ artifact = 'redaction-report.json';         subdir = 'redacted' },
            @{ artifact = 'client-handoff-index.md';       subdir = 'handoff' },
            @{ artifact = 'rev35-readiness-report.json';   subdir = 'handoff' }
        )
        foreach ($pair in $expected) {
            $f = Join-Path $script:releaseRevDir "$($pair.subdir)\$($pair.artifact)"
            Test-Path $f | Should -Be $true -Because "Missing artifact: $($pair.artifact) in subdir $($pair.subdir)"
        }
    }

    It 'Release package manifest includes correct SchemaVersion and ToolVersion' {
        $manifestPath = Join-Path $script:releaseRevDir 'release-package-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.SchemaVersion | Should -Be '3.6'
        $manifest.ToolVersion   | Should -Be 'Rev3.6'
    }

    It 'Release package manifest reports no missing required artifacts' {
        $manifestPath = Join-Path $script:releaseRevDir 'release-package-manifest.json'
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $manifest.RequiredArtifactsPresent | Should -Be $true
        $manifest.MissingRequiredArtifacts.Count | Should -Be 0
    }

    It 'Missing required artifacts cause failure when RequireHardeningArtifacts is set' {
        $fakeRoot    = Join-Path $env:TEMP 'Decom-RP-MissingRev34'
        $releaseOut  = Join-Path $env:TEMP 'Decom-RP-MissingRev34-Release'
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'docs')     -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'runbooks') -Force | Out-Null
        # Do NOT create hardening artifacts
        try {
            Push-Location $fakeRoot
            $ctx = [PSCustomObject]@{
                ToolVersion  = 'Rev3.6'
                OutputPath   = $fakeRoot
                ClientName   = 'TestClient'
                EngagementId = 'test-eng'
                Assessor     = 'TestAssessor'
            }
            { New-DecomReleasePackage -Context $ctx -OutputPath $releaseOut -RequireHardeningArtifacts } | Should -Throw
        } finally {
            Pop-Location
            if (Test-Path $fakeRoot)   { Remove-Item $fakeRoot   -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path $releaseOut) { Remove-Item $releaseOut -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'Optional missing artifact does not cause failure' {
        $fakeRoot    = Join-Path $env:TEMP 'Decom-RP-OptionalMissing'
        $releaseOut  = Join-Path $env:TEMP 'Decom-RP-OptionalMissing-Release'
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'docs')     -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $fakeRoot 'runbooks') -Force | Out-Null

        # Copy required documentation to fake root docs folder
        $requiredDocs = @(
            "Required-Permissions.md",
            "Findings-Catalog.md",
            "Schema-Contracts.md",
            "Rev3-Write-Readiness.md"
        )
        foreach ($doc in $requiredDocs) {
            $sourcePath = Join-Path (Get-Location) "docs\$doc"
            $destPath   = Join-Path $fakeRoot "docs\$doc"
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $destPath -Force
            }
        }

        # Copy required runbooks to fake root runbooks folder
        $requiredRunbooks = @(
            "Assessment-Runbook.md",
            "WhatIf-Approval-Runbook.md",
            "ExecuteRemediation-Runbook.md",
            "Executive-Pack-Runbook.md",
            "Troubleshooting.md",
            "Rev3-Write-Readiness-Runbook.md"
        )
        foreach ($runbook in $requiredRunbooks) {
            $sourcePath = Join-Path (Get-Location) "runbooks\$runbook"
            $destPath   = Join-Path $fakeRoot "runbooks\$runbook"
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $destPath -Force
            }
        }

        # Create all required artifacts except redaction-report (optional)
        $required = @(
            'output-manifest.json',
            'evidence-bundle-manifest.json',
            'evidence-hashes.json',
            'replay-validation-report.json',
            'traceability-report.json',
            'client-handoff-index.md',
            'rev35-readiness-report.json'
        )
        foreach ($artifact in $required) {
            $path = Join-Path $fakeRoot $artifact
            if ($artifact -like '*.json') {
                '{}' | Out-File -FilePath $path -Encoding UTF8
            } elseif ($artifact -like '*.md') {
                '# Test' | Out-File -FilePath $path -Encoding UTF8
            }
        }
        try {
            Push-Location $fakeRoot
            $ctx = [PSCustomObject]@{
                ToolVersion  = 'Rev3.6'
                OutputPath   = $fakeRoot
                ClientName   = 'TestClient'
                EngagementId = 'test-eng'
                Assessor     = 'TestAssessor'
            }
            { New-DecomReleasePackage -Context $ctx -OutputPath $releaseOut -RequireHardeningArtifacts } | Should -Not -Throw
        } finally {
            Pop-Location
            if (Test-Path $fakeRoot)   { Remove-Item $fakeRoot   -Recurse -Force -ErrorAction SilentlyContinue }
            if (Test-Path $releaseOut) { Remove-Item $releaseOut -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
}