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
    [string]$WhatIfManifestPath,
    [string]$ApprovalManifestPath,
    [switch]$NonInteractive,
    [switch]$GenerateApprovalTemplate,

    [int]$MaxActions     = 25,
    [string[]]$ActionId,
    [switch]$RequirePreflightConfirm,

    [switch]$DemoMode,
    [switch]$NoLogo,
    [string]$BaselinePath,
    [switch]$GenerateExecutivePack,
    [switch]$SelfTest,
    [switch]$GenerateReleasePackage,
    [string]$ReleasePackagePath = '.\release\Rev3.4',

    # Rev3.4 hardening output flags (all default off — backward compatible)
    [switch]$GenerateEvidenceBundle,
    [switch]$GenerateRedactedPackage,
    [ValidateSet('ClientSafe','PublicDemo','Strict','Internal')]
    [string]$RedactionProfile = 'ClientSafe',
    [switch]$GenerateReplayValidation,
    [switch]$GenerateApprovalDiff,
    [switch]$GenerateTraceabilityReport,
    [switch]$GenerateClientHandoff,
    [switch]$GenerateRev35Readiness,

    # Rev3.5 NHI / Agentic Identity output flags
    [switch]$GenerateNhiGovernancePack
)

# Tool version — update this single constant each release
$script:ToolVersion = 'Rev3.6'

