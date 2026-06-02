# Rev3.5 NHI / Agentic Identity Audit Readiness
## Entra Identity Decommissioning Control Plane — Rev3.4

---

## IMPORTANT: Scope Boundary

**Rev3.4 does NOT implement NHI (Non-Human Identity) detectors or agentic identity audit capabilities.**

NHI detection — coverage of managed identities, service principals acting as autonomous agents, workload identity federation, and agentic credential patterns — is reserved for Rev3.5. Rev3.4's role is to put the necessary infrastructure in place so that Rev3.5 can be implemented without requiring breaking changes to the existing evidence model, schema contract registry, output manifest, or redaction subsystem.

Do not interpret any function or output in this document as an active NHI audit capability. These are readiness checks — they verify that the Rev3.4 build is structurally prepared for Rev3.5 to be layered on top.

---

## Background: Why NHI Requires Separate Coverage

Human identity decommissioning (accounts, group memberships, app roles, licenses, device assignments) follows a predictable lifecycle: the account exists, is assessed, is approved for decommissioning, and is acted upon. The actor is always a human, the credential type is always a password or MFA factor, and the authorization model is always user-centric.

Non-human identities introduce distinct patterns:

- **Managed identities** have no password and no MFA — credential hygiene checks do not apply, but permission scope and assignment drift do
- **Service principals** may be assigned app roles, delegated permissions, API keys, and certificates simultaneously — each credential type has its own expiry and risk profile
- **Agentic service principals** (SPs backing autonomous AI agents) introduce claim-safety requirements — an agent's token claims must be validated against the operations it is authorized to perform
- **Workload identity federation** creates trust relationships between Azure AD and external identity providers — federation configuration drift is a novel risk category with no analogue in human identity hygiene

Rev3.5 will introduce finding families `DEC-NHI-*` and `DEC-AGENT-*` to cover these patterns. Rev3.4 ensures the infrastructure to support them exists.

---

## Rev3.5 Readiness Functions

| Function | Purpose |
|---|---|
| `New-DecomRev35ReadinessReport` | Runs all 8 readiness checks and returns a structured result object |
| `Export-DecomRev35ReadinessJson` | Writes `Rev35Readiness.json` — machine-readable check results |
| `Export-DecomRev35ReadinessMarkdown` | Writes `Rev35Readiness.md` — human-readable readiness summary |
| `Test-DecomRev35Readiness` | Convenience function — runs all checks and returns `$true` if all pass |

### Usage

```powershell
$readiness = New-DecomRev35ReadinessReport `
    -EvidenceBundle    $evidenceBundle `
    -OutputManifest    $outputManifest `
    -SchemaContracts   $schemaContracts `
    -ToolVersion       'Rev3.4' `
    -SchemaVersion     '3.4'

Export-DecomRev35ReadinessJson     -Report $readiness -OutputPath $outputDir
Export-DecomRev35ReadinessMarkdown -Report $readiness -OutputPath $outputDir

