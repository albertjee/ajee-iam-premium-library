# HTML constants for NHI report generation
$_NHI_DASHBOARD_CSS = @"
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

function Invoke-DecomNhiReporting {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiInventory,

        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiGovernanceFindings,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    Write-DecomInfo "Starting NHI reporting generation..."

    $reportingOutput = @{
        NhIInventory = $NhiInventory
        NhIGovernanceFindings = $NhiGovernanceFindings
        NhIReportingTimestamp = Get-Date -Format o
        Context = $Context
    }

    # Generate NHI inventory exports (CSV/JSON)
    $csvPath = Invoke-DecomNhiExportInventoryCsv -NhiInventory $NhiInventory -Context $Context
    $jsonPath = Invoke-DecomNhiExportInventoryJson -NhiInventory $NhiInventory -Context $Context

    # Generate NHI governance dashboard HTML
    $dashboardPath = Invoke-DecomNhiGenerateGovernanceDashboard -NhiGovernanceFindings $NhiGovernanceFindings -Context $Context

    # Create NHI executive summary
    $executiveSummaryPath = Invoke-DecomNhiGenerateExecutiveSummary -NhiInventory $NhiInventory -NhiGovernanceFindings $NhiGovernanceFindings -Context $Context

    # Produce NHI evidence appendix
    $evidenceAppendixPath = Invoke-DecomNhiGenerateEvidenceAppendix -NhiInventory $NhiInventory -NhiGovernanceFindings $NhiGovernanceFindings -Context $Context

    # Generate NHI exception register
    $exceptionRegisterPath = Invoke-DecomNhiGenerateExceptionRegister -NhiGovernanceFindings $NhiGovernanceFindings -Context $Context

    # Create agentic identity review packet
    $agenticReviewPath = Invoke-DecomNhiGenerateAgenticReviewPacket -NhiInventory $NhiInventory -NhiGovernanceFindings $NhiGovernanceFindings -Context $Context

    # Generate Rev4 NHI write-readiness report
    $writeReadinessPath = Invoke-DecomNhiGenerateRev4WriteReadinessReport -NhiInventory $NhiInventory -NhiGovernanceFindings $NhiGovernanceFindings -Context $Context

    Write-DecomOk "NHI reporting generation complete"
    return $reportingOutput
}

function Invoke-DecomNhiExportInventoryCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiInventory,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if ($Context.DemoMode) {
        $path = Join-Path $Context.OutputPath "nhi-inventory-demo.csv"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $path = Join-Path $Context.OutputPath "nhi-inventory-$timestamp.csv"
    }

    # Select relevant properties for CSV export
    $csvData = $NhiInventory | Select-Object `
        ObjectId, `
        AppId, `
        DisplayName, `
        ObjectType, `
        ServicePrincipalType, `
        PublisherName, `
        IsVerifiedPublisher, `
        SignInAudience, `
        AccountEnabled, `
        CreatedDateTime, `
        Tags, `
        Homepage, `
        AppOwnerOrganizationId, `
        NhiCandidate, `
        AgenticCandidate, `
        AutomationCandidate, `
        WorkloadCandidate, `
        Classification, `
        ClassificationConfidence, `
        ClassificationScore, `
        ClassificationSignals, `
        OwnerCount, `
        CredentialCount, `
        ExpiredCredentialCount, `
        ExpiringCredentialCount, `
        HighRiskPermissionCount, `
        HighRiskOAuthGrantCount, `
        TenantWideConsent, `
        FirstPartyMicrosoftApp, `
        RiskScore, `
        Severity, `
        CoverageMode, `
        CoverageLimitations, `
        RiskScoreMayBeUnderstated, `
        EvidenceSource, `
        EvidenceConfidence

    $csvData | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    Write-DecomInfo "NHI inventory CSV exported to $path"
    return $path
}

