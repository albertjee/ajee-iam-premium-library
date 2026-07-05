# ReplayValidation.psm1 — Rev3.4
# Validates that an execution can be replayed from saved WhatIf, Approval,
# ExecutionLog, ExecutionEvidence, and manifest files WITHOUT connecting to Graph.
# No write cmdlets. No Graph connection. Entirely offline.

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function Invoke-DecomReplayValidation {
    <#
    .SYNOPSIS
    Runs all replay validation checks against saved run artifacts.
    .DESCRIPTION
    Validates binding and consistency of WhatIf report, approval manifest, and
    execution evidence objects without any Graph connection. Works entirely offline.
    .PARAMETER WhatIfReport
    Optional WhatIf run report object. If $null, WhatIf-related checks are skipped.
    .PARAMETER ApprovalManifest
    Optional approval manifest object. If $null, approval-related checks are skipped.
    .PARAMETER ExecutionEvidence
    Optional execution evidence object. If $null, execution checks are skipped.
    .PARAMETER RunId
    The run ID being validated.
    .OUTPUTS
    PSCustomObject with SchemaVersion, Passed, CheckCount, PassedChecks, FailedChecks,
    Findings, and Warnings properties.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [pscustomobject]$WhatIfReport,

        [Parameter(Mandatory = $false)]
        [pscustomobject]$ApprovalManifest,

        [Parameter(Mandatory = $false)]
        [pscustomobject]$ExecutionEvidence,

        [Parameter(Mandatory = $false)]
        [string]$RunId
    )

    $findings = [System.Collections.Generic.List[object]]::new()
    $warnings  = [System.Collections.Generic.List[string]]::new()

    # ── Input availability warnings ──────────────────────────────────────────

    if ($null -eq $WhatIfReport) {
        $warnings.Add('WhatIfReport not provided — WhatIf binding checks skipped')
    }
    if ($null -eq $ApprovalManifest) {
        $warnings.Add('ApprovalManifest not provided — approval binding and action checks skipped')
    }
    if ($null -eq $ExecutionEvidence) {
        $warnings.Add('ExecutionEvidence not provided — execution consistency checks skipped')
    }

    if ($null -eq $WhatIfReport -and $null -eq $ApprovalManifest -and $null -eq $ExecutionEvidence) {
        return [pscustomobject]@{
            SchemaVersion = '3.6'
            ToolVersion   = Get-DecomToolVersion
            RunId         = $RunId
            ValidatedUtc   = (Get-Date).ToUniversalTime().ToString('o')
            Passed        = $null
            CheckCount    = 0
            PassedChecks  = 0
            FailedChecks  = 0
            Findings      = @()
            Warnings      = $warnings.ToArray()
            Status        = 'SkippedNoReplayInputs'
        }
    }

    # ── Check 1: WhatIfRunId in approval matches WhatIf report RunId ─────────

    if ($null -ne $WhatIfReport -and $null -ne $ApprovalManifest) {
        $bindingResult = Test-DecomWhatIfApprovalBinding `
            -WhatIfReport      $WhatIfReport `
            -ApprovalManifest  $ApprovalManifest
        $findings.Add($bindingResult)
    }

    # ── Check 2: ApprovalEnvelopeHash in execution evidence matches approval ─

    if ($null -ne $ApprovalManifest -and $null -ne $ExecutionEvidence) {
        $hashBindingResult = Test-DecomApprovalExecutionBinding `
            -ApprovalManifest  $ApprovalManifest `
            -ExecutionEvidence $ExecutionEvidence
        $findings.Add($hashBindingResult)
    }

    # ── Checks 3–10: Execution evidence internal consistency ─────────────────

    if ($null -ne $ApprovalManifest -and $null -ne $ExecutionEvidence) {
        $consistencyResults = Test-DecomExecutionEvidenceConsistency `
            -ApprovalManifest  $ApprovalManifest `
            -ExecutionEvidence $ExecutionEvidence
        foreach ($r in $consistencyResults) {
            $findings.Add($r)
        }
    }

    # ── Aggregate ────────────────────────────────────────────────────────────

    $allFindings   = $findings.ToArray()
    $passedChecks  = @($allFindings | Where-Object { $_.Passed -eq $true  }).Count
    $failedChecks  = @($allFindings | Where-Object { $_.Passed -eq $false }).Count
    $overallPassed = ($failedChecks -eq 0) -and ($allFindings.Count -gt 0)

    return [pscustomobject]@{
        SchemaVersion = '3.6'
        ToolVersion = Get-DecomToolVersion
        RunId         = $RunId
        ValidatedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        Passed        = $overallPassed
        CheckCount    = $allFindings.Count
        PassedChecks  = $passedChecks
        FailedChecks  = $failedChecks
        Findings      = $allFindings
        Warnings      = $warnings.ToArray()
    }
}

