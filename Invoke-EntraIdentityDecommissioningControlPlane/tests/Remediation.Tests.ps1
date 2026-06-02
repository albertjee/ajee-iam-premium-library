#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev2.0 Remediation Tests' {

    BeforeAll {
        $script:ModPath = Join-Path $PSScriptRoot '..\src\Modules'

        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }

        Import-Module (Join-Path $script:ModPath 'Utilities.psm1') -Force -DisableNameChecking
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
                [PSCustomObject]@{ Id = $approvedRoleAssign; RoleDefinitionId = 'rdef-001'; PrincipalId = $userId }
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

        It 'does not mark action Executed when write fails even if after-state query returns empty' {
            Mock -ModuleName Remediation Remove-MgGroupMemberByRef {
                throw 'simulated remove failure'
            }
            Mock -ModuleName Remediation Get-MgGroupMember {
                @([PSCustomObject]@{ Id = 'user-001' })
            } -ParameterFilter { $GroupId -eq 'group-001' }

            $action = [PSCustomObject]@{
                ActionId        = 'ACT-FAIL'
                FindingId       = 'DEC-USER-001'
                ObjectId        = 'user-001'
                DisplayName     = 'Test User'
                ActionType      = 'RemoveGroupMembership'
                TargetObjectIds = @('group-001')
                ProtectedObject = $false
            }

            $log = New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-001' -RunId ([guid]::NewGuid().ToString())
            Invoke-DecomRemediation -ApprovedActions @($action) -ExecutionLog $log -AllowNonInteractive $true

            $log.Log.Actions[0].Outcome | Should -Be 'Failed'
        }
    }
}

Describe 'Rev2.1 Target Revalidation' {

    BeforeAll {
        $script:ModPath21 = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath21 'Utilities.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath21 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath21 'Remediation.psm1') -Force -DisableNameChecking
    }

    It 'Confirm-DecomActionTargetValid blocks when PrincipalId does not match ObjectId' {
        Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleAssignment {
            [PSCustomObject]@{ Id = 'ra-001'; PrincipalId = 'different-user-guid' }
        }

        $action = [PSCustomObject]@{
            ActionType      = 'RemoveDirectoryRoleAssignment'
            ObjectId        = 'approved-user-guid'
            TargetObjectIds = @('ra-001')
        }

        $result = Confirm-DecomActionTargetValid -Action $action
        $result.Valid | Should -Be $false
        ($result.InvalidTargets | Where-Object { $_ -like '*PrincipalId MISMATCH*' }) |
            Should -Not -BeNullOrEmpty
    }

    It 'Confirm-DecomActionTargetValid returns valid when role assignment matches' {
        Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleAssignment {
            [PSCustomObject]@{ Id = 'ra-001'; PrincipalId = 'approved-user-guid' }
        }

        $action = [PSCustomObject]@{
            ActionType      = 'RemoveDirectoryRoleAssignment'
            ObjectId        = 'approved-user-guid'
            TargetObjectIds = @('ra-001')
        }

        $result = Confirm-DecomActionTargetValid -Action $action
        $result.Valid | Should -Be $true
        $result.InvalidTargets.Count | Should -Be 0
    }

    It 'Confirm-DecomActionTargetValid notes stale group membership as invalid target' {
        Mock -ModuleName Remediation Get-MgGroupMember { @() }

        $action = [PSCustomObject]@{
            ActionType      = 'RemoveGroupMembership'
            ObjectId        = 'user-001'
            TargetObjectIds = @('group-001')
        }

        $result = Confirm-DecomActionTargetValid -Action $action
        $result.Valid | Should -Be $true
        $result.InvalidTargets.Count | Should -BeGreaterThan 0
    }

    It 'Confirm-DecomActionTargetValid notes stale app role assignment as invalid target' {
        Mock -ModuleName Remediation Get-MgUserAppRoleAssignment { @() }

        $action = [PSCustomObject]@{
            ActionType      = 'RevokeAppRoleAssignment'
            ObjectId        = 'user-001'
            TargetObjectIds = @('assign-001')
        }

        $result = Confirm-DecomActionTargetValid -Action $action
        $result.Valid | Should -Be $true
        $result.InvalidTargets.Count | Should -BeGreaterThan 0
    }

    It 'Confirm-DecomActionTargetValid blocks when Graph membership check fails' {
        Mock -ModuleName Remediation Get-MgGroupMember {
            throw 'simulated Graph read failure'
        }

        $action = [PSCustomObject]@{
            ActionType      = 'RemoveGroupMembership'
            ObjectId        = 'user-001'
            TargetObjectIds = @('group-001')
        }

        $result = Confirm-DecomActionTargetValid -Action $action
        $result.Valid | Should -Be $false
    }

    It 'Confirm-DecomActionTargetValid blocks when role assignment read fails' {
        Mock -ModuleName Remediation Get-MgRoleManagementDirectoryRoleAssignment {
            throw 'simulated Graph read failure'
        }

        $action = [PSCustomObject]@{
            ActionType      = 'RemoveDirectoryRoleAssignment'
            ObjectId        = 'approved-user-guid'
            TargetObjectIds = @('ra-001')
        }

        $result = Confirm-DecomActionTargetValid -Action $action
        $result.Valid | Should -Be $false
        $result.ValidationErrors.Count | Should -BeGreaterThan 0
    }
}

