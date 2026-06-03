#Requires -Version 5.1

Describe 'NhiP1Fixes.Rev35 — NHI Output Manifest and Evidence Registration' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','OutputManifest','EvidenceBundle')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'OutputManifest.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'EvidenceBundle.psm1')  -Force -DisableNameChecking

        # Shared context object used by New-DecomOutputManifest and New-DecomEvidenceBundle
        $script:TestContext = [pscustomobject]@{
            ToolVersion  = 'Rev3.5'
            EngagementId = 'eng-001'
            ClientName   = 'Test'
        }
    }

    AfterAll {
        foreach ($m in @('EvidenceBundle','OutputManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'NHI inventory CSV appears in OutputManifest' {
        $manifest = New-DecomOutputManifest `
            -Context $script:TestContext `
            -RunId 'run-001' `
            -OutputRoot $env:TEMP
        $tmpCsv = Join-Path $env:TEMP 'nhi-inventory.csv'
        Set-Content -Path $tmpCsv -Value 'ObjectId,DisplayName' -Force
        try {
            # 'NHI' is not in the Category ValidateSet — use 'Assessment' as the production code does
            $result = Add-DecomOutputManifestItem `
                -Manifest $manifest `
                -FilePath $tmpCsv `
                -Category 'Assessment' `
                -Sensitivity 'Confidential'
            $nhiEntry = $result.Files | Where-Object { $_.FileName -eq 'nhi-inventory.csv' }
            $nhiEntry | Should -Not -BeNullOrEmpty
            $nhiEntry.FileName | Should -Be 'nhi-inventory.csv'
        } finally {
            Remove-Item $tmpCsv -Force -ErrorAction SilentlyContinue
        }
    }

    It 'NHI dashboard appears in EvidenceBundle' {
        $bundleCmd = Get-Command New-DecomEvidenceBundle -ErrorAction SilentlyContinue
        if (-not $bundleCmd) {
            Set-ItResult -Skipped -Because 'EvidenceBundle module not available'
            return
        }
        $tmpHtml = Join-Path $env:TEMP 'nhi-dashboard.html'
        Set-Content -Path $tmpHtml -Value '<html>NHI</html>' -Force
        try {
            # New-DecomEvidenceBundle requires Context, RunId, BundleId, SourceOutputPath, BundleOutputPath
            $bundle = New-DecomEvidenceBundle `
                -Context $script:TestContext `
                -RunId 'run-001' `
                -BundleId ([guid]::NewGuid().ToString()) `
                -SourceOutputPath $env:TEMP `
                -BundleOutputPath (Join-Path $env:TEMP 'nhi-bundle-test')
            # Add-DecomEvidenceBundleFile uses -Category, not -Description
            $result = Add-DecomEvidenceBundleFile `
                -Bundle $bundle `
                -FilePath $tmpHtml `
                -Category 'NHI'
            $nhiEntry = $result.Files | Where-Object { $_.FileName -eq 'nhi-dashboard.html' }
            $nhiEntry | Should -Not -BeNullOrEmpty
            $nhiEntry.Category | Should -Be 'NHI'
        } finally {
            Remove-Item $tmpHtml -Force -ErrorAction SilentlyContinue
        }
    }

    It 'NHI outputs Confidential sensitivity sets SafeForClient=false' {
        # SafeForClient is computed internally from Sensitivity — not a caller parameter.
        # Confidential sensitivity must set SafeForClient=$false per module logic.
        $manifest = New-DecomOutputManifest `
            -Context $script:TestContext `
            -RunId 'run-001' `
            -OutputRoot $env:TEMP
        $tmpCsv = Join-Path $env:TEMP 'nhi-test-output.csv'
        Set-Content -Path $tmpCsv -Value 'test' -Force
        try {
            $result = Add-DecomOutputManifestItem `
                -Manifest $manifest `
                -FilePath $tmpCsv `
                -Category 'Assessment' `
                -Sensitivity 'Confidential'
            $nhiEntry = $result.Files | Where-Object { $_.FileName -eq 'nhi-test-output.csv' }
            $nhiEntry | Should -Not -BeNullOrEmpty
            # Confidential sensitivity => SafeForClient must be $false
            $nhiEntry.SafeForClient | Should -Be $false
        } finally {
            Remove-Item $tmpCsv -Force -ErrorAction SilentlyContinue
        }
    }
}
