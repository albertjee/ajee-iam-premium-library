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
$script:SupportedStages = @('ValidateOnly', 'SnapshotOnly', 'TagOnly', 'DisableOnly', 'ScreamTestOnly', 'DeleteReadinessOnly', 'FinalDelete')
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
        ActionLogSchemaVersion              = $script:ControlledSchemaVersion
        SnapshotSchemaVersion               = $script:ControlledSchemaVersion
        DeleteReadinessSchemaVersion        = $script:ControlledSchemaVersion
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
                $metadata += [ordered]@{
                    KeyId             = [string]$credential.KeyId
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
        [DateTime]$NowUtc = [DateTime]::UtcNow
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    if ([string]$Approval.SchemaVersion -ne $script:ControlledSchemaVersion) { $reasons.Add('Approval schema version is invalid.') }
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
