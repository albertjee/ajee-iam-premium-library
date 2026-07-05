# NhiActivityLog.psm1 - Rev4.46
# Pre-decom agentic identity activity audit.
# Read-only. No write cmdlets.
Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'NhiPatterns.psm1') -Force -DisableNameChecking

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
# Helper: _Compute-SignInBaseMetrics
# Single-pass iteration: counts success/failure/CA-blocks, tracks unique locations.
# Returns [hashtable] with SuccessCount, FailureCount, ConditionalAccessBlockCount,
# CaBlockSet (HashSet[string]), and UniqueIpCount.
# ---------------------------------------------------------------------------
function _Compute-SignInBaseMetrics {
    param(
        [object[]]$SignInEntries
    )

    $successCount = 0
    $failureCount = 0
    $caBlockCount = 0
    $uniqueIpSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($log in $SignInEntries) {
        $status = $log.Status
        $errorCode = 0
        if ($status -and $null -ne $status.ErrorCode) {
            $errorCode = [int]$status.ErrorCode
        }

        if ($errorCode -eq 0) {
            $successCount++
        }
        else {
            $failureCount++
        }

        $caStatus = $log.ConditionalAccessStatus
        if ($caStatus -and ($caStatus -eq 'block' -or ($errorCode -ge 53000 -and $errorCode -lt 53100))) {
            $caBlockCount++
        }

        if ($log.IPAddress) {
            $null = $uniqueIpSet.Add($log.Location)
        }
    }

    return @{
        SuccessCount               = $successCount
        FailureCount               = $failureCount
        ConditionalAccessBlockCount = $caBlockCount
        CaBlockSet                  = $uniqueIpSet
        UniqueIpCount               = $uniqueIpSet.Count
    }
}

