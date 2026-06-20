# Rev4.37 Controlled NHI Lab Validation Runbook

## Purpose

Rev4.37 validates controlled NHI mark, disable, and rollback behavior using synthetic lab objects only.

The runbook is intentionally narrow:

- no live tenant mutation outside the lab scenario
- no `AllowFinalDelete`
- no `AllowHumanExecution`
- no production object reuse
- no broad Graph permissions beyond what the lab creation workflow needs

## Safety Boundaries

- Use only objects whose `DisplayName` starts with `AJEE-LAB-NHI-`.
- Preserve `AJEE-LAB-NHI-KEEP-CONTROL` untouched for the entire exercise.
- Do not create, disable, or delete anything outside the inventory manifest.
- Do not run controlled decommission execution during asset preparation.
- Do not run final delete.
- Do not use placeholder object IDs as real IDs.

## Required Permissions

The lab generator and cleanup scripts are intended for a lab-connected Graph session that can read and manage application registrations and service principals.

Use the minimum permissions needed for that work in the target lab:

- `Application.ReadWrite.All`
- `ServicePrincipal.ReadWrite.All`
- `Directory.Read.All` for discovery and verification

Do not add high-risk permissions that are not needed for application and service principal object management.

## Lab Object Inventory

Required synthetic objects:

| DisplayName | Purpose | Control behavior |
| --- | --- | --- |
| `AJEE-LAB-NHI-KEEP-CONTROL` | Never touched. Proves no collateral impact. | `ControlObject = true` |
| `AJEE-LAB-NHI-DISABLE-ROLLBACK` | Primary reversible disable and rollback target. | `SafeToDisable = true`, `SafeToRollback = true` |
| `AJEE-LAB-NHI-MARK-ONLY` | Mark/tag/evidence-only candidate. | Marked but not disabled in this phase |
| `AJEE-LAB-NHI-NO-OWNER` | Owner-risk detection. | Used to validate owner-risk reporting |
| `AJEE-LAB-NHI-EXPIRED-CRED` | Expired credential evidence. | Used to validate expired-credential handling |
| `AJEE-LAB-NHI-ACTIVE-CRED` | Active credential safety case. | Used to validate active-credential detection |

Each inventory record must include:

- `DisplayName`
- `AppId`
- `ApplicationObjectId`
- `ServicePrincipalObjectId`
- `TargetType`
- `Purpose`
- `CreatedAt`
- `TenantId`
- `SafeToDisable`
- `SafeToRollback`
- `ControlObject`

Inventory output path:

- `out/rev437-lab/`
- Inventory file: `out/rev437-lab/rev437-synthetic-nhi-lab-inventory.json`

## Read-Only Discovery

Before any creation or cleanup, confirm the current lab tenant context and inventory shape.

Suggested checks:

- inspect the repo contract docs
- confirm the required object names
- confirm the inventory path does not already contain unrelated objects
- confirm the target tenant is the intended lab tenant

Do not hardcode tenant IDs in scripts or manifests.

## What-If Plan Generation

Use the controlled planning path only in simulation mode.

Expected shape:

- `-Mode WhatIfRemediation`
- `-GenerateApprovalTemplate`
- `-WhatIfManifestPath`

This step produces planning artifacts only. It does not authorize execution.

## Approval Template

Generate the approval template from the what-if plan and review it manually.

The approval material must carry:

- the target object IDs
- the approved action
- the approval phase or execution phase
- the approval expiry
- the approval hash

## Approved Manifest

Execution gating relies on a validated approval manifest.

The approval file must be checked with the existing approval validators before any later lab step can proceed.

Required gating concepts:

- `ApprovedBy`
- `ApprovedAt`
- `SchemaVersion`
- `ExecutionPhaseApproved`
- `TargetObjectIds`
- `SHA256`

## Mark-Only / Evidence Step

Use the controlled planning contracts to build a mark-only evidence package for `AJEE-LAB-NHI-MARK-ONLY`.

This is evidence generation, not live mutation.

Keep the output constrained to marker evidence and snapshot evidence only.

## Reversible Disable Step

Use the reversible disable target only:

- `AJEE-LAB-NHI-DISABLE-ROLLBACK`

The rev4.37 lab validation should prove:

- the disable is reversible
- the approval is specific
- the snapshot binds to the target
- the rollback evidence is present
- the control object remains untouched

## Rollback Step

Rollback is allowed only after the reversible disable is observed and approved for reversal.

Rollback evidence must include:

- original disable evidence
- pre-action snapshot
- rollback drill package
- rollback trigger or observation failure
- human rollback approval

Rollback must re-enable only. It must not delete, recreate, clean up grants, or clean up metadata.

## Post-Rollback Validation

After rollback, validate:

- `AccountEnabled` returned to its original state
- `ObjectId` did not change
- `AppId` did not change
- credential counts are restored or unchanged
- owner counts are restored or unchanged
- app role assignment counts are restored or unchanged
- OAuth grant counts are restored or unchanged
- no delete, recreate, grant cleanup, or credential change was observed

## Final-Delete Blocked Negative Test

Final delete must remain blocked in this rev.

Validate the negative case by confirming:

- `AllowFinalDelete` is not used
- `ExecutionStage FinalDelete` remains blocked
- live delete is not executable

The controlled planner and readiness gates should continue to report final delete as simulation-only or blocked.

## Acceptance Criteria

- The generator creates only `AJEE-LAB-NHI-*` inventory records.
- The cleanup script refuses to run without an inventory file.
- The cleanup script refuses any inventory entry that does not use the required prefix.
- The runbook and test suite both document that final delete is blocked.
- The control object remains untouched.
- The reversible disable target can be validated as reversible in planning and rollback evidence.

## Cleanup Procedure

Use the cleanup script only after the lab validation is complete and the inventory file has been reviewed.

Recommended order:

1. Review the inventory JSON.
2. Confirm the control object is present and preserved.
3. Run the cleanup script with `-WhatIf` first.
4. Re-run only if the inventory file and confirmation phrase are correct.

Cleanup must only target inventory records with the `AJEE-LAB-NHI-` prefix and must preserve the control object.
