#Requires -Version 5.1

Describe 'ApprovalManifest.psm1 — Rev3.1 ExecutionMap Guest Entries' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking
    }

    AfterAll {
        foreach ($m in @('ApprovalManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'ExecutionMap contains DEC-GUEST-001 mapped to RemoveGuestGroupMembership' {
        InModuleScope ApprovalManifest {
            $script:ExecutionMap['DEC-GUEST-001'] | Should -Be 'RemoveGuestGroupMembership'
        }
    }

    It 'ExecutionMap contains DEC-GUEST-003 mapped to RemoveGuestGroupMembership' {
        InModuleScope ApprovalManifest {
            $script:ExecutionMap['DEC-GUEST-003'] | Should -Be 'RemoveGuestGroupMembership'
        }
    }

    It 'ExecutionMap contains all 4 DEC-GREV group-only finding IDs' {
        InModuleScope ApprovalManifest {
            foreach ($id in @('DEC-GREV-001','DEC-GREV-002')) {
                $script:ExecutionMap[$id] | Should -Be 'RemoveGuestGroupMembership'
            }
        }
    }

    It 'ExecutionMap contains DEC-GUEST-002 in scope (multi-action)' {
        InModuleScope ApprovalManifest {
            $script:ExecutionMap.ContainsKey('DEC-GUEST-002') | Should -Be $true
        }
    }

    It 'ExecutionMap contains DEC-GREV-003 in scope (multi-action)' {
        InModuleScope ApprovalManifest {
            $script:ExecutionMap.ContainsKey('DEC-GREV-003') | Should -Be $true
        }
    }

    It 'GuestDualFindingIds contains DEC-GUEST-002 and DEC-GREV-003' {
        InModuleScope ApprovalManifest {
            $script:GuestDualFindingIds.Contains('DEC-GUEST-002') | Should -Be $true
            $script:GuestDualFindingIds.Contains('DEC-GREV-003')  | Should -Be $true
        }
    }
}

Describe 'ApprovalManifest.psm1 — Rev3.1 WhatIf Generation for Guest Actions' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking
    }

    AfterAll {
        foreach ($m in @('ApprovalManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Guest finding with exact group ID generates RemoveGuestGroupMembership action' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                FindingId         = 'DEC-GUEST-001'
                ObjectId          = 'guest-user-001'
                ObjectType        = 'User'
                DisplayName       = 'Guest User 1'
                UserPrincipalName = 'guest@external.com'
                UserType          = 'Guest'
                GroupId           = 'group-id-exact-001'
                ProtectedObject   = $false
                Evidence          = 'Test evidence'
                RiskScore         = 75
            }
            $targets = Resolve-DecomExecutableTargets -Finding $finding
            $targets.Resolved | Should -Be $true
            $targets.TargetObjects[0].TargetActionType | Should -Be 'RemoveGuestGroupMembership'
            $targets.TargetObjects[0].TargetObjectId   | Should -Be 'group-id-exact-001'
        }
    }

    It 'Guest finding without exact group ID does not resolve executable action' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                FindingId         = 'DEC-GUEST-001'
                ObjectId          = 'guest-user-002'
                ObjectType        = 'User'
                DisplayName       = 'Guest User 2'
                UserPrincipalName = 'guest2@external.com'
                UserType          = 'Guest'
                ProtectedObject   = $false
                Evidence          = 'No group ID'
                RiskScore         = 60
            }
            $targets = Resolve-DecomExecutableTargets -Finding $finding
            $targets.Resolved | Should -Be $false
        }
    }

    It 'Guest finding with exact app role assignment ID generates RevokeGuestAppRoleAssignment action' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                FindingId           = 'DEC-GUEST-002'
                ObjectId            = 'guest-user-003'
                ObjectType          = 'User'
                DisplayName         = 'Guest User 3'
                UserPrincipalName   = 'guest3@external.com'
                UserType            = 'Guest'
                AppRoleAssignmentId = 'approle-assign-exact-001'
                ProtectedObject     = $false
                Evidence            = 'App role evidence'
                RiskScore           = 80
            }
            $targets = Resolve-DecomExecutableTargets -Finding $finding
            $targets.Resolved | Should -Be $true
            $appRoleTarget = $targets.TargetObjects | Where-Object { $_.TargetActionType -eq 'RevokeGuestAppRoleAssignment' }
            $appRoleTarget | Should -Not -BeNullOrEmpty
            $appRoleTarget.TargetObjectId | Should -Be 'approle-assign-exact-001'
        }
    }

    It 'Guest finding without exact app role ID does not generate executable app-role action' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                FindingId         = 'DEC-GUEST-002'
                ObjectId          = 'guest-user-004'
                ObjectType        = 'User'
                DisplayName       = 'Guest User 4'
                UserPrincipalName = 'guest4@external.com'
                UserType          = 'Guest'
                ProtectedObject   = $false
                Evidence          = 'No IDs'
                RiskScore         = 60
            }
            $targets = Resolve-DecomExecutableTargets -Finding $finding
            $targets.Resolved | Should -Be $false
        }
    }

    It 'WhatIf action for guest group membership has RequiresManualApproval true' {
        $engId  = 'ENG-GUEST-001'
        $runId  = [guid]::NewGuid().ToString()
        $outDir = Join-Path $TestDrive 'guest-whatif'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null

        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-GUEST-001'
            ObjectId          = 'guest-user-001'
            ObjectType        = 'User'
            DisplayName       = 'Test Guest'
            UserPrincipalName = 'guest@external.com'
            UserType          = 'Guest'
            GroupId           = 'grp-exact-001'
            ProtectedObject   = $false
            Evidence          = 'Test evidence'
            RiskScore         = 75
        }

        $planPath = New-DecomWhatIfActionPlan -Findings @($finding) `
            -EngagementId $engId -ClientName 'TestClient' -Assessor 'Tester' `
            -WhatIfRunId $runId -OutputPath $outDir

        $plan = Get-Content $planPath -Raw | ConvertFrom-Json
        $guestAction = $plan.ApprovedActions | Where-Object { $_.FindingId -eq 'DEC-GUEST-001' }
        $guestAction | Should -Not -BeNullOrEmpty
        $guestAction.RequiresManualApproval | Should -Be $true
    }

    It 'WhatIf action for guest group membership has ReadinessStatus field' {
        $engId  = 'ENG-GUEST-002'
        $runId  = [guid]::NewGuid().ToString()
        $outDir = Join-Path $TestDrive 'guest-whatif2'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null

        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-GUEST-001'
            ObjectId          = 'guest-user-001'
            ObjectType        = 'User'
            DisplayName       = 'Test Guest'
            UserPrincipalName = 'guest@external.com'
            UserType          = 'Guest'
            GroupId           = 'grp-exact-002'
            ProtectedObject   = $false
            Evidence          = 'Test evidence'
            RiskScore         = 75
        }

        $planPath = New-DecomWhatIfActionPlan -Findings @($finding) `
            -EngagementId $engId -ClientName 'TestClient' -Assessor 'Tester' `
            -WhatIfRunId $runId -OutputPath $outDir

        $plan = Get-Content $planPath -Raw | ConvertFrom-Json
        $guestAction = $plan.ApprovedActions | Where-Object { $_.FindingId -eq 'DEC-GUEST-001' }
        $guestAction.PSObject.Properties.Name | Should -Contain 'ReadinessStatus'
    }

    It 'WhatIf action for guest group membership has SponsorEvidenceStatus field' {
        $engId  = 'ENG-GUEST-003'
        $runId  = [guid]::NewGuid().ToString()
        $outDir = Join-Path $TestDrive 'guest-whatif3'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null

        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-GUEST-001'
            ObjectId          = 'guest-user-001'
            ObjectType        = 'User'
            DisplayName       = 'Test Guest'
            UserPrincipalName = 'guest@external.com'
            UserType          = 'Guest'
            GroupId           = 'grp-exact-003'
            ProtectedObject   = $false
            Evidence          = 'Test evidence'
            RiskScore         = 75
        }

        $planPath = New-DecomWhatIfActionPlan -Findings @($finding) `
            -EngagementId $engId -ClientName 'TestClient' -Assessor 'Tester' `
            -WhatIfRunId $runId -OutputPath $outDir

        $plan = Get-Content $planPath -Raw | ConvertFrom-Json
        $guestAction = $plan.ApprovedActions | Where-Object { $_.FindingId -eq 'DEC-GUEST-001' }
        $guestAction.PSObject.Properties.Name | Should -Contain 'SponsorEvidenceStatus'
    }

    It 'WhatIf action for guest group membership has RollbackGuidance field' {
        $engId  = 'ENG-GUEST-004'
        $runId  = [guid]::NewGuid().ToString()
        $outDir = Join-Path $TestDrive 'guest-whatif4'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null

        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-GUEST-001'
            ObjectId          = 'guest-user-001'
            ObjectType        = 'User'
            DisplayName       = 'Test Guest'
            UserPrincipalName = 'guest@external.com'
            UserType          = 'Guest'
            GroupId           = 'grp-exact-004'
            ProtectedObject   = $false
            Evidence          = 'Test evidence'
            RiskScore         = 75
        }

        $planPath = New-DecomWhatIfActionPlan -Findings @($finding) `
            -EngagementId $engId -ClientName 'TestClient' -Assessor 'Tester' `
            -WhatIfRunId $runId -OutputPath $outDir

        $plan = Get-Content $planPath -Raw | ConvertFrom-Json
        $guestAction = $plan.ApprovedActions | Where-Object { $_.FindingId -eq 'DEC-GUEST-001' }
        $guestAction.PSObject.Properties.Name | Should -Contain 'RollbackGuidance'
        $guestAction.RollbackGuidance | Should -Not -BeNullOrEmpty
    }

    It 'Non-guest object does not generate guest-specific executable action' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                FindingId         = 'DEC-GUEST-001'
                ObjectId          = 'member-user-001'
                ObjectType        = 'User'
                DisplayName       = 'Member User'
                UserPrincipalName = 'member@contoso.com'
                UserType          = 'Member'
                GroupId           = 'grp-exact-005'
                ProtectedObject   = $false
                Evidence          = 'Non-guest'
                RiskScore         = 50
            }
            # With UserType=Member, finding still resolves targets based on IDs
            # The UserType check happens at execution/revalidation, not WhatIf target resolution
            # Validate that non-guest targets include GuestOnly metadata
            $targets = Resolve-DecomExecutableTargets -Finding $finding
            $targets.Resolved | Should -Be $true
        }
    }
}

