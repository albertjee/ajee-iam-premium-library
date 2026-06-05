#Requires -Version 5.1

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '..\src\Modules\NhiAgent.psm1'
    Import-Module $script:ModulePath -Force -DisableNameChecking
}

Describe 'NhiAgent.Rev39 - NHI-AGENT-001/002/003 and DEC-AGENT-002/006/007' {

    BeforeAll {
        # Shared SP objects for testing
        $script:SpAgenticWithAgentName = [PSCustomObject]@{
            Id = 'sp-agentic-001'; DisplayName = 'contoso-agent-prod'
            ServicePrincipalType = 'Application'; AppId = 'app-agentic-001'
            AgenticCandidate = $true
            OwnerCount = 1; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpAgenticWithCopilotName = [PSCustomObject]@{
            Id = 'sp-agentic-002'; DisplayName = 'HR-Copilot-Assistant'
            ServicePrincipalType = 'Application'; AppId = 'app-agentic-002'
            AgenticCandidate = $true
            OwnerCount = 1; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpAgenticNoPattern = [PSCustomObject]@{
            Id = 'sp-agentic-003'; DisplayName = 'contoso-service-worker'
            ServicePrincipalType = 'Application'; AppId = 'app-agentic-003'
            AgenticCandidate = $true
            OwnerCount = 1; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpNonAgenticAgent = [PSCustomObject]@{
            Id = 'sp-na-agent-001'; DisplayName = 'some-agent-tool'
            ServicePrincipalType = 'Application'; AppId = 'app-na-agent-001'
            AgenticCandidate = $false
            OwnerCount = 1; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpNonAgenticCopilot = [PSCustomObject]@{
            Id = 'sp-na-copilot-001'; DisplayName = 'HR-Copilot-Tool'
            ServicePrincipalType = 'Application'; AppId = 'app-na-copilot-001'
            AgenticCandidate = $false
            OwnerCount = 1; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpManagedIdentity = [PSCustomObject]@{
            Id = 'sp-mi-001'; DisplayName = 'managed-identity-runner'
            ServicePrincipalType = 'ManagedIdentity'; AppId = 'app-mi-001'
            AgenticCandidate = $false
            OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpBlueprintNoOwner = [PSCustomObject]@{
            Id = 'sp-blue-001'; DisplayName = 'copilot-studio-agent'
            ServicePrincipalType = 'Application'; AppId = 'app-blue-001'
            AgenticCandidate = $false
            OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpBlueprintHighRisk = [PSCustomObject]@{
            Id = 'sp-blue-002'; DisplayName = 'copilot-hr-agent'
            ServicePrincipalType = 'Application'; AppId = 'app-blue-002'
            AgenticCandidate = $false
            OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 3
        }
        $script:SpAgenticNoOwnerHighRisk = [PSCustomObject]@{
            Id = 'sp-agentic-004'; DisplayName = 'unowned-agent-risk'
            ServicePrincipalType = 'Application'; AppId = 'app-agentic-004'
            AgenticCandidate = $true
            OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 2
        }
        $script:SpAgenticWithOwnerHighRisk = [PSCustomObject]@{
            Id = 'sp-agentic-005'; DisplayName = 'owned-agent-risk'
            ServicePrincipalType = 'Application'; AppId = 'app-agentic-005'
            AgenticCandidate = $true
            OwnerCount = 1; CredentialCount = 0; HighRiskPermissionCount = 2
        }
        $script:SpAgenticNoOwnerNoRisk = [PSCustomObject]@{
            Id = 'sp-agentic-006'; DisplayName = 'unowned-agent-no-risk'
            ServicePrincipalType = 'Application'; AppId = 'app-agentic-006'
            AgenticCandidate = $true
            OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpAgenticWithCreds = [PSCustomObject]@{
            Id = 'sp-agentic-007'; DisplayName = 'agent-with-creds'
            ServicePrincipalType = 'Application'; AppId = 'app-agentic-007'
            AgenticCandidate = $true
            OwnerCount = 1; CredentialCount = 2; HighRiskPermissionCount = 0
        }
        $script:SpAgenticNoCreds = [PSCustomObject]@{
            Id = 'sp-agentic-008'; DisplayName = 'agent-no-creds'
            ServicePrincipalType = 'Application'; AppId = 'app-agentic-008'
            AgenticCandidate = $true
            OwnerCount = 1; CredentialCount = 0; HighRiskPermissionCount = 0
        }
        $script:SpBlueprintEmptyString = [PSCustomObject]@{
            Id = 'sp-blue-003'; DisplayName = 'blueprint-empty-id'
            ServicePrincipalType = 'Application'; AppId = 'app-blue-003'
            AgenticCandidate = $false
            OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 1
        }
    }

    # --- NHI-AGENT-001 tests ---

    Context 'NHI-AGENT-001: fires for non-AgenticCandidate with name patterns' {
        It 'fires when NOT AgenticCandidate and name contains "agent"' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpNonAgenticAgent) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-001' }
            $f | Should -Not -BeNullOrEmpty
            $f.Confidence | Should -Be 'High'
            $f.RiskScore | Should -Be 25
        }

        It 'fires when NOT AgenticCandidate and name contains "copilot"' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpNonAgenticCopilot) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-001' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'does NOT fire when AgenticCandidate=true and name has no pattern match' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticNoPattern) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-001' }
            $f | Should -BeNullOrEmpty
        }

        It 'fires for ManagedIdentity with no name pattern match (Confidence=Low)' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpManagedIdentity) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-001' }
            $f | Should -Not -BeNullOrEmpty
            $f.Confidence | Should -Be 'Low'
            $f.RiskScore | Should -Be 15
            $f.ConsultantNote | Should -Match 'ManagedIdentity'
        }
    }

    # --- NHI-AGENT-002 tests ---

    Context 'NHI-AGENT-002: Blueprint-derived agent with no owner' {
        It 'fires when AgentIdentityBlueprintId is set and OwnerCount=0' {
            $blueprintMap = @{ 'sp-blue-001' = 'blueprint-abc-123' }
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpBlueprintNoOwner) -AgentBlueprintIdByObjectId $blueprintMap
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-002' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'High'
            $f.RiskScore | Should -Be 68
            $f.Confidence | Should -Be 'High'
        }

        It 'does NOT fire when AgentIdentityBlueprintId is null' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpBlueprintNoOwner) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-002' }
            $f | Should -BeNullOrEmpty
        }

        It 'does NOT fire when AgentIdentityBlueprintId is empty string' {
            $blueprintMap = @{ 'sp-blue-003' = '' }
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpBlueprintEmptyString) -AgentBlueprintIdByObjectId $blueprintMap
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-002' }
            $f | Should -BeNullOrEmpty
        }
    }

    # --- NHI-AGENT-003 tests ---

    Context 'NHI-AGENT-003: Blueprint-derived agent with high-risk permissions' {
        It 'fires when AgentIdentityBlueprintId is set and HighRiskPermissionCount > 0' {
            $blueprintMap = @{ 'sp-blue-002' = 'blueprint-xyz-789' }
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpBlueprintHighRisk) -AgentBlueprintIdByObjectId $blueprintMap
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-003' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Critical'
            $f.RiskScore | Should -Be 85
        }

        It 'does NOT fire when AgentIdentityBlueprintId is null' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpBlueprintHighRisk) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-003' }
            $f | Should -BeNullOrEmpty
        }
    }

    # --- DEC-AGENT-002 tests ---

    Context 'DEC-AGENT-002: fires for AgenticCandidate with name patterns' {
        It 'fires when AgenticCandidate and name contains "agent"' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticWithAgentName) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'DEC-AGENT-002' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Informational'
            $f.RiskScore | Should -Be 15
        }

        It 'fires when AgenticCandidate and name contains "copilot"' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticWithCopilotName) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'DEC-AGENT-002' }
            $f | Should -Not -BeNullOrEmpty
        }

        It 'does NOT fire when AgenticCandidate but name has no pattern match' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticNoPattern) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'DEC-AGENT-002' }
            $f | Should -BeNullOrEmpty
        }
    }

    # --- DEC-AGENT-006 tests ---

    Context 'DEC-AGENT-006: AgenticCandidate with client secrets' {
        It 'fires when AgenticCandidate and CredentialCount >= 1' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticWithCreds) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'DEC-AGENT-006' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'High'
            $f.RiskScore | Should -Be 72
        }

        It 'does NOT fire when AgenticCandidate and CredentialCount = 0' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticNoCreds) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'DEC-AGENT-006' }
            $f | Should -BeNullOrEmpty
        }
    }

    # --- DEC-AGENT-007 tests ---

    Context 'DEC-AGENT-007: Agentic candidate with no owner AND high-risk permissions' {
        It 'fires when AgenticCandidate and OwnerCount=0 and HighRiskPermissionCount > 0' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticNoOwnerHighRisk) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'DEC-AGENT-007' }
            $f | Should -Not -BeNullOrEmpty
            $f.Severity | Should -Be 'Critical'
            $f.RiskScore | Should -Be 85
        }

        It 'does NOT fire when AgenticCandidate and has owner' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticWithOwnerHighRisk) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'DEC-AGENT-007' }
            $f | Should -BeNullOrEmpty
        }

        It 'does NOT fire when AgenticCandidate and no high-risk permission' {
            $result = Invoke-NhiAgentScan -ServicePrincipals @($script:SpAgenticNoOwnerNoRisk) -AgentBlueprintIdByObjectId @{}
            $f = $result | Where-Object { $_.FindingId -eq 'DEC-AGENT-007' }
            $f | Should -BeNullOrEmpty
        }
    }

    # --- Coexistence tests ---

    Context 'Finding coexistence' {
        It 'NHI-AGENT-002 and NHI-AGENT-003 can both fire for same SP' {
            $sp = [PSCustomObject]@{
                Id = 'sp-both-001'; DisplayName = 'copilot-studio-both'
                ServicePrincipalType = 'Application'; AppId = 'app-both-001'
                AgenticCandidate = $false
                OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 2
            }
            $blueprintMap = @{ 'sp-both-001' = 'blueprint-both-001' }
            $result = Invoke-NhiAgentScan -ServicePrincipals @($sp) -AgentBlueprintIdByObjectId $blueprintMap
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-002' }
            $f003 = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-003' }
            $f002 | Should -Not -BeNullOrEmpty
            $f003 | Should -Not -BeNullOrEmpty
        }

        It 'NHI-AGENT-002 (blueprint) and DEC-AGENT-003 (AgenticCandidate no owner) can coexist for same SP if SP is AgenticCandidate=true and has blueprint' {
            # Note: NHI-AGENT-002 needs blueprint+no owner, DEC-AGENT-003 needs AgenticCandidate+no owner
            $sp = [PSCustomObject]@{
                Id = 'sp-coexist-001'; DisplayName = 'copilot-agent'
                ServicePrincipalType = 'Application'; AppId = 'app-coexist-001'
                AgenticCandidate = $true
                OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 0
            }
            $blueprintMap = @{ 'sp-coexist-001' = 'blueprint-coexist-001' }
            $result = Invoke-NhiAgentScan -ServicePrincipals @($sp) -AgentBlueprintIdByObjectId $blueprintMap
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-002' }
            # DEC-AGENT-003 would need NhiGovernance - not in this module
            $f002 | Should -Not -BeNullOrEmpty
        }
    }

    # --- Edge case: empty hashtable for blueprint map ---

    Context 'Dormant findings behavior when data unavailable' {
        It 'NHI-AGENT-002 and NHI-AGENT-003 do not fire when AgentBlueprintIdByObjectId is empty' {
            $sp = [PSCustomObject]@{
                Id = 'sp-dormant-001'; DisplayName = 'blueprint-agent-without-map'
                ServicePrincipalType = 'Application'; AppId = 'app-dormant-001'
                AgenticCandidate = $false
                OwnerCount = 0; CredentialCount = 0; HighRiskPermissionCount = 5
            }
            $result = Invoke-NhiAgentScan -ServicePrincipals @($sp) -AgentBlueprintIdByObjectId @{}
            $f002 = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-002' }
            $f003 = $result | Where-Object { $_.FindingId -eq 'NHI-AGENT-003' }
            $f002 | Should -BeNullOrEmpty
            $f003 | Should -BeNullOrEmpty
        }
    }
}