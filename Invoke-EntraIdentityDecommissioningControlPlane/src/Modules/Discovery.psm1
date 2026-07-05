$script:ProtectedPatterns = @(
    'breakglass','break-glass','emergency','sync',
    'aadconnect','cloudsync','svc-','service-'
)

$null = Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

. (Join-Path $PSScriptRoot 'Discovery.Coverage.ps1')

. (Join-Path $PSScriptRoot 'Discovery.SyntheticFindings.ps1')

. (Join-Path $PSScriptRoot 'Discovery.UserGuestFindings.ps1')

. (Join-Path $PSScriptRoot 'Discovery.PimCaExclusion.ps1')

. (Join-Path $PSScriptRoot 'Discovery.AccessReview.ps1')

. (Join-Path $PSScriptRoot 'Discovery.AccessPackages.ps1')

. (Join-Path $PSScriptRoot 'Discovery.ReviewCorrelation.ps1')


function Invoke-DecomAssessmentDiscovery {
    param(
        [pscustomobject]$Context,
        [switch]$DemoMode
    )

    $coverage = New-DecomCoverage

    if ($DemoMode) {
        $coverage.Users                          = $true
        $coverage.Groups                         = $true
        $coverage.Applications                   = $true
        $coverage.ServicePrincipals              = $true
        $coverage.DirectoryRoles                 = $true
        $coverage.ConditionalAccess              = $true
        $coverage.PimEligibleAssignments         = $true
        $coverage.EntitlementAssignments         = $true
        $coverage.AccessReviews                  = $true
        $coverage.AccessReviewDefinitions        = $true
        $coverage.GuestReviewCorrelation         = $true
        $coverage.PimReviewCorrelation           = $true
        $coverage.AccessPackageReviewCorrelation = $true
        $coverage.CAExclusionReviewCorrelation   = $true
        if ($Context) { $Context | Add-Member -NotePropertyName Coverage -NotePropertyValue $coverage -Force }
        [object[]]$synth = @(Get-DecomSyntheticFindings)
        Write-Output -NoEnumerate $synth
        return
    }

    $findings      = [System.Collections.Generic.List[object]]::new()
    Clear-DecomFindingTraceContext

    # --- User findings: DEC-USER-001 + DEC-USER-002 (delegated to helper) ---
    $userResult   = _Get-DecomUserFindings -Context $Context
    if ($userResult.Findings) { $findings.AddRange($userResult.Findings) }
    $disabledUsers   = $userResult.DisabledUsers

    # --- Application and SPN findings: DEC-APP-001/002/003/004/005 + DEC-SPN-001 (delegated) ---
    $appResult   = _Get-DecomOwnedObjectFindings -Context $Context
    if ($appResult.Findings) { $findings.AddRange($appResult.Findings) }
    $apps        = $appResult.Apps

    # --- DEC-GUEST-001: Guests with stale sign-in (delegated) ---
    $guestResult = _Get-DecomGuestFindings -Context $Context
    if ($guestResult.Findings) { $findings.AddRange($guestResult.Findings) }
    $guests      = $guestResult.StaleGuests
    $guestsFull = $guestResult.GuestsAll

    # --- DEC-GUEST-003: Guests without sponsor metadata (calls Get-MgUserManager) ---
    $sponsorResult = _Get-DecomGuestSponsorMetadata -Context $Context -AllGuests $guestsFull
    if ($sponsorResult.Findings) { $findings.AddRange($sponsorResult.Findings) }
    $guestsWithoutSponsor = $sponsorResult.GuestsWithoutSponsor



    # --- Coverage probes for remaining areas (no detection logic yet) ---
    try {
        $null = Get-MgGroup -Top 1 -ErrorAction Stop
        $coverage.Groups = $true
        Write-DecomInfo "Group discovery: OK"
    } catch {
        Write-DecomWarn "Group discovery unavailable: $_"
    }

    try {
        $null = Get-MgServicePrincipal -Top 1 -ErrorAction Stop
        $null = $coverage.ServicePrincipals = $true
        Write-DecomInfo "Service principal discovery: OK"
    } catch {
        Write-DecomWarn "Service principal discovery unavailable: $_"
    }


    $auditCapabilityKey = 'AuditLogs.Unavailable'
    if (Test-DecomCapabilityAvailable -Key $auditCapabilityKey) {
        try {
            $null = Get-MgAuditLogSignIn -Top 1 -ErrorAction Stop
            $coverage.AuditLogs = $true
            Write-DecomInfo "Audit log discovery: OK"
        } catch {
            $null = Set-DecomCapabilityUnavailable -Key $auditCapabilityKey -Message "Audit log discovery unavailable (AuditLog.Read.All required / tenant not premium / B2C limitation): $($_.Exception.Message)" -Error $_.Exception.Message
        }
    }

    _Get-DecomAccessPackageFindings -disabledUsers $disabledUsers -guestsFull $guestsFull -findings $findings -coverage $coverage

    # Dedup HashSet for all Rev2.3 findings
    $emittedRev23 = [System.Collections.Generic.HashSet[string]]::new()

    #region Rev2.3 M2: Access review data collection
    # Extracted to Discovery.AccessReview.ps1. Returns access-review data object.
    $arData = _Get-DecomAccessReviewData -findings $findings -coverage $coverage -emittedRev23 $emittedRev23
    #endregion

    #region Rev2.3 PIM and CA Exclusion Discovery
    # Extracted to Discovery.PimCaExclusion.ps1. Mutates $findings/$coverage/$emittedRev23
    # by reference and sets $script:EligibleAssignments for the M4 correlation block below.
    _Get-DecomPimCaFindings -findings $findings -coverage $coverage -emittedRev23 $emittedRev23
    #endregion

    #region Rev2.3 Review Correlation (M2B/M3/M4/M5/M6)
    # Extracted to Discovery.ReviewCorrelation.ps1. Reads $script:EligibleAssignments (module-scope).
    # $govApiAvailable/$accessReviewData/etc. come from the M2 access-review-data collection block.
    _Get-DecomReviewCorrelationFindings -findings $findings -coverage $coverage `
        -emittedRev23 $emittedRev23 -govApiAvailable $arData.GovApiAvailable `
        -accessReviewData $arData.AccessReviewData -arInstances $arData.ArInstances `
        -arDecisions $arData.ArDecisions -arDefinitions $arData.ArDefinitions
    #endregion

    # =========================================================================
    # End of Rev2.3 sections
    # =========================================================================

    if ($Context) { $Context | Add-Member -NotePropertyName Coverage -NotePropertyValue $coverage -Force }
    [object[]]$result = @($findings)
    Write-Output -NoEnumerate $result
}
