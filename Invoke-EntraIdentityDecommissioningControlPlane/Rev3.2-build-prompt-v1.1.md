# Rev3.2 Claude Code Build Prompt v1.1
# Entra Identity Decommissioning Control Plane
# Controlled Credential Hygiene and Application Governance Expansion

STATUS: PROPOSED IMPLEMENTATION PROMPT — LARGE RELEASE

Rev3.2 is the third controlled write-expansion release in the Rev3.x series.

Rev3.2 builds on:
- Rev2.0 Controlled Remediation Engine
- Rev2.1 Evidence, Preflight, Target Revalidation, and Governance Hardening
- Rev2.2 PIM + Entitlement Management Visibility
- Rev2.3 Access Review Correlation + Governance Proof
- Rev2.4 Baseline, Trend, and Executive Evidence Pack
- Rev2.5 Consultant Release Candidate and Rev3.0 Write-Readiness Gate
- Rev3.0 Controlled Entitlement and PIM Remediation Expansion
- Rev3.1 Controlled Guest Group/App-Role Remediation

CRITICAL SAFETY RULE:
Rev3.2 may expand write behavior only through the existing approved-action pipeline.
Only `Remediation.psm1` may execute tenant write operations.
All writes must be bound to approved exact `TargetObjectIds`.
No discovery, analysis, reporting, governance, baseline, executive-pack, validation, or catalog module may write.

MAIN THEME:
Rev3.2 expands controlled remediation to expired application credential hygiene and adds consultant-grade governance deliverables for application ownership, credential risk, Conditional Access exclusions, emergency access, and Rev3.3 write-readiness.

Recommended release title:

```text
Rev3.2 — Controlled Credential Hygiene and Application Governance Expansion
```

Rev3.2 is intentionally a large release, but with a narrow write surface.

---

## 0. PREREQUISITE BEFORE STARTING

Before implementing Rev3.2, Rev3.1 must be final-QA clean.

Required Rev3.1 prerequisites:

```text
1. Rev3.1 final QA pass completed.
2. Rev3.1 Pester suite passing.
3. Rev3.1 DemoMode clean.
4. Rev3.1 WhatIf demo clean.
5. Rev3.1 SelfTest clean.
6. Rev3.1 safety scan clean.
7. No open P0 or P1 findings from Rev3.1.
8. No writes outside Remediation.psm1.
9. No guest deletion behavior.
10. Stale guest targets log Skipped, not Executed.
```

Rev3.1 final QA PASS confirmed (commit 17847cf, 435/435 tests). All prerequisites met. Proceed directly to Milestone 1.

If any Rev3.1 P0/P1 remains open:

```text
STOP.
Do not begin Rev3.2.
Ask Albert to close Rev3.1 first.
```

---

## 0.5 AUTONOMOUS EXECUTION INSTRUCTIONS

Do NOT stop between milestones to ask Albert for confirmation.
Do NOT pause and ask "shall I proceed?" or "ready for go-ahead?" at any milestone boundary.
Do NOT ask Albert to say yes at any step.
Proceed through ALL milestones (1 through 26) autonomously.

Only stop and report back to Albert if:
1. A gate FAILS (parse error, import error, test failure, safety scan violation)
2. A credential removal without exact KeyId is required
3. An application or service principal deletion path is detected
4. A CA policy mutation path is detected
5. A write outside Remediation.psm1 is required
6. The Final Stop Rule triggers

If all gates pass at each milestone — proceed immediately to the next.
Report final gate summary table only when ALL milestones are complete.
Do not push. Albert pushes manually.

---

## 1. CONTEXT

Repository:

```text
https://github.com/albertjee/ajee-iam-premium-library
```

Tool location:

```text
Invoke-EntraIdentityDecommissioningControlPlane/
```

Expected Rev3.1 baseline:

```text
ToolVersion = Rev3.1
Pester tests >= 435
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
No detector writes
No discovery/analysis/reporting writes
No unapproved target writes
No guest deletion behavior
```

Rev3.2 target:

```text
ToolVersion = Rev3.2
Pester tests target >= 500
Stretch target >= 525
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
Credential hygiene pack clean
Application governance pack clean
CA exclusion governance pack clean
Emergency access governance pack clean
Rev3.3 write-readiness pack clean
No writes outside Remediation.psm1
No app deletion
No service principal deletion
No CA policy mutation
No unapproved credential writes
```

---

## 2. REV3.2 RELEASE GOALS

Rev3.2 should deliver one new controlled write action plus several large consultant-grade governance packs.

### 2.1 Controlled write expansion

Add one new executable action type:

```text
RemoveExpiredApplicationCredential
```

Optional WhatIf-only / readiness action type:

```text
AddApplicationOwner
```

Do not implement `AddApplicationOwner` execution in Rev3.2 unless all safety criteria in this prompt are satisfied and tests are added. Preferred Rev3.2 posture is WhatIf/readiness/approval packet only.

### 2.2 Consultant-grade governance packs

Add read-only deliverables:

```text
Application Ownership Governance Pack
Credential Hygiene Pack
Conditional Access Exclusion Governance Pack
Emergency Access Governance Pack
Application / Credential Exception Registers
Rev3.3 Write-Readiness Pack
```

### 2.3 Questions Rev3.2 should answer

```text
Which apps are unowned?
Which apps have only one owner?
Which apps are owned only by disabled users?
Which apps have expired credentials?
Which credentials are exact-target removable?
Which credentials are expiring but not yet removable?
Which credentials lack owner evidence?
Which CA exclusions lack review evidence?
Which emergency access accounts are protected from remediation?
Which actions are ready for approval?
Which actions are plan-only due to missing exact target data?
Which future write actions are ready for Rev3.3 design?
```

---

## 3. REV3.2 SCOPE

### 3.1 New executable write action

Include:

```text
RemoveExpiredApplicationCredential
```

### 3.2 New plan-only / readiness action candidates

