#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Redaction' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module Redaction -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Redaction.psm1') -Force -DisableNameChecking
    }

    # ── New-DecomRedactionProfile ────────────────────────────────────────────

    It 'New-DecomRedactionProfile returns an object' {
        $p = New-DecomRedactionProfile -ProfileName ClientSafe
        $p | Should -Not -BeNullOrEmpty
    }

    It 'New-DecomRedactionProfile sets ProfileName' {
        $p = New-DecomRedactionProfile -ProfileName PublicDemo
        $p.ProfileName | Should -Be 'PublicDemo'
    }

    It 'New-DecomRedactionProfile ClientSafe has correct defaults' {
        $p = New-DecomRedactionProfile -ProfileName ClientSafe
        $p.RedactTenantId     | Should -Be $true
        $p.RedactObjectIds    | Should -Be $true
        $p.RedactUpns         | Should -Be $true
        $p.RedactEmails       | Should -Be $true
        $p.RedactDisplayNames | Should -Be $false
        $p.RedactRunId        | Should -Be $false
        $p.RedactHashes       | Should -Be $false
    }

    It 'New-DecomRedactionProfile Strict enables all redactions' {
        $p = New-DecomRedactionProfile -ProfileName Strict
        $p.RedactDisplayNames | Should -Be $true
        $p.RedactRunId        | Should -Be $true
        $p.RedactHashes       | Should -Be $true
    }

    It 'New-DecomRedactionProfile Internal has minimal redactions' {
        $p = New-DecomRedactionProfile -ProfileName Internal
        $p.RedactDisplayNames | Should -Be $false
        $p.RedactRunId        | Should -Be $false
        $p.RedactHashes       | Should -Be $false
    }

    It 'New-DecomRedactionProfile initialises TokenMap as empty hashtable' {
        $p = New-DecomRedactionProfile -ProfileName ClientSafe
        $p.TokenMap           | Should -Not -Be $null -Because 'TokenMap must be a hashtable, not null'
        $p.TokenMap.Count     | Should -Be 0
    }

    # ── Invoke-DecomRedaction ────────────────────────────────────────────────

    It 'TenantId redacted — first GUID becomes [REDACTED_TENANT_ID]' {
        $p      = New-DecomRedactionProfile -ProfileName ClientSafe
        $tenant = 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
        $input  = "TenantId: $tenant"
        $result = Invoke-DecomRedaction -InputString $input -Profile $p
        $result | Should -Match '\[REDACTED_TENANT_ID\]'
        $result | Should -Not -Match $tenant
    }

    It 'ObjectId redacted deterministically — same GUID maps to same token across two calls' {
        $p     = New-DecomRedactionProfile -ProfileName ClientSafe
        $guid  = '11111111-2222-3333-4444-555555555555'

        # First call uses the TenantId slot, so provide a distinct leading GUID first
        # then our target GUID as the second one, which should become OBJECT_ID_1.
        $tenant    = 'aaaaaaaa-0000-0000-0000-000000000001'
        $inputA    = "Tenant: $tenant ObjectId: $guid"
        $resultA   = Invoke-DecomRedaction -InputString $inputA -Profile $p

        # Second call with same profile — same GUID must produce same token
        $inputB    = "Again: $guid"
        $resultB   = Invoke-DecomRedaction -InputString $inputB -Profile $p

        # Extract token from resultA
        $tokenA = [System.Text.RegularExpressions.Regex]::Match($resultA, '\[REDACTED_OBJECT_ID_\d+\]').Value
        $tokenA | Should -Not -BeNullOrEmpty

        # resultB should contain the exact same token
        $resultB | Should -Match ([System.Text.RegularExpressions.Regex]::Escape($tokenA))
    }

    It 'UPN redacted — email-format string becomes [REDACTED_UPN_1]' {
        $p      = New-DecomRedactionProfile -ProfileName ClientSafe
        $input  = 'User: john.doe@contoso.com'
        $result = Invoke-DecomRedaction -InputString $input -Profile $p
        $result | Should -Match '\[REDACTED_UPN_1\]'
        $result | Should -Not -Match 'john\.doe@contoso\.com'
    }

    It 'Email redacted — address becomes [REDACTED_UPN_n] or [REDACTED_EMAIL_n]' {
        $p      = New-DecomRedactionProfile -ProfileName ClientSafe
        $input  = 'Contact: admin@fabrikam.org'
        $result = Invoke-DecomRedaction -InputString $input -Profile $p
        $result | Should -Not -Match 'admin@fabrikam\.org'
    }

    It 'Same source value maps to same redacted token on repeated calls' {
        $p     = New-DecomRedactionProfile -ProfileName ClientSafe
        $input = 'User: repeat@example.com'
        $r1    = Invoke-DecomRedaction -InputString $input -Profile $p
        $r2    = Invoke-DecomRedaction -InputString $input -Profile $p
        $r1 | Should -Be $r2
    }

    It 'Empty string returns empty string' {
        $p      = New-DecomRedactionProfile -ProfileName ClientSafe
        $result = Invoke-DecomRedaction -InputString '' -Profile $p
        $result | Should -Be ''
    }

    It 'String with no identifiers is returned unchanged' {
        $p      = New-DecomRedactionProfile -ProfileName ClientSafe
        $input  = 'No sensitive data here. Severity: High. RiskScore: 90.'
        $result = Invoke-DecomRedaction -InputString $input -Profile $p
        $result | Should -Be $input
    }

    It 'Severity and risk fields are not redacted' {
        $p      = New-DecomRedactionProfile -ProfileName Strict
        $input  = 'Severity: Critical RiskScore: 95 Confidence: High'
        $result = Invoke-DecomRedaction -InputString $input -Profile $p
        $result | Should -Be $input
    }

    It 'JSON remains valid after redaction' {
        $p = New-DecomRedactionProfile -ProfileName ClientSafe
        $jsonInput = @'
{
  "TenantId": "aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb",
  "UserPrincipalName": "alice@contoso.com",
  "Severity": "High",
  "RiskScore": 80
}
'@
        $redacted = Invoke-DecomRedaction -InputString $jsonInput -Profile $p
        # Must be parseable JSON — this will throw if invalid
        { $redacted | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'CSV headers preserved after redaction — first line unchanged' {
        $p = New-DecomRedactionProfile -ProfileName ClientSafe
        $csvInput = @"
FindingId,Category,Severity,UserPrincipalName,ObjectId
F001,Identity,High,alice@contoso.com,aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb
"@
        $redacted = Invoke-DecomRedaction -InputString $csvInput -Profile $p
        $lines    = $redacted -split "`n"
        # Header line must be identical
        $lines[0].Trim() | Should -Be 'FindingId,Category,Severity,UserPrincipalName,ObjectId'
    }

    It 'Markdown tables preserved after redaction — pipe structure intact' {
        $p = New-DecomRedactionProfile -ProfileName ClientSafe
        $mdInput = @"
| ObjectId | User | Severity |
|---|---|---|
| aaaaaaaa-1111-2222-3333-bbbbbbbbbbbb | alice@contoso.com | High |
"@
        $redacted = Invoke-DecomRedaction -InputString $mdInput -Profile $p
        $lines    = $redacted -split "`n"
        foreach ($line in $lines) {
            $trimmed = $line.Trim()
            if ($trimmed.Length -gt 0) {
                $trimmed | Should -Match '^\|'
                $trimmed | Should -Match '\|$'
            }
        }
    }

    It 'HTML basic structure preserved after redaction — tags remain intact' {
        $p = New-DecomRedactionProfile -ProfileName ClientSafe
        $htmlInput = '<html><body><p>User: alice@contoso.com</p></body></html>'
        $redacted  = Invoke-DecomRedaction -InputString $htmlInput -Profile $p
        $redacted  | Should -Match '<html>'
        $redacted  | Should -Match '</html>'
        $redacted  | Should -Match '<body>'
        $redacted  | Should -Match '</body>'
        $redacted  | Should -Match '<p>'
        $redacted  | Should -Match '</p>'
        $redacted  | Should -Not -Match 'alice@contoso\.com'
    }

    It 'Hashes preserved in ClientSafe profile' {
        $p    = New-DecomRedactionProfile -ProfileName ClientSafe
        $hash = 'a' * 64
        $input = "Hash: $hash"
        $result = Invoke-DecomRedaction -InputString $input -Profile $p
        $result | Should -Match $hash
    }

    It 'Hashes redacted in Strict profile' {
        $p    = New-DecomRedactionProfile -ProfileName Strict
        $hash = 'b' * 64
        $input = "Hash: $hash"
        $result = Invoke-DecomRedaction -InputString $input -Profile $p
        $result | Should -Not -Match $hash
        $result | Should -Match '\[REDACTED_HASH\]'
    }

    It 'Multiple distinct UPNs get distinct tokens' {
        $p  = New-DecomRedactionProfile -ProfileName ClientSafe
        $in = 'alice@contoso.com bob@fabrikam.com'
        $r  = Invoke-DecomRedaction -InputString $in -Profile $p
        $r  | Should -Match '\[REDACTED_UPN_1\]'
        $r  | Should -Match '\[REDACTED_UPN_2\]'
    }

    # ── Export-DecomRedactionReportJson ──────────────────────────────────────

    It 'Export-DecomRedactionReportJson writes a valid JSON file' {
        $p    = New-DecomRedactionProfile -ProfileName ClientSafe
        $temp = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomRedactionReportJson -Profile $p -Path $temp -RunId 'run-001' -ToolVersion 'Rev4.1' -RedactedFileCount 3
            $json = Get-Content $temp -Raw | ConvertFrom-Json
            $json.SchemaVersion     | Should -Be '3.6'
            $json.ProfileName       | Should -Be 'ClientSafe'
            $json.RunId             | Should -Be 'run-001'
            $json.RedactedFileCount | Should -Be 3
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Export-DecomRedactionReportJson includes TokenCount' {
        $p = New-DecomRedactionProfile -ProfileName ClientSafe
        # Populate some tokens
        $null = Invoke-DecomRedaction -InputString 'alice@contoso.com' -Profile $p
        $temp = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomRedactionReportJson -Profile $p -Path $temp -RunId 'r1' -ToolVersion 'Rev4.1'
            $json = Get-Content $temp -Raw | ConvertFrom-Json
            $json.TokenCount | Should -Be 1
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Export-DecomRedactionReportMarkdown ──────────────────────────────────

    It 'Export-DecomRedactionReportMarkdown writes a Markdown file' {
        $p    = New-DecomRedactionProfile -ProfileName PublicDemo
        $temp = [System.IO.Path]::GetTempFileName()
        try {
            Export-DecomRedactionReportMarkdown -Profile $p -Path $temp -RunId 'run-md-001' -ToolVersion 'Rev4.1' -RedactedFileCount 2
            $content = Get-Content $temp -Raw
            $content | Should -Match '# Redaction Report'
            $content | Should -Match 'SchemaVersion'
            $content | Should -Match 'PublicDemo'
            $content | Should -Match 'run-md-001'
        } finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Test-DecomRedactedOutput ─────────────────────────────────────────────

    It 'Test-DecomRedactedOutput passes on clean string' {
        $p      = New-DecomRedactionProfile -ProfileName ClientSafe
        $result = Test-DecomRedactedOutput -RedactedString 'All clean. Severity: High.' -Profile $p
        $result.Passed | Should -Be $true
        $result.Violations.Count | Should -Be 0
    }

    It 'Test-DecomRedactedOutput passes on empty string' {
        $p      = New-DecomRedactionProfile -ProfileName ClientSafe
        $result = Test-DecomRedactedOutput -RedactedString '' -Profile $p
        $result.Passed | Should -Be $true
    }

    It 'Test-DecomRedactedOutput returns Passed and Violations properties' {
        $p      = New-DecomRedactionProfile -ProfileName ClientSafe
        $result = Test-DecomRedactedOutput -RedactedString 'Safe text' -Profile $p
        $result.PSObject.Properties.Name | Should -Contain 'Passed'
        $result.PSObject.Properties.Name | Should -Contain 'Violations'
    }

    It 'Test-DecomRedactedOutput detects residual mapped GUID as violation' {
        $p    = New-DecomRedactionProfile -ProfileName ClientSafe
        $guid = 'cccccccc-dddd-eeee-ffff-000000000001'
        # Register the GUID in the token map by redacting it first
        $null = Invoke-DecomRedaction -InputString "id: $guid" -Profile $p
        # Now test a string that still contains the original GUID
        $result = Test-DecomRedactedOutput -RedactedString "residual: $guid" -Profile $p
        $result.Passed | Should -Be $false
    }

    # ── GenerateRedactedPackage Integration Tests ──────────────────────────────────────
    # These tests validate the redaction file generation functionality in the entry point
    # Note: These tests require mocking parts of the entry point and are simplified for unit testing

    It 'GenerateRedactedPackage creates redacted files in redacted\ subfolder' {
        $testDir = [System.IO.Path]::GetTempPath()
        $runFolder = Join-Path $testDir "TestRun_$(Get-Random)"
        New-Item -ItemType Directory -Path $runFolder | Out-Null
        try {
            # Create test files
            $testJson = Join-Path $runFolder "test.json"
            $testCsv  = Join-Path $runFolder "test.csv"
            $testMd   = Join-Path $runFolder "test.md"
            $testHtml = Join-Path $runFolder "test.html"

            '{"TenantId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","User":"admin@contoso.com"}' | Set-Content $testJson
            'Id,Email,Name\n1,admin@contoso.com,Admin' | Set-Content $testCsv
            '# Test\nEmail: admin@contoso.com' | Set-Content $testMd
            '<p>Contact: admin@contoso.com</p>' | Set-Content $testHtml

            # Mock the redaction logic from entry point
            Import-Module (Join-Path $script:ModulesPath 'Redaction.psm1') -Force -DisableNameChecking -ErrorAction Stop
            $redactionProfileObj = New-DecomRedactionProfile -ProfileName ClientSafe
            $redactedDir = Join-Path $runFolder 'redacted'
            New-Item -ItemType Directory -Path $redactedDir -Force | Out-Null
            $redactedCount = 0

            Get-ChildItem -Path $runFolder -Recurse -File -Include '*.json','*.csv','*.md','*.html' |
                ForEach-Object {
                    try {
                        $raw = Get-Content $_.FullName -Raw -ErrorAction Stop
                        $redacted = Invoke-DecomRedaction -InputString $raw -Profile $redactionProfileObj
                        $target = Join-Path $redactedDir $_.Name
                        Set-Content -Path $target -Value $redacted -Encoding UTF8
                        $redactedCount++
                    } catch { }
                }

            # Assertions
            Test-Path (Join-Path $redactedDir 'test.json') | Should -Be $true
            Test-Path (Join-Path $redactedDir 'test.csv')  | Should -Be $true
            Test-Path (Join-Path $redactedDir 'test.md')   | Should -Be $true
            Test-Path (Join-Path $redactedDir 'test.html') | Should -Be $true
            $redactedCount | Should -Be 4

            # Verify redaction worked
            (Get-Content (Join-Path $redactedDir 'test.json') -Raw) | Should -Not -Match 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
            (Get-Content (Join-Path $redactedDir 'test.json') -Raw) | Should -Match '\[REDACTED_TENANT_ID\]'
            (Get-Content (Join-Path $redactedDir 'test.csv') -Raw) | Should -Not -Match 'admin@contoso.com'
            (Get-Content (Join-Path $redactedDir 'test.csv') -Raw) | Should -Match '\[REDACTED_UPN_1\]'
        } finally {
            Remove-Item $runFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Redacted output contains no raw TenantId' {
        $testDir = [System.IO.Path]::GetTempPath()
        $runFolder = Join-Path $testDir "TestRunTenant_$(Get-Random)"
        New-Item -ItemType Directory -Path $runFolder | Out-Null
        try {
            $tenantId = '11111111-2222-3333-4444-555555555555'
            $testFile = Join-Path $runFolder "settings.json"
            ('{"TenantId":"' + $tenantId + '","Name":"Test"}') | Set-Content $testFile

            Import-Module (Join-Path $script:ModulesPath 'Redaction.psm1') -Force -DisableNameChecking -ErrorAction Stop
            $redactionProfileObj = New-DecomRedactionProfile -ProfileName ClientSafe
            $redactedDir = Join-Path $runFolder 'redacted'
            New-Item -ItemType Directory -Path $redactedDir -Force | Out-Null

            Get-ChildItem -Path $runFolder -Filter '*.json' -File |
                ForEach-Object {
                    $raw = Get-Content $_.FullName -Raw
                    $redacted = Invoke-DecomRedaction -InputString $raw -Profile $redactionProfileObj
                    $target = Join-Path $redactedDir $_.Name
                    Set-Content -Path $target -Value $redacted -Encoding UTF8
                }

            $redactedContent = Get-Content (Join-Path $redactedDir 'settings.json') -Raw
            $redactedContent | Should -Not -Match $tenantId
            $redactedContent | Should -Match '\[REDACTED_TENANT_ID\]'
        } finally {
            Remove-Item $runFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'RedactedFileCount > 0 when files were redacted' {
        $testDir = [System.IO.Path]::GetTempPath()
        $runFolder = Join-Path $testDir "TestRunCount_$(Get-Random)"
        New-Item -ItemType Directory -Path $runFolder | Out-Null
        try {
            $testFile = Join-Path $runFolder "data.json"
            '{"TenantId":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"}' | Set-Content $testFile

            Import-Module (Join-Path $script:ModulesPath 'Redaction.psm1') -Force -DisableNameChecking -ErrorAction Stop
            $redactionProfileObj = New-DecomRedactionProfile -ProfileName ClientSafe
            $redactedDir = Join-Path $runFolder 'redacted'
            New-Item -ItemType Directory -Path $redactedDir -Force | Out-Null
            $redactedCount = 0

            Get-ChildItem -Path $runFolder -Filter '*.json' -File |
                ForEach-Object {
                    $raw = Get-Content $_.FullName -Raw
                    $redacted = Invoke-DecomRedaction -InputString $raw -Profile $redactionProfileObj
                    $target = Join-Path $redactedDir $_.Name
                    Set-Content -Path $target -Value $redacted -Encoding UTF8
                    $redactedCount++
                }

            $redactedCount | Should -BeGreaterThan 0
            $redactedCount | Should -Be 1
        } finally {
            Remove-Item $runFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'JSON remains parseable after redaction' {
        $testDir = [System.IO.Path]::GetTempPath()
        $runFolder = Join-Path $testDir "TestRunJson_$(Get-Random)"
        New-Item -ItemType Directory -Path $runFolder | Out-Null
        try {
            $testFile = Join-Path $runFolder "complex.json"
            $json = @'
{
  "TenantId": "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
  "Users": [
    {"id": "11111111-1111-1111-1111-111111111111", "email": "user1@contoso.com"},
    {"id": "22222222-2222-2222-2222-222222222222", "email": "user2@fabrikam.com"}
  ],
  "Settings": {
    "AppId": "33333333-3333-3333-3333-333333333333",
    "Secret": "not-a-guid-but-should-stay"
  }
}
'@
            $json | Set-Content $testFile

            Import-Module (Join-Path $script:ModulesPath 'Redaction.psm1') -Force -DisableNameChecking -ErrorAction Stop
            $redactionProfileObj = New-DecomRedactionProfile -ProfileName ClientSafe
            $redactedDir = Join-Path $runFolder 'redacted'
            New-Item -ItemType Directory -Path $redactedDir -Force | Out-Null

            Get-ChildItem -Path $runFolder -Filter '*.json' -File |
                ForEach-Object {
                    $raw = Get-Content $_.FullName -Raw
                    $redacted = Invoke-DecomRedaction -InputString $raw -Profile $redactionProfileObj
                    $target = Join-Path $redactedDir $_.Name
                    Set-Content -Path $target -Value $redacted -Encoding UTF8
                }

            $redactedPath = Join-Path $redactedDir 'complex.json'
            $redactedContent = Get-Content $redactedPath -Raw

            # Should be parseable JSON
            { $redactedContent | ConvertFrom-Json } | Should -Not -Throw

            # Verify redactions occurred
            $redactedContent | Should -Not -Match 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'
            $redactedContent | Should -Not -Match '11111111-1111-1111-1111-111111111111'
            $redactedContent | Should -Not -Match '22222222-2222-2222-2222-222222222222'
            $redactedContent | Should -Not -Match '33333333-3333-3333-3333-333333333333'
            $redactedContent | Should -Not -Match 'user1@contoso.com'
            $redactedContent | Should -Not -Match 'user2@fabrikam.com'

            # Verify non-GUID/email values remain
            $redactedContent | Should -Match 'not-a-guid-but-should-stay'
        } finally {
            Remove-Item $runFolder -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
