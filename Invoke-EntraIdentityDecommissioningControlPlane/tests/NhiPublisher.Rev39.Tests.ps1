#Requires -Version 5.1

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiPublisher.psm1'
    Import-Module $script:ModulePath -Force -DisableNameChecking
}

Describe 'NhiPublisher.Rev39 - NHI-PUB-001, NHI-PUB-002, NHI-REG-001' {

    Context 'NHI-PUB-001: External publisher' {
        It 'fires when publisher is external tenant' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = 'tenant-external'
                VerifiedPublisher = $null
                SignInAudience = 'AzureADMyOrg'
                PublisherDomain = 'external.com'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PUB-001' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Medium'
            $f.RiskScore | Should -Be 30
        }

        It 'does NOT fire when publisher is same tenant' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = 'tenant-local'
                VerifiedPublisher = $null
                SignInAudience = 'AzureADMyOrg'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PUB-001' }
            $f | Should -BeNullOrEmpty
        }

        It 'does NOT fire when PublisherTenantId is null' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = $null
                VerifiedPublisher = $null
                SignInAudience = 'AzureADMyOrg'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PUB-001' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'NHI-PUB-002: No verified publisher' {
        It 'fires when VerifiedPublisher is null' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = $null
                VerifiedPublisher = $null
                SignInAudience = 'AzureADMyOrg'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PUB-002' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Medium'
            $f.RiskScore | Should -Be 25
        }

        It 'fires when VerifiedPublisher.DisplayName is empty' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $vp = [PSCustomObject]@{ DisplayName = '' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = $null
                VerifiedPublisher = $vp
                SignInAudience = 'AzureADMyOrg'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PUB-002' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'does NOT fire when VerifiedPublisher.DisplayName is set' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $vp = [PSCustomObject]@{ DisplayName = 'Verified Publisher Inc' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = $null
                VerifiedPublisher = $vp
                SignInAudience = 'AzureADMyOrg'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PUB-002' }
            $f | Should -BeNullOrEmpty
        }

        It 'does NOT fire when no app registration found for SP' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{} -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PUB-002' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'NHI-REG-001: Multi-tenant or personal sign-in' {
        It 'fires when SignInAudience = AzureADMultipleOrgs' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = $null
                VerifiedPublisher = $null
                SignInAudience = 'AzureADMultipleOrgs'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-REG-001' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'High'
            $f.RiskScore | Should -Be 45
        }

        It 'fires when SignInAudience = AzureADandPersonalMicrosoftAccount' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = $null
                VerifiedPublisher = $null
                SignInAudience = 'AzureADandPersonalMicrosoftAccount'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-REG-001' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'fires when SignInAudience = PersonalMicrosoftAccount' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = $null
                VerifiedPublisher = $null
                SignInAudience = 'PersonalMicrosoftAccount'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-REG-001' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'does NOT fire when SignInAudience = AzureADMyOrg' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = $null
                VerifiedPublisher = $null
                SignInAudience = 'AzureADMyOrg'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-REG-001' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'Finding coexistence' {
        It 'NHI-PUB-001 and NHI-REG-001 can coexist for same SP' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $appReg = [PSCustomObject]@{
                AppId = 'app-001'
                PublisherTenantId = 'tenant-external'
                VerifiedPublisher = $null
                SignInAudience = 'AzureADMultipleOrgs'
            }
            $result = Invoke-NhiPublisherScan -ServicePrincipals @($sp) -AppRegistrationByAppId @{ 'app-001' = $appReg } -TenantId 'tenant-local'
            $f001 = $result | Where-Object { $_.FindingId -eq 'NHI-PUB-001' }
            $fReg = $result | Where-Object { $_.FindingId -eq 'NHI-REG-001' }
            $f001 | Should -Not -BeNullOrEmpty
            $fReg | Should -Not -BeNullOrEmpty
            $f001.ObjectId | Should -Be $sp.Id
            $fReg.ObjectId | Should -Be $sp.Id
        }
    }
}