function Test-DecomWhatIfApprovalBinding {
    <#
    .SYNOPSIS
    Verifies WhatIfRunId in the approval manifest matches the WhatIf report RunId.
    .PARAMETER WhatIfReport
    WhatIf run report object (must have a RunId property).
    .PARAMETER ApprovalManifest
    Approval manifest object (must have a WhatIfRunId property).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$WhatIfReport,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$ApprovalManifest
    )

    $whatIfRunId    = [string]$WhatIfReport.RunId
    $approvalRunId  = [string]$ApprovalManifest.WhatIfRunId

    if (-not $whatIfRunId) {
        return [pscustomobject]@{
            CheckName = 'WhatIfApprovalBinding'
            Passed    = $false
            Message   = 'WhatIfReport.RunId is empty — cannot verify binding'
            Severity  = 'Error'
        }
    }

    if (-not $approvalRunId) {
        return [pscustomobject]@{
            CheckName = 'WhatIfApprovalBinding'
            Passed    = $false
            Message   = 'ApprovalManifest.WhatIfRunId is empty — cannot verify binding'
            Severity  = 'Error'
        }
    }

    if ($whatIfRunId -eq $approvalRunId) {
        return [pscustomobject]@{
            CheckName = 'WhatIfApprovalBinding'
            Passed    = $true
            Message   = "WhatIfRunId binding verified: '$whatIfRunId'"
            Severity  = 'Info'
        }
    } else {
        return [pscustomobject]@{
            CheckName = 'WhatIfApprovalBinding'
            Passed    = $false
            Message   = "WhatIfRunId mismatch: WhatIfReport.RunId='$whatIfRunId', ApprovalManifest.WhatIfRunId='$approvalRunId'"
            Severity  = 'Error'
        }
    }
}

function Test-DecomApprovalExecutionBinding {
    <#
    .SYNOPSIS
    Verifies ApprovalEnvelopeHash in execution evidence matches the approval manifest hash.
    .PARAMETER ApprovalManifest
    Approval manifest object (must have an ApprovalEnvelopeHash property).
    .PARAMETER ExecutionEvidence
    Execution evidence object (must have an ApprovalEnvelopeHash property).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ApprovalManifest,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$ExecutionEvidence
    )

    $manifestHash  = [string]$ApprovalManifest.ApprovalEnvelopeHash
    $evidenceHash  = [string]$ExecutionEvidence.ApprovalEnvelopeHash

    if (-not $manifestHash) {
        return [pscustomobject]@{
            CheckName = 'ApprovalExecutionBinding'
            Passed    = $false
            Message   = 'ApprovalManifest.ApprovalEnvelopeHash is empty — cannot verify execution binding'
            Severity  = 'Error'
        }
    }

    if (-not $evidenceHash) {
        return [pscustomobject]@{
            CheckName = 'ApprovalExecutionBinding'
            Passed    = $false
            Message   = 'ExecutionEvidence.ApprovalEnvelopeHash is empty — cannot verify execution binding'
            Severity  = 'Error'
        }
    }

    if ($manifestHash -eq $evidenceHash) {
        return [pscustomobject]@{
            CheckName = 'ApprovalExecutionBinding'
            Passed    = $true
            Message   = "ApprovalEnvelopeHash binding verified: '$manifestHash'"
            Severity  = 'Info'
        }
    } else {
        return [pscustomobject]@{
            CheckName = 'ApprovalExecutionBinding'
            Passed    = $false
            Message   = "ApprovalEnvelopeHash mismatch: manifest='$manifestHash', evidence='$evidenceHash'"
            Severity  = 'Error'
        }
    }
}

