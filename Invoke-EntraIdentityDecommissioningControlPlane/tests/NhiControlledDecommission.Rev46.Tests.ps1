#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-grants-cleanup.sample.json'
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

    $script:Target = [PSCustomObject]@{
        ObjectId = 'app-rev46-test-001'
        ObjectType = 'Application'
        DisplayName = 'Rev46 Test Application'
        ProtectedObject = $false
        MicrosoftFirstParty = $false
        EmergencyAccessIndicator = $false
        BreakGlassIndicator = $false
        HighConfidenceActive = $false
        Ambiguous = $false
    }
    $script:TargetValidation = Test-NhiControlledTarget -Target $script:Target
    $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target $script:Target -RunId 'RUN-REV46-GRANTS-SAMPLE-001'
    $script:RawSample = Get-Content -LiteralPath $script:SamplePath -Raw
    $script:Sample = $script:RawSample | ConvertFrom-Json

    function New-Rev46Plan {
        param([hashtable]$Overrides = @{})
        $plan = [ordered]@{
            SchemaVersion = '4.6'
            RunId = 'RUN-REV46-GRANTS-SAMPLE-001'
            TargetId = 'app-rev46-test-001'
            TargetObjectId = 'app-rev46-test-001'
            TargetType = 'Application'
            RelatedObjectType = 'OAuthGrant'
            RelatedObjectId = 'oauth-grant-rev46-test-001'
            ResourceAppId = '00000003-0000-0000-c000-000000000000'
            PrincipalId = 'principal-rev46-test-001'
            PermissionName = 'User.Read'
            CleanupScope = 'Narrow'
            TargetAmbiguous = $false
            ApprovalId = 'APP-REV46-GRANTS-001'
            ApprovedActions = @('GrantCleanupReadiness')
            DependencyRecheck = [PSCustomObject]@{
                Status = 'Clean'
                QuerySucceeded = $true
                Blocked = $false
                SkippedWithApproval = $false
            }
            CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
            PostCleanupValidationStatus = 'Simulated'
            ScreamTestEvidence = [PSCustomObject]@{
                EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                Status = 'Complete'
                DependencyDetected = $false
                RecentActivityDetected = $false
                QuerySucceeded = $true
            }
            DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
            LiveCleanupApproved = $false
            LiveCleanupExecutable = $false
        }
        foreach ($key in $Overrides.Keys) { $plan[$key] = $Overrides[$key] }
        [PSCustomObject]$plan
    }

    function New-Rev46Approval {
        param([hashtable]$Overrides = @{})
        $approval = [ordered]@{
            SchemaVersion = '4.6'
            RunId = 'RUN-REV46-GRANTS-SAMPLE-001'
            Status = 'Approved'
            ApprovedBy = 'grants-cleanup-approver@example.com'
            ExpiresUtc = '2099-01-01T00:00:00Z'
            Reusable = $false
            ApprovalId = 'APP-REV46-GRANTS-001'
            TargetId = 'app-rev46-test-001'
            TargetObjectId = 'app-rev46-test-001'
            TargetType = 'Application'
            RelatedObjectType = 'OAuthGrant'
            RelatedObjectId = 'oauth-grant-rev46-test-001'
            ResourceAppId = '00000003-0000-0000-c000-000000000000'
            PrincipalId = 'principal-rev46-test-001'
            PermissionName = 'User.Read'
            CleanupScope = 'Narrow'
            TargetAmbiguous = $false
            ApprovedActions = @('GrantCleanupReadiness')
            LiveCleanupApproved = $false
            LiveCleanupExecutable = $false
        }
        foreach ($key in $Overrides.Keys) { $approval[$key] = $Overrides[$key] }
        [PSCustomObject]$approval
    }

    function New-Rev46GateInput {
        param(
            [hashtable]$PlanOverrides = @{},
            [hashtable]$ApprovalOverrides = @{},
            [string]$Stage = 'GrantCleanupReadiness',
            [bool]$TargetPassed = $true,
            [bool]$SnapshotPresent = $true,
            [bool]$WhatIf = $true,
            [bool]$DemoMode = $false,
            [bool]$IncludeSnapshotId = $true
        )

        $plan = New-Rev46Plan -Overrides $PlanOverrides
        $snapshot = if ($SnapshotPresent) { $script:Snapshot } else { $null }
        $approvalOverrides = @{}
        foreach ($key in $ApprovalOverrides.Keys) { $approvalOverrides[$key] = $ApprovalOverrides[$key] }
        if (-not $approvalOverrides.ContainsKey('SnapshotId')) {
            $approvalOverrides['SnapshotId'] = if ($IncludeSnapshotId -and $snapshot) { $snapshot.SHA256 } else { $null }
        }
        $approval = New-Rev46Approval -Overrides $approvalOverrides

        @{
            ExecutionStage = $Stage
            Plan = $plan
            Approval = $approval
            TargetValidation = if ($TargetPassed) { $script:TargetValidation } else { [PSCustomObject]@{ Passed = $false; Reasons = @('Target validation failed.') } }
            Snapshot = $snapshot
            DependencyRecheck = if ($null -ne $plan.DependencyRecheck) { $plan.DependencyRecheck } else { [PSCustomObject]@{ Status = 'Unknown'; QuerySucceeded = $false; Blocked = $false; SkippedWithApproval = $false } }
            WhatIf = $WhatIf
            DemoMode = $DemoMode
        }
    }

    function Invoke-Rev46Gate {
        param([hashtable]$InputObject)
        $module = Get-Module NhiControlledDecommission
        & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } $InputObject
    }

    function Invoke-Rev46Module {
        param(
            [scriptblock]$ScriptBlock,
            [Parameter(ValueFromRemainingArguments = $true)]
            [object[]]$Arguments
        )
        $module = Get-Module NhiControlledDecommission
        & $module $ScriptBlock @Arguments
    }
}

