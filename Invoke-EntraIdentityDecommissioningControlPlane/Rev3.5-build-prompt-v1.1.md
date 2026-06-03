# Rev3.5 Claude Code Build Prompt v1.1
# Entra Identity Decommissioning Control Plane
# NHI / Agentic Identity Audit and Governance Expansion

STATUS: PROPOSED IMPLEMENTATION PROMPT — READ-ONLY NHI / AGENTIC IDENTITY RELEASE

Rev3.5 is a read-only NHI / agentic identity audit and governance expansion release.

Rev3.5 replaces the previously planned "Rev3.4 NHI / Agentic Identity Audit" scope. Rev3.4 is now complete and approved as the production hardening, evidence packaging, redaction, replay validation, traceability, client handoff, and Rev3.5 readiness foundation release.

Therefore Rev3.5 must build on the now-approved Rev3.4 hardening substrate.

Recommended release title:

```text
Rev3.5 — NHI / Agentic Identity Audit and Governance Expansion
```

Primary goal:

```text
Discover, classify, score, and report Entra-visible non-human identities and likely AI-agent / automation identities using a read-only, coverage-aware, claim-safe model.
```

Critical positioning:

```text
This is a heuristic, Entra-visible NHI / agentic identity audit.
It is not a definitive AI-agent registry.
It does not claim all AI agents are discovered.
It does not claim complete NHI inventory across all SaaS, cloud, CI/CD, Power Platform, or runtime systems.
```

---

## 0. BUILD LINEAGE

Rev3.5 builds on:
- Rev2.0 Controlled Remediation Engine
- Rev2.1 Evidence, Preflight, Target Revalidation, and Governance Hardening
- Rev2.2 PIM + Entitlement Management Visibility
- Rev2.3 Access Review Correlation + Governance Proof
- Rev2.4 Baseline, Trend, and Executive Evidence Pack
- Rev2.5 Consultant Release Candidate and Rev3.0 Write-Readiness Gate
- Rev3.0 Controlled Entitlement and PIM Remediation Expansion
- Rev3.1 Controlled Guest Group/App-Role Remediation
- Rev3.2 Controlled Credential Hygiene and Application Governance Expansion
- Rev3.3 Controlled Application Owner and CA Exclusion Group Remediation
- Rev3.4 Production Hardening, Evidence Packaging, Redaction, Replay Validation, Traceability, Client Handoff, and Rev3.5 Readiness Foundation

Rev3.5 uses the prior `EntraNHIAudit` repository as source material for detector concepts, vocabulary, risk patterns, and NHI framing, but must not copy the standalone audit script architecture directly.

Source inspiration:

```text
Repository: albertjee/EntraNHIAudit
Concepts to harvest:
- Service principal inventory
- ServiceIdentity detection
- Agent/automation naming heuristics
- Ownership gap detection
- Credential risk scoring
- Verified publisher and external publisher signals
- App-role assignment enumeration
- OAuth delegated grant enumeration
- Tenant-wide consent scoring
- High-risk Graph scope detection
- Full/Partial coverage tracking
- AI-agent/NHI disclaimer language
```

Important:

```text
Harvest concepts, not architecture.
Do not paste or port standalone script structure directly.
Integrate into the existing modular Rev3.x control-plane architecture.
Use Rev3.4 hardening outputs for manifesting, evidence bundling, redaction, traceability, schema validation, and client handoff.
```

---

## 1. PREREQUISITE BEFORE STARTING

Before implementing Rev3.5, Rev3.4 must be final-QA clean.

Required Rev3.4 prerequisites:

```text
1. Rev3.4 final QA pass completed.
2. Rev3.4 Pester suite passing.
3. Rev3.4 DemoMode clean.
4. Rev3.4 WhatIf demo clean.
5. Rev3.4 SelfTest clean.
6. Rev3.4 safety scan clean.
7. No open P0 or P1 findings from Rev3.4.
8. No new write scopes added by Rev3.4.
9. No new remediation action types added by Rev3.4.
10. OutputManifest works and recursively indexes nested outputs.
11. EvidenceBundle works and recursively includes nested artifacts.
12. Redaction produces actual redacted files.
13. ReplayValidation loads real artifacts and fails when no checks run.
14. ApprovalDiff consumes real WhatIf/Approval actions.
15. Traceability consumes real Finding/WhatIf/Approval/Execution inputs.
16. ClientHandoff package generation works.
17. Rev35Readiness report exists.
```

Rev3.4 final QA PASS confirmed (commit 17da996, 890/890 tests). All prerequisites met. Proceed directly to Milestone 0.5.

If any Rev3.4 P0/P1 remains open:

```text
STOP.
Do not begin Rev3.5.
Ask Albert to close Rev3.4 first.
```

---

## 0.5 HOUSEKEEPING MILESTONE — BEFORE ANY REV3.5 FEATURE WORK

Execute these housekeeping tasks as the first commit before any NHI feature work.
All four items in one commit. Gate 3 must pass before proceeding to Milestone 1.

### 0.5a — Delete legacy test files from tests\ root

Delete these six files (they test old module structures that no longer exist):
```
tests\Decom.Tests.ps1
tests\DecomBatch.Tests.ps1
tests\DecomBatchReporting.Tests.ps1
tests\DecomCoverageGap.Tests.ps1
tests\DecomPremiumRemediation.Tests.ps1
tests\DecomV21.Tests.ps1
```

### 0.5b — Flatten tests\Rev11\ into tests\

Move all files from tests\Rev11\ up to tests\.
Update BeforeAll root path in all moved test files:
  FROM: $root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
  TO:   $root = Split-Path -Parent $PSScriptRoot
Update CLAUDE.md Pester gate command:
  FROM: Invoke-Pester -Path .\\tests\\Rev11\\
  TO:   Invoke-Pester -Path .\\tests\\
Update all build prompts and Pester invocations in entry point to use .\\tests\\

### 0.5c — Fix Redaction PS5.1 -Include issue

