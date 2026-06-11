#Requires -Modules Pester

Describe 'Rev4.6 safety scan' {
    It 'keeps the additive module free of live Graph write/delete cmdlets' {
        $content = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1') -Raw
        foreach ($pattern in @('Connect-MgGraph', 'Remove-MgServicePrincipal', 'Remove-MgApplication', 'Invoke-MgGraphRequest', 'Update-Mg', 'Set-Mg', 'New-Mg')) {
            ([regex]::Matches($content, [regex]::Escape($pattern))).Count | Should -Be 0
        }
    }

    It 'keeps the Rev4.6 controlled branch free of live Graph write/delete patterns' {
        $content = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1') -Raw
        $start = $content.IndexOf('# Rev4.2-S1 controlled NHI decommission planner/evidence flow')
        $end = $content.IndexOf('# ── Rev4.0 M35: NHI Execution Guard + Flow ────────────────────────────────────')
        $controlled = $content.Substring($start, $end - $start)
        foreach ($pattern in @('Connect-MgGraph', 'Remove-MgServicePrincipal', 'Remove-MgApplication', 'Invoke-MgGraphRequest', 'Update-Mg', 'Set-Mg', 'New-Mg')) {
            ([regex]::Matches($controlled, [regex]::Escape($pattern))).Count | Should -Be 0
        }
    }

    It 'exposes the Rev4.6 grants cleanup stage string' {
        $content = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1') -Raw
        $content | Should -Match 'GrantCleanupReadiness'
    }

    It 'parses the Rev4.6 sample JSON' {
        Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-grants-cleanup.sample.json') -Raw | ConvertFrom-Json | Should -Not -BeNullOrEmpty
    }

    It 'keeps SelfTest before the controlled execution branch' {
        $content = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1') -Raw
        $content.IndexOf('# SelfTest early exit - no Graph connection, discovery, or remediation') | Should -BeLessThan ($content.IndexOf('if ($ExecuteNhiControlledDecommission -or $ExecuteNhiControlledMetadataCleanup -or $ExecuteNhiControlledGrantCleanup)'))
    }
}
