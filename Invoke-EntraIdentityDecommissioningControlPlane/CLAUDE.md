# CLAUDE.md — Entra Identity Decommissioning Control Plane
# Albert Jee | Architect-Level Baseline
# Rev1.3 — Rev4.0 NHI Execution Foundation

---

## 1. Who I Am and What I Expect

I am an architect-level technical practitioner. I hold myself and my tools to explicit standards:
**precision, transparency, and integrity** in both technical output and communication.

- Never declare success without verified, reproducible outcomes
- Never claim integration without showing it
- Never backtrack after confirming — flag deviations immediately, not after being pressed
- Evasion, even once, is a serious trust breach
- "Steam ON" means full-speed execution without hedging or qualification

---

## 2. Mandatory Verification Gates

**Every file modification requires all three gates before declaring done. No exceptions.**

**All gates must use `pwsh` (PowerShell 7+). `powershell.exe` (Windows PowerShell 5.1) is not supported.**

### Gate 1 — Syntax / Parse

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    '<path-to-file>', [ref]$null, [ref]$errors)
Write-Host "Parse errors: $($errors.Count)"
# Must be 0
```

### Gate 2 — Load / Import

```powershell
. '<path-to-script>.ps1'
Write-Host "Dot-source: OK"
```

```powershell
Remove-Module <ModuleName> -Force -ErrorAction SilentlyContinue
Import-Module '<path-to-psm1>' -Force -DisableNameChecking
Write-Host "Module import: OK"
```

### Gate 3 — Test Runner

```powershell
Invoke-Pester -Path @('<test-paths>') -Output Detailed
# Must show 0 failures — count must meet or exceed prior baseline
```

**Rule:** If Gate 1 or Gate 2 emits errors or warnings, STOP. Do not run Gate 3. Fix first.

---

## 3. Version Control Discipline

- **Never overwrite existing files** — always increment version numbers
- **Never reuse script or module filenames** — new version = new filename
- **Never push to remote** without explicit instruction from Albert
- Commit messages must be specific: `fix: Rev1.x -- <what changed>, <N> tests passing`

---

## 4. Communication Standards

- **No hedging on status** — "done" means all three gates passed
- **No assumed success** — "it should work" is not a status report
- **Flag deviations immediately** — if you did something differently than instructed, say so in the same message
- **Escalate blockers immediately** — do not silently loop on a failing approach

---

## 5. Sequencing Discipline

- External review → test environment → live execution. Never skip a step.
- Test environment first — never run new code against a live tenant without a passing test run.
- Build order: design → implement → verify (Gate 1 + 2) → test (Gate 3) → commit

---

## 6. PROJECT CONTEXT

**Project name:** Entra Identity Decommissioning Control Plane
**Repo:** `C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane`
**Primary language:** PowerShell 7+
**Current revision:** Rev4.1
**Push policy:** Albert pushes manually

---

## 7. FROZEN FILES — DO NOT MODIFY UNDER ANY CIRCUMSTANCES

The following files and directories are **production-locked**. All Rev1.x work is purely additive.
Claude Code must never read-to-modify, str_replace, rewrite, or delete any of these:

```
src/Start-Decom.ps1
src/Start-DecomBatch.ps1
src/Invoke-DecomWorkflow.ps1
src/LiteModules/          (entire directory — all 14 .psm1 files)
src/Modules/AccessRemoval.psm1
src/Modules/AppOwnership.psm1
src/Modules/AzureRBAC.psm1
src/Modules/BatchApproval.psm1
src/Modules/BatchContext.psm1
src/Modules/BatchDiff.psm1
src/Modules/BatchOrchestrator.psm1
src/Modules/BatchOrchestratorParallel.psm1
src/Modules/BatchPolicy.psm1
src/Modules/BatchReporting.psm1
src/Modules/BatchState.psm1
src/Modules/ComplianceRemediation.psm1
src/Modules/DeviceRemediation.psm1
src/Modules/LicenseRemediation.psm1
src/Modules/MailboxExtended.psm1
tests/Decom.Tests.ps1
tests/DecomBatch.Tests.ps1
tests/DecomBatchReporting.Tests.ps1
tests/DecomCoverageGap.Tests.ps1
tests/DecomPremiumRemediation.Tests.ps1
tests/DecomV21.Tests.ps1
docs/architecture.md
docs/compliance-model.md
docs/evidence-model.md
docs/permissions.md
docs/production-runbook.md
docs/red-team-scenarios-v1.5.md
docs/release-notes-v1.0.md
docs/runbook.md
docs/security-posture-v1.5.md
docs/threat-model-v1.5.md
docs/validation-guide.md
examples/sample-report.schema.json
SECURITY.md
LICENSE
```

---

## 8. REV1.x MODULE PATHS — CRITICAL

**All Rev1.x new modules use capital M: `src/Modules/`**
Do NOT write to `src/modules/` (lowercase m) — that path does not exist on Windows and will cause GitHub casing issues.

```
Invoke-EntraIdentityDecommissioningControlPlane.ps1   ← entry point (repo root of the tool)
src/Modules/Discovery.psm1      ← Rev1.x assessment discovery
src/Modules/Analysis.psm1       ← Rev1.x scoring engine
src/Modules/Reporting.psm1      ← Rev1.x HTML + export functions
src/Modules/RemediationPlan.psm1← Rev1.x remediation plan generator
src/Modules/Utilities.psm1      ← Rev1.x console helpers + finding factory
tests/Rev11/Safety.Tests.ps1
tests/Rev11/Analysis.Tests.ps1
tests/Rev11/Reporting.Tests.ps1
docs/Consultant-Runbook.md
docs/Required-Permissions.md
docs/Findings-Catalog.md
samples/
CHANGELOG.md                    ← APPEND only — never rewrite history
```

---

## 9. Canonical Test Count

- **Rev3.11 baseline:** 1320 tests (Rev3.110 baseline)
- **Rev4.0 test count:** 1456 total tests, 1455 passing, 1 pre-existing HtmlEncoding cross-test contamination failure accepted
  - 131 new tests (M31–M36 across NhiExecutionSchema, NhiExecution, DestructiveCmdletGuard)
  - Pre-existing Rev11 + Rev36 tests: 66 tests
  - Pre-existing Rev3.x tests: remainder
  - 1455 + 1 = 1456 total
- **Rev4.1 test count:** 1498 total tests, 1498 passing, 0 failed
  - 41 new tests (NhiActivityAudit.Rev41.Tests.ps1, M1-M6 activity audit modules)
  - HtmlEncoding cross-test contamination failure resolved during Rev4.1 fix cycles
- **Rev4.1 test count (2026-07-09):** 2427 total tests, 2427 passing, 0 failed
  - NhiExecutionGuard extraction branch `refactor/nhi-execution-guard` (PR #24)
  - 15 new tests in NhiExecutionGuard.Rev41.Tests.ps1
  - Fixes: ReleaseValidation.Rev33 false positives (NhiExecutionGuard.psm1 data exclusion),
    NhiExecution.Rev40 guard test (updated to test modular architecture)
- **Rev4.2 test count (2026-07-09):** 2441 total tests, 2441 passing, 0 failed
  - NhiScopeCatalog consolidation branch `refactor/nhi-consts` (refactoring-plan target I)
  - 14 new tests in NhiScopeCatalog.Rev42.Tests.ps1
  - ReleaseValidation.Rev33 Policy.ReadWrite exclusion updated (adds NhiScopeCatalog.psm1,
    drops NhiDiscovery.psm1/NhiPermission.psm1 - net tightening)
- **Rev4.2 I-b test count (2026-07-09):** 2452 total tests, 2452 passing, 0 failed
  - NhiGovernance data-driven refactor, branch `refactor/nhi-governance-datadriven`
  - 11 new tests in NhiGovernanceDataDriven.Rev42.Tests.ps1
  - NhiGovernance.psm1: 548 -> 305 lines, 13 -> 2 New-DecomFinding call sites
  - Note: PR #27 (NhiAnalysis fix, +7 tests) merges independently; after both: 2459
- **Current baseline (2026-07-05, after all entry-point decomposition milestones):**
  2412 total tests, 2412 passing, 0 failed (main `94ebd16`, PR #23). Pre-refactor baseline
  was 2408 (`89135d3`, PR #19). Entry-point decomposition (PR #22) added 5 new closed-set
  safety tests in M8; no test count regressions. Full milestone history:
  `docs/entrypoint-decomposition-plan.md` section 4.
- **Gate 3 command:**
  ```powershell
  Invoke-Pester -Path .\tests\ -Output Minimal
  ```
- Must show 0 failures, >= 2452 tests passing.

---

## 10. OUTPUT QUALITY BAR

| Check | Standard |
|---|---|
| Syntax | 0 parse errors on every new .ps1 and .psm1 |
| Load | Silent import, no warnings on all new modules |
| Tests | 0 failures, ≥ 2441 tests passing |
| Git | Only files explicitly authorized in the task allowlist may appear in git diff; frozen files untouched |
| Demo mode | `.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode` runs clean, exports all 5 outputs, HTML opens in browser |

If any row fails — it is not done.

---

## 11. Utilities Module Import Rule

Any new module that calls `Write-DecomWarn`, `Write-DecomLog`, or any `Write-Decom*` function must import `Utilities.psm1` using this pattern:

```powershell
Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking
```

**Critical:** Never substitute `Write-Warning` as a fallback — it breaks output consistency with the rest of the assessment engine. If Utilities is not available, fail with an explicit error.

This ensures all Write-Decom* functions are available when modules are imported independently (e.g., during testing) or loaded by the entry point.

---

## 12. UTF-8 Encoding Standard

**All PowerShell files must use UTF-8 without BOM (Byte Order Mark).** PowerShell 7+ (`pwsh`) reads UTF-8 without BOM natively. Do NOT add a BOM — the UTF-8 signature is not required and causes issues with some tools.

When writing files programmatically, use `[System.IO.File]::WriteAllText()` with explicit UTF-8 encoding:
```powershell
[System.IO.File]::WriteAllText('<path>', $content, [System.Text.UTF8Encoding]::new($false))
```

Or for line arrays:
```powershell
[System.IO.File]::WriteAllLines('<path>', $lines, [System.Text.UTF8Encoding]::new($false))
```

Remove any legacy Windows PowerShell 5.1 BOM requirements from generated files.

---

## 13. Rev3.7 Source Integrity Rules

**No corrupt Unicode or mojibake in executable source.** Do not introduce these characters in any .ps1, .psm1, or .psd1 file:

```text
U+FFFD  replacement character
U+2010–U+2015  Unicode dash characters (em dash, en dash, hyphen, etc.)
U+2212  mathematical minus sign
U+00A0  non-breaking space
U+2018, U+2019, U+201C, U+201D  smart quotes
UTF-8 mojibake byte sequences: 0xC3 0xA2 0xC2 0x80 0xC2 0x94 (em dash artifact)
                               0xC3 0xA2 0xC2 0x80 0xC2 0x93 (en dash artifact)
