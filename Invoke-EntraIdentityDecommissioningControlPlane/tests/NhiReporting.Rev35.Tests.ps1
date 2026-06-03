#Requires -Version 5.1
# INTENTIONAL_HISTORICAL_VERSION: Rev3.5 references are for historical test fixtures

Describe 'NhiReporting.Rev35 — NHI Reporting and Export Functions' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','NhiReporting')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')      -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiReporting.psm1')   -Force -DisableNameChecking

        $script:TestDir = Join-Path $env:TEMP "Decom-Rev35-NhiReport-$(([guid]::NewGuid().Guid))"
        New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null

        $script:TestCtx = [PSCustomObject]@{
            DemoMode     = $false
            OutputPath   = $script:TestDir
            ToolVersion  = 'Rev3.5'
            ClientName   = 'TestClient'
            EngagementId = 'ENG-NHI-35'
        }

        function script:New-TestNhiItem {
            param([string]$Id = 'tid-001', [string]$Name = 'test-agent', [string]$Class = 'LikelyAIAgent')
            [PSCustomObject]@{
                ObjectId                  = $Id
                AppId                     = 'app-' + $Id
                DisplayName               = $Name
                ObjectType                = 'ServicePrincipal'
                ServicePrincipalType      = 'Application'
                Classification            = $Class
                ClassificationConfidence  = 'High'
                ClassificationScore       = 55
                NhiCandidate              = $true
                AgenticCandidate          = $true
                AutomationCandidate       = $false
                WorkloadCandidate         = $false
                OwnerCount                = 0
                CredentialCount           = 1
                ExpiredCredentialCount    = 1
                ExpiringCredentialCount   = 0
                HighRiskPermissionCount   = 1
                HighRiskOAuthGrantCount   = 0
                TenantWideConsent         = $false
                IsVerifiedPublisher       = $false
                PublisherName             = 'TestCorp'
                FirstPartyMicrosoftApp    = $false
                RiskScore                 = 65
                Severity                  = 'High'
                CoverageMode              = 'Full'
                CoverageLimitations       = @()
                RiskScoreMayBeUnderstated = $false
                EvidenceSource            = 'graph'
                EvidenceConfidence        = 'High'
            }
        }

        function script:New-TestNhiFinding {
            param([string]$FindingId = 'DEC-NHI-001', [string]$Sev = 'High')
            [PSCustomObject]@{
                FindingId       = $FindingId
                Category        = 'NHI Governance'
                Severity        = $Sev
                RiskScore       = 65
                Confidence      = 'High'
                ObjectType      = 'ServicePrincipal'
                ObjectId        = 'tid-001'
                DisplayName     = 'test-agent'
                Evidence        = 'Test evidence'
                EvidenceSource  = 'graph'
                RecommendedAction = 'Review'
                RemediationMode = 'InformationOnly'
                Classification  = 'LikelyAIAgent'
                AgenticCandidate = $true
            }
        }

        $script:Inventory = @(
            (script:New-TestNhiItem -Id 'tid-001' -Name 'copilot-agent'),
            (script:New-TestNhiItem -Id 'tid-002' -Name 'workflow-runner' -Class 'LikelyAutomation')
        )
        $script:Findings = @(
            (script:New-TestNhiFinding -FindingId 'DEC-NHI-001' -Sev 'High'),
            (script:New-TestNhiFinding -FindingId 'DEC-NHI-002' -Sev 'High'),
            (script:New-TestNhiFinding -FindingId 'DEC-NHI-009' -Sev 'Critical'),
            (script:New-TestNhiFinding -FindingId 'DEC-AGENT-003' -Sev 'High')
        )
    }

    AfterAll {
        if (Test-Path $script:TestDir) { Remove-Item $script:TestDir -Recurse -Force -ErrorAction SilentlyContinue }
        foreach ($m in @('NhiReporting','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Module safety ──────────────────────────────────────────────────────────

    Context 'Module safety and exports' {

        It 'NhiReporting.psm1 contains no write cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiReporting.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication'
        }

        It 'Exports Invoke-DecomNhiReporting' {
            Get-Command Invoke-DecomNhiReporting -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Invoke-DecomNhiExportInventoryCsv' {
            Get-Command Invoke-DecomNhiExportInventoryCsv -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Invoke-DecomNhiExportInventoryJson' {
            Get-Command Invoke-DecomNhiExportInventoryJson -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Invoke-DecomNhiGenerateGovernanceDashboard' {
            Get-Command Invoke-DecomNhiGenerateGovernanceDashboard -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Invoke-DecomNhiGenerateExecutiveSummary' {
            Get-Command Invoke-DecomNhiGenerateExecutiveSummary -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Invoke-DecomNhiGenerateEvidenceAppendix' {
            Get-Command Invoke-DecomNhiGenerateEvidenceAppendix -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Invoke-DecomNhiGenerateExceptionRegister' {
            Get-Command Invoke-DecomNhiGenerateExceptionRegister -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Invoke-DecomNhiGenerateAgenticReviewPacket' {
            Get-Command Invoke-DecomNhiGenerateAgenticReviewPacket -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Invoke-DecomNhiGenerateRev4WriteReadinessReport' {
            Get-Command Invoke-DecomNhiGenerateRev4WriteReadinessReport -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    # ── NHI Inventory CSV export ───────────────────────────────────────────────

    Context 'Invoke-DecomNhiExportInventoryCsv' {

        BeforeAll {
            $script:CsvPath = Invoke-DecomNhiExportInventoryCsv -NhiInventory $script:Inventory -Context $script:TestCtx
        }

        It 'Returns a non-empty path' {
            $script:CsvPath | Should -Not -BeNullOrEmpty
        }

        It 'File exists on disk' {
            Test-Path $script:CsvPath | Should -Be $true
        }

        It 'File is valid CSV with header row' {
            $rows = Import-Csv $script:CsvPath
            $rows | Should -Not -BeNullOrEmpty
        }

        It 'CSV contains DisplayName column' {
            $rows = Import-Csv $script:CsvPath
            $rows[0].PSObject.Properties.Name | Should -Contain 'DisplayName'
        }

        It 'CSV row count matches inventory count' {
            $rows = Import-Csv $script:CsvPath
            $rows.Count | Should -Be $script:Inventory.Count
        }
    }

    # ── NHI Inventory JSON export ──────────────────────────────────────────────

    Context 'Invoke-DecomNhiExportInventoryJson' {

        BeforeAll {
            $script:JsonPath = Invoke-DecomNhiExportInventoryJson -NhiInventory $script:Inventory -Context $script:TestCtx
        }

        It 'File exists on disk' {
            Test-Path $script:JsonPath | Should -Be $true
        }

        It 'File contains valid JSON' {
            { Get-Content $script:JsonPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'JSON array count matches inventory count' {
            $json = Get-Content $script:JsonPath -Raw | ConvertFrom-Json
            @($json).Count | Should -Be $script:Inventory.Count
        }
    }

    # ── Governance dashboard HTML ──────────────────────────────────────────────

    Context 'Invoke-DecomNhiGenerateGovernanceDashboard' {

        BeforeAll {
            $script:DashPath = Invoke-DecomNhiGenerateGovernanceDashboard -NhiGovernanceFindings $script:Findings -Context $script:TestCtx
        }

        It 'File exists on disk' {
            Test-Path $script:DashPath | Should -Be $true
        }

        It 'File has .html extension' {
            $script:DashPath | Should -Match '\.html$'
        }

        It 'File contains DOCTYPE html' {
            $content = Get-Content $script:DashPath -Raw
            $content | Should -Match '<!DOCTYPE html>'
        }

        It 'File contains NHI Governance Dashboard heading' {
            $content = Get-Content $script:DashPath -Raw
            $content | Should -Match 'NHI Governance Dashboard'
        }
    }

    # ── Executive summary ──────────────────────────────────────────────────────

    Context 'Invoke-DecomNhiGenerateExecutiveSummary' {

        BeforeAll {
            $script:ExecPath = Invoke-DecomNhiGenerateExecutiveSummary `
                -NhiInventory $script:Inventory `
                -NhiGovernanceFindings $script:Findings `
                -Context $script:TestCtx
        }

        It 'File exists on disk' {
            Test-Path $script:ExecPath | Should -Be $true
        }

        It 'File has .md extension' {
            $script:ExecPath | Should -Match '\.md$'
        }

        It 'File starts with markdown heading' {
            $content = Get-Content $script:ExecPath -Raw
            $content | Should -Match '^#\s'
        }
    }

    # ── Evidence appendix ─────────────────────────────────────────────────────

    Context 'Invoke-DecomNhiGenerateEvidenceAppendix' {

        BeforeAll {
            $script:AppxPath = Invoke-DecomNhiGenerateEvidenceAppendix `
                -NhiInventory $script:Inventory `
                -NhiGovernanceFindings $script:Findings `
                -Context $script:TestCtx
        }

        It 'File exists on disk' {
            Test-Path $script:AppxPath | Should -Be $true
        }

        It 'File contains Evidence Appendix heading' {
            $content = Get-Content $script:AppxPath -Raw
            $content | Should -Match 'Evidence'
        }
    }

    # ── Exception register ────────────────────────────────────────────────────

    Context 'Invoke-DecomNhiGenerateExceptionRegister' {

        BeforeAll {
            $script:ExcPath = Invoke-DecomNhiGenerateExceptionRegister `
                -NhiGovernanceFindings $script:Findings `
                -Context $script:TestCtx
        }

        It 'Returns a path' {
            $script:ExcPath | Should -Not -BeNullOrEmpty
        }

        It 'File exists on disk' {
            Test-Path $script:ExcPath | Should -Be $true
        }
    }

    # ── Agentic review packet ─────────────────────────────────────────────────

    Context 'Invoke-DecomNhiGenerateAgenticReviewPacket' {

        BeforeAll {
            $script:AgenticPath = Invoke-DecomNhiGenerateAgenticReviewPacket `
                -NhiInventory $script:Inventory `
                -NhiGovernanceFindings $script:Findings `
                -Context $script:TestCtx
        }

        It 'File exists on disk' {
            Test-Path $script:AgenticPath | Should -Be $true
        }

        It 'File contains Agentic in content' {
            $content = Get-Content $script:AgenticPath -Raw
            $content | Should -Match 'Agentic|agentic'
        }
    }

    # ── Rev4 write-readiness report ───────────────────────────────────────────

    Context 'Invoke-DecomNhiGenerateRev4WriteReadinessReport' {

        BeforeAll {
            $script:ReadyPath = Invoke-DecomNhiGenerateRev4WriteReadinessReport `
                -NhiInventory $script:Inventory `
                -NhiGovernanceFindings $script:Findings `
                -Context $script:TestCtx
        }

        It 'File exists on disk' {
            Test-Path $script:ReadyPath | Should -Be $true
        }

        It 'File contains Rev4 or Write-Readiness in content' {
            $content = Get-Content $script:ReadyPath -Raw
            $content | Should -Match 'Rev4|Write-Readiness|write-readiness'
        }
    }
}