if ($Mode -eq 'ExecuteRemediation' -and $DemoMode) {
    Write-Host "[ERROR] ExecuteRemediation cannot run in DemoMode." -ForegroundColor Red
    exit 1
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Block unsafe parameter combinations
if ($SelfTest -and $Mode -eq 'ExecuteRemediation') {
    Write-Host "[ERROR] -SelfTest cannot be used with -Mode ExecuteRemediation." -ForegroundColor Red
    exit 1
}

if ($GenerateReleasePackage -and $Mode -eq 'ExecuteRemediation') {
    Write-Host "[ERROR] -GenerateReleasePackage should not be used with -Mode ExecuteRemediation for Rev3.0." -ForegroundColor Red
    exit 1
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$ModulesPath = Join-Path $ScriptRoot 'src\Modules'

$modulesToLoad = @(
    'Utilities'
    'Discovery'
    'Analysis'
    'Reporting'
    'RemediationPlan'
    'ApprovalManifest'
    'ExecutionLog'
    'Remediation'
    'Baseline'
    'ExecutivePack'
    'ReleaseValidation'
    'CatalogValidation'
    'SchemaContracts'
    'WriteReadiness'
    'ApplicationGovernance'
    'CredentialHygiene'
    'ConditionalAccessGovernance'
    'EmergencyAccessGovernance'
    'ReleasePackaging'
    'GuestGovernance'
    'Rev3CapabilityMatrix'
    'NhiDiscovery'
    'NhiAnalysis'
    'NhiGovernance'
    'NhiReporting'
)

foreach ($mod in $modulesToLoad) {
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
    Write-Host "  Entra Identity Decommissioning Control Plane  $script:ToolVersion" -ForegroundColor Cyan
    Write-Host '  Assessment-first tooling for identity governance reviews' -ForegroundColor DarkCyan
    Write-Host ('=' * 64) -ForegroundColor $borderColor
    Write-Host "  Mode     : $Mode" -ForegroundColor $modeColor
    Write-Host "  Tenant   : $tenantLabel" -ForegroundColor Gray
    Write-Host "  Started  : $startTime" -ForegroundColor Gray
    Write-Host "  Output   : $RunFolder" -ForegroundColor Gray
    Write-Host ''
    if ($Mode -in 'Assessment','WhatIfRemediation','ExportPlan') {
        Write-Host "*** No tenant modifications will be performed in $Mode mode. ***" -ForegroundColor Green
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
    ToolVersion  = $script:ToolVersion
    OutputPath   = $RunFolder
}

# SelfTest early exit — no Graph connection, no discovery, no remediation
if ($SelfTest) {
    Write-DecomInfo "Running SelfTest / ReleaseValidation mode..."
    $selfTestResult = Invoke-DecomReleaseValidation -Context $Context
    if ($selfTestResult.Passed) {
        Write-DecomOk "SelfTest PASSED"
        if ($GenerateReleasePackage) {
            Write-DecomInfo "Generating release package..."
            New-DecomReleasePackage -Context $Context -OutputPath $ReleasePackagePath
            Write-DecomOk "Release package generated at $ReleasePackagePath"
        }
        exit 0
    } else {
        Write-DecomError "SelfTest FAILED:"
        $selfTestResult.Errors | ForEach-Object { Write-DecomError "  $_" }
        exit 1
    }
}

# ExecuteRemediation branch - runs BEFORE discovery, analysis, and export
if ($Mode -eq 'ExecuteRemediation') {
    # Validate Gate A - WhatIf manifest
    Write-DecomInfo "Validating Gate A: WhatIf manifest..."
    $gateAResult = Test-DecomWhatIfManifest -ManifestPath $WhatIfManifestPath -CurrentEngagementId $EngagementId
    if (-not $gateAResult.Valid) {
        Write-DecomError "Gate A validation failed:"
        $gateAResult.Errors | ForEach-Object { Write-DecomError "  $_" }
        exit 1
    }
    Write-DecomOk "Gate A validation passed"

    # Validate Gate B - Approval manifest
    Write-DecomInfo "Validating Gate B: Approval manifest..."
    $gateBResult = Test-DecomApprovalManifest -ManifestPath $ApprovalManifestPath -CurrentEngagementId $EngagementId -CurrentClientName $ClientName -WhatIfRunId $gateAResult.Manifest.RunId -NonInteractive:$NonInteractive.IsPresent
    if (-not $gateBResult.Valid) {
        Write-DecomError "Gate B validation failed:"
        $gateBResult.Errors | ForEach-Object { Write-DecomError "  $_" }
        exit 1
    }
    Write-DecomOk "Gate B validation passed"

    # ================================================================
    # EXECUTION PREFLIGHT REPORT
    # Runs after Gate A/B but before Graph write connection
    # ================================================================
    $approvedActions = $gateBResult.Manifest.ApprovedActions

    # Apply -ActionId filter FIRST so MaxActions check measures the filtered set
    if ($ActionId -and $ActionId.Count -gt 0) {
        $approvedActions = @($approvedActions | Where-Object { $ActionId -contains $_.ActionId })
        Write-DecomInfo "ActionId filter applied — $($approvedActions.Count) action(s) selected."
    }

    # Apply -MaxActions guardrail against the (possibly filtered) set
    if ($approvedActions.Count -gt $MaxActions) {
        Write-DecomError "Action count ($($approvedActions.Count)) exceeds -MaxActions ($MaxActions)."
        Write-DecomError "Use -MaxActions $($approvedActions.Count) to override."
        exit 1
    }

    if ($approvedActions.Count -eq 0) {
        Write-DecomError "No approved actions remaining after filters. Nothing to execute."
        exit 1
    }

    $groupCounts = $approvedActions | Group-Object ActionType |
        ForEach-Object { "  $($_.Name): $($_.Count)" }
    $affectedUsers  = @($approvedActions | Select-Object -ExpandProperty ObjectId -Unique).Count
    $affectedGroups = @($approvedActions |
        Where-Object { $_.ActionType -eq 'RemoveGroupMembership' } |
        ForEach-Object { $_.TargetObjectIds } | Select-Object -Unique).Count
    $affectedAssignments = @($approvedActions |
        Where-Object { $_.ActionType -in 'RevokeAppRoleAssignment','RemoveDirectoryRoleAssignment' } |
        ForEach-Object { $_.TargetObjectIds } | Select-Object -Unique).Count

    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor Yellow
    Write-Host '  EXECUTION PREFLIGHT SUMMARY' -ForegroundColor Yellow
    Write-Host ('=' * 64) -ForegroundColor Yellow
    Write-Host ''
    Write-Host "  Engagement ID   : $EngagementId"                                   -ForegroundColor Gray
    Write-Host "  Client          : $ClientName"                                      -ForegroundColor Gray
    Write-Host "  WhatIf Run ID   : $($gateAResult.Manifest.RunId)"                  -ForegroundColor Gray
    Write-Host "  Approved By     : $($gateBResult.Manifest.ApprovedBy)"             -ForegroundColor Gray
    Write-Host "  Approval Expires: $($gateBResult.Manifest.ExpiresUtc)"             -ForegroundColor Gray
    Write-Host "  NonInteractive  : $($NonInteractive.IsPresent)"                    -ForegroundColor Gray
    Write-Host ''
    Write-Host '  Approved Actions:' -ForegroundColor DarkCyan
    $groupCounts | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
    Write-Host ''
    Write-Host '  Affected Objects:' -ForegroundColor DarkCyan
    Write-Host "    Users             : $affectedUsers"       -ForegroundColor Gray
    Write-Host "    Groups            : $affectedGroups"      -ForegroundColor Gray
    Write-Host "    Assignments       : $affectedAssignments" -ForegroundColor Gray
    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor Yellow
    Write-Host ''

    if (-not $NonInteractive -and $RequirePreflightConfirm) {
        $confirm = Read-Host "  Type EXECUTE to proceed, or anything else to abort"
        if ($confirm -ne 'EXECUTE') {
            Write-Host "[ABORTED] Execution cancelled by operator." -ForegroundColor Yellow
            exit 0
        }
    } elseif (-not $NonInteractive) {
        $confirm = Read-Host "  Proceed with execution? [y/N]"
        if ($confirm -notmatch '^[yY]') {
            Write-Host "[ABORTED] Execution cancelled by operator." -ForegroundColor Yellow
            exit 0
        }
    }
    Write-Host ''
    # ================================================================
    # END PREFLIGHT REPORT
    # ================================================================

    # Connect to Graph with write scopes only after Gate A and Gate B pass
    Write-DecomInfo "Connecting to Microsoft Graph (write scopes)..."
    try {
        $writeScopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'AuditLog.Read.All',
            'RoleManagement.Read.Directory',
            'Policy.Read.All',
            'GroupMember.ReadWrite.All',
            'AppRoleAssignment.ReadWrite.All',
            'RoleManagement.ReadWrite.Directory',
            'EntitlementManagement.ReadWrite.All',
            'Application.ReadWrite.All'
        )
        Connect-MgGraph -Scopes $writeScopes -TenantId $TenantId -ErrorAction Stop | Out-Null
        Write-DecomOk "Graph connection established with write scopes"
    } catch {
        Write-DecomError "Graph connection failed: $_"
        exit 1
    }

    # Initialize execution log
    $runId = [guid]::NewGuid().ToString()
    $executionLog = New-DecomExecutionLog -RunFolder $RunFolder -EngagementId $EngagementId -RunId $runId

    # Execute approved actions only
    Write-DecomInfo "Executing approved actions..."
    Invoke-DecomRemediation -ApprovedActions $approvedActions -ExecutionLog $executionLog -AllowNonInteractive:$NonInteractive.IsPresent

    # Save execution log
    Write-DecomInfo "Saving execution log..."
    Save-DecomExecutionLog -ExecutionLog $executionLog
    Write-DecomOk "Execution log saved"

    # Export execution evidence CSV and JSON
    Write-DecomInfo "Exporting execution evidence..."
    $evidenceCsvPath  = Join-Path $RunFolder "execution-evidence-$Timestamp.csv"
    $evidenceJsonPath = Join-Path $RunFolder "execution-evidence-$Timestamp.json"
    Export-DecomExecutionEvidence `
        -ExecutionLog     $executionLog `
        -ApprovalManifest $gateBResult.Manifest `
        -CsvPath          $evidenceCsvPath `
        -JsonPath         $evidenceJsonPath
    Write-DecomOk "Execution evidence: $evidenceCsvPath"
    Write-DecomOk "Execution evidence: $evidenceJsonPath"

    # Set execution evidence path for traceability (ExecuteRemediation only)
    $execEvidencePath = $evidenceJsonPath

    # Generate post-remediation HTML report
    Write-DecomInfo "Generating post-remediation report..."
    $remediationReportPath = Join-Path $RunFolder "execution-report-$Timestamp.html"
    Export-DecomExecutionReport `
        -ExecutionLog     $executionLog `
        -ApprovalManifest $gateBResult.Manifest `
        -Path             $remediationReportPath `
        -EngagementId     $EngagementId `
        -ClientName       $ClientName `
        -Assessor         $Assessor `
        -TenantId         $TenantId `
        -ToolVersion      $script:ToolVersion
    Write-DecomOk "Post-remediation report: $remediationReportPath"

    # Write execution summary manifest
    Write-DecomInfo "Writing execution summary manifest..."
    $execSummaryPath = Join-Path $RunFolder "execution-manifest-$Timestamp.json"
    Write-DecomExecutionManifest `
        -ExecutionLog         $executionLog `
        -ApprovalManifest     $gateBResult.Manifest `
        -Path                 $execSummaryPath `
        -EngagementId         $EngagementId `
        -ClientName           $ClientName `
        -TenantId             $TenantId `
        -Assessor             $Assessor `
        -EvidenceCsvPath      $evidenceCsvPath `
        -EvidenceJsonPath     $evidenceJsonPath `
        -ReportPath           $remediationReportPath
    Write-DecomOk "Execution manifest: $execSummaryPath"

    $executedCount      = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'Executed' }).Count
    $failedCount        = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'Failed' }).Count
    $partialFailedCount = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'PartialFailed' }).Count
    $blockedCount       = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'Blocked' }).Count
    $declinedCount      = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'OperatorDeclined' }).Count
    $outOfScopeCount    = @($executionLog.Log.Actions | Where-Object { $_.Outcome -eq 'OutOfScope' }).Count

    Write-Host ''
    Write-Host ('=' * 64) -ForegroundColor DarkCyan
    Write-Host '  Remediation complete.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '  Results:' -ForegroundColor DarkCyan
    Write-Host "    Executed           : $executedCount"      -ForegroundColor Green
    Write-Host "    Partial Failed     : $partialFailedCount" -ForegroundColor Yellow
    Write-Host "    Failed             : $failedCount"        -ForegroundColor Red
    Write-Host "    Blocked (Protected): $blockedCount"       -ForegroundColor Red
    Write-Host "    Operator Declined  : $declinedCount"      -ForegroundColor Yellow
    Write-Host "    Out of Scope       : $outOfScopeCount"    -ForegroundColor Gray
    Write-Host ''
    Write-Host '  Evidence:' -ForegroundColor DarkCyan
    Write-Host "    [OK]  Execution Log      : $($executionLog.Path)"  -ForegroundColor Green
    Write-Host "    [OK]  Evidence CSV       : $evidenceCsvPath"        -ForegroundColor Green
    Write-Host "    [OK]  Evidence JSON      : $evidenceJsonPath"       -ForegroundColor Green
    Write-Host "    [OK]  Remediation Report : $remediationReportPath"  -ForegroundColor Green
    Write-Host "    [OK]  Exec Manifest      : $execSummaryPath"        -ForegroundColor Green
    Write-Host ''
    Write-Host "  Output folder : $RunFolder" -ForegroundColor Gray
    Write-Host ('=' * 64) -ForegroundColor DarkCyan
    Write-Host ''

    exit 0
}