In src/Modules/Redaction.psm1, replace:
  Get-ChildItem -Path $RunFolder -File -Include '*.json','*.csv','*.md','*.html'
With:
  Get-ChildItem -Path $RunFolder -File | Where-Object { $_.Extension -in @('.json','.csv','.md','.html') }

### 0.5d — Fix Pester legacy parameter set warnings

Update all test invocations that use legacy Pester 4 parameter syntax to
pure Pester 5 syntax. Remove -Script, -PesterOption, and hash-table
-CodeCoverage from any test invocation that triggers the legacy warning.

### 0.5 verification

```powershell
Invoke-Pester -Path .\tests\ -Output Minimal
# Must show same count as Rev3.4 baseline (890), 0 failures
# Must show 0 legacy parameter set warnings
```

Git diff must show only: 6 deleted files + moved test files + Redaction.psm1 + CLAUDE.md
Commit with message: "chore: Rev3.5 housekeeping — flatten tests, fix PS5.1 redaction, suppress Pester warnings"
Do not push yet. Proceed to Milestone 1.

---

## 0.6 AUTONOMOUS EXECUTION INSTRUCTIONS

Do NOT stop between milestones to ask Albert for confirmation.
Do NOT pause and ask "shall I proceed?" or "ready for go-ahead?" at any milestone boundary.
Do NOT ask Albert to say yes at any step.
Proceed through ALL milestones (0.5, 1 through 26) autonomously.

Only stop and report back to Albert if:
1. A gate FAILS (parse error, import error, test failure, safety scan violation)
2. A new write scope or write cmdlet is detected in an NHI module
3. A claim of "all AI agents discovered" or "definitive AI agent registry" is required
4. A new remediation action type is added
5. OAuth grant collection crashes rather than degrades gracefully
6. The Final Stop Rule triggers

If all gates pass at each milestone — proceed immediately to the next.
Report final gate summary table only when ALL milestones are complete.
Do not push. Albert pushes manually.

---

## 2. CONTEXT

Repository:

```text
https://github.com/albertjee/ajee-iam-premium-library
```

Tool location:

```text
Invoke-EntraIdentityDecommissioningControlPlane/
```

Reference repository:

```text
https://github.com/albertjee/EntraNHIAudit
```

Expected Rev3.4 baseline:

```text
ToolVersion = Rev3.4
Pester tests >= 890
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
No detector writes
No discovery/analysis/reporting writes
No unapproved target writes
No app/SP/user/guest/group deletion
No CA policy mutation
No Policy.ReadWrite.*
OutputManifest clean
EvidenceBundle clean
Redaction clean
ReplayValidation clean
ApprovalDiff clean
Traceability clean
ClientHandoff clean
Rev35Readiness clean
```

Rev3.5 target:

```text
ToolVersion = Rev3.5
Pester tests target >= 1000
Stretch target >= 1050
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
NHI governance pack clean
Agentic identity governance dashboard clean
NHI inventory exports clean
NHI evidence appendix clean
NHI exception register clean
Agentic identity review packet clean
Rev4 NHI write-readiness report clean
OutputManifest includes all NHI outputs
EvidenceBundle includes all NHI outputs
Redaction supports NHI outputs
ClientHandoff includes NHI client-safe package entries
SchemaContracts validate NHI outputs
No new write scopes
No new write cmdlets
No new remediation action types
No write behavior outside pre-existing approved Rev3.x remediation engine
```

---

## 3. CRITICAL SAFETY RULES

Rev3.5 must be read-only.

```text
Rev3.5 must not add new write scopes.
Rev3.5 must not add new remediation action types.
Rev3.5 must not modify the three-gate safety model.
Rev3.5 must not add write operations anywhere.
Rev3.5 must not make tenant modifications.
Rev3.5 must not create rollback execution logic.
Only existing Rev3.x remediation actions remain executable.
```

### Forbidden Graph behavior

No new NHI modules may contain:

```text
Remove-Mg*
Update-Mg*
Set-Mg*
New-Mg*
Invoke-MgGraphRequest with non-GET method
Connect-MgGraph with write scopes
Policy.ReadWrite.*
Directory.ReadWrite.All
Application.ReadWrite.All outside the existing ExecuteRemediation branch
GroupMember.ReadWrite.All outside the existing ExecuteRemediation branch
AppRoleAssignment.ReadWrite.All outside the existing ExecuteRemediation branch
EntitlementManagement.ReadWrite.All outside the existing ExecuteRemediation branch
AccessReview.ReadWrite.All
```

### Forbidden claims

Generated reports must not say:

```text
All AI agents discovered
Definitive AI agent registry
Complete NHI inventory
Guaranteed agent identity
All agentic identities found
```

Generated reports should say:

```text
Entra-visible NHI candidate
Likely AI-agent / automation identity
Heuristic classification
Evidence confidence
Coverage limitation
Risk may be understated due to unavailable evidence
```

---

## 4. REV3.5 RELEASE GOALS

Rev3.5 should add a consultant-grade NHI / agentic identity visibility layer that benefits from the Rev3.4 hardening foundation.

### 4.1 Primary goals

```text
1. Identify Entra-visible NHI candidates.
2. Identify likely AI-agent / automation identities.
3. Classify identities by signal source and confidence.
4. Correlate ownership, credentials, Graph permissions, OAuth grants, app roles, consent posture, publisher posture, and coverage evidence.
5. Produce NHI-specific findings.
6. Produce agentic identity findings.
7. Produce NHI governance dashboard and exports.
8. Produce NHI evidence appendix and exception register.
9. Produce agentic identity review packet.
10. Produce Rev4.0 NHI write-readiness recommendations without implementing new writes.
11. Register all NHI outputs in Rev3.4 OutputManifest.
12. Include all NHI outputs in Rev3.4 EvidenceBundle.
13. Support Rev3.4 redaction for all NHI outputs.
14. Support Rev3.4 client handoff package integration.
15. Validate all NHI output schemas through Rev3.4 SchemaContracts.
```

### 4.2 Consultant questions Rev3.5 should answer

