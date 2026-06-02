#Requires -Version 5.1

Describe 'EmergencyAccessGovernance.Rev32 — Emergency Access Governance Pack' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','EmergencyAccessGovernance')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')                  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'EmergencyAccessGovernance.psm1') -Force -DisableNameChecking

        $script:testDir = Join-Path $env:TEMP 'Decom-Rev32-EAGov'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $breakGlassId = [guid]::NewGuid().ToString()
        $protectedAppId = [guid]::NewGuid().ToString()

        $findings = @(
            [PSCustomObject]@{
                FindingId       = 'DEC-USER-001'
                ObjectId        = $breakGlassId
                DisplayName     = 'break-glass-acct-01'
                ObjectType      = 'User'
                ProtectedObject = $true
                IsBreakGlass    = $true
                IsEmergencyAccess = $true
            },
            [PSCustomObject]@{
                FindingId       = 'DEC-APP-001'
                ObjectId        = $protectedAppId
                DisplayName     = 'ProtectedEmergencyApp'
                ObjectType      = 'Application'
                ProtectedObject = $true
                IsBreakGlass    = $false
                IsEmergencyAccess = $false
            }
        )

        $whatIfActions = @(
            [PSCustomObject]@{
                ActionId       = [guid]::NewGuid().ToString()
                FindingId      = 'DEC-USER-001'
                ActionType     = 'RemoveGroupMembership'
                ObjectId       = $breakGlassId
                DisplayName    = 'break-glass-acct-01'
                ProtectedObject= $true
            }
        )

        $approvalActions = @(
            [PSCustomObject]@{
                ActionId       = [guid]::NewGuid().ToString()
                FindingId      = 'DEC-USER-001'
                ActionType     = 'RemoveGroupMembership'
                ObjectId       = $breakGlassId
                DisplayName    = 'break-glass-acct-01'
                ProtectedObject= $true
            }
        )

        $script:Context = @{
            ToolVersion  = 'Rev3.2'
            ClientName   = 'TestClient'
            EngagementId = 'ENG-EAGOV-01'
            Assessor     = 'TestAssessor'
            TenantId     = 'test-tenant-id'
        }

        $script:Model = New-DecomEmergencyAccessGovernanceModel `
            -Context $script:Context `
            -Findings $findings `
            -WhatIfActions $whatIfActions `
            -ApprovalActions $approvalActions
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('EmergencyAccessGovernance','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Emergency access governance model is created with SchemaVersion 3.2' {
        $script:Model | Should -Not -BeNullOrEmpty
        $script:Model.SchemaVersion | Should -Be '3.2'
    }

    It 'Emergency access governance model counts protected objects correctly' {
        $script:Model.ProtectedObjectCount | Should -Be 2
    }

    It 'Emergency access governance model identifies emergency access accounts' {
        $script:Model.EmergencyAccessAccountCount | Should -BeGreaterThan 0
    }

    It 'Emergency access governance model records WhatIf actions blocked by ProtectedObject' {
        $script:Model.WhatIfActionsBlockedCount | Should -Be 1
    }

    It 'Emergency access governance model records approval actions blocked by ProtectedObject' {
        $script:Model.ApprovalActionsBlockedCount | Should -Be 1
    }

    It 'Emergency access governance report Markdown exports without error' {
        $path = Join-Path $script:testDir 'ea-report.md'
        { Export-DecomEmergencyAccessGovernanceReportMarkdown -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Emergency access governance report Markdown notes ProtectedObject safety guarantee' {
        $path = Join-Path $script:testDir 'ea-report2.md'
        Export-DecomEmergencyAccessGovernanceReportMarkdown -Model $script:Model -Path $path
        $content = Get-Content $path -Raw
        $content | Should -Match '(?i)(protected.*object|ProtectedObject.*wins|safety)'
    }

    It 'Emergency access governance report HTML exports without error' {
        $path = Join-Path $script:testDir 'ea-report.html'
        { Export-DecomEmergencyAccessGovernanceReportHtml -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Protected object validation JSON exports without error' {
        $path = Join-Path $script:testDir 'po-validation.json'
        { Export-DecomProtectedObjectValidationJson -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'Protected object validation JSON has SchemaVersion 3.2' {
        $path = Join-Path $script:testDir 'po-validation2.json'
        Export-DecomProtectedObjectValidationJson -Model $script:Model -Path $path
        $json = Get-Content $path -Raw | ConvertFrom-Json
        $json.SchemaVersion | Should -Be '3.2'
    }

    It 'Protected object validation CSV exports without error' {
        $path = Join-Path $script:testDir 'po-validation.csv'
        { Export-DecomProtectedObjectValidationCsv -Model $script:Model -Path $path } | Should -Not -Throw
        Test-Path $path | Should -Be $true
    }

    It 'EmergencyAccessGovernance.psm1 is read-only — no Graph write calls' {
        $content = Get-Content (Join-Path $script:ModulesPath 'EmergencyAccessGovernance.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-Mg'
    }

    It 'Emergency access governance model includes hygiene gap recommendations' {
        $script:Model.PotentialHygieneGaps | Should -Not -BeNullOrEmpty
    }
}
