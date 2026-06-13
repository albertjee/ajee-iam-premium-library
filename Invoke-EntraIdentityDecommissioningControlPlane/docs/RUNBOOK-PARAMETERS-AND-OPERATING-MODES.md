# Runbook — Parameters, Operating Modes, and Consultant Usage

## 1. Purpose

This runbook helps a consultant understand which command-line switches are available on `Invoke-EntraIdentityDecommissioningControlPlane.ps1`, what each one does, which modes are safe for discovery or reporting, and which combinations are risky or prohibited without explicit approval.

Use this as the first reference when deciding whether to run the tool offline, in DemoMode, in live read-only assessment mode, or in a planning / execution workflow.

## 2. Operating Mode Summary

| Category                                      | Safety level                          | Tenant write risk                    | Typical consultant use case                                              | Required parameters                                                                                                                       | Parameters that must not be combined casually                                                                             |
| --------------------------------------------- | ------------------------------------- | ------------------------------------:| ------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Offline / no tenant access                    | Safe                                  | None                                 | Parser, import, self-test, release validation, local artifact generation | `-SelfTest`, optionally `-GenerateReleasePackage`, `-OutputPath`, `-ReleasePackagePath`                                                   | Any `Execute*` parameter, `-Rollback`, `-AllowFinalDelete`, `-AllowHumanExecution`, live `-TenantId` with execution flags |
| DemoMode                                      | Safe with caution                     | None                                 | Generate sample outputs with a synthetic tenant context                  | `-DemoMode`, `-OutputPath`                                                                                                                | Any execution, rollback, or final-delete switch                                                                           |
| Live read-only assessment                     | Safe                                  | None                                 | Assess a real tenant without changing tenant state                       | `-Mode Assessment`, `-TenantId`, optional read-only reporting switches                                                                    | Any `Execute*` parameter, `-Rollback`, `-AllowFinalDelete`, controlled cleanup switches                                   |
| Client handoff / executive package generation | Safe                                  | None                                 | Produce client-safe reports and handoff artifacts                        | `-GenerateClientHandoff`, `-GenerateRedactedPackage`, `-GenerateEvidenceBundle`, `-GenerateExecutivePack`, `-GenerateTraceabilityReport`  | Any execution, rollback, or cleanup switch; do not mix with `-AllowFinalDelete`                                           |
| Evidence bundle / traceability generation     | Safe                                  | None                                 | Produce defensible evidence and traceability artifacts                   | `-GenerateEvidenceBundle`, `-GenerateTraceabilityReport`, optionally `-GenerateApprovalDiff`, `-GenerateReplayValidation`                 | Any execution, rollback, or cleanup switch                                                                                |
| Replay validation                             | Safe                                  | None                                 | Check consistency between current output and prior saved outputs         | `-GenerateReplayValidation`, `-WhatIfManifestPath` or prior outputs as inputs                                                             | Any execution, rollback, or final-delete switch                                                                           |
| Readiness validation                          | Safe                                  | None                                 | Verify release and readiness artifacts before client delivery            | `-SelfTest`, `-GenerateRev35Readiness`, `-GenerateNhiGovernancePack`                                                                      | Any execution, rollback, or cleanup switch                                                                                |
| Approval manifest generation / validation     | Caution                               | None unless used in execution gating | Create or validate an approval manifest for planned actions              | `-GenerateApprovalTemplate`, `-ApprovalManifestPath`, `-WhatIfManifestPath`, `-Mode WhatIfRemediation`                                    | `-ExecuteRemediation`, any `ExecuteNhi*` parameter, `-AllowFinalDelete`                                                   |
| WhatIf / planning                             | Caution                               | None                                 | Build a non-executing remediation plan or approval draft                 | `-Mode WhatIfRemediation`, `-GenerateApprovalTemplate`, `-WhatIfExecution`                                                                | `-ExecuteRemediation`, `-Rollback`, any `ExecuteNhi*` parameter                                                           |
| Controlled execution / decommission           | High risk                             | Yes                                  | Run approved, staged remediation or controlled NHI actions               | `-Mode ExecuteRemediation`, `-ExecuteRemediation`, `-ApprovalManifestPath`, `-ApprovedManifestPath`, `-ExecutionRunId`, `-ExecutionStage` | `-AllowFinalDelete`, missing approval artifacts, mixed rollback and execution in one run                                  |
| Rollback                                      | High risk                             | Possible / context-dependent         | Reverse a prior execution using recorded snapshot data                   | `-Rollback`, `-ExecutionRunId`, `-ExecutionOutputPath`                                                                                    | Any live execution switch, `-AllowFinalDelete`, unvalidated or missing snapshot artifacts                                 |
| Final delete / irreversible operations        | Prohibited unless explicitly approved | Yes                                  | Only for tightly controlled lab or approved final-delete workflows       | `-AllowFinalDelete` plus controlled NHI execution stage and plan artifacts                                                                | Any casual execution use, unreviewed approval material, non-lab tenant usage                                              |

## 3. Complete Parameter Inventory

The table below lists every parameter exposed by `Invoke-EntraIdentityDecommissioningControlPlane.ps1` as returned by:

```powershell
(Get-Command .\Invoke-EntraIdentityDecommissioningControlPlane.ps1).Parameters.Keys | Sort-Object
```

