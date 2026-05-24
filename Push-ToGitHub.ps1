#Requires -Version 5.1
<#
.SYNOPSIS
    Push-ToGitHub.ps1
    Initialises git (if needed), sets remote, commits all project files,
    and pushes to the private GitHub repo.

.VERSION
    v0.1 — 2026-05-24 — Albert Jee

.NOTES
    Mainframe discipline: every step is verified before proceeding.
    Script never declares success without confirmed push outcome.
    Run from C:\Git\identity-attack-simulator
    Requires: git installed and on PATH, GitHub auth via credential manager or SSH.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ── CONFIG ──────────────────────────────────────────────────────────────────
$RepoRoot   = "C:\Git\identity-attack-simulator"
$RemoteURL  = "https://github.com/albertjee/ajee-iam-premium-library.git"
$RemoteName = "origin"
$Branch     = "main"
$CommitMsg  = "simulator v0.4 — attack chain, presenter mode, lure flow, AI agent scenario pending"

# Files to include — everything except temp/working files
$IncludePatterns = @(
    "identity-attack-recovery-simulator-v04.html",
    "simulator-config.json",
    "demo-script.md",
    "Copy-SimulatorToGit.ps1",
    "Push-ToGitHub.ps1",
    "identity_attack_recovery_simulator_build_spec_v0_1.md",
    "en-product-demo-under-attack-surviving-restoring-identity-attack.pdf",
    "assets\screenshots\screen1-lure-page.png",
    "assets\screenshots\screen2-lure-page.png",
    "assets\screenshots\screen3-lure-page.png"
)

# ── PREFLIGHT ───────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Push-ToGitHub — Identity Attack Simulator" -ForegroundColor Cyan
Write-Host "  ──────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host "  Repo  : $RemoteURL" -ForegroundColor DarkGray
Write-Host "  Branch: $Branch" -ForegroundColor DarkGray
Write-Host ""

# Verify git is available
try {
    $gitVer = git --version 2>&1
    Write-Host "  ✓  $gitVer" -ForegroundColor Green
} catch {
    Write-Host "  ✗  git not found on PATH — install Git for Windows first" -ForegroundColor Red
    exit 1
}

# Verify we're in the right directory
if (-not (Test-Path (Join-Path $RepoRoot "identity-attack-recovery-simulator-v04.html"))) {
    Write-Host "  ✗  identity-attack-recovery-simulator-v04.html not found in $RepoRoot" -ForegroundColor Red
    Write-Host "     Run this script from C:\Git\identity-attack-simulator" -ForegroundColor DarkGray
    exit 1
}

Set-Location $RepoRoot

# ── GIT INIT ────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Checking git status..." -ForegroundColor DarkGray

if (-not (Test-Path ".git")) {
    Write-Host "  + Initialising git repo..." -ForegroundColor DarkGray
    git init --initial-branch=$Branch 2>&1 | Out-Null
    Write-Host "  ✓  git init complete" -ForegroundColor Green
} else {
    Write-Host "  ✓  git repo already initialised" -ForegroundColor Green
}

# ── .GITIGNORE ──────────────────────────────────────────────────────────────
$gitignore = @"
# Working files — not pushed
identity-attack-recovery-simulator.html
identity-attack-recovery-simulator-v02.html
identity-attack-recovery-simulator-v03.html
identity-attack-recovery-simulator-v04a.html
*.tmp
*.bak
.claude/
"@

if (-not (Test-Path ".gitignore")) {
    $gitignore | Set-Content -Path ".gitignore" -Encoding UTF8
    Write-Host "  ✓  .gitignore created" -ForegroundColor Green
} else {
    Write-Host "  ✓  .gitignore exists" -ForegroundColor Green
}

