[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$BatchManifestPath,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputRoot,

    [Parameter()]
    [ValidateSet('Readiness', 'WhatIf', 'Execute', 'Verify', 'Closeout')]
    [string]$Mode = 'WhatIf',

    [Parameter()]
    [ValidateRange(1, 3)]
    [int]$MaxObjectsPerWave = 3,

    [Parameter()]
    [bool]$StopOnFirstFailure = $true,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApprovalPhrase
)

$script:WrapperVersion = 'Rev4.42'
$script:ApprovedAction = 'ReversibleDisable'
$script:BatchSchemaVersion = 'Rev4.42-BatchReversibleDisable'
$script:SingleObjectLifecycleScriptPath = Join-Path $PSScriptRoot 'Start-NhiSingleObjectLifecycle.ps1'

function Write-BatchJsonArtifact {
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

function Read-BatchJsonDocument {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "STOP: $Label file '$Path' was not found."
    }

    return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Get-BatchInventoryRecords {
    param(
        [Parameter(Mandatory)]
        [object]$InventoryDocument
    )

    if ($null -ne $InventoryDocument.Inventory) {
        return @($InventoryDocument.Inventory)
    }

    if ($InventoryDocument -is [System.Array]) {
        return @($InventoryDocument)
    }

    return @($InventoryDocument)
}

function Get-BatchPropertyValue {
    param(
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$PropertyNames,

        [object]$Default = $null
    )

    foreach ($propertyName in $PropertyNames) {
        $member = $InputObject.PSObject.Properties[$propertyName]
        if ($null -ne $member) {
            return $member.Value
        }
    }

    return $Default
}

function Test-BatchBooleanValue {
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
        switch ($Value.ToLowerInvariant()) {
            'true' { return $true }
            'false' { return $false }
        }
    }

    throw "STOP: $PropertyName must be a strict boolean value."
}

function Test-BatchIdValue {
    param(
        [Parameter(Mandatory)]
        [string]$BatchId,

        [Parameter()]
        [string]$Label = 'BatchId'
    )

    if ([string]::IsNullOrWhiteSpace($BatchId)) {
        throw "STOP: $Label is required."
    }

    if ($BatchId -match '[\\/]' -or $BatchId -match '\.\.') {
        throw "STOP: $Label contains unsafe path content."
    }

    if ($BatchId -notmatch '^[A-Za-z0-9._-]+$') {
        throw "STOP: $Label contains unsupported characters."
    }

    return $BatchId
}

function Test-BatchWhatIfEvidence {
    param(
        [Parameter(Mandatory)]
        [string]$EvidencePath,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$ServicePrincipalObjectId,

        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter(Mandatory)]
        [string]$ApprovedAction,

        [Parameter(Mandatory)]
        [string]$PriorWhatIfRunRoot
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $evidence = Read-BatchJsonDocument -Path $EvidencePath -Label 'WhatIf evidence'
    $evidenceTenantId = [string](Get-BatchPropertyValue -InputObject $evidence -PropertyNames @('TenantId'))
    $evidenceObjectId = [string](Get-BatchPropertyValue -InputObject $evidence -PropertyNames @('ServicePrincipalObjectId', 'TargetObjectId', 'ObjectId'))
    $evidenceAppId = [string](Get-BatchPropertyValue -InputObject $evidence -PropertyNames @('AppId'))
    $evidenceApprovedAction = [string](Get-BatchPropertyValue -InputObject $evidence -PropertyNames @('ApprovedAction', 'ActionType'))
    $evidenceWhatIf = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $evidence -PropertyNames @('WhatIf', 'WhatIfMode') -Default $false) -PropertyName 'WhatIf'
    $evidenceLiveMutationPerformed = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $evidence -PropertyNames @('LiveMutationPerformed', 'LiveMutationAllowed') -Default $false) -PropertyName 'LiveMutationPerformed'
    $evidenceSourceRunRoot = [string](Get-BatchPropertyValue -InputObject $evidence -PropertyNames @('SourceBatchRunRoot', 'PriorWhatIfRunRoot', 'BatchRunRoot'))
    $priorAccountEnabledRaw = Get-BatchPropertyValue -InputObject $evidence -PropertyNames @('PriorAccountEnabled', 'AccountEnabledBefore')
    $priorAccountEnabled = $null

    if ($null -ne $priorAccountEnabledRaw -and -not [string]::IsNullOrWhiteSpace([string]$priorAccountEnabledRaw)) {
        $priorAccountEnabled = Test-BatchBooleanValue -Value $priorAccountEnabledRaw -PropertyName 'PriorAccountEnabled'
    }

    if ($evidenceTenantId -ne $TenantId) { $reasons.Add('WhatIf evidence TenantId does not match the batch tenant.') }
    if ($evidenceObjectId -ne $ServicePrincipalObjectId) { $reasons.Add('WhatIf evidence service principal does not match the target.') }
    if ($evidenceAppId -ne $AppId) { $reasons.Add('WhatIf evidence AppId does not match the target.') }
    if ($evidenceApprovedAction -ne $ApprovedAction) { $reasons.Add('WhatIf evidence action does not match the batch action.') }
    if (-not $evidenceWhatIf) { $reasons.Add('WhatIf evidence must prove WhatIf or readiness mode.') }
    if ($evidenceLiveMutationPerformed) { $reasons.Add('WhatIf evidence must not indicate live mutation.') }
    if (-not [string]::IsNullOrWhiteSpace($evidenceSourceRunRoot) -and $evidenceSourceRunRoot -ne $PriorWhatIfRunRoot) {
        $reasons.Add('WhatIf evidence does not belong to the referenced prior run root.')
    }
    if ($null -eq $priorAccountEnabled) { $reasons.Add('WhatIf evidence must include prior AccountEnabled state.') }

    return [pscustomobject]@{
        PriorAccountEnabled = $priorAccountEnabled
        SourceRunRoot = $evidenceSourceRunRoot
        WhatIfEvidence = $evidence
        BlockingReasons = @($reasons)
    }
}

