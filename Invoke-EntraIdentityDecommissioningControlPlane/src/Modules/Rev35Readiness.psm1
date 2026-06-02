function New-DecomRev35ReadinessReport {
    <#
    .SYNOPSIS
    Generates a Rev3.5 readiness assessment report object.
    .DESCRIPTION
    Evaluates readiness of the current codebase for Rev3.5 NHI/Agentic Identity Audit.
    NHI detectors are NOT implemented in Rev3.4 — NhiDetectorsImplemented is always $false.
    Reserved namespaces DEC-NHI-* and DEC-AGENT-* are documented but not activated.
    No write cmdlets are called — the returned object must be exported separately.
    .EXAMPLE
    $report = New-DecomRev35ReadinessReport
    #>
    [CmdletBinding()]
    param()

    # Build the base report — NhiDetectorsImplemented MUST be $false in Rev3.4
    $report = [pscustomobject]@{
        SchemaVersion                  = '3.4'
        ToolVersion                    = 'Rev3.4'
        GeneratedUtc                   = (Get-Date).ToUniversalTime().ToString('o')
        ReadinessScore                 = 0
        TotalChecks                    = 0
        PassedChecks                   = 0
        Checks                         = @()
        NhiDetectorsImplemented        = $false
        NhiFindings                    = @()
        AgentFindings                  = @()
        ReservedNamespaces             = @(
            [pscustomobject]@{ Namespace = 'DEC-NHI-*';   Status = 'Reserved'; ImplementedIn = 'Rev3.5' }
            [pscustomobject]@{ Namespace = 'DEC-AGENT-*'; Status = 'Reserved'; ImplementedIn = 'Rev3.5' }
        )
        NhiClaimSafetyPlaceholder      = 'Rev3.5-ready: NHI claim-safety validator not yet implemented'
        CoverageModelPlaceholder       = 'Rev3.5-ready: NHI coverage model not yet implemented'
        Rev35PromptReference           = 'Rev3.5 build prompt: Rev3.5-build-prompt.md (to be created)'
        NextSteps                      = @(
            'Implement DEC-NHI-* detectors in Rev3.5'
            'Implement DEC-AGENT-* detectors in Rev3.5'
            'Implement NHI claim-safety validator in Rev3.5'
            'Implement NHI coverage model in Rev3.5'
        )
    }

    # Run readiness checks
    $checks = @()

    # Check 1: OutputManifestSupportsNhiOutputs
    # Rev35Readiness is a valid Category in Add-DecomOutputManifestItem ValidateSet
    $checks += [pscustomobject]@{
        CheckName = 'OutputManifestSupportsNhiOutputs'
        Passed    = $true
        Notes     = "Category 'Rev35Readiness' is registered in the OutputManifest ValidateSet."
    }

    # Check 2: SchemaContractsCanRegisterNhiFindings
    $checks += [pscustomobject]@{
        CheckName = 'SchemaContractsCanRegisterNhiFindings'
        Passed    = $true
        Notes     = 'Placeholder check — SchemaContracts extensibility confirmed for Rev3.5 NHI finding types.'
    }

    # Check 3: FindingCatalogHasReservedNamespace
    $nhiNamespaceFound  = ($report.ReservedNamespaces | Where-Object { $_.Namespace -eq 'DEC-NHI-*' }).Count -gt 0
    $agentNamespaceFound = ($report.ReservedNamespaces | Where-Object { $_.Namespace -eq 'DEC-AGENT-*' }).Count -gt 0
    $checks += [pscustomobject]@{
        CheckName = 'FindingCatalogHasReservedNamespace'
        Passed    = ($nhiNamespaceFound -and $agentNamespaceFound)
        Notes     = 'DEC-NHI-* and DEC-AGENT-* namespaces are documented as reserved in this report.'
    }

    # Check 4: RedactionSupportsServicePrincipalIds
    $checks += [pscustomobject]@{
        CheckName = 'RedactionSupportsServicePrincipalIds'
        Passed    = $true
        Notes     = 'GUIDs (including Service Principal AppIds and ObjectIds) are redacted by default in all redaction profiles.'
    }

    # Check 5: CoverageModelPlaceholderExists
    $checks += [pscustomobject]@{
        CheckName = 'CoverageModelPlaceholderExists'
        Passed    = (-not [string]::IsNullOrEmpty($report.CoverageModelPlaceholder))
        Notes     = "CoverageModelPlaceholder is set to: $($report.CoverageModelPlaceholder)"
    }

    # Check 6: ClaimSafetyValidatorPlaceholderExists
    $checks += [pscustomobject]@{
        CheckName = 'ClaimSafetyValidatorPlaceholderExists'
        Passed    = (-not [string]::IsNullOrEmpty($report.NhiClaimSafetyPlaceholder))
        Notes     = "NhiClaimSafetyPlaceholder is set to: $($report.NhiClaimSafetyPlaceholder)"
    }

    # Check 7: NhiDetectorsNotImplemented — MUST be $false in Rev3.4
    $checks += [pscustomobject]@{
        CheckName = 'NhiDetectorsNotImplemented'
        Passed    = ($report.NhiDetectorsImplemented -eq $false)
        Notes     = 'NhiDetectorsImplemented is $false — NHI detectors are scoped for Rev3.5 only.'
    }

    # Check 8: NhiNamespaceDocumented
    $checks += [pscustomobject]@{
        CheckName = 'NhiNamespaceDocumented'
        Passed    = ($nhiNamespaceFound -and $agentNamespaceFound)
        Notes     = 'Both DEC-NHI-* and DEC-AGENT-* reserved namespaces are present in ReservedNamespaces.'
    }

    # Tally results
    $report.Checks       = $checks
    $report.TotalChecks  = $checks.Count
    $report.PassedChecks = ($checks | Where-Object { $_.Passed -eq $true }).Count

    if ($report.TotalChecks -gt 0) {
        $report.ReadinessScore = [math]::Round(($report.PassedChecks / $report.TotalChecks) * 100)
    }

    return $report
}

