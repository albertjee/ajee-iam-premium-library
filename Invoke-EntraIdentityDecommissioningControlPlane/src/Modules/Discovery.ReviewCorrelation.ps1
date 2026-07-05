function _Get-DecomReviewCorrelationFindings {
    param(
        [System.Collections.Generic.List[object]]$findings,
        $coverage,
        [System.Collections.Generic.HashSet[string]]$emittedRev23,
        $govApiAvailable,
        $accessReviewData,
        $arInstances,
        $arDecisions,
        $arDefinitions
    )

    # --- Rev2.3 M2B: Live review decision findings (DEC-REV-002/003/004/005) ---
    if ($govApiAvailable -and $null -ne $accessReviewData) {

        $staleReviewThreshold90 = (Get-Date).AddDays(-90)

        # DEC-REV-002: Instances where EndDateTime is older than 90 days
        foreach ($inst in $arInstances) {
            $instEnd = $null
            try {
                if ($inst.EndDateTime) { $instEnd = [datetime]$inst.EndDateTime }
            } catch { $instEnd = $null }
            if ($null -ne $instEnd -and $instEnd -lt $staleReviewThreshold90) {
                $defId    = if ($inst.AccessReviewScheduleDefinitionId) { $inst.AccessReviewScheduleDefinitionId } else { 'unknown' }
                $rev002Key = "DEC-REV-002|$defId|$($inst.Id)"
                if ($emittedRev23.Add($rev002Key)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-002' `
                        -Category          'Access Review Governance' `
                        -Severity          'Medium' `
                        -RiskScore         45 `
                        -Confidence        'Medium' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          $defId `
                        -DisplayName       'Stale Access Review Instance' `
                        -UserPrincipalName '' `
                        -Evidence          "Access review instance ended $($instEnd.ToString('yyyy-MM-dd')) — more than 90 days ago. Review cadence may have lapsed." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions/{id}/instances' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions/{id}/instances' `
                        -RecommendedAction 'Verify review schedule and create new review instance to maintain governance cadence.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'Review instance ended >90 days ago — cadence may have lapsed'))
                }
            }
        }

        # DEC-REV-003: Instances with incomplete/pending status OR decisions with NotReviewed
        $incompleteInstIds = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($inst in $arInstances) {
            $instStatus = if ($inst.Status) { $inst.Status.ToLower() } else { '' }
            if ($instStatus -in @('inprogress','notstarted','starting')) {
                $defId    = if ($inst.AccessReviewScheduleDefinitionId) { $inst.AccessReviewScheduleDefinitionId } else { 'unknown' }
                $rev003Key = "DEC-REV-003|$defId|$($inst.Id)"
                if ($emittedRev23.Add($rev003Key)) {
                    [void]$incompleteInstIds.Add($inst.Id)
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-003' `
                        -Category          'Access Review Governance' `
                        -Severity          'Medium' `
                        -RiskScore         50 `
                        -Confidence        'Medium' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          $defId `
                        -DisplayName       'Incomplete Access Review' `
                        -UserPrincipalName '' `
                        -Evidence          "Access review instance has status '$($inst.Status)' — review is not yet complete. Pending reviewer action required." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions/{id}/instances' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions/{id}/instances' `
                        -RecommendedAction 'Follow up with reviewers to complete pending access review decisions.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'Incomplete review instance — reviewer action required'))
                }
            }
        }
        foreach ($dec in $arDecisions) {
            $decDecision = if ($dec.Decision) { $dec.Decision.ToLower() } else { '' }
            if ($decDecision -in @('notreviewed','')) {
                $instId   = if ($dec.AccessReviewInstanceId) { $dec.AccessReviewInstanceId } else { 'unknown' }
                $defId    = if ($dec.AccessReviewScheduleDefinitionId) { $dec.AccessReviewScheduleDefinitionId } else { 'unknown' }
                $rev003DecKey = "DEC-REV-003|dec|$defId|$instId"
                if ($emittedRev23.Add($rev003DecKey)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-003' `
                        -Category          'Access Review Governance' `
                        -Severity          'Medium' `
                        -RiskScore         50 `
                        -Confidence        'Medium' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          $defId `
                        -DisplayName       'Pending Review Decision' `
                        -UserPrincipalName '' `
                        -Evidence          "Access review decision has not been completed (Decision: '$($dec.Decision)') — reviewer action required." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions/{id}/instances/{id}/decisions' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions/{id}/instances/{id}/decisions' `
                        -RecommendedAction 'Follow up with reviewer to complete the pending access review decision.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'NotReviewed decision — reviewer has not acted'))
                }
            }
        }

        # DEC-REV-004: Definitions where scope can't correlate to any finding ObjectId
        $findingObjectIds = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($f in $findings) {
            if ($f.ObjectId -and $f.ObjectId -ne 'tenant-scope' -and $f.ObjectId -ne 'contoso.onmicrosoft.com') {
                [void]$findingObjectIds.Add($f.ObjectId)
            }
        }
        foreach ($def in $arDefinitions) {
            $defId = if ($def.Id) { $def.Id } else { 'unknown' }
            $scopeId   = ''
            $scopeType = ''
            try {
                if ($def.Scope -and $def.Scope.Query)     { $scopeId = $def.Scope.Query }
                if ($def.Scope -and $def.Scope.QueryType) { $scopeType = $def.Scope.QueryType }
            } catch { $scopeId = '' }

            $correlated = $false
            if ($scopeId) {
                foreach ($oid in $findingObjectIds) {
                    if ($scopeId.Contains($oid)) { $correlated = $true; break }
                }
            }
            if (-not $correlated) {
                $rev004Key = "DEC-REV-004|$defId"
                if ($emittedRev23.Add($rev004Key)) {
                    $defName = if ($def.DisplayName) { $def.DisplayName } else { $defId }
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-004' `
                        -Category          'Access Review Governance' `
                        -Severity          'Medium' `
                        -RiskScore         46 `
                        -Confidence        'Low' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          $defId `
                        -DisplayName       $defName `
                        -UserPrincipalName '' `
                        -Evidence          "Access review definition '$defName' scope could not be correlated to any detected finding — scope mapping is unclear." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                        -RecommendedAction 'Review scope configuration for this access review definition to ensure it covers relevant identities.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'Low-confidence scope correlation — review definition may cover undetected scope'))
                }
            }
        }

        # DEC-REV-005: Decisions with Deny/NotApproved where principal still has residual access
        $findingPrincipalIds = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($f in $findings) {
            if ($f.ObjectId -and $f.ObjectId -ne 'tenant-scope' -and $f.ObjectId -ne 'contoso.onmicrosoft.com') {
                [void]$findingPrincipalIds.Add($f.ObjectId)
            }
        }
        foreach ($dec in $arDecisions) {
            $decDecision = if ($dec.Decision) { $dec.Decision.ToLower() } else { '' }
            if ($decDecision -in @('deny','notapproved','remove')) {
                $principalId = if ($dec.Principal -and $dec.Principal.Id) { $dec.Principal.Id } else { '' }
                if ($principalId -and $findingPrincipalIds.Contains($principalId)) {
                    $rev005Key = "DEC-REV-005|$principalId"
                    if ($emittedRev23.Add($rev005Key)) {
                        $principalName = if ($dec.Principal -and $dec.Principal.DisplayName) { $dec.Principal.DisplayName } else { $principalId }
                        $findings.Add((New-DecomFinding `
                            -FindingId         'DEC-REV-005' `
                            -Category          'Access Review Governance' `
                            -Severity          'High' `
                            -RiskScore         67 `
                            -Confidence        'High' `
                            -ObjectType        'User' `
                            -ObjectId          $principalId `
                            -DisplayName       $principalName `
                            -UserPrincipalName '' `
                            -Evidence          "Access review decision '$($dec.Decision)' recorded for $principalName but residual access findings still detected — review action may not have been enforced." `
                            -EvidenceSource    'identityGovernance/accessReviews/definitions/{id}/instances/{id}/decisions' `
                            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions/{id}/instances/{id}/decisions' `
                            -RecommendedAction "Enforce review decision for $principalName — verify access has been removed as directed by reviewer." `
                            -RemediationMode   'InformationOnly' `
                            -ConsultantNote    'Review decision conflict — deny/remove recorded but residual access still detected'))
                    }
                }
            }
        }
    }

    # --- Rev2.3 M3: Guest review correlation ---
    # Build sponsor-missing guest set from DEC-GUEST-003 findings
    $guestNoSponsorIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($gf in $findings) {
        if ($gf.FindingId -eq 'DEC-GUEST-003' -and $gf.ObjectId) {
            [void]$guestNoSponsorIds.Add($gf.ObjectId)
        }
    }
    if ($guestNoSponsorIds.Count -gt 0) { $coverage.GuestReviewCorrelation = $true }

    # Build PIM-002 principal lookup for privileged guest detection
    $pim002PrincipalIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($f in $findings) {
        if ($f.FindingId -eq 'DEC-PIM-002' -and $f.ObjectId) {
            [void]$pim002PrincipalIds.Add($f.ObjectId)
        }
    }

    # Build guest findings list for iteration (DEC-GUEST-001 from stale sign-in,
    # DEC-GUEST-003 from sponsor-missing helper, DEC-GUEST-002 from privileged-guest helper)
    $guestFindings = @($findings | Where-Object { $_.FindingId -in @('DEC-GUEST-001','DEC-GUEST-002','DEC-GUEST-003') })

    # Iterating over stale guests (DEC-GUEST-001) to correlate review decisions.
    # Sponsor-missing guests come from DEC-GUEST-003 (Get-MgUserManager failure).
    # Privileged guests: has PIM-002 assignment (not sponsor-missing — that is DEC-GREV-002).
    foreach ($gf in $guestFindings) {
        $guestId         = $gf.ObjectId
        if (-not $guestId) { continue }

        $lacksSponsorship = $guestNoSponsorIds.Contains($guestId)
        $isPrivileged     = $pim002PrincipalIds.Contains($guestId)

        # Try to correlate review decision for this guest
        $reviewResult = [PSCustomObject]@{
            Found           = $false
            Confidence      = 'Low'
            ReviewId        = ''
            ReviewName      = ''
            LastDecisionUtc = $null
            Status          = ''
            DecisionSummary = ''
            Evidence        = ''
        }

        if ($null -ne $accessReviewData) {
            foreach ($dec in $arDecisions) {
                $decPrincipalId = if ($dec.Principal -and $dec.Principal.Id) { $dec.Principal.Id } else { '' }
                if ($decPrincipalId -eq $guestId) {
                    $reviewResult.Found = $true
                    $reviewResult.DecisionSummary = if ($dec.Decision) { $dec.Decision } else { 'Unknown' }
                    try {
                        if ($dec.ReviewedDateTime) {
                            $reviewResult.LastDecisionUtc = [datetime]$dec.ReviewedDateTime
                        }
                    } catch { $null = $null }
                    break
                }
            }
        }

        # Check if review decision is recent (within 90 days)
        $guestReviewThreshold90 = (Get-Date).AddDays(-90)
        $hasRecentGuestReview = $false
        if ($reviewResult.Found -and $null -ne $reviewResult.LastDecisionUtc) {
            $hasRecentGuestReview = ($reviewResult.LastDecisionUtc -ge $guestReviewThreshold90)
        }

        $grevKey = ''
        if ($isPrivileged -and -not $hasRecentGuestReview) {
            $grevKey = "DEC-GREV-003|$guestId"
            if ($emittedRev23.Add($grevKey)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GREV-003' `
                    -Category          'Guest Lifecycle' `
                    -Severity          'High' `
                    -RiskScore         72 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $guestId `
                    -DisplayName       $gf.DisplayName `
                    -UserPrincipalName $gf.UserPrincipalName `
                    -Evidence          'Guest holds privileged access (PIM eligible or directory role) and no access review decision found — privileged external access is ungoverned.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Immediately create access review for privileged guest $($gf.UserPrincipalName); escalate to security team." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Privileged guest without review evidence — highest risk GREV category'))
            }
        } elseif ($lacksSponsorship -and -not $hasRecentGuestReview) {
            $grevKey = "DEC-GREV-002|$guestId"
            if ($emittedRev23.Add($grevKey)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GREV-002' `
                    -Category          'Guest Lifecycle' `
                    -Severity          'High' `
                    -RiskScore         63 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $guestId `
                    -DisplayName       $gf.DisplayName `
                    -UserPrincipalName $gf.UserPrincipalName `
                    -Evidence          'Guest account lacks sponsor metadata and no access review decision found — business justification cannot be confirmed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Assign a sponsor to $($gf.UserPrincipalName) and create access review; consider offboarding if no sponsor can be identified." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Unsponsored guest without review evidence — elevated governance risk'))
            }
        } elseif (-not $hasRecentGuestReview) {
            $grevKey = "DEC-GREV-001|$guestId"
            if ($emittedRev23.Add($grevKey)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GREV-001' `
                    -Category          'Guest Lifecycle' `
                    -Severity          'Medium' `
                    -RiskScore         48 `
                    -Confidence        'Low' `
                    -ObjectType        'User' `
                    -ObjectId          $guestId `
                    -DisplayName       $gf.DisplayName `
                    -UserPrincipalName $gf.UserPrincipalName `
                    -Evidence          'Guest account has no access review decision found within the last 90 days — review coverage cannot be confirmed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Schedule or confirm access review for guest $($gf.UserPrincipalName) and ensure decision is recorded." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Guest access review coverage gap — no decision evidence within threshold'))
            }
        }
    }

    # --- Rev2.3 M4: PIM review correlation ---
    $pimFindings = @($findings | Where-Object { $_.FindingId -in @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-004') })
    if ($pimFindings.Count -gt 0) { $coverage.PimReviewCorrelation = $true }

    $pimReviewThreshold180 = (Get-Date).AddDays(-180)

    foreach ($pf in $pimFindings) {
        $principalId = $pf.ObjectId
        if (-not $principalId -or $principalId -eq 'tenant-scope') { continue }

        # Safe variable guard for script:EligibleAssignments
        $safeEligible   = if ($null -ne $script:EligibleAssignments) { @($script:EligibleAssignments) } else { @() }

        $roleDefId = ''
        $matchAssignment = $safeEligible | Where-Object { $_.PrincipalId -eq $principalId } | Select-Object -First 1
        if ($matchAssignment -and $matchAssignment.RoleDefinitionId) {
            $roleDefId = $matchAssignment.RoleDefinitionId
        }

        $dedupSuffix = if ($roleDefId) { "$principalId|$roleDefId" } else { $principalId }

        # Try to find review decision for this principal
        $pimReviewFound    = $false
        $pimLastDecision   = $null
        if ($null -ne $accessReviewData) {
            foreach ($dec in $arDecisions) {
                $decPrincipalId = if ($dec.Principal -and $dec.Principal.Id) { $dec.Principal.Id } else { '' }
                if ($decPrincipalId -eq $principalId) {
                    $pimReviewFound = $true
                    try {
                        if ($dec.ReviewedDateTime) { $pimLastDecision = [datetime]$dec.ReviewedDateTime }
                    } catch { $null = $null }
                    break
                }
            }
        }

        if ($null -eq $accessReviewData) {
            # DEC-PIM-007: emit once — no AR data at all
            $pim007Key = 'DEC-PIM-007|tenant-scope'
            if ($emittedRev23.Add($pim007Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-PIM-007' `
                    -Category          'Privileged Access' `
                    -Severity          'Informational' `
                    -RiskScore         22 `
                    -Confidence        'Low' `
                    -ObjectType        'TenantScope' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'PIM Review Correlation' `
                    -UserPrincipalName '' `
                    -Evidence          'PIM eligible assignment findings detected but access review data unavailable — review correlation could not be performed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction 'Grant AccessReview.Read.All permission and re-run assessment to enable PIM review correlation.' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'PIM review correlation skipped — no AR data available'))
            }
        } elseif ($pimReviewFound -and $null -ne $pimLastDecision -and $pimLastDecision -lt $pimReviewThreshold180) {
            # DEC-PIM-006: review found but older than 180 days
            $pim006Key = "DEC-PIM-006|$dedupSuffix"
            if ($emittedRev23.Add($pim006Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-PIM-006' `
                    -Category          'Privileged Access' `
                    -Severity          'High' `
                    -RiskScore         73 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $principalId `
                    -DisplayName       $pf.DisplayName `
                    -UserPrincipalName $pf.UserPrincipalName `
                    -Evidence          "PIM eligible privileged role assignment last reviewed $($pimLastDecision.ToString('yyyy-MM-dd')) — more than 180 days ago. Review has lapsed." `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Initiate new access review for PIM eligible assignment for $($pf.UserPrincipalName)." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Stale PIM review — last decision beyond 180-day threshold'))
            }
        } elseif (-not $pimReviewFound) {
            # DEC-PIM-005: no review evidence found
            $pim005Key = "DEC-PIM-005|$dedupSuffix"
            if ($emittedRev23.Add($pim005Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-PIM-005' `
                    -Category          'Privileged Access' `
                    -Severity          'High' `
                    -RiskScore         70 `
                    -Confidence        'Low' `
                    -ObjectType        'User' `
                    -ObjectId          $principalId `
                    -DisplayName       $pf.DisplayName `
                    -UserPrincipalName $pf.UserPrincipalName `
                    -Evidence          'PIM eligible privileged role assignment found but no access review decision evidence detected — governance review cannot be confirmed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Create access review for PIM eligible assignment for $($pf.UserPrincipalName) and confirm review completion." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'PIM eligible assignment without review evidence — governance gap'))
            }
        }
    }

    # --- Rev2.3 M5: Access package review correlation ---
    $apFindings = @($findings | Where-Object {
        $_.FindingId -in @('DEC-AP-001','DEC-AP-002','DEC-AP-003','DEC-AP-004','DEC-AP-005') -and
        $_.ObjectId -ne 'tenant-scope' -and $_.ObjectId -ne 'contoso.onmicrosoft.com'
    })
    if ($apFindings.Count -gt 0) { $coverage.AccessPackageReviewCorrelation = $true }

    # DEC-AP-006: emit once if no AR definition correlated to entitlement management
    if ($apFindings.Count -gt 0) {
        $emDefForAP = $false
        foreach ($def in $arDefinitions) {
            $scopeQuery = ''
            try { if ($def.Scope -and $def.Scope.Query) { $scopeQuery = $def.Scope.Query } } catch { $null = $null }
            if ($scopeQuery -match 'entitlementManagement|accessPackage') {
                $emDefForAP = $true
                break
            }
        }
        if (-not $emDefForAP) {
            $ap006Key = 'DEC-AP-006|tenant-scope'
            if ($emittedRev23.Add($ap006Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-AP-006' `
                    -Category          'Governance' `
                    -Severity          'Medium' `
                    -RiskScore         50 `
                    -Confidence        'Low' `
                    -ObjectType        'TenantScope' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'Access Package Review Coverage' `
                    -UserPrincipalName '' `
                    -Evidence          'Access package assignment findings found but no access review definition correlated to entitlement management scope.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction 'Create access review definitions scoped to entitlement management access packages.' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'No AR definition found for entitlement management — coverage gap'))
            }
        }
    }

    # Per-principal AP review correlation: DEC-AP-008 (incomplete) > DEC-AP-007 (stale/unavailable)
    $apReviewThreshold180 = (Get-Date).AddDays(-180)
    foreach ($apf in $apFindings) {
        $apPrincipalId = $apf.ObjectId
        if (-not $apPrincipalId) { continue }

        $apDecisionFound    = $false
        $apDecisionComplete = $false
        $apLastDecision     = $null
        if ($null -ne $accessReviewData) {
            foreach ($dec in $arDecisions) {
                $decPrincipalId = if ($dec.Principal -and $dec.Principal.Id) { $dec.Principal.Id } else { '' }
                if ($decPrincipalId -eq $apPrincipalId) {
                    $apDecisionFound = $true
                    $decVal = if ($dec.Decision) { $dec.Decision.ToLower() } else { '' }
                    if ($decVal -notin @('notreviewed','')) { $apDecisionComplete = $true }
                    try {
                        if ($dec.ReviewedDateTime) { $apLastDecision = [datetime]$dec.ReviewedDateTime }
                    } catch { $null = $null }
                    break
                }
            }
        }

        if ($apDecisionFound -and -not $apDecisionComplete) {
            # DEC-AP-008: incomplete decision
            $ap008Key = "DEC-AP-008|$apPrincipalId"
            if ($emittedRev23.Add($ap008Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-AP-008' `
                    -Category          'Governance' `
                    -Severity          'High' `
                    -RiskScore         66 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $apPrincipalId `
                    -DisplayName       $apf.DisplayName `
                    -UserPrincipalName $apf.UserPrincipalName `
                    -Evidence          'Access package assignment review decision is incomplete or not reviewed — reviewer action required.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Follow up with reviewer to complete access review decision for $($apf.UserPrincipalName)." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Pending review decision requires reviewer action'))
            }
        } elseif (-not $apDecisionFound -or ($null -ne $apLastDecision -and $apLastDecision -lt $apReviewThreshold180)) {
            # DEC-AP-007: stale or unavailable
            $ap007Key = "DEC-AP-007|$apPrincipalId"
            if ($emittedRev23.Add($ap007Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-AP-007' `
                    -Category          'Governance' `
                    -Severity          'Medium' `
                    -RiskScore         54 `
                    -Confidence        'Low' `
                    -ObjectType        'User' `
                    -ObjectId          $apPrincipalId `
                    -DisplayName       $apf.DisplayName `
                    -UserPrincipalName $apf.UserPrincipalName `
                    -Evidence          'Access package assignment has no review decision within 180 days — review evidence stale or unavailable.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Initiate access review for access package assignment for $($apf.UserPrincipalName)." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Stale or missing review decision for access package assignment'))
            }
        }
    }

    # --- Rev2.3 M6: CA exclusion review correlation ---
    $caFindings = @($findings | Where-Object { $_.FindingId -in @('DEC-CA-001','DEC-CA-002') })
    if ($caFindings.Count -gt 0) { $coverage.CAExclusionReviewCorrelation = $true }

    $caGroupFindings = @($caFindings | Where-Object { $_.FindingId -eq 'DEC-CA-002' -and $_.ObjectType -eq 'Group' })
    $caStaleThreshold90 = (Get-Date).AddDays(-90)

    foreach ($caf in $caGroupFindings) {
        $caGroupId   = $caf.ObjectId
        $caGroupName = $caf.DisplayName
        if (-not $caGroupId) { continue }

        # Check if any AR definition scope references this group ID or name
        $matchedDef = $null
        foreach ($def in $arDefinitions) {
            $scopeQuery = ''
            try { if ($def.Scope -and $def.Scope.Query) { $scopeQuery = $def.Scope.Query } } catch { $null = $null }
            if ($scopeQuery.Contains($caGroupId)) {
                $matchedDef = $def
                break
            }
            # Name match fallback
            if ($caGroupName -and $def.DisplayName -and $def.DisplayName -match [regex]::Escape($caGroupName)) {
                $matchedDef = $def
                break
            }
        }

        if ($null -eq $matchedDef) {
            # No match — DEC-CA-003
            $ca003Key = "DEC-CA-003|$caGroupId"
            if ($emittedRev23.Add($ca003Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-CA-003' `
                    -Category          'Conditional Access' `
                    -Severity          'High' `
                    -RiskScore         68 `
                    -Confidence        'Low' `
                    -ObjectType        'Group' `
                    -ObjectId          $caGroupId `
                    -DisplayName       $caGroupName `
                    -UserPrincipalName '' `
                    -Evidence          "CA policy exclusion group '$caGroupName' has no correlated access review definition — members excluded without review governance." `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Create access review definition scoped to '$caGroupName' group to govern CA exclusion membership." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'CA exclusion group without review governance — attack surface is ungoverned'))
            }
        } else {
            # Matched definition — check if instances are all stale (>90 days)
            $matchedDefId = $matchedDef.Id
            $defInstances = @($arInstances | Where-Object {
                $_.AccessReviewScheduleDefinitionId -eq $matchedDefId
            })
            $hasRecentInstance = $false
            foreach ($inst in $defInstances) {
                $instEnd = $null
                try { if ($inst.EndDateTime) { $instEnd = [datetime]$inst.EndDateTime } } catch { $null = $null }
                if ($null -ne $instEnd -and $instEnd -ge $caStaleThreshold90) {
                    $hasRecentInstance = $true
                    break
                }
            }
            if (-not $hasRecentInstance -and $defInstances.Count -gt 0) {
                # All instances older than 90 days — DEC-CA-004
                $ca004Key = "DEC-CA-004|$caGroupId"
                if ($emittedRev23.Add($ca004Key)) {
                    $lastInstEnd = $null
                    foreach ($inst in $defInstances) {
                        try {
                            if ($inst.EndDateTime) {
                                $ie = [datetime]$inst.EndDateTime
                                if ($null -eq $lastInstEnd -or $ie -gt $lastInstEnd) { $lastInstEnd = $ie }
                            }
                        } catch { $null = $null }
                    }
                    $lastStr = if ($null -ne $lastInstEnd) { $lastInstEnd.ToString('yyyy-MM-dd') } else { 'unknown' }
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-CA-004' `
                        -Category          'Conditional Access' `
                        -Severity          'High' `
                        -RiskScore         70 `
                        -Confidence        'Low' `
                        -ObjectType        'Group' `
                        -ObjectId          $caGroupId `
                        -DisplayName       $caGroupName `
                        -UserPrincipalName '' `
                        -Evidence          "CA policy exclusion group '$caGroupName' last reviewed $lastStr — more than 90 days ago. Review has lapsed for CA exclusion governance." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                        -RecommendedAction "Initiate new access review for '$caGroupName' to re-validate CA exclusion membership." `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'Stale CA exclusion review — last decision beyond 90-day threshold'))
                }
            }
        }
    }
}
