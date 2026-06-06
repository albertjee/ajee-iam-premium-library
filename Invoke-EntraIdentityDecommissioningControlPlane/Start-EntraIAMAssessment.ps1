<#
.SYNOPSIS
    Preset-driven launcher for the Entra IAM Control Plane.

.DESCRIPTION
    Start-EntraIAMAssessment provides named run-mode shortcuts that map to
    validated parameter sets for Invoke-EntraIdentityDecommissioningControlPlane.

    Available modes:
      QuickNHI           - runs Assessment targeting Named Identity (NHI) objects only
      FullAssessment     - Assessment + NHI governance pack + executive summary pack
      DemoMode           - FullAssessment with synthetic demo data, no Graph connection required
      WhatIfRemediation  - generates a What-If remediation plan without executing changes

    The script is safe to dot-source (no-op, returns immediately).

.EXAMPLE
    Start-EntraIAMAssessment -Mode QuickNHI
    Runs a lightweight assessment targeting Named Identity objects.

.EXAMPLE
    Start-EntraIAMAssessment -Mode FullAssessment -TenantId 'contoso.onmicrosoft.com'
    Runs a full assessment with NHI governance and executive pack against the specified tenant.

.EXAMPLE
    Start-EntraIAMAssessment -Mode DemoMode
    Runs DemoMode using synthetic data - no tenant connection required.

.EXAMPLE
    Start-EntraIAMAssessment -Mode WhatIfRemediation -TenantId 'contoso.onmicrosoft.com' -OutputPath '.\out'
    Generates a What-If remediation plan and saves output to the specified directory.

.LINK
    Invoke-EntraIdentityDecommissioningControlPlane
#>

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateSet('QuickNHI', 'FullAssessment', 'DemoMode', 'WhatIfRemediation')]
    [string]$Mode,

    [string]$TenantId,
    [string]$ClientId,
    [string]$EngagementId,
    [string]$ClientName,
    [string]$Assessor,
    [string]$OutputPath = '.\out',
    [switch]$NonInteractive,
    [switch]$NoLogo
)

# Dot-source safety: return immediately if sourced
$ErrorActionPreference = 'Stop'

if ($MyInvocation.InvocationName -eq '.') {
    return
}

# Runtime validation: -Mode is required when executing
if (-not $Mode) {
    throw "Mode is required. Valid values: QuickNHI, FullAssessment, DemoMode, WhatIfRemediation."
}

# Preset mapping: wrapper -Mode -> main tool parameters
switch ($Mode) {
    'QuickNHI' {
        $mainMode = 'Assessment'
    }
    'FullAssessment' {
        $mainMode = 'Assessment'
        $GenerateNhiGovernancePack = $true
        $GenerateExecutivePack     = $true
    }
    'DemoMode' {
        $mainMode                  = 'Assessment'
        $DemoMode                  = $true
        $GenerateNhiGovernancePack = $true
        $GenerateExecutivePack     = $true
    }
    'WhatIfRemediation' {
        $mainMode = 'WhatIfRemediation'
    }
}

# Build the splat table for the main entry point
$entryPoint = Join-Path $PSScriptRoot 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'

$splat = @{
    Mode      = $mainMode
    OutputPath = $OutputPath
}

if ($TenantId)      { $splat['TenantId']      = $TenantId }
if ($ClientId)      { $splat['ClientId']       = $ClientId }
if ($EngagementId)  { $splat['EngagementId']   = $EngagementId }
if ($ClientName)    { $splat['ClientName']      = $ClientName }
if ($Assessor)      { $splat['Assessor']        = $Assessor }
if ($NonInteractive){ $splat['NonInteractive']  = $true }
if ($NoLogo)        { $splat['NoLogo']          = $true }

# Add switches only when explicitly set by preset
if ($DemoMode)                  { $splat['DemoMode']                    = $true }
if ($GenerateNhiGovernancePack) { $splat['GenerateNhiGovernancePack']   = $true }
if ($GenerateExecutivePack)     { $splat['GenerateExecutivePack']        = $true }

$target = "Invoke-EntraIdentityDecommissioningControlPlane.ps1 Mode=$mainMode"

if ($PSCmdlet.ShouldProcess($target, 'Start Entra IAM assessment')) {
    & $entryPoint @splat
}
