#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev4.13 lab-only live reversible disable dry-run package' {
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
                [Parameter(Mandatory)][string]$TargetId,
                [Parameter()][string]$ApprovedAction = 'DisableOnly'
            )

            [pscustomobject]@{
                ApprovalId = "APR-$RunId"
                ApprovalManifestId = "MAN-$RunId"
                ApprovedAction = $ApprovedAction
                ApprovalExpiresUtc = ([DateTime]::UtcNow.AddDays(1).ToString('o'))
                ApprovalManifestHash = 'abc123'
                ApprovedBy = 'lab-approver'
                Approver = 'lab-approver'
                ApprovalReason = 'Lab reversible disable dry-run'
                BusinessJustification = 'Lab reversible disable dry-run'
                ApprovedActions = @($ApprovedAction)
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
            }
        }

        function script:New-TestRollbackReadiness {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][string]$TargetId,
                [Parameter()][bool]$PreActionEnabledState = $true
            )

            [pscustomobject]@{
                TargetObjectId = $TargetId
                PreActionAccountEnabled = $PreActionEnabledState
                PlannedAction = 'ReversibleDisable'
                RollbackActionName = 'RollbackDisable'
                ApprovalId = "APR-$RunId"
                RunId = $RunId
                CapturedUtc = ([DateTime]::UtcNow.ToString('o'))
                SnapshotId = "SNAP-$RunId"
                BaselineHash = 'baseline-hash'
                EvidenceSourcePath = Join-Path $TestDrive "rollback-$RunId.evidence.json"
            }
        }

        function script:New-TestObservation {
            param([Parameter(Mandatory)][string]$RunId)

            $start = [DateTime]::UtcNow
            [pscustomobject]@{
                ObservationWindowMinutes = 60
                MonitoringOwner = 'lab-ops'
                RollbackContact = 'lab-ops'
                ObservationStartUtc = $start.ToString('o')
                ObservationEndUtc = $start.AddMinutes(60).ToString('o')
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
        }

        function script:New-TestPackageInputs {
            param([Parameter(Mandatory)][string]$RunId)

            $targetId = [guid]::NewGuid().Guid
            $target = New-TestTarget -DisplayName 'Lab Reversible NHI' -ObjectId $targetId
            $readiness = New-TestReadinessResult -TargetId $targetId
            $approval = New-TestApproval -RunId $RunId -TargetId $targetId
            $snapshot = New-TestSnapshot -RunId $RunId -TargetId $targetId
            $rollback = New-TestRollbackReadiness -RunId $RunId -TargetId $targetId
            $observation = New-TestObservation -RunId $RunId

            [pscustomobject]@{
                Target = $target
                Readiness = $readiness
                Approval = $approval
                Snapshot = $snapshot
                Rollback = $rollback
                Observation = $observation
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
            $script:RunId = 'REV413-LAB-001'
            $script:Inputs = New-TestPackageInputs -RunId $script:RunId
            $script:OutputPath = Join-Path $TestDrive 'rev413-dry-run-package.json'
        }

        It 'generates a dry-run operator package for an approved lab-ready target' {
            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $script:Inputs.Target `
                -ReadinessResult $script:Inputs.Readiness `
                -Approval $script:Inputs.Approval `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackReadiness $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath

            $package.Ready | Should -BeTrue
            $package.PackageId | Should -Not -BeNullOrEmpty
            $package.Mode | Should -Be 'OperatorDryRun'
            $package.TenantWritePlanned | Should -BeFalse
            $package.ExecutionPerformed | Should -BeFalse
            $package.FinalDeleteAllowed | Should -BeFalse
            $package.ReadinessVerdict.AllowedAction | Should -Be 'ReversibleDisable'
            $package.ReadinessVerdict.ReadinessFunction | Should -Be 'Test-NhiControlledLabLiveReversibleDisableReadiness'
            $package.Target.TargetDisplayName | Should -Be 'Lab Reversible NHI'
            $package.Target.TargetObjectId | Should -Be $script:Inputs.Target.ObjectId
            $package.Target.TargetAppId | Should -Be $script:Inputs.Target.AppId
            $package.Target.TargetType | Should -Be 'ServicePrincipal'
            $package.Approval.ApprovedBy | Should -Be 'lab-approver'
            $package.Approval.ApprovalManifestId | Should -Be "MAN-$script:RunId"
            $package.PreActionSnapshot.PreActionCredentialCount | Should -Be 2
            $package.PreActionSnapshot.PreActionOwnerCount | Should -Be 1
            $package.RollbackReadiness.RollbackActionName | Should -Be 'RollbackDisable'
            $package.Observation.MonitoringOwner | Should -Be 'lab-ops'
            $package.OutputArtifactPath | Should -Be $script:OutputPath
            Test-Path -LiteralPath $script:OutputPath | Should -BeTrue

            $artifact = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
            $artifact.PackageId | Should -Be $package.PackageId
            $artifact.Mode | Should -Be 'OperatorDryRun'
            $artifact.TargetDisplayName | Should -Be 'Lab Reversible NHI'
        }

        It 'declares non-mutating execution flags and reversible-disable-only planning' {
            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $script:Inputs.Target `
                -ReadinessResult $script:Inputs.Readiness `
                -Approval $script:Inputs.Approval `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackReadiness $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId

            $package.TenantWritePlanned | Should -BeFalse
            $package.ExecutionPerformed | Should -BeFalse
            $package.PlannedAction.PlannedAction | Should -Be 'ReversibleDisable'
            $package.PlannedAction.WhatIf | Should -BeTrue
            $package.PlannedAction.ConfirmRequired | Should -BeTrue
            $package.PlannedAction.HumanApprovalRequired | Should -BeTrue
            $package.PlannedAction.ExpectedChange | Should -Be 'disable only'
        }

        It 'explicitly prohibits final delete and related destructive operations' {
            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $script:Inputs.Target `
                -ReadinessResult $script:Inputs.Readiness `
                -Approval $script:Inputs.Approval `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackReadiness $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId

            @($package.ProhibitedOperations) | Should -Contain 'final delete'
            @($package.ProhibitedOperations) | Should -Contain 'service principal removal'
            @($package.ProhibitedOperations) | Should -Contain 'application removal'
            @($package.ProhibitedOperations) | Should -Contain 'grant cleanup'
            @($package.ProhibitedOperations) | Should -Contain 'metadata cleanup'
            @($package.ProhibitedOperations) | Should -Contain 'credential deletion'
        }
    }

    Context 'fail closed' {
        BeforeAll {
            $script:RunId = 'REV413-LAB-002'
            $script:Inputs = New-TestPackageInputs -RunId $script:RunId
        }

        It 'fails closed when readiness result is missing' {
            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $script:Inputs.Target `
                -ReadinessResult $null `
                -Approval $script:Inputs.Approval `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackReadiness $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Readiness result is required'
        }

        It 'fails closed when approval metadata is missing' {
            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $script:Inputs.Target `
                -ReadinessResult $script:Inputs.Readiness `
                -Approval $null `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackReadiness $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Approval metadata is required'
        }

        It 'fails closed when snapshot metadata is missing' {
            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $script:Inputs.Target `
                -ReadinessResult $script:Inputs.Readiness `
                -Approval $script:Inputs.Approval `
                -Snapshot $null `
                -RollbackReadiness $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Snapshot metadata is required'
        }

        It 'fails closed when rollback metadata is missing' {
            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $script:Inputs.Target `
                -ReadinessResult $script:Inputs.Readiness `
                -Approval $script:Inputs.Approval `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackReadiness $null `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Rollback readiness metadata is required'
        }

        It 'fails closed when observation metadata is missing' {
            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $script:Inputs.Target `
                -ReadinessResult $script:Inputs.Readiness `
                -Approval $script:Inputs.Approval `
                -Snapshot $script:Inputs.Snapshot `
                -RollbackReadiness $script:Inputs.Rollback `
                -ObservationMetadata $null `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Observation metadata is required'
        }

        It 'fails closed for MicrosoftPlatform targets' {
            $target = New-TestTarget -DisplayName 'Microsoft Graph PowerShell' -ObjectId ([guid]::NewGuid().Guid) -Classification 'MicrosoftPlatform' -MicrosoftPlatform $true
            $inputs = New-TestPackageInputs -RunId $script:RunId

            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $target `
                -ReadinessResult $inputs.Readiness `
                -Approval $inputs.Approval `
                -Snapshot $inputs.Snapshot `
                -RollbackReadiness $inputs.Rollback `
                -ObservationMetadata $inputs.Observation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Platform, suppressed, or evidence-only targets'
        }

        It 'fails closed for suppressed targets' {
            $target = New-TestTarget -DisplayName 'Suppressed NHI' -ObjectId ([guid]::NewGuid().Guid) -SuppressCustomerRemediation $true
            $inputs = New-TestPackageInputs -RunId $script:RunId

            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $target `
                -ReadinessResult $inputs.Readiness `
                -Approval $inputs.Approval `
                -Snapshot $inputs.Snapshot `
                -RollbackReadiness $inputs.Rollback `
                -ObservationMetadata $inputs.Observation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Platform, suppressed, or evidence-only targets'
        }

        It 'fails closed for EvidenceOnly targets' {
            $target = New-TestTarget -DisplayName 'EvidenceOnly NHI' -ObjectId ([guid]::NewGuid().Guid) -EvidenceOnly $true -RemediationMode 'EvidenceOnly'
            $inputs = New-TestPackageInputs -RunId $script:RunId

            $package = New-NhiControlledLabDisableDryRunPackage `
                -Target $target `
                -ReadinessResult $inputs.Readiness `
                -Approval $inputs.Approval `
                -Snapshot $inputs.Snapshot `
                -RollbackReadiness $inputs.Rollback `
                -ObservationMetadata $inputs.Observation `
                -RunId $script:RunId

            $package.Ready | Should -BeFalse
            ($package.Blockers -join '; ') | Should -Match 'Platform, suppressed, or evidence-only targets'
        }
    }
}
