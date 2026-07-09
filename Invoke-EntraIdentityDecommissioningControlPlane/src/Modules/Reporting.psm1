#Requires -Version 5.1
# Dot-source template helpers
. "$PSScriptRoot\Reporting.Templates.ps1" -ErrorAction Stop

function Export-DecomAssessmentCsv {
    param([object[]]$Findings, [string]$Path)
    if (-not $Findings -or $Findings.Count -eq 0) {
        'FindingId,Category,Severity,RiskScore,Confidence,ObjectType,DisplayName,Evidence,RecommendedAction,RemediationMode' |
            Set-Content -Path $Path -Encoding UTF8
        return
    }
    $Findings | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

function Export-DecomAssessmentJson {
    param([object[]]$Findings, [string]$Path, [pscustomobject]$Context)
    $payload = [ordered]@{
        SchemaVersion = '3.6'
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Tenant        = $Context.TenantId
        Mode          = $Context.Mode
        Coverage      = $Context.Coverage
        FindingCount  = ($Findings | Measure-Object).Count
        Findings      = $Findings
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
}

function Write-DecomRunManifest {
    param([string]$Path, [pscustomobject]$Context, [hashtable]$Summary, [hashtable]$ExportPaths)
    $manifest = [ordered]@{
        SchemaVersion  = '2.4'
        RunId          = [guid]::NewGuid().Guid
        GeneratedUtc   = (Get-Date).ToUniversalTime().ToString('o')
        TenantId       = $Context.TenantId
        Mode           = $Context.Mode
        DemoMode       = $Context.DemoMode
        EngagementId   = $Context.EngagementId
        ClientName     = $Context.ClientName
        Assessor       = $Context.Assessor
        Coverage       = if ($null -ne $Context.Coverage) { $Context.Coverage } else { $null }
        FindingSummary = $Summary
        Exports        = $ExportPaths
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding UTF8
}

function Export-DecomAssessmentHtml {
    param([object[]]$Findings, [string]$Path, [pscustomobject]$Context, [hashtable]$Summary)

    $tenantDisplay   = if ($Context.DemoMode) { 'DEMO - contoso.onmicrosoft.com' } else { $Context.TenantId }
    $clientDisplay   = if ($Context.ClientName) { $Context.ClientName } else { '-' }
    $engagementId    = if ($Context.EngagementId) { $Context.EngagementId } else { '-' }
    $assessorDisplay = if ($Context.Assessor) { $Context.Assessor } else { '-' }
    $runDate         = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
    $modeDisplay     = $Context.Mode
    $critHighCount   = $Summary.Critical + $Summary.High
    $totalCount      = $Summary.Total

    $coverageMode = 'Full'
    if ($Context.Coverage) {
        $coverageValues = $Context.Coverage.Values | Where-Object { $_ -eq $false }
        if ($coverageValues.Count -gt 0) { $coverageMode = 'Partial' }
    }

    $protectedCount = ($Findings | Where-Object { $_.ProtectedObject -eq $true }).Count
    $userCount      = ($Findings | Where-Object { $_.ObjectType -eq 'User' } | Select-Object -ExpandProperty ObjectId -Unique).Count

    $demoWatermark = ''
    if ($Context.DemoMode) {
$demoWatermark = @'
<div style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%) rotate(-35deg);font-size:100px;font-weight:900;color:rgba(198,167,94,0.06);pointer-events:none;z-index:9999;white-space:nowrap;letter-spacing:12px;font-family:sans-serif;">DEMO DATA</div>
'@
    }

    $safetyBanner = ''
    if ($Context.Mode -in 'Assessment','WhatIfRemediation','ExportPlan') {
        $modeSafetyHtml = [System.Web.HttpUtility]::HtmlEncode($Context.Mode)
$safetyBanner = @"
<div style="background:rgba(34,197,94,0.1);border:1px solid rgba(34,197,94,0.4);border-radius:10px;padding:14px 18px;color:#22c55e;font-weight:600;margin-bottom:24px;">
  &#10003; $modeSafetyHtml mode - no tenant objects were modified during this run.
</div>
"@
    }

    $findingRowsHtml = [System.Text.StringBuilder]::new()
    foreach ($f in $Findings) {
        $severityColor = switch ($f.Severity) {
            'Critical'      { 'color:var(--red);font-weight:700' }
            'High'          { 'color:var(--orange);font-weight:700' }
            'Medium'        { 'color:var(--cyan);font-weight:700' }
            'Low'           { 'color:var(--green);font-weight:700' }
            'Informational' { 'color:var(--muted)' }
            default         { 'color:var(--muted)' }
        }
        $evidenceEsc    = [System.Web.HttpUtility]::HtmlEncode($f.Evidence)
        $actionEsc      = [System.Web.HttpUtility]::HtmlEncode($f.RecommendedAction)
        $displayEsc     = [System.Web.HttpUtility]::HtmlEncode($f.DisplayName)
        $categoryEsc    = [System.Web.HttpUtility]::HtmlEncode($f.Category)
        $severityEsc    = [System.Web.HttpUtility]::HtmlEncode($f.Severity)
        $remModeEsc     = [System.Web.HttpUtility]::HtmlEncode($f.RemediationMode)
        $confEsc        = [System.Web.HttpUtility]::HtmlEncode($f.Confidence)
        $findingIdEsc   = [System.Web.HttpUtility]::HtmlEncode($f.FindingId)
        $objectTypeEsc  = [System.Web.HttpUtility]::HtmlEncode($f.ObjectType)
$rowHtml = @"
<tr data-severity="$severityEsc" data-category="$categoryEsc">
  <td style="font-family:monospace;font-size:12px;">$findingIdEsc</td>
  <td style="$severityColor">$severityEsc</td>
  <td>$categoryEsc</td>
  <td>$severityEsc</td>
  <td>$([Math]::Round($f.RiskScore))</td>
  <td>$confEsc</td>
  <td>$objectTypeEsc</td>
  <td>$displayEsc</td>
  <td style="max-width:280px;">$evidenceEsc</td>
  <td style="max-width:200px;">$actionEsc</td>
  <td>$remModeEsc</td>
</tr>
"@
        $null = $findingRowsHtml.Append($rowHtml)
    }

$metaGridHtml = @"
<div class="meta-item"><div class="label">Tenant</div><div class="value">$( [System.Web.HttpUtility]::HtmlEncode($tenantDisplay) )</div></div>
<div class="meta-item"><div class="label">Client</div><div class="value">$( [System.Web.HttpUtility]::HtmlEncode($clientDisplay) )</div></div>
<div class="meta-item"><div class="label">Engagement ID</div><div class="value">$( [System.Web.HttpUtility]::HtmlEncode($engagementId) )</div></div>
<div class="meta-item"><div class="label">Assessor</div><div class="value">$( [System.Web.HttpUtility]::HtmlEncode($assessorDisplay) )</div></div>
<div class="meta-item"><div class="label">Run Date</div><div class="value">$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') UTC</div></div>
<div class="meta-item"><div class="label">Mode</div><div class="value">$modeDisplay</div></div>
<div class="meta-item"><div class="label">Coverage</div><div class="value">$( [System.Web.HttpUtility]::HtmlEncode($coverageMode) )</div></div>
<div class="meta-item"><div class="label">Assessment ID</div><div class="value" style="font-size:11px;font-family:monospace;">$( [guid]::NewGuid().Guid )</div></div>
"@

    $countEsc = [System.Web.HttpUtility]::HtmlEncode("Total findings: $totalCount | Critical/High: $critHighCount | Protected objects: $protectedCount | Users assessed: $userCount")
$execSummaryHtml = @"
<div class="exec-summary-badge">$countEsc</div>
"@

$metaItemTpl = '<div class="meta-item"><div class="label">__LBL__</div><div class="value" style="__STY__">__CNT__</div></div>'
    $kpiItems = @(
        [ordered]@{ Label='Critical';      Count=$Summary.Critical;      Style='color:var(--red);font-weight:700;font-size:24px;'    },
        [ordered]@{ Label='High';           Count=$Summary.High;          Style='color:var(--orange);font-weight:700;font-size:24px;' },
        [ordered]@{ Label='Medium';         Count=$Summary.Medium;         Style='color:var(--cyan);font-weight:700;font-size:24px;'  },
        [ordered]@{ Label='Low';            Count=$Summary.Low;           Style='color:var(--green);font-weight:700;font-size:24px;' },
        [ordered]@{ Label='Informational'; Count=$Summary.Informational; Style='color:var(--muted);font-weight:700;font-size:24px;' },
        [ordered]@{ Label='Total';          Count=$totalCount;           Style='font-weight:700;font-size:24px;'                     }
    )
    $kpiGridHtml = ($kpiItems | ForEach-Object {
        $metaItemTpl -replace '__LBL__', $_.Label -replace '__CNT__', $_.Count -replace '__STY__', $_.Style
    }) -join ''

$scorecardSections = @()
    foreach ($entry in $Summary.Keys) {
        $lblEsc = [System.Web.HttpUtility]::HtmlEncode($entry)
        $valEsc = [System.Web.HttpUtility]::HtmlEncode([string]$Summary[$entry])
$scorecardSections += "<div class=""meta-item""><div class=""label"">$lblEsc</div><div class=""value"">$valEsc</div></div>"
    }
    $scorecardHtml = $scorecardSections -join ''

$coverageRowsList = @()
    if ($Context.Coverage) {
        foreach ($k in $Context.Coverage.Keys) {
            $kEsc = [System.Web.HttpUtility]::HtmlEncode($k)
            $statusColor = if ($Context.Coverage[$k]) { '#22c55e' } else { '#f59e0b' }
            $statusText  = if ($Context.Coverage[$k]) { 'Covered' } else { 'Not Covered' }
$coverageRowsList += "<tr><td>$kEsc</td><td style=""color:$statusColor;font-weight:600;"">$statusText</td></tr>"
        }
    }
    $coverageRowsHtml = $coverageRowsList -join ''

    $sevOrder = 'Critical','High','Medium','Low','Informational'
    $roadmapOrdered = $Findings | Where-Object { $_.RemediationMode -ne 'InformationOnly' } |
        Sort-Object { $sevOrder.IndexOf($_.Severity) } | Select-Object -First 20
$roadmapListItems = @()
    foreach ($item in $roadmapOrdered) {
        $iidEsc  = [System.Web.HttpUtility]::HtmlEncode($item.FindingId)
        $catEsc  = [System.Web.HttpUtility]::HtmlEncode($item.Category)
        $descEsc = [System.Web.HttpUtility]::HtmlEncode($item.Evidence)
        $sevColor = switch ($item.Severity) {
            'Critical' { 'var(--red)' }
            'High'    { 'var(--orange)' }
            'Medium'  { 'var(--cyan)' }
            default   { 'var(--muted)' }
        }
        $sevEscI = [System.Web.HttpUtility]::HtmlEncode($item.Severity)
$roadmapListItems += "<li style=""border-left:3px solid $sevColor;padding:8px 14px;margin-bottom:8px;background:rgba(255,255,255,0.03);border-radius:0 6px 6px 0;"">
<span style=""font-family:monospace;font-weight:700;margin-right:8px;"">$iidEsc</span>
<span style=""color:$sevColor;font-weight:600;margin-right:8px;"">$sevEscI</span>
<span style=""color:var(--muted);"">$catEsc</span>
<div style=""margin-top:4px;font-size:12px;color:var(--text);"">$descEsc</div>
</li>"
    }
    $roadmapHtml = if ($roadmapListItems.Count -gt 0) {
        '<ol class="roadmap-list">' + ($roadmapListItems -join '') + '</ol>'
    } else {
        '<p style="color:var(--muted);">No remediation-required findings.</p>'
    }

    $modeSafetyText = switch ($Context.Mode) {
        'Assessment'        { 'All findings were identified in read-only Assessment mode - no tenant objects were modified during this run.' }
        'WhatIfRemediation' { 'Findings were evaluated in WhatIfRemediation mode - no tenant objects were modified during this run.' }
        'ExportPlan'        { 'A remediation plan was exported - no tenant objects were modified during this run.' }
        default             { 'Review execution logs and approval manifest for this run.' }
    }
    $modeSafetyTextEsc = [System.Web.HttpUtility]::HtmlEncode($modeSafetyText)
$limitationsHtml = @"
<div style="padding:12px 18px;background:rgba(245,158,11,0.08);border:1px solid rgba(245,158,11,0.25);border-radius:8px;color:var(--text);font-size:13px;line-height:1.7;">
<p style="margin:0 0 8px;"><strong>Findings reflect a point-in-time snapshot.</strong> Entra ID data changes continuously - re-run the assessment periodically to maintain accuracy.</p>
<p style="margin:0 0 8px;"><strong>Coverage depends on available permissions.</strong> Ensure the account used for assessment holds all required Microsoft Graph permissions listed in the Required-Permissions.md documentation.</p>
<p style="margin:0;"><strong>Remediation actions require elevated permissions.</strong> Not all findings can be resolved without Directory.ReadWrite.All or equivalent privileges.</p>
</div>
<p style="color:var(--gold);font-size:12px;margin-top:12px;">$modeSafetyTextEsc</p>
"@

    # --- Template assembly ---
    $tmpl = Get-ReportingTemplateAssessmentDocument
    $head   = $tmpl['header']   -join ''
    $script = $tmpl['script']
    $css    = $tmpl['css']

    $html = $head
    $html = $html -replace '__META_GRID__',              $metaGridHtml
    $html = $html -replace '__TOOL_VERSION_ESC_HTML__',  [System.Web.HttpUtility]::HtmlEncode($Context.ToolVersion)
    $html = $html -replace '__RUNDATE_ESC_HTML__',       ((Get-Date -Format 'yyyy-MM-dd HH:mm:ss') + ' UTC')
    $html = $html -replace '__EXEC_SUMMARY__',           $execSummaryHtml
    $html = $html -replace '__KPI_GRID__',              $kpiGridHtml
    $html = $html -replace '__SCORECARD__',             $scorecardHtml
    $html = $html -replace '__LIMITATIONS__',            $limitationsHtml
    $html = $html -replace '__FINDING_ROWS__',           $findingRowsHtml.ToString()
    $html = $html -replace '__COVERAGE_ROWS__',          $coverageRowsHtml
    $html = $html -replace '__ROADMAP_HTML__',           $roadmapHtml
    $html = $html -replace '__ASSESSMENT_CSS__',         $css
    $html = $html -replace '__ASSESSMENT_SCRIPT__',       $script
    $html = $html + $demoWatermark + "</body></html>"

    [System.IO.File]::WriteAllText($Path, $html, (New-Object System.Text.UTF8Encoding $false))
}

function Export-DecomExecutionReport {
    param(
        [hashtable]$SessionScope,
        [pscustomobject]$Context,
        [string]$OutputDir
    )
    $runId   = [guid]::NewGuid().Guid
    $runDate = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

$actionRowsList = @()
    foreach ($action in $SessionScope.Values) {
        $typeEsc   = [System.Web.HttpUtility]::HtmlEncode($action.ActionType)
        $targetEsc = [System.Web.HttpUtility]::HtmlEncode($action.TargetObject)
        $scopeEsc  = [System.Web.HttpUtility]::HtmlEncode($action.WriteScope)
        $justEsc   = [System.Web.HttpUtility]::HtmlEncode($action.Justification)
        $riskEsc   = [System.Web.HttpUtility]::HtmlEncode($action.RiskLevel)
$actionRowsList += @"
<tr>
  <td style="font-family:monospace;font-size:12px;">$typeEsc</td>
  <td style="font-family:monospace;font-size:11px;">$targetEsc</td>
  <td>$scopeEsc</td>
  <td style="color:var(--orange);">$riskEsc</td>
  <td style="font-size:12px;">$justEsc</td>
</tr>
"@
    }
    $actionRowsHtml = $actionRowsList -join ''

    $versionEsc = [System.Web.HttpUtility]::HtmlEncode($Context.ToolVersion)
$execScorecardHtml = @"
<div class="meta-item"><div class="label">Run Date</div><div class="value">$runDate UTC</div></div>
<div class="meta-item"><div class="label">Tool Version</div><div class="value">$versionEsc</div></div>
<div class="meta-item"><div class="label">Total Actions</div><div class="value">$($SessionScope.Values.Count)</div></div>
"@

    $tmpl = Get-ReportingTemplateExecutionDocument
    $headHtml = $tmpl['head']   -join ''
    $css      = $tmpl['css']
    $bodyHtml = $tmpl['body']   -join ''

    $html = $headHtml -replace '__EXECUTION_CSS__', $css
    $html = $html -replace '__TOOL_VERSION_ESC_HTML__', [System.Web.HttpUtility]::HtmlEncode($Context.ToolVersion)
    $html = $html -replace '__RUNDATE_ESC_HTML__',   $runDate
    $html = $html -replace '__TENANT_ESC_HTML__',    [System.Web.HttpUtility]::HtmlEncode($Context.TenantId)
    $html = $html -replace '__CLIENT_ESC_HTML__',    [System.Web.HttpUtility]::HtmlEncode($Context.ClientName)
    $html = $html -replace '__ENGAGEMENT_ESC_HTML__', [System.Web.HttpUtility]::HtmlEncode($Context.EngagementId)
    $html = $html -replace '__ASSESSOR_ESC_HTML__',   [System.Web.HttpUtility]::HtmlEncode($Context.Assessor)
    $html = $html -replace '__APPROVED_BY_ESC_HTML__', [System.Web.HttpUtility]::HtmlEncode($Context.ApprovedBy)
    $html = $html -replace '__TICKET_ESC_HTML__',    [System.Web.HttpUtility]::HtmlEncode($Context.ApprovalTicket)
    $html = $html -replace '__RUN_ID_ESC_HTML__',     $runId
    $html = $html -replace '__EXEC_SCORECARD__',     $execScorecardHtml
    $html = $html -replace '__ACTION_ROWS__',         $actionRowsHtml
    $html = $html -replace '__EXECUTION_BODY__',     $bodyHtml

    [System.IO.File]::WriteAllText((Join-Path $OutputDir 'execution-report.html'), $html, (New-Object System.Text.UTF8Encoding $false))
}

Export-ModuleMember -Function Export-DecomAssessmentCsv,Export-DecomAssessmentJson,Write-DecomRunManifest,Export-DecomAssessmentHtml,Export-DecomExecutionReport
