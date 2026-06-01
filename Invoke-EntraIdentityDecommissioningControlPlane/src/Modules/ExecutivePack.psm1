#Requires -Version 5.1

function New-DecomExecutiveSummaryModel {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    $findings         = if ($Context.Findings) { @($Context.Findings) } else { @() }
    $summary          = $Context.Summary
    $coverage         = $Context.Coverage
    $baselineSummary  = $Context.BaselineSummary
    $riskMovement     = $Context.RiskMovement

    # Severity counts
    $criticalCount = ($findings | Where-Object { $_.Severity -eq 'Critical' }).Count
    $highCount     = ($findings | Where-Object { $_.Severity -eq 'High' }).Count
    $mediumCount   = ($findings | Where-Object { $_.Severity -eq 'Medium' }).Count

    # Domain counts for posture algorithm
    $hasRevCritical      = ($findings | Where-Object { $_.FindingId -like 'DEC-REV-*'  -and $_.Severity -eq 'Critical' }).Count -gt 0
    $hasGrevCritical     = ($findings | Where-Object { $_.FindingId -like 'DEC-GREV-*' -and $_.Severity -eq 'Critical' }).Count -gt 0
    $hasPrivPimCritical  = ($findings | Where-Object { $_.FindingId -like 'DEC-PIM-*'  -and $_.Severity -eq 'Critical' }).Count -gt 0
    $hasReviewConflict   = ($findings | Where-Object { $_.FindingId -eq "DEC-REV-005" }).Count -gt 0
    $netRiskIncrease     = if ($riskMovement -and $riskMovement.NetRiskDelta -gt 50) { $true } else { $false }

    # Coverage gap check
    $gapFindings    = ($findings | Where-Object { $_.FindingId -like 'DEC-GREV-*' -or $_.FindingId -like 'DEC-REV-*' }).Count
    $caGapFindings  = ($findings | Where-Object { $_.FindingId -like 'DEC-CA-*' }).Count
    $multiCovGaps   = ($gapFindings -ge 3) -or ($caGapFindings -ge 2)

    # Executive risk posture — deterministic algorithm
    # Critical: >=3 critical findings, critical domain-specific findings, or major net risk increase
    if ($criticalCount -ge 3 -or $hasRevCritical -or $hasGrevCritical -or $hasPrivPimCritical -or $netRiskIncrease -or $hasReviewConflict) {
        $posture = 'Critical'
    } elseif ($highCount -ge 5 -or $multiCovGaps) {
        $posture = 'Elevated'
    } elseif ($mediumCount -gt 0 -or $highCount -gt 0 -or $criticalCount -gt 0) {
        $posture = 'Moderate'
    } else {
        # Only Low when no Critical/High and coverage is not partial
        $partialCoverage = $false
        if ($coverage) {
            foreach ($key in $coverage.Keys) {
                if ($coverage[$key] -eq $false) { $partialCoverage = $true; break }
            }
        }
        if ($partialCoverage) {
            $posture = 'Moderate'
        } else {
            $posture = 'Low'
        }
    }

    # Top risks — up to 10 by RiskScore, prefer unique domains
    $domains = @(
        'User Lifecycle','Guest Lifecycle','Privileged Access','Application',
        'Service Principal','Conditional Access','Governance',
        'Access Review Governance','Entitlement Management'
    )
    $topRisks = @()
    $seenDomains = @{}
    $sortedFindings = $findings | Sort-Object RiskScore -Descending | Where-Object { $_.RiskScore -gt 0 }

    # First pass: one per domain
    foreach ($f in $sortedFindings) {
        if ($topRisks.Count -ge 10) { break }
        $domain = Get-DecomRiskDomain -FindingId $f.FindingId -Category $f.Category
        if (-not $seenDomains.ContainsKey($domain)) {
            $seenDomains[$domain] = 0
            $topRisks += $f
        }
    }
    # Second pass: fill remaining slots if < 10
    foreach ($f in $sortedFindings) {
        if ($topRisks.Count -ge 10) { break }
        if ($topRisks -notcontains $f) {
            $topRisks += $f
        }
    }

    # Recommended next actions — deterministic, consultant-safe
    $nextActions = @(
        '1. Close critical disabled-user and privileged-role residue first.',
        '2. Review guest privileged access and sponsor ownership.',
        '3. Validate access review coverage for CA exclusion groups.',
        '4. Establish review cadence for PIM eligible assignments.',
        '5. Confirm access package review schedules and expiration policy.',
        '6. Re-run assessment after remediation to prove risk reduction.'
    )

    # Governance coverage summary
    $coverageSummary = @{}
    if ($coverage) {
        foreach ($key in $coverage.Keys) {
            $coverageSummary[$key] = $coverage[$key]
        }
    }

    return [PSCustomObject]@{
        SchemaVersion          = '2.4'
        ToolVersion            = if ($Context.ToolVersion) { $Context.ToolVersion } else { 'Rev2.4' }
        ClientName             = if ($Context.ClientName) { $Context.ClientName } else { 'Unknown' }
        EngagementId           = if ($Context.EngagementId) { $Context.EngagementId } else { '' }
        Assessor               = if ($Context.Assessor) { $Context.Assessor } else { '' }
        TenantId               = if ($Context.TenantId) { $Context.TenantId } else { '' }
        GeneratedUtc           = if ($Context.GeneratedUtc) { $Context.GeneratedUtc } else { (Get-Date).ToUniversalTime().ToString('o') }
        ExecutiveRiskPosture   = $posture
        TopRisks               = $topRisks
        RiskMovement           = $riskMovement
        BaselineSummary        = $baselineSummary
        GovernanceCoverage     = $coverageSummary
        RecommendedNextActions = $nextActions
        FindingCounts          = @{
            Critical     = $criticalCount
            High         = $highCount
            Medium       = $mediumCount
            Total        = $findings.Count
        }
        ExportPaths            = if ($Context.ExportPaths) { $Context.ExportPaths } else { @{} }
        AllFindings            = $findings
        ConsultantNotes        = @(
            'Assessment performed in read-only mode. No tenant modifications were made.',
            'Coverage may be partial depending on Graph permissions and license availability.',
            'Access review correlation requires AccessReview.Read.All permission.',
            'PIM data requires PrivilegedAccess.Read.AzureAD or equivalent.'
        )
    }
}

