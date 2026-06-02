#Requires -Version 5.1

Describe 'ConditionalAccessGovernance.Rev32 — CA Exclusion Governance Pack' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ConditionalAccessGovernance')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')                   -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Force -DisableNameChecking

        $script:testDir = Join-Path $env:TEMP 'Decom-Rev32-CAGov'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $policyId1 = [guid]::NewGuid().ToString()
        $policyId2 = [guid]::NewGuid().ToString()

        $findings = @(
            [PSCustomObject]@{
                FindingId          = 'DEC-CA-001'
                PolicyId           = $policyId1
                PolicyName         = 'Require MFA for All Users'
                GroupId            = [guid]::NewGuid().ToString()
                RiskLevel          = 'High'
                HasReviewEvidence  = $false
            },
            [PSCustomObject]@{
                FindingId          = 'DEC-CA-002'
                PolicyId           = $policyId2
                PolicyName         = 'Block Legacy Auth'
                GroupId            = [guid]::NewGuid().ToString()
                RiskLevel          = 'Medium'
                HasReviewEvidence  = $true
                ReviewEvidenceDate = (Get-Date).AddDays(-30).ToString('o')
            },
            [PSCustomObject]@{
                FindingId          = 'DEC-CA-003'
                PolicyId           = $policyId1
                PolicyName         = 'Require MFA for All Users'
                GroupId            = [guid]::NewGuid().ToString()
                RiskLevel          = 'High'
                HasReviewEvidence  = $false
            }
        )

        $script:Context = @{
            ToolVersion  = 'Rev3.2'
            ClientName   = 'TestClient'
            EngagementId = 'ENG-CAGOV-01'
            Assessor     = 'TestAssessor'
            TenantId     = 'test-tenant-id'
        }

        $script:Model = New-DecomCaExclusionGovernanceModel -Context $script:Context -Findings $findings
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('ConditionalAccessGovernance','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'CA exclusion governance model is created with SchemaVersion 3.2' {
        $script:Model | Should -Not -BeNullOrEmpty
        $script:Model.SchemaVersion | Should -Be '3.2'
    }

    It 'CA exclusion governance model counts exclusions correctly' {
        $script:Model.ExclusionCount | Should -Be 3
    }

    It 'CA exclusion governance model identifies high-risk exclusions' {
        $script:Model.HighRiskExclusionCount | Should -BeGreaterThan 0
    }

    It 'CA exclusion governance model identifies lack-of-review-evidence exclusions' {
        $script:Model.ExclusionsLackingReviewEvidenceCount | Should -BeGreaterThan 0
    }

    It 'DEC-CA-002 with review evidence produces Rev33WriteCandidate status' {
        $exclusion = [PSCustomObject]@{
            PolicyId = [guid]::NewGuid().ToString()
            PolicyName = 'Test Policy'
            GroupId = [guid]::NewGuid().ToString()
            GroupName = ''
            Target = ''
            DisplayName = 'Test Policy'
            FindingId = 'DEC-CA-002'
            IsHighRisk = $false
            HasReviewEvidence = $true
            ConflictingEvidence = $false
            ReviewEvidenceDate = (Get-Date).AddDays(-10).ToString('o')
        }
        $result = Get-DecomCaExclusionReadiness -Exclusion $exclusion
        $result.ReadinessStatus | Should -Be 'Rev33WriteCandidate'
    }

    It 'DEC-CA-002 without review evidence produces ManualRemediationRequired status' {
        $exclusion = [PSCustomObject]@{
            PolicyId = [guid]::NewGuid().ToString()
            PolicyName = 'Test Policy'
            GroupId = [guid]::NewGuid().ToString()
            GroupName = ''; Target = ''; DisplayName = 'Test Policy'
            FindingId = 'DEC-CA-002'
            IsHighRisk = $false
            HasReviewEvidence = $false
            ConflictingEvidence = $false
            ReviewEvidenceDate = $null
        }
        $result = Get-DecomCaExclusionReadiness -Exclusion $exclusion
        $result.ReadinessStatus | Should -Be 'ManualRemediationRequired'
    }

    It 'CA exclusion governance dashboard HTML exports without error' {
        $path = Join-Path $script:testDir 'ca-dashboard.html'
        { Export-DecomCaExclusionGovernanceDashboardHtml -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'CA exclusion governance dashboard HTML contains client name' {
        $path = Join-Path $script:testDir 'ca-dashboard2.html'
        Export-DecomCaExclusionGovernanceDashboardHtml -Model $script:Model -Path $path
        $content = Get-Content $path -Raw
        $content | Should -Match 'TestClient'
    }

    It 'CA exclusion readiness JSON exports without error' {
        $path = Join-Path $script:testDir 'ca-readiness.json'
        { Export-DecomCaExclusionReadinessJson -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'CA exclusion readiness JSON has SchemaVersion 3.2' {
        $path = Join-Path $script:testDir 'ca-readiness2.json'
        Export-DecomCaExclusionReadinessJson -Model $script:Model -Path $path
        $json = Get-Content $path -Raw | ConvertFrom-Json
        $json.SchemaVersion | Should -Be '3.2'
    }

    It 'CA exclusion readiness CSV exports without error' {
        $path = Join-Path $script:testDir 'ca-readiness.csv'
        { Export-DecomCaExclusionReadinessCsv -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'CA exclusion owner review packet Markdown exports without error' {
        $path = Join-Path $script:testDir 'ca-review.md'
        { Export-DecomCaExclusionOwnerReviewPacketMarkdown -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'CA exclusion owner review packet Markdown notes Rev3.2 read-only constraint' {
        $path = Join-Path $script:testDir 'ca-review2.md'
        Export-DecomCaExclusionOwnerReviewPacketMarkdown -Model $script:Model -Path $path
        $content = Get-Content $path -Raw
        $content | Should -Match '(?i)(read.?only|no.*CA.*mutation|Rev3\.2)'
    }

    It 'CA exclusion owner review packet HTML exports without error' {
        $path = Join-Path $script:testDir 'ca-review.html'
        { Export-DecomCaExclusionOwnerReviewPacketHtml -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'CA exclusion exception register CSV exports without error' {
        $path = Join-Path $script:testDir 'ca-exceptions.csv'
        { Export-DecomCaExclusionExceptionRegisterCsv -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'CA exclusion remediation design Markdown exports without error' {
        $path = Join-Path $script:testDir 'ca-design.md'
        { Export-DecomCaExclusionRemediationDesignMarkdown -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'CA exclusion remediation design notes no CA policy mutation' {
        $path = Join-Path $script:testDir 'ca-design2.md'
        Export-DecomCaExclusionRemediationDesignMarkdown -Model $script:Model -Path $path
        $content = Get-Content $path -Raw
        $content | Should -Match '(?i)(no.*CA.*policy|no.*mutation|read.?only|Policy\.ReadWrite)'
    }

    It 'ConditionalAccessGovernance.psm1 is read-only — no CA write cmdlets' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgIdentityConditionalAccessPolicy'
    }

    It 'ConditionalAccessGovernance.psm1 does not contain CA mutation scope declarations' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
        $content | Should -Not -Match "'Policy\.ReadWrite\.All'|`"Policy\.ReadWrite\.All`""
    }
}
