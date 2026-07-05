# NhiControlledDecommission.LabRehearsal.ps1
# Dot-sourced into NhiControlledDecommission.psm1 module scope. Do not import directly.
# Contains: Test-NhiControlledLabLiveReversibleDisableReadiness, New-NhiControlledLabDisableDryRunPackage, New-NhiControlledLabRollbackDrillPackage, Invoke-NhiControlledLabLiveReversibleDisable, Invoke-NhiControlledLabRollback, New-NhiFinalDeleteEligibilitySimulationPackage

function Test-NhiControlledLabLiveReversibleDisableReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [object]$Approval,

        [Parameter()]
        [string]$ApprovalManifestPath,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$RollbackEvidence,

        [Parameter()]
        [object]$ObservationMetadata,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ActionType = 'DisableOnly',

        [Parameter()]
        [string]$ExpectedSchemaVersion = $script:ControlledSchemaVersion
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    if ([string]::IsNullOrWhiteSpace([string]$TargetId)) { $reasons.Add('TargetId is required.') }
    if ([string]::IsNullOrWhiteSpace([string]$RunId)) { $reasons.Add('RunId is required.') }

    $targetValidation = Test-NhiControlledTarget -Target $Target
    if (-not $targetValidation.Passed) {
        foreach ($reason in @($targetValidation.Reasons)) {
            $reasons.Add([string]$reason)
        }
    }

    $targetLabOnly = (
        [string]$Target.Environment -eq 'Lab' -or
        [bool]$Target.IsLabTarget -eq $true -or
        [string]$Target.TenantScope -eq 'Lab'
    )
    if (-not $targetLabOnly) {
        $reasons.Add('Target must be explicitly marked as lab-only.')
    }
    if ($Target.LabValidationApproved -ne $true) {
        $reasons.Add('LabValidationApproved must be true.')
    }
    if ($TargetId -ne [string]$Target.ObjectId) {
        $reasons.Add('TargetId does not match the target object.')
    }

    if ($Target.MicrosoftPlatform -eq $true -or
        $Target.FirstPartyMicrosoftApp -eq $true -or
        $Target.SuppressCustomerRemediation -eq $true -or
        [string]$Target.Classification -in @('MicrosoftPlatform', 'ExternalVendorPlatform') -or
        [string]$Target.RemediationMode -in @('InformationOnly', 'EvidenceOnly')) {
        $reasons.Add('Platform or suppressed identities are not eligible for live disable readiness.')
    }

    $allowedActions = @('DisableOnly', 'DisableServicePrincipal', 'DisableNhi', 'ControlledDisable', 'ReversibleDisable')
    if ($ActionType -notin $allowedActions) {
        $reasons.Add('Only reversible disable actions are allowed.')
    }

    if ($null -eq $Approval) {
        $reasons.Add('Approval is required.')
    } else {
        try {
            $approvalValidation = Confirm-NhiControlledApproval -Approval $Approval -RunId $RunId -TargetId $TargetId -ActionType 'DisableOnly' -ExpectedSchemaVersion $ExpectedSchemaVersion
            if (-not $approvalValidation.Passed) {
                foreach ($reason in @($approvalValidation.Reasons)) {
                    $reasons.Add([string]$reason)
                }
            }
        } catch {
            $reasons.Add("Approval validation failed: $($_.Exception.Message)")
        }
    }

    if ([string]::IsNullOrWhiteSpace($ApprovalManifestPath)) {
        $reasons.Add('ApprovalManifestPath is required.')
    } else {
        $manifestValidator = Get-Command Confirm-NhiApprovedManifest -ErrorAction SilentlyContinue
        if ($null -eq $manifestValidator) {
            $reasons.Add('Approval manifest integrity validation is unavailable.')
        } else {
            try {
                Confirm-NhiApprovedManifest -ManifestPath $ApprovalManifestPath -EngagementId $RunId -TargetObjectIds @($TargetId) -PhaseLimit 2
            } catch {
                $reasons.Add("Approval manifest validation failed: $($_.Exception.Message)")
            }
        }
    }

    if ($null -eq $Snapshot -or -not $Snapshot.SHA256) {
        $reasons.Add('Snapshot evidence is required.')
    } else {
        if ($Snapshot.Target -and $Snapshot.Target.ObjectId -and [string]$Snapshot.Target.ObjectId -ne $TargetId) {
            $reasons.Add('Snapshot must bind to the target object.')
        }
    }

    if ($null -eq $RollbackEvidence) {
        $reasons.Add('Rollback readiness evidence is required.')
    } else {
        foreach ($name in @('TargetObjectId', 'PreActionAccountEnabled', 'PlannedAction', 'RollbackActionName', 'ApprovalId', 'RunId', 'CapturedUtc')) {
            $property = $RollbackEvidence.PSObject.Properties[$name]
            if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $reasons.Add("Rollback readiness evidence is missing $name.")
            }
        }
        if ($RollbackEvidence.PSObject.Properties['PlannedAction'] -and [string]$RollbackEvidence.PlannedAction -notin $allowedActions) {
            $reasons.Add('Rollback planned action must be reversible disable only.')
        }
        if ($RollbackEvidence.PSObject.Properties['RollbackActionName'] -and [string]$RollbackEvidence.RollbackActionName -notin @('RollbackDisable', 'ReversibleRollbackDisable')) {
            $reasons.Add('Rollback action name is invalid.')
        }
    }

    if ($null -eq $ObservationMetadata) {
        $reasons.Add('Observation metadata is required.')
    } else {
        foreach ($name in @('ScreamTestWindowMinutes', 'MonitoringOwner', 'RollbackContact', 'ObservationStartUtc', 'ObservationEndUtc')) {
            $property = $ObservationMetadata.PSObject.Properties[$name]
            if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $reasons.Add("Observation metadata is missing $name.")
            }
        }
        $startProp = $ObservationMetadata.PSObject.Properties['ObservationStartUtc']
        $endProp = $ObservationMetadata.PSObject.Properties['ObservationEndUtc']
        if ($null -ne $startProp -and $null -ne $endProp) {
            try {
                $startUtc = [DateTime]$startProp.Value
                $endUtc = [DateTime]$endProp.Value
                if ($startUtc -ge $endUtc) {
                    $reasons.Add('Observation end must be after observation start.')
                }
            } catch {
                $reasons.Add('Observation metadata timestamps are invalid.')
            }
        }
    }

    [PSCustomObject]@{
        SchemaVersion      = '4.12'
        RunId              = $RunId
        TargetId           = $TargetId
        TargetType         = [string]$Target.ObjectType
        RequestedAction    = $ActionType
        AllowedAction      = if ($reasons.Count -eq 0) { 'DisableOnly' } else { $null }
        Ready              = $reasons.Count -eq 0
        Blockers           = @($reasons)
        Warnings           = @($warnings)
        TenantWritePlanned = $false
        FinalDeleteAllowed = $false
        PlanningOnly       = $true
        LabOnly            = [bool]$targetLabOnly
        ApprovalValidated  = $null -ne $Approval -and [string]::IsNullOrWhiteSpace([string]$ApprovalManifestPath) -eq $false
        SnapshotValidated  = $null -ne $Snapshot -and [bool]$Snapshot.SHA256
        RollbackValidated  = $null -ne $RollbackEvidence
        ObservationValidated = $null -ne $ObservationMetadata
    }
}

function New-NhiControlledLabDisableDryRunPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter()]
        [object]$ReadinessResult,

        [Parameter()]
        [object]$Approval,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$RollbackReadiness,

        [Parameter()]
        [object]$ObservationMetadata,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $targetValidation = Test-NhiControlledTarget -Target $Target
    if (-not $targetValidation.Passed) {
        foreach ($reason in @($targetValidation.Reasons)) {
            $reasons.Add([string]$reason)
        }
    }

    if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectId')))) {
        $reasons.Add('Target ObjectId is required.')
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('DisplayName')))) {
        $reasons.Add('TargetDisplayName is required.')
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('AppId')))) {
        $warnings.Add('TargetAppId is missing.')
    }

    $targetType = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectType', 'TargetType'))
    if ($targetType -ne 'ServicePrincipal') {
        $reasons.Add('Dry-run package generation is limited to ServicePrincipal targets.')
    }

    $targetLabOnly = (
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Environment')) -eq 'Lab' -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('TenantScope')) -eq 'Lab' -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
    )
    if (-not $targetLabOnly) {
        $reasons.Add('Target must be explicitly marked as lab-only.')
    }

    if ([bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('FirstPartyMicrosoftApp') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('SuppressCustomerRemediation') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('EvidenceOnly') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Classification')) -in @('MicrosoftPlatform', 'ExternalVendorPlatform') -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('RemediationMode')) -in @('InformationOnly', 'EvidenceOnly')) {
        $reasons.Add('Platform, suppressed, or evidence-only targets are not eligible for a dry-run operator package.')
    }

    if ($null -eq $ReadinessResult) {
        $reasons.Add('Readiness result is required.')
    } else {
        if ($ReadinessResult.PSObject.Properties['Ready'] -and $ReadinessResult.Ready -ne $true) {
            $reasons.Add('Readiness result must be Ready.')
        }
        $readinessAction = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessResult -PropertyNames @('AllowedAction', 'RequestedAction', 'ActionType'))
        if ($readinessAction -and $readinessAction -notin @('DisableOnly', 'ReversibleDisable')) {
            $reasons.Add('Readiness result must represent reversible disable readiness.')
        }
    }

    if ($null -eq $Approval) {
        $reasons.Add('Approval metadata is required.')
    }
    if ($null -eq $Snapshot) {
        $reasons.Add('Snapshot metadata is required.')
    }
    if ($null -eq $RollbackReadiness) {
        $reasons.Add('Rollback readiness metadata is required.')
    }
    if ($null -eq $ObservationMetadata) {
        $reasons.Add('Observation metadata is required.')
    }

    $approvalId = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalId'))
    $approvalManifestId = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalManifestId', 'ManifestId'))
    $approvalExpiresUtc = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc'))
    $approvalManifestHash = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalManifestHash', 'SHA256'))
    $approvedBy = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovedBy', 'Approver'))
    $approvalReason = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalReason', 'BusinessJustification', 'Reason'))
    $approvedAction = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvalRunId = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('RunId'))
    if ([string]::IsNullOrWhiteSpace($approvalId)) { $reasons.Add('ApprovalId is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalManifestId)) { $reasons.Add('ApprovalManifestId is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalExpiresUtc)) { $reasons.Add('ApprovalExpiresUtc is required.') }
    if ([string]::IsNullOrWhiteSpace($approvedBy)) { $reasons.Add('ApprovedBy is required.') }
    if ([string]::IsNullOrWhiteSpace($approvedAction)) { $reasons.Add('ApprovedAction is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalRunId)) { $reasons.Add('Approval RunId is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalManifestHash)) {
        $warnings.Add('ApprovalManifestHash is missing.')
    }
    if ([string]::IsNullOrWhiteSpace($approvalReason)) {
        $warnings.Add('Approval reason is missing.')
    }
    if ($approvalRunId -and $approvalRunId -ne $RunId) {
        $reasons.Add('Approval RunId must match the package RunId.')
    }

    if ($approvalExpiresUtc) {
        try {
            if ([DateTime]::Parse($approvalExpiresUtc).ToUniversalTime() -le [DateTime]::UtcNow) {
                $reasons.Add('Approval is expired.')
            }
        } catch {
            $reasons.Add('ApprovalExpiresUtc is not parseable.')
        }
    }

    $approvalActions = @()
    if ($null -ne $Approval -and $Approval.PSObject.Properties['ApprovedActions']) {
        $approvalActions = @($Approval.PSObject.Properties['ApprovedActions'].Value)
    }
    if ($approvalActions.Count -gt 0 -and ($approvalActions -notcontains 'DisableOnly' -and $approvalActions -notcontains 'ReversibleDisable')) {
        $reasons.Add('Approval must include reversible disable approval.')
    }

    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotPath', 'Path'))
    $capturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $preActionEnabledState = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionEnabledState', 'AccountEnabled')
    $preActionCredentialCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionCredentialCount', 'CredentialCount')
    $preActionOwnerCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionOwnerCount', 'OwnerCount')
    $preActionAppRoleAssignmentsCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionAppRoleAssignmentsCount', 'AppRoleAssignmentsCount')
    $preActionOAuthGrantCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionOAuthGrantCount', 'OAuthGrantCount')
    if ([string]::IsNullOrWhiteSpace($snapshotId) -and [string]::IsNullOrWhiteSpace($snapshotPath)) { $reasons.Add('SnapshotId or SnapshotPath is required.') }
    if ([string]::IsNullOrWhiteSpace($capturedUtc)) { $reasons.Add('Snapshot CapturedUtc is required.') }
    if ($null -eq $preActionEnabledState) { $reasons.Add('Pre-action enabled state is required.') }
    if ($null -eq $preActionCredentialCount) { $reasons.Add('Pre-action credential count is required.') }
    if ($null -eq $preActionOwnerCount) { $reasons.Add('Pre-action owner count is required.') }
    if ($null -eq $preActionAppRoleAssignmentsCount) { $reasons.Add('Pre-action app role assignments count is required.') }
    if ($null -eq $preActionOAuthGrantCount) { $reasons.Add('Pre-action OAuth grant count is required.') }

    $rollbackTargetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('TargetObjectId'))
    $rollbackPreActionEnabled = Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('PreActionAccountEnabled', 'PreActionEnabledState')
    $rollbackPlannedAction = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('PlannedAction'))
    $rollbackActionName = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('RollbackActionName'))
    $rollbackApprovalId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('ApprovalId'))
    $rollbackRunId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('RunId'))
    $rollbackCapturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('CapturedUtc'))
    $rollbackSnapshotId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('SnapshotId', 'SnapshotPath'))
    $rollbackBaselineHash = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('BaselineHash', 'SnapshotSHA256'))
    $rollbackEvidenceSourcePath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('EvidenceSourcePath'))
    if ([string]::IsNullOrWhiteSpace($rollbackTargetObjectId)) { $reasons.Add('Rollback target object id is required.') }
    if ($null -eq $rollbackPreActionEnabled) { $reasons.Add('Rollback pre-action enabled state is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackPlannedAction)) { $reasons.Add('Rollback planned action is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackActionName)) { $reasons.Add('Rollback action name is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackApprovalId)) { $reasons.Add('Rollback approval id is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackRunId)) { $reasons.Add('Rollback run id is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackCapturedUtc)) { $reasons.Add('Rollback captured timestamp is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackSnapshotId)) { $warnings.Add('Rollback snapshot linkage is missing.') }
    if ([string]::IsNullOrWhiteSpace($rollbackBaselineHash)) { $warnings.Add('Rollback baseline hash is missing.') }
    if ([string]::IsNullOrWhiteSpace($rollbackEvidenceSourcePath)) { $warnings.Add('Rollback evidence source path is missing.') }

    $observationWindowMinutes = Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('ObservationWindowMinutes', 'ScreamTestWindowMinutes')
    $monitoringOwner = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('MonitoringOwner'))
    $rollbackContact = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('RollbackContact'))
    $observationStartUtc = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('ObservationStartUtc'))
    $observationEndUtc = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('ObservationEndUtc'))
    $successCriteria = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('SuccessCriteria'))
    $failureCriteria = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('FailureCriteria'))
    $rollbackTriggerCriteria = Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('RollbackTriggerCriteria')
    if ($null -eq $observationWindowMinutes) { $reasons.Add('Observation window minutes is required.') }
    if ([string]::IsNullOrWhiteSpace($monitoringOwner)) { $reasons.Add('Monitoring owner is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackContact)) { $reasons.Add('Rollback contact is required.') }
    if ([string]::IsNullOrWhiteSpace($observationStartUtc)) { $reasons.Add('Observation start timestamp is required.') }
    if ([string]::IsNullOrWhiteSpace($observationEndUtc)) { $reasons.Add('Observation end timestamp is required.') }
    if ([string]::IsNullOrWhiteSpace($successCriteria)) { $reasons.Add('Success criteria is required.') }
    if ([string]::IsNullOrWhiteSpace($failureCriteria)) { $reasons.Add('Failure criteria is required.') }
    if ($null -eq $rollbackTriggerCriteria -or @($rollbackTriggerCriteria).Count -eq 0) { $reasons.Add('Rollback trigger criteria is required.') }

    $package = $null
    $artifactPath = $null
    $ready = $reasons.Count -eq 0

    if ($ready) {
        $targetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('DisplayName'))
        $targetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectId'))
        $targetAppId = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('AppId'))
        $classification = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Classification'))
        $labMarker = if ([bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
        $package = [PSCustomObject]@{
            PackageId = "REV413-$RunId-$targetObjectId"
            RunId = $RunId
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
            ToolVersion = '4.13'
            SchemaVersion = '4.13'
            Mode = 'OperatorDryRun'
            TenantWritePlanned = $false
            ExecutionPerformed = $false
            FinalDeleteAllowed = $false
            Ready = $true
            Blockers = @()
            Warnings = @($warnings)
            TargetDisplayName = $targetDisplayName
            TargetObjectId = $targetObjectId
            TargetAppId = $targetAppId
            TargetType = $targetType
            Classification = $classification
            SuppressCustomerRemediation = [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('SuppressCustomerRemediation') -Default $false)
            EvidenceOnly = [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('EvidenceOnly') -Default $false)
            LabTargetMarker = $labMarker
            EnvironmentIndicator = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Environment', 'TenantScope'))
            ApprovalId = $approvalId
            ApprovalManifestId = $approvalManifestId
            ApprovedAction = $approvedAction
            ApprovalExpiresUtc = $approvalExpiresUtc
            ApprovalManifestHash = $approvalManifestHash
            ApprovedBy = $approvedBy
            Approver = $approvedBy
            ApprovalReason = $approvalReason
            ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
            ReadinessVerdict = [PSCustomObject]@{
                Ready = [bool]$ReadinessResult.Ready
                Blockers = @($ReadinessResult.Blockers)
                Warnings = @($ReadinessResult.Warnings)
                AllowedAction = 'ReversibleDisable'
                ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
            }
            PreActionSnapshot = [PSCustomObject]@{
                SnapshotId = $snapshotId
                SnapshotPath = $snapshotPath
                PreActionEnabledState = [bool]$preActionEnabledState
                AccountEnabled = [bool]$preActionEnabledState
                PreActionCredentialCount = [int]$preActionCredentialCount
                PreActionOwnerCount = [int]$preActionOwnerCount
                PreActionAppRoleAssignmentsCount = [int]$preActionAppRoleAssignmentsCount
                PreActionOAuthGrantCount = [int]$preActionOAuthGrantCount
                CapturedUtc = $capturedUtc
            }
            PlannedAction = [PSCustomObject]@{
                PlannedAction = 'ReversibleDisable'
                LiveCommandPreview = "WhatIf: ServicePrincipal account disable preview for $targetObjectId"
                PseudoCommand = "WhatIf: ServicePrincipalAccountEnabled=`$false for $targetObjectId"
                WhatIf = $true
                ConfirmRequired = $true
                HumanApprovalRequired = $true
                ExpectedChange = 'disable only'
                ProhibitedOperations = @(
                    'final delete',
                    'service principal removal',
                    'application removal',
                    'grant cleanup',
                    'metadata cleanup',
                    'credential deletion'
                )
            }
            RollbackReadiness = [PSCustomObject]@{
                TargetObjectId = $rollbackTargetObjectId
                PreActionAccountEnabled = [bool]$rollbackPreActionEnabled
                PlannedAction = $rollbackPlannedAction
                RollbackActionName = $rollbackActionName
                ApprovalId = $rollbackApprovalId
                RunId = $rollbackRunId
                CapturedUtc = $rollbackCapturedUtc
                SnapshotId = $rollbackSnapshotId
                BaselineHash = $rollbackBaselineHash
                EvidenceSourcePath = $rollbackEvidenceSourcePath
            }
            Observation = [PSCustomObject]@{
                ObservationWindowMinutes = [int]$observationWindowMinutes
                MonitoringOwner = $monitoringOwner
                RollbackContact = $rollbackContact
                ObservationStartUtc = $observationStartUtc
                ObservationEndUtc = $observationEndUtc
                SuccessCriteria = $successCriteria
                FailureCriteria = $failureCriteria
                RollbackTriggerCriteria = @($rollbackTriggerCriteria)
                RollbackTriggerCriteriaText = @($rollbackTriggerCriteria | ForEach-Object { [string]$_ })
            }
            OperatorChecklist = New-NhiControlledChecklist -Items @(
                'Confirm this is a lab-only tenant/target.',
                'Confirm target is not MicrosoftPlatform.',
                'Confirm target is not ExternalVendorPlatform.',
                'Confirm SuppressCustomerRemediation is false.',
                'Confirm EvidenceOnly is false.',
                'Confirm approval is current and unexpired.',
                'Confirm pre-action snapshot exists.',
                'Confirm rollback package exists.',
                'Confirm observation window is staffed.',
                'Confirm no final delete is requested.',
                'Confirm dry-run package has been reviewed by human operator.'
            )
            ProhibitedOperations = @(
                'final delete',
                'service principal removal',
                'application removal',
                'grant cleanup',
                'metadata cleanup',
                'credential deletion'
            )
        }

        if ($OutputPath) {
            $artifactPath = Export-NhiControlledDecommissionEvidence -Evidence $package -Path $OutputPath
            $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue $artifactPath -Force
        }
    }

    [PSCustomObject]@{
        SchemaVersion = '4.13'
        PackageType = 'LabDisableDryRun'
        PackageId = if ($package) { $package.PackageId } else { $null }
        RunId = $RunId
        CreatedUtc = if ($package) { $package.CreatedUtc } else { [DateTime]::UtcNow.ToString('o') }
        ToolVersion = '4.13'
        Mode = 'OperatorDryRun'
        TenantWritePlanned = $false
        ExecutionPerformed = $false
        FinalDeleteAllowed = $false
        Ready = $ready
        Blockers = @($reasons)
        Warnings = @($warnings)
        Target = if ($package) { $package | Select-Object -Property TargetDisplayName,TargetObjectId,TargetAppId,TargetType,Classification,SuppressCustomerRemediation,EvidenceOnly,LabTargetMarker,EnvironmentIndicator } else { $null }
        Approval = if ($package) { $package | Select-Object -Property ApprovalId,ApprovalManifestId,ApprovedAction,ApprovalExpiresUtc,ApprovalManifestHash,ApprovedBy,Approver,ApprovalReason } else { $null }
        ReadinessVerdict = if ($package) { $package.ReadinessVerdict } else { [PSCustomObject]@{ Ready = $false; Blockers = @($reasons); Warnings = @($warnings); AllowedAction = 'ReversibleDisable'; ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness' } }
        PreActionSnapshot = if ($package) { $package.PreActionSnapshot } else { $null }
        PlannedAction = if ($package) { $package.PlannedAction } else { $null }
        RollbackReadiness = if ($package) { $package.RollbackReadiness } else { $null }
        Observation = if ($package) { $package.Observation } else { $null }
        OperatorChecklist = if ($package) { $package.OperatorChecklist } else { @() }
        OutputArtifactPath = $artifactPath
        ProhibitedOperations = @(
            'final delete',
            'service principal removal',
            'application removal',
            'grant cleanup',
            'metadata cleanup',
            'credential deletion'
        )
    }
}

function New-NhiControlledLabRollbackDrillPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter()]
        [object]$SourceDryRunPackage,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$RollbackTriggers,

        [Parameter()]
        [object]$RollbackValidationCriteria,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $targetValidation = Test-NhiControlledTarget -Target $Target
    if (-not $targetValidation.Passed) {
        foreach ($reason in @($targetValidation.Reasons)) {
            $reasons.Add([string]$reason)
        }
    }

    $targetType = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectType', 'TargetType'))
    if ($targetType -ne 'ServicePrincipal') {
        $reasons.Add('Rollback drill package generation is limited to ServicePrincipal targets.')
    }

    $targetLabOnly = (
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Environment')) -eq 'Lab' -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('TenantScope')) -eq 'Lab' -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
    )
    if (-not $targetLabOnly) {
        $reasons.Add('Target must be explicitly marked as lab-only.')
    }

    if ([bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('FirstPartyMicrosoftApp') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('SuppressCustomerRemediation') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('EvidenceOnly') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Classification')) -in @('MicrosoftPlatform', 'ExternalVendorPlatform') -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('RemediationMode')) -in @('InformationOnly', 'EvidenceOnly')) {
        $reasons.Add('Platform, suppressed, or evidence-only targets are not eligible for a rollback drill package.')
    }

    if ($null -eq $SourceDryRunPackage) {
        $reasons.Add('Source dry-run package linkage is required.')
    } else {
        $sourcePackageId = [string](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('PackageId'))
        $sourceMode = [string](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('Mode'))
        $sourceReady = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('Ready') -Default $false)
        $sourceTenantWritePlanned = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('TenantWritePlanned') -Default $true)
        $sourceExecutionPerformed = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('ExecutionPerformed') -Default $true)
        $sourcePlannedAction = Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('PlannedAction')
        $sourcePlannedActionName = if ($sourcePlannedAction -is [string]) {
            [string]$sourcePlannedAction
        } elseif ($null -ne $sourcePlannedAction) {
            [string](Get-NhiControlledPropertyValue -InputObject $sourcePlannedAction -PropertyNames @('PlannedAction'))
        } else {
            $null
        }
        if ([string]::IsNullOrWhiteSpace($sourcePackageId)) { $reasons.Add('Source dry-run package id is required.') }
        if ($sourceMode -and $sourceMode -ne 'OperatorDryRun') { $reasons.Add('Source dry-run package must be an operator dry-run package.') }
        if ($sourceReady -ne $true) { $reasons.Add('Source dry-run package must be ready.') }
        if ($sourceTenantWritePlanned -ne $false) { $reasons.Add('Source dry-run package must not plan tenant writes.') }
        if ($sourceExecutionPerformed -ne $false) { $reasons.Add('Source dry-run package must not execute.') }
        if ($null -eq $sourcePlannedActionName -or $sourcePlannedActionName -ne 'ReversibleDisable') {
            $reasons.Add('Source dry-run package must plan ReversibleDisable.')
        }
    }

    if ($null -eq $Snapshot) { $reasons.Add('Snapshot metadata is required.') }
    if ($null -eq $RollbackTriggers) { $reasons.Add('Rollback trigger criteria are required.') }
    if ($null -eq $RollbackValidationCriteria) { $reasons.Add('Rollback validation criteria are required.') }

    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotPath', 'Path'))
    $capturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $preActionEnabledState = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionEnabledState', 'AccountEnabled')
    $baselineHash = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('BaselineHash', 'SnapshotSHA256', 'SHA256'))
    $evidenceSourcePath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('EvidenceSourcePath'))
    if ([string]::IsNullOrWhiteSpace($snapshotId) -and [string]::IsNullOrWhiteSpace($snapshotPath)) { $reasons.Add('SnapshotId or SnapshotPath is required.') }
    if ([string]::IsNullOrWhiteSpace($capturedUtc)) { $reasons.Add('CapturedUtc is required.') }
    if ($null -eq $preActionEnabledState) { $reasons.Add('Pre-action enabled state is required.') }
    if ([string]::IsNullOrWhiteSpace($baselineHash)) { $reasons.Add('BaselineHash is required.') }
    if ([string]::IsNullOrWhiteSpace($evidenceSourcePath)) { $warnings.Add('Evidence source path is missing.') }

    $triggerItems = @($RollbackTriggers)
    $validationItems = @($RollbackValidationCriteria)
    if ($triggerItems.Count -eq 0) { $reasons.Add('Rollback trigger criteria cannot be empty.') }
    if ($validationItems.Count -eq 0) { $reasons.Add('Rollback validation criteria cannot be empty.') }

    $ready = $reasons.Count -eq 0
    $package = $null
    $artifactPath = $null

    if ($ready) {
        $targetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('DisplayName'))
        $targetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectId'))
        $targetAppId = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('AppId'))
        $classification = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Classification'))
        $sourcePackageId = [string](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('PackageId'))
        $package = [PSCustomObject]@{
            RollbackPackageId = "REV414-$RunId-$targetObjectId"
            RunId = $RunId
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
            SourceDryRunPackageId = $sourcePackageId
            Mode = 'RollbackDrillOnly'
            RollbackExecuted = $false
            TenantWritePlanned = $false
            FinalDeleteAllowed = $false
            Ready = $true
            Blockers = @()
            Warnings = @($warnings)
            TargetDisplayName = $targetDisplayName
            TargetObjectId = $targetObjectId
            TargetAppId = $targetAppId
            TargetType = $targetType
            LabTargetMarker = if ([bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
            PreActionBaseline = [PSCustomObject]@{
                PreActionEnabledState = [bool]$preActionEnabledState
                AccountEnabled = [bool]$preActionEnabledState
                SnapshotId = $snapshotId
                SnapshotPath = $snapshotPath
                CapturedUtc = $capturedUtc
                BaselineHash = $baselineHash
                EvidenceSourcePath = $evidenceSourcePath
            }
            RollbackAction = [PSCustomObject]@{
                RollbackAction = 'ReEnableServicePrincipal'
                RollbackCommandPreview = "WhatIf: ServicePrincipal account re-enable preview for $targetObjectId"
                PseudoCommand = "ReEnableServicePrincipal -TargetObjectId $targetObjectId -WhatIf"
                WhatIf = $true
                ConfirmRequired = $true
                HumanApprovalRequired = $true
                RollbackExecutionPerformed = $false
            }
            RollbackTriggerCriteria = @($triggerItems | ForEach-Object { [string]$_ })
            RollbackValidationCriteria = @($validationItems | ForEach-Object { [string]$_ })
            ProhibitedRollbackBehaviors = @(
                'delete anything',
                'remove service principal',
                'remove application',
                'recreate object as substitute for rollback',
                'modify grants',
                'modify credentials',
                'bypass approval'
            )
            OperatorChecklist = New-NhiControlledChecklist -Items @(
                'Confirm original action was reversible disable only.',
                'Confirm pre-action snapshot exists.',
                'Confirm rollback target matches approved lab target.',
                'Confirm rollback command is re-enable only.',
                'Confirm rollback does not recreate or delete objects.',
                'Confirm rollback requires human approval.',
                'Confirm rollback is not executed by this package.',
                'Confirm post-rollback validation criteria are documented.'
            )
            RollbackTriggerCriteriaText = @($triggerItems | ForEach-Object { [string]$_ })
            RollbackValidationCriteriaText = @($validationItems | ForEach-Object { [string]$_ })
            SourceDryRunPackage = [PSCustomObject]@{
                PackageId = $sourcePackageId
                Mode = [string](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('Mode'))
                Ready = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('Ready') -Default $false)
                TenantWritePlanned = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('TenantWritePlanned') -Default $true)
                ExecutionPerformed = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('ExecutionPerformed') -Default $true)
                PlannedAction = $sourcePlannedActionName
            }
        }

        if ($OutputPath) {
            $artifactPath = Export-NhiControlledDecommissionEvidence -Evidence $package -Path $OutputPath
            $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue $artifactPath -Force
        }
    }

    [PSCustomObject]@{
        SchemaVersion = '4.14'
        RollbackPackageType = 'RollbackDrill'
        RollbackPackageId = if ($package) { $package.RollbackPackageId } else { $null }
        RunId = $RunId
        CreatedUtc = if ($package) { $package.CreatedUtc } else { [DateTime]::UtcNow.ToString('o') }
        SourceDryRunPackageId = if ($package) { $package.SourceDryRunPackage.PackageId } else { $null }
        Mode = 'RollbackDrillOnly'
        RollbackExecuted = $false
        TenantWritePlanned = $false
        FinalDeleteAllowed = $false
        Ready = $ready
        Blockers = @($reasons)
        Warnings = @($warnings)
        Target = if ($package) { $package | Select-Object -Property TargetDisplayName,TargetObjectId,TargetAppId,TargetType,LabTargetMarker } else { $null }
        PreActionBaseline = if ($package) { $package.PreActionBaseline } else { $null }
        RollbackAction = if ($package) { $package.RollbackAction } else { $null }
        RollbackTriggerCriteria = if ($package) { $package.RollbackTriggerCriteria } else { @() }
        RollbackValidationCriteria = if ($package) { $package.RollbackValidationCriteria } else { @() }
        ProhibitedRollbackBehaviors = if ($package) { $package.ProhibitedRollbackBehaviors } else { @() }
        OperatorChecklist = if ($package) { $package.OperatorChecklist } else { @() }
        SourceDryRunPackage = if ($package) { $package.SourceDryRunPackage } else { $null }
        OutputArtifactPath = $artifactPath
    }
}

