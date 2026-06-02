# Client Handoff Package
## Entra Identity Decommissioning Control Plane — Rev3.4

---

## Overview

The client handoff package is a structured, portable deliverable produced at the conclusion of every decommissioning engagement. It aggregates all assessment outputs, remediation evidence, approval artifacts, and operational guidance into a single directory that can be transmitted to the client, archived for compliance, or submitted to an audit team without further manual assembly.

The package is designed so that a client with no knowledge of the internal tooling can understand what was assessed, what actions were taken, why each action was authorized, and how to validate the outcomes independently.

---

## Functions

| Function | Purpose |
|---|---|
| `New-DecomClientHandoffPackage` | Orchestrates the full package build — calls all sub-exporters and emits the root manifest |
| `Export-DecomClientHandoffManifestJson` | Writes `ClientHandoffManifest.json` — machine-readable package index |
| `Export-DecomClientHandoffIndexMarkdown` | Writes `index.md` — human-readable table of contents |
| `Export-DecomClientHandoffChecklistMarkdown` | Writes `ClientHandoffChecklist.md` — acceptance checklist for the client contact |

---

## Running the Handoff Package

### Minimum Required Inputs

```powershell
$params = @{
    RunId              = $evidenceBundle.RunId
    EvidenceBundle     = $evidenceBundle
    TraceabilityReport = $traceReport
    ReplayValidation   = $replayResult
    OutputDirectory    = 'C:\DecomOutputs\Handoff'
    ToolVersion        = 'Rev3.4'
    SchemaVersion      = '3.4'
    ClientName         = 'Contoso Ltd'
    EngagementRef      = 'ENG-2026-001'
}

$handoff = New-DecomClientHandoffPackage @params
```

### Output Files Produced

```
ClientHandoff\
  ClientHandoffManifest.json          ← machine-readable package index
  index.md                            ← human-readable table of contents
  ClientHandoffChecklist.md           ← client acceptance checklist
  ExecSummary.md                      ← executive summary narrative
  Findings.csv                        ← all findings, redacted for client
  RemediationPlan.md                  ← approved remediation plan
  WhatIfEvidence\                     ← WhatIf simulation transcripts
  ApprovalEvidence\                   ← approval manifests and tickets
  ExecutionEvidence\                  ← write evidence and post-requery logs
  Traceability.html                   ← end-to-end trace report (HTML)
  Traceability.csv                    ← trace data (CSV, sortable)
  ReplayValidation.md                 ← replay validation results
  RedactedOutputs\                    ← ClientSafe-redacted JSON/CSV files
  Runbooks\                           ← operational guidance documents
  KnownLimitations.md                 ← scope exclusions and caveats
  NextSteps.md                        ← recommended follow-on actions
  Rev35ReadinessNote.md               ← Rev3.5 NHI audit preparation note
```

---

## Package Sections

### Executive Summary (`ExecSummary.md`)

Narrative overview of the engagement scope, identity population assessed, critical and high findings count, actions executed vs. skipped vs. blocked, and overall risk posture change. Written for a non-technical stakeholder audience. References the `RunId` and `EngagementRef` for traceability.

### Findings (`Findings.csv`)

All findings produced by the assessment phase, exported with severity, risk score, finding type, display name, and recommended action. Object IDs and tenant IDs are redacted using the `ClientSafe` redaction profile — the client sees anonymized tokens (`[REDACTED_OBJECT_ID_1]`) rather than raw GUIDs. Severity and risk score fields are always preserved.

### Remediation Plan (`RemediationPlan.md`)

The approved remediation plan document covering each finding group, the proposed action, the approval authority, the approval ticket reference, and the execution outcome. Links to corresponding approval and execution evidence files.

### WhatIf / Approval Evidence

All WhatIf simulation transcripts and approval manifests are included verbatim. These demonstrate that every executed action was pre-authorized. The approval manifest hash (`ApprovalManifestHash`) in each trace row ties back to a specific file in this section.

### Execution Evidence

Post-execution write logs, Graph API call transcripts (where applicable), and post-write requery results. These demonstrate that every approved action was carried out as described and that the system verified the outcome.

### Traceability

The end-to-end trace report in both HTML and CSV format. Each row links a finding through WhatIf generation, approval, execution, and post-write evidence. See `Traceability-Model.md` for trace row field definitions and status codes.

### Replay Validation (`ReplayValidation.md`)

