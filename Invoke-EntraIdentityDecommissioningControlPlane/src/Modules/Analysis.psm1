function Invoke-DecomAnalysis {
    param([object[]]$Findings)

    $protectedPatterns = @(
        'breakglass','break-glass','emergency','sync',
        'aadconnect','cloudsync','svc-','service-'
    )

    $processed = @(foreach ($finding in @($Findings)) {
        if ($null -eq $finding) { continue }

        $riskScore = if ($null -ne $finding.RiskScore) { [int]$finding.RiskScore } else { 0 }

        $severityFromScore = switch ($true) {
            ($riskScore -ge 80) { 'Critical';      break }
            ($riskScore -ge 60) { 'High';           break }
            ($riskScore -ge 40) { 'Medium';         break }
            ($riskScore -ge 25) { 'Low';            break }
            default             { 'Informational' }
        }

        if ($finding.Severity -ne $severityFromScore) {
            Write-DecomWarn "Finding $($finding.FindingId): severity '$($finding.Severity)' out of band for RiskScore $riskScore — clamping to '$severityFromScore'"
            $finding.Severity = $severityFromScore
        }

        $displayNameLower = if ($null -ne $finding.DisplayName) {
            [string]$finding.DisplayName.ToLowerInvariant()
        } else { '' }

        $upnLower = if ($null -ne $finding.UserPrincipalName) {
            [string]$finding.UserPrincipalName.ToLowerInvariant()
        } else { '' }

        $isProtected = $false
        foreach ($pattern in $protectedPatterns) {
            if ($displayNameLower -like "*$pattern*" -or $upnLower -like "*$pattern*") {
                $isProtected = $true
                break
            }
        }
        if ($isProtected) {
            $finding.ProtectedObject   = $true
            $finding.RemediationMode   = 'ProtectedObject'
            $finding.RecommendedAction = "Manual review required — protected object. Original action: $($finding.RecommendedAction)"
        }

        $finding
    })

    $severityOrder = @{ 'Critical' = 0; 'High' = 1; 'Medium' = 2; 'Low' = 3; 'Informational' = 4 }
    @($processed) | Sort-Object { $severityOrder[$_.Severity] }, { -$_.RiskScore }
}

function Get-DecomFindingSummary {
    param([object[]]$Findings)
    [ordered]@{
        Critical      = @($Findings | Where-Object Severity -eq 'Critical').Count
        High          = @($Findings | Where-Object Severity -eq 'High').Count
        Medium        = @($Findings | Where-Object Severity -eq 'Medium').Count
        Low           = @($Findings | Where-Object Severity -eq 'Low').Count
        Informational = @($Findings | Where-Object Severity -eq 'Informational').Count
        Total         = ($Findings | Measure-Object).Count
    }
}
