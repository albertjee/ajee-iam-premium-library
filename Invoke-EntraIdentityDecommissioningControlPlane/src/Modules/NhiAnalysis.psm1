#Requires -Version 5.1

# NHI Classification Constants
$script:NhiClassificationPatterns = @(
    @{ Pattern = 'serviceprincipaltype'; Value = 'ServiceIdentity'; Score = 50; Confidence = 'High'; Category = 'ServicePrincipalType = ServiceIdentity' },
    @{ Pattern = 'agent|copilot|openai|azureai|foundry|llm|gpt'; Value = $true; Score = 35; Confidence = 'Medium'; Category = 'Agent/Automation Naming Pattern' },
    @{ Pattern = 'automation|workflow|orchestrator|runner|bot'; Value = $true; Score = 25; Confidence = 'Medium'; Category = 'Automation Naming Pattern' },
    @{ Pattern = 'svc|service|daemon|worker|sync|scheduler|job'; Value = $true; Score = 15; Confidence = 'Low'; Category = 'Service/Worker Naming Pattern' }
)

$script:NhiFirstPartyMicrosoftPatterns = @(
    'Microsoft Corporation'
)

function Get-DecomNhiClassificationScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$NhiObject
    )

    $score = 0
    $signals = @()
    $confidenceLevels = @()

    # Check ServicePrincipalType = ServiceIdentity
    if ($NhiObject.ServicePrincipalType -eq 'ServiceIdentity') {
        $score += 50
        $signals += 'ServicePrincipalType = ServiceIdentity'
        $confidenceLevels += 'High'
    }

    # Check naming patterns
    $displayNameLower = $NhiObject.DisplayName.ToLower()
    foreach ($pattern in $script:NhiClassificationPatterns) {
        if ($pattern.Pattern -eq 'serviceprincipaltype') {
            # Already checked above
            continue
        }

        if ($displayNameLower -match $pattern.Pattern) {
            $score += $pattern.Score
            $signals += $pattern.Category
            $confidenceLevels += $pattern.Confidence
        }
    }

    # Check credential-bearing app
    if ($NhiObject.CredentialCount -gt 0) {
        $score += 10
        $signals += 'Credential-bearing app'
        $confidenceLevels += 'Low'
    }

    # Check high-risk Graph permissions
    if ($NhiObject.HighRiskPermissionCount -gt 0) {
        $score += 15
        $signals += 'High-risk Graph application permission'
        $confidenceLevels += 'Medium'
    }

    # Check tenant-wide consent
    if ($NhiObject.TenantWideConsent) {
        $score += 15
        $signals += 'Tenant-wide AllPrincipals consent'
        $confidenceLevels += 'Medium'
    }

    # Check ownership gaps
    if ($NhiObject.OwnerCount -eq 0) {
        $score += 15
        $signals += 'No owner'
        $confidenceLevels += 'Medium'
    } elseif ($NhiObject.OwnerCount -eq 1) {
        $score += 8
        $signals += 'Single owner'
        $confidenceLevels += 'Low'
    }

    # Check verified publisher missing
    if (-not $NhiObject.IsVerifiedPublisher) {
        $score += 8
        $signals += 'Verified publisher missing'
        $confidenceLevels += 'Low'
    }

    # Check external publisher
    if ($NhiObject.PublisherName -and $NhiObject.PublisherName -notin $script:NhiFirstPartyMicrosoftPatterns) {
        $score += 10
        $signals += 'External publisher'
        $confidenceLevels += 'Low'
    }

    # Check OAuth delegated grant present
    if ($NhiObject.HighRiskOAuthGrantCount -gt 0) {
        $score += 8
        $signals += 'High-risk delegated OAuth grant present'
        $confidenceLevels += 'Low'
    }

    # Determine final classification and confidence
    $classification = 'Unclassified'
    $finalConfidence = 'Unknown'

    if ($NhiObject.ObjectType -eq 'ServicePrincipal') {
        if ($NhiObject.ServicePrincipalType -eq 'ServiceIdentity') {
            $classification = 'NativeServiceIdentity'
        } elseif ($score -ge 50) {
            $classification = 'LikelyAIAgent'
        } elseif ($score -ge 30) {
            $classification = 'LikelyAIAgent'
        } elseif ($score -ge 15) {
            $classification = 'LikelyAutomation'
        } else {
            $classification = 'UnclassifiedServicePrincipal'
        }
    } else {
        # For Applications
        if ($score -ge 50) {
            $classification = 'LikelyAIAgent'
        } elseif ($score -ge 30) {
            $classification = 'LikelyAIAgent'
        } elseif ($score -ge 15) {
            $classification = 'LikelyAutomation'
        } else {
            $classification = 'UnclassifiedApplication'
        }
    }

    # Determine confidence based on score bands
    if ($score -ge 50) {
        $finalConfidence = 'High'
    } elseif ($score -ge 30) {
        $finalConfidence = 'Medium'
    } elseif ($score -ge 15) {
        $finalConfidence = 'Low'
    } else {
        $finalConfidence = 'Unknown'
    }

    return [PSCustomObject]@{
        ClassificationScore = $score
        Classification = $classification
        ClassificationConfidence = $finalConfidence
        ClassificationSignals = $signals
    }
}

