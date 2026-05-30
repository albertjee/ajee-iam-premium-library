# Rev1.1 Claude Code Build Prompt
# Entra Identity Decommissioning Control Plane — Consultant Readiness

---

## CONTEXT AND CONSTRAINTS

You are building Rev1.1 of the Entra Identity Decommissioning Control Plane.
Read CLAUDE.md in full before writing a single line of code.

**Repo root:**
```
C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane
```

**This is an ADDITIVE build. The frozen file list in CLAUDE.md is absolute.**
Do not read-to-modify, str_replace, or delete any frozen file.
If you are unsure whether a file is frozen — it is. Stop and check CLAUDE.md.

After every file you write or modify, run all three verification gates:
1. Syntax/parse — must be 0 errors
2. Load/import — must be silent, no warnings
3. Full test suite (Gate 3 runs after all files are written): `Invoke-Pester -Path .\tests\Rev11\ -Output Detailed` — zero failures required

Never declare done until all three gates pass with verified output.
Do not push. Albert pushes manually.

---

## WHAT YOU ARE BUILDING

A new **assessment-first PowerShell tool** that:

- Defaults to `Assessment` mode — no tenant objects are modified
- Supports `-DemoMode` for running without any Graph connection (synthetic data)
- Produces 4 exports: CSV, JSON, HTML report, Markdown remediation plan
- Has a professional console output matching the NHI audit tool style
- Generates a high-quality HTML executive report (dark theme — spec below)
- Has ≥ 15 Pester tests covering safety, analysis, and reporting

This is NOT a rewrite of the existing decom tool. It is a new entry point and new module layer sitting alongside the existing infrastructure.

---

## STEP 1 — WRITE CLAUDE.md TO REPO ROOT

Copy the CLAUDE.md from this session's working directory to:
```
C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane\CLAUDE.md
```
Do not modify it. Gate 1 does not apply to markdown.

---

## STEP 2 — WRITE THE ENTRY POINT

**File:**
```
C:\Git\ajee-iam-premium-library\Invoke-EntraIdentityDecommissioningControlPlane\Invoke-EntraIdentityDecommissioningControlPlane.ps1
```

### Parameter block

```powershell
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Assessment','WhatIfRemediation','ExportPlan','ExecuteRemediation')]
    [string]$Mode = 'Assessment',

    [string]$TenantId,
    [string]$ClientId,
    [string]$EngagementId,
    [string]$ClientName,
    [string]$Assessor,
    [string]$OutputPath = '.\out',

    [switch]$DemoMode,
    [switch]$NoLogo
)
```

### Startup banner (console output spec)

Emit exactly this structure using `Write-Host` with colors:

```
================================================================
  Entra Identity Decommissioning Control Plane  Rev1.1
  Assessment-first tooling for identity governance reviews
================================================================
  Mode     : Assessment
  Tenant   : <TenantId or DEMO>
  Started  : <timestamp>
  Output   : <OutputPath>

*** No tenant modifications will be performed in Assessment mode. ***
================================================================
```

Color rules (match NHI audit tool screenshot):
- Header border lines: `DarkCyan`
- Product name line: `Cyan`
- Mode line: `Yellow` when Assessment/WhatIfRemediation, `Red` when ExecuteRemediation
- Safety line (`*** No tenant modifications ***`): `Green`
- `[INFO]` prefix: `DarkCyan` label, `Gray` message
- `[OK]` prefix: `Green` label, `Gray` message
- `[WARN]` prefix: `Yellow` label, `Gray` message
- `[ERROR]` prefix: `Red` label, `Gray` message
- Finding severity counts:
  - `CRITICAL findings :` — `Red`
  - `HIGH findings     :` — `DarkYellow`
  - `MEDIUM findings   :` — `Cyan`
  - `LOW findings      :` — `Green`
  - `INFO findings     :` — `Gray`

### Completion summary (console output spec)

