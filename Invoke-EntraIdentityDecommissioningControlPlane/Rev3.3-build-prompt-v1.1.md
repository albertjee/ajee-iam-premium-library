# Rev3.3 Claude Code Build Prompt v1.1
# Entra Identity Decommissioning Control Plane
# Controlled Application Owner and Conditional Access Exclusion Group Remediation

STATUS: PROPOSED IMPLEMENTATION PROMPT — MAJOR WRITE-EXPANSION RELEASE

Rev3.3 is the recommended final major controlled write-expansion release before production hardening.

Rev3.3 builds on:
- Rev2.0 Controlled Remediation Engine
- Rev2.1 Evidence, Preflight, Target Revalidation, and Governance Hardening
- Rev2.2 PIM + Entitlement Management Visibility
- Rev2.3 Access Review Correlation + Governance Proof
- Rev2.4 Baseline, Trend, and Executive Evidence Pack
- Rev2.5 Consultant Release Candidate and Rev3.0 Write-Readiness Gate
- Rev3.0 Controlled Entitlement and PIM Remediation Expansion
- Rev3.1 Controlled Guest Group/App-Role Remediation
- Rev3.2 Controlled Credential Hygiene and Application Governance Expansion

CRITICAL SAFETY RULE:
Rev3.3 may expand write behavior only through the existing approved-action pipeline.
Rev3.3 must not introduce direct detector writes.
Rev3.3 must not allow discovery, analysis, reporting, baseline, executive pack, release validation, catalog validation, write-readiness, application governance, credential hygiene, conditional access governance, or emergency access governance code to write to the tenant.
Only Remediation.psm1 may execute tenant write operations.
All writes must be bound to approved exact TargetObjectIds and exact approved ObjectIds.

Recommended release title:

```text
Rev3.3 — Controlled Application Owner and CA Exclusion Group Remediation
```

Rev3.3 expands controlled remediation to two high-value governance actions:

```text
1. AddApplicationOwner
2. RemoveCAExclusionGroupMember
```

Everything else remains plan-only, readiness-only, or deferred.

---

## 0. PREREQUISITE BEFORE STARTING

Before implementing Rev3.3, Rev3.2 must be final-QA clean.

Required Rev3.2 prerequisites:

```text
1. Rev3.2 final QA pass completed.
2. Rev3.2 Pester suite passing.
3. Rev3.2 DemoMode clean.
4. Rev3.2 WhatIf demo clean.
5. Rev3.2 SelfTest clean.
6. Rev3.2 safety scan clean.
7. No open P0 or P1 findings from Rev3.2.
8. No writes outside Remediation.psm1.
9. No app deletion behavior.
10. No service principal deletion behavior.
11. No CA policy mutation behavior.
12. Already-removed credentials log Skipped, not Executed.
13. Application.ReadWrite.All is scoped to ExecuteRemediation only.
```

Rev3.2 final QA PASS confirmed (commit 001d091, 566/566 tests). All prerequisites met. Proceed directly to Milestone 1.

If any Rev3.2 P0/P1 remains open:

```text
STOP.
Do not begin Rev3.3.
Ask Albert to close Rev3.2 first.
```

---

## 0.5 AUTONOMOUS EXECUTION INSTRUCTIONS

Do NOT stop between milestones to ask Albert for confirmation.
Do NOT pause and ask "shall I proceed?" or "ready for go-ahead?" at any milestone boundary.
Do NOT ask Albert to say yes at any step.
Proceed through ALL milestones (0 through 20) autonomously.

Only stop and report back to Albert if:
1. A gate FAILS (parse error, import error, test failure, safety scan violation)
2. A CA policy mutation path is detected
3. An application or service principal deletion path is detected
4. An owner inference from display name/app name/email is required
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

Expected Rev3.2 baseline:

```text
ToolVersion = Rev3.2
Pester tests >= 566
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
No detector writes
No discovery/analysis/reporting writes
No unapproved target writes
No app/SP deletion
No CA policy mutation
```

Rev3.3 target:

```text
ToolVersion = Rev3.3
Pester tests target >= 650
Stretch target >= 675
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
Application owner remediation pack clean
CA exclusion remediation pack clean
Rev3 remediation capability matrix generated
Rev3.4 production-hardening readiness report generated
No writes outside Remediation.psm1
No app deletion
No service principal deletion
No CA policy mutation
No unapproved owner writes
No unapproved CA exclusion group membership writes
```

---

## 2. REV3.3 RELEASE GOALS

### 2.1 Controlled write expansion

Add these new executable action types:

```text
AddApplicationOwner
RemoveCAExclusionGroupMember
```

### 2.2 Plan-only / readiness-only candidates

Keep these non-executable in Rev3.3:

```text
RemoveDisabledApplicationOwner
RemoveNonExpiredCredentialAfterRotationEvidence
DisableApplication
DisableServicePrincipal
ModifyConditionalAccessPolicy
ApplyAccessReviewDecision
```

