#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev4.37 synthetic NHI lab assets' {
    BeforeAll {
        $script:ToolsPath = Join-Path $PSScriptRoot '..\tools'
        . (Join-Path $script:ToolsPath 'New-Rev437SyntheticNhiLab.ps1')
        . (Join-Path $script:ToolsPath 'Remove-Rev437SyntheticNhiLab.ps1')
    }

    It 'generator definitions contain the required AJEE-LAB-NHI-* objects' {
        $definitions = @(Get-Rev437RequiredLabDefinitions)
        $definitions.DisplayName | Should -Be @(
            'AJEE-LAB-NHI-KEEP-CONTROL'
            'AJEE-LAB-NHI-DISABLE-ROLLBACK'
            'AJEE-LAB-NHI-MARK-ONLY'
            'AJEE-LAB-NHI-NO-OWNER'
            'AJEE-LAB-NHI-EXPIRED-CRED'
            'AJEE-LAB-NHI-ACTIVE-CRED'
        )
    }

    It 'generator rejects a non-prefixed display name' {
        { Assert-Rev437SyntheticNhiLabDefinition -Definition ([pscustomobject]@{ DisplayName = 'BAD-NHI'; Purpose = 'x'; TargetType = 'ServicePrincipal' }) } | Should -Throw
    }

    It 'generator requires explicit confirmation before creation' {
        { Invoke-Rev437SyntheticNhiLabCreation -TenantId '00000000-0000-0000-0000-000000000001' -OutputPath (Join-Path $TestDrive 'rev437.json') } | Should -Throw
    }

    Context 'generator WhatIf dry-run' {
        BeforeEach {
            Mock Get-MgApplication { @() }
            Mock Get-MgServicePrincipal { @() }
            Mock New-MgApplication { $null }
            Mock New-MgServicePrincipal -ParameterFilter { [string]::IsNullOrWhiteSpace($AppId) } -MockWith {
                throw 'empty AppId must never be used in WhatIf mode.'
            }
        }

        It 'completes when New-MgApplication would not produce a real AppId' {
            { Invoke-Rev437SyntheticNhiLabCreation -TenantId '00000000-0000-0000-0000-000000000001' -OutputPath (Join-Path $TestDrive 'rev437.json') -ConfirmLabCreation -WhatIf } | Should -Not -Throw
        }

        It 'does not attempt service-principal creation with an empty AppId' {
            $result = Invoke-Rev437SyntheticNhiLabCreation -TenantId '00000000-0000-0000-0000-000000000001' -OutputPath (Join-Path $TestDrive 'rev437.json') -ConfirmLabCreation -WhatIf

            $result.WhatIf | Should -BeTrue
            $result.InventoryExported | Should -BeFalse
            $result.LiveIdsAvailable | Should -BeFalse
            $result.InventoryFile | Should -BeNullOrEmpty

            Assert-MockCalled New-MgApplication -Times 0 -Exactly
            Assert-MockCalled New-MgServicePrincipal -Times 0 -Exactly
            Assert-MockCalled Get-MgServicePrincipal -Times 0 -Exactly
        }
    }

    Context 'generator inventory export path resolution' {
        It 'writes inventory JSON inside a directory OutputPath as a direct record array' {
            $outputDir = Join-Path $TestDrive 'rev437-output'
            $definitions = @(Get-Rev437RequiredLabDefinitions)
            $inventory = foreach ($definition in $definitions) {
                $suffix = [array]::IndexOf($definitions, $definition) + 1
                $application = [pscustomobject]@{
                    Id    = "11111111-1111-1111-1111-11111111111$suffix"
                    AppId = "22222222-2222-2222-2222-22222222222$suffix"
                }
                $servicePrincipal = [pscustomobject]@{
                    Id = "33333333-3333-3333-3333-33333333333$suffix"
                }

                Get-Rev437InventoryRecord -Definition $definition -Application $application -ServicePrincipal $servicePrincipal -TenantId '00000000-0000-0000-0000-000000000001'
            }

            $result = Export-Rev437SyntheticNhiLabInventory -Inventory $inventory -TenantId '00000000-0000-0000-0000-000000000001' -OutputPath $outputDir
            $expectedFile = Join-Path $outputDir 'rev437-synthetic-nhi-lab-inventory.json'

            $result.InventoryFile | Should -Be $expectedFile
            Test-Path -LiteralPath $outputDir -PathType Container | Should -BeTrue
            Test-Path -LiteralPath $expectedFile -PathType Leaf | Should -BeTrue

            $written = Get-Content -LiteralPath $expectedFile -Raw | ConvertFrom-Json
            $written -is [array] | Should -BeTrue
            $written.Count | Should -Be 6
            foreach ($record in $written) {
                { Assert-Rev437SyntheticNhiLabDefinition -Definition $record } | Should -Not -Throw
            }

            $written[0].PSObject.Properties.Name | Should -Contain 'DisplayName'
            $written[0].PSObject.Properties.Name | Should -Contain 'AppId'
            $written[0].PSObject.Properties.Name | Should -Contain 'ApplicationObjectId'
            $written[0].PSObject.Properties.Name | Should -Contain 'ServicePrincipalObjectId'
            $written[0].PSObject.Properties.Name | Should -Contain 'TargetType'
            $written[0].PSObject.Properties.Name | Should -Contain 'Purpose'
            $written[0].PSObject.Properties.Name | Should -Contain 'CreatedAt'
            $written[0].PSObject.Properties.Name | Should -Contain 'TenantId'
            $written[0].PSObject.Properties.Name | Should -Contain 'SafeToDisable'
            $written[0].PSObject.Properties.Name | Should -Contain 'SafeToRollback'
            $written[0].PSObject.Properties.Name | Should -Contain 'ControlObject'

            ($written | Where-Object { $_.ControlObject -eq $true }).Count | Should -Be 1
        }

        It 'supports an explicit json file OutputPath' {
            $outputFile = Join-Path $TestDrive 'custom-rev437-inventory.json'
            $inventory = @(
                [pscustomobject]@{
                    DisplayName             = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
                    AppId                   = '44444444-4444-4444-4444-444444444444'
                    ApplicationObjectId     = '55555555-5555-5555-5555-555555555555'
                    ServicePrincipalObjectId = '66666666-6666-6666-6666-666666666666'
                    TargetType              = 'ServicePrincipal'
                    Purpose                 = 'candidate'
                    CreatedAt               = [DateTime]::UtcNow.ToString('o')
                    TenantId                = '00000000-0000-0000-0000-000000000001'
                    SafeToDisable           = $true
                    SafeToRollback          = $true
                    ControlObject           = $false
                }
            )

            $result = Export-Rev437SyntheticNhiLabInventory -Inventory $inventory -TenantId '00000000-0000-0000-0000-000000000001' -OutputPath $outputFile

            $result.InventoryFile | Should -Be $outputFile
            Test-Path -LiteralPath $outputFile -PathType Leaf | Should -BeTrue
        }

        It 'passes the resolved inventory file path to Set-Content instead of the directory path' {
            $outputDir = Join-Path $TestDrive 'rev437-setcontent'
            $inventory = @(
                [pscustomobject]@{
                    DisplayName             = 'AJEE-LAB-NHI-MARK-ONLY'
                    AppId                   = '77777777-7777-7777-7777-777777777777'
                    ApplicationObjectId     = '88888888-8888-8888-8888-888888888888'
                    ServicePrincipalObjectId = '99999999-9999-9999-9999-999999999999'
                    TargetType              = 'ServicePrincipal'
                    Purpose                 = 'candidate'
                    CreatedAt               = [DateTime]::UtcNow.ToString('o')
                    TenantId                = '00000000-0000-0000-0000-000000000001'
                    SafeToDisable           = $false
                    SafeToRollback          = $false
                    ControlObject           = $false
                }
            )

            $script:CapturedSetContentPath = $null
            Mock Set-Content {
                if (Test-Path -LiteralPath $LiteralPath -PathType Container) {
                    throw 'Set-Content received a directory path.'
                }

                $script:CapturedSetContentPath = $LiteralPath
            }

            $result = Export-Rev437SyntheticNhiLabInventory -Inventory $inventory -TenantId '00000000-0000-0000-0000-000000000001' -OutputPath $outputDir
            $expectedFile = Join-Path $outputDir 'rev437-synthetic-nhi-lab-inventory.json'

            $script:CapturedSetContentPath | Should -Be $expectedFile
            $result.InventoryFile | Should -Be $expectedFile
            Assert-MockCalled Set-Content -Times 1 -Exactly
        }

        It 'cleanup WhatIf can consume the generated inventory file shape' {
            $outputDir = Join-Path $TestDrive 'rev437-generated-cleanup'
            $definitions = @(Get-Rev437RequiredLabDefinitions)
            $inventory = foreach ($definition in $definitions) {
                $suffix = [array]::IndexOf($definitions, $definition) + 1
                $application = [pscustomobject]@{
                    Id    = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaa$suffix"
                    AppId = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbb$suffix"
                }
                $servicePrincipal = [pscustomobject]@{
                    Id = "cccccccc-cccc-cccc-cccc-ccccccccccc$suffix"
                }

                Get-Rev437InventoryRecord -Definition $definition -Application $application -ServicePrincipal $servicePrincipal -TenantId '00000000-0000-0000-0000-000000000001'
            }

            $export = Export-Rev437SyntheticNhiLabInventory -Inventory $inventory -TenantId '00000000-0000-0000-0000-000000000001' -OutputPath $outputDir
            Mock Remove-MgApplication { throw 'Remove-MgApplication must not be called in WhatIf.' }
            Mock Remove-MgServicePrincipal { throw 'Remove-MgServicePrincipal must not be called in WhatIf.' }

            $result = Remove-Rev437SyntheticNhiLab -TenantId '00000000-0000-0000-0000-000000000001' -InventoryPath $export.InventoryFile -ConfirmCleanupPhrase 'DELETE AJEE-LAB-NHI INVENTORY OBJECTS' -WhatIf

            $result.WhatIf | Should -BeTrue
            $result.DeletableCount | Should -Be 5
            $result.PlannedDeleteCount | Should -Be 5
            $result.ControlObjectCount | Should -Be 1
            $result.PlannedDeletes.Count | Should -Be 5
            $result.PreservedControl.Count | Should -Be 1
            Assert-MockCalled Remove-MgApplication -Times 0 -Exactly
            Assert-MockCalled Remove-MgServicePrincipal -Times 0 -Exactly
        }
    }

    It 'inventory record contains the required output fields' {
        $definition = (Get-Rev437RequiredLabDefinitions)[1]
        $application = [pscustomobject]@{ Id = '11111111-1111-1111-1111-111111111111'; AppId = '22222222-2222-2222-2222-222222222222' }
        $servicePrincipal = [pscustomobject]@{ Id = '33333333-3333-3333-3333-333333333333' }

        $record = Get-Rev437InventoryRecord -Definition $definition -Application $application -ServicePrincipal $servicePrincipal -TenantId '00000000-0000-0000-0000-000000000001'

        foreach ($field in @(
            'DisplayName',
            'AppId',
            'ApplicationObjectId',
            'ServicePrincipalObjectId',
            'TargetType',
            'Purpose',
            'CreatedAt',
            'TenantId',
            'SafeToDisable',
            'SafeToRollback',
            'ControlObject'
        )) {
            $record.PSObject.Properties[$field] | Should -Not -BeNullOrEmpty
        }
    }

    It 'cleanup refuses when the inventory file is missing' {
        { Read-Rev437SyntheticNhiLabInventory -Path (Join-Path $TestDrive 'missing.json') } | Should -Throw
    }

    It 'cleanup refuses inventory entries without the required prefix' {
        $badInventoryPath = Join-Path $TestDrive 'bad-inventory.json'
        [pscustomobject]@{
            SchemaVersion = '1.0'
            CreatedAt = [DateTime]::UtcNow.ToString('o')
            TenantId = '00000000-0000-0000-0000-000000000001'
            Inventory = @(
                [pscustomobject]@{
                    DisplayName = 'BAD-NHI'
                    AppId = '22222222-2222-2222-2222-222222222222'
                    ApplicationObjectId = '11111111-1111-1111-1111-111111111111'
                    ServicePrincipalObjectId = '33333333-3333-3333-3333-333333333333'
                    TargetType = 'ServicePrincipal'
                    Purpose = 'bad'
                    CreatedAt = [DateTime]::UtcNow.ToString('o')
                    TenantId = '00000000-0000-0000-0000-000000000001'
                    SafeToDisable = $false
                    SafeToRollback = $false
                    ControlObject = $false
                }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $badInventoryPath -Encoding utf8

        { Assert-Rev437SyntheticNhiLabInventory -Inventory (Get-Content -LiteralPath $badInventoryPath -Raw | ConvertFrom-Json) } | Should -Throw
    }

    Context 'cleanup WhatIf dry-run' {
        BeforeEach {
            $script:CleanupWhatIfInventoryPath = Join-Path $TestDrive 'cleanup-whatif.json'
            [pscustomobject]@{
                SchemaVersion = '1.0'
                CreatedAt = [DateTime]::UtcNow.ToString('o')
                TenantId = '00000000-0000-0000-0000-000000000001'
                Inventory = @(
                    [pscustomobject]@{
                        DisplayName = 'AJEE-LAB-NHI-KEEP-CONTROL'
                        AppId = '11111111-1111-1111-1111-111111111111'
                        ApplicationObjectId = '22222222-2222-2222-2222-222222222222'
                        ServicePrincipalObjectId = '33333333-3333-3333-3333-333333333333'
                        TargetType = 'ServicePrincipal'
                        Purpose = 'control'
                        CreatedAt = [DateTime]::UtcNow.ToString('o')
                        TenantId = '00000000-0000-0000-0000-000000000001'
                        SafeToDisable = $false
                        SafeToRollback = $false
                        ControlObject = $true
                    }
                    [pscustomobject]@{
                        DisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
                        AppId = '44444444-4444-4444-4444-444444444444'
                        ApplicationObjectId = '55555555-5555-5555-5555-555555555555'
                        ServicePrincipalObjectId = '66666666-6666-6666-6666-666666666666'
                        TargetType = 'ServicePrincipal'
                        Purpose = 'candidate'
                        CreatedAt = [DateTime]::UtcNow.ToString('o')
                        TenantId = '00000000-0000-0000-0000-000000000001'
                        SafeToDisable = $true
                        SafeToRollback = $true
                        ControlObject = $false
                    }
                )
            } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $script:CleanupWhatIfInventoryPath -Encoding utf8

            Mock Remove-MgApplication { throw 'Remove-MgApplication must not be called in WhatIf.' }
            Mock Remove-MgServicePrincipal { throw 'Remove-MgServicePrincipal must not be called in WhatIf.' }
        }

        It 'reports one planned delete and one preserved control object' {
            $result = Remove-Rev437SyntheticNhiLab -TenantId '00000000-0000-0000-0000-000000000001' -InventoryPath $script:CleanupWhatIfInventoryPath -ConfirmCleanupPhrase 'DELETE AJEE-LAB-NHI INVENTORY OBJECTS' -WhatIf

            $result.WhatIf | Should -BeTrue
            $result.DeletableCount | Should -Be 1
            $result.PlannedDeleteCount | Should -Be 1
            $result.ControlObjectCount | Should -Be 1
            $result.PlannedDeletes.Count | Should -Be 1
            $result.PlannedDeletes[0].DisplayName | Should -Be 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
            $result.Deleted.Count | Should -Be 0
            $result.PreservedControl.Count | Should -Be 1
            $result.PreservedControl[0].DisplayName | Should -Be 'AJEE-LAB-NHI-KEEP-CONTROL'
        }

        It 'does not call Graph removal cmdlets in WhatIf' {
            $null = Remove-Rev437SyntheticNhiLab -TenantId '00000000-0000-0000-0000-000000000001' -InventoryPath $script:CleanupWhatIfInventoryPath -ConfirmCleanupPhrase 'DELETE AJEE-LAB-NHI INVENTORY OBJECTS' -WhatIf

            Assert-MockCalled Remove-MgServicePrincipal -Times 0 -Exactly
            Assert-MockCalled Remove-MgApplication -Times 0 -Exactly
        }
    }

    It 'cleanup requires the explicit confirmation phrase' {
        { Remove-Rev437SyntheticNhiLab -TenantId '00000000-0000-0000-0000-000000000001' -InventoryPath (Join-Path $TestDrive 'missing.json') -ConfirmCleanupPhrase 'wrong phrase' } | Should -Throw
    }

    It 'runbook exists and states that final delete is blocked' {
        $runbookPath = Join-Path $PSScriptRoot '..\docs\REV437-CONTROLLED-NHI-LAB-VALIDATION-RUNBOOK.md'
        Test-Path -LiteralPath $runbookPath | Should -BeTrue
        $content = Get-Content -LiteralPath $runbookPath -Raw
        $content | Should -Match 'Final-Delete Blocked Negative Test'
        $content | Should -Match 'final delete must remain blocked'
        $content | Should -Match 'AJEE-LAB-NHI-KEEP-CONTROL'
    }
}