# Normal modes: Assessment / WhatIfRemediation / ExportPlan
if (-not $DemoMode -and $Mode -in @('Assessment','WhatIfRemediation','ExportPlan')) {
    Write-DecomInfo "Connecting to Microsoft Graph (read-only scopes)..."
    try {
        $scopes = @(
            'User.Read.All',
            'Directory.Read.All',
            'Application.Read.All',
            'AuditLog.Read.All',
            'RoleManagement.Read.Directory',
            'EntitlementManagement.Read.All',
            'AccessReview.Read.All',
            'Policy.Read.All'
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

if ($GenerateNhiGovernancePack -or $DemoMode) {
    Write-DecomInfo "Generating NHI governance pack..."

    # Discover NHI inventory
    $nhiInventory = Invoke-DecomNhiDiscovery -Context $Context -DemoMode:$DemoMode

    # Analyze NHI objects
    $nhiAnalyzed = Invoke-DecomNhiAnalysis -NhiObjects $nhiInventory -Context $Context

    # Generate governance findings
    $nhiGovFindings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects $nhiAnalyzed -Context $Context
    $Findings       = @($Findings) + @($nhiGovFindings)
    $Summary  = Get-DecomFindingSummary -Findings $Findings
    Write-DecomOk "NHI findings merged — total findings now $($Summary.Total)"
}

# Baseline comparison if -BaselinePath provided
$BaselineComparison = $null
$BaselineSummary    = $null
$RiskMovement       = $null
$BaselineResult     = $null
$baselineJsonPath   = $null
$baselineCsvPath    = $null
if ($BaselinePath) {
    Write-DecomInfo "Loading baseline from '$BaselinePath'..."
    $BaselineResult = Import-DecomBaselineFindings -BaselinePath $BaselinePath
    if ($BaselineResult.BaselineAvailable) {
        Write-DecomOk "Baseline loaded: $($BaselineResult.Findings.Count) findings"
        Write-DecomInfo "Comparing against baseline..."
        $BaselineComparison = Compare-DecomFindingBaseline -CurrentFindings $Findings -BaselineFindings $BaselineResult.Findings
        $BaselineSummary    = @{
            New                   = ($BaselineComparison | Where-Object { $_.Status -eq 'New' }).Count
            Persisting            = ($BaselineComparison | Where-Object { $_.IsPersisting -eq $true }).Count
            Resolved              = ($BaselineComparison | Where-Object { $_.Status -eq 'Resolved' }).Count
            ChangedSeverity       = ($BaselineComparison | Where-Object { $_.Status -eq 'ChangedSeverity' }).Count
            ChangedRiskScore      = ($BaselineComparison | Where-Object { $_.Status -eq 'ChangedRiskScore' }).Count
            ChangedEvidence       = ($BaselineComparison | Where-Object { $_.Status -eq 'ChangedEvidence' }).Count
            Unchanged             = ($BaselineComparison | Where-Object { $_.Status -eq 'Unchanged' }).Count
            NetRiskDelta          = ($BaselineComparison | Measure-Object -Property DeltaRiskScore -Sum).Sum
        }
        $RiskMovement       = Get-DecomRiskMovementSummary -ComparisonResults $BaselineComparison
        Write-DecomOk "Baseline comparison complete"
    } else {
        Write-DecomWarn "Baseline unavailable: $($BaselineResult.ErrorDetail)"
        Write-DecomWarn "Continuing without baseline comparison."
    }
} else {
    Write-DecomInfo "No baseline path provided - skipping baseline comparison."
}

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

# Baseline comparison exports
if ($BaselineComparison) {
    Write-DecomInfo "Exporting baseline comparison..."
    $baselineJsonPath = Join-Path $RunFolder "$fileBase-baseline-comparison-$Timestamp.json"
    $baselineCsvPath  = Join-Path $RunFolder "$fileBase-baseline-comparison-$Timestamp.csv"
    Export-DecomBaselineComparisonJson -ComparisonResults $BaselineComparison -Context $Context -BaselineResult $BaselineResult -Path $baselineJsonPath
    Export-DecomBaselineComparisonCsv  -ComparisonResults $BaselineComparison -Path $baselineCsvPath
    Write-DecomOk "Baseline comparison JSON: $baselineJsonPath"
    Write-DecomOk "Baseline comparison CSV: $baselineCsvPath"
    $exportPaths.BaselineComparisonJson = $baselineJsonPath
    $exportPaths.BaselineComparisonCsv  = $baselineCsvPath
    Write-DecomRunManifest -Path $ManifestPath -Context $Context -Summary $summaryHt -ExportPaths $exportPaths
    Write-DecomOk "Run manifest updated with baseline comparison paths"
}

# Executive pack generation if -GenerateExecutivePack specified
if ($GenerateExecutivePack) {
    Write-DecomInfo "Generating executive evidence pack..."

    # Prepare executive pack context
    $execContext = [pscustomobject]@{
        SchemaVersion = '3.6'
        ToolVersion   = $Context.ToolVersion
        ClientName    = $Context.ClientName
        EngagementId  = $Context.EngagementId
        Assessor      = $Context.Assessor
        TenantId      = $Context.TenantId
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Coverage      = $Context.Coverage
        Findings      = $Findings
        Summary       = $Summary
        BaselineComparison = $BaselineComparison
        BaselineSummary    = $BaselineSummary
        RiskMovement       = $RiskMovement
        ExportPaths        = @{
            Csv                   = $CsvPath
            Json                  = $JsonPath
            Html                  = $HtmlPath
            RemediationPlan       = $PlanPath
            Manifest              = $ManifestPath
            BaselineComparisonJson = $baselineJsonPath
            BaselineComparisonCsv  = $baselineCsvPath
        }
    }

    # Generate executive summary model
    $execModel = New-DecomExecutiveSummaryModel -Context $execContext

    # Generate exports
    $execTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $baseName      = "entra-decommissioning-control-plane"

    # Executive summary markdown
    $execMdPath = Join-Path $RunFolder "$baseName-executive-summary-$execTimestamp.md"
    Export-DecomExecutiveSummaryMarkdown -Model $execModel -Path $execMdPath
    Write-DecomOk "Executive summary markdown: $execMdPath"

    # Executive summary HTML
    $execHtmlPath = Join-Path $RunFolder "$baseName-executive-summary-$execTimestamp.html"
    Export-DecomExecutiveSummaryHtml -Model $execModel -Path $execHtmlPath
    Write-DecomOk "Executive summary HTML: $execHtmlPath"

    # Governance KPI dashboard
    $kpiDashboardPath = Join-Path $RunFolder "$baseName-governance-kpi-dashboard-$execTimestamp.html"
    Export-DecomGovernanceKpiDashboardHtml -Model $execModel -Path $kpiDashboardPath
    Write-DecomOk "Governance KPI dashboard: $kpiDashboardPath"

    # Consultant evidence appendix
    $appendixPath = Join-Path $RunFolder "$baseName-consultant-evidence-appendix-$execTimestamp.md"
    Export-DecomConsultantEvidenceAppendixMarkdown -Model $execModel -Path $appendixPath
    Write-DecomOk "Consultant evidence appendix: $appendixPath"

    # Client readout pack manifest
    $clientReadoutPath = Join-Path $RunFolder "$baseName-client-readout-pack-manifest-$execTimestamp.json"
    Write-DecomClientReadoutPackManifest -Model $execModel -Path $clientReadoutPath
    Write-DecomOk "Client readout pack manifest: $clientReadoutPath"

    # Optional: Residual risk register
    try {
        $riskRegisterPath = Join-Path $RunFolder "$baseName-residual-risk-register-$execTimestamp.csv"
        Export-DecomResidualRiskRegisterCsv -Findings $Findings -Path $riskRegisterPath
        Write-DecomOk "Residual risk register: $riskRegisterPath"
    } catch {
        Write-DecomWarn "Residual risk register skipped: $_"
    }

    # Add executive pack exports to final export paths for manifest update
    $exportPaths.ExecutiveSummaryMarkdown = $execMdPath
    $exportPaths.ExecutiveSummaryHtml     = $execHtmlPath
    $exportPaths.GovernanceDashboardHtml  = $kpiDashboardPath
    $exportPaths.ConsultantEvidenceAppendix = $appendixPath
    $exportPaths.ClientReadoutPackManifest  = $clientReadoutPath
    if (Test-Path $riskRegisterPath) {
        $exportPaths.ResidualRiskRegister = $riskRegisterPath
    }

    # Update run manifest with new export paths
    Write-DecomRunManifest -Path $ManifestPath -Context $Context -Summary $summaryHt -ExportPaths $exportPaths
    Write-DecomOk "Run manifest updated with executive pack exports"
}

# Handle GenerateApprovalTemplate flag for WhatIfRemediation mode
if ($Mode -eq 'WhatIfRemediation' -and $GenerateApprovalTemplate) {
    Write-DecomInfo "Generating WhatIf action plan for client approval..."

    $runManifestContent = Get-Content $ManifestPath -Raw | ConvertFrom-Json

    $actionPlanPath = New-DecomWhatIfActionPlan `
        -Findings $Findings `
        -EngagementId $EngagementId `
        -ClientName $ClientName `
        -Assessor $Assessor `
        -WhatIfRunId $runManifestContent.RunId `
        -OutputPath $RunFolder

    Write-DecomOk "WhatIf action plan: $actionPlanPath"
    Write-DecomInfo "Next: review with client, sign, then run Update-DecomApprovalManifestHash."
}

# In DemoMode, auto-enable all Rev3.4 hardening sample outputs
if ($DemoMode) {
    $GenerateRev35Readiness     = $true
    $GenerateClientHandoff      = $true
    $GenerateTraceabilityReport = $true
    $GenerateReplayValidation   = $true
    $GenerateApprovalDiff       = $true
    $GenerateRedactedPackage    = $true
    $GenerateEvidenceBundle     = $true
    $GenerateNhiGovernancePack  = $true
}

# ── Rev3.4 Hardening Outputs ──────────────────────────────────────────────────

$hardeningTimestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runManifestForHardening = if (Test-Path $ManifestPath) { Get-Content $ManifestPath -Raw | ConvertFrom-Json } else { $null }
$hardeningRunId = if ($runManifestForHardening -and $runManifestForHardening.RunId) { $runManifestForHardening.RunId } else { [guid]::NewGuid().ToString() }

if ($GenerateRev35Readiness) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Rev35Readiness.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $rr = New-DecomRev35ReadinessReport
        $rrPath = Join-Path $RunFolder "rev35-readiness-report-$hardeningTimestamp.json"
        Export-DecomRev35ReadinessJson -Report $rr -Path $rrPath
        Write-DecomOk "Rev3.5 readiness report: $rrPath"
    } catch { Write-DecomWarn "Rev3.5 readiness report skipped: $_" }
}

if ($GenerateClientHandoff) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ClientHandoff.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $chPkg = New-DecomClientHandoffPackage -Context $Context -RunId $hardeningRunId -PackagePath $RunFolder
        $chManifestPath = Join-Path $RunFolder "client-handoff-manifest-$hardeningTimestamp.json"
        Export-DecomClientHandoffManifestJson -Package $chPkg -Path $chManifestPath
        $chIndexPath = Join-Path $RunFolder "client-handoff-index-$hardeningTimestamp.md"
        Export-DecomClientHandoffIndexMarkdown -Package $chPkg -Path $chIndexPath
        Write-DecomOk "Client handoff manifest: $chManifestPath"
        Write-DecomOk "Client handoff index: $chIndexPath"
    } catch { Write-DecomWarn "Client handoff skipped: $_" }
}

