#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev1.1 Safety Tests' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\modules'

        Remove-Module Utilities       -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery       -Force -ErrorAction SilentlyContinue
        Remove-Module Analysis        -Force -ErrorAction SilentlyContinue
        Remove-Module Reporting       -Force -ErrorAction SilentlyContinue
        Remove-Module RemediationPlan -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Analysis.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Reporting.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'RemediationPlan.psm1') -Force -DisableNameChecking
    }

    Context 'Default mode is Assessment' {
        It 'Entry point parameter default for Mode is Assessment' {
            $ep = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ep, [ref]$null, [ref]$null)
            $paramBlock = $ast.ParamBlock
            $modeParam = $paramBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Mode' }
            $modeParam | Should -Not -BeNullOrEmpty
            $defaultValue = $modeParam.DefaultValue.Value
            $defaultValue | Should -Be 'Assessment'
        }
    }

    Context 'Assessment mode does not expose remediation execution functions' {
        It 'ExecuteRemediation is not a public function exported by any module' {
            $remediationFns = Get-Command -Name '*ExecuteRemediation*' -ErrorAction SilentlyContinue
            $remediationFns | Should -BeNullOrEmpty
        }
    }

    Context 'ExecuteRemediation requires explicit parameter' {
        It 'Entry point ValidateSet for Mode includes ExecuteRemediation but is not default' {
            $ep = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            $content = Get-Content $ep -Raw
            $content | Should -Match "ExecuteRemediation"
            $content | Should -Match "Mode.*=.*'Assessment'"
        }
    }

    Context 'New-DecomFinding ProtectedObject flag' {
        It 'New-DecomFinding with ProtectedObject=$true sets flag correctly' {
            $finding = New-DecomFinding `
                -FindingId 'TEST-001' `
                -Category 'Test' `
                -Severity 'Low' `
                -RiskScore 25 `
                -Confidence 'Low' `
                -ObjectType 'User' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'TestUser' `
                -Evidence 'Test evidence' `
                -EvidenceSource 'test' `
                -RecommendedAction 'Test action' `
                -RemediationMode 'ManualApprovalRequired' `
                -ProtectedObject $true
            $finding.ProtectedObject | Should -Be $true
        }
    }

    Context 'Protected pattern classification' {
        It 'DisplayName containing breakglass is classified ProtectedObject by Invoke-DecomAnalysis' {
            $finding = New-DecomFinding `
                -FindingId 'TEST-BG-001' `
                -Category 'User Lifecycle' `
                -Severity 'Critical' `
                -RiskScore 95 `
                -Confidence 'High' `
                -ObjectType 'User' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'breakglass-admin' `
                -Evidence 'Protected account in privileged role' `
                -EvidenceSource 'test' `
                -RecommendedAction 'Review' `
                -RemediationMode 'ProtectedObject'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].ProtectedObject | Should -Be $true
        }
    }

    Context 'Discovery module does not call destructive verbs' {
        It 'Discovery.psm1 source contains no Remove-, Set-, or Disable- calls' {
            $discoveryPath = Join-Path $script:ModulesPath 'Discovery.psm1'
            $content = Get-Content $discoveryPath -Raw
            $content | Should -Not -Match '\bRemove-Mg'
            $content | Should -Not -Match '\bSet-Mg'
            $content | Should -Not -Match '\bDisable-Mg'
        }
    }

    Context 'Rev1.2 ExecuteRemediation guard and pattern classification' {
        It 'ExecuteRemediation mode is blocked in entry point source' {
            $ep = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            $content = Get-Content $ep -Raw
            $content | Should -Match 'ExecuteRemediation'
            $content | Should -Match 'reserved for a future release'
        }

        It 'Protected pattern svc- is classified as ProtectedObject' {
            $finding = New-DecomFinding `
                -FindingId 'SVC-001' -Category 'User Lifecycle' -Severity 'Medium' -RiskScore 50 `
                -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'svc-automation-account' -UserPrincipalName 'svc-auto@contoso.com' `
                -Evidence 'Service account test' -EvidenceSource 'test' `
                -RecommendedAction 'Review' -RemediationMode 'ManualApprovalRequired'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].ProtectedObject | Should -Be $true
        }
    }
}
