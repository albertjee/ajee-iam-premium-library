function Invoke-DecomAnalysis {
    param([object[]]$Findings)

    $protectedPatterns = @(
        'breakglass','break-glass','emergency','sync',
        'aadconnect','cloudsync','svc-','service-'
    )

    $processed = @(foreach ($finding in @($Findings)) {
        $severityFromScore = switch ($true) {
            ($finding.RiskScore -ge 80) { 'Critical';      break }
            ($finding.RiskScore -ge 60) { 'High';           break }
            ($finding.RiskScore -ge 40) { 'Medium';         break }
            ($finding.RiskScore -ge 25) { 'Low';            break }
            default                     { 'Informational' }
        }

        if ($finding.Severity -ne $severityFromScore) {
            Write-DecomWarn "Finding $($finding.FindingId): severity '$($finding.Severity)' out of band for RiskScore $($finding.RiskScore) — clamping to '$severityFromScore'"
            $finding.Severity = $severityFromScore
        }

        $displayNameLower = $finding.DisplayName.ToLower()
        $upnLower         = $finding.UserPrincipalName.ToLower()
        $isProtected = $false
        foreach ($pattern in $protectedPatterns) {
            if ($displayNameLower -like "*$pattern*" -or $upnLower -like "*$pattern*") {
                $isProtected = $true
                break
            }
        }
        if ($isProtected) { $finding.ProtectedObject = $true }

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
