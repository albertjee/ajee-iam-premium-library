# Rev4.42 and Rev4.43 Batch Gates

Rev4.42 adds a controlled batch reversible-disable gate.
Rev4.43 adds a controlled batch rollback gate for previously changed objects.

## Safety model

The batch wrappers scale the single-object safety model. They do not bypass the Rev4.41 planning gate.

Each object must have its own:

- identity check
- tenant check
- target validation
- platform and Microsoft first-party classification check
- owner and risk eligibility check
- pre-action snapshot reference
- prior WhatIf evidence reference
- approval state
- mutation eligibility result
- per-object artifact folder
- post-action validation result
- rollback package reference
- closeout summary record

## Rev4.42

Rev4.42 is limited to `ReversibleDisable`.

Required inputs:

- `BatchId`
- matching `TenantId`
- `ApprovedAction = ReversibleDisable`
- explicit `Mode = Execute` for live-path representation
- prior Rev4.41 WhatIf/readiness run root
- per-object WhatIf evidence
- per-object approval state
- conservative `MaxObjectsPerWave` value
- `StopOnFirstFailure = true`
- prior planning evidence must still show `SafetyGatePassed = true`
- prior planning evidence must mark the target as `MutationEligible = true`

Blocked conditions:

- final delete
- cleanup
- `Remove-Mg*`
- Microsoft first-party identities
- platform identities
- unknown classification
- high-risk objects
- ownerless or uncertain owner state unless explicitly marked evidence-only
- missing prior WhatIf evidence
- missing per-object evidence
- missing approval state
- missing identity or AppId
- stale or mismatched prior planning evidence
- prior planning evidence that failed the safety gate
- prior planning evidence that did not mark the target as mutation eligible

Artifacts:

- per-object pre-snapshot record
- per-object changed-object manifest
- per-object rollback package
- per-object post-disable validation contract
- batch execution summary
- batch closeout-ready summary

The batch execution summary and closeout-ready summary are written even when the gate blocks a target, and they record `ExecutionNotPerformed = true`, `LiveMutationPerformed = false`, `SafetyGatePassed = false` when rollback evidence is incomplete, and populated blocking reasons.

## Rev4.43

Rev4.43 is limited to `RollbackDisable`.

Rollback requires:

- a prior approved batch run root
- the prior changed-object manifest
- the prior rollback package
- matching tenant and target identity
- matching AppId
- proof that the object was changed by the prior approved batch run

Rollback is not allowed for arbitrary object lists.
Rollback is not allowed when the prior run root or artifact references are missing.
Rollback emits a batch summary even when evidence is blocked or incomplete so downstream closeout can consume a stable gate-only artifact chain.

Artifacts:

- per-object rollback validation record
- batch rollback summary

## Why final delete remains blocked

Rev4.42 and Rev4.43 are reversible lifecycle gates.
Final delete is outside scope and remains blocked to avoid creating a second irreversible path.

## Why cleanup remains blocked

Cleanup is still blocked because these batch wrappers are limited to controlled reversible disable and rollback behavior.
Nothing in these wrappers should expand into a broad tenant cleanup surface.

## Why `Remove-Mg*` remains blocked

The batch wrappers do not introduce delete-style Graph operations.
They delegate to the existing fixed single-object lifecycle wrappers when a live path is represented, and those wrappers already carry the narrower mutation surface.

## Approval and evidence

Batch execution expects a human approval phrase and explicit evidence references.

The batch manifest should carry:

- the prior Rev4.41 WhatIf evidence reference
- the per-object WhatIf evidence reference
- the per-object approval state
- the expected tenant
- the expected object identity and AppId

## Evidence-only handling

Uncertain owner state can be recorded for evidence-only review, but it must not become mutation eligible.
Uncertain classification is rejected for mutation.

## Wave sizing

`MaxObjectsPerWave` is intentionally conservative.
The current batch gate uses a safe bound of 3 objects per wave.
`StopOnFirstFailure = true` is the default and later objects in the same wave are not processed after a blocking failure.

## Rollback package

Each reversible-disable target gets a rollback package that points to the pre-snapshot and changed-object manifest.
Rollback can only use those generated packages.

## Closeout summaries

Each batch emits a closeout-ready summary so later review can aggregate only from prior artifacts.
