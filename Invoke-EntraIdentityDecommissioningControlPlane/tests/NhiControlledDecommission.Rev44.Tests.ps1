#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-finaldelete-application.sample.json'
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

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
}

AfterAll {
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
}

Describe 'Rev4.4 Application delete-readiness contract' {
    It 'keeps the evaluator private and public export contract frozen' {
        Get-Command Test-NhiControlledApplicationDeleteReadinessGate -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        (Get-Module NhiControlledDecommission).ExportedFunctions.Keys.Count | Should -Be 11
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
        $script:RawSample = Get-Content -LiteralPath $script:SamplePath -Raw
        $script:Sample = $script:RawSample | ConvertFrom-Json
    }

    It 'exists and parses as JSON' {
        $script:Sample | Should -Not -BeNullOrEmpty
    }

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

    It 'contains no secret-like values or delete cmdlet names' {
        $script:RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        $script:RawSample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication'
    }
}
