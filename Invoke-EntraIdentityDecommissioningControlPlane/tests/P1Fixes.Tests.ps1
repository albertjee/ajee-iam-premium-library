#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

# ─── P1-01: AP TargetId Principal Binding (Invoke-DecomRemediation) ─────────

Describe 'P1-01 — AP TargetId Principal Binding' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1')  -Force -DisableNameChecking

        function script:New-P101Log {
            New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-P101' `
                -RunId ([guid]::NewGuid().ToString())
        }
    }

    AfterAll {
        foreach ($m in @('Remediation','ExecutionLog','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'AP assignment PrincipalId/TargetId mismatch blocks action' {
        $userId   = 'user-ap-p101-mismatch'
        $assignId = 'ap-assign-mismatch-001'

        Mock -ModuleName Remediation Get-MgEntitlementManagementAssignment {
            [PSCustomObject]@{ Id = $assignId; TargetId = 'different-user-999' }
        }
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = $userId
            DisplayName     = 'AP Mismatch User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @($assignId)
            ProtectedObject = $false
        }
        $log = New-P101Log
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgEntitlementManagementAssignment -ModuleName Remediation -Exactly 0
    }

    It 'AP assignment read failure blocks action' {
        $userId   = 'user-ap-p101-readfail'
        $assignId = 'ap-assign-readfail-001'

        Mock -ModuleName Remediation Get-MgEntitlementManagementAssignment {
            throw 'Simulated Graph connection failure'
        }
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = $userId
            DisplayName     = 'AP Read Fail User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @($assignId)
            ProtectedObject = $false
        }
        $log = New-P101Log
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgEntitlementManagementAssignment -ModuleName Remediation -Exactly 0
    }

    It 'AP assignment missing target principal blocks action' {
        $userId   = 'user-ap-p101-notarget'
        $assignId = 'ap-assign-notarget-001'

        Mock -ModuleName Remediation Get-MgEntitlementManagementAssignment {
            # Returns assignment with no TargetId, Target, or AdditionalProperties
            [PSCustomObject]@{ Id = $assignId }
        }
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = $userId
            DisplayName     = 'AP No Target User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @($assignId)
            ProtectedObject = $false
        }
        $log = New-P101Log
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgEntitlementManagementAssignment -ModuleName Remediation -Exactly 0
    }
}

# ─── P1-02: AP/PIM Read Failure Sets Valid=false (Confirm-DecomActionTargetValid) ─

Describe 'P1-02 — AP/PIM Read Failure in Confirm-DecomActionTargetValid' {

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

    It 'RemoveAccessPackageAssignment read failure sets Valid=false' {
        $assignId = 'ap-assign-p102-fail-001'

        Mock -ModuleName Remediation Get-MgEntitlementManagementAssignment {
            throw 'Simulated AP read failure'
        }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = 'user-ap-p102'
            DisplayName     = 'P1-02 AP User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @($assignId)
            ProtectedObject = $false
        }

        $result = Confirm-DecomActionTargetValid -Action $action

        $result.Valid                   | Should -Be $false
        $result.ValidationErrors.Count  | Should -BeGreaterThan 0
    }

    It 'RemovePimEligibleAssignment read failure sets Valid=false' {
        $schedId = 'pim-sched-p102-fail-001'

        Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleEligibilitySchedule {
            throw 'Simulated PIM read failure'
        }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-PIM-001'
            ObjectId        = 'user-pim-p102'
            DisplayName     = 'P1-02 PIM User'
            ActionType      = 'RemovePimEligibleAssignment'
            TargetObjectIds = @($schedId)
            ProtectedObject = $false
        }

        $result = Confirm-DecomActionTargetValid -Action $action

        $result.Valid                   | Should -Be $false
        $result.ValidationErrors.Count  | Should -BeGreaterThan 0
    }
}

# ─── P1-03: Exact-ID Only Resolution (Resolve-DecomExecutableTargets) ────────

Describe 'P1-03 — Exact-ID Only Resolution in ApprovalManifest' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'ApprovalManifest.psm1') -Force -DisableNameChecking
    }

    AfterAll {
        foreach ($m in @('ApprovalManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'DEC-AP finding without exact assignment ID does not generate executable action' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                FindingId   = 'DEC-AP-001'
                ObjectId    = 'user-p103-no-ap-id'
                DisplayName = 'No AP ID User'
            }
            $result = Resolve-DecomExecutableTargets -Finding $finding
            $result.Resolved    | Should -Be $false
            $result.ErrorDetail | Should -Match 'broad principal query not permitted'
        }
    }

    It 'DEC-PIM finding without exact eligible assignment ID does not generate executable action' {
        InModuleScope ApprovalManifest {
            $finding = [PSCustomObject]@{
                FindingId   = 'DEC-PIM-001'
                ObjectId    = 'user-p103-no-pim-id'
                DisplayName = 'No PIM ID User'
            }
            $result = Resolve-DecomExecutableTargets -Finding $finding
            $result.Resolved    | Should -Be $false
            $result.ErrorDetail | Should -Match 'broad principal query not permitted'
        }
    }

    It 'DEC-AP finding with exact assignment ID generates only that target' {
        InModuleScope ApprovalManifest {
            $assignId = 'exact-ap-assign-p103-001'
            $finding = [PSCustomObject]@{
                FindingId                 = 'DEC-AP-001'
                ObjectId                  = 'user-p103-exact-ap'
                DisplayName               = 'Exact AP User'
                AccessPackageAssignmentId = $assignId
            }
            $result = Resolve-DecomExecutableTargets -Finding $finding
            $result.Resolved                        | Should -Be $true
            $result.TargetObjects.Count             | Should -Be 1
            $result.TargetObjects[0].TargetObjectId | Should -Be $assignId
        }
    }

    It 'DEC-PIM finding with exact schedule ID generates only that target' {
        InModuleScope ApprovalManifest {
            $schedId = 'exact-pim-sched-p103-001'
            $finding = [PSCustomObject]@{
                FindingId             = 'DEC-PIM-001'
                ObjectId              = 'user-p103-exact-pim'
                DisplayName           = 'Exact PIM User'
                EligibilityScheduleId = $schedId
            }
            $result = Resolve-DecomExecutableTargets -Finding $finding
            $result.Resolved                        | Should -Be $true
            $result.TargetObjects.Count             | Should -Be 1
            $result.TargetObjects[0].TargetObjectId | Should -Be $schedId
        }
    }
}

