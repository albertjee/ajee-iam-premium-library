#Requires -Version 5.1

Describe 'CredentialHygiene.Rev32 — Credential Hygiene Pack' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','CredentialHygiene')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'CredentialHygiene.psm1') -Force -DisableNameChecking

        $script:testDir  = Join-Path $env:TEMP 'Decom-Rev32-CredHyg'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $expiredDt  = (Get-Date).ToUniversalTime().AddDays(-30).ToString('o')
        $keyId1     = [guid]::NewGuid().ToString()
        $appObjId   = [guid]::NewGuid().ToString()

        $findings = @(
            [PSCustomObject]@{
                FindingId            = 'DEC-APP-005'
                ObjectId             = $appObjId
                DisplayName          = 'TestApp-Expired'
                CredentialKeyId      = $keyId1
                CredentialType       = 'PasswordCredential'
                CredentialEndDateTime= $expiredDt
                OwnerCount           = 1
                HasOwner             = $true
                ProtectedObject      = $false
            }
        )

        $script:Context = @{
            ToolVersion  = 'Rev3.2'
            ClientName   = 'TestClient'
            EngagementId = 'ENG-CREDHYG-01'
            Assessor     = 'TestAssessor'
            TenantId     = 'test-tenant-id'
        }

        $script:Model = New-DecomCredentialHygieneModel -Context $script:Context -Findings $findings
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('CredentialHygiene','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Credential hygiene model is created with SchemaVersion 3.2' {
        $script:Model | Should -Not -BeNullOrEmpty
        $script:Model.SchemaVersion | Should -Be '3.2'
    }

    It 'Credential hygiene model has correct ToolVersion' {
        $script:Model.ToolVersion | Should -Be 'Rev3.2'
    }

    It 'Credential removal readiness JSON exports without error' {
        $path = Join-Path $script:testDir 'cred-readiness.json'
        { Export-DecomCredentialRemovalReadinessJson -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Credential removal readiness JSON contains SchemaVersion' {
        $path = Join-Path $script:testDir 'cred-readiness2.json'
        Export-DecomCredentialRemovalReadinessJson -Model $script:Model -Path $path
        $json = Get-Content $path -Raw | ConvertFrom-Json
        $json.SchemaVersion | Should -Be '3.2'
    }

    It 'Credential removal readiness CSV exports without error' {
        $path = Join-Path $script:testDir 'cred-readiness.csv'
        { Export-DecomCredentialRemovalReadinessCsv -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Credential hygiene dashboard HTML exports without error' {
        $path = Join-Path $script:testDir 'cred-dashboard.html'
        { Export-DecomCredentialHygieneDashboardHtml -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Credential hygiene dashboard HTML contains client name' {
        $path = Join-Path $script:testDir 'cred-dashboard2.html'
        Export-DecomCredentialHygieneDashboardHtml -Model $script:Model -Path $path
        $content = Get-Content $path -Raw
        $content | Should -Match 'TestClient'
    }

    It 'Credential owner approval packet Markdown exports without error' {
        $path = Join-Path $script:testDir 'cred-approval.md'
        { Export-DecomCredentialOwnerApprovalPacketMarkdown -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Credential owner approval packet HTML exports without error' {
        $path = Join-Path $script:testDir 'cred-approval.html'
        { Export-DecomCredentialOwnerApprovalPacketHtml -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Credential rollback guide Markdown exports without error' {
        $path = Join-Path $script:testDir 'cred-rollback.md'
        { Export-DecomCredentialRollbackGuideMarkdown -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Credential rollback guide mentions secret material cannot be recovered' {
        $path = Join-Path $script:testDir 'cred-rollback2.md'
        Export-DecomCredentialRollbackGuideMarkdown -Model $script:Model -Path $path
        $content = Get-Content $path -Raw
        $content | Should -Match '(?i)(cannot be recovered|secret material|no.*rollback|manual.*new)'
    }

    It 'Credential exception register CSV exports without error' {
        $path = Join-Path $script:testDir 'cred-exceptions.csv'
        { Export-DecomCredentialExceptionRegisterCsv -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Credential hygiene evidence appendix Markdown exports without error' {
        $path = Join-Path $script:testDir 'cred-evidence.md'
        { Export-DecomCredentialHygieneEvidenceAppendixMarkdown -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Credential access summary JSON exports without error' {
        $path = Join-Path $script:testDir 'cred-summary.json'
        { Export-DecomCredentialAccessSummaryJson -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'CredentialHygiene.psm1 contains no Graph write calls' {
        $content = Get-Content (Join-Path $script:ModulesPath 'CredentialHygiene.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication'
    }
}
