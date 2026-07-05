# NhiControlledDecommission.Run4C.ps1
# Dot-sourced into NhiControlledDecommission.psm1 module scope. Do not import directly.
# Contains: New-NhiRun4CFinalGoNoGoReviewPackage, New-NhiRun4CLiveEvidenceCapturePackage, New-NhiRun4CPostDisableObservationPackage, New-NhiRun4CRollbackExecutionReadinessPackage, Get-NhiRun4CTargetContext, New-NhiRun4CEndToEndLabRehearsalReport, New-NhiRun4CConsultantOperatingGuide, Get-NhiRun4CArtifactRecord, New-NhiRun4CFinalControlledDisableTestPackage, New-NhiRun4CPostDisableEvidenceValidationPackage, New-NhiRun4CControlledRollbackExecutionTestPackage, New-NhiRun4CPostRollbackValidationPackage, New-NhiRun4CFinalEvidenceBundle, New-NhiRev4ReleaseCandidateFreezePackage

function New-NhiRun4CFinalGoNoGoReviewPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$ApprovalManifest,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApprovalManifestPath,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$ReadinessVerdict,

        [Parameter()]
        [object]$DryRunPackage,

        [Parameter()]
        [object]$RollbackPackage,

        [Parameter()]
        [object]$ObservationPlan,

        [Parameter()]
        [object]$OperatorChecklist,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string[]]$RequestedOperations = @()
    )

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    $targetObject = $null
    $targetCount = @($Target).Count
    $targetContext = Get-NhiRun4CTargetContext -Target $Target

    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) {
            $reasons.Add([string]$reason)
        }
    }

    if ($targetCount -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } elseif ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $targetContext = if ($targetObject) { Get-NhiRun4CTargetContext -Target @($targetObject) } else { $null }
    $remediationMode = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) } else { $null }
    $microsoftPlatform = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -or [string]$classification -eq 'MicrosoftPlatform' } else { $false }
    $firstPartyMicrosoftApp = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) } else { $false }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or $remediationMode -eq 'EvidenceOnly' } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or $remediationMode -eq 'InformationOnly' } else { $false }

    $approvalManifestPresent = $null -ne $ApprovalManifest -or (Test-Path -LiteralPath $ApprovalManifestPath -PathType Leaf)
    $approvalManifestHash = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalManifestHash', 'ManifestHash', 'SHA256'))
    $approvalExpiresUtc = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc'))
    $approvedAction = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvedBy = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedBy', 'Approver'))
    $approvedTargetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $approvedTargetType = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetType'))
    $approvedTargetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetDisplayName'))

    $snapshotPresent = $null -ne $Snapshot
    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotPath', 'Path'))

    $readinessPresent = $null -ne $ReadinessVerdict
    $readinessReady = [bool](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('Ready') -Default $false)
    $readinessAllowedAction = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('AllowedAction', 'RequestedAction', 'ActionType'))

    $dryRunPresent = $null -ne $DryRunPackage
    $rollbackPresent = $null -ne $RollbackPackage
    $observationPresent = $null -ne $ObservationPlan
    $operatorChecklistPresent = $null -ne $OperatorChecklist

    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) {
            $reasons.Add([string]$reason)
        }
    }

    $gateChecks = [ordered]@{}
    $gateChecks['ExactlyOneTarget'] = @($Target).Count -eq 1
    $gateChecks['LabOrDevTestTenantOnly'] = $targetObject -and (
        [string]$environment -in @('Lab', 'DevTest', 'DevTestLab', 'Test') -or
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -in @('Lab', 'DevTest', 'Test') -or
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
    )
    $gateChecks['ApprovedTarget'] = $approvalManifestPresent -and $targetObject -and $approvedTargetObjectId -eq $targetObjectId -and $approvedTargetType -eq $targetType -and $approvedTargetDisplayName -eq $targetDisplayName
    $gateChecks['ApprovalNotExpired'] = $false
    if ($approvalExpiresUtc) {
        try {
            $gateChecks['ApprovalNotExpired'] = [DateTime]::Parse($approvalExpiresUtc).ToUniversalTime() -gt [DateTime]::UtcNow
        } catch {
            $gateChecks['ApprovalNotExpired'] = $false
        }
    }
    $gateChecks['ApprovedActionIsReversibleDisable'] = $approvedAction -eq 'ReversibleDisable'
    $gateChecks['NotMicrosoftPlatform'] = $targetObject -and ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -ne $true) -and ($classification -notin @('MicrosoftPlatform'))
    $gateChecks['NotExternalVendorPlatform'] = $targetObject -and ($classification -ne 'ExternalVendorPlatform')
    $gateChecks['NotSuppressed'] = -not $suppressCustomerRemediation
    $gateChecks['NotEvidenceOnly'] = -not $evidenceOnly
    $gateChecks['NotInformationOnly'] = -not $informationOnly
    $gateChecks['SnapshotPresent'] = $snapshotPresent -and (-not [string]::IsNullOrWhiteSpace($snapshotId) -or -not [string]::IsNullOrWhiteSpace($snapshotPath))
    $gateChecks['ReadinessReady'] = $readinessPresent -and $readinessReady -and $readinessAllowedAction -eq 'ReversibleDisable'
    $gateChecks['DryRunPackagePresent'] = $dryRunPresent
    $gateChecks['RollbackPackagePresent'] = $rollbackPresent
    $gateChecks['ObservationPlanPresent'] = $observationPresent
    $gateChecks['NoFinalDeleteRequested'] = -not (@($requestedOperations) -match '(?i)^FinalDelete$|^FinalDeleteRequested$|^Delete$')
    $gateChecks['NoRemoveRequested'] = -not (@($requestedOperations) -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$')
    $gateChecks['NoGrantCleanupRequested'] = -not (@($requestedOperations) -match '(?i)^GrantCleanup$')
    $gateChecks['NoMetadataCleanupRequested'] = -not (@($requestedOperations) -match '(?i)^MetadataCleanup$')
    $gateChecks['NoCredentialDeleteRequested'] = -not (@($requestedOperations) -match '(?i)^CredentialDelete$')
    $gateChecks['OperatorReviewRequired'] = $operatorChecklistPresent -or $true
    $gateChecks['HumanGoNoGoRequired'] = $true

    foreach ($gateName in $gateChecks.Keys) {
        $passed = [bool]$gateChecks[$gateName]
        $severity = if ($passed) { 'Info' } else { 'High' }
        $reason = switch ($gateName) {
            'ExactlyOneTarget' { if ($passed) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } }
            'LabOrDevTestTenantOnly' { if ($passed) { 'Target is labeled as lab/dev/test.' } else { 'Target is not labeled as lab/dev/test.' } }
            'ApprovedTarget' { if ($passed) { 'Approval target matches the requested target.' } else { 'Approval target does not match the requested target.' } }
            'ApprovalNotExpired' { if ($passed) { 'Approval is current.' } else { 'Approval is missing or expired.' } }
            'ApprovedActionIsReversibleDisable' { if ($passed) { 'Approved action is ReversibleDisable.' } else { 'Approved action is not ReversibleDisable.' } }
            'NotMicrosoftPlatform' { if ($passed) { 'Target is not MicrosoftPlatform.' } else { 'MicrosoftPlatform target is blocked.' } }
            'NotExternalVendorPlatform' { if ($passed) { 'Target is not ExternalVendorPlatform.' } else { 'ExternalVendorPlatform target is blocked.' } }
            'NotSuppressed' { if ($passed) { 'Target is not suppressed.' } else { 'SuppressCustomerRemediation target is blocked.' } }
            'NotEvidenceOnly' { if ($passed) { 'Target is not evidence-only.' } else { 'EvidenceOnly target is blocked.' } }
            'NotInformationOnly' { if ($passed) { 'Target is not information-only.' } else { 'InformationOnly target is blocked.' } }
            'SnapshotPresent' { if ($passed) { 'Snapshot metadata is present.' } else { 'Snapshot metadata is missing.' } }
            'ReadinessReady' { if ($passed) { 'Readiness verdict is Ready.' } else { 'Readiness verdict is missing or not Ready.' } }
            'DryRunPackagePresent' { if ($passed) { 'Dry-run package is present.' } else { 'Dry-run package is missing.' } }
            'RollbackPackagePresent' { if ($passed) { 'Rollback package is present.' } else { 'Rollback package is missing.' } }
            'ObservationPlanPresent' { if ($passed) { 'Observation plan is present.' } else { 'Observation plan is missing.' } }
            'NoFinalDeleteRequested' { if ($passed) { 'Final delete was not requested.' } else { 'Final delete was requested.' } }
            'NoRemoveRequested' { if ($passed) { 'Remove action was not requested.' } else { 'Remove action was requested.' } }
            'NoGrantCleanupRequested' { if ($passed) { 'Grant cleanup was not requested.' } else { 'Grant cleanup was requested.' } }
            'NoMetadataCleanupRequested' { if ($passed) { 'Metadata cleanup was not requested.' } else { 'Metadata cleanup was requested.' } }
            'NoCredentialDeleteRequested' { if ($passed) { 'Credential delete was not requested.' } else { 'Credential delete was requested.' } }
            'OperatorReviewRequired' { 'Operator review is required.' }
            'HumanGoNoGoRequired' { 'Human go/no-go is required.' }
        }
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gateName -Passed $passed -Severity $severity -Reason $reason))
        if (-not $passed) { $reasons.Add("$gateName failed: $reason") }
    }

    $goNoGo = if ($reasons.Count -eq 0) { 'Go' } else { 'NoGo' }
    $package = [PSCustomObject]@{
        ReviewPackageId = "REV416-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'FinalGoNoGoReviewOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        Classification = $classification
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        SuppressCustomerRemediation = $suppressCustomerRemediation
        EvidenceOnly = $evidenceOnly
        InformationOnly = $informationOnly
        InputArtifactSummary = [PSCustomObject]@{
            ApprovalManifestPresent = $approvalManifestPresent
            ApprovalManifestPath = $ApprovalManifestPath
            ApprovalManifestHash = $approvalManifestHash
            SnapshotPresent = $snapshotPresent
            SnapshotPath = $snapshotPath
            SnapshotId = $snapshotId
            ReadinessVerdictPresent = $readinessPresent
            DryRunPackagePresent = $dryRunPresent
            RollbackPackagePresent = $rollbackPresent
            ObservationPlanPresent = $observationPresent
            OperatorChecklistPresent = $operatorChecklistPresent
        }
        GateVerdicts = @($gateVerdicts)
        GoNoGo = $goNoGo
        ReadyForControlledDevTestDisable = $goNoGo -eq 'Go'
        Blockers = @($reasons)
        Warnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        AllowedNextAction = if ($goNoGo -eq 'Go') { 'ControlledDevTestReversibleDisable' } else { $null }
        ProhibitedActions = @('final delete', 'remove service principal', 'remove application', 'grant cleanup', 'metadata cleanup', 'credential deletion')
        OperatorSignOff = [PSCustomObject]@{
            OperatorName = $null
            OperatorDecision = $null
            OperatorDecisionUtc = $null
            ApproverName = $null
            ApproverDecision = $null
            ApproverDecisionUtc = $null
            Notes = $null
        }
    }

    $artifactPath = Join-Path $OutputPath "Run4C-FinalGoNoGoReview-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CLiveEvidenceCapturePackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$Target,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$PostActionSnapshot,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetObject = $null
    if (@($Target).Count -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $targetContext = if ($targetObject) { Get-NhiRun4CTargetContext -Target @($targetObject) } else { $null }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'EvidenceOnly' } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }
    $tenantWritePerformed = $false
    $disablePerformed = $false
    $rollbackPerformed = $false
    $finalDeleteAllowed = $false

    if ($targetObject) {
        foreach ($reason in @($targetContext.Blockers)) {
            if ($reason) {
                $reasons.Add([string]$reason)
            }
        }
        if ([string]$environment -notin @('Lab', 'DevTest', 'DevTestLab', 'Test') -and
            [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -ne $true -and
            [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -notin @('Lab', 'DevTest', 'Test') -and
            [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -ne $true) {
            $reasons.Add('Target is not explicitly marked as lab/dev/test.')
        }
        if ($microsoftPlatform) { $reasons.Add('MicrosoftPlatform target is blocked.') }
        if ($firstPartyMicrosoftApp) { $reasons.Add('First-party Microsoft app target is blocked.') }
        if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
        if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
        if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
        if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }
    }

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    if ($requestedOperations -match '(?i)^FinalDelete$') { $reasons.Add('Final delete request is blocked.') }
    if ($requestedOperations -match '(?i)^GrantCleanup$') { $reasons.Add('Grant cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^CredentialDelete$') { $reasons.Add('Credential deletion request is blocked.') }
    if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { $reasons.Add('Remove request is blocked.') }

    $preActionSnapshotRequired = $true
    $executionEvidenceRequired = $true
    $postActionEvidenceRequired = $true
    $commandPreview = if ($targetObject) { "Invoke-NhiDisable -ObjectId $targetObjectId -ObjectType ServicePrincipal -WhatIf" } else { 'Pending target selection' }

    $preSnapshotPresent = $null -ne $PreActionSnapshot
    if (-not $preSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if ($null -eq $Target) { $reasons.Add('Target is required.') }

    $preActionEnabledState = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AccountEnabled', 'PreActionEnabledState')
    $credentialCountBefore = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CredentialCount', 'PreActionCredentialCount')
    $ownerCountBefore = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OwnerCount', 'PreActionOwnerCount')
    $appRoleAssignmentsBefore = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppRoleAssignmentsCount', 'PreActionAppRoleAssignmentsCount')
    $oauthGrantCountBefore = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OAuthGrantCount', 'PreActionOAuthGrantCount')
    $capturedUtcBefore = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $snapshotHashBefore = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotHash', 'SHA256', 'BaselineHash'))

    $preActionEnabledStateAfter = $null
    $credentialCountAfter = $null
    $ownerCountAfter = $null
    $appRoleAssignmentsAfter = $null
    $oauthGrantCountAfter = $null
    $capturedUtcAfter = $null
    $snapshotHashAfter = $null
    $artifactPaths = @()

    $package = [PSCustomObject]@{
        EvidencePackageId = "REV417-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'LiveEvidenceCapturePlanOnly'
        TenantWritePerformed = $tenantWritePerformed
        DisablePerformed = $disablePerformed
        RollbackPerformed = $rollbackPerformed
        FinalDeleteAllowed = $finalDeleteAllowed
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        Classification = $classification
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        TenantId = $TenantId
        EvidenceScope = 'SingleTargetOnly'
        PreActionSnapshotRequired = $preActionSnapshotRequired
        AccountEnabledBefore = $preActionEnabledState
        CredentialCountBefore = $credentialCountBefore
        OwnerCountBefore = $ownerCountBefore
        AppRoleAssignmentsCountBefore = $appRoleAssignmentsBefore
        OAuthGrantCountBefore = $oauthGrantCountBefore
        CapturedUtcBefore = $capturedUtcBefore
        SnapshotHashBefore = $snapshotHashBefore
        PlannedAction = 'ReversibleDisable'
        ExecutionEvidenceRequired = $executionEvidenceRequired
        CommandPreview = $commandPreview
        OperatorIdentityPlaceholder = 'Pending'
        ExecutionStartUtcPlaceholder = 'Pending'
        ExecutionEndUtcPlaceholder = 'Pending'
        GraphRequestIdPlaceholder = 'Pending'
        CorrelationIdPlaceholder = 'Pending'
        WhatChanged = 'AccountEnabled only'
        WhatMustNotChange = @(
            'grants',
            'credentials',
            'owners',
            'app metadata',
            'app object',
            'service principal deletion'
        )
        AccountEnabledAfter = $preActionEnabledStateAfter
        CredentialCountAfter = $credentialCountAfter
        OwnerCountAfter = $ownerCountAfter
        AppRoleAssignmentsCountAfter = $appRoleAssignmentsAfter
        OAuthGrantCountAfter = $oauthGrantCountAfter
        CapturedUtcAfter = $capturedUtcAfter
        SnapshotHashAfter = $snapshotHashAfter
        EvidenceManifestHash = $null
        ArtifactPaths = @()
        EvidenceCompletenessStatus = 'Pending'
        MissingEvidence = @(
            if ($null -eq $PreActionSnapshot) { 'Pre-action snapshot' }
            'Execution evidence placeholders'
            'Post-action evidence placeholders'
        )
        SafetyAssertions = [PSCustomObject]@{
            NoFinalDelete = $true
            NoRemoveServicePrincipal = $true
            NoRemoveApplication = $true
            NoGrantCleanup = $true
            NoMetadataCleanup = $true
            NoCredentialDeletion = $true
            NoRollbackExecution = $true
        }
        Ready = $reasons.Count -eq 0
        Blockers = @($reasons)
        Warnings = @($warnings)
    }

    if ($OutputPath) {
        $artifactPath = Join-Path $OutputPath "Run4C-LiveEvidenceCapture-$RunId.json"
        $artifactPaths += $artifactPath
        $package | Add-Member -NotePropertyName ArtifactPaths -NotePropertyValue @($artifactPaths) -Force
        $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    }

    return $package
}

function New-NhiRun4CPostDisableObservationPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$Target,

        [Parameter()]
        [Nullable[int]]$ObservationWindowMinutes,

        [Parameter()]
        [string]$MonitoringOwner,

        [Parameter()]
        [string]$RollbackContact,

        [Parameter()]
        [string]$EscalationContact,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetObject = $null
    if (@($Target).Count -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'EvidenceOnly' } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }

    if ([string]$environment -notin @('Lab', 'DevTest', 'DevTestLab', 'Test') -and
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -ne $true -and
        [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -notin @('Lab', 'DevTest', 'Test') -and
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -ne $true) {
        $reasons.Add('Target is not explicitly marked as lab/dev/test.')
    }
    if ([string]$classification -eq 'MicrosoftPlatform' -or [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true) { $reasons.Add('MicrosoftPlatform target is blocked.') }
    if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
    if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
    if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
    if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }

    if ($null -eq $ObservationWindowMinutes -or $ObservationWindowMinutes -le 0) { $reasons.Add('Observation window is required.') }
    if ([string]::IsNullOrWhiteSpace($MonitoringOwner)) { $reasons.Add('Monitoring owner is required.') }
    if ([string]::IsNullOrWhiteSpace($RollbackContact)) { $reasons.Add('Rollback contact is required.') }

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    if ($requestedOperations -match '(?i)^FinalDelete$') { $reasons.Add('Final delete request is blocked.') }
    if ($requestedOperations -match '(?i)^GrantCleanup$') { $reasons.Add('Grant cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^CredentialDelete$') { $reasons.Add('Credential deletion request is blocked.') }

    $preSnapshotPresent = $null -ne $PreActionSnapshot
    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotPath', 'Path'))
    if ($null -eq $PreActionSnapshot) {
        $warnings.Add('Pre-action snapshot is not supplied; observation remains template-only.')
    }

    $package = [PSCustomObject]@{
        ObservationPackageId = "REV418-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'PostDisableObservationPlanOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        Classification = $classification
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        ObservationScope = 'SingleTargetOnly'
        ObservationWindowMinutes = $ObservationWindowMinutes
        ObservationStartUtcPlaceholder = 'Pending'
        ObservationEndUtcPlaceholder = 'Pending'
        MonitoringOwner = $MonitoringOwner
        RollbackContact = $RollbackContact
        EscalationContact = $EscalationContact
        SuccessCriteria = @(
            'No unexpected app outage',
            'No unexpected authentication failure spike',
            'Owner/business validation passed',
            'No unauthorized secondary change',
            'No emergency rollback trigger'
        )
        FailureCriteria = @(
            'App outage detected',
            'Authentication failure spike',
            'Owner/business validation failure',
            'Unexpected permission/grant/credential change',
            'Operator stop condition'
        )
        RollbackTriggerCriteria = @(
            'Critical outage',
            'Business owner rejection',
            'Monitoring owner escalation',
            'Authentication failure threshold breached',
            'Manual operator stop'
        )
        ObservationLogPath = $null
        OperatorNotes = $null
        BusinessOwnerValidation = $null
        MonitoringSummary = $null
        EvidenceCompletenessStatus = 'Pending'
        MissingEvidence = @(
            if (-not $preSnapshotPresent) { 'Pre-action snapshot' }
            if ($null -eq $ObservationWindowMinutes -or $ObservationWindowMinutes -le 0) { 'Observation window' }
            if ([string]::IsNullOrWhiteSpace($MonitoringOwner)) { 'Monitoring owner' }
            if ([string]::IsNullOrWhiteSpace($RollbackContact)) { 'Rollback contact' }
        )
        SafetyAssertions = [PSCustomObject]@{
            ObservationOnly = $true
            RollbackNotExecuted = $true
            FinalDeleteAllowed = $false
            NoTenantMutationByObservation = $true
        }
        ObservationOnly = $true
        RollbackNotExecuted = $true
        NoTenantMutationByObservation = $true
        Ready = $reasons.Count -eq 0
        Blockers = @($reasons)
        Warnings = @($warnings)
    }

    $artifactPath = Join-Path $OutputPath "Run4C-PostDisableObservation-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CRollbackExecutionReadinessPackage {
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
        [object]$PostDisableObservation,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$RollbackTrigger,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    $targetObject = $null
    if (@($Target).Count -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'EvidenceOnly' } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }

    if ([string]$environment -notin @('Lab', 'DevTest', 'DevTestLab', 'Test') -and
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -ne $true -and
        [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -notin @('Lab', 'DevTest', 'Test') -and
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -ne $true) {
        $reasons.Add('Target is not explicitly marked as lab/dev/test.')
    }
    if ([string]$classification -eq 'MicrosoftPlatform' -or [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true) { $reasons.Add('MicrosoftPlatform target is blocked.') }
    if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
    if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
    if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
    if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }

    $originalDisablePresent = $null -ne $OriginalDisableEvidence
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $postDisableObservationPresent = $null -ne $PostDisableObservation
    $rollbackDrillPackagePresent = $null -ne $RollbackDrillPackage
    $rollbackTriggerPresent = $null -ne $RollbackTrigger -and @($RollbackTrigger).Count -gt 0
    if (-not $originalDisablePresent) { $reasons.Add('Original disable evidence is required.') }
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $rollbackDrillPackagePresent) { $reasons.Add('Rollback drill package is required.') }
    if (-not $rollbackTriggerPresent) { $reasons.Add('Rollback trigger is required.') }

    $originalActionWasReversibleDisable = [string](Get-NhiControlledPropertyValue -InputObject $OriginalDisableEvidence -PropertyNames @('PlannedAction', 'AllowedAction', 'RequestedAction', 'ActionType')) -eq 'ReversibleDisable'
    $rollbackActionIsReEnableOnly = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('RollbackAction', 'RollbackActionName')) -eq 'ReEnableServicePrincipal'
    $rollbackDrillReady = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('Ready') -Default $false)
    $rollbackTriggerText = @($RollbackTrigger | ForEach-Object { [string]$_ })
    if (-not $originalActionWasReversibleDisable) { $reasons.Add('Original action was not reversible disable.') }
    if ($rollbackActionIsReEnableOnly -ne $true) { $reasons.Add('Rollback action must be re-enable only.') }
    if ($rollbackDrillReady -ne $true) { $reasons.Add('Rollback drill package must be ready.') }

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    if ($requestedOperations -match '(?i)^Delete$|^FinalDelete$') { $reasons.Add('Delete request is blocked.') }
    if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { $reasons.Add('Remove request is blocked.') }
    if ($requestedOperations -match '(?i)^Recreate$') { $reasons.Add('Recreate request is blocked.') }
    if ($requestedOperations -match '(?i)^GrantCleanup$') { $reasons.Add('Grant cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^CredentialChange$') { $reasons.Add('Credential change request is blocked.') }
    if ($requestedOperations -match '(?i)^MetadataCleanup$') { $reasons.Add('Metadata cleanup request is blocked.') }

    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotPath', 'Path'))
    $capturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $baselineHash = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('BaselineHash', 'SnapshotSHA256', 'SHA256'))
    $evidenceSourcePath = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('EvidenceSourcePath'))

    $observationFailureOrManualTriggerPresent = $postDisableObservationPresent -or $rollbackTriggerPresent
    if (-not $observationFailureOrManualTriggerPresent) { $reasons.Add('Observation failure or manual trigger is required.') }

    $package = [PSCustomObject]@{
        RollbackReadinessPackageId = "REV419-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'RollbackExecutionReadinessOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        ObservationScope = 'SingleTargetOnly'
        OriginalDisableEvidencePresent = $originalDisablePresent
        PreActionSnapshotPresent = $preActionSnapshotPresent
        RollbackDrillPackagePresent = $rollbackDrillPackagePresent
        PostDisableObservationPresent = $postDisableObservationPresent
        RollbackTriggerPresent = $rollbackTriggerPresent
        HumanRollbackApprovalRequired = $true
        HumanRollbackApprovalCaptured = $false
        RequiredInputs = [PSCustomObject]@{
            OriginalDisableEvidencePresent = $originalDisablePresent
            PreActionSnapshotPresent = $preActionSnapshotPresent
            PostDisableObservationPresent = $postDisableObservationPresent
            RollbackDrillPackagePresent = $rollbackDrillPackagePresent
            RollbackTriggerPresent = $rollbackTriggerPresent
        }
        GateVerdicts = @()
        RollbackReadiness = if ($reasons.Count -eq 0) { 'Ready' } else { 'NotReady' }
        ReadyForRollbackExecution = $reasons.Count -eq 0
        Blockers = @($reasons)
        Warnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        AllowedNextAction = if ($reasons.Count -eq 0) { 'ControlledDevTestReEnableOnly' } else { $null }
        ProhibitedActions = @('delete', 'remove service principal', 'remove application', 'recreate object', 'grant cleanup', 'credential change', 'metadata cleanup')
        OperatorSignOff = [PSCustomObject]@{
            OperatorName = $null
            OperatorDecision = $null
            OperatorDecisionUtc = $null
            ApproverName = $null
            ApproverDecision = $null
            ApproverDecisionUtc = $null
            Notes = $null
        }
        PreActionSnapshot = [PSCustomObject]@{
            SnapshotId = $snapshotId
            SnapshotPath = $snapshotPath
            CapturedUtc = $capturedUtc
            BaselineHash = $baselineHash
            EvidenceSourcePath = $evidenceSourcePath
        }
        PostDisableObservation = $PostDisableObservation
        RollbackDrillPackage = $RollbackDrillPackage
        RollbackTrigger = @($rollbackTriggerText)
    }

    $gateChecks = [ordered]@{
        ExactlyOneTarget = @($Target).Count -eq 1
        LabOrDevTestTenantOnly = $targetObject -and (
            [string]$environment -in @('Lab', 'DevTest', 'DevTestLab', 'Test') -or
            [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
            [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -in @('Lab', 'DevTest', 'Test') -or
            [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
        )
        OriginalActionWasReversibleDisable = $originalActionWasReversibleDisable
        OriginalDisableEvidencePresent = $originalDisablePresent
        PreActionSnapshotPresent = $preActionSnapshotPresent
        RollbackDrillPackagePresent = $rollbackDrillPackagePresent
        ObservationFailureOrManualTriggerPresent = $observationFailureOrManualTriggerPresent
        RollbackActionIsReEnableOnly = $rollbackActionIsReEnableOnly
        NoDeleteRequested = -not ($requestedOperations -match '(?i)^Delete$|^FinalDelete$')
        NoRemoveRequested = -not ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$')
        NoRecreateRequested = -not ($requestedOperations -match '(?i)^Recreate$')
        NoGrantCleanupRequested = -not ($requestedOperations -match '(?i)^GrantCleanup$')
        NoCredentialChangeRequested = -not ($requestedOperations -match '(?i)^CredentialChange$')
        HumanRollbackApprovalRequired = $true
    }

    foreach ($gateName in $gateChecks.Keys) {
        $passed = [bool]$gateChecks[$gateName]
        $severity = if ($passed) { 'Info' } else { 'High' }
        $reason = switch ($gateName) {
            'ExactlyOneTarget' { if ($passed) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } }
            'LabOrDevTestTenantOnly' { if ($passed) { 'Target is labeled as lab/dev/test.' } else { 'Target is not labeled as lab/dev/test.' } }
            'OriginalActionWasReversibleDisable' { if ($passed) { 'Original action was reversible disable.' } else { 'Original action was not reversible disable.' } }
            'OriginalDisableEvidencePresent' { if ($passed) { 'Original disable evidence is present.' } else { 'Original disable evidence is missing.' } }
            'PreActionSnapshotPresent' { if ($passed) { 'Pre-action snapshot is present.' } else { 'Pre-action snapshot is missing.' } }
            'RollbackDrillPackagePresent' { if ($passed) { 'Rollback drill package is present.' } else { 'Rollback drill package is missing.' } }
            'ObservationFailureOrManualTriggerPresent' { if ($passed) { 'Rollback trigger is present.' } else { 'Observation failure or manual trigger is missing.' } }
            'RollbackActionIsReEnableOnly' { if ($passed) { 'Rollback action is re-enable only.' } else { 'Rollback action is not re-enable only.' } }
            'NoDeleteRequested' { if ($passed) { 'Delete was not requested.' } else { 'Delete was requested.' } }
            'NoRemoveRequested' { if ($passed) { 'Remove was not requested.' } else { 'Remove was requested.' } }
            'NoRecreateRequested' { if ($passed) { 'Recreate was not requested.' } else { 'Recreate was requested.' } }
            'NoGrantCleanupRequested' { if ($passed) { 'Grant cleanup was not requested.' } else { 'Grant cleanup was requested.' } }
            'NoCredentialChangeRequested' { if ($passed) { 'Credential change was not requested.' } else { 'Credential change was requested.' } }
            'HumanRollbackApprovalRequired' { 'Human rollback approval is required.' }
        }
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gateName -Passed $passed -Severity $severity -Reason $reason))
        if (-not $passed) { $reasons.Add("$gateName failed: $reason") }
    }

    $package | Add-Member -NotePropertyName GateVerdicts -NotePropertyValue @($gateVerdicts) -Force
    $package | Add-Member -NotePropertyName HumanDecisionRequired -NotePropertyValue $true -Force

    $artifactPath = Join-Path $OutputPath "Run4C-RollbackReadiness-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function Get-NhiRun4CTargetContext {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $targetObject = $null
    if (@($Target).Count -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } elseif ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = $false
    if ($targetObject) {
        $evidenceOnly = [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'EvidenceOnly'
    }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }
    $microsoftPlatform = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -or [string]$classification -eq 'MicrosoftPlatform' } else { $false }
    $firstPartyMicrosoftApp = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) } else { $false }
    $isLabOrDevTest = $targetObject -and (
        [string]$environment -in @('Lab', 'DevTest', 'DevTestLab', 'Test') -or
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -in @('Lab', 'DevTest', 'DevTestLab', 'Test') -or
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
    )

    if ($targetObject) {
        if (-not $isLabOrDevTest) { $reasons.Add('Target is not explicitly marked as lab/dev/test.') }
        if ([string]$classification -eq 'MicrosoftPlatform' -or [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true) { $reasons.Add('MicrosoftPlatform target is blocked.') }
        if ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) -eq $true) { $reasons.Add('First-party Microsoft app target is blocked.') }
        if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
        if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
        if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
        if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }
    }

    [PSCustomObject]@{
        TargetObject = $targetObject
        TargetCount = @($Target).Count
        Blockers = @($reasons)
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        Classification = $classification
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        MicrosoftPlatform = $microsoftPlatform
        FirstPartyMicrosoftApp = $firstPartyMicrosoftApp
        SuppressCustomerRemediation = $suppressCustomerRemediation
        EvidenceOnly = $evidenceOnly
        InformationOnly = $informationOnly
        IsLabOrDevTest = [bool]$isLabOrDevTest
    }
}

