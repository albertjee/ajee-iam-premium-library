#Requires -Version 7.0
<#
.SYNOPSIS
    Rev4.2-S1 controlled NHI decommission planner and evidence functions.

.DESCRIPTION
    Additive, local-data-only planner. This module performs no Graph calls and
    contains no tenant mutation path. FinalDelete is blocked for live execution
    in Rev4.2-S1.
#>

$script:ControlledSchemaVersion = '4.2'
$script:SupportedTargetTypes = @('ServicePrincipal', 'Application', 'ManagedIdentity')
$script:SupportedStages = @('ValidateOnly', 'SnapshotOnly', 'TagOnly', 'DisableOnly', 'ScreamTestOnly', 'DeleteReadinessOnly', 'MetadataCleanupReadiness', 'GrantCleanupReadiness', 'FinalDelete')
$script:SensitivePropertyPattern = '(?i)(secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)'

function Get-NhiControlledDecommissionSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputString
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        $hash = $sha256.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
}

function Get-NhiControlledDecommissionSchema {
    [CmdletBinding()]
    param()

    [ordered]@{
        ControlledDecommissionSchemaVersion = $script:ControlledSchemaVersion
        MetadataCleanupSchemaVersion        = '4.5'
        GrantCleanupSchemaVersion           = '4.6'
        ActionLogSchemaVersion              = $script:ControlledSchemaVersion
        SnapshotSchemaVersion               = $script:ControlledSchemaVersion
        DeleteReadinessSchemaVersion        = $script:ControlledSchemaVersion
        DependencyRecheckStatuses           = @('Clean', 'Blocked', 'Unknown', 'SkippedWithApproval')
        PostCleanupValidationStatuses       = @('NotRun', 'Simulated', 'ConfirmedAbsent', 'ConfirmedPresent', 'Unknown')
        SupportedTargetTypes                = @($script:SupportedTargetTypes)
        SupportedStages                     = @($script:SupportedStages)
        LiveMutationEnabled                 = $false
        FinalDeleteLiveEnabled              = $false
    }
}

function ConvertTo-NhiControlledSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId
    )

    $sanitized = [ordered]@{}
    foreach ($property in $Target.PSObject.Properties) {
        if ($property.Name -eq 'AdditionalProperties') {
            continue
        }
        if ($property.Name -in @('KeyCredentials', 'PasswordCredentials', 'Certificates', 'Credentials')) {
            $metadata = @()
            foreach ($credential in @($property.Value)) {
                $metadata += [ordered]@{
                    KeyId             = [string]$credential.KeyId
                    CredentialId      = [string]$credential.CredentialId
                    Id                = [string]$credential.Id
                    Type              = [string]$credential.Type
                    Usage             = [string]$credential.Usage
                    StartDateTime     = [string]$credential.StartDateTime
                    EndDateTime       = [string]$credential.EndDateTime
                    DisplayName       = [string]$credential.DisplayName
                }
            }
            $sanitized[$property.Name] = $metadata
            continue
        }
        if ($property.Name -match $script:SensitivePropertyPattern) {
            continue
        }
        $sanitized[$property.Name] = $property.Value
    }

    $snapshotBody = [ordered]@{
        SchemaVersion = $script:ControlledSchemaVersion
        RunId         = $RunId
        CapturedUtc   = [DateTime]::UtcNow.ToString('o')
        Target        = [PSCustomObject]$sanitized
    }
    $canonical = $snapshotBody | ConvertTo-Json -Depth 20 -Compress
    $snapshotBody['SHA256'] = Get-NhiControlledDecommissionSha256 -InputString $canonical
    return [PSCustomObject]$snapshotBody
}

function Test-NhiControlledTarget {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Target
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    if (-not $Target.ObjectId) { $reasons.Add('Target ObjectId is missing.') }
    if (-not $Target.ObjectType -or $Target.ObjectType -notin $script:SupportedTargetTypes) { $reasons.Add('Target type is unsupported.') }
    if ($Target.ProtectedObject -eq $true) { $reasons.Add('Target is protected.') }
    if ($Target.MicrosoftFirstParty -eq $true) { $reasons.Add('Microsoft first-party target is blocked.') }
    if ($Target.EmergencyAccessIndicator -eq $true -or $Target.BreakGlassIndicator -eq $true) { $reasons.Add('Emergency or break-glass target is blocked.') }
    if ($Target.HighConfidenceActive -eq $true) { $reasons.Add('High-confidence active target is blocked.') }
    if ($Target.Ambiguous -eq $true) { $reasons.Add('Target identity is ambiguous.') }

    [PSCustomObject]@{
        Passed  = $reasons.Count -eq 0
        Reasons = @($reasons)
    }
}

