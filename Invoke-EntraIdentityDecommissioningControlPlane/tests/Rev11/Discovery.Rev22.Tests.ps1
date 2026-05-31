#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev2.2 Discovery Coverage Model' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'

        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue
        Remove-Module Analysis   -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Analysis.psm1')   -Force -DisableNameChecking
    }

    Context 'New-DecomCoverage includes Rev2.2 fields' {
        It 'New-DecomCoverage contains PimEligibleAssignments initialised false' {
            $coverage = New-DecomCoverage
            ($coverage.Keys -contains 'PimEligibleAssignments') | Should -Be $true
            $coverage.PimEligibleAssignments | Should -Be $false
        }

        It 'New-DecomCoverage contains all 5 Rev2.2 fields' {
            $coverage = New-DecomCoverage
            ($coverage.Keys -contains 'PimEligibleAssignments')       | Should -Be $true
            ($coverage.Keys -contains 'PimActivationEvidence')        | Should -Be $true
            ($coverage.Keys -contains 'EntitlementAssignments')       | Should -Be $true
            ($coverage.Keys -contains 'AccessPackagePolicies')        | Should -Be $true
            ($coverage.Keys -contains 'AccessReviewScheduleEvidence') | Should -Be $true
        }
    }

    Context 'Demo mode synthetic data' {
        It 'DemoMode returns DEC-PIM-001 finding' {
            $ctx   = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
            $synth = Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode
            ($synth | Where-Object { $_.FindingId -eq 'DEC-PIM-001' }) | Should -Not -BeNullOrEmpty
        }

        It 'DemoMode returns DEC-PIM-002 finding' {
            $ctx   = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
            $synth = Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode
            ($synth | Where-Object { $_.FindingId -eq 'DEC-PIM-002' }) | Should -Not -BeNullOrEmpty
        }

        It 'DemoMode returns DEC-PIM-003 finding with Confidence Low' {
            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
            $synth  = Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode
            $pim003 = $synth | Where-Object { $_.FindingId -eq 'DEC-PIM-003' } | Select-Object -First 1
            $pim003 | Should -Not -BeNullOrEmpty
            $pim003.Confidence | Should -Be 'Low'
        }

        It 'DemoMode returns all 5 AP finding IDs' {
            $ctx   = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
            $synth = Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode
            ($synth | Where-Object { $_.FindingId -eq 'DEC-AP-001' }) | Should -Not -BeNullOrEmpty
            ($synth | Where-Object { $_.FindingId -eq 'DEC-AP-002' }) | Should -Not -BeNullOrEmpty
            ($synth | Where-Object { $_.FindingId -eq 'DEC-AP-003' }) | Should -Not -BeNullOrEmpty
            ($synth | Where-Object { $_.FindingId -eq 'DEC-AP-004' }) | Should -Not -BeNullOrEmpty
            ($synth | Where-Object { $_.FindingId -eq 'DEC-AP-005' }) | Should -Not -BeNullOrEmpty
        }

        It 'DemoMode sets PimEligibleAssignments coverage flag' {
            $ctx = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
            Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode | Out-Null
            $ctx.Coverage.PimEligibleAssignments | Should -Be $true
        }

        It 'DemoMode sets EntitlementAssignments coverage flag' {
            $ctx = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$true; Coverage=$null }
            Invoke-DecomAssessmentDiscovery -Context $ctx -DemoMode | Out-Null
            $ctx.Coverage.EntitlementAssignments | Should -Be $true
        }
    }
}

