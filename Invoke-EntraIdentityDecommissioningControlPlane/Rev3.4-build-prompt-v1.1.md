# Rev3.4 Claude Code Build Prompt v1.1
# Entra Identity Decommissioning Control Plane
# Production Hardening, Evidence Packaging, and Client Deployment Foundation

STATUS: PROPOSED IMPLEMENTATION PROMPT — HARDENING / FOUNDATION RELEASE

Rev3.4 is a hardening, packaging, evidence-integrity, and client-deployment foundation release.

Rev3.4 deliberately does not add new tenant write actions.

Rev3.4 deliberately does not implement the NHI / agentic identity audit expansion. That scope is deferred to Rev3.5 and should be treated as the next read-only visibility expansion after Rev3.4 hardens the product foundation.

Recommended release title:

```text
Rev3.4 — Production Hardening, Evidence Packaging, and Client Deployment Foundation
```

Rev3.4 builds on:
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

CRITICAL SAFETY RULE:
Rev3.4 must not add new write scopes.
Rev3.4 must not add new remediation action types.
Rev3.4 must not add new Graph write operations.
Rev3.4 must not modify the three-gate safety model except to validate, document, package, and verify it more rigorously.
Rev3.4 must not change the semantics of existing remediation actions.
Rev3.4 must harden the tool for consultant delivery, client evidence handoff, audit replay, redaction, and future Rev3.5 NHI expansion.

MAIN THEME:

```text
Rev3.4 = make the product safe, portable, reviewable, reproducible, and client-ready.
Rev3.5 = add NHI / agentic identity audit visibility.
```

---

## 0. PREREQUISITE BEFORE STARTING

Before implementing Rev3.4, Rev3.3 must be final-QA clean.

Required Rev3.3 prerequisites:

```text
1. Rev3.3 final QA pass completed.
2. Rev3.3 Pester suite passing.
3. Rev3.3 DemoMode clean.
4. Rev3.3 WhatIf demo clean.
5. Rev3.3 SelfTest clean.
6. Rev3.3 safety scan clean.
7. No open P0 or P1 findings from Rev3.3.
8. No writes outside Remediation.psm1.
9. No app deletion behavior.
10. No service principal deletion behavior.
11. No CA policy mutation behavior.
12. No Policy.ReadWrite.* scope.
13. AddApplicationOwner outcome logic is add-oriented and evidence-correct.
14. CA exclusion exact-target binding is enforced.
```

Rev3.3 final QA PASS confirmed (commit d3a747c, 740/740 tests). All prerequisites met. Proceed directly to Milestone 1.

If any Rev3.3 P0/P1 remains open:

```text
STOP.
Do not begin Rev3.4.
Ask Albert to close Rev3.3 first.
```

---

## 0.5 AUTONOMOUS EXECUTION INSTRUCTIONS

Do NOT stop between milestones to ask Albert for confirmation.
Do NOT pause and ask "shall I proceed?" or "ready for go-ahead?" at any milestone boundary.
Do NOT ask Albert to say yes at any step.
Proceed through ALL milestones (0 through 17) autonomously.

Only stop and report back to Albert if:
1. A gate FAILS (parse error, import error, test failure, safety scan violation)
2. A new write scope or write cmdlet is detected in a hardening module
3. NHI/agentic identity detector implementation is attempted
4. DEC-NHI-* or DEC-AGENT-* findings are emitted
5. A new remediation action type is added
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

Expected Rev3.3 baseline:

```text
ToolVersion = Rev3.3
Pester tests >= 740
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
No detector writes
No discovery/analysis/reporting writes
No unapproved target writes
No app/SP deletion
No CA policy mutation
No Policy.ReadWrite.*
```

Rev3.4 target:

```text
ToolVersion = Rev3.4
Pester tests target >= 825
Stretch target >= 850
0 failures
Demo mode clean
WhatIf demo clean
SelfTest clean
Release package clean
Evidence bundle clean
Redaction mode clean
Replay validator clean
Approval diff clean
Traceability report clean
Client handoff package clean
Rev3.5 readiness report clean
No new write scopes
No new remediation action types
No new Graph write operations
No change to existing remediation semantics
```

---

## 2. REV3.4 RELEASE GOALS

Rev3.4 should turn the tool from a powerful engineering asset into a consultant-deliverable product.

### 2.1 Primary goals