function New-BatchTargetArtifactFolder {
    param(
        [Parameter(Mandatory)]
        [string]$WaveFolder,

        [Parameter(Mandatory)]
        [int]$TargetIndex,

        [Parameter(Mandatory)]
        [string]$ServicePrincipalObjectId
    )

    $safeId = $ServicePrincipalObjectId -replace '[^A-Za-z0-9-]', '_'
    return Join-Path $WaveFolder ('target-{0:00}-{1}' -f $TargetIndex, $safeId)
}

function Get-BatchTargetRecord {
    param(
        [Parameter(Mandatory)]
        [object[]]$InventoryRecords,

        [Parameter(Mandatory)]
        [string]$ServicePrincipalObjectId,

        [Parameter()]
        [string]$AppId
    )

    $targetRecords = @($InventoryRecords | Where-Object {
        ([string](Get-BatchPropertyValue -InputObject $_ -PropertyNames @('ServicePrincipalObjectId', 'Id', 'ObjectId'))) -eq $ServicePrincipalObjectId
    })

    if ($targetRecords.Count -ne 1) {
        throw "STOP: Inventory must contain exactly one record for service principal '$ServicePrincipalObjectId'."
    }

    $targetRecord = $targetRecords[0]
    if (-not [string]::IsNullOrWhiteSpace($AppId)) {
        $inventoryAppId = [string](Get-BatchPropertyValue -InputObject $targetRecord -PropertyNames @('AppId'))
        if ($inventoryAppId -ne $AppId) {
            throw "STOP: Inventory AppId does not match the batch target for service principal '$ServicePrincipalObjectId'."
        }
    }

    return $targetRecord
}

