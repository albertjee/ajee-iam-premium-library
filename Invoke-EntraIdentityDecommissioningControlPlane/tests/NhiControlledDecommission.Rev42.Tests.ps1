#Requires -Version 7.0

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:PlanSamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-decommission-plan.sample.json'
    $script:ApprovalSamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-decommission-approval.sample.json'
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

    function New-Rev42Target {
        param(
            [string]$ObjectId = 'sp-rev42-001',
            [string]$ObjectType = 'ServicePrincipal',
            [bool]$ProtectedObject = $false,
            [bool]$MicrosoftFirstParty = $false,
            [bool]$EmergencyAccessIndicator = $false,
            [bool]$BreakGlassIndicator = $false,
            [bool]$HighConfidenceActive = $false,
            [bool]$Ambiguous = $false
        )
        [PSCustomObject]@{
            ObjectId = $ObjectId
            ObjectType = $ObjectType
            DisplayName = 'Rev42 Test Service Principal'
            AppId = 'app-rev42-001'
            AccountEnabled = $true
            ProtectedObject = $ProtectedObject
            MicrosoftFirstParty = $MicrosoftFirstParty
            EmergencyAccessIndicator = $EmergencyAccessIndicator
            BreakGlassIndicator = $BreakGlassIndicator
            HighConfidenceActive = $HighConfidenceActive
            Ambiguous = $Ambiguous
            ClientSecret = 'must-not-export'
            AccessToken = 'must-not-export'
            PasswordCredentials = @(
                [PSCustomObject]@{
                    KeyId = 'key-001'
                    DisplayName = 'metadata-only'
                    StartDateTime = '2026-01-01T00:00:00Z'
                    EndDateTime = '2027-01-01T00:00:00Z'
                    SecretText = 'must-not-export'
                }
            )
        }
    }

    function New-Rev42Approval {
        param(
            [string]$RunId = 'RUN-REV42-001',
            [string]$Status = 'Approved',
            [string]$ApprovedBy = 'approver@example.com',
            [string[]]$TargetObjectIds = @('sp-rev42-001'),
            [string[]]$ApprovedActions = @('SnapshotOnly', 'DeleteReadinessOnly'),
            [string]$ExpiresUtc = '2099-01-01T00:00:00Z',
            [bool]$Reusable = $false,
            [string]$SchemaVersion = '4.2'
        )
        [PSCustomObject]@{
            SchemaVersion = $SchemaVersion
            RunId = $RunId
            Status = $Status
            ApprovedBy = $ApprovedBy
            TargetObjectIds = $TargetObjectIds
            ApprovedActions = $ApprovedActions
            ExpiresUtc = $ExpiresUtc
            Reusable = $Reusable
        }
    }
}

AfterAll {
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
}

