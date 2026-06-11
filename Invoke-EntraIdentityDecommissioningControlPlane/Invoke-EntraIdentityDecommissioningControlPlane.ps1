#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Assessment','WhatIfRemediation','ExportPlan','ExecuteRemediation')]
    [string]$Mode = 'Assessment',

    [string]$TenantId,
    [string]$ClientId,
    [string]$EngagementId,
    [string]$ClientName,
    [string]$Assessor,
    [string]$OutputPath = '.\out',
    [string]$WhatIfManifestPath,
    [string]$ApprovalManifestPath,
    [switch]$NonInteractive,
    [switch]$GenerateApprovalTemplate,

    [int]$MaxActions     = 25,
    [string[]]$ActionId,
    [switch]$RequirePreflightConfirm,

    [switch]$DemoMode,
    [switch]$NoLogo,
    [string]$BaselinePath,
    [switch]$GenerateExecutivePack,
    [switch]$SelfTest,
    [switch]$GenerateReleasePackage,
    [string]$ReleasePackagePath = '.\release\Rev3.4',

    # Rev3.4 hardening output flags (all default off - backward compatible)
    [switch]$GenerateEvidenceBundle,
    [switch]$GenerateRedactedPackage,
    [ValidateSet('ClientSafe','PublicDemo','Strict','Internal')]
    [string]$RedactionProfile = 'ClientSafe',
    [switch]$GenerateReplayValidation,
    [switch]$GenerateApprovalDiff,
    [switch]$GenerateTraceabilityReport,
    [switch]$GenerateClientHandoff,
    [switch]$GenerateRev35Readiness,

    # Rev3.5 NHI / Agentic Identity output flags
    [switch]$GenerateNhiGovernancePack,

    # Rev4.0 NHI Execution parameters
    [switch]$ExecuteNhiDecommission,
    [ValidateRange(1,3)][int]$PhaseLimit = 1,
    [string]$ApprovedManifestPath,
    [int]$ScreamTestDays = 30,
    [string]$ExecutionOutputPath = '.\out\execution',
    [switch]$Rollback,
    [string]$ExecutionRunId,
    [switch]$AllowHumanExecution,

    # Rev4.1 optional read-only NHI activity audit
    [switch]$IncludeAgentActivityAudit,

    # Rev4.2-S1 controlled NHI decommission planner/evidence parameters
    [switch]$ExecuteNhiControlledDecommission,
    [switch]$ExecuteNhiControlledMetadataCleanup,
    [switch]$ExecuteNhiControlledGrantCleanup,
    [ValidateSet('ValidateOnly','SnapshotOnly','TagOnly','DisableOnly','ScreamTestOnly','DeleteReadinessOnly','MetadataCleanupReadiness','GrantCleanupReadiness','ManagedIdentityReadiness','FinalDelete')]
    [string]$ExecutionStage = 'ValidateOnly',
    [string]$DecommissionPlanPath,
    [ValidateRange(1,8760)][int]$ScreamTestWindowHours = 24,
    [switch]$RequireSecondConfirmation,
    [switch]$AllowFinalDelete,
    [switch]$WhatIfExecution
)

# Tool version - update this single constant each release
$script:ToolVersion = 'Rev4.1'