### 2.3 Consultant-grade deliverables

Add read-only deliverables:

```text
Application Owner Remediation Pack
CA Exclusion Remediation Pack
Rev3 Remediation Capability Matrix
Rev3.4 Production-Hardening Readiness Pack
Enhanced rollback and evidence appendices
```

### 2.4 Questions Rev3.3 should answer

```text
Which apps/SPNs can safely receive a new approved owner?
Which ownership findings remain plan-only due to missing approved owner object?
Which CA exclusions can safely remove a principal from an exclusion group?
Which CA exclusion findings remain plan-only due to missing exact group/member evidence?
Which writes were approved?
Which writes were blocked?
Which writes were skipped because target state already changed?
Which writes executed and were confirmed by post-write re-query?
Which actions are still too dangerous for this consultant tool?
```

---

## 3. SCOPE

### 3.1 New executable write action: AddApplicationOwner

Allowed source findings:

```text
DEC-APP-001 — Application has no owners
DEC-APP-002 — Application owned exclusively by disabled user
DEC-APP-003 — Application has only one owner / fragile ownership
DEC-SPN-001 — Service principal has no owner
```

### 3.2 New executable write action: RemoveCAExclusionGroupMember

Allowed source findings:

```text
DEC-CA-002 — CA exclusion group membership requires access review
DEC-CA-003 — CA exclusion lacks confirmable review evidence
DEC-CA-004 — CA exclusion review decision conflicts with active exclusion
```

### 3.3 Explicit non-goals

Rev3.3 must not implement:

```text
No application deletion.
No service principal deletion.
No application disable.
No service principal disable.
No disabled owner removal unless replacement owner is confirmed and explicitly approved in a future release.
No credential removal beyond Rev3.2 RemoveExpiredApplicationCredential.
No non-expired credential removal.
No CA policy mutation.
No direct CA include/exclude policy modification.
No Policy.ReadWrite.* scope.
No access review decision application.
No access review creation.
No guest deletion.
No user deletion.
No owner inference from display name, department, sponsor, app name, or email.
No broad search-and-remove.
No "remove all CA exclusions" behavior.
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

## 4. SAFETY MODEL — MUST REMAIN INTACT

Rev3.3 must reuse the existing safety model.

### Gate A — WhatIf manifest

```text
WhatIf manifest exists.
WhatIfRunId exists.
WhatIf manifest is fresh.
WhatIf manifest contains exact candidate actions.
WhatIf manifest was generated from assessment findings.
```

### Gate B — Approval manifest

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

```text
ProtectedObject still blocks at execution time.
ProtectedObject wins over approval.
ProtectedObject cannot be overridden by Rev3.3 actions.
```

### Rev3.3 added safety rules

```text
No owner write without exact NewOwnerObjectId.
No owner write if target app/SP read fails.
No owner write if NewOwnerObjectId read fails.
No owner write if NewOwnerObjectId is disabled.
No owner write if NewOwnerObjectId is a guest unless AllowGuestOwner = true in approval manifest.
No owner write if target app/SP already has owner and action type is not appropriate.
No CA exclusion write without exact ExclusionGroupId and exact ExcludedPrincipalId.
No CA exclusion write if CA policy no longer excludes the approved group.
No CA exclusion write if principal is not member of approved exclusion group.
No CA exclusion write if principal is ProtectedObject.
No CA exclusion write if principal is emergency access / break-glass.
No CA policy mutation under any circumstance.
No Policy.ReadWrite.* scope under any circumstance.
No write if approval manifest schema is older than 3.3 for Rev3.3 action types.
```

---

## 5. FILES TO MODIFY

Allowed files:

```text
Invoke-EntraIdentityDecommissioningControlPlane.ps1
src/Modules/RemediationPlan.psm1
src/Modules/ApprovalManifest.psm1
src/Modules/Remediation.psm1
src/Modules/ExecutionLog.psm1
src/Modules/WriteReadiness.psm1
src/Modules/ReleaseValidation.psm1
src/Modules/SchemaContracts.psm1
src/Modules/ApplicationGovernance.psm1
src/Modules/ConditionalAccessGovernance.psm1
src/Modules/EmergencyAccessGovernance.psm1
src/Modules/Reporting.psm1
src/Modules/ExecutivePack.psm1
src/Modules/Rev3CapabilityMatrix.psm1
tests/Rev11/Safety.Tests.ps1
tests/Rev11/RemediationPlan.Rev33.Tests.ps1
tests/Rev11/Remediation.Rev33.Tests.ps1
tests/Rev11/ApprovalManifest.Rev33.Tests.ps1
tests/Rev11/ApplicationOwnerRemediation.Rev33.Tests.ps1
tests/Rev11/CaExclusionRemediation.Rev33.Tests.ps1
tests/Rev11/Rev3CapabilityMatrix.Rev33.Tests.ps1
tests/Rev11/ReleaseValidation.Rev33.Tests.ps1
docs/Required-Permissions.md
docs/Findings-Catalog.md
docs/Schema-Contracts.md
docs/Rev3-Write-Readiness.md
runbooks/ExecuteRemediation-Runbook.md
runbooks/Application-Owner-Remediation-Runbook.md
runbooks/CA-Exclusion-Group-Remediation-Runbook.md
runbooks/Rev3-Capability-Matrix-Runbook.md
CHANGELOG.md
README.md
```

Strictly forbidden unless Albert explicitly approves:

```text
src/Modules/Discovery.psm1
src/Modules/Analysis.psm1
src/Modules/Baseline.psm1
src/Modules/CredentialHygiene.psm1
src/Modules/ReleasePackaging.psm1
```

---

## 6. VERSIONING AND PERMISSIONS

Entry point must update:

```powershell
$script:ToolVersion = 'Rev3.3'
```

Schema versions:

```text
Assessment JSON SchemaVersion = 3.3
Run manifest SchemaVersion = 3.3
WhatIf action plan SchemaVersion = 3.3
Approval manifest SchemaVersion = 3.3 if schema fields change
Execution log SchemaVersion = 3.3
Execution evidence SchemaVersion = 3.3
Execution manifest SchemaVersion = 3.3
Release validation report SchemaVersion = 3.3
Application owner remediation pack SchemaVersion = 3.3
CA exclusion remediation pack SchemaVersion = 3.3
Rev3 capability matrix SchemaVersion = 3.3
Rev3.4 readiness report SchemaVersion = 3.3
```

Existing write scopes retained:

```text
GroupMember.ReadWrite.All
AppRoleAssignment.ReadWrite.All
RoleManagement.ReadWrite.Directory
EntitlementManagement.ReadWrite.All
Application.ReadWrite.All
```

Preferred Rev3.3:

```text
No new write scopes beyond existing Rev3.2 write scopes.
```

For `AddApplicationOwner`, use:

```text
Application.ReadWrite.All
```

For `RemoveCAExclusionGroupMember`, use:

```text
GroupMember.ReadWrite.All + Policy.Read.All
```

Do not add:

```text
Policy.ReadWrite.*
Directory.ReadWrite.All
User.ReadWrite.All
AccessReview.ReadWrite.All
```

Write scopes must still be requested only in `ExecuteRemediation` mode after Gate A and Gate B pass.

---

## 7. NEW ACTION TYPE: AddApplicationOwner

### Purpose

Add an explicitly approved owner to an application or service principal.

### Required approved action fields

```text
ActionType = AddApplicationOwner
ObjectId = approved Application or ServicePrincipal ObjectId
ObjectType = Application or ServicePrincipal
TargetObjectIds = exact NewOwnerObjectId values
TargetType = DirectoryObjectOwner
NewOwnerObjectId
NewOwnerUserPrincipalName
NewOwnerType = User | Group | ServicePrincipal
OwnerSource = ApprovalManifest | ExplicitOwnerMapping
BusinessJustification
```

### Optional owner mapping file

Rev3.3 may support:

```text
-OwnerMappingPath
```

CSV columns:

```text
ObjectId
ObjectType
NewOwnerObjectId
NewOwnerUserPrincipalName
NewOwnerType
BusinessJustification
BusinessOwner
TechnicalOwner
ApprovalTicket
AllowGuestOwner
```

OwnerMappingPath is read-only input. It cannot bypass approval manifest. It can populate WhatIf metadata only.

### WhatIf generation requirements

Generate executable `AddApplicationOwner` only when:

```text
FindingId is DEC-APP-001, DEC-APP-002, DEC-APP-003, or DEC-SPN-001.
ObjectId is present.
ObjectType is Application or ServicePrincipal.
NewOwnerObjectId is explicitly provided by approval/readiness input or owner mapping file.
OwnerSource is ApprovalManifest or ExplicitOwnerMapping.
RemediationMode is ManualApprovalRequired.
```

If exact NewOwnerObjectId is missing:

```text
Do not generate executable action.
Generate plan-only owner readiness guidance.
```

Do not infer owner from display name, app name, department, UPN text, sponsor, or owner count.

### Revalidation requirements

Before write:

```text
Read target application/service principal by exact ObjectId.
If target read fails: block action.
If target does not exist: stale/no-op.
Read current owners.
If NewOwnerObjectId is already owner: Skipped/no-op.
Read NewOwnerObjectId.
If owner read fails: block action.
If owner is user and AccountEnabled = false: block action.
If owner is user and UserType = Guest and AllowGuestOwner != true: block action.
If ObjectType is not Application or ServicePrincipal: block action.
If target object does not match approved ObjectId: block action.
```

### Write operation

For Application:

```powershell
New-MgApplicationOwnerByRef -ApplicationId <ApplicationObjectId> -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/<NewOwnerObjectId>' }
```

For ServicePrincipal:

```powershell
New-MgServicePrincipalOwnerByRef -ServicePrincipalId <ServicePrincipalObjectId> -BodyParameter @{ '@odata.id' = 'https://graph.microsoft.com/v1.0/directoryObjects/<NewOwnerObjectId>' }
```

Command availability gate required. If unavailable, log Blocked and continue.

### Post-write evidence

```text
Re-query owners.
Confirm NewOwnerObjectId appears in owners.
If re-query fails: Outcome = PartialFailed or EvidenceUnknown, not Executed.
If owner still absent: Outcome = Failed or PartialFailed.
If owner present: Outcome = Executed.
If owner was already present before write: Outcome = Skipped.
```

---

## 8. NEW ACTION TYPE: RemoveCAExclusionGroupMember

### Purpose

Remove an approved principal from an approved Conditional Access exclusion group.

This action must not mutate the Conditional Access policy itself.

### Required approved action fields

```text
ActionType = RemoveCAExclusionGroupMember
ObjectId = approved excluded principal object ID
ObjectType = User | Guest | ServicePrincipal | GroupMember
TargetObjectIds = exact ExclusionGroupId values
TargetType = CAExclusionGroup
PolicyId
PolicyDisplayName
ExclusionGroupId
ExclusionGroupDisplayName
ExcludedPrincipalId
```

### WhatIf generation requirements

Generate executable `RemoveCAExclusionGroupMember` only when:

```text
FindingId is DEC-CA-002, DEC-CA-003, or DEC-CA-004.
PolicyId is present.
ExclusionGroupId is present.
ExcludedPrincipalId/ObjectId is present.
TargetObjectIds contains exact ExclusionGroupId.
RemediationMode is ManualApprovalRequired.
```

If exact PolicyId, ExclusionGroupId, or ExcludedPrincipalId is missing:

```text
Do not generate executable action.
Generate plan-only guidance.
```

### Approval validation requirements

```text
ActionType must equal RemoveCAExclusionGroupMember.
FindingId must be DEC-CA-002, DEC-CA-003, or DEC-CA-004.
ObjectId must equal approved ExcludedPrincipalId where applicable.
TargetObjectIds must contain exact ExclusionGroupId.
PolicyId must be present.
ProtectedObject must not be true.
EmergencyAccessIndicator must not be true.
BreakGlassIndicator must not be true.
SchemaVersion must be 3.3 or higher.
Action must not duplicate another approved CA exclusion group removal operation.
```

### Revalidation requirements

Before write:

```text
Read Conditional Access policy by PolicyId using Policy.Read.All.
If policy read fails: block action.
Confirm policy currently excludes ExclusionGroupId.
If policy no longer excludes group: stale/no-op or blocked, but not Executed.
Read group by ExclusionGroupId.
If group read fails: block action.
Read group members.
If read fails: block action.
Confirm ExcludedPrincipalId is current member of ExclusionGroupId.
If principal no longer member: Skipped/no-op.
Read principal if possible.
If principal is ProtectedObject: block.
If principal is emergency access/break-glass: block.
If group/object mismatch: block.
```

### Write operation

Use exact group membership removal:

```powershell
Remove-MgGroupMemberByRef -GroupId <ExclusionGroupId> -DirectoryObjectId <ExcludedPrincipalId>
```

Do not call:

```text
Update-MgIdentityConditionalAccessPolicy
New-MgIdentityConditionalAccessPolicy
Remove-MgIdentityConditionalAccessPolicy
```

Do not request:

```text
Policy.ReadWrite.*
```

### Post-write evidence

```text
Re-query group membership.
Confirm ExcludedPrincipalId no longer member.
Optionally re-query CA policy read-only to confirm policy still excludes group; do not mutate.
If re-query fails: Outcome = PartialFailed or EvidenceUnknown, not Executed.
If principal still member: Outcome = Failed or PartialFailed.
If principal absent: Outcome = Executed.
If principal was absent before write: Outcome = Skipped.
```

---

## 9. EXACT TARGET EXTRACTION AND REGISTRY

Extend or add helper:

```powershell
Get-DecomFindingExactTargetIds
```

For application owner target:

```text
NewOwnerObjectId
NewOwnerObjectIds
TargetObjectId
TargetObjectIds
```

For CA exclusion group target:

```text
ExclusionGroupId
ExclusionGroupIds
TargetGroupId
TargetGroupIds
TargetObjectId
TargetObjectIds
```

For excluded principal:

```text
ExcludedPrincipalId
PrincipalId
ObjectId
```

Rules:

```text
Only return non-empty exact IDs.
Do not return display names.
Do not return policy names.
Do not return group names.
Do not return app names.
Do not return UPN-only values.
Do not broad-query tenant to create executable targets.
If exact ID is missing, return empty and mark action plan-only.
```

Execution scope registry must retain all existing Rev2.x/Rev3.x actions and add:

```text
DEC-APP-001 -> AddApplicationOwner
DEC-APP-002 -> AddApplicationOwner
DEC-APP-003 -> AddApplicationOwner
DEC-SPN-001 -> AddApplicationOwner
DEC-CA-002 -> RemoveCAExclusionGroupMember
DEC-CA-003 -> RemoveCAExclusionGroupMember
DEC-CA-004 -> RemoveCAExclusionGroupMember
```

Deferred/unsafe entries:

```text
RemoveDisabledApplicationOwner -> readiness only
RemoveNonExpiredCredentialAfterRotationEvidence -> readiness only
DisableApplication -> Unsafe/deferred
DisableServicePrincipal -> Unsafe/deferred
ModifyConditionalAccessPolicy -> Unsafe/deferred
ApplyAccessReviewDecision -> Deferred
```

---

## 10. WHATIF, APPROVAL, AND HASH REQUIREMENTS

For `AddApplicationOwner`, WhatIf output must include:

```text
ActionId
FindingId
ActionType
ObjectId
ObjectType
DisplayName
TargetObjectIds
TargetType
NewOwnerObjectId
NewOwnerUserPrincipalName
NewOwnerType
OwnerSource
BusinessJustification
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

