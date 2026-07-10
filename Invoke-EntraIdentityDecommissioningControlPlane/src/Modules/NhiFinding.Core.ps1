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
