# Refactoring Plan — Entra Identity Decommissioning Control Plane

> **Status:** Proposed — awaiting approval before execution
> **Scope:** Premium repo ONLY — `src/Modules/` (65 modules, 34,433 lines). `src/LiteModules/` is deprecated and excluded.
> **PowerShell target:** v7+ only — 5.1 is not supported
> **Canonical test count:** Must equal or exceed baseline before and after every phase (baseline: 2,430 tests)
> **Steam ON rule:** Do not begin code changes until explicit approval is given

---

## 1. Target Areas

### A. `Discovery.psm1` — 2,530-line `Invoke-DecomAssessmentDiscovery` (God method, Premium)

`Invoke-DecomAssessmentDiscovery` and `Get-DecomSyntheticFindings` are the two primary exported functions. The assessment discovery function aggregates outputs from multiple NHI submodules (NhiSignIn, NhiCredential, NhiPermission, NhiOwner, NhiDiscovery, etc.) and assembles a comprehensive output — but does so with deep inline nesting rather than delegating to helper functions. With only 4 functions in 2,530 lines, the ratio (~630 lines per function) signals this is a god-method that orchestrates too much inline.

`Get-DecomSyntheticFindings` synthesizes findings from submodule outputs without a clean data-passing contract, making unit testing of each finding-synthesis path difficult without exercising the entire discovery chain.

Note: This is the Premium `Discovery.psm1` in `src/Modules/`, not the Lite version. The Lite equivalent in `src/LiteModules/` is excluded from this plan.

### B. `NhiActivityLog.psm1` — Monolithic analysis functions

`Invoke-NhiAgentSignInAnalysis` and `Invoke-NhiAgentDirectoryAuditAnalysis` each run metrics computation, risk scoring, anomaly detection, and timeline construction in a single function body ~180–200 lines each. Finding generation (`New-NhiActivityAssessmentFinding`, ~230 lines) handles 12 distinct finding types in one switch-like cascade with hardcoded risk scores.

The burst detection in sign-in analysis uses an O(n²) rolling window loop that becomes expensive for large sign-in datasets (~1000+ entries).

### C. `NhiGraphApiAudit.psm1` — Monolithic analysis and finding functions

Same structural problem as NhiActivityLog: compute + classify + score + timeline in one function. Additionally, pattern arrays (`HighRiskOperationPatterns`, `ComplianceSensitiveOperations`, `PrivilegeEscalationPatterns`) are duplicated verbatim in NhiActivityLog.psm1, creating a maintenance hazard where updates to one file must be manually mirrored.

### D. Cross-module evidence emission duplication

In Premium, the pattern `New-DecomActionResult` + `Add-DecomEvidenceEvent` is confirmed across 8 action modules: AccessRemoval.psm1 (5 evidence calls), ComplianceRemediation.psm1 (3), MailboxExtended.psm1 (2), DeviceRemediation.psm1 (2), LicenseRemediation.psm1 (2), AppOwnership.psm1 (1), AzureRBAC.psm1 (1), along with anonymous inline patterns in additional callers. The two-step block (construct result, then emit evidence) will drift over time unless consolidated.

Note: LiteModules (src/LiteModules/) has this same pattern but is excluded from this plan.

### E. `State.psm1` — Single-line compressed file

Two functions on one line each. While functional, this is an anti-pattern for a file that CLAUDE.md identifies as foundational infrastructure. It cannot be meaningfully diffed, debugged, or maintained without first being expanded.

### F. `Execution.psm1` — Circular import of State.psm1

`Invoke-DecomPhase` does `Import-Module (Join-Path $PSScriptRoot 'State.psm1')` at script-load time. If State.psm1 is already imported by the caller, this creates a double-load with potential version conflicts. State should be imported once, at the caller (Start-Decom.ps1), and `Invoke-DecomPhase` should receive `$State` as a passed dependency only — not import it at runtime.

### G. `Guardrails.psm1` — Missing Export-ModuleMember entry

`New-DecomSkippedBecauseWhatIf` is used by Discovery.psm1, Mailbox.psm1, and Containment.psm1 but is not listed in `Export-ModuleMember`. The calls work because PowerShell module resolution finds it via auto-import, but this is fragile and relies on implicit load order. This function should be explicitly exported.

### H. `Evidence.psm1` — Global mutable singleton without synchronization

`$script:DecomEvidenceNdjsonPath` is a module-scoped singleton used by `Add-DecomEvidenceEvent` to write NDJSON lines. There is no file locking, no coordination with the in-memory `$Context.Evidence` list, and no thread-safety. If two events fire simultaneously in a pipeline or background runspace, concurrent `Add-Content` calls can corrupt the file or lose entries.

