#Requires -Version 7.0
<#
.SYNOPSIS
    Rev4.8 controlled NHI decommission planner and evidence functions.

.DESCRIPTION
    Additive, local-data-only planner. This module performs no Graph calls and
    contains no tenant mutation path. FinalDelete remains simulation-only when
    -AllowFinalDelete is set; live execution stays blocked.
#>

$script:ControlledSchemaVersion = '4.2'
$script:SupportedTargetTypes = @('ServicePrincipal', 'Application', 'ManagedIdentity')
$script:SupportedStages = @('ValidateOnly', 'SnapshotOnly', 'TagOnly', 'DisableOnly', 'ScreamTestOnly', 'DeleteReadinessOnly', 'MetadataCleanupReadiness', 'GrantCleanupReadiness', 'ManagedIdentityReadiness', 'E2EEvidencePack', 'ProductionReadiness', 'FinalDelete')
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

function ConvertTo-NhiControlledSanitizedValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter()]
        [string]$PropertyName
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($PropertyName -and $PropertyName -match $script:SensitivePropertyPattern) {
        return $null
    }

    if ($Value -is [string]) {
        if ($Value -match $script:SensitivePropertyPattern -or $Value -match 'must-not-export') {
            return '[REDACTED]'
        }
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $keyName = [string]$key
            if ($keyName -match $script:SensitivePropertyPattern) {
                continue
            }
            $copy[$keyName] = ConvertTo-NhiControlledSanitizedValue -Value $Value[$key] -PropertyName $keyName
        }
        return [PSCustomObject]$copy
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in @($Value)) {
            $items += ,(ConvertTo-NhiControlledSanitizedValue -Value $item)
        }
        return $items
    }

    $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -in @('NoteProperty', 'Property') })
    if ($properties.Count -gt 0) {
        $copy = [ordered]@{}
        foreach ($property in $properties) {
            if ($property.Name -match $script:SensitivePropertyPattern) {
                continue
            }
            $copy[$property.Name] = ConvertTo-NhiControlledSanitizedValue -Value $property.Value -PropertyName $property.Name
        }
        return [PSCustomObject]$copy
    }

    return $Value
}

function Get-NhiControlledDecommissionSchema {
    [CmdletBinding()]
    param()

    [ordered]@{
        ControlledDecommissionSchemaVersion = $script:ControlledSchemaVersion
        MetadataCleanupSchemaVersion        = '4.5'
        GrantCleanupSchemaVersion           = '4.6'
        ManagedIdentitySchemaVersion        = '4.7'
        E2EEvidencePackSchemaVersion        = '4.8'
        ProductionReadinessSchemaVersion    = '4.9'
        ReleaseMergeGateSchemaVersion       = '4.9'
        KnownWarningInventorySchemaVersion  = '4.9'
        FinalSafetyAssertionSchemaVersion   = '4.9'
        QAHandoffSchemaVersion              = '4.8'
        OperatorDecisionSchemaVersion       = '4.8'
        ActionLogSchemaVersion              = $script:ControlledSchemaVersion
        SnapshotSchemaVersion               = $script:ControlledSchemaVersion
        DeleteReadinessSchemaVersion        = $script:ControlledSchemaVersion
        DependencyRecheckStatuses           = @('Clean', 'Blocked', 'Unknown', 'SkippedWithApproval')
        PostCleanupValidationStatuses       = @('NotRun', 'Simulated', 'ConfirmedAbsent', 'ConfirmedPresent', 'Unknown')
        ManagedIdentityTypes                = @('SystemAssigned', 'UserAssigned', 'Unknown')
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
        if ($property.Name -in @('KeyCredentials', 'PasswordCredentials', 'Certificates', 'Credentials')) {
            $metadata = @()
            foreach ($credential in @($property.Value)) {
                $credentialMetadata = [ordered]@{
                    KeyId             = [string]$credential.KeyId
                    CredentialId      = [string]$credential.CredentialId
                    Id                = [string]$credential.Id
                    Type              = [string]$credential.Type
                    Usage             = [string]$credential.Usage
                    StartDateTime     = [string]$credential.StartDateTime
                    EndDateTime       = [string]$credential.EndDateTime
                    DisplayName       = [string]$credential.DisplayName
                }
                if ($credential.PSObject.Properties['AdditionalProperties']) {
                    $credentialMetadata['AdditionalProperties'] = ConvertTo-NhiControlledSanitizedValue -Value $credential.AdditionalProperties -PropertyName 'AdditionalProperties'
                }
                $metadata += [PSCustomObject]$credentialMetadata
            }
            $sanitized[$property.Name] = $metadata
            continue
        }
        if ($property.Name -match $script:SensitivePropertyPattern) {
            continue
        }
        $sanitized[$property.Name] = ConvertTo-NhiControlledSanitizedValue -Value $property.Value -PropertyName $property.Name
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
        [bool]$AllowFinalDeleteSimulation = $false,

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
    if ($script:ControlledSchemaVersion -eq '4.2' -and $ActionType -eq 'FinalDelete' -and -not $AllowFinalDeleteSimulation) {
        $reasons.Add('FinalDelete is not permitted in Rev4.2-S1.')
        $approvedActions = @()
    }
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
    $status = if (-not $QuerySucceeded) {
        'Unknown'
    } elseif ($critical.Count -eq 0 -and @($RecentActivity).Count -eq 0) {
        'Clean'
    } else {
        'Blocked'
    }
    [PSCustomObject]@{
        QuerySucceeded        = $QuerySucceeded
        DependencyCount      = @($Dependencies).Count
        CriticalDependencyCount = $critical.Count
        RecentActivityCount  = @($RecentActivity).Count
        Status               = $status
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

function Get-NhiControlledTargetCountsByType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan
    )

    $counts = [ordered]@{
        ServicePrincipal = 0
        Application      = 0
        ManagedIdentity  = 0
    }

    $planCounts = $Plan.PSObject.Properties['TargetCountsByType']
    if ($null -ne $planCounts -and $null -ne $planCounts.Value) {
        $value = $planCounts.Value
        foreach ($key in @('ServicePrincipal', 'Application', 'ManagedIdentity')) {
            if ($value -is [System.Collections.IDictionary] -and $value.Contains($key)) {
                $counts[$key] = [int]$value[$key]
            } else {
                $valueProperty = $value.PSObject.Properties[$key]
                if ($null -ne $valueProperty) {
                    $counts[$key] = [int]$valueProperty.Value
                }
            }
        }
    } else {
        $targetType = [string]$Plan.TargetType
        if ($counts.Contains($targetType)) {
            $counts[$targetType] = 1
        }
    }

    [PSCustomObject]$counts
}

function Get-NhiControlledStatusText {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Value,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Default = 'Incomplete'
    )

    $status = [string]$Value
    if ([string]::IsNullOrWhiteSpace($status)) {
        $status = $Default
    }

    return $status
}

function New-NhiControlledE2EEvidencePack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter(Mandatory)]
        [object]$Approval,

        [Parameter(Mandatory)]
        [object]$Snapshot,

        [Parameter(Mandatory)]
        [object]$ScreamTest,

        [Parameter(Mandatory)]
        [object]$DependencyRecheck,

        [Parameter(Mandatory)]
        [object]$DeleteReadiness,

        [Parameter(Mandatory)]
        [object]$MetadataReadiness,

        [Parameter(Mandatory)]
        [object]$GrantReadiness,

        [Parameter(Mandatory)]
        [object]$ManagedIdentityReadiness,

        [Parameter(Mandatory)]
        [object]$OperatorDecision,

        [Parameter()]
        [object[]]$KnownWarnings = @()
    )

    $targetCounts = Get-NhiControlledTargetCountsByType -Plan $Plan
    $rollback = Get-NhiControlledRollbackLimitation -Evidence $Plan
    [PSCustomObject]@{
        SchemaVersion        = '4.8'
        RunId                = [string]$Plan.RunId
        GeneratedAtUtc       = [DateTime]::UtcNow.ToString('o')
        ToolVersion          = Get-DecomToolVersion
        PlanIdentity         = [PSCustomObject]@{
            TargetId   = [string]$Plan.TargetId
            TargetType = [string]$Plan.TargetType
            SchemaVersion = [string]$Plan.SchemaVersion
        }
        TargetCountsByType   = $targetCounts
        ApprovalCoverage     = [PSCustomObject]@{
            ApprovedBy = [string]$Approval.ApprovedBy
            Status     = Get-NhiControlledStatusText -Value $Approval.Status
            ExactTarget = ($Approval.TargetId -eq $Plan.TargetId -and $Approval.TargetType -eq $Plan.TargetType)
        }
        SnapshotCoverage     = [PSCustomObject]@{
            SHA256   = [string]$Snapshot.SHA256
            Present  = [bool]$Snapshot.SHA256
        }
        ScreamTestSummary    = [PSCustomObject]@{
            Status           = Get-NhiControlledStatusText -Value $ScreamTest.Status
            IllustrativeOnly = $true
            LiveMonitoring   = $false
        }
        DependencyRecheckSummary = [PSCustomObject]@{
            Status = Get-NhiControlledStatusText -Value $DependencyRecheck.Status
        }
        DeleteReadinessSummary   = [PSCustomObject]@{
            Status = Get-NhiControlledStatusText -Value $DeleteReadiness.Status
        }
        CleanupReadinessSummary  = [PSCustomObject]@{
            Metadata = Get-NhiControlledStatusText -Value $MetadataReadiness.Status
            Grants   = Get-NhiControlledStatusText -Value $GrantReadiness.Status
            ManagedIdentity = Get-NhiControlledStatusText -Value $ManagedIdentityReadiness.Status
        }
        RollbackLimitationSummary = [PSCustomObject]@{
            Classification = [string]$rollback.Classification
        }
        OperatorDecisionState    = $OperatorDecision
        LiveDeleteExecutable     = $false
        LiveCleanupExecutable    = $false
        GraphWritePathAvailable  = $false
        FinalDeleteSimulationOnly = $true
        SafetyAssertions         = [PSCustomObject]@{
            LiveDeleteExecutable    = $false
            LiveCleanupExecutable   = $false
            GraphWritePathAvailable = $false
        }
        ValidationResults        = [PSCustomObject]@{
            ManagedIdentityStatus = Get-NhiControlledStatusText -Value $ManagedIdentityReadiness.Status
            MetadataStatus        = Get-NhiControlledStatusText -Value $MetadataReadiness.Status
            GrantsStatus          = Get-NhiControlledStatusText -Value $GrantReadiness.Status
            DeleteReadinessStatus = Get-NhiControlledStatusText -Value $DeleteReadiness.Status
        }
        KnownWarnings            = @($KnownWarnings)
        QAHandoffManifest        = [PSCustomObject]@{
            ToolVersion        = Get-DecomToolVersion
            RunId              = [string]$Plan.RunId
            GeneratedAtUtc     = [DateTime]::UtcNow.ToString('o')
            EvidenceArtifacts  = @(
                'nhi-controlled-e2e-evidence-pack.json'
                'nhi-controlled-qa-handoff-manifest.json'
                'nhi-controlled-operator-decision-log.json'
                'nhi-controlled-managed-identity-readiness.json'
                'nhi-controlled-e2e-snapshot.json'
            )
            SafetyAssertions   = [PSCustomObject]@{
                LiveDeleteExecutable    = $false
                LiveCleanupExecutable   = $false
                GraphWritePathAvailable = $false
                FinalDeleteSimulationOnly = $true
            }
            ValidationResults   = [PSCustomObject]@{
                ManagedIdentity = Get-NhiControlledStatusText -Value $ManagedIdentityReadiness.Status
                Metadata        = Get-NhiControlledStatusText -Value $MetadataReadiness.Status
                Grants          = Get-NhiControlledStatusText -Value $GrantReadiness.Status
                DeleteReadiness = Get-NhiControlledStatusText -Value $DeleteReadiness.Status
            }
            KnownWarnings      = @($KnownWarnings)
            PushStatus         = 'No'
        }
    }
}

function New-NhiControlledOperatorDecisionLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan,

        [Parameter()]
        [string]$Decision = 'SimulationOnly',

        [Parameter()]
        [string]$DecisionBy = 'local-planner',

        [Parameter()]
        [string]$Reason = 'No live execution is allowed in unattended builds.',

        [Parameter()]
        [string]$Scope = 'Rev4.8'
    )

    [PSCustomObject]@{
        SchemaVersion   = '4.8'
        RunId           = [string]$Plan.RunId
        Decision        = $Decision
        DecisionBy      = $DecisionBy
        DecisionAtUtc   = [DateTime]::UtcNow.ToString('o')
        Reason          = $Reason
        Scope           = $Scope
        IsSimulationOnly = $true
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
        [ValidateSet('ValidateOnly', 'SnapshotOnly', 'TagOnly', 'DisableOnly', 'ScreamTestOnly', 'DeleteReadinessOnly', 'MetadataCleanupReadiness', 'GrantCleanupReadiness', 'ManagedIdentityReadiness', 'E2EEvidencePack', 'ProductionReadiness', 'FinalDelete')]
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
        FinalDeleteLiveEnabled = $false
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

function Test-NhiControlledLabLiveReversibleDisableReadiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [object]$Approval,

        [Parameter()]
        [string]$ApprovalManifestPath,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$RollbackEvidence,

        [Parameter()]
        [object]$ObservationMetadata,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TargetId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ActionType = 'DisableOnly',

        [Parameter()]
        [string]$ExpectedSchemaVersion = $script:ControlledSchemaVersion
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    if ([string]::IsNullOrWhiteSpace([string]$TargetId)) { $reasons.Add('TargetId is required.') }
    if ([string]::IsNullOrWhiteSpace([string]$RunId)) { $reasons.Add('RunId is required.') }

    $targetValidation = Test-NhiControlledTarget -Target $Target
    if (-not $targetValidation.Passed) {
        foreach ($reason in @($targetValidation.Reasons)) {
            $reasons.Add([string]$reason)
        }
    }

    $targetLabOnly = (
        [string]$Target.Environment -eq 'Lab' -or
        [bool]$Target.IsLabTarget -eq $true -or
        [string]$Target.TenantScope -eq 'Lab'
    )
    if (-not $targetLabOnly) {
        $reasons.Add('Target must be explicitly marked as lab-only.')
    }
    if ($Target.LabValidationApproved -ne $true) {
        $reasons.Add('LabValidationApproved must be true.')
    }
    if ($TargetId -ne [string]$Target.ObjectId) {
        $reasons.Add('TargetId does not match the target object.')
    }

    if ($Target.MicrosoftPlatform -eq $true -or
        $Target.FirstPartyMicrosoftApp -eq $true -or
        $Target.SuppressCustomerRemediation -eq $true -or
        [string]$Target.Classification -in @('MicrosoftPlatform', 'ExternalVendorPlatform') -or
        [string]$Target.RemediationMode -in @('InformationOnly', 'EvidenceOnly')) {
        $reasons.Add('Platform or suppressed identities are not eligible for live disable readiness.')
    }

    $allowedActions = @('DisableOnly', 'DisableServicePrincipal', 'DisableNhi', 'ControlledDisable', 'ReversibleDisable')
    if ($ActionType -notin $allowedActions) {
        $reasons.Add('Only reversible disable actions are allowed.')
    }

    if ($null -eq $Approval) {
        $reasons.Add('Approval is required.')
    } else {
        try {
            $approvalValidation = Confirm-NhiControlledApproval -Approval $Approval -RunId $RunId -TargetId $TargetId -ActionType 'DisableOnly' -ExpectedSchemaVersion $ExpectedSchemaVersion
            if (-not $approvalValidation.Passed) {
                foreach ($reason in @($approvalValidation.Reasons)) {
                    $reasons.Add([string]$reason)
                }
            }
        } catch {
            $reasons.Add("Approval validation failed: $($_.Exception.Message)")
        }
    }

    if ([string]::IsNullOrWhiteSpace($ApprovalManifestPath)) {
        $reasons.Add('ApprovalManifestPath is required.')
    } else {
        $manifestValidator = Get-Command Confirm-NhiApprovedManifest -ErrorAction SilentlyContinue
        if ($null -eq $manifestValidator) {
            $reasons.Add('Approval manifest integrity validation is unavailable.')
        } else {
            try {
                Confirm-NhiApprovedManifest -ManifestPath $ApprovalManifestPath -EngagementId $RunId -TargetObjectIds @($TargetId) -PhaseLimit 2
            } catch {
                $reasons.Add("Approval manifest validation failed: $($_.Exception.Message)")
            }
        }
    }

    if ($null -eq $Snapshot -or -not $Snapshot.SHA256) {
        $reasons.Add('Snapshot evidence is required.')
    } else {
        if ($Snapshot.Target -and $Snapshot.Target.ObjectId -and [string]$Snapshot.Target.ObjectId -ne $TargetId) {
            $reasons.Add('Snapshot must bind to the target object.')
        }
    }

    if ($null -eq $RollbackEvidence) {
        $reasons.Add('Rollback readiness evidence is required.')
    } else {
        foreach ($name in @('TargetObjectId', 'PreActionAccountEnabled', 'PlannedAction', 'RollbackActionName', 'ApprovalId', 'RunId', 'CapturedUtc')) {
            $property = $RollbackEvidence.PSObject.Properties[$name]
            if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $reasons.Add("Rollback readiness evidence is missing $name.")
            }
        }
        if ($RollbackEvidence.PSObject.Properties['PlannedAction'] -and [string]$RollbackEvidence.PlannedAction -notin $allowedActions) {
            $reasons.Add('Rollback planned action must be reversible disable only.')
        }
        if ($RollbackEvidence.PSObject.Properties['RollbackActionName'] -and [string]$RollbackEvidence.RollbackActionName -notin @('RollbackDisable', 'ReversibleRollbackDisable')) {
            $reasons.Add('Rollback action name is invalid.')
        }
    }

    if ($null -eq $ObservationMetadata) {
        $reasons.Add('Observation metadata is required.')
    } else {
        foreach ($name in @('ScreamTestWindowMinutes', 'MonitoringOwner', 'RollbackContact', 'ObservationStartUtc', 'ObservationEndUtc')) {
            $property = $ObservationMetadata.PSObject.Properties[$name]
            if ($null -eq $property -or [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $reasons.Add("Observation metadata is missing $name.")
            }
        }
        $startProp = $ObservationMetadata.PSObject.Properties['ObservationStartUtc']
        $endProp = $ObservationMetadata.PSObject.Properties['ObservationEndUtc']
        if ($null -ne $startProp -and $null -ne $endProp) {
            try {
                $startUtc = [DateTime]$startProp.Value
                $endUtc = [DateTime]$endProp.Value
                if ($startUtc -ge $endUtc) {
                    $reasons.Add('Observation end must be after observation start.')
                }
            } catch {
                $reasons.Add('Observation metadata timestamps are invalid.')
            }
        }
    }

    [PSCustomObject]@{
        SchemaVersion      = '4.12'
        RunId              = $RunId
        TargetId           = $TargetId
        TargetType         = [string]$Target.ObjectType
        RequestedAction    = $ActionType
        AllowedAction      = if ($reasons.Count -eq 0) { 'DisableOnly' } else { $null }
        Ready              = $reasons.Count -eq 0
        Blockers           = @($reasons)
        Warnings           = @($warnings)
        TenantWritePlanned = $false
        FinalDeleteAllowed = $false
        PlanningOnly       = $true
        LabOnly            = [bool]$targetLabOnly
        ApprovalValidated  = $null -ne $Approval -and [string]::IsNullOrWhiteSpace([string]$ApprovalManifestPath) -eq $false
        SnapshotValidated  = $null -ne $Snapshot -and [bool]$Snapshot.SHA256
        RollbackValidated  = $null -ne $RollbackEvidence
        ObservationValidated = $null -ne $ObservationMetadata
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

function New-NhiControlledProductionReadinessEvidenceState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return [PSCustomObject]@{
            Name    = $Name
            Present = $false
            Status  = 'Missing'
        }
    }

    $status = 'Present'
    if ($Value.PSObject.Properties['Status']) {
        $status = [string]$Value.Status
    } elseif ($Value.PSObject.Properties['Passed']) {
        $status = if ($Value.Passed -eq $true) { 'Passed' } else { 'Failed' }
    } elseif ($Value.PSObject.Properties['Approved']) {
        $status = if ($Value.Approved -eq $true) { 'Approved' } else { 'Rejected' }
    } elseif ($Value.PSObject.Properties['Clean']) {
        $status = if ($Value.Clean -eq $true) { 'Clean' } else { 'Dirty' }
    } elseif ($Value.PSObject.Properties['Complete']) {
        $status = if ($Value.Complete -eq $true) { 'Complete' } else { 'Incomplete' }
    }

    [PSCustomObject]@{
        Name    = $Name
        Present = $true
        Status  = $status
    }
}

function New-NhiControlledFindingDispositionSummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Severity,

        [Parameter()]
        [object[]]$Findings = @()
    )

    $normalized = @($Findings | Where-Object { $null -ne $_ })
    $unresolved = @($normalized | Where-Object {
        $disposition = [string]$_.Disposition
        $resolved = if ($_.PSObject.Properties['Resolved']) { [bool]$_.Resolved } else { $false }
        [string]::IsNullOrWhiteSpace($disposition) -or $disposition -notin @('Resolved', 'Mitigated', 'AcceptedRisk', 'Documented') -or -not $resolved
    })

    [PSCustomObject]@{
        Severity        = $Severity
        Count           = $normalized.Count
        UnresolvedCount = $unresolved.Count
        Blocked         = $Severity -in @('P0', 'P1') -and $unresolved.Count -gt 0
        Dispositions    = @($normalized | ForEach-Object { if ($_.Disposition) { [string]$_.Disposition } else { 'Missing' } })
    }
}

function New-NhiControlledKnownWarningInventory {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$KnownWarnings = @()
    )

    $inventory = @(
        [PSCustomObject]@{
            Warning = 'DemoMode traceability warning about $execEvidencePath not being set, if still present.'
            Severity = 'Low'
            Disposition = 'Documented'
            Source = 'LegacyAssessmentPath'
        }
        [PSCustomObject]@{
            Warning = 'Pester ConvertTo-DecomHtmlEncoded empty-string binding messages, if still present.'
            Severity = 'Low'
            Disposition = 'Documented'
            Source = 'Pester'
        }
        [PSCustomObject]@{
            Warning = 'Rev4.7/4.8 P2 follow-up: tighten empty evidence object guard.'
            Severity = 'Medium'
            Disposition = 'Open'
            Source = 'Rev4.7'
        }
        [PSCustomObject]@{
            Warning = 'Rev4.7/4.8 P2 follow-up: review non-MI default evidence synthesis.'
            Severity = 'Medium'
            Disposition = 'Open'
            Source = 'Rev4.7'
        }
        [PSCustomObject]@{
            Warning = 'Rev4.7/4.8 P2 follow-up: improve future delta QA ZIP portability.'
            Severity = 'Medium'
            Disposition = 'Open'
            Source = 'Rev4.8'
        }
    )
    $seenInventoryKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($item in @($inventory)) {
        $null = $seenInventoryKeys.Add("$($item.Warning)|$($item.Source)")
    }

    foreach ($warning in @($KnownWarnings)) {
        if ($null -eq $warning) {
            continue
        }
        if ($warning -is [string]) {
            $inventory += [PSCustomObject]@{
                Warning = $warning
                Severity = 'Medium'
                Disposition = 'Documented'
                Source = 'Input'
            }
            continue
        }
        $warningItem = [PSCustomObject]@{
            Warning = [string]$warning.Warning
            Severity = if ($warning.PSObject.Properties['Severity']) { [string]$warning.Severity } else { 'Medium' }
            Disposition = if ($warning.PSObject.Properties['Disposition']) { [string]$warning.Disposition } else { 'Documented' }
            Source = if ($warning.PSObject.Properties['Source']) { [string]$warning.Source } else { 'Input' }
        }
        $warningKey = "$($warningItem.Warning)|$($warningItem.Source)"
        if ($seenInventoryKeys.Add($warningKey)) {
            $inventory += $warningItem
        }
    }

    [PSCustomObject]@{
        SchemaVersion = '4.9'
        Items         = @($inventory)
    }
}

function New-NhiControlledFinalSafetyAssertions {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Gate
    )

    [PSCustomObject]@{
        SchemaVersion = '4.9'
        LiveDeleteExecutable = $false
        LiveCleanupExecutable = $false
        GraphWritePathAvailable = $false
        ArmWritePathAvailable = $false
        FinalDeleteSimulationOnly = $true
        ProductionUnlockGranted = $false
        ProductionExecutionEnabled = $false
        RequiresManualApprovalForProduction = $true
        RequiresExternalQAForMerge = $true
        ProductionReadyForReview = [bool]$Gate.ProductionReadyForReview
    }
}

function New-NhiControlledProductionReadinessGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Input')]
        [object]$ReadinessInput
    )

    if ($ReadinessInput -is [System.Collections.IEnumerator]) {
        $readinessInputObject = @($ReadinessInput | Select-Object -First 1)
        if ($readinessInputObject.Count -gt 0) {
            $ReadinessInput = $readinessInputObject[0]
        }
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $evidenceNames = @(
        'Rev42PlannerEvidence',
        'Rev43ServicePrincipalFinalDeleteSimulationEvidence',
        'Rev44ApplicationReadinessEvidence',
        'Rev45MetadataCleanupReadinessEvidence',
        'Rev46GrantsCleanupReadinessEvidence',
        'Rev47ManagedIdentityReadinessEvidence',
        'Rev48E2EEvidencePackEvidence',
        'ExternalQaApprovalEvidence',
        'FullPesterEvidence',
        'SafetyScanEvidence',
        'FrozenFileDiffEvidence',
        'GitStatusEvidence'
    )

    foreach ($name in $evidenceNames) {
        $property = $ReadinessInput.PSObject.Properties[$name]
        if ($null -eq $property -or $null -eq $property.Value) {
            $reasons.Add("$name is required.")
        }
    }

    $externalQa = if ($ReadinessInput.PSObject.Properties['ExternalQaApprovalEvidence']) { $ReadinessInput.ExternalQaApprovalEvidence } else { $null }
    if ($null -ne $externalQa -and $externalQa.PSObject.Properties['Approved'] -and $externalQa.Approved -ne $true) {
        $reasons.Add('External QA approval evidence must be approved.')
    }
    if ($null -ne $externalQa -and $externalQa.PSObject.Properties['Status'] -and [string]$externalQa.Status -ne 'Approved') {
        $reasons.Add('External QA approval status must be Approved.')
    }

    $fullPester = if ($ReadinessInput.PSObject.Properties['FullPesterEvidence']) { $ReadinessInput.FullPesterEvidence } else { $null }
    if ($null -ne $fullPester -and $fullPester.PSObject.Properties['Passed'] -and $fullPester.Passed -ne $true) {
        $reasons.Add('Full Pester evidence must pass.')
    }

    $safetyScan = if ($ReadinessInput.PSObject.Properties['SafetyScanEvidence']) { $ReadinessInput.SafetyScanEvidence } else { $null }
    if ($null -ne $safetyScan -and $safetyScan.PSObject.Properties['Passed'] -and $safetyScan.Passed -ne $true) {
        $reasons.Add('Safety scan evidence must pass.')
    }

    $frozenDiff = if ($ReadinessInput.PSObject.Properties['FrozenFileDiffEvidence']) { $ReadinessInput.FrozenFileDiffEvidence } else { $null }
    if ($null -ne $frozenDiff -and $frozenDiff.PSObject.Properties['Clean'] -and $frozenDiff.Clean -ne $true) {
        $reasons.Add('Frozen-file diff evidence must be clean.')
    }

    $gitStatus = if ($ReadinessInput.PSObject.Properties['GitStatusEvidence']) { $ReadinessInput.GitStatusEvidence } else { $null }
    if ($null -ne $gitStatus -and $gitStatus.PSObject.Properties['Clean'] -and $gitStatus.Clean -ne $true) {
        $reasons.Add('Git status evidence must be clean.')
    }

    $p0 = New-NhiControlledFindingDispositionSummary -Severity 'P0' -Findings (@($ReadinessInput.P0Findings))
    $p1 = New-NhiControlledFindingDispositionSummary -Severity 'P1' -Findings (@($ReadinessInput.P1Findings))
    $p2 = New-NhiControlledFindingDispositionSummary -Severity 'P2' -Findings (@($ReadinessInput.P2Findings))
    if ($p0.Blocked) { $reasons.Add('Unresolved P0 findings block readiness.') }
    if ($p1.Blocked) { $reasons.Add('Unresolved P1 findings block readiness.') }
    if ($p2.UnresolvedCount -gt 0) { $reasons.Add('P2 findings must be documented with disposition.') }

    $knownWarnings = New-NhiControlledKnownWarningInventory -KnownWarnings (@($ReadinessInput.KnownWarnings))
    foreach ($warning in $knownWarnings.Items) {
        if ([string]::IsNullOrWhiteSpace($warning.Severity) -or [string]::IsNullOrWhiteSpace($warning.Disposition)) {
            $reasons.Add('Known warnings must include severity and disposition.')
            break
        }
    }

    $finalSafetyAssertions = [PSCustomObject]@{
        SchemaVersion = '4.9'
        LiveDeleteExecutable = $false
        LiveCleanupExecutable = $false
        GraphWritePathAvailable = $false
        ArmWritePathAvailable = $false
        FinalDeleteSimulationOnly = $true
        ProductionUnlockGranted = $false
        ProductionExecutionEnabled = $false
        RequiresManualApprovalForProduction = $true
        RequiresExternalQAForMerge = $true
    }

    if ($finalSafetyAssertions.LiveDeleteExecutable -or $finalSafetyAssertions.LiveCleanupExecutable -or $finalSafetyAssertions.GraphWritePathAvailable -or $finalSafetyAssertions.ArmWritePathAvailable -or $finalSafetyAssertions.ProductionExecutionEnabled -or $finalSafetyAssertions.ProductionUnlockGranted -eq $true) {
        $reasons.Add('Final safety assertions failed.')
    }

    $productionReady = $reasons.Count -eq 0
    $operatorDecision = if ($ReadinessInput.PSObject.Properties['OperatorMergeDecision']) { $ReadinessInput.OperatorMergeDecision } else { $null }
    if ($null -eq $operatorDecision) {
        $operatorDecisionDecision = if ($productionReady) { 'ReadyForReview' } else { 'Blocked' }
        $operatorDecisionReason = if ($productionReady) { 'External QA and merge-gate evidence required before any manual merge decision.' } else { 'Evidence is incomplete or blocked.' }
        $operatorDecision = [PSCustomObject]@{
            Decision = $operatorDecisionDecision
            DecisionBy = 'local-planner'
            DecisionAtUtc = [DateTime]::UtcNow.ToString('o')
            Reason = $operatorDecisionReason
            Scope = 'Rev4.9'
            IsExecuting = $false
        }
    }

    $rev42PlannerEvidenceValue = if ($ReadinessInput.PSObject.Properties['Rev42PlannerEvidence']) { $ReadinessInput.Rev42PlannerEvidence } else { $null }
    $rev43ServicePrincipalFinalDeleteSimulationEvidenceValue = if ($ReadinessInput.PSObject.Properties['Rev43ServicePrincipalFinalDeleteSimulationEvidence']) { $ReadinessInput.Rev43ServicePrincipalFinalDeleteSimulationEvidence } else { $null }
    $rev44ApplicationReadinessEvidenceValue = if ($ReadinessInput.PSObject.Properties['Rev44ApplicationReadinessEvidence']) { $ReadinessInput.Rev44ApplicationReadinessEvidence } else { $null }
    $rev45MetadataCleanupReadinessEvidenceValue = if ($ReadinessInput.PSObject.Properties['Rev45MetadataCleanupReadinessEvidence']) { $ReadinessInput.Rev45MetadataCleanupReadinessEvidence } else { $null }
    $rev46GrantsCleanupReadinessEvidenceValue = if ($ReadinessInput.PSObject.Properties['Rev46GrantsCleanupReadinessEvidence']) { $ReadinessInput.Rev46GrantsCleanupReadinessEvidence } else { $null }
    $rev47ManagedIdentityReadinessEvidenceValue = if ($ReadinessInput.PSObject.Properties['Rev47ManagedIdentityReadinessEvidence']) { $ReadinessInput.Rev47ManagedIdentityReadinessEvidence } else { $null }
    $rev48E2EEvidencePackEvidenceValue = if ($ReadinessInput.PSObject.Properties['Rev48E2EEvidencePackEvidence']) { $ReadinessInput.Rev48E2EEvidencePackEvidence } else { $null }
    $productionReadyStatus = if ($productionReady) { 'ReadyForReview' } else { 'Blocked' }

    [PSCustomObject]@{
        SchemaVersion = '4.9'
        Status = $productionReadyStatus
        ProductionReadyForReview = $productionReady
        ProductionExecutionEnabled = $false
        ProductionUnlockGranted = $false
        RequiresManualApprovalForProduction = $true
        RequiresExternalQAForMerge = $true
        Reasons = @($reasons)
        FinalSafetyAssertions = $finalSafetyAssertions
        RequiredEvidence = [PSCustomObject]@{
            Rev42PlannerEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'Rev42PlannerEvidence' -Value $rev42PlannerEvidenceValue
            Rev43ServicePrincipalFinalDeleteSimulationEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'Rev43ServicePrincipalFinalDeleteSimulationEvidence' -Value $rev43ServicePrincipalFinalDeleteSimulationEvidenceValue
            Rev44ApplicationReadinessEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'Rev44ApplicationReadinessEvidence' -Value $rev44ApplicationReadinessEvidenceValue
            Rev45MetadataCleanupReadinessEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'Rev45MetadataCleanupReadinessEvidence' -Value $rev45MetadataCleanupReadinessEvidenceValue
            Rev46GrantsCleanupReadinessEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'Rev46GrantsCleanupReadinessEvidence' -Value $rev46GrantsCleanupReadinessEvidenceValue
            Rev47ManagedIdentityReadinessEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'Rev47ManagedIdentityReadinessEvidence' -Value $rev47ManagedIdentityReadinessEvidenceValue
            Rev48E2EEvidencePackEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'Rev48E2EEvidencePackEvidence' -Value $rev48E2EEvidencePackEvidenceValue
            ExternalQaApprovalEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'ExternalQaApprovalEvidence' -Value $externalQa
            FullPesterEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'FullPesterEvidence' -Value $fullPester
            SafetyScanEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'SafetyScanEvidence' -Value $safetyScan
            FrozenFileDiffEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'FrozenFileDiffEvidence' -Value $frozenDiff
            GitStatusEvidence = New-NhiControlledProductionReadinessEvidenceState -Name 'GitStatusEvidence' -Value $gitStatus
        }
        P0Disposition = $p0
        P1Disposition = $p1
        P2Disposition = $p2
        KnownWarnings = $knownWarnings
        OperatorMergeDecision = $operatorDecision
    }
}

function New-NhiControlledReleaseMergeGateManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Gate,

        [Parameter()]
        [Alias('Input')]
        [object]$ManifestInput
    )

    if ($ManifestInput -is [System.Collections.IEnumerator]) {
        $manifestInputObject = @($ManifestInput | Select-Object -First 1)
        if ($manifestInputObject.Count -gt 0) {
            $ManifestInput = $manifestInputObject[0]
        }
    }

    [PSCustomObject]@{
        SchemaVersion = '4.9'
        BranchName = if ($ManifestInput -and $ManifestInput.PSObject.Properties['BranchName']) { [string]$ManifestInput.BranchName } else { 'feature/rev42-controlled-nhi-decommission' }
        LatestCommit = if ($ManifestInput -and $ManifestInput.PSObject.Properties['LatestCommit']) { [string]$ManifestInput.LatestCommit } else { 'dc1a214' }
        GitStatusClean = if ($ManifestInput -and $ManifestInput.PSObject.Properties['GitStatusClean']) { [bool]$ManifestInput.GitStatusClean } else { $true }
        FrozenFileDiffClean = if ($ManifestInput -and $ManifestInput.PSObject.Properties['FrozenFileDiffClean']) { [bool]$ManifestInput.FrozenFileDiffClean } else { $true }
        PushStatus = 'No'
        MergeStatus = if ($Gate.ProductionReadyForReview) { 'ReadyForReview' } else { 'Blocked' }
        ExternalQARequired = $true
        MergeExecuted = $false
        TagExecuted = $false
        DeleteBranchExecuted = $false
        PushExecuted = $false
        OperatorMergeDecision = $Gate.OperatorMergeDecision
    }
}

function New-NhiControlledMergeGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Gate,

        [Parameter()]
        [object]$Manifest
    )

    [PSCustomObject]@{
        SchemaVersion = '4.9'
        ReviewReady = [bool]$Gate.ProductionReadyForReview
        MergeDecisionRecorded = $true
        MergeExecuted = $false
        PushPerformed = $false
        TagPerformed = $false
        DeleteBranchPerformed = $false
        ManualApprovalRequired = $true
        ExternalQARequired = $true
        MergeBlocked = -not [bool]$Gate.ProductionReadyForReview
        ManifestBranchName = if ($Manifest -and $Manifest.BranchName) { [string]$Manifest.BranchName } else { $null }
    }
}

function New-NhiControlledProductionReadinessEvidencePack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [Alias('Input')]
        [object]$ReadinessInput
    )

    if ($ReadinessInput -is [System.Collections.IEnumerator]) {
        $readinessInputObject = @($ReadinessInput | Select-Object -First 1)
        if ($readinessInputObject.Count -gt 0) {
            $ReadinessInput = $readinessInputObject[0]
        }
    }

    $gate = New-NhiControlledProductionReadinessGate -Input $ReadinessInput
    $releaseManifest = New-NhiControlledReleaseMergeGateManifest -Gate $gate -Input $ReadinessInput
    $mergeGate = New-NhiControlledMergeGate -Gate $gate -Manifest $releaseManifest
    $warnings = if ($ReadinessInput.PSObject.Properties['KnownWarnings']) { $ReadinessInput.KnownWarnings } else { @() }
    $warningInventory = New-NhiControlledKnownWarningInventory -KnownWarnings $warnings

    [PSCustomObject]@{
        SchemaVersion = '4.9'
        RunId = if ($ReadinessInput.PSObject.Properties['RunId']) { [string]$ReadinessInput.RunId } else { 'RUN-REV49-PROD-001' }
        GeneratedAtUtc = [DateTime]::UtcNow.ToString('o')
        ProductionReadiness = $gate
        Reasons = @($gate.Reasons)
        ReleaseManifest = $releaseManifest
        MergeGate = $mergeGate
        KnownWarnings = $warningInventory
        FinalSafetyAssertions = New-NhiControlledFinalSafetyAssertions -Gate $gate
        OperatorMergeDecision = $gate.OperatorMergeDecision
        ProductionReadyForReview = $gate.ProductionReadyForReview
        ProductionExecutionEnabled = $false
        FinalDeleteSimulationOnly = $true
    }
}

function Get-NhiControlledPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$PropertyNames,

        [Parameter()]
        [object]$Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    foreach ($propertyName in @($PropertyNames)) {
        if ($InputObject.PSObject.Properties[$propertyName]) {
            return $InputObject.PSObject.Properties[$propertyName].Value
        }
    }

    return $Default
}

function New-NhiControlledChecklist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Items
    )

    @(foreach ($item in @($Items)) {
        [PSCustomObject]@{
            Checked = $false
            Required = $true
            Item = $item
        }
    })
}

function New-NhiControlledLabDisableDryRunPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter()]
        [object]$ReadinessResult,

        [Parameter()]
        [object]$Approval,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$RollbackReadiness,

        [Parameter()]
        [object]$ObservationMetadata,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $targetValidation = Test-NhiControlledTarget -Target $Target
    if (-not $targetValidation.Passed) {
        foreach ($reason in @($targetValidation.Reasons)) {
            $reasons.Add([string]$reason)
        }
    }

    if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectId')))) {
        $reasons.Add('Target ObjectId is required.')
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('DisplayName')))) {
        $reasons.Add('TargetDisplayName is required.')
    }
    if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('AppId')))) {
        $warnings.Add('TargetAppId is missing.')
    }

    $targetType = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectType', 'TargetType'))
    if ($targetType -ne 'ServicePrincipal') {
        $reasons.Add('Dry-run package generation is limited to ServicePrincipal targets.')
    }

    $targetLabOnly = (
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Environment')) -eq 'Lab' -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('TenantScope')) -eq 'Lab' -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
    )
    if (-not $targetLabOnly) {
        $reasons.Add('Target must be explicitly marked as lab-only.')
    }

    if ([bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('FirstPartyMicrosoftApp') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('SuppressCustomerRemediation') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('EvidenceOnly') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Classification')) -in @('MicrosoftPlatform', 'ExternalVendorPlatform') -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('RemediationMode')) -in @('InformationOnly', 'EvidenceOnly')) {
        $reasons.Add('Platform, suppressed, or evidence-only targets are not eligible for a dry-run operator package.')
    }

    if ($null -eq $ReadinessResult) {
        $reasons.Add('Readiness result is required.')
    } else {
        if ($ReadinessResult.PSObject.Properties['Ready'] -and $ReadinessResult.Ready -ne $true) {
            $reasons.Add('Readiness result must be Ready.')
        }
        $readinessAction = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessResult -PropertyNames @('AllowedAction', 'RequestedAction', 'ActionType'))
        if ($readinessAction -and $readinessAction -notin @('DisableOnly', 'ReversibleDisable')) {
            $reasons.Add('Readiness result must represent reversible disable readiness.')
        }
    }

    if ($null -eq $Approval) {
        $reasons.Add('Approval metadata is required.')
    }
    if ($null -eq $Snapshot) {
        $reasons.Add('Snapshot metadata is required.')
    }
    if ($null -eq $RollbackReadiness) {
        $reasons.Add('Rollback readiness metadata is required.')
    }
    if ($null -eq $ObservationMetadata) {
        $reasons.Add('Observation metadata is required.')
    }

    $approvalId = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalId'))
    $approvalManifestId = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalManifestId', 'ManifestId'))
    $approvalExpiresUtc = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc'))
    $approvalManifestHash = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalManifestHash', 'SHA256'))
    $approvedBy = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovedBy', 'Approver'))
    $approvalReason = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovalReason', 'BusinessJustification', 'Reason'))
    $approvedAction = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvalRunId = [string](Get-NhiControlledPropertyValue -InputObject $Approval -PropertyNames @('RunId'))
    if ([string]::IsNullOrWhiteSpace($approvalId)) { $reasons.Add('ApprovalId is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalManifestId)) { $reasons.Add('ApprovalManifestId is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalExpiresUtc)) { $reasons.Add('ApprovalExpiresUtc is required.') }
    if ([string]::IsNullOrWhiteSpace($approvedBy)) { $reasons.Add('ApprovedBy is required.') }
    if ([string]::IsNullOrWhiteSpace($approvedAction)) { $reasons.Add('ApprovedAction is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalRunId)) { $reasons.Add('Approval RunId is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalManifestHash)) {
        $warnings.Add('ApprovalManifestHash is missing.')
    }
    if ([string]::IsNullOrWhiteSpace($approvalReason)) {
        $warnings.Add('Approval reason is missing.')
    }
    if ($approvalRunId -and $approvalRunId -ne $RunId) {
        $reasons.Add('Approval RunId must match the package RunId.')
    }

    if ($approvalExpiresUtc) {
        try {
            if ([DateTime]::Parse($approvalExpiresUtc).ToUniversalTime() -le [DateTime]::UtcNow) {
                $reasons.Add('Approval is expired.')
            }
        } catch {
            $reasons.Add('ApprovalExpiresUtc is not parseable.')
        }
    }

    $approvalActions = @()
    if ($null -ne $Approval -and $Approval.PSObject.Properties['ApprovedActions']) {
        $approvalActions = @($Approval.PSObject.Properties['ApprovedActions'].Value)
    }
    if ($approvalActions.Count -gt 0 -and ($approvalActions -notcontains 'DisableOnly' -and $approvalActions -notcontains 'ReversibleDisable')) {
        $reasons.Add('Approval must include reversible disable approval.')
    }

    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotPath', 'Path'))
    $capturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $preActionEnabledState = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionEnabledState', 'AccountEnabled')
    $preActionCredentialCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionCredentialCount', 'CredentialCount')
    $preActionOwnerCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionOwnerCount', 'OwnerCount')
    $preActionAppRoleAssignmentsCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionAppRoleAssignmentsCount', 'AppRoleAssignmentsCount')
    $preActionOAuthGrantCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionOAuthGrantCount', 'OAuthGrantCount')
    if ([string]::IsNullOrWhiteSpace($snapshotId) -and [string]::IsNullOrWhiteSpace($snapshotPath)) { $reasons.Add('SnapshotId or SnapshotPath is required.') }
    if ([string]::IsNullOrWhiteSpace($capturedUtc)) { $reasons.Add('Snapshot CapturedUtc is required.') }
    if ($null -eq $preActionEnabledState) { $reasons.Add('Pre-action enabled state is required.') }
    if ($null -eq $preActionCredentialCount) { $reasons.Add('Pre-action credential count is required.') }
    if ($null -eq $preActionOwnerCount) { $reasons.Add('Pre-action owner count is required.') }
    if ($null -eq $preActionAppRoleAssignmentsCount) { $reasons.Add('Pre-action app role assignments count is required.') }
    if ($null -eq $preActionOAuthGrantCount) { $reasons.Add('Pre-action OAuth grant count is required.') }

    $rollbackTargetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('TargetObjectId'))
    $rollbackPreActionEnabled = Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('PreActionAccountEnabled', 'PreActionEnabledState')
    $rollbackPlannedAction = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('PlannedAction'))
    $rollbackActionName = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('RollbackActionName'))
    $rollbackApprovalId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('ApprovalId'))
    $rollbackRunId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('RunId'))
    $rollbackCapturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('CapturedUtc'))
    $rollbackSnapshotId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('SnapshotId', 'SnapshotPath'))
    $rollbackBaselineHash = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('BaselineHash', 'SnapshotSHA256'))
    $rollbackEvidenceSourcePath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadiness -PropertyNames @('EvidenceSourcePath'))
    if ([string]::IsNullOrWhiteSpace($rollbackTargetObjectId)) { $reasons.Add('Rollback target object id is required.') }
    if ($null -eq $rollbackPreActionEnabled) { $reasons.Add('Rollback pre-action enabled state is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackPlannedAction)) { $reasons.Add('Rollback planned action is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackActionName)) { $reasons.Add('Rollback action name is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackApprovalId)) { $reasons.Add('Rollback approval id is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackRunId)) { $reasons.Add('Rollback run id is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackCapturedUtc)) { $reasons.Add('Rollback captured timestamp is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackSnapshotId)) { $warnings.Add('Rollback snapshot linkage is missing.') }
    if ([string]::IsNullOrWhiteSpace($rollbackBaselineHash)) { $warnings.Add('Rollback baseline hash is missing.') }
    if ([string]::IsNullOrWhiteSpace($rollbackEvidenceSourcePath)) { $warnings.Add('Rollback evidence source path is missing.') }

    $observationWindowMinutes = Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('ObservationWindowMinutes', 'ScreamTestWindowMinutes')
    $monitoringOwner = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('MonitoringOwner'))
    $rollbackContact = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('RollbackContact'))
    $observationStartUtc = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('ObservationStartUtc'))
    $observationEndUtc = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('ObservationEndUtc'))
    $successCriteria = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('SuccessCriteria'))
    $failureCriteria = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('FailureCriteria'))
    $rollbackTriggerCriteria = Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('RollbackTriggerCriteria')
    if ($null -eq $observationWindowMinutes) { $reasons.Add('Observation window minutes is required.') }
    if ([string]::IsNullOrWhiteSpace($monitoringOwner)) { $reasons.Add('Monitoring owner is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackContact)) { $reasons.Add('Rollback contact is required.') }
    if ([string]::IsNullOrWhiteSpace($observationStartUtc)) { $reasons.Add('Observation start timestamp is required.') }
    if ([string]::IsNullOrWhiteSpace($observationEndUtc)) { $reasons.Add('Observation end timestamp is required.') }
    if ([string]::IsNullOrWhiteSpace($successCriteria)) { $reasons.Add('Success criteria is required.') }
    if ([string]::IsNullOrWhiteSpace($failureCriteria)) { $reasons.Add('Failure criteria is required.') }
    if ($null -eq $rollbackTriggerCriteria -or @($rollbackTriggerCriteria).Count -eq 0) { $reasons.Add('Rollback trigger criteria is required.') }

    $package = $null
    $artifactPath = $null
    $ready = $reasons.Count -eq 0

    if ($ready) {
        $targetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('DisplayName'))
        $targetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectId'))
        $targetAppId = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('AppId'))
        $classification = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Classification'))
        $labMarker = if ([bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
        $package = [PSCustomObject]@{
            PackageId = "REV413-$RunId-$targetObjectId"
            RunId = $RunId
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
            ToolVersion = '4.13'
            SchemaVersion = '4.13'
            Mode = 'OperatorDryRun'
            TenantWritePlanned = $false
            ExecutionPerformed = $false
            FinalDeleteAllowed = $false
            Ready = $true
            Blockers = @()
            Warnings = @($warnings)
            TargetDisplayName = $targetDisplayName
            TargetObjectId = $targetObjectId
            TargetAppId = $targetAppId
            TargetType = $targetType
            Classification = $classification
            SuppressCustomerRemediation = [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('SuppressCustomerRemediation') -Default $false)
            EvidenceOnly = [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('EvidenceOnly') -Default $false)
            LabTargetMarker = $labMarker
            EnvironmentIndicator = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Environment', 'TenantScope'))
            ApprovalId = $approvalId
            ApprovalManifestId = $approvalManifestId
            ApprovedAction = $approvedAction
            ApprovalExpiresUtc = $approvalExpiresUtc
            ApprovalManifestHash = $approvalManifestHash
            ApprovedBy = $approvedBy
            Approver = $approvedBy
            ApprovalReason = $approvalReason
            ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
            ReadinessVerdict = [PSCustomObject]@{
                Ready = [bool]$ReadinessResult.Ready
                Blockers = @($ReadinessResult.Blockers)
                Warnings = @($ReadinessResult.Warnings)
                AllowedAction = 'ReversibleDisable'
                ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness'
            }
            PreActionSnapshot = [PSCustomObject]@{
                SnapshotId = $snapshotId
                SnapshotPath = $snapshotPath
                PreActionEnabledState = [bool]$preActionEnabledState
                AccountEnabled = [bool]$preActionEnabledState
                PreActionCredentialCount = [int]$preActionCredentialCount
                PreActionOwnerCount = [int]$preActionOwnerCount
                PreActionAppRoleAssignmentsCount = [int]$preActionAppRoleAssignmentsCount
                PreActionOAuthGrantCount = [int]$preActionOAuthGrantCount
                CapturedUtc = $capturedUtc
            }
            PlannedAction = [PSCustomObject]@{
                PlannedAction = 'ReversibleDisable'
                LiveCommandPreview = "WhatIf: ServicePrincipal account disable preview for $targetObjectId"
                PseudoCommand = "WhatIf: ServicePrincipalAccountEnabled=`$false for $targetObjectId"
                WhatIf = $true
                ConfirmRequired = $true
                HumanApprovalRequired = $true
                ExpectedChange = 'disable only'
                ProhibitedOperations = @(
                    'final delete',
                    'service principal removal',
                    'application removal',
                    'grant cleanup',
                    'metadata cleanup',
                    'credential deletion'
                )
            }
            RollbackReadiness = [PSCustomObject]@{
                TargetObjectId = $rollbackTargetObjectId
                PreActionAccountEnabled = [bool]$rollbackPreActionEnabled
                PlannedAction = $rollbackPlannedAction
                RollbackActionName = $rollbackActionName
                ApprovalId = $rollbackApprovalId
                RunId = $rollbackRunId
                CapturedUtc = $rollbackCapturedUtc
                SnapshotId = $rollbackSnapshotId
                BaselineHash = $rollbackBaselineHash
                EvidenceSourcePath = $rollbackEvidenceSourcePath
            }
            Observation = [PSCustomObject]@{
                ObservationWindowMinutes = [int]$observationWindowMinutes
                MonitoringOwner = $monitoringOwner
                RollbackContact = $rollbackContact
                ObservationStartUtc = $observationStartUtc
                ObservationEndUtc = $observationEndUtc
                SuccessCriteria = $successCriteria
                FailureCriteria = $failureCriteria
                RollbackTriggerCriteria = @($rollbackTriggerCriteria)
                RollbackTriggerCriteriaText = @($rollbackTriggerCriteria | ForEach-Object { [string]$_ })
            }
            OperatorChecklist = New-NhiControlledChecklist -Items @(
                'Confirm this is a lab-only tenant/target.',
                'Confirm target is not MicrosoftPlatform.',
                'Confirm target is not ExternalVendorPlatform.',
                'Confirm SuppressCustomerRemediation is false.',
                'Confirm EvidenceOnly is false.',
                'Confirm approval is current and unexpired.',
                'Confirm pre-action snapshot exists.',
                'Confirm rollback package exists.',
                'Confirm observation window is staffed.',
                'Confirm no final delete is requested.',
                'Confirm dry-run package has been reviewed by human operator.'
            )
            ProhibitedOperations = @(
                'final delete',
                'service principal removal',
                'application removal',
                'grant cleanup',
                'metadata cleanup',
                'credential deletion'
            )
        }

        if ($OutputPath) {
            $artifactPath = Export-NhiControlledDecommissionEvidence -Evidence $package -Path $OutputPath
            $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue $artifactPath -Force
        }
    }

    [PSCustomObject]@{
        SchemaVersion = '4.13'
        PackageType = 'LabDisableDryRun'
        PackageId = if ($package) { $package.PackageId } else { $null }
        RunId = $RunId
        CreatedUtc = if ($package) { $package.CreatedUtc } else { [DateTime]::UtcNow.ToString('o') }
        ToolVersion = '4.13'
        Mode = 'OperatorDryRun'
        TenantWritePlanned = $false
        ExecutionPerformed = $false
        FinalDeleteAllowed = $false
        Ready = $ready
        Blockers = @($reasons)
        Warnings = @($warnings)
        Target = if ($package) { $package | Select-Object -Property TargetDisplayName,TargetObjectId,TargetAppId,TargetType,Classification,SuppressCustomerRemediation,EvidenceOnly,LabTargetMarker,EnvironmentIndicator } else { $null }
        Approval = if ($package) { $package | Select-Object -Property ApprovalId,ApprovalManifestId,ApprovedAction,ApprovalExpiresUtc,ApprovalManifestHash,ApprovedBy,Approver,ApprovalReason } else { $null }
        ReadinessVerdict = if ($package) { $package.ReadinessVerdict } else { [PSCustomObject]@{ Ready = $false; Blockers = @($reasons); Warnings = @($warnings); AllowedAction = 'ReversibleDisable'; ReadinessFunction = 'Test-NhiControlledLabLiveReversibleDisableReadiness' } }
        PreActionSnapshot = if ($package) { $package.PreActionSnapshot } else { $null }
        PlannedAction = if ($package) { $package.PlannedAction } else { $null }
        RollbackReadiness = if ($package) { $package.RollbackReadiness } else { $null }
        Observation = if ($package) { $package.Observation } else { $null }
        OperatorChecklist = if ($package) { $package.OperatorChecklist } else { @() }
        OutputArtifactPath = $artifactPath
        ProhibitedOperations = @(
            'final delete',
            'service principal removal',
            'application removal',
            'grant cleanup',
            'metadata cleanup',
            'credential deletion'
        )
    }
}

function New-NhiControlledLabRollbackDrillPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter()]
        [object]$SourceDryRunPackage,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$RollbackTriggers,

        [Parameter()]
        [object]$RollbackValidationCriteria,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    $targetValidation = Test-NhiControlledTarget -Target $Target
    if (-not $targetValidation.Passed) {
        foreach ($reason in @($targetValidation.Reasons)) {
            $reasons.Add([string]$reason)
        }
    }

    $targetType = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectType', 'TargetType'))
    if ($targetType -ne 'ServicePrincipal') {
        $reasons.Add('Rollback drill package generation is limited to ServicePrincipal targets.')
    }

    $targetLabOnly = (
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Environment')) -eq 'Lab' -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('TenantScope')) -eq 'Lab' -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
    )
    if (-not $targetLabOnly) {
        $reasons.Add('Target must be explicitly marked as lab-only.')
    }

    if ([bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('FirstPartyMicrosoftApp') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('SuppressCustomerRemediation') -Default $false) -eq $true -or
        [bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('EvidenceOnly') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Classification')) -in @('MicrosoftPlatform', 'ExternalVendorPlatform') -or
        [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('RemediationMode')) -in @('InformationOnly', 'EvidenceOnly')) {
        $reasons.Add('Platform, suppressed, or evidence-only targets are not eligible for a rollback drill package.')
    }

    if ($null -eq $SourceDryRunPackage) {
        $reasons.Add('Source dry-run package linkage is required.')
    } else {
        $sourcePackageId = [string](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('PackageId'))
        $sourceMode = [string](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('Mode'))
        $sourceReady = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('Ready') -Default $false)
        $sourceTenantWritePlanned = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('TenantWritePlanned') -Default $true)
        $sourceExecutionPerformed = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('ExecutionPerformed') -Default $true)
        $sourcePlannedAction = Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('PlannedAction')
        $sourcePlannedActionName = if ($sourcePlannedAction -is [string]) {
            [string]$sourcePlannedAction
        } elseif ($null -ne $sourcePlannedAction) {
            [string](Get-NhiControlledPropertyValue -InputObject $sourcePlannedAction -PropertyNames @('PlannedAction'))
        } else {
            $null
        }
        if ([string]::IsNullOrWhiteSpace($sourcePackageId)) { $reasons.Add('Source dry-run package id is required.') }
        if ($sourceMode -and $sourceMode -ne 'OperatorDryRun') { $reasons.Add('Source dry-run package must be an operator dry-run package.') }
        if ($sourceReady -ne $true) { $reasons.Add('Source dry-run package must be ready.') }
        if ($sourceTenantWritePlanned -ne $false) { $reasons.Add('Source dry-run package must not plan tenant writes.') }
        if ($sourceExecutionPerformed -ne $false) { $reasons.Add('Source dry-run package must not execute.') }
        if ($null -eq $sourcePlannedActionName -or $sourcePlannedActionName -ne 'ReversibleDisable') {
            $reasons.Add('Source dry-run package must plan ReversibleDisable.')
        }
    }

    if ($null -eq $Snapshot) { $reasons.Add('Snapshot metadata is required.') }
    if ($null -eq $RollbackTriggers) { $reasons.Add('Rollback trigger criteria are required.') }
    if ($null -eq $RollbackValidationCriteria) { $reasons.Add('Rollback validation criteria are required.') }

    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotPath', 'Path'))
    $capturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $preActionEnabledState = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionEnabledState', 'AccountEnabled')
    $baselineHash = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('BaselineHash', 'SnapshotSHA256', 'SHA256'))
    $evidenceSourcePath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('EvidenceSourcePath'))
    if ([string]::IsNullOrWhiteSpace($snapshotId) -and [string]::IsNullOrWhiteSpace($snapshotPath)) { $reasons.Add('SnapshotId or SnapshotPath is required.') }
    if ([string]::IsNullOrWhiteSpace($capturedUtc)) { $reasons.Add('CapturedUtc is required.') }
    if ($null -eq $preActionEnabledState) { $reasons.Add('Pre-action enabled state is required.') }
    if ([string]::IsNullOrWhiteSpace($baselineHash)) { $reasons.Add('BaselineHash is required.') }
    if ([string]::IsNullOrWhiteSpace($evidenceSourcePath)) { $warnings.Add('Evidence source path is missing.') }

    $triggerItems = @($RollbackTriggers)
    $validationItems = @($RollbackValidationCriteria)
    if ($triggerItems.Count -eq 0) { $reasons.Add('Rollback trigger criteria cannot be empty.') }
    if ($validationItems.Count -eq 0) { $reasons.Add('Rollback validation criteria cannot be empty.') }

    $ready = $reasons.Count -eq 0
    $package = $null
    $artifactPath = $null

    if ($ready) {
        $targetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('DisplayName'))
        $targetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('ObjectId'))
        $targetAppId = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('AppId'))
        $classification = [string](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('Classification'))
        $sourcePackageId = [string](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('PackageId'))
        $package = [PSCustomObject]@{
            RollbackPackageId = "REV414-$RunId-$targetObjectId"
            RunId = $RunId
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
            SourceDryRunPackageId = $sourcePackageId
            Mode = 'RollbackDrillOnly'
            RollbackExecuted = $false
            TenantWritePlanned = $false
            FinalDeleteAllowed = $false
            Ready = $true
            Blockers = @()
            Warnings = @($warnings)
            TargetDisplayName = $targetDisplayName
            TargetObjectId = $targetObjectId
            TargetAppId = $targetAppId
            TargetType = $targetType
            LabTargetMarker = if ([bool](Get-NhiControlledPropertyValue -InputObject $Target -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
            PreActionBaseline = [PSCustomObject]@{
                PreActionEnabledState = [bool]$preActionEnabledState
                AccountEnabled = [bool]$preActionEnabledState
                SnapshotId = $snapshotId
                SnapshotPath = $snapshotPath
                CapturedUtc = $capturedUtc
                BaselineHash = $baselineHash
                EvidenceSourcePath = $evidenceSourcePath
            }
            RollbackAction = [PSCustomObject]@{
                RollbackAction = 'ReEnableServicePrincipal'
                RollbackCommandPreview = "WhatIf: ServicePrincipal account re-enable preview for $targetObjectId"
                PseudoCommand = "ReEnableServicePrincipal -TargetObjectId $targetObjectId -WhatIf"
                WhatIf = $true
                ConfirmRequired = $true
                HumanApprovalRequired = $true
                RollbackExecutionPerformed = $false
            }
            RollbackTriggerCriteria = @($triggerItems | ForEach-Object { [string]$_ })
            RollbackValidationCriteria = @($validationItems | ForEach-Object { [string]$_ })
            ProhibitedRollbackBehaviors = @(
                'delete anything',
                'remove service principal',
                'remove application',
                'recreate object as substitute for rollback',
                'modify grants',
                'modify credentials',
                'bypass approval'
            )
            OperatorChecklist = New-NhiControlledChecklist -Items @(
                'Confirm original action was reversible disable only.',
                'Confirm pre-action snapshot exists.',
                'Confirm rollback target matches approved lab target.',
                'Confirm rollback command is re-enable only.',
                'Confirm rollback does not recreate or delete objects.',
                'Confirm rollback requires human approval.',
                'Confirm rollback is not executed by this package.',
                'Confirm post-rollback validation criteria are documented.'
            )
            RollbackTriggerCriteriaText = @($triggerItems | ForEach-Object { [string]$_ })
            RollbackValidationCriteriaText = @($validationItems | ForEach-Object { [string]$_ })
            SourceDryRunPackage = [PSCustomObject]@{
                PackageId = $sourcePackageId
                Mode = [string](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('Mode'))
                Ready = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('Ready') -Default $false)
                TenantWritePlanned = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('TenantWritePlanned') -Default $true)
                ExecutionPerformed = [bool](Get-NhiControlledPropertyValue -InputObject $SourceDryRunPackage -PropertyNames @('ExecutionPerformed') -Default $true)
                PlannedAction = $sourcePlannedActionName
            }
        }

        if ($OutputPath) {
            $artifactPath = Export-NhiControlledDecommissionEvidence -Evidence $package -Path $OutputPath
            $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue $artifactPath -Force
        }
    }

    [PSCustomObject]@{
        SchemaVersion = '4.14'
        RollbackPackageType = 'RollbackDrill'
        RollbackPackageId = if ($package) { $package.RollbackPackageId } else { $null }
        RunId = $RunId
        CreatedUtc = if ($package) { $package.CreatedUtc } else { [DateTime]::UtcNow.ToString('o') }
        SourceDryRunPackageId = if ($package) { $package.SourceDryRunPackage.PackageId } else { $null }
        Mode = 'RollbackDrillOnly'
        RollbackExecuted = $false
        TenantWritePlanned = $false
        FinalDeleteAllowed = $false
        Ready = $ready
        Blockers = @($reasons)
        Warnings = @($warnings)
        Target = if ($package) { $package | Select-Object -Property TargetDisplayName,TargetObjectId,TargetAppId,TargetType,LabTargetMarker } else { $null }
        PreActionBaseline = if ($package) { $package.PreActionBaseline } else { $null }
        RollbackAction = if ($package) { $package.RollbackAction } else { $null }
        RollbackTriggerCriteria = if ($package) { $package.RollbackTriggerCriteria } else { @() }
        RollbackValidationCriteria = if ($package) { $package.RollbackValidationCriteria } else { @() }
        ProhibitedRollbackBehaviors = if ($package) { $package.ProhibitedRollbackBehaviors } else { @() }
        OperatorChecklist = if ($package) { $package.OperatorChecklist } else { @() }
        SourceDryRunPackage = if ($package) { $package.SourceDryRunPackage } else { $null }
        OutputArtifactPath = $artifactPath
    }
}