function Confirm-NhiControlledApproval {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Approval,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ActionType,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ExpectedSchemaVersion = $script:ControlledSchemaVersion,

        [Parameter()]
        [DateTime]$NowUtc = [DateTime]::UtcNow
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    if ([string]$Approval.SchemaVersion -ne $ExpectedSchemaVersion) { $reasons.Add('Approval schema version is invalid.') }
    if (-not $Approval.ApprovedBy) { $reasons.Add('ApprovedBy is required.') }
    if ([string]$Approval.Status -ne 'Approved') { $reasons.Add('Approval status is not Approved.') }
    if ([string]$Approval.RunId -ne $RunId -and $Approval.Reusable -ne $true) { $reasons.Add('Approval RunId does not match.') }
    if ($Approval.ExpiresUtc) {
        try {
            if ([DateTime]$Approval.ExpiresUtc -le $NowUtc) { $reasons.Add('Approval is expired.') }
        } catch {
            $reasons.Add('Approval ExpiresUtc is invalid.')
        }
    } else {
        $reasons.Add('Approval ExpiresUtc is required.')
    }

    $approvedTargets = @($Approval.TargetObjectIds)
    if ($TargetId -notin $approvedTargets) { $reasons.Add('Target is not approved.') }
    $approvedActions = @($Approval.ApprovedActions)
    if ($ActionType -notin $approvedActions) { $reasons.Add('Action is not approved.') }

    [PSCustomObject]@{
        Passed  = $reasons.Count -eq 0
        Reasons = @($reasons)
    }
}

function Get-NhiControlledScreamTestStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [DateTime]$StartedUtc,

        [Parameter(Mandatory)]
        [ValidateRange(1, 8760)]
        [int]$WindowHours,

        [Parameter()]
        [DateTime]$NowUtc = [DateTime]::UtcNow,

        [Parameter()]
        [bool]$DependencyDetected = $false,

        [Parameter()]
        [bool]$RecentActivityDetected = $false,

        [Parameter()]
        [bool]$QuerySucceeded = $true
    )

    $elapsedHours = [math]::Max(0, [math]::Floor(($NowUtc.ToUniversalTime() - $StartedUtc.ToUniversalTime()).TotalHours))
    $status = if (-not $QuerySucceeded) {
        'Unknown'
    } elseif ($DependencyDetected -or $RecentActivityDetected) {
        'Blocked'
    } elseif ($elapsedHours -ge $WindowHours) {
        'Complete'
    } else {
        'Active'
    }

    [PSCustomObject]@{
        SchemaVersion          = $script:ControlledSchemaVersion
        Status                 = $status
        StartedUtc             = $StartedUtc.ToUniversalTime().ToString('o')
        EvaluatedUtc           = $NowUtc.ToUniversalTime().ToString('o')
        WindowHours            = $WindowHours
        ElapsedHours           = [int]$elapsedHours
        DependencyDetected     = $DependencyDetected
        RecentActivityDetected = $RecentActivityDetected
        QuerySucceeded         = $QuerySucceeded
    }
}

function Test-NhiControlledDependencies {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Dependencies = @(),

        [Parameter()]
        [object[]]$RecentActivity = @(),

        [Parameter()]
        [bool]$QuerySucceeded = $true
    )

    $critical = @($Dependencies | Where-Object { $_.Severity -in @('Critical', 'High') -or $_.Blocking -eq $true })
    [PSCustomObject]@{
        QuerySucceeded        = $QuerySucceeded
        DependencyCount      = @($Dependencies).Count
        CriticalDependencyCount = $critical.Count
        RecentActivityCount  = @($RecentActivity).Count
        Passed               = $QuerySucceeded -and $critical.Count -eq 0 -and @($RecentActivity).Count -eq 0
    }
}

