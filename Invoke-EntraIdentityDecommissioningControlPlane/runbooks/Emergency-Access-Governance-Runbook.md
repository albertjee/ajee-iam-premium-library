# Emergency Access Governance Runbook — Rev3.2

## Overview

`EmergencyAccessGovernance.psm1` (Rev3.2) is a read-only module that builds a governance model for ProtectedObject findings, emergency access accounts, and blocked remediation actions. It does not perform any write operations.

---

## Purpose

Rev3.2 identifies and catalogs:

- **Protected objects** — accounts/applications marked `ProtectedObject = true` (break-glass accounts, sync accounts, shared service accounts)
- **Emergency access accounts** — protected objects identified as emergency/break-glass accounts
- **Blocked actions** — WhatIf or approval actions that were blocked due to ProtectedObject flag
- **Hygiene gaps** — emergency access accounts that lack MFA, audit logging, or access review evidence

---

## Governance Model Generation

```powershell
Import-Module .\src\Modules\EmergencyAccessGovernance.psm1 -Force -DisableNameChecking

$model = New-DecomEmergencyAccessGovernanceModel `
    -Findings $assessmentFindings `
    -WhatIfActions $whatIfPlan.ApprovedActions `
    -ApprovalActions $approvalManifest.ApprovedActions
```

The model includes:
- `ProtectedObjectCount` — total objects with `ProtectedObject = true`
- `EmergencyAccessAccountCount` — subset identified as emergency access accounts
- `WhatIfActionsBlocked` — count of WhatIf actions blocked by ProtectedObject
- `ApprovalActionsBlocked` — count of approval actions blocked by ProtectedObject
- `HygieneGapsPresent` — true if any emergency access account has hygiene gaps

---

## Export Functions

| Function | Output | Purpose |
|---|---|---|
| `Export-DecomEmergencyAccessGovernanceReportMarkdown` | Markdown | Governance report (notes ProtectedObject safety guarantee) |
| `Export-DecomEmergencyAccessGovernanceReportHtml` | HTML | Governance report (HTML) |
| `Export-DecomProtectedObjectValidationJson` | JSON | Machine-readable protected object validation data |
| `Export-DecomProtectedObjectValidationCsv` | CSV | Tabular protected object data |

---

## ProtectedObject Safety Guarantee

Objects with `ProtectedObject = true` are never acted upon by the remediation engine, regardless of what the approval manifest contains. This check is applied:

1. In `Invoke-DecomRemediation` — before any credential is checked
2. In `Confirm-DecomActionTargetValid` — for all action types
3. In WhatIf plan generation — `ProtectedObject = true` findings are cataloged but never generate executable actions

The `EmergencyAccessGovernance.psm1` module documents which objects were protected and which planned actions were blocked as a result, providing an audit trail.

---

## Hygiene Gaps

Emergency access account hygiene gaps flagged by this module:

| Gap | Meaning |
|---|---|
| Missing MFA | Account lacks MFA registration evidence |
| No audit logging | Sign-in audit logging not confirmed |
| No access review | No confirmable access review evidence for this account |
| Stale review | Review evidence older than policy threshold |

These are informational — no automated remediation is available for emergency access accounts.

---

## Safety Notes

- `EmergencyAccessGovernance.psm1` contains no Remove-Mg, Update-Mg, Set-Mg, or New-Mg calls
- No write scopes (`ReadWrite.All`) are declared or used
- This module is included in the `Test-DecomSafetyInvariant` read-only module scan

---

© 2026 Albert Jee. All rights reserved.
