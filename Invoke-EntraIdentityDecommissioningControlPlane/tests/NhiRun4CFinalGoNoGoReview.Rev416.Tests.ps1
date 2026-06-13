$ErrorActionPreference = 'Stop'

$script:modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path

function Write-TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $json = $InputObject | ConvertTo-Json -Depth 30
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    $json | Set-Content -LiteralPath $Path -Encoding utf8
}

function New-TestTarget {
    param(
        [string]$DisplayName = 'Lab Reversible NHI',
        [string]$Classification = 'CustomerOwned',
        [string]$Environment = 'Lab',
        [bool]$IsLabTarget = $true,
        [bool]$SuppressCustomerRemediation = $false,
        [bool]$EvidenceOnly = $false,
        [bool]$InformationOnly = $false
    )

    [pscustomobject]@{
        ObjectId = '11111111-1111-1111-1111-111111111111'
        DisplayName = $DisplayName
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

function New-TestApprovalManifest {
    param(
        [datetime]$ExpiresUtc = ([datetime]::UtcNow.AddDays(1))
    )

    [pscustomobject]@{
        ApprovalId = 'APR-RUN4C-001'
        TargetObjectId = '11111111-1111-1111-1111-111111111111'
        TargetDisplayName = 'Lab Reversible NHI'
        TargetType = 'ServicePrincipal'
        ApprovedAction = 'ReversibleDisable'
        ApprovedBy = 'lab-approver'
        ApprovalReason = 'Run #4C review'
        ApprovalExpiresUtc = $ExpiresUtc.ToString('o')
        ApprovalManifestHash = 'manifest-hash'
    }
}

function New-TestSnapshot {
    [pscustomobject]@{
        SnapshotId = 'SNAP-RUN4C-001'
        SnapshotPath = Join-Path $TestDrive 'snapshot.json'
        CapturedUtc = ([datetime]::UtcNow.ToString('o'))
        PreActionEnabledState = $true
        AccountEnabled = $true
        PreActionCredentialCount = 1
        PreActionOwnerCount = 1
        PreActionAppRoleAssignmentsCount = 1
        PreActionOAuthGrantCount = 1
        TargetObjectId = '11111111-1111-1111-1111-111111111111'
        TargetDisplayName = 'Lab Reversible NHI'
        TargetAppId = '22222222-2222-2222-2222-222222222222'
        BaselineHash = 'snapshot-hash'
        EvidenceSourcePath = Join-Path $TestDrive 'snapshot.evidence.json'
    }
}

function New-TestReadinessVerdict {
    param([bool]$Ready = $true)

    [pscustomobject]@{
        Ready = $Ready
        Blockers = @()
        Warnings = @()
        AllowedAction = 'ReversibleDisable'
        ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
        TenantWritePlanned = $true
        FinalDeleteAllowed = $false
        ReadinessReady = $Ready
    }
}

function New-TestDryRunPackage {
    [pscustomobject]@{
        PackageId = 'DRY-RUN-001'
        Ready = $true
        TenantWritePlanned = $false
        ExecutionPerformed = $false
        FinalDeleteAllowed = $false
        PlannedAction = 'ReversibleDisable'
        ProhibitedOperations = @('final delete', 'service principal removal', 'application removal', 'grant cleanup', 'metadata cleanup', 'credential deletion')
    }
}

function New-TestRollbackPackage {
    [pscustomobject]@{
        RollbackPackageId = 'RB-001'
        RollbackExecuted = $false
        RollbackAction = 'ReEnableServicePrincipal'
        WhatIf = $true
        HumanApprovalRequired = $true
        Ready = $true
    }
}

function New-TestObservationPlan {
    [pscustomobject]@{
        ObservationWindowMinutes = 60
        MonitoringOwner = 'lab-ops'
        RollbackContact = 'lab-ops'
        ObservationStartUtc = ([datetime]::UtcNow.ToString('o'))
        ObservationEndUtc = ([datetime]::UtcNow.AddMinutes(60).ToString('o'))
        SuccessCriteria = 'No outage.'
        FailureCriteria = 'Unexpected mutation.'
        RollbackTriggerCriteria = @('Critical outage')
    }
}

Describe 'Rev4.16 Final Go/No-Go Review Package' {
    BeforeAll {
        $modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path
        Import-Module $modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev416'
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
        $script:DefaultApproval = [pscustomobject]@{
            ApprovalId = 'APR-RUN4C-001'
            TargetObjectId = '11111111-1111-1111-1111-111111111111'
            TargetDisplayName = 'Lab Reversible NHI'
            TargetType = 'ServicePrincipal'
            ApprovedAction = 'ReversibleDisable'
            ApprovedBy = 'lab-approver'
            ApprovalReason = 'Run #4C review'
            ApprovalExpiresUtc = ([datetime]::UtcNow.AddDays(1).ToString('o'))
            ApprovalManifestHash = 'manifest-hash'
        }
        $script:DefaultSnapshot = [pscustomobject]@{
            SnapshotId = 'SNAP-RUN4C-001'
            SnapshotPath = Join-Path $TestDrive 'snapshot.json'
            CapturedUtc = ([datetime]::UtcNow.ToString('o'))
            PreActionEnabledState = $true
            AccountEnabled = $true
            PreActionCredentialCount = 1
            PreActionOwnerCount = 1
            PreActionAppRoleAssignmentsCount = 1
            PreActionOAuthGrantCount = 1
            TargetObjectId = '11111111-1111-1111-1111-111111111111'
            TargetDisplayName = 'Lab Reversible NHI'
            TargetAppId = '22222222-2222-2222-2222-222222222222'
            BaselineHash = 'snapshot-hash'
            EvidenceSourcePath = Join-Path $TestDrive 'snapshot.evidence.json'
        }
        $script:DefaultReadiness = [pscustomobject]@{
            Ready = $true
            Blockers = @()
            Warnings = @()
            AllowedAction = 'ReversibleDisable'
            ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
            TenantWritePlanned = $true
            FinalDeleteAllowed = $false
            ReadinessReady = $true
        }
        $script:DefaultDryRun = [pscustomobject]@{
            PackageId = 'DRY-RUN-001'
            Ready = $true
            TenantWritePlanned = $false
            ExecutionPerformed = $false
            FinalDeleteAllowed = $false
            PlannedAction = 'ReversibleDisable'
            ProhibitedOperations = @('final delete', 'service principal removal', 'application removal', 'grant cleanup', 'metadata cleanup', 'credential deletion')
        }
        $script:DefaultRollback = [pscustomobject]@{
            RollbackPackageId = 'RB-001'
            RollbackExecuted = $false
            RollbackAction = 'ReEnableServicePrincipal'
            WhatIf = $true
            HumanApprovalRequired = $true
            Ready = $true
        }
        $script:DefaultObservation = [pscustomobject]@{
            ObservationWindowMinutes = 60
            MonitoringOwner = 'lab-ops'
            RollbackContact = 'lab-ops'
            ObservationStartUtc = ([datetime]::UtcNow.ToString('o'))
            ObservationEndUtc = ([datetime]::UtcNow.AddMinutes(60).ToString('o'))
            SuccessCriteria = 'No outage.'
            FailureCriteria = 'Unexpected mutation.'
            RollbackTriggerCriteria = @('Critical outage')
        }
        $script:Checklist = [pscustomobject]@{
            ConfirmLabOnly = $true
            ConfirmNotMicrosoftPlatform = $true
            ConfirmNotExternalVendorPlatform = $true
            ConfirmNotSuppressed = $true
            ConfirmNotEvidenceOnly = $true
            ConfirmCurrentApproval = $true
            ConfirmSnapshotExists = $true
            ConfirmRollbackPackageExists = $true
            ConfirmObservationPlanExists = $true
        }
        ($script:DefaultApproval | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath (Join-Path $script:OutputPath 'approval.json') -Encoding utf8
    }

        function global:Invoke-ReviewPackage {
            param(
                [object]$Target = $null,
                [object]$ApprovalManifest = $null,
                [object]$Snapshot = $null,
                [object]$ReadinessVerdict = $null,
                [object]$DryRunPackage = $null,
                [object]$RollbackPackage = $null,
                [object]$ObservationPlan = $null,
                [object]$OperatorChecklist = $script:Checklist,
                [string[]]$RequestedOperations = @('ReversibleDisable'),
                [string]$RunId = 'REV416-001'
            )

            if ($null -eq $Target) { $Target = $script:DefaultTarget }
            if ($null -eq $ApprovalManifest) { $ApprovalManifest = $script:DefaultApproval }
            if ($null -eq $Snapshot) { $Snapshot = $script:DefaultSnapshot }
            if ($null -eq $ReadinessVerdict) { $ReadinessVerdict = $script:DefaultReadiness }
            if ($null -eq $DryRunPackage) { $DryRunPackage = $script:DefaultDryRun }
            if ($null -eq $RollbackPackage) { $RollbackPackage = $script:DefaultRollback }
            if ($null -eq $ObservationPlan) { $ObservationPlan = $script:DefaultObservation }

            $approvalPath = Join-Path $script:OutputPath "$RunId.approval.json"
            ($ApprovalManifest | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $approvalPath -Encoding utf8

            New-NhiRun4CFinalGoNoGoReviewPackage `
                -Target @($Target) `
                -ApprovalManifest $ApprovalManifest `
                -ApprovalManifestPath $approvalPath `
                -Snapshot $Snapshot `
                -ReadinessVerdict $ReadinessVerdict `
                -DryRunPackage $DryRunPackage `
                -RollbackPackage $RollbackPackage `
                -ObservationPlan $ObservationPlan `
                -OperatorChecklist $OperatorChecklist `
                -RequestedOperations $RequestedOperations `
                -RunId $RunId `
                -OutputPath $script:OutputPath
        }

    It 'Complete approved dev/test lab target returns Go with RequiredHumanDecision=true and HumanDecisionCaptured=false' {
        $result = Invoke-ReviewPackage -Target $script:LabTarget

        $result.GoNoGo | Should -Be 'Go'
        $result.RequiredHumanDecision | Should -BeTrue
        $result.HumanDecisionCaptured | Should -BeFalse
        $result.ReadyForControlledDevTestDisable | Should -BeTrue
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'writes JSON artifact locally' {
        $result = Invoke-ReviewPackage -Target $script:LabTarget -RunId 'REV416-ARTIFACT'
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).ReviewPackageId | Should -Match '^REV416-'
    }

    It 'Missing lab/dev-test marker returns NoGo' {
        (New-NhiRun4CFinalGoNoGoReviewPackage `
            -Target @($script:ProdTarget) `
            -ApprovalManifest $script:DefaultApproval `
            -ApprovalManifestPath (Join-Path $script:OutputPath 'prod.approval.json') `
            -Snapshot $script:DefaultSnapshot `
            -ReadinessVerdict $script:DefaultReadiness `
            -DryRunPackage $script:DefaultDryRun `
            -RollbackPackage $script:DefaultRollback `
            -ObservationPlan $script:DefaultObservation `
            -OperatorChecklist $script:Checklist `
            -RequestedOperations @('ReversibleDisable') `
            -RunId 'REV416-PROD' `
            -OutputPath $script:OutputPath).GoNoGo | Should -Be 'NoGo'
    }

    It 'More than one target returns NoGo' {
        $result = Invoke-ReviewPackage -Target @($script:LabTarget, $script:LabTarget)
        $result.GoNoGo | Should -Be 'NoGo'
    }

    It 'Missing approval manifest returns NoGo' {
        (New-NhiRun4CFinalGoNoGoReviewPackage `
            -Target @($script:LabTarget) `
            -ApprovalManifest $null `
            -ApprovalManifestPath (Join-Path $script:OutputPath 'missing-approval.json') `
            -Snapshot $script:DefaultSnapshot `
            -ReadinessVerdict $script:DefaultReadiness `
            -DryRunPackage $script:DefaultDryRun `
            -RollbackPackage $script:DefaultRollback `
            -ObservationPlan $script:DefaultObservation `
            -OperatorChecklist $script:Checklist `
            -RequestedOperations @('ReversibleDisable') `
            -RunId 'REV416-MISSING-APPROVAL' `
            -OutputPath $script:OutputPath).GoNoGo | Should -Be 'NoGo'
    }

    It 'Expired approval returns NoGo' {
        (New-NhiRun4CFinalGoNoGoReviewPackage `
            -Target @($script:LabTarget) `
            -ApprovalManifest $script:ApprovalExpired `
            -ApprovalManifestPath (Join-Path $script:OutputPath 'expired-approval.json') `
            -Snapshot $script:DefaultSnapshot `
            -ReadinessVerdict $script:DefaultReadiness `
            -DryRunPackage $script:DefaultDryRun `
            -RollbackPackage $script:DefaultRollback `
            -ObservationPlan $script:DefaultObservation `
            -OperatorChecklist $script:Checklist `
            -RequestedOperations @('ReversibleDisable') `
            -RunId 'REV416-EXPIRED' `
            -OutputPath $script:OutputPath).GoNoGo | Should -Be 'NoGo'
    }

    It 'Non-reversible approved action returns NoGo' {
        $approval = $script:DefaultApproval
        $approval.ApprovedAction = 'FinalDelete'
        (Invoke-ReviewPackage -Target $script:LabTarget -ApprovalManifest $approval).GoNoGo | Should -Be 'NoGo'
    }

    It 'MicrosoftPlatform target returns NoGo' {
        (Invoke-ReviewPackage -Target $script:MicrosoftTarget).GoNoGo | Should -Be 'NoGo'
    }

    It 'ExternalVendorPlatform target returns NoGo' {
        (Invoke-ReviewPackage -Target $script:ExternalTarget).GoNoGo | Should -Be 'NoGo'
    }

    It 'SuppressCustomerRemediation=true returns NoGo' {
        (Invoke-ReviewPackage -Target $script:SuppressedTarget).GoNoGo | Should -Be 'NoGo'
    }

    It 'EvidenceOnly=true returns NoGo' {
        (Invoke-ReviewPackage -Target $script:EvidenceOnlyTarget).GoNoGo | Should -Be 'NoGo'
    }

    It 'Missing snapshot returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -Snapshot $null).GoNoGo | Should -Be 'NoGo'
    }

    It 'Missing readiness verdict returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -ReadinessVerdict $null).GoNoGo | Should -Be 'NoGo'
    }

    It 'Readiness verdict Ready=false returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -ReadinessVerdict $script:ReadinessFalse).GoNoGo | Should -Be 'NoGo'
    }

    It 'Missing dry-run package returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -DryRunPackage $null).GoNoGo | Should -Be 'NoGo'
    }

    It 'Missing rollback package returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -RollbackPackage $null).GoNoGo | Should -Be 'NoGo'
    }

    It 'Missing observation plan returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -ObservationPlan $null).GoNoGo | Should -Be 'NoGo'
    }

    It 'Requested final delete returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -RequestedOperations @('FinalDelete')).GoNoGo | Should -Be 'NoGo'
    }

    It 'Requested remove returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -RequestedOperations @('Remove')).GoNoGo | Should -Be 'NoGo'
    }

    It 'Requested grant cleanup returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -RequestedOperations @('GrantCleanup')).GoNoGo | Should -Be 'NoGo'
    }

    It 'Requested metadata cleanup returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -RequestedOperations @('MetadataCleanup')).GoNoGo | Should -Be 'NoGo'
    }

    It 'Requested credential deletion returns NoGo' {
        (Invoke-ReviewPackage -Target $script:LabTarget -RequestedOperations @('CredentialDelete')).GoNoGo | Should -Be 'NoGo'
    }

    It 'Package states TenantWritePerformed=false, DisablePerformed=false, RollbackPerformed=false, FinalDeleteAllowed=false' {
        $result = Invoke-ReviewPackage -Target $script:LabTarget
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
    }
}
