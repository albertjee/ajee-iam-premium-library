function Get-DecomSchemaContract {
    [CmdletBinding()]
    param(
        [ValidateSet('Finding','RunManifest','ApprovalManifest','ExecutionLog','ExecutionEvidence','BaselineComparison','ExecutiveSummary','ClientReadoutPackManifest','CatalogValidationReport','WriteReadinessReport','CredentialHygienePack','ApplicationGovernancePack','ConditionalAccessGovernancePack','EmergencyAccessGovernancePack','ReleaseValidationReport','OutputManifest','EvidenceBundleManifest','EvidenceHashManifest','RedactionReport','ReplayValidationReport','ApprovalDiffReport','TraceabilityReport','ClientHandoffManifest','Rev35ReadinessReport')]
        [string]$ObjectType
    )

    switch ($ObjectType) {
        'Finding' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'FindingId', 'Category', 'Severity', 'RiskScore', 'Confidence', 'ObjectType', 'ObjectId',
                    'DisplayName', 'UserPrincipalName', 'Evidence', 'EvidenceSource', 'GraphEndpoint',
                    'RecommendedAction', 'RemediationMode', 'ConsultantNote'
                )
                FieldTypes = @{
                    FindingId = 'string'
                    Category = 'string'
                    Severity = 'string'
                    RiskScore = 'int'
                    Confidence = 'string'
                    ObjectType = 'string'
                    ObjectId = 'string'
                    DisplayName = 'string'
                    UserPrincipalName = 'string'
                    Evidence = 'string'
                    EvidenceSource = 'string'
                    GraphEndpoint = 'string'
                    RecommendedAction = 'string'
                    RemediationMode = 'string'
                    ConsultantNote = 'string'
                }
                AllowedValues = @{
                    Severity = @('Critical','High','Medium','Low','Informational')
                    RemediationMode = @('ManualApprovalRequired','AutoRemediable','InformationOnly','ProtectedObject')
                    Confidence = @('High','Medium','Low')
                }
                Description = 'Core finding object emitted during assessment'
            }
        }
        'RunManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'RunId', 'Mode', 'DemoMode', 'Summary', 'ExportPaths'
                )
                Description = 'Manifest summarizing assessment run and exports'
            }
        }
        'ApprovalManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName',
                    'RunId', 'ApprovedBy', 'ExpiresUtc', 'ApprovedActions'
                )
                Description = 'Client-approved remediation actions'
            }
        }
        'ExecutionLog' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'RunId',
                    'Log'
                )
                Description = 'Detailed execution log for remediation operations'
            }
        }
        'ExecutionEvidence' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId',
                    'Actions', 'Summary'
                )
                Description = 'Evidence of executed remediation actions'
            }
        }
        'BaselineComparison' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId',
                    'ComparisonResults', 'BaselineInfo'
                )
                Description = 'Comparison between current and baseline findings'
            }
        }
        'ExecutiveSummary' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'Coverage', 'Findings', 'Summary', 'BaselineComparison', 'RiskMovement'
                )
                Description = 'Executive summary of assessment findings'
            }
        }
        'ClientReadoutPackManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'Items'
                )
                Description = 'Manifest of client readout pack contents'
            }
        }
        'CatalogValidationReport' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'Passed', 'UnknownFindingIds', 'SeverityMismatches', 'RiskScoreMismatches',
                    'RiskScoreBandViolations', 'MissingRequiredFields', 'InvalidRemediationModes'
                )
                Description = 'Validation of findings against documentation catalog'
            }
        }
        'WriteReadinessReport' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'ExecutionScopeRegistry', 'Rev3Candidates', 'Recommendation'
                )
                Description = 'Readiness assessment for Rev3.1 write expansion'
            }
        }
        'CredentialHygienePack' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'CredentialCount', 'ExpiredCredentialCount', 'ExpiringSoonCredentialCount', 'OwnerlessCredentialCount', 'SingleOwnerCredentialCount', 'DisabledOwnerCredentialCount',
                    'ReadyForApprovalCount', 'PlanOnlyExpiringNotExpiredCount', 'BlockedMissingCredentialKeyIdCount', 'BlockedCredentialNotExpiredCount', 'BlockedApplicationReadFailureCount', 'BlockedNoApplicationOwnerCount', 'BlockedProtectedApplicationCount', 'BlockedCredentialTypeUnsupportedCount',
                    'SkippedAlreadyRemovedCount', 'ExecutedCount', 'FailedCount', 'PartialFailedCount', 'DeferredCount',
                    'CredentialDetails'
                )
                FieldTypes = @{
                    SchemaVersion = 'string'
                    ToolVersion = 'string'
                    GeneratedUtc = 'string'
                    EngagementId = 'string'
                    ClientName = 'string'
                    Assessor = 'string'
                    CredentialCount = 'int'
                    ExpiredCredentialCount = 'int'
                    ExpiringSoonCredentialCount = 'int'
                    OwnerlessCredentialCount = 'int'
                    SingleOwnerCredentialCount = 'int'
                    DisabledOwnerCredentialCount = 'int'
                    ReadyForApprovalCount = 'int'
                    PlanOnlyExpiringNotExpiredCount = 'int'
                    BlockedMissingCredentialKeyIdCount = 'int'
                    BlockedCredentialNotExpiredCount = 'int'
                    BlockedApplicationReadFailureCount = 'int'
                    BlockedNoApplicationOwnerCount = 'int'
                    BlockedProtectedApplicationCount = 'int'
                    BlockedCredentialTypeUnsupportedCount = 'int'
                    SkippedAlreadyRemovedCount = 'int'
                    ExecutedCount = 'int'
                    FailedCount = 'int'
                    PartialFailedCount = 'int'
                    DeferredCount = 'int'
                    CredentialDetails = 'object'
                }
                Description = 'Credential hygiene pack containing summary and details of credential findings'
            }
        }
        'ApplicationGovernancePack' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'ApplicationCount', 'UnownedApplicationCount', 'SingleOwnerApplicationCount', 'DisabledOwnerApplicationCount', 'DisabledOnlyOwnerApplicationCount',
                    'ServicePrincipalNoOwnerCount', 'CredentialBearingNoOwnerCount',
                    'ReadyForOwnerApprovalCount', 'PlanOnlyOwnerActionCount', 'ExceptionCount',
                    'Applications', 'OwnerReadiness', 'Exceptions', 'RecommendedNextActions'
                )
                FieldTypes = @{
                    SchemaVersion = 'string'
                    ToolVersion = 'string'
                    GeneratedUtc = 'string'
                    EngagementId = 'string'
                    ClientName = 'string'
                    Assessor = 'string'
                    ApplicationCount = 'int'
                    UnownedApplicationCount = 'int'
                    SingleOwnerApplicationCount = 'int'
                    DisabledOwnerApplicationCount = 'int'
                    DisabledOnlyOwnerApplicationCount = 'int'
                    ServicePrincipalNoOwnerCount = 'int'
                    CredentialBearingNoOwnerCount = 'int'
                    ReadyForOwnerApprovalCount = 'int'
                    PlanOnlyOwnerActionCount = 'int'
                    ExceptionCount = 'int'
                    Applications = 'object'
                    OwnerReadiness = 'object'
                    Exceptions = 'object'
                    RecommendedNextActions = 'object'
                }
                Description = 'Application ownership governance pack containing summary and details of application ownership findings'
            }
        }
        'ConditionalAccessGovernancePack' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'CAPolicyCount', 'ExclusionGroupCount', 'ExclusionCount', 'ExclusionsLackingReviewEvidenceCount', 'ConflictingReviewEvidenceCount',
                    'HighRiskExclusionCount', 'RecommendedManualRemediationCount', 'Rev3WriteReadinessCandidatesCount',
                    'CAPolicies', 'ExclusionGroups', 'Exclusions', 'ExceptionRegister', 'RemediationDesign'
                )
                FieldTypes = @{
                    SchemaVersion = 'string'
                    ToolVersion = 'string'
                    GeneratedUtc = 'string'
                    EngagementId = 'string'
                    ClientName = 'string'
                    Assessor = 'string'
                    CAPolicyCount = 'int'
                    ExclusionGroupCount = 'int'
                    ExclusionCount = 'int'
                    ExclusionsLackingReviewEvidenceCount = 'int'
                    ConflictingReviewEvidenceCount = 'int'
                    HighRiskExclusionCount = 'int'
                    RecommendedManualRemediationCount = 'int'
                    Rev3WriteReadinessCandidatesCount = 'int'
                    CAPolicies = 'object'
                    ExclusionGroups = 'object'
                    Exclusions = 'object'
                    ExceptionRegister = 'object'
                    RemediationDesign = 'object'
                }
                Description = 'Conditional Access exclusion governance pack containing summary and details of CA exclusions'
            }
        }
        'EmergencyAccessGovernancePack' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'ProtectedObjectCount', 'EmergencyAccessAccountCount', 'ProtectedObjectBreakdown', 'WhatIfActionsBlockedCount', 'ApprovalActionsBlockedCount',
                    'ProtectedObjects', 'EmergencyAccessAccounts', 'WhatIfActionsBlocked', 'ApprovalActionsBlocked', 'PotentialHygieneGaps'
                )
                FieldTypes = @{
                    SchemaVersion = 'string'
                    ToolVersion = 'string'
                    GeneratedUtc = 'string'
                    EngagementId = 'string'
                    ClientName = 'string'
                    Assessor = 'string'
                    ProtectedObjectCount = 'int'
                    EmergencyAccessAccountCount = 'int'
                    ProtectedObjectBreakdown = 'object'
                    WhatIfActionsBlockedCount = 'int'
                    ApprovalActionsBlockedCount = 'int'
                    ProtectedObjects = 'object'
                    EmergencyAccessAccounts = 'object'
                    WhatIfActionsBlocked = 'object'
                    ApprovalActionsBlocked = 'object'
                    PotentialHygieneGaps = 'object'
                }
                Description = 'Emergency access governance pack containing ProtectedObject validation and emergency access account inventory'
            }
        }
        'ReleaseValidationReport' {
            return [PSCustomObject]@{
                SchemaVersion = '3.3'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'Passed', 'FailedChecks', 'Details'
                )
                Description = 'Release validation report assessing safety and quality gates'
            }
        }
        'OutputManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '3.4'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'RunId', 'GeneratedUtc',
                    'EngagementId', 'ClientName', 'OutputRoot', 'Files', 'Summary'
                )
                FieldTypes = @{
                    SchemaVersion = 'string'
                    ToolVersion = 'string'
                    RunId = 'string'
                    GeneratedUtc = 'string'
                    EngagementId = 'string'
                    ClientName = 'string'
                    OutputRoot = 'string'
                    Files = 'object'
                    Summary = 'object'
                }
                AllowedValues = @{
                    SchemaVersion = @('3.4','3.6')
                }
                Description = 'Output manifest cataloguing all run output files with hashes and sensitivity classifications'
            }
        }
        'EvidenceBundleManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '3.6'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'RunId', 'BundleId', 'GeneratedUtc',
                    'SourceOutputPath', 'BundleOutputPath', 'FileCount', 'TotalBytes', 'Files'
                )
                Description = 'Evidence bundle manifest linking run outputs for audit and chain-of-custody'
            }
        }
        'EvidenceHashManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '3.6'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'RunId', 'GeneratedUtc', 'Hashes'
                )
                Description = 'Evidence hash manifest containing SHA-256 hashes for all bundled files'
            }
        }
        'RedactionReport' {
            return [PSCustomObject]@{
                SchemaVersion = '3.6'
                RequiredFields = @(
                    'SchemaVersion', 'RunId', 'ProfileName', 'TokenCount', 'RedactedFileCount', 'GeneratedUtc'
                )
                Description = 'Redaction report summarising profile settings and token substitution counts'
            }
        }
        'ReplayValidationReport' {
            return [PSCustomObject]@{
                SchemaVersion = '3.6'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'RunId', 'GeneratedUtc',
                    'OverallPassed', 'Checks'
                )
                Description = 'Replay validation report verifying WhatIf/Approval/Execution chain integrity'
            }
        }
        'ApprovalDiffReport' {
            return [PSCustomObject]@{
                SchemaVersion = '3.6'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'RunId', 'GeneratedUtc',
                    'Passed', 'DiffItems', 'Summary'
                )
                Description = 'Approval diff report comparing WhatIf actions to approval manifest'
            }
        }
        'TraceabilityReport' {
            return [PSCustomObject]@{
                SchemaVersion = '3.6'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'RunId', 'GeneratedUtc',
                    'Entries', 'Summary'
                )
                Description = 'End-to-end traceability report mapping findings to WhatIf, Approval, and Execution records'
            }
        }
        'ClientHandoffManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '3.6'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'RunId', 'GeneratedUtc',
                    'EngagementId', 'ClientName', 'ValidationStatus',
                    'Sections', 'ClientSafeFiles', 'SensitiveFiles', 'Warnings'
                )
                Description = 'Client handoff package manifest identifying client-safe and sensitive outputs'
            }
        }
        'Rev35ReadinessReport' {
            return [PSCustomObject]@{
                SchemaVersion = '3.6'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'RunId', 'GeneratedUtc',
                    'ReadinessScore', 'NhiDetectorsImplemented', 'AgentIdentityDetectorsImplemented',
                    'Checks', 'Summary'
                )
                Description = 'Rev3.5 NHI readiness report documenting reserved namespaces and readiness checks'
            }
        }
    }
}

function Test-DecomObjectAgainstSchemaContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Object,
        [Parameter(Mandatory = $true)]
        [PSObject]$Contract
    )

    $result = [PSCustomObject]@{
        Passed = $true
        Errors = @()
        MissingFields = @()
        TypeMismatches = @()
        InvalidValues = @()
    }

    # Check required fields
    foreach ($field in $Contract.RequiredFields) {
        if (-not ($Object.PSObject.Properties.Name -contains $field)) {
            $result.MissingFields += $field
            $result.Passed = $false
        }
    }

    # Check field types where defined
    if ($Contract.FieldTypes) {
        foreach ($field in $Contract.FieldTypes.Keys) {
            if ($Object.PSObject.Properties.Name -contains $field) {
                $value = $Object.$field
                $expectedType = $Contract.FieldTypes[$field]

                $typeMatch = switch ($expectedType) {
                    'string' { $value -is [string] }
                    'int' { $value -is [int] }
                    'double' { $value -is [double] }
                    'bool' { $value -is [bool] }
                    default { $true }  # Assume correct for complex types
                }

                if (-not $typeMatch) {
                    $result.TypeMismatches += "${field}: expected $expectedType, got $($value.GetType().Name)"
                    $result.Passed = $false
                }
            }
        }
    }

    # Check allowed values where defined
    if ($Contract.AllowedValues) {
        foreach ($field in $Contract.AllowedValues.Keys) {
            if ($Object.PSObject.Properties.Name -contains $field) {
                $value = $Object.$field
                $allowed = $Contract.AllowedValues[$field]

                if (-not ($allowed -contains $value)) {
                    $result.InvalidValues += "${field}: value='$value' not in allowed values"
                    $result.Passed = $false
                }
            }
        }
    }

    return $result
}

