#Requires -Version 5.1
<#
.SYNOPSIS
    Copy-SimulatorToGit.ps1
    Copies Identity Attack & Recovery Simulator project files from Downloads
    to C:\Git\identity-attack-simulator

.VERSION
    v0.1 — 2026-05-22 — Albert Jee — Initial release

.NOTES
    Mainframe discipline: every copy is verified by file existence check.
    Script never declares success without confirmed outcome.
    Run from any location. No elevated rights required.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── CONFIG ──────────────────────────────────────────────────────────────────
$Source      = "$env:USERPROFILE\Downloads"
$Destination = "C:\Git\identity-attack-simulator"

# Files to copy — add new entries here as the project grows
$FilesToCopy = @(
    @{ File = "identity-attack-recovery-simulator-v02.html"; Required = $true  },
    @{ File = "identity-attack-recovery-simulator.html";     Required = $false },
    @{ File = "identity_attack_recovery_simulator_build_spec_v0_1.md"; Required = $false },
    @{ File = "Note_41_transcript.pdf";                      Required = $false },
    @{ File = "en-product-demo-under-attack-surviving-restoring-identity-attack.pdf"; Required = $false }
)

# ── INIT ────────────────────────────────────────────────────────────────────
$Pass  = 0
$Fail  = 0
$Skip  = 0
$Log   = [System.Collections.Generic.List[string]]::new()

function Write-Status {
    param([string]$Icon, [string]$Msg, [ConsoleColor]$Color = 'White')
    $line = "  $Icon  $Msg"
    Write-Host $line -ForegroundColor $Color
    $Log.Add("$(Get-Date -Format 'HH:mm:ss')  $line")
}

Write-Host ""
Write-Host "  Identity Attack & Recovery Simulator — File Copy" -ForegroundColor Cyan
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Source  : $Source" -ForegroundColor DarkGray
Write-Host "  Dest    : $Destination" -ForegroundColor DarkGray
Write-Host ""

# ── VERIFY DESTINATION ──────────────────────────────────────────────────────
$SubDirs = @(
    $Destination,
    "$Destination\assets",
    "$Destination\assets\screenshots"
)

foreach ($dir in $SubDirs) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Status "+" "Created directory: $dir" -Color DarkGray
    }
}

# ── COPY FILES ──────────────────────────────────────────────────────────────
Write-Host "  Copying files..." -ForegroundColor DarkGray
Write-Host ""

foreach ($entry in $FilesToCopy) {
    $srcPath  = Join-Path $Source      $entry.File
    $destPath = Join-Path $Destination $entry.File

    # Source exists?
    if (-not (Test-Path $srcPath)) {
        if ($entry.Required) {
            Write-Status "✗" "$($entry.File)  [MISSING — required]" -Color Red
            $Fail++
        } else {
            Write-Status "–" "$($entry.File)  [not found — skipped]" -Color DarkGray
            $Skip++
        }
        continue
    }

    # Copy
    try {
        Copy-Item -Path $srcPath -Destination $destPath -Force

        # Verify
        if (Test-Path $destPath) {
            $srcSize  = (Get-Item $srcPath).Length
            $destSize = (Get-Item $destPath).Length
            if ($srcSize -eq $destSize) {
                Write-Status "✓" "$($entry.File)  ($([math]::Round($destSize/1KB,1)) KB)" -Color Green
                $Pass++
            } else {
                Write-Status "!" "$($entry.File)  [size mismatch — src $srcSize / dest $destSize]" -Color Yellow
                $Fail++
            }
        } else {
            Write-Status "✗" "$($entry.File)  [copy failed — dest not found]" -Color Red
            $Fail++
        }
    } catch {
        Write-Status "✗" "$($entry.File)  [ERROR: $($_.Exception.Message)]" -Color Red
        $Fail++
    }
}

# ── SUMMARY ─────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ─────────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Results" -ForegroundColor Cyan
Write-Host "    Copied  : $Pass" -ForegroundColor Green
Write-Host "    Skipped : $Skip" -ForegroundColor DarkGray
if ($Fail -gt 0) {
    Write-Host "    Failed  : $Fail" -ForegroundColor Red
} else {
    Write-Host "    Failed  : $Fail" -ForegroundColor Green
}
Write-Host ""

# ── VERIFY DESTINATION CONTENTS ─────────────────────────────────────────────
Write-Host "  Destination contents:" -ForegroundColor DarkGray
Get-ChildItem -Path $Destination -File | ForEach-Object {
    Write-Host "    $($_.Name)  ($([math]::Round($_.Length/1KB,1)) KB)" -ForegroundColor DarkGray
}
Write-Host ""

# ── EXIT CODE ────────────────────────────────────────────────────────────────
if ($Fail -gt 0) {
    Write-Host "  STATUS: COMPLETED WITH ERRORS — review failures above" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  STATUS: ALL REQUIRED FILES VERIFIED" -ForegroundColor Green
    exit 0
}
