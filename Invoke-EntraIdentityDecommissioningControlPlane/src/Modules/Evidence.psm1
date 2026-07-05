# Evidence.psm1 — Evidence emission consolidation and thread-safe NDJSON write
# Phase 4 refactoring target: DRY evidence emission + file locking
#
# This module shadows LiteModules/Evidence.psm1 and LiteModules/Models.psm1
# for the src/Modules/ layer only, adding:
#   - New-DecomActionResultWithEvidence: wrapped New-DecomActionResult + evidence emission
#   - File locking on the NDJSON write path in Add-DecomEvidenceEvent
#
# Frozen LiteModules callers (AccessRemoval, AzureRBAC, etc.) are unaffected —
# they import LiteModules/* directly and get the non-locked path.
# Only src/Modules/ callers that import this module get the locked path.

# ── Shadow LiteModules imports (only affects this module's scope) ────────────────
Import-Module (Join-Path $PSScriptRoot '../LiteModules/Models.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot '../LiteModules/Evidence.psm1') -Force -DisableNameChecking

# ── Script-scoped state ─────────────────────────────────────────────────────────

$script:DecomEvidenceNdjsonPath = $null

# ── Internal: thread-safe NDJSON write with OS-level file lock ──────────────────

function _Write-DecomEvidenceNdjson {
    <#
    .SYNOPSIS
    Appends a JSON line to the NDJSON evidence log with exclusive file locking.
    .DESCRIPTION
    Acquires an exclusive OS-level lock on the NDJSON file before writing.
    This prevents corruption from concurrent Add-Content calls in pipelines
    or background runspace scenarios (Rev4 refactoring item H).
    .PARAMETER Path
    The NDJSON file path.
    .PARAMETER Entry
    The JSON string to append (already serialized).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Entry
    )

    if (-not $Path) { return }

    # FileShare.None on the open IS the exclusive lock; write through the same
    # handle. A second handle (e.g. Add-Content) would be rejected by the share
    # mode, so the write must not go through a separate open.
    $attempts = 3
    for ($i = 1; $i -le $attempts; $i++) {
        $fs = $null
        try {
            $fs = [System.IO.File]::Open($Path, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $writer = [System.IO.StreamWriter]::new($fs, [System.Text.UTF8Encoding]::new($false))
            $writer.WriteLine($Entry)
            $writer.Dispose()
            $fs = $null
            return
        } catch [System.IO.IOException] {
            # File held by a concurrent writer or external process (AV scanner).
            # Retry briefly, then fall through non-fatally - do not abort the
            # action result for an NDJSON write failure.
            if ($i -lt $attempts) { Start-Sleep -Milliseconds (50 * $i) }
            else { Write-Verbose "NDJSON write failed after $attempts attempts (locked or unavailable, non-fatal): $_" }
        } catch {
            Write-Verbose "NDJSON write failed (non-fatal): $_"
            return
        } finally {
            if ($null -ne $fs) { $fs.Dispose() }
        }
    }
}

# ── Shadow: Add-DecomEvidenceEvent with file-locked NDJSON write ────────────────

function Add-DecomEvidenceEvent {
    <#
    .SYNOPSIS
    Emits an evidence event for the decommission run.
    .DESCRIPTION
    Shadow of LiteModules/Add-DecomEvidenceEvent that replaces the NDJSON
    Add-Content write with a file-locked exclusive-write path via
    _Write-DecomEvidenceNdjson. The in-memory list update is unchanged.
    .PARAMETER Context
    The run context object (must have RunId, CorrelationId, etc.).
    .PARAMETER Phase
    The decomposition phase (PhaseA/B/C, etc.).
    .PARAMETER ActionName
    Human-readable action label.
    .PARAMETER Status
    One of: Success, Warning, Skipped, Error.
    .PARAMETER IsCritical
    Whether this action is critical to the decommission objective.
    .PARAMETER Message
    Descriptive message for the event.
    .PARAMETER BeforeState
    Hashtable of pre-action state snapshot.
    .PARAMETER AfterState
    Hashtable of post-action state snapshot.
    .PARAMETER Evidence
    Arbitrary key/value evidence payload.
    .PARAMETER ControlObjective
    Regulatory or policy control this action maps to.
    .PARAMETER RiskMitigated
    Risk description this action mitigates.
    .RETURNS
    The evidence event as a PSCustomObject (also appended to $Context.Evidence).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][pscustomobject]$Context,
        [string]$Phase,
        [string]$ActionName,
        [string]$Status,
        [bool]$IsCritical,
        [string]$Message,
        [hashtable]$BeforeState,
        [hashtable]$AfterState,
        [hashtable]$Evidence,
        [string]$ControlObjective,
        [string]$RiskMitigated
    )

    $eventHt = [ordered]@{
        RunId            = $Context.RunId
        CorrelationId    = $Context.CorrelationId
        EvidenceLevel    = $Context.EvidenceLevel
        TargetUPN        = $Context.TargetUPN
        OperatorUPN      = if ($Context.OperatorUPN)      { $Context.OperatorUPN }      else { $null }
        OperatorObjectId = if ($Context.OperatorObjectId) { $Context.OperatorObjectId } else { $null }
        TicketId         = if ($Context.TicketId)         { $Context.TicketId }         else { $null }
        TimestampUtc     = (Get-Date).ToUniversalTime().ToString('o')
        ActionId         = [guid]::NewGuid().Guid
        Phase            = $Phase
        ActionName       = $ActionName
        Status           = $Status
        IsCritical       = $IsCritical
        Message          = $Message
        BeforeState      = if ($BeforeState) { $BeforeState } else { @{} }
        AfterState       = if ($AfterState)  { $AfterState }  else { @{} }
        Evidence         = if ($Evidence)    { $Evidence }    else { @{} }
        ControlObjective = $ControlObjective
        RiskMitigated    = $RiskMitigated
    }

    # Add to in-memory list (same as LiteModules original)
    $eventObj = [pscustomobject]$eventHt
    $Context.Evidence.Add($eventObj)

    # Write to NDJSON with thread-safe _Write-DecomEvidenceNdjson
    $ndjsonPath = $script:DecomEvidenceNdjsonPath
    if ($ndjsonPath) {
        if ($Context.SealEvidence -eq $true) {
            $sealed = Write-DecomEvidenceSeal -Event $eventHt -PrevHash $Context.EvidencePrevHash
            $Context.EvidencePrevHash = $sealed.NewPrevHash
            _Write-DecomEvidenceNdjson -Path $ndjsonPath -Entry ($sealed.Event | ConvertTo-Json -Depth 50 -Compress)
        } else {
            _Write-DecomEvidenceNdjson -Path $ndjsonPath -Entry ($eventHt | ConvertTo-Json -Depth 50 -Compress)
        }
    }

    return $eventObj
}

