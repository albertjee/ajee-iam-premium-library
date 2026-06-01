#Requires -Version 5.1

function Get-DecomSha256 {
    param([string]$InputString)

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        $hash  = $sha256.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-','').ToLowerInvariant()
    } finally {
        if ($sha256) { $sha256.Dispose() }
    }
}

function Convert-DecomActionToCanonical {
    param([object]$Action)

    [ordered]@{
        ActionId           = [string]$Action.ActionId
        FindingId          = [string]$Action.FindingId
        ObjectId           = [string]$Action.ObjectId
        ObjectType         = [string]$Action.ObjectType
        DisplayName        = [string]$Action.DisplayName
        UserPrincipalName  = [string]$Action.UserPrincipalName
        ActionType         = [string]$Action.ActionType
        TargetObjectIds    = @($Action.TargetObjectIds | Sort-Object)
        TargetDisplayNames = @($Action.TargetDisplayNames)
        Evidence           = [string]$Action.Evidence
        RiskScore          = [int]$Action.RiskScore
        ProtectedObject    = [bool]$Action.ProtectedObject
        RoleAssignmentId          = [string]$Action.RoleAssignmentId
        RoleDefinitionId          = [string]$Action.RoleDefinitionId
        RoleDisplayName           = [string]$Action.RoleDisplayName
        AccessPackageAssignmentId = [string]$Action.AccessPackageAssignmentId
        AccessPackageId           = [string]$Action.AccessPackageId
        AccessPackageName         = [string]$Action.AccessPackageName
        TargetPrincipalId         = [string]$Action.TargetPrincipalId
        EligibilityScheduleId     = [string]$Action.EligibilityScheduleId
        UserType                  = [string]$Action.UserType
        GuestOnly                 = if ($Action.GuestOnly) { [bool]$Action.GuestOnly } else { $false }
        SponsorEvidenceStatus     = [string]$Action.SponsorEvidenceStatus
        ReviewEvidenceStatus      = [string]$Action.ReviewEvidenceStatus
        ReadinessStatus           = [string]$Action.ReadinessStatus
        ReadinessReason           = [string]$Action.ReadinessReason
        GroupId                   = [string]$Action.GroupId
        GroupDisplayName          = [string]$Action.GroupDisplayName
        AppRoleAssignmentId       = [string]$Action.AppRoleAssignmentId
        ResourceId                = [string]$Action.ResourceId
        ResourceDisplayName       = [string]$Action.ResourceDisplayName
    }
}

function Get-DecomApprovedActionsHash {
    param([object[]]$ApprovedActions)

    $canonical = @(
        $ApprovedActions |
            Sort-Object { $_.ActionId } |
            ForEach-Object { Convert-DecomActionToCanonical -Action $_ }
    )

    $serialized = $canonical | ConvertTo-Json -Depth 10 -Compress
    return Get-DecomSha256 -InputString $serialized
}

function Get-DecomApprovalEnvelopeHash {
    param(
        [pscustomobject]$Manifest,
        [string]$ActionsHash
    )

    # PS5.1 ConvertFrom-Json auto-converts ISO date strings to DateTime objects.
    # Normalize to consistent ISO 8601 UTC strings so the hash is stable across
    # the string → JSON → DateTime roundtrip.
    $ic     = [System.Globalization.CultureInfo]::InvariantCulture
    $styles = [System.Globalization.DateTimeStyles]::RoundtripKind

    $approvedUtcRaw = $Manifest.ApprovedUtc
    $approvedUtcStr = if ($approvedUtcRaw -is [datetime]) {
        $approvedUtcRaw.ToUniversalTime().ToString('o')
    } else {
        try {
            ([datetime]::Parse([string]$approvedUtcRaw, $ic, $styles)).ToUniversalTime().ToString('o')
        } catch { [string]$approvedUtcRaw }
    }

    $expiresUtcRaw = $Manifest.ExpiresUtc
    $expiresUtcStr = if ($expiresUtcRaw -is [datetime]) {
        $expiresUtcRaw.ToUniversalTime().ToString('o')
    } else {
        try {
            ([datetime]::Parse([string]$expiresUtcRaw, $ic, $styles)).ToUniversalTime().ToString('o')
        } catch { [string]$expiresUtcRaw }
    }

    $envelope = "$($Manifest.EngagementId)|$($Manifest.ClientName)|$($Manifest.WhatIfRunId)|" +
                "$($Manifest.ApprovedBy)|$approvedUtcStr|$expiresUtcStr|" +
                "$($Manifest.AllowNonInteractive)|$ActionsHash"

    return Get-DecomSha256 -InputString $envelope
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
    'DEC-GUEST-002' = 'GuestMultiAction'
    'DEC-GUEST-003' = 'RemoveGuestGroupMembership'
    'DEC-GREV-001' = 'RemoveGuestGroupMembership'
    'DEC-GREV-002' = 'RemoveGuestGroupMembership'
    'DEC-GREV-003' = 'GuestMultiAction'
}

