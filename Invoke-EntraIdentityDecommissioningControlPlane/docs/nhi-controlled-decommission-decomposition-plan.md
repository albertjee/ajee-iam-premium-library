# NhiControlledDecommission.psm1 — Phase 5 Decomposition Plan

**Source:** `src/Modules/NhiControlledDecommission.psm1`
**Scanned:** 2026-07-04
**Scope:** Phase 5 Pre-Analysis (read-only)

---

## 1. Source Metrics

| Metric | Value |
|---|---|
| Total lines | 5916 |
| Total functions | 65 |
| Module-level `$script:` variables | 4 |
| Duplicate function definitions | 1 paste error |

**Module-level `$script:` variable inventory:**

| Variable | Line | Value |
|---|---|---|
| `$script:ControlledSchemaVersion` | 14 | `'4.2'` |
| `$script:SupportedTargetTypes` | 15 | 3-element array |
| `$script:SupportedStages` | 16 | 11-element array |
| `$script:SensitivePropertyPattern` | 17 | regex string |

These four variables are referenced by multiple functions across all subsystems. They must be either:
- (a) centralized in `NhiControlledDecommission.psm1` and re-exported with each sub-module, or
- (b) copied into each extracted module (preferred for self-contained sub-modules).

Recommendation: copy the four declarations into each extracted module. This avoids cross-module import ordering dependencies during refactoring.

---

## 2. Function Catalog

65 functions total, grouped by subsystem:

### Subsystem A — `Get-NhiControlled*` (Data Retrieval / State Queries)

| # | Function | Lines | Size |
|---|---|---|---|
| 1 | `Get-NhiControlledDecommissionSha256` | 19-36 | 18 |
| 2 | `ConvertTo-NhiControlledSanitizedValue` | 37-96 | 60 |
| 3 | `Get-NhiControlledDecommissionSchema` | 97-125 | 29 |
| 4 | `ConvertTo-NhiControlledSnapshot` | 126-176 | 51 |
| 5 | `Get-NhiControlledScreamTestStatus` | 258-304 | 47 |
| 6 | `Get-NhiControlledDeleteReadiness` | 336-380 | 45 |
| 7 | `Get-NhiControlledRollbackLimitation` | 497-529 | 33 |
| 8 | `Get-NhiControlledCredentialMetadataEvidence` | 530-554 | 25 |
| 9 | `Get-NhiControlledOwnerMetadataEvidence` | 555-576 | 22 |
| 10 | `Get-NhiControlledDependencyRecheckStatus` | 766-797 | 32 |
| 11 | `Get-NhiControlledManagedIdentityType` | 948-976 | 29 |
| 12 | `Get-NhiControlledTargetCountsByType` | 1155-1190 | 36 |
| 13 | `Get-NhiControlledStatusText` | 1191-1209 | 19 |
| 14 | `Get-NhiControlledPropertyValue` | 2060-2085 | 26 |
| 15 | `Get-NhiRun4CTargetContext` | 3909-3976 | 68 |
| 16 | `Get-NhiRun4CArtifactRecord` | 4698-4726 | 29 |

### Subsystem B — `Test-NhiControlled*` (Gate / Check Functions)

| # | Function | Lines | Size |
|---|---|---|---|
| 1 | `Test-NhiControlledTarget` | 177-198 | 22 |
| 2 | `Test-NhiControlledDependencies` | 305-335 | 31 |
| 3 | `Test-NhiControlledServicePrincipalFinalDeleteGate` | 381-433 | 53 |
| 4 | `Test-NhiControlledApplicationDeleteReadinessGate` | 434-496 | 63 |
| 5 | `Test-NhiControlledMetadataCleanupReadinessGate` | 618-699 | 82 |
| 6 | `Test-NhiControlledGrantCleanupReadinessGate` | 798-886 | 89 |
| 7 | `Test-NhiControlledManagedIdentityReadinessGate` | 977-1080 | 104 |
| 8 | `Test-NhiControlledLabLiveReversibleDisableReadiness` | 1449-1626 | 178 |

### Subsystem C — `New-NhiControlled*` with `Confirm-NhiControlled*` (Plan / Manifest / Evidence Generation)