Describe 'Rev2.2 PIM Detection Logic' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'

        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    It 'PIM cmdlet unavailable does not throw' {
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
            # PIM cmdlet intentionally NOT defined here — covered by try/catch

            $ctx = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            { Invoke-DecomAssessmentDiscovery -Context $ctx } | Should -Not -Throw
        }
    }

    It 'Entitlement Management cmdlet unavailable does not throw' {
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
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            # AP cmdlets intentionally NOT defined here

            $ctx = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            { Invoke-DecomAssessmentDiscovery -Context $ctx } | Should -Not -Throw
        }
    }

    It 'Disabled user with eligible PIM assignment emits DEC-PIM-001' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter, $Property, $Select, [switch]$All, $ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='pim-dis-0001'; DisplayName='Disabled User PIM'
                        UserPrincipalName='pim.disabled@test.com'; AccountEnabled=$false
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
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance {
                param([switch]$All, $ErrorAction)
                return @([PSCustomObject]@{
                    PrincipalId      = 'pim-dis-0001'
                    RoleDefinitionId = 'role-001'
                    RoleDefinition   = [PSCustomObject]@{ DisplayName = 'Global Administrator' }
                })
            }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-PIM-001' }) | Should -Not -BeNullOrEmpty
        }
    }

    It 'Guest with eligible PIM assignment emits DEC-PIM-002' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter, $Property, $Select, [switch]$All, $ErrorAction)
                if ($Filter -match 'accountEnabled') { return @() }
                return @([PSCustomObject]@{
                    Id='pim-guest-0001'; DisplayName='Guest User PIM'
                    UserPrincipalName='pim.guest_ext@contoso.com'
                    Department=$null; JobTitle=$null; SignInActivity=$null
                })
            }
            function Get-MgUserManager              { param($UserId,$ErrorAction) { $null } }
            function Get-MgApplication              { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal         { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole            { param($ErrorAction) @() }
            function Get-MgUserMemberOf             { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment    { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn           { param($Top,$ErrorAction) throw 'unavailable' }
            function Get-MgGroup                    { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance {
                param([switch]$All, $ErrorAction)
                return @([PSCustomObject]@{
                    PrincipalId      = 'pim-guest-0001'
                    RoleDefinitionId = 'role-001'
                    RoleDefinition   = [PSCustomObject]@{ DisplayName = 'Global Administrator' }
                })
            }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-PIM-002' }) | Should -Not -BeNullOrEmpty
        }
    }

    It 'Eligible PIM assignments with unavailable activation evidence emit DEC-PIM-003 at most once' {
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
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance {
                param([switch]$All, $ErrorAction)
                return @(
                    [PSCustomObject]@{ PrincipalId='pim-oth-0001'; RoleDefinitionId='role-001'; RoleDefinition=[PSCustomObject]@{ DisplayName='Reader' } },
                    [PSCustomObject]@{ PrincipalId='pim-oth-0002'; RoleDefinitionId='role-002'; RoleDefinition=[PSCustomObject]@{ DisplayName='Reader' } }
                )
            }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }

            $ctx     = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result  = @(Invoke-DecomAssessmentDiscovery -Context $ctx)
            $pim003s = @($result | Where-Object { $_.FindingId -eq 'DEC-PIM-003' })
            $pim003s.Count | Should -Be 1
        }
    }
}

