#Requires -Version 5.1
# Pester tests for NhiExecutionSchema.psm1 (Rev4.0 M31)

BeforeAll {
    $ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiExecutionSchema.psm1'
    Import-Module $ModulePath -Force -DisableNameChecking
}

AfterAll {
    Remove-Module 'NhiExecutionSchema' -Force -ErrorAction SilentlyContinue
}

# ── Get-NhiExecutionSchema ────────────────────────────────────────────────────

Describe 'Get-NhiExecutionSchema' {
    It 'Returns 12 actions total' {
        $schema = Get-NhiExecutionSchema
        $schema.Count | Should -Be 12
    }

    It 'Returns all 6 allowed actions with BlockedInRev40 = $false' {
        $schema = Get-NhiExecutionSchema
        $allowed = @('Snapshot', 'Tag', 'Disable', 'Monitor', 'RollbackTag', 'RollbackDisable')
        foreach ($name in $allowed) {
            $schema[$name].BlockedInRev40 | Should -Be $false -Because "Action '$name' must be allowed in Rev4.0"
        }
    }

    It 'Returns all 6 blocked actions with BlockedInRev40 = $true' {
        $schema = Get-NhiExecutionSchema
        $blocked = @('HardDeleteSvcPrincipalBlocklist', 'RemoveCredential', 'RemoveAppRoleAssignment',
            'RemoveOAuthGrant', 'RemoveOwner', 'DeleteApplication')
        foreach ($name in $blocked) {
            $schema[$name].BlockedInRev40 | Should -Be $true -Because "Action '$name' must be blocked in Rev4.0"
        }
    }

    It 'Returns correct Phase for each action' {
        $schema = Get-NhiExecutionSchema

        $schema['Snapshot'].Phase         | Should -Be 1
        $schema['Tag'].Phase              | Should -Be 1
        $schema['Disable'].Phase          | Should -Be 2
        $schema['Monitor'].Phase          | Should -Be 3
        $schema['RollbackTag'].Phase      | Should -Be 3
        $schema['RollbackDisable'].Phase  | Should -Be 3

        $schema['HardDeleteSvcPrincipalBlocklist'].Phase | Should -Be 3
        $schema['RemoveCredential'].Phase           | Should -Be 2
        $schema['RemoveAppRoleAssignment'].Phase    | Should -Be 2
        $schema['RemoveOAuthGrant'].Phase           | Should -Be 2
        $schema['RemoveOwner'].Phase                | Should -Be 1
        $schema['DeleteApplication'].Phase          | Should -Be 3
    }

    It 'Returns correct IsReversible for each action' {
        $schema = Get-NhiExecutionSchema

        # Allowed actions are all reversible
        foreach ($name in @('Snapshot', 'Tag', 'Disable', 'Monitor', 'RollbackTag', 'RollbackDisable')) {
            $schema[$name].IsReversible | Should -Be $true
        }

        # Blocked actions are all non-reversible
        foreach ($name in @('HardDeleteSvcPrincipalBlocklist', 'RemoveCredential', 'RemoveAppRoleAssignment',
                'RemoveOAuthGrant', 'RemoveOwner', 'DeleteApplication')) {
            $schema[$name].IsReversible | Should -Be $false
        }
    }

    It 'Returns correct ApplicableObjectTypes for each action' {
        $schema = Get-NhiExecutionSchema

        # All 3: Snapshot, Tag, Disable, Monitor, RollbackTag, RollbackDisable
        foreach ($name in @('Snapshot', 'Tag', 'Disable', 'Monitor', 'RollbackTag', 'RollbackDisable')) {
            $schema[$name].ApplicableObjectTypes | Should -Contain 'ServicePrincipal'
            $schema[$name].ApplicableObjectTypes | Should -Contain 'ManagedIdentity'
            $schema[$name].ApplicableObjectTypes | Should -Contain 'User'
        }

        # SP-only
        $schema['RemoveOwner'].ApplicableObjectTypes        | Should -BeExactly @('ServicePrincipal')
        $schema['DeleteApplication'].ApplicableObjectTypes | Should -BeExactly @('ServicePrincipal')
        $schema['RemoveCredential'].ApplicableObjectTypes   | Should -BeExactly @('ServicePrincipal')
        $schema['RemoveOAuthGrant'].ApplicableObjectTypes   | Should -BeExactly @('ServicePrincipal')

        # SP + User
        $schema['RemoveAppRoleAssignment'].ApplicableObjectTypes | Should -BeExactly @('ServicePrincipal', 'User')
    }

    It 'Returns a copy so module-level mutation does not propagate' {
        $schema = Get-NhiExecutionSchema
        $schema['Snapshot'].Phase = 99
        $fresh = Get-NhiExecutionSchema
        $fresh['Snapshot'].Phase | Should -Be 1
    }

    It 'Every action Name field matches its hashtable key' {
        $schema = Get-NhiExecutionSchema
        foreach ($key in $schema.Keys) {
            $schema[$key].Name | Should -Be $key
        }
    }

    It 'Every action has RequiresApprovedManifest = $true' {
        $schema = Get-NhiExecutionSchema
        foreach ($action in $schema.Values) {
            $action.RequiresApprovedManifest | Should -Be $true
        }
    }
}

