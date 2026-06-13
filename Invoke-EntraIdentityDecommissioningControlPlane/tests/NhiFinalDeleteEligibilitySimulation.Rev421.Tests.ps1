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

function global:New-TestDisableEvidence {
    [pscustomobject]@{
        PlannedAction = 'ReversibleDisable'
        OutputArtifactPath = Join-Path $TestDrive 'final-delete-disable-evidence.json'
    }
}

function global:New-TestObservation {
    [pscustomobject]@{
        ObservationWindowMinutes = 60
        OutputArtifactPath = Join-Path $TestDrive 'final-delete-observation.json'
    }
}

function global:Invoke-FinalDeleteSimulation {
    param(
        [object]$Target = $null,
        [object]$PriorDisableEvidence = $null,
        [object]$PostDisableObservation = $null,
        [bool]$BusinessOwnerFinalApprovalPresent = $true,
        [bool]$SecurityApprovalPresent = $true,
        [bool]$RetentionWindowSatisfied = $true,
        [bool]$DependencyCheckPassed = $true,
        [Nullable[bool]]$NoActiveSignInsObserved = $true,
        [Nullable[bool]]$NoActiveGrantsRemaining = $true,
        [Nullable[bool]]$NoCredentialRiskRemaining = $true,
        [string[]]$RequestedOperations = @(),
        [string]$RunId = 'REV421-001'
    )

    if (-not $PSBoundParameters.ContainsKey('Target')) { $Target = New-TestTarget }
    if (-not $PSBoundParameters.ContainsKey('PriorDisableEvidence')) { $PriorDisableEvidence = New-TestDisableEvidence }
    if (-not $PSBoundParameters.ContainsKey('PostDisableObservation')) { $PostDisableObservation = New-TestObservation }

    if ($PriorDisableEvidence -and $PriorDisableEvidence.OutputArtifactPath) { Write-TestJson -Path $PriorDisableEvidence.OutputArtifactPath -InputObject $PriorDisableEvidence }
    if ($PostDisableObservation -and $PostDisableObservation.OutputArtifactPath) { Write-TestJson -Path $PostDisableObservation.OutputArtifactPath -InputObject $PostDisableObservation }

    New-NhiFinalDeleteEligibilitySimulationPackage `
        -Target @($Target) `
        -PriorDisableEvidence $PriorDisableEvidence `
        -PostDisableObservation $PostDisableObservation `
        -BusinessOwnerFinalApprovalPresent $BusinessOwnerFinalApprovalPresent `
        -SecurityApprovalPresent $SecurityApprovalPresent `
        -RetentionWindowSatisfied $RetentionWindowSatisfied `
        -DependencyCheckPassed $DependencyCheckPassed `
        -NoActiveSignInsObserved $NoActiveSignInsObserved `
        -NoActiveGrantsRemaining $NoActiveGrantsRemaining `
        -NoCredentialRiskRemaining $NoCredentialRiskRemaining `
        -RequestedOperations $RequestedOperations `
        -RunId $RunId `
        -OutputPath $script:OutputPath
}

Describe 'Rev4.21 Final Delete Eligibility Simulation Only' {
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
        $script:OutputPath = Join-Path $TestDrive 'rev421'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:BlockedMicrosoft = New-TestTarget -Classification 'MicrosoftPlatform'
        $script:BlockedExternal = New-TestTarget -Classification 'ExternalVendorPlatform'
        $script:BlockedSuppressed = New-TestTarget -SuppressCustomerRemediation $true
        $script:BlockedEvidenceOnly = New-TestTarget -EvidenceOnly $true
    }

    It 'Complete simulated lab target can return Eligible but ReadyForActualDelete=false' {
        $result = Invoke-FinalDeleteSimulation

        $result.FinalDeleteEligibility | Should -Be 'Eligible'
        $result.ReadyForActualDelete | Should -BeFalse
        $result.RequiredSeparateApproval | Should -BeTrue
        $result.HumanDecisionCaptured | Should -BeFalse
        $result.SimulatedOnly | Should -BeTrue
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.ExecutionCommandEmitted | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package always states SimulatedOnly=true' {
        (Invoke-FinalDeleteSimulation).SimulatedOnly | Should -BeTrue
    }

    It 'Package always states FinalDeleteAllowed=false' {
        (Invoke-FinalDeleteSimulation).FinalDeleteAllowed | Should -BeFalse
    }

    It 'Package always states ExecutionCommandEmitted=false' {
        (Invoke-FinalDeleteSimulation).ExecutionCommandEmitted | Should -BeFalse
    }

    It 'Missing prior disable evidence returns NotEligible' {
        (Invoke-FinalDeleteSimulation -PriorDisableEvidence $null).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Missing observation completion returns NotEligible' {
        (Invoke-FinalDeleteSimulation -PostDisableObservation $null).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Missing business owner approval returns NotEligible' {
        (Invoke-FinalDeleteSimulation -BusinessOwnerFinalApprovalPresent $false).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Missing security approval returns NotEligible' {
        (Invoke-FinalDeleteSimulation -SecurityApprovalPresent $false).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Missing retention window returns NotEligible' {
        (Invoke-FinalDeleteSimulation -RetentionWindowSatisfied $false).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Missing dependency check returns NotEligible' {
        (Invoke-FinalDeleteSimulation -DependencyCheckPassed $false).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'MicrosoftPlatform target returns NotEligible' {
        (Invoke-FinalDeleteSimulation -Target $script:BlockedMicrosoft).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'ExternalVendorPlatform target returns NotEligible' {
        (Invoke-FinalDeleteSimulation -Target $script:BlockedExternal).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Suppressed target returns NotEligible' {
        (Invoke-FinalDeleteSimulation -Target $script:BlockedSuppressed).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'EvidenceOnly target returns NotEligible' {
        (Invoke-FinalDeleteSimulation -Target $script:BlockedEvidenceOnly).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Actual delete request is blocked' {
        (Invoke-FinalDeleteSimulation -RequestedOperations @('Delete')).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Remove request is blocked' {
        (Invoke-FinalDeleteSimulation -RequestedOperations @('Remove')).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Grant cleanup request is blocked' {
        (Invoke-FinalDeleteSimulation -RequestedOperations @('GrantCleanup')).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Metadata cleanup request is blocked' {
        (Invoke-FinalDeleteSimulation -RequestedOperations @('MetadataCleanup')).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Credential deletion request is blocked' {
        (Invoke-FinalDeleteSimulation -RequestedOperations @('CredentialDelete')).FinalDeleteEligibility | Should -Be 'NotEligible'
    }

    It 'Package writes JSON artifact locally' {
        $result = Invoke-FinalDeleteSimulation -RunId 'REV421-ARTIFACT'
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).SimulationPackageId | Should -Match '^REV421-'
    }

    It 'Tests prove no executable delete command is emitted' {
        $result = Invoke-FinalDeleteSimulation
        $result.ExecutionCommandEmitted | Should -BeFalse
        $result.CommandPreview | Should -Match 'simulation only'
    }
}