function Test-BatchTargetEligibility {
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [object]$InventoryRecord,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$PriorWhatIfEvidencePath,

        [Parameter(Mandatory)]
        [string]$PriorWhatIfRunRoot
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $servicePrincipalObjectId = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('ServicePrincipalObjectId'))
    $appId = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('AppId'))
    $objectType = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('ObjectType'))
    $approvedAction = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('ApprovedAction'))
    $approvalState = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('ApprovalState'))
    $riskReason = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('RiskReason'))
    $ownerStatus = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('OwnerStatus'))
    $platformClassification = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('PlatformClassification'))
    $firstParty = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $Target -PropertyNames @('MicrosoftFirstParty', 'MicrosoftFirstPartyClassification') -Default $false) -PropertyName 'MicrosoftFirstParty'
    $platformIdentity = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $Target -PropertyNames @('PlatformIdentity', 'MicrosoftPlatform') -Default $false) -PropertyName 'PlatformIdentity'
    $evidenceOnly = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $Target -PropertyNames @('EvidenceOnly') -Default $false) -PropertyName 'EvidenceOnly'
    $whatIfEvidencePath = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('WhatIfEvidencePath'))
    $targetTenantId = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('TenantId'))
    $inventoryTenantId = [string](Get-BatchPropertyValue -InputObject $InventoryRecord -PropertyNames @('TenantId'))
    $inventoryAppId = [string](Get-BatchPropertyValue -InputObject $InventoryRecord -PropertyNames @('AppId'))
    $inventoryObjectId = [string](Get-BatchPropertyValue -InputObject $InventoryRecord -PropertyNames @('ServicePrincipalObjectId', 'Id', 'ObjectId'))
    $whatIfEvidence = Test-BatchWhatIfEvidence -EvidencePath $whatIfEvidencePath -TenantId $TenantId -ServicePrincipalObjectId $servicePrincipalObjectId -AppId $appId -ApprovedAction $script:ApprovedAction -PriorWhatIfRunRoot $PriorWhatIfRunRoot
    $priorAccountEnabled = $whatIfEvidence.PriorAccountEnabled

    if ([string]::IsNullOrWhiteSpace($servicePrincipalObjectId)) { $reasons.Add('ServicePrincipalObjectId is required.') }
    if ([string]::IsNullOrWhiteSpace($objectType) -or $objectType -ne 'ServicePrincipal') { $reasons.Add('ObjectType must be ServicePrincipal.') }
    if ([string]::IsNullOrWhiteSpace($appId)) { $reasons.Add('AppId is required.') }
    if ($approvedAction -ne $script:ApprovedAction) { $reasons.Add('ApprovedAction must be ReversibleDisable.') }
    if ($approvalState -ne 'Approved') { $reasons.Add('ApprovalState must be Approved.') }
    if ([string]::IsNullOrWhiteSpace($riskReason)) { $reasons.Add('RiskReason is required.') }
    if ([string]::IsNullOrWhiteSpace($ownerStatus)) { $reasons.Add('OwnerStatus is required.') }
    if ([string]::IsNullOrWhiteSpace($platformClassification) -or $platformClassification -match 'Unknown') { $reasons.Add('Platform classification must be known.') }
    if ($firstParty) { $reasons.Add('Microsoft first-party identities are not eligible for mutation.') }
    if ($platformIdentity) { $reasons.Add('Platform identities are not eligible for mutation.') }
    if ($ownerStatus -match 'Unknown|Uncertain|Ownerless' -and -not $evidenceOnly) { $reasons.Add('Ownerless or uncertain owner state is not eligible for mutation unless evidence-only.') }
    if ([string]::IsNullOrWhiteSpace($whatIfEvidencePath) -or -not (Test-Path -LiteralPath $whatIfEvidencePath -PathType Leaf)) { $reasons.Add('Per-object WhatIf evidence is required.') }
    if ($targetTenantId -ne $TenantId) { $reasons.Add('TenantId does not match the batch tenant.') }
    if ($inventoryTenantId -ne $TenantId) { $reasons.Add('Inventory tenant does not match the batch tenant.') }
    if ($inventoryObjectId -ne $servicePrincipalObjectId) { $reasons.Add('Inventory object identity does not match the batch target.') }
    if ($inventoryAppId -ne $appId) { $reasons.Add('Inventory AppId does not match the batch target.') }
    if ([string]::IsNullOrWhiteSpace($PriorWhatIfEvidencePath) -or -not (Test-Path -LiteralPath $PriorWhatIfEvidencePath -PathType Leaf)) { $reasons.Add('Prior Rev4.41 WhatIf evidence is required.') }
    if ($whatIfEvidence.BlockingReasons.Count -gt 0) { $reasons.AddRange($whatIfEvidence.BlockingReasons) }
    if ($evidenceOnly) { $reasons.Add('EvidenceOnly disposition blocks mutation.') }
    if ($null -eq $priorAccountEnabled) { $reasons.Add('Prior AccountEnabled state is required.') }

    $mutationEligible = ($reasons.Count -eq 0) -and (-not $evidenceOnly)
    $validationStatus = if ($evidenceOnly) { 'EvidenceOnly' } elseif ($reasons.Count -eq 0) { 'Eligible' } else { 'Blocked' }

    return [pscustomobject]@{
        ServicePrincipalObjectId = $servicePrincipalObjectId
        AppId = $appId
        ObjectType = $objectType
        ApprovedAction = $approvedAction
        ApprovalState = $approvalState
        RiskReason = $riskReason
        OwnerStatus = $ownerStatus
        PlatformClassification = $platformClassification
        MicrosoftFirstParty = $firstParty
        PlatformIdentity = $platformIdentity
        EvidenceOnly = $evidenceOnly
        PriorAccountEnabled = $priorAccountEnabled
        PriorWhatIfEvidencePath = $PriorWhatIfEvidencePath
        WhatIfEvidencePath = $whatIfEvidencePath
        ValidationStatus = $validationStatus
        MutationEligible = $mutationEligible
        BlockingReasons = @($reasons)
    }
}

