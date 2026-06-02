#Requires -Version 5.1

function Confirm-DecomActionTargetValid {
    # Validates that approved target still exists and belongs to the approved object.
    # Returns: Valid, InvalidTargets (stale/safe), ValidationErrors (Graph failures), ErrorDetail
    param([object]$Action)

    $result = [PSCustomObject]@{
        Valid            = $true
        InvalidTargets   = [System.Collections.Generic.List[string]]::new()
        ValidationErrors = [System.Collections.Generic.List[string]]::new()
        ErrorDetail      = ''
    }

    $actionType = [string]$Action.ActionType
    $objectId   = [string]$Action.ObjectId
    $targetIds  = @($Action.TargetObjectIds)

    try {
        switch ($actionType) {

            'RemoveGroupMembership' {
                foreach ($groupId in $targetIds) {
                    try {
                        $members  = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)
                        $isMember = $null -ne ($members | Where-Object { $_.Id -eq $objectId })
                        if (-not $isMember) {
                            $result.InvalidTargets.Add("$groupId : user no longer member (already removed or state changed)")
                        }
                    } catch {
                        $result.ValidationErrors.Add("$groupId : membership check failed — $_")
                        $result.Valid = $false
                    }
                }
            }

            'RevokeAppRoleAssignment' {
                try {
                    $allAssignments = @(Get-MgUserAppRoleAssignment -UserId $objectId -All -ErrorAction Stop)
                    foreach ($assignmentId in $targetIds) {
                        $exists = $null -ne ($allAssignments | Where-Object { $_.Id -eq $assignmentId })
                        if (-not $exists) {
                            $result.InvalidTargets.Add("$assignmentId : assignment not found (already revoked or state changed)")
                        }
                    }
                } catch {
                    $result.ValidationErrors.Add("App role check failed for $objectId : $_")
                    $result.Valid = $false
                }
            }

            'RemoveDirectoryRoleAssignment' {
                foreach ($roleAssignmentId in $targetIds) {
                    try {
                        $assignment = Get-MgRoleManagementDirectoryRoleAssignment `
                            -UnifiedRoleAssignmentId $roleAssignmentId -ErrorAction Stop
                        if ($null -eq $assignment) {
                            $result.InvalidTargets.Add("$roleAssignmentId : assignment not found (already removed or state changed)")
                        } elseif ($assignment.PrincipalId -ne $objectId) {
                            $result.InvalidTargets.Add("$roleAssignmentId : PrincipalId MISMATCH — approved ObjectId=$objectId but assignment PrincipalId=$($assignment.PrincipalId) — BLOCKED")
                            $result.Valid = $false
                        }
                    } catch {
                        $result.ValidationErrors.Add("$roleAssignmentId : role assignment check failed — $_")
                        $result.Valid = $false
                    }
                }
            }

            'RemoveAccessPackageAssignment' {
                # P1-01: -ErrorAction Stop so Graph errors throw into the catch block.
                # P1-01: TargetId binding check after null check to prevent cross-principal writes.
                foreach ($assignmentId in $targetIds) {
                    try {
                        $assignment = Get-MgEntitlementManagementAssignment `
                            -AccessPackageAssignmentId $assignmentId -ErrorAction Stop
                        if ($null -eq $assignment) {
                            $result.InvalidTargets.Add("$assignmentId : assignment not found (already removed or state changed)")
                        } else {
                            # Resolve TargetId from multiple possible properties
                            $targetId = if ($assignment.TargetId) {
                                [string]$assignment.TargetId
                            } elseif ($assignment.Target -and $assignment.Target.Id) {
                                [string]$assignment.Target.Id
                            } elseif ($assignment.AdditionalProperties -and
                                      $assignment.AdditionalProperties['targetId']) {
                                [string]$assignment.AdditionalProperties['targetId']
                            } else {
                                ''
                            }
                            if (-not $targetId) {
                                $result.ValidationErrors.Add(
                                    "$assignmentId : TargetId could not be resolved from assignment object — BLOCKED")
                                $result.Valid = $false
                            } elseif ($targetId -ne $objectId) {
                                $result.ValidationErrors.Add(
                                    "$assignmentId : TargetId MISMATCH — approved ObjectId=$objectId " +
                                    "but assignment TargetId=$targetId — BLOCKED")
                                $result.Valid = $false
                            }
                        }
                    } catch {
                        $result.ValidationErrors.Add("$assignmentId : assignment check failed — $_")
                        $result.Valid = $false
                    }
                }
            }

            'RemovePimEligibleAssignment' {
                # P1-02: -ErrorAction Stop so Graph errors throw into the catch block.
                foreach ($scheduleId in $targetIds) {
                    try {
                        $schedule = Get-MgRoleManagementDirectoryRoleEligibilitySchedule `
                            -UnifiedRoleEligibilityScheduleId $scheduleId -ErrorAction Stop
                        if ($null -eq $schedule) {
                            $result.InvalidTargets.Add("$scheduleId : eligible schedule not found (already removed or state changed)")
                        } elseif ($schedule.PrincipalId -ne $objectId) {
                            $result.InvalidTargets.Add("$scheduleId : PrincipalId MISMATCH — approved ObjectId=$objectId but schedule PrincipalId=$($schedule.PrincipalId) — BLOCKED")
                            $result.Valid = $false
                        }
                    } catch {
                        $result.ValidationErrors.Add("$scheduleId : eligible schedule check failed — $_")
                        $result.Valid = $false
                    }
                }
            }

            'RemoveGuestGroupMembership' {
                # Validate guest identity first
                $guestCheck = Confirm-DecomGuestIdentity -ObjectId $objectId
                if (-not $guestCheck.Valid) {
                    $result.ValidationErrors.Add("Guest identity check failed: $($guestCheck.ErrorDetail)")
                    $result.Valid = $false
                    break
                }
                # Validate group membership for each target
                foreach ($groupId in $targetIds) {
                    try {
                        $members = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)
                        $isMember = $null -ne ($members | Where-Object { $_.Id -eq $objectId })
                        if (-not $isMember) {
                            $result.InvalidTargets.Add("$groupId : guest no longer member (already removed or state changed)")
                        }
                    } catch {
                        $result.ValidationErrors.Add("$groupId : group membership check failed — $_")
                        $result.Valid = $false
                    }
                }
            }

            'RevokeGuestAppRoleAssignment' {
                # Validate guest identity first
                $guestCheck = Confirm-DecomGuestIdentity -ObjectId $objectId
                if (-not $guestCheck.Valid) {
                    $result.ValidationErrors.Add("Guest identity check failed: $($guestCheck.ErrorDetail)")
                    $result.Valid = $false
                    break
                }
                # Validate each app role assignment belongs to the approved guest
                try {
                    $allAssignments = @(Get-MgUserAppRoleAssignment -UserId $objectId -All -ErrorAction Stop)
                    foreach ($assignmentId in $targetIds) {
                        $assignment = $allAssignments | Where-Object { $_.Id -eq $assignmentId }
                        if ($null -eq $assignment) {
                            $result.InvalidTargets.Add("$assignmentId : assignment not found (already revoked or state changed)")
                        } elseif ($assignment.PrincipalId -and $assignment.PrincipalId -ne $objectId) {
                            $result.ValidationErrors.Add("$assignmentId : PrincipalId MISMATCH — approved ObjectId=$objectId but assignment PrincipalId=$($assignment.PrincipalId) — BLOCKED")
                            $result.Valid = $false
                        }
                    }
                } catch {
                    $result.ValidationErrors.Add("App role assignment check failed for guest $objectId : $_")
                    $result.Valid = $false
                }
            }

            'RemoveExpiredApplicationCredential' {
                # Read application by exact ObjectId
                $app = $null
                try {
                    $app = Get-MgApplication -ApplicationId $objectId -ErrorAction Stop
                } catch {
                    $result.ValidationErrors.Add("Application read failed for $objectId : $_")
                    $result.Valid = $false
                    break
                }
                if ($null -eq $app) {
                    $result.InvalidTargets.Add("$objectId : application not found — stale target")
                    break
                }

                $approvedObjectType = [string]$Action.ObjectType
                if ($approvedObjectType -and $approvedObjectType -ne '' -and $approvedObjectType -ne 'Application') {
                    $result.ValidationErrors.Add("ObjectType MISMATCH — approved=$approvedObjectType but RemoveExpiredApplicationCredential requires Application — BLOCKED")
                    $result.Valid = $false
                    break
                }

                $approvedCredType = [string]$Action.CredentialType
                $now = [datetime]::UtcNow

                foreach ($keyId in $targetIds) {
                    $pwdCred = @($app.PasswordCredentials | Where-Object { $_.KeyId -and [string]$_.KeyId -eq $keyId })
                    $keyCred = @($app.KeyCredentials  | Where-Object { $_.KeyId -and [string]$_.KeyId -eq $keyId })
                    if ($pwdCred.Count -eq 0 -and $keyCred.Count -eq 0) {
                        $result.InvalidTargets.Add("$keyId : credential not found (already removed or never existed)")
                        continue
                    }
                    $cred       = if ($pwdCred.Count -gt 0) { $pwdCred[0] } else { $keyCred[0] }
                    $credSource = if ($pwdCred.Count -gt 0) { 'PasswordCredential' } else { 'KeyCredential' }

                    if ($approvedCredType -and $approvedCredType -ne '' -and $approvedCredType -ne $credSource) {
                        $result.ValidationErrors.Add("$keyId : CredentialType MISMATCH — approved=$approvedCredType but actual=$credSource — BLOCKED")
                        $result.Valid = $false
                        break
                    }
                    if ($null -eq $cred.EndDateTime) {
                        $result.ValidationErrors.Add("$keyId : EndDateTime is null — cannot confirm expired — BLOCKED")
                        $result.Valid = $false
                        break
                    }
                    $endDt = $cred.EndDateTime
                    if ($endDt -isnot [datetime]) {
                        try { $endDt = [datetime]::Parse([string]$endDt) } catch {
                            $result.ValidationErrors.Add("$keyId : EndDateTime cannot be parsed — BLOCKED")
                            $result.Valid = $false
                            break
                        }
                    }
                    if ($endDt.ToUniversalTime() -ge $now) {
                        $result.ValidationErrors.Add("$keyId : credential is NOT expired (EndDateTime=$($endDt.ToUniversalTime().ToString('o'))) — BLOCKED")
                        $result.Valid = $false
                        break
                    }
                }
            }
            'AddApplicationOwner' {
                $newOwnerObjId = [string]$Action.NewOwnerObjectId
                if (-not $newOwnerObjId -or $newOwnerObjId -eq '') {
                    $result.ValidationErrors.Add("NewOwnerObjectId is missing — BLOCKED")
                    $result.Valid = $false
                    break
                }
                $objType = [string]$Action.ObjectType
                if ($objType -notin @('Application','ServicePrincipal','')) {
                    $result.ValidationErrors.Add("ObjectType '$objType' is not Application or ServicePrincipal — BLOCKED")
                    $result.Valid = $false
                    break
                }
                # Read target application/service principal
                try {
                    if ($objType -eq 'ServicePrincipal') {
                        $spn = Get-MgServicePrincipal -ServicePrincipalId $objectId -Property 'Id,DisplayName' -ErrorAction Stop
                        if ($null -eq $spn) {
                            $result.ValidationErrors.Add("ServicePrincipal $objectId not found — BLOCKED")
                            $result.Valid = $false
                            break
                        }
                        # Check if owner already present
                        $owners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $objectId -All -ErrorAction Stop)
                        $alreadyOwner = $null -ne ($owners | Where-Object { $_.Id -eq $newOwnerObjId })
                        if ($alreadyOwner) {
                            $result.InvalidTargets.Add("$newOwnerObjId : already owner of ServicePrincipal (no-op)")
                        }
                    } else {
                        $app = Get-MgApplication -ApplicationId $objectId -Property 'Id,DisplayName' -ErrorAction Stop
                        if ($null -eq $app) {
                            $result.ValidationErrors.Add("Application $objectId not found — BLOCKED")
                            $result.Valid = $false
                            break
                        }
                        # Check if owner already present
                        $owners = @(Get-MgApplicationOwner -ApplicationId $objectId -All -ErrorAction Stop)
                        $alreadyOwner = $null -ne ($owners | Where-Object { $_.Id -eq $newOwnerObjId })
                        if ($alreadyOwner) {
                            $result.InvalidTargets.Add("$newOwnerObjId : already owner of Application (no-op)")
                        }
                    }
                } catch {
                    $result.ValidationErrors.Add("Target read failed for $objectId : $_")
                    $result.Valid = $false
                    break
                }
                # Read new owner object
                try {
                    $ownerObj = Get-MgDirectoryObject -DirectoryObjectId $newOwnerObjId -ErrorAction Stop
                    if ($null -eq $ownerObj) {
                        $result.ValidationErrors.Add("NewOwnerObjectId $newOwnerObjId not found — BLOCKED")
                        $result.Valid = $false
                        break
                    }
                } catch {
                    $result.ValidationErrors.Add("NewOwnerObjectId read failed for $newOwnerObjId : $_")
                    $result.Valid = $false
                    break
                }
                # If owner is a user, check AccountEnabled and UserType
                try {
                    $ownerUser = Get-MgUser -UserId $newOwnerObjId -Property 'Id,AccountEnabled,UserType' -ErrorAction Stop
                    if ($null -ne $ownerUser) {
                        if ($ownerUser.AccountEnabled -eq $false) {
                            $result.ValidationErrors.Add("NewOwnerObjectId $newOwnerObjId is disabled (AccountEnabled=false) — BLOCKED")
                            $result.Valid = $false
                            break
                        }
                        $allowGuest = if ($null -ne $Action.AllowGuestOwner) { [bool]$Action.AllowGuestOwner } else { $false }
                        if ($ownerUser.UserType -eq 'Guest' -and -not $allowGuest) {
                            $result.ValidationErrors.Add("NewOwnerObjectId $newOwnerObjId is a Guest and AllowGuestOwner is not true — BLOCKED")
                            $result.Valid = $false
                            break
                        }
                    }
                } catch { }
            }

            'RemoveCAExclusionGroupMember' {
                $groupId     = if ($Action.ExclusionGroupId) { [string]$Action.ExclusionGroupId } else { if ($targetIds.Count -gt 0) { [string]$targetIds[0] } else { '' } }
                $principalId = if ($Action.ExcludedPrincipalId) { [string]$Action.ExcludedPrincipalId } else { $objectId }
                $policyId    = [string]$Action.PolicyId
                if (-not $policyId -or $policyId -eq '') {
                    $result.ValidationErrors.Add("PolicyId missing — BLOCKED")
                    $result.Valid = $false
                    break
                }
                if (-not $groupId -or $groupId -eq '') {
                    $result.ValidationErrors.Add("ExclusionGroupId missing — BLOCKED")
                    $result.Valid = $false
                    break
                }
                if (-not $principalId -or $principalId -eq '') {
                    $result.ValidationErrors.Add("ExcludedPrincipalId missing — BLOCKED")
                    $result.Valid = $false
                    break
                }
                # Safety: check EmergencyAccessIndicator and BreakGlassIndicator
                if ($Action.EmergencyAccessIndicator -eq $true) {
                    $result.ValidationErrors.Add("EmergencyAccessIndicator=true — BLOCKED")
                    $result.Valid = $false
                    break
                }
                if ($Action.BreakGlassIndicator -eq $true) {
                    $result.ValidationErrors.Add("BreakGlassIndicator=true — BLOCKED")
                    $result.Valid = $false
                    break
                }
                # Read CA policy (read-only, confirm it still excludes the group)
                try {
                    $policy = Get-MgIdentityConditionalAccessPolicy -ConditionalAccessPolicyId $policyId -ErrorAction Stop
                    if ($null -eq $policy) {
                        $result.ValidationErrors.Add("CA policy $policyId not found — BLOCKED")
                        $result.Valid = $false
                        break
                    }
                    # Check if policy excludes the group
                    $excludedGroups = @()
                    if ($policy.Conditions -and $policy.Conditions.Users) {
                        $excludedGroups = @($policy.Conditions.Users.ExcludeGroups)
                    }
                    if ($null -ne $policy.AdditionalProperties -and $policy.AdditionalProperties['conditions']) {
                        $conds = $policy.AdditionalProperties['conditions']
                        if ($conds['users'] -and $conds['users']['excludeGroups']) {
                            $excludedGroups += @($conds['users']['excludeGroups'])
                        }
                    }
                    $stillExcludes = $excludedGroups -contains $groupId
                    if (-not $stillExcludes) {
                        $result.InvalidTargets.Add("$groupId : CA policy no longer excludes this group (stale/no-op)")
                    }
                } catch {
                    $result.ValidationErrors.Add("CA policy read failed for $policyId : $_")
                    $result.Valid = $false
                    break
                }
                # Read group and confirm principal is member
                try {
                    $members = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)
                    $isMember = $null -ne ($members | Where-Object { $_.Id -eq $principalId })
                    if (-not $isMember) {
                        $result.InvalidTargets.Add("$principalId : not member of exclusion group $groupId (already removed or state changed)")
                    }
                } catch {
                    $result.ValidationErrors.Add("Group member read failed for $groupId : $_")
                    $result.Valid = $false
                    break
                }
            }

        }
    } catch {
        $result.ErrorDetail = $_.ToString()
        $result.Valid = $false
    }

    return $result
}

$script:ExecutionMap = @{
    'DEC-USER-001' = 'RemoveGroupMembership'
    'DEC-USER-002' = 'RevokeAppRoleAssignment'
    'DEC-USER-003' = 'RemoveDirectoryRoleAssignment'
    'DEC-ROLE-001' = 'RemoveDirectoryRoleAssignment'
    'DEC-AP-001'   = 'RemoveAccessPackageAssignment'
    'DEC-AP-002'   = 'RemoveAccessPackageAssignment'
    'DEC-AP-007'   = 'RemoveAccessPackageAssignment'
    'DEC-AP-008'   = 'RemoveAccessPackageAssignment'
    'DEC-PIM-001'  = 'RemovePimEligibleAssignment'
    'DEC-PIM-002'  = 'RemovePimEligibleAssignment'
    'DEC-PIM-003'  = 'RemovePimEligibleAssignment'
    'DEC-PIM-004'  = 'RemovePimEligibleAssignment'
    'DEC-PIM-005'  = 'RemovePimEligibleAssignment'
    'DEC-PIM-006'  = 'RemovePimEligibleAssignment'
    'DEC-GUEST-001' = 'RemoveGuestGroupMembership'
    'DEC-GUEST-002' = 'GuestGroupOrAppRole'
    'DEC-GUEST-003' = 'RemoveGuestGroupMembership'
    'DEC-GREV-001'  = 'RemoveGuestGroupMembership'
    'DEC-GREV-002'  = 'RemoveGuestGroupMembership'
    'DEC-GREV-003'  = 'GuestGroupOrAppRole'
    'DEC-APP-005'   = 'RemoveExpiredApplicationCredential'
    # Rev3.3
    'DEC-APP-001'   = 'AddApplicationOwner'
    'DEC-APP-002'   = 'AddApplicationOwner'
    'DEC-APP-003'   = 'AddApplicationOwner'
    'DEC-SPN-001'   = 'AddApplicationOwner'
    'DEC-CA-002'    = 'RemoveCAExclusionGroupMember'
    'DEC-CA-003'    = 'RemoveCAExclusionGroupMember'
    'DEC-CA-004'    = 'RemoveCAExclusionGroupMember'
}

$script:ManualApprovalFindingIds = @(
    'DEC-USER-002','DEC-USER-003','DEC-ROLE-001',
    'DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008',
    'DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006',
    'DEC-GUEST-001','DEC-GUEST-002','DEC-GUEST-003',
    'DEC-GREV-001','DEC-GREV-002','DEC-GREV-003',
    'DEC-APP-005',
    'DEC-APP-001','DEC-APP-002','DEC-APP-003','DEC-SPN-001',
    'DEC-CA-002','DEC-CA-003','DEC-CA-004'
)

function Confirm-DecomGuestIdentity {
    # Validates that the target object exists and UserType is Guest.
    # Returns: Valid, ErrorDetail
    param([string]$ObjectId)

    $result = [PSCustomObject]@{
        Valid       = $false
        UserType    = ''
        ErrorDetail = ''
    }

    try {
        $user = Get-MgUser -UserId $ObjectId -Property 'Id,UserType' -ErrorAction Stop
        if ($null -eq $user) {
            $result.ErrorDetail = "Guest user $ObjectId not found"
            return $result
        }
        $result.UserType = [string]$user.UserType
        if ($result.UserType -ne 'Guest') {
            $result.ErrorDetail = "UserType is '$($result.UserType)' not Guest — blocked to prevent non-guest write"
            return $result
        }
        $result.Valid = $true
    } catch {
        $result.ErrorDetail = "Guest identity read failed for $ObjectId : $_"
    }

    return $result
}

function Invoke-DecomRemediation {
    param(
        [object[]]$ApprovedActions,
        [PSCustomObject]$ExecutionLog,
        [bool]$AllowNonInteractive
    )

    $results = [PSCustomObject]@{
        Executed       = 0
        Failed         = 0
        PartialFailed  = 0
        Blocked        = 0
        OperatorDeclined = 0
        OutOfScope     = 0
        Skipped        = 0
    }

    foreach ($action in @($ApprovedActions)) {
        $actionId    = [string]$action.ActionId
        $findingId   = [string]$action.FindingId
        $objectId    = [string]$action.ObjectId
        $displayName = [string]$action.DisplayName
        $actionType  = [string]$action.ActionType
        $targetIds   = @($action.TargetObjectIds)

        $errorDetail = ''

        # Gate C: ProtectedObject — absolute block, no override
        if ($action.ProtectedObject -eq $true) {
            Add-DecomExecutionAction `
                -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                -Outcome 'Blocked' -TargetObjectIds $targetIds `
                -TargetsBefore @() -TargetsAfter @() -ErrorDetail 'ProtectedObject=true'
            continue
        }

        # Gate C: Execution scope check
        if (-not $script:ExecutionMap.ContainsKey($findingId)) {
            Add-DecomExecutionAction `
                -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                -Outcome 'OutOfScope' -TargetObjectIds $targetIds `
                -TargetsBefore @() -TargetsAfter @() `
                -ErrorDetail "FindingId '$findingId' is not in Rev2.0 execution scope"
            continue
        }

        # Gate C: ManualApprovalRequired — prompt unless NonInteractive is authorized
        if (($script:ManualApprovalFindingIds -contains $findingId) -and (-not $AllowNonInteractive)) {
            $response = Read-Host "Execute action $actionId ($actionType) on '$displayName'? [y/n]"
            if ($response -notmatch '^[yY]') {
                Add-DecomExecutionAction `
                    -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                    -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                    -Outcome 'OperatorDeclined' -TargetObjectIds $targetIds `
                    -TargetsBefore @() -TargetsAfter @() -ErrorDetail 'Operator declined at prompt'
                continue
            }
        }

        # Target revalidation — confirm every target still exists and belongs to the approved object
        Write-DecomInfo "Revalidating targets for $actionId..."
        $revalidation = Confirm-DecomActionTargetValid -Action $action

        if (-not $revalidation.Valid) {
            $blockDetail = "Target revalidation FAILED: " +
                           (($revalidation.ValidationErrors + $revalidation.InvalidTargets) -join '; ')
            Write-Host "[BLOCKED]   $actionId $findingId — $displayName : $blockDetail" -ForegroundColor Red
            Add-DecomExecutionAction `
                -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                -Outcome 'Blocked' -TargetObjectIds $targetIds `
                -TargetsBefore @() -TargetsAfter @() `
                -ErrorDetail $blockDetail
            continue
        }

        if ($revalidation.InvalidTargets.Count -gt 0) {
            if ($revalidation.InvalidTargets.Count -eq $targetIds.Count -and
                $actionType -in @('RemoveGuestGroupMembership','RevokeGuestAppRoleAssignment',
                                  'RemoveExpiredApplicationCredential',
                                  'AddApplicationOwner','RemoveCAExclusionGroupMember')) {
                Add-DecomExecutionAction `
                    -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                    -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                    -Outcome 'Skipped' -TargetObjectIds $targetIds `
                    -TargetsBefore @() -TargetsAfter @() `
                    -ErrorDetail ("All targets already in expected state: " + ($revalidation.InvalidTargets -join '; '))
                $results.Skipped++
                continue
            }
            Write-DecomWarn "Some targets for $actionId are already in expected state: $($revalidation.InvalidTargets -join '; ')"
        }

        # Query state before execution
        $beforeState = Get-DecomTargetState -Action $action

        # Execute per approved TargetObjectId
        $failedTargets = [System.Collections.Generic.List[string]]::new()

        switch ($actionType) {

            'RemoveGroupMembership' {
                foreach ($groupId in $targetIds) {
                    try {
                        $members = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)
                        $isMember = $null -ne ($members | Where-Object { $_.Id -eq $objectId })
                        if ($isMember) {
                            Remove-MgGroupMemberByRef -GroupId $groupId -DirectoryObjectId $objectId -ErrorAction Stop
                        }
                    } catch {
                        $failedTargets.Add($groupId)
                        $errorDetail += "Group $groupId : $_; "
                    }
                }
            }

            'RevokeAppRoleAssignment' {
                foreach ($assignmentId in $targetIds) {
                    try {
                        $allAssignments = @(Get-MgUserAppRoleAssignment -UserId $objectId -All -ErrorAction Stop)
                        $exists = $null -ne ($allAssignments | Where-Object { $_.Id -eq $assignmentId })
                        if ($exists) {
                            Remove-MgUserAppRoleAssignment -UserId $objectId -AppRoleAssignmentId $assignmentId -ErrorAction Stop
                        }
                    } catch {
                        $failedTargets.Add($assignmentId)
                        $errorDetail += "Assignment $assignmentId : $_; "
                    }
                }
            }

            'RemoveDirectoryRoleAssignment' {
                foreach ($roleAssignmentId in $targetIds) {
                    try {
                        $assignment = Get-MgRoleManagementDirectoryRoleAssignment `
                            -UnifiedRoleAssignmentId $roleAssignmentId -ErrorAction SilentlyContinue
                        if ($null -ne $assignment) {
                            Remove-MgRoleManagementDirectoryRoleAssignment `
                                -UnifiedRoleAssignmentId $roleAssignmentId -ErrorAction Stop
                        }
                    } catch {
                        $failedTargets.Add($roleAssignmentId)
                        $errorDetail += "RoleAssignment $roleAssignmentId : $_; "
                    }
                }
            }

            'RemoveAccessPackageAssignment' {
                if (-not (Get-Command 'Remove-MgEntitlementManagementAssignment' -ErrorAction SilentlyContinue)) {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                        -ErrorDetail 'Access package assignment removal cmdlet unavailable.'
                    continue
                }
                foreach ($assignmentId in $targetIds) {
                    try {
                        $existing = Get-MgEntitlementManagementAssignment `
                            -AccessPackageAssignmentId $assignmentId -ErrorAction SilentlyContinue
                        if ($null -ne $existing) {
                            Remove-MgEntitlementManagementAssignment `
                                -AccessPackageAssignmentId $assignmentId -ErrorAction Stop
                        }
                    } catch {
                        $failedTargets.Add($assignmentId)
                        $errorDetail += "Assignment $assignmentId : $_; "
                    }
                }
            }

            'RemovePimEligibleAssignment' {
                if (-not (Get-Command 'Remove-MgRoleManagementDirectoryRoleEligibilitySchedule' -ErrorAction SilentlyContinue)) {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                        -ErrorDetail 'PIM eligible assignment removal cmdlet unavailable.'
                    continue
                }
                foreach ($scheduleId in $targetIds) {
                    try {
                        $schedule = Get-MgRoleManagementDirectoryRoleEligibilitySchedule `
                            -UnifiedRoleEligibilityScheduleId $scheduleId -ErrorAction SilentlyContinue
                        if ($null -ne $schedule) {
                            Remove-MgRoleManagementDirectoryRoleEligibilitySchedule `
                                -UnifiedRoleEligibilityScheduleId $scheduleId -ErrorAction Stop
                        }
                    } catch {
                        $failedTargets.Add($scheduleId)
                        $errorDetail += "Schedule $scheduleId : $_; "
                    }
                }
            }

            'RemoveGuestGroupMembership' {
                $guestValidation = Confirm-DecomGuestIdentity -ObjectId $objectId
                if (-not $guestValidation.Valid) {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore @() -TargetsAfter @() `
                        -ErrorDetail "Guest identity validation failed: $($guestValidation.ErrorDetail)"
                    continue
                }
                foreach ($groupId in $targetIds) {
                    try {
                        $members = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)
                        $isMember = $null -ne ($members | Where-Object { $_.Id -eq $objectId })
                        if ($isMember) {
                            Remove-MgGroupMemberByRef -GroupId $groupId -DirectoryObjectId $objectId -ErrorAction Stop
                        }
                    } catch {
                        $failedTargets.Add($groupId)
                        $errorDetail += "Group $groupId : $_; "
                    }
                }
            }

            'RevokeGuestAppRoleAssignment' {
                $guestValidation = Confirm-DecomGuestIdentity -ObjectId $objectId
                if (-not $guestValidation.Valid) {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore @() -TargetsAfter @() `
                        -ErrorDetail "Guest identity validation failed: $($guestValidation.ErrorDetail)"
                    continue
                }
                foreach ($assignmentId in $targetIds) {
                    try {
                        $allAssignments = @(Get-MgUserAppRoleAssignment -UserId $objectId -All -ErrorAction Stop)
                        $exists = $null -ne ($allAssignments | Where-Object { $_.Id -eq $assignmentId })
                        if ($exists) {
                            Remove-MgUserAppRoleAssignment -UserId $objectId -AppRoleAssignmentId $assignmentId -ErrorAction Stop
                        }
                    } catch {
                        $failedTargets.Add($assignmentId)
                        $errorDetail += "Assignment $assignmentId : $_; "
                    }
                }
            }

            'RemoveExpiredApplicationCredential' {
                # Read application — block if read fails
                $app = $null
                try {
                    $app = Get-MgApplication -ApplicationId $objectId -ErrorAction Stop
                } catch {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                        -ErrorDetail "Application read failed: $_"
                    continue
                }
                if ($null -eq $app) {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                        -ErrorDetail "Application $objectId not found — stale target"
                    continue
                }

                $now = [datetime]::UtcNow
                foreach ($keyId in $targetIds) {
                    $pwdCred = @($app.PasswordCredentials | Where-Object { $_.KeyId -and [string]$_.KeyId -eq $keyId })
                    $keyCred = @($app.KeyCredentials  | Where-Object { $_.KeyId -and [string]$_.KeyId -eq $keyId })

                    if ($pwdCred.Count -eq 0 -and $keyCred.Count -eq 0) {
                        # Credential already removed — Skipped, not Failed
                        continue
                    }

                    $credSource = if ($pwdCred.Count -gt 0) { 'PasswordCredential' } else { 'KeyCredential' }

                    try {
                        if ($credSource -eq 'PasswordCredential') {
                            if (-not (Get-Command 'Remove-MgApplicationPassword' -ErrorAction SilentlyContinue)) {
                                $failedTargets.Add($keyId)
                                $errorDetail += "KeyId $keyId : Remove-MgApplicationPassword cmdlet unavailable; "
                            } else {
                                Remove-MgApplicationPassword -ApplicationId $objectId -KeyId $keyId -ErrorAction Stop
                            }
                        } else {
                            if (-not (Get-Command 'Remove-MgApplicationKey' -ErrorAction SilentlyContinue)) {
                                $failedTargets.Add($keyId)
                                $errorDetail += "KeyId $keyId : Remove-MgApplicationKey cmdlet unavailable; "
                            } else {
                                Remove-MgApplicationKey -ApplicationId $objectId -KeyId $keyId -ErrorAction Stop
                            }
                        }
                    } catch {
                        $failedTargets.Add($keyId)
                        $errorDetail += "KeyId $keyId : $_; "
                    }
                }
            }

            'AddApplicationOwner' {
                $newOwnerObjId = [string]$action.NewOwnerObjectId
                $objType       = [string]$action.ObjectType
                if (-not $newOwnerObjId -or $newOwnerObjId -eq '') {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                        -ErrorDetail "NewOwnerObjectId missing — BLOCKED"
                    continue
                }
                $odataRef = "https://graph.microsoft.com/v1.0/directoryObjects/$newOwnerObjId"
                try {
                    if ($objType -eq 'ServicePrincipal') {
                        if (-not (Get-Command 'New-MgServicePrincipalOwnerByRef' -ErrorAction SilentlyContinue)) {
                            Add-DecomExecutionAction `
                                -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                                -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                                -Outcome 'Blocked' -TargetObjectIds $targetIds `
                                -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                                -ErrorDetail 'New-MgServicePrincipalOwnerByRef cmdlet unavailable.'
                            continue
                        }
                        New-MgServicePrincipalOwnerByRef -ServicePrincipalId $objectId `
                            -BodyParameter @{ '@odata.id' = $odataRef } -ErrorAction Stop
                    } else {
                        if (-not (Get-Command 'New-MgApplicationOwnerByRef' -ErrorAction SilentlyContinue)) {
                            Add-DecomExecutionAction `
                                -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                                -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                                -Outcome 'Blocked' -TargetObjectIds $targetIds `
                                -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                                -ErrorDetail 'New-MgApplicationOwnerByRef cmdlet unavailable.'
                            continue
                        }
                        New-MgApplicationOwnerByRef -ApplicationId $objectId `
                            -BodyParameter @{ '@odata.id' = $odataRef } -ErrorAction Stop
                    }
                } catch {
                    $failedTargets.Add($newOwnerObjId)
                    $errorDetail += "Owner add failed for $newOwnerObjId : $_; "
                }
            }

            'RemoveCAExclusionGroupMember' {
                $groupId     = if ($action.ExclusionGroupId) { [string]$action.ExclusionGroupId } else { if ($targetIds.Count -gt 0) { [string]$targetIds[0] } else { '' } }
                $principalId = if ($action.ExcludedPrincipalId) { [string]$action.ExcludedPrincipalId } else { $objectId }
                if (-not $groupId -or -not $principalId) {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                        -ErrorDetail "ExclusionGroupId or ExcludedPrincipalId missing — BLOCKED"
                    continue
                }
                # Safety re-check at execution time
                if ($action.EmergencyAccessIndicator -eq $true -or $action.BreakGlassIndicator -eq $true) {
                    Add-DecomExecutionAction `
                        -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                        -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                        -Outcome 'Blocked' -TargetObjectIds $targetIds `
                        -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                        -ErrorDetail "EmergencyAccess/BreakGlass indicator — BLOCKED at execution time"
                    continue
                }
                try {
                    Remove-MgGroupMemberByRef -GroupId $groupId -DirectoryObjectId $principalId -ErrorAction Stop
                } catch {
                    $failedTargets.Add($groupId)
                    $errorDetail += "CA exclusion group member removal failed for principal $principalId in group $groupId : $_; "
                }
            }

            default {
                Add-DecomExecutionAction `
                    -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                    -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                    -Outcome 'Failed' -TargetObjectIds $targetIds `
                    -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter @() `
                    -ErrorDetail "Unsupported ActionType '$actionType'"
                continue
            }
        }

        # Re-query state after execution.
        # P1-04: structured result distinguishes query failure from confirmed-removed (empty set).
        $afterState = Get-DecomTargetState -Action $action

        # Write failures take precedence over after-state.
        # P1-04: AP/PIM after-state query failure → PartialFailed, not Executed.
        #        A failed re-query cannot serve as evidence that the write succeeded.
        $outcome = if ($failedTargets.Count -gt 0) {
            if ($failedTargets.Count -lt $targetIds.Count) { 'PartialFailed' } else { 'Failed' }
        } elseif (-not $afterState.QuerySucceeded) {
            $errorDetail += "Post-write re-query failed: $($afterState.ErrorDetail)"
            'PartialFailed'
        } elseif ($afterState.PresentTargetIds.Count -eq 0) {
            'Executed'
        } elseif ($afterState.PresentTargetIds.Count -lt $targetIds.Count) {
            'PartialFailed'
        } else {
            'Failed'
        }

        Add-DecomExecutionAction `
            -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
            -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
            -Outcome $outcome -TargetObjectIds $targetIds `
            -TargetsBefore $beforeState.PresentTargetIds -TargetsAfter $afterState.PresentTargetIds `
            -ErrorDetail $errorDetail
    }
}

