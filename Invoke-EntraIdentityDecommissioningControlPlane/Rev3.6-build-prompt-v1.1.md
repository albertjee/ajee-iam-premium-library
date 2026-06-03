# Rev3.6 Claude Code Build Prompt v1.1
# Entra Identity Decommissioning Control Plane
# Post-Release Cleanup, Version Hygiene, and Evidence Consistency

STATUS: PROPOSED IMPLEMENTATION PROMPT — CLEANUP / POLISH RELEASE

Rev3.6 is a post-cleanup release after the approved Rev3.5 NHI / Agentic Identity Audit and Governance Expansion.

Rev3.6 should be boring by design.

Rev3.6 must not add new tenant write behavior.
Rev3.6 must not add new write scopes.
Rev3.6 must not add new remediation action types.
Rev3.6 must not add new NHI detector families.
Rev3.6 must not change scoring semantics except where explicitly listed as cleanup/hardening.
Rev3.6 must focus on version hygiene, test maintainability, output consistency, evidence-chain cleanup, NHI pipeline de-duplication, PS5.1 hygiene, and release polish.

Recommended release title:

```text
Rev3.6 — Post-Release Cleanup, Version Hygiene, and Evidence Consistency
```

---

## 0. Baseline

Repository:

```text
https://github.com/albertjee/ajee-iam-premium-library
```

Tool location:

```text
Invoke-EntraIdentityDecommissioningControlPlane/
```

Expected Rev3.5 baseline:

```text
ToolVersion = Rev3.5
SchemaVersion = 3.5
Pester tests >= 1073
0 failures
Rev3.5 final QA PASS confirmed (commit e5aa388, 1073/1073 tests). All prerequisites met. Proceed directly to Milestone 1.
No open P0/P1 findings
No new write scopes
No new remediation action types
NHI pipeline read-only
DEC-NHI / DEC-AGENT findings merged into main Findings array
Summary recalculated after NHI merge
NHI reporting uses Entra-visible / heuristic language
```

Rev3.6 target:

```text
ToolVersion = Rev3.6
SchemaVersion = 3.6 for current outputs
Pester tests target >= 1125
Stretch target >= 1150
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
Safety scan clean
No new write scopes
No new remediation action types
No new tenant modifications
No hardcoded stale current-version strings in tests
No duplicated NHI discovery/analysis/governance execution
No PS7-only syntax
No silent catch blocks in critical packaging paths
No evidence bundle self-recursion
No redaction self-recursion
```

---

## 0.6 AUTONOMOUS EXECUTION INSTRUCTIONS

Do NOT stop between milestones to ask Albert for confirmation.
Do NOT pause and ask "shall I proceed?" or "ready for go-ahead?" at any milestone boundary.
Do NOT ask Albert to say yes at any step.
Proceed through ALL milestones (1 through 15) autonomously.

Only stop and report back to Albert if:
1. A gate FAILS (parse error, import error, test failure, safety scan violation)
2. A new write scope or write cmdlet is detected
3. A new remediation action type is added
4. A historical version test is blindly replaced without INTENTIONAL_HISTORICAL_VERSION marker
5. The Final Stop Rule triggers

If all gates pass at each milestone — proceed immediately to the next.
After each milestone commit, update CLAUDE.md canonical test count.
Update CHANGELOG.md at Milestone 11 (documentation cleanup).
Report final gate summary table only when ALL milestones are complete.
Do not push. Albert pushes manually.

---

## 1. Rev3.6 Release Goals

Rev3.6 should clean up debt created during the rapid Rev3.x build-out.

Primary goals:

