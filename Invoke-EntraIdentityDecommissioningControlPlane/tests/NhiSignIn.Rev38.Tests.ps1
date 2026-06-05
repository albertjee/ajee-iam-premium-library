#Requires -Version 5.1

Describe 'NhiSignIn - NHI-SIGNIN-001 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiSignIn.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'SIGNIN-001 - Stale sign-in 90 days' {
        It 'Fires when DaysSinceSignIn = 90 with active credentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s01'; AppId = 'app-s01'; DisplayName = 'test-sp-90'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k1'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s01' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-90); DaysSinceSignIn = 90 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-001' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when DaysSinceSignIn = 179 with active credentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s02'; AppId = 'app-s02'; DisplayName = 'test-sp-179'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k2'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s02' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-179); DaysSinceSignIn = 179 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-001' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when DaysSinceSignIn = 89' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s03'; AppId = 'app-s03'; DisplayName = 'test-sp-89'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k3'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s03' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-89); DaysSinceSignIn = 89 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-001' }
            $f | Should -BeNullOrEmpty
        }

        It 'Does NOT fire when DaysSinceSignIn = 200 but SIGNIN-003 fires at >= 365' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s04'; AppId = 'app-s04'; DisplayName = 'test-sp-suppressed'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k4'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s04' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-400); DaysSinceSignIn = 400 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f001 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-001' }
            $f003 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-003' }
            $f001 | Should -BeNullOrEmpty
            $f003 | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'NhiSignIn - NHI-SIGNIN-002 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiSignIn.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'SIGNIN-002 - Stale sign-in 180 days' {
        It 'Fires when DaysSinceSignIn = 180 with active credentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s10'; AppId = 'app-s10'; DisplayName = 'test-sp-180'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k10'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s10' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-180); DaysSinceSignIn = 180 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-002' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when DaysSinceSignIn = 364 with active credentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s11'; AppId = 'app-s11'; DisplayName = 'test-sp-364'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k11'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s11' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-364); DaysSinceSignIn = 364 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-002' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when DaysSinceSignIn >= 365 (suppressed by 003)' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s12'; AppId = 'app-s12'; DisplayName = 'test-sp-365suppressed'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k12'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s12' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-400); DaysSinceSignIn = 400 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-002' }
            $f003 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-003' }
            $f002 | Should -BeNullOrEmpty
            $f003 | Should -Not -BeNullOrEmpty
        }

        It 'SIGNIN-002 suppresses SIGNIN-001 for same SP' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s13'; AppId = 'app-s13'; DisplayName = 'test-sp-180suppress'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k13'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s13' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-200); DaysSinceSignIn = 200 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f001 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-001' }
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-002' }
            $f001 | Should -BeNullOrEmpty
            $f002 | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'NhiSignIn - NHI-SIGNIN-003 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiSignIn.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'SIGNIN-003 - Stale sign-in 365+ days' {
        It 'Fires when DaysSinceSignIn = 365 with active credentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s20'; AppId = 'app-s20'; DisplayName = 'test-sp-365'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k20'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s20' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-365); DaysSinceSignIn = 365 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-003' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when DaysSinceSignIn = 400 with active credentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s21'; AppId = 'app-s21'; DisplayName = 'test-sp-400'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k21'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s21' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-400); DaysSinceSignIn = 400 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-003' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when sign-in record is absent AND SP has active credentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s22'; AppId = 'app-s22'; DisplayName = 'test-sp-no-signin'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k22'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            # No sign in data
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-003' }
            $f | Should -Not -BeNullOrEmpty
            $f.Confidence | Should -Be 'Medium'
        }

        It 'Does NOT fire when sign-in record absent and no active credentials' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s23'; AppId = 'app-s23'; DisplayName = 'test-sp-no-signin-nocred'
                OwnerCount = 1
                passwordCredentials = @()
                keyCredentials = @()
            }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId @{} -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-003' }
            $f | Should -BeNullOrEmpty
        }

        It 'SIGNIN-003 suppresses SIGNIN-001 and SIGNIN-002 for same SP' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s24'; AppId = 'app-s24'; DisplayName = 'test-sp-suppress-all'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k24'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s24' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-500); DaysSinceSignIn = 500 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f001 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-001' }
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-002' }
            $f003 = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-003' }
            $f001 | Should -BeNullOrEmpty
            $f002 | Should -BeNullOrEmpty
            $f003 | Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'NhiSignIn - NHI-SIGNIN-004 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiSignIn.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'SIGNIN-004 - Recent sign-in with no owner' {
        It 'Fires when DaysSinceSignIn < 30 AND OwnerCount = 0' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s30'; AppId = 'app-s30'; DisplayName = 'test-sp-recent-noowner'
                OwnerCount = 0
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k30'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s30' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-5); DaysSinceSignIn = 5 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-004' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when DaysSinceSignIn = 29 AND OwnerCount = 1' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s31'; AppId = 'app-s31'; DisplayName = 'test-sp-recent-withowner'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k31'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s31' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-29); DaysSinceSignIn = 29 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-004' }
            $f | Should -BeNullOrEmpty
        }
    }
}

Describe 'NhiSignIn - NHI-SIGNIN-005 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiSignIn.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'SIGNIN-005 - Recent sign-in with high-risk permission' {
        It 'Fires when DaysSinceSignIn < 30 AND HasHighRiskApplicationPermission = true' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s40'; AppId = 'app-s40'; DisplayName = 'test-sp-recent-highrisk'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k40'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s40' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-5); DaysSinceSignIn = 5 } }
            $permSummary = @{ 'sp-s40' = [PSCustomObject]@{ HasHighRiskApplicationPermission = $true; HighRiskPermissions = @('Directory.ReadWrite.All') } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId $permSummary
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-005' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when DaysSinceSignIn < 30 AND HasHighRiskApplicationPermission = false' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s41'; AppId = 'app-s41'; DisplayName = 'test-sp-recent-safe'
                OwnerCount = 1
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k41'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            $signInByAppId = @{ 'app-s41' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-5); DaysSinceSignIn = 5 } }
            $permSummary = @{ 'sp-s41' = [PSCustomObject]@{ HasHighRiskApplicationPermission = $false; HighRiskPermissions = @() } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId @{} -PermissionSummaryByObjectId $permSummary
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-005' }
            $f | Should -BeNullOrEmpty
        }
    }
}

Describe 'NhiSignIn - Lookup Order Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiSignIn.psm1') -Force -DisableNameChecking
        $now = Get-Date
    }

    Context 'SignInByServicePrincipalId lookup fallback' {
        It 'SignInByServicePrincipalId lookup works when AppId lookup returns nothing' {
            $sp = [PSCustomObject]@{
                Id = 'sp-s50'; AppId = 'app-s50'; DisplayName = 'test-sp-lookup-order'
                OwnerCount = 0
                passwordCredentials = @([PSCustomObject]@{ KeyId = 'k50'; EndDateTime = $now.AddDays(100).ToString('o') })
                keyCredentials = @()
            }
            # AppId lookup is empty, falls through to ServicePrincipalId
            $signInByAppId = @{}
            $signInByServicePrincipalId = @{ 'sp-s50' = [PSCustomObject]@{ LastSignInDate = $now.AddDays(-500); DaysSinceSignIn = 500 } }
            $result = Invoke-NhiSignInScan -ServicePrincipals @($sp) -SignInByAppId $signInByAppId -SignInByServicePrincipalId $signInByServicePrincipalId -PermissionSummaryByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-SIGNIN-003' }
            $f | Should -Not -BeNullOrEmpty
        }
    }
}