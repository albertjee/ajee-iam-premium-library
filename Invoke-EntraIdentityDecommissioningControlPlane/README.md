# Entra Identity Decommissioning Control Plane

> **Consultant-grade identity governance tooling for Microsoft Entra ID.**
> Assessment-first design. No tenant modifications without explicit approval.

---

## Overview

Two tools in one repo:

| Tool | Entry Point | Purpose |
|---|---|---|
| **Assessment Control Plane** | `Invoke-EntraIdentityDecommissioningControlPlane.ps1` | Discovery, scoring, and remediation planning — read-only |
| **Decommissioning Execution Engine** | `src/Start-Decom.ps1` / `src/Start-DecomBatch.ps1` | Controlled batch identity remediation — requires approval gate |

The Assessment Control Plane (Rev1.4) is the recommended starting point for any engagement.
It produces an executive HTML report, CSV findings export, and approval-ready remediation plan
before any execution is considered.

---

## Rev4.2-S1 Controlled NHI Decommission Planning

Rev4.2-S1 adds an additive, local-only controlled NHI decommission planner and evidence workflow.
It supports `WhatIf` and `DemoMode` planning only. It does not connect to Microsoft Graph, request
new Graph write scopes, or mutate tenant objects.

The entry-point `ToolVersion` is `Rev4.10`. Rev4.10 traceability is provided by its schema version,
branch, commit, documentation, module, samples, and focused tests.

Safety boundary:

- Live `FinalDelete` is blocked in Rev4.2-S1.
- `Remove-MgServicePrincipal` and `Remove-MgApplication` are not implemented or invoked.
- Assessment, default, SelfTest, DemoMode, and WhatIf paths remain write-free.
- A valid Rev4.2 plan and approval manifest are required; missing or invalid inputs fail closed.
- The workflow produces five local JSON evidence files: plan, sanitized snapshot, scream-test
  evaluation, delete-readiness evaluation, and rollback plan.
- Scream-test and readiness evidence is illustrative/generated planner evidence, not live monitoring
  evidence. Runtime recomputes generated evidence and does not trust rich sample fields as authority.
- If both `-ExecuteNhiControlledDecommission` and `-ExecuteNhiDecommission` are supplied, the
  Rev4.2-S1 controlled path runs first and exits before legacy Rev4.0 execution.

Sample planner command:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -ExecuteNhiControlledDecommission `
    -ExecutionStage DeleteReadinessOnly `
    -DecommissionPlanPath '.\samples\nhi-controlled-decommission-plan.sample.json' `
    -ApprovalManifestPath '.\samples\nhi-controlled-decommission-approval.sample.json' `
    -WhatIfExecution `
    -OutputPath '.\out'
```

Sample inputs:

- `samples/nhi-controlled-decommission-plan.sample.json`
- `samples/nhi-controlled-decommission-approval.sample.json`

See `runbooks/NHI-Controlled-Decommission-Runbook.md` for the full S1 operator workflow.

### Rev4.3 Service Principal FinalDelete Guard

Rev4.3 adds a Service Principal-only FinalDelete gate simulation and evidence artifact. It evaluates
stage, explicit allow switch, exact approval, snapshot, delete-readiness, scream-test or override,
dependency recheck, protected-target checks, and test-tenant metadata.

Even when every gate passes, Rev4.3 reports `GuardSatisfiedSimulationOnly`,
`LiveDeleteExecutable = false`, and `DeleteCmdletAvailable = false`. No
`Remove-MgServicePrincipal` cmdlet, Graph write, or unattended live-delete path is included.

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

---

### Rev4.7 Managed Identity Readiness

Rev4.7 adds managed identity readiness and simulation-only evidence. `SystemAssigned` identities require
parent resource evidence; `UserAssigned` identities require attachment evidence. No live Managed Identity
deletion, Azure Resource Manager deletion, or role-assignment cleanup path is included.

### Rev4.8 End-to-End Evidence Pack

Rev4.8 adds the end-to-end evidence pack and QA handoff manifest. It summarizes the local simulation-only
state across the controlled planner and readiness artifacts. It does not authorize live deletion or cleanup.

### Rev4.9 Production Readiness Guardrails

Rev4.9 adds the final pre-merge production-readiness gate, merge-gate manifest, known-warning inventory,
and final safety assertions. It records branch/commit cleanliness, external QA evidence, full Pester
evidence, safety-scan evidence, and frozen-file diff evidence. It does not enable production execution,
live delete, live cleanup, or any tenant mutation path.

Sample input:

- `samples/nhi-controlled-production-readiness.sample.json`

