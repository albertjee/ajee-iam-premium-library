#Requires -Version 5.1

function New-DecomCredentialHygieneModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Context,
        [Parameter(Mandatory = $false)]
        [object[]]$Findings = @()
    )

    $details = [System.Collections.Generic.List[object]]::new()
    $utcNow = [datetime]::UtcNow

    foreach ($f in @($Findings | Where-Object { $_.FindingId -in @('DEC-APP-005','DEC-APP-004') })) {
        $readiness = Get-DecomCredentialRemovalReadiness -Credential $f
        $details.Add($readiness)
    }

    $model = [pscustomobject]@{
        SchemaVersion = '3.2'
        ToolVersion   = $Context.ToolVersion
        GeneratedUtc  = $utcNow.ToString('o')
        ClientName    = $Context.ClientName
        EngagementId  = $Context.EngagementId
        Assessor      = $Context.Assessor
        TenantId      = if ($Context.TenantId) { $Context.TenantId } else { '' }
        CredentialCount                       = $details.Count
        ExpiredCredentialCount                = ($details | Where-Object { $_.IsExpired }).Count
        ExpiringSoonCredentialCount           = ($details | Where-Object { -not $_.IsExpired -and $_.ReadinessStatus -eq 'PlanOnlyExpiringNotExpired' }).Count
        OwnerlessCredentialCount              = ($details | Where-Object { $_.OwnerCount -eq 0 }).Count
        SingleOwnerCredentialCount            = ($details | Where-Object { $_.OwnerCount -eq 1 }).Count
        DisabledOwnerCredentialCount          = 0
        ReadyForApprovalCount                 = ($details | Where-Object { $_.ReadinessStatus -eq 'ReadyForApproval' }).Count
        PlanOnlyExpiringNotExpiredCount       = ($details | Where-Object { $_.ReadinessStatus -eq 'PlanOnlyExpiringNotExpired' }).Count
        BlockedMissingCredentialKeyIdCount    = ($details | Where-Object { $_.ReadinessStatus -eq 'BlockedMissingCredentialKeyId' }).Count
        BlockedCredentialNotExpiredCount      = ($details | Where-Object { $_.ReadinessStatus -eq 'BlockedCredentialNotExpired' }).Count
        BlockedApplicationReadFailureCount    = ($details | Where-Object { $_.ReadinessStatus -eq 'BlockedApplicationReadFailure' }).Count
        BlockedNoApplicationOwnerCount        = ($details | Where-Object { $_.ReadinessStatus -eq 'BlockedNoApplicationOwner' }).Count
        BlockedProtectedApplicationCount      = ($details | Where-Object { $_.ReadinessStatus -eq 'BlockedProtectedApplication' }).Count
        BlockedCredentialTypeUnsupportedCount = ($details | Where-Object { $_.ReadinessStatus -eq 'BlockedCredentialTypeUnsupported' }).Count
        SkippedAlreadyRemovedCount            = ($details | Where-Object { $_.ReadinessStatus -eq 'SkippedAlreadyRemoved' }).Count
        ExecutedCount                         = 0
        FailedCount                           = 0
        PartialFailedCount                    = 0
        DeferredCount                         = ($details | Where-Object { $_.ReadinessStatus -eq 'Deferred' }).Count
        CredentialDetails                     = $details.ToArray()
    }

    return $model
}

