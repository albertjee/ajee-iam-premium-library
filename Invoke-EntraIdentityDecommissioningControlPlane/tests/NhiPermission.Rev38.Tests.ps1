#Requires -Version 5.1

Describe 'NhiPermission - NHI-PERM-001 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiPermission.psm1') -Force -DisableNameChecking
    }

    Context 'Permission unit counting thresholds' {
        It 'Fires when permission units >= 10 (PERM-001)' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm01'; DisplayName = 'sp-perms'; AppId = 'app-perm01' }
            # 10 AppRoleAssignments = 10 permission units
            $aras = 0..9 | ForEach-Object {
                [PSCustomObject]@{ PrincipalId = 'sp-perm01'; AppRoleId = 'role-q'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'Member'; ResolutionStatus = 'Resolved' }
            }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-001' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when permission units = 9 (PERM-001 boundary)' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm02'; DisplayName = 'sp-perms2'; AppId = 'app-perm02' }
            $aras = 0..8 | ForEach-Object {
                [PSCustomObject]@{ PrincipalId = 'sp-perm02'; AppRoleId = 'role-q'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'Member'; ResolutionStatus = 'Resolved' }
            }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-001' }
            $f | Should -BeNullOrEmpty
        }

        It 'Boundary at exactly 10 units for PERM-001' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm03'; DisplayName = 'sp-perms3'; AppId = 'app-perm03' }
            $aras = 0..9 | ForEach-Object {
                [PSCustomObject]@{ PrincipalId = 'sp-perm03'; AppRoleId = 'role-q'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'Member'; ResolutionStatus = 'Resolved' }
            }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f001 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-001' }
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-002' }
            $f001 | Should -Not -BeNullOrEmpty
            $f002 | Should -BeNullOrEmpty
        }
    }
}

Describe 'NhiPermission - NHI-PERM-002 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiPermission.psm1') -Force -DisableNameChecking
    }

    Context 'Moderate permission count (5-9 units)' {
        It 'Fires when permission units = 5' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm10'; DisplayName = 'sp-perms10'; AppId = 'app-perm10' }
            $aras = 0..4 | ForEach-Object {
                [PSCustomObject]@{ PrincipalId = 'sp-perm10'; AppRoleId = 'role-q'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'Member'; ResolutionStatus = 'Resolved' }
            }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-002' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when permission units = 9' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm11'; DisplayName = 'sp-perms11'; AppId = 'app-perm11' }
            $aras = 0..8 | ForEach-Object {
                [PSCustomObject]@{ PrincipalId = 'sp-perm11'; AppRoleId = 'role-q'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'Member'; ResolutionStatus = 'Resolved' }
            }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-002' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when permission units = 4' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm12'; DisplayName = 'sp-perms12'; AppId = 'app-perm12' }
            $aras = 0..3 | ForEach-Object {
                [PSCustomObject]@{ PrincipalId = 'sp-perm12'; AppRoleId = 'role-q'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'Member'; ResolutionStatus = 'Resolved' }
            }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-002' }
            $f001 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-001' }
            $f002 | Should -BeNullOrEmpty
            $f001 | Should -BeNullOrEmpty
        }

        It 'Does NOT fire when permission units >= 10 (PERM-001 takes over)' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm13'; DisplayName = 'sp-perms13'; AppId = 'app-perm13' }
            $aras = 0..9 | ForEach-Object {
                [PSCustomObject]@{ PrincipalId = 'sp-perm13'; AppRoleId = 'role-q'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'Member'; ResolutionStatus = 'Resolved' }
            }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-002' }
            $f001 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-001' }
            $f002 | Should -BeNullOrEmpty
            $f001 | Should -Not -BeNullOrEmpty
        }

        It 'Boundary at exactly 5 units for PERM-002' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm14'; DisplayName = 'sp-perms14'; AppId = 'app-perm14' }
            $aras = @(0,1,2,3,4) | ForEach-Object {
                [PSCustomObject]@{ PrincipalId = 'sp-perm14'; AppRoleId = 'role-q'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'Member'; ResolutionStatus = 'Resolved' }
            }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-002' }
            $f001 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-001' }
            $f002 | Should -Not -BeNullOrEmpty
            $f001 | Should -BeNullOrEmpty
        }
    }
}

