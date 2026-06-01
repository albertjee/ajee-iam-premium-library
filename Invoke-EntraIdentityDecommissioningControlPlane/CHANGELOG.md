# Changelog

## Rev2.4 — Baseline Comparison, Trend Analysis, and Executive Evidence Pack

### Added
- `-BaselinePath` parameter: load a prior findings JSON (or run folder) for delta comparison.
- `-GenerateExecutivePack` switch: generate a complete client-ready evidence package.
- `Baseline.psm1`: Import-DecomBaselineFindings, Get-DecomFindingStableKey, Compare-DecomFindingBaseline, Export-DecomBaselineComparisonJson, Export-DecomBaselineComparisonCsv, Get-DecomRiskMovementSummary.
- `ExecutivePack.psm1`: New-DecomExecutiveSummaryModel, Export-DecomExecutiveSummaryMarkdown, Export-DecomExecutiveSummaryHtml, Export-DecomGovernanceKpiDashboardHtml, Export-DecomConsultantEvidenceAppendixMarkdown, Write-DecomClientReadoutPackManifest, Export-DecomResidualRiskRegisterCsv.
- Baseline comparison exports: `*-baseline-comparison-*.json` and `*-baseline-comparison-*.csv` per run.
- Executive pack outputs: executive summary MD, executive summary HTML, governance KPI dashboard HTML, consultant evidence appendix MD, client readout pack manifest JSON, residual risk register CSV.
- Deterministic executive risk posture algorithm (Critical / Elevated / Moderate / Low) with no random state.
- Top-10 risks table weighted by domain diversity then RiskScore.
- SchemaVersion bumped to `2.4` in all output artifacts.

### Safety
- Rev2.4 is read-only.
- No new write scopes.
- No new remediation action types.
- No changes to ExecuteRemediation behavior.
- Rev2.x three-gate controlled remediation safety model unchanged.

### Tests
- Added Baseline.Rev24.Tests.ps1 (26 tests) and ExecutivePack.Rev24.Tests.ps1 (40 tests).
- Added 12 Rev2.4 safety and catalog conformance tests to Safety.Tests.ps1.
- Baseline: 146 (Rev2.3). Rev2.4: 224 tests, 0 failures.

---

## Rev2.3 — Access Review Correlation and Governance Proof Expansion

### Added
- Read-only access review evidence collection where Graph/API coverage is available.
- Governance proof coverage model for review definitions, instances, decisions, and correlation.
- DEC-REV-001 through DEC-REV-005 for access review coverage and decision evidence.
- DEC-GREV-001 through DEC-GREV-003 for guest review correlation.
- DEC-PIM-005 through DEC-PIM-007 for PIM review correlation.
- DEC-AP-006 through DEC-AP-008 for access package review correlation.
- DEC-CA-003 and DEC-CA-004 for Conditional Access exclusion review correlation.
- DEC-GOV-001 through DEC-GOV-003 for tenant-level governance evidence limitations.
- Rev2.3 synthetic findings for governance proof demo mode (+14 findings).
- HTML/JSON/run manifest coverage fields for access review evidence.

### Safety
- Rev2.3 is read-only.
- No new ExecuteRemediation action types.
- No new write scopes.
- No PIM remediation.
- No Entitlement Management remediation.
- No access review creation or decision application.
- Existing Rev2.x controlled remediation safety model unchanged.

### Tests
- Added Rev2.3 discovery, safety, and reporting tests.
- Baseline: 116 (Rev2.2). Rev2.3 target: >= 145 tests, 0 failures.

---

## Rev2.2 — PIM and Entitlement Management Visibility Expansion

### Added
- Read-only PIM eligible assignment visibility.
- DEC-PIM-001: Disabled user has eligible privileged role assignment.
- DEC-PIM-002: Guest has eligible privileged role assignment.
- DEC-PIM-003: PIM activation/review evidence unavailable (tenant-level coverage gap).
- DEC-PIM-004: Eligible privileged assignment requires governance review.
- Read-only Entitlement Management / Access Package visibility.
- DEC-AP-001: Disabled user has access package assignment.
- DEC-AP-002: Guest has access package assignment.
- DEC-AP-003: Access package assignment has no visible expiration evidence.
- DEC-AP-004: Access package review coverage could not be confirmed.
- DEC-AP-005: Access package assignment linked to sensitive resource/group heuristic.
- Rev2.2 coverage model for PIM, Entitlement Management, and Access Review evidence.
- `$script:ToolVersion` single source of truth in entry point; all report headers and footers use `$Context.ToolVersion`.
- SchemaVersion bumped to 2.2 in JSON export and run manifest.