Describe 'NhiControlledDecommission module contract' {
    $script:ExpectedExports = @(
        'Get-NhiControlledDecommissionSha256'
        'Get-NhiControlledDecommissionSchema'
        'ConvertTo-NhiControlledSnapshot'
        'Test-NhiControlledTarget'
        'Confirm-NhiControlledApproval'
        'Get-NhiControlledScreamTestStatus'
        'Test-NhiControlledDependencies'
        'Get-NhiControlledDeleteReadiness'
        'New-NhiControlledRollbackPlan'
        'New-NhiControlledDecommissionPlan'
        'Test-NhiControlledLabLiveReversibleDisableReadiness'
        'Export-NhiControlledDecommissionEvidence'
        'New-NhiControlledLabDisableDryRunPackage'
        'New-NhiControlledLabRollbackDrillPackage'
        'Invoke-NhiControlledLabLiveReversibleDisable'
        'New-NhiRun4CFinalGoNoGoReviewPackage'
        'New-NhiRun4CLiveEvidenceCapturePackage'
        'New-NhiRun4CPostDisableObservationPackage'
        'New-NhiRun4CRollbackExecutionReadinessPackage'
        'Invoke-NhiControlledLabRollback'
        'New-NhiFinalDeleteEligibilitySimulationPackage'
        'New-NhiRun4CEndToEndLabRehearsalReport'
        'New-NhiRun4CConsultantOperatingGuide'
        'Get-NhiRun4CArtifactRecord'
        'New-NhiRun4CFinalControlledDisableTestPackage'
        'New-NhiRun4CPostDisableEvidenceValidationPackage'
        'New-NhiRun4CControlledRollbackExecutionTestPackage'
        'New-NhiRun4CPostRollbackValidationPackage'
        'New-NhiRun4CFinalEvidenceBundle'
        'New-NhiRev4ReleaseCandidateFreezePackage'
    )

    It 'imports successfully' {
        Get-Module NhiControlledDecommission | Should -Not -BeNullOrEmpty
    }

    It 'exports the required public functions and keeps private helpers hidden' {
        $exports = (Get-Module NhiControlledDecommission).ExportedFunctions.Keys
        foreach ($name in $script:ExpectedExports) {
            $exports | Should -Contain $name
        }
        Get-Command New-NhiControlledE2EEvidencePack -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command New-NhiControlledOperatorDecisionLog -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'contains no live Graph write/delete cmdlet references' {
        # Guarded read-only state checks are allowed; this only blocks live write/delete or connection paths.
        (Get-Content $script:ModulePath -Raw) | Should -Not -Match 'Connect-MgGraph|Invoke-MgGraphRequest|(?:Update|Set|New|Remove)-Mg'
    }

    It 'contains no Graph request calls' {
        (Get-Content $script:ModulePath -Raw) | Should -Not -Match 'Invoke-MgGraphRequest'
    }
}

Describe 'Get-NhiControlledDecommissionSchema' {
    BeforeAll { $script:Schema = Get-NhiControlledDecommissionSchema }

    It 'uses schema version 4.2' {
        $script:Schema.ControlledDecommissionSchemaVersion | Should -Be '4.2'
        $script:Schema.ActionLogSchemaVersion | Should -Be '4.2'
        $script:Schema.SnapshotSchemaVersion | Should -Be '4.2'
        $script:Schema.DeleteReadinessSchemaVersion | Should -Be '4.2'
    }

    It 'supports only NHI target types' {
        $script:Schema.SupportedTargetTypes | Should -Contain 'ServicePrincipal'
        $script:Schema.SupportedTargetTypes | Should -Contain 'Application'
        $script:Schema.SupportedTargetTypes | Should -Contain 'ManagedIdentity'
        $script:Schema.SupportedTargetTypes | Should -Not -Contain 'User'
    }

    It 'lists FinalDelete but blocks live mutation' {
        $script:Schema.SupportedStages | Should -Contain 'FinalDelete'
        $script:Schema.LiveMutationEnabled | Should -BeFalse
        $script:Schema.FinalDeleteLiveEnabled | Should -BeFalse
    }
}

Describe 'Get-NhiControlledDecommissionSha256' {
    It 'is deterministic' {
        Get-NhiControlledDecommissionSha256 -InputString 'rev42' | Should -Be (Get-NhiControlledDecommissionSha256 -InputString 'rev42')
    }

    It 'changes when input changes' {
        Get-NhiControlledDecommissionSha256 -InputString 'rev42-a' | Should -Not -Be (Get-NhiControlledDecommissionSha256 -InputString 'rev42-b')
    }

    It 'returns 64 lowercase hexadecimal characters' {
        Get-NhiControlledDecommissionSha256 -InputString '' | Should -Match '^[0-9a-f]{64}$'
    }
}

Describe 'ConvertTo-NhiControlledSnapshot' {
    BeforeAll {
        $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target (New-Rev42Target) -RunId 'RUN-REV42-001'
        $script:SnapshotJson = $script:Snapshot | ConvertTo-Json -Depth 20
    }

    It 'creates versioned snapshot with hash' {
        $script:Snapshot.SchemaVersion | Should -Be '4.2'
        $script:Snapshot.RunId | Should -Be 'RUN-REV42-001'
        $script:Snapshot.SHA256 | Should -Match '^[0-9a-f]{64}$'
    }

    It 'preserves non-sensitive target state' {
        $script:Snapshot.Target.ObjectId | Should -Be 'sp-rev42-001'
        $script:Snapshot.Target.AccountEnabled | Should -BeTrue
    }

    It 'removes secret and token properties' {
        $script:SnapshotJson | Should -Not -Match 'must-not-export'
        $script:Snapshot.Target.PSObject.Properties.Name | Should -Not -Contain 'ClientSecret'
        $script:Snapshot.Target.PSObject.Properties.Name | Should -Not -Contain 'AccessToken'
    }

    It 'retains credential metadata only' {
        $script:Snapshot.Target.PasswordCredentials[0].KeyId | Should -Be 'key-001'
        $script:Snapshot.Target.PasswordCredentials[0].DisplayName | Should -Be 'metadata-only'
        ($script:Snapshot.Target.PasswordCredentials[0].PSObject.Properties.Name -contains 'SecretText') | Should -BeFalse
    }

    It 'redacts nested secrets in AdditionalProperties' {
        $target = New-Rev42Target
        $target | Add-Member -NotePropertyName AdditionalProperties -NotePropertyValue ([PSCustomObject]@{
            NestedSecret = 'must-not-export'
            Inner = [PSCustomObject]@{
                ChildToken = 'must-not-export'
            }
        }) -Force
        $target.PasswordCredentials[0] | Add-Member -NotePropertyName AdditionalProperties -NotePropertyValue ([PSCustomObject]@{
            NestedSecret = 'must-not-export'
            Inner = [PSCustomObject]@{
                ChildToken = 'must-not-export'
            }
        }) -Force

        $snapshot = ConvertTo-NhiControlledSnapshot -Target $target -RunId 'RUN-REV42-002'
        $snapshotJson = $snapshot | ConvertTo-Json -Depth 20

        $snapshot.Target.AdditionalProperties.PSObject.Properties.Name | Should -Not -Contain 'NestedSecret'
        $snapshot.Target.AdditionalProperties.Inner.PSObject.Properties.Name | Should -Not -Contain 'ChildToken'
        $snapshot.Target.PasswordCredentials[0].AdditionalProperties.PSObject.Properties.Name | Should -Not -Contain 'NestedSecret'
        $snapshotJson | Should -Not -Match 'must-not-export'
    }
}

Describe 'Test-NhiControlledTarget' {
    It 'passes a supported unprotected target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target)).Passed | Should -BeTrue
    }

    It 'blocks missing ObjectId' {
        $target = New-Rev42Target -ObjectId ''
        (Test-NhiControlledTarget -Target $target).Passed | Should -BeFalse
    }

    It 'blocks unsupported user target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -ObjectType User)).Passed | Should -BeFalse
    }

    It 'blocks protected target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -ProtectedObject $true)).Passed | Should -BeFalse
    }

    It 'blocks Microsoft first-party target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -MicrosoftFirstParty $true)).Passed | Should -BeFalse
    }

    It 'blocks emergency target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -EmergencyAccessIndicator $true)).Passed | Should -BeFalse
    }

    It 'blocks break-glass target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -BreakGlassIndicator $true)).Passed | Should -BeFalse
    }

    It 'blocks active and ambiguous targets' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -HighConfidenceActive $true)).Passed | Should -BeFalse
        (Test-NhiControlledTarget -Target (New-Rev42Target -Ambiguous $true)).Passed | Should -BeFalse
    }
}

