# NhiPatterns.psm1 - Rev4.46
# Shared pattern constants for NHI audit analysis.
# Used by NhiActivityLog.psm1 and NhiGraphApiAudit.psm1.
# Read-only patterns, no execution or mutation.

# Compliance-sensitive keywords for audit log analysis.
# Covers data-loss and compliance operations.
$script:ComplianceKeywords = @(
    'Delete'
    'Purge'
    'Hard.delete'
    'Retention'
    'Hold'
    'eDiscovery'
)

# Compliance-sensitive regex patterns for Graph API operation analysis.
$script:ComplianceSensitivePatterns = @(
    'Delete'
    'Purge'
    'Hard\.delete'
    'Retention'
    'Hold'
)

# Privilege escalation regex patterns for Graph API operation analysis.
$script:PrivilegeEscalationPatterns = @(
    'Add\.role'
    'Add\.admin'
    'Grant\.permission'
    'Create\.service\.principal'
    'Create\.application'
)

# High-risk operation regex patterns, compiled from compliance + privilege escalation.
$script:HighRiskOperationPatterns = @(
    'Delete'
    'Purge'
    'Hard\.delete'
    'Retention'
    'Hold'
    'Add\.role'
    'Add\.admin'
    'Grant\.permission'
    'Create\.service\.principal'
    'Create\.application'
)

function Get-NhiSharedPatterns {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        ComplianceKeywords           = $script:ComplianceKeywords
        ComplianceSensitivePatterns  = $script:ComplianceSensitivePatterns
        PrivilegeEscalationPatterns  = $script:PrivilegeEscalationPatterns
        HighRiskOperationPatterns    = $script:HighRiskOperationPatterns
    }
}

Export-ModuleMember -Function Get-NhiSharedPatterns