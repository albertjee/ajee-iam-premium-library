# Redaction Model
## Entra Identity Decommissioning Control Plane — Rev3.4

---

## Overview

The redaction subsystem applies deterministic, profile-driven redaction to all output files before they are shared outside the engagement team. Redaction is not optional scrubbing — it is a structured transformation with documented rules, reproducible tokens, and a validation gate that confirms sensitive values do not survive in the output.

Every redacted output carries a `RedactionProfileApplied` field in its metadata so consumers know exactly what rules were in force. The same source data, redacted twice with the same profile, always produces identical tokens — the transformation is deterministic by design.

---

## Functions

| Function | Purpose |
|---|---|
| `New-DecomRedactionProfile` | Constructs a profile object with the specified redaction rules |
| `Invoke-DecomRedaction` | Applies a profile to a source object or file and returns the redacted form |
| `Export-DecomRedactionReportJson` | Writes `RedactionReport.json` — log of all substitutions made |
| `Export-DecomRedactionReportMarkdown` | Writes `RedactionReport.md` — human-readable substitution summary |
| `Test-DecomRedactedOutput` | Scans redacted output for any surviving sensitive values; fails if found |

---

## Redaction Profiles

### Profile: `ClientSafe`

**Intended audience:** Client contact, client IT team, external stakeholders.

Applied automatically to all files included in the client handoff package's main sections and `RedactedOutputs\` directory.

| Data Type | Replacement Token |
|---|---|
| TenantId (GUID) | `[REDACTED_TENANT_ID]` |
| ObjectId GUIDs | `[REDACTED_OBJECT_ID_n]` (sequential per-run, deterministic) |
| AppId GUIDs | `[REDACTED_APP_ID_n]` |
| User Principal Names | `[REDACTED_UPN_n]` |
| Email addresses | `[REDACTED_EMAIL_n]` |
| Service Principal display names | Preserved |
| Severity / risk score fields | Preserved |
| SHA-256 hashes | Preserved |
| RunId | Preserved |
| FindingId / ActionId | Preserved |

### Profile: `PublicDemo`

**Intended audience:** Conference demos, screenshots, public documentation examples.

More aggressive than `ClientSafe` — removes all organization-specific identifiers including display names.

| Data Type | Replacement Token |
|---|---|
| TenantId | `[DEMO_TENANT]` |
| ObjectId GUIDs | `[DEMO_OBJECT_n]` |
| AppId GUIDs | `[DEMO_APP_n]` |
| UPNs | `demo-user-n@demo.contoso.com` |
| Email addresses | `demo-user-n@demo.contoso.com` |
| Display names | `Demo User n` / `Demo App n` / `Demo Group n` |
| Severity / risk score fields | Preserved |
| SHA-256 hashes | `[DEMO_HASH]` |
| RunId | `DEMO-RUN-0000` |

### Profile: `Strict`

**Intended audience:** Legal holds, regulatory submissions, maximum-sensitivity archives.

Redacts everything that could identify a specific organization, user, or object.

| Data Type | Replacement Token |
|---|---|
| TenantId | `[REDACTED_TENANT_ID]` |
| ObjectId GUIDs | `[REDACTED_OBJECT_ID_n]` |
| AppId GUIDs | `[REDACTED_APP_ID_n]` |
| UPNs | `[REDACTED_UPN_n]` |
| Email addresses | `[REDACTED_EMAIL_n]` |
| Display names | `[REDACTED_DISPLAY_NAME_n]` |
| RunId | `[REDACTED_RUN_ID]` |
| HostName | `[REDACTED_HOST]` |
| Severity / risk score fields | Preserved |
| SHA-256 hashes | Preserved |
| FindingId / ActionId | Preserved (codes only, no display names) |

### Profile: `Internal`

**Intended audience:** Engagement team internal review, tool development, QA.

Minimal redaction — only the most sensitive identifiers are masked. Use within the engagement team only; never transmit externally.

| Data Type | Replacement Token |
|---|---|
| TenantId | `[REDACTED_TENANT_ID]` |
| ObjectId GUIDs | Preserved |
| AppId GUIDs | Preserved |
| UPNs | Preserved |
| Email addresses | Preserved |
| Display names | Preserved |
| Severity / risk score fields | Preserved |
| SHA-256 hashes | Preserved |
| RunId | Preserved |

---

## What Gets Redacted

### TenantId

All GUIDs that match the `TenantId` recorded in the run identity section are replaced with `[REDACTED_TENANT_ID]`. This covers inline references in JSON properties, URL fragments (e.g., Graph API URLs containing the tenant GUID), and narrative Markdown text.

```
Before: "TenantId": "11111111-2222-3333-4444-555555555555"
After:  "TenantId": "[REDACTED_TENANT_ID]"
```

### ObjectId GUIDs

Every GUID that appears in an `ObjectId`, `Id`, `UserId`, `GroupId`, `ServicePrincipalId`, `ManagedIdentityId`, or `TargetObjectId` field is assigned a deterministic sequential token within the run. The same GUID always maps to the same token within a single redaction operation.

```
Before: "ObjectId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
After:  "ObjectId": "[REDACTED_OBJECT_ID_1]"
```

