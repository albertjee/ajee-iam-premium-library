#Requires -Modules Pester

# M7.2 Consolidation: 8 NhiControlledDecommission.RevXX.Tests.ps1 files -> 1 consolidated file.
# Source files (kept in place, not deleted by this change): Rev42, Rev43, Rev44, Rev45, Rev46,
# Rev47, Rev48, Rev49.
#
# The module is imported ONCE in the shared top-level BeforeAll below. No Mock, InModuleScope,
# or BeforeEach usage was found in any of the 8 source files (verified via grep before writing
# this file), so a single shared import is behavior-neutral versus each file's original
# Remove-Module/Import-Module cycle.
#
# Several source files (Rev4.5, Rev4.6, Rev4.7, Rev4.8, Rev4.9) set generically-named
# script-scope state ($script:Target, $script:TargetValidation, $script:Snapshot,
# $script:RawSample, $script:Sample) at file scope, where each file previously ran as an
# independent Pester script. To avoid cross-revision variable collisions in this single merged
# file, each of those revisions keeps its own nested BeforeAll scoped to a per-revision wrapper
# Describe, which re-establishes that state immediately before that revision's own Describe
# blocks run -- an exact behavioral mirror of the original per-file BeforeAll semantics, just
# re-scoped one level deeper so Pester runs it fresh, in file order, right before its own tests.
# Rev4.2/4.3/4.4 never used those generic names at file scope (only inside their own
# already-nested "sample artifact" Describes), so no wrapper is needed for them.
#
# Duplicate-name judgment calls (see the task report for full reasoning):
#   - "contains no secret-like values or delete cmdlet names" (Rev43/44/45/46/47/48) and
#     "exists and parses as JSON" (Rev43/44): identical assertion code run against a different
#     sample fixture per revision -> collapsed into two shared -ForEach Describes at the bottom
#     of this file (one case per revision, exact original pattern preserved per case).
#   - All other same-named "It" blocks flagged for this group (the "blocks <Name>" ForEach
#     templates, and the "blocks approval ..." / "keeps ... simulation only" / "keeps the
#     private evaluator hidden ..." families) each invoke a DIFFERENT private gate function
#     from the module with a different Plan/Approval shape -> verified NOT true duplicates,
#     kept as separate "It" blocks under their own per-revision Describe (no collision since
#     Pester scopes "It" names to their enclosing Describe).

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:EntryPointPath = Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'

    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

    # ---- Rev4.2 sample paths + helpers ----
    $script:PlanSamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-decommission-plan.sample.json'
    $script:ApprovalSamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-decommission-approval.sample.json'

    function New-Rev42Target {
        param(
            [string]$ObjectId = 'sp-rev42-001',
            [string]$ObjectType = 'ServicePrincipal',
            [bool]$ProtectedObject = $false,
            [bool]$MicrosoftFirstParty = $false,
            [bool]$EmergencyAccessIndicator = $false,
            [bool]$BreakGlassIndicator = $false,
            [bool]$HighConfidenceActive = $false,
            [bool]$Ambiguous = $false
        )
        [PSCustomObject]@{
            ObjectId = $ObjectId
            ObjectType = $ObjectType
            DisplayName = 'Rev42 Test Service Principal'
            AppId = 'app-rev42-001'
            AccountEnabled = $true
            ProtectedObject = $ProtectedObject
            MicrosoftFirstParty = $MicrosoftFirstParty
            EmergencyAccessIndicator = $EmergencyAccessIndicator
            BreakGlassIndicator = $BreakGlassIndicator
            HighConfidenceActive = $HighConfidenceActive
            Ambiguous = $Ambiguous
            ClientSecret = 'must-not-export'
            AccessToken = 'must-not-export'
            PasswordCredentials = @(
                [PSCustomObject]@{
                    KeyId = 'key-001'
                    DisplayName = 'metadata-only'
                    StartDateTime = '2026-01-01T00:00:00Z'
                    EndDateTime = '2027-01-01T00:00:00Z'
                    SecretText = 'must-not-export'
                }
            )
        }
    }

    function New-Rev42Approval {
        param(
            [string]$RunId = 'RUN-REV42-001',
            [string]$Status = 'Approved',
            [string]$ApprovedBy = 'approver@example.com',
            [string[]]$TargetObjectIds = @('sp-rev42-001'),
            [string[]]$ApprovedActions = @('SnapshotOnly', 'DeleteReadinessOnly'),
            [string]$ExpiresUtc = '2099-01-01T00:00:00Z',
            [bool]$Reusable = $false,
            [string]$SchemaVersion = '4.2'
        )
        [PSCustomObject]@{
            SchemaVersion = $SchemaVersion
            RunId = $RunId
            Status = $Status
            ApprovedBy = $ApprovedBy
            TargetObjectIds = $TargetObjectIds
            ApprovedActions = $ApprovedActions
            ExpiresUtc = $ExpiresUtc
            Reusable = $Reusable
        }
    }

    # ---- Rev4.3 sample path + helpers ----
    $script:Rev43SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-finaldelete-sp.sample.json'

    function New-Rev43GateInput {
        param(
            [string]$Stage = 'FinalDelete',
            [bool]$Allow = $true,
            [string]$TargetType = 'ServicePrincipal',
            [bool]$TargetPassed = $true,
            [bool]$ApprovalPassed = $true,
            [bool]$SnapshotPresent = $true,
            [string]$Readiness = 'Ready',
            [string]$ScreamStatus = 'Complete',
            [bool]$Override = $false,
            [bool]$DependencyPassed = $true,
            [bool]$QuerySucceeded = $true,
            [bool]$IsTestTenant = $true,
            [string]$Environment = 'Test',
            [bool]$WhatIf = $true,
            [bool]$DemoMode = $false
        )

        @{
            ExecutionStage = $Stage
            AllowFinalDelete = $Allow
            Plan = [PSCustomObject]@{
                SchemaVersion = '4.2'
                TargetId = 'sp-rev43-test-001'
                TargetType = $TargetType
                TestTenantGuard = [PSCustomObject]@{ IsTestTenant = $IsTestTenant; Environment = $Environment }
            }
            TargetValidation = [PSCustomObject]@{ Passed = $TargetPassed }
            ApprovalValidation = [PSCustomObject]@{ Passed = $ApprovalPassed }
            Snapshot = if ($SnapshotPresent) { [PSCustomObject]@{ SHA256 = ('a' * 64) } } else { $null }
            DeleteReadiness = [PSCustomObject]@{ Status = $Readiness }
            ScreamTest = [PSCustomObject]@{ Status = $ScreamStatus }
            DependencyCheck = [PSCustomObject]@{ Passed = $DependencyPassed; QuerySucceeded = $QuerySucceeded }
            ScreamTestOverrideApproved = $Override
            WhatIf = $WhatIf
            DemoMode = $DemoMode
        }
    }

    function Invoke-Rev43Gate {
        param([hashtable]$InputObject)
        $module = Get-Module NhiControlledDecommission
        & $module {
            param($GateInput)
            Test-NhiControlledServicePrincipalFinalDeleteGate @GateInput
        } $InputObject
    }

    # ---- Rev4.4 sample path + helpers ----
    $script:Rev44SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-finaldelete-application.sample.json'

    function New-Rev44GateInput {
        param(
            [string]$Stage = 'FinalDelete',
            [bool]$Allow = $true,
            [string]$TargetType = 'Application',
            [bool]$TargetPassed = $true,
            [bool]$ApprovalPassed = $true,
            [bool]$SnapshotPresent = $true,
            [string]$Readiness = 'Ready',
            [string]$ScreamStatus = 'Complete',
            [bool]$ScreamOverride = $false,
            [bool]$DependencyPassed = $true,
            [bool]$DependencyQuerySucceeded = $true,
            [bool]$RelationshipPresent = $true,
            [bool]$RelationshipQuerySucceeded = $true,
            [int]$ActiveServicePrincipalCount = 0,
            [int]$UnresolvedAppRoleAssignmentCount = 0,
            [int]$UnresolvedOAuthGrantCount = 0,
            [int]$ActiveCredentialCount = 0,
            [bool]$ActiveCredentialOverride = $false,
            [bool]$MultiTenant = $false,
            [bool]$PublisherEvidenceCaptured = $true,
            [bool]$OwnershipEvidenceCaptured = $true,
            [bool]$WhatIf = $true,
            [bool]$DemoMode = $false
        )

        $plan = [ordered]@{
            SchemaVersion = '4.2'
            TargetId = 'app-rev44-test-001'
            TargetType = $TargetType
        }
        if ($RelationshipPresent) {
            $plan.ApplicationRelationshipEvidence = [PSCustomObject]@{
                QuerySucceeded = $RelationshipQuerySucceeded
                ActiveServicePrincipalCount = $ActiveServicePrincipalCount
                UnresolvedAppRoleAssignmentCount = $UnresolvedAppRoleAssignmentCount
                UnresolvedOAuthGrantCount = $UnresolvedOAuthGrantCount
                ActiveCredentialCount = $ActiveCredentialCount
                MultiTenant = $MultiTenant
                PublisherEvidenceCaptured = $PublisherEvidenceCaptured
                OwnershipEvidenceCaptured = $OwnershipEvidenceCaptured
            }
        }

        @{
            ExecutionStage = $Stage
            AllowFinalDelete = $Allow
            Plan = [PSCustomObject]$plan
            TargetValidation = [PSCustomObject]@{ Passed = $TargetPassed }
            ApprovalValidation = [PSCustomObject]@{ Passed = $ApprovalPassed }
            Snapshot = if ($SnapshotPresent) { [PSCustomObject]@{ SHA256 = ('b' * 64) } } else { $null }
            DeleteReadiness = [PSCustomObject]@{ Status = $Readiness }
            ScreamTest = [PSCustomObject]@{ Status = $ScreamStatus }
            DependencyCheck = [PSCustomObject]@{ Passed = $DependencyPassed; QuerySucceeded = $DependencyQuerySucceeded }
            ScreamTestOverrideApproved = $ScreamOverride
            ActiveCredentialOverrideApproved = $ActiveCredentialOverride
            WhatIf = $WhatIf
            DemoMode = $DemoMode
        }
    }

    function Invoke-Rev44Gate {
        param([hashtable]$InputObject)
        $module = Get-Module NhiControlledDecommission
        & $module {
            param($GateInput)
            Test-NhiControlledApplicationDeleteReadinessGate @GateInput
        } $InputObject
    }

    # ---- Rev4.5-4.9 sample paths (per-revision state + helpers are defined in each ----
    # ---- revision's own wrapper Describe BeforeAll below, to avoid variable collisions) ----
    $script:Rev45SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-metadata-cleanup.sample.json'
    $script:Rev46SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-grants-cleanup.sample.json'
    $script:Rev47SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-managed-identity-readiness.sample.json'
    $script:Rev48SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-e2e-evidence-pack.sample.json'
    $script:Rev49SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-production-readiness.sample.json'
}

AfterAll {
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
}

# =============================================================================
# Rev4.2
# =============================================================================
Describe 'NhiControlledDecommission module contract' {
    $script:ExpectedExports = @(
        'Get-NhiControlledDecommissionSha256'
        'Get-NhiControlledDecommissionSchema'
        'ConvertTo-NhiControlledSnapshot'
        'Test-NhiControlledTarget'
        'Confirm-NhiControlledApproval'
        'Get-NhiControlledScreamTestStatus'
        'Test-NhiControlledDependencies'
        'Get-NhiControlledDeleteReadiness'
        'New-NhiControlledRollbackPlan'
        'New-NhiControlledDecommissionPlan'
        'Test-NhiControlledLabLiveReversibleDisableReadiness'
        'Export-NhiControlledDecommissionEvidence'
        'New-NhiControlledLabDisableDryRunPackage'
        'New-NhiControlledLabRollbackDrillPackage'
        'Invoke-NhiControlledLabLiveReversibleDisable'
        'New-NhiRun4CFinalGoNoGoReviewPackage'
        'New-NhiRun4CLiveEvidenceCapturePackage'
        'New-NhiRun4CPostDisableObservationPackage'
        'New-NhiRun4CRollbackExecutionReadinessPackage'
        'Invoke-NhiControlledLabRollback'
        'New-NhiFinalDeleteEligibilitySimulationPackage'
        'New-NhiRun4CEndToEndLabRehearsalReport'
        'New-NhiRun4CConsultantOperatingGuide'
        'Get-NhiRun4CArtifactRecord'
        'New-NhiRun4CFinalControlledDisableTestPackage'
        'New-NhiRun4CPostDisableEvidenceValidationPackage'
        'New-NhiRun4CControlledRollbackExecutionTestPackage'
        'New-NhiRun4CPostRollbackValidationPackage'
        'New-NhiRun4CFinalEvidenceBundle'
        'New-NhiRev4ReleaseCandidateFreezePackage'
    )

    It 'imports successfully' {
        Get-Module NhiControlledDecommission | Should -Not -BeNullOrEmpty
    }

    It 'exports the required public functions and keeps private helpers hidden' {
        $exports = (Get-Module NhiControlledDecommission).ExportedFunctions.Keys
        foreach ($name in $script:ExpectedExports) {
            $exports | Should -Contain $name
        }
        Get-Command New-NhiControlledE2EEvidencePack -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command New-NhiControlledOperatorDecisionLog -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'contains no live Graph write/delete cmdlet references' {
        # Guarded read-only state checks are allowed; this only blocks live write/delete or connection paths.
        (Get-Content $script:ModulePath -Raw) | Should -Not -Match 'Connect-MgGraph|Invoke-MgGraphRequest|(?:Update|Set|New|Remove)-Mg'
    }

    It 'contains no Graph request calls' {
        (Get-Content $script:ModulePath -Raw) | Should -Not -Match 'Invoke-MgGraphRequest'
    }
}

Describe 'Get-NhiControlledDecommissionSchema' {
    BeforeAll { $script:Schema = Get-NhiControlledDecommissionSchema }

    It 'uses schema version 4.2' {
        $script:Schema.ControlledDecommissionSchemaVersion | Should -Be '4.2'
        $script:Schema.ActionLogSchemaVersion | Should -Be '4.2'
        $script:Schema.SnapshotSchemaVersion | Should -Be '4.2'
        $script:Schema.DeleteReadinessSchemaVersion | Should -Be '4.2'
    }

    It 'supports only NHI target types' {
        $script:Schema.SupportedTargetTypes | Should -Contain 'ServicePrincipal'
        $script:Schema.SupportedTargetTypes | Should -Contain 'Application'
        $script:Schema.SupportedTargetTypes | Should -Contain 'ManagedIdentity'
        $script:Schema.SupportedTargetTypes | Should -Not -Contain 'User'
    }

    It 'lists FinalDelete but blocks live mutation' {
        $script:Schema.SupportedStages | Should -Contain 'FinalDelete'
        $script:Schema.LiveMutationEnabled | Should -BeFalse
        $script:Schema.FinalDeleteLiveEnabled | Should -BeFalse
    }
}

Describe 'Get-NhiControlledDecommissionSha256' {
    It 'is deterministic' {
        Get-NhiControlledDecommissionSha256 -InputString 'rev42' | Should -Be (Get-NhiControlledDecommissionSha256 -InputString 'rev42')
    }

    It 'changes when input changes' {
        Get-NhiControlledDecommissionSha256 -InputString 'rev42-a' | Should -Not -Be (Get-NhiControlledDecommissionSha256 -InputString 'rev42-b')
    }

    It 'returns 64 lowercase hexadecimal characters' {
        Get-NhiControlledDecommissionSha256 -InputString '' | Should -Match '^[0-9a-f]{64}$'
    }
}

Describe 'ConvertTo-NhiControlledSnapshot' {
    BeforeAll {
        $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target (New-Rev42Target) -RunId 'RUN-REV42-001'
        $script:SnapshotJson = $script:Snapshot | ConvertTo-Json -Depth 20
    }

    It 'creates versioned snapshot with hash' {
        $script:Snapshot.SchemaVersion | Should -Be '4.2'
        $script:Snapshot.RunId | Should -Be 'RUN-REV42-001'
        $script:Snapshot.SHA256 | Should -Match '^[0-9a-f]{64}$'
    }

    It 'preserves non-sensitive target state' {
        $script:Snapshot.Target.ObjectId | Should -Be 'sp-rev42-001'
        $script:Snapshot.Target.AccountEnabled | Should -BeTrue
    }

    It 'removes secret and token properties' {
        $script:SnapshotJson | Should -Not -Match 'must-not-export'
        $script:Snapshot.Target.PSObject.Properties.Name | Should -Not -Contain 'ClientSecret'
        $script:Snapshot.Target.PSObject.Properties.Name | Should -Not -Contain 'AccessToken'
    }

    It 'retains credential metadata only' {
        $script:Snapshot.Target.PasswordCredentials[0].KeyId | Should -Be 'key-001'
        $script:Snapshot.Target.PasswordCredentials[0].DisplayName | Should -Be 'metadata-only'
        ($script:Snapshot.Target.PasswordCredentials[0].PSObject.Properties.Name -contains 'SecretText') | Should -BeFalse
    }

    It 'redacts nested secrets in AdditionalProperties' {
        $target = New-Rev42Target
        $target | Add-Member -NotePropertyName AdditionalProperties -NotePropertyValue ([PSCustomObject]@{
            NestedSecret = 'must-not-export'
            Inner = [PSCustomObject]@{
                ChildToken = 'must-not-export'
            }
        }) -Force
        $target.PasswordCredentials[0] | Add-Member -NotePropertyName AdditionalProperties -NotePropertyValue ([PSCustomObject]@{
            NestedSecret = 'must-not-export'
            Inner = [PSCustomObject]@{
                ChildToken = 'must-not-export'
            }
        }) -Force

        $snapshot = ConvertTo-NhiControlledSnapshot -Target $target -RunId 'RUN-REV42-002'
        $snapshotJson = $snapshot | ConvertTo-Json -Depth 20

        $snapshot.Target.AdditionalProperties.PSObject.Properties.Name | Should -Not -Contain 'NestedSecret'
        $snapshot.Target.AdditionalProperties.Inner.PSObject.Properties.Name | Should -Not -Contain 'ChildToken'
        $snapshot.Target.PasswordCredentials[0].AdditionalProperties.PSObject.Properties.Name | Should -Not -Contain 'NestedSecret'
        $snapshotJson | Should -Not -Match 'must-not-export'
    }
}

Describe 'Test-NhiControlledTarget' {
    It 'passes a supported unprotected target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target)).Passed | Should -BeTrue
    }

    It 'blocks missing ObjectId' {
        $target = New-Rev42Target -ObjectId ''
        (Test-NhiControlledTarget -Target $target).Passed | Should -BeFalse
    }

    It 'blocks unsupported user target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -ObjectType User)).Passed | Should -BeFalse
    }

    It 'blocks protected target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -ProtectedObject $true)).Passed | Should -BeFalse
    }

    It 'blocks Microsoft first-party target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -MicrosoftFirstParty $true)).Passed | Should -BeFalse
    }

    It 'blocks emergency target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -EmergencyAccessIndicator $true)).Passed | Should -BeFalse
    }

    It 'blocks break-glass target' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -BreakGlassIndicator $true)).Passed | Should -BeFalse
    }

    It 'blocks active and ambiguous targets' {
        (Test-NhiControlledTarget -Target (New-Rev42Target -HighConfidenceActive $true)).Passed | Should -BeFalse
        (Test-NhiControlledTarget -Target (New-Rev42Target -Ambiguous $true)).Passed | Should -BeFalse
    }
}

