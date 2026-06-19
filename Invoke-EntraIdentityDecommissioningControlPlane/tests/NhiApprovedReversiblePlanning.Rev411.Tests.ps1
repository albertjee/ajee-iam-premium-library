#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev4.11 approved reversible lab NHI planning' {
    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'

        foreach ($m in @('Utilities', 'ApprovalManifest', 'NhiControlledDecommission', 'NhiExecutionSchema')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }

        $script:UtilitiesModule = Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking -PassThru
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiControlledDecommission.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiExecutionSchema.psm1') -Force -DisableNameChecking
        $script:NewDecomFindingCommand = $script:UtilitiesModule.ExportedFunctions['New-DecomFinding']

        function script:Get-TestSha256Hex {
            param([Parameter(Mandatory)][string]$InputString)

            $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
            $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
            ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
        }

        function script:New-TestFinding {
            param(
                [Parameter(Mandatory)][string]$FindingId,
                [Parameter(Mandatory)][string]$DisplayName,
                [Parameter(Mandatory)][string]$Classification,
                [Parameter(Mandatory)][bool]$MicrosoftPlatform,
                [Parameter(Mandatory)][bool]$FirstPartyMicrosoftApp,
                [Parameter(Mandatory)][bool]$SuppressCustomerRemediation,
                [Parameter(Mandatory)][string]$RemediationMode,
                [Parameter(Mandatory)][string]$RecommendedAction,
                [Parameter(Mandatory)][string]$AppId,
                [Parameter(Mandatory)][string]$AppOwnerOrganizationId,
                [Parameter(Mandatory)][string]$VerifiedPublisherName
            )

            & $script:NewDecomFindingCommand `
                -FindingId $FindingId `
                -Category 'NHI Planning' `
                -Severity 'Informational' `
                -RiskScore 0 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName $DisplayName `
                -Evidence "Synthetic planning evidence for $DisplayName" `
                -EvidenceSource 'unit-test' `
                -RecommendedAction $RecommendedAction `
                -RemediationMode $RemediationMode `
                -Classification $Classification `
                -ClassificationConfidence 'High' `
                -ClassificationSignals @('catalog', 'unit-test') `
                -ClassificationSource 'Catalog' `
                -ClassificationScore 0 `
                -MicrosoftPlatformReason 'Catalog identity' `
                -NormalizedAppId $AppId `
                -NormalizedPublisherName '' `
                -NormalizedVerifiedPublisherName $VerifiedPublisherName `
                -NormalizedAppOwnerOrganizationId $AppOwnerOrganizationId `
                -NormalizedServicePrincipalType 'Application' `
                -NormalizedTags @('WindowsAzureActiveDirectoryIntegratedApp') `
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
                -VerifiedPublisherName $VerifiedPublisherName `
                -PublisherName '' `
                -FirstPartyMicrosoftApp $FirstPartyMicrosoftApp `
                -MicrosoftFirstParty $FirstPartyMicrosoftApp `
                -MicrosoftPlatform $MicrosoftPlatform `
                -SuppressCustomerRemediation $SuppressCustomerRemediation `
                -EvidenceOnly ([string]$RemediationMode -in @('InformationOnly', 'EvidenceOnly')) `
                -CoverageMode 'EvidenceOnly' `
                -RiskScoreMayBeUnderstated $false
        }

        function script:New-TestControlledTarget {
            param(
                [Parameter(Mandatory)][string]$DisplayName,
                [Parameter(Mandatory)][string]$TargetId,
                [Parameter(Mandatory)][string]$Classification,
                [Parameter(Mandatory)][string]$RemediationMode
            )

            [pscustomobject]@{
                ObjectId                   = $TargetId
                ObjectType                 = 'ServicePrincipal'
                DisplayName                = $DisplayName
                AppId                      = [guid]::NewGuid().Guid
                Classification             = $Classification
                MicrosoftPlatform          = $false
                FirstPartyMicrosoftApp     = $false
                MicrosoftFirstParty        = $false
                SuppressCustomerRemediation = $false
                RemediationMode            = $RemediationMode
                ProtectedObject            = $false
                BreakGlassIndicator        = $false
                EmergencyAccessIndicator   = $false
                HighConfidenceActive       = $false
                Ambiguous                  = $false
            }
        }

        function script:New-TestApprovalRecord {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][string]$TargetId,
                [Parameter(Mandatory)][string]$ActionType,
                [Parameter()][string]$ApprovedBy = 'unit-test',
                [Parameter()][string]$SchemaVersion = '4.2',
                [Parameter()][string]$Status = 'Approved',
                [Parameter()][string]$ExpiresUtc = ([DateTime]::UtcNow.AddDays(1).ToString('o')),
                [Parameter()][string[]]$ApprovedActions = @('DisableOnly')
            )

            [pscustomobject]@{
                SchemaVersion   = $SchemaVersion
                ApprovedBy      = $ApprovedBy
                Status          = $Status
                RunId           = $RunId
                ExpiresUtc      = $ExpiresUtc
                Reusable        = $false
                TargetObjectIds = @($TargetId)
                ApprovedActions = @($ApprovedActions)
                ActionType      = $ActionType
                ApprovedUtc     = [DateTime]::UtcNow.ToString('o')
            }
        }

        function script:Write-TestApprovalManifest {
            param(
                [Parameter(Mandatory)][string]$Path,
                [Parameter(Mandatory)][string]$EngagementId,
                [Parameter(Mandatory)][string[]]$TargetObjectIds,
                [Parameter(Mandatory)][string]$ApprovedBy,
                [Parameter(Mandatory)][string]$ApprovedAt,
                [Parameter(Mandatory)][int]$ExecutionPhaseApproved,
                [Parameter()][string]$SchemaVersion = '4.2'
            )

            $idsJson = ConvertTo-Json -InputObject $TargetObjectIds -Compress -Depth 10
            $manifest = [pscustomobject]@{
                EngagementId           = $EngagementId
                SHA256                 = Get-TestSha256Hex -InputString $idsJson
                ExecutionPhaseApproved = $ExecutionPhaseApproved
                ApprovedBy             = $ApprovedBy
                ApprovedAt             = $ApprovedAt
                SchemaVersion          = $SchemaVersion
            }

            $json = $manifest | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
            return $manifest
        }
    }

    AfterAll {
        foreach ($m in @('NhiExecutionSchema', 'NhiControlledDecommission', 'ApprovalManifest', 'Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'platform suppression' {
        It 'blocks Microsoft Graph PowerShell from producing executable remediation' {
            $finding = New-TestFinding `
                -FindingId 'DEC-SPN-001' `
                -DisplayName 'Microsoft Graph PowerShell' `
                -Classification 'MicrosoftPlatform' `
                -MicrosoftPlatform $true `
                -FirstPartyMicrosoftApp $true `
                -SuppressCustomerRemediation $true `
                -RemediationMode 'InformationOnly' `
                -RecommendedAction 'Evidence only - Microsoft platform identity' `
                -AppId '14d82eec-204b-4c2f-b7e8-296a70dab67e' `
                -AppOwnerOrganizationId '72f988bf-86f1-41af-91ab-2d7cd011db47' `
                -VerifiedPublisherName 'Microsoft Corporation'

            $resolved = Resolve-DecomExecutableTargets -Finding $finding
            $resolvedText = $resolved | ConvertTo-Json -Depth 20 -Compress

            $finding.Classification | Should -Be 'MicrosoftPlatform'
            $finding.MicrosoftPlatform | Should -BeTrue
            $finding.FirstPartyMicrosoftApp | Should -BeTrue
            $finding.SuppressCustomerRemediation | Should -BeTrue
            $finding.RemediationMode | Should -Be 'InformationOnly'
            $resolvedText | Should -Not -Match 'AddApplicationOwner|Remove-MgServicePrincipal|Remove-MgApplication|FinalDelete'
            $resolved.Resolved | Should -BeFalse
            @($resolved.TargetObjects).Count | Should -Be 0
        }

        It 'blocks iOS Accounts from producing executable remediation' {
            $finding = New-TestFinding `
                -FindingId 'DEC-SPN-001' `
                -DisplayName 'iOS Accounts' `
                -Classification 'ExternalVendorPlatform' `
                -MicrosoftPlatform $false `
                -FirstPartyMicrosoftApp $false `
                -SuppressCustomerRemediation $true `
                -RemediationMode 'InformationOnly' `
                -RecommendedAction 'Evidence only - external vendor platform identity' `
                -AppId 'f8d98a96-0999-43f5-8af3-69971c7bb423' `
                -AppOwnerOrganizationId 'e0fad04c-a04c-41ab-b35e-dc523af755a1' `
                -VerifiedPublisherName 'Apple Inc.'

            $resolved = Resolve-DecomExecutableTargets -Finding $finding
            $resolvedText = $resolved | ConvertTo-Json -Depth 20 -Compress

            $finding.Classification | Should -Be 'ExternalVendorPlatform'
            $finding.MicrosoftPlatform | Should -BeFalse
            $finding.FirstPartyMicrosoftApp | Should -BeFalse
            $finding.SuppressCustomerRemediation | Should -BeTrue
            $finding.RemediationMode | Should -Be 'InformationOnly'
            $resolvedText | Should -Not -Match 'AddApplicationOwner|Remove-MgServicePrincipal|Remove-MgApplication|FinalDelete'
            $resolved.Resolved | Should -BeFalse
            @($resolved.TargetObjects).Count | Should -Be 0
        }
    }

    Context 'approved reversible planning' {
        BeforeAll {
            $script:RunId = 'REV411-LAB-001'
            $script:ApprovedTargetId = [guid]::NewGuid().Guid
            $script:UnapprovedTargetId = [guid]::NewGuid().Guid
            $script:MissingMetadataTargetId = [guid]::NewGuid().Guid

            $script:ApprovedTarget = New-TestControlledTarget `
                -DisplayName 'Lab Reversible NHI' `
                -TargetId $script:ApprovedTargetId `
                -Classification 'CustomerOwned' `
                -RemediationMode 'ManualApprovalRequired'

            $script:ApprovedFinding = New-TestFinding `
                -FindingId 'DEC-SPN-001' `
                -DisplayName $script:ApprovedTarget.DisplayName `
                -Classification 'CustomerOwned' `
                -MicrosoftPlatform $false `
                -FirstPartyMicrosoftApp $false `
                -SuppressCustomerRemediation $false `
                -RemediationMode 'ManualApprovalRequired' `
                -RecommendedAction 'Disable service principal after approval' `
                -AppId $script:ApprovedTarget.AppId `
                -AppOwnerOrganizationId '11111111-2222-3333-4444-555555555555' `
                -VerifiedPublisherName 'Contoso Labs'

            $script:UnapprovedFinding = New-TestFinding `
                -FindingId 'DEC-SPN-001' `
                -DisplayName 'Unapproved Lab NHI' `
                -Classification 'CustomerOwned' `
                -MicrosoftPlatform $false `
                -FirstPartyMicrosoftApp $false `
                -SuppressCustomerRemediation $false `
                -RemediationMode 'ManualApprovalRequired' `
                -RecommendedAction 'Disable service principal after approval' `
                -AppId ([guid]::NewGuid().Guid) `
                -AppOwnerOrganizationId '11111111-2222-3333-4444-555555555555' `
                -VerifiedPublisherName 'Contoso Labs'

            $script:MissingMetadataFinding = New-TestFinding `
                -FindingId 'DEC-SPN-001' `
                -DisplayName 'Missing Approval Metadata NHI' `
                -Classification 'CustomerOwned' `
                -MicrosoftPlatform $false `
                -FirstPartyMicrosoftApp $false `
                -SuppressCustomerRemediation $false `
                -RemediationMode 'ManualApprovalRequired' `
                -RecommendedAction 'Disable service principal after approval' `
                -AppId ([guid]::NewGuid().Guid) `
                -AppOwnerOrganizationId '11111111-2222-3333-4444-555555555555' `
                -VerifiedPublisherName 'Contoso Labs'
        }

        It 'keeps the approved customer/lab finding actionable and non-platform' {
            $script:ApprovedFinding.Classification | Should -Be 'CustomerOwned'
            $script:ApprovedFinding.MicrosoftPlatform | Should -BeFalse
            $script:ApprovedFinding.FirstPartyMicrosoftApp | Should -BeFalse
            $script:ApprovedFinding.SuppressCustomerRemediation | Should -BeFalse
            $script:ApprovedFinding.RemediationMode | Should -Be 'ManualApprovalRequired'
            $script:ApprovedFinding.RecommendedAction | Should -Match 'Disable service principal'
        }

        It 'accepts the approved target through the controlled approval gates and produces a reversible disable plan only' {
            $approvalManifestPath = Join-Path $TestDrive 'rev411-approved-manifest.json'
            $null = Write-TestApprovalManifest `
                -Path $approvalManifestPath `
                -EngagementId $script:RunId `
                -TargetObjectIds @($script:ApprovedTargetId) `
                -ApprovedBy 'lab-approver' `
                -ApprovedAt ([DateTime]::UtcNow.ToString('o')) `
                -ExecutionPhaseApproved 2

            { Confirm-NhiApprovedManifest -ManifestPath $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:ApprovedTargetId) -PhaseLimit 2 } | Should -Not -Throw

            $approval = New-TestApprovalRecord -RunId $script:RunId -TargetId $script:ApprovedTargetId -ActionType 'DisableOnly' -ApprovedBy 'lab-approver' -ApprovedActions @('DisableOnly')
            $approvalCheck = Confirm-NhiControlledApproval -Approval $approval -RunId $script:RunId -TargetId $script:ApprovedTargetId -ActionType 'DisableOnly' -ExpectedSchemaVersion '4.2'
            $approvalCheck.Passed | Should -BeTrue

            $plan = New-NhiControlledDecommissionPlan -Target $script:ApprovedTarget -ExecutionStage 'DisableOnly' -RunId $script:RunId -WhatIf $true -DemoMode $true
            $schema = Get-NhiExecutionSchema

            $plan.Status | Should -Be 'Planned'
            $plan.PlanningOnly | Should -BeTrue
            $plan.WhatIf | Should -BeTrue
            $plan.FinalDeleteLiveEnabled | Should -BeFalse
            $plan.Actions.Count | Should -Be 1
            $plan.Actions[0].ActionType | Should -Be 'DisableOnly'
            $plan.Actions[0].RollbackAvailable | Should -BeTrue
            $plan.Actions[0].Result | Should -Be 'Planned'
            $schema.Disable.IsReversible | Should -BeTrue
            $schema.Keys | Should -Contain 'Disable'
            $schema.Keys | Should -Contain 'RollbackDisable'
            $schema.Keys | Should -Not -Contain 'FinalDelete'

            $planJson = $plan | ConvertTo-Json -Depth 20 -Compress
            $planJson | Should -Not -Match 'ActionType":"FinalDelete|ExecutionStage":"FinalDelete|HardDelete|PermanentDelete|Remove-MgServicePrincipal|Remove-MgApplication'
            $planJson | Should -Match 'DisableOnly'
            $plan.TargetId | Should -Be $script:ApprovedTargetId
            $approval.TargetObjectIds | Should -Contain $script:ApprovedTargetId
        }

        It 'fails closed for an otherwise actionable unapproved target' {
            $approval = New-TestApprovalRecord -RunId $script:RunId -TargetId $script:ApprovedTargetId -ActionType 'DisableOnly' -ApprovedBy 'lab-approver' -ApprovedActions @('DisableOnly')
            $approvalCheck = Confirm-NhiControlledApproval -Approval $approval -RunId $script:RunId -TargetId $script:UnapprovedTargetId -ActionType 'DisableOnly' -ExpectedSchemaVersion '4.2'

            $approvalCheck.Passed | Should -BeFalse
            ($approvalCheck.Reasons -join '; ') | Should -Match 'Target is not approved'
        }

        It 'fails closed when approval metadata is missing or incomplete' {
            $missingApprovedBy = New-TestApprovalRecord -RunId $script:RunId -TargetId $script:MissingMetadataTargetId -ActionType 'DisableOnly' -ApprovedBy '' -ApprovedActions @('DisableOnly')
            $missingApprovedByCheck = Confirm-NhiControlledApproval -Approval $missingApprovedBy -RunId $script:RunId -TargetId $script:MissingMetadataTargetId -ActionType 'DisableOnly' -ExpectedSchemaVersion '4.2'

            $missingExpiresUtc = New-TestApprovalRecord -RunId $script:RunId -TargetId $script:MissingMetadataTargetId -ActionType 'DisableOnly' -ApprovedBy 'lab-approver' -ExpiresUtc '' -ApprovedActions @('DisableOnly')
            $missingExpiresUtcCheck = Confirm-NhiControlledApproval -Approval $missingExpiresUtc -RunId $script:RunId -TargetId $script:MissingMetadataTargetId -ActionType 'DisableOnly' -ExpectedSchemaVersion '4.2'

            $missingApprovedByCheck.Passed | Should -BeFalse
            $missingExpiresUtcCheck.Passed | Should -BeFalse
            (($missingApprovedByCheck.Reasons + $missingExpiresUtcCheck.Reasons) -join '; ') | Should -Match 'ApprovedBy is required|ExpiresUtc is required'
        }

        It 'blocks final-delete planning and keeps final delete out of the approved reversible path' {
            $finalDeletePlan = New-NhiControlledDecommissionPlan -Target $script:ApprovedTarget -ExecutionStage 'FinalDelete' -RunId $script:RunId -WhatIf $true -DemoMode $true
            $finalDeletePlan.Status | Should -Be 'Blocked'
            ($finalDeletePlan.BlockReason + ' ' + ($finalDeletePlan.Actions | ConvertTo-Json -Depth 20 -Compress)) | Should -Match 'FinalDelete is blocked'
            ($finalDeletePlan.Actions | ConvertTo-Json -Depth 20 -Compress) | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|HardDelete|PermanentDelete'
        }

        It 'exports a local WhatIf plan artifact that stays non-mutating and excludes platform targets' {
            $plan = New-NhiControlledDecommissionPlan -Target $script:ApprovedTarget -ExecutionStage 'DisableOnly' -RunId $script:RunId -WhatIf $true -DemoMode $true
            $artifactPath = Join-Path $TestDrive 'rev411-whatif-plan.json'
            $artifact = [pscustomobject]@{
                TargetDisplayName      = $script:ApprovedTarget.DisplayName
                TargetId               = $plan.TargetId
                WhatIf                 = $plan.WhatIf
                PlanningOnly           = $plan.PlanningOnly
                ActionType             = $plan.Actions[0].ActionType
                RollbackAvailable      = $plan.Actions[0].RollbackAvailable
            }
            $null = Export-NhiControlledDecommissionEvidence -Evidence $artifact -Path $artifactPath

            Test-Path -LiteralPath $artifactPath | Should -BeTrue
            $artifactText = Get-Content -LiteralPath $artifactPath -Raw

            $artifactText | Should -Match $script:ApprovedTarget.DisplayName
            $artifactText | Should -Match '"WhatIf":\s*true'
            $artifactText | Should -Match '"PlanningOnly":\s*true'
            $artifactText | Should -Match '"ActionType":\s*"DisableOnly"'
            $artifactText | Should -Not -Match 'FinalDelete|Remove-MgServicePrincipal|Remove-MgApplication|HardDelete|PermanentDelete'
        }
    }
}
