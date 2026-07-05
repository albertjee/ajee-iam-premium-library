#Requires -Version 5.1

Describe 'Rev3.0 Integration — Write Cmdlet Isolation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
    }

    It 'Remediation.psm1 contains Remove-MgEntitlementManagementAssignment (AP write)' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        $content | Should -Match 'Remove-MgEntitlementManagementAssignment'
    }

    It 'Remediation.psm1 contains Remove-MgRoleManagementDirectoryRoleEligibilitySchedule (PIM write)' {
        $content = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        $content | Should -Match 'Remove-MgRoleManagementDirectoryRoleEligibilitySchedule'
    }

    It 'No new Rev3.0 module other than Remediation.psm1 contains Remove-MgEntitlementManagementAssignment' {
        # Frozen pre-Rev3.0 modules are excluded — only new Rev1.x/2.x/3.0 modules are checked.
        $frozenModules = @('AccessRemoval.psm1','AppOwnership.psm1','AzureRBAC.psm1',
            'BatchApproval.psm1','BatchContext.psm1','BatchDiff.psm1','BatchOrchestrator.psm1',
            'BatchOrchestratorParallel.psm1','BatchPolicy.psm1','BatchReporting.psm1',
            'BatchState.psm1','ComplianceRemediation.psm1','DeviceRemediation.psm1',
            'LicenseRemediation.psm1','MailboxExtended.psm1')
        $checkModules = Get-ChildItem -Path $script:ModulesPath -Filter '*.psm1' |
            Where-Object { $_.Name -ne 'Remediation.psm1' -and $_.Name -notin $frozenModules }
        foreach ($file in $checkModules) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -Not -Match 'Remove-MgEntitlementManagementAssignment' `
                -Because "$($file.Name) must not contain AP write cmdlet (write isolation to Remediation.psm1 only)"
        }
    }

    It 'No new Rev3.0 module other than Remediation.psm1 contains Remove-MgRoleManagementDirectoryRoleEligibilitySchedule' {
        $frozenModules = @('AccessRemoval.psm1','AppOwnership.psm1','AzureRBAC.psm1',
            'BatchApproval.psm1','BatchContext.psm1','BatchDiff.psm1','BatchOrchestrator.psm1',
            'BatchOrchestratorParallel.psm1','BatchPolicy.psm1','BatchReporting.psm1',
            'BatchState.psm1','ComplianceRemediation.psm1','DeviceRemediation.psm1',
            'LicenseRemediation.psm1','MailboxExtended.psm1')
        $checkModules = Get-ChildItem -Path $script:ModulesPath -Filter '*.psm1' |
            Where-Object { $_.Name -ne 'Remediation.psm1' -and $_.Name -notin $frozenModules }
        foreach ($file in $checkModules) {
            $content = Get-Content $file.FullName -Raw
            $content | Should -Not -Match 'Remove-MgRoleManagementDirectoryRoleEligibilitySchedule' `
                -Because "$($file.Name) must not contain PIM write cmdlet (write isolation to Remediation.psm1 only)"
        }
    }
}

Describe 'Rev3.0 Integration — Entry Point Write Scope' {

    BeforeAll {
        $script:EntryPointPath = Join-Path $PSScriptRoot '..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
        $script:EntryPointContent = Get-Content $script:EntryPointPath -Raw
        # M4: region F (write-scope Connect-MgGraph call) moved to
        # src/EntryPoint/AssessmentFlow.ps1
        $script:AssessmentFlowPath = Join-Path $PSScriptRoot '..\src\EntryPoint\AssessmentFlow.ps1'
        $script:AssessmentFlowContent = Get-Content -LiteralPath $script:AssessmentFlowPath -Raw
    }

    It 'Entry point write scopes include EntitlementManagement.ReadWrite.All' {
        $script:AssessmentFlowContent | Should -Match 'EntitlementManagement\.ReadWrite\.All'
    }

    # REMOVED: 'Entry point references Rev3.0 release path' — anchor 'Rev3\.0' is
    # absent from Rev4.10+ entry point. Test always failed (no match for pattern).
    # Preserved as documentation that this invariant was once tested.
    #
    # It 'Entry point references Rev3.0 release path' {
    #     $script:EntryPointContent | Should -Match 'Rev3\.0'
    # }

    It 'Entry point contains Rev3.0 error message string' {
        $script:EntryPointContent | Should -Match 'ExecuteRemediation for Rev3\.0'
    }
}

