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

function script:New-Rev439InventoryRecord {
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
        Purpose = if ($ControlObject) { 'Control object' } else { 'Rev4.39 live rollback target' }
        CreatedAt = [DateTime]::UtcNow.ToString('o')
        TenantId = $TenantId
        SafeToDisable = -not $ControlObject
        SafeToRollback = -not $ControlObject
        ControlObject = $ControlObject
    }
}

function script:New-Rev439ApprovalManifest {
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
        [string]$RunId = 'REV439-TEST-RUN',

        [Parameter()]
        [string[]]$TargetObjectIds = @($TargetObjectId),

        [Parameter()]
        [string]$ApprovedAction = 'ReEnableServicePrincipal',

        [Parameter()]
        [string]$ApprovalPhrase = 'APPROVE REV4.39 LIVE ROLLBACK AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY',

        [Parameter()]
        [object]$LiveRollbackApproved = $true,

        [Parameter()]
        [object]$FinalDeleteApproved = $false,

        [Parameter()]
        [object]$CleanupApproved = $false
    )

    [pscustomobject]@{
        SchemaVersion = '4.39'
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
        LiveRollbackApproved = $LiveRollbackApproved
        FinalDeleteApproved = $FinalDeleteApproved
        CleanupApproved = $CleanupApproved
    }
}

