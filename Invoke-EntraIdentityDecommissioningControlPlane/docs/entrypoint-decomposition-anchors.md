# Entry-Point Decomposition — M1 Assertion-Migration Anchors

> **Status:** M1 APPROVED — 89cfcb0 committed (P1/P2/P3 pre-existing issues resolved), M2 in progress.
> **Baseline:** `48d0eeb`, 2408/2408, branch `refactor/entrypoint-decomposition`
> **Plan (APPROVED):** `docs/entrypoint-decomposition-plan.md`
> **Migration path for `$script:ControlledBranch`:** Path B (direct companion read in test BeforeAll)

---

## Source Files

- Entry point: `Invoke-EntraIdentityDecommissioningControlPlane.ps1` (1906 lines, 0 functions, 48 params)
- Companion target dir: `src/EntryPoint/`

## Region Map

| Region | Lines (48d0eeb) | Content | Disposition |
|---|---|---|---|
| A | 1-70 | param block, `$script:ToolVersion` | **STAYS in main** |
| B | 72-162 | mode validation, module imports | **STAYS in main** |
| C | 163-194 | SelfTest early exit | **STAYS in main** |
| D | 196-637 | Rev4.2-S1 controlled NHI decommission | -> `src/EntryPoint/ControlledNhiDecommission.ps1` |
| E | 638-960 | Rev4.0 M35 NHI execution guard + flow | -> `src/EntryPoint/NhiExecutionFlow.ps1` |
| F | 961-1242 | Assessment context, write-readiness, Graph connect | -> `src/EntryPoint/AssessmentFlow.ps1` |
| G | 1243-1611 | NHI governance pack + agent activity audit + demo | -> `src/EntryPoint/NhiGovernancePack.ps1` |
| H | 1612-1829 | Rev3.4 hardening outputs | -> `src/EntryPoint/HardeningOutputs.ps1` |
| I | 1830-1906 | Rev3.5 NHI governance pack | -> `src/EntryPoint/Rev35GovernancePack.ps1` |

## Migration Classes

| Class | Current target | New target |
|---|---|---|
| 1 Extraction-span | EntrySource substring via IndexOf markers | Read companion file directly |
| 2 Presence (whole-file) | `$EntrySource` | Concatenated corpus (main + companions in dot-source order) |
| 3 Absence (whole-file) | `$EntrySource` | Concatenated corpus — absence must hold across ALL files |
| 4 Ordering | `$EntrySource` positions | Concatenated corpus — first-occurrence (dot-source order == region order, so positions preserved) |
| 5 Block-slicing | `$EntrySource` substrings | Specific companion file(s) containing each block |
| 6 AST contract | Entry point AST | `main` AST + each companion AST |
| 7 Version/schema | `$EntrySource` ToolVersion regex | **UNCHANGED** (stays in main) |

---

## Concatenated Corpus Convention

After decomposition, tests that read `$EntrySource = Get-Content -Raw` of the entry point must instead read the concatenated corpus in dot-source order:

```
$corpusContent = @(
    (Get-Content -LiteralPath 'Invoke-EntraIdentityDecommissioningControlPlane.ps1' -Raw)   # main (A+B+C + dot-source block)
    (Get-Content -LiteralPath 'src/EntryPoint/ControlledNhiDecommission.ps1' -Raw)         # D
    (Get-Content -LiteralPath 'src/EntryPoint/NhiExecutionFlow.ps1' -Raw)                   # E
    (Get-Content -LiteralPath 'src/EntryPoint/AssessmentFlow.ps1' -Raw)                      # F
    (Get-Content -LiteralPath 'src/EntryPoint/NhiGovernancePack.ps1' -Raw)                    # G
    (Get-Content -LiteralPath 'src/EntryPoint/HardeningOutputs.ps1' -Raw)                     # H
    (Get-Content -LiteralPath 'src/EntryPoint/Rev35GovernancePack.ps1' -Raw)                  # I
) -join "`n"
```

This preserves first-occurrence semantics because concatenation order == dot-source order == original region order.

---

## Anchor Table

### 1. `tests/Safety.NhiControlled.Consolidated.Tests.ps1`

Counts: ~50 entry-anchored assertions + BeforeAll lines. Key patterns:

#### BeforeAll Infrastructure

| Test : line | Variable | Current source | New source |
|---|---|---|---|
| 12 | `$script:EntrySource` | `Get-Content -Raw $script:EntryPoint` (full file) | **Replace with `$script:Corpus`** (concatenated corpus — covers presence/absence/ordering across all regions) |
| 27-31 | `$script:ControlledBranch` | `$EntrySource.IndexOf('# Rev4.2-S1 controlled ...')` → `$EntrySource.Substring($branchStart, $branchEnd - $branchStart)` via markers in regions D and E | **Path B (recommended):** `$script:ControlledBranch = Get-Content -Raw (Join-Path $script:Root 'src/EntryPoint/ControlledNhiDecommission.ps1')` — all assertions against `$script:ControlledBranch` (lines 84-106, 287-288, 318-324, 338-340, 359-396) continue unchanged. **Path A (alternative):** dot-source the companion as part of main's load sequence; BeforeAll reads companion directly |

#### Assertion Classes

| Test : line | It / anchor type | Class | Anchor string(s) | Region | New target |
|---|---|---|---|---|---|
| 35-37 | `$script:EntryAst = [Parser]::ParseFile($script:EntryPoint, ...)` | 6 | full entry point AST | ALL | **Main AST + all 6 companion ASTs** — see AST section below |
| 50-52 | 'parses without errors' | 6 | `$script:ParseErrors.Count` | ALL | Correlate: must parse main + companions |
| 54-56 | 'uses Rev4.10 tool version' | 7 | `'$script:ToolVersion = ''Rev4.10'''` | A | **UNCHANGED** (stays in main) |
| 58-70 | 'defines Rev4.2-S1 parameter contract' | 6 | `$script:EntryAst.ParamBlock.Parameters` | A | **UNCHANGED** (param block in main) |
| 72-74 | 'loads the additive controlled decommission module' | 3 | `"'NhiControlledDecommission'"` in `$script:EntrySource` | B | **UNCHANGED** (module import in region B, stays in main) |
| 76-81 | 'places SelfTest before controlled... | 1 | `'# SelfTest early exit'`, `'if ($ExecuteNhiControlledDecommission...)'`, `'Connect-MgGraph'` | B/C/D | All three in main (regions B/C stay, D in Companion D). B/C anchors unchanged; D anchor reads Companion D |
| 83-85 | 'requires WhatIfExecution or DemoMode' | 3 | `'if \(-not \$WhatIfExecution -and -not \$DemoMode\)'` in `$script:ControlledBranch` | D | **Companion D** (direct, Path B) |
| 87-106 | 'fails closed when plan/manifest missing', 'blocks FinalDelete', 'contains no Graph connection', 'contains no mutation cmdlets' | 3 | various patterns in `$script:ControlledBranch` | D | **Companion D** |
| 109-112 | 'does not invoke prohibited deletion commands anywhere' | 6 | `$script:EntryAst.FindAll({ [CommandAst] })` — Remove-MgServicePrincipal, Remove-MgApplication | ALL | **Main + all 6 companions** (must find zero) |
| 114-117 | 'exports five local evidence artifacts and exits 0' | 3 | `'Export-NhiControlledDecommissionEvidence'` and `'exit 0'` in `$script:ControlledBranch` | D | **Companion D** |
| 119-139 | 'sample planner invocation succeeds', 'sample FinalDelete fails closed' | 7 (runtime) | `pwsh -File $script:EntryPoint ... -ExecuteNhiControlledDecommission ...` | D | **UNCHANGED invocation** — entry point must dot-source Companion D before executing |
| 147-155 | 'contains no ServicePrincipal/Application delete cmdlet' | 3 | `'(?m)^\s*Remove-MgServicePrincipal\b'`, `'(?m)^\s*Remove-MgApplication\b'` against `$script:EntrySource` | ALL | **Corpus** — pattern must not appear in main + all companions |
| 166-176 | 'requires WhatIf/Demo', 'blocks AllowFinalDelete outside FinalDelete stage' | 3 | various patterns in `$script:EntrySource` | D | **Corpus** — anchor in D, search over full corpus |
| 178-183 | 'keeps SelfTest before controlled and Graph paths' | 1 | same 3-markers as line 76-81 | B/C/D | Same as line 76-81 |
| 185-260 | 'sample simulation produces local evidence', 'FinalDelete blocked', 'Application readiness', etc. | 7 (runtime) | `pwsh -File $script:EntryPoint ...` | D | **UNCHANGED invocation** |
| 262-266 | **DANGEROUS** 'default source path contains no gate invocation before controlled branch' | 5 | `'if ($ExecuteNhiControlledDecommission...)'` — prefix of `$script:EntrySource` up to that marker | B/C | Tests the region C→D boundary in main. **Must verify dot-source of companion D begins AT the `$ExecuteNhiControlledDecommission` guard in main** (line 195). If dot-source placement shifts, this test's prefix length changes |
| 285-289 | 'keeps controlled branch free of live Graph patterns' | 3 | `$script:MutationPatterns` (7 patterns: Connect-MgGraph, Remove-MgServicePrincipal, etc.) in `$script:ControlledBranch` | D | **Companion D** (direct, Path B) |
| 291-297 | 'exposes Rev4.5/Rev4.6 metadata cleanup stage strings' | 3 | `'MetadataCleanupReadiness'`, `'GrantCleanupReadiness'` in `$script:EntrySource` | D | **Corpus** |
| 304-310 | 'exposes Rev4.6 grants cleanup stage string' | 3 | `'GrantCleanupReadiness'` in `$script:EntrySource` | D | **Corpus** or Companion D |
| 317-324 | 'does not synthesize managed identity evidence defaults' | 3 | `'ParentResourceId\s*=\s*\[string\]\$controlledPlanInput\.TargetId'`, `'ResourceId\s*=\s*\[string\]\$controlledPlanInput\.TargetId'` in `$script:ControlledBranch` | D | **Companion D** |
| 322-340 | 'exposes Rev4.7/Rev4.8 stage strings and samples' | 3 | `'ManagedIdentityReadiness'`, `'E2EEvidencePack'` in `$script:ControlledBranch` | D | **Companion D** |
| 355-357 | 'parses entry point without syntax errors' | 6 | `$script:ParseErrors.Count` | ALL | **Main + all 6 companions must parse clean** |
| 359-362 | 'keeps controlled branch on guarded production-readiness path' | 3 | `'ProductionReadiness'`, `'No Graph connection or tenant mutation performed'` in `$script:ControlledBranch` | D | **Companion D** |
| 364-368 | **BOUNDARY** 'keeps entry point from exposing production readiness in default Assessment flow' | 3 | `'if \(\$ExecuteNhiControlledDecommission -or ...\)'`, `'if \(\$controlledFeatureStage -eq ''ProductionReadiness''\)'`, `'Mode -eq ''Assessment''.*ProductionReadiness'` (negated) in `$script:EntrySource` | D/F boundary | These strings straddle regions D and F. Must search **corpus** — negative guard (Assessment excludes ProductionReadiness) stays in main (region F), positive guards in Companion D |
| 364-406 | 'contains no prohibited Graph mutation command names' | 6 | `$script:EntryAst.FindAll({ [CommandAst] })` — Remove-MgServicePrincipal, Remove-MgApplication, Remove-Az, Update-MgUser | ALL | **Main + all 6 companions** |
| 387-391 | 'does not schedule live merge or push operations' | 3 (x6) | 6 git-operation patterns in `$script:EntrySource` | ALL | **Corpus** |
| 393-396 | 'retains the controlled entry point before the execution flow' | 3 | `'exit 0'` and `'Rev4\.9 production readiness guardrails completed'` in `$script:ControlledBranch` | D | **Companion D** |

---

### 2. `tests/NhiControlledDecommission.Rev4x.Consolidated.Tests.ps1`

Counts: ~13 entry-anchored lines.

| Test : line | It / anchor type | Class | Anchor string(s) | Region | New target |
|---|---|---|---|---|---|
| 295-298 | 'contains no live Graph write/delete cmdlet references' | 3 | `'Connect-MgGraph\|Invoke-MgGraphRequest\|(?:Update\|Set\|New\|Remove)-Mg'` against `$script:ModulePath` (module-only, NOT entry point) | Module | **UNCHANGED** (module-only read, no entry anchor) |
| 2999-3005 | 'exports production readiness evidence pack through entry point' | 7 (runtime) | `pwsh -File $script:EntryPointPath ... -ExecutionStage ProductionReadiness ...` | D | **UNCHANGED invocation** |
| 3008-3013 | 'supports DemoMode simulation only through entry point' | 7 (runtime) | `pwsh -File $script:EntryPointPath ... -ExecutionStage ProductionReadiness ... -DemoMode` | D | **UNCHANGED invocation** |
| 3016-3019 | 'keeps SelfTest before the controlled Graph connection path' | 1 | `'# SelfTest early exit - no Graph connection, discovery, or remediation'` and `'Connect-MgGraph'` — inline `Get-Content -Raw` at test time | B/C | **UNCHANGED** (both markers stay in main regions B/C) |
| 3021-3026 | 'writes JSON artifacts that parse cleanly' | 7 (runtime) | `pwsh -File $script:EntryPointPath ... -ExecutionStage ProductionReadiness ...` | D | **UNCHANGED invocation** |
| 3028-3051 | 'fails closed when production readiness plan omits Rev42PlannerEvidence/FullPesterEvidence' | 7 (runtime) | `pwsh -File $script:EntryPointPath ...` | D | **UNCHANGED invocation** |
| 3054-3058 | **CLASS 1 RETARGET** 'keeps default Assessment out of controlled readiness path' | 3 (x2) | `'# Rev4\.2-S1 controlled NHI decommission planner/evidence flow'` (positive, reads entry point inline) and `'if \(\$Mode -eq ''Assessment''.*ProductionReadiness'` (negative) — both via `$script:Source = Get-Content -Raw $script:EntryPointPath` | **D/F boundary — BOUNDARY STRADDLER** | **Path A:** positive assertion must read Companion D directly (banner moves into companion). Negative assertion (Assessment-mode guard in main) stays unchanged. **Path B:** both read corpus, positive finds Banner in Companion D position, negative finds Assessment guard in main position |

---

### 3. `tests/NhiExecution.Rev40.Tests.ps1`

Counts: ~27 M35-specific entry-anchored assertions.

**Key finding:** NhiExecution.Rev40 touches the entry point ONLY from line 1181 onward (M35 tests). Earlier tests in the file are module/unit tests with no entry-point dependency.

#### BeforeAll

| Test : line | Variable | Current source | New source |
|---|---|---|---|
| 1187 | `$Script:EntryPointPath` | `Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'` | **UNCHANGED** (path reference only) |
| 1237 | M35 Guard BeforeAll | `$content = Get-Content -Path $Script:EntryPointPath -Raw` | **Concatenated corpus** (read main + all companions) |
| 1281 | M35 Execution Flow BeforeAll | `$content = Get-Content -Path $Script:EntryPointPath -Raw` | **Concatenated corpus** |