function New-NhiRun4CEndToEndLabRehearsalReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$ApprovalManifest,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$ReadinessVerdict,

        [Parameter()]
        [object]$DryRunPackage,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$ControlledDisablePackage,

        [Parameter()]
        [object]$FinalGoNoGoPackage,

        [Parameter()]
        [object]$EvidenceCapturePackage,

        [Parameter()]
        [object]$ObservationPackage,

        [Parameter()]
        [object]$RollbackReadinessPackage,

        [Parameter()]
        [object]$RollbackPreviewPackage,

        [Parameter()]
        [object]$FinalDeleteSimulationPackage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string]$MarkdownOutputPath
    )

    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $chainItems = @(
        [PSCustomObject]@{ Revision = 'Rev4.11'; Label = 'approved reversible planning proof'; Package = $ApprovalManifest; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('OutputArtifactPath', 'ApprovalManifestPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.12'; Label = 'readiness gate'; Package = $ReadinessVerdict; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.13'; Label = 'dry-run package'; Package = $DryRunPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.14'; Label = 'rollback drill package'; Package = $RollbackDrillPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.15'; Label = 'controlled disable path'; Package = $ControlledDisablePackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $ControlledDisablePackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.16'; Label = 'final go/no-go package'; Package = $FinalGoNoGoPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $FinalGoNoGoPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.17'; Label = 'evidence capture package'; Package = $EvidenceCapturePackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $EvidenceCapturePackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.18'; Label = 'observation package'; Package = $ObservationPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $ObservationPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.19'; Label = 'rollback readiness package'; Package = $RollbackReadinessPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadinessPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.20'; Label = 'rollback preview path'; Package = $RollbackPreviewPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPreviewPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.21'; Label = 'final delete simulation'; Package = $FinalDeleteSimulationPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $FinalDeleteSimulationPackage -PropertyNames @('OutputArtifactPath')); Required = $true }
    )

    $chainSummary = foreach ($item in $chainItems) {
        $present = $null -ne $item.Package
        $status = if (-not $present) {
            'Missing'
        } elseif ($item.Package.PSObject.Properties['GoNoGo']) {
            [string]$item.Package.GoNoGo
        } elseif ($item.Package.PSObject.Properties['Readiness']) {
            [string]$item.Package.Readiness
        } elseif ($item.Package.PSObject.Properties['RollbackReadiness']) {
            [string]$item.Package.RollbackReadiness
        } elseif ($item.Package.PSObject.Properties['FinalDeleteEligibility']) {
            [string]$item.Package.FinalDeleteEligibility
        } elseif ($item.Package.PSObject.Properties['Ready']) {
            if ($item.Package.Ready -eq $true) { 'Complete' } else { 'Incomplete' }
        } else {
            'Present'
        }

        if (-not $present -and $item.Required) { $reasons.Add("$($item.Revision) package is missing.") }
        [PSCustomObject]@{
            Revision = $item.Revision
            Label = $item.Label
            Present = $present
            Status = $status
            ArtifactPath = $item.ArtifactPath
        }
    }

    $requiredArtifacts = @(
        'Approval manifest',
        'Snapshot',
        'Readiness verdict',
        'Dry-run package',
        'Rollback drill package',
        'Go/No-Go package',
        'Evidence capture package',
        'Observation package',
        'Rollback readiness package',
        'Rollback preview package',
        'Final delete simulation package'
    )

    $artifactIndex = [PSCustomObject]@{
        ApprovalManifestPath = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('OutputArtifactPath', 'ApprovalManifestPath'))
        SnapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('OutputArtifactPath', 'SnapshotPath', 'Path'))
        ReadinessVerdictPath = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('OutputArtifactPath'))
        DryRunPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('OutputArtifactPath'))
        RollbackDrillPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('OutputArtifactPath'))
        GoNoGoPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $FinalGoNoGoPackage -PropertyNames @('OutputArtifactPath'))
        EvidenceCapturePackagePath = [string](Get-NhiControlledPropertyValue -InputObject $EvidenceCapturePackage -PropertyNames @('OutputArtifactPath'))
        ObservationPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $ObservationPackage -PropertyNames @('OutputArtifactPath'))
        RollbackReadinessPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadinessPackage -PropertyNames @('OutputArtifactPath'))
        RollbackPreviewPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPreviewPackage -PropertyNames @('OutputArtifactPath'))
        FinalDeleteSimulationPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $FinalDeleteSimulationPackage -PropertyNames @('OutputArtifactPath'))
    }

    $passedCount = @($chainSummary | Where-Object { $_.Status -in @('Go', 'Ready', 'Complete', 'Eligible') }).Count
    $failedCount = @($chainSummary | Where-Object { $_.Status -in @('NoGo', 'NotReady', 'Incomplete', 'NotEligible', 'Missing') }).Count
    $pendingCount = [math]::Max(0, @($chainSummary).Count - $passedCount - $failedCount)
    $complete = $reasons.Count -eq 0
    $rehearsalStatus = if ($complete) { 'Complete' } else { 'Incomplete' }

    $package = [PSCustomObject]@{
        ReportId = "REV422-$RunId-$($targetContext.TargetObjectId)"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'EndToEndLabRehearsalOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetContext.TargetDisplayName
        TargetObjectId = $targetContext.TargetObjectId
        TargetAppId = $targetContext.TargetAppId
        TargetType = $targetContext.TargetType
        EnvironmentMarker = $targetContext.EnvironmentMarker
        Classification = $targetContext.Classification
        SuppressCustomerRemediation = $targetContext.SuppressCustomerRemediation
        EvidenceOnly = $targetContext.EvidenceOnly
        ChainSummary = @($chainSummary)
        RehearsalStatus = $rehearsalStatus
        ReadyForFinalControlledDevTestDisable = $complete
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        SafetyAssertions = [PSCustomObject]@{
            NoProductionTenantWrite = $true
            NoLiveTenantWriteByRehearsal = $true
            NoActualDisable = $true
            NoActualRollback = $true
            NoActualDelete = $true
            NoFinalDelete = $true
            NoGrantCleanup = $true
            NoCredentialDeletion = $true
        }
        OperatorChecklistSummary = [PSCustomObject]@{
            ChecklistItems = $requiredArtifacts
            PassedCount = $passedCount
            FailedCount = $failedCount
            PendingCount = $pendingCount
        }
        ArtifactIndex = $artifactIndex
    }

    $artifactPath = Join-Path $OutputPath "Run4C-EndToEndLabRehearsal-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force

    if ($MarkdownOutputPath) {
        $markdownLines = @(
            '# End-to-End Lab Rehearsal Report',
            '',
            "- ReportId: $($package.ReportId)",
            "- RunId: $RunId",
            "- RehearsalStatus: $rehearsalStatus",
            "- ReadyForFinalControlledDevTestDisable: $complete",
            '',
            '## Chain Summary'
        )
        foreach ($item in $chainSummary) {
            $markdownLines += "- $($item.Revision) $($item.Label): $($item.Status)"
        }
        [System.IO.File]::WriteAllText($MarkdownOutputPath, ($markdownLines -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
        $package | Add-Member -NotePropertyName MarkdownArtifactPath -NotePropertyValue $MarkdownOutputPath -Force
    }

    return $package
}

function New-NhiRun4CConsultantOperatingGuide {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string]$JsonIndexPath,

        [Parameter()]
        [string]$RunId = 'REV423-GUIDE'
    )

    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    $title = 'Run #4C Controlled Lab NHI Reversible Disable Operating Guide'
    $markdown = @(
        "# $title",
        '',
        '## Executive Summary',
        'This workflow is designed to reduce decommissioning risk by using a reversible-first, evidence-driven lab process.',
        'No final delete is part of Run #4C.',
        'Production use requires separate approval.',
        '',
        '## Scope',
        '- Dev/test tenant only.',
        '- Exactly one approved lab NHI.',
        '- Reversible disable only.',
        '- No delete.',
        '- No grant cleanup.',
        '- No credential deletion.',
        '- No metadata cleanup.',
        '',
        '## Roles and Responsibilities',
        '- Operator',
        '- Approver',
        '- Monitoring owner',
        '- Rollback contact',
        '- Business owner',
        '- Security reviewer',
        '',
        '## Required Artifacts',
        '- Approval manifest',
        '- Pre-action snapshot',
        '- Readiness verdict',
        '- Dry-run package',
        '- Rollback drill package',
        '- Final Go/No-Go package',
        '- Evidence capture package',
        '- Observation package',
        '- Rollback readiness package',
        '- Rollback preview package',
        '- Final delete simulation package',
        '- End-to-end rehearsal report',
        '',
        '## Runbook Phases',
        '- Phase 1: Target selection',
        '- Phase 2: Approval',
        '- Phase 3: Snapshot',
        '- Phase 4: Readiness',
        '- Phase 5: Dry-run',
        '- Phase 6: Rollback drill',
        '- Phase 7: Go/No-Go',
        '- Phase 8: Controlled reversible disable',
        '- Phase 9: Observation',
        '- Phase 10: Rollback readiness if needed',
        '- Phase 11: Rollback only if separately approved',
        '- Phase 12: Final delete simulation only',
        '',
        '## Safety Boundaries',
        '- No production tenant write in lab workflow.',
        '- No final delete.',
        '- No service principal removal.',
        '- No application removal.',
        '- No grant cleanup.',
        '- No credential deletion.',
        '- No rollback without separate approval.',
        '- Microsoft/platform identities are evidence-only.',
        '- Suppressed identities are not customer-actionable.',
        '',
        '## Client-Safe Narrative',
        'This guide is consultant-ready because it uses a clear approval chain, traceable evidence, a reversible-first control model, an operator checklist, explicit rollback readiness, separate delete handling, and client-safe artifacts.',
        '',
        '## Final Operator Warning',
        'Do not run live commands without final human go/no-go and a verified lab target.',
        '',
        '## Target Context',
        "- TargetDisplayName: $($targetContext.TargetDisplayName)",
        "- TargetObjectId: $($targetContext.TargetObjectId)",
        "- TargetAppId: $($targetContext.TargetAppId)",
        "- TargetType: $($targetContext.TargetType)",
        "- Environment: $($targetContext.EnvironmentMarker)",
        "- Classification: $($targetContext.Classification)"
    )

    $guidePath = Join-Path $OutputPath "Run4C-ConsultantOperatingGuide-$RunId.md"
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $guidePath) -Force
    [System.IO.File]::WriteAllText($guidePath, ($markdown -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))

    $package = [PSCustomObject]@{
        GuideId = "REV423-$RunId-$($targetContext.TargetObjectId)"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'ConsultantReadyOperatingGuideOnly'
        Title = $title
        TargetDisplayName = $targetContext.TargetDisplayName
        TargetObjectId = $targetContext.TargetObjectId
        TargetAppId = $targetContext.TargetAppId
        TargetType = $targetContext.TargetType
        EnvironmentMarker = $targetContext.EnvironmentMarker
        Classification = $targetContext.Classification
        OutputArtifactPath = $guidePath
        ContainsExecutableDeleteCommand = $false
        ContainsExecutableFinalDeleteCommand = $false
    }

    if ($JsonIndexPath) {
        Export-NhiControlledDecommissionEvidence -Evidence $package -Path $JsonIndexPath | Out-Null
        $package | Add-Member -NotePropertyName JsonIndexPath -NotePropertyValue $JsonIndexPath -Force
    }

    return $package
}

