function New-DecomEvidenceBundle {
    <#
    .SYNOPSIS
    Creates a new evidence bundle object.
    .DESCRIPTION
    Initializes a new evidence bundle with schema version, tool version, and run metadata.
    .PARAMETER Context
    The run context containing EngagementId, ClientName, ToolVersion, etc.
    .PARAMETER RunId
    The unique run identifier.
    .PARAMETER BundleId
    The unique bundle identifier.
    .PARAMETER SourceOutputPath
    The path to the source output directory (where the run outputs are).
    .PARAMETER BundleOutputPath
    The path where the evidence bundle will be stored.
    .RETURNS
    A PSCustomObject representing the evidence bundle.
    .EXAMPLE
    $bundle = New-DecomEvidenceBundle -Context $Context -RunId $runId -BundleId $bundleId -SourceOutputPath $runFolder -BundleOutputPath "$runFolder\evidence-bundle"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string]$RunId,

        [Parameter(Mandatory = $true)]
        [string]$BundleId,

        [Parameter(Mandatory = $true)]
        [string]$SourceOutputPath,

        [Parameter(Mandatory = $true)]
        [string]$BundleOutputPath
    )

    $bundle = [ordered]@{
        SchemaVersion   = '3.4'
        ToolVersion     = $Context.ToolVersion
        RunId           = $RunId
        BundleId        = $BundleId
        GeneratedUtc    = (Get-Date).ToUniversalTime().ToString('o')
        SourceOutputPath = $SourceOutputPath
        BundleOutputPath = $BundleOutputPath
        FileCount       = 0
        TotalBytes      = 0
        Sha256ManifestHash = $null
        Files           = @()
        Limitations     = @()
    }

    return [pscustomobject]$bundle
}

function Add-DecomEvidenceBundleFile {
    <#
    .SYNOPSIS
    Adds a file to the evidence bundle.
    .DESCRIPTION
    Adds a file with metadata to the evidence bundle's Files array.
    .PARAMETER Bundle
    The evidence bundle to update.
    .PARAMETER FilePath
    The full path to the file to add.
    .PARAMETER Category
    The category of the file (e.g., Assessment, Findings, WhatIf, etc.).
    .RETURNS
    The updated evidence bundle.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Bundle,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string]$Category
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return $Bundle
    }

    try {
        $fileInfo = Get-Item $FilePath
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)

        # Calculate SHA-256 hash
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($fileBytes)
        $hashHex = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()

        $fileId = [guid]::NewGuid().ToString()
        try {
            $resolvedBase = [System.IO.Path]::GetFullPath($Bundle.SourceOutputPath).TrimEnd('\', '/')
            $resolvedFile = [System.IO.Path]::GetFullPath($FilePath)
            if ($resolvedFile.StartsWith($resolvedBase + '\', [StringComparison]::OrdinalIgnoreCase) -or
                $resolvedFile.StartsWith($resolvedBase + '/', [StringComparison]::OrdinalIgnoreCase)) {
                $relativePath = '.' + $resolvedFile.Substring($resolvedBase.Length)
            } else {
                $relativePath = $resolvedFile
            }
        } catch {
            $relativePath = $FilePath
        }

        $fileEntry = [ordered]@{
            FileId          = $fileId
            FileName        = $fileInfo.Name
            RelativePath    = $relativePath
            FullPath        = $fileInfo.FullName
            Category        = $Category
            SizeBytes       = $fileInfo.Length
            Sha256          = $hashHex
        }

        # Check for duplicate FileId (shouldn't happen with GUID, but validate)
        if ($Bundle.Files.FileId -contains $fileId) {
            throw "Duplicate FileId detected: $fileId"
        }

        $Bundle.Files += [pscustomobject]$fileEntry

        # Update summary
        $Bundle.FileCount++
        $Bundle.TotalBytes += $fileInfo.Length

        return $Bundle
    } catch {
        Write-Error "Failed to add file to evidence bundle: $_"
        return $Bundle
    }
}

function Export-DecomEvidenceBundleManifestJson {
    <#
    .SYNOPSIS
    Exports the evidence bundle manifest to JSON file.
    .DESCRIPTION
    Writes the evidence bundle manifest as a JSON file to disk.
    .PARAMETER Bundle
    The evidence bundle to export.
    .PARAMETER Path
    The file path for the JSON output.
    .EXAMPLE
    Export-DecomEvidenceBundleManifestJson -Bundle $bundle -Path "$bundlePath\manifest.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Bundle,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $bundle | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        Write-Verbose "Evidence bundle manifest exported to $Path"
    } catch {
        Write-Error "Failed to export evidence bundle manifest JSON: $_"
        throw
    }
}