#### Assertions: Parameter Acceptance (Class 5 → Main)

These read `$content` for param declarations — all remain in main (region A param block):

| Test : line | It-name | Anchor | New target |
|---|---|---|---|
| 1190-1196 | 'Entry point accepts -ExecuteNhiDecommission' | `'ExecuteNhiDecommission'` | **Main** (param A) |
| 1199-1201 | 'Entry point accepts -PhaseLimit' | `'PhaseLimit'` | **Main** (param A) |
| 1204-1206 | 'Entry point accepts -ApprovedManifestPath' | `'ApprovedManifestPath'` | **Main** (param A) |
| 1209-1211 | 'Entry point accepts -ScreamTestDays' | `'ScreamTestDays'` | **Main** (param A) |
| 1214-1216 | 'Entry point accepts -ExecutionOutputPath' | `'ExecutionOutputPath'` | **Main** (param A) |
| 1219-1221 | 'Entry point accepts -Rollback' | `'\$Rollback\b'` | **Main** (param A) |
| 1224-1226 | 'Entry point accepts -ExecutionRunId' | `'ExecutionRunId'` | **Main** (param A) |
| 1229-1231 | 'Entry point accepts -AllowHumanExecution' | `'AllowHumanExecution'` | **Main** (param A) |

#### Assertions: M35 Guard / Execution (Class 5 → Companion E)

