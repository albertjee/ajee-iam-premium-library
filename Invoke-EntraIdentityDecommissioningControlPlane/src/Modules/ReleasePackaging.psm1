#Requires -Version 5.1

function New-DecomReleasePackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Context,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    Write-DecomInfo "Generating release package at $OutputPath..."

    # Create release directory structure
    $releaseDir = Join-Path $OutputPath "Rev2.5"
    New-Item -ItemType Directory -Path $releaseDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $releaseDir "docs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $releaseDir "runbooks") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $releaseDir "sample-outputs") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $releaseDir "validation") -Force | Out-Null

    try {
        # Copy required documentation
        $requiredDocs = @(
            "Required-Permissions.md",
            "Findings-Catalog.md",
            "Schema-Contracts.md",
            "Rev3-Write-Readiness.md"
        )
        foreach ($doc in $requiredDocs) {
            $sourcePath = Join-Path (Get-Location) "docs\$doc"
            $destPath = Join-Path $releaseDir "docs\$doc"
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $destPath -Force
                Write-DecomOk "Copied documentation: $doc"
            } else {
                throw "Required documentation not found: $doc"
            }
        }

        # Copy required runbooks
        $requiredRunbooks = @(
            "Assessment-Runbook.md",
            "WhatIf-Approval-Runbook.md",
            "ExecuteRemediation-Runbook.md",
            "Executive-Pack-Runbook.md",
            "Troubleshooting.md",
            "Rev3-Write-Readiness-Runbook.md"
        )
        foreach ($runbook in $requiredRunbooks) {
            $sourcePath = Join-Path (Get-Location) "runbooks\$runbook"
            $destPath = Join-Path $releaseDir "runbooks\$runbook"
            if (Test-Path $sourcePath) {
                Copy-Item -Path $sourcePath -Destination $destPath -Force
                Write-DecomOk "Copied runbook: $runbook"
            } else {
                Write-DecomWarn "Required runbook not found: $runbook"
            }
        }

        # Generate release package manifest
        Write-DecomReleasePackageManifest -Context $Context -OutputPath $releaseDir

        Write-DecomOk "Release package generation completed"

    } catch {
        Write-DecomError "Release package generation failed: $_"
        throw
    }
}

function Copy-DecomReleaseAsset {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        [switch]$MarkMissingIfNotFound
    )

    if (Test-Path $SourcePath) {
        Copy-Item -Path $SourcePath -Destination $DestinationPath -Force
        return $true
    } else {
        if ($MarkMissingIfNotFound) {
            # Create manifest entry indicating missing file
            $manifestEntry = [PSCustomObject]@{
                Source = $SourcePath
                Destination = $DestinationPath
                Missing = $true
                Reason = "Source file not found"
            }
            # This would be added to manifest in real implementation
            Write-DecomWarn "Asset not found (marked as missing): $SourcePath"
        }
        return $false
    }
}

