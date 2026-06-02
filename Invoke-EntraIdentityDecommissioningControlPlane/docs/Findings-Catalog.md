# Findings Catalog — Entra Identity Decommissioning Control Plane

## Catalog

| Finding ID | Category | Title | Default Severity |
|---|---|---|---|
| DEC-USER-001 | User Lifecycle | Disabled user retains group memberships | Medium |
| DEC-USER-002 | User Lifecycle | Disabled user retains app assignments | High |
| DEC-USER-003 | User Lifecycle | Disabled user has privileged access | Critical |
| DEC-APP-001 | Application | Application has no owner | Medium |
| DEC-APP-002 | Application | Application owned by disabled user | Critical |
| DEC-APP-003 | Application | Application has single owner | Medium |
| DEC-APP-004 | Application | Application secret expires soon | Medium |
| DEC-APP-005 | Application | Application has expired credential attached | High |
| DEC-SPN-001 | Application | Service principal has no owner | Medium |
| DEC-GUEST-001 | Guest Lifecycle | Guest has stale sign-in | Medium |
| DEC-GUEST-002 | Guest Lifecycle | Guest holds privileged directory role | Critical |
| DEC-GUEST-003 | Guest Lifecycle | Guest lacks sponsor metadata | Medium |
| DEC-CA-001 | Conditional Access | CA policy has user/group exclusions requiring review | High |
| DEC-CA-002 | Conditional Access | CA exclusion group membership requires access review | High |
| DEC-ROLE-001 | Privileged Access | Disabled identity holds active privileged role | Critical |
| DEC-IGA-001 | Governance | Access package lacks review coverage | High |

## Severity Model

| Severity | Risk Score Band | Meaning |
|---|---|---|
| Critical | 80–100 | Immediate risk to tenant security posture |
| High | 60–79 | Significant risk requiring prompt action |
| Medium | 40–59 | Risk requiring planned remediation |
| Low | 25–39 | Low risk, monitor or remediate at next cycle |
| Informational | 0–24 | Coverage gap or advisory note, no direct risk |

## Confidence Model

| Confidence | Meaning |
|---|---|
| High | Evidence is direct and deterministic |
| Medium | Evidence is indirect or partially available |
| Low | Evidence is incomplete; further investigation required |

## Remediation Mode

| Mode | Meaning |
|---|---|
| ManualApprovalRequired | Finding requires explicit approval before remediation |
| AutoRemediable | Finding can be remediated automatically in ExecuteRemediation mode |
| InformationOnly | No remediation action; advisory only |
| ProtectedObject | Object is protected (break-glass, sync account); remediation blocked |

## Rev2.0 Execution Scope

ExecuteRemediation is available only for these finding/action families in Rev2.0:

| FindingId | ActionType | TargetObjectIds represent | Confirmation |
|---|---|---|---|
| DEC-USER-001 | RemoveGroupMembership | Group IDs | AutoRemediable — no per-action prompt |
| DEC-USER-002 | RevokeAppRoleAssignment | App role assignment IDs | ManualApprovalRequired — per-action prompt |
| DEC-USER-003 | RemoveDirectoryRoleAssignment | Directory role assignment IDs | ManualApprovalRequired — per-action prompt |
| DEC-ROLE-001 | RemoveDirectoryRoleAssignment | Directory role assignment IDs | ManualApprovalRequired — per-action prompt |

All other findings are plan-only in Rev2.0.

ProtectedObject actions are never executed regardless of approval manifest content.

Execution operates only on approved TargetObjectIds from the approval manifest.
The engine never re-discovers current tenant state to broaden execution targets.

For privileged role removals, Rev2.0 generates one executable action per exact directory role assignment ID.

## Rev2.2 — PIM and Entitlement Management Visibility

| FindingId | Severity | Description |
|---|---|---|
| DEC-PIM-001 | Critical | Disabled user has eligible privileged role assignment |
| DEC-PIM-002 | Critical | Guest has eligible privileged role assignment |
| DEC-PIM-003 | Medium | PIM activation/review evidence unavailable (tenant-level coverage gap) |
| DEC-PIM-004 | High | Eligible privileged assignment requires governance review |
| DEC-AP-001 | High | Disabled user has access package assignment |
| DEC-AP-002 | Medium | Guest has access package assignment |
| DEC-AP-003 | Medium | Access package assignment has no visible expiration evidence |
| DEC-AP-004 | Medium | Access package review coverage could not be confirmed |
| DEC-AP-005 | High | Access package assignment linked to sensitive resource/group heuristic |

## Rev2.3 — Access Review Correlation and Governance Proof Findings

### Access Review / Governance Proof Findings

| FindingId | Category | Title | Severity | RiskScore |
|---|---|---|---:|---:|
| DEC-REV-001 | Governance | Access review coverage unavailable or partial | Informational | 20 |
| DEC-REV-002 | Governance | Access review decision evidence stale or older than threshold | Medium | 45 |
| DEC-REV-003 | Governance | Access review has incomplete decisions | Medium | 50 |
| DEC-REV-004 | Governance | Access review scope does not clearly map to residual access finding | Medium | 46 |
| DEC-REV-005 | Governance | Access review decision conflicts with current residual access | High | 67 |

### Guest Governance Review Findings

