#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev1.1 Reporting Tests' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\modules'

        Remove-Module Utilities       -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery       -Force -ErrorAction SilentlyContinue
        Remove-Module Analysis        -Force -ErrorAction SilentlyContinue
        Remove-Module Reporting       -Force -ErrorAction SilentlyContinue
        Remove-Module RemediationPlan -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Analysis.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Reporting.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'RemediationPlan.psm1') -Force -DisableNameChecking

        $script:TempDir = Join-Path $env:TEMP "DecomTests_$(Get-Random)"
        New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

        $script:TestFindings = @(
            (New-DecomFinding `
                -FindingId 'TEST-CRIT-001' `
                -Category 'User Lifecycle' `
                -Severity 'Critical' `
                -RiskScore 92 `
                -Confidence 'High' `
                -ObjectType 'User' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'Disabled Admin' `
                -UserPrincipalName 'admin@contoso.com' `
                -Evidence 'Disabled user retains Global Administrator role' `
                -EvidenceSource 'directoryRoles' `
                -GraphEndpoint '/v1.0/directoryRoles/{id}/members' `
                -RecommendedAction 'Remove role assignment' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'Confirm before removal'),
            (New-DecomFinding `
                -FindingId 'TEST-HIGH-001' `
                -Category 'Application' `
                -Severity 'High' `
                -RiskScore 70 `
                -Confidence 'High' `
                -ObjectType 'Application' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'Ownerless App' `
                -UserPrincipalName '' `
                -Evidence 'Application has no owner assigned' `
                -EvidenceSource 'applications' `
                -GraphEndpoint '/v1.0/applications/{id}/owners' `
                -RecommendedAction 'Assign owner to application' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'Governance gap')
        )

        $script:TestContext = [PSCustomObject]@{
            TenantId     = 'test.onmicrosoft.com'
            Mode         = 'Assessment'
            DemoMode     = $false
            EngagementId = 'ENG-TEST-001'
            ClientName   = 'Test Client'
            Assessor     = 'Test Assessor'
            Coverage     = [ordered]@{ Users = $true; Groups = $false }
        }
    }

    AfterAll {
        if (Test-Path $script:TempDir) {
            Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'CSV export' {
        It 'CSV export creates file at expected path' {
            $csvPath = Join-Path $script:TempDir 'test-findings.csv'
            Export-DecomAssessmentCsv -Findings $script:TestFindings -Path $csvPath
            Test-Path $csvPath | Should -Be $true
        }

        It 'CSV contains required columns (FindingId, Severity, Category, Evidence, RecommendedAction)' {
            $csvPath = Join-Path $script:TempDir 'test-findings-cols.csv'
            Export-DecomAssessmentCsv -Findings $script:TestFindings -Path $csvPath
            $csv     = Import-Csv $csvPath
            $headers = $csv[0].PSObject.Properties.Name
            $headers | Should -Contain 'FindingId'
            $headers | Should -Contain 'Severity'
            $headers | Should -Contain 'Category'
            $headers | Should -Contain 'Evidence'
            $headers | Should -Contain 'RecommendedAction'
        }
    }

    Context 'JSON export' {
        It 'JSON export produces valid JSON' {
            $jsonPath = Join-Path $script:TempDir 'test-findings.json'
            Export-DecomAssessmentJson -Findings $script:TestFindings -Path $jsonPath -Context $script:TestContext
            { Get-Content $jsonPath -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'JSON contains SchemaVersion, Findings, and FindingCount' {
            $jsonPath = Join-Path $script:TempDir 'test-findings-schema.json'
            Export-DecomAssessmentJson -Findings $script:TestFindings -Path $jsonPath -Context $script:TestContext
            $json = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $json.SchemaVersion | Should -Not -BeNullOrEmpty
            $json.FindingCount  | Should -Be $script:TestFindings.Count
            $json.Findings      | Should -Not -BeNullOrEmpty
        }
    }

    Context 'HTML export' {
        It 'HTML export creates file at expected path' {
            $htmlPath = Join-Path $script:TempDir 'test-report.html'
            $summary  = @{ Critical = 1; High = 1; Medium = 0; Low = 0; Informational = 0; Total = 2 }
            Export-DecomAssessmentHtml -Findings $script:TestFindings -Path $htmlPath -Context $script:TestContext -Summary $summary
            Test-Path $htmlPath | Should -Be $true
        }

        It 'HTML contains Executive Summary text' {
            $htmlPath = Join-Path $script:TempDir 'test-report-content.html'
            $summary  = @{ Critical = 1; High = 1; Medium = 0; Low = 0; Informational = 0; Total = 2 }
            Export-DecomAssessmentHtml -Findings $script:TestFindings -Path $htmlPath -Context $script:TestContext -Summary $summary
            $content  = Get-Content $htmlPath -Raw
            $content  | Should -Match 'Executive Summary'
        }
    }

    Context 'Remediation plan' {
        It 'Remediation plan contains PendingReview status' {
            $planPath = Join-Path $script:TempDir 'test-remediation.md'
            Export-DecomRemediationPlan -Findings $script:TestFindings -Path $planPath -Context $script:TestContext
            $content = Get-Content $planPath -Raw
            $content | Should -Match 'PendingReview'
        }

        It 'Remediation plan references finding IDs from Critical and High findings' {
            $planPath = Join-Path $script:TempDir 'test-remediation-ids.md'
            Export-DecomRemediationPlan -Findings $script:TestFindings -Path $planPath -Context $script:TestContext
            $content = Get-Content $planPath -Raw
            $content | Should -Match 'TEST-CRIT-001'
            $content | Should -Match 'TEST-HIGH-001'
        }
    }

    Context 'Rev1.2 empty-findings and Medium plan sections' {
        It 'CSV export succeeds with empty findings array' {
            $path = Join-Path $TestDrive 'empty.csv'
            { Export-DecomAssessmentCsv -Findings @() -Path $path } | Should -Not -Throw
            Test-Path $path | Should -Be $true
        }

        It 'Remediation plan includes Medium findings in Review Queue section' {
            $findings = @(
                (New-DecomFinding -FindingId 'MED-001' -Category 'User Lifecycle' `
                    -Severity 'Medium' -RiskScore 50 -Confidence 'High' `
                    -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
                    -DisplayName 'Test User' -UserPrincipalName 'test@contoso.com' `
                    -Evidence 'Medium finding test' -EvidenceSource 'test' `
                    -RecommendedAction 'Review access' -RemediationMode 'ManualApprovalRequired')
            )
            $path = Join-Path $TestDrive 'plan.md'
            $ctx  = [PSCustomObject]@{ Mode='Assessment'; TenantId='test'; EngagementId=''; ClientName=''; Assessor='' }
            Export-DecomRemediationPlan -Findings $findings -Path $path -Context $ctx
            $content = Get-Content $path -Raw
            $content | Should -Match 'Review Queue'
            $content | Should -Match 'MED-001'
        }
    }
}