| Parameter                             | Type             | Required? | Default if known   | Safety category                   | Read-only?                            | Writes to tenant?       | Purpose                                                                                | Typical use                                             | Related output artifacts                                                       | Notes / warnings                                                                   |
| ------------------------------------- | ---------------- | --------- | ------------------ | --------------------------------- | ------------------------------------- | ----------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------- |
| `ActionId`                            | String           | No        | None               | Controlled execution              | No                                    | Possible                | Filter approved remediation actions by ID                                              | Narrow an execution or plan review to a specific action | Execution logs, approval/execution artifacts                                   | Use only with approved action sets                                                 |
| `AllowFinalDelete`                    | Switch           | No        | False              | Dangerous / restricted            | No                                    | Yes                     | Allows final-delete stage in controlled NHI workflows                                  | Lab-only or explicitly approved final-delete workflows  | Final-delete readiness / plan artifacts                                        | High-risk; never use casually                                                      |
| `AllowHumanExecution`                 | Switch           | No        | False              | Dangerous / restricted            | No                                    | Yes                     | Permits human-approved execution paths where available                                 | Controlled execution only                               | Execution logs, approval artifacts                                             | Treat as execution-enabling                                                        |
| `ApprovalManifestPath`                | String           | No        | None               | Approval / gating                 | Yes for generation; no for validation | No by itself            | Points to an approval manifest used to gate or validate work                           | WhatIf, approval validation, execution gating           | Approval manifest, approval diff, execution gating artifacts                   | Input-only when validating or executing                                            |
| `ApprovedManifestPath`                | String           | No        | None               | Approval / gating                 | Yes                                   | No by itself            | Points to a pre-approved manifest for execution                                        | Controlled execution only                               | Approved manifest input, execution logs                                        | Must match the execution plan                                                      |
| `Assessor`                            | String           | No        | None               | Read-only reporting               | Yes                                   | No                      | Records who performed the assessment                                                   | Reporting and handoff artifacts                         | Executive summary, traceability, assessment outputs                            | Useful for client defensibility                                                    |
| `BaselinePath`                        | String           | No        | None               | Read-only reporting               | Yes                                   | No                      | Provides a prior baseline for comparison                                               | Deltas, trend review, re-assessment                     | Assessment comparison outputs                                                  | Path must point to prior output data                                               |
| `ClientId`                            | String           | No        | None               | Read-only / connection            | No                                    | No                      | Client application identifier for Graph access                                         | Live assessment or tenant connection                    | Assessment outputs                                                             | Needs code confirmation for exact auth path in all modes                           |
| `ClientName`                          | String           | No        | None               | Reporting                         | Yes                                   | No                      | Records the client name in artifacts                                                   | Client-facing output                                    | Executive summary, handoff artifacts                                           | Prefer a consistent legal/client name                                              |
| `Confirm`                             | Common parameter | No        | PowerShell default | Dangerous / restricted            | No                                    | Possible                | PowerShell confirmation prompt control                                                 | Execution or destructive-style commands                 | Depends on command path                                                        | Standard PowerShell common parameter                                               |
| `Debug`                               | Common parameter | No        | PowerShell default | Diagnostic                        | Yes                                   | No                      | Enables debug output                                                                   | Troubleshooting                                         | Console / debug stream                                                         | Standard PowerShell common parameter                                               |
| `DecommissionPlanPath`                | String           | No        | None               | Controlled execution / planning   | Yes                                   | No by itself            | Points to a decommission plan used by controlled NHI workflows                         | Controlled execution or validation                      | Decommission plan, readiness artifacts                                         | Input-only; must be valid and reviewed                                             |
| `DemoMode`                            | Switch           | No        | False              | Safe with caution                 | Yes                                   | No                      | Runs against a synthetic demo tenant context and auto-enables several report artifacts | Demos and walk-throughs                                 | Demo outputs, local reports, handoff artifacts                                 | Good for offline demos; not a tenant write path                                    |
| `EngagementId`                        | String           | No        | None               | Reporting                         | Yes                                   | No                      | Identifies the engagement in artifacts                                                 | Client delivery and traceability                        | Report headers, manifests, handoff artifacts                                   | Useful for multi-run correlation                                                   |
| `ErrorAction`                         | Common parameter | No        | PowerShell default | Diagnostic                        | No                                    | No                      | Controls error handling                                                                | Troubleshooting and automation                          | Console / stream behavior                                                      | Standard PowerShell common parameter                                               |
| `ErrorVariable`                       | Common parameter | No        | PowerShell default | Diagnostic                        | Yes                                   | No                      | Captures errors into a variable                                                        | Automation / troubleshooting                            | None directly                                                                  | Standard PowerShell common parameter                                               |
| `ExecuteNhiControlledDecommission`    | Switch           | No        | False              | Dangerous / restricted            | No                                    | Yes                     | Enables controlled NHI decommission execution path                                     | Only after approval and plan validation                 | Controlled execution logs, NHI action logs                                     | Requires plan and approval artifacts                                               |
| `ExecuteNhiControlledGrantCleanup`    | Switch           | No        | False              | Dangerous / restricted            | No                                    | Yes                     | Enables controlled grant cleanup                                                       | Only after approval and validation                      | Grant cleanup plan / action log                                                | High-risk execution path                                                           |
| `ExecuteNhiControlledMetadataCleanup` | Switch           | No        | False              | Dangerous / restricted            | No                                    | Yes                     | Enables controlled metadata cleanup                                                    | Only after approval and validation                      | Metadata cleanup plan / action log                                             | High-risk execution path                                                           |
| `ExecuteNhiDecommission`              | Switch           | No        | False              | Dangerous / restricted            | No                                    | Yes                     | Enables the main decommission execution path                                           | Explicitly approved live remediation                    | Execution logs, snapshots, attestation artifacts                               | Do not use in read-only assessment                                                 |
| `ExecutionOutputPath`                 | String           | No        | `.\out\execution`  | Execution / rollback              | Yes                                   | No by itself            | Stores execution artifacts and rollback state                                          | Execution and rollback workflows                        | Snapshot manifests, execution logs                                             | Ensure path is preserved for rollback                                              |
| `ExecutionRunId`                      | String           | No        | None               | Execution / rollback              | Yes                                   | No by itself            | Identifies an execution run for rollback or traceability                               | Rollback, audit, execution correlation                  | Snapshot manifest, rollback inputs                                             | Must match prior execution artifacts                                               |
| `ExecutionStage`                      | String           | No        | `ValidateOnly`     | Controlled execution              | No                                    | Yes                     | Chooses the controlled NHI stage                                                       | Controlled NHI workflows                                | Stage-specific plan / log artifacts                                            | Needs code confirmation for stage-by-stage behavior in every branch                |
| `GenerateApprovalDiff`                | Switch           | No        | False              | Read-only reporting               | Yes                                   | No                      | Produces approval-plan differences                                                     | Review planning changes                                 | Approval diff JSON/MD/HTML                                                     | Local artifact only                                                                |
| `GenerateApprovalTemplate`            | Switch           | No        | False              | Planning / approval               | Yes                                   | No                      | Produces a WhatIf approval template                                                    | Draft approval planning                                 | Approval template / WhatIf plan                                                | Usually paired with `-Mode WhatIfRemediation`                                      |
| `GenerateClientHandoff`               | Switch           | No        | False              | Safe                              | Yes                                   | No                      | Produces client handoff artifacts                                                      | Client delivery package                                 | Client handoff manifest/index                                                  | Local artifact only                                                                |
| `GenerateEvidenceBundle`              | Switch           | No        | False              | Safe                              | Yes                                   | No                      | Produces evidence bundle artifacts                                                     | Evidence archive for client or internal review          | Evidence bundle manifest/index/hash files                                      | Local artifact only                                                                |
| `GenerateExecutivePack`               | Switch           | No        | False              | Safe                              | Yes                                   | No                      | Produces executive summary package                                                     | Client summary / executive review                       | Executive summary artifacts                                                    | Local artifact only                                                                |
| `GenerateNhiGovernancePack`           | Switch           | No        | False              | Safe / read-only reporting        | Yes                                   | No                      | Produces NHI governance reporting artifacts                                            | Governance review                                       | NHI inventory, governance dashboard, executive summary, write-readiness report | Local artifact only                                                                |
| `GenerateRedactedPackage`             | Switch           | No        | False              | Safe                              | Yes                                   | No                      | Produces a client-safe redacted package                                                | Client handoff                                          | Redacted package artifacts                                                     | Use with sensitivity-aware outputs                                                 |
| `GenerateReleasePackage`              | Switch           | No        | False              | Safe / offline packaging          | Yes                                   | No                      | Produces a release package from local artifacts                                        | Packaging after self-test / validation                  | Release package manifest and copied artifacts                                  | Needs code confirmation for all included folders                                   |
| `GenerateReplayValidation`            | Switch           | No        | False              | Safe                              | Yes                                   | No                      | Produces replay validation artifacts                                                   | Compare prior output / evidence consistency             | Replay validation report JSON/MD                                               | Input artifacts may be required                                                    |
| `GenerateRev35Readiness`              | Switch           | No        | False              | Safe                              | Yes                                   | No                      | Produces Rev3.5/Rev35 readiness artifacts                                              | Release / readiness review                              | Readiness report JSON/MD                                                       | Local artifact only                                                                |
| `GenerateTraceabilityReport`          | Switch           | No        | False              | Safe                              | Yes                                   | No                      | Produces traceability reports                                                          | Evidence mapping and auditability                       | Traceability report JSON/CSV/MD/HTML                                           | Local artifact only                                                                |
| `IncludeAgentActivityAudit`           | Switch           | No        | False              | Controlled execution              | No                                    | Possible                | Includes agent activity audit detail in execution artifacts                            | Higher-audit execution runs                             | Execution / audit artifacts                                                    | Prefer only when audit detail is needed                                            |
| `InformationAction`                   | Common parameter | No        | PowerShell default | Diagnostic                        | No                                    | No                      | Controls information stream handling                                                   | Automation / troubleshooting                            | Console / stream behavior                                                      | Standard PowerShell common parameter                                               |
| `InformationVariable`                 | Common parameter | No        | PowerShell default | Diagnostic                        | Yes                                   | No                      | Captures information stream                                                            | Automation / troubleshooting                            | None directly                                                                  | Standard PowerShell common parameter                                               |
| `MaxActions`                          | Int32            | No        | `25`               | Controlled execution / planning   | No                                    | Yes if execution occurs | Caps the number of actions processed                                                   | Safety limit for execution batches                      | Execution plan / log artifacts                                                 | Keep conservative in live environments                                             |
| `Mode`                                | String           | No        | `Assessment`       | Operating mode                    | No                                    | Depends on mode         | Chooses assessment, planning, export, or execution flow                                | Primary mode selection                                  | Depends on mode                                                                | ValidateSet: `Assessment`, `WhatIfRemediation`, `ExportPlan`, `ExecuteRemediation` |
| `NoLogo`                              | Switch           | No        | False              | Cosmetic                          | Yes                                   | No                      | Suppresses banner output                                                               | Cleaner automation logs                                 | None                                                                           | No safety impact                                                                   |
| `NonInteractive`                      | Switch           | No        | False              | Execution / automation            | No                                    | Possible                | Skips interactive prompts where supported                                              | Automation and CI-style runs                            | Execution logs                                                                 | Do not use casually with execution paths                                           |
| `OutBuffer`                           | Common parameter | No        | PowerShell default | Diagnostic                        | No                                    | No                      | Pipeline buffering control                                                             | Advanced PowerShell usage                               | None directly                                                                  | Standard PowerShell common parameter                                               |
| `OutputPath`                          | String           | No        | `.\out`            | Safe / local artifacts            | Yes                                   | No                      | Base output directory for generated artifacts                                          | Most offline and live read-only runs                    | Many report and manifest files                                                 | Keep path isolated and reviewable                                                  |
| `OutVariable`                         | Common parameter | No        | PowerShell default | Diagnostic                        | Yes                                   | No                      | Captures pipeline output                                                               | Automation / troubleshooting                            | None directly                                                                  | Standard PowerShell common parameter                                               |
| `PhaseLimit`                          | Int32            | No        | `1`                | Controlled execution / gating     | No                                    | Possible                | Limits approved execution phases                                                       | Execution gating and approval validation                | Execution gating artifacts                                                     | Validate phase-by-phase before use                                                 |
| `PipelineVariable`                    | Common parameter | No        | PowerShell default | Diagnostic                        | Yes                                   | No                      | Stores pipeline output into a variable                                                 | Advanced scripting                                      | None directly                                                                  | Standard PowerShell common parameter                                               |
| `ProgressAction`                      | Common parameter | No        | PowerShell default | Diagnostic                        | No                                    | No                      | Controls progress display                                                              | Automation and console control                          | None directly                                                                  | Standard PowerShell common parameter                                               |
| `RedactionProfile`                    | String           | No        | `ClientSafe`       | Safe / packaging                  | Yes                                   | No                      | Chooses the redaction policy for generated packages                                    | Client-safe packaging                                   | Redaction report, redacted package                                             | ValidateSet: `ClientSafe`, `PublicDemo`, `Strict`, `Internal`                      |
| `ReleasePackagePath`                  | String           | No        | `.\release\Rev3.4` | Safe / offline packaging          | Yes                                   | No                      | Target folder for release package output                                               | SelfTest and release packaging                          | Release package files                                                          | Path naming may need code confirmation for current release versioning              |
| `RequirePreflightConfirm`             | Switch           | No        | False              | Controlled execution              | No                                    | Possible                | Requires a preflight confirmation step                                                 | Extra safety before live actions                        | Execution gating artifacts                                                     | Keep enabled for live execution paths                                              |
| `RequireSecondConfirmation`           | Switch           | No        | False              | Controlled execution              | No                                    | Possible                | Requires a second confirmation step                                                    | Additional human gate before execution                  | Execution gating artifacts                                                     | Safety prompt only; not a substitute for approval artifacts                        |
| `Rollback`                            | Switch           | No        | False              | High risk                         | No                                    | Possible                | Triggers rollback workflow using prior execution artifacts                             | Recovery from prior execution                           | Snapshot manifests, rollback logs                                              | Requires valid `ExecutionRunId` and preserved output path                          |
| `ScreamTestDays`                      | Int32            | No        | `30`               | Controlled execution / validation | No                                    | Possible                | Controls the scream-test window in days                                                | Execution validation and readiness                      | Execution validation / status artifacts                                        | Used in execution status calculations                                              |
| `ScreamTestWindowHours`               | Int32            | No        | `24`               | Controlled execution / validation | No                                    | Possible                | Controls the scream-test window in hours for controlled NHI workflows                  | Readiness and validation planning                       | Readiness / validation artifacts                                               | Validate range before use                                                          |
| `SelfTest`                            | Switch           | No        | False              | Safe / offline                    | Yes                                   | No                      | Runs offline release validation and exits before tenant connection                     | Parser/import/module/release validation                 | Release validation report, optional release package                            | Best first command for local validation                                            |
| `TenantId`                            | String           | No        | None               | Live assessment / execution       | No                                    | Possible                | Selects the tenant target                                                              | Live read-only assessment or execution                  | All tenant-scoped reports                                                      | Required for live tenant workflows                                                 |
| `Verbose`                             | Common parameter | No        | PowerShell default | Diagnostic                        | No                                    | No                      | Enables verbose output                                                                 | Troubleshooting                                         | Console / stream behavior                                                      | Standard PowerShell common parameter                                               |
| `WarningAction`                       | Common parameter | No        | PowerShell default | Diagnostic                        | No                                    | No                      | Controls warning handling                                                              | Automation / troubleshooting                            | Console / stream behavior                                                      | Standard PowerShell common parameter                                               |
| `WarningVariable`                     | Common parameter | No        | PowerShell default | Diagnostic                        | Yes                                   | No                      | Captures warnings                                                                      | Automation / troubleshooting                            | None directly                                                                  | Standard PowerShell common parameter                                               |
| `WhatIf`                              | Common parameter | No        | PowerShell default | Diagnostic / safe preview         | No                                    | No                      | PowerShell WhatIf semantics                                                            | Previewing commands                                     | Console behavior                                                               | Standard PowerShell common parameter                                               |
| `WhatIfExecution`                     | Switch           | No        | False              | Planning / controlled NHI         | No                                    | No by itself            | Enables controlled NHI WhatIf-style execution paths without live mutation              | Planning and simulation                                 | WhatIf / approval artifacts                                                    | Needs code confirmation for exact branch behavior                                  |
| `WhatIfManifestPath`                  | String           | No        | None               | Planning / validation             | Yes for output; no for validation     | No by itself            | Points to a WhatIf manifest used for planning, validation, or replay comparison        | Planning and validation workflows                       | WhatIf manifest, replay validation, approval diff                              | Input-only when validating or executing                                            |