Describe 'Confirm-NhiControlledApproval' {
    It 'passes exact valid approval' {
        $result = Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly'
        $result.Passed | Should -BeTrue
    }

    It 'blocks schema mismatch' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -SchemaVersion '4.1') -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
    }

    It 'blocks missing approver and non-approved status' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -ApprovedBy '') -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -Status Pending) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
    }

    It 'blocks RunId mismatch unless reusable' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -RunId OTHER) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -RunId OTHER -Reusable $true) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeTrue
    }

    It 'blocks expired approval' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval -ExpiresUtc '2020-01-01T00:00:00Z') -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'SnapshotOnly').Passed | Should -BeFalse
    }

    It 'blocks target and action mismatches' {
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId other -ActionType 'SnapshotOnly').Passed | Should -BeFalse
        (Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'DisableOnly').Passed | Should -BeFalse
    }

    It 'blocks FinalDelete even when approval includes it' {
        $approval = New-Rev42Approval -ApprovedActions @('SnapshotOnly', 'DeleteReadinessOnly', 'FinalDelete')
        $result = Confirm-NhiControlledApproval -Approval $approval -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'FinalDelete'
        $result.Passed | Should -BeFalse
        ($result.Reasons -join ' ') | Should -Match 'FinalDelete is not permitted in Rev4\.2-S1'
    }
}

Describe 'Get-NhiControlledScreamTestStatus' {
    It 'returns Active before window completes' {
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-2)) -WindowHours 24).Status | Should -Be 'Active'
    }

    It 'returns Complete after window completes' {
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24).Status | Should -Be 'Complete'
    }

    It 'returns Blocked for dependency or recent activity' {
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24 -DependencyDetected $true).Status | Should -Be 'Blocked'
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24 -RecentActivityDetected $true).Status | Should -Be 'Blocked'
    }

    It 'fails closed to Unknown when query failed' {
        (Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24 -QuerySucceeded $false).Status | Should -Be 'Unknown'
    }
}

Describe 'Dependency and delete-readiness evaluation' {
    It 'passes clean dependency evidence' {
        (Test-NhiControlledDependencies -Dependencies @() -RecentActivity @()).Passed | Should -BeTrue
    }

    It 'blocks critical dependency and recent activity' {
        (Test-NhiControlledDependencies -Dependencies @([PSCustomObject]@{ Severity = 'Critical' }) -RecentActivity @()).Passed | Should -BeFalse
        (Test-NhiControlledDependencies -Dependencies @() -RecentActivity @([PSCustomObject]@{ Id = 'activity-1' })).Passed | Should -BeFalse
    }

    It 'fails closed when dependency query fails' {
        (Test-NhiControlledDependencies -QuerySucceeded $false).Passed | Should -BeFalse
    }

    It 'returns Ready only when every gate passes' {
        $target = Test-NhiControlledTarget -Target (New-Rev42Target)
        $approval = Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'DeleteReadinessOnly'
        $snapshot = ConvertTo-NhiControlledSnapshot -Target (New-Rev42Target) -RunId 'RUN-REV42-001'
        $scream = Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24
        $deps = Test-NhiControlledDependencies
        (Get-NhiControlledDeleteReadiness -TargetValidation $target -ApprovalValidation $approval -Snapshot $snapshot -ScreamTest $scream -DependencyCheck $deps).Status | Should -Be 'Ready'
    }

    It 'never enables live FinalDelete' {
        $target = Test-NhiControlledTarget -Target (New-Rev42Target)
        $approval = Confirm-NhiControlledApproval -Approval (New-Rev42Approval) -RunId 'RUN-REV42-001' -TargetId 'sp-rev42-001' -ActionType 'DeleteReadinessOnly'
        $snapshot = ConvertTo-NhiControlledSnapshot -Target (New-Rev42Target) -RunId 'RUN-REV42-001'
        $scream = Get-NhiControlledScreamTestStatus -StartedUtc ([DateTime]::UtcNow.AddHours(-25)) -WindowHours 24
        $deps = Test-NhiControlledDependencies
        (Get-NhiControlledDeleteReadiness -TargetValidation $target -ApprovalValidation $approval -Snapshot $snapshot -ScreamTest $scream -DependencyCheck $deps).FinalDeleteLiveEnabled | Should -BeFalse
    }
}

Describe 'Planner, rollback, and evidence exports' {
    It 'creates planning-only snapshot plan' {
        $plan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage SnapshotOnly -RunId 'RUN-REV42-001'
        $plan.Status | Should -Be 'Planned'
        $plan.PlanningOnly | Should -BeTrue
        $plan.LiveMutationEnabled | Should -BeFalse
        $plan.FinalDeleteLiveEnabled | Should -BeFalse
    }

    It 'blocks FinalDelete in all S1 plans' {
        foreach ($mode in @(
            @{ WhatIf = $true; DemoMode = $false },
            @{ WhatIf = $false; DemoMode = $true },
            @{ WhatIf = $false; DemoMode = $false }
        )) {
            $plan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage FinalDelete -RunId 'RUN-REV42-001' -WhatIf $mode.WhatIf -DemoMode $mode.DemoMode
            $plan.Status | Should -Be 'Blocked'
            $plan.BlockReason | Should -Match 'blocked for live execution'
            $plan.LiveMutationEnabled | Should -BeFalse
        }
    }

    It 'blocks plans for protected targets' {
        (New-NhiControlledDecommissionPlan -Target (New-Rev42Target -ProtectedObject $true) -ExecutionStage SnapshotOnly -RunId 'RUN-REV42-001').Status | Should -Be 'Blocked'
    }

    It 'creates rollback plan linked to snapshot hash' {
        $snapshot = ConvertTo-NhiControlledSnapshot -Target (New-Rev42Target) -RunId 'RUN-REV42-001'
        $rollback = New-NhiControlledRollbackPlan -Snapshot $snapshot -RunId 'RUN-REV42-001'
        $rollback.RollbackAvailable | Should -BeTrue
        $rollback.SnapshotSHA256 | Should -Be $snapshot.SHA256
        $rollback.PlannedActions.Count | Should -Be 2
    }

    It 'exports UTF-8 JSON evidence' {
        $path = Join-Path $TestDrive 'evidence\plan.json'
        $plan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage SnapshotOnly -RunId 'RUN-REV42-001'
        Export-NhiControlledDecommissionEvidence -Evidence $plan -Path $path | Should -Be $path
        Test-Path $path | Should -BeTrue
        (Get-Content $path -Raw | ConvertFrom-Json).SchemaVersion | Should -Be '4.2'
    }
}

Describe 'Rev4.2-S1 sample artifacts' {
    BeforeAll {
        $script:PlanSampleRaw = Get-Content $script:PlanSamplePath -Raw
        $script:ApprovalSampleRaw = Get-Content $script:ApprovalSamplePath -Raw
        $script:PlanSample = $script:PlanSampleRaw | ConvertFrom-Json
        $script:ApprovalSample = $script:ApprovalSampleRaw | ConvertFrom-Json
    }

    It 'includes both required sample files' {
        Test-Path $script:PlanSamplePath | Should -BeTrue
        Test-Path $script:ApprovalSamplePath | Should -BeTrue
    }

    It 'parses both samples as valid JSON' {
        $script:PlanSample | Should -Not -BeNullOrEmpty
        $script:ApprovalSample | Should -Not -BeNullOrEmpty
    }

    It 'uses Rev4.2 schema in both samples' {
        $script:PlanSample.SchemaVersion | Should -Be '4.2'
        $script:ApprovalSample.SchemaVersion | Should -Be '4.2'
    }

    It 'binds approval and plan to the same RunId and target' {
        $script:ApprovalSample.RunId | Should -Be $script:PlanSample.RunId
        $script:ApprovalSample.TargetObjectIds | Should -Contain $script:PlanSample.TargetId
    }

    It 'keeps plan sample WhatIf Demo and planning-only' {
        $script:PlanSample.WhatIf | Should -BeTrue
        $script:PlanSample.DemoMode | Should -BeTrue
        $script:PlanSample.PlanningOnly | Should -BeTrue
        $script:PlanSample.LiveMutationEnabled | Should -BeFalse
    }

    It 'keeps approval sample evidence-only' {
        $script:ApprovalSample.LiveMutationApproved | Should -BeFalse
        $script:ApprovalSample.FinalDeleteApproved | Should -BeFalse
        $script:ApprovalSample.ApprovedActions | Should -Not -Contain 'FinalDelete'
        $script:ApprovalSample.ApprovedActions | Should -Not -Contain 'DisableOnly'
        $script:ApprovalSample.ApprovedActions | Should -Not -Contain 'TagOnly'
    }

    It 'contains a blocked FinalDelete action in the plan sample' {
        $finalDelete = $script:PlanSample.Actions | Where-Object { $_.ActionType -eq 'FinalDelete' }
        $finalDelete | Should -Not -BeNullOrEmpty
        $finalDelete.Result | Should -Be 'Blocked'
        $finalDelete.Warnings -join ' ' | Should -Match 'blocked for live execution'
    }

    It 'never enables FinalDelete in plan readiness evidence' {
        $script:PlanSample.FinalDeleteLiveEnabled | Should -BeFalse
        $script:PlanSample.DeleteReadiness.FinalDeleteLiveEnabled | Should -BeFalse
    }

    It 'contains no secret token or certificate values' {
        foreach ($raw in @($script:PlanSampleRaw, $script:ApprovalSampleRaw)) {
            $raw | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        }
    }

    It 'contains no prohibited Graph delete cmdlet names' {
        $script:PlanSampleRaw | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication'
        $script:ApprovalSampleRaw | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication'
    }

    It 'validates sample approval for DeleteReadinessOnly' {
        $result = Confirm-NhiControlledApproval -Approval $script:ApprovalSample -RunId $script:PlanSample.RunId -TargetId $script:PlanSample.TargetId -ActionType 'DeleteReadinessOnly'
        $result.Passed | Should -BeTrue
    }

    It 'rejects sample approval for FinalDelete' {
        $result = Confirm-NhiControlledApproval -Approval $script:ApprovalSample -RunId $script:PlanSample.RunId -TargetId $script:PlanSample.TargetId -ActionType 'FinalDelete'
        $result.Passed | Should -BeFalse
    }

    It 'produces evidence-only WhatIf and Demo plans' {
        $whatIfPlan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage SnapshotOnly -RunId 'RUN-WHATIF' -WhatIf $true
        $demoPlan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage SnapshotOnly -RunId 'RUN-DEMO' -WhatIf $false -DemoMode $true
        foreach ($plan in @($whatIfPlan, $demoPlan)) {
            $plan.PlanningOnly | Should -BeTrue
            $plan.LiveMutationEnabled | Should -BeFalse
        }
    }

    It 'blocks FinalDelete for WhatIf Demo and live-mode plan requests' {
        foreach ($settings in @(
            @{ RunId = 'RUN-WHATIF-FD'; WhatIf = $true; DemoMode = $false },
            @{ RunId = 'RUN-DEMO-FD'; WhatIf = $false; DemoMode = $true },
            @{ RunId = 'RUN-LIVE-FD'; WhatIf = $false; DemoMode = $false }
        )) {
            $plan = New-NhiControlledDecommissionPlan -Target (New-Rev42Target) -ExecutionStage FinalDelete -RunId $settings.RunId -WhatIf $settings.WhatIf -DemoMode $settings.DemoMode
            $plan.Status | Should -Be 'Blocked'
            $plan.LiveMutationEnabled | Should -BeFalse
        }
    }
}

# =============================================================================
# Rev4.3
# =============================================================================
Describe 'Rev4.3 Service Principal FinalDelete guard contract' {
    It 'keeps the Rev4.3 gate evaluator private to preserve the frozen public contract' {
        Get-Command Test-NhiControlledServicePrincipalFinalDeleteGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        $exports = (Get-Module NhiControlledDecommission).ExportedFunctions.Keys
        $exports | Should -Contain 'Test-NhiControlledTarget'
        $exports | Should -Contain 'New-NhiControlledDecommissionPlan'
        $exports | Should -Contain 'ConvertTo-NhiControlledSnapshot'
    }

    It 'satisfies gates only as simulation when all required inputs pass' {
        $result = Invoke-Rev43Gate (New-Rev43GateInput)
        $result.GatesPassed | Should -BeTrue
        $result.Status | Should -Be 'GuardSatisfiedSimulationOnly'
    }

    It 'never enables live delete when all gates pass' {
        $result = Invoke-Rev43Gate (New-Rev43GateInput)
        $result.LiveDeleteExecutable | Should -BeFalse
        $result.DeleteCmdletAvailable | Should -BeFalse
        $result.SimulationOnly | Should -BeTrue
    }

    It 'supports DemoMode simulation without live delete' {
        $result = Invoke-Rev43Gate (New-Rev43GateInput -WhatIf $false -DemoMode $true)
        $result.GatesPassed | Should -BeTrue
        $result.LiveDeleteExecutable | Should -BeFalse
    }

    It 'blocks unattended non-WhatIf non-Demo requests' {
        $result = Invoke-Rev43Gate (New-Rev43GateInput -WhatIf $false -DemoMode $false)
        $result.GatesPassed | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match 'WhatIf or DemoMode'
    }

    It 'allows an explicitly approved scream-test override' {
        $result = Invoke-Rev43Gate (New-Rev43GateInput -ScreamStatus Active -Override $true)
        $result.GatesPassed | Should -BeTrue
        $result.LiveDeleteExecutable | Should -BeFalse
    }
}