function Get-DecomRiskDomain {
    param(
        [string]$FindingId,
        [string]$Category
    )
    if ($FindingId -like 'DEC-USER-*')  { return 'User Lifecycle' }
    if ($FindingId -like 'DEC-GUEST-*') { return 'Guest Lifecycle' }
    if ($FindingId -like 'DEC-GREV-*')  { return 'Guest Lifecycle' }
    if ($FindingId -like 'DEC-PIM-*')   { return 'Privileged Access' }
    if ($FindingId -like 'DEC-ROLE-*')  { return 'Privileged Access' }
    if ($FindingId -like 'DEC-APP-*')   { return 'Application' }
    if ($FindingId -like 'DEC-SP-*')    { return 'Service Principal' }
    if ($FindingId -like 'DEC-CA-*')    { return 'Conditional Access' }
    if ($FindingId -like 'DEC-REV-*')   { return 'Access Review Governance' }
    if ($FindingId -like 'DEC-AP-*')    { return 'Entitlement Management' }
    if ($Category)                       { return $Category }
    return 'Governance'
}

function Export-DecomExecutiveSummaryMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $postureEmoji = switch ($Model.ExecutiveRiskPosture) {
        'Critical' { 'CRITICAL' }
        'Elevated' { 'ELEVATED' }
        'Moderate' { 'MODERATE' }
        default    { 'LOW' }
    }

    $postureNarrative = switch ($Model.ExecutiveRiskPosture) {
        'Critical' { 'The tenant exhibits critical identity governance gaps requiring immediate remediation. Multiple high-severity findings indicate significant exposure across privileged access, guest lifecycle, and access review governance.' }
        'Elevated' { 'The tenant has elevated identity governance risk with several high-severity findings. Governance coverage gaps and unreviewed privileged assignments require prioritized attention.' }
        'Moderate' { 'The tenant has moderate identity governance risk. While no critical threshold has been breached, medium and high findings require structured remediation planning.' }
        default    { 'The tenant demonstrates low identity governance risk based on current assessment coverage. Continued monitoring and periodic re-assessment are recommended.' }
    }

    $baselineSection = ''
    if ($Model.BaselineSummary) {
        $bs = $Model.BaselineSummary
        $baselineSection = @"

## Baseline Movement

| Status | Count |
|--------|-------|
| New | $($bs.New) |
| Persisting | $($bs.Persisting) |
| Resolved | $($bs.Resolved) |
| Changed Severity | $($bs.ChangedSeverity) |
| Changed Risk Score | $($bs.ChangedRiskScore) |
| Net Risk Delta | $($bs.NetRiskDelta) |

"@
    } else {
        $baselineSection = "`n## Baseline Movement`n`nNo baseline provided. Trend comparison not available for this run.`n"
    }

    # Top risks table
    $topRisksTable = "| # | Finding ID | Severity | Risk Score | Description |`n|---|-----------|----------|------------|-------------|`n"
    $idx = 1
    foreach ($r in $Model.TopRisks) {
        $desc = if ($r.Evidence) { ($r.Evidence -replace '\|','-') } else { $r.FindingId }
        if ($desc.Length -gt 80) { $desc = $desc.Substring(0,77) + '...' }
        $topRisksTable += "| $idx | $($r.FindingId) | $($r.Severity) | $($r.RiskScore) | $desc |`n"
        $idx++
    }
    if ($Model.TopRisks.Count -eq 0) {
        $topRisksTable += "| - | - | - | - | No findings |`n"
    }

    # Coverage table
    $covTable = "| Coverage Area | Status |`n|--------------|--------|`n"
    if ($Model.GovernanceCoverage -and $Model.GovernanceCoverage.Count -gt 0) {
        foreach ($key in $Model.GovernanceCoverage.Keys) {
            $val = if ($Model.GovernanceCoverage[$key] -eq $true) { 'Full' } elseif ($Model.GovernanceCoverage[$key] -eq $false) { 'Partial/Unavailable' } else { 'Unknown' }
            $covTable += "| $key | $val |`n"
        }
    } else {
        $covTable += "| Coverage data unavailable | - |`n"
    }

    $nextActionsText = ($Model.RecommendedNextActions | ForEach-Object { "- $_" }) -join "`n"

    $md = @"
