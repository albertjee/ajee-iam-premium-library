# Entry-Point Decomposition Plan (v1 - APPROVED)

> Status: M1-M7 COMPLETE, 2026-07-05. All 6 regions (D-I) extracted to
> src/EntryPoint/ companions; entry point reduced from 1906 to 209 lines.
> M8 (closed-set safety test, docs) complete. See
> docs/entrypoint-decomposition-anchors.md for the full commit-by-milestone
> history and post-landing corrections found along the way.
> Baseline: main `48d0eeb`, 2408/2408 passing
> Scope: `Invoke-EntraIdentityDecommissioningControlPlane.ps1` (1906 lines) + 9+ test files
> that assert on its source text (grew to 13+ files during migration; see anchors doc)

---

## 1. Objective and the explicit trade-off

Decompose the 1906-line, zero-function, 48-parameter procedural entry point into dot-sourced
companion files following the Phase 2/5 pattern - **with coordinated migration of the test
anchors that currently pin its source text in place.**

**Trade-off (signed off by Albert at Gate 1):** today, the single file is a deliberately
monolithic auditable artifact - 9 test files prove safety properties (no mutation cmdlets,
SelfTest-before-Graph ordering, per-block scope containment) by scanning ONE file. After
decomposition those properties span N files. **Mitigation:** a new closed-set safety test
asserts (a) the main file dot-sources exactly the expected companion list and nothing else,
and (b) every whole-file absence/presence scan runs over the concatenated corpus
(main + all companions in dot-source order), so the audit surface stays closed and
machine-checked.

This is NOT a suite-untouched refactor: test files will be edited. Every migrated assertion
must keep its meaning (same property, new target); the total test count must not drop below
2408, and every milestone must end 0 failures.

---

## 2. Current state (measured)

- `Invoke-EntraIdentityDecommissioningControlPlane.ps1`: 1906 lines, **0 functions**,
  48 parameters, parse errors 0. Pure top-to-bottom procedural flow; all state is
  script-scope variables flowing across regions.
- Not in the CLAUDE.md section 7 frozen list (modifiable; has been modified in every Rev4.x).

### Region map (line numbers at `48d0eeb`)

| Region | Lines | Content | Proposed disposition |
|---|---|---|---|
| A | 1-70 | param block (48 params), `$script:ToolVersion` | **STAYS in main** (AST param-contract tests; VersionHygiene regex) |
| B | 72-162 | mode validation, module imports, setup | **STAYS in main** (small; imports use `$PSScriptRoot` relative to repo root) |
| C | 163-194 | SelfTest early exit (`exit 0/1`) | **STAYS in main** (ordering anchor 'SelfTest early exit'; small) |
| D | 196-637 | Rev4.2-S1 controlled NHI decommission branch (`exit 0`) | -> `src/EntryPoint/ControlledNhiDecommission.ps1` (~442 lines) |
| E | 638-960 | Rev4.0 M35 NHI execution guard + flow | -> `src/EntryPoint/NhiExecutionFlow.ps1` (~320 lines) |
| F | 961-1242 | Assessment context, write-readiness, Graph connect blocks | -> `src/EntryPoint/AssessmentFlow.ps1` (~280 lines) |
| G | 1243-1611 | NHI governance pack + agent activity audit + demo block | -> `src/EntryPoint/NhiGovernancePack.ps1` (~370 lines) |
| H | 1612-1829 | Rev3.4 hardening outputs | -> `src/EntryPoint/HardeningOutputs.ps1` (~220 lines) |
| I | 1830-1906 | Rev3.5 NHI governance pack | -> `src/EntryPoint/Rev35GovernancePack.ps1` (~77 lines) |

Post-split main file: regions A+B+C + a dot-source orchestration block (companions in
original region order) - roughly 260 lines. Exact boundaries re-verified per milestone
(line numbers shift; re-grep markers before each slice, per the Phase 2 mechanics rule).

**Dot-source semantics note:** dot-sourcing runs companion code in the CALLER's scope -
script variables flow across companion boundaries exactly as they do across regions today,
and `exit` inside a dot-sourced file exits the entry point (current behavior of regions D/E).
Two audits required per moved region (milestone checklist): (1) no use of `$PSScriptRoot` /
`$PSCommandPath` / `$MyInvocation` inside the region (these change meaning when the code
moves to `src/EntryPoint/`); (2) no `#region`-relative assumptions.

---

## 3. Test-anchor inventory and migration strategy

9 test files read the entry-point source. Assertion classes and their migrations:

| Class | Example | Current target | New target |
|---|---|---|---|
| Extraction-span | Safety.NhiControlled.Consolidated extracts lines 196-637 via IndexOf markers, ~30 Should -Match on the span | EntrySource substring | Read `src/EntryPoint/ControlledNhiDecommission.ps1` directly (simpler than markers) |
| Presence (whole-file) | NhiExecution.Rev40: ~20 Should -Match ('PhaseLimit', 'ScreamTestDays', ...) | EntrySource | Concatenated corpus (main + companions in dot-source order) via a shared helper |
| Absence (whole-file) | ReleaseValidation.Rev31: Should -Not -Match 'Remove-Mg' (with allowlist trick) | EntrySource | Concatenated corpus - absence must hold across ALL files |
| Ordering | Rev33: IndexOf('Test-DecomWhatIfManifest') < IndexOf('Test-DecomApprovalManifest') < IndexOf('Connect-MgGraph'); Safety: SelfTest before controlled before Connect-MgGraph | EntrySource positions | Concatenated corpus in dot-source order - first-occurrence semantics preserved because concatenation order == execution order |
| Block-slicing | Rev33/P1Fixes slice assess/demo/exec blocks, assert scopes per block | EntrySource substrings | Target the specific companion file(s) containing each block |
| AST contract | param block, prohibited-CommandAst scans | Entry point AST | Param contract: unchanged (params stay in main). CommandAst scans: run over main + each companion AST |
| Version/schema | VersionHygiene: ToolVersion regex | EntrySource | Unchanged (ToolVersion stays in main) |

Affected files (assertion-line counts are upper bounds; the M1 table will list each):
`Safety.NhiControlled.Consolidated.Tests.ps1` (~40 entry-anchored),
`NhiControlledDecommission.Rev4x.Consolidated.Tests.ps1` (~10 entry-anchored),
`NhiExecution.Rev40.Tests.ps1` (~39), `ReleaseValidation.Rev33.Tests.ps1` (~29),
`ReleaseValidation.Rev31.Tests.ps1` (~10), `Rev30.Integration.Tests.ps1` (~9),
`Safety.Rev34.Tests.ps1` (~4), `VersionHygiene.Rev36.Tests.ps1` (unchanged),
`P1Fixes.Rev32.Tests.ps1` (~3).

**Frozen-test check:** none of the 9 files is in the frozen list (Decom*.Tests.ps1 are
frozen; these are not).

### New safety test (net-new coverage, added in M8)

`tests/EntryPointClosedSet.Tests.ps1`:
1. Main file dot-sources exactly the 6 expected companions, in the expected order, and no
   other `. (Join-Path ...)` lines exist.
2. `src/EntryPoint/` contains exactly those 6 files (no unlisted executable code).
3. The concatenation helper used by migrated tests resolves to main + those 6 in order.

---

## 4. Milestones (each: Gate 1 parse -> Gate 2 run -> Gate 3 full suite -> commit)

- **M0** - Commit this plan doc after approval. Re-verify baseline 2408/2408 on `48d0eeb`.
- **M1** - READ-ONLY assertion-migration table: every entry-anchored assertion in the 9
  files, its class, and its exact new target. Artifact:
  `docs/entrypoint-decomposition-anchors.md`. **STOP - Albert approves the table before
  any code moves.**
- **M2** - Shared test helper (corpus concatenation in dot-source order) + region D
  extraction (`ControlledNhiDecommission.ps1`) + migrate its anchors (Safety consolidated,
  NhiControlledDecommission consolidated, Rev33 demo-block slices as applicable). Gates. Commit.
- **M3** - Region E (`NhiExecutionFlow.ps1`) + NhiExecution.Rev40 + P1Fixes exec-block
  anchors. Gates. Commit.
- **M4** - Region F (`AssessmentFlow.ps1`) + Rev33 assess-block/ordering + Rev30 anchors.
  Gates. Commit.
- **M5** - Region G (`NhiGovernancePack.ps1`) + Safety.Rev34 demo anchors. Gates. Commit.
- **M6** - Region H (`HardeningOutputs.ps1`) + any Rev3.4 SchemaVersion anchors. Gates. Commit.
- **M7** - Region I (`Rev35GovernancePack.ps1`). Gates. Commit.
- **M8** - `EntryPointClosedSet.Tests.ps1` + docs (refactoring-plan.md section, CHANGELOG
  entry, CLAUDE.md canonical count update if it changed). Gates. Commit.
- **M9** - External review (CodeRabbit on the PR + /code-review pass), fix findings, PR to
  main. Albert merges.

Execution rules (carried over from Phase 2/5): re-grep markers before every slice (line
numbers shift); UTF-8 no BOM, CRLF; slice verbatim - never retype code; serialize edits
(never edit a file while a suite run is in flight); revert immediately on any red suite,
never pile fixes on broken state.

## 5. Risks

| Risk | Mitigation |
|---|---|
| Missed source anchor -> false-red suite mid-milestone | M1 exhaustive table approved first; per-milestone full-suite gate catches strays; revert rule |
| `$MyInvocation`/`$PSScriptRoot` semantics change in moved region | Per-region audit in each milestone checklist before slicing |
| Ordering-assertion semantics drift (first-IndexOf over corpus vs single file) | Concatenation order == dot-source order == original region order; M1 table records expected positions |
| Audit-surface regression (the signed-off trade-off) | Closed-set test (M8) + absence scans over full corpus - stronger than trusting directory contents |
| Test count drops below 2408 | Migrations are 1:1 rewrites; count asserted at every milestone gate; M8 adds net-new tests |