function Get-DecomTargetState {
    # P1-04: returns structured result so after-state query failures are not silently treated as Executed.
    param([object]$Action)

    $actionType     = [string]$Action.ActionType
    $objectId       = [string]$Action.ObjectId
    $targetIds      = @($Action.TargetObjectIds)
    $present        = [System.Collections.Generic.List[string]]::new()
    $querySucceeded = $true
    $queryError     = ''

    switch ($actionType) {

        'RemoveGroupMembership' {
            foreach ($groupId in $targetIds) {
                try {
                    $members = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)
                    if ($null -ne ($members | Where-Object { $_.Id -eq $objectId })) {
                        $present.Add($groupId)
                    }
                } catch { }
            }
        }

        'RevokeAppRoleAssignment' {
            try {
                $allAssignments = @(Get-MgUserAppRoleAssignment -UserId $objectId -All -ErrorAction Stop)
                foreach ($assignmentId in $targetIds) {
                    if ($null -ne ($allAssignments | Where-Object { $_.Id -eq $assignmentId })) {
                        $present.Add($assignmentId)
                    }
                }
            } catch { }
        }

        'RemoveDirectoryRoleAssignment' {
            foreach ($roleAssignmentId in $targetIds) {
                try {
                    $a = Get-MgRoleManagementDirectoryRoleAssignment `
                        -UnifiedRoleAssignmentId $roleAssignmentId -ErrorAction SilentlyContinue
                    if ($null -ne $a) {
                        $present.Add($roleAssignmentId)
                    }
                } catch { }
            }
        }

        'RemoveAccessPackageAssignment' {
            foreach ($assignmentId in $targetIds) {
                try {
                    $assignment = Get-MgEntitlementManagementAssignment `
                        -AccessPackageAssignmentId $assignmentId -ErrorAction Stop
                    if ($null -ne $assignment) {
                        $present.Add($assignmentId)
                    }
                } catch {
                    $querySucceeded = $false
                    $queryError += "Assignment $assignmentId re-query failed: $_; "
                }
            }
        }

        'RemovePimEligibleAssignment' {
            foreach ($scheduleId in $targetIds) {
                try {
                    $schedule = Get-MgRoleManagementDirectoryRoleEligibilitySchedule `
                        -UnifiedRoleEligibilityScheduleId $scheduleId -ErrorAction Stop
                    if ($null -ne $schedule) {
                        $present.Add($scheduleId)
                    }
                } catch {
                    $querySucceeded = $false
                    $queryError += "Schedule $scheduleId re-query failed: $_; "
                }
            }
        }

        'RemoveGuestGroupMembership' {
            foreach ($groupId in $targetIds) {
                try {
                    $members = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)
                    if ($null -ne ($members | Where-Object { $_.Id -eq $objectId })) {
                        $present.Add($groupId)
                    }
                } catch {
                    $querySucceeded = $false
                    $queryError += "Group $groupId membership re-query failed: $_; "
                }
            }
        }

        'RevokeGuestAppRoleAssignment' {
            try {
                $allAssignments = @(Get-MgUserAppRoleAssignment -UserId $objectId -All -ErrorAction Stop)
                foreach ($assignmentId in $targetIds) {
                    if ($null -ne ($allAssignments | Where-Object { $_.Id -eq $assignmentId })) {
                        $present.Add($assignmentId)
                    }
                }
            } catch {
                $querySucceeded = $false
                $queryError += "App role assignment re-query failed for guest $objectId : $_; "
            }
        }

        'RemoveExpiredApplicationCredential' {
            try {
                $app = Get-MgApplication -ApplicationId $objectId -ErrorAction Stop
                if ($null -eq $app) {
                    $querySucceeded = $false
                    $queryError += "Application $objectId not found during post-write re-query; "
                } else {
                    foreach ($keyId in $targetIds) {
                        $pwdCred = @($app.PasswordCredentials | Where-Object { $_.KeyId -and [string]$_.KeyId -eq $keyId })
                        $keyCred = @($app.KeyCredentials  | Where-Object { $_.KeyId -and [string]$_.KeyId -eq $keyId })
                        if ($pwdCred.Count -gt 0 -or $keyCred.Count -gt 0) {
                            $present.Add($keyId)
                        }
                    }
                }
            } catch {
                $querySucceeded = $false
                $queryError += "Application $objectId re-query failed: $_; "
            }
        }

        'AddApplicationOwner' {
            $newOwnerObjId = [string]$Action.NewOwnerObjectId
            if (-not $newOwnerObjId) { break }
            $objType = [string]$Action.ObjectType
            try {
                if ($objType -eq 'ServicePrincipal') {
                    $owners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $objectId -All -ErrorAction Stop)
                } else {
                    $owners = @(Get-MgApplicationOwner -ApplicationId $objectId -All -ErrorAction Stop)
                }
                if ($null -ne ($owners | Where-Object { $_.Id -eq $newOwnerObjId })) {
                    $present.Add($newOwnerObjId)
                }
            } catch {
                $querySucceeded = $false
                $queryError += "Owner re-query failed for $objectId : $_; "
            }
        }

        'RemoveCAExclusionGroupMember' {
            $groupId     = if ($Action.ExclusionGroupId) { [string]$Action.ExclusionGroupId } else { if ($targetIds.Count -gt 0) { [string]$targetIds[0] } else { '' } }
            $principalId = if ($Action.ExcludedPrincipalId) { [string]$Action.ExcludedPrincipalId } else { $objectId }
            if (-not $groupId) { break }
            try {
                $members = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)
                if ($null -ne ($members | Where-Object { $_.Id -eq $principalId })) {
                    $present.Add($groupId)
                }
            } catch {
                $querySucceeded = $false
                $queryError += "CA exclusion group member re-query failed for $groupId : $_; "
            }
        }

        default {
            throw "Unsupported ActionType '$actionType' in Get-DecomTargetState"
        }
    }

    return [PSCustomObject]@{
        QuerySucceeded   = $querySucceeded
        PresentTargetIds = $present.ToArray()
        ErrorDetail      = $queryError
    }
}
