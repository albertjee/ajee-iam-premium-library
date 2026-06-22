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
    [ValidateSet('WhatIf', 'Execute', 'Verify', 'Closeout')]
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

$script:WrapperVersion = 'Rev4.43'
$script:ApprovedAction = 'RollbackDisable'
$script:BatchSchemaVersion = 'Rev4.43-BatchRollback'
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

    if ($Value -is [bool]) { return [bool]$Value }
    if ($Value -is [string]) {
        switch ($Value.ToLowerInvariant()) {
            'true' { return $true }
            'false' { return $false }
        }
    }

    throw "STOP: $PropertyName must be a strict boolean value."
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

function New-BatchRollbackContracts {
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
        [object]$ChangedObjectManifest,

        [Parameter(Mandatory)]
        [object]$RollbackPackage
    )

    $runId = "REV443-{0}" -f ([guid]::NewGuid().Guid)
    $rollbackValidationPath = Join-Path $ArtifactFolder 'rev443-rollback-validation.json'
    $approvalManifestPath = Join-Path $ArtifactFolder 'rev443-single-object-approval.json'

    $validation = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $BatchId
        RunId = $runId
        TenantId = $TenantId
        ServicePrincipalObjectId = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('ServicePrincipalObjectId'))
        AppId = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('AppId'))
        ObjectType = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('ObjectType'))
        ChangedObjectManifestPath = [string](Get-BatchPropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('OutputArtifactPath', 'ChangedObjectManifestPath'))
        RollbackPackagePath = [string](Get-BatchPropertyValue -InputObject $RollbackPackage -PropertyNames @('OutputArtifactPath', 'RollbackPackagePath'))
        ValidationStatus = 'Pending'
        MutationObserved = $false
        NonTargetObjectProtection = $true
        ArtifactFolder = $ArtifactFolder
    }

    $approvalManifest = [pscustomobject]@{
        RunId = $runId
        BatchId = $BatchId
        TenantId = $TenantId
        TargetObjectId = $validation.ServicePrincipalObjectId
        TargetDisplayName = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('DisplayName', 'TargetDisplayName'))
        AppId = $validation.AppId
        ObjectType = $validation.ObjectType
        ApprovedAction = $script:ApprovedAction
        ApprovedActions = @($script:ApprovedAction)
        ApprovalPhrase = $ApprovalPhrase
        LiveRollbackApproved = $true
        FinalDeleteApproved = $false
        CleanupApproved = $false
        SourceBatchRunRoot = [string](Get-BatchPropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('SourceBatchRunRoot', 'BatchRunRoot'))
    }

    Write-BatchJsonArtifact -Path $rollbackValidationPath -InputObject $validation | Out-Null
    Write-BatchJsonArtifact -Path $approvalManifestPath -InputObject $approvalManifest | Out-Null

    return [pscustomobject]@{
        RunId = $runId
        RollbackValidationPath = $rollbackValidationPath
        ApprovalManifestPath = $approvalManifestPath
    }
}

