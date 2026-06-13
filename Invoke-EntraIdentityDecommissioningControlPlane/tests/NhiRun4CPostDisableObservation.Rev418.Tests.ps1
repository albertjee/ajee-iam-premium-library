$ErrorActionPreference = 'Stop'

$script:modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path

function Write-TestJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][object]$InputObject)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $Path -Encoding utf8
}

function New-TestTarget {
    param(
        [string]$Classification = 'CustomerOwned',
        [string]$Environment = 'Lab',
        [bool]$IsLabTarget = $true,
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
        IsLabTarget = $IsLabTarget
        LabTargetMarker = $IsLabTarget
        SuppressCustomerRemediation = $SuppressCustomerRemediation
        EvidenceOnly = $EvidenceOnly
        InformationOnly = $InformationOnly
        RemediationMode = if ($InformationOnly) { 'InformationOnly' } else { 'ManualApprovalRequired' }
    }
}

function New-TestSnapshot {
    [pscustomobject]@{
        SnapshotId = 'SNAP-OBS-001'
        SnapshotPath = Join-Path $TestDrive 'obs-snapshot.json'
        CapturedUtc = ([datetime]::UtcNow.ToString('o'))
        PreActionEnabledState = $true
        AccountEnabled = $true
        TargetObjectId = '11111111-1111-1111-1111-111111111111'
    }
}

Describe 'Rev4.18 Post-Disable Observation Package' {
    BeforeAll {
        $modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path
        Import-Module $modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev418'
        $null = New-Item -ItemType Directory -Path $script:OutputPath -Force
        $script:DefaultTarget = [pscustomobject]@{
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
        $script:DefaultSnapshot = [pscustomobject]@{
            SnapshotId = 'SNAP-OBS-001'
            SnapshotPath = Join-Path $TestDrive 'obs-snapshot.json'
            CapturedUtc = ([datetime]::UtcNow.ToString('o'))
            PreActionEnabledState = $true
            AccountEnabled = $true
            PreActionCredentialCount = 1
            PreActionOwnerCount = 1
            PreActionAppRoleAssignmentsCount = 1
            PreActionOAuthGrantCount = 1
            TargetObjectId = '11111111-1111-1111-1111-111111111111'
            TargetDisplayName = 'Lab Reversible NHI'
            TargetAppId = '22222222-2222-2222-2222-222222222222'
            SnapshotHash = 'snapshot-hash'
            EvidenceSourcePath = Join-Path $TestDrive 'obs-snapshot.evidence.json'
        }
        $script:MicrosoftTarget = [pscustomobject]@{
            ObjectId = '11111111-1111-1111-1111-111111111111'
            DisplayName = 'Lab Reversible NHI'
            AppId = '22222222-2222-2222-2222-222222222222'
            ObjectType = 'ServicePrincipal'
            TargetType = 'ServicePrincipal'
            Classification = 'MicrosoftPlatform'
            Environment = 'Lab'
            TenantScope = 'Lab'
            IsLabTarget = $true
            LabTargetMarker = $true
            SuppressCustomerRemediation = $false
            EvidenceOnly = $false
            InformationOnly = $false
            RemediationMode = 'ManualApprovalRequired'
        }
        $script:SuppressedTarget = [pscustomobject]@{
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
            SuppressCustomerRemediation = $true
            EvidenceOnly = $false
            InformationOnly = $false
            RemediationMode = 'ManualApprovalRequired'
        }
        $script:EvidenceOnlyTarget = [pscustomobject]@{
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
            EvidenceOnly = $true
            InformationOnly = $false
            RemediationMode = 'ManualApprovalRequired'
        }
    }

    function global:Invoke-Package {
        param(
            [object]$Target = $null,
            [Nullable[int]]$ObservationWindowMinutes = 60,
            [string]$MonitoringOwner = 'lab-ops',
            [string]$RollbackContact = 'lab-ops',
            [string]$EscalationContact = 'lab-escalation',
            [object]$Snapshot = $null,
            [string[]]$RequestedOperations = @('ReversibleDisable'),
            [string]$RunId = 'REV418-001'
        )

        if ($null -eq $Target) { $Target = $script:DefaultTarget }
        if ($null -eq $Snapshot) { $Snapshot = $script:DefaultSnapshot }

        New-NhiRun4CPostDisableObservationPackage `
            -Target $Target `
            -ObservationWindowMinutes $ObservationWindowMinutes `
            -MonitoringOwner $MonitoringOwner `
            -RollbackContact $RollbackContact `
            -EscalationContact $EscalationContact `
            -PreActionSnapshot $Snapshot `
            -RequestedOperations $RequestedOperations `
            -RunId $RunId `
            -OutputPath $script:OutputPath
    }

    It 'Complete approved dev/test target creates observation package' {
        $result = Invoke-Package
        $result.ObservationScope | Should -Be 'SingleTargetOnly'
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.ObservationOnly | Should -BeTrue
        $result.NoTenantMutationByObservation | Should -BeTrue
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = Invoke-Package -RunId 'REV418-ARTIFACT'
        (Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json).ObservationPackageId | Should -Match '^REV418-'
    }

    It 'Package declares TenantWritePerformed=false, DisablePerformed=false, RollbackPerformed=false' {
        $result = Invoke-Package
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
    }

    It 'Package includes observation window' {
        $result = Invoke-Package
        $result.ObservationWindowMinutes | Should -Be 60
    }

    It 'Package includes monitoring owner' {
        (Invoke-Package).MonitoringOwner | Should -Be 'lab-ops'
    }

    It 'Package includes rollback contact' {
        (Invoke-Package).RollbackContact | Should -Be 'lab-ops'
    }

    It 'Package includes success criteria' {
        (Invoke-Package).SuccessCriteria | Should -Contain 'No unexpected app outage'
    }

    It 'Package includes failure criteria' {
        (Invoke-Package).FailureCriteria | Should -Contain 'App outage detected'
    }

    It 'Package includes rollback trigger criteria' {
        (Invoke-Package).RollbackTriggerCriteria | Should -Contain 'Critical outage'
    }

    It 'Missing observation window fails closed' {
        $result = Invoke-Package -ObservationWindowMinutes $null
        $result.Ready | Should -BeFalse
    }

    It 'Missing monitoring owner fails closed' {
        (Invoke-Package -MonitoringOwner '').Ready | Should -BeFalse
    }

    It 'Missing rollback contact fails closed' {
        (Invoke-Package -RollbackContact '').Ready | Should -BeFalse
    }

    It 'MicrosoftPlatform target is blocked' {
        (Invoke-Package -Target $script:MicrosoftTarget).Ready | Should -BeFalse
    }

    It 'Suppressed target is blocked' {
        (Invoke-Package -Target $script:SuppressedTarget).Ready | Should -BeFalse
    }

    It 'EvidenceOnly target is blocked' {
        (Invoke-Package -Target $script:EvidenceOnlyTarget).Ready | Should -BeFalse
    }

    It 'Package states observation only and no tenant mutation' {
        $result = Invoke-Package
        $result.ObservationOnly | Should -BeTrue
        $result.RollbackNotExecuted | Should -BeTrue
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.NoTenantMutationByObservation | Should -BeTrue
    }
}
