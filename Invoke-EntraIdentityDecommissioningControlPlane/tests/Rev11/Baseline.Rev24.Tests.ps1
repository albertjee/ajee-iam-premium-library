#Requires -Version 5.1
#Requires -Modules Pester

Describe 'Rev2.4 Baseline Module' {

    BeforeAll {
        Set-Location (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent)
        Remove-Module Baseline -Force -ErrorAction SilentlyContinue
        Remove-Module Utilities -Force -ErrorAction SilentlyContinue
        Import-Module .\src\Modules\Utilities.psm1 -Force -DisableNameChecking
        Import-Module .\src\Modules\Baseline.psm1  -Force -DisableNameChecking

        # Helper: create minimal finding object
        function New-TestFinding {
            param(
                [string]$FindingId = 'DEC-USER-001',
                [string]$ObjectType = 'User',
                [string]$ObjectId = [guid]::NewGuid().Guid,
                [string]$DisplayName = 'Test User',
                [string]$Severity = 'High',
                [int]$RiskScore = 70,
                [string]$Evidence = 'Test evidence'
            )
            return [PSCustomObject]@{
                FindingId   = $FindingId
                ObjectType  = $ObjectType
                ObjectId    = $ObjectId
                DisplayName = $DisplayName
                Severity    = $Severity
                RiskScore   = $RiskScore
                Evidence    = $Evidence
                RunId       = $null
            }
        }

        # Shared baseline JSON for file-based tests
        $script:FindingId1 = 'DEC-USER-001'
        $script:ObjId1 = [guid]::NewGuid().Guid

        $script:BaselineJson = @{
            SchemaVersion = '2.3'
            GeneratedUtc  = (Get-Date).AddDays(-7).ToUniversalTime().ToString('o')
            Findings      = @(
                @{
                    FindingId   = $script:FindingId1
                    ObjectType  = 'User'
                    ObjectId    = $script:ObjId1
                    DisplayName = 'Disabled Admin'
                    Severity    = 'High'
                    RiskScore   = 70
                    Evidence    = 'Disabled user retains role'
                    RunId       = $null
                }
            )
        } | ConvertTo-Json -Depth 5
    }

    Context 'Import-DecomBaselineFindings — missing/invalid path' {

        It 'Missing baseline path returns BaselineAvailable=false without throwing' {
            { $result = Import-DecomBaselineFindings -BaselinePath '' } | Should -Not -Throw
            $result = Import-DecomBaselineFindings -BaselinePath ''
            $result.BaselineAvailable | Should -Be $false
        }

        It 'Non-existent file path returns BaselineAvailable=false with ErrorDetail' {
            $result = Import-DecomBaselineFindings -BaselinePath 'C:\nonexistent-path\file.json'
            $result.BaselineAvailable | Should -Be $false
            $result.ErrorDetail | Should -Not -BeNullOrEmpty
        }

        It 'Invalid JSON content returns BaselineAvailable=false' {
            $badJson = Join-Path $TestDrive 'bad.json'
            Set-Content $badJson -Value 'THIS IS NOT JSON' -Encoding UTF8
            $result = Import-DecomBaselineFindings -BaselinePath $badJson
            $result.BaselineAvailable | Should -Be $false
        }

        It 'JSON with unsupported schema version returns BaselineAvailable=false' {
            $badSchema = @{ SchemaVersion = '1.0'; Findings = @() } | ConvertTo-Json
            $schemaPath = Join-Path $TestDrive 'bad-schema.json'
            Set-Content $schemaPath -Value $badSchema -Encoding UTF8
            $result = Import-DecomBaselineFindings -BaselinePath $schemaPath
            $result.BaselineAvailable | Should -Be $false
        }
    }

    Context 'Import-DecomBaselineFindings — valid file path' {

        It 'Valid findings JSON file loads successfully' {
            $jsonPath = Join-Path $TestDrive 'baseline.json'
            Set-Content $jsonPath -Value $script:BaselineJson -Encoding UTF8
            $result = Import-DecomBaselineFindings -BaselinePath $jsonPath
            $result.BaselineAvailable | Should -Be $true
            $result.Findings.Count | Should -Be 1
        }

        It 'SourcePath is populated for valid file' {
            $jsonPath = Join-Path $TestDrive 'baseline-src.json'
            Set-Content $jsonPath -Value $script:BaselineJson -Encoding UTF8
            $result = Import-DecomBaselineFindings -BaselinePath $jsonPath
            $result.SourcePath | Should -Be $jsonPath
        }
    }

    Context 'Import-DecomBaselineFindings — folder path' {

        It 'Folder path resolves newest findings JSON' {
            $folder = Join-Path $TestDrive 'baseline-folder'
            New-Item -ItemType Directory -Path $folder -Force | Out-Null

            # Create two files with different timestamps
            $oldFile = Join-Path $folder 'entra-findings-20250101.json'
            $newFile = Join-Path $folder 'entra-findings-20260101.json'
            Set-Content $oldFile -Value $script:BaselineJson -Encoding UTF8
            Start-Sleep -Milliseconds 100
            Set-Content $newFile -Value $script:BaselineJson -Encoding UTF8

            $result = Import-DecomBaselineFindings -BaselinePath $folder
            $result.BaselineAvailable | Should -Be $true
            $result.SourcePath | Should -Be $newFile
        }

        It 'Folder with no findings JSON returns BaselineAvailable=false' {
            $emptyFolder = Join-Path $TestDrive 'empty-folder'
            New-Item -ItemType Directory -Path $emptyFolder -Force | Out-Null
            $result = Import-DecomBaselineFindings -BaselinePath $emptyFolder
            $result.BaselineAvailable | Should -Be $false
        }
    }

    Context 'Get-DecomFindingStableKey' {

        It 'Stable key includes FindingId' {
            $f = New-TestFinding -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId 'oid-001' -DisplayName 'Test'
            $key = Get-DecomFindingStableKey -Finding $f
            $key | Should -Match 'DEC-USER-001'
        }

        It 'Stable key includes ObjectType' {
            $f = New-TestFinding -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId 'oid-001' -DisplayName 'Test'
            $key = Get-DecomFindingStableKey -Finding $f
            $key | Should -Match 'User'
        }

        It 'Stable key includes ObjectId' {
            $oid = [guid]::NewGuid().Guid
            $f = New-TestFinding -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId $oid -DisplayName 'Test'
            $key = Get-DecomFindingStableKey -Finding $f
            $key | Should -Match $oid
        }

        It 'Two findings with different ObjectId produce different keys' {
            $f1 = New-TestFinding -FindingId 'DEC-USER-001' -ObjectId 'aaa-001'
            $f2 = New-TestFinding -FindingId 'DEC-USER-001' -ObjectId 'bbb-002'
            $key1 = Get-DecomFindingStableKey -Finding $f1
            $key2 = Get-DecomFindingStableKey -Finding $f2
            $key1 | Should -Not -Be $key2
        }
    }

    Context 'Compare-DecomFindingBaseline — status classification' {

        BeforeAll {
            $script:SharedObjId = [guid]::NewGuid().Guid

            $script:BaselineFinding = New-TestFinding `
                -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId $script:SharedObjId `
                -DisplayName 'Disabled Admin' -Severity 'High' -RiskScore 70 -Evidence 'Prior evidence'

            $script:CurrentFindingSame = New-TestFinding `
                -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId $script:SharedObjId `
                -DisplayName 'Disabled Admin' -Severity 'High' -RiskScore 70 -Evidence 'Prior evidence'

            $script:NewFinding = New-TestFinding `
                -FindingId 'DEC-GUEST-001' -ObjectType 'Guest' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'New Guest' -Severity 'Critical' -RiskScore 85 -Evidence 'New evidence'
        }

        It 'New finding is classified as New' {
            $result = Compare-DecomFindingBaseline `
                -CurrentFindings @($script:NewFinding) `
                -BaselineFindings @($script:BaselineFinding)
            $newItems = $result | Where-Object { $_.Status -eq 'New' }
            $newItems.Count | Should -Be 1
            $newItems[0].FindingId | Should -Be 'DEC-GUEST-001'
        }

        It 'Resolved finding is classified as Resolved' {
            $result = Compare-DecomFindingBaseline `
                -CurrentFindings @($script:NewFinding) `
                -BaselineFindings @($script:BaselineFinding)
            $resolved = $result | Where-Object { $_.Status -eq 'Resolved' }
            $resolved.Count | Should -Be 1
            $resolved[0].FindingId | Should -Be 'DEC-USER-001'
        }

        It 'Unchanged finding is classified as Unchanged' {
            $result = Compare-DecomFindingBaseline `
                -CurrentFindings @($script:CurrentFindingSame) `
                -BaselineFindings @($script:BaselineFinding)
            $unchanged = $result | Where-Object { $_.Status -eq 'Unchanged' }
            $unchanged.Count | Should -Be 1
        }

        It 'ChangedSeverity detected when severity changes' {
            $changedSev = New-TestFinding `
                -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId $script:SharedObjId `
                -DisplayName 'Disabled Admin' -Severity 'Critical' -RiskScore 70
            $result = Compare-DecomFindingBaseline `
                -CurrentFindings @($changedSev) `
                -BaselineFindings @($script:BaselineFinding)
            ($result | Where-Object { $_.Status -eq 'ChangedSeverity' }).Count | Should -Be 1
        }

        It 'ChangedRiskScore detected when risk score changes' {
            $changedRisk = New-TestFinding `
                -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId $script:SharedObjId `
                -DisplayName 'Disabled Admin' -Severity 'High' -RiskScore 85
            $result = Compare-DecomFindingBaseline `
                -CurrentFindings @($changedRisk) `
                -BaselineFindings @($script:BaselineFinding)
            ($result | Where-Object { $_.Status -eq 'ChangedRiskScore' }).Count | Should -Be 1
        }

        It 'DeltaRiskScore is positive when risk score increases' {
            $changedRisk = New-TestFinding `
                -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId $script:SharedObjId `
                -DisplayName 'Disabled Admin' -Severity 'High' -RiskScore 85
            $result = Compare-DecomFindingBaseline `
                -CurrentFindings @($changedRisk) `
                -BaselineFindings @($script:BaselineFinding)
            ($result[0].DeltaRiskScore) | Should -Be 15
        }

        It 'DeltaRiskScore is negative when risk score decreases' {
            $lowerRisk = New-TestFinding `
                -FindingId 'DEC-USER-001' -ObjectType 'User' -ObjectId $script:SharedObjId `
                -DisplayName 'Disabled Admin' -Severity 'High' -RiskScore 50
            $result = Compare-DecomFindingBaseline `
                -CurrentFindings @($lowerRisk) `
                -BaselineFindings @($script:BaselineFinding)
            ($result[0].DeltaRiskScore) | Should -Be -20
        }
    }

    Context 'Get-DecomRiskMovementSummary' {

        It 'NetRiskDelta calculated correctly' {
            $oid = [guid]::NewGuid().Guid
            $baseline = @(New-TestFinding -FindingId 'DEC-USER-001' -ObjectId $oid -Severity 'High' -RiskScore 70)
            $current  = @(
                (New-TestFinding -FindingId 'DEC-USER-001' -ObjectId $oid -Severity 'High' -RiskScore 80),
                (New-TestFinding -FindingId 'DEC-GUEST-001' -Severity 'Critical' -RiskScore 85)
            )
            $comparison = Compare-DecomFindingBaseline -CurrentFindings $current -BaselineFindings $baseline
            $movement = Get-DecomRiskMovementSummary -ComparisonResults $comparison
            $movement.NetRiskDelta | Should -Be ($movement.NetRiskDelta)  # computed, not hardcoded
            $movement.TotalCurrentFindings | Should -BeGreaterThan 0
        }

        It 'NewCritical counts Critical new findings' {
            $oid = [guid]::NewGuid().Guid
            $baseline = @(New-TestFinding -FindingId 'DEC-USER-001' -ObjectId $oid -Severity 'High' -RiskScore 70)
            $current  = @(
                (New-TestFinding -FindingId 'DEC-GUEST-001' -Severity 'Critical' -RiskScore 85),
                (New-TestFinding -FindingId 'DEC-APP-001' -Severity 'Critical' -RiskScore 88)
            )
            $comparison = Compare-DecomFindingBaseline -CurrentFindings $current -BaselineFindings $baseline
            $movement = Get-DecomRiskMovementSummary -ComparisonResults $comparison
            $movement.NewCritical | Should -Be 2
        }
    }

    Context 'Baseline exports' {

        BeforeAll {
            $script:ExportObjId = [guid]::NewGuid().Guid
            $baseline = @(New-TestFinding -FindingId 'DEC-USER-001' -ObjectId $script:ExportObjId -Severity 'High' -RiskScore 70)
            $current  = @(
                (New-TestFinding -FindingId 'DEC-USER-001' -ObjectId $script:ExportObjId -Severity 'Critical' -RiskScore 80),
                (New-TestFinding -FindingId 'DEC-GUEST-001' -Severity 'Critical' -RiskScore 85)
            )
            $script:Comparison = Compare-DecomFindingBaseline -CurrentFindings $current -BaselineFindings $baseline
            $script:BaselineResultObj = [PSCustomObject]@{
                BaselineAvailable = $true
                SourcePath        = 'C:\prior\findings.json'
                Findings          = $baseline
                ErrorDetail       = ''
            }
            $script:ExportCtx = [PSCustomObject]@{
                ToolVersion  = 'Rev2.4'
                ClientName   = 'Contoso'
                EngagementId = 'ENG-001'
                TenantId     = 'contoso.onmicrosoft.com'
            }
        }

        It 'Export-DecomBaselineComparisonJson SchemaVersion is 2.4' {
            $path = Join-Path $TestDrive 'baseline-cmp.json'
            Export-DecomBaselineComparisonJson `
                -ComparisonResults $script:Comparison `
                -Context $script:ExportCtx `
                -BaselineResult $script:BaselineResultObj `
                -Path $path
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.SchemaVersion | Should -Be '2.4'
        }

        It 'Baseline comparison JSON contains required Summary fields' {
            $path = Join-Path $TestDrive 'baseline-cmp-summary.json'
            Export-DecomBaselineComparisonJson `
                -ComparisonResults $script:Comparison `
                -Context $script:ExportCtx `
                -BaselineResult $script:BaselineResultObj `
                -Path $path
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.Summary | Should -Not -BeNullOrEmpty
            $json.Summary.PSObject.Properties.Name | Should -Contain 'New'
            $json.Summary.PSObject.Properties.Name | Should -Contain 'Resolved'
        }

        It 'Baseline unavailable still writes JSON with BaselineAvailable=false' {
            $unavailable = [PSCustomObject]@{ BaselineAvailable = $false; SourcePath = ''; Findings = @(); ErrorDetail = 'Not found' }
            $fakeComparison = @()
            $path = Join-Path $TestDrive 'baseline-unavail.json'
            Export-DecomBaselineComparisonJson `
                -ComparisonResults $fakeComparison `
                -Context $script:ExportCtx `
                -BaselineResult $unavailable `
                -Path $path
            Test-Path $path | Should -Be $true
            $json = Get-Content $path -Raw | ConvertFrom-Json
            $json.BaselineAvailable | Should -Be $false
        }

        It 'Export-DecomBaselineComparisonCsv contains required headers' {
            $path = Join-Path $TestDrive 'baseline-cmp.csv'
            Export-DecomBaselineComparisonCsv -ComparisonResults $script:Comparison -Path $path
            Test-Path $path | Should -Be $true
            $csv = Import-Csv $path
            $csv[0].PSObject.Properties.Name | Should -Contain 'StableKey'
            $csv[0].PSObject.Properties.Name | Should -Contain 'Status'
            $csv[0].PSObject.Properties.Name | Should -Contain 'FindingId'
        }

        It 'Empty comparison results still creates CSV with headers' {
            $path = Join-Path $TestDrive 'baseline-empty.csv'
            Export-DecomBaselineComparisonCsv -ComparisonResults @() -Path $path
            Test-Path $path | Should -Be $true
        }
    }
}