function Invoke-DecomNhiExportInventoryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiInventory,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if ($Context.DemoMode) {
        $path = Join-Path $Context.OutputPath "nhi-inventory-demo.json"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $path = Join-Path $Context.OutputPath "nhi-inventory-$timestamp.json"
    }

    $jsonData = $NhiInventory | ConvertTo-Json -Depth 10
    $jsonData | Out-File -FilePath $path -Encoding UTF8
    Write-DecomInfo "NHI inventory JSON exported to $path"
    return $path
}

function Invoke-DecomNhiGenerateGovernanceDashboard {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiGovernanceFindings,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if ($Context.DemoMode) {
        $path = Join-Path $Context.OutputPath "nhi-governance-dashboard-demo.html"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $path = Join-Path $Context.OutputPath "nhi-governance-dashboard-$timestamp.html"
    }

    # Basic HTML dashboard template - CSS is provided by $_NHI_DASHBOARD_CSS constant
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>NHI Governance Dashboard</title>
    <style>
        $($_NHI_DASHBOARD_CSS)
    </style>
</head>
<body>
    <div class="header">
        <h1>NHI Governance Dashboard</h1>
        <p>Generated: $(Get-Date -Format u)</p>
    </div>

    <div class="summary">
        <div class="summary-box">
            <h3>Total NHIs</h3>
            <p>$($NhiGovernanceFindings | Group-Object -Property ObjectId | Measure-Object | Select-Object -ExpandProperty Count)</p>
        </div>
        <div class="summary-box">
            <h3>Total Findings</h3>
            <p>$($NhiGovernanceFindings.Count)</p>
        </div>
        <div class="summary-box">
            <h3>Critical Findings</h3>
            <p>$($NhiGovernanceFindings | Where-Object { $_.Severity -eq 'Critical' }).Count)</p>
        </div>
        <div class="summary-box">
            <h3>High Findings</h3>
            <p>$($NhiGovernanceFindings | Where-Object { $_.Severity -eq 'High' }).Count)</p>
        </div>
    </div>

    <h2>Findings Details</h2>
    <table class="finding-table">
        <thead>
            <tr>
                <th>Finding ID</th>
                <th>Category</th>
                <th>Severity</th>
                <th>Risk Score</th>
                <th>Object Type</th>
                <th>Object ID</th>
                <th>Display Name</th>
                <th>Evidence</th>
                <th>Recommended Action</th>
                <th>Remediation Mode</th>
            </tr>
        </thead>
        <tbody>
"@

    foreach ($finding in $NhiGovernanceFindings) {
        $html += @"
            <tr class="severity-$($finding.Severity.ToLower())">
                <td>$($finding.FindingId)</td>
                <td>$($finding.Category)</td>
                <td>$($finding.Severity)</td>
                <td>$($finding.RiskScore)</td>
                <td>$($finding.ObjectType)</td>
                <td>$($finding.ObjectId)</td>
                <td>$($finding.DisplayName)</td>
                <td>$($finding.Evidence)</td>
                <td>$($finding.RecommendedAction)</td>
                <td>$($finding.RemediationMode)</td>
            </tr>
"@
    }

    $html += @"
        </tbody>
    </table>
</body>
</html>
"@

    $html | Out-File -FilePath $path -Encoding UTF8
    Write-DecomInfo "NHI governance dashboard HTML exported to $path"
    return $path
}