function Write-DecomReleasePackageManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Context,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $manifest = [PSCustomObject]@{
        SchemaVersion = '2.5'
        ToolVersion   = $Context.ToolVersion
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        ClientName    = $Context.ClientName
        EngagementId  = $Context.EngagementId
        Assessor      = $Context.Assessor
        Contents      = @(
            [PSCustomObject]@{ Type = 'documentation'; Path = 'docs\Required-Permissions.md'; Description = 'Required Microsoft Graph permissions' },
            [PSCustomObject]@{ Type = 'documentation'; Path = 'docs\Findings-Catalog.md'; Description = 'Complete findings catalog with metadata' },
            [PSCustomObject]@{ Type = 'documentation'; Path = 'docs\Schema-Contracts.md'; Description = 'Schema contracts for all output objects' },
            [PSCustomObject]@{ Type = 'documentation'; Path = 'docs\Rev3-Write-Readiness.md'; Description = 'Rev3.0 write expansion readiness guidance' },
            [PSCustomObject]@{ Type = 'runbook'; Path = 'runbooks\Assessment-Runbook.md'; Description = 'Guide for running assessments' },
            [PSCustomObject]@{ Type = 'runbook'; Path = 'runbooks\WhatIf-Approval-Runbook.md'; Description = 'WhatIf approval process guide' },
            [PSCustomObject]@{ Type = 'runbook'; Path = 'runbooks\ExecuteRemediation-Runbook.md'; Description = 'Three-gate execution model guide' },
            [PSCustomObject]@{ Type = 'runbook'; Path = 'runbooks\Executive-Pack-Runbook.md'; Description = 'Executive evidence pack generation guide' },
            [PSCustomObject]@{ Type = 'runbook'; Path = 'runbooks\Troubleshooting.md'; Description = 'Common issues and resolution steps' },
            [PSCustomObject]@{ Type = 'runbook'; Path = 'runbooks\Rev3-Write-Readiness-Runbook.md'; Description = 'Rev3 write-readiness report interpretation guide' }
        )
    }

    # Check for sample outputs and mark missing if not found
    $sampleOutputs = @(
        @{ Type = 'sample'; Path = 'sample-outputs\demo-html-report.html'; Description = 'Demo HTML assessment report' },
        @{ Type = 'sample'; Path = 'sample-outputs\demo-findings.json'; Description = 'Demo findings JSON export' },
        @{ Type = 'sample'; Path = 'sample-outputs\demo-remediation-plan.md'; Description = 'Demo remediation plan markdown' },
        @{ Type = 'sample'; Path = 'sample-outputs\demo-executive-summary.md'; Description = 'Demo executive summary markdown' },
        @{ Type = 'sample'; Path = 'sample-outputs\demo-governance-dashboard.html'; Description = 'Demo governance KPI dashboard HTML' }
    )

    foreach ($sample in $sampleOutputs) {
        $sourcePath = Join-Path (Get-Location) $sample.Path
        if (Test-Path $sourcePath) {
            Copy-Item -Path $sourcePath -Destination (Join-Path $OutputPath $sample.Path) -Force
            $manifest.Contents += [PSCustomObject]@{
                Type = $sample.Type
                Path = $sample.Path
                Description = $sample.Description
                Missing = $false
            }
        } else {
            $manifest.Contents += [PSCustomObject]@{
                Type = $sample.Type
                Path = $sample.Path
                Description = $sample.Description
                Missing = $true
            }
            Write-DecomWarn "Sample output not found (marked as missing): $($sample.Path)"
        }
    }

    # Add validation outputs — look for them in Context.OutputPath (generated by SelfTest)
    $validationSources = @(
        @{ Pattern='release-validation-report-*.json';  Dest='validation\release-validation-report.json';  Description='Release validation report' },
        @{ Pattern='catalog-validation-report-*.json';  Dest='validation\catalog-validation-report.json';  Description='Catalog validation report' },
        @{ Pattern='schema-validation-report-*.json';   Dest='validation\schema-validation-report.json';   Description='Schema validation report' },
        @{ Pattern='execution-scope-registry-*.json';   Dest='validation\execution-scope-registry.json';   Description='Execution scope registry' },
        @{ Pattern='rev3-write-readiness-report-*.json';Dest='validation\rev3-write-readiness-report.json';Description='Rev3 write-readiness report' }
    )

    foreach ($item in $validationSources) {
        $source = $null
        if ($Context.OutputPath -and (Test-Path $Context.OutputPath)) {
            $source = Get-ChildItem -Path $Context.OutputPath -Filter $item.Pattern -File -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending | Select-Object -First 1
        }
        if ($source) {
            $dest = Join-Path $OutputPath $item.Dest
            Copy-Item -Path $source.FullName -Destination $dest -Force
            $missing = $false
        } else {
            $missing = $true
        }
        $manifest.Contents += [PSCustomObject]@{
            Type        = 'validation'
            Path        = $item.Dest
            Description = $item.Description
            Missing     = $missing
        }
    }

    $manifestPath = Join-Path $OutputPath "release-package-manifest.json"
    $json = $manifest | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $manifestPath -Encoding UTF8
    Write-DecomOk "Release package manifest: $manifestPath"
}