```
================================================================
  Assessment complete.

  Findings:
    CRITICAL : <n>
    HIGH     : <n>
    MEDIUM   : <n>
    LOW      : <n>
    INFO     : <n>

  Exports:
    [OK]  CSV              : <path>
    [OK]  JSON             : <path>
    [OK]  HTML Report      : <path>
    [OK]  Remediation Plan : <path>
    [OK]  Run Manifest     : <path>

  Output folder : <OutputPath>
================================================================
```

### Module loading

Load from `src\modules\`:
- `Utilities.psm1`
- `Discovery.psm1`
- `Analysis.psm1`
- `Reporting.psm1`
- `RemediationPlan.psm1`

### Execution flow

```
1. Print banner
2. If DemoMode → load synthetic dataset (no Graph calls)
3. Else if Mode = Assessment or WhatIfRemediation → Connect-MgGraph (read-only scopes)
4. Invoke-DecomAssessmentDiscovery → returns $Findings (array of finding objects)
5. Invoke-DecomAnalysis -Findings $Findings → returns scored/classified findings
6. Emit finding counts to console (CRITICAL/HIGH/MEDIUM/LOW/INFO)
7. Export-DecomAssessmentCsv
8. Export-DecomAssessmentJson
9. Export-DecomAssessmentHtml  (the big one — spec below)
10. Export-DecomRemediationPlan
11. Write-DecomRunManifest
12. Print completion summary
```

### Timestamped output folder

```powershell
$Timestamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
$RunFolder  = Join-Path $OutputPath $Timestamp
New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null
```

Output filenames:
```
entra-decommissioning-control-plane-assessment-<timestamp>.csv
entra-decommissioning-control-plane-findings-<timestamp>.json
entra-decommissioning-control-plane-report-<timestamp>.html
entra-decommissioning-control-plane-remediation-plan-<timestamp>.md
entra-decommissioning-control-plane-run-manifest-<timestamp>.json
```

---

## STEP 3 — WRITE src\modules\Utilities.psm1

Helper functions used across modules:

```powershell
function Write-DecomInfo  { param([string]$Message) Write-Host "[INFO]  " -ForegroundColor DarkCyan -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomOk    { param([string]$Message) Write-Host "[OK]    " -ForegroundColor Green    -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomWarn  { param([string]$Message) Write-Host "[WARN]  " -ForegroundColor Yellow   -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomError { param([string]$Message) Write-Host "[ERROR] " -ForegroundColor Red      -NoNewline; Write-Host $Message -ForegroundColor Gray }

function New-DecomFinding {
    param(
        [string]$FindingId,
        [string]$Category,
        [ValidateSet('Critical','High','Medium','Low','Informational')]
        [string]$Severity,
        [int]$RiskScore,
        [ValidateSet('High','Medium','Low')]
        [string]$Confidence,
        [string]$ObjectType,
        [string]$ObjectId,
        [string]$DisplayName,
        [string]$UserPrincipalName,
        [string]$Evidence,
        [string]$EvidenceSource,
        [string]$GraphEndpoint,
        [string]$RecommendedAction,
        [ValidateSet('ManualApprovalRequired','AutoRemediable','InformationOnly','ProtectedObject')]
        [string]$RemediationMode,
        [string]$ConsultantNote,
        [bool]$ProtectedObject = $false
    )
    [PSCustomObject]@{
        FindingId         = $FindingId
        Category          = $Category
        Severity          = $Severity
        RiskScore         = $RiskScore
        Confidence        = $Confidence
        ObjectType        = $ObjectType
        ObjectId          = $ObjectId
        DisplayName       = $DisplayName
        UserPrincipalName = $UserPrincipalName
        Evidence          = $Evidence
        EvidenceSource    = $EvidenceSource
        GraphEndpoint     = $GraphEndpoint
        RecommendedAction = $RecommendedAction
        RemediationMode   = $RemediationMode
        ConsultantNote    = $ConsultantNote
        ProtectedObject   = $ProtectedObject
        DetectedUtc       = (Get-Date).ToUniversalTime().ToString('o')
    }
}

function Get-DecomTimestamp { Get-Date -Format 'yyyyMMdd_HHmmss' }
function Get-DecomTimestampDisplay { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }
```

Gate 1 + Gate 2 after writing.

---

## STEP 4 — WRITE src\modules\Discovery.psm1

### Protected pattern list

```powershell
$script:ProtectedPatterns = @(
    'breakglass','break-glass','emergency','sync',
    'aadconnect','cloudsync','svc-','service-'
)
```

### Coverage tracking

```powershell
function New-DecomCoverage {
    [ordered]@{
        Users                 = $false
        Groups                = $false
        Applications          = $false
        ServicePrincipals     = $false
        DirectoryRoles        = $false
        SignInLogs            = $false
        AuditLogs             = $false
        ConditionalAccess     = $false
        EntitlementManagement = $false
    }
}
```

### Main discovery function

```powershell
function Invoke-DecomAssessmentDiscovery {
    param(
        [pscustomobject]$Context,
        [switch]$DemoMode
    )
    # In DemoMode: return Get-DecomSyntheticFindings
    # In live mode: stub each Graph call with try/catch; mark coverage flags
    # Return array of finding objects (from New-DecomFinding)
}
```

### Synthetic dataset (DemoMode)

`Get-DecomSyntheticFindings` must return EXACTLY these findings (matches the screenshot counts):

| FindingId | Category | Severity | RiskScore | Confidence | DisplayName | Evidence |
|---|---|---|---|---|---|---|
| DEC-USER-003 | User Lifecycle | Critical | 92 | High | Alex Mercer | Disabled user retains Global Administrator role assignment |
| DEC-APP-002 | Application | High | 81 | High | Contoso Analytics API | Application owned exclusively by disabled user alex.mercer@contoso.com |
| DEC-GUEST-002 | Guest Lifecycle | High | 78 | High | ext_partner@fabrikam.com | Guest account holds User Administrator role — no sponsor metadata |
| DEC-USER-001 | User Lifecycle | Medium | 55 | High | Jordan Riley | Disabled user retains membership in 4 groups including IT-Admins |
| DEC-APP-001 | Application | Medium | 51 | High | Reporting Daemon SP | Service principal has no owner assigned |
| DEC-CA-001 | Conditional Access | Medium | 48 | Medium | MFA-Exclusion-Legacy | CA exclusion group contains 12 accounts — unreviewed for 180+ days |
| DEC-GUEST-001 | Guest Lifecycle | Low | 32 | Medium | ext_vendor@tailspin.com | Guest last sign-in 210 days ago — no access review coverage |
| DEC-IGA-001 | Governance | Informational | 18 | Low | Entitlement Management | AuditLog.Read.All scope unavailable — IGA coverage assessment incomplete |

Counts: 1 Critical, 2 High, 3 Medium, 1 Low, 1 Informational.

Use fake object IDs (GUIDs), fake tenant: `contoso.onmicrosoft.com`, fake UPNs from `@contoso.com` or `@fabrikam.com`.

Gate 1 + Gate 2 after writing.

---

## STEP 5 — WRITE src\modules\Analysis.psm1

```powershell
function Invoke-DecomAnalysis {
    param([object[]]$Findings)
    # Returns the same findings array with severity validated against RiskScore bands:
    # Critical = 80-100, High = 60-79, Medium = 40-59, Low = 25-39, Informational = 0-24
    # Clamp any out-of-band finding and emit Write-DecomWarn
    # Mark ProtectedObject = $true for any DisplayName matching $script:ProtectedPatterns
    # Return sorted: Critical first, then High, Medium, Low, Informational
}

function Get-DecomFindingSummary {
    param([object[]]$Findings)
    # Returns ordered hashtable: Critical, High, Medium, Low, Informational counts
    [ordered]@{
        Critical      = ($Findings | Where-Object Severity -eq 'Critical').Count
        High          = ($Findings | Where-Object Severity -eq 'High').Count
        Medium        = ($Findings | Where-Object Severity -eq 'Medium').Count
        Low           = ($Findings | Where-Object Severity -eq 'Low').Count
        Informational = ($Findings | Where-Object Severity -eq 'Informational').Count
        Total         = $Findings.Count
    }
}
```

Gate 1 + Gate 2 after writing.

---

## STEP 6 — WRITE src\modules\Reporting.psm1

### CSV export

```powershell
function Export-DecomAssessmentCsv {
    param([object[]]$Findings, [string]$Path)
    $Findings | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}
```

### JSON export

```powershell
function Export-DecomAssessmentJson {
    param([object[]]$Findings, [string]$Path, [pscustomobject]$Context)
    $payload = [ordered]@{
        SchemaVersion = '1.1'
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Tenant        = $Context.TenantId
        Mode          = $Context.Mode
        Coverage      = $Context.Coverage
        FindingCount  = $Findings.Count
        Findings      = $Findings
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
}
```

### Run manifest

```powershell
function Write-DecomRunManifest {
    param([string]$Path, [pscustomobject]$Context, [hashtable]$Summary, [hashtable]$ExportPaths)
    $manifest = [ordered]@{
        SchemaVersion = '1.1'
        RunId         = [guid]::NewGuid().Guid
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        TenantId      = $Context.TenantId
        Mode          = $Context.Mode
        DemoMode      = $Context.DemoMode
        EngagementId  = $Context.EngagementId
        ClientName    = $Context.ClientName
        Assessor      = $Context.Assessor
        FindingSummary= $Summary
        Exports       = $ExportPaths
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding UTF8
}
```

### HTML report — Export-DecomAssessmentHtml

This is the primary deliverable. Match the NHI audit HTML design exactly.

**Color palette (CSS variables):**
```css
--navy:   #0b1220
--gold:   #c6a75e
--text:   #f8fafc
--muted:  #cbd5e1
--cyan:   #38bdf8
--red:    #ef4444
--orange: #f59e0b
--green:  #22c55e
--border: rgba(198,167,94,0.35)
```

**Body:** `background: linear-gradient(135deg, #0b1220, #020617)` — dark navy.

**Page max-width:** 1280px, centered, 40px padding.

**Header section:**
- Left border: 6px solid `--gold`
- H1: product name in white, 34px
- Subtitle: muted, 16px
- Meta-grid (3 columns): Tenant, Run Date, Version, Mode, Client, Engagement ID, Assessor, Coverage, Findings Total — labels in muted uppercase 11px, values in gold

**Safety banner** (shown when Mode = Assessment):
```html
<div style="background:rgba(34,197,94,0.1); border:1px solid rgba(34,197,94,0.4); border-radius:10px; padding:14px 18px; color:#22c55e; font-weight:600; margin-bottom:24px;">
  ✅ Assessment mode — no tenant objects were modified during this run.
</div>
```

**Demo watermark** (shown in DemoMode):
```css
position:fixed; top:50%; left:50%; transform:translate(-50%,-50%) rotate(-35deg);
font-size:100px; font-weight:900; color:rgba(198,167,94,0.06);
pointer-events:none; z-index:9999; white-space:nowrap; letter-spacing:12px;
```
Text: `DEMO DATA`

**KPI grid** (4 columns):
- Total Users Assessed
- Critical + High Findings
- Protected Objects Detected
- Coverage Mode (Full / Partial)

Each KPI card: `background:rgba(22,32,51,0.92)`, `border-radius:16px`, label in muted uppercase, value in 34px bold, note in muted 13px.

**Severity scorecard** (5 columns):
- Critical → `--red`
- High → `--orange`
- Medium → `--cyan`
- Low → `--green`
- Informational → `--muted`

**Findings table** (filterable by Severity and Category):
Columns: Finding ID | Severity | Category | Object | Evidence | Recommended Action | Confidence | Remediation Mode

Row styling:
- Critical → `color: var(--red); font-weight:700`
- High → `color: var(--orange); font-weight:700`
- Medium → `color: var(--cyan); font-weight:700`
- Low → `color: var(--green); font-weight:700`
- Informational → `color: var(--muted)`

**Filter controls** above table: dropdowns for Severity and Category. JavaScript `applyFilters()` hides/shows rows.

**Sections in order:**
1. Executive Summary (paragraph text generated from finding counts)
2. KPI grid
3. Severity scorecard
4. Findings table (filterable)
5. Coverage Summary (which Graph areas succeeded/failed)
6. Remediation Roadmap (top 3 recommended actions from Critical/High findings)
7. Assumptions and Limitations (standard consultant text)
8. Footer: generated timestamp, version, "Consultant advisory tool — not a continuous monitoring platform"

**Consultant advisory banner** at top of page (thin bar):
```html
<div style="width:100%; background:#0a0f1a; border-left:6px solid #c6a75e; padding:12px 32px; font-size:13px; color:#94a3b8;">
  <strong style="color:#c6a75e;">Consultant Assessment Tool</strong> — Assessment-first. No tenant objects modified in this run.
</div>
```

**Print CSS:** white background, hide filters and watermark, preserve table structure.

Gate 1 + Gate 2 after writing.

---

## STEP 7 — WRITE src\modules\RemediationPlan.psm1

```powershell
function Export-DecomRemediationPlan {
    param([object[]]$Findings, [string]$Path, [pscustomobject]$Context)
    # Generate Markdown remediation plan
    # Header block: client, date, engagement ID, assessor, mode
    # Safety note: this plan does not execute any actions
    # For each Critical and High finding (sorted by RiskScore desc):
    #   ActionId = "ACT-{n:D3}"
    #   FindingId, ObjectType, ObjectId, DisplayName, Risk, RecommendedAction
    #   BusinessOwner: [To be confirmed]
    #   ApprovalRequired: Yes
    #   ApprovalStatus: PendingReview
    #   ExecutionCommand: [Requires ExecuteRemediation mode — not generated in Assessment]
    #   RollbackNote: [Document before execution]
    #   EvidenceReference: $Finding.FindingId
    # Footer: Rev1.1 branding, consultant contact note
}
```

Gate 1 + Gate 2 after writing.

---

## STEP 8 — WRITE THE THREE PESTER TEST FILES

### tests\Rev11\Safety.Tests.ps1

Required tests (minimum):
1. Default mode is `Assessment`
2. `Assessment` mode does not expose remediation functions publicly
3. `ExecuteRemediation` cannot be set without explicit parameter
4. `New-DecomFinding` with ProtectedObject=$true sets flag correctly
5. Protected pattern `breakglass` is classified ProtectedObject
6. Destructive verbs (`Remove-`, `Set-`, `Disable-`) are not called by Discovery module

### tests\Rev11\Analysis.Tests.ps1

Required tests (minimum):
1. Disabled user with privileged role → Severity = Critical, RiskScore ≥ 80
2. Guest with privileged access → Severity = Critical
3. App with no owner → Severity = High or Critical
4. Informational finding has RiskScore ≤ 24
5. `Get-DecomFindingSummary` returns correct counts for mixed input
6. `Invoke-DecomAnalysis` sorts Critical before High before Medium

### tests\Rev11\Reporting.Tests.ps1

Required tests (minimum):
1. CSV export creates file at expected path
2. CSV contains required columns (FindingId, Severity, Category, Evidence, RecommendedAction)
3. JSON export produces valid JSON
4. JSON contains `SchemaVersion`, `Findings`, `FindingCount`
5. HTML export creates file
6. HTML contains `Executive Summary` text
7. Remediation plan contains `PendingReview`
8. Remediation plan references finding IDs

All tests must use mocks/stubs — no live Graph or Exchange connection required.

Gate 1 + Gate 2 on each test file.
Gate 3: `Invoke-Pester -Path .\tests\Rev11\ -Output Detailed` — must show 0 failures.

---

## STEP 9 — WRITE THE DOCS

### docs\Consultant-Runbook.md

```markdown
# Consultant Runbook — Entra Identity Decommissioning Control Plane

## Pre-Engagement
- Confirm tenant scope and read-only permissions
- Confirm whether sign-in/audit logs are available
- Confirm whether guest and app ownership analysis is in scope
- Confirm whether remediation planning is in scope

## Execution
1. Run assessment mode (no parameters required)
2. Validate coverage warnings in console output
3. Review critical and high findings
4. Export CSV, JSON, HTML, and Markdown outputs
5. Review exceptions with client

## Client Workshop
- Start with executive scorecard (HTML report)
- Explain residual access risk by category
- Review critical findings
- Separate true risks from approved exceptions
- Agree on remediation ownership and timeline

## Post-Workshop
- Update remediation plan with approvals
- Mark findings as Approved / Rejected / Deferred
- Prepare optional controlled ExecuteRemediation phase for Rev2.0

## Known Limitations
- Assessment mode reads only — no changes to tenant
- Sign-in log analysis requires AuditLog.Read.All scope
- IGA coverage requires EntitlementManagement.Read.All scope
- Rev1.1 does not support hybrid or on-premises AD DS environments
```

### docs\Required-Permissions.md

Full permissions table per Section 4 of the checklist spec:

| Permission | Type | Purpose | Required For |
|---|---|---|---|
| `User.Read.All` | Delegated | Read user lifecycle state | User discovery |
| `Directory.Read.All` | Delegated | Read directory objects | Groups, roles, directory relationships |
| `Application.Read.All` | Delegated | Read app registrations and service principals | App ownership drift |
| `AuditLog.Read.All` | Delegated | Read sign-in and audit signals | Stale identity assessment |
| `RoleManagement.Read.Directory` | Delegated | Read privileged role assignments | Privileged access residue |
| `EntitlementManagement.Read.All` | Delegated | Read access packages | IGA coverage |

Include minimum permission note: request only what is needed, explain what is unavailable if optional permissions are missing.

### docs\Findings-Catalog.md

Full catalog from Section 15 of the checklist:

| Finding ID | Category | Title | Default Severity |
|---|---|---|---|
| DEC-USER-001 | User Lifecycle | Disabled user retains group memberships | Medium |
| DEC-USER-002 | User Lifecycle | Disabled user retains app assignments | High |
| DEC-USER-003 | User Lifecycle | Disabled user has privileged access | Critical |
| DEC-APP-001 | Application | Application has no owner | High |
| DEC-APP-002 | Application | Application owned by disabled user | Critical |
| DEC-APP-003 | Application | Application has single owner | Medium |
| DEC-APP-004 | Application | Application secret expires soon | Medium |
| DEC-APP-005 | Application | Application has stale credential | High |
| DEC-GUEST-001 | Guest Lifecycle | Guest has stale sign-in | Medium |
| DEC-GUEST-002 | Guest Lifecycle | Guest has privileged access | Critical |
| DEC-GUEST-003 | Guest Lifecycle | Guest lacks sponsor metadata | Medium |
| DEC-CA-001 | Conditional Access | Identity excluded from CA policy | High |
| DEC-CA-002 | Conditional Access | CA exclusion group requires review | High |
| DEC-ROLE-001 | Privileged Access | Stale identity has active role | Critical |
| DEC-IGA-001 | Governance | Access package lacks review coverage | High |

---

## STEP 10 — WRITE THE SAMPLE FILES

Run demo mode once after the script is complete:
```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode -OutputPath .\samples
```

This generates the 4 sample files. Copy them to:
```
samples\sample-findings.csv
samples\sample-findings.json
samples\sample-report.html
samples\sample-remediation-plan.md
```

If the script is not yet runnable, hand-generate the samples from the synthetic dataset defined in Step 4.

---

## STEP 11 — UPDATE CHANGELOG.md

APPEND this block at the top of CHANGELOG.md (above all existing entries). Do not modify anything below it.

```markdown
## Rev1.1 — Consultant Readiness Hardening (2026-05-29)

### Added
- New entry point: `Invoke-EntraIdentityDecommissioningControlPlane.ps1`
- Assessment-first execution model — default mode is `Assessment`, no tenant modification
- Explicit run modes: Assessment, WhatIfRemediation, ExportPlan, ExecuteRemediation
- `-DemoMode` flag — synthetic data, no Graph connection required
- Standardized evidence-backed finding schema (`New-DecomFinding`)
- Severity and confidence model (Critical/High/Medium/Low/Informational + High/Medium/Low confidence)
- Timestamped output folder per run (`out\YYYYMMDD_HHmmss\`)
- CSV, JSON, HTML, and Markdown remediation plan exports
- Executive HTML report — dark theme, KPI grid, severity scorecard, filterable findings table
- Protected object classification model (break-glass, sync, emergency accounts)
- Coverage tracking model — reports partial coverage when Graph scopes are unavailable
- Consultant-facing remediation plan with approval status fields
- `docs\Consultant-Runbook.md`
- `docs\Required-Permissions.md`
- `docs\Findings-Catalog.md`
- `samples\` — demo-mode output files (CSV, JSON, HTML, Markdown)
- `tests\Rev11\` — Safety, Analysis, Reporting Pester suites (≥ 15 tests, 0 failures)

### Architecture
- `src\modules\Discovery.psm1` — assessment discovery with coverage tracking
- `src\modules\Analysis.psm1` — scoring engine, confidence model, protected object classification
- `src\modules\Reporting.psm1` — all export functions including HTML report generator
- `src\modules\RemediationPlan.psm1` — approval-ready Markdown plan generator
- `src\modules\Utilities.psm1` — console output helpers, finding object factory

### Unchanged
- All Lite decom modules (`src\LiteModules\`) — untouched
- All Premium batch modules (`src\Modules\`) — untouched
- All existing Pester suites — untouched, still passing
- Existing docs, SECURITY.md, LICENSE — untouched
```

---

## STEP 12 — FINAL VERIFICATION SEQUENCE

Run in order. Do not skip. Report actual output for each.

```powershell
# Gate 1 — parse all new files
$newFiles = @(
    '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1',
    '.\src\modules\Utilities.psm1',
    '.\src\modules\Discovery.psm1',
    '.\src\modules\Analysis.psm1',
    '.\src\modules\Reporting.psm1',
    '.\src\modules\RemediationPlan.psm1',
    '.\tests\Rev11\Safety.Tests.ps1',
    '.\tests\Rev11\Analysis.Tests.ps1',
    '.\tests\Rev11\Reporting.Tests.ps1'
)
foreach ($f in $newFiles) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        (Resolve-Path $f), [ref]$null, [ref]$errors)
    Write-Host "$f — Parse errors: $($errors.Count)"
}
# Every line must show: parse errors: 0
```

```powershell
# Gate 2 — import all new modules silently
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
# Every line must show: Import OK with no warnings above it
```

```powershell
# Gate 3 — full Rev1.1 Pester suite
Invoke-Pester -Path .\tests\Rev11\ -Output Detailed
# Must show 0 failures, Tests count >= 15
```

```powershell
# Demo mode smoke test
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode
# Must:
# - Print banner with Mode: Assessment and green safety line
# - Print finding counts: 1 CRITICAL, 2 HIGH, 3 MEDIUM, 1 LOW, 1 INFO
# - Print [OK] export lines for all 4 outputs + manifest
# - Create output folder with all 5 files
# - Exit 0
```

**Only after all four commands show clean output — declare Rev1.1 complete.**

Do not push. Albert pushes manually.
