# Application Ownership Governance Runbook — Rev3.2

## Overview

`ApplicationGovernance.psm1` (Rev3.2) is a read-only consultant deliverable module. It processes DEC-APP-001, DEC-APP-002, DEC-APP-003, and DEC-SPN-001 findings into a structured governance model with export functions for client deliverables.

No write actions are performed by this module. Ownership remediation (assigning or removing owners) remains a manual engagement activity.

---

## Finding IDs Covered

| FindingId | Description | Severity | Module Action |
|---|---|---|---|
| DEC-APP-001 | Application has no owner | Medium | `ReadyForOwnerApproval` readiness — plan-only |
| DEC-APP-002 | Application owned by disabled user | Critical | `ReadyForOwnerApproval` readiness — plan-only |
| DEC-APP-003 | Application has single owner | Medium | `PlanOnlySingleOwner` readiness — advisory only |
| DEC-SPN-001 | Service principal has no owner | Medium | `ReadyForOwnerApproval` readiness — plan-only |

---

## Governance Model Generation

```powershell
Import-Module .\src\Modules\ApplicationGovernance.psm1 -Force -DisableNameChecking

$model = New-DecomApplicationGovernanceModel `
    -Context @{
        ToolVersion  = 'Rev3.2'
        ClientName   = 'ClientName'
        EngagementId = 'ENG-XXXX'
        Assessor     = 'Your Name'
    } `
    -Findings $assessmentFindings
```

---

## Export Functions

| Function | Output | Purpose |
|---|---|---|
| `Export-DecomApplicationGovernanceDashboardHtml` | HTML | Executive dashboard |
| `Export-DecomApplicationOwnerReadinessJson` | JSON | Machine-readable readiness data |
| `Export-DecomApplicationOwnerReadinessCsv` | CSV | Tabular readiness data |
| `Export-DecomApplicationOwnerApprovalPacketMarkdown` | Markdown | Owner approval request packet |
| `Export-DecomApplicationOwnerApprovalPacketHtml` | HTML | Owner approval request (HTML) |
| `Export-DecomApplicationOwnershipExceptionRegisterCsv` | CSV | Exception tracking register |
| `Export-DecomApplicationGovernanceEvidenceAppendixMarkdown` | Markdown | Evidence appendix for compliance record |

---

## Readiness States

| ReadinessStatus | Meaning |
|---|---|
| `ReadyForOwnerApproval` | Finding is well-formed; owner approval action can be drafted |
| `PlanOnlySingleOwner` | Application has one owner — advisory only, no action required |
| `BlockedProtectedObject` | `ProtectedObject = true` — no action; protected from governance review |

---

## Safety Notes

- `ApplicationGovernance.psm1` contains no Remove-Mg, Update-Mg, Set-Mg, New-Mg, or Graph write calls
- No `Application.ReadWrite.All` scope is declared or used
- All export functions write to local file paths only
- This module is included in the `Test-DecomSafetyInvariant` read-only module scan

---

© 2026 Albert Jee. All rights reserved.
