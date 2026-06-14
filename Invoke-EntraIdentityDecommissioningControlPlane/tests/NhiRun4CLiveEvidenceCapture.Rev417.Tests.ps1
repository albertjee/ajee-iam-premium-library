$ErrorActionPreference = 'Stop'

$script:modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path

function Write-TestJson {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][object]$InputObject)
    $null = New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force
    ($InputObject | ConvertTo-Json -Depth 30) | Set-Content -LiteralPath $Path -Encoding utf8
}

function New-Rev417TestTarget {
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

function New-Rev417TestSnapshot {
    param([string]$Name = 'snapshot')
    [pscustomobject]@{
        SnapshotId = "SNAP-$Name"
        SnapshotPath = Join-Path $TestDrive "$Name.json"
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
        EvidenceSourcePath = Join-Path $TestDrive "$Name.evidence.json"
    }
}

Describe 'Rev4.17 Live Evidence Capture Package' {
    BeforeAll {
        $modulePath = (Resolve-Path (Join-Path $PWD 'src\Modules\NhiControlledDecommission.psm1')).Path
        Import-Module $modulePath -Force
        $script:OutputPath = Join-Path $TestDrive 'rev417'
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
            SnapshotId = 'SNAP-rev417'
            SnapshotPath = Join-Path $TestDrive 'rev417.json'
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
            EvidenceSourcePath = Join-Path $TestDrive 'rev417.evidence.json'
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

    function script:Invoke-Rev417Package {
        param(
            [object]$Target = $null,
            [object]$Snapshot = $null,
            [string]$TenantId = 'tenant-001',
            [string[]]$RequestedOperations = @('ReversibleDisable'),
            [string]$RunId = 'REV417-001'
        )

        if ($null -eq $Target) { $Target = $script:DefaultTarget }
        if ($null -eq $Snapshot) { $Snapshot = $script:DefaultSnapshot }

        New-NhiRun4CLiveEvidenceCapturePackage `
            -Target $Target `
            -TenantId $TenantId `
            -PreActionSnapshot $Snapshot `
            -PostActionSnapshot $null `
            -RequestedOperations $RequestedOperations `
            -RunId $RunId `
            -OutputPath $script:OutputPath
    }

    It 'Complete approved dev/test target creates evidence capture package' {
        $result = Invoke-Rev417Package
        $result.EvidenceScope | Should -Be 'SingleTargetOnly'
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
        $result.RollbackPerformed | Should -BeFalse
        $result.FinalDeleteAllowed | Should -BeFalse
        $result.WhatChanged | Should -Be 'AccountEnabled only'
        Test-Path -LiteralPath $result.OutputArtifactPath | Should -BeTrue
    }

    It 'Package writes JSON artifact locally' {
        $result = Invoke-Rev417Package -RunId 'REV417-ARTIFACT'
        $artifact = Get-Content -LiteralPath $result.OutputArtifactPath -Raw | ConvertFrom-Json
        $artifact.EvidencePackageId | Should -Match '^REV417-'
    }

    It 'Package declares TenantWritePerformed=false and DisablePerformed=false' {
        $result = Invoke-Rev417Package
        $result.TenantWritePerformed | Should -BeFalse
        $result.DisablePerformed | Should -BeFalse
    }

    It 'Package requires pre-action snapshot' {
        $result = New-NhiRun4CLiveEvidenceCapturePackage `
            -Target $script:DefaultTarget `
            -TenantId 'tenant-001' `
            -PreActionSnapshot $null `
            -PostActionSnapshot $null `
            -RequestedOperations @('ReversibleDisable') `
            -RunId 'REV417-MISSING-SNAPSHOT' `
            -OutputPath $script:OutputPath
        $result.Ready | Should -BeFalse
        ($result.Blockers -join '; ') | Should -Match 'snapshot'
    }

    It 'Package requires execution evidence placeholders' {
        $result = Invoke-Rev417Package
        $result.ExecutionEvidenceRequired | Should -BeTrue
        $result.OperatorIdentityPlaceholder | Should -Be 'Pending'
        $result.ExecutionStartUtcPlaceholder | Should -Be 'Pending'
        $result.ExecutionEndUtcPlaceholder | Should -Be 'Pending'
    }

    It 'Package requires post-action evidence placeholders' {
        $result = Invoke-Rev417Package
        $result.AccountEnabledAfter | Should -BeNullOrEmpty
        $result.CredentialCountAfter | Should -BeNullOrEmpty
        $result.OwnerCountAfter | Should -BeNullOrEmpty
        $result.AppRoleAssignmentsCountAfter | Should -BeNullOrEmpty
        $result.OAuthGrantCountAfter | Should -BeNullOrEmpty
    }

    It 'Package states WhatChanged = AccountEnabled only' {
        (Invoke-Rev417Package).WhatChanged | Should -Be 'AccountEnabled only'
    }

    It 'Package states prohibited changes for grants, credentials, owners, metadata, service principal deletion, application deletion' {
        $result = Invoke-Rev417Package
        $result.WhatMustNotChange | Should -Contain 'grants'
        $result.WhatMustNotChange | Should -Contain 'credentials'
        $result.WhatMustNotChange | Should -Contain 'owners'
        $result.WhatMustNotChange | Should -Contain 'app metadata'
        $result.WhatMustNotChange | Should -Contain 'app object'
        $result.WhatMustNotChange | Should -Contain 'service principal deletion'
    }

    It 'Missing target returns fail-closed package or throws controlled error' {
        $threw = $false
        try {
            $result = New-NhiRun4CLiveEvidenceCapturePackage `
                -Target $null `
                -TenantId 'tenant-001' `
                -PreActionSnapshot $script:DefaultSnapshot `
                -PostActionSnapshot $null `
                -RequestedOperations @('ReversibleDisable') `
                -RunId 'REV417-MISSING-TARGET' `
                -OutputPath $script:OutputPath
        } catch {
            $threw = $true
        }

        if ($threw) {
            $threw | Should -BeTrue
        } else {
            $result.Ready | Should -BeFalse
        }
    }

    It 'MicrosoftPlatform target is blocked' {
        (Invoke-Rev417Package -Target $script:MicrosoftTarget).Ready | Should -BeFalse
    }

    It 'Suppressed target is blocked' {
        (Invoke-Rev417Package -Target $script:SuppressedTarget).Ready | Should -BeFalse
    }

    It 'EvidenceOnly target is blocked' {
        (Invoke-Rev417Package -Target $script:EvidenceOnlyTarget).Ready | Should -BeFalse
    }

    It 'Final delete request is blocked' {
        (Invoke-Rev417Package -RequestedOperations @('FinalDelete')).Ready | Should -BeFalse
    }

    It 'Grant cleanup request is blocked' {
        (Invoke-Rev417Package -RequestedOperations @('GrantCleanup')).Ready | Should -BeFalse
    }

    It 'Credential deletion request is blocked' {
        (Invoke-Rev417Package -RequestedOperations @('CredentialDelete')).Ready | Should -BeFalse
    }
}