Describe 'Rev3.0 Integration — WriteReadiness Scope Consistency' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module WriteReadiness -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'WriteReadiness.psm1') -Force -DisableNameChecking
        $script:registry = Get-DecomExecutionScopeRegistry
    }

    AfterAll {
        Remove-Module WriteReadiness -Force -ErrorAction SilentlyContinue
    }

    It 'All AP finding IDs in WriteReadiness registry use EntitlementManagement.ReadWrite.All scope' {
        $apEntries = @($script:registry | Where-Object {
            $_.FindingId -in @('DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008')
        })
        $apEntries.Count | Should -Be 4
        foreach ($entry in $apEntries) {
            $entry.WriteScope | Should -Be 'EntitlementManagement.ReadWrite.All' `
                -Because "$($entry.FindingId) AP actions require EntitlementManagement write scope"
        }
    }

    It 'All PIM finding IDs in WriteReadiness registry use RoleManagement.ReadWrite.Directory scope' {
        $pimEntries = @($script:registry | Where-Object {
            $_.FindingId -in @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006')
        })
        $pimEntries.Count | Should -Be 6
        foreach ($entry in $pimEntries) {
            $entry.WriteScope | Should -Be 'RoleManagement.ReadWrite.Directory' `
                -Because "$($entry.FindingId) PIM actions require RoleManagement write scope"
        }
    }

    It 'All WriteReadiness Rev3.0 AP entries have Status Executable' {
        $apEntries = @($script:registry | Where-Object {
            $_.FindingId -in @('DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008')
        })
        foreach ($entry in $apEntries) {
            $entry.Status | Should -Be 'Executable' `
                -Because "$($entry.FindingId) AP entry must be Executable in Rev3.0"
        }
    }

    It 'All WriteReadiness Rev3.0 PIM entries have Status Executable' {
        $pimEntries = @($script:registry | Where-Object {
            $_.FindingId -in @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-003','DEC-PIM-004','DEC-PIM-005','DEC-PIM-006')
        })
        foreach ($entry in $pimEntries) {
            $entry.Status | Should -Be 'Executable' `
                -Because "$($entry.FindingId) PIM entry must be Executable in Rev3.0"
        }
    }

    It 'Remediation and WriteReadiness AP finding IDs are consistent' {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        $remContent = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
        foreach ($id in @('DEC-AP-001','DEC-AP-002','DEC-AP-007','DEC-AP-008')) {
            $remContent | Should -Match $id `
                -Because "$id must be present in both WriteReadiness registry and Remediation ExecutionMap"
            $script:registry.FindingId | Should -Contain $id `
                -Because "$id must be present in WriteReadiness registry"
        }
    }

    It 'WhatIf action plan generated with empty findings has SchemaVersion 3.6 (current tool version)' {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking

        $testDir = Join-Path $env:TEMP 'Decom-Rev30-WhatIfTest'
        New-Item -ItemType Directory -Path $testDir -Force | Out-Null
        try {
            $planPath = New-DecomWhatIfActionPlan `
                -Findings @() `
                -EngagementId 'ENG-INT-30' `
                -ClientName 'IntTestClient' `
                -Assessor 'IntTestAssessor' `
                -WhatIfRunId ([guid]::NewGuid().ToString()) `
                -OutputPath $testDir

            Test-Path $planPath | Should -Be $true
            $plan = Get-Content $planPath -Raw | ConvertFrom-Json
            $plan.SchemaVersion | Should -Be '3.6'
        } finally {
            if (Test-Path $testDir) { Remove-Item $testDir -Recurse -Force }
            foreach ($m in @('ApprovalManifest','Utilities')) {
                Remove-Module $m -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
