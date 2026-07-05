# NhiControlledDecommission.CleanupPlanning.ps1
# Dot-sourced into NhiControlledDecommission.psm1 module scope. Do not import directly.
# Contains: New-NhiControlledMetadataInventory, Test-NhiControlledMetadataCleanupReadinessGate, New-NhiControlledMetadataCleanupPlan, New-NhiControlledMetadataCleanupActionLog, Get-NhiControlledDependencyRecheckStatus, Test-NhiControlledGrantCleanupReadinessGate, New-NhiControlledGrantCleanupPlan, New-NhiControlledGrantCleanupActionLog, Get-NhiControlledManagedIdentityType, Test-NhiControlledManagedIdentityReadinessGate, New-NhiControlledManagedIdentityReadinessPlan, New-NhiControlledManagedIdentityActionLog

function New-NhiControlledMetadataInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Approval,

        [object]$Snapshot,

        [Parameter()]
        [object]$CleanupReadiness,

        [Parameter()]
        [object[]]$Credentials = @()
    )

    $rollback = Get-NhiControlledRollbackLimitation -Evidence $Plan
    $ownerEvidence = Get-NhiControlledOwnerMetadataEvidence -OwnerEvidence $Plan.OwnerMetadataEvidence

    [PSCustomObject]@{
        SchemaVersion            = '4.5'
        RunId                    = [string]$Plan.RunId
        TargetId                 = [string]$Plan.TargetId
        TargetType               = [string]$Plan.TargetType
        MetadataCleanupType      = [string]$Plan.MetadataCleanupType
        MetadataObjectId         = [string]$Plan.MetadataObjectId
        MetadataObjectType       = [string]$Plan.MetadataObjectType
        CredentialMetadataEvidence = @(Get-NhiControlledCredentialMetadataEvidence -Credentials $Credentials)
        OwnerMetadataEvidence     = $ownerEvidence
        DecommissionMarkerEvidence = if ($Plan.DecommissionMarkerEvidence) { $Plan.DecommissionMarkerEvidence } else { [PSCustomObject]@{ LocalOnly = $true; MarkerPresent = $false } }
        SnapshotSHA256           = [string]$Snapshot.SHA256
        ApprovalId               = if ($Approval.ApprovalId) { [string]$Approval.ApprovalId } else { [string]$Plan.ApprovalId }
        SnapshotId               = if ($Approval.SnapshotId) { [string]$Approval.SnapshotId } else { [string]$Snapshot.SHA256 }
        RollbackLimitation       = $rollback.Classification
        CleanupReadinessStatus   = if ($CleanupReadiness) { [string]$CleanupReadiness.Status } else { 'Unknown' }
        LiveCleanupEnabled       = $false
    }
}