```text
Which service principals look like NHI / automation / agentic identities?
Which NHI have no owner?
Which NHI have only one owner?
Which NHI have stale, expired, or long-lived credentials?
Which NHI have high-risk Graph application permissions?
Which NHI have delegated OAuth grants?
Which NHI have tenant-wide AllPrincipals grants?
Which NHI are verified publisher gaps or external publisher risks?
Which NHI look like AI agents by ServiceIdentity or naming pattern?
Which NHI are covered by evidence vs partial evidence?
Which NHI should be remediated using existing Rev3.x actions?
Which NHI require future Rev4.0 detectors/data sources?
Which findings are evidence-backed vs inference-backed?
Which outputs are safe for client handoff?
```

---

## 5. REV3.5 SCOPE

### 5.1 Read-only detectors

Add NHI and agentic identity detectors only.

New finding families:

```text
DEC-NHI-*
DEC-AGENT-*
```

No new write actions.

### 5.2 New read-only modules

Preferred new modules:

```text
src/Modules/NhiDiscovery.psm1
src/Modules/NhiAnalysis.psm1
src/Modules/NhiGovernance.psm1
src/Modules/NhiReporting.psm1
```

Alternative if project style strongly prefers fewer files:

```text
src/Modules/NhiGovernance.psm1
```

But the modular split is preferred because this is a large release.

### 5.3 Existing modules that may be extended

```text
Invoke-EntraIdentityDecommissioningControlPlane.ps1       # ToolVersion, params, imports, output integration only
src/Modules/Discovery.psm1                                # read-only NHI collection hooks only
src/Modules/Analysis.psm1                                 # NHI correlation/scoring only
src/Modules/Reporting.psm1                                # report section hooks only
src/Modules/ExecutivePack.psm1                            # NHI summary section only
src/Modules/ReleaseValidation.psm1                        # update read-only safety invariants
src/Modules/SchemaContracts.psm1                          # update NHI output schemas
src/Modules/WriteReadiness.psm1                           # Rev4.0 NHI readiness
src/Modules/OutputManifest.psm1                           # include NHI output categories only
src/Modules/EvidenceBundle.psm1                           # include NHI output categories only
src/Modules/Redaction.psm1                                # verify NHI redaction coverage only
src/Modules/ClientHandoff.psm1                            # include NHI client package section only
```

### 5.4 Explicitly out of scope

```text
No new remediation action types.
No new write scopes.
No Graph write cmdlets.
No agent deletion.
No app deletion.
No service principal deletion.
No credential deletion beyond existing Rev3.2 action.
No owner mutation beyond existing Rev3.3 action.
No CA policy mutation.
No user/guest deletion.
No access review decision application.
No Power Platform write action.
No GitHub write action.
No SaaS write action.
No automatic claim that all AI agents are discovered.
No runtime token-chain proof beyond available Entra-visible evidence.
```

---

## 6. VERSIONING REQUIREMENTS

Entry point must update:

```powershell
$script:ToolVersion = 'Rev3.5'
```

Schema versions:

```text
Assessment JSON SchemaVersion = 3.5
Run manifest SchemaVersion = 3.5
NHI inventory SchemaVersion = 3.5
NHI governance dashboard SchemaVersion = 3.5
NHI executive summary SchemaVersion = 3.5
NHI evidence appendix SchemaVersion = 3.5
NHI exception register SchemaVersion = 3.5
Agentic identity review packet SchemaVersion = 3.5
Rev4 NHI write-readiness report SchemaVersion = 3.5
Release validation report SchemaVersion = 3.5
Output manifest SchemaVersion = 3.5 where generated in current run
Evidence bundle manifest SchemaVersion = 3.5 where generated in current run
Client handoff manifest SchemaVersion = 3.5 where generated in current run
```

Do not leave stale Rev3.4 labels in current-version NHI outputs.

Historical docs/changelog may retain old version labels.

---

## 7. GRAPH PERMISSIONS

Rev3.5 should be read-only.

### 7.1 Existing read scopes

Use existing read scopes where possible:

```text
Application.Read.All
Directory.Read.All
AuditLog.Read.All
RoleManagement.Read.Directory
Policy.Read.All
```

### 7.2 Optional read-only scope review

If OAuth/delegated grant enumeration requires additional read-only permissions, document them and use least privilege only.

Allowed only if required and validated as read-only:

```text
DelegatedPermissionGrant.Read.All
AppRoleAssignment.ReadWrite.All is NOT allowed in read mode
```

Important:
The project previously avoided or removed some permissions in earlier NHI tooling. Do not add `DelegatedPermissionGrant.Read.All` casually. If required, implement as optional coverage mode:

```text
If scope unavailable:
CoverageMode = Partial
RiskScoreMayBeUnderstated = true
Emit DEC-NHI-011
Continue without crash
```

### 7.3 Forbidden write permissions

Do not add:

```text
Application.ReadWrite.All as a new read-mode scope
Directory.ReadWrite.All
Policy.ReadWrite.*
User.ReadWrite.All
GroupMember.ReadWrite.All outside ExecuteRemediation
AppRoleAssignment.ReadWrite.All outside ExecuteRemediation
EntitlementManagement.ReadWrite.All outside ExecuteRemediation
AccessReview.ReadWrite.All
```

### 7.4 Scope sequencing

Assessment/Demo/WhatIf/SelfTest must remain read-only unless running the pre-existing ExecuteRemediation path.

Rev3.5 NHI features must not require write-scope connection.

---

## 8. NHI CLASSIFICATION MODEL

Create a classification model for service principals and applications.

### 8.1 Classification output fields

```text
ObjectId
AppId
ServicePrincipalId
ApplicationObjectId
DisplayName
ObjectType
ServicePrincipalType
PublisherName
VerifiedPublisherName
SignInAudience
AccountEnabled
CreatedDateTime
Tags
Homepage
AppOwnerOrganizationId
NhiCandidate
AgenticCandidate
AutomationCandidate
WorkloadCandidate
Classification
ClassificationConfidence
ClassificationSignals
ClassificationScore
RiskScore
Severity
CoverageMode
CoverageLimitations
RiskScoreMayBeUnderstated
EvidenceSource
EvidenceConfidence
```

