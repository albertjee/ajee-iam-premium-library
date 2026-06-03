#Requires -Version 5.1

function Invoke-DecomReleaseValidation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [PSObject]$Context,
        [Parameter(Mandatory = $false)]
        [string]$ToolVersion = 'Rev3.3',
        [Parameter(Mandatory = $false)]
        [string]$EntryPointPath,
        [Parameter(Mandatory = $false)]
        [string]$ModulesPath
    )

    if ($null -eq $Context) {
        $Context = [PSCustomObject]@{
            ToolVersion  = $ToolVersion
            OutputPath   = $null
            ClientName   = 'Validation'
            EngagementId = 'validation'
            Assessor     = 'Validation'
        }
        if ($EntryPointPath) { $Context | Add-Member -NotePropertyName EntryPointPath -NotePropertyValue $EntryPointPath -Force }
        if ($ModulesPath)    { $Context | Add-Member -NotePropertyName ModulesPath    -NotePropertyValue $ModulesPath    -Force }
    }

    $results = [PSCustomObject]@{
        Valid                   = $true
        Passed                  = $true
        Errors                  = @()
        Warnings                = @()
        VersionConsistent       = $true
        SafetyInvariantsOK      = $true
        NoUnexpectedWriteScope  = $true
        NoUnexpectedWriteCmdlet = $true
    }

    try {
        $versionResult = Test-DecomVersionConsistency -Context $Context
        $results.VersionConsistent = $versionResult.Passed
        if (-not $versionResult.Passed) {
            $results.Passed = $false
            $results.Valid  = $false
            foreach ($e in $versionResult.Errors) { $results.Errors += $e }
        }

        $safetyResult = Test-DecomSafetyInvariant -Context $Context
        $results.SafetyInvariantsOK      = $safetyResult.Passed
        $results.NoUnexpectedWriteScope  = $safetyResult.NoUnexpectedWriteScope
        $results.NoUnexpectedWriteCmdlet = $safetyResult.NoUnexpectedWriteCmdlet
        if (-not $safetyResult.Passed) {
            $results.Passed = $false
            $results.Valid  = $false
            foreach ($e in $safetyResult.Errors) { $results.Errors += $e }
        }

        Export-DecomReleaseValidationJson     -Result $results -Context $Context
        Export-DecomReleaseValidationMarkdown -Result $results -Context $Context

    } catch {
        $results.Passed = $false
        $results.Valid  = $false
        $results.Errors += "Unexpected error during release validation: $_"
    }

    return $results
}

