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

Rich evidence fields in the sample plan are illustrative input examples only. Runtime recomputes
generated snapshot, scream-test, dependency, readiness, rollback, and plan evidence from accepted
plan and approval inputs. Precomputed readiness or evidence fields are not trusted as authority.

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

Rev4.2-S1 scream-test evidence is generated planner evidence only. It is not evidence of live
monitoring, a live Graph query, or completed tenant observation.

Future hardening note: if `ConvertTo-NhiControlledSnapshot` is later supplied raw Graph objects,
sanitization must be expanded and tested for `AdditionalProperties` and unusual secret-like fields
before that input path is enabled.

Sample contracts:

- `samples/nhi-controlled-decommission-plan.sample.json`
- `samples/nhi-controlled-decommission-approval.sample.json`

---

## Rev4.3 Service Principal FinalDelete Guard Evidence

The Rev4.3 gate evaluator produces `nhi-controlled-decommission-finaldelete-sp-guard.json`.

**Required evaluation fields:** SchemaVersion, TargetId, TargetType, ActionType, GatesPassed,
Status, SimulationOnly, LiveDeleteExecutable, DeleteCmdletAvailable, WhatIf, DemoMode, Reasons

`Status` may be `Blocked` or `GuardSatisfiedSimulationOnly`. `SimulationOnly` must be `true`;
`LiveDeleteExecutable` and `DeleteCmdletAvailable` must be `false`.

Test-tenant guard metadata requires `IsTestTenant = true` and `Environment = Test`. This metadata is
necessary for simulation readiness but never enables live deletion.

Sample: `samples/nhi-controlled-finaldelete-sp.sample.json`

---

## Rev4.4 Application Registration Readiness Schemas

Rev4.4 adds application-registration readiness and FinalDelete simulation evidence only. It does not
introduce live deletion or new Graph write permissions.

### Application FinalDelete Readiness Gate

**Required fields:** SchemaVersion, TargetId, TargetType, ActionType, GatesPassed, Status,
SimulationOnly, LiveDeleteExecutable, DeleteCmdletAvailable, WhatIf, DemoMode, Reasons

`Status` may be `Blocked` or `ReadinessSatisfiedSimulationOnly`. `SimulationOnly` must be `true`;
`LiveDeleteExecutable` and `DeleteCmdletAvailable` must be `false`.

### Application Readiness Evidence

The Rev4.4 planner exports local-only evidence artifacts for plan, snapshot, scream-test, delete-readiness,
and application readiness simulation. All generated evidence remains simulation-only and cannot authorize
live deletion.

Sample: `samples/nhi-controlled-finaldelete-application.sample.json`

---

## Rev4.5 Metadata Cleanup Schemas

Rev4.5 adds related metadata inventory and cleanup-readiness evidence only. It does not introduce live
credential removal, owner removal, marker updates, or tenant writes.

### Metadata Inventory

**Core fields:** SchemaVersion, RunId, TargetObjectId, TargetType, MetadataCleanupType,
CredentialMetadataEvidence, OwnerMetadataEvidence, DecommissionMarkerEvidence, RollbackLimitation,
CleanupReadiness, Status, PlanningOnly, LiveCleanupEnabled

### Metadata Cleanup Plan

**Core fields:** SchemaVersion, RunId, TargetObjectId, TargetType, MetadataCleanupType, MetadataObjectId,
DependencyRecheckStatus, CleanupReadiness, BroadCleanupBlocked, LiveCleanupEnabled, PlanningOnly, Status

### Metadata Cleanup Action Log

**Core fields:** SchemaVersion, RunId, TargetObjectId, TargetType, MetadataCleanupType, Status, Result,
SimulationOnly, LiveCleanupEnabled

### Rollback Limitation

Allowed classifications are `Reversible`, `Limited`, `NotAvailable`, and `EvidenceOnly`.

Credential metadata evidence must not export secret values, token values, certificate values, or raw credential material.

Sample: `samples/nhi-controlled-metadata-cleanup.sample.json`

---

## Rev4.6 Grant Cleanup Schemas

Rev4.6 adds grant and assignment cleanup-readiness evidence only. It does not introduce live grant removal,
app role assignment removal, or any other write/delete path.

### Grant Cleanup Plan

**Core fields:** SchemaVersion, RunId, TargetObjectId, TargetType, RelatedObjectType, RelatedObjectId,
ResourceAppId, ResourceId, PrincipalId, PermissionName, Scope, DependencyRecheckStatus, CleanupReadiness,
BroadCleanupBlocked, LiveCleanupEnabled, PlanningOnly, Status

### Dependency Recheck

Allowed statuses are `Clean`, `Blocked`, `Unknown`, and `SkippedWithApproval`.

### Post-Cleanup Validation

Allowed statuses are `NotRun`, `Simulated`, `ConfirmedAbsent`, `ConfirmedPresent`, and `Unknown`.

### Grant Cleanup Action Log

**Core fields:** SchemaVersion, RunId, TargetObjectId, RelatedObjectId, DependencyRecheckStatus,
CleanupReadiness, Status, Result, SimulationOnly, LiveCleanupEnabled

If `ResourceAppId`, `ResourceId`, `PrincipalId`, `PermissionName`, or `Scope` is present on either the
plan or approval object, the runtime must fail closed unless both sides are present and equal.

Sample: `samples/nhi-controlled-grants-cleanup.sample.json`

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