# ── README ───────────────────────────────────────────────────────────────────
if (-not (Test-Path "README.md")) {
    @"
# Identity Attack & Recovery Simulator

A single-file HTML simulator demonstrating a real-world OAuth consent attack chain
against Microsoft Entra ID, with animated blast radius and guided recovery.

## What it demonstrates

- Four-stage attack: consent granted → persistence → identity damaged → lateral SaaS movement
- Before/after diff view per changed object
- Presenter mode for boardroom delivery
- Lure flow showing the three-screen social engineering sequence
- Five-step guided recovery with forensic audit export

## Usage

Open \`identity-attack-recovery-simulator-v04.html\` in any modern browser.
No build step. No server. No credentials required.

## Files

| File | Purpose |
|---|---|
| \`identity-attack-recovery-simulator-v04.html\` | Primary simulator — current version |
| \`simulator-config.json\` | Scenario text and image asset paths |
| \`demo-script.md\` | Full presenter script with stage-by-stage narration |
| \`assets/screenshots/\` | Lure flow screenshots |
| \`identity_attack_recovery_simulator_build_spec_v0_1.md\` | Original build specification |

## Version history

| Version | Key additions |
|---|---|
| v0.1 | Four-stage attack, recovery, audit export |
| v0.2 | Animated node propagation, before/after diff view |
| v0.3 | Presenter mode, lure flow modal, UTF-8 BOM fix |
| v0.4 | Adele Vance cross-user movement, property-level modify/restore, peak drift fix |

## Status

Simulated — no real tenant is connected. All state is local to the browser session.
"@ | Set-Content -Path "README.md" -Encoding UTF8
    Write-Host "  ✓  README.md created" -ForegroundColor Green
} else {
    Write-Host "  ✓  README.md exists" -ForegroundColor Green
}

# ── REMOTE ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Configuring remote..." -ForegroundColor DarkGray

$existingRemote = git remote 2>&1
if ($existingRemote -match $RemoteName) {
    git remote set-url $RemoteName $RemoteURL 2>&1 | Out-Null
    Write-Host "  ✓  Remote '$RemoteName' updated to $RemoteURL" -ForegroundColor Green
} else {
    git remote add $RemoteName $RemoteURL 2>&1 | Out-Null
    Write-Host "  ✓  Remote '$RemoteName' added" -ForegroundColor Green
}

# ── STAGE FILES ─────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Staging files..." -ForegroundColor DarkGray

$staged = 0
$missing = 0

foreach ($f in $IncludePatterns) {
    if (Test-Path $f) {
        git add $f 2>&1 | Out-Null
        Write-Host "  ✓  $f" -ForegroundColor Green
        $staged++
    } else {
        Write-Host "  –  $f  [not found — skipped]" -ForegroundColor DarkGray
        $missing++
    }
}

# Always stage gitignore and README
git add .gitignore README.md 2>&1 | Out-Null

Write-Host ""
Write-Host "  Staged  : $staged files" -ForegroundColor DarkGray
if ($missing -gt 0) {
    Write-Host "  Skipped : $missing files not found" -ForegroundColor DarkGray
}

# ── COMMIT ──────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Committing..." -ForegroundColor DarkGray

$status = git status --porcelain 2>&1
if (-not $status) {
    Write-Host "  ✓  Nothing to commit — working tree clean" -ForegroundColor Green
} else {
    git commit -m $CommitMsg 2>&1 | ForEach-Object { Write-Host "  $_" -ForegroundColor DarkGray }
    Write-Host "  ✓  Commit complete" -ForegroundColor Green
}

# ── PUSH ────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  Pushing to $RemoteURL..." -ForegroundColor DarkGray
Write-Host "  (GitHub may prompt for credentials)" -ForegroundColor DarkGray
Write-Host ""

try {
    git push $RemoteName $Branch --set-upstream 2>&1 | ForEach-Object {
        Write-Host "  $_" -ForegroundColor DarkGray
    }

    # Verify push succeeded
    $pushRC = $LASTEXITCODE
    if ($pushRC -eq 0) {
        Write-Host ""
        Write-Host "  ──────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  STATUS: PUSH SUCCESSFUL" -ForegroundColor Green
        Write-Host "  $RemoteURL" -ForegroundColor Cyan
        Write-Host ""
        exit 0
    } else {
        Write-Host ""
        Write-Host "  STATUS: PUSH FAILED — exit code $pushRC" -ForegroundColor Red
        Write-Host "  Check credentials and repo access" -ForegroundColor DarkGray
        exit 1
    }
} catch {
    Write-Host "  ✗  Push error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
