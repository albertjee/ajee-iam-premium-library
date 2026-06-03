# Entra Identity Decommissioning — Remediation Plan
## Rev1.2 Consultant Readiness

| Field           | Value             |
|-----------------|-------------------|
| Client          | Not specified       |
| Engagement ID   | Not specified            |
| Assessor        | Not specified         |
| Assessment Date | 2026-05-31 17:37:03 UTC          |
| Mode            | Assessment      |

> **Safety Note:** This plan documents recommended remediation actions identified during an Assessment-mode run.
> This plan does not execute any actions. All remediation requires manual review and explicit approval before execution.

---
## Immediate Actions (Critical + High)

### ACT-001 — DEC-USER-003: Alex Mercer

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-001                                                        |
| Finding ID           | DEC-USER-003                                            |
| Severity             | Critical (Risk Score: 92)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0001-0001-0001-000000000001                                             |
| Display Name         | Alex Mercer                                          |
| Evidence             | Disabled user retains Global Administrator role assignment                                             |
| Recommended Action   | Remove Global Administrator role assignment from disabled user alex.mercer@contoso.com                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-USER-003                                            |

---
### ACT-002 — DEC-ROLE-001: Sam Okafor

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-002                                                        |
| Finding ID           | DEC-ROLE-001                                            |
| Severity             | Critical (Risk Score: 90)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0016-0016-0016-000000000016                                             |
| Display Name         | Sam Okafor                                          |
| Evidence             | Disabled user holds active Privileged Role Administrator assignment — account is disabled                                             |
| Recommended Action   | Remove Privileged Role Administrator assignment from disabled user sam.okafor@contoso.com immediately                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-ROLE-001                                            |

---
### ACT-003 — DEC-APP-002: Contoso Analytics API

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-003                                                        |
| Finding ID           | DEC-APP-002                                            |
| Severity             | Critical (Risk Score: 88)         |
| Object Type          | Application                                           |
| Object ID            | a1b2c3d4-0002-0002-0002-000000000002                                             |
| Display Name         | Contoso Analytics API                                          |
| Evidence             | Application owned exclusively by disabled user alex.mercer@contoso.com — no active owner remains                                             |
| Recommended Action   | Assign active owner to Contoso Analytics API; remove disabled user alex.mercer@contoso.com as owner                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-APP-002                                            |

---
### ACT-004 — DEC-PIM-001: Disabled Admin (PIM)

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-004                                                        |
| Finding ID           | DEC-PIM-001                                            |
| Severity             | Critical (Risk Score: 86)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0019-0019-0019-000000000019                                             |
| Display Name         | Disabled Admin (PIM)                                          |
| Evidence             | Disabled user retains eligible privileged role assignment. Eligibility should be reviewed before account closure is considered complete.                                             |
| Recommended Action   | Review and remove eligible privileged role assignment from disabled user disabled.admin@contoso.com                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-PIM-001                                            |

---
### ACT-005 — DEC-GUEST-002: ext_partner@fabrikam.com

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-005                                                        |
| Finding ID           | DEC-GUEST-002                                            |
| Severity             | Critical (Risk Score: 85)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0003-0003-0003-000000000003                                             |
| Display Name         | ext_partner@fabrikam.com                                          |
| Evidence             | Guest account holds User Administrator role — no sponsor metadata                                             |
| Recommended Action   | Review guest privileged access; assign sponsor; consider role removal                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-GUEST-002                                            |

---
### ACT-006 — DEC-PIM-002: ext_privileged@fabrikam.com

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-006                                                        |
| Finding ID           | DEC-PIM-002                                            |
| Severity             | Critical (Risk Score: 84)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0020-0020-0020-000000000020                                             |
| Display Name         | ext_privileged@fabrikam.com                                          |
| Evidence             | Guest identity retains eligible privileged role assignment. Review external privileged access governance and sponsor approval.                                             |
| Recommended Action   | Review and remove eligible privileged role from guest; confirm sponsor approval for any continued access                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-PIM-002                                            |