| Test : line | It / anchor type | Class | Anchor string(s) | Region | New target |
|---|---|---|---|---|---|
| 1240-1245 | '-ExecuteNhiDecommission without -ApprovedManifestPath throws' | 5 | `'ExecuteNhiDecommission'`, `'-not \$ApprovedManifestPath'`, `'ERROR.*ApprovedManifestPath'` — lines ~687-689 | E | **Companion E** |
| 1248-1251 | '-Rollback without -ExecutionRunId throws' | 5 | `'\$Rollback\b'`, `'if \(.*-not \$ExecutionRunId'` — lines ~701-704 | E | **Companion E** |
| 1254-1258 | '-ExecutionRunId invalid format throws' | 5 | `'-match .*notmatch.*ExecutionRunId'` — lines ~706-708 | E | **Companion E** |
| 1261-1266 | 'Supplied valid -ExecutionRunId passed through' | 5 | `'ExecutionRunId'`, `'Invoke-NhiSnapshot'`, `'Invoke-NhiTag'` — lines ~711-718 | E | **Companion E** |
| 1269-1277 | **CRITICAL BOUNDARY STRADDLER** 'Destructive cmdlet guard present' | 5 | `'NHI_REV40_BLOCKED_CMDLETS_DEFINITION'`, `'HardDeleteSvcPrincipalBlocklist'`, `'RemoveMgServicePrincipalNoParams'`, `'RemoveMgApplicationNoParams'` — region E lines 641-660 | **E** | **Companion E — with NHI_REV40_BLOCKED_CMDLETS constraint**: the comment-guard at entry ~641-660 must be preserved inside or adjacent to Companion E so anchor remains findable in the corpus at the original relative position within region E |
| 1287 | 'ExecutionOutputPath is created if absent' | 5 | `'ExecutionOutputPath.*New-Item\|New-Item.*ExecutionOutputPath'` — line ~723-724 | E | **Companion E** |
| 1291-1295 | 'NhiExecution modules imported' | 5 | `'NhiExecutionSchema'`, `'NhiExecution'` — lines ~658-661 | E | **Companion E** |
| 1298-1300 | 'Phase 1 always runs Snapshot then Tag' | 5 | `'Invoke-NhiSnapshot'`, `'Invoke-NhiTag'` | E | **Companion E** |
| 1303-1305 | 'Phase 2 only runs if PhaseLimit >= 2' | 5 | `'PhaseLimit.*2\|2.*PhaseLimit'` | E | **Companion E** |
| 1308-1310 | 'Phase 3 only runs if PhaseLimit >= 3' | 5 | `'PhaseLimit.*3\|3.*PhaseLimit'`, `'Get-NhiScreamTestStatus'` | E | **Companion E** |
| 1313-1319 | 'WhatIf Phase 2 does NOT check SnapshotManifest' | 5 | `'\$WhatIfPreference'`, `'PhaseLimit -ge 2'` | E | **Companion E** |
| 1322-1323 | 'Non-WhatIf Phase 2 throws when SnapshotManifest absent' | 5 | `'SnapshotManifest.*not found\|throw.*Manifest'` | E | **Companion E** |
| 1326-1327 | 'Rollback reads SnapshotManifest-{ExecutionRunId}.json' | 5 | `'SnapshotManifest.*ExecutionRunId'` — line ~729 | E | **Companion E** |
| 1330-1333 | 'Assessment behavior unchanged when -ExecuteNhiDecommission not passed' | 5 | `'Invoke-DecomAssessmentDiscovery'` | F | **Companion F** (assessment unchanged when NHI exec not triggered) |
| 1336-1341 | 'WhatIf output written to NhiExecutionWhatIf.json' | 5 | `'-WhatIf:\$WhatIfPreference'` | E | **Companion E** |

