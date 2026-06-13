$ErrorActionPreference = 'Stop'

function global:Write-TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $Path -Encoding utf8
}

function global:New-TestTarget {
    param(
        [string]$Classification = 'CustomerOwned',
        [string]$Environment = 'Lab',
        [bool]$SuppressCustomerRemediation = $false,
        [bool]$EvidenceOnly = $false
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
        InformationOnly = $false
        RemediationMode = 'ManualApprovalRequired'
    }
}

function global:New-TestPackage {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [hashtable]$Extra
    )

    $path = Join-Path $TestDrive "$Name.json"
    $package = [ordered]@{
        OutputArtifactPath = $path
    }
    foreach ($key in $Extra.Keys) {
        $package[$key] = $Extra[$key]
    }
    [pscustomobject]$package
}

function global:Invoke-RehearsalReport {
    param(
        [object]$Target = $null,
        [object]$ApprovalManifest = $null,
        [object]$Snapshot = $null,
        [object]$ReadinessVerdict = $null,
        [object]$DryRunPackage = $null,
        [object]$RollbackDrillPackage = $null,
        [object]$ControlledDisablePackage = $null,
        [object]$FinalGoNoGoPackage = $null,
        [object]$EvidenceCapturePackage = $null,
        [object]$ObservationPackage = $null,
        [object]$RollbackReadinessPackage = $null,
        [object]$RollbackPreviewPackage = $null,
        [object]$FinalDeleteSimulationPackage = $null,
        [string]$RunId = 'REV422-001',
        [string]$MarkdownOutputPath = $null
    )

    if (-not $PSBoundParameters.ContainsKey('Target')) { $Target = New-TestTarget }
    if (-not $PSBoundParameters.ContainsKey('ApprovalManifest')) { $ApprovalManifest = New-TestPackage -Name 'approval' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('Snapshot')) { $Snapshot = New-TestPackage -Name 'snapshot' -Extra @{ SnapshotPath = (Join-Path $TestDrive 'snapshot.json'); Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('ReadinessVerdict')) { $ReadinessVerdict = New-TestPackage -Name 'readiness' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('DryRunPackage')) { $DryRunPackage = New-TestPackage -Name 'dryrun' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('RollbackDrillPackage')) { $RollbackDrillPackage = New-TestPackage -Name 'rollbackdrill' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('ControlledDisablePackage')) { $ControlledDisablePackage = New-TestPackage -Name 'disable' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('FinalGoNoGoPackage')) { $FinalGoNoGoPackage = New-TestPackage -Name 'gono' -Extra @{ GoNoGo = 'Go' } }
    if (-not $PSBoundParameters.ContainsKey('EvidenceCapturePackage')) { $EvidenceCapturePackage = New-TestPackage -Name 'evidence' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('ObservationPackage')) { $ObservationPackage = New-TestPackage -Name 'observation' -Extra @{ Ready = $true } }
    if (-not $PSBoundParameters.ContainsKey('RollbackReadinessPackage')) { $RollbackReadinessPackage = New-TestPackage -Name 'rollbackreadiness' -Extra @{ RollbackReadiness = 'Ready' } }
    if (-not $PSBoundParameters.ContainsKey('RollbackPreviewPackage')) { $RollbackPreviewPackage = New-TestPackage -Name 'rollbackpreview' -Extra @{ RollbackReadiness = 'Ready' } }
    if (-not $PSBoundParameters.ContainsKey('FinalDeleteSimulationPackage')) { $FinalDeleteSimulationPackage = New-TestPackage -Name 'finaldelete' -Extra @{ FinalDeleteEligibility = 'Eligible' } }

    foreach ($pkg in @($ApprovalManifest, $Snapshot, $ReadinessVerdict, $DryRunPackage, $RollbackDrillPackage, $ControlledDisablePackage, $FinalGoNoGoPackage, $EvidenceCapturePackage, $ObservationPackage, $RollbackReadinessPackage, $RollbackPreviewPackage, $FinalDeleteSimulationPackage)) {
        if ($null -eq $pkg -or [string]::IsNullOrWhiteSpace($pkg.OutputArtifactPath)) {
            continue
        }

        Write-TestJson -Path $pkg.OutputArtifactPath -InputObject $pkg
    }

    New-NhiRun4CEndToEndLabRehearsalReport `
        -Target @($Target) `
        -ApprovalManifest $ApprovalManifest `
        -Snapshot $Snapshot `
        -ReadinessVerdict $ReadinessVerdict `
        -DryRunPackage $DryRunPackage `
        -RollbackDrillPackage $RollbackDrillPackage `
        -ControlledDisablePackage $ControlledDisablePackage `
        -FinalGoNoGoPackage $FinalGoNoGoPackage `
        -EvidenceCapturePackage $EvidenceCapturePackage `
        -ObservationPackage $ObservationPackage `
        -RollbackReadinessPackage $RollbackReadinessPackage `
        -RollbackPreviewPackage $RollbackPreviewPackage `
        -FinalDeleteSimulationPackage $FinalDeleteSimulationPackage `
        -RunId $RunId `
        -OutputPath $script:OutputPath `
        -MarkdownOutputPath $MarkdownOutputPath
}

Describe 'Rev4.22 End-to-End Lab Rehearsal Report' {
    BeforeAll {
        if ([string]::IsNullOrWhiteSpace($PSScriptRoot)) {
            throw 'PSScriptRoot is not available for this test harness.'
        }

        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        if (-not (Test-Path -LiteralPath $script:modulePath)) {
            throw "Required module not found: $script:modulePath"
        }

        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev422'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:MarkdownPath = Join-Path $TestDrive 'rev422-report.md'
        $script:BlockedMicrosoft = New-TestTarget -Classification 'MicrosoftPlatform'
        $script:BlockedSuppressed = New-TestTarget -SuppressCustomerRemediation $true
        $script:BlockedEvidenceOnly = New-TestTarget -EvidenceOnly $true
    }

    It 'Complete artifact chain generates rehearsal report' {
        $result = Invoke-RehearsalReport -MarkdownOutputPath $script:MarkdownPath

        $result.RehearsalStatus | Should -Be 'Complete'
        $result.ReadyForFinalControlledDevTestDisable | Should -BeTrue
        $result.RequiredHumanDecision | Should -BeTrue
        $result.HumanDecisionCaptured | Should -BeFalse
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.DeletePerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.OperatorChecklistSummary.PassedCount | Should -Be 11
        $result.OperatorChecklistSummary.FailedCount | Should -Be 0
        $result.OperatorChecklistSummary.PendingCount | Should -Be 0
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $result.MarkdownArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:MarkdownPath | Should -BeTrue
    }

    It 'Report writes JSON artifact locally' {
        $result = Invoke-RehearsalReport -RunId 'REV422-ARTIFACT'
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).ReportId | Should -Match '^REV422-'
    }

    It 'Optional Markdown artifact writes if implemented' {
        $result = Invoke-RehearsalReport -RunId 'REV422-MD' -MarkdownOutputPath $script:MarkdownPath
        Test-Path -LiteralPath $result.MarkdownArtifactPath | Should -BeTrue
        Test-Path -LiteralPath $script:MarkdownPath | Should -BeTrue
    }

    It 'Report states TenantWritePerformed=false' {
        (Invoke-RehearsalReport).TenantWritePerformed | Should -BeFalse
    }

    It 'Report states DisablePerformed=false' {
        (Invoke-RehearsalReport).DisablePerformed | Should -BeFalse
    }

    It 'Report states RollbackPerformed=false' {
        (Invoke-RehearsalReport).RollbackPerformed | Should -BeFalse
    }

    It 'Report states DeletePerformed=false' {
        (Invoke-RehearsalReport).DeletePerformed | Should -BeFalse
    }

    It 'Report states FinalDeleteAllowed=false' {
        (Invoke-RehearsalReport).FinalDeleteAllowed | Should -BeFalse
    }

    It 'Missing readiness package makes report Incomplete' {
        (Invoke-RehearsalReport -ReadinessVerdict $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing dry-run package makes report Incomplete' {
        (Invoke-RehearsalReport -DryRunPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing rollback drill package makes report Incomplete' {
        (Invoke-RehearsalReport -RollbackDrillPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing go/no-go package makes report Incomplete' {
        (Invoke-RehearsalReport -FinalGoNoGoPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing evidence capture package makes report Incomplete' {
        (Invoke-RehearsalReport -EvidenceCapturePackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing observation package makes report Incomplete' {
        (Invoke-RehearsalReport -ObservationPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing rollback readiness package makes report Incomplete' {
        (Invoke-RehearsalReport -RollbackReadinessPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing rollback preview package makes report Incomplete' {
        (Invoke-RehearsalReport -RollbackPreviewPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Missing final delete simulation package makes report Incomplete' {
        (Invoke-RehearsalReport -FinalDeleteSimulationPackage $null).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'MicrosoftPlatform target is blocked' {
        (Invoke-RehearsalReport -Target $script:BlockedMicrosoft).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'Suppressed target is blocked' {
        (Invoke-RehearsalReport -Target $script:BlockedSuppressed).RehearsalStatus | Should -Be 'Incomplete'
    }

    It 'EvidenceOnly target is blocked' {
        (Invoke-RehearsalReport -Target $script:BlockedEvidenceOnly).RehearsalStatus | Should -Be 'Incomplete'
    }
}