function Invoke-NhiControlledLabLiveReversibleDisable {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Target,

        [Parameter()]
        [object]$ApprovalManifest,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApprovalManifestPath,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$ReadinessResult,

        [Parameter()]
        [object]$DryRunPackage,

        [Parameter()]
        [object]$RollbackPackage,

        [Parameter()]
        [object]$ObservationMetadata,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$EngagementId,

        [Parameter()]
        [bool]$LabExecutionApproved = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @('ReversibleDisable')
    )

    if ([string]::IsNullOrWhiteSpace($EngagementId)) {
        $EngagementId = $RunId
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetObject = $null
    $targetContext = $null

    if ($null -eq $Target -or @($Target).Count -ne 1) {
        $reasons.Add('Exactly one target is required.')
    } else {
        $targetObject = @($Target)[0]
        $targetValidation = Test-NhiControlledTarget -Target $targetObject
        if (-not $targetValidation.Passed) {
            foreach ($reason in @($targetValidation.Reasons)) {
                $reasons.Add([string]$reason)
            }
        }

        $targetContext = Get-NhiRun4CTargetContext -Target @($targetObject)
        foreach ($reason in @($targetContext.Blockers)) {
            if ($reason) {
                $reasons.Add([string]$reason)
            }
        }

        $targetType = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType'))
        if ($targetType -ne 'ServicePrincipal') {
            $reasons.Add('Run #4C execution is limited to ServicePrincipal targets.')
        }

        if ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabValidationApproved') -Default $false) -ne $true) {
            $reasons.Add('LabValidationApproved must be true.')
        }
    }

    if ($LabExecutionApproved -ne $true) {
        $reasons.Add('LabExecutionApproved must be true.')
    }

    $requestedOperations = @($RequestedOperations)
    if ($requestedOperations.Count -eq 0) {
        $reasons.Add('At least one requested operation is required.')
    } else {
        $destructivePattern = '(?i)(finaldelete|final delete|delete|harddelete|removeapplication|remove service principal|removeserviceprincipal|remove application|remove|grantcleanup|grant cleanup|metadatacleanup|metadata cleanup|credentialdelete|credential deletion|credentialdeletion|credentialchange|recreate)'
        foreach ($requestedOperation in $requestedOperations) {
            if ([string]::IsNullOrWhiteSpace([string]$requestedOperation)) {
                $reasons.Add('Requested operations cannot be empty.')
                continue
            }

            if ([string]$requestedOperation -ne 'ReversibleDisable') {
                $reasons.Add("Requested operation '$requestedOperation' is blocked.")
            }
            if ([string]$requestedOperation -match $destructivePattern) {
                $reasons.Add("Requested operation '$requestedOperation' is destructive and is blocked.")
            }
        }
    }

    if (-not (Test-Path -LiteralPath $ApprovalManifestPath -PathType Leaf)) {
        $reasons.Add('Approval manifest file is required.')
    }

    $approvalManifestFromFile = $null
    if (Test-Path -LiteralPath $ApprovalManifestPath -PathType Leaf) {
        try {
            $approvalManifestFromFile = Get-Content -LiteralPath $ApprovalManifestPath -Raw | ConvertFrom-Json
        } catch {
            $reasons.Add('Approval manifest file is not valid JSON.')
        }
    }

    if ($null -eq $ApprovalManifest) {
        $reasons.Add('Approval manifest object is required.')
    }

    $approvalId = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalId', 'Id'))
    $approvedAction = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvedBy = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedBy', 'Approver'))
    $approvalReason = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalReason', 'BusinessJustification', 'Reason'))
    $approvalExpiresUtc = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc'))
    $approvalHash = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalManifestHash', 'ManifestHash', 'SHA256'))
    $manifestTargetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $manifestTargetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetDisplayName'))
    $manifestTargetType = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetType'))

    if ([string]::IsNullOrWhiteSpace($approvalId)) { $reasons.Add('ApprovalId is required.') }
    if ([string]::IsNullOrWhiteSpace($approvedAction)) { $reasons.Add('ApprovedAction is required.') }
    if ($approvedAction -ne 'ReversibleDisable') { $reasons.Add('ApprovedAction must be ReversibleDisable.') }
    if ([string]::IsNullOrWhiteSpace($approvedBy)) { $reasons.Add('ApprovedBy is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalReason)) { $reasons.Add('ApprovalReason or BusinessJustification is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalExpiresUtc)) { $reasons.Add('ApprovalExpiresUtc is required.') }
    if ($null -eq $approvalManifestFromFile) {
        $reasons.Add('Approval manifest contents could not be loaded.')
    } else {
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovalId', 'Id')))) { $reasons.Add('Approval manifest file is missing ApprovalId.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('TargetObjectId')))) { $reasons.Add('Approval manifest file is missing TargetObjectId.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('TargetDisplayName')))) { $reasons.Add('Approval manifest file is missing TargetDisplayName.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('TargetType')))) { $reasons.Add('Approval manifest file is missing TargetType.') }
        if ([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovedAction', 'ActionType')) -ne 'ReversibleDisable') { $reasons.Add('Approval manifest file must approve ReversibleDisable only.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovedBy', 'Approver')))) { $reasons.Add('Approval manifest file is missing ApprovedBy.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovalReason', 'BusinessJustification', 'Reason')))) { $reasons.Add('Approval manifest file is missing ApprovalReason or BusinessJustification.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc')))) { $reasons.Add('Approval manifest file is missing ApprovalExpiresUtc.') }
    }

    if ($null -ne $targetObject) {
        if ($manifestTargetObjectId -and $manifestTargetObjectId -ne [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))) {
            $reasons.Add('Approval manifest target object id must match the live target.')
        }
        if ($manifestTargetDisplayName -and $manifestTargetDisplayName -ne [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName'))) {
            $reasons.Add('Approval manifest target display name must match the live target.')
        }
        if ($manifestTargetType -and $manifestTargetType -ne [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType'))) {
            $reasons.Add('Approval manifest target type must match the live target.')
        }
    }

    if ($approvalExpiresUtc) {
        try {
            if ([DateTime]::Parse($approvalExpiresUtc).ToUniversalTime() -le [DateTime]::UtcNow) {
                $reasons.Add('Approval is expired.')
            }
        } catch {
            $reasons.Add('ApprovalExpiresUtc is not parseable.')
        }
    }

    if ([string]::IsNullOrWhiteSpace($approvalHash)) {
        $warnings.Add('Approval manifest hash is missing.')
    }

    if ($null -eq $Snapshot) {
        $reasons.Add('Snapshot is required.')
    }
    if ($null -eq $ReadinessResult) {
        $reasons.Add('Readiness result is required.')
    }
    if ($null -eq $DryRunPackage) {
        $reasons.Add('Dry-run package is required.')
    }
    if ($null -eq $RollbackPackage) {
        $reasons.Add('Rollback package is required.')
    }
    if ($null -eq $ObservationMetadata) {
        $reasons.Add('Observation metadata is required.')
    }

    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotPath', 'Path'))
    $capturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $preActionEnabledState = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionEnabledState', 'AccountEnabled')
    $preActionCredentialCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionCredentialCount', 'CredentialCount')
    $preActionOwnerCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionOwnerCount', 'OwnerCount')
    $preActionAppRoleAssignmentsCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionAppRoleAssignmentsCount', 'AppRoleAssignmentsCount')
    $preActionOAuthGrantCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionOAuthGrantCount', 'OAuthGrantCount')
    if ([string]::IsNullOrWhiteSpace($snapshotId) -and [string]::IsNullOrWhiteSpace($snapshotPath)) { $reasons.Add('SnapshotId or SnapshotPath is required.') }
    if ([string]::IsNullOrWhiteSpace($capturedUtc)) { $reasons.Add('Snapshot CapturedUtc is required.') }
    if ($null -eq $preActionEnabledState) { $reasons.Add('Pre-action enabled state is required.') }
    if ($null -eq $preActionCredentialCount) { $warnings.Add('Pre-action credential count is missing.') }
    if ($null -eq $preActionOwnerCount) { $warnings.Add('Pre-action owner count is missing.') }
    if ($null -eq $preActionAppRoleAssignmentsCount) { $warnings.Add('Pre-action app role assignments count is missing.') }
    if ($null -eq $preActionOAuthGrantCount) { $warnings.Add('Pre-action OAuth grant count is missing.') }

    $readinessReady = [bool](Get-NhiControlledPropertyValue -InputObject $ReadinessResult -PropertyNames @('Ready') -Default $false)
    $readinessBlockers = @($ReadinessResult.Blockers)
    $readinessAllowedAction = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessResult -PropertyNames @('AllowedAction', 'RequestedAction', 'ActionType'))
    $readinessFinalDeleteAllowed = [bool](Get-NhiControlledPropertyValue -InputObject $ReadinessResult -PropertyNames @('FinalDeleteAllowed') -Default $true)
    if ($readinessReady -ne $true) { $reasons.Add('Readiness result must be Ready.') }
    if ($readinessAllowedAction -ne 'ReversibleDisable') { $reasons.Add('Readiness result must allow ReversibleDisable only.') }
    if ($readinessFinalDeleteAllowed -ne $false) { $reasons.Add('Readiness result must not allow final delete.') }
    if ($null -ne $readinessBlockers -and @($readinessBlockers).Count -gt 0 -and [string]::IsNullOrWhiteSpace([string]$readinessBlockers[0]) -eq $false) {
        $warnings.Add('Readiness blockers were supplied and should be reviewed before live execution.')
    }

    $dryRunReady = [bool](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('Ready') -Default $false)
    $dryRunTenantWritePlanned = [bool](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('TenantWritePlanned') -Default $true)
    $dryRunExecutionPerformed = [bool](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('ExecutionPerformed') -Default $true)
    $dryRunFinalDeleteAllowed = [bool](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('FinalDeleteAllowed') -Default $true)
    $dryRunPlannedAction = [string](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('PlannedAction', 'PlannedActionType'))
    if ($dryRunReady -ne $true) { $reasons.Add('Dry-run package must be ready.') }
    if ($dryRunTenantWritePlanned -ne $false) { $reasons.Add('Dry-run package must not plan tenant writes.') }
    if ($dryRunExecutionPerformed -ne $false) { $reasons.Add('Dry-run package must not have executed.') }
    if ($dryRunFinalDeleteAllowed -ne $false) { $reasons.Add('Dry-run package must not allow final delete.') }
    if ($dryRunPlannedAction -ne 'ReversibleDisable') { $reasons.Add('Dry-run package must plan ReversibleDisable only.') }

    $rollbackExecuted = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('RollbackExecuted') -Default $true)
    $rollbackActionName = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    $rollbackWhatIf = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('WhatIf') -Default $false)
    $rollbackHumanApprovalRequired = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('HumanApprovalRequired') -Default $false)
    if ($rollbackExecuted -ne $false) { $reasons.Add('Rollback package must not have executed.') }
    if ($rollbackActionName -ne 'ReEnableServicePrincipal') { $reasons.Add('Rollback action must be re-enable only.') }
    if ($rollbackWhatIf -ne $true) { $reasons.Add('Rollback package must be WhatIf only.') }
    if ($rollbackHumanApprovalRequired -ne $true) { $reasons.Add('Rollback package must require human approval.') }

    $observationWindowMinutes = Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('ObservationWindowMinutes', 'ScreamTestWindowMinutes')
    $monitoringOwner = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('MonitoringOwner'))
    $rollbackContact = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('RollbackContact'))
    $successCriteria = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('SuccessCriteria'))
    $failureCriteria = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('FailureCriteria'))
    $rollbackTriggerCriteria = Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('RollbackTriggerCriteria')
    if ($null -eq $observationWindowMinutes) { $reasons.Add('Observation window minutes is required.') }
    if ([string]::IsNullOrWhiteSpace($monitoringOwner)) { $reasons.Add('Monitoring owner is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackContact)) { $reasons.Add('Rollback contact is required.') }
    if ([string]::IsNullOrWhiteSpace($successCriteria)) { $reasons.Add('Success criteria is required.') }
    if ([string]::IsNullOrWhiteSpace($failureCriteria)) { $reasons.Add('Failure criteria is required.') }
    if ($null -eq $rollbackTriggerCriteria -or @($rollbackTriggerCriteria).Count -eq 0) { $reasons.Add('Rollback trigger criteria is required.') }

    $liveCommandPreview = $null
    if ($null -ne $targetObject) {
        $liveCommandPreview = "Invoke-NhiDisable -ObjectId $([string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))) -ObjectType ServicePrincipal -EngagementId $EngagementId -ExecutionRunId $RunId -ExecutionOutputPath `"$OutputPath`" -ScreamTestDays 0"
    }

    $ready = $reasons.Count -eq 0
    $executionPerformed = $false
    $postActionEnabledState = $null
    $executionError = $null

    if ($ready -and $LabExecutionApproved -eq $true -and -not $WhatIfPreference) {
        try {
            Invoke-NhiDisable -ObjectId ([string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))) `
                -ObjectType 'ServicePrincipal' `
                -EngagementId $EngagementId `
                -ExecutionRunId $RunId `
                -ExecutionOutputPath $OutputPath `
                -ScreamTestDays 0
            $executionPerformed = $true
            $getServicePrincipal = Get-Command Get-MgServicePrincipal -ErrorAction SilentlyContinue
            if ($getServicePrincipal) {
                try {
                    $liveState = Get-MgServicePrincipal -ServicePrincipalId ([string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))) -Property 'AccountEnabled' -ErrorAction Stop
                    $postActionEnabledState = $liveState.AccountEnabled
                } catch {
                    $warnings.Add('Post-action enabled state could not be captured.')
                }
            }
        } catch {
            $executionError = $_.Exception.Message
            $reasons.Add('Live execution failed.')
        }
    }

    $evidence = [PSCustomObject]@{
        SchemaVersion = '4.15'
        RunId = $RunId
        EngagementId = $EngagementId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'Run4CLiveReversibleDisable'
        LabExecutionApproved = $LabExecutionApproved
        WhatIf = [bool]$WhatIfPreference
        Ready = $ready
        Blockers = @($reasons)
        Warnings = @($warnings)
        Target = if ($targetObject) {
            [PSCustomObject]@{
                TargetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName'))
                TargetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))
                TargetAppId = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId'))
                TargetType = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType'))
                Classification = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification'))
                LabTargetMarker = if ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
            }
        } else { $null }
        ApprovalManifest = [PSCustomObject]@{
            ApprovalId = $approvalId
            TargetObjectId = $manifestTargetObjectId
            TargetDisplayName = $manifestTargetDisplayName
            TargetType = $manifestTargetType
            ApprovedAction = $approvedAction
            ApprovedBy = $approvedBy
            ApprovalReason = $approvalReason
            ApprovalExpiresUtc = $approvalExpiresUtc
            ApprovalManifestHash = $approvalHash
        }
        PreActionSnapshot = [PSCustomObject]@{
            SnapshotId = $snapshotId
            SnapshotPath = $snapshotPath
            PreActionEnabledState = [bool]$preActionEnabledState
            AccountEnabled = [bool]$preActionEnabledState
            PreActionCredentialCount = $preActionCredentialCount
            PreActionOwnerCount = $preActionOwnerCount
            PreActionAppRoleAssignmentsCount = $preActionAppRoleAssignmentsCount
            PreActionOAuthGrantCount = $preActionOAuthGrantCount
            CapturedUtc = $capturedUtc
        }
        DryRunPackage = [PSCustomObject]@{
            PackageId = [string](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('PackageId'))
            Ready = $dryRunReady
            TenantWritePlanned = $dryRunTenantWritePlanned
            ExecutionPerformed = $dryRunExecutionPerformed
            FinalDeleteAllowed = $dryRunFinalDeleteAllowed
            PlannedAction = $dryRunPlannedAction
        }
        RollbackPackage = [PSCustomObject]@{
            RollbackPackageId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('RollbackPackageId'))
            RollbackExecuted = $rollbackExecuted
            RollbackAction = $rollbackActionName
            WhatIf = $rollbackWhatIf
            HumanApprovalRequired = $rollbackHumanApprovalRequired
        }
        ReadinessResult = [PSCustomObject]@{
            Ready = $readinessReady
            Blockers = @($readinessBlockers)
            AllowedAction = $readinessAllowedAction
            FinalDeleteAllowed = $readinessFinalDeleteAllowed
        }
        Observation = [PSCustomObject]@{
            ObservationWindowMinutes = $observationWindowMinutes
            MonitoringOwner = $monitoringOwner
            RollbackContact = $rollbackContact
            SuccessCriteria = $successCriteria
            FailureCriteria = $failureCriteria
            RollbackTriggerCriteria = @($rollbackTriggerCriteria)
        }
        LiveCommandPreview = $liveCommandPreview
        RequestedOperations = @($requestedOperations)
        ExecutionPerformed = $executionPerformed
        ExecutionError = $executionError
        PreActionEnabledState = [bool]$preActionEnabledState
        PostActionEnabledState = $postActionEnabledState
        NoDeleteOccurred = $true
        NoRemoveOccurred = $true
        NoGrantCleanupOccurred = $true
        NoMetadataCleanupOccurred = $true
        NoCredentialDeletionOccurred = $true
        RollbackExecuted = $false
    }

    if ($OutputPath) {
        $artifactPath = Join-Path $OutputPath "Run4C-ExecutionEvidence-$RunId.json"
        $evidence | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $evidence -Path $artifactPath) -Force
    }

    return $evidence
}

