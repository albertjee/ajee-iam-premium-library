$ErrorActionPreference = 'Stop'

# M7.2 Consolidation: 12 Run4C per-revision Pester files -> 1 consolidated file.
#
# Source files (unmodified, retained on disk pending a later retirement step):
#   NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1
#   NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1
#   NhiRun4CPostDisableObservation.Rev418.Tests.ps1
#   NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1
#   NhiRun4CControlledRollbackPath.Rev420.Tests.ps1
#   NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1
#   NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1
#   NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1
#   NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1
#   NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1
#   NhiRun4CPostRollbackValidation.Rev427.Tests.ps1
#   NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1
#
# VERIFICATION FINDING on the 27 "duplicate It name" rows in the task brief:
# Every row was checked against the actual function invoked and the actual result
# property asserted in each contributing file. In ALL 27 cases, the files sharing an
# It name call a DIFFERENT underlying New-NhiRun4C*/Invoke-NhiControlledLab* function
# (this pipeline defines one such function per revision) and/or assert a DIFFERENT
# result property. Two illustrative examples:
#   - "Package writes JSON artifact locally" appears in 9 files and resolves to 9
#     different functions (LiveEvidenceCapturePackage, PostDisableObservationPackage,
#     RollbackExecutionReadinessPackage, Invoke-NhiControlledLabRollback,
#     FinalControlledDisableTestPackage, PostDisableEvidenceValidationPackage,
#     ControlledRollbackExecutionTestPackage, PostRollbackValidationPackage,
#     FinalEvidenceBundle), each asserting a different artifact-id property/regex.
#   - "Package does not execute rollback" (Rev4.25 vs Rev4.27) asserts
#     $result.RollbackPerformed in one file and $result.RollbackPerformedByThisPackage
#     in the other -- textually similar names, genuinely different properties on
#     genuinely different functions.
# Collapsing any of these to a single occurrence would silently delete real coverage of
# one pipeline stage's function. Per instructions, NONE were merged: every occurrence is
# kept, verbatim, in its own per-revision Describe block below, with a short comment on
# each occurrence past the first cross-referencing the sibling revision it shares a name
# with and the function that makes it a distinct test. See the final report for the full
# per-row breakdown.
#
# Helper-function renames (mechanical only -- zero assertion/behavior change):
# Several source files declare same-named local helper functions (New-TestTarget,
# New-TestSnapshot, Write-TestJson, New-TestPackage, etc.) with DIFFERENT signatures per
# file. Pester's discovery-then-run model means a later bare `function Name { }`
# statement in the SAME file silently overrides an earlier same-named one for every
# block's It (verified empirically before writing this file). Concatenating the 12 files
# verbatim would therefore break earlier blocks at run time. Every colliding LIVE
# (actually-called) helper below has been renamed with a Rev-number prefix (e.g.
# New-TestTarget -> New-Rev420TestTarget) and all call sites within that same block
# updated to match -- same signature, same defaults, same body, new name only. Helper
# functions confirmed to have ZERO call sites in their own original file (dead/leftover
# code in Rev4.16/4.17/4.18/4.19's New-Test*/Write-TestJson helpers) were dropped rather
# than renamed, since they contribute no behavior either way.

