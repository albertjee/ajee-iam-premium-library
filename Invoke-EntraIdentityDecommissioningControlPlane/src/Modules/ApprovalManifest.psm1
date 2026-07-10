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

    # Core identifier fields — always present
    [ordered]@{
        ActionId          = [string]$Action.ActionId
        FindingId         = [string]$Action.FindingId
        ObjectId          = [string]$Action.ObjectId
        ObjectType        = [string]$Action.ObjectType
        DisplayName       = [string]$Action.DisplayName
        UserPrincipalName = [string]$Action.UserPrincipalName
        ActionType        = [string]$Action.ActionType
        TargetObjectIds   = @($Action.TargetObjectIds | Sort-Object)
        TargetDisplayNames= @($Action.TargetDisplayNames)
        Evidence          = [string]$Action.Evidence
        RiskScore         = [int]$Action.RiskScore
        ProtectedObject   = [bool]$Action.ProtectedObject

        # Typed sub-objects — only populated when relevant
        # PIM / Directory Role Assignment
        RoleAssignment = if ($Action.RoleAssignmentId -or $Action.RoleDefinitionId -or $Action.RoleDisplayName) {
            [ordered]@{
                RoleAssignmentId = [string]$Action.RoleAssignmentId
                RoleDefinitionId = [string]$Action.RoleDefinitionId
                RoleDisplayName  = [string]$Action.RoleDisplayName
            }
        } else { $null }

        # Access Package Assignment
        AccessPackage = if ($Action.AccessPackageAssignmentId -or $Action.AccessPackageId -or $Action.AccessPackageName) {
            [ordered]@{
                AccessPackageAssignmentId = [string]$Action.AccessPackageAssignmentId
                AccessPackageId           = [string]$Action.AccessPackageId
                AccessPackageName         = [string]$Action.AccessPackageName
                TargetPrincipalId         = [string]$Action.TargetPrincipalId
                EligibilityScheduleId     = [string]$Action.EligibilityScheduleId
            }
        } else { $null }

        # Guest user metadata (populated for guest users and dual-action guests)
        GuestMetadata = if ($Action.UserType -or $null -ne $Action.GuestOnly) {
            [ordered]@{
                UserType  = [string]$Action.UserType
                GuestOnly = if ($null -ne $Action.GuestOnly) { [bool]$Action.GuestOnly } else { $false }
            }
        } else { $null }

        # Readiness / evidence status
        Readiness = if ($Action.ReadinessStatus -or $Action.ReadinessReason -or $Action.SponsorEvidenceStatus -or $Action.ReviewEvidenceStatus) {
            [ordered]@{
                ReadinessStatus      = [string]$Action.ReadinessStatus
                ReadinessReason      = [string]$Action.ReadinessReason
                SponsorEvidenceStatus= [string]$Action.SponsorEvidenceStatus
                ReviewEvidenceStatus = [string]$Action.ReviewEvidenceStatus
            }
        } else { $null }

        # Group membership
        GroupMembership = if ($Action.GroupId -or $Action.GroupDisplayName -or $Action.AppRoleAssignmentId) {
            [ordered]@{
                GroupId          = [string]$Action.GroupId
                GroupDisplayName = [string]$Action.GroupDisplayName
                AppRoleAssignmentId = [string]$Action.AppRoleAssignmentId
                ResourceId       = [string]$Action.ResourceId
                ResourceDisplayName = [string]$Action.ResourceDisplayName
            }
        } else { $null }

        # Application credential
        Credential = if ($Action.CredentialType -or $Action.CredentialKeyId -or $Action.CredentialEndDateTime) {
            [ordered]@{
                CredentialType     = [string]$Action.CredentialType
                CredentialKeyId    = [string]$Action.CredentialKeyId
                CredentialEndDateTime = [string]$Action.CredentialEndDateTime
                CredentialExpired  = if ($null -ne $Action.CredentialExpired) { [bool]$Action.CredentialExpired } else { $false }
            }
        } else { $null }

        # Application / service principal ownership
        Ownership = if ($Action.NewOwnerObjectId -or $Action.OwnerSource -or $Action.BusinessJustification -or
                         $null -ne $Action.OwnerCount -or $null -ne $Action.HasOwner -or $null -ne $Action.AllowGuestOwner) {
            [ordered]@{
                OwnerCount                = if ($null -ne $Action.OwnerCount) { [int]$Action.OwnerCount } else { 0 }
                HasOwner                  = if ($null -ne $Action.HasOwner) { [bool]$Action.HasOwner } else { $false }
                NewOwnerObjectId           = [string]$Action.NewOwnerObjectId
                NewOwnerUserPrincipalName = [string]$Action.NewOwnerUserPrincipalName
                NewOwnerType             = [string]$Action.NewOwnerType
                OwnerSource              = [string]$Action.OwnerSource
                BusinessJustification    = [string]$Action.BusinessJustification
                AllowGuestOwner          = if ($null -ne $Action.AllowGuestOwner) { [bool]$Action.AllowGuestOwner } else { $false }
            }
        } else { $null }

        # Application metadata
        Application = if ($Action.ApplicationId -or $Action.AppId -or $Action.OwnerCount) {
            [ordered]@{
                ApplicationId = [string]$Action.ApplicationId
                AppId         = [string]$Action.AppId
                OwnerCount    = if ($null -ne $Action.OwnerCount) { [int]$Action.OwnerCount } else { 0 }
                HasOwner      = if ($null -ne $Action.HasOwner) { [bool]$Action.HasOwner } else { $false }
            }
        } else { $null }

        # Conditional Access exclusion group member
        CAExclusion = if ($Action.PolicyId -or $Action.ExclusionGroupId -or $Action.ExcludedPrincipalId) {
            [ordered]@{
                PolicyId                  = [string]$Action.PolicyId
                PolicyDisplayName         = [string]$Action.PolicyDisplayName
                ExclusionGroupId          = [string]$Action.ExclusionGroupId
                ExclusionGroupDisplayName = [string]$Action.ExclusionGroupDisplayName
                ExcludedPrincipalId       = [string]$Action.ExcludedPrincipalId
                EmergencyAccessIndicator  = if ($null -ne $Action.EmergencyAccessIndicator) { [bool]$Action.EmergencyAccessIndicator } else { $false }
                BreakGlassIndicator       = if ($null -ne $Action.BreakGlassIndicator) { [bool]$Action.BreakGlassIndicator } else { $false }
            }
        } else { $null }
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
    'DEC-APP-005'   = 'RemoveExpiredApplicationCredential'
    # Rev3.3 — AddApplicationOwner
    'DEC-APP-001'   = 'AddApplicationOwner'
    'DEC-APP-002'   = 'AddApplicationOwner'
    'DEC-APP-003'   = 'AddApplicationOwner'
    'DEC-SPN-001'   = 'AddApplicationOwner'
    # Rev3.3 — RemoveCAExclusionGroupMember
    'DEC-CA-002'    = 'RemoveCAExclusionGroupMember'
    'DEC-CA-003'    = 'RemoveCAExclusionGroupMember'
    'DEC-CA-004'    = 'RemoveCAExclusionGroupMember'
}