function Get-DecomNhiRiskScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$NhiObject,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ClassificationResult
    )

    # Base risk score from classification
    $baseScore = $ClassificationResult.ClassificationScore

    # Risk factors that increase score
    $riskScore = $baseScore

    # Ensure score stays within bounds
    if ($riskScore -lt 0) { $riskScore = 0 }
    if ($riskScore -gt 100) { $riskScore = 100 }

    return [int]$riskScore
}

function Get-DecomNhiSeverityFromRiskScore {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$RiskScore
    )

    if ($RiskScore -ge 85) { return 'Critical' }
    if ($RiskScore -ge 70) { return 'High' }
    if ($RiskScore -ge 44) { return 'Medium' }
    if ($RiskScore -ge 15) { return 'Low' }
    return 'Informational'
}

function Get-DecomNhiRemediationMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FindingId,
        [string]$Classification,
        [bool]$ExactTargetAvailable
    )

    # Map finding IDs to remediation modes based on build prompt
    switch ($FindingId) {
        'DEC-NHI-001' { return 'InformationOnly' }
        'DEC-NHI-002' {
            if ($ExactTargetAvailable) { return 'ManualApprovalRequired' }
            else { return 'InformationOnly' }
        }
        'DEC-NHI-003' {
            if ($ExactTargetAvailable) { return 'ManualApprovalRequired' }
            else { return 'InformationOnly' }
        }
        'DEC-NHI-004' {
            if ($ExactTargetAvailable) { return 'ManualApprovalRequired' }
            else { return 'InformationOnly' }
        }
        'DEC-NHI-005' {
            if ($ExactTargetAvailable) { return 'ManualApprovalRequired' }
            else { return 'InformationOnly' }
        }
        'DEC-NHI-006' { return 'InformationOnly' }  # or PlanOnly
        'DEC-NHI-007' { return 'InformationOnly' }
        'DEC-NHI-008' { return 'InformationOnly' }
        'DEC-NHI-009' { return 'InformationOnly' }
        'DEC-NHI-010' { return 'InformationOnly' }
        'DEC-NHI-011' { return 'InformationOnly' }
        'DEC-NHI-012' {
            if ($ExactTargetAvailable) { return 'ManualApprovalRequired' }
            else { return 'InformationOnly' }
        }
        'DEC-AGENT-001' { return 'InformationOnly' }
        'DEC-AGENT-002' { return 'InformationOnly' }
        'DEC-AGENT-003' {
            if ($ExactTargetAvailable) { return 'ManualApprovalRequired' }
            else { return 'InformationOnly' }
        }
        'DEC-AGENT-004' { return 'InformationOnly' }
        'DEC-AGENT-005' { return 'InformationOnly' }
        'DEC-AGENT-006' {
            if ($ExactTargetAvailable) { return 'ManualApprovalRequired' }
            else { return 'InformationOnly' }
        }
        'DEC-AGENT-007' { return 'InformationOnly' }
        default { return 'InformationOnly' }
    }
}

