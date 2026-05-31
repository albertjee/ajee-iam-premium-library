#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev2.0 Remediation Tests' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\..\src\Modules'

        foreach ($m in @('ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }

        Import-Module (Join-Path $script:ModPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1') -Force -DisableNameChecking

        function script:New-TestLog {
            param([string]$RunId = [guid]::NewGuid().ToString())
            New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-001' -RunId $RunId
        }

        function script:New-TestAction {
            param(
                [string]$ActionId    = 'ACT-001',
                [string]$FindingId   = 'DEC-USER-001',
                [string]$ObjectId    = 'user-001',
                [string]$ActionType  = 'RemoveGroupMembership',
                [string[]]$TargetIds = @('group-001'),
                [bool]$Protected     = $false
            )
            [PSCustomObject]@{
                ActionId        = $ActionId
                FindingId       = $FindingId
                ObjectId        = $ObjectId
                DisplayName     = 'Test User'
                ActionType      = $ActionType
                TargetObjectIds = $TargetIds
                ProtectedObject = $Protected
            }
        }
    }

    Context 'Execution log lifecycle' {

        It 'New-DecomExecutionLog creates correct structure' {
            $log = New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-001' -RunId 'test-run-1'
            $log             | Should -Not -BeNullOrEmpty
            $log.Log.RunId   | Should -Be 'test-run-1'
            $log.Log.EngagementId | Should -Be 'ENG-001'
            $log.Log.Actions.Count | Should -Be 0
            $log.Log.CompletedUtc  | Should -BeNullOrEmpty
            $log.Path | Should -Match 'execution-log-test-run-1'
        }

        It 'Add-DecomExecutionAction appends entry with correct fields' {
            $log = New-TestLog -RunId 'test-run-append'
            Add-DecomExecutionAction -ExecutionLog $log -ActionId 'ACT-001' `
                -FindingId 'DEC-USER-001' -ObjectId 'user-001' -DisplayName 'U1' `
                -ActionType 'RemoveGroupMembership' -Outcome 'Executed' `
                -TargetObjectIds @('grp-1') -TargetsBefore @('grp-1') `
                -TargetsAfter @() -ErrorDetail ''
            $log.Log.Actions.Count        | Should -Be 1
            $log.Log.Actions[0].ActionId  | Should -Be 'ACT-001'
            $log.Log.Actions[0].Outcome   | Should -Be 'Executed'
            $log.Log.Actions[0].FindingId | Should -Be 'DEC-USER-001'
        }

        It 'Save-DecomExecutionLog writes file and sets CompletedUtc' {
            $runId = 'save-test-' + [guid]::NewGuid().ToString().Substring(0,8)
            $log = New-TestLog -RunId $runId
            Save-DecomExecutionLog -ExecutionLog $log
            $expectedPath = Join-Path $TestDrive "execution-log-$runId.json"
            Test-Path $expectedPath | Should -Be $true
            $content = Get-Content $expectedPath -Raw | ConvertFrom-Json
            $content.CompletedUtc | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Gate C: ProtectedObject and scope enforcement' {

        It 'ProtectedObject action logs Blocked and no Remove-Mg* calls made' {
            Mock -ModuleName Remediation Remove-MgGroupMemberByRef              { }
            Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment         { }
            Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleAssignment { }

            $action = New-TestAction -Protected $true
            $log = New-TestLog
            Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

            $log.Log.Actions.Count          | Should -Be 1
            $log.Log.Actions[0].Outcome     | Should -Be 'Blocked'

            Should -Invoke -CommandName Remove-MgGroupMemberByRef              -ModuleName Remediation -Exactly 0
            Should -Invoke -CommandName Remove-MgUserAppRoleAssignment         -ModuleName Remediation -Exactly 0
            Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleAssignment -ModuleName Remediation -Exactly 0
        }

        It 'Out-of-scope FindingId logs OutOfScope' {
            $action = New-TestAction -FindingId 'DEC-UNKNOWN-999' -ActionType 'RemoveGroupMembership'
            $log = New-TestLog
            Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true
            $log.Log.Actions.Count      | Should -Be 1
            $log.Log.Actions[0].Outcome | Should -Be 'OutOfScope'
        }

        It 'ManualApprovalRequired action with declined prompt logs OperatorDeclined' {
            Mock -ModuleName Remediation Read-Host { 'n' }

            $action = New-TestAction -FindingId 'DEC-USER-002' -ActionType 'RevokeAppRoleAssignment' `
                -TargetIds @('assign-001')
            $log = New-TestLog
            Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $false

            $log.Log.Actions.Count      | Should -Be 1
            $log.Log.Actions[0].Outcome | Should -Be 'OperatorDeclined'
        }
    }

    Context 'Write-safety: approved TargetObjectIds only' {

        It 'DEC-USER-001 calls Remove-MgGroupMemberByRef only with approved group ID' {
            $userId    = 'user-001'
            $approvedGrp = 'group-approved-001'

            Mock -ModuleName Remediation Get-MgGroupMember {
                @([PSCustomObject]@{ Id = $userId })
            }
            Mock -ModuleName Remediation Remove-MgGroupMemberByRef { }

            $action = New-TestAction -FindingId 'DEC-USER-001' -ObjectId $userId `
                -ActionType 'RemoveGroupMembership' -TargetIds @($approvedGrp)
            $log = New-TestLog
            Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

            Should -Invoke -CommandName Remove-MgGroupMemberByRef -ModuleName Remediation -Exactly 1
            Should -Invoke -CommandName Remove-MgGroupMemberByRef -ModuleName Remediation -Exactly 1 `
                -ParameterFilter { $GroupId -eq $approvedGrp -and $DirectoryObjectId -eq $userId }
        }

        It 'DEC-USER-002 calls Remove-MgUserAppRoleAssignment only with approved assignment ID' {
            $userId    = 'user-002'
            $approvedAssign = 'assignment-approved-001'

            Mock -ModuleName Remediation Get-MgUserAppRoleAssignment {
                @([PSCustomObject]@{ Id = $approvedAssign; ResourceDisplayName = 'App1' })
            }
            Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment { }

            $action = New-TestAction -FindingId 'DEC-USER-002' -ObjectId $userId `
                -ActionType 'RevokeAppRoleAssignment' -TargetIds @($approvedAssign)
            $log = New-TestLog
            Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

            Should -Invoke -CommandName Remove-MgUserAppRoleAssignment -ModuleName Remediation -Exactly 1
            Should -Invoke -CommandName Remove-MgUserAppRoleAssignment -ModuleName Remediation -Exactly 1 `
                -ParameterFilter { $UserId -eq $userId -and $AppRoleAssignmentId -eq $approvedAssign }
        }

        It 'DEC-USER-003 calls Remove-MgRoleManagementDirectoryRoleAssignment only with approved assignment ID' {
            $userId       = 'user-003'
            $approvedRoleAssign = 'role-assignment-approved-001'

            Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleAssignment {
                [PSCustomObject]@{ Id = $approvedRoleAssign; RoleDefinitionId = 'rdef-001' }
            }
            Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleAssignment { }

            $action = New-TestAction -FindingId 'DEC-USER-003' -ObjectId $userId `
                -ActionType 'RemoveDirectoryRoleAssignment' -TargetIds @($approvedRoleAssign)
            $log = New-TestLog
            Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

            Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleAssignment -ModuleName Remediation -Exactly 1
            Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleAssignment -ModuleName Remediation -Exactly 1 `
                -ParameterFilter { $UnifiedRoleAssignmentId -eq $approvedRoleAssign }
        }

        It 'ProtectedObject action makes zero Remove-Mg* calls even when other actions succeed' {
            Mock -ModuleName Remediation Remove-MgGroupMemberByRef              { }
            Mock -ModuleName Remediation Remove-MgUserAppRoleAssignment         { }
            Mock -ModuleName Remediation Remove-MgRoleManagementDirectoryRoleAssignment { }

            $protectedAction = New-TestAction -ActionId 'ACT-P1' -Protected $true
            $log = New-TestLog
            Invoke-DecomRemediation -ApprovedActions @($protectedAction) -ExecutionLog $log -AllowNonInteractive $true

            Should -Invoke -CommandName Remove-MgGroupMemberByRef              -ModuleName Remediation -Exactly 0
            Should -Invoke -CommandName Remove-MgUserAppRoleAssignment         -ModuleName Remediation -Exactly 0
            Should -Invoke -CommandName Remove-MgRoleManagementDirectoryRoleAssignment -ModuleName Remediation -Exactly 0
        }
    }
}
