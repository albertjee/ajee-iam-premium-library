# NhiGraphApiAudit.psm1 - Rev4.46
# Pre-decom Graph API operation audit.
# Read-only. No write cmdlets.

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'NhiPatterns.psm1') -Force -DisableNameChecking

#---------------------------------------------------------------------------
# Function: Get-NhiAgentGraphApiAudit
#---------------------------------------------------------------------------
function Get-NhiAgentGraphApiAudit {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ObjectId,

        [Parameter(Mandatory = $false)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $false)]
        [datetime]$EndTime
    )

    $capabilityKey = 'NhiGraphApiAudit.Unavailable'
    if (-not (Test-DecomCapabilityAvailable -Key $capabilityKey)) {
        $state = Get-DecomCapabilityState -Key $capabilityKey
        return New-DecomUnavailableQueryResult -CapabilityKey $capabilityKey -Error ([string]$state.LastError) -ObjectId $ObjectId
    }

    try {
        # Build OData filter for initiatedBy/app/servicePrincipalId
        $filter = "initiatedBy/app/servicePrincipalId eq '{0}'" -f $ObjectId

        # Build time constraint if provided
        if ($PSBoundParameters.ContainsKey('StartTime') -or $PSBoundParameters.ContainsKey('EndTime')) {
            $timeConditions = @()
            if ($PSBoundParameters.ContainsKey('StartTime')) {
                $isoTime = $StartTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
                $timeConditions += "activityDateTime ge $isoTime"
            }
            if ($PSBoundParameters.ContainsKey('EndTime')) {
                $isoTime = $EndTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
                $timeConditions += "activityDateTime le $isoTime"
            }
            if ($timeConditions.Count -gt 0) {
                $filter = $filter + " and " + ($timeConditions -join " and ")
            }
        }

        # Select key properties to reduce payload
        $property = @(
            'Id',
            'Category',
            'ActivityDisplayName',
            'OperationType',
            'Result',
            'ResultReason',
            'TargetResources',
            'InitiatedBy',
            'activityDateTime'
        ) -join ','

        $auditLogs = Get-MgAuditLogDirectoryAudit `
            -Filter $filter `
            -All `
            -Property $property `
            -ErrorAction Stop

        return $auditLogs
    }
    catch {
        $message = "Get-NhiAgentGraphApiAudit failed for ObjectId '$ObjectId': $($_.Exception.Message)"
        $null = Set-DecomCapabilityUnavailable -Key $capabilityKey -Message $message -Error $_.Exception.Message
        return New-DecomUnavailableQueryResult -CapabilityKey $capabilityKey -Error $_.Exception.Message -ObjectId $ObjectId
    }
}

Export-ModuleMember -Function Get-NhiAgentGraphApiAudit

#---------------------------------------------------------------------------
# Helper: _Classify-GraphApiOperation
# Classifies a single Graph API audit log entry into operation categories.
# Returns a [hashtable] with: UserModification, RoleAssignment, ConsentGrant,
# MailboxModification, PolicyModification, ComplianceSensitive, PrivilegeEscalation.
#---------------------------------------------------------------------------
function _Classify-GraphApiOperation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Log,

        [string]$ComplianceRegex,
        [string]$PrivilegeRegex
    )

    $displayName = $Log.ActivityDisplayName
    if ([string]::IsNullOrEmpty($displayName)) {
        $displayName = ''
    }

    $userModification   = $displayName -match '(User|Member|Account|Password)'
    $roleAssignment     = $displayName -match '(Role|Admin|Privilege)'
    $consentGrant       = $displayName -match '(Consent|Permission|Grant)'
    $mailboxModification = $displayName -match '(Mailbox|Mail|Exchange)'
    $policyModification  = $displayName -match '(Policy|Conditional|MFA|Authentication)'
    $complianceSensitive = $ComplianceRegex -and ($displayName -match $ComplianceRegex)
    $privilegeEscalation = $PrivilegeRegex -and ($displayName -match $PrivilegeRegex)

    return @{
        UserModification    = $userModification
        RoleAssignment      = $roleAssignment
        ConsentGrant        = $consentGrant
        MailboxModification = $mailboxModification
        PolicyModification  = $policyModification
        ComplianceSensitive = $complianceSensitive
        PrivilegeEscalation = $privilegeEscalation
    }
}