Describe 'Rev4.3 required gate failures' {
    It 'blocks <Name>' -ForEach @(
        @{ Name = 'missing FinalDelete stage'; Values = @{ Stage = 'DeleteReadinessOnly' }; Pattern = 'ExecutionStage FinalDelete' }
        @{ Name = 'missing AllowFinalDelete'; Values = @{ Allow = $false }; Pattern = 'AllowFinalDelete' }
        @{ Name = 'non-ServicePrincipal target'; Values = @{ TargetType = 'Application' }; Pattern = 'ServicePrincipal' }
        @{ Name = 'failed target validation'; Values = @{ TargetPassed = $false }; Pattern = 'Target validation' }
        @{ Name = 'invalid exact approval'; Values = @{ ApprovalPassed = $false }; Pattern = 'Exact FinalDelete approval' }
        @{ Name = 'missing snapshot'; Values = @{ SnapshotPresent = $false }; Pattern = 'Snapshot evidence' }
        @{ Name = 'partial delete-readiness'; Values = @{ Readiness = 'Partial' }; Pattern = 'Delete-readiness must be Ready' }
        @{ Name = 'blocked delete-readiness'; Values = @{ Readiness = 'Blocked' }; Pattern = 'Delete-readiness must be Ready' }
        @{ Name = 'active scream-test'; Values = @{ ScreamStatus = 'Active' }; Pattern = 'Scream-test must be Complete' }
        @{ Name = 'unknown scream-test'; Values = @{ ScreamStatus = 'Unknown' }; Pattern = 'Scream-test must be Complete' }
        @{ Name = 'unresolved dependency'; Values = @{ DependencyPassed = $false }; Pattern = 'Dependency recheck must be clean' }
        @{ Name = 'failed dependency query'; Values = @{ QuerySucceeded = $false }; Pattern = 'Dependency recheck must be clean' }
        @{ Name = 'non-test tenant'; Values = @{ IsTestTenant = $false }; Pattern = 'Test-tenant guard metadata' }
        @{ Name = 'non-test environment'; Values = @{ Environment = 'Production' }; Pattern = 'Test-tenant guard metadata' }
        @{ Name = 'unattended live-mode request'; Values = @{ WhatIf = $false; DemoMode = $false }; Pattern = 'WhatIf or DemoMode' }
    ) {
        $input = New-Rev43GateInput @Values
        $result = Invoke-Rev43Gate $input
        $result.GatesPassed | Should -BeFalse
        $result.Status | Should -Be 'Blocked'
        $result.LiveDeleteExecutable | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match $Pattern
    }
}

Describe 'Rev4.3 protected-target gates' {
    It 'blocks <Name> through target validation' -ForEach @(
        @{ Name = 'Microsoft first-party target'; Target = @{ ObjectId='sp-1'; ObjectType='ServicePrincipal'; MicrosoftFirstParty=$true } }
        @{ Name = 'protected target'; Target = @{ ObjectId='sp-1'; ObjectType='ServicePrincipal'; ProtectedObject=$true } }
        @{ Name = 'emergency target'; Target = @{ ObjectId='sp-1'; ObjectType='ServicePrincipal'; EmergencyAccessIndicator=$true } }
        @{ Name = 'break-glass target'; Target = @{ ObjectId='sp-1'; ObjectType='ServicePrincipal'; BreakGlassIndicator=$true } }
        @{ Name = 'active target'; Target = @{ ObjectId='sp-1'; ObjectType='ServicePrincipal'; HighConfidenceActive=$true } }
        @{ Name = 'ambiguous target'; Target = @{ ObjectId='sp-1'; ObjectType='ServicePrincipal'; Ambiguous=$true } }
    ) {
        $validation = Test-NhiControlledTarget -Target ([PSCustomObject]$Target)
        $validation.Passed | Should -BeFalse
        $input = New-Rev43GateInput -TargetPassed $validation.Passed
        (Invoke-Rev43Gate $input).GatesPassed | Should -BeFalse
    }
}

Describe 'Rev4.3 sample FinalDelete simulation artifact' {
    BeforeAll {
        $script:RawSample = Get-Content -LiteralPath $script:Rev43SamplePath -Raw
        $script:Sample = $script:RawSample | ConvertFrom-Json
    }

    # Merged: "exists and parses as JSON" -> moved to the shared "Rev4.3-Rev4.4 sample artifacts
    # parse cleanly" Describe near the end of this file (union with Rev4.4's own sample).
    # Merged: "contains no secret-like values or delete cmdlet names" -> moved to the shared
    # "Rev4.3-Rev4.8 sample hygiene" Describe near the end of this file.

    It 'is ServicePrincipal-only' {
        $script:Sample.TargetType | Should -Be 'ServicePrincipal'
    }

    It 'contains exact FinalDelete approval' {
        $script:Sample.TargetObjectIds | Should -Contain $script:Sample.TargetId
        $script:Sample.ApprovedActions | Should -Contain 'FinalDelete'
        $script:Sample.FinalDeleteApproved | Should -BeTrue
    }

    It 'contains test-tenant guard metadata' {
        $script:Sample.TestTenantGuard.IsTestTenant | Should -BeTrue
        $script:Sample.TestTenantGuard.Environment | Should -Be 'Test'
        $script:Sample.TestTenantGuard.LiveDeleteDuringBuild | Should -BeFalse
    }

    It 'keeps live mutation and delete disabled' {
        $script:Sample.LiveMutationApproved | Should -BeFalse
        $script:Sample.LiveDeleteExecutable | Should -BeFalse
        $script:Sample.SimulationOnly | Should -BeTrue
    }
}

# =============================================================================
# Rev4.4
# =============================================================================
Describe 'Rev4.4 Application delete-readiness contract' {
    It 'keeps the evaluator private and public export contract frozen' {
        Get-Command Test-NhiControlledApplicationDeleteReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        $exports = (Get-Module NhiControlledDecommission).ExportedFunctions.Keys
        $exports | Should -Contain 'Test-NhiControlledTarget'
        $exports | Should -Contain 'New-NhiControlledDecommissionPlan'
        $exports | Should -Contain 'ConvertTo-NhiControlledSnapshot'
    }

    It 'satisfies readiness only as simulation when every gate passes' {
        $result = Invoke-Rev44Gate (New-Rev44GateInput)
        $result.GatesPassed | Should -BeTrue
        $result.Status | Should -Be 'ReadinessSatisfiedSimulationOnly'
    }

    It 'never enables Application deletion when every gate passes' {
        $result = Invoke-Rev44Gate (New-Rev44GateInput)
        $result.LiveDeleteExecutable | Should -BeFalse
        $result.DeleteCmdletAvailable | Should -BeFalse
        $result.SimulationOnly | Should -BeTrue
    }

    It 'supports DemoMode readiness simulation only' {
        $result = Invoke-Rev44Gate (New-Rev44GateInput -WhatIf $false -DemoMode $true)
        $result.GatesPassed | Should -BeTrue
        $result.LiveDeleteExecutable | Should -BeFalse
    }

    It 'allows explicitly approved active credential override' {
        (Invoke-Rev44Gate (New-Rev44GateInput -ActiveCredentialCount 1 -ActiveCredentialOverride $true)).GatesPassed | Should -BeTrue
    }

    It 'allows explicitly approved scream-test override' {
        (Invoke-Rev44Gate (New-Rev44GateInput -ScreamStatus Active -ScreamOverride $true)).GatesPassed | Should -BeTrue
    }
}

Describe 'Rev4.4 required readiness gate failures' {
    It 'blocks <Name>' -ForEach @(
        @{ Name='missing FinalDelete stage'; Values=@{ Stage='DeleteReadinessOnly' }; Pattern='ExecutionStage FinalDelete' }
        @{ Name='missing AllowFinalDelete'; Values=@{ Allow=$false }; Pattern='AllowFinalDelete' }
        @{ Name='non-Application target'; Values=@{ TargetType='ServicePrincipal' }; Pattern='Target type must be Application' }
        @{ Name='failed target validation'; Values=@{ TargetPassed=$false }; Pattern='Target validation' }
        @{ Name='invalid exact approval'; Values=@{ ApprovalPassed=$false }; Pattern='Exact Application FinalDelete approval' }
        @{ Name='missing snapshot'; Values=@{ SnapshotPresent=$false }; Pattern='Snapshot evidence' }
        @{ Name='partial readiness'; Values=@{ Readiness='Partial' }; Pattern='Delete-readiness must be Ready' }
        @{ Name='blocked readiness'; Values=@{ Readiness='Blocked' }; Pattern='Delete-readiness must be Ready' }
        @{ Name='active scream-test'; Values=@{ ScreamStatus='Active' }; Pattern='Scream-test must be Complete' }
        @{ Name='failed general dependency'; Values=@{ DependencyPassed=$false }; Pattern='General dependency recheck' }
        @{ Name='unknown general dependency'; Values=@{ DependencyQuerySucceeded=$false }; Pattern='General dependency recheck' }
        @{ Name='missing relationship evidence'; Values=@{ RelationshipPresent=$false }; Pattern='relationship evidence is required' }
        @{ Name='failed relationship query'; Values=@{ RelationshipQuerySucceeded=$false }; Pattern='relationship evidence query must succeed' }
        @{ Name='active service principal dependency'; Values=@{ ActiveServicePrincipalCount=1 }; Pattern='Active service principal dependency' }
        @{ Name='app role assignment dependency'; Values=@{ UnresolvedAppRoleAssignmentCount=1 }; Pattern='app role assignment dependency' }
        @{ Name='OAuth grant dependency'; Values=@{ UnresolvedOAuthGrantCount=1 }; Pattern='OAuth grant dependency' }
        @{ Name='active credential dependency'; Values=@{ ActiveCredentialCount=1 }; Pattern='Active credential dependency' }
        @{ Name='multi-tenant application'; Values=@{ MultiTenant=$true }; Pattern='Multi-tenant Application' }
        @{ Name='missing publisher evidence'; Values=@{ PublisherEvidenceCaptured=$false }; Pattern='publisher evidence' }
        @{ Name='missing ownership evidence'; Values=@{ OwnershipEvidenceCaptured=$false }; Pattern='Ownership evidence' }
        @{ Name='unattended live-mode request'; Values=@{ WhatIf=$false; DemoMode=$false }; Pattern='WhatIf or DemoMode' }
    ) {
        $result = Invoke-Rev44Gate (New-Rev44GateInput @Values)
        $result.GatesPassed | Should -BeFalse
        $result.Status | Should -Be 'Blocked'
        $result.LiveDeleteExecutable | Should -BeFalse
        $result.Reasons -join ' ' | Should -Match $Pattern
    }
}

Describe 'Rev4.4 Application sample artifact' {
    BeforeAll {
        $script:RawSample = Get-Content -LiteralPath $script:Rev44SamplePath -Raw
        $script:Sample = $script:RawSample | ConvertFrom-Json
    }

    # Merged: "exists and parses as JSON" -> moved to the shared "Rev4.3-Rev4.4 sample artifacts
    # parse cleanly" Describe near the end of this file (union with Rev4.3's own sample).
    # Merged: "contains no secret-like values or delete cmdlet names" -> moved to the shared
    # "Rev4.3-Rev4.8 sample hygiene" Describe near the end of this file.

    It 'targets an Application' {
        $script:Sample.TargetType | Should -Be 'Application'
    }

    It 'contains exact Application FinalDelete approval' {
        $script:Sample.TargetObjectIds | Should -Contain $script:Sample.TargetId
        $script:Sample.ApprovedActions | Should -Contain 'FinalDelete'
        $script:Sample.ApplicationFinalDeleteApproved | Should -BeTrue
    }

    It 'contains clean relationship evidence' {
        $evidence = $script:Sample.ApplicationRelationshipEvidence
        $evidence.QuerySucceeded | Should -BeTrue
        $evidence.ActiveServicePrincipalCount | Should -Be 0
        $evidence.UnresolvedAppRoleAssignmentCount | Should -Be 0
        $evidence.UnresolvedOAuthGrantCount | Should -Be 0
        $evidence.ActiveCredentialCount | Should -Be 0
    }

    It 'captures publisher and ownership evidence' {
        $script:Sample.ApplicationRelationshipEvidence.PublisherEvidenceCaptured | Should -BeTrue
        $script:Sample.ApplicationRelationshipEvidence.OwnershipEvidenceCaptured | Should -BeTrue
    }

    It 'blocks multi-tenant and live delete defaults' {
        $script:Sample.ApplicationRelationshipEvidence.MultiTenant | Should -BeFalse
        $script:Sample.LiveDeleteExecutable | Should -BeFalse
        $script:Sample.LiveMutationApproved | Should -BeFalse
    }
}

