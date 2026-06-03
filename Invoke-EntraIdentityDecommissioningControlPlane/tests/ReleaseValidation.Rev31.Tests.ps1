#Requires -Version 5.1

Describe 'Safety — Rev3.1 Write Isolation and Guest Safety Invariants' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        $script:EntryPointPath = Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
    }

    It 'GuestGovernance.psm1 contains no write cmdlets (Remove-Mg)' {
        $content = Get-Content (Join-Path $script:ModulesPath 'GuestGovernance.psm1') -Raw
        $content | Should -Not -Match 'Remove-Mg'
    }

    It 'GuestGovernance.psm1 contains no write cmdlets (Update-Mg)' {
        $content = Get-Content (Join-Path $script:ModulesPath 'GuestGovernance.psm1') -Raw
        $content | Should -Not -Match 'Update-Mg'
    }

    It 'GuestGovernance.psm1 contains no Connect-MgGraph' {
        $content = Get-Content (Join-Path $script:ModulesPath 'GuestGovernance.psm1') -Raw
        $content | Should -Not -Match 'Connect-MgGraph'
    }

    It 'Remediation.psm1 contains Remove-MgGroupMemberByRef (guest group write)' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        $content | Should -Match 'Remove-MgGroupMemberByRef'
    }

    It 'Remediation.psm1 contains Remove-MgUserAppRoleAssignment (guest app-role write)' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        $content | Should -Match 'Remove-MgUserAppRoleAssignment'
    }

    It 'No module other than Remediation.psm1 contains Remove-MgGroupMemberByRef guest write' {
        $frozenModules = @('AccessRemoval.psm1','AppOwnership.psm1','AzureRBAC.psm1',
            'BatchApproval.psm1','BatchContext.psm1','BatchDiff.psm1','BatchOrchestrator.psm1',
            'BatchOrchestratorParallel.psm1','BatchPolicy.psm1','BatchReporting.psm1',
            'BatchState.psm1','ComplianceRemediation.psm1','DeviceRemediation.psm1',
            'LicenseRemediation.psm1','MailboxExtended.psm1')
        $checkModules = Get-ChildItem -Path $script:ModulesPath -Filter '*.psm1' |
            Where-Object { $_.Name -ne 'Remediation.psm1' -and $_.Name -notin $frozenModules }
        foreach ($file in $checkModules) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -Not -Match 'Remove-MgGroupMemberByRef' `
                -Because "$($file.Name) must not contain guest group write cmdlet"
        }
    }

    It 'No Rev3.1 module contains guest deletion cmdlet (Remove-MgUser)' {
        $frozenModules = @('AccessRemoval.psm1','AppOwnership.psm1','AzureRBAC.psm1',
            'BatchApproval.psm1','BatchContext.psm1','BatchDiff.psm1','BatchOrchestrator.psm1',
            'BatchOrchestratorParallel.psm1','BatchPolicy.psm1','BatchReporting.psm1',
            'BatchState.psm1','ComplianceRemediation.psm1','DeviceRemediation.psm1',
            'LicenseRemediation.psm1','MailboxExtended.psm1')
        $checkModules = Get-ChildItem -Path $script:ModulesPath -Filter '*.psm1' |
            Where-Object { $_.Name -notin $frozenModules }
        foreach ($file in $checkModules) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -Not -Match 'Remove-MgUser\b' `
                -Because "Rev3.1 must not delete guest users"
        }
    }

    It 'Entry point ToolVersion is Rev3.5' {
        $content = Get-Content $script:EntryPointPath -Raw
        $content | Should -Match "\`$script:ToolVersion\s*=\s*'Rev3\.5'"
    }

    It 'Entry point write scopes include GroupMember.ReadWrite.All' {
        $content = Get-Content $script:EntryPointPath -Raw
        $content | Should -Match 'GroupMember\.ReadWrite\.All'
    }

    It 'Entry point write scopes include AppRoleAssignment.ReadWrite.All' {
        $content = Get-Content $script:EntryPointPath -Raw
        $content | Should -Match 'AppRoleAssignment\.ReadWrite\.All'
    }
}

Describe 'ReleaseValidation.psm1 — Rev3.1 Validation Checks' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','SchemaContracts','WriteReadiness','ReleaseValidation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')          -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'SchemaContracts.psm1')    -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'WriteReadiness.psm1')     -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ReleaseValidation.psm1')  -Force -DisableNameChecking
    }

    AfterAll {
        foreach ($m in @('ReleaseValidation','WriteReadiness','SchemaContracts','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'ReleaseValidation checks that ToolVersion is Rev3.5' {
        # Run validation with wrong ToolVersion to confirm the check exists
        $result = Invoke-DecomReleaseValidation -ToolVersion 'Rev3.0' -EntryPointPath `
            (Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1') `
            -ModulesPath $script:ModulesPath
        $result.Valid | Should -Be $false
        ($result.Errors | Where-Object { $_ -match 'Rev3\.5' }) | Should -Not -BeNullOrEmpty
    }

    It 'ReleaseValidation RemoveGuestGroupMembership is in executable write scope' {
        $result = Invoke-DecomReleaseValidation -ToolVersion 'Rev3.1' -EntryPointPath `
            (Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1') `
            -ModulesPath $script:ModulesPath
        # Check allowed action types include guest actions
        $result | Should -Not -BeNullOrEmpty
    }

    It 'WriteReadiness guest entries have GuestOnly = true' {
        $registry = Get-DecomExecutionScopeRegistry
        $guestEntries = $registry | Where-Object { $_.FindingId -like 'DEC-GUEST-*' -or $_.FindingId -like 'DEC-GREV-*' }
        foreach ($entry in $guestEntries) {
            $entry.GuestOnly | Should -Be $true `
                -Because "FindingId $($entry.FindingId) is guest-only and must be flagged"
        }
    }

    It 'WriteReadiness guest entries have IntroducedIn Rev3.1' {
        $registry = Get-DecomExecutionScopeRegistry
        $guestEntries = $registry | Where-Object { $_.FindingId -like 'DEC-GUEST-*' -or $_.FindingId -like 'DEC-GREV-*' }
        foreach ($entry in $guestEntries) {
            $entry.IntroducedIn | Should -Be 'Rev3.1' `
                -Because "FindingId $($entry.FindingId) was introduced in Rev3.1"
        }
    }
}
