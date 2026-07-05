#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetObjectId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TargetDisplayName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$AppId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$OutputRoot,

    [Parameter(Mandatory)]
    [ValidateSet('Readiness', 'WhatIf', 'Validate', 'Closeout')]
    [string]$EvidenceMode,

    [Parameter(Mandatory)]
    [AllowNull()]
    [object]$OwnerEvidence,

    [Parameter(Mandatory)]
    [AllowNull()]
    [object]$ActivityEvidence,

    [Parameter(Mandatory)]
    [AllowNull()]
    [object]$RiskAcceptance,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApprovedBy,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ApprovalPhrase,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ExpiresUtc,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$AllowListPath
)

$ErrorActionPreference = 'Stop'

$script:WrapperVersion = 'Rev4.46'
$script:ExpectedTenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
$script:ExpectedTargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
$script:ExpectedTargetObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
$script:ExpectedAppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
$script:ExpectedApprovalPhrase = 'APPROVE REV4.46 LAB READINESS EVIDENCE ONLY'

function Write-NhiJsonArtifact {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    $json = $InputObject | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    return $Path
}

function Test-UtcTimestamp {
    param(
        [Parameter(Mandatory)]
        [string]$UtcString
    )

    try {
                [void][DateTime]::Parse($UtcString).ToUniversalTime()
        return $true
    } catch {
        return $false
    }
}

function Test-NotExpiredUtc {
    param(
        [Parameter(Mandatory)]
        [string]$UtcString
    )

    try {
        $expires = [DateTime]::Parse($UtcString).ToUniversalTime()
        return ($expires -gt [DateTime]::UtcNow)
    } catch {
        return $false
    }
}

function Get-InputValue {
    param(
                [AllowNull()]
        [object]$Object,

        [Parameter(Mandatory)]
        [string[]]$PropertyNames,

        [AllowNull()]
        [object]$Default = $null
    )

    foreach ($propertyName in $PropertyNames) {
        if ($null -ne $Object -and $Object.PSObject.Properties[$propertyName]) {
            $value = $Object.$propertyName
            if ($null -ne $value -and -not [string]::IsNullOrWhiteSpace([string]$value)) {
                return $value
            }
        }
    }

    return $Default
}

function Get-AllowedTargets {
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return @()
    }

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "AllowListPath '$Path' was not found."
    }

    $document = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    $targets = @()
    if ($document.PSObject.Properties['Targets']) {
        $targets = @($document.Targets)
    } elseif ($document -is [System.Array]) {
        $targets = @($document)
    } else {
        $targets = @($document)
    }

    return @($targets | Where-Object { $_ })
}

function Test-TargetAllowed {
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$TargetObjectId,

        [Parameter(Mandatory)]
        [string]$TargetDisplayName,

        [Parameter(Mandatory)]
        [string]$AppId,

        [AllowNull()]
        [string]$AllowListPath
    )

    $allowedTargets = Get-AllowedTargets -Path $AllowListPath
    if ($allowedTargets.Count -eq 0) {
        return @{
            Allowed = (
                $TenantId -eq $script:ExpectedTenantId -and
                $TargetObjectId -eq $script:ExpectedTargetObjectId -and
                $TargetDisplayName -eq $script:ExpectedTargetDisplayName -and
                $AppId -eq $script:ExpectedAppId
            )
            Source = 'BuiltInKnownLabTarget'
        }
    }

    foreach ($allowedTarget in $allowedTargets) {
        $allowedTenantId = [string](Get-InputValue -Object $allowedTarget -PropertyNames @('TenantId'))
        $allowedObjectId = [string](Get-InputValue -Object $allowedTarget -PropertyNames @('TargetObjectId', 'ServicePrincipalObjectId', 'ObjectId'))
        $allowedDisplayName = [string](Get-InputValue -Object $allowedTarget -PropertyNames @('TargetDisplayName', 'DisplayName'))
        $allowedAppId = [string](Get-InputValue -Object $allowedTarget -PropertyNames @('AppId'))

        if ($TenantId -eq $allowedTenantId -and $TargetObjectId -eq $allowedObjectId -and $TargetDisplayName -eq $allowedDisplayName -and $AppId -eq $allowedAppId) {
            return @{ Allowed = $true; Source = 'AllowListPath' }
        }
    }

    return @{ Allowed = $false; Source = 'AllowListPath' }
}

