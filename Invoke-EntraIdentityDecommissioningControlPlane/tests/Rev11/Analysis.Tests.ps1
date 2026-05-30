#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev1.1 Analysis Tests' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\modules'

        Remove-Module Utilities -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery -Force -ErrorAction SilentlyContinue
        Remove-Module Analysis  -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Analysis.psm1')  -Force -DisableNameChecking
    }

    Context 'Severity classification — disabled user with privileged role' {
        It 'Disabled user with privileged role finding has Severity Critical and RiskScore >= 80' {
            $finding = New-DecomFinding `
                -FindingId 'DEC-USER-003' `
                -Category 'User Lifecycle' `
                -Severity 'Critical' `
                -RiskScore 92 `
                -Confidence 'High' `
                -ObjectType 'User' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'Disabled Admin User' `
                -Evidence 'Disabled user retains Global Administrator role assignment' `
                -EvidenceSource 'directoryRoles' `
                -RecommendedAction 'Remove role assignment' `
                -RemediationMode 'ManualApprovalRequired'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].Severity   | Should -Be 'Critical'
            $result[0].RiskScore  | Should -BeGreaterOrEqual 80
        }
    }

    Context 'Severity classification — guest with privileged access' {
        It 'Guest with privileged access finding is classified Critical when RiskScore >= 80' {
            $finding = New-DecomFinding `
                -FindingId 'DEC-GUEST-002' `
                -Category 'Guest Lifecycle' `
                -Severity 'Critical' `
                -RiskScore 85 `
                -Confidence 'High' `
                -ObjectType 'User' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'ext_partner@fabrikam.com' `
                -Evidence 'Guest holds privileged role' `
                -EvidenceSource 'directoryRoles' `
                -RecommendedAction 'Review guest privileged access' `
                -RemediationMode 'ManualApprovalRequired'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].Severity | Should -Be 'Critical'
        }
    }

    Context 'Severity classification — app with no owner' {
        It 'App with no owner finding has Severity High or Critical' {
            $finding = New-DecomFinding `
                -FindingId 'DEC-APP-001' `
                -Category 'Application' `
                -Severity 'High' `
                -RiskScore 65 `
                -Confidence 'High' `
                -ObjectType 'Application' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'Ownerless App' `
                -Evidence 'Application has no owner assigned' `
                -EvidenceSource 'applications' `
                -RecommendedAction 'Assign owner' `
                -RemediationMode 'ManualApprovalRequired'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].Severity | Should -BeIn @('High','Critical')
        }
    }

    Context 'Severity classification — informational' {
        It 'Informational finding has RiskScore <= 24' {
            $finding = New-DecomFinding `
                -FindingId 'DEC-IGA-001' `
                -Category 'Governance' `
                -Severity 'Informational' `
                -RiskScore 18 `
                -Confidence 'Low' `
                -ObjectType 'TenantScope' `
                -ObjectId 'contoso.onmicrosoft.com' `
                -DisplayName 'Entitlement Management' `
                -Evidence 'AuditLog.Read.All unavailable' `
                -EvidenceSource 'graphPermissions' `
                -RecommendedAction 'Request missing scopes' `
                -RemediationMode 'InformationOnly'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].Severity  | Should -Be 'Informational'
            $result[0].RiskScore | Should -BeLessOrEqual 24
        }
    }

    Context 'Get-DecomFindingSummary' {
        It 'Returns correct counts for mixed severity input' {
            $findings = @(
                (New-DecomFinding -FindingId 'T1' -Category 'Test' -Severity 'Critical'      -RiskScore 92 -Confidence 'High'   -ObjectType 'User'   -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'A' -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'ManualApprovalRequired'),
                (New-DecomFinding -FindingId 'T2' -Category 'Test' -Severity 'High'          -RiskScore 70 -Confidence 'High'   -ObjectType 'User'   -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'B' -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'ManualApprovalRequired'),
                (New-DecomFinding -FindingId 'T3' -Category 'Test' -Severity 'High'          -RiskScore 65 -Confidence 'Medium' -ObjectType 'User'   -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'C' -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'ManualApprovalRequired'),
                (New-DecomFinding -FindingId 'T4' -Category 'Test' -Severity 'Medium'        -RiskScore 50 -Confidence 'Medium' -ObjectType 'Group'  -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'D' -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'ManualApprovalRequired'),
                (New-DecomFinding -FindingId 'T5' -Category 'Test' -Severity 'Low'           -RiskScore 30 -Confidence 'Low'   -ObjectType 'User'   -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'E' -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'ManualApprovalRequired'),
                (New-DecomFinding -FindingId 'T6' -Category 'Test' -Severity 'Informational' -RiskScore 10 -Confidence 'Low'   -ObjectType 'Tenant' -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'F' -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'InformationOnly')
            )
            $summary = Get-DecomFindingSummary -Findings $findings
            $summary.Critical      | Should -Be 1
            $summary.High          | Should -Be 2
            $summary.Medium        | Should -Be 1
            $summary.Low           | Should -Be 1
            $summary.Informational | Should -Be 1
            $summary.Total         | Should -Be 6
        }
    }

    Context 'Invoke-DecomAnalysis sort order' {
        It 'Invoke-DecomAnalysis returns Critical findings before High before Medium' {
            $findings = @(
                (New-DecomFinding -FindingId 'S1' -Category 'Test' -Severity 'Medium'   -RiskScore 45 -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'MedFinding'  -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'ManualApprovalRequired'),
                (New-DecomFinding -FindingId 'S2' -Category 'Test' -Severity 'Critical' -RiskScore 95 -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'CritFinding' -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'ManualApprovalRequired'),
                (New-DecomFinding -FindingId 'S3' -Category 'Test' -Severity 'High'     -RiskScore 70 -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) -DisplayName 'HighFinding' -Evidence 'e' -EvidenceSource 's' -RecommendedAction 'r' -RemediationMode 'ManualApprovalRequired')
            )
            $result = Invoke-DecomAnalysis -Findings $findings
            $result[0].Severity | Should -Be 'Critical'
            $result[1].Severity | Should -Be 'High'
            $result[2].Severity | Should -Be 'Medium'
        }
    }

    Context 'Rev1.2 null-safety and empty-input guards' {
        It 'Invoke-DecomAnalysis tolerates null DisplayName and UserPrincipalName' {
            $finding = New-DecomFinding `
                -FindingId 'NULL-001' -Category 'Test' -Severity 'Low' -RiskScore 30 `
                -Confidence 'Low' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName $null -UserPrincipalName $null `
                -Evidence 'Null field test' -EvidenceSource 'test' `
                -RecommendedAction 'Review' -RemediationMode 'ManualApprovalRequired'
            { Invoke-DecomAnalysis -Findings @($finding) } | Should -Not -Throw
        }

        It 'Protected objects are forced to RemediationMode ProtectedObject after analysis' {
            $finding = New-DecomFinding `
                -FindingId 'PROT-001' -Category 'User Lifecycle' -Severity 'Medium' -RiskScore 55 `
                -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'svc-breakglass-admin' -UserPrincipalName 'svc-breakglass@contoso.com' `
                -Evidence 'Protected object test' -EvidenceSource 'test' `
                -RecommendedAction 'Remove access' -RemediationMode 'AutoRemediable'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].ProtectedObject | Should -Be $true
            $result[0].RemediationMode | Should -Be 'ProtectedObject'
        }

        It 'Invoke-DecomAnalysis handles empty findings array without error' {
            { Invoke-DecomAnalysis -Findings @() } | Should -Not -Throw
        }

        It 'Get-DecomFindingSummary returns zero counts for empty input' {
            $summary = Get-DecomFindingSummary -Findings @()
            $summary.Total    | Should -Be 0
            $summary.Critical | Should -Be 0
        }
    }

    Context 'Rev1.3 severity mapping for new finding IDs' {
        It 'DEC-APP-002 RiskScore 88 maps to Critical severity' {
            $finding = New-DecomFinding `
                -FindingId 'DEC-APP-002' -Category 'Application' -Severity 'Critical' -RiskScore 88 `
                -Confidence 'High' -ObjectType 'Application' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'Test App' -UserPrincipalName '' `
                -Evidence 'Owned by disabled user' -EvidenceSource 'test' `
                -RecommendedAction 'Assign owner' -RemediationMode 'ManualApprovalRequired'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].Severity | Should -Be 'Critical'
        }

        It 'DEC-APP-005 RiskScore 68 maps to High severity' {
            $finding = New-DecomFinding `
                -FindingId 'DEC-APP-005' -Category 'Application' -Severity 'High' -RiskScore 68 `
                -Confidence 'High' -ObjectType 'Application' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'Legacy App' -UserPrincipalName '' `
                -Evidence 'Expired credential attached' -EvidenceSource 'test' `
                -RecommendedAction 'Remove credential' -RemediationMode 'ManualApprovalRequired'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].Severity | Should -Be 'High'
        }

        It 'DEC-USER-002 RiskScore 72 maps to High severity' {
            $finding = New-DecomFinding `
                -FindingId 'DEC-USER-002' -Category 'User Lifecycle' -Severity 'High' -RiskScore 72 `
                -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'Morgan Chen' -UserPrincipalName 'morgan.chen@contoso.com' `
                -Evidence 'Retains 3 app role assignments' -EvidenceSource 'test' `
                -RecommendedAction 'Revoke assignments' -RemediationMode 'ManualApprovalRequired'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].Severity | Should -Be 'High'
        }
    }
}