function Get-DecomCredentialRemovalReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Credential
    )

    $utcNow   = [datetime]::UtcNow
    $keyId    = [string]$Credential.CredentialKeyId
    if (-not $keyId) { $keyId = [string]$Credential.KeyId }

    $credType = [string]$Credential.CredentialType
    $endDateRaw = [string]$Credential.CredentialEndDateTime
    $isProtected = $Credential.ProtectedObject -eq $true
    $ownerCount = if ($null -ne $Credential.OwnerCount) { [int]$Credential.OwnerCount } else { -1 }

    # ProtectedObject wins
    if ($isProtected) {
        return [pscustomobject]@{
            ApplicationId   = [string]$Credential.ApplicationId
            ApplicationObjectId = [string]$Credential.ObjectId
            AppId           = [string]$Credential.AppId
            DisplayName     = [string]$Credential.DisplayName
            CredentialKeyId = $keyId
            CredentialType  = $credType
            StartDateTime   = [string]$Credential.CredentialStartDateTime
            EndDateTime     = $endDateRaw
            IsExpired       = $false
            OwnerCount      = $ownerCount
            ReadinessStatus = 'BlockedProtectedApplication'
            ReadinessReason = 'ProtectedObject is set — credential removal blocked'
        }
    }

    # Credential type must be supported
    if ($credType -and $credType -ne '' -and $credType -notin @('PasswordCredential','KeyCredential','')) {
        return [pscustomobject]@{
            ApplicationId   = [string]$Credential.ApplicationId
            ApplicationObjectId = [string]$Credential.ObjectId
            AppId           = [string]$Credential.AppId
            DisplayName     = [string]$Credential.DisplayName
            CredentialKeyId = $keyId
            CredentialType  = $credType
            StartDateTime   = [string]$Credential.CredentialStartDateTime
            EndDateTime     = $endDateRaw
            IsExpired       = $false
            OwnerCount      = $ownerCount
            ReadinessStatus = 'BlockedCredentialTypeUnsupported'
            ReadinessReason = "Credential type '$credType' is not supported (must be PasswordCredential or KeyCredential)"
        }
    }

    # KeyId required for executable action
    if (-not $keyId) {
        return [pscustomobject]@{
            ApplicationId   = [string]$Credential.ApplicationId
            ApplicationObjectId = [string]$Credential.ObjectId
            AppId           = [string]$Credential.AppId
            DisplayName     = [string]$Credential.DisplayName
            CredentialKeyId = ''
            CredentialType  = $credType
            StartDateTime   = [string]$Credential.CredentialStartDateTime
            EndDateTime     = $endDateRaw
            IsExpired       = $false
            OwnerCount      = $ownerCount
            ReadinessStatus = 'BlockedMissingCredentialKeyId'
            ReadinessReason = 'No exact credential KeyId found in finding — cannot generate executable action'
        }
    }

    # Parse EndDateTime
    $isExpired = $false
    $endDt = $null
    if ($endDateRaw) {
        try {
            $endDt = [datetime]::Parse($endDateRaw, [System.Globalization.CultureInfo]::InvariantCulture,
                [System.Globalization.DateTimeStyles]::RoundtripKind)
            $isExpired = ($endDt.ToUniversalTime() -lt $utcNow)
        } catch {
            $isExpired = $false
        }
    }

    if (-not $isExpired) {
        $status = if ($Credential.FindingId -eq 'DEC-APP-004') {
            'PlanOnlyExpiringNotExpired'
        } else {
            'BlockedCredentialNotExpired'
        }
        return [pscustomobject]@{
            ApplicationId   = [string]$Credential.ApplicationId
            ApplicationObjectId = [string]$Credential.ObjectId
            AppId           = [string]$Credential.AppId
            DisplayName     = [string]$Credential.DisplayName
            CredentialKeyId = $keyId
            CredentialType  = $credType
            StartDateTime   = [string]$Credential.CredentialStartDateTime
            EndDateTime     = $endDateRaw
            IsExpired       = $false
            OwnerCount      = $ownerCount
            ReadinessStatus = $status
            ReadinessReason = 'Credential is not yet expired — plan-only or blocked'
        }
    }

    return [pscustomobject]@{
        ApplicationId   = [string]$Credential.ApplicationId
        ApplicationObjectId = [string]$Credential.ObjectId
        AppId           = [string]$Credential.AppId
        DisplayName     = [string]$Credential.DisplayName
        CredentialKeyId = $keyId
        CredentialType  = $credType
        StartDateTime   = [string]$Credential.CredentialStartDateTime
        EndDateTime     = $endDateRaw
        IsExpired       = $true
        OwnerCount      = $ownerCount
        ReadinessStatus = 'ReadyForApproval'
        ReadinessReason = 'Exact expired credential KeyId present — ready for approval'
    }
}

function Export-DecomCredentialHygieneDashboardHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Credential Hygiene Dashboard — $($Model.ClientName)</title>
    <style>
        body { font-family: Segoe UI, sans-serif; margin: 2em; color: #222; }
        h1 { color: #1a1a2e; }
        table { border-collapse: collapse; width: 100%; margin-top: 1em; }
        th { background: #1a1a2e; color: #fff; padding: 8px; text-align: left; }
        td { padding: 6px 8px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f5f5f5; }
        .badge { border-radius: 4px; padding: 2px 8px; font-size: 0.85em; }
        .ready { background: #d4edda; color: #155724; }
        .blocked { background: #f8d7da; color: #721c24; }
        .plan { background: #fff3cd; color: #856404; }
    </style>
</head>
<body>
<h1>Credential Hygiene Dashboard</h1>
<p><strong>Client:</strong> $($Model.ClientName) &nbsp;|&nbsp;
   <strong>Engagement:</strong> $($Model.EngagementId) &nbsp;|&nbsp;
   <strong>Generated:</strong> $($Model.GeneratedUtc) &nbsp;|&nbsp;
   <strong>SchemaVersion:</strong> $($Model.SchemaVersion)</p>

<h2>Summary</h2>
<table>
<tr><th>Metric</th><th>Count</th></tr>
<tr><td>Total Credentials Assessed</td><td>$($Model.CredentialCount)</td></tr>
<tr><td>Expired Credentials</td><td>$($Model.ExpiredCredentialCount)</td></tr>
<tr><td>Expiring Soon (Plan-Only)</td><td>$($Model.ExpiringSoonCredentialCount)</td></tr>
<tr><td>Ready for Approval</td><td>$($Model.ReadyForApprovalCount)</td></tr>
<tr><td>Blocked — Missing KeyId</td><td>$($Model.BlockedMissingCredentialKeyIdCount)</td></tr>
<tr><td>Blocked — Not Expired</td><td>$($Model.BlockedCredentialNotExpiredCount)</td></tr>
<tr><td>Blocked — Read Failure</td><td>$($Model.BlockedApplicationReadFailureCount)</td></tr>
<tr><td>Blocked — Protected Application</td><td>$($Model.BlockedProtectedApplicationCount)</td></tr>
</table>

<h2>Credential Details</h2>
<table>
<tr><th>Application</th><th>Credential Type</th><th>KeyId</th><th>End Date</th><th>Expired</th><th>Readiness</th></tr>
$(foreach ($c in $Model.CredentialDetails) {
    $badge = switch ($c.ReadinessStatus) {
        'ReadyForApproval' { 'ready' }
        { $_ -like 'Blocked*' } { 'blocked' }
        default { 'plan' }
    }
    "<tr><td>$($c.DisplayName)</td><td>$($c.CredentialType)</td><td>$($c.CredentialKeyId)</td><td>$($c.EndDateTime)</td><td>$($c.IsExpired)</td><td><span class='badge $badge'>$($c.ReadinessStatus)</span></td></tr>"
})
</table>

<hr><p style="font-size:0.8em">© 2026 Albert Jee. All rights reserved. Rev3.2 Credential Hygiene Dashboard.</p>
</body></html>
"@
    $html | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Credential hygiene dashboard HTML: $Path"
}

function Export-DecomCredentialRemovalReadinessJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $Model | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Credential removal readiness JSON: $Path"
}

function Export-DecomCredentialRemovalReadinessCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ($Model.CredentialDetails -and @($Model.CredentialDetails).Count -gt 0) {
        $Model.CredentialDetails | Export-Csv -Path $Path -NoTypeInformation
    } else {
        [pscustomobject]@{
            ApplicationId = ''; DisplayName = ''; CredentialKeyId = ''
            CredentialType = ''; EndDateTime = ''; IsExpired = ''; ReadinessStatus = ''; ReadinessReason = ''
        } | Export-Csv -Path $Path -NoTypeInformation
    }
    Write-DecomOk "Credential removal readiness CSV: $Path"
}

function Export-DecomCredentialOwnerApprovalPacketMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $readyItems = @($Model.CredentialDetails | Where-Object { $_.ReadinessStatus -eq 'ReadyForApproval' })
    $rows = ($readyItems | ForEach-Object {
        "| $($_.DisplayName) | $($_.CredentialKeyId) | $($_.CredentialType) | $($_.EndDateTime) | ☐ |"
    }) -join "`n"

    $markdown = @"
# Credential Owner Approval Packet

**Client:** $($Model.ClientName)
**Engagement:** $($Model.EngagementId)
**Assessor:** $($Model.Assessor)
**Generated:** $($Model.GeneratedUtc)
**SchemaVersion:** $($Model.SchemaVersion)

## Purpose

This packet requires signature from the application owner authorizing removal of the expired credentials listed below.

## Credentials Requiring Approval

| Application | Credential KeyId | Type | Expired | Approved |
|---|---|---|---|---|
$rows

## Owner Acknowledgement

By signing below, the application owner confirms that the listed credentials are expired and authorizes their removal.

**Approver Name:** ___________________________
**Role:** ___________________________
**Signature:** ___________________________
**Date:** ___________________________

## Safety Notes

- Only exact credential KeyIds listed above will be removed.
- Rollback requires creating a new application credential through the platform engineering process.
- Secret material cannot be recovered after deletion.

---
© 2026 Albert Jee. All rights reserved.
"@

    $markdown | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Credential owner approval packet Markdown: $Path"
}

function Export-DecomCredentialOwnerApprovalPacketHtml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $readyItems = @($Model.CredentialDetails | Where-Object { $_.ReadinessStatus -eq 'ReadyForApproval' })
    $rows = ($readyItems | ForEach-Object {
        "<tr><td>$($_.DisplayName)</td><td>$($_.CredentialKeyId)</td><td>$($_.CredentialType)</td><td>$($_.EndDateTime)</td><td>☐</td></tr>"
    }) -join "`n"

    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Credential Owner Approval Packet — $($Model.ClientName)</title>
    <style>
        body { font-family: Segoe UI, sans-serif; margin: 2em; }
        table { border-collapse: collapse; width: 100%; }
        th { background: #1a1a2e; color: #fff; padding: 8px; }
        td { padding: 6px 8px; border-bottom: 1px solid #ddd; }
    </style>
</head>
<body>
<h1>Credential Owner Approval Packet</h1>
<p><strong>Client:</strong> $($Model.ClientName) | <strong>Engagement:</strong> $($Model.EngagementId) | <strong>Generated:</strong> $($Model.GeneratedUtc)</p>
<h2>Credentials Requiring Approval</h2>
<table>
<tr><th>Application</th><th>Credential KeyId</th><th>Type</th><th>Expired</th><th>Approved</th></tr>
$rows
</table>
<h2>Owner Acknowledgement</h2>
<p>Approver Name: ___________________________<br>
Role: ___________________________<br>
Signature: ___________________________<br>
Date: ___________________________</p>
<p><em>Secret material cannot be recovered after deletion.</em></p>
<hr><p style="font-size:0.8em">© 2026 Albert Jee. All rights reserved.</p>
</body></html>
"@
    $html | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Credential owner approval packet HTML: $Path"
}

function Export-DecomCredentialRollbackGuideMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $markdown = @"
# Credential Rollback Guide

**Client:** $($Model.ClientName)
**Engagement:** $($Model.EngagementId)
**Generated:** $($Model.GeneratedUtc)
**SchemaVersion:** $($Model.SchemaVersion)

## Important Notice

Rollback requires creating a new application credential through the application owner or platform engineering process.
Rev3.2 does not auto-rollback credential removal because secret material cannot be recovered after deletion.

## What Cannot Be Restored

- The exact secret value of a removed PasswordCredential cannot be recovered.
- The private key material of a removed KeyCredential cannot be recovered.
- Only the credential metadata (KeyId, display name, dates) is logged as evidence.

## Rollback Procedure

1. Contact the application owner to generate a new credential.
2. Update all dependent services and applications with the new credential.
3. Verify application functionality after the new credential is deployed.
4. Document the new credential in the organization's secrets management system.

## Removed Credentials

$(foreach ($c in $Model.CredentialDetails | Where-Object { $_.ReadinessStatus -eq 'ReadyForApproval' }) {
"- **$($c.DisplayName)** — KeyId: $($c.CredentialKeyId) — Type: $($c.CredentialType) — Expired: $($c.EndDateTime)"
})

---
© 2026 Albert Jee. All rights reserved.
"@

    $markdown | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Credential rollback guide Markdown: $Path"
}

function Export-DecomCredentialExceptionRegisterCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $exceptions = @($Model.CredentialDetails | Where-Object { $_.ReadinessStatus -like 'Blocked*' })
    if ($exceptions.Count -gt 0) {
        $exceptions | Select-Object ApplicationId, DisplayName, CredentialKeyId, CredentialType, EndDateTime, ReadinessStatus, ReadinessReason |
            Export-Csv -Path $Path -NoTypeInformation
    } else {
        [pscustomobject]@{
            ApplicationId = ''; DisplayName = ''; CredentialKeyId = ''
            CredentialType = ''; EndDateTime = ''; ReadinessStatus = ''; ReadinessReason = ''
        } | Export-Csv -Path $Path -NoTypeInformation
    }
    Write-DecomOk "Credential exception register CSV: $Path"
}

function Export-DecomCredentialHygieneEvidenceAppendixMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $markdown = @"
# Credential Hygiene Evidence Appendix

**Client:** $($Model.ClientName)
**Engagement:** $($Model.EngagementId)
**Generated:** $($Model.GeneratedUtc)
**SchemaVersion:** $($Model.SchemaVersion)
**ToolVersion:** $($Model.ToolVersion)

## Assessment Coverage

- Total Credentials Assessed: $($Model.CredentialCount)
- Expired: $($Model.ExpiredCredentialCount)
- Expiring Soon (Plan-Only): $($Model.ExpiringSoonCredentialCount)
- Ready for Approval: $($Model.ReadyForApprovalCount)

## Methodology

This assessment identifies expired application credentials using DEC-APP-005 findings
from the Entra Identity Decommissioning Control Plane. Only credentials with exact
KeyIds and confirmed expiration are candidates for removal.

## Evidence Chain

1. Assessment discovery identified credential metadata from Microsoft Graph.
2. Credential readiness was evaluated against the Rev3.2 safety model.
3. Only expired credentials with exact KeyIds are listed as ReadyForApproval.
4. Execution requires client-signed approval manifest with SchemaVersion 3.2 or higher.

---
© 2026 Albert Jee. All rights reserved.
"@

    $markdown | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Credential hygiene evidence appendix Markdown: $Path"
}

function Export-DecomCredentialAccessSummaryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Model,
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $summary = [pscustomobject]@{
        SchemaVersion        = $Model.SchemaVersion
        ToolVersion          = $Model.ToolVersion
        GeneratedUtc         = $Model.GeneratedUtc
        EngagementId         = $Model.EngagementId
        ClientName           = $Model.ClientName
        CredentialCount      = $Model.CredentialCount
        ExpiredCount         = $Model.ExpiredCredentialCount
        ReadyForApproval     = $Model.ReadyForApprovalCount
        BlockedTotal         = $Model.BlockedMissingCredentialKeyIdCount +
                               $Model.BlockedCredentialNotExpiredCount +
                               $Model.BlockedApplicationReadFailureCount +
                               $Model.BlockedNoApplicationOwnerCount +
                               $Model.BlockedProtectedApplicationCount +
                               $Model.BlockedCredentialTypeUnsupportedCount
        PlanOnlyCount        = $Model.PlanOnlyExpiringNotExpiredCount
    }

    $summary | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding UTF8
    Write-DecomOk "Credential access summary JSON: $Path"
}
