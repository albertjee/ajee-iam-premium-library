#Requires -Version 5.1

function Get-DecomSchemaContract {
    [CmdletBinding()]
    param(
        [ValidateSet('Finding','RunManifest','ApprovalManifest','ExecutionLog','ExecutionEvidence','BaselineComparison','ExecutiveSummary','ClientReadoutPackManifest','CatalogValidationReport','WriteReadinessReport')]
        [string]$ObjectType
    )

    switch ($ObjectType) {
        'Finding' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
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
                    Confidence = 'double'
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
                }
                Description = 'Core finding object emitted during assessment'
            }
        }
        'RunManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'RunId', 'Mode', 'DemoMode', 'Summary', 'ExportPaths'
                )
                Description = 'Manifest summarizing assessment run and exports'
            }
        }
        'ApprovalManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName',
                    'RunId', 'ApprovedBy', 'ExpiresUtc', 'ApprovedActions'
                )
                Description = 'Client-approved remediation actions'
            }
        }
        'ExecutionLog' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'RunId',
                    'Log'
                )
                Description = 'Detailed execution log for remediation operations'
            }
        }
        'ExecutionEvidence' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId',
                    'Actions', 'Summary'
                )
                Description = 'Evidence of executed remediation actions'
            }
        }
        'BaselineComparison' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId',
                    'ComparisonResults', 'BaselineInfo'
                )
                Description = 'Comparison between current and baseline findings'
            }
        }
        'ExecutiveSummary' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'Coverage', 'Findings', 'Summary', 'BaselineComparison', 'RiskMovement'
                )
                Description = 'Executive summary of assessment findings'
            }
        }
        'ClientReadoutPackManifest' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'Items'
                )
                Description = 'Manifest of client readout pack contents'
            }
        }
        'CatalogValidationReport' {
            return [PSCustomObject]@{
                SchemaVersion = '2.5'
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
                SchemaVersion = '2.5'
                RequiredFields = @(
                    'SchemaVersion', 'ToolVersion', 'GeneratedUtc', 'EngagementId', 'ClientName', 'Assessor',
                    'ExecutionScopeRegistry', 'Rev3Candidates', 'Recommendation'
                )
                Description = 'Readiness assessment for Rev3.0 write expansion'
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

**SchemaVersion:** 2.5
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

function Export-DecomSchemaValidationJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Object,
        [Parameter(Mandatory = $true)]
        [PSObject]$Contract,
        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $validationResult = Test-DecomObjectAgainstSchemaContract -Object $Object -Contract $Contract

    $jsonObject = [PSCustomObject]@{
        SchemaVersion = '2.5'
        ToolVersion   = $Contract.SchemaVersion
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        ObjectType    = ($Contract | Get-Member -MemberType NoteProperty | Where-Object {$_.Name -eq 'Description'}).Value
        Passed        = $validationResult.Passed
        Errors        = $validationResult.Errors
        MissingFields = $validationResult.MissingFields
        TypeMismatches= $validationResult.TypeMismatches
        InvalidValues = $validationResult.InvalidValues
    }

    $json = $jsonObject | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $OutputPath -Encoding UTF8
    Write-DecomOk "Schema validation JSON: $OutputPath"
}