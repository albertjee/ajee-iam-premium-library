# NhiGovernanceDataDriven.Rev42.Tests.ps1
# Rev4.2 - NhiGovernance.psm1 data-driven refactor (refactoring-plan target I-b).
# Locks the definitions table (IDs, order, metadata) and the refactor invariants:
# single exported function, no repeated inline New-DecomFinding blocks, behavioral
# parity for a max-trigger fixture and the Microsoft platform evidence-only override.

BeforeAll {
    $script:ToolRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulesPath = Join-Path $script:ToolRoot 'src\Modules'
    $script:GovPath = Join-Path $script:ModulesPath 'NhiGovernance.psm1'

    Remove-Module Utilities, NhiGovernance -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
    Import-Module $script:GovPath -Force -DisableNameChecking

    function script:New-GovTestNhiObject {
        param([hashtable]$Overrides = @{})
        $base = @{
            ObjectId                 = 'sp-gov-001'
            ObjectType               = 'ServicePrincipal'
            AppId                    = 'app-gov-001'
            DisplayName              = 'gov-test-sp'
            ServicePrincipalType     = 'Application'
            NhiCandidate             = $true
            AgenticCandidate         = $false
            AutomationCandidate      = $false
            WorkloadCandidate        = $false
            Classification           = 'LikelyAutomation'
            ClassificationConfidence = 'Medium'
            ClassificationSignals    = @('Automation Naming Pattern')
            ClassificationScore      = 25
            Severity                 = 'Low'
            RiskScore                = 25
            MicrosoftPlatform        = $false
            MicrosoftFirstParty      = $false
            MicrosoftPlatformReason  = $null
            FirstPartyMicrosoftApp   = $false
            IsVerifiedPublisher      = $true
            VerifiedPublisherName    = 'Contoso Ltd'
            PublisherName            = 'Contoso Ltd'
            OwnerCount               = 2
            RawOwners                = @()
            CredentialCount          = 0
            ExpiredCredentialCount   = 0
            ExpiringCredentialCount  = 0
            HighRiskPermissionCount  = 0
            HighRiskOAuthGrantCount  = 0
            TenantWideConsent        = $false
            CoverageMode             = 'Full'
            RiskScoreMayBeUnderstated = $false
        }
        foreach ($k in $Overrides.Keys) { $base[$k] = $Overrides[$k] }
        [PSCustomObject]$base
    }
    $script:GovContext = [PSCustomObject]@{ DemoMode = $false }
}

Describe 'NhiGovernance data-driven refactor invariants (Rev4.2)' {

    It 'parses with zero errors' {
        $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($script:GovPath, [ref]$null, [ref]$errors)
        $errors.Count | Should -Be 0
    }

    It 'exports exactly one function: Invoke-DecomNhiGovernance (helper stays private)' {
        $mod = Get-Module NhiGovernance
        @($mod.ExportedFunctions.Keys) | Should -Be @('Invoke-DecomNhiGovernance')
    }

    It 'contains exactly two New-DecomFinding call sites (platform override + helper), not 13 inline blocks' {
        $content = Get-Content $script:GovPath -Raw
        # Count invocations only (splat or backtick continuation), not comment mentions
        ([regex]::Matches($content, 'New-DecomFinding\s+[@`]')).Count | Should -Be 2
    }

    It 'defines the 12 finding definitions in pre-refactor emission order' {
        $defs = & (Get-Module NhiGovernance) { $script:NhiGovernanceFindingDefinitions }
        @($defs).Count | Should -Be 12
        @($defs.FindingId) | Should -Be @(
            'DEC-NHI-001', 'DEC-NHI-002', 'DEC-NHI-003', 'DEC-NHI-004',
            'DEC-NHI-007', 'DEC-NHI-009', 'DEC-NHI-010', 'DEC-NHI-012',
            'DEC-AGENT-001', 'DEC-AGENT-003', 'DEC-AGENT-004', 'DEC-AGENT-005'
        )
    }

    It 'preserves pre-refactor severity/risk-score metadata for all literal definitions' {
        $defs = & (Get-Module NhiGovernance) { $script:NhiGovernanceFindingDefinitions }
        $expected = @{
            'DEC-NHI-002'   = @('High', 62);        'DEC-NHI-003'   = @('Medium', 44)
            'DEC-NHI-004'   = @('High', 68);        'DEC-NHI-007'   = @('High', 72)
            'DEC-NHI-009'   = @('Critical', 85);    'DEC-NHI-010'   = @('Medium', 45)
            'DEC-NHI-012'   = @('High', 70);        'DEC-AGENT-001' = @('Informational', 20)
            'DEC-AGENT-003' = @('High', 68);        'DEC-AGENT-004' = @('High', 76)
            'DEC-AGENT-005' = @('Critical', 88)
        }
        foreach ($def in $defs | Where-Object { $_.FindingId -ne 'DEC-NHI-001' }) {
            $def.Severity | Should -Be $expected[$def.FindingId][0] -Because $def.FindingId
            $def.RiskScore | Should -Be $expected[$def.FindingId][1] -Because $def.FindingId
        }
    }
}

