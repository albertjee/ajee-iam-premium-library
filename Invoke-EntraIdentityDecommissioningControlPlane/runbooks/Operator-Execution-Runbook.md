# Operator Execution Runbook
## Entra Identity Decommissioning Control Plane — Rev3.4

**Audience:** Identity governance consultants and IAM operators  
**Purpose:** End-to-end guide for running the tool in production  
**Tool:** `Invoke-EntraIdentityDecommissioningControlPlane.ps1`

---

## Prerequisites

### Software Requirements

| Requirement | Minimum Version | Notes |
|---|---|---|
| PowerShell | 5.1 | Windows PowerShell or PowerShell 7+ |
| Microsoft Graph PowerShell SDK | 2.x | `Install-Module Microsoft.Graph` |
| Pester | 5.x | For SelfTest verification |

### Install Microsoft Graph SDK

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Force
```

### Verify Installation

```powershell
Get-Module Microsoft.Graph -ListAvailable | Select-Object Name, Version
```

### Required Permissions

**Assessment / WhatIfRemediation / ExportPlan modes (read-only):**
- `User.Read.All`
- `Directory.Read.All`
- `Application.Read.All`
- `AuditLog.Read.All`
- `RoleManagement.Read.Directory`
- `EntitlementManagement.Read.All`
- `AccessReview.Read.All`
- `Policy.Read.All`

**ExecuteRemediation mode (adds write scopes):**
- All read scopes above, plus:
- `GroupMember.ReadWrite.All`
- `AppRoleAssignment.ReadWrite.All`
- `RoleManagement.ReadWrite.Directory`
- `EntitlementManagement.ReadWrite.All`
- `Application.ReadWrite.All`

The tool connects to Microsoft Graph automatically using the appropriate scope set for each mode. The operator is prompted to authenticate unless running non-interactively with a pre-authenticated context.

### Engagement Parameters

Before running, gather the following values:

| Parameter | Description | Example |
|---|---|---|
| `-TenantId` | Azure AD tenant ID (GUID or domain) | `contoso.onmicrosoft.com` |
| `-EngagementId` | Unique identifier for this engagement | `ENG-2026-001` |
| `-ClientName` | Client organization name | `Contoso Ltd` |
| `-Assessor` | Consultant name or ID | `Albert Jee` |
| `-OutputPath` | Folder for all run outputs | `.\out` |

---

## Step 1: SelfTest Verification

Run SelfTest before any live tenant work to confirm the tool loads cleanly and all modules pass validation.

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -SelfTest
```

**Expected output:**

```
[OK]  SelfTest PASSED
```

If SelfTest fails, stop. Read the error messages — they will identify which module failed version consistency or safety checks. Do not proceed to a live tenant until SelfTest passes.

### SelfTest with Release Package

To generate the release package artifact at the same time:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -SelfTest -GenerateReleasePackage
```

---

## Step 2: Assessment Mode

Assessment mode performs discovery and analysis against the live tenant. No tenant modifications are made.

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out"
```

**With executive pack and Rev3.4 hardening outputs:**

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -GenerateExecutivePack `
    -GenerateEvidenceBundle `
    -GenerateTraceabilityReport `
    -GenerateClientHandoff `
    -GenerateRev35Readiness
```

**Expected output:**

```
[OK]  CSV exported
[OK]  JSON exported
[OK]  HTML report generated
[OK]  Remediation plan generated
[OK]  Run manifest written
  Assessment complete.
  CRITICAL : 3
  HIGH     : 7
  MEDIUM   : 12
  LOW      : 4
  INFO     : 2
  Output folder : .\out\20260602_143000