### I. Scope array drift risk in NHI reporting modules

Both NhiReporting.psm1 and EvidenceBundle.psm1 contain hand-coded scope/permission arrays that may duplicate definitions stored elsewhere. No single `$script:Scopes` constant is established as the canonical source of truth — `NhiGovernance.psm1` (587 lines, 1 function) is a single monolithic governance function that likely defines permission requirements inline rather than as a shared data structure. Verify whether these arrays need to be extracted to a `NhiConsts.psm1` or similar constants module.

Note: LiteModules Auth.psm1 (scope duplication) is excluded from this plan.

### J. `Reporting.psm1` — HTML report as inline here-string

`Export-DecomHtmlReport` builds the entire HTML document via string interpolation, with `[ConvertTo-DecomHtmlEncoded]` calls sprinkled throughout. No HTML encoding library, no template file, no separation between data binding and presentation. The CSS is embedded inline and changes require editing PowerShell code. The approach is functional but does not scale for future report complexity.

### K. `NhiControlledDecommission.psm1` — 5,915-line megafile (65 functions)

The largest single module in the codebase at nearly 6,000 lines and 65 exported functions. Functions follow a naming convention of `Invoke-NhiControlled*`, `Test-NhiControlled*`, `New-NhiControlled*`, `Get-NhiControlled*`, and `New-NhiRun4C*` — suggesting at minimum two logical subsystems (the controlled-decommission gate system and the Run4C lab-live rehearsal system) that have been lumped into one file.

The `#Requires` declaration is present on this file. Function names show duplication (`New-NhiControlledGateVerdict` appears on two separate lines — likely a paste error, not intentional overloading). The entire decommission pipeline — gate verdicts, metadata cleanup, metadata inventory, rollback plans, production readiness evidence, operator decision logs, final delete simulation, consultant handoff guides, and end-to-end lab rehearsal reports — lives in one file. Any change to one subsystem risks regressions in another.

---

## 2. The "Why" — Problem Summary

| Target | Smell | Impact |
|---|---|---|
| Discovery.psm1 (Premium) | SRP violation — 2,530 lines in 4 functions; `Invoke-DecomAssessmentDiscovery` orchestrating too much inline | Difficult to unit-test individual discovery sub-paths |
| NhiActivityLog analysis | Monolithic compute + score + timeline in one function | Cannot test risk scoring logic independently |
| NhiGraphApiAudit analysis | Same monolithic pattern as NhiActivityLog | Same |
| Pattern array duplication | Same arrays copy-pasted in two modules | Maintenance hazard; update one, forget the other |
| Evidence emission boilerplate | 8 confirmed modules (AccessRemoval, ComplianceRemediation, MailboxExtended, etc.) with identical two-step blocks | Drift over time; one caller will lose the evidence call |
| State.psm1 | Minified source (LiteModules excluded; check Premium equivalent) | Git diffs show no useful history; debugging requires reformatting first |
| Execution.psm1 circular import | Import at runtime vs. pass-as-dependency | Double-load risk; violates explicit dependency model |
| Guardrails export gap | Not in explicit Export-ModuleMember list | Relies on PowerShell auto-import fallback — fragile across sessions |
| Evidence.psm1 global state | Not thread-safe, no file locking | File corruption under concurrent writes |
| NHI constants drift | NhiReporting, EvidenceBundle, NhiGovernance define permission/scope arrays inline with no canonical source | Silent drift across NHI subsystem as arrays are updated independently |
| Reporting.psm1 HTML | Single here-string with inline CSS | Hard to modify report styling without touching PowerShell logic |
| NhiControlledDecommission.psm1 | 5,915 lines / 65 functions in one file; multiple subsystems co-located | Git history meaningless per-line; cross-subsystem regression risk; paste-duplicated function names |

---

## 3. Step-by-Step Plan

All phases follow Gate 1 (parse), Gate 2 (load), Gate 3 (Pester) verification after each phase. Any gate failure halts the phase and requires diagnosis before proceeding.

### Phase 0 — Baseline (mandatory, do first)

- Clone the repo locally to a clean branch named `refactor/...`
- Run `Invoke-Pester .\tests\ -Output Minimal` and record the canonical test count
- Confirm all tests pass before any change

### Phase 1 — Infrastructure fixes (lowest risk, highest confidence)