Describe 'Rev4.39 lab live rollback gate' {
    BeforeAll {
        $script:RollbackScriptPath = Join-Path $PSScriptRoot '..\tools\Invoke-Rev439LabLiveRollback.ps1'

        $script:TenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
        $script:TargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
        $script:TargetAppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
        $script:TargetApplicationObjectId = 'cacb17fd-bc8d-4798-a8b9-e030699ea2ad'
        $script:TargetServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
        $script:ControlDisplayName = 'AJEE-LAB-NHI-KEEP-CONTROL'
        $script:ControlServicePrincipalObjectId = 'b574ecc2-443f-4963-9cd4-cb5da517a717'
        $script:RollbackPhrase = 'APPROVE REV4.39 LIVE ROLLBACK AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
    }

    BeforeEach {
        $script:RunId = 'REV439-' + [guid]::NewGuid().ToString('N')
        $script:OutputPath = Join-Path $TestDrive $script:RunId
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:InventoryPath = Join-Path $TestDrive "$($script:RunId)-inventory.json"
        $script:ApprovalPath = Join-Path $TestDrive "$($script:RunId)-approval.json"

        $script:InventoryDocument = [pscustomobject]@{
            SchemaVersion = '4.37'
            CreatedAt = [DateTime]::UtcNow.ToString('o')
            TenantId = $script:TenantId
            Inventory = @(
                (New-Rev439InventoryRecord -DisplayName $script:ControlDisplayName -AppId '11111111-1111-1111-1111-111111111111' -ApplicationObjectId '22222222-2222-2222-2222-222222222222' -ServicePrincipalObjectId $script:ControlServicePrincipalObjectId -TenantId $script:TenantId -ControlObject $true)
                (New-Rev439InventoryRecord -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -ApplicationObjectId $script:TargetApplicationObjectId -ServicePrincipalObjectId $script:TargetServicePrincipalObjectId -TenantId $script:TenantId -ControlObject $false)
            )
        }
        Write-TestJson -Path $script:InventoryPath -InputObject $script:InventoryDocument

        $script:ApprovalDocument = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId
        Write-TestJson -Path $script:ApprovalPath -InputObject $script:ApprovalDocument

        Mock Update-MgServicePrincipal {
            [pscustomobject]@{
                ServicePrincipalId = $ServicePrincipalId
                AccountEnabled = $true
            }
        }

        Mock Remove-MgServicePrincipal { throw 'Remove-MgServicePrincipal must not be called.' }
        Mock Remove-MgApplication { throw 'Remove-MgApplication must not be called.' }
        Mock Remove-MgOauth2PermissionGrant { throw 'Remove-MgOauth2PermissionGrant must not be called.' }
        Mock Remove-MgServicePrincipalAppRoleAssignment { throw 'Remove-MgServicePrincipalAppRoleAssignment must not be called.' }
        Mock Remove-MgApplicationPassword { throw 'Remove-MgApplicationPassword must not be called.' }
        Mock Remove-MgApplicationKey { throw 'Remove-MgApplicationKey must not be called.' }
    }

    It 'rejects missing inventory' {
        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath (Join-Path $TestDrive 'missing-inventory.json') -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects missing approval manifest' {
        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath (Join-Path $TestDrive 'missing-approval.json') -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects wrong tenant' {
        { & $script:RollbackScriptPath -TenantId '00000000-0000-0000-0000-000000000000' -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects wrong target object ID' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId 'ffffffff-ffff-ffff-ffff-ffffffffffff' -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects wrong display name' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName 'AJEE-LAB-NHI-BAD-NAME' -AppId $script:TargetAppId -RunId $script:RunId
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects wrong AppId' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId 'ffffffff-ffff-ffff-ffff-ffffffffffff' -RunId $script:RunId
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects missing control object' {
        $inventoryWithoutControl = [pscustomobject]@{
            SchemaVersion = '4.37'
            CreatedAt = [DateTime]::UtcNow.ToString('o')
            TenantId = $script:TenantId
            Inventory = @($script:InventoryDocument.Inventory | Where-Object { $_.DisplayName -ne $script:ControlDisplayName })
        }
        Write-TestJson -Path $script:InventoryPath -InputObject $inventoryWithoutControl

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects extra target IDs' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -TargetObjectIds @($script:TargetServicePrincipalObjectId, 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee')
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects wrong rollback approval phrase' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -ApprovalPhrase 'APPROVE SOMETHING ELSE'
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects disallowed ApprovedAction' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -ApprovedAction 'FinalDelete'
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects disallowed ApprovedActions array value' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId
        $approval.ApprovedActions = @('FinalDelete')
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects LiveRollbackApproved false' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -LiveRollbackApproved $false
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects FinalDeleteApproved true' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -FinalDeleteApproved $true
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'rejects CleanupApproved true' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -CleanupApproved $true
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'parses string false as false, not true' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -LiveRollbackApproved 'false' -FinalDeleteApproved 'false' -CleanupApproved 'false'
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'fails closed on invalid boolean strings' {
        $approval = New-Rev439ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -LiveRollbackApproved 'maybe' -FinalDeleteApproved 'maybe' -CleanupApproved 'maybe'
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        { & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf } | Should -Throw
    }

    It 'WhatIf does not call Update-MgServicePrincipal' {
        $result = & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf
        $result.WhatIf | Should -BeTrue
        $result.LiveMutationPerformed | Should -BeFalse
        Assert-MockCalled Update-MgServicePrincipal -Times 0 -Exactly
    }

    It 'live path is gated by ShouldProcess' {
        $result = & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -Confirm:$false
        $result.LiveMutationPerformed | Should -BeTrue
        Assert-MockCalled Update-MgServicePrincipal -Times 1 -Exactly -ParameterFilter {
            $ServicePrincipalId -eq $script:TargetServicePrincipalObjectId -and $AccountEnabled -eq $true
        }
    }

    It 'allowed mutation surface is exactly Update-MgServicePrincipal AccountEnabled:true' {
        $source = Get-Content -LiteralPath $script:RollbackScriptPath -Raw
        ($source -match 'Update-MgServicePrincipal') | Should -BeTrue
        ($source -match '-AccountEnabled:\$true') | Should -BeTrue
        $source | Should -Not -Match 'Remove-Mg'
        $source | Should -Not -Match 'AllowFinalDelete'
    }

    It 'produces fresh artifacts and summary flags' {
        $result = & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf
        Test-Path -LiteralPath $result.Artifacts.PreRollbackSnapshot | Should -BeTrue
        Test-Path -LiteralPath $result.Artifacts.ChangedObjectManifest | Should -BeTrue
        Test-Path -LiteralPath $result.Artifacts.PostRollbackValidation | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        (Split-Path -Parent $result.OutputArtifactPath) | Should -Be $script:OutputPath
        $summary = Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json
        $summary.NoDeletePath | Should -BeTrue
        $summary.FinalDeleteAllowed | Should -BeFalse
        $summary.CleanupAllowed | Should -BeFalse
        $summary.ApplicationRegistrationUntouched | Should -BeTrue
        $summary.GrantsUntouched | Should -BeTrue
        $summary.CredentialsUntouched | Should -BeTrue
        $summary.ControlObjectUntouched | Should -BeTrue
    }

    It 'changed-object manifest contains exactly one object and excludes control object' {
        $result = & $script:RollbackScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveRollbackPhrase $script:RollbackPhrase -WhatIf
        $manifest = Get-Content -LiteralPath $result.Artifacts.ChangedObjectManifest -Raw | ConvertFrom-Json
        $manifest.ChangedObjects.Count | Should -Be 1
        $manifest.ChangedObjectIds.Count | Should -Be 1
        $manifest.ChangedObjectIds[0] | Should -Be $script:TargetServicePrincipalObjectId
        $manifest.ChangedObjects[0].ChangeType | Should -Be 'AccountEnabled:true'
        $manifest.ChangedObjectIds | Should -Not -Contain $script:ControlServicePrincipalObjectId
    }
}
