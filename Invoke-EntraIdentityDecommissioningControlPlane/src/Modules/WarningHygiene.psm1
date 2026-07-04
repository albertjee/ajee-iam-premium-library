Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

<#
.SYNOPSIS
WarningHygiene module — standardized warning capture and reporting for Entra decommissioning operations.

.DESCRIPTION
Provides structured warning collection, validation, and serialization across hardening/reporting phases.
Ensures failures are recorded rather than silently swallowed, and warnings are visible in manifests/reports.

.NOTES
Rev3.6 — Post-Release Cleanup, Version Hygiene, and Evidence Consistency
No new write scopes. Read-only assessment and validation module.
#>

<#
WARNING COLLECTION AND VALIDATION
#>

function New-DecomWarningCollection {
	<#
	.SYNOPSIS
	Initialize structured warning collection container.

	.DESCRIPTION
	Creates a collection object to capture warnings with Stage, Error, and timestamp metadata.
	#>
	[OutputType([PSCustomObject])]
	param()

	return @{
		Warnings = @()
		StageCounts = @{}
		FailureCount = 0
	}
}

function Add-DecomWarning {
	<#
	.SYNOPSIS
	Append structured warning to collection.

	.DESCRIPTION
	Records a warning with operation stage, error message, and metadata.
	Updates stage counters for manifest summaries.
	#>
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory=$true)]
		[hashtable] $WarningCollection,

		[Parameter(Mandatory=$true)]
		[string] $Stage,

		[Parameter(Mandatory=$true)]
		[string] $Error,

		[Parameter(Mandatory=$false)]
		[object] $AdditionalMetadata
	)

	$warning = [pscustomobject]@{
		Stage = $Stage
		Error = $Error
		Timestamp = (Get-Date -AsUTC).ToString('o')
		Metadata = $AdditionalMetadata
	}

	$WarningCollection.Warnings += $warning

	if (-not $WarningCollection.StageCounts.ContainsKey($Stage)) {
		$WarningCollection.StageCounts[$Stage] = 0
	}
	$WarningCollection.StageCounts[$Stage]++

	$WarningCollection.FailureCount++

	return $warning
}

function Get-DecomWarnings {
	<#
	.SYNOPSIS
	Retrieve all warnings from collection.

	.DESCRIPTION
	Returns warnings array, optionally filtered by stage.
	#>
	[OutputType([PSCustomObject[]])]
	param(
		[Parameter(Mandatory=$true)]
		[hashtable] $WarningCollection,

		[Parameter(Mandatory=$false)]
		[string] $Stage
	)

	if ($Stage) {
		return $WarningCollection.Warnings | Where-Object { $_.Stage -eq $Stage }
	}

	return $WarningCollection.Warnings
}

function Test-DecomWarningCollection {
	<#
	.SYNOPSIS
	Validate warning collection state.

	.DESCRIPTION
	Returns true if collection is empty (no failures), false otherwise.
	#>
	[OutputType([bool])]
	param(
		[Parameter(Mandatory=$true)]
		[hashtable] $WarningCollection
	)

	return $WarningCollection.FailureCount -eq 0
}

function ConvertTo-DecomWarningManifest {
	<#
	.SYNOPSIS
	Serialize warning collection for manifest output.

	.DESCRIPTION
	Converts warning collection to JSON-serializable manifest object.
	Suitable for OutputManifest, EvidenceBundle, ClientHandoff sections.
	#>
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory=$true)]
		[hashtable] $WarningCollection,

		[Parameter(Mandatory=$false)]
		[string] $SectionName = 'Warnings'
	)

	return [pscustomobject]@{
		Section = $SectionName
		FailureCount = $WarningCollection.FailureCount
		StageCounts = $WarningCollection.StageCounts
		Warnings = @($WarningCollection.Warnings | ForEach-Object {
			[pscustomobject]@{
				Stage = $_.Stage
				Error = $_.Error
				Timestamp = $_.Timestamp
			}
		})
	}
}

<#
HARDENING OPERATION WRAPPERS
#>

