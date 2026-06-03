# Entra Identity Decommissioning — Remediation Plan
## Rev1.2 Consultant Readiness

| Field           | Value             |
|-----------------|-------------------|
| Client          | Newport High PTSA       |
| Engagement ID   | ENG-002            |
| Assessor        | Albert Jee         |
| Assessment Date | 2026-06-01 01:37:41 UTC          |
| Mode            | Assessment      |

> **Safety Note:** This plan documents recommended remediation actions identified during an Assessment-mode run.
> This plan does not execute any actions. All remediation requires manual review and explicit approval before execution.

---
## Immediate Actions (Critical + High)

### ACT-001 — DEC-CA-003: Exclude from CA

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-001                                                        |
| Finding ID           | DEC-CA-003                                            |
| Severity             | High (Risk Score: 68)         |
| Object Type          | Group                                           |
| Object ID            | 171b0f85-04f6-4946-97f3-5a7e6bc1987f                                             |
| Display Name         | Exclude from CA                                          |
| Evidence             | CA policy exclusion group 'Exclude from CA' has no correlated access review definition — members excluded without review governance.                                             |
| Recommended Action   | Create access review definition scoped to 'Exclude from CA' group to govern CA exclusion membership.                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-003                                            |

---
### ACT-002 — DEC-APP-005: PowerShelltoTeamsGraphAPI

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-002                                                        |
| Finding ID           | DEC-APP-005                                            |
| Severity             | High (Risk Score: 68)         |
| Object Type          | Application                                           |
| Object ID            | ce472608-cabf-468c-a816-c214e17cbb17                                             |
| Display Name         | PowerShelltoTeamsGraphAPI                                          |
| Evidence             | Client secret 'albert demo secret' expired 1272 days ago (2022-12-07) — still attached to application                                             |
| Recommended Action   | Remove expired Client secret from 'PowerShelltoTeamsGraphAPI' and rotate if integration still active                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-APP-005                                            |

---
### ACT-003 — DEC-CA-001: Microsoft-managed: Block device code flow

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-003                                                        |
| Finding ID           | DEC-CA-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | Policy                                           |
| Object ID            | ba681662-e32b-4e83-95c6-03ccceb73ca8                                             |
| Display Name         | Microsoft-managed: Block device code flow                                          |
| Evidence             | CA policy excludes 1 user(s) and 0 group(s) from policy scope                                             |
| Recommended Action   | Review and reduce exclusions in 'Microsoft-managed: Block device code flow'; initiate access review for excluded identities                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-001                                            |

---
### ACT-004 — DEC-CA-001: CA005: Require multifactor authentication for guest access

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-004                                                        |
| Finding ID           | DEC-CA-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | Policy                                           |
| Object ID            | fdde5940-f993-4118-b169-da9d3c7d50b2                                             |
| Display Name         | CA005: Require multifactor authentication for guest access                                          |
| Evidence             | CA policy excludes 1 user(s) and 0 group(s) from policy scope                                             |
| Recommended Action   | Review and reduce exclusions in 'CA005: Require multifactor authentication for guest access'; initiate access review for excluded identities                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-001                                            |

---
### ACT-005 — DEC-CA-001: CA902 Session Admin Persistence

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-005                                                        |
| Finding ID           | DEC-CA-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | Policy                                           |
| Object ID            | 37e7dd4e-144a-4491-9211-2fd40705372d                                             |
| Display Name         | CA902 Session Admin Persistence                                          |
| Evidence             | CA policy excludes 0 user(s) and 1 group(s) from policy scope                                             |
| Recommended Action   | Review and reduce exclusions in 'CA902 Session Admin Persistence'; initiate access review for excluded identities                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-001                                            |

---
### ACT-006 — DEC-CA-001: CA901 Block usagr from outside USA

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-006                                                        |
| Finding ID           | DEC-CA-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | Policy                                           |
| Object ID            | c94c8fde-dc65-448e-bb2a-b29bd94c10d4                                             |
| Display Name         | CA901 Block usagr from outside USA                                          |
| Evidence             | CA policy excludes 2 user(s) and 0 group(s) from policy scope                                             |
| Recommended Action   | Review and reduce exclusions in 'CA901 Block usagr from outside USA'; initiate access review for excluded identities                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-001                                            |

---
### ACT-007 — DEC-CA-001: CA001: Require multifactor authentication for admins

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-007                                                        |
| Finding ID           | DEC-CA-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | Policy                                           |
| Object ID            | bedd5488-9202-46af-8cc7-690019cd0d57                                             |
| Display Name         | CA001: Require multifactor authentication for admins                                          |
| Evidence             | CA policy excludes 2 user(s) and 1 group(s) from policy scope                                             |
| Recommended Action   | Review and reduce exclusions in 'CA001: Require multifactor authentication for admins'; initiate access review for excluded identities                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-001                                            |

