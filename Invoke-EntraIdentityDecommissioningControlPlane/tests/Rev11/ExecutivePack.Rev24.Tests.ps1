#Requires -Version 5.1
#Requires -Modules Pester

Describe 'Rev2.4 ExecutivePack Module' {

    BeforeAll {
        Set-Location (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
        foreach ($m in @('Utilities','Baseline','ExecutivePack')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
            Import-Module ".\src\Modules\$m.psm1" -Force -DisableNameChecking
        }

        # Helper: create minimal finding
        function New-ExecTestFinding {
            param(
                [string]$FindingId = 'DEC-USER-001',
                [string]$Severity  = 'High',
                [int]$RiskScore    = 70,
                [string]$Category  = 'User Lifecycle',
                [string]$Evidence  = 'Test evidence'
            )
            return [PSCustomObject]@{
                FindingId   = $FindingId
                ObjectType  = 'User'
                ObjectId    = [guid]::NewGuid().Guid
                DisplayName = 'Test Object'
                Severity    = $Severity
                RiskScore   = $RiskScore
                Category    = $Category
                Evidence    = $Evidence
                RunId       = $null
            }
        }

        # Shared contexts
        $script:EmptyContext = [PSCustomObject]@{
            SchemaVersion      = '2.4'
            ToolVersion        = 'Rev2.4'
            ClientName         = 'Contoso'
            EngagementId       = 'ENG-001'
            Assessor           = 'Albert Jee'
            TenantId           = 'contoso.onmicrosoft.com'
            GeneratedUtc       = (Get-Date).ToUniversalTime().ToString('o')
            Coverage           = @{ Users = $true; Guests = $true; PIM = $false }
            Findings           = @()
            Summary            = @{ Critical=0; High=0; Medium=0; Low=0; Total=0 }
            BaselineComparison = $null
            BaselineSummary    = $null
            RiskMovement       = $null
            ExportPaths        = @{ Csv = 'C:\out\test.csv'; Json = 'C:\out\test.json' }
        }

        $script:CriticalContext = [PSCustomObject]@{
            SchemaVersion      = '2.4'
            ToolVersion        = 'Rev2.4'
            ClientName         = 'Contoso'
            EngagementId       = 'ENG-002'
            Assessor           = 'Albert Jee'
            TenantId           = 'contoso.onmicrosoft.com'
            GeneratedUtc       = (Get-Date).ToUniversalTime().ToString('o')
            Coverage           = @{ Users = $true; Guests = $true; PIM = $true }
            Findings           = @(
                (New-ExecTestFinding -FindingId 'DEC-USER-001' -Severity 'Critical' -RiskScore 90),
                (New-ExecTestFinding -FindingId 'DEC-GUEST-001' -Severity 'Critical' -RiskScore 88),
                (New-ExecTestFinding -FindingId 'DEC-PIM-001'   -Severity 'Critical' -RiskScore 86)
            )
            Summary            = @{ Critical=3; High=0; Medium=0; Low=0; Total=3 }
            BaselineComparison = $null
            BaselineSummary    = $null
            RiskMovement       = $null
            ExportPaths        = @{}
        }

        $script:ElevatedContext = [PSCustomObject]@{
            SchemaVersion = '2.4'
            ToolVersion   = 'Rev2.4'
            ClientName    = 'Fabrikam'
            EngagementId  = 'ENG-003'
            Assessor      = 'Albert Jee'
            TenantId      = 'fabrikam.onmicrosoft.com'
            GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
            Coverage      = @{ Users = $true; Guests = $true; PIM = $true }
            Findings      = @(
                (New-ExecTestFinding -FindingId 'DEC-USER-001' -Severity 'High' -RiskScore 75),
                (New-ExecTestFinding -FindingId 'DEC-GUEST-001' -Severity 'High' -RiskScore 72),
                (New-ExecTestFinding -FindingId 'DEC-PIM-001'   -Severity 'High' -RiskScore 70),
                (New-ExecTestFinding -FindingId 'DEC-APP-001'   -Severity 'High' -RiskScore 68),
                (New-ExecTestFinding -FindingId 'DEC-CA-001'    -Severity 'High' -RiskScore 65)
            )
            Summary       = @{ Critical=0; High=5; Medium=0; Low=0; Total=5 }
            BaselineComparison = $null
            BaselineSummary    = $null
            RiskMovement       = $null
            ExportPaths        = @{}
        }

        $script:ModerateContext = [PSCustomObject]@{
            SchemaVersion = '2.4'
            ToolVersion   = 'Rev2.4'
            ClientName    = 'Northwind'
            EngagementId  = 'ENG-004'
            Assessor      = 'Albert Jee'
            TenantId      = 'northwind.onmicrosoft.com'
            GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
            Coverage      = @{ Users = $true; Guests = $true; PIM = $true }
            Findings      = @(
                (New-ExecTestFinding -FindingId 'DEC-USER-001' -Severity 'Medium' -RiskScore 45),
                (New-ExecTestFinding -FindingId 'DEC-GUEST-001' -Severity 'High' -RiskScore 65)
            )
            Summary       = @{ Critical=0; High=1; Medium=1; Low=0; Total=2 }
            BaselineComparison = $null
            BaselineSummary    = $null
            RiskMovement       = $null
            ExportPaths        = @{}
        }
    }

    Context 'New-DecomExecutiveSummaryModel — model creation' {

        It 'Executive summary model is created without throwing' {
            { New-DecomExecutiveSummaryModel -Context $script:EmptyContext } | Should -Not -Throw
        }

        It 'Model SchemaVersion is 2.4' {
            $model = New-DecomExecutiveSummaryModel -Context $script:EmptyContext
            $model.SchemaVersion | Should -Be '2.4'
        }

        It 'Model ToolVersion matches context' {
            $model = New-DecomExecutiveSummaryModel -Context $script:EmptyContext
            $model.ToolVersion | Should -Be 'Rev2.4'
        }

        It 'Model has RecommendedNextActions' {
            $model = New-DecomExecutiveSummaryModel -Context $script:EmptyContext
            $model.RecommendedNextActions | Should -Not -BeNullOrEmpty
            $model.RecommendedNextActions.Count | Should -BeGreaterOrEqual 1
        }

        It 'Model ConsultantNotes is populated' {
            $model = New-DecomExecutiveSummaryModel -Context $script:EmptyContext
            $model.ConsultantNotes | Should -Not -BeNullOrEmpty
        }
    }

    Context 'New-DecomExecutiveSummaryModel — risk posture algorithm' {

        It 'Critical posture assigned when 3 or more critical findings' {
            $model = New-DecomExecutiveSummaryModel -Context $script:CriticalContext
            $model.ExecutiveRiskPosture | Should -Be 'Critical'
        }

        It 'Elevated posture assigned with 5 or more high findings' {
            $model = New-DecomExecutiveSummaryModel -Context $script:ElevatedContext
            $model.ExecutiveRiskPosture | Should -Be 'Elevated'
        }

        It 'Moderate posture assigned with mixed medium/high but no critical threshold' {
            $model = New-DecomExecutiveSummaryModel -Context $script:ModerateContext
            $model.ExecutiveRiskPosture | Should -Be 'Moderate'
        }

        It 'Low posture only when no Critical/High and coverage is full' {
            $ctx = [PSCustomObject]@{
                SchemaVersion = '2.4'; ToolVersion = 'Rev2.4'; ClientName = 'Test'
                EngagementId = 'T-001'; Assessor = 'Test'; TenantId = 'test'
                GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
                Coverage = @{ Users = $true; Guests = $true; PIM = $true }
                Findings = @()
                Summary = @{ Critical=0; High=0; Medium=0; Low=0; Total=0 }
                BaselineComparison = $null; BaselineSummary = $null; RiskMovement = $null
                ExportPaths = @{}
            }
            $model = New-DecomExecutiveSummaryModel -Context $ctx
            $model.ExecutiveRiskPosture | Should -Be 'Low'
        }

        It 'Low posture NOT assigned when coverage has partial area (partial defaults to Moderate)' {
            $ctx = [PSCustomObject]@{
                SchemaVersion = '2.4'; ToolVersion = 'Rev2.4'; ClientName = 'Test'
                EngagementId = 'T-001'; Assessor = 'Test'; TenantId = 'test'
                GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
                Coverage = @{ Users = $true; Guests = $false; PIM = $false }
                Findings = @()
                Summary = @{ Critical=0; High=0; Medium=0; Low=0; Total=0 }
                BaselineComparison = $null; BaselineSummary = $null; RiskMovement = $null
                ExportPaths = @{}
            }
            $model = New-DecomExecutiveSummaryModel -Context $ctx
            $model.ExecutiveRiskPosture | Should -Not -Be 'Low'
        }

        It 'Critical severity DEC-REV finding triggers Critical posture' {
            $ctx = [PSCustomObject]@{
                SchemaVersion = '2.4'; ToolVersion = 'Rev2.4'; ClientName = 'Test'
                EngagementId = 'T-001'; Assessor = 'Test'; TenantId = 'test'
                GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
                Coverage = @{ Users = $true }
                Findings = @(New-ExecTestFinding -FindingId 'DEC-REV-005' -Severity 'Critical' -RiskScore 90)
                Summary = @{ Critical=1; High=0; Medium=0; Low=0; Total=1 }
                BaselineComparison = $null; BaselineSummary = $null; RiskMovement = $null
                ExportPaths = @{}
            }
            $model = New-DecomExecutiveSummaryModel -Context $ctx
            $model.ExecutiveRiskPosture | Should -Be 'Critical'
        }
    }

    Context 'New-DecomExecutiveSummaryModel — top risk selection' {

        It 'Top risks are sorted by RiskScore descending' {
            $model = New-DecomExecutiveSummaryModel -Context $script:CriticalContext
            if ($model.TopRisks.Count -ge 2) {
                $model.TopRisks[0].RiskScore | Should -BeGreaterOrEqual $model.TopRisks[1].RiskScore
            }
        }

        It 'Top risks count does not exceed 10' {
            $manyFindings = 1..15 | ForEach-Object {
                New-ExecTestFinding -FindingId "DEC-USER-$(($_ % 5).ToString('D3'))" -Severity 'High' -RiskScore (50 + $_)
            }
            $ctx = [PSCustomObject]@{
                SchemaVersion='2.4'; ToolVersion='Rev2.4'; ClientName='Test'; EngagementId='T'; Assessor='T'; TenantId='t'
                GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o')
                Coverage=@{}; Findings=$manyFindings; Summary=@{ Critical=0; High=15; Medium=0; Low=0; Total=15 }
                BaselineComparison=$null; BaselineSummary=$null; RiskMovement=$null; ExportPaths=@{}
            }
            $model = New-DecomExecutiveSummaryModel -Context $ctx
            $model.TopRisks.Count | Should -BeLessOrEqual 10
        }
    }

    Context 'Export-DecomExecutiveSummaryMarkdown' {

        BeforeAll {
            $script:ExecMdModel = New-DecomExecutiveSummaryModel -Context $script:CriticalContext
        }

        It 'Markdown file is created' {
            $path = Join-Path $TestDrive 'exec-summary.md'
            Export-DecomExecutiveSummaryMarkdown -Model $script:ExecMdModel -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Markdown contains ToolVersion Rev2.4' {
            $path = Join-Path $TestDrive 'exec-summary-tv.md'
            Export-DecomExecutiveSummaryMarkdown -Model $script:ExecMdModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Rev2\.4'
        }

        It 'Markdown contains Executive Risk Posture section' {
            $path = Join-Path $TestDrive 'exec-summary-posture.md'
            Export-DecomExecutiveSummaryMarkdown -Model $script:ExecMdModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Executive Risk Posture'
        }

        It 'Markdown contains Top 10 Risks section' {
            $path = Join-Path $TestDrive 'exec-summary-risks.md'
            Export-DecomExecutiveSummaryMarkdown -Model $script:ExecMdModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Top 10 Risks'
        }

        It 'Markdown footer contains copyright' {
            $path = Join-Path $TestDrive 'exec-summary-footer.md'
            Export-DecomExecutiveSummaryMarkdown -Model $script:ExecMdModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match '© 2026 Albert Jee'
        }

        It 'Markdown handles no baseline gracefully' {
            $noBaselineModel = New-DecomExecutiveSummaryModel -Context $script:EmptyContext
            $path = Join-Path $TestDrive 'exec-summary-nobaseline.md'
            { Export-DecomExecutiveSummaryMarkdown -Model $noBaselineModel -Path $path } | Should -Not -Throw
            $content = Get-Content $path -Raw
            $content | Should -Match 'No baseline provided'
        }
    }

    Context 'Export-DecomExecutiveSummaryHtml' {

        BeforeAll {
            $script:ExecHtmlModel = New-DecomExecutiveSummaryModel -Context $script:CriticalContext
        }

        It 'HTML file is created' {
            $path = Join-Path $TestDrive 'exec-summary.html'
            Export-DecomExecutiveSummaryHtml -Model $script:ExecHtmlModel -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'HTML contains Rev2.4' {
            $path = Join-Path $TestDrive 'exec-html-tv.html'
            Export-DecomExecutiveSummaryHtml -Model $script:ExecHtmlModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Rev2\.4'
        }

        It 'HTML contains executive posture' {
            $path = Join-Path $TestDrive 'exec-html-posture.html'
            Export-DecomExecutiveSummaryHtml -Model $script:ExecHtmlModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Critical|Elevated|Moderate|Low'
        }

        It 'HTML contains no external script or style references' {
            $path = Join-Path $TestDrive 'exec-html-safe.html'
            Export-DecomExecutiveSummaryHtml -Model $script:ExecHtmlModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Not -Match 'src="http'
            $content | Should -Not -Match 'href="http'
        }

        It 'HTML footer contains copyright' {
            $path = Join-Path $TestDrive 'exec-html-footer.html'
            Export-DecomExecutiveSummaryHtml -Model $script:ExecHtmlModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match '© 2026 Albert Jee'
        }
    }

    Context 'Export-DecomGovernanceKpiDashboardHtml' {

        BeforeAll {
            $script:KpiModel = New-DecomExecutiveSummaryModel -Context $script:CriticalContext
        }

        It 'Dashboard HTML file is created' {
            $path = Join-Path $TestDrive 'kpi-dashboard.html'
            Export-DecomGovernanceKpiDashboardHtml -Model $script:KpiModel -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Dashboard contains KPI tiles section' {
            $path = Join-Path $TestDrive 'kpi-tiles.html'
            Export-DecomGovernanceKpiDashboardHtml -Model $script:KpiModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Total'
            $content | Should -Match 'Critical'
        }

        It 'Dashboard contains Governance Coverage section' {
            $path = Join-Path $TestDrive 'kpi-coverage.html'
            Export-DecomGovernanceKpiDashboardHtml -Model $script:KpiModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Coverage'
        }

        It 'Dashboard contains Access Review Evidence section' {
            $path = Join-Path $TestDrive 'kpi-review.html'
            Export-DecomGovernanceKpiDashboardHtml -Model $script:KpiModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Access Review'
        }

        It 'Dashboard does not crash when coverage is null' {
            $ctx = [PSCustomObject]@{
                SchemaVersion='2.4'; ToolVersion='Rev2.4'; ClientName='Test'; EngagementId='T'; Assessor='T'; TenantId='t'
                GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o')
                Coverage=$null; Findings=@(); Summary=@{ Critical=0; High=0; Medium=0; Low=0; Total=0 }
                BaselineComparison=$null; BaselineSummary=$null; RiskMovement=$null; ExportPaths=@{}
            }
            $nullCovModel = New-DecomExecutiveSummaryModel -Context $ctx
            $path = Join-Path $TestDrive 'kpi-null-cov.html'
            { Export-DecomGovernanceKpiDashboardHtml -Model $nullCovModel -Path $path } | Should -Not -Throw
        }

        It 'Dashboard contains Baseline Movement section when baseline provided' {
            $ctxWithBaseline = [PSCustomObject]@{
                SchemaVersion='2.4'; ToolVersion='Rev2.4'; ClientName='Test'; EngagementId='T'; Assessor='T'; TenantId='t'
                GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o')
                Coverage=@{ Users=$true }; Findings=@(); Summary=@{ Critical=0; High=0; Medium=0; Low=0; Total=0 }
                BaselineComparison=$null
                BaselineSummary=@{ New=2; Persisting=3; Resolved=1; ChangedSeverity=0; ChangedRiskScore=0; ChangedEvidence=0; Unchanged=2; NetRiskDelta=15 }
                RiskMovement=$null; ExportPaths=@{}
            }
            $modelWithBaseline = New-DecomExecutiveSummaryModel -Context $ctxWithBaseline
            $path = Join-Path $TestDrive 'kpi-with-baseline.html'
            Export-DecomGovernanceKpiDashboardHtml -Model $modelWithBaseline -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Baseline Movement'
        }
    }

    Context 'Export-DecomConsultantEvidenceAppendixMarkdown' {

        BeforeAll {
            $script:AppendixModel = New-DecomExecutiveSummaryModel -Context $script:CriticalContext
        }

        It 'Appendix markdown file is created' {
            $path = Join-Path $TestDrive 'appendix.md'
            Export-DecomConsultantEvidenceAppendixMarkdown -Model $script:AppendixModel -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Appendix contains safety model statement' {
            $path = Join-Path $TestDrive 'appendix-safety.md'
            Export-DecomConsultantEvidenceAppendixMarkdown -Model $script:AppendixModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'read-only'
            $content | Should -Match 'three-gate'
        }

        It 'Appendix contains coverage limitations' {
            $path = Join-Path $TestDrive 'appendix-cov.md'
            Export-DecomConsultantEvidenceAppendixMarkdown -Model $script:AppendixModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Coverage Limitations'
        }

        It 'Appendix contains export inventory section' {
            $modelWithPaths = New-DecomExecutiveSummaryModel -Context ([PSCustomObject]@{
                SchemaVersion='2.4'; ToolVersion='Rev2.4'; ClientName='Test'; EngagementId='T'; Assessor='T'; TenantId='t'
                GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o')
                Coverage=@{}; Findings=@(); Summary=@{ Critical=0; High=0; Medium=0; Low=0; Total=0 }
                BaselineComparison=$null; BaselineSummary=$null; RiskMovement=$null
                ExportPaths=@{ Csv='C:\out\test.csv'; Json='C:\out\test.json' }
            })
            $path = Join-Path $TestDrive 'appendix-exports.md'
            Export-DecomConsultantEvidenceAppendixMarkdown -Model $modelWithPaths -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Match 'Export File Inventory'
        }

        It 'Appendix contains no write or remediation expansion language' {
            $path = Join-Path $TestDrive 'appendix-nowrites.md'
            Export-DecomConsultantEvidenceAppendixMarkdown -Model $script:AppendixModel -Path $path
            $content = Get-Content $path -Raw
            $content | Should -Not -Match 'ReadWrite'
            $content | Should -Not -Match 'Remove-Mg'
        }
    }

    Context 'Write-DecomClientReadoutPackManifest' {

        BeforeAll {
            $script:ManifestModel = New-DecomExecutiveSummaryModel -Context ([PSCustomObject]@{
                SchemaVersion='2.4'; ToolVersion='Rev2.4'; ClientName='Contoso'; EngagementId='ENG-001'; Assessor='Albert Jee'; TenantId='contoso.onmicrosoft.com'
                GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o')
                Coverage=@{ Users=$true }; Findings=@(); Summary=@{ Critical=0; High=0; Medium=0; Low=0; Total=0 }
                BaselineComparison=$null; BaselineSummary=$null; RiskMovement=$null
                ExportPaths=@{ Csv='C:\out\test.csv'; Json='C:\out\test.json'; Html='C:\out\test.html' }
            })
        }

        It 'Manifest JSON file is created' {
            $path = Join-Path $TestDrive 'readout-manifest.json'
            Write-DecomClientReadoutPackManifest -Model $script:ManifestModel -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Manifest SchemaVersion is 2.4' {
            $path = Join-Path $TestDrive 'readout-schema.json'
            Write-DecomClientReadoutPackManifest -Model $script:ManifestModel -Path $path
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.SchemaVersion | Should -Be '2.4'
        }

        It 'Manifest contains SafetyStatement' {
            $path = Join-Path $TestDrive 'readout-safety.json'
            Write-DecomClientReadoutPackManifest -Model $script:ManifestModel -Path $path
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.SafetyStatement | Should -Not -BeNullOrEmpty
            $json.SafetyStatement | Should -Match 'read-only'
        }

        It 'Manifest contains Files section' {
            $path = Join-Path $TestDrive 'readout-files.json'
            Write-DecomClientReadoutPackManifest -Model $script:ManifestModel -Path $path
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.Files | Should -Not -BeNullOrEmpty
        }

        It 'Manifest JSON is valid (parseable)' {
            $path = Join-Path $TestDrive 'readout-valid.json'
            Write-DecomClientReadoutPackManifest -Model $script:ManifestModel -Path $path
            { Get-Content $path -Raw | ConvertFrom-Json } | Should -Not -Throw
        }
    }
}