function Invoke-NhiControlledLabLiveReversibleDisable {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [object[]]$Target,

        [Parameter()]
        [object]$ApprovalManifest,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApprovalManifestPath,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$ReadinessResult,

        [Parameter()]
        [object]$DryRunPackage,

        [Parameter()]
        [object]$RollbackPackage,

        [Parameter()]
        [object]$ObservationMetadata,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$EngagementId,

        [Parameter()]
        [bool]$LabExecutionApproved = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @('ReversibleDisable')
    )

    if ([string]::IsNullOrWhiteSpace($EngagementId)) {
        $EngagementId = $RunId
    }

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetObject = $null
    $targetContext = $null

    if ($null -eq $Target -or @($Target).Count -ne 1) {
        $reasons.Add('Exactly one target is required.')
    } else {
        $targetObject = @($Target)[0]
        $targetValidation = Test-NhiControlledTarget -Target $targetObject
        if (-not $targetValidation.Passed) {
            foreach ($reason in @($targetValidation.Reasons)) {
                $reasons.Add([string]$reason)
            }
        }

        $targetContext = Get-NhiRun4CTargetContext -Target @($targetObject)
        foreach ($reason in @($targetContext.Blockers)) {
            if ($reason) {
                $reasons.Add([string]$reason)
            }
        }

        $targetType = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType'))
        if ($targetType -ne 'ServicePrincipal') {
            $reasons.Add('Run #4C execution is limited to ServicePrincipal targets.')
        }

        if ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabValidationApproved') -Default $false) -ne $true) {
            $reasons.Add('LabValidationApproved must be true.')
        }
    }

    if ($LabExecutionApproved -ne $true) {
        $reasons.Add('LabExecutionApproved must be true.')
    }

    $requestedOperations = @($RequestedOperations)
    if ($requestedOperations.Count -eq 0) {
        $reasons.Add('At least one requested operation is required.')
    } else {
        $destructivePattern = '(?i)(finaldelete|final delete|delete|harddelete|removeapplication|remove service principal|removeserviceprincipal|remove application|remove|grantcleanup|grant cleanup|metadatacleanup|metadata cleanup|credentialdelete|credential deletion|credentialdeletion|credentialchange|recreate)'
        foreach ($requestedOperation in $requestedOperations) {
            if ([string]::IsNullOrWhiteSpace([string]$requestedOperation)) {
                $reasons.Add('Requested operations cannot be empty.')
                continue
            }

            if ([string]$requestedOperation -ne 'ReversibleDisable') {
                $reasons.Add("Requested operation '$requestedOperation' is blocked.")
            }
            if ([string]$requestedOperation -match $destructivePattern) {
                $reasons.Add("Requested operation '$requestedOperation' is destructive and is blocked.")
            }
        }
    }

    if (-not (Test-Path -LiteralPath $ApprovalManifestPath -PathType Leaf)) {
        $reasons.Add('Approval manifest file is required.')
    }

    $approvalManifestFromFile = $null
    if (Test-Path -LiteralPath $ApprovalManifestPath -PathType Leaf) {
        try {
            $approvalManifestFromFile = Get-Content -LiteralPath $ApprovalManifestPath -Raw | ConvertFrom-Json
        } catch {
            $reasons.Add('Approval manifest file is not valid JSON.')
        }
    }

    if ($null -eq $ApprovalManifest) {
        $reasons.Add('Approval manifest object is required.')
    }

    $approvalId = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalId', 'Id'))
    $approvedAction = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvedBy = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedBy', 'Approver'))
    $approvalReason = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalReason', 'BusinessJustification', 'Reason'))
    $approvalExpiresUtc = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc'))
    $approvalHash = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalManifestHash', 'ManifestHash', 'SHA256'))
    $manifestTargetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $manifestTargetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetDisplayName'))
    $manifestTargetType = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetType'))

    if ([string]::IsNullOrWhiteSpace($approvalId)) { $reasons.Add('ApprovalId is required.') }
    if ([string]::IsNullOrWhiteSpace($approvedAction)) { $reasons.Add('ApprovedAction is required.') }
    if ($approvedAction -ne 'ReversibleDisable') { $reasons.Add('ApprovedAction must be ReversibleDisable.') }
    if ([string]::IsNullOrWhiteSpace($approvedBy)) { $reasons.Add('ApprovedBy is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalReason)) { $reasons.Add('ApprovalReason or BusinessJustification is required.') }
    if ([string]::IsNullOrWhiteSpace($approvalExpiresUtc)) { $reasons.Add('ApprovalExpiresUtc is required.') }
    if ($null -eq $approvalManifestFromFile) {
        $reasons.Add('Approval manifest contents could not be loaded.')
    } else {
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovalId', 'Id')))) { $reasons.Add('Approval manifest file is missing ApprovalId.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('TargetObjectId')))) { $reasons.Add('Approval manifest file is missing TargetObjectId.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('TargetDisplayName')))) { $reasons.Add('Approval manifest file is missing TargetDisplayName.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('TargetType')))) { $reasons.Add('Approval manifest file is missing TargetType.') }
        if ([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovedAction', 'ActionType')) -ne 'ReversibleDisable') { $reasons.Add('Approval manifest file must approve ReversibleDisable only.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovedBy', 'Approver')))) { $reasons.Add('Approval manifest file is missing ApprovedBy.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovalReason', 'BusinessJustification', 'Reason')))) { $reasons.Add('Approval manifest file is missing ApprovalReason or BusinessJustification.') }
        if ([string]::IsNullOrWhiteSpace([string](Get-NhiControlledPropertyValue -InputObject $approvalManifestFromFile -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc')))) { $reasons.Add('Approval manifest file is missing ApprovalExpiresUtc.') }
    }

    if ($null -ne $targetObject) {
        if ($manifestTargetObjectId -and $manifestTargetObjectId -ne [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))) {
            $reasons.Add('Approval manifest target object id must match the live target.')
        }
        if ($manifestTargetDisplayName -and $manifestTargetDisplayName -ne [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName'))) {
            $reasons.Add('Approval manifest target display name must match the live target.')
        }
        if ($manifestTargetType -and $manifestTargetType -ne [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType'))) {
            $reasons.Add('Approval manifest target type must match the live target.')
        }
    }

    if ($approvalExpiresUtc) {
        try {
            if ([DateTime]::Parse($approvalExpiresUtc).ToUniversalTime() -le [DateTime]::UtcNow) {
                $reasons.Add('Approval is expired.')
            }
        } catch {
            $reasons.Add('ApprovalExpiresUtc is not parseable.')
        }
    }

    if ([string]::IsNullOrWhiteSpace($approvalHash)) {
        $warnings.Add('Approval manifest hash is missing.')
    }

    if ($null -eq $Snapshot) {
        $reasons.Add('Snapshot is required.')
    }
    if ($null -eq $ReadinessResult) {
        $reasons.Add('Readiness result is required.')
    }
    if ($null -eq $DryRunPackage) {
        $reasons.Add('Dry-run package is required.')
    }
    if ($null -eq $RollbackPackage) {
        $reasons.Add('Rollback package is required.')
    }
    if ($null -eq $ObservationMetadata) {
        $reasons.Add('Observation metadata is required.')
    }

    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotPath', 'Path'))
    $capturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $preActionEnabledState = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionEnabledState', 'AccountEnabled')
    $preActionCredentialCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionCredentialCount', 'CredentialCount')
    $preActionOwnerCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionOwnerCount', 'OwnerCount')
    $preActionAppRoleAssignmentsCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionAppRoleAssignmentsCount', 'AppRoleAssignmentsCount')
    $preActionOAuthGrantCount = Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('PreActionOAuthGrantCount', 'OAuthGrantCount')
    if ([string]::IsNullOrWhiteSpace($snapshotId) -and [string]::IsNullOrWhiteSpace($snapshotPath)) { $reasons.Add('SnapshotId or SnapshotPath is required.') }
    if ([string]::IsNullOrWhiteSpace($capturedUtc)) { $reasons.Add('Snapshot CapturedUtc is required.') }
    if ($null -eq $preActionEnabledState) { $reasons.Add('Pre-action enabled state is required.') }
    if ($null -eq $preActionCredentialCount) { $warnings.Add('Pre-action credential count is missing.') }
    if ($null -eq $preActionOwnerCount) { $warnings.Add('Pre-action owner count is missing.') }
    if ($null -eq $preActionAppRoleAssignmentsCount) { $warnings.Add('Pre-action app role assignments count is missing.') }
    if ($null -eq $preActionOAuthGrantCount) { $warnings.Add('Pre-action OAuth grant count is missing.') }

    $readinessReady = [bool](Get-NhiControlledPropertyValue -InputObject $ReadinessResult -PropertyNames @('Ready') -Default $false)
    $readinessBlockers = @($ReadinessResult.Blockers)
    $readinessAllowedAction = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessResult -PropertyNames @('AllowedAction', 'RequestedAction', 'ActionType'))
    $readinessFinalDeleteAllowed = [bool](Get-NhiControlledPropertyValue -InputObject $ReadinessResult -PropertyNames @('FinalDeleteAllowed') -Default $true)
    if ($readinessReady -ne $true) { $reasons.Add('Readiness result must be Ready.') }
    if ($readinessAllowedAction -ne 'ReversibleDisable') { $reasons.Add('Readiness result must allow ReversibleDisable only.') }
    if ($readinessFinalDeleteAllowed -ne $false) { $reasons.Add('Readiness result must not allow final delete.') }
    if ($null -ne $readinessBlockers -and @($readinessBlockers).Count -gt 0 -and [string]::IsNullOrWhiteSpace([string]$readinessBlockers[0]) -eq $false) {
        $warnings.Add('Readiness blockers were supplied and should be reviewed before live execution.')
    }

    $dryRunReady = [bool](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('Ready') -Default $false)
    $dryRunTenantWritePlanned = [bool](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('TenantWritePlanned') -Default $true)
    $dryRunExecutionPerformed = [bool](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('ExecutionPerformed') -Default $true)
    $dryRunFinalDeleteAllowed = [bool](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('FinalDeleteAllowed') -Default $true)
    $dryRunPlannedAction = [string](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('PlannedAction', 'PlannedActionType'))
    if ($dryRunReady -ne $true) { $reasons.Add('Dry-run package must be ready.') }
    if ($dryRunTenantWritePlanned -ne $false) { $reasons.Add('Dry-run package must not plan tenant writes.') }
    if ($dryRunExecutionPerformed -ne $false) { $reasons.Add('Dry-run package must not have executed.') }
    if ($dryRunFinalDeleteAllowed -ne $false) { $reasons.Add('Dry-run package must not allow final delete.') }
    if ($dryRunPlannedAction -ne 'ReversibleDisable') { $reasons.Add('Dry-run package must plan ReversibleDisable only.') }

    $rollbackExecuted = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('RollbackExecuted') -Default $true)
    $rollbackActionName = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    $rollbackWhatIf = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('WhatIf') -Default $false)
    $rollbackHumanApprovalRequired = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('HumanApprovalRequired') -Default $false)
    if ($rollbackExecuted -ne $false) { $reasons.Add('Rollback package must not have executed.') }
    if ($rollbackActionName -ne 'ReEnableServicePrincipal') { $reasons.Add('Rollback action must be re-enable only.') }
    if ($rollbackWhatIf -ne $true) { $reasons.Add('Rollback package must be WhatIf only.') }
    if ($rollbackHumanApprovalRequired -ne $true) { $reasons.Add('Rollback package must require human approval.') }

    $observationWindowMinutes = Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('ObservationWindowMinutes', 'ScreamTestWindowMinutes')
    $monitoringOwner = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('MonitoringOwner'))
    $rollbackContact = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('RollbackContact'))
    $successCriteria = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('SuccessCriteria'))
    $failureCriteria = [string](Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('FailureCriteria'))
    $rollbackTriggerCriteria = Get-NhiControlledPropertyValue -InputObject $ObservationMetadata -PropertyNames @('RollbackTriggerCriteria')
    if ($null -eq $observationWindowMinutes) { $reasons.Add('Observation window minutes is required.') }
    if ([string]::IsNullOrWhiteSpace($monitoringOwner)) { $reasons.Add('Monitoring owner is required.') }
    if ([string]::IsNullOrWhiteSpace($rollbackContact)) { $reasons.Add('Rollback contact is required.') }
    if ([string]::IsNullOrWhiteSpace($successCriteria)) { $reasons.Add('Success criteria is required.') }
    if ([string]::IsNullOrWhiteSpace($failureCriteria)) { $reasons.Add('Failure criteria is required.') }
    if ($null -eq $rollbackTriggerCriteria -or @($rollbackTriggerCriteria).Count -eq 0) { $reasons.Add('Rollback trigger criteria is required.') }

    $liveCommandPreview = $null
    if ($null -ne $targetObject) {
        $liveCommandPreview = "Invoke-NhiDisable -ObjectId $([string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))) -ObjectType ServicePrincipal -EngagementId $EngagementId -ExecutionRunId $RunId -ExecutionOutputPath `"$OutputPath`" -ScreamTestDays 0"
    }

    $ready = $reasons.Count -eq 0
    $executionPerformed = $false
    $postActionEnabledState = $null
    $executionError = $null

    if ($ready -and $LabExecutionApproved -eq $true -and -not $WhatIfPreference) {
        try {
            Invoke-NhiDisable -ObjectId ([string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))) `
                -ObjectType 'ServicePrincipal' `
                -EngagementId $EngagementId `
                -ExecutionRunId $RunId `
                -ExecutionOutputPath $OutputPath `
                -ScreamTestDays 0
            $executionPerformed = $true
            $getServicePrincipal = Get-Command Get-MgServicePrincipal -ErrorAction SilentlyContinue
            if ($getServicePrincipal) {
                try {
                    $liveState = Get-MgServicePrincipal -ServicePrincipalId ([string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))) -Property 'AccountEnabled' -ErrorAction Stop
                    $postActionEnabledState = $liveState.AccountEnabled
                } catch {
                    $warnings.Add('Post-action enabled state could not be captured.')
                }
            }
        } catch {
            $executionError = $_.Exception.Message
            $reasons.Add('Live execution failed.')
        }
    }

    $evidence = [PSCustomObject]@{
        SchemaVersion = '4.15'
        RunId = $RunId
        EngagementId = $EngagementId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'Run4CLiveReversibleDisable'
        LabExecutionApproved = $LabExecutionApproved
        WhatIf = [bool]$WhatIfPreference
        Ready = $ready
        Blockers = @($reasons)
        Warnings = @($warnings)
        Target = if ($targetObject) {
            [PSCustomObject]@{
                TargetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName'))
                TargetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId'))
                TargetAppId = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId'))
                TargetType = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType'))
                Classification = [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification'))
                LabTargetMarker = if ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
            }
        } else { $null }
        ApprovalManifest = [PSCustomObject]@{
            ApprovalId = $approvalId
            TargetObjectId = $manifestTargetObjectId
            TargetDisplayName = $manifestTargetDisplayName
            TargetType = $manifestTargetType
            ApprovedAction = $approvedAction
            ApprovedBy = $approvedBy
            ApprovalReason = $approvalReason
            ApprovalExpiresUtc = $approvalExpiresUtc
            ApprovalManifestHash = $approvalHash
        }
        PreActionSnapshot = [PSCustomObject]@{
            SnapshotId = $snapshotId
            SnapshotPath = $snapshotPath
            PreActionEnabledState = [bool]$preActionEnabledState
            AccountEnabled = [bool]$preActionEnabledState
            PreActionCredentialCount = $preActionCredentialCount
            PreActionOwnerCount = $preActionOwnerCount
            PreActionAppRoleAssignmentsCount = $preActionAppRoleAssignmentsCount
            PreActionOAuthGrantCount = $preActionOAuthGrantCount
            CapturedUtc = $capturedUtc
        }
        DryRunPackage = [PSCustomObject]@{
            PackageId = [string](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('PackageId'))
            Ready = $dryRunReady
            TenantWritePlanned = $dryRunTenantWritePlanned
            ExecutionPerformed = $dryRunExecutionPerformed
            FinalDeleteAllowed = $dryRunFinalDeleteAllowed
            PlannedAction = $dryRunPlannedAction
        }
        RollbackPackage = [PSCustomObject]@{
            RollbackPackageId = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPackage -PropertyNames @('RollbackPackageId'))
            RollbackExecuted = $rollbackExecuted
            RollbackAction = $rollbackActionName
            WhatIf = $rollbackWhatIf
            HumanApprovalRequired = $rollbackHumanApprovalRequired
        }
        ReadinessResult = [PSCustomObject]@{
            Ready = $readinessReady
            Blockers = @($readinessBlockers)
            AllowedAction = $readinessAllowedAction
            FinalDeleteAllowed = $readinessFinalDeleteAllowed
        }
        Observation = [PSCustomObject]@{
            ObservationWindowMinutes = $observationWindowMinutes
            MonitoringOwner = $monitoringOwner
            RollbackContact = $rollbackContact
            SuccessCriteria = $successCriteria
            FailureCriteria = $failureCriteria
            RollbackTriggerCriteria = @($rollbackTriggerCriteria)
        }
        LiveCommandPreview = $liveCommandPreview
        RequestedOperations = @($requestedOperations)
        ExecutionPerformed = $executionPerformed
        ExecutionError = $executionError
        PreActionEnabledState = [bool]$preActionEnabledState
        PostActionEnabledState = $postActionEnabledState
        NoDeleteOccurred = $true
        NoRemoveOccurred = $true
        NoGrantCleanupOccurred = $true
        NoMetadataCleanupOccurred = $true
        NoCredentialDeletionOccurred = $true
        RollbackExecuted = $false
    }

    if ($OutputPath) {
        $artifactPath = Join-Path $OutputPath "Run4C-ExecutionEvidence-$RunId.json"
        $evidence | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $evidence -Path $artifactPath) -Force
    }

    return $evidence
}

