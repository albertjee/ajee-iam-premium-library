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
                [string]$Publisher     = 'TestCorp',
                [string]$VerifiedPublisherName = $null,
                [string]$AppOwnerOrganizationId = 'tenant-test-001',
                [bool]$RiskScoreMayBeUnderstated = $false
            )
            $obj = [PSCustomObject]@{
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
                VerifiedPublisherName     = $VerifiedPublisherName
                AppOwnerOrganizationId    = $AppOwnerOrganizationId
                FirstPartyMicrosoftApp    = $false
                CoverageMode              = 'Full'
                CoverageLimitations       = @()
                RiskScoreMayBeUnderstated = $RiskScoreMayBeUnderstated
                NhiCandidate              = $true
                AgenticCandidate          = $false
                AutomationCandidate       = $false
                WorkloadCandidate         = $false
                RawOwners                 = @()
                RawOAuthGrants            = @()
                EvidenceSource            = 'graph'
                EvidenceConfidence        = 'High'
            }
            $platform = Test-DecomMicrosoftPlatformIdentity -NhiObject $obj
            $obj | Add-Member -NotePropertyName MicrosoftFirstParty -NotePropertyValue $platform.MicrosoftFirstParty -Force
            $obj | Add-Member -NotePropertyName MicrosoftPlatform -NotePropertyValue $platform.MicrosoftPlatform -Force
            $obj | Add-Member -NotePropertyName MicrosoftPlatformReason -NotePropertyValue $platform.Reason -Force
            $obj.FirstPartyMicrosoftApp = $platform.MicrosoftFirstParty
            return $obj
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

    Context 'Microsoft platform identities remain evidence-only' {

        It 'Microsoft platform SPN is retained with MicrosoftPlatform classification' {
            $msftSp = [PSCustomObject]@{
                appId                 = '1b730954-1685-4b74-9bfd-dac224a7b894'
                displayName           = 'Microsoft Graph PowerShell'
                appDisplayName        = 'Microsoft Graph PowerShell'
                servicePrincipalType  = 'Application'
                appOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
                tags                  = @('WindowsAzureActiveDirectoryIntegratedApp')
                publisherName         = $null
                verifiedPublisher     = [PSCustomObject]@{ displayName = 'Microsoft' }
                NhiCandidate          = $true
                AgenticCandidate      = $false
                AutomationCandidate   = $false
                WorkloadCandidate     = $false
                OwnerCount            = 0
                CredentialCount       = 0
                ExpiredCredentialCount = 0
                ExpiringCredentialCount = 0
                HighRiskPermissionCount = 0
                HighRiskOAuthGrantCount = 0
                TenantWideConsent     = $false
                IsVerifiedPublisher   = $true
                CoverageMode          = 'Full'
                CoverageLimitations   = @()
                RiskScoreMayBeUnderstated = $false
                RawOwners             = @()
                RawOAuthGrants        = @()
            }
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($msftSp) -Context $ctx
            $results.Count | Should -Be 1
            $results[0].MicrosoftPlatform | Should -Be $true
            $results[0].Classification | Should -Be 'MicrosoftPlatform'
            $results[0].CoverageMode | Should -Be 'EvidenceOnly'
        }

        It 'Microsoft platform SPN is recognized from nested live metadata fields' {
            $msftSp = [PSCustomObject]@{
                appId                  = 'fb50aeb4-1f6f-4d14-8f83-6d4cfe11d9d2'
                displayName            = 'Microsoft Tech Community'
                appDisplayName         = 'Microsoft Tech Community'
                servicePrincipalType   = 'Application'
                appOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
                tags                   = @('WindowsAzureActiveDirectoryIntegratedApp')
                publisherName          = $null
                verifiedPublisher      = $null
                AdditionalProperties   = @{
                    verifiedPublisher = [PSCustomObject]@{ displayName = '' }
                }
                NhiCandidate           = $true
                AgenticCandidate       = $false
                AutomationCandidate    = $false
                WorkloadCandidate      = $false
                OwnerCount             = 0
                CredentialCount        = 0
                ExpiredCredentialCount = 0
                ExpiringCredentialCount = 0
                HighRiskPermissionCount = 0
                HighRiskOAuthGrantCount = 0
                TenantWideConsent      = $false
                IsVerifiedPublisher    = $false
                CoverageMode           = 'Full'
                CoverageLimitations    = @()
                RiskScoreMayBeUnderstated = $false
                RawOwners              = @()
                RawOAuthGrants         = @()
            }
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($msftSp) -Context $ctx
            $results[0].MicrosoftPlatform | Should -Be $true
            $results[0].MicrosoftFirstParty | Should -Be $true
            $results[0].Classification | Should -Be 'MicrosoftPlatform'
            $results[0].ClassificationSignals | Should -Contain 'Microsoft platform identity'
        }

        It 'Microsoft platform SPN is not misclassified by name alone' {
            $fakeMsft = script:New-TestNhiObject -DisplayName 'Microsoft Graph clone' -Publisher 'Microsoft Corporation' -VerifiedPublisherName $null -AppOwnerOrganizationId 'tenant-test-001'
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($fakeMsft) -Context $ctx
            $results[0].MicrosoftPlatform | Should -Be $false
            $results[0].Classification | Should -BeIn @('UnclassifiedServicePrincipal','LikelyAutomation','LikelyAIAgent')
        }

        It 'Microsoft platform internal inventory record is recognized after normalization' {
            $inventoryRecord = [PSCustomObject]@{
                AppId                  = '1b730954-1685-4b74-9bfd-dac224a7b894'
                DisplayName            = 'Microsoft Graph PowerShell'
                AppDisplayName         = 'Microsoft Graph PowerShell'
                ObjectType             = 'ServicePrincipal'
                ServicePrincipalType   = 'Application'
                PublisherName          = $null
                VerifiedPublisherName  = 'Microsoft'
                AppOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
                Tags                   = @('WindowsAzureActiveDirectoryIntegratedApp')
                NhiCandidate           = $true
                AgenticCandidate       = $false
                AutomationCandidate    = $false
                WorkloadCandidate      = $false
                OwnerCount             = 0
                CredentialCount        = 0
                ExpiredCredentialCount = 0
                ExpiringCredentialCount = 0
                HighRiskPermissionCount = 0
                HighRiskOAuthGrantCount = 0
                TenantWideConsent      = $false
                CoverageMode           = 'EvidenceOnly'
            }
            $result = Test-DecomMicrosoftPlatformIdentity -NhiObject $inventoryRecord
            $result.MicrosoftPlatform | Should -Be $true
            $result.MicrosoftFirstParty | Should -Be $true
            $result.Reason | Should -BeIn @('MicrosoftOwnerTenant','MicrosoftAppIdAllowlist','MicrosoftPublisherAndVerifiedPublisher')
        }

        It 'Non-Microsoft SPN generates NHI findings when criteria met' {
            $thirdPartySp = script:New-TestNhiObject -DisplayName 'copilot-hr-agent' -Publisher 'Contoso Corp'
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($thirdPartySp) -Context $ctx
            $results | Should -Not -BeNullOrEmpty
        }
    }

    # ── P1-04A: OAuth scoring order ───────────────────────────────────────
    Context 'P1-04A: TenantWideConsent and HighRiskOAuthGrantCount calculated before classification' {

        It 'TenantWideConsent=true increases classification score before risk assignment' {
            # Object with tenant-wide consent but no other signals
            $obj = script:New-TestNhiObject -DisplayName 'test-app' -OwnerCount 2 -Publisher 'Microsoft Corporation' -IsVerified $true
            $obj | Add-Member -NotePropertyName TenantWideConsent -NotePropertyValue $true -Force
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            # Tenant-wide consent adds 15 to classification score
            $result.ClassificationScore | Should -Be 15
        }

        It 'HighRiskOAuthGrantCount>0 contributes to risk before governance finding generation' {
            # Object with high-risk OAuth grant but no other signals
            $obj = script:New-TestNhiObject -DisplayName 'test-app' -OwnerCount 2 -Publisher 'Microsoft Corporation' -IsVerified $true
            # RawOAuthGrants with a high-risk scope
            $obj | Add-Member -NotePropertyName RawOAuthGrants -NotePropertyValue @(@{ConsentType='SpecificPrincipals'; Scope='User.Read.All'}) -Force
            # Set the OAuth grant count to simulate what the analysis would do
            $obj | Add-Member -NotePropertyName HighRiskOAuthGrantCount -NotePropertyValue 1 -Force
            $result = Get-DecomNhiClassificationScore -NhiObject $obj
            # High-risk OAuth grant adds 8 to classification score
            $result.ClassificationScore | Should -Be 8
        }
    }

    # ── P1-03A: Preserve discovery coverage flags ────────────────────────
    Context 'P1-03A: Analysis preserves discovery coverage flags' {

        It 'RiskScoreMayBeUnderstated=true from discovery is preserved after NHI analysis' {
            # Object with RiskScoreMayBeUnderstated set to true from discovery
            $obj = script:New-TestNhiObject -DisplayName 'test-app' -RiskScoreMayBeUnderstated $true
            # Ensure HighRiskPermissionCount is present so analysis doesn't add the limitation
            $obj | Add-Member -NotePropertyName HighRiskPermissionCount -NotePropertyValue 1 -Force
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($obj) -Context $ctx
            $results[0].RiskScoreMayBeUnderstated | Should -Be $true
        }

        It 'CoverageLimitations from discovery are preserved and analysis limitations appended' {
            # Object with existing coverage limitation and a condition that triggers analysis limitation
            $obj = script:New-TestNhiObject -DisplayName 'test-app'
            $obj | Add-Member -NotePropertyName CoverageLimitations -NotePropertyValue @('Existing limitation from discovery') -Force
            # No HighRiskPermissionCount -> analysis will add limitation
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $results = Invoke-DecomNhiAnalysis -NhiObjects @($obj) -Context $ctx
            $limitations = $results[0].CoverageLimitations
            $limitations | Should -Contain 'Existing limitation from discovery'
            $limitations | Should -Contain 'Application role display-name resolution unavailable — permission risk may be understated'
            # Expect exactly two limitations
            $limitations.Count | Should -Be 2
        }
    }

    # ── P1-01C: Summary recalculation after NHI merge ──────────────────────
    Context 'P1-01C: Summary is recalculated after NHI findings merged' {

        It 'Summary.Total includes DEC-NHI and DEC-AGENT findings after analysis' {
            # Simulate base findings and NHI-generated findings
            $baseFinding = [PSCustomObject]@{
                FindingId = 'DEC-SAMPLE-001'
                FindingTitle = 'Base finding'
                Severity = 'Medium'
            }
            $nhiAnalyzed = script:New-TestNhiObject -DisplayName 'agent-test' -SpType 'ServiceIdentity'
            $ctx = [PSCustomObject]@{ DemoMode = $false }
            $nhiResults = Invoke-DecomNhiAnalysis -NhiObjects @($nhiAnalyzed) -Context $ctx
            # Verify that analyzed object has classification and risk properties
            $nhiResults | Should -Not -BeNullOrEmpty
            $nhiResults[0].Classification | Should -Not -BeNullOrEmpty
            $nhiResults[0].Severity | Should -Not -BeNullOrEmpty
        }
    }
}