function Test-NhiControlledMetadataCleanupReadinessGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExecutionStage,

        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Approval,

        [Parameter(Mandatory)]
        [object]$TargetValidation,

        [object]$Snapshot,

        [Parameter(Mandatory)]
        [object]$CleanupReadiness,

        [Parameter()]
        [bool]$WhatIf = $false,

        [Parameter()]
        [bool]$DemoMode = $false
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $roll = Get-NhiControlledRollbackLimitation -Evidence $Plan
    $credentialEvidence = @($Plan.CredentialMetadataEvidence)
    $ownerEvidence = $Plan.OwnerMetadataEvidence
    $markerEvidence = $Plan.DecommissionMarkerEvidence

    if ($ExecutionStage -ne 'MetadataCleanupReadiness') { $reasons.Add('ExecutionStage MetadataCleanupReadiness is required.') }
    if ([string]$Plan.SchemaVersion -ne '4.5') { $reasons.Add('Valid metadata cleanup plan is required.') }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.TargetId) -or [string]::IsNullOrWhiteSpace([string]$Plan.MetadataObjectId)) { $reasons.Add('Exact metadata target binding is required.') }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.MetadataCleanupType)) { $reasons.Add('Metadata cleanup type is required.') }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.ApprovalId)) { $reasons.Add('ApprovalId is required.') }
    if ([string]::IsNullOrWhiteSpace([string]$Approval.ApprovedBy)) { $reasons.Add('ApprovedBy is required.') }
    if ([string]$Approval.Status -ne 'Approved') { $reasons.Add('Approval status must be Approved.') }
    if ($Approval.MetadataObjectId -ne $Plan.MetadataObjectId) { $reasons.Add('Exact metadata object ID is required.') }
    if ($Approval.TargetId -ne $Plan.TargetId) { $reasons.Add('Exact target binding is required.') }
    if ($Approval.ApprovalId -ne $Plan.ApprovalId -and -not $Approval.Reusable) { $reasons.Add('Approval specifically authorizing the cleanup action is required.') }
    if ($Approval.MetadataCleanupType -ne $Plan.MetadataCleanupType) { $reasons.Add('Approval must match the cleanup action type.') }
    if ($Approval.ApprovedActions -notcontains 'MetadataCleanupReadiness') { $reasons.Add('Approval must specifically authorize the cleanup action.') }
    if (-not $Snapshot -or -not $Snapshot.SHA256) { $reasons.Add('Snapshot evidence is required.') }
    if ($Approval.SnapshotId -and $Approval.SnapshotId -ne $Snapshot.SHA256) { $reasons.Add('Snapshot evidence must match the approval.') }
    if (-not $CleanupReadiness -or [string]$CleanupReadiness.Status -ne 'Ready') { $reasons.Add('Cleanup readiness must be Ready.') }
    if (-not $WhatIf -and -not $DemoMode) { $reasons.Add('Rev4.5 unattended build permits WhatIf or DemoMode simulation only.') }
    if (-not $credentialEvidence -and [string]$Plan.MetadataCleanupType -eq 'CredentialMetadata') { $reasons.Add('Credential metadata evidence is required.') }
    if (-not $ownerEvidence -and [string]$Plan.MetadataCleanupType -eq 'OwnerMetadata') { $reasons.Add('Owner metadata evidence is required.') }
    if ($Plan.MetadataCleanupType -eq 'MarkerCleanup' -and $null -eq $markerEvidence) { $reasons.Add('Marker cleanup evidence is required.') }
    if ($roll.Classification -notin @('Reversible', 'Limited', 'NotAvailable', 'EvidenceOnly')) { $reasons.Add('Rollback limitation classification is invalid.') }
    if ($TargetValidation.Passed -ne $true) { $reasons.Add('Target validation failed.') }

    [PSCustomObject]@{
        SchemaVersion        = '4.5'
        EvaluatedUtc         = [DateTime]::UtcNow.ToString('o')
        TargetId             = [string]$Plan.TargetId
        TargetType           = [string]$Plan.TargetType
        MetadataObjectId     = [string]$Plan.MetadataObjectId
        MetadataObjectType   = [string]$Plan.MetadataObjectType
        MetadataCleanupType  = [string]$Plan.MetadataCleanupType
        RollbackLimitation   = $roll.Classification
        CleanupReadiness     = [PSCustomObject]@{
            Status = if ($reasons.Count -eq 0) { 'Ready' } elseif ($Approval.SnapshotId -and $Approval.SnapshotId -ne $Snapshot.SHA256) { 'Blocked' } else { 'Partial' }
        }
        PostCleanupValidation = [PSCustomObject]@{
            Status = if ($WhatIf -or $DemoMode) { 'Simulated' } else { 'NotRun' }
            Outcome = 'EvidenceOnly'
        }
        GatesPassed          = $reasons.Count -eq 0
        Status               = if ($reasons.Count -eq 0) { 'MetadataCleanupSatisfiedSimulationOnly' } else { 'Blocked' }
        SimulationOnly       = $true
        LiveCleanupExecutable = $false
        CleanupCmdletAvailable = $false
        WhatIf               = $WhatIf
        DemoMode             = $DemoMode
        Reasons              = @($reasons)
    }
}

