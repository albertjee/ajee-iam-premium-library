#Requires -Version 5.1

Describe 'ApprovalManifest.psm1 — Rev3.0 ExecutionMap' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
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

    It 'ApprovalManifest ExecutionMap contains all 4 AP finding IDs' {
        InModuleScope ApprovalManifest {
            foreach ($id in @('DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008')) {
                $script:ExecutionMap.ContainsKey($id) | Should -Be $true `
                    -Because "FindingId $id must be in ApprovalManifest ExecutionMap for WhatIf plan generation"
            }
        }
    }

    It 'ApprovalManifest ExecutionMap maps all 4 AP finding IDs to RemoveAccessPackageAssignment' {
        InModuleScope ApprovalManifest {
            foreach ($id in @('DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008')) {
                $script:ExecutionMap[$id] | Should -Be 'RemoveAccessPackageAssignment' `
                    -Because "FindingId $id must resolve to RemoveAccessPackageAssignment"
            }
        }
    }

    It 'ApprovalManifest ExecutionMap contains all 6 PIM finding IDs' {
        InModuleScope ApprovalManifest {
            foreach ($id in @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006')) {
                $script:ExecutionMap.ContainsKey($id) | Should -Be $true `
                    -Because "FindingId $id must be in ApprovalManifest ExecutionMap for WhatIf plan generation"
            }
        }
    }

    It 'ApprovalManifest ExecutionMap maps all 6 PIM finding IDs to RemovePimEligibleAssignment' {
        InModuleScope ApprovalManifest {
            foreach ($id in @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006')) {
                $script:ExecutionMap[$id] | Should -Be 'RemovePimEligibleAssignment' `
                    -Because "FindingId $id must resolve to RemovePimEligibleAssignment"
            }
        }
    }
}

