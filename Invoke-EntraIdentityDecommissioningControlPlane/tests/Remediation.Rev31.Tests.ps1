#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Remediation.psm1 — Rev3.1 ExecutionMap and ManualApproval Guest Registry' {

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

    It 'ExecutionMap contains all 6 guest finding IDs in scope' {
        InModuleScope Remediation {
            $guestIds = @('DEC-GUEST-001','DEC-GUEST-002','DEC-GUEST-003','DEC-GREV-001','DEC-GREV-002','DEC-GREV-003')
            foreach ($id in $guestIds) {
                $script:ExecutionMap.ContainsKey($id) | Should -Be $true `
                    -Because "FindingId $id must be in Remediation ExecutionMap for execution scope checking"
            }
        }
    }

    It 'ManualApprovalFindingIds includes all 6 guest finding IDs' {
        InModuleScope Remediation {
            $guestIds = @('DEC-GUEST-001','DEC-GUEST-002','DEC-GUEST-003','DEC-GREV-001','DEC-GREV-002','DEC-GREV-003')
            foreach ($id in $guestIds) {
                $script:ManualApprovalFindingIds | Should -Contain $id `
                    -Because "FindingId $id requires manual approval before guest write"
            }
        }
    }
}

Describe 'Remediation.psm1 — Rev3.1 Guest Identity Revalidation' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1')  -Force -DisableNameChecking

        function script:New-GuestTestLog {
            New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-GUEST-REVAL' `
                -RunId ([guid]::NewGuid().ToString())
        }
    }

    AfterAll {
        foreach ($m in @('Remediation','ExecutionLog','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Guest user read failure blocks RemoveGuestGroupMembership action' {
        Mock -ModuleName Remediation Get-MgUser { throw 'Simulated Graph read failure' }
        Mock -ModuleName Remediation Remove-MgGroupMemberByRef { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-001'
            ObjectId        = 'guest-read-fail-001'
            DisplayName     = 'Guest Read Fail'
            ActionType      = 'RemoveGuestGroupMembership'
            TargetObjectIds = @('grp-001')
            ProtectedObject = $false
        }
        $log = New-GuestTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgGroupMemberByRef -ModuleName Remediation -Exactly 0
    }

    It 'UserType Member blocks RemoveGuestGroupMembership action' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'member-user-001'; UserType = 'Member' }
        }
        Mock -ModuleName Remediation Remove-MgGroupMemberByRef { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-001'
            ObjectId        = 'member-user-001'
            DisplayName     = 'Member User'
            ActionType      = 'RemoveGuestGroupMembership'
            TargetObjectIds = @('grp-member-001')
            ProtectedObject = $false
        }
        $log = New-GuestTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgGroupMemberByRef -ModuleName Remediation -Exactly 0
    }

    It 'Guest group membership read failure blocks action' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-grp-fail-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgGroupMember { throw 'Simulated group membership read failure' }
        Mock -ModuleName Remediation Remove-MgGroupMemberByRef { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-001'
            ObjectId        = 'guest-grp-fail-001'
            DisplayName     = 'Guest Group Fail'
            ActionType      = 'RemoveGuestGroupMembership'
            TargetObjectIds = @('grp-fail-read-001')
            ProtectedObject = $false
        }
        $log = New-GuestTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgGroupMemberByRef -ModuleName Remediation -Exactly 0
    }

    It 'RemoveGuestGroupMembership stale target logs Skipped and does not attempt write' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-stale-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgGroupMember { @() }
        Mock -ModuleName Remediation Remove-MgGroupMemberByRef { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-001'
            ObjectId        = 'guest-stale-001'
            DisplayName     = 'Guest Stale'
            ActionType      = 'RemoveGuestGroupMembership'
            TargetObjectIds = @('grp-stale-001')
            ProtectedObject = $false
        }
        $log = New-GuestTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Skipped'
        Should -Invoke -CommandName Remove-MgGroupMemberByRef -ModuleName Remediation -Exactly 0
    }

    It 'RevokeGuestAppRoleAssignment stale target logs Skipped and does not attempt write' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-stale-approle-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgUserAppRoleAssignment { @() }
        Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-002'
            ObjectId        = 'guest-stale-approle-001'
            DisplayName     = 'Guest AppRole Stale'
            ActionType      = 'RevokeGuestAppRoleAssignment'
            TargetObjectIds = @('approle-stale-001')
            ProtectedObject = $false
        }
        $log = New-GuestTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Skipped'
        Should -Invoke -CommandName Remove-MgUserAppRoleAssignment -ModuleName Remediation -Exactly 0
    }

    It 'Guest app role assignment read failure blocks RevokeGuestAppRoleAssignment action' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-approle-fail-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgUserAppRoleAssignment { throw 'Simulated app role read failure' }
        Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-002'
            ObjectId        = 'guest-approle-fail-001'
            DisplayName     = 'Guest AppRole Fail'
            ActionType      = 'RevokeGuestAppRoleAssignment'
            TargetObjectIds = @('approle-assign-fail-001')
            ProtectedObject = $false
        }
        $log = New-GuestTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgUserAppRoleAssignment -ModuleName Remediation -Exactly 0
    }

    It 'App role assignment PrincipalId mismatch blocks RevokeGuestAppRoleAssignment action' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-approle-mismatch-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgUserAppRoleAssignment {
            @([PSCustomObject]@{ Id = 'approle-mismatch-001'; PrincipalId = 'different-user-999' })
        }
        Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-002'
            ObjectId        = 'guest-approle-mismatch-001'
            DisplayName     = 'Guest AppRole Mismatch'
            ActionType      = 'RevokeGuestAppRoleAssignment'
            TargetObjectIds = @('approle-mismatch-001')
            ProtectedObject = $false
        }
        $log = New-GuestTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgUserAppRoleAssignment -ModuleName Remediation -Exactly 0
    }

    It 'Guest app role assignment absent becomes stale no-op' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-approle-stale-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgUserAppRoleAssignment { @() }
        Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-002'
            ObjectId        = 'guest-approle-stale-001'
            DisplayName     = 'Guest AppRole Stale'
            ActionType      = 'RevokeGuestAppRoleAssignment'
            TargetObjectIds = @('approle-stale-001')
            ProtectedObject = $false
        }
        $log = New-GuestTestLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count | Should -Be 1
        Should -Invoke -CommandName Remove-MgUserAppRoleAssignment -ModuleName Remediation -Exactly 0
    }
}

