Describe 'Rev4.43 batch rollback gate' {
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

        $script:WrapperPath = Join-Path $PSScriptRoot '..\tools\Start-NhiBatchRollback.ps1'
        . $script:WrapperPath -TenantId '00000000-0000-0000-0000-000000000000' -BatchManifestPath 'C:\temp\dummy-batch.json' -OutputRoot 'C:\temp\dummy-output' -ApprovalPhrase 'DUMMY' -WhatIf

        $script:TenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
        $script:BatchId = 'REV443-TEST-BATCH'
        $script:OutputRoot = Join-Path $TestDrive 'rev443-output'
        $script:InventoryPath = Join-Path $TestDrive 'rev443-inventory.json'
        $script:SourceBatchRoot = Join-Path $TestDrive 'rev442-source'
        $script:ApprovalPhrase = 'APPROVE REV4.43 BATCH ROLLBACK ONLY'

        $null = New-Item -ItemType Directory -Path $script:SourceBatchRoot -Force
        Write-TestJson -Path $script:InventoryPath -InputObject ([pscustomobject]@{
            TenantId = $script:TenantId
            Inventory = @(
                [pscustomobject]@{
                    ServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
                    AppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
                    DisplayName = 'Target One'
                    ObjectType = 'ServicePrincipal'
                    TenantId = $script:TenantId
                },
                [pscustomobject]@{
                    ServicePrincipalObjectId = '9f7d8246-0b83-4d94-91b9-66e0cbfe8c2a'
                    AppId = 'f2f9c1a3-7f7a-4ef8-8f9a-17d9abf2f311'
                    DisplayName = 'Target Two'
                    ObjectType = 'ServicePrincipal'
                    TenantId = $script:TenantId
                }
            )
        })

        Write-TestJson -Path (Join-Path $script:SourceBatchRoot 'rev442-batch-manifest.json') -InputObject ([pscustomobject]@{
            BatchId = 'REV442-PRIOR'
            TenantId = $script:TenantId
        })
        Write-TestJson -Path (Join-Path $script:SourceBatchRoot 'rev442-batch-execution-summary.json') -InputObject ([pscustomobject]@{
            BatchId = 'REV442-PRIOR'
            TenantId = $script:TenantId
        })

        $script:ChangedManifestOne = Join-Path $TestDrive 'rev443-changed-1.json'
        $script:RollbackPackageOne = Join-Path $TestDrive 'rev443-rollback-1.json'
        $script:ChangedManifestTwo = Join-Path $TestDrive 'rev443-changed-2.json'
        $script:RollbackPackageTwo = Join-Path $TestDrive 'rev443-rollback-2.json'

        Write-TestJson -Path $script:ChangedManifestOne -InputObject ([pscustomobject]@{
            BatchId = 'REV442-PRIOR'
            TenantId = $script:TenantId
            ServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
            AppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
            ApprovedAction = 'ReversibleDisable'
            ChangedByPriorBatchRun = $true
            SourceBatchRunRoot = $script:SourceBatchRoot
            PriorAccountEnabled = $true
            OutputArtifactPath = $script:ChangedManifestOne
        })
        Write-TestJson -Path $script:RollbackPackageOne -InputObject ([pscustomobject]@{
            BatchId = 'REV442-PRIOR'
            TenantId = $script:TenantId
            ServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
            AppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
            PriorAccountEnabled = $true
            RollbackAction = 'ReEnableServicePrincipal'
            OutputArtifactPath = $script:RollbackPackageOne
        })
        Write-TestJson -Path $script:ChangedManifestTwo -InputObject ([pscustomobject]@{
            BatchId = 'REV442-PRIOR'
            TenantId = $script:TenantId
            ServicePrincipalObjectId = '9f7d8246-0b83-4d94-91b9-66e0cbfe8c2a'
            AppId = 'f2f9c1a3-7f7a-4ef8-8f9a-17d9abf2f311'
            ApprovedAction = 'ReversibleDisable'
            ChangedByPriorBatchRun = $true
            SourceBatchRunRoot = $script:SourceBatchRoot
            PriorAccountEnabled = $false
            OutputArtifactPath = $script:ChangedManifestTwo
        })
        Write-TestJson -Path $script:RollbackPackageTwo -InputObject ([pscustomobject]@{
            BatchId = 'REV442-PRIOR'
            TenantId = $script:TenantId
            ServicePrincipalObjectId = '9f7d8246-0b83-4d94-91b9-66e0cbfe8c2a'
            AppId = 'f2f9c1a3-7f7a-4ef8-8f9a-17d9abf2f311'
            PriorAccountEnabled = $false
            RollbackAction = 'DisableServicePrincipal'
            OutputArtifactPath = $script:RollbackPackageTwo
        })

        $script:BaseManifest = [pscustomobject]@{
            BatchId = $script:BatchId
            TenantId = $script:TenantId
            ApprovedAction = 'RollbackDisable'
            Mode = 'Execute'
            Confirm = $false
            MaxObjectsPerWave = 3
            StopOnFirstFailure = $true
            FinalDeleteApproved = $false
            CleanupApproved = $false
            ApprovalPhrase = $script:ApprovalPhrase
            SourceBatchRunRoot = $script:SourceBatchRoot
            InventoryPath = $script:InventoryPath
            Targets = @(
                [pscustomobject]@{
                    ServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
                    AppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
                    ObjectType = 'ServicePrincipal'
                    TenantId = $script:TenantId
                    ChangedObjectManifestPath = $script:ChangedManifestOne
                    RollbackPackagePath = $script:RollbackPackageOne
                },
                [pscustomobject]@{
                    ServicePrincipalObjectId = '9f7d8246-0b83-4d94-91b9-66e0cbfe8c2a'
                    AppId = 'f2f9c1a3-7f7a-4ef8-8f9a-17d9abf2f311'
                    ObjectType = 'ServicePrincipal'
                    TenantId = $script:TenantId
                    ChangedObjectManifestPath = $script:ChangedManifestTwo
                    RollbackPackagePath = $script:RollbackPackageTwo
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

    It 'rejects missing prior batch run root' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.SourceBatchRunRoot = Join-Path $TestDrive 'missing-root'
        $path = Join-Path $TestDrive 'rev443-missing-root.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects missing changed-object manifest' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].ChangedObjectManifestPath = Join-Path $TestDrive 'missing-changed.json'
        $path = Join-Path $TestDrive 'rev443-missing-changed.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects missing rollback package' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].RollbackPackagePath = Join-Path $TestDrive 'missing-rollback.json'
        $path = Join-Path $TestDrive 'rev443-missing-rollback.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects manual arbitrary rollback list' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets = @(
            [pscustomobject]@{
                ServicePrincipalObjectId = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'
                AppId = 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'
                ObjectType = 'ServicePrincipal'
                TenantId = $script:TenantId
                ChangedObjectManifestPath = $script:ChangedManifestOne
                RollbackPackagePath = $script:RollbackPackageOne
            }
        )
        $path = Join-Path $TestDrive 'rev443-arbitrary-list.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects TenantId mismatch' {
        $path = Write-TestJson -Path (Join-Path $TestDrive 'rev443-tenant.json') -InputObject $script:BaseManifest
        { & $script:WrapperPath -TenantId '00000000-0000-0000-0000-000000000000' -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects object identity mismatch' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].ServicePrincipalObjectId = '11111111-1111-1111-1111-111111111111'
        $path = Join-Path $TestDrive 'rev443-identity.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects AppId mismatch' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].AppId = '11111111-1111-1111-1111-111111111111'
        $path = Join-Path $TestDrive 'rev443-appid.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'rejects object not marked as changed by prior batch run' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $changed = Get-Content -LiteralPath $script:ChangedManifestOne -Raw | ConvertFrom-Json
        $changed.ChangedByPriorBatchRun = $false
        $badChangedManifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev443-changed-1-bad.json') -InputObject $changed
        $manifest.Targets[0].ChangedObjectManifestPath = $badChangedManifestPath
        $path = Join-Path $TestDrive 'rev443-not-changed.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'Rollback eligibility only includes objects changed by prior approved batch run' {
        $manifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev443-good.json') -InputObject $script:BaseManifest
        $result = & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $manifestPath -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute
        $result.Targets.Count | Should -Be 2
        $result.Targets[0].SafetyGatePassed | Should -BeTrue
        $result.Targets[0].ChangedByPriorBatchRun | Should -BeTrue
    }

    It 'StopOnFirstFailure stops later rollback items in the same wave' {
        $manifest = Copy-TestObject -InputObject $script:BaseManifest
        $manifest.Targets[0].RollbackPackagePath = Join-Path $TestDrive 'missing-rollback.json'
        $path = Join-Path $TestDrive 'rev443-stop-first.json'
        Write-TestJson -Path $path -InputObject $manifest
        { & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $path -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute } | Should -Throw
    }

    It 'Produces per-object rollback validation record' {
        $manifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev443-good-validation.json') -InputObject $script:BaseManifest
        $result = & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $manifestPath -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute
        Test-Path -LiteralPath (Join-Path $result.Targets[0].ArtifactFolder 'rev443-rollback-validation.json') | Should -BeTrue
        $result.ChildCallCount | Should -Be 0
        $result.Targets[0].ExecutionStatus | Should -Be 'GateOnly'
        $result.Targets[0].ExecutionNotPerformed | Should -BeTrue
        Test-Path -LiteralPath $result.Targets[0].ApprovalManifestPath | Should -BeTrue
    }

    It 'Produces batch rollback summary' {
        $manifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev443-good-summary.json') -InputObject $script:BaseManifest
        $result = & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $manifestPath -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute
        Test-Path -LiteralPath $result.BatchSummaryPath | Should -BeTrue
        $summary = Get-Content -LiteralPath $result.BatchSummaryPath -Raw | ConvertFrom-Json
        $summary.ApprovedAction | Should -Be 'RollbackDisable'
        $summary.ChildCallCount | Should -Be 0
        @($summary.ApprovalManifestPaths).Count | Should -BeGreaterThan 0
    }

    It 'Confirms non-target object protection contract' {
        $manifestPath = Write-TestJson -Path (Join-Path $TestDrive 'rev443-good-protection.json') -InputObject $script:BaseManifest
        $result = & $script:WrapperPath -TenantId $script:TenantId -BatchManifestPath $manifestPath -OutputRoot $script:OutputRoot -ApprovalPhrase $script:ApprovalPhrase -Mode Execute
        $result.NonTargetObjectProtection | Should -BeTrue
        (Get-Content -LiteralPath $result.BatchSummaryPath -Raw | ConvertFrom-Json).NonTargetObjectProtection | Should -BeTrue
    }

    It 'does not call Remove-Mg* or unsupported Graph mutation commands' {
        $source = Get-Content -LiteralPath $script:WrapperPath -Raw
        $source | Should -Not -Match 'Remove-Mg'
        $source | Should -Not -Match 'Update-MgServicePrincipal'
        $source | Should -Not -Match '(?i)\bCleanupApproved\s*=\s*\$true\b'
        $source | Should -Not -Match '(?i)\bFinalDeleteApproved\s*=\s*\$true\b'
    }
}