If the same GUID appears 12 times across a document, every instance becomes `[REDACTED_OBJECT_ID_1]`. A reviewer can still track that a single object was referenced consistently.

### AppId GUIDs

GUIDs appearing in `AppId`, `ApplicationId`, or `ClientId` fields are replaced with sequential `[REDACTED_APP_ID_n]` tokens using the same deterministic mapping.

### User Principal Names

Strings matching the UPN pattern (`name@domain.tld`) are replaced with `[REDACTED_UPN_n]` tokens. The domain suffix is not preserved in `ClientSafe` or `Strict` profiles to avoid tenant identification via domain.

### Email Addresses

Email addresses (distinct from UPNs where the full address is in a dedicated `Email` field) are replaced with `[REDACTED_EMAIL_n]` tokens. The same email address always maps to the same token within a run.

---

## What Is Always Preserved

Regardless of profile, the following fields are never modified:

- `Severity` (Critical / High / Medium / Low / Informational)
- `RiskScore` (numeric)
- `FindingType` / `FindingCode` (e.g., `DEC-STALE-001`)
- `ActionType` (e.g., `DisableAccount`, `RemoveGroupMembership`)
- SHA-256 hash values
- `FindingId` / `ActionId` (UUID identifiers for findings and actions — not tenant object IDs)
- Timestamps (`ExecutedUtc`, `ApprovedAt`, `GeneratedUtc`)
- `TraceStatus` codes
- `SchemaVersion` / `ToolVersion`

Preserving these fields ensures that a redacted output retains its analytical and audit value — a reviewer can still assess risk severity, verify the trace chain, and validate timestamps without seeing tenant-specific identifiers.

---

## Determinism Guarantee

The token numbering scheme is deterministic within a single call to `Invoke-DecomRedaction`. The mapping is built by scanning the source document in document order (top-to-bottom, left-to-right for JSON keys) and assigning the next available token number to each new GUID or identifier encountered.

**Consequence:** Redacting the same source document twice in the same process call produces identical output. Redacting two different documents independently does not guarantee that the same GUID gets the same token number in both documents — token numbers are local to each redaction call.

If cross-document token consistency is required (e.g., for a multi-file package where the same object should have the same token in every file), pass all source files to a single `Invoke-DecomRedaction` call with the `-MultiFile` switch.

---

## Structure Preservation

Redaction replaces values only — it never changes the structure of the output.

- **JSON:** Key names are never modified. Only values are replaced. Nested objects and arrays are fully traversed.
- **CSV:** Column headers are never modified. Only cell values are replaced. Row count and column count are unchanged.
- **Markdown:** Inline code spans and fenced code blocks are scanned for sensitive values. Heading text and list item text are scanned. Table cell values are replaced; header cells are preserved.
- **HTML:** Text nodes and attribute values are scanned. Tag names and attribute names are never modified. The document structure (DOM) is preserved exactly.

---

## Redaction Report

After redaction, a report is available documenting every substitution made:

```powershell
Export-DecomRedactionReportJson `
    -RedactionResult $result `
    -OutputPath      'C:\DecomOutputs\RedactedOutputs\RedactionReport.json'

Export-DecomRedactionReportMarkdown `
    -RedactionResult $result `
    -OutputPath      'C:\DecomOutputs\RedactedOutputs\RedactionReport.md'
```

`RedactionReport.json` contains:
- Profile applied
- Total substitutions made, broken down by type
- Per-token mapping table (original value hash → token) — the original value is stored as a SHA-256 hash, not in cleartext, to avoid the report itself being a leak
- Files processed and their individual substitution counts

### Validation Gate

```powershell
$validation = Test-DecomRedactedOutput `
    -RedactedPath    'C:\DecomOutputs\RedactedOutputs\' `
    -OriginalBundle  $evidenceBundle `
    -Profile         'ClientSafe'

if (-not $validation.Passed) {
    $validation.LeakedValues | ForEach-Object { Write-Warning "Leak detected: $_" }
}
```

`Test-DecomRedactedOutput` scans the redacted files for any value that appears in the original bundle's sensitive field inventory. It fails with a non-zero count if any original TenantId, ObjectId GUID, UPN, or email address survives in the redacted output. This gate must pass before any file is included in the client handoff package.

---

## Usage Example

```powershell
# Build a ClientSafe profile
$profile = New-DecomRedactionProfile -ProfileName 'ClientSafe'

# Apply to the findings export
$redacted = Invoke-DecomRedaction `
    -SourcePath  'C:\DecomOutputs\Assessment\Findings.json' `
    -Profile     $profile `
    -OutputPath  'C:\DecomOutputs\RedactedOutputs\Findings.ClientSafe.json'

# Validate — must pass before transmission
$check = Test-DecomRedactedOutput `
    -RedactedPath   'C:\DecomOutputs\RedactedOutputs\Findings.ClientSafe.json' `
    -OriginalBundle $evidenceBundle `
    -Profile        'ClientSafe'

Write-Host "Validation passed: $($check.Passed) | Leaks found: $($check.LeakCount)"
```

---

*ToolVersion: Rev3.4 | SchemaVersion: 3.4 | Module: `src\Modules\Redaction.psm1`*
