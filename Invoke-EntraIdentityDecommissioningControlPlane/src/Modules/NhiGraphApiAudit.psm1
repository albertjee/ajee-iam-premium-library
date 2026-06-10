# NhiGraphApiAudit.psm1 - Rev4.1
# Pre-decom Graph API operation audit.
# Read-only. No write cmdlets.

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

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

    try {
        # Build OData filter for initiatedBy/app/servicePrincipalId
        $filter = "initiatedBy/app/servicePrincipalId eq '{0}'" -f $ObjectId

        # Build time constraint if provided
        if ($PSBoundParameters.ContainsKey('StartTime') -or $PSBoundParameters.ContainsKey('EndTime')) {
            $timeConditions = @()
            if ($PSBoundParameters.ContainsKey('StartTime')) {
                $isoTime = $StartTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
                $timeConditions += "createdDateTime ge $isoTime"
            }
            if ($PSBoundParameters.ContainsKey('EndTime')) {
                $isoTime = $EndTime.ToString('yyyy-MM-ddTHH:mm:ssZ')
                $timeConditions += "createdDateTime le $isoTime"
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
            'createdDateTime'
        ) -join ','

        $auditLogs = Get-MgAuditLogDirectoryAudit `
            -Filter $filter `
            -All `
            -Property $property `
            -ErrorAction Stop

        return $auditLogs
    }
    catch {
        Write-DecomWarn "Get-NhiAgentGraphApiAudit failed for ObjectId '$ObjectId': $($_.Exception.Message)"
        return @()
    }
}

