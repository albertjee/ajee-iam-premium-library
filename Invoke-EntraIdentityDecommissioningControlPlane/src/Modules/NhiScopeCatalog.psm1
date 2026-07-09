# NhiScopeCatalog.psm1 - Rev4.2
# Canonical catalog of high-risk Graph permission/scope name lists.
# Addresses target I of docs/refactoring-plan.md (scope array drift).
# Data only - no Graph calls, no mutation, no scope requests. Scope names below are
# DETECTION data (permissions to flag as high-risk), never scopes this tool requests.
#
# The Discovery and Permission lists are intentionally kept as separate named lists,
# preserved verbatim from their original modules. They had already drifted apart
# (e.g. Discovery includes PrivilegedAccess.ReadWrite.AzureAD, AuditLog.Read.All,
# Policy.ReadWrite.All; Permission does not). Unifying them is a deliberate future
# decision, not a side effect of this consolidation.

# Verbatim from NhiDiscovery.psm1 ($script:HighRiskAppPermissions, 14 entries).
$script:DiscoveryHighRiskAppPermissions = @(
    'Directory.ReadWrite.All', 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All',
    'RoleManagement.ReadWrite.Directory', 'PrivilegedAccess.ReadWrite.AzureAD',
    'Group.ReadWrite.All', 'User.ReadWrite.All', 'Mail.ReadWrite', 'Mail.Send',
    'Files.ReadWrite.All', 'Sites.FullControl.All', 'AuditLog.Read.All',
    'Policy.ReadWrite.All', 'EntitlementManagement.ReadWrite.All'
)

# Verbatim from NhiDiscovery.psm1 ($script:HighRiskDelegatedScopes, 12 entries).
$script:DiscoveryHighRiskDelegatedScopes = @(
    'Directory.AccessAsUser.All', 'Directory.ReadWrite.All', 'Application.ReadWrite.All',
    'AppRoleAssignment.ReadWrite.All', 'User.Read.All', 'User.ReadWrite.All', 'Group.ReadWrite.All',
    'Mail.ReadWrite', 'Mail.Send', 'Files.ReadWrite.All', 'Sites.FullControl.All', 'offline_access'
)

# Verbatim from NhiPermission.psm1 ($script:HighRiskAppRoles, 12 entries).
$script:PermissionHighRiskAppRoles = @(
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

# Verbatim from NhiPermission.psm1 ($script:HighRiskDelegatedScopes, 8 entries).
$script:PermissionHighRiskDelegatedScopes = @(
    'Directory.ReadWrite.All',
    'User.ReadWrite.All',
    'Mail.ReadWrite',
    'Mail.Send',
    'Files.ReadWrite.All',
    'Sites.FullControl.All',
    'RoleManagement.ReadWrite.Directory',
    'Directory.AccessAsUser.All'
)

function Get-NhiScopeCatalog {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        DiscoveryHighRiskAppPermissions    = $script:DiscoveryHighRiskAppPermissions
        DiscoveryHighRiskDelegatedScopes   = $script:DiscoveryHighRiskDelegatedScopes
        PermissionHighRiskAppRoles         = $script:PermissionHighRiskAppRoles
        PermissionHighRiskDelegatedScopes  = $script:PermissionHighRiskDelegatedScopes
    }
}

Export-ModuleMember -Function Get-NhiScopeCatalog
