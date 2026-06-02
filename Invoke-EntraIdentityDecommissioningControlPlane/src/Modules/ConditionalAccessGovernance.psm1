#Requires -Version 5.1

$script:CaFindingIds = [System.Collections.Generic.HashSet[string]] @(
    'DEC-CA-001','DEC-CA-002','DEC-CA-003','DEC-CA-004'
)

function New-DecomCaExclusionGovernanceModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $false)]
        [object[]]$Findings = @()
    )

    $caPolicies       = [System.Collections.Generic.List[object]]::new()
    $exclusions       = [System.Collections.Generic.List[object]]::new()
    $exceptionRegister= [System.Collections.Generic.List[object]]::new()
    $remediationDesign= [System.Collections.Generic.List[object]]::new()

    $policyCount        = 0
    $exclusionGroupCount= 0
    $exclusionCount     = 0
    $lackReviewCount    = 0
    $conflictCount      = 0
    $highRiskCount      = 0
    $manualRemCount     = 0
    $rev33CandCount     = 0

    $policySet = [System.Collections.Generic.HashSet[string]]::new()

    foreach ($f in $Findings) {
        $fid = $f.FindingId
        if (-not $script:CaFindingIds.Contains($fid)) { continue }

        $policyId    = if ($f.PolicyId)    { $f.PolicyId }    else { '' }
        $policyName  = if ($f.PolicyName)  { $f.PolicyName }  elseif ($f.DisplayName) { $f.DisplayName } else { 'Unknown Policy' }
        $groupId     = if ($f.GroupId)     { $f.GroupId }     else { '' }
        $groupName   = if ($f.GroupName)   { $f.GroupName }   else { '' }
        $target      = if ($f.Target)      { $f.Target }      else { '' }
        $isHighRisk  = ($f.RiskLevel -eq 'High' -or $f.HighRisk -eq $true)
        $hasReview   = ($f.HasReviewEvidence -eq $true -or $f.ReviewEvidenceDate -ne $null)
        $isConflict  = ($f.ConflictingEvidence -eq $true)

        if ($policySet.Add($policyId)) { $policyCount++ }
        if ($groupId) { $exclusionGroupCount++ }
        $exclusionCount++

        if (-not $hasReview)  { $lackReviewCount++ }
        if ($isConflict)      { $conflictCount++ }
        if ($isHighRisk)      { $highRiskCount++ }

        $readiness = Get-DecomCaExclusionReadiness -Exclusion ([PSCustomObject]@{
            PolicyId              = $policyId
            PolicyName            = $policyName
            GroupId               = $groupId
            GroupName             = $groupName
            Target                = $target
            DisplayName           = $policyName
            FindingId             = $fid
            IsHighRisk            = $isHighRisk
            HasReviewEvidence     = $hasReview
            ConflictingEvidence   = $isConflict
            ReviewEvidenceDate    = $f.ReviewEvidenceDate
        })

        $exclusions.Add($readiness)

        if ($readiness.ReadinessStatus -eq 'ManualRemediationRequired') { $manualRemCount++ }
        if ($readiness.ReadinessStatus -eq 'Rev33WriteCandidate')        { $rev33CandCount++ }

        if (-not $hasReview -or $isConflict -or $isHighRisk) {
            $remediationDesign.Add([PSCustomObject]@{
                PolicyId        = $policyId
                PolicyName      = $policyName
                GroupId         = $groupId
                FindingId       = $fid
                ReadinessStatus = $readiness.ReadinessStatus
                DesignAction    = $readiness.ReadinessReason
                Priority        = if ($isHighRisk) { 'High' } elseif (-not $hasReview) { 'Medium' } else { 'Low' }
            })
        }

        if ($policyId -and -not ($caPolicies | Where-Object { $_.PolicyId -eq $policyId })) {
            $caPolicies.Add([PSCustomObject]@{
                PolicyId         = $policyId
                PolicyName       = $policyName
                ExclusionCount   = ($Findings | Where-Object { $_.PolicyId -eq $policyId }).Count
                HasHighRisk      = $isHighRisk
                HasReviewGap     = -not $hasReview
            })
        }
    }

    return [PSCustomObject]@{
        SchemaVersion                       = '3.2'
        ToolVersion                         = $Context.ToolVersion
        GeneratedUtc                        = (Get-Date).ToUniversalTime().ToString('o')
        ClientName                          = $Context.ClientName
        EngagementId                        = $Context.EngagementId
        Assessor                            = $Context.Assessor
        TenantId                            = if ($Context.TenantId) { $Context.TenantId } else { '' }
        CAPolicyCount                       = $policyCount
        ExclusionGroupCount                 = $exclusionGroupCount
        ExclusionCount                      = $exclusionCount
        ExclusionsLackingReviewEvidenceCount= $lackReviewCount
        ConflictingReviewEvidenceCount      = $conflictCount
        HighRiskExclusionCount              = $highRiskCount
        RecommendedManualRemediationCount   = $manualRemCount
        Rev3WriteReadinessCandidatesCount   = $rev33CandCount
        CAPolicies                          = $caPolicies.ToArray()
        ExclusionGroups                     = @()
        Exclusions                          = $exclusions.ToArray()
        ExceptionRegister                   = $exceptionRegister.ToArray()
        RemediationDesign                   = $remediationDesign.ToArray()
    }
}