```

Use plain ASCII hyphens (-), normal ASCII quotation marks ("), and standard ASCII spaces only. Do NOT place em dashes, en dashes, or non-ASCII characters inside inline catch block comments — this breaks module loading under pwsh:

```powershell
# WRONG - em dash in catch comment breaks module loading
} catch { $null = $null # Silenced: failure treated – as absent }

# CORRECT - plain ASCII hyphen only or no comment
} catch { $null = $null }
} catch { $null = $null # Silenced: failure treated - as absent }
```

**Preserve CRLF line endings.** All source files (.ps1, .psm1, .psd1) use CRLF (Windows line endings). Do not convert to LF.

**Gate 1 validation rule.** Gate 1 parse checks must use inline `pwsh -Command`, never `pwsh -File`. File-based parsing produces false errors in this repo.

```powershell
# CORRECT
pwsh -Command { [System.Management.Automation.Language.Parser]::ParseFile(...) }

# WRONG - do not use
pwsh -File .\parse-check.ps1
```

---

## 14. Final Validation Standards

**All verification output must be raw command output, not Claude Code summaries.**

When reporting Gate results:
- Show the exact output from `Invoke-Pester` (Tests Passed/Failed line verbatim)
- Show exact `git diff --name-only` output for each milestone
- Show exact parse error output if any
- Never report "Tests should pass" or "Probably working" — only verified outcomes

Before completing any milestone:
```powershell
git diff --name-only
git status --short
```

Report these outputs verbatim. Do not summarize them.

---

## Agent skills

### Issue tracker

GitHub Issues. External PRs are NOT a request surface — triage focuses on issues only. See `docs/agents/issue-tracker.md`.

### Triage labels

Defaults: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context. Skills look at `CONTEXT.md` (if present) and `docs/adr/` (if present) at the repo root. See `docs/agents/domain.md`.
