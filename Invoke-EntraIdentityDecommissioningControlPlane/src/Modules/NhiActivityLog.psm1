# NhiActivityLog.psm1 - Rev4.1
# Pre-decom agentic identity activity audit.
# Read-only. No write cmdlets.
Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

# ---------------------------------------------------------------------------
# Helper: Get-ODataTimeFilter
# Constructs OData time filter string for date-based queries.
# ---------------------------------------------------------------------------
function Get-ODataTimeFilter {
    param(
        [DateTime]$StartTime,
        [DateTime]$EndTime,
        [string]$PropertyName = 'createdDateTime'
    )
    $filters = @()
    if ($StartTime) {
        $filters += "$PropertyName ge $((Get-Date $StartTime -Format 'yyyy-MM-ddTHH:mm:ssZ'))"
    }
    if ($EndTime) {
        $filters += "$PropertyName le $((Get-Date $EndTime -Format 'yyyy-MM-ddTHH:mm:ssZ'))"
    }
    if ($filters.Count -gt 0) {
        return $filters -join ' and '
    }
    return $null
}

# ---------------------------------------------------------------------------
# Export: Get-NhiAgentSignInLog
# Retrieves sign-in logs for a service principal or user.
# ---------------------------------------------------------------------------
function Get-NhiAgentSignInLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [ValidateSet('ServicePrincipal', 'User')]
        [string]$ObjectType,

        [DateTime]$StartTime = (Get-Date).AddDays(-30),
        [DateTime]$EndTime = (Get-Date)
    )

    $capabilityKey = 'NhiActivityLog.SignInLogs.Unavailable'
    if (-not (Test-DecomCapabilityAvailable -Key $capabilityKey)) {
        $state = Get-DecomCapabilityState -Key $capabilityKey
        return New-DecomUnavailableQueryResult -CapabilityKey $capabilityKey -Error ([string]$state.LastError) -ObjectId $ObjectId -ObjectType $ObjectType
    }

    try {
        if ($ObjectType -eq 'ServicePrincipal') {
            $filter = "servicePrincipalId eq '$ObjectId'"
        } else {
            $filter = "userId eq '$ObjectId'"
        }

        # Apply time constraint
        $timeFilter = Get-ODataTimeFilter -StartTime $StartTime -EndTime $EndTime
        if ($timeFilter) {
            $filter = "$filter and $timeFilter"
        }

        Get-MgBetaAuditLogSignIn -Filter $filter -All -ErrorAction Stop
    } catch {
        $message = "Get-NhiAgentSignInLog failed for $ObjectType '$ObjectId': $($_.Exception.Message)"
        $null = Set-DecomCapabilityUnavailable -Key $capabilityKey -Message $message -Error $_.Exception.Message
        return New-DecomUnavailableQueryResult -CapabilityKey $capabilityKey -Error $_.Exception.Message -ObjectId $ObjectId -ObjectType $ObjectType
    }
}