---

### 4. `tests/P1Fixes.Rev32.Tests.ps1`

Counts: ~3 entry-anchored assertions.

| Test : line | It / anchor type | Class | Anchor string(s) | Region | New target |
|---|---|---|---|---|---|
| 6 | BeforeAll `$script:EntryPoint` | N/A | path construction | N/A | **UNCHANGED** |
| 16 | BeforeAll `$script:EntryContent` | 2 | `Get-Content $script:EntryPoint -Raw` | ALL | **Concatenated corpus** |
| 28 | 'ExecuteRemediation write scopes include Application.ReadWrite.All' | 5 | `'(?s)^.*?(?=\$writeScopes\s*=\s*@)'` — extracts everything before `$writeScopes = @(` | B/F boundary | `$writeScopes` definition in **AssessmentFlow.ps1** (Companion F) — `$writeScopes` is set in the AssessmentFlow section |
| 33 | 'Assessment mode does not request Application.ReadWrite.All' | 5 | `'(?s)if\s*\(\$Mode\s*-eq\s*[''"]ExecuteRemediation[''"].*'` — removes ExecuteRemediation branch, asserts the remainder lacks `Application.ReadWrite.All` | F | **Companion F** — the `ExecuteRemediation` guard is the start of region F (line ~961); after removal, the remaining content must be in Companion F |
| 38 | 'WhatIfRemediation mode does not request Application.ReadWrite.All' | 5 | same `(?s)if\s*\(\$Mode\s*-eq\s*[''"]ExecuteRemediation[''"]` block-slicing | F | **Companion F** |

---

### 5. `tests/ReleaseValidation.Rev31.Tests.ps1`

Counts: ~8 entry-anchored assertions. **No decomposition changes required** — the whole-file absence `Should -Not -Match 'Remove-Mg'` uses an allowlist against the modules corpus (not the entry point) and the function invocations pass `$script:EntryPointPath` as a path argument (not reading source).

| Test : line | Anchor type | Class | Treatment |
|---|---|---|---|
| 8 | BeforeAll `$script:EntryPointPath` | N/A | **UNCHANGED** (path only) |
| 66-68 | ToolVersion match | 7 | **UNCHANGED** (ToolVersion stays in main) |
| 71-78 | write scope matches | 1 | **UNCHANGED** (scope strings in param block, region A) |
| 103-116 | `Invoke-DecomReleaseValidation` calls passing `-EntryPointPath` | N/A | **UNCHANGED** (passes path string, not reading content) |

---

### 6. `tests/ReleaseValidation.Rev33.Tests.ps1`

Counts: ~29 entry-anchored, covering all regions.