```text
1. Harden release packaging.
2. Create client-safe evidence bundles.
3. Add redaction / sanitized export mode.
4. Add approval manifest diff viewer.
5. Add WhatIf-to-Approval-to-Execution traceability.
6. Add pre/post state evidence bundle.
7. Add replay validator for execution logs.
8. Add output manifest index.
9. Add evidence integrity hash manifest.
10. Add operator runbook pack.
11. Add failure recovery guide.
12. Add client handoff package generator.
13. Add demo/sample package generator.
14. Add schema and output contract validation.
15. Add Rev3.5 NHI readiness foundation without implementing NHI detectors yet.
```

### 2.2 Consultant questions Rev3.4 should answer

```text
What did the tool find?
What did it propose?
What did the client approve?
What changed in the tenant?
What was skipped, blocked, failed, or partially failed?
What evidence proves the result?
Which files were generated?
Which files are safe to share with the client?
Which files contain sensitive data?
Can the run be replayed from saved evidence?
Can another engineer validate the chain of custody?
Can the release be packaged cleanly for a client engagement?
Is the codebase ready for Rev3.5 NHI / agentic identity expansion?
```

---

## 3. REV3.4 SCOPE

### 3.1 In scope

```text
Evidence packaging
Client-safe redaction
Run replay validation
Approval manifest diffing
Traceability reporting
Output manifest indexing
Evidence hash manifest
Release package hardening
Operator runbooks
Failure recovery guide
Client handoff package
Demo package
Sample sanitized outputs
Schema/output contract validation
Rev3.5 NHI readiness hooks
```

### 3.2 Explicitly out of scope

```text
No new remediation action types.
No new write scopes.
No new Graph write operations.
No new tenant mutation behavior.
No NHI / agentic identity detectors.
No DEC-NHI-* findings.
No DEC-AGENT-* findings.
No AI-agent classification model.
No OAuth/consent correlation expansion.
No app deletion.
No service principal deletion.
No user/guest deletion.
No CA policy mutation.
No Policy.ReadWrite.*.
No AccessReview.ReadWrite.*.
No remediation rollback execution.
No automatic undo writes.
```

Rev3.4 may create rollback guidance and rollback packages, but it must not execute rollback writes.

---

## 4. SAFETY MODEL — MUST REMAIN INTACT

Rev3.4 must preserve the existing safety model.

### 4.1 Safety constraints

```text
No new writes.
No new write scopes.
No new remediation action types.
No new ExecuteRemediation action behavior.
Existing remediation actions must continue to behave exactly as Rev3.3.
All new modules must be read-only.
```

### 4.2 Safety scan expectations

No new hardening modules may contain:

```text
Remove-Mg*
Update-Mg*
Set-Mg*
New-Mg*
Invoke-MgGraphRequest with non-GET method
Connect-MgGraph with write scopes
Policy.ReadWrite.*
Directory.ReadWrite.All
User.ReadWrite.All
AccessReview.ReadWrite.All
Remove-MgApplication
Remove-MgServicePrincipal
Remove-MgUser
Remove-MgGroup
```

### 4.3 Rev3.5 positioning safety

Rev3.4 may mention Rev3.5 NHI readiness, but must not implement NHI classification/detectors.

Allowed wording:

```text
Rev3.5-ready schema extension point
NHI output placeholder
Future DEC-NHI and DEC-AGENT reserved namespace
Read-only detector pack registration pattern
```

Forbidden wording:

```text
NHI implemented
Agentic identity audit implemented
All AI agents discovered
Definitive AI agent registry
Complete NHI inventory
```

---

## 5. FILES TO MODIFY

Allowed files:

```text
Invoke-EntraIdentityDecommissioningControlPlane.ps1       # ToolVersion, parameters, module import only
src/Modules/ReleasePackaging.psm1                         # harden release/client package generator
src/Modules/ReleaseValidation.psm1                        # hardening validation
src/Modules/SchemaContracts.psm1                          # output contract validation
src/Modules/WriteReadiness.psm1                           # Rev3.5 readiness report
src/Modules/Reporting.psm1                                # optional links/sections only
src/Modules/ExecutivePack.psm1                            # optional client package index only
src/Modules/OutputManifest.psm1                           # NEW
src/Modules/EvidenceBundle.psm1                           # NEW
src/Modules/Redaction.psm1                                # NEW
src/Modules/ReplayValidation.psm1                         # NEW
src/Modules/ApprovalDiff.psm1                             # NEW
src/Modules/Traceability.psm1                             # NEW
src/Modules/ClientHandoff.psm1                            # NEW
src/Modules/Rev35Readiness.psm1                           # NEW
tests/Rev11/Safety.Rev34.Tests.ps1                        # NEW
tests/Rev11/OutputManifest.Rev34.Tests.ps1                # NEW
tests/Rev11/EvidenceBundle.Rev34.Tests.ps1                # NEW
tests/Rev11/Redaction.Rev34.Tests.ps1                     # NEW
tests/Rev11/ReplayValidation.Rev34.Tests.ps1              # NEW
tests/Rev11/ApprovalDiff.Rev34.Tests.ps1                  # NEW
tests/Rev11/Traceability.Rev34.Tests.ps1                  # NEW
tests/Rev11/ClientHandoff.Rev34.Tests.ps1                 # NEW
tests/Rev11/Rev35Readiness.Rev34.Tests.ps1                # NEW
tests/Rev11/ReleaseValidation.Rev34.Tests.ps1             # NEW
docs/Client-Handoff-Package.md                            # NEW
docs/Evidence-Bundle-Model.md                             # NEW
docs/Redaction-Model.md                                   # NEW
docs/Replay-Validation-Model.md                           # NEW
docs/Traceability-Model.md                                # NEW
docs/Rev3.5-NHI-Readiness.md                              # NEW
docs/Schema-Contracts.md                                  # update
docs/Findings-Catalog.md                                  # update only if version refs needed
runbooks/Operator-Execution-Runbook.md                    # NEW
runbooks/Failure-Recovery-Runbook.md                      # NEW
runbooks/Client-Handoff-Runbook.md                        # NEW
runbooks/Redaction-Review-Runbook.md                      # NEW
runbooks/Replay-Validation-Runbook.md                     # NEW
CHANGELOG.md
README.md
```

Forbidden unless Albert explicitly approves:

```text
src/Modules/Remediation.psm1                              # no changes expected
src/Modules/ApprovalManifest.psm1                         # no changes expected except optional non-behavioral schema display
src/Modules/ExecutionLog.psm1                             # no behavior changes expected
src/Modules/Discovery.psm1                                # no new detectors
src/Modules/Analysis.psm1                                 # no scoring changes
src/Modules/Nhi*.psm1                                     # do not create NHI modules in Rev3.4
```

---

## 6. VERSIONING REQUIREMENTS

Entry point must update:

```powershell
$script:ToolVersion = 'Rev3.4'
```

Schema versions:

```text
Assessment JSON SchemaVersion = 3.4
Run manifest SchemaVersion = 3.4
Output manifest SchemaVersion = 3.4
Evidence bundle manifest SchemaVersion = 3.4
Redaction report SchemaVersion = 3.4
Replay validation report SchemaVersion = 3.4
Approval diff report SchemaVersion = 3.4
Traceability report SchemaVersion = 3.4
Client handoff manifest SchemaVersion = 3.4
Rev3.5 readiness report SchemaVersion = 3.4
Release validation report SchemaVersion = 3.4
```

Do not leave stale Rev3.3 labels in current-version outputs.

Historical docs/changelog may retain old version labels.

---

## 7. GRAPH PERMISSIONS

Rev3.4 should add no new Graph permissions.

### 7.1 Existing read/write behavior

Existing Rev3.x write scopes remain available only in the existing ExecuteRemediation branch after Gate A and Gate B.

Rev3.4 hardening features must not request Graph write scopes.

### 7.2 Forbidden permission changes

Do not add:

```text
Policy.ReadWrite.*
Directory.ReadWrite.All
User.ReadWrite.All
Application.ReadWrite.All outside existing ExecuteRemediation branch
GroupMember.ReadWrite.All outside existing ExecuteRemediation branch
AppRoleAssignment.ReadWrite.All outside existing ExecuteRemediation branch
EntitlementManagement.ReadWrite.All outside existing ExecuteRemediation branch
AccessReview.ReadWrite.All
```

---

## 8. NEW MODULE: OutputManifest.psm1

Purpose:

```text
Create a machine-readable index of every output generated by a run.
```

Functions:

```powershell
New-DecomOutputManifest
Add-DecomOutputManifestItem
Export-DecomOutputManifestJson
Export-DecomOutputManifestCsv
Test-DecomOutputManifest
```

Output files:

```text
output-manifest-*.json
output-manifest-*.csv
```

Required manifest fields:

```text
SchemaVersion
ToolVersion
RunId
GeneratedUtc
EngagementId
ClientName
OutputRoot
Files[]
Summary
```

Per-file fields:

```text
FileId
FileName
RelativePath
FullPath
FileType
Category
Sensitivity
ContainsSensitiveData
SafeForClient
GeneratedUtc
SizeBytes
Sha256
SourceStage
RelatedRunId
RelatedWhatIfRunId
RelatedApprovalManifestHash
RelatedExecutionManifestHash
Description
```

Allowed sensitivity values:

```text
Public
ClientSafe
Confidential
Restricted
ContainsIdentifiers
ContainsTenantData
ContainsExecutionEvidence
```

Required categories:

```text
Assessment
Findings
Report
RemediationPlan
WhatIf
ApprovalTemplate
ExecutionEvidence
ExecutionReport
Baseline
ExecutivePack
ReleaseValidation
SchemaContracts
ClientHandoff
Redacted
Demo
Rev35Readiness
```

Rules:

```text
Every generated file should appear in the output manifest.
Every file should have SHA-256 hash.
Missing files should be detected.
Duplicate manifest entries should fail validation.
```

---

## 9. NEW MODULE: EvidenceBundle.psm1

Purpose:

```text
Package assessment, WhatIf, approval, execution, reports, manifests, and hashes into a reproducible evidence bundle.
```

Functions:

```powershell
New-DecomEvidenceBundle
Export-DecomEvidenceBundleManifestJson
Export-DecomEvidenceBundleIndexMarkdown
Export-DecomEvidenceHashManifest
Test-DecomEvidenceBundle
```

Output files:

```text
evidence-bundle-manifest-*.json
evidence-bundle-index-*.md
evidence-hash-manifest-*.json
evidence-hash-manifest-*.csv
```

Evidence bundle sections:

```text
Run identity
Assessment outputs
Findings outputs
WhatIf plan
Approval template / approval manifest
Execution logs
Execution evidence
Post-remediation reports
Baseline comparison
Executive pack
Release validation
Schema contracts
Output manifest
Hash manifest
Known limitations
```

Evidence bundle manifest fields:

```text
SchemaVersion
ToolVersion
RunId
BundleId
GeneratedUtc
SourceOutputPath
BundleOutputPath
FileCount
TotalBytes
Sha256ManifestHash
Files[]
Limitations
```

Important:

```text
Do not zip by default unless existing packaging pattern already supports it safely.
Prefer folder-based package plus manifest.
If zip is added, keep folder package too.
```

---

## 10. NEW MODULE: Redaction.psm1

Purpose:

```text
Create client-safe redacted copies of selected outputs.
```

Functions:

```powershell
New-DecomRedactionProfile
Invoke-DecomRedaction
Export-DecomRedactionReportJson
Export-DecomRedactionReportMarkdown
Test-DecomRedactedOutput
```

Output files:

```text
redaction-report-*.json
redaction-report-*.md
redacted-output-manifest-*.json
```

Default redaction rules:

```text
TenantId -> [REDACTED_TENANT_ID]
ObjectId GUIDs -> [REDACTED_OBJECT_ID_n]
AppId GUIDs -> [REDACTED_APP_ID_n]
UserPrincipalName -> [REDACTED_UPN_n]
Email addresses -> [REDACTED_EMAIL_n]
DisplayName -> optional preserve or redact depending profile
ClientName -> optional preserve or redact depending profile
RunId -> preserve by default unless strict mode
Approval hashes -> preserve by default
SHA-256 file hashes -> preserve by default
```

Redaction profiles:

```text
ClientSafe
PublicDemo
Strict
Internal
```

Rules:

```text
Redaction must be deterministic within a package.
Same source value should map to same redacted token.
Never redact severity/risk fields.
Never corrupt JSON structure.
Never corrupt CSV columns.
Never corrupt Markdown tables.
Never corrupt HTML basic rendering.
```

---

## 11. NEW MODULE: ReplayValidation.psm1

Purpose:

```text
Validate that an execution can be replayed from saved WhatIf, Approval, ExecutionLog, ExecutionEvidence, and manifest files without connecting to Graph.
```

Functions:

```powershell
Invoke-DecomReplayValidation
Test-DecomWhatIfApprovalBinding
Test-DecomApprovalExecutionBinding
Test-DecomExecutionEvidenceConsistency
Export-DecomReplayValidationReportJson
Export-DecomReplayValidationReportMarkdown
```

Output files:

```text
replay-validation-report-*.json
replay-validation-report-*.md
```

Validation checks:

```text
WhatIfRunId matches approval manifest.
ApprovalEnvelopeHash matches execution evidence.
ApprovedActionsHash matches approved action list.
Every executed ActionId exists in approval manifest.
No unapproved ActionId appears in execution evidence.
Every TargetObjectId in execution evidence was approved.
Every Failed/PartialFailed/Blocked action has ErrorDetail.
Every Executed action has post-write evidence.
Skipped actions do not claim tenant write.
ExecutionWindow was valid at execution time when present.
ProtectedObject actions are blocked, not executed.
```

No Graph connection allowed.

---

## 12. NEW MODULE: ApprovalDiff.psm1

Purpose:

```text
Compare WhatIf action plan and ApprovalManifest to show what was approved, rejected, changed, or omitted.
```

Functions:

```powershell
Compare-DecomWhatIfToApproval
Export-DecomApprovalDiffJson
Export-DecomApprovalDiffMarkdown
Export-DecomApprovalDiffHtml
```

Output files:

```text
approval-diff-*.json
approval-diff-*.md
approval-diff-*.html
```

Diff categories:

```text
ApprovedUnchanged
ApprovedModified
RejectedOrOmitted
ApprovalOnlyNotInWhatIf
HashChanged
TargetChanged
ActionTypeChanged
RiskChanged
ProtectedObjectAttempted
```

Rules:

```text
ApprovalOnlyNotInWhatIf is a hard validation failure for execution.
TargetChanged should be flagged as high risk.
ProtectedObjectAttempted should be high risk.
Diff output must be client-readable.
```

---

## 13. NEW MODULE: Traceability.psm1

Purpose:

```text
Create an end-to-end trace from Finding -> WhatIf Action -> Approval Action -> Execution Evidence -> Post-write State.
```

Functions:

```powershell
New-DecomTraceabilityModel
Export-DecomTraceabilityReportJson
Export-DecomTraceabilityReportCsv
Export-DecomTraceabilityReportHtml
Export-DecomTraceabilityReportMarkdown
```

Output files:

```text
traceability-report-*.json
traceability-report-*.csv
traceability-report-*.html
traceability-report-*.md
```

Trace row fields:

```text
FindingId
FindingInstanceId
Severity
RiskScore
ObjectId
DisplayName
ActionId
ActionType
TargetObjectIds
WhatIfRunId
ApprovalStatus
ApprovedBy
ApprovalTicket
ApprovalManifestHash
ExecutionOutcome
ExecutedUtc
GraphWriteCmdlet
PostWriteRequeryStatus
EvidenceFile
RollbackGuidance
TraceStatus
TraceGapReason
```

Trace statuses:

```text
FindingOnly
WhatIfGenerated
Approved
Rejected
Executed
Skipped
Blocked
Failed
PartialFailed
EvidenceMissing
TraceGap
```

---

## 14. NEW MODULE: ClientHandoff.psm1

Purpose:

```text
Generate a consultant-ready client handoff package.
```

Functions:

```powershell
New-DecomClientHandoffPackage
Export-DecomClientHandoffManifestJson
Export-DecomClientHandoffIndexMarkdown
Export-DecomClientHandoffChecklistMarkdown
```

Output files:

```text
client-handoff-manifest-*.json
client-handoff-index-*.md
client-handoff-checklist-*.md
```

Client handoff sections:

```text
Executive summary
Assessment reports
Findings exports
Remediation plan
WhatIf / approval evidence
Execution evidence
Traceability report
Replay validation report
Redacted client-safe outputs
Exception registers
Runbooks
Known limitations
Next-step recommendations
Rev3.5 readiness note
```

Rules:

```text
Client handoff package must mark sensitive files clearly.
Client handoff package must prefer redacted outputs when available.
Client handoff package must include a validation status.
Client handoff package must not include raw secrets.
Client handoff package must not include token values.
```

---

## 15. NEW MODULE: Rev35Readiness.psm1

Purpose:

```text
Prepare the codebase and output model for Rev3.5 NHI / Agentic Identity Audit and Governance Expansion without implementing it.
```

Functions:

```powershell
New-DecomRev35ReadinessReport
Export-DecomRev35ReadinessJson
Export-DecomRev35ReadinessMarkdown
Test-DecomRev35Readiness
```

Output files:

```text
rev3.5-nhi-readiness-report-*.json
rev3.5-nhi-readiness-report-*.md
```

Readiness checks:

```text
Output manifest supports future NHI outputs.
Schema contracts can register future DEC-NHI-* and DEC-AGENT-* families.
Finding catalog has reserved namespace note.
Dashboard/reporting can link future NHI dashboards.
Redaction supports service principal/app IDs.
Coverage model placeholder exists.
Claim-safety validator placeholder exists.
Rev3.5 prompt reference documented.
```

