#Requires -Modules Pester

Describe 'PresenceCheck.Rev37 — Remediation Unknown Presence State' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '../../src/Modules'
        Remove-Module Remediation -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModPath 'Remediation.psm1') -Force -DisableNameChecking
    }

    Context 'RemoveGroupMembership presence check' {

        It 'returns ConfirmedPresent when member exists' {
            $action = [pscustomobject]@{
                ActionType        = 'RemoveGroupMembership'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('group-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgGroupMember -MockWith {
                @([pscustomobject]@{ Id = 'user-123' }, [pscustomobject]@{ Id = 'user-789' })
            }

            $result = Get-DecomTargetState -Action $action
            $groupCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'group-456' }

            $groupCheck.PresenceCheckStatus | Should -Be 'ConfirmedPresent'
            $groupCheck.PresenceCheckError | Should -Be $null
            $result.QuerySucceeded | Should -Be $true
        }

        It 'returns ConfirmedAbsent when member not found' {
            $action = [pscustomobject]@{
                ActionType        = 'RemoveGroupMembership'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('group-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgGroupMember -MockWith {
                @([pscustomobject]@{ Id = 'user-789' })
            }

            $result = Get-DecomTargetState -Action $action
            $groupCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'group-456' }

            $groupCheck.PresenceCheckStatus | Should -Be 'ConfirmedAbsent'
            $groupCheck.PresenceCheckError | Should -Be $null
            $result.QuerySucceeded | Should -Be $true
        }

        It 'returns Unknown with error message when read fails' {
            $action = [pscustomobject]@{
                ActionType        = 'RemoveGroupMembership'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('group-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgGroupMember -MockWith {
                throw [System.Exception]::new('Access denied')
            }

            $result = Get-DecomTargetState -Action $action
            $groupCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'group-456' }

            $groupCheck.PresenceCheckStatus | Should -Be 'Unknown'
            $groupCheck.PresenceCheckError | Should -Match 'Access denied'
            $result.QuerySucceeded | Should -Be $false
        }
    }

    Context 'RevokeAppRoleAssignment presence check' {

        It 'returns ConfirmedPresent when assignment exists' {
            $action = [pscustomobject]@{
                ActionType        = 'RevokeAppRoleAssignment'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('assignment-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgUserAppRoleAssignment -MockWith {
                @([pscustomobject]@{ Id = 'assignment-456' }, [pscustomobject]@{ Id = 'assignment-789' })
            }

            $result = Get-DecomTargetState -Action $action
            $assignmentCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'assignment-456' }

            $assignmentCheck.PresenceCheckStatus | Should -Be 'ConfirmedPresent'
            $assignmentCheck.PresenceCheckError | Should -Be $null
            $result.QuerySucceeded | Should -Be $true
        }

        It 'returns ConfirmedAbsent when assignment not found' {
            $action = [pscustomobject]@{
                ActionType        = 'RevokeAppRoleAssignment'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('assignment-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgUserAppRoleAssignment -MockWith {
                @([pscustomobject]@{ Id = 'assignment-789' })
            }

            $result = Get-DecomTargetState -Action $action
            $assignmentCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'assignment-456' }

            $assignmentCheck.PresenceCheckStatus | Should -Be 'ConfirmedAbsent'
            $assignmentCheck.PresenceCheckError | Should -Be $null
            $result.QuerySucceeded | Should -Be $true
        }

        It 'returns Unknown with error message when read fails' {
            $action = [pscustomobject]@{
                ActionType        = 'RevokeAppRoleAssignment'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('assignment-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgUserAppRoleAssignment -MockWith {
                throw [System.Exception]::new('User not found')
            }

            $result = Get-DecomTargetState -Action $action
            $assignmentCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'assignment-456' }

            $assignmentCheck.PresenceCheckStatus | Should -Be 'Unknown'
            $assignmentCheck.PresenceCheckError | Should -Match 'User not found'
            $result.QuerySucceeded | Should -Be $false
        }
    }

    Context 'RemoveDirectoryRoleAssignment presence check' {

        It 'returns ConfirmedPresent when assignment exists' {
            $action = [pscustomobject]@{
                ActionType        = 'RemoveDirectoryRoleAssignment'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('roleassignment-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgRoleManagementDirectoryRoleAssignment -MockWith {
                [pscustomobject]@{ Id = 'roleassignment-456'; PrincipalId = 'user-123' }
            }

            $result = Get-DecomTargetState -Action $action
            $roleCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'roleassignment-456' }

            $roleCheck.PresenceCheckStatus | Should -Be 'ConfirmedPresent'
            $roleCheck.PresenceCheckError | Should -Be $null
            $result.QuerySucceeded | Should -Be $true
        }

        It 'returns ConfirmedAbsent when assignment not found' {
            $action = [pscustomobject]@{
                ActionType        = 'RemoveDirectoryRoleAssignment'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('roleassignment-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgRoleManagementDirectoryRoleAssignment -MockWith {
                $null
            }

            $result = Get-DecomTargetState -Action $action
            $roleCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'roleassignment-456' }

            $roleCheck.PresenceCheckStatus | Should -Be 'ConfirmedAbsent'
            $roleCheck.PresenceCheckError | Should -Be $null
            $result.QuerySucceeded | Should -Be $true
        }

        It 'returns Unknown with error message when read fails' {
            $action = [pscustomobject]@{
                ActionType        = 'RemoveDirectoryRoleAssignment'
                ObjectId          = 'user-123'
                TargetObjectIds   = @('roleassignment-456')
            }

            Mock -ModuleName Remediation -CommandName Get-MgRoleManagementDirectoryRoleAssignment -MockWith {
                throw [System.Exception]::new('Role assignment not accessible')
            }

            $result = Get-DecomTargetState -Action $action
            $roleCheck = $result.PresenceCheckByTarget | Where-Object { $_.TargetId -eq 'roleassignment-456' }

            $roleCheck.PresenceCheckStatus | Should -Be 'Unknown'
            $roleCheck.PresenceCheckError | Should -Match 'Role assignment not accessible'
            $result.QuerySucceeded | Should -Be $false
        }
    }
}