Include as WhatIf/readiness only unless explicitly approved later:

```text
AddApplicationOwner
RemoveCAExclusionGroupMember
```

### 3.3 Source findings for RemoveExpiredApplicationCredential

Allowed executable source finding:

```text
DEC-APP-005 — Application has expired credential still attached
```

Plan-only source finding:

```text
DEC-APP-004 — Application secret or certificate expiring within 90 days
```

Rules:

```text
DEC-APP-005 may generate executable RemoveExpiredApplicationCredential only when exact credential KeyId is present and credential is expired at execution time.
DEC-APP-004 must remain plan-only in Rev3.2.
```

### 3.4 Source findings for AddApplicationOwner readiness

Allowed source findings:

```text
DEC-APP-001 — Application has no owner
DEC-APP-002 — Application owned exclusively by disabled user
DEC-APP-003 — Application has only one owner
DEC-SPN-001 — Service principal has no owner
```

Rules:

```text
AddApplicationOwner is approval/readiness/WhatIf-only in Rev3.2 unless explicitly implemented as a safe exact-target write.
Do not infer owner automatically.
```

### 3.5 Source findings for CA exclusion governance

Allowed source findings:

```text
DEC-CA-001
DEC-CA-002
DEC-CA-003
DEC-CA-004
```

Rules:

```text
CA exclusion remediation is read-only governance and readiness only in Rev3.2.
No CA policy mutation.
No CA group membership removal in Rev3.2.
```

---

## 4. EXPLICIT NON-GOALS

Rev3.2 must not implement:

```text
No application deletion.
No service principal deletion.
No application disable.
No service principal disable.
No non-expired credential removal.
No credential removal without exact KeyId.
No credential removal by display name.
No credential removal by hint, description, or end date alone.
No CA policy mutation.
No CA exclusion group member removal.
No guest deletion.
No user deletion.
No app owner assignment based on inferred owner.
No access review decision application.
No access review creation.
No PIM changes beyond existing Rev3.0 behavior.
No broad search-and-remove.
No "remove all expired credentials" behavior.
No live rediscovery during execution to expand targets beyond approved TargetObjectIds.
No Graph writes outside Remediation.psm1.
```

If implementation appears to require any of the above:

```text
STOP.
Do not improvise.
Ask Albert.
```

---

## 5. SAFETY MODEL — MUST REMAIN INTACT

Rev3.2 must reuse the existing safety model.

### Gate A — WhatIf manifest

Required:

```text
WhatIf manifest exists.
WhatIfRunId exists.
WhatIf manifest is fresh.
WhatIf manifest contains exact candidate actions.
WhatIf manifest was generated from assessment findings.
```

### Gate B — Approval manifest

Required:

```text
Approval manifest exists.
Approval manifest binds to WhatIfRunId.
Approval manifest has valid hashes.
Approval manifest has ApprovedActions.
Each ApprovedAction has exact ObjectId.
Each ApprovedAction has exact TargetObjectIds.
Each ApprovedAction has valid ActionType/FindingId consistency.
No duplicate ActionIds.
No duplicate target operations.
Approval has not expired.
ExecutionWindow is valid if present.
```

### Gate C — Protected object block

Required:

```text
ProtectedObject still blocks at execution time.
ProtectedObject wins over approval.
ProtectedObject cannot be overridden by Rev3.2 actions.
```

### Rev3.2 credential safety rules

```text
No write without exact credential KeyId.
No write if application read fails.
No write if credential KeyId is not found.
No write if credential is not expired at execution time.
No write if credential type is unknown.
No write if object is not an Application when action type is RemoveExpiredApplicationCredential.
No write if TargetObjectId is not a valid KeyId-like value.
No write if target credential is already gone — log Skipped, not Executed.
No write if ProtectedObject is true.
No write if approval manifest schema is older than 3.2 for Rev3.2 action types.
```

---

## 6. FILES TO MODIFY

Allowed files:

```text
Invoke-EntraIdentityDecommissioningControlPlane.ps1       # ToolVersion/scopes/parameters only if needed
src/Modules/RemediationPlan.psm1                          # WhatIf generation for credential/app owner readiness
src/Modules/ApprovalManifest.psm1                         # validation for Rev3.2 action type
src/Modules/Remediation.psm1                              # execution support for exact credential removal
src/Modules/ExecutionLog.psm1                             # credential evidence fields if needed
src/Modules/WriteReadiness.psm1                           # update execution and Rev3.3 candidate registries
src/Modules/ReleaseValidation.psm1                        # update safety invariants
src/Modules/SchemaContracts.psm1                          # update ActionType/evidence schema
src/Modules/ExecutivePack.psm1                            # optional: add app/credential governance summary
src/Modules/Reporting.psm1                                # optional: report hooks only
src/Modules/ApplicationGovernance.psm1                    # NEW read-only module
src/Modules/CredentialHygiene.psm1                        # NEW read-only module
src/Modules/ConditionalAccessGovernance.psm1              # NEW read-only module
src/Modules/EmergencyAccessGovernance.psm1                # NEW read-only module
tests/Rev11/Safety.Tests.ps1
tests/Rev11/RemediationPlan.Rev32.Tests.ps1               # NEW
tests/Rev11/Remediation.Rev32.Tests.ps1                   # NEW
tests/Rev11/ApprovalManifest.Rev32.Tests.ps1              # NEW
tests/Rev11/ApplicationGovernance.Rev32.Tests.ps1         # NEW
tests/Rev11/CredentialHygiene.Rev32.Tests.ps1             # NEW
tests/Rev11/ConditionalAccessGovernance.Rev32.Tests.ps1   # NEW
tests/Rev11/EmergencyAccessGovernance.Rev32.Tests.ps1     # NEW
tests/Rev11/ReleaseValidation.Rev32.Tests.ps1             # NEW
docs/Required-Permissions.md
docs/Findings-Catalog.md
docs/Schema-Contracts.md
docs/Rev3-Write-Readiness.md
runbooks/ExecuteRemediation-Runbook.md
runbooks/Credential-Hygiene-Runbook.md                    # NEW
runbooks/Application-Ownership-Governance-Runbook.md      # NEW
runbooks/CA-Exclusion-Governance-Runbook.md               # NEW
runbooks/Emergency-Access-Governance-Runbook.md           # NEW
CHANGELOG.md
README.md
```

