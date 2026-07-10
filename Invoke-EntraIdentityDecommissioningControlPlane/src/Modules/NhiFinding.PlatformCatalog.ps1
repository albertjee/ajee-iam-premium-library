function Get-DecomPlatformIdentityCatalogPath {
    [CmdletBinding()]
    param(
        [string]$CatalogPath = ''
    )

    if ($CatalogPath) {
        return $CatalogPath
    }

    $moduleRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    return (Join-Path $moduleRoot 'config\platform-identity-catalog.json')
}

function Get-DecomPlatformIdentityCatalog {
    [CmdletBinding()]
    param(
        [string]$CatalogPath = ''
    )

    $resolvedPath = Get-DecomPlatformIdentityCatalogPath -CatalogPath $CatalogPath
    if ($script:DecomPlatformIdentityCatalog -and $script:DecomPlatformIdentityCatalogPath -eq $resolvedPath) {
        return $script:DecomPlatformIdentityCatalog
    }

    $catalog = [pscustomobject]@{
        schemaVersion   = '1.0'
        description     = 'Known Microsoft and vendor platform service-principal classifications used by the Entra decommissioning control plane.'
        lastReviewedUtc = '2026-06-12T00:00:00Z'
        identities      = @()
        catalogPath     = $resolvedPath
    }

    if (Test-Path -LiteralPath $resolvedPath) {
        $loaded = Get-Content -LiteralPath $resolvedPath -Raw | ConvertFrom-Json -Depth 20
        $identities = @()
        if ($loaded.PSObject.Properties['identities']) {
            $identities = @($loaded.identities)
        }
        $catalog = [pscustomobject]@{
            schemaVersion   = [string]$loaded.schemaVersion
            description     = [string]$loaded.description
            lastReviewedUtc = [string]$loaded.lastReviewedUtc
            identities      = $identities
            catalogPath     = $resolvedPath
        }
    }

    $script:DecomPlatformIdentityCatalog = $catalog
    $script:DecomPlatformIdentityCatalogPath = $resolvedPath
    return $catalog
}

function Test-DecomPlatformIdentityCatalog {
    [CmdletBinding()]
    param(
        [object]$Catalog = $(Get-DecomPlatformIdentityCatalog)
    )

    $errors = @()
    $duplicateAppIds = @()
    $allowedClassifications = @('MicrosoftPlatform', 'ExternalVendorPlatform', 'CustomerOwned', 'Unknown')
    $seenAppIds = @{}
    $identities = @()

    if ($Catalog -and $Catalog.PSObject.Properties['identities']) {
        $identities = @($Catalog.identities)
    }

    if (-not $Catalog -or -not $Catalog.PSObject.Properties['schemaVersion'] -or [string]::IsNullOrWhiteSpace([string]$Catalog.schemaVersion)) {
        $errors += 'Catalog schemaVersion is missing.'
    }

    if ($identities.Count -eq 0) {
        $errors += 'Catalog identities collection is empty.'
    }

    foreach ($identity in $identities) {
        $appId = [string]$identity.appId
        if ([string]::IsNullOrWhiteSpace($appId)) {
            $errors += 'Catalog identity is missing appId.'
            continue
        }

        if ($seenAppIds.ContainsKey($appId.ToLowerInvariant())) {
            $duplicateAppIds += $appId
        } else {
            $seenAppIds[$appId.ToLowerInvariant()] = $true
        }

        $classification = [string]$identity.classification
        if ($classification -and ($classification -notin $allowedClassifications)) {
            $errors += "Catalog identity '$appId' has unsupported classification '$classification'."
        }
    }

    if ($duplicateAppIds.Count -gt 0) {
        $errors += "Duplicate catalog appId entries detected: $($duplicateAppIds -join ', ')."
    }

    [pscustomobject]@{
        Valid          = ($errors.Count -eq 0)
        Errors         = $errors
        DuplicateAppIds = $duplicateAppIds
        IdentityCount  = $identities.Count
        SchemaVersion  = if ($Catalog -and $Catalog.PSObject.Properties['schemaVersion']) { [string]$Catalog.schemaVersion } else { '' }
    }
}

