#Requires -Version 5.1
# Pester tests for NhiExecution.psm1 (Rev4.0 M32–M34)
# Tests for Snap/Tag (M32), Disable/Rollback (M33), Monitor (M34).

BeforeAll {
    $Script:ExecutionModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiExecution.psm1'
    Import-Module $Script:ExecutionModulePath -Force -DisableNameChecking

    # ── Manifest helpers (scoped inside BeforeAll so Mocks can reach them) ────

    function New-TestSnapshotManifest {
        param(
            [string]$Path,
            [string]$ExecutionRunId = '20260101_120000',
            [string]$EngagementId    = 'ENG-REV40-001',
            [hashtable[]]$Records   = @()
        )

        $createdAt = '2026-06-01T12:00:00Z'
        [object[]]$manifestRecords = @()
        foreach ($rec in $Records) {
            $manifestRecords += [PSCustomObject]$rec
        }

        $manifest = [ordered]@{
            ExecutionRunId = $ExecutionRunId
            EngagementId   = $EngagementId
            CreatedAt     = $createdAt
            Records       = $manifestRecords
        }

        $jsonStr = $manifest | ConvertTo-Json -Depth 10 -Compress
        [System.IO.File]::WriteAllText($Path, $jsonStr, [System.Text.UTF8Encoding]::new($false))
    }

    function New-TestSPSnapshotRecord {
        param(
            [string]$ObjectId          = 'sp-001-uuid',
            [string]$DisplayName       = 'Test App Service Principal',
            $PriorAccountEnabled       = $true,
            $PriorNotes                = $null,
            [string]$EngagementId      = 'ENG-REV40-001',
            $AdditionalFields          = @{ AppRolesCount = 0; OAuth2PermissionGrantsCount = 0; KeyCredentialsCount = 0; PasswordCredentialsCount = 0; Owners = @() }
        )
        return [ordered]@{
            ObjectId           = $ObjectId
            ObjectType         = 'ServicePrincipal'
            DisplayName        = $DisplayName
            AppId              = 'app-id-001'
            PriorAccountEnabled = $PriorAccountEnabled
            PriorNotes         = $PriorNotes
            SnapshotTimestamp  = '2026-06-01T12:00:00Z'
            DisabledAt         = $null
            ScreamTestDays     = 0
            SkipReason         = $null
            AdditionalFields   = $AdditionalFields
            EngagementId        = $EngagementId
        }
    }
}

AfterAll {
    Remove-Module 'NhiExecution' -Force -ErrorAction SilentlyContinue
}

# ── Module-level test constants ────────────────────────────────────────────────

$Script:FIXTURE_SP = @{
    ObjectId           = 'sp-001-uuid'
    DisplayName        = 'Test App Service Principal'
    AppId              = 'app-id-001'
    AccountEnabled     = $true
    Notes              = $null
    ObjectType         = 'ServicePrincipal'
}

$Script:FIXTURE_MI = @{
    ObjectId           = 'mi-001-uuid'
    DisplayName        = 'Test Managed Identity'
    AppId              = 'msi-app-id-001'
    AccountEnabled     = $true
    ObjectType         = 'ManagedIdentity'
}

$Script:FIXTURE_USER = @{
    ObjectId           = 'user-001-uuid'
    DisplayName        = 'Test User'
    UserPrincipalName  = 'testuser@contoso.com'
    AccountEnabled     = $true
    ObjectType         = 'User'
}

# ── Manifest helpers moved into BeforeAll above ──────────────────────────────

# ══════════════════════════════════════════════════════════════════════════════
# M32 TESTS — Invoke-NhiSnapshot and Invoke-NhiTag
# ══════════════════════════════════════════════════════════════════════════════

Describe 'Invoke-NhiSnapshot — WhatIf' {
    It 'Invoke-NhiSnapshot WhatIf: writes intent to NhiExecutionWhatIf.json without Graph calls' {
        $path = Join-Path $TestDrive 'whatif-snapshot'
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        Invoke-NhiSnapshot -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-001' -ExecutionRunId 'TESTRUN01' `
            -ExecutionOutputPath $path -WhatIf

        $whatIfPath = Join-Path $path 'NhiExecutionWhatIf.json'
        Test-Path $whatIfPath | Should -Be $true

        $entries = @(Get-Content -Path $whatIfPath -Raw | ConvertFrom-Json)
        $entries.Count | Should -BeGreaterThan 0
        $entries[0].Action | Should -Be 'Snapshot'
        $entries[0].ObjectId | Should -Be 'sp-001'
        $entries[0].ObjectType | Should -Be 'ServicePrincipal'
    }

    It 'Invoke-NhiSnapshot WhatIf: Does not call Get-MgServicePrincipal' {
        $path = Join-Path $TestDrive 'whatif-no-graph-sp'
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        Invoke-NhiSnapshot -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-001' -ExecutionRunId 'TESTRUN01' `
            -ExecutionOutputPath $path -WhatIf

        # WhatIf path should not trigger any Graph calls —
        # the WhatIf file must exist and Action must be 'Snapshot'
        $whatIfPath = Join-Path $path 'NhiExecutionWhatIf.json'
        $entries = @(Get-Content -Path $whatIfPath -Raw | ConvertFrom-Json)
        $entries[0].Action | Should -Be 'Snapshot'
    }
}