AfterAll {
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
}

Describe 'Rev4.6 grants cleanup contract' {
    It 'keeps the private evaluator hidden and export contract frozen' {
        Get-Command Test-NhiControlledGrantCleanupReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        $exports = (Get-Module NhiControlledDecommission).ExportedCommands.Keys
        $exports | Should -Contain 'Test-NhiControlledTarget'
        $exports | Should -Contain 'New-NhiControlledDecommissionPlan'
        $exports | Should -Contain 'ConvertTo-NhiControlledSnapshot'
    }

    It 'parses the grants cleanup sample JSON' {
        $script:Sample | Should -Not -BeNullOrEmpty
        $script:Sample.SchemaVersion | Should -Be '4.6'
        $script:Sample.TargetType | Should -Be 'Application'
    }

    It 'contains no secret-like values or delete cmdlet names' {
        $script:RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        $script:RawSample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication'
    }

    It 'captures exact related-object evidence in the sample' {
        $script:Sample.RelatedObjectType | Should -Be 'OAuthGrant'
        $script:Sample.RelatedObjectId | Should -Be 'oauth-grant-rev46-test-001'
        $script:Sample.DependencyRecheck.Status | Should -Be 'Clean'
    }

    It 'returns the expected dependency recheck statuses' {
        (Invoke-Rev46Module { param($QuerySucceeded, $Blocked, $SkippedWithApproval) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $QuerySucceeded -Blocked $Blocked -SkippedWithApproval $SkippedWithApproval } $true $false $false).Status | Should -Be 'Clean'
        (Invoke-Rev46Module { param($QuerySucceeded, $Blocked, $SkippedWithApproval) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $QuerySucceeded -Blocked $Blocked -SkippedWithApproval $SkippedWithApproval } $true $true $false).Status | Should -Be 'Blocked'
        (Invoke-Rev46Module { param($QuerySucceeded, $Blocked, $SkippedWithApproval) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $QuerySucceeded -Blocked $Blocked -SkippedWithApproval $SkippedWithApproval } $false $false $false).Status | Should -Be 'Unknown'
        (Invoke-Rev46Module { param($QuerySucceeded, $Blocked, $SkippedWithApproval) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $QuerySucceeded -Blocked $Blocked -SkippedWithApproval $SkippedWithApproval } $true $false $true).Status | Should -Be 'SkippedWithApproval'
    }

    It 'returns the expected post-cleanup validation states' {
        $result = Invoke-Rev46Gate (New-Rev46GateInput)
        $result.PostCleanupValidation.Status | Should -Be 'Simulated'
        $result.LiveCleanupExecutable | Should -BeFalse
    }

    It 'generates grants cleanup plan and action log objects' {
        $gate = Invoke-Rev46Gate (New-Rev46GateInput)
        $plan = Invoke-Rev46Module {
            param($Plan, $DependencyRecheck, $Readiness)
            New-NhiControlledGrantCleanupPlan -Plan $Plan -DependencyRecheck $DependencyRecheck -Readiness $Readiness
        } (New-Rev46Plan) (New-Rev46Plan).DependencyRecheck $gate
        $actionLog = Invoke-Rev46Module {
            param($Plan, $DependencyRecheck, $Readiness)
            New-NhiControlledGrantCleanupActionLog -Plan $Plan -DependencyRecheck $DependencyRecheck -Readiness $Readiness
        } (New-Rev46Plan) (New-Rev46Plan).DependencyRecheck $gate
        $plan.Status | Should -Be 'Planned'
        $actionLog.Result | Should -Be 'SimulationOnly'
    }

    It 'satisfies readiness only as simulation when every gate passes' {
        $result = Invoke-Rev46Gate (New-Rev46GateInput)
        $result.GatesPassed | Should -BeTrue
        $result.Status | Should -Be 'GrantCleanupSatisfiedSimulationOnly'
    }

    It 'never enables live grant cleanup when every gate passes' {
        $result = Invoke-Rev46Gate (New-Rev46GateInput)
        $result.LiveCleanupExecutable | Should -BeFalse
        $result.CleanupCmdletAvailable | Should -BeFalse
        $result.SimulationOnly | Should -BeTrue
    }

    It 'supports DemoMode readiness simulation only' {
        $result = Invoke-Rev46Gate (New-Rev46GateInput -DemoMode $true -WhatIf $false)
        $result.GatesPassed | Should -BeTrue
        $result.PostCleanupValidation.Status | Should -Be 'Simulated'
    }

    It 'supports WhatIf readiness simulation only' {
        $result = Invoke-Rev46Gate (New-Rev46GateInput -WhatIf $true)
        $result.GatesPassed | Should -BeTrue
        $result.WhatIf | Should -BeTrue
    }

    It 'keeps post-cleanup validation simulated or not run only' {
        $whatIfResult = Invoke-Rev46Gate (New-Rev46GateInput -WhatIf $true)
        $nonWhatIfResult = Invoke-Rev46Gate (New-Rev46GateInput -WhatIf $false -DemoMode $true)
        $whatIfResult.PostCleanupValidation.Status | Should -Be 'Simulated'
        $nonWhatIfResult.PostCleanupValidation.Status | Should -Be 'Simulated'
    }
}