### Notes on parameter inventory

- The `Mode` parameter is the top-level branch selector for the main entry script.
- Common PowerShell parameters are inherited and not part of the tool's domain logic, but they are listed here because they appear in the actual command surface.
- Any parameter documented as "Needs code confirmation" was observed in the parameter surface, but the exact output naming or behavior should be rechecked in code before relying on it for external automation.

## 4. Safe Consultant Run Recipes

### 4.1 Offline parser/import/focused test gate

Use this when you want to validate the repo without touching a tenant.

```powershell
Invoke-Pester -Path '.\tests\NhiDiscovery.Rev35.Tests.ps1'
Invoke-Pester -Path '.\tests\Reporting.Tests.ps1'
Invoke-Pester -Path '.\tests\PlatformIdentityCatalog.Rev410.Tests.ps1'
Invoke-Pester -Path '.\tests\Rev410.MicrosoftPlatform.Tests.ps1'
Invoke-Pester -Path '.\tests\SuppressCustomerRemediation.Rev410.Tests.ps1'
```

If you need a broader safety gate, run the full safety subset listed in Section 9.

### 4.2 Offline DemoMode output pack

Use this to generate sample local artifacts without tenant access.

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
  -DemoMode `
  -OutputPath '.\out\demo'
```

DemoMode is useful for walkthroughs and artifact inspection. It should not be used as a substitute for a real tenant assessment.

