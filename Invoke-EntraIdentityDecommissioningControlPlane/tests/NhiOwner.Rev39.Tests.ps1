#Requires -Version 5.1

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiOwner.psm1'
    Import-Module $script:ModulePath -Force -DisableNameChecking
}

Describe 'NhiOwner.Rev39 - NHI-OWNER-001 through 006' {

    Context 'NHI-OWNER-001: No owner' {
        It 'fires when no owners and lookup succeeded' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @() }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-001' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'High'
            $f.RiskScore | Should -Be 65
        }

        It 'does NOT fire when OwnerLookupSucceeded is false' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $owner = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $ownersById = @{ 'sp-001' = @($owner) }
            # Global lookup failure (empty hashtable)
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId @{} -OwnerLookupSucceeded $false
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-001' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'NHI-OWNER-002: Single owner' {
        It 'fires when exactly 1 owner' {
            $owner = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($owner) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-002' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Medium'
            $f.RiskScore | Should -Be 30
        }

        It 'does NOT fire when 0 owners' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId @{ 'sp-001' = @() } -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-002' }
            $f | Should -BeNullOrEmpty
        }

        It 'does NOT fire when 2+ owners' {
            $owner1 = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $owner2 = [PSCustomObject]@{ Id = 'user-002'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($owner1, $owner2) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-002' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'NHI-OWNER-003: Lookup failure' {
        It 'fires when OwnerLookupSucceeded = false and has no owner data' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            # Empty hashtable = no data retrieved for anyone
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId @{} -OwnerLookupSucceeded $false
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-003' }
            $f | Should -Not -BeNullOrEmpty
            $f.Confidence | Should -Be 'Low'
            $f.ObjectType | Should -Be 'Assessment'
            $f.RiskScore | Should -Be 20
        }

        It 'does NOT fire when lookup succeeded' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $owner = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId @{ 'sp-001' = @($owner) } -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-003' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'NHI-OWNER-004: Guest owner' {
        It 'fires when any owner is Guest' {
            $guestOwner = [PSCustomObject]@{ Id = 'guest-001'; UserType = 'Guest'; AccountEnabled = $true; ObjectType = 'User' }
            $memberOwner = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($memberOwner, $guestOwner) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-004' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Medium'
            $f.RiskScore | Should -Be 35
        }

        It 'does NOT fire when all owners are Member' {
            $owner1 = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $owner2 = [PSCustomObject]@{ Id = 'user-002'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($owner1, $owner2) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-004' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'NHI-OWNER-005: Disabled owner' {
        It 'fires when any owner is disabled' {
            $enabledOwner = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $disabledOwner = [PSCustomObject]@{ Id = 'user-002'; UserType = 'Member'; AccountEnabled = $false; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($enabledOwner, $disabledOwner) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-005' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'High'
            $f.RiskScore | Should -Be 55
        }

        It 'does NOT fire when all owners are enabled' {
            $owner1 = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $owner2 = [PSCustomObject]@{ Id = 'user-002'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($owner1, $owner2) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-005' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'NHI-OWNER-006: All owners are service principals' {
        It 'fires when all owners are ServicePrincipal' {
            $spOwner = [PSCustomObject]@{ Id = 'sp-002'; UserType = $null; AccountEnabled = $true; ObjectType = 'ServicePrincipal' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($spOwner) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-006' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'High'
            $f.RiskScore | Should -Be 50
        }

        It 'does NOT fire when at least one human owner exists' {
            $spOwner = [PSCustomObject]@{ Id = 'sp-002'; UserType = $null; AccountEnabled = $true; ObjectType = 'ServicePrincipal' }
            $humanOwner = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($spOwner, $humanOwner) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-006' }
            $f | Should -BeNullOrEmpty
        }

        It 'does NOT fire when no owners (OWNER-001 fires instead)' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId @{ 'sp-001' = @() } -OwnerLookupSucceeded $true
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-006' }
            $f | Should -BeNullOrEmpty
        }
    }

    Context 'Mutual exclusivity rules' {
        It 'OWNER-001 and OWNER-002 are mutually exclusive' {
            # One owner case: only OWNER-002 fires
            $owner = [PSCustomObject]@{ Id = 'user-001'; UserType = 'Member'; AccountEnabled = $true; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($owner) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            $found001 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-001' }).Count
            $found002 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-002' }).Count
            $found001 | Should -Be 0
            $found002 | Should -Be 1
        }

        It 'OWNER-001 and OWNER-006 are mutually exclusive' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId @{ 'sp-001' = @() } -OwnerLookupSucceeded $true
            $found001 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-001' }).Count
            $found006 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-006' }).Count
            $found001 | Should -Be 1
            $found006 | Should -Be 0
        }

        It 'Multiple findings can coexist for same SP' {
            $guestOwner = [PSCustomObject]@{ Id = 'guest-001'; UserType = 'Guest'; AccountEnabled = $true; ObjectType = 'User' }
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $ownersById = @{ 'sp-001' = @($guestOwner) }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId $ownersById -OwnerLookupSucceeded $true
            # Single owner (OWNER-002) + guest owner (OWNER-004) coexist
            $found002 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-002' }).Count
            $found004 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-004' }).Count
            $found002 | Should -Be 1
            $found004 | Should -Be 1
        }
    }

    Context 'NHI-OWNER-003 suppression behavior' {
        It 'OWNER-003 emits exactly one assessment-level finding when owner lookup globally unavailable' {
            $sp1 = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp1'; AppId = 'app-001' }
            $sp2 = [PSCustomObject]@{ Id = 'sp-002'; DisplayName = 'test-sp2'; AppId = 'app-002' }
            # Global lookup failure - empty hashtable
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp1, $sp2) -OwnersByObjectId @{} -OwnerLookupSucceeded $false
            $f003 = $result | Where-Object { $_.FindingId -eq 'NHI-OWNER-003' }
            $f003.Count | Should -Be 1
            $f003[0].ObjectType | Should -Be 'Assessment'
            # No per-SP findings when owner data is completely unavailable
            ($result | Where-Object { $_.ObjectType -ne 'Assessment' -and $_.FindingId -eq 'NHI-OWNER-003' }).Count | Should -Be 0
        }

        It 'OWNER-003 suppresses OWNER-001 and OWNER-002 when lookup globally fails' {
            $sp = [PSCustomObject]@{ Id = 'sp-001'; DisplayName = 'test-sp'; AppId = 'app-001' }
            $result = Invoke-NhiOwnerScan -ServicePrincipals @($sp) -OwnersByObjectId @{} -OwnerLookupSucceeded $false
            $found001 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-001' }).Count
            $found002 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-002' }).Count
            $found003 = ($result | Where-Object { $_.FindingId -eq 'NHI-OWNER-003' }).Count
            $found001 | Should -Be 0
            $found002 | Should -Be 0
            $found003 | Should -Be 1
        }
    }
}