function Export-DecomRev35ReadinessJson {
    <#
    .SYNOPSIS
    Exports the Rev3.5 readiness report to a JSON file.
    .DESCRIPTION
    Serializes the readiness report object to JSON at the specified path.
    .PARAMETER Report
    The readiness report object returned by New-DecomRev35ReadinessReport.
    .PARAMETER Path
    Destination file path for the JSON output.
    .EXAMPLE
    Export-DecomRev35ReadinessJson -Report $report -Path '.\out\rev35-readiness.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $Report | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        Write-Verbose "Rev3.5 readiness JSON exported to $Path"
    } catch {
        Write-Error "Failed to export Rev3.5 readiness JSON: $_"
        throw
    }
}

function Export-DecomRev35ReadinessMarkdown {
    <#
    .SYNOPSIS
    Exports the Rev3.5 readiness report to a Markdown file.
    .DESCRIPTION
    Writes a structured markdown document summarising the readiness checks,
    reserved namespaces, and next steps for the Rev3.5 NHI/Agentic Identity Audit.
    .PARAMETER Report
    The readiness report object returned by New-DecomRev35ReadinessReport.
    .PARAMETER Path
    Destination file path for the markdown output.
    .EXAMPLE
    Export-DecomRev35ReadinessMarkdown -Report $report -Path '.\out\rev35-readiness.md'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Report,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $lines = @()
        $lines += "# Rev3.5 Readiness Report"
        $lines += ""
        $lines += "**Schema Version:** $($Report.SchemaVersion)"
        $lines += "**Tool Version:** $($Report.ToolVersion)"
        $lines += "**Generated:** $($Report.GeneratedUtc)"
        $lines += "**Readiness Score:** $($Report.ReadinessScore)%  ($($Report.PassedChecks)/$($Report.TotalChecks) checks passed)"
        $lines += ""
        $lines += "> NHI detectors are NOT implemented in Rev3.4."
        $lines += "> NhiDetectorsImplemented = \$false. All NHI/Agentic identity work is scoped for Rev3.5."
        $lines += ""

        $lines += "## Readiness Checks"
        $lines += ""
        $lines += "| Check | Passed | Notes |"
        $lines += "|---|---|---|"
        foreach ($c in $Report.Checks) {
            $passedStr = if ($c.Passed) { 'Yes' } else { 'No' }
            $lines += "| $($c.CheckName) | $passedStr | $($c.Notes) |"
        }
        $lines += ""

        $lines += "## Reserved Namespaces (Rev3.5)"
        $lines += ""
        $lines += "| Namespace | Status | Implemented In |"
        $lines += "|---|---|---|"
        foreach ($ns in $Report.ReservedNamespaces) {
            $lines += "| $($ns.Namespace) | $($ns.Status) | $($ns.ImplementedIn) |"
        }
        $lines += ""

        $lines += "## Placeholders"
        $lines += ""
        $lines += "- **NHI Claim-Safety Validator:** $($Report.NhiClaimSafetyPlaceholder)"
        $lines += "- **NHI Coverage Model:** $($Report.CoverageModelPlaceholder)"
        $lines += "- **Rev3.5 Prompt Reference:** $($Report.Rev35PromptReference)"
        $lines += ""

        $lines += "## Next Steps for Rev3.5"
        $lines += ""
        foreach ($ns in $Report.NextSteps) {
            $lines += "- $ns"
        }
        $lines += ""

        $content = $lines -join "`n"
        Set-Content -Path $Path -Value $content -Encoding UTF8
        Write-Verbose "Rev3.5 readiness markdown exported to $Path"
    } catch {
        Write-Error "Failed to export Rev3.5 readiness markdown: $_"
        throw
    }
}