---
### ACT-008 — DEC-CA-001: CA006: Require multifactor authentication for Azure management

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-008                                                        |
| Finding ID           | DEC-CA-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | Policy                                           |
| Object ID            | bcc81919-6f02-4593-9aa6-49e2885af912                                             |
| Display Name         | CA006: Require multifactor authentication for Azure management                                          |
| Evidence             | CA policy excludes 1 user(s) and 1 group(s) from policy scope                                             |
| Recommended Action   | Review and reduce exclusions in 'CA006: Require multifactor authentication for Azure management'; initiate access review for excluded identities                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-001                                            |

---
### ACT-009 — DEC-CA-001: CA003: Block legacy authentication

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-009                                                        |
| Finding ID           | DEC-CA-001                                            |
| Severity             | High (Risk Score: 65)         |
| Object Type          | Policy                                           |
| Object ID            | 00ae77ad-3852-41f3-919f-fcd66f73c8d7                                             |
| Display Name         | CA003: Block legacy authentication                                          |
| Evidence             | CA policy excludes 2 user(s) and 0 group(s) from policy scope                                             |
| Recommended Action   | Review and reduce exclusions in 'CA003: Block legacy authentication'; initiate access review for excluded identities                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-001                                            |

---
### ACT-010 — DEC-CA-002: Exclude from CA

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-010                                                        |
| Finding ID           | DEC-CA-002                                            |
| Severity             | High (Risk Score: 62)         |
| Object Type          | Group                                           |
| Object ID            | 171b0f85-04f6-4946-97f3-5a7e6bc1987f                                             |
| Display Name         | Exclude from CA                                          |
| Evidence             | CA exclusion group 'Exclude from CA' has 3 members in policy 'CA902 Session Admin Persistence' — access review status unknown                                             |
| Recommended Action   | Create access review for 'Exclude from CA'; validate all 3 members still require CA exclusion                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-002                                            |

---
### ACT-011 — DEC-CA-002: Exclude from CA

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-011                                                        |
| Finding ID           | DEC-CA-002                                            |
| Severity             | High (Risk Score: 62)         |
| Object Type          | Group                                           |
| Object ID            | 171b0f85-04f6-4946-97f3-5a7e6bc1987f                                             |
| Display Name         | Exclude from CA                                          |
| Evidence             | CA exclusion group 'Exclude from CA' has 3 members in policy 'CA001: Require multifactor authentication for admins' — access review status unknown                                             |
| Recommended Action   | Create access review for 'Exclude from CA'; validate all 3 members still require CA exclusion                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-002                                            |

---
### ACT-012 — DEC-CA-002: Exclude from CA

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | ACT-012                                                        |
| Finding ID           | DEC-CA-002                                            |
| Severity             | High (Risk Score: 62)         |
| Object Type          | Group                                           |
| Object ID            | 171b0f85-04f6-4946-97f3-5a7e6bc1987f                                             |
| Display Name         | Exclude from CA                                          |
| Evidence             | CA exclusion group 'Exclude from CA' has 3 members in policy 'CA006: Require multifactor authentication for Azure management' — access review status unknown                                             |
| Recommended Action   | Create access review for 'Exclude from CA'; validate all 3 members still require CA exclusion                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | DEC-CA-002                                            |

---
## Review Queue (Medium)

### ACT-013 — DEC-APP-001: aljee demo

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-013                                  |
| Finding ID         | DEC-APP-001                      |
| Severity           | Medium (Risk Score: 51) |
| Object Type        | Application                     |
| Display Name       | aljee demo                    |
| Evidence           | Application has no owner assigned                       |
| Recommended Action | Assign accountable owner to application 'aljee demo'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless applications are a governance gap                 |

---
### ACT-014 — DEC-APP-001: P2P Server

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-014                                  |
| Finding ID         | DEC-APP-001                      |
| Severity           | Medium (Risk Score: 51) |
| Object Type        | Application                     |
| Display Name       | P2P Server                    |
| Evidence           | Application has no owner assigned                       |
| Recommended Action | Assign accountable owner to application 'P2P Server'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless applications are a governance gap                 |

---
### ACT-015 — DEC-APP-001: AdminDroid Service Application

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-015                                  |
| Finding ID         | DEC-APP-001                      |
| Severity           | Medium (Risk Score: 51) |
| Object Type        | Application                     |
| Display Name       | AdminDroid Service Application                    |
| Evidence           | Application has no owner assigned                       |
| Recommended Action | Assign accountable owner to application 'AdminDroid Service Application'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless applications are a governance gap                 |

---
### ACT-016 — DEC-APP-001: m365-security-assessment-tool-dev

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-016                                  |
| Finding ID         | DEC-APP-001                      |
| Severity           | Medium (Risk Score: 51) |
| Object Type        | Application                     |
| Display Name       | m365-security-assessment-tool-dev                    |
| Evidence           | Application has no owner assigned                       |
| Recommended Action | Assign accountable owner to application 'm365-security-assessment-tool-dev'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless applications are a governance gap                 |

