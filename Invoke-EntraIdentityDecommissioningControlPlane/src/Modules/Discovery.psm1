$script:ProtectedPatterns = @(
    'breakglass','break-glass','emergency','sync',
    'aadconnect','cloudsync','svc-','service-'
)

function New-DecomCoverage {
    [ordered]@{
        Users                 = $false
        Groups                = $false
        Applications          = $false
        ServicePrincipals     = $false
        DirectoryRoles        = $false
        SignInLogs            = $false
        AuditLogs             = $false
        ConditionalAccess     = $false
        EntitlementManagement = $false
    }
}

function Get-DecomSyntheticFindings {
    @(
        (New-DecomFinding `
            -FindingId 'DEC-USER-003' `
            -Category 'User Lifecycle' `
            -Severity 'Critical' `
            -RiskScore 92 `
            -Confidence 'High' `
            -ObjectType 'User' `
            -ObjectId 'a1b2c3d4-0001-0001-0001-000000000001' `
            -DisplayName 'Alex Mercer' `
            -UserPrincipalName 'alex.mercer@contoso.com' `
            -Evidence 'Disabled user retains Global Administrator role assignment' `
            -EvidenceSource 'directoryRoles' `
            -GraphEndpoint '/v1.0/directoryRoles/{id}/members' `
            -RecommendedAction 'Remove Global Administrator role assignment from disabled user alex.mercer@contoso.com' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Confirm no pending IT tasks before removing role'),

        (New-DecomFinding `
            -FindingId 'DEC-APP-002' `
            -Category 'Application' `
            -Severity 'Critical' `
            -RiskScore 88 `
            -Confidence 'High' `
            -ObjectType 'Application' `
            -ObjectId 'a1b2c3d4-0002-0002-0002-000000000002' `
            -DisplayName 'Contoso Analytics API' `
            -UserPrincipalName '' `
            -Evidence 'Application owned exclusively by disabled user alex.mercer@contoso.com — no active owner remains' `
            -EvidenceSource 'applications/{id}/owners' `
            -GraphEndpoint '/v1.0/applications/{id}/owners' `
            -RecommendedAction 'Assign active owner to Contoso Analytics API; remove disabled user alex.mercer@contoso.com as owner' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'App is effectively unmanaged — disabled sole owner creates governance gap'),

        (New-DecomFinding `
            -FindingId 'DEC-GUEST-002' `
            -Category 'Guest Lifecycle' `
            -Severity 'High' `
            -RiskScore 78 `
            -Confidence 'High' `
            -ObjectType 'User' `
            -ObjectId 'a1b2c3d4-0003-0003-0003-000000000003' `
            -DisplayName 'ext_partner@fabrikam.com' `
            -UserPrincipalName 'ext_partner_fabrikam.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence 'Guest account holds User Administrator role — no sponsor metadata' `
            -EvidenceSource 'directoryRoles' `
            -GraphEndpoint '/v1.0/directoryRoles/{id}/members' `
            -RecommendedAction 'Review guest privileged access; assign sponsor; consider role removal' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Guest with privileged role requires explicit business justification'),

        (New-DecomFinding `
            -FindingId 'DEC-USER-001' `
            -Category 'User Lifecycle' `
            -Severity 'High' `
            -RiskScore 65 `
            -Confidence 'High' `
            -ObjectType 'User' `
            -ObjectId 'a1b2c3d4-0004-0004-0004-000000000004' `
            -DisplayName 'Jordan Riley' `
            -UserPrincipalName 'jordan.riley@contoso.com' `
            -Evidence 'Disabled user retains membership in 4 groups including IT-Admins' `
            -EvidenceSource 'users/{id}/memberOf' `
            -GraphEndpoint '/v1.0/users/{id}/memberOf' `
            -RecommendedAction 'Remove jordan.riley@contoso.com from all group memberships' `
            -RemediationMode 'AutoRemediable' `
            -ConsultantNote 'Standard group cleanup for disabled user'),

        (New-DecomFinding `
            -FindingId 'DEC-APP-001' `
            -Category 'Application' `
            -Severity 'Medium' `
            -RiskScore 51 `
            -Confidence 'High' `
            -ObjectType 'Application' `
            -ObjectId 'a1b2c3d4-0005-0005-0005-000000000005' `
            -DisplayName 'Reporting Daemon SP' `
            -UserPrincipalName '' `
            -Evidence 'Application has no owner assigned' `
            -EvidenceSource 'applications/{id}/owners' `
            -GraphEndpoint '/v1.0/applications/{id}/owners' `
            -RecommendedAction 'Assign accountable owner to Reporting Daemon SP' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Ownerless service principals are a governance gap'),

        (New-DecomFinding `
            -FindingId 'DEC-CA-001' `
            -Category 'Conditional Access' `
            -Severity 'Medium' `
            -RiskScore 48 `
            -Confidence 'Medium' `
            -ObjectType 'Group' `
            -ObjectId 'a1b2c3d4-0006-0006-0006-000000000006' `
            -DisplayName 'MFA-Exclusion-Legacy' `
            -UserPrincipalName '' `
            -Evidence 'CA exclusion group contains 12 accounts — unreviewed for 180+ days' `
            -EvidenceSource 'conditionalAccessPolicies' `
            -GraphEndpoint '/v1.0/identity/conditionalAccess/policies' `
            -RecommendedAction 'Review MFA-Exclusion-Legacy membership; initiate access review for CA exclusion groups' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'CA exclusion groups require periodic attestation'),

        (New-DecomFinding `
            -FindingId 'DEC-GUEST-001' `
            -Category 'Guest Lifecycle' `
            -Severity 'Low' `
            -RiskScore 32 `
            -Confidence 'Medium' `
            -ObjectType 'User' `
            -ObjectId 'a1b2c3d4-0007-0007-0007-000000000007' `
            -DisplayName 'ext_vendor@tailspin.com' `
            -UserPrincipalName 'ext_vendor_tailspin.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence 'Guest last sign-in 210 days ago — no access review coverage' `
            -EvidenceSource 'signInLogs' `
            -GraphEndpoint '/v1.0/auditLogs/signIns' `
            -RecommendedAction 'Initiate access review for stale guest ext_vendor@tailspin.com' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Stale guest — review with business owner for continued need'),

        (New-DecomFinding `
            -FindingId 'DEC-IGA-001' `
            -Category 'Governance' `
            -Severity 'Informational' `
            -RiskScore 18 `
            -Confidence 'Low' `
            -ObjectType 'TenantScope' `
            -ObjectId 'contoso.onmicrosoft.com' `
            -DisplayName 'Entitlement Management' `
            -UserPrincipalName '' `
            -Evidence 'AuditLog.Read.All scope unavailable — IGA coverage assessment incomplete' `
            -EvidenceSource 'graphPermissions' `
            -GraphEndpoint '/v1.0/identityGovernance/entitlementManagement' `
            -RecommendedAction 'Request AuditLog.Read.All and EntitlementManagement.Read.All for full IGA coverage' `
            -RemediationMode 'InformationOnly' `
            -ConsultantNote 'Coverage gap — not a finding against tenant configuration'),

        # DEC-APP-003 — Single owner (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-APP-003' `
            -Category          'Application' `
            -Severity          'Medium' `
            -RiskScore         45 `
            -Confidence        'High' `
            -ObjectType        'Application' `
            -ObjectId          'a1b2c3d4-0010-0010-0010-000000000010' `
            -DisplayName       'Finance Reporting App' `
            -UserPrincipalName '' `
            -Evidence          'Application has only 1 owner — single point of failure for ownership continuity' `
            -EvidenceSource    'applications/{id}/owners' `
            -GraphEndpoint     '/v1.0/applications/{id}/owners' `
            -RecommendedAction 'Add a second owner to Finance Reporting App to ensure ownership continuity' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Single-owner apps are a governance risk if that owner leaves or is disabled'),

        # DEC-APP-004 — Expiring credential (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-APP-004' `
            -Category          'Application' `
            -Severity          'Medium' `
            -RiskScore         48 `
            -Confidence        'High' `
            -ObjectType        'Application' `
            -ObjectId          'a1b2c3d4-0011-0011-0011-000000000011' `
            -DisplayName       'DevOps Pipeline SP' `
            -UserPrincipalName '' `
            -Evidence          'Client secret expires in 14 days (2026-06-13) — renewal not confirmed' `
            -EvidenceSource    'applications/{id}/passwordCredentials' `
            -GraphEndpoint     '/v1.0/applications/{id}?$select=passwordCredentials,keyCredentials' `
            -RecommendedAction 'Rotate expiring client secret for DevOps Pipeline SP before 2026-06-13' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Expiring secrets cause integration failures and may trigger emergency access patterns'),

        # DEC-APP-005 — Expired credential (High)
        (New-DecomFinding `
            -FindingId         'DEC-APP-005' `
            -Category          'Application' `
            -Severity          'High' `
            -RiskScore         68 `
            -Confidence        'High' `
            -ObjectType        'Application' `
            -ObjectId          'a1b2c3d4-0012-0012-0012-000000000012' `
            -DisplayName       'Legacy SSO Connector' `
            -UserPrincipalName '' `
            -Evidence          'Client secret expired 47 days ago (2026-04-13) — credential still attached to application' `
            -EvidenceSource    'applications/{id}/passwordCredentials' `
            -GraphEndpoint     '/v1.0/applications/{id}?$select=passwordCredentials,keyCredentials' `
            -RecommendedAction 'Remove expired credential from Legacy SSO Connector and rotate if integration still active' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Expired credentials are a hygiene issue; confirm whether integration is still in use'),

        # DEC-SPN-001 — Ownerless service principal (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-SPN-001' `
            -Category          'Application' `
            -Severity          'Medium' `
            -RiskScore         44 `
            -Confidence        'High' `
            -ObjectType        'ServicePrincipal' `
            -ObjectId          'a1b2c3d4-0013-0013-0013-000000000013' `
            -DisplayName       'Azure Backup Agent SP' `
            -UserPrincipalName '' `
            -Evidence          'Service principal has no owner assigned — accountability gap for this enterprise application' `
            -EvidenceSource    'servicePrincipals/{id}/owners' `
            -GraphEndpoint     '/v1.0/servicePrincipals/{id}/owners' `
            -RecommendedAction 'Assign accountable owner to Azure Backup Agent SP' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Ownerless service principals with active permissions are ungoverned'),

        # DEC-USER-002 — Disabled user retains app role assignments (High)
        (New-DecomFinding `
            -FindingId         'DEC-USER-002' `
            -Category          'User Lifecycle' `
            -Severity          'High' `
            -RiskScore         72 `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0014-0014-0014-000000000014' `
            -DisplayName       'Morgan Chen' `
            -UserPrincipalName 'morgan.chen@contoso.com' `
            -Evidence          'Disabled user retains 3 app role assignments: Salesforce Admin, SAP HR Read, Workday Integrations' `
            -EvidenceSource    'users/{id}/appRoleAssignments' `
            -GraphEndpoint     '/v1.0/users/{id}/appRoleAssignments' `
            -RecommendedAction 'Revoke all app role assignments for disabled user morgan.chen@contoso.com' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'App role assignments for disabled users represent residual SaaS access risk')
    )
}

function Invoke-DecomAssessmentDiscovery {
    param(
        [pscustomobject]$Context,
        [switch]$DemoMode
    )

    $coverage = New-DecomCoverage

    if ($DemoMode) {
        $coverage.Users             = $true
        $coverage.Groups            = $true
        $coverage.Applications      = $true
        $coverage.ServicePrincipals = $true
        $coverage.DirectoryRoles    = $true
        $coverage.ConditionalAccess = $true
        if ($Context) { $Context | Add-Member -NotePropertyName Coverage -NotePropertyValue $coverage -Force }
        [object[]]$synth = @(Get-DecomSyntheticFindings)
        Write-Output -NoEnumerate $synth
        return
    }

    $findings      = [System.Collections.Generic.List[object]]::new()
    $staleThreshold = (Get-Date).AddDays(-90)
    $disabledUsers = @()
    $apps          = @()

    # --- DEC-USER-001: Disabled users with group memberships ---
    try {
        $disabledUsers = @(Get-MgUser `
            -Filter "accountEnabled eq false" `
            -Select Id,DisplayName,UserPrincipalName,AccountEnabled `
            -All -ErrorAction Stop)
        $coverage.Users = $true
        Write-DecomInfo "User discovery: OK ($($disabledUsers.Count) disabled users)"

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
                    $findings.Add((New-DecomFinding `
                        -FindingId    'DEC-USER-001' `
                        -Category     'User Lifecycle' `
                        -Severity     'Medium' `
                        -RiskScore    55 `
                        -Confidence   'High' `
                        -ObjectType   'User' `
                        -ObjectId     $user.Id `
                        -DisplayName  $user.DisplayName `
                        -UserPrincipalName $user.UserPrincipalName `
                        -Evidence     $evidence `
                        -EvidenceSource 'users/{id}/memberOf' `
                        -GraphEndpoint  '/v1.0/users/{id}/memberOf' `
                        -RecommendedAction "Remove $($user.UserPrincipalName) from all group memberships" `
                        -RemediationMode 'AutoRemediable' `
                        -ConsultantNote  'Standard group cleanup for disabled user'))
                }
            } catch {
                Write-DecomWarn "Group membership check failed for $($user.UserPrincipalName): $_"
            }
        }
    } catch {
        Write-DecomWarn "User discovery unavailable: $_"
    }

    # --- DEC-APP-001: Applications with no owner ---
    try {
        $apps = @(Get-MgApplication -Select Id,DisplayName,AppId -All -ErrorAction Stop)
        $coverage.Applications = $true
        Write-DecomInfo "Application discovery: OK ($($apps.Count) applications)"

        foreach ($app in $apps) {
            try {
                $owners = @(Get-MgApplicationOwner -ApplicationId $app.Id -ErrorAction Stop)
                if ($owners.Count -eq 0) {
                    $findings.Add((New-DecomFinding `
                        -FindingId    'DEC-APP-001' `
                        -Category     'Application' `
                        -Severity     'Medium' `
                        -RiskScore    51 `
                        -Confidence   'High' `
                        -ObjectType   'Application' `
                        -ObjectId     $app.Id `
                        -DisplayName  $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence     'Application has no owner assigned' `
                        -EvidenceSource 'applications/{id}/owners' `
                        -GraphEndpoint  '/v1.0/applications/{id}/owners' `
                        -RecommendedAction "Assign accountable owner to application '$($app.DisplayName)'" `
                        -RemediationMode 'ManualApprovalRequired' `
                        -ConsultantNote  'Ownerless applications are a governance gap'))
                }
            } catch {
                Write-DecomWarn "Owner check failed for application '$($app.DisplayName)': $_"
            }
        }
    } catch {
        Write-DecomWarn "Application discovery unavailable: $_"
    }

    # --- DEC-GUEST-001: Guests with stale sign-in (SignInActivity property) ---
    try {
        $guests = @(Get-MgUser `
            -Filter "userType eq 'Guest'" `
            -Property Id,DisplayName,UserPrincipalName,SignInActivity `
            -All -ErrorAction Stop)
        $coverage.SignInLogs = $true
        Write-DecomInfo "Guest sign-in discovery: OK ($($guests.Count) guest accounts)"

        $guestStaleThreshold = (Get-Date).AddDays(-180)
        foreach ($guest in $guests) {
            $lastSignIn    = $null
            $hasSignInData = $false

            try {
                if ($guest.SignInActivity -and $guest.SignInActivity.LastSignInDateTime) {
                    $hasSignInData = $true
                    $lastSignIn    = [datetime]$guest.SignInActivity.LastSignInDateTime
                }
            } catch { $hasSignInData = $false }

            if (-not $hasSignInData) { continue }

            if ($null -eq $lastSignIn) {
                $daysStr = 'never signed in'
            } elseif ($lastSignIn -lt $guestStaleThreshold) {
                $daysStr = "$([int]((Get-Date) - $lastSignIn).TotalDays) days ago"
            } else {
                continue
            }

            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-GUEST-001' `
                -Category          'Guest Lifecycle' `
                -Severity          'Low' `
                -RiskScore         32 `
                -Confidence        'Medium' `
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
    } catch {
        Write-DecomWarn "Guest sign-in discovery unavailable (SignInActivity permission required): $_"
    }

    # --- Extended application analysis (DEC-APP-002, 003, 004, 005) ---
    if ($apps.Count -gt 0) {
    $disabledUserIds = if ($disabledUsers) {
        [System.Collections.Generic.HashSet[string]]@($disabledUsers | ForEach-Object { $_.Id })
    } else {
        [System.Collections.Generic.HashSet[string]]::new()
    }

    $warningDays = 90
    $today       = Get-Date

    foreach ($app in $apps) {
        try {
            $owners = @(Get-MgApplicationOwner -ApplicationId $app.Id -ErrorAction Stop)

            # DEC-APP-002: All owners are disabled users
            if ($owners.Count -gt 0) {
                $activeOwners = @($owners | Where-Object {
                    -not $disabledUserIds.Contains($_.Id)
                })
                if ($activeOwners.Count -eq 0) {
                    $disabledOwnerNames = ($owners | ForEach-Object {
                        $_.AdditionalProperties['userPrincipalName']
                    } | Where-Object { $_ }) -join ', '
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-APP-002' `
                        -Category          'Application' `
                        -Severity          'Critical' `
                        -RiskScore         88 `
                        -Confidence        'High' `
                        -ObjectType        'Application' `
                        -ObjectId          $app.Id `
                        -DisplayName       $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          "Application owned exclusively by disabled user(s): $disabledOwnerNames — no active owner remains" `
                        -EvidenceSource    'applications/{id}/owners' `
                        -GraphEndpoint     '/v1.0/applications/{id}/owners' `
                        -RecommendedAction "Assign active owner to '$($app.DisplayName)'; remove disabled user(s) as owner" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'App is effectively unmanaged — sole owner is disabled'))
                }
            }

            # DEC-APP-003: Exactly one owner (fragile ownership)
            if ($owners.Count -eq 1) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-APP-003' `
                    -Category          'Application' `
                    -Severity          'Medium' `
                    -RiskScore         45 `
                    -Confidence        'High' `
                    -ObjectType        'Application' `
                    -ObjectId          $app.Id `
                    -DisplayName       $app.DisplayName `
                    -UserPrincipalName '' `
                    -Evidence          'Application has only 1 owner — single point of failure for ownership continuity' `
                    -EvidenceSource    'applications/{id}/owners' `
                    -GraphEndpoint     '/v1.0/applications/{id}/owners' `
                    -RecommendedAction "Add a second owner to '$($app.DisplayName)' to ensure ownership continuity" `
                    -RemediationMode   'ManualApprovalRequired' `
                    -ConsultantNote    'Single-owner apps are a governance risk'))
            }

        } catch {
            Write-DecomWarn "Owner check failed for '$($app.DisplayName)': $_"
        }

        # DEC-APP-004 and DEC-APP-005: Credential expiry analysis
        try {
            $appDetail = Get-MgApplication -ApplicationId $app.Id `
                -Select Id,DisplayName,PasswordCredentials,KeyCredentials -ErrorAction Stop

            $allCreds = @()
            if ($appDetail.PasswordCredentials) { $allCreds += $appDetail.PasswordCredentials }
            if ($appDetail.KeyCredentials)      { $allCreds += $appDetail.KeyCredentials }

            foreach ($cred in $allCreds) {
                if (-not $cred.EndDateTime) { continue }
                $expiry    = [datetime]$cred.EndDateTime
                $daysToExp = [int]($expiry - $today).TotalDays
                $credType  = if ($cred.PSObject.Properties.Name -contains 'SecretText') { 'Client secret' } else { 'Certificate' }
                $credHint  = if ($cred.DisplayName) { $cred.DisplayName } else { $cred.KeyId }

                if ($daysToExp -lt 0) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-APP-005' `
                        -Category          'Application' `
                        -Severity          'High' `
                        -RiskScore         68 `
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
                        -ConsultantNote    'Expired credentials are a hygiene issue; confirm whether integration is still in use'))

                } elseif ($daysToExp -le $warningDays) {
                    $findings.Add((New-DecomFinding `
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

    # --- DEC-SPN-001: Service principals with no owner ---
    try {
        $spns = @(Get-MgServicePrincipal `
            -Filter "tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')" `
            -Select Id,DisplayName,AppId,Tags `
            -All -ErrorAction Stop)

        if ($spns.Count -eq 0) {
            $spns = @(Get-MgServicePrincipal -Select Id,DisplayName,AppId,Tags -All -ErrorAction Stop |
                Where-Object { $_.Tags -contains 'WindowsAzureActiveDirectoryIntegratedApp' })
        }

        $coverage.ServicePrincipals = $true
        Write-DecomInfo "Service principal discovery: OK ($($spns.Count) enterprise applications)"

        foreach ($spn in $spns) {
            try {
                $spOwners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $spn.Id -ErrorAction Stop)
                if ($spOwners.Count -eq 0) {
                    $findings.Add((New-DecomFinding `
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

    # --- DEC-USER-002: Disabled users with app role assignments ---
    if ($disabledUsers.Count -gt 0) {
    foreach ($user in $disabledUsers) {
        try {
            $appRoles = @(Get-MgUserAppRoleAssignment -UserId $user.Id -All -ErrorAction Stop)
            if ($appRoles.Count -gt 0) {
                $resourceNames = ($appRoles | ForEach-Object {
                    $_.ResourceDisplayName
                } | Select-Object -Unique | Where-Object { $_ }) -join ', '

                $evidence = "Disabled user retains $($appRoles.Count) app role assignment(s)"
                if ($resourceNames) { $evidence += ": $resourceNames" }

                $findings.Add((New-DecomFinding `
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
    } # end if ($disabledUsers.Count -gt 0)

    # --- Coverage probes for remaining areas (no detection logic yet) ---
    try {
        $null = Get-MgGroup -Top 1 -ErrorAction Stop
        $coverage.Groups = $true
        Write-DecomInfo "Group discovery: OK"
    } catch {
        Write-DecomWarn "Group discovery unavailable: $_"
    }

    try {
        $null = Get-MgServicePrincipal -Top 1 -ErrorAction Stop
        $coverage.ServicePrincipals = $true
        Write-DecomInfo "Service principal discovery: OK"
    } catch {
        Write-DecomWarn "Service principal discovery unavailable: $_"
    }

    try {
        $null = Get-MgDirectoryRole -ErrorAction Stop
        $coverage.DirectoryRoles = $true
        Write-DecomInfo "Directory role discovery: OK"
    } catch {
        Write-DecomWarn "Directory role discovery unavailable: $_"
    }

    try {
        $null = Get-MgAuditLogSignIn -Top 1 -ErrorAction Stop
        $coverage.AuditLogs = $true
        Write-DecomInfo "Audit log discovery: OK"
    } catch {
        Write-DecomWarn "Audit log discovery unavailable (AuditLog.Read.All required): $_"
    }

    try {
        $null = Get-MgIdentityConditionalAccessPolicy -ErrorAction Stop
        $coverage.ConditionalAccess = $true
        Write-DecomInfo "Conditional access discovery: OK"
    } catch {
        Write-DecomWarn "Conditional access discovery unavailable: $_"
    }

    try {
        $null = Get-MgEntitlementManagementAccessPackage -Top 1 -ErrorAction Stop
        $coverage.EntitlementManagement = $true
        Write-DecomInfo "Entitlement management discovery: OK"
    } catch {
        Write-DecomWarn "Entitlement management discovery unavailable (EntitlementManagement.Read.All required): $_"
    }

    if ($Context) { $Context | Add-Member -NotePropertyName Coverage -NotePropertyValue $coverage -Force }
    [object[]]$result = @($findings)
    Write-Output -NoEnumerate $result
}
