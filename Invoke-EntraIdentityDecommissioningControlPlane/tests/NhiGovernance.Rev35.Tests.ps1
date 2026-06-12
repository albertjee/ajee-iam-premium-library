#Requires -Version 5.1

Describe 'NhiGovernance.Rev35 — NHI Governance Finding Generation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','NhiAnalysis','NhiGovernance')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')     -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiAnalysis.psm1')   -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Force -DisableNameChecking

        $script:GovCtx = [PSCustomObject]@{ DemoMode = $false; OutputPath = $env:TEMP }

        function script:New-AnalyzedNhiObject {
            param(
                [string]$DisplayName          = 'test-app',
                [string]$ObjectType           = 'ServicePrincipal',
                [string]$SpType               = 'Application',
                [string]$Classification       = 'LikelyAIAgent',
                [string]$ClassificationConf   = 'High',
                [int]$OwnerCount              = 0,
                [int]$HighRiskPermCount       = 0,
                [bool]$TenantWide             = $false,
                [bool]$IsVerified             = $false,
                [bool]$IsAgentic              = $true,
                [object[]]$RawOwners          = @()
            )
            [PSCustomObject]@{
                ObjectId                  = [guid]::NewGuid().Guid
                DisplayName               = $DisplayName
                ObjectType                = $ObjectType
                ServicePrincipalType      = $SpType
                Classification            = $Classification
                ClassificationConfidence  = $ClassificationConf
                ClassificationSignals     = @('test-signal')
                ClassificationScore       = 50
                NhiCandidate              = $true
                AgenticCandidate          = $IsAgentic
                AutomationCandidate       = $false
                WorkloadCandidate         = $false
                OwnerCount                = $OwnerCount
                CredentialCount           = 0
                ExpiredCredentialCount    = 0
                ExpiringCredentialCount   = 0
                HighRiskPermissionCount   = $HighRiskPermCount
                HighRiskOAuthGrantCount   = 0
                TenantWideConsent         = $TenantWide
                IsVerifiedPublisher       = $IsVerified
                VerifiedPublisherName     = $null
                PublisherName             = 'TestCorp'
                FirstPartyMicrosoftApp    = $false
                MicrosoftFirstParty       = $false
                MicrosoftPlatform         = $false
                MicrosoftPlatformReason    = ''
                CoverageMode              = 'Full'
                CoverageLimitations       = @()
                RiskScoreMayBeUnderstated = $false
                RiskScore                 = 65
                Severity                  = 'High'
                RawOwners                 = $RawOwners
            }
        }
    }

    AfterAll {
        foreach ($m in @('NhiGovernance','NhiAnalysis','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Module safety ──────────────────────────────────────────────────────────

    Context 'Module safety checks' {

        It 'NhiGovernance.psm1 contains no write cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication'
        }

        It 'NhiGovernance.psm1 does not request write scopes' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiGovernance.psm1') -Raw
            $content | Should -Not -Match 'Application\.ReadWrite|GroupMember\.ReadWrite'
        }

        It 'Exports Invoke-DecomNhiGovernance' {
            Get-Command Invoke-DecomNhiGovernance -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    # ── DEC-NHI-001: NHI candidate inventory ──────────────────────────────────

    Context 'DEC-NHI-001 — Entra-visible NHI candidate detected' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -DisplayName 'agent-svc' -OwnerCount 1 -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:F001 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-001' }
        }

        It 'DEC-NHI-001 is generated for every NHI candidate' {
            $script:F001 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-001 RemediationMode is InformationOnly' {
            $script:F001.RemediationMode | Should -Be 'InformationOnly'
        }

        It 'DEC-NHI-001 carries Classification field' {
            $script:F001.Classification | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-001 carries ClassificationScore' {
            $script:F001.ClassificationScore | Should -BeGreaterOrEqual 0
        }
    }

    Context 'Microsoft platform evidence-only suppression' {
        It 'Microsoft platform identities generate only evidence-only inventory findings' {
            $obj = script:New-AnalyzedNhiObject -DisplayName 'Microsoft Graph' -Classification 'MicrosoftPlatform' -IsAgentic $false
            $obj.MicrosoftPlatform = $true
            $obj.MicrosoftFirstParty = $true
            $obj.MicrosoftPlatformReason = 'MicrosoftOwnerTenant'
            $obj.FirstPartyMicrosoftApp = $true
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx

            $findings.Count | Should -Be 1
            $findings[0].FindingId | Should -Be 'DEC-NHI-001'
            $findings[0].Classification | Should -Be 'MicrosoftPlatform'
            $findings[0].RemediationMode | Should -Be 'InformationOnly'
            $findings[0].EvidenceOnly | Should -Be $true
            $findings[0].MicrosoftPlatform | Should -Be $true
            $findings[0].FirstPartyMicrosoftApp | Should -Be $true
            $findings[0].RecommendedAction | Should -Match '^Evidence only'
            $findings[0].ClassificationSource | Should -Not -BeNullOrEmpty
            $findings[0].NormalizedAppId | Should -BeNullOrEmpty
        }

        It 'Microsoft platform identities do not generate owner or agent remediation findings' {
            $obj = script:New-AnalyzedNhiObject -DisplayName 'Microsoft Graph' -Classification 'MicrosoftPlatform' -IsAgentic $false
            $obj.MicrosoftPlatform = $true
            $obj.MicrosoftFirstParty = $true
            $obj.MicrosoftPlatformReason = 'MicrosoftOwnerTenant'
            $obj.FirstPartyMicrosoftApp = $true
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx

            ($findings | Where-Object { $_.FindingId -in @('DEC-NHI-002','DEC-NHI-003','DEC-NHI-004','DEC-NHI-007','DEC-NHI-009','DEC-NHI-010','DEC-NHI-012','DEC-AGENT-001','DEC-AGENT-003','DEC-AGENT-004','DEC-AGENT-005') }).Count | Should -Be 0
            ($findings | Where-Object { $_.RecommendedAction -match 'Assign accountable owner|AddApplicationOwner|Revoke consent|Verify publisher|Reduce permission scope' }).Count | Should -Be 0
        }
    }

    # ── DEC-NHI-002: No owner ──────────────────────────────────────────────────

    Context 'DEC-NHI-002 — NHI has no owner' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -OwnerCount 0 -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:F002 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-002' }
        }

        It 'DEC-NHI-002 is generated when OwnerCount = 0' {
            $script:F002 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-002 Severity is High' {
            $script:F002.Severity | Should -Be 'High'
        }

        It 'DEC-NHI-002 RiskScore is 62' {
            $script:F002.RiskScore | Should -Be 62
        }

        It 'DEC-NHI-002 not generated when OwnerCount > 0' {
            $obj = script:New-AnalyzedNhiObject -OwnerCount 2 -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $f = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-002' }
            $f | Should -BeNullOrEmpty
        }
    }

    # ── DEC-NHI-003: Single owner ──────────────────────────────────────────────

    Context 'DEC-NHI-003 — NHI has only one owner' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -OwnerCount 1 -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:F003 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-003' }
        }

        It 'DEC-NHI-003 is generated when OwnerCount = 1' {
            $script:F003 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-003 Severity is Medium' {
            $script:F003.Severity | Should -Be 'Medium'
        }

        It 'DEC-NHI-003 not generated when OwnerCount = 0' {
            $obj = script:New-AnalyzedNhiObject -OwnerCount 0 -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $f = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-003' }
            $f | Should -BeNullOrEmpty
        }
    }

    # ── DEC-NHI-004: Disabled owner ───────────────────────────────────────────

    Context 'DEC-NHI-004 — NHI owned by disabled identity' {

        BeforeAll {
            $disabledOwner = [PSCustomObject]@{ AccountEnabled = $false; Id = 'disabled-user-id' }
            $obj = script:New-AnalyzedNhiObject -OwnerCount 1 -IsAgentic $false -RawOwners @($disabledOwner)
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:F004 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-004' }
        }

        It 'DEC-NHI-004 is generated when owner is disabled' {
            $script:F004 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-004 Severity is High' {
            $script:F004.Severity | Should -Be 'High'
        }
    }

    # ── DEC-NHI-007: High-risk permissions ────────────────────────────────────

    Context 'DEC-NHI-007 — NHI has high-risk Graph permission' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -HighRiskPermCount 2 -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:F007 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-007' }
        }

        It 'DEC-NHI-007 is generated when HighRiskPermissionCount > 0' {
            $script:F007 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-007 Severity is High' {
            $script:F007.Severity | Should -Be 'High'
        }

        It 'DEC-NHI-007 not generated when no high-risk permissions' {
            $obj = script:New-AnalyzedNhiObject -HighRiskPermCount 0 -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $f = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-007' }
            $f | Should -BeNullOrEmpty
        }
    }

    # ── DEC-NHI-009: Tenant-wide consent ──────────────────────────────────────

    Context 'DEC-NHI-009 — NHI has tenant-wide consent' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -TenantWide $true -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:F009 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-009' }
        }

        It 'DEC-NHI-009 is generated when TenantWideConsent is true' {
            $script:F009 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-009 Severity is Critical' {
            $script:F009.Severity | Should -Be 'Critical'
        }
    }

    # ── DEC-NHI-010: Publisher verification gap ────────────────────────────────

    Context 'DEC-NHI-010 — publisher verification gap' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -IsVerified $false -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:F010 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-010' }
        }

        It 'DEC-NHI-010 is generated when not verified' {
            $script:F010 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-010 Severity is Medium' {
            $script:F010.Severity | Should -Be 'Medium'
        }
    }

    # ── DEC-NHI-012: High-risk perms + no owner ────────────────────────────────

    Context 'DEC-NHI-012 — high-risk app-roles with no owner accountability' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -OwnerCount 0 -HighRiskPermCount 1 -IsAgentic $false
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:F012 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-012' }
        }

        It 'DEC-NHI-012 is generated when HighRiskPermCount > 0 and OwnerCount = 0' {
            $script:F012 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-NHI-012 RemediationMode is ManualApprovalRequired' {
            $script:F012.RemediationMode | Should -Be 'ManualApprovalRequired'
        }
    }

    # ── DEC-AGENT findings ─────────────────────────────────────────────────────

    Context 'DEC-AGENT-001 — native agent/service identity' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -SpType 'ServiceIdentity' -Classification 'NativeServiceIdentity' -IsAgentic $true
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:FA001 = $findings | Where-Object { $_.FindingId -eq 'DEC-AGENT-001' }
        }

        It 'DEC-AGENT-001 is generated for ServiceIdentity agentic candidate' {
            $script:FA001 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-AGENT-001 RemediationMode is InformationOnly' {
            $script:FA001.RemediationMode | Should -Be 'InformationOnly'
        }
    }

    Context 'DEC-AGENT-003 — agent-like identity has no owner' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -OwnerCount 0 -IsAgentic $true
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:FA003 = $findings | Where-Object { $_.FindingId -eq 'DEC-AGENT-003' }
        }

        It 'DEC-AGENT-003 is generated for agentic candidate with no owner' {
            $script:FA003 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-AGENT-003 Severity is High' {
            $script:FA003.Severity | Should -Be 'High'
        }
    }

    Context 'DEC-AGENT-004 — agent-like identity has high-risk permission' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -HighRiskPermCount 1 -IsAgentic $true
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:FA004 = $findings | Where-Object { $_.FindingId -eq 'DEC-AGENT-004' }
        }

        It 'DEC-AGENT-004 is generated for agentic candidate with high-risk perm' {
            $script:FA004 | Should -Not -BeNullOrEmpty
        }
    }

    Context 'DEC-AGENT-005 — agent-like identity has tenant-wide consent' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -TenantWide $true -IsAgentic $true
            $findings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
            $script:FA005 = $findings | Where-Object { $_.FindingId -eq 'DEC-AGENT-005' }
        }

        It 'DEC-AGENT-005 is generated for agentic candidate with tenant-wide consent' {
            $script:FA005 | Should -Not -BeNullOrEmpty
        }

        It 'DEC-AGENT-005 Severity is Critical' {
            $script:FA005.Severity | Should -Be 'Critical'
        }
    }

    # ── Finding field completeness ─────────────────────────────────────────────

    Context 'All findings carry NHI-specific fields' {

        BeforeAll {
            $obj = script:New-AnalyzedNhiObject -OwnerCount 0 -HighRiskPermCount 1 -IsAgentic $true -TenantWide $true
            $script:AllFindings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovCtx
        }

        It 'All findings have non-empty FindingId' {
            $script:AllFindings | ForEach-Object { $_.FindingId | Should -Not -BeNullOrEmpty }
        }

        It 'All findings have valid Severity' {
            $script:AllFindings | ForEach-Object {
                $_.Severity | Should -BeIn @('Critical','High','Medium','Low','Informational')
            }
        }

        It 'All findings have RiskScore >= 0' {
            $script:AllFindings | ForEach-Object { $_.RiskScore | Should -BeGreaterOrEqual 0 }
        }

        It 'All findings have ObjectId populated' {
            $script:AllFindings | ForEach-Object { $_.ObjectId | Should -Not -BeNullOrEmpty }
        }

        It 'All findings have Classification populated' {
            $script:AllFindings | ForEach-Object { $_.Classification | Should -Not -BeNullOrEmpty }
        }

        It 'Finding IDs in DEC-NHI-* or DEC-AGENT-* namespace' {
            $script:AllFindings | ForEach-Object {
                $_.FindingId | Should -Match '^DEC-(NHI|AGENT)-\d{3}$'
            }
        }
    }
}
