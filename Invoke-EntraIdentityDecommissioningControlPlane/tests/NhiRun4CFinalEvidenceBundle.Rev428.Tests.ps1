$ErrorActionPreference = 'Stop'

function script:New-TestTarget {
    [pscustomobject]@{
        ObjectId = '11111111-1111-1111-1111-111111111111'
        DisplayName = 'Lab Reversible NHI'
        AppId = '22222222-2222-2222-2222-222222222222'
        ObjectType = 'ServicePrincipal'
        TargetType = 'ServicePrincipal'
        Classification = 'CustomerOwned'
        Environment = 'Lab'
        TenantScope = 'Lab'
        IsLabTarget = $true
        LabTargetMarker = $true
        SuppressCustomerRemediation = $false
        EvidenceOnly = $false
        InformationOnly = $false
        RemediationMode = 'ManualApprovalRequired'
    }
}

function script:New-TestPackage {
    param([string]$Name,[hashtable]$Extra)
    $package = [ordered]@{ OutputArtifactPath = Join-Path $TestDrive "$Name.json" }
    foreach ($k in $Extra.Keys) { $package[$k] = $Extra[$k] }
    [pscustomobject]$package
}

Describe 'Rev4.28 Final End-to-End Evidence Bundle / Consultant QA Package' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev428'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:Target = @(New-TestTarget)
        $script:Rev410 = New-TestPackage -Name 'rev410' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev410.json'); Platform = 'MicrosoftPlatform' }
        $script:Rev411 = New-TestPackage -Name 'rev411' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev411.json'); Ready = $true }
        $script:Rev412 = New-TestPackage -Name 'rev412' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev412.json'); Ready = $true }
        $script:Rev413 = New-TestPackage -Name 'rev413' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev413.json'); Ready = $true }
        $script:Rev414 = New-TestPackage -Name 'rev414' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev414.json'); Ready = $true }
        $script:Rev415 = New-TestPackage -Name 'rev415' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev415.json'); Ready = $true }
        $script:Rev416 = New-TestPackage -Name 'rev416' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev416.json'); GoNoGo = 'Go' }
        $script:Rev417 = New-TestPackage -Name 'rev417' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev417.json'); Ready = $true }
        $script:Rev418 = New-TestPackage -Name 'rev418' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev418.json'); Ready = $true }
        $script:Rev419 = New-TestPackage -Name 'rev419' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev419.json'); RollbackReadiness = 'Ready' }
        $script:Rev420 = New-TestPackage -Name 'rev420' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev420.json'); RollbackReadiness = 'Ready' }
        $script:Rev421 = New-TestPackage -Name 'rev421' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev421.json'); FinalDeleteEligibility = 'Eligible' }
        $script:Rev422 = New-TestPackage -Name 'rev422' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev422.json'); RehearsalStatus = 'Complete' }
        $script:Rev423 = New-TestPackage -Name 'rev423' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev423.md'); GuideId = 'REV423' }
        $script:Rev424 = New-TestPackage -Name 'rev424' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev424.json'); PackageStatus = 'ReadyForHumanReview' }
        $script:Rev425 = New-TestPackage -Name 'rev425' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev425.json'); PostDisableValidationStatus = 'Passed' }
        $script:Rev426 = New-TestPackage -Name 'rev426' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev426.json'); PackageStatus = 'ReadyForHumanRollbackReview' }
        $script:Rev427 = New-TestPackage -Name 'rev427' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rev427.json'); PostRollbackValidationStatus = 'Passed' }
        $script:MarkdownPath = Join-Path $TestDrive 'rev428.md'
    }

    It 'Complete artifact chain creates final evidence bundle' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev410PlatformClassificationEvidence $script:Rev410 -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-OK' -MarkdownOutputPath $script:MarkdownPath
        $result.ChainComplete | Should -BeTrue
        $result.RequiredArtifactsPresent | Should -BeTrue
        $result.SafetyAssertionsPassed | Should -BeTrue
        $result.FinalDeleteExcluded | Should -BeTrue
        $result.ProductionTenantExcluded | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).EvidenceBundleId | Should -Match '^REV428-'
    }

    It 'Optional Markdown writes if implemented' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-MD' -MarkdownOutputPath $script:MarkdownPath
        Test-Path -LiteralPath $result.MarkdownArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:MarkdownPath | Should -BeTrue
    }

    It 'Missing Rev4.24 package makes chain incomplete' { (New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $null -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-1').ChainComplete | Should -BeFalse }
    It 'Missing Rev4.25 package makes chain incomplete' { (New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $null -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-2').ChainComplete | Should -BeFalse }
    It 'Missing Rev4.26 package makes chain incomplete' { (New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $null -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-3').ChainComplete | Should -BeFalse }
    It 'Missing Rev4.27 package makes chain incomplete' { (New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $null -OutputPath $script:OutputPath -RunId 'REV428-4').ChainComplete | Should -BeFalse }

    It 'Bundle states no tenant write by bundle' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-5'
        $result.TenantWritePerformedByBundle | Should -BeFalse
        $result.DisablePerformedByBundle | Should -BeFalse
        $result.RollbackPerformedByBundle | Should -BeFalse
        $result.DeletePerformedByBundle | Should -BeFalse
    }

    It 'Bundle contains consultant summary' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-6'
        $result.ConsultantSummary.WhatWasProven | Should -Not -BeNullOrEmpty
        $result.ConsultantSummary.WhatWasNotProven | Should -Not -BeNullOrEmpty
    }

    It 'Bundle contains no secrets or live credentials' {
        $result = New-NhiRun4CFinalEvidenceBundle -Target $script:Target -Rev411PlanningProof $script:Rev411 -Rev412ReadinessGate $script:Rev412 -Rev413DryRunPackage $script:Rev413 -Rev414RollbackDrillPackage $script:Rev414 -Rev415ControlledDisablePathPackage $script:Rev415 -Rev416FinalGoNoGoReviewPackage $script:Rev416 -Rev417EvidenceCapturePackage $script:Rev417 -Rev418ObservationPackage $script:Rev418 -Rev419RollbackReadinessPackage $script:Rev419 -Rev420RollbackPreviewPackage $script:Rev420 -Rev421FinalDeleteSimulationPackage $script:Rev421 -Rev422RehearsalReport $script:Rev422 -Rev423ConsultantGuide $script:Rev423 -Rev424FinalControlledDisableTestPackage $script:Rev424 -Rev425PostDisableValidationPackage $script:Rev425 -Rev426RollbackExecutionTestPackage $script:Rev426 -Rev427PostRollbackValidationPackage $script:Rev427 -OutputPath $script:OutputPath -RunId 'REV428-7'
        $result.ContainedSecrets | Should -BeFalse
    }
}
