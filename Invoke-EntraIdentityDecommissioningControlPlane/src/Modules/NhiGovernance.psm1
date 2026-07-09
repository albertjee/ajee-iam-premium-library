# NhiGovernance.psm1 - Rev4.2 data-driven refactor (refactoring-plan target I-b).
# Behavior-preserving: the 12 conditional New-DecomFinding blocks are now driven by
# $script:NhiGovernanceFindingDefinitions. Finding order, parameter sets, metadata
# values, evidence strings, and GraphEndpoint strings are preserved verbatim from the
# pre-refactor implementation - including the pre-existing single-quoted (unexpanded)
# '$($nhiObject.ObjectId)' artifacts inside GraphEndpoint values.
#
# Definition fields:
#   Condition  - scriptblock ($o) -> $false/$null (skip), $true, or hashtable of extras
#   Severity / RiskScore / Confidence - literal, or scriptblock ($o) for object-derived
#   Evidence   - scriptblock ($o, $extra) -> string
#   GraphEndpoint / Category / RecommendedAction / RemediationMode - literals
#   IncludePlatformFields - adds MicrosoftFirstParty/MicrosoftPlatform/EvidenceOnly:$false
#                           (only DEC-NHI-001 passed these pre-refactor)

$script:NhiGovernanceFindingDefinitions = @(
    @{
        FindingId = 'DEC-NHI-001'
        Condition = { param($o) $true }
        Category = 'NHI Inventory'
        Severity = { param($o) $o.Severity }
        RiskScore = { param($o) $o.RiskScore }
        Confidence = { param($o) $o.ClassificationConfidence }
        Evidence = { param($o, $extra) "Entra-visible NHI candidate based on $($o.ClassificationSignals -join ', ')" }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals'
        RecommendedAction = 'Review for ownership, credentials, and permissions'
        RemediationMode = 'InformationOnly'
        IncludePlatformFields = $true
    },
    @{
        FindingId = 'DEC-NHI-002'
        Condition = { param($o) $o.OwnerCount -eq 0 }
        Category = 'NHI Ownership'
        Severity = 'High'
        RiskScore = 62
        Confidence = 'High'
        Evidence = { param($o, $extra) 'NHI has no owner assigned' }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/owners'
        RecommendedAction = 'Assign owner using AddApplicationOwner action'
        RemediationMode = 'ManualApprovalRequired'
    },
    @{
        FindingId = 'DEC-NHI-003'
        Condition = { param($o) $o.OwnerCount -eq 1 }
        Category = 'NHI Ownership'
        Severity = 'Medium'
        RiskScore = 44
        Confidence = 'High'
        Evidence = { param($o, $extra) 'NHI has only one owner assigned' }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/owners'
        RecommendedAction = 'Consider assigning additional owner for redundancy'
        RemediationMode = 'ManualApprovalRequired'
    },
    @{
        FindingId = 'DEC-NHI-004'
        Condition = {
            param($o)
            $disabledOwnerCount = 0
            if ($o.RawOwners) {
                foreach ($owner in $o.RawOwners) {
                    if ($owner.AccountEnabled -eq $false) { $disabledOwnerCount++ }
                }
            }
            if ($disabledOwnerCount -gt 0) { @{ DisabledOwnerCount = $disabledOwnerCount } } else { $false }
        }
        Category = 'NHI Ownership'
        Severity = 'High'
        RiskScore = 68
        Confidence = 'High'
        Evidence = { param($o, $extra) "NHI is owned by $($extra.DisabledOwnerCount) disabled identity(ies)" }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/owners'
        RecommendedAction = 'Assign owner using AddApplicationOwner action'
        RemediationMode = 'ManualApprovalRequired'
    },
    @{
        FindingId = 'DEC-NHI-007'
        Condition = { param($o) $o.HighRiskPermissionCount -gt 0 }
        Category = 'NHI Permission Risk'
        Severity = 'High'
        RiskScore = 72
        Confidence = 'High'
        Evidence = { param($o, $extra) "NHI has $($o.HighRiskPermissionCount) high-risk Graph application permission(s)" }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/appRoleAssignments'
        RecommendedAction = 'Review permission necessity and consider removal'
        RemediationMode = 'InformationOnly'
    },
    @{
        FindingId = 'DEC-NHI-009'
        Condition = { param($o) [bool]$o.TenantWideConsent }
        Category = 'NHI Consent Risk'
        Severity = 'Critical'
        RiskScore = 85
        Confidence = 'High'
        Evidence = { param($o, $extra) 'NHI has tenant-wide AllPrincipals consent' }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/oauth2PermissionGrants'
        RecommendedAction = 'Review consent necessity and consider removal'
        RemediationMode = 'InformationOnly'
    },
    @{
        FindingId = 'DEC-NHI-010'
        Condition = { param($o) -not $o.IsVerifiedPublisher }
        Category = 'NHI Publisher Risk'
        Severity = 'Medium'
        RiskScore = 45
        Confidence = 'Medium'
        Evidence = { param($o, $extra) 'NHI publisher verification cannot be verified' }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/applications/$($nhiObject.AppId)'
        RecommendedAction = 'Verify publisher through Microsoft Partner Center'
        RemediationMode = 'InformationOnly'
    },
    @{
        FindingId = 'DEC-NHI-012'
        Condition = { param($o) $o.HighRiskPermissionCount -gt 0 -and $o.OwnerCount -eq 0 }
        Category = 'NHI Permission Ownership Correlation'
        Severity = 'High'
        RiskScore = 70
        Confidence = 'High'
        Evidence = { param($o, $extra) "NHI has $($o.HighRiskPermissionCount) high-risk app-role assignments but no owner" }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/appRoleAssignments'
        RecommendedAction = 'Assign owner using AddApplicationOwner action'
        RemediationMode = 'ManualApprovalRequired'
    },
    @{
        FindingId = 'DEC-AGENT-001'
        Condition = { param($o) $o.AgenticCandidate -and $o.ServicePrincipalType -eq 'ServiceIdentity' }
        Category = 'Agentic Identity Inventory'
        Severity = 'Informational'
        RiskScore = 20
        Confidence = 'High'
        Evidence = { param($o, $extra) 'Native ServiceIdentity service principal detected' }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)'
        RecommendedAction = 'Review for official sanction and documentation'
        RemediationMode = 'InformationOnly'
    },
    @{
        FindingId = 'DEC-AGENT-003'
        Condition = { param($o) $o.AgenticCandidate -and $o.OwnerCount -eq 0 }
        Category = 'Agent Ownership'
        Severity = 'High'
        RiskScore = 68
        Confidence = 'High'
        Evidence = { param($o, $extra) 'Agent-like identity has no owner assigned' }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/owners'
        RecommendedAction = 'Assign owner using AddApplicationOwner action'
        RemediationMode = 'ManualApprovalRequired'
    },
    @{
        FindingId = 'DEC-AGENT-004'
        Condition = { param($o) $o.AgenticCandidate -and $o.HighRiskPermissionCount -gt 0 }
        Category = 'Agent Permission Risk'
        Severity = 'High'
        RiskScore = 76
        Confidence = 'High'
        Evidence = { param($o, $extra) "Agent-like identity has $($o.HighRiskPermissionCount) high-risk Graph permission(s)" }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/appRoleAssignments'
        RecommendedAction = 'Review permission necessity and consider removal'
        RemediationMode = 'InformationOnly'
    },
    @{
        FindingId = 'DEC-AGENT-005'
        Condition = { param($o) $o.AgenticCandidate -and [bool]$o.TenantWideConsent }
        Category = 'Agent Consent Risk'
        Severity = 'Critical'
        RiskScore = 88
        Confidence = 'High'
        Evidence = { param($o, $extra) 'Agent-like identity has tenant-wide AllPrincipals consent' }
        GraphEndpoint = 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/oauth2PermissionGrants'
        RecommendedAction = 'Review consent necessity and consider removal'
        RemediationMode = 'InformationOnly'
    }
)