| # | Function | Lines | Size |
|---|---|---|---|
| 1 | `Confirm-NhiControlledApproval` | 199-257 | 59 |
| 2 | `New-NhiControlledMetadataInventory` | 577-617 | 41 |
| 3 | `New-NhiControlledMetadataCleanupPlan` | 700-738 | 39 |
| 4 | `New-NhiControlledMetadataCleanupActionLog` | 739-765 | 27 |
| 5 | `New-NhiControlledGrantCleanupPlan` | 887-920 | 34 |
| 6 | `New-NhiControlledGrantCleanupActionLog` | 921-947 | 27 |
| 7 | `New-NhiControlledManagedIdentityReadinessPlan` | 1081-1126 | 46 |
| 8 | `New-NhiControlledManagedIdentityActionLog` | 1127-1154 | 28 |
| 9 | `New-NhiControlledE2EEvidencePack` | 1210-1333 | 124 |
| 10 | `New-NhiControlledOperatorDecisionLog` | 1334-1364 | 31 |
| 11 | `New-NhiControlledRollbackPlan` | 1365-1388 | 24 |
| 12 | `New-NhiControlledDecommissionPlan` | 1389-1448 | 60 |
| 13 | `Export-NhiControlledDecommissionEvidence` | 1627-1646 | 20 |
| 14 | `New-NhiControlledProductionReadinessEvidenceState` | 1647-1684 | 38 |
| 15 | `New-NhiControlledFindingDispositionSummary` | 1685-1710 | 26 |
| 16 | `New-NhiControlledKnownWarningInventory` | 1711-1785 | 75 |
| 17 | `New-NhiControlledFinalSafetyAssertions` | 1786-1807 | 22 |
| 18 | `New-NhiControlledProductionReadinessGate` | 1808-1961 | 154 |
| 19 | `New-NhiControlledReleaseMergeGateManifest` | 1962-1996 | 35 |
| 20 | `New-NhiControlledMergeGate` | 1997-2021 | 25 |
| 21 | `New-NhiControlledProductionReadinessEvidencePack` | 2022-2059 | 38 |
| 22 | `New-NhiControlledChecklist` | 2086-2101 | 16 |
| 23 | `New-NhiControlledGateVerdict` | 3064-3090 | 27 |
| 24 | `New-NhiControlledGateVerdict` | 3881-3908 | 28 |

### Subsystem D — `New-NhiControlled*` Lab Live Rehearsal Packages

| # | Function | Lines | Size |
|---|---|---|---|
| 1 | `New-NhiControlledLabDisableDryRunPackage` | 2102-2459 | 358 |
| 2 | `New-NhiControlledLabRollbackDrillPackage` | 2460-2678 | 219 |

### Subsystem E — `Invoke-NhiControlled*` + `Invoke-*` (Execution Actions)

| # | Function | Lines | Size |
|---|---|---|---|
| 1 | `Invoke-NhiControlledLabLiveReversibleDisable` | 2679-3063 | 385 |
| 2 | `Invoke-NhiControlledLabRollback` | 3977-4195 | 219 |

### Subsystem F — `New-NhiRun4C*` (Run4C Lab-Live Rehearsal Subsystem)

| # | Function | Lines | Size |
|---|---|---|---|
| 1 | `New-NhiRun4CFinalGoNoGoReviewPackage` | 3091-3322 | 232 |
| 2 | `New-NhiRun4CLiveEvidenceCapturePackage` | 3323-3509 | 187 |
| 3 | `New-NhiRun4CPostDisableObservationPackage` | 3510-3665 | 156 |
| 4 | `New-NhiRun4CRollbackExecutionReadinessPackage` | 3666-3880 | 215 |
| 5 | `New-NhiRun4CEndToEndLabRehearsalReport` | 4363-4569 | 207 |
| 6 | `New-NhiRun4CConsultantOperatingGuide` | 4570-4697 | 128 |
| 7 | `New-NhiRun4CFinalControlledDisableTestPackage` | 4727-5003 | 277 |
| 8 | `New-NhiRun4CPostDisableEvidenceValidationPackage` | 5004-5175 | 172 |
| 9 | `New-NhiRun4CControlledRollbackExecutionTestPackage` | 5176-5355 | 180 |
| 10 | `New-NhiRun4CPostRollbackValidationPackage` | 5356-5506 | 151 |
| 11 | `New-NhiRun4CFinalEvidenceBundle` | 5507-5735 | 229 |
| 12 | `New-NhiRev4ReleaseCandidateFreezePackage` | 5736-5915 | 180 |

---

## 3. Duplicate Function: `New-NhiControlledGateVerdict`

### Occurrences (2)

**Occurrence 1 — lines 3064-3090** (KEEP — has `[OutputType([PSCustomObject])]` and `[Severity]` is mandatory with no default)
```powershell
function New-NhiControlledGateVerdict {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GateName,
        [Parameter(Mandatory)]
        [bool]$Passed,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Severity,        # mandatory, no default
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Reason
    )
    ...
}
```

