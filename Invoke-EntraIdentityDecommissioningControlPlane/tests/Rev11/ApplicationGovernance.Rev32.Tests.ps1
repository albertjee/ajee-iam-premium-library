#Requires -Version 5.1

Describe 'ApplicationGovernance.Rev32 — Application Ownership Governance Pack' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','ApplicationGovernance')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')            -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Force -DisableNameChecking

        $script:testDir = Join-Path $env:TEMP 'Decom-Rev32-AppGov'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $findings = @(
            [PSCustomObject]@{
                FindingId   = 'DEC-APP-001'
                ObjectId    = [guid]::NewGuid().ToString()
                AppId       = [guid]::NewGuid().ToString()
                DisplayName = 'UnownedApp'
                OwnerCount  = 0
                HasOwner    = $false
                ProtectedObject = $false
            },
            [PSCustomObject]@{
                FindingId   = 'DEC-APP-002'
                ObjectId    = [guid]::NewGuid().ToString()
                AppId       = [guid]::NewGuid().ToString()
                DisplayName = 'DisabledOwnerApp'
                OwnerCount  = 1
                HasOwner    = $true
                ProtectedObject = $false
            },
            [PSCustomObject]@{
                FindingId   = 'DEC-APP-003'
                ObjectId    = [guid]::NewGuid().ToString()
                AppId       = [guid]::NewGuid().ToString()
                DisplayName = 'SingleOwnerApp'
                OwnerCount  = 1
                HasOwner    = $true
                ProtectedObject = $false
            },
            [PSCustomObject]@{
                FindingId   = 'DEC-SPN-001'
                ObjectId    = [guid]::NewGuid().ToString()
                AppId       = [guid]::NewGuid().ToString()
                DisplayName = 'NoOwnerSPN'
                OwnerCount  = 0
                HasOwner    = $false
                ProtectedObject = $false
            }
        )

        $script:Context = @{
            ToolVersion  = 'Rev3.2'
            ClientName   = 'TestClient'
            EngagementId = 'ENG-APPGOV-01'
            Assessor     = 'TestAssessor'
            TenantId     = 'test-tenant-id'
        }

        $script:Model = New-DecomApplicationGovernanceModel -Context $script:Context -Findings $findings
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('ApplicationGovernance','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Application governance model is created with SchemaVersion 3.2' {
        $script:Model | Should -Not -BeNullOrEmpty
        $script:Model.SchemaVersion | Should -Be '3.2'
    }

    It 'Application governance model counts unowned applications correctly' {
        $script:Model.UnownedApplicationCount | Should -Be 1
    }

    It 'Application governance model counts single-owner applications correctly' {
        $script:Model.SingleOwnerApplicationCount | Should -Be 1
    }

    It 'Application governance model counts service principals without owner correctly' {
        $script:Model.ServicePrincipalNoOwnerCount | Should -Be 1
    }

    It 'Get-DecomApplicationOwnerReadiness returns ReadyForApproval for DEC-APP-001' {
        $app = [PSCustomObject]@{
            ObjectId = [guid]::NewGuid().ToString()
            AppId = [guid]::NewGuid().ToString()
            DisplayName = 'UnownedApp'
            FindingId = 'DEC-APP-001'
            OwnerCount = 0
            HasOwner = $false
            IsSPN = $false
            ProtectedObject = $false
        }
        $result = Get-DecomApplicationOwnerReadiness -Application $app
        $result.ReadyForApproval | Should -Be $true
        $result.ReadinessStatus | Should -Be 'ReadyForOwnerApproval'
    }

    It 'Get-DecomApplicationOwnerReadiness returns PlanOnly for DEC-APP-003' {
        $app = [PSCustomObject]@{
            ObjectId = [guid]::NewGuid().ToString()
            AppId = [guid]::NewGuid().ToString()
            DisplayName = 'SingleOwnerApp'
            FindingId = 'DEC-APP-003'
            OwnerCount = 1
            HasOwner = $true
            IsSPN = $false
            ProtectedObject = $false
        }
        $result = Get-DecomApplicationOwnerReadiness -Application $app
        $result.PlanOnly | Should -Be $true
    }

    It 'Get-DecomApplicationOwnerReadiness blocks ProtectedObject' {
        $app = [PSCustomObject]@{
            ObjectId = [guid]::NewGuid().ToString()
            AppId = [guid]::NewGuid().ToString()
            DisplayName = 'ProtectedApp'
            FindingId = 'DEC-APP-001'
            OwnerCount = 0
            HasOwner = $false
            IsSPN = $false
            ProtectedObject = $true
        }
        $result = Get-DecomApplicationOwnerReadiness -Application $app
        $result.ReadyForApproval | Should -Be $false
        $result.ReadinessStatus | Should -Be 'BlockedProtectedObject'
    }

    It 'Application governance dashboard HTML exports without error' {
        $path = Join-Path $script:testDir 'app-dashboard.html'
        { Export-DecomApplicationGovernanceDashboardHtml -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Application governance dashboard HTML contains client name' {
        $path = Join-Path $script:testDir 'app-dashboard2.html'
        Export-DecomApplicationGovernanceDashboardHtml -Model $script:Model -Path $path
        $content = Get-Content $path -Raw
        $content | Should -Match 'TestClient'
    }

    It 'Application owner readiness JSON exports without error' {
        $path = Join-Path $script:testDir 'app-readiness.json'
        { Export-DecomApplicationOwnerReadinessJson -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Application owner readiness JSON has SchemaVersion 3.2' {
        $path = Join-Path $script:testDir 'app-readiness2.json'
        Export-DecomApplicationOwnerReadinessJson -Model $script:Model -Path $path
        $json = Get-Content $path -Raw | ConvertFrom-Json
        $json.SchemaVersion | Should -Be '3.2'
    }

    It 'Application owner readiness CSV exports without error' {
        $path = Join-Path $script:testDir 'app-readiness.csv'
        { Export-DecomApplicationOwnerReadinessCsv -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Application owner approval packet Markdown exports without error' {
        $path = Join-Path $script:testDir 'app-approval.md'
        { Export-DecomApplicationOwnerApprovalPacketMarkdown -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Application owner approval packet HTML exports without error' {
        $path = Join-Path $script:testDir 'app-approval.html'
        { Export-DecomApplicationOwnerApprovalPacketHtml -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Application ownership exception register CSV exports without error' {
        $path = Join-Path $script:testDir 'app-exceptions.csv'
        { Export-DecomApplicationOwnershipExceptionRegisterCsv -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Application governance evidence appendix Markdown exports without error' {
        $path = Join-Path $script:testDir 'app-evidence.md'
        { Export-DecomApplicationGovernanceEvidenceAppendixMarkdown -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'ApplicationGovernance.psm1 is read-only — no Graph write calls' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication'
    }
}