function Export-DecomEvidenceBundleIndexMarkdown {
    <#
    .SYNOPSIS
    Exports the evidence bundle index to Markdown file.
    .DESCRIPTION
    Writes a markdown index of the evidence bundle contents.
    .PARAMETER Bundle
    The evidence bundle to export.
    .PARAMETER Path
    The file path for the markdown output.
    .EXAMPLE
    Export-DecomEvidenceBundleIndexMarkdown -Bundle $bundle -Path "$bundlePath\index.md"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Bundle,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $header = @"
# Evidence Bundle Index

**Bundle ID:** $($Bundle.BundleId)
**Run ID:** $($Bundle.RunId)
**Generated:** $($Bundle.GeneratedUtc)
**Source Output Path:** $($Bundle.SourceOutputPath)
**Bundle Output Path:** $($Bundle.BundleOutputPath)

## Summary
- **File Count:** $($Bundle.FileCount)
- **Total Size:** $($Bundle.TotalBytes) bytes

## Files

| File Name | Category | Size (Bytes) | SHA-256 |
|-----------|----------|--------------|---------|
"@

        $rows = foreach ($file in $Bundle.Files) {
            "| $($file.FileName) | $($file.Category) | $($file.SizeBytes) | $($file.Sha256) |"
        }

        $content = $header + ($rows -join "`n")
        Set-Content -Path $Path -Value $content -Encoding UTF8
        Write-Verbose "Evidence bundle index markdown exported to $Path"
    } catch {
        Write-Error "Failed to export evidence bundle index markdown: $_"
        throw
    }
}

function Export-DecomEvidenceHashManifest {
    <#
    .SYNOPSIS
    Exports the evidence hash manifest (JSON and CSV).
    .DESCRIPTION
    Creates a hash manifest containing file names and their SHA-256 hashes.
    .PARAMETER Bundle
    The evidence bundle to export.
    .PARAMETER JsonPath
    The file path for the JSON hash manifest.
    .PARAMETER CsvPath
    The file path for the CSV hash manifest.
    .EXAMPLE
    Export-DecomEvidenceHashManifest -Bundle $bundle -JsonPath "$bundlePath\hashes.json" -CsvPath "$bundlePath\hashes.csv"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Bundle,

        [Parameter(Mandatory = $true)]
        [string]$JsonPath,

        [Parameter(Mandatory = $true)]
        [string]$CsvPath
    )

    try {
        # Build hash manifest object
        $hashManifest = [ordered]@{
            SchemaVersion   = '3.4'
            ToolVersion     = $Bundle.ToolVersion
            RunId           = $Bundle.RunId
            GeneratedUtc    = $Bundle.GeneratedUtc
            Hashes          = @()
        }

        foreach ($file in $Bundle.Files) {
            $hashManifest.Hashes += [ordered]@{
                FileName    = $file.FileName
                RelativePath = $file.RelativePath
                Sha256      = $file.Sha256
            }
        }

        # Export JSON
        $hashManifest | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonPath -Encoding UTF8
        Write-Verbose "Evidence hash manifest JSON exported to $JsonPath"

        # Export CSV
        if ($Bundle.Files.Count -gt 0) {
            $Bundle.Files | Select-Object FileName, RelativePath, Sha256 | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8
        } else {
            $headers = "FileName,RelativePath,Sha256"
            $headers | Set-Content -Path $CsvPath -Encoding UTF8
        }
        Write-Verbose "Evidence hash manifest CSV exported to $CsvPath"
    } catch {
        Write-Error "Failed to export evidence hash manifest: $_"
        throw
    }
}

