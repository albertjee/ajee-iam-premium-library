#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$InventoryPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApprovalManifestPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ConfirmLiveDisablePhrase,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RunId = ('REV438-' + [guid]::NewGuid().ToString('N'))
)

$ErrorActionPreference = 'Stop'

$script:ExpectedTenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
$script:ExpectedTargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
$script:ExpectedTargetAppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
$script:ExpectedTargetApplicationObjectId = 'cacb17fd-bc8d-4798-a8b9-e030699ea2ad'
$script:ExpectedTargetServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
$script:ExpectedControlDisplayName = 'AJEE-LAB-NHI-KEEP-CONTROL'
$script:ExpectedControlServicePrincipalObjectId = 'b574ecc2-443f-4963-9cd4-cb5da517a717'
$script:ExpectedApprovalPhrase = 'APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
$script:AllowedApprovedActions = @('ReversibleDisable', 'DisableOnly')

function Write-Rev438JsonArtifact {
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

    $json = $InputObject | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    return $Path
}

function Read-Rev438JsonDocument {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label file '$Path' was not found."
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "$Label file '$Path' is empty."
    }

    try {
        return $raw | ConvertFrom-Json
    } catch {
        throw "$Label file '$Path' is not valid JSON."
    }
}

function Get-Rev438PropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$PropertyNames,

        [Parameter()]
        [object]$Default = $null
    )

    foreach ($propertyName in $PropertyNames) {
        if ($InputObject.PSObject.Properties[$propertyName]) {
            return $InputObject.$propertyName
        }
    }

    return $Default
}

function ConvertTo-Rev438StrictBoolean {
    param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter(Mandatory)]
        [string]$PropertyName
    )

    if ($null -eq $Value) {
        throw "$PropertyName must be a boolean value."
    }

    if ($Value -is [bool]) {
        return [bool]$Value
    }

    if ($Value -is [string]) {
        switch ($Value.Trim().ToLowerInvariant()) {
            'true' { return $true }
            'false' { return $false }
        }
    }

    throw "$PropertyName must be a boolean value."
}

function Get-Rev438InventoryRecords {
    param(
        [Parameter(Mandatory)]
        [object]$InventoryDocument
    )

    if ($InventoryDocument.PSObject.Properties['Inventory']) {
        return @($InventoryDocument.Inventory)
    }

    return @($InventoryDocument)
}

function Get-Rev438ApprovedActions {
    param(
        [Parameter(Mandatory)]
        [object]$ApprovalManifest
    )

    $approvedAction = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvedActionsValue = Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedActions')

    if ($null -eq $approvedActionsValue) {
        if ([string]::IsNullOrWhiteSpace($approvedAction)) {
            return @()
        }
        return @($approvedAction)
    }

    if ($approvedActionsValue -is [string]) {
        return @([string]$approvedActionsValue)
    }

    if ($approvedActionsValue -is [System.Collections.IEnumerable]) {
        return @($approvedActionsValue | ForEach-Object { [string]$_ })
    }

    return @([string]$approvedActionsValue)
}

