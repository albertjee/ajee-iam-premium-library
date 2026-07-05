if ($GenerateNhiGovernancePack -or $DemoMode -or $IncludeAgentActivityAudit) {
    Write-DecomInfo "Generating NHI governance pack..."

    # Discover NHI inventory
    $NhiInventory = Invoke-DecomNhiDiscovery -Context $Context

    # Analyze NHI objects
    $NhiAnalyzed = Invoke-DecomNhiAnalysis -NhiObjects $NhiInventory -Context $Context

    # Generate governance findings
    $NhiGovernanceFindings = Invoke-DecomNhiGovernance -AnalyzedNhiObjects $NhiAnalyzed -Context $Context
    $Findings       = @($Findings) + @($NhiGovernanceFindings)
    $Summary  = Get-DecomFindingSummary -Findings $Findings
    $NhiPipelineRan = $true
    Write-DecomOk "NHI findings merged - total findings now $($Summary.Total)"

    # === Rev3.8 M24: NHI credential / permission / sign-in scans ===
    Write-DecomInfo "Running NHI credential, permission, and sign-in scans..."

    # Flatten raw SPs from NhiAnalyzed for scan functions (consistent with owner/agent/publisher scans)
    # Note: NhiInventory includes Microsoft Graph (sp-004) which is filtered out by NhiAnalysis; use NhiAnalyzed for SP list
    $nhiScanSpIds = @($NhiAnalyzed | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.MicrosoftPlatform -ne $true } | ForEach-Object { $_.ObjectId })
    $nhiCredentialSps = @($NhiInventory | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.MicrosoftPlatform -ne $true -and $_.ObjectId -in $nhiScanSpIds } | ForEach-Object { $_.RawServicePrincipal })
    $nhiPermissionAras = @($NhiInventory | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.MicrosoftPlatform -ne $true -and $_.ObjectId -in $nhiScanSpIds } | ForEach-Object { $_.RawAppRoleAssignments } | Where-Object { $_ })
    $nhiPermissionGrants = @($NhiInventory | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.MicrosoftPlatform -ne $true -and $_.ObjectId -in $nhiScanSpIds } | ForEach-Object { $_.RawOAuthGrants } | Where-Object { $_ })

    # NHI-CRED scan
    $nhiCredentialFindings = @()
    if ($nhiCredentialSps.Count -gt 0) {
        $nhiCredentialFindings = Invoke-NhiCredentialScan -ServicePrincipals $nhiCredentialSps -SignInByAppId @{} -SignInByServicePrincipalId @{}
        if ($nhiCredentialFindings) { $Findings += $nhiCredentialFindings }
    }

    # NHI-PERM scan
    $nhiPermissionFindings = @()
    if ($nhiCredentialSps.Count -gt 0 -and ($nhiPermissionAras.Count -gt 0 -or $nhiPermissionGrants.Count -gt 0)) {
        $nhiPermissionFindings = Invoke-NhiPermissionScan -ServicePrincipals $nhiCredentialSps -AppRoleAssignments $nhiPermissionAras -OAuthGrants $nhiPermissionGrants
        if ($nhiPermissionFindings) { $Findings += $nhiPermissionFindings }
    }

    # NHI-SIGNIN scan
    $nhiSignInFindings = @()
    if ($nhiCredentialSps.Count -gt 0) {
        $nhiSignInFindings = Invoke-NhiSignInScan -ServicePrincipals $nhiCredentialSps -SignInByAppId @{} -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
        if ($nhiSignInFindings) { $Findings += $nhiSignInFindings }
    }

    $credCount = if ($nhiCredentialFindings) { $nhiCredentialFindings.Count } else { 0 }
    $permCount = if ($nhiPermissionFindings) { $nhiPermissionFindings.Count } else { 0 }
    $signCount = if ($nhiSignInFindings) { $nhiSignInFindings.Count } else { 0 }
    $newNhiFindingCount = $credCount + $permCount + $signCount
    $Summary  = Get-DecomFindingSummary -Findings $Findings
    Write-DecomOk "NHI credential/permission/signIn scans complete - $newNhiFindingCount new findings added"

    # === Rev3.9 M29: NHI owner, publisher, and agent scans ===
    Write-DecomInfo "Running NHI owner, publisher, and agent scans..."

    # Flatten raw SPs from NhiInventory for scan functions
    $nhiScanSps = @($NhiInventory | Where-Object { $_.ObjectType -eq 'ServicePrincipal' -and $_.MicrosoftPlatform -ne $true } | ForEach-Object { $_.RawServicePrincipal })

    # Extract owner data for NhiOwner
    $ownersByObjectId = @{}
    $ownerLookupSucceeded = $true
    foreach ($nhiObj in $NhiInventory) {
        if ($nhiObj.ObjectType -eq 'ServicePrincipal' -and $nhiObj.MicrosoftPlatform -ne $true) {
            if ($nhiObj.RawOwners) {
                $ownersByObjectId[$nhiObj.ObjectId] = @($nhiObj.RawOwners)
            } else {
                $ownersByObjectId[$nhiObj.ObjectId] = @()
            }
            if ($nhiObj.RiskScoreMayBeUnderstated -eq $true) {
                $ownerLookupSucceeded = $false
            }
        }
    }

    # Extract app registration data for NhiPublisher
    $appRegistrationByAppId = @{}
    foreach ($nhiObj in $NhiInventory) {
        if ($nhiObj.ObjectType -eq 'Application' -and $nhiObj.RawApplication) {
            $appRegistrationByAppId[$nhiObj.AppId] = $nhiObj.RawApplication
        }
    }

    # Extract agent blueprint IDs for NhiAgent
    $agentBlueprintIdByObjectId = @{}
    foreach ($nhiObj in $NhiInventory) {
        if ($nhiObj.ObjectType -eq 'ServicePrincipal') {
            $blueprintId = $null
            if ($nhiObj.RawServicePrincipal.PSObject.Properties.Name -contains 'AgentIdentityBlueprintId') {
                $blueprintId = $nhiObj.RawServicePrincipal.AgentIdentityBlueprintId
            }
            if (-not $blueprintId -and $nhiObj.RawServicePrincipal.AdditionalProperties) {
                $blueprintId = $nhiObj.RawServicePrincipal.AdditionalProperties['agentIdentityBlueprintId']
            }
            if ($blueprintId) {
                $agentBlueprintIdByObjectId[$nhiObj.ObjectId] = $blueprintId
            }
        }
    }

    # TenantId for NhiPublisher
    $tenantIdForNhiPublisher = ''
    if ($Context -and $Context.TenantId) {
        $tenantIdForNhiPublisher = [string]$Context.TenantId
    }

    $nhiOwnerFindings = @()
    if ($nhiScanSps.Count -gt 0) {
        $nhiOwnerFindings = Invoke-NhiOwnerScan -ServicePrincipals $nhiScanSps -OwnersByObjectId $ownersByObjectId -OwnerLookupSucceeded $ownerLookupSucceeded
        if ($nhiOwnerFindings) { $Findings += $nhiOwnerFindings }
    }

    $nhiPublisherFindings = @()
    if ($nhiScanSps.Count -gt 0) {
        $nhiPublisherFindings = Invoke-NhiPublisherScan -ServicePrincipals $nhiScanSps -AppRegistrationByAppId $appRegistrationByAppId -TenantId $tenantIdForNhiPublisher
        if ($nhiPublisherFindings) { $Findings += $nhiPublisherFindings }
    }

    $nhiAgentFindings = @()
    if ($nhiScanSps.Count -gt 0) {
        $nhiAgentFindings = Invoke-NhiAgentScan -ServicePrincipals $nhiScanSps -AgentBlueprintIdByObjectId $agentBlueprintIdByObjectId
        if ($nhiAgentFindings) { $Findings += $nhiAgentFindings }
    }

    $ownCount = if ($nhiOwnerFindings) { $nhiOwnerFindings.Count } else { 0 }
    $pubCount = if ($nhiPublisherFindings) { $nhiPublisherFindings.Count } else { 0 }
    $agentCount = if ($nhiAgentFindings) { $nhiAgentFindings.Count } else { 0 }
    $newNhiFindingCount2 = $ownCount + $pubCount + $agentCount
    $Summary  = Get-DecomFindingSummary -Findings $Findings
    Write-DecomOk "NHI owner/publisher/agent scans complete - $newNhiFindingCount2 new findings added"

    # === Rev4.1 M7: Optional NHI activity audit ===
    if ($IncludeAgentActivityAudit) {
        Write-DecomInfo "Running optional NHI activity audit..."
        $actWindowStart = (Get-Date).AddDays(-30)
        $actWindowEnd   = Get-Date
        foreach ($nhiObject in $NhiAnalyzed) {
            if (-not $nhiObject.AgenticCandidate) { continue }
            $signInLogs    = Get-NhiAgentSignInLog -ObjectId $nhiObject.ObjectId -ObjectType $nhiObject.ObjectType -StartTime $actWindowStart -EndTime $actWindowEnd
            $directoryLogs = Get-NhiAgentDirectoryAuditLog -ObjectId $nhiObject.ObjectId -StartTime $actWindowStart -EndTime $actWindowEnd
            $actFindings    = Invoke-NhiActivityLogScan -NhiObject $nhiObject -SignInLogs $signInLogs -DirectoryLogs $directoryLogs
            $graphFindings  = Invoke-NhiGraphApiAuditScan -NhiObject $nhiObject -StartTime $actWindowStart -EndTime $actWindowEnd
            $complyFindings = Invoke-NhiComplianceAuditScan -NhiObject $nhiObject -StartTime $actWindowStart -EndTime $actWindowEnd
            $tokenFindings  = Invoke-NhiTokenForensicsScan -NhiObject $nhiObject -SignInLogs $signInLogs
            $caFindings     = Invoke-NhiConditionalAccessResponseScan -NhiObject $nhiObject -SignInLogs $signInLogs
            $Findings += $actFindings + $graphFindings + $complyFindings + $tokenFindings + $caFindings
        }
        $Summary = Get-DecomFindingSummary -Findings $Findings
        Write-DecomOk "NHI activity audit complete - total findings now $($Summary.Total)"
    }
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