$script:GuestDualFindingIds = [System.Collections.Generic.HashSet[string]] @('DEC-GUEST-002', 'DEC-GREV-003')
$script:GuestGroupOnlyFindingIds = [System.Collections.Generic.HashSet[string]] @(
    'DEC-GUEST-001', 'DEC-GUEST-003', 'DEC-GREV-001', 'DEC-GREV-002'
)
$script:AllGuestFindingIds = [System.Collections.Generic.HashSet[string]] @(
    'DEC-GUEST-001', 'DEC-GUEST-002', 'DEC-GUEST-003',
    'DEC-GREV-001', 'DEC-GREV-002', 'DEC-GREV-003'
)

function Get-DecomFindingExactTargetIds {
    param([pscustomobject]$Finding, [string]$FindingType)
    $ids = [System.Collections.Generic.List[string]]::new()
    if ($FindingType -eq 'AP') {
        foreach ($prop in @('AccessPackageAssignmentId','AssignmentId','TargetObjectId')) {
            $val = $Finding.$prop
            if ($val -and [string]$val -ne '') { [void]$ids.Add([string]$val); break }
        }
    } elseif ($FindingType -eq 'PIM') {
        foreach ($prop in @('EligibilityScheduleId','RoleEligibilityScheduleId','PimEligibleAssignmentId','TargetObjectId')) {
            $val = $Finding.$prop
            if ($val -and [string]$val -ne '') { [void]$ids.Add([string]$val); break }
        }
    } elseif ($FindingType -eq 'GuestGroupMembership') {
        foreach ($prop in @('GroupId','GroupIds','TargetGroupId','TargetGroupIds','TargetObjectId','TargetObjectIds','MemberOfGroupId','MemberOfGroupIds')) {
            $val = $Finding.$prop
            if ($val) {
                if ($val -is [string]) {
                    if ($val -ne '') { [void]$ids.Add($val) }
                } elseif ($val -is [System.Collections.IEnumerable]) {
                    foreach ($item in $val) {
                        if ($item -and [string]$item -ne '') { [void]$ids.Add($item) }
                    }
                }
            }
        }
    } elseif ($FindingType -eq 'GuestAppRoleAssignment') {
        foreach ($prop in @('AppRoleAssignmentId','AppRoleAssignmentIds','AssignmentId','AssignmentIds','TargetObjectId','TargetObjectIds')) {
            $val = $Finding.$prop
            if ($val) {
                if ($val -is [string]) {
                    if ($val -ne '') { [void]$ids.Add($val) }
                } elseif ($val -is [System.Collections.IEnumerable]) {
                    foreach ($item in $val) {
                        if ($item -and [string]$item -ne '') { [void]$ids.Add($item) }
                    }
                }
            }
        }
    }
    # Remove duplicates and return as array (always [object[]] even for 1 element)
    return @($ids | Sort-Object -Unique)
}