Describe 'Confirm-NhiControlledApproval' {
    It 'passes exact valid approval' {
        $result = Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly'
        $result.Passed | Should -BeTrue
    }

    It 'blocks schema mismatch' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -SchemaVersion '4.1') -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
    }

    It 'blocks missing approver and non-approved status' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -ApprovedBy '') -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -Status Pending) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
    }

    It 'blocks RunId mismatch unless reusable' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -RunId OTHER) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -RunId OTHER -Reusable $true) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeTrue
    }

    It 'blocks expired approval' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -ExpiresUtc '2020-01-01T00:00:00Z') -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
    }

    It 'blocks target and action mismatches' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId other -ActionType 'SnapshotOnly').Passed | Should -BeFalse
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'DisableOnly').Passed | Should -BeFalse
    }

    It 'blocks FinalDelete even when approval includes it' {
        $approval = New-Rev42Approval -ApprovedActions @('SnapshotOnly', 'DeleteReadinessOnly', 'FinalDelete')
        $result = Confirm-NhiControlledApproval -Approval $approval -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'FinalDelete'
        $result.Passed | Should -BeFalse
        ($result.Reasons -join ' ') | Should -Match 'FinalDelete is not permitted in Rev4\.2-S1'
    }
}

Describe 'Get-NhiControlledScreamTestStatus' {
    It 'returns Active before window completes' {
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-2)) -WindowHours 24).Status | Should -Be 'Active'
    }

    It 'returns Complete after window completes' {
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24).Status | Should -Be 'Complete'
    }

    It 'returns Blocked for dependency or recent activity' {
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24 -DependencyDetected $true).Status | Should -Be 'Blocked'
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24 -RecentActivityDetected $true).Status | Should -Be 'Blocked'
    }

    It 'fails closed to Unknown when query failed' {
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24 -QuerySucceeded $false).Status | Should -Be 'Unknown'
    }
}

