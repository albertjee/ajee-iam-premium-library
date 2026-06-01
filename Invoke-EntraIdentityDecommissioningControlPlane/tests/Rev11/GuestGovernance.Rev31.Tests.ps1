#Requires -Version 5.1

Describe 'GuestGovernance.psm1 — Rev3.1 No-Write Safety' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        $script:GGPath = Join-Path $script:ModulesPath 'GuestGovernance.psm1'
        $script:GGContent = Get-Content $script:GGPath -Raw
    }

    It 'GuestGovernance.psm1 contains no Remove-Mg cmdlets' {
        $script:GGContent | Should -Not -Match 'Remove-Mg'
    }

    It 'GuestGovernance.psm1 contains no Update-Mg cmdlets' {
        $script:GGContent | Should -Not -Match 'Update-Mg'
    }

    It 'GuestGovernance.psm1 contains no Set-Mg cmdlets' {
        $script:GGContent | Should -Not -Match 'Set-Mg'
    }

    It 'GuestGovernance.psm1 contains no New-Mg cmdlets' {
        $script:GGContent | Should -Not -Match 'New-Mg'
    }

    It 'GuestGovernance.psm1 contains no Connect-MgGraph calls' {
        $script:GGContent | Should -Not -Match 'Connect-MgGraph'
    }

    It 'GuestGovernance.psm1 contains no Invoke-MgGraphRequest with non-GET method' {
        $script:GGContent | Should -Not -Match "Invoke-MgGraphRequest.*-Method\s+['""]?(POST|PUT|PATCH|DELETE)"
    }
}

Describe 'GuestGovernance.psm1 — Rev3.1 Governance Pack Functions' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','GuestGovernance')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'GuestGovernance.psm1')  -Force -DisableNameChecking

        $script:TestContext = [PSCustomObject]@{
            ToolVersion  = 'Rev3.1'
            ClientName   = 'TestClient'
            EngagementId = 'ENG-GG-001'
            Assessor     = 'Test Assessor'
            TenantId     = 'test-tenant-id'
        }
        $script:OutDir = Join-Path $TestDrive 'gg-output'
        New-Item -ItemType Directory -Path $script:OutDir -Force | Out-Null
    }

    AfterAll {
        foreach ($m in @('GuestGovernance','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'New-DecomGuestGovernanceModel returns a model with SchemaVersion 3.1' {
        $model = New-DecomGuestGovernanceModel -Context $script:TestContext
        $model.SchemaVersion | Should -Be '3.1'
    }

    It 'New-DecomGuestGovernanceModel returns a model with correct ToolVersion' {
        $model = New-DecomGuestGovernanceModel -Context $script:TestContext
        $model.ToolVersion | Should -Be 'Rev3.1'
    }

    It 'New-DecomGuestGovernanceModel returns a model with Guests array' {
        $model = New-DecomGuestGovernanceModel -Context $script:TestContext
        $model.PSObject.Properties.Name | Should -Contain 'Guests'
        ($model.Guests -is [array]) | Should -Be $true
    }

    It 'Get-DecomGuestRemediationReadiness returns PlanOnlyMissingExactTarget for a finding without exact IDs' {
        $finding = [PSCustomObject]@{
            ObjectId          = 'guest-001'
            DisplayName       = 'Test Guest'
            UserPrincipalName = 'guest@external.com'
            UserType          = 'Guest'
            FindingId         = 'DEC-GUEST-001'
        }
        $readiness = Get-DecomGuestRemediationReadiness -Finding $finding
        $readiness.ReadinessStatus | Should -Be 'PlanOnlyMissingExactTarget'
    }

    It 'Export-DecomGuestRemediationReadinessJson creates a file' {
        $path = Join-Path $script:OutDir 'guest-readiness.json'
        Export-DecomGuestRemediationReadinessJson -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
    }

    It 'Export-DecomGuestRemediationReadinessCsv creates a file' {
        $path = Join-Path $script:OutDir 'guest-readiness.csv'
        Export-DecomGuestRemediationReadinessCsv -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
    }

    It 'Export-DecomGuestGovernanceDashboardHtml creates an HTML file' {
        $path = Join-Path $script:OutDir 'guest-governance-dashboard.html'
        Export-DecomGuestGovernanceDashboardHtml -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
        (Get-Content $path -Raw) | Should -Match '<html'
    }

    It 'Export-DecomGuestOwnerApprovalPacketMarkdown creates a Markdown file' {
        $path = Join-Path $script:OutDir 'guest-approval-packet.md'
        Export-DecomGuestOwnerApprovalPacketMarkdown -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
        (Get-Content $path -Raw) | Should -Match 'Guest Owner Approval Packet'
    }

    It 'Export-DecomGuestOwnerApprovalPacketHtml creates an HTML file' {
        $path = Join-Path $script:OutDir 'guest-approval-packet.html'
        Export-DecomGuestOwnerApprovalPacketHtml -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
        (Get-Content $path -Raw) | Should -Match '<html'
    }

    It 'Export-DecomGuestAccessExceptionRegisterCsv creates a CSV file with correct headers' {
        $path = Join-Path $script:OutDir 'guest-exceptions.csv'
        Export-DecomGuestAccessExceptionRegisterCsv -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
        (Get-Content $path -Raw) | Should -Match 'ExceptionId'
        (Get-Content $path -Raw) | Should -Match 'GuestObjectId'
    }

    It 'Export-DecomGuestRemediationEvidenceAppendixMarkdown creates a Markdown file' {
        $path = Join-Path $script:OutDir 'guest-evidence-appendix.md'
        Export-DecomGuestRemediationEvidenceAppendixMarkdown -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
        (Get-Content $path -Raw) | Should -Match 'Remediation Evidence Appendix'
    }

    It 'Export-DecomGuestActionRollbackGuideMarkdown creates a Markdown file' {
        $path = Join-Path $script:OutDir 'guest-rollback-guide.md'
        Export-DecomGuestActionRollbackGuideMarkdown -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
        (Get-Content $path -Raw) | Should -Match 'Rollback'
    }

    It 'Export-DecomGuestAccessSummaryJson creates a JSON file with SchemaVersion 3.1' {
        $path = Join-Path $script:OutDir 'guest-access-summary.json'
        Export-DecomGuestAccessSummaryJson -Context $script:TestContext -Path $path
        Test-Path $path | Should -Be $true
        $data = Get-Content $path -Raw | ConvertFrom-Json
        $data.SchemaVersion | Should -Be '3.1'
    }
}
