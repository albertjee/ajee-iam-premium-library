$ErrorActionPreference = 'Stop'

function global:New-TestTarget {
    param([string]$Classification = 'CustomerOwned',[bool]$SuppressCustomerRemediation = $false,[bool]$EvidenceOnly = $false)
    [pscustomobject]@{
        ObjectId = '11111111-1111-1111-1111-111111111111'
        DisplayName = 'Lab Reversible NHI'
        AppId = '22222222-2222-2222-2222-222222222222'
        ObjectType = 'ServicePrincipal'
        TargetType = 'ServicePrincipal'
        Classification = $Classification
        Environment = 'Lab'
        TenantScope = 'Lab'
        IsLabTarget = $true
        LabTargetMarker = $true
        SuppressCustomerRemediation = $SuppressCustomerRemediation
        EvidenceOnly = $EvidenceOnly
        InformationOnly = $false
        RemediationMode = 'ManualApprovalRequired'
    }
}

function global:New-TestPackage {
    param([string]$Name,[hashtable]$Extra)
    $package = [ordered]@{ OutputArtifactPath = Join-Path $TestDrive "$Name.json" }
    foreach ($k in $Extra.Keys) { $package[$k] = $Extra[$k] }
    [pscustomobject]$package
}

Describe 'Rev4.26 Controlled Rollback Execution Test Package, Dev/Test Only' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev426'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:Target = @(New-TestTarget)
        $script:OriginalDisable = New-TestPackage -Name 'disable' -Extra @{ PlannedAction = 'ReversibleDisable'; OutputArtifactPath = (Join-Path $TestDrive 'disable.json') }
        $script:PostDisableValidation = New-TestPackage -Name 'postdisable' -Extra @{ PostDisableValidationStatus = 'Passed'; OutputArtifactPath = (Join-Path $TestDrive 'postdisable.json') }
        $script:Readiness = New-TestPackage -Name 'readiness' -Extra @{ RollbackReadiness = 'Ready'; OutputArtifactPath = (Join-Path $TestDrive 'readiness.json') }
        $script:Preview = New-TestPackage -Name 'preview' -Extra @{ RollbackAction = 'ReEnableServicePrincipal'; OutputArtifactPath = (Join-Path $TestDrive 'preview.json') }
        $script:Drill = New-TestPackage -Name 'drill' -Extra @{ Ready = $true; RollbackAction = 'ReEnableServicePrincipal'; OutputArtifactPath = (Join-Path $TestDrive 'drill.json') }
        $script:Snapshot = New-TestPackage -Name 'snapshot' -Extra @{ SnapshotPath = (Join-Path $TestDrive 'snapshot.json'); AccountEnabled = $true }
        $script:Trigger = [pscustomobject]@{ Reason = 'Manual operator stop' }
    }

    It 'Complete rollback artifact chain creates rollback execution test package' {
        $result = New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-OK'
        $result.PackageStatus | Should -Be 'ReadyForHumanRollbackReview'
        $result.RequiredHumanDecision | Should -BeTrue
        $result.HumanRollbackApprovalRequired | Should -BeTrue
        $result.HumanRollbackApprovalCaptured | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).RollbackExecutionTestPackageId | Should -Match '^REV426-'
    }

    It 'Package states RollbackPerformed=false' {
        (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-STATE').RollbackPerformed | Should -BeFalse
    }

    It 'Missing original disable evidence returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $null -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-1').PackageStatus | Should -Be 'NotReady' }
    It 'Missing post-disable validation package returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $null -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-2').PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback readiness package returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $null -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-3').PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback preview package returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $null -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-4').PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback drill package returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $null -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-5').PackageStatus | Should -Be 'NotReady' }
    It 'Missing observation trigger returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $null -OutputPath $script:OutputPath -RunId 'REV426-6').PackageStatus | Should -Be 'NotReady' }

    It 'Rollback action other than re-enable returns NotReady' {
        $badPreview = New-TestPackage -Name 'badpreview' -Extra @{ RollbackAction = 'Delete'; OutputArtifactPath = (Join-Path $TestDrive 'badpreview.json') }
        (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $badPreview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-7').PackageStatus | Should -Be 'NotReady'
    }

    It 'Delete request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('Delete') -OutputPath $script:OutputPath -RunId 'REV426-8').PackageStatus | Should -Be 'NotReady' }
    It 'Remove request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('Remove') -OutputPath $script:OutputPath -RunId 'REV426-9').PackageStatus | Should -Be 'NotReady' }
    It 'Recreate request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('Recreate') -OutputPath $script:OutputPath -RunId 'REV426-10').PackageStatus | Should -Be 'NotReady' }
    It 'Grant cleanup request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('GrantCleanup') -OutputPath $script:OutputPath -RunId 'REV426-11').PackageStatus | Should -Be 'NotReady' }
    It 'Metadata cleanup request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('MetadataCleanup') -OutputPath $script:OutputPath -RunId 'REV426-12').PackageStatus | Should -Be 'NotReady' }
    It 'Credential change request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('CredentialChange') -OutputPath $script:OutputPath -RunId 'REV426-13').PackageStatus | Should -Be 'NotReady' }

    It 'Human rollback approval required and not auto-captured' {
        $result = New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-14'
        $result.HumanRollbackApprovalRequired | Should -BeTrue
        $result.HumanRollbackApprovalCaptured | Should -BeFalse
    }

    It 'Rollback live command block is emitted only as a template and marked DO NOT RUN' {
        $result = New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-15'
        $result.RollbackLiveCommandBlockTemplate | Should -Match 'DO NOT RUN WITHOUT FINAL HUMAN ROLLBACK GO/NO-GO'
    }
}
