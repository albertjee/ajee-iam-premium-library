# Rev4.41 Batch NHI Lifecycle Planning

Rev4.41 adds a planning-only batch wrapper for multiple NHI service principal targets. It scales the Rev4.40 safety model across a list of objects without introducing any live batch mutation path.

## Why It Exists

- It removes the need to plan one NHI target at a time when the operator already knows the target set.
- It keeps the batch flow read-only.
- It records per-object validation, risk reasons, ownership status, activity status, and artifact locations.
- It plans cohort/wave grouping so operators can review the batch in smaller, bounded slices.

## What It Does

- Reads a set of service principal object IDs.
- Performs read-only Graph lookups for each target.
- Rejects Microsoft first-party and platform identities from mutation eligibility.
- Rejects unknown or high-risk targets from mutation eligibility.
- Records per-object artifact folders and local JSON summaries.
- Writes a batch manifest and a batch summary.

## Supported Modes

- `Readiness`: performs read-only eligibility checks, wave planning, and artifact generation for a proposed batch. This is the planning pass before any simulated execution.
- `WhatIf`: performs the same read-only planning work but marks the batch as a WhatIf rehearsal. It does not mutate tenant state.
- `Verify`: performs read-only Graph verification only. It checks that the targets can be observed and classified, but it does not create a live mutation path.
- `Closeout`: aggregates only pre-existing artifacts from a prior batch run root. It does not create new lifecycle directories.

## Batch Manifest Fields

The wrapper writes a batch manifest with these root fields:

- `BatchId`: string, generated as `REV441B-<32 hex chars>` unless supplied. Identifies the batch run.
- `TenantId`: string. The tenant being observed for read-only planning and verification.
- `ApprovedAction`: string, fixed to `ReversibleDisable`.
- `Mode`: string, one of `Readiness`, `WhatIf`, `Verify`, or `Closeout`.
- `MaxObjectsPerWave`: integer, 1-100. Controls the number of eligible targets grouped into each planned wave.
- `StopOnFirstFailure`: boolean, `true` or `false`.
- `FinalDeleteApproved`: boolean, always `false` in Rev4.41.
- `CleanupApproved`: boolean, always `false` in Rev4.41.
- `Targets[]`: array of target records, one per requested service principal object ID.

Each target record includes:

- `DisplayName`: string. Observed display name, or `null` on Graph read failure.
- `ObjectType`: string, fixed to `ServicePrincipal`.
- `ServicePrincipalObjectId`: string. The observed service principal object ID.
- `AppId`: string. The observed application ID, or `null` on Graph read failure.
- `RiskReason`: string. Short human-readable reason the target was blocked or planned.
- `OwnerStatus`: string, typically `NoOwners`, `SingleOwner`, `MultiOwner`, or `Unknown`.
- `LastObservedActivity`: string, typically `Recent`, `Stale`, `Inactive`, or `Unknown`.
- `ApprovedAction`: string, fixed to `ReversibleDisable` for batch planning.

## Output Layout

The wrapper writes a timestamped run root under `C:\temp\IAM` unless `-OutputRoot` is supplied.

The on-disk layout is:

```text
<RunRoot>/<Mode>/
  rev441-batch-manifest.json
  rev441-batch-summary.json
  targets/
    target-<index>-<shortId>/
      rev441-target-summary.json
  wave-<N>/
```

Targets are grouped into waves based on `MaxObjectsPerWave`. Eligible targets are assigned to `wave-01`, `wave-02`, and so on, while each requested object also gets its own per-object artifact folder under `targets/`.

## Operator Example

```powershell
.\tools\Start-NhiBatchLifecyclePlanning.ps1 `
  -TenantId "contoso-test" `
  -Mode WhatIf `
  -TargetObjectIds @(
    "sp-eligible-1",
    "sp-eligible-2",
    "sp-platform-1"
  ) `
  -MaxObjectsPerWave 2
```

## What It Does Not Do

This wrapper does not execute live tenant mutation.

- No live disable execution.
- No rollback execution.
- No cleanup.
- No delete.
- No final delete.
- No `Remove-Mg*`.
- No direct `Update-MgServicePrincipal`.

## Relationship To Rev4.40

- Rev4.40 is the single-object lifecycle wrapper.
- Rev4.41 is the batch planning wrapper.
- Rev4.41 keeps the same fail-closed posture but applies it to multiple targets and wave planning.