### 4.3 Live read-only tenant assessment

Use this when you want tenant-scoped assessment output without execution flags.

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
  -Mode Assessment `
  -TenantId '<tenant-id>' `
  -ClientId '<app-client-id-if-required>' `
  -ClientName 'Client Name' `
  -Assessor 'Consultant Name' `
  -OutputPath '.\out\client-assessment' `
  -GenerateExecutivePack `
  -GenerateClientHandoff `
  -GenerateTraceabilityReport `
  -GenerateReplayValidation `
  -GenerateEvidenceBundle `
  -GenerateRedactedPackage `
  -GenerateRev35Readiness `
  -GenerateNhiGovernancePack
```

Do not include any execution, rollback, or delete/cleanup switches in a read-only assessment run.

### 4.4 Client handoff package generation

Use this after a safe assessment to create client-facing delivery artifacts.

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
  -Mode Assessment `
  -TenantId '<tenant-id>' `
  -OutputPath '.\out\handoff' `
  -GenerateClientHandoff `
  -GenerateRedactedPackage `
  -GenerateEvidenceBundle `
  -GenerateExecutivePack `
  -GenerateTraceabilityReport
```

The client handoff path should stay client-safe. If sensitive data is present, prefer redaction before handoff.

### 4.5 Replay validation

Replay validation checks whether current outputs remain consistent with previously produced evidence or manifests.

- If there are no replay inputs, the tool should return `SkippedNoReplayInputs` and not pretend there was a validation failure.
- If there are existing outputs or manifests, replay validation compares current content with the saved evidence set.
- Use replay validation as an evidence consistency check, not as a replacement for assessment.

Example:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
  -Mode Assessment `
  -TenantId '<tenant-id>' `
  -OutputPath '.\out\replay' `
  -GenerateReplayValidation
```

### 4.6 Self-test / readiness validation

`SelfTest` is an offline entry path. It runs release validation before any tenant connection or discovery work begins.

Observed behavior from code:

- It creates a self-test run folder under `OutputPath`.
- It calls the release validation workflow.
- If validation passes and `GenerateReleasePackage` is also set, it builds a release package from the self-test context.
- It exits before tenant connection / live assessment work.

Use it when:

- you want to verify parser/import/module wiring,
- you want a local release gate before client delivery,
- you want to confirm the repo can generate expected artifacts without touching a tenant.

Example:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
  -SelfTest `
  -OutputPath '.\out\selftest' `
  -GenerateReleasePackage `
  -ReleasePackagePath '.\release\Rev4.10'
```

### 4.7 Approval manifest validation

The following parameters are relevant to approval gating:

- `ApprovalManifestPath`
- `ApprovedManifestPath`
- `WhatIfManifestPath`
- `GenerateApprovalTemplate`
- `GenerateApprovalDiff`

Observed behavior from code:

