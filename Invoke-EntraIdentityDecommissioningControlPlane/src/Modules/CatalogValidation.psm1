function Import-DecomFindingsCatalog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CatalogPath
    )

    if (-not (Test-Path $CatalogPath)) {
        Throw "Findings catalog not found at path: $CatalogPath"
    }

    $catalogContent = Get-Content $CatalogPath -Raw
    $findings = @()

    # Parse markdown table rows for findings
    $lines = $catalogContent -split "`n"
    $inTable = $false
    $headers = $null

    foreach ($line in $lines) {
        if ($line -like "|*FindingId*|*") {
            $inTable = $true
            # Extract headers
            $headerParts = $line -split '\|' | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }
            $headers = @{}
            for ($i = 0; $i -lt $headerParts.Count; $i++) {
                $headers[$headerParts[$i]] = $i
            }
            continue
        }

        if ($inTable -and $line -like "|*---*|*") {
            continue  # Skip separator line
        }

        if ($inTable -and $line -like "|*|*") {
            $parts = $line -split '\|' | Where-Object { $_ -ne '' } | ForEach-Object { $_.Trim() }
            if ($parts.Count -gt 0) {
                $finding = [PSCustomObject]@{
                    FindingId = if ($headers.ContainsKey('FindingId')) { $parts[$headers['FindingId']] } else { '' }
                    Category  = if ($headers.ContainsKey('Category')) { $parts[$headers['Category']] } else { '' }
                    Title     = if ($headers.ContainsKey('Title')) { $parts[$headers['Title']] } else { '' }
                    Description = if ($headers.ContainsKey('Description')) { $parts[$headers['Description']] } else { '' }
                    Severity  = if ($headers.ContainsKey('Severity')) { $parts[$headers['Severity']] } else { '' }
                    RiskScore = if ($headers.ContainsKey('RiskScore')) {
                        $score = $parts[$headers['RiskScore']]
                        $nullRef = $null
if ([int]::TryParse($score, [ref]$nullRef)) {
                            [int]$score
                        } else {
                            $null
                        }
                    } else { $null }
                }
                $findings += $finding
            }
        }

        if ($inTable -and -not ($line -like "|*|*")) {
            break  # End of table
        }
    }

    return $findings
}

function Get-DecomFindingCatalogMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject[]]$Catalog
    )

    $map = @{}
    foreach ($finding in $Catalog) {
        if ($finding.FindingId) {
            $map[$finding.FindingId] = $finding
        }
    }
    return $map
}

function Test-DecomFindingCatalogAlignment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject[]]$Findings,
        [Parameter(Mandatory = $true)]
        [PSObject[]]$Catalog
    )

    $catalogMap = Get-DecomFindingCatalogMap -Catalog $Catalog

    $result = [PSCustomObject]@{
        Passed = $true
        UnknownFindingIds = @()
        SeverityMismatches = @()
        RiskScoreMismatches = @()
        RiskScoreBandViolations = @()
        MissingRequiredFields = @()
        InvalidRemediationModes = @()
    }

    $validRemediationModes = @('ManualApprovalRequired', 'AutoRemediable', 'InformationOnly', 'ProtectedObject')
    $severityBands = @{
        Critical = @{ Min = 80; Max = 100 }
        High     = @{ Min = 60; Max = 79 }
        Medium   = @{ Min = 40; Max = 59 }
        Low      = @{ Min = 25; Max = 39 }
        Informational = @{ Min = 0; Max = 24 }
    }

    foreach ($finding in $Findings) {
        $findingId = $finding.FindingId
        if (-not $findingId) {
            continue
        }

        # Check if finding exists in catalog
        if (-not $catalogMap.ContainsKey($findingId)) {
            $result.UnknownFindingIds += $findingId
            $result.Passed = $false
            continue
        }

        $catalogEntry = $catalogMap[$findingId]

        # Check required fields
        $requiredFields = @('FindingId', 'Category', 'Severity', 'RiskScore', 'Confidence', 'ObjectType', 'ObjectId', 'DisplayName', 'UserPrincipalName', 'Evidence', 'EvidenceSource', 'GraphEndpoint', 'RecommendedAction', 'RemediationMode', 'ConsultantNote')
        foreach ($field in $requiredFields) {
            $value = $finding.$field
            if (-not $value -or $value -eq '') {
                $result.MissingRequiredFields += "$findingId.$field"
                $result.Passed = $false
            }
        }

        # Check severity match
        if ($catalogEntry.Severity -and $finding.Severity) {
            if ($catalogEntry.Severity -ne $finding.Severity) {
                $result.SeverityMismatches += "$findingId`: catalog='$($catalogEntry.Severity)' vs finding='$($finding.Severity)'"
                $result.Passed = $false
            }
        }

        # Check RiskScore match
        if ($catalogEntry.RiskScore -and $finding.RiskScore) {
            if ($catalogEntry.RiskScore -ne $finding.RiskScore) {
                $result.RiskScoreMismatches += "${findingId}: catalog=$($catalogEntry.RiskScore) vs finding=$($finding.RiskScore)"
                $result.Passed = $false
            }
        }

        # Check RiskScore within severity band
        if ($finding.RiskScore -and $catalogEntry.Severity) {
            $band = $severityBands[$catalogEntry.Severity]
            if ($band) {
                if ($finding.RiskScore -lt $band.Min -or $finding.RiskScore -gt $band.Max) {
                    $result.RiskScoreBandViolations += "${findingId}: score=$($finding.RiskScore) outside $($catalogEntry.Severity) band ($($band.Min)-$($band.Max))"
                    $result.Passed = $false
                }
            }
        }

        # Check RemediationMode validity
        if ($finding.RemediationMode) {
            if (-not ($validRemediationModes -contains $finding.RemediationMode)) {
                $result.InvalidRemediationModes += "${findingId}: invalid mode='$($finding.RemediationMode)'"
                $result.Passed = $false
            }
        }
    }

    return $result
}