| Test : line | It / anchor type | Class | Anchor string(s) | Region | New target |
|---|---|---|---|---|---|
| 46-47 | ToolVersion Rev4.10 | 7 | `IndexOf('\$script:ToolVersion\s*=\s*[''"]Rev4\.10[''"]')` | A | **UNCHANGED** (Class 7) |
| 70-72 | 'Assessment mode does not call Application.ReadWrite.All' | 1 | `$content -replace '(?s)ExecuteRemediation.*',''` then `-Not -Match 'Application\.ReadWrite\.All'` — block-slices to the non-ExecuteRemediation portion | F | **Companion F** — the non-ExecuteRemediation portion is the assessment flow code in Companion F |
| 76-78 | 'DemoMode does not request Application.ReadWrite.All' | 1 | same slice technique | F | **Companion F** |
| 81-84 | 'DemoMode does not request GroupMember.ReadWrite.All' | 1 | same slice technique | F | **Companion F** |
| 89-98 | **CRITICAL: ORDERING CHAIN REQUIRES FIX** 'Gate ordering unchanged — WhatIf and Approval gates before Connect-MgGraph' | 4 | `IndexOf('Test-DecomWhatIfManifest')`, `IndexOf('Test-DecomApprovalManifest')`, `IndexOf('Connect-MgGraph')` | E | **Companion E** — BUT **the test assertion itself is currently broken** (see Pre-existing issue below) |
| 184-186 | 'Entry point does not reference Policy.ReadWrite' | 1 | `$content \| Should -Not -Match 'Policy\.ReadWrite'` | A | **UNCHANGED** (Policy.ReadWrite absent from entry point) |
| 223-225 | 'Rev3CapabilityMatrix module loaded' | 1 | `$content \| Should -Match 'Rev3CapabilityMatrix'` | A/B | **UNCHANGED** (dot-source in region B, stays in main) |

---

### 7. `tests/Rev30.Integration.Tests.ps1`

Counts: ~9 entry-anchored.

| Test : line | It / anchor type | Class | Anchor string(s) | Region | New target |
|---|---|---|---|---|---|
| 54-55 | `$script:EntryPointContent = Get-Content -Raw` | 1 | full entry point read | ALL | **Concatenated corpus** |
| 57-59 | 'includes EntitlementManagement.ReadWrite.All' | 1 | `$script:EntryPointContent \| Should -Match 'EntitlementManagement\.ReadWrite\.All'` | A | **UNCHANGED** (scope in param block, stays in main) |
| 62-63 | **WARNING: INTENTIONAL MISMATCH** 'references Rev3.0 release path' | 1 | `$script:EntryPointContent \| Should -Match 'Rev3\.0'` | G/H/I | **Companions G/H/I** — BUT `'Rev3\.0'` is **absent from current Rev4.10 source** — agent flagged this as INTENTIONAL_HISTORICAL_VERSION, meaning the test may have been written against an older revision and now always passes regardless |
| 66-68 | 'contains Rev3.0 error message string' | 1 | `$script:EntryPointContent \| Should -Match 'ExecuteRemediation for Rev3\.0'` | E | **Companion E** (NHI execution guard message string) |

---

### 8. `tests/Safety.Rev34.Tests.ps1`

Counts: ~4 entry-anchored.

| Test : line | It / anchor type | Class | Anchor string(s) | Region | New target |
|---|---|---|---|---|---|
| 114-117 | 'Assessment mode is the default Mode parameter' | 6 | `[Parser]::ParseFile($script:EntryPoint, ...)` — param block AST | A | **UNCHANGED** (param block stays in main) |
| 121-122 | 'DemoMode appears in write-scope Graph calls' | 1 | `$c \| Should -Match '-DemoMode'` — `$c` derived from `$script:EntrySource` AST cmdlets | F/G | **Companions F and G** — DemoMode uses appear in both the read-scope Graph connect (F) and demo-mode governance block (G) |
| 121-123 | 'DemoMode not paired with write scopes' | 1 | `$c \| Should -Not -Match 'DemoMode.*ReadWrite\|ReadWrite.*DemoMode'` | F/G | **Companions F and G** |
| 126-129 | 'WhatIfRemediation not used with ExecuteRemediation' | 1 | `$c \| Should -Match 'WhatIfRemediation'` and `Should -Match 'ExecuteRemediation'` | E/F | **Companions E and F** — both patterns present across regions |

---

### 9. `tests/Rev11/VersionHygiene.Rev36.Tests.ps1`

Counts: ~6 entry-anchored. **UNCHANGED — all Class 7 (ToolVersion stays in main).**

| Test : line | It / anchor type | Class | Treatment |
|---|---|---|---|
| 19-21 | ToolVersion = current release | 7 | **UNCHANGED** |
| 24-26 | ToolVersion not stale (not Rev3.[0-5]) | 7 | **UNCHANGED** |
| 31-34 | SchemaVersion 3.6 | 1 | Reads main file only. `'SchemaVersion\s*=\s*''3\.6'''` is in region F of the current file. After decomposition it will be in **Companion F**. Test should be updated to read concatenated corpus OR Companion F directly |

