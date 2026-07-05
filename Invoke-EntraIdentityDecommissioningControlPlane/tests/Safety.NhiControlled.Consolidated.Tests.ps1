#Requires -Modules Pester

# M7.2 Consolidation: 8 Safety.Rev4x files -> 1 consolidated file
# Kept ALL unique assertions; SubSumed variants merged to strongest version.
# BeforeAll reads all required sources once; no behavioral change to any assertion.

BeforeAll {
    $script:Root       = Join-Path $PSScriptRoot '..'
    $script:EntryPoint = Join-Path $script:Root 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    $script:ModulePath = Join-Path $script:Root 'src\Modules\NhiControlledDecommission.psm1'

    $script:EntrySource = Get-Content -LiteralPath $script:EntryPoint -Raw
    $script:ModuleSource = Get-Content -LiteralPath $script:ModulePath -Raw

    $script:Samples = @{
        PlanApproval    = Join-Path $script:Root 'samples\nhi-controlled-decommission-plan.sample.json'
        Approval        = Join-Path $script:Root 'samples\nhi-controlled-decommission-approval.sample.json'
        FinalDeleteApp  = Join-Path $script:Root 'samples\nhi-controlled-finaldelete-application.sample.json'
        FinalDeleteSp   = Join-Path $script:Root 'samples\nhi-controlled-finaldelete-sp.sample.json'
        MetadataCleanup = Join-Path $script:Root 'samples\nhi-controlled-metadata-cleanup.sample.json'
        GrantsCleanup   = Join-Path $script:Root 'samples\nhi-controlled-grants-cleanup.sample.json'
        ManagedIdentity = Join-Path $script:Root 'samples\nhi-controlled-managed-identity-readiness.sample.json'
        E2EEvidencePack = Join-Path $script:Root 'samples\nhi-controlled-e2e-evidence-pack.sample.json'
        ProductionReadiness = Join-Path $script:Root 'samples\nhi-controlled-production-readiness.sample.json'
    }

    # Controlled branch extraction (Rev4.2 marker through Rev4.0 M35 divider)
    $branchStart = $script:EntrySource.IndexOf('# Rev4.2-S1 controlled NHI decommission planner/evidence flow')
    $branchEnd   = $script:EntrySource.IndexOf('# ── Rev4.0 M35: NHI Execution Guard + Flow ────────────────────────────────────', $branchStart)
    if ($branchEnd -lt 0) { $branchEnd = $script:EntrySource.IndexOf('if ($ExecuteNhiDecommission)', $branchStart) }
    $script:ControlledBranch = $script:EntrySource.Substring($branchStart, $branchEnd - $branchStart)

    # AST for entry-point structural checks
    $tokens = $null; $errors = $null
    $script:EntryAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:EntryPoint, [ref]$tokens, [ref]$errors)
    $script:ParseErrors = $errors

    # Graph mutation patterns — widest set (Rev49 superset)
    $script:MutationPatterns = @(
        'Connect-MgGraph', 'Remove-MgServicePrincipal', 'Remove-MgApplication',
        'Remove-Az', 'Invoke-MgGraphRequest', 'Update-Mg', 'Set-Mg', 'New-Mg'
    )
}