### 8.2 Classification values

```text
NativeServiceIdentity
LikelyAIAgent
LikelyAutomation
LikelyWorkloadIdentity
LikelyServiceAccount
ThirdPartyOAuthApp
MicrosoftFirstPartyApp
UnclassifiedServicePrincipal
UnclassifiedApplication
```

### 8.3 Confidence values

```text
High
Medium
Low
Unknown
```

### 8.4 Signal sources

```text
ServicePrincipalType = ServiceIdentity
Name pattern match
Tag pattern match
Publisher pattern
Verified publisher missing/present
Credential-bearing app
Graph app-role assignment
OAuth delegated grant
Tenant-wide consent
High-risk Graph permission
Owner gap
App role assignment volume
Credential age/expiry
External publisher
Microsoft first-party publisher
```

### 8.5 First-party Microsoft handling

Avoid noisy or misleading findings for Microsoft-owned first-party service principals.

Rules:

```text
Classify Microsoft first-party apps separately.
Do not treat Microsoft first-party app ownership gaps the same as customer-owned app ownership gaps.
Do not recommend customer remediation for Microsoft-owned first-party service principals.
Flag first-party Microsoft objects as inventory/context unless there is a customer-controlled artifact attached.
```

Required field:

```text
FirstPartyMicrosoftApp = true|false|unknown
```

---

## 9. AGENT / AUTOMATION DETECTION HEURISTICS

Harvest and normalize concepts from `EntraNHIAudit`.

### 9.1 Native signal

High-confidence signal:

```text
servicePrincipalType eq 'ServiceIdentity'
```

Finding:

```text
DEC-AGENT-001 — Native ServiceIdentity service principal detected
```

### 9.2 Separator-bounded name pattern detection

Use separator-bounded matching to reduce false positives.

Suggested patterns:

```text
agent
aiagent
copilot
bot
automation
automate
workflow
orchestrator
orchestration
svc
service
daemon
worker
runner
connector
logicapp
function
foundry
openai
azureai
azure-ai
gpt
llm
ml
mlops
pipeline
sync
scheduler
job
```

Do not match arbitrary substrings without separators.

Examples that should match:

```text
agent-prod
copilot_connector
svc-payroll-sync
workflow-runner
azureai-orchestrator
```

Examples that should not match:

```text
management
contingent
agency
serviceable
```

### 9.3 Signal scoring

Suggested classification scoring:

```text
ServiceIdentity = +50
agent/copilot/openai/azureai/foundry/llm/gpt pattern = +35
automation/workflow/orchestrator/runner/bot pattern = +25
svc/service/daemon/worker/sync/scheduler/job pattern = +15
Credential-bearing app = +10
High-risk Graph permission = +15
Tenant-wide consent = +15
No owner = +15
Single owner = +8
Verified publisher missing = +8
External publisher = +10
OAuth delegated grant present = +8
```

Confidence bands:

```text
High >= 50
Medium >= 30
Low >= 15
Unknown < 15
```

This is separate from risk scoring. Keep classification confidence separate from risk severity.

---

## 10. HIGH-RISK PERMISSION MODEL

Add a configurable high-risk Graph permission map.

### 10.1 Default high-risk application permissions

Include at minimum:

```text
Directory.ReadWrite.All
Application.ReadWrite.All
AppRoleAssignment.ReadWrite.All
RoleManagement.ReadWrite.Directory
PrivilegedAccess.ReadWrite.AzureAD
Group.ReadWrite.All
User.ReadWrite.All
Mail.ReadWrite
Mail.Send
Files.ReadWrite.All
Sites.FullControl.All
AuditLog.Read.All
Policy.ReadWrite.*
EntitlementManagement.ReadWrite.All
```

### 10.2 Default high-risk delegated scopes

```text
Directory.AccessAsUser.All
Directory.ReadWrite.All
Application.ReadWrite.All
AppRoleAssignment.ReadWrite.All
User.ReadWrite.All
Group.ReadWrite.All
Mail.ReadWrite
Mail.Send
Files.ReadWrite.All
Sites.FullControl.All
offline_access
```

### 10.3 Output fields

```text
PermissionId
PermissionValue
PermissionType
ResourceAppId
ResourceDisplayName
RiskTier
RiskReason
ConsentType
PrincipalId
PrincipalDisplayName
```

Important:

```text
Do not request write scopes to inspect high-risk write permissions.
Detect permission grants read-only from available Graph metadata.
```

---

## 11. OAUTH / CONSENT CORRELATION

Harvest EntraNHIAudit concepts around OAuth grants and tenant-wide consent.

### 11.1 OAuth grant fields

```text
ClientId
ClientDisplayName
ConsentType
PrincipalId
PrincipalDisplayName
ResourceId
ResourceDisplayName
Scope
HighRiskScopeCount
HighRiskScopes
AllPrincipalsConsent
GrantCoverageMode
```

### 11.2 Findings to emit

```text
DEC-NHI-008 for high-risk delegated OAuth grants
DEC-NHI-009 for AllPrincipals tenant-wide consent
DEC-AGENT-005 when agent-like identity has tenant-wide consent
```

### 11.3 Graceful degradation

If OAuth grant enumeration fails:

```text
CoverageMode = Partial
RiskScoreMayBeUnderstated = true
Emit DEC-NHI-011 coverage finding
Do not crash
```

---

## 12. CREDENTIAL / OWNER / PERMISSION CORRELATION

Correlate NHI classification with existing credential, ownership, permission, consent, publisher, and app-role evidence.

### 12.1 Required correlations

```text
NHI + no owner
NHI + single owner
NHI + disabled owner
NHI + expired credential
NHI + expiring credential
NHI + no verified publisher
NHI + external publisher
NHI + high-risk app permission
NHI + high-risk OAuth grant
NHI + tenant-wide consent
NHI + app-role assignment volume
Agent-like + no owner
Agent-like + high-risk permission
Agent-like + expired credential
Agent-like + tenant-wide consent
```

