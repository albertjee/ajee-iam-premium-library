#Requires -Modules Pester

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiControlledDecommission.psm1'
    $script:SamplePath = Join-Path $PSScriptRoot '..\samples\nhi-controlled-finaldelete-sp.sample.json'
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
    Import-Module $script:ModulePath -Force -DisableNameChecking

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
}

AfterAll {
    Remove-Module NhiControlledDecommission -Force -ErrorAction SilentlyContinue
}

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
        $script:RawSample = Get-Content -LiteralPath $script:SamplePath -Raw
        $script:Sample = $script:RawSample | ConvertFrom-Json
    }

    It 'exists and parses as JSON' {
        $script:Sample | Should -Not -BeNullOrEmpty
    }

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

    It 'contains no secret-like values or delete cmdlet names' {
        $script:RawSample | Should -Not -Match '(?i)"(?:secret|token|privatekey|certificatevalue|keyvalue|password|credentialvalue)"\s*:'
        $script:RawSample | Should -Not -Match 'Remove-MgServicePrincipal|Remove-MgApplication'
    }
}
