# Entra Identity Decommissioning — Remediation Plan
## Rev1.1 Consultant Readiness

| Field          | Value                  |
|----------------|------------------------|
| Client         | Contoso Ltd            |
| Engagement ID  | ENG-DEMO-001                 |
| Assessor       | Albert Jee              |
| Assessment Date| 2026-05-29 23:56:18 UTC               |
| Mode           | Assessment           |

> **Safety Note:** This plan documents recommended remediation actions identified during an Assessment-mode run.
> This plan does not execute any actions. All remediation requires manual review and explicit approval before execution.

---

## Remediation Actions
### ACT-001 — DEC-USER-003: Alex Mercer

| Field                | Value                                                                 |
|----------------------|-----------------------------------------------------------------------|
| Action ID            | ACT-001                                                             |
| Finding ID           | DEC-USER-003                                                 |
| Severity             | Critical (Risk Score: 92)              |
| Object Type          | User                                                |
| Object ID            | a1b2c3d4-0001-0001-0001-000000000001                                                  |
| Display Name         | Alex Mercer                                               |
| Evidence             | Disabled user retains Global Administrator role assignment                                                  |
| Recommended Action   | Remove Global Administrator role assignment from disabled user alex.mercer@contoso.com                                         |
| Business Owner       | [To be confirmed]                                                     |
| Approval Required    | Yes                                                                   |
| Approval Status      | PendingReview                                                         |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment]      |
| Rollback Note        | [Document current state before execution]                             |
| Evidence Reference   | DEC-USER-003                                                 |

---
### ACT-002 — DEC-APP-002: Contoso Analytics API

| Field                | Value                                                                 |
|----------------------|-----------------------------------------------------------------------|
| Action ID            | ACT-002                                                             |
| Finding ID           | DEC-APP-002                                                 |
| Severity             | High (Risk Score: 79)              |
| Object Type          | Application                                                |
| Object ID            | a1b2c3d4-0002-0002-0002-000000000002                                                  |
| Display Name         | Contoso Analytics API                                               |
| Evidence             | Application owned exclusively by disabled user alex.mercer@contoso.com                                                  |
| Recommended Action   | Assign active owner to Contoso Analytics API; remove disabled user as owner                                         |
| Business Owner       | [To be confirmed]                                                     |
| Approval Required    | Yes                                                                   |
| Approval Status      | PendingReview                                                         |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment]      |
| Rollback Note        | [Document current state before execution]                             |
| Evidence Reference   | DEC-APP-002                                                 |

---
### ACT-003 — DEC-GUEST-002: ext_partner@fabrikam.com

| Field                | Value                                                                 |
|----------------------|-----------------------------------------------------------------------|
| Action ID            | ACT-003                                                             |
| Finding ID           | DEC-GUEST-002                                                 |
| Severity             | High (Risk Score: 78)              |
| Object Type          | User                                                |
| Object ID            | a1b2c3d4-0003-0003-0003-000000000003                                                  |
| Display Name         | ext_partner@fabrikam.com                                               |
| Evidence             | Guest account holds User Administrator role — no sponsor metadata                                                  |
| Recommended Action   | Review guest privileged access; assign sponsor; consider role removal                                         |
| Business Owner       | [To be confirmed]                                                     |
| Approval Required    | Yes                                                                   |
| Approval Status      | PendingReview                                                         |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment]      |
| Rollback Note        | [Document current state before execution]                             |
| Evidence Reference   | DEC-GUEST-002                                                 |

---
## Notes

- All actions in this plan require explicit client approval before execution.
- This plan was generated by Entra Identity Decommissioning Control Plane Rev1.1.
- For questions about this plan, contact the assessor listed above.
- To execute approved remediation actions, re-run the tool with `-Mode ExecuteRemediation` after obtaining approvals.

*Entra Identity Decommissioning Control Plane Rev1.1 — Consultant Advisory Tool*