function Get-DecomCaExclusionReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Exclusion
    )

    $policyId    = $Exclusion.PolicyId
    $policyName  = $Exclusion.PolicyName
    $groupId     = $Exclusion.GroupId
    $target      = $Exclusion.Target
    $displayName = $Exclusion.DisplayName
    $findingId   = $Exclusion.FindingId
    $isHighRisk  = $Exclusion.IsHighRisk -eq $true
    $hasReview   = $Exclusion.HasReviewEvidence -eq $true
    $isConflict  = $Exclusion.ConflictingEvidence -eq $true

    switch ($findingId) {
        'DEC-CA-001' {
            $status = if ($isHighRisk) { 'HighRiskExclusionManualRequired' } else { 'ManualRemediationRequired' }
            $reason = 'CA exclusion lacks owner group. Manual review and group assignment required. No automated removal in Rev3.2.'
        }
        'DEC-CA-002' {
            if ($isConflict) {
                $status = 'ConflictingReviewEvidence'
                $reason = 'CA exclusion has conflicting review evidence. Reconcile review evidence before scheduling removal.'
            } elseif (-not $hasReview) {
                $status = 'ManualRemediationRequired'
                $reason = 'CA exclusion lacks review evidence. Access review required before any removal action.'
            } else {
                $status = 'Rev33WriteCandidate'
                $reason = 'CA exclusion has review evidence. Candidate for RemoveCAExclusionGroupMember in Rev3.3 after design approval.'
            }
        }
        'DEC-CA-003' {
            if ($isHighRisk) {
                $status = 'HighRiskExclusionManualRequired'
                $reason = 'High-risk CA exclusion pattern identified. Manual escalation required before any remediation.'
            } else {
                $status = 'ManualRemediationRequired'
                $reason = 'CA exclusion group member requires manual review and evidence before any removal.'
            }
        }
        'DEC-CA-004' {
            $status = 'ReviewRequired'
            $reason = 'CA exclusion requires periodic access review. Schedule review to determine remediation path.'
        }
        default {
            $status = 'Deferred'
            $reason = 'FindingId not recognized for CA exclusion readiness. Manual review required.'
        }
    }

    return [PSCustomObject]@{
        PolicyId            = $policyId
        PolicyName          = $policyName
        GroupId             = $groupId
        Target              = $target
        DisplayName         = $displayName
        FindingId           = $findingId
        IsHighRisk          = $isHighRisk
        HasReviewEvidence   = $hasReview
        ConflictingEvidence = $isConflict
        ReadinessStatus     = $status
        ReadinessReason     = $reason
    }
}

