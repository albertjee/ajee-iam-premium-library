#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [ValidateNotNullOrEmpty()]
    [string]$InventoryPath,

    [ValidateNotNullOrEmpty()]
    [string]$ConfirmCleanupPhrase
)

$ErrorActionPreference = 'Stop'

$script:ExpectedCleanupPhrase = 'DELETE AJEE-LAB-NHI INVENTORY OBJECTS'
$script:RequiredPrefix = 'AJEE-LAB-NHI-'

function Test-Rev437SyntheticNhiLabName {
    param([Parameter(Mandatory)][string]$DisplayName)

    return $DisplayName -like 'AJEE-LAB-NHI-*'
}

function Read-Rev437SyntheticNhiLabInventory {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Inventory file '$Path' was not found."
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "Inventory file '$Path' is empty."
    }

    $inventory = $raw | ConvertFrom-Json
    if ($null -eq $inventory) {
        throw "Inventory file '$Path' is invalid JSON."
    }

    return $inventory
}

function Assert-Rev437SyntheticNhiLabInventory {
    param([Parameter(Mandatory)][object]$Inventory)

    if ($Inventory.PSObject.Properties['Inventory']) {
        $records = @($Inventory.Inventory)
    } else {
        $records = @($Inventory)
    }

    if ($records.Count -eq 0) {
        throw 'Inventory contains no lab objects.'
    }

    $requiredFields = @(
        'DisplayName',
        'AppId',
        'ApplicationObjectId',
        'ServicePrincipalObjectId',
        'TargetType',
        'Purpose',
        'CreatedAt',
        'TenantId',
        'SafeToDisable',
        'SafeToRollback',
        'ControlObject'
    )

    foreach ($record in $records) {
        foreach ($field in $requiredFields) {
            if ($null -eq $record.PSObject.Properties[$field] -or [string]::IsNullOrWhiteSpace([string]$record.$field)) {
                throw "Inventory record is missing required field '$field'."
            }
        }

        if (-not (Test-Rev437SyntheticNhiLabName -DisplayName $record.DisplayName)) {
            throw "Inventory record '$($record.DisplayName)' does not use the required AJEE-LAB-NHI- prefix."
        }
    }

    return ,$records
}

function Remove-Rev437SyntheticNhiLab {
    param(
        [Parameter(Mandatory)][string]$TenantId,
        [Parameter(Mandatory)][string]$InventoryPath,
        [Parameter(Mandatory)][string]$ConfirmCleanupPhrase
    )

    if ($ConfirmCleanupPhrase -ne $script:ExpectedCleanupPhrase) {
        throw "Cleanup confirmation phrase must be '$script:ExpectedCleanupPhrase'."
    }

    $inventory = Read-Rev437SyntheticNhiLabInventory -Path $InventoryPath
    $records = @(Assert-Rev437SyntheticNhiLabInventory -Inventory $inventory)
    $deletableRecords = @($records | Where-Object { $_.ControlObject -ne $true })
    $controlRecords = @($records | Where-Object { $_.ControlObject -eq $true })

    if (-not (Get-Command Remove-MgApplication -ErrorAction SilentlyContinue) -or
        -not (Get-Command Remove-MgServicePrincipal -ErrorAction SilentlyContinue)) {
        throw 'Microsoft Graph PowerShell cmdlets are required for lab object cleanup.'
    }

    $actions = [System.Collections.Generic.List[object]]::new()
    foreach ($record in $deletableRecords) {
        if (-not (Test-Rev437SyntheticNhiLabName -DisplayName $record.DisplayName)) {
            throw "Refusing to delete non-lab object '$($record.DisplayName)'."
        }

        $spTarget = "service principal $($record.ServicePrincipalObjectId)"
        $appTarget = "application $($record.ApplicationObjectId)"

        if ($PSCmdlet.ShouldProcess($record.DisplayName, "Delete $spTarget")) {
            Remove-MgServicePrincipal -ServicePrincipalId $record.ServicePrincipalObjectId -ErrorAction Stop
        }

        if ($PSCmdlet.ShouldProcess($record.DisplayName, "Delete $appTarget")) {
            Remove-MgApplication -ApplicationId $record.ApplicationObjectId -ErrorAction Stop
        }

        $actions.Add([pscustomobject]@{
            DisplayName             = $record.DisplayName
            ApplicationObjectId     = $record.ApplicationObjectId
            ServicePrincipalObjectId = $record.ServicePrincipalObjectId
            ControlObject           = [bool]$record.ControlObject
            Deleted                 = $true
        }) | Out-Null
    }

    [pscustomobject]@{
        TenantId           = $TenantId
        InventoryPath       = $InventoryPath
        ExpectedPrefix      = $script:RequiredPrefix
        ConfirmationPhrase  = $ConfirmCleanupPhrase
        DeletableCount      = $deletableRecords.Count
        ControlObjectCount   = $controlRecords.Count
        Deleted             = @($actions)
        PreservedControl    = @($controlRecords)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($TenantId)) {
        throw 'TenantId is required.'
    }
    if ([string]::IsNullOrWhiteSpace($InventoryPath)) {
        throw 'InventoryPath is required.'
    }
    if ([string]::IsNullOrWhiteSpace($ConfirmCleanupPhrase)) {
        throw 'ConfirmCleanupPhrase is required.'
    }
    Remove-Rev437SyntheticNhiLab -TenantId $TenantId -InventoryPath $InventoryPath -ConfirmCleanupPhrase $ConfirmCleanupPhrase
}