function New-NhiControlledGateVerdict {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GateName,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Severity = 'High',

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Reason
    )

    [PSCustomObject]@{
        GateName = $GateName
        Passed = $Passed
        Severity = $Severity
        Reason = $Reason
    }
}

function New-NhiRun4CFinalGoNoGoReviewPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$ApprovalManifest,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$ApprovalManifestPath,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$ReadinessVerdict,

        [Parameter()]
        [object]$DryRunPackage,

        [Parameter()]
        [object]$RollbackPackage,

        [Parameter()]
        [object]$ObservationPlan,

        [Parameter()]
        [object]$OperatorChecklist,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string[]]$RequestedOperations = @()
    )

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    $targetObject = $null
    $targetCount = @($Target).Count
    $targetContext = Get-NhiRun4CTargetContext -Target $Target

    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) {
            $reasons.Add([string]$reason)
        }
    }

    if ($targetCount -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } elseif ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $targetContext = if ($targetObject) { Get-NhiRun4CTargetContext -Target @($targetObject) } else { $null }
    $remediationMode = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) } else { $null }
    $microsoftPlatform = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -or [string]$classification -eq 'MicrosoftPlatform' } else { $false }
    $firstPartyMicrosoftApp = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) } else { $false }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or $remediationMode -eq 'EvidenceOnly' } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or $remediationMode -eq 'InformationOnly' } else { $false }

    $approvalManifestPresent = $null -ne $ApprovalManifest -or (Test-Path -LiteralPath $ApprovalManifestPath -PathType Leaf)
    $approvalManifestHash = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalManifestHash', 'ManifestHash', 'SHA256'))
    $approvalExpiresUtc = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc'))
    $approvedAction = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType'))
    $approvedBy = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedBy', 'Approver'))
    $approvedTargetObjectId = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $approvedTargetType = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetType'))
    $approvedTargetDisplayName = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetDisplayName'))

    $snapshotPresent = $null -ne $Snapshot
    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('SnapshotPath', 'Path'))

    $readinessPresent = $null -ne $ReadinessVerdict
    $readinessReady = [bool](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('Ready') -Default $false)
    $readinessAllowedAction = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('AllowedAction', 'RequestedAction', 'ActionType'))

    $dryRunPresent = $null -ne $DryRunPackage
    $rollbackPresent = $null -ne $RollbackPackage
    $observationPresent = $null -ne $ObservationPlan
    $operatorChecklistPresent = $null -ne $OperatorChecklist

    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) {
            $reasons.Add([string]$reason)
        }
    }

    $gateChecks = [ordered]@{}
    $gateChecks['ExactlyOneTarget'] = @($Target).Count -eq 1
    $gateChecks['LabOrDevTestTenantOnly'] = $targetObject -and (
        [string]$environment -in @('Lab', 'DevTest', 'DevTestLab', 'Test') -or
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -in @('Lab', 'DevTest', 'Test') -or
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
    )
    $gateChecks['ApprovedTarget'] = $approvalManifestPresent -and $targetObject -and $approvedTargetObjectId -eq $targetObjectId -and $approvedTargetType -eq $targetType -and $approvedTargetDisplayName -eq $targetDisplayName
    $gateChecks['ApprovalNotExpired'] = $false
    if ($approvalExpiresUtc) {
        try {
            $gateChecks['ApprovalNotExpired'] = [DateTime]::Parse($approvalExpiresUtc).ToUniversalTime() -gt [DateTime]::UtcNow
        } catch {
            $gateChecks['ApprovalNotExpired'] = $false
        }
    }
    $gateChecks['ApprovedActionIsReversibleDisable'] = $approvedAction -eq 'ReversibleDisable'
    $gateChecks['NotMicrosoftPlatform'] = $targetObject -and ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -ne $true) -and ($classification -notin @('MicrosoftPlatform'))
    $gateChecks['NotExternalVendorPlatform'] = $targetObject -and ($classification -ne 'ExternalVendorPlatform')
    $gateChecks['NotSuppressed'] = -not $suppressCustomerRemediation
    $gateChecks['NotEvidenceOnly'] = -not $evidenceOnly
    $gateChecks['NotInformationOnly'] = -not $informationOnly
    $gateChecks['SnapshotPresent'] = $snapshotPresent -and (-not [string]::IsNullOrWhiteSpace($snapshotId) -or -not [string]::IsNullOrWhiteSpace($snapshotPath))
    $gateChecks['ReadinessReady'] = $readinessPresent -and $readinessReady -and $readinessAllowedAction -eq 'ReversibleDisable'
    $gateChecks['DryRunPackagePresent'] = $dryRunPresent
    $gateChecks['RollbackPackagePresent'] = $rollbackPresent
    $gateChecks['ObservationPlanPresent'] = $observationPresent
    $gateChecks['NoFinalDeleteRequested'] = -not (@($requestedOperations) -match '(?i)^FinalDelete$|^FinalDeleteRequested$|^Delete$')
    $gateChecks['NoRemoveRequested'] = -not (@($requestedOperations) -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$')
    $gateChecks['NoGrantCleanupRequested'] = -not (@($requestedOperations) -match '(?i)^GrantCleanup$')
    $gateChecks['NoMetadataCleanupRequested'] = -not (@($requestedOperations) -match '(?i)^MetadataCleanup$')
    $gateChecks['NoCredentialDeleteRequested'] = -not (@($requestedOperations) -match '(?i)^CredentialDelete$')
    $gateChecks['OperatorReviewRequired'] = $operatorChecklistPresent -or $true
    $gateChecks['HumanGoNoGoRequired'] = $true

    foreach ($gateName in $gateChecks.Keys) {
        $passed = [bool]$gateChecks[$gateName]
        $severity = if ($passed) { 'Info' } else { 'High' }
        $reason = switch ($gateName) {
            'ExactlyOneTarget' { if ($passed) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } }
            'LabOrDevTestTenantOnly' { if ($passed) { 'Target is labeled as lab/dev/test.' } else { 'Target is not labeled as lab/dev/test.' } }
            'ApprovedTarget' { if ($passed) { 'Approval target matches the requested target.' } else { 'Approval target does not match the requested target.' } }
            'ApprovalNotExpired' { if ($passed) { 'Approval is current.' } else { 'Approval is missing or expired.' } }
            'ApprovedActionIsReversibleDisable' { if ($passed) { 'Approved action is ReversibleDisable.' } else { 'Approved action is not ReversibleDisable.' } }
            'NotMicrosoftPlatform' { if ($passed) { 'Target is not MicrosoftPlatform.' } else { 'MicrosoftPlatform target is blocked.' } }
            'NotExternalVendorPlatform' { if ($passed) { 'Target is not ExternalVendorPlatform.' } else { 'ExternalVendorPlatform target is blocked.' } }
            'NotSuppressed' { if ($passed) { 'Target is not suppressed.' } else { 'SuppressCustomerRemediation target is blocked.' } }
            'NotEvidenceOnly' { if ($passed) { 'Target is not evidence-only.' } else { 'EvidenceOnly target is blocked.' } }
            'NotInformationOnly' { if ($passed) { 'Target is not information-only.' } else { 'InformationOnly target is blocked.' } }
            'SnapshotPresent' { if ($passed) { 'Snapshot metadata is present.' } else { 'Snapshot metadata is missing.' } }
            'ReadinessReady' { if ($passed) { 'Readiness verdict is Ready.' } else { 'Readiness verdict is missing or not Ready.' } }
            'DryRunPackagePresent' { if ($passed) { 'Dry-run package is present.' } else { 'Dry-run package is missing.' } }
            'RollbackPackagePresent' { if ($passed) { 'Rollback package is present.' } else { 'Rollback package is missing.' } }
            'ObservationPlanPresent' { if ($passed) { 'Observation plan is present.' } else { 'Observation plan is missing.' } }
            'NoFinalDeleteRequested' { if ($passed) { 'Final delete was not requested.' } else { 'Final delete was requested.' } }
            'NoRemoveRequested' { if ($passed) { 'Remove action was not requested.' } else { 'Remove action was requested.' } }
            'NoGrantCleanupRequested' { if ($passed) { 'Grant cleanup was not requested.' } else { 'Grant cleanup was requested.' } }
            'NoMetadataCleanupRequested' { if ($passed) { 'Metadata cleanup was not requested.' } else { 'Metadata cleanup was requested.' } }
            'NoCredentialDeleteRequested' { if ($passed) { 'Credential delete was not requested.' } else { 'Credential delete was requested.' } }
            'OperatorReviewRequired' { 'Operator review is required.' }
            'HumanGoNoGoRequired' { 'Human go/no-go is required.' }
        }
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gateName -Passed $passed -Severity $severity -Reason $reason))
        if (-not $passed) { $reasons.Add("$gateName failed: $reason") }
    }

    $goNoGo = if ($reasons.Count -eq 0) { 'Go' } else { 'NoGo' }
    $package = [PSCustomObject]@{
        ReviewPackageId = "REV416-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'FinalGoNoGoReviewOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        Classification = $classification
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        SuppressCustomerRemediation = $suppressCustomerRemediation
        EvidenceOnly = $evidenceOnly
        InformationOnly = $informationOnly
        InputArtifactSummary = [PSCustomObject]@{
            ApprovalManifestPresent = $approvalManifestPresent
            ApprovalManifestPath = $ApprovalManifestPath
            ApprovalManifestHash = $approvalManifestHash
            SnapshotPresent = $snapshotPresent
            SnapshotPath = $snapshotPath
            SnapshotId = $snapshotId
            ReadinessVerdictPresent = $readinessPresent
            DryRunPackagePresent = $dryRunPresent
            RollbackPackagePresent = $rollbackPresent
            ObservationPlanPresent = $observationPresent
            OperatorChecklistPresent = $operatorChecklistPresent
        }
        GateVerdicts = @($gateVerdicts)
        GoNoGo = $goNoGo
        ReadyForControlledDevTestDisable = $goNoGo -eq 'Go'
        Blockers = @($reasons)
        Warnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        AllowedNextAction = if ($goNoGo -eq 'Go') { 'ControlledDevTestReversibleDisable' } else { $null }
        ProhibitedActions = @('final delete', 'remove service principal', 'remove application', 'grant cleanup', 'metadata cleanup', 'credential deletion')
        OperatorSignOff = [PSCustomObject]@{
            OperatorName = $null
            OperatorDecision = $null
            OperatorDecisionUtc = $null
            ApproverName = $null
            ApproverDecision = $null
            ApproverDecisionUtc = $null
            Notes = $null
        }
    }

    $artifactPath = Join-Path $OutputPath "Run4C-FinalGoNoGoReview-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CLiveEvidenceCapturePackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$Target,

        [Parameter()]
        [string]$TenantId,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$PostActionSnapshot,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetObject = $null
    if (@($Target).Count -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $targetContext = if ($targetObject) { Get-NhiRun4CTargetContext -Target @($targetObject) } else { $null }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'EvidenceOnly' } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }
    $tenantWritePerformed = $false
    $disablePerformed = $false
    $rollbackPerformed = $false
    $finalDeleteAllowed = $false

    if ($targetObject) {
        foreach ($reason in @($targetContext.Blockers)) {
            if ($reason) {
                $reasons.Add([string]$reason)
            }
        }
        if ([string]$environment -notin @('Lab', 'DevTest', 'DevTestLab', 'Test') -and
            [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -ne $true -and
            [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -notin @('Lab', 'DevTest', 'Test') -and
            [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -ne $true) {
            $reasons.Add('Target is not explicitly marked as lab/dev/test.')
        }
        if ($microsoftPlatform) { $reasons.Add('MicrosoftPlatform target is blocked.') }
        if ($firstPartyMicrosoftApp) { $reasons.Add('First-party Microsoft app target is blocked.') }
        if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
        if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
        if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
        if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }
    }

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    if ($requestedOperations -match '(?i)^FinalDelete$') { $reasons.Add('Final delete request is blocked.') }
    if ($requestedOperations -match '(?i)^GrantCleanup$') { $reasons.Add('Grant cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^CredentialDelete$') { $reasons.Add('Credential deletion request is blocked.') }
    if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { $reasons.Add('Remove request is blocked.') }

    $preActionSnapshotRequired = $true
    $executionEvidenceRequired = $true
    $postActionEvidenceRequired = $true
    $commandPreview = if ($targetObject) { "Invoke-NhiDisable -ObjectId $targetObjectId -ObjectType ServicePrincipal -WhatIf" } else { 'Pending target selection' }

    $preSnapshotPresent = $null -ne $PreActionSnapshot
    if (-not $preSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if ($null -eq $Target) { $reasons.Add('Target is required.') }

    $preActionEnabledState = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AccountEnabled', 'PreActionEnabledState')
    $credentialCountBefore = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CredentialCount', 'PreActionCredentialCount')
    $ownerCountBefore = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OwnerCount', 'PreActionOwnerCount')
    $appRoleAssignmentsBefore = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppRoleAssignmentsCount', 'PreActionAppRoleAssignmentsCount')
    $oauthGrantCountBefore = Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OAuthGrantCount', 'PreActionOAuthGrantCount')
    $capturedUtcBefore = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $snapshotHashBefore = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotHash', 'SHA256', 'BaselineHash'))

    $preActionEnabledStateAfter = $null
    $credentialCountAfter = $null
    $ownerCountAfter = $null
    $appRoleAssignmentsAfter = $null
    $oauthGrantCountAfter = $null
    $capturedUtcAfter = $null
    $snapshotHashAfter = $null
    $artifactPaths = @()

    $package = [PSCustomObject]@{
        EvidencePackageId = "REV417-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'LiveEvidenceCapturePlanOnly'
        TenantWritePerformed = $tenantWritePerformed
        DisablePerformed = $disablePerformed
        RollbackPerformed = $rollbackPerformed
        FinalDeleteAllowed = $finalDeleteAllowed
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        Classification = $classification
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        TenantId = $TenantId
        EvidenceScope = 'SingleTargetOnly'
        PreActionSnapshotRequired = $preActionSnapshotRequired
        AccountEnabledBefore = $preActionEnabledState
        CredentialCountBefore = $credentialCountBefore
        OwnerCountBefore = $ownerCountBefore
        AppRoleAssignmentsCountBefore = $appRoleAssignmentsBefore
        OAuthGrantCountBefore = $oauthGrantCountBefore
        CapturedUtcBefore = $capturedUtcBefore
        SnapshotHashBefore = $snapshotHashBefore
        PlannedAction = 'ReversibleDisable'
        ExecutionEvidenceRequired = $executionEvidenceRequired
        CommandPreview = $commandPreview
        OperatorIdentityPlaceholder = 'Pending'
        ExecutionStartUtcPlaceholder = 'Pending'
        ExecutionEndUtcPlaceholder = 'Pending'
        GraphRequestIdPlaceholder = 'Pending'
        CorrelationIdPlaceholder = 'Pending'
        WhatChanged = 'AccountEnabled only'
        WhatMustNotChange = @(
            'grants',
            'credentials',
            'owners',
            'app metadata',
            'app object',
            'service principal deletion'
        )
        AccountEnabledAfter = $preActionEnabledStateAfter
        CredentialCountAfter = $credentialCountAfter
        OwnerCountAfter = $ownerCountAfter
        AppRoleAssignmentsCountAfter = $appRoleAssignmentsAfter
        OAuthGrantCountAfter = $oauthGrantCountAfter
        CapturedUtcAfter = $capturedUtcAfter
        SnapshotHashAfter = $snapshotHashAfter
        EvidenceManifestHash = $null
        ArtifactPaths = @()
        EvidenceCompletenessStatus = 'Pending'
        MissingEvidence = @(
            if ($null -eq $PreActionSnapshot) { 'Pre-action snapshot' }
            'Execution evidence placeholders'
            'Post-action evidence placeholders'
        )
        SafetyAssertions = [PSCustomObject]@{
            NoFinalDelete = $true
            NoRemoveServicePrincipal = $true
            NoRemoveApplication = $true
            NoGrantCleanup = $true
            NoMetadataCleanup = $true
            NoCredentialDeletion = $true
            NoRollbackExecution = $true
        }
        Ready = $reasons.Count -eq 0
        Blockers = @($reasons)
        Warnings = @($warnings)
    }

    if ($OutputPath) {
        $artifactPath = Join-Path $OutputPath "Run4C-LiveEvidenceCapture-$RunId.json"
        $artifactPaths += $artifactPath
        $package | Add-Member -NotePropertyName ArtifactPaths -NotePropertyValue @($artifactPaths) -Force
        $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    }

    return $package
}

function New-NhiRun4CPostDisableObservationPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$Target,

        [Parameter()]
        [Nullable[int]]$ObservationWindowMinutes,

        [Parameter()]
        [string]$MonitoringOwner,

        [Parameter()]
        [string]$RollbackContact,

        [Parameter()]
        [string]$EscalationContact,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetObject = $null
    if (@($Target).Count -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'EvidenceOnly' } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }

    if ([string]$environment -notin @('Lab', 'DevTest', 'DevTestLab', 'Test') -and
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -ne $true -and
        [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -notin @('Lab', 'DevTest', 'Test') -and
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -ne $true) {
        $reasons.Add('Target is not explicitly marked as lab/dev/test.')
    }
    if ([string]$classification -eq 'MicrosoftPlatform' -or [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true) { $reasons.Add('MicrosoftPlatform target is blocked.') }
    if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
    if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
    if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
    if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }

    if ($null -eq $ObservationWindowMinutes -or $ObservationWindowMinutes -le 0) { $reasons.Add('Observation window is required.') }
    if ([string]::IsNullOrWhiteSpace($MonitoringOwner)) { $reasons.Add('Monitoring owner is required.') }
    if ([string]::IsNullOrWhiteSpace($RollbackContact)) { $reasons.Add('Rollback contact is required.') }

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    if ($requestedOperations -match '(?i)^FinalDelete$') { $reasons.Add('Final delete request is blocked.') }
    if ($requestedOperations -match '(?i)^GrantCleanup$') { $reasons.Add('Grant cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^CredentialDelete$') { $reasons.Add('Credential deletion request is blocked.') }

    $preSnapshotPresent = $null -ne $PreActionSnapshot
    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotPath', 'Path'))
    if ($null -eq $PreActionSnapshot) {
        $warnings.Add('Pre-action snapshot is not supplied; observation remains template-only.')
    }

    $package = [PSCustomObject]@{
        ObservationPackageId = "REV418-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'PostDisableObservationPlanOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        Classification = $classification
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        ObservationScope = 'SingleTargetOnly'
        ObservationWindowMinutes = $ObservationWindowMinutes
        ObservationStartUtcPlaceholder = 'Pending'
        ObservationEndUtcPlaceholder = 'Pending'
        MonitoringOwner = $MonitoringOwner
        RollbackContact = $RollbackContact
        EscalationContact = $EscalationContact
        SuccessCriteria = @(
            'No unexpected app outage',
            'No unexpected authentication failure spike',
            'Owner/business validation passed',
            'No unauthorized secondary change',
            'No emergency rollback trigger'
        )
        FailureCriteria = @(
            'App outage detected',
            'Authentication failure spike',
            'Owner/business validation failure',
            'Unexpected permission/grant/credential change',
            'Operator stop condition'
        )
        RollbackTriggerCriteria = @(
            'Critical outage',
            'Business owner rejection',
            'Monitoring owner escalation',
            'Authentication failure threshold breached',
            'Manual operator stop'
        )
        ObservationLogPath = $null
        OperatorNotes = $null
        BusinessOwnerValidation = $null
        MonitoringSummary = $null
        EvidenceCompletenessStatus = 'Pending'
        MissingEvidence = @(
            if (-not $preSnapshotPresent) { 'Pre-action snapshot' }
            if ($null -eq $ObservationWindowMinutes -or $ObservationWindowMinutes -le 0) { 'Observation window' }
            if ([string]::IsNullOrWhiteSpace($MonitoringOwner)) { 'Monitoring owner' }
            if ([string]::IsNullOrWhiteSpace($RollbackContact)) { 'Rollback contact' }
        )
        SafetyAssertions = [PSCustomObject]@{
            ObservationOnly = $true
            RollbackNotExecuted = $true
            FinalDeleteAllowed = $false
            NoTenantMutationByObservation = $true
        }
        ObservationOnly = $true
        RollbackNotExecuted = $true
        NoTenantMutationByObservation = $true
        Ready = $reasons.Count -eq 0
        Blockers = @($reasons)
        Warnings = @($warnings)
    }

    $artifactPath = Join-Path $OutputPath "Run4C-PostDisableObservation-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CRollbackExecutionReadinessPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$OriginalDisableEvidence,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$PostDisableObservation,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$RollbackTrigger,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    $targetObject = $null
    if (@($Target).Count -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'EvidenceOnly' } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }

    if ([string]$environment -notin @('Lab', 'DevTest', 'DevTestLab', 'Test') -and
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -ne $true -and
        [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -notin @('Lab', 'DevTest', 'Test') -and
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -ne $true) {
        $reasons.Add('Target is not explicitly marked as lab/dev/test.')
    }
    if ([string]$classification -eq 'MicrosoftPlatform' -or [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true) { $reasons.Add('MicrosoftPlatform target is blocked.') }
    if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
    if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
    if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
    if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }

    $originalDisablePresent = $null -ne $OriginalDisableEvidence
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $postDisableObservationPresent = $null -ne $PostDisableObservation
    $rollbackDrillPackagePresent = $null -ne $RollbackDrillPackage
    $rollbackTriggerPresent = $null -ne $RollbackTrigger -and @($RollbackTrigger).Count -gt 0
    if (-not $originalDisablePresent) { $reasons.Add('Original disable evidence is required.') }
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $rollbackDrillPackagePresent) { $reasons.Add('Rollback drill package is required.') }
    if (-not $rollbackTriggerPresent) { $reasons.Add('Rollback trigger is required.') }

    $originalActionWasReversibleDisable = [string](Get-NhiControlledPropertyValue -InputObject $OriginalDisableEvidence -PropertyNames @('PlannedAction', 'AllowedAction', 'RequestedAction', 'ActionType')) -eq 'ReversibleDisable'
    $rollbackActionIsReEnableOnly = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('RollbackAction', 'RollbackActionName')) -eq 'ReEnableServicePrincipal'
    $rollbackDrillReady = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('Ready') -Default $false)
    $rollbackTriggerText = @($RollbackTrigger | ForEach-Object { [string]$_ })
    if (-not $originalActionWasReversibleDisable) { $reasons.Add('Original action was not reversible disable.') }
    if ($rollbackActionIsReEnableOnly -ne $true) { $reasons.Add('Rollback action must be re-enable only.') }
    if ($rollbackDrillReady -ne $true) { $reasons.Add('Rollback drill package must be ready.') }

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    if ($requestedOperations -match '(?i)^Delete$|^FinalDelete$') { $reasons.Add('Delete request is blocked.') }
    if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { $reasons.Add('Remove request is blocked.') }
    if ($requestedOperations -match '(?i)^Recreate$') { $reasons.Add('Recreate request is blocked.') }
    if ($requestedOperations -match '(?i)^GrantCleanup$') { $reasons.Add('Grant cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^CredentialChange$') { $reasons.Add('Credential change request is blocked.') }
    if ($requestedOperations -match '(?i)^MetadataCleanup$') { $reasons.Add('Metadata cleanup request is blocked.') }

    $snapshotId = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotId', 'Id'))
    $snapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotPath', 'Path'))
    $capturedUtc = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CapturedUtc', 'SnapshotTimestamp'))
    $baselineHash = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('BaselineHash', 'SnapshotSHA256', 'SHA256'))
    $evidenceSourcePath = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('EvidenceSourcePath'))

    $observationFailureOrManualTriggerPresent = $postDisableObservationPresent -or $rollbackTriggerPresent
    if (-not $observationFailureOrManualTriggerPresent) { $reasons.Add('Observation failure or manual trigger is required.') }

    $package = [PSCustomObject]@{
        RollbackReadinessPackageId = "REV419-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'RollbackExecutionReadinessOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        ObservationScope = 'SingleTargetOnly'
        OriginalDisableEvidencePresent = $originalDisablePresent
        PreActionSnapshotPresent = $preActionSnapshotPresent
        RollbackDrillPackagePresent = $rollbackDrillPackagePresent
        PostDisableObservationPresent = $postDisableObservationPresent
        RollbackTriggerPresent = $rollbackTriggerPresent
        HumanRollbackApprovalRequired = $true
        HumanRollbackApprovalCaptured = $false
        RequiredInputs = [PSCustomObject]@{
            OriginalDisableEvidencePresent = $originalDisablePresent
            PreActionSnapshotPresent = $preActionSnapshotPresent
            PostDisableObservationPresent = $postDisableObservationPresent
            RollbackDrillPackagePresent = $rollbackDrillPackagePresent
            RollbackTriggerPresent = $rollbackTriggerPresent
        }
        GateVerdicts = @()
        RollbackReadiness = if ($reasons.Count -eq 0) { 'Ready' } else { 'NotReady' }
        ReadyForRollbackExecution = $reasons.Count -eq 0
        Blockers = @($reasons)
        Warnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        AllowedNextAction = if ($reasons.Count -eq 0) { 'ControlledDevTestReEnableOnly' } else { $null }
        ProhibitedActions = @('delete', 'remove service principal', 'remove application', 'recreate object', 'grant cleanup', 'credential change', 'metadata cleanup')
        OperatorSignOff = [PSCustomObject]@{
            OperatorName = $null
            OperatorDecision = $null
            OperatorDecisionUtc = $null
            ApproverName = $null
            ApproverDecision = $null
            ApproverDecisionUtc = $null
            Notes = $null
        }
        PreActionSnapshot = [PSCustomObject]@{
            SnapshotId = $snapshotId
            SnapshotPath = $snapshotPath
            CapturedUtc = $capturedUtc
            BaselineHash = $baselineHash
            EvidenceSourcePath = $evidenceSourcePath
        }
        PostDisableObservation = $PostDisableObservation
        RollbackDrillPackage = $RollbackDrillPackage
        RollbackTrigger = @($rollbackTriggerText)
    }

    $gateChecks = [ordered]@{
        ExactlyOneTarget = @($Target).Count -eq 1
        LabOrDevTestTenantOnly = $targetObject -and (
            [string]$environment -in @('Lab', 'DevTest', 'DevTestLab', 'Test') -or
            [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
            [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -in @('Lab', 'DevTest', 'Test') -or
            [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
        )
        OriginalActionWasReversibleDisable = $originalActionWasReversibleDisable
        OriginalDisableEvidencePresent = $originalDisablePresent
        PreActionSnapshotPresent = $preActionSnapshotPresent
        RollbackDrillPackagePresent = $rollbackDrillPackagePresent
        ObservationFailureOrManualTriggerPresent = $observationFailureOrManualTriggerPresent
        RollbackActionIsReEnableOnly = $rollbackActionIsReEnableOnly
        NoDeleteRequested = -not ($requestedOperations -match '(?i)^Delete$|^FinalDelete$')
        NoRemoveRequested = -not ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$')
        NoRecreateRequested = -not ($requestedOperations -match '(?i)^Recreate$')
        NoGrantCleanupRequested = -not ($requestedOperations -match '(?i)^GrantCleanup$')
        NoCredentialChangeRequested = -not ($requestedOperations -match '(?i)^CredentialChange$')
        HumanRollbackApprovalRequired = $true
    }

    foreach ($gateName in $gateChecks.Keys) {
        $passed = [bool]$gateChecks[$gateName]
        $severity = if ($passed) { 'Info' } else { 'High' }
        $reason = switch ($gateName) {
            'ExactlyOneTarget' { if ($passed) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } }
            'LabOrDevTestTenantOnly' { if ($passed) { 'Target is labeled as lab/dev/test.' } else { 'Target is not labeled as lab/dev/test.' } }
            'OriginalActionWasReversibleDisable' { if ($passed) { 'Original action was reversible disable.' } else { 'Original action was not reversible disable.' } }
            'OriginalDisableEvidencePresent' { if ($passed) { 'Original disable evidence is present.' } else { 'Original disable evidence is missing.' } }
            'PreActionSnapshotPresent' { if ($passed) { 'Pre-action snapshot is present.' } else { 'Pre-action snapshot is missing.' } }
            'RollbackDrillPackagePresent' { if ($passed) { 'Rollback drill package is present.' } else { 'Rollback drill package is missing.' } }
            'ObservationFailureOrManualTriggerPresent' { if ($passed) { 'Rollback trigger is present.' } else { 'Observation failure or manual trigger is missing.' } }
            'RollbackActionIsReEnableOnly' { if ($passed) { 'Rollback action is re-enable only.' } else { 'Rollback action is not re-enable only.' } }
            'NoDeleteRequested' { if ($passed) { 'Delete was not requested.' } else { 'Delete was requested.' } }
            'NoRemoveRequested' { if ($passed) { 'Remove was not requested.' } else { 'Remove was requested.' } }
            'NoRecreateRequested' { if ($passed) { 'Recreate was not requested.' } else { 'Recreate was requested.' } }
            'NoGrantCleanupRequested' { if ($passed) { 'Grant cleanup was not requested.' } else { 'Grant cleanup was requested.' } }
            'NoCredentialChangeRequested' { if ($passed) { 'Credential change was not requested.' } else { 'Credential change was requested.' } }
            'HumanRollbackApprovalRequired' { 'Human rollback approval is required.' }
        }
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gateName -Passed $passed -Severity $severity -Reason $reason))
        if (-not $passed) { $reasons.Add("$gateName failed: $reason") }
    }

    $package | Add-Member -NotePropertyName GateVerdicts -NotePropertyValue @($gateVerdicts) -Force
    $package | Add-Member -NotePropertyName HumanDecisionRequired -NotePropertyValue $true -Force

    $artifactPath = Join-Path $OutputPath "Run4C-RollbackReadiness-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiControlledGateVerdict {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$GateName,

        [Parameter(Mandatory)]
        [bool]$Passed,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Severity,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Reason
    )

    [PSCustomObject]@{
        GateName = $GateName
        Passed = $Passed
        Severity = $Severity
        Reason = $Reason
    }
}