```

---

## Step 3: WhatIfRemediation Mode

WhatIfRemediation mode simulates what remediation actions would be taken, without making any changes. It produces a WhatIf action plan for client review and approval.

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode WhatIfRemediation `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -GenerateApprovalTemplate
```

The `-GenerateApprovalTemplate` flag generates the WhatIf action plan JSON file. This file is the input to the approval workflow. Record the `RunId` from the run manifest — it will be needed for Gate A validation during execution.

---

## Step 4: The Three-Gate ExecuteRemediation Model

ExecuteRemediation requires three sequential validation gates to pass before any write operation reaches the tenant. Each gate is automated — no manual hash computation is needed.

### Gate A — WhatIf Manifest Validation

Gate A verifies that:
- The WhatIf manifest file exists and is readable
- The `EngagementId` in the manifest matches the `-EngagementId` parameter passed at execution time
- The manifest contains a valid `RunId`

If Gate A fails, execution halts immediately with a specific error message. No Graph connection is established.

### Gate B — Approval Manifest Validation

Gate B verifies that:
- The approval manifest exists and is readable
- The `ApprovalEnvelopeHash` in the approval manifest matches the hash computed from the WhatIf action plan at signing time
- The approval has not expired (`ExpiresUtc` is in the future)
- The `WhatIfRunId` in the approval manifest matches the `RunId` from Gate A
- No protected objects appear in the approved action list

If Gate B fails, execution halts. The approval manifest must be regenerated and re-signed.

### Gate C — Execution Preflight

After Gates A and B pass, and before connecting to Graph with write scopes, the tool displays the Execution Preflight Summary:

- Engagement ID, Client, WhatIf Run ID
- Approved By, Approval Expiry
- Action type breakdown (count by ActionType)
- Affected users, groups, assignments

The operator must confirm (`y` or `EXECUTE`) before Graph write connection is established. Pass `-NonInteractive` to skip the confirmation prompt in automated pipelines.

---

## Step 5: ExecuteRemediation Mode

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode ExecuteRemediation `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -WhatIfManifestPath ".\out\20260602_143000\entra-decommissioning-control-plane-run-manifest-20260602_143000.json" `
    -ApprovalManifestPath ".\approvals\ENG-2026-001-approval.json" `
    -MaxActions 25
```

**With Rev3.4 hardening outputs after execution:**

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode ExecuteRemediation `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -WhatIfManifestPath ".\out\20260602_143000\entra-decommissioning-control-plane-run-manifest-20260602_143000.json" `
    -ApprovalManifestPath ".\approvals\ENG-2026-001-approval.json" `
    -MaxActions 25 `
    -GenerateEvidenceBundle `
    -GenerateReplayValidation `
    -GenerateApprovalDiff `
    -GenerateTraceabilityReport `
    -GenerateClientHandoff `
    -GenerateRedactedPackage `
    -RedactionProfile ClientSafe
```

**Non-interactive execution (CI/CD or scripted):**

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode ExecuteRemediation `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -WhatIfManifestPath ".\out\20260602_143000\entra-decommissioning-control-plane-run-manifest-20260602_143000.json" `
    -ApprovalManifestPath ".\approvals\ENG-2026-001-approval.json" `
    -NonInteractive
```

---

## Rev3.4 Hardening Flags Reference

All flags default to `$false` (off) for backward compatibility. They can be combined freely in Assessment or ExecuteRemediation modes.

| Flag | Description | Output File Pattern |
|---|---|---|
| `-GenerateEvidenceBundle` | SHA-256 hash manifest of all run outputs | `evidence-bundle\evidence-bundle-manifest-*.json` |
| `-GenerateRedactedPackage` | Redacted copy of outputs using the selected profile | `redaction-report-*.json` |
| `-RedactionProfile` | Profile for redaction: `ClientSafe`, `PublicDemo`, `Strict`, `Internal` | (controls redaction behavior) |
| `-GenerateReplayValidation` | 10-check offline replay validation report | `replay-validation-report-*.json` |
| `-GenerateApprovalDiff` | Diff between WhatIf actions and approved actions | `approval-diff-report-*.json` |
| `-GenerateTraceabilityReport` | Finding-to-action traceability chain | `traceability-report-*.json` and `.csv` |
| `-GenerateClientHandoff` | Client handoff package manifest and index | `client-handoff-manifest-*.json`, `client-handoff-index-*.md` |
| `-GenerateRev35Readiness` | Rev3.5 readiness assessment (NHI/agentic scope) | `rev35-readiness-report-*.json` |

