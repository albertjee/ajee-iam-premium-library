# Replay Validation Model
## Entra Identity Decommissioning Control Plane — Rev3.4

---

## Overview

Replay validation is an offline consistency check that runs against completed execution evidence without requiring a live connection to Microsoft Graph. It answers a single question: does the execution record tell a coherent, authorized story?

A coherent story means:
- Every action that was executed was pre-approved
- No unapproved action appears in the execution evidence
- The objects acted upon match the objects that were approved
- Every executed action has post-write evidence confirming the outcome
- The approval manifest that authorized the run is the same manifest that was present when execution occurred

Replay validation does not re-run actions. It does not query the tenant. It reads the artifacts already present in the evidence bundle and validates their internal consistency.

---

## Functions

| Function | Purpose |
|---|---|
| `Invoke-DecomReplayValidation` | Runs all 10 validation checks; returns a structured result object |
| `Test-DecomWhatIfApprovalBinding` | Check 1 — WhatIfRunId in approval matches the WhatIf transcript |
| `Test-DecomApprovalExecutionBinding` | Check 2 — approval manifest hash in execution logs matches the actual manifest |
| `Test-DecomExecutionEvidenceConsistency` | Checks 3–10 — validates each action record for internal consistency |
| `Export-DecomReplayValidationReportJson` | Writes `ReplayValidation.json` — machine-readable validation results |
| `Export-DecomReplayValidationReportMarkdown` | Writes `ReplayValidation.md` — human-readable validation narrative |

---

## Running Replay Validation

```powershell
$replayResult = Invoke-DecomReplayValidation `
    -EvidenceBundle    $evidenceBundle `
    -ToolVersion       'Rev3.4' `
    -SchemaVersion     '3.4'

Export-DecomReplayValidationReportJson `
    -Result     $replayResult `
    -OutputPath 'C:\DecomOutputs\ReplayValidation.json'

Export-DecomReplayValidationReportMarkdown `
    -Result     $replayResult `
    -OutputPath 'C:\DecomOutputs\ReplayValidation.md'

