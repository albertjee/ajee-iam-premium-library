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

function script:New-TestSnapshot {
    param([bool]$Enabled = $true,[int]$CredentialCount = 2,[int]$OwnerCount = 1,[int]$AppRoleAssignmentCount = 0,[int]$OAuthGrantCount = 0,[string]$MetadataHash = 'hash-a')
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

Describe 'Rev4.27 Post-Rollback Validation and Restoration Evidence Package' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:modulePath = Join-Path $repoRoot 'src\Modules\NhiControlledDecommission.psm1'
        Import-Module -Name $script:modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev427'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:Target = @(New-TestTarget)
        $script:Pre = New-TestSnapshot -Enabled $true
        $script:Disable = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'disable.json'); AccountEnabledAfter = $false }
        $script:Rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback.json'); RecreateObserved = $false }
        $script:Post = New-TestSnapshot -Enabled $true
        $script:Obs = [pscustomobject]@{ ObservationWindowCompleted = $true; SuccessCriteriaMet = $true; FailureCriteriaTriggered = $false }
    }

    It 'Complete clean rollback evidence returns Passed' {
        $result = New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-OK'
        $result.PostRollbackValidationStatus | Should -Be 'Passed'
        $result.RestorationConfirmed | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).PostRollbackValidationPackageId | Should -Match '^REV427-'
    }

    It 'Missing pre-action snapshot returns Incomplete' { (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $null -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-1').PostRollbackValidationStatus | Should -Be 'Incomplete' }
    It 'Missing rollback execution evidence returns Incomplete' { (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $null -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-2').PostRollbackValidationStatus | Should -Be 'Incomplete' }
    It 'Missing post-rollback snapshot returns Incomplete' { (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $null -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-3').PostRollbackValidationStatus | Should -Be 'Incomplete' }

    It 'Enabled state not restored returns Failed' {
        $post = New-TestSnapshot -Enabled $false
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-4').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'ObjectId changed returns Failed' {
        $post = New-TestSnapshot -Enabled $true
        $post.ObjectId = '33333333-3333-3333-3333-333333333333'
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-5').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'AppId changed returns Failed' {
        $post = New-TestSnapshot -Enabled $true
        $post.AppId = '44444444-4444-4444-4444-444444444444'
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-6').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Credential count changed returns Failed' {
        $post = New-TestSnapshot -Enabled $true -CredentialCount 3
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-7').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Owner count changed returns Failed' {
        $post = New-TestSnapshot -Enabled $true -OwnerCount 2
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-8').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'App role assignment count changed returns Failed' {
        $post = New-TestSnapshot -Enabled $true -AppRoleAssignmentCount 1
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-9').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'OAuth grant count changed returns Failed' {
        $post = New-TestSnapshot -Enabled $true -OAuthGrantCount 1
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-10').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Delete observed returns Failed' {
        $rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback-delete.json'); DeleteObserved = $true }
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-11').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Recreate observed returns Failed' {
        $rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback-recreate.json'); RecreateObserved = $true }
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-12').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Grant cleanup observed returns Failed' {
        $rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback-grant.json'); GrantCleanupObserved = $true }
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-13').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Credential change observed returns Failed' {
        $rollback = [pscustomobject]@{ OutputArtifactPath = (Join-Path $TestDrive 'rollback-cred.json'); CredentialChangePerformed = $true }
        (New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-14').PostRollbackValidationStatus | Should -Be 'Failed'
    }

    It 'Package does not execute rollback' {
        $result = New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-15'
        $result.RollbackPerformedByThisPackage | Should -BeFalse
        $result.RequiredHumanDecision | Should -BeTrue
    }

    It 'Package does not perform delete or final delete' {
        $result = New-NhiRun4CPostRollbackValidationPackage -Target $script:Target -PreActionSnapshot $script:Pre -DisableEvidence $script:Disable -RollbackExecutionEvidence $script:Rollback -PostRollbackSnapshot $script:Post -ObservationResult $script:Obs -OutputPath $script:OutputPath -RunId 'REV427-16'
        $result.DeletePerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
    }
}