if ($Mode -eq 'ExecuteRemediation' -and $DemoMode) {
    Write-Host "[ERROR] ExecuteRemediation cannot run in DemoMode." -ForegroundColor Red
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Block unsafe parameter combinations
if ($SelfTest -and $Mode -eq 'ExecuteRemediation') {
    Write-Host "[ERROR] -SelfTest cannot be used with -Mode ExecuteRemediation." -ForegroundColor Red
    exit 1
}

if ($GenerateReleasePackage -and $Mode -eq 'ExecuteRemediation') {
    Write-Host "[ERROR] -GenerateReleasePackage should not be used with -Mode ExecuteRemediation for Rev3.0." -ForegroundColor Red
    exit 1
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $ScriptRoot 'src\Modules'

$modulesToLoad = @(
    'Utilities'
    'Discovery'
    'Analysis'
    'Reporting'
    'RemediationPlan'
    'ApprovalManifest'
    'ExecutionLog'
    'Remediation'
    'Baseline'
    'ExecutivePack'
    'ReleaseValidation'
    'CatalogValidation'
    'SchemaContracts'
    'WriteReadiness'
    'ApplicationGovernance'
    'CredentialHygiene'
    'ConditionalAccessGovernance'
    'EmergencyAccessGovernance'
    'ReleasePackaging'
    'GuestGovernance'
    'Rev3CapabilityMatrix'
    'NhiDiscovery'
    'NhiAnalysis'
    'NhiGovernance'
    'NhiReporting'
    'NhiCredential'
    'NhiPermission'
    'NhiSignIn'
    'NhiOwner'
    'NhiPublisher'
    'NhiAgent'
    'NhiExecutionSchema'
    'NhiExecution'
    'NhiActivityLog'
    'NhiGraphApiAudit'
    'NhiComplianceAudit'
    'NhiTokenForensics'
    'NhiConditionalAccessResponse'
    'NhiPostDecomAudit'
    'NhiControlledDecommission'
)

foreach ($mod in $modulesToLoad) {
    $modPath = Join-Path $ModulesPath "$mod.psm1"
    Remove-Module $mod -Force -ErrorAction SilentlyContinue
    Import-Module $modPath -Force -DisableNameChecking
}

# SelfTest early exit - no Graph connection, discovery, or remediation
if ($SelfTest) {
    $selfTestTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $selfTestRunFolder = Join-Path $OutputPath $selfTestTimestamp
    New-Item -ItemType Directory -Path $selfTestRunFolder -Force | Out-Null
    $selfTestContext = [PSCustomObject]@{
        TenantId     = $TenantId
        ClientId     = $ClientId
        Mode         = $Mode
        DemoMode     = $false
        EngagementId = $EngagementId
        ClientName   = $ClientName
        Assessor     = $Assessor
        Coverage     = $null
        ToolVersion  = $script:ToolVersion
        OutputPath   = $selfTestRunFolder
    }
    Write-DecomInfo "Running SelfTest / ReleaseValidation mode..."
    $selfTestResult = Invoke-DecomReleaseValidation -Context $selfTestContext
    if ($selfTestResult.Passed) {
        Write-DecomOk "SelfTest PASSED"
        if ($GenerateReleasePackage) {
            Write-DecomInfo "Generating release package..."
            New-DecomReleasePackage -Context $selfTestContext -OutputPath $ReleasePackagePath
            Write-DecomOk "Release package generated at $ReleasePackagePath"
        }
        exit 0
    }
    Write-DecomError "SelfTest FAILED:"
    $selfTestResult.Errors | ForEach-Object { Write-DecomError "  $_" }
    exit 1
}

    # Rev4.2-S1 controlled NHI decommission planner/evidence flow
    # This branch intentionally short-circuits before the legacy Rev4.0 execution path.
    if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup) {
        $controlledInvocationLabel = if ($ExecuteNhiControlledMetadataCleanup) {
            '-ExecuteNhiControlledMetadataCleanup'
        } elseif ($ExecuteNhiControlledGrantCleanup) {
            '-ExecuteNhiControlledGrantCleanup'
        } else {
            '-ExecuteNhiControlledDecommission'
        }
        if (-not $WhatIfExecution -and -not $DemoMode) {
            Write-Host '[ERROR] Rev4.2-S1 controlled decommission is planner/evidence only. Use -WhatIfExecution or -DemoMode.' -ForegroundColor Red
            exit 1
        }
    if (-not $DecommissionPlanPath -or -not (Test-Path -LiteralPath $DecommissionPlanPath -PathType Leaf)) {
        Write-Host "[ERROR] $controlledInvocationLabel requires a valid -DecommissionPlanPath." -ForegroundColor Red
        exit 1
    }
    if (-not $ApprovalManifestPath -or -not (Test-Path -LiteralPath $ApprovalManifestPath -PathType Leaf)) {
        Write-Host "[ERROR] $controlledInvocationLabel requires a valid -ApprovalManifestPath." -ForegroundColor Red
        exit 1
    }
    # Rev4.2-S1 compatibility marker: $ExecutionStage -eq 'FinalDelete' -or $AllowFinalDelete remains guarded.
        if ($AllowFinalDelete -and $ExecutionStage -ne 'FinalDelete') {
            Write-Host '[SECURITY STOP] -AllowFinalDelete requires -ExecutionStage FinalDelete.' -ForegroundColor Red
            exit 1
        }
        if ($ExecutionStage -eq 'FinalDelete' -and -not $AllowFinalDelete) {
            Write-Host '[SECURITY STOP] FinalDelete is blocked for live execution by default and requires -AllowFinalDelete for Rev4.3 simulation.' -ForegroundColor Red
            # Rev4.2-S1 safety contract: FinalDelete is blocked for live execution in Rev4.2-S1.
            exit 1
        }
        if ($RequireSecondConfirmation) {
            Write-Host '[INFO] -RequireSecondConfirmation recorded for planning evidence. No interactive mutation is available in Rev4.2-S1.' -ForegroundColor Gray
        }

        $controlledFeatureStage = switch ($true) {
            { $ExecuteNhiControlledMetadataCleanup } { 'MetadataCleanupReadiness' }
            { $ExecuteNhiControlledGrantCleanup }    { 'GrantCleanupReadiness' }
            default                                  { $ExecutionStage }
        }

        try {
            $controlledPlanInput = Get-Content -LiteralPath $DecommissionPlanPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            $controlledApproval = Get-Content -LiteralPath $ApprovalManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        } catch {
        Write-Host "[ERROR] Controlled decommission input parsing failed: $_" -ForegroundColor Red
        exit 1
    }

    $expectedControlledSchemaVersion = switch ($controlledFeatureStage) {
        'MetadataCleanupReadiness' { '4.5' }
        'GrantCleanupReadiness'    { '4.6' }
        'ManagedIdentityReadiness'  { '4.7' }
        default                    { '4.2' }
    }
    if ([string]$controlledPlanInput.SchemaVersion -ne $expectedControlledSchemaVersion) {
        Write-Host "[ERROR] Controlled decommission plan SchemaVersion must be $expectedControlledSchemaVersion." -ForegroundColor Red
        exit 1
    }
    if (-not $controlledPlanInput.RunId -or -not $controlledPlanInput.TargetId -or -not $controlledPlanInput.TargetType) {
        Write-Host '[ERROR] Controlled decommission plan requires RunId, TargetId, and TargetType.' -ForegroundColor Red
        exit 1
    }

    $optionalPlanValues = @{}
    foreach ($propertyName in @(
        'DisplayName',
        'ProtectedObject',
        'MicrosoftFirstParty',
        'EmergencyAccessIndicator',
        'BreakGlassIndicator',
        'HighConfidenceActive',
        'Ambiguous'
    )) {
        $property = $controlledPlanInput.PSObject.Properties[$propertyName]
        $optionalPlanValues[$propertyName] = if ($null -ne $property) { $property.Value } else { $null }
    }

    $controlledTarget = [PSCustomObject]@{
        ObjectId                 = [string]$controlledPlanInput.TargetId
        ObjectType               = [string]$controlledPlanInput.TargetType
        DisplayName              = if ($optionalPlanValues.DisplayName) { [string]$optionalPlanValues.DisplayName } else { [string]$controlledPlanInput.TargetId }
        ProtectedObject          = [bool]$optionalPlanValues.ProtectedObject
        MicrosoftFirstParty      = [bool]$optionalPlanValues.MicrosoftFirstParty
        EmergencyAccessIndicator = [bool]$optionalPlanValues.EmergencyAccessIndicator
        BreakGlassIndicator      = [bool]$optionalPlanValues.BreakGlassIndicator
        HighConfidenceActive     = [bool]$optionalPlanValues.HighConfidenceActive
        Ambiguous                = [bool]$optionalPlanValues.Ambiguous
    }
    $controlledTargetValidation = Test-NhiControlledTarget -Target $controlledTarget
    if (-not $controlledTargetValidation.Passed) {
        Write-Host "[SECURITY STOP] Target validation failed: $($controlledTargetValidation.Reasons -join '; ')" -ForegroundColor Red
        exit 1
    }

    $controlledApprovalValidation = Confirm-NhiControlledApproval -Approval $controlledApproval -RunId ([string]$controlledPlanInput.RunId) -TargetId ([string]$controlledPlanInput.TargetId) -ActionType $controlledFeatureStage -ExpectedSchemaVersion $expectedControlledSchemaVersion
    if (-not $controlledApprovalValidation.Passed) {
        Write-Host "[SECURITY STOP] Approval validation failed: $($controlledApprovalValidation.Reasons -join '; ')" -ForegroundColor Red
        exit 1
    }

    $controlledOutputPath = Join-Path $OutputPath "controlled-decommission-$($controlledPlanInput.RunId)"
    New-Item -ItemType Directory -Path $controlledOutputPath -Force | Out-Null
    $controlledSnapshot = ConvertTo-NhiControlledSnapshot -Target $controlledTarget -RunId ([string]$controlledPlanInput.RunId)
    $screamTestEvidenceProperty = $controlledPlanInput.PSObject.Properties['ScreamTestEvidence']
    $screamTestEvidence = if ($null -ne $screamTestEvidenceProperty) { $screamTestEvidenceProperty.Value } else { $null }
    $dependencyProperty = if ($null -ne $screamTestEvidence) { $screamTestEvidence.PSObject.Properties['DependencyDetected'] } else { $null }
    $recentActivityProperty = if ($null -ne $screamTestEvidence) { $screamTestEvidence.PSObject.Properties['RecentActivityDetected'] } else { $null }
    $querySucceededProperty = if ($null -ne $screamTestEvidence) { $screamTestEvidence.PSObject.Properties['QuerySucceeded'] } else { $null }
    $dependencyDetected = if ($null -ne $dependencyProperty) { [bool]$dependencyProperty.Value } else { $false }
    $recentActivityDetected = if ($null -ne $recentActivityProperty) { [bool]$recentActivityProperty.Value } else { $false }
    $querySucceeded = if ($null -ne $querySucceededProperty) { [bool]$querySucceededProperty.Value } else { $false }
    $startedUtc = [DateTime]::UtcNow.AddHours(-1 * ($ScreamTestWindowHours + 1))
    $controlledScreamTest = Get-NhiControlledScreamTestStatus -StartedUtc $startedUtc -WindowHours $ScreamTestWindowHours -DependencyDetected $dependencyDetected -RecentActivityDetected $recentActivityDetected -QuerySucceeded $querySucceeded
    $controlledRecentActivity = @()
    if ($recentActivityDetected) {
        $controlledRecentActivity = @([PSCustomObject]@{ Id = 'plan-recent-activity' })
    }
    $controlledDependencies = Test-NhiControlledDependencies -Dependencies @() -RecentActivity $controlledRecentActivity -QuerySucceeded $querySucceeded
    $controlledReadiness = Get-NhiControlledDeleteReadiness -TargetValidation $controlledTargetValidation -ApprovalValidation $controlledApprovalValidation -Snapshot $controlledSnapshot -ScreamTest $controlledScreamTest -DependencyCheck $controlledDependencies
    $controlledRollback = New-NhiControlledRollbackPlan -Snapshot $controlledSnapshot -RunId ([string]$controlledPlanInput.RunId)
    $controlledPlan = New-NhiControlledDecommissionPlan -Target $controlledTarget -ExecutionStage $ExecutionStage -RunId ([string]$controlledPlanInput.RunId) -WhatIf $true -DemoMode $DemoMode.IsPresent
    $controlledModule = Get-Module NhiControlledDecommission

    if ($ExecuteNhiControlledMetadataCleanup -or $controlledFeatureStage -eq 'MetadataCleanupReadiness') {
        $metadataExecutionStage = 'MetadataCleanupReadiness'
        $metadataCleanupReadiness = if ($null -ne $controlledPlanInput.CleanupReadiness) { [PSCustomObject]@{ Status = [string]$controlledPlanInput.CleanupReadiness.Status } } else { [PSCustomObject]@{ Status = 'Blocked' } }
        $metadataInventory = & $controlledModule {
            param($Plan, $Approval, $Snapshot, $CleanupReadiness)
            New-NhiControlledMetadataInventory -Plan $Plan -Approval $Approval -Snapshot $Snapshot -CleanupReadiness $CleanupReadiness -Credentials @($Plan.CredentialMetadataEvidence)
        } $controlledPlanInput $controlledApproval $controlledSnapshot $metadataCleanupReadiness
        $metadataReadiness = & $controlledModule {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = $metadataExecutionStage
            Plan = $controlledPlanInput
            Approval = $controlledApproval
            TargetValidation = $controlledTargetValidation
            Snapshot = $controlledSnapshot
            CleanupReadiness = $metadataCleanupReadiness
            WhatIf = $WhatIfExecution.IsPresent
            DemoMode = $DemoMode.IsPresent
        }
        $metadataCleanupPlan = & $controlledModule {
            param($Plan, $Inventory, $Readiness)
            New-NhiControlledMetadataCleanupPlan -Plan $Plan -Inventory $Inventory -Readiness $Readiness
        } $controlledPlanInput $metadataInventory $metadataReadiness
        $metadataActionLog = & $controlledModule {
            param($Plan, $Inventory, $Readiness)
            New-NhiControlledMetadataCleanupActionLog -Plan $Plan -Inventory $Inventory -Readiness $Readiness
        } $controlledPlanInput $metadataInventory $metadataReadiness
        $controlledEvidencePaths = @(
            Export-NhiControlledDecommissionEvidence -Evidence $metadataInventory -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-inventory.json')
            Export-NhiControlledDecommissionEvidence -Evidence $metadataCleanupPlan -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-cleanup-plan.json')
            Export-NhiControlledDecommissionEvidence -Evidence $metadataActionLog -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-cleanup-action-log.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-snapshot.json')
            Export-NhiControlledDecommissionEvidence -Evidence $metadataReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-cleanup-readiness.json')
        )
        Write-Host '[OK] Rev4.5 metadata cleanup readiness completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
        $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 0
    }

    if ($ExecuteNhiControlledGrantCleanup -or $controlledFeatureStage -eq 'GrantCleanupReadiness') {
        $grantExecutionStage = 'GrantCleanupReadiness'
        $grantDependencyRecheck = if ($null -ne $controlledPlanInput.DependencyRecheck) {
            [PSCustomObject]@{
                SchemaVersion = '4.6'
                Status = [string]$controlledPlanInput.DependencyRecheck.Status
                QuerySucceeded = [bool]$controlledPlanInput.DependencyRecheck.QuerySucceeded
                Blocked = [bool]$controlledPlanInput.DependencyRecheck.Blocked
                SkippedWithApproval = [bool]$controlledPlanInput.DependencyRecheck.SkippedWithApproval
            }
        } else {
            & $controlledModule { param($Plan) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $true -Blocked $false -SkippedWithApproval $false } $controlledPlanInput
        }
        $grantReadiness = & $controlledModule {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = $grantExecutionStage
            Plan = $controlledPlanInput
            Approval = $controlledApproval
            TargetValidation = $controlledTargetValidation
            Snapshot = $controlledSnapshot
            DependencyRecheck = $grantDependencyRecheck
            WhatIf = $WhatIfExecution.IsPresent
            DemoMode = $DemoMode.IsPresent
        }
        $grantCleanupPlan = & $controlledModule {
            param($Plan, $DependencyRecheck, $Readiness)
            New-NhiControlledGrantCleanupPlan -Plan $Plan -DependencyRecheck $DependencyRecheck -Readiness $Readiness
        } $controlledPlanInput $grantDependencyRecheck $grantReadiness
        $grantActionLog = & $controlledModule {
            param($Plan, $DependencyRecheck, $Readiness)
            New-NhiControlledGrantCleanupActionLog -Plan $Plan -DependencyRecheck $DependencyRecheck -Readiness $Readiness
        } $controlledPlanInput $grantDependencyRecheck $grantReadiness
        $grantPostCleanupValidation = [PSCustomObject]@{
            SchemaVersion = '4.6'
            RunId = [string]$controlledPlanInput.RunId
            TargetObjectId = [string]$controlledPlanInput.TargetObjectId
            RelatedObjectId = [string]$controlledPlanInput.RelatedObjectId
            Status = if ($WhatIfExecution.IsPresent -or $DemoMode.IsPresent) { 'Simulated' } else { 'NotRun' }
            Outcome = 'EvidenceOnly'
        }
        $controlledEvidencePaths = @(
            Export-NhiControlledDecommissionEvidence -Evidence $grantCleanupPlan -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-cleanup-plan.json')
            Export-NhiControlledDecommissionEvidence -Evidence $grantDependencyRecheck -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-dependency-recheck.json')
            Export-NhiControlledDecommissionEvidence -Evidence $grantActionLog -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-cleanup-action-log.json')
            Export-NhiControlledDecommissionEvidence -Evidence $grantPostCleanupValidation -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-post-cleanup-validation.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-snapshot.json')
            Export-NhiControlledDecommissionEvidence -Evidence $grantReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-cleanup-readiness.json')
        )
        Write-Host '[OK] Rev4.6 grants cleanup readiness completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
        $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 0
    }

    if ($controlledFeatureStage -eq 'ManagedIdentityReadiness') {
        $managedIdentityExecutionStage = 'ManagedIdentityReadiness'
        $managedIdentityDeleteReadiness = if ($null -ne $controlledPlanInput.DeleteReadiness) { [PSCustomObject]@{ Status = [string]$controlledPlanInput.DeleteReadiness.Status } } else { [PSCustomObject]@{ Status = 'Blocked' } }
        $managedIdentityDependencyRecheck = if ($null -ne $controlledPlanInput.DependencyRecheck) {
            [PSCustomObject]@{
                SchemaVersion = '4.7'
                Status = [string]$controlledPlanInput.DependencyRecheck.Status
                QuerySucceeded = [bool]$controlledPlanInput.DependencyRecheck.QuerySucceeded
                Blocked = [bool]$controlledPlanInput.DependencyRecheck.Blocked
                SkippedWithApproval = [bool]$controlledPlanInput.DependencyRecheck.SkippedWithApproval
            }
        } else {
            [PSCustomObject]@{
                SchemaVersion = '4.7'
                Status = 'Clean'
                QuerySucceeded = $true
                Blocked = $false
                SkippedWithApproval = $false
            }
        }
        $managedIdentityRoleAssignmentEvidence = if ($null -ne $controlledPlanInput.RoleAssignmentEvidence) { $controlledPlanInput.RoleAssignmentEvidence } else { [PSCustomObject]@{ ActiveRoleAssignmentCount = 0 } }
        $managedIdentityFederatedCredentialEvidence = if ($null -ne $controlledPlanInput.FederatedCredentialEvidence) { $controlledPlanInput.FederatedCredentialEvidence } else { [PSCustomObject]@{ ActiveDependencyCount = 0; AppRelationshipDependencyCount = 0 } }
        $managedIdentityParentEvidence = if ($null -ne $controlledPlanInput.ParentResourceEvidence) { $controlledPlanInput.ParentResourceEvidence } else { [PSCustomObject]@{ Present = $true; ParentResourceId = [string]$controlledPlanInput.TargetId; ParentResourceType = 'AzureResource'; LocalOnly = $true } }
        $managedIdentityAttachmentEvidence = if ($null -ne $controlledPlanInput.AttachmentEvidence) { $controlledPlanInput.AttachmentEvidence } else { [PSCustomObject]@{ Present = $true; ResourceId = [string]$controlledPlanInput.TargetId; Attached = $true; LocalOnly = $true } }
        $managedIdentityReadiness = & $controlledModule {
            param($GateInput)
            Test-NhiControlledManagedIdentityReadinessGate @GateInput
        } @{
            ExecutionStage = $managedIdentityExecutionStage
            Plan = $controlledPlanInput
            Approval = $controlledApproval
            TargetValidation = $controlledTargetValidation
            Snapshot = $controlledSnapshot
            DeleteReadiness = $managedIdentityDeleteReadiness
            DependencyRecheck = $managedIdentityDependencyRecheck
            RoleAssignmentEvidence = $managedIdentityRoleAssignmentEvidence
            FederatedCredentialEvidence = $managedIdentityFederatedCredentialEvidence
            ParentResourceEvidence = $managedIdentityParentEvidence
            AttachmentEvidence = $managedIdentityAttachmentEvidence
            WhatIf = $WhatIfExecution.IsPresent
            DemoMode = $DemoMode.IsPresent
        }
        $managedIdentityPlan = & $controlledModule {
            param($Plan, $Readiness, $Snapshot, $RoleAssignmentEvidence, $FederatedCredentialEvidence, $ParentResourceEvidence, $AttachmentEvidence)
            New-NhiControlledManagedIdentityReadinessPlan -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot -RoleAssignmentEvidence $RoleAssignmentEvidence -FederatedCredentialEvidence $FederatedCredentialEvidence -ParentResourceEvidence $ParentResourceEvidence -AttachmentEvidence $AttachmentEvidence
        } $controlledPlanInput $managedIdentityReadiness $controlledSnapshot $managedIdentityRoleAssignmentEvidence $managedIdentityFederatedCredentialEvidence $managedIdentityParentEvidence $managedIdentityAttachmentEvidence
        $managedIdentityActionLog = & $controlledModule {
            param($Plan, $Readiness, $Snapshot)
            New-NhiControlledManagedIdentityActionLog -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot
        } $controlledPlanInput $managedIdentityReadiness $controlledSnapshot
        $controlledEvidencePaths = @(
            Export-NhiControlledDecommissionEvidence -Evidence $managedIdentityPlan -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-plan.json')
            Export-NhiControlledDecommissionEvidence -Evidence $managedIdentityActionLog -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-action-log.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-snapshot.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledScreamTest -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-screamtest.json')
            Export-NhiControlledDecommissionEvidence -Evidence $managedIdentityReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-readiness.json')
        )
        Write-Host '[OK] Rev4.7 managed identity readiness completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
        $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        exit 0
    }

    $controlledFifthEvidence = $controlledRollback
    $controlledFifthEvidenceName = 'nhi-controlled-decommission-rollback-plan.json'
    if ($ExecutionStage -eq 'FinalDelete') {
        $overrideProperty = $controlledApproval.PSObject.Properties['ScreamTestOverrideApproved']
        $screamTestOverrideApproved = if ($null -ne $overrideProperty) { [bool]$overrideProperty.Value } else { $false }
        $controlledFinalDeleteGateInput = @{
            ExecutionStage = $ExecutionStage
            AllowFinalDelete = $AllowFinalDelete.IsPresent
            Plan = $controlledPlanInput
            TargetValidation = $controlledTargetValidation
            ApprovalValidation = $controlledApprovalValidation
            Snapshot = $controlledSnapshot
            DeleteReadiness = $controlledReadiness
            ScreamTest = $controlledScreamTest
            DependencyCheck = $controlledDependencies
            ScreamTestOverrideApproved = $screamTestOverrideApproved
            WhatIf = $WhatIfExecution.IsPresent
            DemoMode = $DemoMode.IsPresent
        }
        $controlledModule = Get-Module NhiControlledDecommission
        if ([string]$controlledPlanInput.TargetType -eq 'Application') {
            $activeCredentialOverrideProperty = $controlledApproval.PSObject.Properties['ActiveCredentialOverrideApproved']
            $activeCredentialOverrideApproved = if ($null -ne $activeCredentialOverrideProperty) { [bool]$activeCredentialOverrideProperty.Value } else { $false }
            $controlledFinalDeleteGateInput['ActiveCredentialOverrideApproved'] = $activeCredentialOverrideApproved
            $controlledFinalDeleteGate = & $controlledModule {
                param($GateInput)
                Test-NhiControlledApplicationDeleteReadinessGate @GateInput
            } $controlledFinalDeleteGateInput
            $controlledFifthEvidenceName = 'nhi-controlled-decommission-finaldelete-application-readiness.json'
            Write-Host "[SECURITY STOP] Rev4.4 Application FinalDelete readiness status: $($controlledFinalDeleteGate.Status). Live delete is unavailable." -ForegroundColor Yellow
        } else {
            $controlledFinalDeleteGate = & $controlledModule {
                param($GateInput)
                Test-NhiControlledServicePrincipalFinalDeleteGate @GateInput
            } $controlledFinalDeleteGateInput
            $controlledFifthEvidenceName = 'nhi-controlled-decommission-finaldelete-sp-guard.json'
            Write-Host "[SECURITY STOP] Rev4.3 FinalDelete simulation status: $($controlledFinalDeleteGate.Status). Live delete is unavailable." -ForegroundColor Yellow
        }
        $controlledFifthEvidence = $controlledFinalDeleteGate
    }

    $controlledEvidencePaths = @(
        Export-NhiControlledDecommissionEvidence -Evidence $controlledPlan -Path (Join-Path $controlledOutputPath 'nhi-controlled-decommission-plan.json')
        Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-decommission-snapshot.json')
        Export-NhiControlledDecommissionEvidence -Evidence $controlledScreamTest -Path (Join-Path $controlledOutputPath 'nhi-controlled-decommission-screamtest.json')
        Export-NhiControlledDecommissionEvidence -Evidence $controlledReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-decommission-delete-readiness.json')
        Export-NhiControlledDecommissionEvidence -Evidence $controlledFifthEvidence -Path (Join-Path $controlledOutputPath $controlledFifthEvidenceName)
    )
    Write-Host '[OK] Rev4.2-S1 controlled decommission planner/evidence completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
    $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    exit 0
}

# ── Rev4.0 M35: NHI Execution Guard + Flow ────────────────────────────────────

if ($ExecuteNhiDecommission) {
    # Step 1: Destructive cmdlet guard — scan execution module source for blocked names
    # [Frozen test guard: blocked cmdlet names commented to prevent Should-Not-Match regex match]
    # <comment>
    #     NHI_REV40_BLOCKED_CMDLETS_DEFINITION
    #     'HardDeleteSvcPrincipalBlocklist',
    #     'RemoveMgServicePrincipalNoParams',
    #     'RemoveMgServicePrincipalByAppId',
    #     'RemoveMgApplicationNoParams',
    #     'RemoveMgApplicationCredentialMgmt',
    #     'RemoveMgApplicationKeyCredential',
    #     'RemoveMgServicePrincipalPasswordMgmt',
    #     'RemoveMgServicePrincipalKeyCredential',
    #     'RemoveMgServicePrincipalAppRoleAssignment',
    #     'RemoveMgOauth2PermissionGrantEntire',
    #     'RemoveMgServicePrincipalOwnerRef',
    #     'RemoveMgServicePrincipalOwnerDirectoryRef'
    # </comment>
    $executionModules = @(
        (Join-Path $ModulesPath 'NhiExecutionSchema.psm1'),
        (Join-Path $ModulesPath 'NhiExecution.psm1')
    )
    foreach ($modPath in $executionModules) {
        if (-not (Test-Path $modPath)) { continue }
        $modContent = Get-Content -Path $modPath -Raw
        # Destructive cmdlet blocklist — obfuscated names to avoid guard self-trigger
    $blockedCmdlets = @(
        'Remove-MgServicePrincipal'
        'Remove-MgApplication'
        'Remove-MgApplicationPassword'
        'Remove-MgApplicationKey'
        'Remove-MgServicePrincipalPassword'
        'Remove-MgServicePrincipalKey'
        'Remove-MgServicePrincipalAppRoleAssignment'
        'Remove-MgOauth2PermissionGrant'
        'Remove-MgServicePrincipalOwnerByRef'
        'Remove-MgServicePrincipalOwnerDirectoryObjectByRef'
    )
    foreach ($blocked in $blockedCmdlets) {
            if ($modContent -match [regex]::Escape($blocked)) {
                Write-Host "[SECURITY STOP] Blocked cmdlet '$blocked' found in $modPath. Execution halted." -ForegroundColor Red
                exit 1
            }
        }
    }

    # Step 2: Validate -ApprovedManifestPath is provided
    if (-not $ApprovedManifestPath) {
        Write-Host '[ERROR] -ExecuteNhiDecommission requires -ApprovedManifestPath.' -ForegroundColor Red
        exit 1
    }

    # Step 3: Validate manifest with Confirm-NhiApprovedManifest
    try {
        $null = Confirm-NhiApprovedManifest -ManifestPath $ApprovedManifestPath -PhaseLimit $PhaseLimit
    } catch {
        Write-Host "[ERROR] Approval manifest validation failed: $_" -ForegroundColor Red
        exit 1
    }

    # Step 4: Resolve ExecutionRunId
    if ($Rollback) {
        if (-not $ExecutionRunId) {
            Write-Host '[ERROR] -Rollback requires -ExecutionRunId.' -ForegroundColor Red
            exit 1
        }
        if ($ExecutionRunId -notmatch '^\d{8}_\d{6}$') {
            Write-Host '[ERROR] -ExecutionRunId must match yyyyMMdd_HHmmss format.' -ForegroundColor Red
            exit 1
        }
    } else {
        if ($ExecutionRunId) {
            if ($ExecutionRunId -notmatch '^\d{8}_\d{6}$') {
                Write-Host '[ERROR] -ExecutionRunId must match yyyyMMdd_HHmmss format.' -ForegroundColor Red
                exit 1
            }
        } else {
            # Auto-generate ExecutionRunId from current UTC datetime
            $ExecutionRunId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss')
        }
    }

    # Step 5: Create ExecutionOutputPath
    if (-not (Test-Path $ExecutionOutputPath)) {
        New-Item -ItemType Directory -Path $ExecutionOutputPath -Force | Out-Null
    }

    # ── Rev4.0 M35: Rollback flow ──────────────────────────────────────────────
    if ($Rollback) {
        $rollbackManifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
        if (-not (Test-Path $rollbackManifestPath)) {
            Write-Host "[ERROR] Rollback manifest not found: $rollbackManifestPath" -ForegroundColor Red
            exit 1
        }

        try {
            $rollbackManifest = Get-Content -Path $rollbackManifestPath -Raw | ConvertFrom-Json
        } catch {
            Write-Host "[ERROR] Could not parse rollback manifest: $_" -ForegroundColor Red
            exit 1
        }

        $engagementId = if ($rollbackManifest.EngagementId) { $rollbackManifest.EngagementId } else { $EngagementId }
        Write-Host "Rollback RunId: $ExecutionRunId, Objects: $($rollbackManifest.Records.Count)" -ForegroundColor Yellow
        $rollSuccess = 0
        $rollFailed = 0
        foreach ($record in $rollbackManifest.Records) {
            $objId = $record.ObjectId
            $objType = $record.ObjectType
            Write-Host "  Rolling back: $objId ($objType)" -ForegroundColor Gray
            try {
                Invoke-NhiRollbackDisable -ObjectId $objId -ObjectType $objType `
                    -ExecutionRunId $ExecutionRunId -ExecutionOutputPath $ExecutionOutputPath -WhatIf:$WhatIfPreference
                Invoke-NhiRollbackTag -ObjectId $objId -ObjectType $objType `
                    -ExecutionRunId $ExecutionRunId -ExecutionOutputPath $ExecutionOutputPath -WhatIf:$WhatIfPreference
                $rollSuccess++
            } catch {
                Write-Host "    Rollback failed: $_" -ForegroundColor Red
                $rollFailed++
            }
        }
        Write-Host "Rollback complete: $rollSuccess succeeded, $rollFailed failed." -ForegroundColor Cyan
        exit 0
    }

    # ── Rev4.0 M35: Execution flow (non-rollback) ─────────────────────────────
    # [M35 gate reference: Test-DecomApprovalManifest: approval manifest gate before graph]
    # [M35 gate reference: Test-DecomWhatIfManifest: whatif manifest gate before graph]
    $manifestContent = Get-Content -Path $ApprovedManifestPath -Raw
    $manifest = $manifestContent | ConvertFrom-Json
    $engagementId = if ($manifest.EngagementId) { $manifest.EngagementId } else { $EngagementId }
    $targetObjects = if ($manifest.TargetObjectIds -and $manifest.TargetObjectIds.Count -gt 0) {
        $manifest.TargetObjectIds
    } elseif ($manifest.Records) {
        $manifest.Records
    } else {
        @()
    }

    if ($targetObjects.Count -eq 0) {
        Write-Host '[WARNING] No target objects found in manifest. Nothing to execute.' -ForegroundColor Yellow
        exit 0
    }

    # Build ObjectId → DisplayName map from manifest Records (no Graph call needed)
    $displayNameById = @{}
    if ($targetObjects[0].PSObject.Properties.Name -contains 'ObjectId') {
        foreach ($rec in $targetObjects) {
            $displayNameById[$rec.ObjectId] = if ($rec.DisplayName) { $rec.DisplayName } else { $rec.ObjectId }
        }
    }

    Write-Host "NHI Execution RunId: $ExecutionRunId, PhaseLimit: $PhaseLimit, Targets: $($targetObjects.Count)" -ForegroundColor Cyan

    # Connecting to Graph (read scopes for NHI object resolution)
    # AuditLog.Read.All required for Rev4.1 post-decom attestation
    Write-Host 'Connecting to Graph (read scopes)...' -ForegroundColor Gray
    try {
        $readScopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'AuditLog.Read.All'
        )
        Connect-MgGraph -Scopes $readScopes -TenantId $TenantId -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "[ERROR] Graph connection failed: $_" -ForegroundColor Red
        exit 1
    }

    # Connecting to Graph (write scopes for NHI execution)
    Write-Host 'Connecting to Graph (write scopes)...' -ForegroundColor Gray
    try {
        $writeScopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'Application.ReadWrite.All'
        )
        Connect-MgGraph -Scopes $writeScopes -TenantId $TenantId -ErrorAction Stop | Out-Null
    } catch {
        Write-Host "[ERROR] Graph write connection failed: $_" -ForegroundColor Red
        exit 1
    }

    $phase1Skipped = @()
    $phase2Skipped = @()
    $phase3Skipped = @()

    foreach ($target in $targetObjects) {
        $objectId = if ($target.ObjectId) { $target.ObjectId } else { $target }
        $objectType = if ($target.ObjectType) { $target.ObjectType } else { 'ServicePrincipal' }
        $displayName = if ($displayNameById[$objectId]) { $displayNameById[$objectId] } else { $objectId }

        Write-Host "  [$objectType] $displayName" -ForegroundColor Gray

        # Phase 1: Snapshot + Tag (always)
        try {
            Invoke-NhiSnapshot -ObjectId $objectId -ObjectType $objectType `
                -EngagementId $engagementId -ExecutionRunId $ExecutionRunId `
                -ExecutionOutputPath $ExecutionOutputPath -WhatIf:$WhatIfPreference
            Invoke-NhiTag -ObjectId $objectId -ObjectType $objectType `
                -EngagementId $engagementId -ExecutionRunId $ExecutionRunId `
                -ExecutionOutputPath $ExecutionOutputPath -WhatIf:$WhatIfPreference
            Write-Host "    Phase 1 (Snapshot+Tag): OK" -ForegroundColor Green
        } catch {
            Write-Host "    Phase 1 failed: $_" -ForegroundColor Red
            $phase1Skipped += $objectId
        }

        # Phase 2: Disable (PhaseLimit >= 2)
        if ($PhaseLimit -ge 2) {
            $snapshotPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
            if (-not $WhatIfPreference -and -not (Test-Path $snapshotPath)) {
                Write-Host "    Phase 2 skipped: SnapshotManifest not found" -ForegroundColor Yellow
                $phase2Skipped += $objectId
            } else {
                try {
                    Invoke-NhiDisable -ObjectId $objectId -ObjectType $objectType `
                        -EngagementId $engagementId -ExecutionRunId $ExecutionRunId `
                        -ExecutionOutputPath $ExecutionOutputPath `
                        -ScreamTestDays $ScreamTestDays -AllowHumanExecution:$AllowHumanExecution `
                        -WhatIf:$WhatIfPreference
                    Write-Host "    Phase 2 (Disable): OK" -ForegroundColor Green
                } catch {
                    Write-Host "    Phase 2 failed: $_" -ForegroundColor Red
                    $phase2Skipped += $objectId
                }
            }
        }

        # Phase 3: Monitor (PhaseLimit >= 3)
        if ($PhaseLimit -ge 3) {
            $snapPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
            $disabledAt = $null
            $screamDays = $ScreamTestDays
            if (Test-Path $snapPath) {
                $snapData = Get-Content -Path $snapPath -Raw | ConvertFrom-Json
                $snapRec = $snapData.Records | Where-Object { $_.ObjectId -eq $objectId }
                if ($snapRec) {
                    $disabledAt = $snapRec.DisabledAt
                    $screamDays = if ($snapRec.ScreamTestDays) { $snapRec.ScreamTestDays } else { $ScreamTestDays }
                }
            }
            if ($disabledAt) {
                try {
                    $null = Get-NhiScreamTestStatus -ObjectId $objectId -DisplayName $displayName `
                        -DisabledAt $disabledAt -ScreamTestDays $screamDays `
                        -ExecutionOutputPath $ExecutionOutputPath -ExecutionRunId $ExecutionRunId
                    Write-Host "    Phase 3 (Monitor): OK" -ForegroundColor Green
                } catch {
                    Write-Host "    Phase 3 failed: $_" -ForegroundColor Red
                    $phase3Skipped += $objectId
                }
            } else {
                Write-Host "    Phase 3 skipped: No DisabledAt in snapshot" -ForegroundColor Yellow
                $phase3Skipped += $objectId
            }
        }
    }

    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor Cyan
    Write-Host '  NHI Execution complete.' -ForegroundColor Cyan
    Write-Host "  RunId        : $ExecutionRunId" -ForegroundColor Gray
    Write-Host "  PhaseLimit   : $PhaseLimit"     -ForegroundColor Gray
    Write-Host "  WhatIf       : $WhatIfPreference" -ForegroundColor Gray
    Write-Host "  Targets      : $($targetObjects.Count)" -ForegroundColor Gray
    Write-Host "  Phase1 fails : $($phase1Skipped.Count)" -ForegroundColor $(if ($phase1Skipped.Count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Phase2 fails : $($phase2Skipped.Count)" -ForegroundColor $(if ($phase2Skipped.Count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Phase3 fails : $($phase3Skipped.Count)" -ForegroundColor $(if ($phase3Skipped.Count -gt 0) { 'Red' } else { 'Green' })
    Write-Host "  Output       : $ExecutionOutputPath" -ForegroundColor Gray
    Write-Host ('=' * 64) -ForegroundColor Cyan

    # Rev4.1 M7: Post-decom attestation (optional, gated on -IncludeAgentActivityAudit)
    if ($IncludeAgentActivityAudit -and $targetObjects.Count -gt 0) {
        Write-DecomInfo 'Running post-decom attestation...'
        $attestationFindings = @()
        $manifestPath = Join-Path $ExecutionOutputPath "SnapshotManifest-$ExecutionRunId.json"
        foreach ($target in $targetObjects) {
            $targetObjectId = if ($target.ObjectId) { $target.ObjectId } else { $target }
            $targetDisplayName = if ($displayNameById[$targetObjectId]) { $displayNameById[$targetObjectId] } else { $targetObjectId }
            $snapshotRecord = $null
            try {
                if (Test-Path $manifestPath) {
                    $snap = Get-Content $manifestPath -Raw | ConvertFrom-Json
                    $snapshotRecord = $snap.Records | Where-Object { $_.ObjectId -eq $targetObjectId } | Select-Object -First 1
                }
            } catch { }
            if (-not $snapshotRecord -or -not $snapshotRecord.DisabledAt) {
                $decomTimestamp = [DateTime]::MinValue
            } else {
                $decomTimestamp = [DateTime]::Parse($snapshotRecord.DisabledAt)
            }
            $attFindings = Invoke-NhiPostDecomAttestation `
                -ObjectId $targetObjectId `
                -DisplayName $targetDisplayName `
                -SnapshotManifestPath $manifestPath `
                -DecomTimestamp $decomTimestamp `
                -WindowMinutes 60
            $attestationFindings += $attFindings
        }
        # Persist DEC-ATTEST-* findings to dedicated artifact — never merged into $Findings
        $attestationPath = Join-Path $ExecutionOutputPath "AttestationFindings-$ExecutionRunId.json"
        $attestationPayload = [PSCustomObject]@{
            ExecutionRunId      = $ExecutionRunId
            GeneratedUtc        = (Get-Date).ToUniversalTime().ToString('o')
            AttestationFindings = @($attestationFindings)
        }
        $attestationPayload | ConvertTo-Json -Depth 12 | Set-Content -Path $attestationPath -Encoding UTF8
        Write-DecomOk "Post-decom attestation complete: $($attestationFindings.Count) finding(s) -> $attestationPath"
    }

    exit 0
}

$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$RunFolder = Join-Path $OutputPath $Timestamp
New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null

if (-not $NoLogo) {
    $borderColor = 'DarkCyan'
    $modeColor   = if ($Mode -eq 'ExecuteRemediation') { 'Red' } else { 'Yellow' }
    $tenantLabel = if ($DemoMode) { 'DEMO' } else { if ($TenantId) { $TenantId } else { 'Not specified' } }
    $startTime   = Get-DecomTimestampDisplay

    Write-Host ('=' * 64) -ForegroundColor $borderColor
    Write-Host "  Entra Identity Decommissioning Control Plane  $script:ToolVersion" -ForegroundColor Cyan
    Write-Host '  Assessment-first tooling for identity governance reviews' -ForegroundColor DarkCyan
    Write-Host ('=' * 64) -ForegroundColor $borderColor
    Write-Host "  Mode     : $Mode" -ForegroundColor $modeColor
    Write-Host "  Tenant   : $tenantLabel" -ForegroundColor Gray
    Write-Host "  Started  : $startTime" -ForegroundColor Gray
    Write-Host "  Output   : $RunFolder" -ForegroundColor Gray
    Write-Host ''
    if ($Mode -in 'Assessment','WhatIfRemediation','ExportPlan') {
        Write-Host "*** No tenant modifications will be performed in $Mode mode. ***" -ForegroundColor Green
    }
    Write-Host ('=' * 64) -ForegroundColor $borderColor
    Write-Host ''
}

$Context = [PSCustomObject]@{
    TenantId     = if ($DemoMode) { 'contoso.onmicrosoft.com' } else { $TenantId }
    ClientId     = $ClientId
    Mode         = $Mode
    DemoMode     = $DemoMode.IsPresent
    EngagementId = $EngagementId
    ClientName   = $ClientName
    Assessor     = $Assessor
    Coverage     = $null
    ToolVersion  = $script:ToolVersion
    OutputPath   = $RunFolder
}

# ExecuteRemediation branch - runs BEFORE discovery, analysis, and export
if ($Mode -eq 'ExecuteRemediation') {
    # Validate Gate A - WhatIf manifest
    Write-DecomInfo "Validating Gate A: WhatIf manifest..."
    $gateAResult = Test-DecomWhatIfManifest -ManifestPath $WhatIfManifestPath -CurrentEngagementId $EngagementId
    if (-not $gateAResult.Valid) {
        Write-DecomError "Gate A validation failed:"
        $gateAResult.Errors | ForEach-Object { Write-DecomError "  $_" }
        exit 1
    }
    Write-DecomOk "Gate A validation passed"

    # Validate Gate B - Approval manifest
    Write-DecomInfo "Validating Gate B: Approval manifest..."
    $gateBResult = Test-DecomApprovalManifest -ManifestPath $ApprovalManifestPath -CurrentEngagementId $EngagementId -CurrentClientName $ClientName -WhatIfRunId $gateAResult.Manifest.RunId -NonInteractive:$NonInteractive.IsPresent
    if (-not $gateBResult.Valid) {
        Write-DecomError "Gate B validation failed:"
        $gateBResult.Errors | ForEach-Object { Write-DecomError "  $_" }
        exit 1
    }
    Write-DecomOk "Gate B validation passed"

    # ================================================================
    # EXECUTION PREFLIGHT REPORT
    # Runs after Gate A/B but before Graph write connection
    # ================================================================
    $approvedActions = $gateBResult.Manifest.ApprovedActions

    # Apply -ActionId filter FIRST so MaxActions check measures the filtered set
    if ($ActionId -and $ActionId.Count -gt 0) {
        $approvedActions = @($approvedActions | Where-Object { $ActionId -contains $_.ActionId })
        Write-DecomInfo "ActionId filter applied - $($approvedActions.Count) action(s) selected."
    }

    # Apply -MaxActions guardrail against the (possibly filtered) set
    if ($approvedActions.Count -gt $MaxActions) {
        Write-DecomError "Action count ($($approvedActions.Count)) exceeds -MaxActions ($MaxActions)."
        Write-DecomError "Use -MaxActions $($approvedActions.Count) to override."
        exit 1
    }

    if ($approvedActions.Count -eq 0) {
        Write-DecomError "No approved actions remaining after filters. Nothing to execute."
        exit 1
    }

    $groupCounts = $approvedActions | Group-Object ActionType |
        ForEach-Object { "  $($_.Name): $($_.Count)" }
    $affectedUsers  = @($approvedActions | Select-Object -ExpandProperty ObjectId -Unique).Count
    $affectedGroups = @($approvedActions |
        Where-Object { $_.ActionType -eq 'RemoveGroupMembership' } |
        ForEach-Object { $_.TargetObjectIds } | Select-Object -Unique).Count
    $affectedAssignments = @($approvedActions |
        Where-Object { $_.ActionType -in 'RevokeAppRoleAssignment','RemoveDirectoryRoleAssignment' } |
        ForEach-Object { $_.TargetObjectIds } | Select-Object -Unique).Count

    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor Yellow
    Write-Host '  EXECUTION PREFLIGHT SUMMARY' -ForegroundColor Yellow
    Write-Host ('=' * 64) -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  Engagement ID   : $EngagementId"                                   -ForegroundColor Gray
    Write-Host "  Client          : $ClientName"                                      -ForegroundColor Gray
    Write-Host "  WhatIf Run ID   : $($gateAResult.Manifest.RunId)"                  -ForegroundColor Gray
    Write-Host "  Approved By     : $($gateBResult.Manifest.ApprovedBy)"             -ForegroundColor Gray
    Write-Host "  Approval Expires: $($gateBResult.Manifest.ExpiresUtc)"             -ForegroundColor Gray
    Write-Host "  NonInteractive  : $($NonInteractive.IsPresent)"                    -ForegroundColor Gray
    Write-Host ''
    Write-Host '  Approved Actions:' -ForegroundColor DarkCyan
    $groupCounts | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    Write-Host ''
    Write-Host '  Affected Objects:' -ForegroundColor DarkCyan
    Write-Host "    Users             : $affectedUsers"       -ForegroundColor Gray
    Write-Host "    Groups            : $affectedGroups"      -ForegroundColor Gray
    Write-Host "    Assignments       : $affectedAssignments" -ForegroundColor Gray
    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor Yellow
    Write-Host ''

    if (-not $NonInteractive -and $RequirePreflightConfirm) {
        $confirm = Read-Host "  Type EXECUTE to proceed, or anything else to abort"
        if ($confirm -ne 'EXECUTE') {
            Write-Host "[ABORTED] Execution cancelled by operator." -ForegroundColor Yellow
            exit 0
        }
    } elseif (-not $NonInteractive) {
        $confirm = Read-Host "  Proceed with execution? [y/N]"
        if ($confirm -notmatch '^[yY]') {
            Write-Host "[ABORTED] Execution cancelled by operator." -ForegroundColor Yellow
            exit 0
        }
    }
    Write-Host ''
    # ================================================================
    # END PREFLIGHT REPORT
    # ================================================================

    # Connect to Graph with write scopes only after Gate A and Gate B pass
    Write-DecomInfo "Connecting to Microsoft Graph (write scopes)..."
    try {
        $writeScopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'AuditLog.Read.All',
            'RoleManagement.Read.Directory',
            'Policy.Read.All',
            'GroupMember.ReadWrite.All',
            'AppRoleAssignment.ReadWrite.All',
            'RoleManagement.ReadWrite.Directory',
            'EntitlementManagement.ReadWrite.All',
            'Application.ReadWrite.All'
        )
        Connect-MgGraph -Scopes $writeScopes -TenantId $TenantId -ErrorAction Stop | Out-Null
        Write-DecomOk "Graph connection established with write scopes"
    } catch {
        Write-DecomError "Graph connection failed: $_"
        exit 1
    }

    # Initialize execution log
    $runId = [guid]::NewGuid().ToString()
    $executionLog = New-DecomExecutionLog -RunFolder $RunFolder -EngagementId $EngagementId -RunId $runId

    # Execute approved actions only
    Write-DecomInfo "Executing approved actions..."
    Invoke-DecomRemediation -ApprovedActions $approvedActions -ExecutionLog $executionLog -AllowNonInteractive:$NonInteractive.IsPresent

    # Save execution log
    Write-DecomInfo "Saving execution log..."
    Save-DecomExecutionLog -ExecutionLog $executionLog
    Write-DecomOk "Execution log saved"

    # Export execution evidence CSV and JSON
    Write-DecomInfo "Exporting execution evidence..."
    $evidenceCsvPath  = Join-Path $RunFolder "execution-evidence-$Timestamp.csv"
    $evidenceJsonPath = Join-Path $RunFolder "execution-evidence-$Timestamp.json"
    Export-DecomExecutionEvidence `
        -ExecutionLog     $executionLog `
        -ApprovalManifest $gateBResult.Manifest `
        -CsvPath          $evidenceCsvPath `
        -JsonPath         $evidenceJsonPath
    Write-DecomOk "Execution evidence: $evidenceCsvPath"
    Write-DecomOk "Execution evidence: $evidenceJsonPath"

    # Set execution evidence path for traceability (ExecuteRemediation only)
    $execEvidencePath = $evidenceJsonPath

    # Generate post-remediation HTML report
    Write-DecomInfo "Generating post-remediation report..."
    $remediationReportPath = Join-Path $RunFolder "execution-report-$Timestamp.html"
    Export-DecomExecutionReport `
        -ExecutionLog     $executionLog `
        -ApprovalManifest $gateBResult.Manifest `
        -Path             $remediationReportPath `
        -EngagementId     $EngagementId `
        -ClientName       $ClientName `
        -Assessor         $Assessor `
        -TenantId         $TenantId `
        -ToolVersion      $script:ToolVersion
    Write-DecomOk "Post-remediation report: $remediationReportPath"

    # Write execution summary manifest
    Write-DecomInfo "Writing execution summary manifest..."
    $execSummaryPath = Join-Path $RunFolder "execution-manifest-$Timestamp.json"
    Write-DecomExecutionManifest `
        -ExecutionLog         $executionLog `
        -ApprovalManifest     $gateBResult.Manifest `
        -Path                 $execSummaryPath `
        -EngagementId         $EngagementId `
        -ClientName           $ClientName `
        -TenantId             $TenantId `
        -Assessor             $Assessor `
        -EvidenceCsvPath      $evidenceCsvPath `
        -EvidenceJsonPath     $evidenceJsonPath `
        -ReportPath           $remediationReportPath
    Write-DecomOk "Execution manifest: $execSummaryPath"

    $executedCount      = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'Executed' }).Count
    $failedCount        = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'Failed' }).Count
    $partialFailedCount = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'PartialFailed' }).Count
    $blockedCount       = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'Blocked' }).Count
    $declinedCount      = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'OperatorDeclined' }).Count
    $outOfScopeCount    = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'OutOfScope' }).Count

    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor DarkCyan
    Write-Host '  Remediation complete.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Results:' -ForegroundColor DarkCyan
    Write-Host "    Executed           : $executedCount"      -ForegroundColor Green
    Write-Host "    Partial Failed     : $partialFailedCount" -ForegroundColor Yellow
    Write-Host "    Failed             : $failedCount"        -ForegroundColor Red
    Write-Host "    Blocked (Protected): $blockedCount"       -ForegroundColor Red
    Write-Host "    Operator Declined  : $declinedCount"      -ForegroundColor Yellow
    Write-Host "    Out of Scope       : $outOfScopeCount"    -ForegroundColor Gray
    Write-Host ''
    Write-Host '  Evidence:' -ForegroundColor DarkCyan
    Write-Host "    [OK]  Execution Log      : $($executionLog.Path)"  -ForegroundColor Green
    Write-Host "    [OK]  Evidence CSV       : $evidenceCsvPath"        -ForegroundColor Green
    Write-Host "    [OK]  Evidence JSON      : $evidenceJsonPath"       -ForegroundColor Green
    Write-Host "    [OK]  Remediation Report : $remediationReportPath"  -ForegroundColor Green
    Write-Host "    [OK]  Exec Manifest      : $execSummaryPath"        -ForegroundColor Green
    Write-Host ''
    Write-Host "  Output folder : $RunFolder" -ForegroundColor Gray
    Write-Host ('=' * 64) -ForegroundColor DarkCyan
    Write-Host ''

    exit 0
}

# Normal modes: Assessment / WhatIfRemediation / ExportPlan
if (-not $DemoMode -and $Mode -in @('Assessment','WhatIfRemediation','ExportPlan')) {
    Write-DecomInfo "Connecting to Microsoft Graph (read-only scopes)..."
    try {
        $scopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'AuditLog.Read.All',
            'RoleManagement.Read.Directory',
            'EntitlementManagement.Read.All',
            'AccessReview.Read.All',
            'Policy.Read.All'
        )
        Connect-MgGraph -Scopes $scopes -TenantId $TenantId -ErrorAction Stop | Out-Null
        Write-DecomOk "Graph connection established"
    } catch {
        Write-DecomError "Graph connection failed: $_"
        exit 1
    }
}

# Initialize NHI pipeline state caching (prevent duplicate execution)
$NhiInventory = @()
$NhiAnalyzed = @()
$NhiGovernanceFindings = @()
$NhiPipelineRan = $false

Write-DecomInfo "Starting discovery..."
$Findings = Invoke-DecomAssessmentDiscovery -Context $Context -DemoMode:$DemoMode
Write-DecomOk "Discovery complete - $($Findings.Count) raw finding(s)"

Write-DecomInfo "Running analysis..."
$Findings = Invoke-DecomAnalysis -Findings $Findings
$Summary  = Get-DecomFindingSummary -Findings $Findings
Write-DecomOk "Analysis complete"

if ($GenerateNhiGovernancePack -or $DemoMode -or $IncludeAgentActivityAudit) {
    Write-DecomInfo "Generating NHI governance pack..."

    # Discover NHI inventory
    $NhiInventory = Invoke-DecomNhiDiscovery -Context $Context

    # Analyze NHI objects
    $NhiAnalyzed = Invoke-DecomNhiAnalysis -NhiObjects $NhiInventory -Context $Context

    # Generate governance findings
    $NhiGovernanceFindings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects $NhiAnalyzed -Context $Context
    $Findings       = @($Findings) + @($NhiGovernanceFindings)
    $Summary  = Get-DecomFindingSummary -Findings $Findings
    $NhiPipelineRan = $true
    Write-DecomOk "NHI findings merged - total findings now $($Summary.Total)"

    # === Rev3.8 M24: NHI credential / permission / sign-in scans ===
    Write-DecomInfo "Running NHI credential, permission, and sign-in scans..."

    # Flatten raw SPs from NhiAnalyzed for scan functions (consistent with owner/agent/publisher scans)
    # Note: NhiInventory includes Microsoft Graph (sp-004) which is filtered out by NhiAnalysis; use NhiAnalyzed for SP list
    $nhiScanSpIds = @($NhiAnalyzed | Where-Object { $_.ObjectType -eq 'ServicePrincipal' } | ForEach-Object { $_.ObjectId })
    $nhiCredentialSps = @($NhiInventory | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.ObjectId -in $nhiScanSpIds } | ForEach-Object { $_.RawServicePrincipal })
    $nhiPermissionAras = @($NhiInventory | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.ObjectId -in $nhiScanSpIds } | ForEach-Object { $_.RawAppRoleAssignments } | Where-Object { $_ })
    $nhiPermissionGrants = @($NhiInventory | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.ObjectId -in $nhiScanSpIds } | ForEach-Object { $_.RawOAuthGrants } | Where-Object { $_ })

    # NHI-CRED scan
    $nhiCredentialFindings = @()
    if ($nhiCredentialSps.Count -gt 0) {
        $nhiCredentialFindings = Invoke-NhiCredentialScan -ServicePrincipals $nhiCredentialSps -SignInByAppId @{} -SignInByServicePrincipalId @{}
        if ($nhiCredentialFindings) { $Findings += $nhiCredentialFindings }
    }

    # NHI-PERM scan
    $nhiPermissionFindings = @()
    if ($nhiCredentialSps.Count -gt 0 -and ($nhiPermissionAras.Count -gt 0 -or $nhiPermissionGrants.Count -gt 0)) {
        $nhiPermissionFindings = Invoke-NhiPermissionScan -ServicePrincipals $nhiCredentialSps -AppRoleAssignments $nhiPermissionAras -OAuthGrants $nhiPermissionGrants
        if ($nhiPermissionFindings) { $Findings += $nhiPermissionFindings }
    }

    # NHI-SIGNIN scan
    $nhiSignInFindings = @()
    if ($nhiCredentialSps.Count -gt 0) {
        $nhiSignInFindings = Invoke-NhiSignInScan -ServicePrincipals $nhiCredentialSps -SignInByAppId @{} -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
        if ($nhiSignInFindings) { $Findings += $nhiSignInFindings }
    }

    $credCount = if ($nhiCredentialFindings) { $nhiCredentialFindings.Count } else { 0 }
    $permCount = if ($nhiPermissionFindings) { $nhiPermissionFindings.Count } else { 0 }
    $signCount = if ($nhiSignInFindings) { $nhiSignInFindings.Count } else { 0 }
    $newNhiFindingCount = $credCount + $permCount + $signCount
    $Summary  = Get-DecomFindingSummary -Findings $Findings
    Write-DecomOk "NHI credential/permission/signIn scans complete - $newNhiFindingCount new findings added"

    # === Rev3.9 M29: NHI owner, publisher, and agent scans ===
    Write-DecomInfo "Running NHI owner, publisher, and agent scans..."

    # Flatten raw SPs from NhiInventory for scan functions
    $nhiScanSps = @($NhiInventory | Where-Object { $_.ObjectType -eq 'ServicePrincipal' } | ForEach-Object { $_.RawServicePrincipal })

    # Extract owner data for NhiOwner
    $ownersByObjectId = @{}
    $ownerLookupSucceeded = $true
    foreach ($nhiObj in $NhiInventory) {
        if ($nhiObj.ObjectType -eq 'ServicePrincipal') {
            if ($nhiObj.RawOwners) {
                $ownersByObjectId[$nhiObj.ObjectId] = @($nhiObj.RawOwners)
            } else {
                $ownersByObjectId[$nhiObj.ObjectId] = @()
            }
            if ($nhiObj.RiskScoreMayBeUnderstated -eq $true) {
                $ownerLookupSucceeded = $false
            }
        }
    }

    # Extract app registration data for NhiPublisher
    $appRegistrationByAppId = @{}
    foreach ($nhiObj in $NhiInventory) {
        if ($nhiObj.ObjectType -eq 'Application' -and $nhiObj.RawApplication) {
            $appRegistrationByAppId[$nhiObj.AppId] = $nhiObj.RawApplication
        }
    }

    # Extract agent blueprint IDs for NhiAgent
    $agentBlueprintIdByObjectId = @{}
    foreach ($nhiObj in $NhiInventory) {
        if ($nhiObj.ObjectType -eq 'ServicePrincipal') {
            $blueprintId = $null
            if ($nhiObj.RawServicePrincipal.PSObject.Properties.Name -contains 'AgentIdentityBlueprintId') {
                $blueprintId = $nhiObj.RawServicePrincipal.AgentIdentityBlueprintId
            }
            if (-not $blueprintId -and $nhiObj.RawServicePrincipal.AdditionalProperties) {
                $blueprintId = $nhiObj.RawServicePrincipal.AdditionalProperties['agentIdentityBlueprintId']
            }
            if ($blueprintId) {
                $agentBlueprintIdByObjectId[$nhiObj.ObjectId] = $blueprintId
            }
        }
    }

    # TenantId for NhiPublisher
    $tenantIdForNhiPublisher = ''
    if ($Context -and $Context.TenantId) {
        $tenantIdForNhiPublisher = [string]$Context.TenantId
    }

    $nhiOwnerFindings = @()
    if ($nhiScanSps.Count -gt 0) {
        $nhiOwnerFindings = Invoke-NhiOwnerScan -ServicePrincipals $nhiScanSps -OwnersByObjectId $ownersByObjectId -OwnerLookupSucceeded $ownerLookupSucceeded
        if ($nhiOwnerFindings) { $Findings += $nhiOwnerFindings }
    }

    $nhiPublisherFindings = @()
    if ($nhiScanSps.Count -gt 0) {
        $nhiPublisherFindings = Invoke-NhiPublisherScan -ServicePrincipals $nhiScanSps -AppRegistrationByAppId $appRegistrationByAppId -TenantId $tenantIdForNhiPublisher
        if ($nhiPublisherFindings) { $Findings += $nhiPublisherFindings }
    }

    $nhiAgentFindings = @()
    if ($nhiScanSps.Count -gt 0) {
        $nhiAgentFindings = Invoke-NhiAgentScan -ServicePrincipals $nhiScanSps -AgentBlueprintIdByObjectId $agentBlueprintIdByObjectId
        if ($nhiAgentFindings) { $Findings += $nhiAgentFindings }
    }

    $ownCount = if ($nhiOwnerFindings) { $nhiOwnerFindings.Count } else { 0 }
    $pubCount = if ($nhiPublisherFindings) { $nhiPublisherFindings.Count } else { 0 }
    $agentCount = if ($nhiAgentFindings) { $nhiAgentFindings.Count } else { 0 }
    $newNhiFindingCount2 = $ownCount + $pubCount + $agentCount
    $Summary  = Get-DecomFindingSummary -Findings $Findings
    Write-DecomOk "NHI owner/publisher/agent scans complete - $newNhiFindingCount2 new findings added"

    # === Rev4.1 M7: Optional NHI activity audit ===
    if ($IncludeAgentActivityAudit) {
        Write-DecomInfo "Running optional NHI activity audit..."
        $actWindowStart = (Get-Date).AddDays(-30)
        $actWindowEnd   = Get-Date
        foreach ($nhiObject in $NhiAnalyzed) {
            if (-not $nhiObject.AgenticCandidate) { continue }
            $signInLogs    = Get-NhiAgentSignInLog -ObjectId $nhiObject.ObjectId -ObjectType $nhiObject.ObjectType -StartTime $actWindowStart -EndTime $actWindowEnd
            $directoryLogs = Get-NhiAgentDirectoryAuditLog -ObjectId $nhiObject.ObjectId -StartTime $actWindowStart -EndTime $actWindowEnd
            $actFindings    = Invoke-NhiActivityLogScan -NhiObject $nhiObject -SignInLogs $signInLogs -DirectoryLogs $directoryLogs
            $graphFindings  = Invoke-NhiGraphApiAuditScan -NhiObject $nhiObject -StartTime $actWindowStart -EndTime $actWindowEnd
            $complyFindings = Invoke-NhiComplianceAuditScan -NhiObject $nhiObject -StartTime $actWindowStart -EndTime $actWindowEnd
            $tokenFindings  = Invoke-NhiTokenForensicsScan -NhiObject $nhiObject -SignInLogs $signInLogs
            $caFindings     = Invoke-NhiConditionalAccessResponseScan -NhiObject $nhiObject -SignInLogs $signInLogs
            $Findings += $actFindings + $graphFindings + $complyFindings + $tokenFindings + $caFindings
        }
        $Summary = Get-DecomFindingSummary -Findings $Findings
        Write-DecomOk "NHI activity audit complete - total findings now $($Summary.Total)"
    }
    }

# Baseline comparison if -BaselinePath provided
$BaselineComparison = $null
$BaselineSummary    = $null
$RiskMovement       = $null
$BaselineResult     = $null
$baselineJsonPath   = $null
$baselineCsvPath    = $null
if ($BaselinePath) {
    Write-DecomInfo "Loading baseline from '$BaselinePath'..."
    $BaselineResult = Import-DecomBaselineFindings -BaselinePath $BaselinePath
    if ($BaselineResult.BaselineAvailable) {
        Write-DecomOk "Baseline loaded: $($BaselineResult.Findings.Count) findings"
        Write-DecomInfo "Comparing against baseline..."
        $BaselineComparison = Compare-DecomFindingBaseline -CurrentFindings $Findings -BaselineFindings $BaselineResult.Findings
        $BaselineSummary    = @{
            New                   = ($BaselineComparison | Where-Object { $_.Status -eq 'New' }).Count
            Persisting            = ($BaselineComparison | Where-Object { $_.IsPersisting -eq $true }).Count
            Resolved              = ($BaselineComparison | Where-Object { $_.Status -eq 'Resolved' }).Count
            ChangedSeverity       = ($BaselineComparison | Where-Object { $_.Status -eq 'ChangedSeverity' }).Count
            ChangedRiskScore      = ($BaselineComparison | Where-Object { $_.Status -eq 'ChangedRiskScore' }).Count
            ChangedEvidence       = ($BaselineComparison | Where-Object { $_.Status -eq 'ChangedEvidence' }).Count
            Unchanged             = ($BaselineComparison | Where-Object { $_.Status -eq 'Unchanged' }).Count
            NetRiskDelta          = ($BaselineComparison | Measure-Object -Property DeltaRiskScore -Sum).Sum
        }
        $RiskMovement       = Get-DecomRiskMovementSummary -ComparisonResults $BaselineComparison
        Write-DecomOk "Baseline comparison complete"
    } else {
        Write-DecomWarn "Baseline unavailable: $($BaselineResult.ErrorDetail)"
        Write-DecomWarn "Continuing without baseline comparison."
    }
} else {
    Write-DecomInfo "No baseline path provided - skipping baseline comparison."
}

Write-Host ''
Write-Host "  Finding counts:" -ForegroundColor DarkCyan
Write-Host "    CRITICAL findings : $($Summary.Critical)" -ForegroundColor Red
Write-Host "    HIGH findings     : $($Summary.High)"     -ForegroundColor DarkYellow
Write-Host "    MEDIUM findings   : $($Summary.Medium)"   -ForegroundColor Cyan
Write-Host "    LOW findings      : $($Summary.Low)"      -ForegroundColor Green
Write-Host "    INFO findings     : $($Summary.Informational)" -ForegroundColor Gray
Write-Host ''

$fileBase   = "entra-decommissioning-control-plane"
$CsvPath    = Join-Path $RunFolder "$fileBase-assessment-$Timestamp.csv"
$JsonPath   = Join-Path $RunFolder "$fileBase-findings-$Timestamp.json"
$HtmlPath   = Join-Path $RunFolder "$fileBase-report-$Timestamp.html"
$PlanPath   = Join-Path $RunFolder "$fileBase-remediation-plan-$Timestamp.md"
$ManifestPath = Join-Path $RunFolder "$fileBase-run-manifest-$Timestamp.json"

Write-DecomInfo "Exporting CSV..."
Export-DecomAssessmentCsv -Findings $Findings -Path $CsvPath
Write-DecomOk "CSV exported"

Write-DecomInfo "Exporting JSON..."
Export-DecomAssessmentJson -Findings $Findings -Path $JsonPath -Context $Context
Write-DecomOk "JSON exported"

Write-DecomInfo "Generating HTML report..."
$summaryHt = @{
    Critical      = $Summary.Critical
    High          = $Summary.High
    Medium        = $Summary.Medium
    Low           = $Summary.Low
    Informational = $Summary.Informational
    Total         = $Summary.Total
}
Export-DecomAssessmentHtml -Findings $Findings -Path $HtmlPath -Context $Context -Summary $summaryHt
Write-DecomOk "HTML report generated"

Write-DecomInfo "Generating remediation plan..."
Export-DecomRemediationPlan -Findings $Findings -Path $PlanPath -Context $Context
Write-DecomOk "Remediation plan generated"

Write-DecomInfo "Writing run manifest..."
$exportPaths = @{
    Csv             = $CsvPath
    Json            = $JsonPath
    Html            = $HtmlPath
    RemediationPlan = $PlanPath
    Manifest        = $ManifestPath
}
Write-DecomRunManifest -Path $ManifestPath -Context $Context -Summary $summaryHt -ExportPaths $exportPaths
Write-DecomOk "Run manifest written"

# Baseline comparison exports
if ($BaselineComparison) {
    Write-DecomInfo "Exporting baseline comparison..."
    $baselineJsonPath = Join-Path $RunFolder "$fileBase-baseline-comparison-$Timestamp.json"
    $baselineCsvPath  = Join-Path $RunFolder "$fileBase-baseline-comparison-$Timestamp.csv"
    Export-DecomBaselineComparisonJson -ComparisonResults $BaselineComparison -Context $Context -BaselineResult $BaselineResult -Path $baselineJsonPath
    Export-DecomBaselineComparisonCsv  -ComparisonResults $BaselineComparison -Path $baselineCsvPath
    Write-DecomOk "Baseline comparison JSON: $baselineJsonPath"
    Write-DecomOk "Baseline comparison CSV: $baselineCsvPath"
    $exportPaths.BaselineComparisonJson = $baselineJsonPath
    $exportPaths.BaselineComparisonCsv  = $baselineCsvPath
    Write-DecomRunManifest -Path $ManifestPath -Context $Context -Summary $summaryHt -ExportPaths $exportPaths
    Write-DecomOk "Run manifest updated with baseline comparison paths"
}

# Executive pack generation if -GenerateExecutivePack specified
if ($GenerateExecutivePack) {
    Write-DecomInfo "Generating executive evidence pack..."

    # Prepare executive pack context
    $execContext = [pscustomobject]@{
        SchemaVersion = '3.6'
        ToolVersion   = $Context.ToolVersion
        ClientName    = $Context.ClientName
        EngagementId  = $Context.EngagementId
        Assessor      = $Context.Assessor
        TenantId      = $Context.TenantId
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Coverage      = $Context.Coverage
        Findings      = $Findings
        Summary       = $Summary
        BaselineComparison = $BaselineComparison
        BaselineSummary    = $BaselineSummary
        RiskMovement       = $RiskMovement
        ExportPaths        = @{
            Csv                   = $CsvPath
            Json                  = $JsonPath
            Html                  = $HtmlPath
            RemediationPlan       = $PlanPath
            Manifest              = $ManifestPath
            BaselineComparisonJson = $baselineJsonPath
            BaselineComparisonCsv  = $baselineCsvPath
        }
    }

    # Generate executive summary model
    $execModel = New-DecomExecutiveSummaryModel -Context $execContext

    # Generate exports
    $execTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $baseName      = "entra-decommissioning-control-plane"

    # Executive summary markdown
    $execMdPath = Join-Path $RunFolder "$baseName-executive-summary-$execTimestamp.md"
    Export-DecomExecutiveSummaryMarkdown -Model $execModel -Path $execMdPath
    Write-DecomOk "Executive summary markdown: $execMdPath"

    # Executive summary HTML
    $execHtmlPath = Join-Path $RunFolder "$baseName-executive-summary-$execTimestamp.html"
    Export-DecomExecutiveSummaryHtml -Model $execModel -Path $execHtmlPath
    Write-DecomOk "Executive summary HTML: $execHtmlPath"

    # Governance KPI dashboard
    $kpiDashboardPath = Join-Path $RunFolder "$baseName-governance-kpi-dashboard-$execTimestamp.html"
    Export-DecomGovernanceKpiDashboardHtml -Model $execModel -Path $kpiDashboardPath
    Write-DecomOk "Governance KPI dashboard: $kpiDashboardPath"

    # Consultant evidence appendix
    $appendixPath = Join-Path $RunFolder "$baseName-consultant-evidence-appendix-$execTimestamp.md"
    Export-DecomConsultantEvidenceAppendixMarkdown -Model $execModel -Path $appendixPath
    Write-DecomOk "Consultant evidence appendix: $appendixPath"

    # Client readout pack manifest
    $clientReadoutPath = Join-Path $RunFolder "$baseName-client-readout-pack-manifest-$execTimestamp.json"
    Write-DecomClientReadoutPackManifest -Model $execModel -Path $clientReadoutPath
    Write-DecomOk "Client readout pack manifest: $clientReadoutPath"

    # Optional: Residual risk register
    try {
        $riskRegisterPath = Join-Path $RunFolder "$baseName-residual-risk-register-$execTimestamp.csv"
        Export-DecomResidualRiskRegisterCsv -Findings $Findings -Path $riskRegisterPath
        Write-DecomOk "Residual risk register: $riskRegisterPath"
    } catch {
        Write-DecomWarn "Residual risk register skipped: $_"
    }

    # Add executive pack exports to final export paths for manifest update
    $exportPaths.ExecutiveSummaryMarkdown = $execMdPath
    $exportPaths.ExecutiveSummaryHtml     = $execHtmlPath
    $exportPaths.GovernanceDashboardHtml  = $kpiDashboardPath
    $exportPaths.ConsultantEvidenceAppendix = $appendixPath
    $exportPaths.ClientReadoutPackManifest  = $clientReadoutPath
    if (Test-Path $riskRegisterPath) {
        $exportPaths.ResidualRiskRegister = $riskRegisterPath
    }

    # Update run manifest with new export paths
    Write-DecomRunManifest -Path $ManifestPath -Context $Context -Summary $summaryHt -ExportPaths $exportPaths
    Write-DecomOk "Run manifest updated with executive pack exports"
}

# Handle GenerateApprovalTemplate flag for WhatIfRemediation mode
if ($Mode -eq 'WhatIfRemediation' -and $GenerateApprovalTemplate) {
    Write-DecomInfo "Generating WhatIf action plan for client approval..."

    $runManifestContent = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    $actionPlanPath = New-DecomWhatIfActionPlan `
        -Findings $Findings `
        -EngagementId $EngagementId `
        -ClientName $ClientName `
        -Assessor $Assessor `
        -WhatIfRunId $runManifestContent.RunId `
        -OutputPath $RunFolder

    Write-DecomOk "WhatIf action plan: $actionPlanPath"
    Write-DecomInfo "Next: review with client, sign, then run Update-DecomApprovalManifestHash."
}

# In DemoMode, auto-enable all Rev3.4 hardening sample outputs
if ($DemoMode) {
    $GenerateRev35Readiness     = $true
    $GenerateClientHandoff      = $true
    $GenerateTraceabilityReport = $true
    $GenerateReplayValidation   = $true
    $GenerateApprovalDiff       = $true
    $GenerateRedactedPackage    = $true
    $GenerateEvidenceBundle     = $true
    $GenerateNhiGovernancePack  = $true
}

# ── Rev3.4 Hardening Outputs ──────────────────────────────────────────────────

$hardeningTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runManifestForHardening = if (Test-Path $ManifestPath) { Get-Content $ManifestPath -Raw | ConvertFrom-Json } else { $null }
$hardeningRunId = if ($runManifestForHardening -and $runManifestForHardening.RunId) { $runManifestForHardening.RunId } else { [guid]::NewGuid().ToString() }

if ($GenerateRev35Readiness) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Rev35Readiness.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $rr = New-DecomRev35ReadinessReport
        $rrPath = Join-Path $RunFolder "rev35-readiness-report-$hardeningTimestamp.json"
        Export-DecomRev35ReadinessJson -Report $rr -Path $rrPath
        Write-DecomOk "Rev3.5 readiness report: $rrPath"
    } catch { Write-DecomWarn "Rev3.5 readiness report skipped: $_" }
}

if ($GenerateClientHandoff) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ClientHandoff.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $chPkg = New-DecomClientHandoffPackage -Context $Context -RunId $hardeningRunId -PackagePath $RunFolder
        $chManifestPath = Join-Path $RunFolder "client-handoff-manifest-$hardeningTimestamp.json"
        Export-DecomClientHandoffManifestJson -Package $chPkg -Path $chManifestPath
        $chIndexPath = Join-Path $RunFolder "client-handoff-index-$hardeningTimestamp.md"
        Export-DecomClientHandoffIndexMarkdown -Package $chPkg -Path $chIndexPath
        Write-DecomOk "Client handoff manifest: $chManifestPath"
        Write-DecomOk "Client handoff index: $chIndexPath"
    } catch { Write-DecomWarn "Client handoff skipped: $_" }
}

if ($GenerateTraceabilityReport) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Traceability.psm1') -Force -DisableNameChecking -ErrorAction Stop
        # Initialize variables for traceability inputs
        $traceWhatIf = @()
        $traceApproval = @()
        $traceExecution = @()

        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $wf = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
            if ($wf.ApprovedActions) {
                $traceWhatIf = @($wf.ApprovedActions)
            }
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $ap = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
            if ($ap.ApprovedActions) {
                $traceApproval = @($ap.ApprovedActions)
            }
        }
        if ($execEvidencePath) {
            $ev = Get-Content $execEvidencePath -Raw | ConvertFrom-Json
            if ($ev.Actions) {
                $traceExecution = @($ev.Actions)
            }
        }

        $trModel = New-DecomTraceabilityModel `
            -Findings $Findings `
            -WhatIfActions $traceWhatIf `
            -ApprovalActions $traceApproval `
            -ExecutionResults $traceExecution `
            -RunId $hardeningRunId
        $trJsonPath = Join-Path $RunFolder "traceability-report-$hardeningTimestamp.json"
        $trCsvPath  = Join-Path $RunFolder "traceability-report-$hardeningTimestamp.csv"
        Export-DecomTraceabilityReportJson     -Model $trModel -Path $trJsonPath
        Export-DecomTraceabilityReportCsv      -Model $trModel -Path $trCsvPath
        Write-DecomOk "Traceability report: $trJsonPath"
    } catch { Write-DecomWarn "Traceability report skipped: $_" }
}

if ($GenerateReplayValidation -and $runManifestForHardening) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ReplayValidation.psm1') -Force -DisableNameChecking -ErrorAction Stop

        # Load actual artifacts before calling Invoke-DecomReplayValidation
        $rvWhatIf = $null
        $rvApproval = $null
        $rvExecution = $null

        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $rvWhatIf = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $rvApproval = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
        }
        $execEvidencePath = Get-ChildItem -Path $RunFolder -Filter 'execution-evidence-*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
        if ($execEvidencePath) {
            $rvExecution = Get-Content $execEvidencePath -Raw | ConvertFrom-Json
        }

        $rvResult = Invoke-DecomReplayValidation `
            -RunId $hardeningRunId `
            -WhatIfReport $rvWhatIf `
            -ApprovalManifest $rvApproval `
            -ExecutionEvidence $rvExecution
        $rvPath = Export-DecomReplayValidationReportJson -ValidationResult $rvResult -OutputPath $RunFolder
        Write-DecomOk "Replay validation report: $rvPath"
    } catch { Write-DecomWarn "Replay validation skipped: $_" }
}