For `RemoveCAExclusionGroupMember`, WhatIf output must include:

```text
ActionId
FindingId
ActionType
ObjectId
ObjectType
DisplayName
TargetObjectIds
TargetType
PolicyId
PolicyDisplayName
ExclusionGroupId
ExclusionGroupDisplayName
ExcludedPrincipalId
EmergencyAccessIndicator
BreakGlassIndicator
ReviewEvidenceStatus
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

Approval manifest validation must include:

```text
ActionType allowlist includes AddApplicationOwner and RemoveCAExclusionGroupMember.
FindingId/ActionType consistency checks.
TargetObjectIds required.
No duplicate owner-add target operations.
No duplicate CA exclusion group member operations.
ProtectedObject cannot be approved for execution.
EmergencyAccessIndicator/BreakGlassIndicator cannot be approved for CA exclusion removal.
ApprovedActionsHash includes owner/CA metadata affecting execution.
ApprovalEnvelopeHash includes metadata + ActionsHash.
WhatIfRunId binding preserved.
ExecutionWindow preserved.
AllowNonInteractive preserved.
```

Schema gate:

```text
If ApprovalManifest.SchemaVersion < 3.3, reject Rev3.3 action types.
```

Add to canonical approval hash:

```text
NewOwnerObjectId
NewOwnerUserPrincipalName
NewOwnerType
OwnerSource
BusinessJustification
AllowGuestOwner
PolicyId
PolicyDisplayName
ExclusionGroupId
ExclusionGroupDisplayName
ExcludedPrincipalId
EmergencyAccessIndicator
BreakGlassIndicator
ReviewEvidenceStatus
ReadinessStatus
ReadinessReason
```

---

## 11. REMEDIATION ENGINE REQUIREMENTS

All writes must occur only in `Remediation.psm1`.

### AddApplicationOwner execution flow

```text
1. Validate action type is supported.
2. Confirm ProtectedObject false.
3. Confirm FindingId is allowed.
4. Confirm TargetObjectIds contains NewOwnerObjectId.
5. Confirm ObjectType is Application or ServicePrincipal.
6. Run owner target revalidation.
7. If revalidation fails, log Blocked and continue.
8. If owner already present, log Skipped and continue.
9. Execute exact owner add.
10. Re-query owners.
11. Calculate outcome.
12. Write execution log entry.
13. Write evidence row.
```

### RemoveCAExclusionGroupMember execution flow

```text
1. Validate action type is supported.
2. Confirm ProtectedObject false.
3. Confirm EmergencyAccessIndicator/BreakGlassIndicator false.
4. Confirm FindingId is allowed.
5. Confirm TargetObjectIds contains ExclusionGroupId.
6. Confirm PolicyId and ExcludedPrincipalId present.
7. Run CA exclusion target revalidation.
8. If revalidation fails, log Blocked and continue.
9. If principal already absent, log Skipped and continue.
10. Execute exact group membership removal.
11. Re-query membership.
12. Calculate outcome.
13. Write execution log entry.
14. Write evidence row.
```

### Failure outcome rules

```text
Write failed -> Failed, even if after-state is empty unless write failure can be confidently reconciled.
Re-query failed -> PartialFailed or EvidenceUnknown, not Executed.
Target read failure during revalidation -> Blocked.
New owner read failure -> Blocked.
Owner disabled -> Blocked.
Guest owner without explicit allow -> Blocked.
CA policy read failure -> Blocked.
CA policy no longer excludes group -> Skipped or Blocked, not Executed.
Principal already absent from exclusion group -> Skipped.
ProtectedObject -> Blocked.
Operator declined -> OperatorDeclined.
Out of scope action -> OutOfScope.
```

---

## 12. EXECUTION EVIDENCE SCHEMA EXTENSION

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
BeforeExists
AfterExists
Outcome
ErrorDetail
ApprovedBy
ApprovalManifestHash
ExecutedUtc
GraphWriteCmdlet
PostWriteRequeryStatus
NewOwnerObjectId
NewOwnerUserPrincipalName
NewOwnerType
OwnerSource
OwnerWasAlreadyPresent
OwnerPresentAfter
PolicyId
PolicyDisplayName
ExclusionGroupId
ExclusionGroupDisplayName
ExcludedPrincipalId
ExcludedPrincipalWasMemberBefore
ExcludedPrincipalMemberAfter
EmergencyAccessIndicator
BreakGlassIndicator
ReadinessStatus
```

