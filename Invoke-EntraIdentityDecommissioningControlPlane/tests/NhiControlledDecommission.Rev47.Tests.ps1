#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-managed-identity-readiness.sample.json'
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

    $script:Target = [PSCustomObject]@{
        ObjectId = 'mi-rev47-test-001'
        ObjectType = 'ManagedIdentity'
        DisplayName = 'Rev47 Managed Identity'
        ManagedIdentityType = 'SystemAssigned'
        ProtectedObject = $false
        MicrosoftFirstParty = $false
        EmergencyAccessIndicator = $false
        BreakGlassIndicator = $false
        HighConfidenceActive = $false
        Ambiguous = $false
    }
    $script:TargetValidation = Test-NhiControlledTarget -Target $script:Target
    $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target $script:Target -RunId 'RUN-REV47-MI-SAMPLE-001'
    $script:RawSample = Get-Content -LiteralPath $script:SamplePath -Raw
    $script:Sample = $script:RawSample | ConvertFrom-Json

    function New-Rev47Plan {
        param([hashtable]$Overrides = @{})
        $plan = [ordered]@{
            SchemaVersion = '4.7'
            RunId = 'RUN-REV47-MI-SAMPLE-001'
            TargetId = 'mi-rev47-test-001'
            TargetType = 'ManagedIdentity'
            ManagedIdentityType = 'SystemAssigned'
            ApprovalId = 'APP-REV47-MI-001'
            TargetObjectIds = @('mi-rev47-test-001')
            ApprovedActions = @('ManagedIdentityReadiness')
            ParentResourceEvidence = [PSCustomObject]@{
                Present = $true
                ParentResourceId = 'res-group-rev47-001'
                ParentResourceType = 'Microsoft.Web/sites'
                LocalOnly = $true
            }
            AttachmentEvidence = [PSCustomObject]@{
                Present = $true
                ResourceId = 'mi-rev47-test-001'
                Attached = $true
                LocalOnly = $true
            }
            RoleAssignmentEvidence = [PSCustomObject]@{
                ActiveRoleAssignmentCount = 0
                QuerySucceeded = $true
            }
            FederatedCredentialEvidence = [PSCustomObject]@{
                ActiveDependencyCount = 0
                AppRelationshipDependencyCount = 0
                QuerySucceeded = $true
            }
            DependencyRecheck = [PSCustomObject]@{
                SchemaVersion = '4.7'
                Status = 'Clean'
                QuerySucceeded = $true
                Blocked = $false
                SkippedWithApproval = $false
            }
            DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
            ScreamTestEvidence = [PSCustomObject]@{
                EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                Status = 'Complete'
                DependencyDetected = $false
                RecentActivityDetected = $false
                QuerySucceeded = $true
            }
            RollbackLimitation = 'EvidenceOnly'
            LiveCleanupApproved = $false
            LiveCleanupExecutable = $false
        }
        foreach ($key in $Overrides.Keys) { $plan[$key] = $Overrides[$key] }
        [PSCustomObject]$plan
    }

    function New-Rev47Approval {
        param([hashtable]$Overrides = @{})
        $approval = [ordered]@{
            SchemaVersion = '4.7'
            RunId = 'RUN-REV47-MI-SAMPLE-001'
            Status = 'Approved'
            ApprovedBy = 'managed-identity-approver@example.com'
            ExpiresUtc = '2099-01-01T00:00:00Z'
            Reusable = $false
            ApprovalId = 'APP-REV47-MI-001'
            TargetId = 'mi-rev47-test-001'
            TargetType = 'ManagedIdentity'
            ManagedIdentityType = 'SystemAssigned'
            TargetObjectIds = @('mi-rev47-test-001')
            ApprovedActions = @('ManagedIdentityReadiness')
            LiveCleanupApproved = $false
            LiveCleanupExecutable = $false
        }
        foreach ($key in $Overrides.Keys) { $approval[$key] = $Overrides[$key] }
        [PSCustomObject]$approval
    }

    function New-Rev47GateInput {
        param(
            [hashtable]$PlanOverrides = @{},
            [hashtable]$ApprovalOverrides = @{},
            [string]$Stage = 'ManagedIdentityReadiness',
            [bool]$TargetPassed = $true,
            [bool]$SnapshotPresent = $true,
            [bool]$WhatIf = $true,
            [bool]$DemoMode = $false,
            [string]$DeleteReadinessStatus = 'Ready',
            [string]$DependencyStatus = 'Clean',
            [bool]$IncludeSnapshotId = $true
        )

        $plan = New-Rev47Plan -Overrides $PlanOverrides
        $snapshot = if ($SnapshotPresent) { $script:Snapshot } else { $null }
        $approvalOverrides = @{}
        foreach ($key in $ApprovalOverrides.Keys) { $approvalOverrides[$key] = $ApprovalOverrides[$key] }
        if (-not $approvalOverrides.ContainsKey('SnapshotId')) {
            $approvalOverrides['SnapshotId'] = if ($IncludeSnapshotId -and $snapshot) { $snapshot.SHA256 } else { $null }
        }
        $approval = New-Rev47Approval -Overrides $approvalOverrides

        @{
            ExecutionStage = $Stage
            Plan = $plan
            Approval = $approval
            TargetValidation = if ($TargetPassed) { $script:TargetValidation } else { [PSCustomObject]@{ Passed = $false; Reasons = @('Target validation failed.') } }
            Snapshot = $snapshot
            DeleteReadiness = [PSCustomObject]@{ Status = $DeleteReadinessStatus }
            DependencyRecheck = if ($DependencyStatus -eq 'Clean') {
                [PSCustomObject]@{ SchemaVersion = '4.7'; Status = 'Clean'; QuerySucceeded = $true; Blocked = $false; SkippedWithApproval = $false }
            } elseif ($DependencyStatus -eq 'Blocked') {
                [PSCustomObject]@{ SchemaVersion = '4.7'; Status = 'Blocked'; QuerySucceeded = $true; Blocked = $true; SkippedWithApproval = $false }
            } else {
                [PSCustomObject]@{ SchemaVersion = '4.7'; Status = 'Unknown'; QuerySucceeded = $false; Blocked = $false; SkippedWithApproval = $false }
            }
            RoleAssignmentEvidence = if ($null -ne $plan.RoleAssignmentEvidence) { $plan.RoleAssignmentEvidence } else { [PSCustomObject]@{ ActiveRoleAssignmentCount = 0; QuerySucceeded = $true } }
            FederatedCredentialEvidence = if ($null -ne $plan.FederatedCredentialEvidence) { $plan.FederatedCredentialEvidence } else { [PSCustomObject]@{ ActiveDependencyCount = 0; AppRelationshipDependencyCount = 0; QuerySucceeded = $true } }
            ParentResourceEvidence = if ($null -ne $plan.ParentResourceEvidence) { $plan.ParentResourceEvidence } else { $null }
            AttachmentEvidence = if ($null -ne $plan.AttachmentEvidence) { $plan.AttachmentEvidence } else { $null }
            WhatIf = $WhatIf
            DemoMode = $DemoMode
        }
    }

    function Invoke-Rev47Gate {
        param([hashtable]$InputObject)
        $module = Get-Module NhiControlledDecommission
        & $module {
            param($GateInput)
            Test-NhiControlledManagedIdentityReadinessGate @GateInput
        } $InputObject
    }

    function Invoke-Rev47EntryPoint {
        param(
            [string]$PlanPath,
            [string]$ApprovalPath,
            [string]$Stage = 'ManagedIdentityReadiness'
        )

        $stdout = [System.IO.Path]::GetTempFileName()
        $stderr = [System.IO.Path]::GetTempFileName()
        $command = "& '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1' -ExecuteNhiControlledDecommission -ExecutionStage '$Stage' -DecommissionPlanPath '$PlanPath' -ApprovalManifestPath '$ApprovalPath' -WhatIfExecution"
        $process = Start-Process -FilePath 'C:\Program Files\PowerShell\7\pwsh.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr

        [PSCustomObject]@{
            ExitCode = $process.ExitCode
            StdOut = Get-Content -LiteralPath $stdout -Raw
            StdErr = Get-Content -LiteralPath $stderr -Raw
        }
    }

    function New-Rev47DirectGateInput {
        param(
            [string]$ManagedIdentityType = 'SystemAssigned',
            [string]$ApprovalManagedIdentityType = $ManagedIdentityType,
            [string]$ApprovalId = 'APP-REV47-MI-001',
            [string]$TargetId = 'mi-rev47-test-001',
            [string]$ApprovedActions = 'ManagedIdentityReadiness',
            [bool]$WhatIf = $true,
            [bool]$DemoMode = $false
        )

        $target = [PSCustomObject]@{
            ObjectId = 'mi-rev47-test-001'
            ObjectType = 'ManagedIdentity'
            DisplayName = 'Rev47 Managed Identity'
            ManagedIdentityType = 'SystemAssigned'
            ProtectedObject = $false
            MicrosoftFirstParty = $false
            EmergencyAccessIndicator = $false
            BreakGlassIndicator = $false
            HighConfidenceActive = $false
            Ambiguous = $false
        }
        $plan = [PSCustomObject]@{
            SchemaVersion = '4.7'
            RunId = 'RUN-REV47-MI-SAMPLE-001'
            TargetId = 'mi-rev47-test-001'
            TargetType = 'ManagedIdentity'
            ManagedIdentityType = $ManagedIdentityType
            ApprovalId = 'APP-REV47-MI-001'
            TargetObjectIds = @('mi-rev47-test-001')
            ApprovedActions = @('ManagedIdentityReadiness')
            ParentResourceEvidence = [PSCustomObject]@{
                Present = $true
                ParentResourceId = 'res-group-rev47-001'
                ParentResourceType = 'Microsoft.Web/sites'
                LocalOnly = $true
            }
            AttachmentEvidence = [PSCustomObject]@{
                Present = $true
                ResourceId = 'mi-rev47-test-001'
                Attached = $true
                LocalOnly = $true
            }
            RoleAssignmentEvidence = [PSCustomObject]@{
                ActiveRoleAssignmentCount = 0
                QuerySucceeded = $true
            }
            FederatedCredentialEvidence = [PSCustomObject]@{
                ActiveDependencyCount = 0
                AppRelationshipDependencyCount = 0
                QuerySucceeded = $true
            }
            DependencyRecheck = [PSCustomObject]@{
                SchemaVersion = '4.7'
                Status = 'Clean'
                QuerySucceeded = $true
                Blocked = $false
                SkippedWithApproval = $false
            }
            DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
            ScreamTestEvidence = [PSCustomObject]@{
                EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                Status = 'Complete'
                DependencyDetected = $false
                RecentActivityDetected = $false
                QuerySucceeded = $true
            }
            RollbackLimitation = 'EvidenceOnly'
            LiveCleanupApproved = $false
            LiveCleanupExecutable = $false
        }
        $approval = [PSCustomObject]@{
            SchemaVersion = '4.7'
            RunId = 'RUN-REV47-MI-SAMPLE-001'
            Status = 'Approved'
            ApprovedBy = 'managed-identity-approver@example.com'
            ExpiresUtc = '2099-01-01T00:00:00Z'
            Reusable = $false
            ApprovalId = $ApprovalId
            TargetId = $TargetId
            TargetType = 'ManagedIdentity'
            ManagedIdentityType = $ApprovalManagedIdentityType
            TargetObjectIds = @('mi-rev47-test-001')
            ApprovedActions = @($ApprovedActions)
            LiveCleanupApproved = $false
            LiveCleanupExecutable = $false
        }
        $snapshot = ConvertTo-NhiControlledSnapshot -Target $target -RunId 'RUN-REV47-MI-SAMPLE-001'

        @{
            ExecutionStage = 'ManagedIdentityReadiness'
            Plan = $plan
            Approval = $approval
            TargetValidation = (Test-NhiControlledTarget -Target $target)
            Snapshot = $snapshot
            DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
            DependencyRecheck = $plan.DependencyRecheck
            RoleAssignmentEvidence = $plan.RoleAssignmentEvidence
            FederatedCredentialEvidence = $plan.FederatedCredentialEvidence
            ParentResourceEvidence = $plan.ParentResourceEvidence
            AttachmentEvidence = $plan.AttachmentEvidence
            WhatIf = $WhatIf
            DemoMode = $DemoMode
        }
    }

    function Invoke-Rev47Module {
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

Describe 'Rev4.7 managed identity contract' {
    It 'keeps the private evaluator hidden and export contract frozen' {
        Get-Command Test-NhiControlledManagedIdentityReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        $exports = (Get-Module NhiControlledDecommission).ExportedCommands.Keys
        $exports | Should -Contain 'Test-NhiControlledTarget'
        $exports | Should -Contain 'New-NhiControlledDecommissionPlan'
        $exports | Should -Contain 'ConvertTo-NhiControlledSnapshot'
        $exports | Should -Contain 'Test-NhiControlledLabLiveReversibleDisableReadiness'
    }

    It 'parses the managed identity sample JSON' {
        $script:Sample | Should -Not -BeNullOrEmpty
        $script:Sample.SchemaVersion | Should -Be '4.7'
        $script:Sample.TargetType | Should -Be 'ManagedIdentity'
    }

    It 'contains no secret-like values or delete cmdlet names' {
        $script:RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        $script:RawSample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az'
    }

    It 'captures managed identity evidence in the sample' {
        $script:Sample.ManagedIdentityType | Should -Be 'SystemAssigned'
        $script:Sample.ParentResourceEvidence.ParentResourceId | Should -Be 'res-group-rev47-001'
        $script:Sample.DeleteReadiness.Status | Should -Be 'Ready'
    }

    It 'classifies managed identity type from the plan' {
        (Invoke-Rev47Module { param($Plan) Get-NhiControlledManagedIdentityType -Plan $Plan } (New-Rev47Plan)).ManagedIdentityType | Should -Be 'SystemAssigned'
    }

    It 'classifies a user-assigned managed identity' {
        (Invoke-Rev47Module { param($Plan) Get-NhiControlledManagedIdentityType -Plan $Plan } (New-Rev47Plan -Overrides @{ ManagedIdentityType = 'UserAssigned' })).ManagedIdentityType | Should -Be 'UserAssigned'
    }

    It 'classifies an unknown managed identity type' {
        (Invoke-Rev47Module { param($Plan) Get-NhiControlledManagedIdentityType -Plan $Plan } (New-Rev47Plan -Overrides @{ ManagedIdentityType = 'Unexpected' })).ManagedIdentityType | Should -Be 'Unknown'
    }

    It 'produces managed identity plan and action log objects' {
        $readiness = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
        $plan = Invoke-Rev47Module {
            param($Plan, $Readiness, $Snapshot, $RoleAssignmentEvidence, $FederatedCredentialEvidence, $ParentResourceEvidence, $AttachmentEvidence)
            New-NhiControlledManagedIdentityReadinessPlan -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot -RoleAssignmentEvidence $RoleAssignmentEvidence -FederatedCredentialEvidence $FederatedCredentialEvidence -ParentResourceEvidence $ParentResourceEvidence -AttachmentEvidence $AttachmentEvidence
        } (New-Rev47Plan) $readiness $script:Snapshot (New-Rev47Plan).RoleAssignmentEvidence (New-Rev47Plan).FederatedCredentialEvidence (New-Rev47Plan).ParentResourceEvidence (New-Rev47Plan).AttachmentEvidence
        $actionLog = Invoke-Rev47Module {
            param($Plan, $Readiness, $Snapshot)
            New-NhiControlledManagedIdentityActionLog -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot
        } (New-Rev47Plan) $readiness $script:Snapshot
        $plan.Status | Should -Be 'Planned'
        $actionLog.Result | Should -Be 'SimulationOnly'
    }

    It 'satisfies readiness only as simulation when every gate passes' {
        $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
        $result.GatesPassed | Should -BeTrue
        $result.Status | Should -Be 'ManagedIdentityReadinessSatisfiedSimulationOnly'
    }

    It 'supports DemoMode readiness simulation only' {
        $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $false -DemoMode $true)
        $result.GatesPassed | Should -BeTrue
        $result.DemoMode | Should -BeTrue
    }

    It 'supports WhatIf readiness simulation only' {
        $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
        $result.GatesPassed | Should -BeTrue
        $result.WhatIf | Should -BeTrue
    }

    It 'fails closed from the entry point when system-assigned parent evidence is missing' {
        $plan = (New-Rev47Plan -Overrides @{ ParentResourceEvidence = $null })
        $planPath = Join-Path $TestDrive 'rev47-systemassigned-missing-parent.plan.json'
        $approvalPath = Join-Path $TestDrive 'rev47-systemassigned-missing-parent.approval.json'
        $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $planPath -Encoding utf8
        (New-Rev47Approval) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvalPath -Encoding utf8

        $result = Invoke-Rev47EntryPoint -PlanPath $planPath -ApprovalPath $approvalPath
        $result.ExitCode | Should -Be 1
        $result.StdOut | Should -Match '\[SECURITY STOP\] SystemAssigned managed identity requires ParentResourceEvidence'
        $result.StdOut | Should -Not -Match 'managed identity readiness completed'
    }

    It 'fails closed from the entry point when user-assigned attachment evidence is missing' {
        $plan = (New-Rev47Plan -Overrides @{ ManagedIdentityType = 'UserAssigned'; AttachmentEvidence = $null })
        $approval = [PSCustomObject]@{
            SchemaVersion = '4.7'
            RunId = 'RUN-REV47-MI-SAMPLE-001'
            Status = 'Approved'
            ApprovedBy = 'managed-identity-approver@example.com'
            ExpiresUtc = '2099-01-01T00:00:00Z'
            Reusable = $false
            ApprovalId = 'APP-REV47-MI-001'
            TargetId = 'mi-rev47-test-001'
            TargetType = 'ManagedIdentity'
            ManagedIdentityType = 'UserAssigned'
            TargetObjectIds = @('mi-rev47-test-001')
            ApprovedActions = @('ManagedIdentityReadiness')
            LiveCleanupApproved = $false
            LiveCleanupExecutable = $false
        }
        $planPath = Join-Path $TestDrive 'rev47-userassigned-missing-attachment.plan.json'
        $approvalPath = Join-Path $TestDrive 'rev47-userassigned-missing-attachment.approval.json'
        $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $planPath -Encoding utf8
        $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvalPath -Encoding utf8

        $result = Invoke-Rev47EntryPoint -PlanPath $planPath -ApprovalPath $approvalPath
        $result.ExitCode | Should -Be 1
        $result.StdOut | Should -Match '\[SECURITY STOP\] UserAssigned managed identity requires AttachmentEvidence'
        $result.StdOut | Should -Not -Match 'managed identity readiness completed'
    }

    It 'keeps readiness simulation-only and non-executable' {
        $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
        $result.LiveCleanupExecutable | Should -BeFalse
        $result.CleanupCmdletAvailable | Should -BeFalse
        $result.SimulationOnly | Should -BeTrue
    }

    It 'passes the entry point when supplied managed identity evidence is present' {
        $plan = New-Rev47Plan
        $planPath = Join-Path $TestDrive 'rev47-valid.plan.json'
        $approvalPath = Join-Path $TestDrive 'rev47-valid.approval.json'
        $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $planPath -Encoding utf8
        (New-Rev47Approval) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvalPath -Encoding utf8

        $result = Invoke-Rev47EntryPoint -PlanPath $planPath -ApprovalPath $approvalPath
        $result.ExitCode | Should -Be 0
        $result.StdOut | Should -Match 'Rev4.7 managed identity readiness completed'
    }

    It 'requires explicit status normalization for missing text' {
        (Invoke-Rev47Module { param($Value) Get-NhiControlledStatusText -Value $Value } $null) | Should -Be 'Incomplete'
        (Invoke-Rev47Module { param($Value) Get-NhiControlledStatusText -Value $Value } 'Ready') | Should -Be 'Ready'
    }

    It 'passes with a user-assigned attachment and parent evidence present' {
        $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ManagedIdentityType 'UserAssigned' -ApprovalManagedIdentityType 'UserAssigned' -ApprovalId 'APP-REV47-MI-001' -TargetId 'mi-rev47-test-001' -ApprovedActions 'ManagedIdentityReadiness' -WhatIf $true)
        $result.GatesPassed | Should -BeTrue
        $result.ManagedIdentityType | Should -Be 'UserAssigned'
    }

    It 'passes with system-assigned parent evidence present' {
        $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
        $result.GatesPassed | Should -BeTrue
        $result.ManagedIdentityType | Should -Be 'SystemAssigned'
    }

    It 'preserves approval target object ids and readiness contract fields' {
        $readiness = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
        $plan = Invoke-Rev47Module {
            param($Plan, $Readiness, $Snapshot, $RoleAssignmentEvidence, $FederatedCredentialEvidence, $ParentResourceEvidence, $AttachmentEvidence)
            New-NhiControlledManagedIdentityReadinessPlan -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot -RoleAssignmentEvidence $RoleAssignmentEvidence -FederatedCredentialEvidence $FederatedCredentialEvidence -ParentResourceEvidence $ParentResourceEvidence -AttachmentEvidence $AttachmentEvidence
        } (New-Rev47Plan) $readiness $script:Snapshot (New-Rev47Plan).RoleAssignmentEvidence (New-Rev47Plan).FederatedCredentialEvidence (New-Rev47Plan).ParentResourceEvidence (New-Rev47Plan).AttachmentEvidence
        $plan.RollbackLimitation | Should -Be 'EvidenceOnly'
        $plan.LiveCleanupEnabled | Should -BeFalse
        $plan.EvidenceKind | Should -Be 'ManagedIdentityReadiness'
    }

    It 'keeps the approval target object ids stable in the sample' {
        $script:Sample.TargetObjectIds[0] | Should -Be 'mi-rev47-test-001'
        $script:Sample.ApprovedActions[0] | Should -Be 'ManagedIdentityReadiness'
    }
}