# =============================================================================
# Rev4.2 Entry-Point Safety
# =============================================================================
Describe 'Rev4.2 entry-point safety' -Tag 'Safety' {
    It 'parses without errors' {
        $script:ParseErrors.Count | Should -Be 0
    }

    It 'uses Rev4.10 tool version for centralized release-validation compatibility' {
        $script:EntrySource | Should -Match ([regex]::Escape('$script:ToolVersion = ''Rev4.10'''))
    }

    It 'defines the Rev4.2-S1 parameter contract' {
        $paramNames = @($script:EntryAst.ParamBlock.Parameters.Name.VariablePath.UserPath)
        @('ExecuteNhiControlledDecommission', 'ExecutionStage', 'ApprovalManifestPath',
          'DecommissionPlanPath', 'ScreamTestWindowHours',
          'RequireSecondConfirmation', 'AllowFinalDelete', 'WhatIfExecution'
        ) | ForEach-Object { $paramNames | Should -Contain $_ }
    }

    It 'retains a single ApprovalManifestPath parameter' {
        @($script:EntryAst.ParamBlock.Parameters | Where-Object {
            $_.Name.VariablePath.UserPath -eq 'ApprovalManifestPath'
        }).Count | Should -Be 1
    }

    It 'loads the additive controlled decommission module' {
        $script:EntrySource | Should -Match "'NhiControlledDecommission'"
    }

    It 'places SelfTest before controlled decommission and Graph connection paths' {
        $script:EntrySource.IndexOf('# SelfTest early exit') | Should -BeLessThan `
            $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)')
        $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)') | Should -BeLessThan `
            $script:EntrySource.IndexOf('Connect-MgGraph')
    }

    It 'requires WhatIfExecution or DemoMode' {
        $script:ControlledBranch | Should -Match 'if \(-not \$WhatIfExecution -and -not \$DemoMode\)'
    }

    It 'fails closed when the decommission plan is missing' {
        $script:ControlledBranch | Should -Match 'requires a valid -DecommissionPlanPath'
    }

    It 'fails closed when the approval manifest is missing' {
        $script:ControlledBranch | Should -Match 'requires a valid -ApprovalManifestPath'
    }

    It 'blocks FinalDelete and AllowFinalDelete' {
        $script:ControlledBranch | Should -Match ([regex]::Escape('$ExecutionStage -eq ''FinalDelete'' -or $AllowFinalDelete'))
        $script:ControlledBranch | Should -Match 'FinalDelete is blocked for live execution'
    }

    It 'contains no Graph connection in the controlled branch' {
        $script:ControlledBranch | Should -Not -Match 'Connect-MgGraph'
    }

    It 'contains no Graph mutation command in the controlled branch' {
        $script:ControlledBranch | Should -Not -Match '(?m)^\s*(Remove|Update|Set|New)-Mg[A-Za-z]'
        $script:ControlledBranch | Should -Not -Match '(?m)^\s*Invoke-MgGraphRequest'
    }

    It 'does not invoke prohibited deletion commands anywhere in the entry point' {
        $commands = $script:EntryAst.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
        @($commands | Where-Object { $_.GetCommandName() -in @('Remove-MgServicePrincipal', 'Remove-MgApplication') }).Count | Should -Be 0
    }

    It 'exports five local evidence artifacts and exits before existing execution flow' {
        ([regex]::Matches($script:ControlledBranch, 'Export-NhiControlledDecommissionEvidence')).Count | Should -BeGreaterOrEqual 5
        $script:ControlledBranch | Should -Match 'exit 0'
    }

    It 'sample planner invocation succeeds without a Graph connection' {
        $outputPath = Join-Path $TestDrive 'planner'
        # Plan (DeleteReadinessOnly) + matching approval sample — both from the same sample pair
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPoint `
            -ExecuteNhiControlledDecommission -ExecutionStage DeleteReadinessOnly `
            -DecommissionPlanPath $script:Samples.PlanApproval `
            -ApprovalManifestPath $script:Samples.Approval `
            -WhatIfExecution -OutputPath $outputPath 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
        @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'controlled-decommission-RUN-REV42-SAMPLE-001') -File).Count | Should -Be 5
    }

    It 'sample FinalDelete invocation fails closed' {
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPoint `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete `
            -DecommissionPlanPath $script:Samples.FinalDeleteSp `
            -ApprovalManifestPath $script:Samples.FinalDeleteSp `
            -WhatIfExecution -OutputPath (Join-Path $TestDrive 'final-delete') 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'FinalDelete is blocked for live execution'
    }
}