## Rev4.9 / Rev4.10 Session Summary — Platform Identity Classification and Client-Actionable Remediation Suppression

### 1. Purpose

Rev4.9 and Rev4.10 hardened the assessment and planning pipeline so Microsoft-owned platform identities and known external vendor platform identities are not incorrectly presented as customer-actionable decommissioning or remediation work.

The live examples that drove this work were:

- Microsoft Graph PowerShell
- Microsoft Tech Community
- Flipgrid
- iOS Accounts

Microsoft Graph PowerShell, Microsoft Tech Community, and Flipgrid are treated as `MicrosoftPlatform` when catalog and live metadata support that classification. iOS Accounts is treated as `ExternalVendorPlatform`, not `MicrosoftPlatform`. External vendor platform identities are also suppressed from customer-actionable remediation when catalog or metadata marks them as platform-owned.

### 2. Important schema/output changes

The following fields are now present on findings and/or trace output and are important for QA and defensibility:

- `Classification`
- `FirstPartyMicrosoftApp`
- `MicrosoftPlatform`
- `SuppressCustomerRemediation`
- `RemediationMode`
- `EvidenceOnly`
- `ClassificationSource`
- `ClassificationSignals`
- `MicrosoftPlatformReason`
- `NormalizedAppId`
- `NormalizedPublisherName`
- `NormalizedVerifiedPublisherName`
- `NormalizedAppOwnerOrganizationId`
- `NormalizedServicePrincipalType`
- `NormalizedTags`

These fields matter because they make classification explainable, prevent hidden suppression logic, and let QA verify whether a finding is customer-actionable, information-only, or evidence-only. They also support consultant-ready reporting and client defensibility when live platform identities are encountered.

### 3. Platform identity catalog

Known platform identities are now stored in:

- `config/platform-identity-catalog.json`

The catalog is used to identify platform identities using stable metadata such as:

- `AppId`
- `AppOwnerOrganizationId`
- `VerifiedPublisherName`
- `DisplayName`
- `Platform classification`
- `Suppression behavior`

Catalog-driven classification is preferred over fragile display-name-only matching.

Known live entries:

- Microsoft Graph PowerShell
  - AppId: `14d82eec-204b-4c2f-b7e8-296a70dab67e`
  - AppOwnerOrganizationId: `72f988bf-86f1-41af-91ab-2d7cd011db47`
  - Classification: `MicrosoftPlatform`
- Microsoft Tech Community
  - AppId: `09213cdc-9f30-4e82-aa6f-9b6e8d82dab3`
  - AppOwnerOrganizationId: `cdc5aeea-15c5-4db6-b079-fcadd2505dc2`
  - Classification: `MicrosoftPlatform`
- Flipgrid
  - AppId: `f1143447-b07a-4557-b878-b78df8d45c13`
  - AppOwnerOrganizationId: `1bf12738-0df6-4c07-97c3-0b0642a2f1a0`
  - Classification: `MicrosoftPlatform`
- iOS Accounts
  - AppId: `f8d98a96-0999-43f5-8af3-69971c7bb423`
  - AppOwnerOrganizationId: `e0fad04c-a04c-41ab-b35e-dc523af755a1`
  - VerifiedPublisherName: `Apple Inc.`
  - Classification: `ExternalVendorPlatform`
  - `MicrosoftPlatform = false`
  - `FirstPartyMicrosoftApp = false`
  - `SuppressCustomerRemediation = true`

### 4. Remediation behavior change

Suppressed platform identities must not appear in customer-actionable `ACT-*` remediation sections.

Suppressed findings include any finding where one or more of these are true:

- `SuppressCustomerRemediation = true`
- `Classification = MicrosoftPlatform`
- `Classification = ExternalVendorPlatform`
- `MicrosoftPlatform = true`
- `RemediationMode = InformationOnly`
- `RemediationMode = EvidenceOnly`
- `EvidenceOnly = true`

Expected behavior:

- Platform identities may remain visible as evidence-only or information-only appendix rows.
- They must not produce `AddApplicationOwner`, `Assign owner`, `Verify publisher`, `Revoke consent`, `Reduce permission scope`, `ManualApprovalRequired`, or executable approval actions.
- Customer-owned, lab, and third-party identities remain actionable when appropriate.

### 5. Validation performed

Before commit `835e8dd`, the following validation passed:

- `Reporting.Tests.ps1` passed
- Focused Rev4.10 slice passed
- Platform identity catalog tests passed
- `SuppressCustomerRemediation` regression tests passed
- Full safety subset passed: 304 passed, 0 failed
- Live read-only tenant validation passed
- Live findings JSON check passed
- Live remediation-plan leak check passed
- No tenant write/delete/cleanup execution flags were used