Describe 'NhiPermission - NHI-PERM-003 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiPermission.psm1') -Force -DisableNameChecking
    }

    Context 'High-risk app role detection' {
        It 'Fires for Directory.ReadWrite.All (high-risk app role)' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm20'; DisplayName = 'sp-perms20'; AppId = 'app-perm20' }
            $aras = @([PSCustomObject]@{
                PrincipalId = 'sp-perm20'; AppRoleId = 'some-guid'; PrincipalDisplayName = 'SP'
                ResolvedRoleValue = 'Directory.ReadWrite.All'
                ResourceDisplayName = 'Microsoft Graph'
                ResolutionStatus = 'Resolved'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-003' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'High'
        }

        It 'Fires for User.ReadWrite.All as second distinct high-risk role' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm21'; DisplayName = 'sp-perms21'; AppId = 'app-perm21' }
            $aras = @([PSCustomObject]@{
                PrincipalId = 'sp-perm21'; AppRoleId = 'some-guid'; PrincipalDisplayName = 'SP'
                ResolvedRoleValue = 'User.ReadWrite.All'
                ResourceDisplayName = 'Microsoft Graph'
                ResolutionStatus = 'Resolved'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-003' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire for non-high-risk role' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm22'; DisplayName = 'sp-perms22'; AppId = 'app-perm22' }
            $aras = @([PSCustomObject]@{
                PrincipalId = 'sp-perm22'; AppRoleId = 'some-guid'; PrincipalDisplayName = 'SP'
                ResolvedRoleValue = 'User.Read'
                ResourceDisplayName = 'Microsoft Graph'
                ResolutionStatus = 'Resolved'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-003' }
            $f | Should -BeNullOrEmpty
        }

        It 'Does NOT fire when ResolutionStatus = Unresolved' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm23'; DisplayName = 'sp-perms23'; AppId = 'app-perm23' }
            $aras = @([PSCustomObject]@{
                PrincipalId = 'sp-perm23'; AppRoleId = 'some-guid'; PrincipalDisplayName = 'SP'
                ResolvedRoleValue = 'Directory.ReadWrite.All'
                ResourceDisplayName = 'Microsoft Graph'
                ResolutionStatus = 'Unresolved'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-003' }
            $f | Should -BeNullOrEmpty
        }
    }
}

Describe 'NhiPermission - NHI-PERM-004 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiPermission.psm1') -Force -DisableNameChecking
    }

    Context 'High-risk delegated scope detection' {
        It 'Fires when scope token exactly matches high-risk scope' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm30'; DisplayName = 'sp-perms30'; AppId = 'app-perm30' }
            $grants = @([PSCustomObject]@{
                ClientId = 'sp-perm30'; ConsentType = 'Principal'; Scope = 'Directory.ReadWrite.All User.Read'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants $grants
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-004' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire on substring match (Mail.Read does not match Mail.ReadWrite)' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm31'; DisplayName = 'sp-perms31'; AppId = 'app-perm31' }
            $grants = @([PSCustomObject]@{
                ClientId = 'sp-perm31'; ConsentType = 'Principal'; Scope = 'Mail.Read'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants $grants
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-004' }
            $f | Should -BeNullOrEmpty
        }

        It 'Fires for each matching token when grant has multiple scopes' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm32'; DisplayName = 'sp-perms32'; AppId = 'app-perm32' }
            $grants = @([PSCustomObject]@{
                ClientId = 'sp-perm32'; ConsentType = 'Principal'; Scope = 'Directory.ReadWrite.All Mail.ReadWrite'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants $grants
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-004' }
            $f.Count | Should -Be 2
        }
    }
}

Describe 'NhiPermission - NHI-PERM-005 and PERM-006 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiPermission.psm1') -Force -DisableNameChecking
    }

    Context 'AllPrincipals consent detection' {
        It 'Fires when ConsentType = AllPrincipals (PERM-005)' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm40'; DisplayName = 'sp-perms40'; AppId = 'app-perm40' }
            $grants = @([PSCustomObject]@{
                ClientId = 'sp-perm40'; ConsentType = 'AllPrincipals'; Scope = 'User.Read'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants $grants
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-005' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when ConsentType = Principal (PERM-005)' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm41'; DisplayName = 'sp-perms41'; AppId = 'app-perm41' }
            $grants = @([PSCustomObject]@{
                ClientId = 'sp-perm41'; ConsentType = 'Principal'; Scope = 'User.Read'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants $grants
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-005' }
            $f | Should -BeNullOrEmpty
        }

        It 'Fires when AllPrincipals AND high-risk scope both present (PERM-006)' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm42'; DisplayName = 'sp-perms42'; AppId = 'app-perm42' }
            $grants = @([PSCustomObject]@{
                ClientId = 'sp-perm42'; ConsentType = 'AllPrincipals'; Scope = 'Directory.ReadWrite.All'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants $grants
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-006' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Critical'
        }

        It 'Does NOT fire PERM-006 when AllPrincipals but no high-risk scope' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm43'; DisplayName = 'sp-perms43'; AppId = 'app-perm43' }
            $grants = @([PSCustomObject]@{
                ClientId = 'sp-perm43'; ConsentType = 'AllPrincipals'; Scope = 'User.Read'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants $grants
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-006' }
            $f | Should -BeNullOrEmpty
        }
    }
}

Describe 'NhiPermission - NHI-PERM-007 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiPermission.psm1') -Force -DisableNameChecking
    }

    Context 'App role lookup failure detection' {
        It 'Fires when AppRoleLookupSucceeded = false' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm50'; DisplayName = 'sp-perms50'; AppId = 'app-perm50' }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants @() -AppRoleLookupSucceeded $false -AppRoleLookupError 'Insufficient privileges'
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-007' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Medium'
            $f.Confidence | Should -Be 'Low'
        }

        It 'Does NOT fire when AppRoleLookupSucceeded = true' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm51'; DisplayName = 'sp-perms51'; AppId = 'app-perm51' }
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants @() -AppRoleLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-007' }
            $f | Should -BeNullOrEmpty
        }
    }
}

Describe 'NhiPermission - NHI-PERM-008 Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiPermission.psm1') -Force -DisableNameChecking
    }

    Context 'Unresolved or stale app role assignments' {
        It 'Fires when ResolutionStatus = Unresolved' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm60'; DisplayName = 'sp-perms60'; AppId = 'app-perm60' }
            $aras = @([PSCustomObject]@{
                PrincipalId = 'sp-perm60'; AppRoleId = 'role-x'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = $null; ResolutionStatus = 'Unresolved'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-008' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Fires when ResolvedRoleValue is empty' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm61'; DisplayName = 'sp-perms61'; AppId = 'app-perm61' }
            $aras = @([PSCustomObject]@{
                PrincipalId = 'sp-perm61'; AppRoleId = 'role-x'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = ''; ResolutionStatus = 'Resolved'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-008' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'Does NOT fire when ResolutionStatus = Resolved and role is present' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm62'; DisplayName = 'sp-perms62'; AppId = 'app-perm62' }
            $aras = @([PSCustomObject]@{
                PrincipalId = 'sp-perm62'; AppRoleId = 'role-x'; PrincipalDisplayName = 'SP'; ResolvedRoleValue = 'User.Read'; ResolutionStatus = 'Resolved'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments $aras -OAuthGrants @()
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-008' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'Trace context isolation for late permission findings' {
        It 'PERM-007 and PERM-008 do not inherit stale platform metadata from the last service principal' {
            $plainSp = [PSCustomObject]@{
                Id = 'sp-perm-trace-plain'
                DisplayName = 'Contoso App'
                AppId = 'app-perm-trace-plain'
                MicrosoftPlatform = $false
                MicrosoftFirstParty = $false
                FirstPartyMicrosoftApp = $false
                EvidenceOnly = $false
            }

            $platformSp = [PSCustomObject]@{
                Id = 'sp-perm-trace-platform'
                DisplayName = 'Microsoft Graph'
                AppId = 'app-perm-trace-platform'
                MicrosoftPlatform = $true
                MicrosoftFirstParty = $true
                FirstPartyMicrosoftApp = $true
                EvidenceOnly = $true
                SuppressCustomerRemediation = $true
                Classification = 'MicrosoftPlatform'
            }

            $aras = @([PSCustomObject]@{
                PrincipalId = $plainSp.Id
                PrincipalDisplayName = $plainSp.DisplayName
                AppRoleId = 'role-x'
                ResolvedRoleValue = 'User.Read'
                ResolutionStatus = 'Unresolved'
            })

            $result = Invoke-NhiPermissionScan -ServicePrincipals @($plainSp, $platformSp) -AppRoleAssignments $aras -OAuthGrants @() -AppRoleLookupSucceeded $false

            $perm007 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-007' -and $_.ObjectId -eq $plainSp.Id }
            $perm008 = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-008' -and $_.ObjectId -eq $plainSp.Id }

            $perm007.MicrosoftPlatform | Should -Be $false
            $perm007.FirstPartyMicrosoftApp | Should -Be $false
            $perm007.MicrosoftFirstParty | Should -Be $false
            $perm007.EvidenceOnly | Should -Be $false
            $perm007.SuppressCustomerRemediation | Should -Be $false

            $perm008.MicrosoftPlatform | Should -Be $false
            $perm008.FirstPartyMicrosoftApp | Should -Be $false
            $perm008.MicrosoftFirstParty | Should -Be $false
            $perm008.EvidenceOnly | Should -Be $false
            $perm008.SuppressCustomerRemediation | Should -Be $false
        }
    }
}

Describe 'NhiPermission - Override Parameter Tests' {
    BeforeAll {
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\NhiPermission.psm1') -Force -DisableNameChecking
    }

    Context 'Override parameters replace built-in list' {
        It 'Override non-empty list replaces built-in high-risk list' {
            $sp = [PSCustomObject]@{ Id = 'sp-perm70'; DisplayName = 'sp-perms70'; AppId = 'app-perm70' }
            # User.Read is not in the default list, but we override to make it high-risk
            $grants = @([PSCustomObject]@{
                ClientId = 'sp-perm70'; ConsentType = 'Principal'; Scope = 'User.Read'
            })
            $result = Invoke-NhiPermissionScan -ServicePrincipals @($sp) -AppRoleAssignments @() -OAuthGrants $grants `
                -HighRiskDelegatedScopesOverride @('User.Read')
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-PERM-004' }
            $f | Should -Not -BeNullOrEmpty
        }
    }
}