function Invoke-NhiBatchChildLifecycle {
    param(
        [Parameter(Mandatory)]
        [string]$LifecycleScriptPath,

        [Parameter(Mandatory)]
        [hashtable]$BoundParameters
    )

    if (-not (Test-Path -LiteralPath $LifecycleScriptPath -PathType Leaf)) {
        throw "STOP: child lifecycle script '$LifecycleScriptPath' was not found."
    }

    return & $LifecycleScriptPath @BoundParameters
}

function New-BatchObjectContracts {
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [string]$ArtifactFolder,

        [Parameter(Mandatory)]
        [string]$BatchId,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$ApprovalPhrase,

        [Parameter(Mandatory)]
        [string]$PriorWhatIfEvidencePath,

        [Parameter(Mandatory)]
        [object]$Eligibility
    )

    $runId = "REV442-{0}" -f ([guid]::NewGuid().Guid)
    $preSnapshotPath = Join-Path $ArtifactFolder 'rev442-pre-snapshot.json'
    $changedObjectManifestPath = Join-Path $ArtifactFolder 'rev442-changed-object-manifest.json'
    $rollbackPackagePath = Join-Path $ArtifactFolder 'rev442-rollback-package.json'
    $postValidationPath = Join-Path $ArtifactFolder 'rev442-post-disable-validation.json'
    $approvalManifestPath = Join-Path $ArtifactFolder 'rev442-single-object-approval.json'

    $preSnapshot = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $BatchId
        RunId = $runId
        TenantId = $TenantId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        ServicePrincipalObjectId = $Eligibility.ServicePrincipalObjectId
        AppId = $Eligibility.AppId
        ObjectType = $Eligibility.ObjectType
        PriorAccountEnabled = $Eligibility.PriorAccountEnabled
        PriorWhatIfEvidencePath = $PriorWhatIfEvidencePath
        ArtifactFolder = $ArtifactFolder
    }

    $changedObjectManifest = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $BatchId
        RunId = $runId
        TenantId = $TenantId
        ServicePrincipalObjectId = $Eligibility.ServicePrincipalObjectId
        AppId = $Eligibility.AppId
        ObjectType = $Eligibility.ObjectType
        ApprovedAction = $script:ApprovedAction
        ChangedByPriorBatchRun = $false
        PriorAccountEnabled = $Eligibility.PriorAccountEnabled
        PriorWhatIfEvidencePath = $PriorWhatIfEvidencePath
        ArtifactFolder = $ArtifactFolder
        PreSnapshotPath = $preSnapshotPath
        ExecutionStatus = 'GateOnly'
    }

    $rollbackPackage = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $BatchId
        RunId = $runId
        TenantId = $TenantId
        ServicePrincipalObjectId = $Eligibility.ServicePrincipalObjectId
        AppId = $Eligibility.AppId
        ObjectType = $Eligibility.ObjectType
        PriorAccountEnabled = $Eligibility.PriorAccountEnabled
        RollbackAction = if ($null -eq $Eligibility.PriorAccountEnabled) { 'Incomplete' } elseif ([bool]$Eligibility.PriorAccountEnabled) { 'ReEnableServicePrincipal' } else { 'DisableServicePrincipal' }
        RollbackPackageStatus = if ($null -eq $Eligibility.PriorAccountEnabled) { 'Incomplete' } else { 'Ready' }
        SourceChangedObjectManifestPath = $changedObjectManifestPath
        PreSnapshotPath = $preSnapshotPath
        PriorWhatIfEvidencePath = $PriorWhatIfEvidencePath
        ArtifactFolder = $ArtifactFolder
    }

    $postValidation = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $BatchId
        RunId = $runId
        TenantId = $TenantId
        ServicePrincipalObjectId = $Eligibility.ServicePrincipalObjectId
        AppId = $Eligibility.AppId
        ObjectType = $Eligibility.ObjectType
        ValidationStatus = 'Pending'
        MutationObserved = $false
        ArtifactFolder = $ArtifactFolder
        ChangedObjectManifestPath = $changedObjectManifestPath
        RollbackPackagePath = $rollbackPackagePath
    }

    $approvalManifest = [pscustomobject]@{
        RunId = $runId
        BatchId = $BatchId
        TenantId = $TenantId
        TargetObjectId = $Eligibility.ServicePrincipalObjectId
        TargetDisplayName = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('DisplayName', 'TargetDisplayName'))
        AppId = $Eligibility.AppId
        ObjectType = $Eligibility.ObjectType
        ApprovedAction = $script:ApprovedAction
        ApprovedActions = @($script:ApprovedAction)
        ApprovalPhrase = $ApprovalPhrase
        RollbackReady = $false
        LiveMutationApproved = $false
        FinalDeleteApproved = $false
        CleanupApproved = $false
        RiskReason = $Eligibility.RiskReason
        OwnerStatus = $Eligibility.OwnerStatus
        PlatformClassification = $Eligibility.PlatformClassification
        MicrosoftFirstParty = $Eligibility.MicrosoftFirstParty
        PlatformIdentity = $Eligibility.PlatformIdentity
        EvidenceOnly = $Eligibility.EvidenceOnly
        PriorAccountEnabled = $Eligibility.PriorAccountEnabled
        PriorWhatIfEvidencePath = $PriorWhatIfEvidencePath
        WhatIfEvidencePath = $Eligibility.WhatIfEvidencePath
        ExecutionStatus = 'GateOnly'
        ExecutionNotPerformed = $true
    }

    Write-BatchJsonArtifact -Path $preSnapshotPath -InputObject $preSnapshot | Out-Null
    Write-BatchJsonArtifact -Path $changedObjectManifestPath -InputObject $changedObjectManifest | Out-Null
    Write-BatchJsonArtifact -Path $rollbackPackagePath -InputObject $rollbackPackage | Out-Null
    Write-BatchJsonArtifact -Path $postValidationPath -InputObject $postValidation | Out-Null
    Write-BatchJsonArtifact -Path $approvalManifestPath -InputObject $approvalManifest | Out-Null

    return [pscustomobject]@{
        RunId = $runId
        ApprovalManifestPath = $approvalManifestPath
        PreSnapshotPath = $preSnapshotPath
        ChangedObjectManifestPath = $changedObjectManifestPath
        RollbackPackagePath = $rollbackPackagePath
        PostDisableValidationPath = $postValidationPath
    }
}

