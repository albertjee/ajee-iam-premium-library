# NhiPostDecomAudit.psm1 - Rev4.1
# Post-execution attestation: detects policy overrides of decom actions.
# Read-only. No write cmdlets.
Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function Get-NhiPostDecomAuditLog {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [DateTime]$DecomTimestamp,

        [Parameter()]
        [int]$WindowMinutes = 60
    )

    $windowEnd = $DecomTimestamp.AddMinutes($WindowMinutes)
    $startStr  = $DecomTimestamp.ToUniversalTime().ToString('o')
    $endStr    = $windowEnd.ToUniversalTime().ToString('o')
    # Query by time window — filter locally by TargetResources to detect reversals
    # against the target object (not just actions initiated by it)
    $timeFilter = "createdDateTime ge $startStr and createdDateTime le $endStr"

    try {
        $entries = @()
        try {
            $entries = @(Get-MgAuditLogDirectoryAudit -Filter $timeFilter -All -ErrorAction SilentlyContinue)
        } catch {
            Write-DecomWarn "Get-NhiPostDecomAuditLog: Graph query failed for ObjectId '$ObjectId': $($_.Exception.Message)"
        }
        # Filter to entries that target the ObjectId (catches policy reversals by other SPs)
        $windowed = @($entries | Where-Object {
            $entry = $_
            $targetsObject = $false
            if ($entry.TargetResources) {
                $targetsObject = [bool]($entry.TargetResources | Where-Object { $_.Id -eq $ObjectId })
            }
            $targetsObject
        })
        return [array]@($windowed)
    } catch {
        Write-DecomWarn "Get-NhiPostDecomAuditLog: Failed for ObjectId '$ObjectId': $($_.Exception.Message)"
        return [array]@([PSCustomObject]@{ Id = 'query-failed'; ActivityDisplayName = 'QueryFailed'; Result = 'Error' })
    }
}

function Invoke-NhiPostDecomAttestation {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [string]$SnapshotManifestPath,

        [Parameter(Mandatory)]
        [DateTime]$DecomTimestamp,

        [Parameter()]
        [int]$WindowMinutes = 60
    )

    $manifestMissing  = -not (Test-Path $SnapshotManifestPath)
    $timestampInvalid = $DecomTimestamp -eq [DateTime]::MinValue
    $snapshotRecord   = $null

    if (-not $manifestMissing -and -not $timestampInvalid) {
        try {
            $snap = Get-Content $SnapshotManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($snap -and $snap.Records) {
                $snapshotRecord = $snap.Records | Where-Object { $_.ObjectId -eq $ObjectId } | Select-Object -First 1
            }
        } catch {
            Write-DecomWarn "Invoke-NhiPostDecomAttestation: Failed to read manifest: $($_.Exception.Message)"
        }
    }

    $disabledAtMissing = -not $snapshotRecord -or -not $snapshotRecord.DisabledAt

    if ($manifestMissing -or $disabledAtMissing -or $timestampInvalid) {
        $parts = @()
        if ($manifestMissing)    { $parts += 'snapshot manifest not found' }
        if ($disabledAtMissing)  { $parts += 'DisabledAt field missing' }
        if ($timestampInvalid)   { $parts += 'DecomTimestamp is MinValue' }
        $evidence = "Attestation INCOMPLETE: $($parts -join '; ') for ObjectId '$ObjectId'. Cannot verify decom action was taken or reversed."
        return @((New-DecomFinding -FindingId 'DEC-ATTEST-004' -Category 'NHI Post-Decom Attestation - Incomplete' -Severity 'High' -RiskScore 70 -Evidence $evidence -ObjectId $ObjectId -DisplayName $DisplayName))
    }

    $auditEntries = Get-NhiPostDecomAuditLog -ObjectId $ObjectId -DecomTimestamp $DecomTimestamp -WindowMinutes $WindowMinutes

    $overrideDetected      = $false
    $servicePrincipalReversal = $false
    $overridePattern = 'Enable.account|Re-enable|AccountEnabled'

    foreach ($entry in $auditEntries) {
        $entryName = if ($entry.ActivityDisplayName) { $entry.ActivityDisplayName } else { '' }
        $result    = if ($entry.Result)              { $entry.Result }              else { '' }
        if ($entryName -match $overridePattern -and $result -eq 'success') {
            $overrideDetected = $true
            if ($entry.InitiatedBy -and $entry.InitiatedBy.App -and $entry.InitiatedBy.App.ServicePrincipalId) {
                $servicePrincipalReversal = $true
            }
        }
    }

    $policyReversal = $overrideDetected -and $servicePrincipalReversal
    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()

    if (-not $overrideDetected) {
        $findings.Add((New-DecomFinding -FindingId 'DEC-ATTEST-001' -Category 'NHI Post-Decom Attestation - Pass' -Severity 'Informational' -RiskScore 0 -Evidence "Attestation PROVISIONAL PASS: No policy overrides detected in ${WindowMinutes}-minute post-decom window. Note: Entra audit log latency (15-30 min) means this result may not reflect reversals that have not yet landed in the log." -ObjectId $ObjectId -DisplayName $DisplayName))
    } elseif ($overrideDetected -and -not $policyReversal) {
        $findings.Add((New-DecomFinding -FindingId 'DEC-ATTEST-002' -Category 'NHI Post-Decom Attestation - Operator Action' -Severity 'Medium' -RiskScore 50 -Evidence 'Attestation WARNING: Account state change detected after decom. May be operator action. Review audit log.' -ObjectId $ObjectId -DisplayName $DisplayName))
    } else {
        $findings.Add((New-DecomFinding -FindingId 'DEC-ATTEST-003' -Category 'NHI Post-Decom Attestation - Policy Reversal' -Severity 'Critical' -RiskScore 90 -Evidence "Attestation FAILED: Automated policy or service principal reversed decom action within ${WindowMinutes} minutes. Decom may not be stable." -ObjectId $ObjectId -DisplayName $DisplayName))
    }

    return [array]@($findings)
}

Export-ModuleMember -Function @('Get-NhiPostDecomAuditLog','Invoke-NhiPostDecomAttestation')