Describe 'Rev4.7 required gate failures' {
    It 'blocks <Name>' -ForEach @(
        @{ Name = 'missing stage'; Build = { New-Rev47GateInput -Stage 'DeleteReadinessOnly' }; Pattern = 'ManagedIdentityReadiness' }
        @{ Name = 'wrong target type'; Build = { New-Rev47GateInput -PlanOverrides @{ TargetType = 'Application' } }; Pattern = 'Target type must be ManagedIdentity' }
        @{ Name = 'unknown identity type'; Build = { New-Rev47GateInput -PlanOverrides @{ ManagedIdentityType = 'Unexpected' } }; Pattern = 'Managed identity type is Unknown' }
        @{ Name = 'missing parent evidence'; Build = { New-Rev47GateInput -PlanOverrides @{ ParentResourceEvidence = $null } }; Pattern = 'parent resource evidence' }
        @{ Name = 'missing attachment evidence'; Build = { New-Rev47GateInput -PlanOverrides @{ ManagedIdentityType = 'UserAssigned'; AttachmentEvidence = $null } }; Pattern = 'attachment evidence' }
        @{ Name = 'role assignments present'; Build = { New-Rev47GateInput -PlanOverrides @{ RoleAssignmentEvidence = [PSCustomObject]@{ ActiveRoleAssignmentCount = 1; QuerySucceeded = $true } } }; Pattern = 'role assignments block readiness' }
        @{ Name = 'federated dependency present'; Build = { New-Rev47GateInput -PlanOverrides @{ FederatedCredentialEvidence = [PSCustomObject]@{ ActiveDependencyCount = 1; AppRelationshipDependencyCount = 0; QuerySucceeded = $true } } }; Pattern = 'Federated credential or app relationship dependency blocks readiness' }
        @{ Name = 'app relationship dependency present'; Build = { New-Rev47GateInput -PlanOverrides @{ FederatedCredentialEvidence = [PSCustomObject]@{ ActiveDependencyCount = 0; AppRelationshipDependencyCount = 1; QuerySucceeded = $true } } }; Pattern = 'Federated credential or app relationship dependency blocks readiness' }
        @{ Name = 'dependency unknown'; Build = { New-Rev47GateInput -DependencyStatus 'Unknown' }; Pattern = 'Dependency recheck blocks readiness' }
        @{ Name = 'dependency blocked'; Build = { New-Rev47GateInput -DependencyStatus 'Blocked' }; Pattern = 'Dependency recheck blocks readiness' }
        @{ Name = 'snapshot missing'; Build = { New-Rev47GateInput -SnapshotPresent $false }; Pattern = 'Snapshot evidence is required' }
        @{ Name = 'delete readiness blocked'; Build = { New-Rev47GateInput -DeleteReadinessStatus 'Blocked' }; Pattern = 'Delete-readiness must be Ready' }
        @{ Name = 'target validation failed'; Build = { New-Rev47GateInput -TargetPassed $false }; Pattern = 'Target validation failed' }
        @{ Name = 'unattended live-mode request'; Build = { New-Rev47GateInput -WhatIf $false -DemoMode $false }; Pattern = 'WhatIf or DemoMode' }
    ) {
        $result = Invoke-Rev47Gate (& $Build)
        $result.GatesPassed | Should -BeFalse
        $result.Status | Should -Be 'Blocked'
        $result.LiveCleanupExecutable | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match $Pattern
    }

    It 'blocks approval id mismatch' {
        $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ApprovalId 'APP-REV47-WRONG')
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Exact approval is required'
    }

    It 'blocks target mismatch' {
        $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -TargetId 'other-target')
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Exact target binding is required'
    }

    It 'blocks approval action missing' {
        $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ApprovedActions 'SomethingElse')
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Approval must specifically authorize the readiness action'
    }

    It 'blocks managed identity type mismatch' {
        $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ManagedIdentityType 'SystemAssigned' -ApprovalManagedIdentityType 'UserAssigned' -ApprovalId 'APP-REV47-MI-001' -TargetId 'mi-rev47-test-001' -ApprovedActions 'ManagedIdentityReadiness' -WhatIf $true)
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Managed identity type mismatch blocks readiness'
    }

    It 'blocks managed identity approval type mismatch' {
        $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ManagedIdentityType 'UserAssigned' -ApprovalManagedIdentityType 'SystemAssigned' -ApprovalId 'APP-REV47-MI-001' -TargetId 'mi-rev47-test-001' -ApprovedActions 'ManagedIdentityReadiness' -WhatIf $true)
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Managed identity type mismatch blocks readiness'
    }

    It 'blocks exact target binding missing' {
        $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -TargetId '')
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Exact target binding is required'
    }
}
