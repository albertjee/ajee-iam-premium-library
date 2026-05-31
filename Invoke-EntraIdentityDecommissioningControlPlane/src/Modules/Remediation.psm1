#Requires -Version 5.1

$script:ExecutionMap = @{
    'DEC-USER-001' = 'RemoveGroupMembership'
    'DEC-USER-002' = 'RevokeAppRoleAssignment'
    'DEC-USER-003' = 'RemoveDirectoryRoleAssignment'
    'DEC-ROLE-001' = 'RemoveDirectoryRoleAssignment'
}

$script:ManualApprovalFindingIds = @('DEC-USER-002','DEC-USER-003','DEC-ROLE-001')

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

        $targetsBefore = @()
        $targetsAfter  = @()
        $errorDetail   = ''

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

        # Query state before execution
        $targetsBefore = Get-DecomTargetState -Action $action

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

            default {
                Add-DecomExecutionAction `
                    -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
                    -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
                    -Outcome 'Failed' -TargetObjectIds $targetIds `
                    -TargetsBefore $targetsBefore -TargetsAfter @() `
                    -ErrorDetail "Unsupported ActionType '$actionType'"
                continue
            }
        }

        # Re-query state after execution (records actual existsAfter)
        $targetsAfter = Get-DecomTargetState -Action $action

        # Outcome: Executed if all targets absent, PartialFailed if some remain, Failed if all remain
        $outcome = if ($targetsAfter.Count -eq 0) {
            'Executed'
        } elseif ($targetsAfter.Count -lt $targetIds.Count) {
            'PartialFailed'
        } else {
            'Failed'
        }

        Add-DecomExecutionAction `
            -ExecutionLog $ExecutionLog -ActionId $actionId -FindingId $findingId `
            -ObjectId $objectId -DisplayName $displayName -ActionType $actionType `
            -Outcome $outcome -TargetObjectIds $targetIds `
            -TargetsBefore $targetsBefore -TargetsAfter $targetsAfter `
            -ErrorDetail $errorDetail
    }
}

function Get-DecomTargetState {
    param([object]$Action)

    $actionType = [string]$Action.ActionType
    $objectId   = [string]$Action.ObjectId
    $targetIds  = @($Action.TargetObjectIds)
    $present    = [System.Collections.Generic.List[string]]::new()

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

        default {
            throw "Unsupported ActionType '$actionType' in Get-DecomTargetState"
        }
    }

    return $present.ToArray()
}