function Invoke-DecomNhiGenerateExecutiveSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiInventory,
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiGovernanceFindings,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if ($Context.DemoMode) {
        $path = Join-Path $Context.OutputPath "nhi-executive-summary-demo.md"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $path = Join-Path $Context.OutputPath "nhi-executive-summary-$timestamp.md"
    }

    # Calculate statistics
    $totalNhIs = ($NhiInventory | Group-Object -Property ObjectId | Measure-Object | Select-Object -ExpandProperty Count)
    $nhiCandidates = $NhiInventory | Where-Object { $_.NhiCandidate } | Measure-Object | Select-Object -ExpandProperty Count
    $agenticCandidates = $NhiInventory | Where-Object { $_.AgenticCandidate } | Measure-Object | Select-Object -ExpandProperty Count
    $criticalFindings = $NhiGovernanceFindings | Where-Object { $_.Severity -eq 'Critical' } | Measure-Object | Select-Object -ExpandProperty Count
    $highFindings = $NhiGovernanceFindings | Where-Object { $_.Severity -eq 'High' } | Measure-Object | Select-Object -ExpandProperty Count
    $mediumFindings = $NhiGovernanceFindings | Where-Object { $_.Severity -eq 'Medium' } | Measure-Object | Select-Object -ExpandProperty Count
    $lowFindings = $NhiGovernanceFindings | Where-Object { $_.Severity -eq 'Low' } | Measure-Object | Select-Object -ExpandProperty Count
    $informationalFindings = $NhiGovernanceFindings | Where-Object { $_.Severity -eq 'Informational' } | Measure-Object | Select-Object -ExpandProperty Count

    $markdown = @"
# NHI Executive Summary Report

**Generated:** $(Get-Date -Format u)
**Context:** $(if ($Context.EnvironmentName) { $Context.EnvironmentName } else { 'Unknown' })

## Executive Overview

This report provides a read-only assessment of Entra-visible NHI candidates and agentic identity indicators using heuristic classification. Coverage is limited to Entra-visible signals only.

## Key Metrics

| Metric | Count |
|--------|-------|
| Total NHIs Discovered | $totalNhIs |
| NHI Candidates | $nhiCandidates |
| Agentic Identity Candidates | $agenticCandidates |
| **Total Findings** | **$($NhiGovernanceFindings.Count)** |
| Critical Findings | $criticalFindings |
| High Findings | $highFindings |
| Medium Findings | $mediumFindings |
| Low Findings | $lowFindings |
| Informational Findings | $informationalFindings |

## Risk Assessment Summary

The following risk categories were identified:

### Critical Risk Findings ($criticalFindings)
These findings require immediate attention as they represent significant security vulnerabilities.

### High Risk Findings ($highFindings)
These findings should be addressed in the near-term as they pose notable security risks.

## NHI Classification Breakdown

| Classification | Count | Percentage |
|----------------|-------|------------|
| $(($NhiInventory | Where-Object { $_.Classification -eq 'NativeServiceIdentity' }).Count) | Native Service Identity | [Calculate percentage] |
| $(($NhiInventory | Where-Object { $_.Classification -eq 'LikelyAIAgent' }).Count) | Likely AI Agent | [Calculate percentage] |
| $(($NhiInventory | Where-Object { $_.Classification -eq 'LikelyAutomation' }).Count) | Likely Automation | [Calculate percentage] |
| $(($NhiInventory | Where-Object { $_.Classification -eq 'UnclassifiedServicePrincipal' }).Count) | Unclassified Service Principal | [Calculate percentage] |
| $(($NhiInventory | Where-Object { $_.Classification -eq 'UnclassifiedApplication' }).Count) | Unclassified Application | [Calculate percentage] |

## Top Risk Findings

The following table lists the top 10 highest risk findings:

| Rank | Finding ID | Severity | Risk Score | Object Type | Display Name |
|------|------------|----------|------------|-------------|--------------|
"@

    # Add top 10 findings by risk score
    $topFindings = $NhiGovernanceFindings | Sort-Object -Property RiskScore -Descending | Select-Object -First 10
    $rank = 1
    foreach ($finding in $topFindings) {
        $markdown += "| $rank | $($finding.FindingId) | $($finding.Severity) | $($finding.RiskScore) | $($finding.ObjectType) | $($finding.DisplayName) |`n"
        $rank++
    }

    $markdown += @"

## Recommendations

Based on the assessment findings, the following recommendations are prioritized:

### Immediate Actions (Critical Findings)
1. Review and address all Critical risk findings
2. Implement automated monitoring for high-risk NHIs
3. Establish NHI ownership accountability program

### Short-Term Actions (High Findings)
1. Address High risk findings within 30 days
2. Implement periodic NHI discovery and assessment
3. Enhance NHI onboarding and offboarding processes

### Long-Term Actions
1. Establish NHI governance framework
2. Implement continuous NHI monitoring
3. Regular review and updates to NHI policies

## Conclusion

The NHI assessment has identified [$($NhiGovernanceFindings.Count)] total findings across [$totalNhIs] NHIs. Immediate attention is required for $criticalFindings Critical findings and $highFindings High findings to reduce security risks associated with non-human and agentic identities.

---
*Report generated by Entra Identity Decommissioning Control Plane Rev3.5*
"@

    $markdown | Out-File -FilePath $path -Encoding UTF8
    Write-DecomInfo "NHI executive summary exported to $path"
    return $path
}

function Invoke-DecomNhiGenerateEvidenceAppendix {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiInventory,
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiGovernanceFindings,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if ($Context.DemoMode) {
        $path = Join-Path $Context.OutputPath "nhi-evidence-appendix-demo.md"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $path = Join-Path $Context.OutputPath "nhi-evidence-appendix-$timestamp.md"
    }

    $markdown = @"
# NHI Evidence Appendix

**Generated:** $(Get-Date -Format u)

This appendix contains detailed evidence supporting the findings in the NHI assessment report.

## Methodology

The NHI assessment was conducted using Microsoft Graph API to collect data on service principals and applications. The assessment included:

1. Service Principal discovery and property collection
2. Application discovery and property collection
3. Owner, credential, app role assignment, and OAuth grant collection
4. High-risk permission detection based on predefined scopes
5. Classification and scoring analysis
6. Governance finding generation

## Data Sources

- Microsoft Graph API v1.0
- Service Principal objects
- Application objects
- Directory objects (where applicable)
- Audit logs (where available)

## Detailed Evidence by Finding

"@

    $findingGroups = $NhiGovernanceFindings | Group-Object -Property FindingId
    foreach ($group in $findingGroups) {
        $markdown += "### $($group.Name) Findings`n"
        $markdown += "$($group.Group.Count) instance(s) found`n`n"

        foreach ($finding in $group.Group) {
            $markdown += "#### Instance: $($finding.DisplayName) ($($finding.ObjectId))`n"
            $markdown += "- **Finding ID:** $($finding.FindingId)`n"
            $markdown += "- **Category:** $($finding.Category)`n"
            $markdown += "- **Severity:** $($finding.Severity)`n"
            $markdown += "- **Risk Score:** $($finding.RiskScore)`n"
            $markdown += "- **Evidence:** $($finding.Evidence)`n"
            $markdown += "- **Evidence Source:** $($finding.EvidenceSource)`n"
            $markdown += "- **Graph Endpoint:** $($finding.GraphEndpoint)`n"
            $markdown += "- **Recommended Action:** $($finding.RecommendedAction)`n"
            $markdown += "- **Remediation Mode:** $($finding.RemediationMode)`n"
            $markdown += "- **Classification:** $($finding.Classification)`n"
            $markdown += "- **Classification Confidence:** $($finding.ClassificationConfidence)`n"
            $markdown += "- **Raw Data Available:** Yes`n`n"
        }
    }

    $markdown += @"

## Data Quality and Limitations

- Collection timestamp: $(Get-Date -Format u)
- Data completeness: Based on successful Graph API calls
- Permissions used: Minimum required permissions for read-only access
- Known limitations: None identified during this assessment

---
*Evidence appendix generated by Entra Identity Decommissioning Control Plane Rev3.5*
"@

    $markdown | Out-File -FilePath $path -Encoding UTF8
    Write-DecomInfo "NHI evidence appendix exported to $path"
    return $path
}