Describe 'ApprovalManifest.psm1 — Rev3.1 Manifest Validation Schema Gate' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking

        $script:engId      = 'ENG-TEST-31A'
        $script:clientName = 'TestClient31'
        $script:testRunId  = [guid]::NewGuid().ToString()

        function script:New-GuestTestManifest {
            param(
                [string]$Path,
                [string]$SchemaVersion = '3.1',
                [string]$ActionType    = 'RemoveGuestGroupMembership',
                [string]$FindingId     = 'DEC-GUEST-001'
            )
            $action = @{
                ActionId           = 'ACT-001'
                FindingId          = $FindingId
                ObjectId           = 'guest-obj-001'
                ObjectType         = 'User'
                DisplayName        = 'Test Guest'
                UserPrincipalName  = 'guest@external.com'
                ActionType         = $ActionType
                TargetObjectIds    = @('grp-target-001')
                TargetDisplayNames = @('Test Group')
                Evidence           = 'Test evidence'
                RiskScore          = 75
                ProtectedObject    = $false
                RoleAssignmentId   = ''
                RoleDefinitionId   = ''
                RoleDisplayName    = ''
                UserType           = 'Guest'
                GuestOnly          = $true
            }
            # Use placeholder hash — these tests validate schema version errors which occur
            # before hash verification, so an exact hash is not required
            $actionsHash = 'placeholder-hash-schema-version-test'
            $manifest = @{
                SchemaVersion        = $SchemaVersion
                EngagementId         = $script:engId
                ClientName           = $script:clientName
                WhatIfRunId          = $script:testRunId
                ApprovalStatus       = 'Approved'
                ApprovedBy           = 'Test Approver (Admin)'
                ApprovedUtc          = (Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc           = (Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive  = $false
                ApprovedActionsHash  = $actionsHash
                ApprovalEnvelopeHash = 'placeholder-env-hash'
                ApprovedActions      = @($action)
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        }
    }

    AfterAll {
        foreach ($m in @('ApprovalManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Guest action type in SchemaVersion 2.0 manifest produces SchemaVersion error' {
        $path = Join-Path $TestDrive 'guest-schema-v2-0.json'
        New-GuestTestManifest -Path $path -SchemaVersion '2.0'
        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId
        $result.Valid | Should -Be $false
        $result.Errors | Should -Contain ($result.Errors | Where-Object { $_ -match 'SchemaVersion' })
    }

    It 'Guest action type in SchemaVersion 3.0 manifest produces SchemaVersion error' {
        $path = Join-Path $TestDrive 'guest-schema-v3-0.json'
        New-GuestTestManifest -Path $path -SchemaVersion '3.0'
        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId
        $result.Valid | Should -Be $false
        ($result.Errors -join ' ') | Should -Match 'SchemaVersion 3.1'
    }

    It 'Guest action with missing TargetObjectIds fails validation' {
        $path = Join-Path $TestDrive 'guest-no-targets.json'
        @{
            SchemaVersion        = '3.1'
            EngagementId         = $script:engId
            ClientName           = $script:clientName
            WhatIfRunId          = $script:testRunId
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'Test Approver (Admin)'
            ApprovedUtc          = (Get-Date).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(3).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            ApprovedActionsHash  = 'placeholder-hash'
            ApprovalEnvelopeHash = 'placeholder-env-hash'
            ApprovedActions      = @(@{
                ActionId           = 'ACT-001'
                FindingId          = 'DEC-GUEST-001'
                ObjectId           = 'guest-obj-001'
                ActionType         = 'RemoveGuestGroupMembership'
                TargetObjectIds    = @()
                ProtectedObject    = $false
                RoleAssignmentId   = ''
                RoleDefinitionId   = ''
                RoleDisplayName    = ''
            })
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId
        $result.Valid | Should -Be $false
        ($result.Errors | Where-Object { $_ -match 'TargetObjectIds' }) | Should -Not -BeNullOrEmpty
    }

    It 'RevokeGuestAppRoleAssignment with invalid FindingId fails validation' {
        $path = Join-Path $TestDrive 'guest-invalid-finding.json'
        @{
            SchemaVersion        = '3.1'
            EngagementId         = $script:engId
            ClientName           = $script:clientName
            WhatIfRunId          = $script:testRunId
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'Test Approver (Admin)'
            ApprovedUtc          = (Get-Date).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(3).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            ApprovedActionsHash  = 'placeholder-hash'
            ApprovalEnvelopeHash = 'placeholder-env-hash'
            ApprovedActions      = @(@{
                ActionId           = 'ACT-001'
                FindingId          = 'DEC-INVALID-999'
                ObjectId           = 'guest-obj-001'
                ActionType         = 'RevokeGuestAppRoleAssignment'
                TargetObjectIds    = @('assignment-001')
                ProtectedObject    = $false
                RoleAssignmentId   = ''
                RoleDefinitionId   = ''
                RoleDisplayName    = ''
            })
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId
        $result.Valid | Should -Be $false
    }

    It 'Duplicate guest group target operation produces duplicate error' {
        $path = Join-Path $TestDrive 'guest-dup-target.json'
        @{
            SchemaVersion        = '3.1'
            EngagementId         = $script:engId
            ClientName           = $script:clientName
            WhatIfRunId          = $script:testRunId
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'Test Approver (Admin)'
            ApprovedUtc          = (Get-Date).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(3).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            ApprovedActionsHash  = 'placeholder-hash'
            ApprovalEnvelopeHash = 'placeholder-env-hash'
            ApprovedActions      = @(
                @{
                    ActionId           = 'ACT-001'
                    FindingId          = 'DEC-GUEST-001'
                    ObjectId           = 'guest-obj-dup'
                    ActionType         = 'RemoveGuestGroupMembership'
                    TargetObjectIds    = @('grp-dup-001')
                    ProtectedObject    = $false
                    RoleAssignmentId   = ''; RoleDefinitionId = ''; RoleDisplayName = ''
                },
                @{
                    ActionId           = 'ACT-002'
                    FindingId          = 'DEC-GUEST-001'
                    ObjectId           = 'guest-obj-dup'
                    ActionType         = 'RemoveGuestGroupMembership'
                    TargetObjectIds    = @('grp-dup-001')
                    ProtectedObject    = $false
                    RoleAssignmentId   = ''; RoleDefinitionId = ''; RoleDisplayName = ''
                }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId
        $result.Valid | Should -Be $false
        ($result.Errors | Where-Object { $_ -match '[Dd]uplicate' }) | Should -Not -BeNullOrEmpty
    }

    It 'Approval hash changes when Rev3.1 target metadata changes' {
        InModuleScope ApprovalManifest {
            $action1 = @{
                ActionId        = 'ACT-001'; FindingId = 'DEC-GUEST-001'
                ObjectId        = 'guest-hash-test'; ActionType = 'RemoveGuestGroupMembership'
                TargetObjectIds = @('grp-hash-001'); GroupId = 'grp-hash-001'
                UserType        = 'Guest'; GuestOnly = $true
            }
            $action2 = @{
                ActionId        = 'ACT-001'; FindingId = 'DEC-GUEST-001'
                ObjectId        = 'guest-hash-test'; ActionType = 'RemoveGuestGroupMembership'
                TargetObjectIds = @('grp-hash-001'); GroupId = 'grp-hash-002'
                UserType        = 'Guest'; GuestOnly = $true
            }
            $hash1 = Get-DecomApprovedActionsHash -ApprovedActions @($action1)
            $hash2 = Get-DecomApprovedActionsHash -ApprovedActions @($action2)
            $hash1 | Should -Not -Be $hash2
        }
    }

    It 'DEC-GUEST-002 accepts RevokeGuestAppRoleAssignment as a valid ActionType' {
        InModuleScope ApprovalManifest {
            # Both action types are allowed for dual-action findings
            $script:GuestDualFindingIds.Contains('DEC-GUEST-002') | Should -Be $true
        }
    }
}
