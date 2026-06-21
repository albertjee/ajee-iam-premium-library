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
        CleanupCount = @($commands | Where-Object { $_.GetCommandName() -match 'Cleanup' }).Count
        FinalDeleteCount = @($commands | Where-Object { $_.GetCommandName() -match 'FinalDelete' }).Count
        LiveInvokeCount = @($commands | Where-Object { $_.GetCommandName() -in @('Invoke-NhiDisable', 'Invoke-Rev438LabLiveReversibleDisable', 'Invoke-Rev439LabLiveRollback') }).Count
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

function script:New-TestServicePrincipal {
    param(
        [Parameter(Mandatory)]
        [string]$ObjectId,

        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter()]
        [bool]$AccountEnabled = $true,

        [Parameter()]
        [string]$OwnerTenantId = '11111111-2222-3333-4444-555555555555',

        [Parameter()]
        [string]$VerifiedPublisherName = 'Contoso Labs',

        [Parameter()]
        [string]$LastObservedUtc = '2025-01-01T00:00:00Z'
    )

    [pscustomobject]@{
        Id = $ObjectId
        DisplayName = $DisplayName
        AppId = $AppId
        AccountEnabled = $AccountEnabled
        ServicePrincipalType = 'Application'
        PublisherName = ''
        AppOwnerOrganizationId = $OwnerTenantId
        Tags = @()
        SignInActivity = [pscustomobject]@{
            LastSuccessfulSignInDateTime = $LastObservedUtc
        }
        VerifiedPublisher = [pscustomobject]@{
            displayName = $VerifiedPublisherName
        }
    }
}

