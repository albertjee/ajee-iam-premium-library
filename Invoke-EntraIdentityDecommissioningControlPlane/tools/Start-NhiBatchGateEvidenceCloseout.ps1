param(
    [Parameter(Mandatory = $true)]
    [string]$TenantId,

    [Parameter(Mandatory = $true)]
    [string]$BatchId,

    [Parameter(Mandatory = $true)]
    [string]$OutputRoot,

    [Parameter(Mandatory = $true)]
    [string]$PlanningRunRoot,

    [Parameter(Mandatory = $true)]
    [string]$DisableGateRunRoot,

    [Parameter(Mandatory = $true)]
    [string]$RollbackGateRunRoot,

    [string]$InventoryPath,

    [ValidateSet('Validate', 'Closeout')]
    [string]$Mode = 'Validate',

    [switch]$Strict,

    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function New-Finding {
    param(
        [Parameter(Mandatory = $true)][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$ArtifactPath,
        [string]$TargetId,
        [string]$TargetDisplayName
    )

    [pscustomobject]@{
        Severity          = $Severity
        Category          = $Category
        Message           = $Message
        ArtifactPath      = $ArtifactPath
        TargetId          = $TargetId
        TargetDisplayName = $TargetDisplayName
    }
}

function Test-SafeBatchId {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $false
    }

    if ($Value -like '*..*') {
        return $false
    }

    if ($Value -match '[\\/]' ) {
        return $false
    }

    if ($Value -notmatch '^[A-Za-z0-9._-]+$') {
        return $false
    }

    return $true
}

function Get-JsonDocumentsUnderRoot {
    param([Parameter(Mandatory = $true)][string]$RootPath)

    if (-not (Test-Path -LiteralPath $RootPath)) {
        return @()
    }

    Get-ChildItem -LiteralPath $RootPath -Recurse -File -Filter '*.json' | ForEach-Object {
        $raw = Get-Content -LiteralPath $_.FullName -Raw -Encoding UTF8
        $data = $raw | ConvertFrom-Json -Depth 32

        [pscustomobject]@{
            Path = $_.FullName
            Name = $_.Name
            Data = $data
            Raw  = $raw
        }
    }
}

function Get-FirstDocumentByPattern {
    param(
        [Parameter(Mandatory = $true)][object[]]$Documents,
        [Parameter(Mandatory = $true)][string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        $match = $Documents | Where-Object { $_.Name -match $pattern } | Select-Object -First 1
        if ($null -ne $match) {
            return $match
        }
    }

    return $null
}

function Test-HasProperty {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return $null -ne $Object -and $Object.PSObject.Properties.Match($Name).Count -gt 0
}

function Get-PropertyValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if (Test-HasProperty -Object $Object -Name $Name) {
        return $Object.$Name
    }

    return $null
}

function Get-TargetArrayFromDocument {
    param([Parameter(Mandatory = $true)][object]$Document)

    $data = $Document.Data
    if ($null -eq $data) {
        return @()
    }

    if ($data -is [System.Array]) {
        return @($data)
    }

    foreach ($candidateName in @('Targets', 'TargetList', 'TargetRecords', 'Items', 'Records', 'Value')) {
        $candidate = Get-PropertyValue -Object $data -Name $candidateName
        if ($candidate -is [System.Array]) {
            return @($candidate)
        }
    }

    if (Test-ValuePresence -Object $data -Names @('ServicePrincipalObjectId', 'ObjectId', 'TargetObjectId', 'Id', 'TargetId', 'AppId', 'ApplicationId')) {
        return @($data)
    }

    return @()
}

function Get-IdentityString {
    param([Parameter(Mandatory = $true)][object]$Target)

    foreach ($name in @('ServicePrincipalObjectId', 'ObjectId', 'TargetObjectId', 'Id', 'TargetId')) {
        $value = Get-PropertyValue -Object $Target -Name $name
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            return [string]$value
        }
    }

    return $null
}

function Get-AppIdString {
    param([Parameter(Mandatory = $true)][object]$Target)

    foreach ($name in @('AppId', 'ApplicationId')) {
        $value = Get-PropertyValue -Object $Target -Name $name
        if (-not [string]::IsNullOrWhiteSpace([string]$value)) {
            return [string]$value
        }
    }

    return $null
}

function Get-BooleanValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $value = Get-PropertyValue -Object $Object -Name $Name
    if ($null -eq $value) {
        return $null
    }

    if ($value -is [bool]) {
        return [bool]$value
    }

    if ($value -is [string]) {
        switch ($value.Trim().ToLowerInvariant()) {
            'true' { return $true }
            'false' { return $false }
        }
    }

    throw "$Name must be a strict boolean value."
}

function Get-IntegerValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $value = Get-PropertyValue -Object $Object -Name $Name
    if ($null -eq $value) {
        return $null
    }

    try {
        return [int]$value
    } catch {
        return $null
    }
}

function Test-ModeValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$AllowedValues
    )

    if (-not (Test-HasProperty -Object $Object -Name $Name)) {
        return $false
    }

    $value = [string](Get-PropertyValue -Object $Object -Name $Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        return $false
    }

    foreach ($allowedValue in $AllowedValues) {
        if ($value -ieq $allowedValue) {
            return $true
        }
    }

    return $false
}