function Export-DecomCatalogValidationJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Result,
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fileBase   = "catalog-validation-report"
    $JsonPath   = Join-Path $Context.OutputPath "$fileBase-$Timestamp.json"

    $jsonObject = [PSCustomObject]@{
        SchemaVersion          = '3.0'
        ToolVersion            = $Context.ToolVersion
        GeneratedUtc           = (Get-Date).ToUniversalTime().ToString('o')
        ClientName             = $Context.ClientName
        EngagementId           = $Context.EngagementId
        Assessor               = $Context.Assessor
        Passed                 = $Result.Passed
        UnknownFindingIds      = $Result.UnknownFindingIds
        SeverityMismatches     = $Result.SeverityMismatches
        RiskScoreMismatches    = $Result.RiskScoreMismatches
        RiskScoreBandViolations= $Result.RiskScoreBandViolations
        MissingRequiredFields  = $Result.MissingRequiredFields
        InvalidRemediationModes= $Result.InvalidRemediationModes
    }

    $json = $jsonObject | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $JsonPath -Encoding UTF8
    Write-DecomOk "Catalog validation JSON: $JsonPath"
}

function Export-DecomCatalogValidationMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Result,
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fileBase   = "catalog-validation-report"
    $MdPath     = Join-Path $Context.OutputPath "$fileBase-$Timestamp.md"

    $markdown = @"
# Catalog Validation Report

**SchemaVersion:** 3.0
**ToolVersion:** $($Context.ToolVersion)
**GeneratedUtc:** $([DateTime]::UtcNow.ToString('o'))
**ClientName:** $($Context.ClientName)
**EngagementId:** $($Context.EngagementId)
**Assessor:** $($Context.Assessor)

## Summary
- **Passed:** $($Result.Passed)

## Validation Results
- **Unknown Finding IDs:** $($Result.UnknownFindingIds.Count)
- **Severity Mismatches:** $($Result.SeverityMismatches.Count)
- **RiskScore Mismatches:** $($Result.RiskScoreMismatches.Count)
- **RiskScore Band Violations:** $($Result.RiskScoreBandViolations.Count)
- **Missing Required Fields:** $($Result.MissingRequiredFields.Count)
- **Invalid Remediation Modes:** $($Result.InvalidRemediationModes.Count)

## Details
"@

    if ($Result.UnknownFindingIds.Count -gt 0) {
        $markdown += "### Unknown Finding IDs`n"
        $markdown += ($Result.UnknownFindingIds | ForEach-Object { "- $_" }) -join "`n"
        $markdown += "`n"
    }

    if ($Result.SeverityMismatches.Count -gt 0) {
        $markdown += "### Severity Mismatches`n"
        $markdown += ($Result.SeverityMismatches | ForEach-Object { "- $_" }) -join "`n"
        $markdown += "`n"
    }

    if ($Result.RiskScoreMismatches.Count -gt 0) {
        $markdown += "### RiskScore Mismatches`n"
        $markdown += ($Result.RiskScoreMismatches | ForEach-Object { "- $_" }) -join "`n"
        $markdown += "`n"
    }

    if ($Result.RiskScoreBandViolations.Count -gt 0) {
        $markdown += "### RiskScore Band Violations`n"
        $markdown += ($Result.RiskScoreBandViolations | ForEach-Object { "- $_" }) -join "`n"
        $markdown += "`n"
    }

    if ($Result.MissingRequiredFields.Count -gt 0) {
        $markdown += "### Missing Required Fields`n"
        $markdown += ($Result.MissingRequiredFields | ForEach-Object { "- $_" }) -join "`n"
        $markdown += "`n"
    }

    if ($Result.InvalidRemediationModes.Count -gt 0) {
        $markdown += "### Invalid Remediation Modes`n"
        $markdown += ($Result.InvalidRemediationModes | ForEach-Object { "- $_" }) -join "`n"
        $markdown += "`n"
    }

    $markdown += @"
---
© 2026 Albert Jee. All rights reserved.
"@

    $markdown | Out-File -FilePath $MdPath -Encoding UTF8
    Write-DecomOk "Catalog validation Markdown: $MdPath"
}