function Test-DecomExecutionEvidenceConsistency {
    <#
    .SYNOPSIS
    Validates execution evidence internal consistency against approval manifest.
    .DESCRIPTION
    Runs checks 3–10:
      3. ApprovedActionsHash in execution matches approved action list hash
      4. Every executed ActionId exists in approval manifest
      5. No unapproved ActionId appears in execution evidence
      6. Every TargetObjectId in execution evidence was approved
      7. Every Failed/PartialFailed/Blocked action has ErrorDetail populated
      8. Every Executed action has post-write evidence reference
      9. Skipped actions do not claim tenant write
     10. ProtectedObject actions are Blocked (not Executed)
    .PARAMETER ApprovalManifest
    Approval manifest object with ApprovedActions array and hash fields.
    .PARAMETER ExecutionEvidence
    Execution evidence object with Actions array.
    .OUTPUTS
    Array of finding objects, one per check.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ApprovalManifest,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$ExecutionEvidence
    )

    $results = [System.Collections.Generic.List[object]]::new()

    # Collect approved actions into a lookup for efficiency
    $approvedActions    = @($ApprovalManifest.ApprovedActions)
    $approvedActionIds  = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase)
    $approvedTargetMap  = @{}  # ActionId -> array of TargetObjectId strings

    foreach ($act in $approvedActions) {
        $actId = [string]$act.ActionId
        if ($actId) {
            [void]$approvedActionIds.Add($actId)
            $tids = @($act.TargetObjectIds | ForEach-Object { [string]$_ } | Where-Object { $_ -ne '' })
            $approvedTargetMap[$actId] = $tids
        }
    }

    # Execution evidence actions
    $evidenceActions = @($ExecutionEvidence.Actions)

    # ── Check 3: ApprovedActionsHash in execution matches computed hash ───────

    $manifestActionsHash  = [string]$ApprovalManifest.ApprovedActionsHash
    $evidenceActionsHash  = [string]$ExecutionEvidence.ApprovedActionsHash

    if (-not $manifestActionsHash -and -not $evidenceActionsHash) {
        $results.Add([pscustomobject]@{
            CheckName = 'ApprovedActionsHashMatch'
            Passed    = $true
            Message   = 'ApprovedActionsHash not present in either object — check skipped'
            Severity  = 'Info'
        })
    } elseif (-not $evidenceActionsHash) {
        $results.Add([pscustomobject]@{
            CheckName = 'ApprovedActionsHashMatch'
            Passed    = $false
            Message   = 'ExecutionEvidence.ApprovedActionsHash is missing — cannot verify action list integrity'
            Severity  = 'Error'
        })
    } elseif (-not $manifestActionsHash) {
        $results.Add([pscustomobject]@{
            CheckName = 'ApprovedActionsHashMatch'
            Passed    = $false
            Message   = 'ApprovalManifest.ApprovedActionsHash is missing — cannot verify action list integrity'
            Severity  = 'Error'
        })
    } elseif ($manifestActionsHash -eq $evidenceActionsHash) {
        $results.Add([pscustomobject]@{
            CheckName = 'ApprovedActionsHashMatch'
            Passed    = $true
            Message   = "ApprovedActionsHash verified: '$manifestActionsHash'"
            Severity  = 'Info'
        })
    } else {
        $results.Add([pscustomobject]@{
            CheckName = 'ApprovedActionsHashMatch'
            Passed    = $false
            Message   = "ApprovedActionsHash mismatch: manifest='$manifestActionsHash', evidence='$evidenceActionsHash'"
            Severity  = 'Error'
        })
    }

    # ── Check 4: Every executed ActionId exists in approval manifest ──────────

    $unknownActionIds = [System.Collections.Generic.List[string]]::new()
    foreach ($evtAction in $evidenceActions) {
        $evtId = [string]$evtAction.ActionId
        if ($evtId -and -not $approvedActionIds.Contains($evtId)) {
            $unknownActionIds.Add($evtId)
        }
    }

    if ($unknownActionIds.Count -eq 0) {
        $results.Add([pscustomobject]@{
            CheckName = 'AllExecutedActionsApproved'
            Passed    = $true
            Message   = 'All ActionIds in execution evidence exist in the approval manifest'
            Severity  = 'Info'
        })
    } else {
        $list = $unknownActionIds -join ', '
        $results.Add([pscustomobject]@{
            CheckName = 'AllExecutedActionsApproved'
            Passed    = $false
            Message   = "ActionIds in evidence not found in approval manifest: $list"
            Severity  = 'Error'
        })
    }

    # ── Check 5: No unapproved ActionId appears in execution evidence ─────────
    # (Alias / complementary to check 4 — flags any ActionId present in evidence
    # that is absent from the approval manifest, regardless of outcome.)

    $unapprovedIds = [System.Collections.Generic.List[string]]::new()
    foreach ($evtAction in $evidenceActions) {
        $evtId = [string]$evtAction.ActionId
        if ($evtId -and -not $approvedActionIds.Contains($evtId)) {
            if (-not $unapprovedIds.Contains($evtId)) {
                $unapprovedIds.Add($evtId)
            }
        }
    }

    if ($unapprovedIds.Count -eq 0) {
        $results.Add([pscustomobject]@{
            CheckName = 'NoUnapprovedActionIds'
            Passed    = $true
            Message   = 'No unapproved ActionIds found in execution evidence'
            Severity  = 'Info'
        })
    } else {
        $list = $unapprovedIds -join ', '
        $results.Add([pscustomobject]@{
            CheckName = 'NoUnapprovedActionIds'
            Passed    = $false
            Message   = "Unapproved ActionIds present in execution evidence: $list"
            Severity  = 'Error'
        })
    }

    # ── Check 6: Every TargetObjectId in execution evidence was approved ──────

    $unapprovedTargets = [System.Collections.Generic.List[string]]::new()
    foreach ($evtAction in $evidenceActions) {
        $evtId = [string]$evtAction.ActionId
        if (-not $evtId) { continue }
        if (-not $approvedActionIds.Contains($evtId)) { continue }  # already caught by check 4/5

        $approvedTids = $approvedTargetMap[$evtId]
        if ($null -eq $approvedTids) { $approvedTids = @() }

        $evidenceTids = @($evtAction.TargetObjectIds | ForEach-Object { [string]$_ } | Where-Object { $_ -ne '' })
        # If evidence has no TargetObjectId, fall back to TargetObjectId (singular) property
        if ($evidenceTids.Count -eq 0 -and $evtAction.TargetObjectId) {
            $evidenceTids = @([string]$evtAction.TargetObjectId)
        }

        foreach ($tid in $evidenceTids) {
            if ($approvedTids.Count -gt 0 -and $approvedTids -notcontains $tid) {
                $unapprovedTargets.Add("$evtId/$tid")
            }
        }
    }

    if ($unapprovedTargets.Count -eq 0) {
        $results.Add([pscustomobject]@{
            CheckName = 'AllTargetObjectIdsApproved'
            Passed    = $true
            Message   = 'All TargetObjectIds in execution evidence were approved'
            Severity  = 'Info'
        })
    } else {
        $list = ($unapprovedTargets | Select-Object -First 5) -join ', '
        $results.Add([pscustomobject]@{
            CheckName = 'AllTargetObjectIdsApproved'
            Passed    = $false
            Message   = "Unapproved TargetObjectIds in execution evidence (ActionId/TargetObjectId): $list"
            Severity  = 'Error'
        })
    }

    # ── Check 7: Every Failed/PartialFailed/Blocked action has ErrorDetail ────

    $missingErrorDetail = [System.Collections.Generic.List[string]]::new()
    foreach ($evtAction in $evidenceActions) {
        $outcome = [string]$evtAction.Outcome
        if ($outcome -in @('Failed', 'PartialFailed', 'Blocked')) {
            $detail = [string]$evtAction.ErrorDetail
            if (-not $detail -or $detail.Trim() -eq '') {
                $missingErrorDetail.Add("$([string]$evtAction.ActionId) (Outcome=$outcome)")
            }
        }
    }

    if ($missingErrorDetail.Count -eq 0) {
        $results.Add([pscustomobject]@{
            CheckName = 'FailedBlockedActionsHaveErrorDetail'
            Passed    = $true
            Message   = 'All Failed/PartialFailed/Blocked actions have ErrorDetail populated'
            Severity  = 'Info'
        })
    } else {
        $list = $missingErrorDetail -join ', '
        $results.Add([pscustomobject]@{
            CheckName = 'FailedBlockedActionsHaveErrorDetail'
            Passed    = $false
            Message   = "Actions missing ErrorDetail for non-success outcomes: $list"
            Severity  = 'Error'
        })
    }

    # ── Check 8: Every Executed action has post-write evidence reference ──────

    $missingPostWrite = [System.Collections.Generic.List[string]]::new()
    foreach ($evtAction in $evidenceActions) {
        $outcome = [string]$evtAction.Outcome
        if ($outcome -eq 'Executed') {
            # PostWriteEvidence can live at action level or be referenced by non-empty
            # PostWriteEvidence, TargetsAfter, or AfterState fields
            $hasPostWrite = $false
            if ($evtAction.PSObject.Properties['PostWriteEvidence'] -and $evtAction.PostWriteEvidence) {
                $hasPostWrite = $true
            }
            if (-not $hasPostWrite -and $evtAction.PSObject.Properties['TargetsAfter']) {
                $after = @($evtAction.TargetsAfter | Where-Object { $_ -and [string]$_ -ne '' })
                if ($after.Count -gt 0) { $hasPostWrite = $true }
            }
            if (-not $hasPostWrite -and $evtAction.PSObject.Properties['AfterState']) {
                $afterState = [string]$evtAction.AfterState
                if ($afterState -and $afterState.Trim() -ne '') { $hasPostWrite = $true }
            }
            if (-not $hasPostWrite) {
                $missingPostWrite.Add([string]$evtAction.ActionId)
            }
        }
    }

    if ($missingPostWrite.Count -eq 0) {
        $results.Add([pscustomobject]@{
            CheckName = 'ExecutedActionsHavePostWriteEvidence'
            Passed    = $true
            Message   = 'All Executed actions have a post-write evidence reference'
            Severity  = 'Info'
        })
    } else {
        $list = $missingPostWrite -join ', '
        $results.Add([pscustomobject]@{
            CheckName = 'ExecutedActionsHavePostWriteEvidence'
            Passed    = $false
            Message   = "Executed actions missing post-write evidence reference: $list"
            Severity  = 'Error'
        })
    }

    # ── Check 9: Skipped actions do not claim tenant write ────────────────────

    $skippedWithWrite = [System.Collections.Generic.List[string]]::new()
    foreach ($evtAction in $evidenceActions) {
        $outcome = [string]$evtAction.Outcome
        if ($outcome -eq 'Skipped') {
            $hasTenantWrite = $false
            if ($evtAction.PSObject.Properties['HasTenantWrite'] -and $evtAction.HasTenantWrite -eq $true) {
                $hasTenantWrite = $true
            }
            if ($hasTenantWrite) {
                $skippedWithWrite.Add([string]$evtAction.ActionId)
            }
        }
    }

    if ($skippedWithWrite.Count -eq 0) {
        $results.Add([pscustomobject]@{
            CheckName = 'SkippedActionsNoTenantWrite'
            Passed    = $true
            Message   = 'No Skipped actions claim a tenant write'
            Severity  = 'Info'
        })
    } else {
        $list = $skippedWithWrite -join ', '
        $results.Add([pscustomobject]@{
            CheckName = 'SkippedActionsNoTenantWrite'
            Passed    = $false
            Message   = "Skipped actions that claim HasTenantWrite=true: $list"
            Severity  = 'Error'
        })
    }

    # ── Check 10: ProtectedObject actions are Blocked, not Executed ───────────

    $protectedExecuted = [System.Collections.Generic.List[string]]::new()
    foreach ($evtAction in $evidenceActions) {
        $isProtected = $false
        if ($evtAction.PSObject.Properties['ProtectedObject'] -and $evtAction.ProtectedObject -eq $true) {
            $isProtected = $true
        }
        if ($isProtected) {
            $outcome = [string]$evtAction.Outcome
            if ($outcome -eq 'Executed') {
                $protectedExecuted.Add([string]$evtAction.ActionId)
            }
        }
    }

    if ($protectedExecuted.Count -eq 0) {
        $results.Add([pscustomobject]@{
            CheckName = 'ProtectedObjectsNotExecuted'
            Passed    = $true
            Message   = 'No ProtectedObject actions were executed (all are Blocked or non-Executed)'
            Severity  = 'Info'
        })
    } else {
        $list = $protectedExecuted -join ', '
        $results.Add([pscustomobject]@{
            CheckName = 'ProtectedObjectsNotExecuted'
            Passed    = $false
            Message   = "ProtectedObject actions that were Executed (must be Blocked): $list"
            Severity  = 'Error'
        })
    }

    return $results.ToArray()
}

