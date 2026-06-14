#Requires -Modules Pester

BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:EntryPoint = Join-Path $script:Root 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    $script:ModulePath = Join-Path $script:Root 'src\Modules\NhiControlledDecommission.psm1'
    $script:SamplePath = Join-Path $script:Root 'samples\nhi-controlled-production-readiness.sample.json'
    $script:Source = Get-Content -LiteralPath $script:EntryPoint -Raw
    $script:Module = Get-Content -LiteralPath $script:ModulePath -Raw
    $script:Sample = Get-Content -LiteralPath $script:SamplePath -Raw

    $branchStart = $script:Source.IndexOf('# Rev4.2-S1 controlled NHI decommission planner/evidence flow')
    $branchEnd = $script:Source.IndexOf('# ── Rev4.0 M35: NHI Execution Guard + Flow ────────────────────────────────────', $branchStart)
    $script:ControlledBranch = $script:Source.Substring($branchStart, $branchEnd - $branchStart)

    $tokens = $null
    $errors = $null
    $script:EntryAst = [System.Management.Automation.Language.Parser]::ParseFile(
        $script:EntryPoint,
        [ref]$tokens,
        [ref]$errors
    )
    $script:ParseErrors = $errors
}

Describe 'Rev4.9 safety scan' {
    It 'parses the entry point without syntax errors' {
        $script:ParseErrors.Count | Should -Be 0
    }

    It 'keeps the controlled branch on the guarded production-readiness path' {
        $script:ControlledBranch | Should -Match 'ProductionReadiness'
        $script:ControlledBranch | Should -Match 'No Graph connection or tenant mutation performed'
    }

    It 'keeps the controlled branch free of live Graph write/delete patterns' {
        foreach ($pattern in @('Connect-MgGraph', 'Remove-MgServicePrincipal', 'Remove-MgApplication', 'Remove-Az', 'Invoke-MgGraphRequest', 'Update-Mg', 'Set-Mg', 'New-Mg')) {
            ([regex]::Matches($script:ControlledBranch, [regex]::Escape($pattern))).Count | Should -Be 0
        }
    }

    It 'keeps the controlled module free of live Graph write/delete patterns' {
        foreach ($pattern in @('Connect-MgGraph', 'Remove-MgServicePrincipal', 'Remove-MgApplication', 'Remove-Az', 'Invoke-MgGraphRequest', 'Update-Mg', 'Set-Mg', 'New-Mg')) {
            ([regex]::Matches($script:Module, [regex]::Escape($pattern))).Count | Should -Be 0
        }
    }

    It 'keeps the production readiness sample local only' {
        $script:Sample | Should -Match '"SchemaVersion"\s*:\s*"4\.9"'
        $script:Sample | Should -Match '"GitStatusClean"\s*:\s*true'
        $script:Sample | Should -Match '"FrozenFileDiffClean"\s*:\s*true'
    }

    It 'contains no secret-like values in the production readiness sample' {
        $script:Sample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
    }

    It 'contains no prohibited Graph mutation command names in the sample or module' {
        $script:Sample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az|Connect-MgGraph'
        $script:Module | Should -Not -Match 'Connect-MgGraph|Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az'
    }

    It 'keeps the entry point from exposing production readiness in default Assessment flow' {
        $script:Source | Should -Match 'if \(\$ExecuteNhiControlledDecommission -or \$ExecuteNhiControlledMetadataCleanup -or \$ExecuteNhiControlledGrantCleanup\)'
        $script:Source | Should -Match 'if \(\$controlledFeatureStage -eq ''ProductionReadiness''\)'
        $script:Source | Should -Not -Match 'Mode -eq ''Assessment''.*ProductionReadiness'
    }

    It 'does not schedule live merge or push operations' {
        foreach ($pattern in @('git push', 'Merge-Repository', 'New-GitTag', 'Remove-Branch', 'DeleteBranchExecuted = $true', 'PushExecuted = $true', 'MergeExecuted = $true')) {
            $script:Source | Should -Not -Match [regex]::Escape($pattern)
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
        @($commands | Where-Object { $_.GetCommandName() -in @('Remove-MgServicePrincipal', 'Remove-MgApplication', 'Remove-Az', 'Update-MgUser') }).Count | Should -Be 0
    }
}
