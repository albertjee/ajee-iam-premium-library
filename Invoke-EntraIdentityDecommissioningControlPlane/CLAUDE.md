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
**Current revision:** Rev3.11
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

- **Rev3.10 current baseline:** 1291 tests across all Rev3 modules (includes M26–M29 NHI full parity: NhiOwner, NhiPublisher, NhiAgent modules; 51 new tests added)
- **Rev3.11 test count:** 1320 tests (1291 baseline + 29 wrapper tests)
- **Gate 3 command:**
  ```powershell
  Invoke-Pester -Path .\tests\ -Output Detailed
  ```
- Must show 0 failures — 1320 passing is the current baseline. Any new rev must meet or exceed this.

---

## 10. OUTPUT QUALITY BAR

| Check | Standard |
|---|---|
| Syntax | 0 parse errors on every new .ps1 and .psm1 |
| Load | Silent import, no warnings on all new modules |
| Tests | 0 failures, ≥ 1320 tests passing |
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
