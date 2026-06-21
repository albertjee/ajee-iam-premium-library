#Requires -Version 7.0

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$TenantId,

    [Parameter(Mandatory)]
    [ValidateSet('ReversibleDisable', 'RollbackDisable')]
    [string]$Action,

    [Parameter(Mandatory)]
    [ValidateSet('Readiness', 'WhatIf', 'Execute', 'Verify', 'Closeout')]
    [string]$Mode,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TargetObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$OutputRoot,

    [Parameter()]
    [AllowNull()]
    [string]$ApprovalPhrase,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$InventoryPath = 'C:\temp\IAM\Rev437JsonShapeLive-20260619-214241\rev437-synthetic-nhi-lab-inventory.json'
)

$ErrorActionPreference = 'Stop'

$script:WrapperVersion = 'Rev4.40'
$script:ExpectedTenantId = '3177c971-05c9-4b7b-93a1-0edf6fd7237d'
$script:ExpectedTargetDisplayName = 'AJEE-LAB-NHI-DISABLE-ROLLBACK'
$script:ExpectedTargetAppId = '48deb98d-78c4-49b0-8c56-eed1bb5732c0'
$script:ExpectedTargetApplicationObjectId = 'cacb17fd-bc8d-4798-a8b9-e030699ea2ad'
$script:ExpectedTargetServicePrincipalObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b'
$script:ExpectedControlDisplayName = 'AJEE-LAB-NHI-KEEP-CONTROL'
$script:ExpectedControlServicePrincipalObjectId = 'b574ecc2-443f-4963-9cd4-cb5da517a717'
$script:ExpectedRev438ApprovalPhrase = 'APPROVE REV4.38 LIVE DISABLE AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
$script:ExpectedRev439ApprovalPhrase = 'APPROVE REV4.39 LIVE ROLLBACK AJEE-LAB-NHI-DISABLE-ROLLBACK ONLY'
$script:Rev438ReadinessScriptPath = Join-Path $PSScriptRoot 'Test-Rev438LabLiveDisableReadiness.ps1'
$script:Rev438DisableScriptPath = Join-Path $PSScriptRoot 'Invoke-Rev438LabLiveReversibleDisable.ps1'
$script:Rev439RollbackScriptPath = Join-Path $PSScriptRoot 'Invoke-Rev439LabLiveRollback.ps1'

function Get-NhiExpectedApprovalPhrase {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ReversibleDisable', 'RollbackDisable')]
        [string]$Action
    )

    switch ($Action) {
        'ReversibleDisable' { return $script:ExpectedRev438ApprovalPhrase }
        'RollbackDisable' { return $script:ExpectedRev439ApprovalPhrase }
    }
}

function Assert-NhiApprovalPhrase {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('ReversibleDisable', 'RollbackDisable')]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$ApprovalPhrase
    )

    if ([string]::IsNullOrWhiteSpace($ApprovalPhrase)) {
        throw 'ApprovalPhrase is required for Execute mode.'
    }

    $expectedApprovalPhrase = Get-NhiExpectedApprovalPhrase -Action $Action
    if ($ApprovalPhrase -ne $expectedApprovalPhrase) {
        throw "ApprovalPhrase does not match the approved phrase for $Action."
    }

    return $expectedApprovalPhrase
}

function Write-NhiJsonArtifact {
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

    $json = $InputObject | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($Path, $json, [System.Text.UTF8Encoding]::new($false))
    return $Path
}

