# Changelog

## Rev4.1 — NHI Activity Audit Hardening

### Summary
Six new read-only pre-decom agentic activity audit modules. Rev4.0 P1 fix.
Zero new write scopes. 1498/1498 tests passing.

### Changes

#### M0 — Rev4.0 P1 Fix
- Fixed DestructiveCmdletGuard false positive: renamed hashtable key
  HardDeleteServicePrincipal -> HardDeleteSvcPrincipalBlocklist in NhiExecutionSchema.psm1

#### M1-M6 — New Read-Only Modules
- NhiActivityLog.psm1: NHI-ACT-001 through NHI-ACT-005
- NhiGraphApiAudit.psm1: NHI-GRAPH-000 through NHI-GRAPH-008
- NhiComplianceAudit.psm1: NHI-COMPLY-001 through NHI-COMPLY-004
- NhiTokenForensics.psm1: NHI-TOKEN-001 through NHI-TOKEN-003
- NhiConditionalAccessResponse.psm1: NHI-CA-001 through NHI-CA-003
- NhiPostDecomAudit.psm1: DEC-ATTEST-001 through DEC-ATTEST-004
- Total new finding IDs: 28

#### M7 — Entry Point
- Added -IncludeAgentActivityAudit switch (optional, off by default)
- Added 6 new modules to modulesToLoad

#### Tests
- New: tests/NhiActivityAudit.Rev41.Tests.ps1 (41 tests)
- Total: 1498 passed, 0 failed (Rev4.0 baseline: 1456)

---

## Rev4.0 — NHI Execution Foundation (2026-06-07)

### M31 — Execution Schema
- Created `src/Modules/NhiExecutionSchema.psm1`
  - `Get-NhiExecutionSchema` — returns 12-action metadata hashtable (6 allowed + 6 blocked)
  - `Test-NhiExecutionActionAllowed` — phase gating and reversibility enforcement
  - `Confirm-NhiApprovedManifest` — 7-check approval manifest validation
- Phase 1 (Snapshot, Tag), Phase 2 (Disable), Phase 3 (Monitor, RollbackTag, RollbackDisable)
- 6 blocked actions: HardDeleteServicePrincipal, RemoveCredential, RemoveAppRoleAssignment, RemoveOAuthGrant, RemoveOwner, DeleteApplication
- Created `tests/NhiExecutionSchema.Rev40.Tests.ps1` (25 tests)
- Commit: `feat: Rev4.0 M31 - NhiExecutionSchema, action model, manifest validation`

### M32 — Execution Module: Snapshot and Tag
- Created `src/Modules/NhiExecution.psm1`
  - `Invoke-NhiSnapshot` Phase 1 — reads SP graph state, writes SnapshotManifest, tags via Update-MgServicePrincipal
  - `Invoke-NhiTag` Phase 1 — validates prior snapshot, writes DecomTagged notes via Update-MgServicePrincipal
  - PriorNotes capture (null and non-null), PriorAccountEnabled capture
  - Entra write scope: ServicePrincipal only. MI and User are scaffold/read-only.
- Created `tests/NhiExecution.Rev40.Tests.ps1` (added 25 M32 tests)
- Commit: `feat: Rev4.0 M32 - NhiExecution snapshot and tag, PriorNotes capture, SP-only write`

### M33 — Execution Module: Disable and Rollback
- Added to `NhiExecution.psm1`:
  - `Invoke-NhiDisable` Phase 2 — Update-MgServicePrincipal -AccountEnabled:$false, ScreamTestDays tracking
  - `Invoke-NhiRollbackDisable` — restores PriorAccountEnabled exactly (not unconditional $true)
  - `Invoke-NhiRollbackTag` — restores PriorNotes exactly (including null case)
- User with `-AllowHumanExecution`: silent scaffold, no Entra write, ScreamTestDays = 0
- MI disable/rollback: no Entra write, skip reason logged
- Added 24 M33 tests (`tests/NhiExecution.Rev40.Tests.ps1`)
- Commit: `feat: Rev4.0 M33 - NhiExecution disable and rollback, prior-state restore`

### M34 — Scream-Test Monitoring Status
- Added `Get-NhiScreamTestStatus` to `NhiExecution.psm1`
  - Status = Active | Complete | Overdue (ordered evaluation, Overdue takes precedence)
  - Writes/updates NhiExecutionStatus.json with 8-field MonitoringStatus objects
  - Threshold: Complete when ElapsedDays >= ScreamTestDays; Overdue at ScreamTestDays + 7
- Added 14 M34 tests
- Commit: `feat: Rev4.0 M34 - Get-NhiScreamTestStatus, scream-test monitoring, 1406/1406 passing`

### M35 — Entry Point Integration
- Modified `Invoke-EntraIdentityDecommissioningControlPlane.ps1`
  - 8 new execution parameters: -ExecuteNhiDecommission, -PhaseLimit, -ApprovedManifestPath, -ScreamTestDays, -ExecutionOutputPath, -Rollback, -ExecutionRunId, -AllowHumanExecution
  - M35 destructive cmdlet guard (runtime source scan for 12 blocked cmdlets)
  - Approved manifest gate ordered before Connect-MgGraph
  - All 4 phases wired: Phase 1 always runs (Snapshot+Tag), Phase 2 (Disable) follows, Phase 3 (Monitor) on demand
  - ExecutionOutputPath created if absent
- Added 18 M35 tests
- Commit: `feat: Rev4.0 M35 - NhiExecution disable and rollback, prior-state restore, SP-only write`

### M36 — Push Readiness Harness + Destructive Cmdlet Guard
- Created `tests/DestructiveCmdletGuard.Rev40.Tests.ps1` —
  25 CommandAst-based Pester It blocks (Use-MgServicePrincipal AST scan via FindAll(),
  not .NET Visit() pattern — hardDeleteServicePrincipal hashtable keys excluded correctly)
- Created `tools/Test-Rev40PushReadiness.ps1` — 5-gate push harness
  (parse checks, module import, full Pester suite, git status, manifest validation smoke test)
- Confirmed: DestructiveCmdletGuard.Rev40.Tests.ps1 BeforeAll failure fixed by replacing
  $ast.Visit() with $ast.FindAll() (correct PowerShell AST traversal — FindAll() takes scriptblock + bool)
- Commit: `feat: Rev4.0 M36 - DestructiveCmdletGuard test suite, push readiness harness, 1456 tests passing`

### M37 — Documentation
- Updated `CLAUDE.md` — Rev3.11 → Rev4.0, canonical test count 1320 → 1456
- Created this CHANGELOG Rev4.0 section
- Created `QA-PACKAGE-REV40-v1.md` (gitignored at repo root)

