#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'ReplayValidation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        Remove-Module ReplayValidation -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'ReplayValidation.psm1') -Force -DisableNameChecking

        # ── Shared helper: build a minimal WhatIfReport ──────────────────────────
        function script:New-WhatIfReport {
            param([string]$RunId = 'run-001')
            return [pscustomobject]@{
                RunId        = $RunId
                GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
                Mode         = 'WhatIfRemediation'
            }
        }

        # ── Shared helper: build a minimal ApprovalManifest ──────────────────────
        function script:New-ApprovalManifest {
            param(
                [string]$WhatIfRunId         = 'run-001',
                [string]$ApprovalEnvelopeHash = 'abc123',
                [string]$ApprovedActionsHash  = 'hash-aaa',
                [object[]]$ApprovedActions    = @()
            )
            return [pscustomobject]@{
                WhatIfRunId          = $WhatIfRunId
                ApprovalEnvelopeHash = $ApprovalEnvelopeHash
                ApprovedActionsHash  = $ApprovedActionsHash
                ApprovalStatus       = 'Approved'
                ApprovedActions      = $ApprovedActions
            }
        }

        # ── Shared helper: build a minimal ExecutionEvidence ─────────────────────
        function script:New-ExecutionEvidence {
            param(
                [string]$ApprovalEnvelopeHash = 'abc123',
                [string]$ApprovedActionsHash  = 'hash-aaa',
                [object[]]$Actions            = @()
            )
            return [pscustomobject]@{
                ApprovalEnvelopeHash = $ApprovalEnvelopeHash
                ApprovedActionsHash  = $ApprovedActionsHash
                Actions              = $Actions
            }
        }

        # ── Shared helper: build an approved action entry ─────────────────────────
        function script:New-ApprovedAction {
            param(
                [string]$ActionId      = 'action-1',
                [string]$FindingId     = 'DEC-AP-001',
                [string]$ObjectId      = 'user-obj-001',
                [string[]]$TargetObjectIds = @('obj-A'),
                [bool]$ProtectedObject = $false
            )
            return [pscustomobject]@{
                ActionId        = $ActionId
                FindingId       = $FindingId
                ObjectId        = $ObjectId
                ActionType      = 'RemoveAccessPackageAssignment'
                TargetObjectIds = $TargetObjectIds
                ProtectedObject = $ProtectedObject
            }
        }

        # ── Shared helper: build an execution evidence action entry ───────────────
        function script:New-EvidenceAction {
            param(
                [string]$ActionId         = 'action-1',
                [string]$Outcome          = 'Executed',
                [string[]]$TargetObjectIds = @('obj-A'),
                [string]$ErrorDetail      = '',
                [string]$AfterState       = 'removed',
                [bool]$HasTenantWrite     = $false,
                [bool]$ProtectedObject    = $false
            )
            return [pscustomobject]@{
                ActionId        = $ActionId
                Outcome         = $Outcome
                TargetObjectIds = $TargetObjectIds
                ErrorDetail     = $ErrorDetail
                AfterState      = $AfterState
                HasTenantWrite  = $HasTenantWrite
                ProtectedObject = $ProtectedObject
            }
        }
    }

    AfterAll {
        Remove-Module ReplayValidation -Force -ErrorAction SilentlyContinue
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 1 — WhatIfRunId binding validated
    # ────────────────────────────────────────────────────────────────────────────
    It 'WhatIfRunId binding passes when RunIds match' {
        $whatIf   = script:New-WhatIfReport -RunId 'run-001'
        $approval = script:New-ApprovalManifest -WhatIfRunId 'run-001'

        $result = Test-DecomWhatIfApprovalBinding `
            -WhatIfReport     $whatIf `
            -ApprovalManifest $approval

        $result.Passed    | Should -Be $true
        $result.CheckName | Should -Be 'WhatIfApprovalBinding'
    }

    It 'WhatIfRunId binding fails when RunIds differ' {
        $whatIf   = script:New-WhatIfReport -RunId 'run-001'
        $approval = script:New-ApprovalManifest -WhatIfRunId 'run-999'

        $result = Test-DecomWhatIfApprovalBinding `
            -WhatIfReport     $whatIf `
            -ApprovalManifest $approval

        $result.Passed   | Should -Be $false
        $result.Severity | Should -Be 'Error'
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 2 — Approval hash binding validated
    # ────────────────────────────────────────────────────────────────────────────
    It 'ApprovalEnvelopeHash binding passes when hashes match' {
        $approval  = script:New-ApprovalManifest  -ApprovalEnvelopeHash 'abc123'
        $evidence  = script:New-ExecutionEvidence -ApprovalEnvelopeHash 'abc123'

        $result = Test-DecomApprovalExecutionBinding `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence

        $result.Passed    | Should -Be $true
        $result.CheckName | Should -Be 'ApprovalExecutionBinding'
    }

    It 'ApprovalEnvelopeHash binding fails when hashes differ' {
        $approval = script:New-ApprovalManifest  -ApprovalEnvelopeHash 'abc123'
        $evidence = script:New-ExecutionEvidence -ApprovalEnvelopeHash 'xyz999'

        $result = Test-DecomApprovalExecutionBinding `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence

        $result.Passed   | Should -Be $false
        $result.Severity | Should -Be 'Error'
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 3 — Execution action exists in approval
    # ────────────────────────────────────────────────────────────────────────────
    It 'AllExecutedActionsApproved passes when ActionId is in approval manifest' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        $evidenceAction = script:New-EvidenceAction -ActionId 'action-1' -TargetObjectIds @('obj-A')

        $approval = script:New-ApprovalManifest `
            -ApprovedActions @($approvedAction) `
            -ApprovedActionsHash 'hash-aaa'
        $evidence = script:New-ExecutionEvidence `
            -Actions @($evidenceAction) `
            -ApprovedActionsHash 'hash-aaa'

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $approvedCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'AllExecutedActionsApproved' }
        $approvedCheck | Should -Not -BeNullOrEmpty
        $approvedCheck.Passed | Should -Be $true
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 4 — Unapproved execution action fails validation
    # ────────────────────────────────────────────────────────────────────────────
    It 'Validation fails when evidence contains ActionId not in approval manifest' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1'
        $evidenceAction = script:New-EvidenceAction -ActionId 'action-999'

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $validationResult.Passed | Should -Be $false
        $unapprovedCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'AllExecutedActionsApproved' }
        $unapprovedCheck.Passed | Should -Be $false
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 5 — TargetObjectIds must match approval
    # ────────────────────────────────────────────────────────────────────────────
    It 'Validation fails when evidence TargetObjectId was not approved' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        $evidenceAction = script:New-EvidenceAction -ActionId 'action-1' -TargetObjectIds @('obj-B')

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $validationResult.Passed | Should -Be $false
        $targetCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'AllTargetObjectIdsApproved' }
        $targetCheck.Passed | Should -Be $false
    }

    It 'AllTargetObjectIdsApproved passes when TargetObjectId matches approval' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        $evidenceAction = script:New-EvidenceAction -ActionId 'action-1' -TargetObjectIds @('obj-A')

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $targetCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'AllTargetObjectIdsApproved' }
        $targetCheck.Passed | Should -Be $true
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 6 — Executed action requires post-write evidence
    # ────────────────────────────────────────────────────────────────────────────
    It 'ExecutedActionsHavePostWriteEvidence fails when Executed action has no AfterState or PostWriteEvidence' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        # Build an evidence action with Outcome=Executed but no post-write reference
        $evidenceAction = [pscustomobject]@{
            ActionId        = 'action-1'
            Outcome         = 'Executed'
            TargetObjectIds = @('obj-A')
            ErrorDetail     = ''
            HasTenantWrite  = $false
            ProtectedObject = $false
            # Intentionally omit AfterState, TargetsAfter, PostWriteEvidence
        }

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $postWriteCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'ExecutedActionsHavePostWriteEvidence' }
        $postWriteCheck.Passed | Should -Be $false
    }

    It 'ExecutedActionsHavePostWriteEvidence passes when AfterState is populated' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        $evidenceAction = script:New-EvidenceAction `
            -ActionId        'action-1' `
            -Outcome         'Executed' `
            -TargetObjectIds @('obj-A') `
            -AfterState      'removed'

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $postWriteCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'ExecutedActionsHavePostWriteEvidence' }
        $postWriteCheck.Passed | Should -Be $true
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 7 — Blocked action requires ErrorDetail
    # ────────────────────────────────────────────────────────────────────────────
    It 'FailedBlockedActionsHaveErrorDetail fails when Blocked action has no ErrorDetail' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        $evidenceAction = script:New-EvidenceAction `
            -ActionId    'action-1' `
            -Outcome     'Blocked' `
            -ErrorDetail ''

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $errorCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'FailedBlockedActionsHaveErrorDetail' }
        $errorCheck.Passed | Should -Be $false
    }

    It 'FailedBlockedActionsHaveErrorDetail passes when Blocked action has ErrorDetail' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        $evidenceAction = script:New-EvidenceAction `
            -ActionId    'action-1' `
            -Outcome     'Blocked' `
            -ErrorDetail 'ProtectedObject — blocked by policy'

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $errorCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'FailedBlockedActionsHaveErrorDetail' }
        $errorCheck.Passed | Should -Be $true
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 8 — Skipped action does not claim write
    # ────────────────────────────────────────────────────────────────────────────
    It 'SkippedActionsNoTenantWrite fails when Skipped action has HasTenantWrite=true' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        $evidenceAction = script:New-EvidenceAction `
            -ActionId       'action-1' `
            -Outcome        'Skipped' `
            -HasTenantWrite $true

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $skipCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'SkippedActionsNoTenantWrite' }
        $skipCheck.Passed | Should -Be $false
    }

    It 'SkippedActionsNoTenantWrite passes when Skipped action has HasTenantWrite=false' {
        $approvedAction = script:New-ApprovedAction -ActionId 'action-1' -TargetObjectIds @('obj-A')
        $evidenceAction = script:New-EvidenceAction `
            -ActionId       'action-1' `
            -Outcome        'Skipped' `
            -HasTenantWrite $false

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $skipCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'SkippedActionsNoTenantWrite' }
        $skipCheck.Passed | Should -Be $true
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Test 9 — ProtectedObject actions are Blocked, not Executed
    # ────────────────────────────────────────────────────────────────────────────
    It 'ProtectedObjectsNotExecuted fails when ProtectedObject action has Outcome=Executed' {
        $approvedAction = script:New-ApprovedAction `
            -ActionId        'action-1' `
            -TargetObjectIds @('obj-A') `
            -ProtectedObject $false

        $evidenceAction = [pscustomobject]@{
            ActionId        = 'action-1'
            Outcome         = 'Executed'
            TargetObjectIds = @('obj-A')
            ErrorDetail     = ''
            HasTenantWrite  = $true
            ProtectedObject = $true
            AfterState      = 'done'
        }

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $protCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'ProtectedObjectsNotExecuted' }
        $protCheck.Passed | Should -Be $false
    }

    It 'ProtectedObjectsNotExecuted passes when ProtectedObject action has Outcome=Blocked' {
        $approvedAction = script:New-ApprovedAction `
            -ActionId        'action-1' `
            -TargetObjectIds @('obj-A') `
            -ProtectedObject $false

        $evidenceAction = [pscustomobject]@{
            ActionId        = 'action-1'
            Outcome         = 'Blocked'
            TargetObjectIds = @('obj-A')
            ErrorDetail     = 'ProtectedObject — blocked'
            HasTenantWrite  = $false
            ProtectedObject = $true
        }

        $approval = script:New-ApprovalManifest -ApprovedActions @($approvedAction)
        $evidence = script:New-ExecutionEvidence -Actions @($evidenceAction)

        $validationResult = Invoke-DecomReplayValidation `
            -ApprovalManifest  $approval `
            -ExecutionEvidence $evidence `
            -RunId             'run-001'

        $protCheck = $validationResult.Findings | Where-Object { $_.CheckName -eq 'ProtectedObjectsNotExecuted' }
        $protCheck.Passed | Should -Be $true
    }

    # ────────────────────────────────────────────────────────────────────────────
    # Structural / output shape tests
    # ────────────────────────────────────────────────────────────────────────────
    It 'Invoke-DecomReplayValidation returns SchemaVersion 3.6' {
        $result = Invoke-DecomReplayValidation -RunId 'run-schema-check'
        $result.SchemaVersion | Should -Be '3.6'
    }

    It 'Invoke-DecomReplayValidation returns ToolVersion Rev3.6' {
        $result = Invoke-DecomReplayValidation -RunId 'run-tool-check'
        $result.ToolVersion | Should -Be 'Rev3.6'
    }

    It 'Replay validation with no artifacts returns Passed=false' {
        $result = Invoke-DecomReplayValidation -RunId 'run-empty'
        $result.CheckCount | Should -Be 0
        $result.Passed     | Should -Be $false
        $result.Warnings.Count | Should -Be 3
    }

    It 'Invoke-DecomReplayValidation returns a Findings array' {
        $result = Invoke-DecomReplayValidation -RunId 'run-findings-test'
        $result.PSObject.Properties['Findings'] | Should -Not -BeNullOrEmpty
    }

    It 'Export-DecomReplayValidationReportJson writes a readable JSON file' {
        $tempDir = Join-Path $env:TEMP 'ReplayValidation-Rev34-Test'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $validationResult = Invoke-DecomReplayValidation -RunId 'run-export-test'
            $jsonPath = Export-DecomReplayValidationReportJson `
                -ValidationResult $validationResult `
                -OutputPath       $tempDir

            Test-Path $jsonPath | Should -Be $true
            $content = Get-Content $jsonPath -Raw | ConvertFrom-Json
            $content.SchemaVersion | Should -Be '3.6'
            $content.RunId         | Should -Be 'run-export-test'
        } finally {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'Export-DecomReplayValidationReportMarkdown writes a Markdown file' {
        $tempDir = Join-Path $env:TEMP 'ReplayValidation-Rev34-Md'
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        try {
            $validationResult = Invoke-DecomReplayValidation -RunId 'run-md-test'
            $mdPath = Export-DecomReplayValidationReportMarkdown `
                -ValidationResult $validationResult `
                -OutputPath       $tempDir

            Test-Path $mdPath | Should -Be $true
            $content = Get-Content $mdPath -Raw
            $content | Should -Match 'Replay Validation Report'
            $content | Should -Match 'run-md-test'
        } finally {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