function Test-BatchRollbackTargetEligibility {
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [object]$ChangedObjectManifest,

        [Parameter(Mandatory)]
        [object]$RollbackPackage,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$SourceBatchRunRoot
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $servicePrincipalObjectId = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('ServicePrincipalObjectId'))
    $appId = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('AppId'))
    $objectType = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('ObjectType'))
    $targetTenantId = [string](Get-BatchPropertyValue -InputObject $Target -PropertyNames @('TenantId'))
    $changedManifestTenantId = [string](Get-BatchPropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('TenantId'))
    $changedManifestObjectId = [string](Get-BatchPropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('ServicePrincipalObjectId', 'TargetObjectId'))
    $changedManifestAppId = [string](Get-BatchPropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('AppId'))
    $rollbackPackageObjectId = [string](Get-BatchPropertyValue -InputObject $RollbackPackage -PropertyNames @('ServicePrincipalObjectId', 'TargetObjectId'))
    $rollbackPackageAppId = [string](Get-BatchPropertyValue -InputObject $RollbackPackage -PropertyNames @('AppId'))
    $changedByBatch = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('ChangedByPriorBatchRun', 'ChangedByApprovedBatchRun') -Default $false) -PropertyName 'ChangedByPriorBatchRun'
    $sourceRoot = [string](Get-BatchPropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('SourceBatchRunRoot', 'BatchRunRoot'))
    $changedManifestAction = [string](Get-BatchPropertyValue -InputObject $ChangedObjectManifest -PropertyNames @('ApprovedAction'))

    if ([string]::IsNullOrWhiteSpace($servicePrincipalObjectId)) { $reasons.Add('ServicePrincipalObjectId is required.') }
    if ([string]::IsNullOrWhiteSpace($objectType) -or $objectType -ne 'ServicePrincipal') { $reasons.Add('ObjectType must be ServicePrincipal.') }
    if ([string]::IsNullOrWhiteSpace($appId)) { $reasons.Add('AppId is required.') }
    if ($targetTenantId -ne $TenantId) { $reasons.Add('TenantId mismatch.') }
    if ($changedManifestTenantId -ne $TenantId) { $reasons.Add('Changed-object manifest TenantId mismatch.') }
    if ($changedManifestObjectId -ne $servicePrincipalObjectId) { $reasons.Add('Target identity mismatch.') }
    if ($changedManifestAppId -ne $appId) { $reasons.Add('AppId mismatch.') }
    if ($rollbackPackageObjectId -ne $servicePrincipalObjectId) { $reasons.Add('Rollback package identity mismatch.') }
    if ($rollbackPackageAppId -ne $appId) { $reasons.Add('Rollback package AppId mismatch.') }
    if (-not $changedByBatch) { $reasons.Add('Object was not marked as changed by the prior approved batch run.') }
    if ($changedManifestAction -ne 'ReversibleDisable') { $reasons.Add('Changed-object manifest must be from a reversible-disable batch run.') }
    if ([string]::IsNullOrWhiteSpace($sourceRoot) -or $sourceRoot -ne $SourceBatchRunRoot) { $reasons.Add('Source batch run root is missing or does not match.') }

    return [pscustomobject]@{
        ServicePrincipalObjectId = $servicePrincipalObjectId
        AppId = $appId
        ObjectType = $objectType
        TenantId = $targetTenantId
        ChangedByPriorBatchRun = $changedByBatch
        SourceBatchRunRoot = $sourceRoot
        MutationEligible = ($reasons.Count -eq 0)
        BlockingReasons = @($reasons)
    }
}