### Safety
- Rev2.2 is read-only.
- No new ExecuteRemediation action types.
- No new write scopes.
- No PIM remediation.
- No Entitlement Management remediation.
- Existing Rev2.x controlled remediation safety model unchanged.

### Tests
- Added Rev2.2 discovery, safety, and reporting tests.
- Test count: 116/116 passing.

---

## Rev2.1 — Evidence, Preflight, and Governance Hardening (2026-05-31)

### Added
- **Target revalidation (Gate C hardening)**: `Confirm-DecomActionTargetValid` validates each action's targets against live Graph state immediately before execution. PrincipalId mismatch on role assignments produces a hard `Blocked` outcome (wrong-object protection). Stale targets produce a warning and continue.
- **Evidence export**: `Export-DecomExecutionEvidence` flattens all executed actions to per-target CSV rows. `Write-DecomExecutionManifest` writes a structured JSON execution summary with SchemaVersion=2.1, Result counts, and EvidenceFiles paths.
- **Execution report**: `Export-DecomExecutionReport` in Reporting.psm1 generates a dark-themed client-deliverable HTML with scorecard and per-action evidence table. TargetsBefore/TargetsAfter are HtmlEncoded before rendering.
- **Preflight report**: Entry point displays a summary table of approved actions (ActionId, FindingId, DisplayName, ActionType, TargetCount, RiskScore) before execution. `-RequirePreflightConfirm` prompts operator to type EXECUTE before proceeding.
- **MaxActions guardrail**: `-MaxActions` (default 25) blocks execution if approved action count exceeds limit. `-ActionId` filter is applied first, then MaxActions check runs on the filtered set.
- **Execution window enforcement**: `Test-DecomApprovalManifest` validates `ExecutionWindowStartUtc` / `ExecutionWindowEndUtc` when present. Execution is blocked outside the approved window. PS5.1 `ConvertFrom-Json` DateTime coercion handled via `is [datetime]` pattern.
- **Approval manifest optional fields**: `ApprovalTicket`, `ApprovalSystem`, `BusinessOwner`, `TechnicalOwner`, `ApprovalNotes`, `ExecutionWindowStartUtc`, `ExecutionWindowEndUtc`.
- **New params**: `-MaxActions [int]`, `-ActionId [string[]]`, `-RequirePreflightConfirm [switch]`.
- Updated Consultant-Runbook.md with full Rev2.1 engagement workflow, ExecuteRemediation command, MaxActions/ActionId examples, optional manifest fields documentation.

### Safety model (unchanged from Rev2.0)
- Three-gate safety model and all frozen files untouched.
- No new write scope, no new remediation types.
- ApprovalManifest.psm1 modified only to add execution window validation to `Test-DecomApprovalManifest`.

### Tests
- Added 13 new Pester tests across 5 new Describe blocks:
  - Rev2.1 Target Revalidation (4 tests)
  - Rev2.1 Evidence Export (2 tests)
  - Rev2.1 Max Action Guardrail (2 source inspection tests)
  - Rev2.1 Preflight Report (2 source inspection tests)
  - Rev2.1 Execution Window Validation (3 tests)
- Total test count: 88, 0 failures.

---

## Rev2.0 — Controlled Remediation Engine (2026-05-30)

### Added
- ExecuteRemediation mode is now live with a three-gate safety model.
- ExecuteRemediation branch runs before discovery, analysis, and export.
- Gate A validates WhatIf manifest:
  - RunId GUID
  - Mode = WhatIfRemediation
  - EngagementId match
  - GeneratedUtc present
  - 7-day freshness
- Gate B validates approval manifest:
  - Action-level ApprovedActions
  - Real ObjectId + TargetObjectIds
  - ActionType/FindingId consistency
  - No duplicate ActionIds
  - No duplicate target operations
  - ApprovedActionsHash
  - ApprovalEnvelopeHash
  - WhatIfRunId binding
  - Expiry
  - AllowNonInteractive authorization