Live read-only safety note:

The validation run did not use:

- `-ExecuteNhiDecommission`
- `-ExecuteNhiControlledDecommission`
- `-ExecuteNhiControlledGrantCleanup`
- `-ExecuteNhiControlledMetadataCleanup`
- `-AllowFinalDelete`
- rollback execution
- final delete

### 6. QA commands for future verification

Run the full safety subset:

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

Run focused validation:

```powershell
Invoke-Pester -Path '.\tests\Reporting.Tests.ps1'
Invoke-Pester -Path '.\tests\PlatformIdentityCatalog.Rev410.Tests.ps1'
Invoke-Pester -Path '.\tests\Rev410.MicrosoftPlatform.Tests.ps1'
Invoke-Pester -Path '.\tests\SuppressCustomerRemediation.Rev410.Tests.ps1'
```

Live read-only validation template:

```powershell
# Read-only only: do not add execution flags.
Invoke-EntraIdentityDecommissioningControlPlane.ps1 -WhatIfMode -OutputPath '.\out'
```

### 7. Final expected live output

For Microsoft Graph PowerShell, Microsoft Tech Community, and Flipgrid:

- `Classification = MicrosoftPlatform`
- `FirstPartyMicrosoftApp = true`
- `MicrosoftPlatform = true`
- `SuppressCustomerRemediation = true`
- `RemediationMode = InformationOnly` or `EvidenceOnly`
- No actionable `ACT-*` remediation section

For iOS Accounts:

- `Classification = ExternalVendorPlatform`
- `FirstPartyMicrosoftApp = false`
- `MicrosoftPlatform = false`
- `SuppressCustomerRemediation = true`
- `RemediationMode = InformationOnly` or `EvidenceOnly`
- No actionable `ACT-*` remediation section

### 8. Maintenance guidance

- Add new known platform identities to `config/platform-identity-catalog.json`, not by hard-coded display-name-only matching.
- Treat Microsoft-looking names as suspicious unless metadata confirms Microsoft ownership.
- Treat external vendor platform apps separately from Microsoft platform apps.
- Never suppress unknown customer-created apps merely because their display name looks official.
- When adding a catalog entry, add or update Pester tests.
- Always confirm the remediation plan does not leak customer-actionable guidance for suppressed platform identities.

For a consultant-oriented parameter and operating-mode reference, see [Runbook - Parameters, Operating Modes, and Consultant Usage](docs/RUNBOOK-PARAMETERS-AND-OPERATING-MODES.md).

## Assessment Control Plane (Rev1.4)

### What it does

Connects to Microsoft Entra ID in read-only mode and detects residual access risk across:

| Category | Finding IDs | What it detects |
|---|---|---|
| User Lifecycle | DEC-USER-001, 002, 003 | Disabled users with group memberships, app roles, privileged roles |
| Application | DEC-APP-001 through 005 | Ownerless apps, disabled-user owners, expiring/expired credentials, single owners |
| Service Principal | DEC-SPN-001 | Ownerless enterprise applications |
| Guest Lifecycle | DEC-GUEST-001, 002, 003 | Stale guests, privileged guests, guests without sponsor metadata |
| Privileged Access | DEC-ROLE-001 | Disabled identities holding active privileged roles |
| Conditional Access | DEC-CA-001, DEC-CA-002 | CA policy exclusions requiring review |
| Governance | DEC-IGA-001 | Coverage gaps when optional scopes are unavailable |

### Quick start

**Demo mode (no Graph connection required):**
```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode
```

**Live assessment against your tenant:**
```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -TenantId     "contoso.onmicrosoft.com" `
    -EngagementId "ENG-001" `
    -ClientName   "Contoso" `
    -Assessor     "Your Name" `
    -OutputPath   ".\out"
```

### Run modes

| Mode | Description |
|---|---|
| `Assessment` (default) | Read-only discovery and scoring. No tenant modifications. |
| `WhatIfRemediation` | Assessment + remediation plan. No tenant modifications. |
| `ExportPlan` | Export remediation plan only. No tenant modifications. |
| `ExecuteRemediation` | Reserved — blocked in Rev1.x. Available in Rev2.0. |

### Outputs