function Test-OwnerEvidence {
    param(
        [AllowNull()]
        [object]$OwnerEvidence
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $OwnerEvidence) {
        $reasons.Add('Owner evidence is required.')
        return [pscustomobject]@{ Accepted = $false; Reasons = @($reasons) }
    }

    $ownerStatus = [string](Get-InputValue -Object $OwnerEvidence -PropertyNames @('OwnerStatus'))
    $ownerName = [string](Get-InputValue -Object $OwnerEvidence -PropertyNames @('OwnerName', 'OwnerTeam', 'OwnerApprover', 'HumanOwner'))
    $rationale = [string](Get-InputValue -Object $OwnerEvidence -PropertyNames @('Rationale', 'Reason'))
    $timestamp = [string](Get-InputValue -Object $OwnerEvidence -PropertyNames @('Timestamp', 'CapturedUtc', 'ApprovedUtc'))

    if ($ownerStatus -ne 'NoOwners') { $reasons.Add('OwnerStatus must be NoOwners for this lab readiness evidence.') }
    if ([string]::IsNullOrWhiteSpace($ownerName)) { $reasons.Add('Owner evidence must include a human-readable owner or approver name or team.') }
    if ([string]::IsNullOrWhiteSpace($rationale)) { $reasons.Add('Owner evidence must include rationale.') }
    if ([string]::IsNullOrWhiteSpace($timestamp)) { $reasons.Add('Owner evidence must include timestamp.') }
    elseif (-not (Test-UtcTimestamp -UtcString $timestamp)) { $reasons.Add('Owner evidence timestamp is invalid.') }

    return [pscustomobject]@{
        Accepted = $reasons.Count -eq 0
        Reasons = @($reasons)
    }
}

function Test-ActivityEvidence {
    param(
        [AllowNull()]
        [object]$ActivityEvidence
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $ActivityEvidence) {
        $reasons.Add('Activity evidence is required.')
        return [pscustomobject]@{ Accepted = $false; Reasons = @($reasons) }
    }

    $observedActivity = [string](Get-InputValue -Object $ActivityEvidence -PropertyNames @('LastObservedActivity', 'ObservedActivity'))
    $rationale = [string](Get-InputValue -Object $ActivityEvidence -PropertyNames @('Rationale', 'Reason'))
    $timestamp = [string](Get-InputValue -Object $ActivityEvidence -PropertyNames @('Timestamp', 'CapturedUtc', 'ObservedUtc'))

    if ($observedActivity -ne 'Unknown') { $reasons.Add('LastObservedActivity must be Unknown for this lab readiness evidence.') }
    if ([string]::IsNullOrWhiteSpace($rationale)) { $reasons.Add('Activity evidence must include rationale.') }
    if ([string]::IsNullOrWhiteSpace($timestamp)) { $reasons.Add('Activity evidence must include timestamp.') }
    elseif (-not (Test-UtcTimestamp -UtcString $timestamp)) { $reasons.Add('Activity evidence timestamp is invalid.') }

    return [pscustomobject]@{
        Accepted = $reasons.Count -eq 0
        Reasons = @($reasons)
    }
}