function Test-DecomEvidenceBundle {
    <#
    .SYNOPSIS
    Tests the evidence bundle for validity.
    .DESCRIPTION
    Validates the evidence bundle schema, checks for missing files, duplicate entries, and validates hashes.
    .PARAMETER Bundle
    The evidence bundle to test.
    .PARAMETER RequireHashValidation
    If $true, validates that file hashes match current file contents.
    .RETURNS
    A PSCustomObject with Passed boolean and Errors array.
    .EXAMPLE
    $result = Test-DecomEvidenceBundle -Bundle $bundle -RequireHashValidation $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Bundle,

        [bool]$RequireHashValidation = $false
    )

    $errors = @()

    try {
        # Check schema version
        if ($Bundle.SchemaVersion -ne '3.4') {
            $errors += "Invalid SchemaVersion: expected '3.4', got '$($Bundle.SchemaVersion)'"
        }

        # Check tool version
        if (-not $Bundle.ToolVersion) {
            $errors += "ToolVersion is required"
        }

        # Check run ID
        if (-not $Bundle.RunId) {
            $errors += "RunId is required"
        }

        # Check bundle ID
        if (-not $Bundle.BundleId) {
            $errors += "BundleId is required"
        }

        # Check generated UTC
        if (-not $Bundle.GeneratedUtc) {
            $errors += "GeneratedUtc is required"
        }

        # Check source output path
        if (-not $Bundle.SourceOutputPath) {
            $errors += "SourceOutputPath is required"
        }

        # Check bundle output path
        if (-not $Bundle.BundleOutputPath) {
            $errors += "BundleOutputPath is required"
        }

        # Check files array
        if (-not $Bundle.Files) {
            $errors += "Files array is required"
        } elseif ($Bundle.Files -isnot [system.object[]]) {
            $errors += "Files must be an array"
        }

        # Check each file entry
        $fileIds = @()
        $relativePaths = @()

        for ($i = 0; $i -lt $Bundle.Files.Count; $i++) {
            $file = $Bundle.Files[$i]

            # Check required fields
            if (-not $file.FileId) {
                $errors += "File entry ${i}: FileId is required"
            } else {
                if ($fileIds -contains $file.FileId) {
                    $errors += "File entry ${i}: Duplicate FileId: $($file.FileId)"
                }
                $fileIds += $file.FileId
            }

            if (-not $file.FileName) {
                $errors += "File entry ${i}: FileName is required"
            }

            if (-not $file.RelativePath) {
                $errors += "File entry ${i}: RelativePath is required"
            } else {
                if ($relativePaths -contains $file.RelativePath) {
                    $errors += "File entry ${i}: Duplicate RelativePath: $($file.RelativePath)"
                }
                $relativePaths += $file.RelativePath
            }

            if (-not $file.FullPath) {
                $errors += "File entry ${i}: FullPath is required"
            }

            if (-not $file.Category) {
                $errors += "File entry ${i}: Category is required"
            }

            if (-not $file.Sha256) {
                $errors += "File entry ${i}: Sha256 is required"
            }

            # Validate hash if requested and file exists
            if ($RequireHashValidation -and (Test-Path $file.FullPath)) {
                try {
                    $fileBytes = [System.IO.File]::ReadAllBytes($file.FullPath)
                    $sha256 = [System.Security.Cryptography.SHA256]::Create()
                    $hashBytes = $sha256.ComputeHash($fileBytes)
                    $calculatedHash = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()

                    if ($file.Sha256.ToLower() -ne $calculatedHash.ToLower()) {
                        $errors += "File entry ${i}: Hash mismatch for $($file.FileName). Expected: $($file.Sha256), Calculated: $($calculatedHash)"
                    }
                } catch {
                    $errors += "File entry ${i}: Failed to validate hash for $($file.FileName): $_"
                }
            }

            # Check if file exists
            if (-not (Test-Path $file.FullPath)) {
                $errors += "File entry ${i}: File not found: $($file.FullPath)"
            }
        }

        # Validate summary counts match actual files
        $actualTotal = $Bundle.Files.Count
        if ($Bundle.FileCount -ne $actualTotal) {
            $errors += "FileCount mismatch: expected $actualTotal, got $($Bundle.FileCount)"
        }

        $actualSize = ($Bundle.Files | Measure-Object -Property SizeBytes -Sum).Sum
        if ($Bundle.TotalBytes -ne $actualSize) {
            $errors += "TotalBytes mismatch: expected $actualSize, got $($Bundle.TotalBytes)"
        }

        $result = [pscustomobject]@{
            Passed = $errors.Count -eq 0
            Errors = $errors
        }

        return $result
    } catch {
        return [pscustomobject]@{
            Passed = $false
            Errors = @("Unexpected error during evidence bundle validation: $_")
        }
    }
}