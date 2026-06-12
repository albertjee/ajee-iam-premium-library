#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-production-readiness.sample.json'
    $script:EntryPointPath = Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

    $script:RawSample = Get-Content -LiteralPath $script:SamplePath -Raw
    $script:Sample = $script:RawSample | ConvertFrom-Json

    function New-Rev49Input {
        param([hashtable]$Overrides = @{})

        $input = [ordered]@{
            RunId = 'RUN-REV49-PROD-001'
            BranchName = 'feature/rev42-controlled-nhi-decommission'
            LatestCommit = '238e2ca5281b76decee87b14ab31883d8fd2efa9'
            GitStatusClean = $true
            FrozenFileDiffClean = $true
            Rev42PlannerEvidence = [PSCustomObject]@{ Status = 'Complete'; LocalOnly = $true }
            Rev43ServicePrincipalFinalDeleteSimulationEvidence = [PSCustomObject]@{ Status = 'Blocked'; SimulationOnly = $true; LiveDeleteExecutable = $false; LocalOnly = $true }
            Rev44ApplicationReadinessEvidence = [PSCustomObject]@{ Status = 'ReadinessSatisfiedSimulationOnly'; SimulationOnly = $true; LiveDeleteExecutable = $false; LocalOnly = $true }
            Rev45MetadataCleanupReadinessEvidence = [PSCustomObject]@{ Status = 'Ready'; SimulationOnly = $true; LiveCleanupExecutable = $false; LocalOnly = $true }
            Rev46GrantsCleanupReadinessEvidence = [PSCustomObject]@{ Status = 'Ready'; SimulationOnly = $true; LiveCleanupExecutable = $false; LocalOnly = $true }
            Rev47ManagedIdentityReadinessEvidence = [PSCustomObject]@{ Status = 'ManagedIdentityReadinessSatisfiedSimulationOnly'; SimulationOnly = $true; LiveCleanupExecutable = $false; LocalOnly = $true }
            Rev48E2EEvidencePackEvidence = [PSCustomObject]@{ Status = 'Approved'; SimulationOnly = $true; LiveDeleteExecutable = $false; LiveCleanupExecutable = $false; LocalOnly = $true }
            ExternalQaApprovalEvidence = [PSCustomObject]@{ Approved = $true; Status = 'Approved'; ApprovedBy = 'external-qa-approver@example.com'; ApprovalId = 'APP-REV49-PROD-001'; LocalOnly = $true }
            FullPesterEvidence = [PSCustomObject]@{ Passed = $true; Status = 'Passed'; LocalOnly = $true }
            SafetyScanEvidence = [PSCustomObject]@{ Passed = $true; Status = 'Passed'; LocalOnly = $true }
            FrozenFileDiffEvidence = [PSCustomObject]@{ Clean = $true; Status = 'Clean'; LocalOnly = $true }
            GitStatusEvidence = [PSCustomObject]@{ Clean = $true; Status = 'Clean'; LocalOnly = $true }
            P0Findings = @()
            P1Findings = @()
            P2Findings = @(
                [PSCustomObject]@{ Id = 'P2-REV49-001'; Title = 'Tighten empty evidence object guard'; Severity = 'P2'; Disposition = 'Documented'; Resolved = $true },
                [PSCustomObject]@{ Id = 'P2-REV49-002'; Title = 'Review non-MI default evidence synthesis'; Severity = 'P2'; Disposition = 'Documented'; Resolved = $true },
                [PSCustomObject]@{ Id = 'P2-REV49-003'; Title = 'Improve future delta QA ZIP portability'; Severity = 'P2'; Disposition = 'Documented'; Resolved = $true }
            )
            KnownWarnings = @(
                [PSCustomObject]@{ Warning = 'DemoMode traceability warning about $execEvidencePath not being set, if still present.'; Severity = 'Low'; Disposition = 'Documented'; Source = 'LegacyAssessmentPath' },
                [PSCustomObject]@{ Warning = 'Pester ConvertTo-DecomHtmlEncoded empty-string binding messages, if still present.'; Severity = 'Low'; Disposition = 'Documented'; Source = 'Pester' },
                [PSCustomObject]@{ Warning = 'Rev4.7/4.8 P2 follow-up: tighten empty evidence object guard.'; Severity = 'Medium'; Disposition = 'Open'; Source = 'Rev4.7' }
            )
            OperatorMergeDecision = [PSCustomObject]@{ Decision = 'ReadyForReview'; DecisionBy = 'local-planner'; DecisionAtUtc = '2099-01-01T00:00:00Z'; Reason = 'External QA and merge-gate evidence are present locally only.'; Scope = 'Rev4.9'; IsExecuting = $false }
        }

        foreach ($key in $Overrides.Keys) {
            $input[$key] = $Overrides[$key]
        }

        [PSCustomObject]$input
    }

    function Invoke-Rev49Module {
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

Describe 'Rev4.9 production readiness contract' {
    It 'keeps the private builders hidden and the export contract frozen' {
        Get-Command New-NhiControlledProductionReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command New-NhiControlledProductionReadinessEvidencePack -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        (Get-Module NhiControlledDecommission).ExportedCommands.Keys.Count | Should -Be 11
    }

    It 'advertises the Rev4.9 schema contract' {
        $schema = Get-NhiControlledDecommissionSchema
        $schema.ProductionReadinessSchemaVersion | Should -Be '4.9'
        $schema.ReleaseMergeGateSchemaVersion | Should -Be '4.9'
        $schema.KnownWarningInventorySchemaVersion | Should -Be '4.9'
        $schema.FinalSafetyAssertionSchemaVersion | Should -Be '4.9'
        $schema.SupportedStages | Should -Contain 'ProductionReadiness'
    }

    It 'parses the production readiness sample JSON' {
        $script:Sample | Should -Not -BeNullOrEmpty
        $script:Sample.SchemaVersion | Should -Be '4.9'
        $script:Sample.ApprovedActions[0] | Should -Be 'ProductionReadiness'
    }

    It 'keeps the sample free of secret-like fields and live delete commands' {
        $script:RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        $script:RawSample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az|Connect-MgGraph'
    }

    It 'records the expected branch, commit, and local-only evidence flags' {
        $script:Sample.BranchName | Should -Be 'feature/rev42-controlled-nhi-decommission'
        $script:Sample.LatestCommit | Should -Be '238e2ca5281b76decee87b14ab31883d8fd2efa9'
        $script:Sample.GitStatusClean | Should -BeTrue
        $script:Sample.FrozenFileDiffClean | Should -BeTrue
    }

    It 'builds a blocked gate when the input is empty' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } ([PSCustomObject]@{})
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.Status | Should -Be 'Blocked'
        $gate.RequiredEvidence.Rev42PlannerEvidence.Present | Should -BeFalse
    }

    It 'builds a ready-for-review gate with complete local evidence' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input)
        $gate.ProductionReadyForReview | Should -BeTrue
        $gate.Status | Should -Be 'ReadyForReview'
        $gate.ProductionExecutionEnabled | Should -BeFalse
        $gate.ProductionUnlockGranted | Should -BeFalse
    }

    It 'returns the required final safety assertions' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input)
        $gate.FinalSafetyAssertions.LiveDeleteExecutable | Should -BeFalse
        $gate.FinalSafetyAssertions.LiveCleanupExecutable | Should -BeFalse
        $gate.FinalSafetyAssertions.GraphWritePathAvailable | Should -BeFalse
        $gate.FinalSafetyAssertions.ArmWritePathAvailable | Should -BeFalse
        $gate.FinalSafetyAssertions.FinalDeleteSimulationOnly | Should -BeTrue
        $gate.FinalSafetyAssertions.RequiresManualApprovalForProduction | Should -BeTrue
        $gate.FinalSafetyAssertions.RequiresExternalQAForMerge | Should -BeTrue
    }

    It 'records the known warning inventory with severity and disposition' {
        $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
        $pack.KnownWarnings.Items.Count | Should -BeGreaterThan 3
        $pack.KnownWarnings.Items | ForEach-Object {
            $_.Severity | Should -Not -BeNullOrEmpty
            $_.Disposition | Should -Not -BeNullOrEmpty
        }
    }

    It 'produces the expected release manifest and merge gate states' {
        $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
        $pack.ReleaseManifest.PushStatus | Should -Be 'No'
        $pack.ReleaseManifest.MergeStatus | Should -Be 'ReadyForReview'
        $pack.MergeGate.MergeDecisionRecorded | Should -BeTrue
        $pack.MergeGate.MergeExecuted | Should -BeFalse
        $pack.MergeGate.PushPerformed | Should -BeFalse
        $pack.MergeGate.TagPerformed | Should -BeFalse
        $pack.MergeGate.DeleteBranchPerformed | Should -BeFalse
    }

    It 'records the expected branch and commit in the release manifest' {
        $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
        $pack.ReleaseManifest.BranchName | Should -Be 'feature/rev42-controlled-nhi-decommission'
        $pack.ReleaseManifest.LatestCommit | Should -Be '238e2ca5281b76decee87b14ab31883d8fd2efa9'
    }

    It 'marks production execution as disabled even when review-ready' {
        $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
        $pack.ProductionReadyForReview | Should -BeTrue
        $pack.ProductionExecutionEnabled | Should -BeFalse
        $pack.FinalDeleteSimulationOnly | Should -BeTrue
        $pack.FinalSafetyAssertions.ProductionExecutionEnabled | Should -BeFalse
        $pack.FinalSafetyAssertions.ProductionUnlockGranted | Should -BeFalse
    }

    It 'requires external QA approval evidence' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ ExternalQaApprovalEvidence = $null })
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.RequiredEvidence.ExternalQaApprovalEvidence.Present | Should -BeFalse
        $gate.RequiredEvidence.ExternalQaApprovalEvidence.Status | Should -Be 'Missing'
    }

    It 'requires full Pester evidence' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ FullPesterEvidence = $null })
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.RequiredEvidence.FullPesterEvidence.Present | Should -BeFalse
    }

    It 'requires safety scan evidence' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ SafetyScanEvidence = $null })
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.RequiredEvidence.SafetyScanEvidence.Present | Should -BeFalse
    }

    It 'requires frozen-file diff evidence' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ FrozenFileDiffEvidence = $null })
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.RequiredEvidence.FrozenFileDiffEvidence.Present | Should -BeFalse
    }

    It 'requires git status evidence' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ GitStatusEvidence = $null })
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.RequiredEvidence.GitStatusEvidence.Present | Should -BeFalse
    }

    It 'blocks unresolved P0 findings' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ P0Findings = @([PSCustomObject]@{ Id = 'P0-1'; Severity = 'P0'; Disposition = 'Open'; Resolved = $false }) })
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.P0Disposition.Blocked | Should -BeTrue
        $gate.P0Disposition.UnresolvedCount | Should -Be 1
    }

    It 'blocks unresolved P1 findings' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ P1Findings = @([PSCustomObject]@{ Id = 'P1-1'; Severity = 'P1'; Disposition = 'Open'; Resolved = $false }) })
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.P1Disposition.Blocked | Should -BeTrue
        $gate.P1Disposition.UnresolvedCount | Should -Be 1
    }

    It 'requires P2 findings to be documented with disposition' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ P2Findings = @([PSCustomObject]@{ Id = 'P2-1'; Severity = 'P2'; Resolved = $true }) })
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.P2Disposition.UnresolvedCount | Should -Be 1
    }

    It 'keeps live execution flags false in the final safety assertions' {
        $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
        $pack.FinalSafetyAssertions.LiveDeleteExecutable | Should -BeFalse
        $pack.FinalSafetyAssertions.LiveCleanupExecutable | Should -BeFalse
        $pack.FinalSafetyAssertions.GraphWritePathAvailable | Should -BeFalse
        $pack.FinalSafetyAssertions.ArmWritePathAvailable | Should -BeFalse
    }

    It 'records operator merge decision without executing it' {
        $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
        $pack.OperatorMergeDecision.Decision | Should -Be 'ReadyForReview'
        $pack.OperatorMergeDecision.IsExecuting | Should -BeFalse
    }

    It 'keeps the merge gate documentation-only' {
        $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
        $pack.MergeGate.ManualApprovalRequired | Should -BeTrue
        $pack.MergeGate.ExternalQARequired | Should -BeTrue
        $pack.MergeGate.DeleteBranchPerformed | Should -BeFalse
        $pack.MergeGate.TagPerformed | Should -BeFalse
    }

    It 'keeps production unlock disabled' {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input)
        $gate.FinalSafetyAssertions.ProductionUnlockGranted | Should -BeFalse
        $gate.FinalSafetyAssertions.ProductionExecutionEnabled | Should -BeFalse
    }

    It 'normalizes the sample warning inventory' {
        $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
        ($pack.KnownWarnings.Items | Where-Object { $_.Warning -match 'DemoMode traceability warning' }).Severity | Should -Be 'Low'
        ($pack.KnownWarnings.Items | Where-Object { $_.Warning -match 'empty-string binding messages' }).Disposition | Should -Be 'Documented'
    }

    It 'exports the production readiness evidence pack through the entry point' {
        $outputPath = Join-Path $TestDrive 'rev49-output'
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPointPath -ExecuteNhiControlledDecommission -ExecutionStage ProductionReadiness -DecommissionPlanPath $script:SamplePath -ApprovalManifestPath $script:SamplePath -WhatIfExecution -OutputPath $outputPath 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Rev4\.9 production readiness guardrails completed'
        ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
        @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'controlled-decommission-RUN-REV49-PROD-001') -File).Count | Should -Be 6
    }

    It 'supports DemoMode simulation only through the entry point' {
        $outputPath = Join-Path $TestDrive 'rev49-demo'
        $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPointPath -ExecuteNhiControlledDecommission -ExecutionStage ProductionReadiness -DecommissionPlanPath $script:SamplePath -ApprovalManifestPath $script:SamplePath -DemoMode -OutputPath $outputPath 2>&1
        $LASTEXITCODE | Should -Be 0
        ($output -join "`n") | Should -Match 'Rev4\.9 production readiness guardrails completed'
        ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
    }

    It 'keeps SelfTest before the controlled Graph connection path' {
        $source = Get-Content -LiteralPath $script:EntryPointPath -Raw
        $source.IndexOf('# SelfTest early exit - no Graph connection, discovery, or remediation') | Should -BeLessThan $source.IndexOf('Connect-MgGraph')
    }

    It 'writes JSON artifacts that parse cleanly' {
        $outputPath = Join-Path $TestDrive 'rev49-json'
        $null = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPointPath -ExecuteNhiControlledDecommission -ExecutionStage ProductionReadiness -DecommissionPlanPath $script:SamplePath -ApprovalManifestPath $script:SamplePath -WhatIfExecution -OutputPath $outputPath 2>&1
        $artifactPath = Join-Path $outputPath 'controlled-decommission-RUN-REV49-PROD-001\nhi-controlled-production-readiness.json'
        (Get-Content -LiteralPath $artifactPath -Raw | ConvertFrom-Json).SchemaVersion | Should -Be '4.9'
    }

    It 'keeps default Assessment out of the controlled readiness path' {
        $script:Source = Get-Content -LiteralPath $script:EntryPointPath -Raw
        $script:Source | Should -Match '# Rev4\.2-S1 controlled NHI decommission planner/evidence flow'
        $script:Source | Should -Not -Match 'if \(\$Mode -eq ''Assessment''.*ProductionReadiness'
    }
}

