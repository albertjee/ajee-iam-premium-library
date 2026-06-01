#Requires -Version 5.1

Describe 'ApprovalManifest.psm1 — Rev3.1 Get-DecomFindingExactTargetIds Guest Support' {

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

    It 'Get-DecomFindingExactTargetIds extracts GroupId for GuestGroupMembership' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                GroupId = 'grp-exact-001'
            }
            $ids = Get-DecomFindingExactTargetIds -Finding $finding -FindingType 'GuestGroupMembership'
            $ids | Should -Contain 'grp-exact-001'
        }
    }

    It 'Get-DecomFindingExactTargetIds extracts TargetGroupId for GuestGroupMembership' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                TargetGroupId = 'grp-target-001'
            }
            $ids = Get-DecomFindingExactTargetIds -Finding $finding -FindingType 'GuestGroupMembership'
            $ids | Should -Contain 'grp-target-001'
        }
    }

    It 'Get-DecomFindingExactTargetIds returns empty for GuestGroupMembership with no IDs' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                DisplayName = 'No group ID here'
            }
            $ids = Get-DecomFindingExactTargetIds -Finding $finding -FindingType 'GuestGroupMembership'
            $ids.Count | Should -Be 0
        }
    }

    It 'Get-DecomFindingExactTargetIds extracts AppRoleAssignmentId for GuestAppRoleAssignment' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                AppRoleAssignmentId = 'approle-exact-001'
            }
            $ids = Get-DecomFindingExactTargetIds -Finding $finding -FindingType 'GuestAppRoleAssignment'
            $ids | Should -Contain 'approle-exact-001'
        }
    }

    It 'Get-DecomFindingExactTargetIds returns empty for GuestAppRoleAssignment with no IDs' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                ResourceDisplayName = 'Teams — no assignment ID'
            }
            $ids = Get-DecomFindingExactTargetIds -Finding $finding -FindingType 'GuestAppRoleAssignment'
            $ids.Count | Should -Be 0
        }
    }

    It 'Get-DecomFindingExactTargetIds does not return display names as target IDs' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                GroupDisplayName = 'My Group'
                UserPrincipalName = 'guest@external.com'
            }
            $ids = Get-DecomFindingExactTargetIds -Finding $finding -FindingType 'GuestGroupMembership'
            $ids.Count | Should -Be 0
        }
    }
}

Describe 'ApprovalManifest.psm1 — Rev3.1 WhatIf Remediation Readiness Status' {

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

    It 'Missing exact target IDs result in PlanOnly/skipped action in WhatIf plan' {
        $engId  = 'ENG-PLAN-001'
        $runId  = [guid]::NewGuid().ToString()
        $outDir = Join-Path $TestDrive 'plan-only'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null

        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-GUEST-001'
            ObjectId          = 'guest-no-target'
            ObjectType        = 'User'
            DisplayName       = 'Guest No Target'
            UserPrincipalName = 'guest@external.com'
            UserType          = 'Guest'
            ProtectedObject   = $false
            Evidence          = 'No group ID'
            RiskScore         = 60
        }

        $planPath = New-DecomWhatIfActionPlan -Findings @($finding) `
            -EngagementId $engId -ClientName 'TestClient' -Assessor 'Tester' `
            -WhatIfRunId $runId -OutputPath $outDir

        $plan = Get-Content $planPath -Raw | ConvertFrom-Json
        $plan.ApprovedActions.Count | Should -Be 0
        ($plan.SkippedActions + $plan.PlanOnlyActions).Count | Should -BeGreaterThan 0
    }

    It 'Protected guest becomes BlockedProtectedObject in WhatIf skipped list' {
        $engId  = 'ENG-PLAN-002'
        $runId  = [guid]::NewGuid().ToString()
        $outDir = Join-Path $TestDrive 'plan-protected'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null

        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-GUEST-001'
            ObjectId          = 'guest-protected'
            ObjectType        = 'User'
            DisplayName       = 'Protected Guest'
            UserPrincipalName = 'pguest@external.com'
            UserType          = 'Guest'
            GroupId           = 'grp-exact-protected'
            ProtectedObject   = $true
            Evidence          = 'Protected'
            RiskScore         = 90
        }

        $planPath = New-DecomWhatIfActionPlan -Findings @($finding) `
            -EngagementId $engId -ClientName 'TestClient' -Assessor 'Tester' `
            -WhatIfRunId $runId -OutputPath $outDir

        $plan = Get-Content $planPath -Raw | ConvertFrom-Json
        $plan.ApprovedActions.Count | Should -Be 0
        $skippedEntry = $plan.SkippedActions | Where-Object { $_.Reason -eq 'ProtectedObject' }
        $skippedEntry | Should -Not -BeNullOrEmpty
    }

    It 'WhatIf action ReviewEvidenceStatus is Unknown when no review evidence present' {
        $engId  = 'ENG-PLAN-003'
        $runId  = [guid]::NewGuid().ToString()
        $outDir = Join-Path $TestDrive 'plan-review'
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null

        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-GUEST-001'
            ObjectId          = 'guest-noreview'
            ObjectType        = 'User'
            DisplayName       = 'Guest No Review'
            UserPrincipalName = 'noreview@external.com'
            UserType          = 'Guest'
            GroupId           = 'grp-noreview-001'
            ProtectedObject   = $false
            Evidence          = 'Test'
            RiskScore         = 65
        }

        $planPath = New-DecomWhatIfActionPlan -Findings @($finding) `
            -EngagementId $engId -ClientName 'TestClient' -Assessor 'Tester' `
            -WhatIfRunId $runId -OutputPath $outDir

        $plan = Get-Content $planPath -Raw | ConvertFrom-Json
        $guestAction = $plan.ApprovedActions | Where-Object { $_.FindingId -eq 'DEC-GUEST-001' }
        $guestAction.ReviewEvidenceStatus | Should -Be 'Unknown'
    }
}
