# Credential Hygiene Runbook — Rev3.2

## Overview

Rev3.2 adds `RemoveExpiredApplicationCredential` as a controlled write action for DEC-APP-005 findings. This runbook covers assessment, WhatIf plan generation, approval, and execution for expired application credential removal.

---

## Finding IDs Covered

| FindingId | Description | Severity | Action Available |
|---|---|---|---|
| DEC-APP-004 | Application credential expiring soon | Medium | Plan-only (observe, no removal) |
| DEC-APP-005 | Application has expired credential attached | High | `RemoveExpiredApplicationCredential` (Rev3.2) |

---

## Prerequisites

- `Application.Read.All` for assessment phase
- `Application.ReadWrite.All` for ExecuteRemediation phase (Rev3.2 only)
- Approval manifest with `SchemaVersion = 3.2`
- Exact `CredentialKeyId` must be captured in the WhatIf plan

---

## Phase 1 — Assessment

Run with `-Mode Assessment` (or `-DemoMode` for demonstration):

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode Assessment `
    -ClientName 'ClientName' `
    -EngagementId 'ENG-XXXX' `
    -OutputPath '.\out\'
```

DEC-APP-005 findings are generated with the following fields:
- `CredentialKeyId` — exact GUID of the expired credential
- `CredentialType` — `PasswordCredential` or `KeyCredential`
- `CredentialEndDateTime` — ISO 8601 UTC expiry timestamp

**Important:** Only credentials with a confirmed `CredentialKeyId` in the finding will generate an executable WhatIf action. Findings without a KeyId are plan-only.

---

## Phase 2 — WhatIf Plan Generation

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode WhatIfRemediation `
    -ClientName 'ClientName' `
    -EngagementId 'ENG-XXXX' `
    -OutputPath '.\out\'
```

The WhatIf plan JSON will contain `RemoveExpiredApplicationCredential` entries under `ApprovedActions` for eligible DEC-APP-005 findings.

Each credential action includes:
- `CredentialExpired = true` (confirmed at WhatIf time)
- `RequiresManualApproval = true` (cannot be auto-approved)
- `RollbackGuidance` — notes that the secret value cannot be recovered; a new credential must be created if removal was incorrect
- `ReadinessStatus` — status string

---

## Phase 3 — Approval

The WhatIf action plan must be reviewed and converted to an approval manifest with:

- `SchemaVersion = "3.2"` (required — older schema rejects credential action types)
- `RequiresManualApproval = true` per action
- `TargetObjectIds` containing the exact `CredentialKeyId`
- `ApprovalStatus = "Approved"`
- `ApprovedBy` — name and role of approver

**Approval checklist per credential:**
- [ ] Application is confirmed non-critical or decommissioned
- [ ] Credential is confirmed expired (EndDateTime is in the past)
- [ ] Application owner has been notified
- [ ] Rollback plan documented: a new credential can be issued if needed
- [ ] `ProtectedObject` is `false`

---

## Phase 4 — ExecuteRemediation

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode ExecuteRemediation `
    -ClientName 'ClientName' `
    -EngagementId 'ENG-XXXX' `
    -ApprovalManifestPath '.\out\approval-manifest-ENG-XXXX.json' `
    -OutputPath '.\out\'
```

### Execution Safety Gates

Gate C (per credential action):

1. **ProtectedObject check** — blocks if `ProtectedObject = true`
2. **Cmdlet availability** — blocks if `Remove-MgApplicationPassword` / `Remove-MgApplicationKey` not available
3. **Application read** — re-reads application from Graph; blocks if read fails
4. **Credential presence check** — if credential no longer present → logged `Skipped` (no write)
5. **Expiry revalidation** — re-checks `EndDateTime < UtcNow`; blocks if not expired
6. **CredentialType match** — compares live credential type to approval manifest; blocks if mismatch
7. **EndDateTime not null** — blocks if `EndDateTime` is null on live credential

### Execution Outcomes

| Outcome | Meaning |
|---|---|
| `Executed` | Credential removed; post-write re-query confirmed removal |
| `Skipped` | Credential no longer present at execution time (already removed) |
| `Failed` | API call failed; credential may still be present |
| `PartialFailed` | Write call succeeded but post-write re-query failed; state unconfirmed |
| `Blocked` | Pre-flight check failed; no write attempted |

---

## Rollback

There is no automated rollback for credential removal. If a credential was removed incorrectly:

1. Navigate to the application registration in the Entra portal
2. Add a new credential (password or certificate)
3. Update any services using the credential with the new value
4. Document the correction in the engagement log

---

## Governance Pack Output (Read-Only)

`CredentialHygiene.psm1` generates read-only consultant deliverables from DEC-APP-004 and DEC-APP-005 findings:

- HTML dashboard
- JSON readiness report
- CSV summary
- Markdown rollback guide (notes that secret values cannot be recovered)
- Owner notification template
- Remediation design document
- Evidence appendix

None of these outputs trigger any write actions.

---

© 2026 Albert Jee. All rights reserved.