Strictly forbidden unless Albert explicitly approves:

```text
src/Modules/Discovery.psm1                                # no new detector required unless exact credential KeyId already emitted
src/Modules/Analysis.psm1                                 # no scoring changes expected
src/Modules/Baseline.psm1                                 # no changes expected
src/Modules/ReleasePackaging.psm1                         # optional update only if new pack files included
```

---

## 7. VERSIONING REQUIREMENTS

Entry point must update:

```powershell
$script:ToolVersion = 'Rev3.2'
```

Schema versions:

```text
Assessment JSON SchemaVersion = 3.2
Run manifest SchemaVersion = 3.2
WhatIf action plan SchemaVersion = 3.2
Approval manifest SchemaVersion = 3.2 if schema fields change
Execution log SchemaVersion = 3.2
Execution evidence SchemaVersion = 3.2
Execution manifest SchemaVersion = 3.2
Release validation report SchemaVersion = 3.2
Credential hygiene pack SchemaVersion = 3.2
Application governance pack SchemaVersion = 3.2
CA exclusion governance pack SchemaVersion = 3.2
Emergency access governance pack SchemaVersion = 3.2
Rev3.3 write-readiness report SchemaVersion = 3.2
```

Do not leave stale Rev3.1 labels in current-version output.

Historical docs/changelog may retain old version labels.

---

## 8. GRAPH PERMISSIONS

### 8.1 Existing write scopes retained

```text
GroupMember.ReadWrite.All
AppRoleAssignment.ReadWrite.All
RoleManagement.ReadWrite.Directory
EntitlementManagement.ReadWrite.All
```

### 8.2 New write scope consideration

For credential removal, likely required:

```text
Application.ReadWrite.All
```

This is sensitive. It must be requested only in ExecuteRemediation after Gate A and Gate B pass.

### 8.3 Forbidden broad permissions

Do not add:

```text
Directory.ReadWrite.All
User.ReadWrite.All
Policy.ReadWrite.*
AccessReview.ReadWrite.All
```

### 8.4 Scope sequencing

Write scopes must still be requested only in `ExecuteRemediation` mode after Gate A and Gate B pass.

Normal Assessment / DemoMode / WhatIfRemediation / ExportPlan / SelfTest / governance pack generation must not request write scopes.

---

## 9. NEW ACTION TYPE: RemoveExpiredApplicationCredential

### 9.1 Purpose

Remove an approved expired application credential from an application object by exact KeyId.

### 9.2 Approved target identity

Required:

```text
ActionType = RemoveExpiredApplicationCredential
ObjectId = approved Application ObjectId
ObjectType = Application
TargetObjectIds = exact credential KeyId values
TargetType = ApplicationCredential
CredentialType = PasswordCredential or KeyCredential
CredentialEndDateTime
```

Recommended metadata:

```text
ApplicationId
AppId
ApplicationDisplayName
CredentialKeyId
CredentialDisplayName
CredentialType
CredentialStartDateTime
CredentialEndDateTime
CredentialExpired = true
CredentialSource = PasswordCredentials or KeyCredentials
OwnerCount
HasOwner
ProtectedObject
```

### 9.3 WhatIf generation requirements

A WhatIf action may be generated only when:

```text
FindingId = DEC-APP-005.
ObjectId is present.
ObjectType indicates Application.
Finding contains exact credential KeyId.
CredentialEndDateTime is present.
CredentialEndDateTime is earlier than current UTC.
CredentialType is PasswordCredential or KeyCredential.
RemediationMode is ManualApprovalRequired.
```

If exact KeyId is missing:

```text
Do not generate executable action.
Generate plan-only/manual guidance.
```

If credential is expiring but not expired:

```text
Do not generate executable action.
Generate owner review action only.
```

### 9.4 Approval manifest validation requirements

For each approved `RemoveExpiredApplicationCredential`:

```text
ActionType must equal RemoveExpiredApplicationCredential.
FindingId must be DEC-APP-005.
ObjectId must be non-empty GUID-like value.
TargetObjectIds must contain one or more exact credential KeyIds.
TargetObjectIds must not contain display names.
TargetObjectIds must not contain app names.
CredentialType must be PasswordCredential or KeyCredential where present.
CredentialEndDateTime must be present where available.
Action must not duplicate another approved credential removal operation.
SchemaVersion must be 3.2 or higher.
```

### 9.5 Target revalidation requirements

Before write:

```text
Read application by exact ObjectId.
If app read fails: block action.
If application does not exist: stale/no-op.
For each credential KeyId:
    Search PasswordCredentials and KeyCredentials by KeyId.
    If KeyId not found: stale/already removed, no write.
    If found but EndDateTime is null: block action.
    If found but EndDateTime >= current UTC: block action.
    If credential type does not match approved CredentialType when provided: block action.
    If app ObjectId does not match approved ObjectId: block action.
```

### 9.6 Write operation

Use exact app ObjectId and exact KeyId.

For password credentials:

```powershell
Remove-MgApplicationPassword -ApplicationId <ApplicationObjectId> -KeyId <KeyId>
```

For key credentials:

```powershell
Remove-MgApplicationKey -ApplicationId <ApplicationObjectId> -KeyId <KeyId>
```

Command availability gate:

```text
If required cmdlet is unavailable, log Blocked and continue.
Do not fallback to Invoke-MgGraphRequest DELETE unless explicitly approved and tested.
```

### 9.7 Post-write evidence

After write:

```text
Re-query exact application.
Confirm exact KeyId no longer appears in PasswordCredentials or KeyCredentials.
Record existsAfter true/false/unknown.
If re-query fails: Outcome = PartialFailed or EvidenceUnknown, not Executed.
If credential still exists: Outcome = Failed or PartialFailed.
If credential gone: Outcome = Executed.
If credential was already gone before write: Outcome = Skipped.
```

---

## 10. PLAN-ONLY ACTION: AddApplicationOwner

### 10.1 Purpose

Prepare owner approval packets for unowned or fragile applications.

Preferred Rev3.2 state:

```text
WhatIf/readiness only.
No execution by default.
```

### 10.2 Candidate findings

```text
DEC-APP-001
DEC-APP-002
DEC-APP-003
DEC-SPN-001
```

### 10.3 Owner source rules

Do not infer owner automatically.

Accept owner only if explicitly provided by:

```text
ApprovalManifest.NewOwnerObjectId
ApprovalManifest.NewOwnerUserPrincipalName
ApprovalManifest.OwnerSource = ApprovalManifest
ApprovalManifest.BusinessJustification
```

### 10.4 Rev3.2 implementation recommendation

Implement:

```text
Application owner readiness rows
Application owner approval packet
Application ownership exception register
Rev3.3 write-readiness recommendation
```

Do not implement owner write execution unless explicitly approved after separate QA.

---

## 11. NEW READ-ONLY MODULE: ApplicationGovernance.psm1

Functions:

```powershell
New-DecomApplicationGovernanceModel
Get-DecomApplicationOwnerReadiness
Export-DecomApplicationGovernanceDashboardHtml
Export-DecomApplicationOwnerReadinessJson
Export-DecomApplicationOwnerReadinessCsv
Export-DecomApplicationOwnerApprovalPacketMarkdown
Export-DecomApplicationOwnerApprovalPacketHtml
Export-DecomApplicationOwnershipExceptionRegisterCsv
Export-DecomApplicationGovernanceEvidenceAppendixMarkdown
```

Model fields:

```text
SchemaVersion
ToolVersion
GeneratedUtc
ClientName
EngagementId
Assessor
TenantId
ApplicationCount
UnownedApplicationCount
SingleOwnerApplicationCount
DisabledOwnerApplicationCount
DisabledOnlyOwnerApplicationCount
ServicePrincipalNoOwnerCount
CredentialBearingNoOwnerCount
ReadyForOwnerApprovalCount
PlanOnlyOwnerActionCount
ExceptionCount
Applications[]
OwnerReadiness[]
Exceptions[]
RecommendedNextActions[]
```

This module must be read-only.

---

## 12. NEW READ-ONLY MODULE: CredentialHygiene.psm1

Functions:

```powershell
New-DecomCredentialHygieneModel
Get-DecomCredentialRemovalReadiness
Export-DecomCredentialHygieneDashboardHtml
Export-DecomCredentialRemovalReadinessJson
Export-DecomCredentialRemovalReadinessCsv
Export-DecomCredentialOwnerApprovalPacketMarkdown
Export-DecomCredentialOwnerApprovalPacketHtml
Export-DecomCredentialRollbackGuideMarkdown
Export-DecomCredentialExceptionRegisterCsv
Export-DecomCredentialHygieneEvidenceAppendixMarkdown
Export-DecomCredentialAccessSummaryJson
```

Readiness statuses:

```text
ReadyForApproval
PlanOnlyExpiringNotExpired
BlockedMissingCredentialKeyId
BlockedCredentialNotExpired
BlockedApplicationReadFailure
BlockedNoApplicationOwner
BlockedProtectedApplication
BlockedCredentialTypeUnsupported
SkippedAlreadyRemoved
Executed
Failed
PartialFailed
Deferred
```

This module must be read-only.

---

## 13. NEW READ-ONLY MODULE: ConditionalAccessGovernance.psm1

Functions:

```powershell
New-DecomCaExclusionGovernanceModel
Get-DecomCaExclusionReadiness
Export-DecomCaExclusionGovernanceDashboardHtml
Export-DecomCaExclusionReadinessJson
Export-DecomCaExclusionReadinessCsv
Export-DecomCaExclusionOwnerReviewPacketMarkdown
Export-DecomCaExclusionOwnerReviewPacketHtml
Export-DecomCaExclusionExceptionRegisterCsv
Export-DecomCaExclusionRemediationDesignMarkdown
```

Rules:

```text
Read-only only.
No CA policy mutation.
No CA exclusion group membership removal.
No Policy.ReadWrite.* scopes.
```

Sections:

```text
CA policies with exclusions
Exclusion groups requiring access review
Exclusions lacking recent review evidence
Conflicting review evidence
High-risk exclusion patterns
Recommended manual remediation
Rev3.3 write-readiness candidates
```

---

## 14. NEW READ-ONLY MODULE: EmergencyAccessGovernance.psm1

Functions:

```powershell
New-DecomEmergencyAccessGovernanceModel
Export-DecomEmergencyAccessGovernanceReportMarkdown
Export-DecomEmergencyAccessGovernanceReportHtml
Export-DecomProtectedObjectValidationJson
Export-DecomProtectedObjectValidationCsv
```

Purpose:

```text
Validate that break-glass/emergency-access identities are protected from remediation.
```

Report should include:

```text
Protected object summary
Emergency access account inventory if available from findings/context
WhatIf actions blocked by ProtectedObject
Approval actions blocked by ProtectedObject
Potential emergency-access hygiene gaps
Recommended manual checks
```

Do not write.

---

## 15. REV3.3 WRITE-READINESS REPORT

Update `WriteReadiness.psm1` to produce:

```text
rev3.3-write-readiness-report-*.md
rev3.3-write-readiness-report-*.json
```

Candidate actions:

```text
AddApplicationOwner
RemoveCAExclusionGroupMember
RemoveNonExpiredCredentialAfterRotationEvidence
DisableApplication
DisableServicePrincipal
```

