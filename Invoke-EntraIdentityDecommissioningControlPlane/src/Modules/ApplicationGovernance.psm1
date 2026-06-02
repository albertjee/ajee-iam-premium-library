#Requires -Version 5.1

$script:OwnerFindingIds = [System.Collections.Generic.HashSet[string]] @(
    'DEC-APP-001','DEC-APP-002','DEC-APP-003','DEC-SPN-001'
)

function New-DecomApplicationGovernanceModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $false)]
        [object[]]$Findings = @()
    )

    $apps           = [System.Collections.Generic.List[object]]::new()
    $ownerReadiness = [System.Collections.Generic.List[object]]::new()
    $exceptions     = [System.Collections.Generic.List[object]]::new()

    $unownedCount          = 0
    $singleOwnerCount      = 0
    $disabledOwnerCount    = 0
    $disabledOnlyCount     = 0
    $spnNoOwnerCount       = 0
    $credNoOwnerCount      = 0
    $readyForApprovalCount = 0
    $planOnlyCount         = 0
    $exceptionCount        = 0

    foreach ($f in $Findings) {
        $fid = $f.FindingId
        if (-not $script:OwnerFindingIds.Contains($fid)) { continue }

        $isSPN = ($fid -eq 'DEC-SPN-001')
        $objectId    = if ($f.ObjectId)    { $f.ObjectId }    else { '' }
        $appId       = if ($f.AppId)       { $f.AppId }       else { '' }
        $displayName = if ($f.DisplayName) { $f.DisplayName } else { 'Unknown' }
        $ownerCount  = if ($null -ne $f.OwnerCount) { [int]$f.OwnerCount } else { 0 }
        $hasOwner    = $ownerCount -gt 0
        $isProtected = ($f.ProtectedObject -eq $true)

        if ($isProtected) {
            $exceptionCount++
            $exceptions.Add([PSCustomObject]@{
                FindingId    = $fid
                ObjectId     = $objectId
                DisplayName  = $displayName
                Reason       = 'ProtectedObject'
                ExceptionUtc = (Get-Date).ToUniversalTime().ToString('o')
            })
            continue
        }

        switch ($fid) {
            'DEC-APP-001' { $unownedCount++ }
            'DEC-APP-002' { $disabledOwnerCount++; $disabledOnlyCount++ }
            'DEC-APP-003' { $singleOwnerCount++ }
            'DEC-SPN-001' { $spnNoOwnerCount++ }
        }

        $hasCred = ($f.HasCredential -eq $true -or $f.CredentialCount -gt 0)
        if ($hasCred -and -not $hasOwner) { $credNoOwnerCount++ }

        $readiness = Get-DecomApplicationOwnerReadiness -Application ([PSCustomObject]@{
            ObjectId     = $objectId
            AppId        = $appId
            DisplayName  = $displayName
            FindingId    = $fid
            OwnerCount   = $ownerCount
            HasOwner     = $hasOwner
            IsSPN        = $isSPN
            ProtectedObject = $isProtected
        })

        $ownerReadiness.Add($readiness)

        $apps.Add([PSCustomObject]@{
            ObjectId     = $objectId
            AppId        = $appId
            DisplayName  = $displayName
            FindingId    = $fid
            OwnerCount   = $ownerCount
            HasOwner     = $hasOwner
            IsSPN        = $isSPN
            ReadinessStatus = $readiness.ReadinessStatus
            PlanOnly     = $readiness.PlanOnly
        })

        if ($readiness.ReadyForApproval)  { $readyForApprovalCount++ }
        if ($readiness.PlanOnly)          { $planOnlyCount++ }
    }

    $nextActions = @(
        'Review unowned applications and assign owners through the application owner approval packet process.',
        'Validate all single-owner applications for backup owner coverage.',
        'Review applications owned only by disabled users and assign active owners.',
        'Confirm service principals with no owner are assigned to the appropriate team.',
        'Submit approved owner assignments for Rev3.3 implementation.'
    )

    return [PSCustomObject]@{
        SchemaVersion                  = '3.2'
        ToolVersion                    = $Context.ToolVersion
        GeneratedUtc                   = (Get-Date).ToUniversalTime().ToString('o')
        ClientName                     = $Context.ClientName
        EngagementId                   = $Context.EngagementId
        Assessor                       = $Context.Assessor
        TenantId                       = if ($Context.TenantId) { $Context.TenantId } else { '' }
        ApplicationCount               = $apps.Count
        UnownedApplicationCount        = $unownedCount
        SingleOwnerApplicationCount    = $singleOwnerCount
        DisabledOwnerApplicationCount  = $disabledOwnerCount
        DisabledOnlyOwnerApplicationCount = $disabledOnlyCount
        ServicePrincipalNoOwnerCount   = $spnNoOwnerCount
        CredentialBearingNoOwnerCount  = $credNoOwnerCount
        ReadyForOwnerApprovalCount     = $readyForApprovalCount
        PlanOnlyOwnerActionCount       = $planOnlyCount
        ExceptionCount                 = $exceptionCount
        Applications                   = $apps.ToArray()
        OwnerReadiness                 = $ownerReadiness.ToArray()
        Exceptions                     = $exceptions.ToArray()
        RecommendedNextActions         = $nextActions
    }
}

