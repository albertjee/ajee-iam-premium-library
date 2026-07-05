# ENTRY-POINT DECOMPOSITION - RESUME STATE

> **Written:** 2026-07-05 (session stopped at Albert's request near token limit)
> **Branch:** `refactor/entrypoint-decomposition` (LOCAL ONLY - never pushed)
> **Branch HEAD:** `3e6ab8d` (docs: entry-point decomposition plan v1 approved)
> **main:** `48d0eeb` (PR #20 merge), clean, pushed. Canonical suite: 2408/2408.
> **Plan doc (APPROVED, committed):** `docs/entrypoint-decomposition-plan.md` - READ IT FIRST.
> It contains the full region map, test-anchor migration strategy, milestone list M0-M9,
> and execution rules. This resume doc only records session state ON TOP of that plan.

---

## WHERE WE ARE: M0 half-done, M1 interrupted mid-flight. NO CODE TOUCHED.

### Approved decisions (do not re-litigate)
1. Albert chose **"Full project: decompose + rewrite test anchors"** at Gate 1 - he explicitly
   signed off on trading the single-auditable-file security property for a closed,
   test-enforced companion set (mitigation: `EntryPointClosedSet.Tests.ps1`, plan section 3).
2. Plan v1 approved ("go ahead"), committed as `3e6ab8d`.
3. **M1 output still requires its own approval stop** before any code moves (plan M1).

### What was in flight when "stop" was called (all killed cleanly, no artifacts)
- M0 baseline full-suite run on `48d0eeb` - INCOMPLETE. Tree content equals what passed
  2408/2408 pre-merge (PR #20 branch), but no post-merge full run has completed. Re-run first.
- 3 read-only inventory agents building the M1 assertion-migration table - killed mid-read,
  wrote nothing. Their task specs are reproduced below for re-dispatch.

---

## RESUME PROCEDURE (exact order)

### Step 1 - Confirm state
```powershell
cd C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane
git status --short          # expect clean
git log --oneline -2        # expect 3e6ab8d on refactor/entrypoint-decomposition, then 48d0eeb
```

### Step 2 - Finish M0: baseline
```powershell
pwsh -NoProfile -Command "Invoke-Pester -Path '.\tests\' -Output Minimal"
# REQUIRED: Tests Passed: 2408, Failed: 0  (takes ~4-5 min; run in background)
```

### Step 3 - M1: re-dispatch the 3 read-only inventory agents (parallel, no shared state)
Each agent gets: the region map + migration classes from the plan doc (copy plan section 2
table and section 3 class list into the prompt), plus these file assignments and output spec.

**Common output spec for all 3:** for EVERY assertion or BeforeAll line touching the
entry-point script (reads source / IndexOf-slices / AST / invokes via pwsh -File), one row:
`| Test file : line | It-name | Class 1-7 | Exact anchor string(s) | Region A-I | New target |`
plus flags for: anchors spanning MULTIPLE regions (boundary-straddlers - the dangerous ones),
shared BeforeAll infrastructure and how it must be rewritten, runtime invocations (should
need no change - confirm). READ-ONLY - no file edits.

- **Agent 1:** `tests/Safety.NhiControlled.Consolidated.Tests.ps1` +
  `tests/NhiControlledDecommission.Rev4x.Consolidated.Tests.ps1`
  (the $script:ControlledBranch IndexOf-extraction in BeforeAll is the critical
  infrastructure - region D anchors '# Rev4.2-S1 controlled NHI decommission
  planner/evidence flow' and the '# -- Rev4.0 M35: ...' banner)
- **Agent 2:** `tests/NhiExecution.Rev40.Tests.ps1` + `tests/P1Fixes.Rev32.Tests.ps1`
  (M35/region E; the NHI_REV40_BLOCKED_CMDLETS_DEFINITION comment-guard at entry ~641-660
  imposes a constraint on moving region E - agent must explain it; P1Fixes slices
  exec/assess/non-exec blocks by markers - identify exact marker strings + region coverage)
- **Agent 3:** `tests/ReleaseValidation.Rev31.Tests.ps1`, `ReleaseValidation.Rev33.Tests.ps1`,
  `Rev30.Integration.Tests.ps1`, `Safety.Rev34.Tests.ps1`, `Rev11/VersionHygiene.Rev36.Tests.ps1`
  (whole-file presence/absence incl. Rev31's absence-with-allowlist trick - agent must explain
  what the concatenated-corpus rewrite must preserve; ordering chain Test-DecomWhatIfManifest
  -> Test-DecomApprovalManifest -> Connect-MgGraph; note Connect-MgGraph occurs at ~804, 819,
  1108, 1220 - IndexOf takes FIRST; ToolVersion/SchemaVersion regexes)

Partial findings already reported by the killed agents (use as hints, re-verify):
- Agent 2: NhiExecution.Rev40 touches the entry point only from test-file line ~1181 onward
  (M35 tests); P1Fixes touches it in BeforeAll + three P1-01 scope-gate tests.
- Agent 3 was still pinning down 'Rev3.0', literal '-DemoMode', and SchemaVersion '3.6'
  occurrences when killed.

### Step 4 - Merge agent tables into `docs/entrypoint-decomposition-anchors.md`
Cross-check: every one of the 9 files' entry-anchored lines appears; boundary-straddlers
resolved (adjust region boundaries or keep straddled anchors in main); then commit the
artifact on this branch and **STOP for Albert's approval of the table** (plan M1 gate).

### Step 5+ - M2..M9 per the plan doc. One region per milestone WITH its test migrations in
the same commit; all three gates each; count never below 2408; revert immediately on red.

---

## SESSION-WIDE CONTEXT (already merged / decided, as of this doc)

- PR #19 (Phases 1-7 refactor campaign) MERGED `89135d3`; PR #20 (dead-code removal, 10
  functions / 343 lines) MERGED `48d0eeb` on Albert's authority (CodeRabbit never ran -
  rate-limited). CHANGELOG + CLAUDE.md canonical count (2408) current on main.
- Rev4.46 preserved: `feature/rev446-lab-readiness-evidence` @ `cbae306`, PUSHED to origin,
  no PR yet. Next product thread after this refactor: Rev4.46 review/PR -> separately-approved
  one-object lab Execute test.
- Open follow-ups (not started): SchemaContracts.psm1 missing Utilities import (CLAUDE.md
  section 11 violation, fails standalone, passes in-suite via global leakage - one-line fix);
  Evidence.psm1 wire-or-remove decision (unwired, CR-fixed in PR #19).
- 8 unmerged branches deliberately kept after the sweep (rev442-443, rev444 non-clean,
  rev5-ai-maturity, fix/rev41-graph-filters, two rev433-p2, safety/pr6-wip, rev446).
- Dead-code lesson recorded: zero-reference scans must search BARE function names, not
  scope-prefixed AST names (global:Get-PimRoleName false positive broke 6 tests, reverted).
