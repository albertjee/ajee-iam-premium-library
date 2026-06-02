# Replay Validation Runbook
## Entra Identity Decommissioning Control Plane — Rev3.4

**Audience:** Identity governance consultants and audit teams  
**Purpose:** Guide for validating execution replay from saved run artifacts  
**Tool:** `Invoke-EntraIdentityDecommissioningControlPlane.ps1`  
**Key characteristic:** Entirely offline — no Microsoft Graph connection required

---

## Overview

Replay validation reconstructs the logical chain of an execution run from saved artifacts (WhatIf report, approval manifest, and execution evidence) and verifies 10 consistency checks. It does not re-execute any actions or connect to the tenant. It answers the question: "Do the artifacts from this run prove that every action that was executed was authorized?"

Replay validation is designed to be run:

- **After execution** — as an immediate post-execution integrity check
- **Before closing an engagement** — as part of the evidence package sign-off
- **For audit** — when an auditor or client requests proof of authorized changes
- **After evidence bundle transfer** — to confirm artifacts were not modified in transit

---

## When to Run Replay Validation

| Situation | Action |
|---|---|
| Immediately after ExecuteRemediation completes | Run replay validation against the new execution output folder |
| Before generating the client handoff package | Confirm all 10 checks pass; note any failures |
| When an auditor requests execution authorization evidence | Run replay validation and provide the report |
| After copying the evidence bundle to an archive location | Run replay validation from the archive copy to confirm file integrity |
| Any time an execution evidence file is questioned | Run replay validation to identify whether the file chain is intact |

---

## Step 1: Generate the Replay Validation Report

### During an Assessment or ExecuteRemediation Run

Add `-GenerateReplayValidation` to the run:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -GenerateReplayValidation
```

For ExecuteRemediation (validates post-execution artifacts):

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode ExecuteRemediation `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -WhatIfManifestPath ".\out\20260602_143000\...-run-manifest-20260602_143000.json" `
    -ApprovalManifestPath ".\approvals\ENG-2026-001-approval.json" `
    -GenerateReplayValidation
```

**Expected output:**

```
[OK]  Replay validation report: .\out\20260602_143000\replay-validation-report-20260602_143000.json
```

### Prerequisites for Full Validation Coverage

To get all 10 checks evaluated (not just warnings), the run must have produced all three artifact types:

| Artifact | Required for Checks |
|---|---|
| WhatIf run manifest (with RunId) | Check 1 (WhatIfApprovalBinding) |
| Approval manifest (with WhatIfRunId and ApprovedActions) | Checks 1, 2, 3, 4, 5, 6 |
| Execution evidence JSON (with Actions array) | Checks 2–10 |

If any artifact is absent, the corresponding checks are skipped and recorded as warnings (not failures).

---

## Step 2: Read the replay-validation-report.json

Load and inspect the report:

```powershell
$report = Get-Content ".\out\20260602_143000\replay-validation-report-20260602_143000.json" -Raw | ConvertFrom-Json

# Overall result
Write-Host "Overall: $(if ($report.Passed) { 'PASS' } else { 'FAIL' })"
Write-Host "Checks: $($report.PassedChecks) passed / $($report.FailedChecks) failed / $($report.CheckCount) total"

# Show all findings
$report.Findings | Format-Table CheckName, Passed, Severity, Message -AutoSize

# Show any warnings (checks that were skipped due to missing artifacts)
$report.Warnings
```

**Sample passing report output:**

```
Overall: PASS
Checks: 10 passed / 0 failed / 10 total

