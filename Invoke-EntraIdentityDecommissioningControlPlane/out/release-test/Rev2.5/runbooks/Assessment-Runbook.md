# Assessment Runbook

**Tool:** Entra Identity Decommissioning Control Plane  
**SchemaVersion:** 2.5  
**Rev:** 2.5

---

## Prerequisites

- PowerShell 5.1+
- Microsoft Graph PowerShell SDK installed (`Install-Module Microsoft.Graph`)
- Required read scopes granted (see `docs/Required-Permissions.md`)
- Engagement ID, client name, and assessor name ready

## Standard Assessment Run

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith'
```

Output directory: `.\output\<EngagementId>\<timestamp>\`

## Demo Mode (No Live Tenant Required)

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode
```

Generates synthetic findings. No Graph connection required. Use for capability demonstrations and test validation.

## Executive Pack

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith' `
    -GenerateExecutivePack
```

Appends baseline comparison, trend analysis, and client readout pack to standard output.

## WhatIf Mode

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith' `
    -WhatIf
```

Simulates remediation actions without executing them. Produces WhatIf evidence JSON.

## Output Files

| File | Description |
|---|---|
| `findings-*.json` | Raw findings export |
| `run-manifest-*.json` | Run metadata and summary |
| `assessment-report-*.html` | Human-readable HTML report |
| `executive-summary-*.json` | Executive summary (with -GenerateExecutivePack) |
| `client-readout-pack-*.json` | Client readout manifest (with -GenerateExecutivePack) |

## Troubleshooting

See `runbooks/Troubleshooting.md`.

---

© 2026 Albert Jee. All rights reserved.
