function New-DecomOutputManifest {
    <#
    .SYNOPSIS
    Creates a new output manifest object.
    .DESCRIPTION
    Initializes a new output manifest with schema version, tool version, and run metadata.
    .PARAMETER Context
    The run context containing EngagementId, ClientName, ToolVersion, etc.
    .PARAMETER RunId
    The unique run identifier.
    .PARAMETER OutputRoot
    The root directory where outputs are stored.
    .RETURNS
    A PSCustomObject representing the output manifest.
    .EXAMPLE
    $manifest = New-DecomOutputManifest -Context $Context -RunId $runId -OutputRoot $runFolder
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context,

        [Parameter(Mandatory = $true)]
        [string]$RunId,

        [Parameter(Mandatory = $true)]
        [string]$OutputRoot
    )

    $manifest = [ordered]@{
        SchemaVersion   = '3.6'
        ToolVersion     = $Context.ToolVersion
        RunId           = $RunId
        GeneratedUtc    = (Get-Date).ToUniversalTime().ToString('o')
        EngagementId    = $Context.EngagementId
        ClientName      = $Context.ClientName
        OutputRoot      = $OutputRoot
        Files           = @()
        Summary         = [ordered]@{
            TotalFiles        = 0
            TotalSizeBytes    = 0
            PublicFiles       = 0
            ClientSafeFiles   = 0
            ConfidentialFiles = 0
            RestrictedFiles   = 0
        }
    }

    return [pscustomobject]$manifest
}

function Add-DecomOutputManifestItem {
    <#
    .SYNOPSIS
    Adds a file entry to the output manifest.
    .DESCRIPTION
    Adds a file with metadata including hash, sensitivity classification, and safety flags.
    .PARAMETER Manifest
    The output manifest to update.
    .PARAMETER FilePath
    The full path to the file to add.
    .PARAMETER Category
    The file category (Assessment, Findings, Report, etc.).
    .PARAMETER Sensitivity
    The sensitivity level (Public, ClientSafe, Confidential, etc.).
    .PARAMETER Description
    Optional description of the file's purpose.
    .RETURNS
    The updated manifest.
    .EXAMPLE
    $manifest = Add-DecomOutputManifestItem -Manifest $manifest -FilePath $filePath -Category 'Findings' -Sensitivity 'Confidential' -Description 'Assessment findings'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Assessment','Findings','Report','RemediationPlan','WhatIf','ApprovalTemplate','ExecutionEvidence','ExecutionReport','Baseline','ExecutivePack','ReleaseValidation','SchemaContracts','ClientHandoff','Redacted','Demo','Rev35Readiness')]
        [string]$Category,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Public','ClientSafe','Confidential','Restricted','ContainsIdentifiers','ContainsTenantData','ContainsExecutionEvidence')]
        [string]$Sensitivity,

        [string]$Description = ''
    )

    if (-not (Test-Path $FilePath)) {
        Write-Warning "File not found: $FilePath"
        return $Manifest
    }

    try {
        $fileInfo = Get-Item $FilePath
        $fileBytes = [System.IO.File]::ReadAllBytes($FilePath)

        # Calculate SHA-256 hash
        $sha256 = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha256.ComputeHash($fileBytes)
        $hashHex = [System.BitConverter]::ToString($hashBytes).Replace('-', '').ToLower()

        # Determine if safe for client (based on sensitivity)
        $safeForClient = $Sensitivity -in @('Public','ClientSafe')

        $fileId = [guid]::NewGuid().ToString()
        try {
            $resolvedBase = [System.IO.Path]::GetFullPath($Manifest.OutputRoot).TrimEnd('\', '/')
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
            FileId                    = $fileId
            FileName                  = $fileInfo.Name
            RelativePath              = $relativePath
            FullPath                  = $fileInfo.FullName
            FileType                  = $fileInfo.Extension.TrimStart('.')
            Category                  = $Category
            Sensitivity               = $Sensitivity
            ContainsSensitiveData     = $Sensitivity -notin @('Public','ClientSafe')
            SafeForClient             = $safeForClient
            GeneratedUtc              = (Get-Date $fileInfo.LastWriteTimeUtc).ToUniversalTime().ToString('o')
            SizeBytes                 = $fileInfo.Length
            Sha256                    = $hashHex
            SourceStage               = $Category
            RelatedRunId              = $Manifest.RunId
            RelatedWhatIfRunId        = $null
            RelatedApprovalManifestHash = $null
            RelatedExecutionManifestHash = $null
            Description               = $Description
        }

        # Check for duplicate FileId (shouldn't happen with GUID, but validate)
        if ($Manifest.Files.FileId -contains $fileId) {
            throw "Duplicate FileId detected: $fileId"
        }

        $Manifest.Files += [pscustomobject]$fileEntry

        # Update summary
        $Manifest.Summary.TotalFiles++
        $Manifest.Summary.TotalSizeBytes += $fileInfo.Length
        switch ($Sensitivity) {
            'Public' { $Manifest.Summary.PublicFiles++ }
            'ClientSafe' { $Manifest.Summary.ClientSafeFiles++ }
            'Confidential' { $Manifest.Summary.ConfidentialFiles++ }
            'Restricted' { $Manifest.Summary.RestrictedFiles++ }
            default {
                # ContainsIdentifiers, ContainsTenantData, ContainsExecutionEvidence - count as confidential for summary
                $Manifest.Summary.ConfidentialFiles++
            }
        }

        return $Manifest
    } catch {
        Write-Error "Failed to add file to manifest: $($_.Exception.GetType().FullName): $($_.Message)"
        return $Manifest
    }
}

