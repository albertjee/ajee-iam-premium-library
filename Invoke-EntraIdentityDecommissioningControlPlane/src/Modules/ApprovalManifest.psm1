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
        RoleAssignmentId   = [string]$Action.RoleAssignmentId
        RoleDefinitionId   = [string]$Action.RoleDefinitionId
        RoleDisplayName    = [string]$Action.RoleDisplayName
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

            default {
                $result.ErrorDetail = "FindingId '$($Finding.FindingId)' is not in Rev2.0 execution scope"
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
        SchemaVersion = '2.0'
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

        # Every action FindingId is in Rev2.0 execution scope
        foreach ($action in $manifest.ApprovedActions) {
            if (-not $script:ExecutionMap.ContainsKey($action.FindingId)) {
                $errors += "Every action FindingId is in Rev2.0 execution scope"
                break
            }
        }

        # Every action ActionType matches FindingId
        foreach ($action in $manifest.ApprovedActions) {
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

    return [PSCustomObject]@{
        Valid = ($errors.Count -eq 0)
        Errors = $errors
        Manifest = $manifest
    }
}