Describe 'Rev4.9 missing evidence blocks readiness' {
    It 'blocks <Name>' -ForEach @(
        @{ Name = 'missing Rev4.2 evidence'; Build = { New-Rev49Input -Overrides @{ Rev42PlannerEvidence = $null } }; Pattern = 'Rev42PlannerEvidence is required' }
        @{ Name = 'missing Rev4.3 evidence'; Build = { New-Rev49Input -Overrides @{ Rev43ServicePrincipalFinalDeleteSimulationEvidence = $null } }; Pattern = 'Rev43ServicePrincipalFinalDeleteSimulationEvidence is required' }
        @{ Name = 'missing Rev4.4 evidence'; Build = { New-Rev49Input -Overrides @{ Rev44ApplicationReadinessEvidence = $null } }; Pattern = 'Rev44ApplicationReadinessEvidence is required' }
        @{ Name = 'missing Rev4.5 evidence'; Build = { New-Rev49Input -Overrides @{ Rev45MetadataCleanupReadinessEvidence = $null } }; Pattern = 'Rev45MetadataCleanupReadinessEvidence is required' }
        @{ Name = 'missing Rev4.6 evidence'; Build = { New-Rev49Input -Overrides @{ Rev46GrantsCleanupReadinessEvidence = $null } }; Pattern = 'Rev46GrantsCleanupReadinessEvidence is required' }
        @{ Name = 'missing Rev4.7 evidence'; Build = { New-Rev49Input -Overrides @{ Rev47ManagedIdentityReadinessEvidence = $null } }; Pattern = 'Rev47ManagedIdentityReadinessEvidence is required' }
        @{ Name = 'missing Rev4.8 evidence'; Build = { New-Rev49Input -Overrides @{ Rev48E2EEvidencePackEvidence = $null } }; Pattern = 'Rev48E2EEvidencePackEvidence is required' }
        @{ Name = 'missing external QA evidence'; Build = { New-Rev49Input -Overrides @{ ExternalQaApprovalEvidence = $null } }; Pattern = 'ExternalQaApprovalEvidence is required' }
        @{ Name = 'missing full Pester evidence'; Build = { New-Rev49Input -Overrides @{ FullPesterEvidence = $null } }; Pattern = 'FullPesterEvidence is required' }
        @{ Name = 'missing safety scan evidence'; Build = { New-Rev49Input -Overrides @{ SafetyScanEvidence = $null } }; Pattern = 'SafetyScanEvidence is required' }
        @{ Name = 'missing frozen diff evidence'; Build = { New-Rev49Input -Overrides @{ FrozenFileDiffEvidence = $null } }; Pattern = 'FrozenFileDiffEvidence is required' }
        @{ Name = 'missing git status evidence'; Build = { New-Rev49Input -Overrides @{ GitStatusEvidence = $null } }; Pattern = 'GitStatusEvidence is required' }
    ) {
        $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (& $Build)
        $gate.ProductionReadyForReview | Should -BeFalse
        $gate.Status | Should -Be 'Blocked'
        $gate.Reasons -join ' ' | Should -Match $Pattern
    }
}