function Resolve-DecomExecutableTargets {
    param([pscustomobject]$Finding)

    $result = [PSCustomObject]@{
        TargetObjects = @()
        Resolved      = $false
        ErrorDetail   = ''
    }

    try {
        switch ($Finding.FindingId) {

            'DEC-USER-001' {
                $memberOf = @(Get-MgUserMemberOf -UserId $Finding.ObjectId -All -ErrorAction Stop)
                $groups = @($memberOf | Where-Object {
                    $_.AdditionalProperties -and
                    $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group'
                })

                $targets = @(
                    foreach ($g in $groups) {
                        $name = if ($g.AdditionalProperties['displayName']) {
                            $g.AdditionalProperties['displayName']
                        } else {
                            $g.Id
                        }

                        [PSCustomObject]@{
                            TargetObjectId    = $g.Id
                            TargetDisplayName = $name
                            RoleAssignmentId  = ''
                            RoleDefinitionId  = ''
                            RoleDisplayName   = ''
                        }
                    }
                )

                $result.TargetObjects = $targets
                $result.Resolved = ($targets.Count -gt 0)
            }

            'DEC-USER-002' {
                $appRoles = @(Get-MgUserAppRoleAssignment -UserId $Finding.ObjectId -All -ErrorAction Stop)

                $targets = @(
                    foreach ($a in $appRoles) {
                        $name = if ($a.ResourceDisplayName) {
                            $a.ResourceDisplayName
                        } else {
                            $a.Id
                        }

                        [PSCustomObject]@{
                            TargetObjectId    = $a.Id
                            TargetDisplayName = $name
                            RoleAssignmentId  = ''
                            RoleDefinitionId  = ''
                            RoleDisplayName   = ''
                        }
                    }
                )

                $result.TargetObjects = $targets
                $result.Resolved = ($targets.Count -gt 0)
            }

            { $_ -in 'DEC-USER-003','DEC-ROLE-001' } {
                # Exact role-assignment expansion.
                # Generate one target object per role assignment ID.
                # Do not create broad "all roles for user" action semantics.
                $assignments = @(Get-MgRoleManagementDirectoryRoleAssignment `
                    -Filter "principalId eq '$($Finding.ObjectId)'" -ErrorAction Stop)

                $targets = @(
                    foreach ($a in $assignments) {
                        $roleName = $a.RoleDefinitionId

                        # Best-effort role name lookup. Failure must not block target precision.
                        try {
                            $roleDef = Get-MgRoleManagementDirectoryRoleDefinition `
                                -UnifiedRoleDefinitionId $a.RoleDefinitionId -ErrorAction Stop
                            if ($roleDef.DisplayName) {
                                $roleName = $roleDef.DisplayName
                            }
                        } catch {
                            $roleName = $a.RoleDefinitionId
                        }

                        [PSCustomObject]@{
                            TargetObjectId    = $a.Id
                            TargetDisplayName = $roleName
                            RoleAssignmentId  = $a.Id
                            RoleDefinitionId  = $a.RoleDefinitionId
                            RoleDisplayName   = $roleName
                        }
                    }
                )

                $result.TargetObjects = $targets
                $result.Resolved = ($targets.Count -gt 0)
            }

            { $_ -in 'DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008' } {
                $exactIds = Get-DecomFindingExactTargetIds -Finding $Finding -FindingType 'AP'
                if ($exactIds.Count -eq 0) {
                    $result.ErrorDetail = 'No exact AccessPackageAssignmentId found in finding — broad principal query not permitted'
                    $result.Resolved = $false
                } else {
                    $targets = @(
                        foreach ($assignId in $exactIds) {
                            [PSCustomObject]@{
                                TargetObjectId    = $assignId
                                TargetDisplayName = $assignId
                                RoleAssignmentId  = ''
                                RoleDefinitionId  = ''
                                RoleDisplayName   = ''
                            }
                        }
                    )
                    $result.TargetObjects = $targets
                    $result.Resolved = ($targets.Count -gt 0)
                }
            }

            { $_ -in 'DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006' } {
                $exactIds = Get-DecomFindingExactTargetIds -Finding $Finding -FindingType 'PIM'
                if ($exactIds.Count -eq 0) {
                    $result.ErrorDetail = 'No exact EligibilityScheduleId found in finding — broad principal query not permitted'
                    $result.Resolved = $false
                } else {
                    $targets = @(
                        foreach ($schedId in $exactIds) {
                            [PSCustomObject]@{
                                TargetObjectId    = $schedId
                                TargetDisplayName = $schedId
                                RoleAssignmentId  = ''
                                RoleDefinitionId  = ''
                                RoleDisplayName   = ''
                            }
                        }
                    )
                    $result.TargetObjects = $targets
                    $result.Resolved = ($targets.Count -gt 0)
                }
            }

            { $script:GuestGroupOnlyFindingIds.Contains($_) } {
                $exactGroupIds = Get-DecomFindingExactTargetIds -Finding $Finding -FindingType 'GuestGroupMembership'
                if ($exactGroupIds.Count -eq 0) {
                    $result.ErrorDetail = 'No exact group IDs found in finding — PlanOnly: use manual guidance'
                    $result.Resolved = $false
                } else {
                    $result.TargetObjects = @(foreach ($gId in $exactGroupIds) {
                        [PSCustomObject]@{
                            TargetObjectId    = $gId
                            TargetDisplayName = $gId
                            TargetActionType  = 'RemoveGuestGroupMembership'
                            RoleAssignmentId  = ''
                            RoleDefinitionId  = ''
                            RoleDisplayName   = ''
                        }
                    })
                    $result.Resolved = ($result.TargetObjects.Count -gt 0)
                }
            }

            { $script:GuestDualFindingIds.Contains($_) } {
                $exactGroupIds   = Get-DecomFindingExactTargetIds -Finding $Finding -FindingType 'GuestGroupMembership'
                $exactAppRoleIds = Get-DecomFindingExactTargetIds -Finding $Finding -FindingType 'GuestAppRoleAssignment'
                $allTargets = [System.Collections.Generic.List[object]]::new()
                foreach ($gId in $exactGroupIds) {
                    $allTargets.Add([PSCustomObject]@{
                        TargetObjectId    = $gId
                        TargetDisplayName = $gId
                        TargetActionType  = 'RemoveGuestGroupMembership'
                        RoleAssignmentId  = ''; RoleDefinitionId = ''; RoleDisplayName = ''
                    })
                }
                foreach ($aId in $exactAppRoleIds) {
                    $allTargets.Add([PSCustomObject]@{
                        TargetObjectId    = $aId
                        TargetDisplayName = $aId
                        TargetActionType  = 'RevokeGuestAppRoleAssignment'
                        RoleAssignmentId  = ''; RoleDefinitionId = ''; RoleDisplayName = ''
                    })
                }
                if ($allTargets.Count -eq 0) {
                    $result.ErrorDetail = 'No exact group IDs or app role assignment IDs found — PlanOnly: use manual guidance'
                    $result.Resolved = $false
                } else {
                    $result.TargetObjects = $allTargets.ToArray()
                    $result.Resolved = $true
                }
            }

            default {
                $result.ErrorDetail = "FindingId '$($Finding.FindingId)' is not in execution scope"
            }
        }
    } catch {
        $result.ErrorDetail = $_.ToString()
        $result.Resolved = $false
    }

    return $result
}

