# NhiControlledDecommission.Gates.ps1
# Dot-sourced into NhiControlledDecommission.psm1 module scope. Do not import directly.
# Contains: Test-NhiControlledTarget, Confirm-NhiControlledApproval, Get-NhiControlledScreamTestStatus, Test-NhiControlledDependencies, Get-NhiControlledDeleteReadiness, Test-NhiControlledServicePrincipalFinalDeleteGate, Test-NhiControlledApplicationDeleteReadinessGate, Get-NhiControlledRollbackLimitation, Get-NhiControlledCredentialMetadataEvidence, Get-NhiControlledOwnerMetadataEvidence, New-NhiControlledGateVerdict

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
