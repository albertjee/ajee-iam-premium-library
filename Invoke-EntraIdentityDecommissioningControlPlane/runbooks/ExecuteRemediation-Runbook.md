# ExecuteRemediation Runbook

**Tool:** Entra Identity Decommissioning Control Plane  
**SchemaVersion:** 2.5  
**Rev:** 2.5

---

## Safety Boundary

**This tool is read-only except for the four Rev2.0 executable actions.** No write operations occur unless all three of the following gates pass:

1. `-ExecuteRemediation` switch is explicitly provided
2. A valid, non-expired approval manifest is present at `-ApprovalManifestPath`
3. The manifest's `ApprovedActions` list contains the FindingId being acted on

Write scopes used: `GroupMember.ReadWrite.All`, `AppRoleAssignment.ReadWrite.All`, `RoleManagement.ReadWrite.Directory`

No other write scopes are requested or used.

## Three-Gate Model

```
Gate 1 — Approval Manifest Present and Valid
Gate 2 — FindingId in ApprovedActions list
Gate 3 — Pre-flight target revalidation passes
```

All three gates must pass before any write call is issued. Failure at any gate skips that action and logs it as `Skipped-SafetyGate`.

## Rev2.0 Executable Actions

| FindingId | Graph Call | Scope |
|---|---|---|
| DEC-USER-001 | Remove-MgGroupMember | GroupMember.ReadWrite.All |
| DEC-USER-002 | Remove-MgGroupMember | GroupMember.ReadWrite.All |
| DEC-USER-003 | Remove-MgGroupMember | GroupMember.ReadWrite.All |
| DEC-ROLE-001 | Remove-MgDirectoryRoleMember | RoleManagement.ReadWrite.Directory |

No other write actions exist in this tool. Expansion requires Rev3.0 design approval.

## Execute Command

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith' `
    -ExecuteRemediation `
    -ApprovalManifestPath '.\approval-manifest-ENG-2026-001.json'
```

## Output Files

| File | Description |
|---|---|
| `execution-log-*.json` | Per-action execution log with status |
| `execution-evidence-*.json` | Evidence package for audit trail |

## Rollback

Rev2.0 actions are membership removals. To reverse:
- Re-add the user to the group or role using standard admin tooling
- All removed memberships are logged in `execution-evidence-*.json`

## Prohibited Combinations

The following parameter combinations are blocked at startup:

- `-ExecuteRemediation` + `-WhatIf` — mutually exclusive
- `-ExecuteRemediation` + `-DemoMode` — execution never runs against demo data
- `-ExecuteRemediation` without `-ApprovalManifestPath` — no manifest, no execution

---

© 2026 Albert Jee. All rights reserved.
