#Requires -Version 5.1
<#
.SYNOPSIS
    Rev4.0 M36 Push Readiness Check.

.DESCRIPTION
    Runs all gates before push is authorized. Mirrors Test-Rev39PushReadiness pattern.
    Includes:
    - Gate 1: Parse checks on all new/modified files
    - Gate 2: Module import checks
    - Gate 3: Pester suite (baseline >= 1320, 0 failures)
    - Gate 4: Git status check
    - Gate 5: Confirm-NhiApprovedManifest smoke test
    - Final Go/NoGo verdict

    Run from repo root:  pwsh -File tools/Test-Rev40PushReadiness.ps1
#>

param(
    [string]$ModuleRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Write-Host '=== Rev4.0 M36 Push Readiness Check ===' -ForegroundColor Cyan
Write-Host '=' * 48 -ForegroundColor DarkCyan

$results = @{}
$gateNames = @('Gate1', 'Gate3Count', 'Gate3Pass', 'Gate4', 'Gate5Manifest')

# ── Gate 1: Parse all new/modified files ──────────────────────────────────────
Write-Host ''
Write-Host '[Gate 1] Parse checks...' -ForegroundColor Yellow

$parseFiles = @(
    'src\Modules\NhiExecutionSchema.psm1',
    'src\Modules\NhiExecution.psm1',
    'tests\DestructiveCmdletGuard.Rev40.Tests.ps1',
    'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
)

$gate1Pass = $true
foreach ($f in $parseFiles) {
    $fullPath = Join-Path $ModuleRoot $f
    if (-not (Test-Path $fullPath)) {
        Write-Host "  SKIP: $f (not found)" -ForegroundColor DarkGray
        continue
    }
    $errors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile(
        $fullPath, [ref]$null, [ref]$errors)
    if ($errors.Count -gt 0) {
        Write-Host "  FAIL: $f — $($errors.Count) parse error(s)" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        $gate1Pass = $false
    } else {
        Write-Host "  OK:   $f" -ForegroundColor Green
    }
}
$results['Gate1'] = $gate1Pass

# ── Gate 2: Module import checks ──────────────────────────────────────────────
Write-Host ''
Write-Host '[Gate 2] Module import checks...' -ForegroundColor Yellow

$modulesToCheck = @(
    'src\Modules\NhiExecutionSchema.psm1',
    'src\Modules\NhiExecution.psm1'
)

foreach ($m in $modulesToCheck) {
    $modPath = Join-Path $ModuleRoot $m
    if (-not (Test-Path $modPath)) {
        Write-Host "  SKIP: $m (not found)" -ForegroundColor DarkGray
        continue
    }
    $modName = [System.IO.Path]::GetFileNameWithoutExtension($m)
    Remove-Module $modName -Force -ErrorAction SilentlyContinue
    $importErr = $null
    Import-Module $modPath -Force -DisableNameChecking 2>
$importErr | Out-Null
    if ($importErr) {
        Write-Host "  FAIL: $m — import warning/error" -ForegroundColor Red
        $results['Gate2Import'] = $false
    } else {
        Write-Host "  OK:   $m" -ForegroundColor Green
    }
}
if ($null -eq $results['Gate2Import']) {
    $results['Gate2Import'] = $true
}

# ── Gate 3: Pester suite ──────────────────────────────────────────────────────
Write-Host ''
Write-Host '[Gate 3] Running Pester suite...' -ForegroundColor Yellow

$testPath = Join-Path $ModuleRoot 'tests'
$output = Invoke-Pester -Path $testPath -Output Detailed 2>&1

$totalTests = 0
$passedTests = 0
$failedTests = 0

$output | Select-String 'Discovery found' | ForEach-Object {
    if ($_ -match '(\d+)') { $totalTests = [int]$matches[1] }
}
$output | Select-String 'Tests Passed' | Select-Object -Last 1 | ForEach-Object {
    if ($_ -match 'Tests Passed:\s*(\d+)') { $passedTests = [int]$matches[1] }
}
$output | Select-String 'Failed:' | Select-Object -Last 1 | ForEach-Object {
    if ($_ -match 'Failed:\s*(\d+)') { $failedTests = [int]$matches[1] }
}

Write-Host "  Total:  $totalTests"
Write-Host "  Passed: $passedTests"
Write-Host "  Failed: $failedTests" -ForegroundColor $(if ($failedTests -gt 0) { 'Red' } else { 'Green' })

$baseline = 1320
if ($totalTests -lt $baseline) {
    Write-Host "  FAIL: Test count $totalTests below baseline $baseline" -ForegroundColor Red
    $results['Gate3Count'] = $false
} else {
    Write-Host "  OK:   Test count meets baseline ($totalTests >= $baseline)" -ForegroundColor Green
    $results['Gate3Count'] = $true
}

if ($failedTests -gt 0) {
    Write-Host "  FAIL: $failedTests test(s) failed" -ForegroundColor Red
    $results['Gate3Pass'] = $false
} else {
    Write-Host "  OK:   All tests passing" -ForegroundColor Green
    $results['Gate3Pass'] = $true
}

# ── Gate 4: Git status check ──────────────────────────────────────────────────
Write-Host ''
Write-Host '[Gate 4] Git status check...' -ForegroundColor Yellow

$gitCmd = git -C $ModuleRoot status --porcelain
$stagedChanges = $gitCmd | Where-Object { $_ -match '^.[ACDMR]' }
$untracked = $gitCmd | Where-Object { $_ -match '^[^? ?]' -and $_ -notmatch '^.. [A-Z]' }

if ($stagedChanges) {
    Write-Host "  Note: Staged changes present (expected if committing):" -ForegroundColor Yellow
    $stagedChanges | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
}
if ($untracked) {
    Write-Host "  Note: Non-ignored untracked files present:" -ForegroundColor Yellow
    $untracked | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
}

Write-Host "  OK:   Git status check complete" -ForegroundColor Green
$results['Gate4'] = $true

# ── Gate 5: Manifest validation smoke test ────────────────────────────────────
Write-Host ''
Write-Host '[Gate 5] Confirm-NhiApprovedManifest smoke test...' -ForegroundColor Yellow

Import-Module (Join-Path $ModuleRoot 'src\Modules\NhiExecutionSchema.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $ModuleRoot 'src\Modules\NhiExecution.psm1') -Force -DisableNameChecking

# Create a manifest missing ApprovedBy (empty string — should fail)
$badManifestPath = Join-Path $env:TEMP "NhiSmokeTest_$(Get-Random).json"
$badContent = @{
    EngagementId          = 'ENG-PUSHTEST-001'
    TargetObjectIds        = @()
    ApprovedBy            = ''
    ApprovedAt            = '2026-06-01T12:00:00Z'
    ExecutionPhaseApproved = 3
    SHA256                = 'abc123'
    SchemaVersion         = '1.0'
} | ConvertTo-Json -Compress
[System.IO.File]::WriteAllText($badManifestPath, $badContent, [System.Text.UTF8Encoding]::new($false))

$threw = $false
$errorMsg = ''
try {
    $null = Confirm-NhiApprovedManifest -ManifestPath $badManifestPath -PhaseLimit 3
} catch {
    $threw = $true
    $errorMsg = $_.Exception.Message
}

if ($threw) {
    Write-Host "  OK:   Confirm-NhiApprovedManifest throws on invalid manifest" -ForegroundColor Green
    Write-Host "        Reason (first 120 chars): $($errorMsg.Substring(0, [Math]::Min(120, $errorMsg.Length)))" -ForegroundColor DarkGray
    $results['Gate5Manifest'] = $true
} else {
    Write-Host "  FAIL: Confirm-NhiApprovedManifest did not throw on empty ApprovedBy" -ForegroundColor Red
    $results['Gate5Manifest'] = $false
}

Remove-Item $badManifestPath -Force -ErrorAction SilentlyContinue

# ── Final verdict ────────────────────────────────────────────────────────────
Write-Host ''
Write-Host '=== VERDICT ===' -ForegroundColor Cyan
Write-Host '=' * 48 -ForegroundColor DarkCyan

$allPassed = $true
$gateNames | ForEach-Object {
    if ($null -eq $results[$_]) { $results[$_] = $false }
    if ($results[$_] -eq $false) { $allPassed = $false }
}

$results.GetEnumerator() | ForEach-Object {
    $status = if ($_.Value) { 'PASS' } else { 'FAIL' }
    $color  = if ($_.Value) { 'Green' } else { 'Red' }
    Write-Host "  $($_.Key): $status" -ForegroundColor $color
}

Write-Host ''
if ($allPassed) {
    Write-Host '  GO — All gates passed.' -ForegroundColor Green
    Write-Host '  Ready to commit Rev4.0 M36.' -ForegroundColor Green
    exit 0
} else {
    Write-Host '  NO-GO — One or more gates failed.' -ForegroundColor Red
    Write-Host '  Fix failures before committing.' -ForegroundColor Red
    $failures = $results.GetEnumerator() | Where-Object { $_.Value -eq $false } | Select-Object -ExpandProperty Key
    Write-Host "  Failed gates: $($failures -join ', ')" -ForegroundColor Red
    exit 1
}