function Invoke-DecomHardeningOperation {
	<#
	.SYNOPSIS
	Execute best-effort hardening operation with structured error capture.

	.DESCRIPTION
	Runs a scriptblock, captures failures to warning collection, and logs via Write-DecomWarn.
	Does not re-throw — failures are recorded, not fatal.
	#>
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory=$true)]
		[scriptblock] $Operation,

		[Parameter(Mandatory=$true)]
		[hashtable] $WarningCollection,

		[Parameter(Mandatory=$true)]
		[string] $OperationName,

		[Parameter(Mandatory=$false)]
		[object] $Metadata
	)

	try {
		$result = @(& $Operation)
		return [pscustomobject]@{
			Success = $true
			Result = $result
			Error = $null
		}
	}
	catch {
		$errorMsg = $_.Exception.Message
		Write-DecomWarn "Hardening operation '$OperationName' failed: $errorMsg"

		Add-DecomWarning -WarningCollection $WarningCollection `
			-Stage $OperationName `
			-Error $errorMsg `
			-AdditionalMetadata $Metadata | Out-Null

		return [pscustomobject]@{
			Success = $false
			Result = $null
			Error = $errorMsg
		}
	}
}

<#
VALIDATION HELPERS
#>

function Test-DecomSilentCatchBlocks {
	<#
	.SYNOPSIS
	Scan production module for silent catch blocks.

	.DESCRIPTION
	Validates that catch blocks contain explicit error handling (Write-DecomWarn, variable assignment).
	Reports on modules that have uncaught error conditions.

	Returns hashtable with ModulePath, HasSilentCatches, SilentCatchLines.
	#>
	[OutputType([hashtable])]
	param(
		[Parameter(Mandatory=$true)]
		[string] $ModulePath
	)

	if (-not (Test-Path $ModulePath)) {
		return @{
			ModulePath = $ModulePath
			Exists = $false
			HasSilentCatches = $null
			Error = "Module not found"
		}
	}

	$content = Get-Content $ModulePath -Raw
	$tokens = $null
	$errors = $null

	[System.Management.Automation.Language.Parser]::ParseFile(
		$ModulePath, [ref]$tokens, [ref]$errors) | Out-Null

	if ($errors -and $errors.Count -gt 0) {
		return @{
			ModulePath = $ModulePath
			Exists = $true
			HasSilentCatches = $null
			Error = "Parse error: $($errors[0].Message)"
		}
	}

	$catchMatches = [regex]::Matches(
		$content,
		'catch\s*\{\s*\}',
		[System.Text.RegularExpressions.RegexOptions]::IgnoreCase
	)

	$hasSilent = $catchMatches.Count -gt 0

	$silentLines = @()
	if ($hasSilent) {
		$lines = $content -split "`n"
		$pos = 0
		foreach ($match in $catchMatches) {
			$charPos = $match.Index
			$lineNum = 1
			for ($i = 0; $i -lt $charPos; $i++) {
				if ($content[$i] -eq "`n") { $lineNum++ }
			}
			$silentLines += $lineNum
		}
	}

	return @{
		ModulePath = $ModulePath
		Exists = $true
		HasSilentCatches = $hasSilent
		SilentCatchCount = $catchMatches.Count
		SilentCatchLines = $silentLines
		Error = $null
	}
}

function Test-DecomWarningHygiene {
	<#
	.SYNOPSIS
	Validate warning hygiene across production modules.

	.DESCRIPTION
	Scans production modules and test harness for silent catch blocks.
	Returns summary of modules with hygiene violations.
	#>
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory=$false)]
		[string[]] $ModulePaths = @()
	)

	if ($ModulePaths.Count -eq 0) {
		$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
		$ModulePaths = @(Get-ChildItem "$repoRoot\src\Modules" -Filter '*.psm1' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
		$ModulePaths += @(Get-ChildItem "$repoRoot" -Filter 'Invoke-*.ps1' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
	}

	$results = @()
	$violationCount = 0

	foreach ($path in $ModulePaths) {
		$scanResult = Test-DecomSilentCatchBlocks -ModulePath $path

		if ($scanResult.HasSilentCatches) {
			$violationCount++
			Write-DecomWarn "Silent catch blocks detected in $(Split-Path -Leaf $path) at lines: $($scanResult.SilentCatchLines -join ', ')"
		}

		$results += $scanResult
	}

	return [pscustomobject]@{
		ModuleCount = $ModulePaths.Count
		ViolationCount = $violationCount
		Results = $results
		HasViolations = $violationCount -gt 0
	}
}

Export-ModuleMember -Function @(
	'New-DecomWarningCollection'
	'Add-DecomWarning'
	'Get-DecomWarnings'
	'Test-DecomWarningCollection'
	'ConvertTo-DecomWarningManifest'
	'Invoke-DecomHardeningOperation'
	'Test-DecomSilentCatchBlocks'
	'Test-DecomWarningHygiene'
)
