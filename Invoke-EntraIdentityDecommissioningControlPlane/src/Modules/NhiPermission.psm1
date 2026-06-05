#Requires -Version 5.1

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

$script:HighRiskAppRoles = @(
    'Directory.ReadWrite.All',
    'User.ReadWrite.All',
    'Group.ReadWrite.All',
    'Mail.ReadWrite',
    'Mail.Send',
    'Files.ReadWrite.All',
    'Sites.FullControl.All',
    'RoleManagement.ReadWrite.Directory',
    'Application.ReadWrite.All',
    'AppRoleAssignment.ReadWrite.All',
    'Directory.AccessAsUser.All',
    'EntitlementManagement.ReadWrite.All'
)

$script:HighRiskDelegatedScopes = @(
    'Directory.ReadWrite.All',
    'User.ReadWrite.All',
    'Mail.ReadWrite',
    'Mail.Send',
    'Files.ReadWrite.All',
    'Sites.FullControl.All',
    'RoleManagement.ReadWrite.Directory',
    'Directory.AccessAsUser.All'
)

function Invoke-NhiPermissionScan {
    [CmdletBinding()]
    param(
        [object[]]$ServicePrincipals,
        [object[]]$AppRoleAssignments,
        [object[]]$OAuthGrants,
        [bool]$AppRoleLookupSucceeded = $true,
        [string]$AppRoleLookupError = '',
        [string[]]$HighRiskAppRolesOverride = @(),
        [string[]]$HighRiskDelegatedScopesOverride = @()
    )

    $appRoles = @()
    $delegatedScopes = @()
    if ($HighRiskAppRolesOverride.Count -gt 0) {
        $appRoles = $HighRiskAppRolesOverride
    } else {
        $appRoles = $script:HighRiskAppRoles
    }
    if ($HighRiskDelegatedScopesOverride.Count -gt 0) {
        $delegatedScopes = $HighRiskDelegatedScopesOverride
    } else {
        $delegatedScopes = $script:HighRiskDelegatedScopes
    }

    $findings = @()
    $permUnitsMap = @{}

    # Phase 1: Count permission units per SP
    foreach ($ara in $AppRoleAssignments) {
        $key = $ara.PrincipalId
        if (-not $permUnitsMap.ContainsKey($key)) {
            $permUnitsMap[$key] = 0
        }
        $permUnitsMap[$key]++
    }

    foreach ($grant in $OAuthGrants) {
        $key = $grant.ClientId
        if (-not $permUnitsMap.ContainsKey($key)) {
            $permUnitsMap[$key] = 0
        }
        $scopeTokens = @()
        if ($grant.Scope -and $grant.Scope.Trim() -ne '') {
            $scopeTokens = @($grant.Scope -split '\s+' | Where-Object { $_ -ne '' })
        }
        foreach ($tok in $scopeTokens) {
            $permUnitsMap[$key]++
        }
    }

    foreach ($sp in $ServicePrincipals) {
        $spId = $sp.Id
        $totalUnits = 0
        if ($permUnitsMap.ContainsKey($spId)) {
            $totalUnits = $permUnitsMap[$spId]
        }

        # PERM-001
        if ($totalUnits -ge 10) {
            $findings += New-DecomFinding -FindingId 'NHI-PERM-001' -Category 'PermissionScopeRisk' -Severity 'High' -RiskScore 15 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $spId -DisplayName $sp.DisplayName -Evidence "Permission unit count is $totalUnits (>= 10)" -EvidenceSource 'graph' -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$spId" -RecommendedAction 'Audit and reduce permission scope; remove unnecessary grants' -RemediationMode 'ManualApprovalRequired' -ConsultantNote 'Privilege sprawl: excessive permissions across app roles and OAuth grants'
        }

        # PERM-002
        if ($totalUnits -ge 5 -and $totalUnits -lt 10) {
            $findings += New-DecomFinding -FindingId 'NHI-PERM-002' -Category 'PermissionScopeRisk' -Severity 'Medium' -RiskScore 8 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $spId -DisplayName $sp.DisplayName -Evidence "Permission unit count is $totalUnits (>= 5 and < 10)" -EvidenceSource 'graph' -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$spId" -RecommendedAction 'Review permissions for necessity; reduce if possible' -RemediationMode 'InformationOnly' -ConsultantNote 'Moderate permission complexity'
        }

        $spAras = @($AppRoleAssignments | Where-Object { $_.PrincipalId -eq $spId })
        $spGrants = @($OAuthGrants | Where-Object { $_.ClientId -eq $spId })

        # PERM-003
        foreach ($ara in $spAras) {
            if ($ara.ResolutionStatus -and $ara.ResolutionStatus.ToLower() -eq 'unresolved') { continue }
            if ($ara.ResolvedRoleValue) {
                $roleMatch = $false
                foreach ($r in $appRoles) {
                    if ($r.ToLower() -eq $ara.ResolvedRoleValue.ToLower()) {
                        $roleMatch = $true
                        break
                    }
                }
                if ($roleMatch) {
                    $findings += New-DecomFinding -FindingId 'NHI-PERM-003' -Category 'PermissionScopeRisk' -Severity 'High' -RiskScore 15 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $spId -DisplayName $sp.DisplayName -Evidence "High-risk application permission assigned: $($ara.ResolvedRoleValue)" -EvidenceSource 'graph' -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$spId/appRoleAssignments" -RecommendedAction "Review necessity of $($ara.ResolvedRoleValue); remove if not required" -RemediationMode 'ManualApprovalRequired' -ConsultantNote "Resource: $($ara.ResourceDisplayName)"
                }
            }
        }

        # PERM-004 and PERM-005 and PERM-006
        foreach ($grant in $spGrants) {
            $scopeTokens = @()
            if ($grant.Scope -and $grant.Scope.Trim() -ne '') {
                $scopeTokens = @($grant.Scope -split '\s+' | Where-Object { $_ -ne '' })
            }
            $isAllPrincipals = $false
            if ($grant.ConsentType -and $grant.ConsentType.ToLower() -eq 'allprincipals') {
                $isAllPrincipals = $true
            }
            foreach ($tok in $scopeTokens) {
                $matchedRole = $null
                foreach ($r in $delegatedScopes) {
                    if ($r.ToLower() -eq $tok.ToLower()) {
                        $matchedRole = $r
                        break
                    }
                }
                if ($matchedRole) {
                    # PERM-004
                    $findings += New-DecomFinding -FindingId 'NHI-PERM-004' -Category 'PermissionScopeRisk' -Severity 'High' -RiskScore 10 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $spId -DisplayName $sp.DisplayName -Evidence "High-risk delegated scope present: $matchedRole" -EvidenceSource 'graph' -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$spId/oauth2PermissionGrants" -RecommendedAction "Review necessity of $matchedRole scope; remove if not required" -RemediationMode 'ManualApprovalRequired' -ConsultantNote "Scope: $($grant.Scope)"
                    # PERM-006
                    if ($isAllPrincipals) {
                        $findings += New-DecomFinding -FindingId 'NHI-PERM-006' -Category 'PermissionScopeRisk' -Severity 'Critical' -RiskScore 20 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $spId -DisplayName $sp.DisplayName -Evidence "AllPrincipals consent combined with high-risk scope: $matchedRole" -EvidenceSource 'graph' -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$spId/oauth2PermissionGrants" -RecommendedAction "Revoke AllPrincipals consent for $matchedRole immediately" -RemediationMode 'ManualApprovalRequired' -ConsultantNote 'Critical combined risk: broad consent + high-risk permission'
                    }
                }
            }
            # PERM-005
            if ($isAllPrincipals) {
                $findings += New-DecomFinding -FindingId 'NHI-PERM-005' -Category 'PermissionScopeRisk' -Severity 'High' -RiskScore 10 -Confidence 'High' -ObjectType 'ServicePrincipal' -ObjectId $spId -DisplayName $sp.DisplayName -Evidence 'Tenant-wide AllPrincipals OAuth consent granted' -EvidenceSource 'graph' -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$spId/oauth2PermissionGrants" -RecommendedAction 'Review consent necessity; revoke if not required' -RemediationMode 'ManualApprovalRequired' -ConsultantNote 'ConsentType: AllPrincipals'
            }
        }
    }

    # PERM-007
    if (-not $AppRoleLookupSucceeded) {
        foreach ($sp in $ServicePrincipals) {
            $findings += New-DecomFinding -FindingId 'NHI-PERM-007' -Category 'PermissionScopeRisk' -Severity 'Medium' -RiskScore 5 -Confidence 'Low' -ObjectType 'ServicePrincipal' -ObjectId $sp.Id -DisplayName $sp.DisplayName -Evidence 'App role display-name lookup failed; permission analysis may be incomplete' -EvidenceSource 'graph' -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals' -RecommendedAction 'Verify Microsoft Graph permissions; ensure Directory.Read.All or AppRoleAssignment.Read.All is granted' -RemediationMode 'InformationOnly' -ConsultantNote "Lookup error: $AppRoleLookupError"
        }
    }

    # PERM-008
    foreach ($ara in $AppRoleAssignments) {
        if ($ara.ResolutionStatus -and $ara.ResolutionStatus.ToLower() -eq 'unresolved') {
            $dispName = $ara.PrincipalDisplayName
            if (-not $dispName) { $dispName = $ara.PrincipalId }
            $findings += New-DecomFinding -FindingId 'NHI-PERM-008' -Category 'PermissionScopeRisk' -Severity 'Low' -RiskScore 5 -Confidence 'Medium' -ObjectType 'ServicePrincipal' -ObjectId $ara.PrincipalId -DisplayName $dispName -Evidence "App role assignment has unresolved status: $($ara.ResolutionStatus)" -EvidenceSource 'graph' -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($ara.PrincipalId)/appRoleAssignments" -RecommendedAction 'Re-resolve or remove stale app role assignment' -RemediationMode 'InformationOnly' -ConsultantNote 'ResolutionStatus: Unresolved'
        }
        $roleEmpty = $false
        if (-not $ara.ResolvedRoleValue) { $roleEmpty = $true }
        if ($ara.ResolvedRoleValue -is [string] -and $ara.ResolvedRoleValue.Trim() -eq '') { $roleEmpty = $true }
        if ($roleEmpty) {
            $dispName = $ara.PrincipalDisplayName
            if (-not $dispName) { $dispName = $ara.PrincipalId }
            $findings += New-DecomFinding -FindingId 'NHI-PERM-008' -Category 'PermissionScopeRisk' -Severity 'Low' -RiskScore 5 -Confidence 'Medium' -ObjectType 'ServicePrincipal' -ObjectId $ara.PrincipalId -DisplayName $dispName -Evidence 'App role assignment has no resolvable role value; grant may be stale' -EvidenceSource 'graph' -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($ara.PrincipalId)/appRoleAssignments" -RecommendedAction 'Re-resolve or remove stale app role assignment' -RemediationMode 'InformationOnly' -ConsultantNote 'ResolvedRoleValue is null/empty'
        }
    }

    return $findings
}

Export-ModuleMember -Function Invoke-NhiPermissionScan