**Demo mode** automatically enables all Rev3.4 hardening flags with synthetic data. Use for training and demonstrations:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode
```

---

## Output Folder Structure

Each run creates a timestamped subfolder under `-OutputPath`:

```
.\out\
  20260602_143000\
    entra-decommissioning-control-plane-assessment-20260602_143000.csv
    entra-decommissioning-control-plane-findings-20260602_143000.json
    entra-decommissioning-control-plane-report-20260602_143000.html
    entra-decommissioning-control-plane-remediation-plan-20260602_143000.md
    entra-decommissioning-control-plane-run-manifest-20260602_143000.json
    entra-decommissioning-control-plane-executive-summary-20260602_143000.md     (if -GenerateExecutivePack)
    entra-decommissioning-control-plane-executive-summary-20260602_143000.html   (if -GenerateExecutivePack)
    traceability-report-20260602_143000.json                                     (if -GenerateTraceabilityReport)
    traceability-report-20260602_143000.csv
    replay-validation-report-20260602_143000.json                                (if -GenerateReplayValidation)
    approval-diff-report-20260602_143000.json                                    (if -GenerateApprovalDiff)
    redaction-report-20260602_143000.json                                        (if -GenerateRedactedPackage)
    client-handoff-manifest-20260602_143000.json                                 (if -GenerateClientHandoff)
    client-handoff-index-20260602_143000.md
    rev35-readiness-report-20260602_143000.json                                  (if -GenerateRev35Readiness)
    output-manifest-20260602_143000.json                                         (aggregated when hardening flags used)
    evidence-bundle\                                                              (if -GenerateEvidenceBundle)
      evidence-bundle-manifest-20260602_143000.json
      evidence-hashes-20260602_143000.json
      evidence-hashes-20260602_143000.csv
```

For ExecuteRemediation runs, the output folder additionally contains:

```
    execution-evidence-20260602_143000.csv
    execution-evidence-20260602_143000.json
    execution-report-20260602_143000.html
    execution-manifest-20260602_143000.json
```

---

## Limiting Actions with -MaxActions and -ActionId

`-MaxActions` (default: 25) is a hard guardrail. If the approved action count exceeds this limit, execution halts with a message showing the exact count to override with.

`-ActionId` allows selective execution of specific approved actions by their ActionId GUID(s):

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode ExecuteRemediation `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -WhatIfManifestPath ".\out\20260602_143000\...-run-manifest-20260602_143000.json" `
    -ApprovalManifestPath ".\approvals\ENG-2026-001-approval.json" `
    -ActionId "a1b2c3d4-0000-0000-0000-000000000001","a1b2c3d4-0000-0000-0000-000000000002"
```

The `-ActionId` filter is applied before the `-MaxActions` check, so filtered subsets can be executed without raising the `-MaxActions` limit.

---

## Execution Outcome Codes

| Outcome | Meaning |
|---|---|
| `Executed` | Action completed successfully; post-write evidence recorded |
| `PartialFailed` | Action attempted; some targets succeeded, some failed |
| `Failed` | Action attempted; all targets failed; ErrorDetail populated |
| `Blocked` | Action blocked by ProtectedObject guardrail; not attempted |
| `OperatorDeclined` | Operator declined at interactive prompt |
| `OutOfScope` | Action skipped — not in the filtered action set |

---

## Baseline Comparison

To compare the current assessment against a prior run:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-002" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -BaselinePath ".\out\20260101_090000\entra-decommissioning-control-plane-findings-20260101_090000.json"
```

Baseline comparison outputs `*-baseline-comparison-*.json` and `*-baseline-comparison-*.csv` in the run folder, and the run manifest is updated with the baseline paths.

---

*Entra Identity Decommissioning Control Plane Rev3.4 — Operator Execution Runbook*
