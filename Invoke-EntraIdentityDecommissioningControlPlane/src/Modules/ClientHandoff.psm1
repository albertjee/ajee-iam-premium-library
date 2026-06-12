function New-DecomClientHandoffPackage {
    <#
    .SYNOPSIS
    Creates a consultant-ready client handoff package manifest object.
    .DESCRIPTION
    Initializes a handoff package with schema version, run metadata, and categorized
    file sections. Marks sensitive files and warns when validation is missing.
    No write cmdlets are called — the returned object must be exported separately.
    .PARAMETER Context
    The run context (pscustomobject) containing ToolVersion, EngagementId, etc.
    .PARAMETER RunId
    The unique run identifier.
    .PARAMETER PackagePath
    Output directory that will contain the handoff package.
    .PARAMETER AssessmentFiles
    Paths to assessment report files.
    .PARAMETER FindingsFiles
    Paths to findings export files.
    .PARAMETER RemediationPlanFiles
    Paths to remediation plan files.
    .PARAMETER WhatIfFiles
    Paths to WhatIf approval evidence files.
    .PARAMETER ApprovalFiles
    Paths to approval manifest files.
    .PARAMETER ExecutionEvidenceFiles
    Paths to execution evidence files.
    .PARAMETER TraceabilityFiles
    Paths to traceability report files.
    .PARAMETER ReplayValidationFiles
    Paths to replay validation files.
    .PARAMETER RedactedFiles
    Paths to redacted (client-safe) output files. These are preferred over raw outputs.
    .PARAMETER RunbookFiles
    Paths to runbook files.
    .PARAMETER ValidationStatus
    Validation status string, e.g. 'NotValidated', 'Validated', 'PartiallyValidated'.
    .EXAMPLE
    $pkg = New-DecomClientHandoffPackage -Context $ctx -RunId 'run-001' -PackagePath '.\out\handoff'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string]$RunId,

        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [string[]]$AssessmentFiles = @(),
        [string[]]$FindingsFiles = @(),
        [string[]]$RemediationPlanFiles = @(),
        [string[]]$WhatIfFiles = @(),
        [string[]]$ApprovalFiles = @(),
        [string[]]$ExecutionEvidenceFiles = @(),
        [string[]]$TraceabilityFiles = @(),
        [string[]]$ReplayValidationFiles = @(),
        [string[]]$RedactedFiles = @(),
        [string[]]$RunbookFiles = @(),
        [string]$ValidationStatus = 'NotValidated'
    )

    $warnings        = @()
    $sensitiveFiles  = @()
    $clientSafeFiles = @()
    $clientHandoffFiles = @()

    $packageFilePatterns = @{
        ExecutiveSummary       = 'executive-summary|execsummary'
        ClientHandoffArtifacts = 'client-handoff|handoff-manifest|handoff-index|handoff-checklist'
        FindingsExports        = 'findings'
        RemediationPlan        = 'remediation-plan'
        WhatIfApprovalEvidence = 'whatif|approval'
        ExecutionEvidence      = 'execution'
        TraceabilityReport     = 'traceability'
        ReplayValidation       = 'replay-validation|replay'
        Runbooks               = 'runbook'
        AssessmentReports      = 'assessment|report|manifest|readiness'
    }

    # Helper: classify a file path as sensitive or client-safe
    # Redacted files are always client-safe. FindingsFiles contain identifiers.
    function _ClassifyFile {
        param([string]$FilePath, [bool]$IsRedacted = $false)
        if ($IsRedacted) {
            return 'ClientSafe'
        }
        $lower = $FilePath.ToLower()
        if ($lower -match 'findings|evidence|execution|trace|approval') {
            return 'Sensitive'
        }
        return 'ClientSafe'
    }

    # Build the sections ordered dictionary
    $sections = [ordered]@{
        ExecutiveSummary       = @()
        ClientHandoffArtifacts = @()
        AssessmentReports      = @()
        FindingsExports        = @()
        RemediationPlan        = @()
        WhatIfApprovalEvidence = @()
        ExecutionEvidence      = @()
        TraceabilityReport     = @()
        ReplayValidation       = @()
        RedactedClientSafe     = @()
        Runbooks               = @()
    }

    if (Test-Path -LiteralPath $PackagePath) {
        $discoveredFiles = @(Get-ChildItem -LiteralPath $PackagePath -File -Recurse -ErrorAction SilentlyContinue | Where-Object {
            $_.Extension -in @('.json','.csv','.md','.html')
        })

        foreach ($file in $discoveredFiles) {
            $pathValue = $file.FullName
            $relativePath = $pathValue.Substring($PackagePath.Length).TrimStart('\', '/')
            if ($relativePath -match '(^|\\)temp(\\|$)') {
                continue
            }
            if ($pathValue -match '\\redacted\\') {
                if ($RedactedFiles -notcontains $pathValue) { $RedactedFiles += $pathValue }
                continue
            }

            if ($AssessmentFiles.Count -eq 0 -and $FindingsFiles.Count -eq 0 -and $RemediationPlanFiles.Count -eq 0 -and $WhatIfFiles.Count -eq 0 -and
                $ApprovalFiles.Count -eq 0 -and $ExecutionEvidenceFiles.Count -eq 0 -and $TraceabilityFiles.Count -eq 0 -and $ReplayValidationFiles.Count -eq 0 -and
                $RunbookFiles.Count -eq 0) {
                switch -Regex ($file.Name) {
                    $packageFilePatterns.ExecutiveSummary       { if ($AssessmentFiles -notcontains $pathValue) { $AssessmentFiles += $pathValue }; break }
                    $packageFilePatterns.ClientHandoffArtifacts { if ($clientHandoffFiles -notcontains $pathValue) { $clientHandoffFiles += $pathValue }; break }
                    $packageFilePatterns.FindingsExports        { if ($FindingsFiles -notcontains $pathValue) { $FindingsFiles += $pathValue }; break }
                    $packageFilePatterns.RemediationPlan        { if ($RemediationPlanFiles -notcontains $pathValue) { $RemediationPlanFiles += $pathValue }; break }
                    $packageFilePatterns.WhatIfApprovalEvidence { if ($WhatIfFiles -notcontains $pathValue) { $WhatIfFiles += $pathValue }; break }
                    $packageFilePatterns.ExecutionEvidence      { if ($ExecutionEvidenceFiles -notcontains $pathValue) { $ExecutionEvidenceFiles += $pathValue }; break }
                    $packageFilePatterns.TraceabilityReport     { if ($TraceabilityFiles -notcontains $pathValue) { $TraceabilityFiles += $pathValue }; break }
                    $packageFilePatterns.ReplayValidation       { if ($ReplayValidationFiles -notcontains $pathValue) { $ReplayValidationFiles += $pathValue }; break }
                    $packageFilePatterns.Runbooks               { if ($RunbookFiles -notcontains $pathValue) { $RunbookFiles += $pathValue }; break }
                    default                                     { if ($AssessmentFiles -notcontains $pathValue) { $AssessmentFiles += $pathValue } }
                }
            }
        }
    }

    # Populate AssessmentReports
    foreach ($f in $AssessmentFiles) {
        $sections.AssessmentReports += $f
        $class = _ClassifyFile -FilePath $f
        if ($class -eq 'Sensitive') { $sensitiveFiles += $f } else { $clientSafeFiles += $f }
    }

    foreach ($f in $clientHandoffFiles) {
        $sections.ClientHandoffArtifacts += $f
        $clientSafeFiles += $f
    }

    # Populate FindingsExports — raw findings are always sensitive (contain identifiers)
    foreach ($f in $FindingsFiles) {
        $sections.FindingsExports += $f
        $sensitiveFiles += $f
    }

    # Populate RemediationPlan
    foreach ($f in $RemediationPlanFiles) {
        $sections.RemediationPlan += $f
        $class = _ClassifyFile -FilePath $f
        if ($class -eq 'Sensitive') { $sensitiveFiles += $f } else { $clientSafeFiles += $f }
    }

    # WhatIf + Approval evidence — sensitive
    foreach ($f in $WhatIfFiles) {
        $sections.WhatIfApprovalEvidence += $f
        $sensitiveFiles += $f
    }
    foreach ($f in $ApprovalFiles) {
        $sections.WhatIfApprovalEvidence += $f
        $sensitiveFiles += $f
    }

    # Execution evidence — sensitive
    foreach ($f in $ExecutionEvidenceFiles) {
        $sections.ExecutionEvidence += $f
        $sensitiveFiles += $f
    }

    # Traceability — sensitive
    foreach ($f in $TraceabilityFiles) {
        $sections.TraceabilityReport += $f
        $sensitiveFiles += $f
    }

    # Replay validation — sensitive but shared with client only when passing
    foreach ($f in $ReplayValidationFiles) {
        $sections.ReplayValidation += $f
        $sensitiveFiles += $f
    }

    # Redacted files — PREFERRED for client sharing
    foreach ($f in $RedactedFiles) {
        $sections.RedactedClientSafe += $f
        $clientSafeFiles += $f
    }

    # Runbooks — client safe
    foreach ($f in $RunbookFiles) {
        $sections.Runbooks += $f
        $clientSafeFiles += $f
    }

    # Warning: missing validation
    if ($ValidationStatus -eq 'NotValidated' -or [string]::IsNullOrEmpty($ValidationStatus)) {
        $warnings += 'ValidationStatus is NotValidated — replay validation report is missing or not yet run. Confirm replay passes before delivering package to client.'
    }

    # Warning: no redacted outputs
    if ($RedactedFiles.Count -eq 0) {
        $warnings += 'No RedactedFiles provided — sensitive findings have not been redacted. Ensure redacted outputs are prepared before sharing with client.'
    }

    $package = [pscustomobject]@{
        SchemaVersion            = '3.6'
        ToolVersion              = $Context.ToolVersion
        RunId                    = $RunId
        PackageId                = [guid]::NewGuid().ToString()
        GeneratedUtc             = (Get-Date).ToUniversalTime().ToString('o')
        PackagePath              = $PackagePath
        ValidationStatus         = $ValidationStatus
        Sections                 = $sections
        SensitiveFiles           = $sensitiveFiles
        ClientSafeFiles          = $clientSafeFiles
        Warnings                 = $warnings
        NextStepRecommendations  = @(
            'Review traceability report for any TraceGap findings'
            'Validate replay report passes all checks'
            'Confirm all sensitive files are redacted before sharing with client'
            'Rev3.5 NHI and agentic identity audit scope is available for next engagement'
        )
    }

    return $package
}