```text
1. Remove hardcoded version strings from tests where practical.
2. Centralize version/schema expectations for tests.
3. Scan and fix stale Rev3.3 / Rev3.4 / Rev3.5 / 3.4 / 3.5 assertions where they should track current version.
4. Consolidate NHI pipeline execution into one cached flow.
5. Prevent NHI discovery/analysis/governance from running twice in one execution.
6. Ensure NHI reporting, standard exports, OutputManifest, EvidenceBundle, Redaction, ClientHandoff, and Traceability all use the same NHI evidence set.
7. Tighten evidence bundle recursion and output manifest self-indexing behavior.
8. Tighten redaction recursion and prevent redacting already-redacted files.
9. Preserve PS5.1 compatibility across all Rev3.x modules.
10. Replace silent catch blocks in hardening/reporting paths with warning capture.
11. Normalize coverage limitation de-duplication.
12. Reduce misleading risk-understated flags where zero risk is not the same as missing evidence.
13. Add cleanup tests so future releases do not reintroduce version drift.
```

---

## 2. Explicit Non-Goals

Rev3.6 must not implement:

```text
No new Graph write scopes.
No new write cmdlets.
No new remediation action types.
No new detector families.
No new DEC-NHI or DEC-AGENT IDs unless explicitly required by existing docs correction.
No app/service principal/user/guest/group deletion.
No CA policy mutation.
No Policy.ReadWrite.*.
No AccessReview.ReadWrite.*.
No rollback execution.
No bulk execution orchestration.
No Rev4 write actions.
```

If implementation attempts any of the above:

```text
STOP.
Fail the build.
Ask Albert.
```

---

## 3. Priority Cleanup Item — Version Hygiene in Tests

### 3.1 Problem

Some tests and expected-output assertions hardcode historical version strings such as:

```text
Rev3.3
Rev3.4
Rev3.5
2.4
3.4
3.5
```

This creates test maintenance churn every release.

Example discovery command:

```powershell
Select-String -Path .\tests\Rev11\*.ps1 -Pattern "Rev3\.3|Rev3\.4|Rev3\.5|2\.4|3\.4|3\.5" |
    Select-Object Path, LineNumber, Line
```

The goal is not to blindly replace every historical reference. The goal is to separate:

```text
1. Current-version expectations that should track ToolVersion / SchemaVersion.
2. Historical compatibility tests that should intentionally remain pinned.
3. Changelog/doc text where old versions are expected.
```

### 3.2 Required implementation

Create a test helper, for example:

```text
tests/Rev11/TestVersionContext.ps1
```

Suggested content:

```powershell
function Get-DecomExpectedToolVersion {
    return 'Rev3.6'
}

function Get-DecomExpectedSchemaVersion {
    return '3.6'
}

function Get-DecomExpectedMajorMinor {
    return '3.6'
}
```

Then update tests so current-version assertions use:

```powershell
$ExpectedToolVersion = Get-DecomExpectedToolVersion
$ExpectedSchemaVersion = Get-DecomExpectedSchemaVersion
```

Preferred assertion style:

```powershell
$report.ToolVersion | Should -Be (Get-DecomExpectedToolVersion)
$manifest.SchemaVersion | Should -Be (Get-DecomExpectedSchemaVersion)
```

### 3.3 Historical tests

If a test intentionally validates old manifest rejection, preserve the old version string but label it clearly:

```powershell
# INTENTIONAL_HISTORICAL_VERSION — validates legacy manifest rejection.
$legacySchemaVersion = '3.2'
```

### 3.4 Version drift scanner

Add:

```text
VersionHygiene.Rev36.Tests.ps1
```

It should:

```text
1. Scan tests for current-version hardcoding.
2. Allow explicitly tagged historical constants.
3. Fail if stale current-version strings appear without intentional marker.
4. Verify ToolVersion = Rev3.6 in the entry point.
5. Verify current output schemas use 3.6.
```

Allowlist marker:

```text
INTENTIONAL_HISTORICAL_VERSION
```

---

## 4. NHI Pipeline De-Duplication

### 4.1 Problem

Rev3.5 introduced a working NHI pipeline before standard exports:

