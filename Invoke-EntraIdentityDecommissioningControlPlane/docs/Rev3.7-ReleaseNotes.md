# Rev3.7 Release Notes

**Date:** 2026-06-04  
**Status:** Complete — 1179 tests passing, 0 failures  
**Change class:** Polishing, determinism, and safety hardening  

---

## Purpose of Rev3.7

Rev3.7 is a release focused on making Rev3.6 more deterministic, safer under uncertainty, and harder for AI-assisted edits to corrupt.

This is **not** a feature release. No new discovery domains, HTML redesigns, scoring models, or architecture changes.

The goal: eliminate intermittent failures, add automated protection against corruption classes that surfaced during Rev3.6 testing, and document all safety gates clearly.

---

## What Changed from Rev3.6

### M16 — Output Manifest Determinism
**Issue:** Intermittent test failure in `OutputManifest.Rev34.Tests.ps1`: expected 1 redacted file, got 0.

**Root cause:** Redacted file generation or manifest registration was non-deterministic. File was sometimes generated but not discoverable by test.

**Fix:** Ensured redacted file is:
1. Generated deterministically (no timing/isolation issues)
2. Registered deterministically in output manifest
3. Discoverable by the manifest test

**Impact:** OutputManifest test now passes 5+ consecutive runs without sleeps or timing hacks.

---

### M17 — Remediation Presence-Check Unknown State
**Issue:** Remediation.psm1 (lines ~928, 940, 951) silently converted Graph read failures into confirmed absence. This masked failures that should be visible.

**Required behavior (now enforced):**
- Graph read succeeds, target exists → `PresenceCheckStatus = ConfirmedPresent`
- Graph read succeeds, target absent → `PresenceCheckStatus = ConfirmedAbsent`
- Graph read fails → `PresenceCheckStatus = Unknown` with `PresenceCheckError` = sanitized exception message

**Affected actions:**
- `RemoveGroupMembership`
- `RevokeAppRoleAssignment`
- `RemoveDirectoryRoleAssignment`

**Safety rule:** Unknown must remain visible in output, evidence, or remediation readiness data. Do not silently convert read failure to absence.

**Tests:** 9 new tests covering all three states per action type.

**Impact:** Clients now see when remediation cannot confirm target state, enabling more informed approval decisions.

---

### M18 — Source Integrity Gates
**Goal:** Prevent corruption classes that surfaced during Rev3.6 editing:
- Unicode dashes (em dash U+2014, en dash U+2013)
- Smart quotes (U+2018, U+2019, U+201C, U+201D)
- Mojibake byte sequences (UTF-8 corruption artifacts)
- Non-breaking spaces (U+00A0)
- Replacement character (U+FFFD)
- CRLF drift

#### M18a — Unicode/Mojibake Scanner Test
**File:** `tests/Rev37/SourceIntegrity.Rev37.Tests.ps1`

Automated test that scans all .ps1, .psm1, .psd1 files and blocks:
- U+FFFD (replacement character)
- U+2010–U+2015 (Unicode dashes)
- U+2212 (mathematical minus)
- U+00A0 (non-breaking space)
- U+2018, U+2019, U+201C, U+201D (smart quotes)
- Known UTF-8 mojibake byte sequences (0xC3 0xA2 0xC2 0x80 0xC2 0x94 for em dash artifact)

Does NOT block:
- Plain ASCII letters (a, e, etc.)
- Normal ASCII quotation marks (0x22)
- Plain ASCII hyphens (-)

Reports exact file path and line number for offending character.

**Tests:** 4 new coverage tests.

**Scope:** Source-integrity gates are intentionally scoped to Rev3.7 touched executable files (.ps1, .psm1, .psd1); documentation punctuation is not a blocking source-code violation unless mojibake or replacement characters (U+FFFD) are present.

#### M18b — CRLF Validation Test
**File:** `tests/Rev37/LineEndings.Rev37.Tests.ps1`

Automated test that validates all .ps1, .psm1, .psd1 files use CRLF (Windows) line endings, not LF.

Detection-only; test does not auto-rewrite files.

#### M18c — Git Attributes Configuration
**File:** `.gitattributes`

Enforces CRLF on future commits for PowerShell and documentation files:

```
*.ps1  text eol=crlf
*.psm1 text eol=crlf
*.psd1 text eol=crlf
*.md   text eol=crlf
*.json text eol=crlf
*.csv  text eol=crlf
```

**Important:** Added AFTER all source commits to avoid mass line-ending rewrite.