# =============================================================================
# Rev4.5 (wrapper Describe: nested BeforeAll re-establishes the generically-named
# $script:Target/$script:TargetValidation/$script:Snapshot/$script:RawSample/$script:Sample
# state that Rev4.5's original file set at file scope, immediately before Rev4.5's own
# Describes run -- see the file-level header comment for why this wrapper exists.)
# =============================================================================
Describe 'Rev4.5 metadata cleanup gate suite' {
    BeforeAll {
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
        $script:RawSample = Get-Content -LiteralPath $script:Rev45SamplePath -Raw
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

    Describe 'Rev4.5 metadata cleanup contract' {
        It 'keeps the private evaluator hidden and export contract frozen' {
            Get-Command Test-NhiControlledMetadataCleanupReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $exports = (Get-Module NhiControlledDecommission).ExportedCommands.Keys
            $exports | Should -Contain 'Test-NhiControlledTarget'
            $exports | Should -Contain 'New-NhiControlledDecommissionPlan'
            $exports | Should -Contain 'ConvertTo-NhiControlledSnapshot'
        }

        It 'parses the metadata sample JSON' {
            $script:Sample | Should -Not -BeNullOrEmpty
            $script:Sample.SchemaVersion | Should -Be '4.5'
            $script:Sample.TargetType | Should -Be 'ServicePrincipal'
        }

        # Merged: "contains no secret-like values or delete cmdlet names" -> moved to the shared
        # "Rev4.3-Rev4.8 sample hygiene" Describe near the end of this file.

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
}

# =============================================================================
# Rev4.6 (wrapper Describe -- see Rev4.5 header comment above for rationale)
# =============================================================================
Describe 'Rev4.6 grants cleanup gate suite' {
    BeforeAll {
        $script:Target = [PSCustomObject]@{
            ObjectId = 'app-rev46-test-001'
            ObjectType = 'Application'
            DisplayName = 'Rev46 Test Application'
            ProtectedObject = $false
            MicrosoftFirstParty = $false
            EmergencyAccessIndicator = $false
            BreakGlassIndicator = $false
            HighConfidenceActive = $false
            Ambiguous = $false
        }
        $script:TargetValidation = Test-NhiControlledTarget -Target $script:Target
        $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target $script:Target -RunId 'RUN-REV46-GRANTS-SAMPLE-001'
        $script:RawSample = Get-Content -LiteralPath $script:Rev46SamplePath -Raw
        $script:Sample = $script:RawSample | ConvertFrom-Json

        function New-Rev46Plan {
            param([hashtable]$Overrides = @{})
            $plan = [ordered]@{
                SchemaVersion = '4.6'
                RunId = 'RUN-REV46-GRANTS-SAMPLE-001'
                TargetId = 'app-rev46-test-001'
                TargetObjectId = 'app-rev46-test-001'
                TargetType = 'Application'
                RelatedObjectType = 'OAuthGrant'
                RelatedObjectId = 'oauth-grant-rev46-test-001'
                ResourceAppId = '00000003-0000-0000-c000-000000000000'
                PrincipalId = 'principal-rev46-test-001'
                PermissionName = 'User.Read'
                CleanupScope = 'Narrow'
                TargetAmbiguous = $false
                ApprovalId = 'APP-REV46-GRANTS-001'
                ApprovedActions = @('GrantCleanupReadiness')
                DependencyRecheck = [PSCustomObject]@{
                    Status = 'Clean'
                    QuerySucceeded = $true
                    Blocked = $false
                    SkippedWithApproval = $false
                }
                CleanupReadiness = [PSCustomObject]@{ Status = 'Ready' }
                PostCleanupValidationStatus = 'Simulated'
                ScreamTestEvidence = [PSCustomObject]@{
                    EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                    Status = 'Complete'
                    DependencyDetected = $false
                    RecentActivityDetected = $false
                    QuerySucceeded = $true
                }
                DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
                LiveCleanupApproved = $false
                LiveCleanupExecutable = $false
            }
            foreach ($key in $Overrides.Keys) { $plan[$key] = $Overrides[$key] }
            [PSCustomObject]$plan
        }

        function New-Rev46Approval {
            param([hashtable]$Overrides = @{})
            $approval = [ordered]@{
                SchemaVersion = '4.6'
                RunId = 'RUN-REV46-GRANTS-SAMPLE-001'
                Status = 'Approved'
                ApprovedBy = 'grants-cleanup-approver@example.com'
                ExpiresUtc = '2099-01-01T00:00:00Z'
                Reusable = $false
                ApprovalId = 'APP-REV46-GRANTS-001'
                TargetId = 'app-rev46-test-001'
                TargetObjectId = 'app-rev46-test-001'
                TargetType = 'Application'
                RelatedObjectType = 'OAuthGrant'
                RelatedObjectId = 'oauth-grant-rev46-test-001'
                ResourceAppId = '00000003-0000-0000-c000-000000000000'
                PrincipalId = 'principal-rev46-test-001'
                PermissionName = 'User.Read'
                CleanupScope = 'Narrow'
                TargetAmbiguous = $false
                ApprovedActions = @('GrantCleanupReadiness')
                LiveCleanupApproved = $false
                LiveCleanupExecutable = $false
            }
            foreach ($key in $Overrides.Keys) { $approval[$key] = $Overrides[$key] }
            [PSCustomObject]$approval
        }

        function New-Rev46GateInput {
            param(
                [hashtable]$PlanOverrides = @{},
                [hashtable]$ApprovalOverrides = @{},
                [string]$Stage = 'GrantCleanupReadiness',
                [bool]$TargetPassed = $true,
                [bool]$SnapshotPresent = $true,
                [bool]$WhatIf = $true,
                [bool]$DemoMode = $false,
                [bool]$IncludeSnapshotId = $true
            )

            $plan = New-Rev46Plan -Overrides $PlanOverrides
            $snapshot = if ($SnapshotPresent) { $script:Snapshot } else { $null }
            $approvalOverrides = @{}
            foreach ($key in $ApprovalOverrides.Keys) { $approvalOverrides[$key] = $ApprovalOverrides[$key] }
            if (-not $approvalOverrides.ContainsKey('SnapshotId')) {
                $approvalOverrides['SnapshotId'] = if ($IncludeSnapshotId -and $snapshot) { $snapshot.SHA256 } else { $null }
            }
            $approval = New-Rev46Approval -Overrides $approvalOverrides

            @{
                ExecutionStage = $Stage
                Plan = $plan
                Approval = $approval
                TargetValidation = if ($TargetPassed) { $script:TargetValidation } else { [PSCustomObject]@{ Passed = $false; Reasons = @('Target validation failed.') } }
                Snapshot = $snapshot
                DependencyRecheck = if ($null -ne $plan.DependencyRecheck) { $plan.DependencyRecheck } else { [PSCustomObject]@{ Status = 'Unknown'; QuerySucceeded = $false; Blocked = $false; SkippedWithApproval = $false } }
                WhatIf = $WhatIf
                DemoMode = $DemoMode
            }
        }

        function Invoke-Rev46Gate {
            param([hashtable]$InputObject)
            $module = Get-Module NhiControlledDecommission
            & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } $InputObject
        }

        function Invoke-Rev46Module {
            param(
                [scriptblock]$ScriptBlock,
                [Parameter(ValueFromRemainingArguments = $true)]
                [object[]]$Arguments
            )
            $module = Get-Module NhiControlledDecommission
            & $module $ScriptBlock @Arguments
        }
    }

    Describe 'Rev4.6 grants cleanup contract' {
        It 'keeps the private evaluator hidden and export contract frozen' {
            Get-Command Test-NhiControlledGrantCleanupReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $exports = (Get-Module NhiControlledDecommission).ExportedCommands.Keys
            $exports | Should -Contain 'Test-NhiControlledTarget'
            $exports | Should -Contain 'New-NhiControlledDecommissionPlan'
            $exports | Should -Contain 'ConvertTo-NhiControlledSnapshot'
        }

        It 'parses the grants cleanup sample JSON' {
            $script:Sample | Should -Not -BeNullOrEmpty
            $script:Sample.SchemaVersion | Should -Be '4.6'
            $script:Sample.TargetType | Should -Be 'Application'
        }

        # Merged: "contains no secret-like values or delete cmdlet names" -> moved to the shared
        # "Rev4.3-Rev4.8 sample hygiene" Describe near the end of this file.

        It 'captures exact related-object evidence in the sample' {
            $script:Sample.RelatedObjectType | Should -Be 'OAuthGrant'
            $script:Sample.RelatedObjectId | Should -Be 'oauth-grant-rev46-test-001'
            $script:Sample.DependencyRecheck.Status | Should -Be 'Clean'
        }

        It 'returns the expected dependency recheck statuses' {
            (Invoke-Rev46Module { param($QuerySucceeded, $Blocked, $SkippedWithApproval) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $QuerySucceeded -Blocked $Blocked -SkippedWithApproval $SkippedWithApproval } $true $false $false).Status | Should -Be 'Clean'
            (Invoke-Rev46Module { param($QuerySucceeded, $Blocked, $SkippedWithApproval) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $QuerySucceeded -Blocked $Blocked -SkippedWithApproval $SkippedWithApproval } $true $true $false).Status | Should -Be 'Blocked'
            (Invoke-Rev46Module { param($QuerySucceeded, $Blocked, $SkippedWithApproval) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $QuerySucceeded -Blocked $Blocked -SkippedWithApproval $SkippedWithApproval } $false $false $false).Status | Should -Be 'Unknown'
            (Invoke-Rev46Module { param($QuerySucceeded, $Blocked, $SkippedWithApproval) Get-NhiControlledDependencyRecheckStatus -QuerySucceeded $QuerySucceeded -Blocked $Blocked -SkippedWithApproval $SkippedWithApproval } $true $false $true).Status | Should -Be 'SkippedWithApproval'
        }

        It 'returns the expected post-cleanup validation states' {
            $result = Invoke-Rev46Gate (New-Rev46GateInput)
            $result.PostCleanupValidation.Status | Should -Be 'Simulated'
            $result.LiveCleanupExecutable | Should -BeFalse
        }

        It 'generates grants cleanup plan and action log objects' {
            $gate = Invoke-Rev46Gate (New-Rev46GateInput)
            $plan = Invoke-Rev46Module {
                param($Plan, $DependencyRecheck, $Readiness)
                New-NhiControlledGrantCleanupPlan -Plan $Plan -DependencyRecheck $DependencyRecheck -Readiness $Readiness
            } (New-Rev46Plan) (New-Rev46Plan).DependencyRecheck $gate
            $actionLog = Invoke-Rev46Module {
                param($Plan, $DependencyRecheck, $Readiness)
                New-NhiControlledGrantCleanupActionLog -Plan $Plan -DependencyRecheck $DependencyRecheck -Readiness $Readiness
            } (New-Rev46Plan) (New-Rev46Plan).DependencyRecheck $gate
            $plan.Status | Should -Be 'Planned'
            $actionLog.Result | Should -Be 'SimulationOnly'
        }

        It 'satisfies readiness only as simulation when every gate passes' {
            $result = Invoke-Rev46Gate (New-Rev46GateInput)
            $result.GatesPassed | Should -BeTrue
            $result.Status | Should -Be 'GrantCleanupSatisfiedSimulationOnly'
        }

        It 'never enables live grant cleanup when every gate passes' {
            $result = Invoke-Rev46Gate (New-Rev46GateInput)
            $result.LiveCleanupExecutable | Should -BeFalse
            $result.CleanupCmdletAvailable | Should -BeFalse
            $result.SimulationOnly | Should -BeTrue
        }

        It 'supports DemoMode readiness simulation only' {
            $result = Invoke-Rev46Gate (New-Rev46GateInput -DemoMode $true -WhatIf $false)
            $result.GatesPassed | Should -BeTrue
            $result.PostCleanupValidation.Status | Should -Be 'Simulated'
        }

        It 'supports WhatIf readiness simulation only' {
            $result = Invoke-Rev46Gate (New-Rev46GateInput -WhatIf $true)
            $result.GatesPassed | Should -BeTrue
            $result.WhatIf | Should -BeTrue
        }

        It 'keeps post-cleanup validation simulated or not run only' {
            $whatIfResult = Invoke-Rev46Gate (New-Rev46GateInput -WhatIf $true)
            $nonWhatIfResult = Invoke-Rev46Gate (New-Rev46GateInput -WhatIf $false -DemoMode $true)
            $whatIfResult.PostCleanupValidation.Status | Should -Be 'Simulated'
            $nonWhatIfResult.PostCleanupValidation.Status | Should -Be 'Simulated'
        }
    }

    Describe 'Rev4.6 required gate failures' {
        It 'blocks <Name>' -ForEach @(
            @{ Name = 'missing stage'; Build = { New-Rev46GateInput -Stage 'DeleteReadinessOnly' }; Pattern = 'GrantCleanupReadiness' }
            @{ Name = 'wrong schema'; Build = { New-Rev46GateInput -PlanOverrides @{ SchemaVersion = '4.5' } }; Pattern = 'Valid grant cleanup plan is required' }
            @{ Name = 'missing target id'; Build = { New-Rev46GateInput -PlanOverrides @{ TargetObjectId = '' } }; Pattern = 'Exact related object binding is required' }
            @{ Name = 'missing related id'; Build = { New-Rev46GateInput -PlanOverrides @{ RelatedObjectId = '' } }; Pattern = 'Exact related object binding is required' }
            @{ Name = 'unsupported related type'; Build = { New-Rev46GateInput -PlanOverrides @{ RelatedObjectType = 'UnsupportedType' } }; Pattern = 'Unsupported related object type' }
            @{ Name = 'dependency blocked'; Build = { New-Rev46GateInput -PlanOverrides @{ DependencyRecheck = [PSCustomObject]@{ Status = 'Blocked'; QuerySucceeded = $true; Blocked = $true; SkippedWithApproval = $false } } }; Pattern = 'Dependency recheck blocks cleanup' }
            @{ Name = 'dependency unknown'; Build = { New-Rev46GateInput -PlanOverrides @{ DependencyRecheck = [PSCustomObject]@{ Status = 'Unknown'; QuerySucceeded = $false; Blocked = $false; SkippedWithApproval = $false } } }; Pattern = 'Dependency recheck blocks cleanup' }
            @{ Name = 'target ambiguous'; Build = { New-Rev46GateInput -PlanOverrides @{ TargetAmbiguous = $true } }; Pattern = 'Target ambiguity blocks cleanup' }
            @{ Name = 'broad cleanup'; Build = { New-Rev46GateInput -PlanOverrides @{ CleanupScope = 'Broad'; Scope = 'User.Read' } -ApprovalOverrides @{ Scope = 'Mail.Read' } }; Pattern = 'broaden from one related object to many' }
            @{ Name = 'target validation failed'; Build = { New-Rev46GateInput -TargetPassed $false }; Pattern = 'Target validation failed' }
            @{ Name = 'unattended live-mode request'; Build = { New-Rev46GateInput -WhatIf $false -DemoMode $false }; Pattern = 'WhatIf or DemoMode' }
        ) {
            $result = Invoke-Rev46Gate (& $Build)
            $result.GatesPassed | Should -BeFalse
            $result.Status | Should -Be 'Blocked'
            $result.LiveCleanupExecutable | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match $Pattern
        }

        It 'blocks approval id missing' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan -Overrides @{ Scope = 'User.Read' })
                Approval = (New-Rev46Approval -Overrides @{ ApprovalId = '' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Exact approval is required'
        }

        It 'blocks approval not approved' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan -Overrides @{ Scope = 'User.Read' })
                Approval = (New-Rev46Approval -Overrides @{ Status = 'Pending' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
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
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan -Overrides @{ Scope = 'User.Read' })
                Approval = (New-Rev46Approval -Overrides @{ TargetObjectId = 'wrong-target' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'TargetObjectId mismatch blocks cleanup'
        }

        It 'blocks approval related mismatch' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan)
                Approval = (New-Rev46Approval -Overrides @{ RelatedObjectId = 'wrong-related' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'RelatedObjectId mismatch blocks cleanup'
        }

        It 'blocks approval type mismatch' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan)
                Approval = (New-Rev46Approval -Overrides @{ RelatedObjectType = 'AppRoleAssignment' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'RelatedObjectType mismatch blocks cleanup'
        }

        It 'blocks approval action missing' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan)
                Approval = (New-Rev46Approval -Overrides @{ ApprovedActions = @('SomethingElse') })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'specifically authorize the cleanup action'
        }

        It 'blocks resource app mismatch' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan)
                Approval = (New-Rev46Approval -Overrides @{ ResourceAppId = 'different-app' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'ResourceAppId mismatch blocks cleanup'
        }

        It 'blocks principal mismatch' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan)
                Approval = (New-Rev46Approval -Overrides @{ PrincipalId = 'different-principal' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'PrincipalId mismatch blocks cleanup'
        }

        It 'blocks permission name mismatch' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan)
                Approval = (New-Rev46Approval -Overrides @{ PermissionName = 'Mail.Read' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'PermissionName mismatch blocks cleanup'
        }

        It 'blocks scope mismatch' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan -Overrides @{ Scope = 'User.Read' })
                Approval = (New-Rev46Approval -Overrides @{ Scope = 'Mail.Read' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Scope mismatch blocks cleanup'
        }

        It 'blocks missing snapshot' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan)
                Approval = (New-Rev46Approval)
                TargetValidation = $script:TargetValidation
                Snapshot = $null
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Snapshot evidence is required'
        }

        It 'blocks snapshot mismatch' {
            $module = Get-Module NhiControlledDecommission
            $result = & $module {
                param($GateInput)
                Test-NhiControlledGrantCleanupReadinessGate @GateInput
            } @{
                ExecutionStage = 'GrantCleanupReadiness'
                Plan = (New-Rev46Plan)
                Approval = (New-Rev46Approval -Overrides @{ SnapshotId = 'bad-snapshot' })
                TargetValidation = $script:TargetValidation
                Snapshot = $script:Snapshot
                DependencyRecheck = (New-Rev46Plan).DependencyRecheck
                WhatIf = $true
                DemoMode = $false
            }
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Snapshot does not include the related object'
        }
    }
}

