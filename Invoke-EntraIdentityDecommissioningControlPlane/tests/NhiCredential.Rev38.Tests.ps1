#Requires -Version 5.1

Describe 'NhiCredential - NHI-CRED-001 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiCredential.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'NHI-CRED-001 - Client secret detection' {
        It 'Fires when SP has passwordCredentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-001'
                AppId = 'app-001'
                DisplayName = 'test-sp'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-001'
                        StartDateTime = $now.AddDays(-30).ToString('o')
                        EndDateTime = $now.AddDays(365).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-001' }
            $f | Should -Not -BeNullOrEmpty
            $f.ObjectId | Should -Be 'sp-001'
        }

        It 'Does NOT fire when SP has no passwordCredentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-002'
                AppId = 'app-002'
                DisplayName = 'test-sp-no-secret'
                passwordCredentials = @()
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-001' }
            $f | Should -BeNullOrEmpty
        }
    }
}

Describe 'NhiCredential - NHI-CRED-002 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiCredential.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'NHI-CRED-002 - Secret age warning (90 days)' {
        It 'Fires when secret age is exactly 90 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-003'
                AppId = 'app-003'
                DisplayName = 'test-sp-90'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-90'
                        StartDateTime = $now.AddDays(-90).ToString('o')
                        EndDateTime = $now.AddDays(295).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-002' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when secret age is 91 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-004'
                AppId = 'app-004'
                DisplayName = 'test-sp-91'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-91'
                        StartDateTime = $now.AddDays(-91).ToString('o')
                        EndDateTime = $now.AddDays(294).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-002' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when secret age is 89 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-005'
                AppId = 'app-005'
                DisplayName = 'test-sp-89'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-89'
                        StartDateTime = $now.AddDays(-89).ToString('o')
                        EndDateTime = $now.AddDays(296).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-002' }
            $f | Should -BeNullOrEmpty
        }

        It 'Does NOT fire when secret age is >= 180 (suppressed by CRED-003)' {
            $sp = [PSCustomObject]@{
                Id = 'sp-006'
                AppId = 'app-006'
                DisplayName = 'test-sp-180'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-180'
                        StartDateTime = $now.AddDays(-200).ToString('o')
                        EndDateTime = $now.AddDays(180).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            # Should have CRED-003 but NOT CRED-002
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-002' }
            $f003 = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-003' }
            $f002 | Should -BeNullOrEmpty
            $f003 | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'NhiCredential - NHI-CRED-003 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiCredential.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'NHI-CRED-003 - Secret age critical (180 days)' {
        It 'Fires when secret age is exactly 180 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-007'
                AppId = 'app-007'
                DisplayName = 'test-sp-exact-180'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-exact-180'
                        StartDateTime = $now.AddDays(-180).ToString('o')
                        EndDateTime = $now.AddDays(185).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-003' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when secret age is 181 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-008'
                AppId = 'app-008'
                DisplayName = 'test-sp-181'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-181'
                        StartDateTime = $now.AddDays(-181).ToString('o')
                        EndDateTime = $now.AddDays(184).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-003' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when secret age is 179 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-009'
                AppId = 'app-009'
                DisplayName = 'test-sp-179'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-179'
                        StartDateTime = $now.AddDays(-179).ToString('o')
                        EndDateTime = $now.AddDays(186).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-003' }
            $f | Should -BeNullOrEmpty
        }

        It 'CRED-003 and CRED-002 are mutually exclusive for same credential' {
            $sp = [PSCustomObject]@{
                Id = 'sp-010'
                AppId = 'app-010'
                DisplayName = 'test-sp-mutual-excl'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-exclusive'
                        StartDateTime = $now.AddDays(-200).ToString('o')
                        EndDateTime = $now.AddDays(165).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-002' }
            $f003 = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-003' }
            $f002 | Should -BeNullOrEmpty
            $f003 | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'NhiCredential - NHI-CRED-004 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiCredential.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'NHI-CRED-004 - Expired credential with recent sign-in' {
        It 'Fires for expired passwordCredential with recent sign-in' {
            $sp = [PSCustomObject]@{
                Id = 'sp-011'
                AppId = 'app-011'
                DisplayName = 'test-sp-expired-pwd'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-expired-pwd'
                        StartDateTime = $now.AddDays(-400).ToString('o')
                        EndDateTime = $now.AddDays(-10).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $signInByAppId = @{
                'app-011' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-30); DaysSinceSignIn = 30 }
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-004' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires for expired keyCredential with recent sign-in' {
            $sp = [PSCustomObject]@{
                Id = 'sp-012'
                AppId = 'app-012'
                DisplayName = 'test-sp-expired-key'
                passwordCredentials = @()
                keyCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-expired-key'
                        StartDateTime = $now.AddDays(-400).ToString('o')
                        EndDateTime = $now.AddDays(-5).ToString('o')
                    }
                )
            }
            $signInByServicePrincipalId = @{
                'sp-012' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-60); DaysSinceSignIn = 60 }
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId $signInByServicePrincipalId
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-004' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when credential is expired but no sign-in record' {
            $sp = [PSCustomObject]@{
                Id = 'sp-013'
                AppId = 'app-013'
                DisplayName = 'test-sp-expired-no-signin'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-no-signin'
                        StartDateTime = $now.AddDays(-400).ToString('o')
                        EndDateTime = $now.AddDays(-10).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-004' }
            $f | Should -BeNullOrEmpty
        }

        It 'SignInByServicePrincipalId lookup works when AppId lookup returns nothing' {
            $sp = [PSCustomObject]@{
                Id = 'sp-014'
                AppId = 'app-014'
                DisplayName = 'test-sp-lookup-order'
                passwordCredentials = @()
                keyCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-lookup'
                        StartDateTime = $now.AddDays(-400).ToString('o')
                        EndDateTime = $now.AddDays(-10).ToString('o')
                    }
                )
            }
            # AppId lookup has nothing, falls through to ServicePrincipalId lookup
            $signInByAppId = @{}
            $signInByServicePrincipalId = @{
                'sp-014' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-50); DaysSinceSignIn = 50 }
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId $signInByServicePrincipalId
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-004' }
            $f | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'NhiCredential - NHI-CRED-005 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiCredential.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'NHI-CRED-005 - Credential expiring within 30 days' {
        It 'Fires when credential expires in exactly 30 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-015'
                AppId = 'app-015'
                DisplayName = 'test-sp-exp30'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-exp30'
                        StartDateTime = $now.AddDays(-100).ToString('o')
                        EndDateTime = $now.AddDays(30).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-005' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when credential expires in 15 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-016'
                AppId = 'app-016'
                DisplayName = 'test-sp-exp15'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-exp15'
                        StartDateTime = $now.AddDays(-100).ToString('o')
                        EndDateTime = $now.AddDays(15).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-005' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when credential expires in 31 days' {
            $sp = [PSCustomObject]@{
                Id = 'sp-017'
                AppId = 'app-017'
                DisplayName = 'test-sp-exp31'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-exp31'
                        StartDateTime = $now.AddDays(-100).ToString('o')
                        EndDateTime = $now.AddDays(32).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-005' }
            $f | Should -BeNullOrEmpty
        }

        It 'Does NOT fire when credential is already expired (CRED-004 scope)' {
            $sp = [PSCustomObject]@{
                Id = 'sp-018'
                AppId = 'app-018'
                DisplayName = 'test-sp-already-expired'
                passwordCredentials = @(
                    [PSCustomObject]@{
                        KeyId = 'key-already-expired'
                        StartDateTime = $now.AddDays(-400).ToString('o')
                        EndDateTime = $now.AddDays(-5).ToString('o')
                    }
                )
                keyCredentials = @()
            }
            # Has recent sign-in so CRED-004 fires; CRED-005 should NOT fire for already-expired
            $signInByAppId = @{
                'app-018' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-30); DaysSinceSignIn = 30 }
            }
            $result = Invoke-NhiCredentialScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-005' }
            $f | Should -BeNullOrEmpty
            $f004 = $result | Where-Object { $_.FindingId -eq 'NHI-CRED-004' }
            $f004 | Should -Not -BeNullOrEmpty
        }
    }
}