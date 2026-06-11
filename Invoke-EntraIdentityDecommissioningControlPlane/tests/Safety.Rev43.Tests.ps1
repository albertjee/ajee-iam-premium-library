#Requires -Modules Pester

BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:Entry = Join-Path $script:Root 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    $script:Module = Join-Path $script:Root 'src\Modules\NhiControlledDecommission.psm1'
    $script:Sample = Join-Path $script:Root 'samples\nhi-controlled-finaldelete-sp.sample.json'
    $script:EntrySource = Get-Content -LiteralPath $script:Entry -Raw
    $script:ModuleSource = Get-Content -LiteralPath $script:Module -Raw
}

Describe 'Rev4.3 FinalDelete safety boundary' {
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
        $script:EntrySource.IndexOf('if ($SelfTest)') | Should -BeLessThan $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission)')
        $script:EntrySource.IndexOf('if ($ExecuteNhiControlledDecommission)') | Should -BeLessThan $script:EntrySource.IndexOf('Connect-MgGraph')
    }

    It 'sample simulation produces local evidence and never reports mutation' {
        $outputPath = Join-Path $TestDrive 'rev43'
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Entry `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete -AllowFinalDelete `
            -DecommissionPlanPath $script:Sample -ApprovalManifestPath $script:Sample `
            -WhatIfExecution -OutputPath $outputPath 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Live delete is unavailable'
        ($output -join "`n") | Should -Match 'GuardSatisfiedSimulationOnly'
        ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
        @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'controlled-decommission-RUN-REV43-SP-FINALDELETE-SAMPLE-001') -File).Count | Should -Be 5
    }

    It 'FinalDelete remains blocked by default' {
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:Entry `
            -ExecuteNhiControlledDecommission -ExecutionStage FinalDelete `
            -DecommissionPlanPath $script:Sample -ApprovalManifestPath $script:Sample `
            -WhatIfExecution -OutputPath (Join-Path $TestDrive 'blocked') 2>&1
        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'blocked for live execution by default'
    }
}