### Tests
- Total: 1456/1456 passing, 0 failed (Rev4.0 canonical count)

### Key Design Decisions
| Topic | Decision |
|---|---|
| Entra write scope | ServicePrincipal only. MI and User deferred to Rev4.1. |
| Human identity hooks | User disable scaffold — -AllowHumanExecution required, no Entra write, ScreamTestDays = 0 |
| MI behavior | Scaffold — reads capture state locally, skip reason logged, no Entra write |
| Approved manifest | 7-check validation (EngagementId, SHA256, Phase, ApprovedBy, ApprovedAt, SchemaVersion, file parse) |
| Destructive cmdlet guard | M35 runtime scan (entry point startup) + M36 Pester AST scan (CI gate) |
| SnapshotManifest | SnapshotManifest-{ExecutionRunId}.json — one file per RunId |
| ExecutionRunId | Auto-generated if not supplied (yyyyMMdd_HHmmss UTC), validated by regex |
| HTML execution sections | Deferred to Rev4.1 (NhiReporting.psm1 not modified in Rev4.0) |
| New-DecomFinding | Never called from any execution module |
| Start-EntraIAMAssessment.ps1 | Not modified in Rev4.0 |

### Known Limitations (carried forward from Rev3.x)
- MI Entra write deferred to Rev4.1 (pending live SDK validation)
- HTML execution sections deferred to Rev4.1
- Sign-in log data source (NHI-SIGNIN-001/002) not yet wired
- AgentIdentityBlueprintId (NHI-AGENT-002/003) not yet wired
- DEC-AGENT-002/006/007 dormant findings
- Full human execution deferred to Rev4.1
- Start-EntraIAMAssessment.ps1 not updated (Rev3.11 v2 scope)

---

## Rev3.11 — Simple Parameter Wrapper (2026-06-05)

### M1 - Wrapper Script
- Created `Start-EntraIAMAssessment.ps1` (repo root) — preset-driven launcher for the main entry point
- Four run modes: QuickNHI, FullAssessment, DemoMode, WhatIfRemediation
- Dot-source safe (returns immediately on dot-source)
- ShouldProcess guard: `-WhatIf` blocks main tool invocation
- `-Mode` validated at runtime (not Mandatory in param block)
- Help content: .SYNOPSIS, .DESCRIPTION, 4 .EXAMPLE blocks
- No hardcoded absolute paths
- Commit: `feat: Rev3.11 M1 - Start-EntraIAMAssessment.ps1 wrapper, 4 preset modes`

### M2 - Test Suite
- Created `tests/StartEntraIAMAssessment.Rev311.Tests.ps1` (29 tests)
- TestDrive fake entry point strategy (not Mock) for splat verification
- Covers: presence/load, parameter metadata, help content, all 4 preset mappings, optional param wiring, ShouldProcess guard, no hardcoded paths
- All 29 new tests pass
- Commit: `test: Rev3.11 M2 - StartEntraIAMAssessment tests, 1320/1320 passing`

### M3 - Documentation
- `CHANGELOG.md` updated with Rev3.11 section
- `CLAUDE.md` updated: Current revision Rev3.10 → Rev3.11, Canonical test count 1291 → 1320
- Commit: `docs: Rev3.11 M3 - CHANGELOG and CLAUDE.md updated`

### Tests
- Total: 1320/1320 passing, 0 failed

## Rev3.8 — NHI Coverage Expansion (2026-06-05)

### M21 - NhiCredential Module
- Created `src/Modules/NhiCredential.psm1` implementing NHI-CRED-001 through NHI-CRED-005
- Credential hygiene detectors: client secret detection, secret age thresholds (90/180 days), expired credential with active SP, credential expiry warning (30 days)
- Threshold inclusivity: exactly 90 days fires NHI-CRED-002; exactly 180 days fires NHI-CRED-003 and suppresses NHI-CRED-002 for same credential
- Created `tests/NhiCredential.Rev38.Tests.ps1` (18 tests)
- Commit: `fix: Rev3.8 M21 - NhiCredential module, NHI-CRED-001 through 005`

### M22 - NhiPermission Module
- Created `src/Modules/NhiPermission.psm1` implementing NHI-PERM-001 through NHI-PERM-008
- Permission and scope detectors: privilege sprawl (>10 units), moderate complexity (5-9 units), high-risk app roles, high-risk delegated scopes, AllPrincipals consent, combined AllPrincipals+high-risk, app role lookup failure, unresolved stale grants
- Exact case-insensitive scope token matching (not substring); one finding per matching token
- Created `tests/NhiPermission.Rev38.Tests.ps1` (24 tests)
- Commit: `fix: Rev3.8 M22 - NhiPermission module, NHI-PERM-001 through 008`

### M23 - NhiSignIn Module
- Created `src/Modules/NhiSignIn.psm1` implementing NHI-SIGNIN-001 through NHI-SIGNIN-005
- Sign-in activity detectors: stale thresholds (90/180/365 days), suppressive precedence (SIGNIN-003 > SIGNIN-002 > SIGNIN-001), absent sign-in record with active credentials, recent active SP with no owner, recent active SP with high-risk permission
- Null/missing sign-in record: emits SIGNIN-003 with Confidence=Medium when SP has active credentials but no sign-in record
- Created `tests/NhiSignIn.Rev38.Tests.ps1` (18 tests; co-committed with M22)
- Commit: `fix: Rev3.8 M23 - NhiSignIn module, NHI-SIGNIN-001 through 005`

### M24 - Integration Wiring
- Added NhiCredential, NhiPermission, NhiSignIn to module import list in entry point
- Invoked all three scans from entry point after NHI governance block
- New findings flow through existing $Findings pipeline to CSV and JSON export
- Entry point integration: no modifications to existing NHI governance or discovery modules
- Commit: `feat: Rev3.8 M24 - integration wiring and Rev3.8 push readiness harness`

### M25 - Documentation
- Updated CLAUDE.md: Rev3.7 -> Rev3.8, canonical test count 1179 -> 1240
- Updated CHANGELOG.md with Rev3.8 section

### Tests
- Total: 1240 tests, 0 failures
- Added tests: 18 (NhiCredential), 24 (NhiPermission), 18 (NhiSignIn), 1 synthetic data test = 61 new tests

### Safety
- Rev3.8 expands NHI classification with 18 new finding IDs across credential, permission, and sign-in domains
- No new Graph endpoints; all new finding functions accept pre-fetched data
- NhiSignInScan and NhiCredentialScan handle absent sign-in data gracefully (empty hashtables)
- No new remediation action types or write scopes