---

## Pre-Existing Issues Found During Inventory

### P1: Rev33 Ordering Test — ✅ RESOLVED (89cfcb0)

**File:** `tests/ReleaseValidation.Rev33.Tests.ps1` lines 89-99
**Test:** `IndexOf('Test-DecomWhatIfManifest') < IndexOf('Connect-MgGraph')`

**File:** `tests/ReleaseValidation.Rev33.Tests.ps1` lines 89-98
**Test:** `IndexOf('Test-DecomWhatIfManifest') < IndexOf('Connect-MgGraph')`

**Current state:** The test FAILS against the pre-decomposition source. In the current entry point:
- `Connect-MgGraph` — first occurrence at line 804 (inside `if ($ExecuteNhiDecommission)`, which exits at line 635 BEFORE reaching the M35 guard — unreachable at runtime)
- `Test-DecomWhatIfManifest` — line 999 (inside M35 guard block, after line 804)

`IndexOf` searches the static string, not the control flow. `posConn (804) < posA (999)` means `posA < posConn` is **false**. This test fails today at `48d0eeb`.

**Root cause:** `Connect-MgGraph` at line 804 is inside `if ($ExecuteNhiDecommission)` which is reached only when `$ExecuteNhiControlledDecommission` is false (controlled block exits before the NHI block). Line 804 is dead code.
**Fix:** Strip dead code blocks (controlled block through `exit 0` at line 635, NHI execution block) before `IndexOf`. The ordering comparison now operates on the reachable assessment/ExecuteRemediation execution path only. 55/55 tests pass after fix.

### P2: Rev30.Rev3\.0 Anchor — ✅ RESOLVED (89cfcb0, commentted out)

**File:** `tests/Rev30.Integration.Tests.ps1` lines 62-63

**File:** `tests/Rev30.Integration.Tests.ps1` line 62-63
**Test:** `$script:EntryPointContent | Should -Match 'Rev3\.0'`

**Current state:** `'Rev3\.0'` is absent from the Rev4.10 entry point. The test passes vacuously because `-Match` with a non-existent pattern always returns false, and `Should -Match` expects true. This test appears to have been written against an older revision.

**Required resolution:** Either remove the test (if Rev3.0 references are genuinely gone), update the anchor, or add a comment documenting intentional obsolescence.

### P3: SchemaVersion 3.6 Test Reads Main Only

**File:** `tests/Rev11/VersionHygiene.Rev36.Tests.ps1` line 31-34
**Test:** `$script:EntrySource | Should -Match "SchemaVersion\s*=\s*'3\.6'"`

The `SchemaVersion = '3.6'` literal is embedded in the `$Context` initialization within region F. After decomposition it will live in **Companion F**. The test reads `$script:EntrySource` (main file only), which will no longer contain the string.

**Required resolution (M8):** Update to read concatenated corpus, or explicitly read Companion F directly.

---

## $script:ControlledBranch — Two Migration Paths

### Path B (recommended): Direct companion read in test BeforeAll

```powershell
# BeforeAll — replace IndexOf/Substring extraction entirely
$script:ControlledBranchPath = Join-Path $script:Root 'src\EntryPoint\ControlledNhiDecommission.ps1'
$script:ControlledBranch = Get-Content -LiteralPath $script:ControlledBranchPath -Raw
```

All 17 tests asserting against `$script:ControlledBranch` (Should -Match, Should -Not -Match, .Count assertions) continue unchanged. The variable name stays the same; only the source changes from an IndexOf slice of the entry point to a direct read of the companion file.

**Cost:** ~2 lines changed in BeforeAll of Safety.NhiControlled and NhiControlledDecommission.

### Path A: Dot-source integration

Set `$script:ControlledBranch` by dot-sourcing the companion as part of the main entry-point load sequence, so that `$script:ControlledBranch` contains the companion's output when executed. Requires changes to both the BeforeAll AND the entry point's dot-source ordering. More invasive than Path B.

**Recommendation: Path B.**

---

## AST Contract Migration (Class 6)

Tests asserting `$script:EntryAst.FindAll({ [CommandAst] })` currently parse the main entry point. After decomposition, they must parse the full corpus concatenated in dot-source order.

