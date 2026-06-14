BeforeAll {
    $moduleRoot = Split-Path $PSScriptRoot -Parent
    Import-Module (Join-Path $moduleRoot 'src/Modules/Utilities.psm1') -Force
    Import-Module (Join-Path $moduleRoot 'src/Modules/ApprovalManifest.psm1') -Force

    function Invoke-DecomCommandWithDefaults {
        param(
            [Parameter(Mandatory)]
            [string]$CommandName,
            [Parameter(Mandatory)]
            [hashtable]$PreferredArguments,
            [object]$PipelineInput
        )

        $command = Get-Command $CommandName -ErrorAction Stop
        $splat = @{}

        foreach ($entry in $PreferredArguments.GetEnumerator()) {
            if ($command.Parameters.ContainsKey($entry.Key)) {
                $splat[$entry.Key] = $entry.Value
            }
        }

        foreach ($parameter in $command.Parameters.Values | Where-Object { $_.IsMandatory }) {
            if ($splat.ContainsKey($parameter.Name)) {
                continue
            }

            $splat[$parameter.Name] = switch ($parameter.ParameterType.FullName) {
                'System.Boolean' { $false }
                'System.Int32' { 0 }
                'System.String' {
                    if ($parameter.Name -eq 'OutputPath') {
                        Join-Path ([System.IO.Path]::GetTempPath()) 'DecomWhatIfPlan'
                    }
                    elseif ($parameter.Name -eq 'EngagementId') {
                        'Rev410'
                    }
                    elseif ($parameter.Name -eq 'ClientName') {
                        'SuppressCustomerRemediation'
                    }
                    elseif ($parameter.Name -eq 'Assessor') {
                        'Codex'
                    }
                    elseif ($parameter.Name -eq 'WhatIfRunId') {
                        'rev410-suppression'
                    }
                    elseif ($parameter.Name -eq 'Classification') {
                        'ExternalVendorPlatform'
                    }
                    elseif ($parameter.Name -eq 'RemediationMode') {
                        'InformationOnly'
                    }
                    else {
                        ''
                    }
                }
                'System.Collections.Hashtable' { @{} }
                'System.Object[]' { @() }
                default { $null }
            }
        }

        $shouldPipe = $null -ne $PipelineInput -and -not ($splat.ContainsKey('InputObject') -or $splat.ContainsKey('Finding') -or $splat.ContainsKey('NhiObject') -or $splat.ContainsKey('Record'))

        if ($shouldPipe) {
            return $PipelineInput | & $CommandName @splat
        }

        return & $CommandName @splat
    }

    function New-SuppressedFindingFixture {
        param(
            [string]$FindingId = 'ACT-063',
            [string]$DisplayName = 'iOS Accounts',
            [string]$Classification = 'ExternalVendorPlatform'
        )

        [pscustomobject]@{
            FindingId = $FindingId
            DisplayName = $DisplayName
            Classification = $Classification
            ClassificationConfidence = 'High'
            ClassificationScore = 0
            ClassificationSource = 'Catalog'
            ClassificationSignals = @('platform catalog')
            SuppressCustomerRemediation = $true
            MicrosoftPlatform = $false
            FirstPartyMicrosoftApp = $false
            MicrosoftFirstParty = $false
            EvidenceOnly = $true
            RemediationMode = 'ManualApprovalRequired'
            RecommendedAction = 'Assign owner using AddApplicationOwner action'
            NormalizedAppId = 'f8d98a96-0999-43f5-8af3-69971c7bb423'
            NormalizedPublisherName = ''
            NormalizedVerifiedPublisherName = 'Apple Inc.'
            NormalizedAppOwnerOrganizationId = 'e0fad04c-a04c-41ab-b35e-dc523af755a1'
            NormalizedServicePrincipalType = 'Application'
            NormalizedTags = @('WindowsAzureActiveDirectoryIntegratedApp')
        }
    }
}