Describe 'Rev2.1 Evidence Export' {

    BeforeAll {
        $script:ModPath21e = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModPath21e 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModPath21e 'Remediation.psm1') -Force -DisableNameChecking
    }

    It 'Export-DecomExecutionEvidence creates CSV and JSON files' {
        $log = New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-001' `
            -RunId ([guid]::NewGuid().ToString())
        Add-DecomExecutionAction -ExecutionLog $log -ActionId 'ACT-001' `
            -FindingId 'DEC-USER-001' -ObjectId 'u1' -DisplayName 'Test' `
            -ActionType 'RemoveGroupMembership' -Outcome 'Executed' `
            -TargetObjectIds @('g1') -TargetsBefore @('g1: existsBefore=true') `
            -TargetsAfter @('g1: existsAfter=false') -ErrorDetail ''
        Save-DecomExecutionLog -ExecutionLog $log

        $csvPath  = Join-Path $TestDrive 'evidence.csv'
        $jsonPath = Join-Path $TestDrive 'evidence.json'
        $manifest = [PSCustomObject]@{ ApprovedActionsHash = 'hash'; ApprovedBy = 'Jane' }

        Export-DecomExecutionEvidence -ExecutionLog $log -ApprovalManifest $manifest `
            -CsvPath $csvPath -JsonPath $jsonPath

        Test-Path $csvPath  | Should -Be $true
        Test-Path $jsonPath | Should -Be $true
        $csv = Import-Csv $csvPath
        $csv[0].ActionId | Should -Be 'ACT-001'
        $csv[0].Outcome  | Should -Be 'Executed'
    }

    It 'Write-DecomExecutionManifest creates manifest with correct schema version' {
        $log = New-DecomExecutionLog -RunFolder $TestDrive -EngagementId 'ENG-001' `
            -RunId ([guid]::NewGuid().ToString())
        Save-DecomExecutionLog -ExecutionLog $log

        $manifestPath = Join-Path $TestDrive 'exec-manifest.json'
        $approval = [PSCustomObject]@{
            WhatIfRunId = 'r1'; ApprovedBy = 'Jane'; ApprovalTicket = 'CHG-001'
            ApprovalSystem = 'ServiceNow'; ApprovedActionsHash = 'h1'
            ApprovalEnvelopeHash = 'h2'
        }

        Write-DecomExecutionManifest -ExecutionLog $log -ApprovalManifest $approval `
            -Path $manifestPath -EngagementId 'ENG-001' -ClientName 'Contoso' `
            -TenantId 'contoso.onmicrosoft.com' -Assessor 'Albert Jee' `
            -EvidenceCsvPath 'ev.csv' -EvidenceJsonPath 'ev.json' -ReportPath 'rep.html'

        $content = Get-Content $manifestPath -Raw | ConvertFrom-Json
        $content.SchemaVersion  | Should -Be '2.1'
        $content.Mode           | Should -Be 'ExecuteRemediation'
        $content.ApprovalTicket | Should -Be 'CHG-001'
    }
}

Describe 'Rev2.1 Max Action Guardrail' {

    It 'Entry point MaxActions check is present in source' {
        $src = Get-Content '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1' -Raw
        $src | Should -Match 'MaxActions'
        $src | Should -Match 'exceeds'
    }

    It 'Entry point ActionId filter is present in source' {
        $src = Get-Content '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1' -Raw
        $src | Should -Match '\$ActionId'
    }
}

Describe 'Rev2.1 Preflight Report' {

    It 'Entry point RequirePreflightConfirm parameter is present' {
        $src = Get-Content '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1' -Raw
        $src | Should -Match 'RequirePreflightConfirm'
    }

    It 'Entry point preflight EXECUTE prompt is present' {
        $src = Get-Content '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1' -Raw
        $src | Should -Match 'EXECUTE'
    }
}

Describe 'Rev2.1 Execution Window Validation' {

    BeforeAll {
        $script:ModPath21w = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module ApprovalManifest -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModPath21w 'ApprovalManifest.psm1') -Force -DisableNameChecking
    }

    It 'Test-DecomApprovalManifest blocks when current time is before ExecutionWindowStartUtc' {
        $tomorrow  = (Get-Date).AddDays(1).ToUniversalTime().ToString('o')
        $dayAfter  = (Get-Date).AddDays(2).ToUniversalTime().ToString('o')
        $mPath = Join-Path $TestDrive 'approval-before-window.json'
        $m = [ordered]@{
            SchemaVersion        = '2.0'
            ApprovalStatus       = 'Approved'
            EngagementId         = 'ENG-001'
            ClientName           = 'Contoso'
            ApprovedBy           = 'Jane Smith'
            ApprovedUtc          = (Get-Date).AddDays(-1).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(3).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            WhatIfRunId          = [guid]::NewGuid().ToString()
            ApprovedActionsHash  = 'placeholder'
            ApprovalEnvelopeHash = 'placeholder'
            ApprovedActions      = @()
            ExecutionWindowStartUtc = $tomorrow
            ExecutionWindowEndUtc   = $dayAfter
        }
        $m | ConvertTo-Json -Depth 5 | Set-Content $mPath -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $mPath `
            -CurrentEngagementId 'ENG-001' -CurrentClientName 'Contoso' `
            -WhatIfRunId $m.WhatIfRunId
        ($result.Errors | Where-Object { $_ -like '*before ExecutionWindowStartUtc*' }) |
            Should -Not -BeNullOrEmpty
    }

    It 'Test-DecomApprovalManifest blocks when current time is after ExecutionWindowEndUtc' {
        $yesterday = (Get-Date).AddDays(-2).ToUniversalTime().ToString('o')
        $anHourAgo = (Get-Date).AddHours(-1).ToUniversalTime().ToString('o')
        $mPath = Join-Path $TestDrive 'approval-after-window.json'
        $m = [ordered]@{
            SchemaVersion        = '2.0'
            ApprovalStatus       = 'Approved'
            EngagementId         = 'ENG-001'
            ClientName           = 'Contoso'
            ApprovedBy           = 'Jane Smith'
            ApprovedUtc          = (Get-Date).AddDays(-3).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(1).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            WhatIfRunId          = [guid]::NewGuid().ToString()
            ApprovedActionsHash  = 'placeholder'
            ApprovalEnvelopeHash = 'placeholder'
            ApprovedActions      = @()
            ExecutionWindowStartUtc = $yesterday
            ExecutionWindowEndUtc   = $anHourAgo
        }
        $m | ConvertTo-Json -Depth 5 | Set-Content $mPath -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $mPath `
            -CurrentEngagementId 'ENG-001' -CurrentClientName 'Contoso' `
            -WhatIfRunId $m.WhatIfRunId
        ($result.Errors | Where-Object { $_ -like '*after ExecutionWindowEndUtc*' }) |
            Should -Not -BeNullOrEmpty
    }

    It 'Test-DecomApprovalManifest does not add window errors when current time is within window' {
        $anHourAgo = (Get-Date).AddHours(-1).ToUniversalTime().ToString('o')
        $tomorrow  = (Get-Date).AddDays(1).ToUniversalTime().ToString('o')
        $mPath = Join-Path $TestDrive 'approval-in-window.json'
        $m = [ordered]@{
            SchemaVersion        = '2.0'
            ApprovalStatus       = 'Approved'
            EngagementId         = 'ENG-001'
            ClientName           = 'Contoso'
            ApprovedBy           = 'Jane Smith'
            ApprovedUtc          = (Get-Date).AddDays(-1).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(3).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            WhatIfRunId          = [guid]::NewGuid().ToString()
            ApprovedActionsHash  = 'placeholder'
            ApprovalEnvelopeHash = 'placeholder'
            ApprovedActions      = @()
            ExecutionWindowStartUtc = $anHourAgo
            ExecutionWindowEndUtc   = $tomorrow
        }
        $m | ConvertTo-Json -Depth 5 | Set-Content $mPath -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $mPath `
            -CurrentEngagementId 'ENG-001' -CurrentClientName 'Contoso' `
            -WhatIfRunId $m.WhatIfRunId
        ($result.Errors | Where-Object { $_ -like '*ExecutionWindow*' }) |
            Should -BeNullOrEmpty
    }
}
