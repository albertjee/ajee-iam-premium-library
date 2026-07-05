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
        Write-DecomInfo "ActionId filter applied - $($approvedActions.Count) action(s) selected."
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

# Initialize NHI pipeline state caching (prevent duplicate execution)
$NhiInventory = @()
$NhiAnalyzed = @()
$NhiGovernanceFindings = @()
$NhiPipelineRan = $false

Write-DecomInfo "Starting discovery..."
$Findings = Invoke-DecomAssessmentDiscovery -Context $Context -DemoMode:$DemoMode
Write-DecomOk "Discovery complete - $($Findings.Count) raw finding(s)"

Write-DecomInfo "Running analysis..."
$Findings = Invoke-DecomAnalysis -Findings $Findings
$Summary  = Get-DecomFindingSummary -Findings $Findings
Write-DecomOk "Analysis complete"
