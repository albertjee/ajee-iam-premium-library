# Evidence Bundle Model
## Entra Identity Decommissioning Control Plane — Rev3.4

---

## Overview

The evidence bundle is the authoritative, tamper-evident record of a decommissioning run. It aggregates every artifact produced during a run — assessment output, WhatIf transcripts, approval manifests, execution logs, baseline exports, and release metadata — and seals the collection with a SHA-256 hash manifest. The bundle is the primary input to replay validation, traceability reporting, and the client handoff package.

An evidence bundle is not a backup of outputs. It is a chain-of-custody record: a complete, ordered set of artifacts that allows an independent reviewer to reconstruct exactly what happened during a run, verify that all actions were pre-authorized, and confirm that the execution record is internally consistent.

---

## Functions

| Function | Purpose |
|---|---|
| `New-DecomEvidenceBundle` | Builds the full bundle object in memory from run artifacts |
| `Export-DecomEvidenceBundleManifestJson` | Writes `EvidenceBundleManifest.json` — machine-readable bundle index |
| `Export-DecomEvidenceBundleIndexMarkdown` | Writes `EvidenceBundleIndex.md` — human-readable section summary |
| `Export-DecomEvidenceHashManifest` | Writes `HashManifest.json` — SHA-256 hashes for every artifact file |
| `Test-DecomEvidenceBundle` | Validates bundle completeness and hash integrity |

---

## Bundle Construction

### Typical Call Pattern

```powershell
$bundle = New-DecomEvidenceBundle `
    -RunId              $runId `
    -AssessmentResult   $assessmentResult `
    -WhatIfTranscripts  $whatIfTranscripts `
    -ApprovalManifest   $approvalManifest `
    -ExecutionLogs      $executionLogs `
    -BaselineExport     $baselineExport `
    -ExecutivePack      $executivePack `
    -ReleaseValidation  $releaseValidation `
    -SchemaContracts    $schemaContracts `
    -OutputManifest     $outputManifest `
    -ToolVersion        'Rev3.4' `
    -SchemaVersion      '3.4'

Export-DecomEvidenceBundleManifestJson -Bundle $bundle -OutputPath $outputDir
Export-DecomEvidenceHashManifest       -Bundle $bundle -OutputPath $outputDir
Export-DecomEvidenceBundleIndexMarkdown -Bundle $bundle -OutputPath $outputDir
```

### Validation

```powershell
$result = Test-DecomEvidenceBundle -BundlePath $outputDir
if (-not $result.IsValid) {
    $result.Failures | ForEach-Object { Write-Warning $_ }
}
```

---

## Bundle Sections

### 1. Run Identity

Fields that uniquely identify the run and the operator:

| Field | Description |
|---|---|
| `RunId` | UUID generated at run start — immutable for the lifecycle of the run |
| `RunStartUtc` | ISO-8601 timestamp when the run began |
| `RunEndUtc` | ISO-8601 timestamp when the bundle was sealed |
| `OperatorUpn` | UPN of the account that executed the run |
| `TenantId` | Azure AD tenant identifier (redacted in client-facing exports) |
| `ToolVersion` | `Rev3.4` |
| `SchemaVersion` | `3.4` |
| `HostName` | Machine name — for audit trail completeness |

### 2. Assessment

The full assessment output: all findings produced by the discovery and analysis phases. Includes finding ID, severity, risk score, finding type, object identifiers, and raw evidence collected from the tenant. This section is the root of the traceability chain — every downstream artifact links back to a `FindingId` from this section.

Output files:
- `Assessment\Findings.json`
- `Assessment\Findings.csv`
- `Assessment\AssessmentSummary.json`

### 3. WhatIf Transcripts

Pre-execution simulation outputs for every remediation action considered. Each transcript records the proposed action, the target object, the expected outcome, and the `WhatIfRunId` that approval records will reference. No changes are made to the tenant during WhatIf — these transcripts prove the simulation was run before any write was attempted.

Output files:
- `WhatIf\WhatIfTranscripts.json`
- `WhatIf\WhatIfSummary.md`

### 4. Approval Manifest

The signed approval record: a JSON document listing every ActionId approved for execution, the approver UPN, the approval ticket reference, the approval timestamp, and a SHA-256 hash of the manifest itself. The manifest hash is the binding link between the approval record and the execution evidence — replay validation checks that every executed action's `ApprovalManifestHash` matches the actual manifest file.

Output files:
- `Approval\ApprovalManifest.json`
- `Approval\ApprovalManifest.hash.txt`

### 5. Execution Logs

Post-execution records: the outcome of every action attempted, the Graph API write cmdlet called, the UTC timestamp of execution, any error detail for failed or blocked actions, and the post-write requery result. This section is the primary source of truth for what actually changed in the tenant.

