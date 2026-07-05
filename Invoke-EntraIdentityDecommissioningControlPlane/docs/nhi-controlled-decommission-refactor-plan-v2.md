# NhiControlledDecommission.psm1 Refactor Plan v2 (Tighter Pass)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

> **Status:** EXECUTED - committed at fe4c7c0, 2430/2430 passing
> **Supersedes:** `docs/nhi-controlled-decommission-decomposition-plan.md` (7-module split - v1)
> **Branch:** `refactor/phase1-cleanup`
> **Baseline:** 2,430 tests, 0 failures (HEAD `91ed88b`)

**Goal:** Split the 5,916-line / 65-function `NhiControlledDecommission.psm1` into 6 dot-sourced companion `.ps1` files behind a ~60-line loader, fix the `New-NhiControlledGateVerdict` paste-error duplicate, with zero change to module identity, exports, schema versions, or test files. A follow-on **Phase 7** (separately approved, bottom of this doc) then consolidates the redundant rev-by-rev test files (2,430 -> ~2,000-2,100) without losing any unique assertion.

**Architecture:** Same pattern as the Phase 2 Discovery decomposition, which is already proven in this repo at 2,430/2,430. The `.psm1` keeps its filename, its `Import-Module Utilities` line, its 4 `$script:` variables, and its single `Export-ModuleMember` block; function bodies move verbatim into `NhiControlledDecommission.<Subsystem>.ps1` files that are dot-sourced into the module's own scope.

**Tech Stack:** PowerShell 7+ (pwsh), Pester, Git. Gates per CLAUDE.md section 2.

---

## Why v2 is tighter than v1

| Concern | v1 (7 sub-modules) | v2 (dot-source companions) |
|---|---|---|
| Module identity | 7 new `.psm1` files + facade re-export layer | Unchanged - one module, one identity |
| `$script:` variables (4) | Copied into each of 7 modules (drift hazard) | Stay in loader once; dot-sourced code sees them natively |
| Import ordering | Cross-module dependency ordering to manage | None - dot-source order is irrelevant for function definitions |
| `Export-ModuleMember` | Split across 7 files + facade aggregation | Unchanged - single existing block in loader |
| Test impact | Facade must perfectly re-export or 30+ test files break | Zero - tests `Import-Module` the same path and get the same surface |
| Rollback story | Multi-file revert | `git revert` of small per-milestone commits |

**Enabling fact (verified 2026-07-04):** `grep InModuleScope NhiControlledDecommission tests/` returns zero matches. Nothing pins code to sub-module boundaries; only the imported module's public surface matters.

**Freeze check (CLAUDE.md section 7) - PASSED:** `src/Modules/NhiControlledDecommission.psm1` is not on the frozen list. All companion files are new filenames. No frozen file is touched.

---

## Verified source facts

- Physical lines: 5,916. Function definitions found: 66 (65 unique + 1 duplicate).
- Exported functions: 30 (single `Export-ModuleMember` block, lines 5884-5915).
- Internal (non-exported) functions: 35.
- `$script:` variables: 4, all defined lines 14-17, none assigned inside any function.
- Duplicate: `New-NhiControlledGateVerdict` at lines 3064-3089 (LOOSE: `Severity = 'High'` default, `[AllowEmptyString()]` on `Reason`, no `[OutputType]`) and lines 3881-3907 (STRICT: `[OutputType([PSCustomObject])]`, all four params mandatory with `ValidateNotNullOrEmpty`). **CORRECTION at execution time (v1 doc had these swapped):** PowerShell last-definition-wins means the STRICT copy at 3881 is what runs today. M1 therefore deletes the loose copy at 3064-3089 - a zero-behavior-change edit since the strict copy already wins. All 6 call sites (lines 3261, 3869, 4187, 4354, 4935, 5288) pass all four parameters explicitly.

---

## Target file layout

```
src/Modules/NhiControlledDecommission.psm1                      (~60 lines: header, Utilities import, 4 script vars, dot-source block, Export-ModuleMember)
src/Modules/NhiControlledDecommission.Core.ps1                  (~330 lines,  8 functions)
src/Modules/NhiControlledDecommission.Gates.ps1                 (~450 lines, 11 functions)
src/Modules/NhiControlledDecommission.CleanupPlanning.ps1       (~580 lines, 12 functions)
src/Modules/NhiControlledDecommission.PlanEvidence.ps1          (~670 lines, 13 functions)
src/Modules/NhiControlledDecommission.LabRehearsal.ps1          (~1520 lines, 6 functions)
src/Modules/NhiControlledDecommission.Run4C.ps1                 (~2330 lines, 15 functions)
```