# ---------------------------------------------------------------------------
# Export: Invoke-NhiAgentSignInAnalysis
# Analyzes sign-in logs to produce risk signals and scores.
# ---------------------------------------------------------------------------
function Invoke-NhiAgentSignInAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SignInLogs,

        [string]$ObjectId
    )

    if (Test-DecomQueryUnavailableResult -InputObject $SignInLogs) {
        return [PSCustomObject]@{
            QuerySucceeded       = $false
            CapabilityAvailable  = $false
            SignInCount          = 0
            SuccessCount         = 0
            FailureCount         = 0
            FailureRate          = 0
            MaxSignInInOneHour   = 0
            ConditionalAccessBlockCount = 0
            ImpossibleTravelDetected = $false
            UniqueIpCount        = 0
            OverallRiskScore     = 0
            RiskSignals          = @()
            Error                = $SignInLogs.Error
        }
    }

    $signInEntries = Get-DecomQueryResultEntries -InputObject $SignInLogs

    # Handle empty input
    if (-not $signInEntries -or $signInEntries.Count -eq 0) {
        return [PSCustomObject]@{
            QuerySucceeded       = $true
            CapabilityAvailable  = $true
            SignInCount              = 0
            SuccessCount             = 0
            FailureCount             = 0
            FailureRate              = 0
            MaxSignInInOneHour       = 0
            ConditionalAccessBlockCount = 0
            ImpossibleTravelDetected = $false
            UniqueIpCount            = 0
            OverallRiskScore         = 0
            RiskSignals              = @()
        }
    }

    # Sort by CreatedDateTime ascending for temporal analysis
    $sorted = $signInEntries | Sort-Object { try { [DateTime]$_.CreatedDateTime } catch { [DateTime]::MinValue } }

    $successCount = 0
    $failureCount = 0
    $conditionalAccessBlockCount = 0
    $uniqueIpSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $riskSignals = @()

    foreach ($log in $sorted) {
        $status = $log.Status
        $errorCode = 0
        if ($status) {
            if ($status.ErrorCode -ne $null) { $errorCode = [int]$status.ErrorCode }
        }

        if ($errorCode -eq 0) {
            $successCount++
        } else {
            $failureCount++
        }

        # Conditional Access blocking - error code 53000 series, or ConditionalAccessStatus = block
        $caStatus = $log.ConditionalAccessStatus
        if ($caStatus -and ($caStatus -eq 'block' -or $status.ErrorCode -ge 53000 -and $status.ErrorCode -lt 53100)) {
            $conditionalAccessBlockCount++
        }

        if ($log.IPAddress) {
            $null = $uniqueIpSet.Add($log.Location)
        }
    }

    $signInCount = $sorted.Count
    $failureRate = 0.0
    if ($signInCount -gt 0) {
        $failureRate = [math]::Round($failureCount / $signInCount, 4)
    }

    # Failure rate signal
    if ($failureRate -gt 0.3) {
        $riskSignals += "High failure rate: $([math]::Round($failureRate * 100, 1))%"
    }

    # Burst detection: > 10 sign-ins in any 1-hour rolling window
    $maxPerHour = 0
    if ($sorted.Count -gt 1) {
        $timestamps = @($sorted | ForEach-Object {
            try { [DateTime]$_.CreatedDateTime } catch { $null }
        } | Where-Object { $_ -ne $null })

        if ($timestamps.Count -gt 0) {
            $sortedTimestamps = $timestamps | Sort-Object
            $i = 0
            $j = 0
            while ($i -lt $sortedTimestamps.Count) {
                while ($j -lt $sortedTimestamps.Count -and
                    ($sortedTimestamps[$j] - $sortedTimestamps[$i]).TotalMinutes -le 60) {
                    $j++
                }
                $windowCount = $j - $i
                if ($windowCount -gt $maxPerHour) { $maxPerHour = $windowCount }
                $i++
            }
        }
    }

    if ($maxPerHour -gt 10) {
        $riskSignals += "Burst activity: $maxPerHour sign-ins in 1-hour window"
    }

    # Impossible travel detection: different cities, elapsed < 15 minutes
    $impossibleTravelDetected = $false
    if ($sorted.Count -gt 1) {
        $cityLogs = @($sorted | Where-Object { $_.Location -and $_.Location.Trim() -ne '' } |
            ForEach-Object {
                [PSCustomObject]@{
                    City = $_.Location
                    Time = try { [DateTime]$_.CreatedDateTime } catch { $null }
                }
            } | Where-Object { $_.Time -ne $null })

        if ($cityLogs.Count -gt 1) {
            for ($k = 0; $k -lt $cityLogs.Count - 1; $k++) {
                $current = $cityLogs[$k]
                $next = $cityLogs[$k + 1]
                if ($current.City -ne $next.City) {
                    $elapsed = ($next.Time - $current.Time).TotalMinutes
                    if ($elapsed -gt 0 -and $elapsed -lt 15) {
                        $impossibleTravelDetected = $true
                        break
                    }
                }
            }
        }
    }

    if ($impossibleTravelDetected) {
        $riskSignals += "Impossible travel: sign-ins from multiple cities in less than 15 minutes"
    }

    # Calculate overall risk score (cap at 100)
    $riskScore = 0
    if ($failureRate -gt 0.3) { $riskScore += 30 }
    if ($maxPerHour -gt 10) { $riskScore += 25 }
    if ($impossibleTravelDetected) { $riskScore += 45 }
    if ($riskScore -gt 100) { $riskScore = 100 }

    return [PSCustomObject]@{
        QuerySucceeded             = $true
        CapabilityAvailable        = $true
        SignInCount                 = $signInCount
        SuccessCount               = $successCount
        FailureCount               = $failureCount
        FailureRate                = $failureRate
        MaxSignInInOneHour          = $maxPerHour
        ConditionalAccessBlockCount = $conditionalAccessBlockCount
        ImpossibleTravelDetected   = $impossibleTravelDetected
        UniqueIpCount              = $uniqueIpSet.Count
        OverallRiskScore            = $riskScore
        RiskSignals                = $riskSignals
    }
}