function Export-DecomClientHandoffManifestJson {
    <#
    .SYNOPSIS
    Exports the client handoff package manifest to a JSON file.
    .DESCRIPTION
    Serializes the handoff package object to JSON at the specified path.
    .PARAMETER Package
    The handoff package object returned by New-DecomClientHandoffPackage.
    .PARAMETER Path
    Destination file path for the JSON output.
    .EXAMPLE
    Export-DecomClientHandoffManifestJson -Package $pkg -Path '.\out\handoff\manifest.json'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Package,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $Package | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        Write-Verbose "Client handoff manifest exported to $Path"
    } catch {
        Write-Error "Failed to export client handoff manifest JSON: $_"
        throw
    }
}

function Export-DecomClientHandoffIndexMarkdown {
    <#
    .SYNOPSIS
    Exports a markdown index of the client handoff package.
    .DESCRIPTION
    Writes a structured markdown document listing all sections and files in the package.
    .PARAMETER Package
    The handoff package object returned by New-DecomClientHandoffPackage.
    .PARAMETER Path
    Destination file path for the markdown output.
    .EXAMPLE
    Export-DecomClientHandoffIndexMarkdown -Package $pkg -Path '.\out\handoff\index.md'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Package,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $lines = @()
        $lines += "# Client Handoff Package Index"
        $lines += ""
        $lines += "**Schema Version:** $($Package.SchemaVersion)"
        $lines += "**Tool Version:** $($Package.ToolVersion)"
        $lines += "**Run ID:** $($Package.RunId)"
        $lines += "**Package ID:** $($Package.PackageId)"
        $lines += "**Generated:** $($Package.GeneratedUtc)"
        $lines += "**Package Path:** $($Package.PackagePath)"
        $lines += "**Validation Status:** $($Package.ValidationStatus)"
        $lines += ""

        if ($Package.Warnings.Count -gt 0) {
            $lines += "## Warnings"
            $lines += ""
            foreach ($w in $Package.Warnings) {
                $lines += "- $w"
            }
            $lines += ""
        }

        $lines += "## Package Sections"
        $lines += ""

        foreach ($sectionName in $Package.Sections.Keys) {
            $files = $Package.Sections[$sectionName]
            $count = if ($null -eq $files) { 0 } else { @($files).Count }
            $lines += "### $sectionName ($count file(s))"
            $lines += ""
            if ($count -gt 0) {
                foreach ($f in @($files)) {
                    $lines += "- $f"
                }
            } else {
                $lines += "_No files in this section._"
            }
            $lines += ""
        }

        $lines += "## Client-Safe Files"
        $lines += ""
        if ($Package.ClientSafeFiles.Count -gt 0) {
            foreach ($f in $Package.ClientSafeFiles) {
                $lines += "- $f"
            }
        } else {
            $lines += "_None. Ensure redacted outputs are prepared._"
        }
        $lines += ""

        $lines += "## Sensitive Files (Do Not Share)"
        $lines += ""
        if ($Package.SensitiveFiles.Count -gt 0) {
            foreach ($f in $Package.SensitiveFiles) {
                $lines += "- $f"
            }
        } else {
            $lines += "_None._"
        }
        $lines += ""

        $lines += "## Next Steps"
        $lines += ""
        foreach ($ns in $Package.NextStepRecommendations) {
            $lines += "- $ns"
        }
        $lines += ""

        $content = $lines -join "`n"
        Set-Content -Path $Path -Value $content -Encoding UTF8
        Write-Verbose "Client handoff index markdown exported to $Path"
    } catch {
        Write-Error "Failed to export client handoff index markdown: $_"
        throw
    }
}

