# Rev4.44 Batch Gate Evidence Closeout

## Purpose
Rev4.44 is an offline evidence validator. It proves artifact continuity across Rev4.41 planning, Rev4.42 disable-gate, and Rev4.43 rollback-gate evidence without mutating any tenant object.

## Inputs
- `TenantId`
- `BatchId`
- `OutputRoot`
- `PlanningRunRoot`
- `DisableGateRunRoot`
- `RollbackGateRunRoot`
- Optional `InventoryPath`
- Optional `Strict`

## Outputs
Rev4.44 writes a new output folder beneath `OutputRoot` using the batch id and a UTC timestamp.

Expected artifacts:
- `rev444-batch-gate-closeout-summary.json`
- `rev444-batch-gate-closeout-findings.json`
- `rev444-batch-gate-closeout-targets.json`
- `rev444-batch-gate-closeout-operator-runbook.md`

## Safety Model
Rev4.44 is evidence-only.

It does not:
- perform tenant mutation
- run live disable
- run live rollback
- run cleanup
- run delete
- run final delete
- call `Remove-Mg*`
- call direct `Update-MgServicePrincipal`
- invoke child lifecycle execution

If evidence is incomplete or inconsistent, Rev4.44 fails closed.

## Closeout Statuses
- `CloseoutReady`: the evidence chain is consistent and gate-only conditions are confirmed.
- `CloseoutBlocked`: one or more continuity, identity, or safety checks failed.
- `GateOnlyConfirmed`: the gate artifacts explicitly show no live child execution.
- `EvidenceOnly`: the target exists for continuity validation only and is not mutation-ready.
- `IncompleteEvidence`: required state is missing.
- `IdentityMismatch`: service principal or app identity does not match across artifacts.
- `TenantMismatch`: tenant identity does not match across artifacts.
- `BatchMismatch`: batch identity does not match across artifacts.
- `UnsafeBatchId`: the batch id is not safe for path use.
- `MissingArtifact`: a required artifact bundle is missing.
- `WarningOnly`: a non-strict prior-state gap was observed and recorded as a warning only.

## Artifact Continuity Model
Rev4.44 checks:
- `TenantId` continuity
- `BatchId` continuity
- `ApprovedAction` and `Mode` presence on the source summaries
- `FinalDeleteApproved = false`
- `CleanupApproved = false`
- per-target `ServicePrincipalObjectId`
- per-target `AppId` when present
- target classification continuity
- planning readiness / WhatIf evidence
- `SafetyGatePassed` on the source summaries and per-target gate evidence
- gate-only disable evidence
- gate-only rollback evidence
- rollback package prior-state evidence when it is available
- the count of generated closeout output artifacts
- `LiveMutationDetectedCount` only counts explicit live-mutation indicators, not blocked closeout rows by disposition alone

## Why This Does Not Authorize Live Execution
Rev4.42 and Rev4.43 remain gate-only by design. Rev4.44 only validates that the evidence trail is intact. It does not convert those gate artifacts into a live mutation approval and it does not introduce a production execution path.

## Operator Interpretation
- Use `CloseoutReady` only as confirmation that the evidence chain is consistent.
- Treat `CloseoutBlocked` as a stop condition.
- Treat `EvidenceOnly` as non-mutating evidence retention, not as approval to mutate.
- Treat missing prior account state as blocking evidence in `-Strict` mode.
- Treat missing prior account state as warning-only evidence in non-strict mode, which does not increase the blocked target count by itself.
- Treat `SafetyGatePassed = false` anywhere in the evidence chain as a stop condition.
- `BlockedCount` is target-centric, so one target with multiple findings still counts once.
- `LiveMutationDetectedCount` must remain tied to actual live execution indicators such as live child calls or live mutation flags.

## Known Non-Goals
- No live batch disable.
- No live batch rollback.
- No cleanup.
- No delete.
- No final delete.
- No Graph mutation.
- No child lifecycle execution.
- No production run instructions.
- No approval for live mutation.
- Live batch execution out of scope.