**Occurrence 2 — lines 3881-3908** (DISCARD — paste error; `[Severity]` defaults to `'High'`)
```powershell
function New-NhiControlledGateVerdict {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GateName,
        [Parameter(Mandatory)]
        [bool]$Passed,
        [string]$Severity = 'High',   # has default — looser signature
        [Parameter(Mandatory)]
        [string]$Reason                # Reason is NOT marked ValidateNotNullOrEmpty
    )
    ...
}
```

**Decision: KEEP the definition at line 3064-3090. DELETE the definition at lines 3881-3907.** The second is a copy-paste error that appears after the Run4C subsystem boundary. It has a less strict signature (Severity has default, Reason is not forced non-empty), which is inconsistent with the rest of the gate validation pattern used throughout the module.

---

## 4. `$script:` Variable Dependency Map

Only 4 module-level `$script:` variables exist. All are set at module top (lines 14-17) before any function definition. No `$script:` variables are assigned inside any function (confirmed by line-by-line grep — zero non-comment `$script:varName =` assignments with line number > 17).

| Variable | References |
|---|---|
| `$script:ControlledSchemaVersion` | Used in: `Get-NhiControlledDecommissionSchema` (line 102), `Get-NhiControlledScreamTestStatus` (line 293), `Get-NhiControlledDeleteReadiness` (line 374), `Test-NhiControlledServicePrincipalFinalDeleteGate` (line 404), `Test-NhiControlledApplicationDeleteReadinessGate` (line 458), `Confirm-NhiControlledApproval` (line 246), `New-NhiControlledDecommissionPlan` (line 1419), `Test-NhiControlledLabLiveReversibleDisableReadiness` (line 1483), `Test-NhiControlledManagedIdentityReadinessGate`, `Test-NhiControlledGrantCleanupReadinessGate`, `Test-NhiControlledMetadataCleanupReadinessGate` |
| `$script:SupportedTargetTypes` | Used in: `Test-NhiControlledTarget` (line 186), `Get-NhiControlledDecommissionSchema` (line 119) |
| `$script:SupportedStages` | Used in: `Get-NhiControlledDecommissionSchema` (line 120) |
| `$script:SensitivePropertyPattern` | Used in: `ConvertTo-NhiControlledSanitizedValue` (line 51), `ConvertTo-NhiControlledSnapshot` (line 160) |

**Impact on extraction:** The 4 `$script:` variables must appear in every extracted sub-module or be centralized. Current recommendation: copy all 4 into each sub-module during extraction. This is the simplest approach that avoids cross-module import ordering.

---

## 5. Proposed Module Decomposition

### Module 1: `NhiControlledCore.psm1`
**Lines: 1-1250** (approx) — Foundation utilities, no cross-subsystem dependencies.

Contains all **general-purpose utilities** that have no dependencies on other NhiControlled functions:

- `Get-NhiControlledDecommissionSha256` (L19-36)
- `ConvertTo-NhiControlledSanitizedValue` (L37-96) *references `$script:SensitivePropertyPattern`*
- `Get-NhiControlledDecommissionSchema` (L97-125) *references `$script:ControlledSchemaVersion`, `$script:SupportedTargetTypes`, `$script:SupportedStages`*
- `ConvertTo-NhiControlledSnapshot` (L126-176) *references `$script:SensitivePropertyPattern`*
- `Get-NhiControlledStatusText` (L1191-1209)
- `Get-NhiControlledPropertyValue` (L2060-2085)
- `Get-NhiControlledTargetCountsByType` (L1155-1190)

**Dependencies:** Self-contained, no NhiControlled function calls.

---

### Module 2: `NhiControlledValidation.psm1`
**Lines: 177-1080** — All gate and check functions.

Contains:

- `Test-NhiControlledTarget` (L177-198)
- `Confirm-NhiControlledApproval` (L199-257) *references `$script:ControlledSchemaVersion`*
- `Get-NhiControlledScreamTestStatus` (L258-304) *references `$script:ControlledSchemaVersion`*
- `Test-NhiControlledDependencies` (L305-335)
- `Get-NhiControlledDeleteReadiness` (L336-380) *references `$script:ControlledSchemaVersion`*
- `Test-NhiControlledServicePrincipalFinalDeleteGate` (L381-433) *references `$script:ControlledSchemaVersion`*
- `Test-NhiControlledApplicationDeleteReadinessGate` (L434-496) *references `$script:ControlledSchemaVersion`*
- `Get-NhiControlledRollbackLimitation` (L497-529)
- `Get-NhiControlledCredentialMetadataEvidence` (L530-554)
- `Get-NhiControlledOwnerMetadataEvidence` (L555-576)
- `Get-NhiControlledManagedIdentityType` (L948-976)
- `Test-NhiControlledManagedIdentityReadinessGate` (L977-1080)