function Test-RiskAcceptance {
    param(
        [AllowNull()]
        [object]$RiskAcceptance,

        [Parameter(Mandatory)]
        [string]$ApprovedBy,

        [Parameter(Mandatory)]
        [string]$ExpiresUtc
    )

    $reasons = [System.Collections.Generic.List[string]]::new()
    if ($null -eq $RiskAcceptance) {
        $reasons.Add('Risk acceptance is required.')
        return [pscustomobject]@{ Accepted = $false; Reasons = @($reasons) }
    }

    $statement = [string](Get-InputValue -Object $RiskAcceptance -PropertyNames @('Statement', 'RiskAcceptanceStatement', 'AcceptanceStatement'))
    $rationale = [string](Get-InputValue -Object $RiskAcceptance -PropertyNames @('Rationale', 'Reason'))
    $timestamp = [string](Get-InputValue -Object $RiskAcceptance -PropertyNames @('Timestamp', 'CapturedUtc', 'ApprovedUtc'))
    $riskExpiresUtc = [string](Get-InputValue -Object $RiskAcceptance -PropertyNames @('ExpiresUtc'))
    $acceptedBy = [string](Get-InputValue -Object $RiskAcceptance -PropertyNames @('ApprovedBy', 'AcceptedBy'))
    $productionApproved = [bool](Get-InputValue -Object $RiskAcceptance -PropertyNames @('ProductionUseApproved') -Default $false)
    $finalDeleteApproved = [bool](Get-InputValue -Object $RiskAcceptance -PropertyNames @('FinalDeleteApproved') -Default $false)
    $cleanupApproved = [bool](Get-InputValue -Object $RiskAcceptance -PropertyNames @('CleanupApproved') -Default $false)
    $batchExecutionApproved = [bool](Get-InputValue -Object $RiskAcceptance -PropertyNames @('BatchExecutionApproved') -Default $false)

    if ([string]::IsNullOrWhiteSpace($statement) -or $statement -notmatch '(?i)lab-only readiness acceptance') {
        $reasons.Add('Risk acceptance statement must explicitly say this is a lab-only readiness acceptance.')
    }
    if ($productionApproved) { $reasons.Add('Risk acceptance must not approve production use.') }
    if ($finalDeleteApproved) { $reasons.Add('Risk acceptance must not approve final delete.') }
    if ($cleanupApproved) { $reasons.Add('Risk acceptance must not approve cleanup.') }
    if ($batchExecutionApproved) { $reasons.Add('Risk acceptance must not approve broad batch execution.') }
    if ([string]::IsNullOrWhiteSpace($rationale)) { $reasons.Add('Risk acceptance must include rationale.') }
    if ([string]::IsNullOrWhiteSpace($timestamp)) { $reasons.Add('Risk acceptance must include timestamp.') }
    elseif (-not (Test-UtcTimestamp -UtcString $timestamp)) { $reasons.Add('Risk acceptance timestamp is invalid.') }
    if ([string]::IsNullOrWhiteSpace($riskExpiresUtc)) { $reasons.Add('Risk acceptance must include ExpiresUtc.') }
    elseif (-not (Test-NotExpiredUtc -UtcString $riskExpiresUtc)) { $reasons.Add('Risk acceptance ExpiresUtc must be in the future.') }
    if ([string]::IsNullOrWhiteSpace($acceptedBy) -and [string]::IsNullOrWhiteSpace($ApprovedBy)) { $reasons.Add('Risk acceptance must identify the approver.') }
    elseif ($acceptedBy -and $acceptedBy -ne $ApprovedBy) { $reasons.Add('Risk acceptance approver must match ApprovedBy.') }

    return [pscustomobject]@{
        Accepted = $reasons.Count -eq 0
        Reasons = @($reasons)
    }
}

function New-RunArtifacts {
    param(
        [Parameter(Mandatory)]
        [string]$RunRoot,

        [Parameter(Mandatory)]
        [string]$TargetObjectId
    )

    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
    $safeTarget = $TargetObjectId -replace '[^A-Za-z0-9-]', '_'
    $artifactRoot = Join-Path $RunRoot ("rev446-lab-readiness-evidence/{0}/target-{1}" -f $timestamp, $safeTarget)
    $null = New-Item -ItemType Directory -Path $artifactRoot -Force

    return [pscustomobject]@{
        ArtifactRoot = $artifactRoot
        EvidencePath = Join-Path $artifactRoot 'rev446-lab-readiness-evidence.json'
        SummaryPath = Join-Path $artifactRoot 'rev446-lab-readiness-summary.json'
        RunbookPath = Join-Path $artifactRoot 'rev446-operator-runbook.md'
    }
}