CSV and JSON exports must include these fields where available.

---

## 13. NEW READ-ONLY MODULE: Rev3CapabilityMatrix.psm1

Create a new read-only module.

Functions:

```powershell
New-DecomRev3CapabilityMatrix
Export-DecomRev3CapabilityMatrixMarkdown
Export-DecomRev3CapabilityMatrixJson
Export-DecomRev34ProductionReadinessMarkdown
Export-DecomRev34ProductionReadinessJson
```

Output files:

```text
rev3-remediation-capability-matrix-*.md
rev3-remediation-capability-matrix-*.json
rev3.4-production-hardening-readiness-*.md
rev3.4-production-hardening-readiness-*.json
```

Capability matrix sections:

```text
Rev2.0 controlled remediation actions
Rev3.0 AP/PIM actions
Rev3.1 guest actions
Rev3.2 credential actions
Rev3.3 owner/CA group actions
Plan-only actions
Deferred actions
Unsafe actions
Required scopes by mode
Rollback model
Post-write evidence model
Unsupported operations
```

---

## 14. GOVERNANCE DELIVERABLES

### Application Owner Remediation Pack

```text
application-owner-remediation-readiness-*.json
application-owner-remediation-readiness-*.csv
application-owner-approval-packet-*.md
application-owner-approval-packet-*.html
application-owner-execution-evidence-*.json
application-owner-execution-evidence-*.csv
application-owner-rollback-guide-*.md
```