function Test-ValuePresence {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string[]]$Names
    )

    foreach ($name in $Names) {
        $value = Get-PropertyValue -Object $Object -Name $name
        if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
            return $true
        }
    }

    return $false
}

function Add-Finding {
    param(
        [Parameter(Mandatory = $true)][object]$Findings,
        [Parameter(Mandatory = $true)][string]$Severity,
        [Parameter(Mandatory = $true)][string]$Category,
        [Parameter(Mandatory = $true)][string]$Message,
        [string]$ArtifactPath,
        [string]$TargetId,
        [string]$TargetDisplayName
    )

    $Findings.Add((New-Finding -Severity $Severity -Category $Category -Message $Message -ArtifactPath $ArtifactPath -TargetId $TargetId -TargetDisplayName $TargetDisplayName))
}

function Get-FirstTargetDocument {
    param([Parameter(Mandatory = $true)][object[]]$Documents)

    foreach ($document in $Documents) {
        $targets = Get-TargetArrayFromDocument -Document $document
        if (@($targets).Count -gt 0) {
            return $document
        }
    }

    return $null
}

function Test-RequiredSummaryFields {
    param(
        [Parameter(Mandatory = $true)][object]$Document,
        [Parameter(Mandatory = $true)][string[]]$RequiredFields
    )

    foreach ($field in $RequiredFields) {
        if (-not (Test-HasProperty -Object $Document.Data -Name $field)) {
            return $false
        }
    }

    return $true
}

if (-not (Test-SafeBatchId -Value $BatchId)) {
    throw "Unsafe BatchId '$BatchId'."
}

$startedUtc = (Get-Date).ToUniversalTime().ToString('o')
$allFindings = [System.Collections.Generic.List[object]]::new()

$planningDocs = @(Get-JsonDocumentsUnderRoot -RootPath $PlanningRunRoot)
$disableDocs = @(Get-JsonDocumentsUnderRoot -RootPath $DisableGateRunRoot)
$rollbackDocs = @(Get-JsonDocumentsUnderRoot -RootPath $RollbackGateRunRoot)

if ($planningDocs.Count -eq 0) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Planning evidence bundle is missing.' -ArtifactPath $PlanningRunRoot
}

if ($disableDocs.Count -eq 0) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Disable-gate evidence bundle is missing.' -ArtifactPath $DisableGateRunRoot
}

if ($rollbackDocs.Count -eq 0) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Rollback-gate evidence bundle is missing.' -ArtifactPath $RollbackGateRunRoot
}

foreach ($document in @($planningDocs + $disableDocs + $rollbackDocs)) {
    $documentTenantId = Get-PropertyValue -Object $document.Data -Name 'TenantId'
    if (-not [string]::IsNullOrWhiteSpace([string]$documentTenantId) -and [string]$documentTenantId -ne $TenantId) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'TenantMismatch' -Message 'Artifact TenantId does not match the requested TenantId.' -ArtifactPath $document.Path
    }

    $documentBatchId = Get-PropertyValue -Object $document.Data -Name 'BatchId'
    if (-not [string]::IsNullOrWhiteSpace([string]$documentBatchId) -and [string]$documentBatchId -ne $BatchId) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'BatchMismatch' -Message 'Artifact BatchId does not match the requested BatchId.' -ArtifactPath $document.Path
    }
}

$planningSummaryDoc = Get-FirstDocumentByPattern -Documents $planningDocs -Patterns @('summary', 'planning')
$planningTargetsDoc = Get-FirstTargetDocument -Documents $planningDocs
$planningReadinessDoc = Get-FirstDocumentByPattern -Documents $planningDocs -Patterns @('readiness', 'whatif', 'plan')

if ($null -eq $planningSummaryDoc) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Planning summary artifact not found.' -ArtifactPath $PlanningRunRoot
}

if ($null -eq $planningTargetsDoc) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Planning target artifact not found.' -ArtifactPath $PlanningRunRoot
}

if ($null -eq $planningReadinessDoc) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Planning readiness / WhatIf artifact not found.' -ArtifactPath $PlanningRunRoot
}

$planningTargets = @()
if ($null -ne $planningTargetsDoc) {
    $planningTargets = @(Get-TargetArrayFromDocument -Document $planningTargetsDoc)
}

if ($null -ne $planningSummaryDoc -and -not (Test-RequiredSummaryFields -Document $planningSummaryDoc -RequiredFields @('TenantId', 'BatchId'))) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Planning summary is missing TenantId or BatchId.' -ArtifactPath $planningSummaryDoc.Path
}