# ---------------------------------------------------------------------------
# Export: Get-NhiAgentDirectoryAuditLog
# Retrieves directory audit logs initiated by a specific service principal.
# ---------------------------------------------------------------------------
function Get-NhiAgentDirectoryAuditLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ObjectId,

        [DateTime]$StartTime = (Get-Date).AddDays(-30),
        [DateTime]$EndTime = (Get-Date)
    )

    $capabilityKey = 'NhiActivityLog.DirectoryAuditLogs.Unavailable'
    if (-not (Test-DecomCapabilityAvailable -Key $capabilityKey)) {
        $state = Get-DecomCapabilityState -Key $capabilityKey
        return New-DecomUnavailableQueryResult -CapabilityKey $capabilityKey -Error ([string]$state.LastError) -ObjectId $ObjectId
    }

    try {
        $filter = "initiatedBy/app/servicePrincipalId eq '$ObjectId'"

        $timeFilter = Get-ODataTimeFilter -StartTime $StartTime -EndTime $EndTime -PropertyName 'activityDateTime'
        if ($timeFilter) {
            $filter = "$filter and $timeFilter"
        }

        Get-MgAuditLogDirectoryAudit -Filter $filter -All -ErrorAction Stop
    } catch {
        $message = "Get-NhiAgentDirectoryAuditLog failed for '$ObjectId': $($_.Exception.Message)"
        $null = Set-DecomCapabilityUnavailable -Key $capabilityKey -Message $message -Error $_.Exception.Message
        return New-DecomUnavailableQueryResult -CapabilityKey $capabilityKey -Error $_.Exception.Message -ObjectId $ObjectId
    }
}

