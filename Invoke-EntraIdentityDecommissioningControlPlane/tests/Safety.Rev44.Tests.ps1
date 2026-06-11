#Requires -Modules Pester

BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Entry = Join-Path $script:Root 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    $script:Module = Join-Path $script:Root 'src\Modules\NhiControlledDecommission.psm1'
    $script:Sample = Join-Path $script:Root 'samples\nhi-controlled-finaldelete-application.sample.json'
    $script:EntrySource = Get-Content -LiteralPath $script:Entry -Raw
    $script:ModuleSource = Get-Content -LiteralPath $script:Module -Raw
}

Describe 'Rev4.4 Application readiness safety boundary' {
    It 'contains no Application delete cmdlet invocation' {
        $script:EntrySource | Should -Not -Match '(?m)^\s*Remove-MgApplication\b'
        $script:ModuleSource | Should -Not -Match '(?m)^\s*Remove-MgApplication\b'
    }

    It 'contains no ServicePrincipal delete cmdlet invocation' {
        $script:EntrySource | Should -Not -Match '(?m)^\s*Remove-MgServicePrincipal\b'
        $script:ModuleSource | Should -Not -Match '(?m)^\s*Remove-MgServicePrincipal\b'
    }

    It 'contains no Graph call in the additive module' {
        $script:ModuleSource | Should -Not -Match 'Connect-MgGraph|Invoke-MgGraphRequest'
    }

    It 'classifies Application live delete as unavailable' {
        $script:ModuleSource | Should -Match 'FinalDeleteApplicationReadiness'
        $script:ModuleSource | Should -Match 'LiveDeleteExecutable\s*=\s*\$false'
        $script:ModuleSource | Should -Match 'DeleteCmdletAvailable\s*=\s*\$false'
    }

    It 'keeps SelfTest before controlled and Graph paths' {
        $script:EntrySource.IndexOf('if ($SelfTest)') | Should -BeLessThan $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission)')
        $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission)') | Should -BeLessThan $script:EntrySource.IndexOf('Connect-MgGraph')
    }

    It 'dispatches Application readiness separately from ServicePrincipal gate' {
        $script:EntrySource | Should -Match ([regex]::Escape('$controlledPlanInput.TargetType -eq ''Application'''))
        $script:EntrySource | Should -Match 'Test-NhiControlledApplicationDeleteReadinessGate'
        $script:EntrySource | Should -Match 'Test-NhiControlledServicePrincipalFinalDeleteGate'
    }

    It 'sample Application readiness produces five local evidence files only' {
        $outputPath = Join-Path $TestDrive 'rev44'
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Entry `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete -AllowFinalDelete `
            -DecommissionPlanPath $script:Sample -ApprovalManifestPath $script:Sample `
            -WhatIfExecution -OutputPath $outputPath 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'ReadinessSatisfiedSimulationOnly'
        ($output -join "`n") | Should -Match 'Live delete is unavailable'
        ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
        @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'controlled-decommission-RUN-REV44-APPLICATION-SAMPLE-001') -File).Count | Should -Be 5
    }

    It 'Application FinalDelete remains blocked without AllowFinalDelete' {
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Entry `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete `
            -DecommissionPlanPath $script:Sample -ApprovalManifestPath $script:Sample `
            -WhatIfExecution -OutputPath (Join-Path $TestDrive 'blocked') 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'blocked for live execution by default'
    }

    It 'default source path contains no Application gate invocation before controlled branch' {
        $controlledIndex = $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission)')
        $prefix = $script:EntrySource.Substring(0, $controlledIndex)
        $prefix | Should -Not -Match 'Test-NhiControlledApplicationDeleteReadinessGate'
    }

    It 'WhatIf source path contains no mutation cmdlet' {
        $script:ModuleSource | Should -Not -Match '(?m)^\s*(Remove|Update|Set|New)-Mg[A-Za-z]'
    }
}
