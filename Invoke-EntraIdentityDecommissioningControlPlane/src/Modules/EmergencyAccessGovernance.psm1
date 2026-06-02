#Requires -Version 5.1

function New-DecomEmergencyAccessGovernanceModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $false)]
        [object[]]$Findings = @(),
        [Parameter(Mandatory = $false)]
        [object[]]$WhatIfActions = @(),
        [Parameter(Mandatory = $false)]
        [object[]]$ApprovalActions = @()
    )

    $protectedObjects          = [System.Collections.Generic.List[object]]::new()
    $emergencyAccessAccounts   = [System.Collections.Generic.List[object]]::new()
    $whatIfBlocked             = [System.Collections.Generic.List[object]]::new()
    $approvalBlocked           = [System.Collections.Generic.List[object]]::new()
    $hygieneGaps               = [System.Collections.Generic.List[object]]::new()

    $protectedByType = @{}

    foreach ($f in $Findings) {
        if ($f.ProtectedObject -ne $true) { continue }

        $objId    = if ($f.ObjectId)    { $f.ObjectId }    else { '' }
        $dispName = if ($f.DisplayName) { $f.DisplayName } else { 'Unknown' }
        $objType  = if ($f.ObjectType)  { $f.ObjectType }  else { 'Unknown' }
        $findId   = if ($f.FindingId)   { $f.FindingId }   else { '' }

        $po = [PSCustomObject]@{
            ObjectId        = $objId
            DisplayName     = $dispName
            ObjectType      = $objType
            FindingId       = $findId
            ProtectionReason= if ($f.ProtectedObjectReason) { $f.ProtectedObjectReason } else { 'ProtectedObject flag set in finding' }
        }
        $protectedObjects.Add($po)

        if (-not $protectedByType.ContainsKey($objType)) { $protectedByType[$objType] = 0 }
        $protectedByType[$objType]++

        $isEmergencyAcct = ($f.IsEmergencyAccess -eq $true -or $f.IsBreakGlass -eq $true -or
            $dispName -match '(break.?glass|emergency.?access|breakglass|bg-|ba-|eac-)')
        if ($isEmergencyAcct) {
            $emergencyAccessAccounts.Add([PSCustomObject]@{
                ObjectId          = $objId
                DisplayName       = $dispName
                ObjectType        = $objType
                FindingId         = $findId
                IsBreakGlass      = ($f.IsBreakGlass -eq $true)
                IsEmergencyAccess = $true
                ProtectedObject   = $true
                HygieneGapsFound  = $false
                Note              = 'Confirmed protected. No remediation actions will be executed against this object.'
            })
        }
    }

    foreach ($action in $WhatIfActions) {
        if ($action.ProtectedObject -ne $true) { continue }
        $whatIfBlocked.Add([PSCustomObject]@{
            ActionId        = if ($action.ActionId)    { $action.ActionId }    else { '' }
            FindingId       = if ($action.FindingId)   { $action.FindingId }   else { '' }
            ActionType      = if ($action.ActionType)  { $action.ActionType }  else { '' }
            ObjectId        = if ($action.ObjectId)    { $action.ObjectId }    else { '' }
            DisplayName     = if ($action.DisplayName) { $action.DisplayName } else { '' }
            BlockedReason   = 'ProtectedObject flag in WhatIf action plan'
        })
    }

    foreach ($action in $ApprovalActions) {
        if ($action.ProtectedObject -ne $true) { continue }
        $approvalBlocked.Add([PSCustomObject]@{
            ActionId        = if ($action.ActionId)    { $action.ActionId }    else { '' }
            FindingId       = if ($action.FindingId)   { $action.FindingId }   else { '' }
            ActionType      = if ($action.ActionType)  { $action.ActionType }  else { '' }
            ObjectId        = if ($action.ObjectId)    { $action.ObjectId }    else { '' }
            DisplayName     = if ($action.DisplayName) { $action.DisplayName } else { '' }
            BlockedReason   = 'ProtectedObject flag in approval action'
        })
    }

    $knownGapPatterns = @(
        'Emergency access account missing MFA registration',
        'Emergency access account has expiring credentials',
        'Emergency access account not excluded from all applicable CA policies',
        'Emergency access account shared secret not rotated within 90 days',
        'Emergency access account sign-in activity not monitored'
    )
    foreach ($gap in $knownGapPatterns) {
        $hygieneGaps.Add([PSCustomObject]@{
            GapDescription = $gap
            RecommendedAction = 'Manual review and validation required. Contact security team.'
            Automated = $false
        })
    }

    return [PSCustomObject]@{
        SchemaVersion             = '3.2'
        ToolVersion               = $Context.ToolVersion
        GeneratedUtc              = (Get-Date).ToUniversalTime().ToString('o')
        ClientName                = $Context.ClientName
        EngagementId              = $Context.EngagementId
        Assessor                  = $Context.Assessor
        TenantId                  = if ($Context.TenantId) { $Context.TenantId } else { '' }
        ProtectedObjectCount      = $protectedObjects.Count
        EmergencyAccessAccountCount = $emergencyAccessAccounts.Count
        ProtectedObjectBreakdown  = $protectedByType
        WhatIfActionsBlockedCount = $whatIfBlocked.Count
        ApprovalActionsBlockedCount = $approvalBlocked.Count
        ProtectedObjects          = $protectedObjects.ToArray()
        EmergencyAccessAccounts   = $emergencyAccessAccounts.ToArray()
        WhatIfActionsBlocked      = $whatIfBlocked.ToArray()
        ApprovalActionsBlocked    = $approvalBlocked.ToArray()
        PotentialHygieneGaps      = $hygieneGaps.ToArray()
    }
}