# =============================================================================
# Rev4.7 (wrapper Describe -- see Rev4.5 header comment above for rationale)
# =============================================================================
Describe 'Rev4.7 managed identity gate suite' {
    BeforeAll {
        $script:Target = [PSCustomObject]@{
            ObjectId = 'mi-rev47-test-001'
            ObjectType = 'ManagedIdentity'
            DisplayName = 'Rev47 Managed Identity'
            ManagedIdentityType = 'SystemAssigned'
            ProtectedObject = $false
            MicrosoftFirstParty = $false
            EmergencyAccessIndicator = $false
            BreakGlassIndicator = $false
            HighConfidenceActive = $false
            Ambiguous = $false
        }
        $script:TargetValidation = Test-NhiControlledTarget -Target $script:Target
        $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target $script:Target -RunId 'RUN-REV47-MI-SAMPLE-001'
        $script:RawSample = Get-Content -LiteralPath $script:Rev47SamplePath -Raw
        $script:Sample = $script:RawSample | ConvertFrom-Json

        function New-Rev47Plan {
            param([hashtable]$Overrides = @{})
            $plan = [ordered]@{
                SchemaVersion = '4.7'
                RunId = 'RUN-REV47-MI-SAMPLE-001'
                TargetId = 'mi-rev47-test-001'
                TargetType = 'ManagedIdentity'
                ManagedIdentityType = 'SystemAssigned'
                ApprovalId = 'APP-REV47-MI-001'
                TargetObjectIds = @('mi-rev47-test-001')
                ApprovedActions = @('ManagedIdentityReadiness')
                ParentResourceEvidence = [PSCustomObject]@{
                    Present = $true
                    ParentResourceId = 'res-group-rev47-001'
                    ParentResourceType = 'Microsoft.Web/sites'
                    LocalOnly = $true
                }
                AttachmentEvidence = [PSCustomObject]@{
                    Present = $true
                    ResourceId = 'mi-rev47-test-001'
                    Attached = $true
                    LocalOnly = $true
                }
                RoleAssignmentEvidence = [PSCustomObject]@{
                    ActiveRoleAssignmentCount = 0
                    QuerySucceeded = $true
                }
                FederatedCredentialEvidence = [PSCustomObject]@{
                    ActiveDependencyCount = 0
                    AppRelationshipDependencyCount = 0
                    QuerySucceeded = $true
                }
                DependencyRecheck = [PSCustomObject]@{
                    SchemaVersion = '4.7'
                    Status = 'Clean'
                    QuerySucceeded = $true
                    Blocked = $false
                    SkippedWithApproval = $false
                }
                DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
                ScreamTestEvidence = [PSCustomObject]@{
                    EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                    Status = 'Complete'
                    DependencyDetected = $false
                    RecentActivityDetected = $false
                    QuerySucceeded = $true
                }
                RollbackLimitation = 'EvidenceOnly'
                LiveCleanupApproved = $false
                LiveCleanupExecutable = $false
            }
            foreach ($key in $Overrides.Keys) { $plan[$key] = $Overrides[$key] }
            [PSCustomObject]$plan
        }

        function New-Rev47Approval {
            param([hashtable]$Overrides = @{})
            $approval = [ordered]@{
                SchemaVersion = '4.7'
                RunId = 'RUN-REV47-MI-SAMPLE-001'
                Status = 'Approved'
                ApprovedBy = 'managed-identity-approver@example.com'
                ExpiresUtc = '2099-01-01T00:00:00Z'
                Reusable = $false
                ApprovalId = 'APP-REV47-MI-001'
                TargetId = 'mi-rev47-test-001'
                TargetType = 'ManagedIdentity'
                ManagedIdentityType = 'SystemAssigned'
                TargetObjectIds = @('mi-rev47-test-001')
                ApprovedActions = @('ManagedIdentityReadiness')
                LiveCleanupApproved = $false
                LiveCleanupExecutable = $false
            }
            foreach ($key in $Overrides.Keys) { $approval[$key] = $Overrides[$key] }
            [PSCustomObject]$approval
        }

        function New-Rev47GateInput {
            param(
                [hashtable]$PlanOverrides = @{},
                [hashtable]$ApprovalOverrides = @{},
                [string]$Stage = 'ManagedIdentityReadiness',
                [bool]$TargetPassed = $true,
                [bool]$SnapshotPresent = $true,
                [bool]$WhatIf = $true,
                [bool]$DemoMode = $false,
                [string]$DeleteReadinessStatus = 'Ready',
                [string]$DependencyStatus = 'Clean',
                [bool]$IncludeSnapshotId = $true
            )

            $plan = New-Rev47Plan -Overrides $PlanOverrides
            $snapshot = if ($SnapshotPresent) { $script:Snapshot } else { $null }
            $approvalOverrides = @{}
            foreach ($key in $ApprovalOverrides.Keys) { $approvalOverrides[$key] = $ApprovalOverrides[$key] }
            if (-not $approvalOverrides.ContainsKey('SnapshotId')) {
                $approvalOverrides['SnapshotId'] = if ($IncludeSnapshotId -and $snapshot) { $snapshot.SHA256 } else { $null }
            }
            $approval = New-Rev47Approval -Overrides $approvalOverrides

            @{
                ExecutionStage = $Stage
                Plan = $plan
                Approval = $approval
                TargetValidation = if ($TargetPassed) { $script:TargetValidation } else { [PSCustomObject]@{ Passed = $false; Reasons = @('Target validation failed.') } }
                Snapshot = $snapshot
                DeleteReadiness = [PSCustomObject]@{ Status = $DeleteReadinessStatus }
                DependencyRecheck = if ($DependencyStatus -eq 'Clean') {
                    [PSCustomObject]@{ SchemaVersion = '4.7'; Status = 'Clean'; QuerySucceeded = $true; Blocked = $false; SkippedWithApproval = $false }
                } elseif ($DependencyStatus -eq 'Blocked') {
                    [PSCustomObject]@{ SchemaVersion = '4.7'; Status = 'Blocked'; QuerySucceeded = $true; Blocked = $true; SkippedWithApproval = $false }
                } else {
                    [PSCustomObject]@{ SchemaVersion = '4.7'; Status = 'Unknown'; QuerySucceeded = $false; Blocked = $false; SkippedWithApproval = $false }
                }
                RoleAssignmentEvidence = if ($null -ne $plan.RoleAssignmentEvidence) { $plan.RoleAssignmentEvidence } else { [PSCustomObject]@{ ActiveRoleAssignmentCount = 0; QuerySucceeded = $true } }
                FederatedCredentialEvidence = if ($null -ne $plan.FederatedCredentialEvidence) { $plan.FederatedCredentialEvidence } else { [PSCustomObject]@{ ActiveDependencyCount = 0; AppRelationshipDependencyCount = 0; QuerySucceeded = $true } }
                ParentResourceEvidence = if ($null -ne $plan.ParentResourceEvidence) { $plan.ParentResourceEvidence } else { $null }
                AttachmentEvidence = if ($null -ne $plan.AttachmentEvidence) { $plan.AttachmentEvidence } else { $null }
                WhatIf = $WhatIf
                DemoMode = $DemoMode
            }
        }

        function Invoke-Rev47Gate {
            param([hashtable]$InputObject)
            $module = Get-Module NhiControlledDecommission
            & $module {
                param($GateInput)
                Test-NhiControlledManagedIdentityReadinessGate @GateInput
            } $InputObject
        }

        function Invoke-Rev47EntryPoint {
            param(
                [string]$PlanPath,
                [string]$ApprovalPath,
                [string]$Stage = 'ManagedIdentityReadiness'
            )

            $stdout = [System.IO.Path]::GetTempFileName()
            $stderr = [System.IO.Path]::GetTempFileName()
            $command = "& '.\Invoke-EntraIdentityDecommissioningControlPlane.ps1' -ExecuteNhiControlledDecommission -ExecutionStage '$Stage' -DecommissionPlanPath '$PlanPath' -ApprovalManifestPath '$ApprovalPath' -WhatIfExecution"
            $process = Start-Process -FilePath 'C:\Program Files\PowerShell\7\pwsh.exe' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', $command) -Wait -PassThru -NoNewWindow -RedirectStandardOutput $stdout -RedirectStandardError $stderr

            [PSCustomObject]@{
                ExitCode = $process.ExitCode
                StdOut = Get-Content -LiteralPath $stdout -Raw
                StdErr = Get-Content -LiteralPath $stderr -Raw
            }
        }

        function New-Rev47DirectGateInput {
            param(
                [string]$ManagedIdentityType = 'SystemAssigned',
                [string]$ApprovalManagedIdentityType = $ManagedIdentityType,
                [string]$ApprovalId = 'APP-REV47-MI-001',
                [string]$TargetId = 'mi-rev47-test-001',
                [string]$ApprovedActions = 'ManagedIdentityReadiness',
                [bool]$WhatIf = $true,
                [bool]$DemoMode = $false
            )

            $target = [PSCustomObject]@{
                ObjectId = 'mi-rev47-test-001'
                ObjectType = 'ManagedIdentity'
                DisplayName = 'Rev47 Managed Identity'
                ManagedIdentityType = 'SystemAssigned'
                ProtectedObject = $false
                MicrosoftFirstParty = $false
                EmergencyAccessIndicator = $false
                BreakGlassIndicator = $false
                HighConfidenceActive = $false
                Ambiguous = $false
            }
            $plan = [PSCustomObject]@{
                SchemaVersion = '4.7'
                RunId = 'RUN-REV47-MI-SAMPLE-001'
                TargetId = 'mi-rev47-test-001'
                TargetType = 'ManagedIdentity'
                ManagedIdentityType = $ManagedIdentityType
                ApprovalId = 'APP-REV47-MI-001'
                TargetObjectIds = @('mi-rev47-test-001')
                ApprovedActions = @('ManagedIdentityReadiness')
                ParentResourceEvidence = [PSCustomObject]@{
                    Present = $true
                    ParentResourceId = 'res-group-rev47-001'
                    ParentResourceType = 'Microsoft.Web/sites'
                    LocalOnly = $true
                }
                AttachmentEvidence = [PSCustomObject]@{
                    Present = $true
                    ResourceId = 'mi-rev47-test-001'
                    Attached = $true
                    LocalOnly = $true
                }
                RoleAssignmentEvidence = [PSCustomObject]@{
                    ActiveRoleAssignmentCount = 0
                    QuerySucceeded = $true
                }
                FederatedCredentialEvidence = [PSCustomObject]@{
                    ActiveDependencyCount = 0
                    AppRelationshipDependencyCount = 0
                    QuerySucceeded = $true
                }
                DependencyRecheck = [PSCustomObject]@{
                    SchemaVersion = '4.7'
                    Status = 'Clean'
                    QuerySucceeded = $true
                    Blocked = $false
                    SkippedWithApproval = $false
                }
                DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
                ScreamTestEvidence = [PSCustomObject]@{
                    EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                    Status = 'Complete'
                    DependencyDetected = $false
                    RecentActivityDetected = $false
                    QuerySucceeded = $true
                }
                RollbackLimitation = 'EvidenceOnly'
                LiveCleanupApproved = $false
                LiveCleanupExecutable = $false
            }
            $approval = [PSCustomObject]@{
                SchemaVersion = '4.7'
                RunId = 'RUN-REV47-MI-SAMPLE-001'
                Status = 'Approved'
                ApprovedBy = 'managed-identity-approver@example.com'
                ExpiresUtc = '2099-01-01T00:00:00Z'
                Reusable = $false
                ApprovalId = $ApprovalId
                TargetId = $TargetId
                TargetType = 'ManagedIdentity'
                ManagedIdentityType = $ApprovalManagedIdentityType
                TargetObjectIds = @('mi-rev47-test-001')
                ApprovedActions = @($ApprovedActions)
                LiveCleanupApproved = $false
                LiveCleanupExecutable = $false
            }
            $snapshot = ConvertTo-NhiControlledSnapshot -Target $target -RunId 'RUN-REV47-MI-SAMPLE-001'

            @{
                ExecutionStage = 'ManagedIdentityReadiness'
                Plan = $plan
                Approval = $approval
                TargetValidation = (Test-NhiControlledTarget -Target $target)
                Snapshot = $snapshot
                DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
                DependencyRecheck = $plan.DependencyRecheck
                RoleAssignmentEvidence = $plan.RoleAssignmentEvidence
                FederatedCredentialEvidence = $plan.FederatedCredentialEvidence
                ParentResourceEvidence = $plan.ParentResourceEvidence
                AttachmentEvidence = $plan.AttachmentEvidence
                WhatIf = $WhatIf
                DemoMode = $DemoMode
            }
        }

        function Invoke-Rev47Module {
            param(
                [scriptblock]$ScriptBlock,
                [Parameter(ValueFromRemainingArguments = $true)]
                [object[]]$Arguments
            )
            $module = Get-Module NhiControlledDecommission
            & $module $ScriptBlock @Arguments
        }
    }

    Describe 'Rev4.7 managed identity contract' {
        It 'keeps the private evaluator hidden and export contract frozen' {
            Get-Command Test-NhiControlledManagedIdentityReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $exports = (Get-Module NhiControlledDecommission).ExportedCommands.Keys
            $exports | Should -Contain 'Test-NhiControlledTarget'
            $exports | Should -Contain 'New-NhiControlledDecommissionPlan'
            $exports | Should -Contain 'ConvertTo-NhiControlledSnapshot'
            $exports | Should -Contain 'Test-NhiControlledLabLiveReversibleDisableReadiness'
        }

        It 'parses the managed identity sample JSON' {
            $script:Sample | Should -Not -BeNullOrEmpty
            $script:Sample.SchemaVersion | Should -Be '4.7'
            $script:Sample.TargetType | Should -Be 'ManagedIdentity'
        }

        # Merged: "contains no secret-like values or delete cmdlet names" -> moved to the shared
        # "Rev4.3-Rev4.8 sample hygiene" Describe near the end of this file.

        It 'captures managed identity evidence in the sample' {
            $script:Sample.ManagedIdentityType | Should -Be 'SystemAssigned'
            $script:Sample.ParentResourceEvidence.ParentResourceId | Should -Be 'res-group-rev47-001'
            $script:Sample.DeleteReadiness.Status | Should -Be 'Ready'
        }

        It 'classifies managed identity type from the plan' {
            (Invoke-Rev47Module { param($Plan) Get-NhiControlledManagedIdentityType -Plan $Plan } (New-Rev47Plan)).ManagedIdentityType | Should -Be 'SystemAssigned'
        }

        It 'classifies a user-assigned managed identity' {
            (Invoke-Rev47Module { param($Plan) Get-NhiControlledManagedIdentityType -Plan $Plan } (New-Rev47Plan -Overrides @{ ManagedIdentityType = 'UserAssigned' })).ManagedIdentityType | Should -Be 'UserAssigned'
        }

        It 'classifies an unknown managed identity type' {
            (Invoke-Rev47Module { param($Plan) Get-NhiControlledManagedIdentityType -Plan $Plan } (New-Rev47Plan -Overrides @{ ManagedIdentityType = 'Unexpected' })).ManagedIdentityType | Should -Be 'Unknown'
        }

        It 'produces managed identity plan and action log objects' {
            $readiness = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
            $plan = Invoke-Rev47Module {
                param($Plan, $Readiness, $Snapshot, $RoleAssignmentEvidence, $FederatedCredentialEvidence, $ParentResourceEvidence, $AttachmentEvidence)
                New-NhiControlledManagedIdentityReadinessPlan -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot -RoleAssignmentEvidence $RoleAssignmentEvidence -FederatedCredentialEvidence $FederatedCredentialEvidence -ParentResourceEvidence $ParentResourceEvidence -AttachmentEvidence $AttachmentEvidence
            } (New-Rev47Plan) $readiness $script:Snapshot (New-Rev47Plan).RoleAssignmentEvidence (New-Rev47Plan).FederatedCredentialEvidence (New-Rev47Plan).ParentResourceEvidence (New-Rev47Plan).AttachmentEvidence
            $actionLog = Invoke-Rev47Module {
                param($Plan, $Readiness, $Snapshot)
                New-NhiControlledManagedIdentityActionLog -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot
            } (New-Rev47Plan) $readiness $script:Snapshot
            $plan.Status | Should -Be 'Planned'
            $actionLog.Result | Should -Be 'SimulationOnly'
        }

        It 'satisfies readiness only as simulation when every gate passes' {
            $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
            $result.GatesPassed | Should -BeTrue
            $result.Status | Should -Be 'ManagedIdentityReadinessSatisfiedSimulationOnly'
        }

        It 'supports DemoMode readiness simulation only' {
            $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $false -DemoMode $true)
            $result.GatesPassed | Should -BeTrue
            $result.DemoMode | Should -BeTrue
        }

        It 'supports WhatIf readiness simulation only' {
            $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
            $result.GatesPassed | Should -BeTrue
            $result.WhatIf | Should -BeTrue
        }

        It 'fails closed from the entry point when system-assigned parent evidence is missing' {
            $plan = (New-Rev47Plan -Overrides @{ ParentResourceEvidence = $null })
            $planPath = Join-Path $TestDrive 'rev47-systemassigned-missing-parent.plan.json'
            $approvalPath = Join-Path $TestDrive 'rev47-systemassigned-missing-parent.approval.json'
            $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $planPath -Encoding utf8
            (New-Rev47Approval) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvalPath -Encoding utf8

            $result = Invoke-Rev47EntryPoint -PlanPath $planPath -ApprovalPath $approvalPath
            $result.ExitCode | Should -Be 1
            $result.StdOut | Should -Match '\[SECURITY STOP\] SystemAssigned managed identity requires ParentResourceEvidence'
            $result.StdOut | Should -Not -Match 'managed identity readiness completed'
        }

        It 'fails closed from the entry point when user-assigned attachment evidence is missing' {
            $plan = (New-Rev47Plan -Overrides @{ ManagedIdentityType = 'UserAssigned'; AttachmentEvidence = $null })
            $approval = [PSCustomObject]@{
                SchemaVersion = '4.7'
                RunId = 'RUN-REV47-MI-SAMPLE-001'
                Status = 'Approved'
                ApprovedBy = 'managed-identity-approver@example.com'
                ExpiresUtc = '2099-01-01T00:00:00Z'
                Reusable = $false
                ApprovalId = 'APP-REV47-MI-001'
                TargetId = 'mi-rev47-test-001'
                TargetType = 'ManagedIdentity'
                ManagedIdentityType = 'UserAssigned'
                TargetObjectIds = @('mi-rev47-test-001')
                ApprovedActions = @('ManagedIdentityReadiness')
                LiveCleanupApproved = $false
                LiveCleanupExecutable = $false
            }
            $planPath = Join-Path $TestDrive 'rev47-userassigned-missing-attachment.plan.json'
            $approvalPath = Join-Path $TestDrive 'rev47-userassigned-missing-attachment.approval.json'
            $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $planPath -Encoding utf8
            $approval | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvalPath -Encoding utf8

            $result = Invoke-Rev47EntryPoint -PlanPath $planPath -ApprovalPath $approvalPath
            $result.ExitCode | Should -Be 1
            $result.StdOut | Should -Match '\[SECURITY STOP\] UserAssigned managed identity requires AttachmentEvidence'
            $result.StdOut | Should -Not -Match 'managed identity readiness completed'
        }

        It 'keeps readiness simulation-only and non-executable' {
            $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
            $result.LiveCleanupExecutable | Should -BeFalse
            $result.CleanupCmdletAvailable | Should -BeFalse
            $result.SimulationOnly | Should -BeTrue
        }

        It 'passes the entry point when supplied managed identity evidence is present' {
            $plan = New-Rev47Plan
            $planPath = Join-Path $TestDrive 'rev47-valid.plan.json'
            $approvalPath = Join-Path $TestDrive 'rev47-valid.approval.json'
            $plan | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $planPath -Encoding utf8
            (New-Rev47Approval) | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $approvalPath -Encoding utf8

            $result = Invoke-Rev47EntryPoint -PlanPath $planPath -ApprovalPath $approvalPath
            $result.ExitCode | Should -Be 0
            $result.StdOut | Should -Match 'Rev4.7 managed identity readiness completed'
        }

        It 'requires explicit status normalization for missing text' {
            (Invoke-Rev47Module { param($Value) Get-NhiControlledStatusText -Value $Value } $null) | Should -Be 'Incomplete'
            (Invoke-Rev47Module { param($Value) Get-NhiControlledStatusText -Value $Value } 'Ready') | Should -Be 'Ready'
        }

        It 'passes with a user-assigned attachment and parent evidence present' {
            $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ManagedIdentityType 'UserAssigned' -ApprovalManagedIdentityType 'UserAssigned' -ApprovalId 'APP-REV47-MI-001' -TargetId 'mi-rev47-test-001' -ApprovedActions 'ManagedIdentityReadiness' -WhatIf $true)
            $result.GatesPassed | Should -BeTrue
            $result.ManagedIdentityType | Should -Be 'UserAssigned'
        }

        It 'passes with system-assigned parent evidence present' {
            $result = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
            $result.GatesPassed | Should -BeTrue
            $result.ManagedIdentityType | Should -Be 'SystemAssigned'
        }

        It 'preserves approval target object ids and readiness contract fields' {
            $readiness = Invoke-Rev47Gate (New-Rev47GateInput -WhatIf $true)
            $plan = Invoke-Rev47Module {
                param($Plan, $Readiness, $Snapshot, $RoleAssignmentEvidence, $FederatedCredentialEvidence, $ParentResourceEvidence, $AttachmentEvidence)
                New-NhiControlledManagedIdentityReadinessPlan -Plan $Plan -Readiness $Readiness -Snapshot $Snapshot -RoleAssignmentEvidence $RoleAssignmentEvidence -FederatedCredentialEvidence $FederatedCredentialEvidence -ParentResourceEvidence $ParentResourceEvidence -AttachmentEvidence $AttachmentEvidence
            } (New-Rev47Plan) $readiness $script:Snapshot (New-Rev47Plan).RoleAssignmentEvidence (New-Rev47Plan).FederatedCredentialEvidence (New-Rev47Plan).ParentResourceEvidence (New-Rev47Plan).AttachmentEvidence
            $plan.RollbackLimitation | Should -Be 'EvidenceOnly'
            $plan.LiveCleanupEnabled | Should -BeFalse
            $plan.EvidenceKind | Should -Be 'ManagedIdentityReadiness'
        }

        It 'keeps the approval target object ids stable in the sample' {
            $script:Sample.TargetObjectIds[0] | Should -Be 'mi-rev47-test-001'
            $script:Sample.ApprovedActions[0] | Should -Be 'ManagedIdentityReadiness'
        }
    }

    Describe 'Rev4.7 required gate failures' {
        It 'blocks <Name>' -ForEach @(
            @{ Name = 'missing stage'; Build = { New-Rev47GateInput -Stage 'DeleteReadinessOnly' }; Pattern = 'ManagedIdentityReadiness' }
            @{ Name = 'wrong target type'; Build = { New-Rev47GateInput -PlanOverrides @{ TargetType = 'Application' } }; Pattern = 'Target type must be ManagedIdentity' }
            @{ Name = 'unknown identity type'; Build = { New-Rev47GateInput -PlanOverrides @{ ManagedIdentityType = 'Unexpected' } }; Pattern = 'Managed identity type is Unknown' }
            @{ Name = 'missing parent evidence'; Build = { New-Rev47GateInput -PlanOverrides @{ ParentResourceEvidence = $null } }; Pattern = 'parent resource evidence' }
            @{ Name = 'missing attachment evidence'; Build = { New-Rev47GateInput -PlanOverrides @{ ManagedIdentityType = 'UserAssigned'; AttachmentEvidence = $null } }; Pattern = 'attachment evidence' }
            @{ Name = 'role assignments present'; Build = { New-Rev47GateInput -PlanOverrides @{ RoleAssignmentEvidence = [PSCustomObject]@{ ActiveRoleAssignmentCount = 1; QuerySucceeded = $true } } }; Pattern = 'role assignments block readiness' }
            @{ Name = 'federated dependency present'; Build = { New-Rev47GateInput -PlanOverrides @{ FederatedCredentialEvidence = [PSCustomObject]@{ ActiveDependencyCount = 1; AppRelationshipDependencyCount = 0; QuerySucceeded = $true } } }; Pattern = 'Federated credential or app relationship dependency blocks readiness' }
            @{ Name = 'app relationship dependency present'; Build = { New-Rev47GateInput -PlanOverrides @{ FederatedCredentialEvidence = [PSCustomObject]@{ ActiveDependencyCount = 0; AppRelationshipDependencyCount = 1; QuerySucceeded = $true } } }; Pattern = 'Federated credential or app relationship dependency blocks readiness' }
            @{ Name = 'dependency unknown'; Build = { New-Rev47GateInput -DependencyStatus 'Unknown' }; Pattern = 'Dependency recheck blocks readiness' }
            @{ Name = 'dependency blocked'; Build = { New-Rev47GateInput -DependencyStatus 'Blocked' }; Pattern = 'Dependency recheck blocks readiness' }
            @{ Name = 'snapshot missing'; Build = { New-Rev47GateInput -SnapshotPresent $false }; Pattern = 'Snapshot evidence is required' }
            @{ Name = 'delete readiness blocked'; Build = { New-Rev47GateInput -DeleteReadinessStatus 'Blocked' }; Pattern = 'Delete-readiness must be Ready' }
            @{ Name = 'target validation failed'; Build = { New-Rev47GateInput -TargetPassed $false }; Pattern = 'Target validation failed' }
            @{ Name = 'unattended live-mode request'; Build = { New-Rev47GateInput -WhatIf $false -DemoMode $false }; Pattern = 'WhatIf or DemoMode' }
        ) {
            $result = Invoke-Rev47Gate (& $Build)
            $result.GatesPassed | Should -BeFalse
            $result.Status | Should -Be 'Blocked'
            $result.LiveCleanupExecutable | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match $Pattern
        }

        It 'blocks approval id mismatch' {
            $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ApprovalId 'APP-REV47-WRONG')
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Exact approval is required'
        }

        It 'blocks target mismatch' {
            $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -TargetId 'other-target')
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Exact target binding is required'
        }

        It 'blocks approval action missing' {
            $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ApprovedActions 'SomethingElse')
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Approval must specifically authorize the readiness action'
        }

        It 'blocks managed identity type mismatch' {
            $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ManagedIdentityType 'SystemAssigned' -ApprovalManagedIdentityType 'UserAssigned' -ApprovalId 'APP-REV47-MI-001' -TargetId 'mi-rev47-test-001' -ApprovedActions 'ManagedIdentityReadiness' -WhatIf $true)
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Managed identity type mismatch blocks readiness'
        }

        It 'blocks managed identity approval type mismatch' {
            $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -ManagedIdentityType 'UserAssigned' -ApprovalManagedIdentityType 'SystemAssigned' -ApprovalId 'APP-REV47-MI-001' -TargetId 'mi-rev47-test-001' -ApprovedActions 'ManagedIdentityReadiness' -WhatIf $true)
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Managed identity type mismatch blocks readiness'
        }

        It 'blocks exact target binding missing' {
            $result = Invoke-Rev47Gate (New-Rev47DirectGateInput -TargetId '')
            $result.GatesPassed | Should -BeFalse
            $result.Reasons -join ' ' | Should -Match 'Exact target binding is required'
        }
    }
}

