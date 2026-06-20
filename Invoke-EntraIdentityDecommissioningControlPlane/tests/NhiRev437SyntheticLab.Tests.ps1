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
