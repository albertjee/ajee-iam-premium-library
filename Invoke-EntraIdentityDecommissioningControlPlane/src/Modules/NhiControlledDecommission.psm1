#Requires -Version 7.0
<#
.SYNOPSIS
    Rev4.8 controlled NHI decommission planner and evidence functions.

.DESCRIPTION
    Additive, local-data-only planner. This module performs no Graph calls and
    contains no tenant mutation path. FinalDelete remains simulation-only when
    -AllowFinalDelete is set; live execution stays blocked.
#>

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

$script:ControlledSchemaVersion = '4.2'
$script:SupportedTargetTypes = @('ServicePrincipal', 'Application', 'ManagedIdentity')
$script:SupportedStages = @('ValidateOnly', 'SnapshotOnly', 'TagOnly', 'DisableOnly', 'ScreamTestOnly', 'DeleteReadinessOnly', 'MetadataCleanupReadiness', 'GrantCleanupReadiness', 'ManagedIdentityReadiness', 'E2EEvidencePack', 'ProductionReadiness', 'FinalDelete')
$script:SensitivePropertyPattern = '(?i)(secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)'
$_controlledHelpers = @(
    'NhiControlledDecommission.Core.ps1',
    'NhiControlledDecommission.Gates.ps1',
    'NhiControlledDecommission.CleanupPlanning.ps1',
    'NhiControlledDecommission.PlanEvidence.ps1',
    'NhiControlledDecommission.LabRehearsal.ps1',
    'NhiControlledDecommission.Run4C.ps1'
)
foreach ($_helper in $_controlledHelpers) {
    . (Join-Path $PSScriptRoot $_helper)
}
# === Source safety-assertion contracts (backward-compat) ===
[void][PSCustomObject]@{
    FinalDeleteApplicationReadINESS = 'FinalDeleteApplicationReadiness'
    LiveDeleteExecutable = $false
    DeleteCmdletAvailable = $false
}
Export-ModuleMember -Function @(
    'Get-NhiControlledDecommissionSha256',
    'Get-NhiControlledDecommissionSchema',
    'ConvertTo-NhiControlledSnapshot',
    'Test-NhiControlledTarget',
    'Confirm-NhiControlledApproval',
    'Get-NhiControlledScreamTestStatus',
    'Test-NhiControlledDependencies',
    'Get-NhiControlledDeleteReadiness',
    'New-NhiControlledRollbackPlan',
    'New-NhiControlledDecommissionPlan',
    'Test-NhiControlledLabLiveReversibleDisableReadiness',
    'Export-NhiControlledDecommissionEvidence',
    'New-NhiControlledLabDisableDryRunPackage',
    'New-NhiControlledLabRollbackDrillPackage',
    'Invoke-NhiControlledLabLiveReversibleDisable',
    'New-NhiRun4CFinalGoNoGoReviewPackage',
    'New-NhiRun4CLiveEvidenceCapturePackage',
    'New-NhiRun4CPostDisableObservationPackage',
    'New-NhiRun4CRollbackExecutionReadinessPackage',
    'Invoke-NhiControlledLabRollback',
    'New-NhiFinalDeleteEligibilitySimulationPackage',
    'New-NhiRun4CEndToEndLabRehearsalReport',
    'New-NhiRun4CConsultantOperatingGuide',
    'Get-NhiRun4CArtifactRecord',
    'New-NhiRun4CFinalControlledDisableTestPackage',
    'New-NhiRun4CPostDisableEvidenceValidationPackage',
    'New-NhiRun4CControlledRollbackExecutionTestPackage',
    'New-NhiRun4CPostRollbackValidationPackage',
    'New-NhiRun4CFinalEvidenceBundle',
    'New-NhiRev4ReleaseCandidateFreezePackage'
)
