# Rev4.40 Single-Object Lifecycle Wrapper

Rev4.40 adds a thin operator wrapper for the known lab NHI target so operators no longer need to hand-compose the Rev4.38 disable and Rev4.39 rollback flow each time.

## Why It Exists

- It orchestrates the already-proven Rev4.38 and Rev4.39 lab live gates.
- It keeps the existing fail-closed behavior in the underlying scripts.
- It gives the operator one entry point for readiness, WhatIf, execute, verify, and closeout.

## Supported Actions

- `ReversibleDisable`
- `RollbackDisable`

## Supported Modes

- `Readiness`
- `WhatIf`
- `Execute`
- `Verify`
- `Closeout`

## Lab Constants

- TenantId: `3177c971-05c9-4b7b-93a1-0edf6fd7237d`
- TargetDisplayName: `AJEE-LAB-NHI-DISABLE-ROLLBACK`
- TargetAppId: `48deb98d-78c4-49b0-8c56-eed1bb5732c0`
- TargetApplicationObjectId: `cacb17fd-bc8d-4798-a8b9-e030699ea2ad`
- TargetServicePrincipalObjectId: `7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b`
- ControlDisplayName: `AJEE-LAB-NHI-KEEP-CONTROL`
- ControlServicePrincipalObjectId: `b574ecc2-443f-4963-9cd4-cb5da517a717`
- Default inventory: `C:\temp\IAM\Rev437JsonShapeLive-20260619-214241\rev437-synthetic-nhi-lab-inventory.json`

## Operator Examples

Disable readiness:

```powershell
.\tools\Start-NhiSingleObjectLifecycle.ps1 `
  -TenantId "3177c971-05c9-4b7b-93a1-0edf6fd7237d" `
  -Action ReversibleDisable `
  -Mode Readiness
```

Disable WhatIf:

```powershell
.\tools\Start-NhiSingleObjectLifecycle.ps1 `
  -TenantId "3177c971-05c9-4b7b-93a1-0edf6fd7237d" `
  -Action ReversibleDisable `
  -Mode WhatIf
```

Disable execute:

```powershell
.\tools\Start-NhiSingleObjectLifecycle.ps1 `
  -TenantId "3177c971-05c9-4b7b-93a1-0edf6fd7237d" `
  -Action ReversibleDisable `
  -Mode Execute `
  -ApprovalPhrase "APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY"
```

Rollback WhatIf:

```powershell
.\tools\Start-NhiSingleObjectLifecycle.ps1 `
  -TenantId "3177c971-05c9-4b7b-93a1-0edf6fd7237d" `
  -Action RollbackDisable `
  -Mode WhatIf
```

Rollback execute:

```powershell
.\tools\Start-NhiSingleObjectLifecycle.ps1 `
  -TenantId "3177c971-05c9-4b7b-93a1-0edf6fd7237d" `
  -Action RollbackDisable `
  -Mode Execute `
  -ApprovalPhrase "APPROVE REV4.39 LIVE ROLLBACK AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY"
```

## What It Does Not Do

- No arbitrary production object IDs
- No final delete
- No cleanup
- No direct Graph mutation in the wrapper

## Relationship To Rev4.38 And Rev4.39

- `ReversibleDisable` delegates to the Rev4.38 readiness and live-disable path.
- `RollbackDisable` delegates to the Rev4.39 live-rollback path.
- The wrapper does not weaken the underlying fail-closed ShouldProcess checks introduced in PR #13.