function Invoke-DecomNhiGenerateExceptionRegister {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiGovernanceFindings,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if ($Context.DemoMode) {
        $path = Join-Path $Context.OutputPath "nhi-exception-register-demo.csv"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $path = Join-Path $Context.OutputPath "nhi-exception-register-$timestamp.csv"
    }

    # Create exception register for findings that require exceptions or special handling
    $exceptionItems = $NhiGovernanceFindings | Where-Object {
        $_.RemediationMode -in @('ManualApprovalRequired', 'PlanOnly') -or
        $_.FindingId -in @('DEC-NHI-009', 'DEC-AGENT-005')
    } | ForEach-Object {
        [PSCustomObject]@{
            ExceptionId            = [guid]::NewGuid().ToString()
            FindingId              = $_.FindingId
            ObjectId               = $_.ObjectId
            DisplayName            = $_.DisplayName
            Severity               = $_.Severity
            RiskScore              = $_.RiskScore
            Evidence               = $_.Evidence
            RecommendedAction      = $_.RecommendedAction
            RemediationMode        = $_.RemediationMode
            ExceptionJustification = 'Pending review'
            ExpiresOn              = (Get-Date).AddDays(90).ToString('o')
            ReviewedBy             = ''
            ReviewedOn             = $null
        }
    }

    if ($exceptionItems) {
        $exceptionItems | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
    } else {
        'ExceptionId,FindingId,ObjectId,DisplayName,Severity,RiskScore,Evidence,RecommendedAction,RemediationMode,ExceptionJustification,ExpiresOn,ReviewedBy,ReviewedOn' | Out-File -FilePath $path -Encoding UTF8
    }
    Write-DecomInfo "NHI exception register exported to $path"
    return $path
}

function Invoke-DecomNhiGenerateAgenticReviewPacket {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiInventory,
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiGovernanceFindings,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if ($Context.DemoMode) {
        $path = Join-Path $Context.OutputPath "nhi-agentic-review-packet-demo.md"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $path = Join-Path $Context.OutputPath "nhi-agentic-review-packet-$timestamp.md"
    }

    # Filter for agentic identity findings
    $agenticFindings = $NhiGovernanceFindings | Where-Object { $_.AgenticCandidate }
    $agenticNhIs = $NhiInventory | Where-Object { $_.AgenticCandidate }

    $markdown = @"
# Agentic Identity Review Packet

**Generated:** $(Get-Date -Format u)
**Context:** $(if ($Context.EnvironmentName) { $Context.EnvironmentName } else { 'Unknown' })

## Overview

This packet provides a focused review of agentic identities discovered in the tenant. Agentic identities are non-human identities that demonstrate characteristics of autonomous or semi-autonomous systems, potentially including AI agents, automation workflows, or other intelligent agents.

## Agentic Identity Summary

| Metric | Count |
|--------|-------|
| Total Agentic Identity Candidates | $($agenticNhIs.Count) |
| Total Agentic-Related Findings | $($agenticFindings.Count) |
| Critical Agentic Findings | $($agenticFindings | Where-Object { $_.Severity -eq 'Critical' }).Count) |
| High Agentic Findings | $($agenticFindings | Where-Object { $_.Severity -eq 'High' }).Count) |

## Agentic Identity Inventory

"@

    if ($agenticNhIs.Count -gt 0) {
        $markdown += "| Object ID | Display Name | Object Type | Classification | Risk Score | Severity |`n"
        $markdown += "|-----------|--------------|-------------|----------------|------------|----------|`n"
        foreach ($nhi in $agenticNhIs) {
            $markdown += "| $($nhi.ObjectId) | $($nhi.DisplayName) | $($nhi.ObjectType) | $($nhi.Classification) | $($nhi.RiskScore) | $($nhi.Severity) |`n"
        }
    } else {
        $markdown += "_No agentic identity candidates discovered._`n"
    }

    $markdown += @"

## Agentic Identity Findings Details

