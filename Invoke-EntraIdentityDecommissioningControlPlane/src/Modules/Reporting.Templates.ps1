# Reporting.Templates.ps1 — Target J (refactoring-plan)
# Static HTML/CSS template fragments. No variable expansion in return values —
# all dynamic binding uses __PLACEHOLDER__ tokens that the caller replaces.

# ------------------------------------------------------------------
# CSS strings — returned as-is (ASCII, no HTML, no PS expressions)
# ------------------------------------------------------------------

function Get-ReportingTemplateAssessmentCss {
    return @"
:root{--navy:#0b1220;--gold:#c6a75e;--text:#f8fafc;--muted:#cbd5e1;--cyan:#38bdf8;--red:#ef4444;--orange:#f59e0b;--green:#22c55e;--border:rgba(198,167,94,0.35);}
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
@media print{body{background:#fff;color:#000;}.advisory-bar,.filter-bar,[style*{position:fixed}]{display:none!important;}table{border:1px solid #ccc;}thead th{background:#f0f0f0;color:#000;}tbody td{color:#000;border-bottom:1px solid #ddd;}}
"@
}

function Get-ReportingTemplateExecutionCss {
    return @"
:root{--navy:#0b1220;--gold:#c6a75e;--text:#f8fafc;--muted:#cbd5e1;--cyan:#38bdf8;--red:#ef4444;--orange:#f59e0b;--green:#22c55e;--border:rgba(198,167,94,0.35);}
*{box-sizing:border-box;margin:0;padding:0;}
body{background:linear-gradient(135deg,#0b1220,#020617);color:var(--text);font-family:'Segoe UI',system-ui,sans-serif;min-height:100vh;}
.advisory-bar{width:100%;background:#0a0f1a;border-left:6px solid var(--gold);padding:12px 32px;font-size:13px;color:#94a3b8;}
.advisory-bar strong{color:var(--gold);}
.container{max-width:1280px;margin:0 auto;padding:40px;}
.header{border-left:6px solid var(--gold);padding-left:20px;margin-bottom:32px;}
.header h1{color:var(--text);font-size:34px;font-weight:700;}
.header .subtitle{color:var(--muted);font-size:16px;margin-top:6px;}
.meta-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-top:20px;}
.meta-item .label{color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:0.5px;}
.meta-item .value{color:var(--gold);font-size:14px;font-weight:600;margin-top:2px;}
.section-title{font-size:18px;font-weight:700;color:var(--gold);margin:32px 0 16px;border-bottom:1px solid var(--border);padding-bottom:8px;}
.scorecard{display:grid;grid-template-columns:repeat(6,1fr);gap:12px;margin-bottom:24px;}
.score-card{background:rgba(22,32,51,0.92);border-radius:12px;padding:16px;text-align:center;border:1px solid var(--border);}
.score-card .score-label{font-size:11px;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:8px;}
.score-card .score-value{font-size:26px;font-weight:700;}
table{width:100%;border-collapse:collapse;background:rgba(11,18,32,0.7);}
thead th{background:rgba(22,32,51,0.95);color:var(--gold);font-size:11px;text-transform:uppercase;letter-spacing:0.5px;padding:12px 14px;text-align:left;border-bottom:1px solid var(--border);}
tbody td{padding:12px 14px;border-bottom:1px solid rgba(198,167,94,0.12);font-size:14px;color:var(--text);vertical-align:top;}
tbody tr:hover{background:rgba(22,32,51,0.6);}
footer{margin-top:48px;padding-top:20px;border-top:1px solid var(--border);color:var(--muted);font-size:12px;display:flex;justify-content:space-between;align-items:center;}
"@
}

# ------------------------------------------------------------------
# Assessment body template — caller injects __DEMO_WATERMARK__, __SAFETY_BANNER__,
# __META_GRID__, __EXEC_SUMMARY__, __KPI_GRID__, __SCORECARD__, __LIMITATIONS__,
# and replaces __FINDING_ROWS__, __COVERAGE_ROWS__, __ROADMAP_HTML__.
# ------------------------------------------------------------------
function Get-ReportingTemplateAssessmentDocument {
    # Returns the full <style>+<body> structure as a single string.
    # Caller assembles: <head>+<style>+</head><body>+this+<script>+</body></html>
    $css   = Get-ReportingTemplateAssessmentCss
    $parts = @{
        header      = @"
<div class="advisory-bar">
  <strong>Consultant Assessment Tool</strong> — Assessment-first. No tenant objects modified in this run.
</div>
<div class="container">
  <div class="header">
    <h1>Entra Identity Decommissioning Control Plane</h1>
    <div class="subtitle">Identity Governance Assessment Report __TOOL_VERSION_ESC_HTML__</div>
    <div class="meta-grid">
__META_GRID__
    </div>
  </div>
  __SAFETY_BANNER__
  <div class="section-title">Executive Summary</div>
  <div class="exec-summary">
__EXEC_SUMMARY__
  </div>
  <div class="section-title">Key Performance Indicators</div>
__KPI_GRID__
  <div class="section-title">Severity Scorecard</div>
__SCORECARD__
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
__FINDING_ROWS__
    </tbody>
  </table>
  <div class="section-title">Coverage Summary</div>
  <table class="coverage-table">
    <thead><tr><th style="background:rgba(22,32,51,0.95);color:var(--gold);font-size:11px;text-transform:uppercase;padding:10px 14px;text-align:left;border-bottom:1px solid var(--border);">Graph Area</th><th style="background:rgba(22,32,51,0.95);color:var(--gold);font-size:11px;text-transform:uppercase;padding:10px 14px;text-align:left;border-bottom:1px solid var(--border);">Status</th></tr></thead>
    <tbody>
__COVERAGE_ROWS__
    </tbody>
  </table>
  <div class="section-title">Remediation Roadmap</div>
__ROADMAP_HTML__
  <div class="section-title">Assumptions and Limitations</div>
__LIMITATIONS__
  <footer>
    <span>Generated: __RUNDATE_ESC_HTML__ | Entra Identity Decommissioning Control Plane __TOOL_VERSION_ESC_HTML__</span>
    <span style="color:var(--muted);">&#169; 2026 Albert Jee. All rights reserved. | Consultant advisory tool &#8212; not a continuous monitoring platform</span>
  </footer>
</div>
"@
        script = @"
<script>
function applyFilters() {
  var severity = document.getElementById('filterSeverity').value;
  var category = document.getElementById('filterCategory').value;
  var rows = document.querySelectorAll('#findingsTable tbody tr');
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    var sev = row.getAttribute('data-severity') || '';
    var cat = row.getAttribute('data-category') || '';
    var show = (!severity || sev === severity) && (!category || cat === category);
    row.style.display = show ? '' : 'none';
  }
}
</script>
"@
        css = $css
    }
    return $parts
}

function Get-ReportingTemplateAssessmentScript {
    return @"
function applyFilters() {
  var severity = document.getElementById('filterSeverity').value;
  var category = document.getElementById('filterCategory').value;
  var rows = document.querySelectorAll('#findingsTable tbody tr');
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i];
    var sev = row.getAttribute('data-severity') || '';
    var cat = row.getAttribute('data-category') || '';
    var show = (!severity || sev === severity) && (!category || cat === category);
    row.style.display = show ? '' : 'none';
  }
}
"@
}

# ------------------------------------------------------------------
# Callers bind __ACTION_ROWS__ via -replace
# ------------------------------------------------------------------
function Get-ReportingTemplateExecutionDocument {
    $css  = Get-ReportingTemplateExecutionCss
    $body = @"
<div class="advisory-bar">
  <strong>Execution Evidence Report</strong> &#8212; __TOOL_VERSION_ESC_HTML__ | Controlled Remediation &#8212; Client Deliverable
</div>
<div class="container">
  <div class="header">
    <h1>Entra Identity Decommissioning Control Plane</h1>
    <div class="subtitle">Controlled Remediation Execution Report &#8212; __TOOL_VERSION_ESC_HTML__</div>
    <div class="meta-grid">
      <div class="meta-item"><div class="label">Tenant</div><div class="value">__TENANT_ESC_HTML__</div></div>
      <div class="meta-item"><div class="label">Run Date</div><div class="value">__RUNDATE_ESC_HTML__</div></div>
      <div class="meta-item"><div class="label">Version</div><div class="value">__TOOL_VERSION_ESC_HTML__</div></div>
      <div class="meta-item"><div class="label">Client</div><div class="value">__CLIENT_ESC_HTML__</div></div>
      <div class="meta-item"><div class="label">Engagement ID</div><div class="value">__ENGAGEMENT_ESC_HTML__</div></div>
      <div class="meta-item"><div class="label">Assessor</div><div class="value">__ASSESSOR_ESC_HTML__</div></div>
      <div class="meta-item"><div class="label">Approved By</div><div class="value">__APPROVED_BY_ESC_HTML__</div></div>
      <div class="meta-item"><div class="label">Approval Ticket</div><div class="value">__TICKET_ESC_HTML__</div></div>
      <div class="meta-item"><div class="label">Run ID</div><div class="value" style="font-size:11px;font-family:monospace">__RUN_ID_ESC_HTML__</div></div>
    </div>
  </div>
  <div class="section-title">Execution Scorecard</div>
__EXEC_SCORECARD__
  <div class="section-title">Action Evidence</div>
  <table>
    <thead>
      <tr>
        <th>Action ID</th>
        <th>Finding ID</th>
        <th>Object</th>
        <th>Action Type</th>
        <th>Outcome</th>
        <th>Before State</th>
        <th>After State</th>
        <th>Error Detail</th>
      </tr>
    </thead>
    <tbody>
__ACTION_ROWS__
    </tbody>
  </table>
  <footer>
    <span>Generated: __RUNDATE_ESC_HTML__ | Entra Identity Decommissioning Control Plane __TOOL_VERSION_ESC_HTML__</span>
    <span style="color:var(--muted);">&#169; 2026 Albert Jee. All rights reserved. | Consultant advisory tool &#8212; not a continuous monitoring platform</span>
  </footer>
</div>
"@
    return @{ css = $css; body = $body }
}