function New-NhiControlledMetadataCleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Inventory,

        [Parameter(Mandatory)]
        [object]$Readiness
    )

    [PSCustomObject]@{
        SchemaVersion       = '4.5'
        RunId               = [string]$Plan.RunId
        TargetId            = [string]$Plan.TargetId
        TargetType          = [string]$Plan.TargetType
        MetadataObjectId    = [string]$Plan.MetadataObjectId
        MetadataObjectType  = [string]$Plan.MetadataObjectType
        MetadataCleanupType = [string]$Plan.MetadataCleanupType
        InventorySchema     = [string]$Inventory.SchemaVersion
        RollbackLimitation  = [string]$Inventory.RollbackLimitation
        CleanupReadiness    = [string]$Readiness.Status
        LiveCleanupEnabled  = $false
        PlanningOnly        = $true
        Status              = if ($Readiness.GatesPassed) { 'Planned' } else { 'Blocked' }
        Actions             = @(
            [PSCustomObject]@{
                ActionType = 'MetadataCleanupReadiness'
                TargetId   = [string]$Plan.TargetId
                MetadataObjectId = [string]$Plan.MetadataObjectId
                MetadataCleanupType = [string]$Plan.MetadataCleanupType
                Result     = if ($Readiness.GatesPassed) { 'Planned' } else { 'Blocked' }
            }
        )
    }
}

function New-NhiControlledMetadataCleanupActionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Inventory,

        [Parameter(Mandatory)]
        [object]$Readiness
    )

    [PSCustomObject]@{
        SchemaVersion       = '4.5'
        RunId               = [string]$Plan.RunId
        TargetId            = [string]$Plan.TargetId
        MetadataObjectId    = [string]$Plan.MetadataObjectId
        MetadataCleanupType = [string]$Plan.MetadataCleanupType
        RollbackLimitation  = [string]$Inventory.RollbackLimitation
        CleanupReadiness    = [string]$Readiness.Status
        LiveCleanupExecuted = $false
        Result              = if ($Readiness.GatesPassed) { 'SimulationOnly' } else { 'Blocked' }
        Notes               = @('No live metadata cleanup performed.')
    }
}

function Get-NhiControlledDependencyRecheckStatus {
    [CmdletBinding()]
    param(
        [Parameter()]
        [bool]$QuerySucceeded = $true,

        [Parameter()]
        [bool]$Blocked = $false,

        [Parameter()]
        [bool]$SkippedWithApproval = $false
    )

    $status = if (-not $QuerySucceeded) {
        'Unknown'
    } elseif ($Blocked) {
        'Blocked'
    } elseif ($SkippedWithApproval) {
        'SkippedWithApproval'
    } else {
        'Clean'
    }

    [PSCustomObject]@{
        SchemaVersion   = '4.6'
        Status          = $status
        QuerySucceeded   = $QuerySucceeded
        Blocked         = $Blocked
        SkippedWithApproval = $SkippedWithApproval
    }
}