```text
Invoke-DecomNhiDiscovery
Invoke-DecomNhiAnalysis
Invoke-DecomNhiGovernance
Append NHI findings to $Findings
Recalculate summary
```

Later hardening/reporting sections may also generate NHI reporting outputs. Rev3.6 should ensure those later sections reuse the same cached NHI objects and findings instead of running discovery/analysis/governance again.

### 4.2 Required implementation

At the top of the normal assessment pipeline, initialize:

```powershell
$NhiInventory = @()
$NhiAnalyzed = @()
$NhiGovernanceFindings = @()
$NhiPipelineRan = $false
```

When NHI is enabled:

```powershell
if ($GenerateNhiGovernancePack -or $DemoMode) {
    $NhiInventory = Invoke-DecomNhiDiscovery -Context $Context -DemoMode:$DemoMode
    $NhiAnalyzed = Invoke-DecomNhiAnalysis -NhiObjects $NhiInventory -Context $Context
    $NhiGovernanceFindings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects $NhiAnalyzed -Context $Context
    $Findings = @($Findings) + @($NhiGovernanceFindings)
    $Summary = Get-DecomFindingSummary -Findings $Findings
    $NhiPipelineRan = $true
}
```

Later, NHI reporting must use:

```powershell
if ($GenerateNhiGovernancePack) {
    if (-not $NhiPipelineRan) {
        Write-DecomWarn "NHI reporting requested but NHI pipeline did not run; generating empty NHI pack with coverage warning."
    }

    Invoke-DecomNhiReporting `
        -NhiInventory $NhiAnalyzed `
        -NhiGovernanceFindings $NhiGovernanceFindings `
        -Context $Context
}
```

Do not re-run discovery/analysis/governance unless explicitly forced by a future parameter.

### 4.3 Required tests

```text
1. GenerateNhiGovernancePack invokes NhiDiscovery exactly once.
2. GenerateNhiGovernancePack invokes NhiAnalysis exactly once.
3. GenerateNhiGovernancePack invokes NhiGovernance exactly once.
4. NhiReporting receives the same NhiAnalyzed objects produced before standard exports.
5. Standard exports include DEC-NHI / DEC-AGENT findings.
6. NHI output files are registered without re-running discovery.
```

---

## 5. Output Manifest / Evidence Bundle Self-Recursion Cleanup

### 5.1 Problem

Rev3.4/Rev3.5 made output manifest and evidence bundle recursive so nested artifacts are included. That is good, but it can introduce self-recursion or partial indexing if the manifest/bundle is created while scanning the same folder.

### 5.2 Required implementation

Create a stable enumeration helper:

```powershell
Get-DecomOutputFilesForManifest
```

Rules:

```text
Include .json, .csv, .html, .md files.
Exclude temp folders.
Exclude redacted folder when generating source manifest unless explicitly requested.
Exclude evidence-bundle output folder while building evidence bundle.
Exclude output-manifest file while it is being written; optionally add it in a final pass.
Exclude evidence hash manifest while it is being written; optionally add it in a final pass.
Avoid duplicate file entries by FullPath.
```

### 5.3 Required tests

```text
1. OutputManifest does not include duplicate paths.
2. EvidenceBundle does not recursively include itself during initial build.
3. OutputManifest includes NHI outputs after NHI reporting.
4. OutputManifest includes redacted outputs when redacted package generation is enabled.
5. EvidenceBundle includes final NHI outputs without self-recursion.
6. Missing nested file validation still fails as expected.
```

---

## 6. Redaction Cleanup

### 6.1 Problem

Rev3.4 fixed redaction so it creates files. Rev3.6 should harden it:

```text
Do not redact already-redacted files.
Do not recurse into redacted output folder.
Do not silently swallow redaction failures.
Make redaction counts trustworthy.
```

### 6.2 Required implementation

Use stable file selection:

```powershell
Get-ChildItem -Path $RunFolder -File -Recurse |
    Where-Object {
        $_.Extension -in @('.json','.csv','.md','.html') -and
        $_.FullName -notmatch '\\redacted\\' -and
        $_.FullName -notmatch '\\temp\\'
    }