Output files:
- `Execution\ExecutionLog.json`
- `Execution\ExecutionLog.csv`
- `Execution\PostWriteRequery.json`

### 6. Baseline Export

A point-in-time snapshot of the identity population captured before any remediation writes. Used by replay validation to confirm that TargetObjectIds in the approval manifest matched the actual objects present at execution time.

Output files:
- `Baseline\BaselineExport.json`
- `Baseline\BaselineExportSummary.md`

### 7. Executive Pack

The HTML executive report, finding summary dashboard, and risk posture narrative. These are the primary human-facing outputs from the assessment phase.

Output files:
- `ExecPack\ExecutiveReport.html`
- `ExecPack\FindingSummary.json`
- `ExecPack\RiskNarrative.md`

### 8. Release Validation

The results of all release validation checks run against the tool build used for this engagement. Confirms that the SchemaContracts, OutputManifest, and ReleasePackaging modules were in a valid state when the run was executed.

Output files:
- `Release\ReleaseValidation.json`
- `Release\ReleaseValidation.md`

### 9. Schema Contracts

The registered schema contracts active during the run. Each contract binds a finding family code (e.g., `DEC-STALE-*`, `DEC-PRIV-*`) to a specific schema version. Contracts are immutable once registered — this section proves which schema version governed each finding produced during this run.

Output files:
- `Schema\SchemaContracts.json`
- `Schema\SchemaContracts.md`

### 10. Output Manifest

The complete manifest of all output files produced by this run, including file names, sizes, content types, and SHA-256 hashes. This is the authoritative file inventory for the run and serves as the top-level index for the client handoff package.

Output files:
- `OutputManifest.json`
- `OutputManifest.md`

### 11. Hash Manifest

A flat JSON dictionary mapping every artifact file path (relative to the bundle root) to its SHA-256 hash. This manifest is computed last, after all other sections are written, and seals the bundle. Any modification to any artifact after sealing will cause `Test-DecomEvidenceBundle` to fail.

Output file:
- `HashManifest.json`

### 12. Known Limitations

Explicit documentation of scope exclusions, objects skipped due to policy, API permission gaps, and any conditions where evidence collection was incomplete. This section is required — the bundle is considered incomplete if `KnownLimitations.json` is absent.

Output files:
- `KnownLimitations.json`
- `KnownLimitations.md`

---

## SHA-256 Hash Manifest and Chain of Custody

### How the Hash Manifest Is Built

1. Every artifact file is written to the bundle directory.
2. `Export-DecomEvidenceHashManifest` iterates the complete file tree, computes `SHA256` for each file, and writes `HashManifest.json`.
3. The manifest itself is then hashed and its hash is written to `HashManifest.root.hash.txt`.

This two-level structure means: (a) you can verify any individual file against the manifest, and (b) you can verify the manifest itself against the root hash — confirming the manifest was not tampered with after sealing.

### Verification

```powershell
$result = Test-DecomEvidenceBundle -BundlePath $outputDir

# Example output when valid
# BundleValid   : True
# FilesChecked  : 47
# HashMismatches: 0
# MissingSections: @()
```

### Chain of Custody Properties

- `RunId` appears in every output file's metadata — all artifacts are traceable to a single run.
- `OperatorUpn` is recorded in the run identity section — the human responsible for the run is always identifiable.
- The approval manifest hash ties the approval record to the execution logs — no execution can claim approval that did not exist at signing time.
- The hash manifest seals all artifacts after run completion — any post-run modification is detectable.

---

## Bundle Directory Structure

```
EvidenceBundle\
  EvidenceBundleManifest.json     ← bundle metadata and section inventory
  EvidenceBundleIndex.md          ← human-readable section summary
  HashManifest.json               ← SHA-256 hashes for all artifact files
  HashManifest.root.hash.txt      ← hash of HashManifest.json itself
  OutputManifest.json             ← complete file inventory with hashes
  Assessment\
    Findings.json
    Findings.csv
    AssessmentSummary.json
  WhatIf\
    WhatIfTranscripts.json
    WhatIfSummary.md
  Approval\
    ApprovalManifest.json
    ApprovalManifest.hash.txt
  Execution\
    ExecutionLog.json
    ExecutionLog.csv
    PostWriteRequery.json
  Baseline\
    BaselineExport.json
    BaselineExportSummary.md
  ExecPack\
    ExecutiveReport.html
    FindingSummary.json
    RiskNarrative.md
  Release\
    ReleaseValidation.json
    ReleaseValidation.md
  Schema\
    SchemaContracts.json
    SchemaContracts.md
  KnownLimitations.json
  KnownLimitations.md
```

---

*ToolVersion: Rev3.4 | SchemaVersion: 3.4 | Module: `src\Modules\EvidenceBundle.psm1`*