# =============================================================================
# Rev4.3 FinalDelete Safety Boundary
# =============================================================================
Describe 'Rev4.3 FinalDelete safety boundary' -Tag 'Safety' {
    It 'contains no ServicePrincipal delete cmdlet invocation' {
        $script:EntrySource | Should -Not -Match '(?m)^\s*Remove-MgServicePrincipal\b'
        $script:ModuleSource | Should -Not -Match '(?m)^\s*Remove-MgServicePrincipal\b'
    }

    It 'contains no Application delete cmdlet invocation' {
        $script:EntrySource | Should -Not -Match '(?m)^\s*Remove-MgApplication\b'
        $script:ModuleSource | Should -Not -Match '(?m)^\s*Remove-MgApplication\b'
    }

    It 'contains no Graph connection or request in the additive module' {
        $script:ModuleSource | Should -Not -Match 'Connect-MgGraph|Invoke-MgGraphRequest'
    }

    It 'classifies live delete as unavailable in the gate model' {
        $script:ModuleSource | Should -Match 'LiveDeleteExecutable\s*=\s*\$false'
        $script:ModuleSource | Should -Match 'DeleteCmdletAvailable\s*=\s*\$false'
    }

    It 'requires WhatIfExecution or DemoMode before controlled processing' {
        $script:EntrySource | Should -Match 'if \(-not \$WhatIfExecution -and -not \$DemoMode\)'
    }

    It 'requires AllowFinalDelete for FinalDelete simulation' {
        $script:EntrySource | Should -Match ([regex]::Escape('$ExecutionStage -eq ''FinalDelete'' -and -not $AllowFinalDelete'))
    }

    It 'blocks AllowFinalDelete outside FinalDelete stage' {
        $script:EntrySource | Should -Match ([regex]::Escape('$AllowFinalDelete -and $ExecutionStage -ne ''FinalDelete'''))
    }

    It 'keeps SelfTest before controlled and Graph paths' {
        $script:EntrySource.IndexOf('# SelfTest early exit') | Should -BeLessThan `
            $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)')
        $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)') | Should -BeLessThan `
            $script:EntrySource.IndexOf('Connect-MgGraph')
    }

    It 'sample simulation produces local evidence and never reports mutation' {
        $outputPath = Join-Path $TestDrive 'rev43'
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPoint `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete -AllowFinalDelete `
            -DecommissionPlanPath $script:Samples.FinalDeleteSp `
            -ApprovalManifestPath $script:Samples.FinalDeleteSp `
            -WhatIfExecution -OutputPath $outputPath 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Live delete is unavailable'
        ($output -join "`n") | Should -Match 'GuardSatisfiedSimulationOnly'
        ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
        @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'controlled-decommission-RUN-REV43-SP-FINALDELETE-SAMPLE-001') -File).Count | Should -Be 5
    }

    It 'FinalDelete remains blocked by default' {
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPoint `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete `
            -DecommissionPlanPath $script:Samples.FinalDeleteSp `
            -ApprovalManifestPath $script:Samples.FinalDeleteSp `
            -WhatIfExecution -OutputPath (Join-Path $TestDrive 'blocked') 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'blocked for live execution by default'
    }
}

# =============================================================================
# Rev4.4 Application Readiness Safety Boundary
# =============================================================================
Describe 'Rev4.4 Application readiness safety boundary' -Tag 'Safety' {
    # 'contains no Application/ServicePrincipal delete cmdlet invocation' merged into Rev4.3 above (identical assertion)

    It 'contains no Graph call in the additive module' {
        $script:ModuleSource | Should -Not -Match 'Connect-MgGraph|Invoke-MgGraphRequest'
    }

    It 'classifies Application live delete as unavailable' {
        $script:ModuleSource | Should -Match 'FinalDeleteApplicationReadiness'
        $script:ModuleSource | Should -Match 'LiveDeleteExecutable\s*=\s*\$false'
        $script:ModuleSource | Should -Match 'DeleteCmdletAvailable\s*=\s*\$false'
    }

    # Rev44+45+46+47+49 all have "keeps SelfTest" — merged from Rev44 Rev45 Rev46 Rev47 Rev49
    It 'keeps SelfTest before the controlled execution branch' {
        $script:EntrySource.IndexOf('# SelfTest early exit') | Should -BeLessThan `
            $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)')
    }

    It 'dispatches Application readiness separately from ServicePrincipal gate' {
        $script:EntrySource | Should -Match ([regex]::Escape('$controlledPlanInput.TargetType -eq ''Application'''))
        $script:EntrySource | Should -Match 'Test-NhiControlledApplicationDeleteReadinessGate'
        $script:EntrySource | Should -Match 'Test-NhiControlledServicePrincipalFinalDeleteGate'
    }

    It 'sample Application readiness produces five local evidence files only' {
        $outputPath = Join-Path $TestDrive 'rev44'
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPoint `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete -AllowFinalDelete `
            -DecommissionPlanPath $script:Samples.FinalDeleteApp `
            -ApprovalManifestPath $script:Samples.FinalDeleteApp `
            -WhatIfExecution -OutputPath $outputPath 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'ReadinessSatisfiedSimulationOnly'
        ($output -join "`n") | Should -Match 'Live delete is unavailable'
        ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
        @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'controlled-decommission-RUN-REV44-APPLICATION-SAMPLE-001') -File).Count | Should -Be 5
    }

    It 'Application FinalDelete remains blocked without AllowFinalDelete' {
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPoint `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete `
            -DecommissionPlanPath $script:Samples.FinalDeleteApp `
            -ApprovalManifestPath $script:Samples.FinalDeleteApp `
            -WhatIfExecution -OutputPath (Join-Path $TestDrive 'blocked') 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'blocked for live execution by default'
    }

    It 'default source path contains no Application gate invocation before controlled branch' {
        $idx = $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)')
        $prefix = $script:EntrySource.Substring(0, $idx)
        $prefix | Should -Not -Match 'Test-NhiControlledApplicationDeleteReadinessGate'
    }

    It 'WhatIf source path contains no mutation cmdlet' {
        $script:ModuleSource | Should -Not -Match '(?m)^\s*(Remove|Update|Set|New)-Mg[A-Za-z]'
    }
}