function Test-NhiControlledGrantCleanupReadinessGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExecutionStage,

        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Approval,

        [Parameter(Mandatory)]
        [object]$TargetValidation,

        [object]$Snapshot,

        [Parameter(Mandatory)]
        [object]$DependencyRecheck,

        [Parameter()]
        [bool]$WhatIf = $false,

        [Parameter()]
        [bool]$DemoMode = $false
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $supportedRelatedTypes = @('OAuthGrant', 'AppRoleAssignment')

    if ($ExecutionStage -ne 'GrantCleanupReadiness') { $reasons.Add('ExecutionStage GrantCleanupReadiness is required.') }
    if ([string]$Plan.SchemaVersion -ne '4.6') { $reasons.Add('Valid grant cleanup plan is required.') }
    if (-not $TargetValidation -or -not $TargetValidation.Passed) { $reasons.Add('Target validation failed.') }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.TargetObjectId) -or [string]::IsNullOrWhiteSpace([string]$Plan.RelatedObjectId)) { $reasons.Add('Exact related object binding is required.') }
    if ([string]$Plan.RelatedObjectType -notin $supportedRelatedTypes) { $reasons.Add('Unsupported related object type.') }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.ApprovalId)) { $reasons.Add('ApprovalId is required.') }
    if ([string]::IsNullOrWhiteSpace([string]$Approval.ApprovedBy)) { $reasons.Add('ApprovedBy is required.') }
    if ([string]$Approval.Status -ne 'Approved') { $reasons.Add('Approval status must be Approved.') }
    if ($Approval.ApprovalId -ne $Plan.ApprovalId) { $reasons.Add('Exact approval is required.') }
    if ($Approval.TargetObjectId -ne $Plan.TargetObjectId) { $reasons.Add('TargetObjectId mismatch blocks cleanup.') }
    if ($Approval.RelatedObjectId -ne $Plan.RelatedObjectId) { $reasons.Add('RelatedObjectId mismatch blocks cleanup.') }
    if ($Approval.RelatedObjectType -ne $Plan.RelatedObjectType) { $reasons.Add('RelatedObjectType mismatch blocks cleanup.') }
    if ($Approval.ApprovedActions -notcontains 'GrantCleanupReadiness') { $reasons.Add('Approval must specifically authorize the cleanup action.') }
    if ($Plan.ResourceAppId -or $Approval.ResourceAppId) {
        if ([string]::IsNullOrWhiteSpace([string]$Plan.ResourceAppId) -or [string]::IsNullOrWhiteSpace([string]$Approval.ResourceAppId) -or $Approval.ResourceAppId -ne $Plan.ResourceAppId) { $reasons.Add('ResourceAppId mismatch blocks cleanup.') }
    }
    if ($Plan.ResourceId -or $Approval.ResourceId) {
        if ([string]::IsNullOrWhiteSpace([string]$Plan.ResourceId) -or [string]::IsNullOrWhiteSpace([string]$Approval.ResourceId) -or $Approval.ResourceId -ne $Plan.ResourceId) { $reasons.Add('ResourceId mismatch blocks cleanup.') }
    }
    if ($Plan.PrincipalId -or $Approval.PrincipalId) {
        if ([string]::IsNullOrWhiteSpace([string]$Plan.PrincipalId) -or [string]::IsNullOrWhiteSpace([string]$Approval.PrincipalId) -or $Approval.PrincipalId -ne $Plan.PrincipalId) { $reasons.Add('PrincipalId mismatch blocks cleanup.') }
    }
    if ($Plan.PermissionName -or $Approval.PermissionName) {
        if ([string]::IsNullOrWhiteSpace([string]$Plan.PermissionName) -or [string]::IsNullOrWhiteSpace([string]$Approval.PermissionName) -or $Approval.PermissionName -ne $Plan.PermissionName) { $reasons.Add('PermissionName mismatch blocks cleanup.') }
    }
    if ($Plan.Scope -or $Approval.Scope) {
        if ([string]::IsNullOrWhiteSpace([string]$Plan.Scope) -or [string]::IsNullOrWhiteSpace([string]$Approval.Scope) -or $Approval.Scope -ne $Plan.Scope) { $reasons.Add('Scope mismatch blocks cleanup.') }
    }
    if (-not $Snapshot -or -not $Snapshot.SHA256) { $reasons.Add('Snapshot evidence is required.') }
    if ($Plan.SnapshotId -and $Plan.SnapshotId -ne $Snapshot.SHA256) { $reasons.Add('Snapshot does not include the related object.') }
    if ($Approval.SnapshotId -and $Approval.SnapshotId -ne $Snapshot.SHA256) { $reasons.Add('Snapshot does not include the related object.') }
    if ($DependencyRecheck.Status -in @('Unknown', 'Blocked')) { $reasons.Add('Dependency recheck blocks cleanup.') }
    if ($Plan.TargetAmbiguous -eq $true -or $Approval.TargetAmbiguous -eq $true) { $reasons.Add('Target ambiguity blocks cleanup.') }
    if ($Plan.CleanupScope -eq 'Broad' -or $Approval.CleanupScope -eq 'Broad') { $reasons.Add('Cleanup must not broaden from one related object to many.') }
    if (-not $WhatIf -and -not $DemoMode) { $reasons.Add('Rev4.6 unattended build permits WhatIf or DemoMode simulation only.') }
    if ([string]$Approval.PostCleanupValidationStatus -notin @('', 'NotRun', 'Simulated', $null)) { $reasons.Add('Post-cleanup validation model is invalid.') }

    [PSCustomObject]@{
        SchemaVersion        = '4.6'
        EvaluatedUtc         = [DateTime]::UtcNow.ToString('o')
        TargetObjectId       = [string]$Plan.TargetObjectId
        TargetType           = [string]$Plan.TargetType
        RelatedObjectType    = [string]$Plan.RelatedObjectType
        RelatedObjectId      = [string]$Plan.RelatedObjectId
        DependencyRecheck    = $DependencyRecheck
        PostCleanupValidation = [PSCustomObject]@{
            Status = if ($WhatIf -or $DemoMode) { 'Simulated' } else { 'NotRun' }
        }
        GatesPassed          = $reasons.Count -eq 0
        Status               = if ($reasons.Count -eq 0) { 'GrantCleanupSatisfiedSimulationOnly' } else { 'Blocked' }
        SimulationOnly       = $true
        LiveCleanupExecutable = $false
        CleanupCmdletAvailable = $false
        WhatIf               = $WhatIf
        DemoMode             = $DemoMode
        Reasons              = @($reasons)
    }
}

function New-NhiControlledGrantCleanupPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$DependencyRecheck,

        [Parameter(Mandatory)]
        [object]$Readiness
    )

    [PSCustomObject]@{
        SchemaVersion       = '4.6'
        RunId               = [string]$Plan.RunId
        TargetObjectId      = [string]$Plan.TargetObjectId
        TargetType          = [string]$Plan.TargetType
        RelatedObjectType   = [string]$Plan.RelatedObjectType
        RelatedObjectId     = [string]$Plan.RelatedObjectId
        ResourceAppId       = [string]$Plan.ResourceAppId
        ResourceId          = [string]$Plan.ResourceId
        PrincipalId         = [string]$Plan.PrincipalId
        PermissionName      = [string]$Plan.PermissionName
        Scope               = [string]$Plan.Scope
        DependencyRecheckStatus = [string]$DependencyRecheck.Status
        CleanupReadiness    = [string]$Readiness.Status
        BroadCleanupBlocked  = $true
        LiveCleanupEnabled   = $false
        PlanningOnly        = $true
        Status              = if ($Readiness.GatesPassed) { 'Planned' } else { 'Blocked' }
    }
}

function New-NhiControlledGrantCleanupActionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$DependencyRecheck,

        [Parameter(Mandatory)]
        [object]$Readiness
    )

    [PSCustomObject]@{
        SchemaVersion       = '4.6'
        RunId               = [string]$Plan.RunId
        TargetObjectId      = [string]$Plan.TargetObjectId
        RelatedObjectType   = [string]$Plan.RelatedObjectType
        RelatedObjectId     = [string]$Plan.RelatedObjectId
        DependencyRecheckStatus = [string]$DependencyRecheck.Status
        CleanupReadiness    = [string]$Readiness.Status
        LiveCleanupExecuted = $false
        Result              = if ($Readiness.GatesPassed) { 'SimulationOnly' } else { 'Blocked' }
        Notes               = @('No live grant or assignment cleanup performed.')
    }
}

function Get-NhiControlledManagedIdentityType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan
    )

    $candidate = $null
    foreach ($propertyName in @('ManagedIdentityType', 'IdentityType', 'ManagedIdentityClassification')) {
        $property = $Plan.PSObject.Properties[$propertyName]
        if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            $candidate = [string]$property.Value
            break
        }
    }

    if ($candidate -notin @('SystemAssigned', 'UserAssigned')) {
        $candidate = 'Unknown'
    }

    [PSCustomObject]@{
        SchemaVersion = '4.7'
        ManagedIdentityType = $candidate
        IsKnown = $candidate -in @('SystemAssigned', 'UserAssigned')
        IsSystemAssigned = $candidate -eq 'SystemAssigned'
        IsUserAssigned = $candidate -eq 'UserAssigned'
    }
}