65 functions total across companions. Loader dot-source block:

```powershell
$_controlledHelpers = @(
    'NhiControlledDecommission.Core.ps1',
    'NhiControlledDecommission.Gates.ps1',
    'NhiControlledDecommission.CleanupPlanning.ps1',
    'NhiControlledDecommission.PlanEvidence.ps1',
    'NhiControlledDecommission.LabRehearsal.ps1',
    'NhiControlledDecommission.Run4C.ps1'
)
foreach ($_helper in $_controlledHelpers) {
    . (Join-Path $PSScriptRoot $_helper)
}
```

### Function-to-file map (line numbers = current file, pre-edit)

**Core.ps1** (8): Get-NhiControlledDecommissionSha256 (19-36), ConvertTo-NhiControlledSanitizedValue (37-96), Get-NhiControlledDecommissionSchema (97-125), ConvertTo-NhiControlledSnapshot (126-176), Get-NhiControlledTargetCountsByType (1155-1190), Get-NhiControlledStatusText (1191-1209), Get-NhiControlledPropertyValue (2060-2085), New-NhiControlledChecklist (2086-2101)

**Gates.ps1** (11): Test-NhiControlledTarget (177-198), Confirm-NhiControlledApproval (199-257), Get-NhiControlledScreamTestStatus (258-304), Test-NhiControlledDependencies (305-335), Get-NhiControlledDeleteReadiness (336-380), Test-NhiControlledServicePrincipalFinalDeleteGate (381-433), Test-NhiControlledApplicationDeleteReadinessGate (434-496), Get-NhiControlledRollbackLimitation (497-529), Get-NhiControlledCredentialMetadataEvidence (530-554), Get-NhiControlledOwnerMetadataEvidence (555-576), New-NhiControlledGateVerdict (3064-3090, the KEPT strict copy)

**CleanupPlanning.ps1** (12, one contiguous block 577-1154): New-NhiControlledMetadataInventory, Test-NhiControlledMetadataCleanupReadinessGate, New-NhiControlledMetadataCleanupPlan, New-NhiControlledMetadataCleanupActionLog, Get-NhiControlledDependencyRecheckStatus, Test-NhiControlledGrantCleanupReadinessGate, New-NhiControlledGrantCleanupPlan, New-NhiControlledGrantCleanupActionLog, Get-NhiControlledManagedIdentityType, Test-NhiControlledManagedIdentityReadinessGate, New-NhiControlledManagedIdentityReadinessPlan, New-NhiControlledManagedIdentityActionLog

**PlanEvidence.ps1** (13): New-NhiControlledE2EEvidencePack (1210-1333), New-NhiControlledOperatorDecisionLog (1334-1364), New-NhiControlledRollbackPlan (1365-1388), New-NhiControlledDecommissionPlan (1389-1448), Export-NhiControlledDecommissionEvidence (1627-1646), New-NhiControlledProductionReadinessEvidenceState (1647-1684), New-NhiControlledFindingDispositionSummary (1685-1710), New-NhiControlledKnownWarningInventory (1711-1785), New-NhiControlledFinalSafetyAssertions (1786-1807), New-NhiControlledProductionReadinessGate (1808-1961), New-NhiControlledReleaseMergeGateManifest (1962-1996), New-NhiControlledMergeGate (1997-2021), New-NhiControlledProductionReadinessEvidencePack (2022-2059)

**LabRehearsal.ps1** (6): Test-NhiControlledLabLiveReversibleDisableReadiness (1449-1626), New-NhiControlledLabDisableDryRunPackage (2102-2459), New-NhiControlledLabRollbackDrillPackage (2460-2678), Invoke-NhiControlledLabLiveReversibleDisable (2679-3063), Invoke-NhiControlledLabRollback (3977-4195), New-NhiFinalDeleteEligibilitySimulationPackage (4196-4362)

**Run4C.ps1** (15): New-NhiRun4CFinalGoNoGoReviewPackage (3091-3322), New-NhiRun4CLiveEvidenceCapturePackage (3323-3509), New-NhiRun4CPostDisableObservationPackage (3510-3665), New-NhiRun4CRollbackExecutionReadinessPackage (3666-3880), Get-NhiRun4CTargetContext (3909-3976), New-NhiRun4CEndToEndLabRehearsalReport (4363-4569), New-NhiRun4CConsultantOperatingGuide (4570-4697), Get-NhiRun4CArtifactRecord (4698-4726), New-NhiRun4CFinalControlledDisableTestPackage (4727-5003), New-NhiRun4CPostDisableEvidenceValidationPackage (5004-5175), New-NhiRun4CControlledRollbackExecutionTestPackage (5176-5355), New-NhiRun4CPostRollbackValidationPackage (5356-5506), New-NhiRun4CFinalEvidenceBundle (5507-5735), New-NhiRev4ReleaseCandidateFreezePackage (5736-5883)