function Export-DecomOutputManifestJson {
    <#
    .SYNOPSIS
    Exports the output manifest to JSON file.
    .DESCRIPTION
    Writes the output manifest as a JSON file to disk.
    .PARAMETER Manifest
    The output manifest to export.
    .PARAMETER Path
    The file path for the JSON output.
    .EXAMPLE
    Export-DecomOutputManifestJson -Manifest $manifest -Path "$runFolder\output-manifest.json"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        $manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $Path -Encoding UTF8
        Write-Verbose "Output manifest exported to $Path"
    } catch {
        Write-Error "Failed to export output manifest JSON: $_"
        throw
    }
}

function Export-DecomOutputManifestCsv {
    <#
    .SYNOPSIS
    Exports the output manifest to CSV file.
    .DESCRIPTION
    Writes the output manifest files array as a CSV file to disk.
    .PARAMETER Manifest
    The output manifest to export.
    .PARAMETER Path
    The file path for the CSV output.
    .EXAMPLE
    Export-DecomOutputManifestCsv -Manifest $manifest -Path "$runFolder\output-manifest.csv"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Manifest,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        if ($Manifest.Files.Count -gt 0) {
            $Manifest.Files | Export-Csv -Path $Path -NoTypeInformation -Encoding UTF8
        } else {
            # Create empty CSV with headers
            $headers = "FileId,FileName,RelativePath,FullPath,FileType,Category,Sensitivity,ContainsSensitiveData,SafeForClient,GeneratedUtc,SizeBytes,Sha256,SourceStage,RelatedRunId,RelatedWhatIfRunId,RelatedApprovalManifestHash,RelatedExecutionManifestHash,Description"
            $headers | Set-Content -Path $Path -Encoding UTF8
        }
        Write-Verbose "Output manifest CSV exported to $Path"
    } catch {
        Write-Error "Failed to export output manifest CSV: $_"
        throw
    }
}