function Get-NhiRun4CTargetContext {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $targetObject = $null
    if (@($Target).Count -eq 1) {
        $targetObject = @($Target)[0]
    } else {
        $reasons.Add('Exactly one target is required.')
    }

    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $labMarker = if ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true) { 'LabTarget' } elseif ($targetObject -and [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true) { 'LabTarget' } else { 'LabMarkerMissing' }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = $false
    if ($targetObject) {
        $evidenceOnly = [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'EvidenceOnly'
    }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }
    $microsoftPlatform = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -or [string]$classification -eq 'MicrosoftPlatform' } else { $false }
    $firstPartyMicrosoftApp = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) } else { $false }
    $isLabOrDevTest = $targetObject -and (
        [string]$environment -in @('Lab', 'DevTest', 'DevTestLab', 'Test') -or
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -eq $true -or
        [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('TenantScope')) -in @('Lab', 'DevTest', 'DevTestLab', 'Test') -or
        [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false) -eq $true
    )

    if ($targetObject) {
        if (-not $isLabOrDevTest) { $reasons.Add('Target is not explicitly marked as lab/dev/test.') }
        if ([string]$classification -eq 'MicrosoftPlatform' -or [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('MicrosoftPlatform') -Default $false) -eq $true) { $reasons.Add('MicrosoftPlatform target is blocked.') }
        if ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) -eq $true) { $reasons.Add('First-party Microsoft app target is blocked.') }
        if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
        if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
        if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
        if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }
    }

    [PSCustomObject]@{
        TargetObject = $targetObject
        TargetCount = @($Target).Count
        Blockers = @($reasons)
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        Classification = $classification
        EnvironmentMarker = $environment
        LabTargetMarker = $labMarker
        MicrosoftPlatform = $microsoftPlatform
        FirstPartyMicrosoftApp = $firstPartyMicrosoftApp
        SuppressCustomerRemediation = $suppressCustomerRemediation
        EvidenceOnly = $evidenceOnly
        InformationOnly = $informationOnly
        IsLabOrDevTest = [bool]$isLabOrDevTest
    }
}

function Invoke-NhiControlledLabRollback {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$OriginalDisableEvidence,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$RollbackExecutionReadinessPackage,

        [Parameter()]
        [object]$PostDisableObservation,

        [Parameter()]
        [object]$RollbackTrigger,

        [Parameter()]
        [bool]$HumanRollbackApprovalCaptured = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [bool]$WhatIf = $true
    )

    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $originalDisablePresent = $null -ne $OriginalDisableEvidence
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $rollbackDrillPackagePresent = $null -ne $RollbackDrillPackage
    $rollbackReadinessPackagePresent = $null -ne $RollbackExecutionReadinessPackage
    $rollbackTriggerPresent = $null -ne $RollbackTrigger -and @($RollbackTrigger).Count -gt 0
    $humanApprovalRequired = $true
    $humanApprovalCaptured = [bool]$HumanRollbackApprovalCaptured
    $rollbackReadinessState = [string](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionReadinessPackage -PropertyNames @('RollbackReadiness', 'Readiness', 'Status'))
    $rollbackDrillReady = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('Ready') -Default $false)

    if (-not $originalDisablePresent) { $reasons.Add('Original disable evidence is required.') }
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $rollbackDrillPackagePresent) { $reasons.Add('Rollback drill package is required.') }
    if (-not $rollbackReadinessPackagePresent) { $reasons.Add('Rollback execution readiness package is required.') }
    if (-not $rollbackTriggerPresent) { $reasons.Add('Observation failure or manual rollback trigger is required.') }
    if (-not $humanApprovalCaptured) { $reasons.Add('Human rollback approval is required and not captured.') }
    if ($rollbackDrillPackagePresent -and -not $rollbackDrillReady) { $reasons.Add('Rollback drill package is not ready.') }
    if ($rollbackReadinessPackagePresent -and $rollbackReadinessState -and $rollbackReadinessState -notin @('Ready', 'Complete')) { $reasons.Add('Rollback execution readiness package is not Ready.') }

    $rollbackAction = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    $commandPreview = if ($rollbackAction -eq 'ReEnableServicePrincipal') {
        'Preview only: re-enable the service principal after separate human approval.'
    } else {
        'No executable rollback command emitted.'
    }
    if ($rollbackAction -ne 'ReEnableServicePrincipal') { $reasons.Add('Rollback action must be re-enable only.') }

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    if ($requestedOperations -match '(?i)^Delete$|^FinalDelete$') { $reasons.Add('Delete request is blocked.') }
    if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { $reasons.Add('Remove request is blocked.') }
    if ($requestedOperations -match '(?i)^Recreate$') { $reasons.Add('Recreate request is blocked.') }
    if ($requestedOperations -match '(?i)^GrantCleanup$') { $reasons.Add('Grant cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^MetadataCleanup$') { $reasons.Add('Metadata cleanup request is blocked.') }
    if ($requestedOperations -match '(?i)^CredentialChange$|^CredentialDelete$') { $reasons.Add('Credential change request is blocked.') }
    if ($requestedOperations -match '(?i)^ExecuteNhiDecommission$|^ExecuteNhiControlledDecommission$|^ExecuteNhiControlledGrantCleanup$|^ExecuteNhiControlledMetadataCleanup$') { $reasons.Add('Execution command request is blocked.') }

    $package = [PSCustomObject]@{
        RollbackExecutionPackageId = "REV420-$RunId-$($targetContext.TargetObjectId)"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'ControlledRollbackPreviewOnly'
        TenantWritePerformed = $false
        RollbackPerformed = $false
        DisablePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetContext.TargetDisplayName
        TargetObjectId = $targetContext.TargetObjectId
        TargetAppId = $targetContext.TargetAppId
        TargetType = $targetContext.TargetType
        EnvironmentMarker = $targetContext.EnvironmentMarker
        Classification = $targetContext.Classification
        SuppressCustomerRemediation = $targetContext.SuppressCustomerRemediation
        EvidenceOnly = $targetContext.EvidenceOnly
        RollbackExecutionPackageMetadata = [PSCustomObject]@{
            RollbackExecutionPackageId = "REV420-$RunId-$($targetContext.TargetObjectId)"
            RunId = $RunId
            CreatedUtc = [DateTime]::UtcNow.ToString('o')
            Mode = 'ControlledRollbackPreviewOnly'
            TenantWritePerformed = $false
            RollbackPerformed = $false
            DisablePerformed = $false
            FinalDeleteAllowed = $false
        }
        TargetSummary = [PSCustomObject]@{
            TargetDisplayName = $targetContext.TargetDisplayName
            TargetObjectId = $targetContext.TargetObjectId
            TargetAppId = $targetContext.TargetAppId
            TargetType = $targetContext.TargetType
            Environment = $targetContext.EnvironmentMarker
            Classification = $targetContext.Classification
            SuppressCustomerRemediation = $targetContext.SuppressCustomerRemediation
            EvidenceOnly = $targetContext.EvidenceOnly
        }
        RollbackReadinessSummary = [PSCustomObject]@{
            RollbackReadinessPackagePresent = $rollbackReadinessPackagePresent
            RollbackReadiness = if ($reasons.Count -eq 0 -and ($rollbackReadinessState -in @('', 'Ready', 'Complete'))) { 'Ready' } else { 'NotReady' }
            HumanRollbackApprovalRequired = $humanApprovalRequired
            HumanRollbackApprovalCaptured = $humanApprovalCaptured
            RollbackTriggerPresent = $rollbackTriggerPresent
            OriginalDisableEvidencePresent = $originalDisablePresent
            PreActionSnapshotPresent = $preActionSnapshotPresent
        }
        PlannedRollbackAction = [PSCustomObject]@{
            RollbackAction = 'ReEnableServicePrincipal'
            CommandPreview = $commandPreview
            WhatIf = $WhatIf
            ConfirmRequired = $true
            HumanApprovalRequired = $true
            RollbackExecutionPerformed = $false
        }
        SafetyAssertions = [PSCustomObject]@{
            NoDelete = $true
            NoRemoveServicePrincipal = $true
            NoRemoveApplication = $true
            NoRecreate = $true
            NoGrantCleanup = $true
            NoMetadataCleanup = $true
            NoCredentialChange = $true
            NoFinalDelete = $true
        }
        Evidence = [PSCustomObject]@{
            RollbackEvidencePath = (Join-Path $OutputPath "Run4C-ControlledRollbackPreview-$RunId.json")
            CorrelationId = [guid]::NewGuid().Guid
            SourceDisableEvidencePath = [string](Get-NhiControlledPropertyValue -InputObject $OriginalDisableEvidence -PropertyNames @('OutputArtifactPath', 'EvidencePath'))
            SourceSnapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('SnapshotPath', 'Path', 'OutputArtifactPath'))
            SourceObservationPath = [string](Get-NhiControlledPropertyValue -InputObject $PostDisableObservation -PropertyNames @('OutputArtifactPath', 'ObservationPath', 'Path'))
            CapturedUtc = [DateTime]::UtcNow.ToString('o')
        }
        HumanRollbackApprovalRequired = $humanApprovalRequired
        HumanRollbackApprovalCaptured = $humanApprovalCaptured
        RollbackReadinessPackagePresent = $rollbackReadinessPackagePresent
        RollbackReadiness = if ($reasons.Count -eq 0 -and ($rollbackReadinessState -in @('', 'Ready', 'Complete'))) { 'Ready' } else { 'NotReady' }
        RollbackExecutionPerformed = $false
        Blockers = @($reasons)
        Warnings = @($warnings)
    }

    $gateChecks = [ordered]@{
        ExactlyOneTarget = $targetContext.TargetCount -eq 1
        LabOrDevTestOnly = $targetContext.IsLabOrDevTest
        OriginalDisableEvidencePresent = $originalDisablePresent
        PreActionSnapshotPresent = $preActionSnapshotPresent
        RollbackDrillPackagePresent = $rollbackDrillPackagePresent
        RollbackExecutionReadinessPackagePresent = $rollbackReadinessPackagePresent
        RollbackTriggerPresent = $rollbackTriggerPresent
        RollbackActionIsReEnableOnly = $rollbackAction -eq 'ReEnableServicePrincipal'
        HumanRollbackApprovalRequired = $humanApprovalRequired
        HumanRollbackApprovalCaptured = $humanApprovalCaptured
        NoDeleteRequested = -not ($requestedOperations -match '(?i)^Delete$|^FinalDelete$')
        NoRemoveRequested = -not ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$')
        NoRecreateRequested = -not ($requestedOperations -match '(?i)^Recreate$')
        NoGrantCleanupRequested = -not ($requestedOperations -match '(?i)^GrantCleanup$')
        NoMetadataCleanupRequested = -not ($requestedOperations -match '(?i)^MetadataCleanup$')
        NoCredentialChangeRequested = -not ($requestedOperations -match '(?i)^CredentialChange$|^CredentialDelete$')
        NoExecutionCommandRequested = -not ($requestedOperations -match '(?i)^ExecuteNhiDecommission$|^ExecuteNhiControlledDecommission$|^ExecuteNhiControlledGrantCleanup$|^ExecuteNhiControlledMetadataCleanup$')
    }

    foreach ($gateName in $gateChecks.Keys) {
        $passed = [bool]$gateChecks[$gateName]
        $severity = if ($passed) { 'Info' } else { 'High' }
        $reason = switch ($gateName) {
            'ExactlyOneTarget' { if ($passed) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } }
            'LabOrDevTestOnly' { if ($passed) { 'Target is labeled as lab/dev/test.' } else { 'Target is not labeled as lab/dev/test.' } }
            'OriginalDisableEvidencePresent' { if ($passed) { 'Original disable evidence is present.' } else { 'Original disable evidence is missing.' } }
            'PreActionSnapshotPresent' { if ($passed) { 'Pre-action snapshot is present.' } else { 'Pre-action snapshot is missing.' } }
            'RollbackDrillPackagePresent' { if ($passed) { 'Rollback drill package is present.' } else { 'Rollback drill package is missing.' } }
            'RollbackExecutionReadinessPackagePresent' { if ($passed) { 'Rollback execution readiness package is present.' } else { 'Rollback execution readiness package is missing.' } }
            'RollbackTriggerPresent' { if ($passed) { 'Rollback trigger is present.' } else { 'Rollback trigger is missing.' } }
            'RollbackActionIsReEnableOnly' { if ($passed) { 'Rollback action is re-enable only.' } else { 'Rollback action is not re-enable only.' } }
            'HumanRollbackApprovalRequired' { 'Human rollback approval is required.' }
            'HumanRollbackApprovalCaptured' { if ($passed) { 'Human rollback approval was captured.' } else { 'Human rollback approval is not captured.' } }
            'NoDeleteRequested' { if ($passed) { 'Delete was not requested.' } else { 'Delete was requested.' } }
            'NoRemoveRequested' { if ($passed) { 'Remove was not requested.' } else { 'Remove was requested.' } }
            'NoRecreateRequested' { if ($passed) { 'Recreate was not requested.' } else { 'Recreate was requested.' } }
            'NoGrantCleanupRequested' { if ($passed) { 'Grant cleanup was not requested.' } else { 'Grant cleanup was requested.' } }
            'NoMetadataCleanupRequested' { if ($passed) { 'Metadata cleanup was not requested.' } else { 'Metadata cleanup was requested.' } }
            'NoCredentialChangeRequested' { if ($passed) { 'Credential change was not requested.' } else { 'Credential change was requested.' } }
            'NoExecutionCommandRequested' { if ($passed) { 'No execution command was requested.' } else { 'Execution command was requested.' } }
        }
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gateName -Passed $passed -Severity $severity -Reason $reason))
    }

    $package | Add-Member -NotePropertyName GateVerdicts -NotePropertyValue @($gateVerdicts) -Force
    $package | Add-Member -NotePropertyName HumanApprovalRequired -NotePropertyValue $humanApprovalRequired -Force
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path (Join-Path $OutputPath "Run4C-ControlledRollbackPreview-$RunId.json")) -Force
    return $package
}

