#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Run #4C lab live reversible disable' {
    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'

        foreach ($m in @('NhiExecution', 'NhiControlledDecommission')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }

        Import-Module (Join-Path $script:ModulesPath 'NhiExecution.psm1') -Force -DisableNameChecking
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

        function script:New-TestApprovalManifest {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][object]$Target,
                [Parameter()][string]$ApprovedAction = 'ReversibleDisable',
                [Parameter()][string]$ApprovalReason = 'Run #4C lab reversible disable',
                [Parameter()][string]$ApprovedBy = 'lab-approver',
                [Parameter()][string]$ApprovalExpiresUtc = ([DateTime]::UtcNow.AddDays(1).ToString('o'))
            )

            [pscustomobject]@{
                ApprovalId = "APR-$RunId"
                TargetObjectId = $Target.ObjectId
                TargetDisplayName = $Target.DisplayName
                TargetType = $Target.ObjectType
                ApprovedAction = $ApprovedAction
                ApprovedBy = $ApprovedBy
                ApprovalReason = $ApprovalReason
                BusinessJustification = $ApprovalReason
                ApprovalExpiresUtc = $ApprovalExpiresUtc
                ApprovalManifestHash = 'rev415-manifest-hash'
            }
        }

        function script:Write-TestJson {
            param(
                [Parameter(Mandatory)][string]$Path,
                [Parameter(Mandatory)][object]$InputObject
            )

            $parent = Split-Path -Parent $Path
            if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
                New-Item -ItemType Directory -Path $parent -Force | Out-Null
            }

            $json = $InputObject | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
        }

        function script:New-TestSnapshot {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][object]$Target
            )

            [pscustomobject]@{
                SnapshotId = "SNAP-$RunId"
                SnapshotPath = Join-Path $TestDrive "snapshot-$RunId.json"
                CapturedUtc = ([DateTime]::UtcNow.ToString('o'))
                PreActionEnabledState = $true
                AccountEnabled = $true
                PreActionCredentialCount = 2
                PreActionOwnerCount = 1
                PreActionAppRoleAssignmentsCount = 3
                PreActionOAuthGrantCount = 4
                TargetObjectId = $Target.ObjectId
                TargetDisplayName = $Target.DisplayName
                TargetAppId = $Target.AppId
                BaselineHash = 'snapshot-baseline-hash'
                EvidenceSourcePath = Join-Path $TestDrive "snapshot-$RunId.evidence.json"
            }
        }

        function script:New-TestReadiness {
            param([Parameter(Mandatory)][string]$TargetId)

            [pscustomobject]@{
                Ready = $true
                Blockers = @()
                Warnings = @()
                AllowedAction = 'ReversibleDisable'
                ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
                TenantWritePlanned = $true
                ExecutionPerformed = $false
                FinalDeleteAllowed = $false
                TargetId = $TargetId
            }
        }

        function script:New-TestRollbackReadiness {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][string]$TargetId
            )

            [pscustomobject]@{
                TargetObjectId = $TargetId
                PreActionAccountEnabled = $true
                PlannedAction = 'ReversibleDisable'
                RollbackActionName = 'RollbackDisable'
                ApprovalId = "APR-$RunId"
                RunId = $RunId
                CapturedUtc = ([DateTime]::UtcNow.ToString('o'))
                SnapshotId = "SNAP-$RunId"
                BaselineHash = 'snapshot-baseline-hash'
                EvidenceSourcePath = Join-Path $TestDrive "rollback-$RunId.evidence.json"
            }
        }

        function script:New-TestObservation {
            [pscustomobject]@{
                ObservationWindowMinutes = 60
                MonitoringOwner = 'lab-ops'
                RollbackContact = 'lab-ops'
                ObservationStartUtc = ([DateTime]::UtcNow.ToString('o'))
                ObservationEndUtc = ([DateTime]::UtcNow.AddMinutes(60).ToString('o'))
                SuccessCriteria = 'Target is disabled only after explicit approval.'
                FailureCriteria = 'Target unexpectedly mutates beyond reversible disable.'
                RollbackTriggerCriteria = @(
                    'App outage detected',
                    'Authentication failure spike',
                    'Owner/business validation failure',
                    'Monitoring owner escalation',
                    'Manual operator stop condition'
                )
            }
        }

        function script:New-TestDryRunPackage {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][object]$Target,
                [Parameter(Mandatory)][object]$Readiness,
                [Parameter(Mandatory)][object]$Approval,
                [Parameter(Mandatory)][object]$Snapshot,
                [Parameter(Mandatory)][object]$RollbackReadiness,
                [Parameter(Mandatory)][object]$Observation
            )

            $package = [pscustomobject]@{
                PackageId = "DRY-$RunId"
                RunId = $RunId
                CreatedUtc = [DateTime]::UtcNow.ToString('o')
                Mode = 'OperatorDryRun'
                TenantWritePlanned = $false
                ExecutionPerformed = $false
                FinalDeleteAllowed = $false
                Ready = $true
                Blockers = @()
                Warnings = @()
                PlannedAction = 'ReversibleDisable'
                PlannedActionDetails = [pscustomobject]@{
                    PlannedAction = 'ReversibleDisable'
                    WhatIf = $true
                    ConfirmRequired = $true
                    HumanApprovalRequired = $true
                    ExpectedChange = 'disable only'
                }
                ProhibitedOperations = @(
                    'final delete',
                    'service principal removal',
                    'application removal',
                    'grant cleanup',
                    'metadata cleanup',
                    'credential deletion'
                )
                ReadinessVerdict = [pscustomobject]@{
                    Ready = $true
                    Blockers = @()
                    Warnings = @()
                    AllowedAction = 'ReversibleDisable'
                    ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
                }
                Target = [pscustomobject]@{
                    TargetDisplayName = $Target.DisplayName
                    TargetObjectId = $Target.ObjectId
                    TargetAppId = $Target.AppId
                    TargetType = $Target.ObjectType
                }
                Approval = [pscustomobject]@{
                    ApprovalId = $Approval.ApprovalId
                    ApprovalManifestId = "MAN-$RunId"
                    ApprovedAction = $Approval.ApprovedAction
                    ApprovalExpiresUtc = $Approval.ApprovalExpiresUtc
                    ApprovalManifestHash = $Approval.ApprovalManifestHash
                    ApprovedBy = $Approval.ApprovedBy
                    Approver = $Approval.ApprovedBy
                    ApprovalReason = $Approval.ApprovalReason
                }
                PreActionSnapshot = [pscustomobject]@{
                    SnapshotId = $Snapshot.SnapshotId
                    SnapshotPath = $Snapshot.SnapshotPath
                    PreActionEnabledState = [bool]$Snapshot.PreActionEnabledState
                    AccountEnabled = [bool]$Snapshot.AccountEnabled
                    PreActionCredentialCount = $Snapshot.PreActionCredentialCount
                    PreActionOwnerCount = $Snapshot.PreActionOwnerCount
                    PreActionAppRoleAssignmentsCount = $Snapshot.PreActionAppRoleAssignmentsCount
                    PreActionOAuthGrantCount = $Snapshot.PreActionOAuthGrantCount
                    CapturedUtc = $Snapshot.CapturedUtc
                }
                RollbackReadiness = [pscustomobject]@{
                    TargetObjectId = $RollbackReadiness.TargetObjectId
                    PreActionAccountEnabled = [bool]$RollbackReadiness.PreActionAccountEnabled
                    PlannedAction = $RollbackReadiness.PlannedAction
                    RollbackActionName = $RollbackReadiness.RollbackActionName
                    ApprovalId = $RollbackReadiness.ApprovalId
                    RunId = $RollbackReadiness.RunId
                    CapturedUtc = $RollbackReadiness.CapturedUtc
                    SnapshotId = $RollbackReadiness.SnapshotId
                    BaselineHash = $RollbackReadiness.BaselineHash
                    EvidenceSourcePath = $RollbackReadiness.EvidenceSourcePath
                }
                Observation = [pscustomobject]@{
                    ObservationWindowMinutes = $Observation.ObservationWindowMinutes
                    MonitoringOwner = $Observation.MonitoringOwner
                    RollbackContact = $Observation.RollbackContact
                    ObservationStartUtc = $Observation.ObservationStartUtc
                    ObservationEndUtc = $Observation.ObservationEndUtc
                    SuccessCriteria = $Observation.SuccessCriteria
                    FailureCriteria = $Observation.FailureCriteria
                    RollbackTriggerCriteria = @($Observation.RollbackTriggerCriteria)
                }
            }

            $path = Join-Path $TestDrive "run4c-dryrun-$RunId.json"
            Write-TestJson -Path $path -InputObject $package
            $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue $path -Force
            return $package
        }

        function script:New-TestRollbackPackage {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][object]$Target,
                [Parameter(Mandatory)][object]$DryRunPackage,
                [Parameter(Mandatory)][object]$Snapshot
            )

            $package = [pscustomobject]@{
                RollbackPackageId = "RB-$RunId"
                RunId = $RunId
                CreatedUtc = [DateTime]::UtcNow.ToString('o')
                SourceDryRunPackageId = $DryRunPackage.PackageId
                Mode = 'RollbackDrillOnly'
                RollbackExecuted = $false
                TenantWritePlanned = $false
                FinalDeleteAllowed = $false
                Ready = $true
                Blockers = @()
                Warnings = @()
                RollbackAction = 'ReEnableServicePrincipal'
                Target = [pscustomobject]@{
                    TargetDisplayName = $Target.DisplayName
                    TargetObjectId = $Target.ObjectId
                    TargetAppId = $Target.AppId
                    TargetType = $Target.ObjectType
                    LabTargetMarker = 'LabTarget'
                }
                PreActionBaseline = [pscustomobject]@{
                    PreActionEnabledState = [bool]$Snapshot.PreActionEnabledState
                    AccountEnabled = [bool]$Snapshot.AccountEnabled
                    SnapshotId = $Snapshot.SnapshotId
                    SnapshotPath = $Snapshot.SnapshotPath
                    CapturedUtc = $Snapshot.CapturedUtc
                    BaselineHash = $Snapshot.BaselineHash
                    EvidenceSourcePath = $Snapshot.EvidenceSourcePath
                }
                RollbackActionDetails = [pscustomobject]@{
                    RollbackAction = 'ReEnableServicePrincipal'
                    RollbackCommandPreview = "WhatIf: ServicePrincipal account re-enable preview for $($Target.ObjectId)"
                    PseudoCommand = "ReEnableServicePrincipal -TargetObjectId $($Target.ObjectId) -WhatIf"
                    WhatIf = $true
                    ConfirmRequired = $true
                    HumanApprovalRequired = $true
                    RollbackExecutionPerformed = $false
                }
                RollbackTriggerCriteria = @(
                    'App outage detected',
                    'Authentication failure spike',
                    'Owner/business validation failure',
                    'Monitoring owner escalation',
                    'Manual operator stop condition'
                )
                RollbackValidationCriteria = @(
                    'Target enabled state restored',
                    'Sign-in/authentication recovery observed if applicable',
                    'Owner/business validation completed',
                    'Audit record written',
                    'Post-rollback observation window completed'
                )
                ProhibitedRollbackBehaviors = @(
                    'delete anything',
                    'remove service principal',
                    'remove application',
                    'recreate object as substitute for rollback',
                    'modify grants',
                    'modify credentials',
                    'bypass approval'
                )
                OperatorChecklist = @(
                    [pscustomobject]@{ Checked = $false; Required = $true; Item = 'Confirm original action was reversible disable only.' }
                    [pscustomobject]@{ Checked = $false; Required = $true; Item = 'Confirm pre-action snapshot exists.' }
                    [pscustomobject]@{ Checked = $false; Required = $true; Item = 'Confirm rollback target matches approved lab target.' }
                    [pscustomobject]@{ Checked = $false; Required = $true; Item = 'Confirm rollback command is re-enable only.' }
                    [pscustomobject]@{ Checked = $false; Required = $true; Item = 'Confirm rollback does not recreate or delete objects.' }
                    [pscustomobject]@{ Checked = $false; Required = $true; Item = 'Confirm rollback requires human approval.' }
                    [pscustomobject]@{ Checked = $false; Required = $true; Item = 'Confirm rollback is not executed by this package.' }
                    [pscustomobject]@{ Checked = $false; Required = $true; Item = 'Confirm post-rollback validation criteria are documented.' }
                )
                SourceDryRunPackage = [pscustomobject]@{
                    PackageId = $DryRunPackage.PackageId
                    Mode = $DryRunPackage.Mode
                    Ready = $DryRunPackage.Ready
                    TenantWritePlanned = $DryRunPackage.TenantWritePlanned
                    ExecutionPerformed = $DryRunPackage.ExecutionPerformed
                    PlannedAction = 'ReversibleDisable'
                }
            }

            $path = Join-Path $TestDrive "run4c-rollback-$RunId.json"
            Write-TestJson -Path $path -InputObject $package
            $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue $path -Force
            return $package
        }

        function script:New-TestInputs {
            param([Parameter(Mandatory)][string]$RunId)

            $targetId = [guid]::NewGuid().Guid
            $target = New-TestTarget -DisplayName 'Lab Reversible NHI' -ObjectId $targetId
            $approval = New-TestApprovalManifest -RunId $RunId -Target $target
            $approvalPath = Join-Path $TestDrive "approval-$RunId.json"
            Write-TestJson -Path $approvalPath -InputObject $approval

            $snapshot = New-TestSnapshot -RunId $RunId -Target $target
            $readiness = New-TestReadiness -TargetId $targetId
            $rollbackReadiness = New-TestRollbackReadiness -RunId $RunId -TargetId $targetId
            $observation = New-TestObservation
            $dryRun = New-TestDryRunPackage -RunId $RunId -Target $target -Readiness $readiness -Approval $approval -Snapshot $snapshot -RollbackReadiness $rollbackReadiness -Observation $observation
            $rollback = New-TestRollbackPackage -RunId $RunId -Target $target -DryRunPackage $dryRun -Snapshot $snapshot

            [pscustomobject]@{
                Target = $target
                Approval = $approval
                ApprovalPath = $approvalPath
                Snapshot = $snapshot
                Readiness = $readiness
                DryRun = $dryRun
                Rollback = $rollback
                Observation = $observation
            }
        }
    }

    AfterAll {
        foreach ($m in @('NhiExecution', 'NhiControlledDecommission')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }

        Remove-Item function:Get-MgServicePrincipal -Force -ErrorAction SilentlyContinue
    }

    Context 'preflight gate' {
        BeforeAll {
            $script:RunId = 'REV415-LAB-001'
            $script:Inputs = New-TestInputs -RunId $script:RunId
            $script:OutputPath = Join-Path $TestDrive 'run4c-output'
            New-Item -ItemType Directory -Path $script:OutputPath -Force | Out-Null
        }

        It 'blocks live execution unless LabExecutionApproved is true' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'LabExecutionApproved must be true'
        }

        It 'blocks live execution unless exactly one target is supplied' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target, $script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Exactly one target is required'
        }

        It 'blocks live execution for MicrosoftPlatform targets' {
            $target = New-TestTarget -DisplayName 'Microsoft Graph PowerShell' -ObjectId ([guid]::NewGuid().Guid) -Classification 'MicrosoftPlatform' -MicrosoftPlatform $true
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Platform targets are blocked'
        }

        It 'blocks live execution for ExternalVendorPlatform targets' {
            $target = New-TestTarget -DisplayName 'Vendor Platform' -ObjectId ([guid]::NewGuid().Guid) -Classification 'ExternalVendorPlatform'
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Platform targets are blocked'
        }

        It 'blocks live execution for SuppressCustomerRemediation=true' {
            $target = New-TestTarget -DisplayName 'Suppressed NHI' -ObjectId ([guid]::NewGuid().Guid) -SuppressCustomerRemediation $true
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'SuppressCustomerRemediation targets are blocked'
        }

        It 'blocks live execution for EvidenceOnly=true' {
            $target = New-TestTarget -DisplayName 'Evidence Only NHI' -ObjectId ([guid]::NewGuid().Guid) -EvidenceOnly $true
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'EvidenceOnly targets are blocked'
        }

        It 'blocks live execution for missing approval manifest' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $null `
                -ApprovalManifestPath (Join-Path $TestDrive 'missing-approval.json') `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Approval manifest'
        }

        It 'blocks live execution for expired approval' {
            $approval = New-TestApprovalManifest -RunId $script:RunId -Target $script:Inputs.Target -ApprovalExpiresUtc ([DateTime]::UtcNow.AddDays(-1).ToString('o'))
            Write-TestJson -Path $script:Inputs.ApprovalPath -InputObject $approval

            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Approval is expired'
        }

        It 'blocks live execution for missing pre-action snapshot' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $null `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Snapshot is required'
        }

        It 'blocks live execution for missing rollback package' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $null `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Rollback package is required'
        }

        It 'blocks live execution for missing observation plan' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $null `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Observation metadata is required'
        }

        It 'blocks live execution for final delete requests' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('FinalDelete')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Requested operation ''FinalDelete'' is blocked'
        }

        It 'blocks live execution for grant cleanup requests' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('GrantCleanup')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Requested operation ''GrantCleanup'' is blocked'
        }

        It 'blocks live execution for metadata cleanup requests' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('MetadataCleanup')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Requested operation ''MetadataCleanup'' is blocked'
        }

        It 'blocks live execution for credential deletion requests' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('CredentialDelete')

            $result.Ready | Should -BeFalse
            ($result.Blockers -join '; ') | Should -Match 'Requested operation ''CredentialDelete'' is blocked'
        }

        It 'produces a final live-run command preview without executing' {
            $preview = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -WhatIf `
                -RequestedOperations @('ReversibleDisable')

            $preview.LiveCommandPreview | Should -Match 'Invoke-NhiDisable'
            $preview.ExecutionPerformed | Should -BeFalse
            $preview.RollbackExecuted | Should -BeFalse
        }
    }

    Context 'execution gate' {
        BeforeAll {
            $script:RunId = 'REV415-LAB-002'
            $script:OutputPath = Join-Path $TestDrive 'run4c-execution'
            New-Item -ItemType Directory -Path $script:OutputPath -Force | Out-Null

            $script:ExecutionInputs = [pscustomobject]@{
                Target = [pscustomobject]@{
                    ObjectId = '11111111-1111-1111-1111-111111111111'
                    ObjectType = 'ServicePrincipal'
                    DisplayName = 'Lab Reversible NHI'
                    AppId = '22222222-2222-2222-2222-222222222222'
                    Classification = 'CustomerOwned'
                    MicrosoftPlatform = $false
                    FirstPartyMicrosoftApp = $false
                    SuppressCustomerRemediation = $false
                    EvidenceOnly = $false
                    Environment = 'Lab'
                    IsLabTarget = $true
                    TenantScope = 'Lab'
                    RemediationMode = 'ManualApprovalRequired'
                    AccountEnabled = $true
                    VerifiedPublisherName = 'Contoso Labs'
                    ProtectedObject = $false
                    BreakGlassIndicator = $false
                    EmergencyAccessIndicator = $false
                    HighConfidenceActive = $false
                    Ambiguous = $false
                }
                Approval = [pscustomobject]@{
                    ApprovalId = 'APR-RUN'
                    TargetObjectId = '11111111-1111-1111-1111-111111111111'
                    TargetDisplayName = 'Lab Reversible NHI'
                    TargetType = 'ServicePrincipal'
                    ApprovedAction = 'ReversibleDisable'
                    ApprovedBy = 'lab-approver'
                    ApprovalReason = 'Run #4C'
                    ApprovalExpiresUtc = ([DateTime]::UtcNow.AddDays(1).ToString('o'))
                    ApprovalManifestHash = 'hash'
                }
                ApprovalPath = Join-Path $TestDrive 'approval-execution.json'
                Snapshot = [pscustomobject]@{
                    SnapshotId = 'SNAP-RUN'
                    SnapshotPath = (Join-Path $TestDrive 'snap-execution.json')
                    CapturedUtc = ([DateTime]::UtcNow.ToString('o'))
                    PreActionEnabledState = $true
                    AccountEnabled = $true
                    PreActionCredentialCount = 1
                    PreActionOwnerCount = 1
                    PreActionAppRoleAssignmentsCount = 1
                    PreActionOAuthGrantCount = 1
                    TargetObjectId = '11111111-1111-1111-1111-111111111111'
                    TargetDisplayName = 'Lab Reversible NHI'
                    TargetAppId = '22222222-2222-2222-2222-222222222222'
                    BaselineHash = 'snapshot-baseline-hash'
                    EvidenceSourcePath = (Join-Path $TestDrive 'snap-execution.evidence.json')
                }
                Readiness = [pscustomobject]@{
                    Ready = $true
                    Blockers = @()
                    Warnings = @()
                    AllowedAction = 'ReversibleDisable'
                    ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
                    TenantWritePlanned = $true
                    ExecutionPerformed = $false
                    FinalDeleteAllowed = $false
                    TargetId = '11111111-1111-1111-1111-111111111111'
                }
                DryRun = [pscustomobject]@{
                    PackageId = 'DRY-RUN'
                    Ready = $true
                    TenantWritePlanned = $false
                    ExecutionPerformed = $false
                    FinalDeleteAllowed = $false
                    PlannedAction = 'ReversibleDisable'
                    PlannedActionDetails = [pscustomobject]@{
                        PlannedAction = 'ReversibleDisable'
                        WhatIf = $true
                        ConfirmRequired = $true
                        HumanApprovalRequired = $true
                        ExpectedChange = 'disable only'
                    }
                }
                Rollback = [pscustomobject]@{
                    RollbackPackageId = 'RB-RUN'
                    RollbackExecuted = $false
                    RollbackAction = 'ReEnableServicePrincipal'
                    WhatIf = $true
                    HumanApprovalRequired = $true
                }
                Observation = [pscustomobject]@{
                    ObservationWindowMinutes = 60
                    MonitoringOwner = 'lab-ops'
                    RollbackContact = 'lab-ops'
                    ObservationStartUtc = ([DateTime]::UtcNow.ToString('o'))
                    ObservationEndUtc = ([DateTime]::UtcNow.AddMinutes(60).ToString('o'))
                    SuccessCriteria = 'Target is disabled only after explicit approval.'
                    FailureCriteria = 'Target unexpectedly mutates beyond reversible disable.'
                    RollbackTriggerCriteria = @('App outage detected')
                }
            }
            Write-TestJson -Path $script:ExecutionInputs.ApprovalPath -InputObject $script:ExecutionInputs.Approval
        }

        It 'executes reversible disable only when explicit live lab approval is true and artifacts are present' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:ExecutionInputs.Target) `
                -ApprovalManifest $script:ExecutionInputs.Approval `
                -ApprovalManifestPath $script:ExecutionInputs.ApprovalPath `
                -Snapshot $script:ExecutionInputs.Snapshot `
                -ReadinessResult $script:ExecutionInputs.Readiness `
                -DryRunPackage $script:ExecutionInputs.DryRun `
                -RollbackPackage $script:ExecutionInputs.Rollback `
                -ObservationMetadata $script:ExecutionInputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -WhatIf `
                -RequestedOperations @('ReversibleDisable')

            $result.Ready | Should -BeTrue
            $result.ExecutionPerformed | Should -BeFalse
            $result.PreActionEnabledState | Should -BeTrue
            $result.PostActionEnabledState | Should -BeNullOrEmpty
            Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        }

        It 'writes execution evidence and records no delete/remove/grant cleanup/metadata cleanup/credential deletion occurred' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:ExecutionInputs.Target) `
                -ApprovalManifest $script:ExecutionInputs.Approval `
                -ApprovalManifestPath $script:ExecutionInputs.ApprovalPath `
                -Snapshot $script:ExecutionInputs.Snapshot `
                -ReadinessResult $script:ExecutionInputs.Readiness `
                -DryRunPackage $script:ExecutionInputs.DryRun `
                -RollbackPackage $script:ExecutionInputs.Rollback `
                -ObservationMetadata $script:ExecutionInputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -WhatIf `
                -RequestedOperations @('ReversibleDisable')

            $artifact = Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json
            $artifact.ExecutionPerformed | Should -BeFalse
            $artifact.NoDeleteOccurred | Should -BeTrue
            $artifact.NoRemoveOccurred | Should -BeTrue
            $artifact.NoGrantCleanupOccurred | Should -BeTrue
            $artifact.NoMetadataCleanupOccurred | Should -BeTrue
            $artifact.NoCredentialDeletionOccurred | Should -BeTrue
        }

        It 'does not execute rollback during Run #4C' {
            $result = Invoke-NhiControlledLabLiveReversibleDisable `
                -Target @($script:Inputs.Target) `
                -ApprovalManifest $script:Inputs.Approval `
                -ApprovalManifestPath $script:Inputs.ApprovalPath `
                -Snapshot $script:Inputs.Snapshot `
                -ReadinessResult $script:Inputs.Readiness `
                -DryRunPackage $script:Inputs.DryRun `
                -RollbackPackage $script:Inputs.Rollback `
                -ObservationMetadata $script:Inputs.Observation `
                -RunId $script:RunId `
                -OutputPath $script:OutputPath `
                -LabExecutionApproved $true `
                -RequestedOperations @('ReversibleDisable')

            $result.RollbackExecuted | Should -BeFalse
        }
    }
}
