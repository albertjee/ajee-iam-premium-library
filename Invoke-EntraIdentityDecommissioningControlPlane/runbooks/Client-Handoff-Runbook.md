# Client Handoff Runbook
## Entra Identity Decommissioning Control Plane — Rev3.4

**Audience:** Identity governance consultants  
**Purpose:** Step-by-step guide for packaging and delivering findings to the client  
**Tool:** `Invoke-EntraIdentityDecommissioningControlPlane.ps1`

---

## Overview

The client handoff package is a structured collection of outputs from the engagement. It separates what is safe to share with the client from what must remain restricted to the consulting team. Generating the package does not transmit any files — it produces a manifest and index that the consultant uses to assemble and review the delivery.

The handoff workflow has four stages:

1. Generate the handoff package manifest during the assessment run
2. Prepare redacted (client-safe) copies of findings outputs
3. Review the checklist to confirm all sensitive data is excluded
4. Deliver the approved client-safe files

---

## What the Client Handoff Package Contains

The package is organized into sections. Each section maps to a category of engagement output:

| Section | Contents | Sensitivity |
|---|---|---|
| `AssessmentReports` | HTML and CSV assessment reports | Client-safe (no raw identifiers in HTML) |
| `FindingsExports` | Raw findings JSON and CSV with GUIDs and UPNs | Sensitive — do not share without redaction |
| `RemediationPlan` | Markdown remediation plan | Typically client-safe; review before sharing |
| `WhatIfApprovalEvidence` | WhatIf action plan and approval manifest | Sensitive — contains approval signatures |
| `ExecutionEvidence` | Execution evidence CSV and JSON | Sensitive — contains full object ID records |
| `TraceabilityReport` | Traceability chain JSON and CSV | Sensitive — contains finding-to-action mapping with identifiers |
| `ReplayValidation` | Replay validation report | Sensitive — share only when all checks pass |
| `RedactedClientSafe` | Redacted copies of findings and evidence | Client-safe — preferred for all sharing |
| `Runbooks` | Operator runbooks | Client-safe |

The package manifest identifies which files are in `ClientSafeFiles` vs `SensitiveFiles`. The rule is simple: share only what is in `ClientSafeFiles`, plus any files explicitly moved to `RedactedClientSafe` after redaction review.

---

## Step 1: Generate the Client Handoff Package

Add `-GenerateClientHandoff` to any Assessment or ExecuteRemediation run:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -GenerateClientHandoff
```

**Expected output:**

```
[OK]  Client handoff manifest: .\out\20260602_143000\client-handoff-manifest-20260602_143000.json
[OK]  Client handoff index: .\out\20260602_143000\client-handoff-index-20260602_143000.md
```

The manifest JSON contains the full package structure. The index markdown is a human-readable version suitable for review without specialized tooling.

---

## Step 2: Generate with Redaction

For most engagements, raw findings contain customer tenant GUIDs, UPNs, and application IDs that must be redacted before sharing. Generate both the handoff package and the redacted outputs together:

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -TenantId "contoso.onmicrosoft.com" `
    -EngagementId "ENG-2026-001" `
    -ClientName "Contoso Ltd" `
    -Assessor "Albert Jee" `
    -OutputPath ".\out" `
    -GenerateClientHandoff `
    -GenerateRedactedPackage `
    -RedactionProfile ClientSafe