function New-NhiFinalDeleteEligibilitySimulationPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$PriorDisableEvidence,

        [Parameter()]
        [object]$PostDisableObservation,

        [Parameter()]
        [bool]$BusinessOwnerFinalApprovalPresent = $false,

        [Parameter()]
        [bool]$SecurityApprovalPresent = $false,

        [Parameter()]
        [bool]$RetentionWindowSatisfied = $false,

        [Parameter()]
        [bool]$DependencyCheckPassed = $false,

        [Parameter()]
        [Nullable[bool]]$NoActiveSignInsObserved,

        [Parameter()]
        [Nullable[bool]]$NoActiveGrantsRemaining,

        [Parameter()]
        [Nullable[bool]]$NoCredentialRiskRemaining,

        [Parameter()]
        [bool]$FinalDeleteSeparateApprovalRequired = $true,

        [Parameter()]
        [bool]$HumanDecisionCaptured = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $priorDisableEvidencePresent = $null -ne $PriorDisableEvidence
    $postDisableObservationCompleted = $null -ne $PostDisableObservation
    $noActiveSignIns = if ($PSBoundParameters.ContainsKey('NoActiveSignInsObserved')) { [bool]$NoActiveSignInsObserved } else { $false }
    $noActiveGrants = if ($PSBoundParameters.ContainsKey('NoActiveGrantsRemaining')) { [bool]$NoActiveGrantsRemaining } else { $false }
    $noCredentialRisk = if ($PSBoundParameters.ContainsKey('NoCredentialRiskRemaining')) { [bool]$NoCredentialRiskRemaining } else { $false }
    $firstPartyMicrosoftApp = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) } else { $false }
    $actualDeleteRequested = $requestedOperations -match '(?i)^Delete$|^FinalDelete$'
    $removeRequested = $requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$'
    $grantCleanupRequested = $requestedOperations -match '(?i)^GrantCleanup$'
    $metadataCleanupRequested = $requestedOperations -match '(?i)^MetadataCleanup$'
    $credentialDeletionRequested = $requestedOperations -match '(?i)^CredentialDelete$|^CredentialChange$'
    $recreateRequested = $requestedOperations -match '(?i)^Recreate$'

    if (-not $priorDisableEvidencePresent) { $reasons.Add('Prior reversible disable evidence is required.') }
    if (-not $postDisableObservationCompleted) { $reasons.Add('Post-disable observation completion is required.') }
    if (-not $BusinessOwnerFinalApprovalPresent) { $reasons.Add('Business owner final approval is required.') }
    if (-not $SecurityApprovalPresent) { $reasons.Add('Security approval is required.') }
    if (-not $RetentionWindowSatisfied) { $reasons.Add('Retention window must be satisfied.') }
    if (-not $DependencyCheckPassed) { $reasons.Add('Dependency check must pass.') }
    if ($firstPartyMicrosoftApp) { $reasons.Add('First-party Microsoft app target is blocked.') }
    if (-not $noActiveSignIns) { $reasons.Add('No active sign-ins must be observed.') }
    if (-not $noActiveGrants) { $reasons.Add('No active grants remaining must be confirmed.') }
    if (-not $noCredentialRisk) { $reasons.Add('No credential risk remaining must be confirmed.') }
    if ($actualDeleteRequested) { $reasons.Add('Actual delete request is blocked.') }
    if ($removeRequested) { $reasons.Add('Remove request is blocked.') }
    if ($grantCleanupRequested) { $reasons.Add('Grant cleanup request is blocked.') }
    if ($metadataCleanupRequested) { $reasons.Add('Metadata cleanup request is blocked.') }
    if ($credentialDeletionRequested) { $reasons.Add('Credential deletion request is blocked.') }
    if ($recreateRequested) { $reasons.Add('Recreate request is blocked.') }

    $package = [PSCustomObject]@{
        SimulationPackageId = "REV421-$RunId-$($targetContext.TargetObjectId)"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'FinalDeleteEligibilitySimulationOnly'
        TenantWritePerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        ExecutionCommandEmitted = $false
        TargetDisplayName = $targetContext.TargetDisplayName
        TargetObjectId = $targetContext.TargetObjectId
        TargetAppId = $targetContext.TargetAppId
        TargetType = $targetContext.TargetType
        Classification = $targetContext.Classification
        EnvironmentMarker = $targetContext.EnvironmentMarker
        SuppressCustomerRemediation = $targetContext.SuppressCustomerRemediation
        EvidenceOnly = $targetContext.EvidenceOnly
        InformationOnly = $targetContext.InformationOnly
        SimulatedOnly = $true
        ReadyForActualDelete = $false
        RequiredSeparateApproval = $true
        HumanDecisionCaptured = [bool]$HumanDecisionCaptured
        CommandPreview = 'No executable final-delete command emitted; simulation only.'
        ProhibitedActions = @('actual final delete', 'remove service principal', 'remove application', 'grant cleanup', 'metadata cleanup', 'credential deletion')
        EligibilityGates = @()
        FinalDeleteEligibility = if ($reasons.Count -eq 0) { 'Eligible' } else { 'NotEligible' }
        Blockers = @($reasons)
        Warnings = @($warnings)
        Explanation = [PSCustomObject]@{
            WhyFinalDeleteIsNotExecuted = 'This package is simulation only and never executes live mutation.'
            FutureEvidenceRequired = @('separate approval', 'completed observation', 'retention window', 'dependency clearance')
            WhySeparateMilestone = 'Final delete must remain a separate approval milestone from reversible disable.'
            WhySimulationIsSafer = 'Simulation proves the decision gates without producing live tenant changes.'
        }
        Evidence = [PSCustomObject]@{
            SimulationEvidencePath = (Join-Path $OutputPath "Run4C-FinalDeleteEligibilitySimulation-$RunId.json")
            CorrelationId = [guid]::NewGuid().Guid
            SourceDisableEvidencePath = [string](Get-NhiControlledPropertyValue -InputObject $PriorDisableEvidence -PropertyNames @('OutputArtifactPath', 'EvidencePath'))
            SourceSnapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $PriorDisableEvidence -PropertyNames @('SnapshotPath', 'PreActionSnapshotPath', 'OutputArtifactPath'))
            SourceObservationPath = [string](Get-NhiControlledPropertyValue -InputObject $PostDisableObservation -PropertyNames @('OutputArtifactPath', 'ObservationPath', 'Path'))
            CapturedUtc = [DateTime]::UtcNow.ToString('o')
        }
    }

    $gateDefinitions = @(
        @{ GateName = 'ExactlyOneTarget'; Passed = ($targetContext.TargetCount -eq 1); Reason = if ($targetContext.TargetCount -eq 1) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } },
        @{ GateName = 'LabOrDevTestOnly'; Passed = $targetContext.IsLabOrDevTest; Reason = if ($targetContext.IsLabOrDevTest) { 'Target is labeled as lab/dev/test.' } else { 'Target is not labeled as lab/dev/test.' } },
        @{ GateName = 'NotMicrosoftPlatform'; Passed = -not $targetContext.MicrosoftPlatform; Reason = if ($targetContext.MicrosoftPlatform) { 'MicrosoftPlatform target is blocked.' } else { 'Target is not MicrosoftPlatform.' } },
        @{ GateName = 'NotFirstPartyMicrosoftApp'; Passed = -not $targetContext.FirstPartyMicrosoftApp; Reason = if ($targetContext.FirstPartyMicrosoftApp) { 'First-party Microsoft app target is blocked.' } else { 'Target is not a first-party Microsoft app.' } },
        @{ GateName = 'NotExternalVendorPlatform'; Passed = -not ($targetContext.Classification -eq 'ExternalVendorPlatform'); Reason = if ($targetContext.Classification -eq 'ExternalVendorPlatform') { 'ExternalVendorPlatform target is blocked.' } else { 'Target is not ExternalVendorPlatform.' } },
        @{ GateName = 'NotSuppressed'; Passed = -not $targetContext.SuppressCustomerRemediation; Reason = if ($targetContext.SuppressCustomerRemediation) { 'SuppressCustomerRemediation target is blocked.' } else { 'Target is not suppressed.' } },
        @{ GateName = 'NotEvidenceOnly'; Passed = -not $targetContext.EvidenceOnly; Reason = if ($targetContext.EvidenceOnly) { 'EvidenceOnly target is blocked.' } else { 'Target is not evidence-only.' } },
        @{ GateName = 'PriorReversibleDisableEvidencePresent'; Passed = $priorDisableEvidencePresent; Reason = if ($priorDisableEvidencePresent) { 'Prior disable evidence is present.' } else { 'Prior disable evidence is missing.' } },
        @{ GateName = 'PostDisableObservationCompleted'; Passed = $postDisableObservationCompleted; Reason = if ($postDisableObservationCompleted) { 'Post-disable observation is complete.' } else { 'Post-disable observation is missing.' } },
        @{ GateName = 'NoRollbackNeededOrRollbackWindowExpired'; Passed = $RetentionWindowSatisfied; Reason = if ($RetentionWindowSatisfied) { 'Rollback window has expired or is not needed.' } else { 'Rollback window is still open or not proven.' } },
        @{ GateName = 'BusinessOwnerFinalApprovalPresent'; Passed = $BusinessOwnerFinalApprovalPresent; Reason = if ($BusinessOwnerFinalApprovalPresent) { 'Business owner final approval is present.' } else { 'Business owner final approval is missing.' } },
        @{ GateName = 'SecurityApprovalPresent'; Passed = $SecurityApprovalPresent; Reason = if ($SecurityApprovalPresent) { 'Security approval is present.' } else { 'Security approval is missing.' } },
        @{ GateName = 'RetentionWindowSatisfied'; Passed = $RetentionWindowSatisfied; Reason = if ($RetentionWindowSatisfied) { 'Retention window is satisfied.' } else { 'Retention window is not satisfied.' } },
        @{ GateName = 'DependencyCheckPassed'; Passed = $DependencyCheckPassed; Reason = if ($DependencyCheckPassed) { 'Dependency check passed.' } else { 'Dependency check failed.' } },
        @{ GateName = 'NoActiveSignInsObserved'; Passed = $noActiveSignIns; Reason = if ($noActiveSignIns) { 'No active sign-ins were observed.' } else { 'Active sign-ins remain or were not proven absent.' } },
        @{ GateName = 'NoActiveGrantsRemaining'; Passed = $noActiveGrants; Reason = if ($noActiveGrants) { 'No active grants remain.' } else { 'Active grants remain or were not proven absent.' } },
        @{ GateName = 'NoCredentialRiskRemaining'; Passed = $noCredentialRisk; Reason = if ($noCredentialRisk) { 'No credential risk remains.' } else { 'Credential risk remains or was not proven absent.' } },
        @{ GateName = 'FinalDeleteSeparateApprovalRequired'; Passed = $FinalDeleteSeparateApprovalRequired; Reason = 'Final delete requires a separate approval milestone.' }
    )

    foreach ($gate in $gateDefinitions) {
        $passed = [bool]$gate.Passed
        $severity = if ($passed) { 'Info' } else { 'High' }
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gate.GateName -Passed $passed -Severity $severity -Reason $gate.Reason))
    }

    $package | Add-Member -NotePropertyName EligibilityGates -NotePropertyValue @($gateVerdicts) -Force
    $artifactPath = Join-Path $OutputPath "Run4C-FinalDeleteEligibilitySimulation-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CEndToEndLabRehearsalReport {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$ApprovalManifest,

        [Parameter()]
        [object]$Snapshot,

        [Parameter()]
        [object]$ReadinessVerdict,

        [Parameter()]
        [object]$DryRunPackage,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$ControlledDisablePackage,

        [Parameter()]
        [object]$FinalGoNoGoPackage,

        [Parameter()]
        [object]$EvidenceCapturePackage,

        [Parameter()]
        [object]$ObservationPackage,

        [Parameter()]
        [object]$RollbackReadinessPackage,

        [Parameter()]
        [object]$RollbackPreviewPackage,

        [Parameter()]
        [object]$FinalDeleteSimulationPackage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string]$MarkdownOutputPath
    )

    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()

    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $chainItems = @(
        [PSCustomObject]@{ Revision = 'Rev4.11'; Label = 'approved reversible planning proof'; Package = $ApprovalManifest; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('OutputArtifactPath', 'ApprovalManifestPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.12'; Label = 'readiness gate'; Package = $ReadinessVerdict; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.13'; Label = 'dry-run package'; Package = $DryRunPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.14'; Label = 'rollback drill package'; Package = $RollbackDrillPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.15'; Label = 'controlled disable path'; Package = $ControlledDisablePackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $ControlledDisablePackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.16'; Label = 'final go/no-go package'; Package = $FinalGoNoGoPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $FinalGoNoGoPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.17'; Label = 'evidence capture package'; Package = $EvidenceCapturePackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $EvidenceCapturePackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.18'; Label = 'observation package'; Package = $ObservationPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $ObservationPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.19'; Label = 'rollback readiness package'; Package = $RollbackReadinessPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadinessPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.20'; Label = 'rollback preview path'; Package = $RollbackPreviewPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPreviewPackage -PropertyNames @('OutputArtifactPath')); Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.21'; Label = 'final delete simulation'; Package = $FinalDeleteSimulationPackage; ArtifactPath = [string](Get-NhiControlledPropertyValue -InputObject $FinalDeleteSimulationPackage -PropertyNames @('OutputArtifactPath')); Required = $true }
    )

    $chainSummary = foreach ($item in $chainItems) {
        $present = $null -ne $item.Package
        $status = if (-not $present) {
            'Missing'
        } elseif ($item.Package.PSObject.Properties['GoNoGo']) {
            [string]$item.Package.GoNoGo
        } elseif ($item.Package.PSObject.Properties['Readiness']) {
            [string]$item.Package.Readiness
        } elseif ($item.Package.PSObject.Properties['RollbackReadiness']) {
            [string]$item.Package.RollbackReadiness
        } elseif ($item.Package.PSObject.Properties['FinalDeleteEligibility']) {
            [string]$item.Package.FinalDeleteEligibility
        } elseif ($item.Package.PSObject.Properties['Ready']) {
            if ($item.Package.Ready -eq $true) { 'Complete' } else { 'Incomplete' }
        } else {
            'Present'
        }

        if (-not $present -and $item.Required) { $reasons.Add("$($item.Revision) package is missing.") }
        [PSCustomObject]@{
            Revision = $item.Revision
            Label = $item.Label
            Present = $present
            Status = $status
            ArtifactPath = $item.ArtifactPath
        }
    }

    $requiredArtifacts = @(
        'Approval manifest',
        'Snapshot',
        'Readiness verdict',
        'Dry-run package',
        'Rollback drill package',
        'Go/No-Go package',
        'Evidence capture package',
        'Observation package',
        'Rollback readiness package',
        'Rollback preview package',
        'Final delete simulation package'
    )

    $artifactIndex = [PSCustomObject]@{
        ApprovalManifestPath = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('OutputArtifactPath', 'ApprovalManifestPath'))
        SnapshotPath = [string](Get-NhiControlledPropertyValue -InputObject $Snapshot -PropertyNames @('OutputArtifactPath', 'SnapshotPath', 'Path'))
        ReadinessVerdictPath = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('OutputArtifactPath'))
        DryRunPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $DryRunPackage -PropertyNames @('OutputArtifactPath'))
        RollbackDrillPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('OutputArtifactPath'))
        GoNoGoPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $FinalGoNoGoPackage -PropertyNames @('OutputArtifactPath'))
        EvidenceCapturePackagePath = [string](Get-NhiControlledPropertyValue -InputObject $EvidenceCapturePackage -PropertyNames @('OutputArtifactPath'))
        ObservationPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $ObservationPackage -PropertyNames @('OutputArtifactPath'))
        RollbackReadinessPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadinessPackage -PropertyNames @('OutputArtifactPath'))
        RollbackPreviewPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPreviewPackage -PropertyNames @('OutputArtifactPath'))
        FinalDeleteSimulationPackagePath = [string](Get-NhiControlledPropertyValue -InputObject $FinalDeleteSimulationPackage -PropertyNames @('OutputArtifactPath'))
    }

    $passedCount = @($chainSummary | Where-Object { $_.Status -in @('Go', 'Ready', 'Complete', 'Eligible') }).Count
    $failedCount = @($chainSummary | Where-Object { $_.Status -in @('NoGo', 'NotReady', 'Incomplete', 'NotEligible', 'Missing') }).Count
    $pendingCount = [math]::Max(0, @($chainSummary).Count - $passedCount - $failedCount)
    $complete = $reasons.Count -eq 0
    $rehearsalStatus = if ($complete) { 'Complete' } else { 'Incomplete' }

    $package = [PSCustomObject]@{
        ReportId = "REV422-$RunId-$($targetContext.TargetObjectId)"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'EndToEndLabRehearsalOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetContext.TargetDisplayName
        TargetObjectId = $targetContext.TargetObjectId
        TargetAppId = $targetContext.TargetAppId
        TargetType = $targetContext.TargetType
        EnvironmentMarker = $targetContext.EnvironmentMarker
        Classification = $targetContext.Classification
        SuppressCustomerRemediation = $targetContext.SuppressCustomerRemediation
        EvidenceOnly = $targetContext.EvidenceOnly
        ChainSummary = @($chainSummary)
        RehearsalStatus = $rehearsalStatus
        ReadyForFinalControlledDevTestDisable = $complete
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        SafetyAssertions = [PSCustomObject]@{
            NoProductionTenantWrite = $true
            NoLiveTenantWriteByRehearsal = $true
            NoActualDisable = $true
            NoActualRollback = $true
            NoActualDelete = $true
            NoFinalDelete = $true
            NoGrantCleanup = $true
            NoCredentialDeletion = $true
        }
        OperatorChecklistSummary = [PSCustomObject]@{
            ChecklistItems = $requiredArtifacts
            PassedCount = $passedCount
            FailedCount = $failedCount
            PendingCount = $pendingCount
        }
        ArtifactIndex = $artifactIndex
    }

    $artifactPath = Join-Path $OutputPath "Run4C-EndToEndLabRehearsal-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force

    if ($MarkdownOutputPath) {
        $markdownLines = @(
            '# End-to-End Lab Rehearsal Report',
            '',
            "- ReportId: $($package.ReportId)",
            "- RunId: $RunId",
            "- RehearsalStatus: $rehearsalStatus",
            "- ReadyForFinalControlledDevTestDisable: $complete",
            '',
            '## Chain Summary'
        )
        foreach ($item in $chainSummary) {
            $markdownLines += "- $($item.Revision) $($item.Label): $($item.Status)"
        }
        [System.IO.File]::WriteAllText($MarkdownOutputPath, ($markdownLines -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
        $package | Add-Member -NotePropertyName MarkdownArtifactPath -NotePropertyValue $MarkdownOutputPath -Force
    }

    return $package
}

function New-NhiRun4CConsultantOperatingGuide {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string]$JsonIndexPath,

        [Parameter()]
        [string]$RunId = 'REV423-GUIDE'
    )

    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    $title = 'Run #4C Controlled Lab NHI Reversible Disable Operating Guide'
    $markdown = @(
        "# $title",
        '',
        '## Executive Summary',
        'This workflow is designed to reduce decommissioning risk by using a reversible-first, evidence-driven lab process.',
        'No final delete is part of Run #4C.',
        'Production use requires separate approval.',
        '',
        '## Scope',
        '- Dev/test tenant only.',
        '- Exactly one approved lab NHI.',
        '- Reversible disable only.',
        '- No delete.',
        '- No grant cleanup.',
        '- No credential deletion.',
        '- No metadata cleanup.',
        '',
        '## Roles and Responsibilities',
        '- Operator',
        '- Approver',
        '- Monitoring owner',
        '- Rollback contact',
        '- Business owner',
        '- Security reviewer',
        '',
        '## Required Artifacts',
        '- Approval manifest',
        '- Pre-action snapshot',
        '- Readiness verdict',
        '- Dry-run package',
        '- Rollback drill package',
        '- Final Go/No-Go package',
        '- Evidence capture package',
        '- Observation package',
        '- Rollback readiness package',
        '- Rollback preview package',
        '- Final delete simulation package',
        '- End-to-end rehearsal report',
        '',
        '## Runbook Phases',
        '- Phase 1: Target selection',
        '- Phase 2: Approval',
        '- Phase 3: Snapshot',
        '- Phase 4: Readiness',
        '- Phase 5: Dry-run',
        '- Phase 6: Rollback drill',
        '- Phase 7: Go/No-Go',
        '- Phase 8: Controlled reversible disable',
        '- Phase 9: Observation',
        '- Phase 10: Rollback readiness if needed',
        '- Phase 11: Rollback only if separately approved',
        '- Phase 12: Final delete simulation only',
        '',
        '## Safety Boundaries',
        '- No production tenant write in lab workflow.',
        '- No final delete.',
        '- No service principal removal.',
        '- No application removal.',
        '- No grant cleanup.',
        '- No credential deletion.',
        '- No rollback without separate approval.',
        '- Microsoft/platform identities are evidence-only.',
        '- Suppressed identities are not customer-actionable.',
        '',
        '## Client-Safe Narrative',
        'This guide is consultant-ready because it uses a clear approval chain, traceable evidence, a reversible-first control model, an operator checklist, explicit rollback readiness, separate delete handling, and client-safe artifacts.',
        '',
        '## Final Operator Warning',
        'Do not run live commands without final human go/no-go and a verified lab target.',
        '',
        '## Target Context',
        "- TargetDisplayName: $($targetContext.TargetDisplayName)",
        "- TargetObjectId: $($targetContext.TargetObjectId)",
        "- TargetAppId: $($targetContext.TargetAppId)",
        "- TargetType: $($targetContext.TargetType)",
        "- Environment: $($targetContext.EnvironmentMarker)",
        "- Classification: $($targetContext.Classification)"
    )

    $guidePath = Join-Path $OutputPath "Run4C-ConsultantOperatingGuide-$RunId.md"
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $guidePath) -Force
    [System.IO.File]::WriteAllText($guidePath, ($markdown -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))

    $package = [PSCustomObject]@{
        GuideId = "REV423-$RunId-$($targetContext.TargetObjectId)"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'ConsultantReadyOperatingGuideOnly'
        Title = $title
        TargetDisplayName = $targetContext.TargetDisplayName
        TargetObjectId = $targetContext.TargetObjectId
        TargetAppId = $targetContext.TargetAppId
        TargetType = $targetContext.TargetType
        EnvironmentMarker = $targetContext.EnvironmentMarker
        Classification = $targetContext.Classification
        OutputArtifactPath = $guidePath
        ContainsExecutableDeleteCommand = $false
        ContainsExecutableFinalDeleteCommand = $false
    }

    if ($JsonIndexPath) {
        Export-NhiControlledDecommissionEvidence -Evidence $package -Path $JsonIndexPath | Out-Null
        $package | Add-Member -NotePropertyName JsonIndexPath -NotePropertyValue $JsonIndexPath -Force
    }

    return $package
}

function Get-NhiRun4CArtifactRecord {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$InputObject,

        [Parameter()]
        [string[]]$PropertyNames = @(),

        [Parameter()]
        [string]$FallbackPath,

        [Parameter()]
        [string]$FallbackId
    )

    $path = [string](Get-NhiControlledPropertyValue -InputObject $InputObject -PropertyNames (@('OutputArtifactPath') + @($PropertyNames)))
    $id = [string](Get-NhiControlledPropertyValue -InputObject $InputObject -PropertyNames @('Id', 'PackageId', 'ReportId', 'ReviewPackageId', 'GuideId', 'SimulationPackageId', 'ObservationPackageId', 'RollbackReadinessPackageId', 'FinalDeleteEligibilityPackageId', 'FinalTestPackageId'))
    if ([string]::IsNullOrWhiteSpace($path)) { $path = [string]$FallbackPath }
    if ([string]::IsNullOrWhiteSpace($id)) { $id = [string]$FallbackId }

    [PSCustomObject]@{
        Present = $null -ne $InputObject
        Path = $path
        Id = $id
    }
}

