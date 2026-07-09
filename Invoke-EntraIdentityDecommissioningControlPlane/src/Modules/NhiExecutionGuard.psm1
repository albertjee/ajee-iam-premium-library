#Requires -Version 5.1
# ══════════════════════════════════════════════════════════════════════════════
# NhiExecutionGuard.psm1 — Rev4.1 M1
# Destructive cmdlet guard + testable AST scanner
#
# Blocked cmdlet list is defined ONCE in $Script:NhiBlockedCmdlets and shared
# by both detection paths:
#   - Raw-string scanner  (Test-NhiExecutionModuleClean)  — 10 runtime items
#   - CommandAst scanner  (Get-FileCommandNames)          — all 12 items
#
# Exports:
#   Test-NhiExecutionModuleClean   — primary guard, throws on first violation
#   Get-FileCommandNames           — AST scanner, returns FileCommandSet instance
#
# IMPORTANT: Get-FileCommandNames returns [FileCommandSet] (class instance), NOT
# a bare HashSet.  HashSet implements IEnumerable — the PowerShell pipeline
# unrolls it on return ($null for empty, individual chars for non-empty).
# FileCommandSet bundles the HashSet without triggering that unroll.
#
# API:
#   $r.Data       — inner HashSet (for callers that need to iterate)
#   $r.ItemCount  — int item count (method call, avoids property name shadowing)
#   $r.Contains($name) — bool O(1) lookup (method call)
#   $r.Raw()      — returns HashSet as [object[]] (stops pipeline unroll)
# ══════════════════════════════════════════════════════════════════════════════

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

# ----------------------------------------------------------------------
# FileCommandSet — wrapper class for AST scan results
# ----------------------------------------------------------------------
# Using a named class (not PSCustomObject) so that:
#   $r.Count    — calls get_Count() (returns HashSet.Count = item count, int)
#   $r.Contains($name) — calls Contains(string) method on the inner HashSet
#   $r.Data     — returns the inner HashSet for callers that need it
#
# Field is named _Data (underscore) to prevent shadowing with the get_Count()
# getter — PowerShell property lookup finds _Data.Count before HashSet.Count,
# so the getter is invoked correctly (not: $r.Data.Count returns HashSet.Count).
# ----------------------------------------------------------------------
class FileCommandSet {
    [System.Collections.Generic.HashSet[string]] $_Data

    FileCommandSet([System.Collections.Generic.IEnumerable[string]] $Items) {
        $this._Data = [System.Collections.Generic.HashSet[string]]::new(
            [System.StringComparer]::OrdinalIgnoreCase)
        foreach ($item in $Items) {
            [void]$this._Data.Add($item)
        }
    }

    # Expose inner HashSet as [object[]] so it does not get enumerated
    # by PowerShell's pipeline (empty HashSet → empty stream → $null without this).
    [object[]] Raw() {
        $arr = [object[]]::new($this._Data.Count)
        $this._Data.CopyTo($arr, 0)
        return $arr
    }

    # Total command names in the file; 0 means file has no CommandAst nodes.
    [int] ItemCount() { return $this._Data.Count }

    # O(1) lookup: does the named command appear in the source file?
    [bool] Contains([string] $Name) { return $this._Data.Contains($Name) }
}

# ----------------------------------------------------------------------
# BLOCKED CMDLET LIST — single source of truth, used by both scanners
# ----------------------------------------------------------------------
$Script:NhiBlockedCmdlets = @(
    'Remove-MgServicePrincipal'
    'Remove-MgApplication'
    'Remove-MgApplicationPassword'
    'Remove-MgApplicationKey'
    'Remove-MgServicePrincipalPassword'
    'Remove-MgServicePrincipalKey'
    'Remove-MgServicePrincipalAppRoleAssignment'
    'Remove-MgOauth2PermissionGrant'
    'Remove-MgServicePrincipalOwnerByRef'
    'Remove-MgServicePrincipalOwnerDirectoryObjectByRef'
    'HardDeleteServicePrincipal'
    'Remove-MgServicePrincipalByAppId'
)

