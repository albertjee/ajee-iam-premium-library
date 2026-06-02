#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Traceability' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module Traceability -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'Traceability.psm1') -Force -DisableNameChecking
    }

    It 'FindingOnly trace status generated when finding has no WhatIf action' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-001'
            FindingInstanceId = 'fi-001'
            Severity          = 'High'
            RiskScore         = '80'
            ObjectId          = 'user-001'
            DisplayName       = 'Alice Smith'
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @() -ApprovalActions @() -ExecutionResults @() -RunId 'run-t01'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-001' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'FindingOnly'
        $model.Summary.FindingOnly | Should -Be 1
    }

    It 'WhatIfGenerated trace status generated when finding has WhatIf but no approval' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-002'
            FindingInstanceId = 'fi-002'
            Severity          = 'Medium'
            RiskScore         = '60'
            ObjectId          = 'user-002'
            DisplayName       = 'Bob Jones'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-002'
            FindingId   = 'f-002'
            ActionType  = 'RemoveGroupMember'
            WhatIfRunId = 'wi-run-002'
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @() -ExecutionResults @() -RunId 'run-t02'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-002' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'WhatIfGenerated'
        $model.Summary.WhatIfGenerated | Should -Be 1
    }

    It 'Approved trace status generated when finding has WhatIf and Approved approval but no execution' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-003'
            FindingInstanceId = 'fi-003'
            Severity          = 'High'
            RiskScore         = '75'
            ObjectId          = 'user-003'
            DisplayName       = 'Carol White'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-003'
            FindingId   = 'f-003'
            ActionType  = 'RevokeAccessPackage'
            WhatIfRunId = 'wi-run-003'
        }
        $aa = [pscustomobject]@{
            ActionId              = 'act-003'
            ApprovalStatus        = 'Approved'
            ApprovedBy            = 'manager@contoso.com'
            ApprovalTicket        = 'CHG-1001'
            ApprovalManifestHash  = 'manifesthash-003'
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @($aa) -ExecutionResults @() -RunId 'run-t03'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-003' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'TraceGap'
        $model.Summary.TraceGap | Should -Be 1
    }

    It 'Executed trace status generated when execution outcome is Executed with EvidenceFile' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-004'
            FindingInstanceId = 'fi-004'
            Severity          = 'Critical'
            RiskScore         = '95'
            ObjectId          = 'user-004'
            DisplayName       = 'Dan Green'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-004'
            FindingId   = 'f-004'
            ActionType  = 'DisableAccount'
            WhatIfRunId = 'wi-run-004'
        }
        $aa = [pscustomobject]@{
            ActionId             = 'act-004'
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'approver@contoso.com'
            ApprovalTicket       = 'CHG-1002'
            ApprovalManifestHash = 'manifesthash-004'
        }
        $ex = [pscustomobject]@{
            ActionId              = 'act-004'
            ExecutionOutcome      = 'Executed'
            ExecutedUtc           = '2026-06-02T10:00:00Z'
            GraphWriteCmdlet      = 'Update-MgUser'
            PostWriteRequeryStatus = 'Confirmed'
            EvidenceFile          = 'evidence-004.json'
            RollbackGuidance      = 'Re-enable account via Entra admin portal.'
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @($aa) -ExecutionResults @($ex) -RunId 'run-t04'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-004' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'Executed'
        $model.Summary.Executed | Should -Be 1
    }

    It 'Skipped trace status generated when execution outcome is Skipped' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-005'
            FindingInstanceId = 'fi-005'
            Severity          = 'Low'
            RiskScore         = '25'
            ObjectId          = 'user-005'
            DisplayName       = 'Eve Brown'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-005'
            FindingId   = 'f-005'
            ActionType  = 'RemoveLicense'
            WhatIfRunId = 'wi-run-005'
        }
        $aa = [pscustomobject]@{
            ActionId             = 'act-005'
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'approver@contoso.com'
            ApprovalTicket       = 'CHG-1003'
            ApprovalManifestHash = 'manifesthash-005'
        }
        $ex = [pscustomobject]@{
            ActionId              = 'act-005'
            ExecutionOutcome      = 'Skipped'
            ExecutedUtc           = '2026-06-02T10:05:00Z'
            GraphWriteCmdlet      = ''
            PostWriteRequeryStatus = ''
            EvidenceFile          = ''
            RollbackGuidance      = ''
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @($aa) -ExecutionResults @($ex) -RunId 'run-t05'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-005' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'Skipped'
        $model.Summary.Skipped | Should -Be 1
    }

    It 'Blocked trace status generated when execution outcome is Blocked' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-006'
            FindingInstanceId = 'fi-006'
            Severity          = 'High'
            RiskScore         = '85'
            ObjectId          = 'user-006'
            DisplayName       = 'Frank Black'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-006'
            FindingId   = 'f-006'
            ActionType  = 'RemoveRoleAssignment'
            WhatIfRunId = 'wi-run-006'
        }
        $aa = [pscustomobject]@{
            ActionId             = 'act-006'
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'approver@contoso.com'
            ApprovalTicket       = 'CHG-1004'
            ApprovalManifestHash = 'manifesthash-006'
        }
        $ex = [pscustomobject]@{
            ActionId              = 'act-006'
            ExecutionOutcome      = 'Blocked'
            ExecutedUtc           = '2026-06-02T10:10:00Z'
            GraphWriteCmdlet      = ''
            PostWriteRequeryStatus = ''
            EvidenceFile          = ''
            RollbackGuidance      = ''
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @($aa) -ExecutionResults @($ex) -RunId 'run-t06'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-006' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'Blocked'
        $model.Summary.Blocked | Should -Be 1
    }

    It 'EvidenceMissing trace gap generated when execution outcome is Executed but EvidenceFile is empty' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-007'
            FindingInstanceId = 'fi-007'
            Severity          = 'Critical'
            RiskScore         = '90'
            ObjectId          = 'user-007'
            DisplayName       = 'Grace Lee'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-007'
            FindingId   = 'f-007'
            ActionType  = 'DisableAccount'
            WhatIfRunId = 'wi-run-007'
        }
        $aa = [pscustomobject]@{
            ActionId             = 'act-007'
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'approver@contoso.com'
            ApprovalTicket       = 'CHG-1005'
            ApprovalManifestHash = 'manifesthash-007'
        }
        $ex = [pscustomobject]@{
            ActionId              = 'act-007'
            ExecutionOutcome      = 'Executed'
            ExecutedUtc           = '2026-06-02T10:15:00Z'
            GraphWriteCmdlet      = 'Update-MgUser'
            PostWriteRequeryStatus = 'Confirmed'
            EvidenceFile          = ''
            RollbackGuidance      = ''
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @($aa) -ExecutionResults @($ex) -RunId 'run-t07'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-007' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'EvidenceMissing'
        $model.Summary.EvidenceMissing | Should -Be 1
    }

    It 'Traceability CSV exported and importable' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-csv'
            FindingInstanceId = 'fi-csv'
            Severity          = 'Medium'
            RiskScore         = '55'
            ObjectId          = 'user-csv'
            DisplayName       = 'CSV Test User'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-csv'
            FindingId   = 'f-csv'
            ActionType  = 'RemoveGroupMember'
            WhatIfRunId = 'wi-run-csv'
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @() -ExecutionResults @() -RunId 'run-csv'

        $tempPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.csv'
        try {
            Export-DecomTraceabilityReportCsv -Model $model -Path $tempPath
            Test-Path $tempPath | Should -Be $true
            $imported = Import-Csv -Path $tempPath
            $imported | Should -Not -BeNullOrEmpty
            $imported[0].FindingId | Should -Be 'f-csv'
        } finally {
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }
    }

    It 'Traceability HTML exported and contains HTML structure' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-html'
            FindingInstanceId = 'fi-html'
            Severity          = 'High'
            RiskScore         = '78'
            ObjectId          = 'user-html'
            DisplayName       = 'HTML Test User'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-html'
            FindingId   = 'f-html'
            ActionType  = 'RemoveLicense'
            WhatIfRunId = 'wi-run-html'
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @() -ExecutionResults @() -RunId 'run-html'

        $tempPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.html'
        try {
            Export-DecomTraceabilityReportHtml -Model $model -Path $tempPath
            Test-Path $tempPath | Should -Be $true
            $content = [System.IO.File]::ReadAllText($tempPath)
            $content | Should -Match '<!DOCTYPE html>'
            $content | Should -Match '<table'
        } finally {
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }
    }

    It 'Traceability links Finding to WhatIf by FindingId' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-link-001'
            FindingInstanceId = 'fi-link-001'
            Severity          = 'Medium'
            RiskScore         = '50'
            ObjectId          = 'user-link-001'
            DisplayName       = 'Link Test User'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-link-001'
            FindingId   = 'f-link-001'
            ActionType  = 'RemoveGroupMember'
            WhatIfRunId = 'wi-run-link-001'
        }
        $wa2 = [pscustomobject]@{
            ActionId    = 'act-link-002'
            FindingId   = 'f-link-001'  # Same FindingId - should link to same finding
            ActionType  = 'RevokeAppRoleAssignment'
            WhatIfRunId = 'wi-run-link-002'
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa, $wa2) -ApprovalActions @() -ExecutionResults @() -RunId 'run-link'

        # Should have 2 rows (one for each WhatIf action)
        ($model.Rows.Count) | Should -Be 2

        # Both rows should have the same FindingId
        foreach ($row in $model.Rows) {
            $row.FindingId | Should -Be 'f-link-001'
        }

        # Should have 2 WhatIfGenerated trace status
        $model.Summary.WhatIfGenerated | Should -Be 2
    }

    It 'Executed action without evidence becomes EvidenceMissing' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-evidence-001'
            FindingInstanceId = 'fi-evidence-001'
            Severity          = 'High'
            RiskScore         = '85'
            ObjectId          = 'user-evidence-001'
            DisplayName       = 'Evidence Test User'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-evidence-001'
            FindingId   = 'f-evidence-001'
            ActionType  = 'DisableAccount'
            WhatIfRunId = 'wi-run-evidence-001'
        }
        $aa = [pscustomobject]@{
            ActionId             = 'act-evidence-001'
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'approver@contoso.com'
            ApprovalTicket       = 'CHG-EV-001'
            ApprovalManifestHash = 'manifesthash-ev-001'
        }
        $ex = [pscustomobject]@{
            ActionId              = 'act-evidence-001'
            ExecutionOutcome      = 'Executed'
            ExecutedUtc           = '2026-06-02T11:00:00Z'
            GraphWriteCmdlet      = 'Update-MgUser'
            PostWriteRequeryStatus = 'Confirmed'
            EvidenceFile          = ''  # Empty evidence file
            RollbackGuidance      = ''
        }

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @($aa) -ExecutionResults @($ex) -RunId 'run-evidence'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-evidence-001' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'EvidenceMissing'
        $row.EvidenceFile | Should -Be ''
        $model.Summary.EvidenceMissing | Should -Be 1
    }

    It 'Approved action with no execution becomes TraceGap' {
        $finding = [pscustomobject]@{
            FindingId         = 'f-tracegap-001'
            FindingInstanceId = 'fi-tracegap-001'
            Severity          = 'Medium'
            RiskScore         = '60'
            ObjectId          = 'user-tracegap-001'
            DisplayName       = 'TraceGap Test User'
        }
        $wa = [pscustomobject]@{
            ActionId    = 'act-tracegap-001'
            FindingId   = 'f-tracegap-001'
            ActionType  = 'RemoveLicense'
            WhatIfRunId = 'wi-run-tracegap-001'
        }
        $aa = [pscustomobject]@{
            ActionId             = 'act-tracegap-001'
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'approver@contoso.com'
            ApprovalTicket       = 'CHG-TG-001'
            ApprovalManifestHash = 'manifesthash-tg-001'
        }
        # Note: No execution record provided

        $model = New-DecomTraceabilityModel -Findings @($finding) -WhatIfActions @($wa) -ApprovalActions @($aa) -ExecutionResults @() -RunId 'run-tracegap'

        $row = $model.Rows | Where-Object { $_.FindingId -eq 'f-tracegap-001' }
        $row | Should -Not -BeNullOrEmpty
        $row.TraceStatus | Should -Be 'TraceGap'
        $row.TraceGapReason | Should -Be 'Approval record present but execution outcome is NotExecuted.'
        $model.Summary.TraceGap | Should -Be 1
    }
}