function New-DecomWhatIfActionPlan {
    param(
        [object[]]$Findings,
        [string]$EngagementId,
        [string]$ClientName,
        [string]$Assessor,
        [string]$WhatIfRunId,
        [string]$OutputPath,
        [int]$ExpiryDays = 3
    )

    $actions = [System.Collections.Generic.List[object]]::new()
    $planOnly = [System.Collections.Generic.List[object]]::new()
    $skipped = [System.Collections.Generic.List[object]]::new()

    $claimedOperationKeys = [System.Collections.Generic.HashSet[string]]::new()
    $claimedRoleAssignmentIds = [System.Collections.Generic.HashSet[string]]::new()

    $actionNum = 1

    # Process DEC-USER-003 before DEC-ROLE-001 so lifecycle action wins.
    $priorityOrder = @('DEC-USER-003','DEC-USER-001','DEC-USER-002','DEC-ROLE-001')
    $sortedFindings = @(
        foreach ($fid in $priorityOrder) {
            $Findings | Where-Object { $_.FindingId -eq $fid }
        }
        $Findings | Where-Object { $priorityOrder -notcontains $_.FindingId }
    )

    foreach ($finding in @($sortedFindings)) {
        if ($null -eq $finding) { continue }
        if (-not $script:ExecutionMap.ContainsKey($finding.FindingId)) { continue }

        if ($finding.ProtectedObject -eq $true) {
            $skipped.Add([ordered]@{
                FindingId = $finding.FindingId
                DisplayName = $finding.DisplayName
                Reason = 'ProtectedObject'
            })
            continue
        }

        Write-DecomInfo "Resolving executable targets for $($finding.FindingId): $($finding.DisplayName)"
        $targets = Resolve-DecomExecutableTargets -Finding $finding

        if (-not $targets.Resolved) {
            $reason = if ($targets.ErrorDetail) { $targets.ErrorDetail } else { 'No executable targets resolved' }
            $skipped.Add([ordered]@{
                FindingId = $finding.FindingId
                DisplayName = $finding.DisplayName
                Reason = $reason
            })
            Write-DecomWarn "Skipped executable action for $($finding.FindingId): $reason"
            continue
        }

        $actionType = $script:ExecutionMap[$finding.FindingId]

        if ($finding.FindingId -in @('DEC-USER-003','DEC-ROLE-001')) {
            foreach ($target in @($targets.TargetObjects)) {
                $roleAssignmentId = [string]$target.RoleAssignmentId
                if (-not $roleAssignmentId) {
                    $skipped.Add([ordered]@{
                        FindingId = $finding.FindingId
                        DisplayName = $finding.DisplayName
                        Reason = 'Missing RoleAssignmentId'
                    })
                    continue
                }

                if ($finding.FindingId -eq 'DEC-ROLE-001' -and $claimedRoleAssignmentIds.Contains($roleAssignmentId)) {
                    $planOnly.Add([ordered]@{
                        FindingId = $finding.FindingId
                        ObjectId = $finding.ObjectId
                        DisplayName = $finding.DisplayName
                        UserPrincipalName = $finding.UserPrincipalName
                        TargetObjectId = $roleAssignmentId
                        TargetDisplayName = $target.TargetDisplayName
                        Reason = 'Role assignment already covered by DEC-USER-003 executable action'
                    })
                    continue
                }

                $opKey = "$actionType|$($finding.ObjectId)|$($target.TargetObjectId)"
                if ($claimedOperationKeys.Contains($opKey)) {
                    $planOnly.Add([ordered]@{
                        FindingId = $finding.FindingId
                        ObjectId = $finding.ObjectId
                        DisplayName = $finding.DisplayName
                        TargetObjectId = $target.TargetObjectId
                        TargetDisplayName = $target.TargetDisplayName
                        Reason = 'Duplicate target operation already included in ApprovedActions'
                    })
                    continue
                }

                [void]$claimedOperationKeys.Add($opKey)

                if ($finding.FindingId -eq 'DEC-USER-003') {
                    [void]$claimedRoleAssignmentIds.Add($roleAssignmentId)
                }

                $action = [ordered]@{
                    ActionId = 'ACT-{0:D3}' -f $actionNum
                    FindingId = $finding.FindingId
                    ObjectId = $finding.ObjectId
                    ObjectType = $finding.ObjectType
                    DisplayName = $finding.DisplayName
                    UserPrincipalName = $finding.UserPrincipalName
                    ActionType = $actionType
                    TargetObjectIds = @($target.TargetObjectId)
                    TargetDisplayNames = @($target.TargetDisplayName)
                    Evidence = $finding.Evidence
                    RiskScore = $finding.RiskScore
                    ProtectedObject = $finding.ProtectedObject
                    RoleAssignmentId = $target.RoleAssignmentId
                    RoleDefinitionId = $target.RoleDefinitionId
                    RoleDisplayName = $target.RoleDisplayName
                }

                $actions.Add($action)
                $actionNum++
            }

            continue
        }

        # Guest findings: group by TargetActionType; dual-action findings may generate two actions.
        if ($script:AllGuestFindingIds.Contains($finding.FindingId)) {
            $typeGroups = @($targets.TargetObjects | Group-Object { $_.TargetActionType })
            foreach ($typeGroup in $typeGroups) {
                $groupActionType = $typeGroup.Name
                if (-not $groupActionType) { continue }

                $effectiveTargets = @()
                foreach ($tgt in $typeGroup.Group) {
                    $opKey = "$groupActionType|$($finding.ObjectId)|$($tgt.TargetObjectId)"
                    if ($claimedOperationKeys.Contains($opKey)) {
                        $planOnly.Add([ordered]@{
                            FindingId         = $finding.FindingId
                            ObjectId          = $finding.ObjectId
                            DisplayName       = $finding.DisplayName
                            TargetObjectId    = $tgt.TargetObjectId
                            TargetDisplayName = $tgt.TargetDisplayName
                            Reason            = 'Duplicate target operation already included in ApprovedActions'
                        })
                        continue
                    }
                    [void]$claimedOperationKeys.Add($opKey)
                    $effectiveTargets += $tgt
                }

                if ($effectiveTargets.Count -eq 0) { continue }

                $rollback = if ($groupActionType -eq 'RemoveGuestGroupMembership') {
                    'Rollback requires re-adding the guest to the group after business owner approval. Rev3.1 does not auto-rollback guest group membership changes.'
                } else {
                    'Rollback requires re-granting the guest app role assignment through the application owner or identity governance process. Rev3.1 does not auto-rollback app role assignment changes.'
                }
                $targetType = if ($groupActionType -eq 'RemoveGuestGroupMembership') { 'Group' } else { 'AppRoleAssignment' }
                $sponsorStatus = if ($finding.SponsorEvidence -or $finding.Manager -or $finding.Department -or $finding.BusinessOwner) { 'Present' } else { 'Unknown' }
                $reviewStatus = if ($finding.LastReviewEvidenceUtc) { 'Present' } else { 'Unknown' }

                $action = [ordered]@{
                    ActionId               = 'ACT-{0:D3}' -f $actionNum
                    FindingId              = $finding.FindingId
                    ObjectId               = $finding.ObjectId
                    ObjectType             = $finding.ObjectType
                    DisplayName            = $finding.DisplayName
                    UserPrincipalName      = $finding.UserPrincipalName
                    UserType               = if ($finding.UserType) { [string]$finding.UserType } else { 'Guest' }
                    ActionType             = $groupActionType
                    TargetObjectIds        = @($effectiveTargets | ForEach-Object { $_.TargetObjectId })
                    TargetDisplayNames     = @($effectiveTargets | ForEach-Object { $_.TargetDisplayName })
                    TargetType             = $targetType
                    Evidence               = $finding.Evidence
                    RiskScore              = $finding.RiskScore
                    ProtectedObject        = $finding.ProtectedObject
                    RequiresManualApproval = $true
                    GuestOnly              = $true
                    RollbackGuidance       = $rollback
                    PostWriteEvidenceRequired = $true
                    SponsorEvidenceStatus  = $sponsorStatus
                    ReviewEvidenceStatus   = $reviewStatus
                    ReadinessStatus        = 'ReadyForApproval'
                    ReadinessReason        = 'Exact target IDs present and guest identity validated'
                    PreflightChecks        = @('TargetObjectIdsPresent', 'GuestIdentityValidated', 'ProtectedObjectNotSet')
                    RoleAssignmentId       = ''
                    RoleDefinitionId       = ''
                    RoleDisplayName        = ''
                }

                $actions.Add($action)
                $actionNum++
            }
            continue
        }

        # Non-role action families can group multiple target IDs in one action,
        # but duplicate target operations must still be removed.
        $effectiveTargets = @()
        foreach ($target in @($targets.TargetObjects)) {
            $opKey = "$actionType|$($finding.ObjectId)|$($target.TargetObjectId)"
            if ($claimedOperationKeys.Contains($opKey)) {
                $planOnly.Add([ordered]@{
                    FindingId = $finding.FindingId
                    ObjectId = $finding.ObjectId
                    DisplayName = $finding.DisplayName
                    TargetObjectId = $target.TargetObjectId
                    TargetDisplayName = $target.TargetDisplayName
                    Reason = 'Duplicate target operation already included in ApprovedActions'
                })
                continue
            }

            [void]$claimedOperationKeys.Add($opKey)
            $effectiveTargets += $target
        }

        if ($effectiveTargets.Count -eq 0) {
            $skipped.Add([ordered]@{
                FindingId = $finding.FindingId
                DisplayName = $finding.DisplayName
                Reason = 'No unique executable targets after deduplication'
            })
            continue
        }

        $action = [ordered]@{
            ActionId = 'ACT-{0:D3}' -f $actionNum
            FindingId = $finding.FindingId
            ObjectId = $finding.ObjectId
            ObjectType = $finding.ObjectType
            DisplayName = $finding.DisplayName
            UserPrincipalName = $finding.UserPrincipalName
            ActionType = $actionType
            TargetObjectIds = @($effectiveTargets | ForEach-Object { $_.TargetObjectId })
            TargetDisplayNames = @($effectiveTargets | ForEach-Object { $_.TargetDisplayName })
            Evidence = $finding.Evidence
            RiskScore = $finding.RiskScore
            ProtectedObject = $finding.ProtectedObject
            RoleAssignmentId = ''
            RoleDefinitionId = ''
            RoleDisplayName = ''
        }

        $actions.Add($action)
        $actionNum++
    }

    $actionsArray = $actions.ToArray()
    $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actionsArray

    $manifest = [ordered]@{
        SchemaVersion = '3.1'
        GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
        EngagementId = $EngagementId
        ClientName = $ClientName
        Assessor = $Assessor
        WhatIfRunId = $WhatIfRunId
        ApprovalStatus = 'PendingSignature'
        ApprovedBy = '[CLIENT APPROVER NAME AND ROLE — REQUIRED]'
        ApprovedUtc = '[APPROVAL DATE — REQUIRED]'
        ExpiresUtc = (Get-Date).AddDays($ExpiryDays).ToUniversalTime().ToString('o')
        AllowNonInteractive = $false
        ApprovedActionsHash = $actionsHash
        ApprovalEnvelopeHash = '[RECOMPUTE AFTER SIGNING — run Update-DecomApprovalManifestHash]'
        ApprovedActions = $actionsArray
        PlanOnlyActions = $planOnly.ToArray()
        SkippedActions = $skipped.ToArray()
        Instructions = @(
            '1. Review every ApprovedAction with the client.',
            '2. Confirm ObjectId, DisplayName, ActionType, TargetDisplayNames, and RoleDisplayName where present.',
            '3. Remove any actions the client does not approve.',
            '4. Set ApprovalStatus to Approved.',
            '5. Set ApprovedBy to client approver full name and role.',
            '6. Set ApprovedUtc to ISO datetime of approval.',
            '7. Optionally set AllowNonInteractive to true only if client approves automation without per-action prompts.',
            '8. Run: Update-DecomApprovalManifestHash -ManifestPath <path>.',
            '9. Do not modify any other fields after hash update.'
        )
    }

    $fileName = "whatif-action-plan-$EngagementId-$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    $path = Join-Path $OutputPath $fileName
    $manifest | ConvertTo-Json -Depth 12 | Set-Content -Path $path -Encoding UTF8

    Write-DecomOk "WhatIf action plan written: $path"
    Write-DecomInfo "ApprovedActions: $($actionsArray.Count); PlanOnly: $($planOnly.Count); Skipped: $($skipped.Count)"
    return $path
}