function Get-NhiControlledDeleteReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$TargetValidation,

        [Parameter(Mandatory)]
        [object]$ApprovalValidation,

        [Parameter()]
        [object]$Snapshot,

        [Parameter(Mandatory)]
        [object]$ScreamTest,

        [Parameter(Mandatory)]
        [object]$DependencyCheck
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    if (-not $TargetValidation.Passed) { $reasons.Add('Target validation failed.') }
    if (-not $ApprovalValidation.Passed) { $reasons.Add('Approval validation failed.') }
    if (-not $Snapshot -or -not $Snapshot.SHA256) { $reasons.Add('Valid snapshot is required.') }
    if ($ScreamTest.Status -ne 'Complete') { $reasons.Add("Scream-test status is '$($ScreamTest.Status)'.") }
    if (-not $DependencyCheck.QuerySucceeded) { $reasons.Add('Dependency evidence is unknown.') }
    elseif (-not $DependencyCheck.Passed) { $reasons.Add('Dependency or recent activity evidence blocks readiness.') }

    $status = if (-not $TargetValidation.Passed -or -not $ApprovalValidation.Passed) {
        'Blocked'
    } elseif (-not $DependencyCheck.QuerySucceeded -or $ScreamTest.Status -eq 'Unknown') {
        'Unknown'
    } elseif ($reasons.Count -eq 0) {
        'Ready'
    } else {
        'Partial'
    }

    [PSCustomObject]@{
        SchemaVersion = $script:ControlledSchemaVersion
        Status        = $status
        FinalDeleteLiveEnabled = $false
        Reasons       = @($reasons)
    }
}

function Test-NhiControlledServicePrincipalFinalDeleteGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ExecutionStage,
        [Parameter()][bool]$AllowFinalDelete = $false,
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][object]$TargetValidation,
        [Parameter(Mandatory)][object]$ApprovalValidation,
        [Parameter()][object]$Snapshot,
        [Parameter(Mandatory)][object]$DeleteReadiness,
        [Parameter(Mandatory)][object]$ScreamTest,
        [Parameter(Mandatory)][object]$DependencyCheck,
        [Parameter()][bool]$ScreamTestOverrideApproved = $false,
        [Parameter()][bool]$WhatIf = $false,
        [Parameter()][bool]$DemoMode = $false
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $testTenant = $Plan.PSObject.Properties['TestTenantGuard']
    $testTenantValue = if ($null -ne $testTenant) { $testTenant.Value } else { $null }

    if ($ExecutionStage -ne 'FinalDelete') { $reasons.Add('ExecutionStage FinalDelete is required.') }
    if (-not $AllowFinalDelete) { $reasons.Add('AllowFinalDelete is required.') }
    if ([string]$Plan.SchemaVersion -ne $script:ControlledSchemaVersion) { $reasons.Add('Valid decommission plan is required.') }
    if ([string]$Plan.TargetType -ne 'ServicePrincipal') { $reasons.Add('Target type must be ServicePrincipal.') }
    if (-not $TargetValidation.Passed) { $reasons.Add('Target validation failed.') }
    if (-not $ApprovalValidation.Passed) { $reasons.Add('Exact FinalDelete approval is required.') }
    if (-not $Snapshot -or -not $Snapshot.SHA256) { $reasons.Add('Snapshot evidence is required.') }
    if ($DeleteReadiness.Status -ne 'Ready') { $reasons.Add('Delete-readiness must be Ready.') }
    if ($ScreamTest.Status -ne 'Complete' -and -not $ScreamTestOverrideApproved) { $reasons.Add('Scream-test must be Complete or explicitly overridden.') }
    if (-not $DependencyCheck.QuerySucceeded -or -not $DependencyCheck.Passed) { $reasons.Add('Dependency recheck must be clean.') }
    if ($null -eq $testTenantValue -or $testTenantValue.IsTestTenant -ne $true -or [string]$testTenantValue.Environment -ne 'Test') {
        $reasons.Add('Test-tenant guard metadata is required.')
    }
    if (-not $WhatIf -and -not $DemoMode) { $reasons.Add('Rev4.3 unattended build permits WhatIf or DemoMode simulation only.') }

    [PSCustomObject]@{
        SchemaVersion         = '4.3'
        EvaluatedUtc          = [DateTime]::UtcNow.ToString('o')
        TargetId              = [string]$Plan.TargetId
        TargetType            = [string]$Plan.TargetType
        ActionType            = 'FinalDeleteServicePrincipal'
        GatesPassed           = $reasons.Count -eq 0
        Status                = if ($reasons.Count -eq 0) { 'GuardSatisfiedSimulationOnly' } else { 'Blocked' }
        SimulationOnly        = $true
        LiveDeleteExecutable  = $false
        DeleteCmdletAvailable = $false
        WhatIf                = $WhatIf
        DemoMode              = $DemoMode
        Reasons               = @($reasons)
    }
}

