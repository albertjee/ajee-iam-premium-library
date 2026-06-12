#Requires -Modules Pester

BeforeAll {
    $script:Root = Join-Path $PSScriptRoot '..'
    $script:EntryPoint = Join-Path $script:Root 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    $script:PlanSample = Join-Path $script:Root 'samples\nhi-controlled-decommission-plan.sample.json'
    $script:ApprovalSample = Join-Path $script:Root 'samples\nhi-controlled-decommission-approval.sample.json'
    $script:Source = Get-Content -LiteralPath $script:EntryPoint -Raw

    $branchStart = $script:Source.IndexOf('# Rev4.2-S1 controlled NHI decommission planner/evidence flow')
    if ($branchStart -lt 0) {
        throw 'Controlled branch start marker was not found in Invoke-EntraIdentityDecommissioningControlPlane.ps1.'
    }
    $branchEnd = $script:Source.IndexOf('if ($ExecuteNhiDecommission)', $branchStart)
    if ($branchEnd -lt 0 -or $branchEnd -le $branchStart) {
        throw 'Controlled branch end marker was not found after the start marker in Invoke-EntraIdentityDecommissioningControlPlane.ps1.'
    }
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

Describe 'Rev4.2-S1 entry-point controlled decommission safety' {
    It 'parses without errors' {
        $script:ParseErrors.Count | Should -Be 0
    }

    It 'retains Rev4.1 tool version for frozen release-validation compatibility' {
        $script:Source | Should -Match ([regex]::Escape('$script:ToolVersion = ''Rev4.1'''))
    }

    It 'defines the Rev4.2-S1 parameter contract' {
        $parameterNames = @($script:EntryAst.ParamBlock.Parameters.Name.VariablePath.UserPath)
        @(
            'ExecuteNhiControlledDecommission'
            'ExecutionStage'
            'ApprovalManifestPath'
            'DecommissionPlanPath'
            'ScreamTestWindowHours'
            'RequireSecondConfirmation'
            'AllowFinalDelete'
            'WhatIfExecution'
        ) | ForEach-Object {
            $parameterNames | Should -Contain $_
        }
    }

    It 'retains a single ApprovalManifestPath parameter' {
        @($script:EntryAst.ParamBlock.Parameters | Where-Object {
            $_.Name.VariablePath.UserPath -eq 'ApprovalManifestPath'
        }).Count | Should -Be 1
    }

    It 'loads the additive controlled decommission module' {
        $script:Source | Should -Match "'NhiControlledDecommission'"
    }

    It 'places SelfTest before controlled decommission and Graph connection paths' {
        $script:Source.IndexOf('# SelfTest early exit - no Graph connection, discovery, or remediation') | Should -BeLessThan $script:Source.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)')
        $script:Source.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)') | Should -BeLessThan $script:Source.IndexOf('Connect-MgGraph')
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
        $script:ControlledBranch | Should -Match 'FinalDelete is blocked for live execution in Rev4\.2-S1'
    }

    It 'contains no Graph connection in the controlled branch' {
        $script:ControlledBranch | Should -Not -Match 'Connect-MgGraph'
    }

    It 'contains no Graph mutation command in the controlled branch' {
        $script:ControlledBranch | Should -Not -Match '(?m)^\s*(Remove|Update|Set|New)-Mg[A-Za-z]'
        $script:ControlledBranch | Should -Not -Match '(?m)^\s*Invoke-MgGraphRequest'
    }

    It 'does not invoke prohibited deletion commands anywhere in the entry point' {
        $commands = $script:EntryAst.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        }, $true)
        @($commands | Where-Object {
            $_.GetCommandName() -in @('Remove-MgServicePrincipal', 'Remove-MgApplication')
        }).Count | Should -Be 0
    }

    It 'exports five local evidence artifacts and exits before existing execution flow' {
        ([regex]::Matches($script:ControlledBranch, 'Export-NhiControlledDecommissionEvidence')).Count | Should -BeGreaterOrEqual 5
        $script:ControlledBranch | Should -Match 'exit 0'
    }

    It 'sample planner invocation succeeds without a Graph connection' {
        $outputPath = Join-Path $TestDrive 'planner'
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPoint `
            -ExecuteNhiControlledDecommission `
            -ExecutionStage DeleteReadinessOnly `
            -DecommissionPlanPath $script:PlanSample `
            -ApprovalManifestPath $script:ApprovalSample `
            -WhatIfExecution `
            -OutputPath $outputPath 2>&1

        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
        @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'controlled-decommission-RUN-REV42-SAMPLE-001') -File).Count | Should -Be 5
    }

    It 'sample FinalDelete invocation fails closed' {
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPoint `
            -ExecuteNhiControlledDecommission `
            -ExecutionStage FinalDelete `
            -DecommissionPlanPath $script:PlanSample `
            -ApprovalManifestPath $script:ApprovalSample `
            -WhatIfExecution `
            -OutputPath (Join-Path $TestDrive 'final-delete') 2>&1

        $LASTEXITCODE | Should -Be 1
        ($output -join "`n") | Should -Match 'FinalDelete is blocked for live execution'
    }
}