function Test-NhiControlledManagedIdentityReadinessGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ExecutionStage,

        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Approval,

        [Parameter(Mandatory)]
        [object]$TargetValidation,

        [Parameter()]
        [object]$Snapshot,

        [Parameter(Mandatory)]
        [object]$DeleteReadiness,

        [Parameter(Mandatory)]
        [object]$DependencyRecheck,

        [Parameter()]
        [object]$RoleAssignmentEvidence,

        [Parameter()]
        [object]$FederatedCredentialEvidence,

        [Parameter()]
        [object]$ParentResourceEvidence,

        [Parameter()]
        [object]$AttachmentEvidence,

        [Parameter()]
        [bool]$WhatIf = $false,

        [Parameter()]
        [bool]$DemoMode = $false
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $miType = Get-NhiControlledManagedIdentityType -Plan $Plan

    if ($ExecutionStage -ne 'ManagedIdentityReadiness') { $reasons.Add('ExecutionStage ManagedIdentityReadiness is required.') }
    if ([string]$Plan.TargetType -ne 'ManagedIdentity') { $reasons.Add('Target type must be ManagedIdentity.') }
    if (-not $miType.IsKnown) { $reasons.Add('Managed identity type is Unknown.') }
    if (-not $TargetValidation.Passed) { $reasons.Add('Target validation failed.') }
    if ([string]::IsNullOrWhiteSpace([string]$Plan.ApprovalId)) { $reasons.Add('ApprovalId is required.') }
    if ([string]::IsNullOrWhiteSpace([string]$Approval.ApprovedBy)) { $reasons.Add('ApprovedBy is required.') }
    if ([string]$Approval.Status -ne 'Approved') { $reasons.Add('Approval status must be Approved.') }
    if ($Approval.ApprovalId -ne $Plan.ApprovalId) { $reasons.Add('Exact approval is required.') }
    if ($Approval.TargetId -ne $Plan.TargetId) { $reasons.Add('Exact target binding is required.') }
    if ($Approval.TargetType -ne $Plan.TargetType) { $reasons.Add('Target type mismatch blocks readiness.') }
    if ($Approval.ManagedIdentityType -and $Approval.ManagedIdentityType -ne $Plan.ManagedIdentityType) { $reasons.Add('Managed identity type mismatch blocks readiness.') }
    if ($Approval.ApprovedActions -notcontains 'ManagedIdentityReadiness') { $reasons.Add('Approval must specifically authorize the readiness action.') }
    if (-not $Snapshot -or -not $Snapshot.SHA256) { $reasons.Add('Snapshot evidence is required.') }
    if (-not $DeleteReadiness -or [string]$DeleteReadiness.Status -ne 'Ready') { $reasons.Add('Delete-readiness must be Ready.') }
    if (-not $DependencyRecheck -or $DependencyRecheck.Status -in @('Unknown', 'Blocked')) { $reasons.Add('Dependency recheck blocks readiness.') }

    $roleAssignmentCount = if ($null -ne $RoleAssignmentEvidence -and $null -ne $RoleAssignmentEvidence.ActiveRoleAssignmentCount) { [int]$RoleAssignmentEvidence.ActiveRoleAssignmentCount } else { 0 }
    $federatedDependencyCount = if ($null -ne $FederatedCredentialEvidence -and $null -ne $FederatedCredentialEvidence.ActiveDependencyCount) { [int]$FederatedCredentialEvidence.ActiveDependencyCount } else { 0 }
    $appDependencyCount = if ($null -ne $FederatedCredentialEvidence -and $null -ne $FederatedCredentialEvidence.AppRelationshipDependencyCount) { [int]$FederatedCredentialEvidence.AppRelationshipDependencyCount } else { 0 }

    if ($roleAssignmentCount -gt 0) { $reasons.Add('Active role assignments block readiness.') }
    if ($federatedDependencyCount -gt 0 -or $appDependencyCount -gt 0) { $reasons.Add('Federated credential or app relationship dependency blocks readiness.') }

    $parentEvidencePresent = $null -ne $ParentResourceEvidence -and ($ParentResourceEvidence.Present -eq $true -or $ParentResourceEvidence.ParentResourceId)
    $attachmentEvidencePresent = $null -ne $AttachmentEvidence -and ($AttachmentEvidence.Present -eq $true -or $AttachmentEvidence.ResourceId -or $AttachmentEvidence.Attached -eq $true)

    if ($miType.ManagedIdentityType -eq 'SystemAssigned' -and -not $parentEvidencePresent) {
        $reasons.Add('System-assigned managed identity requires parent resource evidence.')
    }
    if ($miType.ManagedIdentityType -eq 'UserAssigned' -and -not $attachmentEvidencePresent) {
        $reasons.Add('User-assigned managed identity requires attachment evidence.')
    }
    if (-not $WhatIf -and -not $DemoMode) { $reasons.Add('Rev4.7 unattended build permits WhatIf or DemoMode simulation only.') }

    [PSCustomObject]@{
        SchemaVersion         = '4.7'
        EvaluatedUtc          = [DateTime]::UtcNow.ToString('o')
        TargetId              = [string]$Plan.TargetId
        TargetType            = [string]$Plan.TargetType
        ManagedIdentityType    = $miType.ManagedIdentityType
        ActionType            = 'ManagedIdentityReadiness'
        GatesPassed           = $reasons.Count -eq 0
        Status                = if ($reasons.Count -eq 0) { 'ManagedIdentityReadinessSatisfiedSimulationOnly' } else { 'Blocked' }
        SimulationOnly        = $true
        LiveCleanupExecutable  = $false
        CleanupCmdletAvailable = $false
        WhatIf                = $WhatIf
        DemoMode              = $DemoMode
        DeleteReadiness       = $DeleteReadiness
        DependencyRecheck     = $DependencyRecheck
        ParentResourceEvidence = $ParentResourceEvidence
        AttachmentEvidence    = $AttachmentEvidence
        RoleAssignmentEvidence = $RoleAssignmentEvidence
        FederatedCredentialEvidence = $FederatedCredentialEvidence
        Reasons               = @($reasons)
    }
}

function New-NhiControlledManagedIdentityReadinessPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Readiness,

        [Parameter(Mandatory)]
        [object]$Snapshot,

        [Parameter()]
        [object]$RoleAssignmentEvidence,

        [Parameter()]
        [object]$FederatedCredentialEvidence,

        [Parameter()]
        [object]$ParentResourceEvidence,

        [Parameter()]
        [object]$AttachmentEvidence
    )

    $miType = Get-NhiControlledManagedIdentityType -Plan $Plan
    [PSCustomObject]@{
        SchemaVersion            = '4.7'
        RunId                    = [string]$Plan.RunId
        TargetId                 = [string]$Plan.TargetId
        TargetType               = [string]$Plan.TargetType
        ManagedIdentityType      = $miType.ManagedIdentityType
        ParentResourceEvidence   = $ParentResourceEvidence
        AttachmentEvidence       = $AttachmentEvidence
        RoleAssignmentEvidence   = $RoleAssignmentEvidence
        FederatedCredentialEvidence = $FederatedCredentialEvidence
        SnapshotSHA256           = [string]$Snapshot.SHA256
        DeleteReadinessStatus    = [string]$Readiness.Status
        RollbackLimitation       = if ($Plan.RollbackLimitation) { [string]$Plan.RollbackLimitation } else { 'EvidenceOnly' }
        LiveCleanupEnabled       = $false
        PlanningOnly             = $true
        Status                   = if ($Readiness.GatesPassed) { 'Planned' } else { 'Blocked' }
        EvidenceKind             = 'ManagedIdentityReadiness'
    }
}

function New-NhiControlledManagedIdentityActionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Readiness,

        [Parameter(Mandatory)]
        [object]$Snapshot
    )

    $miType = Get-NhiControlledManagedIdentityType -Plan $Plan
    [PSCustomObject]@{
        SchemaVersion       = '4.7'
        RunId               = [string]$Plan.RunId
        TargetId            = [string]$Plan.TargetId
        TargetType          = [string]$Plan.TargetType
        ManagedIdentityType = $miType.ManagedIdentityType
        SnapshotSHA256      = [string]$Snapshot.SHA256
        DeleteReadiness     = [string]$Readiness.Status
        LiveCleanupExecuted = $false
        Result              = if ($Readiness.GatesPassed) { 'SimulationOnly' } else { 'Blocked' }
        Notes               = @('No live managed identity cleanup performed.')
    }
}