function Test-NhiControlledApplicationDeleteReadinessGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ExecutionStage,
        [Parameter()][bool]$AllowFinalDelete = $false,
        [Parameter(Mandatory)][object]$Plan,
        [Parameter(Mandatory)][object]$TargetValidation,
        [Parameter(Mandatory)][object]$ApprovalValidation,
        [Parameter()][object]$Snapshot,
        [Parameter(Mandatory)][object]$DeleteReadiness,
        [Parameter(Mandatory)][object]$ScreamTest,
        [Parameter(Mandatory)][object]$DependencyCheck,
        [Parameter()][bool]$ScreamTestOverrideApproved = $false,
        [Parameter()][bool]$ActiveCredentialOverrideApproved = $false,
        [Parameter()][bool]$WhatIf = $false,
        [Parameter()][bool]$DemoMode = $false
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $relationshipProperty = $Plan.PSObject.Properties['ApplicationRelationshipEvidence']
    $relationship = if ($null -ne $relationshipProperty) { $relationshipProperty.Value } else { $null }

    if ($ExecutionStage -ne 'FinalDelete') { $reasons.Add('ExecutionStage FinalDelete is required.') }
    if (-not $AllowFinalDelete) { $reasons.Add('AllowFinalDelete is required for Application readiness simulation.') }
    if ([string]$Plan.SchemaVersion -ne $script:ControlledSchemaVersion) { $reasons.Add('Valid decommission plan is required.') }
    if ([string]$Plan.TargetType -ne 'Application') { $reasons.Add('Target type must be Application.') }
    if (-not $TargetValidation.Passed) { $reasons.Add('Target validation failed.') }
    if (-not $ApprovalValidation.Passed) { $reasons.Add('Exact Application FinalDelete approval is required.') }
    if (-not $Snapshot -or -not $Snapshot.SHA256) { $reasons.Add('Snapshot evidence is required.') }
    if ($DeleteReadiness.Status -ne 'Ready') { $reasons.Add('Delete-readiness must be Ready.') }
    if ($ScreamTest.Status -ne 'Complete' -and -not $ScreamTestOverrideApproved) { $reasons.Add('Scream-test must be Complete or explicitly overridden.') }
    if (-not $DependencyCheck.QuerySucceeded -or -not $DependencyCheck.Passed) { $reasons.Add('General dependency recheck must be clean.') }
    if ($null -eq $relationship) {
        $reasons.Add('Application relationship evidence is required.')
    } else {
        if ($relationship.QuerySucceeded -ne $true) { $reasons.Add('Application relationship evidence query must succeed.') }
        if ([int]$relationship.ActiveServicePrincipalCount -gt 0) { $reasons.Add('Active service principal dependency blocks readiness.') }
        if ([int]$relationship.UnresolvedAppRoleAssignmentCount -gt 0) { $reasons.Add('Unresolved app role assignment dependency blocks readiness.') }
        if ([int]$relationship.UnresolvedOAuthGrantCount -gt 0) { $reasons.Add('Unresolved OAuth grant dependency blocks readiness.') }
        if ([int]$relationship.ActiveCredentialCount -gt 0 -and -not $ActiveCredentialOverrideApproved) { $reasons.Add('Active credential dependency requires explicit approval.') }
        if ($relationship.MultiTenant -eq $true) { $reasons.Add('Multi-tenant Application is blocked by default.') }
        if ($relationship.PublisherEvidenceCaptured -ne $true) { $reasons.Add('Verified publisher evidence must be captured.') }
        if ($relationship.OwnershipEvidenceCaptured -ne $true) { $reasons.Add('Ownership evidence must be captured.') }
    }
    if (-not $WhatIf -and -not $DemoMode) { $reasons.Add('Rev4.4 unattended build permits WhatIf or DemoMode simulation only.') }

    [PSCustomObject]@{
        SchemaVersion         = '4.4'
        EvaluatedUtc          = [DateTime]::UtcNow.ToString('o')
        TargetId              = [string]$Plan.TargetId
        TargetType            = [string]$Plan.TargetType
        ActionType            = 'FinalDeleteApplicationReadiness'
        GatesPassed           = $reasons.Count -eq 0
        Status                = if ($reasons.Count -eq 0) { 'ReadinessSatisfiedSimulationOnly' } else { 'Blocked' }
        SimulationOnly        = $true
        LiveDeleteExecutable  = $false
        DeleteCmdletAvailable = $false
        WhatIf                = $WhatIf
        DemoMode              = $DemoMode
        Reasons               = @($reasons)
    }
}