function Test-DecomOutputManifest {
    <#
    .SYNOPSIS
    Tests the output manifest for validity.
    .DESCRIPTION
    Validates the output manifest schema, checks for missing files, duplicate entries, and validates hashes.
    .PARAMETER Manifest
    The output manifest to test.
    .PARAMETER RequireHashValidation
    If $true, validates that file hashes match current file contents.
    .RETURNS
    A PSCustomObject with Passed boolean and Errors array.
    .EXAMPLE
    $result = Test-DecomOutputManifest -Manifest $manifest -RequireHashValidation $true
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Manifest,

        [bool]$RequireHashValidation = $false
    )

    $errors = @()

    try {
        # Check schema version
        if ($Manifest.SchemaVersion -ne '3.6') {
            $errors += "Invalid SchemaVersion: expected '3.6', got '$($Manifest.SchemaVersion)'"
        }

        # Check tool version
        if (-not $Manifest.ToolVersion) {
            $errors += "ToolVersion is required"
        }

        # Check run ID
        if (-not $Manifest.RunId) {
            $errors += "RunId is required"
        }

        # Check generated UTC
        if (-not $Manifest.GeneratedUtc) {
            $errors += "GeneratedUtc is required"
        }

        # Check engagement ID
        if (-not $Manifest.EngagementId) {
            $errors += "EngagementId is required"
        }

        # Check client name
        if (-not $Manifest.ClientName) {
            $errors += "ClientName is required"
        }

        # Check output root
        if (-not $Manifest.OutputRoot) {
            $errors += "OutputRoot is required"
        }

        # Check files array
        if (-not $Manifest.Files) {
            $errors += "Files array is required"
        } elseif ($Manifest.Files -isnot [system.object[]]) {
            $errors += "Files must be an array"
        }

        # Check each file entry
        $fileIds = @()
        $relativePaths = @()

        for ($i = 0; $i -lt $Manifest.Files.Count; $i++) {
            $file = $Manifest.Files[$i]

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

            if (-not $file.FileType) {
                $errors += "File entry ${i}: FileType is required"
            }

            if (-not $file.Category) {
                $errors += "File entry ${i}: Category is required"
            }

            if (-not $file.Sensitivity) {
                $errors += "File entry ${i}: Sensitivity is required"
            }

            if (-not $file.GeneratedUtc) {
                $errors += "File entry ${i}: GeneratedUtc is required"
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

            # Check if file exists (unless it's a known generated file that might not exist yet)
            if (-not (Test-Path $file.FullPath)) {
                $errors += "File entry ${i}: File not found: $($file.FullPath)"
            }
        }

        # Validate summary counts match actual files
        $actualTotal = $Manifest.Files.Count
        if ($Manifest.Summary.TotalFiles -ne $actualTotal) {
            $errors += "Summary.TotalFiles mismatch: expected $actualTotal, got $($Manifest.Summary.TotalFiles)"
        }

        $actualSize = ($Manifest.Files | Measure-Object -Property SizeBytes -Sum).Sum
        if ($Manifest.Summary.TotalSizeBytes -ne $actualSize) {
            $errors += "Summary.TotalSizeBytes mismatch: expected $actualSize, got $($Manifest.Summary.TotalSizeBytes)"
        }

        $actualPublic = ($Manifest.Files | Where-Object { $_.Sensitivity -eq 'Public' }).Count
        if ($Manifest.Summary.PublicFiles -ne $actualPublic) {
            $errors += "Summary.PublicFiles mismatch: expected $actualPublic, got $($Manifest.Summary.PublicFiles)"
        }

        $actualClientSafe = ($Manifest.Files | Where-Object { $_.Sensitivity -eq 'ClientSafe' }).Count
        if ($Manifest.Summary.ClientSafeFiles -ne $actualClientSafe) {
            $errors += "Summary.ClientSafeFiles mismatch: expected $actualClientSafe, got $($Manifest.Summary.ClientSafeFiles)"
        }

        $actualConfidential = ($Manifest.Files | Where-Object { $_.Sensitivity -in @('Confidential','Restricted','ContainsIdentifiers','ContainsTenantData','ContainsExecutionEvidence') }).Count
        if ($Manifest.Summary.ConfidentialFiles -ne $actualConfidential) {
            $errors += "Summary.ConfidentialFiles mismatch: expected $actualConfidential, got $($Manifest.Summary.ConfidentialFiles)"
        }

        $result = [pscustomobject]@{
            Passed = $errors.Count -eq 0
            Errors = $errors
        }

        return $result
    } catch {
        return [pscustomobject]@{
            Passed = $false
            Errors = @("Unexpected error during manifest validation: $_")
        }
    }
}

function Get-DecomOutputFilesForManifest {
    <#
    .SYNOPSIS
    Enumerates files for manifest inclusion with de-duplication.
    .DESCRIPTION
    Safely enumerates output folder files for manifest inclusion, preventing:
    - Duplicate file entries by FullPath
    - Self-recursion (excluding manifest being written)
    - Recursion into temp/redacted folders
    .PARAMETER RunFolder
    Root output folder to enumerate.
    .PARAMETER ExcludeFolders
    Folders to exclude from enumeration (e.g. 'redacted', 'temp').
    .PARAMETER ExcludeFiles
    Files to exclude by FullPath.
    .RETURNS
    Array of file objects sorted by path, deduplicated.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RunFolder,
        [string[]]$ExcludeFolders = @('redacted', 'temp'),
        [string[]]$ExcludeFiles = @()
    )

    $seenPaths = @{}
    $result = @()

    Get-ChildItem -Path $RunFolder -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Extension -in @('.json','.csv','.html','.md') -and
            $_.FullName -notin $ExcludeFiles -and
            -not ($ExcludeFolders | Where-Object { $_.FullName -match "\\$_\\" })
        } |
        ForEach-Object {
            if (-not $seenPaths.ContainsKey($_.FullName)) {
                $seenPaths[$_.FullName] = $true
                $result += $_
            }
        }

    return @($result | Sort-Object FullPath)
}