function New-NhiGovernanceFindingFromDefinition {
    # Private helper: builds the New-DecomFinding call for one definition + object.
    # The parameter set matches the pre-refactor inline blocks exactly: platform fields
    # (MicrosoftFirstParty/MicrosoftPlatform/EvidenceOnly) are passed only when the
    # definition sets IncludePlatformFields (DEC-NHI-001).
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Definition,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$NhiObject,
        $Extra
    )

    $severity = if ($Definition.Severity -is [scriptblock]) { & $Definition.Severity $NhiObject } else { $Definition.Severity }
    $riskScore = if ($Definition.RiskScore -is [scriptblock]) { & $Definition.RiskScore $NhiObject } else { $Definition.RiskScore }
    $confidence = if ($Definition.Confidence -is [scriptblock]) { & $Definition.Confidence $NhiObject } else { $Definition.Confidence }

    $params = @{
        FindingId                 = $Definition.FindingId
        Category                  = $Definition.Category
        Severity                  = $severity
        RiskScore                 = $riskScore
        Confidence                = $confidence
        ObjectType                = $NhiObject.ObjectType
        ObjectId                  = $NhiObject.ObjectId
        DisplayName               = $NhiObject.DisplayName
        Evidence                  = (& $Definition.Evidence $NhiObject $Extra)
        EvidenceSource            = 'graph'
        GraphEndpoint             = $Definition.GraphEndpoint
        RecommendedAction         = $Definition.RecommendedAction
        RemediationMode           = $Definition.RemediationMode
        Classification            = $NhiObject.Classification
        ClassificationConfidence  = $NhiObject.ClassificationConfidence
        ClassificationSignals     = $NhiObject.ClassificationSignals
        ClassificationScore       = $NhiObject.ClassificationScore
        NhiCandidate              = $NhiObject.NhiCandidate
        AgenticCandidate          = $NhiObject.AgenticCandidate
        AutomationCandidate       = $NhiObject.AutomationCandidate
        WorkloadCandidate         = $NhiObject.WorkloadCandidate
        OwnerCount                = $NhiObject.OwnerCount
        CredentialCount           = $NhiObject.CredentialCount
        ExpiredCredentialCount    = $NhiObject.ExpiredCredentialCount
        ExpiringCredentialCount   = $NhiObject.ExpiringCredentialCount
        HighRiskPermissionCount   = $NhiObject.HighRiskPermissionCount
        HighRiskOAuthGrantCount   = $NhiObject.HighRiskOAuthGrantCount
        TenantWideConsent         = $NhiObject.TenantWideConsent
        VerifiedPublisherName     = $NhiObject.VerifiedPublisherName
        PublisherName             = $NhiObject.PublisherName
        FirstPartyMicrosoftApp    = $NhiObject.FirstPartyMicrosoftApp
        CoverageMode              = $NhiObject.CoverageMode
        RiskScoreMayBeUnderstated = $NhiObject.RiskScoreMayBeUnderstated
    }

    if ($Definition.IncludePlatformFields) {
        $params.MicrosoftFirstParty = $NhiObject.MicrosoftFirstParty
        $params.MicrosoftPlatform = $NhiObject.MicrosoftPlatform
        $params.EvidenceOnly = $false
    }

    return New-DecomFinding @params
}