if ($null -ne $planningSummaryDoc) {
    $planningSummaryData = $planningSummaryDoc.Data
    foreach ($name in @('ApprovedAction', 'Mode', 'FinalDeleteApproved', 'CleanupApproved', 'SafetyGatePassed', 'TargetCount')) {
        if (-not (Test-HasProperty -Object $planningSummaryData -Name $name)) {
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message "Planning summary is missing $name." -ArtifactPath $planningSummaryDoc.Path
        }
    }

    if ([string](Get-PropertyValue -Object $planningSummaryData -Name 'ApprovedAction') -ne 'ReversibleDisable') {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Planning summary ApprovedAction is not ReversibleDisable.' -ArtifactPath $planningSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $planningSummaryData -Name 'FinalDeleteApproved') -ne $false) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Planning summary must not approve final delete.' -ArtifactPath $planningSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $planningSummaryData -Name 'CleanupApproved') -ne $false) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Planning summary must not approve cleanup.' -ArtifactPath $planningSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $planningSummaryData -Name 'SafetyGatePassed') -ne $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Planning summary safety gate did not pass.' -ArtifactPath $planningSummaryDoc.Path
    }

    if (-not (Test-ModeValue -Object $planningSummaryData -Name 'Mode' -AllowedValues @('WhatIf', 'Readiness'))) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Planning summary Mode must be WhatIf or Readiness.' -ArtifactPath $planningSummaryDoc.Path
    }
}

if ($null -ne $planningReadinessDoc) {
    $readinessData = $planningReadinessDoc.Data
    if (-not (Test-ValuePresence -Object $readinessData -Names @('ReadinessStatus', 'WhatIf', 'WhatIfMode', 'PlanningReadinessStatus', 'ValidationState'))) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Planning readiness / WhatIf artifact does not contain a readiness indicator.' -ArtifactPath $planningReadinessDoc.Path
    }
}

if ($null -ne $planningTargetsDoc) {
    $planningTargetArray = @(Get-TargetArrayFromDocument -Document $planningTargetsDoc)
    foreach ($target in $planningTargetArray) {
        $targetId = Get-IdentityString -Target $target
        $displayName = [string](Get-PropertyValue -Object $target -Name 'DisplayName')
        if (-not (Test-ValuePresence -Object $target -Names @('ValidationStatus', 'ValidationState'))) {
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Planning target is missing per-target validation status.' -ArtifactPath $planningTargetsDoc.Path -TargetId $targetId -TargetDisplayName $displayName
        }

        $mutationEligible = Get-BooleanValue -Object $target -Name 'MutationEligible'
        $evidenceOnly = Get-BooleanValue -Object $target -Name 'EvidenceOnly'
        $disposition = [string](Get-PropertyValue -Object $target -Name 'Disposition')
        if (($null -eq $mutationEligible -and $null -eq $evidenceOnly -and [string]::IsNullOrWhiteSpace($disposition))) {
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Planning target is missing MutationEligible / EvidenceOnly disposition.' -ArtifactPath $planningTargetsDoc.Path -TargetId $targetId -TargetDisplayName $displayName
        }
    }
}

foreach ($document in $planningDocs) {
    $data = $document.Data
    if ($null -ne (Get-BooleanValue -Object $data -Name 'LiveMutationPerformed') -and (Get-BooleanValue -Object $data -Name 'LiveMutationPerformed')) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'LiveMutationDetected' -Message 'Planning bundle reports live mutation performed.' -ArtifactPath $document.Path
    }

    $childCallCount = Get-IntegerValue -Object $data -Name 'ChildCallCount'
    if ($null -ne $childCallCount -and $childCallCount -gt 0) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'LiveMutationDetected' -Message 'Planning bundle reports live child calls.' -ArtifactPath $document.Path
    }

    if ((Get-BooleanValue -Object $data -Name 'CleanupExecuted') -eq $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'LiveMutationDetected' -Message 'Planning bundle reports cleanup activity.' -ArtifactPath $document.Path
    }

    if ((Get-BooleanValue -Object $data -Name 'FinalDeleteExecuted') -eq $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'LiveMutationDetected' -Message 'Planning bundle reports final delete activity.' -ArtifactPath $document.Path
    }
}

$disableSummaryDoc = Get-FirstDocumentByPattern -Documents $disableDocs -Patterns @('summary', 'disable', 'gate')
$disableTargetsDoc = Get-FirstTargetDocument -Documents $disableDocs

if ($null -eq $disableSummaryDoc) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Disable-gate summary artifact not found.' -ArtifactPath $DisableGateRunRoot
}

if ($null -eq $disableTargetsDoc) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Disable-gate target artifact not found.' -ArtifactPath $DisableGateRunRoot
}

