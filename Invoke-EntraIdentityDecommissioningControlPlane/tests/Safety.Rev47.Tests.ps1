#Requires -Modules Pester

BeforeAll {
    $script:EntryPoint = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1') -Raw

    $branchStart = $script:EntryPoint.IndexOf('# Rev4.2-S1 controlled NHI decommission planner/evidence flow')
    if ($branchStart -lt 0) {
        throw 'Controlled branch start marker was not found in Invoke-EntraIdentityDecommissioningControlPlane.ps1.'
    }

    $branchEnd = $script:EntryPoint.IndexOf('Rev4.0 M35: NHI Execution Guard + Flow', $branchStart)
    if ($branchEnd -lt 0) {
        $branchEnd = $script:EntryPoint.IndexOf('if ($ExecuteNhiDecommission)', $branchStart)
    }
    if ($branchEnd -lt 0 -or $branchEnd -le $branchStart) {
        throw 'Controlled branch end marker was not found after the start marker in Invoke-EntraIdentityDecommissioningControlPlane.ps1.'
    }

    $script:ControlledBranch = $script:EntryPoint.Substring($branchStart, $branchEnd - $branchStart)
    $script:Module = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1') -Raw
    $script:Sample = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-managed-identity-readiness.sample.json') -Raw
}

Describe 'Rev4.7 safety scan' {

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

    It 'does not synthesize managed identity evidence defaults in the controlled branch' {
        $script:ControlledBranch | Should -Not -Match 'Present\s*=\s*\$true;\s*ParentResourceId\s*=\s*\[string\]\$controlledPlanInput\.TargetId'
        $script:ControlledBranch | Should -Not -Match 'Present\s*=\s*\$true;\s*ResourceId\s*=\s*\[string\]\$controlledPlanInput\.TargetId'
    }

    It 'exposes the Rev4.7 stage string and sample schema' {
        $script:ControlledBranch | Should -Match 'ManagedIdentityReadiness'
        $script:Sample | Should -Match '"SchemaVersion"\s*:\s*"4\.7"'
    }

    It 'parses the Rev4.7 sample JSON and keeps it local-only' {
        $json = $script:Sample | ConvertFrom-Json
        $json.LiveCleanupExecutable | Should -BeFalse
        $json.Status | Should -Be 'Approved'
    }
}