Describe 'Rev2.2 AP Detection Logic' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'

        Remove-Module Utilities  -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery  -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')  -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')  -Force -DisableNameChecking
    }

    It 'Disabled user with active access package assignment emits DEC-AP-001' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter, $Property, $Select, [switch]$All, $ErrorAction)
                if ($Filter -match 'accountEnabled') {
                    return @([PSCustomObject]@{
                        Id='ap-dis-0001'; DisplayName='AP Disabled User'
                        UserPrincipalName='ap.disabled@test.com'; AccountEnabled=$false
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
                param([switch]$All, $ErrorAction)
                return @([PSCustomObject]@{
                    AccessPackageSubject = [PSCustomObject]@{
                        ObjectId    = 'ap-dis-0001'
                        DisplayName = 'AP Disabled User'
                        Email       = 'ap.disabled@test.com'
                    }
                    State           = 'Delivered'
                    Schedule        = $null
                    ExpiredDateTime = $null
                    AccessPackage   = [PSCustomObject]@{ DisplayName = 'Standard Access' }
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-AP-001' }) | Should -Not -BeNullOrEmpty
        }
    }

    It 'Guest with access package assignment emits DEC-AP-002' {
        InModuleScope Discovery {
            function Get-MgUser {
                param($Filter, $Property, $Select, [switch]$All, $ErrorAction)
                if ($Filter -match 'accountEnabled') { return @() }
                return @([PSCustomObject]@{
                    Id='ap-guest-0001'; DisplayName='AP Guest User'
                    UserPrincipalName='ap.guest_ext@contoso.com'
                    Department=$null; JobTitle=$null; SignInActivity=$null
                })
            }
            function Get-MgUserManager              { param($UserId,$ErrorAction) { $null } }
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
                param([switch]$All, $ErrorAction)
                return @([PSCustomObject]@{
                    AccessPackageSubject = [PSCustomObject]@{
                        ObjectId    = 'ap-guest-0001'
                        DisplayName = 'AP Guest User'
                        Email       = 'ap.guest@ext.com'
                    }
                    State           = 'Delivered'
                    Schedule        = $null
                    ExpiredDateTime = $null
                    AccessPackage   = [PSCustomObject]@{ DisplayName = 'Vendor Package' }
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-AP-002' }) | Should -Not -BeNullOrEmpty
        }
    }

    It 'Assignment with missing expiration evidence emits DEC-AP-003' {
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
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment {
                param([switch]$All, $ErrorAction)
                return @([PSCustomObject]@{
                    AccessPackageSubject = [PSCustomObject]@{
                        ObjectId    = 'ap-oth-0001'
                        DisplayName = 'Some User'
                        Email       = 'some.user@test.com'
                    }
                    State           = 'Delivered'
                    Schedule        = $null
                    ExpiredDateTime = $null
                    AccessPackage   = [PSCustomObject]@{ DisplayName = 'No Expiry Package' }
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            ($result | Where-Object { $_.FindingId -eq 'DEC-AP-003' }) | Should -Not -BeNullOrEmpty
        }
    }

    It 'DEC-AP-004 emitted without claiming unreviewed status' {
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
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment {
                param([switch]$All, $ErrorAction)
                return @([PSCustomObject]@{
                    AccessPackageSubject = [PSCustomObject]@{
                        ObjectId    = 'ap-oth-0002'
                        DisplayName = 'Another User'
                        Email       = 'another@test.com'
                    }
                    State           = 'Delivered'
                    Schedule        = $null
                    ExpiredDateTime = $null
                    AccessPackage   = [PSCustomObject]@{ DisplayName = 'Basic Package' }
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            $ap004  = $result | Where-Object { $_.FindingId -eq 'DEC-AP-004' } | Select-Object -First 1
            $ap004 | Should -Not -BeNullOrEmpty
            $ap004.Evidence | Should -Not -Match 'unreviewed'
            $ap004.Evidence | Should -Not -Match 'review failed'
        }
    }

    It 'Sensitive resource heuristic emits DEC-AP-005 with Confidence Medium' {
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
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment {
                param([switch]$All, $ErrorAction)
                return @([PSCustomObject]@{
                    AccessPackageSubject = [PSCustomObject]@{
                        ObjectId    = 'ap-oth-0003'
                        DisplayName = 'Sensitive User'
                        Email       = 'sensitive@test.com'
                    }
                    State           = 'Delivered'
                    Schedule        = $null
                    ExpiredDateTime = $null
                    AccessPackage   = [PSCustomObject]@{ DisplayName = 'Global Admin Access Package' }
                })
            }

            $ctx    = [PSCustomObject]@{ TenantId='test'; Mode='Assessment'; DemoMode=$false; Coverage=$null }
            $result = Invoke-DecomAssessmentDiscovery -Context $ctx
            $ap005  = $result | Where-Object { $_.FindingId -eq 'DEC-AP-005' } | Select-Object -First 1
            $ap005 | Should -Not -BeNullOrEmpty
            $ap005.Confidence | Should -Be 'Medium'
        }
    }
}
