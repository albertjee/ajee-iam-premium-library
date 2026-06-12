#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-e2e-evidence-pack.sample.json'
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

    $script:Target = [PSCustomObject]@{
        ObjectId = 'e2e-rev48-test-001'
        ObjectType = 'ManagedIdentity'
        DisplayName = 'Rev48 E2E Managed Identity'
        ManagedIdentityType = 'SystemAssigned'
        ProtectedObject = $false
        MicrosoftFirstParty = $false
        EmergencyAccessIndicator = $false
        BreakGlassIndicator = $false
        HighConfidenceActive = $false
        Ambiguous = $false
    }
    $script:TargetValidation = Test-NhiControlledTarget -Target $script:Target
    $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target $script:Target -RunId 'RUN-REV48-E2E-SAMPLE-001'
    $script:RawSample = Get-Content -LiteralPath $script:SamplePath -Raw
    $script:Sample = $script:RawSample | ConvertFrom-Json

    function New-Rev48Plan {
        param([hashtable]$Overrides = @{})
        $plan = [ordered]@{
            SchemaVersion = '4.8'
            RunId = 'RUN-REV48-E2E-SAMPLE-001'
            TargetId = 'e2e-rev48-test-001'
            TargetType = 'ManagedIdentity'
            ManagedIdentityType = 'SystemAssigned'
            ApprovalId = 'APP-REV48-E2E-001'
            TargetObjectIds = @('e2e-rev48-test-001')
            ApprovedActions = @('E2EEvidencePack')
            TargetCountsByType = [ordered]@{ ServicePrincipal = 2; Application = 1; ManagedIdentity = 1 }
            DependencyRecheck = [PSCustomObject]@{
                SchemaVersion = '4.8'
                Status = 'Clean'
                QuerySucceeded = $true
                Blocked = $false
                SkippedWithApproval = $false
            }
            DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
            MetadataReadiness = [PSCustomObject]@{ Status = 'MetadataCleanupSatisfiedSimulationOnly' }
            GrantReadiness = [PSCustomObject]@{ Status = 'GrantCleanupSatisfiedSimulationOnly' }
            ManagedIdentityReadiness = [PSCustomObject]@{ Status = 'ManagedIdentityReadinessSatisfiedSimulationOnly' }
            ScreamTestEvidence = [PSCustomObject]@{
                EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                Status = 'Complete'
                DependencyDetected = $false
                RecentActivityDetected = $false
                QuerySucceeded = $true
            }
            OperatorDecision = [PSCustomObject]@{
                Decision = 'SimulationOnly'
                DecisionBy = 'local-planner'
                DecisionAtUtc = '2099-01-01T00:00:00Z'
                Reason = 'No live tenant execution is allowed.'
                Scope = 'Rev4.8'
                IsSimulationOnly = $true
            }
            KnownWarnings = @('DemoMode traceability warning may still appear in legacy assessment paths.')
            LiveDeleteExecutable = $false
            LiveCleanupExecutable = $false
            GraphWritePathAvailable = $false
            FinalDeleteSimulationOnly = $true
        }
        foreach ($key in $Overrides.Keys) { $plan[$key] = $Overrides[$key] }
        [PSCustomObject]$plan
    }

    function New-Rev48Approval {
        param([hashtable]$Overrides = @{})
        $approval = [ordered]@{
            SchemaVersion = '4.8'
            RunId = 'RUN-REV48-E2E-SAMPLE-001'
            Status = 'Approved'
            ApprovedBy = 'e2e-qa-approver@example.com'
            ExpiresUtc = '2099-01-01T00:00:00Z'
            Reusable = $false
            ApprovalId = 'APP-REV48-E2E-001'
            TargetId = 'e2e-rev48-test-001'
            TargetType = 'ManagedIdentity'
            ManagedIdentityType = 'SystemAssigned'
            TargetObjectIds = @('e2e-rev48-test-001')
            ApprovedActions = @('E2EEvidencePack')
            TargetCountsByType = [ordered]@{ ServicePrincipal = 2; Application = 1; ManagedIdentity = 1 }
            LiveDeleteExecutable = $false
            LiveCleanupExecutable = $false
            GraphWritePathAvailable = $false
            FinalDeleteSimulationOnly = $true
        }
        foreach ($key in $Overrides.Keys) { $approval[$key] = $Overrides[$key] }
        [PSCustomObject]$approval
    }

    function New-Rev48PackInput {
        param(
            [hashtable]$PlanOverrides = @{},
            [hashtable]$ApprovalOverrides = @{},
            [bool]$SnapshotPresent = $true
        )

        $plan = New-Rev48Plan -Overrides $PlanOverrides
        $snapshot = if ($SnapshotPresent) { $script:Snapshot } else { $null }
        $approval = New-Rev48Approval -Overrides $ApprovalOverrides

        [PSCustomObject]@{
            Plan = $plan
            Approval = $approval
            Snapshot = $snapshot
            ScreamTest = $plan.ScreamTestEvidence
            DependencyRecheck = $plan.DependencyRecheck
            DeleteReadiness = $plan.DeleteReadiness
            MetadataReadiness = $plan.MetadataReadiness
            GrantReadiness = $plan.GrantReadiness
            ManagedIdentityReadiness = $plan.ManagedIdentityReadiness
            OperatorDecision = $plan.OperatorDecision
            KnownWarnings = $plan.KnownWarnings
        }
    }

    function Invoke-Rev48Module {
        param(
            [scriptblock]$ScriptBlock,
            [Parameter(ValueFromRemainingArguments = $true)]
            [object[]]$Arguments
        )
        $module = Get-Module NhiControlledDecommission
        & $module $ScriptBlock @Arguments
    }
}

