#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-metadata-cleanup.sample.json'
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

    $script:Target = [PSCustomObject]@{
        ObjectId               = 'sp-rev45-test-001'
        ObjectType             = 'ServicePrincipal'
        DisplayName            = 'Rev45 Test Service Principal'
        ProtectedObject        = $false
        MicrosoftFirstParty    = $false
        EmergencyAccessIndicator = $false
        BreakGlassIndicator    = $false
        HighConfidenceActive   = $false
        Ambiguous              = $false
    }
    $script:TargetValidation = Test-NhiControlledTarget -Target $script:Target
    $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target $script:Target -RunId 'RUN-REV45-META-SAMPLE-001'
    $script:RawSample = Get-Content -LiteralPath $script:SamplePath -Raw
    $script:Sample = $script:RawSample | ConvertFrom-Json

    function New-Rev45Plan {
        param([hashtable]$Overrides = @{})
        $plan = [ordered]@{
            SchemaVersion           = '4.5'
            RunId                   = 'RUN-REV45-META-SAMPLE-001'
            TargetId                = 'sp-rev45-test-001'
            TargetType              = 'ServicePrincipal'
            MetadataCleanupType     = 'CredentialMetadata'
            MetadataObjectId        = 'sp-rev45-test-001-credential-metadata'
            MetadataObjectType      = 'PasswordCredential'
            ApprovalId              = 'APP-REV45-META-001'
            TargetObjectIds         = @('sp-rev45-test-001')
            ApprovedActions         = @('MetadataCleanupReadiness')
            CredentialMetadataEvidence = @(
                [PSCustomObject]@{
                    CredentialType = 'PasswordCredential'
                    KeyId          = 'cred-pass-rev45-001'
                    CredentialId   = 'cred-pass-rev45-001'
                    StartDateTime  = '2025-01-01T00:00:00Z'
                    EndDateTime    = '2026-01-01T00:00:00Z'
                    DisplayName    = 'Rev45 Password Credential Metadata'
                }
            )
            OwnerMetadataEvidence    = [PSCustomObject]@{
                OwnerCount       = 2
                OwnerTypeSummary = [ordered]@{ User = 2; Group = 0; ServicePrincipal = 0 }
                OwnerRiskNotes   = @('No live owner removal is permitted.', 'Owner evidence is informational only.')
            }
            DecommissionMarkerEvidence = [PSCustomObject]@{
                MarkerPresent         = $true
                LocalOnly             = $true
                LiveGraphUpdateApproved = $false
            }
            RollbackLimitation      = 'Limited'
            CleanupReadiness        = [PSCustomObject]@{ Status = 'Ready' }
            ScreamTestEvidence      = [PSCustomObject]@{
                EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                Status = 'Complete'
                DependencyDetected = $false
                RecentActivityDetected = $false
                QuerySucceeded = $true
            }
            DeleteReadiness         = [PSCustomObject]@{ Status = 'Ready' }
            LiveCleanupApproved     = $false
            LiveCleanupExecutable   = $false
        }
        foreach ($key in $Overrides.Keys) { $plan[$key] = $Overrides[$key] }
        [PSCustomObject]$plan
    }

    function New-Rev45Approval {
        param([hashtable]$Overrides = @{})
        $approval = [ordered]@{
            SchemaVersion        = '4.5'
            RunId                = 'RUN-REV45-META-SAMPLE-001'
            Status               = 'Approved'
            ApprovedBy           = 'metadata-cleanup-approver@example.com'
            ExpiresUtc           = '2099-01-01T00:00:00Z'
            Reusable             = $false
            ApprovalId           = 'APP-REV45-META-001'
            TargetId             = 'sp-rev45-test-001'
            TargetType           = 'ServicePrincipal'
            MetadataCleanupType  = 'CredentialMetadata'
            MetadataObjectId     = 'sp-rev45-test-001-credential-metadata'
            ApprovedActions      = @('MetadataCleanupReadiness')
            TargetObjectIds      = @('sp-rev45-test-001')
            LiveCleanupApproved  = $false
            LiveCleanupExecutable = $false
        }
        foreach ($key in $Overrides.Keys) { $approval[$key] = $Overrides[$key] }
        [PSCustomObject]$approval
    }

    function New-Rev45GateInput {
        param(
            [hashtable]$PlanOverrides = @{},
            [hashtable]$ApprovalOverrides = @{},
            [string]$Stage = 'MetadataCleanupReadiness',
            [bool]$TargetPassed = $true,
            [bool]$SnapshotPresent = $true,
            [bool]$WhatIf = $true,
            [bool]$DemoMode = $false,
            [string]$CleanupReadinessStatus = 'Ready',
            [bool]$IncludeSnapshotId = $true
        )

        $plan = New-Rev45Plan -Overrides $PlanOverrides
        $snapshot = if ($SnapshotPresent) { $script:Snapshot } else { $null }
        $approvalOverrides = @{}
        foreach ($key in $ApprovalOverrides.Keys) { $approvalOverrides[$key] = $ApprovalOverrides[$key] }
        if (-not $approvalOverrides.ContainsKey('SnapshotId')) {
            $approvalOverrides['SnapshotId'] = if ($IncludeSnapshotId -and $snapshot) { $snapshot.SHA256 } else { $null }
        }
        $approval = New-Rev45Approval -Overrides $approvalOverrides

        @{
            ExecutionStage = $Stage
            Plan = $plan
            Approval = $approval
            TargetValidation = if ($TargetPassed) { $script:TargetValidation } else { [PSCustomObject]@{ Passed = $false; Reasons = @('Target validation failed.') } }
            Snapshot = $snapshot
            CleanupReadiness = [PSCustomObject]@{ Status = $CleanupReadinessStatus }
            WhatIf = $WhatIf
            DemoMode = $DemoMode
        }
    }

    function Invoke-Rev45Gate {
        param([hashtable]$InputObject)
        $module = Get-Module NhiControlledDecommission
        & $module {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } $InputObject
    }

    function Invoke-Rev45Module {
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

Describe 'Rev4.5 metadata cleanup contract' {
    It 'keeps the private evaluator hidden and export contract frozen' {
        Get-Command Test-NhiControlledMetadataCleanupReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        (Get-Module NhiControlledDecommission).ExportedCommands.Keys.Count | Should -Be 11
    }

    It 'parses the metadata sample JSON' {
        $script:Sample | Should -Not -BeNullOrEmpty
        $script:Sample.SchemaVersion | Should -Be '4.5'
        $script:Sample.TargetType | Should -Be 'ServicePrincipal'
    }

    It 'contains no secret-like values or delete cmdlet names' {
        $script:RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        $script:RawSample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication'
    }

    It 'captures credential metadata and owner evidence in the sample' {
        $script:Sample.CredentialMetadataEvidence.Count | Should -Be 2
        $script:Sample.CredentialMetadataEvidence[0].KeyId | Should -Be 'cred-pass-rev45-001'
        $script:Sample.OwnerMetadataEvidence.OwnerCount | Should -Be 2
        $script:Sample.OwnerMetadataEvidence.OwnerTypeSummary.User | Should -Be 2
    }

    It 'produces sanitized credential inventory evidence' {
        $inventory = Invoke-Rev45Module {
            param($Plan, $Approval, $Snapshot, $CleanupReadiness)
            New-NhiControlledMetadataInventory -Plan $Plan -Approval $Approval -Snapshot $Snapshot -CleanupReadiness $CleanupReadiness -Credentials @($Plan.CredentialMetadataEvidence)
        } (New-Rev45Plan) (New-Rev45Approval) $script:Snapshot ([PSCustomObject]@{ Status = 'Ready' })
        $inventory.CredentialMetadataEvidence.Count | Should -Be 1
        $inventory.CredentialMetadataEvidence[0].KeyId | Should -Be 'cred-pass-rev45-001'
        $inventory.CredentialMetadataEvidence[0].SecretValue | Should -BeNullOrEmpty
        $inventory.CredentialMetadataEvidence[0].CertificateValue | Should -BeNullOrEmpty
    }

    It 'includes owner evidence and rollback limitation in the inventory' {
        $inventory = Invoke-Rev45Module {
            param($Plan, $Approval, $Snapshot, $CleanupReadiness)
            New-NhiControlledMetadataInventory -Plan $Plan -Approval $Approval -Snapshot $Snapshot -CleanupReadiness $CleanupReadiness -Credentials @($Plan.CredentialMetadataEvidence)
        } (New-Rev45Plan) (New-Rev45Approval) $script:Snapshot ([PSCustomObject]@{ Status = 'Ready' })
        $inventory.OwnerMetadataEvidence.OwnerCount | Should -Be 2
        $inventory.RollbackLimitation | Should -Be 'Limited'
        $inventory.DecommissionMarkerEvidence.LocalOnly | Should -BeTrue
    }

    It 'classifies reversible rollback limitation' {
        (Invoke-Rev45Module { param($Evidence) Get-NhiControlledRollbackLimitation -Evidence $Evidence } ([PSCustomObject]@{ Reversible = $true })).Classification | Should -Be 'Reversible'
    }

    It 'classifies limited rollback limitation' {
        (Invoke-Rev45Module { param($Evidence) Get-NhiControlledRollbackLimitation -Evidence $Evidence } ([PSCustomObject]@{ LimitedRollback = $true })).Classification | Should -Be 'Limited'
    }

    It 'classifies not available rollback limitation' {
        (Invoke-Rev45Module { param($Evidence) Get-NhiControlledRollbackLimitation -Evidence $Evidence } ([PSCustomObject]@{ RollbackAvailable = $false })).Classification | Should -Be 'NotAvailable'
    }

    It 'classifies evidence-only rollback limitation' {
        (Invoke-Rev45Module { param($Evidence) Get-NhiControlledRollbackLimitation -Evidence $Evidence } ([PSCustomObject]@{})).Classification | Should -Be 'EvidenceOnly'
    }

    It 'builds metadata cleanup plan and action log objects' {
        $gate = Invoke-Rev45Gate (New-Rev45GateInput)
        $inventory = Invoke-Rev45Module {
            param($Plan, $Approval, $Snapshot, $CleanupReadiness)
            New-NhiControlledMetadataInventory -Plan $Plan -Approval $Approval -Snapshot $Snapshot -CleanupReadiness $CleanupReadiness -Credentials @($Plan.CredentialMetadataEvidence)
        } (New-Rev45Plan) (New-Rev45Approval) $script:Snapshot ([PSCustomObject]@{ Status = 'Ready' })
        $plan = Invoke-Rev45Module {
            param($Plan, $Inventory, $Readiness)
            New-NhiControlledMetadataCleanupPlan -Plan $Plan -Inventory $Inventory -Readiness $Readiness
        } (New-Rev45Plan) $inventory $gate
        $actionLog = Invoke-Rev45Module {
            param($Plan, $Inventory, $Readiness)
            New-NhiControlledMetadataCleanupActionLog -Plan $Plan -Inventory $Inventory -Readiness $Readiness
        } (New-Rev45Plan) $inventory $gate
        $plan.Status | Should -Be 'Planned'
        $actionLog.Result | Should -Be 'SimulationOnly'
    }

    It 'satisfies readiness only as simulation when every gate passes' {
        $result = Invoke-Rev45Gate (New-Rev45GateInput)
        $result.GatesPassed | Should -BeTrue
        $result.Status | Should -Be 'MetadataCleanupSatisfiedSimulationOnly'
    }

    It 'never enables live metadata cleanup when every gate passes' {
        $result = Invoke-Rev45Gate (New-Rev45GateInput)
        $result.LiveCleanupExecutable | Should -BeFalse
        $result.CleanupCmdletAvailable | Should -BeFalse
        $result.SimulationOnly | Should -BeTrue
    }

    It 'supports DemoMode readiness simulation only' {
        $result = Invoke-Rev45Gate (New-Rev45GateInput -DemoMode $true -WhatIf $false)
        $result.GatesPassed | Should -BeTrue
        $result.LiveCleanupExecutable | Should -BeFalse
        $result.PostCleanupValidation.Status | Should -Be 'Simulated'
    }

    It 'supports WhatIf readiness simulation only' {
        $result = Invoke-Rev45Gate (New-Rev45GateInput -WhatIf $true)
        $result.GatesPassed | Should -BeTrue
        $result.WhatIf | Should -BeTrue
    }

    It 'keeps post-cleanup validation simulated or not run only' {
        $whatIfResult = Invoke-Rev45Gate (New-Rev45GateInput -WhatIf $true)
        $nonWhatIfResult = Invoke-Rev45Gate (New-Rev45GateInput -WhatIf $false -DemoMode $true)
        $whatIfResult.PostCleanupValidation.Status | Should -Be 'Simulated'
        $nonWhatIfResult.PostCleanupValidation.Status | Should -Be 'Simulated'
    }
}

Describe 'Rev4.5 required gate failures' {
    It 'blocks <Name>' -ForEach @(
        @{ Name = 'missing stage'; Build = { New-Rev45GateInput -Stage 'DeleteReadinessOnly' }; Pattern = 'MetadataCleanupReadiness' }
        @{ Name = 'wrong schema'; Build = { New-Rev45GateInput -PlanOverrides @{ SchemaVersion = '4.4' } }; Pattern = 'Valid metadata cleanup plan is required' }
        @{ Name = 'missing target binding'; Build = { New-Rev45GateInput -PlanOverrides @{ TargetId = '' } }; Pattern = 'Exact metadata target binding is required' }
        @{ Name = 'missing metadata object'; Build = { New-Rev45GateInput -PlanOverrides @{ MetadataObjectId = '' } }; Pattern = 'Exact metadata target binding is required' }
        @{ Name = 'unsupported cleanup type'; Build = { New-Rev45GateInput -PlanOverrides @{ MetadataCleanupType = 'OAuthGrant' } }; Pattern = 'Approval must match the cleanup action type' }
        @{ Name = 'missing snapshot'; Build = { New-Rev45GateInput -SnapshotPresent $false }; Pattern = 'Snapshot evidence is required' }
        @{ Name = 'cleanup not ready'; Build = { New-Rev45GateInput -CleanupReadinessStatus 'Partial' }; Pattern = 'Cleanup readiness must be Ready' }
        @{ Name = 'target validation failed'; Build = { New-Rev45GateInput -TargetPassed $false }; Pattern = 'Target validation failed' }
        @{ Name = 'unattended live-mode request'; Build = { New-Rev45GateInput -WhatIf $false -DemoMode $false }; Pattern = 'WhatIf or DemoMode' }
        @{ Name = 'missing credential evidence'; Build = { New-Rev45GateInput -PlanOverrides @{ CredentialMetadataEvidence = @() } }; Pattern = 'Credential metadata evidence is required' }
        @{ Name = 'missing owner evidence'; Build = { New-Rev45GateInput -PlanOverrides @{ MetadataCleanupType = 'OwnerMetadata'; OwnerMetadataEvidence = $null } }; Pattern = 'Owner metadata evidence is required' }
        @{ Name = 'missing marker evidence'; Build = { New-Rev45GateInput -PlanOverrides @{ MetadataCleanupType = 'MarkerCleanup'; DecommissionMarkerEvidence = $null } }; Pattern = 'Marker cleanup evidence is required' }
    ) {
        $result = Invoke-Rev45Gate (& $Build)
        $result.GatesPassed | Should -BeFalse
        $result.Status | Should -Be 'Blocked'
        $result.LiveCleanupExecutable | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match $Pattern
    }

    It 'blocks approval id missing' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'MetadataCleanupReadiness'
            Plan = (New-Rev45Plan)
            Approval = (New-Rev45Approval -Overrides @{ ApprovalId = '' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Approval specifically authorizing the cleanup action'
    }

    It 'blocks approval not approved' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'MetadataCleanupReadiness'
            Plan = (New-Rev45Plan)
            Approval = (New-Rev45Approval -Overrides @{ Status = 'Pending' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Approval status must be Approved'
    }

    It 'blocks approval target mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'MetadataCleanupReadiness'
            Plan = (New-Rev45Plan)
            Approval = (New-Rev45Approval -Overrides @{ TargetId = 'wrong-target' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Exact target binding is required'
    }

    It 'blocks approval metadata mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'MetadataCleanupReadiness'
            Plan = (New-Rev45Plan)
            Approval = (New-Rev45Approval -Overrides @{ MetadataObjectId = 'wrong-meta' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Exact metadata object ID is required'
    }

    It 'blocks approval type mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'MetadataCleanupReadiness'
            Plan = (New-Rev45Plan)
            Approval = (New-Rev45Approval -Overrides @{ MetadataCleanupType = 'OwnerMetadata' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Approval must match the cleanup action type'
    }

    It 'blocks approval action missing' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'MetadataCleanupReadiness'
            Plan = (New-Rev45Plan)
            Approval = (New-Rev45Approval -Overrides @{ ApprovedActions = @('SomethingElse') })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'specifically authorize the cleanup action'
    }

    It 'blocks snapshot mismatch' {
        $module = Get-Module NhiControlledDecommission
        $result = & $module {
            param($GateInput)
            Test-NhiControlledMetadataCleanupReadinessGate @GateInput
        } @{
            ExecutionStage = 'MetadataCleanupReadiness'
            Plan = (New-Rev45Plan)
            Approval = (New-Rev45Approval -Overrides @{ SnapshotId = 'bad-snapshot' })
            TargetValidation = $script:TargetValidation
            Snapshot = $script:Snapshot
            CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
            WhatIf = $true
            DemoMode = $false
        }
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'Snapshot evidence must match the approval'
    }
}
