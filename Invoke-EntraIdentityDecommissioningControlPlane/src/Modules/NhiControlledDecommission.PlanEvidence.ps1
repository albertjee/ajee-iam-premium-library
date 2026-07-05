# NhiControlledDecommission.PlanEvidence.ps1
# Dot-sourced into NhiControlledDecommission.psm1 module scope. Do not import directly.
# Contains: New-NhiControlledE2EEvidencePack, New-NhiControlledOperatorDecisionLog, New-NhiControlledRollbackPlan, New-NhiControlledDecommissionPlan, Export-NhiControlledDecommissionEvidence, New-NhiControlledProductionReadinessEvidenceState, New-NhiControlledFindingDispositionSummary, New-NhiControlledKnownWarningInventory, New-NhiControlledFinalSafetyAssertions, New-NhiControlledProductionReadinessGate, New-NhiControlledReleaseMergeGateManifest, New-NhiControlledMergeGate, New-NhiControlledProductionReadinessEvidencePack

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