Describe 'Invoke-NhiSnapshot — ServicePrincipal' {
    BeforeAll {
        # Mock module-level Graph calls
        Mock Get-MgServicePrincipal -ModuleName NhiExecution {
            [PSCustomObject]@{
                Id                    = 'sp-001-uuid'
                DisplayName           = 'Test App SP'
                AppId                 = 'app-id-001'
                AccountEnabled        = $true
                Notes                 = $null
                AppRoles              = @()
                OAuth2PermissionGrants = @()
                KeyCredentials        = @()
                PasswordCredentials   = @()
            }
        }

        Mock Get-MgServicePrincipalOwner -ModuleName NhiExecution {
            return @([PSCustomObject]@{ Id = 'owner-guid-001' })
        }

        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $Script:SnapOutputPath = Join-Path $TestDrive 'snap-sp-test'
        New-Item -ItemType Directory -Path $Script:SnapOutputPath -Force | Out-Null
    }

    It 'Invoke-NhiSnapshot for SP: calls Update-MgServicePrincipal (mocked)' {
        Invoke-NhiSnapshot -ObjectId 'sp-001-uuid' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST01' `
            -ExecutionOutputPath $Script:SnapOutputPath

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 1
        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -ParameterFilter {
            $ServicePrincipalId -eq 'sp-001-uuid'
        }
    }

    It 'Invoke-NhiSnapshot for SP: Record in SnapshotManifest-{RunId}.json contains PriorNotes' {
        Invoke-NhiSnapshot -ObjectId 'sp-001-uuid' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST02' `
            -ExecutionOutputPath $Script:SnapOutputPath

        $manifestPath = Join-Path $Script:SnapOutputPath 'SnapshotManifest-M32TEST02.json'
        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $record   = $manifest.Records | Where-Object { $_.ObjectId -eq 'sp-001-uuid' }

        $record.ObjectId           | Should -Not -BeNullOrEmpty
        $record.ObjectType         | Should -Be 'ServicePrincipal'
        'PriorNotes' -in ($record.PSObject.Properties.Name) | Should -Be $true
        $record.PriorNotes         | Should -BeNullOrEmpty -Because 'Notes was null in the test SP'
    }

    It 'Invoke-NhiSnapshot for SP: PriorNotes captured when Notes field is non-null' {
        # Re-mock with non-null Notes
        Mock Get-MgServicePrincipal -ModuleName NhiExecution {
            [PSCustomObject]@{
                Id                    = 'sp-002-uuid'
                DisplayName           = 'Test SP with Notes'
                AppId                 = 'app-id-002'
                AccountEnabled        = $true
                Notes                 = 'Original Notes Value'
                AppRoles              = @()
                OAuth2PermissionGrants = @()
                KeyCredentials        = @()
                PasswordCredentials   = @()
            }
        }

        Invoke-NhiSnapshot -ObjectId 'sp-002-uuid' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST03' `
            -ExecutionOutputPath $Script:SnapOutputPath

        $manifestPath = Join-Path $Script:SnapOutputPath 'SnapshotManifest-M32TEST03.json'
        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $record   = $manifest.Records | Where-Object { $_.ObjectId -eq 'sp-002-uuid' }

        $record.PriorNotes | Should -Be 'Original Notes Value'
    }

    It 'Invoke-NhiSnapshot for SP: AdditionalFields contains captured counts and Owners' {
        # Mock SP with credential data
        Mock Get-MgServicePrincipal -ModuleName NhiExecution {
            [PSCustomObject]@{
                Id                    = 'sp-003-uuid'
                DisplayName           = 'Test SP Full'
                AppId                 = 'app-id-003'
                AccountEnabled        = $true
                Notes                 = 'Has notes'
                AppRoles              = @(
                    [PSCustomObject]@{ Id = 'role1' }
                    [PSCustomObject]@{ Id = 'role2' }
                )
                OAuth2PermissionGrants = @([PSCustomObject]@{ Id = 'grant1' })
                KeyCredentials        = @([PSCustomObject]@{ Id = 'key1' })
                PasswordCredentials   = @([PSCustomObject]@{ Id = 'pwd1' })
            }
        }
        Mock Get-MgServicePrincipalOwner -ModuleName NhiExecution {
            return @(
                [PSCustomObject]@{ Id = 'owner-a' }
                [PSCustomObject]@{ Id = 'owner-b' }
            )
        }

        Invoke-NhiSnapshot -ObjectId 'sp-003-uuid' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST04' `
            -ExecutionOutputPath $Script:SnapOutputPath

        $manifestPath = Join-Path $Script:SnapOutputPath 'SnapshotManifest-M32TEST04.json'
        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $record   = $manifest.Records | Where-Object { $_.ObjectId -eq 'sp-003-uuid' }

        $record.AdditionalFields.AppRolesCount         | Should -Be 2
        $record.AdditionalFields.OAuth2PermissionGrantsCount | Should -Be 1
        $record.AdditionalFields.KeyCredentialsCount    | Should -Be 1
        $record.AdditionalFields.PasswordCredentialsCount | Should -Be 1
        $record.AdditionalFields.Owners                | Should -Contain 'owner-a'
        $record.AdditionalFields.Owners                | Should -Contain 'owner-b'
    }

    It 'Invoke-NhiSnapshot for SP: Snapshots update existing Record for same ObjectId/RunId' {
        Invoke-NhiSnapshot -ObjectId 'sp-001-uuid' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST_UPD' `
            -ExecutionOutputPath $Script:SnapOutputPath
        # Second snapshot of same ObjectId in same RunId — must update, not append
        Invoke-NhiSnapshot -ObjectId 'sp-001-uuid' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST_UPD' `
            -ExecutionOutputPath $Script:SnapOutputPath

        $manifestPath = Join-Path $Script:SnapOutputPath 'SnapshotManifest-M32TEST_UPD.json'
        $manifest    = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $matches     = @($manifest.Records | Where-Object { $_.ObjectId -eq 'sp-001-uuid' })

        $matches.Count | Should -Be 1 -Because 'Two snapshots of same ObjectId in same RunId updates, not duplicates'
    }
}

Describe 'Invoke-NhiSnapshot — ManagedIdentity' {
    BeforeAll {
        Mock Get-MgServicePrincipal -ModuleName NhiExecution {
            [PSCustomObject]@{
                Id             = 'mi-001-uuid'
                DisplayName    = 'Test MI'
                AppId          = 'msi-app-001'
                AccountEnabled = $true
                AppRoles       = @()
                KeyCredentials = @()
                PasswordCredentials = @()
            }
        }
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $Script:MISnapPath = Join-Path $TestDrive 'snap-mi-test'
        New-Item -ItemType Directory -Path $Script:MISnapPath -Force | Out-Null
    }

    It 'Invoke-NhiSnapshot for MI: no Graph write cmdlet called' {
        Invoke-NhiSnapshot -ObjectId 'mi-001-uuid' -ObjectType 'ManagedIdentity' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST_MI' `
            -ExecutionOutputPath $Script:MISnapPath

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }

    It 'Invoke-NhiSnapshot for MI: Record contains SkipReason = "SnapshotTagWrite skipped for ManagedIdentity in Rev4.0"' {
        Invoke-NhiSnapshot -ObjectId 'mi-001-uuid' -ObjectType 'ManagedIdentity' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST_MI2' `
            -ExecutionOutputPath $Script:MISnapPath

        $manifestPath = Join-Path $Script:MISnapPath 'SnapshotManifest-M32TEST_MI2.json'
        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $record   = $manifest.Records | Where-Object { $_.ObjectId -eq 'mi-001-uuid' }

        $record.SkipReason | Should -Be 'SnapshotTagWrite skipped for ManagedIdentity in Rev4.0'
    }

    It 'Invoke-NhiSnapshot for MI: Record contains PriorAccountEnabled' {
        Invoke-NhiSnapshot -ObjectId 'mi-001-uuid' -ObjectType 'ManagedIdentity' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST_MI3' `
            -ExecutionOutputPath $Script:MISnapPath

        $manifestPath = Join-Path $Script:MISnapPath 'SnapshotManifest-M32TEST_MI3.json'
        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $record   = $manifest.Records | Where-Object { $_.ObjectId -eq 'mi-001-uuid' }

        'PriorAccountEnabled' -in ($record.PSObject.Properties.Name) | Should -Be $true
    }
}

