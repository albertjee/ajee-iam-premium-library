#Requires -Version 5.1

Describe 'CaExclusionRemediation.Rev33 — CA Exclusion Governance Pack Exports' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ConditionalAccessGovernance')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')                     -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1')   -Force -DisableNameChecking

        $script:testDir = Join-Path $env:TEMP "Decom-Rev33-CAExcl-$(([guid]::NewGuid().Guid))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $script:Context = @{
            ToolVersion  = 'Rev3.5'
            ClientName   = 'TestClient'
            EngagementId = 'ENG-33-CAE'
            Assessor     = 'TestAssessor'
            OutputPath   = $script:testDir
            TenantId     = ''
        }

        $pol1 = [guid]::NewGuid().Guid
        $grp1 = [guid]::NewGuid().Guid

        $script:Findings = @(
            [PSCustomObject]@{
                FindingId          = 'DEC-CA-002'
                PolicyId           = $pol1
                PolicyName         = 'Require MFA - All Apps'
                GroupId            = $grp1
                GroupName          = 'CA-Exclusion-Legacy'
                Target             = 'user@contoso.com'
                DisplayName        = 'Require MFA - All Apps'
                RiskLevel          = 'High'
                HasReviewEvidence  = $true
                ConflictingEvidence= $false
                HighRisk           = $true
            },
            [PSCustomObject]@{
                FindingId          = 'DEC-CA-003'
                PolicyId           = [guid]::NewGuid().Guid
                PolicyName         = 'Block Legacy Auth'
                GroupId            = [guid]::NewGuid().Guid
                Target             = 'svc@contoso.com'
                DisplayName        = 'Block Legacy Auth'
                RiskLevel          = 'Medium'
                HasReviewEvidence  = $false
                ConflictingEvidence= $false
            },
            [PSCustomObject]@{
                FindingId          = 'DEC-CA-004'
                PolicyId           = [guid]::NewGuid().Guid
                PolicyName         = 'Require Compliant Device'
                GroupId            = [guid]::NewGuid().Guid
                Target             = 'admin@contoso.com'
                DisplayName        = 'Require Compliant Device'
                HasReviewEvidence  = $false
                ConflictingEvidence= $true
            }
        )

        $script:Model = New-DecomCaExclusionGovernanceModel -Context $script:Context -Findings $script:Findings
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('ConditionalAccessGovernance','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Governance model ──

    Context 'CA exclusion governance model' {

        It 'New-DecomCaExclusionGovernanceModel returns a model object' {
            $script:Model | Should -Not -BeNullOrEmpty
        }

        It 'Model ExclusionCount is correct' {
            $script:Model.ExclusionCount | Should -Be 3
        }

        It 'Model includes Exclusions array' {
            $script:Model.Exclusions | Should -Not -BeNullOrEmpty
        }

        It 'Model CAPolicyCount is at least 1' {
            $script:Model.CAPolicyCount | Should -BeGreaterThan 0
        }

        It 'DEC-CA-002 with review evidence shows Rev33WriteCandidate status' {
            $ca002 = $script:Model.Exclusions | Where-Object { $_.FindingId -eq 'DEC-CA-002' }
            $ca002.ReadinessStatus | Should -Be 'Rev33WriteCandidate'
        }

        It 'DEC-CA-003 without review evidence shows ManualRemediationRequired or HighRisk' {
            $ca003 = $script:Model.Exclusions | Where-Object { $_.FindingId -eq 'DEC-CA-003' }
            $ca003.ReadinessStatus | Should -Match 'ManualRemediationRequired|HighRisk'
        }

        It 'Model Rev3WriteReadinessCandidatesCount is correct' {
            $script:Model.Rev3WriteReadinessCandidatesCount | Should -BeGreaterThan 0
        }
    }

    # ── Item 62: CA exclusion remediation readiness JSON exported ──

    Context 'Item 62 — CA exclusion readiness JSON export' {

        It 'Export-DecomCaExclusionReadinessJson creates a file' {
            $path = Join-Path $script:testDir 'ca-exclusion-remediation-readiness-test.json'
            Export-DecomCaExclusionReadinessJson -Model $script:Model -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported readiness JSON is valid JSON' {
            $path = Join-Path $script:testDir 'ca-exclusion-remediation-readiness-test.json'
            if (-not (Test-Path $path)) {
                Export-DecomCaExclusionReadinessJson -Model $script:Model -Path $path
            }
            { Get-Content $path -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Exported JSON includes Exclusions array' {
            $path = Join-Path $script:testDir 'ca-exclusion-remediation-readiness-test.json'
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.Exclusions | Should -Not -BeNullOrEmpty
        }

        It 'Exported JSON includes ExclusionCount field' {
            $path = Join-Path $script:testDir 'ca-exclusion-remediation-readiness-test.json'
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.ExclusionCount | Should -BeGreaterThan 0
        }
    }

    # ── Item 63: CA exclusion owner approval packet exported ──

    Context 'Item 63 — CA exclusion owner review packet export' {

        It 'Export-DecomCaExclusionOwnerReviewPacketMarkdown creates a file' {
            $path = Join-Path $script:testDir 'ca-exclusion-owner-approval-packet-test.md'
            Export-DecomCaExclusionOwnerReviewPacketMarkdown -Model $script:Model -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported packet Markdown contains review header' {
            $path = Join-Path $script:testDir 'ca-exclusion-owner-approval-packet-test.md'
            if (-not (Test-Path $path)) {
                Export-DecomCaExclusionOwnerReviewPacketMarkdown -Model $script:Model -Path $path
            }
            $content = Get-Content $path -Raw
            $content | Should -Match 'CA Exclusion|Exclusion.*Review|Owner Review'
        }

        It 'Exported packet includes reviewer signature block' {
            $path = Join-Path $script:testDir 'ca-exclusion-owner-approval-packet-test.md'
            $content = Get-Content $path -Raw
            $content | Should -Match 'Signature'
        }

        It 'Export-DecomCaExclusionGovernanceDashboardHtml creates an HTML file' {
            $path = Join-Path $script:testDir 'ca-exclusion-dashboard-test.html'
            Export-DecomCaExclusionGovernanceDashboardHtml -Model $script:Model -Path $path
            Test-Path $path | Should -Be $true
        }
    }

    # ── Item 64: CA exclusion rollback guide exported ──

    Context 'Item 64 — CA exclusion remediation design/rollback guide export' {

        It 'Export-DecomCaExclusionRemediationDesignMarkdown creates a file' {
            $path = Join-Path $script:testDir 'ca-exclusion-rollback-guide-test.md'
            Export-DecomCaExclusionRemediationDesignMarkdown -Model $script:Model -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported remediation design contains Rev3.3 write candidates section' {
            $path = Join-Path $script:testDir 'ca-exclusion-rollback-guide-test.md'
            if (-not (Test-Path $path)) {
                Export-DecomCaExclusionRemediationDesignMarkdown -Model $script:Model -Path $path
            }
            $content = Get-Content $path -Raw
            $content | Should -Match 'Rev3\.3|Rev3\.2 Constraints|Remediation Design'
        }

        It 'Exported remediation design includes no-CA-policy-mutation statement' {
            $path = Join-Path $script:testDir 'ca-exclusion-rollback-guide-test.md'
            $content = Get-Content $path -Raw
            $content | Should -Match '(?i)(no CA policy mutation|not.*mutate|No CA policy)'
        }
    }

    # ── No-write safety ──

    Context 'ConditionalAccessGovernance.psm1 is read-only' {

        It 'ConditionalAccessGovernance.psm1 contains no Remove-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg'
        }

        It 'ConditionalAccessGovernance.psm1 does not contain CA policy mutation cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
            $content | Should -Not -Match 'Update-MgIdentityConditionalAccessPolicy'
            $content | Should -Not -Match 'New-MgIdentityConditionalAccessPolicy'
        }

        It 'ConditionalAccessGovernance.psm1 does not contain ReadWrite scope references' {
            $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
            $content | Should -Not -Match 'ReadWrite\.All'
        }

        It 'ConditionalAccessGovernance.psm1 does not reference Policy.ReadWrite' {
            $content = Get-Content (Join-Path $script:ModulesPath 'ConditionalAccessGovernance.psm1') -Raw
            $content | Should -Not -Match 'Policy\.ReadWrite'
        }
    }
}
