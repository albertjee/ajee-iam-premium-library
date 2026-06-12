#Requires -Modules Pester

BeforeAll {
    $script:EntryPointLines = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1')
    $script:ControlledBranch = ($script:EntryPointLines[176..445] -join [Environment]::NewLine)
    $script:Module = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1') -Raw
    $script:Sample = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-e2e-evidence-pack.sample.json') -Raw
}

Describe 'Rev4.8 safety scan' {

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

    It 'exposes the Rev4.8 stage string and sample schema' {
        $script:ControlledBranch | Should -Match 'E2EEvidencePack'
        $script:Sample | Should -Match '"SchemaVersion"\s*:\s*"4\.8"'
    }

    It 'parses the Rev4.8 sample JSON and keeps it local-only' {
        $json = $script:Sample | ConvertFrom-Json
        $json.LiveDeleteExecutable | Should -BeFalse
        $json.FinalDeleteSimulationOnly | Should -BeTrue
        $json.Status | Should -Be 'Approved'
    }
}
