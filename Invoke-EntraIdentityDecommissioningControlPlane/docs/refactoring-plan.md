# Refactoring Plan - Entra Identity Decommissioning Control Plane

> **Status:** COMPLETED
> **Scope:** Premium repo ONLY - `src/Modules/` (65 modules, 34,433 lines). `src/LiteModules/` is deprecated and excluded.
> **PowerShell target:** v7+ only - 5.1 is not supported
> **Canonical test count:** 2,459 passing (main HEAD after PRs #26-30; baseline 2,459)

---

## 1. Target Areas

### A. `Discovery.psm1` - 2,530-line `Invoke-DecomAssessmentDiscovery` (God method, Premium)

`Invoke-DecomAssessmentDiscovery` and `Get-DecomSyntheticFindings` are the two primary exported functions. The assessment discovery function aggregates outputs from multiple NHI submodules (NhiSignIn, NhiCredential, NhiPermission, NhiOwner, NhiDiscovery, etc.) and assembles a comprehensive output - but does so with deep inline nesting rather than delegating to helper functions. With only 4 functions in 2,530 lines, the ratio (~630 lines per function) signals this is a god-method that orchestrates too much inline.

`Get-DecomSyntheticFindings` synthesizes findings from submodule outputs without a clean data-passing contract, making unit testing of each finding-synthesis path difficult without exercising the entire discovery chain.

Note: This is the Premium `Discovery.psm1` in `src/Modules/`, not the Lite version. The Lite equivalent in `src/LiteModules/` is excluded from this plan.

### B. `NhiActivityLog.psm1` - Monolithic analysis functions

`Invoke-NhiAgentSignInAnalysis` and `Invoke-NhiAgentDirectoryAuditAnalysis` each run metrics computation, risk scoring, anomaly detection, and timeline construction in a single function body ~180-200 lines each. Finding generation (`New-NhiActivityAssessmentFinding`, ~230 lines) handles 12 distinct finding types in one switch-like cascade with hardcoded risk scores.

The burst detection in sign-in analysis uses an O(n2) rolling window loop that becomes expensive for large sign-in datasets (~1000+ entries).

### C. `NhiGraphApiAudit.psm1` - Monolithic analysis and finding functions

Same structural problem as NhiActivityLog: compute + classify + score + timeline in one function. Additionally, pattern arrays (`HighRiskOperationPatterns`, `ComplianceSensitiveOperations`, `PrivilegeEscalationPatterns`) are duplicated verbatim in NhiActivityLog.psm1, creating a maintenance hazard where updates to one file must be manually mirrored.

### D. Cross-module evidence emission duplication

In Premium, the pattern `New-DecomActionResult` + `Add-DecomEvidenceEvent` is confirmed across 8 action modules: AccessRemoval.psm1 (5 evidence calls), ComplianceRemediation.psm1 (3), MailboxExtended.psm1 (2), DeviceRemediation.psm1 (2), LicenseRemediation.psm1 (2), AppOwnership.psm1 (1), AzureRBAC.psm1 (1), along with anonymous inline patterns in additional callers. The two-step block (construct result, then emit evidence) will drift over time unless consolidated.

Note: LiteModules (src/LiteModules/) has this same pattern but is excluded from this plan.

### E. `State.psm1` - LiteModules-only (OUT OF SCOPE)

Two functions on one line each. While functional, this is an anti-pattern for a file that CLAUDE.md identifies as foundational infrastructure. State.psm1 exists only in `src/LiteModules/` - **excluded from this plan's scope** - and is already well-formatted with doc comments in the current version.

### F. `Execution.psm1` - LiteModules-only (OUT OF SCOPE)

`Invoke-DecomPhase` documentation notes that State.psm1 must be imported by the caller. Execution.psm1 exists only in `src/LiteModules/` - **excluded from this plan's scope**. The dependency is already documented at the top of the file.

### G. `Guardrails.psm1` - LiteModules-only (OUT OF SCOPE)

`New-DecomSkippedBecauseWhatIf` is used by Discovery.psm1, Mailbox.psm1, and Containment.psm1 but is not listed in `Export-ModuleMember`. Guardrails.psm1 exists only in `src/LiteModules/` - **excluded from this plan's scope**.

### H. `Evidence.psm1` - LiteModules-only (OUT OF SCOPE) + global mutable singleton without synchronization

`$script:DecomEvidenceNdjsonPath` is a module-scoped singleton used by `Add-DecomEvidenceEvent` to write NDJSON lines. There is no file locking, no coordination with the in-memory `$Context.Evidence` list, and no thread-safety. Evidence.psm1 exists only in `src/LiteModules/` - **excluded from this plan's scope**. The same pattern in Premium NHI modules may need a separate investigation.

### I. Scope array drift risk in NHI reporting modules

Both NhiReporting.psm1 and EvidenceBundle.psm1 contain hand-coded scope/permission arrays that may duplicate definitions stored elsewhere. No single `$script:Scopes` constant is established as the canonical source of truth - `NhiGovernance.psm1` (587 lines, 1 function) is a single monolithic governance function that likely defines permission requirements inline rather than as a shared data structure. Verify whether these arrays need to be extracted to a `NhiConsts.psm1` or similar constants module.

Note: LiteModules Auth.psm1 (scope duplication) is excluded from this plan.

### J. `Reporting.psm1` - HTML report as inline here-string

`Export-DecomHtmlReport` builds the entire HTML document via string interpolation, with `[ConvertTo-DecomHtmlEncoded]` calls sprinkled throughout. No HTML encoding library, no template file, no separation between data binding and presentation. The CSS is embedded inline and changes require editing PowerShell code. The approach is functional but does not scale for future report complexity.

### K. `NhiControlledDecommission.psm1` - 5,915-line megafile (65 functions)

The largest single module in the codebase at nearly 6,000 lines and 65 exported functions. Functions follow a naming convention of `Invoke-NhiControlled*`, `Test-NhiControlled*`, `New-NhiControlled*`, `Get-NhiControlled*`, and `New-NhiRun4C*` - suggesting at minimum two logical subsystems (the controlled-decommission gate system and the Run4C lab-live rehearsal system) that have been lumped into one file.

The `#Requires` declaration is present on this file. Function names show duplication (`New-NhiControlledGateVerdict` appears on two separate lines - likely a paste error, not intentional overloading). The entire decommission pipeline - gate verdicts, metadata cleanup, metadata inventory, rollback plans, production readiness evidence, operator decision logs, final delete simulation, consultant handoff guides, and end-to-end lab rehearsal reports - lives in one file. Any change to one subsystem risks regressions in another.

---

## 2. The "Why" - Problem Summary

| Target | Smell | Impact |
|---|---|---|
| Discovery.psm1 (Premium) | SRP violation - 2,530 lines in 4 functions; `Invoke-DecomAssessmentDiscovery` orchestrating too much inline | Difficult to unit-test individual discovery sub-paths | **COMPLETED** (Phase 2, commits e761f8a+7204f3c -- 2530L -> 139L, 7 dot-sourced companions) |
| NhiActivityLog analysis | Monolithic compute + score + timeline in one function | Cannot test risk scoring logic independently | **COMPLETED** (Phase 3, commit 58dca9e -- 9 private helpers extracted) |
| NhiGraphApiAudit analysis | Same monolithic pattern as NhiActivityLog | Same | **COMPLETED** (Phase 3, commit 58dca9e -- shared pattern extraction + data-driven findings) |
| Pattern array duplication | Same arrays copy-pasted in two modules | Maintenance hazard; update one, forget the other | **COMPLETED** (Phase 3, NhiPatterns.psm1 created, commit 096f2cd) |
| Evidence emission boilerplate | LiteModules-only target (OUT OF SCOPE) | N/A | N/A |
| Phase 1 targets (State, Execution, Guardrails) | LiteModules-only targets (OUT OF SCOPE) | N/A | N/A |
| Evidence.psm1 global state | LiteModules-only target (OUT OF SCOPE) | N/A | N/A |
| NHI constants drift | NhiReporting, EvidenceBundle, NhiGovernance define permission/scope arrays inline with no canonical source | Silent drift across NHI subsystem as arrays are updated independently | **COMPLETED** (PR #26, NhiScopeCatalog.psm1; PR #28 I-b data-driven NhiGovernance) |
| Reporting.psm1 HTML | Single here-string with inline CSS | Hard to modify report styling without touching PowerShell logic | **COMPLETED** (Target J, PR #30 -- Reporting.Templates.ps1, 2459/2459) |
| NhiControlledDecommission.psm1 | 5,915 lines / 65 functions in one file; multiple subsystems co-located | Git history meaningless per-line; cross-subsystem regression risk; paste-duplicated function names | **COMPLETED** (Phase 5, commit fe4c7c0 -- 5915L -> 66L, 6 dot-sourced companions) |

---

## 3. Step-by-Step Plan

All phases follow Gate 1 (parse), Gate 2 (load), Gate 3 (Pester) verification after each phase. Any gate failure halts the phase and requires diagnosis before proceeding.

### Phase 0 - Baseline (mandatory, do first)

- Clone the repo locally to a clean branch named `refactor/...`
- Run `Invoke-Pester .\tests\ -Output Minimal` and record the canonical test count
- Confirm all tests pass before any change

### Phase 1 - Infrastructure fixes (lowest risk, highest confidence)

**Note:** State.psm1, Execution.psm1, Guardrails.psm1, and Auth.psm1 exist only in `src/LiteModules/`, which is excluded from this plan's scope. The following items target `src/Modules/` only.

1. Remove `#Requires -Version 5.1` from `NhiActivityLog.psm1` and `NhiGraphApiAudit.psm1` - target is pwsh 7+ only; verify with Gate 2 after each edit

### Phase 2 - Discovery.psm1 decomposition (high risk, high reward)

2. Extract `Get-DecomIdentitySnapshot` into private helper functions, one per data source:
   - `_Get-DecomGroupMembership`
   - `_Get-DecomRoleAssignments` (active + eligible, with PIM resolution)
   - `_Get-DecomOwnedObjects`
   - `_Get-DecomAppAssignments`
   - `_Get-DecomMailboxDelegation` (FullAccess, SendAs, SendOnBehalf, forwarding)
   - `_Get-DecomMfaMethods`
3. Each helper returns a `[hashtable]`. `Get-DecomIdentitySnapshot` composes them and becomes ~30 lines of orchestration
4. Freeze the public function signature of `Get-DecomIdentitySnapshot` - parameter names, parameter set, and return type must not change. The refactor must be invisible to callers
5. Write Pester tests for each `_Get-*` helper in isolation

### Phase 3 - NHI audit module decomposition (medium risk, incremental)

6. Create a new `NhiPatterns.psm1` module containing the shared pattern arrays. Update both `NhiActivityLog.psm1` and `NhiGraphApiAudit.psm1` to import it, removing the duplication
7. Break `Invoke-NhiAgentSignInAnalysis` into private helpers:
    - `_Compute-SignInBaseMetrics`
    - `_Detect-SignInBurst` (replace O(n2) rolling window with O(n log n) sorted-index approach)
    - `_Detect-ImpossibleTravel`
    - `Invoke-NhiAgentSignInAnalysis` becomes orchestrator only
8. Apply the same decomposition to `Invoke-NhiAgentDirectoryAuditAnalysis`
9. Refactor `New-NhiActivityAssessmentFinding` - convert hardcoded if/else cascades into a data-driven pattern using finding definitions as a hashtable/array constant. The function iterates over definitions rather than containing branching logic for each finding type
10. Apply the same data-driven refactor to `New-NhiGraphApiAuditFinding`
11. Write Pester tests for each new private helper

### Phase 4 - Reporting polish (low risk)

12. Extract the HTML template structure to named string constants in Reporting.psm1: `_HTML_HEADER`, `_CSS_BLOCK`, `_SUMMARY_CARD_ROW`, `_TABLE_HEADER`, `_TABLE_FOOTER`, `_HTML_FOOTER`. Keep the data-binding logic in `Export-DecomHtmlReport` but push the static HTML skeleton into named constants

### Phase 5 - NhiControlledDecommission split (highest risk effort)

13. Perform a full function-group analysis of NhiControlledDecommission.psm1's 65 exported functions. Categorize by subsystem: controlled-decommission gates, metadata cleanup, metadata inventory, rollback execution, production readiness evidence, operator decision logging, Run4C lab-live rehearsal, consultant handoff, end-to-end lab rehearsal reporting. Use the function naming convention as the primary signal
14. Extract each subsystem into its own module (e.g., `NhiGateVerdict.psm1`, `NhiMetadata.psm1`, `NhiRollback.psm1`, `NhiProductionReadiness.psm1`, `NhiRun4C.psm1`, `NhiConsultantHandoff.psm1`). Each new module must keep the `NhiControlled*` prefix preserved in all exported function names for backward compatibility
15. Verify no GitHub-frozen file (see CLAUDE.md FROZEN FILES section) is in the extraction set. Extract only to new files, never overwrite existing frozen modules
16. Fix the duplicated `New-NhiControlledGateVerdict` function name (paste error) - decide which implementation is authoritative and consolidate
17. Write Pester tests for each new subsystem module in isolation before reassembling

### Phase 6 - Verification (mandatory after every phase)

18. Gate 1: `pwsh -Command { [System.Management.Automation.Language.Parser]::ParseFile('<path>', [ref]$null, [ref]$errors); Write-Host "Parse errors: $($errors.Count)" }` on every modified file - must return 0
19. Gate 2: import/dot-source checks for every modified module - must be silent
20. Gate 3: `Invoke-Pester .\tests\ -Output Minimal` - must equal or exceed the Phase 0 canonical count (2,430 baseline)
21. `git diff --name-only` to confirm only intended files changed; frozen files remain untouched

---

## 4. Risk Assessment

### High risk

**Phase 2 (Discovery decomposition):** In Premium, `Invoke-DecomAssessmentDiscovery` and `Get-DecomSyntheticFindings` are called as part of the assessment discovery pipeline. The function signatures MUST NOT change - parameter names, types, and return object shapes must remain identical. Any refactor must freeze the public contract first. **Mitigation:** write a smoke test that passes a mock context through the existing function and asserts the return object's property names before touching any code.

**Phase 5 (NhiControlledDecommission split):** This is the highest-risk refactor in the plan - 65 functions in 5,915 lines. Every function's implementation touches the rest of the file's `$script:` scope variables. Extracting into separate modules without a full variable-scope audit will break cross-function references. **Mitigation:** Before extracting anything, produce a full `$script:` variable dependency map. Extract subsystems one at a time, running Gate 3 after each extraction. Never delete lines from NhiControlledDecommission.psm1 - only comment-out after confirming the new module is loadable and tests pass.

### Medium risk

**Phase 3 (NHI decomposition):** The analysis functions (`Invoke-NhiAgentSignInAnalysis`, `Invoke-NhiAgentDirectoryAuditAnalysis`) are standalone NHI audit tools. Since they have no callers outside themselves, decomposing into private helpers is safe. However, `New-NhiActivityAssessmentFinding` and `New-NhiGraphApiAuditFinding` ARE the public API of these modules and may be called by external tooling. Their signatures must remain stable.

**Phase 1:** `#Requires -Version 5.1` removal must be verified with Gate 2: `pwsh -Command 'Import-Module ...'` on each updated NHI module. No silent version guard can block pwsh 7+ loading. The 5.1 declaration was actively incorrect - pwsh 7+ handles these modules correctly without it.


**Phase 1** (`#Requires -Version 5.1` removal) and **Phase 4** (Reporting string constants) are purely mechanical refactors with no behavioral change.

### Edge cases

- Phase 1 (`#Requires -Version 5.1` removal) must be verified with Gate 2: `pwsh -Command 'Import-Module ...'` on each updated NHI module - no version guard can silently block pwsh 7+ loading
- Phase 5 (NhiControlledDecommission split): `$script:` variable scope. Before extracting any subsystem, produce a full `$script:` variable dependency map to avoid silent cross-module reference failures. The 65-function file has likely accumulated module-level state - extraction must account for it

---

---

*Generated from codebase analysis - do not begin implementation until approved*

---

## 5. Session Summary -- Refactor/Phase1-Cleanup Branch

**Branch:** `refactor/phase1-cleanup`
**Session date:** 2026-07-04
**Canonical test baseline:** 1,498 tests (Rev4.1)
**CLAUDE.md canonical test count:** 1,498 ≥ must maintain or exceed

---

### 5.1 Scope Correction -- Plan vs. Reality

The original plan text listed Phase 1 targets (`State.psm1`, `Execution.psm1`, `Guardrails.psm1`) and Phase 4 targets (`Evidence.psm1`) in `src/Modules/`. Full path audit revealed:

| Item in original plan | Plan said | Actual location | Resolution |
|---|---|---|---|
| State.psm1 expand | `src/Modules/` | Only `src/LiteModules/` -- excluded from scope | Marked `OUT OF SCOPE` in plan |
| Execution.psm1 circular import | `src/Modules/` | Only `src/LiteModules/` -- excluded from scope | Marked `OUT OF SCOPE` in plan |
| Guardrails.psm1 missing export | `src/Modules/` | Only `src/LiteModules/` -- excluded from scope | Marked `OUT OF SCOPE` in plan |
| Evidence.psm1 file locking | `src/Modules/` | Only `src/LiteModules/` -- excluded from scope | Marked `OUT OF SCCOPE` in plan |
| NhiActivityLog.psm1 `#Requires` | `src/Modules/` | EXISTS | **Completed -- Gate 1+2 passed** |
| NhiGraphApiAudit.psm1 `#Requires` | `src/Modules/` | EXISTS | **Completed -- Gate 1+2 passed** |

**Why these were wrong:** The plan's scope statement explicitly excluded `src/LiteModules/` ("deprecated and excluded") but listed its files as targets. All plan targets were assumed to be in `src/Modules/` (Premium, 65 modules, 34,433 lines). Only NhiActivityLog.psm1 and NhiGraphApiAudit.psm1 were confirmed to actually exist in the Premium modules directory.

---

### 5.2 UTF-8/Unicode Sanitization

**What:** All Unicode em-dashes (U+2014 `--`), en-dashes (U+2013 `-`), superscript 2 (U+00B2 `²`), and other non-ASCII characters in `docs/refactoring-plan.md` were replaced with their ASCII equivalents.

**Why:** CLAUDE.md section 13 prohibits non-ASCII characters in Any executable source, including documentation embedded in the repo. The `--` and `-` characters in the plan document were introduced by an LLM writing the document and are not valid for this repo's UTF-8 standard.

**Files changed:** `docs/refactoring-plan.md`

---

### 5.3 Phase 1 Complete -- Verified

#### `#Requires -Version 5.1` removed from NhiActivityLog.psm1

- **File:** `src/Modules/NhiActivityLog.psm1`
- **Change:** Removed `#Requires -Version 5.1` line (was at line 1 before edit)
- **Gate 1 (Parse):** 0 errors ✅
- **Gate 2 (Import):** Silent import, no warnings ✅
- **Why:** The 5.1 requirement was incorrect and blocked pwsh 7+ loading. The module uses PowerShell 7+ features throughout.

#### `#Requires -Version 5.1` removed from NhiGraphApiAudit.psm1

- **File:** `src/Modules/NhiGraphApiAudit.psm1**
- **Change:** Removed `#Requires -Version 5.1` line
- **Gate 1 (Parse):** 0 errors ✅
- **Gate 2 (Import):** Silent import, no warnings ✅
- **Why:** Same as above.

---

### 5.4 Invalid Phase 1 Items (Marked N/A -- LiteModules Only)

The following Phase 1 items from the original plan were confirmed to target `src/LiteModules/` files only (excluded from scope per the plan's own scope statement):

| Item | File | Status |
|---|---|---|
| State.psm1 expand | `src/LiteModules/State.psm1` | N/A -- excluded |
| Execution.psm1 circular import | `src/LiteModules/Execution.psm1` | N/A -- excluded |
| Guardrails.psm1 Export-ModuleMember | `src/LiteModules/Guardrails.psm1` | N/A -- excluded |
| Evidence.psm1 file locking | `src/LiteModules/Evidence.psm1` | N/A -- excluded |
| Auth.psm1 scope consolidation | `src/LiteModules/Auth.psm1` | N/A -- excluded |

---

### 5.5 Remaining Work and Current Status

| Phase | Task | Status | Blocker |
|---|---|---|---|
| Phase 2 | Discovery.psm1 decomposition -- 7 dot-sourced helpers; 2584 -> 109 lines | **COMPLETE (commits e761f8a + 7204f3c, 2430/2430)** | N/A |
| Phase 3 | Create `NhiPatterns.psm1` (shared pattern arrays) | **COMPLETE (commit 096f2cd)** | N/A |
| Phase 3 | NhiActivityLog + NhiGraphApiAudit decomposition into private helpers (tasks 7-11) | **COMPLETE (commit 58dca9e, 2430/2430)** | N/A |
| Phase 4 | Extract HTML template constants in Reporting.psm1 + NhiReporting.psm1 | **COMPLETE (commit 096f2cd)** | N/A |
| Phase 5 | Split NhiControlledDecommission.psm1 into companions (Core/Gates/CleanupPlanning/PlanEvidence/LabRehearsal/Run4C) | **COMPLETE (commit fe4c7c0, 2430/2430)** | N/A |
| Phase 6 | Verification (mandatory after each phase) | Pending | Per phase |
| Phase 7 | Test consolidation -- merge 28 per-Rev test files (Safety.Rev4x/NhiRun4C/NhiControlledDecommission.Rev4x) into 3 consolidated files | **COMPLETE (pending commit, 2418/2418)** | N/A |

**Phase 2 COMPLETED (2026-07-04, commits e761f8a + 7204f3c):** Decomposed
`Discovery.psm1` into 7 dot-sourced `.ps1` companion files. All helpers verified
at 2430/2430, 0 failures. Line counts below are actual disk measurements.

**Phase 2 extracted helpers (Gate-3 verified at 2430/2430, actual line counts):**
- `Discovery.Coverage.ps1` -- Get-DecomAvailableCommand, New-DecomCoverage (35 lines)
- `Discovery.SyntheticFindings.ps1` -- Get-DecomSyntheticFindings (652 lines)
- `Discovery.UserGuestFindings.ps1` -- _Get-DecomUserFindings, _Get-DecomGuestFindings, _Get-DecomGuestSponsorMetadata, _Get-DecomOwnedObjectFindings (357 lines)
- `Discovery.PimCaExclusion.ps1` -- _Get-DecomPimCaFindings (332 lines)
- `Discovery.AccessReview.ps1` -- _Get-DecomAccessReviewData (194 lines)
- `Discovery.AccessPackages.ps1` -- _Get-DecomAccessPackageFindings (182 lines)
- `Discovery.ReviewCorrelation.ps1` -- _Get-DecomReviewCorrelationFindings (594 lines)

**Final `Discovery.psm1`: 109 lines** -- dot-source loader + thin orchestrator.

**Phase 2 file layout (e761f8a, actual disk line counts):**
```
src/Modules/Discovery.psm1                    (109 lines)
src/Modules/Discovery.Coverage.ps1             (35  lines)
src/Modules/Discovery.SyntheticFindings.ps1   (652 lines)
src/Modules/Discovery.UserGuestFindings.ps1  (357 lines)
src/Modules/Discovery.PimCaExclusion.ps1       (332 lines)
src/Modules/Discovery.AccessReview.ps1         (194 lines)
src/Modules/Discovery.AccessPackages.ps1       (182 lines)
src/Modules/Discovery.ReviewCorrelation.ps1    (594 lines)
### 5.6 Open Issues

### 5.6 Open Issues

1. **NhiControlledDecommission.psm1 extraction requires freeze check:** Before Phase 5 can start, verify none of the 65 functions are in the frozen files list (CLAUDE.md section 7). Task 5 of the step-by-step plan addresses this.

2. **String vs DateTime coercion in SignInActivity:** SignInActivity.LastSignInDateTime may be a DateTime (real Graph) or string (test mock). Always wrap in try { [datetime]raw } catch { $null } before comparison - raw string -lt [datetime] returns $false silently, not a type error. Never do `$raw -lt [datetime]` without the cast.

---

### 5.7 Agent Dispatch Log

| Agent ID | Task | Phase | Status | Notes |
|---|---|---|---|---|
| a4bb52a5 | Create NhiPatterns.psm1 | P3 | Complete | Shared pattern arrays extracted |
| (internal) | Extract HTML constants - Reporting + NhiReporting | P4 | Complete | Phase 4 done |
| (internal) | Decompose Discovery.psm1 into 7 dot-source helpers | P2 | **Complete** | 2584->109 lines, commits e761f8a + 7204f3c, 2430/2430 |
| (internal) | NhiActivityLog + NhiGraphApiAudit private-helper decomposition | P3 | **Complete** | Commit 58dca9e, 2430/2430, tasks 7-11 done |
| (internal) | Split NhiControlledDecommission.psm1 into 6 dot-source companions | P5 | **Complete** | Commit fe4c7c0, 2430/2430, 5915->66 lines |
| a4ade05af1eed3e1c | Consolidate NhiControlledDecommission.Rev4x (8 files -> 1) | P7 | **Complete** | 315/315, 2 of 14 flagged rows were true dupes, 12 false positives kept separate |
| a280e4ea2f50ea8d4 | Consolidate NhiRun4C (12 files -> 1) | P7 | **Complete** | 230/230, 0 of 27 flagged rows were true dupes (all false positives, different function per rev) |
| (internal) | Fix + consolidate Safety.Rev4x (8 files -> 1) | P7 | **Complete** | 54/54 (was 66), 1 real bug found+fixed (-LiteralPath+wildcard silently matched 0 files) |

---

### 5.8 RESUMABILITY CHECKPOINT

> **Last updated:** 2026-07-05
> **Branch:** `refactor/phase1-cleanup`
> **HEAD:** `599d2af` (Phase 7 complete in working tree, pending commit)
> **Phase 2 status:** **COMPLETE** - commits e761f8a + 7204f3c, 2430/2430 passing
> **Phase 3 status:** **COMPLETE** - commit 58dca9e, 2430/2430 passing
> **Phase 5 status:** **COMPLETE** - commit fe4c7c0, 2430/2430 passing
> **Phase 7 status:** **COMPLETE (pending commit)** - 2418/2418 passing (net -12 from 2430 baseline)

Phase 2 is complete (Discovery.psm1: 109 lines, 7 dot-sourced helpers).
Phase 3 is complete (NhiActivityLog + NhiGraphApiAudit: 9 private helpers extracted + data-driven findings refactored).

**Phase 5 COMPLETED (2026-07-04, commit fe4c7c0):** Split
`NhiControlledDecommission.psm1` into 6 dot-source companion files. Loader reduced from
5915 lines to 66 lines. All verified at 2430/2430, 0 failures.

**Phase 5 companion files (fe4c7c0, actual disk line counts):**
- `NhiControlledDecommission.Core.ps1` -- 258 lines, 8 functions
- `NhiControlledDecommission.Gates.ps1` -- 431 lines, 11 functions (377 at extraction; the surviving strict `New-NhiControlledGateVerdict` was added during the slim)
- `NhiControlledDecommission.CleanupPlanning.ps1` -- 581 lines, 12 functions
- `NhiControlledDecommission.PlanEvidence.ps1` -- 675 lines, 13 functions
- `NhiControlledDecommission.LabRehearsal.ps1` -- 1529 lines, 6 functions
- `NhiControlledDecommission.Run4C.ps1` -- 2382 lines, 14 functions

**Final `NhiControlledDecommission.psm1`: 66 lines** -- dot-source loader + Export-ModuleMember.

---

### 5.9 Phase 7 - Test Consolidation (M7.1 + M7.2)

**M7.1 (read-only inventory, 2026-07-04):** `docs/test-consolidation-inventory.md` inventoried 28
per-revision test files (Safety.Rev4x x8, NhiRun4C x12, NhiControlledDecommission.Rev4x x8)
totaling 511 static `It` names, mechanically flagging 48 as "SubSumed" (same name appearing in 2+
files). Per the v2 plan, this required a STOP for Albert's approval of the kill-list before any
file was written.

**M7.2 (consolidation, 2026-07-05):** Each of the 48 flagged names was verified by reading the
actual assertion body in every file it appeared in -- not just matched by name. Two parallel
subagents were dispatched (independent problem domains, no shared state) to handle the NhiRun4C
and NhiControlledDecommission.Rev4x groups; the Safety.Rev4x group was consolidated first as a
smaller pilot and used to establish the pattern.

**Key finding:** the mechanical name-matching in M7.1 could not distinguish "same assertion text,
genuinely duplicated" from "same `It` name reused across revisions, testing a different underlying
function/fixture." Of 48 flagged SubSumed names, only **9 were real duplicates** safe to merge; the
other **39 were false positives** and were correctly kept as separate tests to avoid silent
coverage loss:

- **Safety.Rev4x (8 -> 1 file):** all 7 flagged names were genuine duplicates or semantically
  identical merges (one pair -- "additive module...cmdlets" vs "controlled module...patterns" --
  tested the exact same `$script:ModuleSource` regex-list check under different phrasing across
  revs). Consolidated to `tests/Safety.NhiControlled.Consolidated.Tests.ps1`: **54 tests (was 66,
  -12)**. One real bug found and fixed during consolidation: a `Get-ChildItem -LiteralPath
  <wildcard>` assertion silently matched zero files because `-LiteralPath` never expands
  wildcards; restored to the original exact literal-path + count assertion. Two of the 7 names
  were also found still physically duplicated (copy-pasted into two `Describe` blocks instead of
  actually merged) and were collapsed to one occurrence each.
- **NhiRun4C (12 -> 1 file):** all 27 flagged names were false positives -- every occurrence invoked
  a different underlying `New-NhiRun4C*`/`Invoke-NhiControlledLab*` function per revision (e.g.
  "Package writes JSON artifact locally" checks 9 different artifact-id properties across its 9
  files). Zero merges were safe; consolidated to `tests/NhiRun4C.Consolidated.Tests.ps1` for
  file-count reduction only: **230 tests (unchanged)**. A same-named-helper-function collision
  hazard was found and fixed: several source files declared identically-named local helpers
  (`New-TestTarget`, `Write-TestJson`, etc.) with different signatures, which would have silently
  collided once concatenated into one Pester script scope (later same-named `function` wins for
  every block, not just its own); colliding helpers were renamed with a `Rev<NNN>` prefix
  (body/signature unchanged, call sites updated). Pre-existing test debt in Rev4.16 (four
  `$script:` variables referenced but never assigned, falling through to default via a
  null-check) was reproduced verbatim, not fixed, per the zero-behavior-change mandate.
- **NhiControlledDecommission.Rev4x (8 -> 1 file):** of 14 flagged names, only 2 were genuine
  duplicates (byte-identical assertions against different sample fixtures, collapsed into
  `-ForEach`); the other 12 were false positives (same name, different private gate function --
  e.g. Metadata-cleanup vs Grant-cleanup vs Managed-Identity readiness gates). Consolidated to
  `tests/NhiControlledDecommission.Rev4x.Consolidated.Tests.ps1`: **315 tests (unchanged)** -- the
  M7.1 inventory's static count of 215 undercounted because several `It`s use `-ForEach` and
  running each of the 8 original files individually and summing confirms 315 was always the real
  discovered/executed count.

**Net result:** 28 files -> 3 files. **2430 -> 2418 tests (-12 net)**, entirely from the
Safety.Rev4x group; the other two groups' flagged "duplicates" were mechanical-inventory false
positives, correctly kept separate to avoid coverage loss.

**Verification sequence (all Gate 1/3, `pwsh`):**
1. Each new file Gate-1/Gate-3 verified standalone (54/54, 230/230, 315/315), independently
   re-run and spot-checked (not just trusting the building agent's own report).
2. Full suite run with all 28 old files + 3 new files coexisting: **3029/3029, 0 failures**
   (= 2430 baseline + 599 new-file total, confirming zero interaction effects between old and new).
3. The 28 superseded files removed via `git rm` (confirmed tracked in git first).
4. Full suite re-run: **2418/2418, 0 failures** -- exact match to the pre-computed expectation.

**Docs updated:** `docs/test-consolidation-inventory.md` (all 48 verdict cells resolved from
`[TODO]` to MERGED / KEPT SEPARATE with reasoning), this section, section 5.5 table, section 5.7
agent dispatch log, section 5.8 resumability checkpoint.

**Not yet done:** commit. Per CLAUDE.md, Albert commits/pushes manually -- this is proposed but
not yet executed.

---

### 5.10 Entry-Point Decomposition (M1-M8, branch refactor/entrypoint-decomposition)

Separate campaign from Phase 1-7 above (different branch). Decomposed
`Invoke-EntraIdentityDecommissioningControlPlane.ps1` (1906 lines, 0 functions,
48 parameters, pure top-to-bottom procedural flow) into 6 dot-sourced companions
under `src/EntryPoint/`, one region per milestone, migrating every test that
asserts on the entry point's source text as each region moved.

**Trade-off (signed off by Albert at Gate 1, full detail in
`docs/entrypoint-decomposition-plan.md` section 1):** the pre-decomposition file
was a deliberately monolithic auditable artifact -- 9+ test files proved safety
properties (no mutation cmdlets, SelfTest-before-Graph ordering) by scanning ONE
file. Mitigated by the M8 closed-set safety test (`tests/EntryPointClosedSet.Tests.ps1`),
which makes the companion set itself machine-checked: main must dot-source
exactly the 6 expected companions in the expected order, and `src/EntryPoint/`
must contain exactly those 6 files.

**Milestones and commits:**

| Milestone | Region | Companion | Commit | Lines extracted |
|---|---|---|---|---|
| M1 | -- (assertion-migration table) | -- | `89cfcb0` | -- |
| M2 | D -- controlled NHI decommission | `ControlledNhiDecommission.ps1` | `7a332b0`/`52a4f3a` (PR #21) | 443 |
| M3 | E -- Rev4.0 M35 NHI execution guard | `NhiExecutionFlow.ps1` | `6420c45` | 317 |
| M4 | F -- assessment/write-readiness/Graph connect | `AssessmentFlow.ps1` | `6469099` | 286 |
| M5 | G -- NHI governance pack + demo block | `NhiGovernancePack.ps1` | `8857b21` | 368 |
| M6 | H -- Rev3.4 hardening outputs | `HardeningOutputs.ps1` | `c54b40c` | 217 |
| M7 | I -- Rev3.5 NHI governance pack | `Rev35GovernancePack.ps1` | `ed755ac` | 75 |
| M8 | closed-set safety test + docs | -- | (this commit) | -- |

Entry point: **1906 -> 209 lines** (param block + setup/imports + SelfTest +
6 dot-source lines). Canonical test count grew from 2408 (pre-decomposition
baseline) to **2412** (2407 migrated + 5 new M8 closed-set tests).

**Process discipline that paid off:** starting at M4, the full test suite was
run *before* touching any test file at each milestone (not just the files the
recon/anchor inventory predicted). This caught real gaps the static inventory
missed every time:
- M4 surfaced 2 additional broken files beyond the 9-file M1 inventory and the
  4-agent M4 recon sweep (`NhiControlledDecommission.Rev4x.Consolidated.Tests.ps1`
  had never been in any inventory), including a **pre-existing latent bug from
  M2** (a boundary-straddler assertion broken since the region-D banner moved,
  never caught because nobody ran that specific file until M4's full-suite gate).
- M6 and M7 confirmed the opposite case: when recon predicted near-zero or exact
  failure counts for genuinely low-coverage regions, the full-suite run matched
  the prediction precisely (1 failure at M6, 2 at M7, both exactly as forecast) --
  validating that the recon agents' region-by-region test-anchor tracing was
  reliable once cross-checked against ground truth, not merely trusted blind.

Two anchor mis-attributions in `docs/entrypoint-decomposition-anchors.md`'s
original M1 table (SchemaVersion 3.6 attributed to region F, actually region G;
a Rev3.0 error string attributed to region E, actually region B) were found and
corrected post-M3, before they could cause confusion at the milestone that
actually needed to act on them.

**Not yet done:** M9 (external review -- CodeRabbit + `/code-review` -- and PR to
main). Per CLAUDE.md, Albert pushes/merges manually.

---