function Start-NhiBatchRollback {
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
        [ValidateSet('WhatIf', 'Execute', 'Verify', 'Closeout')]
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

    $batchManifest = Read-BatchJsonDocument -Path $BatchManifestPath -Label 'Batch rollback manifest'
    $runRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    $null = New-Item -ItemType Directory -Path $runRoot -Force
    $batchId = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('BatchId'))
    $manifestTenantId = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('TenantId'))
    $manifestAction = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $manifestMode = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('Mode'))
    $manifestMaxObjectsPerWave = [int](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('MaxObjectsPerWave') -Default $MaxObjectsPerWave)
    $manifestStopOnFirstFailure = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('StopOnFirstFailure') -Default $true) -PropertyName 'StopOnFirstFailure'
    $finalDeleteApproved = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('FinalDeleteApproved') -Default $false) -PropertyName 'FinalDeleteApproved'
    $cleanupApproved = Test-BatchBooleanValue -Value (Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('CleanupApproved') -Default $false) -PropertyName 'CleanupApproved'
    $sourceBatchRunRoot = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('SourceBatchRunRoot', 'PriorBatchRunRoot'))
    $inventoryPath = [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('InventoryPath'))
    $targetDocuments = @($batchManifest.Targets)

    if ([string]::IsNullOrWhiteSpace($batchId)) { throw 'STOP: BatchId is required.' }
    if ($manifestTenantId -ne $TenantId) { throw 'STOP: TenantId does not match the rollback manifest.' }
    if ($manifestAction -ne $script:ApprovedAction) { throw 'STOP: ApprovedAction must be RollbackDisable.' }
    if ($manifestMode -and $manifestMode -ne $Mode) { throw 'STOP: Manifest Mode does not match the requested mode.' }
    if (-not $manifestStopOnFirstFailure) { throw 'STOP: StopOnFirstFailure must be true.' }
    if ($finalDeleteApproved) { throw 'STOP: Final delete is blocked for Rev4.43 batch rollback.' }
    if ($cleanupApproved) { throw 'STOP: Cleanup is blocked for Rev4.43 batch rollback.' }
    if ($manifestMaxObjectsPerWave -gt 3 -or $MaxObjectsPerWave -gt 3) { throw 'STOP: MaxObjectsPerWave exceeds the safe bound for Rev4.43 batch rollback.' }
    if ($targetDocuments.Count -gt $MaxObjectsPerWave) { throw 'STOP: Rollback target count exceeds the allowed wave bound.' }
    if ([string]::IsNullOrWhiteSpace($inventoryPath)) { throw 'STOP: InventoryPath is required.' }
    if ([string]::IsNullOrWhiteSpace($sourceBatchRunRoot) -or -not (Test-Path -LiteralPath $sourceBatchRunRoot -PathType Container)) { throw 'STOP: Prior approved batch run root is required.' }
    if (-not (Test-Path -LiteralPath (Join-Path $sourceBatchRunRoot 'rev442-batch-manifest.json') -PathType Leaf)) { throw 'STOP: Prior batch manifest is required.' }
    if (-not (Test-Path -LiteralPath (Join-Path $sourceBatchRunRoot 'rev442-batch-execution-summary.json') -PathType Leaf)) { throw 'STOP: Prior batch execution summary is required.' }
    if ([string]::IsNullOrWhiteSpace($ApprovalPhrase) -or $ApprovalPhrase -ne [string](Get-BatchPropertyValue -InputObject $batchManifest -PropertyNames @('ApprovalPhrase'))) { throw 'STOP: ApprovalPhrase does not match the rollback manifest.' }
    if (-not (Test-Path -LiteralPath $inventoryPath -PathType Leaf)) { throw 'STOP: Inventory file is required.' }

    $inventoryDocument = Read-BatchJsonDocument -Path $inventoryPath -Label 'Inventory'
    $inventoryRecords = if ($null -ne $inventoryDocument.Inventory) { @($inventoryDocument.Inventory) } elseif ($inventoryDocument -is [System.Array]) { @($inventoryDocument) } else { @($inventoryDocument) }
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
        $artifactFolder = New-Item -ItemType Directory -Path (Join-Path $waveFolder ('target-{0:00}-{1}' -f ($index + 1), ($targetObjectId -replace '[^A-Za-z0-9-]', '_'))) -Force
        $changedObjectManifestPath = [string](Get-BatchPropertyValue -InputObject $target -PropertyNames @('ChangedObjectManifestPath'))
        $rollbackPackagePath = [string](Get-BatchPropertyValue -InputObject $target -PropertyNames @('RollbackPackagePath'))

        if ([string]::IsNullOrWhiteSpace($changedObjectManifestPath) -or -not (Test-Path -LiteralPath $changedObjectManifestPath -PathType Leaf)) {
            throw 'STOP: Changed-object manifest is required.'
        }
        if ([string]::IsNullOrWhiteSpace($rollbackPackagePath) -or -not (Test-Path -LiteralPath $rollbackPackagePath -PathType Leaf)) {
            throw 'STOP: Rollback package is required.'
        }

        $changedObjectManifest = Read-BatchJsonDocument -Path $changedObjectManifestPath -Label 'Changed-object manifest'
        $rollbackPackage = Read-BatchJsonDocument -Path $rollbackPackagePath -Label 'Rollback package'
        $eligibility = Test-BatchRollbackTargetEligibility -Target $target -ChangedObjectManifest $changedObjectManifest -RollbackPackage $rollbackPackage -TenantId $TenantId -SourceBatchRunRoot $sourceBatchRunRoot

        $validationSummary = [pscustomobject]@{
            WrapperVersion = $script:WrapperVersion
            BatchId = $batchId
            TenantId = $TenantId
            Mode = $Mode
            ApprovedAction = $script:ApprovedAction
            ServicePrincipalObjectId = $eligibility.ServicePrincipalObjectId
            AppId = $eligibility.AppId
            ObjectType = $eligibility.ObjectType
            MutationEligible = $eligibility.MutationEligible
            BlockingReasons = @($eligibility.BlockingReasons)
            ChangedByPriorBatchRun = $eligibility.ChangedByPriorBatchRun
            SourceBatchRunRoot = $eligibility.SourceBatchRunRoot
            ChangedObjectManifestPath = $changedObjectManifestPath
            RollbackPackagePath = $rollbackPackagePath
            ArtifactFolder = $artifactFolder.FullName
            ValidationStatus = if ($eligibility.MutationEligible) { 'Eligible' } else { 'Blocked' }
            ChildRunSummaryPath = $null
            LiveMutationPerformed = $false
            SafetyGatePassed = $eligibility.MutationEligible
        }

        if (-not $eligibility.MutationEligible) {
            $blockedTargets.Add($validationSummary)
            $processedTargets.Add($validationSummary)
            Write-BatchJsonArtifact -Path (Join-Path $artifactFolder.FullName 'rev443-rollback-validation.json') -InputObject $validationSummary | Out-Null
            Write-BatchJsonArtifact -Path (Join-Path $artifactFolder.FullName 'rev443-target-summary.json') -InputObject $validationSummary | Out-Null
            $isSoftEligibilityFailure = ($eligibility.BlockingReasons.Count -eq 1 -and $eligibility.BlockingReasons[0] -eq 'Object was not marked as changed by the prior approved batch run.')
            if ($StopOnFirstFailure -and -not $isSoftEligibilityFailure) { $stoppedEarly = $true; break }
            continue
        }

        $processedTargets.Add($validationSummary)
        $eligibleTargets.Add($validationSummary)

        if ($Mode -eq 'Execute') {
            $childArguments = @{
                TenantId = $TenantId
                Action = 'RollbackDisable'
                Mode = 'Execute'
                TargetObjectId = $targetObjectId
                InventoryPath = $inventoryPath
                OutputRoot = (Join-Path $artifactFolder.FullName 'child')
                ApprovalPhrase = $ApprovalPhrase
                Confirm = $false
            }

            $childSummary = Invoke-NhiBatchChildLifecycle -LifecycleScriptPath $script:SingleObjectLifecycleScriptPath -BoundParameters $childArguments
            $validationSummary.ChildRunSummaryPath = [string](Get-BatchPropertyValue -InputObject $childSummary -PropertyNames @('WrapperRunSummaryPath', 'OutputArtifactPath', 'ChildRunSummaryPath'))
            $validationSummary.LiveMutationPerformed = [bool](Get-BatchPropertyValue -InputObject $childSummary -PropertyNames @('LiveMutationPerformed', 'LiveMutationAllowed') -Default $false)
            $validationSummary.SafetyGatePassed = [bool](Get-BatchPropertyValue -InputObject $childSummary -PropertyNames @('SafetyGatePassed') -Default $false)
            $childCalls++
        }

        Write-BatchJsonArtifact -Path (Join-Path $artifactFolder.FullName 'rev443-rollback-validation.json') -InputObject $validationSummary | Out-Null
        Write-BatchJsonArtifact -Path (Join-Path $artifactFolder.FullName 'rev443-target-summary.json') -InputObject $validationSummary | Out-Null
    }

    $changedByBatchBlockedTargets = @($blockedTargets | Where-Object { @($_.BlockingReasons) -contains 'Object was not marked as changed by the prior approved batch run.' })
    if ($changedByBatchBlockedTargets.Count -gt 0) {
        $blockedReason = [string]($changedByBatchBlockedTargets[0].BlockingReasons -join ' ')
        throw ('STOP: ' + $blockedReason)
    }

    if ($blockedTargets.Count -gt 0 -and $eligibleTargets.Count -eq 0) {
        $blockedReason = [string]($blockedTargets[0].BlockingReasons -join ' ')
        throw ('STOP: ' + $blockedReason)
    }

    $batchManifestOutPath = Join-Path $batchRoot 'rev443-batch-manifest.json'
    $batchSummaryPath = Join-Path $batchRoot 'rev443-batch-rollback-summary.json'

    $batchManifestOut = [pscustomobject]@{
        SchemaVersion = $script:BatchSchemaVersion
        WrapperVersion = $script:WrapperVersion
        BatchId = $batchId
        TenantId = $TenantId
        ApprovedAction = $script:ApprovedAction
        Mode = $Mode
        MaxObjectsPerWave = $MaxObjectsPerWave
        StopOnFirstFailure = $true
        FinalDeleteApproved = $false
        CleanupApproved = $false
        ApprovalPhrase = $ApprovalPhrase
        SourceBatchRunRoot = $sourceBatchRunRoot
        InventoryPath = $inventoryPath
        Targets = @($processedTargets)
        GeneratedUtc = [DateTime]::UtcNow.ToString('o')
    }

    $batchSummary = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $batchId
        TenantId = $TenantId
        ApprovedAction = $script:ApprovedAction
        Mode = $Mode
        MaxObjectsPerWave = $MaxObjectsPerWave
        StopOnFirstFailure = $true
        FinalDeleteApproved = $false
        CleanupApproved = $false
        ApprovalPhrase = $ApprovalPhrase
        SourceBatchRunRoot = $sourceBatchRunRoot
        InventoryPath = $inventoryPath
        BatchRoot = $batchRoot
        BatchManifestPath = $batchManifestOutPath
        BatchSummaryPath = $batchSummaryPath
        TotalTargetCount = $targetDocuments.Count
        EligibleTargetCount = $eligibleTargets.Count
        BlockedTargetCount = $blockedTargets.Count
        ChildCallCount = $childCalls
        StoppedEarly = $stoppedEarly
        SafetyGatePassed = ($blockedTargets.Count -eq 0)
        PerObjectRollbackValidationPaths = @($processedTargets | ForEach-Object { Join-Path $_.ArtifactFolder 'rev443-rollback-validation.json' })
        Targets = @($processedTargets)
        NonTargetObjectProtection = $true
    }

    Write-BatchJsonArtifact -Path $batchManifestOutPath -InputObject $batchManifestOut | Out-Null
    Write-BatchJsonArtifact -Path $batchSummaryPath -InputObject $batchSummary | Out-Null

    return [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        BatchId = $batchId
        TenantId = $TenantId
        Mode = $Mode
        ApprovedAction = $script:ApprovedAction
        ApprovalPhrase = $ApprovalPhrase
        BatchRoot = $batchRoot
        BatchManifestPath = $batchManifestOutPath
        BatchSummaryPath = $batchSummaryPath
        SafetyGatePassed = ($blockedTargets.Count -eq 0)
        StopOnFirstFailure = $true
        MaxObjectsPerWave = $MaxObjectsPerWave
        TotalTargetCount = $targetDocuments.Count
        EligibleTargetCount = $eligibleTargets.Count
        BlockedTargetCount = $blockedTargets.Count
        ChildCallCount = $childCalls
        Targets = @($processedTargets)
        NonTargetObjectProtection = $true
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-NhiBatchRollback @PSBoundParameters
}
