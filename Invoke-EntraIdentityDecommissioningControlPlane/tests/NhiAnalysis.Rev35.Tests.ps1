#Requires -Version 5.1

Describe 'NhiAnalysis.Rev35 — NHI Classification and Scoring Engine' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','NhiAnalysis')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiAnalysis.psm1')  -Force -DisableNameChecking

        # Helper: minimal NHI object for tests
        function script:New-TestNhiObject {
            param(
                [string]$DisplayName   = 'test-app',
                [string]$ObjectType    = 'ServicePrincipal',
                [string]$SpType        = 'Application',
                [int]$OwnerCount       = 1,
                [int]$CredentialCount  = 0,
                [int]$HighRiskPermCount = 0,
                [bool]$TenantWide      = $false,
                [bool]$IsVerified      = $true,
                [string]$Publisher     = 'TestCorp'
            )
            [PSCustomObject]@{
                ObjectId                  = [guid]::NewGuid().Guid
                DisplayName               = $DisplayName
                ObjectType                = $ObjectType
                ServicePrincipalType      = $SpType
                OwnerCount                = $OwnerCount
                CredentialCount           = $CredentialCount
                ExpiredCredentialCount    = 0
                ExpiringCredentialCount   = 0
                HighRiskPermissionCount   = $HighRiskPermCount
                HighRiskOAuthGrantCount   = 0
                TenantWideConsent         = $TenantWide
                IsVerifiedPublisher       = $IsVerified
                PublisherName             = $Publisher
                FirstPartyMicrosoftApp    = ($Publisher -eq 'Microsoft Corporation')
                CoverageMode              = 'Full'
                CoverageLimitations       = @()
                RiskScoreMayBeUnderstated = $false
                NhiCandidate              = $true
                AgenticCandidate          = $false
                AutomationCandidate       = $false
                WorkloadCandidate         = $false
                RawOwners                 = @()
                VerifiedPublisherName     = $null
                EvidenceSource            = 'graph'
                EvidenceConfidence        = 'High'
            }
        }
    }

    AfterAll {
        foreach ($m in @('NhiAnalysis','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Module safety ──────────────────────────────────────────────────────────

    Context 'Module safety checks' {

        It 'NhiAnalysis.psm1 contains no write cmdlets' {
            $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
            $content | Should -Not -Match 'Remove-Mg|Update-Mg|Set-Mg|New-MgApplication'
        }

        It 'Exports Invoke-DecomNhiAnalysis' {
            Get-Command Invoke-DecomNhiAnalysis -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Get-DecomNhiClassificationScore' {
            Get-Command Get-DecomNhiClassificationScore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Get-DecomNhiSeverityFromRiskScore' {
            Get-Command Get-DecomNhiSeverityFromRiskScore -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }

        It 'Exports Get-DecomNhiRemediationMode' {
            Get-Command Get-DecomNhiRemediationMode -ErrorAction SilentlyContinue | Should -Not -BeNullOrEmpty
        }
    }

    # ── Classification scoring ─────────────────────────────────────────────────

    Context 'Get-DecomNhiClassificationScore — classification results' {

        It 'ServiceIdentity type scores >= 50 and classifies as NativeServiceIdentity' {
            $obj = script:New-TestNhiObject -SpType 'ServiceIdentity'
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            $result.ClassificationScore  | Should -BeGreaterOrEqual 50
            $result.Classification       | Should -Be 'NativeServiceIdentity'
        }

        It 'Agent naming pattern scores high and classifies as LikelyAIAgent' {
            $obj = script:New-TestNhiObject -DisplayName 'copilot-hr-agent'
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            $result.ClassificationScore  | Should -BeGreaterOrEqual 30
            $result.Classification       | Should -Be 'LikelyAIAgent'
        }

        It 'Automation naming pattern classifies correctly' {
            $obj = script:New-TestNhiObject -DisplayName 'workflow-runner-payments'
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            $result.ClassificationScore  | Should -BeGreaterOrEqual 15
            $result.Classification       | Should -BeIn @('LikelyAIAgent','LikelyAutomation')
        }

        It 'Unknown app with no signals classifies as UnclassifiedServicePrincipal' {
            $obj = script:New-TestNhiObject -DisplayName 'random-nonprod-app' -OwnerCount 2
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            $result.Classification | Should -Be 'UnclassifiedServicePrincipal'
        }

        It 'Application object with no signals classifies as UnclassifiedApplication' {
            $obj = script:New-TestNhiObject -DisplayName 'basic-app' -ObjectType 'Application' -OwnerCount 2
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            $result.Classification | Should -Be 'UnclassifiedApplication'
        }

        It 'High-risk permission increases score' {
            $noPerms = script:New-TestNhiObject -DisplayName 'test-noperms' -HighRiskPermCount 0
            $withPerms = script:New-TestNhiObject -DisplayName 'test-perms' -HighRiskPermCount 2
            $scoreNo   = (Get-DecomNhiClassificationScore -NhiObject $noPerms).ClassificationScore
            $scoreWith = (Get-DecomNhiClassificationScore -NhiObject $withPerms).ClassificationScore
            $scoreWith | Should -BeGreaterThan $scoreNo
        }

        It 'No-owner increases score' {
            $withOwner = script:New-TestNhiObject -OwnerCount 1
            $noOwner   = script:New-TestNhiObject -OwnerCount 0
            $scoreWith = (Get-DecomNhiClassificationScore -NhiObject $withOwner).ClassificationScore
            $scoreNo   = (Get-DecomNhiClassificationScore -NhiObject $noOwner).ClassificationScore
            $scoreNo   | Should -BeGreaterThan $scoreWith
        }

        It 'Tenant-wide consent increases score' {
            $noConsent   = script:New-TestNhiObject -TenantWide $false
            $withConsent = script:New-TestNhiObject -TenantWide $true
            $scoreNo   = (Get-DecomNhiClassificationScore -NhiObject $noConsent).ClassificationScore
            $scoreWith = (Get-DecomNhiClassificationScore -NhiObject $withConsent).ClassificationScore
            $scoreWith | Should -BeGreaterThan $scoreNo
        }

        It 'Returns ClassificationSignals as array' {
            $obj = script:New-TestNhiObject -DisplayName 'agent-service'
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            $result.ClassificationSignals.GetType().IsArray | Should -Be $true
        }

        It 'High confidence when ServiceIdentity' {
            $obj = script:New-TestNhiObject -SpType 'ServiceIdentity'
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            $result.ClassificationConfidence | Should -Be 'High'
        }
    }

    # ── Severity mapping ───────────────────────────────────────────────────────

    Context 'Get-DecomNhiSeverityFromRiskScore — severity thresholds' {

        It 'Score >= 85 maps to Critical' {
            Get-DecomNhiSeverityFromRiskScore -RiskScore 85  | Should -Be 'Critical'
            Get-DecomNhiSeverityFromRiskScore -RiskScore 100 | Should -Be 'Critical'
        }

        It 'Score 70-84 maps to High' {
            Get-DecomNhiSeverityFromRiskScore -RiskScore 70 | Should -Be 'High'
            Get-DecomNhiSeverityFromRiskScore -RiskScore 84 | Should -Be 'High'
        }

        It 'Score 44-69 maps to Medium' {
            Get-DecomNhiSeverityFromRiskScore -RiskScore 44 | Should -Be 'Medium'
            Get-DecomNhiSeverityFromRiskScore -RiskScore 69 | Should -Be 'Medium'
        }

        It 'Score 15-43 maps to Low' {
            Get-DecomNhiSeverityFromRiskScore -RiskScore 15 | Should -Be 'Low'
            Get-DecomNhiSeverityFromRiskScore -RiskScore 43 | Should -Be 'Low'
        }

        It 'Score < 15 maps to Informational' {
            Get-DecomNhiSeverityFromRiskScore -RiskScore 0  | Should -Be 'Informational'
            Get-DecomNhiSeverityFromRiskScore -RiskScore 14 | Should -Be 'Informational'
        }
    }

    # ── Remediation mode mapping ───────────────────────────────────────────────

    Context 'Get-DecomNhiRemediationMode — finding ID mapping' {

        It 'DEC-NHI-001 maps to InformationOnly' {
            Get-DecomNhiRemediationMode -FindingId 'DEC-NHI-001' -ExactTargetAvailable $false | Should -Be 'InformationOnly'
        }

        It 'DEC-NHI-002 with target maps to ManualApprovalRequired' {
            Get-DecomNhiRemediationMode -FindingId 'DEC-NHI-002' -ExactTargetAvailable $true | Should -Be 'ManualApprovalRequired'
        }

        It 'DEC-NHI-002 without target maps to InformationOnly' {
            Get-DecomNhiRemediationMode -FindingId 'DEC-NHI-002' -ExactTargetAvailable $false | Should -Be 'InformationOnly'
        }

        It 'DEC-AGENT-001 maps to InformationOnly' {
            Get-DecomNhiRemediationMode -FindingId 'DEC-AGENT-001' -ExactTargetAvailable $false | Should -Be 'InformationOnly'
        }

        It 'Unknown finding ID defaults to InformationOnly' {
            Get-DecomNhiRemediationMode -FindingId 'DEC-UNKNOWN-999' -ExactTargetAvailable $false | Should -Be 'InformationOnly'
        }
    }

    # ── Invoke-DecomNhiAnalysis pipeline ──────────────────────────────────────

    Context 'Invoke-DecomNhiAnalysis — full analysis pipeline' {

        BeforeAll {
            $script:AnalysisInput = @(
                (script:New-TestNhiObject -DisplayName 'copilot-agent' -SpType 'ServiceIdentity' -OwnerCount 0 -HighRiskPermCount 2),
                (script:New-TestNhiObject -DisplayName 'workflow-runner' -OwnerCount 1 -HighRiskPermCount 0),
                (script:New-TestNhiObject -DisplayName 'random-app' -OwnerCount 2 -HighRiskPermCount 0)
            )
            $script:AnalysisCtx = [PSCustomObject]@{ DemoMode = $false }
            $script:AnalysisResults = Invoke-DecomNhiAnalysis -NhiObjects $script:AnalysisInput -Context $script:AnalysisCtx
        }

        It 'Returns same count as input' {
            $script:AnalysisResults.Count | Should -Be $script:AnalysisInput.Count
        }

        It 'Each result has Classification property' {
            $script:AnalysisResults | ForEach-Object { $_.Classification | Should -Not -BeNullOrEmpty }
        }

        It 'Each result has ClassificationScore >= 0' {
            $script:AnalysisResults | ForEach-Object { $_.ClassificationScore | Should -BeGreaterOrEqual 0 }
        }

        It 'Each result has Severity in valid set' {
            $script:AnalysisResults | ForEach-Object {
                $_.Severity | Should -BeIn @('Critical','High','Medium','Low','Informational')
            }
        }

        It 'ServiceIdentity input classifies as NativeServiceIdentity' {
            $native = $script:AnalysisResults | Where-Object { $_.DisplayName -eq 'copilot-agent' }
            $native.Classification | Should -Be 'NativeServiceIdentity'
        }

        It 'Each result has NhiCandidate set to true for ServicePrincipal objects' {
            $spResults = $script:AnalysisResults | Where-Object { $_.ObjectType -eq 'ServicePrincipal' }
            $spResults | ForEach-Object { $_.NhiCandidate | Should -Be $true }
        }
    }

    # ── Microsoft first-party exclusion ───────────────────────────────────────

    Context 'Microsoft first-party SPN exclusion' {

        It 'Microsoft first-party SPN does not generate DEC-NHI findings' {
            $msftSp = script:New-TestNhiObject -DisplayName 'Microsoft Graph' -Publisher 'Microsoft Corporation'
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($msftSp) -Context $ctx
            $results | Should -BeNullOrEmpty
        }

        It 'Microsoft first-party SPN does not generate DEC-AGENT findings' {
            $msftAgent = script:New-TestNhiObject -DisplayName 'Azure AI Foundry' -Publisher 'Microsoft Corporation'
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($msftAgent) -Context $ctx
            $results | Should -BeNullOrEmpty
        }

        It 'Non-Microsoft SPN generates NHI findings when criteria met' {
            $thirdPartySp = script:New-TestNhiObject -DisplayName 'copilot-hr-agent' -Publisher 'Contoso Corp'
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($thirdPartySp) -Context $ctx
            $results | Should -Not -BeNullOrEmpty
        }
    }
}
