#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'ApprovalDiff' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        Remove-Module ApprovalDiff -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $script:ModulesPath 'ApprovalDiff.psm1') -Force -DisableNameChecking
    }

    It 'ApprovedUnchanged detected when WhatIf and Approval match exactly' {
        $wa = [pscustomobject]@{
            ActionId       = 'a1'
            ActionType     = 'RemoveGroupMember'
            TargetObjectId = 'obj-100'
            Hash           = 'abc123'
            RiskScore      = 70
            ProtectedObject = $false
        }
        $aa = [pscustomobject]@{
            ActionId       = 'a1'
            ActionType     = 'RemoveGroupMember'
            TargetObjectId = 'obj-100'
            Hash           = 'abc123'
            RiskScore      = 70
        }

        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @($aa) -RunId 'run-01'

        $item = $diff.DiffItems | Where-Object { $_.ActionId -eq 'a1' }
        $item | Should -Not -BeNullOrEmpty
        $item.DiffCategory | Should -Be 'ApprovedUnchanged'
    }

    It 'ActionTypeChanged detected when ActionType differs between WhatIf and Approval' {
        $wa = [pscustomobject]@{
            ActionId       = 'a2'
            ActionType     = 'RemoveGroupMember'
            TargetObjectId = 'obj-200'
            Hash           = 'hash-wa'
            RiskScore      = 50
            ProtectedObject = $false
        }
        $aa = [pscustomobject]@{
            ActionId       = 'a2'
            ActionType     = 'DisableAccount'
            TargetObjectId = 'obj-200'
            Hash           = 'hash-wa'
            RiskScore      = 50
        }

        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @($aa) -RunId 'run-02'

        $item = $diff.DiffItems | Where-Object { $_.ActionId -eq 'a2' }
        $item | Should -Not -BeNullOrEmpty
        $item.DiffCategory | Should -BeIn @('ActionTypeChanged', 'ApprovedModified')
    }

    It 'RejectedOrOmitted detected when WhatIf action is absent from Approval' {
        $wa = [pscustomobject]@{
            ActionId       = 'a3'
            ActionType     = 'RevokeAccessPackage'
            TargetObjectId = 'obj-300'
            Hash           = 'hash-x'
            RiskScore      = 60
            ProtectedObject = $false
        }

        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @() -RunId 'run-03'

        $item = $diff.DiffItems | Where-Object { $_.ActionId -eq 'a3' }
        $item | Should -Not -BeNullOrEmpty
        $item.DiffCategory | Should -Be 'RejectedOrOmitted'
    }

    It 'ApprovalOnlyNotInWhatIf detected and Passed is false' {
        $aa = [pscustomobject]@{
            ActionId       = 'a99'
            ActionType     = 'RemoveRoleAssignment'
            TargetObjectId = 'obj-999'
            Hash           = 'hash-orphan'
            RiskScore      = 80
        }

        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @() -ApprovalActions @($aa) -RunId 'run-04'

        $item = $diff.DiffItems | Where-Object { $_.ActionId -eq 'a99' }
        $item | Should -Not -BeNullOrEmpty
        $item.DiffCategory | Should -Be 'ApprovalOnlyNotInWhatIf'
        $diff.Passed | Should -Be $false
    }

    It 'TargetChanged detected with RiskLevel High when TargetObjectId differs' {
        $wa = [pscustomobject]@{
            ActionId       = 'a4'
            ActionType     = 'RemoveGroupMember'
            TargetObjectId = 'obj-original'
            Hash           = 'hash-q'
            RiskScore      = 55
            ProtectedObject = $false
        }
        $aa = [pscustomobject]@{
            ActionId       = 'a4'
            ActionType     = 'RemoveGroupMember'
            TargetObjectId = 'obj-changed'
            Hash           = 'hash-q'
            RiskScore      = 55
        }

        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @($aa) -RunId 'run-05'

        $item = $diff.DiffItems | Where-Object { $_.ActionId -eq 'a4' }
        $item | Should -Not -BeNullOrEmpty
        $item.DiffCategory | Should -Be 'TargetChanged'
        $item.RiskLevel | Should -Be 'High'
    }

    It 'ProtectedObjectAttempted detected when WhatIf action has ProtectedObject true' {
        $wa = [pscustomobject]@{
            ActionId        = 'a5'
            ActionType      = 'DisableAccount'
            TargetObjectId  = 'obj-protected'
            Hash            = 'hash-p'
            RiskScore       = 90
            ProtectedObject = $true
        }
        $aa = [pscustomobject]@{
            ActionId       = 'a5'
            ActionType     = 'DisableAccount'
            TargetObjectId = 'obj-protected'
            Hash           = 'hash-p'
            RiskScore      = 90
        }

        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @($aa) -RunId 'run-06'

        $item = $diff.DiffItems | Where-Object { $_.ActionId -eq 'a5' }
        $item | Should -Not -BeNullOrEmpty
        $item.DiffCategory | Should -Be 'ProtectedObjectAttempted'
    }

    It 'Approval diff Markdown exported contains markdown table markers' {
        $wa = [pscustomobject]@{
            ActionId       = 'md-01'
            ActionType     = 'RemoveGroupMember'
            TargetObjectId = 'obj-md'
            Hash           = 'hash-md'
            RiskScore      = 40
            ProtectedObject = $false
        }
        $aa = [pscustomobject]@{
            ActionId       = 'md-01'
            ActionType     = 'RemoveGroupMember'
            TargetObjectId = 'obj-md'
            Hash           = 'hash-md'
            RiskScore      = 40
        }

        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @($aa) -RunId 'run-md'

        $tempPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.md'
        try {
            Export-DecomApprovalDiffMarkdown -Diff $diff -Path $tempPath
            Test-Path $tempPath | Should -Be $true
            $content = [System.IO.File]::ReadAllText($tempPath)
            $content | Should -Match '\|'
        } finally {
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }
    }

    It 'Approval diff detects ApprovedUnchanged with real matching action' {
        $wa = [pscustomobject]@{ ActionId='ap1'; ActionType='RemoveGroupMember'; TargetObjectId='obj-ap1'; Hash='hash-ap1'; RiskScore=50; ProtectedObject=$false }
        $aa = [pscustomobject]@{ ActionId='ap1'; ActionType='RemoveGroupMember'; TargetObjectId='obj-ap1'; Hash='hash-ap1'; RiskScore=50 }
        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @($aa) -RunId 'run-p102-a'
        ($diff.DiffItems | Where-Object { $_.ActionId -eq 'ap1' }).DiffCategory | Should -Be 'ApprovedUnchanged'
    }

    It 'Approval diff detects RejectedOrOmitted' {
        $wa = [pscustomobject]@{ ActionId='ap2'; ActionType='DisableAccount'; TargetObjectId='obj-ap2'; Hash='hash-ap2'; RiskScore=60; ProtectedObject=$false }
        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @() -RunId 'run-p102-b'
        ($diff.DiffItems | Where-Object { $_.ActionId -eq 'ap2' }).DiffCategory | Should -Be 'RejectedOrOmitted'
    }

    It 'Approval diff detects ApprovalOnlyNotInWhatIf' {
        $aa = [pscustomobject]@{ ActionId='ap3'; ActionType='RevokeAccessPackage'; TargetObjectId='obj-ap3'; Hash='hash-ap3'; RiskScore=70 }
        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @() -ApprovalActions @($aa) -RunId 'run-p102-c'
        ($diff.DiffItems | Where-Object { $_.ActionId -eq 'ap3' }).DiffCategory | Should -Be 'ApprovalOnlyNotInWhatIf'
    }

    It 'Approval diff HTML exported contains HTML tags' {
        $wa = [pscustomobject]@{
            ActionId       = 'html-01'
            ActionType     = 'RevokeAccessPackage'
            TargetObjectId = 'obj-html'
            Hash           = 'hash-html'
            RiskScore      = 65
            ProtectedObject = $false
        }
        $aa = [pscustomobject]@{
            ActionId       = 'html-01'
            ActionType     = 'RevokeAccessPackage'
            TargetObjectId = 'obj-html'
            Hash           = 'hash-html'
            RiskScore      = 65
        }

        $diff = Compare-DecomWhatIfToApproval -WhatIfActions @($wa) -ApprovalActions @($aa) -RunId 'run-html'

        $tempPath = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.html'
        try {
            Export-DecomApprovalDiffHtml -Diff $diff -Path $tempPath
            Test-Path $tempPath | Should -Be $true
            $content = [System.IO.File]::ReadAllText($tempPath)
            $content | Should -Match '<html'
            $content | Should -Match '<table'
        } finally {
            if (Test-Path $tempPath) { Remove-Item $tempPath -Force }
        }
    }
}