### 12.2 Existing action reuse

Do not create new write actions.

If existing actions apply, set `RemediationMode` appropriately:

```text
AddApplicationOwner for ownership gaps
RemoveExpiredApplicationCredential for expired credentials with exact KeyId
RevokeAppRoleAssignment only where existing exact-target logic applies
```

Otherwise:

```text
InformationOnly
PlanOnly
```

Existing-action reuse means:

```text
The finding may be mapped as a candidate to an existing action type.
It must not introduce any new action type.
It must still require WhatIf -> ApprovalManifest -> ExecuteRemediation.
It must still require exact target IDs.
```

---

## 13. COVERAGE MODEL

Add explicit NHI coverage model.

### 13.1 Coverage dimensions

```text
ServicePrincipalInventoryCollected
ApplicationInventoryCollected
OwnerEvidenceCollected
CredentialEvidenceCollected
AppRoleAssignmentEvidenceCollected
OAuthGrantEvidenceCollected
PublisherEvidenceCollected
SignInEvidenceCollected
AgentIdentityEvidenceCollected
HighRiskPermissionEvidenceCollected
```

### 13.2 Coverage values

```text
Full
Partial
Unavailable
NotLicensed
PermissionDenied
NotImplemented
```

### 13.3 Coverage output

```text
CoverageMode
CoverageReasons
RiskScoreMayBeUnderstated
PermissionEvidenceCollected
OAuthEvidenceCollected
AgentEvidenceCollected
```

If a collection path fails, continue and emit coverage limitation finding.

---

## 14. NEW FINDING FAMILY: DEC-NHI-*

Add these finding IDs.

```text
DEC-NHI-001 — Entra-visible NHI candidate detected
Severity: Informational
RiskScore: 15
Category: NHI Inventory
RemediationMode: InformationOnly

DEC-NHI-002 — NHI has no owner
Severity: High
RiskScore: 62
Category: NHI Ownership
RemediationMode: ManualApprovalRequired if existing AddApplicationOwner can apply; otherwise InformationOnly

DEC-NHI-003 — NHI has only one owner
Severity: Medium
RiskScore: 44
Category: NHI Ownership
RemediationMode: ManualApprovalRequired if existing AddApplicationOwner can apply; otherwise InformationOnly

DEC-NHI-004 — NHI owned by disabled identity
Severity: High
RiskScore: 68
Category: NHI Ownership
RemediationMode: ManualApprovalRequired if existing AddApplicationOwner can apply; otherwise InformationOnly

DEC-NHI-005 — NHI credential expired or stale
Severity: High
RiskScore: 70
Category: NHI Credential Hygiene
RemediationMode: ManualApprovalRequired if exact KeyId exists and existing RemoveExpiredApplicationCredential can apply

DEC-NHI-006 — NHI credential expiring soon
Severity: Medium
RiskScore: 50
Category: NHI Credential Hygiene
RemediationMode: InformationOnly / PlanOnly

DEC-NHI-007 — NHI has high-risk Graph application permission
Severity: High
RiskScore: 72
Category: NHI Permission Risk
RemediationMode: InformationOnly

DEC-NHI-008 — NHI has high-risk delegated OAuth grant
Severity: High
RiskScore: 74
Category: NHI OAuth Grant Risk
RemediationMode: InformationOnly

DEC-NHI-009 — NHI has tenant-wide AllPrincipals consent
Severity: Critical
RiskScore: 85
Category: NHI Consent Risk
RemediationMode: InformationOnly

DEC-NHI-010 — NHI publisher verification gap
Severity: Medium
RiskScore: 45
Category: NHI Publisher Risk
RemediationMode: InformationOnly

DEC-NHI-011 — NHI coverage partial or incomplete
Severity: Informational
RiskScore: 20
Category: NHI Coverage
RemediationMode: InformationOnly

DEC-NHI-012 — NHI has app-role assignments but no owner accountability
Severity: High
RiskScore: 70
Category: NHI Permission Ownership Correlation
RemediationMode: ManualApprovalRequired if existing AddApplicationOwner can apply
```

---

## 15. NEW FINDING FAMILY: DEC-AGENT-*

Add these finding IDs.

```text
DEC-AGENT-001 — Native agent/service identity detected
Severity: Informational
RiskScore: 20
Category: Agentic Identity Inventory
RemediationMode: InformationOnly

DEC-AGENT-002 — Likely AI-agent identity detected by naming pattern
Severity: Informational
RiskScore: 20
Category: Agentic Identity Inventory
RemediationMode: InformationOnly

DEC-AGENT-003 — Agent-like identity has no owner
Severity: High
RiskScore: 68
Category: Agent Ownership
RemediationMode: ManualApprovalRequired if existing AddApplicationOwner can apply

DEC-AGENT-004 — Agent-like identity has high-risk Graph permission
Severity: High
RiskScore: 76
Category: Agent Permission Risk
RemediationMode: InformationOnly

DEC-AGENT-005 — Agent-like identity has tenant-wide consent
Severity: Critical
RiskScore: 88
Category: Agent Consent Risk
RemediationMode: InformationOnly

DEC-AGENT-006 — Agent-like identity has credential risk
Severity: High
RiskScore: 72
Category: Agent Credential Risk
RemediationMode: ManualApprovalRequired if exact expired KeyId exists and existing action applies

DEC-AGENT-007 — Agentic identity governance evidence missing
Severity: Medium
RiskScore: 52
Category: Agent Governance Evidence
RemediationMode: InformationOnly
```

---

## 16. NHI GOVERNANCE DELIVERABLES

### 16.1 NHI inventory exports

```text
nhi-inventory-*.csv
nhi-inventory-*.json
```

Required fields:

```text
ObjectId
AppId
DisplayName
ObjectType
ServicePrincipalType
Classification
ClassificationConfidence
ClassificationSignals
ClassificationScore
NhiCandidate
AgenticCandidate
AutomationCandidate
OwnerCount
CredentialCount
ExpiredCredentialCount
ExpiringCredentialCount
HighRiskPermissionCount
HighRiskOAuthGrantCount
TenantWideConsent
VerifiedPublisherName
PublisherName
FirstPartyMicrosoftApp
RiskScore
Severity
CoverageMode
RiskScoreMayBeUnderstated
RecommendedAction
SafeForClient
```

### 16.2 NHI governance dashboard

```text
nhi-governance-dashboard-*.html
```

Sections:

```text
At-a-glance NHI summary
Likely AI-agent identities
ServiceIdentity identities
Ownership gaps
Credential hygiene
High-risk Graph permissions
OAuth delegated grants
Tenant-wide consent
Publisher verification gaps
Coverage limitations
Remediation candidates using existing actions
Recommended next steps
Claim-safety disclaimer
```

### 16.3 NHI executive summary

```text
nhi-executive-summary-*.md
nhi-executive-summary-*.html
```

Tone:

```text
Executive, consultant-grade, not alarmist.
Avoid unsupported claims.
Clearly distinguish evidence from inference.
```

### 16.4 NHI evidence appendix

```text
nhi-evidence-appendix-*.md
```

Sections:

```text
Methodology
Classification signals
Pattern matching rules
Permission risk model
OAuth grant model
Coverage limitations
False-positive handling
Manual validation checklist
Claim-safety language
```

### 16.5 NHI exception register

```text
nhi-exception-register-*.csv
```

Fields:

```text
ExceptionId
ObjectId
DisplayName
Classification
FindingId
Reason
BusinessOwner
TechnicalOwner
ExpirationDate
ReviewCadence
Status
Notes
```

### 16.6 Agentic identity review packet

```text
agentic-identity-review-packet-*.md
agentic-identity-review-packet-*.html
```

Sections:

```text
Likely agentic identities
Native ServiceIdentity identities
Pattern-matched agent candidates
High-risk agent permissions
Agent ownership gaps
Agent credential risks
Recommended owner review workflow
Manual validation checklist
Claim-safety disclaimer
```

### 16.7 Rev4 NHI write-readiness report

```text
rev4-nhi-write-readiness-report-*.md
rev4-nhi-write-readiness-report-*.json
```

Candidate future actions:

```text
AddNhiOwner
RemoveNhiExpiredCredential
RemoveNhiHighRiskOAuthGrant
RevokeNhiAppRoleAssignment
RemoveTenantWideConsent
DisableUnsafeNhi
QuarantineAgenticIdentity
```

Recommended status values:

```text
ReadyViaExistingAction
NeedsDesign
Unsafe
Deferred
ExternalSystemRequired
```

Default recommendation:

```text
ReadyForRev4Design, not ReadyForRev4Implementation
```

---

## 17. REV3.4 HARDENING INTEGRATION REQUIREMENTS

Rev3.5 must integrate with the Rev3.4 hardening substrate.

### 17.1 OutputManifest integration

All Rev3.5 NHI outputs must appear in `output-manifest-*.json`.

NHI categories to add:

```text
NhiInventory
NhiGovernance
NhiDashboard
NhiExecutiveSummary
NhiEvidenceAppendix
NhiExceptionRegister
AgenticIdentityReview
Rev4NhiReadiness
```

Each file must include:

```text
Sha256
Sensitivity
ContainsSensitiveData
SafeForClient
Category
Description
```

### 17.2 EvidenceBundle integration

Evidence bundle must include NHI outputs when generated.

Required bundle sections:

```text
NHI inventory
NHI findings
NHI dashboard
Agentic identity review packet
NHI evidence appendix
NHI coverage limitations
Rev4 NHI write-readiness report
```

### 17.3 Redaction integration

Rev3.5 NHI outputs must be redaction-safe.

Redaction tests must prove:

```text
TenantId redacted
ObjectId redacted
AppId redacted
ServicePrincipalId redacted
UserPrincipalName redacted
Email redacted
JSON remains valid
CSV headers preserved
HTML structure preserved
Markdown tables preserved
```

### 17.4 ClientHandoff integration

Client handoff package must include NHI section.

Client handoff should prefer redacted NHI outputs when `-GenerateRedactedPackage` is used.

### 17.5 Traceability integration

NHI findings should be traceable to existing action candidates where applicable.

Trace examples:

```text
DEC-NHI-002 -> existing AddApplicationOwner candidate if exact NewOwnerObjectId exists
DEC-NHI-005 -> existing RemoveExpiredApplicationCredential candidate if exact KeyId exists
DEC-AGENT-003 -> existing AddApplicationOwner candidate if exact NewOwnerObjectId exists
```

### 17.6 SchemaContracts integration

Add schema validation for:

```text
NhiInventory
NhiGovernanceDashboard
NhiExecutiveSummary
NhiExceptionRegister
AgenticIdentityReviewPacket
Rev4NhiWriteReadiness
NhiCoverageModel
```

---

## 18. DEMO MODE REQUIREMENTS

DemoMode must remain no-Graph and no-write.

DemoMode should include synthetic data sufficient to generate:

```text
Native ServiceIdentity example
Likely AI agent by name pattern
Automation identity by name pattern
NHI with no owner
NHI with expired credential
NHI with high-risk Graph application permission
NHI with high-risk delegated OAuth grant
NHI with tenant-wide consent
NHI coverage partial finding
NHI dashboard
Agentic identity review packet
NHI evidence appendix
Rev4 NHI write-readiness report
OutputManifest containing NHI outputs
EvidenceBundle containing NHI outputs
Redacted NHI package if GenerateRedactedPackage is enabled
ClientHandoff NHI section
```

DemoMode must not request write scopes or call remediation writes.

---

## 19. SELFTEST / RELEASE VALIDATION UPDATE

SelfTest must validate:

```text
Rev3.5 NHI modules are read-only.
No new write scopes are added.
No new remediation action types are added.
No writes outside Remediation.psm1.
Assessment/WhatIf/Demo do not request write scopes.
NHI finding catalog entries exist.
DEC-NHI and DEC-AGENT IDs are unique.
NHI schema contracts validate.
NHI demo outputs generate.
NHI outputs appear in OutputManifest.
NHI outputs appear in EvidenceBundle.
NHI outputs are redaction-safe.
NHI outputs can be included in ClientHandoff.
No "definitive AI agent registry" claim appears in generated reports.
No "all AI agents discovered" claim appears in generated reports.
Coverage model emits Partial when collection fails.
```

---

## 20. DOCUMENTATION UPDATES

Add/update:

```text
docs/NHI-Agentic-Identity-Governance.md
docs/NHI-Finding-Catalog.md
docs/NHI-Coverage-Model.md
docs/Schema-Contracts.md
docs/Findings-Catalog.md
docs/Rev4-NHI-Write-Readiness.md
runbooks/NHI-Agentic-Identity-Audit-Runbook.md
runbooks/NHI-Exception-Review-Runbook.md
README.md
CHANGELOG.md
```

### Required README note

```markdown
## Rev3.5 NHI / Agentic Identity Audit

Rev3.5 adds read-only NHI and agentic identity governance.

It identifies Entra-visible non-human identity candidates and likely AI-agent / automation identities using:
- service principal metadata
- ServiceIdentity signals
- separator-bounded naming patterns
- ownership evidence
- credential evidence
- Graph application permissions
- OAuth delegated grants
- tenant-wide consent
- publisher verification
- coverage confidence

Rev3.5 is heuristic. It is not a definitive registry of all AI agents.
```

---

## 21. TEST REQUIREMENTS

Expected Rev3.4 baseline:

```text
>= 890 tests
0 failures
```

Rev3.5 target:

```text
>= 1000 tests
Stretch target >= 1050
0 failures
```

### 21.1 Safety tests

```text
1. Rev3.5 adds no new write scopes.
2. Rev3.5 adds no new remediation action types.
3. NhiDiscovery.psm1 contains no write cmdlets.
4. NhiAnalysis.psm1 contains no write cmdlets.
5. NhiGovernance.psm1 contains no write cmdlets.
6. NhiReporting.psm1 contains no write cmdlets.
7. Assessment mode remains read-only.
8. DemoMode remains read-only.
9. WhatIfRemediation remains read-only.
10. No Policy.ReadWrite.* appears.
11. No Directory.ReadWrite.All appears.
12. No app/SP/user/guest deletion cmdlets appear.
```

### 21.2 Classification tests

```text
13. ServiceIdentity classified as NativeServiceIdentity with High confidence.
14. agent/copilot/openai/azureai/foundry patterns classify as likely AI agent.
15. automation/workflow/orchestrator/bot patterns classify as likely automation.
16. svc/service/runner/sync patterns classify as likely workload identity.
17. separator-bounded matching avoids management/agency/serviceable false positives.
18. ClassificationConfidence is separate from risk severity.
19. Multiple signals increase confidence.
20. Unmatched SP remains UnclassifiedServicePrincipal.
21. Microsoft first-party apps are classified separately.
22. Microsoft first-party apps do not get customer remediation recommendations by default.
```

### 21.3 Finding tests

```text
23. DEC-NHI-001 emitted for NHI candidate.
24. DEC-NHI-002 emitted for NHI with no owner.
25. DEC-NHI-005 emitted for NHI expired credential.
26. DEC-NHI-007 emitted for high-risk app permission.
27. DEC-NHI-008 emitted for high-risk OAuth grant.
28. DEC-NHI-009 emitted for AllPrincipals consent.
29. DEC-AGENT-001 emitted for ServiceIdentity.
30. DEC-AGENT-002 emitted for agent pattern match.
31. DEC-AGENT-004 emitted for agent with high-risk Graph permission.
32. DEC-AGENT-005 emitted for agent with tenant-wide consent.
```

### 21.4 Coverage tests

```text
33. OAuth grant failure emits Partial coverage.
34. App role assignment failure emits Partial coverage.
35. Owner lookup failure emits Partial coverage.
36. Coverage limitations appear in dashboard.
37. RiskScoreMayBeUnderstated true when permission evidence missing.
```

### 21.5 Output tests

```text
38. NHI inventory CSV exported.
39. NHI inventory JSON exported.
40. NHI governance dashboard exported.
41. NHI executive summary MD exported.
42. NHI executive summary HTML exported.
43. NHI evidence appendix exported.
44. NHI exception register exported.
45. Agentic identity review packet MD exported.
46. Agentic identity review packet HTML exported.
47. Rev4 NHI write-readiness JSON exported.
48. Rev4 NHI write-readiness MD exported.
```

### 21.6 Rev3.4 hardening integration tests

```text
49. OutputManifest includes NHI inventory.
50. OutputManifest includes NHI dashboard.
51. EvidenceBundle includes NHI outputs.
52. Redaction redacts ObjectId/AppId in NHI JSON.
53. Redaction preserves NHI CSV headers.
54. ClientHandoff includes NHI section.
55. SchemaContracts validates NHI inventory.
56. Traceability maps NHI finding to existing action candidate where applicable.
```

### 21.7 Claim safety tests

```text
57. Reports do not claim all AI agents discovered.
58. Reports do not claim definitive AI agent registry.
59. Reports include heuristic/coverage disclaimer.
60. Reports distinguish evidence from inference.
61. Reports state Entra-visible scope limitation.
```

---

## 22. MILESTONE IMPLEMENTATION PLAN

Implement in milestones.