$isReady = Test-DecomRev35Readiness -Report $readiness
Write-Host "Rev3.5 readiness: $isReady"
```

---

## The 8 Readiness Checks

### Check 1 — Output Manifest Supports Future NHI Outputs

**What it verifies:** The output manifest schema (v3.4) includes a `FutureCapabilitySlots` array that can accommodate NHI-specific output types (`NHIFindings.json`, `AgentClaimAudit.json`, `WorkloadFederationDrift.csv`) without a schema version bump.

**Why it matters:** Rev3.5 must be able to register new output types in the manifest without invalidating existing manifests from Rev3.4 runs. The `FutureCapabilitySlots` design ensures backward compatibility.

**Pass condition:** `OutputManifest.SchemaVersion` is `3.4` and `FutureCapabilitySlots` is present as an array (may be empty).

**Check ID:** `NHI-READY-001`

---

### Check 2 — Schema Contracts Can Register DEC-NHI-* and DEC-AGENT-* Families

**What it verifies:** The schema contract registry supports registration of finding family codes matching the patterns `DEC-NHI-*` and `DEC-AGENT-*` without conflicting with any existing registered family.

**Why it matters:** Rev3.5 finding codes must not collide with existing Rev3.x finding codes. This check confirms the namespace is clean and registration will succeed when Rev3.5 modules are loaded.

**Pass condition:** No existing registered contract has a family code prefixed with `DEC-NHI-` or `DEC-AGENT-`. The registry's code space is available for Rev3.5.

**Check ID:** `NHI-READY-002`

---

### Check 3 — Finding Catalog Has Reserved Namespace Note

**What it verifies:** The finding catalog output (`FindingCatalog.json`) produced by this run includes a `ReservedNamespaces` entry documenting that `DEC-NHI-*` and `DEC-AGENT-*` are reserved for Rev3.5.

**Why it matters:** Without an explicit reservation, a future finding code could accidentally be assigned from the NHI namespace in a Rev3.4 patch. The reserved namespace note prevents namespace pollution.

**Pass condition:** `FindingCatalog.ReservedNamespaces` contains entries for `DEC-NHI-*` and `DEC-AGENT-*` with `ReservedForRevision: "Rev3.5"`.

**Check ID:** `NHI-READY-003`

---

### Check 4 — Executive Dashboard Can Link Future NHI Dashboards

**What it verifies:** The HTML executive report template includes a `FutureDashboardLinks` placeholder section that Rev3.5 can populate with NHI-specific dashboard links without requiring a template rewrite.

**Why it matters:** The executive report is the primary human-facing output. Rev3.5 should be able to add NHI findings to the existing report rather than generating a separate, disconnected document.

**Pass condition:** `ExecutiveReport.html` contains the `<!-- NHI-DASHBOARD-PLACEHOLDER -->` comment marker at the appropriate location in the findings summary section.

**Check ID:** `NHI-READY-004`

---

### Check 5 — Redaction Supports Service Principal and App IDs

**What it verifies:** The `ClientSafe` and `Strict` redaction profiles include redaction rules covering `ServicePrincipalId`, `ManagedIdentityId`, and `ClientId` field types in addition to the human identity fields (`ObjectId`, `UPN`, `Email`).

**Why it matters:** NHI findings will reference service principal IDs, managed identity object IDs, and app registration client IDs. These are sensitive identifiers that must be redacted in client-facing exports — they can be used to enumerate the client's application portfolio.

**Pass condition:** `New-DecomRedactionProfile -ProfileName ClientSafe` includes `ServicePrincipalId`, `ManagedIdentityId`, and `ClientId` in its `SensitiveFieldTypes` list. `New-DecomRedactionProfile -ProfileName Strict` also covers these types.

**Check ID:** `NHI-READY-005`

---

### Check 6 — Coverage Model Has NHI Placeholder

**What it verifies:** The coverage model document (`ReleaseValidation.json`) includes a `PlannedCoverageExpansions` entry documenting NHI/agentic identity as a planned Rev3.5 addition.

**Why it matters:** Release validation checks confirm that the tool covers what it claims to cover. Rev3.4's release validation must acknowledge that NHI coverage is not present but is planned — this prevents the coverage model from appearing more complete than it is.

**Pass condition:** `ReleaseValidation.PlannedCoverageExpansions` contains an entry with `Revision: "Rev3.5"` and `Domain: "NHI/AgenticIdentity"`.

**Check ID:** `NHI-READY-006`

---

### Check 7 — Claim-Safety Validator Placeholder Is Registered

**What it verifies:** The schema contract registry includes a placeholder entry for the `DEC-AGENT-CLAIM-SAFETY` validator contract, marked with `Status: Reserved` and `ImplementedIn: "Rev3.5"`.

**Why it matters:** Claim-safety validation — verifying that an agentic service principal's token claims align with its authorized operations — is a Rev3.5 capability. Registering the placeholder in Rev3.4 ensures the contract ID is stable before implementation, preventing breaking changes when Rev3.5 ships.

**Pass condition:** `SchemaContracts` contains an entry with `FamilyCode: "DEC-AGENT-CLAIM-SAFETY"`, `Status: "Reserved"`, and `ImplementedIn: "Rev3.5"`.

**Check ID:** `NHI-READY-007`

---

### Check 8 — Rev3.5 Prompt Reference Is Documented

**What it verifies:** The `KnownLimitations.md` file produced by this run includes an explicit note that NHI/Agentic Identity Audit coverage is not in scope for Rev3.4 and references Rev3.5 as the planned delivery vehicle.

**Why it matters:** Known limitations are a required section of every evidence bundle. Clients who review the known limitations document must be clearly informed that NHI is not covered, so they do not assume their service principal population has been audited.

**Pass condition:** `KnownLimitations.md` contains the phrase "NHI/Agentic Identity Audit coverage is reserved for Rev3.5" (case-insensitive).

**Check ID:** `NHI-READY-008`

---

## Readiness Check Summary Table

| CheckId | Description | Pass Condition |
|---|---|---|
| `NHI-READY-001` | Output manifest supports future NHI outputs | `FutureCapabilitySlots` array present |
| `NHI-READY-002` | Schema contracts namespace clean for DEC-NHI-* / DEC-AGENT-* | No existing contract in NHI/AGENT namespace |
| `NHI-READY-003` | Finding catalog has reserved namespace note | `ReservedNamespaces` entries for Rev3.5 |
| `NHI-READY-004` | Executive dashboard can link future NHI dashboards | Placeholder comment present in HTML template |
| `NHI-READY-005` | Redaction covers SP/App IDs | `ServicePrincipalId`, `ManagedIdentityId`, `ClientId` in profile |
| `NHI-READY-006` | Coverage model has NHI placeholder | `PlannedCoverageExpansions` entry for Rev3.5 |
| `NHI-READY-007` | Claim-safety validator placeholder registered | `DEC-AGENT-CLAIM-SAFETY` reserved in schema contracts |
| `NHI-READY-008` | Rev3.5 prompt reference in known limitations | NHI/Rev3.5 reference present in `KnownLimitations.md` |

---

## Readiness Result Object

```json
{
  "ToolVersion": "Rev3.4",
  "SchemaVersion": "3.4",
  "ReportGeneratedUtc": "...",
  "RunId": "...",
  "OverallReadiness": "Ready",
  "ChecksRun": 8,
  "ChecksPassed": 8,
  "ChecksFailed": 0,
  "FailedChecks": [],
  "NhiImplemented": false,
  "NhiReservedForRevision": "Rev3.5",
  "CheckDetails": [ ... ]
}
```

`NhiImplemented: false` is always the expected value for a Rev3.4 run. If this field ever returns `true` in a Rev3.4 build, it indicates a configuration error — NHI detectors should not be active in this revision.

---

## Output Files

| File | Description |
|---|---|
| `Rev35Readiness.json` | Machine-readable readiness check results |
| `Rev35Readiness.md` | Human-readable readiness summary — included in client handoff package as `Rev35ReadinessNote.md` |

---

## What Rev3.5 Will Add

The following capabilities are planned for Rev3.5 and are NOT present in Rev3.4:

- **DEC-NHI-001** — Managed Identity Permission Scope Excess (system-assigned and user-assigned)
- **DEC-NHI-002** — Service Principal Stale Credential (expired certificates and secrets on non-human accounts)
- **DEC-NHI-003** — Workload Identity Federation Configuration Drift
- **DEC-NHI-004** — Managed Identity Without Resource Lock
- **DEC-AGENT-001** — Agentic Service Principal Over-Privileged Role Assignment
- **DEC-AGENT-002** — Claim-Safety Validator — token claim scope vs. authorized operations mismatch
- **DEC-AGENT-003** — Agentic Identity Without Conditional Access Policy Binding

Rev3.5 will consume the infrastructure put in place by Rev3.4 (evidence bundle, schema contracts, output manifest, redaction profiles, traceability model) without requiring changes to any of those components.

---

*ToolVersion: Rev3.4 | SchemaVersion: 3.4 | Module: `src\Modules\Rev35Readiness.psm1`*
