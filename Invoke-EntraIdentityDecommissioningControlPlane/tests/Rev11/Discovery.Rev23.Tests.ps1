#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

# Helper: standard Graph mock set (no AR cmdlets) for tests that only need base mocks
# Individual tests add overrides as needed via InModuleScope function re-definition

Describe 'Rev2.3 Access Review Governance — M2 Coverage' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    # Test 1: AR cmdlet unavailable emits DEC-GOV-002
    It 'Access review cmdlet unavailable emits DEC-GOV-002 and does not throw' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            # Access review cmdlets intentionally NOT defined

            $ctx = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            { $r23 = Invoke-DecomAssessmentDiscovery -Context $ctx } | Should -Not -Throw
            $r23 = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($r23 | Where-Object { $_.FindingId -eq 'DEC-GOV-002' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 2: AR definitions available sets AccessReviews coverage true
    It 'Access review definitions available sets AccessReviews coverage true' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-001'; DisplayName='Test Review'; Scope=$null })
            }

            $ctx = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            Invoke-DecomAssessmentDiscovery -Context $ctx | Out-Null
            $ctx.Coverage.AccessReviews | Should -Be $true
        }
    }

    # Test 3: Definitions available but no decisions emits DEC-REV-001
    It 'Access review definitions available but no decisions emits DEC-REV-001' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-001'; DisplayName='Test Review'; Scope=$null })
            }
            # No instance or decision cmdlets defined -> no decisions collected

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-REV-001' }) | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Rev2.3 Access Review Governance — M3 Guest Review Correlation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    # Test 4: Guest without review evidence emits DEC-GREV-001
    It 'Guest without review evidence emits DEC-GREV-001' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') { return @() }
                # For guest filter — return a guest with stale sign-in
                return @([PSCustomObject]@{
                    Id='grev-001-guest'
                    DisplayName='ext_stale_guest@fabrikam.com'
                    UserPrincipalName='ext_stale_guest_fabrikam.com#EXT#@contoso.onmicrosoft.com'
                    Department=$null; JobTitle=$null
                    SignInActivity=[PSCustomObject]@{
                        LastSignInDateTime=(Get-Date).AddDays(-200).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    }
                })
            }
            function Get-MgUserManager              { param($UserId,$ErrorAction) $null }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgDirectoryRoleMember      { param($DirectoryRoleId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-g001'; DisplayName='Guest Review'; Scope=$null })
            }
            # No decisions cmdlet — no review decisions for this guest

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-GREV-001' -and $_.ObjectId -eq 'grev-001-guest' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 5: Guest without sponsor and without review evidence emits DEC-GREV-002
    It 'Guest without sponsor and without review evidence emits DEC-GREV-002' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') { return @() }
                return @([PSCustomObject]@{
                    Id='grev-002-guest'
                    DisplayName='ext_nosponsored@tailspin.com'
                    UserPrincipalName='ext_nosponsored_tailspin.com#EXT#@contoso.onmicrosoft.com'
                    Department=$null; JobTitle=$null
                    SignInActivity=$null
                })
            }
            function Get-MgUserManager              { param($UserId,$ErrorAction) throw 'No manager' }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgDirectoryRoleMember      { param($DirectoryRoleId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-g002'; DisplayName='Guest Review'; Scope=$null })
            }
            # No decisions — guest DEC-GUEST-003 fires, then GREV-002 fires

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-GREV-002' -and $_.ObjectId -eq 'grev-002-guest' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 6: Privileged guest (via PIM-002) without review evidence emits DEC-GREV-003
    It 'Privileged guest (PIM eligible) without review evidence emits DEC-GREV-003' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') { return @() }
                return @([PSCustomObject]@{
                    Id='grev-003-guest'
                    DisplayName='ext_privileged_norev@fabrikam.com'
                    UserPrincipalName='ext_privileged_norev_fabrikam.com#EXT#@contoso.onmicrosoft.com'
                    Department=$null; JobTitle=$null
                    SignInActivity=$null
                })
            }
            function Get-MgUserManager              { param($UserId,$ErrorAction) throw 'No manager' }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgDirectoryRoleMember      { param($DirectoryRoleId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    PrincipalId      = 'grev-003-guest'
                    RoleDefinitionId = 'role-ga-001'
                    RoleDefinition   = [PSCustomObject]@{ DisplayName = 'Global Administrator' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-g003'; DisplayName='PIM Review'; Scope=$null })
            }
            # No decisions — DEC-PIM-002 fires for guest, DEC-GREV-003 should fire

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-GREV-003' -and $_.ObjectId -eq 'grev-003-guest' }) | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Rev2.3 Access Review Governance — M4 PIM Review Correlation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    # Test 7: PIM eligible assignment without review evidence emits DEC-PIM-005
    It 'PIM eligible assignment without review evidence emits DEC-PIM-005' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='pim5-dis-0001'; DisplayName='Disabled User PIM5'
                        UserPrincipalName='pim5.disabled@test.com'; AccountEnabled=$false
                    })
                }
                return @()
            }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    PrincipalId      = 'pim5-dis-0001'
                    RoleDefinitionId = 'role-001'
                    RoleDefinition   = [PSCustomObject]@{ DisplayName = 'Global Administrator' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-p005'; DisplayName='PIM Review'; Scope=$null })
            }
            # No instance/decision cmdlets — no review for principal -> DEC-PIM-005

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-PIM-005' -and $_.ObjectId -eq 'pim5-dis-0001' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 8: PIM review evidence older than 180 days emits DEC-PIM-006
    It 'PIM review evidence older than 180 days emits DEC-PIM-006' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='pim6-dis-0001'; DisplayName='Disabled User PIM6'
                        UserPrincipalName='pim6.disabled@test.com'; AccountEnabled=$false
                    })
                }
                return @()
            }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    PrincipalId      = 'pim6-dis-0001'
                    RoleDefinitionId = 'role-002'
                    RoleDefinition   = [PSCustomObject]@{ DisplayName = 'Security Administrator' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-p006'; DisplayName='PIM Review 6'; Scope=$null })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='inst-p006'; AccessReviewScheduleDefinitionId='def-p006'; Status='Completed'; EndDateTime=(Get-Date).AddDays(-10).ToString('yyyy-MM-ddTHH:mm:ssZ') })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                $staleDate = (Get-Date).AddDays(-200).ToString('yyyy-MM-ddTHH:mm:ssZ')
                return @([PSCustomObject]@{
                    Decision         = 'Approve'
                    ReviewedDateTime = $staleDate
                    Principal        = [PSCustomObject]@{ Id='pim6-dis-0001'; DisplayName='Disabled User PIM6' }
                    AccessReviewScheduleDefinitionId = 'def-p006'
                    AccessReviewInstanceId           = 'inst-p006'
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-PIM-006' -and $_.ObjectId -eq 'pim6-dis-0001' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 9: PIM correlation unavailable emits DEC-PIM-007 once
    It 'PIM correlation unavailable emits DEC-PIM-007 exactly once' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='pim7-dis-0001'; DisplayName='Disabled User PIM7'
                        UserPrincipalName='pim7.disabled@test.com'; AccountEnabled=$false
                    })
                }
                return @()
            }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    PrincipalId      = 'pim7-dis-0001'
                    RoleDefinitionId = 'role-003'
                    RoleDefinition   = [PSCustomObject]@{ DisplayName = 'Global Administrator' }
                })
            }
            # AR cmdlets NOT defined -> govApiAvailable=$false -> accessReviewData=$null -> DEC-PIM-007

            $ctx     = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result  = @(Invoke-DecomAssessmentDiscovery -Context $ctx)
            $pim007s = @($result | Where-Object { $_.FindingId -eq 'DEC-PIM-007' })
            $pim007s.Count | Should -Be 1
        }
    }
}

