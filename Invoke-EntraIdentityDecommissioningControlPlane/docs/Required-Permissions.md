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

## Rev4.2-S1 - Controlled NHI Decommission Planner Permissions

Rev4.2-S1 controlled NHI decommission is a local planner/evidence workflow only. It requires
no Microsoft Graph connection and introduces no new Graph permissions or write scopes.

- `-ExecuteNhiControlledDecommission` must be paired with `-WhatIfExecution` or `-DemoMode`.
- Assessment permissions remain read-only.
- The Rev4.2-S1 planner reads local plan and approval JSON files and writes local evidence JSON only.
- Live `FinalDelete` is blocked.
- `Remove-MgServicePrincipal` and `Remove-MgApplication` are not implemented or invoked.

The sample plan and approval files can be validated without tenant credentials:

- `samples/nhi-controlled-decommission-plan.sample.json`
- `samples/nhi-controlled-decommission-approval.sample.json`

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
| `RoleManagement.ReadWrite.Directory` | Delegated | Remove approved privileged role assignments | DEC-USER-003, DEC-ROLE-001, DEC-PIM-001–DEC-PIM-006 |
| `EntitlementManagement.ReadWrite.All` | Delegated | Remove approved access package assignments (Rev3.0) | DEC-AP-001, DEC-AP-002, DEC-AP-007, DEC-AP-008 |

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

## Rev3.1 — New Write Permissions Required for Guest Governance Actions

Rev3.1 introduces two new controlled guest remediation action types. Both require write permissions requested only after Gate A (WhatIf manifest) and Gate B (approval manifest with SchemaVersion ≥ 3.1) pass. All actions include a `UserType = Guest` revalidation check before execution.

| Permission | Type | Action Types | Finding IDs |
|---|---|---|---|
| `GroupMember.ReadWrite.All` | Delegated | `RemoveGuestGroupMembership` | DEC-GUEST-001, DEC-GUEST-002, DEC-GUEST-003, DEC-GREV-001, DEC-GREV-002, DEC-GREV-003 |
| `AppRoleAssignment.ReadWrite.All` | Delegated | `RevokeGuestAppRoleAssignment` | DEC-GUEST-002, DEC-GREV-003 |

`GroupMember.ReadWrite.All` was already required by Rev2.0 for `RemoveGroupMembership`. Rev3.1 extends its use to guest group membership removal.

`AppRoleAssignment.ReadWrite.All` was already required by Rev2.0 for `RevokeAppRoleAssignment`. Rev3.1 extends its use to guest app role revocation.

Both permissions are already present in the write-scope `Connect-MgGraph` call in the entry point.

If `Remove-MgGroupMemberByRef` or `Remove-MgUserAppRoleAssignment` fail, the action is logged `Failed` or `PartialFailed`. The run continues for all other actions.

---

## Rev3.0 — New Write Permissions Required for AP and PIM Actions

Rev3.0 introduces two new controlled remediation action types. Both require write permissions requested only after Gate A (WhatIf manifest) and Gate B (approval manifest with SchemaVersion ≥ 3.0) pass.

| Permission | Type | Action Types | Finding IDs |
|---|---|---|---|
| `EntitlementManagement.ReadWrite.All` | Delegated | `RemoveAccessPackageAssignment` | DEC-AP-001, DEC-AP-002, DEC-AP-007, DEC-AP-008 |
| `RoleManagement.ReadWrite.Directory` | Delegated | `RemovePimEligibleAssignment` | DEC-PIM-001 through DEC-PIM-006 |

`RoleManagement.ReadWrite.Directory` was already required by Rev2.0 for `RemoveDirectoryRoleAssignment`. Rev3.0 extends its use to PIM eligible assignment removal.

`EntitlementManagement.ReadWrite.All` is new in Rev3.0. It is added to the write-scope `Connect-MgGraph` call in the entry point only when ExecuteRemediation mode is active.

If `Remove-MgEntitlementManagementAssignment` or `Remove-MgRoleManagementDirectoryRoleEligibilitySchedule` is unavailable in the session (module not loaded), the action is logged `Blocked` with `cmdlet unavailable` error detail. The run continues for all other actions.

## Rev3.2 — New Write Permission Required for Application Credential Removal

Rev3.2 introduces one new controlled write action. It requires a write permission requested only after Gate A (WhatIf manifest) and Gate B (approval manifest with SchemaVersion ≥ 3.2) pass.

| Permission | Type | Action Type | Finding IDs |
|---|---|---|---|
| `Application.ReadWrite.All` | Delegated | `RemoveExpiredApplicationCredential` | DEC-APP-005 |

`Application.ReadWrite.All` is new in Rev3.2. It is added to the write-scope `Connect-MgGraph` call in the entry point only when ExecuteRemediation mode is active.

The action removes only the specific password or key credential identified by an exact `CredentialKeyId`. The application object itself is never deleted. Non-expired credentials, credentials without an exact KeyId, and ProtectedObject applications are blocked before any write is attempted.

`Remove-MgApplicationPassword` is used for `PasswordCredential` type; `Remove-MgApplicationKey` is used for `KeyCredential` type. Both are checked for cmdlet availability before use.

## Rev2.5 — No New Permissions Required

Rev2.5 adds SelfTest (`-SelfTest`), release packaging (`-GenerateReleasePackage`), schema contracts, catalog validation, and write-readiness assessment capabilities. All new features operate on local source files and prior output artifacts only. No additional Microsoft Graph scopes are required.
