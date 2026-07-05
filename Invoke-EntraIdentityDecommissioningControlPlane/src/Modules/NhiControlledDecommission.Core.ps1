# NhiControlledDecommission.Core.ps1
# Dot-sourced into NhiControlledDecommission.psm1 module scope. Do not import directly.
# Contains: Get-NhiControlledDecommissionSha256, ConvertTo-NhiControlledSanitizedValue, Get-NhiControlledDecommissionSchema, ConvertTo-NhiControlledSnapshot, Get-NhiControlledTargetCountsByType, Get-NhiControlledStatusText, Get-NhiControlledPropertyValue, New-NhiControlledChecklist

function Get-NhiControlledDecommissionSha256 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$InputString
    )

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($InputString)
        $hash = $sha256.ComputeHash($bytes)
        return ([BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    } finally {
        $sha256.Dispose()
    }
}

function ConvertTo-NhiControlledSanitizedValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Value,

        [Parameter()]
        [string]$PropertyName
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($PropertyName -and $PropertyName -match $script:SensitivePropertyPattern) {
        return $null
    }

    if ($Value -is [string]) {
        if ($Value -match $script:SensitivePropertyPattern -or $Value -match 'must-not-export') {
            return '[REDACTED]'
        }
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $copy = [ordered]@{}
        foreach ($key in $Value.Keys) {
            $keyName = [string]$key
            if ($keyName -match $script:SensitivePropertyPattern) {
                continue
            }
            $copy[$keyName] = ConvertTo-NhiControlledSanitizedValue -Value $Value[$key] -PropertyName $keyName
        }
        return [PSCustomObject]$copy
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $items = @()
        foreach ($item in @($Value)) {
            $items += ,(ConvertTo-NhiControlledSanitizedValue -Value $item)
        }
        return $items
    }

    $properties = @($Value.PSObject.Properties | Where-Object { $_.MemberType -in @('NoteProperty', 'Property') })
    if ($properties.Count -gt 0) {
        $copy = [ordered]@{}
        foreach ($property in $properties) {
            if ($property.Name -match $script:SensitivePropertyPattern) {
                continue
            }
            $copy[$property.Name] = ConvertTo-NhiControlledSanitizedValue -Value $property.Value -PropertyName $property.Name
        }
        return [PSCustomObject]$copy
    }

    return $Value
}

function Get-NhiControlledDecommissionSchema {
    [CmdletBinding()]
    param()

    [ordered]@{
        ControlledDecommissionSchemaVersion = $script:ControlledSchemaVersion
        MetadataCleanupSchemaVersion        = '4.5'
        GrantCleanupSchemaVersion           = '4.6'
        ManagedIdentitySchemaVersion        = '4.7'
        E2EEvidencePackSchemaVersion        = '4.8'
        ProductionReadinessSchemaVersion    = '4.9'
        ReleaseMergeGateSchemaVersion       = '4.9'
        KnownWarningInventorySchemaVersion  = '4.9'
        FinalSafetyAssertionSchemaVersion   = '4.9'
        QAHandoffSchemaVersion              = '4.8'
        OperatorDecisionSchemaVersion       = '4.8'
        ActionLogSchemaVersion              = $script:ControlledSchemaVersion
        SnapshotSchemaVersion               = $script:ControlledSchemaVersion
        DeleteReadinessSchemaVersion        = $script:ControlledSchemaVersion
        DependencyRecheckStatuses           = @('Clean', 'Blocked', 'Unknown', 'SkippedWithApproval')
        PostCleanupValidationStatuses       = @('NotRun', 'Simulated', 'ConfirmedAbsent', 'ConfirmedPresent', 'Unknown')
        ManagedIdentityTypes                = @('SystemAssigned', 'UserAssigned', 'Unknown')
        SupportedTargetTypes                = @($script:SupportedTargetTypes)
        SupportedStages                     = @($script:SupportedStages)
        LiveMutationEnabled                 = $false
        FinalDeleteLiveEnabled              = $false
    }
}