function Invoke-DecomNhiAnalysis {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$NhiObjects,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    Write-DecomInfo "Starting NHI analysis for $($NhiObjects.Count) objects..."

    $analyzedObjects = @()

    foreach ($nhiObject in $NhiObjects) {
        try {
            $platformClassification = Test-DecomMicrosoftPlatformIdentity -NhiObject $nhiObject
            if ($platformClassification.MicrosoftPlatform) {
                $analyzedObjects += ($nhiObject | Add-Member -NotePropertyName MicrosoftFirstParty -NotePropertyValue $platformClassification.MicrosoftFirstParty -Force -PassThru |
                    Add-Member -NotePropertyName MicrosoftPlatform -NotePropertyValue $platformClassification.MicrosoftPlatform -Force -PassThru |
    Add-Member -NotePropertyName MicrosoftPlatformReason -NotePropertyValue $platformClassification.Reason -Force -PassThru |
    Add-Member -NotePropertyName SuppressCustomerRemediation -NotePropertyValue $platformClassification.SuppressCustomerRemediation -Force -PassThru |
                    Add-Member -NotePropertyName ClassificationSource -NotePropertyValue 'MicrosoftPlatformOverride' -Force -PassThru |
                    Add-Member -NotePropertyName ClassificationScore -NotePropertyValue 0 -Force -PassThru |
                    Add-Member -NotePropertyName Classification -NotePropertyValue 'MicrosoftPlatform' -Force -PassThru |
                    Add-Member -NotePropertyName ClassificationConfidence -NotePropertyValue 'High' -Force -PassThru |
                    Add-Member -NotePropertyName ClassificationSignals -NotePropertyValue @('Microsoft platform identity') -Force -PassThru |
                    Add-Member -NotePropertyName NormalizedAppId -NotePropertyValue $nhiObject.NormalizedAppId -Force -PassThru |
                    Add-Member -NotePropertyName NormalizedPublisherName -NotePropertyValue $nhiObject.NormalizedPublisherName -Force -PassThru |
                    Add-Member -NotePropertyName NormalizedVerifiedPublisherName -NotePropertyValue $nhiObject.NormalizedVerifiedPublisherName -Force -PassThru |
                    Add-Member -NotePropertyName NormalizedAppOwnerOrganizationId -NotePropertyValue $nhiObject.NormalizedAppOwnerOrganizationId -Force -PassThru |
                    Add-Member -NotePropertyName NormalizedServicePrincipalType -NotePropertyValue $nhiObject.NormalizedServicePrincipalType -Force -PassThru |
                    Add-Member -NotePropertyName NormalizedTags -NotePropertyValue $nhiObject.NormalizedTags -Force -PassThru |
                    Add-Member -NotePropertyName NhiCandidate -NotePropertyValue $true -Force -PassThru |
                    Add-Member -NotePropertyName AgenticCandidate -NotePropertyValue $false -Force -PassThru |
                    Add-Member -NotePropertyName AutomationCandidate -NotePropertyValue $false -Force -PassThru |
                    Add-Member -NotePropertyName WorkloadCandidate -NotePropertyValue $false -Force -PassThru |
                    Add-Member -NotePropertyName RiskScore -NotePropertyValue 0 -Force -PassThru |
                    Add-Member -NotePropertyName Severity -NotePropertyValue 'Informational' -Force -PassThru |
                    Add-Member -NotePropertyName CoverageMode -NotePropertyValue 'EvidenceOnly' -Force -PassThru)
                continue
            }

            # P1-04: Calculate OAuth fields first
            $tenantWideConsent = $false
            $highRiskOAuthGrantCount = 0
            foreach ($grant in @($nhiObject.RawOAuthGrants)) {
                if ($grant.ConsentType -eq 'AllPrincipals') { $tenantWideConsent = $true }
                $scopes = @()
                if ($grant.Scope) { $scopes = @($grant.Scope -split '\s+') }
                foreach ($scope in $scopes) {
                    if ($scope -in $script:HighRiskDelegatedScopes) {
                        $highRiskOAuthGrantCount++
                        break
                    }
                }
            }
            $nhiObject | Add-Member -NotePropertyName TenantWideConsent -NotePropertyValue $tenantWideConsent -Force
            $nhiObject | Add-Member -NotePropertyName HighRiskOAuthGrantCount -NotePropertyValue $highRiskOAuthGrantCount -Force

            # Step 2 — NOW run classification and risk scoring
            # Get classification
            $classificationResult = Get-DecomNhiClassificationScore -NhiObject $nhiObject

            # Calculate risk score
            $riskScore = Get-DecomNhiRiskScore -NhiObject $nhiObject -ClassificationResult $classificationResult

            # Determine severity from risk score
            $severity = Get-DecomNhiSeverityFromRiskScore -RiskScore $riskScore

            # P1-03: Preserve discovery coverage flags — do NOT reset to false/@()
            $riskScoreMayBeUnderstated = [bool]$nhiObject.RiskScoreMayBeUnderstated
            $coverageLimitations = @($nhiObject.CoverageLimitations)

            # Then append analysis-level limitations
            if (-not $nhiObject.HighRiskPermissionCount) {
                $riskScoreMayBeUnderstated = $true
                $coverageLimitations += 'Application role display-name resolution unavailable — permission risk may be understated'
            }

            # Determine if this is an NHI or agentic candidate
            $isNhiCandidate = $nhiObject.ObjectType -in @('ServicePrincipal', 'Application')
            $isAgenticCandidate = $classificationResult.Classification -in @('NativeServiceIdentity', 'LikelyAIAgent', 'LikelyAutomation')
            $isAutomationCandidate = $classificationResult.Classification -eq 'LikelyAutomation'
            $isWorkloadCandidate = $false  # To be determined by additional logic

            # Update NHI object with analysis results
            $analyzedObject = $nhiObject | Add-Member -NotePropertyName 'ClassificationScore' -NotePropertyValue $classificationResult.ClassificationScore -Force -PassThru |
                Add-Member -NotePropertyName 'Classification' -NotePropertyValue $classificationResult.Classification -Force -PassThru |
                Add-Member -NotePropertyName 'ClassificationConfidence' -NotePropertyValue $classificationResult.ClassificationConfidence -Force -PassThru |
                Add-Member -NotePropertyName 'ClassificationSignals' -NotePropertyValue $classificationResult.ClassificationSignals -Force -PassThru |
                Add-Member -NotePropertyName 'ClassificationSource' -NotePropertyValue 'HeuristicAnalysis' -Force -PassThru |
                Add-Member -NotePropertyName 'MicrosoftFirstParty' -NotePropertyValue ([bool]$nhiObject.MicrosoftFirstParty) -Force -PassThru |
                Add-Member -NotePropertyName 'MicrosoftPlatform' -NotePropertyValue ([bool]$nhiObject.MicrosoftPlatform) -Force -PassThru |
    Add-Member -NotePropertyName 'MicrosoftPlatformReason' -NotePropertyValue $nhiObject.MicrosoftPlatformReason -Force -PassThru |
    Add-Member -NotePropertyName 'SuppressCustomerRemediation' -NotePropertyValue ([bool]$nhiObject.SuppressCustomerRemediation) -Force -PassThru |
                Add-Member -NotePropertyName 'NormalizedAppId' -NotePropertyValue $nhiObject.NormalizedAppId -Force -PassThru |
                Add-Member -NotePropertyName 'NormalizedPublisherName' -NotePropertyValue $nhiObject.NormalizedPublisherName -Force -PassThru |
                Add-Member -NotePropertyName 'NormalizedVerifiedPublisherName' -NotePropertyValue $nhiObject.NormalizedVerifiedPublisherName -Force -PassThru |
                Add-Member -NotePropertyName 'NormalizedAppOwnerOrganizationId' -NotePropertyValue $nhiObject.NormalizedAppOwnerOrganizationId -Force -PassThru |
                Add-Member -NotePropertyName 'NormalizedServicePrincipalType' -NotePropertyValue $nhiObject.NormalizedServicePrincipalType -Force -PassThru |
                Add-Member -NotePropertyName 'NormalizedTags' -NotePropertyValue $nhiObject.NormalizedTags -Force -PassThru |
                Add-Member -NotePropertyName 'NhiCandidate' -NotePropertyValue $isNhiCandidate -Force -PassThru |
                Add-Member -NotePropertyName 'AgenticCandidate' -NotePropertyValue $isAgenticCandidate -Force -PassThru |
                Add-Member -NotePropertyName 'AutomationCandidate' -NotePropertyValue $isAutomationCandidate -Force -PassThru |
                Add-Member -NotePropertyName 'WorkloadCandidate' -NotePropertyValue $isWorkloadCandidate -Force -PassThru |
                Add-Member -NotePropertyName 'RiskScore' -NotePropertyValue $riskScore -Force -PassThru |
                Add-Member -NotePropertyName 'Severity' -NotePropertyValue $severity -Force -PassThru |
                Add-Member -NotePropertyName 'TenantWideConsent' -NotePropertyValue $tenantWideConsent -Force -PassThru |
                Add-Member -NotePropertyName 'HighRiskOAuthGrantCount' -NotePropertyValue $highRiskOAuthGrantCount -Force -PassThru |
                Add-Member -NotePropertyName 'RiskScoreMayBeUnderstated' -NotePropertyValue $riskScoreMayBeUnderstated -Force -PassThru |
                Add-Member -NotePropertyName 'CoverageLimitations' -NotePropertyValue $coverageLimitations -Force -PassThru

            $analyzedObjects += $analyzedObject
        } catch {
            Write-Warning "Failed to analyze NHI object $($nhiObject.DisplayName): $_"
            # Add the object anyway with default values to avoid breaking the pipeline
            $analyzedObjects += $nhiObject
        }
    }

    Write-DecomOk "NHI analysis complete — $($analyzedObjects.Count) object(s) analyzed"
    return $analyzedObjects
}

