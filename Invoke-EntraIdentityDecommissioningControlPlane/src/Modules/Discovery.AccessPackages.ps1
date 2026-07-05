function _Get-DecomAccessPackageFindings {
    param(
        $disabledUsers,
        $guestsFull,
        [System.Collections.Generic.List[object]]$findings,
        $coverage
    )

    # --- Rev2.2 AP: Access Package assignment visibility ---
    $apCapabilityKey = 'AccessPackages.Unavailable'
    if (Test-DecomCapabilityAvailable -Key $apCapabilityKey) {
        try {
            # Check cmdlet availability first
            $apAssignCmdlet  = Get-Command 'Get-MgEntitlementManagementAssignment' -ErrorAction SilentlyContinue
            $apAssignCmdlet2 = Get-Command 'Get-MgIdentityGovernanceEntitlementManagementAccessPackageAssignment' -ErrorAction SilentlyContinue

            $apAssignments = $null
            if ($null -ne $apAssignCmdlet) {
                $apAssignments = @(Get-MgEntitlementManagementAssignment -All -ErrorAction Stop)
            } elseif ($null -ne $apAssignCmdlet2) {
                $apAssignments = @(Get-MgIdentityGovernanceEntitlementManagementAccessPackageAssignment -All -ErrorAction Stop)
            }

            if ($null -ne $apAssignments) {
                $coverage.EntitlementManagement  = $true
                $coverage.EntitlementAssignments = $true
                Write-DecomInfo "Access package assignment discovery: OK ($($apAssignments.Count) assignments)"

            # Build lookup sets
            $apDisabledIdSet = [System.Collections.Generic.HashSet[string]]::new()
            if ($disabledUsers -and $disabledUsers.Count -gt 0) {
                foreach ($u in $disabledUsers) { if ($u -and $u.Id) { [void]$apDisabledIdSet.Add([string]$u.Id) } }
            }
            $apGuestIdSet = [System.Collections.Generic.HashSet[string]]::new()
            if ($null -ne $guestsFull -and $guestsFull.Count -gt 0) {
                foreach ($g in $guestsFull) { if ($g -and $g.Id) { [void]$apGuestIdSet.Add([string]$g.Id) } }
            }

            $sensitiveKeywords = @('admin','privileged','global','security','breakglass','break-glass',
                                   'tier0','tier-0','pim','identity','entra')

            $ap004Emitted = $false

            foreach ($assignment in $apAssignments) {
                # Resolve principal ID
                $principalId = ''
                if ($assignment.AccessPackageSubject -and $assignment.AccessPackageSubject.ObjectId) {
                    $principalId = $assignment.AccessPackageSubject.ObjectId
                } elseif ($assignment.TargetId) {
                    $principalId = $assignment.TargetId
                }
                if (-not $principalId) { continue }

                # Resolve state — active if Delivered, active, or no state
                $state = if ($assignment.State) { $assignment.State.ToLower() } else { 'active' }
                if ($state -notin @('delivered','active','pendingdelivery','')) {
                    if ($state -in @('expired','canceled','rejected')) { continue }
                }

                # Resolve display name
                $principalName = ''
                $principalUpn  = ''
                if ($assignment.AccessPackageSubject) {
                    if ($assignment.AccessPackageSubject.DisplayName) { $principalName = $assignment.AccessPackageSubject.DisplayName }
                    if ($assignment.AccessPackageSubject.Email)       { $principalUpn  = $assignment.AccessPackageSubject.Email }
                }
                if (-not $principalName) { $principalName = $principalId }

                # Resolve access package name
                $pkgName = ''
                if ($assignment.AccessPackage -and $assignment.AccessPackage.DisplayName) {
                    $pkgName = $assignment.AccessPackage.DisplayName
                }

                # DEC-AP-001: Disabled user has active access package assignment
                if ($principalId -and $apDisabledIdSet.Contains($principalId)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-AP-001' `
                        -Category          'Governance' `
                        -Severity          'High' `
                        -RiskScore         70 `
                        -Confidence        'High' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Disabled user retains access package assignment$(if ($pkgName) {" for package: $pkgName"}). Review Entitlement Management lifecycle closure." `
                        -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
                        -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
                        -RecommendedAction "Review and remove access package assignment from disabled user $principalUpn" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Active access package assignment for disabled user represents lifecycle closure gap'))
                }
                # DEC-AP-002: Guest has access package assignment
                elseif ($principalId -and $apGuestIdSet.Contains($principalId)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-AP-002' `
                        -Category          'Governance' `
                        -Severity          'Medium' `
                        -RiskScore         52 `
                        -Confidence        'Medium' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Guest has access package assignment$(if ($pkgName) {" for package: $pkgName"}); sponsor or review status requires validation." `
                        -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
                        -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
                        -RecommendedAction "Confirm sponsor approval and review status for guest $principalUpn access package assignment" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Guest access package requires explicit sponsor validation'))
                }

                # DEC-AP-003: Assignment has no visible expiration evidence
                $hasExpiry = $false
                if ($assignment.Schedule -and $assignment.Schedule.Expiration) {
                    if ($assignment.Schedule.Expiration.EndDateTime -or
                        $assignment.Schedule.Expiration.Duration) {
                        $hasExpiry = $true
                    }
                }
                if (-not $hasExpiry -and $assignment.ExpiredDateTime) { $hasExpiry = $true }
                if (-not $hasExpiry) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-AP-003' `
                        -Category          'Governance' `
                        -Severity          'Medium' `
                        -RiskScore         48 `
                        -Confidence        'Medium' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Access package assignment$(if ($pkgName) {" for package: $pkgName"}) does not expose expiration evidence; review assignment lifecycle policy." `
                        -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
                        -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
                        -RecommendedAction 'Review access package lifecycle policy and set expiration for this assignment' `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Assignment without expiration evidence requires lifecycle review'))
                }

                # DEC-AP-005: Assignment linked to sensitive resource (heuristic)
                $isSensitive = $false
                if ($pkgName) {
                    foreach ($kw in $sensitiveKeywords) {
                        if ($pkgName.ToLower().Contains($kw)) { $isSensitive = $true; break }
                    }
                }
                if ($isSensitive) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-AP-005' `
                        -Category          'Governance' `
                        -Severity          'High' `
                        -RiskScore         68 `
                        -Confidence        'Medium' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Access package assignment appears linked to sensitive resource or group based on resource metadata/name heuristic." `
                        -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
                        -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
                        -RecommendedAction "Review access package assignment linked to sensitive resource '$pkgName'; confirm business justification and governance approval" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Sensitive resource heuristic match — Confidence: Medium'))
                }
            }

            # DEC-AP-004: Emit once — access review coverage could not be confirmed
            if (-not $ap004Emitted) {
                $ap004Emitted = $true
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-AP-004' `
                    -Category          'Governance' `
                    -Severity          'Medium' `
                    -RiskScore         44 `
                    -Confidence        'Low' `
                    -ObjectType        'Tenant' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'Access Package Review Coverage' `
                    -UserPrincipalName '' `
                    -Evidence          'Access package review coverage could not be confirmed from available Graph data.' `
                    -EvidenceSource    'identityGovernance/entitlementManagement/accessPackages' `
                    -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/accessPackages' `
                    -RecommendedAction 'Grant AccessReview.Read.All and re-run assessment for full access review coverage' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Access review coverage gap — not a finding against tenant configuration'))
            }

            } else {
                $null = Set-DecomCapabilityUnavailable -Key $apCapabilityKey -Message 'Access package assignment cmdlets unavailable in installed Graph module'
            }
        } catch {
            $null = Set-DecomCapabilityUnavailable -Key $apCapabilityKey -Message "Access package assignment discovery unavailable (EntitlementManagement.Read.All required): $($_.Exception.Message)" -Error $_.Exception.Message
        }
    }
}
