#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [switch]$ConfirmLabCreation,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\out\rev437-lab\rev437-synthetic-nhi-lab-inventory.json')
)

$ErrorActionPreference = 'Stop'

function Get-Rev437RequiredLabDefinitions {
    @(
        [pscustomobject]@{
            DisplayName    = 'AJEE-LAB-NHI-KEEP-CONTROL'
            Purpose        = 'Never touched; proves no collateral impact.'
            TargetType     = 'ServicePrincipal'
            SafeToDisable  = $false
            SafeToRollback = $false
            ControlObject  = $true
            CreateApplication = $true
            CreateServicePrincipal = $true
            Description    = 'Rev4.37 control object. Do not disable, mark, or delete.'
        }
        [pscustomobject]@{
            DisplayName    = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
            Purpose        = 'Primary reversible disable and rollback target.'
            TargetType     = 'ServicePrincipal'
            SafeToDisable  = $true
            SafeToRollback = $true
            ControlObject  = $false
            CreateApplication = $true
            CreateServicePrincipal = $true
            Description    = 'Rev4.37 reversible disable and rollback target.'
        }
        [pscustomobject]@{
            DisplayName    = 'AJEE-LAB-NHI-MARK-ONLY'
            Purpose        = 'Mark/tag/evidence-only candidate.'
            TargetType     = 'ServicePrincipal'
            SafeToDisable  = $false
            SafeToRollback = $false
            ControlObject  = $false
            CreateApplication = $true
            CreateServicePrincipal = $true
            Description    = 'Rev4.37 mark/tag evidence-only candidate.'
        }
        [pscustomobject]@{
            DisplayName    = 'AJEE-LAB-NHI-NO-OWNER'
            Purpose        = 'Owner-risk detection.'
            TargetType     = 'ServicePrincipal'
            SafeToDisable  = $false
            SafeToRollback = $false
            ControlObject  = $false
            CreateApplication = $true
            CreateServicePrincipal = $true
            Description    = 'Rev4.37 owner-risk detection candidate.'
        }
        [pscustomobject]@{
            DisplayName    = 'AJEE-LAB-NHI-EXPIRED-CRED'
            Purpose        = 'Expired credential evidence.'
            TargetType     = 'ServicePrincipal'
            SafeToDisable  = $false
            SafeToRollback = $false
            ControlObject  = $false
            CreateApplication = $true
            CreateServicePrincipal = $true
            Description    = 'Rev4.37 expired credential evidence candidate.'
        }
        [pscustomobject]@{
            DisplayName    = 'AJEE-LAB-NHI-ACTIVE-CRED'
            Purpose        = 'Active credential safety case.'
            TargetType     = 'ServicePrincipal'
            SafeToDisable  = $false
            SafeToRollback = $false
            ControlObject  = $false
            CreateApplication = $true
            CreateServicePrincipal = $true
            Description    = 'Rev4.37 active credential safety case candidate.'
        }
    )
}

function Test-Rev437SyntheticNhiLabName {
    param([Parameter(Mandatory)][string]$DisplayName)

    return $DisplayName -like 'AJEE-LAB-NHI-*'
}

function Assert-Rev437SyntheticNhiLabDefinition {
    param([Parameter(Mandatory)][object]$Definition)

    if (-not (Test-Rev437SyntheticNhiLabName -DisplayName $Definition.DisplayName)) {
        throw "DisplayName '$($Definition.DisplayName)' must start with AJEE-LAB-NHI-."
    }

    if ([string]::IsNullOrWhiteSpace([string]$Definition.Purpose)) {
        throw "DisplayName '$($Definition.DisplayName)' is missing Purpose."
    }

    if ([string]::IsNullOrWhiteSpace([string]$Definition.TargetType)) {
        throw "DisplayName '$($Definition.DisplayName)' is missing TargetType."
    }
}

function Get-Rev437GraphApplicationByDisplayName {
    param([Parameter(Mandatory)][string]$DisplayName)

    $escaped = $DisplayName.Replace("'", "''")
    @(Get-MgApplication -Filter "displayName eq '$escaped'" -All -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -eq $DisplayName })
}

function Get-Rev437GraphServicePrincipalByAppId {
    param([Parameter(Mandatory)][string]$AppId)

    @(Get-MgServicePrincipal -Filter "appId eq '$AppId'" -All -ErrorAction SilentlyContinue | Where-Object { $_.AppId -eq $AppId })
}

function Get-Rev437InventoryRecord {
    param(
        [Parameter(Mandatory)][object]$Definition,
        [Parameter(Mandatory)][object]$Application,
        [Parameter(Mandatory)][object]$ServicePrincipal,
        [Parameter(Mandatory)][string]$TenantId
    )

    [pscustomobject]@{
        DisplayName            = $Definition.DisplayName
        AppId                  = [string]$Application.AppId
        ApplicationObjectId    = [string]$Application.Id
        ServicePrincipalObjectId = [string]$ServicePrincipal.Id
        TargetType             = [string]$Definition.TargetType
        Purpose                = [string]$Definition.Purpose
        CreatedAt              = [DateTime]::UtcNow.ToString('o')
        TenantId               = $TenantId
        SafeToDisable          = [bool]$Definition.SafeToDisable
        SafeToRollback         = [bool]$Definition.SafeToRollback
        ControlObject          = [bool]$Definition.ControlObject
    }
}