Status values:

```text
Candidate
Deferred
Unsafe
NeedsDesign
```

Recommended Rev3.2 final recommendation:

```text
ReadyForRev3.3Design
```

Not:

```text
ReadyForRev3.3Implementation
```

---

## 16. EXACT TARGET ID EXTRACTION

Extend or add helper:

```powershell
Get-DecomFindingExactTargetIds
```

For credential KeyIds, search:

```text
CredentialKeyId
CredentialKeyIds
KeyId
KeyIds
TargetObjectId
TargetObjectIds
```

Rules:

```text
Only return non-empty values.
Do not return display names.
Do not return application names.
Do not return credential display names.
Do not return date strings.
Prefer GUID-like KeyIds where possible.
If exact KeyId is missing, return empty and mark action plan-only.
```

---

## 17. EXECUTION SCOPE REGISTRY UPDATE

Existing executable findings remain:

```text
DEC-USER-001 -> RemoveGroupMembership
DEC-USER-002 -> RevokeAppRoleAssignment
DEC-USER-003 -> RemoveDirectoryRoleAssignment
DEC-ROLE-001 -> RemoveDirectoryRoleAssignment
DEC-AP-001 / 002 / 007 / 008 -> RemoveAccessPackageAssignment
DEC-PIM-001 through DEC-PIM-006 -> RemovePimEligibleAssignment
DEC-GUEST/GREV supported guest actions from Rev3.1
```

Add Rev3.2 executable entry:

```text
DEC-APP-005 -> RemoveExpiredApplicationCredential
```

Rev3.2 plan-only entries:

```text
DEC-APP-004 -> CredentialOwnerReviewOnly
DEC-APP-001 / 002 / 003 / DEC-SPN-001 -> ApplicationOwnerReadinessOnly
DEC-CA-001 / 002 / 003 / 004 -> CaExclusionGovernanceOnly
```

Registry fields:

```text
FindingId
ActionType
WriteScope
TargetType
TargetObjectIdsRepresent
RequiresPerActionPrompt
IntroducedIn
Status
RiskLevel
ApplicationOnly
CredentialType
```

Recommended:

```text
RemoveExpiredApplicationCredential:
    RequiresPerActionPrompt = true
    Status = ExecutableWhenExactExpiredCredentialKeyIdPresent
    RiskLevel = High
    IntroducedIn = Rev3.2
```

---

## 18. WHATIF ACTION PLAN REQUIREMENTS

For `RemoveExpiredApplicationCredential`, WhatIf output must include:

```text
ActionId
FindingId
ActionType
ObjectId
ObjectType
DisplayName
TargetObjectIds
TargetDisplayNames if available
TargetType
CredentialType
CredentialKeyId
CredentialEndDateTime
CredentialExpired
RiskScore
Severity
ProtectedObject
RequiresManualApproval = true
RollbackGuidance
PreflightChecks
PostWriteEvidenceRequired
ReadinessStatus
ReadinessReason
```

Rollback guidance:

```text
Rollback requires creating a new application credential through the application owner or platform engineering process. Rev3.2 does not auto-rollback credential removal because secret material cannot be recovered after deletion.
```

Important:

```text
Do not claim the exact secret/certificate value can be restored.
```

---

## 19. APPROVAL MANIFEST REQUIREMENTS

Approval manifest validation must include:

```text
ActionType allowlist includes RemoveExpiredApplicationCredential.
FindingId/ActionType consistency checks.
DEC-APP-005 only.
TargetObjectIds required.
TargetObjectIds exact KeyIds only.
No duplicate credential target operations.
ProtectedObject cannot be approved for execution.
ApprovedActionsHash includes credential metadata affecting execution.
ApprovalEnvelopeHash includes metadata + ActionsHash.
WhatIfRunId binding preserved.
ExecutionWindow preserved.
AllowNonInteractive preserved.
```

Schema gate:

```text
If ApprovalManifest.SchemaVersion < 3.2, reject RemoveExpiredApplicationCredential.
```

Add to canonical approval hash:

```text
CredentialType
CredentialKeyId
CredentialEndDateTime
CredentialExpired
ApplicationId
AppId
ApplicationDisplayName
OwnerCount
HasOwner
ReadinessStatus
ReadinessReason
```

---

## 20. REMEDIATION ENGINE REQUIREMENTS

All write execution must happen in `Remediation.psm1`.

### 20.1 Per-action execution flow for RemoveExpiredApplicationCredential

```text
1. Validate action type is supported.
2. Confirm ProtectedObject false.
3. Confirm FindingId = DEC-APP-005.
4. Confirm TargetObjectIds present.
5. Confirm ObjectType is Application where available.
6. Run credential target revalidation.
7. If revalidation fails, log Blocked and continue.
8. If credential already removed, log Skipped and continue.
9. If credential exists and is expired, execute exact credential removal.
10. Re-query exact application credential state.
11. Calculate outcome.
12. Write execution log entry.
13. Write evidence row.
```

### 20.2 Failure outcome rules

```text
Write failed -> Failed, even if after-state is empty unless write failure can be confidently reconciled.
Re-query failed -> PartialFailed or EvidenceUnknown, not Executed.
Application read failure during revalidation -> Blocked.
Credential KeyId mismatch -> Blocked.
Credential not expired -> Blocked.
Credential already removed -> Skipped.
ProtectedObject -> Blocked.
Operator declined -> OperatorDeclined.
Out of scope action -> OutOfScope.
```

---

## 21. EXECUTION EVIDENCE SCHEMA EXTENSION

Add fields where available:

```text
RunId
ActionId
FindingId
ActionType
ObjectId
ObjectType
DisplayName
TargetObjectId
TargetType
TargetDisplayName
CredentialType
CredentialKeyId
CredentialDisplayName
CredentialStartDateTime
CredentialEndDateTime
CredentialExpired
BeforeExists
AfterExists
Outcome
ErrorDetail
ApprovedBy
ApprovalManifestHash
ExecutedUtc
GraphWriteCmdlet
PostWriteRequeryStatus
ApplicationId
AppId
OwnerCount
HasOwner
ReadinessStatus
```