# =============================================================================
# Rev4.16 Final Go/No-Go Review Package
# (source: NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1)
# Dead-code helpers dropped: Write-TestJson, New-TestTarget, New-TestApprovalManifest,
# New-TestSnapshot, New-TestReadinessVerdict, New-TestDryRunPackage, New-TestRollbackPackage,
# New-TestObservationPlan, and the unused top-level $script:modulePath line -- all verified
# to have zero call sites in the source file (the Describe's own BeforeAll builds every
# fixture inline instead of calling these helpers).
# NOTE (verbatim-preserved, not a new bug): $script:LabTarget, $script:ProdTarget,
# $script:ReadinessFalse and $script:ApprovalExpired are referenced below but never
# assigned anywhere in this block (nor anywhere else in this consolidated file) -- this
# matches the original standalone file exactly (empirically confirmed: 26/26 pass
# standalone, with these resolving to $null and the wrapper's null-coalescing fallback to
# $script:DefaultTarget/$script:DefaultApproval taking over). Preserved verbatim per the
# zero-behavior-change mandate; flagged to Albert as pre-existing test debt, not fixed here.
# =============================================================================
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

    function script:Invoke-ReviewPackage {
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

    # Shares a name with 8 other revisions' "Package writes JSON artifact locally" (Rev4.17,
    # 4.19, 4.20, 4.24, 4.25, 4.26, 4.27, 4.28) -- each asserts a different artifact-id
    # property against a different New-NhiRun4C* function. This one is
    # New-NhiRun4CFinalGoNoGoReviewPackage / ReviewPackageId. Not a duplicate; kept.
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

    # Shares a name with 5 other revisions' "MicrosoftPlatform target is/returns NoGo/blocked"
    # (Rev4.17, 4.18, 4.19, 4.20, 4.22) -- each is a different function. This one is
    # New-NhiRun4CFinalGoNoGoReviewPackage. Not a duplicate; kept.
    It 'MicrosoftPlatform target returns NoGo' {
        (Invoke-ReviewPackage -Target $script:MicrosoftTarget).GoNoGo | Should -Be 'NoGo'
    }

    It 'MicrosoftPlatform boolean target with CustomerOwned classification returns NoGo' {
        $target = $script:DefaultTarget | Select-Object *
        $target | Add-Member -NotePropertyName MicrosoftPlatform -NotePropertyValue $true -Force
        $target | Add-Member -NotePropertyName Classification -NotePropertyValue 'CustomerOwned' -Force

        (Invoke-ReviewPackage -Target $target).GoNoGo | Should -Be 'NoGo'
    }

    It 'FirstPartyMicrosoftApp boolean target with CustomerOwned classification returns NoGo' {
        $target = $script:DefaultTarget | Select-Object *
        $target | Add-Member -NotePropertyName FirstPartyMicrosoftApp -NotePropertyValue $true -Force
        $target | Add-Member -NotePropertyName Classification -NotePropertyValue 'CustomerOwned' -Force

        (Invoke-ReviewPackage -Target $target).GoNoGo | Should -Be 'NoGo'
    }

    It 'InformationOnly boolean target returns NoGo even when RemediationMode is ManualApprovalRequired' {
        $target = $script:DefaultTarget | Select-Object *
        $target | Add-Member -NotePropertyName InformationOnly -NotePropertyValue $true -Force
        $target | Add-Member -NotePropertyName RemediationMode -NotePropertyValue 'ManualApprovalRequired' -Force

        (Invoke-ReviewPackage -Target $target).GoNoGo | Should -Be 'NoGo'
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

    # Shares a name with Rev4.19's version -- that one exercises
    # New-NhiRun4CRollbackExecutionReadinessPackage instead of this file's
    # New-NhiRun4CFinalGoNoGoReviewPackage. Not a duplicate; kept.
    It 'Package states TenantWritePerformed=false, DisablePerformed=false, RollbackPerformed=false, FinalDeleteAllowed=false' {
        $result = Invoke-ReviewPackage -Target $script:LabTarget
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
    }
}

# =============================================================================
# Rev4.17 Live Evidence Capture Package
# (source: NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1)
# Dead-code helpers dropped: Write-TestJson, New-Rev417TestTarget, New-Rev417TestSnapshot,
# and the unused top-level $script:modulePath line -- verified zero call sites (the
# Describe's own BeforeAll builds every fixture inline instead of calling these helpers).
# =============================================================================
Describe 'Rev4.17 Live Evidence Capture Package' {
    BeforeAll {
        $modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path
        Import-Module $modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev417'
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
        $script:DefaultSnapshot = [pscustomobject]@{
            SnapshotId = 'SNAP-rev417'
            SnapshotPath = Join-Path $TestDrive 'rev417.json'
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
            SnapshotHash = 'snapshot-hash'
            EvidenceSourcePath = Join-Path $TestDrive 'rev417.evidence.json'
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

    function script:Invoke-Rev417Package {
        param(
            [object]$Target = $null,
            [object]$Snapshot = $null,
            [string]$TenantId = 'tenant-001',
            [string[]]$RequestedOperations = @('ReversibleDisable'),
            [string]$RunId = 'REV417-001'
        )

        if ($null -eq $Target) { $Target = $script:DefaultTarget }
        if ($null -eq $Snapshot) { $Snapshot = $script:DefaultSnapshot }

        New-NhiRun4CLiveEvidenceCapturePackage `
            -Target $Target `
            -TenantId $TenantId `
            -PreActionSnapshot $Snapshot `
            -PostActionSnapshot $null `
            -RequestedOperations $RequestedOperations `
            -RunId $RunId `
            -OutputPath $script:OutputPath
    }

    It 'Complete approved dev/test target creates evidence capture package' {
        $result = Invoke-Rev417Package
        $result.EvidenceScope | Should -Be 'SingleTargetOnly'
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.WhatChanged | Should -Be 'AccountEnabled only'
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    # Shares a name with 8 other revisions -- this one is New-NhiRun4CLiveEvidenceCapturePackage
    # / EvidencePackageId. See the header note; not a duplicate, kept.
    It 'Package writes JSON artifact locally' {
        $result = Invoke-Rev417Package -RunId 'REV417-ARTIFACT'
        $artifact = Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json
        $artifact.EvidencePackageId | Should -Match '^REV417-'
    }

    It 'Package declares TenantWritePerformed=false and DisablePerformed=false' {
        $result = Invoke-Rev417Package
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
    }

    It 'Package requires pre-action snapshot' {
        $result = New-NhiRun4CLiveEvidenceCapturePackage `
            -Target $script:DefaultTarget `
            -TenantId 'tenant-001' `
            -PreActionSnapshot $null `
            -PostActionSnapshot $null `
            -RequestedOperations @('ReversibleDisable') `
            -RunId 'REV417-MISSING-SNAPSHOT' `
            -OutputPath $script:OutputPath
        $result.Ready | Should -BeFalse
        ($result.Blockers -join '; ') | Should -Match 'snapshot'
    }

    It 'Package requires execution evidence placeholders' {
        $result = Invoke-Rev417Package
        $result.ExecutionEvidenceRequired | Should -BeTrue
        $result.OperatorIdentityPlaceholder | Should -Be 'Pending'
        $result.ExecutionStartUtcPlaceholder | Should -Be 'Pending'
        $result.ExecutionEndUtcPlaceholder | Should -Be 'Pending'
    }

    It 'Package requires post-action evidence placeholders' {
        $result = Invoke-Rev417Package
        $result.AccountEnabledAfter | Should -BeNullOrEmpty
        $result.CredentialCountAfter | Should -BeNullOrEmpty
        $result.OwnerCountAfter | Should -BeNullOrEmpty
        $result.AppRoleAssignmentsCountAfter | Should -BeNullOrEmpty
        $result.OAuthGrantCountAfter | Should -BeNullOrEmpty
    }

    It 'Package states WhatChanged = AccountEnabled only' {
        (Invoke-Rev417Package).WhatChanged | Should -Be 'AccountEnabled only'
    }

    It 'Package states prohibited changes for grants, credentials, owners, metadata, service principal deletion, application deletion' {
        $result = Invoke-Rev417Package
        $result.WhatMustNotChange | Should -Contain 'grants'
        $result.WhatMustNotChange | Should -Contain 'credentials'
        $result.WhatMustNotChange | Should -Contain 'owners'
        $result.WhatMustNotChange | Should -Contain 'app metadata'
        $result.WhatMustNotChange | Should -Contain 'app object'
        $result.WhatMustNotChange | Should -Contain 'service principal deletion'
    }

    It 'Missing target returns fail-closed package or throws controlled error' {
        $threw = $false
        try {
            $result = New-NhiRun4CLiveEvidenceCapturePackage `
                -Target $null `
                -TenantId 'tenant-001' `
                -PreActionSnapshot $script:DefaultSnapshot `
                -PostActionSnapshot $null `
                -RequestedOperations @('ReversibleDisable') `
                -RunId 'REV417-MISSING-TARGET' `
                -OutputPath $script:OutputPath
        } catch {
            $threw = $true
        }

        if ($threw) {
            $threw | Should -BeTrue
        } else {
            $result.Ready | Should -BeFalse
        }
    }

    # Shares a name with 5 other revisions (Rev4.16, 4.18, 4.19, 4.20, 4.22) -- this one is
    # New-NhiRun4CLiveEvidenceCapturePackage. Not a duplicate; kept.
    It 'MicrosoftPlatform target is blocked' {
        (Invoke-Rev417Package -Target $script:MicrosoftTarget).Ready | Should -BeFalse
    }

    # Shares a name with 4 other revisions (Rev4.18, 4.19, 4.22, 4.24) -- this one is
    # New-NhiRun4CLiveEvidenceCapturePackage. Not a duplicate; kept.
    It 'Suppressed target is blocked' {
        (Invoke-Rev417Package -Target $script:SuppressedTarget).Ready | Should -BeFalse
    }

    # Shares a name with 4 other revisions (Rev4.18, 4.19, 4.22, 4.24) -- this one is
    # New-NhiRun4CLiveEvidenceCapturePackage. Not a duplicate; kept.
    It 'EvidenceOnly target is blocked' {
        (Invoke-Rev417Package -Target $script:EvidenceOnlyTarget).Ready | Should -BeFalse
    }

    # Shares a name with Rev4.20 and Rev4.24 -- this one is New-NhiRun4CLiveEvidenceCapturePackage.
    # Not a duplicate; kept.
    It 'Final delete request is blocked' {
        (Invoke-Rev417Package -RequestedOperations @('FinalDelete')).Ready | Should -BeFalse
    }

    # Shares a name with Rev4.20, 4.24, 4.26 -- this one is New-NhiRun4CLiveEvidenceCapturePackage.
    # Not a duplicate; kept.
    It 'Grant cleanup request is blocked' {
        (Invoke-Rev417Package -RequestedOperations @('GrantCleanup')).Ready | Should -BeFalse
    }

    # Shares a name with Rev4.24 -- this one is New-NhiRun4CLiveEvidenceCapturePackage
    # (property: Ready), Rev4.24 is New-NhiRun4CFinalControlledDisableTestPackage
    # (property: PackageStatus). Not a duplicate; kept.
    It 'Credential deletion request is blocked' {
        (Invoke-Rev417Package -RequestedOperations @('CredentialDelete')).Ready | Should -BeFalse
    }
}

# =============================================================================
# Rev4.18 Post-Disable Observation Package
# (source: NhiRun4CPostDisableObservation.Rev418.Tests.ps1)
# Dead-code helpers dropped: Write-TestJson, New-Rev418TestTarget, New-Rev418TestSnapshot,
# and the unused top-level $script:modulePath line -- verified zero call sites.
# =============================================================================
Describe 'Rev4.18 Post-Disable Observation Package' {
    BeforeAll {
        $modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path
        Import-Module $modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev418'
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
        $script:DefaultSnapshot = [pscustomobject]@{
            SnapshotId = 'SNAP-OBS-001'
            SnapshotPath = Join-Path $TestDrive 'obs-snapshot.json'
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
            SnapshotHash = 'snapshot-hash'
            EvidenceSourcePath = Join-Path $TestDrive 'obs-snapshot.evidence.json'
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

    function script:Invoke-Rev418Package {
        param(
            [object]$Target = $null,
            [Nullable[int]]$ObservationWindowMinutes = 60,
            [string]$MonitoringOwner = 'lab-ops',
            [string]$RollbackContact = 'lab-ops',
            [string]$EscalationContact = 'lab-escalation',
            [object]$Snapshot = $null,
            [string[]]$RequestedOperations = @('ReversibleDisable'),
            [string]$RunId = 'REV418-001'
        )

        if ($null -eq $Target) { $Target = $script:DefaultTarget }
        if ($null -eq $Snapshot) { $Snapshot = $script:DefaultSnapshot }

        New-NhiRun4CPostDisableObservationPackage `
            -Target $Target `
            -ObservationWindowMinutes $ObservationWindowMinutes `
            -MonitoringOwner $MonitoringOwner `
            -RollbackContact $RollbackContact `
            -EscalationContact $EscalationContact `
            -PreActionSnapshot $Snapshot `
            -RequestedOperations $RequestedOperations `
            -RunId $RunId `
            -OutputPath $script:OutputPath
    }

    It 'Complete approved dev/test target creates observation package' {
        $result = Invoke-Rev418Package
        $result.ObservationScope | Should -Be 'SingleTargetOnly'
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.ObservationOnly | Should -BeTrue
        $result.NoTenantMutationByObservation | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    # Shares a name with 8 other revisions -- this one is New-NhiRun4CPostDisableObservationPackage
    # / ObservationPackageId. Not a duplicate; kept.
    It 'Package writes JSON artifact locally' {
        $result = Invoke-Rev418Package -RunId 'REV418-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).ObservationPackageId | Should -Match '^REV418-'
    }

    It 'Package declares TenantWritePerformed=false, DisablePerformed=false, RollbackPerformed=false' {
        $result = Invoke-Rev418Package
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
    }

    It 'Package includes observation window' {
        $result = Invoke-Rev418Package
        $result.ObservationWindowMinutes | Should -Be 60
    }

    It 'Package includes monitoring owner' {
        (Invoke-Rev418Package).MonitoringOwner | Should -Be 'lab-ops'
    }

    It 'Package includes rollback contact' {
        (Invoke-Rev418Package).RollbackContact | Should -Be 'lab-ops'
    }

    It 'Package includes success criteria' {
        (Invoke-Rev418Package).SuccessCriteria | Should -Contain 'No unexpected app outage'
    }

    It 'Package includes failure criteria' {
        (Invoke-Rev418Package).FailureCriteria | Should -Contain 'App outage detected'
    }

    It 'Package includes rollback trigger criteria' {
        (Invoke-Rev418Package).RollbackTriggerCriteria | Should -Contain 'Critical outage'
    }

    It 'Missing observation window fails closed' {
        $result = Invoke-Rev418Package -ObservationWindowMinutes $null
        $result.Ready | Should -BeFalse
    }

    It 'Missing monitoring owner fails closed' {
        (Invoke-Rev418Package -MonitoringOwner '').Ready | Should -BeFalse
    }

    It 'Missing rollback contact fails closed' {
        (Invoke-Rev418Package -RollbackContact '').Ready | Should -BeFalse
    }

    # Shares a name with 5 other revisions -- this one is New-NhiRun4CPostDisableObservationPackage.
    # Not a duplicate; kept.
    It 'MicrosoftPlatform target is blocked' {
        (Invoke-Rev418Package -Target $script:MicrosoftTarget).Ready | Should -BeFalse
    }

    # Shares a name with 4 other revisions -- this one is New-NhiRun4CPostDisableObservationPackage.
    # Not a duplicate; kept.
    It 'Suppressed target is blocked' {
        (Invoke-Rev418Package -Target $script:SuppressedTarget).Ready | Should -BeFalse
    }

    # Shares a name with 4 other revisions -- this one is New-NhiRun4CPostDisableObservationPackage.
    # Not a duplicate; kept.
    It 'EvidenceOnly target is blocked' {
        (Invoke-Rev418Package -Target $script:EvidenceOnlyTarget).Ready | Should -BeFalse
    }

    It 'Package states observation only and no tenant mutation' {
        $result = Invoke-Rev418Package
        $result.ObservationOnly | Should -BeTrue
        $result.RollbackNotExecuted | Should -BeTrue
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.NoTenantMutationByObservation | Should -BeTrue
    }
}

# =============================================================================
# Rev4.19 Rollback Execution Readiness Package
# (source: NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1)
# Dead-code helpers dropped: Write-TestJson, New-TestTarget, New-TestSnapshot,
# New-TestOriginalDisableEvidence, New-TestRollbackDrillPackage, New-TestObservation,
# and the unused top-level $script:modulePath line -- verified zero call sites (the
# Describe's own BeforeAll/wrapper function build every fixture inline instead).
# =============================================================================
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

    function script:Invoke-Package {
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

    # Shares a name with 8 other revisions -- this one is
    # New-NhiRun4CRollbackExecutionReadinessPackage / RollbackReadinessPackageId. Not a
    # duplicate; kept.
    It 'Package writes JSON artifact locally' {
        $result = Invoke-Package -RunId 'REV419-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).RollbackReadinessPackageId | Should -Match '^REV419-'
    }

    # Shares a name with Rev4.16's version -- that one exercises
    # New-NhiRun4CFinalGoNoGoReviewPackage instead of this file's
    # New-NhiRun4CRollbackExecutionReadinessPackage. Not a duplicate; kept.
    It 'Package states TenantWritePerformed=false, DisablePerformed=false, RollbackPerformed=false, FinalDeleteAllowed=false' {
        $result = Invoke-Package
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
    }

    # Shares a name with Rev4.26's version -- that one exercises
    # New-NhiRun4CControlledRollbackExecutionTestPackage and asserts PackageStatus, this one
    # asserts RollbackReadiness on New-NhiRun4CRollbackExecutionReadinessPackage. Not a
    # duplicate; kept.
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

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage and asserts PostDisableValidationStatus
    # -eq 'Incomplete'; this one asserts RollbackReadiness -eq 'NotReady' on
    # New-NhiRun4CRollbackExecutionReadinessPackage. Not a duplicate; kept.
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

    # Shares a name with Rev4.24 and Rev4.26 -- each exercises a different
    # New-NhiRun4C*Package function. This one is New-NhiRun4CRollbackExecutionReadinessPackage.
    # Not a duplicate; kept.
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

    # Shares a name with 5 other revisions -- this one is New-NhiRun4CRollbackExecutionReadinessPackage.
    # Not a duplicate; kept.
    It 'MicrosoftPlatform target is blocked' {
        (Invoke-Package -Target $script:MicrosoftTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with 4 other revisions -- this one is New-NhiRun4CRollbackExecutionReadinessPackage.
    # Not a duplicate; kept.
    It 'Suppressed target is blocked' {
        (Invoke-Package -Target $script:SuppressedTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with 4 other revisions -- this one is New-NhiRun4CRollbackExecutionReadinessPackage.
    # Not a duplicate; kept.
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

# =============================================================================
# Rev4.20 Controlled Rollback Path
# (source: NhiRun4CControlledRollbackPath.Rev420.Tests.ps1)
# Helper functions renamed (LIVE -- actually called in this file's own BeforeAll/wrapper):
# Write-TestJson -> Write-Rev420TestJson, New-TestTarget -> New-Rev420TestTarget,
# New-TestSnapshot -> New-Rev420TestSnapshot, New-TestOriginalDisableEvidence ->
# New-Rev420TestOriginalDisableEvidence, New-TestRollbackDrillPackage ->
# New-Rev420TestRollbackDrillPackage, New-TestRollbackReadinessPackage ->
# New-Rev420TestRollbackReadinessPackage, New-TestObservation -> New-Rev420TestObservation.
# Same signatures, same defaults, same bodies -- renamed only to avoid colliding with
# other revisions' same-named-but-differently-signed helpers when concatenated into one
# file (see header note on Pester's discovery-time function scoping).
# =============================================================================
function script:Write-Rev420TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $Path -Encoding utf8
}

function script:New-Rev420TestTarget {
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

function script:New-Rev420TestSnapshot {
    [pscustomobject]@{
        SnapshotId = 'SNAP-RUN4C-ROLLBACK-001'
        SnapshotPath = Join-Path $TestDrive 'rollback-snapshot.json'
        CapturedUtc = ([datetime]::UtcNow.ToString('o'))
        BaselineHash = 'snapshot-hash'
        PreActionEnabledState = $true
        EvidenceSourcePath = Join-Path $TestDrive 'rollback-snapshot.evidence.json'
    }
}

function script:New-Rev420TestOriginalDisableEvidence {
    [pscustomobject]@{
        PlannedAction = 'ReversibleDisable'
        OutputArtifactPath = Join-Path $TestDrive 'rollback-disable-evidence.json'
    }
}

function script:New-Rev420TestRollbackDrillPackage {
    [pscustomobject]@{
        RollbackPackageId = 'RB-DRILL-001'
        Ready = $true
        RollbackAction = 'ReEnableServicePrincipal'
        OutputArtifactPath = Join-Path $TestDrive 'rollback-drill.json'
    }
}

function script:New-Rev420TestRollbackReadinessPackage {
    [pscustomobject]@{
        RollbackReadinessPackageId = 'REV419-READY-001'
        RollbackReadiness = 'Ready'
        OutputArtifactPath = Join-Path $TestDrive 'rollback-readiness.json'
    }
}

function script:New-Rev420TestObservation {
    [pscustomobject]@{
        ObservationWindowMinutes = 60
        MonitoringOwner = 'lab-ops'
        RollbackContact = 'lab-ops'
        RollbackTriggerCriteria = @('Critical outage')
        OutputArtifactPath = Join-Path $TestDrive 'rollback-observation.json'
    }
}

function script:Invoke-RollbackPreview {
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

    if (-not $PSBoundParameters.ContainsKey('Target')) { $Target = New-Rev420TestTarget }
    if (-not $PSBoundParameters.ContainsKey('OriginalDisableEvidence')) { $OriginalDisableEvidence = New-Rev420TestOriginalDisableEvidence }
    if (-not $PSBoundParameters.ContainsKey('PreActionSnapshot')) { $PreActionSnapshot = New-Rev420TestSnapshot }
    if (-not $PSBoundParameters.ContainsKey('RollbackDrillPackage')) { $RollbackDrillPackage = New-Rev420TestRollbackDrillPackage }
    if (-not $PSBoundParameters.ContainsKey('RollbackExecutionReadinessPackage')) { $RollbackExecutionReadinessPackage = New-Rev420TestRollbackReadinessPackage }
    if (-not $PSBoundParameters.ContainsKey('PostDisableObservation')) { $PostDisableObservation = New-Rev420TestObservation }

    if ($OriginalDisableEvidence -and $OriginalDisableEvidence.OutputArtifactPath) { Write-Rev420TestJson -Path $OriginalDisableEvidence.OutputArtifactPath -InputObject $OriginalDisableEvidence }
    if ($PreActionSnapshot -and $PreActionSnapshot.SnapshotPath) { Write-Rev420TestJson -Path $PreActionSnapshot.SnapshotPath -InputObject $PreActionSnapshot }
    if ($RollbackDrillPackage -and $RollbackDrillPackage.OutputArtifactPath) { Write-Rev420TestJson -Path $RollbackDrillPackage.OutputArtifactPath -InputObject $RollbackDrillPackage }
    if ($RollbackExecutionReadinessPackage -and $RollbackExecutionReadinessPackage.OutputArtifactPath) { Write-Rev420TestJson -Path $RollbackExecutionReadinessPackage.OutputArtifactPath -InputObject $RollbackExecutionReadinessPackage }
    if ($PostDisableObservation -and $PostDisableObservation.OutputArtifactPath) { Write-Rev420TestJson -Path $PostDisableObservation.OutputArtifactPath -InputObject $PostDisableObservation }

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
        $script:BlockedTarget = New-Rev420TestTarget -Classification 'MicrosoftPlatform'
        $script:ExternalTarget = New-Rev420TestTarget -Classification 'ExternalVendorPlatform'
        $script:SuppressedTarget = New-Rev420TestTarget -SuppressCustomerRemediation $true
        $script:EvidenceOnlyTarget = New-Rev420TestTarget -EvidenceOnly $true
        $script:InformationOnlyTarget = New-Rev420TestTarget -InformationOnly $true
        $script:ReadonlyReadiness = New-Rev420TestRollbackReadinessPackage
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

    # Shares a name with 8 other revisions -- this one is Invoke-NhiControlledLabRollback /
    # RollbackExecutionPackageId. Not a duplicate; kept.
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

    # Shares a name with 5 other revisions -- this one is Invoke-NhiControlledLabRollback.
    # Not a duplicate; kept.
    It 'MicrosoftPlatform target is blocked' {
        (Invoke-RollbackPreview -Target $script:BlockedTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.24 -- this one is Invoke-NhiControlledLabRollback, Rev4.24 is
    # New-NhiRun4CFinalControlledDisableTestPackage. Not a duplicate; kept.
    It 'ExternalVendorPlatform target is blocked' {
        (Invoke-RollbackPreview -Target $script:ExternalTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'SuppressCustomerRemediation=true target is blocked' {
        (Invoke-RollbackPreview -Target $script:SuppressedTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'EvidenceOnly=true target is blocked' {
        (Invoke-RollbackPreview -Target $script:EvidenceOnlyTarget).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.26 -- this one is Invoke-NhiControlledLabRollback. Not a
    # duplicate; kept.
    It 'Delete request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('Delete')).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.24 and Rev4.26 -- this one is Invoke-NhiControlledLabRollback.
    # Not a duplicate; kept.
    It 'Remove request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('Remove')).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.26 -- this one is Invoke-NhiControlledLabRollback. Not a
    # duplicate; kept.
    It 'Recreate request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('Recreate')).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.17, 4.24, 4.26 -- this one is Invoke-NhiControlledLabRollback.
    # Not a duplicate; kept.
    It 'Grant cleanup request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('GrantCleanup')).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.24 and Rev4.26 -- this one is Invoke-NhiControlledLabRollback.
    # Not a duplicate; kept.
    It 'Metadata cleanup request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('MetadataCleanup')).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.26 -- this one is Invoke-NhiControlledLabRollback. Not a
    # duplicate; kept.
    It 'Credential change request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('CredentialChange')).RollbackReadiness | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.17 and Rev4.24 -- this one is Invoke-NhiControlledLabRollback.
    # Not a duplicate; kept.
    It 'Final delete request is blocked' {
        (Invoke-RollbackPreview -RequestedOperations @('FinalDelete')).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Rollback action other than re-enable is blocked' {
        $rollback = New-Rev420TestRollbackDrillPackage
        $rollback.RollbackAction = 'Delete'
        (Invoke-RollbackPreview -RollbackDrillPackage $rollback -HumanRollbackApprovalCaptured $true).RollbackReadiness | Should -Be 'NotReady'
    }

    It 'Rollback is not executed by tests' {
        $result = Invoke-RollbackPreview
        $result.RollbackExecutionPerformed | Should -BeFalse
        $result.PlannedRollbackAction.CommandPreview | Should -Match 'Preview only'
    }
}

# =============================================================================
# Rev4.22 End-to-End Lab Rehearsal Report
# (source: NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1)
# Helper functions already uniquely named in the source file (Rev422-prefixed) -- no
# rename required; copied verbatim.
# =============================================================================
function script:Write-Rev422TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $Path -Encoding utf8
}

function script:New-Rev422TestTarget {
    param(
        [string]$Classification = 'CustomerOwned',
        [string]$Environment = 'Lab',
        [bool]$SuppressCustomerRemediation = $false,
        [bool]$EvidenceOnly = $false
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
        InformationOnly = $false
        RemediationMode = 'ManualApprovalRequired'
    }
}

function script:New-Rev422TestPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Extra
    )

    $path = Join-Path $TestDrive "$Name.json"
    $package = [ordered]@{
        OutputArtifactPath = $path
    }
    foreach ($key in $Extra.Keys) {
        $package[$key] = $Extra[$key]
    }
    [pscustomobject]$package
}

function script:Invoke-Rev422RehearsalReport {
    param(
        [object]$Target = $null,
        [object]$ApprovalManifest = $null,
        [object]$Snapshot = $null,
        [object]$ReadinessVerdict = $null,
        [object]$DryRunPackage = $null,
        [object]$RollbackDrillPackage = $null,
        [object]$ControlledDisablePackage = $null,
        [object]$FinalGoNoGoPackage = $null,
        [object]$EvidenceCapturePackage = $null,
        [object]$ObservationPackage = $null,
        [object]$RollbackReadinessPackage = $null,
        [object]$RollbackPreviewPackage = $null,
        [object]$FinalDeleteSimulationPackage = $null,
        [string]$RunId = 'REV422-001',
        [string]$MarkdownOutputPath = $null
    )

    if (-not $PSBoundParameters.ContainsKey('Target')) { $Target = New-Rev422TestTarget }
    if (-not $PSBoundParameters.ContainsKey('ApprovalManifest')) { $ApprovalManifest = New-Rev422TestPackage -Name 'approval' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('Snapshot')) { $Snapshot = New-Rev422TestPackage -Name 'snapshot' -Extra @{ SnapshotPath = (Join-Path $TestDrive 'snapshot.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('ReadinessVerdict')) { $ReadinessVerdict = New-Rev422TestPackage -Name 'readiness' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('DryRunPackage')) { $DryRunPackage = New-Rev422TestPackage -Name 'dryrun' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('RollbackDrillPackage')) { $RollbackDrillPackage = New-Rev422TestPackage -Name 'rollbackdrill' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('ControlledDisablePackage')) { $ControlledDisablePackage = New-Rev422TestPackage -Name 'disable' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('FinalGoNoGoPackage')) { $FinalGoNoGoPackage = New-Rev422TestPackage -Name 'gono' -Extra @{ GoNoGo = 'Go' } }
    if (-not $PSBoundParameters.ContainsKey('EvidenceCapturePackage')) { $EvidenceCapturePackage = New-Rev422TestPackage -Name 'evidence' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('ObservationPackage')) { $ObservationPackage = New-Rev422TestPackage -Name 'observation' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('RollbackReadinessPackage')) { $RollbackReadinessPackage = New-Rev422TestPackage -Name 'rollbackreadiness' -Extra @{ RollbackReadiness = 'Ready' } }
    if (-not $PSBoundParameters.ContainsKey('RollbackPreviewPackage')) { $RollbackPreviewPackage = New-Rev422TestPackage -Name 'rollbackpreview' -Extra @{ RollbackReadiness = 'Ready' } }
    if (-not $PSBoundParameters.ContainsKey('FinalDeleteSimulationPackage')) { $FinalDeleteSimulationPackage = New-Rev422TestPackage -Name 'finaldelete' -Extra @{ FinalDeleteEligibility = 'Eligible' } }

    foreach ($pkg in @($ApprovalManifest, $Snapshot, $ReadinessVerdict, $DryRunPackage, $RollbackDrillPackage, $ControlledDisablePackage, $FinalGoNoGoPackage, $EvidenceCapturePackage, $ObservationPackage, $RollbackReadinessPackage, $RollbackPreviewPackage, $FinalDeleteSimulationPackage)) {
        if ($null -eq $pkg -or [string]::IsNullOrWhiteSpace($pkg.OutputArtifactPath)) {
            continue
        }

        Write-Rev422TestJson -Path $pkg.OutputArtifactPath -InputObject $pkg
    }

    New-NhiRun4CEndToEndLabRehearsalReport `
        -Target @($Target) `
        -ApprovalManifest $ApprovalManifest `
        -Snapshot $Snapshot `
        -ReadinessVerdict $ReadinessVerdict `
        -DryRunPackage $DryRunPackage `
        -RollbackDrillPackage $RollbackDrillPackage `
        -ControlledDisablePackage $ControlledDisablePackage `
        -FinalGoNoGoPackage $FinalGoNoGoPackage `
        -EvidenceCapturePackage $EvidenceCapturePackage `
        -ObservationPackage $ObservationPackage `
        -RollbackReadinessPackage $RollbackReadinessPackage `
        -RollbackPreviewPackage $RollbackPreviewPackage `
        -FinalDeleteSimulationPackage $FinalDeleteSimulationPackage `
        -RunId $RunId `
        -OutputPath $script:OutputPath `
        -MarkdownOutputPath $MarkdownOutputPath
}

Describe 'Rev4.22 End-to-End Lab Rehearsal Report' {
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
        $script:OutputPath = Join-Path $TestDrive 'rev422'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:MarkdownPath = Join-Path $TestDrive 'rev422-report.md'
        $script:BlockedMicrosoft = New-Rev422TestTarget -Classification 'MicrosoftPlatform'
        $script:BlockedSuppressed = New-Rev422TestTarget -SuppressCustomerRemediation $true
        $script:BlockedEvidenceOnly = New-Rev422TestTarget -EvidenceOnly $true
    }

    It 'Complete artifact chain generates rehearsal report' {
        $result = Invoke-Rev422RehearsalReport -MarkdownOutputPath $script:MarkdownPath

        $result.RehearsalStatus | Should -Be 'Complete'
        $result.ReadyForFinalControlledDevTestDisable | Should -BeTrue
        $result.RequiredHumanDecision | Should -BeTrue
        $result.HumanDecisionCaptured | Should -BeFalse
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.DeletePerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.OperatorChecklistSummary.PassedCount | Should -Be 11
        $result.OperatorChecklistSummary.FailedCount | Should -Be 0
        $result.OperatorChecklistSummary.PendingCount | Should -Be 0
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $result.MarkdownArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:MarkdownPath | Should -BeTrue
    }

    It 'Report writes JSON artifact locally' {
        $result = Invoke-Rev422RehearsalReport -RunId 'REV422-ARTIFACT'
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).ReportId | Should -Match '^REV422-'
    }

    It 'Optional Markdown artifact writes if implemented' {
        $result = Invoke-Rev422RehearsalReport -RunId 'REV422-MD' -MarkdownOutputPath $script:MarkdownPath
        Test-Path -LiteralPath $result.MarkdownArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:MarkdownPath | Should -BeTrue
    }

    It 'Report states TenantWritePerformed=false' {
        (Invoke-Rev422RehearsalReport).TenantWritePerformed | Should -BeFalse
    }

    It 'Report states DisablePerformed=false' {
        (Invoke-Rev422RehearsalReport).DisablePerformed | Should -BeFalse
    }

    It 'Report states RollbackPerformed=false' {
        (Invoke-Rev422RehearsalReport).RollbackPerformed | Should -BeFalse
    }

    It 'Report states DeletePerformed=false' {
        (Invoke-Rev422RehearsalReport).DeletePerformed | Should -BeFalse
    }

    It 'Report states FinalDeleteAllowed=false' {
        (Invoke-Rev422RehearsalReport).FinalDeleteAllowed | Should -BeFalse
    }

    It 'Missing readiness package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -ReadinessVerdict $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing dry-run package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -DryRunPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing rollback drill package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -RollbackDrillPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing go/no-go package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -FinalGoNoGoPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing evidence capture package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -EvidenceCapturePackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing observation package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -ObservationPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing rollback readiness package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -RollbackReadinessPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing rollback preview package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -RollbackPreviewPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing final delete simulation package makes report Incomplete' {
        (Invoke-Rev422RehearsalReport -FinalDeleteSimulationPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    # Shares a name with 4 other revisions -- this one is New-NhiRun4CEndToEndLabRehearsalReport.
    # Not a duplicate; kept.
    It 'MicrosoftPlatform target is blocked' {
        (Invoke-Rev422RehearsalReport -Target $script:BlockedMicrosoft).RehearsalStatus | Should -Be 'Incomplete'
    }

    # Shares a name with 4 other revisions -- this one is New-NhiRun4CEndToEndLabRehearsalReport.
    # Not a duplicate; kept.
    It 'Suppressed target is blocked' {
        (Invoke-Rev422RehearsalReport -Target $script:BlockedSuppressed).RehearsalStatus | Should -Be 'Incomplete'
    }

    # Shares a name with 4 other revisions -- this one is New-NhiRun4CEndToEndLabRehearsalReport.
    # Not a duplicate; kept.
    It 'EvidenceOnly target is blocked' {
        (Invoke-Rev422RehearsalReport -Target $script:BlockedEvidenceOnly).RehearsalStatus | Should -Be 'Incomplete'
    }
}

# =============================================================================
# Rev4.23 Consultant-Ready Operating Guide / Client-Safe Narrative
# (source: NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1)
# Helper function renamed (LIVE -- called 19 times below): New-TestTarget ->
# New-Rev423TestTarget. Same body (fixed CustomerOwned/Lab target, no params), renamed
# only to avoid colliding with other revisions' differently-signed same-named helper.
# =============================================================================
function script:New-Rev423TestTarget {
    [pscustomobject]@{
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
}

Describe 'Rev4.23 Consultant-Ready Operating Guide / Client-Safe Narrative' {
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
        $script:OutputPath = Join-Path $TestDrive 'rev423'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:JsonIndexPath = Join-Path $TestDrive 'rev423-guide-index.json'
    }

    It 'Guide writes Markdown artifact locally' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath -JsonIndexPath $script:JsonIndexPath
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:JsonIndexPath | Should -BeTrue
    }

    It 'Guide includes title' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Run #4C Controlled Lab NHI Reversible Disable Operating Guide'
    }

    It 'Guide includes executive summary' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Executive Summary'
    }

    It 'Guide includes scope' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match '## Scope'
    }

    It 'Guide includes roles and responsibilities' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Roles and Responsibilities'
    }

    It 'Guide includes required artifacts' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Required Artifacts'
    }

    It 'Guide includes runbook phases' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Runbook Phases'
    }

    It 'Guide includes safety boundaries' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Safety Boundaries'
    }

    It 'Guide includes client-safe narrative' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Client-Safe Narrative'
    }

    It 'Guide states no final delete' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'No final delete'
    }

    It 'Guide states no production tenant write' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'No production tenant write'
    }

    It 'Guide states one approved lab NHI only' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Exactly one approved lab NHI'
    }

    It 'Guide states rollback requires separate approval' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'separate approval'
    }

    It 'Guide states Microsoft/platform identities are evidence-only' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Microsoft/platform identities are evidence-only'
    }

    It 'Guide contains no secrets' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match '(?i)clientsecret|refresh token|access token|secret='
    }

    It 'Guide contains no tokens' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match '(?i)Bearer eyJ|access token|id token'
    }

    It 'Guide contains no live credentials' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match '(?i)live credential|client secret|password'
    }

    It 'Guide does not emit executable delete command' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Mg'
    }

    It 'Guide does not emit executable final delete command' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-Rev423TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Invoke-NhiControlledLabLiveReversibleDisable|ExecuteNhiDecommission'
    }
}