function Export-Rev437SyntheticNhiLabInventory {
    param(
        [Parameter(Mandatory)][object[]]$Inventory,
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$OutputPath
    )

    $payload = [pscustomobject]@{
        SchemaVersion = '1.0'
        CreatedAt     = [DateTime]::UtcNow.ToString('o')
        TenantId      = $TenantId
        Inventory     = @($Inventory)
    }

    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $payload | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding utf8
    return $payload
}

function Invoke-Rev437SyntheticNhiLabCreation {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$OutputPath,
        [switch]$ConfirmLabCreation
    )

    if (-not $ConfirmLabCreation) {
        throw 'ConfirmLabCreation is required before any lab object creation is attempted.'
    }

    $definitions = @(Get-Rev437RequiredLabDefinitions)
    foreach ($definition in $definitions) {
        Assert-Rev437SyntheticNhiLabDefinition -Definition $definition
    }

    if ($WhatIfPreference) {
        $dryRunInventory = foreach ($definition in $definitions) {
            [pscustomobject]@{
                DisplayName             = $definition.DisplayName
                AppId                   = $null
                ApplicationObjectId     = $null
                ServicePrincipalObjectId = $null
                TargetType              = [string]$definition.TargetType
                Purpose                 = [string]$definition.Purpose
                CreatedAt               = $null
                TenantId                = $TenantId
                SafeToDisable           = [bool]$definition.SafeToDisable
                SafeToRollback          = [bool]$definition.SafeToRollback
                ControlObject           = [bool]$definition.ControlObject
                WhatIf                  = $true
            }
        }

        return [pscustomobject]@{
            TenantId               = $TenantId
            OutputPath             = $OutputPath
            WhatIf                 = $true
            InventoryExported      = $false
            LiveIdsAvailable       = $false
            ObjectCount            = @($dryRunInventory).Count
            Inventory              = @($dryRunInventory)
            InventoryFile          = $null
            Message                = 'WhatIf dry-run only. Live IDs are available after running without -WhatIf.'
        }
    }

    if (-not (Get-Command Get-MgApplication -ErrorAction SilentlyContinue) -or
        -not (Get-Command Get-MgServicePrincipal -ErrorAction SilentlyContinue)) {
        throw 'Microsoft Graph PowerShell cmdlets are required for lab object creation.'
    }

    $inventory = [System.Collections.Generic.List[object]]::new()

    foreach ($definition in $definitions) {
        $applications = @(Get-Rev437GraphApplicationByDisplayName -DisplayName $definition.DisplayName)
        $application = $applications | Select-Object -First 1
        if (-not $application) {
            if ($PSCmdlet.ShouldProcess($definition.DisplayName, 'Create application registration')) {
                $application = New-MgApplication -DisplayName $definition.DisplayName -SignInAudience 'AzureADMyOrg' -Description $definition.Description
            }
        } elseif ($PSCmdlet.ShouldProcess($definition.DisplayName, 'Update application description')) {
            Update-MgApplication -ApplicationId $application.Id -Description $definition.Description | Out-Null
        }

        $servicePrincipals = @(Get-Rev437GraphServicePrincipalByAppId -AppId $application.AppId)
        $servicePrincipal = $servicePrincipals | Select-Object -First 1
        if (-not $servicePrincipal) {
            if ($PSCmdlet.ShouldProcess($definition.DisplayName, 'Create service principal')) {
                $servicePrincipal = New-MgServicePrincipal -AppId $application.AppId -AccountEnabled:$true -Description $definition.Description
            }
        } elseif ($PSCmdlet.ShouldProcess($definition.DisplayName, 'Update service principal description')) {
            Update-MgServicePrincipal -ServicePrincipalId $servicePrincipal.Id -Description $definition.Description | Out-Null
        }

        $inventory.Add((Get-Rev437InventoryRecord -Definition $definition -Application $application -ServicePrincipal $servicePrincipal -TenantId $TenantId)) | Out-Null
    }

    $inventoryPayload = Export-Rev437SyntheticNhiLabInventory -Inventory $inventory -TenantId $TenantId -OutputPath $OutputPath
    [pscustomobject]@{
        TenantId      = $TenantId
        OutputPath    = $OutputPath
        CreatedAt     = $inventoryPayload.CreatedAt
        ObjectCount   = $inventory.Count
        Inventory     = @($inventory)
        InventoryFile = $OutputPath
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        throw 'TenantId is required.'
    }
    if (-not $ConfirmLabCreation) {
        throw 'ConfirmLabCreation is required.'
    }
    Invoke-Rev437SyntheticNhiLabCreation -TenantId $TenantId -OutputPath $OutputPath -ConfirmLabCreation:$ConfirmLabCreation -WhatIf:$WhatIfPreference
}
