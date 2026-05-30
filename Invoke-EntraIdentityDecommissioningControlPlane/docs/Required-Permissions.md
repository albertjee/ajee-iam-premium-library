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
| `RoleManagement.Read.Directory` | Delegated | Read privileged role assignments | Privileged access residue |
| `EntitlementManagement.Read.All` | Delegated | Read access packages | IGA coverage |

## Minimum Permission Note

Request only the permissions needed for the agreed scope. If optional permissions
(`AuditLog.Read.All`, `EntitlementManagement.Read.All`) are unavailable, the tool will
run with partial coverage and report which areas could not be assessed. Coverage gaps
are surfaced as Informational findings and noted in the Coverage Summary section of the
HTML report.

## Requesting Permissions

The tool uses interactive delegated authentication (Connect-MgGraph). The authenticating
user must be assigned to a role that includes the permissions above, or the permissions
must be consented for the registered application.

Recommended role for assessment-only runs: **Global Reader** covers most read-only
directory operations. For sign-in log access, the user also needs **Reports Reader** or
**Security Reader**.

## DemoMode

Running with `-DemoMode` requires no Graph permissions. Use this mode to demonstrate
the tool and validate output format without a live tenant connection.