$script:GuestDualFindingIds = [System.Collections.Generic.HashSet[string]] @('DEC-GUEST-002', 'DEC-GREV-003')
$script:GuestGroupOnlyFindingIds = [System.Collections.Generic.HashSet[string]] @(
    'DEC-GUEST-001', 'DEC-GUEST-003', 'DEC-GREV-001', 'DEC-GREV-002'
)
$script:AllGuestFindingIds = [System.Collections.Generic.HashSet[string]] @(
    'DEC-GUEST-001', 'DEC-GUEST-002', 'DEC-GUEST-003',
    'DEC-GREV-001', 'DEC-GREV-002', 'DEC-GREV-003'
)
$script:CredentialFindingIds = [System.Collections.Generic.HashSet[string]] @('DEC-APP-005')
$script:OwnerFindingIds      = [System.Collections.Generic.HashSet[string]] @('DEC-APP-001','DEC-APP-002','DEC-APP-003','DEC-SPN-001')
$script:CAExclusionFindingIds= [System.Collections.Generic.HashSet[string]] @('DEC-CA-002','DEC-CA-003','DEC-CA-004')

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
    } elseif ($FindingType -eq 'CredentialKeyId') {
        foreach ($prop in @('CredentialKeyId','CredentialKeyIds','KeyId','KeyIds','TargetObjectId','TargetObjectIds')) {
            $val = $Finding.$prop
            if ($val) {
                if ($val -is [string]) {
                    if ($val -ne '') { [void]$ids.Add($val); break }
                } elseif ($val -is [System.Collections.IEnumerable]) {
                    foreach ($item in $val) {
                        if ($item -and [string]$item -ne '') { [void]$ids.Add([string]$item) }
                    }
                    if ($ids.Count -gt 0) { break }
                }
            }
        }
    } elseif ($FindingType -eq 'OwnerObjectId') {
        foreach ($prop in @('NewOwnerObjectId','NewOwnerObjectIds','OwnerObjectId','OwnerObjectIds','TargetObjectId','TargetObjectIds')) {
            $val = $Finding.$prop
            if ($val) {
                if ($val -is [string]) {
                    if ($val -ne '') { [void]$ids.Add($val); break }
                } elseif ($val -is [System.Collections.IEnumerable]) {
                    foreach ($item in $val) {
                        if ($item -and [string]$item -ne '') { [void]$ids.Add([string]$item) }
                    }
                    if ($ids.Count -gt 0) { break }
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

    if ($Finding.SuppressCustomerRemediation -eq $true -or $Finding.MicrosoftPlatform -eq $true -or $Finding.FirstPartyMicrosoftApp -eq $true -or $Finding.EvidenceOnly -eq $true -or $Finding.Classification -in @('MicrosoftPlatform', 'ExternalVendorPlatform')) {
        $result.ErrorDetail = 'Microsoft platform identity is evidence-only; executable targets are suppressed.'
        return $result
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

            'DEC-APP-005' {
                $exactKeyIds = Get-DecomFindingExactTargetIds -Finding $Finding -FindingType 'CredentialKeyId'
                if ($exactKeyIds.Count -eq 0) {
                    $result.ErrorDetail = 'No exact credential KeyId found in finding — cannot generate executable credential action'
                    $result.Resolved = $false
                } else {
                    $endDateRaw = [string]$Finding.CredentialEndDateTime
                    $expired = $false
                    if ($endDateRaw) {
                        try {
                            $endDt = [datetime]::Parse($endDateRaw, [System.Globalization.CultureInfo]::InvariantCulture,
                                [System.Globalization.DateTimeStyles]::RoundtripKind)
                            $expired = ($endDt.ToUniversalTime() -lt [datetime]::UtcNow)
                        } catch { $null = $null }
                    }
                    if (-not $expired) {
                        $result.ErrorDetail = 'Credential is not expired at WhatIf generation time — only expired credentials may generate executable actions'
                        $result.Resolved = $false
                    } else {
                        $result.TargetObjects = @(foreach ($kid in $exactKeyIds) {
                            [PSCustomObject]@{
                                TargetObjectId    = $kid
                                TargetDisplayName = $kid
                                TargetActionType  = 'RemoveExpiredApplicationCredential'
                                RoleAssignmentId  = ''; RoleDefinitionId = ''; RoleDisplayName = ''
                            }
                        })
                        $result.Resolved = ($result.TargetObjects.Count -gt 0)
                    }
                }
            }

            { $script:OwnerFindingIds.Contains($_) } {
                # Exact NewOwnerObjectId must be present — no inference from display name
                $exactOwnerIds = Get-DecomFindingExactTargetIds -Finding $Finding -FindingType 'OwnerObjectId'
                if ($exactOwnerIds.Count -eq 0) {
                    $result.ErrorDetail = 'No exact NewOwnerObjectId found in finding — executable AddApplicationOwner not generated (use owner mapping or manual approval)'
                    $result.Resolved = $false
                } else {
                    $objType = if ($Finding.ObjectType) { [string]$Finding.ObjectType } else { 'Application' }
                    $result.TargetObjects = @(foreach ($oid in $exactOwnerIds) {
                        [PSCustomObject]@{
                            TargetObjectId    = $oid
                            TargetDisplayName = $oid
                            TargetActionType  = 'AddApplicationOwner'
                            RoleAssignmentId  = ''; RoleDefinitionId = ''; RoleDisplayName = ''
                            NewOwnerObjectId  = $oid
                        }
                    })
                    $result.Resolved = ($result.TargetObjects.Count -gt 0)
                }
            }

            { $script:CAExclusionFindingIds.Contains($_) } {
                # Exact PolicyId, ExclusionGroupId, and ExcludedPrincipalId must be present
                $policyId    = [string]$Finding.PolicyId
                $groupId     = if ($Finding.ExclusionGroupId) { [string]$Finding.ExclusionGroupId } else { '' }
                $principalId = if ($Finding.ExcludedPrincipalId) { [string]$Finding.ExcludedPrincipalId } else { [string]$Finding.ObjectId }
                if (-not $policyId) {
                    $result.ErrorDetail = 'PolicyId missing — cannot generate executable RemoveCAExclusionGroupMember'
                    $result.Resolved = $false
                } elseif (-not $groupId) {
                    $result.ErrorDetail = 'ExclusionGroupId missing — cannot generate executable RemoveCAExclusionGroupMember'
                    $result.Resolved = $false
                } elseif (-not $principalId) {
                    $result.ErrorDetail = 'ExcludedPrincipalId/ObjectId missing — cannot generate executable RemoveCAExclusionGroupMember'
                    $result.Resolved = $false
                } else {
                    $result.TargetObjects = @([PSCustomObject]@{
                        TargetObjectId    = $groupId
                        TargetDisplayName = if ($Finding.ExclusionGroupDisplayName) { [string]$Finding.ExclusionGroupDisplayName } else { $groupId }
                        TargetActionType  = 'RemoveCAExclusionGroupMember'
                        RoleAssignmentId  = ''; RoleDefinitionId = ''; RoleDisplayName = ''
                        PolicyId          = $policyId
                        ExclusionGroupId  = $groupId
                        ExcludedPrincipalId = $principalId
                    })
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
        if ($finding.SuppressCustomerRemediation -eq $true -or $finding.MicrosoftPlatform -eq $true -or $finding.FirstPartyMicrosoftApp -eq $true -or $finding.EvidenceOnly -eq $true -or $finding.Classification -in @('MicrosoftPlatform', 'ExternalVendorPlatform')) {
            $skipped += [pscustomobject]@{
                FindingId = $finding.FindingId
                DisplayName = $finding.DisplayName
                Reason = 'Customer remediation suppressed for platform identity'
                Classification = $finding.Classification
            }
            continue
        }

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
                    RoleAssignment = [ordered]@{
                        RoleAssignmentId = $target.RoleAssignmentId
                        RoleDefinitionId = $target.RoleDefinitionId
                        RoleDisplayName  = $target.RoleDisplayName
                    }
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
                    ActionType             = $groupActionType
                    TargetObjectIds        = @($effectiveTargets | ForEach-Object { $_.TargetObjectId })
                    TargetDisplayNames     = @($effectiveTargets | ForEach-Object { $_.TargetDisplayName })
                    Evidence               = $finding.Evidence
                    RiskScore              = $finding.RiskScore
                    ProtectedObject        = $finding.ProtectedObject
                    RequiresManualApproval  = $true
                    GuestMetadata = [ordered]@{
                        UserType  = if ($finding.UserType) { [string]$finding.UserType } else { 'Guest' }
                        GuestOnly = $true
                    }
                    GroupMembership = [ordered]@{
                        GroupId = ''
                        GroupDisplayName = ''
                        AppRoleAssignmentId = ''
                        ResourceId = ''
                        ResourceDisplayName = ''
                    }
                    Readiness = [ordered]@{
                        ReadinessStatus       = 'ReadyForApproval'
                        ReadinessReason       = 'Exact target IDs present and guest identity validated'
                        SponsorEvidenceStatus = $sponsorStatus
                        ReviewEvidenceStatus  = $reviewStatus
                    }
                    RollbackGuidance           = $rollback
                    PostWriteEvidenceRequired  = $true
                    PreflightChecks            = @('TargetObjectIdsPresent', 'GuestIdentityValidated', 'ProtectedObjectNotSet')
                }

                $actions.Add($action)
                $actionNum++
            }
            continue
        }

        # Credential findings: one action per expired credential KeyId.
        if ($script:CredentialFindingIds.Contains($finding.FindingId)) {
            foreach ($tgt in @($targets.TargetObjects)) {
                $opKey = "RemoveExpiredApplicationCredential|$($finding.ObjectId)|$($tgt.TargetObjectId)"
                if ($claimedOperationKeys.Contains($opKey)) {
                    $planOnly.Add([ordered]@{
                        FindingId         = $finding.FindingId
                        ObjectId          = $finding.ObjectId
                        DisplayName       = $finding.DisplayName
                        TargetObjectId    = $tgt.TargetObjectId
                        TargetDisplayName = $tgt.TargetDisplayName
                        Reason            = 'Duplicate credential key removal already included in ApprovedActions'
                    })
                    continue
                }
                [void]$claimedOperationKeys.Add($opKey)

                $credType    = [string]$finding.CredentialType
                $credKeyId   = [string]$tgt.TargetObjectId
                $credEndDate = [string]$finding.CredentialEndDateTime

                $action = [ordered]@{
                    ActionId               = 'ACT-{0:D3}' -f $actionNum
                    FindingId              = $finding.FindingId
                    ObjectId               = $finding.ObjectId
                    ObjectType             = if ($finding.ObjectType) { [string]$finding.ObjectType } else { 'Application' }
                    DisplayName            = $finding.DisplayName
                    UserPrincipalName      = [string]$finding.UserPrincipalName
                    ActionType             = 'RemoveExpiredApplicationCredential'
                    TargetObjectIds        = @($credKeyId)
                    TargetDisplayNames     = @($credKeyId)
                    Evidence               = [string]$finding.Evidence
                    RiskScore              = $finding.RiskScore
                    ProtectedObject        = $finding.ProtectedObject
                    RequiresManualApproval  = $true
                    Credential = [ordered]@{
                        CredentialType      = $credType
                        CredentialKeyId     = $credKeyId
                        CredentialEndDateTime = $credEndDate
                        CredentialExpired   = $true
                    }
                    Application = [ordered]@{
                        ApplicationId = [string]$finding.ApplicationId
                        AppId        = [string]$finding.AppId
                        OwnerCount   = if ($null -ne $finding.OwnerCount) { [int]$finding.OwnerCount } else { 0 }
                        HasOwner     = if ($null -ne $finding.HasOwner) { [bool]$finding.HasOwner } else { $false }
                    }
                    Readiness = [ordered]@{
                        ReadinessStatus = 'ReadyForApproval'
                        ReadinessReason = 'Exact expired credential KeyId present and credential expired at WhatIf time'
                    }
                    RollbackGuidance            = 'Rollback requires creating a new application credential through the application owner or platform engineering process. Rev3.2 does not auto-rollback credential removal because secret material cannot be recovered after deletion.'
                    PostWriteEvidenceRequired  = $true
                    PreflightChecks            = @('ExactCredentialKeyIdPresent','CredentialExpiredAtExecutionTime','ProtectedObjectNotSet','ApplicationReadSucceeds')
                }

                $actions.Add($action)
                $actionNum++
            }
            continue
        }

        # Owner findings (Rev3.3): one action per approved NewOwnerObjectId
        if ($script:OwnerFindingIds.Contains($finding.FindingId)) {
            foreach ($tgt in @($targets.TargetObjects)) {
                $newOwnerObjId = if ($tgt.NewOwnerObjectId) { [string]$tgt.NewOwnerObjectId } else { [string]$tgt.TargetObjectId }
                $opKey = "AddApplicationOwner|$($finding.ObjectId)|$newOwnerObjId"
                if ($claimedOperationKeys.Contains($opKey)) {
                    $planOnly.Add([ordered]@{
                        FindingId         = $finding.FindingId
                        ObjectId          = $finding.ObjectId
                        DisplayName       = $finding.DisplayName
                        TargetObjectId    = $newOwnerObjId
                        TargetDisplayName = $tgt.TargetDisplayName
                        Reason            = 'Duplicate owner-add operation already included in ApprovedActions'
                    })
                    continue
                }
                [void]$claimedOperationKeys.Add($opKey)

                $ownerSource = if ($finding.OwnerSource) { [string]$finding.OwnerSource } else { 'ApprovalManifest' }
                $ownerType   = if ($finding.NewOwnerType)  { [string]$finding.NewOwnerType }  else { 'User' }
                $ownerUpn    = if ($finding.NewOwnerUserPrincipalName) { [string]$finding.NewOwnerUserPrincipalName } else { '' }
                $bizJust     = if ($finding.BusinessJustification) { [string]$finding.BusinessJustification } else { 'Application requires an active owner for governance accountability' }
                $objType     = if ($finding.ObjectType) { [string]$finding.ObjectType } else { 'Application' }

                $action = [ordered]@{
                    ActionId               = 'ACT-{0:D3}' -f $actionNum
                    FindingId              = $finding.FindingId
                    ObjectId               = $finding.ObjectId
                    ObjectType             = $objType
                    DisplayName            = $finding.DisplayName
                    UserPrincipalName      = [string]$finding.UserPrincipalName
                    ActionType             = 'AddApplicationOwner'
                    TargetObjectIds        = @($newOwnerObjId)
                    TargetDisplayNames     = @($newOwnerObjId)
                    Evidence               = [string]$finding.Evidence
                    RiskScore              = $finding.RiskScore
                    ProtectedObject        = $finding.ProtectedObject
                    RequiresManualApproval = $true
                    Ownership = [ordered]@{
                        NewOwnerObjectId           = $newOwnerObjId
                        NewOwnerUserPrincipalName = $ownerUpn
                        NewOwnerType               = $ownerType
                        OwnerSource                = $ownerSource
                        BusinessJustification      = $bizJust
                        AllowGuestOwner            = if ($null -ne $finding.AllowGuestOwner) { [bool]$finding.AllowGuestOwner } else { $false }
                    }
                    RollbackGuidance           = 'Rollback requires manually removing the added owner via the application ownership management interface. Rev3.3 does not auto-rollback owner additions.'
                    PostWriteEvidenceRequired  = $true
                    PreflightChecks            = @('ExactNewOwnerObjectIdPresent','TargetApplicationOrServicePrincipalReadable','NewOwnerObjectReadable','NewOwnerNotDisabled','NewOwnerGuestCheckPassed','ProtectedObjectNotSet')
                    Readiness = [ordered]@{
                        ReadinessStatus = 'ReadyForApproval'
                        ReadinessReason = 'Exact NewOwnerObjectId present in approval manifest'
                    }
                }

                $actions.Add($action)
                $actionNum++
            }
            continue
        }

        # CA exclusion findings (Rev3.3): one action per ExclusionGroupId / ExcludedPrincipalId pair
        if ($script:CAExclusionFindingIds.Contains($finding.FindingId)) {
            foreach ($tgt in @($targets.TargetObjects)) {
                $groupId     = if ($tgt.ExclusionGroupId)   { [string]$tgt.ExclusionGroupId }   else { [string]$tgt.TargetObjectId }
                $principalId = if ($tgt.ExcludedPrincipalId){ [string]$tgt.ExcludedPrincipalId } else { [string]$finding.ObjectId }
                $policyId    = if ($tgt.PolicyId)            { [string]$tgt.PolicyId }            else { [string]$finding.PolicyId }
                $opKey = "RemoveCAExclusionGroupMember|$principalId|$groupId"
                if ($claimedOperationKeys.Contains($opKey)) {
                    $planOnly.Add([ordered]@{
                        FindingId         = $finding.FindingId
                        ObjectId          = $finding.ObjectId
                        DisplayName       = $finding.DisplayName
                        TargetObjectId    = $groupId
                        TargetDisplayName = $tgt.TargetDisplayName
                        Reason            = 'Duplicate CA exclusion group member removal already included in ApprovedActions'
                    })
                    continue
                }
                [void]$claimedOperationKeys.Add($opKey)

                $reviewStatus = if ($finding.LastReviewEvidenceUtc) { 'Present' } else { 'Unknown' }
                $isEmergency  = if ($null -ne $finding.EmergencyAccessIndicator) { [bool]$finding.EmergencyAccessIndicator } else { $false }
                $isBreakGlass = if ($null -ne $finding.BreakGlassIndicator)      { [bool]$finding.BreakGlassIndicator }      else { $false }

                $action = [ordered]@{
                    ActionId               = 'ACT-{0:D3}' -f $actionNum
                    FindingId              = $finding.FindingId
                    ObjectId               = $principalId
                    ObjectType             = if ($finding.ObjectType) { [string]$finding.ObjectType } else { 'User' }
                    DisplayName            = $finding.DisplayName
                    UserPrincipalName      = [string]$finding.UserPrincipalName
                    ActionType             = 'RemoveCAExclusionGroupMember'
                    TargetObjectIds        = @($groupId)
                    TargetDisplayNames     = @($tgt.TargetDisplayName)
                    Evidence               = [string]$finding.Evidence
                    RiskScore              = $finding.RiskScore
                    ProtectedObject        = $finding.ProtectedObject
                    RequiresManualApproval  = $true
                    CAExclusion = [ordered]@{
                        PolicyId                  = $policyId
                        PolicyDisplayName         = if ($finding.PolicyDisplayName) { [string]$finding.PolicyDisplayName } else { '' }
                        ExclusionGroupId          = $groupId
                        ExclusionGroupDisplayName = if ($finding.ExclusionGroupDisplayName) { [string]$finding.ExclusionGroupDisplayName } else { $groupId }
                        ExcludedPrincipalId       = $principalId
                        EmergencyAccessIndicator  = $isEmergency
                        BreakGlassIndicator       = $isBreakGlass
                    }
                    Readiness = [ordered]@{
                        ReadinessStatus      = 'ReadyForApproval'
                        ReadinessReason      = 'Exact PolicyId, ExclusionGroupId, and ExcludedPrincipalId present'
                        ReviewEvidenceStatus = $reviewStatus
                    }
                    RollbackGuidance           = 'Rollback requires re-adding the principal to the exclusion group via group membership management. Rev3.3 does not auto-rollback CA exclusion group membership changes.'
                    PostWriteEvidenceRequired  = $true
                    PreflightChecks            = @('ExactExclusionGroupIdPresent','ExactExcludedPrincipalIdPresent','ExactPolicyIdPresent','PolicyStillExcludesGroup','PrincipalIsMember','PrincipalNotProtected','PrincipalNotEmergencyAccess','ProtectedObjectNotSet')
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
        }

        $actions.Add($action)
        $actionNum++
    }

    $actionsArray = $actions.ToArray()
    $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actionsArray

    $manifest = [ordered]@{
        SchemaVersion = '3.6'
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

        # Rev3.2 credential action types require SchemaVersion 3.2 or higher
        $rev32CredActionTypes = @('RemoveExpiredApplicationCredential')
        $rev32CredActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -in $rev32CredActionTypes })
        if ($rev32CredActions.Count -gt 0) {
            $svRaw = [string]$manifest.SchemaVersion
            $svMajor = 0; $svMinor = 0
            if ($svRaw -match '^(\d+)\.(\d+)') { [int]$svMajor = $Matches[1]; [int]$svMinor = $Matches[2] }
            if ($svMajor -lt 3 -or ($svMajor -eq 3 -and $svMinor -lt 2)) {
                $errors += "Rev3.2 credential action types require approval manifest SchemaVersion 3.2 or higher (found: $svRaw)"
            }
            # FindingId must be DEC-APP-005
            foreach ($ca in $rev32CredActions) {
                if ($ca.FindingId -ne 'DEC-APP-005') {
                    $errors += "RemoveExpiredApplicationCredential FindingId must be DEC-APP-005 (found: $($ca.FindingId))"
                }
                # TargetObjectIds must be non-empty
                foreach ($tid in @($ca.TargetObjectIds)) {
                    if (-not $tid -or [string]$tid -eq '') {
                        $errors += "RemoveExpiredApplicationCredential TargetObjectIds must not be empty strings"
                        break
                    }
                }
                # ProtectedObject must not be true
                if ($ca.ProtectedObject -eq $true) {
                    $errors += "ProtectedObject action cannot be approved for credential removal"
                }
                # Credential sub-object
                if ($ca.Credential) {
                    if ($ca.Credential.CredentialExpired -ne $true) {
                        $errors += "RemoveExpiredApplicationCredential Credential must be marked expired at approval time"
                    }
                } else {
                    $errors += "RemoveExpiredApplicationCredential: Credential sub-object is required"
                }
            }
            # No duplicate credential removal operations (same ObjectId + same KeyId)
            $credOpKeys = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($ca in $rev32CredActions) {
                foreach ($tid in @($ca.TargetObjectIds)) {
                    $credKey = "RemoveExpiredApplicationCredential|$($ca.ObjectId)|$tid"
                    if ($credOpKeys.Contains($credKey)) {
                        $errors += "Duplicate credential removal operation: $credKey"
                        break
                    }
                    [void]$credOpKeys.Add($credKey)
                }
            }
        }

        # Rev3.3 owner action types require SchemaVersion 3.3 or higher
        $rev33OwnerActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' })
        if ($rev33OwnerActions.Count -gt 0) {
            $svRaw = [string]$manifest.SchemaVersion
            $svMajor = 0; $svMinor = 0
            if ($svRaw -match '^(\d+)\.(\d+)') { [int]$svMajor = $Matches[1]; [int]$svMinor = $Matches[2] }
            if ($svMajor -lt 3 -or ($svMajor -eq 3 -and $svMinor -lt 3)) {
                $errors += "Rev3.3 owner action types require approval manifest SchemaVersion 3.3 or higher (found: $svRaw)"
            }
            foreach ($oa in $rev33OwnerActions) {
                if ($oa.FindingId -notin @('DEC-APP-001','DEC-APP-002','DEC-APP-003','DEC-SPN-001')) {
                    $errors += "AddApplicationOwner FindingId must be DEC-APP-001, DEC-APP-002, DEC-APP-003, or DEC-SPN-001 (found: $($oa.FindingId))"
                }
                if (-not $oa.Ownership -or -not $oa.Ownership.NewOwnerObjectId -or [string]$oa.Ownership.NewOwnerObjectId -eq '') {
                    $errors += "AddApplicationOwner requires NewOwnerObjectId (Ownership.NewOwnerObjectId)"
                }
                if (-not $oa.Ownership -or -not $oa.Ownership.BusinessJustification -or [string]$oa.Ownership.BusinessJustification -eq '') {
                    $errors += "AddApplicationOwner requires BusinessJustification (Ownership.BusinessJustification)"
                }
                if ($oa.ProtectedObject -eq $true) {
                    $errors += "ProtectedObject action cannot be approved for owner addition"
                }
                # Ownership sub-object must have required fields
                if (-not $oa.Ownership) {
                    $errors += "AddApplicationOwner: Ownership sub-object is required"
                }
                $targetIds = @($oa.TargetObjectIds | ForEach-Object { [string]$_ })
                if ($targetIds -notcontains [string]$oa.Ownership.NewOwnerObjectId) {
                    $errors += "AddApplicationOwner NewOwnerObjectId must be present in TargetObjectIds"
                }
            }
            # No duplicate owner-add operations
            $ownerOpKeys = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($oa in $rev33OwnerActions) {
                $ownerKey = "AddApplicationOwner|$($oa.ObjectId)|$(if ($oa.Ownership) { $oa.Ownership.NewOwnerObjectId } else { '' })"
                if ($ownerOpKeys.Contains($ownerKey)) {
                    $errors += "Duplicate owner-add operation: $ownerKey"
                    break
                }
                [void]$ownerOpKeys.Add($ownerKey)
            }
        }

        # Rev3.3 CA exclusion action types require SchemaVersion 3.3 or higher
        $rev33CAActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' })
        if ($rev33CAActions.Count -gt 0) {
            $svRaw = [string]$manifest.SchemaVersion
            $svMajor = 0; $svMinor = 0
            if ($svRaw -match '^(\d+)\.(\d+)') { [int]$svMajor = $Matches[1]; [int]$svMinor = $Matches[2] }
            if ($svMajor -lt 3 -or ($svMajor -eq 3 -and $svMinor -lt 3)) {
                $errors += "Rev3.3 CA exclusion action types require approval manifest SchemaVersion 3.3 or higher (found: $svRaw)"
            }
            foreach ($ca in $rev33CAActions) {
                if ($ca.FindingId -notin @('DEC-CA-002','DEC-CA-003','DEC-CA-004')) {
                    $errors += "RemoveCAExclusionGroupMember FindingId must be DEC-CA-002, DEC-CA-003, or DEC-CA-004 (found: $($ca.FindingId))"
                }
                if (-not $ca.CAExclusion -or -not $ca.CAExclusion.PolicyId -or [string]$ca.CAExclusion.PolicyId -eq '') {
                    $errors += "RemoveCAExclusionGroupMember requires PolicyId (CAExclusion.PolicyId)"
                }
                $caExcl = $ca.CAExclusion
                if (-not $caExcl -or -not $caExcl.ExclusionGroupId -and (-not $ca.TargetObjectIds -or $ca.TargetObjectIds.Count -eq 0)) {
                    $errors += "RemoveCAExclusionGroupMember requires ExclusionGroupId (CAExclusion.ExclusionGroupId)"
                }
                if ($ca.ProtectedObject -eq $true) {
                    $errors += "ProtectedObject action cannot be approved for CA exclusion group removal"
                }
                if ($caExcl -and $caExcl.EmergencyAccessIndicator -eq $true) {
                    $errors += "EmergencyAccessIndicator action cannot be approved for CA exclusion group removal"
                }
                if ($caExcl -and $caExcl.BreakGlassIndicator -eq $true) {
                    $errors += "BreakGlassIndicator action cannot be approved for CA exclusion group removal"
                }

                # ExcludedPrincipalId required
                if (-not $caExcl -or -not $caExcl.ExcludedPrincipalId -or [string]$caExcl.ExcludedPrincipalId -eq '') {
                    $errors += "RemoveCAExclusionGroupMember requires ExcludedPrincipalId (CAExclusion.ExcludedPrincipalId)"
                }

                # ObjectId must equal ExcludedPrincipalId
                if ($caExcl -and $caExcl.ExcludedPrincipalId -and ([string]$ca.ObjectId -ne [string]$caExcl.ExcludedPrincipalId)) {
                    $errors += "RemoveCAExclusionGroupMember ObjectId must equal ExcludedPrincipalId"
                }

                # ExclusionGroupId must be in TargetObjectIds
                $targetIds = @($ca.TargetObjectIds | ForEach-Object { [string]$_ })
                if ($caExcl -and $caExcl.ExclusionGroupId -and ($targetIds -notcontains [string]$caExcl.ExclusionGroupId)) {
                    $errors += "RemoveCAExclusionGroupMember ExclusionGroupId must be present in TargetObjectIds"
                }
            }
            # No duplicate CA exclusion operations
            $caOpKeys = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($ca in $rev33CAActions) {
                $caExcl      = $ca.CAExclusion
                $groupId     = if ($caExcl -and $caExcl.ExclusionGroupId) { [string]$caExcl.ExclusionGroupId } else { [string](@($ca.TargetObjectIds)[0]) }
                $principalId = if ($caExcl -and $caExcl.ExcludedPrincipalId) { [string]$caExcl.ExcludedPrincipalId } else { [string]$ca.ObjectId }
                $caKey = "RemoveCAExclusionGroupMember|$principalId|$groupId"
                if ($caOpKeys.Contains($caKey)) {
                    $errors += "Duplicate CA exclusion group member removal operation: $caKey"
                    break
                }
                [void]$caOpKeys.Add($caKey)
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
                if (-not $action.RoleAssignment -or -not $action.RoleAssignment.RoleAssignmentId -or
                    $action.RoleAssignment.RoleAssignmentId -ne $action.TargetObjectIds[0]) {
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