function Get-DecomApplicationOwnerReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Application
    )

    $objectId    = $Application.ObjectId
    $appId       = $Application.AppId
    $displayName = $Application.DisplayName
    $findingId   = $Application.FindingId
    $ownerCount  = if ($null -ne $Application.OwnerCount) { [int]$Application.OwnerCount } else { 0 }
    $hasOwner    = $Application.HasOwner -eq $true
    $isSPN       = $Application.IsSPN -eq $true
    $isProtected = $Application.ProtectedObject -eq $true

    if ($isProtected) {
        return [PSCustomObject]@{
            ApplicationId    = $objectId
            AppId            = $appId
            DisplayName      = $displayName
            FindingId        = $findingId
            OwnerCount       = $ownerCount
            HasOwner         = $hasOwner
            IsSPN            = $isSPN
            ReadyForApproval = $false
            PlanOnly         = $false
            ReadinessStatus  = 'BlockedProtectedObject'
            ReadinessReason  = 'Object is marked ProtectedObject and cannot be remediated.'
        }
    }

    switch ($findingId) {
        'DEC-APP-001' {
            return [PSCustomObject]@{
                ApplicationId    = $objectId
                AppId            = $appId
                DisplayName      = $displayName
                FindingId        = $findingId
                OwnerCount       = 0
                HasOwner         = $false
                IsSPN            = $false
                ReadyForApproval = $true
                PlanOnly         = $false
                ReadinessStatus  = 'ReadyForOwnerApproval'
                ReadinessReason  = 'Application has no owner. Owner assignment requires approval and new owner ObjectId in manifest.'
            }
        }
        'DEC-APP-002' {
            return [PSCustomObject]@{
                ApplicationId    = $objectId
                AppId            = $appId
                DisplayName      = $displayName
                FindingId        = $findingId
                OwnerCount       = $ownerCount
                HasOwner         = $hasOwner
                IsSPN            = $false
                ReadyForApproval = $true
                PlanOnly         = $false
                ReadinessStatus  = 'ReadyForOwnerApproval'
                ReadinessReason  = 'Application owned exclusively by disabled user(s). Active owner replacement required.'
            }
        }
        'DEC-APP-003' {
            return [PSCustomObject]@{
                ApplicationId    = $objectId
                AppId            = $appId
                DisplayName      = $displayName
                FindingId        = $findingId
                OwnerCount       = $ownerCount
                HasOwner         = $hasOwner
                IsSPN            = $false
                ReadyForApproval = $false
                PlanOnly         = $true
                ReadinessStatus  = 'PlanOnlySingleOwner'
                ReadinessReason  = 'Application has only one owner. Second owner recommended but not yet executable. Manual review required.'
            }
        }
        'DEC-SPN-001' {
            return [PSCustomObject]@{
                ApplicationId    = $objectId
                AppId            = $appId
                DisplayName      = $displayName
                FindingId        = $findingId
                OwnerCount       = 0
                HasOwner         = $false
                IsSPN            = $true
                ReadyForApproval = $true
                PlanOnly         = $false
                ReadinessStatus  = 'ReadyForOwnerApproval'
                ReadinessReason  = 'Service principal has no owner. Owner assignment requires approval and new owner ObjectId in manifest.'
            }
        }
        default {
            return [PSCustomObject]@{
                ApplicationId    = $objectId
                AppId            = $appId
                DisplayName      = $displayName
                FindingId        = $findingId
                OwnerCount       = $ownerCount
                HasOwner         = $hasOwner
                IsSPN            = $isSPN
                ReadyForApproval = $false
                PlanOnly         = $true
                ReadinessStatus  = 'Deferred'
                ReadinessReason  = 'FindingId not recognized for owner readiness. Manual review required.'
            }
        }
    }
}

function Export-DecomApplicationGovernanceDashboardHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $ts          = $Model.GeneratedUtc
    $client      = [System.Net.WebUtility]::HtmlEncode($Model.ClientName)
    $engId       = [System.Net.WebUtility]::HtmlEncode($Model.EngagementId)
    $assessor    = [System.Net.WebUtility]::HtmlEncode($Model.Assessor)
    $appCount    = $Model.ApplicationCount
    $unowned     = $Model.UnownedApplicationCount
    $singleOwner = $Model.SingleOwnerApplicationCount
    $disabledOwn = $Model.DisabledOwnerApplicationCount
    $spnNoOwner  = $Model.ServicePrincipalNoOwnerCount
    $readyCount  = $Model.ReadyForOwnerApprovalCount
    $planOnly    = $Model.PlanOnlyOwnerActionCount

    $rowsSb = [System.Text.StringBuilder]::new()
    foreach ($r in $Model.OwnerReadiness) {
        $dn    = [System.Net.WebUtility]::HtmlEncode($r.DisplayName)
        $fid   = [System.Net.WebUtility]::HtmlEncode($r.FindingId)
        $oid   = [System.Net.WebUtility]::HtmlEncode($r.ApplicationId)
        $rs    = [System.Net.WebUtility]::HtmlEncode($r.ReadinessStatus)
        $rr    = [System.Net.WebUtility]::HtmlEncode($r.ReadinessReason)
        $oc    = $r.OwnerCount
        $badge = if ($r.ReadyForApproval) { 'badge-ready' } elseif ($r.PlanOnly) { 'badge-plan' } else { 'badge-blocked' }
        $null = $rowsSb.Append("<tr><td>$dn</td><td>$fid</td><td>$oid</td><td>$oc</td><td><span class='badge $badge'>$rs</span></td><td>$rr</td></tr>")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Application Ownership Governance Dashboard — $client</title>
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
footer{padding:16px 32px;font-size:.75rem;color:#888}
</style>
</head>
<body>
<div class="header">
  <h1>Application Ownership Governance Dashboard</h1>
  <p>Client: $client | Engagement: $engId | Assessor: $assessor | Generated: $ts | Schema: $($Model.SchemaVersion)</p>
</div>
<div class="cards">
  <div class="card"><div class="num">$appCount</div><div class="lbl">Total Applications</div></div>
  <div class="card"><div class="num">$unowned</div><div class="lbl">Unowned Apps</div></div>
  <div class="card"><div class="num">$singleOwner</div><div class="lbl">Single-Owner Apps</div></div>
  <div class="card"><div class="num">$disabledOwn</div><div class="lbl">Disabled Owner Apps</div></div>
  <div class="card"><div class="num">$spnNoOwner</div><div class="lbl">SPNs No Owner</div></div>
  <div class="card"><div class="num">$readyCount</div><div class="lbl">Ready for Approval</div></div>
  <div class="card"><div class="num">$planOnly</div><div class="lbl">Plan-Only Actions</div></div>
</div>
<div class="section">
  <h2>Application Owner Readiness</h2>
  <table>
    <tr><th>Display Name</th><th>Finding</th><th>Object ID</th><th>Owner Count</th><th>Status</th><th>Reason</th></tr>
    $($rowsSb.ToString())
  </table>
</div>
<footer>Rev3.2 Application Ownership Governance Pack — Read-Only Assessment Output</footer>
</body>
</html>
"@
    $html | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Application governance dashboard HTML: $Path"
}

function Export-DecomApplicationOwnerReadinessJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $payload = [PSCustomObject]@{
        SchemaVersion                  = $Model.SchemaVersion
        ToolVersion                    = $Model.ToolVersion
        GeneratedUtc                   = $Model.GeneratedUtc
        ClientName                     = $Model.ClientName
        EngagementId                   = $Model.EngagementId
        Assessor                       = $Model.Assessor
        TenantId                       = $Model.TenantId
        ApplicationCount               = $Model.ApplicationCount
        UnownedApplicationCount        = $Model.UnownedApplicationCount
        SingleOwnerApplicationCount    = $Model.SingleOwnerApplicationCount
        DisabledOwnerApplicationCount  = $Model.DisabledOwnerApplicationCount
        DisabledOnlyOwnerApplicationCount = $Model.DisabledOnlyOwnerApplicationCount
        ServicePrincipalNoOwnerCount   = $Model.ServicePrincipalNoOwnerCount
        CredentialBearingNoOwnerCount  = $Model.CredentialBearingNoOwnerCount
        ReadyForOwnerApprovalCount     = $Model.ReadyForOwnerApprovalCount
        PlanOnlyOwnerActionCount       = $Model.PlanOnlyOwnerActionCount
        ExceptionCount                 = $Model.ExceptionCount
        OwnerReadiness                 = $Model.OwnerReadiness
        Exceptions                     = $Model.Exceptions
        RecommendedNextActions         = $Model.RecommendedNextActions
    }
    $payload | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Application owner readiness JSON: $Path"
}

function Export-DecomApplicationOwnerReadinessCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Model.OwnerReadiness -and $Model.OwnerReadiness.Count -gt 0) {
        $Model.OwnerReadiness | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    } else {
        [PSCustomObject]@{
            ApplicationId   = ''
            AppId           = ''
            DisplayName     = ''
            FindingId       = ''
            OwnerCount      = 0
            HasOwner        = $false
            IsSPN           = $false
            ReadyForApproval= $false
            PlanOnly        = $false
            ReadinessStatus = ''
            ReadinessReason = ''
        } | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
    Write-DecomOk "Application owner readiness CSV: $Path"
}

function Export-DecomApplicationOwnerApprovalPacketMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Application Owner Approval Packet")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Client:** $($Model.ClientName)")
    $null = $sb.AppendLine("**Engagement:** $($Model.EngagementId)")
    $null = $sb.AppendLine("**Assessor:** $($Model.Assessor)")
    $null = $sb.AppendLine("**Generated (UTC):** $($Model.GeneratedUtc)")
    $null = $sb.AppendLine("**Schema Version:** $($Model.SchemaVersion)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Metric | Count |")
    $null = $sb.AppendLine("|---|---|")
    $null = $sb.AppendLine("| Applications Reviewed | $($Model.ApplicationCount) |")
    $null = $sb.AppendLine("| Unowned Applications | $($Model.UnownedApplicationCount) |")
    $null = $sb.AppendLine("| Single-Owner Applications | $($Model.SingleOwnerApplicationCount) |")
    $null = $sb.AppendLine("| Disabled-Owner Applications | $($Model.DisabledOwnerApplicationCount) |")
    $null = $sb.AppendLine("| Service Principals No Owner | $($Model.ServicePrincipalNoOwnerCount) |")
    $null = $sb.AppendLine("| Ready for Approval | $($Model.ReadyForOwnerApprovalCount) |")
    $null = $sb.AppendLine("| Plan-Only | $($Model.PlanOnlyOwnerActionCount) |")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Owner Assignment Approval Table")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("Each row below requires explicit owner approval before execution.")
    $null = $sb.AppendLine("Provide the new owner ObjectId in the approval manifest `NewOwnerObjectId` field.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Application | Finding | Object ID | Readiness | Action Required |")
    $null = $sb.AppendLine("|---|---|---|---|---|")

    foreach ($r in ($Model.OwnerReadiness | Where-Object { $_.ReadyForApproval })) {
        $null = $sb.AppendLine("| $($r.DisplayName) | $($r.FindingId) | $($r.ApplicationId) | $($r.ReadinessStatus) | Assign new owner |")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Plan-Only Items (No Execution Available in Rev3.2)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Application | Finding | Object ID | Status | Reason |")
    $null = $sb.AppendLine("|---|---|---|---|---|")

    foreach ($r in ($Model.OwnerReadiness | Where-Object { $_.PlanOnly })) {
        $null = $sb.AppendLine("| $($r.DisplayName) | $($r.FindingId) | $($r.ApplicationId) | $($r.ReadinessStatus) | $($r.ReadinessReason) |")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Approver Signature")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("By signing below, the approver confirms that the new owner assignments above are correct,")
    $null = $sb.AppendLine("authorized, and that owner ObjectIds have been validated against the active directory.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Name:** ___________________________")
    $null = $sb.AppendLine("**Title:** ___________________________")
    $null = $sb.AppendLine("**Date:** ___________________________")
    $null = $sb.AppendLine("**Signature:** ___________________________")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("*Rev3.2 Application Ownership Governance Pack — Read-Only Assessment Output*")
    $null = $sb.AppendLine("*AddApplicationOwner execution is deferred to Rev3.3 after QA approval.*")

    $sb.ToString() | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Application owner approval packet Markdown: $Path"
}

function Export-DecomApplicationOwnerApprovalPacketHtml {
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

    $readyRows = [System.Text.StringBuilder]::new()
    foreach ($r in ($Model.OwnerReadiness | Where-Object { $_.ReadyForApproval })) {
        $dn  = [System.Net.WebUtility]::HtmlEncode($r.DisplayName)
        $fid = [System.Net.WebUtility]::HtmlEncode($r.FindingId)
        $oid = [System.Net.WebUtility]::HtmlEncode($r.ApplicationId)
        $rs  = [System.Net.WebUtility]::HtmlEncode($r.ReadinessStatus)
        $null = $readyRows.Append("<tr><td>$dn</td><td>$fid</td><td>$oid</td><td>$rs</td><td>Assign new owner</td></tr>")
    }

    $planRows = [System.Text.StringBuilder]::new()
    foreach ($r in ($Model.OwnerReadiness | Where-Object { $_.PlanOnly })) {
        $dn  = [System.Net.WebUtility]::HtmlEncode($r.DisplayName)
        $fid = [System.Net.WebUtility]::HtmlEncode($r.FindingId)
        $oid = [System.Net.WebUtility]::HtmlEncode($r.ApplicationId)
        $rs  = [System.Net.WebUtility]::HtmlEncode($r.ReadinessStatus)
        $rr  = [System.Net.WebUtility]::HtmlEncode($r.ReadinessReason)
        $null = $planRows.Append("<tr><td>$dn</td><td>$fid</td><td>$oid</td><td>$rs</td><td>$rr</td></tr>")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Application Owner Approval Packet — $client</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f4f6f9;color:#1a1a2e}
.header{background:#1a1a2e;color:#fff;padding:24px 32px}
.header h1{margin:0;font-size:1.4rem}
.header p{margin:4px 0 0;font-size:.8rem;opacity:.8}
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
  <h1>Application Owner Approval Packet</h1>
  <p>Client: $client | Engagement: $engId | Assessor: $assessor | Generated: $ts</p>
</div>
<div class="section">
  <h2>Applications Ready for Owner Assignment</h2>
  <table>
    <tr><th>Application</th><th>Finding</th><th>Object ID</th><th>Readiness</th><th>Action Required</th></tr>
    $($readyRows.ToString())
  </table>
  <h2>Plan-Only Items (Rev3.2)</h2>
  <table>
    <tr><th>Application</th><th>Finding</th><th>Object ID</th><th>Status</th><th>Reason</th></tr>
    $($planRows.ToString())
  </table>
  <h2>Approver Signature</h2>
  <div class="sig-box">
    <p>By signing, the approver confirms that owner assignments are correct, authorized, and ObjectIds have been validated.</p>
    <p class="sig-line">Name: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p>
    <p class="sig-line">Title: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p>
    <p class="sig-line">Date: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p>
    <p class="sig-line">Signature: &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</p>
  </div>
</div>
<footer>Rev3.2 Application Ownership Governance Pack — Read-Only Assessment Output. AddApplicationOwner execution deferred to Rev3.3.</footer>
</body>
</html>
"@
    $html | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Application owner approval packet HTML: $Path"
}

function Export-DecomApplicationOwnershipExceptionRegisterCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Model.Exceptions -and $Model.Exceptions.Count -gt 0) {
        $Model.Exceptions | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    } else {
        [PSCustomObject]@{
            FindingId    = ''
            ObjectId     = ''
            DisplayName  = ''
            Reason       = ''
            ExceptionUtc = ''
        } | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
    Write-DecomOk "Application ownership exception register CSV: $Path"
}

function Export-DecomApplicationGovernanceEvidenceAppendixMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Application Governance Evidence Appendix")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Client:** $($Model.ClientName)")
    $null = $sb.AppendLine("**Engagement:** $($Model.EngagementId)")
    $null = $sb.AppendLine("**Assessor:** $($Model.Assessor)")
    $null = $sb.AppendLine("**Generated (UTC):** $($Model.GeneratedUtc)")
    $null = $sb.AppendLine("**Schema Version:** $($Model.SchemaVersion)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Evidence Chain")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("This appendix documents the evidence chain for application ownership governance.")
    $null = $sb.AppendLine("All data was collected in read-only assessment mode with no write operations performed.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Evidence Item | Value |")
    $null = $sb.AppendLine("|---|---|")
    $null = $sb.AppendLine("| Assessment Tool Version | $($Model.ToolVersion) |")
    $null = $sb.AppendLine("| Schema Version | $($Model.SchemaVersion) |")
    $null = $sb.AppendLine("| Generated UTC | $($Model.GeneratedUtc) |")
    $null = $sb.AppendLine("| Total Applications Assessed | $($Model.ApplicationCount) |")
    $null = $sb.AppendLine("| Unowned Applications | $($Model.UnownedApplicationCount) |")
    $null = $sb.AppendLine("| Single-Owner Applications | $($Model.SingleOwnerApplicationCount) |")
    $null = $sb.AppendLine("| Disabled-Owner Applications | $($Model.DisabledOwnerApplicationCount) |")
    $null = $sb.AppendLine("| SPNs Without Owner | $($Model.ServicePrincipalNoOwnerCount) |")
    $null = $sb.AppendLine("| Credential-Bearing Apps Without Owner | $($Model.CredentialBearingNoOwnerCount) |")
    $null = $sb.AppendLine("| Ready for Owner Approval | $($Model.ReadyForOwnerApprovalCount) |")
    $null = $sb.AppendLine("| Plan-Only Actions | $($Model.PlanOnlyOwnerActionCount) |")
    $null = $sb.AppendLine("| Exception Register Entries | $($Model.ExceptionCount) |")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Read-Only Guarantee")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("ApplicationGovernance.psm1 is a read-only module. No Graph write operations were performed")
    $null = $sb.AppendLine("during the generation of this report. Owner assignments require a separate approval workflow")
    $null = $sb.AppendLine("and are deferred to Rev3.3 after explicit QA approval.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Recommended Next Actions")
    $null = $sb.AppendLine("")
    foreach ($action in $Model.RecommendedNextActions) {
        $null = $sb.AppendLine("- $action")
    }
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("*Rev3.2 Application Ownership Governance Pack — Evidence Appendix*")

    $sb.ToString() | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Application governance evidence appendix Markdown: $Path"
}