Describe 'Rev2.3 Access Review Governance — M5 Access Package Review Correlation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    # Test 10: AP findings exist but no EM-scoped AR definition emits DEC-AP-006
    It 'Access package findings without EM-scoped review definition emits DEC-AP-006' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='ap6-dis-0001'; DisplayName='AP6 Disabled'
                        UserPrincipalName='ap6.disabled@test.com'; AccountEnabled=$false
                    })
                }
                return @()
            }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    AccessPackageSubject = [PSCustomObject]@{
                        ObjectId='ap6-dis-0001'; DisplayName='AP6 Disabled'; Email='ap6.disabled@test.com'
                    }
                    State='Delivered'; Schedule=$null; ExpiredDateTime=$null
                    AccessPackage=[PSCustomObject]@{ DisplayName='Standard Package' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                # Returns a definition with no entitlementManagement scope
                return @([PSCustomObject]@{
                    Id='def-ap006'; DisplayName='User Review'
                    Scope=[PSCustomObject]@{ Query='/v1.0/groups/group-001/members'; QueryType='MicrosoftGraph' }
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-AP-006' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 11: AP assignment with no review decision emits DEC-AP-007
    It 'Access package assignment with no review decision emits DEC-AP-007' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='ap7-usr-0001'; DisplayName='AP7 User'
                        UserPrincipalName='ap7.user@test.com'; AccountEnabled=$false
                    })
                }
                return @()
            }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    AccessPackageSubject = [PSCustomObject]@{
                        ObjectId='ap7-usr-0001'; DisplayName='AP7 User'; Email='ap7.user@test.com'
                    }
                    State='Delivered'; Schedule=$null; ExpiredDateTime=$null
                    AccessPackage=[PSCustomObject]@{ DisplayName='Basic Package' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='def-ap007'; DisplayName='AP Review'
                    Scope=[PSCustomObject]@{ Query='/v1.0/identityGovernance/entitlementManagement/accessPackages'; QueryType='MicrosoftGraph' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='inst-ap007'; AccessReviewScheduleDefinitionId='def-ap007'
                    Status='Completed'; EndDateTime=(Get-Date).AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                # No decisions for ap7-usr-0001 — returns empty
                return @()
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-AP-007' -and $_.ObjectId -eq 'ap7-usr-0001' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 12: AP assignment with incomplete review decision (NotReviewed) emits DEC-AP-008
    It 'Access package assignment with NotReviewed decision emits DEC-AP-008' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='ap8-usr-0001'; DisplayName='AP8 User'
                        UserPrincipalName='ap8.user@test.com'; AccountEnabled=$false
                    })
                }
                return @()
            }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    AccessPackageSubject = [PSCustomObject]@{
                        ObjectId='ap8-usr-0001'; DisplayName='AP8 User'; Email='ap8.user@test.com'
                    }
                    State='Delivered'; Schedule=$null; ExpiredDateTime=$null
                    AccessPackage=[PSCustomObject]@{ DisplayName='Pending Package' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='def-ap008'; DisplayName='AP Review 8'
                    Scope=[PSCustomObject]@{ Query='/v1.0/identityGovernance/entitlementManagement/accessPackages'; QueryType='MicrosoftGraph' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='inst-ap008'; AccessReviewScheduleDefinitionId='def-ap008'
                    Status='InProgress'; EndDateTime=(Get-Date).AddDays(5).ToString('yyyy-MM-ddTHH:mm:ssZ')
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Decision         = 'NotReviewed'
                    ReviewedDateTime = $null
                    Principal        = [PSCustomObject]@{ Id='ap8-usr-0001'; DisplayName='AP8 User' }
                    AccessReviewScheduleDefinitionId = 'def-ap008'
                    AccessReviewInstanceId           = 'inst-ap008'
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-AP-008' -and $_.ObjectId -eq 'ap8-usr-0001' }) | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Rev2.3 Access Review Governance — M6 CA Exclusion Review Correlation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    # Test 13: CA exclusion group without review evidence emits DEC-CA-003
    It 'CA exclusion group without review definition emits DEC-CA-003' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy {
                param($ErrorAction)
                return @([PSCustomObject]@{
                    Id='ca-pol-001'; DisplayName='Require MFA'; State='enabled'
                    Conditions=[PSCustomObject]@{
                        Users=[PSCustomObject]@{
                            ExcludeUsers=@()
                            ExcludeGroups=@('ca-excl-group-noreview')
                        }
                    }
                })
            }
            function Get-MgGroup {
                param($Top,$GroupId,$Select,$ErrorAction)
                if ($GroupId) {
                    return [PSCustomObject]@{ Id='ca-excl-group-noreview'; DisplayName='CA-MFA-Exclusion-NoReview' }
                }
                return @()
            }
            function Get-MgGroupMember {
                param($GroupId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='member-001' })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                # Returns a definition that does NOT scope to the group ID
                return @([PSCustomObject]@{
                    Id='def-ca003'; DisplayName='Some Other Review'
                    Scope=[PSCustomObject]@{ Query='/v1.0/groups/different-group-id/members'; QueryType='MicrosoftGraph' }
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-CA-003' -and $_.ObjectId -eq 'ca-excl-group-noreview' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 14: CA exclusion review stale (all instances >90 days) emits DEC-CA-004
    It 'CA exclusion group with only stale review instances emits DEC-CA-004' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy {
                param($ErrorAction)
                return @([PSCustomObject]@{
                    Id='ca-pol-002'; DisplayName='Require MFA Stale'; State='enabled'
                    Conditions=[PSCustomObject]@{
                        Users=[PSCustomObject]@{
                            ExcludeUsers=@()
                            ExcludeGroups=@('ca-excl-group-stale')
                        }
                    }
                })
            }
            function Get-MgGroup {
                param($Top,$GroupId,$Select,$ErrorAction)
                if ($GroupId) {
                    return [PSCustomObject]@{ Id='ca-excl-group-stale'; DisplayName='CA-MFA-Exclusion-StaleReview' }
                }
                return @()
            }
            function Get-MgGroupMember {
                param($GroupId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='member-002' })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='def-ca004'; DisplayName='CA Exclusion Review'
                    Scope=[PSCustomObject]@{ Query='/v1.0/groups/ca-excl-group-stale/members'; QueryType='MicrosoftGraph' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                # All instances ended >90 days ago
                return @([PSCustomObject]@{
                    Id='inst-ca004'; AccessReviewScheduleDefinitionId='def-ca004'
                    Status='Completed'
                    EndDateTime=(Get-Date).AddDays(-120).ToString('yyyy-MM-ddTHH:mm:ssZ')
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                return @()
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-CA-004' -and $_.ObjectId -eq 'ca-excl-group-stale' }) | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'Rev2.3 Access Review Governance — Dedup and Safety' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    # Test 15: Deduplication prevents duplicate GREV finding for same guest
    It 'Deduplication prevents duplicate GREV-001 finding for same guest' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') { return @() }
                # Same guest both in sign-in query and metadata query
                return @([PSCustomObject]@{
                    Id='dedup-guest-001'
                    DisplayName='ext_dedup@fabrikam.com'
                    UserPrincipalName='ext_dedup_fabrikam.com#EXT#@contoso.onmicrosoft.com'
                    Department=$null; JobTitle=$null
                    SignInActivity=[PSCustomObject]@{
                        LastSignInDateTime=(Get-Date).AddDays(-200).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    }
                })
            }
            function Get-MgUserManager              { param($UserId,$ErrorAction) $null }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgDirectoryRoleMember      { param($DirectoryRoleId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-dedup'; DisplayName='Dedup Review'; Scope=$null })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = @(Invoke-DecomAssessmentDiscovery -Context $ctx)
            $grev1s = @($result | Where-Object { $_.FindingId -eq 'DEC-GREV-001' -and $_.ObjectId -eq 'dedup-guest-001' })
            $grev1s.Count | Should -Be 1
        }
    }

    # Test 16: Deduplication prevents duplicate CA review finding for same group from two policies
    It 'Deduplication prevents duplicate DEC-CA-003 for same group from two CA policies' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy {
                param($ErrorAction)
                # Two policies both excluding the same group
                return @(
                    [PSCustomObject]@{
                        Id='ca-pol-dedup-1'; DisplayName='MFA Policy 1'; State='enabled'
                        Conditions=[PSCustomObject]@{
                            Users=[PSCustomObject]@{ ExcludeUsers=@(); ExcludeGroups=@('ca-shared-excl-group') }
                        }
                    },
                    [PSCustomObject]@{
                        Id='ca-pol-dedup-2'; DisplayName='MFA Policy 2'; State='enabled'
                        Conditions=[PSCustomObject]@{
                            Users=[PSCustomObject]@{ ExcludeUsers=@(); ExcludeGroups=@('ca-shared-excl-group') }
                        }
                    }
                )
            }
            function Get-MgGroup {
                param($Top,$GroupId,$Select,$ErrorAction)
                if ($GroupId) {
                    return [PSCustomObject]@{ Id='ca-shared-excl-group'; DisplayName='Shared-CA-Exclusion-Group' }
                }
                return @()
            }
            function Get-MgGroupMember {
                param($GroupId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='member-003' })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='def-dedup-ca'; DisplayName='Other Review'
                    Scope=[PSCustomObject]@{ Query='/v1.0/groups/different-id/members'; QueryType='MicrosoftGraph' }
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = @(Invoke-DecomAssessmentDiscovery -Context $ctx)
            $ca003s = @($result | Where-Object { $_.FindingId -eq 'DEC-CA-003' -and $_.ObjectId -eq 'ca-shared-excl-group' })
            $ca003s.Count | Should -Be 1
        }
    }

    # Test 17: All Rev2.3 synthetic findings have required schema fields
    It 'All Rev2.3 demo findings have required schema fields' {
        $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
        $synth  = Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode
        $rev23Ids = @('DEC-REV-001','DEC-GREV-001','DEC-GREV-002','DEC-GREV-003',
                      'DEC-PIM-005','DEC-PIM-006','DEC-PIM-007',
                      'DEC-AP-006','DEC-AP-007','DEC-AP-008',
                      'DEC-CA-003','DEC-CA-004','DEC-GOV-001','DEC-GOV-002')
        foreach ($id in $rev23Ids) {
            $f = $synth | Where-Object { $_.FindingId -eq $id } | Select-Object -First 1
            $f | Should -Not -BeNullOrEmpty -Because "finding $id should be present in demo output"
            $f.FindingId  | Should -Not -BeNullOrEmpty -Because "$id must have FindingId"
            $f.Severity   | Should -Not -BeNullOrEmpty -Because "$id must have Severity"
            $f.RiskScore  | Should -Not -BeNullOrEmpty -Because "$id must have RiskScore"
            $f.Confidence | Should -Not -BeNullOrEmpty -Because "$id must have Confidence"
        }
    }

    # Test 18: Rev2.3 demo findings do not use AutoRemediable
    It 'Rev2.3 demo findings do not use AutoRemediable remediation mode' {
        $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
        $synth  = Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode
        $rev23Ids = @('DEC-REV-001','DEC-GREV-001','DEC-GREV-002','DEC-GREV-003',
                      'DEC-PIM-005','DEC-PIM-006','DEC-PIM-007',
                      'DEC-AP-006','DEC-AP-007','DEC-AP-008',
                      'DEC-CA-003','DEC-CA-004','DEC-GOV-001','DEC-GOV-002')
        $autoRemediable = @($synth | Where-Object {
            $rev23Ids -contains $_.FindingId -and $_.RemediationMode -eq 'AutoRemediable'
        })
        $autoRemediable.Count | Should -Be 0
    }

    # Test 19: Partial coverage (AR instances cmdlet throws) does not crash discovery
    It 'Partial AR coverage — instances cmdlet throws — does not crash' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-partial'; DisplayName='Partial Review'; Scope=$null })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                throw 'Instances unavailable'
            }

            $ctx = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            { Invoke-DecomAssessmentDiscovery -Context $ctx } | Should -Not -Throw
        }
    }
}