function Invoke-NhiControlledLabRollback {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$OriginalDisableEvidence,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$RollbackExecutionReadinessPackage,

        [Parameter()]
        [object]$PostDisableObservation,

        [Parameter()]
        [object]$RollbackTrigger,

        [Parameter()]
        [bool]$HumanRollbackApprovalCaptured = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [bool]$WhatIf = $true
    )

    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $originalDisablePresent = $null -ne $OriginalDisableEvidence
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $rollbackDrillPackagePresent = $null -ne $RollbackDrillPackage
    $rollbackReadinessPackagePresent = $null -ne $RollbackExecutionReadinessPackage
    $rollbackTriggerPresent = $null -ne $RollbackTrigger -and @($RollbackTrigger).Count -gt 0
    $humanApprovalRequired = $true
    $humanApprovalCaptured = [bool]$HumanRollbackApprovalCaptured
    $rollbackReadinessState = [string](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionReadinessPackage -PropertyNames @('RollbackReadiness', 'Readiness', 'Status'))
    $rollbackDrillReady = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('Ready') -Default $false)

    if (-not $originalDisablePresent) { $reasons.Add('Original disable evidence is required.') }
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $rollbackDrillPackagePresent) { $reasons.Add('Rollback drill package is required.') }
    if (-not $rollbackReadinessPackagePresent) { $reasons.Add('Rollback execution readiness package is required.') }
    if (-not $rollbackTriggerPresent) { $reasons.Add('Observation failure or manual rollback trigger is required.') }
    if (-not $humanApprovalCaptured) { $reasons.Add('Human rollback approval is required and not captured.') }
    if ($rollbackDrillPackagePresent -and -not $rollbackDrillReady) { $reasons.Add('Rollback drill package is not ready.') }
    if ($rollbackReadinessPackagePresent -and $rollbackReadinessState -and $rollbackReadinessState -notin @('Ready', 'Complete')) { $reasons.Add('Rollback execution readiness package is not Ready.') }

    $rollbackAction = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    $commandPreview = if ($rollbackAction -eq 'ReEnableServicePrincipal') {
        'Preview only: re-enable the service principal after separate human approval.'
    } else {
        'No executable rollback command emitted.'
    }
    if ($rollbackAction -ne 'ReEnableServicePrincipal') { $reasons.Add('Rollback action must be re-enable only.') }

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    if ($requestedOperations -match '(?i)^Delete$|^FinalDelete$') { $reasons.Add('Delete request is blocked.') }
    if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { $reasons.Add('Remove request is blocked.') }
    if ($requestedOperations -match '(?i)^Recreate$') { $reasons.Add('Recreate request is blocked.') }
    if ($requestedOperations -match '(?i)^GrantCleanup$') { $reasons.Add('Grant cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^MetadataCleanup$') { $reasons.Add('Metadata cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^CredentialChange$|^CredentialDelete$') { $reasons.Add('Credential change request is blocked.') }
    if ($requestedOperations -match '(?i)^ExecuteNhiDecommission$|^ExecuteNhiControlledDecommission$|^ExecuteNhiControlledGrantCleanup$|^ExecuteNhiControlledMetadataCleanup$') { $reasons.Add('Execution command request is blocked.') }

    $package = [PSCustomObject]@{
        RollbackExecutionPackageId = "REV420-$RunId-$($targetContext.TargetObjectId)"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'ControlledRollbackPreviewOnly'
        TenantWritePerformed = $false
        RollbackPerformed = $false
        DisablePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetContext.TargetDisplayName
        TargetObjectId = $targetContext.TargetObjectId
        TargetAppId = $targetContext.TargetAppId
        TargetType = $targetContext.TargetType
        EnvironmentMarker = $targetContext.EnvironmentMarker
        Classification = $targetContext.Classification
        SuppressCustomerRemediation = $targetContext.SuppressCustomerRemediation
        EvidenceOnly = $targetContext.EvidenceOnly
        RollbackExecutionPackageMetadata = [PSCustomObject]@{
            RollbackExecutionPackageId = "REV420-$RunId-$($targetContext.TargetObjectId)"
            RunId = $RunId
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
            Mode = 'ControlledRollbackPreviewOnly'
            TenantWritePerformed = $false
            RollbackPerformed = $false
            DisablePerformed = $false
            FinalDeleteAllowed = $false
        }
        TargetSummary = [PSCustomObject]@{
            TargetDisplayName = $targetContext.TargetDisplayName
            TargetObjectId = $targetContext.TargetObjectId
            TargetAppId = $targetContext.TargetAppId
            TargetType = $targetContext.TargetType
            Environment = $targetContext.EnvironmentMarker
            Classification = $targetContext.Classification
            SuppressCustomerRemediation = $targetContext.SuppressCustomerRemediation
            EvidenceOnly = $targetContext.EvidenceOnly
        }
        RollbackReadinessSummary = [PSCustomObject]@{
            RollbackReadinessPackagePresent = $rollbackReadinessPackagePresent
            RollbackReadiness = if ($reasons.Count -eq 0 -and ($rollbackReadinessState -in @('', 'Ready', 'Complete'))) { 'Ready' } else { 'NotReady' }
            HumanRollbackApprovalRequired = $humanApprovalRequired
            HumanRollbackApprovalCaptured = $humanApprovalCaptured
            RollbackTriggerPresent = $rollbackTriggerPresent
            OriginalDisableEvidencePresent = $originalDisablePresent
            PreActionSnapshotPresent = $preActionSnapshotPresent
        }
        PlannedRollbackAction = [PSCustomObject]@{
            RollbackAction = 'ReEnableServicePrincipal'
            CommandPreview = $commandPreview
            WhatIf = $WhatIf
            ConfirmRequired = $true
            HumanApprovalRequired = $true
            RollbackExecutionPerformed = $false
        }
        SafetyAssertions = [PSCustomObject]@{
            NoDelete = $true
            NoRemoveServicePrincipal = $true
            NoRemoveApplication = $true
            NoRecreate = $true
            NoGrantCleanup = $true
            NoMetadataCleanup = $true
            NoCredentialChange = $true
            NoFinalDelete = $true
        }
        Evidence = [PSCustomObject]@{
            RollbackEvidencePath = (Join-Path $OutputPath "Run4C-ControlledRollbackPreview-$RunId.json")
            CorrelationId = [guid]::NewGuid().Guid
            SourceDisableEvidencePath = [string](Get-NhiControlledPropertyValue -InputObject $OriginalDisableEvidence -PropertyNames @('OutputArtifactPath', 'EvidencePath'))
            SourceSnapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotPath', 'Path', 'OutputArtifactPath'))
            SourceObservationPath = [string](Get-NhiControlledPropertyValue -InputObject $PostDisableObservation -PropertyNames @('OutputArtifactPath', 'ObservationPath', 'Path'))
            CapturedUtc = [DateTime]::UtcNow.ToString('o')
        }
        HumanRollbackApprovalRequired = $humanApprovalRequired
        HumanRollbackApprovalCaptured = $humanApprovalCaptured
        RollbackReadinessPackagePresent = $rollbackReadinessPackagePresent
        RollbackReadiness = if ($reasons.Count -eq 0 -and ($rollbackReadinessState -in @('', 'Ready', 'Complete'))) { 'Ready' } else { 'NotReady' }
        RollbackExecutionPerformed = $false
        Blockers = @($reasons)
        Warnings = @($warnings)
    }

    $gateChecks = [ordered]@{
        ExactlyOneTarget = $targetContext.TargetCount -eq 1
        LabOrDevTestOnly = $targetContext.IsLabOrDevTest
        OriginalDisableEvidencePresent = $originalDisablePresent
        PreActionSnapshotPresent = $preActionSnapshotPresent
        RollbackDrillPackagePresent = $rollbackDrillPackagePresent
        RollbackExecutionReadinessPackagePresent = $rollbackReadinessPackagePresent
        RollbackTriggerPresent = $rollbackTriggerPresent
        RollbackActionIsReEnableOnly = $rollbackAction -eq 'ReEnableServicePrincipal'
        HumanRollbackApprovalRequired = $humanApprovalRequired
        HumanRollbackApprovalCaptured = $humanApprovalCaptured
        NoDeleteRequested = -not ($requestedOperations -match '(?i)^Delete$|^FinalDelete$')
        NoRemoveRequested = -not ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$')
        NoRecreateRequested = -not ($requestedOperations -match '(?i)^Recreate$')
        NoGrantCleanupRequested = -not ($requestedOperations -match '(?i)^GrantCleanup$')
        NoMetadataCleanupRequested = -not ($requestedOperations -match '(?i)^MetadataCleanup$')
        NoCredentialChangeRequested = -not ($requestedOperations -match '(?i)^CredentialChange$|^CredentialDelete$')
        NoExecutionCommandRequested = -not ($requestedOperations -match '(?i)^ExecuteNhiDecommission$|^ExecuteNhiControlledDecommission$|^ExecuteNhiControlledGrantCleanup$|^ExecuteNhiControlledMetadataCleanup$')
    }

    foreach ($gateName in $gateChecks.Keys) {
        $passed = [bool]$gateChecks[$gateName]
        $severity = if ($passed) { 'Info' } else { 'High' }
        $reason = switch ($gateName) {
            'ExactlyOneTarget' { if ($passed) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } }
            'LabOrDevTestOnly' { if ($passed) { 'Target is labeled as lab/dev/test.' } else { 'Target is not labeled as lab/dev/test.' } }
            'OriginalDisableEvidencePresent' { if ($passed) { 'Original disable evidence is present.' } else { 'Original disable evidence is missing.' } }
            'PreActionSnapshotPresent' { if ($passed) { 'Pre-action snapshot is present.' } else { 'Pre-action snapshot is missing.' } }
            'RollbackDrillPackagePresent' { if ($passed) { 'Rollback drill package is present.' } else { 'Rollback drill package is missing.' } }
            'RollbackExecutionReadinessPackagePresent' { if ($passed) { 'Rollback execution readiness package is present.' } else { 'Rollback execution readiness package is missing.' } }
            'RollbackTriggerPresent' { if ($passed) { 'Rollback trigger is present.' } else { 'Rollback trigger is missing.' } }
            'RollbackActionIsReEnableOnly' { if ($passed) { 'Rollback action is re-enable only.' } else { 'Rollback action is not re-enable only.' } }
            'HumanRollbackApprovalRequired' { 'Human rollback approval is required.' }
            'HumanRollbackApprovalCaptured' { if ($passed) { 'Human rollback approval was captured.' } else { 'Human rollback approval is not captured.' } }
            'NoDeleteRequested' { if ($passed) { 'Delete was not requested.' } else { 'Delete was requested.' } }
            'NoRemoveRequested' { if ($passed) { 'Remove was not requested.' } else { 'Remove was requested.' } }
            'NoRecreateRequested' { if ($passed) { 'Recreate was not requested.' } else { 'Recreate was requested.' } }
            'NoGrantCleanupRequested' { if ($passed) { 'Grant cleanup was not requested.' } else { 'Grant cleanup was requested.' } }
            'NoMetadataCleanupRequested' { if ($passed) { 'Metadata cleanup was not requested.' } else { 'Metadata cleanup was requested.' } }
            'NoCredentialChangeRequested' { if ($passed) { 'Credential change was not requested.' } else { 'Credential change was requested.' } }
            'NoExecutionCommandRequested' { if ($passed) { 'No execution command was requested.' } else { 'Execution command was requested.' } }
        }
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gateName -Passed $passed -Severity $severity -Reason $reason))
    }

    $package | Add-Member -NotePropertyName GateVerdicts -NotePropertyValue @($gateVerdicts) -Force
    $package | Add-Member -NotePropertyName HumanApprovalRequired -NotePropertyValue $humanApprovalRequired -Force
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path (Join-Path $OutputPath "Run4C-ControlledRollbackPreview-$RunId.json")) -Force
    return $package
}

