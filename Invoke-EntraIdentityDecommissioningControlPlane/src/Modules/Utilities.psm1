function Write-DecomInfo  { param([string]$Message) Write-Host "[INFO]  " -ForegroundColor DarkCyan -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomOk    { param([string]$Message) Write-Host "[OK]    " -ForegroundColor Green    -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomWarn  { param([string]$Message) Write-Host "[WARN]  " -ForegroundColor Yellow   -NoNewline; Write-Host $Message -ForegroundColor Gray }
function Write-DecomError { param([string]$Message) Write-Host "[ERROR] " -ForegroundColor Red      -NoNewline; Write-Host $Message -ForegroundColor Gray }

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
        # NHI / Agentic Identity fields (Rev3.5)
        [string]$Classification,
        [string]$ClassificationConfidence,
        [object[]]$ClassificationSignals,
        [int]$ClassificationScore,
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
        [string]$CoverageMode,
        [bool]$RiskScoreMayBeUnderstated
    )
    [PSCustomObject]@{
        FindingId                 = $FindingId
        Category                  = $Category
        Severity                  = $Severity
        RiskScore                 = $RiskScore
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
        ClassificationScore       = $ClassificationScore
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
        CoverageMode              = $CoverageMode
        RiskScoreMayBeUnderstated = $RiskScoreMayBeUnderstated
    }
}

function Get-DecomTimestamp { Get-Date -Format 'yyyyMMdd_HHmmss' }
function Get-DecomTimestampDisplay { Get-Date -Format 'yyyy-MM-dd HH:mm:ss' }