- `GenerateApprovalTemplate` is used in the planning / WhatIf branch to produce an approval template.
- `WhatIfManifestPath` is used as a WhatIf planning artifact and can also feed validation and replay-style comparisons.
- `ApprovalManifestPath` is used as an input manifest for validation and execution gating.
- `ApprovedManifestPath` is used as an input-approved artifact for controlled execution paths.

Classification:

- Input-only: `ApprovalManifestPath`, `ApprovedManifestPath`, `WhatIfManifestPath` when used to validate or execute
- Generated output: `GenerateApprovalTemplate`, `GenerateApprovalDiff`

### 4.8 WhatIf / controlled decommission planning

Use `-Mode WhatIfRemediation` when you want a non-executing remediation plan and approval draft.

Example:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
  -Mode WhatIfRemediation `
  -TenantId '<tenant-id>' `
  -OutputPath '.\out\whatif' `
  -GenerateApprovalTemplate `
  -WhatIfManifestPath '.\out\whatif\whatif-manifest.json'
```

This is planning only. It is not live removal unless execution switches are also used.

## 5. Dangerous / Restricted Parameters

### High-risk execution switches

The following switches and modes can enable live execution, cleanup, rollback, or irreversible actions:

- `-ExecuteNhiDecommission`
- `-ExecuteNhiControlledDecommission`
- `-ExecuteNhiControlledGrantCleanup`
- `-ExecuteNhiControlledMetadataCleanup`
- `-AllowFinalDelete`
- `-AllowHumanExecution`
- `-Rollback`
- `-Mode ExecuteRemediation`

What they enable:

- `ExecuteNhiDecommission` enables the main decommission execution path.
- `ExecuteNhiControlledDecommission`, `ExecuteNhiControlledGrantCleanup`, and `ExecuteNhiControlledMetadataCleanup` enable staged controlled NHI actions.
- `AllowFinalDelete` unlocks final-delete behavior in controlled workflows.
- `AllowHumanExecution` enables human-approved execution paths.
- `Rollback` triggers recovery from prior execution artifacts.
- `Mode ExecuteRemediation` enters the live remediation branch.

Why they are dangerous:

- They can change tenant state.
- They can delete, disable, or clean up identities or permissions.
- They can make irreversible changes when final-delete is enabled.
- They can create compliance or recovery risk if run without reviewed approval artifacts.

Prerequisites before use:

- Reviewed approval artifacts.
- Known execution scope.
- Confirmed tenant and client context.
- Preserved execution snapshot / rollback data where applicable.
- Explicit operator approval.

Approval expectations:

- Use only in approved workflows.
- Prefer lab or tightly controlled staging environments first.
- Keep `AllowFinalDelete` disabled unless the workflow explicitly authorizes the final-delete stage.

Evidence required before use:

- A validated plan or approval manifest.
- Read-back or replay evidence when available.
- Traceability and handoff artifacts for the approved scope.

Rollback evidence required:

- Valid `ExecutionRunId`.
- Preserved `ExecutionOutputPath`.
- Snapshot manifest and related execution artifacts.
- Proof that the rollback target matches the original execution.

## 6. Never Combine Casually Matrix

| Risky combination                                                                   | Why risky                                        | Safer alternative                                               |
| ----------------------------------------------------------------------------------- | ------------------------------------------------ | --------------------------------------------------------------- |
| Any `Execute*` parameter + live `-TenantId`                                         | Can mutate tenant state                          | Run read-only assessment or WhatIf first                        |
| `-AllowFinalDelete` + any execution mode                                            | Unlocks irreversible behavior                    | Keep final delete disabled until explicitly authorized          |
| Cleanup modes + missing approval manifest                                           | No approved scope to gate execution              | Generate and validate approval artifacts first                  |
| `-Rollback` + missing `-ExecutionRunId` / `-ExecutionOutputPath`                    | Rollback cannot prove what to reverse            | Preserve and point to the exact execution artifacts             |
| `-GenerateClientHandoff` without redaction when sensitive output exists             | May expose client-internal data                  | Add `-GenerateRedactedPackage` and use client-safe outputs      |
| `-ExecuteNhiControlledDecommission` + `-AllowFinalDelete` without explicit approval | Irreversible change risk                         | Lab-only or approved final-delete workflow only                 |
| `-ExecuteNhiDecommission` + `-NonInteractive`                                       | Can remove human friction from live execution    | Keep interactive prompts unless automation is formally approved |
| `-Mode ExecuteRemediation` + `-WhatIf` alone                                        | Confusing semantics; may not execute as expected | Use a clearly approved execution path or a separate WhatIf run  |

## 7. Output Artifact Map

| Switch / mode                          | Artifact produced                             | File pattern                                                                                                                   | Client-safe?         | Internal-only? | Evidence value | Notes                                     |
| -------------------------------------- | --------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ | -------------------- | -------------- | -------------- | ----------------------------------------- |
| `-SelfTest`                            | Release validation report                     | `release-validation-report-*.json` / `.md`                                                                                     | Yes                  | No             | High           | Offline gate before tenant access         |
| `-DemoMode`                            | Demo assessment bundle                        | Demo-named output files under `OutputPath`                                                                                     | Usually yes          | No             | Medium         | Synthetic tenant context                  |
| `-Mode Assessment`                     | Assessment findings                           | `assessment-*.csv`, `assessment-*.json`, `assessment-*.html`                                                                   | Depends on redaction | Sometimes      | High           | Core read-only assessment output          |
| `-Mode WhatIfRemediation`              | WhatIf remediation plan                       | `whatif-approval-template*.json` / planning artifacts                                                                          | Usually internal     | Yes            | High           | Planning only                             |
| `-GenerateExecutivePack`               | Executive summary package                     | `executive-summary-*.md` / `.html` or pack outputs                                                                             | Yes                  | No             | High           | Client-facing summary                     |
| `-GenerateClientHandoff`               | Client handoff manifest and index             | `client-handoff-manifest-*.json`, `client-handoff-index-*.md`                                                                  | Yes                  | No             | High           | Lists deliverable artifacts               |
| `-GenerateRedactedPackage`             | Redacted client-safe package                  | `redacted\...` artifacts and redaction report                                                                                  | Yes                  | No             | High           | Use for client delivery                   |
| `-GenerateEvidenceBundle`              | Evidence bundle manifest and index            | `evidence-bundle-manifest-*.json`, `evidence-bundle-index-*.md`, hash manifests                                                | Often yes            | No             | High           | Strong audit value                        |
| `-GenerateTraceabilityReport`          | Traceability report                           | `traceability-report-*.json`, `.csv`, `.md`, `.html`                                                                           | Often yes            | No             | High           | Maps findings to evidence                 |
| `-GenerateReplayValidation`            | Replay validation report                      | `replay-validation-report-*.json`, `.md`                                                                                       | Yes                  | No             | High           | Checks evidence consistency               |
| `-GenerateRev35Readiness`              | Readiness report                              | `rev35-readiness-report-*.json`, `.md`                                                                                         | Usually yes          | No             | High           | Release / readiness gate                  |
| `-GenerateNhiGovernancePack`           | NHI governance outputs                        | `nhi-inventory-*.csv`, `nhi-governance-dashboard-*.html`, `nhi-executive-summary-*.md`, `nhi-rev4-write-readiness-report-*.md` | Often yes            | No             | High           | Governance-focused package                |
| `-GenerateApprovalDiff`                | Approval diff                                 | `approval-diff-*.json`, `.md`, `.html`                                                                                         | Usually internal     | Yes            | High           | Compare approval state                    |
| `-GenerateApprovalTemplate`            | Approval template                             | Planning / approval template artifacts                                                                                         | Usually internal     | Yes            | High           | Used for planning and gating              |
| `-ExecuteNhiDecommission`              | Execution logs / snapshots                    | `SnapshotManifest-*.json`, execution logs                                                                                      | No                   | Sometimes      | High           | Live execution path                       |
| `-ExecuteNhiControlledDecommission`    | Controlled decommission plan / logs           | Controlled execution artifacts                                                                                                 | No                   | Sometimes      | High           | High-risk controlled workflow             |
| `-ExecuteNhiControlledGrantCleanup`    | Grant cleanup plan / logs                     | Controlled grant cleanup artifacts                                                                                             | No                   | Sometimes      | High           | High-risk controlled workflow             |
| `-ExecuteNhiControlledMetadataCleanup` | Metadata cleanup plan / logs                  | Controlled metadata cleanup artifacts                                                                                          | No                   | Sometimes      | High           | High-risk controlled workflow             |
| `-Rollback`                            | Rollback state and logs                       | `SnapshotManifest-*.json`, rollback logs                                                                                       | No                   | Sometimes      | High           | Requires preserved execution state        |
| `-AllowFinalDelete`                    | Final-delete readiness / simulation artifacts | Final-delete plan outputs                                                                                                      | No                   | Yes            | High           | Irreversible behavior if used incorrectly |

Additional artifact families commonly generated by the underlying modules include:

- findings JSON / CSV / HTML
- assessment CSV / JSON / HTML
- remediation plan MD
- output manifest JSON / CSV
- executive summary MD / HTML
- client handoff index / manifest
- redaction report JSON / MD
- evidence bundle manifest / index / hash manifest
- traceability report JSON / CSV / MD / HTML
- replay validation report JSON / MD
- readiness report JSON / MD
- NHI governance pack artifacts

## 8. Consultant Decision Tree

### I only want to test the tool offline

Use `-SelfTest` or run the test suite directly. Do not provide a tenant ID or any execution switches.

### I want a demo report

Use `-DemoMode` and local output generation switches only. Keep it synthetic.

### I want a live read-only client assessment

Use `-Mode Assessment` with tenant-scoped reporting switches only. Do not include execution or rollback parameters.

### I want a client-safe handoff package

Use the assessment outputs plus `-GenerateClientHandoff`, `-GenerateRedactedPackage`, and `-GenerateEvidenceBundle`.

### I want to verify evidence / replay

Use `-GenerateReplayValidation` with the saved outputs or replay inputs.

### I want to plan NHI decommissioning

Use the controlled planning or WhatIf path, validate the approval artifacts, and keep execution switches off.

### I think I am ready to remove / disable an NHI

This is a high-risk step. Confirm the approval manifest, execution run identifiers, and rollback evidence before using any execution switch.

### I need rollback

Use the rollback path only when the prior execution artifacts are intact and validated.

### I am considering final delete

Treat this as prohibited unless explicitly approved. Final delete should never be a casual test or a default action.

## 9. Validation Commands

Parameter inventory:

```powershell
(Get-Command .\Invoke-EntraIdentityDecommissioningControlPlane.ps1).Parameters.Keys | Sort-Object
```

Parser sweep:

```powershell
Get-ChildItem -Recurse -Include *.ps1,*.psm1 -File | ForEach-Object {
  [void][scriptblock]::Create((Get-Content -LiteralPath $_.FullName -Raw))
}
```

Focused Rev4.10 tests:

```powershell
Invoke-Pester -Path '.\tests\Reporting.Tests.ps1'
Invoke-Pester -Path '.\tests\PlatformIdentityCatalog.Rev410.Tests.ps1'
Invoke-Pester -Path '.\tests\Rev410.MicrosoftPlatform.Tests.ps1'
Invoke-Pester -Path '.\tests\SuppressCustomerRemediation.Rev410.Tests.ps1'
```

Full safety subset:

```powershell
Invoke-Pester -Path @(
'.\tests\DestructiveCmdletGuard.Rev40.Tests.ps1',
'.\tests\NhiExecution.Rev40.Tests.ps1',
'.\tests\NhiExecutionSchema.Rev40.Tests.ps1',
'.\tests\NhiSafety.Rev35.Tests.ps1',
'.\tests\Safety.Tests.ps1',
'.\tests\Safety.Rev42.Tests.ps1',
'.\tests\Safety.Rev43.Tests.ps1',
'.\tests\Safety.Rev44.Tests.ps1',
'.\tests\Safety.Rev45.Tests.ps1',
'.\tests\Safety.Rev46.Tests.ps1',
'.\tests\Safety.Rev47.Tests.ps1',
'.\tests\Safety.Rev48.Tests.ps1',
'.\tests\Safety.Rev49.Tests.ps1'
)
```

Git clean status:

```powershell
git status --short
```

Output artifact inventory:

```powershell
Get-ChildItem -Recurse .\out,.\release -File | Select-Object FullName, Length, LastWriteTime
```

### 4.11 Rev4.11 approved reversible lab NHI planning proof

Rev4.11 is an offline proof that one approved customer or lab NHI can produce a reversible planning result without any live tenant write.

It proves:

- An approved lab target can pass the controlled approval gate and produce a reversible `DisableOnly` planning result.
- Platform identities such as Microsoft Graph PowerShell and iOS Accounts remain evidence-only or information-only and do not produce executable actions.
- Unapproved targets and missing approval metadata fail closed.
- Final-delete planning stays blocked.

It does not prove:

- Live tenant mutation.
- Actual NHI removal or rollback execution.
- Final-delete execution.
- Grant cleanup or metadata cleanup authorization.

No live tenant write was performed for Rev4.11. The next forward-looking step remains Run #4C, which is a live reversible lab disable in a lab-only tenant.

### 4.12 Rev4.12 lab live reversible disable readiness gate

Rev4.12 is an offline readiness gate for a future lab-only live reversible disable attempt.

It proves:

- The target is explicitly lab-only.
- The approval manifest is present and integrity-checked.
- The approval metadata is complete and unexpired.
- The requested action is reversible disable only.
- Snapshot evidence, rollback readiness evidence, and observation metadata are present.
- Platform identities, suppressed identities, unapproved targets, and cleanup or final-delete requests remain blocked.

It does not prove:

- Live tenant mutation.
- Actual disable execution.
- Rollback execution.
- Final-delete execution.
- Grant cleanup or metadata cleanup authorization.

No live tenant write was performed for Rev4.12. No actual disable was performed. No rollback was performed. No final delete was performed.

Before any future Run #4C live lab disable, the following must be present:

- Explicit lab-only target marking.
- Approved manifest with valid integrity hash.
- Complete, unexpired approval metadata.
- Pre-action snapshot evidence.
- Rollback readiness evidence.
- Observation or scream-test window metadata.
- No platform or suppressed identity classification.

### 4.13 Rev4.13 lab-only live reversible disable dry-run package

Rev4.13 is an operator-readiness artifact only. It converts an already-approved lab-only reversible disable readiness result into a reviewable dry-run package without executing the operation.

It proves:

- The approved lab target can be packaged for human review with dry-run metadata.
- The package records tenant-write intent as false and execution as not performed.
- The planned action is reversible disable only.
- Approval, snapshot, rollback readiness, and observation metadata can be assembled into a single local artifact.
- Prohibited operations are explicitly listed and remain blocked.

It does not prove:

- Live tenant mutation.
- Actual NHI disable execution.
- NHI removal.
- Rollback execution.
- Final delete execution.
- Grant cleanup, metadata cleanup, or credential deletion.

Required inputs:

- Approved lab-only target.
- Readiness verdict from `Test-NhiControlledLabLiveReversibleDisableReadiness`.
- Approval metadata.
- Pre-action snapshot metadata.
- Rollback readiness metadata.
- Observation / scream-test metadata.

Generated artifacts:

- Local JSON package artifact.
- Optional Markdown artifact if the calling workflow supports it.

Safety boundaries:

- No live tenant write is performed.
- No actual disable is performed.
- No rollback is performed.
- No final delete is allowed.
- No secrets, tokens, or raw tenant credentials are exported.

No live execution statement:

- Rev4.13 is a dry-run package only. It does not execute a lab disable, and it remains separate from any future Run #4C live lab operation.

### 4.14 Rev4.14 rollback drill package

Rev4.14 is an operator-readiness artifact only. It packages rollback steps, evidence, and decision gates for the same future lab-only reversible disable scenario without executing rollback.

It proves:

- A rollback drill can be packaged before any future live reversible disable is attempted.
- The rollback package records a non-executed rollback drill.
- The package links to the pre-action baseline and the source dry-run package when available.
- Rollback trigger and validation criteria can be documented without performing recovery actions.
- Prohibited rollback behaviors are explicitly listed and blocked.

It does not prove:

- Live tenant mutation.
- Actual rollback execution.
- NHI removal or object recreation.
- Grant cleanup, metadata cleanup, or credential modification.
- Final delete execution.

Required inputs:

- Approved lab-only target.
- Pre-action snapshot baseline.
- Rollback trigger criteria.
- Rollback validation criteria.
- Source dry-run package linkage, if the workflow uses linkage.

Generated artifacts:

- Local JSON rollback drill package artifact.
- Optional Markdown artifact if the calling workflow supports it.

Safety boundaries:

- No rollback is performed.
- No live tenant write is performed.
- No final delete is allowed.
- No objects are deleted, removed, or recreated.
- No secrets, tokens, or raw tenant credentials are exported.

No rollback execution statement:

- Rev4.14 is a rollback drill package only. It does not execute rollback, and it remains separate from any future Run #4C live lab operation.

### 4.15 Run #4C lab live reversible disable

Run #4C is the first controlled live-write milestone. It is lab-only, reversible-disable only, and must remain narrow enough to touch exactly one approved target.

It proves:

- A single approved lab target can pass the live gate after the offline readiness, dry-run, and rollback drill artifacts are present.
- The live wrapper records execution evidence locally.
- The execution path can be blocked cleanly when approval, snapshot, rollback, observation, or target eligibility is missing.

It does not prove:

- Production execution.
- Multiple-target execution.
- Final delete.
- Grant cleanup.
- Metadata cleanup.
- Credential deletion.
- Rollback execution.

Required inputs:

- One lab-only approved service principal target.
- Approval manifest artifact.
- Pre-action snapshot artifact.
- Rev4.12 readiness verdict.
- Rev4.13 dry-run package.
- Rev4.14 rollback drill package.
- Observation / scream-test plan.

Generated artifacts:

- Local execution evidence JSON.
- Optional command preview in the console or local evidence record.

Safety boundaries:

- Do not run against production or customer-critical targets.
- Do not run against MicrosoftPlatform, ExternalVendorPlatform, suppressed, evidence-only, or information-only targets.
- Do not run `-AllowFinalDelete`, `-ExecuteNhiDecommission`, `-ExecuteNhiControlledGrantCleanup`, or `-ExecuteNhiControlledMetadataCleanup`.
- Do not call remove, grant cleanup, metadata cleanup, or credential deletion paths.
- Do not execute rollback unless a separate, explicit failure response is approved later.

Preflight example:

```powershell
$run4c = Invoke-NhiControlledLabLiveReversibleDisable `
  -Target @($target) `
  -ApprovalManifest $approvalManifest `
  -ApprovalManifestPath '.\out\run4c\approval-manifest.json' `
  -Snapshot $snapshot `
  -ReadinessResult $readinessVerdict `
  -DryRunPackage $dryRunPackage `
  -RollbackPackage $rollbackPackage `
  -ObservationMetadata $observationPlan `
  -RunId 'RUN4C-LAB-001' `
  -OutputPath '.\out\run4c' `
  -LabExecutionApproved $false `
  -RequestedOperations @('ReversibleDisable') `
  -WhatIf
```

