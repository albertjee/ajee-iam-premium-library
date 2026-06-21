# Rev4.39 Lab Live Rollback

This tool is lab-only and re-enables the same synthetic service principal after a Rev4.38 disable.
It does not execute rollback until a human explicitly runs it.

## Scope

- Target: `AJEE-LAB-NHI-DISABLE-ROLLBACK`
- TenantId: `3177c971-05c9-4b7b-93a1-0edf6fd7237d`
- Target AppId: `48deb98d-78c4-49b0-8c56-eed1bb5732c0`
- Target ApplicationObjectId: `cacb17fd-bc8d-4798-a8b9-e030699ea2ad`
- Target ServicePrincipalObjectId: `7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b`
- Control object: `AJEE-LAB-NHI-KEEP-CONTROL`
- Required phrase: `APPROVE REV4.39 LIVE ROLLBACK AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY`

## Files

- `tools/Invoke-Rev439LabLiveRollback.ps1`
- `samples/rev439/rev439-lab-live-rollback-approval.sample.json`
- `tests/Rev439LabLiveRollback.Tests.ps1`

## Human Steps

1. Confirm the target is the expected disabled lab service principal.
2. Run the rollback tool with `-WhatIf` first.
3. Inspect the rollback artifacts and confirm the change is target-only.
4. Only after explicit approval, run the live rollback path without `-WhatIf`.
5. Post-check that the target is `AccountEnabled = $true` and all other lab objects remain unchanged.
6. Stop. Do not expand into cleanup, delete, or any other mutation.

## Gate Checks

- Exact tenant validation.
- Exact target display name, AppId, ApplicationObjectId, and ServicePrincipalObjectId validation.
- Control object presence validation.
- Exact rollback approval phrase validation.
- Exactly one target object ID in the approval manifest.
- Allowed rollback actions only: `ReEnableServicePrincipal` or `RollbackDisable`.
- Strict boolean parsing for `LiveRollbackApproved`, `FinalDeleteApproved`, and `CleanupApproved`.
- `FinalDeleteApproved` must be false or absent.
- `CleanupApproved` must be false or absent.

## Artifact Set

- `rev439-pre-rollback-snapshot.json`
- `rev439-changed-object-manifest.json`
- `rev439-post-rollback-validation.json`
- `rev439-run-summary.json`

## Mutation Surface

The only permitted live mutation is:

- `Update-MgServicePrincipal -ServicePrincipalId 7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b -AccountEnabled:$true`

## Safety Notes

- No `Remove-Mg*` calls are allowed.
- No final-delete support is added.
- No cleanup path is added.