function Get-NhiControlledRollbackLimitation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Evidence
    )

    $classification = [string]$Evidence.RollbackLimitation
    if ([string]::IsNullOrWhiteSpace($classification)) {
        if ($Evidence.RollbackAvailable -eq $false) {
            $classification = 'NotAvailable'
        } elseif ($Evidence.LimitedRollback -eq $true) {
            $classification = 'Limited'
        } elseif ($Evidence.Reversible -eq $true) {
            $classification = 'Reversible'
        } else {
            $classification = 'EvidenceOnly'
        }
    }
    if ($classification -notin @('Reversible', 'Limited', 'NotAvailable', 'EvidenceOnly')) {
        $classification = 'EvidenceOnly'
    }

    [PSCustomObject]@{
        SchemaVersion  = '4.5'
        Classification  = $classification
        EvidenceOnly    = $classification -eq 'EvidenceOnly'
        Limited         = $classification -eq 'Limited'
        Reversible      = $classification -eq 'Reversible'
        NotAvailable    = $classification -eq 'NotAvailable'
    }
}

function Get-NhiControlledCredentialMetadataEvidence {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Credentials = @()
    )

    @(
        foreach ($credential in @($Credentials)) {
            if ($null -eq $credential) { continue }
            [PSCustomObject]@{
                CredentialType = if ($credential.CredentialType) { [string]$credential.CredentialType } elseif ($credential.Type) { [string]$credential.Type } else { 'Unknown' }
                KeyId          = [string]$credential.KeyId
                CredentialId   = if ($credential.CredentialId) { [string]$credential.CredentialId } elseif ($credential.Id) { [string]$credential.Id } else { [string]$credential.KeyId }
                StartDateTime   = if ($credential.StartDateTime) { [string]$credential.StartDateTime } else { $null }
                EndDateTime     = if ($credential.EndDateTime) { [string]$credential.EndDateTime } else { $null }
                DisplayName     = if ($credential.DisplayName) { [string]$credential.DisplayName } else { $null }
                SecretValue     = $null
                CertificateValue = $null
                TokenValue      = $null
            }
        }
    )
}

function Get-NhiControlledOwnerMetadataEvidence {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$OwnerEvidence
    )

    $ownerCount = if ($null -ne $OwnerEvidence.OwnerCount) { [int]$OwnerEvidence.OwnerCount } else { 0 }
    $typeSummary = if ($OwnerEvidence.OwnerTypeSummary) { $OwnerEvidence.OwnerTypeSummary } else { [ordered]@{} }
    $riskNotes = @()
    if ($OwnerEvidence.OwnerRiskNotes) {
        $riskNotes = @($OwnerEvidence.OwnerRiskNotes)
    }

    [PSCustomObject]@{
        OwnerCount       = $ownerCount
        OwnerTypeSummary = $typeSummary
        OwnerRiskNotes   = $riskNotes
        NoLiveOwnerRemoval = $true
    }
}

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
    if ($Approval.ResourceAppId -and $Plan.ResourceAppId -and $Approval.ResourceAppId -ne $Plan.ResourceAppId) { $reasons.Add('ResourceAppId mismatch blocks cleanup.') }
    if ($Approval.ResourceId -and $Plan.ResourceId -and $Approval.ResourceId -ne $Plan.ResourceId) { $reasons.Add('ResourceId mismatch blocks cleanup.') }
    if ($Approval.PrincipalId -and $Plan.PrincipalId -and $Approval.PrincipalId -ne $Plan.PrincipalId) { $reasons.Add('PrincipalId mismatch blocks cleanup.') }
    if ($Approval.PermissionName -and $Plan.PermissionName -and $Approval.PermissionName -ne $Plan.PermissionName) { $reasons.Add('PermissionName mismatch blocks cleanup.') }
    if ($Approval.Scope -and $Plan.Scope -and $Approval.Scope -ne $Plan.Scope) { $reasons.Add('Scope mismatch blocks cleanup.') }
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

