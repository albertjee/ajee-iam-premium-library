#Requires -Version 5.1

Describe 'SchemaContracts.psm1' {
    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module SchemaContracts -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'SchemaContracts.psm1') -Force -DisableNameChecking
    }

    AfterAll {
        Remove-Module SchemaContracts -Force -ErrorAction SilentlyContinue
    }

    It 'Get-DecomSchemaContract should return Finding contract with required fields' {
        $contract = Get-DecomSchemaContract -ObjectType 'Finding'
        $contract.SchemaVersion | Should -Be '3.3'
        $contract.RequiredFields | Should -Contain 'FindingId'
        $contract.RequiredFields | Should -Contain 'Severity'
        $contract.RequiredFields | Should -Contain 'RiskScore'
        $contract.FieldTypes['RiskScore'] | Should -Be 'int'
        $contract.AllowedValues['Severity'] | Should -Contain 'Critical'
        $contract.AllowedValues['RemediationMode'] | Should -Contain 'AutoRemediable'
    }

    It 'Finding schema contract defines Confidence as string with allowed values High, Medium, Low' {
        $contract = Get-DecomSchemaContract -ObjectType 'Finding'
        $contract.FieldTypes['Confidence'] | Should -Be 'string'
        $contract.AllowedValues['Confidence'] | Should -Contain 'High'
        $contract.AllowedValues['Confidence'] | Should -Contain 'Medium'
        $contract.AllowedValues['Confidence'] | Should -Contain 'Low'
        $contract.AllowedValues['Confidence'].Count | Should -Be 3
    }

    It 'Test-DecomObjectAgainstSchemaContract should pass valid Finding object' {
        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-USER-001'
            Category          = 'DEC-USER'
            Severity          = 'High'
            RiskScore         = 75
            Confidence        = 'High'
            ObjectType        = 'User'
            ObjectId          = 'user123'
            DisplayName       = 'Test User'
            UserPrincipalName = 'user@contoso.com'
            Evidence          = 'Group membership observed'
            EvidenceSource    = 'Azure AD'
            GraphEndpoint     = '/users/user123/memberOf'
            RecommendedAction = 'Remove from group'
            RemediationMode   = 'AutoRemediable'
            ConsultantNote    = 'Review business need'
        }

        $contract = Get-DecomSchemaContract -ObjectType 'Finding'
        $result = Test-DecomObjectAgainstSchemaContract -Object $finding -Contract $contract
        $result.Passed | Should -Be $true
        $result.Errors.Count | Should -Be 0
    }

    It 'Test-DecomObjectAgainstSchemaContract should fail on missing required field' {
        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-USER-001'
            Category          = 'DEC-USER'
            Severity          = 'High'
            RiskScore         = 75
            # Confidence missing intentionally
            ObjectType        = 'User'
            ObjectId          = 'user123'
            DisplayName       = 'Test User'
            UserPrincipalName = 'user@contoso.com'
            Evidence          = 'Group membership observed'
            EvidenceSource    = 'Azure AD'
            GraphEndpoint     = '/users/user123/memberOf'
            RecommendedAction = 'Remove from group'
            RemediationMode   = 'AutoRemediable'
            ConsultantNote    = 'Review business need'
        }

        $contract = Get-DecomSchemaContract -ObjectType 'Finding'
        $result = Test-DecomObjectAgainstSchemaContract -Object $finding -Contract $contract
        $result.Passed | Should -Be $false
        $result.MissingFields.Count | Should -BeGreaterThan 0
    }

    It 'Test-DecomObjectAgainstSchemaContract should fail on invalid Severity' {
        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-USER-001'
            Category          = 'DEC-USER'
            Severity          = 'InvalidSeverity'
            RiskScore         = 75
            Confidence        = 'High'
            ObjectType        = 'User'
            ObjectId          = 'user123'
            DisplayName       = 'Test User'
            UserPrincipalName = 'user@contoso.com'
            Evidence          = 'Group membership observed'
            EvidenceSource    = 'Azure AD'
            GraphEndpoint     = '/users/user123/memberOf'
            RecommendedAction = 'Remove from group'
            RemediationMode   = 'AutoRemediable'
            ConsultantNote    = 'Review business need'
        }

        $contract = Get-DecomSchemaContract -ObjectType 'Finding'
        $result = Test-DecomObjectAgainstSchemaContract -Object $finding -Contract $contract
        $result.Passed | Should -Be $false
        $result.InvalidValues.Count | Should -BeGreaterThan 0
        $result.InvalidValues[0] | Should -Match 'Severity.*InvalidSeverity'
    }

    It 'Test-DecomObjectAgainstSchemaContract should fail on wrong RiskScore type' {
        $finding = [PSCustomObject]@{
            FindingId         = 'DEC-USER-001'
            Category          = 'DEC-USER'
            Severity          = 'High'
            RiskScore         = 'not-a-number'
            Confidence        = 'High'
            ObjectType        = 'User'
            ObjectId          = 'user123'
            DisplayName       = 'Test User'
            UserPrincipalName = 'user@contoso.com'
            Evidence          = 'Group membership observed'
            EvidenceSource    = 'Azure AD'
            GraphEndpoint     = '/users/user123/memberOf'
            RecommendedAction = 'Remove from group'
            RemediationMode   = 'AutoRemediable'
            ConsultantNote    = 'Review business need'
        }

        $contract = Get-DecomSchemaContract -ObjectType 'Finding'
        $result = Test-DecomObjectAgainstSchemaContract -Object $finding -Contract $contract
        $result.Passed | Should -Be $false
        $result.TypeMismatches.Count | Should -BeGreaterThan 0
    }

    It 'Export-DecomSchemaContractsMarkdown should generate documentation file' {
        $testPath = Join-Path $env:TEMP 'Schema-Contracts-test.md'
        try {
            Export-DecomSchemaContractsMarkdown -OutputPath $testPath
            Test-Path $testPath | Should -Be $true
            $content = Get-Content $testPath -Raw
            $content | Should -Match 'Schema Contracts'
            $content | Should -Match 'Finding Schema'
            $content | Should -Match 'Required Fields'
        } finally {
            if (Test-Path $testPath) { Remove-Item $testPath -Force }
        }
    }
}
