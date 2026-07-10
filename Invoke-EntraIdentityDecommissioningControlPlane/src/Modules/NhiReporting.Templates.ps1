# NhiReporting.Templates.ps1 -- Candidate 2 (improve-codebase-architecture, mirrors Target J)
# Static HTML/CSS template fragments for the NHI governance dashboard.

function Get-NhiReportingTemplateDashboardCss {
    return @"
body { font-family: Arial, sans-serif; margin: 20px; }
.header { background-color: #f0f0f0; padding: 20px; text-align: center; }
.summary { display: flex; justify-content: space-around; margin: 20px 0; }
.summary-box { border: 1px solid #ccc; padding: 15px; text-align: center; min-width: 150px; }
.finding-table { width: 100%; border-collapse: collapse; margin: 20px 0; }
.finding-table th, .finding-table td { border: 1px solid #ddd; padding: 8px; text-align: left; }
.finding-table th { background-color: #f2f2f2; }
.trend-up { color: red; }
.trend-down { color: green; }
.severity-Critical { background-color: #ffebee; }
.severity-High { background-color: #fff3e0; }
.severity-Medium { background-color: #fff8e1; }
.severity-Low { background-color: #f3e5f5; }
.severity-Informational { background-color: #f5f5f5; }
"@
}
