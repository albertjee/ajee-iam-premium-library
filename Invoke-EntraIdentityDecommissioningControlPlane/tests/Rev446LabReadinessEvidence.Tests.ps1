#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

function script:Write-TestJson {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [object]$InputObject
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parent -Force
    }

    ($InputObject | ConvertTo-Json -Depth 20) | Set-Content -LiteralPath $Path -Encoding utf8
}

function script:Get-CommandCounts {
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $errors = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    if ($errors.Count -gt 0) {
        throw "Parse errors in $Path : $($errors.Count)"
    }

    $commands = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst]
    }, $true)

    [pscustomobject]@{
        RemoveCount = @($commands | Where-Object { $_.GetCommandName() -like 'Remove-Mg*' }).Count
        UpdateCount = @($commands | Where-Object { $_.GetCommandName() -like 'Update-Mg*' }).Count
        SetCount = @($commands | Where-Object { $_.GetCommandName() -like 'Set-Mg*' }).Count
        NewCount = @($commands | Where-Object { $_.GetCommandName() -like 'New-Mg*' }).Count
        InvokeCount = @($commands | Where-Object { $_.GetCommandName() -like 'Invoke-Mg*' }).Count
    }
}

function script:New-OwnerEvidence {
    param(
        [string]$Name = 'Lab owner approval board',
        [string]$Rationale = 'Ownerless is acceptable in this lab because the target is synthetic and isolated.',
        [string]$Timestamp = ([DateTime]::UtcNow.ToString('o'))
    )

    [pscustomobject]@{
        OwnerStatus = 'NoOwners'
        OwnerName = $Name
        Rationale = $Rationale
        Timestamp = $Timestamp
    }
}

function script:New-ActivityEvidence {
    param(
        [string]$Rationale = 'No recent sign-in activity is acceptable for this lab target because the target is intentionally idle.',
        [string]$Timestamp = ([DateTime]::UtcNow.ToString('o'))
    )

    [pscustomobject]@{
        LastObservedActivity = 'Unknown'
        Rationale = $Rationale
        Timestamp = $Timestamp
    }
}

function script:New-RiskAcceptance {
    param(
        [string]$ApprovedBy = 'Lab readiness approver',
        [string]$Rationale = 'Explicit lab-only acceptance recorded for readiness evidence.',
        [string]$Timestamp = ([DateTime]::UtcNow.ToString('o')),
        [string]$ExpiresUtc = ([DateTime]::UtcNow.AddDays(2).ToString('o')),
        [bool]$FinalDeleteApproved = $false,
        [bool]$CleanupApproved = $false,
        [bool]$LiveMutationApproved = $false,
        [bool]$BatchExecutionApproved = $false,
        [string]$Statement = 'This is a lab-only readiness acceptance and does not approve production use.'
    )

    [pscustomobject]@{
        ApprovedBy = $ApprovedBy
        Rationale = $Rationale
        Timestamp = $Timestamp
        ExpiresUtc = $ExpiresUtc
        ProductionUseApproved = $false
        FinalDeleteApproved = $FinalDeleteApproved
        CleanupApproved = $CleanupApproved
        LiveMutationApproved = $LiveMutationApproved
        BatchExecutionApproved = $BatchExecutionApproved
        Statement = $Statement
    }
}

