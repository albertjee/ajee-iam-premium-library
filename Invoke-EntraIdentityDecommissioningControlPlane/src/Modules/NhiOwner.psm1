#Requires -Version 5.1

Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function Invoke-NhiOwnerScan {
    [CmdletBinding()]
    param(
        [object[]]$ServicePrincipals,
        [hashtable]$OwnersByObjectId,
        [bool]$OwnerLookupSucceeded = $true,
        [string]$OwnerLookupError   = ''
    )

    $findings = @()

    # OWNER-003 coverage-mode: if lookup failed globally (no data for any SP),
    # emit ONE assessment-level finding only.
    $hasAnyOwnerData = $false
    foreach ($sp in $ServicePrincipals) {
        if ($OwnersByObjectId -and $OwnersByObjectId.ContainsKey($sp.Id) -and
            $OwnersByObjectId[$sp.Id] -and $OwnersByObjectId[$sp.Id].Count -gt 0) {
            $hasAnyOwnerData = $true
            break
        }
    }

    foreach ($sp in $ServicePrincipals) {
        $null = Set-DecomFindingTraceContext -SourceObject $sp -ClassificationSource 'NhiOwner'
        $owners = @()
        if ($OwnersByObjectId -and $OwnersByObjectId.ContainsKey($sp.Id)) {
            $owners = @($OwnersByObjectId[$sp.Id])
        }
        $ownerCount = $owners.Count

        # NHI-OWNER-001: No owner
        if ($ownerCount -eq 0 -and $OwnerLookupSucceeded) {
            $findings += New-DecomFinding `
                -FindingId 'NHI-OWNER-001' `
                -Category 'Identity Governance' `
                -Severity 'High' `
                -RiskScore 65 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence 'Service principal has no owner assigned' `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/owners" `
                -RecommendedAction 'Assign an owner to this service principal using AddApplicationOwner action' `
                -RemediationMode 'ManualApprovalRequired' `
                -ConsultantNote 'No owner accountability - escalate to application owner'
        }

        # NHI-OWNER-002: Single owner (mutually exclusive with OWNER-001)
        if ($ownerCount -eq 1 -and $OwnerLookupSucceeded) {
            $findings += New-DecomFinding `
                -FindingId 'NHI-OWNER-002' `
                -Category 'Identity Governance' `
                -Severity 'Medium' `
                -RiskScore 30 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $sp.Id `
                -DisplayName $sp.DisplayName `
                -Evidence "Service principal has exactly one owner ($($owners[0].Id)) - single point of failure" `
                -EvidenceSource 'graph' `
                -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/owners" `
                -RecommendedAction 'Assign additional owner for redundancy' `
                -RemediationMode 'InformationOnly' `
                -ConsultantNote 'Single owner increases risk of lockout'
        }

        # NHI-OWNER-004: Guest owner
        foreach ($owner in $owners) {
            if ($owner.UserType -eq 'Guest') {
                $findings += New-DecomFinding `
                    -FindingId 'NHI-OWNER-004' `
                    -Category 'Identity Governance' `
                    -Severity 'Medium' `
                    -RiskScore 35 `
                    -Confidence 'High' `
                    -ObjectType 'ServicePrincipal' `
                    -ObjectId $sp.Id `
                    -DisplayName $sp.DisplayName `
                    -Evidence "Service principal has a guest user as owner: $($owner.Id)" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/owners" `
                    -RecommendedAction 'Review guest owner necessity; document business justification or replace with member account' `
                    -RemediationMode 'InformationOnly' `
                    -ConsultantNote 'Guest owner external to tenant - review access requirements'
                break  # one finding per SP for guest owner
            }
        }

        # NHI-OWNER-005: Disabled owner
        foreach ($owner in $owners) {
            if ($null -ne $owner.AccountEnabled -and $owner.AccountEnabled -eq $false) {
                $findings += New-DecomFinding `
                    -FindingId 'NHI-OWNER-005' `
                    -Category 'Identity Governance' `
                    -Severity 'High' `
                    -RiskScore 55 `
                    -Confidence 'High' `
                    -ObjectType 'ServicePrincipal' `
                    -ObjectId $sp.Id `
                    -DisplayName $sp.DisplayName `
                    -Evidence "Service principal has a disabled account as owner: $($owner.Id)" `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/owners" `
                    -RecommendedAction 'Replace disabled owner with active account; decommission disabled account ifunused' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -ConsultantNote 'Disabled owner blocks ownership actions - immediate risk'
                break  # one finding per SP for disabled owner
            }
        }

        # NHI-OWNER-006: All owners are service principals (no human owner)
        # Only fires when at least one owner exists
        if ($ownerCount -ge 1 -and $OwnerLookupSucceeded) {
            $allSpOwners = $true
            foreach ($owner in $owners) {
                if ($owner.ObjectType -ne 'ServicePrincipal') {
                    $allSpOwners = $false
                    break
                }
            }
            if ($allSpOwners) {
                $findings += New-DecomFinding `
                    -FindingId 'NHI-OWNER-006' `
                    -Category 'Identity Governance' `
                    -Severity 'High' `
                    -RiskScore 50 `
                    -Confidence 'High' `
                    -ObjectType 'ServicePrincipal' `
                    -ObjectId $sp.Id `
                    -DisplayName $sp.DisplayName `
                    -Evidence 'All owners are service principals - no human owner accountability' `
                    -EvidenceSource 'graph' `
                    -GraphEndpoint "https://graph.microsoft.com/v1.0/servicePrincipals/$($sp.Id)/owners" `
                    -RecommendedAction 'Assign a human owner from the business unit that owns this service principal' `
                    -RemediationMode 'ManualApprovalRequired' `
                    -ConsultantNote 'Service principal owners create circular accountability'
            }
        }
    }

    # NHI-OWNER-003: Lookup failed - emit ONCE as assessment-level finding
    # Only when lookup was globally unavailable (not per-SP)
    Clear-DecomFindingTraceContext
    if (-not $OwnerLookupSucceeded -and -not $hasAnyOwnerData) {
        $findings += New-DecomFinding `
            -FindingId 'NHI-OWNER-003' `
            -Category 'Identity Governance' `
            -Severity 'Medium' `
            -RiskScore 20 `
            -Confidence 'Low' `
            -ObjectType 'Assessment' `
            -ObjectId 'NHI-OWNER-003-COVERAGE' `
            -DisplayName 'Owner Data Unavailable' `
            -Evidence "Owner lookup failed globally for this run. Owner data unavailable for the full tenant. Error: $OwnerLookupError" `
            -EvidenceSource 'graph' `
            -GraphEndpoint 'https://graph.microsoft.com/v1.0/servicePrincipals/{id}/owners' `
            -RecommendedAction 'Verify Microsoft Graph permissions: Directory.Read.All or Owner.Read.All required. Ensure app registration has appropriate Graph permissions.' `
            -RemediationMode 'InformationOnly' `
            -ConsultantNote 'Coverage gap - owner-based findings are dormant for this run. All NHI-OWNER findings suppressed due to data unavailability.'
    }

    Clear-DecomFindingTraceContext
    return $findings
}

Export-ModuleMember -Function Invoke-NhiOwnerScan