# Surface any failures
if ($replayResult.FailedChecks.Count -gt 0) {
    $replayResult.FailedChecks | ForEach-Object {
        Write-Warning "FAIL [$($_.CheckId)]: $($_.Reason)"
    }
}
```

No Graph connection parameters are required. No `-TenantId`, no `-ClientId`, no `-ClientSecret`. All inputs come from the evidence bundle.

---

## The 10 Validation Checks

### Check 1 — WhatIfRunId Binding

**What it verifies:** The `WhatIfRunId` field recorded in the approval manifest matches the `RunId` present in the WhatIf transcript files.

**Why it matters:** The approval was granted against a specific WhatIf simulation. If the `WhatIfRunId` does not match, the approval may have been issued against a different simulation than the one that preceded execution.

**Failure condition:** `ApprovalManifest.WhatIfRunId` does not match `WhatIfTranscripts.RunId`.

**Check function:** `Test-DecomWhatIfApprovalBinding`

---

### Check 2 — Approval Hash Binding

**What it verifies:** The SHA-256 hash of `ApprovalManifest.json` matches the `ApprovalManifestHash` value recorded in every execution log entry.

**Why it matters:** This binding proves that execution used the same approval document that was signed. If the manifest was modified between signing and execution, the hashes will diverge.

**Failure condition:** `SHA256(ApprovalManifest.json)` does not equal any `ExecutionLog[n].ApprovalManifestHash`.

**Check function:** `Test-DecomApprovalExecutionBinding`

---

### Check 3 — Every Executed ActionId Was Approved

**What it verifies:** For every execution log entry with `Outcome = Executed`, the `ActionId` appears in `ApprovalManifest.ApprovedActions`.

**Why it matters:** No action may be executed without explicit approval. An `ActionId` in the execution log that does not appear in the approval manifest is an unauthorized execution.

**Failure condition:** Any execution log entry with `Outcome = Executed` has an `ActionId` not present in `ApprovalManifest.ApprovedActions`.

---

### Check 4 — No Unapproved ActionId in Execution Evidence

**What it verifies:** The converse of Check 3 — no execution log entry with a write outcome (`Executed`, `PartialFailed`) contains an `ActionId` absent from the approval manifest. Skipped and Blocked entries are exempt from this check.

**Why it matters:** Checks 3 and 4 together ensure the approved set and the executed set are identical — no extras, no gaps on the write side.

**Failure condition:** Any execution log entry with a write outcome has an `ActionId` not present in `ApprovalManifest.ApprovedActions`.

---

### Check 5 — TargetObjectIds Match Approval

**What it verifies:** For every executed action, the `TargetObjectIds` array in the execution log entry matches the `TargetObjectIds` array recorded in the approval manifest for the same `ActionId`.

**Why it matters:** Approval is granted for a specific action against specific objects. An action executed against a different object than approved is unauthorized, even if the `ActionId` itself was approved.

**Failure condition:** `ExecutionLog[n].TargetObjectIds` does not equal `ApprovalManifest.ApprovedActions[ActionId].TargetObjectIds` (order-independent set comparison).

---

### Check 6 — Executed Action Has Post-Write Evidence

**What it verifies:** Every execution log entry with `Outcome = Executed` has a corresponding entry in `PostWriteRequery.json` confirming that the outcome was verified after the write.

**Why it matters:** Execution without verification is an incomplete record. The post-write requery confirms that the change actually took effect in the tenant, not just that the API call returned 200.

**Failure condition:** Any execution log entry with `Outcome = Executed` has no corresponding `PostWriteRequery` record, or the corresponding record has `Status = NotQueried`.

---

### Check 7 — Blocked Action Has ErrorDetail

**What it verifies:** Every execution log entry with `Outcome = Blocked` has a non-empty `ErrorDetail` field explaining why the action was blocked.

**Why it matters:** A blocked action without an explanation is an incomplete record. The ErrorDetail is required for audit purposes so reviewers can determine whether the block was expected (e.g., a protected object policy) or unexpected (e.g., a permission error).

**Failure condition:** Any execution log entry with `Outcome = Blocked` has a null or empty `ErrorDetail`.

---

### Check 8 — Skipped Action Cannot Claim Write

**What it verifies:** No execution log entry with `Outcome = Skipped` has a non-empty `GraphWriteCmdlet` field or a corresponding `PostWriteRequery` record.

**Why it matters:** A skipped action by definition did not execute a write. If a skipped entry claims a Graph write cmdlet was called or a post-write requery was performed, the record is internally inconsistent.

**Failure condition:** Any execution log entry with `Outcome = Skipped` has a non-null `GraphWriteCmdlet` or a corresponding `PostWriteRequery` entry.

---

### Check 9 — ExecutionWindow Is Valid

**What it verifies:** The `ExecutedUtc` timestamp for every executed action falls within the `ExecutionWindow` recorded in the approval manifest (`ApprovalManifest.ExecutionWindowStart` and `ApprovalManifest.ExecutionWindowEnd`).

**Why it matters:** Approval grants are time-bounded. An action executed outside the approved window may have occurred after the approval expired or before it was effective.

**Failure condition:** Any `ExecutedUtc` value is earlier than `ExecutionWindowStart` or later than `ExecutionWindowEnd`.

---

### Check 10 — ProtectedObject Blocked, Not Executed

**What it verifies:** Every object flagged as `IsProtectedObject = true` in the baseline export has no execution log entry with `Outcome = Executed`. Protected objects must appear as `Blocked` if any action was attempted against them.

**Why it matters:** Protected objects (e.g., break-glass accounts, critical service principals) are never eligible for automated remediation. An executed action against a protected object is a policy violation regardless of approval status.

**Failure condition:** Any execution log entry with `Outcome = Executed` references a `TargetObjectId` that appears in the baseline export with `IsProtectedObject = true`.

---

## Validation Result Object

`Invoke-DecomReplayValidation` returns a structured object with the following shape:

```json
{
  "RunId": "...",
  "ValidationTimestamp": "...",
  "ToolVersion": "Rev3.4",
  "SchemaVersion": "3.4",
  "OverallResult": "Pass",
  "ChecksRun": 10,
  "ChecksPassed": 10,
  "ChecksFailed": 0,
  "FailedChecks": [],
  "CheckDetails": [
    {
      "CheckId": "RV-001",
      "CheckName": "WhatIfRunIdBinding",
      "Result": "Pass",
      "Detail": "WhatIfRunId matches transcript RunId"
    },
    ...
  ]
}
```

`OverallResult` is `Pass` only if all 10 checks pass. Any single failure sets `OverallResult` to `Fail`.

---

## Check Reference Table

| CheckId | Name | Function | Key Artifact Fields |
|---|---|---|---|
| RV-001 | WhatIfRunId Binding | `Test-DecomWhatIfApprovalBinding` | `ApprovalManifest.WhatIfRunId`, `WhatIfTranscripts.RunId` |
| RV-002 | Approval Hash Binding | `Test-DecomApprovalExecutionBinding` | `SHA256(ApprovalManifest.json)`, `ExecutionLog[n].ApprovalManifestHash` |
| RV-003 | Executed ActionId Approved | `Test-DecomExecutionEvidenceConsistency` | `ExecutionLog[n].ActionId`, `ApprovalManifest.ApprovedActions` |
| RV-004 | No Unapproved Write ActionId | `Test-DecomExecutionEvidenceConsistency` | `ExecutionLog[n].ActionId` (write outcomes), `ApprovalManifest.ApprovedActions` |
| RV-005 | TargetObjectIds Match | `Test-DecomExecutionEvidenceConsistency` | `ExecutionLog[n].TargetObjectIds`, `ApprovalManifest.ApprovedActions[n].TargetObjectIds` |
| RV-006 | Executed Has Post-Write Evidence | `Test-DecomExecutionEvidenceConsistency` | `ExecutionLog[n].Outcome`, `PostWriteRequery[n].Status` |
| RV-007 | Blocked Has ErrorDetail | `Test-DecomExecutionEvidenceConsistency` | `ExecutionLog[n].Outcome`, `ExecutionLog[n].ErrorDetail` |
| RV-008 | Skipped Cannot Claim Write | `Test-DecomExecutionEvidenceConsistency` | `ExecutionLog[n].Outcome`, `ExecutionLog[n].GraphWriteCmdlet` |
| RV-009 | ExecutionWindow Valid | `Test-DecomExecutionEvidenceConsistency` | `ExecutionLog[n].ExecutedUtc`, `ApprovalManifest.ExecutionWindowStart/End` |
| RV-010 | ProtectedObject Not Executed | `Test-DecomExecutionEvidenceConsistency` | `ExecutionLog[n].TargetObjectIds`, `BaselineExport[n].IsProtectedObject` |

---

## Output Files

| File | Description |
|---|---|
| `ReplayValidation.json` | Machine-readable result object — all 10 check results |
| `ReplayValidation.md` | Human-readable narrative — pass/fail summary with explanations for any failures |

---

*ToolVersion: Rev3.4 | SchemaVersion: 3.4 | Module: `src\Modules\ReplayValidation.psm1`*
