# Rev1.2 Claude Code Build Prompt
# Entra Identity Decommissioning Control Plane
# Consultant Readiness Hardening Patch

---

## CONTEXT AND CONSTRAINTS

Read CLAUDE.md in full before writing a single line of code.

This is a patch release — Rev1.2. All changes are confined to the Rev1.1 files only.
Frozen files remain untouched. No new files are required unless adding tests.

**Repo root:**
```
C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane
```

After every file modification, run Gate 1 + Gate 2 on that file immediately.
Run Gate 3 after all files are patched.
Run demo mode smoke test last.
Never declare done until all four pass with verified output.
Do not push. Albert pushes manually.

**Canonical test count after Rev1.2: ≥ 27 tests, 0 failures.**
(Rev1.1 had 20. Rev1.2 adds ≥ 7 new tests.)

---

## FILES TO PATCH

```
Invoke-EntraIdentityDecommissioningControlPlane.ps1
src/modules/Analysis.psm1
src/modules/Discovery.psm1
src/modules/Reporting.psm1
src/modules/RemediationPlan.psm1
tests/Rev11/Safety.Tests.ps1
tests/Rev11/Analysis.Tests.ps1
tests/Rev11/Reporting.Tests.ps1
CHANGELOG.md  ← APPEND Rev1.2 block at top only
```

---

## FIX 1 — P1-01: Null safety in Invoke-DecomAnalysis (Analysis.psm1)

Replace the DisplayName and UserPrincipalName access in Invoke-DecomAnalysis with null-safe guards:

```powershell
$displayNameLower = if ($null -ne $finding.DisplayName) {
    [string]$finding.DisplayName.ToLowerInvariant()
} else { '' }

$upnLower = if ($null -ne $finding.UserPrincipalName) {
    [string]$finding.UserPrincipalName.ToLowerInvariant()
} else { '' }
```

Also guard the RiskScore field:
```powershell
$riskScore = if ($null -ne $finding.RiskScore) { [int]$finding.RiskScore } else { 0 }
```

Also guard foreach against null input — wrap with @():
```powershell
$processed = @(foreach ($finding in @($Findings)) {
    if ($null -eq $finding) { continue }
    # ... rest of loop
})
```

Also guard Total count in Get-DecomFindingSummary:
```powershell
Total = ($Findings | Measure-Object).Count
```

Gate 1 + Gate 2 after this fix.

---

## FIX 2 — P1-02: Protected objects must force RemediationMode (Analysis.psm1)

Inside the protected object block in Invoke-DecomAnalysis, after setting ProtectedObject = $true, also force:

```powershell
if ($isProtected) {
    $finding.ProtectedObject   = $true
    $finding.RemediationMode   = 'ProtectedObject'
    $finding.RecommendedAction = "Manual review required — protected object. Original action: $($finding.RecommendedAction)"
}
```

Gate 1 + Gate 2 after this fix.

---

## FIX 3 — P1-03: Filter DEC-USER-001 memberOf to actual groups (Discovery.psm1)

In the DEC-USER-001 live detection, after calling Get-MgUserMemberOf, filter to actual groups only:

```powershell
$memberOf = @(Get-MgUserMemberOf -UserId $user.Id -All -ErrorAction Stop)

$memberships = @(
    $memberOf | Where-Object {
        $_.AdditionalProperties -and
        $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group'
    }
)

if ($memberships.Count -gt 0) {
    $groupNames = (@($memberships | ForEach-Object {
        if ($_.AdditionalProperties -and $_.AdditionalProperties['displayName']) {
            $_.AdditionalProperties['displayName']
        }
    } | Where-Object { $_ }) -join ', ')

    $evidence = "Disabled user retains direct membership in $($memberships.Count) group(s)"
    if ($groupNames) { $evidence += ": $groupNames" }

    # pass $evidence to New-DecomFinding
}
```

Gate 1 + Gate 2 after this fix.

---

## FIX 4 — P1-04: Separate missing guest sign-in from stale evidence (Discovery.psm1)

Replace the DEC-GUEST-001 guest sign-in check with this pattern:

```powershell
foreach ($guest in $guests) {
    $lastSignIn      = $null
    $hasSignInData   = $false

    try {
        if ($guest.SignInActivity -and $guest.SignInActivity.LastSignInDateTime) {
            $hasSignInData = $true
            $lastSignIn    = [datetime]$guest.SignInActivity.LastSignInDateTime
        }
    } catch { $hasSignInData = $false }

    # Missing sign-in data = coverage gap, not a per-user finding
    if (-not $hasSignInData) { continue }

    $staleThreshold = (Get-Date).AddDays(-180)

    if ($null -eq $lastSignIn) {
        $daysStr = 'never signed in'
    } elseif ($lastSignIn -lt $staleThreshold) {
        $daysStr = "$([int]((Get-Date) - $lastSignIn).TotalDays) days ago"
    } else {
        continue  # not stale — skip
    }

    $findings.Add((New-DecomFinding `
        -FindingId         'DEC-GUEST-001' `
        -Category          'Guest Lifecycle' `
        -Severity          'Low' `
        -RiskScore         32 `
        -Confidence        'Medium' `
        -ObjectType        'User' `
        -ObjectId          $guest.Id `
        -DisplayName       $guest.DisplayName `
        -UserPrincipalName $guest.UserPrincipalName `
        -Evidence          "Guest last sign-in: $daysStr — review for continued access need" `
        -EvidenceSource    'signInActivity' `
        -GraphEndpoint     '/v1.0/users/{id}?$select=signInActivity' `
        -RecommendedAction "Initiate access review for stale guest $($guest.UserPrincipalName)" `
        -RemediationMode   'ManualApprovalRequired' `
        -ConsultantNote    'Confirm with business owner whether guest access is still required'))
}
```

Gate 1 + Gate 2 after this fix.

---

## FIX 5 — P1-05: Block ExecuteRemediation explicitly (entry point)

In Invoke-EntraIdentityDecommissioningControlPlane.ps1, add this guard immediately after the param block and before any other logic:

```powershell
if ($Mode -eq 'ExecuteRemediation') {
    Write-Host "[ERROR] ExecuteRemediation is reserved for a future release." -ForegroundColor Red
    Write-Host "        Rev1.1 supports Assessment, WhatIfRemediation, and ExportPlan only." -ForegroundColor Red
    exit 1
}
```

Gate 1 + Gate 2 after this fix.

---

## FIX 6 — P2-01: Mode-accurate safety banner (entry point)

Replace the safety banner Write-Host line with:

```powershell
Write-Host "*** No tenant modifications will be performed in $Mode mode. ***" -ForegroundColor Green
```

---

## FIX 7 — P2-02: ExportPlan Graph connection guard (entry point)

Update the Graph connection condition to include ExportPlan:

```powershell
if (-not $DemoMode -and $Mode -in @('Assessment','WhatIfRemediation','ExportPlan')) {
    # Connect-MgGraph
}
```

Gate 1 + Gate 2 after Fixes 5+6+7 (all entry point changes done together).

---

## FIX 8 — P2-03: DEC-APP-001 naming consistency (Discovery.psm1)

In the synthetic dataset (DemoMode), update DEC-APP-001 to match live mode:
- Change ObjectType from 'ServicePrincipal' to 'Application'
- Change Evidence from 'Service principal has no owner assigned' to 'Application has no owner assigned'

In live mode DEC-APP-001, confirm ObjectType = 'Application' and Evidence = 'Application has no owner assigned'.

Gate 1 + Gate 2 after this fix.

---

## FIX 9 — P2-04: HTML mode-specific safety text (Reporting.psm1)

In Export-DecomAssessmentHtml, replace the hardcoded Assessment mode text with:

```powershell
$modeSafetyText = switch ($Context.Mode) {
    'Assessment'        { 'All findings were identified in read-only Assessment mode — no tenant objects were modified during this run.' }
    'WhatIfRemediation' { 'Findings were evaluated in WhatIfRemediation mode — no tenant objects were modified during this run.' }
    'ExportPlan'        { 'A remediation plan was exported — no tenant objects were modified during this run.' }
    default             { 'Review execution logs and approval manifest for this run.' }
}
```

Use $modeSafetyText in the HTML body where the mode safety sentence appears.

Gate 1 + Gate 2 after this fix.

---

## FIX 10 — P2-05: Replace NodeList.forEach in HTML (Reporting.psm1)

In the embedded JavaScript in Export-DecomAssessmentHtml, replace:

```javascript
rows.forEach(function(row) {
```

With an indexed loop:

```javascript
for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
```

And update the closing brace accordingly. This ensures compatibility with locked-down enterprise browsers.

Gate 1 + Gate 2 after this fix.

---

## FIX 11 — P2-06: Medium findings in remediation plan (RemediationPlan.psm1)

Update Export-DecomRemediationPlan to include Medium findings as a separate Review Queue section:

Structure:

```markdown
## Immediate Actions (Critical + High)
<!-- findings with Severity Critical or High -->

## Review Queue (Medium)
<!-- findings with Severity Medium -->
Each Medium finding entry includes:
  ActionId, FindingId, ObjectType, DisplayName, Evidence,
  RecommendedAction, ApprovalStatus = PendingReview,
  ConsultantNote
```

Low and Informational findings go into a brief:

```markdown
## Monitor / Hygiene (Low + Informational)
| FindingId | DisplayName | Evidence |
```

Gate 1 + Gate 2 after this fix.

---

## FIX 12 — P2: CSV null guard (Reporting.psm1)

Confirm Export-DecomAssessmentCsv handles empty input:

```powershell
function Export-DecomAssessmentCsv {
    param([object[]]$Findings, [string]$Path)
    if (-not $Findings -or $Findings.Count -eq 0) {
        # Write header-only CSV
        'FindingId,Category,Severity,RiskScore,Confidence,ObjectType,DisplayName,Evidence,RecommendedAction,RemediationMode' |
            Set-Content -Path $Path -Encoding UTF8
        return
    }
    $Findings | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}
```

Same guard for JSON, HTML, and remediation plan — if findings are empty, write a minimal valid file, not nothing.

Gate 1 + Gate 2 after this fix.

---

## NEW TESTS — Add to existing test files

### tests/Rev11/Analysis.Tests.ps1 — add these tests

```powershell
It 'Invoke-DecomAnalysis tolerates null DisplayName and UserPrincipalName' {
    $finding = New-DecomFinding `
        -FindingId 'NULL-001' -Category 'Test' -Severity 'Low' -RiskScore 30 `
        -Confidence 'Low' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
        -DisplayName $null -UserPrincipalName $null `
        -Evidence 'Null field test' -EvidenceSource 'test' `
        -RecommendedAction 'Review' -RemediationMode 'ManualApprovalRequired'

    { Invoke-DecomAnalysis -Findings @($finding) } | Should -Not -Throw
}

It 'Protected objects are forced to RemediationMode ProtectedObject after analysis' {
    $finding = New-DecomFinding `
        -FindingId 'PROT-001' -Category 'User Lifecycle' -Severity 'Medium' -RiskScore 55 `
        -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
        -DisplayName 'svc-breakglass-admin' -UserPrincipalName 'svc-breakglass@contoso.com' `
        -Evidence 'Protected object test' -EvidenceSource 'test' `
        -RecommendedAction 'Remove access' -RemediationMode 'AutoRemediable'

    $result = Invoke-DecomAnalysis -Findings @($finding)

    $result[0].ProtectedObject | Should -Be $true
    $result[0].RemediationMode | Should -Be 'ProtectedObject'
}

It 'Invoke-DecomAnalysis handles empty findings array without error' {
    { Invoke-DecomAnalysis -Findings @() } | Should -Not -Throw
}

It 'Get-DecomFindingSummary returns zero counts for empty input' {
    $summary = Get-DecomFindingSummary -Findings @()
    $summary.Total    | Should -Be 0
    $summary.Critical | Should -Be 0
}
```

### tests/Rev11/Safety.Tests.ps1 — add these tests

```powershell
It 'ExecuteRemediation mode exits with error in entry point' {
    $entryPoint = Get-Content '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1' -Raw
    $entryPoint | Should -Match 'ExecuteRemediation'
    $entryPoint | Should -Match 'reserved for a future release'
}

It 'Protected pattern svc- is classified as ProtectedObject' {
    $finding = New-DecomFinding `
        -FindingId 'SVC-001' -Category 'User Lifecycle' -Severity 'Medium' -RiskScore 50 `
        -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
        -DisplayName 'svc-automation-account' -UserPrincipalName 'svc-auto@contoso.com' `
        -Evidence 'Service account test' -EvidenceSource 'test' `
        -RecommendedAction 'Review' -RemediationMode 'ManualApprovalRequired'

    $result = Invoke-DecomAnalysis -Findings @($finding)
    $result[0].ProtectedObject | Should -Be $true
}
```

### tests/Rev11/Reporting.Tests.ps1 — add these tests

```powershell
It 'CSV export succeeds with empty findings array' {
    $path = Join-Path $TestDrive 'empty.csv'
    { Export-DecomAssessmentCsv -Findings @() -Path $path } | Should -Not -Throw
    Test-Path $path | Should -Be $true
}

It 'Remediation plan includes Medium findings in Review Queue section' {
    $findings = @(
        New-DecomFinding -FindingId 'MED-001' -Category 'User Lifecycle' `
            -Severity 'Medium' -RiskScore 50 -Confidence 'High' `
            -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
            -DisplayName 'Test User' -UserPrincipalName 'test@contoso.com' `
            -Evidence 'Medium finding test' -EvidenceSource 'test' `
            -RecommendedAction 'Review access' -RemediationMode 'ManualApprovalRequired'
    )
    $path = Join-Path $TestDrive 'plan.md'
    $ctx  = [PSCustomObject]@{ Mode='Assessment'; TenantId='test'; EngagementId=''; ClientName=''; Assessor='' }
    Export-DecomRemediationPlan -Findings $findings -Path $path -Context $ctx
    $content = Get-Content $path -Raw
    $content | Should -Match 'Review Queue'
    $content | Should -Match 'MED-001'
}
```

---

## VERIFICATION SEQUENCE

Run in order. Show actual output of each. Do not skip.

```powershell
# Gate 1 — parse all patched files
$files = @(
    '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1',
    '.\src\modules\Analysis.psm1',
    '.\src\modules\Discovery.psm1',
    '.\src\modules\Reporting.psm1',
    '.\src\modules\RemediationPlan.psm1',
    '.\tests\Rev11\Safety.Tests.ps1',
    '.\tests\Rev11\Analysis.Tests.ps1',
    '.\tests\Rev11\Reporting.Tests.ps1'
)
foreach ($f in $files) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $f), [ref]$null, [ref]$errors)
    Write-Host "$f — Parse errors: $($errors.Count)"
}
# Every line must show: parse errors: 0
```

```powershell
# Gate 2 — import all patched modules silently
$modules = @(
    '.\src\modules\Utilities.psm1',
    '.\src\modules\Discovery.psm1',
    '.\src\modules\Analysis.psm1',
    '.\src\modules\Reporting.psm1',
    '.\src\modules\RemediationPlan.psm1'
)
foreach ($m in $modules) {
    Remove-Module ([System.IO.Path]::GetFileNameWithoutExtension($m)) -Force -ErrorAction SilentlyContinue
    Import-Module (Resolve-Path $m) -Force -DisableNameChecking
    Write-Host "$m — Import OK"
}
# Every line must show: Import OK with no warnings
```

```powershell
# Gate 3 — full Rev1.2 Pester suite
Invoke-Pester -Path .\tests\Rev11\ -Output Detailed
# Must show 0 failures, Tests count >= 27
```

```powershell
# Demo mode smoke test
pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode
# Must:
# - Print banner with correct mode safety line
# - Print 1 CRITICAL, 2 HIGH, 3 MEDIUM, 1 LOW, 1 INFO
# - Print [OK] for all 5 exports
# - Exit 0
```

Only after all four show clean output — declare Rev1.2 complete.
Do not push. Albert pushes manually.

---

## CHANGELOG ENTRY

APPEND this block at the top of CHANGELOG.md above the Rev1.1 entry:

```markdown
## Rev1.2 — Consultant Readiness Hardening Patch (2026-05-30)