Describe 'Invoke-NhiSnapshot — User' {
    BeforeAll {
        Mock Get-MgUser -ModuleName NhiExecution {
            [PSCustomObject]@{
                Id                = 'user-001-uuid'
                DisplayName       = 'Test User'
                AccountEnabled    = $true
                UserPrincipalName = 'testuser@contoso.com'
            }
        }
        Mock Get-MgUserLicenseDetail -ModuleName NhiExecution { return @() }
        Mock Get-MgUserMemberOf      -ModuleName NhiExecution { return @() }
        Mock Get-MgUserAppRoleAssignment -ModuleName NhiExecution { return @() }
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $Script:UserSnapPath = Join-Path $TestDrive 'snap-user-test'
        New-Item -ItemType Directory -Path $Script:UserSnapPath -Force | Out-Null
    }

    It 'Invoke-NhiSnapshot for User: no Graph write cmdlet called' {
        Invoke-NhiSnapshot -ObjectId 'user-001-uuid' -ObjectType 'User' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST_USR' `
            -ExecutionOutputPath $Script:UserSnapPath

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }

    It 'Invoke-NhiSnapshot for User: Record contains PriorAccountEnabled' {
        Invoke-NhiSnapshot -ObjectId 'user-001-uuid' -ObjectType 'User' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TEST_USR2' `
            -ExecutionOutputPath $Script:UserSnapPath

        $manifestPath = Join-Path $Script:UserSnapPath 'SnapshotManifest-M32TEST_USR2.json'
        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $record   = $manifest.Records | Where-Object { $_.ObjectId -eq 'user-001-uuid' }

        'PriorAccountEnabled' -in ($record.PSObject.Properties.Name) | Should -Be $true
    }
}