#---------------------------------------------------------------------------
# Helper: _Aggregate-GraphApiMetrics
# Iterates $AuditLogs, calls _Classify-GraphApiOperation per entry,
# accumulates counts and computed metrics.
# Returns a [hashtable] with all counts, $false/$true for signals,
# and individual op counts.
#---------------------------------------------------------------------------
function _Aggregate-GraphApiMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$AuditLogs,

        [string]$ComplianceRegex,
        [string]$PrivilegeRegex
    )

    $totalOps = 0
    $successfulOps = 0
    $failedOps = 0
    $userMods = 0
    $roleAssign = 0
    $consentGrant = 0
    $mailboxMod = 0
    $policyMod = 0
    $complianceSensitive = 0
    $privilegeEscalation = 0

    foreach ($log in $AuditLogs) {
        $totalOps++
        $result = $log.Result
        if ($result -eq 'Success') {
            $successfulOps++
        }
        else {
            $failedOps++
        }

        $classified = _Classify-GraphApiOperation `
            -Log $log `
            -ComplianceRegex $ComplianceRegex `
            -PrivilegeRegex $PrivilegeRegex

        if ($classified.UserModification)    { $userMods++ }
        if ($classified.RoleAssignment)      { $roleAssign++ }
        if ($classified.ConsentGrant)        { $consentGrant++ }
        if ($classified.MailboxModification) { $mailboxMod++ }
        if ($classified.PolicyModification)  { $policyMod++ }
        if ($classified.ComplianceSensitive)  { $complianceSensitive++ }
        if ($classified.PrivilegeEscalation)  { $privilegeEscalation++ }
    }

    return @{
        TotalOps              = $totalOps
        SuccessfulOps         = $successfulOps
        FailedOps             = $failedOps
        UserMods              = $userMods
        RoleAssign            = $roleAssign
        ConsentGrant          = $consentGrant
        MailboxMod            = $mailboxMod
        PolicyMod             = $policyMod
        ComplianceSensitive   = $complianceSensitive
        PrivilegeEscalation    = $privilegeEscalation
    }
}

#---------------------------------------------------------------------------
# Helper: _Compute-GraphApiRiskScore
# Calculates additive risk score from aggregated Graph API metrics.
# Returns [hashtable] with OverallRiskScore (int capped at 100) and
# RiskSignals (array of human-readable signals).
#---------------------------------------------------------------------------
function _Compute-GraphApiRiskScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Metrics
    )

    $riskScore = 0
    $riskSignals = @()

    if ($Metrics.UserMods -gt 5) {
        $riskScore += 15
        $riskSignals += "High volume user modifications: $($Metrics.UserMods) operations"
    }
    if ($Metrics.RoleAssign -gt 0) {
        $riskScore += 25
        $riskSignals += "Role assignment activity detected: $($Metrics.RoleAssign) operations"
    }
    if ($Metrics.ConsentGrant -gt 3) {
        $riskScore += 20
        $riskSignals += "Excessive consent grants: $($Metrics.ConsentGrant) operations"
    }
    if ($Metrics.MailboxMod -gt 0) {
        $riskScore += 15
        $riskSignals += "Mailbox modifications: $($Metrics.MailboxMod) operations"
    }
    if ($Metrics.PolicyMod -gt 0) {
        $riskScore += 20
        $riskSignals += "Policy modifications: $($Metrics.PolicyMod) operations"
    }
    if ($Metrics.ComplianceSensitive -gt 0) {
        $riskScore += 30
        $riskSignals += "Compliance-sensitive operations: $($Metrics.ComplianceSensitive) operations"
    }
    if ($Metrics.PrivilegeEscalation -gt 0) {
        $riskScore += 35
        $riskSignals += "Privilege escalation activity: $($Metrics.PrivilegeEscalation) operations"
    }
    if ($Metrics.FailedOps -gt $Metrics.SuccessfulOps) {
        $riskScore += 10
        $riskSignals += "Operation failure rate exceeds success rate"
    }

    if ($riskScore -gt 100) { $riskScore = 100 }

    return @{
        OverallRiskScore = $riskScore
        RiskSignals      = $riskSignals
    }
}

#---------------------------------------------------------------------------
# Function: Invoke-NhiGraphApiOperationAnalysis
#---------------------------------------------------------------------------
function Invoke-NhiGraphApiOperationAnalysis {
    [CmdletBinding()]
    [OutputType([System.Object])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$AuditLogs,

        [Parameter(Mandatory = $false)]
        [string]$ObjectId
    )

    if (Test-DecomQueryUnavailableResult -InputObject $AuditLogs) {
        return [PSCustomObject]@{
            QuerySucceeded       = $false
            CapabilityAvailable  = $false
            PSTypeName           = 'NhiGraphApiAudit.AnalysisResult'
            TotalOperations      = 0
            SuccessfulOperations = 0
            FailedOperations     = 0
            FailureRate          = 0.0
            UserModificationOps  = 0
            RoleAssignmentOps    = 0
            ConsentGrantOps      = 0
            MailboxModificationOps = 0
            PolicyModificationOps = 0
            HighRiskOpCount      = 0
            ComplianceSensitiveOpCount = 0
            PrivilegeEscalationOpCount = 0
            OverallRiskScore     = 0
            RiskSignals          = @()
            Error                = $AuditLogs.Error
        }
    }

    # Handle empty input
    if ($null -eq $AuditLogs -or $AuditLogs.Count -eq 0) {
        return [PSCustomObject]@{
            QuerySucceeded       = $true
            CapabilityAvailable  = $true
            PSTypeName                    = 'NhiGraphApiAudit.AnalysisResult'
            TotalOperations               = 0
            SuccessfulOperations          = 0
            FailedOperations              = 0
            FailureRate                   = 0.0
            UserModificationOps           = 0
            RoleAssignmentOps             = 0
            ConsentGrantOps               = 0
            MailboxModificationOps        = 0
            PolicyModificationOps         = 0
            HighRiskOpCount              = 0
            ComplianceSensitiveOpCount    = 0
            PrivilegeEscalationOpCount   = 0
            OverallRiskScore              = 0
            RiskSignals                   = @()
        }
    }

    # Load shared patterns
    $patterns = Get-NhiSharedPatterns
    $complianceRegex = '(' + ($patterns.ComplianceSensitivePatterns -join '|') + ')'
    $privilegeRegex = '(' + ($patterns.PrivilegeEscalationPatterns -join '|') + ')'

    $metrics = _Aggregate-GraphApiMetrics -AuditLogs $AuditLogs -ComplianceRegex $complianceRegex -PrivilegeRegex $privilegeRegex
    $totalOps = $metrics.TotalOps
    $successfulOps = $metrics.SuccessfulOps
    $failedOps = $metrics.FailedOps
    $userMods = $metrics.UserMods
    $roleAssign = $metrics.RoleAssign
    $consentGrant = $metrics.ConsentGrant
    $mailboxMod = $metrics.MailboxMod
    $policyMod = $metrics.PolicyMod
    $complianceSensitive = $metrics.ComplianceSensitive
    $privilegeEscalation = $metrics.PrivilegeEscalation

    $failureRate = 0.0
    if ($totalOps -gt 0) {
        $failureRate = [decimal]($failedOps / $totalOps)
    }

    $riskResult = _Compute-GraphApiRiskScore -Metrics $metrics
    $riskScore = $riskResult.OverallRiskScore
    $riskSignals = $riskResult.RiskSignals

    # High-risk count: compliance-sensitive + privilege-escalation + role-assignment
    $highRiskCount = 0
    if ($complianceSensitive -gt 0) { $highRiskCount += $complianceSensitive }
    if ($privilegeEscalation -gt 0) { $highRiskCount += $privilegeEscalation }
    if ($roleAssign -gt 0) { $highRiskCount += $roleAssign }

    return [PSCustomObject]@{
        QuerySucceeded                = $true
        CapabilityAvailable           = $true
        PSTypeName                    = 'NhiGraphApiAudit.AnalysisResult'
        TotalOperations               = $totalOps
        SuccessfulOperations          = $successfulOps
        FailedOperations              = $failedOps
        FailureRate                   = $failureRate
        UserModificationOps           = $userMods
        RoleAssignmentOps             = $roleAssign
        ConsentGrantOps               = $consentGrant
        MailboxModificationOps        = $mailboxMod
        PolicyModificationOps         = $policyMod
        HighRiskOpCount               = $highRiskCount
        ComplianceSensitiveOpCount    = $complianceSensitive
        PrivilegeEscalationOpCount    = $privilegeEscalation
        OverallRiskScore              = $riskScore
        RiskSignals                   = $riskSignals
    }
}

Export-ModuleMember -Function Invoke-NhiGraphApiOperationAnalysis

#---------------------------------------------------------------------------
# Function: Invoke-NhiGraphApiAuditScan
#---------------------------------------------------------------------------
function Invoke-NhiGraphApiAuditScan {
    [CmdletBinding()]
    [OutputType([System.Object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$NhiObject,

        [Parameter(Mandatory = $false)]
        [datetime]$StartTime,

        [Parameter(Mandatory = $false)]
        [datetime]$EndTime
    )

    # Skip if not an agentic candidate
    if ($NhiObject -and $NhiObject.AgenticCandidate -ne $true) {
        return @()
    }

    # Get the ObjectId for the NHI
    $objectId = $NhiObject.ObjectId
    if ([string]::IsNullOrEmpty($objectId)) {
        Write-DecomWarn "Invoke-NhiGraphApiAuditScan: NhiObject has no Id, skipping"
        return @()
    }

    # Fetch audit logs
    $invokeParams = @{ ObjectId = $objectId }
    if ($PSBoundParameters.ContainsKey('StartTime')) {
        $invokeParams['StartTime'] = $StartTime
    }
    if ($PSBoundParameters.ContainsKey('EndTime')) {
        $invokeParams['EndTime'] = $EndTime
    }

    $auditLogs = Get-NhiAgentGraphApiAudit @invokeParams
    if (Test-DecomQueryUnavailableResult -InputObject $auditLogs) {
        return @()
    }
    $analysis = Invoke-NhiGraphApiOperationAnalysis -AuditLogs $auditLogs -ObjectId $objectId

    # Store analysis on NhiObject if available
    $displayName = if ($NhiObject.DisplayName) { $NhiObject.DisplayName } else { $objectId }
    if ($NhiObject.PSObject.Properties['GraphApiAuditAnalysis']) {
        $NhiObject.GraphApiAuditAnalysis = $analysis
    }

    # Data-driven finding emission — iterate standard definitions.
    # GRAPH-000 and GRAPH-001 (no-ops / general activity) are handled separately
    # below; remaining 6 finding types use a definition table.
    # Each definition: FindingId, MetricProperty, Threshold, Severity, RiskScore, Template.
    $_standardDefs = @(
        @{ FindingId = 'NHI-GRAPH-002'; MetricProp = 'UserModificationOps';          Threshold = 0;   Severity = 'High';     RiskScore = 65; Template = 'User modification operations: {0}' },
        @{ FindingId = 'NHI-GRAPH-003'; MetricProp = 'RoleAssignmentOps';            Threshold = 0;   Severity = 'Critical'; RiskScore = 90; Template = 'CRITICAL: Role assignment operations: {0}' },
        @{ FindingId = 'NHI-GRAPH-004'; MetricProp = 'ConsentGrantOps';              Threshold = 0;   Severity = 'High';     RiskScore = 75; Template = 'Application consent grants: {0}' },
        @{ FindingId = 'NHI-GRAPH-005'; MetricProp = 'ComplianceSensitiveOpCount';   Threshold = 0;   Severity = 'Critical'; RiskScore = 95; Template = 'CRITICAL: Compliance-sensitive operations: {0}' },
        @{ FindingId = 'NHI-GRAPH-006'; MetricProp = 'PolicyModificationOps';        Threshold = 0;   Severity = 'Critical'; RiskScore = 88; Template = 'CRITICAL: Security policy modifications: {0}' },
        @{ FindingId = 'NHI-GRAPH-007'; MetricProp = 'HighRiskOpCount';              Threshold = 0;   Severity = 'High';     RiskScore = 70; Template = 'High-risk operations: {0}' }
    )

    foreach ($def in $_standardDefs) {
        $metricValue = $analysis.($def.MetricProp)
        if ($analysis.QuerySucceeded -and $metricValue -gt $def.Threshold) {
            $findings.Add((
                New-DecomFinding `
                    -FindingId $def.FindingId `
                    -Category 'NHI Activity - Graph API Audit' `
                    -Severity $def.Severity `
                    -RiskScore $def.RiskScore `
                    -Evidence ($def.Template -f $metricValue) `
                    -ObjectId $objectId `
                    -DisplayName $displayName
            ))
        }
    }

    # GRAPH-000: No operations, GRAPH-001: Activity summary
    if ($analysis.QuerySucceeded -and $analysis.TotalOperations -eq 0) {
        $findings.Add((
            New-DecomFinding `
                -FindingId 'NHI-GRAPH-000' `
                -Category 'NHI Activity - Graph API Audit' `
                -Severity 'Informational' `
                -RiskScore 0 `
                -Evidence 'No Graph API operations detected in assessment window' `
                -ObjectId $objectId `
                -DisplayName $displayName
        ))
    }
    elseif ($analysis.QuerySucceeded -and $analysis.TotalOperations -gt 0) {
        $sev = if ($analysis.OverallRiskScore -lt 50) { 'Medium' } else { 'High' }
        $findings.Add((
            New-DecomFinding `
                -FindingId 'NHI-GRAPH-001' `
                -Category 'NHI Activity - Graph API Audit' `
                -Severity $sev `
                -RiskScore $analysis.OverallRiskScore `
                -Evidence "Agent initiated $($analysis.TotalOperations) Graph operations: $($analysis.SuccessfulOperations) successful, $($analysis.FailedOperations) failed" `
                -ObjectId $objectId `
                -DisplayName $displayName
        ))
    }

    # GRAPH-008: High failure rate (special: computed percentage)
    if ($analysis.QuerySucceeded -and $analysis.FailureRate -gt 0.5) {
        $failurePct = [math]::Round($analysis.FailureRate * 100, 1)
        $findings.Add((
            New-DecomFinding `
                -FindingId 'NHI-GRAPH-008' `
                -Category 'NHI Activity - Graph API Audit' `
                -Severity 'Medium' `
                -RiskScore 45 `
                -Evidence "High operation failure rate: ${failurePct}% failure rate ($($analysis.FailedOperations) of $($analysis.TotalOperations) operations failed)" `
                -ObjectId $objectId `
                -DisplayName $displayName
        ))
    }

    return $findings.ToArray()
}

Export-ModuleMember -Function Invoke-NhiGraphApiAuditScan