# =============================================================================
# Rev4.8 (wrapper Describe -- see Rev4.5 header comment above for rationale)
# =============================================================================
Describe 'Rev4.8 E2E evidence pack suite' {
    BeforeAll {
        $script:Target = [PSCustomObject]@{
            ObjectId = 'e2e-rev48-test-001'
            ObjectType = 'ManagedIdentity'
            DisplayName = 'Rev48 E2E Managed Identity'
            ManagedIdentityType = 'SystemAssigned'
            ProtectedObject = $false
            MicrosoftFirstParty = $false
            EmergencyAccessIndicator = $false
            BreakGlassIndicator = $false
            HighConfidenceActive = $false
            Ambiguous = $false
        }
        $script:TargetValidation = Test-NhiControlledTarget -Target $script:Target
        $script:Snapshot = ConvertTo-NhiControlledSnapshot -Target $script:Target -RunId 'RUN-REV48-E2E-SAMPLE-001'
        $script:RawSample = Get-Content -LiteralPath $script:Rev48SamplePath -Raw
        $script:Sample = $script:RawSample | ConvertFrom-Json

        function New-Rev48Plan {
            param([hashtable]$Overrides = @{})
            $plan = [ordered]@{
                SchemaVersion = '4.8'
                RunId = 'RUN-REV48-E2E-SAMPLE-001'
                TargetId = 'e2e-rev48-test-001'
                TargetType = 'ManagedIdentity'
                ManagedIdentityType = 'SystemAssigned'
                ApprovalId = 'APP-REV48-E2E-001'
                TargetObjectIds = @('e2e-rev48-test-001')
                ApprovedActions = @('E2EEvidencePack')
                TargetCountsByType = [ordered]@{ ServicePrincipal = 2; Application = 1; ManagedIdentity = 1 }
                DependencyRecheck = [PSCustomObject]@{
                    SchemaVersion = '4.8'
                    Status = 'Clean'
                    QuerySucceeded = $true
                    Blocked = $false
                    SkippedWithApproval = $false
                }
                DeleteReadiness = [PSCustomObject]@{ Status = 'Ready' }
                MetadataReadiness = [PSCustomObject]@{ Status = 'MetadataCleanupSatisfiedSimulationOnly' }
                GrantReadiness = [PSCustomObject]@{ Status = 'GrantCleanupSatisfiedSimulationOnly' }
                ManagedIdentityReadiness = [PSCustomObject]@{ Status = 'ManagedIdentityReadinessSatisfiedSimulationOnly' }
                ScreamTestEvidence = [PSCustomObject]@{
                    EvidenceType = 'IllustrativeGeneratedPlannerEvidenceNotLiveMonitoring'
                    Status = 'Complete'
                    DependencyDetected = $false
                    RecentActivityDetected = $false
                    QuerySucceeded = $true
                }
                OperatorDecision = [PSCustomObject]@{
                    Decision = 'SimulationOnly'
                    DecisionBy = 'local-planner'
                    DecisionAtUtc = '2099-01-01T00:00:00Z'
                    Reason = 'No live tenant execution is allowed.'
                    Scope = 'Rev4.8'
                    IsSimulationOnly = $true
                }
                KnownWarnings = @('DemoMode traceability warning may still appear in legacy assessment paths.')
                LiveDeleteExecutable = $false
                LiveCleanupExecutable = $false
                GraphWritePathAvailable = $false
                FinalDeleteSimulationOnly = $true
            }
            foreach ($key in $Overrides.Keys) { $plan[$key] = $Overrides[$key] }
            [PSCustomObject]$plan
        }

        function New-Rev48Approval {
            param([hashtable]$Overrides = @{})
            $approval = [ordered]@{
                SchemaVersion = '4.8'
                RunId = 'RUN-REV48-E2E-SAMPLE-001'
                Status = 'Approved'
                ApprovedBy = 'e2e-qa-approver@example.com'
                ExpiresUtc = '2099-01-01T00:00:00Z'
                Reusable = $false
                ApprovalId = 'APP-REV48-E2E-001'
                TargetId = 'e2e-rev48-test-001'
                TargetType = 'ManagedIdentity'
                ManagedIdentityType = 'SystemAssigned'
                TargetObjectIds = @('e2e-rev48-test-001')
                ApprovedActions = @('E2EEvidencePack')
                TargetCountsByType = [ordered]@{ ServicePrincipal = 2; Application = 1; ManagedIdentity = 1 }
                LiveDeleteExecutable = $false
                LiveCleanupExecutable = $false
                GraphWritePathAvailable = $false
                FinalDeleteSimulationOnly = $true
            }
            foreach ($key in $Overrides.Keys) { $approval[$key] = $Overrides[$key] }
            [PSCustomObject]$approval
        }

        function New-Rev48PackInput {
            param(
                [hashtable]$PlanOverrides = @{},
                [hashtable]$ApprovalOverrides = @{},
                [bool]$SnapshotPresent = $true
            )

            $plan = New-Rev48Plan -Overrides $PlanOverrides
            $snapshot = if ($SnapshotPresent) { $script:Snapshot } else { $null }
            $approval = New-Rev48Approval -Overrides $ApprovalOverrides

            [PSCustomObject]@{
                Plan = $plan
                Approval = $approval
                Snapshot = $snapshot
                ScreamTest = $plan.ScreamTestEvidence
                DependencyRecheck = $plan.DependencyRecheck
                DeleteReadiness = $plan.DeleteReadiness
                MetadataReadiness = $plan.MetadataReadiness
                GrantReadiness = $plan.GrantReadiness
                ManagedIdentityReadiness = $plan.ManagedIdentityReadiness
                OperatorDecision = $plan.OperatorDecision
                KnownWarnings = $plan.KnownWarnings
            }
        }

        function Invoke-Rev48Module {
            param(
                [scriptblock]$ScriptBlock,
                [Parameter(ValueFromRemainingArguments = $true)]
                [object[]]$Arguments
            )
            $module = Get-Module NhiControlledDecommission
            & $module $ScriptBlock @Arguments
        }
    }

    Describe 'Rev4.8 evidence pack contract' {
        $script:ExpectedExports = @(
            'Get-NhiControlledDecommissionSha256'
            'Get-NhiControlledDecommissionSchema'
            'ConvertTo-NhiControlledSnapshot'
            'Test-NhiControlledTarget'
            'Confirm-NhiControlledApproval'
            'Get-NhiControlledScreamTestStatus'
            'Test-NhiControlledDependencies'
            'Get-NhiControlledDeleteReadiness'
            'New-NhiControlledRollbackPlan'
            'New-NhiControlledDecommissionPlan'
            'Test-NhiControlledLabLiveReversibleDisableReadiness'
            'Export-NhiControlledDecommissionEvidence'
            'New-NhiControlledLabDisableDryRunPackage'
            'New-NhiControlledLabRollbackDrillPackage'
            'Invoke-NhiControlledLabLiveReversibleDisable'
            'New-NhiRun4CFinalGoNoGoReviewPackage'
            'New-NhiRun4CLiveEvidenceCapturePackage'
            'New-NhiRun4CPostDisableObservationPackage'
            'New-NhiRun4CRollbackExecutionReadinessPackage'
            'Invoke-NhiControlledLabRollback'
            'New-NhiFinalDeleteEligibilitySimulationPackage'
            'New-NhiRun4CEndToEndLabRehearsalReport'
            'New-NhiRun4CConsultantOperatingGuide'
            'Get-NhiRun4CArtifactRecord'
            'New-NhiRun4CFinalControlledDisableTestPackage'
            'New-NhiRun4CPostDisableEvidenceValidationPackage'
            'New-NhiRun4CControlledRollbackExecutionTestPackage'
            'New-NhiRun4CPostRollbackValidationPackage'
            'New-NhiRun4CFinalEvidenceBundle'
            'New-NhiRev4ReleaseCandidateFreezePackage'
        )

        It 'keeps the private helpers hidden and exports the required public contract' {
            Get-Command New-NhiControlledE2EEvidencePack -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Command New-NhiControlledOperatorDecisionLog -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $exports = (Get-Module NhiControlledDecommission).ExportedCommands.Keys
            foreach ($name in $script:ExpectedExports) {
                $exports | Should -Contain $name
            }
        }

        It 'parses the E2E sample JSON' {
            $script:Sample | Should -Not -BeNullOrEmpty
            $script:Sample.SchemaVersion | Should -Be '4.8'
            $script:Sample.TargetType | Should -Be 'ManagedIdentity'
        }

        # Merged: "contains no secret-like values or delete cmdlet names" -> moved to the shared
        # "Rev4.3-Rev4.8 sample hygiene" Describe near the end of this file.

        It 'captures evidence pack input identity and counts' {
            $script:Sample.TargetCountsByType.ServicePrincipal | Should -Be 2
            $script:Sample.TargetCountsByType.Application | Should -Be 1
            $script:Sample.TargetCountsByType.ManagedIdentity | Should -Be 1
        }

        It 'returns target counts by type from the module helper' {
            $counts = Invoke-Rev48Module { param($Plan) Get-NhiControlledTargetCountsByType -Plan $Plan } (New-Rev48Plan)
            $counts.ServicePrincipal | Should -Be 2
            $counts.Application | Should -Be 1
            $counts.ManagedIdentity | Should -Be 1
        }

        It 'sets live-delete and live-cleanup flags false' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.LiveDeleteExecutable | Should -BeFalse
            $pack.LiveCleanupExecutable | Should -BeFalse
            $pack.GraphWritePathAvailable | Should -BeFalse
            $pack.FinalDeleteSimulationOnly | Should -BeTrue
        }

        It 'builds a QA handoff manifest with the required fields' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.QAHandoffManifest.ToolVersion | Should -Be 'Rev4.10'
            $pack.QAHandoffManifest.PushStatus | Should -Be 'No'
            $pack.QAHandoffManifest.EvidenceArtifacts.Count | Should -Be 5
        }

        It 'builds an operator decision log with the required fields' {
            $decision = Invoke-Rev48Module {
                param($Plan, $Decision)
                New-NhiControlledOperatorDecisionLog -Plan $Plan -Decision $Decision.Decision -DecisionBy $Decision.DecisionBy -Reason $Decision.Reason -Scope $Decision.Scope
            } (New-Rev48Plan) (New-Rev48Plan).OperatorDecision
            $decision.Decision | Should -Be 'SimulationOnly'
            $decision.IsSimulationOnly | Should -BeTrue
            $decision.Scope | Should -Be 'Rev4.8'
        }

        It 'summarizes approval coverage, snapshot coverage, and scream-test status' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.ApprovalCoverage.ExactTarget | Should -BeTrue
            $pack.SnapshotCoverage.Present | Should -BeTrue
            $pack.ScreamTestSummary.IllustrativeOnly | Should -BeTrue
        }

        It 'summarizes dependency recheck, delete readiness, and cleanup readiness' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.DependencyRecheckSummary.Status | Should -Be 'Clean'
            $pack.DeleteReadinessSummary.Status | Should -Be 'Ready'
            $pack.CleanupReadinessSummary.Metadata | Should -Be 'MetadataCleanupSatisfiedSimulationOnly'
        }

        It 'summarizes rollback limitation and validation results' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.RollbackLimitationSummary.Classification | Should -Be 'EvidenceOnly'
            $pack.ValidationResults.ManagedIdentityStatus | Should -Be 'ManagedIdentityReadinessSatisfiedSimulationOnly'
            $pack.ValidationResults.MetadataStatus | Should -Be 'MetadataCleanupSatisfiedSimulationOnly'
        }

        It 'includes the known warning list and simulation-only evidence state' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.KnownWarnings.Count | Should -BeGreaterThan 0
            $pack.SafetyAssertions.LiveDeleteExecutable | Should -BeFalse
            $pack.SafetyAssertions.GraphWritePathAvailable | Should -BeFalse
        }

        It 'normalizes missing evidence to incomplete statuses' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) ([PSCustomObject]@{}) @()
            $pack.SnapshotCoverage.Present | Should -BeFalse
            $pack.ValidationResults.ManagedIdentityStatus | Should -Be 'Incomplete'
            $pack.ValidationResults.MetadataStatus | Should -Be 'Incomplete'
            $pack.ValidationResults.GrantsStatus | Should -Be 'Incomplete'
        }

        It 'keeps simulation-only flags false for live execution' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.FinalDeleteSimulationOnly | Should -BeTrue
            $pack.QAHandoffManifest.SafetyAssertions.FinalDeleteSimulationOnly | Should -BeTrue
            $pack.QAHandoffManifest.PushStatus | Should -Be 'No'
        }

        It 'preserves the QA handoff evidence artifact list' -ForEach @(
            @{ Index = 0; File = 'nhi-controlled-e2e-evidence-pack.json' }
            @{ Index = 1; File = 'nhi-controlled-qa-handoff-manifest.json' }
            @{ Index = 2; File = 'nhi-controlled-operator-decision-log.json' }
            @{ Index = 3; File = 'nhi-controlled-managed-identity-readiness.json' }
            @{ Index = 4; File = 'nhi-controlled-e2e-snapshot.json' }
        ) {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.QAHandoffManifest.EvidenceArtifacts[$Index] | Should -Be $File
        }

        It 'keeps the safety assertions false for live execution' -ForEach @(
            @{ Name = 'LiveDeleteExecutable'; Value = $false }
            @{ Name = 'LiveCleanupExecutable'; Value = $false }
            @{ Name = 'GraphWritePathAvailable'; Value = $false }
            @{ Name = 'FinalDeleteSimulationOnly'; Value = $true }
        ) {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.$Name | Should -Be $Value
        }

        It 'reports validation result fields individually' -ForEach @(
            @{ Name = 'ManagedIdentityStatus'; Value = 'ManagedIdentityReadinessSatisfiedSimulationOnly' }
            @{ Name = 'MetadataStatus'; Value = 'MetadataCleanupSatisfiedSimulationOnly' }
            @{ Name = 'GrantsStatus'; Value = 'GrantCleanupSatisfiedSimulationOnly' }
            @{ Name = 'DeleteReadinessStatus'; Value = 'Ready' }
        ) {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.ValidationResults.$Name | Should -Be $Value
        }

        It 'reports summary field <Name>' -ForEach @(
            @{ Name = 'PlanIdentity.TargetId'; Value = 'e2e-rev48-test-001' }
            @{ Name = 'PlanIdentity.TargetType'; Value = 'ManagedIdentity' }
            @{ Name = 'PlanIdentity.SchemaVersion'; Value = '4.8' }
            @{ Name = 'QAHandoffManifest.ToolVersion'; Value = 'Rev4.10' }
            @{ Name = 'QAHandoffManifest.KnownWarnings.Count'; Value = 1 }
            @{ Name = 'OperatorDecision.IsSimulationOnly'; Value = $true }
            @{ Name = 'ApprovalCoverage.Status'; Value = 'Approved' }
        ) {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings

            switch ($Name) {
                'PlanIdentity.TargetId' { $pack.PlanIdentity.TargetId | Should -Be $Value }
                'PlanIdentity.TargetType' { $pack.PlanIdentity.TargetType | Should -Be $Value }
                'PlanIdentity.SchemaVersion' { $pack.PlanIdentity.SchemaVersion | Should -Be $Value }
                'QAHandoffManifest.ToolVersion' { $pack.QAHandoffManifest.ToolVersion | Should -Be $Value }
                'QAHandoffManifest.KnownWarnings.Count' { $pack.QAHandoffManifest.KnownWarnings.Count | Should -Be $Value }
                'OperatorDecision.IsSimulationOnly' { $pack.OperatorDecisionState.IsSimulationOnly | Should -Be $Value }
                'ApprovalCoverage.Status' { $pack.ApprovalCoverage.Status | Should -Be $Value }
            }
        }

        It 'reports the snapshot hash from the pack' {
            $input = New-Rev48PackInput
            $pack = Invoke-Rev48Module {
                param($Plan, $Approval, $Snapshot, $ScreamTest, $DependencyRecheck, $DeleteReadiness, $MetadataReadiness, $GrantReadiness, $ManagedIdentityReadiness, $OperatorDecision, $KnownWarnings)
                New-NhiControlledE2EEvidencePack -Plan $Plan -Approval $Approval -Snapshot $Snapshot -ScreamTest $ScreamTest -DependencyRecheck $DependencyRecheck -DeleteReadiness $DeleteReadiness -MetadataReadiness $MetadataReadiness -GrantReadiness $GrantReadiness -ManagedIdentityReadiness $ManagedIdentityReadiness -OperatorDecision $OperatorDecision -KnownWarnings $KnownWarnings
            } $input.Plan $input.Approval $input.Snapshot $input.ScreamTest $input.DependencyRecheck $input.DeleteReadiness $input.MetadataReadiness $input.GrantReadiness $input.ManagedIdentityReadiness $input.OperatorDecision $input.KnownWarnings
            $pack.SnapshotCoverage.SHA256 | Should -Be $input.Snapshot.SHA256
        }
    }
}