```

The `ClientSafe` profile redacts:
- All tenant IDs (GUIDs in tenant context)
- All object IDs (user, group, application, service principal GUIDs)
- All application IDs
- All UPNs
- All email addresses

Display names, RunIds, and hashes are preserved under `ClientSafe`. Use `Strict` if those must also be removed (see Redaction Review Runbook for full profile details).

**Expected output includes:**

```
[OK]  Redaction report: .\out\20260602_143000\redaction-report-20260602_143000.json
[OK]  Client handoff manifest: .\out\20260602_143000\client-handoff-manifest-20260602_143000.json
[OK]  Client handoff index: .\out\20260602_143000\client-handoff-index-20260602_143000.md
```

---

## Step 3: Files Safe to Share vs. Files That Must Stay Restricted

### Safe to share with the client

- `*-report-*.html` — HTML assessment report (severity labels and risk scores; no raw GUIDs or UPNs)
- `*-remediation-plan-*.md` — Remediation plan in Markdown
- `*-executive-summary-*.html` — Executive summary (if generated)
- `*-executive-summary-*.md`
- `redaction-report-*.json` — Redaction summary (token counts, no raw values)
- Files in the `RedactedClientSafe` section of the handoff package
- Runbook files from `runbooks\`
- `rev35-readiness-report-*.json` — Rev3.5 readiness assessment (no identifiers)

### Must stay restricted (do not share in raw form)

- `*-findings-*.json` — Raw findings JSON with full GUIDs, UPNs, and display names
- `*-assessment-*.csv` — Raw findings CSV
- `*-baseline-comparison-*.json` — Baseline comparison with historical identifiers
- `execution-evidence-*.json` — Full execution evidence with ObjectIds
- `execution-evidence-*.csv`
- `execution-manifest-*.json`
- `approval-diff-report-*.json` — Approval diff with action IDs
- `traceability-report-*.json` — Traceability with finding-to-action ObjectId chains
- `evidence-bundle\*` — Evidence bundle with file hashes linked to raw outputs

---

## Step 4: Review the Client Handoff Checklist

Open the client-handoff-index markdown to review the package state:

```powershell
# View the index in a text editor or browser
Invoke-Item ".\out\20260602_143000\client-handoff-index-20260602_143000.md"
```

The index will display any warnings generated by the tool. Common warnings:

**Warning: ValidationStatus is NotValidated**

The replay validation report has not been generated or has not passed. Before delivering the package:
- Run with `-GenerateReplayValidation` and confirm all 10 checks pass.
- See the Replay Validation Runbook for instructions.

**Warning: No RedactedFiles provided**

No redacted outputs were included in the package. This means the `RedactedClientSafe` section is empty and raw sensitive files are the only available outputs.
- Re-run with `-GenerateRedactedPackage -RedactionProfile ClientSafe`.
- After review (see Redaction Review Runbook), move approved redacted files into the client delivery folder.

### Handoff checklist (complete before delivery)

- [ ] Assessment HTML report reviewed — no raw identifiers visible in rendered output
- [ ] Remediation plan reviewed for accuracy and completeness
- [ ] Executive summary reviewed and approved by lead consultant
- [ ] Redacted findings generated with `ClientSafe` or `Strict` profile
- [ ] Redaction report reviewed — token counts match expected identifier volume
- [ ] Replay validation passed all 10 checks (or known exceptions documented)
- [ ] `SensitiveFiles` list reviewed — none of these files are in the delivery folder
- [ ] `ClientSafeFiles` list reviewed — all of these files are accounted for
- [ ] Rev3.5 readiness note prepared for next-engagement discussion
- [ ] Client delivery folder contains only client-safe outputs

---

## Step 5: Sample Client Handoff Talking Points

When presenting findings and delivering the package, use the following structure:

**Opening (executive summary):**
"Based on our assessment of your Entra ID tenant, we identified [N] findings across [N] identity governance areas. The highest-priority items are [CRITICAL/HIGH summary]. We have documented all findings with evidence and have prepared a remediation plan."

**Remediation evidence:**
"For each remediation action we performed, we maintained a complete execution log with before-and-after evidence. We can provide the execution report showing exactly what changed, when it changed, and the approval that authorized it."

**What we are delivering:**
- Assessment report (HTML) — severity-rated findings with remediation guidance
- Remediation plan (Markdown) — prioritized action items with effort estimates
- Executive summary — governance posture overview for leadership review
- [If applicable] Execution report — post-remediation evidence with action log

**What stays with the consulting team:**
"We retain the raw technical data — object IDs, credential hashes, approval manifests — as part of our engagement evidence record. These are not included in your delivery package but are available upon request under formal evidence handling procedures."

**Rev3.5 readiness:**
"Our tooling now includes a Rev3.5 readiness assessment. Based on your current environment, [summarize rev35-readiness-report findings]. Non-human identity and agentic identity audit capabilities are available for your next engagement."

---

## Known Limitations to Communicate to the Client

1. **Assessment scope is point-in-time.** The assessment reflects the state of the tenant at the time the tool was run. Changes made after the assessment run are not reflected in the findings.

2. **Remediation evidence requires tenant connectivity.** Execution evidence is generated during the live run. It cannot be reconstructed retroactively from the assessment alone.

3. **Redaction is deterministic but not reversible.** Once outputs are redacted and delivered, the token-to-value mapping is held only in the consultant's evidence bundle. If an identifier needs to be traced back, the raw output in the evidence bundle must be consulted.

4. **Executive pack requires assessment data.** If `-GenerateExecutivePack` was not specified during the assessment run, the executive summary cannot be regenerated from an existing findings file without re-running the assessment.

5. **Rev3.5 readiness is advisory only.** The Rev3.5 readiness report identifies gaps relative to the planned Rev3.5 scope (NHI/agentic identity governance). It is not an audit finding and does not indicate a compliance failure.

---

## Rev3.5 Readiness Note for Next Engagement

The `rev35-readiness-report-*.json` generated by `-GenerateRev35Readiness` documents the current environment's readiness for the Rev3.5 NHI (Non-Human Identity) and agentic identity governance capabilities planned for the next major tool release.

Review this report before the next engagement scoping call:

```powershell
$readiness = Get-Content ".\out\20260602_143000\rev35-readiness-report-20260602_143000.json" -Raw | ConvertFrom-Json
$readiness | Select-Object ToolVersion, Passed, CheckCount, FailedChecks
```

Items that are not ready should be noted in the engagement close-out documentation and presented to the client as scope items for the next engagement.

---

*Entra Identity Decommissioning Control Plane Rev3.4 — Client Handoff Runbook*