```

Replace silent catches with warning capture:

```powershell
catch {
    $redactionErrors += [pscustomobject]@{
        File = $sourceFile.FullName
        Error = $_.Exception.Message
    }
    Write-DecomWarn "Redaction failed for $($sourceFile.FullName): $($_.Exception.Message)"
}
```

Redaction report should include:

```text
RedactedFileCount
FailedFileCount
FailedFiles[]
ProfileName
DeterministicMapping = true
```

### 6.3 Required tests

```text
1. Redaction skips redacted folder.
2. Redaction does not re-redact already-redacted files.
3. Redaction report FailedFileCount increments on unreadable file.
4. RedactedFileCount equals actual number of redacted files written.
5. Same input token maps consistently within one package.
```

---

## 7. Coverage Limitation Cleanup

### 7.1 Problem

Rev3.5 added:

```text
RiskScoreMayBeUnderstated
CoverageLimitations
```

Rev3.6 should prevent:

```text
Duplicate limitations.
Risk-understated flag being set when zero high-risk permissions were legitimately found.
Loss of upstream coverage limitations.
```

### 7.2 Required implementation

Add helper:

```powershell
Add-DecomCoverageLimitation
```

Behavior:

```text
Preserve existing coverage limitations.
Append only unique messages.
Set RiskScoreMayBeUnderstated only when data is missing, unavailable, or unresolved.
Do not set RiskScoreMayBeUnderstated merely because HighRiskPermissionCount = 0.
```

For app-role permission resolution:

```text
If resource/app role resolution was not attempted or failed:
  RiskScoreMayBeUnderstated = true
  Add limitation.
If resolution succeeded and zero high-risk permissions found:
  RiskScoreMayBeUnderstated remains as-is.
