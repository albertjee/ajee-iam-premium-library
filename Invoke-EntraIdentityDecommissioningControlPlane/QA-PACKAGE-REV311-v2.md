# QA Package - Rev3.11 Simple Parameter Wrapper
# File: QA-PACKAGE-REV311-v2.md
# Generated: 2026-06-05

## 1. Final Test Count

```
Tests Passed: 1320, Failed: 0, Skipped: 0, Inconclusive: 0, NotRun: 0
```

1320 = 1291 (Rev3.10 baseline) + 29 new Rev3.11 tests.
All tests pass. No failures.

## 2. Git Log (Rev3.11 commits)

```
df1be0a docs: Rev3.11 QA package - 1320/1320 passing, ready for external AI review
add11a4 docs: Rev3.11 M3 - CHANGELOG and CLAUDE.md updated
12b38ea test: Rev3.11 M2 - StartEntraIAMAssessment tests, 1320/1320 passing
164d9e0 feat: Rev3.11 M1 - Start-EntraIAMAssessment.ps1 wrapper, 4 preset modes
```

## 3. File Diff Summary

```
Start-EntraIAMAssessment.ps1                    (new)
tests/StartEntraIAMAssessment.Rev311.Tests.ps1 (new)
docs/QA-PACKAGE-REV311-v2.md                   (new)
CHANGELOG.md                                    (modified)
CLAUDE.md                                       (modified)
```

No frozen files touched. No existing source files modified.

## 4. Gate 1 Parse Output

**Start-EntraIAMAssessment.ps1:**
```
Parse errors: 0
```

**tests/StartEntraIAMAssessment.Rev311.Tests.ps1:**
```
Parse errors: 0
```

## 5. Gate 2 Dot-Source Output

```
Dot-source: OK
```

Wrapper dot-sources silently. No prompts. No errors. Only output is the sentinel line above.

## 6. Preset Mapping Table

| Wrapper `-Mode`     | Main tool `Mode`       | Switches added                                     |
|---------------------|------------------------|----------------------------------------------------|
| QuickNHI            | Assessment             | none                                               |
| FullAssessment      | Assessment             | GenerateNhiGovernancePack, GenerateExecutivePack   |
| DemoMode            | Assessment             | DemoMode, GenerateNhiGovernancePack, GenerateExecutivePack |
| WhatIfRemediation   | WhatIfRemediation      | none                                               |

Splat construction: optional params (`TenantId`, `ClientId`, `EngagementId`, `ClientName`, `Assessor`, `NonInteractive`, `NoLogo`) are added to splat only when supplied (presence check, not `$null` check).

## 7. Architecture Decisions

### -Mode NOT Mandatory in param block
Rationale: Making `-Mode` a `[Mandatory]` script parameter prevents silent dot-sourcing — the param would be bound before the script body executes and throw if absent. The BUILD-PROMPT spec requires runtime validation via a throw statement. The dot-source safety guard (checking `$MyInvocation.InvocationName -eq '.'`) sits before that throw, so sourcing is always silent.

### TestDrive fake entry point (not Mock)
Rationale: Pester `Mock` intercepts named commands and cmdlets — not the `&` invocation operator. Since the wrapper calls the entry point via `& $entryPoint @splat` with a `$PSScriptRoot`-resolved path, mocking fails reliably. The TestDrive approach provides a real fake that writes `$PSBoundParameters` to JSON, allowing the test to verify the actual splat contents that the wrapper produces.

### CRLF handling
PowerShell 7's `WriteAllLines` preserves platform-native endings. On Windows pwsh 7, Get-Content returns LF when reading a CRLF file, then WriteAllLines writes LF. Workaround: Python read/write with explicit `\r\n` normalization.

## 8. Known Issues or Deviations

**None.** All Rev3.11 tests pass. The Rev3.11 test file contains 16 test cases producing 29 passing assertions.

Two bugs were found and fixed during initial test run:
1. ValidateSet order test: removed premature `.Sort-Object` call — AST preserves declaration order, not sorted order.
2. QuickNHI BeforeAll: removed stray `-WhatIf` that blocked ShouldProcess and left `captured-params.json` nonexistent, causing `$captured` to be `$null`.

## 9. Commits

| Milestone | SHA | Message |
|---|---|---|
| M1 | 164d9e0 | feat: Rev3.11 M1 - Start-EntraIAMAssessment.ps1 wrapper, 4 preset modes |
| M2 | 12b38ea | test: Rev3.11 M2 - StartEntraIAMAssessment tests, 1320/1320 passing |
| M3 | add11a4 | docs: Rev3.11 M3 - CHANGELOG and CLAUDE.md updated |
| QA | df1be0a | docs: Rev3.11 QA package - 1320/1320 passing, ready for external AI review |

## 10. Push Status
Push performed: No. Albert pushes manually after external QA approval.