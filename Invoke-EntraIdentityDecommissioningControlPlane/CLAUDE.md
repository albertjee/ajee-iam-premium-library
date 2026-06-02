# CLAUDE.md — Entra Identity Decommissioning Control Plane
# Albert Jee | Architect-Level Baseline
# Rev1.3 — Application Ownership Drift Detection

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

**Project name:** Entra Identity Decommissioning Control Plane — Rev1.3 Application Ownership Drift
**Repo:** `C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane`
**Primary language:** PowerShell 5.1+
**Current revision:** Rev1.3
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

- **Rev1.3 current baseline:** 35 tests across Safety, Analysis, and Reporting suites
- **Gate 3 command:**
  ```powershell
  Invoke-Pester -Path .\tests\ -Output Detailed
  ```
- Must show 0 failures — 35 passing is the current baseline. Any new rev must meet or exceed this.

---

## 10. OUTPUT QUALITY BAR

| Check | Standard |
|---|---|
| Syntax | 0 parse errors on every new .ps1 and .psm1 |
| Load | Silent import, no warnings on all new modules |
| Tests | 0 failures, ≥ 35 tests passing |
| Git | Only Rev1.x new files in diff — frozen files untouched |
| Demo mode | `.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode` runs clean, exports all 5 outputs, HTML opens in browser |

If any row fails — it is not done.