---

## Invariants (must hold at every milestone)

1. `Export-ModuleMember` block: byte-identical, stays in the loader.
2. All 65 function bodies move **verbatim** - no logic edits, no renames, no signature changes (sole exception: deleting the duplicate in Milestone 1).
3. Schema versions 4.2-4.9 untouched.
4. Zero test-file edits.
5. Companion files contain function definitions only - nothing executes at dot-source time.
6. UTF-8 no BOM, CRLF, ASCII-only (CLAUDE.md sections 12-13). Extraction via `[System.IO.File]::WriteAllText(..., [System.Text.UTF8Encoding]::new($false))`.
7. Gates after every milestone: Gate 1 (parse = 0 errors on every touched file), Gate 2 (silent `Import-Module`), Gate 3 (`Invoke-Pester .\tests\ -Output Minimal` = 2,430+, 0 failures). Commit per milestone with verbatim test counts.

---

## Milestones

### Milestone 0: Baseline

**Files:** none modified.

- [ ] **Step 0.1:** `git status --short` - working tree must be clean of tracked modifications (untracked diagnostics OK)
- [ ] **Step 0.2:** Run full suite, record canonical count:
  ```powershell
  pwsh -NoProfile -Command "Invoke-Pester -Path .\tests\ -Output Minimal"
  ```
  Expected: `Tests Passed: 2430` (or current baseline), `Failed: 0`. HALT if not.

### Milestone 1: De-duplicate `New-NhiControlledGateVerdict`

**Files:** Modify `src/Modules/NhiControlledDecommission.psm1` (delete lines 3881-3908, the loose copy).

Behavioral note: today the loose copy (last definition) wins at runtime. After deletion the strict copy (3064-3090) takes effect. All 6 call sites pass `-GateName -Passed -Severity -Reason` explicitly, so the only new failure surface is an empty `Severity`/`Reason` value reaching `ValidateNotNullOrEmpty` - exactly what Gate 3 exists to catch.

- [ ] **Step 1.1:** Delete the function definition at lines 3881-3908 (the copy where `[string]$Severity = 'High'`). Leave the 3064-3090 definition untouched.
- [ ] **Step 1.2:** Gate 1:
  ```powershell
  pwsh -NoProfile -Command "$e = $null; [void][System.Management.Automation.Language.Parser]::ParseFile('C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane\src\Modules\NhiControlledDecommission.psm1', [ref]$null, [ref]$e); Write-Host \"Parse errors: $($e.Count)\""
  ```
  Expected: `Parse errors: 0`
- [ ] **Step 1.3:** Gate 2:
  ```powershell
  pwsh -NoProfile -Command "Import-Module 'C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane\src\Modules\NhiControlledDecommission.psm1' -Force -DisableNameChecking; Write-Host 'Module import: OK'"
  ```
  Expected: silent, then `Module import: OK`
- [ ] **Step 1.4:** Gate 3 full suite. Expected: 2,430+, 0 failures.
- [ ] **Step 1.5:** `git diff --name-only` - only `src/Modules/NhiControlledDecommission.psm1`. Commit:
  ```
  fix: Phase 5 M1 -- remove New-NhiControlledGateVerdict paste-error duplicate (strict signature now authoritative), NNNN/NNNN passing
  ```

### Milestones 2-7: Extract companions (one file per milestone, one commit each)

Order: **M2 Run4C -> M3 LabRehearsal -> M4 PlanEvidence -> M5 CleanupPlanning -> M6 Gates -> M7 Core.** Bottom-of-file-first keeps remaining line numbers stable longest; Core last leaves the loader slim-down as the trivial final step.

