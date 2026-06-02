#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'OutputManifest' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'

        Remove-Module OutputManifest -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'OutputManifest.psm1') -Force -DisableNameChecking
    }

    It 'New-DecomOutputManifest returns an object' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $manifest | Should -Not -BeNullOrEmpty
    }

    It 'New-DecomOutputManifest sets SchemaVersion to 3.4' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $manifest.SchemaVersion | Should -Be '3.4'
    }

    It 'New-DecomOutputManifest sets ToolVersion from context' {
        $context = @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' }
        $manifest = New-DecomOutputManifest -Context $context -RunId 'run-123' -OutputRoot '.\out'
        $manifest.ToolVersion | Should -Be 'Rev3.4'
    }

    It 'New-DecomOutputManifest sets RunId' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-abc' -OutputRoot '.\out'
        $manifest.RunId | Should -Be 'run-abc'
    }

    It 'Add-DecomOutputManifestItem adds a file' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content'
        try {
            $result = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Assessment' -Sensitivity 'Public' -Description 'Test file'
            $result.Files.Count | Should -Be 1
            $result.Files[0].FileName | Should -Be ([System.IO.Path]::GetFileName($tempFile))
            $result.Files[0].Category | Should -Be 'Assessment'
            $result.Files[0].Sensitivity | Should -Be 'Public'
            $result.Files[0].Description | Should -Be 'Test file'
            $result.Summary.TotalFiles | Should -Be 1
        } finally {
            Remove-Item $tempFile -Force
        }
    }

    It 'Add-DecomOutputManifestItem sets SHA-256 hash' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content for hash'
        try {
            $result = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Findings' -Sensitivity 'Confidential'
            $result.Files.Count | Should -Be 1
            $result.Files[0].Sha256 | Should -Not -BeNullOrEmpty
            $result.Files[0].Sha256.Length | Should -Be 64
        } finally {
            Remove-Item $tempFile -Force
        }
    }

    It 'Export-DecomOutputManifestJson writes JSON file' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempJson = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomOutputManifestJson -Manifest $manifest -Path $tempJson
            $jsonContent = Get-Content $tempJson -Raw | ConvertFrom-Json
            $jsonContent.SchemaVersion | Should -Be '3.4'
            $jsonContent.ToolVersion | Should -Be 'Rev3.4'
            $jsonContent.RunId | Should -Be 'run-123'
            $jsonContent.EngagementId | Should -Be 'eng-123'
            $jsonContent.ClientName | Should -Be 'Client A'
        } finally {
            Remove-Item $tempJson -Force
        }
    }

    It 'Export-DecomOutputManifestCsv writes CSV file' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content'
        try {
            $manifest = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Assessment' -Sensitivity 'Public' -Description 'Test file'
            $tempCsv = [System.IO.Path]::GetTempFileName()
            Export-DecomOutputManifestCsv -Manifest $manifest -Path $tempCsv
            $csvContent = Import-Csv -Path $tempCsv
            $csvContent.Count | Should -Be 1
            $csvContent[0].FileName | Should -Be ([System.IO.Path]::GetFileName($tempFile))
            $csvContent[0].Category | Should -Be 'Assessment'
            $csvContent[0].Sensitivity | Should -Be 'Public'
            $csvContent[0].Description | Should -Be 'Test file'
        } finally {
            Remove-Item $tempFile -Force
            if (Test-Path $tempCsv) { Remove-Item $tempCsv -Force }
        }
    }

    It 'Test-DecomOutputManifest validates a valid manifest' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content'
        try {
            $manifest = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Assessment' -Sensitivity 'Public' -Description 'Test file'
            $result = Test-DecomOutputManifest -Manifest $manifest -RequireHashValidation:$true
            $result.Passed | Should -Be $true
            $result.Errors.Count | Should -Be 0
        } finally {
            Remove-Item $tempFile -Force
        }
    }

    It 'Test-DecomOutputManifest detects missing file' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content'
        try {
            $manifest = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Assessment' -Sensitivity 'Public'
            Remove-Item $tempFile -Force
            $result = Test-DecomOutputManifest -Manifest $manifest
            $result.Passed | Should -Be $false
            ($result.Errors | Where-Object { $_ -like '*File not found*' }).Count | Should -BeGreaterThan 0
        } finally {
            if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
        }
    }

    It 'Test-DecomOutputManifest detects duplicate manifest entry' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content'
        try {
            $manifest = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Assessment' -Sensitivity 'Public'
            $manifest = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Report' -Sensitivity 'Public'
            $result = Test-DecomOutputManifest -Manifest $manifest
            $result.Passed | Should -Be $false
            ($result.Errors | Where-Object { $_ -like '*Duplicate*' }).Count | Should -BeGreaterThan 0
        } finally {
            Remove-Item $tempFile -Force
        }
    }

    It 'Add-DecomOutputManifestItem sets Sensitivity classification' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content'
        try {
            $result = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Findings' -Sensitivity 'ContainsTenantData'
            $result.Files[0].Sensitivity | Should -Be 'ContainsTenantData'
            $result.Files[0].ContainsSensitiveData | Should -Be $true
        } finally {
            Remove-Item $tempFile -Force
        }
    }

    It 'Add-DecomOutputManifestItem sets SafeForClient flag' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = [System.IO.Path]::GetTempFileName()
        Set-Content -Path $tempFile -Value 'test content'
        try {
            $result = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Report' -Sensitivity 'ClientSafe'
            $result.Files[0].SafeForClient | Should -Be $true
        } finally {
            Remove-Item $tempFile -Force
        }
    }

    It 'Output manifest includes nested evidence-bundle files' {
        $ctx      = [pscustomobject]@{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' }
        $tmpBase  = [System.IO.Path]::GetTempPath()
        $outRoot  = Join-Path $tmpBase ('omR_' + [guid]::NewGuid().ToString('N').Substring(0, 6))
        $nested   = Join-Path $outRoot 'nested'
        $null     = New-Item -ItemType Directory -Path $nested -Force
        $file     = Join-Path $nested 'nested-file.json'
        [System.IO.File]::WriteAllText($file, '{"test":1}')
        $manifest = New-DecomOutputManifest -Context $ctx -RunId 'run-n1' -OutputRoot $outRoot
        try {
            $manifest = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $file -Category 'Assessment' -Sensitivity 'Confidential'
            $manifest.Summary.TotalFiles | Should -Be 1
            $manifest.Files[0].FileName | Should -Be 'nested-file.json'
        } finally {
            if (Test-Path $outRoot) { Remove-Item $outRoot -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }

    It 'Output manifest includes redacted files' {
        $manifest = New-DecomOutputManifest -Context @{ ToolVersion='Rev3.4'; EngagementId='eng-123'; ClientName='Client A' } -RunId 'run-123' -OutputRoot '.\out'
        $tempFile = Join-Path '.\out' 'redacted-report.json'
        Set-Content -Path $tempFile -Value '{"redacted": "data"}'
        try {
            $result = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $tempFile -Category 'Report' -Sensitivity 'ClientSafe'
            $result.Files.Count | Should -Be 1
            $result.Files[0].Sensitivity | Should -Be 'ClientSafe'
            $result.Files[0].FileName | Should -Be 'redacted-report.json'
        } finally {
            Remove-Item $tempFile -Force
        }
    }
}
