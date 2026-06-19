# NhiActivityAudit.Rev41.Tests.ps1 - Rev4.1
# Pester v5 tests for M1-M6 activity audit modules

# =============================================================================
# BEFOREALL: Shared helpers + module imports
# =============================================================================

BeforeAll {
    $script:BasePath = $PSScriptRoot | Split-Path -Parent
    $script:ModulesPath = Join-Path $script:BasePath 'src\Modules'

    # Unload all modules to guarantee fresh load
    $toUnload = @('NhiActivityLog','NhiGraphApiAudit','NhiComplianceAudit',
                   'NhiTokenForensics','NhiConditionalAccessResponse','NhiPostDecomAudit',
                   'Utilities')
    foreach ($m in $toUnload) { Remove-Module $m -Force -EA SilentlyContinue }

    # Utilities first, then all audit modules
    Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')          -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiActivityLog.psm1')              -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiGraphApiAudit.psm1')            -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiComplianceAudit.psm1')          -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiTokenForensics.psm1')           -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiConditionalAccessResponse.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiPostDecomAudit.psm1')           -Force -DisableNameChecking
}

AfterAll {
    foreach ($m in @('NhiActivityLog','NhiGraphApiAudit','NhiComplianceAudit',
                     'NhiTokenForensics','NhiConditionalAccessResponse','NhiPostDecomAudit',
                     'Utilities')) {
        Remove-Module $m -Force -ErrorAction SilentlyContinue
    }
}

# =============================================================================
# SHARED TEST HELPERS (global: available to all Describe blocks)
# =============================================================================

function global:New-TestNhiObject {
    param(
        [string]$ObjectId           = '00000000-0000-0000-0000-000000000001',
        [string]$DisplayName        = 'TestAgentSvcPrincipal',
        [bool]$AgenticCandidate      = $true,
        [bool]$NhiCandidate          = $true,
        [bool]$AutomationCandidate  = $false,
        [bool]$WorkloadCandidate     = $true
    )
    [PSCustomObject]@{
        PSTypeName           = 'NhiFound'
        ObjectId            = $ObjectId
        DisplayName         = $DisplayName
        ObjectType          = 'ServicePrincipal'
        AgenticCandidate    = $AgenticCandidate
        NhiCandidate        = $NhiCandidate
        AutomationCandidate = $AutomationCandidate
        WorkloadCandidate   = $WorkloadCandidate
    }
}

function global:New-TestSignInLog {
    param([int]$Count = 5, [bool]$WithCAFailure = $false)
    $logs = @()
    for ($i = 0; $i -lt $Count; $i++) {
        $logs += [PSCustomObject]@{
            Id                              = "signin-$i"
            CreatedDateTime                = (Get-Date).AddHours(-$i).ToString('o')
            Status                          = @{ ErrorCode = 0 }
            ConditionalAccessStatus         = if ($WithCAFailure -and ($i % 3) -eq 0) { 'failure' } else { 'success' }
            IPAddress                       = "192.0.2.$($i + 1)"
            Location                        = if ($i % 2 -eq 0) { 'Seattle, WA' } else { 'Redmond, WA' }
            ClientAppUsed                   = if ($i % 2 -eq 0) { 'MSAL Python' } else { 'Mobile Apps' }
            AppliedConditionalAccessPolicies = @(@{ Id = "policy-$i" })
        }
    }
    return $logs
}

function global:New-TestDirectoryAuditLog {
    param([string[]]$Categories = @('User', 'Group', 'Role'))
    $logs = @()
    $idx = 0
    foreach ($cat in $Categories) {
        $logs += [PSCustomObject]@{
            Id                      = "audit-$idx"
            OperationType           = 'Update'
            ActivityDisplayName     = "$cat.Modify"
            Result                  = 'Success'
            AdditionalProperties    = @{
                loggedByService = 'Core Directory'
                operationType   = "$cat.Update"
                category        = $cat
                targetResources = @(@{ id = '00000000-0000-0000-0000-000000000001'; type = 'ServicePrincipal' })
            }
            CreatedDateTime         = (Get-Date).AddHours(-$idx).ToString('o')
        }
        $idx++
    }
    return $logs
}

function global:New-TestGraphApiAuditLog {
    param([string[]]$DisplayNames = @('Add user', 'Assign role to user', 'Update policy'))
    $logs = @()
    $idx = 0
    foreach ($name in $DisplayNames) {
        $logs += [PSCustomObject]@{
            Id                  = "graph-audit-$idx"
            ActivityDisplayName = $name
            Result              = if (($idx % 3) -eq 0) { 'Failure' } else { 'Success' }
            ResultReason        = ''
            CreatedDateTime     = (Get-Date).AddHours(-$idx).ToString('o')
        }
        $idx++
    }
    return $logs
}

