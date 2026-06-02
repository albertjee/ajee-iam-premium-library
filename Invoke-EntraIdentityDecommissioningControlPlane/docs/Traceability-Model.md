# Traceability Model
## Entra Identity Decommissioning Control Plane — Rev3.4

---

## Overview

The traceability model provides end-to-end linkage from every finding produced during assessment through WhatIf simulation, approval, execution, and post-write evidence. A complete trace record allows an auditor to answer the following questions for any remediation action:

- Which finding justified this action?
- Who approved it?
- When was it executed?
- What Graph API call was made?
- Was the outcome verified after the write?
- If the action did not execute, why not?

A trace gap — a finding with no corresponding approval, or an approved action with no execution record — is explicitly surfaced in the `TraceStatus` field rather than silently omitted.

---

## Functions

| Function | Purpose |
|---|---|
| `New-DecomTraceabilityModel` | Builds the traceability model from evidence bundle artifacts |
| `Export-DecomTraceabilityReportJson` | Writes `Traceability.json` — machine-readable trace rows |
| `Export-DecomTraceabilityReportCsv` | Writes `Traceability.csv` — tabular trace data |
| `Export-DecomTraceabilityReportHtml` | Writes `Traceability.html` — styled HTML report with status color-coding |
| `Export-DecomTraceabilityReportMarkdown` | Writes `Traceability.md` — Markdown table format |

---

## Building the Traceability Model

```powershell
$traceModel = New-DecomTraceabilityModel `
    -EvidenceBundle $evidenceBundle `
    -ToolVersion    'Rev3.4' `
    -SchemaVersion  '3.4'

# Export all formats
Export-DecomTraceabilityReportJson     -Model $traceModel -OutputPath $outputDir
Export-DecomTraceabilityReportCsv      -Model $traceModel -OutputPath $outputDir
Export-DecomTraceabilityReportHtml     -Model $traceModel -OutputPath $outputDir
Export-DecomTraceabilityReportMarkdown -Model $traceModel -OutputPath $outputDir
```

---

## Trace Row Fields

Each row in the traceability model represents a single finding-action pair. One finding may produce multiple rows if it generated multiple remediation actions.

### Identity Fields

| Field | Type | Description |
|---|---|---|
| `FindingId` | UUID | Unique identifier for the finding — assigned during assessment |
| `FindingInstanceId` | UUID | Unique identifier for this specific instance of the finding type against this object — allows the same finding type to appear against multiple objects without collision |
| `Severity` | Enum | `Critical`, `High`, `Medium`, `Low`, `Informational` |
| `RiskScore` | Integer | Numeric risk score (0–100) produced by the scoring engine |
| `ObjectId` | GUID | Azure AD object identifier for the subject of the finding — redacted in client-facing exports |
| `DisplayName` | String | Display name of the subject object — preserved unless `Strict` profile applied |

### Action Fields

| Field | Type | Description |
|---|---|---|
| `ActionId` | UUID | Unique identifier for the remediation action — assigned during WhatIf generation |
| `ActionType` | String | Enumerated action type (e.g., `DisableAccount`, `RemoveGroupMembership`, `RevokeAppRole`, `RemoveExpiredCredential`, `BlockSignIn`) |
| `TargetObjectIds` | String[] | Array of object IDs that this action will modify — may differ from `ObjectId` when an action targets a relationship (e.g., removing a user from a group targets both the user and the group) |

### WhatIf Fields

| Field | Type | Description |
|---|---|---|
| `WhatIfRunId` | UUID | RunId of the WhatIf transcript that generated this action — binds the trace to the simulation phase |

### Approval Fields

| Field | Type | Description |
|---|---|---|
| `ApprovalStatus` | Enum | `Approved`, `Rejected`, `Pending`, `NotRequested` |
| `ApprovedBy` | String | UPN of the approver — null if not approved |
| `ApprovalTicket` | String | Change management ticket reference (e.g., `CHG-2026-001234`) — null if not applicable |
| `ApprovalManifestHash` | String | SHA-256 hash of the approval manifest document at time of signing |

### Execution Fields

| Field | Type | Description |
|---|---|---|
| `ExecutionOutcome` | Enum | See Trace Statuses below |
| `ExecutedUtc` | DateTime | UTC timestamp of execution — null if action was not executed |
| `GraphWriteCmdlet` | String | The Graph API PowerShell cmdlet called to execute the action (e.g., `Update-MgUser`, `Remove-MgGroupMember`) — null if not executed |
| `PostWriteRequeryStatus` | Enum | `Confirmed`, `Unconfirmed`, `NotApplicable`, `NotQueried` — result of the post-write verification step |

### Evidence and Rollback Fields

| Field | Type | Description |
|---|---|---|
| `EvidenceFile` | String | Relative path to the post-write evidence file within the evidence bundle |
| `RollbackGuidance` | String | Human-readable guidance for reversing this action if required — populated for all executed write actions |

### Trace Status Fields

| Field | Type | Description |
|---|---|---|
| `TraceStatus` | Enum | Overall trace completeness status — see Trace Statuses |
| `TraceGapReason` | String | Explanation when `TraceStatus = TraceGap` — describes what artifact is missing or inconsistent |

---

## Trace Statuses

The `TraceStatus` field summarizes the lifecycle position of each trace row. Eleven statuses are defined:

| Status | Meaning |
|---|---|
| `FindingOnly` | A finding was produced during assessment but no WhatIf action was generated. This is expected for informational findings or findings explicitly excluded from remediation scope. |
| `WhatIfGenerated` | A WhatIf action was generated for this finding but no approval decision has been recorded. The action is pending approval. |
| `Approved` | The action was approved but execution has not yet occurred. The action is in the approval queue awaiting the execution window. |
| `Rejected` | The action was explicitly rejected by the approver. No execution will occur. The `ApprovedBy` field records the rejecting authority. |
| `Executed` | The action was approved and executed. `PostWriteRequeryStatus` confirms the outcome was verified. |
| `Skipped` | The action was approved but skipped during execution — typically because a prerequisite condition was no longer met at execution time (e.g., object was deleted before the action ran). |
| `Blocked` | The action was blocked by a policy enforcement rule (e.g., protected object, scope gate, missing permission). `ErrorDetail` in the execution log explains the specific block reason. |
| `Failed` | The action was attempted but failed. The Graph API call returned an error. `ErrorDetail` records the error. No change was made to the tenant. |
| `PartialFailed` | The action was partially executed — some `TargetObjectIds` were processed successfully and others failed. `ErrorDetail` identifies which objects failed. |
| `EvidenceMissing` | The execution log records the action as executed but the expected post-write evidence file is absent from the evidence bundle. This status flags a gap in the evidence chain that requires investigation. |
| `TraceGap` | A fundamental linking failure — either the approval manifest references an `ActionId` with no corresponding WhatIf transcript entry, or an execution log entry references an `ActionId` not present in any approval manifest. `TraceGapReason` provides the specific explanation. |

### Status Lifecycle

```
FindingOnly
  └─ WhatIfGenerated
       ├─ Rejected         (terminal — no execution)
       └─ Approved
            ├─ Skipped     (terminal — execution window closed without execution)
            ├─ Blocked     (terminal — policy prevented execution)
            ├─ Failed      (terminal — execution attempted, Graph error returned)
            ├─ PartialFailed (terminal — some targets failed)
            ├─ Executed    (terminal — success, PostWriteRequery confirmed)
            └─ EvidenceMissing (terminal — executed but evidence file absent)

