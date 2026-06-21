# Rev4.38 Live Run Pack

This pack is read-only until a human intentionally runs the live disable tool later.
It does not execute the live disable itself.

## Scope

- Target: `AJEE-LAB-NHI-DISABLE-ROLLBACK`
- TenantId: `3177c971-05c9-4b7b-93a1-0edf6fd7237d`
- Target AppId: `48deb98d-78c4-49b0-8c56-eed1bb5732c0`
- Target ApplicationObjectId: `cacb17fd-bc8d-4798-a8b9-e030699ea2ad`
- Target ServicePrincipalObjectId: `7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b`
- Control object: `AJEE-LAB-NHI-KEEP-CONTROL`
- Required phrase: `APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY`

## Files

- `tools/Test-Rev438LabLiveDisableReadiness.ps1`
- `samples/rev438/rev438-lab-live-disable-approval.live-template.json`
- `tests/Rev438LabLiveRunPack.Tests.ps1`

## Human Steps

1. Perform a read-only Graph check against the official inventory source.
2. Run the readiness script against the inventory and candidate approval manifest.
3. Run the Rev4.38 tool with `-WhatIf`.
4. Inspect the generated artifacts and confirm the target-only change.
5. Only after explicit approval, run the live disable path without `-WhatIf`.
6. Post-check that the target is `AccountEnabled = $false` and non-target objects are unchanged.
7. Stop. Do not broaden the run into cleanup or delete.

## Readiness Checks

The readiness script fails closed unless all of the following are true:

- Inventory exists and is valid JSON.
- Inventory contains exactly one target record.
- Inventory contains the control object.
- Approval manifest contains the exact tenant, target ID, phrase, and action.
- Approval manifest has no extra target IDs.
- `FinalDeleteApproved` is false or absent.
- `RollbackReady` and `LiveMutationApproved` parse strictly as booleans.

## Readiness Artifact

- `rev438-live-run-readiness.json`

## Safety Notes

- This pack does not execute the live disable.
- This pack does not add final-delete support.
- This pack does not add `Remove-Mg*` calls.
- Operational note: the first Rev4.38 live-disable attempt produced a documented process deviation when the wrapper hit a missing ShouldProcess context before mutation. The operator then performed the approved direct Graph disable for the single lab target and captured local evidence showing one target changed and zero non-target lab service principals changed. The timestamped `C:\temp\IAM\Rev438LiveRun-20260620-220538\` run-root artifacts are local runtime evidence, not durable Git-tracked records; this note preserves the durable summary. This hotfix updates the live wrappers to fail closed when ShouldProcess context is unavailable, and future rollback should use the fixed wrapper path rather than direct Graph.
