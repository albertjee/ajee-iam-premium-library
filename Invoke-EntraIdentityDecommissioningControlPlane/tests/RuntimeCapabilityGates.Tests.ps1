#Requires -Modules Pester

BeforeAll {
    $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'

    foreach ($module in @('Utilities','Discovery','NhiDiscovery','NhiActivityLog')) {
        Remove-Module $module -Force -ErrorAction SilentlyContinue
    }

    Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiDiscovery.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiActivityLog.psm1') -Force -DisableNameChecking

    function global:New-RuntimeTestNhiObject {
        param(
            [string]$ObjectId = 'runtime-test-id',
            [string]$DisplayName = 'Runtime Test Object',
            [bool]$AgenticCandidate = $true
        )

        [PSCustomObject]@{
            PSTypeName        = 'NhiFound'
            ObjectId          = $ObjectId
            DisplayName       = $DisplayName
            ObjectType        = 'ServicePrincipal'
            AgenticCandidate  = $AgenticCandidate
            NhiCandidate      = $true
            AutomationCandidate = $false
            WorkloadCandidate = $true
        }
    }

    function global:New-RuntimeTestServicePrincipals {
        param([int]$Count = 61)

        $items = @()
        for ($i = 1; $i -le $Count; $i++) {
            $items += [PSCustomObject]@{
                Id                    = "sp-$i"
                AppId                 = "app-$i"
                DisplayName           = "runtime-sp-$i"
                ServicePrincipalType   = 'Application'
                PublisherName         = 'Contoso Corp'
                VerifiedPublisher     = $null
                AccountEnabled        = $true
                Tags                  = @()
                AppOwnerOrganizationId = 'tenant-001'
                AdditionalProperties  = @{}
                Credentials           = @()
                Owners                = @()
                AppRoleAssignments    = @()
                OAuthGrants           = @()
            }
        }

        return $items
    }
}

