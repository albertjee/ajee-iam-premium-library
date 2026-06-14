$ErrorActionPreference = 'Stop'

function script:Write-TestJson {
    param([string]$Path,[object]$InputObject)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 40) | Set-Content -LiteralPath $Path -Encoding utf8
}

function script:New-TestTarget {
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

function script:New-TestSnapshot {
    param(
        [bool]$Enabled = $true,
        [int]$CredentialCount = 2,
        [int]$OwnerCount = 1,
        [int]$AppRoleAssignmentCount = 0,
        [int]$OAuthGrantCount = 0,
        [string]$MetadataHash = 'hash-a'
    )

    [pscustomobject]@{
        SnapshotPath = Join-Path $TestDrive ('snapshot-' + ([guid]::NewGuid().Guid) + '.json')
        AccountEnabled = $Enabled
        Enabled = $Enabled
        IsEnabled = $Enabled
        CredentialCount = $CredentialCount
        OwnerCount = $OwnerCount
        AppRoleAssignmentCount = $AppRoleAssignmentCount
        OAuthGrantCount = $OAuthGrantCount
        AppMetadataHash = $MetadataHash
        ObjectId = '11111111-1111-1111-1111-111111111111'
        AppId = '22222222-2222-2222-2222-222222222222'
    }
}

function script:New-TestObservationResult {
    param(
        [bool]$ObservationWindowCompleted = $true,
        [string]$MonitoringOwner = 'lab-ops',
        [string]$RollbackContact = 'lab-ops',
        [bool]$SuccessCriteriaMet = $true,
        [bool]$FailureCriteriaTriggered = $false,
        [bool]$RollbackTriggerDetected = $false,
        [string]$BusinessOwnerValidationResult = 'Passed'
    )

    [pscustomobject]@{
        ObservationWindowCompleted = $ObservationWindowCompleted
        MonitoringOwner = $MonitoringOwner
        RollbackContact = $RollbackContact
        SuccessCriteriaMet = $SuccessCriteriaMet
        FailureCriteriaTriggered = $FailureCriteriaTriggered
        RollbackTriggerDetected = $RollbackTriggerDetected
        BusinessOwnerValidationResult = $BusinessOwnerValidationResult
    }
}

Describe 'Rev4.25 Post-Disable Evidence Validation and Observation Result Package' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev425'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:Target = @(New-TestTarget)
        $script:Pre = New-TestSnapshot -Enabled $true
        $script:Exec = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'exec.json'); DisableObserved = $true }
        $script:Post = New-TestSnapshot -Enabled $false
        $script:Obs = New-TestObservationResult
        $script:Evidence = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'evidence.json') }
        Write-TestJson -Path $script:Pre.SnapshotPath -InputObject $script:Pre
        Write-TestJson -Path $script:Post.SnapshotPath -InputObject $script:Post
        Write-TestJson -Path $script:Exec.OutputArtifactPath -InputObject $script:Exec
        Write-TestJson -Path $script:Evidence.OutputArtifactPath -InputObject $script:Evidence
    }

    It 'Complete clean post-disable evidence returns Passed' {
        $result = New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-OK'
        $result.PostDisableValidationStatus | Should -Be 'Passed'
        $result.ReadyToRemainDisabled | Should -BeTrue
        $result.RollbackRecommended | Should -BeFalse
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).PostDisableValidationPackageId | Should -Match '^REV425-'
    }

    It 'Package states TenantWritePerformed=false' {
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-STATE').TenantWritePerformed | Should -BeFalse
    }

    It 'Missing pre-action snapshot returns Incomplete' { (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $null -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-1').PostDisableValidationStatus | Should -Be 'Incomplete' }
    It 'Missing execution evidence returns Incomplete' { (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $null -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-2').PostDisableValidationStatus | Should -Be 'Incomplete' }
    It 'Missing post-action snapshot returns Incomplete' { (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $null -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-3').PostDisableValidationStatus | Should -Be 'Incomplete' }
    It 'Missing observation result returns Incomplete' { (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $null -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-4').PostDisableValidationStatus | Should -Be 'Incomplete' }

    It 'Expected account-enabled change not observed returns Failed' {
        $post = New-TestSnapshot -Enabled $true
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-5').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'Credential count changed returns Failed' {
        $post = New-TestSnapshot -Enabled $false -CredentialCount 3
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-6').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'Owner count changed returns Failed' {
        $post = New-TestSnapshot -Enabled $false -OwnerCount 2
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-7').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'App role assignment count changed returns Failed' {
        $post = New-TestSnapshot -Enabled $false -AppRoleAssignmentCount 1
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-8').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'OAuth grant count changed returns Failed' {
        $post = New-TestSnapshot -Enabled $false -OAuthGrantCount 1
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-9').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'Delete observed returns Failed' {
        $exec = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'exec-delete.json'); DeleteObserved = $true }
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-10').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'Grant cleanup observed returns Failed' {
        $exec = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'exec-grant.json'); GrantCleanupObserved = $true }
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-11').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'Credential deletion observed returns Failed' {
        $exec = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'exec-cred.json'); CredentialDeletionObserved = $true }
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-12').PostDisableValidationStatus | Should -Be 'Failed'
    }

    It 'Observation failure triggers RollbackRecommended=true' {
        $obs = New-TestObservationResult -SuccessCriteriaMet $false -FailureCriteriaTriggered $true
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-13').RollbackRecommended | Should -BeTrue
    }

    It 'Rollback trigger detected returns RollbackRecommended=true' {
        $obs = New-TestObservationResult -RollbackTriggerDetected $true
        (New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-14').RollbackRecommended | Should -BeTrue
    }

    It 'Package does not execute rollback' {
        $result = New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-15'
        $result.RollbackPerformed | Should -BeFalse
        $result.RequiredHumanDecision | Should -BeTrue
    }

    It 'Package does not perform delete or final delete' {
        $result = New-NhiRun4CPostDisableEvidenceValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -ExecutionEvidence $script:Exec -PostActionSnapshot $script:Post -ObservationResult $script:Obs -EvidenceCapturePackage $script:Evidence -OutputPath $script:OutputPath -RunId 'REV425-16'
        $result.DeletePerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
    }
}