# ---------------------------------------------------------------------------
# Export: Invoke-NhiAgentDirectoryAuditAnalysis
# Analyzes directory audit logs to produce compliance risk signals.
# ---------------------------------------------------------------------------
function Invoke-NhiAgentDirectoryAuditAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$DirectoryLogs,

        [string]$ObjectId
    )

    if (Test-DecomQueryUnavailableResult -InputObject $DirectoryLogs) {
        return [PSCustomObject]@{
            QuerySucceeded       = $false
            CapabilityAvailable  = $false
            DirectoryOperationCount      = 0
            SuccessCount                 = 0
            FailureCount                 = 0
            UserModificationCount        = 0
            PrivilegedRoleChangeCount   = 0
            GroupMembershipChangeCount  = 0
            ApplicationConsentGrantCount = 0
            MailboxModificationCount     = 0
            PolicyModificationCount      = 0
            ComplianceEvasionSignals     = @()
            OverallRiskScore             = 0
            RiskSignals                  = @()
            Error                        = $DirectoryLogs.Error
        }
    }

    $directoryEntries = Get-DecomQueryResultEntries -InputObject $DirectoryLogs

    if (-not $directoryEntries -or $directoryEntries.Count -eq 0) {
        return [PSCustomObject]@{
            QuerySucceeded       = $true
            CapabilityAvailable  = $true
            DirectoryOperationCount      = 0
            SuccessCount                 = 0
            FailureCount                 = 0
            UserModificationCount        = 0
            PrivilegedRoleChangeCount   = 0
            GroupMembershipChangeCount  = 0
            ApplicationConsentGrantCount = 0
            MailboxModificationCount     = 0
            PolicyModificationCount      = 0
            ComplianceEvasionSignals     = @()
            OverallRiskScore             = 0
            RiskSignals                  = @()
        }
    }

    $complianceKeywords = @('Delete', 'Purge', 'Hard.delete', 'Retention', 'Hold', 'eDiscovery')
    $complianceRegex = '(' + ($complianceKeywords -join '|') + ')'

    $successCount = 0
    $failureCount = 0
    $userModificationCount = 0
    $privilegedRoleChangeCount = 0
    $groupMembershipChangeCount = 0
    $applicationConsentGrantCount = 0
    $mailboxModificationCount = 0
    $policyModificationCount = 0
    $complianceEvasionSignals = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $riskSignals = @()

    foreach ($log in $directoryEntries) {
        $operation = $log.OperationType
        $displayName = $log.OperationDisplayName

        $result = $log.Result
        if ($result -and $result -eq 'success') {
            $successCount++
        } else {
            $failureCount++
        }

        # Operation categorization based on OperationType and OperationDisplayName
        if ($operation -match 'Add' -and $displayName -and ($displayName -match 'user|User')) {
            $userModificationCount++
        }
        if ($operation -match 'Update' -and $displayName -and ($displayName -match 'user|User')) {
            $userModificationCount++
        }
        if ($operation -match 'Delete' -and $displayName -and ($displayName -match 'user|User')) {
            $userModificationCount++
        }

        if ($displayName -and ($displayName -match 'role|Role|privilege|Privilege')) {
            $privilegedRoleChangeCount++
        }

        if ($displayName -and ($displayName -match 'group|Group|membership|Membership')) {
            $groupMembershipChangeCount++
        }

        if ($displayName -and ($displayName -match 'consent|Consent|permission grant|PermissionGrant')) {
            $applicationConsentGrantCount++
        }

        if ($displayName -and ($displayName -match 'mailbox|Mailbox|inbox|Inbox')) {
            $mailboxModificationCount++
        }

        if ($displayName -and ($displayName -match 'policy|Policy|rule|Rule|settings|Settings')) {
            $policyModificationCount++
        }

        # Compliance evasion detection
        if ($displayName -and $displayName -match $complianceRegex) {
            $matchedKeyword = $complianceKeywords | Where-Object { $displayName -match $_ } | Select-Object -First 1
            if ($matchedKeyword) {
                $null = $complianceEvasionSignals.Add($displayName)
            }
        }
    }

    # Add compliance evasion signals to risk signals
    if ($complianceEvasionSignals.Count -gt 0) {
        $riskSignals += "Compliance-sensitive operations detected: $($complianceEvasionSignals.Count) audit entries"
    }

    # Build directory operation count
    $directoryOperationCount = $directoryEntries.Count

    # Calculate overall risk score
    $riskScore = 0
    if ($privilegedRoleChangeCount -gt 0) { $riskScore += 35 }
    if ($userModificationCount -gt 5) { $riskScore += 20 }
    if ($groupMembershipChangeCount -gt 10) { $riskScore += 15 }
    if ($applicationConsentGrantCount -gt 0) { $riskScore += 20 }
    if ($complianceEvasionSignals.Count -gt 0) { $riskScore += 25 }
    if ($policyModificationCount -gt 5) { $riskScore += 15 }
    if ($riskScore -gt 100) { $riskScore = 100 }

    return [PSCustomObject]@{
        QuerySucceeded                = $true
        CapabilityAvailable           = $true
        DirectoryOperationCount       = $directoryOperationCount
        SuccessCount                  = $successCount
        FailureCount                  = $failureCount
        UserModificationCount         = $userModificationCount
        PrivilegedRoleChangeCount     = $privilegedRoleChangeCount
        GroupMembershipChangeCount    = $groupMembershipChangeCount
        ApplicationConsentGrantCount  = $applicationConsentGrantCount
        MailboxModificationCount       = $mailboxModificationCount
        PolicyModificationCount       = $policyModificationCount
        ComplianceEvasionSignals      = @($complianceEvasionSignals)
        OverallRiskScore              = $riskScore
        RiskSignals                   = $riskSignals
    }
}