function Export-DecomSchemaContractsMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $markdown = @"
# Schema Contracts

**SchemaVersion:** 3.0
**Generated:** $([DateTime]::UtcNow.ToString('o'))

## Finding Schema
"@

    $findingContract = Get-DecomSchemaContract -ObjectType 'Finding'
    $markdown += "### Required Fields`n"
    foreach ($field in $findingContract.RequiredFields) {
        $type = $findingContract.FieldTypes[$field]
        $desc = ""
        switch ($field) {
            'FindingId' { $desc = 'Unique identifier for the finding' }
            'Category' { $desc = 'Finding category (e.g., DEC-USER, DEC-APP)' }
            'Severity' { $desc = 'Finding severity level' }
            'RiskScore' { $desc = 'Numeric risk score (0-100)' }
            'Confidence' { $desc = 'Confidence in finding accuracy (0.0-1.0)' }
            'ObjectType' { $desc = 'Type of object (User, Group, Application, etc.)' }
            'ObjectId' { $desc = 'Object identifier' }
            'DisplayName' { $desc = 'Object display name' }
            'UserPrincipalName' { $desc = 'User principal name (for users)' }
            'Evidence' { $desc = 'Evidence supporting the finding' }
            'EvidenceSource' { $desc = 'Source of evidence' }
            'GraphEndpoint' { $desc = 'Microsoft Graph endpoint queried' }
            'RecommendedAction' { $desc = 'Recommended remediation action' }
            'RemediationMode' { $desc = 'How finding should be remediated' }
            'ConsultantNote' { $desc = 'Consultant notes or recommendations' }
        }
        $allowed = ""
        if ($findingContract.AllowedValues[$field]) {
            $allowed = " (Allowed: $($findingContract.AllowedValues[$field] -join ', '))"
        }
        $markdown += "- **${field}** ($type)${allowed}: $desc`n"
    }
    $markdown += "`n"

    # Add other schemas...
    $schemas = @('RunManifest','ApprovalManifest','ExecutionLog','ExecutionEvidence','BaselineComparison','ExecutiveSummary','ClientReadoutPackManifest','CatalogValidationReport','WriteReadinessReport')
    foreach ($schema in $schemas) {
        $contract = Get-DecomSchemaContract -ObjectType $schema
        $markdown += "## $schema Schema`n"
        $markdown += "### Required Fields`n"
        foreach ($field in $contract.RequiredFields) {
            $markdown += "- **${field}**`n"
        }
        $markdown += "`n"
    }

    $markdown += @"
---
© 2026 Albert Jee. All rights reserved.
"@

    $markdown | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-DecomOk "Schema contracts markdown: $OutputPath"
}