Results of all 10 replay validation checks. A fully passing replay report confirms that the execution record is internally consistent and that no unapproved actions appear in the evidence. See `Replay-Validation-Model.md` for check definitions.

### Redacted Outputs

JSON, CSV, and HTML exports produced with the `ClientSafe` redaction profile applied. These files are safe to share outside the engagement team. See `Redaction-Model.md` for the complete redaction rule set.

### Runbooks

Operational guidance documents included from `docs\` — specifically the Consultant Runbook, Required Permissions guide, and any engagement-specific playbooks. These allow the client's internal team to understand ongoing maintenance requirements.

### Known Limitations (`KnownLimitations.md`)

Explicit documentation of any scope exclusions (e.g., guest accounts not in scope, privileged role exclusions, objects blocked by policy), API permission gaps encountered during the run, and any objects where evidence collection was incomplete. This section is mandatory — it must not be left empty.

### Next Steps (`NextSteps.md`)

Recommended follow-on actions for the client: re-assessment cadence, objects deferred for manual review, policy changes recommended, and prerequisites for Rev3.5 NHI/Agentic Identity Audit readiness.

### Rev3.5 Readiness Note (`Rev35ReadinessNote.md`)

A brief note explaining what Rev3.4 puts in place for the upcoming NHI/Agentic Identity Audit capability (Rev3.5), and what the client needs to do before that capability is available. See `Rev3.5-NHI-Readiness.md` for full details.

---

## Sensitive vs. Safe File Classification

| File | Classification | Notes |
|---|---|---|
| `ClientHandoffManifest.json` | Safe | Contains only metadata and file hashes |
| `index.md` | Safe | Table of contents only |
| `ClientHandoffChecklist.md` | Safe | Acceptance checklist, no sensitive data |
| `ExecSummary.md` | Safe | Redacted narrative |
| `Findings.csv` | Safe | ClientSafe profile applied |
| `RemediationPlan.md` | Safe | Redacted references |
| `WhatIfEvidence\` | **Sensitive** | May contain raw object data — do not transmit unredacted |
| `ApprovalEvidence\` | Safe | Hashes and ticket references only |
| `ExecutionEvidence\` | **Sensitive** | Contains raw Graph API responses — redact before external transmission |
| `Traceability.html` | Safe | ClientSafe profile applied |
| `Traceability.csv` | Safe | ClientSafe profile applied |
| `ReplayValidation.md` | Safe | Validation status only |
| `RedactedOutputs\` | Safe | Purpose-built for external sharing |
| `Runbooks\` | Safe | Generic operational guidance |
| `KnownLimitations.md` | Safe | Scope narrative, no object-level data |
| `NextSteps.md` | Safe | Recommendations only |
| `Rev35ReadinessNote.md` | Safe | Forward-looking readiness summary |

> **Rule:** Any file marked Sensitive must be reviewed by the engagement lead before transmission. When in doubt, run it through `Invoke-DecomRedaction` with the `ClientSafe` profile before sharing.

---

## Manifest Schema

`ClientHandoffManifest.json` is a JSON object with the following top-level fields:

```json
{
  "ManifestVersion": "3.4",
  "RunId": "...",
  "EngagementRef": "...",
  "ClientName": "...",
  "GeneratedUtc": "...",
  "ToolVersion": "Rev3.4",
  "SchemaVersion": "3.4",
  "PackageSections": [ ... ],
  "FileSHA256": { "<filename>": "<hash>", ... },
  "KnownLimitationsPresent": true,
  "ReplayValidationPassed": true,
  "TraceabilityComplete": true
}
```

The `FileSHA256` dictionary provides a SHA-256 hash for every file in the package, enabling the client to verify integrity after transmission.

---

## Acceptance Checklist

`ClientHandoffChecklist.md` contains a checklist that the client contact signs off on. It covers:

- [ ] Received and verified `ClientHandoffManifest.json` hash
- [ ] Confirmed `ReplayValidationPassed: true` in manifest
- [ ] Reviewed `KnownLimitations.md` and acknowledged scope exclusions
- [ ] Confirmed `ExecSummary.md` aligns with verbal debrief
- [ ] Stored package in compliance-designated archive location
- [ ] Scheduled re-assessment per `NextSteps.md` cadence

---

*ToolVersion: Rev3.4 | SchemaVersion: 3.4 | Module: `src\Modules\ClientHandoff.psm1`*