function Assert-Rev438LiveRunReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [object[]]$InventoryRecords,

        [Parameter(Mandatory)]
        [object]$ApprovalManifest,

        [Parameter(Mandatory)]
        [string]$ConfirmLiveDisablePhrase,

        [Parameter(Mandatory)]
        [string]$InventoryPath,

        [Parameter(Mandatory)]
        [string]$ApprovalManifestPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$RunId
    )

    $reasons = [System.Collections.Generic.List[string]]::new()

    if ($TenantId -ne $script:ExpectedTenantId) {
        $reasons.Add("TenantId must equal $script:ExpectedTenantId.")
    }

    if ($ConfirmLiveDisablePhrase -ne $script:ExpectedApprovalPhrase) {
        $reasons.Add('ConfirmLiveDisablePhrase must match the required approval phrase.')
    }

    $targetRecords = @($InventoryRecords | Where-Object { [string]$_.DisplayName -eq $script:ExpectedTargetDisplayName })
    if ($targetRecords.Count -ne 1) {
        $reasons.Add('Inventory must contain exactly one AJEE-LAB-NHI-DISABLE-ROLLBACK record.')
    }

    $controlRecords = @($InventoryRecords | Where-Object { [string]$_.DisplayName -eq $script:ExpectedControlDisplayName })
    if ($controlRecords.Count -ne 1) {
        $reasons.Add('Inventory must contain the AJEE-LAB-NHI-KEEP-CONTROL record.')
    }

    $targetRecord = if ($targetRecords.Count -eq 1) { $targetRecords[0] } else { $null }
    $controlRecord = if ($controlRecords.Count -eq 1) { $controlRecords[0] } else { $null }

    if ($null -ne $targetRecord) {
        if ([string]$targetRecord.ServicePrincipalObjectId -ne $script:ExpectedTargetServicePrincipalObjectId) {
            $reasons.Add('Target ServicePrincipalObjectId does not match the required value.')
        }
        if ([string]$targetRecord.DisplayName -ne $script:ExpectedTargetDisplayName) {
            $reasons.Add('Target DisplayName does not match the required value.')
        }
        if ([string]$targetRecord.AppId -ne $script:ExpectedTargetAppId) {
            $reasons.Add('Target AppId does not match the required value.')
        }
        if ([string]$targetRecord.ApplicationObjectId -ne $script:ExpectedTargetApplicationObjectId) {
            $reasons.Add('Target ApplicationObjectId does not match the required value.')
        }
        if ([string]$targetRecord.TenantId -ne $script:ExpectedTenantId) {
            $reasons.Add('Target TenantId does not match the required value.')
        }
    }

    if ($null -ne $controlRecord) {
        if ([string]$controlRecord.ServicePrincipalObjectId -ne $script:ExpectedControlServicePrincipalObjectId) {
            $reasons.Add('Control object ServicePrincipalObjectId does not match the required value.')
        }
    }

    $approvalTenantId = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TenantId'))
    $targetObjectId = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $targetObjectIdsValue = Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectIds')
    $targetObjectIds = @()
    if ($null -ne $targetObjectIdsValue) {
        if ($targetObjectIdsValue -is [string]) {
            $targetObjectIds += [string]$targetObjectIdsValue
        } elseif ($targetObjectIdsValue -is [System.Collections.IEnumerable]) {
            foreach ($item in $targetObjectIdsValue) {
                $targetObjectIds += [string]$item
            }
        } else {
            $targetObjectIds += [string]$targetObjectIdsValue
        }
    }

    $targetDisplayName = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetDisplayName', 'DisplayName'))
    $targetAppId = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('AppId'))
    $approvedAction = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvedActions = @(Get-Rev438ApprovedActions -ApprovalManifest $ApprovalManifest)
    $approvalPhrase = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalPhrase', 'ConfirmLiveDisablePhrase'))
    $rollbackReadyValue = Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('RollbackReady')
    $liveMutationApprovedValue = Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('LiveMutationApproved')
    $finalDeleteApprovedValue = Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('FinalDeleteApproved')

    $rollbackReady = $false
    try {
        $rollbackReady = ConvertTo-Rev438StrictBoolean -Value $rollbackReadyValue -PropertyName 'RollbackReady'
    } catch {
        $reasons.Add($_.Exception.Message)
    }

    $liveMutationApproved = $false
    try {
        $liveMutationApproved = ConvertTo-Rev438StrictBoolean -Value $liveMutationApprovedValue -PropertyName 'LiveMutationApproved'
    } catch {
        $reasons.Add($_.Exception.Message)
    }

    $finalDeleteApproved = $false
    try {
        $finalDeleteApproved = ConvertTo-Rev438StrictBoolean -Value $finalDeleteApprovedValue -PropertyName 'FinalDeleteApproved'
    } catch {
        $reasons.Add($_.Exception.Message)
    }

    if ($approvalTenantId -ne $script:ExpectedTenantId) {
        $reasons.Add('Approval TenantId must match the required value.')
    }

    if ($targetObjectIds.Count -ne 1) {
        $reasons.Add('Approval manifest must contain exactly one TargetObjectId.')
    } elseif ([string]$targetObjectIds[0] -ne $script:ExpectedTargetServicePrincipalObjectId) {
        $reasons.Add('Approval TargetObjectIds entry does not match the required value.')
    }

    if ($targetObjectId -ne $script:ExpectedTargetServicePrincipalObjectId) {
        $reasons.Add('Approval target object ID does not match the required value.')
    }

    if ($targetDisplayName -ne $script:ExpectedTargetDisplayName) {
        $reasons.Add('Approval target display name does not match the required value.')
    }

    if ($targetAppId -ne $script:ExpectedTargetAppId) {
        $reasons.Add('Approval target AppId does not match the required value.')
    }

    if ($approvalPhrase -ne $script:ExpectedApprovalPhrase) {
        $reasons.Add('Approval manifest phrase does not match the required approval phrase.')
    }

    if ($approvalPhrase -ne $script:ExpectedApprovalPhrase) {
        $reasons.Add('Approval manifest phrase does not match the required phrase.')
    }

    if ($approvedActions.Count -eq 0) {
        $reasons.Add('Approval must specify an approved action.')
    } elseif ($approvedActions.Count -gt 1) {
        $reasons.Add('ApprovedActions must contain exactly one value.')
    } else {
        if ($approvedActions[0] -notin $script:AllowedApprovedActions) {
            $reasons.Add('Approval must authorize only ReversibleDisable or DisableOnly.')
        }
        if ($approvedAction -and $approvedAction -ne $approvedActions[0]) {
            $reasons.Add('ApprovedAction and ApprovedActions must match.')
        }
    }

    if (-not $rollbackReady) {
        $reasons.Add('Approval manifest must mark rollback readiness true.')
    }

    if (-not $liveMutationApproved) {
        $reasons.Add('Approval manifest must explicitly approve live mutation.')
    }

    if ($finalDeleteApproved) {
        $reasons.Add('FinalDelete must not be approved.')
    }

    $readyForWhatIf = $reasons.Count -eq 0

    $controlObjectId = if ($null -ne $controlRecord) { [string]$controlRecord.ServicePrincipalObjectId } else { $script:ExpectedControlServicePrincipalObjectId }

    $artifact = [pscustomobject]@{
        SchemaVersion = '4.38'
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        TenantId = $TenantId
        InventoryPath = $InventoryPath
        ApprovalManifestPath = $ApprovalManifestPath
        OutputPath = $OutputPath
        TargetObjectId = [string]$targetObjectId
        ControlObjectId = [string]$controlObjectId
        ReadyForWhatIf = $readyForWhatIf
        ReadyForLiveDisable = $readyForWhatIf
        BlockingReasons = @($reasons)
        ApprovalChecks = [pscustomobject]@{
            ApprovedAction = $approvedAction
            ApprovedActions = @($approvedActions)
            RollbackReady = $rollbackReady
            LiveMutationApproved = $liveMutationApproved
            FinalDeleteApproved = $finalDeleteApproved
        }
    }

    $artifactPath = Join-Path $OutputPath 'rev438-live-run-readiness.json'
    $artifact | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev438JsonArtifact -Path $artifactPath -InputObject $artifact) -Force
    return $artifact
}

function Invoke-Rev438LabLiveDisableReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$InventoryPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApprovalManifestPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfirmLiveDisablePhrase,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId
    )

    $inventoryDocument = Read-Rev438JsonDocument -Path $InventoryPath -Label 'Inventory'
    $approvalDocument = Read-Rev438JsonDocument -Path $ApprovalManifestPath -Label 'Approval manifest'
    $inventoryRecords = @(Get-Rev438InventoryRecords -InventoryDocument $inventoryDocument)
    return Assert-Rev438LiveRunReadiness -TenantId $TenantId -InventoryRecords $inventoryRecords -ApprovalManifest $approvalDocument -ConfirmLiveDisablePhrase $ConfirmLiveDisablePhrase -InventoryPath $InventoryPath -ApprovalManifestPath $ApprovalManifestPath -OutputPath $OutputPath -RunId $RunId
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Rev438LabLiveDisableReadiness @PSBoundParameters
}