if ($null -ne $disableSummaryDoc) {
    $disableData = $disableSummaryDoc.Data
    foreach ($name in @('TenantId', 'BatchId', 'ApprovedAction', 'Mode', 'ExecutionStatus', 'ExecutionNotPerformed', 'ChildCallCount', 'LiveMutationPerformed', 'FinalDeleteApproved', 'CleanupApproved', 'SafetyGatePassed', 'TargetCount', 'EligibleTargetCount', 'BlockedTargetCount')) {
        if (-not (Test-HasProperty -Object $disableData -Name $name)) {
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message "Disable-gate summary is missing $name." -ArtifactPath $disableSummaryDoc.Path
        }
    }

    if ([string](Get-PropertyValue -Object $disableData -Name 'ApprovedAction') -ne 'ReversibleDisable') {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate summary ApprovedAction is not ReversibleDisable.' -ArtifactPath $disableSummaryDoc.Path
    }

    if ([string](Get-PropertyValue -Object $disableData -Name 'ExecutionStatus') -notmatch '^GateOnly') {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate execution status is not gate-only.' -ArtifactPath $disableSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $disableData -Name 'ExecutionNotPerformed') -ne $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate execution claims live execution occurred.' -ArtifactPath $disableSummaryDoc.Path
    }

    if ((Get-IntegerValue -Object $disableData -Name 'ChildCallCount') -ne 0) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate child call count is not zero.' -ArtifactPath $disableSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $disableData -Name 'LiveMutationPerformed') -ne $false) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate claims a live mutation was performed.' -ArtifactPath $disableSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $disableData -Name 'FinalDeleteApproved') -ne $false) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate must not approve final delete.' -ArtifactPath $disableSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $disableData -Name 'CleanupApproved') -ne $false) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate must not approve cleanup.' -ArtifactPath $disableSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $disableData -Name 'SafetyGatePassed') -ne $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate summary safety gate did not pass.' -ArtifactPath $disableSummaryDoc.Path
    }

    if (-not (Test-ModeValue -Object $disableData -Name 'Mode' -AllowedValues @('Execute'))) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Disable-gate summary Mode must be Execute.' -ArtifactPath $disableSummaryDoc.Path
    }

    foreach ($name in @('ApprovalManifestPath', 'PreSnapshotPath', 'RollbackPackagePath', 'ChangedObjectManifestPath')) {
        if (-not (Test-HasProperty -Object $disableData -Name $name)) {
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message "Disable-gate summary is missing $name." -ArtifactPath $disableSummaryDoc.Path
        }
    }

    $disableTargetCount = Get-IntegerValue -Object $disableData -Name 'TargetCount'
    $disableEligibleCount = Get-IntegerValue -Object $disableData -Name 'EligibleTargetCount'
    $disableBlockedCount = Get-IntegerValue -Object $disableData -Name 'BlockedTargetCount'
    if ($null -ne $disableTargetCount -and ($disableEligibleCount + $disableBlockedCount) -gt $disableTargetCount) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate eligible plus blocked counts exceed target count.' -ArtifactPath $disableSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $disableData -Name 'ChangedByPriorBatchRun') -eq $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Disable-gate claims changed-by-prior-batch-run without proof of prior real mutation.' -ArtifactPath $disableSummaryDoc.Path
    }
}

if ($null -ne $disableTargetsDoc -and @($planningTargets).Count -gt 0) {
    $disableTargets = @(Get-TargetArrayFromDocument -Document $disableTargetsDoc)
    if (@($disableTargets).Count -lt @($planningTargets).Count) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Disable-gate target count is smaller than planning target count.' -ArtifactPath $disableTargetsDoc.Path
    }
}

$rollbackSummaryDoc = Get-FirstDocumentByPattern -Documents $rollbackDocs -Patterns @('summary', 'rollback', 'gate')
$rollbackTargetsDoc = Get-FirstTargetDocument -Documents $rollbackDocs
$rollbackPackageDoc = Get-FirstDocumentByPattern -Documents $rollbackDocs -Patterns @('rollback-package', 'rollbackpackage', 'package')

if ($null -eq $rollbackSummaryDoc) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Rollback-gate summary artifact not found.' -ArtifactPath $RollbackGateRunRoot
}

if ($null -eq $rollbackTargetsDoc) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Rollback-gate target artifact not found.' -ArtifactPath $RollbackGateRunRoot
}

if ($null -ne $rollbackSummaryDoc) {
    $rollbackData = $rollbackSummaryDoc.Data
    foreach ($name in @('TenantId', 'BatchId', 'ApprovedAction', 'Mode', 'ExecutionStatus', 'ExecutionNotPerformed', 'ChildCallCount', 'LiveMutationPerformed', 'FinalDeleteApproved', 'CleanupApproved', 'SafetyGatePassed', 'TargetCount', 'EligibleTargetCount', 'BlockedTargetCount')) {
        if (-not (Test-HasProperty -Object $rollbackData -Name $name)) {
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message "Rollback-gate summary is missing $name." -ArtifactPath $rollbackSummaryDoc.Path
        }
    }

    if ([string](Get-PropertyValue -Object $rollbackData -Name 'ApprovedAction') -ne 'RollbackDisable') {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate summary ApprovedAction is not RollbackDisable.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    if ([string](Get-PropertyValue -Object $rollbackData -Name 'ExecutionStatus') -notmatch '^GateOnly') {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate execution status is not gate-only.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $rollbackData -Name 'ExecutionNotPerformed') -ne $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate execution claims live execution occurred.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    if ((Get-IntegerValue -Object $rollbackData -Name 'ChildCallCount') -ne 0) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate child call count is not zero.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $rollbackData -Name 'LiveMutationPerformed') -ne $false) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate claims a live mutation was performed.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $rollbackData -Name 'FinalDeleteApproved') -ne $false) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate must not approve final delete.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $rollbackData -Name 'CleanupApproved') -ne $false) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate must not approve cleanup.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    if ((Get-BooleanValue -Object $rollbackData -Name 'SafetyGatePassed') -ne $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate summary safety gate did not pass.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    if (-not (Test-ModeValue -Object $rollbackData -Name 'Mode' -AllowedValues @('Execute'))) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Rollback-gate summary Mode must be Execute.' -ArtifactPath $rollbackSummaryDoc.Path
    }

    $rollbackTargetCount = Get-IntegerValue -Object $rollbackData -Name 'TargetCount'
    $rollbackEligibleCount = Get-IntegerValue -Object $rollbackData -Name 'EligibleTargetCount'
    $rollbackBlockedCount = Get-IntegerValue -Object $rollbackData -Name 'BlockedTargetCount'
    if ($null -ne $rollbackTargetCount -and ($rollbackEligibleCount + $rollbackBlockedCount) -gt $rollbackTargetCount) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Rollback-gate eligible plus blocked counts exceed target count.' -ArtifactPath $rollbackSummaryDoc.Path
    }
}