function Export-DecomClientHandoffChecklistMarkdown {
    <#
    .SYNOPSIS
    Exports a consultant checklist markdown for the client handoff package.
    .DESCRIPTION
    Writes a markdown document with checkbox items for the consultant to verify
    before delivering the package to the client.
    .PARAMETER Package
    The handoff package object returned by New-DecomClientHandoffPackage.
    .PARAMETER Path
    Destination file path for the markdown output.
    .EXAMPLE
    Export-DecomClientHandoffChecklistMarkdown -Package $pkg -Path '.\out\handoff\checklist.md'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Package,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $lines = @()
        $lines += "# Client Handoff Checklist"
        $lines += ""
        $lines += "**Run ID:** $($Package.RunId)"
        $lines += "**Package ID:** $($Package.PackageId)"
        $lines += "**Generated:** $($Package.GeneratedUtc)"
        $lines += "**Validation Status:** $($Package.ValidationStatus)"
        $lines += ""
        $lines += "## Pre-Delivery Checklist"
        $lines += ""
        $lines += "Complete all items below before delivering the package to the client."
        $lines += ""
        $lines += "- [ ] Assessment reports reviewed"
        $lines += "- [ ] Findings exported"
        $lines += "- [ ] Remediation plan approved"
        $lines += "- [ ] WhatIf/Approval evidence attached"
        $lines += "- [ ] Execution evidence validated"
        $lines += "- [ ] Traceability report clean"
        $lines += "- [ ] Replay validation passed"
        $lines += "- [ ] Redacted files prepared for client sharing"
        $lines += "- [ ] Runbooks included"
        $lines += "- [ ] Sensitive files NOT included in client package"
        $lines += "- [ ] Rev3.5 NHI readiness scope noted for future engagement"
        $lines += ""

        if ($Package.Warnings.Count -gt 0) {
            $lines += "## Warnings Requiring Attention"
            $lines += ""
            foreach ($w in $Package.Warnings) {
                $lines += "- **WARNING:** $w"
            }
            $lines += ""
        }

        $lines += "## Next Step Recommendations"
        $lines += ""
        foreach ($ns in $Package.NextStepRecommendations) {
            $lines += "- $ns"
        }
        $lines += ""

        $content = $lines -join "`n"
        Set-Content -Path $Path -Value $content -Encoding UTF8
        Write-Verbose "Client handoff checklist markdown exported to $Path"
    } catch {
        Write-Error "Failed to export client handoff checklist markdown: $_"
        throw
    }
}