Describe 'SuppressCustomerRemediation' {
    It 'survives into the final finding object and forces evidence-only output' {
        $source = New-SuppressedFindingFixture

        $finding = New-DecomFinding `
            -FindingId $source.FindingId `
            -Category 'PlatformIdentity' `
            -Severity 'Informational' `
            -RiskScore 0 `
            -Confidence 'High' `
            -ObjectType 'ServicePrincipal' `
            -ObjectId '00000000-0000-0000-0000-000000000000' `
            -DisplayName $source.DisplayName `
            -Evidence @('platform catalog') `
            -EvidenceSource 'Catalog' `
            -RemediationMode 'ManualApprovalRequired' `
            -RecommendedAction 'Assign owner using AddApplicationOwner action' `
            -Classification $source.Classification `
            -ClassificationConfidence 'High' `
            -ClassificationSignals @('platform catalog') `
            -ClassificationSource 'Catalog' `
            -ClassificationScore 0 `
            -MicrosoftPlatformReason 'Catalog identity' `
            -NormalizedAppId $source.NormalizedAppId `
            -NormalizedPublisherName $source.NormalizedPublisherName `
            -NormalizedVerifiedPublisherName $source.NormalizedVerifiedPublisherName `
            -NormalizedAppOwnerOrganizationId $source.NormalizedAppOwnerOrganizationId `
            -NormalizedServicePrincipalType $source.NormalizedServicePrincipalType `
            -NormalizedTags $source.NormalizedTags `
            -NhiCandidate $true `
            -AgenticCandidate $false `
            -AutomationCandidate $false `
            -WorkloadCandidate $false `
            -OwnerCount 0 `
            -CredentialCount 0 `
            -ExpiredCredentialCount 0 `
            -ExpiringCredentialCount 0 `
            -HighRiskPermissionCount 0 `
            -HighRiskOAuthGrantCount 0 `
            -TenantWideConsent $false `
            -VerifiedPublisherName $source.NormalizedVerifiedPublisherName `
            -PublisherName $source.NormalizedPublisherName `
            -FirstPartyMicrosoftApp $false `
            -MicrosoftFirstParty $false `
            -MicrosoftPlatform $false `
            -SuppressCustomerRemediation $true `
            -EvidenceOnly $true `
            -CoverageMode 'EvidenceOnly' `
            -RiskScoreMayBeUnderstated $false

        $finding.SuppressCustomerRemediation | Should -BeTrue
        $finding.Classification | Should -Be 'ExternalVendorPlatform'
        $finding.MicrosoftPlatform | Should -BeFalse
        $finding.FirstPartyMicrosoftApp | Should -BeFalse
        $finding.PSObject.Properties.Name | Should -Contain 'SuppressCustomerRemediation'
    }

    It 'suppresses executable targets and approval-plan actions' {
        $finding = New-SuppressedFindingFixture
        $planPath = Join-Path ([System.IO.Path]::GetTempPath()) 'DecomWhatIfPlan'
        [System.IO.Directory]::CreateDirectory($planPath) | Out-Null

        $resolved = Resolve-DecomExecutableTargets -Finding $finding
        $resolvedJson = $resolved | ConvertTo-Json -Depth 20 -Compress

        $resolvedJson | Should -Not -Match 'AddApplicationOwner|Assign owner|Verify publisher|Revoke consent|Reduce permission scope|ManualApprovalRequired'

        $plan = Invoke-DecomCommandWithDefaults -CommandName 'New-DecomWhatIfActionPlan' -PreferredArguments @{
            Findings = @($finding)
            ExecutionMap = @{}
            OutputPath = $planPath
            EngagementId = 'Rev410'
            ClientName = 'SuppressCustomerRemediation'
            Assessor = 'Codex'
            WhatIfRunId = 'rev410-suppression'
            ExpiryDays = 30
        }

        $planJson = $plan | ConvertTo-Json -Depth 20 -Compress
        $planJson | Should -Not -Match 'AddApplicationOwner|Assign owner|Verify publisher|Revoke consent|Reduce permission scope|ManualApprovalRequired'
    }
}
