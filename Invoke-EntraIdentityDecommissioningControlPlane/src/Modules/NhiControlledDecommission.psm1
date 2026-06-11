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