# Executive Summary — Entra Identity Decommissioning Control Plane

## Engagement Context

| Field | Value |
|-------|-------|
| Client | $($Model.ClientName) |
| Engagement ID | $($Model.EngagementId) |
| Assessor | $($Model.Assessor) |
| Tenant ID | $($Model.TenantId) |
| Generated | $($Model.GeneratedUtc) |
| Tool Version | $($Model.ToolVersion) |

## Executive Risk Posture

**$postureEmoji**

$postureNarrative

## Key Findings

The assessment identified $($Model.FindingCounts.Total) total findings: $($Model.FindingCounts.Critical) Critical, $($Model.FindingCounts.High) High, $($Model.FindingCounts.Medium) Medium. These findings span user lifecycle management, guest identity governance, privileged access, and access review coverage. Findings are prioritized by risk score and remediation impact.

## Top 10 Risks

$topRisksTable

## Governance Evidence Coverage

$covTable
$baselineSection

## Recommended Next Actions

$nextActionsText

## Consultant Notes and Limitations

$(($Model.ConsultantNotes | ForEach-Object { "- $_" }) -join "`n")

---

*© 2026 Albert Jee. All rights reserved.*
"@

    Set-Content -Path $Path -Value $md -Encoding UTF8
}

function Export-DecomExecutiveSummaryHtml {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $postureColor = switch ($Model.ExecutiveRiskPosture) {
        'Critical' { '#c0392b' }
        'Elevated' { '#e67e22' }
        'Moderate' { '#f39c12' }
        default    { '#27ae60' }
    }

    $postureNarrative = switch ($Model.ExecutiveRiskPosture) {
        'Critical' { 'Critical identity governance gaps detected. Immediate remediation required.' }
        'Elevated' { 'Elevated governance risk. Prioritized remediation planning needed.' }
        'Moderate' { 'Moderate governance risk. Structured remediation plan recommended.' }
        default    { 'Low governance risk based on current assessment coverage.' }
    }

    # HTML-escape helper
    function hesc { param([string]$s) if ($s) { $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;') } else { '' } }

    # Top risks rows
    $topRisksRows = ''
    $idx = 1
    foreach ($r in $Model.TopRisks) {
        $sevColor = switch ($r.Severity) {
            'Critical' { '#c0392b' }
            'High'     { '#e67e22' }
            'Medium'   { '#f39c12' }
            default    { '#27ae60' }
        }
        $evidenceRaw = if ($r.Evidence) { if ($r.Evidence.Length -gt 100) { $r.Evidence.Substring(0,97) + '...' } else { $r.Evidence } } else { $r.FindingId }
        $evidence = hesc $evidenceRaw
        $topRisksRows += "<tr><td>$idx</td><td>$(hesc $r.FindingId)</td><td style='color:$sevColor;font-weight:bold'>$(hesc $r.Severity)</td><td>$($r.RiskScore)</td><td>$evidence</td></tr>`n"
        $idx++
    }
    if ($Model.TopRisks.Count -eq 0) {
        $topRisksRows = '<tr><td colspan="5">No findings</td></tr>'
    }

    # Coverage rows
    $covRows = ''
    if ($Model.GovernanceCoverage -and $Model.GovernanceCoverage.Count -gt 0) {
        foreach ($key in $Model.GovernanceCoverage.Keys) {
            $val = if ($Model.GovernanceCoverage[$key] -eq $true) { '<span style="color:#27ae60">Full</span>' } else { '<span style="color:#e67e22">Partial/Unavailable</span>' }
            $covRows += "<tr><td>$(hesc $key)</td><td>$val</td></tr>`n"
        }
    } else {
        $covRows = '<tr><td colspan="2">Coverage data unavailable</td></tr>'
    }

    # Baseline movement table
    $baselineHtml = ''
    if ($Model.BaselineSummary) {
        $bs = $Model.BaselineSummary
        $baselineHtml = @"
<h2>Baseline Movement</h2>
<table>
<tr><th>Status</th><th>Count</th></tr>
<tr><td>New</td><td>$($bs.New)</td></tr>
<tr><td>Persisting</td><td>$($bs.Persisting)</td></tr>
<tr><td>Resolved</td><td>$($bs.Resolved)</td></tr>
<tr><td>Changed Severity</td><td>$($bs.ChangedSeverity)</td></tr>
<tr><td>Changed Risk Score</td><td>$($bs.ChangedRiskScore)</td></tr>
<tr><td>Net Risk Delta</td><td>$($bs.NetRiskDelta)</td></tr>
</table>
"@
    } else {
        $baselineHtml = '<h2>Baseline Movement</h2><p>No baseline provided. Trend comparison not available for this run.</p>'
    }

    $nextActionsHtml = '<ol>' + ($Model.RecommendedNextActions | ForEach-Object { "<li>$(hesc ($_ -replace '^\d+\.\s*',''))</li>" }) -join '' + '</ol>'

    $notesHtml = '<ul>' + ($Model.ConsultantNotes | ForEach-Object { "<li>$(hesc $_)</li>" }) -join '' + '</ul>'

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Executive Summary - $(hesc $Model.ClientName)</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #0d1b2a; color: #e8eaf6; margin: 0; padding: 0; }
  .header { background: #1a2744; padding: 28px 40px; border-bottom: 3px solid #2e4a7a; }
  .header h1 { margin: 0; font-size: 1.6em; color: #7eb3ff; }
  .header .sub { color: #a0b4d0; margin-top: 6px; font-size: 0.9em; }
  .content { max-width: 1100px; margin: 0 auto; padding: 30px 40px; }
  h2 { color: #7eb3ff; border-bottom: 1px solid #2e4a7a; padding-bottom: 6px; margin-top: 32px; }
  .posture-badge { display: inline-block; background: $postureColor; color: #fff; padding: 10px 28px; border-radius: 4px; font-size: 1.3em; font-weight: bold; letter-spacing: 1px; margin: 10px 0; }
  .kpi-grid { display: flex; gap: 16px; flex-wrap: wrap; margin: 18px 0; }
  .kpi { background: #1a2744; border: 1px solid #2e4a7a; border-radius: 6px; padding: 16px 24px; min-width: 130px; text-align: center; }
  .kpi .val { font-size: 2em; font-weight: bold; color: #7eb3ff; }
  .kpi .lbl { font-size: 0.8em; color: #a0b4d0; margin-top: 4px; }
  table { width: 100%; border-collapse: collapse; margin: 14px 0; font-size: 0.9em; }
  th { background: #1a2744; color: #7eb3ff; padding: 9px 12px; text-align: left; border: 1px solid #2e4a7a; }
  td { padding: 8px 12px; border: 1px solid #2e4a7a; }
  tr:nth-child(even) { background: #131e30; }
  .meta-table td:first-child { color: #a0b4d0; width: 160px; }
  ol, ul { padding-left: 22px; }
  li { margin: 5px 0; }
  .footer { text-align: center; color: #4a6080; padding: 24px; font-size: 0.8em; border-top: 1px solid #1a2744; margin-top: 40px; }
</style>
</head>
<body>
<div class="header">
  <h1>Executive Summary — Entra Identity Decommissioning Control Plane</h1>
  <div class="sub">$(hesc $Model.ToolVersion) | SchemaVersion $($Model.SchemaVersion) | $(hesc $Model.GeneratedUtc)</div>
</div>
<div class="content">

<h2>Engagement Context</h2>
<table class="meta-table">
<tr><td>Client</td><td>$(hesc $Model.ClientName)</td></tr>
<tr><td>Engagement ID</td><td>$(hesc $Model.EngagementId)</td></tr>
<tr><td>Assessor</td><td>$(hesc $Model.Assessor)</td></tr>
<tr><td>Tenant ID</td><td>$(hesc $Model.TenantId)</td></tr>
<tr><td>Generated</td><td>$(hesc $Model.GeneratedUtc)</td></tr>
</table>

<h2>Executive Risk Posture</h2>
<div class="posture-badge">$(hesc $Model.ExecutiveRiskPosture)</div>
<p>$(hesc $postureNarrative)</p>

<div class="kpi-grid">
  <div class="kpi"><div class="val">$($Model.FindingCounts.Total)</div><div class="lbl">Total Findings</div></div>
  <div class="kpi"><div class="val" style="color:#c0392b">$($Model.FindingCounts.Critical)</div><div class="lbl">Critical</div></div>
  <div class="kpi"><div class="val" style="color:#e67e22">$($Model.FindingCounts.High)</div><div class="lbl">High</div></div>
  <div class="kpi"><div class="val" style="color:#f39c12">$($Model.FindingCounts.Medium)</div><div class="lbl">Medium</div></div>
</div>

<h2>Top 10 Risks</h2>
<table>
<tr><th>#</th><th>Finding ID</th><th>Severity</th><th>Risk Score</th><th>Evidence</th></tr>
$topRisksRows
</table>

<h2>Governance Evidence Coverage</h2>
<table>
<tr><th>Coverage Area</th><th>Status</th></tr>
$covRows
</table>

$baselineHtml

<h2>Recommended Next Actions</h2>
$nextActionsHtml

<h2>Consultant Notes and Limitations</h2>
$notesHtml

</div>
<div class="footer">© 2026 Albert Jee. All rights reserved. | $(hesc $Model.ToolVersion) | SchemaVersion $($Model.SchemaVersion)</div>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding UTF8
}

function Export-DecomGovernanceKpiDashboardHtml {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    function hesc { param([string]$s) if ($s) { $s.Replace('&','&amp;').Replace('<','&lt;').Replace('>','&gt;').Replace('"','&quot;') } else { '' } }

    $findings = if ($Model.AllFindings) { @($Model.AllFindings) } else { @() }

    # KPI counts
    $totalFindings     = $findings.Count
    $criticalFindings  = ($findings | Where-Object { $_.Severity -eq 'Critical' }).Count
    $highFindings      = ($findings | Where-Object { $_.Severity -eq 'High' }).Count
    $privFindings      = ($findings | Where-Object { $_.FindingId -like 'DEC-PIM-*' -or $_.FindingId -like 'DEC-ROLE-*' }).Count
    $guestFindings     = ($findings | Where-Object { $_.FindingId -like 'DEC-GUEST-*' -or $_.FindingId -like 'DEC-GREV-*' }).Count
    $apFindings        = ($findings | Where-Object { $_.FindingId -like 'DEC-AP-*' }).Count
    $caFindings        = ($findings | Where-Object { $_.FindingId -like 'DEC-CA-*' }).Count
    $newSinceBaseline  = if ($Model.BaselineSummary) { $Model.BaselineSummary.New } else { 'N/A' }
    $resolvedSince     = if ($Model.BaselineSummary) { $Model.BaselineSummary.Resolved } else { 'N/A' }

    # Coverage status
    $coverage = $Model.GovernanceCoverage
    $covStatus = if ($coverage -and $coverage.Count -gt 0) {
        $fullCount    = ($coverage.Values | Where-Object { $_ -eq $true }).Count
        $partialCount = ($coverage.Values | Where-Object { $_ -eq $false }).Count
        "$fullCount Full / $partialCount Partial"
    } else { 'Unknown' }

    # Posture color
    $postureColor = switch ($Model.ExecutiveRiskPosture) {
        'Critical' { '#c0392b' }
        'Elevated' { '#e67e22' }
        'Moderate' { '#f39c12' }
        default    { '#27ae60' }
    }

    # Severity distribution rows
    $sevRows = ''
    foreach ($sev in @('Critical','High','Medium','Low','Informational')) {
        $cnt = ($findings | Where-Object { $_.Severity -eq $sev }).Count
        $barPct = if ($totalFindings -gt 0) { [int](($cnt / $totalFindings) * 100) } else { 0 }
        $sevColor = switch ($sev) {
            'Critical' { '#c0392b' }
            'High'     { '#e67e22' }
            'Medium'   { '#f39c12' }
            'Low'      { '#27ae60' }
            default    { '#7f8c8d' }
        }
        $sevRows += "<tr><td>$sev</td><td>$cnt</td><td><div style='background:$sevColor;height:14px;width:$($barPct)%;min-width:2px;border-radius:3px'></div></td></tr>`n"
    }

    # Coverage rows
    $covRows = ''
    if ($coverage -and $coverage.Count -gt 0) {
        foreach ($key in $coverage.Keys) {
            $status = if ($coverage[$key] -eq $true) { '<span style="color:#27ae60">Full</span>' } else { '<span style="color:#e67e22">Partial</span>' }
            $covRows += "<tr><td>$(hesc $key)</td><td>$status</td></tr>`n"
        }
    } else {
        $covRows = '<tr><td colspan="2">Coverage data unavailable</td></tr>'
    }

    # Access review section
    $revFindings = @($findings | Where-Object { $_.FindingId -like 'DEC-REV-*' -or $_.FindingId -like 'DEC-GREV-*' })
    $revRows = ''
    foreach ($rf in ($revFindings | Select-Object -First 10)) {
        $evidenceRaw = if ($rf.Evidence) { if ($rf.Evidence.Length -gt 80) { $rf.Evidence.Substring(0,77)+'...' } else { $rf.Evidence } } else { '-' }
        $evidence = hesc $evidenceRaw
        $revRows += "<tr><td>$(hesc $rf.FindingId)</td><td>$(hesc $rf.Severity)</td><td>$($rf.RiskScore)</td><td>$evidence</td></tr>`n"
    }
    if ($revRows -eq '') { $revRows = '<tr><td colspan="4">No access review governance findings</td></tr>' }

    # PIM section
    $pimFindings = @($findings | Where-Object { $_.FindingId -like 'DEC-PIM-*' })
    $pimRows = ''
    foreach ($pf in ($pimFindings | Select-Object -First 10)) {
        $evidenceRaw = if ($pf.Evidence) { if ($pf.Evidence.Length -gt 80) { $pf.Evidence.Substring(0,77)+'...' } else { $pf.Evidence } } else { '-' }
        $evidence = hesc $evidenceRaw
        $pimRows += "<tr><td>$(hesc $pf.FindingId)</td><td>$(hesc $pf.Severity)</td><td>$($pf.RiskScore)</td><td>$evidence</td></tr>`n"
    }
    if ($pimRows -eq '') { $pimRows = '<tr><td colspan="4">No PIM findings</td></tr>' }

    # Baseline section
    $baselineHtml = ''
    if ($Model.BaselineSummary) {
        $bs = $Model.BaselineSummary
        $baselineHtml = @"
<h2>Baseline Movement</h2>
<div class="kpi-grid">
  <div class="kpi"><div class="val" style="color:#c0392b">$($bs.New)</div><div class="lbl">New Findings</div></div>
  <div class="kpi"><div class="val" style="color:#27ae60">$($bs.Resolved)</div><div class="lbl">Resolved</div></div>
  <div class="kpi"><div class="val">$($bs.Persisting)</div><div class="lbl">Persisting</div></div>
  <div class="kpi"><div class="val">$($bs.NetRiskDelta)</div><div class="lbl">Net Risk Delta</div></div>
</div>
"@
    } else {
        $baselineHtml = '<h2>Baseline Movement</h2><p>No baseline provided for this run.</p>'
    }

    # Recommended next actions
    $actionsHtml = '<ol>' + ($Model.RecommendedNextActions | ForEach-Object { "<li>$(hesc ($_ -replace '^\d+\.\s*',''))</li>" }) -join '' + '</ol>'

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Governance KPI Dashboard - $(hesc $Model.ClientName)</title>
<style>
  body { font-family: 'Segoe UI', Arial, sans-serif; background: #0d1b2a; color: #e8eaf6; margin: 0; padding: 0; }
  .header { background: #1a2744; padding: 24px 40px; border-bottom: 3px solid #2e4a7a; }
  .header h1 { margin: 0; font-size: 1.5em; color: #7eb3ff; }
  .header .sub { color: #a0b4d0; margin-top: 5px; font-size: 0.85em; }
  .content { max-width: 1200px; margin: 0 auto; padding: 28px 40px; }
  h2 { color: #7eb3ff; border-bottom: 1px solid #2e4a7a; padding-bottom: 5px; margin-top: 30px; }
  .kpi-grid { display: flex; gap: 14px; flex-wrap: wrap; margin: 16px 0; }
  .kpi { background: #1a2744; border: 1px solid #2e4a7a; border-radius: 6px; padding: 14px 20px; min-width: 120px; text-align: center; }
  .kpi .val { font-size: 1.8em; font-weight: bold; color: #7eb3ff; }
  .kpi .lbl { font-size: 0.75em; color: #a0b4d0; margin-top: 3px; }
  .posture { display: inline-block; background: $postureColor; color: #fff; padding: 8px 22px; border-radius: 4px; font-weight: bold; font-size: 1.1em; }
  table { width: 100%; border-collapse: collapse; font-size: 0.88em; margin: 12px 0; }
  th { background: #1a2744; color: #7eb3ff; padding: 8px 10px; text-align: left; border: 1px solid #2e4a7a; }
  td { padding: 7px 10px; border: 1px solid #2e4a7a; }
  tr:nth-child(even) { background: #131e30; }
  ol,ul { padding-left: 20px; }
  li { margin: 4px 0; }
  .footer { text-align: center; color: #4a6080; padding: 20px; font-size: 0.78em; border-top: 1px solid #1a2744; margin-top: 36px; }
</style>
</head>
<body>
<div class="header">
  <h1>Governance KPI Dashboard — Entra Identity Decommissioning Control Plane</h1>
  <div class="sub">$(hesc $Model.ToolVersion) | $(hesc $Model.ClientName) | $(hesc $Model.GeneratedUtc)</div>
</div>
<div class="content">

<h2>At-a-Glance Risk Posture</h2>
<div class="posture">$(hesc $Model.ExecutiveRiskPosture)</div>

<h2>Finding Severity Distribution</h2>
<div class="kpi-grid">
  <div class="kpi"><div class="val">$totalFindings</div><div class="lbl">Total</div></div>
  <div class="kpi"><div class="val" style="color:#c0392b">$criticalFindings</div><div class="lbl">Critical</div></div>
  <div class="kpi"><div class="val" style="color:#e67e22">$highFindings</div><div class="lbl">High</div></div>
  <div class="kpi"><div class="val" style="color:#2980b9">$privFindings</div><div class="lbl">Privileged Access</div></div>
  <div class="kpi"><div class="val" style="color:#8e44ad">$guestFindings</div><div class="lbl">Guest Governance</div></div>
  <div class="kpi"><div class="val" style="color:#16a085">$apFindings</div><div class="lbl">Access Packages</div></div>
  <div class="kpi"><div class="val" style="color:#d35400">$caFindings</div><div class="lbl">CA Exclusions</div></div>
</div>
<table>
<tr><th>Severity</th><th>Count</th><th>Distribution</th></tr>
$sevRows
</table>

<h2>Governance Coverage Status</h2>
<table><tr><th>Coverage Area</th><th>Status</th></tr>
$covRows
</table>

<h2>Access Review Evidence Coverage</h2>
<table><tr><th>Finding ID</th><th>Severity</th><th>Risk Score</th><th>Evidence</th></tr>
$revRows
</table>

<h2>PIM and Privileged Access Review Posture</h2>
<table><tr><th>Finding ID</th><th>Severity</th><th>Risk Score</th><th>Evidence</th></tr>
$pimRows
</table>

$baselineHtml

<h2>Recommended Next Actions</h2>
$actionsHtml

</div>
<div class="footer">© 2026 Albert Jee. All rights reserved. | $(hesc $Model.ToolVersion) | SchemaVersion $($Model.SchemaVersion)</div>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding UTF8
}

function Export-DecomConsultantEvidenceAppendixMarkdown {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $exportInventory = ''
    if ($Model.ExportPaths -and $Model.ExportPaths.Count -gt 0) {
        foreach ($key in $Model.ExportPaths.Keys) {
            $val = $Model.ExportPaths[$key]
            if ($val) { $exportInventory += "- **$key**: $val`n" }
        }
    } else {
        $exportInventory = '- Export paths not available'
    }

    $md = @"
# Consultant Evidence Appendix — Entra Identity Decommissioning Control Plane

**Client:** $($Model.ClientName)
**Engagement ID:** $($Model.EngagementId)
**Assessor:** $($Model.Assessor)
**Generated:** $($Model.GeneratedUtc)
**Tool Version:** $($Model.ToolVersion)
**Schema Version:** $($Model.SchemaVersion)

---

## 1. Methodology

This assessment uses the Entra Identity Decommissioning Control Plane tool, which queries Microsoft Graph APIs to identify identity governance gaps across user lifecycle, guest lifecycle, privileged access, application ownership, Conditional Access, PIM, access reviews, and entitlement management. All data collection is read-only. No tenant modifications are performed during assessment mode.

## 2. Graph Permissions and Coverage

The following Graph permission scopes are required for full coverage:

- User.Read.All — User lifecycle and disabled account detection
- AuditLog.Read.All — Sign-in activity (optional, enhances detection)
- Directory.Read.All — Directory roles, groups, service principals
- Application.Read.All — Application registration and ownership
- Policy.Read.All — Conditional Access policy enumeration
- PrivilegedAccess.Read.AzureAD — PIM eligible assignments
- EntitlementManagement.Read.All — Access packages and assignments
- AccessReview.Read.All — Access review definitions, instances, decisions

Missing permissions result in partial coverage. Findings for unavailable areas are omitted, not fabricated.

## 3. Finding Schema

Each finding includes:
- **FindingId**: Unique detector identifier (e.g., DEC-USER-001)
- **Category**: Risk domain classification
- **Severity**: Critical / High / Medium / Low / Informational
- **RiskScore**: 0–100 numeric risk indicator
- **Confidence**: High / Medium / Low
- **ObjectType**: Type of affected object
- **ObjectId**: Entra object GUID
- **DisplayName**: Human-readable name
- **Evidence**: Specific evidence string
- **EvidenceSource**: Graph API endpoint or data source
- **RecommendedAction**: Remediation guidance

## 4. Coverage Limitations

- AuditLog.Read.All is optional. Without it, last sign-in data may be unavailable.
- PIM data requires PrivilegedAccess.Read.AzureAD or equivalent modern scope.
- Access review correlation requires AccessReview.Read.All.
- Entitlement Management requires EntitlementManagement.Read.All and an active Microsoft Entra ID Governance license.
- Guest review correlation uses review definition matching, not identity-level linking.
- Findings reflect point-in-time assessment state only.

## 5. Detector Families Included

| Prefix | Domain |
|--------|--------|
| DEC-USER | User Lifecycle |
| DEC-GUEST | Guest Lifecycle |
| DEC-GREV | Guest Review Governance |
| DEC-APP | Application Ownership |
| DEC-SP | Service Principal |
| DEC-CA | Conditional Access |
| DEC-PIM | Privileged Identity Management |
| DEC-ROLE | Directory Role Residue |
| DEC-REV | Access Review Governance |
| DEC-AP | Entitlement Management / Access Packages |

## 6. Access Review Correlation Limitations

Access review correlation links review definitions and instances to identity objects (guests, CA exclusion groups, access packages) using Entra review definition IDs. Limitations include:

- Instance-level matching depends on review scope configuration.
- Stale instance detection uses a 90-day threshold.
- Review decisions may reflect partial reviewer completion.
- Organizations without Entra ID Governance licensing may see limited review data.

## 7. Baseline Comparison Methodology

When a baseline findings JSON is provided via -BaselinePath, the tool:

1. Loads prior findings from the JSON export (SchemaVersion 2.3 or 2.4).
2. Generates a stable key per finding: FindingId|ObjectType|ObjectId|DisplayName.
3. Compares current findings against baseline using stable keys.
4. Classifies each finding as: New, Persisting, Resolved, ChangedSeverity, ChangedRiskScore, ChangedEvidence, or Unchanged.
5. Computes risk movement summary including NetRiskDelta.

Resolved findings (in baseline but not current run) may reflect true remediation or coverage gaps. Interpret in context of current coverage flags.

## 8. Safety Model Statement

Assessment, WhatIfRemediation, ExportPlan, and Rev2.4 executive pack generation are read-only operations. ExecuteRemediation remains governed by the existing Rev2.x three-gate safety model:

1. Gate 1: Approval manifest hash validation (HMAC-SHA256)
2. Gate 2: Preflight confirmation (interactive or -RequirePreflightConfirm flag)
3. Gate 3: Per-action revalidation before Graph write execution

Rev2.4 does not modify ExecuteRemediation behavior. No new write scopes or tenant-modifying Graph calls were added.

## 9. Export File Inventory

$exportInventory

## 10. Recommended Validation Steps

1. Verify findings against Entra admin center for critical and high severity items.
2. Confirm disabled user accounts flagged as having privileged roles or sign-in activity.
3. Validate guest accounts flagged for missing sponsors or stale review coverage.
4. Cross-reference PIM eligible assignments with privileged access policy.
5. Review CA exclusion groups for access review evidence before remediation.
6. Re-run assessment after remediation wave to confirm risk reduction.

---

*© 2026 Albert Jee. All rights reserved.*
"@

    Set-Content -Path $Path -Value $md -Encoding UTF8
}

function Write-DecomClientReadoutPackManifest {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $files = [ordered]@{}
    if ($Model.ExportPaths -and $Model.ExportPaths.Count -gt 0) {
        foreach ($key in $Model.ExportPaths.Keys) {
            $files[$key] = $Model.ExportPaths[$key]
        }
    }

    $manifest = [ordered]@{
        SchemaVersion    = '2.4'
        ToolVersion      = $Model.ToolVersion
        GeneratedUtc     = $Model.GeneratedUtc
        ClientName       = $Model.ClientName
        EngagementId     = $Model.EngagementId
        Assessor         = $Model.Assessor
        TenantId         = $Model.TenantId
        ExecutiveRiskPosture = $Model.ExecutiveRiskPosture
        BaselineAvailable = ($null -ne $Model.BaselineSummary)
        Files            = $files
        SafetyStatement  = 'Rev2.4 generated read-only reporting artifacts and did not modify tenant configuration.'
    }

    $json = $manifest | ConvertTo-Json -Depth 10
    Set-Content -Path $Path -Value $json -Encoding UTF8
}

function Export-DecomResidualRiskRegisterCsv {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Findings,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    # Domain to recommended owner mapping
    $ownerMap = @{
        'User Lifecycle'          = 'IAM / Identity Operations'
        'Guest Lifecycle'         = 'Business Owner / Collaboration Owner'
        'Access Review Governance'= 'IAM Governance'
        'Application'             = 'App Owner / Platform Engineering'
        'Service Principal'       = 'Platform Engineering'
        'Conditional Access'      = 'Security Engineering'
        'Privileged Access'       = 'IAM / Security'
        'Entitlement Management'  = 'Identity Governance'
        'Governance'              = 'IAM Governance'
    }

    $rows = @()
    $riskIdx = 1
    foreach ($f in $Findings) {
        $domain = Get-DecomRiskDomain -FindingId $f.FindingId -Category $f.Category
        $owner  = if ($ownerMap.ContainsKey($domain)) { $ownerMap[$domain] } else { 'IAM Governance' }

        $impact = switch ($f.Severity) {
            'Critical' { 'High business impact — immediate risk to identity security posture' }
            'High'     { 'Significant impact — remediation required within 30 days' }
            'Medium'   { 'Moderate impact — plan remediation within 90 days' }
            default    { 'Low impact — address in next governance review cycle' }
        }

        $rows += [PSCustomObject]@{
            RiskId             = "RISK-$($riskIdx.ToString('D4'))"
            FindingId          = $f.FindingId
            Severity           = $f.Severity
            RiskScore          = $f.RiskScore
            Domain             = $domain
            ObjectType         = $f.ObjectType
            ObjectId           = $f.ObjectId
            DisplayName        = $f.DisplayName
            Evidence           = $f.Evidence
            BusinessImpact     = $impact
            RecommendedOwner   = $owner
            RecommendedAction  = $f.RecommendedAction
            TargetDueDate      = ''
            Status             = 'Open'
        }
        $riskIdx++
    }

    if ($rows.Count -eq 0) {
        'RiskId,FindingId,Severity,RiskScore,Domain,ObjectType,ObjectId,DisplayName,Evidence,BusinessImpact,RecommendedOwner,RecommendedAction,TargetDueDate,Status' |
            Set-Content -Path $Path -Encoding UTF8
        return
    }

    $rows | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}