Each run creates a timestamped folder under `.\out\` containing:

| File | Description |
|---|---|
| `*-assessment-*.csv` | All findings in spreadsheet format |
| `*-findings-*.json` | Machine-readable findings with full schema |
| `*-report-*.html` | Executive HTML report — dark theme, filterable findings table |
| `*-remediation-plan-*.md` | Approval-ready Markdown remediation plan |
| `*-run-manifest-*.json` | Run audit record with coverage and finding summary |

### Required permissions

| Permission | Purpose |
|---|---|
| `User.Read.All` | User lifecycle and guest discovery |
| `Directory.Read.All` | Groups, roles, directory relationships |
| `Application.Read.All` | App registrations, owners, credentials |
| `AuditLog.Read.All` | Sign-in activity for stale identity detection |
| `RoleManagement.Read.Directory` | Privileged role assignments |
| `Policy.Read.All` | Conditional Access policy analysis |
| `EntitlementManagement.Read.All` | IGA coverage (optional — P3 license required) |

### Finding severity model

| Severity | RiskScore range | Example |
|---|---|---|
| Critical | 80–100 | Disabled user holds Global Administrator |
| High | 60–79 | App owned exclusively by disabled user |
| Medium | 40–59 | App with single owner |
| Low | 25–39 | Stale guest last sign-in 210 days ago |
| Informational | 0–24 | Coverage gap — optional scope unavailable |

### Test suite

```powershell
Invoke-Pester -Path .\tests\Rev11\ -Output Detailed
# 282/282 tests passing, 0 failures
```

---

## Rev3.4 — Production Hardening

Rev3.4 turns the tool from a powerful engineering asset into a consultant-deliverable product:

- **Output manifest** — machine-readable index of every generated file with SHA-256 hashes and sensitivity classification
- **Evidence bundle** — reproducible package of assessment, WhatIf, approval, execution, and hash manifests
- **Redaction profiles** — client-safe sanitized copies (ClientSafe, PublicDemo, Strict, Internal)
- **Replay validation** — validate WhatIf→Approval→Execution chain integrity without a Graph connection
- **Approval diff** — compare WhatIf plan vs approval manifest to surface changes, rejections, target changes
- **Traceability report** — end-to-end audit trail from Finding to WhatIf to Approval to Execution Evidence
- **Client handoff package** — consultant-ready deliverable with checklist, index, and manifest
- **Operator runbook pack** — execution, failure recovery, client handoff, redaction review, replay validation
- **Rev3.5 NHI readiness** — extension points for upcoming NHI / agentic identity audit expansion

Rev3.4 adds no new write scopes, no new remediation action types, and no NHI detectors.

---

## Rev2.5 — SelfTest and Release Package

### SelfTest Mode

Run the built-in release validation without connecting to Graph:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -SelfTest
```

Validates:
- Tool version consistency (`ToolVersion = Rev4.10` in entry point)
- No write verbs or write scopes in read-only modules
- Remediation.psm1 contains only Rev2.0 executable actions

Exit code 0 on pass, 1 on failure. Produces `release-validation-report-*.json` and `release-validation-report-*.md` in the output directory.

### Generate Release Package

Bundle documentation, runbooks, and validation reports for client delivery:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -SelfTest `
    -GenerateReleasePackage `
    -ReleasePackagePath '.\release\Rev2.5'
```

Package structure:
```
release\Rev2.5\
  docs\               Required-Permissions.md, Findings-Catalog.md
  runbooks\           Six operational runbooks
  validation\         Release validation, catalog validation, schema validation reports
  sample-outputs\     Demo outputs (generated separately by DemoMode)
  release-package-manifest.json
```

### Rev3.0 Write-Readiness

Rev2.5 includes a formal Rev3.0 write-readiness gate:

```powershell
Import-Module .\src\Modules\WriteReadiness.psm1 -Force
$report = New-DecomRev3WriteReadinessReport -Context $ctx
```

Current recommendation: **ReadyForRev3Design** — the safety architecture is mature enough to begin designing write expansion. This is a design gate only, not implementation approval.

See `runbooks\Rev3-Write-Readiness-Runbook.md` for interpretation guidance.

---

## Decommissioning Execution Engine (Premium v2.0)

### What it does

Controlled batch execution of identity decommissioning workflows. Requires an approved
remediation plan and an active Entra ID connection with write permissions.

```powershell
# New batch run
.\src\Start-DecomBatch.ps1 `
    -UpnList  alice@contoso.com, bob@contoso.com `
    -TicketId CHG-12345 `
    -WhatIfMode

# Resume interrupted batch
.\src\Start-DecomBatch.ps1 `
    -ResumePath 'C:\output\<BatchId>\batch-state.json'