# =============================================================================
# Rev4.9 (wrapper Describe -- see Rev4.5 header comment above for rationale)
# =============================================================================
Describe 'Rev4.9 production readiness gate suite' {
    BeforeAll {
        $script:RawSample = Get-Content -LiteralPath $script:Rev49SamplePath -Raw
        $script:Sample = $script:RawSample | ConvertFrom-Json

        function New-Rev49Input {
            param([hashtable]$Overrides = @{})

            $input = [ordered]@{
                RunId = 'RUN-REV49-PROD-001'
                BranchName = 'feature/rev42-controlled-nhi-decommission'
                LatestCommit = '238e2ca5281b76decee87b14ab31883d8fd2efa9'
                GitStatusClean = $true
                FrozenFileDiffClean = $true
                Rev42PlannerEvidence = [PSCustomObject]@{ Status = 'Complete'; LocalOnly = $true }
                Rev43ServicePrincipalFinalDeleteSimulationEvidence = [PSCustomObject]@{ Status = 'Blocked'; SimulationOnly = $true; LiveDeleteExecutable = $false; LocalOnly = $true }
                Rev44ApplicationReadinessEvidence = [PSCustomObject]@{ Status = 'ReadinessSatisfiedSimulationOnly'; SimulationOnly = $true; LiveDeleteExecutable = $false; LocalOnly = $true }
                Rev45MetadataCleanupReadinessEvidence = [PSCustomObject]@{ Status = 'Ready'; SimulationOnly = $true; LiveCleanupExecutable = $false; LocalOnly = $true }
                Rev46GrantsCleanupReadinessEvidence = [PSCustomObject]@{ Status = 'Ready'; SimulationOnly = $true; LiveCleanupExecutable = $false; LocalOnly = $true }
                Rev47ManagedIdentityReadinessEvidence = [PSCustomObject]@{ Status = 'ManagedIdentityReadinessSatisfiedSimulationOnly'; SimulationOnly = $true; LiveCleanupExecutable = $false; LocalOnly = $true }
                Rev48E2EEvidencePackEvidence = [PSCustomObject]@{ Status = 'Approved'; SimulationOnly = $true; LiveDeleteExecutable = $false; LiveCleanupExecutable = $false; LocalOnly = $true }
                ExternalQaApprovalEvidence = [PSCustomObject]@{ Approved = $true; Status = 'Approved'; ApprovedBy = 'external-qa-approver@example.com'; ApprovalId = 'APP-REV49-PROD-001'; LocalOnly = $true }
                FullPesterEvidence = [PSCustomObject]@{ Passed = $true; Status = 'Passed'; LocalOnly = $true }
                SafetyScanEvidence = [PSCustomObject]@{ Passed = $true; Status = 'Passed'; LocalOnly = $true }
                FrozenFileDiffEvidence = [PSCustomObject]@{ Clean = $true; Status = 'Clean'; LocalOnly = $true }
                GitStatusEvidence = [PSCustomObject]@{ Clean = $true; Status = 'Clean'; LocalOnly = $true }
                P0Findings = @()
                P1Findings = @()
                P2Findings = @(
                    [PSCustomObject]@{ Id = 'P2-REV49-001'; Title = 'Tighten empty evidence object guard'; Severity = 'P2'; Disposition = 'Documented'; Resolved = $true },
                    [PSCustomObject]@{ Id = 'P2-REV49-002'; Title = 'Review non-MI default evidence synthesis'; Severity = 'P2'; Disposition = 'Documented'; Resolved = $true },
                    [PSCustomObject]@{ Id = 'P2-REV49-003'; Title = 'Improve future delta QA ZIP portability'; Severity = 'P2'; Disposition = 'Documented'; Resolved = $true }
                )
                KnownWarnings = @(
                    [PSCustomObject]@{ Warning = 'DemoMode traceability warning about $execEvidencePath not being set, if still present.'; Severity = 'Low'; Disposition = 'Documented'; Source = 'LegacyAssessmentPath' },
                    [PSCustomObject]@{ Warning = 'Pester ConvertTo-DecomHtmlEncoded empty-string binding messages, if still present.'; Severity = 'Low'; Disposition = 'Documented'; Source = 'Pester' },
                    [PSCustomObject]@{ Warning = 'Rev4.7/4.8 P2 follow-up: tighten empty evidence object guard.'; Severity = 'Medium'; Disposition = 'Open'; Source = 'Rev4.7' }
                )
                OperatorMergeDecision = [PSCustomObject]@{ Decision = 'ReadyForReview'; DecisionBy = 'local-planner'; DecisionAtUtc = '2099-01-01T00:00:00Z'; Reason = 'External QA and merge-gate evidence are present locally only.'; Scope = 'Rev4.9'; IsExecuting = $false }
            }

            foreach ($key in $Overrides.Keys) {
                $input[$key] = $Overrides[$key]
            }

            [PSCustomObject]$input
        }

        function New-Rev49PlanFile {
            param(
                [Parameter(Mandatory)]
                [string]$Path,

                [string[]]$RemoveProperties = @(),

                [hashtable]$Overrides = @{}
            )

            $plan = $script:RawSample | ConvertFrom-Json
            $payload = [ordered]@{}
            foreach ($property in $plan.PSObject.Properties.Name) {
                if ($property -notin $RemoveProperties) {
                    $payload[$property] = $plan.$property
                }
            }

            $json = $payload | ConvertTo-Json -Depth 20
            Set-Content -LiteralPath $Path -Value $json -Encoding utf8
            return $Path
        }

        function Invoke-Rev49Module {
            param(
                [scriptblock]$ScriptBlock,
                [Parameter(ValueFromRemainingArguments = $true)]
                [object[]]$Arguments
            )
            $module = Get-Module NhiControlledDecommission
            & $module $ScriptBlock @Arguments
        }
    }

    Describe 'Rev4.9 production readiness contract' {
        $script:ExpectedExports = @(
            'Get-NhiControlledDecommissionSha256'
            'Get-NhiControlledDecommissionSchema'
            'ConvertTo-NhiControlledSnapshot'
            'Test-NhiControlledTarget'
            'Confirm-NhiControlledApproval'
            'Get-NhiControlledScreamTestStatus'
            'Test-NhiControlledDependencies'
            'Get-NhiControlledDeleteReadiness'
            'New-NhiControlledRollbackPlan'
            'New-NhiControlledDecommissionPlan'
            'Test-NhiControlledLabLiveReversibleDisableReadiness'
            'Export-NhiControlledDecommissionEvidence'
            'New-NhiControlledLabDisableDryRunPackage'
            'New-NhiControlledLabRollbackDrillPackage'
            'Invoke-NhiControlledLabLiveReversibleDisable'
            'New-NhiRun4CFinalGoNoGoReviewPackage'
            'New-NhiRun4CLiveEvidenceCapturePackage'
            'New-NhiRun4CPostDisableObservationPackage'
            'New-NhiRun4CRollbackExecutionReadinessPackage'
            'Invoke-NhiControlledLabRollback'
            'New-NhiFinalDeleteEligibilitySimulationPackage'
            'New-NhiRun4CEndToEndLabRehearsalReport'
            'New-NhiRun4CConsultantOperatingGuide'
            'Get-NhiRun4CArtifactRecord'
            'New-NhiRun4CFinalControlledDisableTestPackage'
            'New-NhiRun4CPostDisableEvidenceValidationPackage'
            'New-NhiRun4CControlledRollbackExecutionTestPackage'
            'New-NhiRun4CPostRollbackValidationPackage'
            'New-NhiRun4CFinalEvidenceBundle'
            'New-NhiRev4ReleaseCandidateFreezePackage'
        )

        It 'keeps the private builders hidden and exports the required public contract' {
            Get-Command New-NhiControlledProductionReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            Get-Command New-NhiControlledProductionReadinessEvidencePack -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
            $exports = (Get-Module NhiControlledDecommission).ExportedCommands.Keys
            foreach ($name in $script:ExpectedExports) {
                $exports | Should -Contain $name
            }
        }

        It 'advertises the Rev4.9 schema contract' {
            $schema = Get-NhiControlledDecommissionSchema
            $schema.ProductionReadinessSchemaVersion | Should -Be '4.9'
            $schema.ReleaseMergeGateSchemaVersion | Should -Be '4.9'
            $schema.KnownWarningInventorySchemaVersion | Should -Be '4.9'
            $schema.FinalSafetyAssertionSchemaVersion | Should -Be '4.9'
            $schema.SupportedStages | Should -Contain 'ProductionReadiness'
        }

        It 'parses the production readiness sample JSON' {
            $script:Sample | Should -Not -BeNullOrEmpty
            $script:Sample.SchemaVersion | Should -Be '4.9'
            $script:Sample.ApprovedActions[0] | Should -Be 'ProductionReadiness'
        }

        It 'keeps the sample free of secret-like fields and live delete commands' {
            $script:RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
            $script:RawSample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az|Connect-MgGraph'
        }

        It 'records the expected branch, commit, and local-only evidence flags' {
            $script:Sample.BranchName | Should -Be 'feature/rev42-controlled-nhi-decommission'
            $script:Sample.LatestCommit | Should -Be '238e2ca5281b76decee87b14ab31883d8fd2efa9'
            $script:Sample.GitStatusClean | Should -BeTrue
            $script:Sample.FrozenFileDiffClean | Should -BeTrue
        }

        It 'builds a blocked gate when the input is empty' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } ([PSCustomObject]@{})
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.Status | Should -Be 'Blocked'
            $gate.RequiredEvidence.Rev42PlannerEvidence.Present | Should -BeFalse
        }

        It 'builds a ready-for-review gate with complete local evidence' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input)
            $gate.ProductionReadyForReview | Should -BeTrue
            $gate.Status | Should -Be 'ReadyForReview'
            $gate.ProductionExecutionEnabled | Should -BeFalse
            $gate.ProductionUnlockGranted | Should -BeFalse
        }

        It 'returns the required final safety assertions' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input)
            $gate.FinalSafetyAssertions.LiveDeleteExecutable | Should -BeFalse
            $gate.FinalSafetyAssertions.LiveCleanupExecutable | Should -BeFalse
            $gate.FinalSafetyAssertions.GraphWritePathAvailable | Should -BeFalse
            $gate.FinalSafetyAssertions.ArmWritePathAvailable | Should -BeFalse
            $gate.FinalSafetyAssertions.FinalDeleteSimulationOnly | Should -BeTrue
            $gate.FinalSafetyAssertions.RequiresManualApprovalForProduction | Should -BeTrue
            $gate.FinalSafetyAssertions.RequiresExternalQAForMerge | Should -BeTrue
        }

        It 'records the known warning inventory with severity and disposition' {
            $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
            $pack.KnownWarnings.Items.Count | Should -BeGreaterThan 3
            $pack.KnownWarnings.Items | ForEach-Object {
                $_.Severity | Should -Not -BeNullOrEmpty
                $_.Disposition | Should -Not -BeNullOrEmpty
            }
        }

        It 'produces the expected release manifest and merge gate states' {
            $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
            $pack.ReleaseManifest.PushStatus | Should -Be 'No'
            $pack.ReleaseManifest.MergeStatus | Should -Be 'ReadyForReview'
            $pack.MergeGate.MergeDecisionRecorded | Should -BeTrue
            $pack.MergeGate.MergeExecuted | Should -BeFalse
            $pack.MergeGate.PushPerformed | Should -BeFalse
            $pack.MergeGate.TagPerformed | Should -BeFalse
            $pack.MergeGate.DeleteBranchPerformed | Should -BeFalse
        }

        It 'records the expected branch and commit in the release manifest' {
            $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
            $pack.ReleaseManifest.BranchName | Should -Be 'feature/rev42-controlled-nhi-decommission'
            $pack.ReleaseManifest.LatestCommit | Should -Be '238e2ca5281b76decee87b14ab31883d8fd2efa9'
        }

        It 'marks production execution as disabled even when review-ready' {
            $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
            $pack.ProductionReadyForReview | Should -BeTrue
            $pack.ProductionExecutionEnabled | Should -BeFalse
            $pack.FinalDeleteSimulationOnly | Should -BeTrue
            $pack.FinalSafetyAssertions.ProductionExecutionEnabled | Should -BeFalse
            $pack.FinalSafetyAssertions.ProductionUnlockGranted | Should -BeFalse
        }

        It 'requires external QA approval evidence' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ ExternalQaApprovalEvidence = $null })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.RequiredEvidence.ExternalQaApprovalEvidence.Present | Should -BeFalse
            $gate.RequiredEvidence.ExternalQaApprovalEvidence.Status | Should -Be 'Missing'
        }

        It 'requires full Pester evidence' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ FullPesterEvidence = $null })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.RequiredEvidence.FullPesterEvidence.Present | Should -BeFalse
        }

        It 'requires safety scan evidence' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ SafetyScanEvidence = $null })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.RequiredEvidence.SafetyScanEvidence.Present | Should -BeFalse
        }

        It 'requires frozen-file diff evidence' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ FrozenFileDiffEvidence = $null })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.RequiredEvidence.FrozenFileDiffEvidence.Present | Should -BeFalse
        }

        It 'requires git status evidence' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ GitStatusEvidence = $null })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.RequiredEvidence.GitStatusEvidence.Present | Should -BeFalse
        }

        It 'blocks unresolved P0 findings' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ P0Findings = @([PSCustomObject]@{ Id = 'P0-1'; Severity = 'P0'; Disposition = 'Open'; Resolved = $false }) })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.P0Disposition.Blocked | Should -BeTrue
            $gate.P0Disposition.UnresolvedCount | Should -Be 1
        }

        It 'blocks unresolved P1 findings' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ P1Findings = @([PSCustomObject]@{ Id = 'P1-1'; Severity = 'P1'; Disposition = 'Open'; Resolved = $false }) })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.P1Disposition.Blocked | Should -BeTrue
            $gate.P1Disposition.UnresolvedCount | Should -Be 1
        }

        It 'requires P2 findings to be documented with disposition' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ P2Findings = @([PSCustomObject]@{ Id = 'P2-1'; Severity = 'P2'; Resolved = $true }) })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.P2Disposition.UnresolvedCount | Should -Be 1
        }

        It 'keeps live execution flags false in the final safety assertions' {
            $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
            $pack.FinalSafetyAssertions.LiveDeleteExecutable | Should -BeFalse
            $pack.FinalSafetyAssertions.LiveCleanupExecutable | Should -BeFalse
            $pack.FinalSafetyAssertions.GraphWritePathAvailable | Should -BeFalse
            $pack.FinalSafetyAssertions.ArmWritePathAvailable | Should -BeFalse
        }

        It 'blocks readiness when FullPesterEvidence is explicitly failed' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input -Overrides @{ FullPesterEvidence = [PSCustomObject]@{ Passed = $false; Status = 'Failed'; LocalOnly = $true } })
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.Status | Should -Be 'Blocked'
            $gate.Reasons -join ' ' | Should -Match 'Full Pester evidence must pass'
        }

        It 'records operator merge decision without executing it' {
            $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
            $pack.OperatorMergeDecision.Decision | Should -Be 'ReadyForReview'
            $pack.OperatorMergeDecision.IsExecuting | Should -BeFalse
        }

        It 'keeps the merge gate documentation-only' {
            $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
            $pack.MergeGate.ManualApprovalRequired | Should -BeTrue
            $pack.MergeGate.ExternalQARequired | Should -BeTrue
            $pack.MergeGate.DeleteBranchPerformed | Should -BeFalse
            $pack.MergeGate.TagPerformed | Should -BeFalse
        }

        It 'keeps production unlock disabled' {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (New-Rev49Input)
            $gate.FinalSafetyAssertions.ProductionUnlockGranted | Should -BeFalse
            $gate.FinalSafetyAssertions.ProductionExecutionEnabled | Should -BeFalse
        }

        It 'normalizes the sample warning inventory' {
            $pack = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessEvidencePack -Input $Payload } (New-Rev49Input)
            ($pack.KnownWarnings.Items | Where-Object { $_.Warning -match 'DemoMode traceability warning' }).Severity | Should -Be 'Low'
            ($pack.KnownWarnings.Items | Where-Object { $_.Warning -match 'empty-string binding messages' }).Disposition | Should -Be 'Documented'
        }

        It 'exports the production readiness evidence pack through the entry point' {
            $outputPath = Join-Path $TestDrive 'rev49-output'
            $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPointPath -ExecuteNhiControlledDecommission -ExecutionStage ProductionReadiness -DecommissionPlanPath $script:Rev49SamplePath -ApprovalManifestPath $script:Rev49SamplePath -WhatIfExecution -OutputPath $outputPath 2>&1
            $LASTEXITCODE | Should -Be 0
            ($output -join "`n") | Should -Match 'Rev4\.9 production readiness guardrails completed'
            ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
            @(Get-ChildItem -LiteralPath (Join-Path $outputPath 'controlled-decommission-RUN-REV49-PROD-001') -File).Count | Should -Be 6
        }

        It 'supports DemoMode simulation only through the entry point' {
            $outputPath = Join-Path $TestDrive 'rev49-demo'
            $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPointPath -ExecuteNhiControlledDecommission -ExecutionStage ProductionReadiness -DecommissionPlanPath $script:Rev49SamplePath -ApprovalManifestPath $script:Rev49SamplePath -DemoMode -OutputPath $outputPath 2>&1
            $LASTEXITCODE | Should -Be 0
            ($output -join "`n") | Should -Match 'Rev4\.9 production readiness guardrails completed'
            ($output -join "`n") | Should -Match 'No Graph connection or tenant mutation performed'
        }

        It 'keeps SelfTest before the controlled Graph connection path' {
            $source = Get-Content -LiteralPath $script:EntryPointPath -Raw
            $source.IndexOf('# SelfTest early exit - no Graph connection, discovery, or remediation') | Should -BeLessThan $source.IndexOf('Connect-MgGraph')
        }

        It 'writes JSON artifacts that parse cleanly' {
            $outputPath = Join-Path $TestDrive 'rev49-json'
            $null = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPointPath -ExecuteNhiControlledDecommission -ExecutionStage ProductionReadiness -DecommissionPlanPath $script:Rev49SamplePath -ApprovalManifestPath $script:Rev49SamplePath -WhatIfExecution -OutputPath $outputPath 2>&1
            $artifactPath = Join-Path $outputPath 'controlled-decommission-RUN-REV49-PROD-001\nhi-controlled-production-readiness.json'
            (Get-Content -LiteralPath $artifactPath -Raw | ConvertFrom-Json).SchemaVersion | Should -Be '4.9'
        }

        It 'fails closed when the production readiness plan omits Rev42PlannerEvidence' {
            $planPath = Join-Path $TestDrive 'rev49-missing-rev42.json'
            $approvalPath = Join-Path $TestDrive 'rev49-approval.json'
            New-Rev49PlanFile -Path $planPath -RemoveProperties @('Rev42PlannerEvidence') | Out-Null
            New-Rev49PlanFile -Path $approvalPath | Out-Null

            $outputPath = Join-Path $TestDrive 'rev49-missing-rev42-output'
            $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPointPath -ExecuteNhiControlledDecommission -ExecutionStage ProductionReadiness -DecommissionPlanPath $planPath -ApprovalManifestPath $approvalPath -WhatIfExecution -OutputPath $outputPath 2>&1
            $LASTEXITCODE | Should -Be 1
            ($output -join "`n") | Should -Match '\[SECURITY STOP\]'
            ($output -join "`n") | Should -Not -Match 'ReadyForReview'
        }

        It 'fails closed when the production readiness plan omits FullPesterEvidence' {
            $planPath = Join-Path $TestDrive 'rev49-missing-full-pester.json'
            $approvalPath = Join-Path $TestDrive 'rev49-approval.json'
            New-Rev49PlanFile -Path $planPath -RemoveProperties @('FullPesterEvidence') | Out-Null
            New-Rev49PlanFile -Path $approvalPath | Out-Null

            $outputPath = Join-Path $TestDrive 'rev49-missing-full-pester-output'
            $output = & pwsh -NoProfile -ExecutionPolicy Bypass -File $script:EntryPointPath -ExecuteNhiControlledDecommission -ExecutionStage ProductionReadiness -DecommissionPlanPath $planPath -ApprovalManifestPath $approvalPath -WhatIfExecution -OutputPath $outputPath 2>&1
            $LASTEXITCODE | Should -Be 1
            ($output -join "`n") | Should -Match '\[SECURITY STOP\]'
            ($output -join "`n") | Should -Not -Match 'ReadyForReview'
        }

        It 'keeps default Assessment out of the controlled readiness path' {
            $script:Source = Get-Content -LiteralPath $script:EntryPointPath -Raw
            $script:Source | Should -Match '# Rev4\.2-S1 controlled NHI decommission planner/evidence flow'
            $script:Source | Should -Not -Match 'if \(\$Mode -eq ''Assessment''.*ProductionReadiness'
        }
    }

    Describe 'Rev4.9 missing evidence blocks readiness' {
        It 'blocks <Name>' -ForEach @(
            @{ Name = 'missing Rev4.2 evidence'; Build = { New-Rev49Input -Overrides @{ Rev42PlannerEvidence = $null } }; Pattern = 'Rev42PlannerEvidence is required' }
            @{ Name = 'missing Rev4.3 evidence'; Build = { New-Rev49Input -Overrides @{ Rev43ServicePrincipalFinalDeleteSimulationEvidence = $null } }; Pattern = 'Rev43ServicePrincipalFinalDeleteSimulationEvidence is required' }
            @{ Name = 'missing Rev4.4 evidence'; Build = { New-Rev49Input -Overrides @{ Rev44ApplicationReadinessEvidence = $null } }; Pattern = 'Rev44ApplicationReadinessEvidence is required' }
            @{ Name = 'missing Rev4.5 evidence'; Build = { New-Rev49Input -Overrides @{ Rev45MetadataCleanupReadinessEvidence = $null } }; Pattern = 'Rev45MetadataCleanupReadinessEvidence is required' }
            @{ Name = 'missing Rev4.6 evidence'; Build = { New-Rev49Input -Overrides @{ Rev46GrantsCleanupReadinessEvidence = $null } }; Pattern = 'Rev46GrantsCleanupReadinessEvidence is required' }
            @{ Name = 'missing Rev4.7 evidence'; Build = { New-Rev49Input -Overrides @{ Rev47ManagedIdentityReadinessEvidence = $null } }; Pattern = 'Rev47ManagedIdentityReadinessEvidence is required' }
            @{ Name = 'missing Rev4.8 evidence'; Build = { New-Rev49Input -Overrides @{ Rev48E2EEvidencePackEvidence = $null } }; Pattern = 'Rev48E2EEvidencePackEvidence is required' }
            @{ Name = 'missing external QA evidence'; Build = { New-Rev49Input -Overrides @{ ExternalQaApprovalEvidence = $null } }; Pattern = 'ExternalQaApprovalEvidence is required' }
            @{ Name = 'missing full Pester evidence'; Build = { New-Rev49Input -Overrides @{ FullPesterEvidence = $null } }; Pattern = 'FullPesterEvidence is required' }
            @{ Name = 'missing safety scan evidence'; Build = { New-Rev49Input -Overrides @{ SafetyScanEvidence = $null } }; Pattern = 'SafetyScanEvidence is required' }
            @{ Name = 'missing frozen diff evidence'; Build = { New-Rev49Input -Overrides @{ FrozenFileDiffEvidence = $null } }; Pattern = 'FrozenFileDiffEvidence is required' }
            @{ Name = 'missing git status evidence'; Build = { New-Rev49Input -Overrides @{ GitStatusEvidence = $null } }; Pattern = 'GitStatusEvidence is required' }
        ) {
            $gate = Invoke-Rev49Module { param($Payload) New-NhiControlledProductionReadinessGate -Input $Payload } (& $Build)
            $gate.ProductionReadyForReview | Should -BeFalse
            $gate.Status | Should -Be 'Blocked'
            $gate.Reasons -join ' ' | Should -Match $Pattern
        }
    }
}