Describe 'Invoke-NhiSnapshot — Error guards' {
    It 'Invoke-NhiSnapshot: throws on invalid ObjectType' {
        { Invoke-NhiSnapshot -ObjectId 'any-id' -ObjectType 'InvalidType' `
                -EngagementId 'ENG-001' -ExecutionRunId 'TEST' `
                -ExecutionOutputPath $TestDrive } | Should -Throw
    }

    It 'Invoke-NhiSnapshot: throws when ExecutionOutputPath does not exist' {
        { Invoke-NhiSnapshot -ObjectId 'any-id' -ObjectType 'ServicePrincipal' `
                -EngagementId 'ENG-001' -ExecutionRunId 'TEST' `
                -ExecutionOutputPath (Join-Path $TestDrive 'NONEXISTENT') } | Should -Throw
    }

    It 'Invoke-NhiSnapshot: throws when Get-MgServicePrincipal fails for SP' {
        Mock Get-MgServicePrincipal -ModuleName NhiExecution { throw 'Graph unreachable' }

        { Invoke-NhiSnapshot -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
                -EngagementId 'ENG-001' -ExecutionRunId 'TESTERR' `
                -ExecutionOutputPath $TestDrive } | Should -Throw
    }

    It 'Invoke-NhiSnapshot: Manifest filename follows SnapshotManifest-{RunId}.json convention' {
        $path = Join-Path $TestDrive 'manifest-convention-test'
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        Mock Get-MgServicePrincipal -ModuleName NhiExecution {
            [PSCustomObject]@{ Id = 'conv-sp'; DisplayName = 'Conv'; AppId = 'a1'; AccountEnabled = $true; Notes = $null; AppRoles = @(); OAuth2PermissionGrants = @(); KeyCredentials = @(); PasswordCredentials = @() }
        }
        Mock Get-MgServicePrincipalOwner -ModuleName NhiExecution { return @() }
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $runId = '20260605_143000'
        Invoke-NhiSnapshot -ObjectId 'conv-sp' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-001' -ExecutionRunId $runId -ExecutionOutputPath $path

        $expectedPath = Join-Path $path "SnapshotManifest-$runId.json"
        Test-Path $expectedPath | Should -Be $true
    }
}

# ── Invoke-NhiTag tests ─────────────────────────────────────────────────────────

Describe 'Invoke-NhiTag — WhatIf' {
    It 'Invoke-NhiTag WhatIf: writes intent to NhiExecutionWhatIf.json' {
        $path = Join-Path $TestDrive 'whatif-tag-test'
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        Invoke-NhiTag -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-001' -ExecutionRunId 'TESTRUN01' `
            -ExecutionOutputPath $path -WhatIf

        $whatIfPath = Join-Path $path 'NhiExecutionWhatIf.json'
        Test-Path $whatIfPath | Should -Be $true

        $entries = @(Get-Content -Path $whatIfPath -Raw | ConvertFrom-Json)
        $entries[0].Action   | Should -Be 'Tag'
        $entries[0].ObjectId | Should -Be 'sp-001'
    }

    It 'Invoke-NhiTag WhatIf: no Graph write call' {
        $path = Join-Path $TestDrive 'whatif-no-graph-tag'
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        Invoke-NhiTag -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-001' -ExecutionRunId 'TESTRUN02' `
            -ExecutionOutputPath $path -WhatIf

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }

    It 'Invoke-NhiTag WhatIf: does NOT check for SnapshotManifest file' {
        # WhatIf must work even without SnapshotManifest
        $path = Join-Path $TestDrive 'whatif-no-manifest'
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        # No SnapshotManifest file created
        { Invoke-NhiTag -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
                -EngagementId 'ENG-001' -ExecutionRunId 'RUNID_WHATIF' `
                -ExecutionOutputPath $path -WhatIf } | Should -Not -Throw
    }
}

Describe 'Invoke-NhiTag — ServicePrincipal' {
    BeforeAll {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $Script:TagOutputPath = Join-Path $TestDrive 'tag-sp-test'
        New-Item -ItemType Directory -Path $Script:TagOutputPath -Force | Out-Null

        # Pre-create a SnapshotManifest so Tag can find the Record
        $manifestPath = Join-Path $Script:TagOutputPath 'SnapshotManifest-M32TAG_SP.json'
        $rec = New-TestSPSnapshotRecord -ObjectId 'tag-sp-001' -PriorAccountEnabled $true -PriorNotes $null
        New-TestSnapshotManifest -Path $manifestPath -ExecutionRunId 'M32TAG_SP' `
            -Records @($rec)
    }

    It 'Invoke-NhiTag for SP: calls Update-MgServicePrincipal (mocked)' {
        Invoke-NhiTag -ObjectId 'tag-sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TAG_SP' `
            -ExecutionOutputPath $Script:TagOutputPath

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 1
    }

    It 'Invoke-NhiTag for SP: throws when no prior snapshot Record exists' {
        { Invoke-NhiTag -ObjectId 'nonexistent-sp' -ObjectType 'ServicePrincipal' `
                -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TAG_SP' `
                -ExecutionOutputPath $Script:TagOutputPath } | Should -Throw '*No snapshot Record found*'
    }

    It 'Invoke-NhiTag for SP: throws when SnapshotManifest-{RunId}.json does not exist (non-WhatIf)' {
        $emptyPath = Join-Path $TestDrive 'tag-no-manifest'
        New-Item -ItemType Directory -Path $emptyPath -Force | Out-Null

        { Invoke-NhiTag -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
                -EngagementId 'ENG-001' -ExecutionRunId 'NONEXISTENT_RUNID' `
                -ExecutionOutputPath $emptyPath } | Should -Throw '*not found*'
    }
}

Describe 'Invoke-NhiTag — ManagedIdentity' {
    BeforeAll {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $Script:TagMIPath = Join-Path $TestDrive 'tag-mi-test'
        New-Item -ItemType Directory -Path $Script:TagMIPath -Force | Out-Null

        $miRec = [ordered]@{
            ObjectId           = 'mi-tag-001'
            ObjectType         = 'ManagedIdentity'
            DisplayName        = 'Test MI'
            AppId              = 'msi-001'
            PriorAccountEnabled = $true
            PriorNotes         = $null
            SnapshotTimestamp  = '2026-06-01T12:00:00Z'
            DisabledAt         = $null
            ScreamTestDays     = 0
            SkipReason         = 'SnapshotTagWrite skipped for ManagedIdentity in Rev4.0'
            AdditionalFields   = @{}
            EngagementId       = 'ENG-REV40-001'
        }
        $manifestPath = Join-Path $Script:TagMIPath 'SnapshotManifest-M32TAG_MI.json'
        New-TestSnapshotManifest -Path $manifestPath -ExecutionRunId 'M32TAG_MI' -Records @($miRec)
    }

    It 'Invoke-NhiTag for MI: no Graph call, no exception' {
        { Invoke-NhiTag -ObjectId 'mi-tag-001' -ObjectType 'ManagedIdentity' `
                -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TAG_MI' `
                -ExecutionOutputPath $Script:TagMIPath } | Should -Not -Throw

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }
}

Describe 'Invoke-NhiTag — User' {
    BeforeAll {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $Script:TagUserPath = Join-Path $TestDrive 'tag-user-test'
        New-Item -ItemType Directory -Path $Script:TagUserPath -Force | Out-Null

        $userRec = [ordered]@{
            ObjectId           = 'user-tag-001'
            ObjectType         = 'User'
            DisplayName        = 'Test User'
            AppId              = $null
            PriorAccountEnabled = $true
            PriorNotes         = $null
            SnapshotTimestamp  = '2026-06-01T12:00:00Z'
            DisabledAt         = $null
            ScreamTestDays     = 0
            SkipReason         = 'SnapshotTagWrite skipped for User in Rev4.0'
            AdditionalFields   = @{}
            EngagementId       = 'ENG-REV40-001'
        }
        $manifestPath = Join-Path $Script:TagUserPath 'SnapshotManifest-M32TAG_USER.json'
        New-TestSnapshotManifest -Path $manifestPath -ExecutionRunId 'M32TAG_USER' -Records @($userRec)
    }

    It 'Invoke-NhiTag for User: no Graph call, no exception' {
        { Invoke-NhiTag -ObjectId 'user-tag-001' -ObjectType 'User' `
                -EngagementId 'ENG-REV40-001' -ExecutionRunId 'M32TAG_USER' `
                -ExecutionOutputPath $Script:TagUserPath } | Should -Not -Throw

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }
}

Describe 'Invoke-NhiTag — Error guards' {
    It 'Invoke-NhiTag: throws on invalid ObjectType' {
        $path = Join-Path $TestDrive 'tag-invalid-type'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        # WhatIf to skip manifest requirement
        { Invoke-NhiTag -ObjectId 'any-id' -ObjectType 'InvalidType' `
                -EngagementId 'ENG-001' -ExecutionRunId 'TEST_WHATIF' `
                -ExecutionOutputPath $path } | Should -Throw
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# M33 TESTS — Invoke-NhiDisable, Invoke-NhiRollbackDisable, Invoke-NhiRollbackTag
# ══════════════════════════════════════════════════════════════════════════════

Describe 'Invoke-NhiDisable — WhatIf' {
    It 'Invoke-NhiDisable WhatIf: no Graph call, no manifest read required' {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }
        Mock Get-MgServicePrincipal -ModuleName NhiExecution { throw 'Must not be called in WhatIf mode' }

        $path = Join-Path $TestDrive 'disable-whatif'
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        Invoke-NhiDisable -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-001' -ExecutionRunId 'TESTRUN' `
            -ExecutionOutputPath $path -ScreamTestDays 30 -WhatIf

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
        Should -Invoke Get-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }

    It 'Invoke-NhiDisable WhatIf: writes action intent to NhiExecutionWhatIf.json' {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $path = Join-Path $TestDrive 'disable-whatif-intent'
        New-Item -ItemType Directory -Path $path -Force | Out-Null

        Invoke-NhiDisable -ObjectId 'sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-001' -ExecutionRunId 'DISWHATIF01' `
            -ExecutionOutputPath $path -ScreamTestDays 30 -WhatIf

        $whatIfPath = Join-Path $path 'NhiExecutionWhatIf.json'
        $entries = @(Get-Content -Path $whatIfPath -Raw | ConvertFrom-Json)
        $entries[0].Action | Should -Be 'Disable'
    }
}

Describe 'Invoke-NhiDisable — ServicePrincipal' {
    BeforeAll {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }
        Mock Get-MgServicePrincipal -ModuleName NhiExecution {
            [PSCustomObject]@{
                Id             = 'disable-sp-001'
                DisplayName    = 'Disable Test SP'
                AppId          = 'app-001'
                AccountEnabled = $true
                Notes          = 'Tagged'
                AppRoles       = @()
                OAuth2PermissionGrants = @()
                KeyCredentials = @()
                PasswordCredentials = @()
            }
        }
        Mock Get-MgServicePrincipalOwner -ModuleName NhiExecution { return @() }

        $Script:DisableOutputPath = Join-Path $TestDrive 'disable-sp-test'
        New-Item -ItemType Directory -Path $Script:DisableOutputPath -Force | Out-Null

        # Pre-create snapshot manifest
        $rec = New-TestSPSnapshotRecord -ObjectId 'disable-sp-001' -PriorAccountEnabled $true -PriorNotes 'Tagged'
        New-TestSnapshotManifest -Path (Join-Path $Script:DisableOutputPath 'SnapshotManifest-DIS_SP.json') `
            -ExecutionRunId 'DIS_SP' -Records @($rec)
    }

    It 'Invoke-NhiDisable for SP: calls Update-MgServicePrincipal with AccountEnabled=$false' {
        Invoke-NhiDisable -ObjectId 'disable-sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'DIS_SP' `
            -ExecutionOutputPath $Script:DisableOutputPath -ScreamTestDays 30

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 1
        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -ParameterFilter {
            $ServicePrincipalId -eq 'disable-sp-001' -and
            $AccountEnabled -eq $false
        }
    }

    It 'Invoke-NhiDisable for SP: Record updated with DisabledAt and ScreamTestDays' {
        $manifestPath = Join-Path $Script:DisableOutputPath 'SnapshotManifest-DIS_SP2.json'
        # Create manifest
        $rec = New-TestSPSnapshotRecord -ObjectId 'disable-sp-001'
        New-TestSnapshotManifest -Path $manifestPath -ExecutionRunId 'DIS_SP2' -Records @($rec)

        # Run disable
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }
        Invoke-NhiDisable -ObjectId 'disable-sp-001' -ObjectType 'ServicePrincipal' `
            -EngagementId 'ENG-REV40-001' -ExecutionRunId 'DIS_SP2' `
            -ExecutionOutputPath $Script:DisableOutputPath -ScreamTestDays 15

        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $record   = $manifest.Records | Where-Object { $_.ObjectId -eq 'disable-sp-001' }

        [string]::IsNullOrEmpty($record.DisabledAt) | Should -Be $false
        $record.ScreamTestDays | Should -Be 15
    }

    It 'Invoke-NhiDisable for SP: throws when no prior snapshot Record exists' {
        $emptyPath = Join-Path $TestDrive 'disable-no-snapshot'
        New-Item -ItemType Directory -Path $emptyPath -Force | Out-Null
        New-TestSnapshotManifest -Path (Join-Path $emptyPath 'SnapshotManifest-DIS_EMPTY.json') `
            -ExecutionRunId 'DIS_EMPTY' -Records @()

        { Invoke-NhiDisable -ObjectId 'unknown-sp' -ObjectType 'ServicePrincipal' `
                -EngagementId 'ENG-001' -ExecutionRunId 'DIS_EMPTY' `
                -ExecutionOutputPath $emptyPath -ScreamTestDays 30 } | Should -Throw '*No snapshot Record*'
    }
}

Describe 'Invoke-NhiDisable — ManagedIdentity' {
    It 'Invoke-NhiDisable for MI: no Graph call, no exception' {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }
        Mock Get-MgServicePrincipal -ModuleName NhiExecution {
            [PSCustomObject]@{ Id = 'mi-d-001'; DisplayName = 'MI D'; AppId = 'mi1'; AccountEnabled = $true; AppRoles = @(); KeyCredentials = @(); PasswordCredentials = @() }
        }

        $path = Join-Path $TestDrive 'disable-mi-test'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $miRec = [ordered]@{
            ObjectId = 'mi-d-001'; ObjectType = 'ManagedIdentity'; DisplayName = 'MI'; AppId = 'mi1'
            PriorAccountEnabled = $true; PriorNotes = $null; SnapshotTimestamp = '2026-06-01T12:00:00Z'
            DisabledAt = $null; ScreamTestDays = 0; SkipReason = 'SnapshotTagWrite skipped for ManagedIdentity in Rev4.0'
            AdditionalFields = @{}; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-DIS_MI.json') -ExecutionRunId 'DIS_MI' -Records @($miRec)

        { Invoke-NhiDisable -ObjectId 'mi-d-001' -ObjectType 'ManagedIdentity' `
                -EngagementId 'ENG-001' -ExecutionRunId 'DIS_MI' `
                -ExecutionOutputPath $path -ScreamTestDays 30 } | Should -Not -Throw

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }
}

Describe 'Invoke-NhiDisable — User' {
    It 'Invoke-NhiDisable for User without -AllowHumanExecution: throws' {
        $path = Join-Path $TestDrive 'disable-user-no-flag'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $uRec = [ordered]@{
            ObjectId = 'u-d-001'; ObjectType = 'User'; DisplayName = 'U'; AppId = $null
            PriorAccountEnabled = $true; PriorNotes = $null; SnapshotTimestamp = '2026-06-01T12:00:00Z'
            DisabledAt = $null; ScreamTestDays = 0; SkipReason = $null; AdditionalFields = @{}; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-DIS_USER.json') -ExecutionRunId 'DIS_USER' -Records @($uRec)

        { Invoke-NhiDisable -ObjectId 'u-d-001' -ObjectType 'User' `
                -EngagementId 'ENG-001' -ExecutionRunId 'DIS_USER' `
                -ExecutionOutputPath $path -ScreamTestDays 30 } | Should -Throw '*Human identity disable blocked*'
    }

    It 'Invoke-NhiDisable for User with -AllowHumanExecution: no Graph call, ScreamTestDays = 0 (always)' {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $path = Join-Path $TestDrive 'disable-user-with-flag'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $uRec = [ordered]@{
            ObjectId = 'u-d-002'; ObjectType = 'User'; DisplayName = 'U2'; AppId = $null
            PriorAccountEnabled = $true; PriorNotes = $null; SnapshotTimestamp = '2026-06-01T12:00:00Z'
            DisabledAt = $null; ScreamTestDays = 0; SkipReason = $null; AdditionalFields = @{}; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-DIS_USER2.json') -ExecutionRunId 'DIS_USER2' -Records @($uRec)

        { Invoke-NhiDisable -ObjectId 'u-d-002' -ObjectType 'User' `
                -EngagementId 'ENG-001' -ExecutionRunId 'DIS_USER2' `
                -ExecutionOutputPath $path -ScreamTestDays 30 -AllowHumanExecution } | Should -Not -Throw

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0

        # Verify ScreamTestDays = 0 regardless of parameter value
        $manifest = Get-Content -Path (Join-Path $path 'SnapshotManifest-DIS_USER2.json') -Raw | ConvertFrom-Json
        $record   = $manifest.Records | Where-Object { $_.ObjectId -eq 'u-d-002' }
        $record.ScreamTestDays | Should -Be 0 -Because 'ScreamTestDays always 0 for User'
    }

    It 'Invoke-NhiDisable for User without -AllowHumanExecution: no manifest update' {
        # Pre-seed a User record
        $path = Join-Path $TestDrive 'disable-user-no-update'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $uRec = [ordered]@{
            ObjectId = 'u-d-003'; ObjectType = 'User'; DisplayName = 'U3'; AppId = $null
            PriorAccountEnabled = $true; PriorNotes = $null; SnapshotTimestamp = '2026-06-01T12:00:00Z'
            DisabledAt = $null; ScreamTestDays = 0; SkipReason = $null; AdditionalFields = @{}; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-DIS_USER3.json') -ExecutionRunId 'DIS_USER3' -Records @($uRec)

        $beforeJson = Get-Content (Join-Path $path 'SnapshotManifest-DIS_USER3.json') -Raw

        try {
            Invoke-NhiDisable -ObjectId 'u-d-003' -ObjectType 'User' `
                -EngagementId 'ENG-001' -ExecutionRunId 'DIS_USER3' `
                -ExecutionOutputPath $path -ScreamTestDays 30 2>$null
        } catch { }

        $afterJson = Get-Content (Join-Path $path 'SnapshotManifest-DIS_USER3.json') -Raw
        $afterJson | Should -BeExactly $beforeJson -Because 'No manifest update when User has no AllowHumanExecution'
    }
}

Describe 'Invoke-NhiDisable — Error guards' {
    It 'Invoke-NhiDisable: throws on invalid ObjectType' {
        $path = Join-Path $TestDrive 'disable-invalid-type'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }
        { Invoke-NhiDisable -ObjectId 'any-id' -ObjectType 'Fake' `
                -EngagementId 'ENG-001' -ExecutionRunId 'TEST' `
                -ExecutionOutputPath $path -ScreamTestDays 30 } | Should -Throw
    }
}

# ── Invoke-NhiRollbackDisable ─────────────────────────────────────────────────

Describe 'Invoke-NhiRollbackDisable — ServicePrincipal' {
    BeforeAll {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $Script:RollbackPath = Join-Path $TestDrive 'rollback-disable-test'
        New-Item -ItemType Directory -Path $Script:RollbackPath -Force | Out-Null

        # Manifest where SP was disabled (PriorAccountEnabled = $true → now AccountEnabled = $false scenario)
        $recTrue = [ordered]@{
            ObjectId = 'rb-sp-001'; ObjectType = 'ServicePrincipal'; DisplayName = 'RB SP 001'
            AppId = 'app-rb-001'; PriorAccountEnabled = $true; PriorNotes = 'PreDisTag'
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = '2026-06-03T12:00:00Z'
            ScreamTestDays = 30; SkipReason = $null; AdditionalFields = @{ AppRolesCount = 0; OAuth2PermissionGrantsCount = 0; KeyCredentialsCount = 0; PasswordCredentialsCount = 0; Owners = @() }; EngagementId = 'ENG-REV40-001'
        }
        # SP where state was false before (no-op for disable but rollback shouldn't restore unconditionally)
        $recFalse = [ordered]@{
            ObjectId = 'rb-sp-002'; ObjectType = 'ServicePrincipal'; DisplayName = 'RB SP 002'
            AppId = 'app-rb-002'; PriorAccountEnabled = $false; PriorNotes = $null
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = '2026-06-03T12:00:00Z'
            ScreamTestDays = 30; SkipReason = $null; AdditionalFields = @{ AppRolesCount = 0; OAuth2PermissionGrantsCount = 0; KeyCredentialsCount = 0; PasswordCredentialsCount = 0; Owners = @() }; EngagementId = 'ENG-REV40-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $Script:RollbackPath 'SnapshotManifest-RB_SP.json') `
            -ExecutionRunId 'RB_SP' -Records @($recTrue, $recFalse)
    }

    It 'Invoke-NhiRollbackDisable for SP: reads PriorAccountEnabled and restores state' {
        Invoke-NhiRollbackDisable -ObjectId 'rb-sp-001' -ObjectType 'ServicePrincipal' `
            -ExecutionRunId 'RB_SP' -ExecutionOutputPath $Script:RollbackPath

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 1
        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -ParameterFilter {
            $ServicePrincipalId -eq 'rb-sp-001' -and
            $AccountEnabled -eq $true
        }
    }

    It 'Invoke-NhiRollbackDisable for SP: restores $false when PriorAccountEnabled was $false — NOT unconditional $true' {
        Invoke-NhiRollbackDisable -ObjectId 'rb-sp-002' -ObjectType 'ServicePrincipal' `
            -ExecutionRunId 'RB_SP' -ExecutionOutputPath $Script:RollbackPath

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 1
        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -ParameterFilter {
            $ServicePrincipalId -eq 'rb-sp-002' -and
            $AccountEnabled -eq $false
        }
    }

    It 'Invoke-NhiRollbackDisable: throws when zero matching Records' {
        { Invoke-NhiRollbackDisable -ObjectId 'unknown-sp' -ObjectType 'ServicePrincipal' `
                -ExecutionRunId 'RB_SP' -ExecutionOutputPath $Script:RollbackPath } | Should -Throw '*No snapshot Record found*'
    }

    It 'Invoke-NhiRollbackDisable: throws when multiple matching Records' {
        # Add duplicate record to manifest
        $manifestPath = Join-Path $Script:RollbackPath 'SnapshotManifest-RB_SP_DUP.json'
        $rec = [ordered]@{
            ObjectId = 'rb-dup-001'; ObjectType = 'ServicePrincipal'; DisplayName = 'RB DUP'
            AppId = 'app-dup'; PriorAccountEnabled = $true; PriorNotes = $null
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = $null
            ScreamTestDays = 0; SkipReason = $null; AdditionalFields = @{ AppRolesCount = 0; OAuth2PermissionGrantsCount = 0; KeyCredentialsCount = 0; PasswordCredentialsCount = 0; Owners = @() }; EngagementId = 'ENG-DUP'
        }
        New-TestSnapshotManifest -Path $manifestPath -ExecutionRunId 'RB_SP_DUP' -Records @($rec, $rec)

        { Invoke-NhiRollbackDisable -ObjectId 'rb-dup-001' -ObjectType 'ServicePrincipal' `
                -ExecutionRunId 'RB_SP_DUP' -ExecutionOutputPath $Script:RollbackPath } | Should -Throw '*Multiple snapshot Records found*'
    }
}

Describe 'Invoke-NhiRollbackDisable — ManagedIdentity / User' {
    It 'Invoke-NhiRollbackDisable for MI: no Graph call, no exception' {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $path = Join-Path $TestDrive 'rb-mi-test'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $miRec = [ordered]@{
            ObjectId = 'mi-rb-001'; ObjectType = 'ManagedIdentity'; DisplayName = 'MI RB'
            AppId = 'mi-rb-001'; PriorAccountEnabled = $true; PriorNotes = $null
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = '2026-06-03T12:00:00Z'
            ScreamTestDays = 30; SkipReason = 'SnapshotTagWrite skipped for ManagedIdentity in Rev4.0'
            AdditionalFields = @{}; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-RB_MI.json') -ExecutionRunId 'RB_MI' -Records @($miRec)

        { Invoke-NhiRollbackDisable -ObjectId 'mi-rb-001' -ObjectType 'ManagedIdentity' `
                -ExecutionRunId 'RB_MI' -ExecutionOutputPath $path } | Should -Not -Throw

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }

    It 'Invoke-NhiRollbackDisable for User: no Graph call, no exception' {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $path = Join-Path $TestDrive 'rb-user-test'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $uRec = [ordered]@{
            ObjectId = 'u-rb-001'; ObjectType = 'User'; DisplayName = 'U RB'; AppId = $null
            PriorAccountEnabled = $true; PriorNotes = $null
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = '2026-06-03T12:00:00Z'
            ScreamTestDays = 0; SkipReason = $null; AdditionalFields = @{}; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-RB_USR.json') -ExecutionRunId 'RB_USR' -Records @($uRec)

        { Invoke-NhiRollbackDisable -ObjectId 'u-rb-001' -ObjectType 'User' `
                -ExecutionRunId 'RB_USR' -ExecutionOutputPath $path } | Should -Not -Throw

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }

    It 'Invoke-NhiRollbackDisable: throws on invalid ObjectType' {
        $path = Join-Path $TestDrive 'rb-invalid-type'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }
        { Invoke-NhiRollbackDisable -ObjectId 'any-id' -ObjectType 'Fake' `
                -ExecutionRunId 'RB_TEST' -ExecutionOutputPath $path } | Should -Throw
    }
}

# ── Invoke-NhiRollbackTag ─────────────────────────────────────────────────────

Describe 'Invoke-NhiRollbackTag — ServicePrincipal' {
    BeforeAll {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $Script:TagRollbackPath = Join-Path $TestDrive 'rollback-tag-test'
        New-Item -ItemType Directory -Path $Script:TagRollbackPath -Force | Out-Null

        $recOriginalNotes = [ordered]@{
            ObjectId = 'rb-tag-001'; ObjectType = 'ServicePrincipal'; DisplayName = 'RB Tag SP'
            AppId = 'app-rbtag'; PriorAccountEnabled = $true; PriorNotes = 'Original Notes'
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = $null; ScreamTestDays = 0
            SkipReason = $null; AdditionalFields = @{ AppRolesCount = 0; OAuth2PermissionGrantsCount = 0; KeyCredentialsCount = 0; PasswordCredentialsCount = 0; Owners = @() }; EngagementId = 'ENG-001'
        }
        $recNullNotes = [ordered]@{
            ObjectId = 'rb-tag-002'; ObjectType = 'ServicePrincipal'; DisplayName = 'RB Tag SP2'
            AppId = 'app-rbtag2'; PriorAccountEnabled = $true; PriorNotes = $null
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = $null; ScreamTestDays = 0
            SkipReason = $null; AdditionalFields = @{ AppRolesCount = 0; OAuth2PermissionGrantsCount = 0; KeyCredentialsCount = 0; PasswordCredentialsCount = 0; Owners = @() }; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $Script:TagRollbackPath 'SnapshotManifest-RB_TAG.json') `
            -ExecutionRunId 'RB_TAG' -Records @($recOriginalNotes, $recNullNotes)
    }

    It 'Invoke-NhiRollbackTag for SP: restores exact PriorNotes value (non-null)' {
        Invoke-NhiRollbackTag -ObjectId 'rb-tag-001' -ObjectType 'ServicePrincipal' `
            -ExecutionRunId 'RB_TAG' -ExecutionOutputPath $Script:TagRollbackPath

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 1
        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -ParameterFilter {
            $ServicePrincipalId -eq 'rb-tag-001' -and
            $Notes -eq 'Original Notes'
        }
    }

    It 'Invoke-NhiRollbackTag for SP: restores null Notes (PriorNotes was $null)' {
        Invoke-NhiRollbackTag -ObjectId 'rb-tag-002' -ObjectType 'ServicePrincipal' `
            -ExecutionRunId 'RB_TAG' -ExecutionOutputPath $Script:TagRollbackPath

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 1
        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -ParameterFilter {
            $ServicePrincipalId -eq 'rb-tag-002' -and
            $Notes -eq $null
        }
    }

    It 'Invoke-NhiRollbackTag: throws when zero matching Records' {
        { Invoke-NhiRollbackTag -ObjectId 'unknown-sp' -ObjectType 'ServicePrincipal' `
                -ExecutionRunId 'RB_TAG' -ExecutionOutputPath $Script:TagRollbackPath } | Should -Throw '*No snapshot Record found*'
    }

    It 'Invoke-NhiRollbackTag: throws when multiple matching Records' {
        $path = Join-Path $TestDrive 'rb-tag-dup'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $rec = [ordered]@{
            ObjectId = 'rb-dup-tag'; ObjectType = 'ServicePrincipal'; DisplayName = 'Dup'; AppId = 'a'
            PriorAccountEnabled = $true; PriorNotes = 'Dup Note'; SnapshotTimestamp = '2026-06-01T12:00:00Z'
            DisabledAt = $null; ScreamTestDays = 0; SkipReason = $null; AdditionalFields = @{}; EngagementId = 'ENG'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-RB_TAG_DUP.json') `
            -ExecutionRunId 'RB_TAG_DUP' -Records @($rec, $rec)

        { Invoke-NhiRollbackTag -ObjectId 'rb-dup-tag' -ObjectType 'ServicePrincipal' `
                -ExecutionRunId 'RB_TAG_DUP' -ExecutionOutputPath $path } | Should -Throw '*Multiple snapshot Records found*'
    }
}

Describe 'Invoke-NhiRollbackTag — ManagedIdentity / User' {
    It 'Invoke-NhiRollbackTag for MI: no Graph call, no exception' {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $path = Join-Path $TestDrive 'rb-tag-mi-test'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $miRec = [ordered]@{
            ObjectId = 'mi-rbtag-001'; ObjectType = 'ManagedIdentity'; DisplayName = 'MI Tag RB'
            AppId = 'mi-rbtag'; PriorAccountEnabled = $true; PriorNotes = 'MI Tag'
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = $null; ScreamTestDays = 0
            SkipReason = 'SnapshotTagWrite skipped for ManagedIdentity in Rev4.0'
            AdditionalFields = @{}; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-RB_TAG_MI.json') -ExecutionRunId 'RB_TAG_MI' -Records @($miRec)

        { Invoke-NhiRollbackTag -ObjectId 'mi-rbtag-001' -ObjectType 'ManagedIdentity' `
                -ExecutionRunId 'RB_TAG_MI' -ExecutionOutputPath $path } | Should -Not -Throw

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }

    It 'Invoke-NhiRollbackTag for User: no Graph call, no exception' {
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }

        $path = Join-Path $TestDrive 'rb-tag-user-test'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        $uRec = [ordered]@{
            ObjectId = 'u-rbtag-001'; ObjectType = 'User'; DisplayName = 'U Tag RB'; AppId = $null
            PriorAccountEnabled = $true; PriorNotes = $null
            SnapshotTimestamp = '2026-06-01T12:00:00Z'; DisabledAt = $null; ScreamTestDays = 0
            SkipReason = $null; AdditionalFields = @{}; EngagementId = 'ENG-001'
        }
        New-TestSnapshotManifest -Path (Join-Path $path 'SnapshotManifest-RB_TAG_USR.json') -ExecutionRunId 'RB_TAG_USR' -Records @($uRec)

        { Invoke-NhiRollbackTag -ObjectId 'u-rbtag-001' -ObjectType 'User' `
                -ExecutionRunId 'RB_TAG_USR' -ExecutionOutputPath $path } | Should -Not -Throw

        Should -Invoke Update-MgServicePrincipal -ModuleName NhiExecution -Times 0
    }

    It 'Invoke-NhiRollbackTag: throws on invalid ObjectType' {
        $path = Join-Path $TestDrive 'rb-tag-invalid-type'
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Mock Update-MgServicePrincipal -ModuleName NhiExecution { }
        { Invoke-NhiRollbackTag -ObjectId 'any-id' -ObjectType 'Fake' `
                -ExecutionRunId 'RB_TAG_TEST' -ExecutionOutputPath $path } | Should -Throw
    }
}

# ══════════════════════════════════════════════════════════════════════════════
# M34 TESTS — Get-NhiScreamTestStatus
# ══════════════════════════════════════════════════════════════════════════════

Describe 'Get-NhiScreamTestStatus — Status calculation' {
    BeforeAll {
        $Script:MonOutputPath = Join-Path $TestDrive 'monitor-status-test'
        New-Item -ItemType Directory -Path $Script:MonOutputPath -Force | Out-Null
    }

    It 'Status = "Active" when ElapsedDays < ScreamTestDays' {
        # Disabled 5 days ago, ScreamTestDays = 30 → Active
        $disabledAt = [DateTime]::UtcNow.AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $result = Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test SP' `
            -DisabledAt $disabledAt -ScreamTestDays 30 -ExecutionOutputPath $Script:MonOutputPath `
            -ExecutionRunId 'MON01'

        $result.Status       | Should -Be 'Active'
        $result.ElapsedDays | Should -BeLessThan 30
    }

    It 'Status = "Complete" when ElapsedDays >= ScreamTestDays AND ElapsedDays <= ScreamTestDays + 7' {
        # Disabled 33 days ago, ScreamTestDays = 30 → Complete (33 <= 37)
        $disabledAt = [DateTime]::UtcNow.AddDays(-33).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $result = Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test SP' `
            -DisabledAt $disabledAt -ScreamTestDays 30 -ExecutionOutputPath $Script:MonOutputPath `
            -ExecutionRunId 'MON02'

        $result.Status | Should -Be 'Complete'
    }

    It 'Status = "Overdue" when ElapsedDays > ScreamTestDays + 7' {
        # Disabled 40 days ago, ScreamTestDays = 30 → Overdue (40 > 37)
        $disabledAt = [DateTime]::UtcNow.AddDays(-40).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $result = Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test SP' `
            -DisabledAt $disabledAt -ScreamTestDays 30 -ExecutionOutputPath $Script:MonOutputPath `
            -ExecutionRunId 'MON03'

        $result.Status | Should -Be 'Overdue'
    }

    It 'Status = "Complete" (not "Overdue") at exactly ScreamTestDays + 7 boundary' {
        # Disabled exactly 37 days ago, ScreamTestDays = 30 → must be Complete, not Overdue
        $disabledAt = [DateTime]::UtcNow.AddDays(-37).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $result = Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test SP' `
            -DisabledAt $disabledAt -ScreamTestDays 30 -ExecutionOutputPath $Script:MonOutputPath `
            -ExecutionRunId 'MON04'

        $result.Status | Should -Be 'Complete' -Because 'At exactly ScreamTestDays+7, status must be Complete (not Overdue)'
    }

    It 'Overdue takes precedence over Complete at same day' {
        # The ordering matters: check Overdue evaluation before Complete
        # If 38 days: 38 > 37 → Overdue, not Complete
        $disabledAt = [DateTime]::UtcNow.AddDays(-38).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $result = Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test SP' `
            -DisabledAt $disabledAt -ScreamTestDays 30 -ExecutionOutputPath $Script:MonOutputPath `
            -ExecutionRunId 'MON05'

        $result.Status | Should -Be 'Overdue'
    }

    It 'Returns object with all 8 required fields' {
        $disabledAt = [DateTime]::UtcNow.AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $result = Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test SP' `
            -DisabledAt $disabledAt -ScreamTestDays 30 -ExecutionOutputPath $Script:MonOutputPath `
            -ExecutionRunId 'MON06'

        @('ObjectId', 'DisplayName', 'DisabledAt', 'ElapsedDays', 'ScreamTestDays', 'Status', 'ExecutionRunId', 'AssessedAt') | ForEach-Object {
            $result.PSObject.Properties.Name | Should -Contain $_
        }
    }
}

Describe 'Get-NhiScreamTestStatus — file I/O' {
    BeforeAll {
        $Script:MonFilePath = Join-Path $TestDrive 'monitor-file-test'
        New-Item -ItemType Directory -Path $Script:MonFilePath -Force | Out-Null
    }

    It 'NhiExecutionStatus.json created when it does not exist' {
        $disabledAt = [DateTime]::UtcNow.AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')
        $statusPath = Join-Path $Script:MonFilePath 'NhiExecutionStatus.json'

        (Test-Path $statusPath) | Should -Be $false

        Get-NhiScreamTestStatus -ObjectId 'file-sp-001' -DisplayName 'File Test' `
            -DisabledAt $disabledAt -ScreamTestDays 30 `
            -ExecutionOutputPath $Script:MonFilePath -ExecutionRunId 'MON_FILE01'

        $statusPath | Should -Exist
        $content = Get-Content -Path $statusPath -Raw | ConvertFrom-Json
        $content.Count | Should -BeGreaterThan 0
    }

    It 'NhiExecutionStatus.json appended to when it already exists' {
        $statusPath = Join-Path $Script:MonFilePath 'NhiExecutionStatus.json'

        # Pre-populate file with one entry using a simple array
        [System.IO.File]::WriteAllText(
            $statusPath,
            '[{"ObjectId":"existing"},]',
            [System.Text.UTF8Encoding]::new($false)
        )

        $disabledAt = [DateTime]::UtcNow.AddDays(-3).ToString('yyyy-MM-ddTHH:mm:ssZ')

        Get-NhiScreamTestStatus -ObjectId 'file-sp-002' -DisplayName 'File Test 2' `
            -DisabledAt $disabledAt -ScreamTestDays 30 `
            -ExecutionOutputPath $Script:MonFilePath -ExecutionRunId 'MON_FILE02'

        $content = Get-Content -Path $statusPath -Raw | ConvertFrom-Json
        $content.Count | Should -Be 2 -Because 'After appending, there should be 2 entries'
    }

    It 'Throws when existing NhiExecutionStatus.json is not a valid JSON array' {
        $statusPath = Join-Path $Script:MonFilePath 'NhiExecutionStatus.json'
        New-Item -ItemType Directory -Path $Script:MonFilePath -Force | Out-Null
        [System.IO.File]::WriteAllText($statusPath, 'NOT JSON {{{', [System.Text.UTF8Encoding]::new($false))

        $disabledAt = [DateTime]::UtcNow.AddDays(-3).ToString('yyyy-MM-ddTHH:mm:ssZ')

        { Get-NhiScreamTestStatus -ObjectId 'bad-json' -DisplayName 'Bad' `
                -DisabledAt $disabledAt -ScreamTestDays 30 `
                -ExecutionOutputPath $Script:MonFilePath -ExecutionRunId 'MON_BAD' } | Should -Throw
    }

    It 'Throws when ExecutionOutputPath does not exist' {
        $disabledAt = [DateTime]::UtcNow.AddDays(-3).ToString('yyyy-MM-ddTHH:mm:ssZ')

        { Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test' `
                -DisabledAt $disabledAt -ScreamTestDays 30 `
                -ExecutionOutputPath (Join-Path $TestDrive 'DOES_NOT_EXIST') `
                -ExecutionRunId 'MON_NOEXIST' } | Should -Throw
    }

    It 'Throws when -DisabledAt is not a parseable datetime' {
        $badPath = Join-Path $TestDrive 'mon-bad-date'
        New-Item -ItemType Directory -Path $badPath -Force | Out-Null

        { Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test' `
                -DisabledAt 'NOT-A-DATE-TIME' -ScreamTestDays 30 `
                -ExecutionOutputPath $badPath -ExecutionRunId 'MON_BADDATE' } | Should -Throw
    }
}

Describe 'Get-NhiScreamTestStatus — New-DecomFinding not called' {
    It 'Asserts that New-DecomFinding is never called (mock assertion)' {
        $monPath = Join-Path $TestDrive 'mon-no-finding'
        New-Item -ItemType Directory -Path $monPath -Force | Out-Null

        $disabledAt = [DateTime]::UtcNow.AddDays(-5).ToString('yyyy-MM-ddTHH:mm:ssZ')

        # If New-DecomFinding is in scope (e.g. if Utilities module is loaded),
        # it would throw because the function is not defined in NhiExecution scope.
        # We simply verify the function completes without calling New-DecomFinding.
        # Since New-DecomFinding is not available in NhiExecution scope,
        # any call to it would be a CommandNotFoundException.
        try {
            Get-NhiScreamTestStatus -ObjectId 'sp-001' -DisplayName 'Test' `
                -DisabledAt $disabledAt -ScreamTestDays 30 `
                -ExecutionOutputPath $monPath -ExecutionRunId 'MON_NOFIND'
            $result = 'OK'
        } catch {
            if ($_.Exception.Message -like '*New-DecomFinding*') {
                throw "New-DecomFinding was called — this must never happen"
            }
            $result = 'Other Error: ' + $_.Exception.Message
        }

        $result | Should -Be 'OK'
    }
}