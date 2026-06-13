$ErrorActionPreference = 'Stop'

$script:modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path

function Write-TestJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][object]$InputObject)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $Path -Encoding utf8
}

function New-TestTarget {
    param(
        [string]$Classification = 'CustomerOwned',
        [string]$Environment = 'Lab',
        [bool]$IsLabTarget = $true,
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
        IsLabTarget = $IsLabTarget
        LabTargetMarker = $IsLabTarget
        SuppressCustomerRemediation = $SuppressCustomerRemediation
        EvidenceOnly = $EvidenceOnly
        InformationOnly = $InformationOnly
        RemediationMode = if ($InformationOnly) { 'InformationOnly' } else { 'ManualApprovalRequired' }
    }
}

function New-TestSnapshot {
    [pscustomobject]@{
        SnapshotId = 'SNAP-RB-001'
        SnapshotPath = Join-Path $TestDrive 'rb-snapshot.json'
        CapturedUtc = ([datetime]::UtcNow.ToString('o'))
        PreActionEnabledState = $true
        AccountEnabled = $true
        BaselineHash = 'snapshot-hash'
        EvidenceSourcePath = Join-Path $TestDrive 'rb-snapshot.evidence.json'
    }
}

function New-TestOriginalDisableEvidence {
    [pscustomobject]@{
        PlannedAction = 'ReversibleDisable'
        ExecutionPerformed = $true
        OutputArtifactPath = Join-Path $TestDrive 'disable-evidence.json'
    }
}

function New-TestRollbackDrillPackage {
    [pscustomobject]@{
        RollbackPackageId = 'RB-DRILL-001'
        Ready = $true
        RollbackAction = 'ReEnableServicePrincipal'
        RollbackExecuted = $false
    }
}

function New-TestObservation {
    [pscustomobject]@{
        ObservationWindowMinutes = 60
        MonitoringOwner = 'lab-ops'
        RollbackContact = 'lab-ops'
        FailureCriteria = 'App outage detected'
        RollbackTriggerCriteria = @('Critical outage')
    }
}

