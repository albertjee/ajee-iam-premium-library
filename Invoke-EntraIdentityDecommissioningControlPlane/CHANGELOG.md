# Changelog

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

## v1.4 — Hygiene + Spec Completion (2026-04-25)
## v1.3 — Hardening Release (2026-04-25)
## v1.2 — Spec Alignment + Regression Fixes (2026-04-25)
## v1.1 — Remediation Release (2026-04-25)
## v1.0 — Initial Release (2026-04-25)