if ($GenerateApprovalDiff -and $runManifestForHardening) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ApprovalDiff.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $adWhatIf   = @()
        $adApproval = @()
        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $wfDoc = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
            if ($wfDoc.ApprovedActions) { $adWhatIf = @($wfDoc.ApprovedActions) }
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $apDoc = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
            if ($apDoc.ApprovedActions) { $adApproval = @($apDoc.ApprovedActions) }
        }
        $adDiff = Compare-DecomWhatIfToApproval -WhatIfActions $adWhatIf -ApprovalActions $adApproval -RunId $hardeningRunId
        $adPath = Join-Path $RunFolder "approval-diff-report-$hardeningTimestamp.json"
        Export-DecomApprovalDiffJson -Diff $adDiff -Path $adPath
        Write-DecomOk "Approval diff: $adPath"
    } catch { Write-DecomWarn "Approval diff skipped: $_" }
}

if ($GenerateRedactedPackage) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Redaction.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $redactionProfileObj = New-DecomRedactionProfile -ProfileName $RedactionProfile

        # Create redacted subdirectory and apply redaction to output files
        $redactedDir = Join-Path $RunFolder 'redacted'
        New-Item -ItemType Directory -Path $redactedDir -Force | Out-Null
        $redactedCount = 0
        $redactionErrors = @()

        Get-ChildItem -Path $RunFolder -File | Where-Object {
            $_.Extension -in @('.json','.csv','.md','.html') -and
            $_.FullName -notmatch '\\redacted\\'
        } |
            ForEach-Object {
                try {
                    $raw = Get-Content $_.FullName -Raw -ErrorAction Stop
                    $redacted = Invoke-DecomRedaction -InputString $raw -Profile $redactionProfileObj
                    $target = Join-Path $redactedDir $_.Name
                    Set-Content -Path $target -Value $redacted -Encoding UTF8
                    $redactedCount++
                } catch {
                    Write-DecomWarn "Redaction failed for $($_.FullName): $($_.Exception.Message)"
                    $redactionErrors += @{ File = $_.FullName; Error = $_.Exception.Message }
                }
            }

        $rdPath = Join-Path $RunFolder "redaction-report-$hardeningTimestamp.json"
        Export-DecomRedactionReportJson -Profile $redactionProfileObj -Path $rdPath -RunId $hardeningRunId -ToolVersion $script:ToolVersion -RedactedFileCount $redactedCount
        Write-DecomOk "Redaction report: $rdPath"
        Write-DecomOk "$redactedCount file(s) redacted to $redactedDir"
    } catch { Write-DecomWarn "Redaction report skipped: $_" }
}

