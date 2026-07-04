# Refactoring Session Log

> Branch: `refactor/phase1-cleanup`
> Plan: [refactoring-plan.md](refactoring-plan.md)
> Baseline: 2,430 tests, 0 failures (established 2026-07-04 before any change)

---

## Phase 1 — Infrastructure cleanup (2026-07-04)

### What changed

**1. Removed `#Requires -Version 5.1` from 31 non-frozen modules in `src/Modules/`**

The project targets pwsh 7+ only (CLAUDE.md Section 2). The 5.1 declaration was
actively wrong: it implied Windows PowerShell 5.1 support that no longer exists.
Removed the version line only; no other `#Requires` directives were present.

Modified: ApplicationGovernance, ApprovalDiff (had a duplicated declaration),
ApprovalManifest, CatalogValidation, ConditionalAccessGovernance, CredentialHygiene,
EmergencyAccessGovernance, ExecutionLog, ExecutivePack, GuestGovernance, HtmlEncoding,
NhiAgent, NhiAnalysis, NhiCredential, NhiDiscovery, NhiExecution, NhiExecutionSchema,
NhiGovernance, NhiOwner, NhiPermission, NhiPublisher, NhiReporting, NhiSignIn,
ReleasePackaging, ReleaseValidation, Remediation, ReplayValidation, Rev35Readiness,
SchemaContracts, WarningHygiene, WriteReadiness.

Skipped (frozen per CLAUDE.md Section 7): AccessRemoval, BatchContext,
BatchOrchestrator, BatchReporting, BatchState, Rev3CapabilityMatrix, Traceability
still carry the declaration — they are production-locked and out of scope.

**2. Updated `tests/NhiDiscovery.Rev35.Tests.ps1`**

One test asserted the module *declares* `#Requires -Version 5.1`. Inverted the
assertion to enforce the new invariant: the module must NOT declare 5.1.

**3. Fixed latent bug in `tools/Start-NhiLabReadinessEvidence.ps1` (untracked, Rev4.46)**

`Test-RiskAcceptance` called `Test-NotExpiredUtc`, which was never defined —
all 8 Rev4.46 lab-readiness tests failed on any input with an `ExpiresUtc`.
Added the missing function (parses the timestamp, returns whether it is in the
future). This failure pre-dated Phase 1; it surfaced during the baseline run.

### Findings / plan corrections

- `Guardrails.psm1` does not exist in the Premium repo — the plan's Target G
  (missing `New-DecomSkippedBecauseWhatIf` export) referenced the deprecated
  Lite codebase. **Target G is closed as not applicable.**
- `State.psm1` / `Execution.psm1` (Targets E, F) also do not exist in
  `src/Modules/` — Lite-only. **Closed as not applicable.**

### Gates

| Gate | Result |
|---|---|
| 1 — Parse | 31/31 modules + 2 fixed files: 0 errors |
| 2 — Import | 31/31 modules: silent import, no warnings |
| 3 — Pester | Tests Passed: 2430, Failed: 0, Skipped: 0, Total: 2430 |

### Why it matters / what it unlocks

Every later phase edits these same modules. With the version declarations gone
and the test suite enforcing the pwsh 7+ invariant, Phases 2-6 can use 7+ syntax
(ternaries, null-coalescing, `ForEach-Object -Parallel`) without a silent 5.1
contract contradicting them.

---

## Phase 5 pre-analysis — NhiControlledDecommission decomposition plan (2026-07-04)

Read-only analysis of `src/Modules/NhiControlledDecommission.psm1`
(5,916 lines, 65 functions). Full plan:
[nhi-controlled-decommission-decomposition-plan.md](nhi-controlled-decommission-decomposition-plan.md)

Key findings:

- **Duplicate `New-NhiControlledGateVerdict`** — two definitions. Keep L3064-3090
  (has `[OutputType]`, mandatory Severity); discard L3881-3907 (paste error,
  weaker validation).
- **`$script:` state is trivial** — only 4 module-level constants, zero mutation
  inside functions. Extraction risk is far lower than the plan's worst case.
- **7 proposed sub-modules** in dependency order: Core → Validation → Plan →
  DecommissionPlan → Evidence → LabRehearsal → Run4C. Current file becomes a
  facade that imports and re-exports everything (no caller changes).
