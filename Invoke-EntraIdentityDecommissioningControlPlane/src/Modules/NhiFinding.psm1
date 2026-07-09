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

function New-DecomFinding {
    param(
        [string]$FindingId,
        [string]$Category,
        [ValidateSet('Critical','High','Medium','Low','Informational')]
        [string]$Severity,
        [int]$RiskScore,
        [ValidateSet('High','Medium','Low')]
        [string]$Confidence,
        [string]$ObjectType,
        [string]$ObjectId,
        [string]$DisplayName,
        [string]$UserPrincipalName,
        [string]$Evidence,
        [string]$EvidenceSource,
        [string]$GraphEndpoint,
        [string]$RecommendedAction,
        [ValidateSet('ManualApprovalRequired','AutoRemediable','InformationOnly','ProtectedObject')]
        [string]$RemediationMode,
        [string]$ConsultantNote,
        [bool]$ProtectedObject = $false,
        [string]$Classification,
        [string]$ClassificationConfidence,
        [object[]]$ClassificationSignals,
        [string]$ClassificationSource,
        [int]$ClassificationScore,
        [string]$MicrosoftPlatformReason,
        [string]$NormalizedAppId,
        [string]$NormalizedPublisherName,
        [string]$NormalizedVerifiedPublisherName,
        [string]$NormalizedAppOwnerOrganizationId,
        [string]$NormalizedServicePrincipalType,
        [object[]]$NormalizedTags,
        [bool]$NhiCandidate,
        [bool]$AgenticCandidate,
        [bool]$AutomationCandidate,
        [bool]$WorkloadCandidate,
        [int]$OwnerCount,
        [int]$CredentialCount,
        [int]$ExpiredCredentialCount,
        [int]$ExpiringCredentialCount,
        [int]$HighRiskPermissionCount,
        [int]$HighRiskOAuthGrantCount,
        [bool]$TenantWideConsent,
        [string]$VerifiedPublisherName,
        [string]$PublisherName,
        [bool]$FirstPartyMicrosoftApp,
        [bool]$MicrosoftFirstParty,
        [bool]$MicrosoftPlatform,
        [bool]$SuppressCustomerRemediation,
        [bool]$EvidenceOnly,
        [string]$CoverageMode,
        [bool]$RiskScoreMayBeUnderstated
    )
    if (-not $PSBoundParameters.ContainsKey('ClassificationSource') -and $script:DecomFindingTraceContext) {
        $ClassificationSource = [string]$script:DecomFindingTraceContext.ClassificationSource
    }
    if (-not $PSBoundParameters.ContainsKey('ClassificationSignals') -and $script:DecomFindingTraceContext) {
        $ClassificationSignals = @($script:DecomFindingTraceContext.ClassificationSignals)
    }
    if (-not $PSBoundParameters.ContainsKey('MicrosoftPlatformReason') -and $script:DecomFindingTraceContext) {
        $MicrosoftPlatformReason = [string]$script:DecomFindingTraceContext.MicrosoftPlatformReason
    }
    if (-not $PSBoundParameters.ContainsKey('NormalizedAppId') -and $script:DecomFindingTraceContext) {
        $NormalizedAppId = [string]$script:DecomFindingTraceContext.NormalizedAppId
    }
    if (-not $PSBoundParameters.ContainsKey('NormalizedPublisherName') -and $script:DecomFindingTraceContext) {
        $NormalizedPublisherName = [string]$script:DecomFindingTraceContext.NormalizedPublisherName
    }
    if (-not $PSBoundParameters.ContainsKey('NormalizedVerifiedPublisherName') -and $script:DecomFindingTraceContext) {
        $NormalizedVerifiedPublisherName = [string]$script:DecomFindingTraceContext.NormalizedVerifiedPublisherName
    }
    if (-not $PSBoundParameters.ContainsKey('NormalizedAppOwnerOrganizationId') -and $script:DecomFindingTraceContext) {
        $NormalizedAppOwnerOrganizationId = [string]$script:DecomFindingTraceContext.NormalizedAppOwnerOrganizationId
    }
    if (-not $PSBoundParameters.ContainsKey('NormalizedServicePrincipalType') -and $script:DecomFindingTraceContext) {
        $NormalizedServicePrincipalType = [string]$script:DecomFindingTraceContext.NormalizedServicePrincipalType
    }
    if (-not $PSBoundParameters.ContainsKey('NormalizedTags') -and $script:DecomFindingTraceContext) {
        $NormalizedTags = @($script:DecomFindingTraceContext.NormalizedTags)
    }
    if (-not $PSBoundParameters.ContainsKey('FirstPartyMicrosoftApp') -and $script:DecomFindingTraceContext) {
        $FirstPartyMicrosoftApp = [bool]$script:DecomFindingTraceContext.FirstPartyMicrosoftApp
    }
    if (-not $PSBoundParameters.ContainsKey('MicrosoftFirstParty') -and $script:DecomFindingTraceContext) {
        $MicrosoftFirstParty = [bool]$script:DecomFindingTraceContext.MicrosoftFirstParty
    }
    if (-not $PSBoundParameters.ContainsKey('MicrosoftPlatform') -and $script:DecomFindingTraceContext) {
        $MicrosoftPlatform = [bool]$script:DecomFindingTraceContext.MicrosoftPlatform
    }
    if (-not $PSBoundParameters.ContainsKey('EvidenceOnly') -and $script:DecomFindingTraceContext) {
        $EvidenceOnly = [bool]$script:DecomFindingTraceContext.EvidenceOnly
    }
    if (-not $PSBoundParameters.ContainsKey('SuppressCustomerRemediation') -and $script:DecomFindingTraceContext) {
        $SuppressCustomerRemediation = [bool]$script:DecomFindingTraceContext.SuppressCustomerRemediation
    }

    $platformClassification = ''
    $platformSuppressCustomerRemediation = $false
    if ($script:DecomFindingTraceContext) {
        $platformClassification = [string]$script:DecomFindingTraceContext.PlatformClassification
        $platformSuppressCustomerRemediation = [bool]$script:DecomFindingTraceContext.SuppressCustomerRemediation
    }

    if (-not $PSBoundParameters.ContainsKey('Classification') -and $platformClassification -and $platformClassification -ne 'Unknown') {
        $Classification = $platformClassification
    }
    if (-not $PSBoundParameters.ContainsKey('ClassificationConfidence') -and $platformClassification -and $platformClassification -ne 'Unknown') {
        $ClassificationConfidence = 'High'
    }

    if ($MicrosoftPlatform -or $FirstPartyMicrosoftApp) {
        $MicrosoftPlatform = $true
        $FirstPartyMicrosoftApp = $true
        $MicrosoftFirstParty = $true
        $EvidenceOnly = $true
        $SuppressCustomerRemediation = $true
        $Classification = 'MicrosoftPlatform'
        $ClassificationConfidence = 'High'
        $ClassificationScore = 0
        if ([string]::IsNullOrWhiteSpace($RemediationMode) -or $RemediationMode -eq 'ManualApprovalRequired' -or $RemediationMode -eq 'AutoRemediable') {
            $RemediationMode = 'InformationOnly'
        }
        if ([string]::IsNullOrWhiteSpace($RecommendedAction) -or $RecommendedAction -match 'Assign accountable owner|AddApplicationOwner|Revoke consent|Verify publisher|Reduce permission scope|Review permissions|review permissions|decommission|remove|reduce') {
            $RecommendedAction = 'Evidence only - Microsoft platform identity'
        }
    } elseif ($platformClassification -eq 'ExternalVendorPlatform' -and $platformSuppressCustomerRemediation) {
        $MicrosoftPlatform = $false
        $FirstPartyMicrosoftApp = $false
        $MicrosoftFirstParty = $false
        $EvidenceOnly = $true
        $SuppressCustomerRemediation = $true
        $Classification = 'ExternalVendorPlatform'
        $ClassificationConfidence = 'High'
        $ClassificationScore = 0
        if ([string]::IsNullOrWhiteSpace($RemediationMode) -or $RemediationMode -eq 'ManualApprovalRequired' -or $RemediationMode -eq 'AutoRemediable') {
            $RemediationMode = 'InformationOnly'
        }
        if ([string]::IsNullOrWhiteSpace($RecommendedAction) -or $RecommendedAction -match 'Assign accountable owner|AddApplicationOwner|Revoke consent|Verify publisher|Reduce permission scope|Review permissions|review permissions|decommission|remove|reduce') {
            $RecommendedAction = 'Evidence only - external vendor platform identity'
        }
    }
    [PSCustomObject]@{
        FindingId                 = $FindingId
        Category                  = $Category
        Severity                  = $Severity
        RiskScore                  = $RiskScore
        Confidence                = $Confidence
        ObjectType                = $ObjectType
        ObjectId                  = $ObjectId
        DisplayName               = $DisplayName
        UserPrincipalName         = $UserPrincipalName
        Evidence                  = $Evidence
        EvidenceSource            = $EvidenceSource
        GraphEndpoint             = $GraphEndpoint
        RecommendedAction         = $RecommendedAction
        RemediationMode           = $RemediationMode
        ConsultantNote            = $ConsultantNote
        ProtectedObject           = $ProtectedObject
        DetectedUtc               = (Get-Date).ToUniversalTime().ToString('o')
        Classification            = $Classification
        ClassificationConfidence  = $ClassificationConfidence
        ClassificationSignals     = $ClassificationSignals
        ClassificationSource      = $ClassificationSource
        ClassificationScore       = $ClassificationScore
        MicrosoftPlatformReason   = $MicrosoftPlatformReason
        NormalizedAppId           = $NormalizedAppId
        NormalizedPublisherName   = $NormalizedPublisherName
        NormalizedVerifiedPublisherName = $NormalizedVerifiedPublisherName
        NormalizedAppOwnerOrganizationId = $NormalizedAppOwnerOrganizationId
        NormalizedServicePrincipalType = $NormalizedServicePrincipalType
        NormalizedTags            = $NormalizedTags
        NhiCandidate              = $NhiCandidate
        AgenticCandidate          = $AgenticCandidate
        AutomationCandidate       = $AutomationCandidate
        WorkloadCandidate         = $WorkloadCandidate
        OwnerCount                = $OwnerCount
        CredentialCount           = $CredentialCount
        ExpiredCredentialCount    = $ExpiredCredentialCount
        ExpiringCredentialCount   = $ExpiringCredentialCount
        HighRiskPermissionCount   = $HighRiskPermissionCount
        HighRiskOAuthGrantCount   = $HighRiskOAuthGrantCount
        TenantWideConsent         = $TenantWideConsent
        VerifiedPublisherName     = $VerifiedPublisherName
        PublisherName             = $PublisherName
        FirstPartyMicrosoftApp    = $FirstPartyMicrosoftApp
        MicrosoftFirstParty       = $MicrosoftFirstParty
        MicrosoftPlatform        = $MicrosoftPlatform
        SuppressCustomerRemediation = $SuppressCustomerRemediation
        EvidenceOnly             = $EvidenceOnly
        CoverageMode              = $CoverageMode
        RiskScoreMayBeUnderstated = $RiskScoreMayBeUnderstated
    }
}

