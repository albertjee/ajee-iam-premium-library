# Schema Contracts

**SchemaVersion:** 3.2  
**Rev:** 3.2

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