# ── Test-NhiExecutionActionAllowed ────────────────────────────────────────────

Describe 'Test-NhiExecutionActionAllowed' {
    It 'Returns $false for all 6 blocked actions at PhaseLimit 3' {
        foreach ($name in @('HardDeleteSvcPrincipalBlocklist', 'RemoveCredential', 'RemoveAppRoleAssignment',
                'RemoveOAuthGrant', 'RemoveOwner', 'DeleteApplication')) {
            Test-NhiExecutionActionAllowed -ActionName $name -PhaseLimit 3 | Should -Be $false
        }
    }

    It 'PhaseLimit 1 allows only Snapshot and Tag' {
        Test-NhiExecutionActionAllowed -ActionName 'Snapshot' -PhaseLimit 1 | Should -Be $true
        Test-NhiExecutionActionAllowed -ActionName 'Tag' -PhaseLimit 1        | Should -Be $true
        foreach ($name in @('Disable', 'Monitor', 'RollbackTag', 'RollbackDisable')) {
            Test-NhiExecutionActionAllowed -ActionName $name -PhaseLimit 1 | Should -Be $false
        }
    }

    It 'PhaseLimit 2 allows Snapshot, Tag, and Disable' {
        foreach ($name in @('Snapshot', 'Tag', 'Disable')) {
            Test-NhiExecutionActionAllowed -ActionName $name -PhaseLimit 2 | Should -Be $true
        }
        foreach ($name in @('Monitor', 'RollbackTag', 'RollbackDisable')) {
            Test-NhiExecutionActionAllowed -ActionName $name -PhaseLimit 2 | Should -Be $false
        }
    }

    It 'PhaseLimit 3 allows all 6 allowed actions' {
        foreach ($name in @('Snapshot', 'Tag', 'Disable', 'Monitor', 'RollbackTag', 'RollbackDisable')) {
            Test-NhiExecutionActionAllowed -ActionName $name -PhaseLimit 3 | Should -Be $true
        }
    }

    It 'Returns $false for unknown action name' {
        Test-NhiExecutionActionAllowed -ActionName 'NonExistentAction' -PhaseLimit 3 | Should -Be $false
    }

    It 'Monitor blocked at PhaseLimit 1 and 2 but allowed at PhaseLimit 3' {
        Test-NhiExecutionActionAllowed -ActionName 'Monitor' -PhaseLimit 1 | Should -Be $false
        Test-NhiExecutionActionAllowed -ActionName 'Monitor' -PhaseLimit 2 | Should -Be $false
        Test-NhiExecutionActionAllowed -ActionName 'Monitor' -PhaseLimit 3 | Should -Be $true
    }

    It 'Disable blocked at PhaseLimit 1 but allowed at PhaseLimit 2 and 3' {
        Test-NhiExecutionActionAllowed -ActionName 'Disable' -PhaseLimit 1 | Should -Be $false
        Test-NhiExecutionActionAllowed -ActionName 'Disable' -PhaseLimit 2 | Should -Be $true
        Test-NhiExecutionActionAllowed -ActionName 'Disable' -PhaseLimit 3 | Should -Be $true
    }
}

# ── Confirm-NhiApprovedManifest ──────────────────────────────────────────────