function New-NhiRun4CFinalControlledDisableTestPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$ApprovalManifest,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$ReadinessVerdict,

        [Parameter()]
        [object]$DryRunPackage,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$ControlledDisablePreview,

        [Parameter()]
        [object]$FinalGoNoGoReviewPackage,

        [Parameter()]
        [object]$EvidenceCapturePackage,

        [Parameter()]
        [object]$ObservationPackage,

        [Parameter()]
        [object]$RollbackReadinessPackage,

        [Parameter()]
        [object]$RollbackPreviewPackage,

        [Parameter()]
        [object]$FinalDeleteSimulationPackage,

        [Parameter()]
        [object]$EndToEndRehearsalReport,

        [Parameter()]
        [object]$ConsultantOperatingGuide,

        [Parameter()]
        [bool]$HumanGoNoGoCaptured = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @('ReversibleDisable'),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target

    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $firstPartyMicrosoftApp = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('FirstPartyMicrosoftApp', 'MicrosoftFirstParty') -Default $false) } else { $false }
    $suppressCustomerRemediation = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('SuppressCustomerRemediation') -Default $false) } else { $false }
    $evidenceOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('EvidenceOnly') -Default $false) } else { $false }
    $informationOnly = if ($targetObject) { [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('InformationOnly') -Default $false) -or [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('RemediationMode')) -eq 'InformationOnly' } else { $false }
    $labMarker = if ($targetObject -and ([bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('IsLabTarget') -Default $false) -or [bool](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('LabTargetMarker') -Default $false))) { 'LabTarget' } else { 'LabMarkerMissing' }
    $approvalManifestPresent = $null -ne $ApprovalManifest
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $readinessVerdictPresent = $null -ne $ReadinessVerdict
    $dryRunPackagePresent = $null -ne $DryRunPackage
    $rollbackDrillPackagePresent = $null -ne $RollbackDrillPackage
    $controlledDisablePreviewPresent = $null -ne $ControlledDisablePreview
    $finalGoNoGoReviewPackagePresent = $null -ne $FinalGoNoGoReviewPackage
    $evidenceCapturePackagePresent = $null -ne $EvidenceCapturePackage
    $observationPackagePresent = $null -ne $ObservationPackage
    $rollbackReadinessPackagePresent = $null -ne $RollbackReadinessPackage
    $rollbackPreviewPackagePresent = $null -ne $RollbackPreviewPackage
    $finalDeleteSimulationPackagePresent = $null -ne $FinalDeleteSimulationPackage
    $endToEndRehearsalReportPresent = $null -ne $EndToEndRehearsalReport
    $consultantOperatingGuidePresent = $null -ne $ConsultantOperatingGuide

    $approvalAction = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovedAction', 'ActionType', 'RequestedAction'))
    $approvalExpiresUtc = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('ApprovalExpiresUtc', 'ExpiresUtc'))
    $approvalTargetId = [string](Get-NhiControlledPropertyValue -InputObject $ApprovalManifest -PropertyNames @('TargetObjectId'))
    $approvalNotExpired = $false
    if ($approvalExpiresUtc) {
        try { $approvalNotExpired = [DateTime]::Parse($approvalExpiresUtc).ToUniversalTime() -gt [DateTime]::UtcNow } catch { $approvalNotExpired = $false }
    }

    $readinessReady = [bool](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('Ready') -Default $false)
    if (-not $readinessReady) {
        $readinessState = [string](Get-NhiControlledPropertyValue -InputObject $ReadinessVerdict -PropertyNames @('Readiness', 'Status'))
        $readinessReady = $readinessState -in @('Ready', 'Complete')
    }

    $targetIsDisposableOrLabApproved = ($targetContext.IsLabOrDevTest) -and (-not $targetContext.Blockers)
    if ($approvalTargetId -and $targetObjectId -and $approvalTargetId -ne $targetObjectId) { $targetIsDisposableOrLabApproved = $false }
    if (-not $approvalManifestPresent) { $reasons.Add('Approval manifest is required.') }
    if (-not $approvalNotExpired) { $reasons.Add('Approval manifest is missing or expired.') }
    if ($approvalAction -ne 'ReversibleDisable') { $reasons.Add('Approved action is not ReversibleDisable.') }
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $readinessVerdictPresent -or -not $readinessReady) { $reasons.Add('Readiness verdict is required and must be ready.') }
    if (-not $dryRunPackagePresent) { $reasons.Add('Dry-run package is required.') }
    if (-not $rollbackDrillPackagePresent) { $reasons.Add('Rollback drill package is required.') }
    if (-not $controlledDisablePreviewPresent) { $reasons.Add('Controlled disable preview is required.') }
    if (-not $finalGoNoGoReviewPackagePresent) { $reasons.Add('Final go/no-go review package is required.') }
    if (-not $evidenceCapturePackagePresent) { $reasons.Add('Evidence capture package is required.') }
    if (-not $observationPackagePresent) { $reasons.Add('Observation package is required.') }
    if (-not $rollbackReadinessPackagePresent) { $reasons.Add('Rollback readiness package is required.') }
    if (-not $rollbackPreviewPackagePresent) { $reasons.Add('Rollback preview package is required.') }
    if (-not $endToEndRehearsalReportPresent) { $reasons.Add('End-to-end rehearsal report is required.') }
    if (-not $consultantOperatingGuidePresent) { $reasons.Add('Consultant operating guide is required.') }
    if (-not $targetIsDisposableOrLabApproved) { $reasons.Add('Target is not a disposable or lab-approved target.') }
    if ($firstPartyMicrosoftApp) { $reasons.Add('First-party Microsoft app target is blocked.') }
    if ([string]$classification -eq 'MicrosoftPlatform') { $reasons.Add('MicrosoftPlatform target is blocked.') }
    if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }
    if ($suppressCustomerRemediation) { $reasons.Add('SuppressCustomerRemediation target is blocked.') }
    if ($evidenceOnly) { $reasons.Add('EvidenceOnly target is blocked.') }
    if ($informationOnly) { $reasons.Add('InformationOnly target is blocked.') }
    if (@($Target).Count -ne 1) { $reasons.Add('Exactly one target is required.') }

    $artifactIndex = [PSCustomObject]@{
        ApprovalManifest = Get-NhiRun4CArtifactRecord -InputObject $ApprovalManifest -PropertyNames @('ApprovalManifestPath') -FallbackId 'ApprovalManifest'
        PreActionSnapshot = Get-NhiRun4CArtifactRecord -InputObject $PreActionSnapshot -PropertyNames @('SnapshotPath', 'Path') -FallbackId 'PreActionSnapshot'
        ReadinessVerdict = Get-NhiRun4CArtifactRecord -InputObject $ReadinessVerdict -PropertyNames @('ReadinessVerdictPath', 'OutputArtifactPath') -FallbackId 'ReadinessVerdict'
        DryRunPackage = Get-NhiRun4CArtifactRecord -InputObject $DryRunPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'DryRunPackage'
        RollbackDrillPackage = Get-NhiRun4CArtifactRecord -InputObject $RollbackDrillPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'RollbackDrillPackage'
        ControlledDisablePreview = Get-NhiRun4CArtifactRecord -InputObject $ControlledDisablePreview -PropertyNames @('OutputArtifactPath') -FallbackId 'ControlledDisablePreview'
        FinalGoNoGoReviewPackage = Get-NhiRun4CArtifactRecord -InputObject $FinalGoNoGoReviewPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'FinalGoNoGoReviewPackage'
        EvidenceCapturePackage = Get-NhiRun4CArtifactRecord -InputObject $EvidenceCapturePackage -PropertyNames @('OutputArtifactPath') -FallbackId 'EvidenceCapturePackage'
        ObservationPackage = Get-NhiRun4CArtifactRecord -InputObject $ObservationPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'ObservationPackage'
        RollbackReadinessPackage = Get-NhiRun4CArtifactRecord -InputObject $RollbackReadinessPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'RollbackReadinessPackage'
        RollbackPreviewPackage = Get-NhiRun4CArtifactRecord -InputObject $RollbackPreviewPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'RollbackPreviewPackage'
        FinalDeleteSimulationPackage = Get-NhiRun4CArtifactRecord -InputObject $FinalDeleteSimulationPackage -PropertyNames @('OutputArtifactPath') -FallbackId 'FinalDeleteSimulationPackage'
        EndToEndRehearsalReport = Get-NhiRun4CArtifactRecord -InputObject $EndToEndRehearsalReport -PropertyNames @('OutputArtifactPath') -FallbackId 'EndToEndRehearsalReport'
        ConsultantOperatingGuide = Get-NhiRun4CArtifactRecord -InputObject $ConsultantOperatingGuide -PropertyNames @('OutputArtifactPath') -FallbackId 'ConsultantOperatingGuide'
    }

    $requiredArtifacts = @(
        'ApprovalManifest',
        'PreActionSnapshot',
        'ReadinessVerdict',
        'DryRunPackage',
        'RollbackDrillPackage',
        'ControlledDisablePreview',
        'FinalGoNoGoReviewPackage',
        'EvidenceCapturePackage',
        'ObservationPackage',
        'RollbackReadinessPackage',
        'RollbackPreviewPackage',
        'FinalDeleteSimulationPackage',
        'EndToEndRehearsalReport',
        'ConsultantOperatingGuide'
    )

    foreach ($artifactName in $requiredArtifacts) {
        if (-not $artifactIndex.$artifactName.Present) {
            $reasons.Add("$artifactName is missing.")
        }
    }

    $gateDefinitions = @(
        @{ GateName = 'ExactlyOneTarget'; Passed = @($Target).Count -eq 1; Severity = 'High'; Reason = if (@($Target).Count -eq 1) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } },
        @{ GateName = 'DevTestTenantOnly'; Passed = $targetContext.IsLabOrDevTest; Severity = 'High'; Reason = if ($targetContext.IsLabOrDevTest) { 'Target is labeled as dev/test or lab.' } else { 'Target is not labeled as dev/test or lab.' } },
        @{ GateName = 'TargetIsDisposableOrLabApproved'; Passed = $targetIsDisposableOrLabApproved; Severity = 'High'; Reason = if ($targetIsDisposableOrLabApproved) { 'Target is disposable or lab-approved.' } else { 'Target is not disposable or lab-approved.' } },
        @{ GateName = 'ApprovalManifestPresent'; Passed = $approvalManifestPresent; Severity = 'High'; Reason = if ($approvalManifestPresent) { 'Approval manifest is present.' } else { 'Approval manifest is missing.' } },
        @{ GateName = 'ApprovalNotExpired'; Passed = $approvalNotExpired; Severity = 'High'; Reason = if ($approvalNotExpired) { 'Approval is not expired.' } else { 'Approval is missing or expired.' } },
        @{ GateName = 'ApprovedActionIsReversibleDisable'; Passed = $approvalAction -eq 'ReversibleDisable'; Severity = 'High'; Reason = if ($approvalAction -eq 'ReversibleDisable') { 'Approved action is ReversibleDisable.' } else { 'Approved action is not ReversibleDisable.' } },
        @{ GateName = 'ReadinessReady'; Passed = $readinessReady; Severity = 'High'; Reason = if ($readinessReady) { 'Readiness verdict is ready.' } else { 'Readiness verdict is missing or not ready.' } },
        @{ GateName = 'DryRunPackagePresent'; Passed = $dryRunPackagePresent; Severity = 'High'; Reason = if ($dryRunPackagePresent) { 'Dry-run package is present.' } else { 'Dry-run package is missing.' } },
        @{ GateName = 'RollbackDrillPackagePresent'; Passed = $rollbackDrillPackagePresent; Severity = 'High'; Reason = if ($rollbackDrillPackagePresent) { 'Rollback drill package is present.' } else { 'Rollback drill package is missing.' } },
        @{ GateName = 'FinalGoNoGoReviewPresent'; Passed = $finalGoNoGoReviewPackagePresent; Severity = 'High'; Reason = if ($finalGoNoGoReviewPackagePresent) { 'Final go/no-go review package is present.' } else { 'Final go/no-go review package is missing.' } },
        @{ GateName = 'EvidenceCapturePackagePresent'; Passed = $evidenceCapturePackagePresent; Severity = 'High'; Reason = if ($evidenceCapturePackagePresent) { 'Evidence capture package is present.' } else { 'Evidence capture package is missing.' } },
        @{ GateName = 'ObservationPackagePresent'; Passed = $observationPackagePresent; Severity = 'High'; Reason = if ($observationPackagePresent) { 'Observation package is present.' } else { 'Observation package is missing.' } },
        @{ GateName = 'RollbackReadinessPackagePresent'; Passed = $rollbackReadinessPackagePresent; Severity = 'High'; Reason = if ($rollbackReadinessPackagePresent) { 'Rollback readiness package is present.' } else { 'Rollback readiness package is missing.' } },
        @{ GateName = 'RollbackPreviewPackagePresent'; Passed = $rollbackPreviewPackagePresent; Severity = 'High'; Reason = if ($rollbackPreviewPackagePresent) { 'Rollback preview package is present.' } else { 'Rollback preview package is missing.' } },
        @{ GateName = 'EndToEndRehearsalComplete'; Passed = $endToEndRehearsalReportPresent -and [string](Get-NhiControlledPropertyValue -InputObject $EndToEndRehearsalReport -PropertyNames @('RehearsalStatus', 'Status')) -in @('Complete', 'Ready'); Severity = 'High'; Reason = if ($endToEndRehearsalReportPresent) { 'End-to-end rehearsal report is complete.' } else { 'End-to-end rehearsal report is missing.' } },
        @{ GateName = 'ConsultantGuidePresent'; Passed = $consultantOperatingGuidePresent; Severity = 'High'; Reason = if ($consultantOperatingGuidePresent) { 'Consultant guide is present.' } else { 'Consultant guide is missing.' } },
        @{ GateName = 'NoFinalDeleteRequested'; Passed = -not ($requestedOperations -match '(?i)^FinalDelete$|^Delete$|^HardDelete$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^FinalDelete$|^Delete$|^HardDelete$') { 'Final delete was requested.' } else { 'Final delete was not requested.' } },
        @{ GateName = 'NoRemoveRequested'; Passed = -not ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { 'Remove was requested.' } else { 'Remove was not requested.' } },
        @{ GateName = 'NoGrantCleanupRequested'; Passed = -not ($requestedOperations -match '(?i)^GrantCleanup$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^GrantCleanup$') { 'Grant cleanup was requested.' } else { 'Grant cleanup was not requested.' } },
        @{ GateName = 'NoMetadataCleanupRequested'; Passed = -not ($requestedOperations -match '(?i)^MetadataCleanup$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^MetadataCleanup$') { 'Metadata cleanup was requested.' } else { 'Metadata cleanup was not requested.' } },
        @{ GateName = 'NoCredentialDeleteRequested'; Passed = -not ($requestedOperations -match '(?i)^CredentialDelete$|^CredentialDeletion$|^CredentialChange$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^CredentialDelete$|^CredentialDeletion$|^CredentialChange$') { 'Credential deletion or change was requested.' } else { 'Credential deletion was not requested.' } },
        @{ GateName = 'HumanGoNoGoRequired'; Passed = $true; Severity = 'Info'; Reason = 'Human go/no-go is required.' },
        @{ GateName = 'HumanGoNoGoCapturedFalseByDefault'; Passed = -not $HumanGoNoGoCaptured; Severity = 'Info'; Reason = if (-not $HumanGoNoGoCaptured) { 'Human go/no-go is not auto-captured.' } else { 'Human go/no-go was captured.' } }
    )

    foreach ($gate in $gateDefinitions) {
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gate.GateName -Passed ([bool]$gate.Passed) -Severity $gate.Severity -Reason $gate.Reason))
    }

    foreach ($gateVerdict in $gateVerdicts) {
        if (-not $gateVerdict.Passed -and [string]$gateVerdict.Severity -eq 'High') {
            if ($reasons -notcontains [string]$gateVerdict.Reason) {
                $reasons.Add([string]$gateVerdict.Reason)
            }
        }
    }

    $packageStatus = if ($reasons.Count -eq 0) { 'ReadyForHumanReview' } else { 'NotReady' }
    $readyForControlledDevTestDisable = $false
    if ($reasons.Count -eq 0 -and $HumanGoNoGoCaptured) {
        $readyForControlledDevTestDisable = $true
    }

    $package = [PSCustomObject]@{
        FinalTestPackageId = "REV424-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'FinalControlledDisableTestPackageOnly'
        TenantWritePerformed = $false
        DisablePerformed = $false
        RollbackPerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        SuppressCustomerRemediation = $suppressCustomerRemediation
        EvidenceOnly = $evidenceOnly
        InformationOnly = $informationOnly
        LabTargetMarker = $labMarker
        RequiredArtifactIndex = $artifactIndex
        PreExecutionGates = @($gateVerdicts)
        PreflightCommandPreview = ".\\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -ExecuteNhiControlledDecommission -ExecutionStage DisableOnly -WhatIfExecution -OutputPath '.\\out'"
        LiveCommandBlockTemplate = @(
            '# DO NOT RUN WITHOUT FINAL HUMAN GO/NO-GO',
            '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `',
            '  -ExecuteNhiControlledDecommission `',
            '  -ExecutionStage DisableOnly `',
            '  -OutputPath ''.\out''',
            '# Template only. This package does not execute live disable.'
        ) -join [Environment]::NewLine
        RequestedOperations = @($requestedOperations)
        LabExecutionApprovedDefault = $false
        WhatIfDefault = $true
        ConfirmRequired = $true
        RequiredHumanDecision = $true
        HumanDecisionCaptured = [bool]$HumanGoNoGoCaptured
        HumanGoNoGoRequired = $true
        HumanGoNoGoCaptured = [bool]$HumanGoNoGoCaptured
        PackageStatus = $packageStatus
        ReadyForControlledDevTestDisable = $readyForControlledDevTestDisable
        AllowedNextAction = if ($packageStatus -eq 'ReadyForHumanReview') { 'HumanReviewOnly' } else { 'HumanReviewOnlyBlocked' }
        ProhibitedActions = @('final delete', 'remove service principal', 'remove application', 'grant cleanup', 'metadata cleanup', 'credential deletion')
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
    }

    $artifactPath = Join-Path $OutputPath "Run4C-FinalControlledDisableTestPackage-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CPostDisableEvidenceValidationPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$ExecutionEvidence,

        [Parameter()]
        [object]$PostActionSnapshot,

        [Parameter()]
        [object]$ObservationResult,

        [Parameter()]
        [object]$EvidenceCapturePackage,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $executionEvidencePresent = $null -ne $ExecutionEvidence
    $postActionSnapshotPresent = $null -ne $PostActionSnapshot
    $observationResultPresent = $null -ne $ObservationResult
    $evidenceCapturePackagePresent = $null -ne $EvidenceCapturePackage
    $targetBlocked = $targetContext.Blockers.Count -gt 0
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $executionEvidencePresent) { $reasons.Add('Execution evidence is required.') }
    if (-not $postActionSnapshotPresent) { $reasons.Add('Post-action snapshot is required.') }
    if (-not $observationResultPresent) { $reasons.Add('Observation result is required.') }
    if (-not $evidenceCapturePackagePresent) { $reasons.Add('Evidence capture package is required.') }
    if ($targetBlocked) { $reasons.AddRange(@($targetContext.Blockers)) }

    $accountEnabledBefore = [bool](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AccountEnabled', 'Enabled', 'IsEnabled') -Default $true)
    $accountEnabledAfter = [bool](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('AccountEnabled', 'Enabled', 'IsEnabled') -Default $false)
    $expectedChangeObserved = $preActionSnapshotPresent -and $executionEvidencePresent -and $postActionSnapshotPresent -and ($accountEnabledBefore -eq $true) -and ($accountEnabledAfter -eq $false)

    $credentialCountBefore = [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CredentialCount', 'CredentialsCount') -Default -1)
    $credentialCountAfter = [int](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('CredentialCount', 'CredentialsCount') -Default -1)
    $ownerCountBefore = [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OwnerCount') -Default -1)
    $ownerCountAfter = [int](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('OwnerCount') -Default -1)
    $appRoleAssignmentsBefore = [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppRoleAssignmentCount') -Default -1)
    $appRoleAssignmentsAfter = [int](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('AppRoleAssignmentCount') -Default -1)
    $oauthGrantsBefore = [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OAuthGrantCount', 'GrantCount') -Default -1)
    $oauthGrantsAfter = [int](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('OAuthGrantCount', 'GrantCount') -Default -1)
    $appMetadataBefore = [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppMetadataHash', 'MetadataHash'))
    $appMetadataAfter = [string](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('AppMetadataHash', 'MetadataHash'))
    $servicePrincipalStillExists = [bool](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('ServicePrincipalStillExists', 'ObjectStillExists') -Default $true)
    $applicationStillExists = [bool](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('ApplicationStillExists') -Default $true)

    $credentialCountUnchanged = ($credentialCountBefore -lt 0 -or $credentialCountAfter -lt 0) -or ($credentialCountBefore -eq $credentialCountAfter)
    $ownerCountUnchanged = ($ownerCountBefore -lt 0 -or $ownerCountAfter -lt 0) -or ($ownerCountBefore -eq $ownerCountAfter)
    $appRoleAssignmentCountUnchanged = ($appRoleAssignmentsBefore -lt 0 -or $appRoleAssignmentsAfter -lt 0) -or ($appRoleAssignmentsBefore -eq $appRoleAssignmentsAfter)
    $oauthGrantCountUnchanged = ($oauthGrantsBefore -lt 0 -or $oauthGrantsAfter -lt 0) -or ($oauthGrantsBefore -eq $oauthGrantsAfter)
    $appMetadataUnchanged = ([string]::IsNullOrWhiteSpace($appMetadataBefore) -or [string]::IsNullOrWhiteSpace($appMetadataAfter)) -or ($appMetadataBefore -eq $appMetadataAfter)
    $noDeleteObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $ExecutionEvidence -PropertyNames @('DeletePerformed', 'DeleteObserved') -Default $false) -or [bool](Get-NhiControlledPropertyValue -InputObject $PostActionSnapshot -PropertyNames @('DeleteObserved') -Default $false))
    $noGrantCleanupObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $ExecutionEvidence -PropertyNames @('GrantCleanupPerformed', 'GrantCleanupObserved') -Default $false))
    $noCredentialDeletionObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $ExecutionEvidence -PropertyNames @('CredentialDeletionPerformed', 'CredentialDeleteObserved', 'CredentialDeletionObserved') -Default $false))
    if (-not $expectedChangeObserved) { $reasons.Add('Expected account enabled state change was not observed.') }
    if (-not $credentialCountUnchanged) { $reasons.Add('Credential count changed.') }
    if (-not $ownerCountUnchanged) { $reasons.Add('Owner count changed.') }
    if (-not $appRoleAssignmentCountUnchanged) { $reasons.Add('App role assignment count changed.') }
    if (-not $oauthGrantCountUnchanged) { $reasons.Add('OAuth grant count changed.') }
    if (-not $servicePrincipalStillExists) { $reasons.Add('Service principal no longer exists.') }
    if ($targetType -eq 'Application' -and -not $applicationStillExists) { $reasons.Add('Application no longer exists.') }
    if (-not $noDeleteObserved) { $reasons.Add('Delete observed.') }
    if (-not $noGrantCleanupObserved) { $reasons.Add('Grant cleanup observed.') }
    if (-not $noCredentialDeletionObserved) { $reasons.Add('Credential deletion observed.') }
    if (-not $appMetadataUnchanged) { $warnings.Add('Application metadata changed or was not proven unchanged.') }

    $observationWindowCompleted = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('ObservationWindowCompleted') -Default $false)
    $monitoringOwner = [string](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('MonitoringOwner'))
    $rollbackContact = [string](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('RollbackContact'))
    $successCriteriaMet = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('SuccessCriteriaMet') -Default $false)
    $failureCriteriaTriggered = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('FailureCriteriaTriggered') -Default $false)
    $rollbackTriggerDetected = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('RollbackTriggerDetected') -Default $false)
    $businessOwnerValidationResult = [string](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('BusinessOwnerValidationResult'))

    $artifactPath = Join-Path $OutputPath "Run4C-PostDisableValidation-$RunId.json"
    $package = [PSCustomObject]@{
        PostDisableValidationPackageId = "REV425-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'PostDisableEvidenceValidationOnly'
        TenantWritePerformed = $false
        DisablePerformedByThisPackage = $false
        RollbackPerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        PreActionSnapshotPresent = $preActionSnapshotPresent
        ExecutionEvidencePresent = $executionEvidencePresent
        PostActionSnapshotPresent = $postActionSnapshotPresent
        ObservationResultPresent = $observationResultPresent
        EvidenceCapturePackagePresent = $evidenceCapturePackagePresent
        ExpectedChange = 'AccountEnabled changed from true to false, or equivalent reversible-disable state'
        AccountEnabledBefore = $accountEnabledBefore
        AccountEnabledAfter = $accountEnabledAfter
        ExpectedChangeObserved = $expectedChangeObserved
        CredentialCountUnchanged = $credentialCountUnchanged
        OwnerCountUnchanged = $ownerCountUnchanged
        AppRoleAssignmentCountUnchanged = $appRoleAssignmentCountUnchanged
        OAuthGrantCountUnchanged = $oauthGrantCountUnchanged
        AppMetadataUnchanged = $appMetadataUnchanged
        ServicePrincipalStillExists = $servicePrincipalStillExists
        ApplicationStillExists = $applicationStillExists
        NoDeleteObserved = $noDeleteObserved
        NoGrantCleanupObserved = $noGrantCleanupObserved
        NoCredentialDeletionObserved = $noCredentialDeletionObserved
        ObservationWindowCompleted = $observationWindowCompleted
        MonitoringOwner = $monitoringOwner
        RollbackContact = $rollbackContact
        SuccessCriteriaMet = $successCriteriaMet
        FailureCriteriaTriggered = $failureCriteriaTriggered
        RollbackTriggerDetected = $rollbackTriggerDetected
        BusinessOwnerValidationResult = $businessOwnerValidationResult
        PostDisableValidationStatus = $status
        ReadyToRemainDisabled = $readyToRemainDisabled
        RollbackRecommended = $rollbackRecommended
        Blockers = @($reasons)
        Warnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
    }

    $status = if ($reasons.Count -gt 0) { if ($preActionSnapshotPresent -and $executionEvidencePresent -and $postActionSnapshotPresent -and $observationResultPresent) { 'Failed' } else { 'Incomplete' } } else { 'Passed' }
    $rollbackRecommended = $failureCriteriaTriggered -or $rollbackTriggerDetected -or (-not $successCriteriaMet)
    $readyToRemainDisabled = ($status -eq 'Passed') -and (-not $rollbackRecommended)
    $package.PostDisableValidationStatus = $status
    $package.ReadyToRemainDisabled = $readyToRemainDisabled
    $package.RollbackRecommended = $rollbackRecommended
    $package.Blockers = @($reasons)
    $package.Warnings = @($warnings)

    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CControlledRollbackExecutionTestPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$OriginalDisableEvidence,

        [Parameter()]
        [object]$PostDisableValidationPackage,

        [Parameter()]
        [object]$RollbackReadinessPackage,

        [Parameter()]
        [object]$RollbackPreviewPackage,

        [Parameter()]
        [object]$RollbackDrillPackage,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$ObservationFailureOrManualTrigger,

        [Parameter()]
        [bool]$HumanRollbackApprovalCaptured = $false,

        [Parameter()]
        [string[]]$RequestedOperations = @('ReEnableServicePrincipal'),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $requestedOperations = @($RequestedOperations | ForEach-Object { [string]$_ })
    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $gateVerdicts = [System.Collections.Generic.List[object]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $originalDisablePresent = $null -ne $OriginalDisableEvidence
    $postDisableValidationPresent = $null -ne $PostDisableValidationPackage
    $rollbackReadinessPresent = $null -ne $RollbackReadinessPackage
    $rollbackPreviewPresent = $null -ne $RollbackPreviewPackage
    $rollbackDrillPresent = $null -ne $RollbackDrillPackage
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $observationFailureOrManualTriggerPresent = $null -ne $ObservationFailureOrManualTrigger

    if (-not $originalDisablePresent) { $reasons.Add('Original disable evidence is required.') }
    if (-not $postDisableValidationPresent) { $reasons.Add('Post-disable validation package is required.') }
    if (-not $rollbackReadinessPresent) { $reasons.Add('Rollback readiness package is required.') }
    if (-not $rollbackPreviewPresent) { $reasons.Add('Rollback preview package is required.') }
    if (-not $rollbackDrillPresent) { $reasons.Add('Rollback drill package is required.') }
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $observationFailureOrManualTriggerPresent) { $reasons.Add('Observation failure or manual trigger is required.') }

    $originalActionWasReversibleDisable = [string](Get-NhiControlledPropertyValue -InputObject $OriginalDisableEvidence -PropertyNames @('PlannedAction', 'AllowedAction', 'RequestedAction', 'ActionType')) -eq 'ReversibleDisable'
    $rollbackAction = [string](Get-NhiControlledPropertyValue -InputObject $RollbackPreviewPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    if ([string]::IsNullOrWhiteSpace($rollbackAction)) {
        $rollbackAction = [string](Get-NhiControlledPropertyValue -InputObject $RollbackDrillPackage -PropertyNames @('RollbackAction', 'RollbackActionName'))
    }
    $rollbackActionIsReEnableOnly = $rollbackAction -eq 'ReEnableServicePrincipal'
    $rollbackReadinessReady = [bool](Get-NhiControlledPropertyValue -InputObject $RollbackReadinessPackage -PropertyNames @('Ready', 'RollbackReadiness') -Default $false)
    if (-not $rollbackReadinessReady) {
        $rollbackReadinessReady = [string](Get-NhiControlledPropertyValue -InputObject $RollbackReadinessPackage -PropertyNames @('RollbackReadiness')) -in @('Ready', 'Complete')
    }

    if (-not $originalActionWasReversibleDisable) { $reasons.Add('Original action was not reversible disable.') }
    if (-not $rollbackReadinessReady) { $reasons.Add('Rollback readiness is not ready.') }
    if (-not $rollbackActionIsReEnableOnly) { $reasons.Add('Rollback action must be re-enable only.') }
    if (@($Target).Count -ne 1) { $reasons.Add('Exactly one target is required.') }
    if (-not $targetContext.IsLabOrDevTest) { $reasons.Add('Target must be lab/dev/test only.') }
    if ([string]$classification -eq 'MicrosoftPlatform') { $reasons.Add('MicrosoftPlatform target is blocked.') }
    if ([string]$classification -eq 'ExternalVendorPlatform') { $reasons.Add('ExternalVendorPlatform target is blocked.') }

    $gateDefinitions = @(
        @{ GateName = 'ExactlyOneTarget'; Passed = @($Target).Count -eq 1; Severity = 'High'; Reason = if (@($Target).Count -eq 1) { 'Exactly one target supplied.' } else { 'Exactly one target is required.' } },
        @{ GateName = 'DevTestTenantOnly'; Passed = $targetContext.IsLabOrDevTest; Severity = 'High'; Reason = if ($targetContext.IsLabOrDevTest) { 'Target is labeled as dev/test or lab.' } else { 'Target is not labeled as dev/test or lab.' } },
        @{ GateName = 'OriginalDisableWasReversible'; Passed = $originalActionWasReversibleDisable; Severity = 'High'; Reason = if ($originalActionWasReversibleDisable) { 'Original disable was reversible.' } else { 'Original disable was not reversible.' } },
        @{ GateName = 'RollbackRecommendedOrManuallyTriggered'; Passed = [bool]$ObservationFailureOrManualTrigger; Severity = 'High'; Reason = if ($ObservationFailureOrManualTrigger) { 'Rollback was recommended or manually triggered.' } else { 'Rollback was not recommended or manually triggered.' } },
        @{ GateName = 'RollbackReadinessReady'; Passed = $rollbackReadinessReady; Severity = 'High'; Reason = if ($rollbackReadinessReady) { 'Rollback readiness is ready.' } else { 'Rollback readiness is not ready.' } },
        @{ GateName = 'RollbackActionIsReEnableOnly'; Passed = $rollbackActionIsReEnableOnly; Severity = 'High'; Reason = if ($rollbackActionIsReEnableOnly) { 'Rollback action is re-enable only.' } else { 'Rollback action is not re-enable only.' } },
        @{ GateName = 'HumanRollbackApprovalRequired'; Passed = $true; Severity = 'Info'; Reason = 'Human rollback approval is required.' },
        @{ GateName = 'HumanRollbackApprovalCapturedFalseByDefault'; Passed = -not $HumanRollbackApprovalCaptured; Severity = 'Info'; Reason = if (-not $HumanRollbackApprovalCaptured) { 'Human rollback approval is not auto-captured.' } else { 'Human rollback approval was captured.' } },
        @{ GateName = 'NoDeleteRequested'; Passed = -not ($requestedOperations -match '(?i)^Delete$|^FinalDelete$|^HardDelete$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^Delete$|^FinalDelete$|^HardDelete$') { 'Delete was requested.' } else { 'Delete was not requested.' } },
        @{ GateName = 'NoRemoveRequested'; Passed = -not ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^Remove$|^RemoveServicePrincipal$|^RemoveApplication$') { 'Remove was requested.' } else { 'Remove was not requested.' } },
        @{ GateName = 'NoRecreateRequested'; Passed = -not ($requestedOperations -match '(?i)^Recreate$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^Recreate$') { 'Recreate was requested.' } else { 'Recreate was not requested.' } },
        @{ GateName = 'NoGrantCleanupRequested'; Passed = -not ($requestedOperations -match '(?i)^GrantCleanup$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^GrantCleanup$') { 'Grant cleanup was requested.' } else { 'Grant cleanup was not requested.' } },
        @{ GateName = 'NoMetadataCleanupRequested'; Passed = -not ($requestedOperations -match '(?i)^MetadataCleanup$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^MetadataCleanup$') { 'Metadata cleanup was requested.' } else { 'Metadata cleanup was not requested.' } },
        @{ GateName = 'NoCredentialChangeRequested'; Passed = -not ($requestedOperations -match '(?i)^CredentialChange$|^CredentialDelete$|^CredentialDeletion$'); Severity = 'High'; Reason = if ($requestedOperations -match '(?i)^CredentialChange$|^CredentialDelete$|^CredentialDeletion$') { 'Credential change was requested.' } else { 'Credential change was not requested.' } }
    )

    foreach ($gate in $gateDefinitions) {
        $gateVerdicts.Add((New-NhiControlledGateVerdict -GateName $gate.GateName -Passed ([bool]$gate.Passed) -Severity $gate.Severity -Reason $gate.Reason))
    }

    foreach ($gateVerdict in $gateVerdicts) {
        if (-not $gateVerdict.Passed -and [string]$gateVerdict.Severity -eq 'High') {
            if ($reasons -notcontains [string]$gateVerdict.Reason) {
                $reasons.Add([string]$gateVerdict.Reason)
            }
        }
    }

    $packageStatus = if ($reasons.Count -eq 0) { 'ReadyForHumanRollbackReview' } else { 'NotReady' }
    $readyForControlledDevTestRollback = ($reasons.Count -eq 0) -and $HumanRollbackApprovalCaptured

    $package = [PSCustomObject]@{
        RollbackExecutionTestPackageId = "REV426-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'ControlledRollbackExecutionTestPackageOnly'
        TenantWritePerformed = $false
        RollbackPerformed = $false
        DisablePerformed = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        OriginalDisableEvidencePresent = $originalDisablePresent
        PostDisableValidationPackagePresent = $postDisableValidationPresent
        RollbackReadinessPackagePresent = $rollbackReadinessPresent
        RollbackPreviewPackagePresent = $rollbackPreviewPresent
        RollbackDrillPackagePresent = $rollbackDrillPresent
        PreActionSnapshotPresent = $preActionSnapshotPresent
        ObservationFailureOrManualTriggerPresent = $observationFailureOrManualTriggerPresent
        RollbackAction = if ([string]::IsNullOrWhiteSpace($rollbackAction)) { 'ReEnableServicePrincipal' } else { $rollbackAction }
        RollbackPreflightCommandPreview = ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -ExecuteNhiControlledDecommission -ExecutionStage ReversibleDisable -WhatIfExecution -OutputPath '.\out'"
        RollbackLiveCommandBlockTemplate = @(
            '# DO NOT RUN WITHOUT FINAL HUMAN ROLLBACK GO/NO-GO',
            '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `',
            '  -ExecuteNhiControlledDecommission `',
            '  -ExecutionStage ReversibleDisable `',
            '  -OutputPath ''.\out''',
            '# Template only. This package does not execute live rollback.'
        ) -join [Environment]::NewLine
        WhatIfDefault = $true
        ConfirmRequired = $true
        RollbackExecutionApprovedDefault = $false
        GateVerdicts = @($gateVerdicts)
        PackageStatus = $packageStatus
        ReadyForControlledDevTestRollback = $readyForControlledDevTestRollback
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        HumanRollbackApprovalRequired = $true
        HumanRollbackApprovalCaptured = [bool]$HumanRollbackApprovalCaptured
        AllowedNextAction = if ($packageStatus -eq 'ReadyForHumanRollbackReview') { 'HumanRollbackReviewOnly' } else { 'HumanRollbackReviewOnlyBlocked' }
        ProhibitedActions = @('delete', 'remove service principal', 'remove application', 'recreate object', 'grant cleanup', 'metadata cleanup', 'credential change')
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
    }

    $artifactPath = Join-Path $OutputPath "Run4C-ControlledRollbackExecutionTestPackage-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CPostRollbackValidationPackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$PreActionSnapshot,

        [Parameter()]
        [object]$DisableEvidence,

        [Parameter()]
        [object]$RollbackExecutionEvidence,

        [Parameter()]
        [object]$PostRollbackSnapshot,

        [Parameter()]
        [object]$ObservationResult,

        [Parameter()]
        [string[]]$RequestedOperations = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }
    $preActionSnapshotPresent = $null -ne $PreActionSnapshot
    $disableEvidencePresent = $null -ne $DisableEvidence
    $rollbackExecutionEvidencePresent = $null -ne $RollbackExecutionEvidence
    $postRollbackSnapshotPresent = $null -ne $PostRollbackSnapshot
    $observationResultPresent = $null -ne $ObservationResult
    if (-not $preActionSnapshotPresent) { $reasons.Add('Pre-action snapshot is required.') }
    if (-not $disableEvidencePresent) { $reasons.Add('Disable evidence is required.') }
    if (-not $rollbackExecutionEvidencePresent) { $reasons.Add('Rollback execution evidence is required.') }
    if (-not $postRollbackSnapshotPresent) { $reasons.Add('Post-rollback snapshot is required.') }
    if (-not $observationResultPresent) { $reasons.Add('Observation result is required.') }

    $accountEnabledBefore = [bool](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AccountEnabled', 'Enabled', 'IsEnabled') -Default $true)
    $accountEnabledAfterDisable = [bool](Get-NhiControlledPropertyValue -InputObject $DisableEvidence -PropertyNames @('AccountEnabledAfter', 'EnabledAfter') -Default $false)
    $accountEnabledAfterRollback = [bool](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('AccountEnabled', 'Enabled', 'IsEnabled') -Default $true)
    $enabledStateRestored = $preActionSnapshotPresent -and $rollbackExecutionEvidencePresent -and $postRollbackSnapshotPresent -and ($accountEnabledBefore -eq $accountEnabledAfterRollback)
    $objectIdUnchanged = [string](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('ObjectId')) -eq [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('ObjectId'))
    $appIdUnchanged = [string](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('AppId')) -eq [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppId'))
    $credentialCountChanged = [int](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('CredentialCount', 'CredentialsCount') -Default -1) -ne [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('CredentialCount', 'CredentialsCount') -Default -1)
    $ownerCountChanged = [int](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('OwnerCount') -Default -1) -ne [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OwnerCount') -Default -1)
    $appRoleAssignmentCountChanged = [int](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('AppRoleAssignmentCount') -Default -1) -ne [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppRoleAssignmentCount') -Default -1)
    $oauthGrantCountChanged = [int](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('OAuthGrantCount', 'GrantCount') -Default -1) -ne [int](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('OAuthGrantCount', 'GrantCount') -Default -1)
    $appMetadataRestoredOrUnchanged = ([string](Get-NhiControlledPropertyValue -InputObject $PostRollbackSnapshot -PropertyNames @('AppMetadataHash', 'MetadataHash')) -eq [string](Get-NhiControlledPropertyValue -InputObject $PreActionSnapshot -PropertyNames @('AppMetadataHash', 'MetadataHash')))
    $noDeleteObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionEvidence -PropertyNames @('DeletePerformed', 'DeleteObserved') -Default $false))
    $noRecreateObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionEvidence -PropertyNames @('RecreatePerformed', 'RecreateObserved') -Default $false))
    $noGrantCleanupObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionEvidence -PropertyNames @('GrantCleanupPerformed', 'GrantCleanupObserved') -Default $false))
    $noCredentialChangeObserved = -not ([bool](Get-NhiControlledPropertyValue -InputObject $RollbackExecutionEvidence -PropertyNames @('CredentialChangePerformed', 'CredentialDeleteObserved', 'CredentialDeletionObserved', 'CredentialDeletionPerformed') -Default $false))
    if (-not $enabledStateRestored) { $reasons.Add('Enabled state was not restored.') }
    if ($credentialCountChanged) { $reasons.Add('Credential count changed.') }
    if ($ownerCountChanged) { $reasons.Add('Owner count changed.') }
    if ($appRoleAssignmentCountChanged) { $reasons.Add('App role assignment count changed.') }
    if ($oauthGrantCountChanged) { $reasons.Add('OAuth grant count changed.') }
    if (-not $objectIdUnchanged) { $reasons.Add('ObjectId changed.') }
    if (-not $appIdUnchanged) { $reasons.Add('AppId changed.') }
    if (-not $noDeleteObserved) { $reasons.Add('Delete observed.') }
    if (-not $noRecreateObserved) { $reasons.Add('Recreate observed.') }
    if (-not $noGrantCleanupObserved) { $reasons.Add('Grant cleanup observed.') }
    if (-not $noCredentialChangeObserved) { $reasons.Add('Credential change observed.') }
    if (-not $appMetadataRestoredOrUnchanged) { $warnings.Add('Metadata changed or could not be proven unchanged.') }

    $postRollbackValidationStatus = if ($preActionSnapshotPresent -and $disableEvidencePresent -and $rollbackExecutionEvidencePresent -and $postRollbackSnapshotPresent -and $observationResultPresent) {
        if ($reasons.Count -gt 0) { 'Failed' } elseif ($enabledStateRestored -and -not $credentialCountChanged -and -not $ownerCountChanged -and -not $appRoleAssignmentCountChanged -and -not $oauthGrantCountChanged -and $noDeleteObserved -and $noRecreateObserved -and $noGrantCleanupObserved -and $noCredentialChangeObserved) { 'Passed' } else { 'Failed' }
    } else {
        'Incomplete'
    }

    $observationWindowCompleted = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('ObservationWindowCompleted') -Default $false)
    $successCriteriaMet = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('SuccessCriteriaMet') -Default $false)
    $failureCriteriaTriggered = [bool](Get-NhiControlledPropertyValue -InputObject $ObservationResult -PropertyNames @('FailureCriteriaTriggered') -Default $false)
    $remainingRisk = @()
    if (-not $enabledStateRestored) { $remainingRisk += 'Enabled state not restored' }
    if ($credentialCountChanged) { $remainingRisk += 'Credential count changed' }
    if ($ownerCountChanged) { $remainingRisk += 'Owner count changed' }

    $package = [PSCustomObject]@{
        PostRollbackValidationPackageId = "REV427-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'PostRollbackValidationOnly'
        TenantWritePerformed = $false
        RollbackPerformedByThisPackage = $false
        DeletePerformed = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        PreActionSnapshotPresent = $preActionSnapshotPresent
        DisableEvidencePresent = $disableEvidencePresent
        RollbackExecutionEvidencePresent = $rollbackExecutionEvidencePresent
        PostRollbackSnapshotPresent = $postRollbackSnapshotPresent
        ObservationResultPresent = $observationResultPresent
        AccountEnabledBefore = $accountEnabledBefore
        AccountEnabledAfterDisable = $accountEnabledAfterDisable
        AccountEnabledAfterRollback = $accountEnabledAfterRollback
        EnabledStateRestored = $enabledStateRestored
        ObjectIdUnchanged = $objectIdUnchanged
        AppIdUnchanged = $appIdUnchanged
        CredentialCountRestoredOrUnchanged = -not $credentialCountChanged
        OwnerCountRestoredOrUnchanged = -not $ownerCountChanged
        AppRoleAssignmentCountRestoredOrUnchanged = -not $appRoleAssignmentCountChanged
        OAuthGrantCountRestoredOrUnchanged = -not $oauthGrantCountChanged
        AppMetadataRestoredOrUnchanged = $appMetadataRestoredOrUnchanged
        NoDeleteObserved = $noDeleteObserved
        NoRecreateObserved = $noRecreateObserved
        NoGrantCleanupObserved = $noGrantCleanupObserved
        NoCredentialChangeObserved = $noCredentialChangeObserved
        PostRollbackValidationStatus = $postRollbackValidationStatus
        RestorationConfirmed = $enabledStateRestored -and -not $credentialCountChanged -and -not $ownerCountChanged -and -not $appRoleAssignmentCountChanged -and -not $oauthGrantCountChanged
        RemainingRisk = @($remainingRisk)
        Warnings = @($warnings)
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
        SuccessCriteriaMet = $successCriteriaMet
        FailureCriteriaTriggered = $failureCriteriaTriggered
    }

    $artifactPath = Join-Path $OutputPath "Run4C-PostRollbackValidation-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force
    return $package
}