Identical procedure per milestone (shown once; repeat with that milestone's function list from the map above):

- [ ] **Step N.1:** Create `src/Modules/NhiControlledDecommission.<Name>.ps1` with header:
  ```powershell
  # NhiControlledDecommission.<Name>.ps1
  # Dot-sourced into NhiControlledDecommission.psm1 module scope. Do not import directly.
  # Contains: <function list>
  ```
  then the milestone's function bodies **moved verbatim** from the .psm1. Write with `[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))`, CRLF preserved.
- [ ] **Step N.2:** In the .psm1, delete the moved function bodies. On the first extraction milestone (M2), insert the dot-source block (shown in "Target file layout") after line 17; on later milestones the block already exists - no loader edit needed.
- [ ] **Step N.3:** Gate 1 on BOTH files (the .psm1 and the new .ps1) - `Parse errors: 0` each.
- [ ] **Step N.4:** Gate 2 - silent `Import-Module ... -Force -DisableNameChecking`, then spot-check surface:
  ```powershell
  pwsh -NoProfile -Command "Import-Module '<abs-path>\NhiControlledDecommission.psm1' -Force -DisableNameChecking; (Get-Command -Module NhiControlledDecommission).Count"
  ```
  Expected: `30` at every milestone.
- [ ] **Step N.5:** Gate 3 full suite. Expected: 2,430+, 0 failures. If a failure appears: `git checkout -- src/Modules/` and re-attempt the milestone; never pile fixes on a broken state.
- [ ] **Step N.6:** `git diff --name-only` - exactly the .psm1 + the new .ps1. Commit:
  ```
  refactor: Phase 5 M<k> -- extract NhiControlledDecommission.<Name>.ps1 (<n> functions, dot-sourced), NNNN/NNNN passing
  ```

Per-milestone specifics:

| Milestone | File | Functions | Notes |
|---|---|---|---|
| M2 | Run4C.ps1 | 15 | Largest chunk (~2,330 lines). Adds the dot-source block to loader. |
| M3 | LabRehearsal.ps1 | 6 | Includes both `Invoke-*` functions and `New-NhiFinalDeleteEligibilitySimulationPackage`. |
| M4 | PlanEvidence.ps1 | 13 | Two source ranges (1210-1448, 1627-2059). |
| M5 | CleanupPlanning.ps1 | 12 | Single contiguous range 577-1154. |
| M6 | Gates.ps1 | 11 | Includes the kept `New-NhiControlledGateVerdict`. |
| M7 | Core.ps1 | 8 | Loader ends ~60 lines: header + Utilities import + 4 vars + dot-source + exports. |

### Milestone 8: Docs + final verification

**Files:** Modify `docs/refactoring-plan.md` (sections 5.5, 5.7, 5.8); this plan doc gets status flipped to EXECUTED.

- [ ] **Step 8.1:** Update refactoring-plan.md: Phase 5 row -> COMPLETE with commit hashes and final line counts (disk-measured, not estimated).
- [ ] **Step 8.2:** Full gates one final time (parse loader + all 6 companions, import, full Pester). Report Pester Passed/Failed line verbatim.
- [ ] **Step 8.3:** `git diff --name-only` + `git status --short` verbatim. Commit:
  ```
  docs: mark Phase 5 complete -- NhiControlledDecommission split into 6 dot-sourced companions (5916 -> ~60 line loader), NNNN/NNNN passing
  ```

---

## Explicitly out of scope (YAGNI)

- No new Pester tests for individual companions (existing 30+ NhiControlled/Run4C/Safety test files already exercise every exported function; helper-level tests remain a separate backlog item).
- No renames, no signature changes, no logic changes, no schema bumps.
- No `NhiConsts.psm1` extraction (separate investigation, plan section 1.I).
- Original file is NOT kept as a renamed backup (v1 suggested this; git history is the backup).

## Risk register

| Risk | Mitigation |
|---|---|
| Strict GateVerdict signature rejects an empty Severity/Reason at runtime | M1 is isolated + full Gate 3 before anything else moves |
| Mojibake/BOM/LF introduced during extraction | WriteAllText with UTF8Encoding($false); CRLF check per file before commit |
| Accidental drop/duplication of a function during move | Step N.4 export count must equal 30; Gate 2 import fails loudly on missing definitions called at import-check time; Gate 3 covers the rest |
| Str_replace failures on huge move edits | Per CLAUDE.md section 5: after 2 failures switch to read-whole-file -> string surgery -> WriteAllText |

---

# Phase 7 - Test Suite Consolidation (post-refactor, separate approval)

> **Status:** PROPOSED - runs ONLY after Phase 5 (Milestones 0-8 above) is complete and committed.
> **Why after:** the 30+ NhiControlled/Run4C/Safety test files are the safety net for the module split. Consolidating them first would remove the net while walking the wire.
> **Baseline-rule amendment required:** CLAUDE.md section 9 says test count must meet or exceed baseline. Phase 7 deliberately REDUCES the count. The canonical count in CLAUDE.md is amended in the same commit as each consolidation milestone, with a before/after coverage map. This is a documented, intentional exception - not a regression.

## Measured facts (2026-07-04, HEAD 91ed88b)

Full-suite runtime: **212.8s (3.5 min)** for 2,430 tests. Single biggest cost: `SourceIntegrity.Rev37.Tests.ps1` = **49.6s** (23% of total runtime, scans every source file).

| Group | Files | It-blocks | Duplication evidence |
|---|---|---|---|
| `Safety.Rev42-49.Tests.ps1` | 8 | 66 | 57 unique It names of 66 - 9 literal duplicates; same invariant re-asserted per rev ("keeps the controlled branch free of live Graph write/delete patterns" appears 3x, etc.) |
| `NhiControlledDecommission.Rev42-49.Tests.ps1` | 8 | 215 | Cumulative rev-by-rev coverage of one module; Rev42 base assertions re-exercised by later revs |
| `NhiRun4C*.Tests.ps1` | 12 | 230 | Each file repeats the same schema-version / gate-verdict / artifact-record boilerplate assertions per package function |

**Honest sizing:** literal duplication is modest (the 8 Safety files only carry ~9 exact-duplicate assertions). The reduction comes from three sources: (a) merging per-rev files so shared setup/assertion scaffolding is written once, (b) collapsing cumulative re-assertions where a later rev's test strictly supersedes an earlier rev's, (c) extracting Run4C boilerplate into shared `BeforeAll` helpers so per-package files assert only what is unique to that package. Realistic outcome: **2,430 -> ~2,000-2,100 tests with zero behaviors un-covered.** An earlier conversational estimate of ~1,600-1,800 was made before measurement and is superseded by this figure.

## Non-negotiable rules for this phase

1. **No unique assertion is deleted.** Every removed It block must be shown to be (a) a literal duplicate of a surviving It, or (b) strictly subsumed by a surviving It (same code path, same or stronger expectation). The M7.1 inventory documents this mapping per removed test.
2. Frozen test files (`tests/Decom*.Tests.ps1` per CLAUDE.md section 7) are untouched.
3. New consolidated files get NEW filenames (`Safety.NhiControlled.Consolidated.Tests.ps1` etc.); old rev files are deleted via `git rm` in the same commit (git history is the archive - consistent with section 3 no-overwrite discipline).
4. Gates after every milestone. Gate 3 target changes per milestone to the NEW documented count; failures still = 0, always.
5. Each milestone = one commit with before/after counts in the message.

## Milestones

### M7.1: Coverage inventory (read-only, produces approval artifact)

- [ ] Build `docs/test-consolidation-inventory.md`: every It block in the 28 target files mapped to (invariant tested, code path, rev introduced, duplicate-of / subsumed-by / unique verdict).
- [ ] STOP - present inventory to Albert for approval of the specific kill-list before any test file changes.

### M7.2: Merge the 8 Safety.Rev4x files

- [ ] Create `tests/Safety.NhiControlled.Consolidated.Tests.ps1`: one Describe per invariant, keeping the strictest variant of each duplicated assertion. Expected: 66 -> ~45-50 It blocks.
- [ ] `git rm` the 8 old files in the same commit. Gates. Commit with before/after counts.

### M7.3: Consolidate NhiControlledDecommission.Rev42-49 files

- [ ] Regroup 215 tests into per-subsystem files aligned with the Phase 5 companion layout (`NhiControlled.Gates.Tests.ps1`, `NhiControlled.CleanupPlanning.Tests.ps1`, `NhiControlled.PlanEvidence.Tests.ps1`, `NhiControlled.LabRehearsal.Tests.ps1`) - test organization mirrors code organization. Drop only assertions the M7.1 inventory marked subsumed. Expected: 215 -> ~170-185.
- [ ] `git rm` old files same commit. Gates. Commit.

### M7.4: Run4C boilerplate extraction

- [ ] Create `tests/helpers/Run4CAssertions.ps1` (shared schema/verdict/artifact assertion functions, dot-sourced in BeforeAll). Rewrite the 12 Run4C files to call helpers for common assertions, keep package-unique assertions inline. Expected: 230 -> ~180-190, and 12 files stay 12 (they test 12 distinct functions - file count here is correct, only the repetition goes).
- [ ] Gates. Commit.

### M7.5: Runtime win (optional, zero test removal)

- [ ] Tag `SourceIntegrity.Rev37.Tests.ps1` Describe blocks with `-Tag 'Integrity'`; document two run profiles: full (`Invoke-Pester .\tests\`) for pre-commit/CI, fast (`-ExcludeTagFilter 'Integrity'`) for inner-loop dev. Cuts local runs from 3.5 min to ~2.7 min. Full profile remains the Gate 3 standard.

### M7.6: Canonical baseline amendment

- [ ] Update CLAUDE.md section 9: new canonical count (final measured number), dated, with pointer to `docs/test-consolidation-inventory.md` as the coverage-preservation evidence. Update section 6 current revision. Update refactoring-plan.md. Commit.