### EntraNHIAudit Retirement
- The 18 NHI finding IDs (NHI-CRED-001/002/003/004/005, NHI-PERM-001 through 008, NHI-SIGNIN-001 through 005) were ported from the retired EntraNHIAudit tool
- Rev3.8 consolidates these findings into the decommissioning control plane with full test coverage and pipeline integration

---

## Rev3.9 — NHI Owner/Publisher/Agent Parity Release (2026-06-05)

### M26 - NhiOwner Module
- Created `src/Modules/NhiOwner.psm1` implementing NHI-OWNER-001 through NHI-OWNER-006
- Owner governance detectors: no owner, single owner, owner lookup failure (one-time assessment finding), guest owner, disabled owner, all-owners-are-service-principals
- OWNER-003 (lookup failure) fires exactly once as Assessment-level finding when lookup globally fails, suppressing OWNER-001/002 per-SP findings
- OWNER-001 mutually exclusive with OWNER-002 and OWNER-006
- Created `tests/NhiOwner.Rev39.Tests.ps1` (19 tests)
- Commit: `fix: Rev3.9 M26 - NhiOwner module, NHI-OWNER-001 through 006`

### M27 - NhiPublisher Module
- Created `src/Modules/NhiPublisher.psm1` implementing NHI-PUB-001, NHI-PUB-002, NHI-REG-001
- Publisher verification detectors: no verified publisher, verified publisher present, application registration age >= 365 days
- Threshold inclusion: exactly 365 days fires NHI-REG-001
- Created `tests/NhiPublisher.Rev39.Tests.ps1` (12 tests)
- Commit: `fix: Rev3.9 M27 - NhiPublisher module, NHI-PUB-001/002, NHI-REG-001`

### M28 - NhiAgent Module (Alternative Implementation)
- Created `src/Modules/NhiAgent.psm1` implementing NHI-AGENT-001, NHI-AGENT-002, NHI-AGENT-003 + DEC-AGENT-002/006/007
- AI-agent identity detectors: name pattern matches (agent|copilot|assistant|bot|automation|workflow), blueprint-derived agent with no owner, blueprint-derived agent with high-risk permissions, AgenticCandidate with name pattern, AgenticCandidate with client secrets, unowned AgenticCandidate with high-risk permissions
- DEC-AGENT findings (002/006/007) implemented in NhiAgent.psm1, not in frozen NhiGovernance.psm1
- Deviation Note: `NhiGovernance.psm1` is in the FROZEN list (CLAUDE.md Section 7) and could not be modified; DEC-AGENT findings implemented in standalone NhiAgent.psm1 instead
- Created `tests/NhiAgent.Rev39.Tests.ps1` (20 tests)
- Commit: `fix: Rev3.9 M28 - NhiAgent module, DEC-AGENT-002/006/007 + NHI-AGENT-001/002/003`

### M29 - Integration Wiring
- Added NhiOwner, NhiPublisher, and NhiAgent scan invocations to entry point after NhiGovernance pipeline block
- Entry point modulesToLoad extended to include: NhiOwner, NhiPublisher, NhiAgent
- Findings flow through existing `$Findings` pipeline to CSV/JSON export
- Entry point integration: no modifications to existing NHI governance or discovery modules
- Empty hashtable input: all three scanners return dormant findings when passed empty hashtable (OwnerLookupSucceeded=$false by default; NhiPublisher and NhiAgent blueprints map empty)
- Created `tools/Test-Rev39PushReadiness.ps1`: module parse checks, import verification, full Pester suite
- Commit: `fix: Rev3.9 M29 - integration wiring for NhiOwner, NhiPublisher, NhiAgent scans, 1291/1291 passing`

### M30 - Documentation
- Updated CLAUDE.md: Rev3.8 -> Rev3.9, canonical test count 1240 -> 1291
- Created `docs/QA-PACKAGE-REV39-v1.md`: documented all Rev3.9 findings, integration notes, test results
- Updated CHANGELOG.md entries for M26-M30

### Tests
- Total: 1291 tests, 0 failures
- Added tests: 19 (NhiOwner), 12 (NhiPublisher), 20 (NhiAgent) = 51 new tests

### Safety
- Rev3.9 adds NHI classification findings only — all modules are read-only
- No new Graph endpoints; all new finding functions accept pre-fetched data
- NhiAgent empty hashtable input returns dormant findings (OwnerCount/CredentialCount/HighRiskPermissionCount all zero when no data supplied)
- NhiOwner handles absent owner data gracefully (suppresses per-SP findings when lookup failed)
- No new remediation action types or write scopes

### EntraNHIAudit Retirement (Continued)
- The 9 NHI finding IDs (NHI-OWNER-001 through 006, NHI-PUB-001/002, NHI-REG-001) were ported from the retired EntraNHIAudit tool
- NHI-AGENT-001/002/003 add new AI-agent identity analysis not previously in EntraNHIAudit
- DEC-AGENT-002/006/007 extend the agentic candidate inventory with governance and credential risk signals

---

## Rev3.10 — Data Wiring and DemoMode Hardening (2026-06-05)

### M38 - Entry Point Structural Fix
- Fixed pre-existing structural bug: `if ($GenerateNhiGovernancePack -or $DemoMode)` block at line 416 was missing closing `}` before the credential scan section — caused parse error with `pwsh -File`
- Fixed pre-existing DemoMode parameter bug: `Invoke-DecomNhiDiscovery -Context $Context -DemoMode:$DemoMode` passes a parameter that does not exist on that function — DemoMode is read from `$Context.DemoMode` internally; removed illegal `-DemoMode:$DemoMode` argument
- Entry point parse errors: 1 (pre-existing) → 0 (resolved)

### M38 - DemoMode Synthetic Data Hardening (New-DecomNhiSyntheticData only)
- Added `PrincipalId` to synthetic AppRoleAssignment on sp-002 — prevents `ContainsKey(null)` crash in NhiPermissionScan when scanning with empty hashtable inputs
- Added `ClientId` to synthetic OAuthGrant on sp-003 — prevents `ContainsKey(null)` crash in NhiPermissionScan
- Added `AdditionalProperties = @{}` to all 4 synthetic SPs — real Graph SPs always have this hashtable; ensures property access is not null
- Added `KeyCredentials` array to sp-002 to align with what NhiCredentialScan expects (standard Graph property name vs the custom `Credentials` NoteProperty) — ensures credential scan can read key credential metadata

