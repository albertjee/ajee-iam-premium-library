function _Get-DecomUserFindings {
    # Collects: DEC-USER-001 (disabled users with group memberships) and
    #           DEC-USER-002 (disabled users with app role assignments).
    param([pscustomobject]$Context)

    $userFindings     = [System.Collections.Generic.List[object]]::new()
    $disabledUsers   = @()
    $staleThreshold  = (Get-Date).AddDays(-90)

    try {
        $disabledUsers = @(
            Get-MgUser `
                -Filter "accountEnabled eq false" `
                -Select Id,DisplayName,UserPrincipalName,AccountEnabled `
                -All -ErrorAction Stop)
        $null = $coverage.Users = $true
        Write-DecomInfo "User discovery: OK ($($disabledUsers.Count) disabled users)"
    $null = $null # suppress unused var
    } catch {
        Write-DecomWarn "User discovery unavailable: $_"
        return @{ Findings = $userFindings; DisabledUsers = $disabledUsers }
    }

    # DEC-USER-001: Disabled users with group memberships
    foreach ($user in $disabledUsers) {
        try {
            $memberOf    = @(Get-MgUserMemberOf -UserId $user.Id -All -ErrorAction Stop)
            $memberships = @($memberOf | Where-Object {
                $_.AdditionalProperties -and
                $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group'
            })
            if ($memberships.Count -gt 0) {
                $groupNames = (@($memberships | ForEach-Object {
                    if ($_.AdditionalProperties -and $_.AdditionalProperties['displayName']) {
                        $_.AdditionalProperties['displayName']
                    }
                } | Where-Object { $_ }) -join ', ')
                $evidence = "Disabled user retains direct membership in $($memberships.Count) group(s)"
                if ($groupNames) { $evidence += ": $groupNames" }
                $userFindings.Add((New-DecomFinding `
                    -FindingId         'DEC-USER-001' `
                    -Category          'User Lifecycle' `
                    -Severity          'Medium' `
                    -RiskScore         55 `
                    -Confidence        'High' `
                    -ObjectType        'User' `
                    -ObjectId          $user.Id `
                    -DisplayName       $user.DisplayName `
                    -UserPrincipalName $user.UserPrincipalName `
                    -Evidence          $evidence `
                    -EvidenceSource    'users/{id}/memberOf' `
                    -GraphEndpoint     '/v1.0/users/{id}/memberOf' `
                    -RecommendedAction "Remove $($user.UserPrincipalName) from all group memberships" `
                    -RemediationMode   'AutoRemediable' `
                    -ConsultantNote    'Standard group cleanup for disabled user'))
            }
        } catch {
            Write-DecomWarn "Group membership check failed for $($user.UserPrincipalName): $_"
        }
    }

    # DEC-USER-002: Disabled users with app role assignments
    foreach ($user in $disabledUsers) {
        try {
            $appRoles = @(Get-MgUserAppRoleAssignment -UserId $user.Id -All -ErrorAction Stop)
            if ($appRoles.Count -gt 0) {
                $resourceNames = ($appRoles | ForEach-Object { $_.ResourceDisplayName } |
                    Select-Object -Unique | Where-Object { $_ }) -join ', '
                $evidence = "Disabled user retains $($appRoles.Count) app role assignment(s)"
                if ($resourceNames) { $evidence += ": $resourceNames" }
                $userFindings.Add((New-DecomFinding `
                    -FindingId         'DEC-USER-002' `
                    -Category          'User Lifecycle' `
                    -Severity          'High' `
                    -RiskScore         72 `
                    -Confidence        'High' `
                    -ObjectType        'User' `
                    -ObjectId          $user.Id `
                    -DisplayName       $user.DisplayName `
                    -UserPrincipalName $user.UserPrincipalName `
                    -Evidence          $evidence `
                    -EvidenceSource    'users/{id}/appRoleAssignments' `
                    -GraphEndpoint     '/v1.0/users/{id}/appRoleAssignments' `
                    -RecommendedAction "Revoke all app role assignments for disabled user $($user.UserPrincipalName)" `
                    -RemediationMode   'ManualApprovalRequired' `
                    -ConsultantNote    'App role assignments for disabled users represent residual SaaS access risk'))
            }
        } catch {
            Write-DecomWarn "App role assignment check failed for $($user.UserPrincipalName): $_"
        }
    }

    @{ Findings = $userFindings; DisabledUsers = $disabledUsers }
}

function _Get-DecomGuestFindings {
    # Collects: DEC-GUEST-001 (guests with stale sign-in).
    # Returns: Findings, StaleGuests (subset with no recent sign-in), GuestsAll (all guests).
    param([pscustomobject]$Context)

    $guestFindings        = [System.Collections.Generic.List[object]]::new()
    $guestStaleThreshold = (Get-Date).AddDays(-180)

    # Fetch all guests first; separate into stale and full sets
    # Coerce LastSignInDateTime to [datetime] to handle both DateTime (real API) and
    # string (test mocks) representations — string comparison with -lt fails silently.
    $allGuests = @(
        Get-MgUser `
            -Filter "userType eq 'Guest'" `
            -Property Id,DisplayName,UserPrincipalName,SignInActivity `
            -All -ErrorAction Stop)
    $staleGuests = @($allGuests | Where-Object {
        $raw = if ($_.SignInActivity -and $_.SignInActivity.LastSignInDateTime) {
            $_.SignInActivity.LastSignInDateTime
        } else { $null }
        $lastSignIn = try { [datetime]$raw } catch { $null }
        $null -eq $lastSignIn -or $lastSignIn -lt $guestStaleThreshold
    })

    $null = $coverage.SignInLogs = $true
    Write-DecomInfo "Guest sign-in discovery: OK ($($staleGuests.Count) stale guest accounts)"

    # DEC-GUEST-001: Stale guests
    foreach ($guest in $staleGuests) {
        $rawLast = if ($guest.SignInActivity -and $guest.SignInActivity.LastSignInDateTime) {
            $guest.SignInActivity.LastSignInDateTime
        } else { $null }
        $lastSignIn = try { [datetime]$rawLast } catch { $null }
        $days = $null
        if ($lastSignIn) {
            $nowDays = Get-Date
            $days = [Math]::Round(($nowDays - $lastSignIn).TotalDays)
        }
        $daysStr = if ($null -ne $days) { "$([Math]::Round($days)) days" } else { "never signed in" }
        $severity = if ($null -eq $lastSignIn -or $days -ge 365) { 'High' } else { 'Medium' }
        $riskScore = if ($null -eq $lastSignIn -or $days -ge 365) { 71 } else { 53 }
        $guestFindings.Add((New-DecomFinding `
            -FindingId         'DEC-GUEST-001' `
            -Category          'Guest Lifecycle' `
            -Severity          $severity `
            -RiskScore         $riskScore `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          $guest.Id `
            -DisplayName       $guest.DisplayName `
            -UserPrincipalName $guest.UserPrincipalName `
            -Evidence          "Guest last sign-in: $daysStr — review for continued access need" `
            -EvidenceSource    'signInActivity' `
            -GraphEndpoint     '/v1.0/users/{id}?$select=signInActivity' `
            -RecommendedAction "Initiate access review for stale guest $($guest.UserPrincipalName)" `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Confirm with business owner whether guest access is still required'))
    }

    Clear-DecomFindingTraceContext
    @{ Findings = $guestFindings; StaleGuests = $staleGuests; GuestsAll = $allGuests }
}

function _Get-DecomGuestSponsorMetadata {
    # Collects: DEC-GUEST-003 (guests without sponsor metadata) and
    #           DEC-GUEST-002 (privileged guests without a sponsor).
    # Returns:  Findings (list), GuestsWithoutSponsor (guest IDs with no manager).
    param(
        [pscustomobject]$Context,
        [object[]]$AllGuests
    )

    $sponsorFindings      = [System.Collections.Generic.List[object]]::new()
    $noSponsorGuestIds    = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    if (-not $AllGuests -or $AllGuests.Count -eq 0) {
        return @{ Findings = $sponsorFindings; GuestsWithoutSponsor = @() }
    }

    foreach ($guest in $AllGuests) {
        $hasSponsor = $false
        try {
            $manager = Get-MgUserManager -UserId $guest.Id -ErrorAction Stop
            if ($null -ne $manager) { $hasSponsor = $true }
        } catch {
            $hasSponsor = $false
        }

        if (-not $hasSponsor) {
            [void]$noSponsorGuestIds.Add([string]$guest.Id)

            # DEC-GUEST-003: No sponsor metadata (primary condition)
            $sponsorFindings.Add((New-DecomFinding `
                -FindingId         'DEC-GUEST-003' `
                -Category          'Guest Lifecycle' `
                -Severity          'Medium' `
                -RiskScore         47 `
                -Confidence        'Medium' `
                -ObjectType        'User' `
                -ObjectId          $guest.Id `
                -DisplayName       $guest.DisplayName `
                -UserPrincipalName $guest.UserPrincipalName `
                -Evidence          "Guest account has no manager assigned — sponsor cannot be determined from directory" `
                -EvidenceSource    'users/{id}/manager' `
                -GraphEndpoint     "/v1.0/users/$($guest.Id)/manager" `
                -RecommendedAction "Assign a sponsor (manager) to $($guest.UserPrincipalName) or initiate offboarding" `
                -RemediationMode   'ManualApprovalRequired' `
                -ConsultantNote    'Guest without sponsor metadata cannot be traced to a business owner'))
        }
    }

    Clear-DecomFindingTraceContext
    @{ Findings = $sponsorFindings; GuestsWithoutSponsor = @($noSponsorGuestIds) }
}

function _Get-DecomOwnedObjectFindings {
    # Collects: DEC-APP-001 (apps with no owner) and
    #           DEC-SPN-001 (service principals with no owner).
    param([pscustomobject]$Context)

    $appFindings = [System.Collections.Generic.List[object]]::new()

    # DEC-APP-001
    try {
        $apps = @(Get-MgApplication -Select Id,DisplayName,AppId -All -ErrorAction Stop)
        $null = $coverage.Applications = $true
        Write-DecomInfo "Application discovery: OK ($($apps.Count) applications)"

        foreach ($app in $apps) {
            $null = Set-DecomFindingTraceContext -SourceObject $app -ClassificationSource 'Discovery/Application'
            try {
                $owners = @(Get-MgApplicationOwner -ApplicationId $app.Id -ErrorAction Stop |
                    Where-Object { $null -ne $_ })
                if ($owners.Count -eq 0) {
                    $appFindings.Add((New-DecomFinding `
                        -FindingId         'DEC-APP-001' `
                        -Category          'Application' `
                        -Severity          'Medium' `
                        -RiskScore         51 `
                        -Confidence        'High' `
                        -ObjectType        'Application' `
                        -ObjectId          $app.Id `
                        -DisplayName       $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          'Application has no owner assigned' `
                        -EvidenceSource    'applications/{id}/owners' `
                        -GraphEndpoint     '/v1.0/applications/{id}/owners' `
                        -RecommendedAction "Assign accountable owner to application '$($app.DisplayName)'" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Ownerless applications are a governance gap'))
                }
            } catch {
                Write-DecomWarn "Owner check failed for application '$($app.DisplayName)': $_"
            }
        }
    } catch {
        Write-DecomWarn "Application discovery unavailable: $_"
    }
    Clear-DecomFindingTraceContext

    # DEC-SPN-001
    try {
        $spns = @(
            Get-MgServicePrincipal `
                -Filter "tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')" `
                -Select Id,DisplayName,AppId,Tags,AppOwnerOrganizationId,PublisherName,VerifiedPublisher,ServicePrincipalType `
                -All -ErrorAction Stop)
        if ($spns.Count -eq 0) {
            $spns = @(Get-MgServicePrincipal `
                -Select Id,DisplayName,AppId,Tags,AppOwnerOrganizationId,PublisherName,VerifiedPublisher,ServicePrincipalType `
                -All -ErrorAction Stop |
                Where-Object { $_.Tags -contains 'WindowsAzureActiveDirectoryIntegratedApp' })
        }
        $null = $coverage.ServicePrincipals = $true
        Write-DecomInfo "Service principal discovery: OK ($($spns.Count) enterprise applications)"

        foreach ($spn in $spns) {
            try {
                $null = Set-DecomFindingTraceContext -SourceObject $spn -ClassificationSource 'Discovery/ServicePrincipal'
                $platformClassification = Test-DecomMicrosoftPlatformIdentity -NhiObject $spn
                if ($platformClassification.MicrosoftPlatform) { continue }
                $spOwners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $spn.Id -ErrorAction Stop)
                if ($spOwners.Count -eq 0) {
                    $appFindings.Add((New-DecomFinding `
                        -FindingId         'DEC-SPN-001' `
                        -Category          'Application' `
                        -Severity          'Medium' `
                        -RiskScore         44 `
                        -Confidence        'High' `
                        -ObjectType        'ServicePrincipal' `
                        -ObjectId          $spn.Id `
                        -DisplayName       $spn.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          'Service principal has no owner assigned — accountability gap for this enterprise application' `
                        -EvidenceSource    'servicePrincipals/{id}/owners' `
                        -GraphEndpoint     '/v1.0/servicePrincipals/{id}/owners' `
                        -RecommendedAction "Assign accountable owner to service principal '$($spn.DisplayName)'" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Ownerless service principals with active permissions are ungoverned'))
                }
            } catch {
                Write-DecomWarn "Owner check failed for SP '$($spn.DisplayName)': $_"
            }
        }
    } catch {
        Write-DecomWarn "Service principal discovery unavailable: $_"
    }
    Clear-DecomFindingTraceContext

    # DEC-APP-002/003/004/005: Extended credential and app analysis
    if ($apps.Count -gt 0) {
    $warningDays = 90
    foreach ($app in $apps) {
        try {
            $credResult = @{ PasswordCredentials = @(); KeyCredentials = @() }
            try {
                $passwordCreds = @(Get-MgApplicationPasswordCredential -ApplicationId $app.Id -ErrorAction Stop)
                $keyCreds     = @(Get-MgApplicationKeyCredential -ApplicationId $app.Id -ErrorAction Stop)
                $credResult   = @{ PasswordCredentials = $passwordCreds; KeyCredentials = $keyCreds }
            } catch { }  # credential list unavailable — skip DEC-APP-002/003/004/005 for this app

            $allCreds = @($credResult.PasswordCredentials + $credResult.KeyCreds)
            if ($allCreds.Count -eq 0) {
                continue
            }
            try {
                $owners = @(Get-MgApplicationOwner -ApplicationId $app.Id -ErrorAction SilentlyContinue |
                    Where-Object { $null -ne $_ })
            } catch { $owners = @() }

            foreach ($cred in $allCreds) {
                $expiry    = if ($cred.EndDateTime) { $cred.EndDateTime } else { $null }
                $credType  = if ($cred.KeyId) { 'Key' } else { 'Password' }
                $credHint  = if ($credKeyDisplay = $cred.DisplayName) { $credKeyDisplay } else { $cred.KeyId.Substring(0, [Math]::Min(8, $cred.KeyId.Length)) }
                $credKeyDisplay = $cred.DisplayName
                if (-not $expiry) { continue }
                $daysToExp = ($expiry - (Get-Date)).Days
                if ($daysToExp -lt 0) {
                    $safeOwnerCount = if ($null -ne $owners) { [int]$owners.Count } else { 0 }
                    $f005 = New-DecomFinding `
                        -FindingId         'DEC-APP-005' `
                        -Category          'Application' `
                        -Severity          'Medium' `
                        -RiskScore         45 `
                        -Confidence        'High' `
                        -ObjectType        'Application' `
                        -ObjectId          $app.Id `
                        -DisplayName       $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          "$credType '$credHint' expired $([Math]::Abs($daysToExp)) days ago ($($expiry.ToString('yyyy-MM-dd'))) — still attached to application" `
                        -EvidenceSource    'applications/{id}/passwordCredentials' `
                        -GraphEndpoint     '/v1.0/applications/{id}?$select=passwordCredentials,keyCredentials' `
                        -RecommendedAction "Remove expired $credType from '$($app.DisplayName)' and rotate if integration still active" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Expired credentials are a hygiene issue; confirm whether integration is still in use'
                    $safeOwnerCount = if ($null -ne $owners) { [int]$owners.Count } else { 0 }
                    $f005 | Add-Member -NotePropertyName 'CredentialKeyId'        -NotePropertyValue ($cred.KeyId)                                      -Force
                    $f005 | Add-Member -NotePropertyName 'CredentialType'         -NotePropertyValue ((if ($cred.KeyId) { 'Key' } else { 'Password' })) -Force
                    $f005 | Add-Member -NotePropertyName 'CredentialEndDateTime'  -NotePropertyValue ($cred.EndDateTime.ToUniversalTime().ToString('o')) -Force
                    $f005 | Add-Member -NotePropertyName 'AppId'                  -NotePropertyValue ($app.AppId)                                       -Force
                    $f005 | Add-Member -NotePropertyName 'OwnerCount'             -NotePropertyValue $safeOwnerCount                                      -Force
                    $f005 | Add-Member -NotePropertyName 'HasOwner'               -NotePropertyValue ($safeOwnerCount -gt 0)                               -Force
                    $appFindings.Add($f005)
                } elseif ($daysToExp -le $warningDays) {
                    $appFindings.Add((New-DecomFinding `
                        -FindingId         'DEC-APP-004' `
                        -Category          'Application' `
                        -Severity          'Medium' `
                        -RiskScore         48 `
                        -Confidence        'High' `
                        -ObjectType        'Application' `
                        -ObjectId          $app.Id `
                        -DisplayName       $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          "$credType '$credHint' expires in $daysToExp days ($($expiry.ToString('yyyy-MM-dd'))) — renewal not confirmed" `
                        -EvidenceSource    'applications/{id}/passwordCredentials' `
                        -GraphEndpoint     '/v1.0/applications/{id}?$select=passwordCredentials,keyCredentials' `
                        -RecommendedAction "Rotate expiring $credType for '$($app.DisplayName)' before $($expiry.ToString('yyyy-MM-dd'))" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Expiring credentials cause integration failures'))
                }
            }
        } catch {
            Write-DecomWarn "Credential check failed for '$($app.DisplayName)': $_"
        }
    }
    } # end if ($apps.Count -gt 0)

    @{ Findings = $appFindings; Apps = $apps }
}