function Invoke-DecomNhiGovernance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$AnalyzedNhiObjects,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    Write-DecomInfo "Starting NHI governance processing for $($AnalyzedNhiObjects.Count) objects..."
    Clear-DecomFindingTraceContext

    $governanceFindings = @()

    foreach ($nhiObject in $AnalyzedNhiObjects) {
        $null = Set-DecomFindingTraceContext -SourceObject $nhiObject -ClassificationSource 'NhiGovernance'
        try {
            # Skip if not an NHI candidate
            if (-not $nhiObject.NhiCandidate) { continue }

            # Microsoft platform identities: evidence-only override, then skip all
            # standard definitions (pre-refactor behavior preserved verbatim).
            if ($nhiObject.MicrosoftPlatform -eq $true) {
                $finding001 = New-DecomFinding `
                    -FindingId 'DEC-NHI-001' `
                    -Category 'NHI Inventory' `
                    -Severity 'Informational' `
                    -RiskScore 0 `
                    -Confidence 'High' `
                    -ObjectType $nhiObject.ObjectType `
                    -ObjectId $nhiObject.ObjectId `
                    -DisplayName $nhiObject.DisplayName `
                    -Evidence "Microsoft platform identity retained as evidence-only based on $($nhiObject.MicrosoftPlatformReason)" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals' `
                    -RecommendedAction 'Evidence only - suppress customer remediation' `
                    -RemediationMode 'InformationOnly' `
                    -Classification $nhiObject.Classification `
                    -ClassificationConfidence $nhiObject.ClassificationConfidence `
                    -ClassificationSignals $nhiObject.ClassificationSignals `
                    -ClassificationScore $nhiObject.ClassificationScore `
                    -NhiCandidate $nhiObject.NhiCandidate `
                    -AgenticCandidate $false `
                    -AutomationCandidate $false `
                    -WorkloadCandidate $false `
                    -OwnerCount $nhiObject.OwnerCount `
                    -CredentialCount $nhiObject.CredentialCount `
                    -ExpiredCredentialCount $nhiObject.ExpiredCredentialCount `
                    -ExpiringCredentialCount $nhiObject.ExpiringCredentialCount `
                    -HighRiskPermissionCount $nhiObject.HighRiskPermissionCount `
                    -HighRiskOAuthGrantCount $($nhiObject.HighRiskOAuthGrantCount) `
                    -TenantWideConsent $nhiObject.TenantWideConsent `
                    -VerifiedPublisherName $nhiObject.VerifiedPublisherName `
                    -PublisherName $nhiObject.PublisherName `
                    -FirstPartyMicrosoftApp $nhiObject.FirstPartyMicrosoftApp `
                    -MicrosoftFirstParty $nhiObject.MicrosoftFirstParty `
                    -MicrosoftPlatform $nhiObject.MicrosoftPlatform `
                    -EvidenceOnly $true `
                    -CoverageMode $nhiObject.CoverageMode `
                    -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                $governanceFindings += $finding001
                continue
            }

            # Data-driven generation: definitions evaluated in declaration order,
            # matching the pre-refactor finding emission order exactly.
            foreach ($definition in $script:NhiGovernanceFindingDefinitions) {
                $conditionResult = & $definition.Condition $nhiObject
                if (-not $conditionResult) { continue }
                $extra = if ($conditionResult -is [hashtable]) { $conditionResult } else { $null }
                $governanceFindings += New-NhiGovernanceFindingFromDefinition -Definition $definition -NhiObject $nhiObject -Extra $extra
            }
        } catch {
            Write-Warning "Failed to process governance for NHI object $($nhiObject.DisplayName): $_"
        } finally {
            Clear-DecomFindingTraceContext
        }
    }

    Write-DecomOk "NHI governance processing complete — $($governanceFindings.Count) finding(s) generated"
    return $governanceFindings
}

Export-ModuleMember -Function Invoke-DecomNhiGovernance