function ConvertTo-NhiControlledSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Target,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$RunId
    )

    $sanitized = [ordered]@{}
    foreach ($property in $Target.PSObject.Properties) {
        if ($property.Name -in @('KeyCredentials', 'PasswordCredentials', 'Certificates', 'Credentials')) {
            $metadata = @()
            foreach ($credential in @($property.Value)) {
                $credentialMetadata = [ordered]@{
                    KeyId             = [string]$credential.KeyId
                    CredentialId      = [string]$credential.CredentialId
                    Id                = [string]$credential.Id
                    Type              = [string]$credential.Type
                    Usage             = [string]$credential.Usage
                    StartDateTime     = [string]$credential.StartDateTime
                    EndDateTime       = [string]$credential.EndDateTime
                    DisplayName       = [string]$credential.DisplayName
                }
                if ($credential.PSObject.Properties['AdditionalProperties']) {
                    $credentialMetadata['AdditionalProperties'] = ConvertTo-NhiControlledSanitizedValue -Value $credential.AdditionalProperties -PropertyName 'AdditionalProperties'
                }
                $metadata += [PSCustomObject]$credentialMetadata
            }
            $sanitized[$property.Name] = $metadata
            continue
        }
        if ($property.Name -match $script:SensitivePropertyPattern) {
            continue
        }
        $sanitized[$property.Name] = ConvertTo-NhiControlledSanitizedValue -Value $property.Value -PropertyName $property.Name
    }

    $snapshotBody = [ordered]@{
        SchemaVersion = $script:ControlledSchemaVersion
        RunId         = $RunId
        CapturedUtc   = [DateTime]::UtcNow.ToString('o')
        Target        = [PSCustomObject]$sanitized
    }
    $canonical = $snapshotBody | ConvertTo-Json -Depth 20 -Compress
    $snapshotBody['SHA256'] = Get-NhiControlledDecommissionSha256 -InputString $canonical
    return [PSCustomObject]$snapshotBody
}

function Get-NhiControlledTargetCountsByType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Plan
    )

    $counts = [ordered]@{
        ServicePrincipal = 0
        Application      = 0
        ManagedIdentity  = 0
    }

    $planCounts = $Plan.PSObject.Properties['TargetCountsByType']
    if ($null -ne $planCounts -and $null -ne $planCounts.Value) {
        $value = $planCounts.Value
        foreach ($key in @('ServicePrincipal', 'Application', 'ManagedIdentity')) {
            if ($value -is [System.Collections.IDictionary] -and $value.Contains($key)) {
                $counts[$key] = [int]$value[$key]
            } else {
                $valueProperty = $value.PSObject.Properties[$key]
                if ($null -ne $valueProperty) {
                    $counts[$key] = [int]$valueProperty.Value
                }
            }
        }
    } else {
        $targetType = [string]$Plan.TargetType
        if ($counts.Contains($targetType)) {
            $counts[$targetType] = 1
        }
    }

    [PSCustomObject]$counts
}

function Get-NhiControlledStatusText {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$Value,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$Default = 'Incomplete'
    )

    $status = [string]$Value
    if ([string]::IsNullOrWhiteSpace($status)) {
        $status = $Default
    }

    return $status
}

function Get-NhiControlledPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [string[]]$PropertyNames,

        [Parameter()]
        [object]$Default = $null
    )

    if ($null -eq $InputObject) {
        return $Default
    }

    foreach ($propertyName in @($PropertyNames)) {
        if ($InputObject.PSObject.Properties[$propertyName]) {
            return $InputObject.PSObject.Properties[$propertyName].Value
        }
    }

    return $Default
}

function New-NhiControlledChecklist {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Items
    )

    @(foreach ($item in @($Items)) {
        [PSCustomObject]@{
            Checked = $false
            Required = $true
            Item = $item
        }
    })
}