AfterAll {
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
}

Describe 'Rev4.8 evidence pack contract' {
    It 'keeps the private helpers hidden and export contract frozen' {
        Get-Command New-NhiControlledE2EEvidencePack -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command New-NhiControlledOperatorDecisionLog -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        (Get-Module NhiControlledDecommission).ExportedCommands.Keys.Count | Should -Be 11
    }

    It 'parses the E2E sample JSON' {
        $script:Sample | Should -Not -BeNullOrEmpty
        $script:Sample.SchemaVersion | Should -Be '4.8'
        $script:Sample.TargetType | Should -Be 'ManagedIdentity'
    }

    It 'contains no secret-like values or delete cmdlet names' {
        $script:RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        $script:RawSample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az'
    }

    It 'captures evidence pack input identity and counts' {
        $script:Sample.TargetCountsByType.ServicePrincipal | Should -Be 2
        $script:Sample.TargetCountsByType.Application | Should -Be 1
        $script:Sample.TargetCountsByType.ManagedIdentity | Should -Be 1
    }

    It 'returns target counts by type from the module helper' {
        $counts = Invoke-Rev48Module { param($Plan) Get-NhiControlledTargetCountsByType -Plan $Plan } (New-Rev48Plan)
        $counts.ServicePrincipal | Should -Be 2
        $counts.Application | Should -Be 1
        $counts.ManagedIdentity | Should -Be 1
    }

    It 'sets live-delete and live-cleanup flags false' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.LiveDeleteExecutable | Should -BeFalse
        $pack.LiveCleanupExecutable | Should -BeFalse
        $pack.GraphWritePathAvailable | Should -BeFalse
        $pack.FinalDeleteSimulationOnly | Should -BeTrue
    }

    It 'builds a QA handoff manifest with the required fields' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.QAHandoffManifest.ToolVersion | Should -Be 'Rev4.1'
        $pack.QAHandoffManifest.PushStatus | Should -Be 'No'
        $pack.QAHandoffManifest.EvidenceArtifacts.Count | Should -Be 5
    }

    It 'builds an operator decision log with the required fields' {
        $decision = Invoke-Rev48Module {
            param($Plan, $Decision)
            New-NhiControlledOperatorDecisionLog -Plan $Plan -Decision $Decision.Decision -DecisionBy $Decision.DecisionBy -Reason $Decision.Reason -Scope $Decision.Scope
        } (New-Rev48Plan) (New-Rev48Plan).OperatorDecision
        $decision.Decision | Should -Be 'SimulationOnly'
        $decision.IsSimulationOnly | Should -BeTrue
        $decision.Scope | Should -Be 'Rev4.8'
    }

    It 'summarizes approval coverage, snapshot coverage, and scream-test status' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.ApprovalCoverage.ExactTarget | Should -BeTrue
        $pack.SnapshotCoverage.Present | Should -BeTrue
        $pack.ScreamTestSummary.IllustrativeOnly | Should -BeTrue
    }

    It 'summarizes dependency recheck, delete readiness, and cleanup readiness' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.DependencyRecheckSummary.Status | Should -Be 'Clean'
        $pack.DeleteReadinessSummary.Status | Should -Be 'Ready'
        $pack.CleanupReadinessSummary.Metadata | Should -Be 'MetadataCleanupSatisfiedSimulationOnly'
    }

    It 'summarizes rollback limitation and validation results' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.RollbackLimitationSummary.Classification | Should -Be 'EvidenceOnly'
        $pack.ValidationResults.ManagedIdentityStatus | Should -Be 'ManagedIdentityReadinessSatisfiedSimulationOnly'
        $pack.ValidationResults.MetadataStatus | Should -Be 'MetadataCleanupSatisfiedSimulationOnly'
    }

    It 'includes the known warning list and simulation-only evidence state' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.KnownWarnings.Count | Should -BeGreaterThan 0
        $pack.SafetyAssertions.LiveDeleteExecutable | Should -BeFalse
        $pack.SafetyAssertions.GraphWritePathAvailable | Should -BeFalse
    }

    It 'normalizes missing evidence to incomplete statuses' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) @()
        $pack.SnapshotCoverage.Present | Should -BeFalse
        $pack.ValidationResults.ManagedIdentityStatus | Should -Be 'Incomplete'
        $pack.ValidationResults.MetadataStatus | Should -Be 'Incomplete'
        $pack.ValidationResults.GrantsStatus | Should -Be 'Incomplete'
    }

    It 'keeps simulation-only flags false for live execution' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.FinalDeleteSimulationOnly | Should -BeTrue
        $pack.QAHandoffManifest.SafetyAssertions.FinalDeleteSimulationOnly | Should -BeTrue
        $pack.QAHandoffManifest.PushStatus | Should -Be 'No'
    }

    It 'preserves the QA handoff evidence artifact list' -ForEach @(
        @{ Index = 0; File = 'nhi-controlled-e2e-evidence-pack.json' }
        @{ Index = 1; File = 'nhi-controlled-qa-handoff-manifest.json' }
        @{ Index = 2; File = 'nhi-controlled-operator-decision-log.json' }
        @{ Index = 3; File = 'nhi-controlled-managed-identity-readiness.json' }
        @{ Index = 4; File = 'nhi-controlled-e2e-snapshot.json' }
    ) {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.QAHandoffManifest.EvidenceArtifacts[$Index] | Should -Be $File
    }

    It 'keeps the safety assertions false for live execution' -ForEach @(
        @{ Name = 'LiveDeleteExecutable'; Value = $false }
        @{ Name = 'LiveCleanupExecutable'; Value = $false }
        @{ Name = 'GraphWritePathAvailable'; Value = $false }
        @{ Name = 'FinalDeleteSimulationOnly'; Value = $true }
    ) {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.$Name | Should -Be $Value
    }

    It 'reports validation result fields individually' -ForEach @(
        @{ Name = 'ManagedIdentityStatus'; Value = 'ManagedIdentityReadinessSatisfiedSimulationOnly' }
        @{ Name = 'MetadataStatus'; Value = 'MetadataCleanupSatisfiedSimulationOnly' }
        @{ Name = 'GrantsStatus'; Value = 'GrantCleanupSatisfiedSimulationOnly' }
        @{ Name = 'DeleteReadinessStatus'; Value = 'Ready' }
    ) {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.ValidationResults.$Name | Should -Be $Value
    }

    It 'reports summary field <Name>' -ForEach @(
        @{ Name = 'PlanIdentity.TargetId'; Value = 'e2e-rev48-test-001' }
        @{ Name = 'PlanIdentity.TargetType'; Value = 'ManagedIdentity' }
        @{ Name = 'PlanIdentity.SchemaVersion'; Value = '4.8' }
        @{ Name = 'QAHandoffManifest.ToolVersion'; Value = 'Rev4.1' }
        @{ Name = 'QAHandoffManifest.KnownWarnings.Count'; Value = 1 }
        @{ Name = 'OperatorDecision.IsSimulationOnly'; Value = $true }
        @{ Name = 'ApprovalCoverage.Status'; Value = 'Approved' }
    ) {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings

        switch ($Name) {
            'PlanIdentity.TargetId' { $pack.PlanIdentity.TargetId | Should -Be $Value }
            'PlanIdentity.TargetType' { $pack.PlanIdentity.TargetType | Should -Be $Value }
            'PlanIdentity.SchemaVersion' { $pack.PlanIdentity.SchemaVersion | Should -Be $Value }
            'QAHandoffManifest.ToolVersion' { $pack.QAHandoffManifest.ToolVersion | Should -Be $Value }
            'QAHandoffManifest.KnownWarnings.Count' { $pack.QAHandoffManifest.KnownWarnings.Count | Should -Be $Value }
            'OperatorDecision.IsSimulationOnly' { $pack.OperatorDecisionState.IsSimulationOnly | Should -Be $Value }
            'ApprovalCoverage.Status' { $pack.ApprovalCoverage.Status | Should -Be $Value }
        }
    }

    It 'reports the snapshot hash from the pack' {
        $input = New-Rev48PackInput
        $pack = Invoke-Rev48Module {
            param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
            New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
        } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
        $pack.SnapshotCoverage.SHA256 | Should -Be $input.Snapshot.SHA256
    }
}
