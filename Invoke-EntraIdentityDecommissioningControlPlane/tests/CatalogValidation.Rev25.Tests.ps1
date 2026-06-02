#Requires -Version 5.1

Describe 'CatalogValidation.psm1' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module CatalogValidation -Force -ErrorAction SilentlyContinue
        Remove-Module Utilities -Force -ErrorAction SilentlyContinue
        Import-ModULE (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'CatalogValidation.psm1') -Force -DisableNameChecking

        # Create temp catalog file for import/export tests
        $script:testCatalogPath = Join-Path $env:TEMP 'Decom-Test-Catalog.md'
        $catalogContent = @"
| FindingId | Category | Title | Description | Severity | RiskScore |
|-----------|----------|-------|-------------|----------|-----------|
| DEC-TEST-001 | DEC-TEST | Test Finding | Test description | High | 70 |
| DEC-TEST-002 | DEC-TEST | Test Finding 2 | Test description 2 | Medium | 50 |
"@
        $catalogContent | Out-File -FilePath $script:testCatalogPath -Encoding UTF8

        $script:testOutputDir = Join-Path $env:TEMP 'Decom-Test-Output'
        New-Item -ItemType Directory -Path $script:testOutputDir -Force | Out-Null

        $script:testFindings = @(
            [PSCustomObject]@{
                FindingId         = 'DEC-TEST-001'
                Category          = 'DEC-TEST'
                Title             = 'Test Finding'
                Severity          = 'High'
                RiskScore         = 70
                Confidence        = 0.9
                ObjectType        = 'User'
                ObjectId          = 'test-user-id'
                DisplayName       = 'Test User'
                UserPrincipalName = 'test@contoso.com'
                Evidence          = 'Test evidence'
                EvidenceSource    = 'Test source'
                GraphEndpoint     = 'https://graph.microsoft.com/v1.0/test'
                RecommendedAction = 'Test action'
                RemediationMode   = 'ManualApprovalRequired'
                ConsultantNote    = 'Test note'
            }
        )
    }

    AfterAll {
        if (Test-Path $script:testCatalogPath) { Remove-Item $script:testCatalogPath -Force }
        if (Test-Path $script:testOutputDir) { Remove-Item $script:testOutputDir -Recurse -Force }
        Remove-Module CatalogValidation -Force -ErrorAction SilentlyContinue
    }

    It 'Import-DecomFindingsCatalog should parse markdown catalog' {
        $result = Import-DecomFindingsCatalog -CatalogPath $script:testCatalogPath
        $result.Count | Should -Be 2
        $result[0].FindingId | Should -Be 'DEC-TEST-001'
        $result[0].RiskScore | Should -Be 70
        $result[1].FindingId | Should -Be 'DEC-TEST-002'
        $result[1].Severity  | Should -Be 'Medium'
    }

    It 'Get-DecomFindingCatalogMap should create lookup map' {
        $testCatalog = @(
            [PSCustomObject]@{ FindingId = 'DEC-USER-001'; Category = 'DEC-USER'; Severity = 'High'; RiskScore = 75 },
            [PSCustomObject]@{ FindingId = 'DEC-APP-002'; Category = 'DEC-APP'; Severity = 'Medium'; RiskScore = 50 }
        )
        $map = Get-DecomFindingCatalogMap -Catalog $testCatalog
        $map.Contains('DEC-USER-001') | Should -Be $true
        $map['DEC-USER-001'].FindingId | Should -Be 'DEC-USER-001'
    }

    It 'Test-DecomFindingCatalogAlignment should validate matching findings' {
        $findings = @(
            [PSCustomObject]@{
                FindingId='DEC-U-001'; Category='DEC-U'; Severity='High'; RiskScore=75; Confidence=0.95
                ObjectType='User'; ObjectId='u1'; DisplayName='User'; UserPrincipalName='u@c.com'
                Evidence='e'; EvidenceSource='s'; GraphEndpoint='/users'; RecommendedAction='act'
                RemediationMode='AutoRemediable'; ConsultantNote='note'
            }
        )
        $catalog = @(
            [PSCustomObject]@{ FindingId='DEC-U-001'; Severity='High'; RiskScore=75 }
        )
        $result = Test-DecomFindingCatalogAlignment -Findings $findings -Catalog $catalog
        $result.Passed | Should -Be $true
        $result.UnknownFindingIds.Count | Should -Be 0
    }

    It 'Test-DecomFindingCatalogAlignment should report unknown FindingId' {
        $findings = @(
            [PSCustomObject]@{
                FindingId='DEC-UNKNOWN-001'; Category='X'; Severity='Medium'; RiskScore=50; Confidence=0.9
                ObjectType='User'; ObjectId='u1'; DisplayName='User'; UserPrincipalName='u@c.com'
                Evidence='e'; EvidenceSource='s'; GraphEndpoint='/users'; RecommendedAction='act'
                RemediationMode='ManualApprovalRequired'; ConsultantNote='note'
            }
        )
        $catalog = @(
            [PSCustomObject]@{ FindingId='DEC-USER-001'; Severity='High'; RiskScore=75 }
        )
        $result = Test-DecomFindingCatalogAlignment -Findings $findings -Catalog $catalog
        $result.Passed | Should -Be $false
        $result.UnknownFindingIds | Should -Contain 'DEC-UNKNOWN-001'
    }

    It 'Test-DecomFindingCatalogAlignment should report severity mismatch' {
        $findings = @(
            [PSCustomObject]@{
                FindingId='DEC-USER-001'; Category='DEC-USER'; Severity='Medium'; RiskScore=75; Confidence=0.95
                ObjectType='User'; ObjectId='u1'; DisplayName='User'; UserPrincipalName='u@c.com'
                Evidence='e'; EvidenceSource='s'; GraphEndpoint='/users'; RecommendedAction='act'
                RemediationMode='AutoRemediable'; ConsultantNote='note'
            }
        )
        $catalog = @(
            [PSCustomObject]@{ FindingId='DEC-USER-001'; Severity='High'; RiskScore=75 }
        )
        $result = Test-DecomFindingCatalogAlignment -Findings $findings -Catalog $catalog
        $result.Passed | Should -Be $false
        $result.SeverityMismatches.Count | Should -Be 1
        $result.SeverityMismatches[0] | Should -Match 'DEC-USER-001'
    }

    It 'Test-DecomFindingCatalogAlignment should report RiskScore mismatch' {
        $findings = @(
            [PSCustomObject]@{
                FindingId='DEC-USER-001'; Category='DEC-USER'; Severity='High'; RiskScore=60; Confidence=0.95
                ObjectType='User'; ObjectId='u1'; DisplayName='User'; UserPrincipalName='u@c.com'
                Evidence='e'; EvidenceSource='s'; GraphEndpoint='/users'; RecommendedAction='act'
                RemediationMode='AutoRemediable'; ConsultantNote='note'
            }
        )
        $catalog = @(
            [PSCustomObject]@{ FindingId='DEC-USER-001'; Severity='High'; RiskScore=75 }
        )
        $result = Test-DecomFindingCatalogAlignment -Findings $findings -Catalog $catalog
        $result.Passed | Should -Be $false
        $result.RiskScoreMismatches.Count | Should -Be 1
        $result.RiskScoreMismatches[0] | Should -Match 'DEC-USER-001'
    }

    It 'Test-DecomFindingCatalogAlignment should report RiskScore band violation' {
        $findings = @(
            [PSCustomObject]@{
                FindingId='DEC-USER-001'; Category='DEC-USER'; Severity='High'; RiskScore=85; Confidence=0.95
                ObjectType='User'; ObjectId='u1'; DisplayName='User'; UserPrincipalName='u@c.com'
                Evidence='e'; EvidenceSource='s'; GraphEndpoint='/users'; RecommendedAction='act'
                RemediationMode='AutoRemediable'; ConsultantNote='note'
            }
        )
        $catalog = @(
            [PSCustomObject]@{ FindingId='DEC-USER-001'; Severity='High'; RiskScore=75 }
        )
        $result = Test-DecomFindingCatalogAlignment -Findings $findings -Catalog $catalog
        $result.Passed | Should -Be $false
        $result.RiskScoreBandViolations.Count | Should -Be 1
        $result.RiskScoreBandViolations[0] | Should -Match 'DEC-USER-001'
    }

    It 'Test-DecomFindingCatalogAlignment should report invalid RemediationMode' {
        $findings = @(
            [PSCustomObject]@{
                FindingId='DEC-USER-001'; Category='DEC-USER'; Severity='High'; RiskScore=75; Confidence=0.95
                ObjectType='User'; ObjectId='u1'; DisplayName='User'; UserPrincipalName='u@c.com'
                Evidence='e'; EvidenceSource='s'; GraphEndpoint='/users'; RecommendedAction='act'
                RemediationMode='InvalidMode'; ConsultantNote='note'
            }
        )
        $catalog = @(
            [PSCustomObject]@{ FindingId='DEC-USER-001'; Severity='High'; RiskScore=75 }
        )
        $result = Test-DecomFindingCatalogAlignment -Findings $findings -Catalog $catalog
        $result.Passed | Should -Be $false
        $result.InvalidRemediationModes.Count | Should -Be 1
        $result.InvalidRemediationModes[0] | Should -Match 'InvalidMode'
    }

    It 'should export validation results to JSON' {
        $catalog  = Import-DecomFindingsCatalog -CatalogPath $script:testCatalogPath
        $valResult = Test-DecomFindingCatalogAlignment -Findings $script:testFindings -Catalog $catalog
        $context = [PSCustomObject]@{
            ToolVersion  = 'Rev3.0'
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'test-eng'
            Assessor     = 'TestAssessor'
        }
        { Export-DecomCatalogValidationJson -Result $valResult -Context $context } | Should -Not -Throw
        $files = Get-ChildItem -Path $script:testOutputDir -Filter 'catalog-validation-report-*.json'
        $files.Count | Should -BeGreaterThan 0
        $json = Get-Content $files[0].FullName -Raw | ConvertFrom-Json
        $json.SchemaVersion | Should -Be '3.0'
        $json.ToolVersion   | Should -Be 'Rev3.0'
    }

    It 'should export validation results to Markdown' {
        $catalog  = Import-DecomFindingsCatalog -CatalogPath $script:testCatalogPath
        $valResult = Test-DecomFindingCatalogAlignment -Findings $script:testFindings -Catalog $catalog
        $context = [PSCustomObject]@{
            ToolVersion  = 'Rev3.0'
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'test-eng'
            Assessor     = 'TestAssessor'
        }
        { Export-DecomCatalogValidationMarkdown -Result $valResult -Context $context } | Should -Not -Throw
        $files = Get-ChildItem -Path $script:testOutputDir -Filter 'catalog-validation-report-*.md'
        $files.Count | Should -BeGreaterThan 0
        $md = Get-Content $files[0].FullName -Raw
        $md | Should -Match '# Catalog Validation Report'
        $md | Should -Match 'SchemaVersion.*3\.0'
    }
}