$targetCheck = Test-TargetAllowed -TenantId $TenantId -TargetObjectId $TargetObjectId -TargetDisplayName $TargetDisplayName -AppId $AppId -AllowListPath $AllowListPath
$ownerCheck = Test-OwnerEvidence -OwnerEvidence $OwnerEvidence
$activityCheck = Test-ActivityEvidence -ActivityEvidence $ActivityEvidence
$riskCheck = Test-RiskAcceptance -RiskAcceptance $RiskAcceptance -ApprovedBy $ApprovedBy -ExpiresUtc $ExpiresUtc

$blockingReasons = [System.Collections.Generic.List[string]]::new()
if (-not $targetCheck.Allowed) { $blockingReasons.Add('Target identity does not match the known lab target or allow-list entry.') }
if (-not $ownerCheck.Accepted) { foreach ($reason in @($ownerCheck.Reasons)) { $blockingReasons.Add([string]$reason) } }
if (-not $activityCheck.Accepted) { foreach ($reason in @($activityCheck.Reasons)) { $blockingReasons.Add([string]$reason) } }
if (-not $riskCheck.Accepted) { foreach ($reason in @($riskCheck.Reasons)) { $blockingReasons.Add([string]$reason) } }
if ($ApprovalPhrase -ne $script:ExpectedApprovalPhrase) { $blockingReasons.Add('ApprovalPhrase does not match the required Rev4.46 lab readiness phrase.') }
if (-not (Test-UtcTimestamp -UtcString $ExpiresUtc)) { $blockingReasons.Add('Evidence ExpiresUtc must be in the future.') }

$finalDeleteApproved = [bool](Get-InputValue -Object $RiskAcceptance -PropertyNames @('FinalDeleteApproved') -Default $false)
$cleanupApproved = [bool](Get-InputValue -Object $RiskAcceptance -PropertyNames @('CleanupApproved') -Default $false)
$liveMutationApproved = [bool](Get-InputValue -Object $RiskAcceptance -PropertyNames @('LiveMutationApproved') -Default $false)
$tenantMutationPerformed = $false

if ($finalDeleteApproved) { $blockingReasons.Add('Final delete approval is not permitted for Rev4.46 lab readiness evidence.') }
if ($cleanupApproved) { $blockingReasons.Add('Cleanup approval is not permitted for Rev4.46 lab readiness evidence.') }
if ($liveMutationApproved) { $blockingReasons.Add('Live mutation approval is not permitted for Rev4.46 lab readiness evidence.') }

$safetyGatePassed = $blockingReasons.Count -eq 0
$evidenceStatus = if ($safetyGatePassed) { 'Ready' } else { 'Blocked' }

$runRoot = [System.IO.Path]::GetFullPath($OutputRoot)
$null = New-Item -ItemType Directory -Path $runRoot -Force
$artifacts = New-RunArtifacts -RunRoot $runRoot -TargetObjectId $TargetObjectId

$evidence = [pscustomobject]@{
    SchemaVersion = 'Rev4.46-LabReadinessEvidence'
    ToolVersion = $script:WrapperVersion
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    TenantId = $TenantId
    TargetObjectId = $TargetObjectId
    TargetDisplayName = $TargetDisplayName
    AppId = $AppId
    EvidenceMode = $EvidenceMode
    ApprovedBy = $ApprovedBy
    ApprovalPhrase = $ApprovalPhrase
    ExpiresUtc = $ExpiresUtc
    TargetIdentitySource = $targetCheck.Source
    TargetIdentityMatched = $targetCheck.Allowed
    OwnerEvidence = $OwnerEvidence
    ActivityEvidence = $ActivityEvidence
    RiskAcceptance = $RiskAcceptance
    FinalDeleteApproved = $finalDeleteApproved
    CleanupApproved = $cleanupApproved
    LiveMutationApproved = $liveMutationApproved
    TenantMutationPerformed = $tenantMutationPerformed
    SafetyGatePassed = $safetyGatePassed
    BlockingReasons = @($blockingReasons)
}