CSV and JSON exports must include these fields where available.

---

## 22. PROTECTED OBJECT RULES

Protected object logic must apply to Rev3.2 actions.

Rev3.2 protected object block must cover:

```text
Break-glass identities
VIP apps if tagged
Protected applications if tagged
Privileged emergency access apps if identified
Any finding flagged ProtectedObject = true
Any approval action carrying ProtectedObject = true
```

Do not add override in Rev3.2.

---

## 23. DEMO MODE REQUIREMENTS

DemoMode must remain no-Graph and no-write.

DemoMode should include synthetic data sufficient to generate:

```text
RemoveExpiredApplicationCredential WhatIf candidate
Credential hygiene dashboard
Credential owner approval packet
Application ownership governance dashboard
CA exclusion governance dashboard
Emergency access governance report
Rev3.3 write-readiness report
```

DemoMode must not request write scopes or call remediation writes.

---

## 24. SELFTEST / RELEASE VALIDATION UPDATE

SelfTest must validate:

```text
Rev3.2 action registry.
No writes outside Remediation.psm1.
ApplicationGovernance.psm1 is read-only.
CredentialHygiene.psm1 is read-only.
ConditionalAccessGovernance.psm1 is read-only.
EmergencyAccessGovernance.psm1 is read-only.
Write scopes appear only after Gate A/B in ExecuteRemediation.
Assessment/WhatIf/Demo do not request write scopes.
Unsupported Rev3.2 action types are blocked.
Rev3.1 and earlier approval manifests cannot authorize Rev3.2 actions.
No app deletion cmdlets appear.
No service principal deletion cmdlets appear.
No CA policy write cmdlets appear.
```

---

## 25. GOVERNANCE DELIVERABLES

### 25.1 Credential Hygiene Pack

Outputs:

```text
credential-hygiene-dashboard-*.html
credential-removal-readiness-*.json
credential-removal-readiness-*.csv
credential-owner-approval-packet-*.md
credential-owner-approval-packet-*.html
credential-rollback-guide-*.md
credential-exception-register-*.csv
credential-hygiene-evidence-appendix-*.md
credential-access-summary-*.json
```

### 25.2 Application Ownership Governance Pack

Outputs:

```text
application-ownership-dashboard-*.html
application-owner-readiness-*.json
application-owner-readiness-*.csv
application-owner-approval-packet-*.md
application-owner-approval-packet-*.html
application-ownership-exception-register-*.csv
application-governance-evidence-appendix-*.md
```

### 25.3 CA Exclusion Governance Pack

Outputs:

```text
ca-exclusion-governance-dashboard-*.html
ca-exclusion-readiness-*.json
ca-exclusion-readiness-*.csv
ca-exclusion-owner-review-packet-*.md
ca-exclusion-owner-review-packet-*.html
ca-exclusion-exception-register-*.csv
ca-exclusion-remediation-design-*.md
```

### 25.4 Emergency Access Governance Pack

Outputs:

```text
emergency-access-governance-report-*.md
emergency-access-governance-report-*.html
protected-object-validation-*.json
protected-object-validation-*.csv
```

### 25.5 Rev3.3 Write-Readiness Pack

Outputs:

```text
rev3.3-write-readiness-report-*.md
rev3.3-write-readiness-report-*.json
```

---

## 26. DOCUMENTATION UPDATES

Add/update:

```text
docs/Required-Permissions.md
docs/Findings-Catalog.md
docs/Schema-Contracts.md
docs/Rev3-Write-Readiness.md
runbooks/ExecuteRemediation-Runbook.md
runbooks/Credential-Hygiene-Runbook.md
runbooks/Application-Ownership-Governance-Runbook.md
runbooks/CA-Exclusion-Governance-Runbook.md
runbooks/Emergency-Access-Governance-Runbook.md
README.md
CHANGELOG.md
```

Required permission note:

```markdown
## Rev3.2 Controlled Credential Hygiene Remediation

Rev3.2 adds controlled removal of expired application credentials by exact KeyId.

| ActionType | Permission | Used Only In |
|---|---|---|
| `RemoveExpiredApplicationCredential` | `Application.ReadWrite.All` | ExecuteRemediation after Gate A/B |

This permission is not requested in Assessment, DemoMode, ExportPlan, WhatIfRemediation, SelfTest, or governance pack generation modes.
```

---

## 27. TEST REQUIREMENTS

Expected Rev3.1 baseline:

```text
>= 435 tests
0 failures
```

Rev3.2 target:

```text
>= 500 tests
Stretch target >= 525
0 failures
```

Minimum new tests:

### 27.1 Safety tests

```text
1. Assessment mode does not request Application.ReadWrite.All.
2. DemoMode does not request Application.ReadWrite.All.
3. WhatIfRemediation does not request write scopes.
4. ExecuteRemediation write scopes still occur only after Gate A/B.
5. Discovery.psm1 contains no write cmdlets.
6. ApplicationGovernance.psm1 contains no write cmdlets.
7. CredentialHygiene.psm1 contains no write cmdlets.
8. ConditionalAccessGovernance.psm1 contains no write cmdlets.
9. EmergencyAccessGovernance.psm1 contains no write cmdlets.
10. Rev3.2 action types blocked in Rev3.1 and older approval manifests.
11. ProtectedObject blocks credential removal.
12. Unknown Rev3.2 action type is OutOfScope or Blocked.
13. No app deletion cmdlets appear.
14. No service principal deletion cmdlets appear.
15. No CA policy write cmdlets appear.
16. No user/guest deletion cmdlets appear.
```

### 27.2 WhatIf tests

