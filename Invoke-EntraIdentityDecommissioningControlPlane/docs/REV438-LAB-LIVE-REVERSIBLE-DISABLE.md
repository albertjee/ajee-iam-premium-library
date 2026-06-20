# Rev4.38 Lab Live Reversible Disable

This branch adds a separate lab-only tool script for a single reversible disable target:

- `AJEE-LAB-NHI-DISABLE-ROLLBACK`
- `ServicePrincipalObjectId = 7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b`

The tool script is intentionally narrow:

- It does not widen `Invoke-EntraIdentityDecommissioningControlPlane.ps1`.
- It does not add a new planner switch.
- It does not touch application registration, grants, credentials, or metadata.
- It does not implement delete or final-delete behavior.

## Files Added

- `tools/Invoke-Rev438LabLiveReversibleDisable.ps1`
- `tests/Rev438LabLiveReversibleDisable.Tests.ps1`
- `samples/rev438/rev438-lab-live-disable-approval.sample.json`

## Required Inputs

- `TenantId`
- `InventoryPath`
- `ApprovalManifestPath`
- `OutputPath`
- `ConfirmLiveDisablePhrase`
- `-WhatIf` via `SupportsShouldProcess`

Required approval phrase:

- `APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY`

## Safety Gates

The tool fails closed unless all of the following are true:

1. `TenantId` equals `3177c971-05c9-4b7b-93a1-0edf6fd7237d`.
2. `InventoryPath` exists and is valid JSON.
3. `ApprovalManifestPath` exists and is valid JSON.
4. Inventory contains exactly one `AJEE-LAB-NHI-DISABLE-ROLLBACK` record.
5. Target `ServicePrincipalObjectId` equals `7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b`.
6. Target `DisplayName` equals `AJEE-LAB-NHI-DISABLE-ROLLBACK`.
7. Target `AppId` equals `48deb98d-78c4-49b0-8c56-eed1bb5732c0`.
8. Inventory contains the control object `AJEE-LAB-NHI-KEEP-CONTROL`.
9. The control object is not included in the changed-object manifest.
10. Approval manifest contains exactly one `TargetObjectId`.
11. Approval target equals `7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b`.
12. Approval action is only `ReversibleDisable` or `DisableOnly`.
13. Approval manifest contains the exact approval phrase.
14. Pre-action snapshot is written before mutation.
15. Rollback package is written before mutation.
16. Changed-object manifest contains exactly one object ID.
17. Post-disable validation package is written after the operation or simulated operation.
18. Final delete is blocked everywhere in the package surface.
19. Any blocker fails closed before Graph mutation.
20. `-WhatIf` prevents Graph mutation.

## Artifact Set

The tool emits these files into `OutputPath`:

- `rev438-preaction-snapshot.json`
- `rev438-rollback-package.json`
- `rev438-changed-object-manifest.json`
- `rev438-post-disable-validation.json`
- `rev438-run-summary.json`

## Execution Model

The live path performs a single write to the target service principal:

- `Update-MgServicePrincipal -ServicePrincipalId 7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b -AccountEnabled:$false`

The rollback package is a separate local artifact that describes re-enable only:

- `Update-MgServicePrincipal -ServicePrincipalId 7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b -AccountEnabled:$true`

## Manual Validation Sequence

1. Validate the inventory JSON contains the exact target and control object.
2. Validate the approval manifest contains the exact target, phrase, tenant, and action.
3. Run the tool with `-WhatIf` first.
4. Confirm all five artifacts are written.
5. Confirm the changed-object manifest contains exactly one object ID.
6. Confirm the rollback package is re-enable only.
7. Confirm the run summary blocks final delete.
8. Only after human approval, run the live path without `-WhatIf`.
9. Confirm the live path returns `LiveMutationPerformed = true`.

## Validation Commands

Focused Pester:

```powershell
Invoke-Pester -Path .\Invoke-EntraIdentityDecommissioningControlPlane\tests\Rev438LabLiveReversibleDisable.Tests.ps1
```

Static safety scan:

```powershell
rg -n "Remove-MgServicePrincipal|Remove-MgApplication|Remove-MgOauth2PermissionGrant|Remove-MgServicePrincipalAppRoleAssignment|Remove-MgApplicationPassword|Remove-MgApplicationKey|AllowFinalDelete|FinalDelete" .\Invoke-EntraIdentityDecommissioningControlPlane\tools\Invoke-Rev438LabLiveReversibleDisable.ps1 .\Invoke-EntraIdentityDecommissioningControlPlane\tests\Rev438LabLiveReversibleDisable.Tests.ps1
```

## Notes

- `-WhatIf` produces artifacts and does not mutate the tenant.
- The tool is intentionally not wired into the broader controlled planner path.
- Final delete remains blocked by design.
