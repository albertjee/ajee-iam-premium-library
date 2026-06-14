$ErrorActionPreference = 'Stop'

function script:Write-Rev424TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 40) | Set-Content -LiteralPath $Path -Encoding utf8
}

function script:New-Rev424TestTarget {
    param(
        [string]$Classification = 'CustomerOwned',
        [string]$Environment = 'Lab',
        [bool]$SuppressCustomerRemediation = $false,
        [bool]$EvidenceOnly = $false,
        [bool]$InformationOnly = $false
    )

    [pscustomobject]@{
        ObjectId = '11111111-1111-1111-1111-111111111111'
        DisplayName = 'Lab Reversible NHI'
        AppId = '22222222-2222-2222-2222-222222222222'
        ObjectType = 'ServicePrincipal'
        TargetType = 'ServicePrincipal'
        Classification = $Classification
        Environment = $Environment
        TenantScope = $Environment
        IsLabTarget = $true
        LabTargetMarker = $true
        SuppressCustomerRemediation = $SuppressCustomerRemediation
        EvidenceOnly = $EvidenceOnly
        InformationOnly = $InformationOnly
        RemediationMode = if ($InformationOnly) { 'InformationOnly' } else { 'ManualApprovalRequired' }
    }
}

function script:New-Rev424TestPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Extra
    )

    $package = [ordered]@{
        OutputArtifactPath = Join-Path $TestDrive "$Name.json"
    }
    foreach ($key in $Extra.Keys) {
        $package[$key] = $Extra[$key]
    }

    [pscustomobject]$package
}