if ($null -ne $rollbackPackageDoc) {
    $rollbackPackageData = $rollbackPackageDoc.Data
    if ((Get-PropertyValue -Object $rollbackPackageData -Name 'TenantId') -ne $TenantId) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'TenantMismatch' -Message 'Rollback package TenantId does not match the requested TenantId.' -ArtifactPath $rollbackPackageDoc.Path
    }
}

if ($null -ne $rollbackSummaryDoc -and -not (Test-HasProperty -Object $rollbackSummaryDoc.Data -Name 'PriorAccountStateCaptured')) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Rollback-gate summary does not state whether prior account state was captured.' -ArtifactPath $rollbackSummaryDoc.Path
}

if ($Strict.IsPresent -and $null -ne $rollbackSummaryDoc) {
    $priorCaptured = Get-BooleanValue -Object $rollbackSummaryDoc.Data -Name 'PriorAccountStateCaptured'
    if ($priorCaptured -ne $true) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Strict mode requires prior account state capture for rollback correctness.' -ArtifactPath $rollbackSummaryDoc.Path
    }
}

if ($null -ne $rollbackTargetsDoc -and @($planningTargets).Count -gt 0) {
    $rollbackTargets = @(Get-TargetArrayFromDocument -Document $rollbackTargetsDoc)
    if (@($rollbackTargets).Count -lt @($planningTargets).Count) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Rollback-gate target count is smaller than planning target count.' -ArtifactPath $rollbackTargetsDoc.Path
    }
}

if ($null -ne $rollbackDocs) {
    foreach ($document in $rollbackDocs) {
        $data = $document.Data
        if ((Get-BooleanValue -Object $data -Name 'LiveMutationPerformed') -eq $true) {
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'LiveMutationDetected' -Message 'Rollback bundle reports live mutation performed.' -ArtifactPath $document.Path
        }

        if ((Get-IntegerValue -Object $data -Name 'ChildCallCount') -gt 0) {
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'LiveMutationDetected' -Message 'Rollback bundle reports child calls.' -ArtifactPath $document.Path
        }
    }
}

$planningTargetMap = @()
$disableTargetMap = @()
$rollbackTargetMap = @()

if ($planningTargets.Count -gt 0) {
    $planningTargetMap = @($planningTargets)
}

if ($null -ne $disableTargetsDoc) {
    $disableTargetMap = @(Get-TargetArrayFromDocument -Document $disableTargetsDoc)
}

if ($null -ne $rollbackTargetsDoc) {
    $rollbackTargetMap = @(Get-TargetArrayFromDocument -Document $rollbackTargetsDoc)
}

$targetRows = New-Object System.Collections.Generic.List[object]
$closeoutReadyCount = 0
$blockedCount = 0
$evidenceOnlyCount = 0
$incompleteEvidenceCount = 0
$identityMismatchCount = 0
$tenantMismatchCount = 0
$batchMismatchCount = 0
$gateOnlyConfirmedCount = 0
$liveMutationDetectedCount = 0

