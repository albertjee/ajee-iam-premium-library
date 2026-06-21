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

function script:New-Rev438InventoryRecord {
    param(
        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter(Mandatory)]
        [string]$ApplicationObjectId,

        [Parameter(Mandatory)]
        [string]$ServicePrincipalObjectId,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [bool]$ControlObject
    )

    [pscustomobject]@{
        DisplayName = $DisplayName
        AppId = $AppId
        ApplicationObjectId = $ApplicationObjectId
        ServicePrincipalObjectId = $ServicePrincipalObjectId
        TargetType = 'ServicePrincipal'
        Purpose = if ($ControlObject) { 'Control object' } else { 'Rev4.38 live disable target' }
        CreatedAt = [DateTime]::UtcNow.ToString('o')
        TenantId = $TenantId
        SafeToDisable = -not $ControlObject
        SafeToRollback = -not $ControlObject
        ControlObject = $ControlObject
    }
}

function script:New-Rev438ApprovalManifest {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$TargetObjectId,

        [Parameter(Mandatory)]
        [string]$DisplayName,

        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter()]
        [string]$RunId = 'REV438-TEST-RUN',

        [Parameter()]
        [string[]]$TargetObjectIds = @($TargetObjectId),

        [Parameter()]
        [string]$ApprovedAction = 'ReversibleDisable',

        [Parameter()]
        [string]$ApprovalPhrase = 'APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY',

        [Parameter()]
        [object]$RollbackReady = $true,

        [Parameter()]
        [object]$LiveMutationApproved = $true,

        [Parameter()]
        [object]$FinalDeleteApproved = $false
    )

    [pscustomobject]@{
        SchemaVersion = '4.38'
        RunId = $RunId
        Status = 'Approved'
        ApprovedBy = 'lab-approver@example.com'
        ApprovedUtc = [DateTime]::UtcNow.ToString('o')
        ExpiresUtc = [DateTime]::UtcNow.AddDays(1).ToString('o')
        TenantId = $TenantId
        TargetObjectId = $TargetObjectId
        TargetObjectIds = @($TargetObjectIds)
        TargetDisplayName = $DisplayName
        AppId = $AppId
        ApprovedAction = $ApprovedAction
        ApprovedActions = @($ApprovedAction)
        ApprovalPhrase = $ApprovalPhrase
        RollbackReady = $RollbackReady
        LiveMutationApproved = $LiveMutationApproved
        FinalDeleteApproved = $FinalDeleteApproved
    }
}