### CA Exclusion Remediation Pack

```text
ca-exclusion-remediation-readiness-*.json
ca-exclusion-remediation-readiness-*.csv
ca-exclusion-owner-approval-packet-*.md
ca-exclusion-owner-approval-packet-*.html
ca-exclusion-execution-evidence-*.json
ca-exclusion-execution-evidence-*.csv
ca-exclusion-rollback-guide-*.md
```

### Rev3 Capability and Rev3.4 Readiness Pack

```text
rev3-remediation-capability-matrix-*.md
rev3-remediation-capability-matrix-*.json
rev3.4-production-hardening-readiness-*.md
rev3.4-production-hardening-readiness-*.json
```

---

## 15. DEMO MODE AND SELFTEST

DemoMode must remain no-Graph and no-write.

DemoMode should include synthetic data sufficient to generate:

```text
AddApplicationOwner WhatIf candidate
RemoveCAExclusionGroupMember WhatIf candidate
Application owner remediation pack
CA exclusion remediation pack
Rev3 capability matrix
Rev3.4 production readiness report
```

SelfTest must validate:

```text
Rev3.3 action registry.
No writes outside Remediation.psm1.
Rev3CapabilityMatrix.psm1 is read-only.
Write scopes appear only after Gate A/B in ExecuteRemediation.
Assessment/WhatIf/Demo do not request write scopes.
Unsupported Rev3.3 action types are blocked.
Rev3.2 and earlier approval manifests cannot authorize Rev3.3 actions.
No app deletion cmdlets appear.
No service principal deletion cmdlets appear.
No CA policy write cmdlets appear.
No Policy.ReadWrite.* appears.
```

---

## 16. DOCUMENTATION UPDATES

Add/update:

```text
docs/Required-Permissions.md
docs/Findings-Catalog.md
docs/Schema-Contracts.md
docs/Rev3-Write-Readiness.md
runbooks/ExecuteRemediation-Runbook.md
runbooks/Application-Owner-Remediation-Runbook.md
runbooks/CA-Exclusion-Group-Remediation-Runbook.md
runbooks/Rev3-Capability-Matrix-Runbook.md
README.md
CHANGELOG.md
```

Required permissions note:

```markdown
## Rev3.3 Controlled Application Owner and CA Exclusion Group Remediation

Rev3.3 adds controlled owner assignment and controlled removal from CA exclusion groups.

| ActionType | Permission | Used Only In |
|---|---|---|
| `AddApplicationOwner` | `Application.ReadWrite.All` | ExecuteRemediation after Gate A/B |
| `RemoveCAExclusionGroupMember` | `GroupMember.ReadWrite.All` + `Policy.Read.All` | ExecuteRemediation after Gate A/B |

Rev3.3 does not request `Policy.ReadWrite.*` and does not mutate Conditional Access policies.
```