for ($i = 0; $i -lt $planningTargetMap.Count; $i++) {
    $planningTarget = $planningTargetMap[$i]
    $disableTarget = if ($i -lt $disableTargetMap.Count) { $disableTargetMap[$i] } else { $null }
    $rollbackTarget = if ($i -lt $rollbackTargetMap.Count) { $rollbackTargetMap[$i] } else { $null }

    $targetId = Get-IdentityString -Target $planningTarget
    $displayName = [string](Get-PropertyValue -Object $planningTarget -Name 'DisplayName')
    $planningAppId = Get-AppIdString -Target $planningTarget
    $planningObjectType = [string](Get-PropertyValue -Object $planningTarget -Name 'ObjectType')
    $planningTargetType = [string](Get-PropertyValue -Object $planningTarget -Name 'TargetType')
    $planningDisposition = [string](Get-PropertyValue -Object $planningTarget -Name 'Disposition')
    $planningEvidenceOnly = (Get-BooleanValue -Object $planningTarget -Name 'EvidenceOnly') -eq $true -or $planningDisposition -match 'EvidenceOnly'
    $planningMutationEligible = (Get-BooleanValue -Object $planningTarget -Name 'MutationEligible') -eq $true -or $planningDisposition -match 'Eligible'

    $closeoutDisposition = 'CloseoutReady'
    $gateOnlyConfirmed = $false
    $targetFindingCountBefore = $allFindings.Count
    $targetBlocked = $false
    $targetWarning = $false

    if ($planningEvidenceOnly) {
        $closeoutDisposition = 'EvidenceOnly'
        $evidenceOnlyCount++
    } elseif (-not $planningMutationEligible) {
        $closeoutDisposition = 'Blocked'
        $targetBlocked = $true
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Planning target is not mutation eligible.' -TargetId $targetId -TargetDisplayName $displayName
    }

    if ($null -eq $disableTarget -or $null -eq $rollbackTarget) {
        $closeoutDisposition = 'MissingArtifact'
        $targetBlocked = $true
        Add-Finding -Findings $allFindings -Severity 'Error' -Category 'MissingArtifact' -Message 'Target is missing from one or more gate evidence bundles.' -TargetId $targetId -TargetDisplayName $displayName
    } else {
        $disableId = Get-IdentityString -Target $disableTarget
        $rollbackId = Get-IdentityString -Target $rollbackTarget
        $disableAppId = Get-AppIdString -Target $disableTarget
        $rollbackAppId = Get-AppIdString -Target $rollbackTarget

        if ($null -ne $targetId -and $null -ne $disableId -and $targetId -ne $disableId) {
            $closeoutDisposition = 'IdentityMismatch'
            $identityMismatchCount++
            $targetBlocked = $true
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IdentityMismatch' -Message 'Disable-gate target ServicePrincipalObjectId does not match planning evidence.' -TargetId $targetId -TargetDisplayName $displayName
        }

        if ($null -ne $targetId -and $null -ne $rollbackId -and $targetId -ne $rollbackId) {
            $closeoutDisposition = 'IdentityMismatch'
            $identityMismatchCount++
            $targetBlocked = $true
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IdentityMismatch' -Message 'Rollback-gate target ServicePrincipalObjectId does not match planning evidence.' -TargetId $targetId -TargetDisplayName $displayName
        }

        if ($null -ne $planningAppId -and $null -ne $disableAppId -and $planningAppId -ne $disableAppId) {
            $closeoutDisposition = 'IdentityMismatch'
            $identityMismatchCount++
            $targetBlocked = $true
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IdentityMismatch' -Message 'Disable-gate target AppId does not match planning evidence.' -TargetId $targetId -TargetDisplayName $displayName
        }

        if ($null -ne $planningAppId -and $null -ne $rollbackAppId -and $planningAppId -ne $rollbackAppId) {
            $closeoutDisposition = 'IdentityMismatch'
            $identityMismatchCount++
            $targetBlocked = $true
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IdentityMismatch' -Message 'Rollback-gate target AppId does not match planning evidence.' -TargetId $targetId -TargetDisplayName $displayName
        }

        $disableStatus = [string](Get-PropertyValue -Object $disableTarget -Name 'ExecutionStatus')
        $rollbackStatus = [string](Get-PropertyValue -Object $rollbackTarget -Name 'ExecutionStatus')
        $disableNotPerformed = (Get-BooleanValue -Object $disableTarget -Name 'ExecutionNotPerformed') -eq $true
        $rollbackNotPerformed = (Get-BooleanValue -Object $rollbackTarget -Name 'ExecutionNotPerformed') -eq $true
        $disableChildCalls = Get-IntegerValue -Object $disableTarget -Name 'ChildCallCount'
        $rollbackChildCalls = Get-IntegerValue -Object $rollbackTarget -Name 'ChildCallCount'
        $disableLive = (Get-BooleanValue -Object $disableTarget -Name 'LiveMutationPerformed') -eq $true
        $rollbackLive = (Get-BooleanValue -Object $rollbackTarget -Name 'LiveMutationPerformed') -eq $true

        if ($disableStatus -match '^GateOnly' -and $rollbackStatus -match '^GateOnly' -and $disableNotPerformed -and $rollbackNotPerformed -and ($disableChildCalls -eq 0) -and ($rollbackChildCalls -eq 0) -and (-not $disableLive) -and (-not $rollbackLive)) {
            $disableSafetyGatePassed = (Get-BooleanValue -Object $disableTarget -Name 'SafetyGatePassed') -eq $true
            $rollbackSafetyGatePassed = (Get-BooleanValue -Object $rollbackTarget -Name 'SafetyGatePassed') -eq $true
            if (-not $disableSafetyGatePassed -or -not $rollbackSafetyGatePassed) {
                $closeoutDisposition = 'Blocked'
                $targetBlocked = $true
                Add-Finding -Findings $allFindings -Severity 'Error' -Category 'Blocked' -Message 'Target evidence reports a failed safety gate.' -TargetId $targetId -TargetDisplayName $displayName
            } else {
                $gateOnlyConfirmed = $true
                $gateOnlyConfirmedCount++
            }
        } else {
            $closeoutDisposition = 'Blocked'
            $targetBlocked = $true
        }

        if ($disableLive -or $rollbackLive -or (($disableChildCalls -gt 0) -or ($rollbackChildCalls -gt 0))) {
            $liveMutationDetectedCount++
            $closeoutDisposition = 'Blocked'
            $targetBlocked = $true
            Add-Finding -Findings $allFindings -Severity 'Error' -Category 'LiveMutationDetected' -Message 'Target evidence contains live mutation indicators.' -TargetId $targetId -TargetDisplayName $displayName
        }
    }

    $rollbackPackageStateKnown = $false
    $rollbackPriorStateKnown = $false
    if ($null -ne $rollbackTarget) {
        $rollbackPriorStateKnown = Test-ValuePresence -Object $rollbackTarget -Names @('PriorEnabledState', 'PreviousEnabledState', 'PriorAccountStateCaptured')
        if (-not $rollbackPriorStateKnown) {
            $incompleteEvidenceCount++
            if ($Strict.IsPresent) {
                if ($closeoutDisposition -in @('CloseoutReady', 'EvidenceOnly', 'WarningOnly')) {
                    $closeoutDisposition = 'IncompleteEvidence'
                }
                $targetBlocked = $true
                Add-Finding -Findings $allFindings -Severity 'Error' -Category 'IncompleteEvidence' -Message 'Rollback evidence does not capture prior account state for this target.' -TargetId $targetId -TargetDisplayName $displayName
            } else {
                if ($closeoutDisposition -in @('CloseoutReady', 'EvidenceOnly')) {
                    $closeoutDisposition = 'WarningOnly'
                    $targetWarning = $true
                }
                Add-Finding -Findings $allFindings -Severity 'Warning' -Category 'IncompleteEvidence' -Message 'Rollback evidence does not capture prior account state for this target.' -TargetId $targetId -TargetDisplayName $displayName
            }
        } else {
            $rollbackPackageStateKnown = $true
        }
    }

    if ($gateOnlyConfirmed -and $closeoutDisposition -eq 'CloseoutReady' -and -not $planningEvidenceOnly) {
        $closeoutReadyCount++
    }

    if ($targetBlocked -and $allFindings.Count -eq $targetFindingCountBefore) {
        Add-Finding -Findings $allFindings -Severity 'Error' -Category $closeoutDisposition -Message 'Target closeout disposition is blocked.' -TargetId $targetId -TargetDisplayName $displayName
    }

    $targetRows.Add([pscustomobject]@{
        Index                     = $i
        TenantId                  = $TenantId
        BatchId                   = $BatchId
        ServicePrincipalObjectId  = $targetId
        AppId                     = $planningAppId
        DisplayName               = $displayName
        ObjectType                = $planningObjectType
        TargetType                = $planningTargetType
        PlanningDisposition       = if ($planningEvidenceOnly) { 'EvidenceOnly' } elseif ($planningMutationEligible) { 'EligibleGateOnly' } else { 'Blocked' }
        DisableExecutionStatus    = if ($null -ne $disableTarget) { [string](Get-PropertyValue -Object $disableTarget -Name 'ExecutionStatus') } else { $null }
        RollbackExecutionStatus   = if ($null -ne $rollbackTarget) { [string](Get-PropertyValue -Object $rollbackTarget -Name 'ExecutionStatus') } else { $null }
        GateOnlyConfirmed         = $gateOnlyConfirmed
        PriorStateCaptured        = $rollbackPriorStateKnown
        CloseoutDisposition       = $closeoutDisposition
        Notes                     = if ($planningEvidenceOnly) { 'Evidence-only target retained for continuity validation only.' } elseif ($gateOnlyConfirmed) { 'Gate-only evidence confirmed without tenant mutation.' } elseif ($targetWarning) { 'Closeout continues with warning-only incomplete evidence.' } else { 'Closeout blocked by evidence or continuity issue.' }
    })
}

