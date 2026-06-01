# Troubleshooting Runbook

**Tool:** Entra Identity Decommissioning Control Plane  
**SchemaVersion:** 2.5  
**Rev:** 2.5

---

## Common Issues

### Authentication Needed / Connect-MgGraph

**Symptom:** `[WARN] PIM eligible assignment discovery unavailable: Authentication needed. Please call Connect-MgGraph.`

**Cause:** Graph session not established before running the tool.

**Fix:**
```powershell
Connect-MgGraph -Scopes 'User.Read.All','Group.Read.All','Application.Read.All','Directory.Read.All'
# Then run the tool
```

See `docs/Required-Permissions.md` for full scope list.

---

### Parse Errors on Import

**Symptom:** `Import-Module` emits parser errors.

**Fix:** Run Gate 1 parse check:
```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile('<path>.psm1', [ref]$null, [ref]$errors)
Write-Host "Parse errors: $($errors.Count)"
```

---

### SelfTest Fails

**Symptom:** `-SelfTest` exits with code 1.

**Cause:** Version mismatch or safety invariant violation in source files.

**Fix:** Run SelfTest and review errors:
```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -SelfTest
# Check output\*\release-validation-report-*.json for error details
```

---

### Approval Manifest Expired

**Symptom:** `Approval manifest has expired` error during `-ExecuteRemediation`.

**Fix:** Generate a new approval manifest. Manifests expire within 24 hours of `ExpiresUtc`. See `runbooks/WhatIf-Approval-Runbook.md`.

---

### Approval Manifest RunId Mismatch

**Symptom:** `RunId mismatch` error during `-ExecuteRemediation`.

**Fix:** The approval manifest must reference the `RunId` from the most recent WhatIf or assessment run. Re-run WhatIf, re-generate the manifest, and retry.

---

### No Findings Generated

**Symptom:** Assessment completes but `findings-*.json` is empty.

**Cause options:**
1. No decommissioning-relevant identities exist in the tenant
2. Missing Graph scopes — check `[WARN]` lines in output for discovery failures
3. All findings suppressed by suppression rules

**Fix:** Check the `run-manifest-*.json` for `DiscoveryWarnings` and scope errors.

---

### HTML Report Does Not Open

**Symptom:** `assessment-report-*.html` file exists but browser cannot open it.

**Fix:** Open the file directly in a browser. Relative paths in the HTML require opening from the output directory or via a local web server. Do not move the HTML without copying all referenced assets.

---

### Module Not Found Error

**Symptom:** `The term 'Invoke-DecomDiscovery' is not recognized...`

**Cause:** Module auto-import failed because `src\Modules\` path is not discoverable.

**Fix:** Ensure you run the tool from the repo root directory, not a subdirectory:
```powershell
Set-Location 'C:\Git\...\Invoke-EntraIdentityDecommissioningControlPlane'
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode
```

---

### Baseline Path Not Found

**Symptom:** `BaselinePath not found or contains no findings JSON` warning.

**Fix:** Verify the path exists and points to a valid `findings-*.json` or folder containing one:
```powershell
Test-Path '.\output\prior-run\findings-20260101_120000.json'
```

---

## Diagnostic Commands

```powershell
# Check all module parse errors
$modulesPath = '.\src\Modules'
Get-ChildItem $modulesPath -Filter '*.psm1' | ForEach-Object {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$null, [ref]$errors) | Out-Null
    Write-Host "$($_.Name): $($errors.Count) errors"
}

# Run SelfTest
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -SelfTest

# Run full test suite
Invoke-Pester -Path .\tests\Rev11\ -Output Detailed
```

---

© 2026 Albert Jee. All rights reserved.
