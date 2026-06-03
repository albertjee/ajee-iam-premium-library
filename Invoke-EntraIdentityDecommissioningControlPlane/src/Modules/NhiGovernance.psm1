#Requires -Version 5.1

function Invoke-DecomNhiGovernance {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject[]]$AnalyzedNhiObjects,
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    Write-DecomInfo "Starting NHI governance processing for $($AnalyzedNhiObjects.Count) objects..."

    $governanceFindings = @()

    foreach ($nhiObject in $AnalyzedNhiObjects) {
        try {
            # Skip if not an NHI candidate
            if (-not $nhiObject.NhiCandidate) { continue }

            # Generate DEC-NHI-001 - Entra-visible NHI candidate detected
            $finding001 = New-DecomFinding `
                -FindingId 'DEC-NHI-001' `
                -Category 'NHI Inventory' `
                -Severity $nhiObject.Severity `
                -RiskScore $nhiObject.RiskScore `
                -Confidence $nhiObject.ClassificationConfidence `
                -ObjectType $nhiObject.ObjectType `
                -ObjectId $nhiObject.ObjectId `
                -DisplayName $nhiObject.DisplayName `
                -Evidence "Entra-visible NHI candidate based on $($nhiObject.ClassificationSignals -join ', ')" `
                -EvidenceSource 'graph' `
                -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals' `
                -RecommendedAction 'Review for ownership, credentials, and permissions' `
                -RemediationMode 'InformationOnly' `
                -Classification $nhiObject.Classification `
                -ClassificationConfidence $nhiObject.ClassificationConfidence `
                -ClassificationSignals $nhiObject.ClassificationSignals `
                -ClassificationScore $nhiObject.ClassificationScore `
                -NhiCandidate $nhiObject.NhiCandidate `
                -AgenticCandidate $nhiObject.AgenticCandidate `
                -AutomationCandidate $nhiObject.AutomationCandidate `
                -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                -CoverageMode $nhiObject.CoverageMode `
                -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

            $governanceFindings += $finding001

            # Generate DEC-NHI-002 - NHI has no owner
            if ($nhiObject.OwnerCount -eq 0) {
                $finding002 = New-DecomFinding `
                    -FindingId 'DEC-NHI-002' `
                    -Category 'NHI Ownership' `
                    -Severity 'High' `
                    -RiskScore 62 `
                    -Confidence 'High' `
                    -ObjectType $nhiObject.ObjectType `
                    -ObjectId $nhiObject.ObjectId `
                    -DisplayName $nhiObject.DisplayName `
                    -Evidence 'NHI has no owner assigned' `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/owners' `
                    -RecommendedAction 'Assign owner using AddApplicationOwner action' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -Classification $nhiObject.Classification `
                    -ClassificationConfidence $nhiObject.ClassificationConfidence `
                    -ClassificationSignals $nhiObject.ClassificationSignals `
                    -ClassificationScore $nhiObject.ClassificationScore `
                    -NhiCandidate $nhiObject.NhiCandidate `
                    -AgenticCandidate $nhiObject.AgenticCandidate `
                    -AutomationCandidate $nhiObject.AutomationCandidate `
                    -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                    -CoverageMode $nhiObject.CoverageMode `
                    -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                $governanceFindings += $finding002
            }

            # Generate DEC-NHI-003 - NHI has only one owner
            if ($nhiObject.OwnerCount -eq 1) {
                $finding003 = New-DecomFinding `
                    -FindingId 'DEC-NHI-003' `
                    -Category 'NHI Ownership' `
                    -Severity 'Medium' `
                    -RiskScore 44 `
                    -Confidence 'High' `
                    -ObjectType $nhiObject.ObjectType `
                    -ObjectId $nhiObject.ObjectId `
                    -DisplayName $nhiObject.DisplayName `
                    -Evidence 'NHI has only one owner assigned' `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/owners' `
                    -RecommendedAction 'Consider assigning additional owner for redundancy' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -Classification $nhiObject.Classification `
                    -ClassificationConfidence $nhiObject.ClassificationConfidence `
                    -ClassificationSignals $nhiObject.ClassificationSignals `
                    -ClassificationScore $nhiObject.ClassificationScore `
                    -NhiCandidate $nhiObject.NhiCandidate `
                    -AgenticCandidate $nhiObject.AgenticCandidate `
                    -AutomationCandidate $nhiObject.AutomationCandidate `
                    -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                    -CoverageMode $nhiObject.CoverageMode `
                    -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                $governanceFindings += $finding003
            }

            # Generate DEC-NHI-004 - NHI owned by disabled identity
            $disabledOwnerCount = 0
            if ($nhiObject.RawOwners) {
                foreach ($owner in $nhiObject.RawOwners) {
                    if ($owner.AccountEnabled -eq $false) {
                        $disabledOwnerCount++
                    }
                }
            }
            if ($disabledOwnerCount -gt 0) {
                $finding004 = New-DecomFinding `
                    -FindingId 'DEC-NHI-004' `
                    -Category 'NHI Ownership' `
                    -Severity 'High' `
                    -RiskScore 68 `
                    -Confidence 'High' `
                    -ObjectType $nhiObject.ObjectType `
                    -ObjectId $nhiObject.ObjectId `
                    -DisplayName $nhiObject.DisplayName `
                    -Evidence "NHI is owned by $disabledOwnerCount disabled identity(ies)" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/owners' `
                    -RecommendedAction 'Assign owner using AddApplicationOwner action' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -Classification $nhiObject.Classification `
                    -ClassificationConfidence $nhiObject.ClassificationConfidence `
                    -ClassificationSignals $nhiObject.ClassificationSignals `
                    -ClassificationScore $nhiObject.ClassificationScore `
                    -NhiCandidate $nhiObject.NhiCandidate `
                    -AgenticCandidate $nhiObject.AgenticCandidate `
                    -AutomationCandidate $nhiObject.AutomationCandidate `
                    -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                    -CoverageMode $nhiObject.CoverageMode `
                    -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                $governanceFindings += $finding004
            }

            # Generate DEC-NHI-005 - NHI credential expired or stale
            # This would be calculated based on credential expiration dates
            # For now, we'll skip the detailed implementation and note it needs credential date checking

            # Generate DEC-NHI-006 - NHI credential expiring soon
            # Similar to above

            # Generate DEC-NHI-007 - NHI has high-risk Graph application permission
            if ($nhiObject.HighRiskPermissionCount -gt 0) {
                $finding007 = New-DecomFinding `
                    -FindingId 'DEC-NHI-007' `
                    -Category 'NHI Permission Risk' `
                    -Severity 'High' `
                    -RiskScore 72 `
                    -Confidence 'High' `
                    -ObjectType $nhiObject.ObjectType `
                    -ObjectId $nhiObject.ObjectId `
                    -DisplayName $nhiObject.DisplayName `
                    -Evidence "NHI has $($nhiObject.HighRiskPermissionCount) high-risk Graph application permission(s)" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/appRoleAssignments' `
                    -RecommendedAction 'Review permission necessity and consider removal' `
                    -RemediationMode 'InformationOnly' `
                    -Classification $nhiObject.Classification `
                    -ClassificationConfidence $nhiObject.ClassificationConfidence `
                    -ClassificationSignals $nhiObject.ClassificationSignals `
                    -ClassificationScore $nhiObject.ClassificationScore `
                    -NhiCandidate $nhiObject.NhiCandidate `
                    -AgenticCandidate $nhiObject.AgenticCandidate `
                    -AutomationCandidate $nhiObject.AutomationCandidate `
                    -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                    -CoverageMode $nhiObject.CoverageMode `
                    -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                $governanceFindings += $finding007
            }

            # Generate DEC-NHI-008 - NHI has high-risk delegated OAuth grant
            # This would need to check OAuth grants against high-risk scopes

            # Generate DEC-NHI-009 - NHI has tenant-wide AllPrincipals consent
            if ($nhiObject.TenantWideConsent) {
                $finding009 = New-DecomFinding `
                    -FindingId 'DEC-NHI-009' `
                    -Category 'NHI Consent Risk' `
                    -Severity 'Critical' `
                    -RiskScore 85 `
                    -Confidence 'High' `
                    -ObjectType $nhiObject.ObjectType `
                    -ObjectId $nhiObject.ObjectId `
                    -DisplayName $nhiObject.DisplayName `
                    -Evidence 'NHI has tenant-wide AllPrincipals consent' `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/oauth2PermissionGrants' `
                    -RecommendedAction 'Review consent necessity and consider removal' `
                    -RemediationMode 'InformationOnly' `
                    -Classification $nhiObject.Classification `
                    -ClassificationConfidence $nhiObject.ClassificationConfidence `
                    -ClassificationSignals $nhiObject.ClassificationSignals `
                    -ClassificationScore $nhiObject.ClassificationScore `
                    -NhiCandidate $nhiObject.NhiCandidate `
                    -AgenticCandidate $nhiObject.AgenticCandidate `
                    -AutomationCandidate $nhiObject.AutomationCandidate `
                    -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                    -CoverageMode $nhiObject.CoverageMode `
                    -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                $governanceFindings += $finding009
            }

            # Generate DEC-NHI-010 - NHI publisher verification gap
            if (-not $nhiObject.IsVerifiedPublisher) {
                $finding010 = New-DecomFinding `
                    -FindingId 'DEC-NHI-010' `
                    -Category 'NHI Publisher Risk' `
                    -Severity 'Medium' `
                    -RiskScore 45 `
                    -Confidence 'Medium' `
                    -ObjectType $nhiObject.ObjectType `
                    -ObjectId $nhiObject.ObjectId `
                    -DisplayName $nhiObject.DisplayName `
                    -Evidence 'NHI publisher verification cannot be verified' `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/applications/$($nhiObject.AppId)' `
                    -RecommendedAction 'Verify publisher through Microsoft Partner Center' `
                    -RemediationMode 'InformationOnly' `
                    -Classification $nhiObject.Classification `
                    -ClassificationConfidence $nhiObject.ClassificationConfidence `
                    -ClassificationSignals $nhiObject.ClassificationSignals `
                    -ClassificationScore $nhiObject.ClassificationScore `
                    -NhiCandidate $nhiObject.NhiCandidate `
                    -AgenticCandidate $nhiObject.AgenticCandidate `
                    -AutomationCandidate $nhiObject.AutomationCandidate `
                    -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                    -CoverageMode $nhiObject.CoverageMode `
                    -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                $governanceFindings += $finding010
            }

            # Generate DEC-NHI-011 - NHI coverage partial or incomplete
            # This would be set based on collection failures

            # Generate DEC-NHI-012 - NHI has app-role assignments but no owner accountability
            if ($nhiObject.HighRiskPermissionCount -gt 0 -and $nhiObject.OwnerCount -eq 0) {
                $finding012 = New-DecomFinding `
                    -FindingId 'DEC-NHI-012' `
                    -Category 'NHI Permission Ownership Correlation' `
                    -Severity 'High' `
                    -RiskScore 70 `
                    -Confidence 'High' `
                    -ObjectType $nhiObject.ObjectType `
                    -ObjectId $nhiObject.ObjectId `
                    -DisplayName $nhiObject.DisplayName `
                    -Evidence "NHI has $($nhiObject.HighRiskPermissionCount) high-risk app-role assignments but no owner" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/appRoleAssignments' `
                    -RecommendedAction 'Assign owner using AddApplicationOwner action' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -Classification $nhiObject.Classification `
                    -ClassificationConfidence $nhiObject.ClassificationConfidence `
                    -ClassificationSignals $nhiObject.ClassificationSignals `
                    -ClassificationScore $nhiObject.ClassificationScore `
                    -NhiCandidate $nhiObject.NhiCandidate `
                    -AgenticCandidate $nhiObject.AgenticCandidate `
                    -AutomationCandidate $nhiObject.AutomationCandidate `
                    -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                    -CoverageMode $nhiObject.CoverageMode `
                    -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                $governanceFindings += $finding012
            }

            # Now generate DEC-AGENT findings for agent-like identities
            if ($nhiObject.AgenticCandidate) {
                # DEC-AGENT-001 - Native agent/service identity detected
                if ($nhiObject.ServicePrincipalType -eq 'ServiceIdentity') {
                    $findingAgent001 = New-DecomFinding `
                        -FindingId 'DEC-AGENT-001' `
                        -Category 'Agentic Identity Inventory' `
                        -Severity 'Informational' `
                        -RiskScore 20 `
                        -Confidence 'High' `
                        -ObjectType $nhiObject.ObjectType `
                        -ObjectId $nhiObject.ObjectId `
                        -DisplayName $nhiObject.DisplayName `
                        -Evidence 'Native ServiceIdentity service principal detected' `
                        -EvidenceSource 'graph' `
                        -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)' `
                        -RecommendedAction 'Review for official sanction and documentation' `
                        -RemediationMode 'InformationOnly' `
                        -Classification $nhiObject.Classification `
                        -ClassificationConfidence $nhiObject.ClassificationConfidence `
                        -ClassificationSignals $nhiObject.ClassificationSignals `
                        -ClassificationScore $nhiObject.ClassificationScore `
                        -NhiCandidate $nhiObject.NhiCandidate `
                        -AgenticCandidate $nhiObject.AgenticCandidate `
                        -AutomationCandidate $nhiObject.AutomationCandidate `
                        -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                        -CoverageMode $nhiObject.CoverageMode `
                        -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                    $governanceFindings += $findingAgent001
                }

                # DEC-AGENT-002 - Likely AI-agent identity detected by naming pattern
                # This would be based on the classification signals

                # DEC-AGENT-003 - Agent-like identity has no owner
                if ($nhiObject.OwnerCount -eq 0) {
                    $findingAgent003 = New-DecomFinding `
                        -FindingId 'DEC-AGENT-003' `
                        -Category 'Agent Ownership' `
                        -Severity 'High' `
                        -RiskScore 68 `
                        -Confidence 'High' `
                        -ObjectType $nhiObject.ObjectType `
                        -ObjectId $nhiObject.ObjectId `
                        -DisplayName $nhiObject.DisplayName `
                        -Evidence 'Agent-like identity has no owner assigned' `
                        -EvidenceSource 'graph' `
                        -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/owners' `
                        -RecommendedAction 'Assign owner using AddApplicationOwner action' `
                        -RemediationMode 'ManualApprovalRequired' `
                        -Classification $nhiObject.Classification `
                        -ClassificationConfidence $nhiObject.ClassificationConfidence `
                        -ClassificationSignals $nhiObject.ClassificationSignals `
                        -ClassificationScore $nhiObject.ClassificationScore `
                        -NhiCandidate $nhiObject.NhiCandidate `
                        -AgenticCandidate $nhiObject.AgenticCandidate `
                        -AutomationCandidate $nhiObject.AutomationCandidate `
                        -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                        -CoverageMode $nhiObject.CoverageMode `
                        -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                    $governanceFindings += $findingAgent003
                }

                # DEC-AGENT-004 - Agent-like identity has high-risk Graph permission
                if ($nhiObject.HighRiskPermissionCount -gt 0) {
                    $findingAgent004 = New-DecomFinding `
                        -FindingId 'DEC-AGENT-004' `
                        -Category 'Agent Permission Risk' `
                        -Severity 'High' `
                        -RiskScore 76 `
                        -Confidence 'High' `
                        -ObjectType $nhiObject.ObjectType `
                        -ObjectId $nhiObject.ObjectId `
                        -DisplayName $nhiObject.DisplayName `
                        -Evidence "Agent-like identity has $($nhiObject.HighRiskPermissionCount) high-risk Graph permission(s)" `
                        -EvidenceSource 'graph' `
                        -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/appRoleAssignments' `
                        -RecommendedAction 'Review permission necessity and consider removal' `
                        -RemediationMode 'InformationOnly' `
                        -Classification $nhiObject.Classification `
                        -ClassificationConfidence $nhiObject.ClassificationConfidence `
                        -ClassificationSignals $nhiObject.ClassificationSignals `
                        -ClassificationScore $nhiObject.ClassificationScore `
                        -NhiCandidate $nhiObject.NhiCandidate `
                        -AgenticCandidate $nhiObject.AgenticCandidate `
                        -AutomationCandidate $nhiObject.AutomationCandidate `
                        -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                        -CoverageMode $nhiObject.CoverageMode `
                        -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                    $governanceFindings += $findingAgent004
                }

                # DEC-AGENT-005 - Agent-like identity has tenant-wide consent
                if ($nhiObject.TenantWideConsent) {
                    $findingAgent005 = New-DecomFinding `
                        -FindingId 'DEC-AGENT-005' `
                        -Category 'Agent Consent Risk' `
                        -Severity 'Critical' `
                        -RiskScore 88 `
                        -Confidence 'High' `
                        -ObjectType $nhiObject.ObjectType `
                        -ObjectId $nhiObject.ObjectId `
                        -DisplayName $nhiObject.DisplayName `
                        -Evidence 'Agent-like identity has tenant-wide AllPrincipals consent' `
                        -EvidenceSource 'graph' `
                        -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/$($nhiObject.ObjectId)/oauth2PermissionGrants' `
                        -RecommendedAction 'Review consent necessity and consider removal' `
                        -RemediationMode 'InformationOnly' `
                        -Classification $nhiObject.Classification `
                        -ClassificationConfidence $nhiObject.ClassificationConfidence `
                        -ClassificationSignals $nhiObject.ClassificationSignals `
                        -ClassificationScore $nhiObject.ClassificationScore `
                        -NhiCandidate $nhiObject.NhiCandidate `
                        -AgenticCandidate $nhiObject.AgenticCandidate `
                        -AutomationCandidate $nhiObject.AutomationCandidate `
                        -WorkloadCandidate $nhiObject.WorkloadCandidate `
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
                        -CoverageMode $nhiObject.CoverageMode `
                        -RiskScoreMayBeUnderstated $nhiObject.RiskScoreMayBeUnderstated

                    $governanceFindings += $findingAgent005
                }

                # DEC-AGENT-006 - Agent-like identity has credential risk
                # Similar to NHI credential risk findings

                # DEC-AGENT-007 - Agentic identity governance evidence missing
                # This would be based on missing governance evidence
            }
        } catch {
            Write-Warning "Failed to process governance for NHI object $($nhiObject.DisplayName): $_"
        }
    }

    Write-DecomOk "NHI governance processing complete — $($governanceFindings.Count) finding(s) generated"
    return $governanceFindings}