Describe 'ApprovalManifest.psm1 — Rev3.0 SchemaVersion Gate' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking

        $script:engId      = 'ENG-TEST-30A'
        $script:clientName = 'TestClient30'
        $script:testRunId  = [guid]::NewGuid().ToString()

        function script:Write-TestApprovalManifest {
            param(
                [string]$Path,
                [string]$SchemaVersion = '3.0',
                [string]$ActionType    = 'RemoveGroupMembership',
                [string]$FindingId     = 'DEC-USER-001'
            )
            @{
                SchemaVersion        = $SchemaVersion
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
                        FindingId          = $FindingId
                        ObjectId           = 'user-test-001'
                        ObjectType         = 'User'
                        DisplayName        = 'Test User'
                        UserPrincipalName  = 'test@contoso.com'
                        ActionType         = $ActionType
                        TargetObjectIds    = @('target-001')
                        TargetDisplayNames = @('Target Group 1')
                        Evidence           = 'Test evidence'
                        RiskScore          = 70
                        ProtectedObject    = $false
                        RoleAssignmentId   = ''
                        RoleDefinitionId   = ''
                        RoleDisplayName    = ''
                    }
                )
            } | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        }
    }

    AfterAll {
        foreach ($m in @('ApprovalManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'AP action type in SchemaVersion 2.0 manifest produces SchemaVersion error' {
        $path = Join-Path $TestDrive 'ap-schema-v2-0.json'
        Write-TestApprovalManifest -Path $path -SchemaVersion '2.0' `
            -ActionType 'RemoveAccessPackageAssignment' -FindingId 'DEC-AP-001'

        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId

        $result.Valid | Should -Be $false
        $result.Errors | Should -Contain `
            "Rev3.0 action types (AP/PIM) require approval manifest SchemaVersion 3.0 or higher (found: 2.0)"
    }

    It 'PIM action type in SchemaVersion 2.5 manifest produces SchemaVersion error' {
        $path = Join-Path $TestDrive 'pim-schema-v2-5.json'
        Write-TestApprovalManifest -Path $path -SchemaVersion '2.5' `
            -ActionType 'RemovePimEligibleAssignment' -FindingId 'DEC-PIM-001'

        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId

        $result.Valid | Should -Be $false
        $result.Errors | Should -Contain `
            "Rev3.0 action types (AP/PIM) require approval manifest SchemaVersion 3.0 or higher (found: 2.5)"
    }

    It 'AP action type in SchemaVersion 3.0 manifest does not produce SchemaVersion error' {
        $path = Join-Path $TestDrive 'ap-schema-v3-0.json'
        Write-TestApprovalManifest -Path $path -SchemaVersion '3.0' `
            -ActionType 'RemoveAccessPackageAssignment' -FindingId 'DEC-AP-001'

        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId

        $result.Errors | Should -Not -Contain `
            "Rev3.0 action types (AP/PIM) require approval manifest SchemaVersion 3.0 or higher (found: 3.0)"
    }

    It 'Rev2.0 action type (RemoveGroupMembership) in SchemaVersion 2.0 manifest does not produce SchemaVersion error' {
        $path = Join-Path $TestDrive 'rev2-action-schema-v2-0.json'
        Write-TestApprovalManifest -Path $path -SchemaVersion '2.0' `
            -ActionType 'RemoveGroupMembership' -FindingId 'DEC-USER-001'

        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $script:testRunId

        $schemaVersionErrors = @($result.Errors | Where-Object {
            $_ -match 'Rev3\.0 action types.*SchemaVersion'
        })
        $schemaVersionErrors.Count | Should -Be 0
    }
}

Describe 'ApprovalManifest.psm1 — Rev3.0 Hash Functions' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
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

    It 'Get-DecomSha256 returns a 64-character lowercase hexadecimal string' {
        InModuleScope ApprovalManifest {
            $hash = Get-DecomSha256 -InputString 'Rev3.0-test-input'
            $hash.Length | Should -Be 64
            $hash | Should -Match '^[0-9a-f]+$'
        }
    }

    It 'Get-DecomApprovedActionsHash is deterministic for identical input' {
        InModuleScope ApprovalManifest {
            $action = [PSCustomObject]@{
                ActionId = 'ACT-001'; FindingId = 'DEC-USER-001'; ObjectId = 'user-001'
                ObjectType = 'User'; DisplayName = 'Test'; UserPrincipalName = 'u@t.com'
                ActionType = 'RemoveGroupMembership'; TargetObjectIds = @('grp-001')
                TargetDisplayNames = @('G1'); Evidence = 'e'; RiskScore = 70
                ProtectedObject = $false; RoleAssignmentId = ''; RoleDefinitionId = ''; RoleDisplayName = ''
            }
            $hash1 = Get-DecomApprovedActionsHash -ApprovedActions @($action)
            $hash2 = Get-DecomApprovedActionsHash -ApprovedActions @($action)
            $hash1 | Should -Be $hash2
            $hash1.Length | Should -Be 64
        }
    }

    It 'Get-DecomApprovedActionsHash produces different hash when ObjectId changes' {
        InModuleScope ApprovalManifest {
            $baseProps = @{
                ActionId = 'ACT-001'; FindingId = 'DEC-USER-001'; ObjectType = 'User'
                DisplayName = 'Test'; UserPrincipalName = 'u@t.com'
                ActionType = 'RemoveGroupMembership'; TargetObjectIds = @('grp-001')
                TargetDisplayNames = @('G1'); Evidence = 'e'; RiskScore = 70
                ProtectedObject = $false; RoleAssignmentId = ''; RoleDefinitionId = ''; RoleDisplayName = ''
            }
            $action1 = [PSCustomObject]($baseProps + @{ ObjectId = 'user-001' })
            $action2 = [PSCustomObject]($baseProps + @{ ObjectId = 'user-002' })
            $hash1 = Get-DecomApprovedActionsHash -ApprovedActions @($action1)
            $hash2 = Get-DecomApprovedActionsHash -ApprovedActions @($action2)
            $hash1 | Should -Not -Be $hash2
        }
    }
}
