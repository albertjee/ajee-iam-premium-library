$ErrorActionPreference = 'Stop'

function global:Write-TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $Path -Encoding utf8
}

function global:New-TestTarget {
    param(
        [string]$Classification = 'CustomerOwned',
        [string]$Environment = 'Lab',
        [bool]$SuppressCustomerRemediation = $false,
        [bool]$EvidenceOnly = $false,
        [bool]$InformationOnly = $false
    )

    [pscustomobject]@{
        ObjectId = '11111111-1111-1111-1111-111111111111'
        DisplayName = 'Lab Reversible NHI'
        AppId = '22222222-2222-2222-2222-222222222222'
        ObjectType = 'ServicePrincipal'
        TargetType = 'ServicePrincipal'
        Classification = $Classification
        Environment = $Environment
        TenantScope = $Environment
        IsLabTarget = $true
        LabTargetMarker = $true
        SuppressCustomerRemediation = $SuppressCustomerRemediation
        EvidenceOnly = $EvidenceOnly
        InformationOnly = $InformationOnly
        RemediationMode = if ($InformationOnly) { 'InformationOnly' } else { 'ManualApprovalRequired' }
    }
}

function global:New-TestSnapshot {
    [pscustomobject]@{
        SnapshotId = 'SNAP-RUN4C-ROLLBACK-001'
        SnapshotPath = Join-Path $TestDrive 'rollback-snapshot.json'
        CapturedUtc = ([datetime]::UtcNow.ToString('o'))
        BaselineHash = 'snapshot-hash'
        PreActionEnabledState = $true
        EvidenceSourcePath = Join-Path $TestDrive 'rollback-snapshot.evidence.json'
    }
}

function global:New-TestOriginalDisableEvidence {
    [pscustomobject]@{
        PlannedAction = 'ReversibleDisable'
        OutputArtifactPath = Join-Path $TestDrive 'rollback-disable-evidence.json'
    }
}

function global:New-TestRollbackDrillPackage {
    [pscustomobject]@{
        RollbackPackageId = 'RB-DRILL-001'
        Ready = $true
        RollbackAction = 'ReEnableServicePrincipal'
        OutputArtifactPath = Join-Path $TestDrive 'rollback-drill.json'
    }
}

function global:New-TestRollbackReadinessPackage {
    [pscustomobject]@{
        RollbackReadinessPackageId = 'REV419-READY-001'
        RollbackReadiness = 'Ready'
        OutputArtifactPath = Join-Path $TestDrive 'rollback-readiness.json'
    }
}

function global:New-TestObservation {
    [pscustomobject]@{
        ObservationWindowMinutes = 60
        MonitoringOwner = 'lab-ops'
        RollbackContact = 'lab-ops'
        RollbackTriggerCriteria = @('Critical outage')
        OutputArtifactPath = Join-Path $TestDrive 'rollback-observation.json'
    }
}

