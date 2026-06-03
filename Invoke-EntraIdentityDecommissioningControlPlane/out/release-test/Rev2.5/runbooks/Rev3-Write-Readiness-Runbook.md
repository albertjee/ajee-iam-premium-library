# Rev3.0 Write-Readiness Runbook

**Tool:** Entra Identity Decommissioning Control Plane  
**SchemaVersion:** 2.5  
**Rev:** 2.5

---

## Important: Design Gate Only

**The write-readiness report is a design gate, not an implementation approval.**

`Recommendation: ReadyForRev3Design` means the tool's safety architecture is mature enough to begin designing Rev3.0 write expansion. It does NOT mean:

- Any new write actions are approved for implementation
- Any new Graph write scopes are authorized
- Any new remediation types have been reviewed for correctness and safety

Implementation of new write actions requires a separate Rev3.0 design review, security sign-off, and a new approval gate before code is written.

---

## Generating the Write-Readiness Report

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith' `
    -SelfTest `
    -GenerateReleasePackage `
    -ReleasePackagePath '.\release\Rev2.5'
```

The write-readiness report is included in the release package.

Or run WriteReadiness directly:

```powershell
Import-Module .\src\Modules\WriteReadiness.psm1 -Force
$ctx = [PSCustomObject]@{ ToolVersion='Rev2.5'; OutputPath='.\output'; ClientName='Client'; EngagementId='ENG-001'; Assessor='Assessor' }
$report = New-DecomRev3WriteReadinessReport -Context $ctx
Export-DecomRev3WriteReadinessJson -Report $report -Context $ctx
Export-DecomRev3WriteReadinessMarkdown -Report $report -Context $ctx
```

## Reading the Report

The report contains three sections:

### ExecutionScopeRegistry

The four Rev2.0 actions currently executable by this tool. All are `Status=Executable` and `IntroducedIn=Rev2.0`. These are the only write operations currently authorized.

### Rev3Candidates

Proposed write actions for Rev3.0 design consideration. Each entry has:

| Field | Meaning |
|---|---|
| `CandidateStatus` | `NeedsDesign`, `Deferred`, or `Unsafe` |
| `ProposedWriteScope` | Graph scope that would be required |
| `RiskLevel` | Risk assessment for this action type |
| `RequiredApprovalEvidence` | What approvals are needed before implementation |
| `RequiredRollbackDesign` | Rollback capability that must be designed |
| `RecommendedRev` | Earliest rev this could be implemented in |

### Recommendation

| Value | Meaning |
|---|---|
| `ReadyForRev3Design` | Architecture is stable. Design phase may begin. No implementation authorized. |
| `NotReadyForRev3` | Safety concerns must be resolved before design begins. |

`ReadyForRev3Implementation` does not exist as a recommendation value — implementation readiness is a separate gate outside this tool.

## Rev3 Candidate Status Definitions

| Status | Meaning |
|---|---|
| `NeedsDesign` | Technically feasible, requires full design with rollback |
| `Deferred` | Feasible but deferred pending architectural decision |
| `Unsafe` | Not safe to implement without additional safety research |

`Unsafe` candidates (`DEC-APP-001`, `DEC-SPN-001`) are flagged because app/service principal deletion is irreversible and requires out-of-band verification that no dependent services exist. These will remain `Unsafe` until a pre-flight verification framework is designed.

---

© 2026 Albert Jee. All rights reserved.