CheckName                          Passed Severity Message
---------                          ------ -------- -------
WhatIfApprovalBinding              True   Info     WhatIfRunId binding verified: 'a1b2c3d4-...'
ApprovalExecutionBinding           True   Info     ApprovalEnvelopeHash binding verified: 'f3a9...'
ApprovedActionsHashMatch           True   Info     ApprovedActionsHash verified: 'e8c2...'
AllExecutedActionsApproved         True   Info     All ActionIds in execution evidence exist...
NoUnapprovedActionIds              True   Info     No unapproved ActionIds found in execution...
AllTargetObjectIdsApproved         True   Info     All TargetObjectIds in execution evidence were...
FailedBlockedActionsHaveErrorDetail True  Info     All Failed/PartialFailed/Blocked actions have...
ExecutedActionsHavePostWriteEvidence True Info     All Executed actions have a post-write evidence...
SkippedActionsNoTenantWrite        True   Info     No Skipped actions claim a tenant write
ProtectedObjectsNotExecuted        True   Info     No ProtectedObject actions were executed
```

---

## Step 3: What the 10 Checks Mean

### Check 1: WhatIfApprovalBinding (`WhatIfApprovalBinding`)

**What it verifies:** The `WhatIfRunId` field in the approval manifest exactly matches the `RunId` in the WhatIf run manifest.

**Why it matters:** This proves the approval was signed against the specific WhatIf run that generated the action plan. If these don't match, the approval was issued for a different run — the executed actions may not have been what the approver reviewed.

**Failure message pattern:** `WhatIfRunId mismatch: WhatIfReport.RunId='X', ApprovalManifest.WhatIfRunId='Y'`

---

### Check 2: ApprovalExecutionBinding (`ApprovalExecutionBinding`)

**What it verifies:** The `ApprovalEnvelopeHash` in the execution evidence matches the same field in the approval manifest.

**Why it matters:** This proves the approval manifest used during execution was the same document that was signed by the approver. Any modification to the approval manifest after signing would change the hash and fail this check.

**Failure message pattern:** `ApprovalEnvelopeHash mismatch: manifest='X', evidence='Y'`

---

### Check 3: ApprovedActionsHashMatch (`ApprovedActionsHashMatch`)

**What it verifies:** The hash of the approved actions list (if present in both the approval manifest and execution evidence) matches between the two artifacts.

**Why it matters:** Detects any modification to the approved actions list between approval and execution.

**Note:** If neither artifact contains `ApprovedActionsHash`, this check passes with an informational note. It is not a failure — this field is optional in the Rev3.4 schema.

**Failure message pattern:** `ApprovedActionsHash mismatch: manifest='X', evidence='Y'`

---

### Check 4: AllExecutedActionsApproved (`AllExecutedActionsApproved`)

**What it verifies:** Every `ActionId` appearing in the execution evidence exists in the approval manifest's `ApprovedActions` list.

**Why it matters:** Detects unauthorized actions — any action that was executed but not approved.

**Failure message pattern:** `ActionIds in evidence not found in approval manifest: id1, id2`

---

### Check 5: NoUnapprovedActionIds (`NoUnapprovedActionIds`)

**What it verifies:** No `ActionId` in the execution evidence is absent from the approval manifest.

**Why it matters:** Complementary to Check 4. Checks 4 and 5 together ensure no ActionId in the evidence is unknown to the approval, regardless of how the evidence was assembled.

**Failure message pattern:** `Unapproved ActionIds present in execution evidence: id1, id2`

---

### Check 6: AllTargetObjectIdsApproved (`AllTargetObjectIdsApproved`)

**What it verifies:** For each executed action, every `TargetObjectId` in the execution evidence was listed in the approved action's `TargetObjectIds` in the approval manifest.

**Why it matters:** Detects scope creep — an action that was approved for object A but executed against object B.

**Failure message pattern:** `Unapproved TargetObjectIds in execution evidence (ActionId/TargetObjectId): id/tid`

---

### Check 7: FailedBlockedActionsHaveErrorDetail (`FailedBlockedActionsHaveErrorDetail`)

**What it verifies:** Every action with outcome `Failed`, `PartialFailed`, or `Blocked` has a non-empty `ErrorDetail` field.

**Why it matters:** Ensures that every non-success outcome is documented. An action that failed without an error detail cannot be investigated or explained to an auditor.

**Failure message pattern:** `Actions missing ErrorDetail for non-success outcomes: id1 (Outcome=Failed)`

---

### Check 8: ExecutedActionsHavePostWriteEvidence (`ExecutedActionsHavePostWriteEvidence`)

**What it verifies:** Every action with outcome `Executed` has at least one of: `PostWriteEvidence`, `TargetsAfter`, or `AfterState` populated.

**Why it matters:** Proves that a read-back was performed after the write to confirm the change took effect. Without post-write evidence, there is no proof the action completed successfully at the tenant level.

**Failure message pattern:** `Executed actions missing post-write evidence reference: id1, id2`

---

### Check 9: SkippedActionsNoTenantWrite (`SkippedActionsNoTenantWrite`)

**What it verifies:** No action with outcome `Skipped` has `HasTenantWrite = true`.

**Why it matters:** An action that was skipped (e.g., because the credential was already removed) must not claim it wrote to the tenant. This would be a false evidence claim.

**Failure message pattern:** `Skipped actions that claim HasTenantWrite=true: id1`

---

### Check 10: ProtectedObjectsNotExecuted (`ProtectedObjectsNotExecuted`)

**What it verifies:** No action with `ProtectedObject = true` has outcome `Executed`.

**Why it matters:** Protected objects are guardrailed at Gate B and at execution time. If a protected object appears as `Executed`, the protection was bypassed — this is a critical integrity violation.

**Failure message pattern:** `ProtectedObject actions that were Executed (must be Blocked): id1`

---

## Step 4: What to Do When a Check Fails

### Checks 1–2 (Binding checks)

**Implication:** The execution artifacts do not form a coherent chain. Either:
- A different approval manifest was used than the one in the evidence folder
- The evidence was assembled from multiple runs

**Action:**
1. Identify which run folder each artifact came from (check timestamps and RunId fields).
2. If artifacts are from different runs, locate the correct set and re-run replay validation against the matched set.
3. If the artifacts are confirmed to be from the same run and the hashes still mismatch, the evidence may have been modified after execution. Escalate to engagement lead.

### Checks 3–6 (Action and target authorization checks)

**Implication:** The execution evidence contains actions or targets that were not in the approval.

**Action:**
1. Extract the offending ActionIds or TargetObjectIds from the failure message.
2. Compare against the approval manifest's `ApprovedActions` list to determine whether this is a data error or a genuine unauthorized action.
3. If unauthorized: do not deliver the evidence to the client. Document the finding and escalate.
4. If data error (e.g., ActionId format mismatch): identify the root cause in the execution log and re-run with a corrected approval manifest.

### Checks 7–8 (Evidence completeness checks)

**Implication:** The execution evidence is incomplete. Failed actions lack error detail, or executed actions lack post-write confirmation.

**Action:**
1. Review the raw execution log for the affected ActionIds.
2. If the actions are recorded in the log with the correct outcomes but the evidence JSON is incomplete, the evidence export may have been truncated. Re-export using the execution log directly.
3. If the execution log itself lacks the data, the actions may have encountered an unhandled exception. Check the console transcript from the execution run.

### Checks 9–10 (Safety invariant checks)

**Implication:** A critical safety invariant was violated.

**Action:**
1. Stop the engagement immediately. Do not deliver any outputs to the client.
2. Review the raw execution log to determine whether the protected object was genuinely executed or whether the evidence was incorrectly assembled.
3. Escalate to the engagement lead and document the finding.
4. If the execution log confirms the protected object was executed, a full incident review is required.

---

## Graph Connection Requirements

Replay validation requires no Microsoft Graph connection. All 10 checks operate entirely offline against the saved JSON artifacts.

```
No Connect-MgGraph call is made during replay validation.
No tenant permissions are required.
The validation can be run on a machine with no internet access,
as long as the artifact files are accessible.
```

This means replay validation can be run:
- On an air-gapped review workstation
- By an auditor who does not have tenant access
- Weeks or months after the original execution run
- In a CI/CD pipeline as a post-execution gate

---

## Expected Output Files

| File | Description |
|---|---|
| `replay-validation-report-*.json` | Machine-readable validation report with all 10 check results |

The JSON report has the following top-level structure:

```json
{
  "SchemaVersion": "3.4",
  "ToolVersion": "Rev3.4",
  "RunId": "<run-guid>",
  "ValidatedUtc": "2026-06-02T14:30:00Z",
  "Passed": true,
  "CheckCount": 10,
  "PassedChecks": 10,
  "FailedChecks": 0,
  "Findings": [...],
  "Warnings": []
}
```

Each entry in `Findings` contains:
- `CheckName` — identifier for the specific check
- `Passed` — boolean
- `Severity` — `Info` (pass) or `Error` (fail)
- `Message` — human-readable result

Entries in `Warnings` indicate checks that were skipped because a required artifact was not provided.

---

*Entra Identity Decommissioning Control Plane Rev3.4 — Replay Validation Runbook*
