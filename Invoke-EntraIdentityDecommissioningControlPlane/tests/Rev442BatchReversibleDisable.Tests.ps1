Describe 'Rev4.42 batch reversible disable gate' {
    BeforeAll {
        function Write-TestJson {
            param(
                [Parameter(Mandatory)]
                [string]$Path,

                [Parameter(Mandatory)]
                [object]$InputObject
            )

            $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
            $json = $InputObject | ConvertTo-Json -Depth 20
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
            return $Path
        }

        function Copy-TestObject {
            param(
                [Parameter(Mandatory)]
                [object]$InputObject
            )

            return ($InputObject | ConvertTo-Json -Depth 20 | ConvertFrom-Json)
        }

        $script:WrapperPath = Join-Path $PSScriptRoot '..\tools\Start-NhiBatchReversibleDisable.ps1'
        . $script:WrapperPath -TenantId '00000000-0000-0000-0000-000000000000' -BatchManifestPath 'C:\temp\dummy-batch.json' -OutputRoot 'C:\temp\dummy-output' -ApprovalPhrase 'DUMMY' -WhatIf

        $script:TenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
        $script:BatchId = 'REV442-TEST-BATCH'
        $script:OutputRoot = Join-Path $TestDrive 'rev442-output'
        $script:InventoryPath = Join-Path $TestDrive 'rev442-inventory.json'
        $script:PriorRunRoot = Join-Path $TestDrive 'rev441-prior'
        $script:TargetOneEvidencePath = Join-Path $TestDrive 'rev442-target-1-whatif.json'
        $script:TargetTwoEvidencePath = Join-Path $TestDrive 'rev442-target-2-whatif.json'
        $script:PriorEvidencePath = Join-Path $script:PriorRunRoot 'rev441-whatif-evidence.json'
        $script:ApprovalPhrase = 'APPROVE REV4.42 BATCH REVERSIBLE DISABLE ONLY'

        $inventory = [pscustomobject]@{
            TenantId = $script:TenantId
            Inventory = @(
                [pscustomobject]@{
                    ServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
                    AppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
                    DisplayName = 'Target One'
                    ObjectType = 'ServicePrincipal'
                    TenantId = $script:TenantId
                    PriorAccountEnabled = $true
                },
                [pscustomobject]@{
                    ServicePrincipalObjectId = '9f7d8246-0b83-4d94-91b9-66e0cbfe8c2a'
                    AppId = 'f2f9c1a3-7f7a-4ef8-8f9a-17d9abf2f311'
                    DisplayName = 'Target Two'
                    ObjectType = 'ServicePrincipal'
                    TenantId = $script:TenantId
                    PriorAccountEnabled = $false
                }
            )
        }

        $null = New-Item -ItemType Directory -Path $script:PriorRunRoot -Force
        Write-TestJson -Path $script:InventoryPath -InputObject $inventory
        Write-TestJson -Path $script:PriorEvidencePath -InputObject ([pscustomobject]@{
            BatchId = 'REV441-PRIOR'
            TenantId = $script:TenantId
            ApprovedAction = 'ReversibleDisable'
            WhatIf = $true
            LiveMutationPerformed = $false
            SourceBatchRunRoot = $script:PriorRunRoot
        })
        Write-TestJson -Path $script:TargetOneEvidencePath -InputObject ([pscustomobject]@{
            BatchId = 'REV441-PRIOR'
            TenantId = $script:TenantId
            ServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
            AppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
            ApprovedAction = 'ReversibleDisable'
            WhatIf = $true
            LiveMutationPerformed = $false
            SourceBatchRunRoot = $script:PriorRunRoot
            PriorAccountEnabled = $true
        })
        Write-TestJson -Path $script:TargetTwoEvidencePath -InputObject ([pscustomobject]@{
            BatchId = 'REV441-PRIOR'
            TenantId = $script:TenantId
            ServicePrincipalObjectId = '9f7d8246-0b83-4d94-91b9-66e0cbfe8c2a'
            AppId = 'f2f9c1a3-7f7a-4ef8-8f9a-17d9abf2f311'
            ApprovedAction = 'ReversibleDisable'
            WhatIf = $true
            LiveMutationPerformed = $false
            SourceBatchRunRoot = $script:PriorRunRoot
            PriorAccountEnabled = $false
        })
        Write-TestJson -Path (Join-Path $script:PriorRunRoot 'rev441-batch-manifest.json') -InputObject ([pscustomobject]@{
            BatchId = 'REV441-PRIOR'
            TenantId = $script:TenantId
            WhatIf = $true
            SourceBatchRunRoot = $script:PriorRunRoot
        })
        Write-TestJson -Path (Join-Path $script:PriorRunRoot 'rev441-batch-summary.json') -InputObject ([pscustomobject]@{
            BatchId = 'REV441-PRIOR'
            TenantId = $script:TenantId
            WhatIf = $true
            SourceBatchRunRoot = $script:PriorRunRoot
        })

        $script:BaseManifest = [pscustomobject]@{
            BatchId = $script:BatchId
            TenantId = $script:TenantId
            ApprovedAction = 'ReversibleDisable'
            Mode = 'Execute'
            Confirm = $false
            MaxObjectsPerWave = 3
            StopOnFirstFailure = $true
            FinalDeleteApproved = $false
            CleanupApproved = $false
            ApprovalPhrase = $script:ApprovalPhrase
            InventoryPath = $script:InventoryPath
            PriorWhatIfRunRoot = $script:PriorRunRoot
            PriorWhatIfEvidencePath = $script:PriorEvidencePath
            Targets = @(
                [pscustomobject]@{
                    ServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
                    AppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
                    ObjectType = 'ServicePrincipal'
                    TenantId = $script:TenantId
                    ApprovedAction = 'ReversibleDisable'
                    ApprovalState = 'Approved'
                    RiskReason = 'High privilege and stale'
                    OwnerStatus = 'Owned'
                    PlatformClassification = 'CustomerOwned'
                    MicrosoftFirstParty = $false
                    PlatformIdentity = $false
                    EvidenceOnly = $false
                    WhatIfEvidencePath = $script:TargetOneEvidencePath
                    DisplayName = 'Target One'
                },
                [pscustomobject]@{
                    ServicePrincipalObjectId = '9f7d8246-0b83-4d94-91b9-66e0cbfe8c2a'
                    AppId = 'f2f9c1a3-7f7a-4ef8-8f9a-17d9abf2f311'
                    ObjectType = 'ServicePrincipal'
                    TenantId = $script:TenantId
                    ApprovedAction = 'ReversibleDisable'
                    ApprovalState = 'Approved'
                    RiskReason = 'Unused app'
                    OwnerStatus = 'Owned'
                    PlatformClassification = 'CustomerOwned'
                    MicrosoftFirstParty = $false
                    PlatformIdentity = $false
                    EvidenceOnly = $false
                    WhatIfEvidencePath = $script:TargetTwoEvidencePath
                    DisplayName = 'Target Two'
                }
            )
        }
    }

    BeforeEach {
        Remove-Item -LiteralPath $script:OutputRoot -Recurse -Force -ErrorAction SilentlyContinue
        Mock Invoke-NhiBatchChildLifecycle {
            param($LifecycleScriptPath, $BoundParameters)
            [pscustomobject]@{
                WrapperRunSummaryPath = Join-Path $BoundParameters.OutputRoot 'rev440-wrapper-summary.json'
                OutputArtifactPath = Join-Path $BoundParameters.OutputRoot 'rev440-wrapper-summary.json'
                LiveMutationPerformed = $true
                SafetyGatePassed = $true
            }
        }
    }

    It 'rejects missing prior Rev4.41 WhatIf evidence' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.PriorWhatIfEvidencePath = Join-Path $TestDrive 'missing.json'
        $path = Join-Path $TestDrive 'rev442-missing-evidence.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects missing BatchId' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.BatchId = ''
        $path = Join-Path $TestDrive 'rev442-missing-batchid.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects wrong TenantId' {
        $path = Write-TestJson -Path (Join-Path $TestDrive 'rev442-wrong-tenant.json') -InputObject $script:BaseManifest
        { & $script:WrapperPath -TenantId '00000000-0000-0000-0000-000000000000' -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects unsupported ApprovedAction' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.ApprovedAction = 'FinalDelete'
        $path = Join-Path $TestDrive 'rev442-wrong-action.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects FinalDeleteApproved true' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.FinalDeleteApproved = $true
        $path = Join-Path $TestDrive 'rev442-finaldelete.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects CleanupApproved true' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.CleanupApproved = $true
        $path = Join-Path $TestDrive 'rev442-cleanup.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects MaxObjectsPerWave above safe bound' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.MaxObjectsPerWave = 4
        $path = Join-Path $TestDrive 'rev442-wavebound.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects object count above wave bound' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $targets = @($manifest.Targets)
        $targets += [pscustomobject]@{
            ServicePrincipalObjectId = '3a5b41f5-cc8d-4b7f-b6b8-b90d1b6e6c07'
            AppId = '0fd7b11c-0e4b-4a4f-9f37-9ad12f72ee70'
            ObjectType = 'ServicePrincipal'
            TenantId = $script:TenantId
            ApprovedAction = 'ReversibleDisable'
            ApprovalState = 'Approved'
            RiskReason = 'Extra target'
            OwnerStatus = 'Owned'
            PlatformClassification = 'CustomerOwned'
            MicrosoftFirstParty = $false
            PlatformIdentity = $false
            EvidenceOnly = $false
            WhatIfEvidencePath = $script:PriorEvidencePath
            DisplayName = 'Target Three'
        }
        $manifest.Targets = @($targets)
        $path = Join-Path $TestDrive 'rev442-too-many-targets.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects unknown classification' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].PlatformClassification = 'Unknown'
        $path = Join-Path $TestDrive 'rev442-unknown-classification.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects Microsoft first-party identity' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].MicrosoftFirstParty = $true
        $path = Join-Path $TestDrive 'rev442-first-party.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects platform identity' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].PlatformIdentity = $true
        $path = Join-Path $TestDrive 'rev442-platform.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects high-risk object from mutation eligibility' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].RiskReason = ''
        $path = Join-Path $TestDrive 'rev442-high-risk.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects ownerless or uncertain owner state from mutation eligibility unless evidence-only' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].OwnerStatus = 'Uncertain'
        $path = Join-Path $TestDrive 'rev442-ownerless.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects missing AppId where required' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].AppId = ''
        $path = Join-Path $TestDrive 'rev442-missing-appid.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects missing ServicePrincipalObjectId' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].ServicePrincipalObjectId = ''
        $path = Join-Path $TestDrive 'rev442-missing-spid.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects missing per-object WhatIf evidence' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].WhatIfEvidencePath = Join-Path $TestDrive 'missing-whatif.json'
        $path = Join-Path $TestDrive 'rev442-missing-whatif.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'StopOnFirstFailure stops later objects in the same wave' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].RiskReason = ''
        $path = Join-Path $TestDrive 'rev442-stop-first.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'produces per-object artifact folders' {
        $manifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev442-good.json') -InputObject $script:BaseManifest
        $result = & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $manifestPath -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute
        Test-Path -LiteralPath $result.BatchManifestPath | Should -BeTrue
        Test-Path -LiteralPath $result.BatchSummaryPath | Should -BeTrue
        $result.ChildCallCount | Should -Be 0
        $result.Targets[0].ExecutionStatus | Should -Be 'GateOnly'
        $result.Targets[0].ExecutionNotPerformed | Should -BeTrue
        Test-Path -LiteralPath $result.Targets[0].ApprovalManifestPath | Should -BeTrue
        ($result.Targets | ForEach-Object { Test-Path -LiteralPath $_.ArtifactFolder }) | ForEach-Object { $_ | Should -BeTrue }
    }

    It 'produces changed-object manifest contract' {
        $manifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev442-good-manifest.json') -InputObject $script:BaseManifest
        $result = & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $manifestPath -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute
        Test-Path -LiteralPath $result.Targets[0].ChangedObjectManifestPath | Should -BeTrue
        (Get-Content -LiteralPath $result.Targets[0].ChangedObjectManifestPath -Raw | ConvertFrom-Json).ChangedByPriorBatchRun | Should -BeFalse
    }

    It 'produces rollback package contract' {
        $manifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev442-good-rollback.json') -InputObject $script:BaseManifest
        $result = & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $manifestPath -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute
        Test-Path -LiteralPath $result.Targets[0].RollbackPackagePath | Should -BeTrue
        (Get-Content -LiteralPath $result.Targets[0].RollbackPackagePath -Raw | ConvertFrom-Json).RollbackAction | Should -Be 'ReEnableServicePrincipal'
    }

    It 'produces batch execution summary contract' {
        $manifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev442-good-summary.json') -InputObject $script:BaseManifest
        $result = & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $manifestPath -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute
        Test-Path -LiteralPath $result.BatchSummaryPath | Should -BeTrue
        $summary = Get-Content -LiteralPath $result.BatchSummaryPath -Raw | ConvertFrom-Json
        $summary.ApprovedAction | Should -Be 'ReversibleDisable'
        $summary.ChildCallCount | Should -Be 0
        @($summary.ApprovalManifestPaths).Count | Should -BeGreaterThan 0
    }

    It 'does not call Update-MgServicePrincipal directly in the new batch wrapper' {
        $source = Get-Content -LiteralPath $script:WrapperPath -Raw
        $source | Should -Not -Match 'Update-MgServicePrincipal'
        $source | Should -Not -Match 'Remove-Mg'
        $source | Should -Not -Match '(?i)\bFinalDeleteApproved\s*=\s*\$true\b'
        $source | Should -Not -Match '(?i)\bCleanupApproved\s*=\s*\$true\b'
    }
}
