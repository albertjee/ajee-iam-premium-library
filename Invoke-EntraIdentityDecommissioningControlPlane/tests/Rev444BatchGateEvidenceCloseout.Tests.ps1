param()

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:ToolPath = Join-Path $script:RepoRoot 'tools\Start-NhiBatchGateEvidenceCloseout.ps1'

function New-TestJsonFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][object]$Object
    )

    $dir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $Object | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-Rev444Fixture {
    param(
        [Parameter(Mandatory = $true)][string]$BasePath,
        [Parameter(Mandatory = $true)][string]$TenantId,
        [Parameter(Mandatory = $true)][string]$BatchId,
        [switch]$EvidenceOnly,
        [switch]$LiveMutation,
        [switch]$MissingPriorState,
        [switch]$FailSafetyGate
    )

    $planningRoot = Join-Path $BasePath 'planning'
    $disableRoot = Join-Path $BasePath 'disable'
    $rollbackRoot = Join-Path $BasePath 'rollback'
    $outputRoot = Join-Path $BasePath 'out'

    $planningTargets = @(
        [pscustomobject]@{
            TenantId               = $TenantId
            BatchId                = $BatchId
            ServicePrincipalObjectId = 'sp-001'
            AppId                  = 'app-001'
            DisplayName            = 'Alpha'
            ObjectType             = 'ServicePrincipal'
            TargetType             = 'Application'
            ValidationStatus       = 'Validated'
            MutationEligible       = (-not $EvidenceOnly.IsPresent)
            EvidenceOnly           = $EvidenceOnly.IsPresent
            Disposition            = if ($EvidenceOnly.IsPresent) { 'EvidenceOnly' } else { 'EligibleGateOnly' }
        }
    )

    New-TestJsonFile -Path (Join-Path $planningRoot 'rev441-batch-lifecycle-planning-summary.json') -Object ([pscustomobject]@{
        TenantId          = $TenantId
        BatchId           = $BatchId
        TargetCount       = $planningTargets.Count
        ApprovedAction    = 'ReversibleDisable'
        Mode              = 'WhatIf'
        ValidationStatus  = 'Ready'
        WhatIf            = $true
        FinalDeleteApproved = $false
        CleanupApproved    = $false
        LiveMutationPerformed = $false
        SafetyGatePassed   = (-not $FailSafetyGate.IsPresent)
    })

    New-TestJsonFile -Path (Join-Path $planningRoot 'rev441-batch-lifecycle-planning-targets.json') -Object $planningTargets
    New-TestJsonFile -Path (Join-Path $planningRoot 'rev441-batch-lifecycle-planning-readiness.json') -Object ([pscustomobject]@{
        TenantId          = $TenantId
        BatchId           = $BatchId
        ReadinessStatus    = 'Ready'
        WhatIf             = $true
        ValidationState    = 'Approved'
    })

    $disableTargets = @(
        [pscustomobject]@{
            TenantId                  = $TenantId
            BatchId                   = $BatchId
            ServicePrincipalObjectId   = if ($LiveMutation.IsPresent) { 'sp-bad' } else { 'sp-001' }
            AppId                     = if ($LiveMutation.IsPresent) { 'app-bad' } else { 'app-001' }
            DisplayName               = 'Alpha'
            ValidationStatus          = 'Validated'
            ExecutionStatus           = 'GateOnly'
            ExecutionNotPerformed      = $true
            ChildCallCount            = 0
            LiveMutationPerformed     = $false
            ApprovalManifestPath      = 'disable/approval.json'
            PreSnapshotPath           = 'disable/pre-snapshot.json'
            RollbackPackagePath       = 'disable/rollback-package.json'
            ChangedObjectManifestPath = 'disable/changed.json'
            MutationEligible          = (-not $EvidenceOnly.IsPresent)
            EvidenceOnly              = $EvidenceOnly.IsPresent
            Disposition               = if ($EvidenceOnly.IsPresent) { 'EvidenceOnly' } else { 'EligibleGateOnly' }
            ChangedByPriorBatchRun    = $false
        }
    )

    if ($LiveMutation.IsPresent) {
        $disableTargets[0].ChildCallCount = 1
        $disableTargets[0].LiveMutationPerformed = $true
        $disableTargets[0].ExecutionNotPerformed = $false
        $disableTargets[0].ExecutionStatus = 'Success'
    }

    New-TestJsonFile -Path (Join-Path $disableRoot 'rev442-batch-reversible-disable-summary.json') -Object ([pscustomobject]@{
        TenantId                  = $TenantId
        BatchId                   = $BatchId
        ApprovedAction            = 'ReversibleDisable'
        Mode                      = 'Execute'
        TargetCount               = $disableTargets.Count
        EligibleTargetCount       = if ($EvidenceOnly.IsPresent) { 0 } else { 1 }
        BlockedTargetCount        = if ($EvidenceOnly.IsPresent) { 1 } else { 0 }
        ExecutionStatus           = if ($LiveMutation.IsPresent) { 'Success' } else { 'GateOnly' }
        ExecutionNotPerformed     = (-not $LiveMutation.IsPresent)
        ChildCallCount            = if ($LiveMutation.IsPresent) { 1 } else { 0 }
        LiveMutationPerformed     = $LiveMutation.IsPresent
        ApprovalManifestPath      = 'disable/approval.json'
        PreSnapshotPath           = 'disable/pre-snapshot.json'
        RollbackPackagePath       = 'disable/rollback-package.json'
        ChangedObjectManifestPath = 'disable/changed.json'
        ChangedByPriorBatchRun    = $false
        PriorAccountStateCaptured = $true
        FinalDeleteApproved       = $false
        CleanupApproved           = $false
        SafetyGatePassed          = (-not $FailSafetyGate.IsPresent)
    })
    New-TestJsonFile -Path (Join-Path $disableRoot 'rev442-batch-reversible-disable-targets.json') -Object $disableTargets

    $rollbackTargets = @(
        [pscustomobject]@{
            TenantId                = $TenantId
            BatchId                 = $BatchId
            ServicePrincipalObjectId = if ($LiveMutation.IsPresent) { 'sp-bad' } else { 'sp-001' }
            AppId                   = if ($LiveMutation.IsPresent) { 'app-bad' } else { 'app-001' }
            DisplayName             = 'Alpha'
            ValidationStatus        = 'Validated'
            ExecutionStatus         = 'GateOnly'
            ExecutionNotPerformed   = $true
            ChildCallCount          = 0
            LiveMutationPerformed   = $false
            PriorEnabledState        = if ($MissingPriorState.IsPresent) { $null } else { $false }
            RollbackAction          = 'NoOp'
            Disposition             = if ($EvidenceOnly.IsPresent) { 'EvidenceOnly' } else { 'EligibleGateOnly' }
        }
    )

    New-TestJsonFile -Path (Join-Path $rollbackRoot 'rev443-batch-rollback-summary.json') -Object ([pscustomobject]@{
        TenantId                  = $TenantId
        BatchId                   = $BatchId
        ExecutionStatus           = 'GateOnly'
        ExecutionNotPerformed     = $true
        ChildCallCount            = 0
        LiveMutationPerformed     = $false
        PriorAccountStateCaptured = (-not $MissingPriorState.IsPresent)
    })
    New-TestJsonFile -Path (Join-Path $rollbackRoot 'rev443-batch-rollback-targets.json') -Object $rollbackTargets
    New-TestJsonFile -Path (Join-Path $rollbackRoot 'rev443-roll-back-package.json') -Object ([pscustomobject]@{
        TenantId = $TenantId
        BatchId  = $BatchId
        Targets  = $rollbackTargets
    })

    return [pscustomobject]@{
        PlanningRoot   = $planningRoot
        DisableRoot    = $disableRoot
        RollbackRoot   = $rollbackRoot
        OutputRoot     = $outputRoot
        ExpectedTarget = $planningTargets[0]
    }
}