function Test-DecomVersionConsistency {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $result = [PSCustomObject]@{
        Passed = $true
        Errors = @()
    }

    # Use explicit path if provided; otherwise auto-detect by walking up from module location
    $epPath = if ($Context.PSObject.Properties['EntryPointPath'] -and $Context.EntryPointPath) {
        $Context.EntryPointPath
    } else {
        $myInvPath = (Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value.MyCommand.Path
        $scriptRoot = if ($myInvPath) { Split-Path -Parent $myInvPath } else { (Get-Location).Path }
        $projectRoot = $scriptRoot
        for ($i = 0; $i -lt 3; $i++) {
            $ep = Join-Path $projectRoot 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            if (Test-Path $ep) { break }
            $projectRoot = Split-Path $projectRoot -Parent
        }
        Join-Path $projectRoot 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    }

    $projectRoot = Split-Path $epPath -Parent

    if (-not (Test-Path $epPath)) {
        $result.Errors += "Cannot locate entry point for version check"
        $result.Passed = $false
        return $result
    }

    $epContent = Get-Content $epPath -Raw

    # Entry point must declare Rev3.5
    if ($epContent -notmatch "\`$script:ToolVersion\s*=\s*'Rev3\.5'") {
        $result.Errors += "Entry point does not declare ToolVersion = Rev3.5"
        $result.Passed = $false
    }

    # Provided ToolVersion must match the current release standard Rev3.5
    $providedVersion = if ($Context.PSObject.Properties['ToolVersion']) { [string]$Context.ToolVersion } else { 'Rev3.5' }
    if ($providedVersion -ne 'Rev3.5') {
        $result.Errors += "Provided ToolVersion '$providedVersion' does not match expected Rev3.5"
        $result.Passed = $false
    }

    # Scan new modules for stale current-version labels in header comments / SchemaVersion strings
    $stalePattern = "SchemaVersion\s*=\s*'2\.[0-9]'"
    $newModules = @('ReleaseValidation','CatalogValidation','SchemaContracts','WriteReadiness','ReleasePackaging')
    foreach ($mod in $newModules) {
        $modPath = Join-Path $projectRoot "src\Modules\$mod.psm1"
        if (Test-Path $modPath) {
            $content = Get-Content $modPath -Raw
            if ($content -match $stalePattern) {
                $result.Errors += "$mod.psm1 contains stale SchemaVersion (should be 3.0 for Rev3.0)"
                $result.Passed = $false
            }
        }
    }

    return $result
}

function Test-DecomSafetyInvariant {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $result = [PSCustomObject]@{
        Passed                  = $true
        Errors                  = @()
        NoUnexpectedWriteScope  = $true
        NoUnexpectedWriteCmdlet = $true
    }

    $myInvPath = (Get-Variable MyInvocation -Scope 1 -ErrorAction SilentlyContinue).Value.MyCommand.Path
    $scriptRoot = if ($myInvPath) { Split-Path -Parent $myInvPath } else { (Get-Location).Path }

    $projectRoot = $scriptRoot
    for ($i = 0; $i -lt 3; $i++) {
        $ep = Join-Path $projectRoot 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'
        if (Test-Path $ep) { break }
        $projectRoot = Split-Path $projectRoot -Parent
    }

    # Modules that must NEVER contain write verbs or ReadWrite scopes
    # WriteReadiness excluded — contains ProposedWriteScope data by design
    # ReleaseValidation excluded — this module contains the forbidden patterns as detection strings
    $readOnlyModules = @(
        'Discovery','Baseline','ExecutivePack',
        'CatalogValidation','SchemaContracts','ReleasePackaging',
        'ApplicationGovernance','CredentialHygiene',
        'ConditionalAccessGovernance','EmergencyAccessGovernance'
    )

    $forbiddenWriteVerbs  = @('Remove-Mg','Update-Mg','Set-Mg','New-Mg','Invoke-MgGraphRequest')
    $forbiddenWriteScopes = @(
        'AccessReview.ReadWrite',
        'EntitlementManagement.ReadWrite',
        'PrivilegedAccess.ReadWrite',
        'Policy.ReadWrite',
        'User.ReadWrite',
        'Application.ReadWrite'
    )

    foreach ($modName in $readOnlyModules) {
        $modPath = Join-Path $projectRoot "src\Modules\$modName.psm1"
        if (-not (Test-Path $modPath)) { continue }
        $content = Get-Content $modPath -Raw

        foreach ($verb in $forbiddenWriteVerbs) {
            if ($content -match [regex]::Escape($verb)) {
                $result.Errors += "$modName.psm1 contains forbidden write verb: $verb"
                $result.Passed = $false
                $result.NoUnexpectedWriteCmdlet = $false
            }
        }

        foreach ($scope in $forbiddenWriteScopes) {
            if ($content -match [regex]::Escape($scope)) {
                $result.Errors += "$modName.psm1 references forbidden write scope: $scope"
                $result.Passed = $false
                $result.NoUnexpectedWriteScope = $false
            }
        }
    }

    # Verify Remediation.psm1 supports only the executable scope for the current ToolVersion
    $remPath = Join-Path $projectRoot 'src\Modules\Remediation.psm1'
    if (Test-Path $remPath) {
        $remContent = Get-Content $remPath -Raw
        $allRemActions = @(
            'RemoveAccessPackageAssignment',
            'RemovePimEligibleAssignment',
            'RemoveGuestGroupMembership',
            'RevokeGuestAppRoleAssignment',
            'AddApplicationOwner',
            'RemoveExpiredCredential',
            'RemoveCAExclusionGroupMember',
            'DeleteOrDisableApp',
            'DeleteServicePrincipal'
        )
        $allowedRemActions = @()
        if ($Context.ToolVersion -eq 'Rev3.0') {
            $allowedRemActions = @('RemoveAccessPackageAssignment','RemovePimEligibleAssignment')
        } elseif ($Context.ToolVersion -eq 'Rev3.1') {
            $allowedRemActions = @('RemoveAccessPackageAssignment','RemovePimEligibleAssignment','RemoveGuestGroupMembership','RevokeGuestAppRoleAssignment')
        } elseif ($Context.ToolVersion -eq 'Rev3.2') {
            $allowedRemActions = @('RemoveAccessPackageAssignment','RemovePimEligibleAssignment','RemoveGuestGroupMembership','RevokeGuestAppRoleAssignment','RemoveExpiredApplicationCredential')
        } elseif ($Context.ToolVersion -in @('Rev3.3','Rev3.4','Rev3.5')) {
            $allowedRemActions = @('RemoveAccessPackageAssignment','RemovePimEligibleAssignment','RemoveGuestGroupMembership','RevokeGuestAppRoleAssignment','RemoveExpiredApplicationCredential','AddApplicationOwner','RemoveCAExclusionGroupMember')
        }
        $forbiddenRemActions = $allRemActions | Where-Object { $_ -notin $allowedRemActions }
        foreach ($action in $forbiddenRemActions) {
            if ($remContent -match [regex]::Escape($action)) {
                $result.Errors += "Remediation.psm1 contains unexpected write action: $action"
                $result.Passed = $false
            }
        }
    }

    return $result
}

function Test-DecomNoUnexpectedWriteScope {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $safetyResult = Test-DecomSafetyInvariant -Context $Context
    return [PSCustomObject]@{
        Passed = $safetyResult.NoUnexpectedWriteScope
        Errors = $safetyResult.Errors | Where-Object { $_ -match 'write scope' }
    }
}

function Test-DecomNoUnexpectedWriteCmdlet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $safetyResult = Test-DecomSafetyInvariant -Context $Context
    return [PSCustomObject]@{
        Passed = $safetyResult.NoUnexpectedWriteCmdlet
        Errors = $safetyResult.Errors | Where-Object { $_ -match 'write verb' }
    }
}

