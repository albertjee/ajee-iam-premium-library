#Requires -Version 5.1

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

<#
.SYNOPSIS
HtmlEncoding module — standardized HTML entity encoding for dynamic report values.

.DESCRIPTION
Provides HTML encoding functions to prevent XSS vulnerabilities and ensure proper rendering
of dynamic values in HTML reports. Encodes angle brackets, quotes, ampersands, and other
special characters that could break HTML structure or be interpreted as code.

.NOTES
Rev3.6 — Post-Release Cleanup, Version Hygiene, and Evidence Consistency
No new write scopes. Read-only encoding utility module.
#>

<#
HTML ENCODING CORE
#>

function ConvertTo-DecomHtmlEncoded {
	<#
	.SYNOPSIS
	Encode string for safe HTML output.

	.DESCRIPTION
	Encodes special HTML characters to prevent XSS vulnerabilities and ensure
	proper rendering in HTML reports. Handles: < > " ' &

	Returns the encoded string suitable for use in HTML attributes and text content.
	#>
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[string] $InputString,

		[Parameter(Mandatory=$false)]
		[switch] $EncodeQuotes
	)

	if ([string]::IsNullOrEmpty($InputString)) {
		return $InputString
	}

	$encoded = $InputString
	$encoded = $encoded.Replace('&', '&amp;')
	$encoded = $encoded.Replace('<', '&lt;')
	$encoded = $encoded.Replace('>', '&gt;')
	$encoded = $encoded.Replace('"', '&quot;')

	if ($EncodeQuotes) {
		$encoded = $encoded.Replace("'", '&#39;')
	}

	return $encoded
}

function ConvertTo-DecomHtmlText {
	<#
	.SYNOPSIS
	Encode string for HTML body text (not attributes).

	.DESCRIPTION
	Similar to ConvertTo-DecomHtmlEncoded but optimized for text content rather than attributes.
	Encodes angle brackets and ampersands only — preserves single/double quotes for readability.
	#>
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[string] $InputString
	)

	if ([string]::IsNullOrEmpty($InputString)) {
		return $InputString
	}

	$encoded = $InputString
	$encoded = $encoded.Replace('&', '&amp;')
	$encoded = $encoded.Replace('<', '&lt;')
	$encoded = $encoded.Replace('>', '&gt;')

	return $encoded
}

function ConvertTo-DecomHtmlAttribute {
	<#
	.SYNOPSIS
	Encode string for use in HTML attributes.

	.DESCRIPTION
	Encodes all special characters including quotes for safe use in HTML attributes.
	Always encodes single quotes, double quotes, and ampersands.
	#>
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[string] $InputString
	)

	if ([string]::IsNullOrEmpty($InputString)) {
		return $InputString
	}

	$encoded = $InputString
	$encoded = $encoded.Replace('&', '&amp;')
	$encoded = $encoded.Replace('"', '&quot;')
	$encoded = $encoded.Replace("'", '&#39;')
	$encoded = $encoded.Replace('<', '&lt;')
	$encoded = $encoded.Replace('>', '&gt;')

	return $encoded
}

function ConvertTo-DecomHtmlCdata {
	<#
	.SYNOPSIS
	Wrap string in CDATA section for JavaScript/CSS content.

	.DESCRIPTION
	Escapes content for use within <![CDATA[...]]> blocks in XHTML/XML contexts.
	Prevents breaking out of CDATA sections.
	#>
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline=$true)]
		[string] $InputString
	)

	if ([string]::IsNullOrEmpty($InputString)) {
		return $InputString
	}

	$escaped = $InputString.Replace(']]>', ']]&gt;')
	return $escaped
}

<#
VALIDATION HELPERS
#>