Important:

```text
Do not implement NHI detectors in Rev3.4.
Do not emit DEC-NHI-* or DEC-AGENT-* findings in Rev3.4.
Do not create NhiDiscovery.psm1 or NhiAnalysis.psm1 in Rev3.4 unless it is an empty placeholder explicitly marked not implemented.
Preferred: do not create NHI modules until Rev3.5.
```

---

## 16. RELEASE PACKAGE HARDENING

Enhance existing ReleasePackaging.psm1.

Required improvements:

```text
Include output manifest.
Include evidence bundle manifest.
Include hash manifest.
Include replay validation report.
Include traceability report.
Include redaction report when generated.
Include client handoff index.
Include Rev3.5 readiness report.
Fail package generation if required hardening artifacts are missing.
```

Required package sections:

```text
release/
evidence/
redacted/
reports/
runbooks/
docs/
validation/
schemas/
handoff/
demo/
```

Package manifest must include:

```text
PackageId
ToolVersion
GeneratedUtc
SourceRunId
FileCount
TotalBytes
Sha256ManifestHash
RequiredArtifactsPresent
MissingRequiredArtifacts
Warnings
```

---

## 17. SCHEMA / CONTRACT VALIDATION

Enhance SchemaContracts.psm1 to validate Rev3.4 output contracts.

New schemas:

```text
OutputManifest
EvidenceBundleManifest
EvidenceHashManifest
RedactionReport
ReplayValidationReport
ApprovalDiffReport
TraceabilityReport
ClientHandoffManifest
Rev35ReadinessReport
```

Validation requirements:

```text
Required fields present.
SchemaVersion correct.
ToolVersion correct.
RunId present when applicable.
File references exist when applicable.
Hash fields present where required.
No malformed JSON.
CSV headers match schema.
```

---

## 18. OPERATOR EXPERIENCE

Add or document optional parameters if implementation style supports them:

```powershell
-GenerateEvidenceBundle
-GenerateRedactedPackage
-RedactionProfile ClientSafe|PublicDemo|Strict|Internal
-GenerateReplayValidation
-GenerateApprovalDiff
-GenerateTraceabilityReport
-GenerateClientHandoff
-GenerateRev35Readiness
```

Rules:

```text
Default behavior should remain backward-compatible.
If flags are absent, existing assessment/remediation flow must still work.
DemoMode should support generating sample hardening outputs.
SelfTest should validate all new hardening modules without Graph.
```

---

## 19. DEMO MODE REQUIREMENTS

DemoMode must remain no-Graph and no-write.

DemoMode should be able to generate sample:

```text
output-manifest
evidence-bundle-manifest
evidence-hash-manifest
redaction-report
approval-diff
traceability-report
replay-validation-report
client-handoff-index
rev3.5-nhi-readiness-report
```

DemoMode must not request write scopes or call remediation writes.

---

## 20. SELFTEST / RELEASE VALIDATION UPDATE

SelfTest must validate:

```text
Rev3.4 modules are read-only.
No new write scopes are added.
No new remediation action types are added.
No writes outside Remediation.psm1.
Assessment/WhatIf/Demo do not request write scopes.
Output manifest schema validates.
Evidence bundle schema validates.
Redaction report schema validates.
Replay validation schema validates.
Traceability report schema validates.
Client handoff manifest schema validates.
Rev3.5 readiness report schema validates.
No NHI detectors implemented in Rev3.4.
No DEC-NHI-* or DEC-AGENT-* findings emitted in Rev3.4.
```

---

## 21. DOCUMENTATION UPDATES

Add/update:

```text
docs/Client-Handoff-Package.md
docs/Evidence-Bundle-Model.md
docs/Redaction-Model.md
docs/Replay-Validation-Model.md
docs/Traceability-Model.md
docs/Rev3.5-NHI-Readiness.md
docs/Schema-Contracts.md
README.md
CHANGELOG.md
```

Add runbooks:

```text
runbooks/Operator-Execution-Runbook.md
runbooks/Failure-Recovery-Runbook.md
runbooks/Client-Handoff-Runbook.md
runbooks/Redaction-Review-Runbook.md
runbooks/Replay-Validation-Runbook.md
```

Required README note:

```markdown
## Rev3.4 Production Hardening

Rev3.4 adds client delivery hardening:
- evidence bundle
- redaction mode
- replay validation
- approval diff
- traceability report
- client handoff package
- output manifest
- evidence hash manifest
- Rev3.5 NHI readiness report

Rev3.4 does not add new write actions, write scopes, or NHI detectors.
```