```text
17. DEC-APP-005 with exact expired password credential KeyId generates RemoveExpiredApplicationCredential.
18. DEC-APP-005 with exact expired key credential KeyId generates RemoveExpiredApplicationCredential.
19. DEC-APP-005 without KeyId does not generate executable action.
20. DEC-APP-004 expiring credential remains plan-only.
21. Non-expired credential does not generate executable action.
22. Credential rollback guidance says secret value cannot be recovered.
23. Credential action requires manual approval.
24. ReadinessStatus is present.
```

### 27.3 Approval manifest tests

```text
25. Approval manifest accepts valid RemoveExpiredApplicationCredential.
26. Approval manifest rejects credential action with invalid FindingId.
27. Approval manifest rejects missing TargetObjectIds.
28. Approval manifest rejects duplicate credential target operation.
29. Approval manifest rejects SchemaVersion < 3.2.
30. Approval hash changes when CredentialType changes.
31. Approval hash changes when CredentialEndDateTime changes.
32. Approval hash changes when TargetObjectIds changes.
```

### 27.4 Revalidation tests

```text
33. Application read failure blocks action.
34. Missing credential KeyId blocks action or marks stale according to expected state.
35. Credential already removed logs Skipped.
36. Credential not expired blocks action.
37. Credential type mismatch blocks action.
38. PasswordCredential exact KeyId validates.
39. KeyCredential exact KeyId validates.
40. ProtectedObject blocks before write.
```

### 27.5 Execution tests

```text
41. RemoveExpiredApplicationCredential removes only approved password KeyId.
42. RemoveExpiredApplicationCredential removes only approved key KeyId.
43. Unapproved KeyId is never removed.
44. Write failure logs Failed.
45. Post-write re-query failure logs PartialFailed/EvidenceUnknown.
46. Already removed credential logs Skipped.
47. Successful removal logs Executed only after confirmed KeyId absent.
```

### 27.6 Governance pack tests

```text
48. Credential hygiene model created.
49. Credential readiness JSON exported.
50. Credential readiness CSV exported.
51. Credential dashboard HTML exported.
52. Credential approval packet exported.
53. Credential rollback guide exported.
54. Application governance model created.
55. Application ownership dashboard exported.
56. Application owner readiness exported.
57. CA exclusion governance model created.
58. CA exclusion dashboard exported.
59. Emergency access governance report exported.
60. ProtectedObject validation exported.
61. Rev3.3 write-readiness report exported.
```

---

## 28. MILESTONE IMPLEMENTATION PLAN

Implement in milestones.

### Milestone 0 — Rev3.1 Baseline Verification

```text
Confirm branch clean, Rev3.1 tests pass, SelfTest passes, ToolVersion currently Rev3.1.
```

Gate:

```powershell
Invoke-Pester -Path .\tests\Rev11\ -Output Detailed
pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -SelfTest
```

### Milestone 1 — Version + Schema Plumbing

```text
Set ToolVersion = Rev3.2.
Update current output SchemaVersion to 3.2.
Do not change write behavior yet.
```

### Milestone 2 — New Read-Only Module Skeletons

Create:

```text
ApplicationGovernance.psm1
CredentialHygiene.psm1
ConditionalAccessGovernance.psm1
EmergencyAccessGovernance.psm1
```

Add no-write safety tests.

### Milestone 3 — Execution Scope Registry Update

```text
Add DEC-APP-005 -> RemoveExpiredApplicationCredential.
Add plan-only registry entries for DEC-APP-004, app owner findings, and CA exclusions.
```

### Milestone 4 — Credential Exact Target Helper

```text
Extract KeyId from finding properties.
Reject display names, app names, and dates.
```

### Milestone 5 — Credential Hygiene Model

```text
Build credential readiness statuses and model exports.
```

### Milestone 6 — WhatIf Generation for Expired Credentials

```text
Generate RemoveExpiredApplicationCredential only for DEC-APP-005 with exact expired KeyId.
```

### Milestone 7 — Approval Manifest Validation

```text
Add action allowlist, schema gate, target validation, duplicate operation detection, hash fields.
```

### Milestone 8 — Credential Target Revalidation

```text
Read application, locate KeyId, confirm expired, confirm type, block failures.
```

### Milestone 9 — Execute RemoveExpiredApplicationCredential

```text
Implement password/key credential removal in Remediation.psm1 only.
```

### Milestone 10 — Post-Write Credential Evidence

```text
Re-query app credential state and prevent failed re-query from logging Executed.
```

### Milestone 11 — Credential Hygiene Dashboard

```text
Export HTML dashboard and readiness CSV/JSON.
```

### Milestone 12 — Credential Owner Approval Packet

```text
Export MD/HTML packet with exact KeyIds and owner approval table.
```

### Milestone 13 — Credential Rollback Guide

```text
Export rollback guide explaining secret/cert material cannot be recovered.
```

### Milestone 14 — Application Governance Model

```text
Build app ownership model from findings and readiness data.
```

### Milestone 15 — Application Governance Dashboard

```text
Export application ownership dashboard, readiness, approval packet, exception register.
```

### Milestone 16 — AddApplicationOwner Plan-Only Readiness

```text
Generate owner readiness only; no write execution.
```

### Milestone 17 — CA Exclusion Governance Model

```text
Build CA exclusion governance/readiness model.
```

### Milestone 18 — CA Exclusion Governance Outputs

```text
Export dashboard, owner review packet, exception register, remediation design.
```

### Milestone 19 — Emergency Access Governance

```text
Export emergency access report and protected-object validation files.
```

### Milestone 20 — Rev3.3 Write-Readiness Report

```text
Produce ReadyForRev3.3Design report.
```

### Milestone 21 — Evidence Schema Update

```text
Add credential fields to execution evidence.
```

### Milestone 22 — SelfTest / ReleaseValidation Update

```text
Validate new action scope, read-only modules, write-scope isolation, deletion absence.
```

### Milestone 23 — Documentation and Runbooks

```text
Update docs, README, CHANGELOG, and add new runbooks.
```

