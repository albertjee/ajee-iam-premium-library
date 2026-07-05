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
    [string]$ExecutionStage = 'ValidateOnly',
    [string]$DecommissionPlanPath,
    [ValidateRange(1,8760)][int]$ScreamTestWindowHours = 24,
    [switch]$RequireSecondConfirmation,
    [switch]$AllowFinalDelete,
    [switch]$WhatIfExecution
)

# Tool version - update this single constant each release
$script:ToolVersion = 'Rev4.10'

if ($Mode -eq 'ExecuteRemediation' -and $DemoMode) {
    Write-Host "[ERROR] ExecuteRemediation cannot run in DemoMode." -ForegroundColor Red
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ControlledExecutionStages = @(
    'ValidateOnly'
    'SnapshotOnly'
    'TagOnly'
    'DisableOnly'
    'ScreamTestOnly'
    'DeleteReadinessOnly'
    'MetadataCleanupReadiness'
    'GrantCleanupReadiness'
    'ManagedIdentityReadiness'
    'E2EEvidencePack'
    'ProductionReadiness'
    'FinalDelete'
)

if ($ExecutionStage -notin $script:ControlledExecutionStages) {
    Write-Host "[ERROR] Unsupported -ExecutionStage '$ExecutionStage'." -ForegroundColor Red
    exit 1
}

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

. "$PSScriptRoot\src\EntryPoint\ControlledNhiDecommission.ps1" -ErrorAction Stop
. "$PSScriptRoot\src\EntryPoint\NhiExecutionFlow.ps1" -ErrorAction Stop

. "$PSScriptRoot\src\EntryPoint\AssessmentFlow.ps1" -ErrorAction Stop

. "$PSScriptRoot\src\EntryPoint\NhiGovernancePack.ps1" -ErrorAction Stop

# ── Rev3.4 Hardening Outputs ──────────────────────────────────────────────────

. "$PSScriptRoot\src\EntryPoint\HardeningOutputs.ps1" -ErrorAction Stop

# ── Rev3.5 NHI Governance Pack ────────────────────────────────────────────────

. "$PSScriptRoot\src\EntryPoint\Rev35GovernancePack.ps1" -ErrorAction Stop
