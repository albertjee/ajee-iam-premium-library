# Redaction Review Runbook
## Entra Identity Decommissioning Control Plane — Rev3.4

**Audience:** Identity governance consultants  
**Purpose:** Guide for reviewing and approving redacted outputs before client delivery  
**Tool:** `Invoke-EntraIdentityDecommissioningControlPlane.ps1`

---

## Overview

Redaction replaces sensitive identifiers (GUIDs, UPNs, email addresses, hashes) with deterministic tokens before outputs are shared. Determinism means the same source value always maps to the same token within a single redaction run. This allows reviewers to cross-reference tokenized values across files without re-exposing raw identifiers.

Redaction produces a `redaction-report-*.json` that records what was redacted (counts and profile settings) but does not record the token-to-value map itself. The raw token map exists only in memory during the run and is not persisted to disk.

---

## The Four Redaction Profiles

### ClientSafe (recommended for most engagements)

Suitable for delivering to the client organization. Removes the identifiers most likely to cause privacy or security exposure while preserving structure and context.

**What is redacted:**
- Tenant IDs (GUID) — replaced with `[REDACTED_TENANT_ID]`
- Object IDs (user, group, application, service principal GUIDs) — replaced with `[REDACTED_OBJECT_ID_n]`
- Application IDs (GUIDs) — replaced with `[REDACTED_OBJECT_ID_n]` (treated as object IDs in sequence)
- UPNs — replaced with `[REDACTED_UPN_n]`
- Email addresses — replaced with `[REDACTED_UPN_n]`

**What is preserved:**
- Display names (e.g., "Alice Johnson", "Marketing App")
- RunIds
- Severity and risk score fields
- JSON structure and field names
- Non-identifier numeric values

**When to use:** Standard client delivery. Use when the client is expected to recognize their own object names but must not have access to raw GUIDs or UPNs that could be used to query their tenant directly.

---

### PublicDemo (for demonstrations and samples)

Suitable for conference presentations, training materials, and tool demonstrations where no real tenant data should appear.

**What is redacted:**
- Everything in `ClientSafe`, plus:
- Display names — replaced with `[REDACTED_DISPLAY_NAME_n]`

**What is preserved:**
- RunIds
- Hashes (SHA-256 values in evidence files)
- Severity labels, risk scores, action types

**When to use:** Blog posts, screenshots, training environments, demo recordings. Do not use for actual client deliveries — display names are removed, which reduces the usefulness of the output for the client's own context.

---

### Strict (maximum removal)

Suitable for situations where the output will be stored in a lower-trust location, submitted to a third party, or shared publicly without any identifiable association to the engagement.

**What is redacted:**
- Everything in `PublicDemo`, plus:
- RunIds — replaced with `[REDACTED_RUN_ID]`
- SHA-256 hashes (64-character hex strings) — replaced with `[REDACTED_HASH]`

**What is preserved:**
- Severity labels, risk scores, action types, timestamps
- JSON structure

**When to use:** Regulatory submissions, public disclosures, external auditor review where engagement identity must not be traceable. Note that redacting RunIds makes replay validation cross-referencing impossible.

---

### Internal (consultant use only)

Suitable for internal team review within the consulting organization. No identifiers are removed.

**What is redacted:** Nothing. All identifiers are preserved.

**What is preserved:** Everything.

**When to use:** Internal peer review, QA, evidence retention. Do not include in any client delivery or external communication.

---

## Step 1: Invoke Redaction

Add `-GenerateRedactedPackage` and `-RedactionProfile` to any Assessment run:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -GenerateRedactedPackage `
    -RedactionProfile ClientSafe
```

For a public demo output:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -GenerateRedactedPackage `
    -RedactionProfile PublicDemo
```

**Expected output:**

```
[OK]  Redaction report: .\out\20260602_143000\redaction-report-20260602_143000.json
```

---

## Step 2: Review the redaction-report.json

The redaction report records what was redacted. Load and inspect it:

```powershell
$report = Get-Content ".\out\20260602_143000\redaction-report-20260602_143000.json" -Raw | ConvertFrom-Json
$report | Select-Object ProfileName, TokenCount, RedactedFileCount

# View the summary breakdown
$report.Summary | Format-List
```

**Sample output:**

```
ProfileName      : ClientSafe
TokenCount       : 47
RedactedFileCount: 5

TenantIdsRedacted    : 1
ObjectIdsRedacted    : 31
AppIdsRedacted       : 0
UpnsRedacted         : 12
EmailsRedacted       : 3
DisplayNamesRedacted : 0
RedactDisplayNames   : False
RedactRunId          : False
RedactHashes         : False
```

**What to check:**

- `TenantIdsRedacted` should be exactly 1 for most engagements. If 0, the tenant ID was not found in the outputs — verify the assessment actually wrote the tenant ID to the findings JSON.
- `ObjectIdsRedacted` should be greater than 0 if the assessment found any findings with target objects.
- `UpnsRedacted` count should be consistent with the number of users in scope.
- `TokenCount` is the total unique identifier values replaced. A very low token count (< 5) on a large tenant assessment is a signal that the redaction may not have processed the findings file correctly.

---

## Step 3: Verify Deterministic Token Mapping

Deterministic token mapping means the same source GUID always gets the same `[REDACTED_OBJECT_ID_n]` token within a single run. This is critical for cross-file consistency — if a finding references the same user in both the findings JSON and the traceability report, both files should show the same token.

