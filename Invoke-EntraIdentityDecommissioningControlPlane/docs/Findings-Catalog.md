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