---

## 22. TEST REQUIREMENTS

Expected Rev3.3 baseline:

```text
>= 740 tests
0 failures
```

Rev3.4 target:

```text
>= 825 tests
Stretch target >= 850
0 failures
```

### 22.1 Safety tests

```text
1. Rev3.4 adds no new write scopes.
2. Rev3.4 adds no new remediation action types.
3. OutputManifest.psm1 contains no write cmdlets.
4. EvidenceBundle.psm1 contains no write cmdlets.
5. Redaction.psm1 contains no write cmdlets.
6. ReplayValidation.psm1 contains no write cmdlets.
7. ApprovalDiff.psm1 contains no write cmdlets.
8. Traceability.psm1 contains no write cmdlets.
9. ClientHandoff.psm1 contains no write cmdlets.
10. Rev35Readiness.psm1 contains no write cmdlets.
11. Assessment mode remains read-only.
12. DemoMode remains read-only.
13. WhatIfRemediation remains read-only.
14. No Policy.ReadWrite.* appears.
15. No Directory.ReadWrite.All appears.
16. No app/SP/user/guest deletion cmdlets appear.
17. No DEC-NHI-* findings emitted.
18. No DEC-AGENT-* findings emitted.
```

### 22.2 Output manifest tests

```text
19. Output manifest JSON exported.
20. Output manifest CSV exported.
21. Every listed file has SHA-256 hash.
22. Missing listed file fails validation.
23. Duplicate manifest entry fails validation.
24. Sensitivity classification present.
25. SafeForClient flag present.
```

### 22.3 Evidence bundle tests

```text
26. Evidence bundle manifest exported.
27. Evidence hash manifest exported.
28. Evidence bundle includes WhatIf/Approval/Execution when present.
29. Evidence bundle detects missing required evidence.
30. Evidence bundle index Markdown exported.
```

### 22.4 Redaction tests

```text
31. TenantId redacted.
32. ObjectId redacted deterministically.
33. UPN/email redacted.
34. Same source value maps to same redacted token.
35. JSON remains valid after redaction.
36. CSV headers preserved after redaction.
37. Markdown tables preserved after redaction.
38. HTML basic structure preserved after redaction.
39. Hashes preserved unless strict mode specifies otherwise.
```

### 22.5 Replay validation tests

```text
40. WhatIfRunId binding validated.
41. Approval hash binding validated.
42. Execution action must exist in approval.
43. Unapproved execution action fails validation.
44. TargetObjectIds must match approval.
45. Executed action requires post-write evidence.
46. Blocked action requires ErrorDetail.
47. Skipped action does not claim write.
```

### 22.6 Approval diff tests

```text
48. ApprovedUnchanged detected.
49. ApprovedModified detected.
50. RejectedOrOmitted detected.
51. ApprovalOnlyNotInWhatIf detected.
52. TargetChanged detected.
53. ProtectedObjectAttempted detected.
54. Approval diff Markdown exported.
55. Approval diff HTML exported.
```

### 22.7 Traceability tests

```text
56. FindingOnly trace status generated.
57. WhatIfGenerated trace status generated.
58. Approved trace status generated.
59. Executed trace status generated.
60. Skipped trace status generated.
61. Blocked trace status generated.
62. EvidenceMissing trace gap generated.
63. Traceability CSV exported.
64. Traceability HTML exported.
```

### 22.8 Client handoff tests

```text
65. Client handoff manifest exported.
66. Client handoff index exported.
67. Client handoff checklist exported.
68. Sensitive files marked.
69. Redacted files preferred when available.
70. Missing validation report creates warning.
```

### 22.9 Rev3.5 readiness tests

```text
71. Rev3.5 readiness JSON exported.
72. Rev3.5 readiness Markdown exported.
73. Reserved DEC-NHI namespace documented.
74. Reserved DEC-AGENT namespace documented.
75. No NHI detectors implemented.
76. NHI claim-safety placeholder present.
77. Coverage model placeholder present.
```

---

## 23. MILESTONE IMPLEMENTATION PLAN

Implement in milestones.

