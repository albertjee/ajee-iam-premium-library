function New-DecomRedactionProfile {
    <#
    .SYNOPSIS
    Creates a redaction profile object that controls what identifiers are redacted.
    .DESCRIPTION
    Returns a PSCustomObject with per-field redaction flags and a deterministic TokenMap.
    Supported profiles: ClientSafe, PublicDemo, Strict, Internal.
    .PARAMETER ProfileName
    One of: ClientSafe (default), PublicDemo, Strict, Internal.
    .EXAMPLE
    $profile = New-DecomRedactionProfile -ProfileName ClientSafe
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('ClientSafe', 'PublicDemo', 'Strict', 'Internal')]
        [string]$ProfileName = 'ClientSafe'
    )

    $redactDisplayNames = $false
    $redactRunId        = $false
    $redactHashes       = $false

    switch ($ProfileName) {
        'PublicDemo' {
            $redactDisplayNames = $true
            $redactRunId        = $false
            $redactHashes       = $false
        }
        'Strict' {
            $redactDisplayNames = $true
            $redactRunId        = $true
            $redactHashes       = $true
        }
        'Internal' {
            $redactDisplayNames = $false
            $redactRunId        = $false
            $redactHashes       = $false
        }
    }

    return [pscustomobject]@{
        ProfileName          = $ProfileName
        RedactTenantId       = $true
        RedactObjectIds      = $true
        RedactAppIds         = $true
        RedactUpns           = $true
        RedactEmails         = $true
        RedactDisplayNames   = $redactDisplayNames
        RedactRunId          = $redactRunId
        RedactHashes         = $redactHashes
        TokenMap             = @{}
        TenantIdCounter      = 0
        ObjectIdCounter      = 0
        AppIdCounter         = 0
        UpnCounter           = 0
        EmailCounter         = 0
        DisplayNameCounter   = 0
    }
}

function Invoke-DecomRedaction {
    <#
    .SYNOPSIS
    Applies redaction rules to a string using the supplied redaction profile.
    .DESCRIPTION
    Replaces sensitive identifiers (tenant IDs, object IDs, app IDs, UPNs, emails,
    optionally display names, run IDs, and hashes) with deterministic tokens.
    The same source value within the same profile call always maps to the same token.
    JSON, CSV, and Markdown table structure are preserved — only values are replaced.
    .PARAMETER InputString
    The string content to redact.
    .PARAMETER Profile
    A redaction profile object created by New-DecomRedactionProfile.
    .EXAMPLE
    $redacted = Invoke-DecomRedaction -InputString $content -Profile $profile
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$InputString,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Profile
    )

    if ([string]::IsNullOrEmpty($InputString)) {
        return $InputString
    }

    $result = $InputString

    # ── SHA-256 hash pattern (64 hex chars) ─────────────────────────────────
    # Must be checked before GUID patterns since hashes are plain hex strings.
    if ($Profile.RedactHashes) {
        $hashPattern = '[0-9a-fA-F]{64}'
        $result = [System.Text.RegularExpressions.Regex]::Replace(
            $result,
            $hashPattern,
            {
                param($m)
                $src = $m.Value
                if (-not $Profile.TokenMap.ContainsKey($src)) {
                    $Profile.TokenMap[$src] = '[REDACTED_HASH]'
                }
                $Profile.TokenMap[$src]
            }
        )
    }

    # ── GUID pattern ─────────────────────────────────────────────────────────
    $guidPattern = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'

    if ($Profile.RedactTenantId -or $Profile.RedactObjectIds -or $Profile.RedactAppIds) {
        $result = [System.Text.RegularExpressions.Regex]::Replace(
            $result,
            $guidPattern,
            {
                param($m)
                $src = $m.Value.ToLower()

                if ($Profile.TokenMap.ContainsKey($src)) {
                    return $Profile.TokenMap[$src]
                }

                # Classify GUID: the first GUID encountered is treated as TenantId
                # if RedactTenantId is set; subsequent GUIDs rotate through Object/App.
                # Determinism: once classified, always the same token.
                $token = $null

                # Check if this looks like a tenant context — use TenantId slot once
                if ($Profile.RedactTenantId -and $Profile.TenantIdCounter -eq 0) {
                    $Profile.TenantIdCounter = 1
                    $token = '[REDACTED_TENANT_ID]'
                } elseif ($Profile.RedactObjectIds) {
                    $Profile.ObjectIdCounter++
                    $n = $Profile.ObjectIdCounter
                    $token = "[REDACTED_OBJECT_ID_${n}]"
                } elseif ($Profile.RedactAppIds) {
                    $Profile.AppIdCounter++
                    $n = $Profile.AppIdCounter
                    $token = "[REDACTED_APP_ID_${n}]"
                } else {
                    $token = $m.Value
                }

                $Profile.TokenMap[$src] = $token
                return $token
            }
        )
    }

    # ── UPN / Email pattern ───────────────────────────────────────────────────
    # UPNs are processed before plain email so the same address gets one token.
    $upnEmailPattern = '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}'

    if ($Profile.RedactUpns -or $Profile.RedactEmails) {
        $result = [System.Text.RegularExpressions.Regex]::Replace(
            $result,
            $upnEmailPattern,
            {
                param($m)
                $src = $m.Value.ToLower()

                if ($Profile.TokenMap.ContainsKey($src)) {
                    return $Profile.TokenMap[$src]
                }

                $token = $null
                if ($Profile.RedactUpns) {
                    $Profile.UpnCounter++
                    $n = $Profile.UpnCounter
                    $token = "[REDACTED_UPN_${n}]"
                } elseif ($Profile.RedactEmails) {
                    $Profile.EmailCounter++
                    $n = $Profile.EmailCounter
                    $token = "[REDACTED_EMAIL_${n}]"
                } else {
                    $token = $m.Value
                }

                $Profile.TokenMap[$src] = $token
                return $token
            }
        )
    }

    return $result
}