# =============================================================================
# Rev4.5 Metadata Cleanup Safety
# =============================================================================
Describe 'Rev4.5 metadata cleanup safety' -Tag 'Safety' {
    # Merged: Rev45/46/47/48/49 all test module free of Graph patterns — use Rev49 superset
    It 'keeps the additive module free of live Graph write/delete cmdlets' {
        foreach ($p in $script:MutationPatterns) {
            ([regex]::Matches($script:ModuleSource, [regex]::Escape($p))).Count | Should -Be 0
        }
    }

    # Merged: Rev45/46/47/48/49 all test controlled branch — use Rev49 superset
    It 'keeps the controlled branch free of live Graph write/delete patterns' {
        foreach ($p in $script:MutationPatterns) {
            ([regex]::Matches($script:ControlledBranch, [regex]::Escape($p))).Count | Should -Be 0
        }
    }

    It 'exposes the Rev4.5 metadata cleanup stage string' {
        $script:EntrySource | Should -Match 'MetadataCleanupReadiness'
    }

    It 'parses the Rev4.5 sample JSON' {
        Get-Content -LiteralPath $script:Samples.MetadataCleanup -Raw | ConvertFrom-Json | Should -Not -BeNullOrEmpty
    }
}

# =============================================================================
# Rev4.6 Grants Cleanup Safety
# =============================================================================
Describe 'Rev4.6 grants cleanup safety' -Tag 'Safety' {
    It 'exposes the Rev4.6 grants cleanup stage string' {
        $script:EntrySource | Should -Match 'GrantCleanupReadiness'
    }

    It 'parses the Rev4.6 sample JSON' {
        Get-Content -LiteralPath $script:Samples.GrantsCleanup -Raw | ConvertFrom-Json | Should -Not -BeNullOrEmpty
    }
}

# =============================================================================
# Rev4.7 Managed Identity Safety
# =============================================================================
Describe 'Rev4.7 managed identity safety' -Tag 'Safety' {
    It 'does not synthesize managed identity evidence defaults in the controlled branch' {
        $script:ControlledBranch | Should -Not -Match 'Present\s*=\s*\$true;\s*ParentResourceId\s*=\s*\[string\]\$controlledPlanInput\.TargetId'
        $script:ControlledBranch | Should -Not -Match 'Present\s*=\s*\$true;\s*ResourceId\s*=\s*\[string\]\$controlledPlanInput\.TargetId'
    }

    It 'exposes the Rev4.7 stage string and sample schema' {
        $script:ControlledBranch | Should -Match 'ManagedIdentityReadiness'
        Get-Content -LiteralPath $script:Samples.ManagedIdentity -Raw | Should -Match '"SchemaVersion"\s*:\s*"4\.7"'
    }

    It 'parses the Rev4.7 sample JSON and keeps it local-only' {
        $json = Get-Content -LiteralPath $script:Samples.ManagedIdentity -Raw | ConvertFrom-Json
        $json.LiveCleanupExecutable | Should -BeFalse
        $json.Status | Should -Be 'Approved'
    }
}

