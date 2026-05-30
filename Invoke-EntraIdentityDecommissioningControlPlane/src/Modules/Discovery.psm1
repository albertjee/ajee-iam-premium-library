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
            -Severity 'High' `
            -RiskScore 79 `
            -Confidence 'High' `
            -ObjectType 'Application' `
            -ObjectId 'a1b2c3d4-0002-0002-0002-000000000002' `
            -DisplayName 'Contoso Analytics API' `
            -UserPrincipalName '' `
            -Evidence 'Application owned exclusively by disabled user alex.mercer@contoso.com' `
            -EvidenceSource 'applications' `
            -GraphEndpoint '/v1.0/applications/{id}/owners' `
            -RecommendedAction 'Assign active owner to Contoso Analytics API; remove disabled user as owner' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Identify application business owner before removing sole owner'),

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
            -Severity 'Medium' `
            -RiskScore 55 `
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
            -ConsultantNote 'Coverage gap — not a finding against tenant configuration')
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
