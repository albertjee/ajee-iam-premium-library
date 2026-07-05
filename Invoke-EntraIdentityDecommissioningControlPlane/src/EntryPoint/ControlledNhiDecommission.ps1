    # Rev4.2-S1 controlled NHI decommission planner/evidence flow
    # This branch intentionally short-circuits before the legacy Rev4.0 execution path.
    if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup) {
        $controlledInvocationLabel = if ($ExecuteNhiControlledMetadataCleanup) {
            '-ExecuteNhiControlledMetadataCleanup'
        } elseif ($ExecuteNhiControlledGrantCleanup) {
            '-ExecuteNhiControlledGrantCleanup'
        } else {
            '-ExecuteNhiControlledDecommission'
        }
        if (-not $WhatIfExecution -and -not $DemoMode) {
            Write-Host '[ERROR] Rev4.2-S1 controlled decommission is planner/evidence only. Use -WhatIfExecution or -DemoMode.' -ForegroundColor Red
            [System.Environment]::Exit(1)
        }
    if (-not $DecommissionPlanPath -or -not (Test-Path -LiteralPath $DecommissionPlanPath -PathType Leaf)) {
        Write-Host "[ERROR] $controlledInvocationLabel requires a valid -DecommissionPlanPath." -ForegroundColor Red
        [System.Environment]::Exit(1)
    }
    if (-not $ApprovalManifestPath -or -not (Test-Path -LiteralPath $ApprovalManifestPath -PathType Leaf)) {
        Write-Host "[ERROR] $controlledInvocationLabel requires a valid -ApprovalManifestPath." -ForegroundColor Red
        [System.Environment]::Exit(1)
    }
    # Rev4.2-S1 compatibility marker: $ExecutionStage -eq 'FinalDelete' -or $AllowFinalDelete remains guarded.
    if ($AllowFinalDelete -and $ExecutionStage -ne 'FinalDelete') {
        Write-Host '[SECURITY STOP] -AllowFinalDelete requires -ExecutionStage FinalDelete.' -ForegroundColor Red
        [System.Environment]::Exit(1)
    }
    if ($ExecutionStage -eq 'FinalDelete' -and -not $AllowFinalDelete) {
        Write-Host '[SECURITY STOP] FinalDelete is blocked for live execution by default and requires -AllowFinalDelete for Rev4.3 simulation.' -ForegroundColor Red
        # Rev4.2-S1 safety contract: FinalDelete is blocked for live execution in Rev4.2-S1.
        [System.Environment]::Exit(1)
    }
    if ($RequireSecondConfirmation) {
        Write-Host '[INFO] -RequireSecondConfirmation recorded for planning evidence. No interactive mutation is available in Rev4.2-S1.' -ForegroundColor Gray
    }

    # Normalize switches once — avoid .IsPresent on potentially-null values
    $whatIfExecutionPresent = [bool]$WhatIfExecution
    $demoModePresent = [bool]$DemoMode
    $allowFinalDeletePresent = [bool]$AllowFinalDelete

    $controlledFeatureStage = switch ($true) {
        { $ExecuteNhiControlledMetadataCleanup } { 'MetadataCleanupReadiness' }
        { $ExecuteNhiControlledGrantCleanup }    { 'GrantCleanupReadiness' }
        default                                  { $ExecutionStage }
    }

    try {
        $controlledPlanInput = Get-Content -LiteralPath $DecommissionPlanPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $controlledApproval = Get-Content -LiteralPath $ApprovalManifestPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch {
        Write-Host "[ERROR] Controlled decommission input parsing failed: $_" -ForegroundColor Red
        [System.Environment]::Exit(1)
    }

    $expectedControlledSchemaVersion = switch ($controlledFeatureStage) {
        'MetadataCleanupReadiness' { '4.5' }
        'GrantCleanupReadiness'    { '4.6' }
        'ManagedIdentityReadiness'  { '4.7' }
        'E2EEvidencePack'          { '4.8' }
        'ProductionReadiness'      { '4.9' }
        default                    { '4.2' }
    }
    if ([string]$controlledPlanInput.SchemaVersion -ne $expectedControlledSchemaVersion) {
        Write-Host "[ERROR] Controlled decommission plan SchemaVersion must be $expectedControlledSchemaVersion." -ForegroundColor Red
        [System.Environment]::Exit(1)
    }
    if (-not $controlledPlanInput.RunId -or -not $controlledPlanInput.TargetId -or -not $controlledPlanInput.TargetType) {
        Write-Host '[ERROR] Controlled decommission plan requires RunId, TargetId, and TargetType.' -ForegroundColor Red
        [System.Environment]::Exit(1)
    }

    $optionalPlanValues = @{}
    foreach ($propertyName in @(
        'DisplayName',
        'ProtectedObject',
        'MicrosoftFirstParty',
        'EmergencyAccessIndicator',
        'BreakGlassIndicator',
        'HighConfidenceActive',
        'Ambiguous'
    )) {
        $property = $controlledPlanInput.PSObject.Properties[$propertyName]
        $optionalPlanValues[$propertyName] = if ($null -ne $property) { $property.Value } else { $null }
    }

    $controlledTarget = [PSCustomObject]@{
        ObjectId                 = [string]$controlledPlanInput.TargetId
        ObjectType               = [string]$controlledPlanInput.TargetType
        DisplayName              = if ($optionalPlanValues.DisplayName) { [string]$optionalPlanValues.DisplayName } else { [string]$controlledPlanInput.TargetId }
        ProtectedObject          = [bool]$optionalPlanValues.ProtectedObject
        MicrosoftFirstParty      = [bool]$optionalPlanValues.MicrosoftFirstParty
        EmergencyAccessIndicator = [bool]$optionalPlanValues.EmergencyAccessIndicator
        BreakGlassIndicator      = [bool]$optionalPlanValues.BreakGlassIndicator
        HighConfidenceActive     = [bool]$optionalPlanValues.HighConfidenceActive
        Ambiguous                = [bool]$optionalPlanValues.Ambiguous
    }
    $controlledTargetValidation = Test-NhiControlledTarget -Target $controlledTarget
    if (-not $controlledTargetValidation.Passed) {
        Write-Host "[SECURITY STOP] Target validation failed: $($controlledTargetValidation.Reasons -join '; ')" -ForegroundColor Red
        [System.Environment]::Exit(1)
    }

    $controlledApprovalValidation = Confirm-NhiControlledApproval -Approval $controlledApproval -RunId ([string]$controlledPlanInput.RunId) -TargetId ([string]$controlledPlanInput.TargetId) -ActionType $controlledFeatureStage -ExpectedSchemaVersion $expectedControlledSchemaVersion -AllowFinalDeleteSimulation ($allowFinalDeletePresent -and ($whatIfExecutionPresent -or $demoModePresent))
    if (-not $controlledApprovalValidation.Passed) {
        Write-Host "[SECURITY STOP] Approval validation failed: $($controlledApprovalValidation.Reasons -join '; ')" -ForegroundColor Red
        [System.Environment]::Exit(1)
    }

    $controlledOutputPath = Join-Path $OutputPath "controlled-decommission-$($controlledPlanInput.RunId)"
    New-Item -ItemType Directory -Path $controlledOutputPath -Force | Out-Null
    $controlledSnapshot = ConvertTo-NhiControlledSnapshot -Target $controlledTarget -RunId ([string]$controlledPlanInput.RunId)
    $screamTestEvidenceProperty = $controlledPlanInput.PSObject.Properties['ScreamTestEvidence']
    $screamTestEvidence = if ($null -ne $screamTestEvidenceProperty) { $screamTestEvidenceProperty.Value } else { $null }
    $dependencyProperty = if ($null -ne $screamTestEvidence) { $screamTestEvidence.PSObject.Properties['DependencyDetected'] } else { $null }
    $recentActivityProperty = if ($null -ne $screamTestEvidence) { $screamTestEvidence.PSObject.Properties['RecentActivityDetected'] } else { $null }
    $querySucceededProperty = if ($null -ne $screamTestEvidence) { $screamTestEvidence.PSObject.Properties['QuerySucceeded'] } else { $null }
    $dependencyDetected = if ($null -ne $dependencyProperty) { [bool]$dependencyProperty.Value } else { $false }
    $recentActivityDetected = if ($null -ne $recentActivityProperty) { [bool]$recentActivityProperty.Value } else { $false }
    $querySucceeded = if ($null -ne $querySucceededProperty) { [bool]$querySucceededProperty.Value } else { $false }
    $startedUtc = [DateTime]::UtcNow.AddHours(-1 * ($ScreamTestWindowHours + 1))
    $controlledScreamTest = Get-NhiControlledScreamTestStatus -StartedUtc $startedUtc -WindowHours $ScreamTestWindowHours -DependencyDetected $dependencyDetected -RecentActivityDetected $recentActivityDetected -QuerySucceeded $querySucceeded
    $controlledRecentActivity = @()
    if ($recentActivityDetected) {
        $controlledRecentActivity = @([PSCustomObject]@{ Id = 'plan-recent-activity' })
    }
    $controlledDependencies = Test-NhiControlledDependencies -Dependencies @() -RecentActivity $controlledRecentActivity -QuerySucceeded $querySucceeded
    $controlledReadiness = Get-NhiControlledDeleteReadiness -TargetValidation $controlledTargetValidation -ApprovalValidation $controlledApprovalValidation -Snapshot $controlledSnapshot -ScreamTest $controlledScreamTest -DependencyCheck $controlledDependencies
    $controlledRollback = New-NhiControlledRollbackPlan -Snapshot $controlledSnapshot -RunId ([string]$controlledPlanInput.RunId)
    $controlledPlan = New-NhiControlledDecommissionPlan -Target $controlledTarget -ExecutionStage $ExecutionStage -RunId ([string]$controlledPlanInput.RunId) -WhatIf $true -DemoMode $demoModePresent
    $controlledModule = Get-Module NhiControlledDecommission

    if ($ExecuteNhiControlledMetadataCleanup -or $controlledFeatureStage -eq 'MetadataCleanupReadiness') {
        $metadataExecutionStage = 'MetadataCleanupReadiness'
        $metadataCleanupReadiness = if ($null -ne $controlledPlanInput.CleanupReadiness) { [PSCustomObject]@{ Status = [string]$controlledPlanInput.CleanupReadiness.Status } } else { [PSCustomObject]@{ Status = 'Blocked' } }
        $metadataInventory = & $controlledModule {
            param($Plan, $Approval, $Snapshot, $CleanupReadiness)
            New-NhiControlledMetadataInventory -Plan $Plan -Approval $Approval -Snapshot $Snapshot -CleanupReadiness $CleanupReadiness -Credentials @($Plan.CredentialMetadataEvidence)
        } $controlledPlanInput $controlledApproval $controlledSnapshot $metadataCleanupReadiness
        $metadataReadiness = & $controlledModule {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = $metadataExecutionStage
            Plan = $controlledPlanInput
            Approval = $controlledApproval
            TargetValidation = $controlledTargetValidation
            Snapshot = $controlledSnapshot
            CleanupReadiness = $metadataCleanupReadiness
            WhatIf = $whatIfExecutionPresent
            DemoMode = $demoModePresent
        }
        $metadataCleanupPlan = & $controlledModule {
            param($Plan, $Inventory, $Readiness)
            New-NhiControlledMetadataCleanupPlan -Plan $Plan -Inventory $Inventory -Readiness $Readiness
        } $controlledPlanInput $metadataInventory $metadataReadiness
        $metadataActionLog = & $controlledModule {
            param($Plan, $Inventory, $Readiness)
            New-NhiControlledMetadataCleanupActionLog -Plan $Plan -Inventory $Inventory -Readiness $Readiness
        } $controlledPlanInput $metadataInventory $metadataReadiness
        $controlledEvidencePaths = @(
            Export-NhiControlledDecommissionEvidence -Evidence $metadataInventory -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-inventory.json')
            Export-NhiControlledDecommissionEvidence -Evidence $metadataCleanupPlan -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-cleanup-plan.json')
            Export-NhiControlledDecommissionEvidence -Evidence $metadataActionLog -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-cleanup-action-log.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-snapshot.json')
            Export-NhiControlledDecommissionEvidence -Evidence $metadataReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-metadata-cleanup-readiness.json')
        )
        Write-Host '[OK] Rev4.5 metadata cleanup readiness completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
        $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        [System.Environment]::Exit(0)
    }

    if ($ExecuteNhiControlledGrantCleanup -or $controlledFeatureStage -eq 'GrantCleanupReadiness') {
        $grantExecutionStage = 'GrantCleanupReadiness'
        $grantDependencyRecheck = if ($null -ne $controlledPlanInput.DependencyRecheck) {
            [PSCustomObject]@{
                SchemaVersion = '4.6'
                Status = [string]$controlledPlanInput.DependencyRecheck.Status
                QuerySucceeded = [bool]$controlledPlanInput.DependencyRecheck.QuerySucceeded
                Blocked = [bool]$controlledPlanInput.DependencyRecheck.Blocked
                SkippedWithApproval = [bool]$controlledPlanInput.DependencyRecheck.SkippedWithApproval
            }
        } else {
            & $controlledModule { param($Plan) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $true -Blocked $false -SkippedWithApproval $false } $controlledPlanInput
        }
        $grantReadiness = & $controlledModule {
            param($GateInput)
            Test-NhiControlledGrantCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = $grantExecutionStage
            Plan = $controlledPlanInput
            Approval = $controlledApproval
            TargetValidation = $controlledTargetValidation
            Snapshot = $controlledSnapshot
            DependencyRecheck = $grantDependencyRecheck
            WhatIf = $whatIfExecutionPresent
            DemoMode = $demoModePresent
        }
        $grantCleanupPlan = & $controlledModule {
            param($Plan, $DependencyRecheck, $Readiness)
            New-NhiControlledGrantCleanupPlan -Plan $Plan -DependencyRecheck $DependencyRecheck -Readiness $Readiness
        } $controlledPlanInput $grantDependencyRecheck $grantReadiness
        $grantActionLog = & $controlledModule {
            param($Plan, $DependencyRecheck, $Readiness)
            New-NhiControlledGrantCleanupActionLog -Plan $Plan -DependencyRecheck $DependencyRecheck -Readiness $Readiness
        } $controlledPlanInput $grantDependencyRecheck $grantReadiness
        $grantPostCleanupValidation = [PSCustomObject]@{
            SchemaVersion = '4.6'
            RunId = [string]$controlledPlanInput.RunId
            TargetObjectId = [string]$controlledPlanInput.TargetObjectId
            RelatedObjectId = [string]$controlledPlanInput.RelatedObjectId
            Status = if ($whatIfExecutionPresent -or $demoModePresent) { 'Simulated' } else { 'NotRun' }
            Outcome = 'EvidenceOnly'
        }
        $controlledEvidencePaths = @(
            Export-NhiControlledDecommissionEvidence -Evidence $grantCleanupPlan -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-cleanup-plan.json')
            Export-NhiControlledDecommissionEvidence -Evidence $grantDependencyRecheck -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-dependency-recheck.json')
            Export-NhiControlledDecommissionEvidence -Evidence $grantActionLog -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-cleanup-action-log.json')
            Export-NhiControlledDecommissionEvidence -Evidence $grantPostCleanupValidation -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-post-cleanup-validation.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-snapshot.json')
            Export-NhiControlledDecommissionEvidence -Evidence $grantReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-grants-cleanup-readiness.json')
        )
        Write-Host '[OK] Rev4.6 grants cleanup readiness completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
        $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        [System.Environment]::Exit(0)
    }

    if ($controlledFeatureStage -eq 'ManagedIdentityReadiness') {
        $managedIdentityExecutionStage = 'ManagedIdentityReadiness'
        $managedIdentityDeleteReadiness = if ($null -ne $controlledPlanInput.DeleteReadiness) { [PSCustomObject]@{ Status = [string]$controlledPlanInput.DeleteReadiness.Status } } else { [PSCustomObject]@{ Status = 'Blocked' } }
        $managedIdentityDependencyRecheck = if ($null -ne $controlledPlanInput.DependencyRecheck) {
            [PSCustomObject]@{
                SchemaVersion = '4.7'
                Status = [string]$controlledPlanInput.DependencyRecheck.Status
                QuerySucceeded = [bool]$controlledPlanInput.DependencyRecheck.QuerySucceeded
                Blocked = [bool]$controlledPlanInput.DependencyRecheck.Blocked
                SkippedWithApproval = [bool]$controlledPlanInput.DependencyRecheck.SkippedWithApproval
            }
        } else {
            [PSCustomObject]@{
                SchemaVersion = '4.7'
                Status = 'Clean'
                QuerySucceeded = $true
                Blocked = $false
                SkippedWithApproval = $false
            }
        }
        $managedIdentityRoleAssignmentEvidence = if ($null -ne $controlledPlanInput.RoleAssignmentEvidence) { $controlledPlanInput.RoleAssignmentEvidence } else { [PSCustomObject]@{ ActiveRoleAssignmentCount = 0 } }
        $managedIdentityFederatedCredentialEvidence = if ($null -ne $controlledPlanInput.FederatedCredentialEvidence) { $controlledPlanInput.FederatedCredentialEvidence } else { [PSCustomObject]@{ ActiveDependencyCount = 0; AppRelationshipDependencyCount = 0 } }
        $managedIdentityParentEvidence = $controlledPlanInput.ParentResourceEvidence
        $managedIdentityAttachmentEvidence = $controlledPlanInput.AttachmentEvidence
        if ($controlledPlanInput.ManagedIdentityType -eq 'SystemAssigned' -and $null -eq $managedIdentityParentEvidence) {
            Write-Host '[SECURITY STOP] SystemAssigned managed identity requires ParentResourceEvidence. ManagedIdentityReadiness is blocked.' -ForegroundColor Red
            [System.Environment]::Exit(1)
        }
        if ($controlledPlanInput.ManagedIdentityType -eq 'UserAssigned' -and $null -eq $managedIdentityAttachmentEvidence) {
            Write-Host '[SECURITY STOP] UserAssigned managed identity requires AttachmentEvidence. ManagedIdentityReadiness is blocked.' -ForegroundColor Red
            [System.Environment]::Exit(1)
        }
        $managedIdentityReadiness = & $controlledModule {
            param($GateInput)
            Test-NhiControlledManagedIdentityReadinessGate @GateInput
        } @{
            ExecutionStage = $managedIdentityExecutionStage
            Plan = $controlledPlanInput
            Approval = $controlledApproval
            TargetValidation = $controlledTargetValidation
            Snapshot = $controlledSnapshot
            DeleteReadiness = $managedIdentityDeleteReadiness
            DependencyRecheck = $managedIdentityDependencyRecheck
            RoleAssignmentEvidence = $managedIdentityRoleAssignmentEvidence
            FederatedCredentialEvidence = $managedIdentityFederatedCredentialEvidence
            ParentResourceEvidence = $managedIdentityParentEvidence
            AttachmentEvidence = $managedIdentityAttachmentEvidence
            WhatIf = $whatIfExecutionPresent
            DemoMode = $demoModePresent
        }
        $managedIdentityPlan = & $controlledModule {
            param($Plan, $Readiness, $Snapshot, $RoleAssignmentEvidence, $FederatedCredentialEvidence, $ParentResourceEvidence, $AttachmentEvidence)
            New-NhiControlledManagedIdentityReadinessPlan -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot -RoleAssignmentEvidence $RoleAssignmentEvidence -FederatedCredentialEvidence $FederatedCredentialEvidence -ParentResourceEvidence $ParentResourceEvidence -AttachmentEvidence $AttachmentEvidence
        } $controlledPlanInput $managedIdentityReadiness $controlledSnapshot $managedIdentityRoleAssignmentEvidence $managedIdentityFederatedCredentialEvidence $managedIdentityParentEvidence $managedIdentityAttachmentEvidence
        $managedIdentityActionLog = & $controlledModule {
            param($Plan, $Readiness, $Snapshot)
            New-NhiControlledManagedIdentityActionLog -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot
        } $controlledPlanInput $managedIdentityReadiness $controlledSnapshot
        $controlledEvidencePaths = @(
            Export-NhiControlledDecommissionEvidence -Evidence $managedIdentityPlan -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-plan.json')
            Export-NhiControlledDecommissionEvidence -Evidence $managedIdentityActionLog -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-action-log.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-snapshot.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledScreamTest -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-screamtest.json')
            Export-NhiControlledDecommissionEvidence -Evidence $managedIdentityReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-managed-identity-readiness.json')
        )
        Write-Host '[OK] Rev4.7 managed identity readiness completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
        $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        [System.Environment]::Exit(0)
    }

    if ($controlledFeatureStage -eq 'E2EEvidencePack') {
        $e2eManagedIdentityReadiness = if ($null -ne $controlledPlanInput.ManagedIdentityReadiness) { $controlledPlanInput.ManagedIdentityReadiness } else { [PSCustomObject]@{ Status = 'SimulationOnly' } }
        $e2eMetadataReadiness = if ($null -ne $controlledPlanInput.MetadataReadiness) { $controlledPlanInput.MetadataReadiness } else { [PSCustomObject]@{ Status = 'Simulated' } }
        $e2eGrantReadiness = if ($null -ne $controlledPlanInput.GrantReadiness) { $controlledPlanInput.GrantReadiness } else { [PSCustomObject]@{ Status = 'Simulated' } }
        $e2eDecision = if ($null -ne $controlledPlanInput.OperatorDecision) { $controlledPlanInput.OperatorDecision } else { [PSCustomObject]@{ Decision = 'SimulationOnly'; DecisionBy = 'local-planner'; Reason = 'No live tenant execution is allowed.'; Scope = 'Rev4.8'; IsSimulationOnly = $true } }
        $e2eKnownWarnings = if ($null -ne $controlledPlanInput.KnownWarnings) { @($controlledPlanInput.KnownWarnings) } else { @('DemoMode traceability warning may still appear in legacy assessment paths.') }
        $e2ePack = & $controlledModule {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $controlledPlanInput $controlledApproval $controlledSnapshot $controlledScreamTest $controlledDependencies $controlledReadiness $e2eMetadataReadiness $e2eGrantReadiness $e2eManagedIdentityReadiness $e2eDecision $e2eKnownWarnings
        $qaHandoffManifest = $e2ePack.QAHandoffManifest
        $operatorDecisionLog = & $controlledModule {
            param($Plan, $Decision)
            New-NhiControlledOperatorDecisionLog -Plan $Plan -Decision $Decision.Decision -DecisionBy $Decision.DecisionBy -Reason $Decision.Reason -Scope $Decision.Scope
        } $controlledPlanInput $e2eDecision
        $controlledEvidencePaths = @(
            Export-NhiControlledDecommissionEvidence -Evidence $e2ePack -Path (Join-Path $controlledOutputPath 'nhi-controlled-e2e-evidence-pack.json')
            Export-NhiControlledDecommissionEvidence -Evidence $qaHandoffManifest -Path (Join-Path $controlledOutputPath 'nhi-controlled-qa-handoff-manifest.json')
            Export-NhiControlledDecommissionEvidence -Evidence $operatorDecisionLog -Path (Join-Path $controlledOutputPath 'nhi-controlled-operator-decision-log.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-e2e-snapshot.json')
            Export-NhiControlledDecommissionEvidence -Evidence $controlledReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-e2e-readiness.json')
        )
        Write-Host '[OK] Rev4.8 controlled decommission evidence pack completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
        $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        [System.Environment]::Exit(0)
    }

    if ($controlledFeatureStage -eq 'ProductionReadiness') {
        $productionReadinessInput = [PSCustomObject]@{
            RunId = [string]$controlledPlanInput.RunId
            BranchName = if ($controlledPlanInput.PSObject.Properties['BranchName']) { [string]$controlledPlanInput.BranchName } else { 'feature/rev42-controlled-nhi-decommission' }
            LatestCommit = if ($controlledPlanInput.PSObject.Properties['LatestCommit']) { [string]$controlledPlanInput.LatestCommit } else { 'dc1a214' }
            GitStatusClean = if ($controlledPlanInput.PSObject.Properties['GitStatusClean']) { [bool]$controlledPlanInput.GitStatusClean } else { $true }
            FrozenFileDiffClean = if ($controlledPlanInput.PSObject.Properties['FrozenFileDiffClean']) { [bool]$controlledPlanInput.FrozenFileDiffClean } else { $true }
            Rev42PlannerEvidence = if ($controlledPlanInput.PSObject.Properties['Rev42PlannerEvidence']) { $controlledPlanInput.Rev42PlannerEvidence } else { $null }
            Rev43ServicePrincipalFinalDeleteSimulationEvidence = if ($controlledPlanInput.PSObject.Properties['Rev43ServicePrincipalFinalDeleteSimulationEvidence']) { $controlledPlanInput.Rev43ServicePrincipalFinalDeleteSimulationEvidence } else { $null }
            Rev44ApplicationReadinessEvidence = if ($controlledPlanInput.PSObject.Properties['Rev44ApplicationReadinessEvidence']) { $controlledPlanInput.Rev44ApplicationReadinessEvidence } else { $null }
            Rev45MetadataCleanupReadinessEvidence = if ($controlledPlanInput.PSObject.Properties['Rev45MetadataCleanupReadinessEvidence']) { $controlledPlanInput.Rev45MetadataCleanupReadinessEvidence } else { $null }
            Rev46GrantsCleanupReadinessEvidence = if ($controlledPlanInput.PSObject.Properties['Rev46GrantsCleanupReadinessEvidence']) { $controlledPlanInput.Rev46GrantsCleanupReadinessEvidence } else { $null }
            Rev47ManagedIdentityReadinessEvidence = if ($controlledPlanInput.PSObject.Properties['Rev47ManagedIdentityReadinessEvidence']) { $controlledPlanInput.Rev47ManagedIdentityReadinessEvidence } else { $null }
            Rev48E2EEvidencePackEvidence = if ($controlledPlanInput.PSObject.Properties['Rev48E2EEvidencePackEvidence']) { $controlledPlanInput.Rev48E2EEvidencePackEvidence } else { $null }
            ExternalQaApprovalEvidence = if ($controlledPlanInput.PSObject.Properties['ExternalQaApprovalEvidence']) { $controlledPlanInput.ExternalQaApprovalEvidence } else { $null }
            FullPesterEvidence = if ($controlledPlanInput.PSObject.Properties['FullPesterEvidence']) { $controlledPlanInput.FullPesterEvidence } else { $null }
            SafetyScanEvidence = if ($controlledPlanInput.PSObject.Properties['SafetyScanEvidence']) { $controlledPlanInput.SafetyScanEvidence } else { $null }
            FrozenFileDiffEvidence = if ($controlledPlanInput.PSObject.Properties['FrozenFileDiffEvidence']) { $controlledPlanInput.FrozenFileDiffEvidence } else { $null }
            GitStatusEvidence = if ($controlledPlanInput.PSObject.Properties['GitStatusEvidence']) { $controlledPlanInput.GitStatusEvidence } else { $null }
            P0Findings = if ($controlledPlanInput.PSObject.Properties['P0Findings']) { @($controlledPlanInput.P0Findings) } else { @() }
            P1Findings = if ($controlledPlanInput.PSObject.Properties['P1Findings']) { @($controlledPlanInput.P1Findings) } else { @() }
            P2Findings = if ($controlledPlanInput.PSObject.Properties['P2Findings']) { @($controlledPlanInput.P2Findings) } else { @() }
            KnownWarnings = if ($controlledPlanInput.PSObject.Properties['KnownWarnings']) { @($controlledPlanInput.KnownWarnings) } else { @() }
            OperatorMergeDecision = if ($controlledPlanInput.PSObject.Properties['OperatorMergeDecision']) { $controlledPlanInput.OperatorMergeDecision } else { $null }
        }
        $missingProductionReadinessEvidence = @()
        foreach ($evidenceName in @(
            'Rev42PlannerEvidence',
            'Rev43ServicePrincipalFinalDeleteSimulationEvidence',
            'Rev44ApplicationReadinessEvidence',
            'Rev45MetadataCleanupReadinessEvidence',
            'Rev46GrantsCleanupReadinessEvidence',
            'Rev47ManagedIdentityReadinessEvidence',
            'Rev48E2EEvidencePackEvidence',
            'ExternalQaApprovalEvidence',
            'FullPesterEvidence',
            'SafetyScanEvidence',
            'FrozenFileDiffEvidence',
            'GitStatusEvidence'
        )) {
            if ($null -eq $productionReadinessInput.PSObject.Properties[$evidenceName] -or $null -eq $productionReadinessInput.$evidenceName) {
                $missingProductionReadinessEvidence += $evidenceName
            }
        }
        if ($missingProductionReadinessEvidence.Count -gt 0) {
            Write-Host "[SECURITY STOP] Rev4.9 production readiness plan is missing required evidence: $($missingProductionReadinessEvidence -join ', ')." -ForegroundColor Red
            [System.Environment]::Exit(1)
        }
        $productionPack = & $controlledModule {
            param($Payload)
            New-NhiControlledProductionReadinessEvidencePack -Input $Payload
        } $productionReadinessInput
        $controlledEvidencePaths = @(
            Export-NhiControlledDecommissionEvidence -Evidence $productionPack.ProductionReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-production-readiness.json')
            Export-NhiControlledDecommissionEvidence -Evidence $productionPack.ReleaseManifest -Path (Join-Path $controlledOutputPath 'nhi-controlled-release-manifest.json')
            Export-NhiControlledDecommissionEvidence -Evidence $productionPack.MergeGate -Path (Join-Path $controlledOutputPath 'nhi-controlled-merge-gate.json')
            Export-NhiControlledDecommissionEvidence -Evidence $productionPack.KnownWarnings -Path (Join-Path $controlledOutputPath 'nhi-controlled-known-warnings.json')
            Export-NhiControlledDecommissionEvidence -Evidence $productionPack.FinalSafetyAssertions -Path (Join-Path $controlledOutputPath 'nhi-controlled-final-safety-assertions.json')
        )
        Export-NhiControlledDecommissionEvidence -Evidence $productionPack.OperatorMergeDecision -Path (Join-Path $controlledOutputPath 'nhi-controlled-operator-merge-decision.json') | Out-Null
        if ($productionPack.ProductionReadyForReview) {
            Write-Host '[OK] Rev4.9 production readiness guardrails completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
        } else {
            Write-Host '[WARN] Rev4.9 production readiness gate is blocked. No Graph connection or tenant mutation performed.' -ForegroundColor Yellow
        }
        $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
        Write-Host "  $(Join-Path $controlledOutputPath 'nhi-controlled-operator-merge-decision.json')" -ForegroundColor Gray
        [System.Environment]::Exit(0)
    }

    $controlledFifthEvidence = $controlledRollback
    $controlledFifthEvidenceName = 'nhi-controlled-decommission-rollback-plan.json'
    if ($ExecutionStage -eq 'FinalDelete') {
        $overrideProperty = $controlledApproval.PSObject.Properties['ScreamTestOverrideApproved']
        $screamTestOverrideApproved = if ($null -ne $overrideProperty) { [bool]$overrideProperty.Value } else { $false }
        $controlledFinalDeleteGateInput = @{
            ExecutionStage = $ExecutionStage
            AllowFinalDelete = $allowFinalDeletePresent
            Plan = $controlledPlanInput
            TargetValidation = $controlledTargetValidation
            ApprovalValidation = $controlledApprovalValidation
            Snapshot = $controlledSnapshot
            DeleteReadiness = $controlledReadiness
            ScreamTest = $controlledScreamTest
            DependencyCheck = $controlledDependencies
            ScreamTestOverrideApproved = $screamTestOverrideApproved
            WhatIf = $whatIfExecutionPresent
            DemoMode = $demoModePresent
        }
        $controlledModule = Get-Module NhiControlledDecommission
        if ([string]$controlledPlanInput.TargetType -eq 'Application') {
            $activeCredentialOverrideProperty = $controlledApproval.PSObject.Properties['ActiveCredentialOverrideApproved']
            $activeCredentialOverrideApproved = if ($null -ne $activeCredentialOverrideProperty) { [bool]$activeCredentialOverrideProperty.Value } else { $false }
            $controlledFinalDeleteGateInput['ActiveCredentialOverrideApproved'] = $activeCredentialOverrideApproved
            $controlledFinalDeleteGate = & $controlledModule {
                param($GateInput)
                Test-NhiControlledApplicationDeleteReadinessGate @GateInput
            } $controlledFinalDeleteGateInput
            $controlledFifthEvidenceName = 'nhi-controlled-decommission-finaldelete-application-readiness.json'
            Write-Host "[SECURITY STOP] Rev4.4 Application FinalDelete readiness status: $($controlledFinalDeleteGate.Status). Live delete is unavailable." -ForegroundColor Yellow
        } else {
            $controlledFinalDeleteGate = & $controlledModule {
                param($GateInput)
                Test-NhiControlledServicePrincipalFinalDeleteGate @GateInput
            } $controlledFinalDeleteGateInput
            $controlledFifthEvidenceName = 'nhi-controlled-decommission-finaldelete-sp-guard.json'
            Write-Host "[SECURITY STOP] Rev4.3 FinalDelete simulation status: $($controlledFinalDeleteGate.Status). Live delete is unavailable." -ForegroundColor Yellow
        }
        $controlledFifthEvidence = $controlledFinalDeleteGate
    }

    $controlledEvidencePaths = @(
        Export-NhiControlledDecommissionEvidence -Evidence $controlledPlan -Path (Join-Path $controlledOutputPath 'nhi-controlled-decommission-plan.json')
        Export-NhiControlledDecommissionEvidence -Evidence $controlledSnapshot -Path (Join-Path $controlledOutputPath 'nhi-controlled-decommission-snapshot.json')
        Export-NhiControlledDecommissionEvidence -Evidence $controlledScreamTest -Path (Join-Path $controlledOutputPath 'nhi-controlled-decommission-screamtest.json')
        Export-NhiControlledDecommissionEvidence -Evidence $controlledReadiness -Path (Join-Path $controlledOutputPath 'nhi-controlled-decommission-delete-readiness.json')
        Export-NhiControlledDecommissionEvidence -Evidence $controlledFifthEvidence -Path (Join-Path $controlledOutputPath $controlledFifthEvidenceName)
    )
    Write-Host '[OK] Rev4.2-S1 controlled decommission planner/evidence completed. No Graph connection or tenant mutation performed.' -ForegroundColor Green
    $controlledEvidencePaths | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    # [TRACE] Confirm companion reaches [System.Environment]::Exit(0)
    Write-Host '[TRACE] Controlled companion reached final [System.Environment]::Exit(0).' -ForegroundColor Cyan
    [System.Environment]::Exit(0)
}