# ----------------------------------------------------------------------
# Test-NhiExecutionModuleClean
# ----------------------------------------------------------------------
function Test-NhiExecutionModuleClean {
    <#
    .SYNOPSIS
        Scans one or more module files for blocked cmdlet names and halts execution on first match.

    .DESCRIPTION
        Reads each file in ModulePaths as a raw string and uses [regex]::Escape() then
        -match to detect any of the blocked cmdlet names.  Throws a Write-DecomError
        security-stop message on first violation; returns $null if all files are clean.

        Files that do not exist are silently skipped (guard targets only existing code).

    .PARAMETER ModulePaths
        One or more absolute or relative file paths to scan.

    .OUTPUTS
        $null — when no blocked cmdlets are detected.
        Throws [System.Management.Automation.ErrorRecord] on first violation.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string[]]
        $ModulePaths
    )

    process {
        foreach ($modPath in $ModulePaths) {
            if (-not (Test-Path $modPath)) { continue }

            $modContent = Get-Content -Path $modPath -Raw

            foreach ($blocked in $Script:NhiBlockedCmdlets) {
                $escaped = [regex]::Escape($blocked)
                if ($modContent -match $escaped) {
                    $msg = "[SECURITY STOP] Blocked cmdlet '$blocked' found in '$modPath'. " +
                           'Execution halted.  If the reference is legitimate ' +
                           '(e.g. Read-only Get, Confirm-, or WhatIf helpers), ' +
                           'move the call into a dot-sourced companion that ' +
                           'NhiExecutionFlow.ps1 does not scan.'
                    Write-DecomError $msg
                    throw "Blocked cmdlet detected: $blocked"
                }
            }
        }
    }
}

# ----------------------------------------------------------------------
# Get-FileCommandNames
# ----------------------------------------------------------------------
function Get-FileCommandNames {
    <#
    .SYNOPSIS
        Returns all real command-invocation names from a PowerShell source file via AST scan.

    .DESCRIPTION
        Parses the file with Parser::ParseInput and extracts CommandAst nodes.
        CommandAst captures ONLY real invocations — not hashtable keys, string
        literals, or comment strings.  Returns a [FileCommandSet] instance
        (class defined at module scope) so the caller gets a stable object
        with .Count and .Contains(..) without any IEnumerable unrolling.

    .PARAMETER Path
        Absolute or relative path to the .ps1 / .psm1 file to scan.

    .PARAMETER Recurse
        Pass $true (default) to scan all descendant ScriptBlockAst nodes via FindAll.
        Pass $false to scan only the top-level statement block.

    .OUTPUTS
        [FileCommandSet] — wraps the HashSet of cmdlet / function / script names
        found in the file.  Returns an empty set (not $null) if the file has parse
        errors or contains no command invocations.
    #>
    [CmdletBinding()]
    [OutputType([FileCommandSet])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0)]
        [string]
        $Path,

        [Parameter(Position = 1)]
        [bool]
        $Recurse = $true
    )

    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile(
        $Path, [ref]$null, [ref]$parseErrors)
    # Return empty FileCommandSet for files with parse errors or empty/space-only input.
    if ($null -eq $ast -or ($parseErrors -and $parseErrors.Count -gt 0)) {
        return [FileCommandSet]::new(
            [System.Collections.Generic.HashSet[string]]::new(
                [System.StringComparer]::OrdinalIgnoreCase))
    }

    $cmdAsts = $ast.FindAll(
        {
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst]
        },
        $Recurse
    )

    $cmdNames = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)

    foreach ($cmd in $cmdAsts) {
        $name = $cmd.GetCommandName()
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        if ($name -match '^[\w-]+$') {
            [void]$cmdNames.Add($name)
        }
    }

    return [FileCommandSet]::new($cmdNames)
}

Export-ModuleMember -Function Test-NhiExecutionModuleClean, Get-FileCommandNames