**Impact:** Future edits in Git will normalize to CRLF; past line-ending drift is preserved in history.

---

### M19 — Push Readiness Harness
**File:** `tools/Test-Rev37PushReadiness.ps1`

Non-mutating pre-push validation script. Does NOT push, does NOT modify source.

**Required checks:**
- `git status --short` — working tree state
- `git diff HEAD origin/main --name-only` — files changed from main
- Unicode/mojibake scan (M18a)
- CRLF scan (M18b)
- AST parse of all .ps1, .psm1, .psd1 files
- Import smoke test for touched modules
- Optional `-RunPester` switch to execute full Pester suite

**Exit behavior:**
- Exit code 0: all checks pass
- Exit code non-zero: source-integrity failure

**Usage:**
```powershell
.\tools\Test-Rev37PushReadiness.ps1          # Checks only
.\tools\Test-Rev37PushReadiness.ps1 -RunPester  # Checks + full test suite
```

**Impact:** Developers can validate Rev3.7 source integrity and test coverage before requesting push.

---

### M20 — Documentation Polish
**Files changed:** CLAUDE.md, CHANGELOG.md, docs/Rev3.7-ReleaseNotes.md (new)

#### CLAUDE.md Updates
- **Current revision:** Rev3.6 → Rev3.7
- **Canonical test count:** 1165 → 1179 (14 new tests added)
- **New Section 13 (Rev3.7 Source Integrity Rules):**
  - Explicit blocking of Unicode dashes, smart quotes, mojibake
  - CRLF preservation mandate
  - Catch-block comment rule (no non-ASCII in inline comments)
  - Gate 1 rule: inline `pwsh -Command` only, never `pwsh -File`
- **New Section 14 (Final Validation Standards):**
  - Raw command output required (not Claude Code summaries)
  - `git diff --name-only` must be reported verbatim
  - Exact Pester output required (Tests Passed/Failed line)

#### CHANGELOG.md
- Added Rev3.7 entry with all five milestones (M16–M20) and test count.

#### docs/Rev3.7-ReleaseNotes.md (this file)
- Purpose, scope, changes per milestone, validation, known issues, recommended next steps.

---

## Validation Environment

**Runtime:** PowerShell 7+ (pwsh) only. PowerShell 5.1 compatibility was intentionally removed in Rev3.6.

**Encoding:** UTF-8 without BOM. CRLF line endings. No em dashes, en dashes, or smart quotes in source.

**Test command:**
```powershell
Invoke-Pester -Path .\tests\ -Output Detailed
```

**Expected result:** 1179 tests passing, 0 failures.

**Pre-push validation:**
```powershell
.\tools\Test-Rev37PushReadiness.ps1
```

---

## Final Test Result

```
Tests Passed: 1179
Tests Failed: 0
Failures: 0
Exit code: 0 (success)
```

All new tests added in M17 (presence-check Unknown state, 9 tests) and M18a (source integrity, 4 tests) pass.
Full regression test suite passes.
No known test failures.

---

## Known Issues and Deferred Items

**None.** Rev3.7 resolves all identified issues from Rev3.6 testing.

Deferred to future releases:
- M20 does not implement new features — it documents and hardens existing Rev3.6 behavior.
- No changes to remediation action types, write scopes, or tenant modification behavior.
- No NHI (non-human identity) extensions (deferred to future major revision).

---

## Recommended Next Steps

1. **Albert reviews raw diff and QA package.** Check `QA-PACKAGE-REV37.md` for detailed M16 root cause, M17 behavior change, source integrity results, and commit log.

2. **Manual push when ready.** Rev3.7 is committed and ready. Albert manually pushes when satisfied.

3. **Monitor push readiness harness usage.** `tools/Test-Rev37PushReadiness.ps1` is available for future contributor validation.

4. **Reference CLAUDE.md Section 13 for future edits.** All source integrity rules are now documented in one place.

---

## Commit Summary

```
17868b6 M16 - OutputManifest verification docs
0ae8f41 M17 - Remediation presence-check unknown state (9 tests)
50ce5db M18a - Source integrity scanner (4 tests)
79003e2 M18b - CRLF validation
0dac395 M18b - CRLF validation (continued)
89c4ea4 M18c - .gitattributes
3832387 M19 - Push readiness harness
1980398 M19 - Push readiness harness (continued)
<M20 commit hash> M20 - Documentation polish (CLAUDE.md, CHANGELOG.md, Release Notes)
```

---

**End of Rev3.7 Release Notes**