**Migration:**
```powershell
$mainAst      = [Parser]::ParseFile($script:EntryPoint, [ref]$null, [ref]$mainErrs)
$companionD   = [Parser]::ParseFile((Join-Path $src 'src/EntryPoint/ControlledNhiDecommission.ps1'), [ref]$null, [ref]$_)
$companionE   = [Parser]::ParseFile((Join-Path $src 'src/EntryPoint/NhiExecutionFlow.ps1'), [ref]$null, [ref]$_)
# ... etc for F, G, H, I

# For prohibited-command scans: run FindAll on each AST independently, concatenate results
# Param block tests: run on $mainAst only (param block stays in main)
$allAsts = @($mainAst, $companionD, $companionE, $companionF, $companionG, $companionH, $companionI)
$prohibited = $allAsts | ForEach-Object { $_.FindAll({ param($n) $n -is [CommandAst] -and $script:ProhibitedVerbs -contains $_.GetCommandName() }, $true) }
$prohibited.Count | Should -Be 0
```

---

## Shared BeforeAll Helper for Concatenated Corpus

Introduce a shared function in a test helper module (created in M2 alongside Companion D):

```powershell
function Get-EntryPointCorpus {
    param([string]$Root = $script:RepoRoot)
    $main = Join-Path $Root 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    $src  = Join-Path $Root 'src\EntryPoint'
    @(
        (Get-Content -LiteralPath $main -Raw)
        (Get-Content -LiteralPath (Join-Path $src 'ControlledNhiDecommission.ps1') -Raw)
        (Get-Content -LiteralPath (Join-Path $src 'NhiExecutionFlow.ps1') -Raw)
        (Get-Content -LiteralPath (Join-Path $src 'AssessmentFlow.ps1') -Raw)
        (Get-Content -LiteralPath (Join-Path $src 'NhiGovernancePack.ps1') -Raw)
        (Get-Content -LiteralPath (Join-Path $src 'HardeningOutputs.ps1') -Raw)
        (Get-Content -LiteralPath (Join-Path $src 'Rev35GovernancePack.ps1') -Raw)
    ) -join "`n"
}
```

Tests that currently use `$script:EntrySource = Get-Content -Raw $script:EntryPoint` for whole-file presence/absence and ordering switch to `$script:Corpus = Get-EntryPointCorpus` in their BeforeAll.

---

## Migration Summary by File

| File | Anchored rows | Path A changes | Path B changes |
|---|---|---|---|
| Safety.NhiControlled.Consolidated | ~50 | 1–2 (companion dot-source) | 1–2 (companion read in BeforeAll) |
| NhiControlledDecommission.Rev4x | ~13 | 1–2 (companion dot-source) | 1–2 (companion read); 3 lines in line 3054 retarget |
| NhiExecution.Rev40 | ~27 | 2 BeforeAll to corpus | 2 BeforeAll to corpus |
| P1Fixes.Rev32 | ~3 | 1 BeforeAll to corpus | 1 BeforeAll to corpus; block-slicing targets to Companions F/E |
| ReleaseValidation.Rev31 | ~8 | 0 | 0 |
| ReleaseValidation.Rev33 | ~29 | 1 BeforeAll to corpus; Rev33 ordering fix (P1 above) | same |
| Rev30.Integration | ~9 | 1 BeforeAll to corpus; fix Rev3.0 anchor (P2 above) | same |
| Safety.Rev34 | ~4 | 1 BeforeAll to corpus | 1 BeforeAll to corpus |
| VersionHygiene.Rev36 | ~6 | 0 (Class 7) + SchemaVersion fix (P3) | 0 + SchemaVersion fix |
| **Total** | **~150** | | |

---

## Boundary-Straddler Index

| # | File : line | Issue | Resolution |
|---|---|---|---|
| BS-1 | Safety 1 : 364-368 | 'ProductionReadiness in Assessment' — strings straddle D/F boundary | Search corpus; positive guards in Companion D, negative guard (Assessment excludes) stays in main |
| BS-2 | NhiControlled.Rev4x : 3054-3058 | Banner `'# Rev4.2-S1 controlled...'` moves to Companion D; positive assertion reads inline | Retarget positive to Companion D; negative Assessment guard stays unchanged |
| BS-3 | P1Fixes.Rev32 : 28 | `$writeScopes` definition is in AssessmentFlow (entry ~997) — block extraction targets Companion F | Verify Companion F contains the `$writeScopes = @(` guard at its boundary |
| BS-4 | NhiExecution.Rev40 : 1269-1277 | `NHI_REV40_BLOCKED_CMDLETS_DEFINITION` at entry ~641-660 stays inside Companion E with region E content | Ensure comment-guard lines are preserved verbatim in Companion E; IndexOf will find them at new position within concatenated corpus |
| BS-5 | Safety 1 : 262-266 | Prefix of `$EntrySource` up to `$ExecuteNhiControlledDecommission` — tests MAIN has nothing before that guard | Verify dot-source of Companion D IS the first companion and begins AT the `$ExecuteNhiControlledDecommission` block in main |