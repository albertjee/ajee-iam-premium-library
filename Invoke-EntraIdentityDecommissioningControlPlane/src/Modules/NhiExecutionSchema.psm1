#Requires -Version 5.1
<#
.SYNOPSIS
    NHI execution schema: action model and approval manifest validation.

.DESCRIPTION
    Rev4.0 NHI execution action model. Defines all allowed, blocked, and deferred
    execution actions. Provides manifest validation for execution gating.

    12 total actions:
      Allowed in Rev4.0 (reversible): Snapshot, Tag, Disable, Monitor,
        RollbackTag, RollbackDisable
      Blocked in Rev4.0: HardDeleteServicePrincipal, RemoveCredential,
        RemoveAppRoleAssignment, RemoveOAuthGrant, RemoveOwner, DeleteApplication

    Approval manifest validation covers 7 checks before any execution proceeds.
#>

# ── FUNCTIONS ─────────────────────────────────────────────────────────────────

function Get-NhiExecutionSchema {
    <#
    .SYNOPSIS
        Returns the full NHI execution action model.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    # Return a deep copy so callers cannot mutate module-level state.
    $actions = @{}
    foreach ($key in $_NhiActionRegistry.Keys) {
        $actions[$key] = [hashtable]::new($_NhiActionRegistry[$key])
    }
    return $actions
}

function Test-NhiExecutionActionAllowed {
    <#
    .SYNOPSIS
        Tests whether an execution action is allowed given the PhaseLimit.

    .PARAMETER ActionName
        The action name (e.g. 'Snapshot', 'HardDeleteServicePrincipal').

    .PARAMETER PhaseLimit
        The approved execution phase (1, 2, or 3). Actions in phases above this
        limit return $false even if not individually blocked.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ActionName,

        [Parameter(Mandatory)]
        [ValidateRange(1, 3)]
        [int]$PhaseLimit
    )

    $action = $_NhiActionRegistry[$ActionName]
    if (-not $action) {
        return $false
    }

    if ($action.BlockedInRev40) {
        return $false
    }

    if ($action.Phase -gt $PhaseLimit) {
        return $false
    }

    return $true
}

function Confirm-NhiApprovedManifest {
    <#
    .SYNOPSIS
        Validates an approval manifest before Rev4.0 execution proceeds.

    .PARAMETER ManifestPath
        Full path to the approval manifest JSON file.

    .PARAMETER EngagementId
        The current engagement identifier to match against the manifest.

    .PARAMETER TargetObjectIds
        Array of target ObjectIds used to recompute the SHA256 integrity hash.

    .PARAMETER PhaseLimit
        The requested execution phase limit (1, 2, or 3). Manifest must have
        ExecutionPhaseApproved >= PhaseLimit for validation to pass.

    .DESCRIPTION
        Validates ALL of the following conditions. Failure of any single check
        is a hard throw — no execution proceeds.

        1. File exists and is valid parseable JSON.
        2. EngagementId matches the current run's EngagementId.
        3. SHA256 hash of TargetObjectIds array matches the manifest's SHA256 field.
        4. ExecutionPhaseApproved (int 1-3) is >= the requested PhaseLimit.
        5. ApprovedBy field is present and non-empty.
        6. ApprovedAt field is present and non-empty.
        7. SchemaVersion field is present (any non-empty value).
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$EngagementId,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [object[]]$TargetObjectIds,

        [Parameter(Mandatory)]
        [ValidateRange(1, 3)]
        [int]$PhaseLimit
    )

    # ── Check 1: File exists and is parseable JSON ────────────────────────────
    if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) {
        throw "Confirm-NhiApprovedManifest: Manifest file not found at '$ManifestPath'."
    }

    [object]$manifest = $null
    try {
        $jsonContent = Get-Content -Path $ManifestPath -Raw -Encoding UTF8
        $manifest = $jsonContent | ConvertFrom-Json
    } catch {
        throw "Confirm-NhiApprovedManifest: Manifest file is not valid JSON. Path: '$ManifestPath'. Error: $($_.Exception.Message)"
    }

    # ── Check 2: EngagementId match ───────────────────────────────────────────
    $manifestEngagementId = $manifest.EngagementId
    if ([string]::IsNullOrEmpty($manifestEngagementId)) {
        throw "Confirm-NhiApprovedManifest: Manifest is missing or has empty EngagementId field."
    }
    if ($manifestEngagementId -ne $EngagementId) {
        throw "Confirm-NhiApprovedManifest: EngagementId mismatch. Manifest has '$manifestEngagementId', expected '$EngagementId'."
    }

    # ── Check 3: SHA256 integrity hash of TargetObjectIds ─────────────────────
    $manifestHash = $manifest.SHA256
    if ([string]::IsNullOrEmpty($manifestHash)) {
        throw "Confirm-NhiApprovedManifest: Manifest is missing or has empty SHA256 field."
    }

    $idsJson = ConvertTo-Json -InputObject $TargetObjectIds -Compress -Depth 10
    $idsBytes = [System.Text.Encoding]::UTF8.GetBytes($idsJson)
    $sha256Bytes = [System.Security.Cryptography.SHA256]::HashData($idsBytes)
    $computedHash = ''
    foreach ($b in $sha256Bytes) { $computedHash += $b.ToString('x2') }''

    if ($computedHash -ne $manifestHash) {
        throw "Confirm-NhiApprovedManifest: SHA256 hash mismatch. Computed '$computedHash', manifest has '$manifestHash'."
    }

    # ── Check 4: ExecutionPhaseApproved >= PhaseLimit ──────────────────────────
    if (-not ($manifest.PSObject.Properties.Name -contains 'ExecutionPhaseApproved')) {
        throw "Confirm-NhiApprovedManifest: Manifest is missing ExecutionPhaseApproved field."
    }
    $approvedPhase = $manifest.ExecutionPhaseApproved
    if ($null -eq $approvedPhase) {
        throw "Confirm-NhiApprovedManifest: ExecutionPhaseApproved field is null."
    }
    if (-not ($approvedPhase -is [int] -or $approvedPhase -is [long])) {
        throw "Confirm-NhiApprovedManifest: ExecutionPhaseApproved must be an integer, got '$($approvedPhase.GetType().Name)'."
    }
    if ($approvedPhase -lt $PhaseLimit) {
        throw "Confirm-NhiApprovedManifest: ExecutionPhaseApproved ($approvedPhase) is less than requested PhaseLimit ($PhaseLimit). Execution halted."
    }

    # ── Check 5: ApprovedBy is present and non-empty ──────────────────────────
    if (-not ($manifest.PSObject.Properties.Name -contains 'ApprovedBy')) {
        throw "Confirm-NhiApprovedManifest: Manifest is missing ApprovedBy field."
    }
    if ([string]::IsNullOrWhiteSpace($manifest.ApprovedBy)) {
        throw "Confirm-NhiApprovedManifest: ApprovedBy field is empty or whitespace."
    }

    # ── Check 6: ApprovedAt is present and non-empty ──────────────────────────
    if (-not ($manifest.PSObject.Properties.Name -contains 'ApprovedAt')) {
        throw "Confirm-NhiApprovedManifest: Manifest is missing ApprovedAt field."
    }
    if ([string]::IsNullOrWhiteSpace($manifest.ApprovedAt)) {
        throw "Confirm-NhiApprovedManifest: ApprovedAt field is empty or whitespace."
    }

    # ── Check 7: SchemaVersion is present (any non-empty value) ───────────────
    if (-not ($manifest.PSObject.Properties.Name -contains 'SchemaVersion')) {
        throw "Confirm-NhiApprovedManifest: Manifest is missing SchemaVersion field."
    }
    if ([string]::IsNullOrWhiteSpace($manifest.SchemaVersion)) {
        throw "Confirm-NhiApprovedManifest: SchemaVersion field is empty or whitespace."
    }
}