### Milestone 24 — Demo and WhatIf Validation

```text
DemoMode clean.
WhatIf demo includes credential candidate.
Governance packs generate in demo if enabled.
```

### Milestone 25 — Safety Scan

Run:

```powershell
Select-String -Path .\src\Modules\*.psm1,.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Pattern 'ReadWrite|Remove-Mg|Update-Mg|Set-Mg|New-Mg|Invoke-Mg|Remove-MgApplication|Remove-MgServicePrincipal|Remove-MgUser' |
    Format-Table Path,LineNumber,Line -AutoSize
```

Expected:

```text
Write scopes only in ExecuteRemediation branch after Gate A/B.
Write cmdlets only in Remediation.psm1.
No app/SP deletion cmdlets.
No CA policy write cmdlets.
No writes in governance modules.
```

### Milestone 26 — Final Verification

Run:

```powershell
Invoke-Pester -Path .\tests\Rev11\ -Output Detailed

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode -Mode WhatIfRemediation -GenerateApprovalTemplate

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -SelfTest
```

Required final:

```text
Parse errors: 0
All modules import cleanly
>= 500 Pester tests
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
Credential hygiene pack clean
Application governance pack clean
CA exclusion governance pack clean
Emergency access governance pack clean
No writes outside Remediation.psm1
No write scopes outside ExecuteRemediation after Gate A/B
No unapproved credential writes
No app/SP deletion
No CA policy mutation
```

---

## 29. CHANGELOG ENTRY

Prepend:

```markdown
## Rev3.2 — Controlled Credential Hygiene and Application Governance Expansion

### Added
- Controlled remediation action: RemoveExpiredApplicationCredential.
- Credential hygiene readiness model, dashboard, approval packet, rollback guide, and exception register.
- Application ownership governance model, dashboard, owner readiness, approval packet, and exception register.
- Conditional Access exclusion governance dashboard, review packet, exception register, and remediation design.
- Emergency access governance report and ProtectedObject validation exports.
- Rev3.3 write-readiness report.
- Approval manifest validation for Rev3.2 action type.
- Target revalidation for expired application credentials.
- Post-write re-query evidence for credential removal.

### Safety
- Rev3.2 expands writes only through the existing approved-action pipeline.
- No application deletion.
- No service principal deletion.
- No CA policy mutation.
- No non-expired credential removal.
- All credential writes require exact approved KeyIds.
- Rev3.1 and earlier manifests cannot authorize Rev3.2 credential actions.

### Tests
- Added Rev3.2 WhatIf, approval manifest, revalidation, execution, evidence, governance pack, and safety tests.
- Target: >= 500 tests, 0 failures.
```

---

## 30. README UPDATE

Add:

```markdown
## Rev3.2 Controlled Credential Hygiene

Rev3.2 adds controlled removal of expired application credentials by exact KeyId.

| ActionType | Purpose |
|---|---|
| RemoveExpiredApplicationCredential | Remove approved expired application password/key credentials by exact KeyId |

Rev3.2 also adds:
- Credential Hygiene Pack
- Application Ownership Governance Pack
- Conditional Access Exclusion Governance Pack
- Emergency Access Governance Pack
- Rev3.3 Write-Readiness Pack

Rev3.2 does not delete applications, service principals, users, guests, or Conditional Access policies.
```

---

## 31. DONE CRITERIA

Rev3.2 is done only when:

```text
1. ToolVersion = Rev3.2.
2. SchemaVersion = 3.2 for current run outputs.
3. RemoveExpiredApplicationCredential implemented only in approved pipeline.
4. WhatIf generation requires exact expired credential KeyId.
5. Approval validation rejects malformed/mismatched Rev3.2 actions.
6. Revalidation blocks Graph read failures.
7. Revalidation blocks non-expired credentials.
8. Revalidation blocks missing KeyId.
9. ProtectedObject blocks Rev3.2 actions.
10. Post-write evidence is re-queried.
11. Execution evidence includes credential fields.
12. CredentialHygiene.psm1 is read-only.
13. ApplicationGovernance.psm1 is read-only.
14. ConditionalAccessGovernance.psm1 is read-only.
15. EmergencyAccessGovernance.psm1 is read-only.
16. Credential hygiene pack exported.
17. Application governance pack exported.
18. CA exclusion governance pack exported.
19. Emergency access governance pack exported.
20. Rev3.3 write-readiness report exported.
21. No detector writes.
22. No writes outside Remediation.psm1.
23. No write scopes outside ExecuteRemediation after Gate A/B.
24. Assessment/Demo/WhatIf do not request write scopes.
25. Rev3.1 and earlier approval manifests cannot authorize Rev3.2 actions.
26. No app deletion behavior.
27. No service principal deletion behavior.
28. No CA policy mutation behavior.
29. >= 500 Pester tests passing, 0 failures.
30. Demo mode clean.
31. WhatIf demo clean.
32. SelfTest clean.
33. Safety scan clean.
34. Required docs/runbooks updated.
```

---

## 32. FINAL STOP RULE

If the external AI coding engine cannot identify exact expired credential KeyIds from finding evidence:

```text
Do not generate executable action.
Do not broad-query credentials to create executable targets.
Create plan-only/manual guidance instead.
```

If the credential is not expired at execution time:

```text
Block execution.
Do not remove it.
```

If any implementation path would delete an application or service principal:

```text
Fail the build.
Stop immediately.
Ask Albert.
```

If any implementation path would mutate Conditional Access:

```text
Fail the build.
Stop immediately.
Ask Albert.
```

If any implementation path would write outside Remediation.psm1:

```text
Fail the build.
Do not proceed.
```

If test count passes but safety scan shows unexpected write behavior:

```text
Fail the build.
Do not proceed.
```

If Rev3.2 becomes too broad:

```text
Stop.
Limit write behavior to RemoveExpiredApplicationCredential only.
Keep app ownership and CA exclusion governance read-only.
```