# ── New: New-DecomActionResultWithEvidence ────────────────────────────────────

function New-DecomActionResultWithEvidence {
    <#
    .SYNOPSIS
    Creates an action result object and optionally emits an evidence event.
    .DESCRIPTION
    This is the Phase 4 DRY consolidation of the two-step pattern:
        $result = New-DecomActionResult -ActionName ... -Phase ...
        Add-DecomEvidenceEvent -Context $Context ... # easily forgotten
        return $result

    New-DecomActionResultWithEvidence combines both into one call:
        return New-DecomActionResultWithEvidence -Context $Context `
            -ActionName ... -Phase ... -EmitEvidence

    Parameter set matches New-DecomActionResult exactly for backward
    compatibility. When -EmitEvidence is not set (default), this function
    behaves identically to New-DecomActionResult with no evidence side-effects.
    .PARAMETER Context
    The run context. Required when -EmitEvidence is used — carries RunId,
    CorrelationId, TargetUPN, EvidenceLevel for the evidence event.
    .PARAMETER EmitEvidence
    When specified, calls Add-DecomEvidenceEvent internally to record the
    action in the audit trail before returning. Defaults to $false so
    existing two-step call sites are not broken.
    #>
    [CmdletBinding()]
    param(
        # New-DecomActionResult parameters (verbatim)
        [Parameter(Mandatory)][string]$ActionName,
        [Parameter(Mandatory)][string]$Phase,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][bool]$IsCritical,
        [Parameter(Mandatory)][string]$TargetUPN,
        [Parameter(Mandatory)][string]$Message,
        [hashtable]$Evidence,
        [hashtable]$BeforeState,
        [hashtable]$AfterState,
        [string[]]$WarningMessages,
        [string[]]$BlockerMessages,
        [string[]]$ManualFollowUp,
        [string]$RecommendedNext,
        [string]$ControlObjective,
        [string]$RiskMitigated,
        [string]$FailureClass,
        [string]$StepId,

        # Phase 4 addition
        [Parameter(Mandatory)][pscustomobject]$Context,
        [switch]$EmitEvidence
    )

    # Forward to LiteModules/New-DecomActionResult for the PSCustomObject result
    $result = New-DecomActionResult -ActionName $ActionName `
        -Phase $Phase -Status $Status -IsCritical $IsCritical `
        -TargetUPN $TargetUPN -Message $Message `
        -Evidence $Evidence -BeforeState $BeforeState -AfterState $AfterState `
        -WarningMessages $WarningMessages -BlockerMessages $BlockerMessages `
        -ManualFollowUp $ManualFollowUp -RecommendedNext $RecommendedNext `
        -ControlObjective $ControlObjective -RiskMitigated $RiskMitigated `
        -FailureClass $FailureClass -StepId $StepId

    # Emit evidence event when requested (Phase 4 DRY consolidation)
    if ($EmitEvidence) {
        Add-DecomEvidenceEvent -Context $Context `
            -Phase $Phase -ActionName $ActionName -Status $Status `
            -IsCritical $IsCritical -Message $Message `
            -BeforeState $BeforeState -AfterState $AfterState `
            -Evidence $Evidence -ControlObjective $ControlObjective `
            -RiskMitigated $RiskMitigated
    }

    return $result
}