---

## 17. TEST REQUIREMENTS

Expected Rev3.2 baseline:

```text
>= 566 tests
0 failures
```

Rev3.3 target:

```text
>= 650 tests
Stretch target >= 675
0 failures
```

### Safety tests

```text
1. Assessment mode does not request Policy.ReadWrite.*
2. DemoMode does not request write scopes.
3. WhatIfRemediation does not request write scopes.
4. ExecuteRemediation write scopes still occur only after Gate A/B.
5. Discovery.psm1 contains no write cmdlets.
6. ApplicationGovernance.psm1 contains no write cmdlets.
7. ConditionalAccessGovernance.psm1 contains no write cmdlets.
8. EmergencyAccessGovernance.psm1 contains no write cmdlets.
9. Rev3CapabilityMatrix.psm1 contains no write cmdlets.
10. Rev3.3 action types blocked in Rev3.2 and older manifests.
11. ProtectedObject blocks both Rev3.3 actions.
12. Unknown Rev3.3 action type is OutOfScope or Blocked.
13. No app deletion cmdlets appear.
14. No service principal deletion cmdlets appear.
15. No CA policy write cmdlets appear.
16. No Policy.ReadWrite.* appears.
```

### AddApplicationOwner tests

```text
17. DEC-APP-001 with explicit NewOwnerObjectId generates AddApplicationOwner.
18. DEC-APP-001 without NewOwnerObjectId remains plan-only.
19. DEC-SPN-001 with explicit NewOwnerObjectId generates AddApplicationOwner.
20. Owner is not inferred from DisplayName.
21. Owner is not inferred from app name.
22. Valid AddApplicationOwner passes approval validation.
23. Missing NewOwnerObjectId fails.
24. Missing BusinessJustification fails.
25. Invalid FindingId fails.
26. Duplicate owner-add operation fails.
27. SchemaVersion < 3.3 fails.
28. Hash changes when NewOwnerObjectId changes.
29. Target app read failure blocks.
30. NewOwnerObjectId read failure blocks.
31. Disabled owner blocks.
32. Guest owner blocks unless AllowGuestOwner true.
33. Already-owner logs Skipped.
34. Adds only approved NewOwnerObjectId.
35. Post-write re-query failure does not log Executed.
```

### RemoveCAExclusionGroupMember tests

```text
36. DEC-CA-002 with PolicyId, ExclusionGroupId, and ExcludedPrincipalId generates action.
37. Missing PolicyId remains plan-only.
38. Missing ExclusionGroupId remains plan-only.
39. Missing ExcludedPrincipalId remains plan-only.
40. Valid RemoveCAExclusionGroupMember passes.
41. Invalid FindingId fails.
42. Missing PolicyId fails.
43. Missing ExclusionGroupId fails.
44. ProtectedObject fails.
45. EmergencyAccessIndicator true fails.
46. BreakGlassIndicator true fails.
47. Duplicate CA exclusion operation fails.
48. SchemaVersion < 3.3 fails.
49. CA policy read failure blocks.
50. Policy no longer excludes group logs Skipped or Blocked, not Executed.
51. Group read failure blocks.
52. Group member read failure blocks.
53. Principal not member logs Skipped.
54. Protected principal blocks.
55. Break-glass principal blocks.
56. Removes only approved principal from approved group.
57. Does not mutate CA policy.
58. Post-write re-query failure does not log Executed.
```

### Deliverable tests

```text
59. Application owner remediation readiness JSON exported.
60. Application owner approval packet exported.
61. Application owner rollback guide exported.
62. CA exclusion remediation readiness JSON exported.
63. CA exclusion owner approval packet exported.
64. CA exclusion rollback guide exported.
65. Rev3 capability matrix exported.
66. Rev3.4 production readiness report exported.
```

---

## 18. MILESTONE IMPLEMENTATION PLAN

Implement in milestones.

```text
Milestone 0 — Rev3.2 baseline verification
Milestone 1 — Version + schema plumbing
Milestone 2 — Rev3CapabilityMatrix module
Milestone 3 — Execution scope registry update
Milestone 4 — Owner mapping input / exact target helper
Milestone 5 — WhatIf generation for AddApplicationOwner
Milestone 6 — WhatIf generation for RemoveCAExclusionGroupMember
Milestone 7 — Approval manifest validation
Milestone 8 — AddApplicationOwner revalidation
Milestone 9 — RemoveCAExclusionGroupMember revalidation
Milestone 10 — Execute AddApplicationOwner
Milestone 11 — Execute RemoveCAExclusionGroupMember
Milestone 12 — Post-write evidence
Milestone 13 — Application owner remediation pack
Milestone 14 — CA exclusion remediation pack
Milestone 15 — Rev3 capability matrix and Rev3.4 readiness
Milestone 16 — ReleaseValidation / SelfTest update
Milestone 17 — Documentation and runbooks
Milestone 18 — Demo and WhatIf validation
Milestone 19 — Safety scan
Milestone 20 — Final verification
```