Describe 'Dependency and delete-readiness evaluation' {
    It 'passes clean dependency evidence' {
        (Test-NhiControlledDependencies -Dependencies @() -RecentActivity @()).Passed | Should -BeTrue
    }

    It 'blocks critical dependency and recent activity' {
        (Test-NhiControlledDependencies -Dependencies @([PSCustomObject]@{ Severity = 'Critical' }) -RecentActivity @()).Passed | Should -BeFalse
        (Test-NhiControlledDependencies -Dependencies @() -RecentActivity @([PSCustomObject]@{ Id = 'activity-1' })).Passed | Should -BeFalse
    }

    It 'fails closed when dependency query fails' {
        (Test-NhiControlledDependencies -QuerySucceeded $false).Passed | Should -BeFalse
    }

    It 'returns Ready only when every gate passes' {
        $target = Test-NhiControlledTarget -Target (New-Rev42Target)
        $approval = Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'DeleteReadinessOnly'
        $snapshot = ConvertTo-NhiControlledSnapshot -Target (New-Rev42Target) -RunId 'RUN-REV42-001'
        $scream = Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24
        $deps = Test-NhiControlledDependencies
        (Get-NhiControlledDeleteReadiness -TargetValidation $target -ApprovalValidation $approval -Snapshot $snapshot -ScreamTest $scream -DependencyCheck $deps).Status | Should -Be 'Ready'
    }

    It 'never enables live FinalDelete' {
        $target = Test-NhiControlledTarget -Target (New-Rev42Target)
        $approval = Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'DeleteReadinessOnly'
        $snapshot = ConvertTo-NhiControlledSnapshot -Target (New-Rev42Target) -RunId 'RUN-REV42-001'
        $scream = Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24
        $deps = Test-NhiControlledDependencies
        (Get-NhiControlledDeleteReadiness -TargetValidation $target -ApprovalValidation $approval -Snapshot $snapshot -ScreamTest $scream -DependencyCheck $deps).FinalDeleteLiveEnabled | Should -BeFalse
    }
}

Describe 'Planner, rollback, and evidence exports' {
    It 'creates planning-only snapshot plan' {
        $plan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage SnapshotOnly -RunId 'RUN-REV42-001'
        $plan.Status | Should -Be 'Planned'
        $plan.PlanningOnly | Should -BeTrue
        $plan.LiveMutationEnabled | Should -BeFalse
        $plan.FinalDeleteLiveEnabled | Should -BeFalse
    }

    It 'blocks FinalDelete in all S1 plans' {
        foreach ($mode in @(
            @{ WhatIf = $true; DemoMode = $false },
            @{ WhatIf = $false; DemoMode = $true },
            @{ WhatIf = $false; DemoMode = $false }
        )) {
            $plan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage FinalDelete -RunId 'RUN-REV42-001' -WhatIf $mode.WhatIf -DemoMode $mode.DemoMode
            $plan.Status | Should -Be 'Blocked'
            $plan.BlockReason | Should -Match 'blocked for live execution'
            $plan.LiveMutationEnabled | Should -BeFalse
        }
    }

    It 'blocks plans for protected targets' {
        (New-NhiControlledDecommissionPlan -Target (New-Rev42Target -ProtectedObject $true) -ExecutionStage SnapshotOnly -RunId 'RUN-REV42-001').Status | Should -Be 'Blocked'
    }

    It 'creates rollback plan linked to snapshot hash' {
        $snapshot = ConvertTo-NhiControlledSnapshot -Target (New-Rev42Target) -RunId 'RUN-REV42-001'
        $rollback = New-NhiControlledRollbackPlan -Snapshot $snapshot -RunId 'RUN-REV42-001'
        $rollback.RollbackAvailable | Should -BeTrue
        $rollback.SnapshotSHA256 | Should -Be $snapshot.SHA256
        $rollback.PlannedActions.Count | Should -Be 2
    }

    It 'exports UTF-8 JSON evidence' {
        $path = Join-Path $TestDrive 'evidence\plan.json'
        $plan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage SnapshotOnly -RunId 'RUN-REV42-001'
        Export-NhiControlledDecommissionEvidence -Evidence $plan -Path $path | Should -Be $path
        Test-Path $path | Should -BeTrue
        (Get-Content $path -Raw | ConvertFrom-Json).SchemaVersion | Should -Be '4.2'
    }
}