Describe 'Remediation.psm1 — Rev3.1 Guest Write Execution' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1')  -Force -DisableNameChecking

        function script:New-GuestExecLog {
            New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-GUEST-EXEC' `
                -RunId ([guid]::NewGuid().ToString())
        }
    }

    AfterAll {
        foreach ($m in @('Remediation','ExecutionLog','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'RemoveGuestGroupMembership writes only the approved group ID' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-exec-001'; UserType = 'Guest' }
        }
        $callCount = 0
        Mock -ModuleName Remediation Get-MgGroupMember {
            param($GroupId)
            if ($GroupId -eq 'grp-approved-001') {
                @([PSCustomObject]@{ Id = 'guest-exec-001' })
            } else {
                @()
            }
        }
        Mock -ModuleName Remediation Remove-MgGroupMemberByRef {
            param($GroupId, $DirectoryObjectId)
            $script:capturedGroupId = $GroupId
        }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-001'
            ObjectId        = 'guest-exec-001'
            DisplayName     = 'Guest Exec'
            ActionType      = 'RemoveGuestGroupMembership'
            TargetObjectIds = @('grp-approved-001')
            ProtectedObject = $false
        }
        $log = New-GuestExecLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        Should -Invoke -CommandName Remove-MgGroupMemberByRef -ModuleName Remediation -Exactly 1
    }

    It 'RemoveGuestGroupMembership ProtectedObject=true logs Blocked and makes no Remove calls' {
        Mock -ModuleName Remediation Remove-MgGroupMemberByRef { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-001'
            ObjectId        = 'guest-protected-001'
            DisplayName     = 'Guest Protected'
            ActionType      = 'RemoveGuestGroupMembership'
            TargetObjectIds = @('grp-protected-001')
            ProtectedObject = $true
        }
        $log = New-GuestExecLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgGroupMemberByRef -ModuleName Remediation -Exactly 0
    }

    It 'RemoveGuestGroupMembership write failure logs Failed' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-write-fail-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgGroupMember {
            @([PSCustomObject]@{ Id = 'guest-write-fail-001' })
        }
        Mock -ModuleName Remediation Remove-MgGroupMemberByRef { throw 'Simulated write failure' }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-001'
            ObjectId        = 'guest-write-fail-001'
            DisplayName     = 'Guest Write Fail'
            ActionType      = 'RemoveGuestGroupMembership'
            TargetObjectIds = @('grp-write-fail-001')
            ProtectedObject = $false
        }
        $log = New-GuestExecLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Failed'
    }

    It 'RemoveGuestGroupMembership re-query failure logs PartialFailed' {
        $memberCallCount = 0
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-requery-fail-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgGroupMember {
            param($GroupId)
            $script:memberCallCount++
            if ($script:memberCallCount -le 3) {
                # Calls 1-3: revalidation + before-state + membership check in switch
                @([PSCustomObject]@{ Id = 'guest-requery-fail-001' })
            } else {
                # Call 4 (re-query after write): simulate failure
                throw 'Simulated re-query failure'
            }
        }
        Mock -ModuleName Remediation Remove-MgGroupMemberByRef { }

        $script:memberCallCount = 0
        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-001'
            ObjectId        = 'guest-requery-fail-001'
            DisplayName     = 'Guest ReQuery Fail'
            ActionType      = 'RemoveGuestGroupMembership'
            TargetObjectIds = @('grp-requery-fail-001')
            ProtectedObject = $false
        }
        $log = New-GuestExecLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'PartialFailed'
    }

    It 'RevokeGuestAppRoleAssignment writes only approved assignment ID' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-approle-exec-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgUserAppRoleAssignment {
            @([PSCustomObject]@{ Id = 'approle-approved-001'; PrincipalId = 'guest-approle-exec-001' })
        }
        Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-002'
            ObjectId        = 'guest-approle-exec-001'
            DisplayName     = 'Guest AppRole Exec'
            ActionType      = 'RevokeGuestAppRoleAssignment'
            TargetObjectIds = @('approle-approved-001')
            ProtectedObject = $false
        }
        $log = New-GuestExecLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        Should -Invoke -CommandName Remove-MgUserAppRoleAssignment -ModuleName Remediation -Exactly 1
    }

    It 'RevokeGuestAppRoleAssignment ProtectedObject=true logs Blocked and makes no Remove calls' {
        Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment { }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-002'
            ObjectId        = 'guest-approle-protected-001'
            DisplayName     = 'Guest AppRole Protected'
            ActionType      = 'RevokeGuestAppRoleAssignment'
            TargetObjectIds = @('approle-protected-001')
            ProtectedObject = $true
        }
        $log = New-GuestExecLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Blocked'
        Should -Invoke -CommandName Remove-MgUserAppRoleAssignment -ModuleName Remediation -Exactly 0
    }

    It 'RevokeGuestAppRoleAssignment write failure logs Failed' {
        Mock -ModuleName Remediation Get-MgUser {
            [PSCustomObject]@{ Id = 'guest-approle-wfail-001'; UserType = 'Guest' }
        }
        Mock -ModuleName Remediation Get-MgUserAppRoleAssignment {
            @([PSCustomObject]@{ Id = 'approle-wfail-001'; PrincipalId = 'guest-approle-wfail-001' })
        }
        Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment { throw 'Simulated write failure' }

        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-GUEST-002'
            ObjectId        = 'guest-approle-wfail-001'
            DisplayName     = 'Guest AppRole Write Fail'
            ActionType      = 'RevokeGuestAppRoleAssignment'
            TargetObjectIds = @('approle-wfail-001')
            ProtectedObject = $false
        }
        $log = New-GuestExecLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'Failed'
    }

    It 'Unknown Rev3.1 action type is logged as OutOfScope' {
        $action = [PSCustomObject]@{
            ActionId        = 'ACT-001'
            FindingId       = 'DEC-INVALID-999'
            ObjectId        = 'user-unknown'
            DisplayName     = 'Unknown Action'
            ActionType      = 'SomeUnsupportedAction'
            TargetObjectIds = @('target-001')
            ProtectedObject = $false
        }
        $log = New-GuestExecLog
        Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

        $log.Log.Actions.Count      | Should -Be 1
        $log.Log.Actions[0].Outcome | Should -Be 'OutOfScope'
    }
}
