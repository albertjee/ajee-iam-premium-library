#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [ValidateNotNullOrEmpty()]
    [string]$InventoryPath,

    [ValidateNotNullOrEmpty()]
    [string]$ApprovalManifestPath,

    [ValidateNotNullOrEmpty()]
    [string]$OutputPath,

    [ValidateNotNullOrEmpty()]
    [string]$ConfirmLiveDisablePhrase
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

function Assert-Rev438LabGate {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [object[]]$InventoryRecords,

        [Parameter(Mandatory)]
        [object]$ApprovalManifest,

        [Parameter(Mandatory)]
        [string]$ConfirmLiveDisablePhrase
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

    $controlRecord = if ($controlRecords.Count -ge 1) { $controlRecords[0] } else { $null }
    if ($null -ne $controlRecord) {
        if ([string]$controlRecord.ServicePrincipalObjectId -ne $script:ExpectedControlServicePrincipalObjectId) {
            $reasons.Add('Control object ServicePrincipalObjectId does not match the required value.')
        }
    }

    $targetObjectId = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $targetObjectIdsValue = Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectIds')
    $targetObjectIds = @()
    if ($null -ne $targetObjectIdsValue) {
        if ($targetObjectIdsValue -is [string]) {
            $targetObjectIds += $targetObjectIdsValue
        } elseif ($targetObjectIdsValue -is [System.Array]) {
            foreach ($item in $targetObjectIdsValue) {
                $targetObjectIds += $item
            }
        } else {
            $targetObjectIds += $targetObjectIdsValue
        }
    }
    $targetDisplayName = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetDisplayName', 'DisplayName'))
    $targetAppId = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('AppId'))
    $targetTenantId = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TenantId'))
    $approvedAction = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvalPhrase = [string](Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalPhrase', 'ConfirmLiveDisablePhrase'))
    $approvedActionsValue = Get-Rev438PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedActions')
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

    if ($null -ne $approvedActionsValue) {
        $approvedActions = @()
        if ($approvedActionsValue -is [string]) {
            $approvedActions = @([string]$approvedActionsValue)
        } elseif ($approvedActionsValue -is [System.Collections.IEnumerable]) {
            $approvedActions = @($approvedActionsValue | ForEach-Object { [string]$_ })
        } else {
            $approvedActions = @([string]$approvedActionsValue)
        }

        if ($approvedActions.Count -eq 0) {
            $reasons.Add('ApprovedActions must not be empty when present.')
        } elseif ($approvedActions.Count -gt 1) {
            $reasons.Add('ApprovedActions must contain exactly one value.')
        } else {
            $approvedActionFromArray = $approvedActions[0]
            if ($approvedActionFromArray -notin $script:AllowedApprovedActions) {
                $reasons.Add('ApprovedActions contains a disallowed value.')
            }
            if ($approvedAction -and $approvedAction -ne $approvedActionFromArray) {
                $reasons.Add('ApprovedAction and ApprovedActions must match.')
            }
            if (-not $approvedAction) {
                $approvedAction = $approvedActionFromArray
            }
        }
    }

    if ($targetObjectIds.Count -ne 1) {
        $reasons.Add('Approval manifest must contain exactly one TargetObjectId.')
    }

    if ($targetObjectId -ne $script:ExpectedTargetServicePrincipalObjectId) {
        $reasons.Add('Approval target object ID does not match the required value.')
    }

    if ($targetObjectIds.Count -eq 1 -and [string]$targetObjectIds[0] -ne $script:ExpectedTargetServicePrincipalObjectId) {
        $reasons.Add('Approval TargetObjectIds entry does not match the required value.')
    }

    if ($targetDisplayName -ne $script:ExpectedTargetDisplayName) {
        $reasons.Add('Approval target display name does not match the required value.')
    }

    if ($targetAppId -ne $script:ExpectedTargetAppId) {
        $reasons.Add('Approval target AppId does not match the required value.')
    }

    if ($targetTenantId -ne $script:ExpectedTenantId) {
        $reasons.Add('Approval tenant ID does not match the required value.')
    }

    if ($approvedAction -notin $script:AllowedApprovedActions) {
        $reasons.Add('Approval must authorize only ReversibleDisable or DisableOnly.')
    }

    if ($approvalPhrase -ne $script:ExpectedApprovalPhrase) {
        $reasons.Add('Approval manifest phrase does not match the required phrase.')
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

    [pscustomobject]@{
        Passed = $reasons.Count -eq 0
        Reasons = @($reasons)
        TargetRecord = $targetRecord
        ControlRecord = $controlRecord
        ApprovedAction = $approvedAction
        ApprovalPhrase = $approvalPhrase
        TargetObjectId = $targetObjectId
    }
}

function New-Rev438PreActionSnapshot {
    param(
        [Parameter(Mandatory)]
        [object]$TargetRecord,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$InventoryPath,

        [Parameter(Mandatory)]
        [string]$ApprovalManifestPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$RunId
    )

    $snapshot = [pscustomobject]@{
        SnapshotId = "REV438-SNAPSHOT-$RunId"
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        TenantId = $TenantId
        TargetDisplayName = [string]$TargetRecord.DisplayName
        TargetObjectId = [string]$TargetRecord.ServicePrincipalObjectId
        TargetAppId = [string]$TargetRecord.AppId
        ApplicationObjectId = [string]$TargetRecord.ApplicationObjectId
        PreActionAccountEnabled = $true
        ExpectedMutation = 'ServicePrincipal.AccountEnabled = false'
        ControlObjectPreserved = $true
        InventoryPath = $InventoryPath
        ApprovalManifestPath = $ApprovalManifestPath
        OutputPath = $OutputPath
        FinalDeleteBlocked = $true
        LiveMutationBlockedByWhatIf = [bool]$WhatIfPreference
    }

    $artifactPath = Join-Path $OutputPath 'rev438-preaction-snapshot.json'
    $snapshot | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev438JsonArtifact -Path $artifactPath -InputObject $snapshot) -Force
    return $snapshot
}

