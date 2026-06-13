$ErrorActionPreference = 'Stop'

function global:New-TestTarget {
    [pscustomobject]@{
        ObjectId = '11111111-1111-1111-1111-111111111111'
        DisplayName = 'Lab Reversible NHI'
        AppId = '22222222-2222-2222-2222-222222222222'
        ObjectType = 'ServicePrincipal'
        TargetType = 'ServicePrincipal'
        Classification = 'CustomerOwned'
        Environment = 'Lab'
        TenantScope = 'Lab'
        IsLabTarget = $true
        LabTargetMarker = $true
        SuppressCustomerRemediation = $false
        EvidenceOnly = $false
        InformationOnly = $false
        RemediationMode = 'ManualApprovalRequired'
    }
}

Describe 'Rev4.23 Consultant-Ready Operating Guide / Client-Safe Narrative' {
    BeforeAll {
        if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
            throw 'PSScriptRoot is not available for this test harness.'
        }

        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        if (-not (Test-Path -LiteralPath $script:modulePath)) {
            throw "Required module not found: $script:modulePath"
        }

        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev423'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:JsonIndexPath = Join-Path $TestDrive 'rev423-guide-index.json'
    }

    It 'Guide writes Markdown artifact locally' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath -JsonIndexPath $script:JsonIndexPath
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:JsonIndexPath | Should -BeTrue
    }

    It 'Guide includes title' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Run #4C Controlled Lab NHI Reversible Disable Operating Guide'
    }

    It 'Guide includes executive summary' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Executive Summary'
    }

    It 'Guide includes scope' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match '## Scope'
    }

    It 'Guide includes roles and responsibilities' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Roles and Responsibilities'
    }

    It 'Guide includes required artifacts' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Required Artifacts'
    }

    It 'Guide includes runbook phases' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Runbook Phases'
    }

    It 'Guide includes safety boundaries' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Safety Boundaries'
    }

    It 'Guide includes client-safe narrative' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Client-Safe Narrative'
    }

    It 'Guide states no final delete' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'No final delete'
    }

    It 'Guide states no production tenant write' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'No production tenant write'
    }

    It 'Guide states one approved lab NHI only' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Exactly one approved lab NHI'
    }

    It 'Guide states rollback requires separate approval' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'separate approval'
    }

    It 'Guide states Microsoft/platform identities are evidence-only' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw) | Should -Match 'Microsoft/platform identities are evidence-only'
    }

    It 'Guide contains no secrets' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match '(?i)clientsecret|refresh token|access token|secret='
    }

    It 'Guide contains no tokens' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match '(?i)Bearer eyJ|access token|id token'
    }

    It 'Guide contains no live credentials' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match '(?i)live credential|client secret|password'
    }

    It 'Guide does not emit executable delete command' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Mg'
    }

    It 'Guide does not emit executable final delete command' {
        $result = New-NhiRun4CConsultantOperatingGuide -Target @(New-TestTarget) -OutputPath $script:OutputPath
        $content = Get-Content -LiteralPath $result.OutputArtifactPath -Raw
        $content | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Invoke-NhiControlledLabLiveReversibleDisable|ExecuteNhiDecommission'
    }
}