Describe 'Rev4.6 required gate failures' {
    It 'blocks <Name>' -ForEach @(
        @{ Name = 'missing stage'; Build = { New-Rev46GateInput -Stage 'DeleteReadinessOnly' }; Pattern = 'GrantCleanupReadiness' }
        @{ Name = 'wrong schema'; Build = { New-Rev46GateInput -PlanOverrides @{ SchemaVersion = '4.5' } }; Pattern = 'Valid grant cleanup plan is required' }
        @{ Name = 'missing target id'; Build = { New-Rev46GateInput -PlanOverrides @{ TargetObjectId = '' } }; Pattern = 'Exact related object binding is required' }
        @{ Name = 'missing related id'; Build = { New-Rev46GateInput -PlanOverrides @{ RelatedObjectId = '' } }; Pattern = 'Exact related object binding is required' }
        @{ Name = 'unsupported related type'; Build = { New-Rev46GateInput -PlanOverrides @{ RelatedObjectType = 'UnsupportedType' } }; Pattern = 'Unsupported related object type' }
        @{ Name = 'dependency blocked'; Build = { New-Rev46GateInput -PlanOverrides @{ DependencyRecheck = [PSCustomObject]@{ Status = 'Blocked'; QuerySucceeded = $true; Blocked = $true; SkippedWithApproval = $false } } }; Pattern = 'Dependency recheck blocks cleanup' }
        @{ Name = 'dependency unknown'; Build = { New-Rev46GateInput -PlanOverrides @{ DependencyRecheck = [PSCustomObject]@{ Status = 'Unknown'; QuerySucceeded = $false; Blocked = $false; SkippedWithApproval = $false } } }; Pattern = 'Dependency recheck blocks cleanup' }
        @{ Name = 'target ambiguous'; Build = { New-Rev46GateInput -PlanOverrides @{ TargetAmbiguous = $true } }; Pattern = 'Target ambiguity blocks cleanup' }
        @{ Name = 'broad cleanup'; Build = { New-Rev46GateInput -PlanOverrides @{ CleanupScope = 'Broad'; Scope = 'User.Read' } -ApprovalOverrides @{ Scope = 'Mail.Read' } }; Pattern = 'broaden from one related object to many' }
        @{ Name = 'target validation failed'; Build = { New-Rev46GateInput -TargetPassed $false }; Pattern = 'Target validation failed' }
        @{ Name = 'unattended live-mode request'; Build = { New-Rev46GateInput -WhatIf $false -DemoMode $false }; Pattern = 'WhatIf or DemoMode' }
    ) {
        $result = Invoke-Rev46Gate (& $Build)
        $result.GatesPassed | Should -BeFalse
        $result.Status | Should -Be 'Blocked'
        $result.LiveCleanupExecutable | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match $Pattern
    }

    It 'blocks approval id missing' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan -Overrides @{ Scope = 'User.Read' })
            Approval = (New-Rev46Approval -Overrides @{ ApprovalId = '' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Exact approval is required'
    }

    It 'blocks approval not approved' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan -Overrides @{ Scope = 'User.Read' })
            Approval = (New-Rev46Approval -Overrides @{ Status = 'Pending' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Approval status must be Approved'
    }

    It 'blocks approval target mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan -Overrides @{ Scope = 'User.Read' })
            Approval = (New-Rev46Approval -Overrides @{ TargetObjectId = 'wrong-target' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'TargetObjectId mismatch blocks cleanup'
    }

    It 'blocks approval related mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan)
            Approval = (New-Rev46Approval -Overrides @{ RelatedObjectId = 'wrong-related' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'RelatedObjectId mismatch blocks cleanup'
    }

    It 'blocks approval type mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan)
            Approval = (New-Rev46Approval -Overrides @{ RelatedObjectType = 'AppRoleAssignment' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'RelatedObjectType mismatch blocks cleanup'
    }

    It 'blocks approval action missing' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan)
            Approval = (New-Rev46Approval -Overrides @{ ApprovedActions = @('SomethingElse') })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'specifically authorize the cleanup action'
    }

    It 'blocks resource app mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan)
            Approval = (New-Rev46Approval -Overrides @{ ResourceAppId = 'different-app' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'ResourceAppId mismatch blocks cleanup'
    }

    It 'blocks principal mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan)
            Approval = (New-Rev46Approval -Overrides @{ PrincipalId = 'different-principal' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'PrincipalId mismatch blocks cleanup'
    }

    It 'blocks permission name mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan)
            Approval = (New-Rev46Approval -Overrides @{ PermissionName = 'Mail.Read' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'PermissionName mismatch blocks cleanup'
    }

    It 'blocks scope mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan -Overrides @{ Scope = 'User.Read' })
            Approval = (New-Rev46Approval -Overrides @{ Scope = 'Mail.Read' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Scope mismatch blocks cleanup'
    }

    It 'blocks missing snapshot' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan)
            Approval = (New-Rev46Approval)
            TargetValidation = $script:TargetValidation
            Snapshot = $null
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Snapshot evidence is required'
    }

    It 'blocks snapshot mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'GrantCleanupReadiness'
            Plan = (New-Rev46Plan)
            Approval = (New-Rev46Approval -Overrides @{ SnapshotId = 'bad-snapshot' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            DependencyRecheck = (New-Rev46Plan).DependencyRecheck
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Snapshot does not include the related object'
    }
}