# =============================================================================
# Cross-revision merges (true duplicates: identical assertion code, different sample fixture)
# =============================================================================

# Merged: Rev43/44/45/46/47/48 each independently re-implemented this exact check against
# their OWN sample fixture (a different file per revision). The assertion code is identical
# across Rev43/44/45/46, and Rev47/48 widen the forbidden-cmdlet pattern to add "Remove-Az" --
# that widening is preserved per revision below (not applied backwards to Rev43-46, and not
# narrowed for Rev47/48), so no revision's original check is generalized or weakened. Collapsed
# into one -ForEach so the same two lines aren't hand-copied 6 times; every revision's sample
# is still validated with its own exact original pattern -- zero coverage lost.
# Note: the -ForEach data below intentionally recomputes each sample path/content inline
# (rather than referencing the shared BeforeAll's $script:RevXXSamplePath variables) because
# Pester evaluates -ForEach at Discovery time, before any BeforeAll has run.
Describe 'Rev4.3-Rev4.8 sample hygiene (secrets and delete cmdlets)' {
    It 'contains no secret-like values or delete cmdlet names (<Revision>)' -ForEach @(
        @{ Revision = 'Rev4.3'; RawSample = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-finaldelete-sp.sample.json') -Raw); DeletePattern = 'Remove-MgServicePrincipal|Remove-MgApplication' }
        @{ Revision = 'Rev4.4'; RawSample = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-finaldelete-application.sample.json') -Raw); DeletePattern = 'Remove-MgServicePrincipal|Remove-MgApplication' }
        @{ Revision = 'Rev4.5'; RawSample = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-metadata-cleanup.sample.json') -Raw); DeletePattern = 'Remove-MgServicePrincipal|Remove-MgApplication' }
        @{ Revision = 'Rev4.6'; RawSample = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-grants-cleanup.sample.json') -Raw); DeletePattern = 'Remove-MgServicePrincipal|Remove-MgApplication' }
        @{ Revision = 'Rev4.7'; RawSample = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-managed-identity-readiness.sample.json') -Raw); DeletePattern = 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az' }
        @{ Revision = 'Rev4.8'; RawSample = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-e2e-evidence-pack.sample.json') -Raw); DeletePattern = 'Remove-MgServicePrincipal|Remove-MgApplication|Remove-Az' }
    ) {
        $RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        $RawSample | Should -Not -Match $DeletePattern
    }
}

# Merged: Rev43 (ServicePrincipal FinalDelete sample) and Rev44 (Application FinalDelete
# sample) both had a byte-identical "exists and parses as JSON" assertion
# ($script:Sample | Should -Not -BeNullOrEmpty) against their own distinct sample file.
# Collapsed into one -ForEach over both fixtures; no coverage lost.
Describe 'Rev4.3-Rev4.4 sample artifacts parse cleanly' {
    It 'exists and parses as JSON (<Revision>)' -ForEach @(
        @{ Revision = 'Rev4.3 ServicePrincipal FinalDelete'; Sample = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-finaldelete-sp.sample.json') -Raw | ConvertFrom-Json) }
        @{ Revision = 'Rev4.4 Application FinalDelete'; Sample = (Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\samples\nhi-controlled-finaldelete-application.sample.json') -Raw | ConvertFrom-Json) }
    ) {
        $Sample | Should -Not -BeNullOrEmpty
    }
}