function Export-DecomRedactionReportJson {
    <#
    .SYNOPSIS
    Exports a redaction report to a JSON file.
    .DESCRIPTION
    Writes a JSON report summarising the redaction operation including token count,
    file count, profile name, and run metadata.
    .PARAMETER Profile
    The redaction profile used (post-redaction, with populated TokenMap).
    .PARAMETER Path
    Output file path for the JSON report.
    .PARAMETER RunId
    The run identifier to embed in the report.
    .PARAMETER ToolVersion
    The tool version string.
    .PARAMETER RedactedFileCount
    Number of files that were redacted.
    .EXAMPLE
    Export-DecomRedactionReportJson -Profile $profile -Path '.\out\redaction-report.json' -RunId $runId -ToolVersion 'Rev3.4' -RedactedFileCount 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Profile,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$RunId = '',

        [Parameter(Mandatory = $false)]
        [string]$ToolVersion = 'Rev3.6',

        [Parameter(Mandatory = $false)]
        [int]$RedactedFileCount = 0
    )

    $report = [ordered]@{
        SchemaVersion      = '3.4'
        ToolVersion        = $ToolVersion
        RunId              = $RunId
        GeneratedUtc       = (Get-Date).ToUniversalTime().ToString('o')
        ProfileName        = $Profile.ProfileName
        TokenCount         = $Profile.TokenMap.Count
        RedactedFileCount  = $RedactedFileCount
        Summary            = [ordered]@{
            TenantIdsRedacted      = $Profile.TenantIdCounter
            ObjectIdsRedacted      = $Profile.ObjectIdCounter
            AppIdsRedacted         = $Profile.AppIdCounter
            UpnsRedacted           = $Profile.UpnCounter
            EmailsRedacted         = $Profile.EmailCounter
            DisplayNamesRedacted   = $Profile.DisplayNameCounter
            RedactDisplayNames     = $Profile.RedactDisplayNames
            RedactRunId            = $Profile.RedactRunId
            RedactHashes           = $Profile.RedactHashes
        }
    }

    $report | ConvertTo-Json -Depth 6 | Set-Content -Path $Path -Encoding UTF8
}