Describe 'Rev4.19 Rollback Execution Readiness Package' {
    BeforeAll {
        $modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path
        Import-Module $modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev419'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:DefaultTarget = [pscustomobject]@{
            ObjectId = '11111111-1111-1111-1111-111111111111'
            DisplayName = 'Lab Reversible NHI'
            AppId = '22222222-2222-2222-2222-222222222222'
            ObjectType = 'ServicePrincipal'
            TargetType = 'ServicePrincipal'
            Classification = 'CustomerOwned'
            Environment = 'Lab'
            TenantScope = 'Lab'
            IsLabTarget = $true
            LabTargetMarker = $true
            SuppressCustomerRemediation = $false
            EvidenceOnly = $false
            InformationOnly = $false
            RemediationMode = 'ManualApprovalRequired'
        }
        $script:DefaultOriginalDisableEvidence = [pscustomobject]@{
            PlannedAction = 'ReversibleDisable'
            ExecutionPerformed = $true
            OutputArtifactPath = Join-Path $TestDrive 'disable-evidence.json'
        }
        $script:DefaultSnapshot = [pscustomobject]@{
            SnapshotId = 'SNAP-RB-001'
            SnapshotPath = Join-Path $TestDrive 'rb-snapshot.json'
            CapturedUtc = ([datetime]::UtcNow.ToString('o'))
            PreActionEnabledState = $true
            AccountEnabled = $true
            BaselineHash = 'snapshot-hash'
            EvidenceSourcePath = Join-Path $TestDrive 'rb-snapshot.evidence.json'
        }
        $script:DefaultObservation = [pscustomobject]@{
            ObservationWindowMinutes = 60
            MonitoringOwner = 'lab-ops'
            RollbackContact = 'lab-ops'
            FailureCriteria = 'App outage detected'
            RollbackTriggerCriteria = @('Critical outage')
        }
        $script:DefaultRollbackDrill = [pscustomobject]@{
            RollbackPackageId = 'RB-DRILL-001'
            Ready = $true
            RollbackAction = 'ReEnableServicePrincipal'
            RollbackExecuted = $false
        }
        $script:MicrosoftTarget = [pscustomobject]@{
            ObjectId = '11111111-1111-1111-1111-111111111111'
            DisplayName = 'Lab Reversible NHI'
            AppId = '22222222-2222-2222-2222-222222222222'
            ObjectType = 'ServicePrincipal'
            TargetType = 'ServicePrincipal'
            Classification = 'MicrosoftPlatform'
            Environment = 'Lab'
            TenantScope = 'Lab'
            IsLabTarget = $true
            LabTargetMarker = $true
            SuppressCustomerRemediation = $false
            EvidenceOnly = $false
            InformationOnly = $false
            RemediationMode = 'ManualApprovalRequired'
        }
        $script:SuppressedTarget = [pscustomobject]@{
            ObjectId = '11111111-1111-1111-1111-111111111111'
            DisplayName = 'Lab Reversible NHI'
            AppId = '22222222-2222-2222-2222-222222222222'
            ObjectType = 'ServicePrincipal'
            TargetType = 'ServicePrincipal'
            Classification = 'CustomerOwned'
            Environment = 'Lab'
            TenantScope = 'Lab'
            IsLabTarget = $true
            LabTargetMarker = $true
            SuppressCustomerRemediation = $true
            EvidenceOnly = $false
            InformationOnly = $false
            RemediationMode = 'ManualApprovalRequired'
        }
        $script:EvidenceOnlyTarget = [pscustomobject]@{
            ObjectId = '11111111-1111-1111-1111-111111111111'
            DisplayName = 'Lab Reversible NHI'
            AppId = '22222222-2222-2222-2222-222222222222'
            ObjectType = 'ServicePrincipal'
            TargetType = 'ServicePrincipal'
            Classification = 'CustomerOwned'
            Environment = 'Lab'
            TenantScope = 'Lab'
            IsLabTarget = $true
            LabTargetMarker = $true
            SuppressCustomerRemediation = $false
            EvidenceOnly = $true
            InformationOnly = $false
            RemediationMode = 'ManualApprovalRequired'
        }
    }

    function global:Invoke-Package {
        param(
            [object]$Target = $null,
            [object]$OriginalDisableEvidence = $null,
            [object]$PreActionSnapshot = $null,
            [object]$PostDisableObservation = $null,
            [object]$RollbackDrillPackage = $null,
            [object]$RollbackTrigger = $null,
            [string[]]$RequestedOperations = @(),
            [string]$RunId = 'REV419-001'
        )

        if ($null -eq $Target) { $Target = $script:DefaultTarget }
        if ($null -eq $OriginalDisableEvidence) { $OriginalDisableEvidence = $script:DefaultOriginalDisableEvidence }
        if ($null -eq $PreActionSnapshot) { $PreActionSnapshot = $script:DefaultSnapshot }
        if ($null -eq $PostDisableObservation) { $PostDisableObservation = $script:DefaultObservation }
        if ($null -eq $RollbackDrillPackage) { $RollbackDrillPackage = $script:DefaultRollbackDrill }
        if ($null -eq $RollbackTrigger) { $RollbackTrigger = @('Critical outage') }

        New-NhiRun4CRollbackExecutionReadinessPackage `
            -Target @($Target) `
            -OriginalDisableEvidence $OriginalDisableEvidence `
            -PreActionSnapshot $PreActionSnapshot `
            -PostDisableObservation $PostDisableObservation `
            -RollbackDrillPackage $RollbackDrillPackage `
            -RollbackTrigger $RollbackTrigger `
            -RequestedOperations $RequestedOperations `
            -RunId $RunId `
            -OutputPath $script:OutputPath
    }

    It 'Complete approved dev/test rollback inputs return Ready with RequiredHumanDecision=true and HumanDecisionCaptured=false' {
        $result = Invoke-Package
        $result.RollbackReadiness | Should -Be 'Ready'
        $result.ReadyForRollbackExecution | Should -BeTrue
        $result.RequiredHumanDecision | Should -BeTrue
        $result.HumanDecisionCaptured | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = Invoke-Package -RunId 'REV419-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).RollbackReadinessPackageId | Should -Match '^REV419-'
    }

    It 'Package states TenantWritePerformed=false, DisablePerformed=false, RollbackPerformed=false, FinalDeleteAllowed=false' {
        $result = Invoke-Package
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
    }

    It 'Missing original disable evidence returns NotReady' {
        (New-NhiRun4CRollbackExecutionReadinessPackage `
            -Target @($script:DefaultTarget) `
            -OriginalDisableEvidence $null `
            -PreActionSnapshot $script:DefaultSnapshot `
            -PostDisableObservation $script:DefaultObservation `
            -RollbackDrillPackage $script:DefaultRollbackDrill `
            -RollbackTrigger @('Critical outage') `
            -RequestedOperations @() `
            -RunId 'REV419-MISSING-ORIGINAL' `
            -OutputPath $script:OutputPath).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Missing pre-action snapshot returns NotReady' {
        (New-NhiRun4CRollbackExecutionReadinessPackage `
            -Target @($script:DefaultTarget) `
            -OriginalDisableEvidence $script:DefaultOriginalDisableEvidence `
            -PreActionSnapshot $null `
            -PostDisableObservation $script:DefaultObservation `
            -RollbackDrillPackage $script:DefaultRollbackDrill `
            -RollbackTrigger @('Critical outage') `
            -RequestedOperations @() `
            -RunId 'REV419-MISSING-SNAPSHOT' `
            -OutputPath $script:OutputPath).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Missing rollback drill package returns NotReady' {
        (New-NhiRun4CRollbackExecutionReadinessPackage `
            -Target @($script:DefaultTarget) `
            -OriginalDisableEvidence $script:DefaultOriginalDisableEvidence `
            -PreActionSnapshot $script:DefaultSnapshot `
            -PostDisableObservation $script:DefaultObservation `
            -RollbackDrillPackage $null `
            -RollbackTrigger @('Critical outage') `
            -RequestedOperations @() `
            -RunId 'REV419-MISSING-RB' `
            -OutputPath $script:OutputPath).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Missing observation failure or manual trigger returns NotReady' {
        (Invoke-Package -RollbackTrigger @()).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Non-reenable rollback action returns NotReady' {
        $rollback = [pscustomobject]@{
            RollbackPackageId = 'RB-DRILL-002'
            Ready = $true
            RollbackAction = 'Delete'
            RollbackExecuted = $false
        }
        $rollback.RollbackAction = 'Delete'
        (Invoke-Package -RollbackDrillPackage $rollback).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'MicrosoftPlatform target is blocked' {
        (Invoke-Package -Target $script:MicrosoftTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Suppressed target is blocked' {
        (Invoke-Package -Target $script:SuppressedTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'EvidenceOnly target is blocked' {
        (Invoke-Package -Target $script:EvidenceOnlyTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Delete request returns NotReady' {
        (Invoke-Package -RequestedOperations @('Delete')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Remove request returns NotReady' {
        (Invoke-Package -RequestedOperations @('Remove')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Recreate request returns NotReady' {
        (Invoke-Package -RequestedOperations @('Recreate')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Grant cleanup request returns NotReady' {
        (Invoke-Package -RequestedOperations @('GrantCleanup')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Credential change request returns NotReady' {
        (Invoke-Package -RequestedOperations @('CredentialChange')).RollbackReadiness | Should -Be 'NotReady'
    }
}
