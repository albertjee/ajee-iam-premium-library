#Requires -Version 5.1

Describe 'P1Fixes.Rev32 — Scope Gate and Stale-Credential Skip' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        $script:EntryPoint  = Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'

        foreach ($m in @('Utilities','ExecutionLog','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ExecutionLog.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Remediation.psm1')  -Force -DisableNameChecking

        $script:EntryContent = Get-Content $script:EntryPoint -Raw
        # M4: region F (ExecuteRemediation branch, $writeScopes, Assessment/WhatIfRemediation
        # scope guards) moved to src/EntryPoint/AssessmentFlow.ps1
        $script:AssessmentFlowPath = Join-Path $PSScriptRoot '..\src\EntryPoint\AssessmentFlow.ps1'
        $script:AssessmentFlowContent = Get-Content -LiteralPath $script:AssessmentFlowPath -Raw
    }

    AfterAll {
        foreach ($m in @('Remediation','ExecutionLog','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── P1-01: Scope gate ──────────────────────────────────────────────────────

    It 'ExecuteRemediation write scopes include Application.ReadWrite.All' {
        $execBlock = $script:AssessmentFlowContent -replace '(?s)^.*?(?=\$writeScopes\s*=\s*@)', ''
        $execBlock | Should -Match 'Application\.ReadWrite\.All'
    }

    It 'Assessment mode does not request Application.ReadWrite.All' {
        $assessBlock = $script:AssessmentFlowContent -replace '(?s)if\s*\(\$Mode\s*-eq\s*[''"]ExecuteRemediation[''"].*', ''
        $assessBlock | Should -Not -Match 'Application\.ReadWrite\.All'
    }

    It 'WhatIfRemediation mode does not request Application.ReadWrite.All' {
        $nonExecBlock = $script:AssessmentFlowContent -replace '(?s)if\s*\(\$Mode\s*-eq\s*[''"]ExecuteRemediation[''"].*', ''
        $nonExecBlock | Should -Not -Match 'Application\.ReadWrite\.All'
    }

    # ── P1-02: Already-removed credential → Skipped (mocked) ──────────────────

    It 'Already-removed expired credential logs Skipped not Executed' {
        # All targets already gone → all InvalidTargets → Skipped, no write cmdlet.
        InModuleScope Remediation {
            $appObjId  = [guid]::NewGuid().ToString()
            $keyId     = [guid]::NewGuid().ToString()
            $expiredDt = (Get-Date).ToUniversalTime().AddDays(-30).ToString('o')
            $staleMsg  = "$keyId : credential not found (already removed or never existed)"

            $action = [PSCustomObject]@{
                ActionId             = [guid]::NewGuid().ToString()
                FindingId            = 'DEC-APP-005'
                ActionType           = 'RemoveExpiredApplicationCredential'
                ObjectId             = $appObjId
                ObjectType           = 'Application'
                DisplayName          = 'TestApp'
                TargetObjectIds      = @($keyId)
                CredentialType       = 'PasswordCredential'
                CredentialEndDateTime= $expiredDt
                CredentialExpired    = $true
                ProtectedObject      = $false
            }

            $executionLog = [PSCustomObject]@{
                Log = [PSCustomObject]@{ Actions = [System.Collections.Generic.List[object]]::new() }
                Path = ''
            }

            Mock Confirm-DecomActionTargetValid {
                [PSCustomObject]@{
                    Valid            = $true
                    InvalidTargets   = [System.Collections.Generic.List[string]] @($staleMsg)
                    ValidationErrors = [System.Collections.Generic.List[string]]::new()
                    ErrorDetail      = ''
                }
            }
            Mock Get-DecomTargetState {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @(); ErrorDetail = '' }
            }
            Mock Remove-MgApplicationPassword {}
            Mock Remove-MgApplicationKey      {}

            Invoke-DecomRemediation -ApprovedActions @($action) `
                -ExecutionLog $executionLog -AllowNonInteractive $true

            $logged = @($executionLog.Log.Actions)
            $logged.Count | Should -Be 1 -Because 'exactly one action should be logged'
            $logged[0].Outcome | Should -Be 'Skipped' -Because 'all targets already removed'

            Assert-MockCalled Remove-MgApplicationPassword -Times 0 -Scope It
            Assert-MockCalled Remove-MgApplicationKey      -Times 0 -Scope It
        }
    }

    It 'Mixed already-removed and present credential targets do not overstate full execution' {
        # keyId1 stale (1 of 2) — all-stale skip path must NOT fire.
        # keyId2 present — Remove-MgApplicationPassword called exactly once.
        InModuleScope Remediation {
            $appObjId  = [guid]::NewGuid().ToString()
            $keyId1    = [guid]::NewGuid().ToString()
            $keyId2    = [guid]::NewGuid().ToString()
            $expiredDt = (Get-Date).ToUniversalTime().AddDays(-30).ToString('o')
            $staleMsg  = "$keyId1 : credential not found (already removed or never existed)"

            $action = [PSCustomObject]@{
                ActionId             = [guid]::NewGuid().ToString()
                FindingId            = 'DEC-APP-005'
                ActionType           = 'RemoveExpiredApplicationCredential'
                ObjectId             = $appObjId
                ObjectType           = 'Application'
                DisplayName          = 'TestApp'
                TargetObjectIds      = @($keyId1, $keyId2)
                CredentialType       = 'PasswordCredential'
                CredentialEndDateTime= $expiredDt
                CredentialExpired    = $true
                ProtectedObject      = $false
            }

            $executionLog = [PSCustomObject]@{
                Log = [PSCustomObject]@{ Actions = [System.Collections.Generic.List[object]]::new() }
                Path = ''
            }

            Mock Confirm-DecomActionTargetValid {
                [PSCustomObject]@{
                    Valid            = $true
                    InvalidTargets   = [System.Collections.Generic.List[string]] @($staleMsg)
                    ValidationErrors = [System.Collections.Generic.List[string]]::new()
                    ErrorDetail      = ''
                }
            }

            $presentKeyId = $keyId2
            $fakeApp = [PSCustomObject]@{
                Id = $appObjId
                PasswordCredentials = @(
                    [PSCustomObject]@{ KeyId = $presentKeyId; EndDateTime = (Get-Date).AddDays(-30) }
                )
                KeyCredentials = @()
            }
            Mock Get-MgApplication { $fakeApp }
            Mock Get-DecomTargetState {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @(); ErrorDetail = '' }
            }
            Mock Remove-MgApplicationPassword {}

            Invoke-DecomRemediation -ApprovedActions @($action) `
                -ExecutionLog $executionLog -AllowNonInteractive $true

            # Action was NOT fully skipped (not all targets were stale)
            $logged = @($executionLog.Log.Actions)
            $logged.Count | Should -Be 1
            $logged[0].Outcome | Should -Not -Be 'Skipped' -Because 'only one of two targets was stale'

            # keyId2 must have been attempted
            Assert-MockCalled Remove-MgApplicationPassword -Times 1 -Scope It
        }
    }

    It 'Successful credential removal logs Executed only after post-write re-query confirms KeyId absent' {
        # Single expired credential; write succeeds; re-query shows credential gone → Executed.
        InModuleScope Remediation {
            $appObjId  = [guid]::NewGuid().ToString()
            $keyId     = [guid]::NewGuid().ToString()
            $expiredDt = (Get-Date).ToUniversalTime().AddDays(-30).ToString('o')

            $action = [PSCustomObject]@{
                ActionId             = [guid]::NewGuid().ToString()
                FindingId            = 'DEC-APP-005'
                ActionType           = 'RemoveExpiredApplicationCredential'
                ObjectId             = $appObjId
                ObjectType           = 'Application'
                DisplayName          = 'TestApp'
                TargetObjectIds      = @($keyId)
                CredentialType       = 'PasswordCredential'
                CredentialEndDateTime= $expiredDt
                CredentialExpired    = $true
                ProtectedObject      = $false
            }

            $executionLog = [PSCustomObject]@{
                Log = [PSCustomObject]@{ Actions = [System.Collections.Generic.List[object]]::new() }
                Path = ''
            }

            Mock Confirm-DecomActionTargetValid {
                [PSCustomObject]@{
                    Valid            = $true
                    InvalidTargets   = [System.Collections.Generic.List[string]]::new()
                    ValidationErrors = [System.Collections.Generic.List[string]]::new()
                    ErrorDetail      = ''
                }
            }

            $presentKeyId = $keyId
            $fakeApp = [PSCustomObject]@{
                Id = $appObjId
                PasswordCredentials = @(
                    [PSCustomObject]@{ KeyId = $presentKeyId; EndDateTime = (Get-Date).AddDays(-30) }
                )
                KeyCredentials = @()
            }
            Mock Get-MgApplication { $fakeApp }
            Mock Remove-MgApplicationPassword {}

            # Post-write re-query: credential gone (PresentTargetIds empty)
            Mock Get-DecomTargetState {
                [PSCustomObject]@{ QuerySucceeded = $true; PresentTargetIds = @(); ErrorDetail = '' }
            }

            Invoke-DecomRemediation -ApprovedActions @($action) `
                -ExecutionLog $executionLog -AllowNonInteractive $true

            $logged = @($executionLog.Log.Actions)
            $logged.Count | Should -Be 1
            $logged[0].Outcome | Should -Be 'Executed' -Because 'write + re-query confirmed removal'

            Assert-MockCalled Remove-MgApplicationPassword -Times 1 -Scope It
        }
    }
}