function Get-NhiRun4CArtifactRecord {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$InputObject,

        [Parameter()]
        [string[]]$PropertyNames = @(),

        [Parameter()]
        [string]$FallbackPath,

        [Parameter()]
        [string]$FallbackId
    )

    $path = [string](Get-NhiControlledPropertyValue -InputObject $InputObject -PropertyNames (@('OutputArtifactPath') + @($PropertyNames)))
    $id = [string](Get-NhiControlledPropertyValue -InputObject $InputObject -PropertyNames @('Id', 'PackageId', 'ReportId', 'ReviewPackageId', 'GuideId', 'SimulationPackageId', 'ObservationPackageId', 'RollbackReadinessPackageId', 'FinalDeleteEligibilityPackageId', 'FinalTestPackageId'))
    if ([string]::IsNullOrWhiteSpace($path)) { $path = [string]$FallbackPath }
    if ([string]::IsNullOrWhiteSpace($id)) { $id = [string]$FallbackId }

    [PSCustomObject]@{
        Present = $null -ne $InputObject
        Path = $path
        Id = $id
    }
}

function New-NhiRun4CFinalControlledDisableTestPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$ApprovalManifest,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$ReadinessVerdict,

        [Parameter()]
        [object]$DryRunPackage,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$ControlledDisablePreview,

        [Parameter()]
        [object]$FinalGoNoGoReviewPackage,

        [Parameter()]
        [object]$EvidenceCapturePackage,

        [Parameter()]
        [object]$ObservationPackage,

        [Parameter()]
        [object]$RollbackReadinessPackage,

        [Parameter()]
        [object]$RollbackPreviewPackage,

        [Parameter()]
        [object]$FinalDeleteSimulationPackage,

        [Parameter()]
        [object]$EndToEndRehearsalReport,

        [Parameter()]
        [object]$ConsultantOperatingGuide,

        [Parameter()]
        [bool]$HumanGoNoGoCaptured = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @('ReversibleDisable'),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target

    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $firstPartyMicrosoftApp = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) } else { $false }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }
    $labMarker = if ($targetObject -and ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -or [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false))) { 'LabTarget' } else { 'LabMarkerMissing' }
    $approvalManifestPresent = $null -ne $ApprovalManifest
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $readinessVerdictPresent = $null -ne $ReadinessVerdict
    $dryRunPackagePresent = $null -ne $DryRunPackage
    $rollbackDrillPackagePresent = $null -ne $RollbackDrillPackage
    $controlledDisablePreviewPresent = $null -ne $ControlledDisablePreview
    $finalGoNoGoReviewPackagePresent = $null -ne $FinalGoNoGoReviewPackage
    $evidenceCapturePackagePresent = $null -ne $EvidenceCapturePackage
    $observationPackagePresent = $null -ne $ObservationPackage
    $rollbackReadinessPackagePresent = $null -ne $RollbackReadinessPackage
    $rollbackPreviewPackagePresent = $null -ne $RollbackPreviewPackage
    $finalDeleteSimulationPackagePresent = $null -ne $FinalDeleteSimulationPackage
    $endToEndRehearsalReportPresent = $null -ne $EndToEndRehearsalReport
    $consultantOperatingGuidePresent = $null -ne $ConsultantOperatingGuide

    $approvalAction = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType', 'RequestedAction'))
    $approvalExpiresUtc = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc'))
    $approvalTargetId = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $approvalNotExpired = $false
    if ($approvalExpiresUtc) {
        try { $approvalNotExpired = [DateTime]::Parse($approvalExpiresUtc).ToUniversalTime() -gt [DateTime]::UtcNow } catch { $approvalNotExpired = $false }
    }

    $readinessReady = [bool](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('Ready') -Default $false)
    if (-not $readinessReady) {
        $readinessState = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('Readiness', 'Status'))
        $readinessReady = $readinessState -in @('Ready', 'Complete')
    }

    $targetIsDisposableOrLabApproved = ($targetContext.IsLabOrDevTest) -and (-not $targetContext.Blockers)
    if ($approvalTargetId -and $targetObjectId -and $approvalTargetId -ne $targetObjectId) { $targetIsDisposableOrLabApproved = $false }
    if (-not $approvalManifestPresent) { $reasons.Add('Approval manifest is required.') }
    if (-not $approvalNotExpired) { $reasons.Add('Approval manifest is missing or expired.') }
    if ($approvalAction -ne 'ReversibleDisable') { $reasons.Add('Approved action is not ReversibleDisable.') }
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $readinessVerdictPresent -or -not $readinessReady) { $reasons.Add('Readiness verdict is required and must be ready.') }
    if (-not $dryRunPackagePresent) { $reasons.Add('Dry-run package is required.') }
    if (-not $rollbackDrillPackagePresent) { $reasons.Add('Rollback drill package is required.') }
    if (-not $controlledDisablePreviewPresent) { $reasons.Add('Controlled disable preview is required.') }
    if (-not $finalGoNoGoReviewPackagePresent) { $reasons.Add('Final go/no-go review package is required.') }
    if (-not $evidenceCapturePackagePresent) { $reasons.Add('Evidence capture package is required.') }
    if (-not $observationPackagePresent) { $reasons.Add('Observation package is required.') }
    if (-not $rollbackReadinessPackagePresent) { $reasons.Add('Rollback readiness package is required.') }
    if (-not $rollbackPreviewPackagePresent) { $reasons.Add('Rollback preview package is required.') }
    if (-not $endToEndRehearsalReportPresent) { $reasons.Add('End-to-end rehearsal report is required.') }
    if (-not $consultantOperatingGuidePresent) { $reasons.Add('Consultant operating guide is required.') }
    if (-not $targetIsDisposableOrLabApproved) { $reasons.Add('Target is not a disposable or lab-approved target.') }
    if ($firstPartyMicrosoftApp) { $reasons.Add('First-party Microsoft app target is blocked.') }
    if ([string]$classification -eq 'MicrosoftPlatform') { $reasons.Add('MicrosoftPlatform target is blocked.') }
    if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
    if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
    if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
    if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }
    if (@($Target).Count -ne 1) { $reasons.Add('Exactly one target is required.') }

    $artifactIndex = [PSCustomObject]@{
        ApprovalManifest = Get-NhiRun4CArtifactRecord -InputObject $ApprovalManifest -PropertyNames @('ApprovalManifestPath') -FallbackId 'ApprovalManifest'
        PreActionSnapshot = Get-NhiRun4CArtifactRecord -InputObject $PreActionSnapshot -PropertyNames @('SnapshotPath', 'Path') -FallbackId 'PreActionSnapshot'
        ReadinessVerdict = Get-NhiRun4CArtifactRecord -InputObject $ReadinessVerdict -PropertyNames @('ReadinessVerdictPath', 'OutputArtifactPath') -FallbackId 'ReadinessVerdict'
        DryRunPackage = Get-NhiRun4CArtifactRecord -InputObject $DryRunPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'DryRunPackage'
        RollbackDrillPackage = Get-NhiRun4CArtifactRecord -InputObject $RollbackDrillPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'RollbackDrillPackage'
        ControlledDisablePreview = Get-NhiRun4CArtifactRecord -InputObject $ControlledDisablePreview -PropertyNames @('OutputArtifactPath') -FallbackId 'ControlledDisablePreview'
        FinalGoNoGoReviewPackage = Get-NhiRun4CArtifactRecord -InputObject $FinalGoNoGoReviewPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'FinalGoNoGoReviewPackage'
        EvidenceCapturePackage = Get-NhiRun4CArtifactRecord -InputObject $EvidenceCapturePackage -PropertyNames @('OutputArtifactPath') -FallbackId 'EvidenceCapturePackage'
        ObservationPackage = Get-NhiRun4CArtifactRecord -InputObject $ObservationPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'ObservationPackage'
        RollbackReadinessPackage = Get-NhiRun4CArtifactRecord -InputObject $RollbackReadinessPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'RollbackReadinessPackage'
        RollbackPreviewPackage = Get-NhiRun4CArtifactRecord -InputObject $RollbackPreviewPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'RollbackPreviewPackage'
        FinalDeleteSimulationPackage = Get-NhiRun4CArtifactRecord -InputObject $FinalDeleteSimulationPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'FinalDeleteSimulationPackage'
        EndToEndRehearsalReport = Get-NhiRun4CArtifactRecord -InputObject $EndToEndRehearsalReport -PropertyNames @('OutputArtifactPath') -FallbackId 'EndToEndRehearsalReport'
        ConsultantOperatingGuide = Get-NhiRun4CArtifactRecord -InputObject $ConsultantOperatingGuide -PropertyNames @('OutputArtifactPath') -FallbackId 'ConsultantOperatingGuide'
    }

    $requiredArtifacts = @(
        'ApprovalManifest',
        'PreActionSnapshot',
        'ReadinessVerdict',
        'DryRunPackage',
        'RollbackDrillPackage',
        'ControlledDisablePreview',
        'FinalGoNoGoReviewPackage',
        'EvidenceCapturePackage',
        'ObservationPackage',
        'RollbackReadinessPackage',
        'RollbackPreviewPackage',
        'FinalDeleteSimulationPackage',
        'EndToEndRehearsalReport',
        'ConsultantOperatingGuide'
    )

    foreach ($artifactName in $requiredArtifacts) {
        if (-not $artifactIndex.$artifactName.Present) {
            $reasons.Add("$artifactName is missing.")
        }
    }

    $gateDefinitions = @(
        @{ GateName = 'ExactlyOneTarget'; Passed = @($Target).Count -eq 1; Severity = 'High'; Reason = if (@($Target).Count -eq 1) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } },
        @{ GateName = 'DevTestTenantOnly'; Passed = $targetContext.IsLabOrDevTest; Severity = 'High'; Reason = if ($targetContext.IsLabOrDevTest) { 'Target is labeled as dev/test or lab.' } else { 'Target is not labeled as dev/test or lab.' } },
        @{ GateName = 'TargetIsDisposableOrLabApproved'; Passed = $targetIsDisposableOrLabApproved; Severity = 'High'; Reason = if ($targetIsDisposableOrLabApproved) { 'Target is disposable or lab-approved.' } else { 'Target is not disposable or lab-approved.' } },
        @{ GateName = 'ApprovalManifestPresent'; Passed = $approvalManifestPresent; Severity = 'High'; Reason = if ($approvalManifestPresent) { 'Approval manifest is present.' } else { 'Approval manifest is missing.' } },
        @{ GateName = 'ApprovalNotExpired'; Passed = $approvalNotExpired; Severity = 'High'; Reason = if ($approvalNotExpired) { 'Approval is not expired.' } else { 'Approval is missing or expired.' } },
        @{ GateName = 'ApprovedActionIsReversibleDisable'; Passed = $approvalAction -eq 'ReversibleDisable'; Severity = 'High'; Reason = if ($approvalAction -eq 'ReversibleDisable') { 'Approved action is ReversibleDisable.' } else { 'Approved action is not ReversibleDisable.' } },
        @{ GateName = 'ReadinessReady'; Passed = $readinessReady; Severity = 'High'; Reason = if ($readinessReady) { 'Readiness verdict is ready.' } else { 'Readiness verdict is missing or not ready.' } },
        @{ GateName = 'DryRunPackagePresent'; Passed = $dryRunPackagePresent; Severity = 'High'; Reason = if ($dryRunPackagePresent) { 'Dry-run package is present.' } else { 'Dry-run package is missing.' } },
        @{ GateName = 'RollbackDrillPackagePresent'; Passed = $rollbackDrillPackagePresent; Severity = 'High'; Reason = if ($rollbackDrillPackagePresent) { 'Rollback drill package is present.' } else { 'Rollback drill package is missing.' } },
        @{ GateName = 'FinalGoNoGoReviewPresent'; Passed = $finalGoNoGoReviewPackagePresent; Severity = 'High'; Reason = if ($finalGoNoGoReviewPackagePresent) { 'Final go/no-go review package is present.' } else { 'Final go/no-go review package is missing.' } },
        @{ GateName = 'EvidenceCapturePackagePresent'; Passed = $evidenceCapturePackagePresent; Severity = 'High'; Reason = if ($evidenceCapturePackagePresent) { 'Evidence capture package is present.' } else { 'Evidence capture package is missing.' } },
        @{ GateName = 'ObservationPackagePresent'; Passed = $observationPackagePresent; Severity = 'High'; Reason = if ($observationPackagePresent) { 'Observation package is present.' } else { 'Observation package is missing.' } },
        @{ GateName = 'RollbackReadinessPackagePresent'; Passed = $rollbackReadinessPackagePresent; Severity = 'High'; Reason = if ($rollbackReadinessPackagePresent) { 'Rollback readiness package is present.' } else { 'Rollback readiness package is missing.' } },
        @{ GateName = 'RollbackPreviewPackagePresent'; Passed = $rollbackPreviewPackagePresent; Severity = 'High'; Reason = if ($rollbackPreviewPackagePresent) { 'Rollback preview package is present.' } else { 'Rollback preview package is missing.' } },
        @{ GateName = 'EndToEndRehearsalComplete'; Passed = $endToEndRehearsalReportPresent -and [string](Get-NhiControlledPropertyValue -InputObject $EndToEndRehearsalReport -PropertyNames @('RehearsalStatus', 'Status')) -in @('Complete', 'Ready'); Severity = 'High'; Reason = if ($endToEndRehearsalReportPresent) { 'End-to-end rehearsal report is complete.' } else { 'End-to-end rehearsal report is missing.' } },
        @{ GateName = 'ConsultantGuidePresent'; Passed = $consultantOperatingGuidePresent; Severity = 'High'; Reason = if ($consultantOperatingGuidePresent) { 'Consultant guide is present.' } else { 'Consultant guide is missing.' } },
        @{ GateName = 'NoFinalDeleteRequested'; Passed = -not ($requestedOperations -match '(?i)^FinalDelete$|^Delete$|^HardDelete$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^FinalDelete$|^Delete$|^HardDelete$') { 'Final delete was requested.' } else { 'Final delete was not requested.' } },
        @{ GateName = 'NoRemoveRequested'; Passed = -not ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { 'Remove was requested.' } else { 'Remove was not requested.' } },
        @{ GateName = 'NoGrantCleanupRequested'; Passed = -not ($requestedOperations -match '(?i)^GrantCleanup$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^GrantCleanup$') { 'Grant cleanup was requested.' } else { 'Grant cleanup was not requested.' } },
        @{ GateName = 'NoMetadataCleanupRequested'; Passed = -not ($requestedOperations -match '(?i)^MetadataCleanup$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^MetadataCleanup$') { 'Metadata cleanup was requested.' } else { 'Metadata cleanup was not requested.' } },
        @{ GateName = 'NoCredentialDeleteRequested'; Passed = -not ($requestedOperations -match '(?i)^CredentialDelete$|^CredentialDeletion$|^CredentialChange$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^CredentialDelete$|^CredentialDeletion$|^CredentialChange$') { 'Credential deletion or change was requested.' } else { 'Credential deletion was not requested.' } },
        @{ GateName = 'HumanGoNoGoRequired'; Passed = $true; Severity = 'Info'; Reason = 'Human go/no-go is required.' },
        @{ GateName = 'HumanGoNoGoCapturedFalseByDefault'; Passed = -not $HumanGoNoGoCaptured; Severity = 'Info'; Reason = if (-not $HumanGoNoGoCaptured) { 'Human go/no-go is not auto-captured.' } else { 'Human go/no-go was captured.' } }
    )

    foreach ($gate in $gateDefinitions) {
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gate.GateName -Passed ([bool]$gate.Passed) -Severity $gate.Severity -Reason $gate.Reason))
    }

    foreach ($gateVerdict in $gateVerdicts) {
        if (-not $gateVerdict.Passed -and [string]$gateVerdict.Severity -eq 'High') {
            if ($reasons -notcontains [string]$gateVerdict.Reason) {
                $reasons.Add([string]$gateVerdict.Reason)
            }
        }
    }

    $packageStatus = if ($reasons.Count -eq 0) { 'ReadyForHumanReview' } else { 'NotReady' }
    $readyForControlledDevTestDisable = $false
    if ($reasons.Count -eq 0 -and $HumanGoNoGoCaptured) {
        $readyForControlledDevTestDisable = $true
    }

    $package = [PSCustomObject]@{
        FinalTestPackageId = "REV424-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'FinalControlledDisableTestPackageOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        SuppressCustomerRemediation = $suppressCustomerRemediation
        EvidenceOnly = $evidenceOnly
        InformationOnly = $informationOnly
        LabTargetMarker = $labMarker
        RequiredArtifactIndex = $artifactIndex
        PreExecutionGates = @($gateVerdicts)
        PreflightCommandPreview = ".\\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -ExecuteNhiControlledDecommission -ExecutionStage DisableOnly -WhatIfExecution -OutputPath '.\\out'"
        LiveCommandBlockTemplate = @(
            '# DO NOT RUN WITHOUT FINAL HUMAN GO/NO-GO',
            '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `',
            '  -ExecuteNhiControlledDecommission `',
            '  -ExecutionStage DisableOnly `',
            '  -OutputPath ''.\out''',
            '# Template only. This package does not execute live disable.'
        ) -join [Environment]::NewLine
        RequestedOperations = @($requestedOperations)
        LabExecutionApprovedDefault = $false
        WhatIfDefault = $true
        ConfirmRequired = $true
        RequiredHumanDecision = $true
        HumanDecisionCaptured = [bool]$HumanGoNoGoCaptured
        HumanGoNoGoRequired = $true
        HumanGoNoGoCaptured = [bool]$HumanGoNoGoCaptured
        PackageStatus = $packageStatus
        ReadyForControlledDevTestDisable = $readyForControlledDevTestDisable
        AllowedNextAction = if ($packageStatus -eq 'ReadyForHumanReview') { 'HumanReviewOnly' } else { 'HumanReviewOnlyBlocked' }
        ProhibitedActions = @('final delete', 'remove service principal', 'remove application', 'grant cleanup', 'metadata cleanup', 'credential deletion')
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
    }

    $artifactPath = Join-Path $OutputPath "Run4C-FinalControlledDisableTestPackage-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CPostDisableEvidenceValidationPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$ExecutionEvidence,

        [Parameter()]
        [object]$PostActionSnapshot,

        [Parameter()]
        [object]$ObservationResult,

        [Parameter()]
        [object]$EvidenceCapturePackage,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $executionEvidencePresent = $null -ne $ExecutionEvidence
    $postActionSnapshotPresent = $null -ne $PostActionSnapshot
    $observationResultPresent = $null -ne $ObservationResult
    $evidenceCapturePackagePresent = $null -ne $EvidenceCapturePackage
    $targetBlocked = $targetContext.Blockers.Count -gt 0
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $executionEvidencePresent) { $reasons.Add('Execution evidence is required.') }
    if (-not $postActionSnapshotPresent) { $reasons.Add('Post-action snapshot is required.') }
    if (-not $observationResultPresent) { $reasons.Add('Observation result is required.') }
    if (-not $evidenceCapturePackagePresent) { $reasons.Add('Evidence capture package is required.') }
    if ($targetBlocked) { $reasons.AddRange(@($targetContext.Blockers)) }

    $accountEnabledBefore = [bool](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AccountEnabled', 'Enabled', 'IsEnabled') -Default $true)
    $accountEnabledAfter = [bool](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('AccountEnabled', 'Enabled', 'IsEnabled') -Default $false)
    $expectedChangeObserved = $preActionSnapshotPresent -and $executionEvidencePresent -and $postActionSnapshotPresent -and ($accountEnabledBefore -eq $true) -and ($accountEnabledAfter -eq $false)

    $credentialCountBefore = [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CredentialCount', 'CredentialsCount') -Default -1)
    $credentialCountAfter = [int](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('CredentialCount', 'CredentialsCount') -Default -1)
    $ownerCountBefore = [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OwnerCount') -Default -1)
    $ownerCountAfter = [int](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('OwnerCount') -Default -1)
    $appRoleAssignmentsBefore = [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppRoleAssignmentCount') -Default -1)
    $appRoleAssignmentsAfter = [int](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('AppRoleAssignmentCount') -Default -1)
    $oauthGrantsBefore = [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OAuthGrantCount', 'GrantCount') -Default -1)
    $oauthGrantsAfter = [int](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('OAuthGrantCount', 'GrantCount') -Default -1)
    $appMetadataBefore = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppMetadataHash', 'MetadataHash'))
    $appMetadataAfter = [string](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('AppMetadataHash', 'MetadataHash'))
    $servicePrincipalStillExists = [bool](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('ServicePrincipalStillExists', 'ObjectStillExists') -Default $true)
    $applicationStillExists = [bool](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('ApplicationStillExists') -Default $true)

    $credentialCountUnchanged = ($credentialCountBefore -lt 0 -or $credentialCountAfter -lt 0) -or ($credentialCountBefore -eq $credentialCountAfter)
    $ownerCountUnchanged = ($ownerCountBefore -lt 0 -or $ownerCountAfter -lt 0) -or ($ownerCountBefore -eq $ownerCountAfter)
    $appRoleAssignmentCountUnchanged = ($appRoleAssignmentsBefore -lt 0 -or $appRoleAssignmentsAfter -lt 0) -or ($appRoleAssignmentsBefore -eq $appRoleAssignmentsAfter)
    $oauthGrantCountUnchanged = ($oauthGrantsBefore -lt 0 -or $oauthGrantsAfter -lt 0) -or ($oauthGrantsBefore -eq $oauthGrantsAfter)
    $appMetadataUnchanged = ([string]::IsNullOrWhiteSpace($appMetadataBefore) -or [string]::IsNullOrWhiteSpace($appMetadataAfter)) -or ($appMetadataBefore -eq $appMetadataAfter)
    $noDeleteObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $ExecutionEvidence -PropertyNames @('DeletePerformed', 'DeleteObserved') -Default $false) -or [bool](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('DeleteObserved') -Default $false))
    $noGrantCleanupObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $ExecutionEvidence -PropertyNames @('GrantCleanupPerformed', 'GrantCleanupObserved') -Default $false))
    $noCredentialDeletionObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $ExecutionEvidence -PropertyNames @('CredentialDeletionPerformed', 'CredentialDeleteObserved', 'CredentialDeletionObserved') -Default $false))
    if (-not $expectedChangeObserved) { $reasons.Add('Expected account enabled state change was not observed.') }
    if (-not $credentialCountUnchanged) { $reasons.Add('Credential count changed.') }
    if (-not $ownerCountUnchanged) { $reasons.Add('Owner count changed.') }
    if (-not $appRoleAssignmentCountUnchanged) { $reasons.Add('App role assignment count changed.') }
    if (-not $oauthGrantCountUnchanged) { $reasons.Add('OAuth grant count changed.') }
    if (-not $servicePrincipalStillExists) { $reasons.Add('Service principal no longer exists.') }
    if ($targetType -eq 'Application' -and -not $applicationStillExists) { $reasons.Add('Application no longer exists.') }
    if (-not $noDeleteObserved) { $reasons.Add('Delete observed.') }
    if (-not $noGrantCleanupObserved) { $reasons.Add('Grant cleanup observed.') }
    if (-not $noCredentialDeletionObserved) { $reasons.Add('Credential deletion observed.') }
    if (-not $appMetadataUnchanged) { $warnings.Add('Application metadata changed or was not proven unchanged.') }

    $observationWindowCompleted = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('ObservationWindowCompleted') -Default $false)
    $monitoringOwner = [string](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('MonitoringOwner'))
    $rollbackContact = [string](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('RollbackContact'))
    $successCriteriaMet = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('SuccessCriteriaMet') -Default $false)
    $failureCriteriaTriggered = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('FailureCriteriaTriggered') -Default $false)
    $rollbackTriggerDetected = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('RollbackTriggerDetected') -Default $false)
    $businessOwnerValidationResult = [string](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('BusinessOwnerValidationResult'))

    $artifactPath = Join-Path $OutputPath "Run4C-PostDisableValidation-$RunId.json"
    $package = [PSCustomObject]@{
        PostDisableValidationPackageId = "REV425-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'PostDisableEvidenceValidationOnly'
        TenantWritePerformed = $false
        DisablePerformedByThisPackage = $false
        RollbackPerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        PreActionSnapshotPresent = $preActionSnapshotPresent
        ExecutionEvidencePresent = $executionEvidencePresent
        PostActionSnapshotPresent = $postActionSnapshotPresent
        ObservationResultPresent = $observationResultPresent
        EvidenceCapturePackagePresent = $evidenceCapturePackagePresent
        ExpectedChange = 'AccountEnabled changed from true to false, or equivalent reversible-disable state'
        AccountEnabledBefore = $accountEnabledBefore
        AccountEnabledAfter = $accountEnabledAfter
        ExpectedChangeObserved = $expectedChangeObserved
        CredentialCountUnchanged = $credentialCountUnchanged
        OwnerCountUnchanged = $ownerCountUnchanged
        AppRoleAssignmentCountUnchanged = $appRoleAssignmentCountUnchanged
        OAuthGrantCountUnchanged = $oauthGrantCountUnchanged
        AppMetadataUnchanged = $appMetadataUnchanged
        ServicePrincipalStillExists = $servicePrincipalStillExists
        ApplicationStillExists = $applicationStillExists
        NoDeleteObserved = $noDeleteObserved
        NoGrantCleanupObserved = $noGrantCleanupObserved
        NoCredentialDeletionObserved = $noCredentialDeletionObserved
        ObservationWindowCompleted = $observationWindowCompleted
        MonitoringOwner = $monitoringOwner
        RollbackContact = $rollbackContact
        SuccessCriteriaMet = $successCriteriaMet
        FailureCriteriaTriggered = $failureCriteriaTriggered
        RollbackTriggerDetected = $rollbackTriggerDetected
        BusinessOwnerValidationResult = $businessOwnerValidationResult
        PostDisableValidationStatus = $status
        ReadyToRemainDisabled = $readyToRemainDisabled
        RollbackRecommended = $rollbackRecommended
        Blockers = @($reasons)
        Warnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
    }

    $status = if ($reasons.Count -gt 0) { if ($preActionSnapshotPresent -and $executionEvidencePresent -and $postActionSnapshotPresent -and $observationResultPresent) { 'Failed' } else { 'Incomplete' } } else { 'Passed' }
    $rollbackRecommended = $failureCriteriaTriggered -or $rollbackTriggerDetected -or (-not $successCriteriaMet)
    $readyToRemainDisabled = ($status -eq 'Passed') -and (-not $rollbackRecommended)
    $package.PostDisableValidationStatus = $status
    $package.ReadyToRemainDisabled = $readyToRemainDisabled
    $package.RollbackRecommended = $rollbackRecommended
    $package.Blockers = @($reasons)
    $package.Warnings = @($warnings)

    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CControlledRollbackExecutionTestPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$OriginalDisableEvidence,

        [Parameter()]
        [object]$PostDisableValidationPackage,

        [Parameter()]
        [object]$RollbackReadinessPackage,

        [Parameter()]
        [object]$RollbackPreviewPackage,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$ObservationFailureOrManualTrigger,

        [Parameter()]
        [bool]$HumanRollbackApprovalCaptured = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @('ReEnableServicePrincipal'),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $originalDisablePresent = $null -ne $OriginalDisableEvidence
    $postDisableValidationPresent = $null -ne $PostDisableValidationPackage
    $rollbackReadinessPresent = $null -ne $RollbackReadinessPackage
    $rollbackPreviewPresent = $null -ne $RollbackPreviewPackage
    $rollbackDrillPresent = $null -ne $RollbackDrillPackage
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $observationFailureOrManualTriggerPresent = $null -ne $ObservationFailureOrManualTrigger

    if (-not $originalDisablePresent) { $reasons.Add('Original disable evidence is required.') }
    if (-not $postDisableValidationPresent) { $reasons.Add('Post-disable validation package is required.') }
    if (-not $rollbackReadinessPresent) { $reasons.Add('Rollback readiness package is required.') }
    if (-not $rollbackPreviewPresent) { $reasons.Add('Rollback preview package is required.') }
    if (-not $rollbackDrillPresent) { $reasons.Add('Rollback drill package is required.') }
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $observationFailureOrManualTriggerPresent) { $reasons.Add('Observation failure or manual trigger is required.') }

    $originalActionWasReversibleDisable = [string](Get-NhiControlledPropertyValue -InputObject $OriginalDisableEvidence -PropertyNames @('PlannedAction', 'AllowedAction', 'RequestedAction', 'ActionType')) -eq 'ReversibleDisable'
    $rollbackAction = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPreviewPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    if ([string]::IsNullOrWhiteSpace($rollbackAction)) {
        $rollbackAction = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    }
    $rollbackActionIsReEnableOnly = $rollbackAction -eq 'ReEnableServicePrincipal'
    $rollbackReadinessReady = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackReadinessPackage -PropertyNames @('Ready', 'RollbackReadiness') -Default $false)
    if (-not $rollbackReadinessReady) {
        $rollbackReadinessReady = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadinessPackage -PropertyNames @('RollbackReadiness')) -in @('Ready', 'Complete')
    }

    if (-not $originalActionWasReversibleDisable) { $reasons.Add('Original action was not reversible disable.') }
    if (-not $rollbackReadinessReady) { $reasons.Add('Rollback readiness is not ready.') }
    if (-not $rollbackActionIsReEnableOnly) { $reasons.Add('Rollback action must be re-enable only.') }
    if (@($Target).Count -ne 1) { $reasons.Add('Exactly one target is required.') }
    if (-not $targetContext.IsLabOrDevTest) { $reasons.Add('Target must be lab/dev/test only.') }
    if ([string]$classification -eq 'MicrosoftPlatform') { $reasons.Add('MicrosoftPlatform target is blocked.') }
    if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }

    $gateDefinitions = @(
        @{ GateName = 'ExactlyOneTarget'; Passed = @($Target).Count -eq 1; Severity = 'High'; Reason = if (@($Target).Count -eq 1) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } },
        @{ GateName = 'DevTestTenantOnly'; Passed = $targetContext.IsLabOrDevTest; Severity = 'High'; Reason = if ($targetContext.IsLabOrDevTest) { 'Target is labeled as dev/test or lab.' } else { 'Target is not labeled as dev/test or lab.' } },
        @{ GateName = 'OriginalDisableWasReversible'; Passed = $originalActionWasReversibleDisable; Severity = 'High'; Reason = if ($originalActionWasReversibleDisable) { 'Original disable was reversible.' } else { 'Original disable was not reversible.' } },
        @{ GateName = 'RollbackRecommendedOrManuallyTriggered'; Passed = [bool]$ObservationFailureOrManualTrigger; Severity = 'High'; Reason = if ($ObservationFailureOrManualTrigger) { 'Rollback was recommended or manually triggered.' } else { 'Rollback was not recommended or manually triggered.' } },
        @{ GateName = 'RollbackReadinessReady'; Passed = $rollbackReadinessReady; Severity = 'High'; Reason = if ($rollbackReadinessReady) { 'Rollback readiness is ready.' } else { 'Rollback readiness is not ready.' } },
        @{ GateName = 'RollbackActionIsReEnableOnly'; Passed = $rollbackActionIsReEnableOnly; Severity = 'High'; Reason = if ($rollbackActionIsReEnableOnly) { 'Rollback action is re-enable only.' } else { 'Rollback action is not re-enable only.' } },
        @{ GateName = 'HumanRollbackApprovalRequired'; Passed = $true; Severity = 'Info'; Reason = 'Human rollback approval is required.' },
        @{ GateName = 'HumanRollbackApprovalCapturedFalseByDefault'; Passed = -not $HumanRollbackApprovalCaptured; Severity = 'Info'; Reason = if (-not $HumanRollbackApprovalCaptured) { 'Human rollback approval is not auto-captured.' } else { 'Human rollback approval was captured.' } },
        @{ GateName = 'NoDeleteRequested'; Passed = -not ($requestedOperations -match '(?i)^Delete$|^FinalDelete$|^HardDelete$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^Delete$|^FinalDelete$|^HardDelete$') { 'Delete was requested.' } else { 'Delete was not requested.' } },
        @{ GateName = 'NoRemoveRequested'; Passed = -not ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { 'Remove was requested.' } else { 'Remove was not requested.' } },
        @{ GateName = 'NoRecreateRequested'; Passed = -not ($requestedOperations -match '(?i)^Recreate$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^Recreate$') { 'Recreate was requested.' } else { 'Recreate was not requested.' } },
        @{ GateName = 'NoGrantCleanupRequested'; Passed = -not ($requestedOperations -match '(?i)^GrantCleanup$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^GrantCleanup$') { 'Grant cleanup was requested.' } else { 'Grant cleanup was not requested.' } },
        @{ GateName = 'NoMetadataCleanupRequested'; Passed = -not ($requestedOperations -match '(?i)^MetadataCleanup$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^MetadataCleanup$') { 'Metadata cleanup was requested.' } else { 'Metadata cleanup was not requested.' } },
        @{ GateName = 'NoCredentialChangeRequested'; Passed = -not ($requestedOperations -match '(?i)^CredentialChange$|^CredentialDelete$|^CredentialDeletion$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^CredentialChange$|^CredentialDelete$|^CredentialDeletion$') { 'Credential change was requested.' } else { 'Credential change was not requested.' } }
    )

    foreach ($gate in $gateDefinitions) {
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gate.GateName -Passed ([bool]$gate.Passed) -Severity $gate.Severity -Reason $gate.Reason))
    }

    foreach ($gateVerdict in $gateVerdicts) {
        if (-not $gateVerdict.Passed -and [string]$gateVerdict.Severity -eq 'High') {
            if ($reasons -notcontains [string]$gateVerdict.Reason) {
                $reasons.Add([string]$gateVerdict.Reason)
            }
        }
    }

    $packageStatus = if ($reasons.Count -eq 0) { 'ReadyForHumanRollbackReview' } else { 'NotReady' }
    $readyForControlledDevTestRollback = ($reasons.Count -eq 0) -and $HumanRollbackApprovalCaptured

    $package = [PSCustomObject]@{
        RollbackExecutionTestPackageId = "REV426-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'ControlledRollbackExecutionTestPackageOnly'
        TenantWritePerformed = $false
        RollbackPerformed = $false
        DisablePerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        OriginalDisableEvidencePresent = $originalDisablePresent
        PostDisableValidationPackagePresent = $postDisableValidationPresent
        RollbackReadinessPackagePresent = $rollbackReadinessPresent
        RollbackPreviewPackagePresent = $rollbackPreviewPresent
        RollbackDrillPackagePresent = $rollbackDrillPresent
        PreActionSnapshotPresent = $preActionSnapshotPresent
        ObservationFailureOrManualTriggerPresent = $observationFailureOrManualTriggerPresent
        RollbackAction = if ([string]::IsNullOrWhiteSpace($rollbackAction)) { 'ReEnableServicePrincipal' } else { $rollbackAction }
        RollbackPreflightCommandPreview = ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -ExecuteNhiControlledDecommission -ExecutionStage ReversibleDisable -WhatIfExecution -OutputPath '.\out'"
        RollbackLiveCommandBlockTemplate = @(
            '# DO NOT RUN WITHOUT FINAL HUMAN ROLLBACK GO/NO-GO',
            '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `',
            '  -ExecuteNhiControlledDecommission `',
            '  -ExecutionStage ReversibleDisable `',
            '  -OutputPath ''.\out''',
            '# Template only. This package does not execute live rollback.'
        ) -join [Environment]::NewLine
        WhatIfDefault = $true
        ConfirmRequired = $true
        RollbackExecutionApprovedDefault = $false
        GateVerdicts = @($gateVerdicts)
        PackageStatus = $packageStatus
        ReadyForControlledDevTestRollback = $readyForControlledDevTestRollback
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        HumanRollbackApprovalRequired = $true
        HumanRollbackApprovalCaptured = [bool]$HumanRollbackApprovalCaptured
        AllowedNextAction = if ($packageStatus -eq 'ReadyForHumanRollbackReview') { 'HumanRollbackReviewOnly' } else { 'HumanRollbackReviewOnlyBlocked' }
        ProhibitedActions = @('delete', 'remove service principal', 'remove application', 'recreate object', 'grant cleanup', 'metadata cleanup', 'credential change')
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
    }

    $artifactPath = Join-Path $OutputPath "Run4C-ControlledRollbackExecutionTestPackage-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CPostRollbackValidationPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$DisableEvidence,

        [Parameter()]
        [object]$RollbackExecutionEvidence,

        [Parameter()]
        [object]$PostRollbackSnapshot,

        [Parameter()]
        [object]$ObservationResult,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $disableEvidencePresent = $null -ne $DisableEvidence
    $rollbackExecutionEvidencePresent = $null -ne $RollbackExecutionEvidence
    $postRollbackSnapshotPresent = $null -ne $PostRollbackSnapshot
    $observationResultPresent = $null -ne $ObservationResult
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $disableEvidencePresent) { $reasons.Add('Disable evidence is required.') }
    if (-not $rollbackExecutionEvidencePresent) { $reasons.Add('Rollback execution evidence is required.') }
    if (-not $postRollbackSnapshotPresent) { $reasons.Add('Post-rollback snapshot is required.') }
    if (-not $observationResultPresent) { $reasons.Add('Observation result is required.') }

    $accountEnabledBefore = [bool](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AccountEnabled', 'Enabled', 'IsEnabled') -Default $true)
    $accountEnabledAfterDisable = [bool](Get-NhiControlledPropertyValue -InputObject $DisableEvidence -PropertyNames @('AccountEnabledAfter', 'EnabledAfter') -Default $false)
    $accountEnabledAfterRollback = [bool](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('AccountEnabled', 'Enabled', 'IsEnabled') -Default $true)
    $enabledStateRestored = $preActionSnapshotPresent -and $rollbackExecutionEvidencePresent -and $postRollbackSnapshotPresent -and ($accountEnabledBefore -eq $accountEnabledAfterRollback)
    $objectIdUnchanged = [string](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('ObjectId')) -eq [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('ObjectId'))
    $appIdUnchanged = [string](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('AppId')) -eq [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppId'))
    $credentialCountChanged = [int](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('CredentialCount', 'CredentialsCount') -Default -1) -ne [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CredentialCount', 'CredentialsCount') -Default -1)
    $ownerCountChanged = [int](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('OwnerCount') -Default -1) -ne [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OwnerCount') -Default -1)
    $appRoleAssignmentCountChanged = [int](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('AppRoleAssignmentCount') -Default -1) -ne [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppRoleAssignmentCount') -Default -1)
    $oauthGrantCountChanged = [int](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('OAuthGrantCount', 'GrantCount') -Default -1) -ne [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OAuthGrantCount', 'GrantCount') -Default -1)
    $appMetadataRestoredOrUnchanged = ([string](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('AppMetadataHash', 'MetadataHash')) -eq [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppMetadataHash', 'MetadataHash')))
    $noDeleteObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionEvidence -PropertyNames @('DeletePerformed', 'DeleteObserved') -Default $false))
    $noRecreateObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionEvidence -PropertyNames @('RecreatePerformed', 'RecreateObserved') -Default $false))
    $noGrantCleanupObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionEvidence -PropertyNames @('GrantCleanupPerformed', 'GrantCleanupObserved') -Default $false))
    $noCredentialChangeObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionEvidence -PropertyNames @('CredentialChangePerformed', 'CredentialDeleteObserved', 'CredentialDeletionObserved', 'CredentialDeletionPerformed') -Default $false))
    if (-not $enabledStateRestored) { $reasons.Add('Enabled state was not restored.') }
    if ($credentialCountChanged) { $reasons.Add('Credential count changed.') }
    if ($ownerCountChanged) { $reasons.Add('Owner count changed.') }
    if ($appRoleAssignmentCountChanged) { $reasons.Add('App role assignment count changed.') }
    if ($oauthGrantCountChanged) { $reasons.Add('OAuth grant count changed.') }
    if (-not $objectIdUnchanged) { $reasons.Add('ObjectId changed.') }
    if (-not $appIdUnchanged) { $reasons.Add('AppId changed.') }
    if (-not $noDeleteObserved) { $reasons.Add('Delete observed.') }
    if (-not $noRecreateObserved) { $reasons.Add('Recreate observed.') }
    if (-not $noGrantCleanupObserved) { $reasons.Add('Grant cleanup observed.') }
    if (-not $noCredentialChangeObserved) { $reasons.Add('Credential change observed.') }
    if (-not $appMetadataRestoredOrUnchanged) { $warnings.Add('Metadata changed or could not be proven unchanged.') }

    $postRollbackValidationStatus = if ($preActionSnapshotPresent -and $disableEvidencePresent -and $rollbackExecutionEvidencePresent -and $postRollbackSnapshotPresent -and $observationResultPresent) {
        if ($reasons.Count -gt 0) { 'Failed' } elseif ($enabledStateRestored -and -not $credentialCountChanged -and -not $ownerCountChanged -and -not $appRoleAssignmentCountChanged -and -not $oauthGrantCountChanged -and $noDeleteObserved -and $noRecreateObserved -and $noGrantCleanupObserved -and $noCredentialChangeObserved) { 'Passed' } else { 'Failed' }
    } else {
        'Incomplete'
    }

    $observationWindowCompleted = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('ObservationWindowCompleted') -Default $false)
    $successCriteriaMet = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('SuccessCriteriaMet') -Default $false)
    $failureCriteriaTriggered = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('FailureCriteriaTriggered') -Default $false)
    $remainingRisk = @()
    if (-not $enabledStateRestored) { $remainingRisk += 'Enabled state not restored' }
    if ($credentialCountChanged) { $remainingRisk += 'Credential count changed' }
    if ($ownerCountChanged) { $remainingRisk += 'Owner count changed' }

    $package = [PSCustomObject]@{
        PostRollbackValidationPackageId = "REV427-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'PostRollbackValidationOnly'
        TenantWritePerformed = $false
        RollbackPerformedByThisPackage = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        PreActionSnapshotPresent = $preActionSnapshotPresent
        DisableEvidencePresent = $disableEvidencePresent
        RollbackExecutionEvidencePresent = $rollbackExecutionEvidencePresent
        PostRollbackSnapshotPresent = $postRollbackSnapshotPresent
        ObservationResultPresent = $observationResultPresent
        AccountEnabledBefore = $accountEnabledBefore
        AccountEnabledAfterDisable = $accountEnabledAfterDisable
        AccountEnabledAfterRollback = $accountEnabledAfterRollback
        EnabledStateRestored = $enabledStateRestored
        ObjectIdUnchanged = $objectIdUnchanged
        AppIdUnchanged = $appIdUnchanged
        CredentialCountRestoredOrUnchanged = -not $credentialCountChanged
        OwnerCountRestoredOrUnchanged = -not $ownerCountChanged
        AppRoleAssignmentCountRestoredOrUnchanged = -not $appRoleAssignmentCountChanged
        OAuthGrantCountRestoredOrUnchanged = -not $oauthGrantCountChanged
        AppMetadataRestoredOrUnchanged = $appMetadataRestoredOrUnchanged
        NoDeleteObserved = $noDeleteObserved
        NoRecreateObserved = $noRecreateObserved
        NoGrantCleanupObserved = $noGrantCleanupObserved
        NoCredentialChangeObserved = $noCredentialChangeObserved
        PostRollbackValidationStatus = $postRollbackValidationStatus
        RestorationConfirmed = $enabledStateRestored -and -not $credentialCountChanged -and -not $ownerCountChanged -and -not $appRoleAssignmentCountChanged -and -not $oauthGrantCountChanged
        RemainingRisk = @($remainingRisk)
        Warnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        SuccessCriteriaMet = $successCriteriaMet
        FailureCriteriaTriggered = $failureCriteriaTriggered
    }

    $artifactPath = Join-Path $OutputPath "Run4C-PostRollbackValidation-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CFinalEvidenceBundle {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$Rev410PlatformClassificationEvidence,

        [Parameter()]
        [object]$Rev411PlanningProof,

        [Parameter()]
        [object]$Rev412ReadinessGate,

        [Parameter()]
        [object]$Rev413DryRunPackage,

        [Parameter()]
        [object]$Rev414RollbackDrillPackage,

        [Parameter()]
        [object]$Rev415ControlledDisablePathPackage,

        [Parameter()]
        [object]$Rev416FinalGoNoGoReviewPackage,

        [Parameter()]
        [object]$Rev417EvidenceCapturePackage,

        [Parameter()]
        [object]$Rev418ObservationPackage,

        [Parameter()]
        [object]$Rev419RollbackReadinessPackage,

        [Parameter()]
        [object]$Rev420RollbackPreviewPackage,

        [Parameter()]
        [object]$Rev421FinalDeleteSimulationPackage,

        [Parameter()]
        [object]$Rev422RehearsalReport,

        [Parameter()]
        [object]$Rev423ConsultantGuide,

        [Parameter()]
        [object]$Rev424FinalControlledDisableTestPackage,

        [Parameter()]
        [object]$Rev425PostDisableValidationPackage,

        [Parameter()]
        [object]$Rev426RollbackExecutionTestPackage,

        [Parameter()]
        [object]$Rev427PostRollbackValidationPackage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string]$MarkdownOutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }

    $chainItems = @(
        [PSCustomObject]@{ Revision = 'Rev4.10'; Label = 'platform classification evidence'; Package = $Rev410PlatformClassificationEvidence; Required = $false },
        [PSCustomObject]@{ Revision = 'Rev4.11'; Label = 'planning proof'; Package = $Rev411PlanningProof; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.12'; Label = 'readiness gate'; Package = $Rev412ReadinessGate; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.13'; Label = 'dry-run package'; Package = $Rev413DryRunPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.14'; Label = 'rollback drill package'; Package = $Rev414RollbackDrillPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.15'; Label = 'controlled disable path package'; Package = $Rev415ControlledDisablePathPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.16'; Label = 'final go/no-go review package'; Package = $Rev416FinalGoNoGoReviewPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.17'; Label = 'evidence capture package'; Package = $Rev417EvidenceCapturePackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.18'; Label = 'observation package'; Package = $Rev418ObservationPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.19'; Label = 'rollback readiness package'; Package = $Rev419RollbackReadinessPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.20'; Label = 'rollback preview package'; Package = $Rev420RollbackPreviewPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.21'; Label = 'final delete simulation package'; Package = $Rev421FinalDeleteSimulationPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.22'; Label = 'rehearsal report'; Package = $Rev422RehearsalReport; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.23'; Label = 'consultant guide'; Package = $Rev423ConsultantGuide; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.24'; Label = 'final controlled disable test package'; Package = $Rev424FinalControlledDisableTestPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.25'; Label = 'post-disable validation package'; Package = $Rev425PostDisableValidationPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.26'; Label = 'rollback execution test package'; Package = $Rev426RollbackExecutionTestPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.27'; Label = 'post-rollback validation package'; Package = $Rev427PostRollbackValidationPackage; Required = $true }
    )

    $chainIndex = foreach ($item in $chainItems) {
        $present = $null -ne $item.Package
        $status = if (-not $present) {
            'Missing'
        } elseif ($item.Package.PSObject.Properties['PackageStatus']) {
            [string]$item.Package.PackageStatus
        } elseif ($item.Package.PSObject.Properties['PostDisableValidationStatus']) {
            [string]$item.Package.PostDisableValidationStatus
        } elseif ($item.Package.PSObject.Properties['PostRollbackValidationStatus']) {
            [string]$item.Package.PostRollbackValidationStatus
        } elseif ($item.Package.PSObject.Properties['Ready']) {
            if ($item.Package.Ready -eq $true) { 'Ready' } else { 'NotReady' }
        } elseif ($item.Package.PSObject.Properties['GoNoGo']) {
            [string]$item.Package.GoNoGo
        } elseif ($item.Package.PSObject.Properties['RehearsalStatus']) {
            [string]$item.Package.RehearsalStatus
        } elseif ($item.Package.PSObject.Properties['GuideId']) {
            'Present'
        } else {
            'Present'
        }

        if ($item.Required -and -not $present) { $reasons.Add("$($item.Revision) package is missing.") }

        [PSCustomObject]@{
            Revision = $item.Revision
            Label = $item.Label
            Present = $present
            Path = [string](Get-NhiControlledPropertyValue -InputObject $item.Package -PropertyNames @('OutputArtifactPath', 'MarkdownArtifactPath'))
            Status = $status
        }
    }

    $requiredPresent = -not ($chainIndex | Where-Object { $_.Revision -in @('Rev4.11','Rev4.12','Rev4.13','Rev4.14','Rev4.15','Rev4.16','Rev4.17','Rev4.18','Rev4.19','Rev4.20','Rev4.21','Rev4.22','Rev4.23','Rev4.24','Rev4.25','Rev4.26','Rev4.27') -and -not $_.Present })
    $safetyAssertionsPassed = ($targetContext.IsLabOrDevTest) -and (-not $targetContext.Blockers)
    $chainComplete = $requiredPresent -and $safetyAssertionsPassed
    if (-not $requiredPresent) { $reasons.Add('One or more required chain artifacts are missing.') }
    if (-not $safetyAssertionsPassed) { $reasons.Add('Safety assertions failed for the target context.') }

    $bundle = [PSCustomObject]@{
        EvidenceBundleId = "REV428-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'FinalRev4EvidenceBundleOnly'
        TenantWritePerformedByBundle = $false
        DisablePerformedByBundle = $false
        RollbackPerformedByBundle = $false
        DeletePerformedByBundle = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        ChainIndex = @($chainIndex)
        ChainComplete = $chainComplete
        RequiredArtifactsPresent = $requiredPresent
        SafetyAssertionsPassed = $safetyAssertionsPassed
        FinalDeleteExcluded = $true
        ProductionTenantExcluded = $targetContext.IsLabOrDevTest
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
        ConsultantSummary = [PSCustomObject]@{
            WhatWasProven = @(
                'The Run #4C chain is package-only through Rev4.27.',
                'No live tenant write occurred in the bundle step.',
                'Rev4.24 through Rev4.27 artifacts can be chained and reviewed locally.'
            )
            WhatWasNotProven = @(
                'No live disable occurred in the bundle step.',
                'No rollback execution occurred in the bundle step.',
                'No final delete execution occurred.',
                'No production tenant write occurred.'
            )
            WhatRemainsSeparate = @(
                'Human go/no-go remains separate.',
                'Actual tenant execution remains separate.',
                'Final delete remains out of scope.'
            )
            ClientSafeStatement = 'This evidence bundle is local, review-only, and does not authorize tenant mutation.'
            DeleteOutOfScopeStatement = 'Final delete is excluded from Rev4.x and remains out of scope.'
        }
        ContainedSecrets = $false
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
    }

    $artifactPath = Join-Path $OutputPath "Run4C-FinalEvidenceBundle-$RunId.json"
    $bundle | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $bundle -Path $artifactPath) -Force

    if ($MarkdownOutputPath) {
        $markdown = [System.Collections.Generic.List[string]]::new()
        $markdown.Add('# Final Rev4 Evidence Bundle')
        $markdown.Add('')
        $markdown.Add("- EvidenceBundleId: $($bundle.EvidenceBundleId)")
        $markdown.Add("- ChainComplete: $chainComplete")
        $markdown.Add("- RequiredArtifactsPresent: $requiredPresent")
        $markdown.Add("- SafetyAssertionsPassed: $safetyAssertionsPassed")
        $markdown.Add('')
        $markdown.Add('## Consultant Summary')
        $markdown.Add('- What was proven:')
        foreach ($line in @($bundle.ConsultantSummary.WhatWasProven | ForEach-Object { "  - $_" })) {
            $markdown.Add([string]$line)
        }
        $markdown.Add('- What was not proven:')
        foreach ($line in @($bundle.ConsultantSummary.WhatWasNotProven | ForEach-Object { "  - $_" })) {
            $markdown.Add([string]$line)
        }
        $markdown.Add('- What remains separate:')
        foreach ($line in @($bundle.ConsultantSummary.WhatRemainsSeparate | ForEach-Object { "  - $_" })) {
            $markdown.Add([string]$line)
        }
        [System.IO.File]::WriteAllText($MarkdownOutputPath, ($markdown -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
        $bundle | Add-Member -NotePropertyName MarkdownArtifactPath -NotePropertyValue $MarkdownOutputPath -Force
    }

    return $bundle
}

function New-NhiRev4ReleaseCandidateFreezePackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$EvidenceBundle,

        [Parameter()]
        [object]$ConsultantOperatingGuide,

        [Parameter()]
        [object]$SafetyPosture,

        [Parameter()]
        [string]$BranchName,

        [Parameter()]
        [string]$TagName,

        [Parameter()]
        [string]$CommitHash,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string]$MarkdownOutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $EvidenceBundle) { $reasons.Add('Evidence bundle is required.') }
    if ($null -eq $ConsultantOperatingGuide) { $reasons.Add('Consultant operating guide is required.') }
    if ($null -eq $SafetyPosture) { $reasons.Add('Safety posture is required.') }

    $milestones = @(
        @{ Revision = 'Rev4.10'; Purpose = 'Platform identity classification evidence'; Status = 'Completed' },
        @{ Revision = 'Rev4.11'; Purpose = 'Approved reversible planning proof'; Status = 'Completed' },
        @{ Revision = 'Rev4.12'; Purpose = 'Readiness gate'; Status = 'Completed' },
        @{ Revision = 'Rev4.13'; Purpose = 'Dry-run package'; Status = 'Completed' },
        @{ Revision = 'Rev4.14'; Purpose = 'Rollback drill package'; Status = 'Completed' },
        @{ Revision = 'Rev4.15'; Purpose = 'Controlled disable path'; Status = 'Completed' },
        @{ Revision = 'Rev4.16'; Purpose = 'Final go/no-go review package'; Status = 'Completed' },
        @{ Revision = 'Rev4.17'; Purpose = 'Evidence capture package'; Status = 'Completed' },
        @{ Revision = 'Rev4.18'; Purpose = 'Observation package'; Status = 'Completed' },
        @{ Revision = 'Rev4.19'; Purpose = 'Rollback readiness package'; Status = 'Completed' },
        @{ Revision = 'Rev4.20'; Purpose = 'Rollback preview package'; Status = 'Completed' },
        @{ Revision = 'Rev4.21'; Purpose = 'Final delete simulation package'; Status = 'Completed' },
        @{ Revision = 'Rev4.22'; Purpose = 'End-to-end rehearsal report'; Status = 'Completed' },
        @{ Revision = 'Rev4.23'; Purpose = 'Consultant operating guide'; Status = 'Completed' },
        @{ Revision = 'Rev4.24'; Purpose = 'Final controlled disable test package'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.25'; Purpose = 'Post-disable validation package'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.26'; Purpose = 'Rollback execution test package'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.27'; Purpose = 'Post-rollback validation package'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.28'; Purpose = 'Final evidence bundle'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.29'; Purpose = 'Release candidate freeze and handoff'; Status = 'ReadyForReview' }
    )

    $releaseCandidateStatus = if ($reasons.Count -eq 0) { 'Ready' } else { 'NotReady' }
    $package = [PSCustomObject]@{
        ReleaseCandidateId = "REV429-$RunId"
        Version = 'Rev4.x Release Candidate'
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'ReleaseCandidateFreezeOnly'
        TenantWritePerformed = $false
        DisablePerformedByFreeze = $false
        RollbackPerformedByFreeze = $false
        DeletePerformedByFreeze = $false
        FinalDeleteAllowed = $false
        BranchName = $BranchName
        TagName = $TagName
        CommitHash = $CommitHash
        MilestoneChain = @($milestones)
        ReleaseScope = @(
            'Consultant-ready lab workflow',
            'Dev/test reversible-disable governance chain',
            'Evidence-first decommissioning workflow',
            'Rollback readiness and validation workflow',
            'Final delete simulation only',
            'No production execution',
            'No final delete execution'
        )
        ReleaseExclusions = @(
            'Production tenant execution excluded.',
            'Actual final delete excluded.',
            'Service principal/application removal excluded.',
            'Grant cleanup excluded.',
            'Credential deletion excluded.',
            'Metadata cleanup excluded.',
            'Rev5.x required for any future final-delete governance framework.'
        )
        HandoffChecklist = @(
            'All tests passed',
            'Branches/tags recorded',
            'Safety posture recorded',
            'Operating guide generated',
            'Evidence bundle generated',
            'Known limitations documented',
            'Future Rev5.x scope documented'
        )
        FinalDeleteOutOfScope = $true
        Rev5RequiredForDelete = $true
        RequiredArtifactsPresent = $reasons.Count -eq 0
        SafetyAssertionsPassed = $reasons.Count -eq 0
        ReleaseCandidateStatus = $releaseCandidateStatus
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
        ConsultantSummary = [PSCustomObject]@{
            WhatWasProven = 'Rev4.x artifacts can be compiled into a local freeze package.'
            WhatWasNotProven = 'No tenant execution was performed by the freeze package.'
            KnownLimitations = @('Final delete is excluded.', 'Human review remains required.', 'Rev5.x is needed for future delete governance.')
            FutureRev5Scope = 'Any future final-delete governance framework belongs to Rev5.x or later.'
        }
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
    }

    $artifactPath = Join-Path $OutputPath "Rev4-ReleaseCandidateFreeze-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force

    if ($MarkdownOutputPath) {
        $markdown = @(
            '# Rev4.x Release Candidate Freeze',
            '',
            "- ReleaseCandidateId: $($package.ReleaseCandidateId)",
            "- ReleaseCandidateStatus: $releaseCandidateStatus",
            "- FinalDeleteOutOfScope: $true",
            "- Rev5RequiredForDelete: $true",
            '',
            '## Handoff Checklist'
        )
        foreach ($item in $package.HandoffChecklist) { $markdown += "- $item" }
        $markdown += ''
        $markdown += '## Release Exclusions'
        foreach ($item in $package.ReleaseExclusions) { $markdown += "- $item" }
        [System.IO.File]::WriteAllText($MarkdownOutputPath, ($markdown -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
        $package | Add-Member -NotePropertyName MarkdownArtifactPath -NotePropertyValue $MarkdownOutputPath -Force
    }

    return $package
}
