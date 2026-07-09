# Capability state management — self-contained (no Import-Module to avoid nesting cycle)
# Write-DecomWarn is inlined here to avoid Import-Module chain: CapabilityState -> Utilities -> CapabilityState

if (-not $script:DecomWarningOnceState) {
    $script:DecomWarningOnceState = @{}
}

if (-not $script:DecomCapabilityState) {
    $script:DecomCapabilityState = @{}
}

function Reset-DecomRuntimeState {
    [CmdletBinding()]
    param()

    $script:DecomWarningOnceState = @{}
    $script:DecomCapabilityState   = @{}
}

function Get-DecomCapabilityState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    $state = $script:DecomCapabilityState[$Key]
    if ($null -eq $state) {
        $state = [pscustomobject]@{
            Key              = $Key
            Available        = $true
            WarningEmitted   = $false
            SuppressedCount  = 0
            LastMessage      = $null
            LastError        = $null
            LastUpdatedUtc   = $null
        }
        $script:DecomCapabilityState[$Key] = $state
    }

    return $state
}

function Test-DecomCapabilityAvailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key
    )

    return [bool](Get-DecomCapabilityState -Key $Key).Available
}

function Set-DecomCapabilityUnavailable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter()]
        [string]$Error = $null
    )

    $state = Get-DecomCapabilityState -Key $Key
    $state.Available = $false
    $state.LastMessage = $Message
    $state.LastError = $Error
    $state.LastUpdatedUtc = [DateTime]::UtcNow.ToString('o')

    if (-not $state.WarningEmitted) {
        # Inlined Write-DecomWarn to avoid Import-Module nesting cycle
        Write-Host "[WARN]  " -ForegroundColor Yellow -NoNewline
        Write-Host $Message -ForegroundColor Gray
        $state.WarningEmitted = $true
    } else {
        $state.SuppressedCount++
    }

    return $state
}

function Test-DecomInteractiveHost {
    [CmdletBinding()]
    param()

    try {
        return [Environment]::UserInteractive -and $null -ne $Host -and $null -ne $Host.UI -and $Host.Name -notmatch 'ServerRemoteHost'
    } catch {
        return $false
    }
}

function Test-DecomQueryUnavailableResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    if ($InputObject -is [System.Array]) {
        $items = @($InputObject)
        if ($items.Count -eq 1) {
            return Test-DecomQueryUnavailableResult -InputObject $items[0]
        }
        return $false
    }

    return (
        $null -ne $InputObject -and
        $InputObject -is [pscustomobject] -and
        $InputObject.PSObject.Properties.Name -contains 'QuerySucceeded' -and
        -not [bool]$InputObject.QuerySucceeded
    )
}

function Get-DecomQueryResultEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    if (Test-DecomQueryUnavailableResult -InputObject $InputObject) {
        return @()
    }

    if ($InputObject -is [pscustomobject] -and $InputObject.PSObject.Properties.Name -contains 'Entries') {
        return @($InputObject.Entries)
    }

    return @($InputObject)
}

function New-DecomUnavailableQueryResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CapabilityKey,

        [Parameter(Mandatory = $true)]
        [string]$Error,

        [string]$ObjectId = '',

        [string]$ObjectType = '',

        [object[]]$Entries = @()
    )

    return [pscustomobject]@{
        QuerySucceeded        = $false
        CapabilityAvailable   = $false
        CapabilityKey         = $CapabilityKey
        ObjectId              = $ObjectId
        ObjectType            = $ObjectType
        Entries               = @($Entries)
        Error                 = $Error
    }
}

Export-ModuleMember -Function Reset-DecomRuntimeState,Get-DecomCapabilityState,Test-DecomCapabilityAvailable,Set-DecomCapabilityUnavailable,Test-DecomInteractiveHost,Test-DecomQueryUnavailableResult,Get-DecomQueryResultEntries,New-DecomUnavailableQueryResult