if ($GenerateEvidenceBundle) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'EvidenceBundle.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $eb = New-DecomEvidenceBundle -Context $Context -RunId $hardeningRunId -BundleId ([guid]::NewGuid().ToString()) -SourceOutputPath $RunFolder -BundleOutputPath (Join-Path $RunFolder 'evidence-bundle')
        New-Item -ItemType Directory -Path $eb.BundleOutputPath -Force | Out-Null
        Get-ChildItem -Path $RunFolder -File -Recurse | Where-Object { $_.FullName -notmatch '\\temp\\' } | ForEach-Object {
            $eb = Add-DecomEvidenceBundleFile -Bundle $eb -FilePath $_.FullName -Category 'Assessment'
        }
        $ebManifestPath = Join-Path $eb.BundleOutputPath "evidence-bundle-manifest-$hardeningTimestamp.json"
        Export-DecomEvidenceBundleManifestJson -Bundle $eb -Path $ebManifestPath
        $hashJsonPath = Join-Path $eb.BundleOutputPath "evidence-hashes-$hardeningTimestamp.json"
        $hashCsvPath  = Join-Path $eb.BundleOutputPath "evidence-hashes-$hardeningTimestamp.csv"
        Export-DecomEvidenceHashManifest -Bundle $eb -JsonPath $hashJsonPath -CsvPath $hashCsvPath
        Write-DecomOk "Evidence bundle: $ebManifestPath"
    } catch { Write-DecomWarn "Evidence bundle skipped: $_" }
}