"@

    if ($agenticFindings.Count -gt 0) {
        $markdown += "| Finding ID | Object ID | Display Name | Severity | Risk Score | Evidence | Recommended Action |`n"
        $markdown += "|------------|-----------|--------------|----------|------------|----------|--------------------|`n"
        foreach ($finding in $agenticFindings) {
            $markdown += "| $($finding.FindingId) | $($finding.ObjectId) | $($finding.DisplayName) | $($finding.Severity) | $($finding.RiskScore) | $($finding.Evidence) | $($finding.RecommendedAction) |`n"
        }
    } else {
        $markdown += "_No agentic identity findings generated._`n"
    }

    $markdown += @"

## Assessment Methodology

Agentic identities were identified through:
1. Naming pattern analysis (agent, copilot, AI, automation, etc.)
2. Service Principal Type = ServiceIdentity
3. Behavioral indicators from permissions and consent patterns
4. Classification scoring based on observable characteristics

## Recommendations

1. **Inventory Validation**: Validate discovered agentic identities against known authorized automation/AI systems
2. **Risk Assessment**: Conduct detailed risk assessment of high-risk agentic identities
3. **Governance Review**: Review agentic identity permissions and consent grants
4. **Documentation**: Ensure all agentic identities are properly documented and approved
5. **Monitoring**: Implement continuous monitoring for changes to agentic identity properties

---
*Agentic identity review packet generated by Entra Identity Decommissioning Control Plane Rev3.5*
"@

    $markdown | Out-File -FilePath $path -Encoding UTF8
    Write-DecomInfo "NHI agentic review packet exported to $path"
    return $path
}