function New-Rev438RollbackPackage {
    param(
        [Parameter(Mandatory)]
        [object]$TargetRecord,

        [Parameter(Mandatory)]
        [object]$PreActionSnapshot,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$RunId
    )

    $package = [pscustomobject]@{
        RollbackPackageId = "REV438-ROLLBACK-$RunId"
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        TargetDisplayName = [string]$TargetRecord.DisplayName
        TargetObjectId = [string]$TargetRecord.ServicePrincipalObjectId
        TargetAppId = [string]$TargetRecord.AppId
        TargetType = 'ServicePrincipal'
        RollbackAction = 'ReEnableServicePrincipal'
        RollbackCommandPreview = "Update-MgServicePrincipal -ServicePrincipalId $([string]$TargetRecord.ServicePrincipalObjectId) -AccountEnabled:`$true"
        HumanApprovalRequired = $true
        WhatIf = [bool]$WhatIfPreference
        FinalDeleteAllowed = $false
        PreActionSnapshotPath = [string]$PreActionSnapshot.OutputArtifactPath
        ReEnableOnly = $true
        NoDelete = $true
        NoRemove = $true
        NoGrantCleanup = $true
        NoCredentialMutation = $true
        NoMetadataMutation = $true
    }

    $artifactPath = Join-Path $OutputPath 'rev438-rollback-package.json'
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev438JsonArtifact -Path $artifactPath -InputObject $package) -Force
    return $package
}