function New-NhiFinalDeleteEligibilitySimulationPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$PriorDisableEvidence,

        [Parameter()]
        [object]$PostDisableObservation,

        [Parameter()]
        [bool]$BusinessOwnerFinalApprovalPresent = $false,

        [Parameter()]
        [bool]$SecurityApprovalPresent = $false,

        [Parameter()]
        [bool]$RetentionWindowSatisfied = $false,

        [Parameter()]
        [bool]$DependencyCheckPassed = $false,

        [Parameter()]
        [Nullable[bool]]$NoActiveSignInsObserved,

        [Parameter()]
        [Nullable[bool]]$NoActiveGrantsRemaining,

        [Parameter()]
        [Nullable[bool]]$NoCredentialRiskRemaining,

        [Parameter()]
        [bool]$FinalDeleteSeparateApprovalRequired = $true,

        [Parameter()]
        [bool]$HumanDecisionCaptured = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $priorDisableEvidencePresent = $null -ne $PriorDisableEvidence
    $postDisableObservationCompleted = $null -ne $PostDisableObservation
    $noActiveSignIns = if ($PSBoundParameters.ContainsKey('NoActiveSignInsObserved')) { [bool]$NoActiveSignInsObserved } else { $false }
    $noActiveGrants = if ($PSBoundParameters.ContainsKey('NoActiveGrantsRemaining')) { [bool]$NoActiveGrantsRemaining } else { $false }
    $noCredentialRisk = if ($PSBoundParameters.ContainsKey('NoCredentialRiskRemaining')) { [bool]$NoCredentialRiskRemaining } else { $false }
    $firstPartyMicrosoftApp = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) } else { $false }
    $actualDeleteRequested = $requestedOperations -match '(?i)^Delete$|^FinalDelete$'
    $removeRequested = $requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$'
    $grantCleanupRequested = $requestedOperations -match '(?i)^GrantCleanup$'
    $metadataCleanupRequested = $requestedOperations -match '(?i)^MetadataCleanup$'
    $credentialDeletionRequested = $requestedOperations -match '(?i)^CredentialDelete$|^CredentialChange$'
    $recreateRequested = $requestedOperations -match '(?i)^Recreate$'

    if (-not $priorDisableEvidencePresent) { $reasons.Add('Prior reversible disable evidence is required.') }
    if (-not $postDisableObservationCompleted) { $reasons.Add('Post-disable observation completion is required.') }
    if (-not $BusinessOwnerFinalApprovalPresent) { $reasons.Add('Business owner final approval is required.') }
    if (-not $SecurityApprovalPresent) { $reasons.Add('Security approval is required.') }
    if (-not $RetentionWindowSatisfied) { $reasons.Add('Retention window must be satisfied.') }
    if (-not $DependencyCheckPassed) { $reasons.Add('Dependency check must pass.') }
    if ($firstPartyMicrosoftApp) { $reasons.Add('First-party Microsoft app target is blocked.') }
    if (-not $noActiveSignIns) { $reasons.Add('No active sign-ins must be observed.') }
    if (-not $noActiveGrants) { $reasons.Add('No active grants remaining must be confirmed.') }
    if (-not $noCredentialRisk) { $reasons.Add('No credential risk remaining must be confirmed.') }
    if ($actualDeleteRequested) { $reasons.Add('Actual delete request is blocked.') }
    if ($removeRequested) { $reasons.Add('Remove request is blocked.') }
    if ($grantCleanupRequested) { $reasons.Add('Grant cleanup request is blocked.') }
    if ($metadataCleanupRequested) { $reasons.Add('Metadata cleanup request is blocked.') }
    if ($credentialDeletionRequested) { $reasons.Add('Credential deletion request is blocked.') }
    if ($recreateRequested) { $reasons.Add('Recreate request is blocked.') }

    $package = [PSCustomObject]@{
        SimulationPackageId = "REV421-$RunId-$($targetContext.TargetObjectId)"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'FinalDeleteEligibilitySimulationOnly'
        TenantWritePerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        ExecutionCommandEmitted = $false
        TargetDisplayName = $targetContext.TargetDisplayName
        TargetObjectId = $targetContext.TargetObjectId
        TargetAppId = $targetContext.TargetAppId
        TargetType = $targetContext.TargetType
        Classification = $targetContext.Classification
        EnvironmentMarker = $targetContext.EnvironmentMarker
        SuppressCustomerRemediation = $targetContext.SuppressCustomerRemediation
        EvidenceOnly = $targetContext.EvidenceOnly
        InformationOnly = $targetContext.InformationOnly
        SimulatedOnly = $true
        ReadyForActualDelete = $false
        RequiredSeparateApproval = $true
        HumanDecisionCaptured = [bool]$HumanDecisionCaptured
        CommandPreview = 'No executable final-delete command emitted; simulation only.'
        ProhibitedActions = @('actual final delete', 'remove service principal', 'remove application', 'grant cleanup', 'metadata cleanup', 'credential deletion')
        EligibilityGates = @()
        FinalDeleteEligibility = if ($reasons.Count -eq 0) { 'Eligible' } else { 'NotEligible' }
        Blockers = @($reasons)
        Warnings = @($warnings)
        Explanation = [PSCustomObject]@{
            WhyFinalDeleteIsNotExecuted = 'This package is simulation only and never executes live mutation.'
            FutureEvidenceRequired = @('separate approval', 'completed observation', 'retention window', 'dependency clearance')
            WhySeparateMilestone = 'Final delete must remain a separate approval milestone from reversible disable.'
            WhySimulationIsSafer = 'Simulation proves the decision gates without producing live tenant changes.'
        }
        Evidence = [PSCustomObject]@{
            SimulationEvidencePath = (Join-Path $OutputPath "Run4C-FinalDeleteEligibilitySimulation-$RunId.json")
            CorrelationId = [guid]::NewGuid().Guid
            SourceDisableEvidencePath = [string](Get-NhiControlledPropertyValue -InputObject $PriorDisableEvidence -PropertyNames @('OutputArtifactPath', 'EvidencePath'))
            SourceSnapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $PriorDisableEvidence -PropertyNames @('SnapshotPath', 'PreActionSnapshotPath', 'OutputArtifactPath'))
            SourceObservationPath = [string](Get-NhiControlledPropertyValue -InputObject $PostDisableObservation -PropertyNames @('OutputArtifactPath', 'ObservationPath', 'Path'))
            CapturedUtc = [DateTime]::UtcNow.ToString('o')
        }
    }

    $gateDefinitions = @(
        @{ GateName = 'ExactlyOneTarget'; Passed = ($targetContext.TargetCount -eq 1); Reason = if ($targetContext.TargetCount -eq 1) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } },
        @{ GateName = 'LabOrDevTestOnly'; Passed = $targetContext.IsLabOrDevTest; Reason = if ($targetContext.IsLabOrDevTest) { 'Target is labeled as lab/dev/test.' } else { 'Target is not labeled as lab/dev/test.' } },
        @{ GateName = 'NotMicrosoftPlatform'; Passed = -not $targetContext.MicrosoftPlatform; Reason = if ($targetContext.MicrosoftPlatform) { 'MicrosoftPlatform target is blocked.' } else { 'Target is not MicrosoftPlatform.' } },
        @{ GateName = 'NotFirstPartyMicrosoftApp'; Passed = -not $targetContext.FirstPartyMicrosoftApp; Reason = if ($targetContext.FirstPartyMicrosoftApp) { 'First-party Microsoft app target is blocked.' } else { 'Target is not a first-party Microsoft app.' } },
        @{ GateName = 'NotExternalVendorPlatform'; Passed = -not ($targetContext.Classification -eq 'ExternalVendorPlatform'); Reason = if ($targetContext.Classification -eq 'ExternalVendorPlatform') { 'ExternalVendorPlatform target is blocked.' } else { 'Target is not ExternalVendorPlatform.' } },
        @{ GateName = 'NotSuppressed'; Passed = -not $targetContext.SuppressCustomerRemediation; Reason = if ($targetContext.SuppressCustomerRemediation) { 'SuppressCustomerRemediation target is blocked.' } else { 'Target is not suppressed.' } },
        @{ GateName = 'NotEvidenceOnly'; Passed = -not $targetContext.EvidenceOnly; Reason = if ($targetContext.EvidenceOnly) { 'EvidenceOnly target is blocked.' } else { 'Target is not evidence-only.' } },
        @{ GateName = 'PriorReversibleDisableEvidencePresent'; Passed = $priorDisableEvidencePresent; Reason = if ($priorDisableEvidencePresent) { 'Prior disable evidence is present.' } else { 'Prior disable evidence is missing.' } },
        @{ GateName = 'PostDisableObservationCompleted'; Passed = $postDisableObservationCompleted; Reason = if ($postDisableObservationCompleted) { 'Post-disable observation is complete.' } else { 'Post-disable observation is missing.' } },
        @{ GateName = 'NoRollbackNeededOrRollbackWindowExpired'; Passed = $RetentionWindowSatisfied; Reason = if ($RetentionWindowSatisfied) { 'Rollback window has expired or is not needed.' } else { 'Rollback window is still open or not proven.' } },
        @{ GateName = 'BusinessOwnerFinalApprovalPresent'; Passed = $BusinessOwnerFinalApprovalPresent; Reason = if ($BusinessOwnerFinalApprovalPresent) { 'Business owner final approval is present.' } else { 'Business owner final approval is missing.' } },
        @{ GateName = 'SecurityApprovalPresent'; Passed = $SecurityApprovalPresent; Reason = if ($SecurityApprovalPresent) { 'Security approval is present.' } else { 'Security approval is missing.' } },
        @{ GateName = 'RetentionWindowSatisfied'; Passed = $RetentionWindowSatisfied; Reason = if ($RetentionWindowSatisfied) { 'Retention window is satisfied.' } else { 'Retention window is not satisfied.' } },
        @{ GateName = 'DependencyCheckPassed'; Passed = $DependencyCheckPassed; Reason = if ($DependencyCheckPassed) { 'Dependency check passed.' } else { 'Dependency check failed.' } },
        @{ GateName = 'NoActiveSignInsObserved'; Passed = $noActiveSignIns; Reason = if ($noActiveSignIns) { 'No active sign-ins were observed.' } else { 'Active sign-ins remain or were not proven absent.' } },
        @{ GateName = 'NoActiveGrantsRemaining'; Passed = $noActiveGrants; Reason = if ($noActiveGrants) { 'No active grants remain.' } else { 'Active grants remain or were not proven absent.' } },
        @{ GateName = 'NoCredentialRiskRemaining'; Passed = $noCredentialRisk; Reason = if ($noCredentialRisk) { 'No credential risk remains.' } else { 'Credential risk remains or was not proven absent.' } },
        @{ GateName = 'FinalDeleteSeparateApprovalRequired'; Passed = $FinalDeleteSeparateApprovalRequired; Reason = 'Final delete requires a separate approval milestone.' }
    )

    foreach ($gate in $gateDefinitions) {
        $passed = [bool]$gate.Passed
        $severity = if ($passed) { 'Info' } else { 'High' }
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gate.GateName -Passed $passed -Severity $severity -Reason $gate.Reason))
    }

    $package | Add-Member -NotePropertyName EligibilityGates -NotePropertyValue @($gateVerdicts) -Force
    $artifactPath = Join-Path $OutputPath "Run4C-FinalDeleteEligibilitySimulation-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}