- Gate C blocks ProtectedObject actions at execution time.
- Resolve-DecomExecutableTargets:
  - Fetches real group IDs for DEC-USER-001.
  - Fetches real app role assignment IDs for DEC-USER-002.
  - Fetches exact directory role assignment IDs for DEC-USER-003 and DEC-ROLE-001.
- Privileged role removals are one executable action per exact roleAssignmentId.
- DEC-USER-003 is preferred over DEC-ROLE-001 when both refer to the same role assignment.
- Duplicate target operations are deduplicated before approval manifest generation.
- Execution re-queries after every write and records existsAfter state.
- All group membership checks use Get-MgGroupMember -All.
- PartialFailed outcome added.
- Write Graph scopes are requested only after Gate A and Gate B pass.
- Added -GenerateApprovalTemplate flag.
- Added -NonInteractive flag, requiring AllowNonInteractive=true in approval manifest.
- Added src/Modules/ApprovalManifest.psm1.
- Added src/Modules/ExecutionLog.psm1.
- Added src/Modules/Remediation.psm1.
- Banner updated to Rev2.0.

### Safety model
- Assessment, WhatIfRemediation, and ExportPlan remain read-only.
- ExecuteRemediation validates gates before Graph write connection.
- ExecuteRemediation exits before normal discovery/analysis/export flow.
- Execution operates only on approved TargetObjectIds.
- The engine never broadens remediation by rediscovering current tenant state.
- ProtectedObject actions are never executed.

### Tests
- Added 16+ Rev2.0 safety and remediation tests.
- Added mock-based write-safety tests proving Remove-Mg* cmdlets operate only on approved TargetObjectIds.
- Total test count: 74, 0 failures.

---

## Rev1.7 — README & Branding Polish (2026-05-30)

### Updated
- README.md: complete rewrite as consultant-grade dual-tool reference
  - Assessment Control Plane (Rev1.4) fully documented with quick start, modes, outputs, permissions, severity model
  - Decommissioning Execution Engine (Premium v2.0) summarized with reference to src/README.md
  - Repository layout, engagement workflow, safety model, version history, and requirements sections added
- Consultant-Runbook.md: expanded from stub to full engagement runbook
  - Pre-engagement checklist
  - Step-by-step execution guide
  - Client workshop guidance with common questions and answers
  - Post-workshop process
  - Known limitations updated to Rev1.4
  - Troubleshooting section added

### No code changes
- No .ps1, .psm1, or .Tests.ps1 files modified
- No frozen files touched
- 42/42 Pester tests remain passing

---

## Rev1.4 — Guest Lifecycle + Privileged Access + Conditional Access Detection (2026-05-30)

### Added (Live Detectors)
- DEC-GUEST-002: Guest holds active privileged directory role (Critical, RiskScore 85)
- DEC-GUEST-003: Guest lacks sponsor metadata — no manager or department (Medium, RiskScore 47)
- DEC-ROLE-001: Disabled identity holds active privileged role (Critical, RiskScore 90)
- DEC-USER-003: Disabled user holds privileged role — live mode implementation (Critical, RiskScore 92)
- DEC-CA-001: CA policy has user/group exclusions requiring review (High, RiskScore 65)
- DEC-CA-002: CA exclusion group membership requires access review (High, RiskScore 62)

### Fixed
- Entry point banner version updated from Rev1.1 to Rev1.4
- Entry point module path corrected from src\modules to src\Modules (capital M)
- Policy.Read.All added to Graph connection scope list

### Updated
- Synthetic DEC-GUEST-002 updated to Critical/RiskScore 85
- Synthetic DEC-CA-001 updated to High/RiskScore 65
- Synthetic dataset expanded with DEC-GUEST-003, DEC-ROLE-001, DEC-CA-002 (total: 16 findings)
- Stub coverage probes for DirectoryRoles and ConditionalAccess removed (replaced by live detectors)
- Findings-Catalog.md updated with new and revised entries
- Required-Permissions.md updated with RoleManagement.Read.Directory and Policy.Read.All