function global:Invoke-RollbackPreview {
    param(
        [object]$Target = $null,
        [object]$OriginalDisableEvidence = $null,
        [object]$PreActionSnapshot = $null,
        [object]$RollbackDrillPackage = $null,
        [object]$RollbackExecutionReadinessPackage = $null,
        [object]$PostDisableObservation = $null,
        [object]$RollbackTrigger = @('Critical outage'),
        [string[]]$RequestedOperations = @(),
        [bool]$HumanRollbackApprovalCaptured = $false,
        [string]$RunId = 'REV420-001'
    )

    if (-not $PSBoundParameters.ContainsKey('Target')) { $Target = New-TestTarget }
    if (-not $PSBoundParameters.ContainsKey('OriginalDisableEvidence')) { $OriginalDisableEvidence = New-TestOriginalDisableEvidence }
    if (-not $PSBoundParameters.ContainsKey('PreActionSnapshot')) { $PreActionSnapshot = New-TestSnapshot }
    if (-not $PSBoundParameters.ContainsKey('RollbackDrillPackage')) { $RollbackDrillPackage = New-TestRollbackDrillPackage }
    if (-not $PSBoundParameters.ContainsKey('RollbackExecutionReadinessPackage')) { $RollbackExecutionReadinessPackage = New-TestRollbackReadinessPackage }
    if (-not $PSBoundParameters.ContainsKey('PostDisableObservation')) { $PostDisableObservation = New-TestObservation }

    if ($OriginalDisableEvidence -and $OriginalDisableEvidence.OutputArtifactPath) { Write-TestJson -Path $OriginalDisableEvidence.OutputArtifactPath -InputObject $OriginalDisableEvidence }
    if ($PreActionSnapshot -and $PreActionSnapshot.SnapshotPath) { Write-TestJson -Path $PreActionSnapshot.SnapshotPath -InputObject $PreActionSnapshot }
    if ($RollbackDrillPackage -and $RollbackDrillPackage.OutputArtifactPath) { Write-TestJson -Path $RollbackDrillPackage.OutputArtifactPath -InputObject $RollbackDrillPackage }
    if ($RollbackExecutionReadinessPackage -and $RollbackExecutionReadinessPackage.OutputArtifactPath) { Write-TestJson -Path $RollbackExecutionReadinessPackage.OutputArtifactPath -InputObject $RollbackExecutionReadinessPackage }
    if ($PostDisableObservation -and $PostDisableObservation.OutputArtifactPath) { Write-TestJson -Path $PostDisableObservation.OutputArtifactPath -InputObject $PostDisableObservation }

    Invoke-NhiControlledLabRollback `
        -Target @($Target) `
        -OriginalDisableEvidence $OriginalDisableEvidence `
        -PreActionSnapshot $PreActionSnapshot `
        -RollbackDrillPackage $RollbackDrillPackage `
        -RollbackExecutionReadinessPackage $RollbackExecutionReadinessPackage `
        -PostDisableObservation $PostDisableObservation `
        -RollbackTrigger $RollbackTrigger `
        -RequestedOperations $RequestedOperations `
        -HumanRollbackApprovalCaptured $HumanRollbackApprovalCaptured `
        -RunId $RunId `
        -OutputPath $script:OutputPath
}

Describe 'Rev4.20 Controlled Rollback Path' {
    BeforeAll {
        if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
            throw 'PSScriptRoot is not available for this test harness.'
        }

        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        if (-not (Test-Path -LiteralPath $script:modulePath)) {
            throw "Required module not found: $script:modulePath"
        }

        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev420'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:BlockedTarget = New-TestTarget -Classification 'MicrosoftPlatform'
        $script:ExternalTarget = New-TestTarget -Classification 'ExternalVendorPlatform'
        $script:SuppressedTarget = New-TestTarget -SuppressCustomerRemediation $true
        $script:EvidenceOnlyTarget = New-TestTarget -EvidenceOnly $true
        $script:InformationOnlyTarget = New-TestTarget -InformationOnly $true
        $script:ReadonlyReadiness = New-TestRollbackReadinessPackage
        $script:ReadonlyReadiness.RollbackReadiness = 'NotReady'
    }

    It 'Complete rollback-ready dev/test target produces rollback preview package' {
        $result = Invoke-RollbackPreview -HumanRollbackApprovalCaptured $true

        $result.RollbackExecutionPackageMetadata.Mode | Should -Be 'ControlledRollbackPreviewOnly'
        $result.RollbackReadinessSummary.RollbackReadiness | Should -Be 'Ready'
        $result.RollbackReadinessSummary.HumanRollbackApprovalRequired | Should -BeTrue
        $result.RollbackReadinessSummary.HumanRollbackApprovalCaptured | Should -BeTrue
        $result.PlannedRollbackAction.RollbackAction | Should -Be 'ReEnableServicePrincipal'
        $result.PlannedRollbackAction.WhatIf | Should -BeTrue
        $result.PlannedRollbackAction.ConfirmRequired | Should -BeTrue
        $result.PlannedRollbackAction.RollbackExecutionPerformed | Should -BeFalse
        $result.TenantWritePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = Invoke-RollbackPreview -RunId 'REV420-ARTIFACT'
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).RollbackExecutionPackageId | Should -Match '^REV420-'
    }

    It 'Package declares TenantWritePerformed=false and RollbackPerformed=false' {
        $result = Invoke-RollbackPreview -RunId 'REV420-STATE'
        $result.TenantWritePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
    }

    It 'Missing rollback readiness package fails closed' {
        (Invoke-RollbackPreview -RollbackExecutionReadinessPackage $null).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Rollback readiness NotReady fails closed' {
        (Invoke-RollbackPreview -RollbackExecutionReadinessPackage $script:ReadonlyReadiness -HumanRollbackApprovalCaptured $true).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Missing original disable evidence fails closed' {
        (Invoke-RollbackPreview -OriginalDisableEvidence $null).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Missing pre-action snapshot fails closed' {
        (Invoke-RollbackPreview -PreActionSnapshot $null).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Missing rollback trigger fails closed' {
        (Invoke-RollbackPreview -RollbackTrigger @()).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Missing human rollback approval remains preview-only and not executed' {
        $result = Invoke-RollbackPreview
        $result.RollbackExecutionPerformed | Should -BeFalse
        $result.RollbackReadinessSummary.HumanRollbackApprovalCaptured | Should -BeFalse
    }

    It 'MicrosoftPlatform target is blocked' {
        (Invoke-RollbackPreview -Target $script:BlockedTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'ExternalVendorPlatform target is blocked' {
        (Invoke-RollbackPreview -Target $script:ExternalTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'SuppressCustomerRemediation=true target is blocked' {
        (Invoke-RollbackPreview -Target $script:SuppressedTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'EvidenceOnly=true target is blocked' {
        (Invoke-RollbackPreview -Target $script:EvidenceOnlyTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Delete request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('Delete')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Remove request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('Remove')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Recreate request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('Recreate')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Grant cleanup request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('GrantCleanup')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Metadata cleanup request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('MetadataCleanup')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Credential change request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('CredentialChange')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Final delete request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('FinalDelete')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Rollback action other than re-enable is blocked' {
        $rollback = New-TestRollbackDrillPackage
        $rollback.RollbackAction = 'Delete'
        (Invoke-RollbackPreview -RollbackDrillPackage $rollback -HumanRollbackApprovalCaptured $true).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Rollback is not executed by tests' {
        $result = Invoke-RollbackPreview
        $result.RollbackExecutionPerformed | Should -BeFalse
        $result.PlannedRollbackAction.CommandPreview | Should -Match 'Preview only'
    }
}
