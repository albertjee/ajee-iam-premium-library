#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Remediation.psm1 — Rev3.0 ExecutionMap and ManualApproval Registry' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1')  -Force -DisableNameChecking
    }

    AfterAll {
        foreach ($m in @('Remediation','ExecutionLog','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'ExecutionMap maps all 4 AP finding IDs to RemoveAccessPackageAssignment' {
        InModuleScope Remediation {
            $apIds = @('DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008')
            foreach ($id in $apIds) {
                $script:ExecutionMap[$id] | Should -Be 'RemoveAccessPackageAssignment' `
                    -Because "FindingId $id must resolve to RemoveAccessPackageAssignment"
            }
        }
    }

    It 'ExecutionMap maps all 6 PIM finding IDs to RemovePimEligibleAssignment' {
        InModuleScope Remediation {
            $pimIds = @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006')
            foreach ($id in $pimIds) {
                $script:ExecutionMap[$id] | Should -Be 'RemovePimEligibleAssignment' `
                    -Because "FindingId $id must resolve to RemovePimEligibleAssignment"
            }
        }
    }

    It 'ManualApprovalFindingIds includes all 4 AP finding IDs' {
        InModuleScope Remediation {
            foreach ($id in @('DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008')) {
                $script:ManualApprovalFindingIds | Should -Contain $id `
                    -Because "FindingId $id requires manual approval before AP write"
            }
        }
    }

    It 'ManualApprovalFindingIds includes all 6 PIM finding IDs' {
        InModuleScope Remediation {
            foreach ($id in @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006')) {
                $script:ManualApprovalFindingIds | Should -Contain $id `
                    -Because "FindingId $id requires manual approval before PIM write"
            }
        }
    }
}

Describe 'Remediation.psm1 — Rev3.0 AP Write Safety' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1')  -Force -DisableNameChecking

        function script:New-ApTestLog {
            New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-AP' `
                -RunId ([guid]::NewGuid().ToString())
        }
    }

    AfterAll {
        foreach ($m in @('Remediation','ExecutionLog','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'DEC-AP-001 ProtectedObject=true logs Blocked and makes no Remove-Mg calls' {
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = 'user-ap-protected'
            DisplayName     = 'AP Protected User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @('ap-assign-protected-001')
            ProtectedObject = $true
        }
        $log = New-ApTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgEntitlementManagementAssignment -ModuleName Remediation -Exactly 0
    }

    It 'DEC-AP-001 stale assignment (already removed) results in Executed without calling Remove-Mg' {
        Mock -ModuleName Remediation Get-MgEntitlementManagementAssignment { $null }
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = 'user-ap-stale'
            DisplayName     = 'AP Stale User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @('ap-assign-stale-001')
            ProtectedObject = $false
        }
        $log = New-ApTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions[0].Outcome | Should -Be 'Executed'
        Should -Invoke -CommandName Remove-MgEntitlementManagementAssignment -ModuleName Remediation -Exactly 0
    }

    It 'DEC-AP-001 calls Remove-MgEntitlementManagementAssignment exactly once with the approved assignment ID' {
        $assignId = 'ap-assign-approved-001'

        Mock -ModuleName Remediation Get-MgEntitlementManagementAssignment {
            [PSCustomObject]@{ Id = $assignId; TargetId = 'user-ap-live' }
        }
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = 'user-ap-live'
            DisplayName     = 'AP Live User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @($assignId)
            ProtectedObject = $false
        }
        $log = New-ApTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        Should -Invoke -CommandName Remove-MgEntitlementManagementAssignment -ModuleName Remediation -Exactly 1
        Should -Invoke -CommandName Remove-MgEntitlementManagementAssignment -ModuleName Remediation -Exactly 1 `
            -ParameterFilter { $AccessPackageAssignmentId -eq $assignId }
    }

    It 'DEC-AP-001 with AllowNonInteractive=false prompts operator before write' {
        Mock -ModuleName Remediation Read-Host { 'n' }
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = 'user-ap-prompt'
            DisplayName     = 'AP Prompt User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @('ap-assign-prompt-001')
            ProtectedObject = $false
        }
        $log = New-ApTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $false

        $log.Log.Actions[0].Outcome | Should -Be 'OperatorDeclined'
        Should -Invoke -CommandName Remove-MgEntitlementManagementAssignment -ModuleName Remediation -Exactly 0
    }
}

Describe 'Remediation.psm1 — Rev3.0 PIM Write Safety' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1')  -Force -DisableNameChecking

        function script:New-PimTestLog {
            New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-PIM' `
                -RunId ([guid]::NewGuid().ToString())
        }
    }

    AfterAll {
        foreach ($m in @('Remediation','ExecutionLog','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'DEC-PIM-001 ProtectedObject=true logs Blocked and makes no Remove-Mg calls' {
        Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleEligibilitySchedule { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-PIM-001'
            ObjectId        = 'user-pim-protected'
            DisplayName     = 'PIM Protected User'
            ActionType      = 'RemovePimEligibleAssignment'
            TargetObjectIds = @('pim-sched-protected-001')
            ProtectedObject = $true
        }
        $log = New-PimTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleEligibilitySchedule -ModuleName Remediation -Exactly 0
    }

    It 'DEC-PIM-001 PrincipalId mismatch in target validation logs Blocked without write' {
        $userId  = 'user-pim-mismatch'
        $schedId = 'pim-sched-mismatch-001'

        Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleEligibilitySchedule {
            [PSCustomObject]@{ Id = $schedId; PrincipalId = 'wrong-user-999' }
        }
        Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleEligibilitySchedule { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-PIM-001'
            ObjectId        = $userId
            DisplayName     = 'PIM Mismatch User'
            ActionType      = 'RemovePimEligibleAssignment'
            TargetObjectIds = @($schedId)
            ProtectedObject = $false
        }
        $log = New-PimTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleEligibilitySchedule -ModuleName Remediation -Exactly 0
    }

    It 'DEC-PIM-001 calls Remove-MgRoleManagementDirectoryRoleEligibilitySchedule exactly once with the approved schedule ID' {
        $userId  = 'user-pim-live'
        $schedId = 'pim-sched-approved-001'

        Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleEligibilitySchedule {
            [PSCustomObject]@{ Id = $schedId; PrincipalId = $userId }
        }
        Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleEligibilitySchedule { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-PIM-001'
            ObjectId        = $userId
            DisplayName     = 'PIM Live User'
            ActionType      = 'RemovePimEligibleAssignment'
            TargetObjectIds = @($schedId)
            ProtectedObject = $false
        }
        $log = New-PimTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleEligibilitySchedule -ModuleName Remediation -Exactly 1
        Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleEligibilitySchedule -ModuleName Remediation -Exactly 1 `
            -ParameterFilter { $UnifiedRoleEligibilityScheduleId -eq $schedId }
    }

    It 'DEC-PIM-001 with AllowNonInteractive=false prompts operator before write' {
        Mock -ModuleName Remediation Read-Host { 'n' }
        Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleEligibilitySchedule { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-PIM-001'
            ObjectId        = 'user-pim-prompt'
            DisplayName     = 'PIM Prompt User'
            ActionType      = 'RemovePimEligibleAssignment'
            TargetObjectIds = @('pim-sched-prompt-001')
            ProtectedObject = $false
        }
        $log = New-PimTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $false

        $log.Log.Actions[0].Outcome | Should -Be 'OperatorDeclined'
        Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleEligibilitySchedule -ModuleName Remediation -Exactly 0
    }
}