function Export-DecomReplayValidationReportJson {
    <#
    .SYNOPSIS
    Exports the replay validation report to a JSON file.
    .PARAMETER ValidationResult
    The result object returned by Invoke-DecomReplayValidation.
    .PARAMETER OutputPath
    Directory path where the JSON file will be written.
    .OUTPUTS
    The full path of the written file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ValidationResult,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $runIdSafe = if ($ValidationResult.RunId) {
        $ValidationResult.RunId -replace '[^a-zA-Z0-9_\-]', ''
    } else { 'unknown' }

    $fileName = "replay-validation-report-$runIdSafe-$timestamp.json"
    $filePath = Join-Path $OutputPath $fileName

    $ValidationResult | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath -Encoding UTF8

    return $filePath
}

function Export-DecomReplayValidationReportMarkdown {
    <#
    .SYNOPSIS
    Exports the replay validation report to a Markdown file.
    .PARAMETER ValidationResult
    The result object returned by Invoke-DecomReplayValidation.
    .PARAMETER OutputPath
    Directory path where the Markdown file will be written.
    .OUTPUTS
    The full path of the written file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$ValidationResult,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $runIdSafe = if ($ValidationResult.RunId) {
        $ValidationResult.RunId -replace '[^a-zA-Z0-9_\-]', ''
    } else { 'unknown' }

    $fileName = "replay-validation-report-$runIdSafe-$timestamp.md"
    $filePath = Join-Path $OutputPath $fileName

    $overallStr = if ($ValidationResult.Status -eq 'SkippedNoReplayInputs') {
        'SKIPPED'
    } elseif ($ValidationResult.Passed) {
        'PASS'
    } else {
        'FAIL'
    }

    $md = @"
# Replay Validation Report

**SchemaVersion:** $($ValidationResult.SchemaVersion)
**ToolVersion:** $($ValidationResult.ToolVersion)
**RunId:** $($ValidationResult.RunId)
**ValidatedUtc:** $($ValidationResult.ValidatedUtc)
**Result:** $overallStr

## Summary

| Metric | Value |
|--------|-------|
| Total Checks | $($ValidationResult.CheckCount) |
| Passed | $($ValidationResult.PassedChecks) |
| Failed | $($ValidationResult.FailedChecks) |

## Findings

| Check | Passed | Severity | Message |
|-------|--------|----------|---------|
"@

    foreach ($finding in $ValidationResult.Findings) {
        $passedStr = if ($finding.Passed) { 'Yes' } else { 'No' }
        $msg = [string]$finding.Message -replace '\|', '\\|'
        $md += "| $($finding.CheckName) | $passedStr | $($finding.Severity) | $msg |`n"
    }

    if ($ValidationResult.Warnings -and $ValidationResult.Warnings.Count -gt 0) {
        $md += "`n## Warnings`n`n"
        foreach ($w in $ValidationResult.Warnings) {
            $md += "- $w`n"
        }
    }

    $md += @"

---
(c) 2026 Albert Jee. All rights reserved.
"@

    $md | Set-Content -Path $filePath -Encoding UTF8

    return $filePath
}