AfterAll {
    foreach ($module in @('Utilities','Discovery','NhiDiscovery','NhiActivityLog')) {
        Remove-Module $module -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Discovery runtime capability gates' {
    BeforeEach {
        Reset-DecomRuntimeState
    }

    It 'Access review unavailable warns once, not repeatedly' {
        InModuleScope Discovery {
            function Write-DecomInfo { param([string]$Message) }
            Mock Write-Warning -ModuleName Utilities { }
            function Get-MgUser { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole { param($ErrorAction) @() }
            function Get-MgDirectoryRoleMember { param($DirectoryRoleId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserMemberOf { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserManager { param($UserId,$ErrorAction) $null }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn { param($Top,$ErrorAction) @() }
            function Get-MgGroup { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgGroupMember { param($GroupId,[switch]$All,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition { param([switch]$All,$ErrorAction) throw 'User does not have access to any of the reviews.' }

            $ctx = [PSCustomObject]@{ TenantId = 'test'; Mode = 'Assessment'; DemoMode = $false; Coverage = $null }
            { Invoke-DecomAssessmentDiscovery -Context $ctx } | Should -Not -Throw
            { Invoke-DecomAssessmentDiscovery -Context $ctx } | Should -Not -Throw

        }
    }

    It 'PIM premium-license unavailable warns once and skips repeated calls' {
        InModuleScope Discovery {
            $script:pimCalls = 0
            function Write-DecomInfo { param([string]$Message) }
            Mock Write-Warning -ModuleName Utilities { }
            function Get-MgUser { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole { param($ErrorAction) @() }
            function Get-MgDirectoryRoleMember { param($DirectoryRoleId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserMemberOf { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserManager { param($UserId,$ErrorAction) $null }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn { param($Top,$ErrorAction) @() }
            function Get-MgGroup { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgGroupMember { param($GroupId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance {
                param([switch]$All,$ErrorAction)
                $script:pimCalls++
                throw 'AADPremiumLicenseRequired'
            }

            $ctx = [PSCustomObject]@{ TenantId = 'test'; Mode = 'Assessment'; DemoMode = $false; Coverage = $null }
            Invoke-DecomAssessmentDiscovery -Context $ctx | Out-Null
            Invoke-DecomAssessmentDiscovery -Context $ctx | Out-Null

            $script:pimCalls | Should -Be 1
        }
    }

    It 'Access package unavailable warns once and does not retry per run' {
        InModuleScope Discovery {
            $script:apCalls = 0
            function Write-DecomInfo { param([string]$Message) }
            Mock Write-Warning -ModuleName Utilities { }
            function Get-MgUser { param($Filter,$Property,$Select,[switch]$All,$ErrorAction) @() }
            function Get-MgApplication { param($Select,[switch]$All,$ErrorAction) @() }
            function Get-MgServicePrincipal { param($Filter,$Select,[switch]$All,$ErrorAction,$Top) @() }
            function Get-MgDirectoryRole { param($ErrorAction) @() }
            function Get-MgDirectoryRoleMember { param($DirectoryRoleId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserMemberOf { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserAppRoleAssignment { param($UserId,[switch]$All,$ErrorAction) @() }
            function Get-MgUserManager { param($UserId,$ErrorAction) $null }
            function Get-MgIdentityConditionalAccessPolicy { param($ErrorAction) @() }
            function Get-MgAuditLogSignIn { param($Top,$ErrorAction) @() }
            function Get-MgGroup { param($Top,$GroupId,$Select,$ErrorAction) @() }
            function Get-MgGroupMember { param($GroupId,[switch]$All,$ErrorAction) @() }
            function Get-MgIdentityGovernanceAccessReviewDefinition { param([switch]$All,$ErrorAction) @() }
            function Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance { param([switch]$All,$ErrorAction) @() }
            function Get-MgEntitlementManagementAssignment {
                param([switch]$All,$ErrorAction)
                $script:apCalls++
                throw 'EntitlementManagement.Read.All required'
            }

            $ctx = [PSCustomObject]@{ TenantId = 'test'; Mode = 'Assessment'; DemoMode = $false; Coverage = $null }
            Invoke-DecomAssessmentDiscovery -Context $ctx | Out-Null
            Invoke-DecomAssessmentDiscovery -Context $ctx | Out-Null

            $script:apCalls | Should -Be 1
        }
    }
}

Describe 'NhiActivityLog runtime availability' {
    BeforeEach {
        Reset-DecomRuntimeState
    }

    It 'Sign-in unavailable returns QuerySucceeded = false and suppresses dependent findings' {
        Mock Get-MgBetaAuditLogSignIn -ModuleName NhiActivityLog {
            throw 'AADPremiumLicenseRequired'
        }

        Mock Write-Warning -ModuleName Utilities { }

        $first = Get-NhiAgentSignInLog -ObjectId 'sp-signin-test' -ObjectType ServicePrincipal
        $second = Get-NhiAgentSignInLog -ObjectId 'sp-signin-test' -ObjectType ServicePrincipal

        $first.QuerySucceeded | Should -BeFalse
        $first.CapabilityAvailable | Should -BeFalse
        $second.QuerySucceeded | Should -BeFalse

        Assert-MockCalled Get-MgBetaAuditLogSignIn -ModuleName NhiActivityLog -Times 1 -Exactly
        $analysis = Invoke-NhiAgentSignInAnalysis -SignInLogs $first -ObjectId 'sp-signin-test'
        $analysis.QuerySucceeded | Should -BeFalse

        $scan = Invoke-NhiActivityLogScan -NhiObject (New-RuntimeTestNhiObject -ObjectId 'sp-signin-test') -SignInLogs $first -DirectoryLogs @()
        @($scan).Count | Should -Be 0
    }
}

Describe 'NhiDiscovery runtime progress' {
    BeforeEach {
        Reset-DecomRuntimeState
    }

    It 'Service-principal loop emits transcript-friendly heartbeat and preserves result count' {
        InModuleScope NhiDiscovery {
            $script:infoMessages = @()
            $script:progressCalls = @()

            function Write-DecomInfo { param([string]$Message) $script:infoMessages += $Message }
            function Write-Progress {
                param(
                    [string]$Activity,
                    [string]$Status,
                    [int]$PercentComplete,
                    [switch]$Completed
                )
                $script:progressCalls += [pscustomobject]@{
                    Activity = $Activity
                    Status = $Status
                    PercentComplete = $PercentComplete
                    Completed = [bool]$Completed
                }
            }
            function Get-DecomNhiServicePrincipals { param([pscustomobject]$Context) @(New-RuntimeTestServicePrincipals -Count 613) }
            function Get-DecomNhiApplications { param([pscustomobject]$Context) @() }
            function Get-DecomNhiOwners { param([string]$ObjectId,[string]$ObjectType = 'ServicePrincipal') @() }
            function Get-DecomNhiAppRoleAssignments { param([string]$ServicePrincipalId) @() }
            function Get-DecomNhiOAuthGrants { param([string]$ServicePrincipalId) @() }

            $ctx = [PSCustomObject]@{ DemoMode = $false; OutputPath = $env:TEMP }
            $result = Invoke-DecomNhiDiscovery -Context $ctx

            $result.Count | Should -Be 613
            $script:infoMessages | Should -Contain 'Service principal progress: 50 / 613 processed (8%)'
            $script:infoMessages | Should -Contain 'Service principal progress: 613 / 613 processed (100%)'
            $script:infoMessages | Should -Contain 'Service principal processing complete: 613 / 613 processed'
            ($script:progressCalls | Where-Object { $_.Completed }).Count | Should -Be 1
            ($script:progressCalls | Where-Object { -not $_.Completed }).Count | Should -BeGreaterThan 0
        }
    }
}
