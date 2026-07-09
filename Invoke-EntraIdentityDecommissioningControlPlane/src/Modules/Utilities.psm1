# Import sub-modules (cascade-free, confirmed 2026-07-09).
# Sub-modules are self-contained (no Import-Module back to Utilities),
# so Import-Module here does not recurse.
Import-Module (Join-Path $PSScriptRoot 'NhiConsole.psm1')    -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'CapabilityState.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'GraphUtility.psm1')   -Force -DisableNameChecking
Import-Module (Join-Path $PSScriptRoot 'NhiFinding.psm1')    -Force -DisableNameChecking

Export-ModuleMember -Function `
    Write-DecomInfo,Write-DecomOk,Write-DecomWarn,Write-DecomError,`
    Reset-DecomRuntimeState,Get-DecomCapabilityState,Test-DecomCapabilityAvailable,Set-DecomCapabilityUnavailable,Test-DecomInteractiveHost,Test-DecomQueryUnavailableResult,Get-DecomQueryResultEntries,New-DecomUnavailableQueryResult,`
    Get-DecomGraphPropertyValue,Get-DecomGraphNestedDisplayName,Get-DecomNormalizedNhiIdentity,Get-DecomToolVersion,Get-DecomTimestamp,Get-DecomTimestampDisplay,`
    New-DecomFinding,Get-DecomFindingTraceContext,Set-DecomFindingTraceContext,Clear-DecomFindingTraceContext,Get-DecomPlatformIdentityCatalogPath,Get-DecomPlatformIdentityCatalog,Test-DecomPlatformIdentityCatalog,Test-DecomMicrosoftPlatformIdentity