function New-NhiRun4CFinalEvidenceBundle {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object[]]$Target,

        [Parameter()]
        [object]$Rev410PlatformClassificationEvidence,

        [Parameter()]
        [object]$Rev411PlanningProof,

        [Parameter()]
        [object]$Rev412ReadinessGate,

        [Parameter()]
        [object]$Rev413DryRunPackage,

        [Parameter()]
        [object]$Rev414RollbackDrillPackage,

        [Parameter()]
        [object]$Rev415ControlledDisablePathPackage,

        [Parameter()]
        [object]$Rev416FinalGoNoGoReviewPackage,

        [Parameter()]
        [object]$Rev417EvidenceCapturePackage,

        [Parameter()]
        [object]$Rev418ObservationPackage,

        [Parameter()]
        [object]$Rev419RollbackReadinessPackage,

        [Parameter()]
        [object]$Rev420RollbackPreviewPackage,

        [Parameter()]
        [object]$Rev421FinalDeleteSimulationPackage,

        [Parameter()]
        [object]$Rev422RehearsalReport,

        [Parameter()]
        [object]$Rev423ConsultantGuide,

        [Parameter()]
        [object]$Rev424FinalControlledDisableTestPackage,

        [Parameter()]
        [object]$Rev425PostDisableValidationPackage,

        [Parameter()]
        [object]$Rev426RollbackExecutionTestPackage,

        [Parameter()]
        [object]$Rev427PostRollbackValidationPackage,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string]$MarkdownOutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $targetContext = Get-NhiRun4CTargetContext -Target $Target
    foreach ($reason in @($targetContext.Blockers)) {
        if ($reason) { $reasons.Add([string]$reason) }
    }

    $targetObject = if (@($Target).Count -eq 1) { @($Target)[0] } else { $null }
    $targetDisplayName = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('DisplayName')) } else { $null }
    $targetObjectId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectId')) } else { $null }
    $targetAppId = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('AppId')) } else { $null }
    $targetType = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('ObjectType', 'TargetType')) } else { $null }
    $environment = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Environment', 'TenantScope')) } else { $null }
    $classification = if ($targetObject) { [string](Get-NhiControlledPropertyValue -InputObject $targetObject -PropertyNames @('Classification')) } else { $null }

    $chainItems = @(
        [PSCustomObject]@{ Revision = 'Rev4.10'; Label = 'platform classification evidence'; Package = $Rev410PlatformClassificationEvidence; Required = $false },
        [PSCustomObject]@{ Revision = 'Rev4.11'; Label = 'planning proof'; Package = $Rev411PlanningProof; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.12'; Label = 'readiness gate'; Package = $Rev412ReadinessGate; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.13'; Label = 'dry-run package'; Package = $Rev413DryRunPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.14'; Label = 'rollback drill package'; Package = $Rev414RollbackDrillPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.15'; Label = 'controlled disable path package'; Package = $Rev415ControlledDisablePathPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.16'; Label = 'final go/no-go review package'; Package = $Rev416FinalGoNoGoReviewPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.17'; Label = 'evidence capture package'; Package = $Rev417EvidenceCapturePackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.18'; Label = 'observation package'; Package = $Rev418ObservationPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.19'; Label = 'rollback readiness package'; Package = $Rev419RollbackReadinessPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.20'; Label = 'rollback preview package'; Package = $Rev420RollbackPreviewPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.21'; Label = 'final delete simulation package'; Package = $Rev421FinalDeleteSimulationPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.22'; Label = 'rehearsal report'; Package = $Rev422RehearsalReport; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.23'; Label = 'consultant guide'; Package = $Rev423ConsultantGuide; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.24'; Label = 'final controlled disable test package'; Package = $Rev424FinalControlledDisableTestPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.25'; Label = 'post-disable validation package'; Package = $Rev425PostDisableValidationPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.26'; Label = 'rollback execution test package'; Package = $Rev426RollbackExecutionTestPackage; Required = $true },
        [PSCustomObject]@{ Revision = 'Rev4.27'; Label = 'post-rollback validation package'; Package = $Rev427PostRollbackValidationPackage; Required = $true }
    )

    $chainIndex = foreach ($item in $chainItems) {
        $present = $null -ne $item.Package
        $status = if (-not $present) {
            'Missing'
        } elseif ($item.Package.PSObject.Properties['PackageStatus']) {
            [string]$item.Package.PackageStatus
        } elseif ($item.Package.PSObject.Properties['PostDisableValidationStatus']) {
            [string]$item.Package.PostDisableValidationStatus
        } elseif ($item.Package.PSObject.Properties['PostRollbackValidationStatus']) {
            [string]$item.Package.PostRollbackValidationStatus
        } elseif ($item.Package.PSObject.Properties['Ready']) {
            if ($item.Package.Ready -eq $true) { 'Ready' } else { 'NotReady' }
        } elseif ($item.Package.PSObject.Properties['GoNoGo']) {
            [string]$item.Package.GoNoGo
        } elseif ($item.Package.PSObject.Properties['RehearsalStatus']) {
            [string]$item.Package.RehearsalStatus
        } elseif ($item.Package.PSObject.Properties['GuideId']) {
            'Present'
        } else {
            'Present'
        }

        if ($item.Required -and -not $present) { $reasons.Add("$($item.Revision) package is missing.") }

        [PSCustomObject]@{
            Revision = $item.Revision
            Label = $item.Label
            Present = $present
            Path = [string](Get-NhiControlledPropertyValue -InputObject $item.Package -PropertyNames @('OutputArtifactPath', 'MarkdownArtifactPath'))
            Status = $status
        }
    }

    $requiredPresent = -not ($chainIndex | Where-Object { $_.Revision -in @('Rev4.11','Rev4.12','Rev4.13','Rev4.14','Rev4.15','Rev4.16','Rev4.17','Rev4.18','Rev4.19','Rev4.20','Rev4.21','Rev4.22','Rev4.23','Rev4.24','Rev4.25','Rev4.26','Rev4.27') -and -not $_.Present })
    $safetyAssertionsPassed = ($targetContext.IsLabOrDevTest) -and (-not $targetContext.Blockers)
    $chainComplete = $requiredPresent -and $safetyAssertionsPassed
    if (-not $requiredPresent) { $reasons.Add('One or more required chain artifacts are missing.') }
    if (-not $safetyAssertionsPassed) { $reasons.Add('Safety assertions failed for the target context.') }

    $bundle = [PSCustomObject]@{
        EvidenceBundleId = "REV428-$RunId-$targetObjectId"
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'FinalRev4EvidenceBundleOnly'
        TenantWritePerformedByBundle = $false
        DisablePerformedByBundle = $false
        RollbackPerformedByBundle = $false
        DeletePerformedByBundle = $false
        FinalDeleteAllowed = $false
        TargetDisplayName = $targetDisplayName
        TargetObjectId = $targetObjectId
        TargetAppId = $targetAppId
        TargetType = $targetType
        EnvironmentMarker = $environment
        Classification = $classification
        ChainIndex = @($chainIndex)
        ChainComplete = $chainComplete
        RequiredArtifactsPresent = $requiredPresent
        SafetyAssertionsPassed = $safetyAssertionsPassed
        FinalDeleteExcluded = $true
        ProductionTenantExcluded = $targetContext.IsLabOrDevTest
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
        ConsultantSummary = [PSCustomObject]@{
            WhatWasProven = @(
                'The Run #4C chain is package-only through Rev4.27.',
                'No live tenant write occurred in the bundle step.',
                'Rev4.24 through Rev4.27 artifacts can be chained and reviewed locally.'
            )
            WhatWasNotProven = @(
                'No live disable occurred in the bundle step.',
                'No rollback execution occurred in the bundle step.',
                'No final delete execution occurred.',
                'No production tenant write occurred.'
            )
            WhatRemainsSeparate = @(
                'Human go/no-go remains separate.',
                'Actual tenant execution remains separate.',
                'Final delete remains out of scope.'
            )
            ClientSafeStatement = 'This evidence bundle is local, review-only, and does not authorize tenant mutation.'
            DeleteOutOfScopeStatement = 'Final delete is excluded from Rev4.x and remains out of scope.'
        }
        ContainedSecrets = $false
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
    }

    $artifactPath = Join-Path $OutputPath "Run4C-FinalEvidenceBundle-$RunId.json"
    $bundle | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $bundle -Path $artifactPath) -Force

    if ($MarkdownOutputPath) {
        $markdown = [System.Collections.Generic.List[string]]::new()
        $markdown.Add('# Final Rev4 Evidence Bundle')
        $markdown.Add('')
        $markdown.Add("- EvidenceBundleId: $($bundle.EvidenceBundleId)")
        $markdown.Add("- ChainComplete: $chainComplete")
        $markdown.Add("- RequiredArtifactsPresent: $requiredPresent")
        $markdown.Add("- SafetyAssertionsPassed: $safetyAssertionsPassed")
        $markdown.Add('')
        $markdown.Add('## Consultant Summary')
        $markdown.Add('- What was proven:')
        foreach ($line in @($bundle.ConsultantSummary.WhatWasProven | ForEach-Object { "  - $_" })) {
            $markdown.Add([string]$line)
        }
        $markdown.Add('- What was not proven:')
        foreach ($line in @($bundle.ConsultantSummary.WhatWasNotProven | ForEach-Object { "  - $_" })) {
            $markdown.Add([string]$line)
        }
        $markdown.Add('- What remains separate:')
        foreach ($line in @($bundle.ConsultantSummary.WhatRemainsSeparate | ForEach-Object { "  - $_" })) {
            $markdown.Add([string]$line)
        }
        [System.IO.File]::WriteAllText($MarkdownOutputPath, ($markdown -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
        $bundle | Add-Member -NotePropertyName MarkdownArtifactPath -NotePropertyValue $MarkdownOutputPath -Force
    }

    return $bundle
}

function New-NhiRev4ReleaseCandidateFreezePackage {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [object]$EvidenceBundle,

        [Parameter()]
        [object]$ConsultantOperatingGuide,

        [Parameter()]
        [object]$SafetyPosture,

        [Parameter()]
        [string]$BranchName,

        [Parameter()]
        [string]$TagName,

        [Parameter()]
        [string]$CommitHash,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter()]
        [string]$MarkdownOutputPath
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $EvidenceBundle) { $reasons.Add('Evidence bundle is required.') }
    if ($null -eq $ConsultantOperatingGuide) { $reasons.Add('Consultant operating guide is required.') }
    if ($null -eq $SafetyPosture) { $reasons.Add('Safety posture is required.') }

    $milestones = @(
        @{ Revision = 'Rev4.10'; Purpose = 'Platform identity classification evidence'; Status = 'Completed' },
        @{ Revision = 'Rev4.11'; Purpose = 'Approved reversible planning proof'; Status = 'Completed' },
        @{ Revision = 'Rev4.12'; Purpose = 'Readiness gate'; Status = 'Completed' },
        @{ Revision = 'Rev4.13'; Purpose = 'Dry-run package'; Status = 'Completed' },
        @{ Revision = 'Rev4.14'; Purpose = 'Rollback drill package'; Status = 'Completed' },
        @{ Revision = 'Rev4.15'; Purpose = 'Controlled disable path'; Status = 'Completed' },
        @{ Revision = 'Rev4.16'; Purpose = 'Final go/no-go review package'; Status = 'Completed' },
        @{ Revision = 'Rev4.17'; Purpose = 'Evidence capture package'; Status = 'Completed' },
        @{ Revision = 'Rev4.18'; Purpose = 'Observation package'; Status = 'Completed' },
        @{ Revision = 'Rev4.19'; Purpose = 'Rollback readiness package'; Status = 'Completed' },
        @{ Revision = 'Rev4.20'; Purpose = 'Rollback preview package'; Status = 'Completed' },
        @{ Revision = 'Rev4.21'; Purpose = 'Final delete simulation package'; Status = 'Completed' },
        @{ Revision = 'Rev4.22'; Purpose = 'End-to-end rehearsal report'; Status = 'Completed' },
        @{ Revision = 'Rev4.23'; Purpose = 'Consultant operating guide'; Status = 'Completed' },
        @{ Revision = 'Rev4.24'; Purpose = 'Final controlled disable test package'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.25'; Purpose = 'Post-disable validation package'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.26'; Purpose = 'Rollback execution test package'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.27'; Purpose = 'Post-rollback validation package'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.28'; Purpose = 'Final evidence bundle'; Status = if ($null -ne $EvidenceBundle) { 'Included' } else { 'Missing' } },
        @{ Revision = 'Rev4.29'; Purpose = 'Release candidate freeze and handoff'; Status = 'ReadyForReview' }
    )

    $releaseCandidateStatus = if ($reasons.Count -eq 0) { 'Ready' } else { 'NotReady' }
    $package = [PSCustomObject]@{
        ReleaseCandidateId = "REV429-$RunId"
        Version = 'Rev4.x Release Candidate'
        RunId = $RunId
        CreatedUtc = [DateTime]::UtcNow.ToString('o')
        Mode = 'ReleaseCandidateFreezeOnly'
        TenantWritePerformed = $false
        DisablePerformedByFreeze = $false
        RollbackPerformedByFreeze = $false
        DeletePerformedByFreeze = $false
        FinalDeleteAllowed = $false
        BranchName = $BranchName
        TagName = $TagName
        CommitHash = $CommitHash
        MilestoneChain = @($milestones)
        ReleaseScope = @(
            'Consultant-ready lab workflow',
            'Dev/test reversible-disable governance chain',
            'Evidence-first decommissioning workflow',
            'Rollback readiness and validation workflow',
            'Final delete simulation only',
            'No production execution',
            'No final delete execution'
        )
        ReleaseExclusions = @(
            'Production tenant execution excluded.',
            'Actual final delete excluded.',
            'Service principal/application removal excluded.',
            'Grant cleanup excluded.',
            'Credential deletion excluded.',
            'Metadata cleanup excluded.',
            'Rev5.x required for any future final-delete governance framework.'
        )
        HandoffChecklist = @(
            'All tests passed',
            'Branches/tags recorded',
            'Safety posture recorded',
            'Operating guide generated',
            'Evidence bundle generated',
            'Known limitations documented',
            'Future Rev5.x scope documented'
        )
        FinalDeleteOutOfScope = $true
        Rev5RequiredForDelete = $true
        RequiredArtifactsPresent = $reasons.Count -eq 0
        SafetyAssertionsPassed = $reasons.Count -eq 0
        ReleaseCandidateStatus = $releaseCandidateStatus
        RemainingBlockers = @($reasons)
        RemainingWarnings = @($warnings)
        ConsultantSummary = [PSCustomObject]@{
            WhatWasProven = 'Rev4.x artifacts can be compiled into a local freeze package.'
            WhatWasNotProven = 'No tenant execution was performed by the freeze package.'
            KnownLimitations = @('Final delete is excluded.', 'Human review remains required.', 'Rev5.x is needed for future delete governance.')
            FutureRev5Scope = 'Any future final-delete governance framework belongs to Rev5.x or later.'
        }
        RequiredHumanDecision = $true
        HumanDecisionCaptured = $false
    }

    $artifactPath = Join-Path $OutputPath "Rev4-ReleaseCandidateFreeze-$RunId.json"
    $package | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue (Export-NhiControlledDecommissionEvidence -Evidence $package -Path $artifactPath) -Force

    if ($MarkdownOutputPath) {
        $markdown = @(
            '# Rev4.x Release Candidate Freeze',
            '',
            "- ReleaseCandidateId: $($package.ReleaseCandidateId)",
            "- ReleaseCandidateStatus: $releaseCandidateStatus",
            "- FinalDeleteOutOfScope: $true",
            "- Rev5RequiredForDelete: $true",
            '',
            '## Handoff Checklist'
        )
        foreach ($item in $package.HandoffChecklist) { $markdown += "- $item" }
        $markdown += ''
        $markdown += '## Release Exclusions'
        foreach ($item in $package.ReleaseExclusions) { $markdown += "- $item" }
        [System.IO.File]::WriteAllText($MarkdownOutputPath, ($markdown -join [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
        $package | Add-Member -NotePropertyName MarkdownArtifactPath -NotePropertyValue $MarkdownOutputPath -Force
    }

    return $package
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
    'Test-NhiControlledLabLiveReversibleDisableReadiness',
    'Export-NhiControlledDecommissionEvidence',
    'New-NhiControlledLabDisableDryRunPackage',
    'New-NhiControlledLabRollbackDrillPackage',
    'Invoke-NhiControlledLabLiveReversibleDisable',
    'New-NhiRun4CFinalGoNoGoReviewPackage',
    'New-NhiRun4CLiveEvidenceCapturePackage',
    'New-NhiRun4CPostDisableObservationPackage',
    'New-NhiRun4CRollbackExecutionReadinessPackage',
    'Invoke-NhiControlledLabRollback',
    'New-NhiFinalDeleteEligibilitySimulationPackage',
    'New-NhiRun4CEndToEndLabRehearsalReport',
    'New-NhiRun4CConsultantOperatingGuide',
    'Get-NhiRun4CArtifactRecord',
    'New-NhiRun4CFinalControlledDisableTestPackage',
    'New-NhiRun4CPostDisableEvidenceValidationPackage',
    'New-NhiRun4CControlledRollbackExecutionTestPackage',
    'New-NhiRun4CPostRollbackValidationPackage',
    'New-NhiRun4CFinalEvidenceBundle',
    'New-NhiRev4ReleaseCandidateFreezePackage'
)