if ($GenerateTraceabilityReport) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Traceability.psm1') -Force -DisableNameChecking -ErrorAction Stop
        # Initialize variables for traceability inputs
        $traceWhatIf = @()
        $traceApproval = @()
        $traceExecution = @()

        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $wf = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
            if ($wf.ApprovedActions) {
                $traceWhatIf = @($wf.ApprovedActions)
            }
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $ap = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
            if ($ap.ApprovedActions) {
                $traceApproval = @($ap.ApprovedActions)
            }
        }
        if ($execEvidencePath) {
            $ev = Get-Content $execEvidencePath -Raw | ConvertFrom-Json
            if ($ev.Actions) {
                $traceExecution = @($ev.Actions)
            }
        }

        $trModel = New-DecomTraceabilityModel `
            -Findings $Findings `
            -WhatIfActions $traceWhatIf `
            -ApprovalActions $traceApproval `
            -ExecutionResults $traceExecution `
            -RunId $hardeningRunId
        $trJsonPath = Join-Path $RunFolder "traceability-report-$hardeningTimestamp.json"
        $trCsvPath  = Join-Path $RunFolder "traceability-report-$hardeningTimestamp.csv"
        Export-DecomTraceabilityReportJson     -Model $trModel -Path $trJsonPath
        Export-DecomTraceabilityReportCsv      -Model $trModel -Path $trCsvPath
        Write-DecomOk "Traceability report: $trJsonPath"
    } catch { Write-DecomWarn "Traceability report skipped: $_" }
}

if ($GenerateReplayValidation -and $runManifestForHardening) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ReplayValidation.psm1') -Force -DisableNameChecking -ErrorAction Stop

        # Load actual artifacts before calling Invoke-DecomReplayValidation
        $rvWhatIf = $null
        $rvApproval = $null
        $rvExecution = $null

        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $rvWhatIf = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $rvApproval = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
        }
        $execEvidencePath = Get-ChildItem -Path $RunFolder -Filter 'execution-evidence-*.json' -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
        if ($execEvidencePath) {
            $rvExecution = Get-Content $execEvidencePath -Raw | ConvertFrom-Json
        }

        $rvResult = Invoke-DecomReplayValidation `
            -RunId $hardeningRunId `
            -WhatIfReport $rvWhatIf `
            -ApprovalManifest $rvApproval `
            -ExecutionEvidence $rvExecution
        $rvPath = Export-DecomReplayValidationReportJson -ValidationResult $rvResult -OutputPath $RunFolder
        Write-DecomOk "Replay validation report: $rvPath"
    } catch { Write-DecomWarn "Replay validation skipped: $_" }
}

if ($GenerateApprovalDiff -and $runManifestForHardening) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'ApprovalDiff.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $adWhatIf   = @()
        $adApproval = @()
        if ($WhatIfManifestPath -and (Test-Path $WhatIfManifestPath)) {
            $wfDoc = Get-Content $WhatIfManifestPath -Raw | ConvertFrom-Json
            if ($wfDoc.ApprovedActions) { $adWhatIf = @($wfDoc.ApprovedActions) }
        }
        if ($ApprovalManifestPath -and (Test-Path $ApprovalManifestPath)) {
            $apDoc = Get-Content $ApprovalManifestPath -Raw | ConvertFrom-Json
            if ($apDoc.ApprovedActions) { $adApproval = @($apDoc.ApprovedActions) }
        }
        $adDiff = Compare-DecomWhatIfToApproval -WhatIfActions $adWhatIf -ApprovalActions $adApproval -RunId $hardeningRunId
        $adPath = Join-Path $RunFolder "approval-diff-report-$hardeningTimestamp.json"
        Export-DecomApprovalDiffJson -Diff $adDiff -Path $adPath
        Write-DecomOk "Approval diff: $adPath"
    } catch { Write-DecomWarn "Approval diff skipped: $_" }
}

if ($GenerateRedactedPackage) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'Redaction.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $redactionProfileObj = New-DecomRedactionProfile -ProfileName $RedactionProfile

        # Create redacted subdirectory and apply redaction to output files
        $redactedDir = Join-Path $RunFolder 'redacted'
        New-Item -ItemType Directory -Path $redactedDir -Force | Out-Null
        $redactedCount = 0

        Get-ChildItem -Path $RunFolder -File | Where-Object { $_.Extension -in @('.json','.csv','.md','.html') } |
            ForEach-Object {
                try {
                    $raw = Get-Content $_.FullName -Raw -ErrorAction Stop
                    $redacted = Invoke-DecomRedaction -InputString $raw -Profile $redactionProfileObj
                    $target = Join-Path $redactedDir $_.Name
                    Set-Content -Path $target -Value $redacted -Encoding UTF8
                    $redactedCount++
                } catch { }
            }

        $rdPath = Join-Path $RunFolder "redaction-report-$hardeningTimestamp.json"
        Export-DecomRedactionReportJson -Profile $redactionProfileObj -Path $rdPath -RunId $hardeningRunId -ToolVersion $script:ToolVersion -RedactedFileCount $redactedCount
        Write-DecomOk "Redaction report: $rdPath"
        Write-DecomOk "$redactedCount file(s) redacted to $redactedDir"
    } catch { Write-DecomWarn "Redaction report skipped: $_" }
}

if ($GenerateEvidenceBundle) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'EvidenceBundle.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $eb = New-DecomEvidenceBundle -Context $Context -RunId $hardeningRunId -BundleId ([guid]::NewGuid().ToString()) -SourceOutputPath $RunFolder -BundleOutputPath (Join-Path $RunFolder 'evidence-bundle')
        New-Item -ItemType Directory -Path $eb.BundleOutputPath -Force | Out-Null
        Get-ChildItem -Path $RunFolder -File -Recurse | Where-Object { $_.FullName -notmatch '\\temp\\' } | ForEach-Object {
            $eb = Add-DecomEvidenceBundleFile -Bundle $eb -FilePath $_.FullName -Category 'Assessment'
        }
        $ebManifestPath = Join-Path $eb.BundleOutputPath "evidence-bundle-manifest-$hardeningTimestamp.json"
        Export-DecomEvidenceBundleManifestJson -Bundle $eb -Path $ebManifestPath
        $hashJsonPath = Join-Path $eb.BundleOutputPath "evidence-hashes-$hardeningTimestamp.json"
        $hashCsvPath  = Join-Path $eb.BundleOutputPath "evidence-hashes-$hardeningTimestamp.csv"
        Export-DecomEvidenceHashManifest -Bundle $eb -JsonPath $hashJsonPath -CsvPath $hashCsvPath
        Write-DecomOk "Evidence bundle: $ebManifestPath"
    } catch { Write-DecomWarn "Evidence bundle skipped: $_" }
}

if ($GenerateEvidenceBundle -or $GenerateRedactedPackage -or $GenerateTraceabilityReport -or $GenerateClientHandoff -or $GenerateRev35Readiness) {
    try {
        Import-Module (Join-Path $script:ModulesPath 'OutputManifest.psm1') -Force -DisableNameChecking -ErrorAction Stop
        $om = New-DecomOutputManifest -Context $Context -RunId $hardeningRunId -OutputRoot $RunFolder
        Get-ChildItem -Path $RunFolder -File -Recurse | Where-Object { $_.FullName -notmatch '\\temp\\' -and $_.Extension -in @('.json','.csv','.html','.md') } | ForEach-Object {
            $sensitivity = if ($_.Name -match 'redact') { 'ClientSafe' } else { 'Confidential' }
            $category = switch -Regex ($_.Name) {
                'readiness'    { 'Rev35Readiness';    break }
                'handoff'      { 'ClientHandoff';     break }
                'traceability' { 'Report';            break }
                'evidence'     { 'ExecutionEvidence'; break }
                'manifest'     { 'Report';            break }
                default        { 'Assessment' }
            }
            $om = Add-DecomOutputManifestItem -Manifest $om -FilePath $_.FullName -Category $category -Sensitivity $sensitivity
        }
        $omPath = Join-Path $RunFolder "output-manifest-$hardeningTimestamp.json"
        Export-DecomOutputManifestJson -Manifest $om -Path $omPath
        Write-DecomOk "Output manifest: $omPath"
    } catch { Write-DecomWarn "Output manifest skipped: $_" }
}

# ── Rev3.5 NHI Governance Pack ────────────────────────────────────────────────

if ($GenerateNhiGovernancePack) {
    try {
        Write-DecomInfo "Generating NHI governance pack..."

        # Discover NHI inventory
        $nhiInventory = Invoke-DecomNhiDiscovery -Context $Context

        # Analyze NHI objects
        $nhiAnalyzed = Invoke-DecomNhiAnalysis -NhiObjects $nhiInventory -Context $Context

        # Generate governance findings
        $nhiGovernanceFindings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects $nhiAnalyzed -Context $Context

        # Generate NHI reporting outputs (writes nhi-* files to $Context.OutputPath = $RunFolder)
        Invoke-DecomNhiReporting -NhiInventory $nhiAnalyzed -NhiGovernanceFindings $nhiGovernanceFindings -Context $Context

        Write-DecomOk "NHI governance pack generation complete"

        # Register NHI outputs in OutputManifest and EvidenceBundle
        $nhiOutputFiles = Get-ChildItem -Path $RunFolder -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'nhi-*' -or $_.Name -like '*-nhi-*' }

        if ($nhiOutputFiles.Count -gt 0) {
            try {
                Import-Module (Join-Path $script:ModulesPath 'OutputManifest.psm1') -Force -DisableNameChecking -ErrorAction Stop
                $nhiOm = New-DecomOutputManifest -Context $Context -RunId $hardeningRunId -OutputRoot $RunFolder
                foreach ($f in $nhiOutputFiles) {
                    $nhiOm = Add-DecomOutputManifestItem -Manifest $nhiOm `
                        -FilePath $f.FullName -Category 'Assessment' -Sensitivity 'Confidential'
                }
                $nhiOmPath = Join-Path $RunFolder "nhi-output-manifest-$hardeningTimestamp.json"
                Export-DecomOutputManifestJson -Manifest $nhiOm -Path $nhiOmPath
                Write-DecomOk "NHI output manifest: $nhiOmPath"
            } catch { Write-DecomWarn "NHI output manifest skipped: $_" }

            try {
                Import-Module (Join-Path $script:ModulesPath 'EvidenceBundle.psm1') -Force -DisableNameChecking -ErrorAction Stop
                $nhiEb = New-DecomEvidenceBundle -Context $Context -RunId $hardeningRunId `
                    -BundleId ([guid]::NewGuid().ToString()) `
                    -SourceOutputPath $RunFolder `
                    -BundleOutputPath (Join-Path $RunFolder 'nhi-evidence-bundle')
                New-Item -ItemType Directory -Path $nhiEb.BundleOutputPath -Force | Out-Null
                foreach ($f in $nhiOutputFiles) {
                    $nhiEb = Add-DecomEvidenceBundleFile -Bundle $nhiEb `
                        -FilePath $f.FullName -Category 'NHI'
                }
                $nhiEbManifestPath = Join-Path $nhiEb.BundleOutputPath "nhi-evidence-bundle-manifest-$hardeningTimestamp.json"
                Export-DecomEvidenceBundleManifestJson -Bundle $nhiEb -Path $nhiEbManifestPath
                Write-DecomOk "NHI evidence bundle: $nhiEbManifestPath"
            } catch { Write-DecomWarn "NHI evidence bundle skipped: $_" }
        }
    } catch { Write-DecomWarn "NHI governance pack skipped: $_" }
}

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