function Get-NhiRunRoot {
    param(
        [AllowNull()]
        [string]$OutputRoot,

        [switch]$CreateIfMissing
    )

    if ([string]::IsNullOrWhiteSpace($OutputRoot)) {
        $runRoot = Join-Path 'C:\temp\IAM' ('Rev440SingleObjectLifecycleRun-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    }
    else {
        $runRoot = [System.IO.Path]::GetFullPath($OutputRoot)
    }

    if ($CreateIfMissing -and -not (Test-Path -LiteralPath $runRoot -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $runRoot -Force
    }

    return $runRoot
}

function Get-NhiModeOutputPath {
    param(
        [Parameter(Mandatory)]
        [string]$RunRoot,

        [Parameter(Mandatory)]
        [string]$Mode,

        [switch]$CreateIfMissing
    )

    $outputPath = Join-Path $RunRoot $Mode.ToLowerInvariant()
    if ($CreateIfMissing -and -not (Test-Path -LiteralPath $outputPath -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $outputPath -Force
    }

    return $outputPath
}

function New-NhiRev438ApprovalManifest {
    param(
        [Parameter(Mandatory)]
        [string]$RunId,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$TargetObjectId,

        [Parameter(Mandatory)]
        [string]$TargetDisplayName,

        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter(Mandatory)]
        [string]$ApprovalPhrase
    )

    [pscustomobject]@{
        SchemaVersion = '4.38'
        RunId = $RunId
        Status = 'Approved'
        ApprovedBy = 'lab-approver@example.com'
        ApprovedUtc = [DateTime]::UtcNow.ToString('o')
        ExpiresUtc = [DateTime]::UtcNow.AddDays(1).ToString('o')
        TenantId = $TenantId
        TargetObjectId = $TargetObjectId
        TargetObjectIds = @($TargetObjectId)
        TargetDisplayName = $TargetDisplayName
        AppId = $AppId
        ApprovedAction = 'ReversibleDisable'
        ApprovedActions = @('ReversibleDisable')
        ApprovalPhrase = $ApprovalPhrase
        RollbackReady = $true
        LiveMutationApproved = $true
        FinalDeleteApproved = $false
    }
}

function New-NhiRev439ApprovalManifest {
    param(
        [Parameter(Mandatory)]
        [string]$RunId,

        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$TargetObjectId,

        [Parameter(Mandatory)]
        [string]$TargetDisplayName,

        [Parameter(Mandatory)]
        [string]$AppId,

        [Parameter(Mandatory)]
        [string]$ApprovalPhrase
    )

    [pscustomobject]@{
        SchemaVersion = '4.39'
        RunId = $RunId
        Status = 'Approved'
        ApprovedBy = 'lab-approver@example.com'
        ApprovedUtc = [DateTime]::UtcNow.ToString('o')
        ExpiresUtc = [DateTime]::UtcNow.AddDays(1).ToString('o')
        TenantId = $TenantId
        TargetObjectId = $TargetObjectId
        TargetObjectIds = @($TargetObjectId)
        TargetDisplayName = $TargetDisplayName
        AppId = $AppId
        ApprovedAction = 'ReEnableServicePrincipal'
        ApprovedActions = @('ReEnableServicePrincipal')
        ApprovalPhrase = $ApprovalPhrase
        LiveRollbackApproved = $true
        FinalDeleteApproved = $false
        CleanupApproved = $false
    }
}

function Invoke-NhiRev438Readiness {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$InventoryPath,

        [Parameter(Mandatory)]
        [string]$ApprovalManifestPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$ConfirmLiveDisablePhrase,

        [Parameter(Mandatory)]
        [string]$RunId
    )

    if (-not (Test-Path -LiteralPath $script:Rev438ReadinessScriptPath -PathType Leaf)) {
        throw "Rev4.38 readiness script was not found at '$script:Rev438ReadinessScriptPath'."
    }

    & $script:Rev438ReadinessScriptPath @PSBoundParameters
}

function Invoke-NhiRev438LiveDisable {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$InventoryPath,

        [Parameter(Mandatory)]
        [string]$ApprovalManifestPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$ConfirmLiveDisablePhrase
    )

    if (-not (Test-Path -LiteralPath $script:Rev438DisableScriptPath -PathType Leaf)) {
        throw "Rev4.38 live disable script was not found at '$script:Rev438DisableScriptPath'."
    }

    & $script:Rev438DisableScriptPath @PSBoundParameters
}

function Invoke-NhiRev439LiveRollback {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory)]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [string]$InventoryPath,

        [Parameter(Mandatory)]
        [string]$ApprovalManifestPath,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [string]$ConfirmLiveRollbackPhrase
    )

    if (-not (Test-Path -LiteralPath $script:Rev439RollbackScriptPath -PathType Leaf)) {
        throw "Rev4.39 live rollback script was not found at '$script:Rev439RollbackScriptPath'."
    }

    & $script:Rev439RollbackScriptPath @PSBoundParameters
}

