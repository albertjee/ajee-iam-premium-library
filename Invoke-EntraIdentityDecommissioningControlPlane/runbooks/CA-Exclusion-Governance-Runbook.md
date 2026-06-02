# CA Exclusion Governance Runbook — Rev3.2

## Overview

`ConditionalAccessGovernance.psm1` (Rev3.2) is a read-only consultant deliverable module. It processes DEC-CA-001 through DEC-CA-004 findings into a structured governance model for CA exclusion review, exception tracking, and remediation design.

No CA policy mutations are performed in Rev3.2. CA exclusion group membership removal (`RemoveCAExclusionGroupMember`) is deferred to Rev3.3 after QA approval.

---

## Finding IDs Covered

| FindingId | Description | Severity | Module Action |
|---|---|---|---|
| DEC-CA-001 | CA policy has user/group exclusions requiring review | High | `ManualRemediationRequired` — advisory |
| DEC-CA-002 | CA exclusion group membership requires access review | High | `Rev33WriteCandidate` (with review) or `ManualRemediationRequired` |
| DEC-CA-003 | CA exclusion group lacks confirmable access review evidence | High | `HighRiskExclusionManualRequired` or `ManualRemediationRequired` |
| DEC-CA-004 | CA exclusion review evidence stale or unavailable | High | `ReviewRequired` |

---

## Readiness States

| ReadinessStatus | Meaning |
|---|---|
| `Rev33WriteCandidate` | DEC-CA-002 with clean review evidence — candidate for future RemoveCAExclusionGroupMember |
| `ManualRemediationRequired` | No review evidence or inconclusive — manual owner review required |
| `ConflictingReviewEvidence` | Review evidence conflicts with current exclusion state |
| `HighRiskExclusionManualRequired` | High-risk exclusion (DEC-CA-003) — manual governance required |
| `ReviewRequired` | Stale evidence (DEC-CA-004) — schedule a new access review |

---

## Governance Model Generation

```powershell
Import-Module .\src\Modules\ConditionalAccessGovernance.psm1 -Force -DisableNameChecking

$model = New-DecomCaExclusionGovernanceModel `
    -Context @{
        ToolVersion  = 'Rev3.2'
        ClientName   = 'ClientName'
        EngagementId = 'ENG-XXXX'
        Assessor     = 'Your Name'
        TenantId     = '<tenant-id>'
    } `
    -Findings $assessmentFindings
```

---

## Export Functions

| Function | Output | Purpose |
|---|---|---|
| `Export-DecomCaExclusionGovernanceDashboardHtml` | HTML | Executive CA exclusion dashboard |
| `Export-DecomCaExclusionReadinessJson` | JSON | Machine-readable readiness data |
| `Export-DecomCaExclusionReadinessCsv` | CSV | Tabular readiness data |
| `Export-DecomCaExclusionOwnerReviewPacketMarkdown` | Markdown | Owner review packet (notes Rev3.2 read-only constraint) |
| `Export-DecomCaExclusionOwnerReviewPacketHtml` | HTML | Owner review packet (HTML) |
| `Export-DecomCaExclusionExceptionRegisterCsv` | CSV | Exception register for governance documentation |
| `Export-DecomCaExclusionRemediationDesignMarkdown` | Markdown | Remediation design (notes no CA policy mutations in Rev3.2) |

---

## Safety Notes

- `ConditionalAccessGovernance.psm1` contains no Remove-Mg, Update-Mg, Set-Mg, or New-MgIdentityConditionalAccessPolicy calls
- No `Policy.ReadWrite.*` scope is declared or used
- CA policy objects are never mutated — this is a read-only governance and reporting module
- This module is included in the `Test-DecomSafetyInvariant` read-only module scan

---

## Rev3.3 Design Candidate

`RemoveCAExclusionGroupMember` is a Rev3.3 design candidate for DEC-CA-002 findings with clean review evidence (`Rev33WriteCandidate` status). It is not implemented in Rev3.2. When implemented, it will require:

- `GroupMember.ReadWrite.All` write scope
- SchemaVersion ≥ 3.3 in approval manifest
- Pre-flight confirmation that removing the group member does not orphan the CA policy exclusion

---

© 2026 Albert Jee. All rights reserved.
