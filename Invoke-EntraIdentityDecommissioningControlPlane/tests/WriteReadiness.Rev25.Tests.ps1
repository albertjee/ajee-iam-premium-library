#Requires -Version 5.1

Describe 'WriteReadiness.psm1 — Execution Scope Registry' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module WriteReadiness -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'WriteReadiness.psm1') -Force -DisableNameChecking
        $script:registry = Get-DecomExecutionScopeRegistry
    }

    AfterAll {
        Remove-Module WriteReadiness -Force -ErrorAction SilentlyContinue
    }

    It 'Registry contains exactly thirty entries (14 original + 8 Rev3.1 guest + 1 Rev3.2 credential + 7 Rev3.3 owner/CA)' {
        $script:registry.Count | Should -Be 30
    }

    It 'Registry includes DEC-USER-001' {
        $script:registry.FindingId | Should -Contain 'DEC-USER-001'
    }

    It 'Registry includes DEC-USER-002' {
        $script:registry.FindingId | Should -Contain 'DEC-USER-002'
    }

    It 'Registry includes DEC-USER-003' {
        $script:registry.FindingId | Should -Contain 'DEC-USER-003'
    }

    It 'Registry includes DEC-ROLE-001' {
        $script:registry.FindingId | Should -Contain 'DEC-ROLE-001'
    }

    It 'Registry includes DEC-APP-001 as AddApplicationOwner (Rev3.3)' {
        $script:registry.FindingId | Should -Contain 'DEC-APP-001'
    }

    It 'Registry does not include plan-only finding DEC-APP-004' {
        $script:registry.FindingId | Should -Not -Contain 'DEC-APP-004'
    }

    It 'Registry includes Rev3.0 finding DEC-PIM-001' {
        $script:registry.FindingId | Should -Contain 'DEC-PIM-001'
    }

    It 'Registry includes Rev3.0 finding DEC-AP-001' {
        $script:registry.FindingId | Should -Contain 'DEC-AP-001'
    }

    It 'Registry does not include Rev2.4 finding DEC-GOV-001' {
        $script:registry.FindingId | Should -Not -Contain 'DEC-GOV-001'
    }

    It 'All registry entries have Status Executable or ExecutableWhenExactTargetPresent' {
        $validStatuses = @('Executable', 'ExecutableWhenExactTargetPresent', 'ExecutableWhenExactExpiredCredentialKeyIdPresent', 'ExecutableWhenExactOwnerObjectIdPresent')
        $invalid = @($script:registry | Where-Object { $_.Status -notin $validStatuses })
        $invalid.Count | Should -Be 0
    }

    It 'Registry entries have valid IntroducedIn version labels' {
        $validVersions = @('Rev2.0', 'Rev3.0', 'Rev3.1', 'Rev3.2', 'Rev3.3')
        $invalid = @($script:registry | Where-Object { $_.IntroducedIn -notin $validVersions })
        $invalid.Count | Should -Be 0
    }

    It 'All registry write scopes are in the approved scope list' {
        $allowed = @(
            'GroupMember.ReadWrite.All'
            'AppRoleAssignment.ReadWrite.All'
            'RoleManagement.ReadWrite.Directory'
            'EntitlementManagement.ReadWrite.All'
            'Application.ReadWrite.All'
            'Policy.Read.All'
            'GroupMember.ReadWrite.All + Policy.Read.All'
        )
        foreach ($entry in $script:registry) {
            $allowed | Should -Contain $entry.WriteScope
        }
    }
}

