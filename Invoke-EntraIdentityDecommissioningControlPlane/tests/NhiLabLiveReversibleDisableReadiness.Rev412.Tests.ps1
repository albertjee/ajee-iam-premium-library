#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev4.12 lab live reversible disable readiness' {
    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'

        foreach ($m in @('Utilities', 'ApprovalManifest', 'NhiControlledDecommission', 'NhiExecutionSchema')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }

        $script:UtilitiesModule = Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking -PassThru
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiControlledDecommission.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiExecutionSchema.psm1') -Force -DisableNameChecking
        $script:TestDecomMicrosoftPlatformIdentityCommand = $script:UtilitiesModule.ExportedFunctions['Test-DecomMicrosoftPlatformIdentity']

        function script:Get-TestSha256Hex {
            param([Parameter(Mandatory)][string]$InputString)

            $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
            $hashBytes = [System.Security.Cryptography.SHA256]::HashData($bytes)
            ($hashBytes | ForEach-Object { $_.ToString('x2') }) -join ''
        }

        function script:New-TestTarget {
            param(
                [Parameter(Mandatory)][string]$DisplayName,
                [Parameter(Mandatory)][string]$AppId,
                [Parameter(Mandatory)][string]$ObjectId,
                [Parameter()][string]$Classification = 'CustomerOwned',
                [Parameter()][string]$Environment = 'Lab',
                [Parameter()][bool]$IsLabTarget = $true,
                [Parameter()][bool]$LabValidationApproved = $true,
                [Parameter()][string]$TenantScope = 'Lab',
                [Parameter()][bool]$MicrosoftPlatform = $false,
                [Parameter()][bool]$FirstPartyMicrosoftApp = $false,
                [Parameter()][bool]$SuppressCustomerRemediation = $false,
                [Parameter()][string]$RemediationMode = 'ManualApprovalRequired',
                [Parameter()][string]$VerifiedPublisherName = 'Contoso Labs'
            )

            [pscustomobject]@{
                ObjectId                   = $ObjectId
                ObjectType                 = 'ServicePrincipal'
                DisplayName                = $DisplayName
                AppId                      = $AppId
                Environment                = $Environment
                IsLabTarget                = $IsLabTarget
                LabValidationApproved      = $LabValidationApproved
                TenantScope                = $TenantScope
                Classification             = $Classification
                MicrosoftPlatform          = $MicrosoftPlatform
                FirstPartyMicrosoftApp     = $FirstPartyMicrosoftApp
                SuppressCustomerRemediation = $SuppressCustomerRemediation
                RemediationMode            = $RemediationMode
                VerifiedPublisherName      = $VerifiedPublisherName
                PublisherName              = 'Contoso'
                ProtectedObject            = $false
                BreakGlassIndicator        = $false
                EmergencyAccessIndicator   = $false
                HighConfidenceActive       = $false
                Ambiguous                  = $false
                AccountEnabled             = $true
            }
        }

        function script:New-TestApproval {
            param(
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][string]$TargetId,
                [Parameter()][string]$ActionType = 'DisableOnly',
                [Parameter()][string]$ApprovedBy = 'lab-approver',
                [Parameter()][string]$Status = 'Approved',
                [Parameter()][string]$ExpiresUtc = ([DateTime]::UtcNow.AddDays(1).ToString('o')),
                [Parameter()][string[]]$ApprovedActions = @('DisableOnly')
            )

            [pscustomobject]@{
                SchemaVersion   = '4.2'
                ApprovedBy      = $ApprovedBy
                Status          = $Status
                RunId           = $RunId
                ExpiresUtc      = $ExpiresUtc
                Reusable        = $false
                TargetObjectIds = @($TargetId)
                ApprovedActions = @($ApprovedActions)
                ActionType      = $ActionType
                ApprovedUtc     = [DateTime]::UtcNow.ToString('o')
                ApprovalId      = "APR-$RunId"
                ManifestId      = "MAN-$RunId"
            }
        }

        function script:Write-TestApprovalManifest {
            param(
                [Parameter(Mandatory)][string]$Path,
                [Parameter(Mandatory)][string]$EngagementId,
                [Parameter(Mandatory)][string[]]$TargetObjectIds,
                [Parameter(Mandatory)][string]$ApprovedBy,
                [Parameter(Mandatory)][string]$ApprovedAt,
                [Parameter(Mandatory)][int]$ExecutionPhaseApproved,
                [Parameter()][string]$SchemaVersion = '4.2',
                [Parameter()][bool]$IncludeHash = $true
            )

            $manifest = [pscustomobject]@{
                EngagementId           = $EngagementId
                ExecutionPhaseApproved = $ExecutionPhaseApproved
                ApprovedBy             = $ApprovedBy
                ApprovedAt             = $ApprovedAt
                SchemaVersion          = $SchemaVersion
            }

            if ($IncludeHash) {
                $idsJson = ConvertTo-Json -InputObject $TargetObjectIds -Compress -Depth 10
                $manifest | Add-Member -NotePropertyName SHA256 -NotePropertyValue (Get-TestSha256Hex -InputString $idsJson) -Force
            }

            $json = $manifest | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
            return $manifest
        }

        function script:New-TestRollbackEvidence {
            param(
                [Parameter(Mandatory)][object]$Snapshot,
                [Parameter(Mandatory)][object]$Approval,
                [Parameter(Mandatory)][string]$RunId,
                [Parameter(Mandatory)][string]$TargetId
            )

            $rollback = New-NhiControlledRollbackPlan -Snapshot $Snapshot -RunId $RunId
            $rollback | Add-Member -NotePropertyName TargetObjectId -NotePropertyValue $TargetId -Force
            $rollback | Add-Member -NotePropertyName PreActionAccountEnabled -NotePropertyValue $true -Force
            $rollback | Add-Member -NotePropertyName PlannedAction -NotePropertyValue 'DisableOnly' -Force
            $rollback | Add-Member -NotePropertyName RollbackActionName -NotePropertyValue 'RollbackDisable' -Force
            $rollback | Add-Member -NotePropertyName ApprovalId -NotePropertyValue "APR-$RunId" -Force
            $rollback | Add-Member -NotePropertyName ManifestId -NotePropertyValue "MAN-$RunId" -Force
            $rollback | Add-Member -NotePropertyName CapturedUtc -NotePropertyValue ([DateTime]::UtcNow.ToString('o')) -Force
            $rollback | Add-Member -NotePropertyName ApprovalObject -NotePropertyValue $Approval -Force
            return $rollback
        }

        function script:New-TestObservationMetadata {
            param([Parameter(Mandatory)][DateTime]$StartUtc)

            [pscustomobject]@{
                ScreamTestWindowMinutes = 60
                MonitoringOwner         = 'lab-ops'
                RollbackContact         = 'lab-ops'
                ObservationStartUtc     = $StartUtc.ToString('o')
                ObservationEndUtc       = $StartUtc.AddMinutes(60).ToString('o')
            }
        }

        function script:Invoke-Readiness {
            param(
                [Parameter(Mandatory)][object]$Target,
                [Parameter(Mandatory)][object]$Approval,
                [Parameter(Mandatory)][string]$ApprovalManifestPath,
                [Parameter()][object]$Snapshot,
                [Parameter()][object]$RollbackEvidence,
                [Parameter()][object]$ObservationMetadata,
                [Parameter()][string]$ActionType = 'DisableOnly'
            )

            Test-NhiControlledLabLiveReversibleDisableReadiness `
                -Target $Target `
                -Approval $Approval `
                -ApprovalManifestPath $ApprovalManifestPath `
                -Snapshot $Snapshot `
                -RollbackEvidence $RollbackEvidence `
                -ObservationMetadata $ObservationMetadata `
                -RunId 'REV412-LAB-001' `
                -TargetId $Target.ObjectId `
                -ActionType $ActionType
        }
    }

    AfterAll {
        foreach ($m in @('NhiExecutionSchema', 'NhiControlledDecommission', 'ApprovalManifest', 'Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'readiness gate' {
        BeforeAll {
            $script:RunId = 'REV412-LAB-001'
            $script:LabTargetId = [guid]::NewGuid().Guid
            $script:LabAppId = [guid]::NewGuid().Guid
            $script:CustomerTargetId = [guid]::NewGuid().Guid
            $script:TempDir = Join-Path $TestDrive 'rev412'
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            $script:LabTarget = New-TestTarget `
                -DisplayName 'Lab Reversible NHI' `
                -AppId $script:LabAppId `
                -ObjectId $script:LabTargetId

            $script:PlatformGraph = [pscustomobject]@{
                appId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
                appOwnerOrganizationId = '72f988bf-86f1-41af-91ab-2d7cd011db47'
                verifiedPublisher = [pscustomobject]@{ displayName = 'Microsoft Corporation' }
                displayName = 'Microsoft Graph PowerShell'
                appDisplayName = 'Microsoft Graph PowerShell'
                servicePrincipalType = 'Application'
                tags = @('WindowsAzureActiveDirectoryIntegratedApp')
            }

            $script:PlatformIos = [pscustomobject]@{
                appId = 'f8d98a96-0999-43f5-8af3-69971c7bb423'
                appOwnerOrganizationId = 'e0fad04c-a04c-41ab-b35e-dc523af755a1'
                verifiedPublisher = [pscustomobject]@{ displayName = 'Apple Inc.' }
                displayName = 'iOS Accounts'
                appDisplayName = 'iOS Accounts'
                servicePrincipalType = 'Application'
                tags = @()
            }
        }

        It 'returns Ready true only for a lab-only reversible disable with complete metadata' {
            $approval = New-TestApproval -RunId $script:RunId -TargetId $script:LabTargetId
            $approvalManifestPath = Join-Path $script:TempDir 'approval-valid.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:LabTargetId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $script:LabTarget -RunId $script:RunId
            $rollback = New-TestRollbackEvidence -Snapshot $snapshot -Approval $approval -RunId $script:RunId -TargetId $script:LabTargetId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            $result = Invoke-Readiness -Target $script:LabTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation

            $result.Ready | Should -BeTrue
            $result.AllowedAction | Should -Be 'DisableOnly'
            $result.TenantWritePlanned | Should -BeFalse
            $result.FinalDeleteAllowed | Should -BeFalse
            $result.Blockers.Count | Should -Be 0
        }

        It 'fails closed when the lab indicator is missing' {
            $target = New-TestTarget -DisplayName 'Missing Lab Indicator' -AppId ([guid]::NewGuid().Guid) -ObjectId ([guid]::NewGuid().Guid) -Environment 'Production' -IsLabTarget $false -TenantScope 'Production' -LabValidationApproved $true
            $approval = New-TestApproval -RunId $script:RunId -TargetId $target.ObjectId
            $approvalManifestPath = Join-Path $script:TempDir 'approval-lab-missing-indicator.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($target.ObjectId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $target -RunId $script:RunId
            $rollback = New-TestRollbackEvidence -Snapshot $snapshot -Approval $approval -RunId $script:RunId -TargetId $target.ObjectId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            (Invoke-Readiness -Target $target -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation).Ready | Should -BeFalse
        }

        It 'fails closed on expired approval' {
            $approval = New-TestApproval -RunId $script:RunId -TargetId $script:LabTargetId -ExpiresUtc ([DateTime]::UtcNow.AddDays(-1).ToString('o'))
            $approvalManifestPath = Join-Path $script:TempDir 'approval-expired.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:LabTargetId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $script:LabTarget -RunId $script:RunId
            $rollback = New-TestRollbackEvidence -Snapshot $snapshot -Approval $approval -RunId $script:RunId -TargetId $script:LabTargetId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            (Invoke-Readiness -Target $script:LabTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation).Ready | Should -BeFalse
        }

        It 'fails closed when approval integrity metadata is missing' {
            $approval = New-TestApproval -RunId $script:RunId -TargetId $script:LabTargetId
            $approvalManifestPath = Join-Path $script:TempDir 'approval-missing-hash.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:LabTargetId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2 -IncludeHash $false
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $script:LabTarget -RunId $script:RunId
            $rollback = New-TestRollbackEvidence -Snapshot $snapshot -Approval $approval -RunId $script:RunId -TargetId $script:LabTargetId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            (Invoke-Readiness -Target $script:LabTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation).Ready | Should -BeFalse
        }

        It 'fails closed for final delete and cleanup requests' {
            $approval = New-TestApproval -RunId $script:RunId -TargetId $script:LabTargetId -ActionType 'FinalDelete' -ApprovedActions @('FinalDelete')
            $approvalManifestPath = Join-Path $script:TempDir 'approval-finaldelete.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:LabTargetId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $script:LabTarget -RunId $script:RunId
            $rollback = New-TestRollbackEvidence -Snapshot $snapshot -Approval $approval -RunId $script:RunId -TargetId $script:LabTargetId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            $finalDelete = Invoke-Readiness -Target $script:LabTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation -ActionType 'FinalDelete'
            $grantCleanup = Invoke-Readiness -Target $script:LabTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation -ActionType 'GrantCleanupReadiness'

            $finalDelete.Ready | Should -BeFalse
            $grantCleanup.Ready | Should -BeFalse
        }

        It 'blocks Microsoft Graph PowerShell and iOS Accounts' {
            $graphClassification = & $script:TestDecomMicrosoftPlatformIdentityCommand -NhiObject $script:PlatformGraph
            $iosClassification = & $script:TestDecomMicrosoftPlatformIdentityCommand -NhiObject $script:PlatformIos

            $graphTarget = New-TestTarget -DisplayName $script:PlatformGraph.displayName -AppId $script:PlatformGraph.appId -ObjectId ([guid]::NewGuid().Guid) -Classification $graphClassification.Classification -MicrosoftPlatform $graphClassification.MicrosoftPlatform -FirstPartyMicrosoftApp $graphClassification.MicrosoftFirstParty -SuppressCustomerRemediation $graphClassification.SuppressCustomerRemediation -RemediationMode 'InformationOnly'
            $iosTarget = New-TestTarget -DisplayName $script:PlatformIos.displayName -AppId $script:PlatformIos.appId -ObjectId ([guid]::NewGuid().Guid) -Classification $iosClassification.Classification -MicrosoftPlatform $iosClassification.MicrosoftPlatform -FirstPartyMicrosoftApp $iosClassification.MicrosoftFirstParty -SuppressCustomerRemediation $iosClassification.SuppressCustomerRemediation -RemediationMode 'InformationOnly' -VerifiedPublisherName 'Apple Inc.'

            $approval = New-TestApproval -RunId $script:RunId -TargetId $graphTarget.ObjectId
            $approvalManifestPath = Join-Path $script:TempDir 'approval-platform.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($graphTarget.ObjectId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $graphTarget -RunId $script:RunId
            $rollback = New-TestRollbackEvidence -Snapshot $snapshot -Approval $approval -RunId $script:RunId -TargetId $graphTarget.ObjectId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            (Invoke-Readiness -Target $graphTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation).Ready | Should -BeFalse
            (Invoke-Readiness -Target $iosTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation).Ready | Should -BeFalse
        }

        It 'fails closed for an unapproved customer target' {
            $target = New-TestTarget -DisplayName 'Unapproved Customer NHI' -AppId ([guid]::NewGuid().Guid) -ObjectId $script:CustomerTargetId -Environment 'Lab' -IsLabTarget $true -LabValidationApproved $true
            $approval = New-TestApproval -RunId $script:RunId -TargetId $script:LabTargetId
            $approvalManifestPath = Join-Path $script:TempDir 'approval-unapproved-target.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:LabTargetId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $target -RunId $script:RunId
            $rollback = New-TestRollbackEvidence -Snapshot $snapshot -Approval $approval -RunId $script:RunId -TargetId $target.ObjectId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            (Invoke-Readiness -Target $target -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback -ObservationMetadata $observation).Ready | Should -BeFalse
        }

        It 'fails closed when rollback evidence is missing' {
            $approval = New-TestApproval -RunId $script:RunId -TargetId $script:LabTargetId
            $approvalManifestPath = Join-Path $script:TempDir 'approval-no-rollback.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:LabTargetId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $script:LabTarget -RunId $script:RunId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            (Invoke-Readiness -Target $script:LabTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -ObservationMetadata $observation).Ready | Should -BeFalse
        }

        It 'fails closed when snapshot evidence is missing' {
            $approval = New-TestApproval -RunId $script:RunId -TargetId $script:LabTargetId
            $approvalManifestPath = Join-Path $script:TempDir 'approval-no-snapshot.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:LabTargetId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $rollback = New-TestRollbackEvidence -Snapshot ([pscustomobject]@{ SHA256 = 'abc'; Target = [pscustomobject]@{ ObjectId = $script:LabTargetId } }) -Approval $approval -RunId $script:RunId -TargetId $script:LabTargetId
            $observation = New-TestObservationMetadata -StartUtc ([DateTime]::UtcNow)

            (Invoke-Readiness -Target $script:LabTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -RollbackEvidence $rollback -ObservationMetadata $observation).Ready | Should -BeFalse
        }

        It 'fails closed when observation metadata is missing' {
            $approval = New-TestApproval -RunId $script:RunId -TargetId $script:LabTargetId
            $approvalManifestPath = Join-Path $script:TempDir 'approval-no-observation.json'
            $null = Write-TestApprovalManifest -Path $approvalManifestPath -EngagementId $script:RunId -TargetObjectIds @($script:LabTargetId) -ApprovedBy 'lab-approver' -ApprovedAt ([DateTime]::UtcNow.ToString('o')) -ExecutionPhaseApproved 2
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $script:LabTarget -RunId $script:RunId
            $rollback = New-TestRollbackEvidence -Snapshot $snapshot -Approval $approval -RunId $script:RunId -TargetId $script:LabTargetId

            (Invoke-Readiness -Target $script:LabTarget -Approval $approval -ApprovalManifestPath $approvalManifestPath -Snapshot $snapshot -RollbackEvidence $rollback).Ready | Should -BeFalse
        }
    }
}