| FindingId | Category | Title | Severity | RiskScore |
|---|---|---|---:|---:|
| DEC-GREV-001 | Guest Lifecycle | Guest has no confirmable recent access review evidence | Medium | 48 |
| DEC-GREV-002 | Guest Lifecycle | Guest sponsor metadata missing and review evidence unavailable | High | 63 |
| DEC-GREV-003 | Guest Lifecycle | Guest privileged access lacks confirmable review evidence | High | 72 |

## Rev3.1 Executable Write Actions

The following finding IDs have controlled write actions enabled in Rev3.1. All require SchemaVersion ≥ 3.1 in the approval manifest and `UserType = Guest` revalidation before execution.

| FindingId | ActionType | WriteScope |
|---|---|---|
| DEC-GUEST-001 | `RemoveGuestGroupMembership` | `GroupMember.ReadWrite.All` |
| DEC-GUEST-002 | `RemoveGuestGroupMembership` or `RevokeGuestAppRoleAssignment` | `GroupMember.ReadWrite.All` / `AppRoleAssignment.ReadWrite.All` |
| DEC-GUEST-003 | `RemoveGuestGroupMembership` | `GroupMember.ReadWrite.All` |
| DEC-GREV-001 | `RemoveGuestGroupMembership` | `GroupMember.ReadWrite.All` |
| DEC-GREV-002 | `RemoveGuestGroupMembership` | `GroupMember.ReadWrite.All` |
| DEC-GREV-003 | `RemoveGuestGroupMembership` or `RevokeGuestAppRoleAssignment` | `GroupMember.ReadWrite.All` / `AppRoleAssignment.ReadWrite.All` |

### PIM Governance Review Findings

| FindingId | Category | Title | Severity | RiskScore |
|---|---|---|---:|---:|
| DEC-PIM-005 | Privileged Access | Eligible PIM assignment lacks confirmable review evidence | High | 70 |
| DEC-PIM-006 | Privileged Access | Eligible PIM assignment review evidence stale | High | 73 |
| DEC-PIM-007 | Privileged Access | PIM activation/review correlation unavailable | Informational | 22 |

### Access Package Review Findings

| FindingId | Category | Title | Severity | RiskScore |
|---|---|---|---:|---:|
| DEC-AP-006 | Governance | Access package lacks confirmable access review schedule evidence | Medium | 50 |
| DEC-AP-007 | Governance | Access package assignment review evidence stale or unavailable | Medium | 54 |
| DEC-AP-008 | Governance | Access package review decision incomplete or not applied | High | 66 |

### Conditional Access Exclusion Review Findings

| FindingId | Category | Title | Severity | RiskScore |
|---|---|---|---:|---:|
| DEC-CA-003 | Conditional Access | CA exclusion group lacks confirmable access review evidence | High | 68 |
| DEC-CA-004 | Conditional Access | CA exclusion review evidence stale or unavailable | High | 70 |

## Rev3.2 Executable Write Actions

The following finding ID has a controlled write action enabled in Rev3.2. Requires SchemaVersion ≥ 3.2 in the approval manifest and credential expiry revalidation before execution. An exact `CredentialKeyId` must be present; the application object is never deleted.

| FindingId | ActionType | WriteScope | CredentialTypes |
|---|---|---|---|
| DEC-APP-005 | `RemoveExpiredApplicationCredential` | `Application.ReadWrite.All` | PasswordCredential, KeyCredential |

### Safety Constraints

- Credential must be confirmed expired at execution time (`EndDateTime < UtcNow`)
- Exact `CredentialKeyId` must match a credential still present on the application
- `ProtectedObject = true` blocks execution unconditionally
- `CredentialType` mismatch between approval manifest and live application blocks execution
- `null EndDateTime` blocks execution
- Application read failure blocks execution
- Already-removed credentials are logged `Skipped` (no write attempted)
- `Remove-MgApplication` (object deletion) is never called
- `Remove-MgServicePrincipal` is never called

### Governance Pack Modules (Rev3.2 — Read-Only)

Rev3.2 adds four read-only governance pack modules for consultant deliverable generation. None contain write cmdlets or write scopes.

| Module | FindingIds Covered | Purpose |
|---|---|---|
| `ApplicationGovernance.psm1` | DEC-APP-001, DEC-APP-002, DEC-APP-003, DEC-SPN-001 | Application ownership governance model, owner approval packets, exception register |
| `CredentialHygiene.psm1` | DEC-APP-004, DEC-APP-005 | Credential hygiene governance model, expiry dashboard, rollback guidance |
| `ConditionalAccessGovernance.psm1` | DEC-CA-001, DEC-CA-002, DEC-CA-003, DEC-CA-004 | CA exclusion governance model, owner review packets, remediation design |
| `EmergencyAccessGovernance.psm1` | (ProtectedObject findings) | Protected object validation, emergency access hygiene, blocked action audit |

### Tenant-Level Governance Evidence Findings

| FindingId | Category | Title | Severity | RiskScore |
|---|---|---|---:|---:|
| DEC-GOV-001 | Governance | Governance evidence coverage is partial | Informational | 18 |
| DEC-GOV-002 | Governance | Access review API unavailable or permission-limited | Informational | 16 |
| DEC-GOV-003 | Governance | Entra ID Governance licensing may limit evidence coverage | Informational | 14 |
