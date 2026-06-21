#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

function script:Write-TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    ($InputObject | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $Path -Encoding utf8
}

function script:Get-FileCommandCounts {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        throw "Parse errors in $Path : $($errors.Count)"
    }

    $commands = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst]
    }, $true)

    [pscustomobject]@{
        UpdateCount = @($commands | Where-Object { $_.GetCommandName() -ieq 'Update-MgServicePrincipal' }).Count
        RemoveCount = @($commands | Where-Object { $_.GetCommandName() -like 'Remove-Mg*' }).Count
    }
}

function script:Get-ValidateSetValues {
    param(
        [Parameter(Mandatory)]
        [System.Management.Automation.ParameterMetadata]$ParameterMetadata
    )

    $validateSet = $ParameterMetadata.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1
    if ($null -eq $validateSet) {
        return @()
    }

    return @($validateSet.ValidValues)
}

function script:New-FakeReadinessSummary {
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [bool]$ReadyForLiveDisable = $true
    )

    $summary = [pscustomobject]@{
        ReadyForWhatIf = $true
        ReadyForLiveDisable = $ReadyForLiveDisable
        BlockingReasons = @()
        OutputArtifactPath = Join-Path $OutputPath 'rev438-live-run-readiness.json'
    }

    Write-TestJson -Path $summary.OutputArtifactPath -InputObject $summary
    return $summary
}

function script:New-FakeLiveSummary {
    param(
        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$ArtifactName,

        [bool]$LiveMutationPerformed = $false,

        [bool]$SafetyGatePassed = $true,

        [bool]$FinalDeleteAllowed = $false,

        [bool]$CleanupAllowed = $false
    )

    $summary = [pscustomobject]@{
        LiveMutationPerformed = $LiveMutationPerformed
        SafetyGatePassed = $SafetyGatePassed
        FinalDeleteAllowed = $FinalDeleteAllowed
        CleanupAllowed = $CleanupAllowed
        OutputArtifactPath = Join-Path $OutputPath $ArtifactName
    }

    Write-TestJson -Path $summary.OutputArtifactPath -InputObject $summary
    return $summary
}

function script:Get-MgServicePrincipal {
    throw 'Graph cmdlet stub must be mocked in tests.'
}

