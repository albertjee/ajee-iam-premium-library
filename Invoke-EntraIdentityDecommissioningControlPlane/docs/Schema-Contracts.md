# Schema Contracts

**SchemaVersion:** 3.3  
**Rev:** 3.3

---

## Overview

All output objects produced by the Entra Identity Decommissioning Control Plane conform to versioned schema contracts. Each contract defines required fields, field types, and allowed values. Contracts are enforced at runtime via `Test-DecomObjectAgainstSchemaContract` in `SchemaContracts.psm1`.

---

## Finding Schema

**Required fields:** FindingId, Category, Severity, RiskScore, Confidence, ObjectType, ObjectId, DisplayName, UserPrincipalName, Evidence, EvidenceSource, GraphEndpoint, RecommendedAction, RemediationMode, ConsultantNote

| Field | Type | Allowed Values |
|---|---|---|
| FindingId | string | See Findings-Catalog.md |
| Category | string | — |
| Severity | string | Critical, High, Medium, Low, Informational |
| RiskScore | int | 0–100 |
| Confidence | double | 0.0–1.0 |
| ObjectType | string | User, Group, Application, ServicePrincipal, DirectoryRole, ConditionalAccessPolicy |
| ObjectId | string | — |
| DisplayName | string | — |
| UserPrincipalName | string | — |
| Evidence | string | — |
| EvidenceSource | string | — |
| GraphEndpoint | string | — |
| RecommendedAction | string | — |
| RemediationMode | string | ManualApprovalRequired, AutoRemediable, InformationOnly, ProtectedObject |
| ConsultantNote | string | — |

---

## RunManifest Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, ClientName, Assessor, RunId, Mode, DemoMode, Summary, ExportPaths

---

## ApprovalManifest Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, ClientName, RunId, ApprovedBy, ExpiresUtc, ApprovedActions

---

## ExecutionLog Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, RunId, Log

---

## ExecutionEvidence Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, Actions, Summary

---

## BaselineComparison Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, ComparisonResults, BaselineInfo

---

## ExecutiveSummary Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, ClientName, Assessor, Coverage, Findings, Summary, BaselineComparison, RiskMovement

---

## ClientReadoutPackManifest Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, ClientName, Assessor, Items

---

## CatalogValidationReport Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, ClientName, Assessor, Passed, UnknownFindingIds, SeverityMismatches, RiskScoreMismatches, RiskScoreBandViolations, MissingRequiredFields, InvalidRemediationModes

---

## WriteReadinessReport Schema

**Required fields:** SchemaVersion, ToolVersion, GeneratedUtc, EngagementId, ClientName, Assessor, ExecutionScopeRegistry, Rev3Candidates, Recommendation

---

## Rev3.2 Governance Pack Schemas

### ApplicationGovernanceModel

**Required fields:** SchemaVersion, ToolVersion, EngagementId, ClientName, TotalFindings, UnownedApplicationCount, DisabledOwnerApplicationCount, SingleOwnerApplicationCount, SpnNoOwnerCount, ProtectedObjectCount, Applications, Exclusions

### CaExclusionGovernanceModel

**Required fields:** SchemaVersion, ToolVersion, EngagementId, ClientName, TenantId, ExclusionCount, HighRiskExclusionCount, ExclusionsLackingReviewEvidenceCount, ConflictingEvidenceCount, ManualRemediationCount, Rev33WriteCandidateCount, CaPolicies, Exclusions, ExceptionRegister, RemediationDesign

### CredentialHygieneGovernanceModel

**Required fields:** SchemaVersion, ToolVersion, EngagementId, ClientName, TotalFindings, ExpiredCredentialCount, ExpiringCredentialCount, PasswordCredentialCount, KeyCredentialCount, ProtectedObjectCount, Applications

### EmergencyAccessGovernanceModel

**Required fields:** SchemaVersion, ToolVersion, EngagementId, ClientName, ProtectedObjectCount, EmergencyAccessAccountCount, WhatIfActionsBlocked, ApprovalActionsBlocked, HygieneGapsPresent, ProtectedObjects, EmergencyAccounts, HygieneGaps

### WhatIfActionPlan (Rev3.2 extension)

`RemoveExpiredApplicationCredential` action fields: ActionType, FindingId, ObjectId, ObjectType, CredentialKeyId, CredentialType, CredentialEndDateTime, CredentialExpired, TargetObjectIds, RequiresManualApproval, RollbackGuidance, ReadinessStatus

---

## Rev4.2-S1 Controlled NHI Decommission Schemas

Rev4.2-S1 schema objects are local planning and evidence contracts. They do not authorize Graph
writes or live deletion. `FinalDeleteLiveEnabled` must remain `false`.

### Controlled Decommission Plan

**Required input fields:** SchemaVersion, RunId, TargetId, TargetType

**Required generated fields:** SchemaVersion, RunId, GeneratedUtc, TargetId, TargetType,
ExecutionStage, WhatIf, DemoMode, PlanningOnly, LiveMutationEnabled, FinalDeleteLiveEnabled,
Status, Actions

Allowed target types are `ServicePrincipal`, `Application`, and `ManagedIdentity`.
Allowed execution stages are `ValidateOnly`, `SnapshotOnly`, `TagOnly`, `DisableOnly`,
`ScreamTestOnly`, `DeleteReadinessOnly`, and `FinalDelete`. In Rev4.2-S1, every stage is planning
only and `FinalDelete` is always blocked.

### Controlled Decommission Approval

**Required fields:** SchemaVersion, RunId, Status, ApprovedBy, ExpiresUtc, TargetObjectIds,
ApprovedActions

Approval validation requires schema version `4.2`, an approved and unexpired manifest, an exact
target match, and authorization for the requested planning action. Approval does not enable live
mutation or `FinalDelete`.

### Controlled Evidence

The planner exports five local JSON evidence objects:

| Evidence | Purpose |
|---|---|
| Plan | Records the requested planning stage and blocked/live-mutation state |
| Sanitized snapshot | Preserves non-sensitive target state and SHA-256 integrity hash |
| Scream-test evaluation | Records time-window, dependency, activity, and query status |
| Delete-readiness evaluation | Fails closed unless all readiness gates pass |
| Rollback plan | Links reversible planning guidance to the sanitized snapshot hash |

Snapshots retain credential metadata only. Secret values, tokens, and certificate material must
not be exported.

Sample contracts:

- `samples/nhi-controlled-decommission-plan.sample.json`
- `samples/nhi-controlled-decommission-approval.sample.json`

---

## Schema Validation

To validate any object against a contract programmatically:

```powershell
Import-Module .\src\Modules\SchemaContracts.psm1 -Force
$contract = Get-DecomSchemaContract -ObjectType 'Finding'
$result = Test-DecomObjectAgainstSchemaContract -Object $findingObject -Contract $contract
if (-not $result.Passed) {
    $result.MissingFields   # Fields absent from the object
    $result.TypeMismatches  # Fields with wrong types
    $result.InvalidValues   # Fields with disallowed values
}
```

---

© 2026 Albert Jee. All rights reserved.