```text
Milestone 0 — Rev3.3 baseline verification
Milestone 1 — Version + schema plumbing
Milestone 2 — OutputManifest module
Milestone 3 — EvidenceBundle module
Milestone 4 — Redaction module
Milestone 5 — ReplayValidation module
Milestone 6 — ApprovalDiff module
Milestone 7 — Traceability module
Milestone 8 — ClientHandoff module
Milestone 9 — Rev35Readiness module
Milestone 10 — ReleasePackaging hardening
Milestone 11 — SchemaContracts hardening
Milestone 12 — Operator parameters / entry point integration
Milestone 13 — Demo hardening outputs
Milestone 14 — SelfTest / ReleaseValidation update
Milestone 15 — Documentation and runbooks
Milestone 16 — Safety scan
Milestone 17 — Final verification
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
    -Pattern 'ReadWrite|Remove-Mg|Update-Mg|Set-Mg|New-Mg|Invoke-Mg|Policy.ReadWrite|Directory.ReadWrite|Remove-MgApplication|Remove-MgServicePrincipal|Remove-MgUser|Remove-MgGroup' |
    Format-Table Path,LineNumber,Line -AutoSize
```

Expected:

```text
No new write scopes.
No new remediation action types.
No write cmdlets in Rev3.4 hardening modules.
No app/SP/user/guest/group deletion.
No Policy.ReadWrite.*.
No DEC-NHI-* or DEC-AGENT-* findings emitted.
All hardening outputs generated.
```

---

## 24. CHANGELOG ENTRY

Prepend:

```markdown
## Rev3.4 — Production Hardening, Evidence Packaging, and Client Deployment Foundation

### Added
- Output manifest JSON/CSV.
- Evidence bundle manifest and evidence hash manifest.
- Client-safe redaction profiles.
- Replay validation report.
- Approval diff report.
- End-to-end traceability report.
- Client handoff package.
- Operator runbook pack.
- Failure recovery guide.
- Rev3.5 NHI readiness report.
- Schema contract validation for hardening outputs.

### Safety
- Rev3.4 adds no new write scopes.
- Rev3.4 adds no new remediation action types.
- Rev3.4 adds no new tenant modification behavior.
- Existing Rev3.x remediation actions are unchanged.
- Rev3.4 does not implement NHI / agentic identity detectors.

### Tests
- Added Rev3.4 output manifest, evidence bundle, redaction, replay validation, approval diff, traceability, client handoff, Rev3.5 readiness, and safety tests.
- Target: >= 825 tests, 0 failures.
```

---

## 25. README UPDATE

Add:

```markdown
## Rev3.4 Production Hardening

Rev3.4 adds client delivery hardening:
- output manifest
- evidence bundle
- evidence hash manifest
- redaction profiles
- replay validation
- approval diff
- traceability report
- client handoff package
- Rev3.5 NHI readiness report

Rev3.4 does not add new write actions, write scopes, or NHI detectors.
```

---

## 26. DONE CRITERIA

Rev3.4 is done only when:

```text
1. ToolVersion = Rev3.4.
2. SchemaVersion = 3.4 for current run outputs.
3. No new write scopes.
4. No new remediation action types.
5. Existing remediation semantics unchanged.
6. Output manifest exported.
7. Evidence bundle manifest exported.
8. Evidence hash manifest exported.
9. Redaction report exported.
10. Replay validation report exported.
11. Approval diff exported.
12. Traceability report exported.
13. Client handoff package exported.
14. Rev3.5 readiness report exported.
15. Release package includes hardening artifacts.
16. Schema contracts validate hardening outputs.
17. SelfTest validates hardening modules.
18. DemoMode generates sample hardening outputs.
19. No NHI detectors implemented.
20. No DEC-NHI-* findings emitted.
21. No DEC-AGENT-* findings emitted.
22. No write cmdlets in hardening modules.
23. No Policy.ReadWrite.*.
24. No app/SP/user/guest/group deletion behavior.
25. >= 825 Pester tests passing, 0 failures.
26. Demo mode clean.
27. WhatIf demo clean.
28. SelfTest clean.
29. Safety scan clean.
30. Required docs/runbooks updated.
```

---

## 27. FINAL STOP RULE

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

If the external AI coding engine starts implementing NHI / agentic identity detectors:

```text
Fail the build.
Move that scope to Rev3.5.
```

If the external AI coding engine emits DEC-NHI-* or DEC-AGENT-* findings in Rev3.4:

```text
Fail the build.
Move that scope to Rev3.5.
```

If the hardening package cannot validate evidence chain integrity:

```text
Do not mark release as final.
Return validation warnings and require review.
```

If Rev3.4 becomes too broad:

```text
Stop.
Keep Rev3.4 focused on hardening, packaging, evidence, replay, redaction, handoff, and Rev3.5 readiness only.
```