Do not run the following without final go/no-go approval:

```powershell
Invoke-NhiControlledLabLiveReversibleDisable `
  -Target @($target) `
  -ApprovalManifest $approvalManifest `
  -ApprovalManifestPath '.\out\run4c\approval-manifest.json' `
  -Snapshot $snapshot `
  -ReadinessResult $readinessVerdict `
  -DryRunPackage $dryRunPackage `
  -RollbackPackage $rollbackPackage `
  -ObservationMetadata $observationPlan `
  -RunId 'RUN4C-LAB-001' `
  -OutputPath '.\out\run4c' `
  -LabExecutionApproved $true `
  -RequestedOperations @('ReversibleDisable')
```

Run #4C remains separate from the offline Rev4.13 and Rev4.14 packages, and it should not be attempted until the operator has completed the preflight review and given an explicit final go/no-go.

## Rev4.16 Final Go/No-Go Review Package

Purpose:

- Build a single offline review artifact that decides whether a future Run #4C controlled dev/test reversible disable may proceed.

What it proves:

- Approval, snapshot, readiness, dry-run, rollback, and observation inputs are present and internally consistent.
- The target is lab/dev/test only and not blocked by platform, suppression, evidence-only, or information-only rules.
- A human decision is still required before any live-controlled action.

What it does not prove:

- No live tenant write.
- No disable.
- No rollback.
- No final delete.

Required inputs:

- Approved target identity.
- Approval manifest artifact.
- Pre-action snapshot artifact.
- Rev4.12 readiness verdict.
- Rev4.13 dry-run package.
- Rev4.14 rollback drill package.
- Observation plan.

Generated artifacts:

- Local JSON review package.

Safety boundaries:

- Do not mutate Entra ID.
- Do not perform live disable.
- Do not perform rollback.
- Do not allow final delete.

No live execution statement:

- This package is review-only and cannot be used to execute Run #4C.

## Rev4.17 Live Evidence Capture Package

Purpose:

- Define the exact evidence that must be captured before and after a future controlled reversible disable.

What it proves:

- The evidence checklist is complete for the planned future action.
- The package records the expected before/after evidence fields and prohibited changes.

What it does not prove:

- No live tenant write.
- No disable.
- No rollback.
- No final delete.

Required inputs:

- Approved target identity.
- Pre-action snapshot.
- Tenant identifier if available.

Generated artifacts:

- Local JSON evidence capture package.

Safety boundaries:

- This package does not execute any Graph change.
- It only defines evidence capture requirements.

No live execution statement:

- This package is evidence planning only and cannot disable a target.

## Rev4.18 Post-Disable Observation Package

