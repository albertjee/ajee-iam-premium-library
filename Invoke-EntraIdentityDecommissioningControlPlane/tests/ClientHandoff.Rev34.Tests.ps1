#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'ClientHandoff' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module ClientHandoff -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'ClientHandoff.psm1') -Force -DisableNameChecking

        # Shared context used across tests
        $script:TestContext = [pscustomobject]@{
            ToolVersion  = 'Rev4.1'
            EngagementId = 'eng-test-001'
            ClientName   = 'Test Client'
            TenantId     = 'tenant-test-001'
        }
    }

    # ── New-DecomClientHandoffPackage / Export-DecomClientHandoffManifestJson ──

    It 'Client handoff manifest exported — JSON valid and SchemaVersion is 3.6' {
        $pkg  = New-DecomClientHandoffPackage `
            -Context     $script:TestContext `
            -RunId       'run-ch-001' `
            -PackagePath 'C:\out\handoff'

        $temp = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomClientHandoffManifestJson -Package $pkg -Path $temp
            $json = Get-Content $temp -Raw | ConvertFrom-Json
            $json | Should -Not -BeNullOrEmpty
            $json.SchemaVersion | Should -Be '3.6'
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Export-DecomClientHandoffIndexMarkdown ───────────────────────────────

    It 'Client handoff index exported — file exists and contains markdown heading' {
        $pkg  = New-DecomClientHandoffPackage `
            -Context     $script:TestContext `
            -RunId       'run-ch-002' `
            -PackagePath 'C:\out\handoff'

        $temp = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomClientHandoffIndexMarkdown -Package $pkg -Path $temp
            Test-Path $temp | Should -Be $true
            $content = Get-Content $temp -Raw
            $content | Should -Match '^#\s'
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Export-DecomClientHandoffChecklistMarkdown ───────────────────────────

    It 'Client handoff checklist exported — file exists and contains checkbox markers' {
        $pkg  = New-DecomClientHandoffPackage `
            -Context     $script:TestContext `
            -RunId       'run-ch-003' `
            -PackagePath 'C:\out\handoff'

        $temp = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomClientHandoffChecklistMarkdown -Package $pkg -Path $temp
            Test-Path $temp | Should -Be $true
            $content = Get-Content $temp -Raw
            $content | Should -Match '\- \[ \]'
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Sensitive file classification ────────────────────────────────────────

    It 'Sensitive files marked — findings file appears in SensitiveFiles or Sections.FindingsExports' {
        $findingsPath = 'C:\out\run-001\findings-export.json'

        $pkg = New-DecomClientHandoffPackage `
            -Context      $script:TestContext `
            -RunId        'run-ch-004' `
            -PackagePath  'C:\out\handoff' `
            -FindingsFiles @($findingsPath)

        $inSensitive = $pkg.SensitiveFiles -contains $findingsPath
        $inSection   = $pkg.Sections.FindingsExports -contains $findingsPath

        ($inSensitive -or $inSection) | Should -Be $true
    }

    # ── Redacted files preferred ─────────────────────────────────────────────

    It 'Redacted files preferred when available — redacted file appears in ClientSafeFiles' {
        $findingsPath = 'C:\out\run-001\findings-export.json'
        $redactedPath = 'C:\out\run-001\findings-redacted.json'

        $pkg = New-DecomClientHandoffPackage `
            -Context      $script:TestContext `
            -RunId        'run-ch-005' `
            -PackagePath  'C:\out\handoff' `
            -FindingsFiles @($findingsPath) `
            -RedactedFiles @($redactedPath)

        $pkg.ClientSafeFiles | Should -Contain $redactedPath
    }

    # ── Missing validation report creates warning ────────────────────────────

    It 'Missing validation report creates warning — ValidationStatus NotValidated adds to Warnings' {
        $pkg = New-DecomClientHandoffPackage `
            -Context          $script:TestContext `
            -RunId            'run-ch-006' `
            -PackagePath      'C:\out\handoff' `
            -ValidationStatus 'NotValidated'

        $pkg.Warnings.Count | Should -BeGreaterThan 0
    }
}