Describe 'Rev4.46 lab readiness evidence' {
    BeforeAll {
        $script:ToolPath = Join-Path $PSScriptRoot '..\tools\Start-NhiLabReadinessEvidence.ps1'
        $script:TenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
        $script:TargetObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
        $script:TargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
        $script:AppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
        $script:ApprovalPhrase = 'APPROVE REV4.46 LAB READINESS EVIDENCE ONLY'
        $script:ToolCommands = Get-CommandCounts -Path $script:ToolPath
    }

    BeforeEach {
        $script:RunRoot = Join-Path $TestDrive ('rev446-' + [guid]::NewGuid().ToString('N'))
    }

    It 'generates happy-path readiness evidence' {
        $owner = New-OwnerEvidence
        $activity = New-ActivityEvidence
        $risk = New-RiskAcceptance

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode Readiness -OwnerEvidence $owner -ActivityEvidence $activity -RiskAcceptance $risk -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))

        $result.SafetyGatePassed | Should -BeTrue
        $result.EvidenceStatus | Should -Be 'Ready'
        $result.TenantMutationPerformed | Should -BeFalse
        $result.LiveMutationApproved | Should -BeFalse
        Test-Path -LiteralPath $result.ArtifactPaths.EvidencePath | Should -BeTrue
        Test-Path -LiteralPath $result.ArtifactPaths.SummaryPath | Should -BeTrue
        Test-Path -LiteralPath $result.ArtifactPaths.RunbookPath | Should -BeTrue

        $summary = Get-Content -LiteralPath $result.ArtifactPaths.SummaryPath -Raw | ConvertFrom-Json
        $summary.SchemaVersion | Should -Be 'Rev4.46-LabReadinessEvidence'
        $summary.OwnerEvidenceAccepted | Should -BeTrue
        $summary.ActivityEvidenceAccepted | Should -BeTrue
        $summary.RiskAcceptanceAccepted | Should -BeTrue
        $summary.FinalDeleteApproved | Should -BeFalse
        $summary.CleanupApproved | Should -BeFalse
        $summary.LiveMutationApproved | Should -BeFalse
        $summary.TenantMutationPerformed | Should -BeFalse
    }

    It 'blocks a wrong target' {
        $owner = New-OwnerEvidence
        $activity = New-ActivityEvidence
        $risk = New-RiskAcceptance

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId '11111111-1111-1111-1111-111111111111' -TargetDisplayName 'Wrong Target' -AppId '22222222-2222-2222-2222-222222222222' -OutputRoot $script:RunRoot -EvidenceMode Validate -OwnerEvidence $owner -ActivityEvidence $activity -RiskAcceptance $risk -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))

        $result.SafetyGatePassed | Should -BeFalse
        @($result.BlockingReasons).Count | Should -BeGreaterThan 0
    }

    It 'blocks missing owner evidence' {
        $activity = New-ActivityEvidence
        $risk = New-RiskAcceptance

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode Validate -OwnerEvidence $null -ActivityEvidence $activity -RiskAcceptance $risk -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))

        $result.SafetyGatePassed | Should -BeFalse
        ($result.BlockingReasons -join ';') | Should -Match 'Owner evidence is required'
    }

    It 'blocks missing activity evidence' {
        $owner = New-OwnerEvidence
        $risk = New-RiskAcceptance

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode Validate -OwnerEvidence $owner -ActivityEvidence $null -RiskAcceptance $risk -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))

        $result.SafetyGatePassed | Should -BeFalse
        ($result.BlockingReasons -join ';') | Should -Match 'Activity evidence is required'
    }

    It 'blocks missing risk acceptance' {
        $owner = New-OwnerEvidence
        $activity = New-ActivityEvidence

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode Validate -OwnerEvidence $owner -ActivityEvidence $activity -RiskAcceptance $null -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))

        $result.SafetyGatePassed | Should -BeFalse
        ($result.BlockingReasons -join ';') | Should -Match 'Risk acceptance is required'
    }

    It 'blocks expired evidence' {
        $owner = New-OwnerEvidence
        $activity = New-ActivityEvidence
        $risk = New-RiskAcceptance -ExpiresUtc ([DateTime]::UtcNow.AddDays(-1).ToString('o'))

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode Validate -OwnerEvidence $owner -ActivityEvidence $activity -RiskAcceptance $risk -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(-1).ToString('o'))

        $result.SafetyGatePassed | Should -BeFalse
        ($result.BlockingReasons -join ';') | Should -Match 'must be in the future'
    }

    It 'blocks a wrong approval phrase' {
        $owner = New-OwnerEvidence
        $activity = New-ActivityEvidence
        $risk = New-RiskAcceptance

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode WhatIf -OwnerEvidence $owner -ActivityEvidence $activity -RiskAcceptance $risk -ApprovedBy 'Lab readiness approver' -ApprovalPhrase 'WRONG PHRASE' -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))

        $result.SafetyGatePassed | Should -BeFalse
        ($result.BlockingReasons -join ';') | Should -Match 'ApprovalPhrase does not match'
    }

    It 'blocks final delete or cleanup approval' {
        $owner = New-OwnerEvidence
        $activity = New-ActivityEvidence
        $risk = New-RiskAcceptance -FinalDeleteApproved $true

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode Validate -OwnerEvidence $owner -ActivityEvidence $activity -RiskAcceptance $risk -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))

        $result.SafetyGatePassed | Should -BeFalse
        ($result.BlockingReasons -join ';') | Should -Match 'Final delete approval is not permitted'

        $risk2 = New-RiskAcceptance -CleanupApproved $true
        $result2 = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode Validate -OwnerEvidence $owner -ActivityEvidence $activity -RiskAcceptance $risk2 -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))

        $result2.SafetyGatePassed | Should -BeFalse
        ($result2.BlockingReasons -join ';') | Should -Match 'Cleanup approval is not permitted'
    }

    It 'contains no forbidden mutation commands in the tool source' {
        $script:ToolCommands.RemoveCount | Should -Be 0
        $script:ToolCommands.UpdateCount | Should -Be 0
        $script:ToolCommands.SetCount | Should -Be 0
        $script:ToolCommands.NewCount | Should -Be 0
        $script:ToolCommands.InvokeCount | Should -Be 0

        $content = Get-Content -LiteralPath $script:ToolPath -Raw
        $content | Should -Not -Match '\bRemove-Mg'
        $content | Should -Not -Match '\bUpdate-Mg'
        $content | Should -Not -Match '\bSet-Mg'
        $content | Should -Not -Match '\bNew-Mg'
        $content | Should -Not -Match '\bInvoke-Mg'
    }

    It 'writes artifacts with tenant mutation false and live mutation false' {
        $owner = New-OwnerEvidence
        $activity = New-ActivityEvidence
        $risk = New-RiskAcceptance

        $result = & $script:ToolPath -TenantId $script:TenantId -TargetObjectId $script:TargetObjectId -TargetDisplayName $script:TargetDisplayName -AppId $script:AppId -OutputRoot $script:RunRoot -EvidenceMode Closeout -OwnerEvidence $owner -ActivityEvidence $activity -RiskAcceptance $risk -ApprovedBy 'Lab readiness approver' -ApprovalPhrase $script:ApprovalPhrase -ExpiresUtc ([DateTime]::UtcNow.AddDays(1).ToString('o'))
        $evidence = Get-Content -LiteralPath $result.ArtifactPaths.EvidencePath -Raw | ConvertFrom-Json
        $summary = Get-Content -LiteralPath $result.ArtifactPaths.SummaryPath -Raw | ConvertFrom-Json

        $evidence.TenantMutationPerformed | Should -BeFalse
        $evidence.LiveMutationApproved | Should -BeFalse
        $summary.TenantMutationPerformed | Should -BeFalse
        $summary.LiveMutationApproved | Should -BeFalse
    }
}