Purpose:

- Define the post-disable observation window, success criteria, failure criteria, and rollback triggers for a future controlled reversible disable.

What it proves:

- Observation requirements are documented before any future live action.
- Monitoring ownership and escalation paths are explicit.

What it does not prove:

- No live tenant write.
- No disable.
- No rollback.
- No final delete.

Required inputs:

- Approved target identity.
- Observation window.
- Monitoring owner.
- Rollback contact.
- Pre-action snapshot.

Generated artifacts:

- Local JSON observation package.

Safety boundaries:

- Observation is planning only.
- This package must not mutate tenant state.

No live execution statement:

- This package does not run monitoring or trigger rollback.

## Rev4.19 Rollback Execution Readiness Package

Purpose:

- Determine whether rollback would be allowed after a future controlled reversible disable, without executing rollback.

What it proves:

- Original disable evidence, snapshot, observation trigger, and rollback drill inputs are present.
- The next action, if ever approved, would be re-enable only.

What it does not prove:

- No rollback execution.
- No live tenant write.
- No disable.
- No final delete.

Required inputs:

- Original disable evidence.
- Pre-action snapshot.
- Observation failure or manual rollback trigger.
- Rollback drill package.

Generated artifacts:

- Local JSON rollback-readiness package.

Safety boundaries:

- This package is readiness-only.
- It must not delete, remove, recreate, clean up grants, clean up metadata, or change credentials.

No live execution statement:

- This package does not execute rollback.

## 10. Accuracy Review

This runbook is generated from the actual Rev4.10 script and module parameter surface. If parameters are added or removed, update this file and rerun the parameter inventory command.

## Rev4.10 Final Local QA Summary

- Branch: `rev410-codex-build`
- Latest commit: `5f4c5f7` `test: add Rev4.10 controlled NHI removal simulation gate`
- Tag: `rev410-consultant-ready-platform-classification`

### Commit Summary

- `5f4c5f7` `test: add Rev4.10 controlled NHI removal simulation gate`
- `5215c66` `docs: add parameter and operating mode runbook`
- `96486ca` `fix: repair Rev4.0 push readiness parser error`
- `bb3f0b4` `docs: add Rev4.9 and Rev4.10 session summary`
- `835e8dd` `feat: Rev4.10 classify platform identities and suppress client-actionable remediation`

### Run Results

#### Run #1

Offline parser sweep plus focused Rev4.10/reporting tests.

- Parser sweep passed: 186 files parsed, 0 parser errors.
- Focused tests passed: 38 passed, 0 failed.
- A parser issue in `tools/Test-Rev40PushReadiness.ps1` was found and fixed in commit `96486ca`.

#### Run #2

Offline DemoMode output-pack gate.

- Generated the expected DemoMode output artifacts, including findings JSON, assessment CSV, remediation plan, HTML report, run manifest, output manifest, executive pack, client handoff, redaction report, evidence bundle outputs, replay validation report, Rev35 readiness report, and NHI governance demo artifacts.
- This was offline/DemoMode, not a live tenant write.

#### Run #3

Offline replay/readiness/evidence gate.

- JSON validity passed.
- Remediation-plan platform leak scan passed.
- Generic `AddApplicationOwner` actions were confirmed to be tied to demo/customer-style identities such as `copilot-hr-automation` and `contoso-serviceidentity-prod`, not Microsoft Graph PowerShell, Microsoft Tech Community, Flipgrid, or iOS Accounts.
- Full safety subset passed: 304 passed, 0 failed.

#### Run #4A

Offline controlled NHI removal fail-closed simulation.

- New test: `tests/NhiControlledRemovalSimulation.Rev410.Tests.ps1`
- New test passed: 6 passed, 0 failed.
- Combined Rev4.10/platform/suppression simulation tests passed.
- Full safety subset remained green: 304 passed, 0 failed.
- It proved platform identities, suppressed identities, unapproved targets, and missing approval metadata are blocked in offline simulation.
- It did not perform live NHI removal.

### Safety Confirmation

- No live tenant write operations were performed.
- No actual NHI removal was performed.
- No rollback execution was performed.
- No final delete was performed.
- No `-ExecuteNhiDecommission`, `-ExecuteNhiControlledDecommission`, `-ExecuteNhiControlledGrantCleanup`, `-ExecuteNhiControlledMetadataCleanup`, or `-AllowFinalDelete` path was used for live tenant mutation.

### Remaining Future Work

- Run #4B: approved reversible lab action planning.
- Run #4C: live reversible lab disable in a lab-only tenant.
- Final delete remains prohibited and requires a separate explicit approval process.