---
### ACT-007 — DEC-PIM-006: eligible.stalereview@contoso.com

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-007                                                        |
| Finding ID           | DEC-PIM-006                                            |
| Severity             | High (Risk Score: 73)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0034-0034-0034-000000000034                                             |
| Display Name         | eligible.stalereview@contoso.com                                          |
| Evidence             | PIM eligible privileged role assignment last reviewed 2025-09-15 — more than 180 days ago. Review has lapsed.                                             |
| Recommended Action   | Initiate new access review for PIM eligible assignment for eligible.stalereview@contoso.com.                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-PIM-006                                            |

---
### ACT-008 — DEC-USER-002: Morgan Chen

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-008                                                        |
| Finding ID           | DEC-USER-002                                            |
| Severity             | High (Risk Score: 72)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0014-0014-0014-000000000014                                             |
| Display Name         | Morgan Chen                                          |
| Evidence             | Disabled user retains 3 app role assignments: Salesforce Admin, SAP HR Read, Workday Integrations                                             |
| Recommended Action   | Revoke all app role assignments for disabled user morgan.chen@contoso.com                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-USER-002                                            |

---
### ACT-009 — DEC-GREV-003: ext_privileged_norev@fabrikam.com

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-009                                                        |
| Finding ID           | DEC-GREV-003                                            |
| Severity             | High (Risk Score: 72)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0032-0032-0032-000000000032                                             |
| Display Name         | ext_privileged_norev@fabrikam.com                                          |
| Evidence             | Guest holds privileged access (PIM eligible or directory role) and no access review decision found — privileged external access is ungoverned.                                             |
| Recommended Action   | Immediately create access review for privileged guest ext_privileged_norev@fabrikam.com; escalate to security team.                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-GREV-003                                            |

---
### ACT-010 — DEC-PIM-005: eligible.noreview@contoso.com

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-010                                                        |
| Finding ID           | DEC-PIM-005                                            |
| Severity             | High (Risk Score: 70)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0033-0033-0033-000000000033                                             |
| Display Name         | eligible.noreview@contoso.com                                          |
| Evidence             | PIM eligible privileged role assignment found but no access review decision evidence detected — governance review cannot be confirmed.                                             |
| Recommended Action   | Create access review for PIM eligible assignment for eligible.noreview@contoso.com and confirm review completion.                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-PIM-005                                            |

---
### ACT-011 — DEC-CA-004: CA-MFA-Exclusion-StaleReview

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-011                                                        |
| Finding ID           | DEC-CA-004                                            |
| Severity             | High (Risk Score: 70)         |
| Object Type          | Group                                           |
| Object ID            | a1b2c3d4-0038-0038-0038-000000000038                                             |
| Display Name         | CA-MFA-Exclusion-StaleReview                                          |
| Evidence             | CA policy exclusion group last reviewed 2025-08-01 — more than 90 days ago. Review has lapsed for CA exclusion governance.                                             |
| Recommended Action   | Initiate new access review for CA-MFA-Exclusion-StaleReview to re-validate CA exclusion membership.                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-004                                            |

---
### ACT-012 — DEC-AP-001: Offboarded Employee

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-012                                                        |
| Finding ID           | DEC-AP-001                                            |
| Severity             | High (Risk Score: 70)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0021-0021-0021-000000000021                                             |
| Display Name         | Offboarded Employee                                          |
| Evidence             | Disabled user retains access package assignment. Review Entitlement Management lifecycle closure.                                             |
| Recommended Action   | Review and remove access package assignment from disabled user offboarded.employee@contoso.com                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-AP-001                                            |

---
### ACT-013 — DEC-APP-005: Legacy SSO Connector

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-013                                                        |
| Finding ID           | DEC-APP-005                                            |
| Severity             | High (Risk Score: 68)         |
| Object Type          | Application                                           |
| Object ID            | a1b2c3d4-0012-0012-0012-000000000012                                             |
| Display Name         | Legacy SSO Connector                                          |
| Evidence             | Client secret expired 47 days ago (2026-04-13) — credential still attached to application                                             |
| Recommended Action   | Remove expired credential from Legacy SSO Connector and rotate if integration still active                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-APP-005                                            |