Describe 'Rev4.44 Batch Gate Evidence Closeout' {
    BeforeAll {
        $script:RepoRoot = Split-Path -Parent $PSScriptRoot
        $script:ToolPath = Join-Path $script:RepoRoot 'tools\Start-NhiBatchGateEvidenceCloseout.ps1'

        function New-TestJsonFile {
            param(
                [Parameter(Mandatory = $true)][string]$Path,
                [Parameter(Mandatory = $true)][object]$Object
            )

            $dir = Split-Path -Parent $Path
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $Object | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding UTF8
        }

        function New-Rev444Fixture {
            param(
                [Parameter(Mandatory = $true)][string]$BasePath,
                [Parameter(Mandatory = $true)][string]$TenantId,
                [Parameter(Mandatory = $true)][string]$BatchId,
                [switch]$EvidenceOnly,
                [switch]$LiveMutation,
                [switch]$MissingPriorState,
                [switch]$FailSafetyGate
            )

            $planningRoot = Join-Path $BasePath 'planning'
            $disableRoot = Join-Path $BasePath 'disable'
            $rollbackRoot = Join-Path $BasePath 'rollback'
            $outputRoot = Join-Path $BasePath 'out'

            $planningTargets = @(
                [pscustomobject]@{
                    TenantId                 = $TenantId
                    BatchId                  = $BatchId
                    ServicePrincipalObjectId = 'sp-001'
                    AppId                    = 'app-001'
                    DisplayName              = 'Alpha'
                    ObjectType               = 'ServicePrincipal'
                    TargetType               = 'Application'
                    ValidationStatus         = 'Validated'
                    MutationEligible         = (-not $EvidenceOnly.IsPresent)
                    EvidenceOnly             = $EvidenceOnly.IsPresent
                    Disposition              = if ($EvidenceOnly.IsPresent) { 'EvidenceOnly' } else { 'EligibleGateOnly' }
                }
            )

            New-TestJsonFile -Path (Join-Path $planningRoot 'rev441-batch-lifecycle-planning-summary.json') -Object ([pscustomobject]@{
                TenantId               = $TenantId
                BatchId                = $BatchId
                TargetCount            = $planningTargets.Count
                ApprovedAction         = 'ReversibleDisable'
                Mode                   = 'WhatIf'
                ValidationStatus       = 'Ready'
                WhatIf                 = $true
                LiveMutationPerformed  = $false
                FinalDeleteApproved    = $false
                CleanupApproved        = $false
                SafetyGatePassed       = (-not $FailSafetyGate.IsPresent)
            })

            New-TestJsonFile -Path (Join-Path $planningRoot 'rev441-batch-lifecycle-planning-targets.json') -Object $planningTargets
            New-TestJsonFile -Path (Join-Path $planningRoot 'rev441-batch-lifecycle-planning-readiness.json') -Object ([pscustomobject]@{
                TenantId        = $TenantId
                BatchId         = $BatchId
                ReadinessStatus  = 'Ready'
                WhatIf           = $true
                ValidationState  = 'Approved'
            })

            $disableTargets = @(
                [pscustomobject]@{
                    TenantId                  = $TenantId
                    BatchId                   = $BatchId
                    ServicePrincipalObjectId   = if ($LiveMutation.IsPresent) { 'sp-bad' } else { 'sp-001' }
                    AppId                     = if ($LiveMutation.IsPresent) { 'app-bad' } else { 'app-001' }
                    DisplayName               = 'Alpha'
                    ValidationStatus          = 'Validated'
                    SafetyGatePassed          = (-not $FailSafetyGate.IsPresent)
                    ExecutionStatus           = 'GateOnly'
                    ExecutionNotPerformed     = $true
                    ChildCallCount            = 0
                    LiveMutationPerformed     = $false
                    ApprovalManifestPath      = 'disable/approval.json'
                    PreSnapshotPath           = 'disable/pre-snapshot.json'
                    RollbackPackagePath       = 'disable/rollback-package.json'
                    ChangedObjectManifestPath = 'disable/changed.json'
                    MutationEligible          = (-not $EvidenceOnly.IsPresent)
                    EvidenceOnly              = $EvidenceOnly.IsPresent
                    Disposition               = if ($EvidenceOnly.IsPresent) { 'EvidenceOnly' } else { 'EligibleGateOnly' }
                    ChangedByPriorBatchRun    = $false
                }
            )

            if ($LiveMutation.IsPresent) {
                $disableTargets[0].ChildCallCount = 1
                $disableTargets[0].LiveMutationPerformed = $true
                $disableTargets[0].ExecutionNotPerformed = $false
                $disableTargets[0].ExecutionStatus = 'Success'
            }

            New-TestJsonFile -Path (Join-Path $disableRoot 'rev442-batch-reversible-disable-summary.json') -Object ([pscustomobject]@{
                TenantId                  = $TenantId
                BatchId                   = $BatchId
                ApprovedAction            = 'ReversibleDisable'
                Mode                      = 'Execute'
                TargetCount               = $disableTargets.Count
                EligibleTargetCount       = if ($EvidenceOnly.IsPresent) { 0 } else { 1 }
                BlockedTargetCount        = if ($EvidenceOnly.IsPresent) { 1 } else { 0 }
                ExecutionStatus           = if ($LiveMutation.IsPresent) { 'Success' } else { 'GateOnly' }
                ExecutionNotPerformed     = (-not $LiveMutation.IsPresent)
                ChildCallCount            = if ($LiveMutation.IsPresent) { 1 } else { 0 }
                LiveMutationPerformed     = $LiveMutation.IsPresent
                ApprovalManifestPath      = 'disable/approval.json'
                PreSnapshotPath           = 'disable/pre-snapshot.json'
                RollbackPackagePath       = 'disable/rollback-package.json'
                ChangedObjectManifestPath = 'disable/changed.json'
                ChangedByPriorBatchRun    = $false
                PriorAccountStateCaptured = $true
                FinalDeleteApproved       = $false
                CleanupApproved           = $false
                SafetyGatePassed          = (-not $FailSafetyGate.IsPresent)
            })
            New-TestJsonFile -Path (Join-Path $disableRoot 'rev442-batch-reversible-disable-targets.json') -Object $disableTargets

            $rollbackTargets = @(
                [pscustomobject]@{
                    TenantId                = $TenantId
                    BatchId                 = $BatchId
                    ServicePrincipalObjectId = if ($LiveMutation.IsPresent) { 'sp-bad' } else { 'sp-001' }
                    AppId                   = if ($LiveMutation.IsPresent) { 'app-bad' } else { 'app-001' }
                    DisplayName             = 'Alpha'
                    ValidationStatus        = 'Validated'
                    SafetyGatePassed        = (-not $FailSafetyGate.IsPresent)
                    ExecutionStatus         = 'GateOnly'
                    ExecutionNotPerformed   = $true
                    ChildCallCount          = 0
                    LiveMutationPerformed   = $false
                    PriorEnabledState       = if ($MissingPriorState.IsPresent) { $null } else { $false }
                    RollbackAction          = 'NoOp'
                    Disposition             = if ($EvidenceOnly.IsPresent) { 'EvidenceOnly' } else { 'EligibleGateOnly' }
                }
            )

            New-TestJsonFile -Path (Join-Path $rollbackRoot 'rev443-batch-rollback-summary.json') -Object ([pscustomobject]@{
                TenantId                  = $TenantId
                BatchId                   = $BatchId
                ApprovedAction            = 'RollbackDisable'
                Mode                      = 'Execute'
                TargetCount               = $rollbackTargets.Count
                EligibleTargetCount       = if ($EvidenceOnly.IsPresent) { 0 } else { 1 }
                BlockedTargetCount        = if ($EvidenceOnly.IsPresent) { 1 } else { 0 }
                ExecutionStatus           = 'GateOnly'
                ExecutionNotPerformed     = $true
                ChildCallCount            = 0
                LiveMutationPerformed     = $false
                PriorAccountStateCaptured = (-not $MissingPriorState.IsPresent)
                FinalDeleteApproved       = $false
                CleanupApproved           = $false
                SafetyGatePassed          = (-not $FailSafetyGate.IsPresent)
            })
            New-TestJsonFile -Path (Join-Path $rollbackRoot 'rev443-batch-rollback-targets.json') -Object $rollbackTargets
            New-TestJsonFile -Path (Join-Path $rollbackRoot 'rev443-roll-back-package.json') -Object ([pscustomobject]@{
                TenantId = $TenantId
                BatchId  = $BatchId
                Targets  = $rollbackTargets
            })

            return [pscustomobject]@{
                PlanningRoot   = $planningRoot
                DisableRoot    = $disableRoot
                RollbackRoot   = $rollbackRoot
                OutputRoot     = $outputRoot
                ExpectedTarget = $planningTargets[0]
            }
        }
    }

    It 'rejects unsafe BatchId values' {
        foreach ($bad in @('../bad', 'bad/path', 'bad\path', '', $null)) {
            $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'unsafe') -TenantId 'tenant-1' -BatchId 'batch-1'
            { & $script:ToolPath -TenantId 'tenant-1' -BatchId $bad -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
        }
    }

    It 'fails closed when Rev4.41 planning artifacts are missing' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'missing-planning') -TenantId 'tenant-1' -BatchId 'batch-1'
        Remove-Item -LiteralPath $fixture.PlanningRoot -Recurse -Force
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'fails closed when Rev4.42 disable-gate artifacts are missing' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'missing-disable') -TenantId 'tenant-1' -BatchId 'batch-1'
        Remove-Item -LiteralPath $fixture.DisableRoot -Recurse -Force
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'fails closed when Rev4.43 rollback-gate artifacts are missing' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'missing-rollback') -TenantId 'tenant-1' -BatchId 'batch-1'
        Remove-Item -LiteralPath $fixture.RollbackRoot -Recurse -Force
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'detects TenantId mismatch across artifacts' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'tenant-mismatch') -TenantId 'tenant-1' -BatchId 'batch-1'
        (Get-Content -LiteralPath (Join-Path $fixture.RollbackRoot 'rev443-batch-rollback-summary.json') -Raw) -replace 'tenant-1', 'tenant-2' | Set-Content -LiteralPath (Join-Path $fixture.RollbackRoot 'rev443-batch-rollback-summary.json')
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'detects BatchId mismatch across artifacts' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'batch-mismatch') -TenantId 'tenant-1' -BatchId 'batch-1'
        (Get-Content -LiteralPath (Join-Path $fixture.DisableRoot 'rev442-batch-reversible-disable-summary.json') -Raw) -replace 'batch-1', 'batch-2' | Set-Content -LiteralPath (Join-Path $fixture.DisableRoot 'rev442-batch-reversible-disable-summary.json')
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'detects ServicePrincipalObjectId mismatch' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'sp-mismatch') -TenantId 'tenant-1' -BatchId 'batch-1'
        $targets = Get-Content -LiteralPath (Join-Path $fixture.DisableRoot 'rev442-batch-reversible-disable-targets.json') -Raw | ConvertFrom-Json
        $targets[0].ServicePrincipalObjectId = 'sp-999'
        $targets | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $fixture.DisableRoot 'rev442-batch-reversible-disable-targets.json')
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'detects AppId mismatch when present' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'app-mismatch') -TenantId 'tenant-1' -BatchId 'batch-1'
        $targets = Get-Content -LiteralPath (Join-Path $fixture.RollbackRoot 'rev443-batch-rollback-targets.json') -Raw | ConvertFrom-Json
        $targets[0].AppId = 'app-999'
        $targets | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $fixture.RollbackRoot 'rev443-batch-rollback-targets.json')
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'confirms gate-only Rev4.42 status' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'gateonly-disable') -TenantId 'tenant-1' -BatchId 'batch-1'
        $result = & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot
        $result.CloseoutStatus | Should -Be 'CloseoutReady'
        $result.ToolVersion | Should -Be 'Rev4.44'
    }

    It 'confirms gate-only Rev4.43 status' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'gateonly-rollback') -TenantId 'tenant-1' -BatchId 'batch-1'
        $summary = & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot
        $summary.LiveExecutionSupported | Should -BeFalse
        $summary.NoTenantMutationPerformed | Should -BeTrue
    }

    It 'detects any live mutation indicator and blocks closeout' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'live-mutation') -TenantId 'tenant-1' -BatchId 'batch-1' -LiveMutation
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'fails closed when any source safety gate is false' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'failed-safety') -TenantId 'tenant-1' -BatchId 'batch-1' -FailSafetyGate
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot } | Should -Throw
    }

    It 'detects missing prior account state in rollback package and blocks in Strict mode' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'missing-prior') -TenantId 'tenant-1' -BatchId 'batch-1' -MissingPriorState
        { & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot -Strict } | Should -Throw
    }

    It 'allows EvidenceOnly targets but does not count them as mutation-ready' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'evidence-only') -TenantId 'tenant-1' -BatchId 'batch-1' -EvidenceOnly
        $summary = & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot
        $summary.EvidenceOnlyCount | Should -Be 1
        $summary.CloseoutReadyCount | Should -Be 0
    }

    It 'produces all expected Rev4.44 output artifacts' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'outputs') -TenantId 'tenant-1' -BatchId 'batch-1'
        $summary = & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot
        $runDir = Get-ChildItem -LiteralPath $fixture.OutputRoot -Directory -Recurse | Where-Object { $_.Name -like 'batch-*' } | Select-Object -First 1
        $summary.ArtifactCount | Should -Be 4
        Test-Path -LiteralPath (Join-Path $runDir.FullName 'rev444-batch-gate-closeout-summary.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $runDir.FullName 'rev444-batch-gate-closeout-findings.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $runDir.FullName 'rev444-batch-gate-closeout-targets.json') | Should -BeTrue
        Test-Path -LiteralPath (Join-Path $runDir.FullName 'rev444-batch-gate-closeout-operator-runbook.md') | Should -BeTrue
    }

    It 'ensures generated operator runbook contains required guidance' {
        $fixture = New-Rev444Fixture -BasePath (Join-Path $TestDrive 'runbook') -TenantId 'tenant-1' -BatchId 'batch-1'
        & $script:ToolPath -TenantId 'tenant-1' -BatchId 'batch-1' -OutputRoot $fixture.OutputRoot -PlanningRunRoot $fixture.PlanningRoot -DisableGateRunRoot $fixture.DisableRoot -RollbackGateRunRoot $fixture.RollbackRoot | Out-Null
        $runbook = Get-ChildItem -LiteralPath $fixture.OutputRoot -Recurse -File -Filter 'rev444-batch-gate-closeout-operator-runbook.md' | Select-Object -First 1 | Get-Content -Raw
        $runbook | Should -Match 'GateOnly'
        $runbook | Should -Match 'No tenant mutation'
        $runbook | Should -Match 'CloseoutBlocked|CloseoutReady'
        $runbook | Should -Match 'Live batch execution out of scope'
    }

    It 'static safety test confirms the wrapper does not contain forbidden live mutation calls' {
        $content = Get-Content -LiteralPath $script:ToolPath -Raw
        $content | Should -Not -Match 'Update-MgServicePrincipal'
        $content | Should -Not -Match 'Remove-Mg\*'
        $content | Should -Not -Match 'Remove-MgServicePrincipal'
        $content | Should -Not -Match 'Remove-MgApplication'
        $content | Should -Not -Match 'Invoke-NhiBatchChildLifecycle'
        $content | Should -Not -Match 'Start-NhiSingleObjectLifecycle'
        $content | Should -Not -Match 'Invoke-NhiRev438LiveDisable'
        $content | Should -Not -Match 'Invoke-NhiRev439LiveRollback'
    }
}