# =============================================================================
# Rev4.8 E2E Evidence Pack Safety
# =============================================================================
Describe 'Rev4.8 E2E evidence pack safety' -Tag 'Safety' {
    It 'exposes the Rev4.8 stage string and sample schema' {
        $script:ControlledBranch | Should -Match 'E2EEvidencePack'
        Get-Content -LiteralPath $script:Samples.E2EEvidencePack -Raw | Should -Match '"SchemaVersion"\s*:\s*"4\.8"'
    }

    It 'parses the Rev4.8 sample JSON and keeps it local-only' {
        $json = Get-Content -LiteralPath $script:Samples.E2EEvidencePack -Raw | ConvertFrom-Json
        $json.LiveDeleteExecutable | Should -BeFalse
        $json.FinalDeleteSimulationOnly | Should -BeTrue
        $json.Status | Should -Be 'Approved'
    }
}

# =============================================================================
# Rev4.9 Production Readiness Safety
# =============================================================================
Describe 'Rev4.9 production readiness safety' -Tag 'Safety' {
    It 'parses the entry point without syntax errors' {
        $script:ParseErrors.Count | Should -Be 0
    }

    It 'keeps the controlled branch on the guarded production-readiness path' {
        $script:ControlledBranch | Should -Match 'ProductionReadiness'
        $script:ControlledBranch | Should -Match 'No Graph connection or tenant mutation performed'
    }

    It 'keeps the entry point from exposing production readiness in default Assessment flow' {
        $script:EntrySource | Should -Match 'if \(\$ExecuteNhiControlledDecommission -or \$ExecuteNhiControlledMetadataCleanup -or \$ExecuteNhiControlledGrantCleanup\)'
        $script:EntrySource | Should -Match 'if \(\$controlledFeatureStage -eq ''ProductionReadiness''\)'
        $script:EntrySource | Should -Not -Match 'Mode -eq ''Assessment''.*ProductionReadiness'
    }

    It 'keeps the production readiness sample local only' {
        Get-Content -LiteralPath $script:Samples.ProductionReadiness -Raw | Should -Match '"SchemaVersion"\s*:\s*"4\.9"'
        Get-Content -LiteralPath $script:Samples.ProductionReadiness -Raw | Should -Match '"GitStatusClean"\s*:\s*true'
        Get-Content -LiteralPath $script:Samples.ProductionReadiness -Raw | Should -Match '"FrozenFileDiffClean"\s*:\s*true'
    }

    It 'contains no secret-like values in the production readiness sample' {
        Get-Content -LiteralPath $script:Samples.ProductionReadiness -Raw |
            Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
    }

    It 'contains no prohibited Graph mutation command names in the sample or module' {
        Get-Content -LiteralPath $script:Samples.ProductionReadiness -Raw |
            Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az|Connect-MgGraph'
        $script:ModuleSource | Should -Not -Match 'Connect-MgGraph|Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az'
    }

    It 'does not schedule live merge or push operations' {
        foreach ($pattern in @('git push', 'Merge-Repository', 'New-GitTag', 'Remove-Branch', 'DeleteBranchExecuted = $true', 'PushExecuted = $true', 'MergeExecuted = $true')) {
            $script:EntrySource | Should -Not -Match [regex]::Escape($pattern)
        }
    }

    It 'retains the controlled entry point before the execution flow' {
        $script:ControlledBranch | Should -Match 'exit 0'
        $script:ControlledBranch | Should -Match 'Rev4\.9 production readiness guardrails completed'
    }

    It 'does not reference any live Graph write/delete cmdlet anywhere in the entry point AST' {
        $commands = $script:EntryAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true)
        @($commands | Where-Object {
            $_.GetCommandName() -in @('Remove-MgServicePrincipal', 'Remove-MgApplication', 'Remove-Az', 'Update-MgUser')
        }).Count | Should -Be 0
    }
}