---
### ACT-017 — DEC-APP-001: AJ-LAB-M365CopilotReadiness-ReadOnly

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-017                                  |
| Finding ID         | DEC-APP-001                      |
| Severity           | Medium (Risk Score: 51) |
| Object Type        | Application                     |
| Display Name       | AJ-LAB-M365CopilotReadiness-ReadOnly                    |
| Evidence           | Application has no owner assigned                       |
| Recommended Action | Assign accountable owner to application 'AJ-LAB-M365CopilotReadiness-ReadOnly'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless applications are a governance gap                 |

---
### ACT-018 — DEC-APP-001: Milestone_Plan

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-018                                  |
| Finding ID         | DEC-APP-001                      |
| Severity           | Medium (Risk Score: 51) |
| Object Type        | Application                     |
| Display Name       | Milestone_Plan                    |
| Evidence           | Application has no owner assigned                       |
| Recommended Action | Assign accountable owner to application 'Milestone_Plan'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless applications are a governance gap                 |

---
### ACT-019 — DEC-SPN-001: AdminDroid Office 365 Reporter - Sign In

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-019                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | AdminDroid Office 365 Reporter - Sign In                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'AdminDroid Office 365 Reporter - Sign In'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-020 — DEC-SPN-001: AdminDroid Office 365 Reporter - Mail App

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-020                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | AdminDroid Office 365 Reporter - Mail App                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'AdminDroid Office 365 Reporter - Mail App'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-021 — DEC-SPN-001: Microsoft Graph PowerShell

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-021                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | Microsoft Graph PowerShell                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'Microsoft Graph PowerShell'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-022 — DEC-SPN-001: AdminDroid Office 365 Reporter

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-022                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | AdminDroid Office 365 Reporter                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'AdminDroid Office 365 Reporter'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-023 — DEC-SPN-001: PowerShelltoTeamsGraphAPI

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-023                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | PowerShelltoTeamsGraphAPI                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'PowerShelltoTeamsGraphAPI'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-024 — DEC-SPN-001: Toreon Security Office

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-024                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | Toreon Security Office                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'Toreon Security Office'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-025 — DEC-SPN-001: ca-policy-analyzer

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-025                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | ca-policy-analyzer                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'ca-policy-analyzer'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-026 — DEC-SPN-001: M365 MCP Client for Claude

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-026                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | M365 MCP Client for Claude                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'M365 MCP Client for Claude'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-027 — DEC-SPN-001: M365 MCP Server for Claude

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-027                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | M365 MCP Server for Claude                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'M365 MCP Server for Claude'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-028 — DEC-SPN-001: Flipgrid

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-028                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | Flipgrid                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'Flipgrid'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-029 — DEC-SPN-001: Microsoft Tech Community

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-029                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | Microsoft Tech Community                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'Microsoft Tech Community'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-030 — DEC-SPN-001: M365Permissions PowerShell Module

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-030                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | M365Permissions PowerShell Module                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'M365Permissions PowerShell Module'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-031 — DEC-SPN-001: Modern Workplace Tools

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-031                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | Modern Workplace Tools                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'Modern Workplace Tools'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-032 — DEC-SPN-001: iOS Accounts

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-032                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | iOS Accounts                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'iOS Accounts'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-033 — DEC-SPN-001: mmrpreview

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-033                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | mmrpreview                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'mmrpreview'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-034 — DEC-SPN-001: Email

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-034                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | Email                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'Email'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-035 — DEC-SPN-001: FTOP-Multi [wsfed enabled]

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-035                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | FTOP-Multi [wsfed enabled]                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'FTOP-Multi [wsfed enabled]'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-036 — DEC-SPN-001: aljee demo

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-036                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | aljee demo                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'aljee demo'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-037 — DEC-SPN-001: LCTools

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-037                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | LCTools                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'LCTools'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
### ACT-038 — DEC-SPN-001: Access Package Builder

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | ACT-038                                  |
| Finding ID         | DEC-SPN-001                      |
| Severity           | Medium (Risk Score: 44) |
| Object Type        | ServicePrincipal                     |
| Display Name       | Access Package Builder                    |
| Evidence           | Service principal has no owner assigned — accountability gap for this enterprise application                       |
| Recommended Action | Assign accountable owner to service principal 'Access Package Builder'              |
| Approval Status    | PendingReview                              |
| Consultant Note    | Ownerless service principals with active permissions are ungoverned                 |

---
## Monitor / Hygiene (Low + Informational)

| FindingId | DisplayName | Evidence |
|-----------|-------------|----------|
| DEC-GOV-001 | Access Review API Coverage | Access review API cmdlets unavailable — review governance coverage could not be assessed. AccessReview.Read.All permission may be missing. |
| DEC-GOV-002 | Access Review Cmdlet Coverage | Access review data collection failed — review governance coverage could not be assessed. |

---

## Notes

- All Immediate Actions and Review Queue items require explicit client approval before execution.
- This plan was generated by Entra Identity Decommissioning Control Plane Rev1.2.
- For questions about this plan, contact the assessor listed above.
- To execute approved remediation actions, re-run the tool with `-Mode ExecuteRemediation` after obtaining approvals (future release).

*Entra Identity Decommissioning Control Plane Rev1.2 — Consultant Advisory Tool*