Export-ModuleMember -Function Get-NhiAgentGraphApiAudit

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

    # Handle empty input
    if ($null -eq $AuditLogs -or $AuditLogs.Count -eq 0) {
        return [PSCustomObject]@{
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

    # Classify operations by ActivityDisplayName
    $totalOps = $AuditLogs.Count
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
        # Check result status
        $result = $log.Result
        if ($result -eq 'Success') {
            $successfulOps++
        }
        else {
            $failedOps++
        }

        # Classify by ActivityDisplayName using regex
        $displayName = $log.ActivityDisplayName
        if ([string]::IsNullOrEmpty($displayName)) {
            continue
        }

        # User modification operations
        if ($displayName -match '(User|Member|Account|Password)') {
            $userMods++
        }

        # Role assignment operations
        if ($displayName -match '(Role|Admin|Privilege)') {
            $roleAssign++
        }

        # Consent grant operations
        if ($displayName -match '(Consent|Permission|Grant)') {
            $consentGrant++
        }

        # Mailbox modification operations
        if ($displayName -match '(Mailbox|Mail|Exchange)') {
            $mailboxMod++
        }

        # Policy modification operations
        if ($displayName -match '(Policy|Conditional|MFA|Authentication)') {
            $policyMod++
        }

        # Compliance-sensitive operations
        if ($displayName -match '(Delete|Purge|Hard.delete|Retention|Hold)') {
            $complianceSensitive++
        }

        # Privilege escalation operations
        if ($displayName -match '(Add.role|Add.admin|Grant.permission|Create.service.principal|Create.application)') {
            $privilegeEscalation++
        }
    }

    # Calculate failure rate
    $failureRate = 0.0
    if ($totalOps -gt 0) {
        $failureRate = [decimal]($failedOps / $totalOps)
    }

    # Calculate risk score (additive, cap at 100)
    $riskScore = 0

    if ($userMods -gt 5) {
        $riskScore += 15
    }
    if ($roleAssign -gt 0) {
        $riskScore += 25
    }
    if ($consentGrant -gt 3) {
        $riskScore += 20
    }
    if ($mailboxMod -gt 0) {
        $riskScore += 15
    }
    if ($policyMod -gt 0) {
        $riskScore += 20
    }
    if ($complianceSensitive -gt 0) {
        $riskScore += 30
    }
    if ($privilegeEscalation -gt 0) {
        $riskScore += 35
    }
    if ($failedOps -gt $successfulOps) {
        $riskScore += 10
    }

    # Cap at 100
    if ($riskScore -gt 100) {
        $riskScore = 100
    }

    # Build risk signals
    $riskSignals = @()
    if ($userMods -gt 5) {
        $riskSignals += "High volume user modifications: $userMods operations"
    }
    if ($roleAssign -gt 0) {
        $riskSignals += "Role assignment activity detected: $roleAssign operations"
    }
    if ($consentGrant -gt 3) {
        $riskSignals += "Excessive consent grants: $consentGrant operations"
    }
    if ($mailboxMod -gt 0) {
        $riskSignals += "Mailbox modifications: $mailboxMod operations"
    }
    if ($policyMod -gt 0) {
        $riskSignals += "Policy modifications: $policyMod operations"
    }
    if ($complianceSensitive -gt 0) {
        $riskSignals += "Compliance-sensitive operations: $complianceSensitive operations"
    }
    if ($privilegeEscalation -gt 0) {
        $riskSignals += "Privilege escalation activity: $privilegeEscalation operations"
    }
    if ($failedOps -gt $successfulOps) {
        $riskSignals += "Operation failure rate exceeds success rate"
    }

    # Calculate high-risk count
    $highRiskCount = 0
    if ($complianceSensitive -gt 0) { $highRiskCount += $complianceSensitive }
    if ($privilegeEscalation -gt 0) { $highRiskCount += $privilegeEscalation }
    if ($roleAssign -gt 0) { $highRiskCount += $roleAssign }

    return [PSCustomObject]@{
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
    $analysis = Invoke-NhiGraphApiOperationAnalysis -AuditLogs $auditLogs -ObjectId $objectId

    # Store analysis on NhiObject if available
    $displayName = if ($NhiObject.DisplayName) { $NhiObject.DisplayName } else { $objectId }
    if ($NhiObject.PSObject.Properties['GraphApiAuditAnalysis']) {
        $NhiObject.GraphApiAuditAnalysis = $analysis
    }

    # Generate findings — all New-DecomFinding calls on single lines (no backtick continuation)
    $findings = [System.Collections.Generic.List[PSCustomObject]]::new()

    if ($analysis.TotalOperations -eq 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-000' -Category 'NHI Activity - Graph API Audit' -Severity 'Informational' -RiskScore 0 -Evidence 'No Graph API operations detected in assessment window' -ObjectId $objectId -DisplayName $displayName))
    } else {
        $sev001 = if ($analysis.OverallRiskScore -lt 50) { 'Medium' } else { 'High' }
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-001' -Category 'NHI Activity - Graph API Audit' -Severity $sev001 -RiskScore $analysis.OverallRiskScore -Evidence "Agent initiated $($analysis.TotalOperations) Graph operations: $($analysis.SuccessfulOperations) successful, $($analysis.FailedOperations) failed" -ObjectId $objectId -DisplayName $displayName))
    }

    if ($analysis.UserModificationOps -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-002' -Category 'NHI Activity - Graph API Audit' -Severity 'High' -RiskScore 65 -Evidence "User modification operations: $($analysis.UserModificationOps)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($analysis.RoleAssignmentOps -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-003' -Category 'NHI Activity - Graph API Audit' -Severity 'Critical' -RiskScore 90 -Evidence "CRITICAL: Role assignment operations: $($analysis.RoleAssignmentOps)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($analysis.ConsentGrantOps -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-004' -Category 'NHI Activity - Graph API Audit' -Severity 'High' -RiskScore 75 -Evidence "Application consent grants: $($analysis.ConsentGrantOps)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($analysis.ComplianceSensitiveOpCount -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-005' -Category 'NHI Activity - Graph API Audit' -Severity 'Critical' -RiskScore 95 -Evidence "CRITICAL: Compliance-sensitive operations: $($analysis.ComplianceSensitiveOpCount)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($analysis.PolicyModificationOps -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-006' -Category 'NHI Activity - Graph API Audit' -Severity 'Critical' -RiskScore 88 -Evidence "CRITICAL: Security policy modifications: $($analysis.PolicyModificationOps)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($analysis.HighRiskOpCount -gt 0) {
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-007' -Category 'NHI Activity - Graph API Audit' -Severity 'High' -RiskScore 70 -Evidence "High-risk operations: $($analysis.HighRiskOpCount)" -ObjectId $objectId -DisplayName $displayName))
    }
    if ($analysis.FailureRate -gt 0.5) {
        $failurePct = [math]::Round($analysis.FailureRate * 100, 1)
        $findings.Add((New-DecomFinding -FindingId 'NHI-GRAPH-008' -Category 'NHI Activity - Graph API Audit' -Severity 'Medium' -RiskScore 45 -Evidence "High operation failure rate: ${failurePct}% failure rate ($($analysis.FailedOperations) of $($analysis.TotalOperations) operations failed)" -ObjectId $objectId -DisplayName $displayName))
    }

    return $findings.ToArray()
}

Export-ModuleMember -Function Invoke-NhiGraphApiAuditScan