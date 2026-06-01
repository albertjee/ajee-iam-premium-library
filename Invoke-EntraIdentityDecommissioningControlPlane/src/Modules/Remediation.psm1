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
}

$script:ManualApprovalFindingIds = @(
    'DEC-USER-002','DEC-USER-003','DEC-ROLE-001',
    'DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008',
    'DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006'
)

function Invoke-DecomRemediation {
    param(
        [object[]]$ApprovedActions,
        [PSCustomObject]$ExecutionLog,
        [bool]$AllowNonInteractive
    )

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
