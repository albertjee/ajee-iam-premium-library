# Executive Pack Runbook

**Tool:** Entra Identity Decommissioning Control Plane  
**SchemaVersion:** 2.5  
**Rev:** 2.5

---

## Overview

The Executive Pack (`-GenerateExecutivePack`) produces a client-ready evidence bundle including:

- Executive summary with risk posture metrics
- Baseline comparison (if a prior run's findings JSON is provided via `-BaselinePath`)
- Risk movement summary (improved / unchanged / worsened finding counts)
- Client readout pack manifest linking all deliverables

## Standard Executive Pack Run

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith' `
    -GenerateExecutivePack
```

## With Baseline Comparison

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -EngagementId 'ENG-2026-001' `
    -ClientName 'Contoso' `
    -Assessor 'Jane Smith' `
    -GenerateExecutivePack `
    -BaselinePath '.\output\ENG-2026-001\prior-run\findings-*.json'
```

`-BaselinePath` accepts a file path or folder path. If a folder is provided, the most recent `findings-*.json` in that folder is used.

## Output Files

| File | Description |
|---|---|
| `executive-summary-*.json` | Risk posture metrics and finding distribution |
| `executive-summary-*.html` | Human-readable executive summary |
| `baseline-comparison-*.json` | Delta between current and prior run |
| `client-readout-pack-*.json` | Manifest linking all deliverables |

## Risk Movement Categories

| Category | Meaning |
|---|---|
| New | Finding present in current run, absent from baseline |
| Resolved | Finding present in baseline, absent from current run |
| Unchanged | Same FindingId, ObjectId, and severity in both runs |
| ChangedSeverity | Same FindingId and ObjectId, severity changed |
| ChangedRiskScore | Same FindingId and ObjectId, risk score changed |

## IsPersisting Flag

Findings that appear in both the current run and the baseline are flagged `IsPersisting=true` in the executive summary. Persistent high/critical findings indicate unresolved risk requiring client action.

## Demo Mode Executive Pack

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode -GenerateExecutivePack
```

Generates a synthetic executive pack without a live tenant connection.

---

© 2026 Albert Jee. All rights reserved.