Describe 'WriteReadiness.psm1 — Rev3 Write Candidate Registry' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module WriteReadiness -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'WriteReadiness.psm1') -Force -DisableNameChecking
        $script:candidates = Get-DecomRev3WriteCandidateRegistry
    }

    AfterAll {
        Remove-Module WriteReadiness -Force -ErrorAction SilentlyContinue
    }

    It 'Rev3 candidate registry contains access package assignment candidate' {
        $ap = @($script:candidates | Where-Object { $_.CandidateActionType -eq 'RemoveAccessPackageAssignment' })
        $ap.Count | Should -BeGreaterThan 0
    }

    It 'Rev3 candidate registry contains PIM eligible assignment candidate' {
        $pim = @($script:candidates | Where-Object { $_.CandidateActionType -eq 'RemovePimEligibleAssignment' })
        $pim.Count | Should -BeGreaterThan 0
    }

    It 'Unsafe app deletion candidate is marked Unsafe' {
        $unsafe = @($script:candidates | Where-Object { $_.FindingId -eq 'DEC-APP-001' })
        $unsafe.Count | Should -Be 1
        $unsafe[0].CandidateStatus | Should -Be 'Unsafe'
    }

    It 'Service principal deletion candidate is marked Unsafe' {
        $unsafe = @($script:candidates | Where-Object { $_.FindingId -eq 'DEC-SPN-001' })
        $unsafe.Count | Should -Be 1
        $unsafe[0].CandidateStatus | Should -Be 'Unsafe'
    }

    It 'CA exclusion write candidates are marked Deferred' {
        $deferred = @($script:candidates | Where-Object {
            $_.FindingId -in @('DEC-CA-002','DEC-CA-003') })
        $deferred.Count | Should -Be 2
        foreach ($d in $deferred) {
            $d.CandidateStatus | Should -Be 'Deferred'
        }
    }

    It 'All candidates have required registry fields' {
        $requiredFields = @('FindingId','CandidateActionType','CandidateStatus','ProposedWriteScope',
            'RiskLevel','RequiredApprovalEvidence','RequiredRollbackDesign',
            'RequiredPreflightChecks','RequiredPostWriteEvidence','RecommendedRev')
        foreach ($c in $script:candidates) {
            foreach ($field in $requiredFields) {
                $c.$field | Should -Not -BeNullOrEmpty -Because "FindingId=$($c.FindingId) needs $field"
            }
        }
    }
}

Describe 'WriteReadiness.psm1 — Rev3 Write-Readiness Report' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module WriteReadiness -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'WriteReadiness.psm1') -Force -DisableNameChecking
        $script:testOutputDir = Join-Path $env:TEMP 'Decom-WR-Test'
        New-Item -ItemType Directory -Path $script:testOutputDir -Force | Out-Null
        $script:context = [PSCustomObject]@{
            ToolVersion  = 'Rev3.0'
            OutputPath   = $script:testOutputDir
            ClientName   = 'TestClient'
            EngagementId = 'test-eng'
            Assessor     = 'TestAssessor'
        }
        $script:report = New-DecomRev3WriteReadinessReport -Context $script:context
    }

    AfterAll {
        if (Test-Path $script:testOutputDir) { Remove-Item $script:testOutputDir -Recurse -Force }
        Remove-Module WriteReadiness -Force -ErrorAction SilentlyContinue
    }

    It 'Write-readiness report recommendation is ReadyForRev3Design' {
        $script:report.Recommendation | Should -Be 'ReadyForRev3Design'
    }

    It 'Write-readiness report recommendation is not ReadyForRev3Implementation' {
        $script:report.Recommendation | Should -Not -Be 'ReadyForRev3Implementation'
    }

    It 'Write-readiness report has correct schema version' {
        $script:report.SchemaVersion | Should -Be '3.0'
    }

    It 'Write-readiness report contains ExecutionScopeRegistry' {
        $script:report.ExecutionScopeRegistry | Should -Not -BeNullOrEmpty
    }

    It 'Write-readiness report contains Rev3Candidates' {
        $script:report.Rev3Candidates | Should -Not -BeNullOrEmpty
    }

    It 'Export-DecomRev3WriteReadinessJson creates JSON file' {
        { Export-DecomRev3WriteReadinessJson -Report $script:report -Context $script:context } | Should -Not -Throw
        $files = Get-ChildItem -Path $script:testOutputDir -Filter 'rev3-write-readiness-report-*.json'
        $files.Count | Should -BeGreaterThan 0
        $json = Get-Content $files[0].FullName -Raw | ConvertFrom-Json
        $json.SchemaVersion | Should -Be '3.0'
        $json.Recommendation | Should -Be 'ReadyForRev3Design'
    }

    It 'Export-DecomRev3WriteReadinessMarkdown creates Markdown file' {
        { Export-DecomRev3WriteReadinessMarkdown -Report $script:report -Context $script:context } | Should -Not -Throw
        $files = Get-ChildItem -Path $script:testOutputDir -Filter 'rev3-write-readiness-report-*.md'
        $files.Count | Should -BeGreaterThan 0
        $md = Get-Content $files[0].FullName -Raw
        $md | Should -Match 'Rev3\.0 Write-Readiness Report'
        $md | Should -Match 'ReadyForRev3Design'
    }

    It 'Export-DecomExecutionScopeRegistryJson creates JSON file' {
        $reg = Get-DecomExecutionScopeRegistry
        { Export-DecomExecutionScopeRegistryJson -Registry $reg -Context $script:context } | Should -Not -Throw
        $files = Get-ChildItem -Path $script:testOutputDir -Filter 'execution-scope-registry-*.json'
        $files.Count | Should -BeGreaterThan 0
        $json = Get-Content $files[0].FullName -Raw | ConvertFrom-Json
        $json.SchemaVersion | Should -Be '3.0'
    }
}
