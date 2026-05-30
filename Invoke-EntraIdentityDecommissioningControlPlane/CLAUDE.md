# CLAUDE.md — Entra Identity Decommissioning Control Plane
# Albert Jee | Architect-Level Baseline
# Rev1.1 — Consultant Readiness Build

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
- Commit messages must be specific: `fix: Rev1.1 -- <what changed>, <N> tests passing`

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

**Project name:** Entra Identity Decommissioning Control Plane — Rev1.1 Consultant Readiness  
**Repo:** `C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane`  
**Primary language:** PowerShell 5.1+  
**Current revision:** Rev1.2  
**Push policy:** Albert pushes manually

---

## 7. FROZEN FILES — DO NOT MODIFY UNDER ANY CIRCUMSTANCES

The following files and directories are **production-locked**. Rev1.1 is purely additive.
Claude Code must never read-to-modify, str_replace, rewrite, or delete any of these:

```
src/Start-Decom.ps1
src/Start-DecomBatch.ps1
src/Invoke-DecomWorkflow.ps1
src/LiteModules/          (entire directory — all 14 .psm1 files)
src/Modules/              (entire directory — all 15 Premium .psm1 files)
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

## 8. NEW FILES — Rev1.1 Additive Scope Only

Claude Code writes ONLY these new files:

```
Invoke-EntraIdentityDecommissioningControlPlane.ps1   ← new entry point (repo root of the tool)
src/modules/Discovery.psm1
src/modules/Analysis.psm1
src/modules/Reporting.psm1
src/modules/RemediationPlan.psm1
src/modules/Utilities.psm1
tests/Rev11/Safety.Tests.ps1
tests/Rev11/Analysis.Tests.ps1
tests/Rev11/Reporting.Tests.ps1
docs/Consultant-Runbook.md
docs/Required-Permissions.md
docs/Findings-Catalog.md
samples/sample-findings.csv
samples/sample-findings.json
samples/sample-report.html
samples/sample-remediation-plan.md
CHANGELOG.md                                          ← APPEND Rev1.1 entry only — do not rewrite history
```

**Note on CHANGELOG.md:** It already exists with v1.0–v1.5a history. Claude Code must APPEND the Rev1.1 block at the top. It must not rewrite or delete existing entries.

---

## 9. Canonical Test Count

- **Baseline before Rev1.1:** 0 Rev1.1 tests (existing Pester suites are frozen and untouched)
- **Rev1.2 target:** 28 tests across Safety, Analysis, and Reporting suites
- **Gate 3 command:**
  ```powershell
  Invoke-Pester -Path .\tests\Rev11\ -Output Detailed
  ```
- Must show 0 failures before Rev1.1 is declared done

---

## 10. OUTPUT QUALITY BAR

| Check | Standard |
|---|---|
| Syntax | 0 parse errors on every new .ps1 and .psm1 |
| Load | Silent import, no warnings on all new modules |
| Tests | 0 failures, 28 tests passing |
| Git | Only Rev1.1 new files in diff — frozen files untouched |
| Demo mode | `.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode` runs clean, exports all 4 outputs, HTML opens in browser |

If any row fails — it is not done.