### Tests
- Added 7 new Pester tests: severity mapping for DEC-GUEST-002, DEC-ROLE-001,
  DEC-CA-001, DEC-GUEST-003, CSV Rev1.4 finding IDs, remediation plan, HTML rendering
- Total: >= 42 tests, 0 failures

### Notes
- DEC-USER-003 and DEC-ROLE-001 intentionally both fire for the same disabled privileged user
  (different reporting categories: lifecycle failure vs privileged access residue)
- DEC-CA-002 reports access review status as unknown — true review correlation deferred to future release
- DEC-ROLE-001 detects disabled users only in Rev1.4 — stale sign-in detection deferred to future release
- DEC-GUEST-003 may generate findings in tenants where guest sponsor metadata is not maintained
- This release combines planned Rev1.4, Rev1.5, and Rev1.6 into one detection expansion

---

## Rev1.3 — Application Ownership Drift Detection (2026-05-30)

### Added (Live Detectors)
- DEC-APP-002: Application owned exclusively by disabled user (Critical, RiskScore 88)
- DEC-APP-003: Application has only one owner — fragile ownership (Medium, RiskScore 45)
- DEC-APP-004: Application secret or certificate expiring within 90 days (Medium, RiskScore 48)
- DEC-APP-005: Application has expired credential still attached (High, RiskScore 68)
- DEC-SPN-001: Service principal has no owner assigned (Medium, RiskScore 44)
- DEC-USER-002: Disabled user retains app role assignments (High, RiskScore 72)

### Updated
- Synthetic dataset expanded to 14 findings (2C/4H/5M/1L/1I)
- Findings-Catalog.md updated with correct severities and DEC-SPN-001 entry
- Required-Permissions.md updated with AppRoleAssignment.ReadWrite.All

### Tests
- Added 7 new Pester tests: severity validation for new finding IDs,
  remediation plan inclusion, CSV Rev1.3 finding IDs, HTML rendering,
  summary counts for expanded dataset
- Total: ≥ 35 tests, 0 failures

---

## Rev1.2 — Consultant Readiness Hardening Patch (2026-05-30)

### Fixed (P1)
- `Invoke-DecomAnalysis` null-safe guards on DisplayName, UserPrincipalName, and RiskScore
- Protected objects now force `RemediationMode = ProtectedObject` and prepend warning to RecommendedAction
- DEC-USER-001 memberOf filtered to actual groups only (excludes directory roles and admin units)
- DEC-GUEST-001 separates missing sign-in data from stale sign-in evidence — missing data skipped as coverage gap; stale threshold raised to 180 days
- `ExecuteRemediation` mode now exits immediately with error — reserved for future release

### Fixed (P2)
- Safety banner now shows active mode name instead of hardcoded "Assessment mode"
- ExportPlan mode now included in Graph connection guard
- DEC-APP-001 ObjectType and Evidence consistent between DemoMode and live mode
- HTML report mode safety text is now mode-aware
- HTML JavaScript filter replaced NodeList.forEach with indexed loop for enterprise browser compatibility
- Remediation plan now includes Medium findings in Review Queue section and Low/Info in Monitor section
- CSV, JSON, HTML, and Markdown exports handle empty findings array without crashing

### Tests
- Added 8 new Pester tests: null-safe analysis, protected object enforcement,
  empty findings handling, ExecuteRemediation guard, svc- pattern classification,
  empty CSV export, Medium findings in remediation plan, empty summary counts
- Total: 28 tests, 0 failures

---

## Rev1.1 — Consultant Readiness Hardening (2026-05-29)