if ($GenerateEvidenceBundle -or $GenerateRedactedPackage -or $GenerateTraceabilityReport -or $GenerateClientHandoff -or $GenerateRev35Readiness) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'OutputManifest.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $om = New-DecomOutputManifest -Context $Context -RunId $hardeningRunId -OutputRoot $RunFolder
        Get-ChildItem -Path $RunFolder -File -Recurse | Where-Object { $_.FullName -notmatch '\\temp\\' -and $_.Extension -in @('.json','.csv','.html','.md') } | ForEach-Object {
            $sensitivity = if ($_.Name -match 'redact') { 'ClientSafe' } else { 'Confidential' }
            $category = switch -Regex ($_.Name) {
                'readiness'    { 'Rev35Readiness';    break }
                'handoff'      { 'ClientHandoff';     break }
                'traceability' { 'Report';            break }
                'evidence'     { 'ExecutionEvidence'; break }
                'manifest'     { 'Report';            break }
                default        { 'Assessment' }
            }
            $om = Add-DecomOutputManifestItem -Manifest $om -FilePath $_.FullName -Category $category -Sensitivity $sensitivity
        }
        $omPath = Join-Path $RunFolder "output-manifest-$hardeningTimestamp.json"
        Export-DecomOutputManifestJson -Manifest $om -Path $omPath
        Write-DecomOk "Output manifest: $omPath"
    } catch { Write-DecomWarn "Output manifest skipped: $_" }
}

