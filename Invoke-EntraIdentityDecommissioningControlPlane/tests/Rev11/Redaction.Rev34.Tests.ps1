#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Redaction' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
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
            Export-DecomRedactionReportJson -Profile $p -Path $temp -RunId 'run-001' -ToolVersion 'Rev3.4' -RedactedFileCount 3
            $json = Get-Content $temp -Raw | ConvertFrom-Json
            $json.SchemaVersion     | Should -Be '3.4'
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
            Export-DecomRedactionReportJson -Profile $p -Path $temp -RunId 'r1' -ToolVersion 'Rev3.4'
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
            Export-DecomRedactionReportMarkdown -Profile $p -Path $temp -RunId 'run-md-001' -ToolVersion 'Rev3.4' -RedactedFileCount 2
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
}