function Get-DecomFindingTraceContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$SourceObject,

        [string]$ClassificationSource = ''
    )

    $normalized = Get-DecomNormalizedNhiIdentity -InputObject $SourceObject
    $platformClassification = Test-DecomMicrosoftPlatformIdentity -NhiObject $SourceObject

    $classificationSignals = @()
    if ($platformClassification.MicrosoftPlatform -and $platformClassification.Reason) {
        $classificationSignals = @($platformClassification.Reason)
    } elseif ($SourceObject.PSObject.Properties['ClassificationSignals'] -and $SourceObject.ClassificationSignals) {
        $classificationSignals = @($SourceObject.ClassificationSignals | Where-Object { $null -ne $_ -and $_.ToString().Trim() -ne '' })
    }

    return [pscustomobject]@{
        ClassificationSource            = $ClassificationSource
        ClassificationSignals           = $classificationSignals
        PlatformClassification          = [string]$platformClassification.Classification
        SuppressCustomerRemediation    = [bool]$platformClassification.SuppressCustomerRemediation
        MicrosoftPlatformReason         = if ($SourceObject.PSObject.Properties['MicrosoftPlatformReason'] -and $SourceObject.MicrosoftPlatformReason) {
            [string]$SourceObject.MicrosoftPlatformReason
        } elseif ($platformClassification.MicrosoftPlatform) {
            [string]$platformClassification.Reason
        } else {
            ''
        }
        NormalizedAppId                 = $normalized.AppId
        NormalizedPublisherName         = $normalized.PublisherName
        NormalizedVerifiedPublisherName = $normalized.VerifiedPublisherName
        NormalizedAppOwnerOrganizationId= $normalized.AppOwnerOrganizationId
        NormalizedServicePrincipalType  = $normalized.ServicePrincipalType
        NormalizedTags                  = @($normalized.Tags)
        FirstPartyMicrosoftApp          = [bool](
            $platformClassification.MicrosoftFirstParty -or
            ($SourceObject.PSObject.Properties['FirstPartyMicrosoftApp'] -and $SourceObject.FirstPartyMicrosoftApp)
        )
        MicrosoftFirstParty             = [bool](
            $platformClassification.MicrosoftFirstParty -or
            ($SourceObject.PSObject.Properties['MicrosoftFirstParty'] -and $SourceObject.MicrosoftFirstParty)
        )
        MicrosoftPlatform               = [bool](
            $platformClassification.MicrosoftPlatform -or
            ($SourceObject.PSObject.Properties['MicrosoftPlatform'] -and $SourceObject.MicrosoftPlatform)
        )
        EvidenceOnly                    = [bool](
            $platformClassification.EvidenceOnly -or
            ($SourceObject.PSObject.Properties['EvidenceOnly'] -and $SourceObject.EvidenceOnly)
        )
    }
}

function Set-DecomFindingTraceContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$SourceObject,

        [string]$ClassificationSource = ''
    )

    $script:DecomFindingTraceContext = Get-DecomFindingTraceContext -SourceObject $SourceObject -ClassificationSource $ClassificationSource
    return $script:DecomFindingTraceContext
}

function Clear-DecomFindingTraceContext {
    [CmdletBinding()]
    param()

    $script:DecomFindingTraceContext = $null
}

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

Export-ModuleMember -Function Get-DecomGraphPropertyValue,Get-DecomGraphNestedDisplayName,Get-DecomNormalizedNhiIdentity,New-DecomFinding,Get-DecomFindingTraceContext,Set-DecomFindingTraceContext,Clear-DecomFindingTraceContext,Get-DecomPlatformIdentityCatalogPath,Get-DecomPlatformIdentityCatalog,Test-DecomPlatformIdentityCatalog,Test-DecomMicrosoftPlatformIdentity