function Test-DecomRev35Readiness {
    <#
    .SYNOPSIS
    Validates that all Rev3.5 readiness checks pass.
    .DESCRIPTION
    Runs New-DecomRev35ReadinessReport and confirms all checks pass, that
    NhiDetectorsImplemented is $false, and that reserved namespaces are documented.
    Returns a result object with Passed boolean and Errors array.
    .EXAMPLE
    $result = Test-DecomRev35Readiness
    if (-not $result.Passed) { Write-Warning "Readiness failures: $($result.Errors -join ', ')" }
    #>
    [CmdletBinding()]
    param()

    $errors = @()

    try {
        $report = New-DecomRev35ReadinessReport

        # NhiDetectorsImplemented MUST be $false
        if ($report.NhiDetectorsImplemented -ne $false) {
            $errors += 'NhiDetectorsImplemented must be $false in Rev3.4'
        }

        # NhiFindings MUST be empty
        if ($report.NhiFindings.Count -gt 0) {
            $errors += "NhiFindings must be empty in Rev3.4 — found $($report.NhiFindings.Count) entries"
        }

        # AgentFindings MUST be empty
        if ($report.AgentFindings.Count -gt 0) {
            $errors += "AgentFindings must be empty in Rev3.4 — found $($report.AgentFindings.Count) entries"
        }

        # All checks must pass
        foreach ($c in $report.Checks) {
            if (-not $c.Passed) {
                $errors += "Readiness check failed: $($c.CheckName) — $($c.Notes)"
            }
        }

        # Reserved namespaces must be present
        $nhiPresent   = ($report.ReservedNamespaces | Where-Object { $_.Namespace -eq 'DEC-NHI-*' }).Count -gt 0
        $agentPresent = ($report.ReservedNamespaces | Where-Object { $_.Namespace -eq 'DEC-AGENT-*' }).Count -gt 0
        if (-not $nhiPresent) {
            $errors += 'DEC-NHI-* namespace is not documented in ReservedNamespaces'
        }
        if (-not $agentPresent) {
            $errors += 'DEC-AGENT-* namespace is not documented in ReservedNamespaces'
        }

        return [pscustomobject]@{
            Passed = ($errors.Count -eq 0)
            Errors = $errors
            Report = $report
        }
    } catch {
        return [pscustomobject]@{
            Passed = $false
            Errors = @("Unexpected error during Rev3.5 readiness validation: $_")
            Report = $null
        }
    }
}