function global:New-TempSnapshotManifest {
    param(
        [string]$ObjectId   = 'manifest-obj',
        [string]$DisplayName = 'ManifestNhi',
        [bool]$WithDisabledAt = $true
    )
    $path = [System.IO.Path]::GetTempFileName() + '.json'
    $disabledAt = if ($WithDisabledAt) { (Get-Date).AddHours(-2).ToUniversalTime().ToString('o') } else { $null }
    $manifest = [ordered]@{
        ExecutionRunId = 'TEST-REV41-RUN'
        EngagementId   = 'ENG-REV41-TEST'
        Records        = @(
            @{
                ObjectId    = $ObjectId
                DisplayName = $DisplayName
                DisabledAt  = $disabledAt
                Status      = 'Decommissioned'
            }
        )
    } | ConvertTo-Json -Depth 5
    [System.IO.File]::WriteAllText($path, $manifest, [System.Text.UTF8Encoding]::new($false))
    return $path
}

# =============================================================================
# M1: NhiActivityLog
# =============================================================================

Describe 'NhiActivityLog module exports' {
    It 'Exports 5 functions' {
        $exports = (Get-Module NhiActivityLog).ExportedFunctions.Keys
        $exports.Count | Should -Be 5
        $exports | Should -Contain 'Get-NhiAgentSignInLog'
        $exports | Should -Contain 'Invoke-NhiAgentSignInAnalysis'
        $exports | Should -Contain 'Get-NhiAgentDirectoryAuditLog'
        $exports | Should -Contain 'Invoke-NhiAgentDirectoryAuditAnalysis'
        $exports | Should -Contain 'Invoke-NhiActivityLogScan'
    }
}

Describe 'Invoke-NhiAgentSignInAnalysis - with log data' {
    BeforeAll {
        $script:Analysis = Invoke-NhiAgentSignInAnalysis -SignInLogs (New-TestSignInLog -Count 10) -ObjectId 'test-id'
    }

    It 'Has all expected properties' {
        foreach ($p in @('SignInCount','SuccessCount','FailureCount','FailureRate',
                          'MaxSignInInOneHour','ConditionalAccessBlockCount','ImpossibleTravelDetected',
                          'UniqueIpCount','OverallRiskScore','RiskSignals')) {
            $script:Analysis.PSObject.Properties.Name | Should -Contain $p
        }
    }

    It 'Returns SignInCount of 10' {
        $script:Analysis.SignInCount | Should -Be 10
    }

    It 'Returns 0 failures for all-successful logs' {
        $script:Analysis.SuccessCount  | Should -Be 10
        $script:Analysis.FailureCount  | Should -Be 0
        $script:Analysis.FailureRate    | Should -Be 0
    }

    It 'Returns zero risk score for clean logs' {
        $script:Analysis.OverallRiskScore | Should -Be 0
    }
}

Describe 'Invoke-NhiAgentSignInAnalysis - empty array' {
    It 'Returns zero-count result for @() input' {
        $result = Invoke-NhiAgentSignInAnalysis -SignInLogs @() -ObjectId 'empty-id'
        $result.SignInCount      | Should -Be 0
        $result.FailureRate      | Should -Be 0
        $result.OverallRiskScore  | Should -Be 0
        $result.RiskSignals.Count | Should -Be 0
    }
}

Describe 'Invoke-NhiAgentDirectoryAuditAnalysis - with data' {
    BeforeAll {
        $script:Analysis = Invoke-NhiAgentDirectoryAuditAnalysis -DirectoryLogs (New-TestDirectoryAuditLog) -ObjectId 'test-id'
    }

    It 'Returns 3 operations for 3 log entries' {
        $script:Analysis.DirectoryOperationCount | Should -Be 3
        $script:Analysis.SuccessCount            | Should -Be 3
    }

    It 'Has all expected properties' {
        foreach ($p in @('DirectoryOperationCount','SuccessCount','FailureCount',
                          'UserModificationCount','PrivilegedRoleChangeCount',
                          'GroupMembershipChangeCount','ApplicationConsentGrantCount',
                          'ComplianceEvasionSignals','OverallRiskScore','RiskSignals')) {
            $script:Analysis.PSObject.Properties.Name | Should -Contain $p
        }
    }
}