1. Expand `State.psm1` to one function per line with doc comments and `Export-ModuleMember` entries
2. Remove the on-load `Import-Module State.psm1` from `Execution.psm1`. Declare the dependency in module documentation and rely on the caller's load order
3. Add `New-DecomSkippedBecauseWhatIf` to `Export-ModuleMember` in Guardrails.psm1
4. Consolidate Auth.psm1: use `$script:RequiredGraphScopes` as the single source of truth inside `Connect-DecomGraph` (inline `$Scopes = $script:RequiredGraphScopes`)
5. Remove `#Requires -Version 5.1` from `NhiActivityLog.psm1` and `NhiGraphApiAudit.psm1` — target is pwsh 7+ only

### Phase 2 — Discovery.psm1 decomposition (high risk, high reward)

5. Extract `Get-DecomIdentitySnapshot` into private helper functions, one per data source:
   - `_Get-DecomGroupMembership`
   - `_Get-DecomRoleAssignments` (active + eligible, with PIM resolution)
   - `_Get-DecomOwnedObjects`
   - `_Get-DecomAppAssignments`
   - `_Get-DecomMailboxDelegation` (FullAccess, SendAs, SendOnBehalf, forwarding)
   - `_Get-DecomMfaMethods`
6. Each helper returns a `[hashtable]`. `Get-DecomIdentitySnapshot` composes them and becomes ~30 lines of orchestration
7. Freeze the public function signature of `Get-DecomIdentitySnapshot` — parameter names, parameter set, and return type must not change. The refactor must be invisible to callers
8. Write Pester tests for each `_Get-*` helper in isolation

### Phase 3 — NHI audit module decomposition (medium risk, incremental)

9. Create a new `NhiPatterns.psm1` module containing the shared pattern arrays. Update both `NhiActivityLog.psm1` and `NhiGraphApiAudit.psm1` to import it, removing the duplication
10. Break `Invoke-NhiAgentSignInAnalysis` into private helpers:
    - `_Compute-SignInBaseMetrics`
    - `_Detect-SignInBurst` (replace O(n²) rolling window with O(n log n) sorted-index approach)
    - `_Detect-ImpossibleTravel`
    - `Invoke-NhiAgentSignInAnalysis` becomes orchestrator only
11. Apply the same decomposition to `Invoke-NhiAgentDirectoryAuditAnalysis`
12. Refactor `New-NhiActivityAssessmentFinding` — convert hardcoded if/else cascades into a data-driven pattern using finding definitions as a hashtable/array constant. The function iterates over definitions rather than containing branching logic for each finding type
13. Apply the same data-driven refactor to `New-NhiGraphApiAuditFinding`
14. Write Pester tests for each new private helper

### Phase 4 — Evidence emission DRY (medium risk)

15. Introduce `New-DecomActionResultWithEvidence` in Evidence.psm1 that accepts all the same parameters as `New-DecomActionResult` plus a `[switch]$EmitEvidence` flag. When `$EmitEvidence` is set, it calls `Add-DecomEvidenceEvent` internally before returning. The switch defaults to `$false` for backward compatibility
16. Refactor all callers in AccessRemoval, ComplianceRemediation, MailboxExtended, DeviceRemediation, LicenseRemediation, AppOwnership, and AzureRBAC to use `New-DecomActionResultWithEvidence -EmitEvidence` instead of two separate calls
17. Add file locking to the NDJSON write path in `Add-DecomEvidenceEvent`: use `[System.IO.File]::Open` with exclusive write mode and `[System.IO.FileShare]::Read` for the read path

### Phase 5 — Reporting polish (low risk)

18. Extract the HTML template structure to named string constants in Reporting.psm1: `_HTML_HEADER`, `_CSS_BLOCK`, `_SUMMARY_CARD_ROW`, `_TABLE_HEADER`, `_TABLE_FOOTER`, `_HTML_FOOTER`. Keep the data-binding logic in `Export-DecomHtmlReport` but push the static HTML skeleton into named constants

### Phase 6 — NhiControlledDecommission split (highest risk effort)

19. Perform a full function-group analysis of NhiControlledDecommission.psm1's 65 exported functions. Categorize by subsystem: controlled-decommission gates, metadata cleanup, metadata inventory, rollback execution, production readiness evidence, operator decision logging, Run4C lab-live rehearsal, consultant handoff, end-to-end lab rehearsal reporting. Use the function naming convention as the primary signal
20. Extract each subsystem into its own module (e.g., `NhiGateVerdict.psm1`, `NhiMetadata.psm1`, `NhiRollback.psm1`, `NhiProductionReadiness.psm1`, `NhiRun4C.psm1`, `NhiConsultantHandoff.psm1`). Each new module must keep the `NhiControlled*` prefix preserved in all exported function names for backward compatibility
21. Verify no GitHub-frozen file (see CLAUDE.md FROZEN FILES section) is in the extraction set. Extract only to new files, never overwrite existing frozen modules
22. Fix the duplicated `New-NhiControlledGateVerdict` function name (paste error) — decide which implementation is authoritative and consolidate
23. Write Pester tests for each new subsystem module in isolation before reassembling

