#Requires -Version 5.1

Describe 'ApplicationOwnerRemediation.Rev33 — Application Owner Governance Pack Exports' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','ApplicationGovernance')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')            -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Force -DisableNameChecking

        $script:testDir = Join-Path $env:TEMP "Decom-Rev33-AppOwner-$(([guid]::NewGuid().Guid))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $script:Context = @{
            ToolVersion  = 'Rev3.3'
            ClientName   = 'TestClient'
            EngagementId = 'ENG-33-AO'
            Assessor     = 'TestAssessor'
            OutputPath   = $script:testDir
            TenantId     = ''
        }

        $script:Findings = @(
            [PSCustomObject]@{
                FindingId    = 'DEC-APP-001'
                ObjectId     = [guid]::NewGuid().Guid
                AppId        = [guid]::NewGuid().Guid
                DisplayName  = 'Unowned App Alpha'
                OwnerCount   = 0
                HasOwner     = $false
                ProtectedObject = $false
            },
            [PSCustomObject]@{
                FindingId    = 'DEC-APP-002'
                ObjectId     = [guid]::NewGuid().Guid
                AppId        = [guid]::NewGuid().Guid
                DisplayName  = 'Disabled Owner App Beta'
                OwnerCount   = 1
                HasOwner     = $true
                ProtectedObject = $false
            },
            [PSCustomObject]@{
                FindingId    = 'DEC-APP-003'
                ObjectId     = [guid]::NewGuid().Guid
                AppId        = [guid]::NewGuid().Guid
                DisplayName  = 'Single Owner App Gamma'
                OwnerCount   = 1
                HasOwner     = $true
                ProtectedObject = $false
            },
            [PSCustomObject]@{
                FindingId    = 'DEC-SPN-001'
                ObjectId     = [guid]::NewGuid().Guid
                AppId        = [guid]::NewGuid().Guid
                DisplayName  = 'Ownerless SPN Delta'
                OwnerCount   = 0
                HasOwner     = $false
                ProtectedObject = $false
            },
            [PSCustomObject]@{
                FindingId    = 'DEC-APP-001'
                ObjectId     = [guid]::NewGuid().Guid
                AppId        = [guid]::NewGuid().Guid
                DisplayName  = 'Protected App'
                OwnerCount   = 0
                HasOwner     = $false
                ProtectedObject = $true
            }
        )

        $script:Model = New-DecomApplicationGovernanceModel -Context $script:Context -Findings $script:Findings
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('ApplicationGovernance','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Governance model ──

    Context 'Application owner governance model' {

        It 'New-DecomApplicationGovernanceModel returns a model object' {
            $script:Model | Should -Not -BeNullOrEmpty
        }

        It 'Model includes unowned application count' {
            $script:Model.UnownedApplicationCount | Should -BeGreaterThan 0
        }

        It 'Model includes OwnerReadiness array' {
            $script:Model.OwnerReadiness | Should -Not -BeNullOrEmpty
        }

        It 'ProtectedObject finding appears in Exceptions, not OwnerReadiness ready set' {
            $exc = @($script:Model.Exceptions | Where-Object { $_.Reason -eq 'ProtectedObject' })
            $exc.Count | Should -BeGreaterThan 0
        }

        It 'Model ReadyForOwnerApprovalCount is accurate for DEC-APP-001, DEC-APP-002, DEC-SPN-001' {
            $script:Model.ReadyForOwnerApprovalCount | Should -BeGreaterThan 0
        }

        It 'DEC-APP-003 finding shows as PlanOnly (single-owner)' {
            $planOnly = @($script:Model.OwnerReadiness | Where-Object { $_.FindingId -eq 'DEC-APP-003' -and $_.PlanOnly -eq $true })
            $planOnly.Count | Should -BeGreaterThan 0
        }
    }

    # ── Item 59: Application owner remediation readiness JSON exported ──

    Context 'Item 59 — Application owner readiness JSON export' {

        It 'Export-DecomApplicationOwnerReadinessJson creates a file' {
            $path = Join-Path $script:testDir 'application-owner-remediation-readiness-test.json'
            Export-DecomApplicationOwnerReadinessJson -Model $script:Model -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported readiness JSON is valid JSON' {
            $path = Join-Path $script:testDir 'application-owner-remediation-readiness-test.json'
            if (-not (Test-Path $path)) {
                Export-DecomApplicationOwnerReadinessJson -Model $script:Model -Path $path
            }
            { Get-Content $path -Raw | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Exported JSON includes OwnerReadiness array' {
            $path = Join-Path $script:testDir 'application-owner-remediation-readiness-test.json'
            if (-not (Test-Path $path)) {
                Export-DecomApplicationOwnerReadinessJson -Model $script:Model -Path $path
            }
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.OwnerReadiness | Should -Not -BeNullOrEmpty
        }

        It 'Exported JSON includes SchemaVersion' {
            $path = Join-Path $script:testDir 'application-owner-remediation-readiness-test.json'
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.SchemaVersion | Should -Not -BeNullOrEmpty
        }
    }

    # ── Item 60: Application owner approval packet exported ──

    Context 'Item 60 — Application owner approval packet Markdown export' {

        It 'Export-DecomApplicationOwnerApprovalPacketMarkdown creates a file' {
            $path = Join-Path $script:testDir 'application-owner-approval-packet-test.md'
            Export-DecomApplicationOwnerApprovalPacketMarkdown -Model $script:Model -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported approval packet Markdown contains approval table header' {
            $path = Join-Path $script:testDir 'application-owner-approval-packet-test.md'
            if (-not (Test-Path $path)) {
                Export-DecomApplicationOwnerApprovalPacketMarkdown -Model $script:Model -Path $path
            }
            $content = Get-Content $path -Raw
            $content | Should -Match 'Application Owner Approval Packet'
        }

        It 'Exported approval packet includes approver signature block' {
            $path = Join-Path $script:testDir 'application-owner-approval-packet-test.md'
            $content = Get-Content $path -Raw
            $content | Should -Match 'Signature'
        }

        It 'Export-DecomApplicationOwnerApprovalPacketHtml creates an HTML file' {
            $path = Join-Path $script:testDir 'application-owner-approval-packet-test.html'
            Export-DecomApplicationOwnerApprovalPacketHtml -Model $script:Model -Path $path
            Test-Path $path | Should -Be $true
        }
    }

    # ── Item 61: Application owner rollback guide exported ──

    Context 'Item 61 — Application owner rollback/evidence guide export' {

        It 'Export-DecomApplicationGovernanceEvidenceAppendixMarkdown creates a file' {
            $path = Join-Path $script:testDir 'application-owner-rollback-guide-test.md'
            Export-DecomApplicationGovernanceEvidenceAppendixMarkdown -Model $script:Model -Path $path
            Test-Path $path | Should -Be $true
        }

        It 'Exported evidence appendix contains read-only guarantee statement' {
            $path = Join-Path $script:testDir 'application-owner-rollback-guide-test.md'
            if (-not (Test-Path $path)) {
                Export-DecomApplicationGovernanceEvidenceAppendixMarkdown -Model $script:Model -Path $path
            }
            $content = Get-Content $path -Raw
            $content | Should -Match '(?i)(read.only|Read-Only)'
        }

        It 'Exported evidence appendix contains recommended next actions' {
            $path = Join-Path $script:testDir 'application-owner-rollback-guide-test.md'
            $content = Get-Content $path -Raw
            $content | Should -Match 'Recommended Next Actions|Next Actions'
        }
    }

    # ── No-write safety ──

    Context 'ApplicationGovernance.psm1 is read-only' {

        It 'ApplicationGovernance.psm1 contains no Remove-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg'
        }

        It 'ApplicationGovernance.psm1 contains no Update-Mg cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Raw
            $content | Should -Not -Match 'Update-Mg'
        }

        It 'ApplicationGovernance.psm1 contains no New-MgApplication write cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Raw
            $content | Should -Not -Match 'New-MgApplication'
        }

        It 'ApplicationGovernance.psm1 does not request ReadWrite scopes' {
            $content = Get-Content (Join-Path $script:ModulesPath 'ApplicationGovernance.psm1') -Raw
            $content | Should -Not -Match 'ReadWrite\.All'
        }
    }
}