# ---------------------------------------------------------------------------
# Export: Invoke-NhiActivityLogScan
# Orchestrates the full activity audit scan and generates findings.
# ---------------------------------------------------------------------------
function Invoke-NhiActivityLogScan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$NhiObject,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$SignInLogs,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$DirectoryLogs
    )

    # Skip if not an agentic candidate
    if ($NhiObject.AgenticCandidate -ne $true) {
        return @()
    }

    $objectId = $NhiObject.ObjectId
    $displayName = $NhiObject.DisplayName

    # Analyze sign-in logs
    $signInAnalysis = Invoke-NhiAgentSignInAnalysis -SignInLogs $SignInLogs -ObjectId $objectId

    # Analyze directory audit logs
    $dirAnalysis = Invoke-NhiAgentDirectoryAuditAnalysis -DirectoryLogs $DirectoryLogs -ObjectId $objectId

    $findings = @()

    # Calculate assessment window in days
    $startTime = (Get-Date).AddDays(-30)
    $endTime = Get-Date
    $days = [math]::Round(($endTime - $startTime).TotalDays, 0)
    if ($days -eq 0) { $days = 30 }

    # NHI-ACT-001: Agent active sign-in (if SignInCount > 0)
    if ($signInAnalysis.QuerySucceeded -and $signInAnalysis.SignInCount -gt 0) {
        $severity = if ($signInAnalysis.OverallRiskScore -lt 50) { 'Medium' } else { 'High' }
        $daysActive = [math]::Round(($endTime - $startTime).TotalDays, 0)
        if ($daysActive -eq 0) { $daysActive = 30 }

        $findings += New-DecomFinding -FindingId 'NHI-ACT-001' `
            -Category 'NHI Activity - Agent Sign-in Activity' `
            -Severity $severity `
            -RiskScore $signInAnalysis.OverallRiskScore `
            -Evidence "Agent active: $($signInAnalysis.SignInCount) sign-ins, $($signInAnalysis.SuccessCount) successful, $($signInAnalysis.FailureCount) failed in $($daysActive)-day window" `
            -ObjectId $objectId `
            -DisplayName $displayName
    }

    # NHI-ACT-002: Impossible travel detected
    if ($signInAnalysis.QuerySucceeded -and $signInAnalysis.ImpossibleTravelDetected) {
        $findings += New-DecomFinding -FindingId 'NHI-ACT-002' `
            -Category 'NHI Activity - Impossible Travel' `
            -Severity 'Critical' `
            -RiskScore 85 `
            -Evidence 'Impossible travel detected: sign-ins from multiple geographic locations in physically impossible timeframes' `
            -ObjectId $objectId `
            -DisplayName $displayName
    }

    # NHI-ACT-003: Burst sign-in pattern (> 10 in 1-hour window)
    if ($signInAnalysis.QuerySucceeded -and $signInAnalysis.MaxSignInInOneHour -gt 10) {
        $findings += New-DecomFinding -FindingId 'NHI-ACT-003' `
            -Category 'NHI Activity - Burst Sign-in Pattern' `
            -Severity 'High' `
            -RiskScore 60 `
            -Evidence "Burst activity: $($signInAnalysis.MaxSignInInOneHour) sign-ins within 1-hour window" `
            -ObjectId $objectId `
            -DisplayName $displayName
    }

    # NHI-ACT-004: Compliance evasion signals
    if ($dirAnalysis.QuerySucceeded -and $dirAnalysis.ComplianceEvasionSignals -and $dirAnalysis.ComplianceEvasionSignals.Count -gt 0) {
        $signalsJoined = $dirAnalysis.ComplianceEvasionSignals -join '; '

        $findings += New-DecomFinding -FindingId 'NHI-ACT-004' `
            -Category 'NHI Activity - Compliance Evasion Signal' `
            -Severity 'Critical' `
            -RiskScore 95 `
            -Evidence "Compliance-sensitive directory operations detected: $signalsJoined" `
            -ObjectId $objectId `
            -DisplayName $displayName
    }

    # NHI-ACT-005: No sign-in activity (informational)
    if ($signInAnalysis.QuerySucceeded -and $signInAnalysis.SignInCount -eq 0) {
        $findings += New-DecomFinding -FindingId 'NHI-ACT-005' `
            -Category 'NHI Activity - No Sign-in Activity' `
            -Severity 'Informational' `
            -RiskScore 0 `
            -Evidence "No sign-in activity detected in $($days)-day assessment window" `
            -ObjectId $objectId `
            -DisplayName $displayName
    }

    return $findings
}

# Export module members
Export-ModuleMember -Function @(
    'Get-NhiAgentSignInLog'
    'Invoke-NhiAgentSignInAnalysis'
    'Get-NhiAgentDirectoryAuditLog'
    'Invoke-NhiAgentDirectoryAuditAnalysis'
    'Invoke-NhiActivityLogScan'
)