function Test-DecomMicrosoftPlatformIdentity {
    <#
    .SYNOPSIS
    Classifies an NHI object as Microsoft platform, external vendor, or customer-owned.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$NhiObject
    )

    $normalized = Get-DecomNormalizedNhiIdentity -InputObject $NhiObject
    $publisherName = [string]$normalized.PublisherName
    $verifiedPublisherName = [string]$normalized.VerifiedPublisherName
    $appOwnerOrganizationId = [string]$normalized.AppOwnerOrganizationId
    $tags = @($normalized.Tags)
    $appId = [string]$normalized.AppId
    $catalog = Get-DecomPlatformIdentityCatalog
    $catalogEntry = $null
    foreach ($identity in @($catalog.identities)) {
        if ($identity -and $identity.PSObject.Properties['appId'] -and [string]$identity.appId -and $appId -and ([string]$identity.appId -ieq $appId)) {
            $catalogEntry = $identity
            break
        }
    }

    $knownMicrosoftTenantIds = @(
        'f8cdef31-a31e-4b4a-93e4-5f571e91255a',
        '72f988bf-86f1-41af-91ab-2d7cd011db47'
    )

    $fallbackKnownMicrosoftAppIds = @(
        '14d82eec-204b-4c2f-b7e8-296a70dab67e',
        '09213cdc-9f30-4e82-aa6f-9b6e8d82dab3',
        'f1143447-b07a-4557-b878-b78df8d45c13',
        '1b730954-1685-4b74-9bfd-dac224a7b894'
    )

    $hasMicrosoftOwnerTenant = $appOwnerOrganizationId -and ($appOwnerOrganizationId -in $knownMicrosoftTenantIds)
    $hasMicrosoftPublisher = $publisherName -eq 'Microsoft Corporation'
    $hasMicrosoftVerifiedPublisher = $verifiedPublisherName -in @('Microsoft', 'Microsoft Corporation')
    $hasKnownMicrosoftAppId = $appId -and ($appId -in $fallbackKnownMicrosoftAppIds)
    $hasStrongMetadata = $hasMicrosoftOwnerTenant -or $hasMicrosoftVerifiedPublisher -or ($hasMicrosoftPublisher -and $hasMicrosoftVerifiedPublisher)

    if ($hasStrongMetadata) {
        $reason = if ($hasMicrosoftOwnerTenant) {
            'MicrosoftOwnerTenant'
        } elseif ($hasMicrosoftVerifiedPublisher -and $hasMicrosoftPublisher) {
            'MicrosoftPublisherAndVerifiedPublisher'
        } elseif ($hasMicrosoftVerifiedPublisher) {
            'MicrosoftVerifiedPublisher'
        } else {
            'MicrosoftMetadata'
        }

        return [pscustomobject]@{
            Classification              = 'MicrosoftPlatform'
            MicrosoftFirstParty         = $true
            MicrosoftPlatform           = $true
            EvidenceOnly                = $true
            Reason                      = $reason
            SuppressCustomerRemediation  = $true
            CatalogSource               = 'LiveMetadata'
            CatalogEntry                = $catalogEntry
        }
    }

    if ($catalogEntry) {
        $catalogClassification = [string]$catalogEntry.classification
        $catalogReason = [string]$catalogEntry.reason
        $suppressCustomerRemediation = [bool]$catalogEntry.suppressCustomerRemediation

        switch ($catalogClassification) {
            'MicrosoftPlatform' {
                return [pscustomobject]@{
                    Classification              = 'MicrosoftPlatform'
                    MicrosoftFirstParty         = [bool]$catalogEntry.firstPartyMicrosoftApp
                    MicrosoftPlatform           = $true
                    EvidenceOnly                = $true
                    Reason                      = if ($catalogReason) { $catalogReason } else { 'PlatformCatalogMicrosoftPlatform' }
                    SuppressCustomerRemediation = $true
                    CatalogSource               = 'PlatformCatalog'
                    CatalogEntry                = $catalogEntry
                }
            }
            'ExternalVendorPlatform' {
                return [pscustomobject]@{
                    Classification              = 'ExternalVendorPlatform'
                    MicrosoftFirstParty         = $false
                    MicrosoftPlatform           = $false
                    EvidenceOnly                = $suppressCustomerRemediation
                    Reason                      = if ($catalogReason) { $catalogReason } else { 'PlatformCatalogExternalVendor' }
                    SuppressCustomerRemediation = $suppressCustomerRemediation
                    CatalogSource               = 'PlatformCatalog'
                    CatalogEntry                = $catalogEntry
                }
            }
            default {
                return [pscustomobject]@{
                    Classification              = 'Unknown'
                    MicrosoftFirstParty         = $false
                    MicrosoftPlatform           = $false
                    EvidenceOnly                = $false
                    Reason                      = ''
                    SuppressCustomerRemediation = $false
                    CatalogSource               = 'PlatformCatalog'
                    CatalogEntry                = $catalogEntry
                }
            }
        }
    }

    if ($hasKnownMicrosoftAppId) {
        return [pscustomobject]@{
            Classification              = 'MicrosoftPlatform'
            MicrosoftFirstParty         = $true
            MicrosoftPlatform           = $true
            EvidenceOnly                = $true
            Reason                      = 'MicrosoftAppIdAllowlist'
            SuppressCustomerRemediation = $true
            CatalogSource               = 'BuiltInFallback'
            CatalogEntry                = $null
        }
    }

    return [pscustomobject]@{
        Classification              = 'Unknown'
        MicrosoftFirstParty         = $false
        MicrosoftPlatform           = $false
        EvidenceOnly                = $false
        Reason                      = ''
        SuppressCustomerRemediation  = $false
        CatalogSource               = 'Unknown'
        CatalogEntry                = $null
    }
}