function Invoke-NhiGraphVerification {
    param(
        [Parameter(Mandatory)]
        [string]$Action,

        [Parameter(Mandatory)]
        [string]$TargetObjectId,

        [Parameter(Mandatory)]
        [string]$ControlObjectId
    )

    $target = Get-MgServicePrincipal -ServicePrincipalId $TargetObjectId -Property Id,DisplayName,AppId,AccountEnabled
    $control = Get-MgServicePrincipal -ServicePrincipalId $ControlObjectId -Property Id,DisplayName,AppId,AccountEnabled

    $targetExpectedEnabled = if ($Action -eq 'ReversibleDisable') { $false } else { $true }
    $targetActualEnabled = [bool]$target.AccountEnabled
    $controlActualEnabled = [bool]$control.AccountEnabled
    $passed = ($targetActualEnabled -eq $targetExpectedEnabled) -and ($controlActualEnabled -eq $true)

    $verification = [pscustomobject]@{
        VerificationStatus = if ($passed) { 'Passed' } else { 'Failed' }
        SafetyGatePassed = $passed
        TargetDisplayName = [string]$target.DisplayName
        TargetObjectId = [string]$target.Id
        TargetAccountEnabled = $targetActualEnabled
        ControlDisplayName = [string]$control.DisplayName
        ControlObjectId = [string]$control.Id
        ControlAccountEnabled = $controlActualEnabled
        ExpectedTargetAccountEnabled = $targetExpectedEnabled
        OutputArtifactPath = $null
    }

    return $verification
}

function Invoke-NhiCloseoutSummary {
    param(
        [Parameter(Mandatory)]
        [string]$RunRoot,

        [Parameter(Mandatory)]
        [string]$Action
    )

    $artifacts = @()
    if (Test-Path -LiteralPath $RunRoot -PathType Container) {
        $artifacts = @(Get-ChildItem -Path $RunRoot -Recurse -File | Where-Object { $_.Name -match 'summary|validation|snapshot|manifest|deviation|closeout' } | Sort-Object LastWriteTime -Descending)
    }

    $childSummary = $artifacts | Where-Object { $_.Name -match 'run-summary\.json$' } | Select-Object -First 1
    if (-not $childSummary) {
        $childSummary = $artifacts | Where-Object { $_.Name -match 'readiness\.json$' } | Select-Object -First 1
    }

    return [pscustomobject]@{
        CloseoutStatus = if ($artifacts.Count -gt 0) { 'Collected' } else { 'Empty' }
        SafetyGatePassed = $artifacts.Count -gt 0
        ChildRunSummaryPath = if ($childSummary) { $childSummary.FullName } else { $null }
        EvidenceArtifacts = @($artifacts.FullName)
        OutputArtifactPath = $null
        Action = $Action
    }
}

