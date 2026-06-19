# NhiComplianceAudit.psm1 - Rev4.1
# Pre-decom compliance hold bypass detection.
# Read-only. No write cmdlets.
Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function Get-NhiComplianceAuditLog {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ObjectId,

        [Parameter()]
        [datetime]$StartTime = ((Get-Date).AddDays(-30)),

        [Parameter()]
        [datetime]$EndTime = (Get-Date)
    )

    $startStr = $StartTime.ToUniversalTime().ToString('o')
    $endStr   = $EndTime.ToUniversalTime().ToString('o')
    Write-DecomWarn "Querying compliance audit logs for ObjectId: $ObjectId"
    Write-DecomWarn "Time window: $startStr to $endStr"

    try {
        $filter = "activityDateTime ge $startStr and activityDateTime le $endStr"
        try {
            $logs = @(Get-MgAuditLogDirectoryAudit -Filter $filter -All -ErrorAction Stop)
        } catch {
            Write-DecomWarn "Time-filtered query failed: $($_.Exception.Message)"
            return [PSCustomObject]@{ QuerySucceeded = $false; Entries = @(); Error = $_.Exception.Message }
        }
        Write-DecomWarn "Retrieved $($logs.Count) audit log entries"
        return [array]@($logs)
    } catch {
        Write-DecomWarn "Failed to retrieve audit logs: $($_.Exception.Message)"
        return [PSCustomObject]@{ QuerySucceeded = $false; Entries = @(); Error = $_.Exception.Message }
    }
}

function Invoke-NhiComplianceAuditScan {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [object]$NhiObject,

        [Parameter()]
        [datetime]$StartTime = ((Get-Date).AddDays(-30)),

        [Parameter()]
        [datetime]$EndTime = (Get-Date)
    )

    if ($null -eq $NhiObject) { return @() }
    if ($NhiObject.AgenticCandidate -ne $true) { return @() }

    $objectId    = if ($NhiObject.ObjectId)    { $NhiObject.ObjectId }    else { 'UNKNOWN' }
    $displayName = if ($NhiObject.DisplayName) { $NhiObject.DisplayName } else { $objectId }

    Write-DecomWarn "Starting compliance audit scan for ObjectId: $objectId"
    $auditResult = Get-NhiComplianceAuditLog -ObjectId $objectId -StartTime $StartTime -EndTime $EndTime

    # Handle query failure — suppress NHI-COMPLY-004 when Graph unavailable
    if ($auditResult -is [PSCustomObject] -and $auditResult.PSObject.Properties.Name -contains 'QuerySucceeded' -and -not $auditResult.QuerySucceeded) {
        Write-DecomWarn "Compliance audit query failed for ObjectId '$objectId': $($auditResult.Error)"
        return @()
    }
    $auditLogs = if ($auditResult -is [PSCustomObject] -and $auditResult.PSObject.Properties.Name -contains 'Entries') { $auditResult.Entries } else { @($auditResult) }

    $deleteOps     = @()
    $retentionOps  = @()
    $ediscoveryOps = @()

    foreach ($log in $auditLogs) {
        $activity = if ($log.ActivityDisplayName) { $log.ActivityDisplayName } else { '' }
        if ($activity -match 'Delete|Purge|HardDelete') { $deleteOps += $log }
        elseif ($activity -match 'Retention|Hold')       { $retentionOps += $log }
        elseif ($activity -match 'eDiscovery|Archive|Litigation') { $ediscoveryOps += $log }
    }

    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($deleteOps.Count -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-COMPLY-001' -Category 'NHI Activity - Compliance Audit' -Severity 'Critical' -RiskScore 95 -Evidence "Hard-delete or purge operations detected: $($deleteOps.Count)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($retentionOps.Count -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-COMPLY-002' -Category 'NHI Activity - Compliance Audit' -Severity 'Critical' -RiskScore 90 -Evidence "Retention policy or hold modification detected: $($retentionOps.Count)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($ediscoveryOps.Count -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-COMPLY-003' -Category 'NHI Activity - Compliance Audit' -Severity 'High' -RiskScore 75 -Evidence "eDiscovery operations detected: $($ediscoveryOps.Count)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($findings.Count -eq 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-COMPLY-004' -Category 'NHI Activity - Compliance Audit' -Severity 'Informational' -RiskScore 0 -Evidence 'No compliance-sensitive operations detected in successfully retrieved audit logs for the assessment window' -ObjectId $objectId -DisplayName $displayName))
    }

    Write-DecomWarn "Compliance audit scan complete for ObjectId: $objectId, findings: $($findings.Count)"
    return $findings.ToArray()
}

Export-ModuleMember -Function @('Get-NhiComplianceAuditLog','Invoke-NhiComplianceAuditScan')
