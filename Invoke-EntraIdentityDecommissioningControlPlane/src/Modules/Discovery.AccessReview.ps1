function _Get-DecomAccessReviewData {
    param(
        [System.Collections.Generic.List[object]]$findings,
        $coverage,
        [System.Collections.Generic.HashSet[string]]$emittedRev23
    )
    # --- Rev2.3 M2: Access review data collection -->
    $govApiAvailable    = $false
    $accessReviewData   = $null
    $arDefinitions      = @()
    $arInstances        = @()
    $arDecisions        = @()

    $accessReviewCapabilityKey = 'AccessReviews.Unavailable'
    $arDefCmdlet = $null

    if (Test-DecomCapabilityAvailable -Key $accessReviewCapabilityKey) {
        $arDefCmdlet = Get-DecomAvailableCommand -Names @(
            'Get-MgIdentityGovernanceAccessReviewDefinition',
            'Get-MgAccessReviewDefinition'
        )
    }

    if ($null -eq $arDefCmdlet) {
        $null = Set-DecomCapabilityUnavailable -Key $accessReviewCapabilityKey -Message 'Access review definition cmdlet unavailable in installed Graph module'
        $govApiAvailable = $false
        $govKey = 'DEC-GOV-002|tenant-scope'
        if ($emittedRev23.Add($govKey)) {
            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-GOV-002' `
                -Category          'Governance' `
                -Severity          'Informational' `
                -RiskScore         16 `
                -Confidence        'Low' `
                -ObjectType        'TenantScope' `
                -ObjectId          'tenant-scope' `
                -DisplayName       'Access Review Cmdlet Coverage' `
                -UserPrincipalName '' `
                -Evidence          'Access review cmdlet (Get-MgIdentityGovernanceAccessReviewDefinition) is not available in the installed Graph module version.' `
                -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                -RecommendedAction 'Upgrade Microsoft.Graph.Identity.Governance module and re-run assessment to enable access review coverage.' `
                -RemediationMode   'InformationOnly' `
                -ConsultantNote    'Module version gap — cmdlet not available in current Graph module'))
        }
    } else {
        try {
            $arDefinitions = @(& $arDefCmdlet -All -ErrorAction Stop)
            $coverage.AccessReviews           = $true
            $coverage.AccessReviewDefinitions = $true
            Write-DecomInfo "Access review definition discovery: OK ($($arDefinitions.Count) definitions)"
            $govApiAvailable  = $true
            $accessReviewData = [PSCustomObject]@{ Definitions=$arDefinitions; Instances=@(); Decisions=@() }

            # Try to collect instances
            $arInstCmdlet = Get-DecomAvailableCommand -Names @(
                'Get-MgIdentityGovernanceAccessReviewDefinitionInstance',
                'Get-MgAccessReviewDefinitionInstance'
            )
            if ($null -ne $arInstCmdlet -and $arDefinitions.Count -gt 0) {
                $allInstances = [System.Collections.Generic.List[object]]::new()
                foreach ($def in $arDefinitions) {
                    try {
                        $defInst = @(& $arInstCmdlet -AccessReviewScheduleDefinitionId $def.Id -All -ErrorAction Stop)
                        foreach ($inst in $defInst) { $allInstances.Add($inst) }
                    } catch {
                        Write-DecomWarn "Access review instance collection failed for definition $($def.Id): $_"
                    }
                }
                $arInstances = @($allInstances)
                $coverage.AccessReviewInstances = $true
                $accessReviewData.Instances = $arInstances
                Write-DecomInfo "Access review instance discovery: OK ($($arInstances.Count) instances)"
            }

            # Try to collect decisions
            $arDecCmdlet = Get-DecomAvailableCommand -Names @(
                'Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision',
                'Get-MgAccessReviewDefinitionInstanceDecision'
            )
            if ($null -ne $arDecCmdlet -and $arInstances.Count -gt 0) {
                $allDecisions = [System.Collections.Generic.List[object]]::new()
                foreach ($def in $arDefinitions) {
                    foreach ($inst in ($arInstances | Where-Object { $_.AccessReviewScheduleDefinitionId -eq $def.Id -or $null -ne $_ })) {
                        try {
                            $instId = if ($inst.Id) { $inst.Id } else { continue }
                            $decs = @(& $arDecCmdlet `
                                -AccessReviewScheduleDefinitionId $def.Id `
                                -AccessReviewInstanceId $instId `
                                -All -ErrorAction Stop)
                            foreach ($d in $decs) { $allDecisions.Add($d) }
                        } catch {
                            Write-DecomWarn "Access review decision collection failed: $_"
                        }
                    }
                }
                $arDecisions = @($allDecisions)
                $coverage.AccessReviewDecisions = $true
                $accessReviewData.Decisions = $arDecisions
                Write-DecomInfo "Access review decision discovery: OK ($($arDecisions.Count) decisions)"
            }

            # DEC-REV-001: Definitions exist but no decisions
            if ($arDefinitions.Count -gt 0 -and $arDecisions.Count -eq 0) {
                $rev001Key = 'DEC-REV-001|tenant-scope'
                if ($emittedRev23.Add($rev001Key)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-001' `
                        -Category          'Access Review Governance' `
                        -Severity          'Informational' `
                        -RiskScore         20 `
                        -Confidence        'Low' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          'tenant-scope' `
                        -DisplayName       'Access Review Decision Coverage' `
                        -UserPrincipalName '' `
                        -Evidence          "Access review definitions found ($($arDefinitions.Count)) but no review decision records returned — coverage may be partial or reviews newly configured." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                        -RecommendedAction 'Verify access review schedules are producing decisions; check reviewer assignments and completion status.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'No decisions recorded — review schedules may be new or incomplete'))
                }
            }

        } catch {
            $null = Set-DecomCapabilityUnavailable -Key $accessReviewCapabilityKey -Message "Access review data collection failed: $($_.Exception.Message)" -Error $_.Exception.Message
            $govApiAvailable = $false
            $govKey = 'DEC-GOV-002|tenant-scope'
            if ($emittedRev23.Add($govKey)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GOV-002' `
                    -Category          'Governance' `
                    -Severity          'Informational' `
                    -RiskScore         16 `
                    -Confidence        'Low' `
                    -ObjectType        'TenantScope' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'Access Review Cmdlet Coverage' `
                    -UserPrincipalName '' `
                    -Evidence          'Access review data collection failed — review governance coverage could not be assessed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction 'Verify AccessReview.Read.All permission and re-run assessment.' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Access review collection error'))
            }
        }
    }

    # DEC-GOV-001: Emit once if govApiAvailable is false (covers both cmdlet-unavailable and exception paths)
    if (-not $govApiAvailable) {
        $gov001Key = 'DEC-GOV-001|tenant-scope'
        if ($emittedRev23.Add($gov001Key)) {
            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-GOV-001' `
                -Category          'Governance' `
                -Severity          'Informational' `
                -RiskScore         18 `
                -Confidence        'Low' `
                -ObjectType        'TenantScope' `
                -ObjectId          'tenant-scope' `
                -DisplayName       'Access Review API Coverage' `
                -UserPrincipalName '' `
                -Evidence          'Access review API cmdlets unavailable — review governance coverage could not be assessed. AccessReview.Read.All permission may be missing.' `
                -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                -RecommendedAction 'Grant AccessReview.Read.All permission and re-run assessment to enable access review governance coverage.' `
                -RemediationMode   'InformationOnly' `
                -ConsultantNote    'Coverage gap — access review API not available in this environment'))
        }
    }

    # DEC-GOV-003: Licensing may limit evidence coverage — emit when API available but 0 definitions returned
    if ($govApiAvailable -and $arDefinitions.Count -eq 0) {
        $gov003Key = 'DEC-GOV-003|tenant-scope'
        if ($emittedRev23.Add($gov003Key)) {
            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-GOV-003' `
                -Category          'Governance' `
                -Severity          'Informational' `
                -RiskScore         14 `
                -Confidence        'Low' `
                -ObjectType        'TenantScope' `
                -ObjectId          'tenant-scope' `
                -DisplayName       'Access Review Licensing Coverage' `
                -UserPrincipalName '' `
                -Evidence          'Access review API cmdlet is available but returned 0 review definitions. Entra ID Governance licensing (P2 or Governance SKU) may be absent or limited.' `
                -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                -RecommendedAction 'Verify Entra ID Governance or P2 licensing is assigned and access review definitions exist before concluding no reviews are configured.' `
                -RemediationMode   'InformationOnly' `
                -ConsultantNote    'Zero definitions returned — licensing gap or reviews not yet configured'))
        }
    }

    return [PSCustomObject]@{
        GovApiAvailable  = $govApiAvailable
        AccessReviewData = $accessReviewData
        ArDefinitions    = $arDefinitions
        ArInstances      = $arInstances
        ArDecisions      = $arDecisions
    }
}