function Update-DecomApprovalManifestHash {
    param([string]$ManifestPath)

    if (-not (Test-Path $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $manifest.ApprovedActions
    $envHash = Get-DecomApprovalEnvelopeHash -Manifest $manifest -ActionsHash $actionsHash

    $raw = Get-Content $ManifestPath -Raw
    $raw = $raw -replace '"ApprovedActionsHash"\s*:\s*"[^"]*"', "`"ApprovedActionsHash`": `"$actionsHash`""
    $raw = $raw -replace '"ApprovalEnvelopeHash"\s*:\s*"[^"]*"', "`"ApprovalEnvelopeHash`": `"$envHash`""

    Set-Content -Path $ManifestPath -Value $raw -Encoding UTF8

    Write-Host "[OK]    ApprovedActionsHash : $actionsHash" -ForegroundColor Green
    Write-Host "[OK]    ApprovalEnvelopeHash: $envHash" -ForegroundColor Green
}

function Test-DecomWhatIfManifest {
    param([string]$ManifestPath, [string]$CurrentEngagementId)

    if (-not (Test-Path $ManifestPath)) {
        return [PSCustomObject]@{
            Valid = $false
            Errors = @("WhatIf manifest not found: $ManifestPath")
            Manifest = $null
        }
    }

    try {
        $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    } catch {
        return [PSCustomObject]@{
            Valid = $false
            Errors = @("Invalid JSON in WhatIf manifest: $_.Exception.Message")
            Manifest = $null
        }
    }

    $errors = @()

    # Exist on disk (checked above)
    # Be valid JSON (checked above)

    if (-not $manifest.RunId) {
        $errors += "RunId missing"
    } else {
        try {
            [guid]$manifest.RunId | Out-Null
        } catch {
            $errors += "RunId must parse as GUID"
        }
    }

    if ($manifest.Mode -ne 'WhatIfRemediation') {
        $errors += "Mode must equal WhatIfRemediation"
    }

    if ($manifest.EngagementId -ne $CurrentEngagementId) {
        $errors += "EngagementId must match current run"
    }

    if (-not $manifest.GeneratedUtc) {
        $errors += "GeneratedUtc must exist"
    } else {
        try {
            $generated = [datetime]::Parse($manifest.GeneratedUtc)
            $now = [datetime]::UtcNow
            $age = $now - $generated
            if ($age.TotalDays -gt 7) {
                $errors += "GeneratedUtc must not be older than 7 days"
            }
        } catch {
            $errors += "GeneratedUtc must be valid ISO datetime"
        }
    }

    return [PSCustomObject]@{
        Valid = ($errors.Count -eq 0)
        Errors = $errors
        Manifest = $manifest
    }
}

function Test-DecomApprovalManifest {
    param([string]$ManifestPath, [string]$CurrentEngagementId, [string]$CurrentClientName, [string]$WhatIfRunId, [switch]$NonInteractive)

    if (-not (Test-Path $ManifestPath)) {
        return [PSCustomObject]@{
            Valid = $false
            Errors = @("Approval manifest not found: $ManifestPath")
            Manifest = $null
        }
    }

    try {
        $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    } catch {
        return [PSCustomObject]@{
            Valid = $false
            Errors = @("Invalid JSON in approval manifest: $_.Exception.Message")
            Manifest = $null
        }
    }

    $errors = @()

    # Exist on disk (checked above)
    # Be valid JSON (checked above)

    if ($manifest.ApprovalStatus -ne 'Approved') {
        $errors += "ApprovalStatus = Approved"
    }

    if ($manifest.EngagementId -ne $CurrentEngagementId) {
        $errors += "EngagementId matches current run"
    }

    if ($manifest.ClientName -ne $CurrentClientName) {
        $errors += "ClientName matches current run"
    }

    if (-not $manifest.ApprovedBy -or $manifest.ApprovedBy -eq '[CLIENT APPROVER NAME AND ROLE — REQUIRED]') {
        $errors += "ApprovedBy is set and not placeholder text"
    }

    if (-not $manifest.ApprovedUtc -or $manifest.ApprovedUtc -eq '[APPROVAL DATE — REQUIRED]') {
        $errors += "ApprovedUtc is set and not placeholder text"
    }

    if (-not $manifest.ApprovedActions -or $manifest.ApprovedActions.Count -eq 0) {
        $errors += "ApprovedActions is a non-empty array"
    } else {
        # No duplicate ActionId values
        $actionIds = $manifest.ApprovedActions | Select-Object -ExpandProperty ActionId
        if ($actionIds.Count -ne ($actionIds | Sort-Object -Unique).Count) {
            $errors += "No duplicate ActionId values"
        }

        # No duplicate target operations using: ActionType | ObjectId | TargetObjectId
        $operationKeys = [System.Collections.Generic.HashSet[string]]::new()
        $dupOpFound = $false
        foreach ($action in $manifest.ApprovedActions) {
            if ($dupOpFound) { break }
            foreach ($targetId in @($action.TargetObjectIds)) {
                $opKey = "$($action.ActionType)|$($action.ObjectId)|$targetId"
                if ($operationKeys.Contains($opKey)) {
                    $errors += "Duplicate target operation: $opKey"
                    $dupOpFound = $true
                    break
                }
                [void]$operationKeys.Add($opKey)
            }
        }

        # Every action FindingId is in execution scope
        foreach ($action in $manifest.ApprovedActions) {
            if (-not $script:ExecutionMap.ContainsKey($action.FindingId)) {
                $errors += "FindingId '$($action.FindingId)' is not in execution scope"
                break
            }
        }

        # Rev3.0 action types require SchemaVersion 3.0 or higher
        $rev3ActionTypes = @('RemoveAccessPackageAssignment','RemovePimEligibleAssignment')
        $rev3Actions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -in $rev3ActionTypes })
        if ($rev3Actions.Count -gt 0) {
            $schemaVer = [string]$manifest.SchemaVersion
            $major = 0
            if ($schemaVer -match '^(\d+)\.') { [int]$major = $Matches[1] }
            if ($major -lt 3) {
                $errors += "Rev3.0 action types (AP/PIM) require approval manifest SchemaVersion 3.0 or higher (found: $schemaVer)"
            }
        }

        # Rev3.1 guest action types require SchemaVersion 3.1 or higher
        $rev31GuestActionTypes = @('RemoveGuestGroupMembership','RevokeGuestAppRoleAssignment')
        $rev31GuestActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -in $rev31GuestActionTypes })
        if ($rev31GuestActions.Count -gt 0) {
            $svRaw = [string]$manifest.SchemaVersion
            $svMajor = 0; $svMinor = 0
            if ($svRaw -match '^(\d+)\.(\d+)') { [int]$svMajor = $Matches[1]; [int]$svMinor = $Matches[2] }
            if ($svMajor -lt 3 -or ($svMajor -eq 3 -and $svMinor -lt 1)) {
                $errors += "Rev3.1 guest action types require approval manifest SchemaVersion 3.1 or higher (found: $svRaw)"
            }
        }

        # Every action ActionType matches FindingId
        foreach ($action in $manifest.ApprovedActions) {
            # Dual-action guest findings allow either guest action type
            if ($script:GuestDualFindingIds.Contains($action.FindingId)) {
                if ($action.ActionType -notin @('RemoveGuestGroupMembership','RevokeGuestAppRoleAssignment')) {
                    $errors += "Every action ActionType matches FindingId"
                    break
                }
                continue
            }
            $expectedActionType = $script:ExecutionMap[$action.FindingId]
            if ($action.ActionType -ne $expectedActionType) {
                $errors += "Every action ActionType matches FindingId"
                break
            }
        }

        # Every action ObjectId is present
        foreach ($action in $manifest.ApprovedActions) {
            if (-not $action.ObjectId) {
                $errors += "Every action ObjectId is present"
                break
            }
        }

        # Every action TargetObjectIds is non-empty
        foreach ($action in $manifest.ApprovedActions) {
            if (-not $action.TargetObjectIds -or $action.TargetObjectIds.Count -eq 0) {
                $errors += "Every action TargetObjectIds is non-empty"
                break
            }
        }

        # Role assignment actions have exactly one TargetObjectId
        foreach ($action in $manifest.ApprovedActions) {
            if ($action.FindingId -in @('DEC-USER-003','DEC-ROLE-001')) {
                if ($action.TargetObjectIds.Count -ne 1) {
                    $errors += "Role assignment actions have exactly one TargetObjectId"
                    break
                }
                # RoleAssignmentId is present and equals TargetObjectIds[0]
                if (-not $action.RoleAssignmentId -or $action.RoleAssignmentId -ne $action.TargetObjectIds[0]) {
                    $errors += "RoleAssignmentId is present and equals TargetObjectIds[0]"
                    break
                }
            }
        }

        if (-not $WhatIfRunId) {
            $errors += "WhatIfRunId not provided for binding check"
        } elseif ($manifest.WhatIfRunId -ne $WhatIfRunId) {
            $errors += "WhatIfRunId '$($manifest.WhatIfRunId)' does not match WhatIf manifest RunId '$WhatIfRunId'"
        }

        if (-not $manifest.ApprovedActionsHash) {
            $errors += "ApprovedActionsHash matches SHA-256 of canonical ApprovedActions"
        } else {
            $expectedHash = Get-DecomApprovedActionsHash -ApprovedActions $manifest.ApprovedActions
            if ($manifest.ApprovedActionsHash -ne $expectedHash) {
                $errors += "ApprovedActionsHash matches SHA-256 of canonical ApprovedActions"
            }
        }

        if (-not $manifest.ApprovalEnvelopeHash) {
            $errors += "ApprovalEnvelopeHash matches SHA-256 of approval metadata + ApprovedActionsHash"
        } else {
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $manifest.ApprovedActions
            $expectedEnvHash = Get-DecomApprovalEnvelopeHash -Manifest $manifest -ActionsHash $actionsHash
            if ($manifest.ApprovalEnvelopeHash -ne $expectedEnvHash) {
                $errors += "ApprovalEnvelopeHash matches SHA-256 of approval metadata + ApprovedActionsHash"
            }
        }

        if ($NonInteractive.IsPresent -and -not $manifest.AllowNonInteractive) {
            $errors += "AllowNonInteractive = true if -NonInteractive is used"
        }

        # ExpiresUtc is present and not expired
        if (-not $manifest.ExpiresUtc) {
            $errors += "ExpiresUtc is present and not expired"
        } else {
            try {
                $expires = [datetime]::Parse($manifest.ExpiresUtc)
                $now = [datetime]::UtcNow
                if ($expires -lt $now) {
                    $errors += "ExpiresUtc is present and not expired"
                }
            } catch {
                $errors += "ExpiresUtc must be valid ISO datetime"
            }
        }
    }

    # Optional execution window validation — runs regardless of ApprovedActions state
    if ($manifest.ExecutionWindowStartUtc -and $manifest.ExecutionWindowEndUtc) {
        try {
            $ic       = [System.Globalization.CultureInfo]::InvariantCulture
            $styles   = [System.Globalization.DateTimeStyles]::RoundtripKind
            $startRaw = $manifest.ExecutionWindowStartUtc
            $endRaw   = $manifest.ExecutionWindowEndUtc
            # PS5.1 ConvertFrom-Json converts ISO 8601 strings to DateTime objects.
            # Handle both DateTime (already parsed) and string (needs parsing).
            $windowStart = if ($startRaw -is [datetime]) {
                $startRaw.ToUniversalTime()
            } else {
                [datetime]::Parse([string]$startRaw, $ic, $styles).ToUniversalTime()
            }
            $windowEnd = if ($endRaw -is [datetime]) {
                $endRaw.ToUniversalTime()
            } else {
                [datetime]::Parse([string]$endRaw, $ic, $styles).ToUniversalTime()
            }
            $now = (Get-Date).ToUniversalTime()
            if ($now -lt $windowStart) {
                $errors += "Current time is before ExecutionWindowStartUtc ($($manifest.ExecutionWindowStartUtc))"
            }
            if ($now -gt $windowEnd) {
                $errors += "Current time is after ExecutionWindowEndUtc ($($manifest.ExecutionWindowEndUtc))"
            }
        } catch {
            $errors += "ExecutionWindow dates are not valid: $_"
        }
    }

    return [PSCustomObject]@{
        Valid = ($errors.Count -eq 0)
        Errors = $errors
        Manifest = $manifest
    }
}