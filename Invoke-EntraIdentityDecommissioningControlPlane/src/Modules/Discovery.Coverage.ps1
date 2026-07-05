function Get-DecomAvailableCommand {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $name }
    }

    return $null
}

function New-DecomCoverage {
    [ordered]@{
        Users                        = $false
        Groups                       = $false
        Applications                 = $false
        ServicePrincipals            = $false
        DirectoryRoles               = $false
        SignInLogs                   = $false
        AuditLogs                    = $false
        ConditionalAccess            = $false
        EntitlementManagement        = $false
        PimEligibleAssignments       = $false
        PimActivationEvidence        = $false
        EntitlementAssignments       = $false
        AccessPackagePolicies        = $false
        AccessReviewScheduleEvidence = $false
        AccessReviews                  = $false
        AccessReviewDefinitions        = $false
        AccessReviewInstances          = $false
        AccessReviewDecisions          = $false
        GuestReviewCorrelation         = $false
        PimReviewCorrelation           = $false
        AccessPackageReviewCorrelation = $false
        CAExclusionReviewCorrelation   = $false
        GovernanceEvidenceLimitations  = @()
    }
}