# ── MODULE-LEVEL STATE ────────────────────────────────────────────────────────

$_NhiActionRegistry = @{
    # ── Allowed in Rev4.0 (reversible) ───────────────────────────────────────

    'Snapshot'             = @{
        Name                     = 'Snapshot'
        IsReversible             = $true
        Phase                    = 1
        ApplicableObjectTypes    = @('ServicePrincipal', 'ManagedIdentity', 'User')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $false
    }

    'Tag'                  = @{
        Name                     = 'Tag'
        IsReversible             = $true
        Phase                    = 1
        ApplicableObjectTypes    = @('ServicePrincipal', 'ManagedIdentity', 'User')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $false
    }

    'Disable'              = @{
        Name                     = 'Disable'
        IsReversible             = $true
        Phase                    = 2
        ApplicableObjectTypes    = @('ServicePrincipal', 'ManagedIdentity', 'User')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $false
    }

    'Monitor'              = @{
        Name                     = 'Monitor'
        IsReversible             = $true
        Phase                    = 3
        ApplicableObjectTypes    = @('ServicePrincipal', 'ManagedIdentity', 'User')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $false
    }

    'RollbackTag'          = @{
        Name                     = 'RollbackTag'
        IsReversible             = $true
        Phase                    = 3
        ApplicableObjectTypes    = @('ServicePrincipal', 'ManagedIdentity', 'User')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $false
    }

    'RollbackDisable'      = @{
        Name                     = 'RollbackDisable'
        IsReversible             = $true
        Phase                    = 3
        ApplicableObjectTypes    = @('ServicePrincipal', 'ManagedIdentity', 'User')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $false
    }

    # ── Blocked in Rev4.0 ─────────────────────────────────────────────────────

    'HardDeleteSvcPrincipalBlocklist' = @{
        Name                     = 'HardDeleteSvcPrincipalBlocklist'
        IsReversible             = $false
        Phase                    = 3
        ApplicableObjectTypes    = @('ServicePrincipal')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $true
    }

    'RemoveCredential'     = @{
        Name                     = 'RemoveCredential'
        IsReversible             = $false
        Phase                    = 2
        ApplicableObjectTypes    = @('ServicePrincipal')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $true
    }

    'RemoveAppRoleAssignment' = @{
        Name                     = 'RemoveAppRoleAssignment'
        IsReversible             = $false
        Phase                    = 2
        ApplicableObjectTypes    = @('ServicePrincipal', 'User')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $true
    }

    'RemoveOAuthGrant'      = @{
        Name                     = 'RemoveOAuthGrant'
        IsReversible             = $false
        Phase                    = 2
        ApplicableObjectTypes    = @('ServicePrincipal')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $true
    }

    'RemoveOwner'           = @{
        Name                     = 'RemoveOwner'
        IsReversible             = $false
        Phase                    = 1
        ApplicableObjectTypes    = @('ServicePrincipal')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $true
    }

    'DeleteApplication'     = @{
        Name                     = 'DeleteApplication'
        IsReversible             = $false
        Phase                    = 3
        ApplicableObjectTypes    = @('ServicePrincipal')
        RequiresApprovedManifest = $true
        BlockedInRev40           = $true
    }
}

# ── EXPORTS ───────────────────────────────────────────────────────────────────

Export-ModuleMember -Function @(
    'Get-NhiExecutionSchema'
    'Test-NhiExecutionActionAllowed'
    'Confirm-NhiApprovedManifest'
)