function Test-DecomHtmlEncoding {
	<#
	.SYNOPSIS
	Validate that dynamic values in content are properly encoded.

	.DESCRIPTION
	Scans text content for unencoded special characters that could indicate XSS vulnerabilities.
	Returns summary of potential encoding issues found.

	Note: This is a heuristic check and may have false positives/negatives. It's designed
	to catch obvious encoding mistakes, not perform comprehensive security analysis.
	#>
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory=$true)]
		[string] $Content,

		[Parameter(Mandatory=$false)]
		[string[]] $DynamicFieldNames = @('DisplayName', 'UserPrincipalName', 'Evidence', 'Error', 'Message')
	)

	$issues = @()
	$riskLevel = 'None'

	$suspiciousPatterns = @(
		@{ Pattern = '<script'; Name = 'Script tag'; Severity = 'Critical' }
		@{ Pattern = 'javascript:'; Name = 'JavaScript protocol'; Severity = 'Critical' }
		@{ Pattern = 'onerror='; Name = 'Event handler (onerror)'; Severity = 'High' }
		@{ Pattern = 'onclick='; Name = 'Event handler (onclick)'; Severity = 'High' }
		@{ Pattern = 'onload='; Name = 'Event handler (onload)'; Severity = 'High' }
		@{ Pattern = '<iframe'; Name = 'IFrame tag'; Severity = 'High' }
		@{ Pattern = '<object'; Name = 'Object tag'; Severity = 'High' }
		@{ Pattern = '<embed'; Name = 'Embed tag'; Severity = 'High' }
	)

	foreach ($pattern in $suspiciousPatterns) {
		if ($Content -like "*$($pattern.Pattern)*") {
			$issues += [pscustomobject]@{
				Pattern = $pattern.Pattern
				Name = $pattern.Name
				Severity = $pattern.Severity
			}
			if ($pattern.Severity -eq 'Critical') {
				$riskLevel = 'Critical'
			}
			elseif ($pattern.Severity -eq 'High' -and $riskLevel -ne 'Critical') {
				$riskLevel = 'High'
			}
		}
	}

	return [pscustomobject]@{
		RiskLevel = $riskLevel
		IssueCount = $issues.Count
		Issues = $issues
		IsClean = $issues.Count -eq 0
	}
}

function Test-DecomHtmlEncodingConsistency {
	<#
	.SYNOPSIS
	Validate that HTML-generating functions use proper encoding helpers.

	.DESCRIPTION
	Scans a module or script for unencoded variable substitutions in HTML contexts.
	Looks for patterns where variables are directly inserted into HTML without encoding.

	Returns summary of modules with potential encoding consistency issues.
	#>
	[OutputType([PSCustomObject])]
	param(
		[Parameter(Mandatory=$false)]
		[string[]] $ModulePaths = @()
	)

	if ($ModulePaths.Count -eq 0) {
		$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
		$ModulePaths = @(Get-ChildItem "$repoRoot\src\Modules" -Filter '*Report*.psm1' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
	}

	$results = @()
	$violationCount = 0

	foreach ($path in $ModulePaths) {
		if (-not (Test-Path $path)) {
			continue
		}

		$content = Get-Content $path -Raw
		$tokens = $null
		$errors = $null

		[System.Management.Automation.Language.Parser]::ParseFile(
			$path, [ref]$tokens, [ref]$errors) | Out-Null

		if ($errors -and $errors.Count -gt 0) {
			continue
		}

		$unencoded = [regex]::Matches(
			$content,
			'\$\w+\s*-replace\s*"<|\$\w+\s*\+\s*"<|"<[^>]*"\s*\+\s*\$\w+',
			[System.Text.RegularExpressions.RegexOptions]::IgnoreCase
		)

		if ($unencoded.Count -gt 0) {
			$violationCount++
		}

		$results += [pscustomobject]@{
			Module = Split-Path -Leaf $path
			Path = $path
			UnencodedCount = $unencoded.Count
			HasIssues = $unencoded.Count -gt 0
		}
	}

	return [pscustomobject]@{
		ModuleCount = $ModulePaths.Count
		ViolationCount = $violationCount
		Results = $results
		HasViolations = $violationCount -gt 0
	}
}

Export-ModuleMember -Function @(
	'ConvertTo-DecomHtmlEncoded'
	'ConvertTo-DecomHtmlText'
	'ConvertTo-DecomHtmlAttribute'
	'ConvertTo-DecomHtmlCdata'
	'Test-DecomHtmlEncoding'
	'Test-DecomHtmlEncodingConsistency'
)