---
### ACT-014 — DEC-CA-003: CA-MFA-Exclusion-NoReview

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-014                                                        |
| Finding ID           | DEC-CA-003                                            |
| Severity             | High (Risk Score: 68)         |
| Object Type          | Group                                           |
| Object ID            | a1b2c3d4-0037-0037-0037-000000000037                                             |
| Display Name         | CA-MFA-Exclusion-NoReview                                          |
| Evidence             | CA policy exclusion group has no correlated access review definition — members are excluded from policy without review governance.                                             |
| Recommended Action   | Create access review definition scoped to CA-MFA-Exclusion-NoReview group to govern CA exclusion membership.                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-003                                            |

---
### ACT-015 — DEC-AP-005: contractor2@fabrikam.com

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-015                                                        |
| Finding ID           | DEC-AP-005                                            |
| Severity             | High (Risk Score: 68)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0024-0024-0024-000000000024                                             |
| Display Name         | contractor2@fabrikam.com                                          |
| Evidence             | Access package assignment appears linked to sensitive resource or group based on resource metadata/name heuristic.                                             |
| Recommended Action   | Review access package assignment linked to sensitive resource; confirm business justification and governance approval                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-AP-005                                            |

---
### ACT-016 — DEC-AP-008: contractor_pending@northwind.com

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-016                                                        |
| Finding ID           | DEC-AP-008                                            |
| Severity             | High (Risk Score: 66)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0036-0036-0036-000000000036                                             |
| Display Name         | contractor_pending@northwind.com                                          |
| Evidence             | Access package assignment review decision is incomplete or not reviewed — reviewer action required.                                             |
| Recommended Action   | Follow up with reviewer to complete access review decision for contractor_pending@northwind.com.                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-AP-008                                            |

---
### ACT-017 — DEC-CA-001: Require MFA

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-017                                                        |
| Finding ID           | DEC-CA-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | Policy                                           |
| Object ID            | a1b2c3d4-0006-0006-0006-000000000006                                             |
| Display Name         | Require MFA                                          |
| Evidence             | CA policy excludes 3 users and 2 groups from MFA requirement — exclusions require review                                             |
| Recommended Action   | Review and reduce exclusions in policy; initiate access review for excluded identities                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-001                                            |

---
### ACT-018 — DEC-USER-001: Jordan Riley

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-018                                                        |
| Finding ID           | DEC-USER-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0004-0004-0004-000000000004                                             |
| Display Name         | Jordan Riley                                          |
| Evidence             | Disabled user retains membership in 4 groups including IT-Admins                                             |
| Recommended Action   | Remove jordan.riley@contoso.com from all group memberships                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-USER-001                                            |

---
### ACT-019 — DEC-GREV-002: ext_unsponsored@tailspin.com

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-019                                                        |
| Finding ID           | DEC-GREV-002                                            |
| Severity             | High (Risk Score: 63)         |
| Object Type          | User                                           |
| Object ID            | a1b2c3d4-0031-0031-0031-000000000031                                             |
| Display Name         | ext_unsponsored@tailspin.com                                          |
| Evidence             | Guest account lacks sponsor metadata and no access review decision found — business justification cannot be confirmed.                                             |
| Recommended Action   | Assign a sponsor to ext_unsponsored@tailspin.com and create access review; consider offboarding if no sponsor can be identified.                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-GREV-002                                            |

---
### ACT-020 — DEC-CA-002: CA-MFA-Exclusion-VendorAccounts

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-020                                                        |
| Finding ID           | DEC-CA-002                                            |
| Severity             | High (Risk Score: 62)         |
| Object Type          | Group                                           |
| Object ID            | a1b2c3d4-0018-0018-0018-000000000018                                             |
| Display Name         | CA-MFA-Exclusion-VendorAccounts                                          |
| Evidence             | CA exclusion group CA-MFA-Exclusion-VendorAccounts has 8 members — access review status unknown                                             |
| Recommended Action   | Create access review for CA-MFA-Exclusion-VendorAccounts; validate all 8 members still require CA exclusion                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-002                                            |

