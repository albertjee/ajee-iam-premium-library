#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev35Readiness' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module Rev35Readiness -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Rev35Readiness.psm1') -Force -DisableNameChecking
    }

    # ── Export-DecomRev35ReadinessJson ───────────────────────────────────────

    It 'Rev3.5 readiness JSON exported — valid JSON, SchemaVersion 3.6, NhiDetectorsImplemented false' {
        $report = New-DecomRev35ReadinessReport
        $temp   = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomRev35ReadinessJson -Report $report -Path $temp
            $json = Get-Content $temp -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
            $json.SchemaVersion          | Should -Be '3.6'
            $json.NhiDetectorsImplemented | Should -Be $false
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Export-DecomRev35ReadinessMarkdown ───────────────────────────────────

    It 'Rev3.5 readiness Markdown exported — file exists and has markdown content' {
        $report = New-DecomRev35ReadinessReport
        $temp   = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomRev35ReadinessMarkdown -Report $report -Path $temp
            Test-Path $temp | Should -Be $true
            $content = Get-Content $temp -Raw
            $content | Should -Match '^#\s'
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Reserved namespaces ──────────────────────────────────────────────────

    It 'Reserved DEC-NHI-* namespace documented in ReservedNamespaces' {
        $report = New-DecomRev35ReadinessReport
        $nhiEntry = $report.ReservedNamespaces | Where-Object { $_.Namespace -eq 'DEC-NHI-*' }
        $nhiEntry | Should -Not -BeNullOrEmpty
    }

    It 'Reserved DEC-AGENT-* namespace documented in ReservedNamespaces' {
        $report = New-DecomRev35ReadinessReport
        $agentEntry = $report.ReservedNamespaces | Where-Object { $_.Namespace -eq 'DEC-AGENT-*' }
        $agentEntry | Should -Not -BeNullOrEmpty
    }

    # ── NHI detectors not implemented ───────────────────────────────────────

    It 'No NHI detectors implemented — NhiDetectorsImplemented is false and NhiFindings is empty' {
        $report = New-DecomRev35ReadinessReport
        $report.NhiDetectorsImplemented | Should -Be $false
        $report.NhiFindings.Count       | Should -Be 0
    }

    # ── Placeholders ─────────────────────────────────────────────────────────

    It 'NHI claim-safety placeholder is not null or empty' {
        $report = New-DecomRev35ReadinessReport
        $report.NhiClaimSafetyPlaceholder | Should -Not -BeNullOrEmpty
    }

    It 'Coverage model placeholder is not null or empty' {
        $report = New-DecomRev35ReadinessReport
        $report.CoverageModelPlaceholder | Should -Not -BeNullOrEmpty
    }
}