$tenantMismatchCount = @($allFindings | Where-Object { $_.Category -eq 'TenantMismatch' }).Count
$batchMismatchCount = @($allFindings | Where-Object { $_.Category -eq 'BatchMismatch' }).Count
$identityMismatchCount = @($allFindings | Where-Object { $_.Category -eq 'IdentityMismatch' }).Count
$incompleteEvidenceCount = @($allFindings | Where-Object { $_.Category -eq 'IncompleteEvidence' }).Count
$blockedCount = @($targetRows | Where-Object { $_.CloseoutDisposition -in @('Blocked', 'MissingArtifact', 'IdentityMismatch', 'IncompleteEvidence') }).Count
$sourceBlockingFindingCount = @($allFindings | Where-Object { $_.Severity -in @('Error', 'Critical') }).Count

$expectedTenantIds = @()
foreach ($document in @($planningSummaryDoc, $disableSummaryDoc, $rollbackSummaryDoc, $rollbackPackageDoc)) {
    if ($null -ne $document -and (Test-HasProperty -Object $document.Data -Name 'TenantId')) {
        $expectedTenantIds += [string](Get-PropertyValue -Object $document.Data -Name 'TenantId')
    }
}

if (@($expectedTenantIds).Count -gt 0 -and @($expectedTenantIds | Where-Object { $_ -ne $TenantId }).Count -gt 0) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'TenantMismatch' -Message 'One or more artifacts have a TenantId that does not match the requested TenantId.'
}

if ($null -ne $planningSummaryDoc -and [string](Get-PropertyValue -Object $planningSummaryDoc.Data -Name 'BatchId') -ne $BatchId) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'BatchMismatch' -Message 'Planning summary BatchId does not match the requested BatchId.' -ArtifactPath $planningSummaryDoc.Path
}

if ($null -ne $disableSummaryDoc -and [string](Get-PropertyValue -Object $disableSummaryDoc.Data -Name 'BatchId') -ne $BatchId) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'BatchMismatch' -Message 'Disable-gate summary BatchId does not match the requested BatchId.' -ArtifactPath $disableSummaryDoc.Path
}