---
## Review Queue (Medium)

### ACT-021 — DEC-AP-007: contractor_stale_review@northwind.com

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-021                                  |
| Finding ID         | DEC-AP-007                      |
| Severity           | Medium (Risk Score: 54) |
| Object Type        | User                     |
| Display Name       | contractor_stale_review@northwind.com                    |
| Evidence           | Access package assignment has no review decision within 180 days — review evidence stale or unavailable.                       |
| Recommended Action | Initiate access review for access package assignment for contractor_stale_review@northwind.com.              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Stale or missing review decision for access package assignment                 |

---
### ACT-022 — DEC-AP-002: ext_vendor2@tailspin.com

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-022                                  |
| Finding ID         | DEC-AP-002                      |
| Severity           | Medium (Risk Score: 52) |
| Object Type        | User                     |
| Display Name       | ext_vendor2@tailspin.com                    |
| Evidence           | Guest has access package assignment; sponsor or review status requires validation.                       |
| Recommended Action | Confirm sponsor approval and review status for guest access package assignment              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Guest access package requires explicit sponsor validation                 |

---
### ACT-023 — DEC-APP-001: Reporting Daemon SP

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-023                                  |
| Finding ID         | DEC-APP-001                      |
| Severity           | Medium (Risk Score: 51) |
| Object Type        | Application                     |
| Display Name       | Reporting Daemon SP                    |
| Evidence           | Application has no owner assigned                       |
| Recommended Action | Assign accountable owner to Reporting Daemon SP              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals are a governance gap                 |

---
### ACT-024 — DEC-AP-006: Access Package Review Coverage

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-024                                  |
| Finding ID         | DEC-AP-006                      |
| Severity           | Medium (Risk Score: 50) |
| Object Type        | TenantScope                     |
| Display Name       | Access Package Review Coverage                    |
| Evidence           | Access package assignments found but no access review definition correlated to entitlement management scope — review coverage cannot be confirmed.                       |
| Recommended Action | Create access review definitions scoped to entitlement management access packages.              |
| Approval Status    | PendingReview                              |
| Consultant Note    | No AR definition found for entitlement management — coverage gap                 |

---
### ACT-025 — DEC-GREV-001: ext_review_missing@fabrikam.com

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-025                                  |
| Finding ID         | DEC-GREV-001                      |
| Severity           | Medium (Risk Score: 48) |
| Object Type        | User                     |
| Display Name       | ext_review_missing@fabrikam.com                    |
| Evidence           | Guest account has no access review decision found within the last 90 days — review coverage cannot be confirmed.                       |
| Recommended Action | Schedule or confirm access review for guest ext_review_missing@fabrikam.com and ensure decision is recorded.              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Guest access review coverage gap — no decision evidence within threshold                 |

---
### ACT-026 — DEC-APP-004: DevOps Pipeline SP

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-026                                  |
| Finding ID         | DEC-APP-004                      |
| Severity           | Medium (Risk Score: 48) |
| Object Type        | Application                     |
| Display Name       | DevOps Pipeline SP                    |
| Evidence           | Client secret expires in 14 days (2026-06-13) — renewal not confirmed                       |
| Recommended Action | Rotate expiring client secret for DevOps Pipeline SP before 2026-06-13              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Expiring secrets cause integration failures and may trigger emergency access patterns                 |

---
### ACT-027 — DEC-AP-003: contractor@northwind.com

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-027                                  |
| Finding ID         | DEC-AP-003                      |
| Severity           | Medium (Risk Score: 48) |
| Object Type        | User                     |
| Display Name       | contractor@northwind.com                    |
| Evidence           | Access package assignment does not expose expiration evidence; review assignment lifecycle policy.                       |
| Recommended Action | Review access package lifecycle policy and set expiration for assignment              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Assignment without expiration evidence requires lifecycle review                 |