# ── Rev3.5 NHI Governance Pack ────────────────────────────────────────────────

if ($GenerateNhiGovernancePack) {
    try {
        Write-DecomInfo "Generating NHI governance pack..."

        # Use cached NHI pipeline state if already ran, otherwise generate warning
        if (-not $NhiPipelineRan) {
            Write-DecomWarn "NHI reporting requested but NHI pipeline did not run; generating empty NHI pack with coverage warning."
            # Do not re-run discovery/analysis/governance; just exit
        } else {
            # Generate NHI reporting outputs using cached state (writes nhi-* files to $Context.OutputPath = $RunFolder)
            Invoke-DecomNhiReporting -NhiInventory $NhiAnalyzed -NhiGovernanceFindings $NhiGovernanceFindings -Context $Context
            Write-DecomOk "NHI governance pack generation complete"
        }

        if ($NhiPipelineRan) {

        # Register NHI outputs in OutputManifest and EvidenceBundle
        $nhiOutputFiles = Get-ChildItem -Path $RunFolder -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'nhi-*' -or $_.Name -like '*-nhi-*' }

        if ($nhiOutputFiles.Count -gt 0) {
            try {
                Import-Module (Join-Path $script:ModulesPath 'OutputManifest.psm1') -Force -DisableNameChecking -ErrorAction Stop
                $nhiOm = New-DecomOutputManifest -Context $Context -RunId $hardeningRunId -OutputRoot $RunFolder
                foreach ($f in $nhiOutputFiles) {
                    $nhiOm = Add-DecomOutputManifestItem -Manifest $nhiOm `
                        -FilePath $f.FullName -Category 'Assessment' -Sensitivity 'Confidential'
                }
                $nhiOmPath = Join-Path $RunFolder "nhi-output-manifest-$hardeningTimestamp.json"
                Export-DecomOutputManifestJson -Manifest $nhiOm -Path $nhiOmPath
                Write-DecomOk "NHI output manifest: $nhiOmPath"
            } catch { Write-DecomWarn "NHI output manifest skipped: $_" }

            try {
                Import-Module (Join-Path $script:ModulesPath 'EvidenceBundle.psm1') -Force -DisableNameChecking -ErrorAction Stop
                $nhiEb = New-DecomEvidenceBundle -Context $Context -RunId $hardeningRunId `
                    -BundleId ([guid]::NewGuid().ToString()) `
                    -SourceOutputPath $RunFolder `
                    -BundleOutputPath (Join-Path $RunFolder 'nhi-evidence-bundle')
                New-Item -ItemType Directory -Path $nhiEb.BundleOutputPath -Force | Out-Null
                foreach ($f in $nhiOutputFiles) {
                    $nhiEb = Add-DecomEvidenceBundleFile -Bundle $nhiEb `
                        -FilePath $f.FullName -Category 'NHI'
                }
                $nhiEbManifestPath = Join-Path $nhiEb.BundleOutputPath "nhi-evidence-bundle-manifest-$hardeningTimestamp.json"
                Export-DecomEvidenceBundleManifestJson -Bundle $nhiEb -Path $nhiEbManifestPath
                Write-DecomOk "NHI evidence bundle: $nhiEbManifestPath"
            } catch { Write-DecomWarn "NHI evidence bundle skipped: $_" }
        }
        }
    } catch { Write-DecomWarn "NHI governance pack skipped: $_" }
}

Write-Host ''
Write-Host ('=' * 64) -ForegroundColor DarkCyan
Write-Host '  Assessment complete.' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Findings:' -ForegroundColor DarkCyan
Write-Host "    CRITICAL : $($Summary.Critical)" -ForegroundColor Red
Write-Host "    HIGH     : $($Summary.High)"     -ForegroundColor DarkYellow
Write-Host "    MEDIUM   : $($Summary.Medium)"   -ForegroundColor Cyan
Write-Host "    LOW      : $($Summary.Low)"      -ForegroundColor Green
Write-Host "    INFO     : $($Summary.Informational)" -ForegroundColor Gray
Write-Host ''
Write-Host '  Exports:' -ForegroundColor DarkCyan
Write-Host "    [OK]  CSV              : $CsvPath" -ForegroundColor Green
Write-Host "    [OK]  JSON             : $JsonPath" -ForegroundColor Green
Write-Host "    [OK]  HTML Report      : $HtmlPath" -ForegroundColor Green
Write-Host "    [OK]  Remediation Plan : $PlanPath" -ForegroundColor Green
Write-Host "    [OK]  Run Manifest     : $ManifestPath" -ForegroundColor Green
Write-Host ''
Write-Host "  Output folder : $RunFolder" -ForegroundColor Gray
Write-Host ('=' * 64) -ForegroundColor DarkCyan

exit 0
