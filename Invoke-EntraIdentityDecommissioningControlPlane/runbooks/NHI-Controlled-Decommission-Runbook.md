# NHI Controlled Decommission Runbook
## Rev4.2-S1 Planner and Evidence Workflow

**Audience:** IAM operators, reviewers, and approvers

**Scope:** Local planner/evidence/WhatIf/Demo workflow only

**Compatibility note:** The entry-point `ToolVersion` remains `Rev4.1` because the frozen
release-validation contract requires it. Rev4.2-S1 traceability is carried by the schema, branch,
commit, documentation, module, samples, and tests.

---

## Safety Boundary

Rev4.2-S1 does not perform live controlled decommission actions.

- No Microsoft Graph connection is made by the controlled decommission path.
- No tenant object is tagged, disabled, modified, or deleted.
- No new Graph write scopes are requested.
- Live `FinalDelete` is blocked.
- `Remove-MgServicePrincipal` and `Remove-MgApplication` are not implemented or invoked.
- Assessment, default, SelfTest, DemoMode, and WhatIf paths remain write-free.
- Missing or invalid plan and approval inputs fail closed.
- If both `-ExecuteNhiControlledDecommission` and `-ExecuteNhiDecommission` are supplied, the
  controlled Rev4.2-S1 branch runs first and exits before the legacy Rev4.0 execution path.

Do not treat Rev4.2-S1 delete-readiness evidence as authorization to delete an object.

## Inputs

The workflow requires both local JSON inputs:

| Input | Purpose |
|---|---|
| Decommission plan | Identifies the RunId, target, and requested planning stage |
| Approval manifest | Binds an approver, expiry, target, and allowed planning actions |

Repository samples:

- `samples/nhi-controlled-decommission-plan.sample.json`
- `samples/nhi-controlled-decommission-approval.sample.json`

Rich evidence fields in the sample plan are illustrative input examples only. Runtime recomputes
generated evidence from the accepted plan and approval inputs and does not trust precomputed
readiness as authority.

## Preflight

Run offline SelfTest:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -SelfTest
```

Optionally validate the broader offline demonstration path:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode
```

Neither command requires a TenantId or Graph connection.

## Run the Sample Planner

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -ExecuteNhiControlledDecommission `
    -ExecutionStage DeleteReadinessOnly `
    -DecommissionPlanPath '.\samples\nhi-controlled-decommission-plan.sample.json' `
    -ApprovalManifestPath '.\samples\nhi-controlled-decommission-approval.sample.json' `
    -WhatIfExecution `
    -OutputPath '.\out'
```

Expected result:

```text
[OK] Rev4.2-S1 controlled decommission planner/evidence completed. No Graph connection or tenant mutation performed.
```

## Evidence Outputs

The workflow creates a local `controlled-decommission-<RunId>` folder containing:

| File | Description |
|---|---|
| `nhi-controlled-decommission-plan.json` | Planning-only action record |
| `nhi-controlled-decommission-snapshot.json` | Sanitized target snapshot and SHA-256 hash |
| `nhi-controlled-decommission-screamtest.json` | Illustrative/generated planner evaluation; not live monitoring evidence |
| `nhi-controlled-decommission-delete-readiness.json` | Fail-closed readiness decision |
| `nhi-controlled-decommission-rollback-plan.json` | Rollback planning evidence |

Review evidence for RunId and target consistency. Confirm snapshots contain metadata only and no
secret, token, or certificate material.

The S1 scream-test artifact is generated planner evidence. It does not prove a live Graph query,
live monitoring period, or tenant observation occurred.

## Rev4.3 Service Principal FinalDelete Guard Simulation

Rev4.3 evaluates Service Principal FinalDelete gates and writes local evidence only. It does not
include a Service Principal delete cmdlet or live Graph write path.

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -ExecuteNhiControlledDecommission `
    -ExecutionStage FinalDelete `
    -AllowFinalDelete `
    -DecommissionPlanPath '.\samples\nhi-controlled-finaldelete-sp.sample.json' `
    -ApprovalManifestPath '.\samples\nhi-controlled-finaldelete-sp.sample.json' `
    -WhatIfExecution `
    -OutputPath '.\out'
```

Expected FinalDelete-specific evidence replacing the rollback-plan artifact:

- `nhi-controlled-decommission-finaldelete-sp-guard.json`
- `Status = GuardSatisfiedSimulationOnly` when all gates pass
- `LiveDeleteExecutable = false`
- `DeleteCmdletAvailable = false`

`-AllowFinalDelete` permits gate simulation only. It does not authorize or enable deletion.

## Fail-Closed Conditions

Stop and correct the input or evidence when any of these conditions occurs:

- Plan or approval file is missing or invalid JSON.
- Plan schema is not `4.2`.
- RunId, target, or requested action does not match the approval.
- Approval is missing, expired, or not approved.
- Target validation identifies a protected, first-party, emergency-access, break-glass, active,
  ambiguous, or unsupported target.
- Dependency or recent-activity evidence is detected.
- Evidence queries fail or are missing.
- `FinalDelete` or `-AllowFinalDelete` is requested.

## Prohibited S1 Operations

Do not add tenant credentials or a TenantId to work around a planner failure. Do not invoke Graph
write cmdlets. Do not manually convert planner evidence into a live delete operation.

Rev4.2-S1 completion means evidence was generated and reviewed. It does not mean the target was
changed or deleted.

## Future Hardening Note

If `ConvertTo-NhiControlledSnapshot` is later supplied raw Graph objects, expand and test
sanitization for `AdditionalProperties` and unusual secret-like fields before enabling that path.
