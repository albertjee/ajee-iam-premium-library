param(
    [switch]$ListOnly
)

$ErrorActionPreference = 'Stop'

function Write-ReviewWarning {
    param([Parameter(Mandatory)][string]$Message)
    Write-Warning $Message
}

function Add-ReviewFile {
    param(
        [Parameter(Mandatory)][string]$SourcePath,
        [Parameter(Mandatory)][string]$SourceRoot,
        [Parameter(Mandatory)][string]$StagingRoot
    )

    if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
        return $false
    }

    $relativePath = [System.IO.Path]::GetRelativePath($SourceRoot, $SourcePath)
    $destinationPath = Join-Path $StagingRoot $relativePath
    $destinationParent = Split-Path -Parent $destinationPath
    if ($destinationParent -and -not (Test-Path -LiteralPath $destinationParent -PathType Container)) {
        New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    }

    Copy-Item -LiteralPath $SourcePath -Destination $destinationPath -Force
    $hash = Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256
    $script:ReviewManifest.Add([pscustomobject]@{
        RelativePath = $relativePath
        FullPath = $SourcePath
        Length = (Get-Item -LiteralPath $SourcePath).Length
        SHA256 = $hash.Hash
    }) | Out-Null

    return $true
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$outputRoot = 'C:\temp\iam'
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$bundleName = "rev4x-external-review-$timestamp"
$stagingRoot = Join-Path $outputRoot $bundleName
$zipPath = Join-Path $outputRoot "$bundleName.zip"
$manifestPath = Join-Path $stagingRoot 'file-manifest.json'

New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
New-Item -ItemType Directory -Path $stagingRoot -Force | Out-Null

$script:ReviewManifest = [System.Collections.Generic.List[object]]::new()
$missing = [System.Collections.Generic.List[string]]::new()

$requiredFiles = @(
    'tools\New-Rev4xRun4CExternalReviewPackage.ps1'
    'src\Modules\NhiControlledDecommission.psm1'
    'src\Modules\NhiExecution.psm1'
    'src\Modules\NhiExecutionSchema.psm1'
    'src\Modules\ApprovalManifest.psm1'
    'src\Modules\Utilities.psm1'
    'src\Modules\NhiGovernance.psm1'
    'src\Modules\NhiPermission.psm1'
    'src\Modules\NhiOwner.psm1'
    'src\Modules\NhiCredential.psm1'
    'src\Modules\NhiSignIn.psm1'
    'src\Modules\NhiPublisher.psm1'
    'src\Modules\Discovery.psm1'
    'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    'docs\RUNBOOK-PARAMETERS-AND-OPERATING-MODES.md'
    'config\platform-identity-catalog.json'
    'README-EXTERNAL-AI-REVIEW.md'
)

foreach ($relativePath in $requiredFiles) {
    $sourcePath = Join-Path $repoRoot $relativePath
    if (-not (Add-ReviewFile -SourcePath $sourcePath -SourceRoot $repoRoot -StagingRoot $stagingRoot)) {
        $missing.Add($relativePath) | Out-Null
        Write-ReviewWarning "Missing required file: $relativePath"
    }
}

$reviewTestPattern = '(^|\\).*Rev4(10|1[0-9]|2[0-9]).*\.Tests\.ps1$'
$reviewTests = Get-ChildItem -LiteralPath (Join-Path $repoRoot 'tests') -File | Where-Object { $_.FullName -match $reviewTestPattern }

foreach ($testFile in $reviewTests) {
    if (-not (Add-ReviewFile -SourcePath $testFile.FullName -SourceRoot $repoRoot -StagingRoot $stagingRoot)) {
        $missing.Add(([System.IO.Path]::GetRelativePath($repoRoot, $testFile.FullName))) | Out-Null
    }
}

if ($missing.Count -gt 0) {
    Write-ReviewWarning ('Missing required dependencies: ' + ($missing -join ', '))
    $missingPath = Join-Path $stagingRoot 'missing-dependencies.json'
    ($missing | ConvertTo-Json -Depth 10) | Set-Content -LiteralPath $missingPath -Encoding UTF8
    throw "Required review-package dependencies are missing. See '$missingPath'."
}

$manifestPathParent = Split-Path -Parent $manifestPath
if (-not (Test-Path -LiteralPath $manifestPathParent -PathType Container)) {
    New-Item -ItemType Directory -Path $manifestPathParent -Force | Out-Null
}

$script:ReviewManifest | Sort-Object RelativePath | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

if ($ListOnly) {
    [pscustomobject]@{
        BundleRoot = $stagingRoot
        ZipPath = $zipPath
        FileCount = $script:ReviewManifest.Count
        ManifestPath = $manifestPath
    }
    return
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

Compress-Archive -Path (Join-Path $stagingRoot '*') -DestinationPath $zipPath -Force

[pscustomobject]@{
    BundleRoot = $stagingRoot
    ZipPath = $zipPath
    FileCount = $script:ReviewManifest.Count
    ManifestPath = $manifestPath
}