if ($null -ne $rollbackSummaryDoc -and [string](Get-PropertyValue -Object $rollbackSummaryDoc.Data -Name 'BatchId') -ne $BatchId) {
    Add-Finding -Findings $allFindings -Severity 'Error' -Category 'BatchMismatch' -Message 'Rollback-gate summary BatchId does not match the requested BatchId.' -ArtifactPath $rollbackSummaryDoc.Path
}

$safetyGatePassed = ($blockedCount -eq 0 -and $sourceBlockingFindingCount -eq 0)
$closeoutStatus = if ($safetyGatePassed) { 'CloseoutReady' } else { 'CloseoutBlocked' }

$completedUtc = (Get-Date).ToUniversalTime().ToString('o')
$safeBatchId = $BatchId
$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$outputPath = Join-Path -Path $OutputRoot -ChildPath ("rev444-batch-gate-closeout/{0}/batch-{1}" -f $timestamp, $safeBatchId)
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null

$summaryPath = Join-Path $outputPath 'rev444-batch-gate-closeout-summary.json'
$findingsPath = Join-Path $outputPath 'rev444-batch-gate-closeout-findings.json'
$targetsPath = Join-Path $outputPath 'rev444-batch-gate-closeout-targets.json'
$runbookPath = Join-Path $outputPath 'rev444-batch-gate-closeout-operator-runbook.md'

$summary = [pscustomobject]@{
    SchemaVersion               = '4.44'
    ToolVersion                 = 'Rev4.44'
    TenantId                    = $TenantId
    BatchId                     = $BatchId
    Mode                        = $Mode
    StartedUtc                  = $startedUtc
    CompletedUtc                = $completedUtc
    PlanningRunRoot             = $PlanningRunRoot
    DisableGateRunRoot          = $DisableGateRunRoot
    RollbackGateRunRoot         = $RollbackGateRunRoot
    TargetCount                 = @($planningTargets).Count
    CloseoutReadyCount          = $closeoutReadyCount
    BlockedCount                = $blockedCount
    EvidenceOnlyCount           = $evidenceOnlyCount
    IncompleteEvidenceCount     = $incompleteEvidenceCount
    IdentityMismatchCount       = $identityMismatchCount
    TenantMismatchCount         = $tenantMismatchCount
    BatchMismatchCount          = $batchMismatchCount
    GateOnlyConfirmedCount      = $gateOnlyConfirmedCount
    LiveMutationDetectedCount   = $liveMutationDetectedCount
    SafetyGatePassed            = $safetyGatePassed
    CloseoutStatus              = $closeoutStatus
    ArtifactPaths               = [pscustomobject]@{
        SummaryPath = $summaryPath
        FindingsPath = $findingsPath
        TargetsPath  = $targetsPath
        RunbookPath  = $runbookPath
        InputPaths   = @($PlanningRunRoot, $DisableGateRunRoot, $RollbackGateRunRoot)
    }
    NoTenantMutationPerformed   = $true
    LiveExecutionSupported      = $false
    ExecutionModel              = 'GateOnlyEvidenceCloseout'
    ArtifactCount               = @(@($summaryPath, $findingsPath, $targetsPath, $runbookPath) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count
}

$runbook = @"
# Rev4.44 Batch Gate Evidence Closeout

## Purpose
Rev4.44 validates artifact continuity across Rev4.41 planning evidence, Rev4.42 disable-gate evidence, and Rev4.43 rollback-gate evidence.

## What It Validates
- Batch identity continuity.
- Tenant identity continuity.
- Target identity continuity for ServicePrincipalObjectId and AppId when present.
- Gate-only execution markers in Rev4.42 and Rev4.43.
- Evidence-only targets remain evidence-only and are not treated as mutation-ready.
- Rollback package prior-state evidence when it is available.

## What It Does Not Do
- No tenant mutation.
- No live disable.
- No live rollback.
- No cleanup.
- No delete.
- No final delete.
- No direct child lifecycle execution.
- No approval for live mutation.
- Live batch execution out of scope.

## Status Interpretation
- `CloseoutReady`: evidence continuity is satisfied and no blocking findings remain.
- `CloseoutBlocked`: one or more evidence, identity, or safety checks failed.
- `GateOnlyConfirmed`: the gate artifacts explicitly show no live child execution.
- `EvidenceOnly`: the target is retained for evidence continuity only and is not mutation-ready.

## Required Inputs
- Planning evidence bundle from Rev4.41.
- Disable-gate evidence bundle from Rev4.42.
- Rollback-gate evidence bundle from Rev4.43.

## Operator Guidance
If the closeout is blocked, do not infer that live batch execution is safe. Rev4.42 and Rev4.43 remain gate-only by design, and this closeout validator does not authorize a production mutation path.
"@

Set-Content -LiteralPath $summaryPath -Value ($summary | ConvertTo-Json -Depth 12) -Encoding UTF8
Set-Content -LiteralPath $findingsPath -Value ($allFindings | ConvertTo-Json -Depth 12) -Encoding UTF8
Set-Content -LiteralPath $targetsPath -Value ($targetRows | ConvertTo-Json -Depth 12) -Encoding UTF8
Set-Content -LiteralPath $runbookPath -Value $runbook -Encoding UTF8

if (-not $safetyGatePassed) {
    throw "Rev4.44 evidence closeout blocked. See $findingsPath."
}

$summary