### Added
- New entry point: `Invoke-EntraIdentityDecommissioningControlPlane.ps1`
- Assessment-first execution model — default mode is `Assessment`, no tenant modification
- Explicit run modes: Assessment, WhatIfRemediation, ExportPlan, ExecuteRemediation
- `-DemoMode` flag — synthetic data, no Graph connection required
- Standardized evidence-backed finding schema (`New-DecomFinding`)
- Severity and confidence model (Critical/High/Medium/Low/Informational + High/Medium/Low confidence)
- Timestamped output folder per run (`out\YYYYMMDD_HHmmss\`)
- CSV, JSON, HTML, and Markdown remediation plan exports
- Executive HTML report — dark theme, KPI grid, severity scorecard, filterable findings table
- Protected object classification model (break-glass, sync, emergency accounts)
- Coverage tracking model — reports partial coverage when Graph scopes are unavailable
- Consultant-facing remediation plan with approval status fields
- `docs\Consultant-Runbook.md`
- `docs\Required-Permissions.md`
- `docs\Findings-Catalog.md`
- `samples\` — demo-mode output files (CSV, JSON, HTML, Markdown)
- `tests\Rev11\` — Safety, Analysis, Reporting Pester suites (20 tests, 0 failures)

### Architecture
- `src\modules\Discovery.psm1` — assessment discovery with coverage tracking
- `src\modules\Analysis.psm1` — scoring engine, confidence model, protected object classification
- `src\modules\Reporting.psm1` — all export functions including HTML report generator
- `src\modules\RemediationPlan.psm1` — approval-ready Markdown plan generator
- `src\modules\Utilities.psm1` — console output helpers, finding object factory

### Unchanged
- All Lite decom modules (`src\LiteModules\`) — untouched
- All Premium batch modules (`src\Modules\`) — untouched
- All existing Pester suites — untouched, still passing
- Existing docs, SECURITY.md, LICENSE — untouched

---

## v1.5a — Stabilization Release (2026-04-25)

v1.5a is a post-review stabilization release following the v1.5 security hardening milestone.
It introduces no new functional scope or authority and does not modify the threat model,
privilege profile, or guardrail logic documented in `docs/threat-model-v1.5.md`.
The release exists solely to add security documentation artifacts (security posture summary,
red-team scenario analysis, refined SECURITY.md) after initial audit review.

**No code changes. No new threat surface. Existing risk acceptance remains valid.**

---

## v1.5 — Security Hardening Release (2026-04-25)

### Evidence Sealing (tamper-evidence)
- **Hash-chain sealing added to `Evidence.psm1`** — every NDJSON event includes
  `PrevHash` and `EventHash`. Any edit, deletion, or reorder of events breaks the chain.
- **`evidence.manifest.json` written at end of every run** — contains `FinalEventHash`,
  `RunId`, `CorrelationId`, `OperatorUPN`, `TicketId`, and event count as integrity anchor.
- **`SealEvidence` context flag** — default `$true`. Use `-NoSeal` for dev/test only.
- **`Get-DecomSha256Hex`** and **`Seal-DecomEvidenceEvent`** exported from Evidence.psm1.

### Operator Identity (repudiation resistance)
- **`OperatorUPN` and `OperatorObjectId` added to every evidence event** — resolved from
  `Get-MgContext` post-authentication in `Start-Decom.ps1`.
- **`OperatorUPN` and `TicketId` included in `evidence.manifest.json`** summary.
- **Workflow return summary** now includes `OperatorUPN`, `TicketId`, and `Sealed` flag.

### Force Mode Governance
- **`TicketId` mandatory in `-Force -NonInteractive` mode** — `Start-Decom.ps1` exits with
  error if TicketId is not supplied in automation mode. Provides change/ticket traceability.

### Repo Security Posture
- **`SECURITY.md` added** — vulnerability disclosure process, severity classification,
  operational security requirements, and known design limitations documented.
- **`docs/threat-model-v1.5.md` added** — full STRIDE-aligned threat model with asset
  inventory, trust boundaries, mitigations, residual risks, and evidence quality table.

### Pester Coverage (v1.5 — 41 tests across 11 context blocks)
New tests: SECURITY.md presence, threat model doc presence, version string v1.5,
SHA-256 determinism and sensitivity, Seal-DecomEvidenceEvent hash chain correctness,
tamper detection, SealEvidence default true, NoSeal flag, OperatorUPN in context,
TicketId governance enforcement, Write-DecomEvidenceManifest export, workflow summary fields.

---

## v1.4 — Hygiene + Spec Completion (2026-04-25)
## v1.3 — Hardening Release (2026-04-25)
## v1.2 — Spec Alignment + Regression Fixes (2026-04-25)
## v1.1 — Remediation Release (2026-04-25)
## v1.0 — Initial Release (2026-04-25)