```text
Milestone 0 — Rev3.4 baseline verification
Milestone 1 — Version + schema plumbing
Milestone 2 — NHI module skeletons
Milestone 3 — NHI classification model
Milestone 4 — Agent/automation pattern matcher
Milestone 5 — Microsoft first-party classification guard
Milestone 6 — High-risk permission map
Milestone 7 — OAuth grant correlation model
Milestone 8 — Ownership/credential correlation model
Milestone 9 — Coverage model
Milestone 10 — DEC-NHI finding generation
Milestone 11 — DEC-AGENT finding generation
Milestone 12 — Existing-action reuse mapping
Milestone 13 — NHI inventory CSV/JSON exports
Milestone 14 — NHI governance dashboard
Milestone 15 — NHI executive summary
Milestone 16 — NHI evidence appendix
Milestone 17 — NHI exception register
Milestone 18 — Agentic identity review packet
Milestone 19 — Rev4 NHI write-readiness report
Milestone 20 — Rev3.4 OutputManifest / EvidenceBundle integration
Milestone 21 — Rev3.4 Redaction / ClientHandoff integration
Milestone 22 — Demo data and demo outputs
Milestone 23 — SelfTest / ReleaseValidation update
Milestone 24 — Documentation and runbooks
Milestone 25 — Safety scan
Milestone 26 — Final verification
```

Final verification commands:

```powershell
Invoke-Pester -Path .\tests\Rev11\ -Output Detailed

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode -Mode WhatIfRemediation -GenerateApprovalTemplate

pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -SelfTest
```

Safety scan:

```powershell
Select-String -Path .\src\Modules\*.psm1,.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Pattern 'ReadWrite|Remove-Mg|Update-Mg|Set-Mg|New-Mg|Invoke-Mg|Policy.ReadWrite|Directory.ReadWrite|Remove-MgApplication|Remove-MgServicePrincipal|Remove-MgUser' |
    Format-Table Path,LineNumber,Line -AutoSize
```

Expected:

```text
No new write scopes.
No new remediation action types.
No write cmdlets in NHI modules.
No app/SP/user/guest deletion.
No Policy.ReadWrite.*.
All NHI outputs generated.
All NHI outputs appear in OutputManifest and EvidenceBundle.
All NHI outputs are redaction-safe.
```

---

## 23. CHANGELOG ENTRY

Prepend:

```markdown
## Rev3.5 — NHI / Agentic Identity Audit and Governance Expansion

### Added
- Read-only NHI / agentic identity classification model.
- Native ServiceIdentity detection.
- Agent/automation/service-account naming-pattern detection.
- Microsoft first-party service principal classification guard.
- NHI ownership, credential, permission, OAuth, consent, and publisher correlation.
- DEC-NHI finding family.
- DEC-AGENT finding family.
- NHI governance dashboard.
- NHI inventory CSV/JSON exports.
- NHI executive summary.
- NHI evidence appendix.
- NHI exception register.
- Agentic identity review packet.
- Rev4 NHI write-readiness report.
- NHI coverage model.
- Rev3.4 OutputManifest/EvidenceBundle/Redaction/ClientHandoff integration for NHI outputs.

### Safety
- Rev3.5 is read-only.
- No new write scopes.
- No new remediation action types.
- No tenant modification behavior.
- Reports use heuristic classification language and avoid claiming definitive AI agent inventory.

### Tests
- Added Rev3.5 NHI classification, finding, coverage, output, hardening-integration, and claim-safety tests.
- Target: >= 1000 tests, 0 failures.
```

---

## 24. README UPDATE

Add:

```markdown
## Rev3.5 NHI / Agentic Identity Audit

Rev3.5 adds read-only NHI and agentic identity governance.

It identifies Entra-visible non-human identity candidates and likely AI-agent / automation identities using:
- service principal metadata
- ServiceIdentity signals
- separator-bounded naming patterns
- ownership evidence
- credential evidence
- Graph application permissions
- OAuth delegated grants
- tenant-wide consent
- publisher verification
- first-party Microsoft classification guard
- coverage confidence

Rev3.5 is heuristic. It is not a definitive registry of all AI agents.
```

---

## 25. DONE CRITERIA

Rev3.5 is done only when:

```text
1. ToolVersion = Rev3.5.
2. SchemaVersion = 3.5 for current run outputs.
3. NHI classification model implemented.
4. Agent/automation pattern matching implemented with false-positive controls.
5. Microsoft first-party classification guard implemented.
6. DEC-NHI finding family implemented.
7. DEC-AGENT finding family implemented.
8. High-risk permission model implemented.
9. OAuth grant correlation implemented or gracefully degraded.
10. Coverage model implemented.
11. Existing-action reuse mapping implemented without new write actions.
12. NHI inventory CSV/JSON exported.
13. NHI governance dashboard exported.
14. NHI executive summary exported.
15. NHI evidence appendix exported.
16. NHI exception register exported.
17. Agentic identity review packet exported.
18. Rev4 NHI write-readiness report exported.
19. NHI outputs appear in OutputManifest.
20. NHI outputs appear in EvidenceBundle.
21. NHI outputs are redaction-safe.
22. ClientHandoff includes NHI section.
23. No new write scopes.
24. No new remediation action types.
25. No NHI module writes.
26. No detector writes.
27. No app/SP/user/guest deletion behavior.
28. No Policy.ReadWrite.*.
29. Reports include heuristic/coverage disclaimer.
30. Reports do not claim all AI agents discovered.
31. Reports do not claim definitive AI-agent registry.
32. >= 1000 Pester tests passing, 0 failures.
33. Demo mode clean.
34. WhatIf demo clean.
35. SelfTest clean.
36. Safety scan clean.
37. Required docs/runbooks updated.
```

---

## 26. FINAL STOP RULE

If the external AI coding engine attempts to add new write actions:

```text
Fail the build.
Stop immediately.
Ask Albert.
```

If the external AI coding engine attempts to add write scopes:

```text
Fail the build.
Stop immediately.
Ask Albert.
```

If the external AI coding engine attempts to claim complete AI-agent inventory:

```text
Fail the build.
Use heuristic / Entra-visible / coverage-limited language.
```

If the external AI coding engine cannot collect OAuth grants or app-role assignments:

```text
Do not crash.
Mark coverage partial.
Emit DEC-NHI-011.
Continue.
```

If Rev3.5 becomes too broad:

```text
Stop.
Keep Rev3.5 read-only.
Keep write expansion for Rev4.x design only.
```