function Assert-Rev438RollbackPackage {
    param(
        [Parameter(Mandatory)]
        [object]$RollbackPackage
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $rollbackAction = [string](Get-Rev438PropertyValue -InputObject $RollbackPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    $rollbackPreview = [string](Get-Rev438PropertyValue -InputObject $RollbackPackage -PropertyNames @('RollbackCommandPreview', 'RollbackLiveCommandPreview'))
    $finalDeleteAllowed = [bool](Get-Rev438PropertyValue -InputObject $RollbackPackage -PropertyNames @('FinalDeleteAllowed') -Default $true)

    if ($rollbackAction -ne 'ReEnableServicePrincipal') {
        $reasons.Add('Rollback package must be re-enable only.')
    }

    if ($rollbackPreview -notmatch 'Update-MgServicePrincipal') {
        $reasons.Add('Rollback command preview must use Update-MgServicePrincipal.')
    }

    if ($rollbackPreview -match 'Remove-Mg') {
        $reasons.Add('Rollback command preview must not include Remove-Mg calls.')
    }

    if ($finalDeleteAllowed -ne $false) {
        $reasons.Add('Rollback package must not allow final delete.')
    }

    if ($reasons.Count -gt 0) {
        throw ($reasons -join ' ')
    }

    return $RollbackPackage
}

function Assert-Rev438ChangedObjectManifest {
    param(
        [Parameter(Mandatory)]
        [object]$ChangedObjectManifest,

        [Parameter(Mandatory)]
        [object]$TargetRecord,

        [Parameter(Mandatory)]
        [object]$ControlRecord
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $changedObjectIdsValue = Get-Rev438PropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('ChangedObjectIds')
    $changedObjectIds = @()
    if ($null -ne $changedObjectIdsValue) {
        if ($changedObjectIdsValue -is [string]) {
            $changedObjectIds += $changedObjectIdsValue
        } elseif ($changedObjectIdsValue -is [System.Array]) {
            foreach ($item in $changedObjectIdsValue) {
                $changedObjectIds += $item
            }
        } else {
            $changedObjectIds += $changedObjectIdsValue
        }
    }
    $changedObjectsValue = Get-Rev438PropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('ChangedObjects')
    $changedObjects = if ($null -eq $changedObjectsValue) { @() } else { @($changedObjectsValue) }

    if ($changedObjectIds.Count -ne 1) {
        $reasons.Add('Changed-object manifest must contain exactly one object ID.')
    }

    if ($changedObjectIds.Count -eq 1 -and [string]$changedObjectIds[0] -ne [string]$TargetRecord.ServicePrincipalObjectId) {
        $reasons.Add('Changed-object manifest object ID must match the target.')
    }

    if ($changedObjectIds -contains [string]$ControlRecord.ServicePrincipalObjectId) {
        $reasons.Add('Control object must not be included in the changed-object manifest.')
    }

    if ($changedObjects.Count -ne 1) {
        $reasons.Add('Changed-object manifest must contain exactly one object record.')
    } else {
        $changedObjectRecord = $changedObjects[0]
        if ([string](Get-Rev438PropertyValue -InputObject $changedObjectRecord -PropertyNames @('ObjectId')) -ne [string]$TargetRecord.ServicePrincipalObjectId) {
            $reasons.Add('Changed-object manifest record must match the target object ID.')
        }
    }

    if ($reasons.Count -gt 0) {
        throw ($reasons -join ' ')
    }

    return $ChangedObjectManifest
}

function New-Rev438ChangedObjectManifest {
    param(
        [Parameter(Mandatory)]
        [object]$TargetRecord,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$RunId
    )

    $manifest = [pscustomobject]@{
        ManifestId = "REV438-CHANGED-$RunId"
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        ChangedObjectIds = @([string]$TargetRecord.ServicePrincipalObjectId)
        ChangedObjects = @(
            [pscustomobject]@{
                ObjectId = [string]$TargetRecord.ServicePrincipalObjectId
                DisplayName = [string]$TargetRecord.DisplayName
                ObjectType = 'ServicePrincipal'
                ChangeType = 'AccountEnabled:false'
            }
        )
        ControlObjectIds = @()
        FinalDeleteAllowed = $false
    }

    $artifactPath = Join-Path $OutputPath 'rev438-changed-object-manifest.json'
    $manifest | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev438JsonArtifact -Path $artifactPath -InputObject $manifest) -Force
    return $manifest
}

function New-Rev438PostDisableValidationPackage {
    param(
        [Parameter(Mandatory)]
        [object]$TargetRecord,

        [Parameter(Mandatory)]
        [object]$PreActionSnapshot,

        [Parameter(Mandatory)]
        [object]$ChangedObjectManifest,

        [Parameter(Mandatory)]
        [object]$RollbackPackage,

        [Parameter()]
        [object]$MutationResult,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$RunId
    )

    $actualAccountEnabled = $false
    if ($MutationResult -and $MutationResult.PSObject.Properties['AccountEnabled']) {
        $actualAccountEnabled = [bool]$MutationResult.AccountEnabled
    }

    $package = [pscustomobject]@{
        ValidationPackageId = "REV438-VALIDATION-$RunId"
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        TargetDisplayName = [string]$TargetRecord.DisplayName
        TargetObjectId = [string]$TargetRecord.ServicePrincipalObjectId
        TargetAppId = [string]$TargetRecord.AppId
        TargetType = 'ServicePrincipal'
        PreActionSnapshotPath = [string]$PreActionSnapshot.OutputArtifactPath
        ChangedObjectManifestPath = [string]$ChangedObjectManifest.OutputArtifactPath
        RollbackPackagePath = [string]$RollbackPackage.OutputArtifactPath
        PreActionAccountEnabled = $true
        PostActionAccountEnabled = $actualAccountEnabled
        ExpectedAccountEnabledAfter = $false
        ActualMutationObserved = [bool](-not $WhatIfPreference)
        ValidationStatus = if ($WhatIfPreference) { 'Simulated' } elseif ($actualAccountEnabled -eq $false) { 'Passed' } else { 'Failed' }
        AccountEnabledOnlyChange = $actualAccountEnabled -eq $false
        ApplicationRegistrationUntouched = $true
        GrantsUntouched = $true
        CredentialsUntouched = $true
        MetadataUntouched = $true
        ControlObjectUntouched = $true
        FinalDeleteAllowed = $false
        RollbackRecommended = $false
    }

    $artifactPath = Join-Path $OutputPath 'rev438-post-disable-validation.json'
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev438JsonArtifact -Path $artifactPath -InputObject $package) -Force
    return $package
}

function Invoke-Rev438LabLiveReversibleDisable {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
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
        [string]$ConfirmLiveDisablePhrase
    )

    $inventoryDocument = Read-Rev438JsonDocument -Path $InventoryPath -Label 'Inventory'
    $approvalDocument = Read-Rev438JsonDocument -Path $ApprovalManifestPath -Label 'Approval manifest'
    $inventoryRecords = @(Get-Rev438InventoryRecords -InventoryDocument $inventoryDocument)
    $gate = Assert-Rev438LabGate -TenantId $TenantId -InventoryRecords $inventoryRecords -ApprovalManifest $approvalDocument -ConfirmLiveDisablePhrase $ConfirmLiveDisablePhrase

    $artifactDirectory = [System.IO.Path]::GetFullPath($OutputPath)
    if (-not (Test-Path -LiteralPath $artifactDirectory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $artifactDirectory -Force
    }

    if (-not $gate.Passed) {
        throw (($gate.Reasons -join ' '))
    }

    $runId = if ([string]::IsNullOrWhiteSpace([string](Get-Rev438PropertyValue -InputObject $approvalDocument -PropertyNames @('RunId')))) {
        "REV438-{0}" -f ([guid]::NewGuid().Guid)
    } else {
        [string](Get-Rev438PropertyValue -InputObject $approvalDocument -PropertyNames @('RunId'))
    }

    $preActionSnapshot = New-Rev438PreActionSnapshot -TargetRecord $gate.TargetRecord -TenantId $TenantId -InventoryPath $InventoryPath -ApprovalManifestPath $ApprovalManifestPath -OutputPath $artifactDirectory -RunId $runId
    $rollbackPackage = New-Rev438RollbackPackage -TargetRecord $gate.TargetRecord -PreActionSnapshot $preActionSnapshot -OutputPath $artifactDirectory -RunId $runId
    $changedObjectManifest = New-Rev438ChangedObjectManifest -TargetRecord $gate.TargetRecord -OutputPath $artifactDirectory -RunId $runId
    $null = Assert-Rev438ChangedObjectManifest -ChangedObjectManifest $changedObjectManifest -TargetRecord $gate.TargetRecord -ControlRecord $gate.ControlRecord
    $null = Assert-Rev438RollbackPackage -RollbackPackage $rollbackPackage

    $mutationResult = $null
    $liveMutationPerformed = $false
    if ($PSCmdlet.ShouldProcess($gate.TargetRecord.ServicePrincipalObjectId, 'Set service principal AccountEnabled to false')) {
        $mutationResult = Update-MgServicePrincipal -ServicePrincipalId ([string]$gate.TargetRecord.ServicePrincipalObjectId) -AccountEnabled:$false
        $liveMutationPerformed = $true
    }

    $postDisableValidation = New-Rev438PostDisableValidationPackage -TargetRecord $gate.TargetRecord -PreActionSnapshot $preActionSnapshot -ChangedObjectManifest $changedObjectManifest -RollbackPackage $rollbackPackage -MutationResult $mutationResult -OutputPath $artifactDirectory -RunId $runId

    $summary = [pscustomobject]@{
        BranchName = 'fix/rev438-lab-live-reversible-disable-gate'
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        RunId = $runId
        TenantId = $TenantId
        InventoryPath = $InventoryPath
        ApprovalManifestPath = $ApprovalManifestPath
        OutputPath = $artifactDirectory
        TargetDisplayName = [string]$gate.TargetRecord.DisplayName
        TargetObjectId = [string]$gate.TargetRecord.ServicePrincipalObjectId
        TargetAppId = [string]$gate.TargetRecord.AppId
        ControlObjectDisplayName = $script:ExpectedControlDisplayName
        ControlObjectUntouched = $true
        LiveMutationAllowed = $true
        LiveMutationPerformed = $liveMutationPerformed
        WhatIf = [bool]$WhatIfPreference
        ApprovedAction = [string]$gate.ApprovedAction
        ApprovalPhrase = [string]$gate.ApprovalPhrase
        FinalDeleteAllowed = $false
        NoDeletePath = $true
        NoRollbackExecution = $true
        NoCleanupExecution = $true
        SafetyGatePassed = $true
        Artifacts = [pscustomobject]@{
            PreActionSnapshot = $preActionSnapshot.OutputArtifactPath
            RollbackPackage = $rollbackPackage.OutputArtifactPath
            ChangedObjectManifest = $changedObjectManifest.OutputArtifactPath
            PostDisableValidation = $postDisableValidation.OutputArtifactPath
        }
        Gates = @(
            [pscustomobject]@{ Name = 'TenantId'; Passed = $TenantId -eq $script:ExpectedTenantId },
            [pscustomobject]@{ Name = 'TargetObjectId'; Passed = [string]$gate.TargetRecord.ServicePrincipalObjectId -eq $script:ExpectedTargetServicePrincipalObjectId },
            [pscustomobject]@{ Name = 'TargetDisplayName'; Passed = [string]$gate.TargetRecord.DisplayName -eq $script:ExpectedTargetDisplayName },
            [pscustomobject]@{ Name = 'TargetAppId'; Passed = [string]$gate.TargetRecord.AppId -eq $script:ExpectedTargetAppId },
            [pscustomobject]@{ Name = 'ApprovalPhrase'; Passed = $gate.ApprovalPhrase -eq $script:ExpectedApprovalPhrase },
            [pscustomobject]@{ Name = 'RollbackReady'; Passed = [bool](Get-Rev438PropertyValue -InputObject $approvalDocument -PropertyNames @('RollbackReady') -Default $false) }
        )
    }

    $summaryPath = Join-Path $artifactDirectory 'rev438-run-summary.json'
    $summary | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev438JsonArtifact -Path $summaryPath -InputObject $summary) -Force
    return $summary
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Rev438LabLiveReversibleDisable @PSBoundParameters
}
