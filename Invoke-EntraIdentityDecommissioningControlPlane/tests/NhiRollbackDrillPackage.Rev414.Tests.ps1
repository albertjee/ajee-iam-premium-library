#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev4.14 rollback drill package' {
    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'

        foreach ($m in @('NhiControlledDecommission')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }

        Import-Module (Join-Path $script:ModulesPath 'NhiControlledDecommission.psm1') -Force -DisableNameChecking

        function script:New-TestTarget {
            param(
                [Parameter(Mandatory)][string]$DisplayName,
                [Parameter(Mandatory)][string]$ObjectId,
                [Parameter()][string]$AppId = ([guid]::NewGuid().Guid),
                [Parameter()][string]$Classification = 'CustomerOwned',
                [Parameter()][bool]$MicrosoftPlatform = $false,
                [Parameter()][bool]$FirstPartyMicrosoftApp = $false,
                [Parameter()][bool]$SuppressCustomerRemediation = $false,
                [Parameter()][bool]$EvidenceOnly = $false,
                [Parameter()][string]$Environment = 'Lab',
                [Parameter()][bool]$IsLabTarget = $true,
                [Parameter()][string]$TenantScope = 'Lab',
                [Parameter()][string]$RemediationMode = 'ManualApprovalRequired'
            )

            [pscustomobject]@{
                ObjectId = $ObjectId
                ObjectType = 'ServicePrincipal'
                DisplayName = $DisplayName
                AppId = $AppId
                Classification = $Classification
                MicrosoftPlatform = $MicrosoftPlatform
                FirstPartyMicrosoftApp = $FirstPartyMicrosoftApp
                SuppressCustomerRemediation = $SuppressCustomerRemediation
                EvidenceOnly = $EvidenceOnly
                Environment = $Environment
                IsLabTarget = $IsLabTarget
                TenantScope = $TenantScope
                LabValidationApproved = $true
                RemediationMode = $RemediationMode
                AccountEnabled = $true
                VerifiedPublisherName = 'Contoso Labs'
                ProtectedObject = $false
                BreakGlassIndicator = $false
                EmergencyAccessIndicator = $false
                HighConfidenceActive = $false
                Ambiguous = $false
            }
        }

        function script:New-TestReadinessResult {
            param([Parameter(Mandatory)][string]$TargetId)

            [pscustomobject]@{
                Ready = $true
                Blockers = @()
                Warnings = @()
                AllowedAction = 'DisableOnly'
                ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
                TenantWritePlanned = $false
                ExecutionPerformed = $false
                FinalDeleteAllowed = $false
                TargetId = $TargetId
            }
        }

        function script:New-TestApproval {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][string]$TargetId
            )

            [pscustomobject]@{
                ApprovalId = "APR-$RunId"
                ApprovalManifestId = "MAN-$RunId"
                ApprovedAction = 'DisableOnly'
                ApprovalExpiresUtc = ([DateTime]::UtcNow.AddDays(1).ToString('o'))
                ApprovalManifestHash = 'abc123'
                ApprovedBy = 'lab-approver'
                Approver = 'lab-approver'
                ApprovalReason = 'Lab reversible disable dry-run'
                BusinessJustification = 'Lab reversible disable dry-run'
                ApprovedActions = @('DisableOnly')
                RunId = $RunId
                TargetObjectIds = @($TargetId)
            }
        }

        function script:New-TestSnapshot {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][string]$TargetId,
                [Parameter()][bool]$PreActionEnabledState = $true
            )

            [pscustomobject]@{
                SnapshotId = "SNAP-$RunId"
                SnapshotPath = Join-Path $TestDrive "snapshot-$RunId.json"
                CapturedUtc = ([DateTime]::UtcNow.ToString('o'))
                PreActionEnabledState = $PreActionEnabledState
                AccountEnabled = $PreActionEnabledState
                PreActionCredentialCount = 2
                PreActionOwnerCount = 1
                PreActionAppRoleAssignmentsCount = 3
                PreActionOAuthGrantCount = 4
                TargetObjectId = $TargetId
                EvidenceSourcePath = Join-Path $TestDrive "snapshot-$RunId.evidence.json"
                BaselineHash = 'baseline-hash'
            }
        }

        function script:New-TestRollbackTriggers {
            [pscustomobject]@{
                Items = @(
                    'App outage detected',
                    'Authentication failure spike',
                    'Owner/business validation failure',
                    'Monitoring owner escalation',
                    'Manual operator stop condition'
                )
            }
        }

        function script:New-TestRollbackValidation {
            [pscustomobject]@{
                Items = @(
                    'Target enabled state restored',
                    'Sign-in/authentication recovery observed if applicable',
                    'Owner/business validation completed',
                    'Audit record written',
                    'Post-rollback observation window completed'
                )
            }
        }

        function script:New-TestDryRunPackage {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][object]$Target
            )

            $readiness = New-TestReadinessResult -TargetId $Target.ObjectId
            $approval = New-TestApproval -RunId $RunId -TargetId $Target.ObjectId
            $snapshot = New-TestSnapshot -RunId $RunId -TargetId $Target.ObjectId
            $rollbackReadiness = [pscustomobject]@{
                TargetObjectId = $Target.ObjectId
                PreActionAccountEnabled = $true
                PlannedAction = 'ReversibleDisable'
                RollbackActionName = 'RollbackDisable'
                ApprovalId = "APR-$RunId"
                RunId = $RunId
                CapturedUtc = ([DateTime]::UtcNow.ToString('o'))
                SnapshotId = "SNAP-$RunId"
                BaselineHash = 'baseline-hash'
                EvidenceSourcePath = Join-Path $TestDrive "rollback-$RunId.evidence.json"
            }
            $observation = [pscustomobject]@{
                ObservationWindowMinutes = 60
                MonitoringOwner = 'lab-ops'
                RollbackContact = 'lab-ops'
                ObservationStartUtc = ([DateTime]::UtcNow.ToString('o'))
                ObservationEndUtc = ([DateTime]::UtcNow.AddMinutes(60).ToString('o'))
                SuccessCriteria = 'Target can be reviewed before any future live lab change.'
                FailureCriteria = 'Target fails validation or a blocker appears.'
                RollbackTriggerCriteria = @(
                    'App outage detected',
                    'Authentication failure spike',
                    'Owner/business validation failure',
                    'Monitoring owner escalation',
                    'Manual operator stop condition'
                )
            }

            New-NhiControlledLabDisableDryRunPackage `
                -Target $Target `
                -ReadinessResult $readiness `
                -Approval $approval `
                -Snapshot $snapshot `
                -RollbackReadiness $rollbackReadiness `
                -ObservationMetadata $observation `
                -RunId $RunId `
                -OutputPath (Join-Path $TestDrive "rev414-source-$RunId.json")
        }

        function script:New-TestInputs {
            param([Parameter(Mandatory)][string]$RunId)

            $targetId = [guid]::NewGuid().Guid
            $target = New-TestTarget -DisplayName 'Lab Reversible NHI' -ObjectId $targetId
            $dryRun = New-TestDryRunPackage -RunId $RunId -Target $target
            $snapshot = New-TestSnapshot -RunId $RunId -TargetId $targetId

            [pscustomobject]@{
                Target = $target
                DryRun = $dryRun
                Snapshot = $snapshot
                Triggers = (New-TestRollbackTriggers).Items
                Validation = (New-TestRollbackValidation).Items
            }
        }
    }

    AfterAll {
        foreach ($m in @('NhiControlledDecommission')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'package generation' {
        BeforeAll {
            $script:RunId = 'REV414-LAB-001'
            $script:Inputs = New-TestInputs -RunId $script:RunId
            $script:OutputPath = Join-Path $TestDrive 'rev414-rollback-package.json'
        }

        It 'generates a rollback drill package for an approved lab-ready target' {
            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $script:Inputs.Target `
                -SourceDryRunPackage $script:Inputs.DryRun `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackTriggers $script:Inputs.Triggers `
                -RollbackValidationCriteria $script:Inputs.Validation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath

            $package.Ready | Should -BeTrue
            $package.RollbackPackageId | Should -Not -BeNullOrEmpty
            $package.Mode | Should -Be 'RollbackDrillOnly'
            $package.RollbackExecuted | Should -BeFalse
            $package.TenantWritePlanned | Should -BeFalse
            $package.FinalDeleteAllowed | Should -BeFalse
            $package.SourceDryRunPackageId | Should -Be $script:Inputs.DryRun.PackageId
            $package.Target.TargetDisplayName | Should -Be 'Lab Reversible NHI'
            $package.PreActionBaseline.BaselineHash | Should -Be 'baseline-hash'
            $package.RollbackAction.RollbackAction | Should -Be 'ReEnableServicePrincipal'
            $package.RollbackAction.WhatIf | Should -BeTrue
            $package.RollbackAction.ConfirmRequired | Should -BeTrue
            $package.RollbackAction.HumanApprovalRequired | Should -BeTrue
            $package.RollbackAction.RollbackExecutionPerformed | Should -BeFalse
            $package.OutputArtifactPath | Should -Be $script:OutputPath
            Test-Path -LiteralPath $script:OutputPath | Should -BeTrue

            $artifact = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
            $artifact.RollbackPackageId | Should -Be $package.RollbackPackageId
            $artifact.Mode | Should -Be 'RollbackDrillOnly'
            $artifact.SourceDryRunPackageId | Should -Be $script:Inputs.DryRun.PackageId
        }

        It 'includes pre-action baseline, rollback preview, and validation gates only' {
            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $script:Inputs.Target `
                -SourceDryRunPackage $script:Inputs.DryRun `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackTriggers $script:Inputs.Triggers `
                -RollbackValidationCriteria $script:Inputs.Validation `
                -RunId $script:RunId

            $package.PreActionBaseline.AccountEnabled | Should -BeTrue
            $package.PreActionBaseline.SnapshotId | Should -Be "SNAP-$script:RunId"
            $package.RollbackAction.PseudoCommand | Should -Match 'ReEnableServicePrincipal'
            $package.RollbackAction.WhatIf | Should -BeTrue
            $package.RollbackAction.ConfirmRequired | Should -BeTrue
            $package.RollbackAction.HumanApprovalRequired | Should -BeTrue
            $package.RollbackTriggerCriteria.Count | Should -Be 5
            $package.RollbackValidationCriteria.Count | Should -Be 5
        }

        It 'blocks delete, remove, recreate, grant-cleanup, and credential-change behaviors' {
            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $script:Inputs.Target `
                -SourceDryRunPackage $script:Inputs.DryRun `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackTriggers $script:Inputs.Triggers `
                -RollbackValidationCriteria $script:Inputs.Validation `
                -RunId $script:RunId

            @($package.ProhibitedRollbackBehaviors) | Should -Contain 'delete anything'
            @($package.ProhibitedRollbackBehaviors) | Should -Contain 'remove service principal'
            @($package.ProhibitedRollbackBehaviors) | Should -Contain 'remove application'
            @($package.ProhibitedRollbackBehaviors) | Should -Contain 'recreate object as substitute for rollback'
            @($package.ProhibitedRollbackBehaviors) | Should -Contain 'modify grants'
            @($package.ProhibitedRollbackBehaviors) | Should -Contain 'modify credentials'
            @($package.ProhibitedRollbackBehaviors) | Should -Contain 'bypass approval'
        }
    }

    Context 'fail closed' {
        BeforeAll {
            $script:RunId = 'REV414-LAB-002'
            $script:Inputs = New-TestInputs -RunId $script:RunId
        }

        It 'fails closed when dry-run package linkage is missing' {
            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $script:Inputs.Target `
                -SourceDryRunPackage $null `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackTriggers $script:Inputs.Triggers `
                -RollbackValidationCriteria $script:Inputs.Validation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Source dry-run package linkage is required'
        }

        It 'fails closed when pre-action snapshot is missing' {
            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $script:Inputs.Target `
                -SourceDryRunPackage $script:Inputs.DryRun `
                -Snapshot $null `
                -RollbackTriggers $script:Inputs.Triggers `
                -RollbackValidationCriteria $script:Inputs.Validation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Snapshot metadata is required'
        }

        It 'fails closed when rollback trigger criteria is missing' {
            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $script:Inputs.Target `
                -SourceDryRunPackage $script:Inputs.DryRun `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackTriggers @() `
                -RollbackValidationCriteria $script:Inputs.Validation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Rollback trigger criteria cannot be empty'
        }

        It 'fails closed when rollback validation criteria is missing' {
            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $script:Inputs.Target `
                -SourceDryRunPackage $script:Inputs.DryRun `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackTriggers $script:Inputs.Triggers `
                -RollbackValidationCriteria @() `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Rollback validation criteria cannot be empty'
        }

        It 'fails closed for MicrosoftPlatform targets' {
            $target = New-TestTarget -DisplayName 'Microsoft Graph PowerShell' -ObjectId ([guid]::NewGuid().Guid) -Classification 'MicrosoftPlatform' -MicrosoftPlatform $true
            $inputs = New-TestInputs -RunId $script:RunId

            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $target `
                -SourceDryRunPackage $inputs.DryRun `
                -Snapshot $inputs.Snapshot `
                -RollbackTriggers $inputs.Triggers `
                -RollbackValidationCriteria $inputs.Validation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Platform, suppressed, or evidence-only targets'
        }

        It 'fails closed for suppressed targets' {
            $target = New-TestTarget -DisplayName 'Suppressed NHI' -ObjectId ([guid]::NewGuid().Guid) -SuppressCustomerRemediation $true
            $inputs = New-TestInputs -RunId $script:RunId

            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $target `
                -SourceDryRunPackage $inputs.DryRun `
                -Snapshot $inputs.Snapshot `
                -RollbackTriggers $inputs.Triggers `
                -RollbackValidationCriteria $inputs.Validation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Platform, suppressed, or evidence-only targets'
        }

        It 'fails closed for EvidenceOnly targets' {
            $target = New-TestTarget -DisplayName 'EvidenceOnly NHI' -ObjectId ([guid]::NewGuid().Guid) -EvidenceOnly $true -RemediationMode 'EvidenceOnly'
            $inputs = New-TestInputs -RunId $script:RunId

            $package = New-NhiControlledLabRollbackDrillPackage `
                -Target $target `
                -SourceDryRunPackage $inputs.DryRun `
                -Snapshot $inputs.Snapshot `
                -RollbackTriggers $inputs.Triggers `
                -RollbackValidationCriteria $inputs.Validation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Platform, suppressed, or evidence-only targets'
        }
    }
}
