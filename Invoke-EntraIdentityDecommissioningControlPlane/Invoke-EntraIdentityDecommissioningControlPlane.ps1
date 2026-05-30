#Requires -Version 5.1
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

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $ScriptRoot 'src\modules'

foreach ($mod in @('Utilities','Discovery','Analysis','Reporting','RemediationPlan')) {
    $modPath = Join-Path $ModulesPath "$mod.psm1"
    Remove-Module $mod -Force -ErrorAction SilentlyContinue
    Import-Module $modPath -Force -DisableNameChecking
}

$Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$RunFolder = Join-Path $OutputPath $Timestamp
New-Item -ItemType Directory -Path $RunFolder -Force | Out-Null

if (-not $NoLogo) {
    $borderColor = 'DarkCyan'
    $modeColor   = if ($Mode -eq 'ExecuteRemediation') { 'Red' } else { 'Yellow' }
    $tenantLabel = if ($DemoMode) { 'DEMO' } else { if ($TenantId) { $TenantId } else { 'Not specified' } }
    $startTime   = Get-DecomTimestampDisplay

    Write-Host ('=' * 64) -ForegroundColor $borderColor
    Write-Host '  Entra Identity Decommissioning Control Plane  Rev1.1' -ForegroundColor Cyan
    Write-Host '  Assessment-first tooling for identity governance reviews' -ForegroundColor DarkCyan
    Write-Host ('=' * 64) -ForegroundColor $borderColor
    Write-Host "  Mode     : $Mode" -ForegroundColor $modeColor
    Write-Host "  Tenant   : $tenantLabel" -ForegroundColor Gray
    Write-Host "  Started  : $startTime" -ForegroundColor Gray
    Write-Host "  Output   : $RunFolder" -ForegroundColor Gray
    Write-Host ''
    if ($Mode -in 'Assessment','WhatIfRemediation') {
        Write-Host '*** No tenant modifications will be performed in Assessment mode. ***' -ForegroundColor Green
    }
    Write-Host ('=' * 64) -ForegroundColor $borderColor
    Write-Host ''
}

$Context = [PSCustomObject]@{
    TenantId     = if ($DemoMode) { 'contoso.onmicrosoft.com' } else { $TenantId }
    ClientId     = $ClientId
    Mode         = $Mode
    DemoMode     = $DemoMode.IsPresent
    EngagementId = $EngagementId
    ClientName   = $ClientName
    Assessor     = $Assessor
    Coverage     = $null
}

if (-not $DemoMode -and $Mode -in 'Assessment','WhatIfRemediation') {
    Write-DecomInfo "Connecting to Microsoft Graph (read-only scopes)..."
    try {
        $scopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'AuditLog.Read.All',
            'RoleManagement.Read.Directory',
            'EntitlementManagement.Read.All'
        )
        Connect-MgGraph -Scopes $scopes -TenantId $TenantId -ErrorAction Stop | Out-Null
        Write-DecomOk "Graph connection established"
    } catch {
        Write-DecomError "Graph connection failed: $_"
        exit 1
    }
}

Write-DecomInfo "Starting discovery..."
$Findings = Invoke-DecomAssessmentDiscovery -Context $Context -DemoMode:$DemoMode
Write-DecomOk "Discovery complete — $($Findings.Count) raw finding(s)"

Write-DecomInfo "Running analysis..."
$Findings = Invoke-DecomAnalysis -Findings $Findings
$Summary  = Get-DecomFindingSummary -Findings $Findings
Write-DecomOk "Analysis complete"

Write-Host ''
Write-Host "  Finding counts:" -ForegroundColor DarkCyan
Write-Host "    CRITICAL findings : $($Summary.Critical)" -ForegroundColor Red
Write-Host "    HIGH findings     : $($Summary.High)"     -ForegroundColor DarkYellow
Write-Host "    MEDIUM findings   : $($Summary.Medium)"   -ForegroundColor Cyan
Write-Host "    LOW findings      : $($Summary.Low)"      -ForegroundColor Green
Write-Host "    INFO findings     : $($Summary.Informational)" -ForegroundColor Gray
Write-Host ''

$fileBase   = "entra-decommissioning-control-plane"
$CsvPath    = Join-Path $RunFolder "$fileBase-assessment-$Timestamp.csv"
$JsonPath   = Join-Path $RunFolder "$fileBase-findings-$Timestamp.json"
$HtmlPath   = Join-Path $RunFolder "$fileBase-report-$Timestamp.html"
$PlanPath   = Join-Path $RunFolder "$fileBase-remediation-plan-$Timestamp.md"
$ManifestPath = Join-Path $RunFolder "$fileBase-run-manifest-$Timestamp.json"

Write-DecomInfo "Exporting CSV..."
Export-DecomAssessmentCsv -Findings $Findings -Path $CsvPath
Write-DecomOk "CSV exported"

Write-DecomInfo "Exporting JSON..."
Export-DecomAssessmentJson -Findings $Findings -Path $JsonPath -Context $Context
Write-DecomOk "JSON exported"

Write-DecomInfo "Generating HTML report..."
$summaryHt = @{
    Critical      = $Summary.Critical
    High          = $Summary.High
    Medium        = $Summary.Medium
    Low           = $Summary.Low
    Informational = $Summary.Informational
    Total         = $Summary.Total
}
Export-DecomAssessmentHtml -Findings $Findings -Path $HtmlPath -Context $Context -Summary $summaryHt
Write-DecomOk "HTML report generated"

Write-DecomInfo "Generating remediation plan..."
Export-DecomRemediationPlan -Findings $Findings -Path $PlanPath -Context $Context
Write-DecomOk "Remediation plan generated"

Write-DecomInfo "Writing run manifest..."
$exportPaths = @{
    Csv             = $CsvPath
    Json            = $JsonPath
    Html            = $HtmlPath
    RemediationPlan = $PlanPath
    Manifest        = $ManifestPath
}
Write-DecomRunManifest -Path $ManifestPath -Context $Context -Summary $summaryHt -ExportPaths $exportPaths
Write-DecomOk "Run manifest written"

Write-Host ''
Write-Host ('=' * 64) -ForegroundColor DarkCyan
Write-Host '  Assessment complete.' -ForegroundColor Cyan
Write-Host ''
Write-Host '  Findings:' -ForegroundColor DarkCyan
Write-Host "    CRITICAL : $($Summary.Critical)" -ForegroundColor Red
Write-Host "    HIGH     : $($Summary.High)"     -ForegroundColor DarkYellow
Write-Host "    MEDIUM   : $($Summary.Medium)"   -ForegroundColor Cyan
Write-Host "    LOW      : $($Summary.Low)"      -ForegroundColor Green
Write-Host "    INFO     : $($Summary.Informational)" -ForegroundColor Gray
Write-Host ''
Write-Host '  Exports:' -ForegroundColor DarkCyan
Write-Host "    [OK]  CSV              : $CsvPath" -ForegroundColor Green
Write-Host "    [OK]  JSON             : $JsonPath" -ForegroundColor Green
Write-Host "    [OK]  HTML Report      : $HtmlPath" -ForegroundColor Green
Write-Host "    [OK]  Remediation Plan : $PlanPath" -ForegroundColor Green
Write-Host "    [OK]  Run Manifest     : $ManifestPath" -ForegroundColor Green
Write-Host ''
Write-Host "  Output folder : $RunFolder" -ForegroundColor Gray
Write-Host ('=' * 64) -ForegroundColor DarkCyan

exit 0