**To verify consistency manually:**

1. Take a known GUID from the original findings JSON (before redaction):
   ```powershell
   $originalFindings = Get-Content ".\out\20260602_143000\entra-decommissioning-control-plane-findings-20260602_143000.json" -Raw | ConvertFrom-Json
   # Pick any finding's ObjectId
   $sampleGuid = $originalFindings.Findings[0].ObjectId
   Write-Host "Sample GUID: $sampleGuid"
   ```

2. Search the redacted output for that GUID — it should not appear:
   ```powershell
   # Check that no raw GUID appears in the redacted report
   $redactedContent = Get-Content ".\out\20260602_143000\redaction-report-20260602_143000.json" -Raw
   if ($redactedContent -match $sampleGuid) {
       Write-Warning "Raw GUID found in redacted output — redaction may have failed"
   } else {
       Write-Host "[OK] No raw GUID found in redacted report" -ForegroundColor Green
   }
   ```

3. Confirm the token for that GUID appears consistently across all redacted files from the same run (traceability, replay validation, client handoff index).

Note: Token mapping is specific to a single run invocation. If you re-run with `-GenerateRedactedPackage`, a new run will produce new token assignments. The mapping is not persisted between runs.

---

## Step 4: What to Check Before Sharing with Client

Complete this review for every file in the `RedactedClientSafe` / `ClientSafeFiles` list before placing it in the client delivery folder.

### Check 1: No raw GUIDs remaining in client-safe files

```powershell
$guidPattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

Get-ChildItem ".\out\20260602_143000\" -Include "*.json","*.csv","*.md" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    $matches = [System.Text.RegularExpressions.Regex]::Matches($content, $guidPattern)
    if ($matches.Count -gt 0) {
        Write-Warning "Raw GUID found in: $($_.Name) ($($matches.Count) occurrence(s))"
    }
}
```

For client-safe files, any GUID found should be a `[REDACTED_*]` token, not a raw hex GUID. Raw GUIDs in client-safe files require re-running redaction.

### Check 2: Severity and risk fields are preserved

The client needs to see severity labels and risk scores to understand the finding priority. Verify these are not inadvertently tokenized:

```powershell
$sample = Get-Content ".\out\20260602_143000\entra-decommissioning-control-plane-findings-20260602_143000.json" -Raw | ConvertFrom-Json
$sample.Findings[0] | Select-Object Severity, RiskScore
```

Severity values should be `Critical`, `High`, `Medium`, `Low`, or `Informational`. Risk scores should be numeric. If these appear as `[REDACTED_*]` tokens, the redaction profile is too aggressive for the intended use — switch to `ClientSafe` from `Strict` or `PublicDemo`.

### Check 3: JSON structure is valid

Redaction operates on the raw string content of files. Malformed JSON after redaction is possible if a replacement token contains characters that break JSON string encoding (rare but worth checking):

```powershell
try {
    Get-Content ".\out\20260602_143000\entra-decommissioning-control-plane-findings-20260602_143000.json" -Raw | ConvertFrom-Json | Out-Null
    Write-Host "[OK] JSON structure valid after redaction" -ForegroundColor Green
} catch {
    Write-Warning "JSON parse error after redaction: $_"
}
```

### Check 4: No raw UPNs or email addresses in HTML reports

The HTML report renders finding details. Check that UPNs in rendered content are tokenized:

```powershell
$htmlContent = Get-Content ".\out\20260602_143000\entra-decommissioning-control-plane-report-20260602_143000.html" -Raw
$upnPattern = '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}'
$upns = [System.Text.RegularExpressions.Regex]::Matches($htmlContent, $upnPattern)
if ($upns.Count -gt 0) {
    Write-Warning "Possible UPNs remaining in HTML report: $($upns.Count) match(es)"
    $upns | Select-Object -First 5 -ExpandProperty Value
}
```

Note: The tool links do not apply `Invoke-DecomRedaction` to the HTML report directly — the HTML report renders finding data from the in-memory findings object. If the HTML was generated before redaction was applied to the findings JSON, the HTML will contain raw values. The `-GenerateRedactedPackage` flag redacts the JSON outputs; the HTML report is considered a presentation layer. Always verify the HTML before client delivery if UPNs or object IDs may appear in finding details.

---

## Sign-off Checklist

Complete and document the following before moving any file to the client delivery folder:

- [ ] `redaction-report-*.json` reviewed — token counts are consistent with tenant size
- [ ] `TenantIdsRedacted` = 1
- [ ] `ObjectIdsRedacted` > 0 (if findings exist)
- [ ] No raw GUIDs found in client-safe JSON files
- [ ] No raw UPNs or email addresses in client-safe files
- [ ] Severity and risk score fields are numeric/labeled (not tokenized)
- [ ] JSON files parse without error after redaction
- [ ] HTML report reviewed in browser — no raw identifiers visible in rendered output
- [ ] `ClientSafe` profile confirmed (or `Strict` if required by engagement contract)
- [ ] Redaction run was for the same run as the files being delivered (same timestamp folder)
- [ ] Internal (unredacted) copies retained securely in evidence bundle

**Reviewer:** _____________________  
**Date:** _____________________  
**EngagementId:** _____________________  
**RunId:** _____________________

---

*Entra Identity Decommissioning Control Plane Rev3.4 — Redaction Review Runbook*
