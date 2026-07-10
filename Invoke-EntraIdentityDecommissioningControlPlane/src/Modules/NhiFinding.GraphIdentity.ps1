function Get-DecomGraphPropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    if ($null -eq $InputObject) { return $null }

    foreach ($propertyName in $PropertyNames) {
        foreach ($property in @($InputObject.PSObject.Properties)) {
            if ($property.Name -ieq $propertyName) {
                return $property.Value
            }
        }
    }

    if ($InputObject.PSObject.Properties['AdditionalProperties']) {
        $additionalProperties = $InputObject.AdditionalProperties
        if ($additionalProperties -is [System.Collections.IDictionary]) {
            foreach ($propertyName in $PropertyNames) {
                foreach ($key in $additionalProperties.Keys) {
                    if ([string]$key -ieq $propertyName) {
                        return $additionalProperties[$key]
                    }
                }
            }
        } elseif ($additionalProperties -and $additionalProperties.PSObject.Properties) {
            foreach ($propertyName in $PropertyNames) {
                foreach ($property in @($additionalProperties.PSObject.Properties)) {
                    if ($property.Name -ieq $propertyName) {
                        return $property.Value
                    }
                }
            }
        }
    }

    return $null
}

function Get-DecomGraphNestedDisplayName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string[]]$PropertyNames
    )

    $candidate = Get-DecomGraphPropertyValue -InputObject $InputObject -PropertyNames $PropertyNames
    if ($candidate -is [string]) {
        return $candidate
    }

    if ($candidate -and $candidate.PSObject.Properties) {
        $displayName = Get-DecomGraphPropertyValue -InputObject $candidate -PropertyNames @('DisplayName', 'displayName')
        if ($displayName) { return [string]$displayName }
    }

    return ''
}

function Get-DecomNormalizedNhiIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    $appId = [string](Get-DecomGraphPropertyValue -InputObject $InputObject -PropertyNames @('AppId', 'appId'))
    $displayName = [string](Get-DecomGraphPropertyValue -InputObject $InputObject -PropertyNames @('DisplayName', 'displayName'))
    $appDisplayName = [string](Get-DecomGraphPropertyValue -InputObject $InputObject -PropertyNames @('AppDisplayName', 'appDisplayName'))
    $servicePrincipalType = [string](Get-DecomGraphPropertyValue -InputObject $InputObject -PropertyNames @('ServicePrincipalType', 'servicePrincipalType'))
    $publisherName = [string](Get-DecomGraphPropertyValue -InputObject $InputObject -PropertyNames @('PublisherName', 'publisherName'))
    $verifiedPublisherName = Get-DecomGraphNestedDisplayName -InputObject $InputObject -PropertyNames @(
        'VerifiedPublisher',
        'verifiedPublisher',
        'VerifiedPublisherName',
        'verifiedPublisherName'
    )
    $appOwnerOrganizationId = [string](Get-DecomGraphPropertyValue -InputObject $InputObject -PropertyNames @('AppOwnerOrganizationId', 'appOwnerOrganizationId'))

    $rawTags = Get-DecomGraphPropertyValue -InputObject $InputObject -PropertyNames @('Tags', 'tags')
    $tags = @()
    if ($rawTags -is [string]) {
        if ($rawTags.Trim()) { $tags = @($rawTags) }
    } elseif ($rawTags -is [System.Collections.IEnumerable] -and -not ($rawTags -is [string])) {
        $tags = @($rawTags | Where-Object { $null -ne $_ -and $_.ToString().Trim() -ne '' })
    }

    return [pscustomobject]@{
        AppId                  = $appId
        DisplayName            = $displayName
        AppDisplayName         = $appDisplayName
        ServicePrincipalType   = $servicePrincipalType
        PublisherName          = $publisherName
        VerifiedPublisherName  = $verifiedPublisherName
        AppOwnerOrganizationId = $appOwnerOrganizationId
        Tags                   = $tags
    }
}