function script:Invoke-Rev424Package {
    param(
        [object]$Target = $null,
        [object]$ApprovalManifest = $null,
        [object]$PreActionSnapshot = $null,
        [object]$ReadinessVerdict = $null,
        [object]$DryRunPackage = $null,
        [object]$RollbackDrillPackage = $null,
        [object]$ControlledDisablePreview = $null,
        [object]$FinalGoNoGoReviewPackage = $null,
        [object]$EvidenceCapturePackage = $null,
        [object]$ObservationPackage = $null,
        [object]$RollbackReadinessPackage = $null,
        [object]$RollbackPreviewPackage = $null,
        [object]$FinalDeleteSimulationPackage = $null,
        [object]$EndToEndRehearsalReport = $null,
        [object]$ConsultantOperatingGuide = $null,
        [bool]$HumanGoNoGoCaptured = $false,
        [string[]]$RequestedOperations = @('ReversibleDisable'),
        [string]$RunId = 'REV424-001'
    )

    if (-not $PSBoundParameters.ContainsKey('Target')) { $Target = @(New-Rev424TestTarget) }
    if (-not $PSBoundParameters.ContainsKey('ApprovalManifest')) { $ApprovalManifest = New-Rev424TestPackage -Name 'approval' -Extra @{ ApprovalManifestPath = (Join-Path $TestDrive 'approval.json'); ApprovedAction = 'ReversibleDisable'; ApprovalExpiresUtc = ([datetime]::UtcNow.AddDays(1).ToString('o')); TargetObjectId = '11111111-1111-1111-1111-111111111111' } }
    if (-not $PSBoundParameters.ContainsKey('PreActionSnapshot')) { $PreActionSnapshot = New-Rev424TestPackage -Name 'snapshot' -Extra @{ SnapshotPath = (Join-Path $TestDrive 'snapshot.json'); AccountEnabled = $true } }
    if (-not $PSBoundParameters.ContainsKey('ReadinessVerdict')) { $ReadinessVerdict = New-Rev424TestPackage -Name 'readiness' -Extra @{ Ready = $true; Readiness = 'Ready' } }
    if (-not $PSBoundParameters.ContainsKey('DryRunPackage')) { $DryRunPackage = New-Rev424TestPackage -Name 'dryrun' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'dryrun.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('RollbackDrillPackage')) { $RollbackDrillPackage = New-Rev424TestPackage -Name 'rollbackdrill' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rollbackdrill.json'); Ready = $true; RollbackAction = 'ReEnableServicePrincipal' } }
    if (-not $PSBoundParameters.ContainsKey('ControlledDisablePreview')) { $ControlledDisablePreview = New-Rev424TestPackage -Name 'disablepreview' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'disablepreview.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('FinalGoNoGoReviewPackage')) { $FinalGoNoGoReviewPackage = New-Rev424TestPackage -Name 'gono' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'gono.json'); GoNoGo = 'Go' } }
    if (-not $PSBoundParameters.ContainsKey('EvidenceCapturePackage')) { $EvidenceCapturePackage = New-Rev424TestPackage -Name 'evidence' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'evidence.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('ObservationPackage')) { $ObservationPackage = New-Rev424TestPackage -Name 'observation' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'observation.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('RollbackReadinessPackage')) { $RollbackReadinessPackage = New-Rev424TestPackage -Name 'rollbackreadiness' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rollbackreadiness.json'); RollbackReadiness = 'Ready' } }
    if (-not $PSBoundParameters.ContainsKey('RollbackPreviewPackage')) { $RollbackPreviewPackage = New-Rev424TestPackage -Name 'rollbackpreview' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rollbackpreview.json'); RollbackAction = 'ReEnableServicePrincipal' } }
    if (-not $PSBoundParameters.ContainsKey('FinalDeleteSimulationPackage')) { $FinalDeleteSimulationPackage = New-Rev424TestPackage -Name 'finaldelete' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'finaldelete.json'); FinalDeleteEligibility = 'Eligible' } }
    if (-not $PSBoundParameters.ContainsKey('EndToEndRehearsalReport')) { $EndToEndRehearsalReport = New-Rev424TestPackage -Name 'rehearsal' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'rehearsal.json'); RehearsalStatus = 'Complete' } }
    if (-not $PSBoundParameters.ContainsKey('ConsultantOperatingGuide')) { $ConsultantOperatingGuide = New-Rev424TestPackage -Name 'guide' -Extra @{ OutputArtifactPath = (Join-Path $TestDrive 'guide.md'); GuideId = 'REV423' } }

    New-NhiRun4CFinalControlledDisableTestPackage `
        -Target $Target `
        -ApprovalManifest $ApprovalManifest `
        -PreActionSnapshot $PreActionSnapshot `
        -ReadinessVerdict $ReadinessVerdict `
        -DryRunPackage $DryRunPackage `
        -RollbackDrillPackage $RollbackDrillPackage `
        -ControlledDisablePreview $ControlledDisablePreview `
        -FinalGoNoGoReviewPackage $FinalGoNoGoReviewPackage `
        -EvidenceCapturePackage $EvidenceCapturePackage `
        -ObservationPackage $ObservationPackage `
        -RollbackReadinessPackage $RollbackReadinessPackage `
        -RollbackPreviewPackage $RollbackPreviewPackage `
        -FinalDeleteSimulationPackage $FinalDeleteSimulationPackage `
        -EndToEndRehearsalReport $EndToEndRehearsalReport `
        -ConsultantOperatingGuide $ConsultantOperatingGuide `
        -HumanGoNoGoCaptured $HumanGoNoGoCaptured `
        -RequestedOperations $RequestedOperations `
        -RunId $RunId `
        -OutputPath $script:OutputPath
}

Describe 'Rev4.24 Final Controlled Dev/Test Tenant Reversible Disable Test Package' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev424'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:BlockedMicrosoft = New-Rev424TestTarget -Classification 'MicrosoftPlatform'
        $script:BlockedExternal = New-Rev424TestTarget -Classification 'ExternalVendorPlatform'
        $script:BlockedSuppressed = New-Rev424TestTarget -SuppressCustomerRemediation $true
        $script:BlockedEvidenceOnly = New-Rev424TestTarget -EvidenceOnly $true
        $script:BlockedInformationOnly = New-Rev424TestTarget -InformationOnly $true
    }

    It 'Complete artifact chain creates final controlled disable test package' {
        $result = Invoke-Rev424Package

        $result.PackageStatus | Should -Be 'ReadyForHumanReview'
        $result.RequiredHumanDecision | Should -BeTrue
        $result.HumanDecisionCaptured | Should -BeFalse
        $result.ReadyForControlledDevTestDisable | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = Invoke-Rev424Package -RunId 'REV424-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).FinalTestPackageId | Should -Match '^REV424-'
    }

    It 'Package states TenantWritePerformed=false and DisablePerformed=false' {
        $result = Invoke-Rev424Package
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
    }

    It 'Package requires exactly one target' {
        (Invoke-Rev424Package -Target @()).PackageStatus | Should -Be 'NotReady'
    }

    It 'Missing approval manifest returns NotReady' { (Invoke-Rev424Package -ApprovalManifest $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing snapshot returns NotReady' { (Invoke-Rev424Package -PreActionSnapshot $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing readiness verdict returns NotReady' { (Invoke-Rev424Package -ReadinessVerdict $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing dry-run package returns NotReady' { (Invoke-Rev424Package -DryRunPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback drill package returns NotReady' { (Invoke-Rev424Package -RollbackDrillPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing go/no-go package returns NotReady' { (Invoke-Rev424Package -FinalGoNoGoReviewPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing evidence capture package returns NotReady' { (Invoke-Rev424Package -EvidenceCapturePackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing observation package returns NotReady' { (Invoke-Rev424Package -ObservationPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback readiness package returns NotReady' { (Invoke-Rev424Package -RollbackReadinessPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing rollback preview package returns NotReady' { (Invoke-Rev424Package -RollbackPreviewPackage $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing rehearsal report returns NotReady' { (Invoke-Rev424Package -EndToEndRehearsalReport $null).PackageStatus | Should -Be 'NotReady' }
    It 'Missing consultant guide returns NotReady' { (Invoke-Rev424Package -ConsultantOperatingGuide $null).PackageStatus | Should -Be 'NotReady' }
    It 'MicrosoftPlatform target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedMicrosoft)).PackageStatus | Should -Be 'NotReady' }
    It 'MicrosoftPlatform boolean target with CustomerOwned classification is blocked' {
        $target = New-Rev424TestTarget -Classification 'CustomerOwned'
        $target | Add-Member -NotePropertyName MicrosoftPlatform -NotePropertyValue $true -Force
        (Invoke-Rev424Package -Target @($target)).PackageStatus | Should -Be 'NotReady'
    }
    It 'FirstPartyMicrosoftApp boolean target with CustomerOwned classification is blocked' {
        $target = New-Rev424TestTarget -Classification 'CustomerOwned'
        $target | Add-Member -NotePropertyName FirstPartyMicrosoftApp -NotePropertyValue $true -Force
        (Invoke-Rev424Package -Target @($target)).PackageStatus | Should -Be 'NotReady'
    }
    It 'InformationOnly boolean target is blocked' {
        $target = New-Rev424TestTarget -Classification 'CustomerOwned'
        $target | Add-Member -NotePropertyName InformationOnly -NotePropertyValue $true -Force
        $target | Add-Member -NotePropertyName RemediationMode -NotePropertyValue 'ManualApprovalRequired' -Force
        (Invoke-Rev424Package -Target @($target)).PackageStatus | Should -Be 'NotReady'
    }
    It 'ExternalVendorPlatform target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedExternal)).PackageStatus | Should -Be 'NotReady' }
    It 'Suppressed target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedSuppressed)).PackageStatus | Should -Be 'NotReady' }
    It 'EvidenceOnly target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedEvidenceOnly)).PackageStatus | Should -Be 'NotReady' }
    It 'InformationOnly target is blocked' { (Invoke-Rev424Package -Target @($script:BlockedInformationOnly)).PackageStatus | Should -Be 'NotReady' }
    It 'Final delete request is blocked' { (Invoke-Rev424Package -RequestedOperations @('FinalDelete')).PackageStatus | Should -Be 'NotReady' }
    It 'Remove request is blocked' { (Invoke-Rev424Package -RequestedOperations @('Remove')).PackageStatus | Should -Be 'NotReady' }
    It 'Grant cleanup request is blocked' { (Invoke-Rev424Package -RequestedOperations @('GrantCleanup')).PackageStatus | Should -Be 'NotReady' }
    It 'Metadata cleanup request is blocked' { (Invoke-Rev424Package -RequestedOperations @('MetadataCleanup')).PackageStatus | Should -Be 'NotReady' }
    It 'Credential deletion request is blocked' { (Invoke-Rev424Package -RequestedOperations @('CredentialDelete')).PackageStatus | Should -Be 'NotReady' }

    It 'Live command block is emitted only as a template and is marked DO NOT RUN' {
        $result = Invoke-Rev424Package
        $result.LiveCommandBlockTemplate | Should -Match 'DO NOT RUN WITHOUT FINAL HUMAN GO/NO-GO'
        $result.LiveCommandBlockTemplate | Should -Match 'Template only'
    }

    It 'Human go/no-go is required and not auto-captured' {
        $result = Invoke-Rev424Package
        $result.HumanGoNoGoRequired | Should -BeTrue
        $result.HumanGoNoGoCaptured | Should -BeFalse
    }
}
