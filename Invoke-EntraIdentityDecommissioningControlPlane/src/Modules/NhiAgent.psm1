Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

$script:AgentNamePattern = 'agent|copilot|assistant|bot|automation|workflow'

function Invoke-NhiAgentScan {
    [CmdletBinding()]
    param(
        [object[]]$ServicePrincipals,
        [hashtable]$AgentBlueprintIdByObjectId = @{}
    )

    $findings = @()

    foreach ($sp in $ServicePrincipals) {
        $null = Set-DecomFindingTraceContext -SourceObject $sp -ClassificationSource 'NhiAgent'
        $blueprintId = $null
        if ($AgentBlueprintIdByObjectId -and $AgentBlueprintIdByObjectId.ContainsKey($sp.Id)) {
            $blueprintId = $AgentBlueprintIdByObjectId[$sp.Id]
        }
        $blueprintIdPresent = $null -ne $blueprintId -and $blueprintId -ne ''
        $agentMatched = $sp.DisplayName -match $script:AgentNamePattern

        # NHI-AGENT-001: Non-AgenticCandidate with agent-like signals
        if (-not $sp.AgenticCandidate -and $agentMatched) {
            $findings += New-DecomFinding `
                -FindingId 'NHI-AGENT-001' `
                -Category 'Agent Identity' `
                -Severity 'Medium' `
                -RiskScore 25 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "DisplayName matches agent pattern but SP is not classified as AgenticCandidate" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)" `
                -RecommendedAction 'Review this identity for official sanction and AI-agent classification' `
                -RemediationMode 'InformationOnly' `
                -ConsultantNote 'Name pattern suggests possible agent identity - verify with application owner'
        }

        if (-not $sp.AgenticCandidate -and
            $sp.ServicePrincipalType -eq 'ManagedIdentity' -and
            -not $agentMatched) {
            $findings += New-DecomFinding `
                -FindingId 'NHI-AGENT-001' `
                -Category 'Agent Identity' `
                -Severity 'Low' `
                -RiskScore 15 `
                -Confidence 'Low' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence 'ServicePrincipalType is ManagedIdentity but display name does not match agent pattern' `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)" `
                -RecommendedAction 'Review this managed identity for official sanction and AI-agent classification' `
                -RemediationMode 'InformationOnly' `
                -ConsultantNote 'ManagedIdentity is an automation signal, not confirmed AI-agent. Verify with application owner whether this identity is used for AI/agentic workloads.'
        }

        # NHI-AGENT-002: Blueprint agent with no owner
        if ($blueprintIdPresent -and $null -ne $sp.OwnerCount -and $sp.OwnerCount -eq 0) {
            $findings += New-DecomFinding `
                -FindingId 'NHI-AGENT-002' `
                -Category 'Agent Identity' `
                -Severity 'High' `
                -RiskScore 68 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "SP has agentIdentityBlueprintId ($blueprintId) but no owner assigned" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)" `
                -RecommendedAction 'Assign an owner to this Copilot Studio agent identity' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'Blueprint-derived agent identity with no accountability sponsor'
        }

        # NHI-AGENT-003: Blueprint agent with high-risk permission
        if ($blueprintIdPresent -and $null -ne $sp.HighRiskPermissionCount -and $sp.HighRiskPermissionCount -gt 0) {
            $findings += New-DecomFinding `
                -FindingId 'NHI-AGENT-003' `
                -Category 'Agent Permission Risk' `
                -Severity 'Critical' `
                -RiskScore 85 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "SP has agentIdentityBlueprintId ($blueprintId) with $($sp.HighRiskPermissionCount) high-risk permission(s)" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/appRoleAssignments" `
                -RecommendedAction 'Review high-risk permissions on this Copilot Studio agent; restrict to minimum necessary' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'Blueprint-derived agent with high-risk permissions has no governance sponsor'
        }

        # DEC-AGENT-002: AgenticCandidate with name pattern
        if ($sp.AgenticCandidate -and $agentMatched) {
            $findings += New-DecomFinding `
                -FindingId 'DEC-AGENT-002' `
                -Category 'Agentic Identity Inventory' `
                -Severity 'Informational' `
                -RiskScore 15 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "AgenticCandidate display name matches agent pattern" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)" `
                -RecommendedAction 'Confirm official AI-agent classification and document in inventory' `
                -RemediationMode 'InformationOnly' `
                -ConsultantNote 'Naming pattern confirmation for classified agent identity'
        }

        # DEC-AGENT-006: AgenticCandidate with credentials (client secrets)
        if ($sp.AgenticCandidate -and $null -ne $sp.CredentialCount -and $sp.CredentialCount -gt 0) {
            $findings += New-DecomFinding `
                -FindingId 'DEC-AGENT-006' `
                -Category 'Agent Credential Risk' `
                -Severity 'High' `
                -RiskScore 72 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "AgenticCandidate has $($sp.CredentialCount) credential(s) - client secrets detected" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)" `
                -RecommendedAction 'Replace client secrets with certificate or managed identity for this agent identity' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'Agent identities should use managed identity or certificate auth, not client secrets'
        }
    }

    # DEC-AGENT-007: AgenticCandidate with no owner AND high-risk permission
    # (separate pass to ensure OwnerCount/HighRiskPermissionCount are checked together)
    foreach ($sp in $ServicePrincipals) {
        if ($sp.AgenticCandidate -and
            $null -ne $sp.OwnerCount -and $sp.OwnerCount -eq 0 -and
            $null -ne $sp.HighRiskPermissionCount -and $sp.HighRiskPermissionCount -gt 0) {
            $findings += New-DecomFinding `
                -FindingId 'DEC-AGENT-007' `
                -Category 'Agent Ownership' `
                -Severity 'Critical' `
                -RiskScore 85 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "AgenticCandidate has no owner and $($sp.HighRiskPermissionCount) high-risk permission(s)" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)" `
                -RecommendedAction 'Assign owner to this agent identity and review high-risk permissions' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'Unowned agent with high-risk permissions has no accountable governance sponsor'
        }
    }

    Clear-DecomFindingTraceContext
    return $findings
}

Export-ModuleMember -Function Invoke-NhiAgentScan