function Export-DecomCaExclusionGovernanceDashboardHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $client   = [System.Net.WebUtility]::HtmlEncode($Model.ClientName)
    $engId    = [System.Net.WebUtility]::HtmlEncode($Model.EngagementId)
    $assessor = [System.Net.WebUtility]::HtmlEncode($Model.Assessor)
    $ts       = $Model.GeneratedUtc

    $rowsSb = [System.Text.StringBuilder]::new()
    foreach ($e in $Model.Exclusions) {
        $pn   = [System.Net.WebUtility]::HtmlEncode($e.PolicyName)
        $fid  = [System.Net.WebUtility]::HtmlEncode($e.FindingId)
        $gid  = [System.Net.WebUtility]::HtmlEncode($e.GroupId)
        $rs   = [System.Net.WebUtility]::HtmlEncode($e.ReadinessStatus)
        $rr   = [System.Net.WebUtility]::HtmlEncode($e.ReadinessReason)
        $hr   = if ($e.IsHighRisk) { 'Yes' } else { 'No' }
        $rev  = if ($e.HasReviewEvidence) { 'Yes' } else { 'No' }
        $badge = switch ($e.ReadinessStatus) {
            'Rev33WriteCandidate'             { 'badge-ready' }
            'ManualRemediationRequired'       { 'badge-plan' }
            'HighRiskExclusionManualRequired' { 'badge-blocked' }
            'ConflictingReviewEvidence'       { 'badge-blocked' }
            default                           { 'badge-plan' }
        }
        $null = $rowsSb.Append("<tr><td>$pn</td><td>$fid</td><td>$gid</td><td>$hr</td><td>$rev</td><td><span class='badge $badge'>$rs</span></td><td>$rr</td></tr>")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Conditional Access Exclusion Governance Dashboard — $client</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f4f6f9;color:#1a1a2e}
.header{background:#1a1a2e;color:#fff;padding:24px 32px}
.header h1{margin:0;font-size:1.5rem}
.header p{margin:4px 0 0;font-size:.85rem;opacity:.8}
.cards{display:flex;flex-wrap:wrap;gap:16px;padding:24px 32px}
.card{background:#fff;border-radius:8px;padding:20px 24px;min-width:160px;box-shadow:0 1px 4px rgba(0,0,0,.1)}
.card .num{font-size:2rem;font-weight:700;color:#1a1a2e}
.card .lbl{font-size:.8rem;color:#666;margin-top:4px}
.section{padding:0 32px 32px}
table{width:100%;border-collapse:collapse;background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.1)}
th{background:#1a1a2e;color:#fff;padding:10px 12px;text-align:left;font-size:.8rem}
td{padding:10px 12px;border-bottom:1px solid #eee;font-size:.82rem;vertical-align:top}
tr:last-child td{border-bottom:none}
.badge{padding:2px 8px;border-radius:12px;font-size:.75rem;font-weight:600}
.badge-ready{background:#d4edda;color:#155724}
.badge-plan{background:#fff3cd;color:#856404}
.badge-blocked{background:#f8d7da;color:#721c24}
.notice{background:#fff3cd;border-left:4px solid #ffc107;padding:12px 16px;margin:0 32px 24px;border-radius:4px;font-size:.85rem}
footer{padding:16px 32px;font-size:.75rem;color:#888}
</style>
</head>
<body>
<div class="header">
  <h1>Conditional Access Exclusion Governance Dashboard</h1>
  <p>Client: $client | Engagement: $engId | Assessor: $assessor | Generated: $ts | Schema: $($Model.SchemaVersion)</p>
</div>
<div class="notice">
  <strong>Read-Only Assessment:</strong> Rev3.2 does not perform CA policy mutation or exclusion group membership removal.
  CA exclusion remediation requires manual review and is a candidate for Rev3.3 design.
</div>
<div class="cards">
  <div class="card"><div class="num">$($Model.CAPolicyCount)</div><div class="lbl">CA Policies</div></div>
  <div class="card"><div class="num">$($Model.ExclusionCount)</div><div class="lbl">Exclusions</div></div>
  <div class="card"><div class="num">$($Model.HighRiskExclusionCount)</div><div class="lbl">High-Risk Exclusions</div></div>
  <div class="card"><div class="num">$($Model.ExclusionsLackingReviewEvidenceCount)</div><div class="lbl">Lacking Review Evidence</div></div>
  <div class="card"><div class="num">$($Model.ConflictingReviewEvidenceCount)</div><div class="lbl">Conflicting Evidence</div></div>
  <div class="card"><div class="num">$($Model.Rev3WriteReadinessCandidatesCount)</div><div class="lbl">Rev3.3 Candidates</div></div>
</div>
<div class="section">
  <h2>CA Exclusion Readiness</h2>
  <table>
    <tr><th>Policy</th><th>Finding</th><th>Group ID</th><th>High Risk</th><th>Review Evidence</th><th>Status</th><th>Reason</th></tr>
    $($rowsSb.ToString())
  </table>
</div>
<footer>Rev3.2 Conditional Access Exclusion Governance Pack — Read-Only Assessment Output. No CA policy mutation performed.</footer>
</body>
</html>
"@
    $html | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "CA exclusion governance dashboard HTML: $Path"
}

function Export-DecomCaExclusionReadinessJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $payload = [PSCustomObject]@{
        SchemaVersion                        = $Model.SchemaVersion
        ToolVersion                          = $Model.ToolVersion
        GeneratedUtc                         = $Model.GeneratedUtc
        ClientName                           = $Model.ClientName
        EngagementId                         = $Model.EngagementId
        Assessor                             = $Model.Assessor
        TenantId                             = $Model.TenantId
        CAPolicyCount                        = $Model.CAPolicyCount
        ExclusionGroupCount                  = $Model.ExclusionGroupCount
        ExclusionCount                       = $Model.ExclusionCount
        ExclusionsLackingReviewEvidenceCount = $Model.ExclusionsLackingReviewEvidenceCount
        ConflictingReviewEvidenceCount       = $Model.ConflictingReviewEvidenceCount
        HighRiskExclusionCount               = $Model.HighRiskExclusionCount
        RecommendedManualRemediationCount    = $Model.RecommendedManualRemediationCount
        Rev3WriteReadinessCandidatesCount    = $Model.Rev3WriteReadinessCandidatesCount
        CAPolicies                           = $Model.CAPolicies
        Exclusions                           = $Model.Exclusions
        ExceptionRegister                    = $Model.ExceptionRegister
        RemediationDesign                    = $Model.RemediationDesign
    }
    $payload | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "CA exclusion readiness JSON: $Path"
}

function Export-DecomCaExclusionReadinessCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Model.Exclusions -and $Model.Exclusions.Count -gt 0) {
        $Model.Exclusions | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    } else {
        [PSCustomObject]@{
            PolicyId            = ''
            PolicyName          = ''
            GroupId             = ''
            FindingId           = ''
            IsHighRisk          = $false
            HasReviewEvidence   = $false
            ConflictingEvidence = $false
            ReadinessStatus     = ''
            ReadinessReason     = ''
        } | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
    Write-DecomOk "CA exclusion readiness CSV: $Path"
}

function Export-DecomCaExclusionOwnerReviewPacketMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Conditional Access Exclusion Owner Review Packet")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Client:** $($Model.ClientName)")
    $null = $sb.AppendLine("**Engagement:** $($Model.EngagementId)")
    $null = $sb.AppendLine("**Assessor:** $($Model.Assessor)")
    $null = $sb.AppendLine("**Generated (UTC):** $($Model.GeneratedUtc)")
    $null = $sb.AppendLine("**Schema Version:** $($Model.SchemaVersion)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("> **Important:** Rev3.2 does not perform CA policy mutation or CA exclusion group membership removal.")
    $null = $sb.AppendLine("> All CA exclusion remediation requires manual review and approval.")
    $null = $sb.AppendLine("> Automated removal is a candidate for Rev3.3 after design approval.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Metric | Count |")
    $null = $sb.AppendLine("|---|---|")
    $null = $sb.AppendLine("| CA Policies with Exclusions | $($Model.CAPolicyCount) |")
    $null = $sb.AppendLine("| Total Exclusions | $($Model.ExclusionCount) |")
    $null = $sb.AppendLine("| High-Risk Exclusions | $($Model.HighRiskExclusionCount) |")
    $null = $sb.AppendLine("| Lacking Review Evidence | $($Model.ExclusionsLackingReviewEvidenceCount) |")
    $null = $sb.AppendLine("| Conflicting Review Evidence | $($Model.ConflictingReviewEvidenceCount) |")
    $null = $sb.AppendLine("| Rev3.3 Write Candidates | $($Model.Rev3WriteReadinessCandidatesCount) |")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Exclusions Requiring Owner Review")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Policy | Finding | Group ID | High Risk | Review Evidence | Status |")
    $null = $sb.AppendLine("|---|---|---|---|---|---|")

    foreach ($e in $Model.Exclusions) {
        $hr  = if ($e.IsHighRisk) { 'Yes' } else { 'No' }
        $rev = if ($e.HasReviewEvidence) { 'Yes' } else { 'No' }
        $null = $sb.AppendLine("| $($e.PolicyName) | $($e.FindingId) | $($e.GroupId) | $hr | $rev | $($e.ReadinessStatus) |")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Remediation Design Recommendations")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Policy | Priority | Action |")
    $null = $sb.AppendLine("|---|---|---|")

    foreach ($d in $Model.RemediationDesign) {
        $null = $sb.AppendLine("| $($d.PolicyName) | $($d.Priority) | $($d.DesignAction) |")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Owner Reviewer Signature")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("By signing below, the reviewer confirms that CA exclusion data has been reviewed")
    $null = $sb.AppendLine("and that the remediation design recommendations are approved for Rev3.3 planning.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Name:** ___________________________")
    $null = $sb.AppendLine("**Title:** ___________________________")
    $null = $sb.AppendLine("**Date:** ___________________________")
    $null = $sb.AppendLine("**Signature:** ___________________________")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("*Rev3.2 Conditional Access Exclusion Governance Pack — Read-Only Assessment Output*")

    $sb.ToString() | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "CA exclusion owner review packet Markdown: $Path"
}

function Export-DecomCaExclusionOwnerReviewPacketHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $client   = [System.Net.WebUtility]::HtmlEncode($Model.ClientName)
    $engId    = [System.Net.WebUtility]::HtmlEncode($Model.EngagementId)
    $assessor = [System.Net.WebUtility]::HtmlEncode($Model.Assessor)
    $ts       = $Model.GeneratedUtc

    $rowsSb = [System.Text.StringBuilder]::new()
    foreach ($e in $Model.Exclusions) {
        $pn  = [System.Net.WebUtility]::HtmlEncode($e.PolicyName)
        $fid = [System.Net.WebUtility]::HtmlEncode($e.FindingId)
        $gid = [System.Net.WebUtility]::HtmlEncode($e.GroupId)
        $hr  = if ($e.IsHighRisk) { '<span style="color:#721c24;font-weight:600">Yes</span>' } else { 'No' }
        $rev = if ($e.HasReviewEvidence) { '<span style="color:#155724">Yes</span>' } else { '<span style="color:#721c24">No</span>' }
        $rs  = [System.Net.WebUtility]::HtmlEncode($e.ReadinessStatus)
        $null = $rowsSb.Append("<tr><td>$pn</td><td>$fid</td><td>$gid</td><td>$hr</td><td>$rev</td><td>$rs</td></tr>")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>CA Exclusion Owner Review Packet — $client</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f4f6f9;color:#1a1a2e}
.header{background:#1a1a2e;color:#fff;padding:24px 32px}
.header h1{margin:0;font-size:1.4rem}
.header p{margin:4px 0 0;font-size:.8rem;opacity:.8}
.notice{background:#fff3cd;border-left:4px solid #ffc107;padding:12px 16px;margin:24px 32px 0;border-radius:4px;font-size:.85rem}
.section{padding:24px 32px}
table{width:100%;border-collapse:collapse;background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.1);margin-bottom:24px}
th{background:#1a1a2e;color:#fff;padding:10px 12px;text-align:left;font-size:.8rem}
td{padding:10px 12px;border-bottom:1px solid #eee;font-size:.82rem}
tr:last-child td{border-bottom:none}
.sig-box{background:#fff;border-radius:8px;padding:24px;box-shadow:0 1px 4px rgba(0,0,0,.1)}
.sig-line{border-bottom:1px solid #333;margin-bottom:24px;padding-bottom:4px}
footer{padding:16px 32px;font-size:.75rem;color:#888}
</style>
</head>
<body>
<div class="header">
  <h1>CA Exclusion Owner Review Packet</h1>
  <p>Client: $client | Engagement: $engId | Assessor: $assessor | Generated: $ts</p>
</div>
<div class="notice">
  <strong>Read-Only:</strong> Rev3.2 does not perform CA policy mutation. All CA exclusion remediation requires manual review.
</div>
<div class="section">
  <h2>Exclusions Requiring Review</h2>
  <table>
    <tr><th>Policy</th><th>Finding</th><th>Group ID</th><th>High Risk</th><th>Review Evidence</th><th>Status</th></tr>
    $($rowsSb.ToString())
  </table>
  <h2>Owner Reviewer Signature</h2>
  <div class="sig-box">
    <p>By signing, the reviewer confirms that CA exclusion data has been reviewed and remediation design is approved for Rev3.3 planning.</p>
    <p class="sig-line">Name: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p>
    <p class="sig-line">Title: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p>
    <p class="sig-line">Date: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p>
    <p class="sig-line">Signature: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p>
  </div>
</div>
<footer>Rev3.2 Conditional Access Exclusion Governance Pack — Read-Only Assessment Output.</footer>
</body>
</html>
"@
    $html | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "CA exclusion owner review packet HTML: $Path"
}

function Export-DecomCaExclusionExceptionRegisterCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Model.ExceptionRegister -and $Model.ExceptionRegister.Count -gt 0) {
        $Model.ExceptionRegister | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    } else {
        [PSCustomObject]@{
            PolicyId        = ''
            PolicyName      = ''
            GroupId         = ''
            FindingId       = ''
            ExceptionReason = ''
            ExceptionUtc    = ''
        } | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
    Write-DecomOk "CA exclusion exception register CSV: $Path"
}

function Export-DecomCaExclusionRemediationDesignMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Conditional Access Exclusion Remediation Design")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Client:** $($Model.ClientName)")
    $null = $sb.AppendLine("**Engagement:** $($Model.EngagementId)")
    $null = $sb.AppendLine("**Assessor:** $($Model.Assessor)")
    $null = $sb.AppendLine("**Generated (UTC):** $($Model.GeneratedUtc)")
    $null = $sb.AppendLine("**Schema Version:** $($Model.SchemaVersion)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Rev3.2 Constraints")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("Rev3.2 is read-only for all CA exclusion governance. The following actions are NOT implemented:")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("- No CA policy mutation")
    $null = $sb.AppendLine("- No CA exclusion group member removal")
    $null = $sb.AppendLine("- No CA-policy write scopes are requested in Rev3.2")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("RemoveCAExclusionGroupMember is a Rev3.3 design candidate after QA approval.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Remediation Design Priorities")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Policy | Finding | Priority | Action |")
    $null = $sb.AppendLine("|---|---|---|---|")

    foreach ($d in ($Model.RemediationDesign | Sort-Object { if ($_.Priority -eq 'High') { 0 } elseif ($_.Priority -eq 'Medium') { 1 } else { 2 } })) {
        $null = $sb.AppendLine("| $($d.PolicyName) | $($d.FindingId) | $($d.Priority) | $($d.DesignAction) |")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Rev3.3 Write Candidates")
    $null = $sb.AppendLine("")

    $rev33 = @($Model.Exclusions | Where-Object { $_.ReadinessStatus -eq 'Rev33WriteCandidate' })
    if ($rev33.Count -gt 0) {
        $null = $sb.AppendLine("The following exclusions have review evidence and are candidates for RemoveCAExclusionGroupMember in Rev3.3:")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("| Policy | Group ID | Finding |")
        $null = $sb.AppendLine("|---|---|---|")
        foreach ($r in $rev33) {
            $null = $sb.AppendLine("| $($r.PolicyName) | $($r.GroupId) | $($r.FindingId) |")
        }
    } else {
        $null = $sb.AppendLine("No CA exclusions currently qualify as Rev3.3 write candidates.")
        $null = $sb.AppendLine("Address review evidence gaps to enable future automated remediation.")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Recommended Manual Checks")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("1. Validate access review evidence for all exclusions lacking review documentation.")
    $null = $sb.AppendLine("2. Escalate high-risk exclusions for immediate security review.")
    $null = $sb.AppendLine("3. Reconcile conflicting review evidence before scheduling removal.")
    $null = $sb.AppendLine("4. Schedule periodic exclusion reviews for all CA policies.")
    $null = $sb.AppendLine("5. Design Rev3.3 RemoveCAExclusionGroupMember flow after review evidence is complete.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("*Rev3.2 Conditional Access Exclusion Governance Pack — Read-Only Assessment Output*")

    $sb.ToString() | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "CA exclusion remediation design Markdown: $Path"
}