```

Key capabilities: batch envelope, per-UPN lifecycle tracking, checkpoint/resume,
pre-flight approval gate, diff report, policy overlays, litigation hold,
license removal, device remediation, app ownership removal, Azure RBAC removal.

See [Execution Engine README](src/README.md) for full documentation.

---

## Repository layout

```
Invoke-EntraIdentityDecommissioningControlPlane.ps1   <- Assessment entry point (Rev1.4)
src/
  Start-Decom.ps1                 <- Lite single-UPN decommissioning launcher
  Start-DecomBatch.ps1            <- Premium batch decommissioning launcher
  Invoke-DecomWorkflow.ps1        <- Core workflow engine
  LiteModules/                    <- 14 Lite decommissioning modules
  Modules/
    Utilities.psm1                <- Assessment console helpers + finding factory
    Discovery.psm1                <- Assessment discovery engine (Rev1.4)
    Analysis.psm1                 <- Assessment scoring engine
    Reporting.psm1                <- Assessment HTML + export functions
    RemediationPlan.psm1          <- Assessment remediation plan generator
    AccessRemoval.psm1            <- Premium: group/role/OAuth removal
    AppOwnership.psm1             <- Premium: app ownership removal
    AzureRBAC.psm1                <- Premium: Azure RBAC removal
    BatchApproval.psm1            <- Premium: pre-flight approval gate
    BatchContext.psm1             <- Premium: batch envelope management
    BatchDiff.psm1                <- Premium: pre-run diff report
    BatchOrchestrator.psm1        <- Premium: sequential batch orchestrator
    BatchOrchestratorParallel.psm1<- Premium: parallel orchestrator (reserved)
    BatchPolicy.psm1              <- Premium: per-UPN policy overlays
    BatchReporting.psm1           <- Premium: HTML/JSON batch reports
    BatchState.psm1               <- Premium: checkpoint save/restore
    ComplianceRemediation.psm1    <- Premium: litigation hold
    DeviceRemediation.psm1        <- Premium: device disable/wipe/retire
    LicenseRemediation.psm1       <- Premium: license removal
    MailboxExtended.psm1          <- Premium: mail forwarding control
tests/
  Rev11/
    Safety.Tests.ps1              <- Assessment safety tests
    Analysis.Tests.ps1            <- Assessment scoring tests
    Reporting.Tests.ps1           <- Assessment export tests
  Decom.Tests.ps1                 <- Lite suite (41 tests)
  Premium/                        <- Premium batch suite (191 tests)
docs/
  Consultant-Runbook.md           <- Engagement runbook
  Required-Permissions.md         <- Graph permission reference
  Findings-Catalog.md             <- All finding IDs with severity and description
samples/
  sample-findings.csv
  sample-findings.json
  sample-report.html
  sample-remediation-plan.md
out/                              <- Local run outputs (gitignored)
```

---

## Engagement workflow

```
1. Run assessment (DemoMode first, then live)
2. Review HTML report with client
3. Agree on remediation scope
4. Export remediation plan (WhatIfRemediation mode)
5. Obtain approval (sign remediation plan)
6. Execute controlled remediation (Rev2.0 — coming)
```

---

## Safety model

- Assessment mode is **read-only by design** — no Graph write permissions requested
- `ExecuteRemediation` is blocked in all Rev1.x releases — reserved for Rev2.0
- All findings include `RemediationMode` field:
  - `ManualApprovalRequired` — requires human sign-off before action
  - `AutoRemediable` — safe for scripted execution with approval
  - `ProtectedObject` — never auto-remediate (break-glass, sync, service accounts)
  - `InformationOnly` — no action required
- Protected object patterns: `breakglass`, `break-glass`, `emergency`, `sync`, `aadconnect`, `cloudsync`, `svc-`, `service-`

---

## Version history

| Version | Description |
|---|---|
| Rev1.4 | Guest lifecycle, privileged access residue, CA exclusion analysis — 42 tests |
| Rev1.3 | Application ownership drift, credential expiry, service principal owners — 35 tests |
| Rev1.2 | Evidence model hardening, null safety, protected object enforcement — 28 tests |
| Rev1.1 | Assessment-first entry point, demo mode, HTML report, safety model — 20 tests |
| Premium v2.0 | Batch decommissioning engine, approval gate, resume, premium remediation |

---

## Requirements

- PowerShell 5.1 or later
- Microsoft.Graph PowerShell SDK (`Install-Module Microsoft.Graph`)
- Pester v5.x for test suite (`Install-Module Pester -MinimumVersion 5.0`)
- Read-only Graph permissions (see Required Permissions above)