function Start-NhiBatchReversibleDisable {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$BatchManifestPath,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputRoot,

        [Parameter()]
        [ValidateSet('Readiness', 'WhatIf', 'Execute', 'Verify', 'Closeout')]
        [string]$Mode = 'WhatIf',

        [Parameter()]
        [ValidateRange(1, 3)]
        [int]$MaxObjectsPerWave = 3,

        [Parameter()]
        [bool]$StopOnFirstFailure = $true,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApprovalPhrase
    )

    $batchManifest = Read-BatchJsonDocument -Path $BatchManifestPath -Label 'Batch manifest'
    $runRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    $null = New-Item -ItemType Directory -Path $runRoot -Force
    $batchId = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('BatchId'))
    $batchId = Test-BatchIdValue -BatchId $batchId
    $manifestTenantId = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('TenantId'))
    $manifestAction = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $manifestMode = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('Mode'))
    $manifestMaxObjectsPerWave = [int](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('MaxObjectsPerWave') -Default $MaxObjectsPerWave)
    $manifestStopOnFirstFailure = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('StopOnFirstFailure') -Default $true) -PropertyName 'StopOnFirstFailure'
    $finalDeleteApproved = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('FinalDeleteApproved') -Default $false) -PropertyName 'FinalDeleteApproved'
    $cleanupApproved = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('CleanupApproved') -Default $false) -PropertyName 'CleanupApproved'
    $priorWhatIfRunRoot = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('PriorWhatIfRunRoot', 'PriorRunRoot'))
    $priorWhatIfEvidencePath = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('PriorWhatIfEvidencePath'))
    $inventoryPath = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('InventoryPath'))
    $targetDocuments = @($batchManifest.Targets)
    $targetDocuments = @($targetDocuments | Where-Object { $null -ne $_ })

    if ($manifestTenantId -ne $TenantId) { throw 'STOP: TenantId does not match the batch manifest.' }
    if ($manifestAction -ne $script:ApprovedAction) { throw 'STOP: ApprovedAction must be ReversibleDisable.' }
    if ($manifestMode -and $manifestMode -ne $Mode) { throw 'STOP: Manifest Mode does not match the requested mode.' }
    if ($manifestMaxObjectsPerWave -lt 1 -or $manifestMaxObjectsPerWave -gt 3) { throw 'STOP: Manifest MaxObjectsPerWave must be within the safe bound.' }
    $effectiveMaxObjectsPerWave = [Math]::Min($manifestMaxObjectsPerWave, $MaxObjectsPerWave)
    if ($finalDeleteApproved) { throw 'STOP: Final delete is blocked for Rev4.42 batch disable.' }
    if ($cleanupApproved) { throw 'STOP: Cleanup is blocked for Rev4.42 batch disable.' }
    if ($null -eq $batchManifest.Targets -or $targetDocuments.Count -eq 0) { throw 'STOP: Targets are required.' }
    if ($targetDocuments.Count -gt $effectiveMaxObjectsPerWave) { throw 'STOP: Batch target count exceeds the allowed wave bound.' }
    if ([string]::IsNullOrWhiteSpace($inventoryPath)) { throw 'STOP: InventoryPath is required.' }
    if ([string]::IsNullOrWhiteSpace($priorWhatIfRunRoot) -or -not (Test-Path -LiteralPath $priorWhatIfRunRoot -PathType Container)) {
        throw 'STOP: Prior Rev4.41 WhatIf run root is required.'
    }
    if ([string]::IsNullOrWhiteSpace($priorWhatIfEvidencePath) -or -not (Test-Path -LiteralPath $priorWhatIfEvidencePath -PathType Leaf)) {
        throw 'STOP: Prior Rev4.41 WhatIf evidence is required.'
    }
    $priorWhatIfEvidence = Read-BatchJsonDocument -Path $priorWhatIfEvidencePath -Label 'Prior Rev4.41 WhatIf evidence'
    if ([string]::IsNullOrWhiteSpace([string](Get-BatchPropertyValue -InputObject $priorWhatIfEvidence -PropertyNames @('TenantId'))) -or [string](Get-BatchPropertyValue -InputObject $priorWhatIfEvidence -PropertyNames @('TenantId')) -ne $TenantId) {
        throw 'STOP: Prior Rev4.41 WhatIf evidence TenantId does not match the batch tenant.'
    }
    if ([string](Get-BatchPropertyValue -InputObject $priorWhatIfEvidence -PropertyNames @('ApprovedAction', 'ActionType')) -ne $script:ApprovedAction) {
        throw 'STOP: Prior Rev4.41 WhatIf evidence action does not match the batch action.'
    }
    if (-not (Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $priorWhatIfEvidence -PropertyNames @('WhatIf', 'WhatIfMode') -Default $false) -PropertyName 'PriorWhatIfEvidence.WhatIf')) {
        throw 'STOP: Prior Rev4.41 WhatIf evidence must prove WhatIf or readiness mode.'
    }
    if (Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $priorWhatIfEvidence -PropertyNames @('LiveMutationPerformed', 'LiveMutationAllowed') -Default $false) -PropertyName 'PriorWhatIfEvidence.LiveMutationPerformed') {
        throw 'STOP: Prior Rev4.41 WhatIf evidence must not indicate live mutation.'
    }
    $priorEvidenceSourceRoot = [string](Get-BatchPropertyValue -InputObject $priorWhatIfEvidence -PropertyNames @('SourceBatchRunRoot', 'PriorWhatIfRunRoot', 'BatchRunRoot'))
    if (-not [string]::IsNullOrWhiteSpace($priorEvidenceSourceRoot) -and $priorEvidenceSourceRoot -ne $priorWhatIfRunRoot) {
        throw 'STOP: Prior Rev4.41 WhatIf evidence does not belong to the referenced prior run root.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $priorWhatIfRunRoot 'rev441-batch-manifest.json') -PathType Leaf)) {
        throw 'STOP: Prior Rev4.41 batch manifest is required.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $priorWhatIfRunRoot 'rev441-batch-summary.json') -PathType Leaf)) {
        throw 'STOP: Prior Rev4.41 batch summary is required.'
    }
    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) { throw 'STOP: Inventory file is required.' }
    if ($ApprovalPhrase -ne [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('ApprovalPhrase'))) {
        throw 'STOP: ApprovalPhrase does not match the batch manifest.'
    }
    $StopOnFirstFailure = $manifestStopOnFirstFailure

    $inventoryDocument = Read-BatchJsonDocument -Path $inventoryPath -Label 'Inventory'
    $inventoryRecords = Get-BatchInventoryRecords -InventoryDocument $inventoryDocument
    $batchRoot = Join-Path $runRoot ("batch-{0}" -f $batchId)
    $null = New-Item -ItemType Directory -Path $batchRoot -Force
    $waveFolder = Join-Path $batchRoot 'wave-01'
    $null = New-Item -ItemType Directory -Path $waveFolder -Force

    $processedTargets = [System.Collections.Generic.List[object]]::new()
    $eligibleTargets = [System.Collections.Generic.List[object]]::new()
    $blockedTargets = [System.Collections.Generic.List[object]]::new()
    $childCalls = 0
    $stoppedEarly = $false

    foreach ($index in 0..($targetDocuments.Count - 1)) {
        $target = $targetDocuments[$index]
        $targetObjectId = [string](Get-BatchPropertyValue -InputObject $target -PropertyNames @('ServicePrincipalObjectId'))
        $artifactFolder = New-BatchTargetArtifactFolder -WaveFolder $waveFolder -TargetIndex ($index + 1) -ServicePrincipalObjectId $targetObjectId
        $null = New-Item -ItemType Directory -Path $artifactFolder -Force
        $artifactFolderPath = [string]$artifactFolder

        $inventoryRecord = Get-BatchTargetRecord -InventoryRecords $inventoryRecords -ServicePrincipalObjectId $targetObjectId -AppId ([string](Get-BatchPropertyValue -InputObject $target -PropertyNames @('AppId')))
        $eligibility = Test-BatchTargetEligibility -Target $target -InventoryRecord $inventoryRecord -TenantId $TenantId -PriorWhatIfEvidencePath $priorWhatIfEvidencePath -PriorWhatIfRunRoot $priorWhatIfRunRoot
        $targetSummary = [pscustomobject]@{
            WrapperVersion = $script:WrapperVersion
            BatchId = $batchId
            RunId = $null
            TenantId = $TenantId
            ApprovedAction = $script:ApprovedAction
            Mode = $Mode
            ServicePrincipalObjectId = $eligibility.ServicePrincipalObjectId
            AppId = $eligibility.AppId
            ObjectType = $eligibility.ObjectType
            RiskReason = $eligibility.RiskReason
            OwnerStatus = $eligibility.OwnerStatus
            PlatformClassification = $eligibility.PlatformClassification
            MicrosoftFirstParty = $eligibility.MicrosoftFirstParty
            PlatformIdentity = $eligibility.PlatformIdentity
            EvidenceOnly = $eligibility.EvidenceOnly
            ApprovalState = $eligibility.ApprovalState
            PriorWhatIfEvidencePath = $eligibility.PriorWhatIfEvidencePath
            WhatIfEvidencePath = $eligibility.WhatIfEvidencePath
            MutationEligible = $eligibility.MutationEligible
            ValidationStatus = $eligibility.ValidationStatus
            BlockingReasons = @($eligibility.BlockingReasons)
            ArtifactFolder = $artifactFolderPath
            PreSnapshotPath = $null
            ChangedObjectManifestPath = $null
            RollbackPackagePath = $null
            PostDisableValidationPath = $null
            ApprovalManifestPath = $null
            ChildRunSummaryPath = $null
            ExecutionStatus = if ($eligibility.MutationEligible) { 'GateOnly' } else { 'Blocked' }
            LiveMutationRequested = ($Mode -eq 'Execute')
            LiveMutationPerformed = $false
            SafetyGatePassed = $eligibility.MutationEligible
            ChangedByPriorBatchRun = $false
            ExecutionNotPerformed = $true
        }

        if (-not $eligibility.MutationEligible) {
            $blockedTargets.Add($targetSummary)
            $processedTargets.Add($targetSummary)
            Write-BatchJsonArtifact -Path (Join-Path $artifactFolderPath 'rev442-target-summary.json') -InputObject $targetSummary | Out-Null
            if ($StopOnFirstFailure) { $stoppedEarly = $true; break }
            continue
        }

        $contracts = New-BatchObjectContracts -Target $target -ArtifactFolder $artifactFolderPath -BatchId $batchId -TenantId $TenantId -ApprovalPhrase $ApprovalPhrase -PriorWhatIfEvidencePath $priorWhatIfEvidencePath -Eligibility $eligibility
        $targetSummary.RunId = $contracts.RunId
        $targetSummary.PreSnapshotPath = $contracts.PreSnapshotPath
        $targetSummary.ChangedObjectManifestPath = $contracts.ChangedObjectManifestPath
        $targetSummary.RollbackPackagePath = $contracts.RollbackPackagePath
        $targetSummary.PostDisableValidationPath = $contracts.PostDisableValidationPath
        $targetSummary.ApprovalManifestPath = $contracts.ApprovalManifestPath
        $targetSummary.ExecutionStatus = 'GateOnly'
        $targetSummary.LiveMutationPerformed = $false
        $targetSummary.SafetyGatePassed = $eligibility.MutationEligible

        $processedTargets.Add($targetSummary)
        $eligibleTargets.Add($targetSummary)

        Write-BatchJsonArtifact -Path (Join-Path $artifactFolderPath 'rev442-target-summary.json') -InputObject $targetSummary | Out-Null
    }

    if ($StopOnFirstFailure -and $blockedTargets.Count -gt 0) {
        throw ('STOP: ' + ($blockedTargets[0].BlockingReasons -join ' '))
    }

    $batchManifestPath = Join-Path $batchRoot 'rev442-batch-manifest.json'
    $batchSummaryPath = Join-Path $batchRoot 'rev442-batch-execution-summary.json'
    $closeoutSummaryPath = Join-Path $batchRoot 'rev442-batch-closeout-ready-summary.json'

    $batchManifestOut = [pscustomobject]@{
        SchemaVersion = $script:BatchSchemaVersion
        WrapperVersion = $script:WrapperVersion
        BatchId = $batchId
        TenantId = $TenantId
        ApprovedAction = $script:ApprovedAction
        Mode = $Mode
        MaxObjectsPerWave = $effectiveMaxObjectsPerWave
        StopOnFirstFailure = $StopOnFirstFailure
        FinalDeleteApproved = $false
        CleanupApproved = $false
        ApprovalPhrase = $ApprovalPhrase
        PriorWhatIfRunRoot = $priorWhatIfRunRoot
        PriorWhatIfEvidencePath = $priorWhatIfEvidencePath
        InventoryPath = $inventoryPath
        Targets = @($processedTargets)
        ApprovalManifestPaths = @($processedTargets | ForEach-Object { $_.ApprovalManifestPath })
        GeneratedUtc = [DateTime]::UtcNow.ToString('o')
    }

    $batchSummary = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $batchId
        TenantId = $TenantId
        ApprovedAction = $script:ApprovedAction
        Mode = $Mode
        MaxObjectsPerWave = $effectiveMaxObjectsPerWave
        StopOnFirstFailure = $StopOnFirstFailure
        FinalDeleteApproved = $false
        CleanupApproved = $false
        ApprovalPhrase = $ApprovalPhrase
        PriorWhatIfRunRoot = $priorWhatIfRunRoot
        PriorWhatIfEvidencePath = $priorWhatIfEvidencePath
        InventoryPath = $inventoryPath
        BatchRoot = $batchRoot
        BatchManifestPath = $batchManifestPath
        BatchSummaryPath = $batchSummaryPath
        CloseoutSummaryPath = $closeoutSummaryPath
        TotalTargetCount = $targetDocuments.Count
        EligibleTargetCount = $eligibleTargets.Count
        BlockedTargetCount = $blockedTargets.Count
        ChildCallCount = $childCalls
        StoppedEarly = $stoppedEarly
        SafetyGatePassed = ($blockedTargets.Count -eq 0)
        PerObjectArtifactFolders = @($processedTargets | ForEach-Object { $_.ArtifactFolder })
        ChangedObjectManifestPaths = @($processedTargets | ForEach-Object { $_.ChangedObjectManifestPath })
        RollbackPackagePaths = @($processedTargets | ForEach-Object { $_.RollbackPackagePath })
        PostDisableValidationPaths = @($processedTargets | ForEach-Object { $_.PostDisableValidationPath })
        ApprovalManifestPaths = @($processedTargets | ForEach-Object { $_.ApprovalManifestPath })
        Targets = @($processedTargets)
    }

    Write-BatchJsonArtifact -Path $batchManifestPath -InputObject $batchManifestOut | Out-Null
    Write-BatchJsonArtifact -Path $batchSummaryPath -InputObject $batchSummary | Out-Null
    Write-BatchJsonArtifact -Path $closeoutSummaryPath -InputObject ([pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $batchId
        TenantId = $TenantId
        ApprovedAction = $script:ApprovedAction
        Mode = $Mode
        BatchRoot = $batchRoot
        BatchSummaryPath = $batchSummaryPath
        CloseoutStatus = if ($blockedTargets.Count -eq 0) { 'Ready' } else { 'Blocked' }
        ArtifactCount = @($processedTargets).Count * 5
        SafetyGatePassed = ($blockedTargets.Count -eq 0)
    }) | Out-Null

    return [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $batchId
        TenantId = $TenantId
        Mode = $Mode
        ApprovedAction = $script:ApprovedAction
        ApprovalPhrase = $ApprovalPhrase
        BatchRoot = $batchRoot
        BatchManifestPath = $batchManifestPath
        BatchSummaryPath = $batchSummaryPath
        CloseoutSummaryPath = $closeoutSummaryPath
        SafetyGatePassed = ($blockedTargets.Count -eq 0)
        ExecutionStatus = 'GateOnly'
        ExecutionNotPerformed = $true
        StopOnFirstFailure = $StopOnFirstFailure
        MaxObjectsPerWave = $effectiveMaxObjectsPerWave
        TotalTargetCount = $targetDocuments.Count
        EligibleTargetCount = $eligibleTargets.Count
        BlockedTargetCount = $blockedTargets.Count
        ChildCallCount = $childCalls
        ApprovalManifestPaths = @($processedTargets | ForEach-Object { $_.ApprovalManifestPath })
        Targets = @($processedTargets)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-NhiBatchReversibleDisable @PSBoundParameters
}