```

### 7.3 Required tests

```text
1. Existing CoverageLimitations are preserved.
2. Duplicate CoverageLimitations are de-duplicated.
3. RiskScoreMayBeUnderstated remains false when high-risk permission resolution succeeds with zero hits.
4. RiskScoreMayBeUnderstated becomes true when permission resolution fails.
5. OAuth grant collection failure survives discovery -> analysis -> reporting.
```

---

## 8. PS5.1 Compatibility Sweep

### 8.1 Required scan

Add a test to reject PS7-only syntax in production modules:

```powershell
Select-String -Path .\src\Modules\*.psm1,.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Pattern '\?\?|ForEach-Object\s+-Parallel'
```

### 8.2 Parser test

Add parser-based test:

```powershell
$tokens = $null
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors) | Out-Null
$errors | Should -BeNullOrEmpty
```

Run over:

```text
Invoke-EntraIdentityDecommissioningControlPlane.ps1
src/Modules/*.psm1
tests/Rev11/*.ps1
```

### 8.3 Required tests

```text
1. No production module contains ??.
2. No production module uses ForEach-Object -Parallel.
3. All production modules parse under PS5.1 parser.
4. #Requires -Version 5.1 exists on newer modules where appropriate.
```

---

## 9. Silent Catch / Warning Hygiene

### 9.1 Problem

Some hardening/reporting blocks use:

```powershell
catch { }
```

or warnings that are not captured in output manifests.

### 9.2 Required implementation

Replace silent catches in non-test production code with:

```powershell
catch {
    Write-DecomWarn "Operation failed: $($_.Exception.Message)"
    $warnings += [pscustomobject]@{
        Stage = 'StageName'
        Error = $_.Exception.Message
    }
}
```

For best-effort operations, do not fail the run, but record the warning in:

```text
Run manifest
Output manifest summary
Client handoff checklist
Evidence bundle limitations
```

### 9.3 Required tests

```text
1. No production module contains literal catch { }.
2. Failed optional hardening output is recorded as warning.
3. Client handoff manifest includes hardening warnings.
4. Evidence bundle limitations include skipped output reason.
```

---

## 10. HTML / Report Encoding Hygiene

### 10.1 Required implementation

Add or standardize one helper:

```powershell
ConvertTo-DecomHtmlEncoded
```

Use it consistently for dynamic report text:

```text
DisplayName
UserPrincipalName
App display name
Evidence
RecommendedAction
PublisherName
ClassificationSignals
CoverageLimitations
Exception notes
```

### 10.2 Required tests

```text
1. DisplayName containing <script> is encoded in HTML report.
2. Evidence containing angle brackets is encoded.
3. NHI executive summary encodes dynamic values.
4. Approval diff HTML encodes action display names.
5. Traceability HTML encodes evidence fields.
```

---

## 11. Documentation Cleanup

Update:

```text
README.md
CHANGELOG.md
CLAUDE.md
docs/Schema-Contracts.md
docs/Rev3.5-NHI-Readiness.md
docs/Client-Handoff-Package.md
docs/Evidence-Bundle-Model.md
```

Required documentation changes:

```text
1. Mark Rev3.6 as cleanup / no new capability.
2. Update canonical test count.
3. Document version-hygiene rule: tests should not hardcode current version.
4. Document INTENTIONAL_HISTORICAL_VERSION marker.
5. Document single-run NHI pipeline state.
6. Document evidence bundle self-recursion prevention.
7. Document redaction recursion rules.
8. Document coverage limitation semantics.
```

---

## 12. Safety Scan Requirements

Run and pass:

```powershell
Select-String -Path .\src\Modules\*.psm1,.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Pattern 'ReadWrite|Remove-Mg|Update-Mg|Set-Mg|New-Mg|Invoke-Mg|Policy.ReadWrite|Directory.ReadWrite|Remove-MgApplication|Remove-MgServicePrincipal|Remove-MgUser|Remove-MgGroup' |
    Format-Table Path,LineNumber,Line -AutoSize
```

Expected:

```text
No new write scopes.
No new write cmdlets.
Only existing approved remediation write paths remain in Remediation.psm1.
No Policy.ReadWrite.*.
No app/SP/user/guest/group deletion.
```

---

## 13. Test Requirements

Baseline:

```text
Rev3.5 canonical test count: 1073
```

Rev3.6 target:

```text
>= 1125 tests
Stretch >= 1150 tests
0 failures
```

Required new test suites:

```text
VersionHygiene.Rev36.Tests.ps1
NhiPipelineState.Rev36.Tests.ps1
OutputManifestEvidenceCleanup.Rev36.Tests.ps1
RedactionCleanup.Rev36.Tests.ps1
CoverageLimitations.Rev36.Tests.ps1
PS51Compatibility.Rev36.Tests.ps1
WarningHygiene.Rev36.Tests.ps1
HtmlEncoding.Rev36.Tests.ps1
```

---

## 14. Milestone Plan

```text
Milestone 0 — Rev3.5 baseline verification
Milestone 1 — ToolVersion / SchemaVersion bump to Rev3.6 / 3.6
Milestone 2 — TestVersionContext helper
Milestone 3 — Version hygiene scan and test cleanup
Milestone 4 — NHI pipeline state consolidation
Milestone 5 — OutputManifest / EvidenceBundle recursion cleanup
Milestone 6 — Redaction recursion and warning cleanup
Milestone 7 — Coverage limitation helper and de-duplication
Milestone 8 — PS5.1 parser/syntax tests
Milestone 9 — Silent catch/warning hygiene
Milestone 10 — HTML encoding standardization
Milestone 11 — Documentation cleanup
Milestone 12 — SelfTest / ReleaseValidation update
Milestone 13 — Safety scan
Milestone 14 — Demo/WhatIf validation
Milestone 15 — Final verification
```

---

## 15. Final Verification Commands

Run:

```powershell
Invoke-Pester -Path .\tests\Rev11\ -Output Detailed

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode -Mode WhatIfRemediation -GenerateApprovalTemplate

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode -GenerateNhiGovernancePack -GenerateEvidenceBundle -GenerateRedactedPackage -GenerateTraceabilityReport -GenerateClientHandoff

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -SelfTest
```

Expected:

```text
Parse errors: 0
Pester tests >= 1125
Failures: 0
Demo mode clean
WhatIf demo clean
NHI demo clean
SelfTest clean
Safety scan clean
No new write scopes
No new remediation actions
No current-version hardcoding in tests except intentional historical markers
NHI pipeline runs once per execution
OutputManifest and EvidenceBundle do not self-recurse
Redaction skips redacted outputs
Coverage limitations are preserved and de-duplicated
```

---

## 16. CHANGELOG Entry

Add:

```markdown
## Rev3.6 — Post-Release Cleanup, Version Hygiene, and Evidence Consistency

### Added
- Version-hygiene test helper for current ToolVersion and SchemaVersion assertions.
- Version drift scanner for test assertions.
- NHI pipeline state consolidation.
- Output manifest / evidence bundle recursion cleanup.
- Redaction recursion and warning hygiene.
- Coverage limitation preservation and de-duplication.
- PS5.1 parser/syntax validation tests.
- Warning hygiene tests for silent catch blocks.
- HTML encoding hardening tests.

### Changed
- Current-version tests now reference centralized version helpers instead of hardcoded release strings where practical.
- NHI reporting reuses cached NHI discovery/analysis/governance state.
- Redaction skips already-redacted outputs.
- Evidence bundle avoids self-recursion while preserving nested artifact coverage.
- Coverage limitations distinguish missing evidence from legitimate zero-risk findings.

### Safety
- No new write scopes.
- No new remediation action types.
- No new tenant modification behavior.
- No new NHI detector families.
```

---

## 17. Done Criteria

Rev3.6 is done only when:

```text
1. ToolVersion = Rev3.6.
2. SchemaVersion = 3.6 for current outputs.
3. Current-version tests reference centralized version helpers where practical.
4. Historical version tests are clearly marked INTENTIONAL_HISTORICAL_VERSION.
5. NHI discovery/analysis/governance runs once per execution.
6. NHI reporting uses cached NHI pipeline state.
7. OutputManifest avoids duplicate/self-recursive entries.
8. EvidenceBundle avoids self-recursive bundling.
9. Redaction skips redacted folder and reports failures.
10. CoverageLimitations are preserved and de-duplicated.
11. RiskScoreMayBeUnderstated is not set solely because high-risk count = 0.
12. No production silent catch blocks remain in critical hardening paths.
13. PS5.1 parser checks pass.
14. HTML encoding tests pass.
15. No new write scopes.
16. No new remediation action types.
17. No new tenant modifications.
18. Pester tests >= 1125.
19. 0 failures.
20. Demo/WhatIf/NHI/SelfTest clean.
21. Docs and CHANGELOG updated.
```

---

## 18. Final Stop Rule

If the AI coding engine tries to add new functionality beyond cleanup:

```text
STOP.
Rev3.6 is cleanup only.
Move new feature ideas to Rev3.7 or Rev4 backlog.
```

If the AI coding engine tries to add write behavior:

```text
FAIL THE BUILD.
No new writes in Rev3.6.
```

If the AI coding engine tries to blindly replace historical version strings:

```text
STOP.
Historical manifest rejection tests must remain pinned and marked INTENTIONAL_HISTORICAL_VERSION.
```

If the AI coding engine cannot make a cleanup safely:

```text
Leave a TODO with explanation and add it to the Rev3.7 backlog.
Do not risk breaking the approved Rev3.5 behavior.
```