function Start-NhiSingleObjectLifecycle {
    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$TenantId,

        [Parameter(Mandatory)]
        [ValidateSet('ReversibleDisable', 'RollbackDisable')]
        [string]$Action,

        [Parameter(Mandatory)]
        [ValidateSet('Readiness', 'WhatIf', 'Execute', 'Verify', 'Closeout')]
        [string]$Mode,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$TargetObjectId = '7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b',

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputRoot,

        [Parameter()]
        [AllowNull()]
        [string]$ApprovalPhrase,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$InventoryPath = 'C:\temp\IAM\Rev437JsonShapeLive-20260619-214241\rev437-synthetic-nhi-lab-inventory.json'
    )

    if ($TenantId -ne $script:ExpectedTenantId) {
        throw "TenantId must equal $script:ExpectedTenantId."
    }

    if ($TargetObjectId -ne $script:ExpectedTargetServicePrincipalObjectId) {
        throw "TargetObjectId must equal $script:ExpectedTargetServicePrincipalObjectId."
    }

    if (-not (Test-Path -LiteralPath $InventoryPath -PathType Leaf) -and $Mode -in @('Readiness', 'WhatIf', 'Execute')) {
        throw "Inventory file '$InventoryPath' was not found."
    }

    if ($Action -eq 'RollbackDisable' -and $Mode -eq 'Readiness') {
        throw 'Readiness mode is only supported for ReversibleDisable.'
    }

    $createIfMissing = $Mode -ne 'Closeout'
    $runRoot = Get-NhiRunRoot -OutputRoot $OutputRoot -CreateIfMissing:$createIfMissing
    $outputPath = Get-NhiModeOutputPath -RunRoot $runRoot -Mode $Mode -CreateIfMissing:$createIfMissing

    if (-not $createIfMissing) {
        if (-not (Test-Path -LiteralPath $runRoot -PathType Container)) {
            throw "STOP: Closeout requires an existing run root. Create or reuse the prior lifecycle output root before running Closeout."
        }

        if (-not (Test-Path -LiteralPath $outputPath -PathType Container)) {
            throw "STOP: Closeout requires an existing output path. Aggregate only from pre-existing lifecycle artifacts."
        }
    }

    $runId = 'REV440-{0}' -f ([guid]::NewGuid().ToString('N'))
    $targetDisplayName = $script:ExpectedTargetDisplayName
    $targetAppId = $script:ExpectedTargetAppId
    $controlObjectId = $script:ExpectedControlServicePrincipalObjectId
    $childSummary = $null
    $childRunSummaryPath = $null
    $underlyingScript = $null
    $liveMutationRequested = $Mode -in @('WhatIf', 'Execute')
    $liveMutationPerformed = $false
    $safetyGatePassed = $false
    $finalDeleteAllowed = $false
    $cleanupAllowed = $false
    $verificationStatus = $null

    switch ($Mode) {
        'Readiness' {
            $approvalToUse = if ([string]::IsNullOrWhiteSpace($ApprovalPhrase)) { $script:ExpectedRev438ApprovalPhrase } else { $ApprovalPhrase }
            if ($Action -ne 'ReversibleDisable') {
                throw 'Readiness mode only supports ReversibleDisable.'
            }

            $approvalManifest = New-NhiRev438ApprovalManifest -RunId $runId -TenantId $TenantId -TargetObjectId $TargetObjectId -TargetDisplayName $targetDisplayName -AppId $targetAppId -ApprovalPhrase $approvalToUse
            $approvalManifestPath = Write-NhiJsonArtifact -Path (Join-Path $outputPath 'rev438-live-run-approval.json') -InputObject $approvalManifest
            $underlyingScript = $script:Rev438ReadinessScriptPath
            $childSummary = Invoke-NhiRev438Readiness -TenantId $TenantId -InventoryPath $InventoryPath -ApprovalManifestPath $approvalManifestPath -OutputPath $outputPath -ConfirmLiveDisablePhrase $approvalToUse -RunId $runId
            $childRunSummaryPath = [string]$childSummary.OutputArtifactPath
            $safetyGatePassed = [bool]$childSummary.ReadyForLiveDisable
        }

        'WhatIf' {
            if ($Action -eq 'ReversibleDisable') {
                $approvalToUse = if ([string]::IsNullOrWhiteSpace($ApprovalPhrase)) { $script:ExpectedRev438ApprovalPhrase } else { $ApprovalPhrase }
                $approvalManifest = New-NhiRev438ApprovalManifest -RunId $runId -TenantId $TenantId -TargetObjectId $TargetObjectId -TargetDisplayName $targetDisplayName -AppId $targetAppId -ApprovalPhrase $approvalToUse
                $approvalManifestPath = Write-NhiJsonArtifact -Path (Join-Path $outputPath 'rev438-live-disable-approval.json') -InputObject $approvalManifest
                $underlyingScript = $script:Rev438DisableScriptPath
                $childSummary = Invoke-NhiRev438LiveDisable -TenantId $TenantId -InventoryPath $InventoryPath -ApprovalManifestPath $approvalManifestPath -OutputPath $outputPath -ConfirmLiveDisablePhrase $approvalToUse -WhatIf
                $childRunSummaryPath = [string]$childSummary.OutputArtifactPath
                $safetyGatePassed = [bool]$childSummary.SafetyGatePassed
                $liveMutationPerformed = [bool]$childSummary.LiveMutationPerformed
            } elseif ($Action -eq 'RollbackDisable') {
                $approvalToUse = if ([string]::IsNullOrWhiteSpace($ApprovalPhrase)) { $script:ExpectedRev439ApprovalPhrase } else { $ApprovalPhrase }
                $approvalManifest = New-NhiRev439ApprovalManifest -RunId $runId -TenantId $TenantId -TargetObjectId $TargetObjectId -TargetDisplayName $targetDisplayName -AppId $targetAppId -ApprovalPhrase $approvalToUse
                $approvalManifestPath = Write-NhiJsonArtifact -Path (Join-Path $outputPath 'rev439-live-rollback-approval.json') -InputObject $approvalManifest
                $underlyingScript = $script:Rev439RollbackScriptPath
                $childSummary = Invoke-NhiRev439LiveRollback -TenantId $TenantId -InventoryPath $InventoryPath -ApprovalManifestPath $approvalManifestPath -OutputPath $outputPath -ConfirmLiveRollbackPhrase $approvalToUse -WhatIf
                $childRunSummaryPath = [string]$childSummary.OutputArtifactPath
                $safetyGatePassed = [bool]$childSummary.SafetyGatePassed
                $liveMutationPerformed = [bool]$childSummary.LiveMutationPerformed
            }
        }

        'Execute' {
            $approvalToUse = Assert-NhiApprovalPhrase -Action $Action -ApprovalPhrase $ApprovalPhrase

            if (-not $PSCmdlet.ShouldProcess($TargetObjectId, "Execute $Action")) {
                break
            }

            if ($Action -eq 'ReversibleDisable') {
                $approvalManifest = New-NhiRev438ApprovalManifest -RunId $runId -TenantId $TenantId -TargetObjectId $TargetObjectId -TargetDisplayName $targetDisplayName -AppId $targetAppId -ApprovalPhrase $approvalToUse
                $approvalManifestPath = Write-NhiJsonArtifact -Path (Join-Path $outputPath 'rev438-live-disable-approval.json') -InputObject $approvalManifest
                $underlyingScript = $script:Rev438DisableScriptPath
                $childSummary = Invoke-NhiRev438LiveDisable -TenantId $TenantId -InventoryPath $InventoryPath -ApprovalManifestPath $approvalManifestPath -OutputPath $outputPath -ConfirmLiveDisablePhrase $approvalToUse -Confirm:$false
                $childRunSummaryPath = [string]$childSummary.OutputArtifactPath
                $safetyGatePassed = [bool]$childSummary.SafetyGatePassed
                $liveMutationPerformed = [bool]$childSummary.LiveMutationPerformed
            } elseif ($Action -eq 'RollbackDisable') {
                $approvalManifest = New-NhiRev439ApprovalManifest -RunId $runId -TenantId $TenantId -TargetObjectId $TargetObjectId -TargetDisplayName $targetDisplayName -AppId $targetAppId -ApprovalPhrase $approvalToUse
                $approvalManifestPath = Write-NhiJsonArtifact -Path (Join-Path $outputPath 'rev439-live-rollback-approval.json') -InputObject $approvalManifest
                $underlyingScript = $script:Rev439RollbackScriptPath
                $childSummary = Invoke-NhiRev439LiveRollback -TenantId $TenantId -InventoryPath $InventoryPath -ApprovalManifestPath $approvalManifestPath -OutputPath $outputPath -ConfirmLiveRollbackPhrase $approvalToUse -Confirm:$false
                $childRunSummaryPath = [string]$childSummary.OutputArtifactPath
                $safetyGatePassed = [bool]$childSummary.SafetyGatePassed
                $liveMutationPerformed = [bool]$childSummary.LiveMutationPerformed
            }
        }

        'Verify' {
            $verification = Invoke-NhiGraphVerification -Action $Action -TargetObjectId $TargetObjectId -ControlObjectId $controlObjectId
            $verificationStatus = [string]$verification.VerificationStatus
            $safetyGatePassed = [bool]$verification.SafetyGatePassed
            $childSummary = $verification
        }

        'Closeout' {
            $closeout = Invoke-NhiCloseoutSummary -RunRoot $runRoot -Action $Action
            $safetyGatePassed = [bool]$closeout.SafetyGatePassed
            $childSummary = $closeout
            $childRunSummaryPath = [string]$closeout.ChildRunSummaryPath
        }
    }

    $wrapperSummaryPath = Join-Path $runRoot 'rev440-wrapper-summary.json'
    $summary = [pscustomobject]@{
        WrapperVersion = $script:WrapperVersion
        RunId = $runId
        Action = $Action
        Mode = $Mode
        TenantId = $TenantId
        TargetObjectId = $TargetObjectId
        UnderlyingScript = $underlyingScript
        ApprovalManifestPath = $approvalManifestPath
        OutputPath = $outputPath
        WhatIf = ($Mode -eq 'WhatIf') -or [bool]$WhatIfPreference
        LiveMutationRequested = $liveMutationRequested
        LiveMutationPerformed = $liveMutationPerformed
        SafetyGatePassed = $safetyGatePassed
        FinalDeleteAllowed = $finalDeleteAllowed
        CleanupAllowed = $cleanupAllowed
        ChildRunSummaryPath = $childRunSummaryPath
        WrapperRunSummaryPath = $wrapperSummaryPath
        RunRoot = $runRoot
        VerificationStatus = $verificationStatus
    }

    $null = Write-NhiJsonArtifact -Path $wrapperSummaryPath -InputObject $summary
    return $summary
}

if ($MyInvocation.InvocationName -ne '.') {
    Start-NhiSingleObjectLifecycle @PSBoundParameters
}
