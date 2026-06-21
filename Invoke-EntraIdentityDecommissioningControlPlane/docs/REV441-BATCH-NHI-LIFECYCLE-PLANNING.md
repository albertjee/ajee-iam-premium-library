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

- `Readiness`
- `WhatIf`
- `Verify`
- `Closeout`

## Batch Manifest Fields

The wrapper writes a batch manifest with these root fields:

- `BatchId`
- `TenantId`
- `ApprovedAction`
- `Mode`
- `MaxObjectsPerWave`
- `StopOnFirstFailure`
- `FinalDeleteApproved = false`
- `CleanupApproved = false`
- `Targets[]`

Each target record includes:

- `DisplayName`
- `ObjectType`
- `ServicePrincipalObjectId`
- `AppId`
- `RiskReason`
- `OwnerStatus`
- `LastObservedActivity`
- `ApprovedAction`

## Output Layout

The wrapper writes a timestamped run root under `C:\temp\IAM` unless `-OutputRoot` is supplied.

Per-object folders are created under the batch output root, with one summary JSON file per target.

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