Describe 'Confirm-NhiApprovedManifest' {
    BeforeAll {
        function New-TestManifest {
            param([string]$Path, [hashtable]$Overrides = @{})

            # Hard-code the canonical target so we have deterministic SHA256
            $targetIds = @('obj-id-001')
            $idsJson   = ConvertTo-Json -InputObject $targetIds -Compress -Depth 10
            $utf8Bytes = [System.Text.Encoding]::UTF8.GetBytes($idsJson)
            $shaAlg    = [System.Security.Cryptography.SHA256]::Create()
            $shaBytes  = $shaAlg.ComputeHash($utf8Bytes)
            $sha256Hex = -join ($shaBytes | ForEach-Object { $_.ToString('x2') })

            $manifest = @{
                EngagementId             = 'ENG-REV40-001'
                SHA256                   = $sha256Hex
                ExecutionPhaseApproved   = 3
                ApprovedBy              = 'albert.jee@example.com'
                ApprovedAt              = '2026-06-05T00:00:00Z'
                SchemaVersion            = '1.0'
                TargetObjectIds          = $targetIds
            }
            foreach ($key in $Overrides.Keys) {
                $manifest[$key] = $Overrides[$key]
            }
            $jsonStr = ConvertTo-Json -InputObject $manifest -Compress -Depth 10
            [System.IO.File]::WriteAllText($Path, $jsonStr, [System.Text.UTF8Encoding]::new($false))
        }
    }

    It 'Throws when manifest file does not exist' {
        $missing = Join-Path $TestDrive 'does-not-exist.json'
        { Confirm-NhiApprovedManifest -ManifestPath $missing -EngagementId 'ENG-001' `
                -TargetObjectIds @('id1') -PhaseLimit 1 } | Should -Throw '*not found*'
    }

    It 'Throws when manifest file is not valid JSON' {
        $path = Join-Path $TestDrive 'bad-json.json'
        [System.IO.File]::WriteAllText($path, 'not json{{{', [System.Text.UTF8Encoding]::new($false))
        { Confirm-NhiApprovedManifest -ManifestPath $path -EngagementId 'ENG-001' `
                -TargetObjectIds @('id1') -PhaseLimit 1 } | Should -Throw '*not valid JSON*'
    }

    It 'Throws when EngagementId does not match' {
        $path = Join-Path $TestDrive 'eng-mismatch.json'
        New-TestManifest -Path $path -Overrides @{ EngagementId = 'OTHER-ENG' }
        { Confirm-NhiApprovedManifest -ManifestPath $path -EngagementId 'ENG-001' `
                -TargetObjectIds @('obj-id-001') -PhaseLimit 1 } | Should -Throw '*EngagementId*'
    }

    It 'Throws when SHA256 does not match' {
        $path = Join-Path $TestDrive 'hash-mismatch.json'
        New-TestManifest -Path $path
        { Confirm-NhiApprovedManifest -ManifestPath $path -EngagementId 'ENG-REV40-001' `
                -TargetObjectIds @('different-id') -PhaseLimit 1 } | Should -Throw '*SHA256*'
    }

    It 'Throws when ExecutionPhaseApproved is less than PhaseLimit' {
        $path = Join-Path $TestDrive 'phase-low.json'
        New-TestManifest -Path $path -Overrides @{ ExecutionPhaseApproved = 2 }
        { Confirm-NhiApprovedManifest -ManifestPath $path -EngagementId 'ENG-REV40-001' `
                -TargetObjectIds @('obj-id-001') -PhaseLimit 3 } | Should -Throw '*ExecutionPhaseApproved*'
    }

    It 'Throws when ApprovedBy is missing or empty' {
        $path = Join-Path $TestDrive 'no-approver.json'
        New-TestManifest -Path $path -Overrides @{ ApprovedBy = '' }
        { Confirm-NhiApprovedManifest -ManifestPath $path -EngagementId 'ENG-REV40-001' `
                -TargetObjectIds @('obj-id-001') -PhaseLimit 1 } | Should -Throw '*ApprovedBy*'
    }

    It 'Throws when ApprovedAt is missing or empty' {
        $path = Join-Path $TestDrive 'no-approved-at.json'
        New-TestManifest -Path $path -Overrides @{ ApprovedAt = '' }
        { Confirm-NhiApprovedManifest -ManifestPath $path -EngagementId 'ENG-REV40-001' `
                -TargetObjectIds @('obj-id-001') -PhaseLimit 1 } | Should -Throw '*ApprovedAt*'
    }

    It 'Throws when SchemaVersion is missing or empty' {
        $path = Join-Path $TestDrive 'no-schema-version.json'
        New-TestManifest -Path $path -Overrides @{ SchemaVersion = '' }
        { Confirm-NhiApprovedManifest -ManifestPath $path -EngagementId 'ENG-REV40-001' `
                -TargetObjectIds @('obj-id-001') -PhaseLimit 1 } | Should -Throw '*SchemaVersion*'
    }

    It 'Passes (does not throw) on a fully valid manifest' {
        $path = Join-Path $TestDrive 'valid-manifest.json'
        New-TestManifest -Path $path -Overrides @{ ExecutionPhaseApproved = 3 }
        { Confirm-NhiApprovedManifest -ManifestPath $path -EngagementId 'ENG-REV40-001' `
                -TargetObjectIds @('obj-id-001') -PhaseLimit 3 } | Should -Not -Throw
    }
}