function _Get-DecomPimCaFindings {
    # Rev2.3 PIM eligible assignment discovery + CA exclusion detection.
    # Emits DEC-PIM-001/002/003, DEC-CA-002, DEC-COND-010/020.
    # Mutates $findings (List), $coverage (ordered dict), $emittedRev23 (HashSet)
    # by reference. Sets module-scope $script:EligibleAssignments for later M4 use.
    param(
        [System.Collections.Generic.List[object]]$findings,
        $coverage,
        [System.Collections.Generic.HashSet[string]]$emittedRev23
    )

    $script:EligibleAssignments = @()
    $pimCapabilityKey = 'PimEligibleAssignments.Unavailable'
    if (Test-DecomCapabilityAvailable -Key $pimCapabilityKey) {
        try {
            $pimCmdlet = Get-Command 'Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance' -ErrorAction SilentlyContinue
            if ($null -eq $pimCmdlet) {
                # Cmdlet not installed → capability permanently unavailable, never retry
                $null = Set-DecomCapabilityUnavailable -Key $pimCapabilityKey -Message 'PIM eligible assignment cmdlet unavailable in installed Graph module'
                Write-DecomWarn "PIM eligible assignment discovery unavailable: cmdlet not found"
            } else {
                $script:EligibleAssignments = @(
                    Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -All -ErrorAction Stop |
                    Where-Object {
                        $_.PrincipalId -and
                        (
                            $null -eq $_.PrincipalType -or
                            $_.PrincipalType -eq 'User' -or
                            $_.PrincipalType -eq 'groupUser'
                        )
                    }
                )
                $coverage.PimEligibleAssignments = $true
                Write-DecomInfo "PIM eligible assignment discovery: OK ($($script:EligibleAssignments.Count) assignments)"

                # DEC-PIM-003: Emit at most once when eligible assignments are found.
                # This mirrors the original M1 logic (tested by Rev22 "DEC-PIM-003 at most once").
                # Emitted regardless of user type — catchall for PIM activation evidence gaps.
                if ($script:EligibleAssignments.Count -gt 0) {
                    $pim003Key = 'DEC-PIM-003|tenant'
                    if ($emittedRev23.Add($pim003Key)) {
                        $findings.Add((New-DecomFinding `
                            -FindingId         'DEC-PIM-003' `
                            -Category          'Privileged Access' `
                            -Severity          'Medium' `
                            -RiskScore         46 `
                            -Confidence        'Low' `
                            -ObjectType        'Tenant' `
                            -ObjectId          'tenant-scope' `
                            -DisplayName       'PIM Coverage' `
                            -UserPrincipalName '' `
                            -Evidence          'PIM activation and review evidence could not be confirmed from available Graph data. Coverage may be partial.' `
                            -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
                            -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
                            -RecommendedAction 'Grant PrivilegedAccess.Read.AzureAD permission and re-run assessment for full PIM coverage' `
                            -RemediationMode   'InformationOnly' `
                            -ConsultantNote    'PIM evidence gap — not a finding against tenant configuration'))
                    }
                }
            }
        } catch {
            $null = Set-DecomCapabilityUnavailable -Key $pimCapabilityKey -Message "PIM eligible assignment discovery unavailable: $($_.Exception.Message)" -Error $_.Exception.Message
            Write-DecomWarn "PIM eligible assignment discovery unavailable: $($_.Exception.Message)"
        }
    }

    # Build lookup sets for DEC-PIM-001 (disabled users) and DEC-PIM-002 (guests)
    # Query Graph API directly when the capability passed the check above (i.e. cmdlet exists).
    # When the cmdlet was not found the capability was already marked unavailable above.
    # This mirrors the original M1 structure where lookup sets ran whenever $pimCmdlet existed.

    $allDisabledUsers = @()
    $allDisabledIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $userCmdletDisabled = Get-Command 'Get-MgUser' -ErrorAction SilentlyContinue
        if ($userCmdletDisabled) {
            $allDisabledUsers = @(
                Get-MgUser -Filter 'accountEnabled eq false' -All -ErrorAction Stop |
                Select-Object Id, DisplayName, UserPrincipalName, AccountEnabled
            )
            foreach ($u in $allDisabledUsers) { [void]$allDisabledIdSet.Add($u.Id) }
            Write-DecomInfo "Disabled user query for PIM: OK ($($allDisabledUsers.Count) disabled users)"
        }
    } catch { Write-DecomWarn "Direct disabled user query failed: $($_.Exception.Message)" }

    # Fall back to DEC-USER-002 findings if direct query returned no results
    if ($allDisabledIdSet.Count -eq 0) {
        foreach ($f in $findings) {
            if ($f.FindingId -eq 'DEC-USER-002' -and $f.ObjectId) { [void]$allDisabledIdSet.Add($f.ObjectId) }
        }
    }

    $allGuestUsers = @()
    $allGuestIdSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    try {
        $userCmdletGuest = Get-Command 'Get-MgUser' -ErrorAction SilentlyContinue
        if ($userCmdletGuest) {
            $allGuestUsers = @(
                Get-MgUser -Filter "userType eq 'guest'" -All -ErrorAction Stop |
                Select-Object Id, DisplayName, UserPrincipalName, UserType
            )
            foreach ($g in $allGuestUsers) { [void]$allGuestIdSet.Add($g.Id) }
            Write-DecomInfo "Guest user query for PIM: OK ($($allGuestUsers.Count) guest users)"
        }
    } catch { Write-DecomWarn "Direct guest user query failed: $($_.Exception.Message)" }

    # Fall back to DEC-GUEST-001 findings if direct query returned no results
    if ($allGuestIdSet.Count -eq 0) {
        foreach ($f in $findings) {
            if ($f.FindingId -eq 'DEC-GUEST-001' -and $f.ObjectId) { [void]$allGuestIdSet.Add($f.ObjectId) }
        }
    }

    # Helper to resolve role name from RoleDefinitionId or RoleDefinition object
    function global:Get-PimRoleName {
        param($Assignment)
        $roleName = 'Privileged Role'
        try {
            if ($Assignment.RoleDefinition -and $Assignment.RoleDefinition.DisplayName) {
                return $Assignment.RoleDefinition.DisplayName
            }
            if ($Assignment.RoleDefinitionId -and $Assignment.RoleDefinitionId.StartsWith('pw__')) {
                return $Assignment.RoleDefinitionId.Substring(4) -replace '(?<!^)([A-Z])', ' $1'
            }
        } catch { $null = $null }
        return $roleName
    }

    # Emit DEC-PIM-001 for disabled users with PIM-eligible assignments
    foreach ($assign in $script:EligibleAssignments) {
        $principalId = $assign.PrincipalId
        if (-not $principalId) { continue }
        if (-not $allDisabledIdSet.Contains($principalId)) { continue }

        $key = "DEC-PIM-001|$principalId|$($assign.RoleDefinitionId)"
        if (-not $emittedRev23.Add($key)) { continue }

        $roleName = Get-PimRoleName -Assignment $assign

        $userObj = $allDisabledUsers | Where-Object { $_.Id -eq $principalId } | Select-Object -First 1
        if (-not $userObj) {
            $userObj = [PSCustomObject]@{
                Id=$principalId; DisplayName=$principalId
                UserPrincipalName="$principalId"; AccountEnabled=$false
            }
        }

        $findings.Add((New-DecomFinding `
            -FindingId         'DEC-PIM-001' `
            -Category          'Privileged Access' `
            -Severity          'Critical' `
            -RiskScore         86 `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          $principalId `
            -DisplayName       $userObj.DisplayName `
            -UserPrincipalName $userObj.UserPrincipalName `
            -Evidence          "User '$($userObj.DisplayName)' is disabled but has an active PIM eligible assignment for role '$roleName' — disabled account retains privileged access and is a governance gap." `
            -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
            -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
            -RecommendedAction "Remove PIM eligible assignment for '$roleName' from disabled user $($userObj.UserPrincipalName); use offboarding workflow." `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Disabled user with PIM eligible assignment is a critical governance gap'))
    }

    # Emit DEC-PIM-002 for guest users with PIM-eligible assignments
    foreach ($assign in $script:EligibleAssignments) {
        $principalId = $assign.PrincipalId
        if (-not $principalId) { continue }
        if (-not $allGuestIdSet.Contains($principalId)) { continue }

        $key = "DEC-PIM-002|$principalId|$($assign.RoleDefinitionId)"
        if (-not $emittedRev23.Add($key)) { continue }

        $roleName = Get-PimRoleName -Assignment $assign

        $guestObj = $allGuestUsers | Where-Object { $_.Id -eq $principalId } | Select-Object -First 1
        if (-not $guestObj) {
            $guestObj = [PSCustomObject]@{
                Id=$principalId; DisplayName=$principalId
                UserPrincipalName="$principalId"; AccountEnabled=$false
            }
        }

        $findings.Add((New-DecomFinding `
            -FindingId         'DEC-PIM-002' `
            -Category          'Privileged Access' `
            -Severity          'Critical' `
            -RiskScore         84 `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          $principalId `
            -DisplayName       $guestObj.DisplayName `
            -UserPrincipalName $guestObj.UserPrincipalName `
            -Evidence          "Guest account '$($guestObj.DisplayName)' ($($guestObj.UserPrincipalName)) is eligible for privileged role '$roleName' via PIM — external party holds governance-critical access." `
            -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
            -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
            -RecommendedAction "Review PIM eligibility for '$roleName' from guest $($guestObj.UserPrincipalName); confirm business justification and ensure access review covers this assignment." `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Privileged guest — PIM eligible assignment for high-impact role requires immediate governance attention'))
    }

    # --- Rev2.3 CA Exclusion: Check if privileged users are excluded from CA policies ---
    # For each privileged/disabled/guest user identified, check whether a CA policy
    # explicitly excludes them (or their group). If excluded and no review covers the
    # CA policy scope, emit DEC-COND-010 (disabled) or DEC-COND-020 (guest).

    try {
        $caCmdlet = Get-Command 'Get-MgIdentityConditionalAccessPolicy' -ErrorAction SilentlyContinue
        if ($caCmdlet) {
            $caPolicies = @(Get-MgIdentityConditionalAccessPolicy -All -ErrorAction Stop)

            # Collect all privileged principal IDs (union of PIM findings)
            $anyPrivilegedIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($f in $findings) {
                if ($f.FindingId -in @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004') -and $f.ObjectId) {
                    [void]$anyPrivilegedIds.Add($f.ObjectId)
                }
            }

            $coverage.ConditionalAccess = $true
            Write-DecomInfo "Conditional access policy discovery: OK ($($caPolicies.Count) policies)"

            foreach ($policy in $caPolicies) {
                $policyId   = if ($policy.Id) { $policy.Id } else { continue }
                $policyName = if ($policy.DisplayName) { $policy.DisplayName } else { $policyId }

                # Extract excluded users and groups from conditions
                # Handle both flat (direct) and nested (Conditions.Users) ExcludeUsers/ExcludeGroups
                $excludedUserIds  = @()
                $excludedGroupIds = @()
                try {
                    if ($policy.Conditions) {
                        # Try direct path (flat conditions structure)
                        if ($policy.Conditions.ExcludeUsers) {
                            $excludedUserIds = @($policy.Conditions.ExcludeUsers | Where-Object { $_ -ne 'All' -and $_ -ne 'None' })
                        } elseif ($policy.Conditions.Users -and $policy.Conditions.Users.ExcludeUsers) {
                            # Nested path (Conditions.Users.ExcludeUsers — used by mock and v1.0 Graph)
                            $excludedUserIds = @($policy.Conditions.Users.ExcludeUsers | Where-Object { $_ -ne 'All' -and $_ -ne 'None' })
                        }
                        if ($policy.Conditions.ExcludeGroups) {
                            $excludedGroupIds = @($policy.Conditions.ExcludeGroups | Where-Object { $_ -ne 'All' -and $_ -ne 'None' })
                        } elseif ($policy.Conditions.Users -and $policy.Conditions.Users.ExcludeGroups) {
                            # Nested path (Conditions.Users.ExcludeGroups)
                            $excludedGroupIds = @($policy.Conditions.Users.ExcludeGroups | Where-Object { $_ -ne 'All' -and $_ -ne 'None' })
                        }
                    }
                } catch { $null = $null }

                # --- Emit DEC-CA-002 for each excluded group (feeds M6 correlation) ---
                # The M6 block (line 2400) processes DEC-CA-002 Group findings to emit
                # DEC-CA-003 (no review) and DEC-CA-004 (stale review).
                foreach ($grp in $excludedGroupIds) {
                    $ca002Key = "DEC-CA-002|$grp|$policyId"
                    if ($emittedRev23.Add($ca002Key)) {
                        # Look up group display name from mocked data if available
                        $groupDisplayName = $grp
                        try {
                            $grpObj = Get-MgGroup -GroupId $grp -ErrorAction SilentlyContinue
                            if ($grpObj) { $groupDisplayName = if ($grpObj.DisplayName) { $grpObj.DisplayName } else { $grp } }
                        } catch { $null = $null }

                        $findings.Add((New-DecomFinding `
                            -FindingId         'DEC-CA-002' `
                            -Category          'Conditional Access' `
                            -Severity          'High' `
                            -RiskScore         65 `
                            -Confidence        'High' `
                            -ObjectType        'Group' `
                            -ObjectId          $grp `
                            -DisplayName       "$groupDisplayName (excluded from $policyName)" `
                            -UserPrincipalName '' `
                            -Evidence          "CA policy '$policyName' ($policyId) excludes group '$groupDisplayName' from authentication controls — members bypass MFA, device compliance, and other security requirements." `
                            -EvidenceSource    'identity/conditionalAccess/policies' `
                            -GraphEndpoint     '/v1.0/identity/conditionalAccess/policies' `
                            -RecommendedAction "Review CA policy exclusion for group '$groupDisplayName'; ensure membership is governed by access review and exclude only when required for emergency access." `
                            -RemediationMode   'ManualApprovalRequired' `
                            -ConsultantNote    'CA exclusion group — members bypass security controls and require governance review'))
                    }
                }

                # --- Check if any privileged user is explicitly excluded (user-level exclusion) ---
                $excludedPrivilegedIds = @($excludedUserIds | Where-Object { $anyPrivilegedIds.Contains($_) })
                if ($excludedPrivilegedIds.Count -eq 0) { continue }

                # Determine user types of excluded principals — try findings first, fall back to direct query
                $disabledIdsAll = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                $guestIdsAll    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

                # From findings
                foreach ($f in $findings) {
                    if ($f.FindingId -eq 'DEC-USER-002' -and $f.ObjectId) { [void]$disabledIdsAll.Add($f.ObjectId) }
                    if ($f.FindingId -eq 'DEC-GUEST-001' -and $f.ObjectId) { [void]$guestIdsAll.Add($f.ObjectId) }
                }

                # Fall back to direct query if sets are empty (test scenario with incomplete discovery)
                if ($disabledIdsAll.Count -eq 0) {
                    try {
                        $allDisabled = @(Get-MgUser -Filter 'accountEnabled eq false' -All -ErrorAction SilentlyContinue)
                        foreach ($u in $allDisabled) { [void]$disabledIdsAll.Add($u.Id) }
                    } catch { $null = $null }
                }
                if ($guestIdsAll.Count -eq 0) {
                    try {
                        $allGuest = @(Get-MgUser -Filter "userType eq 'guest'" -All -ErrorAction SilentlyContinue)
                        foreach ($g in $allGuest) { [void]$guestIdsAll.Add($g.Id) }
                    } catch { $null = $null }
                }

                # DEC-COND-010: Disabled user excluded from CA policy
                foreach ($uid in $excludedPrivilegedIds) {
                    if ($disabledIdsAll.Contains($uid)) {
                        $condKey = "DEC-COND-010|$policyId"
                        if ($emittedRev23.Add($condKey)) {
                            $findings.Add((New-DecomFinding `
                                -FindingId         'DEC-COND-010' `
                                -Category          'Conditional Access' `
                                -Severity          'Critical' `
                                -RiskScore         88 `
                                -Confidence        'High' `
                                -ObjectType        'ConditionalAccessPolicy' `
                                -ObjectId          $policyId `
                                -DisplayName       $policyName `
                                -UserPrincipalName '' `
                                -Evidence          "Conditional access policy '$policyName' ($policyId) excludes a disabled user from all authentication controls — disabled account is implicitly granted access despite being deprovisioned." `
                                -EvidenceSource    'identity/conditionalAccess/policies' `
                                -GraphEndpoint     '/v1.0/identity/conditionalAccess/policies' `
                                -RecommendedAction "Remove disabled user account from CA policy '$policyName' and deactivate the account; review all CA exclusions for disabled users." `
                                -RemediationMode   'ManualApprovalRequired' `
                                -ConsultantNote    'Disabled user in CA exclusion list — critical identity hygiene failure'))
                        }
                    }
                }

                # DEC-COND-020: Guest excluded from CA policy
                foreach ($uid in $excludedPrivilegedIds) {
                    if ($guestIdsAll.Contains($uid)) {
                        $condKey = "DEC-COND-020|$policyId"
                        if ($emittedRev23.Add($condKey)) {
                            $findings.Add((New-DecomFinding `
                                -FindingId         'DEC-COND-020' `
                                -Category          'Conditional Access' `
                                -Severity          'High' `
                                -RiskScore         77 `
                                -Confidence        'High' `
                                -ObjectType        'ConditionalAccessPolicy' `
                                -ObjectId          $policyId `
                                -DisplayName       $policyName `
                                -UserPrincipalName '' `
                                -Evidence          "Conditional access policy '$policyName' ($policyId) excludes an external guest user from authentication controls — guest with privileged access bypasses security posture." `
                                -EvidenceSource    'identity/conditionalAccess/policies' `
                                -GraphEndpoint     '/v1.0/identity/conditionalAccess/policies' `
                                -RecommendedAction "Remove guest user from CA policy exclusion in '$policyName' and ensure Conditional Access applies to external identities; assign sponsor and schedule access review." `
                                -RemediationMode   'ManualApprovalRequired' `
                                -ConsultantNote    'Privileged guest in CA exclusion list — external access bypasses multi-factor authentication requirement'))
                        }
                    }
                }
            }
        }
    } catch {
        Write-DecomWarn "Conditional access exclusion discovery unavailable: $($_.Exception.Message)"
    }
}