function Add-DecomCoverageLimitation {
    <#
    .SYNOPSIS
    Adds a coverage limitation to an NHI analysis result with deduplication.
    .DESCRIPTION
    Appends a coverage limitation to an analyzed NHI object, preventing duplicates
    and preserving discovery flags (WasDiscovered, IsAgentIdentity, etc.) during
    the analysis phase.
    .PARAMETER AnalyzedObject
    The NHI object with RiskScore and analysis results.
    .PARAMETER LimitationType
    Type of limitation (e.g., 'RiskScoreMayBeUnderstated', 'DiscoveryIncomplete').
    .PARAMETER Reason
    Human-readable reason for the limitation.
    .PARAMETER Severity
    Severity level ('Info', 'Warning', 'Critical').
    .RETURNS
    Updated AnalyzedObject with limitation added (if not duplicate).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$AnalyzedObject,

        [Parameter(Mandatory = $true)]
        [string]$LimitationType,

        [Parameter(Mandatory = $true)]
        [string]$Reason,

        [ValidateSet('Info','Warning','Critical')]
        [string]$Severity = 'Warning'
    )

    if (-not $AnalyzedObject.CoverageLimitations) {
        $AnalyzedObject | Add-Member -NotePropertyName CoverageLimitations -NotePropertyValue @() -Force
    }

    $limitationHash = "$LimitationType`:$Reason"
    # Check for unique limitation (prevent duplicates)
    $unique = $true
    foreach ($limitation in $AnalyzedObject.CoverageLimitations) {
        $existingHash = "$($limitation.Type):$($limitation.Reason)"
        if ($existingHash -eq $limitationHash) {
            $unique = $false
            break
        }
    }

    if ($unique) {
        $limitation = [pscustomobject]@{
            Type      = $LimitationType
            Reason    = $Reason
            Severity  = $Severity
            AddedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        }
        $AnalyzedObject.CoverageLimitations += $limitation
    }

    return $AnalyzedObject
}

Export-ModuleMember -Function Invoke-DecomNhiAnalysis, Get-DecomNhiClassificationScore, Get-DecomNhiRiskScore, Get-DecomNhiSeverityFromRiskScore, Get-DecomNhiRemediationMode, Add-DecomCoverageLimitation