$summary = [pscustomobject]@{
    SchemaVersion = 'Rev4.46-LabReadinessEvidence'
    ToolVersion = $script:WrapperVersion
    CreatedUtc = [DateTime]::UtcNow.ToString('o')
    TenantId = $TenantId
    TargetObjectId = $TargetObjectId
    TargetDisplayName = $TargetDisplayName
    AppId = $AppId
    EvidenceMode = $EvidenceMode
    EvidenceStatus = $evidenceStatus
    OwnerEvidenceAccepted = $ownerCheck.Accepted
    ActivityEvidenceAccepted = $activityCheck.Accepted
    RiskAcceptanceAccepted = $riskCheck.Accepted
    ExpiresUtc = $ExpiresUtc
    FinalDeleteApproved = $false
    CleanupApproved = $false
    LiveMutationApproved = $false
    TenantMutationPerformed = $false
    SafetyGatePassed = $safetyGatePassed
    BlockingReasons = @($blockingReasons)
    ApprovedBy = $ApprovedBy
    ApprovalPhrase = $ApprovalPhrase
    AllowListPath = $AllowListPath
    ArtifactPaths = [pscustomobject]@{
        EvidencePath = $artifacts.EvidencePath
        SummaryPath = $artifacts.SummaryPath
        RunbookPath = $artifacts.RunbookPath
    }
}

$runbook = @"
# Rev4.46 Lab Readiness Evidence

## Purpose
Rev4.46 creates evidence-only lab readiness artifacts for the known lab target without mutating the tenant.

## Safety Boundary
- No Graph write scopes are used.
- No tenant mutation commands are present.
- No live disable, rollback, cleanup, delete, or final delete path is authorized.
- This tool does not bypass Rev4.41, Rev4.42, Rev4.43, or Rev4.44 safety gates.

## Allowed Use
Use this tool only to capture explicit human-approved readiness evidence for the known lab target:
- `AJEE-LAB-NHI-DISABLE-ROLLBACK`
- `7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b`
- `48deb98d-78c4-49b0-8c56-eed1bb5732c0`

## Required Evidence
- Owner evidence that explains why `NoOwners` is acceptable for this lab target.
- Activity evidence that explains why `Unknown` activity is acceptable for this lab target.
- Risk acceptance that is explicitly lab-only and does not approve production use, cleanup, final delete, or broad batch execution.

## Output Artifacts
- `rev446-lab-readiness-evidence.json`
- `rev446-lab-readiness-summary.json`
- `rev446-operator-runbook.md`

## Future Use
This evidence layer prepares the lab for a future separately approved one-object Execute test.
It does not authorize that Execute test by itself.
"@

$null = Write-NhiJsonArtifact -Path $artifacts.EvidencePath -InputObject $evidence
$null = Write-NhiJsonArtifact -Path $artifacts.SummaryPath -InputObject $summary
[System.IO.File]::WriteAllText($artifacts.RunbookPath, $runbook, [System.Text.UTF8Encoding]::new($false))

$result = [pscustomobject]@{
    SchemaVersion = 'Rev4.46-LabReadinessEvidence'
    ToolVersion = $script:WrapperVersion
    TenantId = $TenantId
    TargetObjectId = $TargetObjectId
    TargetDisplayName = $TargetDisplayName
    AppId = $AppId
    EvidenceMode = $EvidenceMode
    EvidenceStatus = $evidenceStatus
    OwnerEvidenceAccepted = $ownerCheck.Accepted
    ActivityEvidenceAccepted = $activityCheck.Accepted
    RiskAcceptanceAccepted = $riskCheck.Accepted
    ExpiresUtc = $ExpiresUtc
    FinalDeleteApproved = $false
    CleanupApproved = $false
    LiveMutationApproved = $false
    TenantMutationPerformed = $tenantMutationPerformed
    SafetyGatePassed = $safetyGatePassed
    BlockingReasons = @($blockingReasons)
    OutputRoot = $runRoot
    ArtifactPaths = [pscustomobject]@{
        EvidencePath = $artifacts.EvidencePath
        SummaryPath = $artifacts.SummaryPath
        RunbookPath = $artifacts.RunbookPath
    }
}

if (-not $safetyGatePassed) {
    $result | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue $artifacts.SummaryPath -Force
    return $result
}

$result | Add-Member -NotePropertyName OutputArtifactPath -NotePropertyValue $artifacts.SummaryPath -Force
return $result