function Export-DecomReleaseValidationJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Result,
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    if (-not $Context.OutputPath) { return }
    if (-not (Test-Path $Context.OutputPath)) {
        New-Item -ItemType Directory -Path $Context.OutputPath -Force | Out-Null
    }

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $JsonPath   = Join-Path $Context.OutputPath "release-validation-report-$Timestamp.json"

    $jsonObject = [PSCustomObject]@{
        SchemaVersion           = '3.0'
        ToolVersion             = $Context.ToolVersion
        GeneratedUtc            = (Get-Date).ToUniversalTime().ToString('o')
        ClientName              = $Context.ClientName
        EngagementId            = $Context.EngagementId
        Assessor                = $Context.Assessor
        Passed                  = $Result.Passed
        VersionConsistent       = $Result.VersionConsistent
        SafetyInvariantsOK      = $Result.SafetyInvariantsOK
        NoUnexpectedWriteScope  = $Result.NoUnexpectedWriteScope
        NoUnexpectedWriteCmdlet = $Result.NoUnexpectedWriteCmdlet
        Errors                  = $Result.Errors
        Warnings                = $Result.Warnings
        Footer                  = '© 2026 Albert Jee. All rights reserved.'
    }

    $json = $jsonObject | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $JsonPath -Encoding UTF8
    Write-DecomOk "Release validation JSON: $JsonPath"
}

function Export-DecomReleaseValidationMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Result,
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    if (-not $Context.OutputPath) { return }
    if (-not (Test-Path $Context.OutputPath)) {
        New-Item -ItemType Directory -Path $Context.OutputPath -Force | Out-Null
    }

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $MdPath     = Join-Path $Context.OutputPath "release-validation-report-$Timestamp.md"

    $passedStr = if ($Result.Passed) { 'PASS' } else { 'FAIL' }

    $markdown = @"
# Release Validation Report

**SchemaVersion:** 3.0
**ToolVersion:** $($Context.ToolVersion)
**GeneratedUtc:** $([DateTime]::UtcNow.ToString('o'))
**Result:** $passedStr

## Checks

| Check | Result |
|---|---|
| Version Consistent | $($Result.VersionConsistent) |
| Safety Invariants OK | $($Result.SafetyInvariantsOK) |
| No Unexpected Write Scope | $($Result.NoUnexpectedWriteScope) |
| No Unexpected Write Cmdlet | $($Result.NoUnexpectedWriteCmdlet) |

"@

    if ($Result.Errors.Count -gt 0) {
        $markdown += "## Errors`n"
        foreach ($e in $Result.Errors) { $markdown += "- $e`n" }
        $markdown += "`n"
    }

    if ($Result.Warnings.Count -gt 0) {
        $markdown += "## Warnings`n"
        foreach ($w in $Result.Warnings) { $markdown += "- $w`n" }
        $markdown += "`n"
    }

    $markdown += @"
---
© 2026 Albert Jee. All rights reserved.
"@

    $markdown | Out-File -FilePath $MdPath -Encoding UTF8
    Write-DecomOk "Release validation Markdown: $MdPath"
}
