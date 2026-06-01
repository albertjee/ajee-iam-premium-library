# Required Permissions — Entra Identity Decommissioning Control Plane

## Delegated Permissions

| Permission | Type | Purpose | Required For |
|---|---|---|---|
| `User.Read.All` | Delegated | Read user lifecycle state | User discovery |
| `Directory.Read.All` | Delegated | Read directory objects | Groups, roles, directory relationships |
| `Application.Read.All` | Delegated | Read app registrations, owners, and credentials | App ownership drift, credential expiry |
| `ServicePrincipalEndpoint.Read.All` | Delegated | Read service principal owners | DEC-SPN-001 |
| `AppRoleAssignment.ReadWrite.All` | Delegated | Read user app role assignments | DEC-USER-002 |
| `AuditLog.Read.All` | Delegated | Read sign-in and audit signals | Stale identity assessment |
| `RoleManagement.Read.Directory` | Delegated | Read privileged role assignments | DEC-ROLE-001, DEC-USER-003, DEC-GUEST-002 |
| `Policy.Read.All` | Delegated | Read Conditional Access policies | DEC-CA-001, DEC-CA-002 |
| `EntitlementManagement.Read.All` | Delegated | Read access packages | IGA coverage |

## Minimum Permission Note

Request only the permissions needed for the agreed scope. If optional permissions
(`AuditLog.Read.All`, `EntitlementManagement.Read.All`) are unavailable, the tool will
run with partial coverage and report which areas could not be assessed. Coverage gaps
are surfaced as Informational findings and noted in the Coverage Summary section of the
HTML report.

## Rev2.4 — No New Permissions Required

Rev2.4 adds baseline comparison (`-BaselinePath`) and executive evidence pack (`-GenerateExecutivePack`)
capabilities. Both features operate entirely on local data already collected during the assessment run.
No additional Microsoft Graph scopes are required.

## Requesting Permissions

The tool uses interactive delegated authentication (Connect-MgGraph). The authenticating
user must be assigned to a role that includes the permissions above, or the permissions
must be consented for the registered application.

Recommended role for assessment-only runs: **Global Reader** covers most read-only
directory operations. For sign-in log access, the user also needs **Reports Reader** or
**Security Reader**.

## Write Permissions (ExecuteRemediation mode only)

These permissions are requested only after Gate A and Gate B pass.
They are never requested during Assessment, WhatIfRemediation, or ExportPlan.

| Permission | Type | Purpose | Required For |
|---|---|---|---|
| `GroupMember.ReadWrite.All` | Delegated | Remove user from approved group memberships | DEC-USER-001 |
| `AppRoleAssignment.ReadWrite.All` | Delegated | Revoke approved app role assignments | DEC-USER-002 |
| `RoleManagement.ReadWrite.Directory` | Delegated | Remove approved privileged role assignments | DEC-USER-003, DEC-ROLE-001 |

## DemoMode

Running with `-DemoMode` requires no Graph permissions. Use this mode to demonstrate
the tool and validate output format without a live tenant connection.

## Rev2.2 Optional Read-Only Permissions

| Permission | Type | Purpose |
|---|---|---|
| `PrivilegedAccess.Read.AzureAD` | Delegated | Read PIM eligible assignment data where available |
| `EntitlementManagement.Read.All` | Delegated | Read access package assignments and policies |
| `AccessReview.Read.All` | Delegated | Read access review schedule evidence where available |
| `Group.Read.All` | Delegated | Read group metadata for sensitive resource heuristics |

If these permissions, APIs, modules, or tenant licenses are unavailable, Rev2.2 reports partial coverage instead of failing the full assessment.

## Rev2.3 Optional Read-Only Permissions

| Permission | Type | Purpose |
|---|---|---|
| `AccessReview.Read.All` | Delegated | Read access review definitions, instances, and decisions where available |
| `EntitlementManagement.Read.All` | Delegated | Correlate access package assignments and policies to review evidence |
| `PrivilegedAccess.Read.AzureAD` | Delegated | Correlate PIM eligibility evidence where available |
| `Group.Read.All` | Delegated | Correlate CA exclusion groups and access package resource groups |

If these permissions, Graph APIs, cmdlets, or tenant licenses are unavailable, Rev2.3 reports partial governance evidence coverage instead of failing the full assessment.