Describe 'Rev2.3 Access Review Governance — M2B Live Findings' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    # Test 20: Stale review instance (>90 days) emits DEC-REV-002
    It 'Access review instance ended more than 90 days ago emits DEC-REV-002' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-rev002'; DisplayName='Stale Review'; Scope=$null })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='inst-rev002'; AccessReviewScheduleDefinitionId='def-rev002'
                    Status='Completed'
                    EndDateTime=(Get-Date).AddDays(-100).ToString('yyyy-MM-ddTHH:mm:ssZ')
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Decision='Approve'; ReviewedDateTime=(Get-Date).AddDays(-100).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    Principal=[PSCustomObject]@{ Id='some-user-001'; DisplayName='Some User' }
                    AccessReviewScheduleDefinitionId='def-rev002'; AccessReviewInstanceId='inst-rev002'
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-REV-002' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 21: Review instance with InProgress status emits DEC-REV-003
    It 'Access review instance with InProgress status emits DEC-REV-003' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-rev003'; DisplayName='InProgress Review'; Scope=$null })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='inst-rev003'; AccessReviewScheduleDefinitionId='def-rev003'
                    Status='InProgress'
                    EndDateTime=(Get-Date).AddDays(5).ToString('yyyy-MM-ddTHH:mm:ssZ')
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                return @()
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-REV-003' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 21b: Every DEC-REV-003 finding (both paths) has Severity Medium and RiskScore 50
    It 'All DEC-REV-003 findings have Severity Medium and RiskScore 50' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            # Definition with two instances: one InProgress (path 1), one Completed with NotReviewed decision (path 2)
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{ Id='def-r003both'; DisplayName='Dual Path Review'; Scope=$null })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                return @(
                    [PSCustomObject]@{ Id='inst-inprog'; AccessReviewScheduleDefinitionId='def-r003both'
                        Status='InProgress'; EndDateTime=(Get-Date).AddDays(5).ToString('yyyy-MM-ddTHH:mm:ssZ') },
                    [PSCustomObject]@{ Id='inst-done';   AccessReviewScheduleDefinitionId='def-r003both'
                        Status='Completed'; EndDateTime=(Get-Date).AddDays(-10).ToString('yyyy-MM-ddTHH:mm:ssZ') }
                )
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                if ($AccessReviewInstanceId -eq 'inst-done') {
                    return @([PSCustomObject]@{
                        Id='dec-nr'; AccessReviewInstanceId='inst-done'
                        AccessReviewScheduleDefinitionId='def-r003both'; Decision='NotReviewed'
                    })
                }
                return @()
            }

            $ctx     = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result  = Invoke-DecomAssessmentDiscovery -Context $ctx
            $rev003  = @($result | Where-Object { $_.FindingId -eq 'DEC-REV-003' })
            $rev003.Count | Should -BeGreaterOrEqual 1
            foreach ($f in $rev003) {
                $f.Severity  | Should -Be 'Medium'
                $f.RiskScore | Should -Be 50
            }
        }
    }

    # Test 22: AR definition scope uncorrelated to any finding emits DEC-REV-004
    It 'AR definition with uncorrelated scope emits DEC-REV-004' {
        InModuleScope Discovery {
            function Get-MgUser                     { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='def-rev004'
                    DisplayName='Uncorrelated Scope Review'
                    Scope=[PSCustomObject]@{
                        Query='/v1.0/groups/ffffffff-ffff-ffff-ffff-ffffffffffff/members'
                        QueryType='MicrosoftGraph'
                    }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='inst-rev004'; AccessReviewScheduleDefinitionId='def-rev004'
                    Status='Completed'; EndDateTime=(Get-Date).AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Decision='Approve'; ReviewedDateTime=(Get-Date).AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    Principal=[PSCustomObject]@{ Id='some-user-rev4'; DisplayName='User Rev4' }
                    AccessReviewScheduleDefinitionId='def-rev004'; AccessReviewInstanceId='inst-rev004'
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-REV-004' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 23: Deny review decision with residual finding access emits DEC-REV-005
    It 'Deny review decision for principal with residual access finding emits DEC-REV-005' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter,$Property,$Select,[switch]$All,$ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='rev5-dis-0001'; DisplayName='Rev5 Disabled'
                        UserPrincipalName='rev5.disabled@test.com'; AccountEnabled=$false
                    })
                }
                return @()
            }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgDirectoryRoleMember      { param($DirectoryRoleId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserMemberOf {
                param($UserId,[switch]$All,$ErrorAction)
                # Return a group with AdditionalProperties odata.type so DEC-USER-001 fires for rev5-dis-0001
                return @([PSCustomObject]@{
                    Id='grp-rev5'
                    AdditionalProperties=@{ '@odata.type'='#microsoft.graph.group'; 'displayName'='Some Group' }
                })
            }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition {
                param([switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='def-rev005'; DisplayName='Rev5 Review'
                    Scope=[PSCustomObject]@{ Query='/v1.0/users/rev5-dis-0001'; QueryType='MicrosoftGraph' }
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstance {
                param($AccessReviewScheduleDefinitionId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Id='inst-rev005'; AccessReviewScheduleDefinitionId='def-rev005'
                    Status='Completed'; EndDateTime=(Get-Date).AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')
                })
            }
            function Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision {
                param($AccessReviewScheduleDefinitionId,$AccessReviewInstanceId,[switch]$All,$ErrorAction)
                return @([PSCustomObject]@{
                    Decision='Deny'; ReviewedDateTime=(Get-Date).AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')
                    Principal=[PSCustomObject]@{ Id='rev5-dis-0001'; DisplayName='Rev5 Disabled' }
                    AccessReviewScheduleDefinitionId='def-rev005'; AccessReviewInstanceId='inst-rev005'
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-REV-005' -and $_.ObjectId -eq 'rev5-dis-0001' }) | Should -Not -BeNullOrEmpty
        }
    }

    # Test 24: Demo mode does not emit DEC-REV-002/003/004/005
    It 'Demo mode does not emit live-only findings DEC-REV-002/003/004/005' {
        $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
        $synth  = Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode
        ($synth | Where-Object { $_.FindingId -eq 'DEC-REV-002' }) | Should -BeNullOrEmpty
        ($synth | Where-Object { $_.FindingId -eq 'DEC-REV-003' }) | Should -BeNullOrEmpty
        ($synth | Where-Object { $_.FindingId -eq 'DEC-REV-004' }) | Should -BeNullOrEmpty
        ($synth | Where-Object { $_.FindingId -eq 'DEC-REV-005' }) | Should -BeNullOrEmpty
    }
}