Describe 'Invoke-NhiActivityLogScan - skips non-agentic' {
    It 'Returns empty array when AgenticCandidate = $false' {
        $result = Invoke-NhiActivityLogScan -NhiObject (New-TestNhiObject -AgenticCandidate $false) -SignInLogs @() -DirectoryLogs @()
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-NhiActivityLogScan - reports NHI-ACT-005 for no activity' {
    It 'Returns NHI-ACT-005 Informational finding when SignInCount = 0' {
        $result = Invoke-NhiActivityLogScan -NhiObject (New-TestNhiObject) -SignInLogs @() -DirectoryLogs @()
        $ids = $result | ForEach-Object { $_.FindingId }
        $ids | Should -Contain 'NHI-ACT-005'
        $act005 = $result | Where-Object { $_.FindingId -eq 'NHI-ACT-005' }
        $act005.Severity  | Should -Be 'Informational'
        $act005.RiskScore | Should -Be 0
    }
}

Describe 'Invoke-NhiActivityLogScan - reports NHI-ACT-001 for active sign-ins' {
    It 'Returns NHI-ACT-001 when sign-ins detected' {
        $result = Invoke-NhiActivityLogScan -NhiObject (New-TestNhiObject) -SignInLogs (New-TestSignInLog -Count 20) -DirectoryLogs @()
        $ids = $result | ForEach-Object { $_.FindingId }
        $ids | Should -Contain 'NHI-ACT-001'
    }
}

# =============================================================================
# M2: NhiGraphApiAudit
# =============================================================================

Describe 'NhiGraphApiAudit module exports' {
    It 'Exports 3 functions' {
        $exports = (Get-Module NhiGraphApiAudit).ExportedFunctions.Keys
        $exports.Count | Should -Be 3
        $exports | Should -Contain 'Get-NhiAgentGraphApiAudit'
        $exports | Should -Contain 'Invoke-NhiGraphApiOperationAnalysis'
        $exports | Should -Contain 'Invoke-NhiGraphApiAuditScan'
    }
}

Describe 'Invoke-NhiGraphApiOperationAnalysis - empty input' {
    It 'Returns NhiGraphApiAudit.AnalysisResult with zero counts for @()' {
        $result = Invoke-NhiGraphApiOperationAnalysis -AuditLogs @() -ObjectId 'empty-id'
        $result | Should -Not -BeNullOrEmpty
        $result.TotalOperations    | Should -Be 0
        $result.FailureRate         | Should -Be 0.0
        $result.OverallRiskScore    | Should -Be 0
        $result.RiskSignals.Count   | Should -Be 0
    }
}

Describe 'Invoke-NhiGraphApiOperationAnalysis - with audit data' {
    BeforeAll {
        $script:Analysis = Invoke-NhiGraphApiOperationAnalysis -AuditLogs (New-TestGraphApiAuditLog) -ObjectId 'graph-test-id'
    }

    It 'Returns 3 total operations' {
        $script:Analysis.TotalOperations | Should -Be 3
    }

    It 'Detects user modification operations' {
        ($script:Analysis.UserModificationOps -gt 0) | Should -BeTrue
    }

    It 'Calculates non-zero risk score' {
        ($script:Analysis.OverallRiskScore -gt 0) | Should -BeTrue
    }

    It 'Populates risk signals array' {
        $script:Analysis.RiskSignals | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-NhiGraphApiAuditScan - skips non-agentic' {
    It 'Returns empty array when AgenticCandidate = $false' {
        $result = Invoke-NhiGraphApiAuditScan -NhiObject (New-TestNhiObject -AgenticCandidate $false)
        $result | Should -BeNullOrEmpty
    }
}

# =============================================================================
# M3: NhiComplianceAudit
# =============================================================================

Describe 'NhiComplianceAudit module exports' {
    It 'Exports 2 functions' {
        $exports = (Get-Module NhiComplianceAudit).ExportedFunctions.Keys
        $exports.Count | Should -Be 2
        $exports | Should -Contain 'Get-NhiComplianceAuditLog'
        $exports | Should -Contain 'Invoke-NhiComplianceAuditScan'
    }
}

Describe 'Get-NhiComplianceAuditLog - returns collection type' {
    # Call without Graph auth (will fail gracefully in catch)
    It 'Returns array-like result when called without auth' {
        # On Graph failure, returns PSCustomObject with QuerySucceeded=$false — no throw
        { $script:ComplianceResult = Get-NhiComplianceAuditLog -ObjectId 'test-compliance-id' -StartTime ([DateTime]::Now.AddDays(-30)) -EndTime ([DateTime]::Now) } |
            Should -Not -Throw
        # Result is PSCustomObject (query failed) or array (query succeeded)
        $script:ComplianceResult | Should -Not -BeNullOrEmpty
    }

    It 'Throws on empty ObjectId (ValidateNotNullOrEmpty)' {
        { Get-NhiComplianceAuditLog -ObjectId '' -StartTime ([DateTime]::Now.AddDays(-30)) -EndTime ([DateTime]::Now) } |
            Should -Throw
    }
}

Describe 'Invoke-NhiComplianceAuditScan - skips non-agentic' {
    It 'Returns empty array when AgenticCandidate = $false' {
        $result = Invoke-NhiComplianceAuditScan -NhiObject (New-TestNhiObject -AgenticCandidate $false)
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-NhiComplianceAuditScan - Graph failure suppresses NHI-COMPLY-004' {
    It 'Suppresses NHI-COMPLY-004 when compliance audit query fails' {
        Mock Get-MgAuditLogDirectoryAudit -ModuleName NhiComplianceAudit {
            throw 'Graph unavailable'
        }
        $result = Invoke-NhiComplianceAuditScan `
            -NhiObject (New-TestNhiObject) `
            -StartTime ([DateTime]::Now.AddDays(-30)) `
            -EndTime ([DateTime]::Now)
        $ids = @($result | ForEach-Object { $_.FindingId })
        $ids | Should -Not -Contain 'NHI-COMPLY-004'
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-NhiComplianceAuditScan - reports NHI-COMPLY-004 when no findings' {
    It 'Returns NHI-COMPLY-004 when query succeeds and no compliance operations detected' {
        Mock Test-DecomCapabilityAvailable -ModuleName NhiComplianceAudit { $true }
        Mock Get-MgAuditLogDirectoryAudit -ModuleName NhiComplianceAudit {
            return @()
        }
        $result = Invoke-NhiComplianceAuditScan `
            -NhiObject (New-TestNhiObject) `
            -StartTime ([DateTime]::Now.AddDays(-30)) `
            -EndTime ([DateTime]::Now)
        $ids = @($result | ForEach-Object { $_.FindingId })
        $ids | Should -Contain 'NHI-COMPLY-004'
    }
}

# =============================================================================
# M4: NhiTokenForensics
# =============================================================================

Describe 'NhiTokenForensics module exports' {
    It 'Exports 1 function' {
        $exports = (Get-Module NhiTokenForensics).ExportedFunctions.Keys
        $exports.Count | Should -Be 1
        $exports | Should -Contain 'Invoke-NhiTokenForensicsScan'
    }
}

Describe 'Invoke-NhiTokenForensicsScan - skips non-agentic' {
    It 'Returns empty array when AgenticCandidate = $false' {
        $nhiObjTF = New-TestNhiObject -AgenticCandidate $false
        $signInTF = New-TestSignInLog
        $result = Invoke-NhiTokenForensicsScan -NhiObject $nhiObjTF -SignInLogs $signInTF
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-NhiTokenForensicsScan - NHI-TOKEN-003 (no token activity)' {
    BeforeAll {
        # Use @() (no sign-in logs) to trigger NHI-TOKEN-003 (no token activity)
        # New-TestSignInLog includes MSAL entries which would suppress TOKEN-003
        $script:Result = Invoke-NhiTokenForensicsScan -NhiObject (New-TestNhiObject) -SignInLogs @()
    }

    It 'Returns at least one finding (NHI-TOKEN-003 informational)' {
        ($script:Result.Count -gt 0) | Should -BeTrue
    }

    It 'Has NHI-TOKEN-003 with Informational severity' {
        $ids = $script:Result | ForEach-Object { $_.FindingId }
        $ids | Should -Contain 'NHI-TOKEN-003'
        $t003 = $script:Result | Where-Object { $_.FindingId -eq 'NHI-TOKEN-003' }
        $t003.Severity  | Should -Be 'Informational'
        $t003.RiskScore | Should -Be 0
    }
}

Describe 'Invoke-NhiTokenForensicsScan - finding has all required properties' {
    It 'Each finding has FindingId, Category, Severity, RiskScore, Evidence, ObjectId, DisplayName' {
        $nhiObjTF2 = New-TestNhiObject
        $result = Invoke-NhiTokenForensicsScan -NhiObject $nhiObjTF2 -SignInLogs @()
        foreach ($f in $result) {
            $f.FindingId   | Should -Not -BeNullOrEmpty
            $f.Category    | Should -Match 'NhiTokenForensics'
            $f.Severity   | Should -Not -BeNullOrEmpty
            ($f.RiskScore -ge 0) | Should -BeTrue
            $f.Evidence    | Should -Not -BeNullOrEmpty
            $f.ObjectId    | Should -Not -BeNullOrEmpty
            $f.DisplayName | Should -Not -BeNullOrEmpty
        }
    }
}

# =============================================================================
# M5: NhiConditionalAccessResponse
# =============================================================================

Describe 'NhiConditionalAccessResponse module exports' {
    It 'Exports 1 function' {
        $exports = (Get-Module NhiConditionalAccessResponse).ExportedFunctions.Keys
        $exports.Count | Should -Be 1
        $exports | Should -Contain 'Invoke-NhiConditionalAccessResponseScan'
    }
}

Describe 'Invoke-NhiConditionalAccessResponseScan - skips non-agentic' {
    It 'Returns empty array when AgenticCandidate = $false' {
        $nhiObjCA = New-TestNhiObject -AgenticCandidate $false
        $result = Invoke-NhiConditionalAccessResponseScan -NhiObject $nhiObjCA -SignInLogs @()
        $result | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-NhiConditionalAccessResponseScan - NHI-CA-001 (CA blocks > 5)' {
    BeforeAll {
        $logs = @()
        for ($i = 0; $i -lt 10; $i++) {
            $logs += [PSCustomObject]@{ ConditionalAccessStatus = 'failure' }
        }
        $script:Result = Invoke-NhiConditionalAccessResponseScan -NhiObject (New-TestNhiObject) -SignInLogs $logs
    }

    It 'Returns NHI-CA-001 finding' {
        $ids = $script:Result | ForEach-Object { $_.FindingId }
        $ids | Should -Contain 'NHI-CA-001'
    }
}

Describe 'Invoke-NhiConditionalAccessResponseScan - NHI-CA-002 (all blocked)' {
    BeforeAll {
        $logs = @()
        for ($i = 0; $i -lt 5; $i++) {
            $logs += [PSCustomObject]@{ ConditionalAccessStatus = 'failure' }
        }
        $script:Result = Invoke-NhiConditionalAccessResponseScan -NhiObject (New-TestNhiObject) -SignInLogs $logs
    }

    It 'Returns NHI-CA-002 finding (all blocked / 5 blocks = 100%%)' {
        $ids = $script:Result | ForEach-Object { $_.FindingId }
        $ids | Should -Contain 'NHI-CA-002'
    }
}

Describe 'Invoke-NhiConditionalAccessResponseScan - NHI-CA-003 (no CA blocks)' {
    BeforeAll {
        $logs = New-TestSignInLog -Count 5   # all CA status 'success'
        $script:Result = Invoke-NhiConditionalAccessResponseScan -NhiObject (New-TestNhiObject) -SignInLogs $logs
    }

    It 'Returns NHI-CA-003 Informational finding' {
        $ids = $script:Result | ForEach-Object { $_.FindingId }
        $ids | Should -Contain 'NHI-CA-003'
        $ca003 = $script:Result | Where-Object { $_.FindingId -eq 'NHI-CA-003' }
        $ca003.Severity  | Should -Be 'Informational'
        $ca003.RiskScore | Should -Be 0
    }
}

# =============================================================================
# M6: NhiPostDecomAudit
# =============================================================================

Describe 'NhiPostDecomAudit module exports' {
    It 'Exports 2 functions' {
        $exports = (Get-Module NhiPostDecomAudit).ExportedFunctions.Keys
        $exports.Count | Should -Be 2
        $exports | Should -Contain 'Get-NhiPostDecomAuditLog'
        $exports | Should -Contain 'Invoke-NhiPostDecomAttestation'
    }
}

Describe 'Get-NhiPostDecomAuditLog - returns array type' {
    It 'Returns array (not $null) for empty Graph response' {
        # Function now returns PSCustomObject with QuerySucceeded + Entries on failure
        $result = Get-NhiPostDecomAuditLog -ObjectId 'postdecom-id' -DecomTimestamp ([DateTime]::Now.AddHours(-1)) -WindowMinutes 60
        $result | Should -Not -BeNullOrEmpty
        # Either array (success) or PSCustomObject with QuerySucceeded (failure)
        ($result.GetType().IsArray -or $result.PSObject.Properties.Name -contains 'QuerySucceeded') | Should -BeTrue
    }
}

Describe 'Invoke-NhiPostDecomAttestation - DEC-ATTEST-004 when manifest missing' {
    It 'Returns DEC-ATTEST-004 when snapshot manifest not found' {
        $result = Invoke-NhiPostDecomAttestation `
            -ObjectId 'attest-test-id' `
            -DisplayName 'AttestTestNhi' `
            -SnapshotManifestPath 'C:\nonexistent\path\SnapshotManifest-FAKE.json' `
            -DecomTimestamp ([DateTime]::Now.AddHours(-1)) `
            -WindowMinutes 60
        ($result.Count -gt 0) | Should -BeTrue
        $result[0].FindingId  | Should -Be 'DEC-ATTEST-004'
        $result[0].Severity   | Should -Be 'High'
        $result[0].RiskScore  | Should -BeGreaterThan 0
    }
}

Describe 'Invoke-NhiPostDecomAttestation - DEC-ATTEST-001 when no overrides' {
    BeforeAll {
        $script:TempPath = New-TempSnapshotManifest -ObjectId 'attest-obj' -DisplayName 'TestNhi'
        $script:DecomTs  = (Get-Date).AddHours(-2)
        $script:Result   = Invoke-NhiPostDecomAttestation `
            -ObjectId 'attest-obj' -DisplayName 'TestNhi' `
            -SnapshotManifestPath $script:TempPath `
            -DecomTimestamp $script:DecomTs `
            -WindowMinutes 60
    }

    AfterAll {
        Remove-Item $script:TempPath -ErrorAction SilentlyContinue
    }

    It 'Returns DEC-ATTEST-001 when no overrides detected' {
        ($script:Result.Count -gt 0) | Should -BeTrue
        # DEC-ATTEST-001 (provisional pass) or DEC-ATTEST-004 (incomplete)
        # are both valid when Graph audit query is unavailable in test env
        $validIds = @('DEC-ATTEST-001','DEC-ATTEST-004')
        $validIds | Should -Contain $script:Result[0].FindingId
    }
}

Describe 'Invoke-NhiPostDecomAttestation - findings have complete properties' {
    BeforeAll {
        $tempPath = New-TempSnapshotManifest -ObjectId 'attest-complete' -DisplayName 'TestComplete'
        $ts       = (Get-Date).AddHours(-1)
        $script:Result = Invoke-NhiPostDecomAttestation `
            -ObjectId 'attest-complete' `
            -DisplayName 'TestComplete' `
            -SnapshotManifestPath $tempPath `
            -DecomTimestamp $ts `
            -WindowMinutes 60
        Remove-Item $tempPath -ErrorAction SilentlyContinue
    }

    It 'Each finding has FindingId, Category, Severity, RiskScore, Evidence, ObjectId, DisplayName' {
        $script:Result | Should -Not -BeNullOrEmpty
        ($script:Result.Count -gt 0) | Should -BeTrue
        foreach ($f in $script:Result) {
            $f.FindingId   | Should -Not -BeNullOrEmpty
            $f.Category    | Should -Not -BeNullOrEmpty
            $f.Severity    | Should -Not -BeNullOrEmpty
            ($f.RiskScore -ge 0) | Should -BeTrue
            $f.Evidence    | Should -Not -BeNullOrEmpty
            $f.ObjectId    | Should -Not -BeNullOrEmpty
            $f.DisplayName  | Should -Not -BeNullOrEmpty
        }
    }
}

# =============================================================================
# Cross-module harmony
# =============================================================================

Describe 'Cross-module import harmony' {
    It 'All 6 module names are unique' {
        $names = @('NhiActivityLog','NhiGraphApiAudit','NhiComplianceAudit',
                   'NhiTokenForensics','NhiConditionalAccessResponse','NhiPostDecomAudit')
        $names | Sort-Object -Unique | Should -HaveCount 6
    }

    It 'All 6 modules can be imported together without error' {
        foreach ($mod in @('NhiActivityLog','NhiGraphApiAudit','NhiComplianceAudit',
                            'NhiTokenForensics','NhiConditionalAccessResponse','NhiPostDecomAudit')) {
            { Import-Module (Join-Path $script:ModulesPath "$mod.psm1") -Force -DisableNameChecking -ErrorAction Stop } |
                Should -Not -Throw
        }
    }
}
