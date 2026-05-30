function Export-DecomRemediationPlan {
    param([object[]]$Findings, [string]$Path, [pscustomobject]$Context)

    $clientName  = if ($Context.ClientName)   { $Context.ClientName }   else { 'Not specified' }
    $engId       = if ($Context.EngagementId) { $Context.EngagementId } else { 'Not specified' }
    $assessor    = if ($Context.Assessor)     { $Context.Assessor }     else { 'Not specified' }
    $runDate     = Get-Date -Format 'yyyy-MM-dd HH:mm:ss UTC'
    $modeDisplay = $Context.Mode

    $safeFindings = @($Findings | Where-Object { $null -ne $_ })

    $header = @"
# Entra Identity Decommissioning — Remediation Plan
## Rev1.2 Consultant Readiness

| Field           | Value             |
|-----------------|-------------------|
| Client          | $clientName       |
| Engagement ID   | $engId            |
| Assessor        | $assessor         |
| Assessment Date | $runDate          |
| Mode            | $modeDisplay      |

> **Safety Note:** This plan documents recommended remediation actions identified during an Assessment-mode run.
> This plan does not execute any actions. All remediation requires manual review and explicit approval before execution.

---

"@

    # --- Immediate Actions (Critical + High) ---
    $critHighItems = @($safeFindings |
        Where-Object { $_.Severity -in 'Critical','High' } |
        Sort-Object { -$_.RiskScore })

    $immediateBlocks = [System.Text.StringBuilder]::new()
    $null = $immediateBlocks.Append("## Immediate Actions (Critical + High)`n`n")

    if ($critHighItems.Count -eq 0) {
        $null = $immediateBlocks.Append("_No Critical or High findings identified._`n`n---`n`n")
    } else {
        $n = 1
        foreach ($finding in $critHighItems) {
            $actionId = "ACT-{0:D3}" -f $n
            $null = $immediateBlocks.Append(@"
### $actionId — $($finding.FindingId): $($finding.DisplayName)

| Field                | Value                                                            |
|----------------------|------------------------------------------------------------------|
| Action ID            | $actionId                                                        |
| Finding ID           | $($finding.FindingId)                                            |
| Severity             | $($finding.Severity) (Risk Score: $($finding.RiskScore))         |
| Object Type          | $($finding.ObjectType)                                           |
| Object ID            | $($finding.ObjectId)                                             |
| Display Name         | $($finding.DisplayName)                                          |
| Evidence             | $($finding.Evidence)                                             |
| Recommended Action   | $($finding.RecommendedAction)                                    |
| Business Owner       | [To be confirmed]                                                |
| Approval Required    | Yes                                                              |
| Approval Status      | PendingReview                                                    |
| Execution Command    | [Requires ExecuteRemediation mode — not generated in Assessment] |
| Rollback Note        | [Document current state before execution]                        |
| Evidence Reference   | $($finding.FindingId)                                            |

---

"@)
            $n++
        }
    }

    # --- Review Queue (Medium) ---
    $mediumItems = @($safeFindings |
        Where-Object { $_.Severity -eq 'Medium' } |
        Sort-Object { -$_.RiskScore })

    $reviewBlocks = [System.Text.StringBuilder]::new()
    $null = $reviewBlocks.Append("## Review Queue (Medium)`n`n")

    if ($mediumItems.Count -eq 0) {
        $null = $reviewBlocks.Append("_No Medium findings identified._`n`n---`n`n")
    } else {
        $n = $critHighItems.Count + 1
        foreach ($finding in $mediumItems) {
            $actionId = "ACT-{0:D3}" -f $n
            $null = $reviewBlocks.Append(@"
### $actionId — $($finding.FindingId): $($finding.DisplayName)

| Field              | Value                                      |
|--------------------|--------------------------------------------|
| Action ID          | $actionId                                  |
| Finding ID         | $($finding.FindingId)                      |
| Severity           | Medium (Risk Score: $($finding.RiskScore)) |
| Object Type        | $($finding.ObjectType)                     |
| Display Name       | $($finding.DisplayName)                    |
| Evidence           | $($finding.Evidence)                       |
| Recommended Action | $($finding.RecommendedAction)              |
| Approval Status    | PendingReview                              |
| Consultant Note    | $($finding.ConsultantNote)                 |

---

"@)
            $n++
        }
    }

    # --- Monitor / Hygiene (Low + Informational) ---
    $monitorItems = @($safeFindings |
        Where-Object { $_.Severity -in 'Low','Informational' } |
        Sort-Object { -$_.RiskScore })

    $monitorBlock = [System.Text.StringBuilder]::new()
    $null = $monitorBlock.Append("## Monitor / Hygiene (Low + Informational)`n`n")

    if ($monitorItems.Count -eq 0) {
        $null = $monitorBlock.Append("_No Low or Informational findings identified._`n`n")
    } else {
        $null = $monitorBlock.Append("| FindingId | DisplayName | Evidence |`n")
        $null = $monitorBlock.Append("|-----------|-------------|----------|`n")
        foreach ($finding in $monitorItems) {
            $null = $monitorBlock.Append("| $($finding.FindingId) | $($finding.DisplayName) | $($finding.Evidence) |`n")
        }
        $null = $monitorBlock.Append("`n")
    }

    $footer = @"
---

## Notes

- All Immediate Actions and Review Queue items require explicit client approval before execution.
- This plan was generated by Entra Identity Decommissioning Control Plane Rev1.2.
- For questions about this plan, contact the assessor listed above.
- To execute approved remediation actions, re-run the tool with ``-Mode ExecuteRemediation`` after obtaining approvals (future release).

*Entra Identity Decommissioning Control Plane Rev1.2 — Consultant Advisory Tool*
"@

    $content = $header + $immediateBlocks.ToString() + $reviewBlocks.ToString() + $monitorBlock.ToString() + $footer
    Set-Content -Path $Path -Value $content -Encoding UTF8
}