**Dependencies on NhiControlledCore:** Only if any extraction makes cross-module calls necessary. Currently all calls are within this block.

---

### Module 3: `NhiControlledPlan.psm1`
**Lines: 577-1388** — All stage-specific planning and action log generation.

Contains:
- `New-NhiControlledMetadataInventory` (L577-617)
- `Test-NhiControlledMetadataCleanupReadinessGate` (L618-699) *may call validation functions from Module 2*
- `New-NhiControlledMetadataCleanupPlan` (L700-738)
- `New-NhiControlledMetadataCleanupActionLog` (L739-765)
- `Get-NhiControlledDependencyRecheckStatus` (L766-797)
- `Test-NhiControlledGrantCleanupReadinessGate` (L798-886) *may call validation functions from Module 2*
- `New-NhiControlledGrantCleanupPlan` (L887-920)
- `New-NhiControlledGrantCleanupActionLog` (L921-947)
- `New-NhiControlledManagedIdentityReadinessPlan` (L1081-1126)
- `New-NhiControlledManagedIdentityActionLog` (L1127-1154)
- `New-NhiControlledOperatorDecisionLog` (L1334-1364)
- `New-NhiControlledRollbackPlan` (L1365-1388)

**Cross-subsystem notes:** This block has validation gate functions interleaved (Test-NhiControlled*ReadinessGate). These should migrate together; they cannot be cleanly separated from the plan functions because each gate function validates its corresponding plan.

---

### Module 4: `NhiControlledDecommissionPlan.psm1`
**Lines: 1389-1710** — Top-level decommission orchestration.

Contains:
- `New-NhiControlledDecommissionPlan` (L1389-1448)
- `Export-NhiControlledDecommissionEvidence` (L1627-1646)
- `New-NhiControlledProductionReadinessEvidenceState` (L1647-1684)
- `New-NhiControlledFindingDispositionSummary` (L1685-1710)

**Note:** `New-NhiControlledDecommissionPlan` is the orchestration entry point — it calls `Test-NhiControlledTarget`. This module depends on Module 2 (Validation).

---

### Module 5: `NhiControlledEvidence.psm1`
**Lines: 1210-2021 + 3084-3090** — Evidence generation and packaging (non-execution).

Contains:
- `New-NhiControlledE2EEvidencePack` (L1210-1333) — requires many input objects; depends on Modules 1, 2, 3
- `New-NhiControlledKnownWarningInventory` (L1711-1785)
- `New-NhiControlledFinalSafetyAssertions` (L1786-1807)
- `New-NhiControlledProductionReadinessGate` (L1808-1961)
- `New-NhiControlledReleaseMergeGateManifest` (L1962-1996)
- `New-NhiControlledMergeGate` (L1997-2021)
- `New-NhiControlledProductionReadinessEvidencePack` (L2022-2059)
- `New-NhiControlledGateVerdict` (L3064-3090) — deduplicated version, **keep this one**
- `New-NhiControlledChecklist` (L2086-2101)

This is the largest functional module (lots of EvidencePack/Readiness functions). It has broad dependencies across all other modules — extract last.

---

### Module 6: `NhiControlledLabRehearsal.psm1`
**Lines: 1449-1626 + 2102-2678 + 3977-4195** — Lab live rehearsal execution (Invoke-*) + supporting packages.

Contains:
- `Test-NhiControlledLabLiveReversibleDisableReadiness` (L1449-1626)
- `New-NhiControlledLabDisableDryRunPackage` (L2102-2459)
- `New-NhiControlledLabRollbackDrillPackage` (L2460-2678)
- `Invoke-NhiControlledLabLiveReversibleDisable` (L2679-3063)
- `Invoke-NhiControlledLabRollback` (L3977-4195)
- `New-NhiControlledFinalSafetyAssertions` — also referenced above (shared; may need cross-module constant or duplication)

**Notes:** The two `Invoke-*` functions are the only active execution paths. All are simulation-only (`WhatIf`/`DemoMode`). This module may call functions from Modules 1-5.

---

### Module 7: `NhiControlledRun4C.psm1`
**Lines: 3091-5915** — Full Run4C lab-live rehearsal subsystem.

Contains the 12 `New-NhiRun4C*` functions plus one `Get-NhiRun4C*`:

- `New-NhiRun4CFinalGoNoGoReviewPackage` (L3091-3322)
- `New-NhiRun4CLiveEvidenceCapturePackage` (L3323-3509)
- `New-NhiRun4CPostDisableObservationPackage` (L3510-3665)
- `New-NhiRun4CRollbackExecutionReadinessPackage` (L3666-3880)
- `New-NhiRun4CEndToEndLabRehearsalReport` (L4363-4569)
- `New-NhiRun4CConsultantOperatingGuide` (L4570-4697)
- `New-NhiRun4CFinalControlledDisableTestPackage` (L4727-5003)
- `New-NhiRun4CPostDisableEvidenceValidationPackage` (L5004-5175)
- `New-NhiRun4CControlledRollbackExecutionTestPackage` (L5176-5355)
- `New-NhiRun4CPostRollbackValidationPackage` (L5356-5506)
- `New-NhiRun4CFinalEvidenceBundle` (L5507-5735)
- `New-NhiRev4ReleaseCandidateFreezePackage` (L5736-5915)
- `Get-NhiRun4CArtifactRecord` (L4698-4726)
- `Get-NhiRun4CTargetContext` (L3909-3976)

**Cross-subsystem note:** The Run4C subsystem at line 3881 contains the paste-error duplicate `New-NhiControlledGateVerdict` that must be removed before extraction.

---

## 6. Extraction Order (Dependency-Ordered)

Extraction must proceed from lowest cross-subsystem dependencies to highest:

| Priority | Module | Reason for ordering |
|---|---|---|
| 1 | `NhiControlledCore.psm1` | No function calls to other subsystems. Only shared `$script:` vars. |
| 2 | `NhiControlledRun4C.psm1` | Mostly self-contained. Contains only `New-NhiRun4C*` and `Get-NhiRun4C*`. Calls `Get-DecomToolVersion` (external) and functions from Modules 1. Can be extracted with stubs. |
| 3 | `NhiControlledValidation.psm1` | Internal calls only. Depends on Module 1 for utilities. |
| 4 | `NhiControlledPlan.psm1` | Contains validation gates interleaved with planning. Depends on Modules 1 and 3. |
| 5 | `NhiControlledDecommissionPlan.psm1` | Orchestration entry point. Depends on Modules 1, 2, 3, 4. |
| 6 | `NhiControlledLabRehearsal.psm1` | Invoke-* functions plus readiness test. Depends on Modules 1-5. |
| 7 | `NhiControlledEvidence.psm1` | Evidence and packaging functions that aggregate results from all other modules. Extract last. |

After all extractions:
- `NhiControlledDecommission.psm1` becomes the facade that imports all sub-modules and re-exports every function.
- The original file should be renamed (not deleted) as a backup during the transition period.

---

## 7. Schema Version Map (Future Reference)

Each function embeds a schema version in its output for contract compatibility:

| Schema Version | Used By |
|---|---|
| `4.2` | `$script:ControlledSchemaVersion` (module default) |
| `4.3` | Test-NhiControlledServicePrincipalFinalDeleteGate |
| `4.4` | Test-NhiControlledApplicationDeleteReadinessGate |
| `4.5` | MetadataCleanupSchemaVersion (via Get-NhiControlledDecommissionSchema) |
| `4.6` | GrantCleanupSchemaVersion (via Get-NhiControlledDecommissionSchema) |
| `4.7` | ManagedIdentitySchemaVersion (via Get-NhiControlledDecommissionSchema) |
| `4.8` | E2EEvidencePack schema + QAHandoffSchemaVersion (via Get-NhiControlledDecommissionSchema) |
| `4.9` | ProductionReadiness + ReleaseMergeGate + KnownWarningInventory + FinalSafetyAssertion schemas (via Get-NhiControlledDecommissionSchema) |

When decomposing, each sub-module's exported functions must preserve these schema versions for existing consumers.

---

## 8. Immediate Action Items

1. **Remove the paste-error duplicate** at lines 3881-3907 (`New-NhiControlledGateVerdict` with default Severity). Keep the definition at lines 3064-3090 (strict signature, `[OutputType([PSCustomObject])]`).
2. **Decide on `$script:` variable strategy** before extraction begins: centralized vs. copy-into-each.
3. **Begin extraction with Module 1 (Core)** — has zero cross-subsystem function calls.
4. **Extract Module 7 (Run4C) second** — it's large (2829 lines, 12 functions) and relatively isolated.
5. Work inward toward `NhiControlledEvidence.psm1` last, as it aggregates everything.