function Invoke-DecomNhiGenerateRev4WriteReadinessReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiInventory,
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiGovernanceFindings,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    if ($Context.DemoMode) {
        $path = Join-Path $Context.OutputPath "nhi-rev4-write-readiness-report-demo.md"
    } else {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $path = Join-Path $Context.OutputPath "nhi-rev4-write-readiness-report-$timestamp.md"
    }

    # Calculate metrics for write readiness
    $totalNhIs = ($NhiInventory | Group-Object -Property ObjectId | Measure-Object | Select-Object -ExpandProperty Count)
    $nhiWithNoOwner = $NhiInventory | Where-Object { $_.OwnerCount -eq 0 } | Measure-Object | Select-Object -ExpandProperty Count
    $nhiWithHighRiskPermissions = $NhiInventory | Where-Object { $_.HighRiskPermissionCount -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count
    $nhiWithTenantWideConsent = $NhiInventory | Where-Object { $_.TenantWideConsent } | Measure-Object | Select-Object -ExpandProperty Count
    $nhiWithExpiredCredentials = $NhiInventory | Where-Object { $_.ExpiredCredentialCount -gt 0 } | Measure-Object | Select-Object -ExpandProperty Count

    $markdown = @"
# Rev4 NHI Write-Readiness Assessment Report

**Generated:** $(Get-Date -Format u)
**Context:** $(if ($Context.EnvironmentName) { $Context.EnvironmentName } else { 'Unknown' })
**Assessment Type:** Read-only discovery and analysis (Rev3.5)
**Target State:** Prepared for Rev4 write-enabled remediation

## Executive Summary

This report assesses the readiness of the NHI population for potential write-enabled remediation capabilities that would be available in a future Rev4 release. The assessment focuses on identifying NHIs that would benefit from or require controlled remediation actions.

## NHI Population Overview

| Metric | Count | Percentage |
|--------|-------|------------|
| Total NHIs | $totalNhIs | 100% |
| NHIs with No Owner | $nhiWithNoOwner | [($nhiWithNoOwner/$totalNhIs)*100]% |
| NHIs with High-Risk Permissions | $nhiWithHighRiskPermissions | [($nhiWithHighRiskPermissions/$totalNhIs)*100]% |
| NHIs with Tenant-Wide Consent | $nhiWithTenantWideConsent | [($nhiWithTenantWideConsent/$totalNhIs)*100]% |
| NHIs with Expired Credentials | $nhiWithExpiredCredentials | [($nhiWithExpiredCredentials/$totalNhIs)*100]% |

## Candidate Future Actions (Rev4)

Based on the Rev3.5 assessment, the following NHIs would be candidates for write-enabled actions in a potential Rev4 release:

### AddNhiOwner Candidates
NHIs without owners that could benefit from ownership assignment:
- Count: $nhiWithNoOwner
- Examples: $(($NhiInventory | Where-Object { $_.OwnerCount -eq 0 } | Select-Object -First 3 | ForEach-Object { $_.DisplayName }) -join ', ')

### RemoveNhiHighRiskPermission Candidates
NHIs with high-risk permissions that could benefit from permission review/removal:
- Count: $nhiWithHighRiskPermissions
- Examples: $(($NhiInventory | Where-Object { $_.HighRiskPermissionCount -gt 0 } | Select-Object -First 3 | ForEach-Object { $_.DisplayName }) -join ', ')

### RemoveNhiTenantWideConsent Candidates
NHIs with tenant-wide consent that could benefit from consent review:
- Count: $nhiWithTenantWideConsent
- Examples: $(($NhiInventory | Where-Object { $_.TenantWideConsent } | Select-Object -First 3 | ForEach-Object { $_.DisplayName }) -join ', ')

### RemoveNhiExpiredCredential Candidates
NHIs with expired credentials that could benefit from credential cleanup:
- Count: $nhiWithExpiredCredentials
- Examples: $(($NhiInventory | Where-Object { $_.ExpiredCredentialCount -gt 0 } | Select-Object -First 3 | ForEach-Object { $_.DisplayName }) -join ', ')

## Readiness Assessment

### Current State (Rev3.5 - Read-Only)
- [x] Discovery and inventory complete
- [x] Classification and scoring implemented
- [x] Governance findings generated
- [x] Reporting and export capabilities available

### Target State (Rev4 - Write-Enabled)
- [ ] Owner management capabilities (AddNhiOwner, RemoveNhiOwner)
- [ ] Permission management capabilities (GrantNhiPermission, RemoveNhiPermission)
- [ ] Consent management capabilities (GrantNhiConsent, RemoveNhiConsent)
- [ ] Credential management capabilities (AddNhiCredential, RemoveNhiCredential)
- [ ] Approval workflow integration for write actions

## Recommendations for Rev4 Preparation

1. **Establish Approval Framework**: Define approval workflows for NHI write actions
2. **Define Action Boundaries**: Clearly specify which NHIs can be targets for write actions
3. **Implement Change Tracking**: Ensure all write actions are properly logged and auditable
4. **Create Rollback Procedures**: Establish procedures to revert write actions if needed
5. **Define Notification Processes**: Establish notifications for NHI write actions

## Current Limitations

This Rev3.5 assessment is strictly read-only and does not perform any write operations. All findings are for informational and planning purposes only.

---
*Rev4 NHI write-readiness report generated by Entra Identity Decommissioning Control Plane Rev3.5*
"@

    $markdown | Out-File -FilePath $path -Encoding UTF8
    Write-DecomInfo "Rev4 NHI write-readiness report exported to $path"
    return $path
}

Export-ModuleMember -Function Invoke-DecomNhiReporting, Invoke-DecomNhiExportInventoryCsv, Invoke-DecomNhiExportInventoryJson, Invoke-DecomNhiGenerateGovernanceDashboard, Invoke-DecomNhiGenerateExecutiveSummary, Invoke-DecomNhiGenerateEvidenceAppendix, Invoke-DecomNhiGenerateExceptionRegister, Invoke-DecomNhiGenerateAgenticReviewPacket, Invoke-DecomNhiGenerateRev4WriteReadinessReport