Final verification commands:

```powershell
Invoke-Pester -Path .	ests\Rev11\ -Output Detailed

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode -Mode WhatIfRemediation -GenerateApprovalTemplate

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -SelfTest
```

Safety scan:

```powershell
Select-String -Path .\src\Modules\*.psm1,.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Pattern 'ReadWrite|Remove-Mg|Update-Mg|Set-Mg|New-Mg|Invoke-Mg|Policy.ReadWrite|Update-MgIdentityConditionalAccessPolicy|Remove-MgApplication|Remove-MgServicePrincipal' |
    Format-Table Path,LineNumber,Line -AutoSize
```

---

## 19. CHANGELOG ENTRY

Prepend:

```markdown
## Rev3.3 — Controlled Application Owner and CA Exclusion Group Remediation

### Added
- Controlled remediation action: AddApplicationOwner.
- Controlled remediation action: RemoveCAExclusionGroupMember.
- Application owner remediation readiness and approval packet.
- CA exclusion group remediation readiness and approval packet.
- Application owner rollback guide.
- CA exclusion group rollback guide.
- Rev3 remediation capability matrix.
- Rev3.4 production-hardening readiness report.
- Approval manifest validation for Rev3.3 action types.
- Target revalidation for application/service principal owner assignment.
- Target revalidation for CA exclusion group membership removal.
- Post-write re-query evidence for Rev3.3 actions.

### Safety
- Rev3.3 expands writes only through the existing approved-action pipeline.
- No application deletion.
- No service principal deletion.
- No CA policy mutation.
- No Policy.ReadWrite.* scope.
- Application owners are never inferred.
- CA exclusions are remediated only by removing approved principals from approved exclusion groups.
- Rev3.2 and earlier manifests cannot authorize Rev3.3 actions.

### Tests
- Added Rev3.3 WhatIf, approval manifest, revalidation, execution, evidence, governance pack, capability matrix, and safety tests.
- Target: >= 650 tests, 0 failures.
```

---

## 20. DONE CRITERIA

Rev3.3 is done only when:

```text
1. ToolVersion = Rev3.3.
2. SchemaVersion = 3.3 for current run outputs.
3. AddApplicationOwner implemented only in approved pipeline.
4. RemoveCAExclusionGroupMember implemented only in approved pipeline.
5. WhatIf generation requires exact NewOwnerObjectId for owner actions.
6. WhatIf generation requires exact PolicyId, ExclusionGroupId, ExcludedPrincipalId for CA exclusion action.
7. Approval validation rejects malformed/mismatched Rev3.3 actions.
8. Revalidation blocks Graph read failures.
9. Revalidation blocks disabled owner.
10. Revalidation blocks guest owner unless explicitly allowed.
11. Revalidation blocks CA policy mismatch.
12. Revalidation blocks ProtectedObject / break-glass CA exclusion removal.
13. Post-write evidence is re-queried.
14. Execution evidence includes owner and CA exclusion fields.
15. Rev3CapabilityMatrix.psm1 is read-only.
16. Application owner remediation pack exported.
17. CA exclusion remediation pack exported.
18. Rev3 capability matrix exported.
19. Rev3.4 production-hardening readiness exported.
20. No detector writes.
21. No writes outside Remediation.psm1.
22. No write scopes outside ExecuteRemediation after Gate A/B.
23. Assessment/Demo/WhatIf do not request write scopes.
24. Rev3.2 and earlier approval manifests cannot authorize Rev3.3 actions.
25. No app deletion behavior.
26. No service principal deletion behavior.
27. No CA policy mutation behavior.
28. No Policy.ReadWrite.* scope.
29. >= 650 Pester tests passing, 0 failures.
30. Demo mode clean.
31. WhatIf demo clean.
32. SelfTest clean.
33. Safety scan clean.
34. Required docs/runbooks updated.
```

---

## 21. FINAL STOP RULE

If the external AI coding engine cannot identify exact `NewOwnerObjectId`:

```text
Do not generate executable AddApplicationOwner.
Create plan-only/manual guidance instead.
```

If the external AI coding engine cannot identify exact `PolicyId`, `ExclusionGroupId`, and `ExcludedPrincipalId`:

```text
Do not generate executable RemoveCAExclusionGroupMember.
Create plan-only/manual guidance instead.
```

If any implementation path would mutate a Conditional Access policy:

```text
Fail the build.
Stop immediately.
Ask Albert.
```

If any implementation path would delete an application or service principal:

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

If Rev3.3 becomes too broad:

```text
Stop.
Limit write behavior to AddApplicationOwner and RemoveCAExclusionGroupMember only.
Keep all other actions plan-only/readiness-only.
```
