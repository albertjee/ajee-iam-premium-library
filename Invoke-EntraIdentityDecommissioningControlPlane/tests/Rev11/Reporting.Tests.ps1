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

    Context 'Rev1.3 new findings in reporting' {
        It 'Remediation plan includes DEC-APP-002 Critical finding in Immediate Actions' {
            $findings = @(
                New-DecomFinding -FindingId 'DEC-APP-002' -Category 'Application' `
                    -Severity 'Critical' -RiskScore 88 -Confidence 'High' `
                    -ObjectType 'Application' -ObjectId ([guid]::NewGuid().Guid) `
                    -DisplayName 'HR Integration Service' -UserPrincipalName '' `
                    -Evidence 'Owned by disabled user' -EvidenceSource 'test' `
                    -RecommendedAction 'Assign active owner' -RemediationMode 'ManualApprovalRequired'
            )
            $path = Join-Path $TestDrive 'plan-app002.md'
            $ctx  = [PSCustomObject]@{ Mode='Assessment'; TenantId='test'; EngagementId=''; ClientName=''; Assessor='' }
            Export-DecomRemediationPlan -Findings $findings -Path $path -Context $ctx
            $content = Get-Content $path -Raw
            $content | Should -Match 'DEC-APP-002'
            $content | Should -Match 'Immediate Actions'
        }

        It 'CSV export includes all Rev1.3 finding IDs from synthetic dataset' {
            Import-Module .\src\modules\Discovery.psm1 -Force -DisableNameChecking
            Import-Module .\src\modules\Utilities.psm1 -Force -DisableNameChecking
            $findings = @(Get-DecomSyntheticFindings)
            $path = Join-Path $TestDrive 'rev13-findings.csv'
            Export-DecomAssessmentCsv -Findings $findings -Path $path
            $csv = Import-Csv $path
            $csv.FindingId | Should -Contain 'DEC-APP-003'
            $csv.FindingId | Should -Contain 'DEC-APP-004'
            $csv.FindingId | Should -Contain 'DEC-APP-005'
            $csv.FindingId | Should -Contain 'DEC-SPN-001'
            $csv.FindingId | Should -Contain 'DEC-USER-002'
        }

        It 'HTML report renders without error for Rev1.3 synthetic findings' {
            Import-Module .\src\modules\Discovery.psm1 -Force -DisableNameChecking
            Import-Module .\src\modules\Utilities.psm1 -Force -DisableNameChecking
            $findings = @(Get-DecomSyntheticFindings)
            $path = Join-Path $TestDrive 'rev13-report.html'
            $ctx  = [PSCustomObject]@{
                Mode='Assessment'; TenantId='contoso.onmicrosoft.com'
                EngagementId='TEST-013'; ClientName='Contoso'; Assessor='Albert Jee'
                DemoMode=$true; Coverage=@{}
            }
            { Export-DecomAssessmentHtml -Findings $findings -Path $path -Context $ctx } | Should -Not -Throw
            Test-Path $path | Should -Be $true
        }

        It 'Get-DecomFindingSummary returns correct counts for Rev1.3 synthetic dataset' {
            Import-ModULE .\src\modules\Discovery.psm1 -Force -DisableNameChecking
            Import-Module .\src\modules\Utilities.psm1 -Force -DisableNameChecking
            Import-Module .\src\modules\Analysis.psm1   -Force -DisableNameChecking
            $findings = @(Invoke-DecomAnalysis -Findings @(Get-DecomSyntheticFindings))
            $summary  = Get-DecomFindingSummary -Findings $findings
            $summary.Critical | Should -BeGreaterOrEqual 2
            $summary.High     | Should -BeGreaterOrEqual 4
            $summary.Total    | Should -BeGreaterOrEqual 13
        }
    }

    Context 'Rev1.4 new findings in reporting' {
        It 'CSV export includes all Rev1.4 finding IDs from synthetic dataset' {
            Import-Module .\src\Modules\Discovery.psm1 -Force -DisableNameChecking
            Import-Module .\src\Modules\Utilities.psm1  -Force -DisableNameChecking
            $findings = @(Get-DecomSyntheticFindings)
            $path = Join-Path $TestDrive 'rev14-findings.csv'
            Export-DecomAssessmentCsv -Findings $findings -Path $path
            $csv = Import-Csv $path
            $csv.FindingId | Should -Contain 'DEC-GUEST-003'
            $csv.FindingId | Should -Contain 'DEC-ROLE-001'
            $csv.FindingId | Should -Contain 'DEC-CA-002'
        }

        It 'Remediation plan includes DEC-ROLE-001 Critical finding in Immediate Actions' {
            $findings = @(
                New-DecomFinding -FindingId 'DEC-ROLE-001' -Category 'Privileged Access' `
                    -Severity 'Critical' -RiskScore 90 -Confidence 'High' `
                    -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
                    -DisplayName 'Sam Okafor' -UserPrincipalName 'sam.okafor@contoso.com' `
                    -Evidence 'Disabled user holds privileged role' -EvidenceSource 'test' `
                    -RecommendedAction 'Remove role assignment' -RemediationMode 'ManualApprovalRequired'
            )
            $path = Join-Path $TestDrive 'plan-role001.md'
            $ctx  = [PSCustomObject]@{ Mode='Assessment'; TenantId='test'; EngagementId=''; ClientName=''; Assessor='' }
            Export-DecomRemediationPlan -Findings $findings -Path $path -Context $ctx
            $content = Get-Content $path -Raw
            $content | Should -Match 'DEC-ROLE-001'
            $content | Should -Match 'Immediate Actions'
        }

        It 'HTML report renders without error for Rev1.4 synthetic findings' {
            Import-Module .\src\Modules\Discovery.psm1 -Force -DisableNameChecking
            Import-Module .\src\Modules\Utilities.psm1  -Force -DisableNameChecking
            $findings = @(Get-DecomSyntheticFindings)
            $path = Join-Path $TestDrive 'rev14-report.html'
            $ctx  = [PSCustomObject]@{
                Mode='Assessment'; TenantId='contoso.onmicrosoft.com'
                EngagementId='TEST-014'; ClientName='Contoso'; Assessor='Albert Jee'
                DemoMode=$true; Coverage=@{}
            }
            { Export-DecomAssessmentHtml -Findings $findings -Path $path -Context $ctx } | Should -Not -Throw
            Test-Path $path | Should -Be $true
        }
    }

    Context 'Rev2.2 reporting coverage' {
        It 'JSON export SchemaVersion is 2.3' {
            $path = Join-Path $TestDrive 'rev23-schema.json'
            Export-DecomAssessmentJson -Findings $script:TestFindings -Path $path -Context $script:TestContext
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.SchemaVersion | Should -Be '2.3'
        }

        It 'HTML renders without null crash for Rev2.2 PIM finding' {
            $pimFinding = New-DecomFinding `
                -FindingId 'DEC-PIM-001' -Category 'Privileged Access' `
                -Severity 'Critical' -RiskScore 86 -Confidence 'High' `
                -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'Disabled Admin (PIM)' `
                -UserPrincipalName 'disabled.admin@contoso.com' `
                -Evidence 'Disabled user retains eligible privileged role assignment.' `
                -EvidenceSource 'roleManagement/directory/roleEligibilityScheduleInstances' `
                -RecommendedAction 'Review and remove eligible role assignment' `
                -RemediationMode 'ManualApprovalRequired'
            $path    = Join-Path $TestDrive 'rev22-pim-html.html'
            $summary = @{ Critical=1; High=0; Medium=0; Low=0; Informational=0; Total=1 }
            $ctx     = [PSCustomObject]@{
                Mode='Assessment'; TenantId='contoso.onmicrosoft.com'
                EngagementId='TEST-022'; ClientName='Contoso'; Assessor='Albert Jee'
                DemoMode=$false; Coverage=@{}; ToolVersion='Rev2.2'
            }
            { Export-DecomAssessmentHtml -Findings @($pimFinding) -Path $path -Context $ctx -Summary $summary } | Should -Not -Throw
            Test-Path $path | Should -Be $true
        }

        It 'CSV export includes Rev2.2 finding IDs from synthetic dataset' {
            Import-Module .\src\Modules\Discovery.psm1 -Force -DisableNameChecking
            Import-Module .\src\Modules\Utilities.psm1  -Force -DisableNameChecking
            $findings = @(Get-DecomSyntheticFindings)
            $path = Join-Path $TestDrive 'rev22-findings.csv'
            Export-DecomAssessmentCsv -Findings $findings -Path $path
            $csv = Import-Csv $path
            $csv.FindingId | Should -Contain 'DEC-PIM-001'
            $csv.FindingId | Should -Contain 'DEC-PIM-002'
            $csv.FindingId | Should -Contain 'DEC-AP-001'
            $csv.FindingId | Should -Contain 'DEC-AP-005'
        }
    }

    Context 'Rev2.3 reporting coverage' {
        It 'Run manifest SchemaVersion is 2.3' {
            $path = Join-Path $TestDrive 'rev23-manifest-schema.json'
            $ctx = [PSCustomObject]@{
                TenantId='contoso.onmicrosoft.com'; Mode='Assessment'; DemoMode=$false
                EngagementId='TEST-023'; ClientName='Contoso'; Assessor='Albert Jee'
                Coverage=[ordered]@{ Users=$true; AccessReviews=$false }
            }
            Write-DecomRunManifest -Path $path -Context $ctx -Summary @{} -ExportPaths @{}
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $manifest.SchemaVersion | Should -Be '2.3'
        }

        It 'Run manifest includes Coverage' {
            $path = Join-Path $TestDrive 'rev23-manifest-cov.json'
            $ctx = [PSCustomObject]@{
                TenantId='test'; Mode='Assessment'; DemoMode=$false
                EngagementId='TEST-023'; ClientName='Test'; Assessor='Test'
                Coverage=[ordered]@{ Users=$true; AccessReviews=$false; GuestReviewCorrelation=$false }
            }
            Write-DecomRunManifest -Path $path -Context $ctx -Summary @{} -ExportPaths @{}
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $manifest.PSObject.Properties.Name | Should -Contain 'Coverage'
        }

        It 'HTML report includes ToolVersion Rev2.3' {
            $path = Join-Path $TestDrive 'rev23-toolversion.html'
            $ctx = [PSCustomObject]@{
                TenantId='test'; Mode='Assessment'; DemoMode=$false
                EngagementId='T-001'; ClientName='Test'; Assessor='Test'
                ToolVersion='Rev2.3'
                Coverage=[ordered]@{ Users=$true }
            }
            Export-DecomAssessmentHtml -Findings @() -Path $path -Context $ctx -Summary @{ Critical=0; High=0; Medium=0; Low=0; Informational=0; Total=0 }
            $html = Get-Content $path -Raw
            $html | Should -Match 'Rev2\.3'
        }

        It 'HTML report renders governance evidence coverage rows' {
            $path = Join-Path $TestDrive 'rev23-gov-coverage.html'
            $ctx = [PSCustomObject]@{
                TenantId='test'; Mode='Assessment'; DemoMode=$false
                EngagementId='T-001'; ClientName='Test'; Assessor='Test'
                ToolVersion='Rev2.3'
                Coverage=[ordered]@{
                    Users=$true; AccessReviews=$true
                    GuestReviewCorrelation=$false; PimReviewCorrelation=$true
                    GovernanceEvidenceLimitations=@()
                }
            }
            Export-DecomAssessmentHtml -Findings @() -Path $path -Context $ctx -Summary @{ Critical=0; High=0; Medium=0; Low=0; Informational=0; Total=0 }
            $html = Get-Content $path -Raw
            $html | Should -Match 'GuestReviewCorrelation'
            $html | Should -Match 'AccessReviews'
        }

        It 'Coverage limitations render without null crash' {
            $path = Join-Path $TestDrive 'rev23-null-cov.html'
            $ctx = [PSCustomObject]@{
                TenantId='test'; Mode='Assessment'; DemoMode=$false
                EngagementId='T-001'; ClientName='Test'; Assessor='Test'
                ToolVersion='Rev2.3'; Coverage=$null
            }
            { Export-DecomAssessmentHtml -Findings @() -Path $path -Context $ctx -Summary @{ Critical=0; High=0; Medium=0; Low=0; Informational=0; Total=0 } } | Should -Not -Throw
        }
    }
}