# ---------------------------------------------------------------------------
# Helper: _Detect-SignInBurst
# Detects sign-in burst using sorted timestamps. For each index, finds the
# farthest index in the sorted list whose timestamp is within 60 minutes.
# Since both i and j traverse the array monotonically, this is O(n).
# Returns [hashtable] with MaxSignInInOneHour.
# ---------------------------------------------------------------------------
function _Detect-SignInBurst {
    param(
        [object[]]$SignInEntries
    )

    $maxPerHour = 0

    $timestamps = @($SignInEntries | ForEach-Object {
            try { [DateTime]$_.CreatedDateTime } catch { $null }
        } | Where-Object { $_ -ne $null })

    if ($timestamps.Count -gt 1) {
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

    return @{ MaxSignInInOneHour = $maxPerHour }
}

# ---------------------------------------------------------------------------
# Helper: _Detect-ImpossibleTravel
# Scans consecutive city-log pairs for location changes within 15 minutes.
# Input: $SignInEntries (sorted by CreatedDateTime, may contain null Location).
# Returns [hashtable] with ImpossibleTravelDetected ($true/$false).
# ---------------------------------------------------------------------------
function _Detect-ImpossibleTravel {
    param(
        [object[]]$SignInEntries
    )

    $impossibleTravelDetected = $false

    $cityLogs = @($SignInEntries | Where-Object { $_.Location -and $_.Location.Trim() -ne '' } |
            ForEach-Object {
                [PSCustomObject]@{
                    City = $_.Location
                    Time = try { [DateTime]$_.CreatedDateTime } catch { $null }
                }
            } | Where-Object { $_.Time -ne $null })

    $k = 0
    while ($k -lt $cityLogs.Count - 1) {
        $current = $cityLogs[$k]
        $next = $cityLogs[$k + 1]
        if ($current.City -ne $next.City) {
            $elapsed = ($next.Time - $current.Time).TotalMinutes
            if ($elapsed -gt 0 -and $elapsed -lt 15) {
                $impossibleTravelDetected = $true
                break
            }
        }
        $k++
    }

    return @{ ImpossibleTravelDetected = $impossibleTravelDetected }
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
            QuerySucceeded               = $false
            CapabilityAvailable          = $false
            SignInCount                  = 0
            SuccessCount                 = 0
            FailureCount                 = 0
            FailureRate                  = 0
            MaxSignInInOneHour            = 0
            ConditionalAccessBlockCount  = 0
            ImpossibleTravelDetected     = $false
            UniqueIpCount                = 0
            OverallRiskScore              = 0
            RiskSignals                  = @()
            Error                        = $SignInLogs.Error
        }
    }

    $signInEntries = Get-DecomQueryResultEntries -InputObject $SignInLogs

    if (-not $signInEntries -or $signInEntries.Count -eq 0) {
        return [PSCustomObject]@{
            QuerySucceeded               = $true
            CapabilityAvailable          = $true
            SignInCount                  = 0
            SuccessCount                 = 0
            FailureCount                 = 0
            FailureRate                  = 0
            MaxSignInInOneHour            = 0
            ConditionalAccessBlockCount  = 0
            ImpossibleTravelDetected     = $false
            UniqueIpCount                = 0
            OverallRiskScore              = 0
            RiskSignals                  = @()
        }
    }

    $sorted = $signInEntries | Sort-Object { try { [DateTime]$_.CreatedDateTime } catch { [DateTime]::MinValue } }

    $baseMetrics = _Compute-SignInBaseMetrics -SignInEntries $sorted
    $burstResult = _Detect-SignInBurst -SignInEntries $sorted
    $travelResult = _Detect-ImpossibleTravel -SignInEntries $sorted

    $successCount = $baseMetrics.SuccessCount
    $failureCount = $baseMetrics.FailureCount
    $conditionalAccessBlockCount = $baseMetrics.ConditionalAccessBlockCount
    $uniqueIpSet = $baseMetrics.CaBlockSet
    $signInCount = $sorted.Count
    $maxPerHour = $burstResult.MaxSignInInOneHour
    $impossibleTravelDetected = $travelResult.ImpossibleTravelDetected

    $failureRate = 0.0
    if ($signInCount -gt 0) {
        $failureRate = [math]::Round($failureCount / $signInCount, 4)
    }

    $riskSignals = @()
    if ($failureRate -gt 0.3) {
        $riskSignals += "High failure rate: $([math]::Round($failureRate * 100, 1))%"
    }
    if ($maxPerHour -gt 10) {
        $riskSignals += "Burst activity: $maxPerHour sign-ins in 1-hour window"
    }
    if ($impossibleTravelDetected) {
        $riskSignals += "Impossible travel: sign-ins from multiple cities in less than 15 minutes"
    }

    $riskScore = 0
    if ($failureRate -gt 0.3) { $riskScore += 30 }
    if ($maxPerHour -gt 10) { $riskScore += 25 }
    if ($impossibleTravelDetected) { $riskScore += 45 }
    if ($riskScore -gt 100) { $riskScore = 100 }

    return [PSCustomObject]@{
        QuerySucceeded               = $true
        CapabilityAvailable          = $true
        SignInCount                  = $signInCount
        SuccessCount                 = $successCount
        FailureCount                 = $failureCount
        FailureRate                  = $failureRate
        MaxSignInInOneHour            = $maxPerHour
        ConditionalAccessBlockCount  = $conditionalAccessBlockCount
        ImpossibleTravelDetected     = $impossibleTravelDetected
        UniqueIpCount                = $uniqueIpSet.Count
        OverallRiskScore              = $riskScore
        RiskSignals                  = $riskSignals
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
# Helper: _Classify-DirectoryEntry
# Classifies a single directory audit log entry across operation categories.
# Returns [hashtable] with UserModification, PrivilegedRoleChange, GroupMembershipChange,
# ApplicationConsentGrant, MailboxModification, PolicyModification, ComplianceEvasionMatch.
# ---------------------------------------------------------------------------
function _Classify-DirectoryEntry {
    param(
        [Parameter(Mandatory)]
        [object]$Log,

        [string]$ComplianceRegex
    )

    $operation   = $Log.OperationType
    $displayName = $Log.OperationDisplayName
    $matchedEvasion = $null

    $userModification = $false
    if ($operation -match 'Add|Update|Delete' -and $displayName -and ($displayName -match 'user|User')) {
        $userModification = $true
    }

    $privilegedRoleChange = $displayName -and ($displayName -match 'role|Role|privilege|Privilege')
    $groupMembershipChange = $displayName -and ($displayName -match 'group|Group|membership|Membership')
    $applicationConsentGrant = $displayName -and ($displayName -match 'consent|Consent|permission grant|PermissionGrant')
    $mailboxModification = $displayName -and ($displayName -match 'mailbox|Mailbox|inbox|Inbox')
    $policyModification = $displayName -and ($displayName -match 'policy|Policy|rule|Rule|settings|Settings')

    if ($displayName -and $ComplianceRegex -and ($displayName -match $ComplianceRegex)) {
        $matchedEvasion = $displayName
    }

    return @{
        UserModification        = $userModification
        PrivilegedRoleChange    = $privilegedRoleChange
        GroupMembershipChange   = $groupMembershipChange
        ApplicationConsentGrant = $applicationConsentGrant
        MailboxModification     = $mailboxModification
        PolicyModification      = $policyModification
        ComplianceEvasionMatch  = $matchedEvasion
    }
}

# ---------------------------------------------------------------------------
# Helper: _Aggregate-DirectoryMetrics
# Iterates $DirectoryEntries, calls _Classify-DirectoryEntry per entry,
# aggregates into counts and compliance-evasion HashSet.
# Returns [hashtable] with SuccessCount, FailureCount, and category counts.
# ---------------------------------------------------------------------------
function _Aggregate-DirectoryMetrics {
    param(
        [object[]]$DirectoryEntries,
        [string]$ComplianceRegex
    )

    $successCount = 0
    $failureCount = 0
    $userModificationCount = 0
    $privilegedRoleChangeCount = 0
    $groupMembershipChangeCount = 0
    $applicationConsentGrantCount = 0
    $mailboxModificationCount = 0
    $policyModificationCount = 0
    $complianceEvasionSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $riskSignals = @()

    foreach ($log in $DirectoryEntries) {
        $result = $log.Result
        if ($result -and $result -eq 'success') {
            $successCount++
        }
        else {
            $failureCount++
        }

        $classified = _Classify-DirectoryEntry -Log $log -ComplianceRegex $ComplianceRegex

        if ($classified.UserModification) { $userModificationCount++ }
        if ($classified.PrivilegedRoleChange) { $privilegedRoleChangeCount++ }
        if ($classified.GroupMembershipChange) { $groupMembershipChangeCount++ }
        if ($classified.ApplicationConsentGrant) { $applicationConsentGrantCount++ }
        if ($classified.MailboxModification) { $mailboxModificationCount++ }
        if ($classified.PolicyModification) { $policyModificationCount++ }
        if ($classified.ComplianceEvasionMatch) {
            $null = $complianceEvasionSet.Add($classified.ComplianceEvasionMatch)
        }
    }

    if ($complianceEvasionSet.Count -gt 0) {
        $riskSignals += "Compliance-sensitive operations detected: $($complianceEvasionSet.Count) audit entries"
    }

    return @{
        SuccessCount                 = $successCount
        FailureCount                 = $failureCount
        UserModificationCount        = $userModificationCount
        PrivilegedRoleChangeCount    = $privilegedRoleChangeCount
        GroupMembershipChangeCount   = $groupMembershipChangeCount
        ApplicationConsentGrantCount = $applicationConsentGrantCount
        MailboxModificationCount     = $mailboxModificationCount
        PolicyModificationCount      = $policyModificationCount
        ComplianceEvasionSet         = $complianceEvasionSet
        RiskSignals                  = $riskSignals
    }
}

# ---------------------------------------------------------------------------
# Helper: _Compute-DirectoryRiskScore
# Calculates additive risk score from aggregated directory metrics.
# Returns [int] capped at 100.
# ---------------------------------------------------------------------------
function _Compute-DirectoryRiskScore {
    param(
        [hashtable]$Metrics
    )

    $riskScore = 0
    if ($Metrics.PrivilegedRoleChangeCount -gt 0)     { $riskScore += 35 }
    if ($Metrics.UserModificationCount -gt 5)          { $riskScore += 20 }
    if ($Metrics.GroupMembershipChangeCount -gt 10)    { $riskScore += 15 }
    if ($Metrics.ApplicationConsentGrantCount -gt 0)    { $riskScore += 20 }
    if ($Metrics.ComplianceEvasionSet.Count -gt 0)     { $riskScore += 25 }
    if ($Metrics.PolicyModificationCount -gt 5)        { $riskScore += 15 }
    if ($riskScore -gt 100) { $riskScore = 100 }

    return $riskScore
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

    $patterns = Get-NhiSharedPatterns
    $complianceKeywords = $patterns.ComplianceKeywords
    $complianceRegex = '(' + ($complianceKeywords -join '|') + ')'

    $metrics = _Aggregate-DirectoryMetrics -DirectoryEntries $directoryEntries -ComplianceRegex $complianceRegex
    $successCount = $metrics.SuccessCount
    $failureCount = $metrics.FailureCount
    $userModificationCount = $metrics.UserModificationCount
    $privilegedRoleChangeCount = $metrics.PrivilegedRoleChangeCount
    $groupMembershipChangeCount = $metrics.GroupMembershipChangeCount
    $applicationConsentGrantCount = $metrics.ApplicationConsentGrantCount
    $mailboxModificationCount = $metrics.MailboxModificationCount
    $policyModificationCount = $metrics.PolicyModificationCount
    $complianceEvasionSignals = $metrics.ComplianceEvasionSet
    $riskSignals = $metrics.RiskSignals
    $directoryOperationCount = $directoryEntries.Count
    $riskScore = _Compute-DirectoryRiskScore -Metrics $metrics

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

    # Data-driven findings (ACT-002 through ACT-004)
    $_actStandardDefs = @(
        @{
            FindingId   = 'NHI-ACT-002'
            Condition   = { $signInAnalysis.QuerySucceeded -and $signInAnalysis.ImpossibleTravelDetected }
            Severity    = 'Critical'
            RiskScore   = 85
            Evidence    = 'Impossible travel detected: sign-ins from multiple geographic locations in physically impossible timeframes'
        },
        @{
            FindingId   = 'NHI-ACT-003'
            Condition   = { $signInAnalysis.QuerySucceeded -and $signInAnalysis.MaxSignInInOneHour -gt 10 }
            Severity    = 'High'
            RiskScore   = 60
            Evidence    = "Burst activity: $($signInAnalysis.MaxSignInInOneHour) sign-ins within 1-hour window"
            EvidenceEval = { "Burst activity: $($signInAnalysis.MaxSignInInOneHour) sign-ins within 1-hour window" }
        },
        @{
            FindingId    = 'NHI-ACT-004'
            Condition     = { $dirAnalysis.QuerySucceeded -and $dirAnalysis.ComplianceEvasionSignals -and $dirAnalysis.ComplianceEvasionSignals.Count -gt 0 }
            Severity      = 'Critical'
            RiskScore     = 95
            EvidenceEval  = { 'Compliance-sensitive directory operations detected: ' + ($dirAnalysis.ComplianceEvasionSignals -join '; ') }
        }
    )

    foreach ($def in $_actStandardDefs) {
        if (& $def.Condition) {
            $evidence = if ($def.EvidenceEval) { & $def.EvidenceEval } else { $def.Evidence }
            $findings += New-DecomFinding -FindingId $def.FindingId `
                -Category 'NHI Activity - Sign-in Activity' `
                -Severity $def.Severity `
                -RiskScore $def.RiskScore `
                -Evidence $evidence `
                -ObjectId $objectId `
                -DisplayName $displayName
        }
    }

    # ACT-001: Active sign-in (SignInCount > 0)
    if ($signInAnalysis.QuerySucceeded -and $signInAnalysis.SignInCount -gt 0) {
        $daysActive = [math]::Round(($endTime - $startTime).TotalDays, 0)
        if ($daysActive -eq 0) { $daysActive = 30 }
        $sev001 = if ($signInAnalysis.OverallRiskScore -lt 50) { 'Medium' } else { 'High' }
        $findings += New-DecomFinding -FindingId 'NHI-ACT-001' `
            -Category 'NHI Activity - Agent Sign-in Activity' `
            -Severity $sev001 `
            -RiskScore $signInAnalysis.OverallRiskScore `
            -Evidence "Agent active: $($signInAnalysis.SignInCount) sign-ins, $($signInAnalysis.SuccessCount) successful, $($signInAnalysis.FailureCount) failed in $($daysActive)-day window" `
            -ObjectId $objectId `
            -DisplayName $displayName
    }

    # ACT-005: No sign-in activity (informational)
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