### Phase 7 — Verification (mandatory after every phase)

24. Gate 1: `pwsh -Command { [System.Management.Automation.Language.Parser]::ParseFile('<path>', [ref]$null, [ref]$errors); Write-Host "Parse errors: $($errors.Count)" }` on every modified file — must return 0
25. Gate 2: import/dot-source checks for every modified module — must be silent
26. Gate 3: `Invoke-Pester .\tests\ -Output Minimal` — must equal or exceed the Phase 0 canonical count (2,430 baseline)
27. `git diff --name-only` to confirm only intended files changed; frozen files remain untouched

---

## 4. Risk Assessment

### High risk

**Phase 2 (Discovery decomposition):** In Premium, `Invoke-DecomAssessmentDiscovery` and `Get-DecomSyntheticFindings` are called as part of the assessment discovery pipeline. The function signatures MUST NOT change — parameter names, types, and return object shapes must remain identical. Any refactor must freeze the public contract first. **Mitigation:** write a smoke test that passes a mock context through the existing function and asserts the return object's property names before touching any code.

**Phase 4 (Evidence DRY):** Changing every call site from `New-DecomActionResult` + `Add-DecomEvidenceEvent` to a single helper risks one caller forgetting the evidence call and going silent in the audit trail. **Mitigation:** introduce a `[switch]$EmitEvidence` parameter defaulting to `$false` on `New-DecomActionResult` so existing two-step calls are explicitly opted into the new pattern rather than broken by default. Verify Gate 3 catches any missing evidence call.

**Phase 6 (NhiControlledDecommission split):** This is the highest-risk refactor in the plan — 65 functions in 5,915 lines. Every function's implementation touches the rest of the file's `$script:` scope variables. Extracting into separate modules without a full variable-scope audit will break cross-function references. **Mitigation:** Before extracting anything, produce a full `$script:` variable dependency map. Extract subsystems one at a time, running Gate 3 after each extraction. Never delete lines from NhiControlledDecommission.psm1 — only comment-out after confirming the new module is loadable and tests pass.

### Medium risk

**Phase 3 (NHI decomposition):** The analysis functions (`Invoke-NhiAgentSignInAnalysis`, `Invoke-NhiAgentDirectoryAuditAnalysis`) are standalone NHI audit tools. Since they have no callers outside themselves, decomposing into private helpers is safe. However, `New-NhiActivityAssessmentFinding` and `New-NhiGraphApiAuditFinding` ARE the public API of these modules and may be called by external tooling. Their signatures must remain stable.

**Phase 1:** `#Requires -Version 5.1` removal must be verified with Gate 2: `pwsh -Command 'Import-Module ...'` on each updated NHI module. No silent version guard can block pwsh 7+ loading. The 5.1 declaration was actively incorrect — pwsh 7+ handles these modules correctly without it.

### Low risk

**Phase 1** (State expansion, Guardrails export, Auth/scope consolidation, `#Requires` cleanup) and **Phase 5** (Reporting string constants) are purely mechanical refactors with no behavioral change.

### Edge cases

- PowerShell module auto-import: Guardrails functions currently work via auto-import fallback. After Phase 1 (explicit export), this will be more robust — but verify that all callers import Guardrails explicitly and are not relying on auto-import
- Evidence file locking: `[System.IO.File]::Open` with exclusive write requires careful handling of the open/close cycle. The in-memory `$Context.Evidence` list is safe; the NDJSON file write is the concern. Test on a system that can simulate concurrent calls
- Phase 1 (`#Requires -Version 5.1` removal) must be verified with Gate 2: `pwsh -Command 'Import-Module ...'` on each updated NHI module — no version guard can silently block pwsh 7+ loading
- Phase 4 file locking on Windows: `[System.IO.File]::Open` exclusive write may conflict with antivirus file system watchers. Test on a machine with real-time AV scanning active
- Phase 6 (NhiControlledDecommission split): `$script:` variable scope. Before extracting any subsystem, produce a full variable-scope dependency map to avoid silent cross-module reference failures. The 65-function file has likely accumulated module-level state — extraction must account for it

---

*Generated from codebase analysis — do not begin implementation until approved*