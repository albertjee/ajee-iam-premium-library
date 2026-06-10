#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'EvidenceBundle' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'

        Remove-Module EvidenceBundle -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'EvidenceBundle.psm1') -Force -DisableNameChecking
    }

    It 'Evidence bundle manifest exported' {
        $ctx = [pscustomobject]@{ ToolVersion='Rev4.1'; EngagementId='eng-123'; ClientName='Client A' }
        $bundle = New-DecomEvidenceBundle -Context $ctx -RunId 'run-123' -BundleId 'bundle-001' `
            -SourceOutputPath '.\out' -BundleOutputPath '.\bundle'
        $tempJson = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomEvidenceBundleManifestJson -Bundle $bundle -Path $tempJson
            $content = Get-Content $tempJson -Raw | ConvertFrom-Json
            $content.SchemaVersion | Should -Be '3.6'
            $content.BundleId | Should -Be 'bundle-001'
            $content.RunId | Should -Be 'run-123'
        } finally {
            Remove-Item $tempJson -Force
        }
    }

    It 'Evidence hash manifest exported' {
        $ctx = [pscustomobject]@{ ToolVersion='Rev4.1'; EngagementId='eng-123'; ClientName='Client A' }
        $bundle = New-DecomEvidenceBundle -Context $ctx -RunId 'run-123' -BundleId 'bundle-002' `
            -SourceOutputPath '.\out' -BundleOutputPath '.\bundle'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'evidence content'
        $tempJson = [System.IO.Path]::GetTempFileName() + '.json'
        $tempCsv  = [System.IO.Path]::GetTempFileName() + '.csv'
        try {
            $bundle = Add-DecomEvidenceBundleFile -Bundle $bundle -FilePath $tempFile -Category 'Assessment'
            Export-DecomEvidenceHashManifest -Bundle $bundle -JsonPath $tempJson -CsvPath $tempCsv
            Test-Path $tempJson | Should -Be $true
            Test-Path $tempCsv  | Should -Be $true
            $hashJson = Get-Content $tempJson -Raw | ConvertFrom-Json
            $hashJson.SchemaVersion | Should -Be '3.6'
            $hashJson.Hashes.Count | Should -Be 1
        } finally {
            Remove-Item $tempFile -Force
            if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
            if (Test-Path $tempCsv)  { Remove-Item $tempCsv  -Force }
        }
    }

    It 'Evidence bundle includes files when added by category' {
        $ctx = [pscustomobject]@{ ToolVersion='Rev4.1'; EngagementId='eng-123'; ClientName='Client A' }
        $bundle = New-DecomEvidenceBundle -Context $ctx -RunId 'run-123' -BundleId 'bundle-003' `
            -SourceOutputPath '.\out' -BundleOutputPath '.\bundle'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'whatif evidence'
        try {
            $bundle = Add-DecomEvidenceBundleFile -Bundle $bundle -FilePath $tempFile -Category 'WhatIf'
            $bundle.Files.Count | Should -Be 1
            $bundle.Files[0].Category | Should -Be 'WhatIf'
            $bundle.Files[0].Sha256 | Should -Not -BeNullOrEmpty
            $bundle.FileCount | Should -Be 1
        } finally {
            Remove-Item $tempFile -Force
        }
    }

    It 'Evidence bundle detects missing required evidence' {
        $ctx = [pscustomobject]@{ ToolVersion='Rev4.1'; EngagementId='eng-123'; ClientName='Client A' }
        $bundle = New-DecomEvidenceBundle -Context $ctx -RunId 'run-123' -BundleId 'bundle-004' `
            -SourceOutputPath '.\out' -BundleOutputPath '.\bundle'
        $fakeEntry = [pscustomobject]@{
            FileId       = [guid]::NewGuid().ToString()
            FileName     = 'missing.json'
            RelativePath = '.\missing.json'
            FullPath     = 'C:\nonexistent\path\missing.json'
            Category     = 'Assessment'
            SizeBytes    = 100
            Sha256       = 'a' * 64
        }
        $bundle.Files += $fakeEntry
        $bundle.FileCount = 1
        $bundle.TotalBytes = 100
        $result = Test-DecomEvidenceBundle -Bundle $bundle
        $result.Passed | Should -Be $false
        ($result.Errors | Where-Object { $_ -like '*File not found*' }).Count | Should -BeGreaterThan 0
    }

    It 'Evidence bundle index Markdown exported' {
        $ctx = [pscustomobject]@{ ToolVersion='Rev4.1'; EngagementId='eng-123'; ClientName='Client A' }
        $bundle = New-DecomEvidenceBundle -Context $ctx -RunId 'run-123' -BundleId 'bundle-005' `
            -SourceOutputPath '.\out' -BundleOutputPath '.\bundle'
        $tempMd = [System.IO.Path]::GetTempFileName() + '.md'
        try {
            Export-DecomEvidenceBundleIndexMarkdown -Bundle $bundle -Path $tempMd
            Test-Path $tempMd | Should -Be $true
            $content = Get-Content $tempMd -Raw
            $content | Should -Match 'bundle-005'
            $content | Should -Match '# Evidence Bundle Index'
        } finally {
            if (Test-Path $tempMd) { Remove-Item $tempMd -Force }
        }
    }

    It 'Evidence bundle file outside source path uses filename as RelativePath' {
        $ctx = [pscustomobject]@{ ToolVersion='Rev4.1'; EngagementId='eng-123'; ClientName='Client A' }
        $bundle = New-DecomEvidenceBundle -Context $ctx -RunId 'run-123' -BundleId 'bundle-ext-001' `
            -SourceOutputPath '.\out' -BundleOutputPath '.\bundle'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'external content'
        try {
            $bundle = Add-DecomEvidenceBundleFile -Bundle $bundle -FilePath $tempFile -Category 'Assessment'
            $bundle.Files[0].RelativePath | Should -Be ([System.IO.Path]::GetFileName($tempFile))
        } finally {
            Remove-Item $tempFile -Force
        }
    }

    It 'Evidence hash manifest includes evidence-bundle manifest' {
        $ctx = [pscustomobject]@{ ToolVersion='Rev4.1'; EngagementId='eng-123'; ClientName='Client A' }
        $bundle = New-DecomEvidenceBundle -Context $ctx -RunId 'run-123' -BundleId 'bundle-006' `
            -SourceOutputPath '.\out' -BundleOutputPath '.\bundle'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content'
        try {
            $bundle = Add-DecomEvidenceBundleFile -Bundle $bundle -FilePath $tempFile -Category 'Assessment'

            $tempJson = [System.IO.Path]::GetTempFileName() + '.json'
            $tempCsv  = [System.IO.Path]::GetTempFileName() + '.csv'
            Export-DecomEvidenceHashManifest -Bundle $bundle -JsonPath $tempJson -CsvPath $tempCsv

            $hashJson = Get-Content $tempJson -Raw | ConvertFrom-Json
            $hashJson.Hashes.Count | Should -Be 1
            $hashJson.Hashes[0].FileName | Should -Be ([System.IO.Path]::GetFileName($tempFile))
            $hashJson.Hashes[0].RelativePath | Should -Be ([System.IO.Path]::GetFileName($tempFile))
        } finally {
            Remove-Item $tempFile -Force
            if (Test-Path $tempJson) { Remove-Item $tempJson -Force }
            if (Test-Path $tempCsv)  { Remove-Item $tempCsv  -Force }
        }
    }
}