TraceGap   (can appear at any point — indicates a linking failure)
```

---

## Output Files

| File | Description |
|---|---|
| `Traceability.json` | Full trace model as a JSON array of trace row objects |
| `Traceability.csv` | Flat CSV — one row per trace row, all fields as columns; suitable for Excel/Power BI |
| `Traceability.html` | Styled HTML table with status color-coding: Critical/High findings in red, executed rows in green, gaps in amber, blocked/rejected in grey |
| `Traceability.md` | Markdown table — suitable for inclusion in reports and GitHub issues |

---

## Color Coding (HTML Report)

| Status | Color |
|---|---|
| `Executed` | Green |
| `Approved` / `WhatIfGenerated` | Blue |
| `Rejected` / `Blocked` / `Skipped` | Grey |
| `Failed` / `PartialFailed` | Orange |
| `EvidenceMissing` / `TraceGap` | Amber |
| Severity: Critical | Red row highlight |
| Severity: High | Orange row highlight |

---

## Completeness Metrics

The traceability model summary object includes the following counts for reporting:

```json
{
  "TotalFindings": 142,
  "TotalTraceRows": 189,
  "StatusCounts": {
    "FindingOnly": 12,
    "WhatIfGenerated": 0,
    "Approved": 0,
    "Rejected": 5,
    "Executed": 160,
    "Skipped": 3,
    "Blocked": 7,
    "Failed": 0,
    "PartialFailed": 0,
    "EvidenceMissing": 0,
    "TraceGap": 0
  },
  "TraceCompleteness": "100%",
  "TraceGapsPresent": false
}
```

`TraceCompleteness` is the percentage of trace rows with a terminal status (any status other than `WhatIfGenerated` or `Approved` after the execution window has closed). A run is considered fully traced when `TraceCompleteness = 100%` and `TraceGapsPresent = false`.

---

*ToolVersion: Rev3.4 | SchemaVersion: 3.4 | Module: `src\Modules\Traceability.psm1`*