### Fixed (P1)
- `Invoke-DecomAnalysis` null-safe guards on DisplayName, UserPrincipalName, and RiskScore
- Protected objects now force `RemediationMode = ProtectedObject` and prepend warning to RecommendedAction
- DEC-USER-001 memberOf filtered to actual groups only (excludes directory roles and admin units)
- DEC-GUEST-001 separates missing sign-in data from stale sign-in evidence — missing data skipped as coverage gap
- `ExecuteRemediation` mode now exits immediately with error — reserved for future release

### Fixed (P2)
- Safety banner now shows active mode name instead of hardcoded "Assessment mode"
- ExportPlan mode now included in Graph connection guard
- DEC-APP-001 ObjectType and Evidence consistent between DemoMode and live mode
- HTML report mode safety text is now mode-aware
- HTML JavaScript filter replaced NodeList.forEach with indexed loop for enterprise browser compatibility
- Remediation plan now includes Medium findings in Review Queue section and Low/Info in Monitor section
- CSV, JSON, HTML, and Markdown exports handle empty findings array without crashing

### Tests
- Added 7 new Pester tests: null-safe analysis, protected object enforcement,
  empty findings handling, ExecuteRemediation guard, svc- pattern classification,
  empty CSV export, Medium findings in remediation plan
- Total: ≥ 27 tests, 0 failures
```