Describe 'Rev4.2-S1 sample artifacts' {
    BeforeAll {
        $script:PlanSampleRaw = Get-Content $script:PlanSamplePath -Raw
        $script:ApprovalSampleRaw = Get-Content $script:ApprovalSamplePath -Raw
        $script:PlanSample = $script:PlanSampleRaw | ConvertFrom-Json
        $script:ApprovalSample = $script:ApprovalSampleRaw | ConvertFrom-Json
    }

    It 'includes both required sample files' {
        Test-Path $script:PlanSamplePath | Should -BeTrue
        Test-Path $script:ApprovalSamplePath | Should -BeTrue
    }

    It 'parses both samples as valid JSON' {
        $script:PlanSample | Should -Not -BeNullOrEmpty
        $script:ApprovalSample | Should -Not -BeNullOrEmpty
    }

    It 'uses Rev4.2 schema in both samples' {
        $script:PlanSample.SchemaVersion | Should -Be '4.2'
        $script:ApprovalSample.SchemaVersion | Should -Be '4.2'
    }

    It 'binds approval and plan to the same RunId and target' {
        $script:ApprovalSample.RunId | Should -Be $script:PlanSample.RunId
        $script:ApprovalSample.TargetObjectIds | Should -Contain $script:PlanSample.TargetId
    }

    It 'keeps plan sample WhatIf Demo and planning-only' {
        $script:PlanSample.WhatIf | Should -BeTrue
        $script:PlanSample.DemoMode | Should -BeTrue
        $script:PlanSample.PlanningOnly | Should -BeTrue
        $script:PlanSample.LiveMutationEnabled | Should -BeFalse
    }

    It 'keeps approval sample evidence-only' {
        $script:ApprovalSample.LiveMutationApproved | Should -BeFalse
        $script:ApprovalSample.FinalDeleteApproved | Should -BeFalse
        $script:ApprovalSample.ApprovedActions | Should -Not -Contain 'FinalDelete'
        $script:ApprovalSample.ApprovedActions | Should -Not -Contain 'DisableOnly'
        $script:ApprovalSample.ApprovedActions | Should -Not -Contain 'TagOnly'
    }

    It 'contains a blocked FinalDelete action in the plan sample' {
        $finalDelete = $script:PlanSample.Actions | Where-Object { $_.ActionType -eq 'FinalDelete' }
        $finalDelete | Should -Not -BeNullOrEmpty
        $finalDelete.Result | Should -Be 'Blocked'
        $finalDelete.Warnings -join ' ' | Should -Match 'blocked for live execution'
    }

    It 'never enables FinalDelete in plan readiness evidence' {
        $script:PlanSample.FinalDeleteLiveEnabled | Should -BeFalse
        $script:PlanSample.DeleteReadiness.FinalDeleteLiveEnabled | Should -BeFalse
    }

    It 'contains no secret token or certificate values' {
        foreach ($raw in @($script:PlanSampleRaw, $script:ApprovalSampleRaw)) {
            $raw | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        }
    }

    It 'contains no prohibited Graph delete cmdlet names' {
        $script:PlanSampleRaw | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication'
        $script:ApprovalSampleRaw | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication'
    }

    It 'validates sample approval for DeleteReadinessOnly' {
        $result = Confirm-NhiControlledApproval -Approval $script:ApprovalSample -RunId $script:PlanSample.RunId -TargetId $script:PlanSample.TargetId -ActionType 'DeleteReadinessOnly'
        $result.Passed | Should -BeTrue
    }

    It 'rejects sample approval for FinalDelete' {
        $result = Confirm-NhiControlledApproval -Approval $script:ApprovalSample -RunId $script:PlanSample.RunId -TargetId $script:PlanSample.TargetId -ActionType 'FinalDelete'
        $result.Passed | Should -BeFalse
    }

    It 'produces evidence-only WhatIf and Demo plans' {
        $whatIfPlan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage SnapshotOnly -RunId 'RUN-WHATIF' -WhatIf $true
        $demoPlan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage SnapshotOnly -RunId 'RUN-DEMO' -WhatIf $false -DemoMode $true
        foreach ($plan in @($whatIfPlan, $demoPlan)) {
            $plan.PlanningOnly | Should -BeTrue
            $plan.LiveMutationEnabled | Should -BeFalse
        }
    }

    It 'blocks FinalDelete for WhatIf Demo and live-mode plan requests' {
        foreach ($settings in @(
            @{ RunId = 'RUN-WHATIF-FD'; WhatIf = $true; DemoMode = $false },
            @{ RunId = 'RUN-DEMO-FD'; WhatIf = $false; DemoMode = $true },
            @{ RunId = 'RUN-LIVE-FD'; WhatIf = $false; DemoMode = $false }
        )) {
            $plan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage FinalDelete -RunId $settings.RunId -WhatIf $settings.WhatIf -DemoMode $settings.DemoMode
            $plan.Status | Should -Be 'Blocked'
            $plan.LiveMutationEnabled | Should -BeFalse
        }
    }
}