# =============================================================================
# Rev4.24 Final Controlled Dev/Test Tenant Reversible Disable Test Package
# (source: NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1)
# Helper functions already uniquely named in the source file (Rev424-prefixed) -- no
# rename required; copied verbatim.
# =============================================================================
function script:Write-Rev424TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 40) | Set-Content -LiteralPath $Path -Encoding utf8
}

function script:New-Rev424TestTarget {
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

function script:New-Rev424TestPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Extra
    )

    $package = [ordered]@{
        OutputArtifactPath = Join-Path $TestDrive "$Name.json"
    }
    foreach ($key in $Extra.Keys) {
        $package[$key] = $Extra[$key]
    }

    [pscustomobject]$package
}

function script:Invoke-Rev424Package {
    param(
        [object]$Target = $null,
        [object]$ApprovalManifest = $null,
        [object]$PreActionSnapshot = $null,
        [object]$ReadinessVerdict = $null,
        [object]$DryRunPackage = $null,
        [object]$RollbackDrillPackage = $null,
        [object]$ControlledDisablePreview = $null,
        [object]$FinalGoNoGoReviewPackage = $null,
        [object]$EvidenceCapturePackage = $null,
        [object]$ObservationPackage = $null,
        [object]$RollbackReadinessPackage = $null,
        [object]$RollbackPreviewPackage = $null,
        [object]$FinalDeleteSimulationPackage = $null,
        [object]$EndToEndRehearsalReport = $null,
        [object]$ConsultantOperatingGuide = $null,
        [bool]$HumanGoNoGoCaptured = $false,
        [string[]]$RequestedOperations = @('ReversibleDisable'),
        [string]$RunId = 'REV424-001'
    )

    if (-not $PSBoundParameters.ContainsKey('Target')) { $Target = @(New-Rev424TestTarget) }
    if (-not $PSBoundParameters.ContainsKey('ApprovalManifest')) { $ApprovalManifest = New-Rev424TestPackage -Name 'approval' -Extra @{ ApprovalManifestPath = (Join-Path $TestDrive 'approval.json'); ApprovedAction = 'ReversibleDisable'; ApprovalExpiresUtc = ([datetime]::UtcNow.AddDays(1).ToString('o')); TargetObjectId = '11111111-1111-1111-1111-111111111111' } }
    if (-not $PSBoundParameters.ContainsKey('PreActionSnapshot')) { $PreActionSnapshot = New-Rev424TestPackage -Name 'snapshot' -Extra @{ SnapshotPath = (Join-Path $TestDrive 'snapshot.json'); AccountEnabled = $true } }
    if (-not $PSBoundParameters.ContainsKey('ReadinessVerdict')) { $ReadinessVerdict = New-Rev424TestPackage -Name 'readiness' -Extra @{ Ready = $true; Readiness = 'Ready' } }
    if (-not $PSBoundParameters.ContainsKey('DryRunPackage')) { $DryRunPackage = New-Rev424TestPackage -Name 'dryrun' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'dryrun.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('RollbackDrillPackage')) { $RollbackDrillPackage = New-Rev424TestPackage -Name 'rollbackdrill' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rollbackdrill.json'); Ready = $true; RollbackAction = 'ReEnableServicePrincipal' } }
    if (-not $PSBoundParameters.ContainsKey('ControlledDisablePreview')) { $ControlledDisablePreview = New-Rev424TestPackage -Name 'disablepreview' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'disablepreview.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('FinalGoNoGoReviewPackage')) { $FinalGoNoGoReviewPackage = New-Rev424TestPackage -Name 'gono' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'gono.json'); GoNoGo = 'Go' } }
    if (-not $PSBoundParameters.ContainsKey('EvidenceCapturePackage')) { $EvidenceCapturePackage = New-Rev424TestPackage -Name 'evidence' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'evidence.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('ObservationPackage')) { $ObservationPackage = New-Rev424TestPackage -Name 'observation' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'observation.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('RollbackReadinessPackage')) { $RollbackReadinessPackage = New-Rev424TestPackage -Name 'rollbackreadiness' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rollbackreadiness.json'); RollbackReadiness = 'Ready' } }
    if (-not $PSBoundParameters.ContainsKey('RollbackPreviewPackage')) { $RollbackPreviewPackage = New-Rev424TestPackage -Name 'rollbackpreview' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rollbackpreview.json'); RollbackAction = 'ReEnableServicePrincipal' } }
    if (-not $PSBoundParameters.ContainsKey('FinalDeleteSimulationPackage')) { $FinalDeleteSimulationPackage = New-Rev424TestPackage -Name 'finaldelete' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'finaldelete.json'); FinalDeleteEligibility = 'Eligible' } }
    if (-not $PSBoundParameters.ContainsKey('EndToEndRehearsalReport')) { $EndToEndRehearsalReport = New-Rev424TestPackage -Name 'rehearsal' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rehearsal.json'); RehearsalStatus = 'Complete' } }
    if (-not $PSBoundParameters.ContainsKey('ConsultantOperatingGuide')) { $ConsultantOperatingGuide = New-Rev424TestPackage -Name 'guide' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'guide.md'); GuideId = 'REV423' } }

    New-NhiRun4CFinalControlledDisableTestPackage `
        -Target $Target `
        -ApprovalManifest $ApprovalManifest `
        -PreActionSnapshot $PreActionSnapshot `
        -ReadinessVerdict $ReadinessVerdict `
        -DryRunPackage $DryRunPackage `
        -RollbackDrillPackage $RollbackDrillPackage `
        -ControlledDisablePreview $ControlledDisablePreview `
        -FinalGoNoGoReviewPackage $FinalGoNoGoReviewPackage `
        -EvidenceCapturePackage $EvidenceCapturePackage `
        -ObservationPackage $ObservationPackage `
        -RollbackReadinessPackage $RollbackReadinessPackage `
        -RollbackPreviewPackage $RollbackPreviewPackage `
        -FinalDeleteSimulationPackage $FinalDeleteSimulationPackage `
        -EndToEndRehearsalReport $EndToEndRehearsalReport `
        -ConsultantOperatingGuide $ConsultantOperatingGuide `
        -HumanGoNoGoCaptured $HumanGoNoGoCaptured `
        -RequestedOperations $RequestedOperations `
        -RunId $RunId `
        -OutputPath $script:OutputPath
}

Describe 'Rev4.24 Final Controlled Dev/Test Tenant Reversible Disable Test Package' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev424'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:BlockedMicrosoft = New-Rev424TestTarget -Classification 'MicrosoftPlatform'
        $script:BlockedExternal = New-Rev424TestTarget -Classification 'ExternalVendorPlatform'
        $script:BlockedSuppressed = New-Rev424TestTarget -SuppressCustomerRemediation $true
        $script:BlockedEvidenceOnly = New-Rev424TestTarget -EvidenceOnly $true
        $script:BlockedInformationOnly = New-Rev424TestTarget -InformationOnly $true
    }

    It 'Complete artifact chain creates final controlled disable test package' {
        $result = Invoke-Rev424Package

        $result.PackageStatus | Should -Be 'ReadyForHumanReview'
        $result.RequiredHumanDecision | Should -BeTrue
        $result.HumanDecisionCaptured | Should -BeFalse
        $result.ReadyForControlledDevTestDisable | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    # Shares a name with 8 other revisions -- this one is
    # New-NhiRun4CFinalControlledDisableTestPackage / FinalTestPackageId. Not a duplicate;
    # kept.
    It 'Package writes JSON artifact locally' {
        $result = Invoke-Rev424Package -RunId 'REV424-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).FinalTestPackageId | Should -Match '^REV424-'
    }

    It 'Package states TenantWritePerformed=false and DisablePerformed=false' {
        $result = Invoke-Rev424Package
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
    }

    It 'Package requires exactly one target' {
        (Invoke-Rev424Package -Target @()).PackageStatus | Should -Be 'NotReady'
    }

    It 'Missing approval manifest returns NotReady' { (Invoke-Rev424Package -ApprovalManifest $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing snapshot returns NotReady' { (Invoke-Rev424Package -PreActionSnapshot $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing readiness verdict returns NotReady' { (Invoke-Rev424Package -ReadinessVerdict $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing dry-run package returns NotReady' { (Invoke-Rev424Package -DryRunPackage $null).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.19 and Rev4.26 -- each exercises a different function. This
    # one is New-NhiRun4CFinalControlledDisableTestPackage. Not a duplicate; kept.
    It 'Missing rollback drill package returns NotReady' { (Invoke-Rev424Package -RollbackDrillPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing go/no-go package returns NotReady' { (Invoke-Rev424Package -FinalGoNoGoReviewPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing evidence capture package returns NotReady' { (Invoke-Rev424Package -EvidenceCapturePackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing observation package returns NotReady' { (Invoke-Rev424Package -ObservationPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback readiness package returns NotReady' { (Invoke-Rev424Package -RollbackReadinessPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback preview package returns NotReady' { (Invoke-Rev424Package -RollbackPreviewPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing rehearsal report returns NotReady' { (Invoke-Rev424Package -EndToEndRehearsalReport $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing consultant guide returns NotReady' { (Invoke-Rev424Package -ConsultantOperatingGuide $null).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with 5 other revisions -- this one is New-NhiRun4CFinalControlledDisableTestPackage.
    # Not a duplicate; kept.
    It 'MicrosoftPlatform target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedMicrosoft)).PackageStatus | Should -Be 'NotReady' }
    It 'MicrosoftPlatform boolean target with CustomerOwned classification is blocked' {
        $target = New-Rev424TestTarget -Classification 'CustomerOwned'
        $target | Add-Member -NotePropertyName MicrosoftPlatform -NotePropertyValue $true -Force
        (Invoke-Rev424Package -Target @($target)).PackageStatus | Should -Be 'NotReady'
    }
    It 'FirstPartyMicrosoftApp boolean target with CustomerOwned classification is blocked' {
        $target = New-Rev424TestTarget -Classification 'CustomerOwned'
        $target | Add-Member -NotePropertyName FirstPartyMicrosoftApp -NotePropertyValue $true -Force
        (Invoke-Rev424Package -Target @($target)).PackageStatus | Should -Be 'NotReady'
    }
    It 'InformationOnly boolean target is blocked' {
        $target = New-Rev424TestTarget -Classification 'CustomerOwned'
        $target | Add-Member -NotePropertyName InformationOnly -NotePropertyValue $true -Force
        $target | Add-Member -NotePropertyName RemediationMode -NotePropertyValue 'ManualApprovalRequired' -Force
        (Invoke-Rev424Package -Target @($target)).PackageStatus | Should -Be 'NotReady'
    }
    # Shares a name with Rev4.20 -- this one is New-NhiRun4CFinalControlledDisableTestPackage,
    # Rev4.20 is Invoke-NhiControlledLabRollback. Not a duplicate; kept.
    It 'ExternalVendorPlatform target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedExternal)).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with 4 other revisions -- this one is New-NhiRun4CFinalControlledDisableTestPackage.
    # Not a duplicate; kept.
    It 'Suppressed target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedSuppressed)).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with 4 other revisions -- this one is New-NhiRun4CFinalControlledDisableTestPackage.
    # Not a duplicate; kept.
    It 'EvidenceOnly target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedEvidenceOnly)).PackageStatus | Should -Be 'NotReady' }
    It 'InformationOnly target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedInformationOnly)).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.17 and Rev4.20 -- this one is New-NhiRun4CFinalControlledDisableTestPackage.
    # Not a duplicate; kept.
    It 'Final delete request is blocked' { (Invoke-Rev424Package -RequestedOperations @('FinalDelete')).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.20 and Rev4.26 -- this one is New-NhiRun4CFinalControlledDisableTestPackage.
    # Not a duplicate; kept.
    It 'Remove request is blocked' { (Invoke-Rev424Package -RequestedOperations @('Remove')).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.17, 4.20, 4.26 -- this one is New-NhiRun4CFinalControlledDisableTestPackage.
    # Not a duplicate; kept.
    It 'Grant cleanup request is blocked' { (Invoke-Rev424Package -RequestedOperations @('GrantCleanup')).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.20 and Rev4.26 -- this one is New-NhiRun4CFinalControlledDisableTestPackage.
    # Not a duplicate; kept.
    It 'Metadata cleanup request is blocked' { (Invoke-Rev424Package -RequestedOperations @('MetadataCleanup')).PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.17 -- this one is New-NhiRun4CFinalControlledDisableTestPackage
    # (property: PackageStatus), Rev4.17 is New-NhiRun4CLiveEvidenceCapturePackage (property:
    # Ready). Not a duplicate; kept.
    It 'Credential deletion request is blocked' { (Invoke-Rev424Package -RequestedOperations @('CredentialDelete')).PackageStatus | Should -Be 'NotReady' }

    It 'Live command block is emitted only as a template and is marked DO NOT RUN' {
        $result = Invoke-Rev424Package
        $result.LiveCommandBlockTemplate | Should -Match 'DO NOT RUN WITHOUT FINAL HUMAN GO/NO-GO'
        $result.LiveCommandBlockTemplate | Should -Match 'Template only'
    }

    It 'Human go/no-go is required and not auto-captured' {
        $result = Invoke-Rev424Package
        $result.HumanGoNoGoRequired | Should -BeTrue
        $result.HumanGoNoGoCaptured | Should -BeFalse
    }
}

# =============================================================================
# Rev4.25 Post-Disable Evidence Validation and Observation Result Package
# (source: NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1)
# Helper functions renamed (LIVE): Write-TestJson -> Write-Rev425TestJson,
# New-TestTarget -> New-Rev425TestTarget, New-TestSnapshot -> New-Rev425TestSnapshot,
# New-TestObservationResult -> New-Rev425TestObservationResult. Same signatures, same
# defaults, same bodies -- renamed only to avoid colliding with other revisions' same-
# named-but-differently-signed helpers when concatenated into one file.
# =============================================================================
function script:Write-Rev425TestJson {
    param([string]$Path,[object]$InputObject)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 40) | Set-Content -LiteralPath $Path -Encoding utf8
}

function script:New-Rev425TestTarget {
    param(
        [string]$Classification = 'CustomerOwned',
        [string]$Environment = 'Lab',
        [bool]$SuppressCustomerRemediation = $false,
        [bool]$EvidenceOnly = $false
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
        InformationOnly = $false
        RemediationMode = 'ManualApprovalRequired'
    }
}

function script:New-Rev425TestSnapshot {
    param(
        [bool]$Enabled = $true,
        [int]$CredentialCount = 2,
        [int]$OwnerCount = 1,
        [int]$AppRoleAssignmentCount = 0,
        [int]$OAuthGrantCount = 0,
        [string]$MetadataHash = 'hash-a'
    )

    [pscustomobject]@{
        SnapshotPath = Join-Path $TestDrive ('snapshot-' + ([guid]::NewGuid().Guid) + '.json')
        AccountEnabled = $Enabled
        Enabled = $Enabled
        IsEnabled = $Enabled
        CredentialCount = $CredentialCount
        OwnerCount = $OwnerCount
        AppRoleAssignmentCount = $AppRoleAssignmentCount
        OAuthGrantCount = $OAuthGrantCount
        AppMetadataHash = $MetadataHash
        ObjectId = '11111111-1111-1111-1111-111111111111'
        AppId = '22222222-2222-2222-2222-222222222222'
    }
}

function script:New-Rev425TestObservationResult {
    param(
        [bool]$ObservationWindowCompleted = $true,
        [string]$MonitoringOwner = 'lab-ops',
        [string]$RollbackContact = 'lab-ops',
        [bool]$SuccessCriteriaMet = $true,
        [bool]$FailureCriteriaTriggered = $false,
        [bool]$RollbackTriggerDetected = $false,
        [string]$BusinessOwnerValidationResult = 'Passed'
    )

    [pscustomobject]@{
        ObservationWindowCompleted = $ObservationWindowCompleted
        MonitoringOwner = $MonitoringOwner
        RollbackContact = $RollbackContact
        SuccessCriteriaMet = $SuccessCriteriaMet
        FailureCriteriaTriggered = $FailureCriteriaTriggered
        RollbackTriggerDetected = $RollbackTriggerDetected
        BusinessOwnerValidationResult = $BusinessOwnerValidationResult
    }
}

Describe 'Rev4.25 Post-Disable Evidence Validation and Observation Result Package' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev425'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:Target = @(New-Rev425TestTarget)
        $script:Pre = New-Rev425TestSnapshot -Enabled $true
        $script:Exec = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'exec.json'); DisableObserved = $true }
        $script:Post = New-Rev425TestSnapshot -Enabled $false
        $script:Obs = New-Rev425TestObservationResult
        $script:Evidence = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'evidence.json') }
        Write-Rev425TestJson -Path $script:Pre.SnapshotPath -InputObject $script:Pre
        Write-Rev425TestJson -Path $script:Post.SnapshotPath -InputObject $script:Post
        Write-Rev425TestJson -Path $script:Exec.OutputArtifactPath -InputObject $script:Exec
        Write-Rev425TestJson -Path $script:Evidence.OutputArtifactPath -InputObject $script:Evidence
    }

    It 'Complete clean post-disable evidence returns Passed' {
        $result = New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-OK'
        $result.PostDisableValidationStatus | Should -Be 'Passed'
        $result.ReadyToRemainDisabled | Should -BeTrue
        $result.RollbackRecommended | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    # Shares a name with 8 other revisions -- this one is
    # New-NhiRun4CPostDisableEvidenceValidationPackage / PostDisableValidationPackageId.
    # Not a duplicate; kept.
    It 'Package writes JSON artifact locally' {
        $result = New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).PostDisableValidationPackageId | Should -Match '^REV425-'
    }

    It 'Package states TenantWritePerformed=false' {
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-STATE').TenantWritePerformed | Should -BeFalse
    }

    # Shares a name with Rev4.27's version -- that one exercises
    # New-NhiRun4CPostRollbackValidationPackage instead of this file's
    # New-NhiRun4CPostDisableEvidenceValidationPackage. Not a duplicate; kept.
    It 'Missing pre-action snapshot returns Incomplete' { (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $null -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-1').PostDisableValidationStatus | Should -Be 'Incomplete' }
    It 'Missing execution evidence returns Incomplete' { (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $null -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-2').PostDisableValidationStatus | Should -Be 'Incomplete' }
    It 'Missing post-action snapshot returns Incomplete' { (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $null -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-3').PostDisableValidationStatus | Should -Be 'Incomplete' }
    It 'Missing observation result returns Incomplete' { (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $null -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-4').PostDisableValidationStatus | Should -Be 'Incomplete' }

    It 'Expected account-enabled change not observed returns Failed' {
        $post = New-Rev425TestSnapshot -Enabled $true
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-5').PostDisableValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.27's version -- that one exercises
    # New-NhiRun4CPostRollbackValidationPackage. Not a duplicate; kept.
    It 'Credential count changed returns Failed' {
        $post = New-Rev425TestSnapshot -Enabled $false -CredentialCount 3
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-6').PostDisableValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.27's version -- that one exercises
    # New-NhiRun4CPostRollbackValidationPackage. Not a duplicate; kept.
    It 'Owner count changed returns Failed' {
        $post = New-Rev425TestSnapshot -Enabled $false -OwnerCount 2
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-7').PostDisableValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.27's version -- that one exercises
    # New-NhiRun4CPostRollbackValidationPackage. Not a duplicate; kept.
    It 'App role assignment count changed returns Failed' {
        $post = New-Rev425TestSnapshot -Enabled $false -AppRoleAssignmentCount 1
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-8').PostDisableValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.27's version -- that one exercises
    # New-NhiRun4CPostRollbackValidationPackage. Not a duplicate; kept.
    It 'OAuth grant count changed returns Failed' {
        $post = New-Rev425TestSnapshot -Enabled $false -OAuthGrantCount 1
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-9').PostDisableValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.27's version -- that one exercises
    # New-NhiRun4CPostRollbackValidationPackage, on the RollbackExecutionEvidence param.
    # This one is New-NhiRun4CPostDisableEvidenceValidationPackage on ExecutionEvidence.
    # Not a duplicate; kept.
    It 'Delete observed returns Failed' {
        $exec = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'exec-delete.json'); DeleteObserved = $true }
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-10').PostDisableValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.27's version -- that one exercises
    # New-NhiRun4CPostRollbackValidationPackage on RollbackExecutionEvidence. This one is
    # New-NhiRun4CPostDisableEvidenceValidationPackage on ExecutionEvidence. Not a
    # duplicate; kept.
    It 'Grant cleanup observed returns Failed' {
        $exec = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'exec-grant.json'); GrantCleanupObserved = $true }
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-11').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'Credential deletion observed returns Failed' {
        $exec = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'exec-cred.json'); CredentialDeletionObserved = $true }
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-12').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'Observation failure triggers RollbackRecommended=true' {
        $obs = New-Rev425TestObservationResult -SuccessCriteriaMet $false -FailureCriteriaTriggered $true
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-13').RollbackRecommended | Should -BeTrue
    }

    It 'Rollback trigger detected returns RollbackRecommended=true' {
        $obs = New-Rev425TestObservationResult -RollbackTriggerDetected $true
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-14').RollbackRecommended | Should -BeTrue
    }

    # Shares a name with Rev4.27's version -- that one asserts
    # $result.RollbackPerformedByThisPackage on New-NhiRun4CPostRollbackValidationPackage;
    # this one asserts $result.RollbackPerformed on
    # New-NhiRun4CPostDisableEvidenceValidationPackage -- different property, different
    # function. Definitely not a duplicate; kept.
    It 'Package does not execute rollback' {
        $result = New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-15'
        $result.RollbackPerformed | Should -BeFalse
        $result.RequiredHumanDecision | Should -BeTrue
    }

    # Shares a name with Rev4.27's version -- that one exercises
    # New-NhiRun4CPostRollbackValidationPackage. Not a duplicate; kept.
    It 'Package does not perform delete or final delete' {
        $result = New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-16'
        $result.DeletePerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
    }
}

# =============================================================================
# Rev4.26 Controlled Rollback Execution Test Package, Dev/Test Only
# (source: NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1)
# Helper functions renamed (LIVE): New-TestTarget -> New-Rev426TestTarget,
# New-TestPackage -> New-Rev426TestPackage. Same signatures, same defaults, same bodies
# -- renamed only to avoid colliding with other revisions' same-named-but-differently-
# signed helpers when concatenated into one file.
# =============================================================================
function script:New-Rev426TestTarget {
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

function script:New-Rev426TestPackage {
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
        $script:Target = @(New-Rev426TestTarget)
        $script:OriginalDisable = New-Rev426TestPackage -Name 'disable' -Extra @{ PlannedAction = 'ReversibleDisable'; OutputArtifactPath = (Join-Path $TestDrive 'disable.json') }
        $script:PostDisableValidation = New-Rev426TestPackage -Name 'postdisable' -Extra @{ PostDisableValidationStatus = 'Passed'; OutputArtifactPath = (Join-Path $TestDrive 'postdisable.json') }
        $script:Readiness = New-Rev426TestPackage -Name 'readiness' -Extra @{ RollbackReadiness = 'Ready'; OutputArtifactPath = (Join-Path $TestDrive 'readiness.json') }
        $script:Preview = New-Rev426TestPackage -Name 'preview' -Extra @{ RollbackAction = 'ReEnableServicePrincipal'; OutputArtifactPath = (Join-Path $TestDrive 'preview.json') }
        $script:Drill = New-Rev426TestPackage -Name 'drill' -Extra @{ Ready = $true; RollbackAction = 'ReEnableServicePrincipal'; OutputArtifactPath = (Join-Path $TestDrive 'drill.json') }
        $script:Snapshot = New-Rev426TestPackage -Name 'snapshot' -Extra @{ SnapshotPath = (Join-Path $TestDrive 'snapshot.json'); AccountEnabled = $true }
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

    # Shares a name with 8 other revisions -- this one is
    # New-NhiRun4CControlledRollbackExecutionTestPackage / RollbackExecutionTestPackageId.
    # Not a duplicate; kept.
    It 'Package writes JSON artifact locally' {
        $result = New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).RollbackExecutionTestPackageId | Should -Match '^REV426-'
    }

    It 'Package states RollbackPerformed=false' {
        (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-STATE').RollbackPerformed | Should -BeFalse
    }

    # Shares a name with Rev4.19's version -- that one exercises
    # New-NhiRun4CRollbackExecutionReadinessPackage. Not a duplicate; kept.
    It 'Missing original disable evidence returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $null -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-1').PackageStatus | Should -Be 'NotReady' }
    It 'Missing post-disable validation package returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $null -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-2').PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback readiness package returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $null -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-3').PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.24's version -- that one exercises
    # New-NhiRun4CFinalControlledDisableTestPackage. Not a duplicate; kept.
    It 'Missing rollback preview package returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $null -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-4').PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.19 and Rev4.24 -- each exercises a different function. This
    # one is New-NhiRun4CControlledRollbackExecutionTestPackage. Not a duplicate; kept.
    It 'Missing rollback drill package returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $null -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-5').PackageStatus | Should -Be 'NotReady' }
    It 'Missing observation trigger returns NotReady' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $null -OutputPath $script:OutputPath -RunId 'REV426-6').PackageStatus | Should -Be 'NotReady' }

    It 'Rollback action other than re-enable returns NotReady' {
        $badPreview = New-Rev426TestPackage -Name 'badpreview' -Extra @{ RollbackAction = 'Delete'; OutputArtifactPath = (Join-Path $TestDrive 'badpreview.json') }
        (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $badPreview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -OutputPath $script:OutputPath -RunId 'REV426-7').PackageStatus | Should -Be 'NotReady'
    }

    # Shares a name with Rev4.20's version -- that one exercises Invoke-NhiControlledLabRollback.
    # Not a duplicate; kept.
    It 'Delete request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('Delete') -OutputPath $script:OutputPath -RunId 'REV426-8').PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.20 and Rev4.24 -- each exercises a different function. This
    # one is New-NhiRun4CControlledRollbackExecutionTestPackage. Not a duplicate; kept.
    It 'Remove request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('Remove') -OutputPath $script:OutputPath -RunId 'REV426-9').PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.20's version -- that one exercises Invoke-NhiControlledLabRollback.
    # Not a duplicate; kept.
    It 'Recreate request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('Recreate') -OutputPath $script:OutputPath -RunId 'REV426-10').PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.17, 4.20, 4.24 -- each exercises a different function. This
    # one is New-NhiRun4CControlledRollbackExecutionTestPackage. Not a duplicate; kept.
    It 'Grant cleanup request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('GrantCleanup') -OutputPath $script:OutputPath -RunId 'REV426-11').PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.20 and Rev4.24 -- each exercises a different function. This
    # one is New-NhiRun4CControlledRollbackExecutionTestPackage. Not a duplicate; kept.
    It 'Metadata cleanup request is blocked' { (New-NhiRun4CControlledRollbackExecutionTestPackage -Target $script:Target -OriginalDisableEvidence $script:OriginalDisable -PostDisableValidationPackage $script:PostDisableValidation -RollbackReadinessPackage $script:Readiness -RollbackPreviewPackage $script:Preview -RollbackDrillPackage $script:Drill -PreActionSnapshot $script:Snapshot -ObservationFailureOrManualTrigger $script:Trigger -RequestedOperations @('MetadataCleanup') -OutputPath $script:OutputPath -RunId 'REV426-12').PackageStatus | Should -Be 'NotReady' }
    # Shares a name with Rev4.20's version -- that one exercises Invoke-NhiControlledLabRollback.
    # Not a duplicate; kept.
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

# =============================================================================
# Rev4.27 Post-Rollback Validation and Restoration Evidence Package
# (source: NhiRun4CPostRollbackValidation.Rev427.Tests.ps1)
# Helper functions renamed (LIVE): New-TestTarget -> New-Rev427TestTarget,
# New-TestSnapshot -> New-Rev427TestSnapshot. Same signatures, same defaults, same
# bodies -- renamed only to avoid colliding with other revisions' same-named-but-
# differently-signed helpers when concatenated into one file.
# =============================================================================
function script:New-Rev427TestTarget {
    [pscustomobject]@{
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
}

function script:New-Rev427TestSnapshot {
    param([bool]$Enabled = $true,[int]$CredentialCount = 2,[int]$OwnerCount = 1,[int]$AppRoleAssignmentCount = 0,[int]$OAuthGrantCount = 0,[string]$MetadataHash = 'hash-a')
    [pscustomobject]@{
        SnapshotPath = Join-Path $TestDrive ('snapshot-' + ([guid]::NewGuid().Guid) + '.json')
        AccountEnabled = $Enabled
        Enabled = $Enabled
        IsEnabled = $Enabled
        CredentialCount = $CredentialCount
        OwnerCount = $OwnerCount
        AppRoleAssignmentCount = $AppRoleAssignmentCount
        OAuthGrantCount = $OAuthGrantCount
        AppMetadataHash = $MetadataHash
        ObjectId = '11111111-1111-1111-1111-111111111111'
        AppId = '22222222-2222-2222-2222-222222222222'
    }
}

Describe 'Rev4.27 Post-Rollback Validation and Restoration Evidence Package' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev427'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:Target = @(New-Rev427TestTarget)
        $script:Pre = New-Rev427TestSnapshot -Enabled $true
        $script:Disable = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'disable.json'); AccountEnabledAfter = $false }
        $script:Rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback.json'); RecreateObserved = $false }
        $script:Post = New-Rev427TestSnapshot -Enabled $true
        $script:Obs = [pscustomobject]@{ ObservationWindowCompleted = $true; SuccessCriteriaMet = $true; FailureCriteriaTriggered = $false }
    }

    It 'Complete clean rollback evidence returns Passed' {
        $result = New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-OK'
        $result.PostRollbackValidationStatus | Should -Be 'Passed'
        $result.RestorationConfirmed | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    # Shares a name with 8 other revisions -- this one is
    # New-NhiRun4CPostRollbackValidationPackage / PostRollbackValidationPackageId. Not a
    # duplicate; kept.
    It 'Package writes JSON artifact locally' {
        $result = New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).PostRollbackValidationPackageId | Should -Match '^REV427-'
    }

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage. Not a duplicate; kept.
    It 'Missing pre-action snapshot returns Incomplete' { (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $null -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-1').PostRollbackValidationStatus | Should -Be 'Incomplete' }
    It 'Missing rollback execution evidence returns Incomplete' { (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $null -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-2').PostRollbackValidationStatus | Should -Be 'Incomplete' }
    It 'Missing post-rollback snapshot returns Incomplete' { (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $null -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-3').PostRollbackValidationStatus | Should -Be 'Incomplete' }

    It 'Enabled state not restored returns Failed' {
        $post = New-Rev427TestSnapshot -Enabled $false
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-4').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'ObjectId changed returns Failed' {
        $post = New-Rev427TestSnapshot -Enabled $true
        $post.ObjectId = '33333333-3333-3333-3333-333333333333'
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-5').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'AppId changed returns Failed' {
        $post = New-Rev427TestSnapshot -Enabled $true
        $post.AppId = '44444444-4444-4444-4444-444444444444'
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-6').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage. Not a duplicate; kept.
    It 'Credential count changed returns Failed' {
        $post = New-Rev427TestSnapshot -Enabled $true -CredentialCount 3
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-7').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage. Not a duplicate; kept.
    It 'Owner count changed returns Failed' {
        $post = New-Rev427TestSnapshot -Enabled $true -OwnerCount 2
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-8').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage. Not a duplicate; kept.
    It 'App role assignment count changed returns Failed' {
        $post = New-Rev427TestSnapshot -Enabled $true -AppRoleAssignmentCount 1
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-9').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage. Not a duplicate; kept.
    It 'OAuth grant count changed returns Failed' {
        $post = New-Rev427TestSnapshot -Enabled $true -OAuthGrantCount 1
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-10').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage on the ExecutionEvidence param.
    # This one is New-NhiRun4CPostRollbackValidationPackage on RollbackExecutionEvidence.
    # Not a duplicate; kept.
    It 'Delete observed returns Failed' {
        $rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback-delete.json'); DeleteObserved = $true }
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-11').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Recreate observed returns Failed' {
        $rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback-recreate.json'); RecreateObserved = $true }
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-12').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage on the ExecutionEvidence param.
    # This one is New-NhiRun4CPostRollbackValidationPackage on RollbackExecutionEvidence.
    # Not a duplicate; kept.
    It 'Grant cleanup observed returns Failed' {
        $rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback-grant.json'); GrantCleanupObserved = $true }
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-13').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Credential change observed returns Failed' {
        $rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback-cred.json'); CredentialChangePerformed = $true }
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-14').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    # Shares a name with Rev4.25's version -- that one asserts
    # $result.RollbackPerformed on New-NhiRun4CPostDisableEvidenceValidationPackage; this
    # one asserts $result.RollbackPerformedByThisPackage on
    # New-NhiRun4CPostRollbackValidationPackage -- different property, different
    # function. Definitely not a duplicate; kept.
    It 'Package does not execute rollback' {
        $result = New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-15'
        $result.RollbackPerformedByThisPackage | Should -BeFalse
        $result.RequiredHumanDecision | Should -BeTrue
    }

    # Shares a name with Rev4.25's version -- that one exercises
    # New-NhiRun4CPostDisableEvidenceValidationPackage. Not a duplicate; kept.
    It 'Package does not perform delete or final delete' {
        $result = New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-16'
        $result.DeletePerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
    }
}

# =============================================================================
# Rev4.28 Final End-to-End Evidence Bundle / Consultant QA Package
# (source: NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1)
# Helper functions renamed (LIVE): New-TestTarget -> New-Rev428TestTarget,
# New-TestPackage -> New-Rev428TestPackage. Same signatures, same defaults, same
# bodies -- renamed only to avoid colliding with other revisions' same-named-but-
# differently-signed helpers when concatenated into one file.
# =============================================================================
function script:New-Rev428TestTarget {
    [pscustomobject]@{
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
}

function script:New-Rev428TestPackage {
    param([string]$Name,[hashtable]$Extra)
    $package = [ordered]@{ OutputArtifactPath = Join-Path $TestDrive "$Name.json" }
    foreach ($k in $Extra.Keys) { $package[$k] = $Extra[$k] }
    [pscustomobject]$package
}

Describe 'Rev4.28 Final End-to-End Evidence Bundle / Consultant QA Package' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev428'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:Target = @(New-Rev428TestTarget)
        $script:Rev410 = New-Rev428TestPackage -Name 'rev410' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev410.json'); Platform = 'MicrosoftPlatform' }
        $script:Rev411 = New-Rev428TestPackage -Name 'rev411' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev411.json'); Ready = $true }
        $script:Rev412 = New-Rev428TestPackage -Name 'rev412' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev412.json'); Ready = $true }
        $script:Rev413 = New-Rev428TestPackage -Name 'rev413' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev413.json'); Ready = $true }
        $script:Rev414 = New-Rev428TestPackage -Name 'rev414' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev414.json'); Ready = $true }
        $script:Rev415 = New-Rev428TestPackage -Name 'rev415' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev415.json'); Ready = $true }
        $script:Rev416 = New-Rev428TestPackage -Name 'rev416' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev416.json'); GoNoGo = 'Go' }
        $script:Rev417 = New-Rev428TestPackage -Name 'rev417' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev417.json'); Ready = $true }
        $script:Rev418 = New-Rev428TestPackage -Name 'rev418' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev418.json'); Ready = $true }
        $script:Rev419 = New-Rev428TestPackage -Name 'rev419' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev419.json'); RollbackReadiness = 'Ready' }
        $script:Rev420 = New-Rev428TestPackage -Name 'rev420' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev420.json'); RollbackReadiness = 'Ready' }
        $script:Rev421 = New-Rev428TestPackage -Name 'rev421' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev421.json'); FinalDeleteEligibility = 'Eligible' }
        $script:Rev422 = New-Rev428TestPackage -Name 'rev422' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev422.json'); RehearsalStatus = 'Complete' }
        $script:Rev423 = New-Rev428TestPackage -Name 'rev423' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev423.md'); GuideId = 'REV423' }
        $script:Rev424 = New-Rev428TestPackage -Name 'rev424' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev424.json'); PackageStatus = 'ReadyForHumanReview' }
        $script:Rev425 = New-Rev428TestPackage -Name 'rev425' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev425.json'); PostDisableValidationStatus = 'Passed' }
        $script:Rev426 = New-Rev428TestPackage -Name 'rev426' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev426.json'); PackageStatus = 'ReadyForHumanRollbackReview' }
        $script:Rev427 = New-Rev428TestPackage -Name 'rev427' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev427.json'); PostRollbackValidationStatus = 'Passed' }
        $script:MarkdownPath = Join-Path $TestDrive 'rev428.md'
    }

    It 'Complete artifact chain creates final evidence bundle' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev410PlatformClassificationEvidence $script:Rev410 -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-OK' -MarkdownOutputPath $script:MarkdownPath
        $result.ChainComplete | Should -BeTrue
        $result.RequiredArtifactsPresent | Should -BeTrue
        $result.SafetyAssertionsPassed | Should -BeTrue
        $result.FinalDeleteExcluded | Should -BeTrue
        $result.ProductionTenantExcluded | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    # Shares a name with 8 other revisions -- this one is New-NhiRun4CFinalEvidenceBundle
    # / EvidenceBundleId. Not a duplicate; kept.
    It 'Package writes JSON artifact locally' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).EvidenceBundleId | Should -Match '^REV428-'
    }

    It 'Optional Markdown writes if implemented' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-MD' -MarkdownOutputPath $script:MarkdownPath
        Test-Path -LiteralPath $result.MarkdownArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:MarkdownPath | Should -BeTrue
    }

    It 'Missing Rev4.24 package makes chain incomplete' { (New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $null -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-1').ChainComplete | Should -BeFalse }
    It 'Missing Rev4.25 package makes chain incomplete' { (New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $null -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-2').ChainComplete | Should -BeFalse }
    It 'Missing Rev4.26 package makes chain incomplete' { (New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $null -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-3').ChainComplete | Should -BeFalse }
    It 'Missing Rev4.27 package makes chain incomplete' { (New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $null -OutputPath $script:OutputPath -RunId 'REV428-4').ChainComplete | Should -BeFalse }

    It 'Bundle states no tenant write by bundle' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-5'
        $result.TenantWritePerformedByBundle | Should -BeFalse
        $result.DisablePerformedByBundle | Should -BeFalse
        $result.RollbackPerformedByBundle | Should -BeFalse
        $result.DeletePerformedByBundle | Should -BeFalse
    }

    It 'Bundle contains consultant summary' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-6'
        $result.ConsultantSummary.WhatWasProven | Should -Not -BeNullOrEmpty
        $result.ConsultantSummary.WhatWasNotProven | Should -Not -BeNullOrEmpty
    }

    It 'Bundle contains no secrets or live credentials' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-7'
        $result.ContainedSecrets | Should -BeFalse
    }
}