function Export-DecomEmergencyAccessGovernanceReportMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Emergency Access Governance Report")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Client:** $($Model.ClientName)")
    $null = $sb.AppendLine("**Engagement:** $($Model.EngagementId)")
    $null = $sb.AppendLine("**Assessor:** $($Model.Assessor)")
    $null = $sb.AppendLine("**Generated (UTC):** $($Model.GeneratedUtc)")
    $null = $sb.AppendLine("**Schema Version:** $($Model.SchemaVersion)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("> **Rev3.2 Safety Guarantee:** This module is read-only.")
    $null = $sb.AppendLine("> Emergency access / break-glass accounts flagged as ProtectedObject are blocked from all WhatIf, approval, and execution actions.")
    $null = $sb.AppendLine("> ProtectedObject always wins over approval.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Protected Object Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Metric | Count |")
    $null = $sb.AppendLine("|---|---|")
    $null = $sb.AppendLine("| Total Protected Objects | $($Model.ProtectedObjectCount) |")
    $null = $sb.AppendLine("| Emergency Access Accounts | $($Model.EmergencyAccessAccountCount) |")
    $null = $sb.AppendLine("| WhatIf Actions Blocked | $($Model.WhatIfActionsBlockedCount) |")
    $null = $sb.AppendLine("| Approval Actions Blocked | $($Model.ApprovalActionsBlockedCount) |")
    $null = $sb.AppendLine("")

    if ($Model.ProtectedObjectBreakdown -and $Model.ProtectedObjectBreakdown.Count -gt 0) {
        $null = $sb.AppendLine("## Protected Object Breakdown by Type")
        $null = $sb.AppendLine("")
        $null = $sb.AppendLine("| Object Type | Count |")
        $null = $sb.AppendLine("|---|---|")
        foreach ($key in $Model.ProtectedObjectBreakdown.Keys) {
            $null = $sb.AppendLine("| $key | $($Model.ProtectedObjectBreakdown[$key]) |")
        }
        $null = $sb.AppendLine("")
    }

    $null = $sb.AppendLine("## Emergency Access Account Inventory")
    $null = $sb.AppendLine("")
    if ($Model.EmergencyAccessAccounts.Count -gt 0) {
        $null = $sb.AppendLine("| Display Name | Object ID | Type | Protected |")
        $null = $sb.AppendLine("|---|---|---|---|")
        foreach ($acct in $Model.EmergencyAccessAccounts) {
            $null = $sb.AppendLine("| $($acct.DisplayName) | $($acct.ObjectId) | $($acct.ObjectType) | Yes |")
        }
    } else {
        $null = $sb.AppendLine("No emergency access accounts were identified in assessment findings.")
        $null = $sb.AppendLine("If break-glass accounts exist, ensure they are tagged with `ProtectedObject = true` in findings.")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## WhatIf Actions Blocked by ProtectedObject")
    $null = $sb.AppendLine("")
    if ($Model.WhatIfActionsBlocked.Count -gt 0) {
        $null = $sb.AppendLine("| Action ID | Finding | Action Type | Object | Display Name |")
        $null = $sb.AppendLine("|---|---|---|---|---|")
        foreach ($a in $Model.WhatIfActionsBlocked) {
            $null = $sb.AppendLine("| $($a.ActionId) | $($a.FindingId) | $($a.ActionType) | $($a.ObjectId) | $($a.DisplayName) |")
        }
    } else {
        $null = $sb.AppendLine("No WhatIf actions were blocked by ProtectedObject in this assessment run.")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Approval Actions Blocked by ProtectedObject")
    $null = $sb.AppendLine("")
    if ($Model.ApprovalActionsBlocked.Count -gt 0) {
        $null = $sb.AppendLine("| Action ID | Finding | Action Type | Object | Display Name |")
        $null = $sb.AppendLine("|---|---|---|---|---|")
        foreach ($a in $Model.ApprovalActionsBlocked) {
            $null = $sb.AppendLine("| $($a.ActionId) | $($a.FindingId) | $($a.ActionType) | $($a.ObjectId) | $($a.DisplayName) |")
        }
    } else {
        $null = $sb.AppendLine("No approval actions were blocked by ProtectedObject in this assessment run.")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Potential Emergency Access Hygiene Gaps")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("The following hygiene gaps are common with emergency access accounts.")
    $null = $sb.AppendLine("Manual review is required — these checks are not automated.")
    $null = $sb.AppendLine("")
    foreach ($gap in $Model.PotentialHygieneGaps) {
        $null = $sb.AppendLine("- **$($gap.GapDescription)** — $($gap.RecommendedAction)")
    }

    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Recommended Manual Checks")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("1. Confirm all break-glass accounts are tagged ProtectedObject in assessment findings.")
    $null = $sb.AppendLine("2. Validate that emergency access accounts are excluded from all CA policies that could lock them out.")
    $null = $sb.AppendLine("3. Confirm MFA and conditional access monitoring is in place for emergency access accounts.")
    $null = $sb.AppendLine("4. Validate that emergency access account credentials are rotated per policy.")
    $null = $sb.AppendLine("5. Confirm that sign-in activity for emergency access accounts is alerted and monitored.")
    $null = $sb.AppendLine("6. Review this report with the security operations team to confirm no gaps.")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("*Rev3.2 Emergency Access Governance Pack — Read-Only Assessment Output*")
    $null = $sb.AppendLine("*ProtectedObject always wins over approval. No override exists in Rev3.2.*")

    $sb.ToString() | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Emergency access governance report Markdown: $Path"
}

function Export-DecomEmergencyAccessGovernanceReportHtml {
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

    $poRowsSb = [System.Text.StringBuilder]::new()
    foreach ($po in $Model.ProtectedObjects) {
        $dn  = [System.Net.WebUtility]::HtmlEncode($po.DisplayName)
        $oid = [System.Net.WebUtility]::HtmlEncode($po.ObjectId)
        $ot  = [System.Net.WebUtility]::HtmlEncode($po.ObjectType)
        $fid = [System.Net.WebUtility]::HtmlEncode($po.FindingId)
        $pr  = [System.Net.WebUtility]::HtmlEncode($po.ProtectionReason)
        $null = $poRowsSb.Append("<tr><td>$dn</td><td>$oid</td><td>$ot</td><td>$fid</td><td>$pr</td></tr>")
    }

    $gapRowsSb = [System.Text.StringBuilder]::new()
    foreach ($gap in $Model.PotentialHygieneGaps) {
        $gd = [System.Net.WebUtility]::HtmlEncode($gap.GapDescription)
        $ra = [System.Net.WebUtility]::HtmlEncode($gap.RecommendedAction)
        $null = $gapRowsSb.Append("<tr><td>$gd</td><td>$ra</td></tr>")
    }

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Emergency Access Governance Report — $client</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:#f4f6f9;color:#1a1a2e}
.header{background:#1a1a2e;color:#fff;padding:24px 32px}
.header h1{margin:0;font-size:1.4rem}
.header p{margin:4px 0 0;font-size:.8rem;opacity:.8}
.alert{background:#f8d7da;border-left:4px solid #dc3545;padding:12px 16px;margin:24px 32px 0;border-radius:4px;font-size:.85rem;color:#721c24}
.cards{display:flex;flex-wrap:wrap;gap:16px;padding:24px 32px}
.card{background:#fff;border-radius:8px;padding:20px 24px;min-width:160px;box-shadow:0 1px 4px rgba(0,0,0,.1)}
.card .num{font-size:2rem;font-weight:700;color:#1a1a2e}
.card .lbl{font-size:.8rem;color:#666;margin-top:4px}
.section{padding:0 32px 32px}
table{width:100%;border-collapse:collapse;background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.1);margin-bottom:24px}
th{background:#1a1a2e;color:#fff;padding:10px 12px;text-align:left;font-size:.8rem}
td{padding:10px 12px;border-bottom:1px solid #eee;font-size:.82rem;vertical-align:top}
tr:last-child td{border-bottom:none}
footer{padding:16px 32px;font-size:.75rem;color:#888}
</style>
</head>
<body>
<div class="header">
  <h1>Emergency Access Governance Report</h1>
  <p>Client: $client | Engagement: $engId | Assessor: $assessor | Generated: $ts</p>
</div>
<div class="alert">
  <strong>Rev3.2 Safety Guarantee:</strong> ProtectedObject always wins over approval.
  No write operations were performed against protected objects. No override exists in Rev3.2.
</div>
<div class="cards">
  <div class="card"><div class="num">$($Model.ProtectedObjectCount)</div><div class="lbl">Protected Objects</div></div>
  <div class="card"><div class="num">$($Model.EmergencyAccessAccountCount)</div><div class="lbl">Emergency Access Accounts</div></div>
  <div class="card"><div class="num">$($Model.WhatIfActionsBlockedCount)</div><div class="lbl">WhatIf Actions Blocked</div></div>
  <div class="card"><div class="num">$($Model.ApprovalActionsBlockedCount)</div><div class="lbl">Approval Actions Blocked</div></div>
</div>
<div class="section">
  <h2>Protected Objects</h2>
  <table>
    <tr><th>Display Name</th><th>Object ID</th><th>Type</th><th>Finding</th><th>Protection Reason</th></tr>
    $($poRowsSb.ToString())
  </table>
  <h2>Potential Emergency Access Hygiene Gaps</h2>
  <table>
    <tr><th>Gap</th><th>Recommended Action</th></tr>
    $($gapRowsSb.ToString())
  </table>
</div>
<footer>Rev3.2 Emergency Access Governance Pack — Read-Only Assessment Output.</footer>
</body>
</html>
"@
    $html | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Emergency access governance report HTML: $Path"
}

function Export-DecomProtectedObjectValidationJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $payload = [PSCustomObject]@{
        SchemaVersion               = $Model.SchemaVersion
        ToolVersion                 = $Model.ToolVersion
        GeneratedUtc                = $Model.GeneratedUtc
        ClientName                  = $Model.ClientName
        EngagementId                = $Model.EngagementId
        Assessor                    = $Model.Assessor
        TenantId                    = $Model.TenantId
        ProtectedObjectCount        = $Model.ProtectedObjectCount
        EmergencyAccessAccountCount = $Model.EmergencyAccessAccountCount
        ProtectedObjectBreakdown    = $Model.ProtectedObjectBreakdown
        WhatIfActionsBlockedCount   = $Model.WhatIfActionsBlockedCount
        ApprovalActionsBlockedCount = $Model.ApprovalActionsBlockedCount
        ProtectedObjects            = $Model.ProtectedObjects
        EmergencyAccessAccounts     = $Model.EmergencyAccessAccounts
        WhatIfActionsBlocked        = $Model.WhatIfActionsBlocked
        ApprovalActionsBlocked      = $Model.ApprovalActionsBlocked
        PotentialHygieneGaps        = $Model.PotentialHygieneGaps
    }
    $payload | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Protected object validation JSON: $Path"
}

function Export-DecomProtectedObjectValidationCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Model.ProtectedObjects -and $Model.ProtectedObjects.Count -gt 0) {
        $Model.ProtectedObjects | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    } else {
        [PSCustomObject]@{
            ObjectId         = ''
            DisplayName      = ''
            ObjectType       = ''
            FindingId        = ''
            ProtectionReason = ''
        } | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
    }
    Write-DecomOk "Protected object validation CSV: $Path"
}