Describe 'Rev4.38 lab live reversible disable gate' {
    BeforeAll {
        $script:ToolsPath = Join-Path $PSScriptRoot '..\tools'
        . (Join-Path $script:ToolsPath 'Invoke-Rev438LabLiveReversibleDisable.ps1')

        $script:TenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
        $script:TargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
        $script:TargetAppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
        $script:TargetApplicationObjectId = 'cacb17fd-bc8d-4798-a8b9-e030699ea2ad'
        $script:TargetServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
        $script:ControlDisplayName = 'AJEE-LAB-NHI-KEEP-CONTROL'
        $script:ControlServicePrincipalObjectId = 'b574ecc2-443f-4963-9cd4-cb5da517a717'
        $script:ApprovalPhrase = 'APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
        $script:RunId = 'REV438-BASELINE'
        $script:RunOutput = Join-Path $TestDrive 'rev438-baseline'
        $null = New-Item -ItemType Directory -Path $script:RunOutput -Force
        $script:ApprovalPath = Join-Path $TestDrive 'rev438-approval.json'
        Write-TestJson -Path $script:ApprovalPath -InputObject (New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId)

        $script:InventoryDocument = [pscustomobject]@{
            SchemaVersion = '4.37'
            CreatedAt = [DateTime]::UtcNow.ToString('o')
            TenantId = $script:TenantId
            Inventory = @(
                (New-Rev438InventoryRecord -DisplayName $script:ControlDisplayName -AppId '11111111-1111-1111-1111-111111111111' -ApplicationObjectId '22222222-2222-2222-2222-222222222222' -ServicePrincipalObjectId $script:ControlServicePrincipalObjectId -TenantId $script:TenantId -ControlObject $true)
                (New-Rev438InventoryRecord -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -ApplicationObjectId $script:TargetApplicationObjectId -ServicePrincipalObjectId $script:TargetServicePrincipalObjectId -TenantId $script:TenantId -ControlObject $false)
                (New-Rev438InventoryRecord -DisplayName 'AJEE-LAB-NHI-MARK-ONLY' -AppId '33333333-3333-3333-3333-333333333333' -ApplicationObjectId '44444444-4444-4444-4444-444444444444' -ServicePrincipalObjectId '55555555-5555-5555-5555-555555555555' -TenantId $script:TenantId -ControlObject $false)
                (New-Rev438InventoryRecord -DisplayName 'AJEE-LAB-NHI-NO-OWNER' -AppId '66666666-6666-6666-6666-666666666666' -ApplicationObjectId '77777777-7777-7777-7777-777777777777' -ServicePrincipalObjectId '88888888-8888-8888-8888-888888888888' -TenantId $script:TenantId -ControlObject $false)
                (New-Rev438InventoryRecord -DisplayName 'AJEE-LAB-NHI-EXPIRED-CRED' -AppId '99999999-9999-9999-9999-999999999999' -ApplicationObjectId 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa' -ServicePrincipalObjectId 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb' -TenantId $script:TenantId -ControlObject $false)
                (New-Rev438InventoryRecord -DisplayName 'AJEE-LAB-NHI-ACTIVE-CRED' -AppId 'cccccccc-cccc-cccc-cccc-cccccccccccc' -ApplicationObjectId 'dddddddd-dddd-dddd-dddd-dddddddddddd' -ServicePrincipalObjectId 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee' -TenantId $script:TenantId -ControlObject $false)
            )
        }

        $script:InventoryPath = Join-Path $TestDrive 'rev438-inventory.json'
        Write-TestJson -Path $script:InventoryPath -InputObject $script:InventoryDocument
    }

    BeforeEach {
        $script:RunId = 'REV438-{0}' -f ([guid]::NewGuid().ToString('N'))
        $script:RunOutput = Join-Path $TestDrive $script:RunId
        $null = New-Item -ItemType Directory -Path $script:RunOutput -Force

        $script:ApprovalPath = Join-Path $TestDrive "$($script:RunId)-approval.json"
        Write-TestJson -Path $script:ApprovalPath -InputObject (New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId)
    }

    BeforeEach {
        Mock Update-MgServicePrincipal {
            [pscustomobject]@{
                ServicePrincipalId = $ServicePrincipalId
                AccountEnabled = $false
            }
        }

        Mock Update-MgApplication { throw 'Update-MgApplication must not be called.' }
        Mock Remove-MgServicePrincipal { throw 'Remove-MgServicePrincipal must not be called.' }
        Mock Remove-MgApplication { throw 'Remove-MgApplication must not be called.' }
        Mock Remove-MgOauth2PermissionGrant { throw 'Remove-MgOauth2PermissionGrant must not be called.' }
        Mock Remove-MgServicePrincipalAppRoleAssignment { throw 'Remove-MgServicePrincipalAppRoleAssignment must not be called.' }
        Mock Remove-MgApplicationPassword { throw 'Remove-MgApplicationPassword must not be called.' }
        Mock Remove-MgApplicationKey { throw 'Remove-MgApplicationKey must not be called.' }
    }

    It 'Rejects wrong TenantId' {
        { Invoke-Rev438LabLiveReversibleDisable -TenantId '00000000-0000-0000-0000-000000000000' -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects missing inventory' {
        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath (Join-Path $TestDrive 'missing-inventory.json') -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects missing approval manifest' {
        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath (Join-Path $TestDrive 'missing-approval.json') -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects wrong target object ID' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId 'ffffffff-ffff-ffff-ffff-ffffffffffff' -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId
        $approvalPath = Join-Path $TestDrive 'approval-wrong-target.json'
        Write-TestJson -Path $approvalPath -InputObject $approval

        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $approvalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects wrong display name' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName 'AJEE-LAB-NHI-BAD-NAME' -AppId $script:TargetAppId
        $approvalPath = Join-Path $TestDrive 'approval-wrong-display.json'
        Write-TestJson -Path $approvalPath -InputObject $approval

        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $approvalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects wrong AppId' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId 'ffffffff-ffff-ffff-ffff-ffffffffffff'
        $approvalPath = Join-Path $TestDrive 'approval-wrong-appid.json'
        Write-TestJson -Path $approvalPath -InputObject $approval

        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $approvalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects missing control object' {
        $inventoryWithoutControl = [pscustomobject]@{
            SchemaVersion = '4.37'
            CreatedAt = [DateTime]::UtcNow.ToString('o')
            TenantId = $script:TenantId
            Inventory = @($script:InventoryDocument.Inventory | Where-Object { $_.DisplayName -ne $script:ControlDisplayName })
        }
        $inventoryPath = Join-Path $TestDrive 'inventory-no-control.json'
        Write-TestJson -Path $inventoryPath -InputObject $inventoryWithoutControl

        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $inventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects approval with extra target IDs' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -TargetObjectIds @($script:TargetServicePrincipalObjectId, 'ffffffff-ffff-ffff-ffff-ffffffffffff')
        $approvalPath = Join-Path $TestDrive 'approval-extra-targets.json'
        Write-TestJson -Path $approvalPath -InputObject $approval

        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $approvalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects approval with wrong target ID' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId 'ffffffff-ffff-ffff-ffff-ffffffffffff' -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -TargetObjectIds @('ffffffff-ffff-ffff-ffff-ffffffffffff')
        $approvalPath = Join-Path $TestDrive 'approval-wrong-target-id.json'
        Write-TestJson -Path $approvalPath -InputObject $approval

        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $approvalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects approval with wrong approval phrase' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -ApprovalPhrase 'APPROVE SOMETHING ELSE'
        $approvalPath = Join-Path $TestDrive 'approval-wrong-phrase.json'
        Write-TestJson -Path $approvalPath -InputObject $approval

        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $approvalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
    }

    It 'Rejects approval that does not approve ReversibleDisable or DisableOnly' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -ApprovedAction 'FinalDelete'
        $approvalPath = Join-Path $TestDrive 'approval-wrong-action.json'
        Write-TestJson -Path $approvalPath -InputObject $approval

        { Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $approvalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf } | Should -Throw
        $gate = Assert-Rev438LabGate -TenantId $script:TenantId -InventoryRecords $script:InventoryDocument.Inventory -ApprovalManifest $approval -ConfirmLiveDisablePhrase $script:ApprovalPhrase
        $gate.Passed | Should -BeFalse
        ($gate.Reasons | Where-Object { $_ -match 'Approval must authorize only ReversibleDisable or DisableOnly' }) | Should -Not -BeNullOrEmpty
    }

    It 'Treats string false as false in rollback readiness validation' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RollbackReady 'false'
        $gate = Assert-Rev438LabGate -TenantId $script:TenantId -InventoryRecords $script:InventoryDocument.Inventory -ApprovalManifest $approval -ConfirmLiveDisablePhrase $script:ApprovalPhrase

        $gate.Passed | Should -BeFalse
        ($gate.Reasons | Where-Object { $_ -match 'Approval manifest must mark rollback readiness true' }) | Should -Not -BeNullOrEmpty
    }

    It 'Fails closed on invalid rollback boolean strings' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RollbackReady 'maybe'
        $gate = Assert-Rev438LabGate -TenantId $script:TenantId -InventoryRecords $script:InventoryDocument.Inventory -ApprovalManifest $approval -ConfirmLiveDisablePhrase $script:ApprovalPhrase

        $gate.Passed | Should -BeFalse
        ($gate.Reasons | Where-Object { $_ -match 'RollbackReady must be a boolean value' }) | Should -Not -BeNullOrEmpty
    }

    It 'Rejects LiveMutationApproved=false' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -LiveMutationApproved $false
        $gate = Assert-Rev438LabGate -TenantId $script:TenantId -InventoryRecords $script:InventoryDocument.Inventory -ApprovalManifest $approval -ConfirmLiveDisablePhrase $script:ApprovalPhrase

        $gate.Passed | Should -BeFalse
        ($gate.Reasons | Where-Object { $_ -match 'explicitly approve live mutation' }) | Should -Not -BeNullOrEmpty
    }

    It 'Rejects FinalDeleteApproved=true' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -FinalDeleteApproved $true
        $gate = Assert-Rev438LabGate -TenantId $script:TenantId -InventoryRecords $script:InventoryDocument.Inventory -ApprovalManifest $approval -ConfirmLiveDisablePhrase $script:ApprovalPhrase

        $gate.Passed | Should -BeFalse
        ($gate.Reasons | Where-Object { $_ -match 'FinalDelete must not be approved' }) | Should -Not -BeNullOrEmpty
    }

    It 'Rejects disallowed ApprovedActions values' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId
        $approval.ApprovedActions = @('FinalDelete')
        $gate = Assert-Rev438LabGate -TenantId $script:TenantId -InventoryRecords $script:InventoryDocument.Inventory -ApprovalManifest $approval -ConfirmLiveDisablePhrase $script:ApprovalPhrase

        $gate.Passed | Should -BeFalse
        ($gate.Reasons | Where-Object { $_ -match 'ApprovedActions contains a disallowed value' }) | Should -Not -BeNullOrEmpty
    }

    It 'Rejects any changed-object manifest containing more than one object ID' {
        $target = $script:InventoryDocument.Inventory | Where-Object { $_.DisplayName -eq $script:TargetDisplayName }
        $control = $script:InventoryDocument.Inventory | Where-Object { $_.DisplayName -eq $script:ControlDisplayName }
        $manifest = [pscustomobject]@{
            ChangedObjectIds = @($target.ServicePrincipalObjectId, 'ffffffff-ffff-ffff-ffff-ffffffffffff')
            ChangedObjects = @(
                [pscustomobject]@{ ObjectId = $target.ServicePrincipalObjectId; DisplayName = $target.DisplayName; ObjectType = 'ServicePrincipal'; ChangeType = 'AccountEnabled:false' }
                [pscustomobject]@{ ObjectId = 'ffffffff-ffff-ffff-ffff-ffffffffffff'; DisplayName = 'Other'; ObjectType = 'ServicePrincipal'; ChangeType = 'AccountEnabled:false' }
            )
        }

        { Assert-Rev438ChangedObjectManifest -ChangedObjectManifest $manifest -TargetRecord $target -ControlRecord $control } | Should -Throw
    }

    It 'Verifies control object is never included in changed-object manifest' {
        $target = $script:InventoryDocument.Inventory | Where-Object { $_.DisplayName -eq $script:TargetDisplayName }
        $control = $script:InventoryDocument.Inventory | Where-Object { $_.DisplayName -eq $script:ControlDisplayName }
        $manifest = [pscustomobject]@{
            ChangedObjectIds = @($target.ServicePrincipalObjectId, $control.ServicePrincipalObjectId)
            ChangedObjects = @(
                [pscustomobject]@{ ObjectId = $target.ServicePrincipalObjectId; DisplayName = $target.DisplayName; ObjectType = 'ServicePrincipal'; ChangeType = 'AccountEnabled:false' }
                [pscustomobject]@{ ObjectId = $control.ServicePrincipalObjectId; DisplayName = $control.DisplayName; ObjectType = 'ServicePrincipal'; ChangeType = 'AccountEnabled:false' }
            )
        }

        { Assert-Rev438ChangedObjectManifest -ChangedObjectManifest $manifest -TargetRecord $target -ControlRecord $control } | Should -Throw
    }

    It 'Verifies -WhatIf produces artifacts and performs no mutation' {
        $result = Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf -Confirm:$false

        $result.WhatIf | Should -BeTrue
        $result.LiveMutationPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        Test-Path -LiteralPath $result.Artifacts.PreActionSnapshot | Should -BeTrue
        Test-Path -LiteralPath $result.Artifacts.RollbackPackage | Should -BeTrue
        Test-Path -LiteralPath $result.Artifacts.ChangedObjectManifest | Should -BeTrue
        Test-Path -LiteralPath $result.Artifacts.PostDisableValidation | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue

        Assert-MockCalled Update-MgServicePrincipal -Times 0 -Exactly
        Assert-MockCalled Remove-MgServicePrincipal -Times 0 -Exactly
        Assert-MockCalled Remove-MgApplication -Times 0 -Exactly
    }

    It 'Verifies live path calls only Update-MgServicePrincipal for the exact target ID' {
        $result = Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -Confirm:$false

        $result.LiveMutationPerformed | Should -BeTrue
        $result.WhatIf | Should -BeFalse
        Assert-MockCalled Update-MgServicePrincipal -Times 1 -Exactly -ParameterFilter {
            $ServicePrincipalId -eq $script:TargetServicePrincipalObjectId -and $AccountEnabled -eq $false
        }
    }

    It 'Verifies live path never calls Remove-MgServicePrincipal' {
        $null = Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -Confirm:$false
        Assert-MockCalled Remove-MgServicePrincipal -Times 0 -Exactly
    }

    It 'Verifies live path never calls Remove-MgApplication' {
        $null = Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -Confirm:$false
        Assert-MockCalled Remove-MgApplication -Times 0 -Exactly
    }

    It 'Verifies live path never calls Update-MgApplication' {
        $null = Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -Confirm:$false
        Assert-MockCalled Update-MgApplication -Times 0 -Exactly
    }

    It 'Verifies live path never touches grants, credentials, or metadata' {
        $null = Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -Confirm:$false
        Assert-MockCalled Remove-MgOauth2PermissionGrant -Times 0 -Exactly
        Assert-MockCalled Remove-MgServicePrincipalAppRoleAssignment -Times 0 -Exactly
        Assert-MockCalled Remove-MgApplicationPassword -Times 0 -Exactly
        Assert-MockCalled Remove-MgApplicationKey -Times 0 -Exactly
    }

    It 'Verifies rollback package is re-enable only' {
        $target = $script:InventoryDocument.Inventory | Where-Object { $_.DisplayName -eq $script:TargetDisplayName }
        $snapshot = [pscustomobject]@{ OutputArtifactPath = Join-Path $TestDrive 'snapshot.json' }
        $rollback = New-Rev438RollbackPackage -TargetRecord $target -PreActionSnapshot $snapshot -OutputPath $script:RunOutput -RunId 'REV438-ROLLBACK-TEST'

        $rollback.RollbackAction | Should -Be 'ReEnableServicePrincipal'
        $rollback.RollbackCommandPreview | Should -Match 'Update-MgServicePrincipal'
        $rollback.RollbackCommandPreview | Should -Match 'AccountEnabled'
        $rollback.RollbackCommandPreview | Should -Not -Match 'Remove-Mg'
        $rollback.FinalDeleteAllowed | Should -BeFalse
        { Assert-Rev438RollbackPackage -RollbackPackage $rollback } | Should -Not -Throw
    }

    It 'Verifies final delete is blocked/not present' {
        $result = Invoke-Rev438LabLiveReversibleDisable -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:RunOutput -ConfirmLiveDisablePhrase $script:ApprovalPhrase -WhatIf -Confirm:$false

        $result.FinalDeleteAllowed | Should -BeFalse
        $result.NoDeletePath | Should -BeTrue
        $result.SafetyGatePassed | Should -BeTrue
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).FinalDeleteAllowed | Should -BeFalse
    }
}