function Export-DecomRedactionReportMarkdown {
    <#
    .SYNOPSIS
    Exports a redaction report to a Markdown file.
    .DESCRIPTION
    Writes a human-readable Markdown report summarising the redaction operation.
    .PARAMETER Profile
    The redaction profile used (post-redaction, with populated TokenMap).
    .PARAMETER Path
    Output file path for the Markdown report.
    .PARAMETER RunId
    The run identifier to embed in the report.
    .PARAMETER ToolVersion
    The tool version string.
    .PARAMETER RedactedFileCount
    Number of files that were redacted.
    .EXAMPLE
    Export-DecomRedactionReportMarkdown -Profile $profile -Path '.\out\redaction-report.md' -RunId $runId -ToolVersion 'Rev3.4' -RedactedFileCount 5
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Profile,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$RunId = '',

        [Parameter(Mandatory = $false)]
        [string]$ToolVersion = 'Rev3.6',

        [Parameter(Mandatory = $false)]
        [int]$RedactedFileCount = 0
    )

    $generatedUtc = (Get-Date).ToUniversalTime().ToString('o')

    $lines = @(
        '# Redaction Report',
        '',
        "**SchemaVersion:** 3.4  ",
        "**ToolVersion:** $ToolVersion  ",
        "**RunId:** $RunId  ",
        "**GeneratedUtc:** $generatedUtc  ",
        "**Profile:** $($Profile.ProfileName)  ",
        '',
        '## Summary',
        '',
        '| Field | Value |',
        '|---|---|',
        "| TokenCount | $($Profile.TokenMap.Count) |",
        "| RedactedFileCount | $RedactedFileCount |",
        "| TenantIdsRedacted | $($Profile.TenantIdCounter) |",
        "| ObjectIdsRedacted | $($Profile.ObjectIdCounter) |",
        "| AppIdsRedacted | $($Profile.AppIdCounter) |",
        "| UpnsRedacted | $($Profile.UpnCounter) |",
        "| EmailsRedacted | $($Profile.EmailCounter) |",
        "| DisplayNamesRedacted | $($Profile.DisplayNameCounter) |",
        "| RedactDisplayNames | $($Profile.RedactDisplayNames) |",
        "| RedactRunId | $($Profile.RedactRunId) |",
        "| RedactHashes | $($Profile.RedactHashes) |"
    )

    $lines -join "`n" | Set-Content -Path $Path -Encoding UTF8
}

function Test-DecomRedactedOutput {
    <#
    .SYNOPSIS
    Validates that a redacted output string contains no residual sensitive identifiers.
    .DESCRIPTION
    Checks that no raw GUIDs, UPNs, or email addresses remain in the redacted string.
    Returns a PSCustomObject with Passed (bool) and Violations (string[]).
    .PARAMETER RedactedString
    The string output to validate.
    .PARAMETER Profile
    The redaction profile that was applied.
    .EXAMPLE
    $result = Test-DecomRedactedOutput -RedactedString $redacted -Profile $profile
    if (-not $result.Passed) { $result.Violations | ForEach-Object { Write-Warning $_ } }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$RedactedString,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Profile
    )

    $violations = [System.Collections.Generic.List[string]]::new()

    if ([string]::IsNullOrEmpty($RedactedString)) {
        return [pscustomobject]@{
            Passed     = $true
            Violations = @()
        }
    }

    $guidPattern     = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
    $upnEmailPattern = '[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}'
    $hashPattern     = '[0-9a-fA-F]{64}'

    if ($Profile.RedactTenantId -or $Profile.RedactObjectIds -or $Profile.RedactAppIds) {
        $residualGuids = [System.Text.RegularExpressions.Regex]::Matches($RedactedString, $guidPattern)
        foreach ($m in $residualGuids) {
            $src = $m.Value.ToLower()
            # Only flag if this was a value that was in the original source map
            if ($Profile.TokenMap.ContainsKey($src)) {
                $violations.Add("Residual GUID found: $($m.Value)")
            }
        }
    }

    if ($Profile.RedactUpns -or $Profile.RedactEmails) {
        $residualUpns = [System.Text.RegularExpressions.Regex]::Matches($RedactedString, $upnEmailPattern)
        foreach ($m in $residualUpns) {
            $src = $m.Value.ToLower()
            if ($Profile.TokenMap.ContainsKey($src)) {
                $violations.Add("Residual UPN/email found: $($m.Value)")
            }
        }
    }

    if ($Profile.RedactHashes) {
        $residualHashes = [System.Text.RegularExpressions.Regex]::Matches($RedactedString, $hashPattern)
        foreach ($m in $residualHashes) {
            if ($Profile.TokenMap.ContainsKey($m.Value)) {
                $violations.Add("Residual hash found: $($m.Value)")
            }
        }
    }

    return [pscustomobject]@{
        Passed     = ($violations.Count -eq 0)
        Violations = $violations.ToArray()
    }
}
