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

Describe 'Rev4.38 live-run pack readiness' {
    BeforeAll {
        $script:ReadinessScriptPath = Join-Path $PSScriptRoot '..\tools\Test-Rev438LabLiveDisableReadiness.ps1'

        $script:TenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
        $script:TargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
        $script:TargetAppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
        $script:TargetApplicationObjectId = 'cacb17fd-bc8d-4798-a8b9-e030699ea2ad'
        $script:TargetServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
        $script:ControlDisplayName = 'AJEE-LAB-NHI-KEEP-CONTROL'
        $script:ControlServicePrincipalObjectId = 'b574ecc2-443f-4963-9cd4-cb5da517a717'
        $script:ApprovalPhrase = 'APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
        $script:OfficialInventoryPath = 'C:\temp\IAM\Rev437JsonShapeLive-20260619-214241\rev437-synthetic-nhi-lab-inventory.json'
    }

    BeforeEach {
        $script:RunId = 'REV438-' + [guid]::NewGuid().ToString('N')
        $script:OutputPath = Join-Path $TestDrive $script:RunId
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:InventoryPath = Join-Path $TestDrive "$($script:RunId)-inventory.json"
        $script:ApprovalPath = Join-Path $TestDrive "$($script:RunId)-approval.json"

        $script:InventoryDocument = [pscustomobject]@{
            SchemaVersion = '4.37'
            CreatedAt = [DateTime]::UtcNow.ToString('o')
            TenantId = $script:TenantId
            Inventory = @(
                (New-Rev438InventoryRecord -DisplayName $script:ControlDisplayName -AppId '11111111-1111-1111-1111-111111111111' -ApplicationObjectId '22222222-2222-2222-2222-222222222222' -ServicePrincipalObjectId $script:ControlServicePrincipalObjectId -TenantId $script:TenantId -ControlObject $true)
                (New-Rev438InventoryRecord -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -ApplicationObjectId $script:TargetApplicationObjectId -ServicePrincipalObjectId $script:TargetServicePrincipalObjectId -TenantId $script:TenantId -ControlObject $false)
            )
        }
        Write-TestJson -Path $script:InventoryPath -InputObject $script:InventoryDocument

        $script:ApprovalDocument = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId
        Write-TestJson -Path $script:ApprovalPath -InputObject $script:ApprovalDocument
    }

    It 'rejects missing inventory' {
        { & $script:ReadinessScriptPath -TenantId $script:TenantId -InventoryPath (Join-Path $TestDrive 'missing-inventory.json') -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId } | Should -Throw
    }

    It 'rejects missing approval manifest' {
        { & $script:ReadinessScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath (Join-Path $TestDrive 'missing-approval.json') -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId } | Should -Throw
    }

    It 'rejects wrong tenant and reports the exact reason' {
        $result = & $script:ReadinessScriptPath -TenantId '00000000-0000-0000-0000-000000000000' -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId
        $result.ReadyForWhatIf | Should -BeFalse
        $result.ReadyForLiveDisable | Should -BeFalse
        ($result.BlockingReasons | Where-Object { $_ -match 'TenantId must equal' }) | Should -Not -BeNullOrEmpty
    }

    It 'rejects wrong target ID and extra target IDs' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId 'ffffffff-ffff-ffff-ffff-ffffffffffff' -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -TargetObjectIds @('ffffffff-ffff-ffff-ffff-ffffffffffff', 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee')
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        $result = & $script:ReadinessScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId
        $result.ReadyForWhatIf | Should -BeFalse
        ($result.BlockingReasons | Where-Object { $_ -match 'exactly one TargetObjectId' -or $_ -match 'does not match the required value' }) | Should -Not -BeNullOrEmpty
    }

    It 'rejects wrong approval phrase' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -ApprovalPhrase 'APPROVE SOMETHING ELSE'
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        $result = & $script:ReadinessScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId
        $result.ReadyForWhatIf | Should -BeFalse
        ($result.BlockingReasons | Where-Object { $_ -match 'required approval phrase' }) | Should -Not -BeNullOrEmpty
    }

    It 'rejects FinalDeleteApproved true' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -FinalDeleteApproved $true
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        $result = & $script:ReadinessScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId
        $result.ReadyForWhatIf | Should -BeFalse
        ($result.BlockingReasons | Where-Object { $_ -match 'FinalDelete must not be approved' }) | Should -Not -BeNullOrEmpty
    }

    It 'parses string false as false, not true' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -RollbackReady 'false' -LiveMutationApproved 'false'
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        $result = & $script:ReadinessScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId
        $result.ReadyForWhatIf | Should -BeFalse
        ($result.BlockingReasons | Where-Object { $_ -match 'rollback readiness true' }) | Should -Not -BeNullOrEmpty
        ($result.BlockingReasons | Where-Object { $_ -match 'explicitly approve live mutation' }) | Should -Not -BeNullOrEmpty
    }

    It 'fails closed on invalid boolean strings' {
        $approval = New-Rev438ApprovalManifest -TenantId $script:TenantId -TargetObjectId $script:TargetServicePrincipalObjectId -DisplayName $script:TargetDisplayName -AppId $script:TargetAppId -RunId $script:RunId -RollbackReady 'maybe' -LiveMutationApproved 'nope'
        Write-TestJson -Path $script:ApprovalPath -InputObject $approval

        $result = & $script:ReadinessScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId
        $result.ReadyForWhatIf | Should -BeFalse
        ($result.BlockingReasons | Where-Object { $_ -match 'must be a boolean value' }) | Should -Not -BeNullOrEmpty
    }

    It 'produces a fresh artifact in a unique output folder' {
        $result = & $script:ReadinessScriptPath -TenantId $script:TenantId -InventoryPath $script:InventoryPath -ApprovalManifestPath $script:ApprovalPath -OutputPath $script:OutputPath -ConfirmLiveDisablePhrase $script:ApprovalPhrase -RunId $script:RunId
        $result.ReadyForWhatIf | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        (Split-Path -Parent $result.OutputArtifactPath) | Should -Be $script:OutputPath
        (Split-Path -Leaf $result.OutputArtifactPath) | Should -Be 'rev438-live-run-readiness.json'
    }

    It 'static scan confirms no live mutation or Remove-Mg calls' {
        $source = Get-Content -LiteralPath $script:ReadinessScriptPath -Raw
        $source | Should -Not -Match 'Update-MgServicePrincipal'
        $source | Should -Not -Match 'Remove-Mg'
    }
}