Describe 'NhiGovernance behavioral parity (Rev4.2)' {

    It 'quiet healthy object produces only DEC-NHI-001' {
        $obj = script:New-GovTestNhiObject
        $findings = @(Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovContext)
        @($findings.FindingId) | Should -Be @('DEC-NHI-001')
    }

    It 'max-trigger agentic fixture emits all applicable findings in pre-refactor order' {
        $obj = script:New-GovTestNhiObject -Overrides @{
            OwnerCount              = 0
            RawOwners               = @([PSCustomObject]@{ AccountEnabled = $false })
            HighRiskPermissionCount = 2
            TenantWideConsent       = $true
            IsVerifiedPublisher     = $false
            AgenticCandidate        = $true
            ServicePrincipalType    = 'ServiceIdentity'
        }
        $findings = @(Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovContext)
        @($findings.FindingId) | Should -Be @(
            'DEC-NHI-001', 'DEC-NHI-002', 'DEC-NHI-004', 'DEC-NHI-007',
            'DEC-NHI-009', 'DEC-NHI-010', 'DEC-NHI-012',
            'DEC-AGENT-001', 'DEC-AGENT-003', 'DEC-AGENT-004', 'DEC-AGENT-005'
        )
    }

    It 'DEC-NHI-004 evidence carries the computed disabled-owner count' {
        $obj = script:New-GovTestNhiObject -Overrides @{
            RawOwners = @(
                [PSCustomObject]@{ AccountEnabled = $false },
                [PSCustomObject]@{ AccountEnabled = $false },
                [PSCustomObject]@{ AccountEnabled = $true }
            )
        }
        $findings = @(Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovContext)
        $f4 = $findings | Where-Object { $_.FindingId -eq 'DEC-NHI-004' }
        $f4 | Should -Not -BeNullOrEmpty
        @($f4)[0].Evidence | Should -Be 'NHI is owned by 2 disabled identity(ies)'
    }

    It 'DEC-NHI-001 inherits object-derived severity, risk score, and confidence' {
        $obj = script:New-GovTestNhiObject -Overrides @{ Severity = 'High'; RiskScore = 71; ClassificationConfidence = 'High' }
        $findings = @(Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovContext)
        $f1 = @($findings | Where-Object { $_.FindingId -eq 'DEC-NHI-001' })[0]
        $f1.Severity | Should -Be 'High'
        $f1.RiskScore | Should -Be 71
        $f1.Confidence | Should -Be 'High'
    }

    It 'Microsoft platform object gets only the evidence-only DEC-NHI-001 override' {
        $obj = script:New-GovTestNhiObject -Overrides @{
            MicrosoftPlatform       = $true
            MicrosoftFirstParty     = $true
            MicrosoftPlatformReason = 'first-party publisher'
            OwnerCount              = 0
            HighRiskPermissionCount = 5
            TenantWideConsent       = $true
        }
        $findings = @(Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovContext)
        @($findings).Count | Should -Be 1
        $findings[0].FindingId | Should -Be 'DEC-NHI-001'
        $findings[0].Severity | Should -Be 'Informational'
        $findings[0].RiskScore | Should -Be 0
        $findings[0].Evidence | Should -Match 'evidence-only based on first-party publisher'
    }

    It 'non-NHI-candidate objects are skipped entirely' {
        $obj = script:New-GovTestNhiObject -Overrides @{ NhiCandidate = $false; OwnerCount = 0; TenantWideConsent = $true }
        $findings = @(Invoke-DecomNhiGovernance -AnalyzedNhiObjects @($obj) -Context $script:GovContext)
        @($findings).Count | Should -Be 0
    }
}