---
### ACT-028 — DEC-GUEST-003: ext_contractor@northwind.com

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-028                                  |
| Finding ID         | DEC-GUEST-003                      |
| Severity           | Medium (Risk Score: 47) |
| Object Type        | User                     |
| Display Name       | ext_contractor@northwind.com                    |
| Evidence           | Guest account has no manager assigned and no department metadata — sponsor cannot be determined                       |
| Recommended Action | Assign a sponsor (manager) and department to ext_contractor@northwind.com or initiate offboarding              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Guest without sponsor metadata cannot be traced to a business owner                 |

---
### ACT-029 — DEC-PIM-003: PIM Coverage

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-029                                  |
| Finding ID         | DEC-PIM-003                      |
| Severity           | Medium (Risk Score: 46) |
| Object Type        | Tenant                     |
| Display Name       | PIM Coverage                    |
| Evidence           | PIM activation and review evidence could not be confirmed from available Graph data. Coverage may be partial.                       |
| Recommended Action | Grant PrivilegedAccess.Read.AzureAD permission and re-run assessment for full PIM coverage              |
| Approval Status    | PendingReview                              |
| Consultant Note    | PIM evidence gap — not a finding against tenant configuration                 |

---
### ACT-030 — DEC-APP-003: Finance Reporting App

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-030                                  |
| Finding ID         | DEC-APP-003                      |
| Severity           | Medium (Risk Score: 45) |
| Object Type        | Application                     |
| Display Name       | Finance Reporting App                    |
| Evidence           | Application has only 1 owner — single point of failure for ownership continuity                       |
| Recommended Action | Add a second owner to Finance Reporting App to ensure ownership continuity              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Single-owner apps are a governance risk if that owner leaves or is disabled                 |

---
### ACT-031 — DEC-AP-004: Access Package Review Coverage

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-031                                  |
| Finding ID         | DEC-AP-004                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | Tenant                     |
| Display Name       | Access Package Review Coverage                    |
| Evidence           | Access package review coverage could not be confirmed from available Graph data.                       |
| Recommended Action | Grant AccessReview.Read.All and re-run assessment for full access review coverage              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Access review coverage gap — not a finding against tenant configuration                 |

---
### ACT-032 — DEC-SPN-001: Azure Backup Agent SP

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-032                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | Azure Backup Agent SP                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to Azure Backup Agent SP              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
## Monitor / Hygiene (Low + Informational)

| FindingId | DisplayName | Evidence |
|-----------|-------------|----------|
| DEC-GUEST-001 | ext_vendor@tailspin.com | Guest last sign-in 210 days ago — no access review coverage |
| DEC-PIM-007 | PIM Review Correlation | PIM eligible assignment findings detected but access review data unavailable — review correlation could not be performed. |
| DEC-REV-001 | Access Review Decision Coverage | Access review definitions found but no review decision records returned — coverage may be partial or reviews may be newly configured. |
| DEC-GOV-001 | Access Review API Coverage | Access review API cmdlets unavailable — review governance coverage could not be assessed. AccessReview.Read.All permission may be missing. |
| DEC-IGA-001 | Entitlement Management | AuditLog.Read.All scope unavailable — IGA coverage assessment incomplete |
| DEC-GOV-002 | Access Review Cmdlet Coverage | Access review cmdlet (Get-MgIdentityGovernanceAccessReviewDefinition) is not available in the installed Graph module version — upgrade may be required. |

---

## Notes

- All Immediate Actions and Review Queue items require explicit client approval before execution.
- This plan was generated by Entra Identity Decommissioning Control Plane Rev1.2.
- For questions about this plan, contact the assessor listed above.
- To execute approved remediation actions, re-run the tool with `-Mode ExecuteRemediation` after obtaining approvals (future release).

*Entra Identity Decommissioning Control Plane Rev1.2 — Consultant Advisory Tool*
