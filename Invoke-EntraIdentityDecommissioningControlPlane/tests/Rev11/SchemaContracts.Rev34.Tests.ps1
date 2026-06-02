#Requires -Version 5.1

Describe 'SchemaContracts.psm1 — Rev3.4 Schemas' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module SchemaContracts -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'SchemaContracts.psm1') -Force -DisableNameChecking
    }

    AfterAll {
        Remove-Module SchemaContracts -Force -ErrorAction SilentlyContinue
    }

    It 'Get-DecomSchemaContract returns OutputManifest contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'OutputManifest'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'ToolVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
        $contract.RequiredFields | Should -Contain 'EngagementId'
        $contract.RequiredFields | Should -Contain 'ClientName'
        $contract.RequiredFields | Should -Contain 'OutputRoot'
        $contract.RequiredFields | Should -Contain 'Files'
        $contract.RequiredFields | Should -Contain 'Summary'
    }

    It 'Get-DecomSchemaContract returns EvidenceBundleManifest contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'EvidenceBundleManifest'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'ToolVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'BundleId'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
        $contract.RequiredFields | Should -Contain 'SourceOutputPath'
        $contract.RequiredFields | Should -Contain 'BundleOutputPath'
        $contract.RequiredFields | Should -Contain 'FileCount'
        $contract.RequiredFields | Should -Contain 'TotalBytes'
        $contract.RequiredFields | Should -Contain 'Files'
    }

    It 'Get-DecomSchemaContract returns EvidenceHashManifest contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'EvidenceHashManifest'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'ToolVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
        $contract.RequiredFields | Should -Contain 'Hashes'
    }

    It 'Get-DecomSchemaContract returns RedactionReport contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'RedactionReport'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'ProfileName'
        $contract.RequiredFields | Should -Contain 'TokenCount'
        $contract.RequiredFields | Should -Contain 'RedactedFileCount'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
    }

    It 'Get-DecomSchemaContract returns ReplayValidationReport contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'ReplayValidationReport'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'ToolVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
        $contract.RequiredFields | Should -Contain 'OverallPassed'
        $contract.RequiredFields | Should -Contain 'Checks'
    }

    It 'Get-DecomSchemaContract returns ApprovalDiffReport contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'ApprovalDiffReport'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'ToolVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
        $contract.RequiredFields | Should -Contain 'Passed'
        $contract.RequiredFields | Should -Contain 'DiffItems'
        $contract.RequiredFields | Should -Contain 'Summary'
    }

    It 'Get-DecomSchemaContract returns TraceabilityReport contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'TraceabilityReport'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'ToolVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
        $contract.RequiredFields | Should -Contain 'Entries'
        $contract.RequiredFields | Should -Contain 'Summary'
    }

    It 'Get-DecomSchemaContract returns ClientHandoffManifest contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'ClientHandoffManifest'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'ToolVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
        $contract.RequiredFields | Should -Contain 'EngagementId'
        $contract.RequiredFields | Should -Contain 'ClientName'
        $contract.RequiredFields | Should -Contain 'ValidationStatus'
        $contract.RequiredFields | Should -Contain 'Sections'
        $contract.RequiredFields | Should -Contain 'ClientSafeFiles'
        $contract.RequiredFields | Should -Contain 'SensitiveFiles'
        $contract.RequiredFields | Should -Contain 'Warnings'
    }

    It 'Get-DecomSchemaContract returns Rev35ReadinessReport contract with SchemaVersion 3.4' {
        $contract = Get-DecomSchemaContract -ObjectType 'Rev35ReadinessReport'
        $contract.SchemaVersion | Should -Be '3.4'
        $contract.RequiredFields | Should -Contain 'SchemaVersion'
        $contract.RequiredFields | Should -Contain 'ToolVersion'
        $contract.RequiredFields | Should -Contain 'RunId'
        $contract.RequiredFields | Should -Contain 'GeneratedUtc'
        $contract.RequiredFields | Should -Contain 'ReadinessScore'
        $contract.RequiredFields | Should -Contain 'NhiDetectorsImplemented'
        $contract.RequiredFields | Should -Contain 'AgentIdentityDetectorsImplemented'
        $contract.RequiredFields | Should -Contain 'Checks'
        $contract.RequiredFields | Should -Contain 'Summary'
    }

    It 'Test-DecomObjectAgainstSchemaContract validates a valid OutputManifest object' {
        $manifest = [PSCustomObject]@{
            SchemaVersion   = '3.4'
            ToolVersion     = 'Rev3.4'
            RunId           = 'run-123'
            GeneratedUtc    = (Get-Date).ToUniversalTime().ToString('o')
            EngagementId    = 'eng-123'
            ClientName      = 'Client A'
            OutputRoot      = '.\out'
            Files           = @()
            Summary         = [ordered]@{
                TotalFiles        = 0
                TotalSizeBytes    = 0
                PublicFiles       = 0
                ClientSafeFiles   = 0
                ConfidentialFiles = 0
                RestrictedFiles   = 0
            }
        }
        $contract = Get-DecomSchemaContract -ObjectType 'OutputManifest'
        $result = Test-DecomObjectAgainstSchemaContract -Object $manifest -Contract $contract
        $result.Passed | Should -Be $true
        $result.Errors.Count | Should -Be 0
    }

    It 'Test-DecomObjectAgainstSchemaContract detects missing field in OutputManifest' {
        $manifest = [PSCustomObject]@{
            SchemaVersion   = '3.4'
            ToolVersion     = 'Rev3.4'
            RunId           = 'run-123'
            GeneratedUtc    = (Get-Date).ToUniversalTime().ToString('o')
            EngagementId    = 'eng-123'
            ClientName      = 'Client A'
            OutputRoot      = '.\out'
            Files           = @()
            # Missing Summary
        }
        $contract = Get-DecomSchemaContract -ObjectType 'OutputManifest'
        $result = Test-DecomObjectAgainstSchemaContract -Object $manifest -Contract $contract
        $result.Passed | Should -Be $false
        $result.MissingFields | Should -Contain 'Summary'
    }

    It 'Test-DecomObjectAgainstSchemaContract detects wrong SchemaVersion in OutputManifest' {
        $manifest = [PSCustomObject]@{
            SchemaVersion   = '3.3' # Should be 3.4
            ToolVersion     = 'Rev3.4'
            RunId           = 'run-123'
            GeneratedUtc    = (Get-Date).ToUniversalTime().ToString('o')
            EngagementId    = 'eng-123'
            ClientName      = 'Client A'
            OutputRoot      = '.\out'
            Files           = @()
            Summary         = [ordered]@{
                TotalFiles        = 0
                TotalSizeBytes    = 0
                PublicFiles       = 0
                ClientSafeFiles   = 0
                ConfidentialFiles = 0
                RestrictedFiles   = 0
            }
        }
        $contract = Get-DecomSchemaContract -ObjectType 'OutputManifest'
        $result = Test-DecomObjectAgainstSchemaContract -Object $manifest -Contract $contract
        $result.Passed | Should -Be $false
        ($result.InvalidValues | Where-Object { $_ -like 'SchemaVersion:*' }).Count | Should -BeGreaterThan 0
    }
}