# ─── P1-04: Post-Write Re-Query State (Invoke-DecomRemediation) ──────────────

Describe 'P1-04 — Post-Write Re-Query State' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1')  -Force -DisableNameChecking

        function script:New-P104ApLog {
            New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-P104AP' `
                -RunId ([guid]::NewGuid().ToString())
        }
        function script:New-P104PimLog {
            New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-P104PIM' `
                -RunId ([guid]::NewGuid().ToString())
        }
    }

    AfterAll {
        foreach ($m in @('Remediation','ExecutionLog','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'AP post-write re-query failure does not log Executed' {
        $assignId  = 'ap-assign-p104-fail-001'
        $userId    = 'user-ap-p104-fail'

        # Hashtable counter — reference type captured by mock closure
        $stateCounter = @{ n = 0 }
        Mock -ModuleName Remediation Get-DecomTargetState {
            $stateCounter.n++
            if ($stateCounter.n -le 1) {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @($assignId); ErrorDetail = '' }
            } else {
                [PSCustomObject]@{ QuerySucceeded = $false; PresentTargetIds = @(); ErrorDetail = 'Simulated re-query failure' }
            }
        }
        Mock -ModuleName Remediation Get-MgEntitlementManagementAssignment {
            [PSCustomObject]@{ Id = $assignId; TargetId = $userId }
        }
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = $userId
            DisplayName     = 'AP Re-Query Fail User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @($assignId)
            ProtectedObject = $false
        }
        $log = New-P104ApLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions[0].Outcome | Should -Not -Be 'Executed'
        $log.Log.Actions[0].Outcome | Should -Be 'PartialFailed'
    }

    It 'PIM post-write re-query failure does not log Executed' {
        $schedId = 'pim-sched-p104-fail-001'
        $userId  = 'user-pim-p104-fail'

        $stateCounter = @{ n = 0 }
        Mock -ModuleName Remediation Get-DecomTargetState {
            $stateCounter.n++
            if ($stateCounter.n -le 1) {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @($schedId); ErrorDetail = '' }
            } else {
                [PSCustomObject]@{ QuerySucceeded = $false; PresentTargetIds = @(); ErrorDetail = 'Simulated PIM re-query failure' }
            }
        }
        Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleEligibilitySchedule {
            [PSCustomObject]@{ Id = $schedId; PrincipalId = $userId }
        }
        Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleEligibilitySchedule { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-PIM-001'
            ObjectId        = $userId
            DisplayName     = 'PIM Re-Query Fail User'
            ActionType      = 'RemovePimEligibleAssignment'
            TargetObjectIds = @($schedId)
            ProtectedObject = $false
        }
        $log = New-P104PimLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions[0].Outcome | Should -Not -Be 'Executed'
        $log.Log.Actions[0].Outcome | Should -Be 'PartialFailed'
    }

    It 'AP post-write re-query success with target gone logs Executed' {
        $assignId = 'ap-assign-p104-gone-001'
        $userId   = 'user-ap-p104-gone'

        $stateCounter = @{ n = 0 }
        Mock -ModuleName Remediation Get-DecomTargetState {
            $stateCounter.n++
            if ($stateCounter.n -le 1) {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @($assignId); ErrorDetail = '' }
            } else {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @(); ErrorDetail = '' }
            }
        }
        Mock -ModuleName Remediation Get-MgEntitlementManagementAssignment {
            [PSCustomObject]@{ Id = $assignId; TargetId = $userId }
        }
        Mock -ModuleName Remediation Remove-MgEntitlementManagementAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-AP-001'
            ObjectId        = $userId
            DisplayName     = 'AP Confirmed Removed User'
            ActionType      = 'RemoveAccessPackageAssignment'
            TargetObjectIds = @($assignId)
            ProtectedObject = $false
        }
        $log = New-P104ApLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions[0].Outcome | Should -Be 'Executed'
    }

    It 'PIM post-write re-query success with target gone logs Executed' {
        $schedId = 'pim-sched-p104-gone-001'
        $userId  = 'user-pim-p104-gone'

        $stateCounter = @{ n = 0 }
        Mock -ModuleName Remediation Get-DecomTargetState {
            $stateCounter.n++
            if ($stateCounter.n -le 1) {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @($schedId); ErrorDetail = '' }
            } else {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @(); ErrorDetail = '' }
            }
        }
        Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleEligibilitySchedule {
            [PSCustomObject]@{ Id = $schedId; PrincipalId = $userId }
        }
        Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleEligibilitySchedule { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-PIM-001'
            ObjectId        = $userId
            DisplayName     = 'PIM Confirmed Removed User'
            ActionType      = 'RemovePimEligibleAssignment'
            TargetObjectIds = @($schedId)
            ProtectedObject = $false
        }
        $log = New-P104PimLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions[0].Outcome | Should -Be 'Executed'
    }
}
