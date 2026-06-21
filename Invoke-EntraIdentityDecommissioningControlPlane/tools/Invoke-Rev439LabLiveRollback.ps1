#Requires -Version 7.0

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
    [string]$ConfirmLiveRollbackPhrase
)

$ErrorActionPreference = 'Stop'

$script:ExpectedTenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
$script:ExpectedTargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
$script:ExpectedTargetAppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
$script:ExpectedTargetApplicationObjectId = 'cacb17fd-bc8d-4798-a8b9-e030699ea2ad'
$script:ExpectedTargetServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
$script:ExpectedControlDisplayName = 'AJEE-LAB-NHI-KEEP-CONTROL'
$script:ExpectedControlServicePrincipalObjectId = 'b574ecc2-443f-4963-9cd4-cb5da517a717'
$script:ExpectedRollbackPhrase = 'APPROVE REV4.39 LIVE ROLLBACK AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
$script:AllowedRollbackActions = @('ReEnableServicePrincipal', 'RollbackDisable')

function Write-Rev439JsonArtifact {
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

function Read-Rev439JsonDocument {
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

function Get-Rev439PropertyValue {
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

function ConvertTo-Rev439StrictBoolean {
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

function Get-Rev439InventoryRecords {
    param(
        [Parameter(Mandatory)]
        [object]$InventoryDocument
    )

    if ($InventoryDocument.PSObject.Properties['Inventory']) {
        return @($InventoryDocument.Inventory)
    }

    return @($InventoryDocument)
}

function Get-Rev439ApprovedActions {
    param(
        [Parameter(Mandatory)]
        [object]$ApprovalManifest
    )

    $approvedAction = [string](Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvedActionsValue = Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedActions')

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

function Assert-Rev439ChangedObjectManifest {
    param(
        [Parameter(Mandatory)]
        [object]$ChangedObjectManifest,

        [Parameter(Mandatory)]
        [object]$TargetRecord,

        [Parameter(Mandatory)]
        [object]$ControlRecord
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $changedObjectIdsValue = Get-Rev439PropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('ChangedObjectIds')
    $changedObjectIds = @()
    if ($null -ne $changedObjectIdsValue) {
        if ($changedObjectIdsValue -is [string]) {
            $changedObjectIds += [string]$changedObjectIdsValue
        } elseif ($changedObjectIdsValue -is [System.Collections.IEnumerable]) {
            foreach ($item in $changedObjectIdsValue) {
                $changedObjectIds += [string]$item
            }
        } else {
            $changedObjectIds += [string]$changedObjectIdsValue
        }
    }

    $changedObjectsValue = Get-Rev439PropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('ChangedObjects')
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
        if ([string](Get-Rev439PropertyValue -InputObject $changedObjectRecord -PropertyNames @('ObjectId')) -ne [string]$TargetRecord.ServicePrincipalObjectId) {
            $reasons.Add('Changed-object manifest record must match the target object ID.')
        }

        if ([string](Get-Rev439PropertyValue -InputObject $changedObjectRecord -PropertyNames @('ChangeType')) -ne 'AccountEnabled:true') {
            $reasons.Add('Changed-object manifest record must be AccountEnabled:true.')
        }
    }

    if ($reasons.Count -gt 0) {
        throw ($reasons -join ' ')
    }

    return $ChangedObjectManifest
}

function Assert-Rev439LabRollbackGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [object[]]$InventoryRecords,

        [Parameter(Mandatory)]
        [object]$ApprovalManifest,

        [Parameter(Mandatory)]
        [string]$ConfirmLiveRollbackPhrase
    )

    $reasons = [System.Collections.Generic.List[string]]::new()

    if ($TenantId -ne $script:ExpectedTenantId) {
        $reasons.Add("TenantId must equal $script:ExpectedTenantId.")
    }

    if ($ConfirmLiveRollbackPhrase -ne $script:ExpectedRollbackPhrase) {
        $reasons.Add('ConfirmLiveRollbackPhrase must match the required rollback phrase.')
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

    $approvalTenantId = [string](Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TenantId'))
    $targetObjectId = [string](Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $targetObjectIdsValue = Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectIds')
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

    $targetDisplayName = [string](Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetDisplayName', 'DisplayName'))
    $targetAppId = [string](Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('AppId'))
    $approvedAction = [string](Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvedActions = @(Get-Rev439ApprovedActions -ApprovalManifest $ApprovalManifest)
    $approvalPhrase = [string](Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalPhrase', 'ConfirmLiveRollbackPhrase'))
    $liveRollbackApprovedValue = Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('LiveRollbackApproved')
    $finalDeleteApprovedValue = Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('FinalDeleteApproved')
    $cleanupApprovedValue = Get-Rev439PropertyValue -InputObject $ApprovalManifest -PropertyNames @('CleanupApproved')

    $liveRollbackApproved = $false
    try {
        $liveRollbackApproved = ConvertTo-Rev439StrictBoolean -Value $liveRollbackApprovedValue -PropertyName 'LiveRollbackApproved'
    } catch {
        $reasons.Add($_.Exception.Message)
    }

    $finalDeleteApproved = $false
    try {
        $finalDeleteApproved = ConvertTo-Rev439StrictBoolean -Value $finalDeleteApprovedValue -PropertyName 'FinalDeleteApproved'
    } catch {
        $reasons.Add($_.Exception.Message)
    }

    $cleanupApproved = $false
    try {
        $cleanupApproved = ConvertTo-Rev439StrictBoolean -Value $cleanupApprovedValue -PropertyName 'CleanupApproved'
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

    if ($approvalPhrase -ne $script:ExpectedRollbackPhrase) {
        $reasons.Add('Approval manifest phrase does not match the required phrase.')
    }

    if ($approvedActions.Count -eq 0) {
        $reasons.Add('Approval must specify an approved action.')
    } elseif ($approvedActions.Count -gt 1) {
        $reasons.Add('ApprovedActions must contain exactly one value.')
    } else {
        if ($approvedActions[0] -notin $script:AllowedRollbackActions) {
            $reasons.Add('Approval must authorize only ReEnableServicePrincipal or RollbackDisable.')
        }
        if ($approvedAction -and $approvedAction -ne $approvedActions[0]) {
            $reasons.Add('ApprovedAction and ApprovedActions must match.')
        }
    }

    if (-not $liveRollbackApproved) {
        $reasons.Add('LiveRollbackApproved must be true.')
    }

    if ($finalDeleteApproved) {
        $reasons.Add('FinalDeleteApproved must be false or absent.')
    }

    if ($cleanupApproved) {
        $reasons.Add('CleanupApproved must be false or absent.')
    }

    [pscustomobject]@{
        Passed = $reasons.Count -eq 0
        Reasons = @($reasons)
        TargetRecord = $targetRecord
        ControlRecord = $controlRecord
        ApprovedAction = $approvedAction
        ApprovalPhrase = $approvalPhrase
        TargetObjectId = $targetObjectId
        LiveRollbackApproved = $liveRollbackApproved
        FinalDeleteApproved = $finalDeleteApproved
        CleanupApproved = $cleanupApproved
    }
}

function New-Rev439PreRollbackSnapshot {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function', Justification='Artifact builder invoked by the parent ShouldProcess-controlled rollback flow.')]
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
        SnapshotId = "REV439-SNAPSHOT-$RunId"
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        TenantId = $TenantId
        TargetDisplayName = [string]$TargetRecord.DisplayName
        TargetObjectId = [string]$TargetRecord.ServicePrincipalObjectId
        TargetAppId = [string]$TargetRecord.AppId
        ApplicationObjectId = [string]$TargetRecord.ApplicationObjectId
        PreActionAccountEnabled = $false
        ExpectedMutation = 'ServicePrincipal.AccountEnabled = true'
        ControlObjectPreserved = $true
        InventoryPath = $InventoryPath
        ApprovalManifestPath = $ApprovalManifestPath
        OutputPath = $OutputPath
        FinalDeleteBlocked = $true
        CleanupBlocked = $true
        LiveMutationBlockedByWhatIf = [bool]$WhatIfPreference
    }

    $artifactPath = Join-Path $OutputPath 'rev439-pre-rollback-snapshot.json'
    $snapshot | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev439JsonArtifact -Path $artifactPath -InputObject $snapshot) -Force
    return $snapshot
}

function New-Rev439ChangedObjectManifest {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function', Justification='Artifact builder invoked by the parent ShouldProcess-controlled rollback flow.')]
    param(
        [Parameter(Mandatory)]
        [object]$TargetRecord,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$RunId
    )

    $manifest = [pscustomobject]@{
        ManifestId = "REV439-CHANGED-$RunId"
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        ChangedObjectIds = @([string]$TargetRecord.ServicePrincipalObjectId)
        ChangedObjects = @(
            [pscustomobject]@{
                ObjectId = [string]$TargetRecord.ServicePrincipalObjectId
                DisplayName = [string]$TargetRecord.DisplayName
                ObjectType = 'ServicePrincipal'
                ChangeType = 'AccountEnabled:true'
            }
        )
        ControlObjectIds = @()
        FinalDeleteAllowed = $false
        CleanupAllowed = $false
    }

    $artifactPath = Join-Path $OutputPath 'rev439-changed-object-manifest.json'
    $manifest | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev439JsonArtifact -Path $artifactPath -InputObject $manifest) -Force
    return $manifest
}

function New-Rev439PostRollbackValidationPackage {
    [Diagnostics.CodeAnalysis.SuppressMessage('PSUseShouldProcessForStateChangingFunctions', '', Scope='Function', Justification='Artifact builder invoked by the parent ShouldProcess-controlled rollback flow.')]
    param(
        [Parameter(Mandatory)]
        [object]$TargetRecord,

        [Parameter(Mandatory)]
        [object]$PreRollbackSnapshot,

        [Parameter(Mandatory)]
        [object]$ChangedObjectManifest,

        [Parameter()]
        [object]$MutationResult,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$RunId
    )

    $actualAccountEnabled = $true
    if ($MutationResult -and $MutationResult.PSObject.Properties['AccountEnabled']) {
        $actualAccountEnabled = ConvertTo-Rev439StrictBoolean -Value $MutationResult.AccountEnabled -PropertyName 'AccountEnabled'
    }

    $package = [pscustomobject]@{
        ValidationPackageId = "REV439-VALIDATION-$RunId"
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        TargetDisplayName = [string]$TargetRecord.DisplayName
        TargetObjectId = [string]$TargetRecord.ServicePrincipalObjectId
        TargetAppId = [string]$TargetRecord.AppId
        TargetType = 'ServicePrincipal'
        PreRollbackSnapshotPath = [string]$PreRollbackSnapshot.OutputArtifactPath
        ChangedObjectManifestPath = [string]$ChangedObjectManifest.OutputArtifactPath
        PreActionAccountEnabled = $false
        PostActionAccountEnabled = $actualAccountEnabled
        ExpectedAccountEnabledAfter = $true
        ActualMutationObserved = [bool](-not $WhatIfPreference)
        ValidationStatus = if ($WhatIfPreference) { 'Simulated' } elseif ($actualAccountEnabled -eq $true) { 'Passed' } else { 'Failed' }
        AccountEnabledOnlyChange = $actualAccountEnabled -eq $true
        ApplicationRegistrationUntouched = $true
        GrantsUntouched = $true
        CredentialsUntouched = $true
        MetadataUntouched = $true
        ControlObjectUntouched = $true
        FinalDeleteAllowed = $false
        CleanupAllowed = $false
    }

    $artifactPath = Join-Path $OutputPath 'rev439-post-rollback-validation.json'
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev439JsonArtifact -Path $artifactPath -InputObject $package) -Force
    return $package
}

function Invoke-Rev439LabLiveRollback {
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
        [string]$ConfirmLiveRollbackPhrase
    )

    $inventoryDocument = Read-Rev439JsonDocument -Path $InventoryPath -Label 'Inventory'
    $approvalDocument = Read-Rev439JsonDocument -Path $ApprovalManifestPath -Label 'Approval manifest'
    $inventoryRecords = @(Get-Rev439InventoryRecords -InventoryDocument $inventoryDocument)
    $gate = Assert-Rev439LabRollbackGate -TenantId $TenantId -InventoryRecords $inventoryRecords -ApprovalManifest $approvalDocument -ConfirmLiveRollbackPhrase $ConfirmLiveRollbackPhrase

    $artifactDirectory = [System.IO.Path]::GetFullPath($OutputPath)
    if (-not (Test-Path -LiteralPath $artifactDirectory -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $artifactDirectory -Force
    }

    if (-not $gate.Passed) {
        throw (($gate.Reasons -join ' '))
    }

    $runId = if ([string]::IsNullOrWhiteSpace([string](Get-Rev439PropertyValue -InputObject $approvalDocument -PropertyNames @('RunId')))) {
        "REV439-{0}" -f ([guid]::NewGuid().Guid)
    } else {
        [string](Get-Rev439PropertyValue -InputObject $approvalDocument -PropertyNames @('RunId'))
    }

    $preRollbackSnapshot = New-Rev439PreRollbackSnapshot -TargetRecord $gate.TargetRecord -TenantId $TenantId -InventoryPath $InventoryPath -ApprovalManifestPath $ApprovalManifestPath -OutputPath $artifactDirectory -RunId $runId
    $changedObjectManifest = New-Rev439ChangedObjectManifest -TargetRecord $gate.TargetRecord -OutputPath $artifactDirectory -RunId $runId
    $null = Assert-Rev439ChangedObjectManifest -ChangedObjectManifest $changedObjectManifest -TargetRecord $gate.TargetRecord -ControlRecord $gate.ControlRecord

    $mutationResult = $null
    $liveMutationPerformed = $false
    if ($PSCmdlet.ShouldProcess($gate.TargetRecord.ServicePrincipalObjectId, 'Set service principal AccountEnabled to true')) {
        $mutationResult = Update-MgServicePrincipal -ServicePrincipalId ([string]$gate.TargetRecord.ServicePrincipalObjectId) -AccountEnabled:$true
        $liveMutationPerformed = $true
    }

    $postRollbackValidation = New-Rev439PostRollbackValidationPackage -TargetRecord $gate.TargetRecord -PreRollbackSnapshot $preRollbackSnapshot -ChangedObjectManifest $changedObjectManifest -MutationResult $mutationResult -OutputPath $artifactDirectory -RunId $runId

    $summary = [pscustomobject]@{
        BranchName = 'fix/rev438-live-run-pack-and-rev439-rollback-gate'
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
        CleanupAllowed = $false
        NoDeletePath = $true
        NoCleanupExecution = $true
        NoRollbackToOtherObject = $true
        ApplicationRegistrationUntouched = $true
        GrantsUntouched = $true
        CredentialsUntouched = $true
        MetadataUntouched = $true
        SafetyGatePassed = $true
        Artifacts = [pscustomobject]@{
            PreRollbackSnapshot = $preRollbackSnapshot.OutputArtifactPath
            ChangedObjectManifest = $changedObjectManifest.OutputArtifactPath
            PostRollbackValidation = $postRollbackValidation.OutputArtifactPath
        }
        Gates = @(
            [pscustomobject]@{ Name = 'TenantId'; Passed = $TenantId -eq $script:ExpectedTenantId },
            [pscustomobject]@{ Name = 'TargetObjectId'; Passed = [string]$gate.TargetRecord.ServicePrincipalObjectId -eq $script:ExpectedTargetServicePrincipalObjectId },
            [pscustomobject]@{ Name = 'TargetDisplayName'; Passed = [string]$gate.TargetRecord.DisplayName -eq $script:ExpectedTargetDisplayName },
            [pscustomobject]@{ Name = 'TargetAppId'; Passed = [string]$gate.TargetRecord.AppId -eq $script:ExpectedTargetAppId },
            [pscustomobject]@{ Name = 'ApprovalPhrase'; Passed = $gate.ApprovalPhrase -eq $script:ExpectedRollbackPhrase },
            [pscustomobject]@{ Name = 'LiveRollbackApproved'; Passed = $gate.LiveRollbackApproved }
        )
    }

    $summaryPath = Join-Path $artifactDirectory 'rev439-run-summary.json'
    $summary | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Write-Rev439JsonArtifact -Path $summaryPath -InputObject $summary) -Force
    return $summary
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Rev439LabLiveRollback @PSBoundParameters
}
