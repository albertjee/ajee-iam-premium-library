function Export-DecomAssessmentCsv {
    param([object[]]$Findings, [string]$Path)
    if (($Findings | Measure-Object).Count -eq 0) {
        $headers = '"FindingId","Category","Severity","RiskScore","Confidence","ObjectType","ObjectId","DisplayName","UserPrincipalName","Evidence","EvidenceSource","GraphEndpoint","RecommendedAction","RemediationMode","ConsultantNote","ProtectedObject","DetectedUtc"'
        Set-Content -Path $Path -Value $headers -Encoding UTF8
        return
    }
    $Findings | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
}

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

function Write-DecomRunManifest {
    param([string]$Path, [pscustomobject]$Context, [hashtable]$Summary, [hashtable]$ExportPaths)
    $manifest = [ordered]@{
        SchemaVersion  = '1.1'
        RunId          = [guid]::NewGuid().Guid
        GeneratedUtc   = (Get-Date).ToUniversalTime().ToString('o')
        TenantId       = $Context.TenantId
        Mode           = $Context.Mode
        DemoMode       = $Context.DemoMode
        EngagementId   = $Context.EngagementId
        ClientName     = $Context.ClientName
        Assessor       = $Context.Assessor
        FindingSummary = $Summary
        Exports        = $ExportPaths
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding UTF8
}

function Export-DecomAssessmentHtml {
    param([object[]]$Findings, [string]$Path, [pscustomobject]$Context, [hashtable]$Summary)

    $tenantDisplay   = if ($Context.DemoMode) { 'DEMO — contoso.onmicrosoft.com' } else { $Context.TenantId }
    $clientDisplay   = if ($Context.ClientName) { $Context.ClientName } else { '—' }
    $engagementId    = if ($Context.EngagementId) { $Context.EngagementId } else { '—' }
    $assessorDisplay = if ($Context.Assessor) { $Context.Assessor } else { '—' }
    $runDate         = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
    $modeDisplay     = $Context.Mode
    $critHighCount   = $Summary.Critical + $Summary.High
    $totalCount      = $Summary.Total

    $coverageMode    = 'Full'
    if ($Context.Coverage) {
        $coverageValues = $Context.Coverage.Values | Where-Object { $_ -eq $false }
        if ($coverageValues.Count -gt 0) { $coverageMode = 'Partial' }
    }

    $protectedCount  = ($Findings | Where-Object { $_.ProtectedObject -eq $true }).Count
    $userCount       = ($Findings | Where-Object { $_.ObjectType -eq 'User' } | Select-Object -ExpandProperty ObjectId -Unique).Count

    $demoWatermark = ''
    if ($Context.DemoMode) {
        $demoWatermark = @'
<div style="position:fixed;top:50%;left:50%;transform:translate(-50%,-50%) rotate(-35deg);font-size:100px;font-weight:900;color:rgba(198,167,94,0.06);pointer-events:none;z-index:9999;white-space:nowrap;letter-spacing:12px;font-family:sans-serif;">DEMO DATA</div>
'@
    }

    $safetyBanner = ''
    if ($Context.Mode -eq 'Assessment') {
        $safetyBanner = @'
<div style="background:rgba(34,197,94,0.1);border:1px solid rgba(34,197,94,0.4);border-radius:10px;padding:14px 18px;color:#22c55e;font-weight:600;margin-bottom:24px;">
  &#10003; Assessment mode — no tenant objects were modified during this run.
</div>
'@
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
        $evidenceEsc  = [System.Web.HttpUtility]::HtmlEncode($f.Evidence)
        $actionEsc    = [System.Web.HttpUtility]::HtmlEncode($f.RecommendedAction)
        $displayEsc   = [System.Web.HttpUtility]::HtmlEncode($f.DisplayName)
        $categoryEsc  = [System.Web.HttpUtility]::HtmlEncode($f.Category)
        $severityEsc  = [System.Web.HttpUtility]::HtmlEncode($f.Severity)
        $remModeEsc   = [System.Web.HttpUtility]::HtmlEncode($f.RemediationMode)
        $confEsc      = [System.Web.HttpUtility]::HtmlEncode($f.Confidence)
        $null = $findingRowsHtml.Append(@"
<tr data-severity="$severityEsc" data-category="$categoryEsc">
  <td style="font-family:monospace;font-size:12px;">$([System.Web.HttpUtility]::HtmlEncode($f.FindingId))</td>
  <td style="$severityColor">$severityEsc</td>
  <td>$categoryEsc</td>
  <td>$displayEsc</td>
  <td style="font-size:13px;color:var(--muted)">$evidenceEsc</td>
  <td style="font-size:13px;">$actionEsc</td>
  <td>$confEsc</td>
  <td style="font-size:12px;">$remModeEsc</td>
</tr>
"@)
    }

    $topFindings = $Findings | Where-Object { $_.Severity -in 'Critical','High' } | Select-Object -First 3
    $roadmapHtml = [System.Text.StringBuilder]::new()
    $i = 1
    foreach ($f in $topFindings) {
        $null = $roadmapHtml.Append(@"
<div style="background:rgba(22,32,51,0.92);border-radius:12px;padding:16px 20px;margin-bottom:12px;border-left:4px solid var(--gold);">
  <div style="color:var(--gold);font-size:12px;font-weight:700;margin-bottom:6px;">PRIORITY $i — $([System.Web.HttpUtility]::HtmlEncode($f.Severity))</div>
  <div style="color:var(--text);font-weight:600;margin-bottom:4px;">$([System.Web.HttpUtility]::HtmlEncode($f.FindingId)) · $([System.Web.HttpUtility]::HtmlEncode($f.DisplayName))</div>
  <div style="color:var(--muted);font-size:13px;">$([System.Web.HttpUtility]::HtmlEncode($f.RecommendedAction))</div>
</div>
"@)
        $i++
    }

    $coverageRowsHtml = [System.Text.StringBuilder]::new()
    if ($Context.Coverage) {
        foreach ($key in $Context.Coverage.Keys) {
            $val     = $Context.Coverage[$key]
            $valText = if ($val) { '<span style="color:var(--green)">&#10003; Available</span>' } else { '<span style="color:var(--muted)">&#8212; Not assessed</span>' }
            $null = $coverageRowsHtml.Append("<tr><td style='color:var(--muted)'>$([System.Web.HttpUtility]::HtmlEncode($key))</td><td>$valText</td></tr>`n")
        }
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Entra Identity Decommissioning Assessment — Rev1.1</title>
<style>
:root {
  --navy:   #0b1220;
  --gold:   #c6a75e;
  --text:   #f8fafc;
  --muted:  #cbd5e1;
  --cyan:   #38bdf8;
  --red:    #ef4444;
  --orange: #f59e0b;
  --green:  #22c55e;
  --border: rgba(198,167,94,0.35);
}
*{box-sizing:border-box;margin:0;padding:0;}
body{background:linear-gradient(135deg,#0b1220,#020617);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;min-height:100vh;}
.advisory-bar{width:100%;background:#0a0f1a;border-left:6px solid var(--gold);padding:12px 32px;font-size:13px;color:#94a3b8;}
.advisory-bar strong{color:var(--gold);}
.container{max-width:1280px;margin:0 auto;padding:40px;}
.header{border-left:6px solid var(--gold);padding-left:20px;margin-bottom:32px;}
.header h1{color:var(--text);font-size:34px;font-weight:700;line-height:1.2;}
.header .subtitle{color:var(--muted);font-size:16px;margin-top:6px;}
.meta-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:20px;}
.meta-item .label{color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:0.5px;}
.meta-item .value{color:var(--gold);font-size:14px;font-weight:600;margin-top:2px;}
.section-title{font-size:18px;font-weight:700;color:var(--gold);margin:32px 0 16px;border-bottom:1px solid var(--border);padding-bottom:8px;}
.kpi-grid{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px;}
.kpi-card{background:rgba(22,32,51,0.92);border-radius:16px;padding:20px;border:1px solid var(--border);}
.kpi-card .kpi-label{color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:0.5px;}
.kpi-card .kpi-value{font-size:34px;font-weight:700;margin:8px 0 4px;}
.kpi-card .kpi-note{color:var(--muted);font-size:13px;}
.scorecard{display:grid;grid-template-columns:repeat(5,1fr);gap:12px;margin-bottom:24px;}
.score-card{background:rgba(22,32,51,0.92);border-radius:12px;padding:16px;text-align:center;border:1px solid var(--border);}
.score-card .score-label{font-size:11px;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:8px;}
.score-card .score-value{font-size:28px;font-weight:700;}
.filter-bar{display:flex;gap:12px;margin-bottom:16px;align-items:center;}
.filter-bar select{background:rgba(22,32,51,0.92);color:var(--text);border:1px solid var(--border);border-radius:8px;padding:8px 14px;font-size:13px;cursor:pointer;}
.filter-bar label{color:var(--muted);font-size:13px;}
table{width:100%;border-collapse:collapse;background:rgba(11,18,32,0.7);}
thead th{background:rgba(22,32,51,0.95);color:var(--gold);font-size:11px;text-transform:uppercase;letter-spacing:0.5px;padding:12px 14px;text-align:left;border-bottom:1px solid var(--border);}
tbody td{padding:12px 14px;border-bottom:1px solid rgba(198,167,94,0.12);font-size:14px;color:var(--text);vertical-align:top;}
tbody tr:hover{background:rgba(22,32,51,0.6);}
.exec-summary{background:rgba(22,32,51,0.6);border-radius:12px;padding:20px 24px;color:var(--muted);line-height:1.7;margin-bottom:24px;}
.exec-summary strong{color:var(--text);}
.coverage-table{width:100%;border-collapse:collapse;}
.coverage-table td{padding:10px 14px;border-bottom:1px solid rgba(198,167,94,0.1);font-size:14px;}
footer{margin-top:48px;padding-top:20px;border-top:1px solid var(--border);color:var(--muted);font-size:12px;display:flex;justify-content:space-between;align-items:center;}
.limitations{background:rgba(22,32,51,0.6);border-radius:12px;padding:20px 24px;color:var(--muted);font-size:13px;line-height:1.8;}
.limitations li{margin-left:20px;margin-bottom:4px;}
@media print{
  body{background:#fff;color:#000;}
  .advisory-bar,.filter-bar,[style*="position:fixed"]{display:none!important;}
  table{border:1px solid #ccc;}
  thead th{background:#f0f0f0;color:#000;}
  tbody td{color:#000;border-bottom:1px solid #ddd;}
}
</style>
</head>
<body>
$demoWatermark
<div class="advisory-bar">
  <strong>Consultant Assessment Tool</strong> — Assessment-first. No tenant objects modified in this run.
</div>
<div class="container">
  <div class="header">
    <h1>Entra Identity Decommissioning Control Plane</h1>
    <div class="subtitle">Identity Governance Assessment Report — Rev1.1</div>
    <div class="meta-grid">
      <div class="meta-item"><div class="label">Tenant</div><div class="value">$([System.Web.HttpUtility]::HtmlEncode($tenantDisplay))</div></div>
      <div class="meta-item"><div class="label">Run Date</div><div class="value">$([System.Web.HttpUtility]::HtmlEncode($runDate))</div></div>
      <div class="meta-item"><div class="label">Version</div><div class="value">Rev1.1</div></div>
      <div class="meta-item"><div class="label">Mode</div><div class="value">$([System.Web.HttpUtility]::HtmlEncode($modeDisplay))</div></div>
      <div class="meta-item"><div class="label">Client</div><div class="value">$([System.Web.HttpUtility]::HtmlEncode($clientDisplay))</div></div>
      <div class="meta-item"><div class="label">Engagement ID</div><div class="value">$([System.Web.HttpUtility]::HtmlEncode($engagementId))</div></div>
      <div class="meta-item"><div class="label">Assessor</div><div class="value">$([System.Web.HttpUtility]::HtmlEncode($assessorDisplay))</div></div>
      <div class="meta-item"><div class="label">Coverage</div><div class="value">$([System.Web.HttpUtility]::HtmlEncode($coverageMode))</div></div>
      <div class="meta-item"><div class="label">Findings Total</div><div class="value">$totalCount</div></div>
    </div>
  </div>

  $safetyBanner

  <div class="section-title">Executive Summary</div>
  <div class="exec-summary">
    <p>This assessment identified <strong>$totalCount finding(s)</strong> across the Entra identity environment, including
    <strong style="color:var(--red)">$($Summary.Critical) Critical</strong>,
    <strong style="color:var(--orange)">$($Summary.High) High</strong>,
    <strong style="color:var(--cyan)">$($Summary.Medium) Medium</strong>,
    <strong style="color:var(--green)">$($Summary.Low) Low</strong>, and
    <strong style="color:var(--muted)">$($Summary.Informational) Informational</strong> findings.
    A total of <strong>$critHighCount</strong> findings require immediate attention.
    $( if ($protectedCount -gt 0) { "Additionally, <strong>$protectedCount protected object(s)</strong> were identified and flagged for manual review." } )
    All findings were identified in read-only Assessment mode — no tenant objects were modified during this run.</p>
  </div>

  <div class="section-title">Key Performance Indicators</div>
  <div class="kpi-grid">
    <div class="kpi-card">
      <div class="kpi-label">Total Findings</div>
      <div class="kpi-value" style="color:var(--cyan)">$totalCount</div>
      <div class="kpi-note">Across all severity levels</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-label">Critical + High</div>
      <div class="kpi-value" style="color:var(--red)">$critHighCount</div>
      <div class="kpi-note">Require immediate action</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-label">Protected Objects</div>
      <div class="kpi-value" style="color:var(--orange)">$protectedCount</div>
      <div class="kpi-note">Manual review required</div>
    </div>
    <div class="kpi-card">
      <div class="kpi-label">Coverage Mode</div>
      <div class="kpi-value" style="color:var(--gold);font-size:24px;">$([System.Web.HttpUtility]::HtmlEncode($coverageMode))</div>
      <div class="kpi-note">Graph API coverage</div>
    </div>
  </div>

  <div class="section-title">Severity Scorecard</div>
  <div class="scorecard">
    <div class="score-card"><div class="score-label" style="color:var(--red)">Critical</div><div class="score-value" style="color:var(--red)">$($Summary.Critical)</div></div>
    <div class="score-card"><div class="score-label" style="color:var(--orange)">High</div><div class="score-value" style="color:var(--orange)">$($Summary.High)</div></div>
    <div class="score-card"><div class="score-label" style="color:var(--cyan)">Medium</div><div class="score-value" style="color:var(--cyan)">$($Summary.Medium)</div></div>
    <div class="score-card"><div class="score-label" style="color:var(--green)">Low</div><div class="score-value" style="color:var(--green)">$($Summary.Low)</div></div>
    <div class="score-card"><div class="score-label" style="color:var(--muted)">Informational</div><div class="score-value" style="color:var(--muted)">$($Summary.Informational)</div></div>
  </div>

  <div class="section-title">Findings</div>
  <div class="filter-bar">
    <label>Severity:</label>
    <select id="filterSeverity" onchange="applyFilters()">
      <option value="">All</option>
      <option value="Critical">Critical</option>
      <option value="High">High</option>
      <option value="Medium">Medium</option>
      <option value="Low">Low</option>
      <option value="Informational">Informational</option>
    </select>
    <label>Category:</label>
    <select id="filterCategory" onchange="applyFilters()">
      <option value="">All</option>
      <option value="User Lifecycle">User Lifecycle</option>
      <option value="Application">Application</option>
      <option value="Guest Lifecycle">Guest Lifecycle</option>
      <option value="Conditional Access">Conditional Access</option>
      <option value="Governance">Governance</option>
    </select>
  </div>
  <table id="findingsTable">
    <thead>
      <tr>
        <th>Finding ID</th>
        <th>Severity</th>
        <th>Category</th>
        <th>Object</th>
        <th>Evidence</th>
        <th>Recommended Action</th>
        <th>Confidence</th>
        <th>Remediation Mode</th>
      </tr>
    </thead>
    <tbody>
$($findingRowsHtml.ToString())
    </tbody>
  </table>

  <div class="section-title">Coverage Summary</div>
  <table class="coverage-table">
    <thead><tr><th style="background:rgba(22,32,51,0.95);color:var(--gold);font-size:11px;text-transform:uppercase;padding:10px 14px;text-align:left;border-bottom:1px solid var(--border);">Graph Area</th><th style="background:rgba(22,32,51,0.95);color:var(--gold);font-size:11px;text-transform:uppercase;padding:10px 14px;text-align:left;border-bottom:1px solid var(--border);">Status</th></tr></thead>
    <tbody>
$($coverageRowsHtml.ToString())
    </tbody>
  </table>

  <div class="section-title">Remediation Roadmap</div>
$($roadmapHtml.ToString())

  <div class="section-title">Assumptions and Limitations</div>
  <div class="limitations">
    <ul>
      <li>This report was generated in Assessment mode. No tenant objects were modified during this run.</li>
      <li>Sign-in log analysis requires the <code>AuditLog.Read.All</code> delegated permission. If this scope was unavailable, stale identity analysis may be incomplete.</li>
      <li>IGA coverage assessment requires the <code>EntitlementManagement.Read.All</code> delegated permission.</li>
      <li>Rev1.1 does not support hybrid or on-premises AD DS environments. Only cloud-only and hybrid cloud-synced objects are assessed.</li>
      <li>Protected object classification is based on display name pattern matching. False positives are possible and should be reviewed with the client.</li>
      <li>Findings reflect point-in-time assessment. Access state may have changed between assessment and report delivery.</li>
      <li>This tool is a consultant advisory tool — it is not a continuous monitoring platform.</li>
    </ul>
  </div>

  <footer>
    <span>Generated: $([System.Web.HttpUtility]::HtmlEncode($runDate)) | Entra Identity Decommissioning Control Plane Rev1.1</span>
    <span>Consultant advisory tool — not a continuous monitoring platform</span>
  </footer>
</div>

<script>
function applyFilters() {
  var severity = document.getElementById('filterSeverity').value;
  var category = document.getElementById('filterCategory').value;
  var rows = document.querySelectorAll('#findingsTable tbody tr');
  rows.forEach(function(row) {
    var sev = row.getAttribute('data-severity') || '';
    var cat = row.getAttribute('data-category') || '';
    var show = (!severity || sev === severity) && (!category || cat === category);
    row.style.display = show ? '' : 'none';
  });
}
</script>
</body>
</html>
"@

    Set-Content -Path $Path -Value $html -Encoding UTF8
}