Describe 'Rev4.41 batch lifecycle planning' {
    BeforeAll {
        $script:WrapperPath = Join-Path $PSScriptRoot '..\tools\Start-NhiBatchLifecyclePlanning.ps1'
        . $script:WrapperPath -TenantId 'contoso-test' -Mode Readiness -TargetObjectIds @('sp-dot-source') -OutputRoot (Join-Path $TestDrive 'dot-source')
        $script:CommandCounts = Get-FileCommandCounts -Path $script:WrapperPath
        $script:WrapperCommand = Get-Command Start-NhiBatchLifecyclePlanning
        $script:TargetIds = @(
            'sp-eligible-1',
            'sp-eligible-2',
            'sp-eligible-3',
            'sp-platform-1',
            'sp-ownerless-1'
        )
        $script:EligibleSp1 = New-TestServicePrincipal -ObjectId 'sp-eligible-1' -DisplayName 'Eligible One' -AppId 'app-eligible-1' -LastObservedUtc '2024-01-01T00:00:00Z'
        $script:EligibleSp2 = New-TestServicePrincipal -ObjectId 'sp-eligible-2' -DisplayName 'Eligible Two' -AppId 'app-eligible-2' -LastObservedUtc '2024-01-01T00:00:00Z'
        $script:EligibleSp3 = New-TestServicePrincipal -ObjectId 'sp-eligible-3' -DisplayName 'Eligible Three' -AppId 'app-eligible-3' -LastObservedUtc '2024-01-01T00:00:00Z'
        $script:PlatformSp = New-TestServicePrincipal -ObjectId 'sp-platform-1' -DisplayName 'Microsoft Graph PowerShell' -AppId '14d82eec-204b-4c2f-b7e8-296a70dab67e' -OwnerTenantId '72f988bf-86f1-41af-91ab-2d7cd011db47' -VerifiedPublisherName 'Microsoft Corporation' -LastObservedUtc '2026-06-01T00:00:00Z'
        $script:OwnerlessSp = New-TestServicePrincipal -ObjectId 'sp-ownerless-1' -DisplayName 'Ownerless Lab NHI' -AppId 'app-ownerless-1' -LastObservedUtc '2024-01-01T00:00:00Z'
        $script:UnknownTargetId = 'sp-unknown-1'
    }

    BeforeEach {
        $script:RunRoot = Join-Path $TestDrive ('rev441-' + [guid]::NewGuid().ToString('N'))
    }

    AfterAll {
        Remove-Item -LiteralPath Function:\Get-MgServicePrincipal -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath Function:\Get-MgServicePrincipalOwner -ErrorAction SilentlyContinue
    }

    BeforeEach {
        Mock Get-MgServicePrincipal {
            param($ServicePrincipalId, $Property)
            switch ($ServicePrincipalId) {
                'sp-eligible-1' { return $script:EligibleSp1 }
                'sp-eligible-2' { return $script:EligibleSp2 }
                'sp-eligible-3' { return $script:EligibleSp3 }
                'sp-platform-1' { return $script:PlatformSp }
                'sp-ownerless-1' { return $script:OwnerlessSp }
                'sp-unknown-1' { throw 'Graph unreachable' }
                default { throw "Unexpected service principal id: $ServicePrincipalId" }
            }
        }

        Mock Get-MgServicePrincipalOwner {
            param($ServicePrincipalId, $All)
            switch ($ServicePrincipalId) {
                'sp-eligible-1' { return @([pscustomobject]@{ Id = 'owner-a' }) }
                'sp-eligible-2' { return @([pscustomobject]@{ Id = 'owner-b' }, [pscustomobject]@{ Id = 'owner-c' }) }
                'sp-eligible-3' { return @([pscustomobject]@{ Id = 'owner-d' }) }
                'sp-platform-1' { return @([pscustomobject]@{ Id = 'microsoft-owner' }) }
                'sp-ownerless-1' { return @() }
                default { return @() }
            }
        }
    }

    It 'exists and exposes only planning modes' {
        Test-Path -LiteralPath $script:WrapperPath | Should -BeTrue
        (Get-ValidateSetValues -ParameterMetadata $script:WrapperCommand.Parameters['Mode']) | Should -Be @('Readiness', 'WhatIf', 'Verify', 'Closeout')
    }

    It 'rejects unsupported modes' {
        { Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode 'Unsupported' -TargetObjectIds @('sp-eligible-1') -OutputRoot $script:RunRoot } | Should -Throw
    }

    It 'writes the batch manifest, batch summary, and per-object artifact folders in Readiness mode' {
        $runRoot = Join-Path $TestDrive ('rev441-' + [guid]::NewGuid().ToString('N'))
        $result = Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode Readiness -TargetObjectIds $script:TargetIds -MaxObjectsPerWave 2 -OutputRoot $runRoot
        $manifest = Get-Content -LiteralPath $result.BatchManifestPath -Raw | ConvertFrom-Json

        $result.WrapperVersion | Should -Be 'Rev4.41'
        $result.Mode | Should -Be 'Readiness'
        $result.WhatIf | Should -BeFalse
        $result.TotalTargetCount | Should -Be 5
        $result.EligibleTargetCount | Should -Be 3
        $result.BlockedTargetCount | Should -Be 2
        $result.WaveCount | Should -Be 2
        $result.SafetyGatePassed | Should -BeFalse
        $manifest.SchemaVersion | Should -Be 'Rev4.41-BatchPlanning'
        $manifest.ApprovedAction | Should -Be 'ReversibleDisable'
        $manifest.FinalDeleteApproved | Should -BeFalse
        $manifest.CleanupApproved | Should -BeFalse
        @($manifest.Targets).Count | Should -Be 5
        @($manifest.Waves).Count | Should -Be 2

        foreach ($target in @($result.Targets)) {
            Test-Path -LiteralPath $target.ArtifactFolder | Should -BeTrue
            Test-Path -LiteralPath $target.TargetSummaryPath | Should -BeTrue
            $target.DisplayName | Should -Not -BeNullOrEmpty
            $target.ObjectType | Should -Be 'ServicePrincipal'
            $target.ServicePrincipalObjectId | Should -Not -BeNullOrEmpty
            $target.AppId | Should -Not -BeNullOrEmpty
            $target.RiskReason | Should -Not -BeNullOrEmpty
            $target.OwnerStatus | Should -Not -BeNullOrEmpty
            $target.LastObservedActivity | Should -Not -BeNullOrEmpty
            $target.ApprovedAction | Should -Be 'ReversibleDisable'
        }

        ($result.Targets | Where-Object { $_.ServicePrincipalObjectId -eq 'sp-platform-1' }).MutationEligible | Should -BeFalse
        ($result.Targets | Where-Object { $_.ServicePrincipalObjectId -eq 'sp-ownerless-1' }).MutationEligible | Should -BeFalse
        ($result.Targets | Where-Object { $_.ServicePrincipalObjectId -eq 'sp-eligible-1' }).WaveNumber | Should -Be 1
        ($result.Targets | Where-Object { $_.ServicePrincipalObjectId -eq 'sp-eligible-3' }).WaveNumber | Should -Be 1
        ($result.Targets | Where-Object { $_.ServicePrincipalObjectId -eq 'sp-eligible-2' }).WaveNumber | Should -Be 2
    }

    It 'WhatIf mode explicitly records WhatIf = true without tenant mutation' {
        $runRoot = Join-Path $TestDrive ('rev441-' + [guid]::NewGuid().ToString('N'))
        $result = Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode WhatIf -TargetObjectIds @('sp-eligible-1', 'sp-eligible-2') -MaxObjectsPerWave 1 -OutputRoot $runRoot
        $manifest = Get-Content -LiteralPath $result.BatchManifestPath -Raw | ConvertFrom-Json

        $result.WhatIf | Should -BeTrue
        $result.Mode | Should -Be 'WhatIf'
        $manifest.WhatIf | Should -BeTrue
        ($result.Targets | Where-Object { $_.ServicePrincipalObjectId -eq 'sp-eligible-1' }).WhatIfResult | Should -Be 'Simulated'
        ($result.Targets | Where-Object { $_.ServicePrincipalObjectId -eq 'sp-eligible-2' }).WaveNumber | Should -Be 2
    }

    It 'blocks Microsoft first-party platform identities from mutation eligibility' {
        $runRoot = Join-Path $TestDrive ('rev441-' + [guid]::NewGuid().ToString('N'))
        $result = Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode Readiness -TargetObjectIds @('sp-platform-1') -OutputRoot $runRoot
        $target = $result.Targets | Select-Object -First 1

        $target.MutationEligible | Should -BeFalse
        $target.RiskReason | Should -Match 'Platform identity is blocked'
        $target.RiskReason | Should -Match 'Microsoft'
        $target.ValidationStatus | Should -Be 'Blocked'
    }

    It 'blocks ownerless or unknown activity targets from mutation eligibility' {
        $runRoot = Join-Path $TestDrive ('rev441-' + [guid]::NewGuid().ToString('N'))
        $result = Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode Readiness -TargetObjectIds @('sp-ownerless-1') -OutputRoot $runRoot
        $target = $result.Targets | Select-Object -First 1

        $target.MutationEligible | Should -BeFalse
        $target.OwnerStatus | Should -Be 'NoOwners'
        $target.RiskReason | Should -Match 'Owner status is NoOwners'
    }

    It 'rejects unknown targets when Graph read fails' {
        $runRoot = Join-Path $TestDrive ('rev441-' + [guid]::NewGuid().ToString('N'))
        $result = Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode Readiness -TargetObjectIds @('sp-unknown-1') -OutputRoot $runRoot
        $target = $result.Targets | Select-Object -First 1

        $target.MutationEligible | Should -BeFalse
        $target.RiskReason | Should -Match 'Graph read failed'
        $target.ValidationStatus | Should -Be 'Blocked'
    }

    It 'Verify mode remains read-only and still produces local verification output' {
        $runRoot = Join-Path $TestDrive ('rev441-' + [guid]::NewGuid().ToString('N'))
        $result = Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode Verify -TargetObjectIds @('sp-eligible-1') -OutputRoot $runRoot

        $result.ReadOnlyGraphVerified | Should -BeTrue
        $result.WhatIf | Should -BeFalse
        $result.Targets.Count | Should -Be 1
        Assert-MockCalled Get-MgServicePrincipal -Times 1 -Exactly
        Assert-MockCalled Get-MgServicePrincipalOwner -Times 1 -Exactly
        $source = Get-Content -LiteralPath $script:WrapperPath -Raw
        $source | Should -Not -Match 'Update-MgServicePrincipal'
        $source | Should -Not -Match 'Remove-Mg'
    }

    It 'Closeout mode fails closed when the run root does not already exist' {
        $missingRoot = Join-Path $TestDrive ('rev441-missing-' + [guid]::NewGuid().ToString('N'))
        { Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode Closeout -TargetObjectIds @('sp-eligible-1') -OutputRoot $missingRoot } | Should -Throw
        Test-Path -LiteralPath $missingRoot | Should -BeFalse
    }

    It 'Closeout mode summarizes only pre-existing local artifacts' {
        $closeoutRoot = Join-Path $TestDrive ('rev441-closeout-' + [guid]::NewGuid().ToString('N'))
        $closeoutPath = Join-Path $closeoutRoot 'closeout'
        $targetsPath = Join-Path $closeoutPath 'targets'
        $targetFolder = Join-Path $targetsPath 'target-01-speligibl'
        $null = New-Item -ItemType Directory -Path $targetFolder -Force
        $null = Write-TestJson -Path (Join-Path $closeoutPath 'rev441-batch-manifest.json') -InputObject ([pscustomobject]@{ BatchId = 'closeout-batch'; Targets = @() })
        $null = Write-TestJson -Path (Join-Path $closeoutPath 'rev441-batch-summary.json') -InputObject ([pscustomobject]@{ BatchId = 'closeout-batch' })
        $null = Write-TestJson -Path (Join-Path $targetFolder 'rev441-target-summary.json') -InputObject ([pscustomobject]@{ ServicePrincipalObjectId = 'sp-eligible-1' })

        $result = Start-NhiBatchLifecyclePlanning -TenantId 'contoso-test' -Mode Closeout -TargetObjectIds @('sp-eligible-1') -OutputRoot $closeoutRoot -BatchId 'closeout-batch'

        $result.CloseoutStatus | Should -Be 'Collected'
        $result.ArtifactCount | Should -BeGreaterThan 0
        Test-Path -LiteralPath $result.CloseoutSummaryPath | Should -BeTrue
    }

    It 'does not contain Update-MgServicePrincipal, Remove-Mg*, cleanup, or final-delete commands' {
        $script:CommandCounts.UpdateCount | Should -Be 0
        $script:CommandCounts.RemoveCount | Should -Be 0
        $script:CommandCounts.CleanupCount | Should -Be 0
        $script:CommandCounts.FinalDeleteCount | Should -Be 0
        $script:CommandCounts.LiveInvokeCount | Should -Be 0
        $source = Get-Content -LiteralPath $script:WrapperPath -Raw
        $source | Should -Not -Match 'Update-MgServicePrincipal'
        $source | Should -Not -Match 'Remove-Mg'
    }
}