Describe 'Rev4.40 single object lifecycle wrapper' {
    BeforeAll {
        $script:WrapperPath = Join-Path $PSScriptRoot '..\tools\Start-NhiSingleObjectLifecycle.ps1'
        . $script:WrapperPath -TenantId '3177c971-05c9-4b7b-93a1-0edf6fd7237d' -Action ReversibleDisable -Mode Readiness -TargetObjectId '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b' -OutputRoot (Join-Path $TestDrive 'dot-source') -InventoryPath (Join-Path $TestDrive 'dot-source-inventory.json') -ApprovalPhrase 'APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
        $script:CommandCounts = Get-FileCommandCounts -Path $script:WrapperPath
        $script:WrapperCommand = Get-Command Start-NhiSingleObjectLifecycle
        $script:TenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
        $script:TargetObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
        $script:ControlObjectId = 'b574ecc2-443f-4963-9cd4-cb5da517a717'
        $script:TargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
        $script:TargetAppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
        $script:TargetApplicationObjectId = 'cacb17fd-bc8d-4798-a8b9-e030699ea2ad'
        $script:InventoryPath = Join-Path $TestDrive 'rev440-inventory.json'
        Write-TestJson -Path $script:InventoryPath -InputObject ([pscustomobject]@{ Inventory = @() })
        $script:DisablePhrase = 'APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
        $script:RollbackPhrase = 'APPROVE REV4.39 LIVE ROLLBACK AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
    }

    BeforeEach {
        $script:RunRoot = Join-Path $TestDrive ('rev440-' + [guid]::NewGuid().ToString('N'))
        $null = New-Item -ItemType Directory -Path $script:RunRoot -Force
    }

    AfterAll {
        Remove-Item -LiteralPath Function:\Get-MgServicePrincipal -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath Function:\global:Get-MgServicePrincipal -ErrorAction SilentlyContinue
    }

    It 'exists' {
        Test-Path -LiteralPath $script:WrapperPath | Should -BeTrue
    }

    It 'supports only expected actions' {
        (Get-ValidateSetValues -ParameterMetadata $script:WrapperCommand.Parameters['Action']) | Should -Be @('ReversibleDisable', 'RollbackDisable')
    }

    It 'supports only expected modes' {
        (Get-ValidateSetValues -ParameterMetadata $script:WrapperCommand.Parameters['Mode']) | Should -Be @('Readiness', 'WhatIf', 'Execute', 'Verify', 'Closeout')
    }

    It 'rejects unsupported actions' {
        { Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action 'UnsupportedAction' -Mode Readiness -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot } | Should -Throw
    }

    It 'rejects unsupported modes' {
        { Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action ReversibleDisable -Mode 'UnsupportedMode' -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot } | Should -Throw
    }

    It 'rejects wrong tenant' {
        { Start-NhiSingleObjectLifecycle -TenantId '00000000-0000-0000-0000-000000000000' -Action ReversibleDisable -Mode Readiness -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot } | Should -Throw
    }

    It 'rejects wrong target object ID' {
        { Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action ReversibleDisable -Mode Readiness -TargetObjectId 'ffffffff-ffff-ffff-ffff-ffffffffffff' -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot } | Should -Throw
    }

    It 'generates the Rev4.38 disable approval manifest using the current schema' {
        Mock Invoke-NhiRev438Readiness {
            param($TenantId, $InventoryPath, $ApprovalManifestPath, $OutputPath, $ConfirmLiveDisablePhrase, $RunId)
            New-FakeReadinessSummary -OutputPath $OutputPath
        }

        $result = Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action ReversibleDisable -Mode Readiness -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot
        $manifest = Get-Content -Raw -LiteralPath $result.ApprovalManifestPath | ConvertFrom-Json

        $manifest.SchemaVersion | Should -Be '4.38'
        $manifest.TenantId | Should -Be $script:TenantId
        $manifest.TargetObjectId | Should -Be $script:TargetObjectId
        @($manifest.TargetObjectIds).Count | Should -Be 1
        @($manifest.TargetObjectIds)[0] | Should -Be $script:TargetObjectId
        $manifest.TargetDisplayName | Should -Be $script:TargetDisplayName
        $manifest.AppId | Should -Be $script:TargetAppId
        $manifest.ApprovedAction | Should -Be 'ReversibleDisable'
        @($manifest.ApprovedActions)[0] | Should -Be 'ReversibleDisable'
        $manifest.ApprovalPhrase | Should -Be $script:DisablePhrase
        $manifest.RollbackReady | Should -BeTrue
        $manifest.LiveMutationApproved | Should -BeTrue
        $manifest.FinalDeleteApproved | Should -BeFalse
    }

    It 'generates the Rev4.39 rollback approval manifest using the current schema' {
        Mock Invoke-NhiRev439LiveRollback {
            param($TenantId, $InventoryPath, $ApprovalManifestPath, $OutputPath, $ConfirmLiveRollbackPhrase, $WhatIf)
            New-FakeLiveSummary -OutputPath $OutputPath -ArtifactName 'rev439-run-summary.json'
        }

        $result = Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action RollbackDisable -Mode WhatIf -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot
        $manifest = Get-Content -Raw -LiteralPath $result.ApprovalManifestPath | ConvertFrom-Json

        $manifest.SchemaVersion | Should -Be '4.39'
        $manifest.TenantId | Should -Be $script:TenantId
        $manifest.TargetObjectId | Should -Be $script:TargetObjectId
        @($manifest.TargetObjectIds).Count | Should -Be 1
        @($manifest.TargetObjectIds)[0] | Should -Be $script:TargetObjectId
        $manifest.TargetDisplayName | Should -Be $script:TargetDisplayName
        $manifest.AppId | Should -Be $script:TargetAppId
        $manifest.ApprovedAction | Should -Be 'ReEnableServicePrincipal'
        @($manifest.ApprovedActions)[0] | Should -Be 'ReEnableServicePrincipal'
        $manifest.ApprovalPhrase | Should -Be $script:RollbackPhrase
        $manifest.LiveRollbackApproved | Should -BeTrue
        $manifest.FinalDeleteApproved | Should -BeFalse
        $manifest.CleanupApproved | Should -BeFalse
    }

    It 'WhatIf mode calls the Rev4.38 child helper with -WhatIf' {
        Mock Invoke-NhiRev438LiveDisable {
            param($TenantId, $InventoryPath, $ApprovalManifestPath, $OutputPath, $ConfirmLiveDisablePhrase, $WhatIf)
            New-FakeLiveSummary -OutputPath $OutputPath -ArtifactName 'rev438-run-summary.json'
        }

        $result = Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action ReversibleDisable -Mode WhatIf -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot
        $summary = Get-Content -Raw -LiteralPath $result.WrapperRunSummaryPath | ConvertFrom-Json

        Assert-MockCalled Invoke-NhiRev438LiveDisable -Times 1 -Exactly -ParameterFilter { $WhatIf }
        $summary.Mode | Should -Be 'WhatIf'
        $summary.WhatIf | Should -BeTrue
    }

    It 'WhatIf mode calls the Rev4.39 child helper with -WhatIf' {
        Mock Invoke-NhiRev439LiveRollback {
            param($TenantId, $InventoryPath, $ApprovalManifestPath, $OutputPath, $ConfirmLiveRollbackPhrase, $WhatIf)
            New-FakeLiveSummary -OutputPath $OutputPath -ArtifactName 'rev439-run-summary.json'
        }

        $result = Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action RollbackDisable -Mode WhatIf -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot
        $summary = Get-Content -Raw -LiteralPath $result.WrapperRunSummaryPath | ConvertFrom-Json

        Assert-MockCalled Invoke-NhiRev439LiveRollback -Times 1 -Exactly -ParameterFilter { $WhatIf }
        $summary.Mode | Should -Be 'WhatIf'
        $summary.WhatIf | Should -BeTrue
    }

    It 'Execute mode requires ApprovalPhrase' {
        { Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action ReversibleDisable -Mode Execute -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot } | Should -Throw
    }

    It 'Execute mode rejects an incorrect approval phrase before child invocation' {
        Mock Invoke-NhiRev438LiveDisable { throw 'Rev4.38 live disable helper must not be called with an invalid approval phrase.' }

        { Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action ReversibleDisable -Mode Execute -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot -ApprovalPhrase 'APPROVE REV4.39 LIVE ROLLBACK AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY' } | Should -Throw
    }

    It 'Rollback execute mode rejects an incorrect approval phrase before child invocation' {
        Mock Invoke-NhiRev439LiveRollback { throw 'Rev4.39 live rollback helper must not be called with an invalid approval phrase.' }

        { Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action RollbackDisable -Mode Execute -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot -ApprovalPhrase 'APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY' } | Should -Throw
    }

    It 'does not contain Update-MgServicePrincipal or Remove-Mg*' {
        $script:CommandCounts.UpdateCount | Should -Be 0
        $script:CommandCounts.RemoveCount | Should -Be 0
        $source = Get-Content -LiteralPath $script:WrapperPath -Raw
        $source | Should -Not -Match 'Update-MgServicePrincipal'
        $source | Should -Not -Match 'Remove-Mg'
    }

    It 'does not implement final delete or cleanup parameter surface' {
        $parameterNames = @($script:WrapperCommand.Parameters.Keys)
        $parameterNames | Should -Contain 'Action'
        $parameterNames | Should -Contain 'Mode'
        $parameterNames | Should -Not -Contain 'FinalDelete'
        $parameterNames | Should -Not -Contain 'Cleanup'
    }

    It 'produces wrapper summary JSON in mocked local mode' {
        Mock Invoke-NhiRev438Readiness {
            param($TenantId, $InventoryPath, $ApprovalManifestPath, $OutputPath, $ConfirmLiveDisablePhrase, $RunId)
            New-FakeReadinessSummary -OutputPath $OutputPath
        }

        $result = Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action ReversibleDisable -Mode Readiness -TargetObjectId $script:TargetObjectId -InventoryPath $script:InventoryPath -OutputRoot $script:RunRoot

        Test-Path -LiteralPath $result.WrapperRunSummaryPath | Should -BeTrue
        $summary = Get-Content -Raw -LiteralPath $result.WrapperRunSummaryPath | ConvertFrom-Json
        $summary.WrapperVersion | Should -Be 'Rev4.40'
        $summary.Action | Should -Be 'ReversibleDisable'
        $summary.Mode | Should -Be 'Readiness'
        $summary.TargetObjectId | Should -Be $script:TargetObjectId
        $summary.ChildRunSummaryPath | Should -Match 'rev438-live-run-readiness\.json$'
        $summary.LiveMutationRequested | Should -BeFalse
        $summary.WhatIf | Should -BeFalse
    }

    It 'Verify mode is read-only and does not call child live mutation helpers' {
        Mock Invoke-NhiRev438Readiness { throw 'Readiness helper must not be called in Verify mode.' }
        Mock Invoke-NhiRev438LiveDisable { throw 'Rev4.38 live disable helper must not be called in Verify mode.' }
        Mock Invoke-NhiRev439LiveRollback { throw 'Rev4.39 live rollback helper must not be called in Verify mode.' }
        Mock Get-MgServicePrincipal {
            param($ServicePrincipalId, $Property)
            if ($ServicePrincipalId -eq $script:TargetObjectId) {
                [pscustomobject]@{
                    Id = $script:TargetObjectId
                    DisplayName = $script:TargetDisplayName
                    AppId = $script:TargetAppId
                    AccountEnabled = $true
                }
            } else {
                [pscustomobject]@{
                    Id = $script:ControlObjectId
                    DisplayName = 'AJEE-LAB-NHI-KEEP-CONTROL'
                    AppId = '0a95508c-8f9f-4f06-8fa5-872ece1ea2c2'
                    AccountEnabled = $true
                }
            }
        }

        $result = Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action RollbackDisable -Mode Verify -TargetObjectId $script:TargetObjectId -OutputRoot $script:RunRoot

        $result.VerificationStatus | Should -Be 'Passed'
        $result.SafetyGatePassed | Should -BeTrue
        Assert-MockCalled Invoke-NhiRev438Readiness -Times 0 -Exactly
        Assert-MockCalled Invoke-NhiRev438LiveDisable -Times 0 -Exactly
        Assert-MockCalled Invoke-NhiRev439LiveRollback -Times 0 -Exactly
        Assert-MockCalled Get-MgServicePrincipal -Times 2 -Exactly
    }

    It 'Closeout mode is local-artifact-only' {
        $null = New-Item -ItemType Directory -Path (Join-Path $script:RunRoot 'closeout') -Force
        $null = Write-TestJson -Path (Join-Path $script:RunRoot 'rev438-run-summary.json') -InputObject ([pscustomobject]@{ OutputArtifactPath = 'C:\temp\IAM\fake\rev438-run-summary.json' })
        $null = Write-TestJson -Path (Join-Path $script:RunRoot 'rev439-run-summary.json') -InputObject ([pscustomobject]@{ OutputArtifactPath = 'C:\temp\IAM\fake\rev439-run-summary.json' })

        Mock Invoke-NhiRev438Readiness { throw 'Readiness helper must not be called in Closeout mode.' }
        Mock Invoke-NhiRev438LiveDisable { throw 'Rev4.38 live disable helper must not be called in Closeout mode.' }
        Mock Invoke-NhiRev439LiveRollback { throw 'Rev4.39 live rollback helper must not be called in Closeout mode.' }
        Mock Get-MgServicePrincipal { throw 'Graph must not be called in Closeout mode.' }

        $result = Start-NhiSingleObjectLifecycle -TenantId $script:TenantId -Action RollbackDisable -Mode Closeout -TargetObjectId $script:TargetObjectId -OutputRoot $script:RunRoot

        $result.SafetyGatePassed | Should -BeTrue
        $result.ChildRunSummaryPath | Should -Match 'rev439-run-summary\.json$'
        Test-Path -LiteralPath $result.WrapperRunSummaryPath | Should -BeTrue
        Assert-MockCalled Invoke-NhiRev438Readiness -Times 0 -Exactly
        Assert-MockCalled Invoke-NhiRev438LiveDisable -Times 0 -Exactly
        Assert-MockCalled Invoke-NhiRev439LiveRollback -Times 0 -Exactly
        Assert-MockCalled Get-MgServicePrincipal -Times 0 -Exactly
    }
}