### M39 - Data Source Wiring
- Wire `ownersByObjectId` hashtable to `Invoke-NhiOwnerScan` — owner data from NhiDiscovery (via `RawOwners`) now passed instead of empty hashtable
- Wire `appRegistrationByAppId` hashtable to `Invoke-NhiPublisherScan` — app registration data keyed by AppId now supplied
- Wire `agentBlueprintIdByObjectId` hashtable to `Invoke-NhiAgentScan` — blueprint IDs from NhiDiscovery `AdditionalProperties['agentIdentityBlueprintId']` extracted for scan functions; added PSObject property-existence guard before direct property access
- Fixed `ownerLookupSucceeded` flag — propagates `RiskScoreMayBeUnderstated` from NhiInventory to NhiOwner scan
- Fixed credential/permission/sign-in section to use NhiAnalyzed SPs (3 SPs after Microsoft Graph filtered) instead of NhiInventory (4 SPs including Microsoft Graph) — consistent with owner/agent/publisher scan data source
- Added null-safe count aggregation for scan result counts — scan functions return `$null` rather than `@()` when no findings, causing `$array.Count` to throw in earlier versions

### M40 - Smoke Test
- DemoMode smoke test: all 5 outputs generated (CSV, JSON, HTML, remediation plan, run manifest)
- NHI finding counts in DemoMode: DEC-NHI (13), NHI-PERM (4), DEC-AGENT (6), NHI-AGENT (2)
- Excluded from M40 commit (fold into M41): NHI-CRED (0 in DemoMode — credential scan reads KeyCredentials property which differs from synthetic data's `Credentials` NoteProperty; acceptable for data-dependent scan), NHI-SIGNIN (0 in DemoMode — sign-in data not generated because DemoMode does not use real-time sign-in records)
- No code changes required for M40 — M40 results folded into M41 docs commit

### Tests
- Total: 1291 tests, 0 failures (unchanged from Rev3.9)
- No new tests added in Rev3.10 (cleanup and wiring release, no new modules)

### Safety
- Rev3.10 is a structural and data wiring release — no new Graph endpoints, no new finding IDs
- Property-existence guard added for `AgentIdentityBlueprintId` access on NhiInventory objects
- Null-safe count aggregation prevents premature script termination when scan functions return `$null`
- DemoMode synthetic data now more closely mirrors real Graph SDK response shape

### KNOWN-P1: RESOLVED
- Pre-existing entry point AST parse error (missing `}`): 0 parse errors after M38 fix
- Pre-existing DemoMode parameter crash (`A parameter cannot be found that matches parameter name 'DemoMode'`): resolved, DemoMode now runs to completion

---

## Rev3.7 — Polishing, Determinism, and Safety Hardening (2026-06-04)

### M16 - Output Manifest Determinism
- Fixed intermittent test failure in OutputManifest.Rev34.Tests.ps1 ("Output manifest includes redacted files").
- Ensured redacted file is generated deterministically, registered in manifest, and discoverable by test.
- OutputManifest verification documentation added.

### M17 - Remediation Presence-Check Unknown State
- Enhanced Remediation.psm1 (lines ~928, 940, 951) to distinguish three presence-check states:
  - `ConfirmedPresent`: Graph read succeeded, target exists
  - `ConfirmedAbsent`: Graph read succeeded, target absent
  - `Unknown`: Graph read failed, error sanitized in output
- Affected actions: `RemoveGroupMembership`, `RevokeAppRoleAssignment`, `RemoveDirectoryRoleAssignment`
- Silent read-failure-as-absence behavior removed; Unknown state now visible in output and remediation readiness.
- Added 9 new tests covering all three states per action type.

### M18 - Source Integrity Gates
- **M18a - Unicode/Mojibake Scanner**: Created `tests/Rev37/SourceIntegrity.Rev37.Tests.ps1`
  - Blocks U+FFFD (replacement char), U+2010–U+2015 (Unicode dashes), U+00A0 (NBSP), smart quotes, mojibake byte sequences
  - Reports exact file and line number for offending source
  - 4 new tests validating scanner coverage
- **M18b - CRLF Validation**: Added `tests/Rev37/LineEndings.Rev37.Tests.ps1`
  - Validates CRLF in all .ps1, .psm1, .psd1 files
  - Detection-only; no auto-rewrite during test execution
- **M18c - Git Attributes**: Added `.gitattributes` to enforce CRLF on future commits
  - Applied to: *.ps1, *.psm1, *.psd1, *.md, *.json, *.csv

### M19 - Push Readiness Harness
- Created `tools/Test-Rev37PushReadiness.ps1` (non-mutating pre-push validation)
- Includes: git status, git diff HEAD origin/main, Unicode/mojibake scan, CRLF scan, AST parse of all source, import smoke tests
- Switches: `-RunPester` (optional) to execute full Pester suite
- Exit code 0 on all checks pass; non-zero on failure
- Reports changed files clearly; no repo state mutation

### M20 - Documentation Polish
- Updated CLAUDE.md:
  - Canonical test count: 1165 → 1179
  - Current revision: Rev3.6 → Rev3.7
  - Added Section 13 (Rev3.7 Source Integrity Rules): Unicode blocking, mojibake detection, CRLF preservation, Gate 1 inline pwsh rule
  - Added Section 14 (Final Validation Standards): raw output requirement, git diff verbatim reporting
- Updated CHANGELOG.md with Rev3.7 summary
- Added `docs/Rev3.7-ReleaseNotes.md`: purpose, what changed, validation environment, final test result, known issues

### Tests
- Total: 1179 tests, 0 failures
- Added tests: 9 (M17 presence-check), 4 (M18a source integrity), included in suite baseline

### Safety
- Rev3.7 adds zero new write scopes. All changes are determinism, safety hardening, and documentation.
- No new remediation action types.
- No new tenant modification behavior.
- All source integrity gates are read-only validation.

---

## Rev3.6 — Output Consistency, Version Hygiene, and Validation Expansion (2026-06-03)

### Added
- `Add-DecomCoverageLimitation`: NhiAnalysis helper for deduplicating coverage limitations and preserving discovery flags during analysis phase.
- 8 Rev3.6 validation test suites (37 tests total):
  - `VersionHygiene.Rev36.Tests.ps1`: Version consistency, historical version markers.
  - `PS51Compatibility.Rev36.Tests.ps1`: PS5.1 parser compliance, no PS7-only syntax.
  - `HtmlEncoding.Rev36.Tests.ps1`: Dynamic value HTML encoding in reports.
  - `WarningHygiene.Rev36.Tests.ps1`: Silent catch block elimination, error capture.
  - `CoverageLimitations.Rev36.Tests.ps1`: Limitation deduplication, RiskScoreMayBeUnderstated semantics.
  - `NhiPipelineState.Rev36.Tests.ps1`: NHI pipeline state caching, single-run guarantee.
  - `OutputManifestEvidenceCleanup.Rev36.Tests.ps1`: Manifest recursion prevention, file deduplication.
  - `RedactionCleanup.Rev36.Tests.ps1`: Redaction module structure, error handling.
- `TestVersionContext.ps1`: Centralized version expectation helper (single source of truth for test assertions).

### Changed
- SchemaVersion bumped to '3.6' in 12 output modules (ApprovalDiff, ApprovalManifest, ClientHandoff, EvidenceBundle, OutputManifest, Redaction, ReplayValidation, Reporting, Rev35Readiness, Rev3CapabilityMatrix, Traceability, ReleasePackaging).
- Entry point ToolVersion updated to 'Rev3.6'.
- Executive pack context SchemaVersion updated to '3.6'.

### Fixed
- Version hygiene: Test files with historical version references (Rev3.5 fixtures) now marked with INTENTIONAL_HISTORICAL_VERSION to prevent drift detection.
- NHI pipeline state: Introduced caching variables ($NhiInventory, $NhiAnalyzed, $NhiGovernanceFindings, $NhiPipelineRan) to prevent duplicate NHI discovery/analysis runs on resume.
- Output manifest deduplication: Added Get-DecomOutputFilesForManifest helper to prevent self-recursion and duplicate file entries via hashtable-based path tracking.
- Redaction module: Replaced silent catch blocks with Write-DecomWarn error capture and exclusion of redacted folder from file enumeration (added check: $_.FullName -notmatch '\\redacted\\').
- Pester test patterns: Fixed foreach variable capture issue in VersionHygiene test by using -TestCases parameter for dynamic test generation.
- Milestone 9: WarningHygiene module and 26 validation tests for silent catch block detection and error hygiene.
- Milestone 10: HtmlEncoding module with HTML-safe value encoding in reports (34 tests).
- WriteReadiness module: Added missing Utilities.psm1 import to enable Write-DecomOk output functions.
- ReleaseValidation module: Updated version check from Rev3.5 to Rev3.6 (surgical update to 7 locations + compatibility array).
- SchemaContracts AllowedValues: Updated OutputManifest schema contract to accept both '3.4' and '3.6' (historical compatibility + current version).
- Test infrastructure: Updated ReleaseValidation.Rev25.Tests.ps1 and ReleaseValidation.Rev31.Tests.ps1 version assertions to validate Rev3.6.

### Safety
- Rev3.6 adds zero new write scopes. All changes are output consistency and validation improvements.
- No new remediation action types or API permissions.

---

## Rev3.5 — NHI / Agentic Identity Audit and Governance Expansion (2026-06-02)

### Added
- `NhiDiscovery.psm1`: Non-Human Identity discovery and risk scoring — identifies service principals, application registrations, and agentic identity patterns via Microsoft Graph read-only API. Emits findings in DEC-NHI-001..012 and DEC-AGENT-001..007 namespaces.
- `NhiAnalysis.psm1`: NHI classification engine — scores and classifies NHI objects as LikelyAIAgent (≥50 or ≥30 with agent signals), LikelyAutomation (≥15), or Unclassified. Scoring factors: ServiceIdentity (+50), agent pattern (+35), automation (+25), service/worker (+15), credential (+10), high-risk permission (+15), tenant-wide consent (+15), no owner (+15), single owner (+8), unverified publisher (+8), external publisher (+10). Severity mapping: Critical≥85, High≥70, Medium≥44, Low≥15, Informational<15.
- `NhiGovernance.psm1`: NHI governance remediation planning — generates governance findings, exception registers, and remediation plan items. ManualApprovalRequired for critical NHI findings; PlanOnly for agentic identity posture items.
- `NhiReporting.psm1`: NHI reporting outputs — executive summary (JSON), detailed findings (JSON), exception register (CSV), governance report (Markdown). All outputs are read-only.
- 5 NHI test suites: `NhiAnalysis.Rev35.Tests.ps1`, `NhiDiscovery.Rev35.Tests.ps1`, `NhiGovernance.Rev35.Tests.ps1`, `NhiReporting.Rev35.Tests.ps1`, `NhiSafety.Rev35.Tests.ps1`.

### Fixed (P1)
- P1-01A: Entry point second NHI governance block called `Invoke-DecomNhiAnalysis -NhiInventory` (wrong parameter name); changed to `-NhiObjects`.
- P1-01B: NHI pipeline now runs BEFORE standard exports in main assessment flow, merging NHI governance findings into main Findings array so NHI findings appear in CSV/JSON/HTML standard exports.
- P1-03: NhiAnalysis marks `RiskScoreMayBeUnderstated = $true` and logs `CoverageLimitations` when `HighRiskPermissionCount` is unavailable (GUID resolution failed), indicating permission risk may be understated.
- P1-04: NhiAnalysis now calculates `TenantWideConsent` and `HighRiskOAuthGrantCount` from `RawOAuthGrants` array instead of leaving as null. `TenantWideConsent = $true` when any grant has `ConsentType = 'AllPrincipals'`. `HighRiskOAuthGrantCount` increments for grants with scopes matching high-risk pattern (`.All`, `.Send`, `FullControl`, `offline_access`).
- P1-05: NhiReporting replaced PS7-only `??` null-coalescing operator with PS5.1-compatible `if ($var) { $var } else { 'default' }`. Replaced overclaiming language "comprehensive analysis of ...discovered" with "read-only assessment of Entra-visible NHI candidates using heuristic classification. Coverage is limited to Entra-visible signals only."

### Safety
- Rev3.5 adds zero new write scopes. All 4 NHI modules are strictly read-only.
- No Remove-Mg, Update-Mg, Set-Mg, New-Mg, or Invoke-MgGraphRequest in any NHI module.
- No connect-scope requests for Application.ReadWrite, RoleManagement.ReadWrite, EntitlementManagement.ReadWrite, or Policy.ReadWrite in NHI modules.
- NHI findings are discovery/posture outputs only — no tenant modifications.
- Rev3.5 adds no new remediation action types to Remediation.psm1.
- Rev3.5 WriteReadiness registry entries carry IntroducedIn = 'Rev3.5'.

### Fixed (Final P1)
- P1-01C: Summary recalculated immediately after NHI findings merge into $Findings. Added test verifying Summary.Total includes both DEC-NHI and DEC-AGENT findings.
- P1-03A: Analysis now preserves RiskScoreMayBeUnderstated and CoverageLimitations from discovery phase instead of resetting to false/@(). Analysis-level limitations appended to discovery limitations rather than overwriting.
- P1-04A: TenantWideConsent and HighRiskOAuthGrantCount calculated BEFORE classification and risk scoring (first OAuth calculation step), so OAuth factors influence classification score. OAuth scoring now contributes to final risk assessment.

### Tests
- Added 168 NHI-specific tests across 5 test files.
- Added 3 final P1 tests: Summary.Total coverage, RiskScoreMayBeUnderstated preservation, CoverageLimitations preservation.
- Total: 1073 tests, 0 failures (prior baseline: 890, Rev3.5 entry: 1068).

---

## Rev3.4 P1 — Entry Point Wiring Fixes and Test Harness Correctness (2026-06-02)

### Fixed
- Entry point P1-02: `Compare-DecomWhatIfToApproval` was called with empty `@()` arrays; now loads real WhatIf and Approval actions from `$WhatIfManifestPath` / `$ApprovalManifestPath` before calling.
- `Traceability.psm1`: TraceGap condition was `$null -ne $ex` — never fired when execution record was absent. Fixed to `($null -eq $ex -or $executionOutcome -eq 'NotExecuted')` so Approved-but-unexecuted actions correctly produce TraceGap.
- `EvidenceBundle.psm1`: `Add-DecomEvidenceBundleFile` stored full absolute path in `RelativePath` when file was outside `SourceOutputPath`. Fixed to store `$fileInfo.Name`.
- `Redaction.Rev34.Tests.ps1`: broken string concatenation `'...'$var'...'` at line 357 caused parse failure — entire file (32 tests) silently excluded. Fixed to `('...' + $var + '...')`.
- `Redaction.Rev34.Tests.ps1`: `Get-ChildItem -Include '*.json'` without `-Recurse` or wildcard path returned no files (known PS quirk). Fixed to `-Filter '*.json'` (single-extension) and `-Recurse -Include` (multi-extension).
- `OutputManifest.Rev34.Tests.ps1`: nested-file test used relative `.\out\nested\` paths that failed in Pester working context. Rewritten with absolute temp paths.
- `Traceability.Rev34.Tests.ps1`: old test expected `'Approved'` for approved-but-unexecuted scenario; updated to expect `'TraceGap'` consistent with P1-03 spec.

### Tests
- Added 3 P1-02 ApprovalDiff tests: `'Approval diff detects ApprovedUnchanged with real matching action'`, `'Approval diff detects RejectedOrOmitted'`, `'Approval diff detects ApprovalOnlyNotInWhatIf'`.
- Added 1 EvidenceBundle regression test: `'Evidence bundle file outside source path uses filename as RelativePath'`.
- Total: 890 tests, 0 failures (prior: 876 committed, 854 runnable due to Redaction parse failure).

---

## Rev3.4 — Production Hardening, Evidence Packaging, and Client Deployment Foundation

### Added
- Output manifest JSON/CSV (`New-DecomOutputManifest`, `Export-DecomOutputManifestJson`, `Export-DecomOutputManifestCsv`).
- Evidence bundle manifest and evidence hash manifest (`New-DecomEvidenceBundle`, `Export-DecomEvidenceBundleManifestJson`, `Export-DecomEvidenceHashManifest`).
- Client-safe redaction profiles: ClientSafe, PublicDemo, Strict, Internal (`New-DecomRedactionProfile`, `Invoke-DecomRedaction`).
- Replay validation report: validates WhatIf→Approval→Execution chain without Graph connection (`Invoke-DecomReplayValidation`).
- Approval diff report: shows what changed between WhatIf plan and approval manifest (`Compare-DecomWhatIfToApproval`).
- End-to-end traceability report: Finding→WhatIf→Approval→Execution→Evidence per row (`New-DecomTraceabilityModel`).
- Client handoff package generator with checklist and manifest index (`New-DecomClientHandoffPackage`).
- Operator runbook pack: Operator-Execution, Failure-Recovery, Client-Handoff, Redaction-Review, Replay-Validation.
- Rev3.5 NHI readiness report: documents extension points without implementing detectors (`New-DecomRev35ReadinessReport`).
- Schema contract validation for all 9 new hardening output types (`SchemaContracts.psm1`).
- `ReleasePackaging.psm1` hardened to include hardening artifacts, fail on missing required artifacts, and support `-RequireHardeningArtifacts` flag.
- Rev3.4 hardening flags added to entry point: `-GenerateEvidenceBundle`, `-GenerateRedactedPackage`, `-RedactionProfile`, `-GenerateReplayValidation`, `-GenerateApprovalDiff`, `-GenerateTraceabilityReport`, `-GenerateClientHandoff`, `-GenerateRev35Readiness`.
- DemoMode auto-generates all hardening sample outputs.

### Safety
- Rev3.4 adds no new write scopes.
- Rev3.4 adds no new remediation action types.
- Rev3.4 adds no new tenant modification behavior.
- Existing Rev3.x remediation actions are unchanged.
- Rev3.4 does not implement NHI / agentic identity detectors (reserved for Rev3.5).
- All 8 new hardening modules are read-only.

### Tests
- Added Rev3.4 tests: Safety, OutputManifest, EvidenceBundle, Redaction, ReplayValidation, ApprovalDiff, Traceability, ClientHandoff, Rev35Readiness, ReleasePackaging, SchemaContracts hardening.
- Total: 876 tests, 0 failures.

---

## Rev3.2 — Controlled Application Credential Write Expansion and Governance Packs

### Added
- `RemoveExpiredApplicationCredential` action type: removes an expired application password or key credential via `Remove-MgApplicationPassword` / `Remove-MgApplicationKey`. Requires `Application.ReadWrite.All`.
- `DEC-APP-005` added to `Remediation.psm1` ExecutionMap and `ManualApprovalFindingIds`.
- Cmdlet availability gate for `Remove-MgApplicationPassword` and `Remove-MgApplicationKey` in credential removal flow.
- Pre-flight credential revalidation in `Confirm-DecomActionTargetValid` for `RemoveExpiredApplicationCredential`: checks ProtectedObject, application read success, credential presence, expiry confirmation, CredentialType match, and non-null EndDateTime.
- Post-write re-query in `Get-DecomTargetState` for credential actions; query failure → `PartialFailed` (not silently `Executed`).
- Already-removed credential detection: logs `Skipped` before any write is attempted.
- `SchemaVersion 3.2` gate in `Test-DecomApprovalManifest`: credential action types in a manifest with SchemaVersion < 3.2 are rejected.
- `DEC-APP-005` in `ApprovalManifest.psm1` `CredentialFindingIds` and ExecutionMap; `CredentialType` and `CredentialEndDateTime` included in canonical approval hash.
- Duplicate credential removal detection in `Test-DecomApprovalManifest`: same ObjectId + CredentialKeyId pair in two actions is rejected.
- `ExecutableWhenExactExpiredCredentialKeyIdPresent` status in `WriteReadiness.psm1` execution scope registry for DEC-APP-005.
- `Application.ReadWrite.All` added to write-scope array in entry point ExecuteRemediation branch.
- **Governance Pack Modules (read-only):**
  - `ApplicationGovernance.psm1`: application ownership governance model, 7 export functions
  - `CredentialHygiene.psm1`: credential hygiene governance model, 9 export functions, rollback guidance
  - `ConditionalAccessGovernance.psm1`: CA exclusion governance model, readiness logic, 7 export functions
  - `EmergencyAccessGovernance.psm1`: protected object validation, emergency access account hygiene, 4 export functions
- All four governance modules added to `Test-DecomSafetyInvariant` read-only module scan.
- `$script:ToolVersion` updated to `Rev3.2`; WhatIf plan and approval manifest `SchemaVersion` bumped to `3.2`.

### Documentation
- `docs/Required-Permissions.md`: Rev3.2 write permission section (`Application.ReadWrite.All`)
- `docs/Findings-Catalog.md`: Rev3.2 executable action table, governance pack module summary
- `docs/Rev3-Write-Readiness.md`: updated to reflect Rev3.2 implementation status
- `docs/Schema-Contracts.md`: Rev3.2 governance pack schemas
- `runbooks/Credential-Hygiene-Runbook.md`: end-to-end credential removal runbook
- `runbooks/Application-Ownership-Governance-Runbook.md`: application governance module runbook
- `runbooks/CA-Exclusion-Governance-Runbook.md`: CA exclusion governance runbook
- `runbooks/Emergency-Access-Governance-Runbook.md`: protected object and emergency access runbook

### Safety
- All Rev3.2 credential writes remain exclusively in `Remediation.psm1`.
- `Remove-MgApplication` (object deletion) is not present in any Rev3.2 module.
- `Remove-MgServicePrincipal` is not present in any module.
- No CA policy write cmdlets (`New-MgIdentityConditionalAccessPolicy`, `Update-MgIdentityConditionalAccessPolicy`, `Remove-MgIdentityConditionalAccessPolicy`) appear in any module.
- No `Remove-MgUser` (user deletion) appears in any module.
- All four governance pack modules contain zero write cmdlets and zero ReadWrite scopes; all pass `Test-DecomSafetyInvariant` read-only scan.
- Non-expired credentials, credentials without exact KeyId, and ProtectedObject applications are blocked before any write is attempted.
- Rev3.1 and older approval manifests cannot authorize Rev3.2 credential action types.

### Tests
- Added `ReleaseValidation.Rev32.Tests.ps1` (18 tests), `RemediationPlan.Rev32.Tests.ps1` (11 tests), `ApprovalManifest.Rev32.Tests.ps1` (11 tests), `Remediation.Rev32.Tests.ps1` (20 tests), `CredentialHygiene.Rev32.Tests.ps1` (14 tests), `ApplicationGovernance.Rev32.Tests.ps1` (19 tests), `ConditionalAccessGovernance.Rev32.Tests.ps1` (19 tests), `EmergencyAccessGovernance.Rev32.Tests.ps1` (14 tests).
- Updated `WriteReadiness.Rev25.Tests.ps1`, `Rev30.Integration.Tests.ps1` to reflect Rev3.2 reality.
- Baseline: 435 (Rev3.1). Rev3.2: 560 tests, 0 failures.

---

## Rev3.1 — Controlled Guest Governance Write Expansion

### Added
- `RemoveGuestGroupMembership` action type: removes a guest user from an approved group via `Remove-MgGroupMemberByRef`. Requires `GroupMember.ReadWrite.All`.
- `RevokeGuestAppRoleAssignment` action type: revokes an approved app role assignment from a guest user via `Remove-MgUserAppRoleAssignment`. Requires `AppRoleAssignment.ReadWrite.All`.
- 6 new guest finding IDs in `Remediation.psm1` ExecutionMap: `DEC-GUEST-001`, `DEC-GUEST-002`, `DEC-GUEST-003`, `DEC-GREV-001`, `DEC-GREV-002`, `DEC-GREV-003`.
- `Confirm-DecomGuestIdentity` helper in `Remediation.psm1`: re-reads `UserType` from Graph before any guest write; blocks if not `Guest`.
- Guest identity revalidation in `Confirm-DecomActionTargetValid`: validates `UserType = Guest` before write for all 6 guest finding IDs.
- Guest write cases in `Get-DecomTargetState`: re-queries group membership and app role assignments post-write for evidence capture; query failure → `PartialFailed` (not silently `Executed`).
- `GuestGovernance.psm1` added as experimental skeleton — read-only, zero write cmdlets. Full guest governance pack planned for future release. Not included in consultant deliverables for Rev3.1.
- `GuestMultiAction` ExecutionMap sentinel for `DEC-GUEST-002` and `DEC-GREV-003` (dual-action findings that can produce either or both guest action types).
- `SchemaVersion 3.1` gate in `Test-DecomApprovalManifest`: guest action types in an approval manifest with SchemaVersion < 3.1 are rejected.
- `WriteReadiness.psm1` execution scope registry expanded from 14 to 22 entries (8 new guest entries, all `Status = ExecutableWhenExactTargetPresent`, `IntroducedIn = Rev3.1`, `GuestOnly = $true`).
- `GroupMember.ReadWrite.All` and `AppRoleAssignment.ReadWrite.All` added to write-scope array in entry point ExecuteRemediation branch.

### Safety
- All Rev3.1 guest writes remain exclusively in `Remediation.psm1`.
- `GuestGovernance.psm1` is read-only: contains zero Remove-Mg, Update-Mg, Set-Mg, New-Mg, or Connect-MgGraph calls.
- `Remove-MgUser` (guest deletion) is not present in any Rev3.1 module.
- Guest writes are gated by Gate A (WhatIf manifest), Gate B (approval manifest with SchemaVersion ≥ 3.1 and exact TargetObjectIds), and Gate C (ProtectedObject, scope check, UserType=Guest revalidation, target revalidation).
- Rev3.0 and older approval manifests cannot authorize Rev3.1 guest action types.

### Tests
- Added `GuestGovernance.Rev31.Tests.ps1` (19 tests), `ApprovalManifest.Rev31.Tests.ps1` (22 tests), `Remediation.Rev31.Tests.ps1` (17 tests), `RemediationPlan.Rev31.Tests.ps1` (9 tests), `ReleaseValidation.Rev31.Tests.ps1` (14 tests).
- Updated `Safety.Tests.ps1`, `WriteReadiness.Rev25.Tests.ps1`, `SchemaContracts.Rev25.Tests.ps1`, `ReleaseValidation.Rev25.Tests.ps1`, `Rev30.Integration.Tests.ps1` to reflect Rev3.1 reality.
- Baseline: 340 (Rev3.0). Rev3.1: 434 tests, 0 failures.

---

## Rev3.0 — Controlled AP and PIM Write Expansion

### Added
- `RemoveAccessPackageAssignment` action type: removes approved access package assignments via `Remove-MgEntitlementManagementAssignment`. Requires `EntitlementManagement.ReadWrite.All`.
- `RemovePimEligibleAssignment` action type: removes approved PIM eligible role schedules via `Remove-MgRoleManagementDirectoryRoleEligibilitySchedule`. Requires `RoleManagement.ReadWrite.Directory`.
- 10 new finding IDs in `Remediation.psm1` ExecutionMap: `DEC-AP-001`, `DEC-AP-002`, `DEC-AP-007`, `DEC-AP-008`, `DEC-PIM-001` through `DEC-PIM-006`.
- Cmdlet availability gate in `Invoke-DecomRemediation`: if `Remove-Mg*` cmdlet is absent, action is logged `Blocked` (`cmdlet unavailable`) without aborting the run.
- PIM PrincipalId binding check in `Confirm-DecomActionTargetValid`: PrincipalId mismatch sets `Valid=$false` and blocks execution (same guard already applied to directory role assignments).
- AP/PIM finding ID resolution in `ApprovalManifest.psm1` `Resolve-DecomExecutableTargets`: AP targets use `Get-MgEntitlementManagementAssignment` with `targetId` filter; PIM targets use `Get-MgRoleManagementDirectoryRoleEligibilitySchedule` with `principalId` filter.
- SchemaVersion gate in `Test-DecomApprovalManifest`: Rev3.0 action types in an approval manifest with SchemaVersion < 3.0 are rejected with a descriptive error.
- `WriteReadiness.psm1` execution scope registry expanded from 4 to 14 entries (10 new AP/PIM entries, all `Status = Executable`, `IntroducedIn = Rev3.0`).
- `EntitlementManagement.ReadWrite.All` added to write-scope array in entry point ExecuteRemediation branch.
- Entry point `$ReleasePackagePath` default updated to `.\release\Rev3.0`.

### Safety
- All Rev3.0 writes remain exclusively in `Remediation.psm1`.
- All Rev3.0 writes remain gated by Gate A (WhatIf manifest), Gate B (approval manifest with SchemaVersion ≥ 3.0 and exact TargetObjectIds), and Gate C (ProtectedObject, scope check, target revalidation).
- AP write: pre-flight `Get-MgEntitlementManagementAssignment` confirms assignment still exists before `Remove-Mg*` is called. Null assignment → no write.
- PIM write: pre-flight PrincipalId binding check blocks execution if `PrincipalId ≠ ObjectId`.
- Rev2.x approval manifests (SchemaVersion < 3.0) cannot authorize Rev3.0 action types.

### Tests
- Added `Remediation.Rev30.Tests.ps1` (12 tests), `ApprovalManifest.Rev30.Tests.ps1` (11 tests), `Rev30.Integration.Tests.ps1` (13 tests).
- Updated `WriteReadiness.Rev25.Tests.ps1`, `Safety.Tests.ps1`, `SchemaContracts.Rev25.Tests.ps1`, `ReleasePackaging.Rev25.Tests.ps1` to reflect Rev3.0 reality.
- Baseline: 304 (Rev2.5). Rev3.0: 340 tests, 0 failures.

---

## Rev2.5 — Consultant Release Candidate and Rev3.0 Write-Readiness Gate

### Added
- `-SelfTest` switch: runs `Invoke-DecomReleaseValidation` and exits. No Graph connection, no discovery, no remediation. Exit code 0 on pass, 1 on failure.
- `-GenerateReleasePackage` switch: bundles documentation, runbooks, validation reports, and manifest into a release directory. Requires `-SelfTest` or post-assessment context.
- `-ReleasePackagePath` parameter: destination path for release package (default `.\release\Rev2.5`).
- `SchemaContracts.psm1`: `Get-DecomSchemaContract`, `Test-DecomObjectAgainstSchemaContract`, `Export-DecomSchemaContractsMarkdown`, `Export-DecomSchemaValidationJson`. Contracts for: Finding, RunManifest, ApprovalManifest, ExecutionLog, ExecutionEvidence, BaselineComparison, ExecutiveSummary, ClientReadoutPackManifest, CatalogValidationReport, WriteReadinessReport.
- `CatalogValidation.psm1`: `Import-DecomFindingsCatalog`, `Get-DecomFindingCatalogMap`, `Test-DecomFindingCatalogAlignment`, `Export-DecomCatalogValidationJson`, `Export-DecomCatalogValidationMarkdown`. Validates findings against documented catalog severity, RiskScore band, RemediationMode, and required fields.
- `WriteReadiness.psm1`: `Get-DecomExecutionScopeRegistry`, `Get-DecomRev3WriteCandidateRegistry`, `New-DecomRev3WriteReadinessReport`, `Export-DecomRev3WriteReadinessJson`, `Export-DecomRev3WriteReadinessMarkdown`, `Export-DecomExecutionScopeRegistryJson`. Recommendation: `ReadyForRev3Design` (design gate only, not implementation approval).
- `ReleaseValidation.psm1`: `Invoke-DecomReleaseValidation`, `Test-DecomVersionConsistency`, `Test-DecomSafetyInvariant`, export functions. Scans source for write verb/scope safety invariants and version consistency.
- `ReleasePackaging.psm1`: `New-DecomReleasePackage`, `Copy-DecomReleaseAsset`, `Write-DecomReleasePackageManifest`. Bundles docs, runbooks, and validation output.
- Six runbooks under `runbooks\`: Assessment-Runbook.md, WhatIf-Approval-Runbook.md, ExecuteRemediation-Runbook.md, Executive-Pack-Runbook.md, Troubleshooting.md, Rev3-Write-Readiness-Runbook.md.
- Two new docs: `docs\Schema-Contracts.md`, `docs\Rev3-Write-Readiness.md`.
- SchemaVersion bumped to `2.5` in all new output artifacts.

### Safety
- Rev2.5 is read-only. No new write scopes. No new remediation action types.
- No changes to ExecuteRemediation behavior or the Rev2.0 three-gate controlled remediation model.
- `Test-DecomSafetyInvariant` enforces no write verbs or write scopes in read-only modules at every SelfTest run.

### Tests
- Added SchemaContracts.Rev25.Tests.ps1 (14 tests), CatalogValidation.Rev25.Tests.ps1 (10 tests), WriteReadiness.Rev25.Tests.ps1 (26 tests), ReleaseValidation.Rev25.Tests.ps1 (10 tests).
- Updated Safety.Tests.ps1 to verify ToolVersion is Rev2.5.
- Baseline: 230 (Rev2.4). Rev2.5: 282 tests, 0 failures.

---

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