function New-NhiControlledRollbackPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Snapshot,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId
    )

    [PSCustomObject]@{
        SchemaVersion = $script:ControlledSchemaVersion
        RunId         = $RunId
        TargetId      = [string]$Snapshot.Target.ObjectId
        RollbackAvailable = $true
        PlannedActions = @(
            [PSCustomObject]@{ ActionType = 'RollbackTag'; PlanningOnly = $true }
            [PSCustomObject]@{ ActionType = 'RollbackDisable'; PlanningOnly = $true }
        )
        SnapshotSHA256 = [string]$Snapshot.SHA256
    }
}

function New-NhiControlledDecommissionPlan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [ValidateSet('ValidateOnly', 'SnapshotOnly', 'TagOnly', 'DisableOnly', 'ScreamTestOnly', 'DeleteReadinessOnly', 'FinalDelete')]
        [string]$ExecutionStage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter()]
        [bool]$WhatIf = $true,

        [Parameter()]
        [bool]$DemoMode = $false
    )

    $targetValidation = Test-NhiControlledTarget -Target $Target
    $blocked = -not $targetValidation.Passed
    $reason = if ($blocked) { $targetValidation.Reasons -join '; ' } else { $null }
    if ($ExecutionStage -eq 'FinalDelete') {
        $blocked = $true
        $reason = 'FinalDelete is blocked for live execution in Rev4.2-S1.'
    }

    [PSCustomObject]@{
        SchemaVersion = $script:ControlledSchemaVersion
        RunId         = $RunId
        GeneratedUtc  = [DateTime]::UtcNow.ToString('o')
        TargetId      = [string]$Target.ObjectId
        TargetType    = [string]$Target.ObjectType
        ExecutionStage = $ExecutionStage
        WhatIf        = $WhatIf
        DemoMode      = $DemoMode
        PlanningOnly  = $true
        LiveMutationEnabled = $false
        Status        = if ($blocked) { 'Blocked' } else { 'Planned' }
        BlockReason   = $reason
        Actions       = @(
            [PSCustomObject]@{
                ActionId      = "$RunId-$ExecutionStage-$($Target.ObjectId)"
                RunId         = $RunId
                TargetId      = [string]$Target.ObjectId
                TargetType    = [string]$Target.ObjectType
                ActionType    = $ExecutionStage
                ExecutionStage = $ExecutionStage
                WhatIf        = $WhatIf
                Result        = if ($blocked) { 'Blocked' } else { 'Planned' }
                RollbackAvailable = $ExecutionStage -notin @('FinalDelete')
                Warnings      = if ($reason) { @($reason) } else { @() }
            }
        )
    }
}

function Export-NhiControlledDecommissionEvidence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Evidence,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $json = $Evidence | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    return $Path
}

Export-ModuleMember -Function @(
    'Get-NhiControlledDecommissionSha256',
    'Get-NhiControlledDecommissionSchema',
    'ConvertTo-NhiControlledSnapshot',
    'Test-NhiControlledTarget',
    'Confirm-NhiControlledApproval',
    'Get-NhiControlledScreamTestStatus',
    'Test-NhiControlledDependencies',
    'Get-NhiControlledDeleteReadiness',
    'New-NhiControlledRollbackPlan',
    'New-NhiControlledDecommissionPlan',
    'Export-NhiControlledDecommissionEvidence'
)
