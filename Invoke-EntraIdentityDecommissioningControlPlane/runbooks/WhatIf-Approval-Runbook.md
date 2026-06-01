# WhatIf and Approval Runbook

**Tool:** Entra Identity Decommissioning Control Plane  
**SchemaVersion:** 2.5  
**Rev:** 2.5

---

## Overview

The WhatIf/Approval flow is a two-phase safety gate before any remediation is executed:

1. **WhatIf phase** — enumerate planned actions, produce evidence JSON
2. **Approval phase** — assessor reviews WhatIf output and signs an approval manifest

No tenant-modifying calls occur until the approval manifest is present and valid.

## Phase 1 — WhatIf Run

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith' `
    -WhatIf
```

Produces: `whatif-evidence-*.json` in the output directory.

## Phase 2 — Create Approval Manifest

Review the WhatIf evidence, then create an approval manifest:

```json
{
  "SchemaVersion": "2.5",
  "ToolVersion": "Rev2.5",
  "GeneratedUtc": "<ISO-8601>",
  "EngagementId": "ENG-2026-001",
  "ClientName": "Contoso",
  "RunId": "<RunId from WhatIf evidence>",
  "ApprovedBy": "Jane Smith",
  "ExpiresUtc": "<ISO-8601, max 24 hours>",
  "ApprovedActions": ["<FindingId1>", "<FindingId2>"]
}
```

Save as: `approval-manifest-<EngagementId>.json`

## Phase 3 — Execute with Approval

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith' `
    -ExecuteRemediation `
    -ApprovalManifestPath '.\approval-manifest-ENG-2026-001.json'
```

The tool validates the manifest before executing any write operations.

## Approval Manifest Validation Rules

- `RunId` must match the current run or a recent WhatIf run
- `ExpiresUtc` must be in the future
- `ApprovedActions` must contain valid FindingIds
- `ApprovedBy` must be non-empty

## Rev2.0 Executable Finding IDs

Only the following finding IDs may appear in `ApprovedActions`:

| FindingId | Action |
|---|---|
| DEC-USER-001 | Remove guest group membership |
| DEC-USER-002 | Remove group membership (non-guest) |
| DEC-USER-003 | Remove group membership (disabled user) |
| DEC-ROLE-001 | Remove directory role assignment |

All other finding IDs are `ManualApprovalRequired` or `InformationOnly` and cannot be auto-remediated.

---

© 2026 Albert Jee. All rights reserved.
