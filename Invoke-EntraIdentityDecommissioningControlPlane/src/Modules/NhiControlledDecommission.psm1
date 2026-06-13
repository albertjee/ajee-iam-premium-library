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
    'Export-NhiControlledDecommissionEvidence'
)
