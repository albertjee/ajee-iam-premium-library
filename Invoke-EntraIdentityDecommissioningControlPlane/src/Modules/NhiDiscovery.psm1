#Requires -Version 5.1

$script:HighRiskAppPermissions = @(
    'Directory.ReadWrite.All', 'Application.ReadWrite.All', 'AppRoleAssignment.ReadWrite.All',
    'RoleManagement.ReadWrite.Directory', 'PrivilegedAccess.ReadWrite.AzureAD',
    'Group.ReadWrite.All', 'User.ReadWrite.All', 'Mail.ReadWrite', 'Mail.Send',
    'Files.ReadWrite.All', 'Sites.FullControl.All', 'AuditLog.Read.All',
    'Policy.ReadWrite.All', 'EntitlementManagement.ReadWrite.All'
)

$script:HighRiskDelegatedScopes = @(
    'Directory.AccessAsUser.All', 'Directory.ReadWrite.All', 'Application.ReadWrite.All',
    'AppRoleAssignment.ReadWrite.All', 'User.Read.All', 'User.ReadWrite.All', 'Group.ReadWrite.All',
    'Mail.ReadWrite', 'Mail.Send', 'Files.ReadWrite.All', 'Sites.FullControl.All', 'offline_access'
)

function Get-DecomNhiServicePrincipals {
    param([pscustomobject]$Context)
    if ($Context -and $Context.DemoMode) { return @() }
    try {
        Get-MgServicePrincipal -All -Property 'id,appId,displayName,servicePrincipalType,publisherName,verifiedPublisher,signInAudience,accountEnabled,createdDateTime,tags,homepage,appOwnerOrganizationId,appRoles,keyCredentials,passwordCredentials' -ErrorAction Stop
    } catch { Write-Warning "NHI SP collection failed: $_"; return @() }
}

function Get-DecomNhiApplications {
    param([pscustomobject]$Context)
    if ($Context -and $Context.DemoMode) { return @() }
    try {
        Get-MgApplication -All -Property 'id,appId,displayName,signInAudience,createdDateTime,tags,homepage,publisherDomain,verifiedPublisher,keyCredentials,passwordCredentials' -ErrorAction Stop
    } catch { Write-Warning "NHI App collection failed: $_"; return @() }
}

function Get-DecomNhiOwners {
    param([string]$ObjectId, [string]$ObjectType = 'ServicePrincipal')
    if ($ObjectType -eq 'Application') {
        Get-MgApplicationOwner -ApplicationId $ObjectId -ErrorAction Stop
    } else {
        Get-MgServicePrincipalOwner -ServicePrincipalId $ObjectId -ErrorAction Stop
    }
}

function Get-DecomNhiCredentials {
    param([pscustomobject]$ServicePrincipalOrApp)
    $creds = @()
    if ($ServicePrincipalOrApp.KeyCredentials) { $creds += $ServicePrincipalOrApp.KeyCredentials }
    if ($ServicePrincipalOrApp.PasswordCredentials) { $creds += $ServicePrincipalOrApp.PasswordCredentials }
    return $creds
}

function Get-DecomNhiAppRoleAssignments {
    param([string]$ServicePrincipalId)
    Get-MgServicePrincipalAppRoleAssignment -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
}

function Get-DecomNhiOAuthGrants {
    param([string]$ServicePrincipalId)
    Get-MgServicePrincipalOauth2PermissionGrant -ServicePrincipalId $ServicePrincipalId -ErrorAction Stop
}

function Get-DecomNhiPublisherVerification {
    param([string]$PublisherName, [pscustomobject]$VerifiedPublisher)
    if (-not $VerifiedPublisher) { return $false }
    return $VerifiedPublisher.DisplayName -eq $PublisherName
}

function Get-DecomNhiHighRiskPermissions {
    param([object[]]$AppRoleAssignments, [object[]]$OAuthGrants)
    $hits = @()
    foreach ($a in $AppRoleAssignments) {
        if ($a.AdditionalProperties -and ($script:HighRiskAppPermissions | Where-Object { $a.AdditionalProperties.appRoleId -eq $_ })) {
            $hits += $a
        }
    }
    foreach ($g in $OAuthGrants) {
        $scopes = $g.Scope -split ' '
        foreach ($s in $scopes) {
            if ($s -in $script:HighRiskDelegatedScopes) { $hits += $g; break }
        }
    }
    return $hits
}

function New-DecomNhiSyntheticData {
    $now = Get-Date
    return [PSCustomObject]@{
        ServicePrincipals = @(
            [PSCustomObject]@{
                Id = 'sp-001'; AppId = 'app-001'; DisplayName = 'contoso-serviceidentity-prod'
                ServicePrincipalType = 'ServiceIdentity'; PublisherName = 'Contoso Corp'
                VerifiedPublisher = $null; AccountEnabled = $true; Tags = @()
                AppOwnerOrganizationId = 'tenant-001'
                AdditionalProperties = @{}
                Credentials = @()
                Owners = @()
                AppRoleAssignments = @()
                OAuthGrants = @()
            },
            [PSCustomObject]@{
                Id = 'sp-002'; AppId = 'app-002'; DisplayName = 'copilot-hr-automation'
                ServicePrincipalType = 'Application'; PublisherName = 'Contoso Corp'
                VerifiedPublisher = $null; AccountEnabled = $true; Tags = @()
                AppOwnerOrganizationId = 'tenant-001'
                AdditionalProperties = @{}
                Credentials = @([PSCustomObject]@{ KeyId = 'key-expired-001'; EndDateTime = $now.AddYears(-1).ToString('o') })
                Owners = @()
                AppRoleAssignments = @([PSCustomObject]@{ PrincipalId = 'sp-002'; AdditionalProperties = @{ appRoleId = 'Directory.ReadWrite.All' } })
                OAuthGrants = @()
            },
            [PSCustomObject]@{
                Id = 'sp-003'; AppId = 'app-003'; DisplayName = 'workflow-runner-payroll'
                ServicePrincipalType = 'Application'; PublisherName = 'Contoso Corp'
                VerifiedPublisher = $null; AccountEnabled = $true; Tags = @()
                AppOwnerOrganizationId = 'tenant-001'
                AdditionalProperties = @{}
                Credentials = @()
                Owners = @([PSCustomObject]@{ Id = 'owner-001'; DisplayName = 'Jane Smith' })
                AppRoleAssignments = @()
                OAuthGrants = @([PSCustomObject]@{ ClientId = 'sp-003'; ConsentType = 'AllPrincipals'; Scope = 'Mail.Send offline_access' })
            },
            [PSCustomObject]@{
                Id = 'sp-004'; AppId = 'app-004'; DisplayName = 'Microsoft Graph'
                ServicePrincipalType = 'Application'; PublisherName = 'Microsoft Corporation'
                VerifiedPublisher = [PSCustomObject]@{ DisplayName = 'Microsoft' }
                AccountEnabled = $true; Tags = @()
                AppOwnerOrganizationId = 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
                AdditionalProperties = @{}
                Credentials = @()
                Owners = @()
                AppRoleAssignments = @()
                OAuthGrants = @()
            }
        )
        Applications = @()
    }
}

function Invoke-DecomNhiDiscovery {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Context
    )

    Write-DecomInfo "Starting NHI discovery..."

    # Initialize collections
    $servicePrincipals = @()
    $applications = @()
    $nhiFindings = @()

    if ($Context.DemoMode) {
        Write-DecomInfo "DemoMode: Using synthetic NHI data"
        $syntheticData = New-DecomNhiSyntheticData
        $servicePrincipals = $syntheticData.ServicePrincipals
        $applications = $syntheticData.Applications
    } else {
        # Collect real service principals
        Write-DecomInfo "Collecting service principals..."
        $servicePrincipals = Get-DecomNhiServicePrincipals -Context $Context

        # Collect real applications
        Write-DecomInfo "Collecting applications..."
        $applications = Get-DecomNhiApplications -Context $Context
    }

    # Process service principals
    Write-DecomInfo "Processing $($servicePrincipals.Count) service principals..."
    foreach ($sp in $servicePrincipals) {
        try {
            $riskUnderstated = $false
            $coverageNotes   = @()

            # In DemoMode, use pre-populated synthetic data fields; in real mode, call Graph
            if ($Context.DemoMode -and ($sp.PSObject.Properties.Name -contains 'Owners')) {
                $owners             = if ($sp.Owners)             { $sp.Owners }             else { @() }
                $credentials        = if ($sp.Credentials)        { $sp.Credentials }        else { @() }
                $appRoleAssignments = if ($sp.AppRoleAssignments) { $sp.AppRoleAssignments } else { @() }
                $oauthGrants        = if ($sp.OAuthGrants)        { $sp.OAuthGrants }        else { @() }
            } else {
                try {
                    $owners = @(Get-DecomNhiOwners -ObjectId $sp.Id -ObjectType 'ServicePrincipal')
                } catch {
                    $owners = @()
                    $riskUnderstated = $true
                    $coverageNotes += 'Owner data unavailable'
                }

                $credentials = Get-DecomNhiCredentials -ServicePrincipalOrApp $sp

                try {
                    $appRoleAssignments = @(Get-DecomNhiAppRoleAssignments -ServicePrincipalId $sp.Id)
                } catch {
                    $appRoleAssignments = @()
                    $riskUnderstated = $true
                    $coverageNotes += 'App role assignment data unavailable'
                }

                try {
                    $oauthGrants = @(Get-DecomNhiOAuthGrants -ServicePrincipalId $sp.Id)
                } catch {
                    $oauthGrants = @()
                    $riskUnderstated = $true
                    $coverageNotes += 'OAuth grant data unavailable'
                }
            }
            $highRiskPermissions = Get-DecomNhiHighRiskPermissions -AppRoleAssignments $appRoleAssignments -OAuthGrants $oauthGrants
            $normalizedIdentity = Get-DecomNormalizedNhiIdentity -InputObject $sp
            $isVerifiedPublisher = Get-DecomNhiPublisherVerification -PublisherName $normalizedIdentity.PublisherName -VerifiedPublisher $sp.VerifiedPublisher
            $platformClassification = Test-DecomMicrosoftPlatformIdentity -NhiObject $sp

            # Build NHI object
            $nhiObject = [PSCustomObject]@{
                # Basic identification
                ObjectId = $sp.Id
                AppId = $sp.AppId
                DisplayName = if ($normalizedIdentity.DisplayName) { $normalizedIdentity.DisplayName } else { $sp.DisplayName }
                AppDisplayName = $normalizedIdentity.AppDisplayName
                ObjectType = 'ServicePrincipal'
                ServicePrincipalType = if ($normalizedIdentity.ServicePrincipalType) { $normalizedIdentity.ServicePrincipalType } else { $sp.servicePrincipalType }

                # Publisher info
                PublisherName = $normalizedIdentity.PublisherName
                VerifiedPublisherName = $normalizedIdentity.VerifiedPublisherName
                IsVerifiedPublisher = $isVerifiedPublisher

                # Other properties
                SignInAudience = $sp.signInAudience
                AccountEnabled = $sp.accountEnabled
                CreatedDateTime = $sp.createdDateTime
                Tags = $normalizedIdentity.Tags
                Homepage = $sp.homepage
                AppOwnerOrganizationId = $normalizedIdentity.AppOwnerOrganizationId

                # Classification (to be filled by analysis)
                NhiCandidate = $false
                AgenticCandidate = $false
                AutomationCandidate = $false
                WorkloadCandidate = $false
                Classification = 'UnclassifiedServicePrincipal'
                ClassificationConfidence = 'Unknown'
                ClassificationSignals = @()
                ClassificationSource = 'Discovery/ServicePrincipal'
                ClassificationScore = 0
                MicrosoftPlatformReason = $platformClassification.Reason
                NormalizedAppId = $normalizedIdentity.AppId
                NormalizedPublisherName = $normalizedIdentity.PublisherName
                NormalizedVerifiedPublisherName = $normalizedIdentity.VerifiedPublisherName
                NormalizedAppOwnerOrganizationId = $normalizedIdentity.AppOwnerOrganizationId
                NormalizedServicePrincipalType = $normalizedIdentity.ServicePrincipalType
                NormalizedTags = $normalizedIdentity.Tags

                # Evidence and risk
                OwnerCount = $owners.Count
                CredentialCount = $credentials.Count
                ExpiredCredentialCount = 0  # Will be calculated in analysis
                ExpiringCredentialCount = 0  # Will be calculated in analysis
                HighRiskPermissionCount = $highRiskPermissions.Count
                HighRiskOAuthGrantCount = 0  # Will be calculated in analysis
                TenantWideConsent = $false  # Will be calculated in analysis
                FirstPartyMicrosoftApp = $platformClassification.MicrosoftFirstParty
                MicrosoftFirstParty = $platformClassification.MicrosoftFirstParty
                MicrosoftPlatform = $platformClassification.MicrosoftPlatform
                SuppressCustomerRemediation = $platformClassification.SuppressCustomerRemediation

                # Risk and coverage
                RiskScore = 0  # Will be calculated in analysis
                Severity = 'Informational'
                CoverageMode = 'Full'
                CoverageLimitations = $coverageNotes
                RiskScoreMayBeUnderstated = $riskUnderstated
                EvidenceSource = 'graph'
                EvidenceConfidence = 'High'

                # Raw data for correlation
                RawServicePrincipal = $sp
                RawOwners = $owners
                RawCredentials = $credentials
                RawAppRoleAssignments = $appRoleAssignments
                RawOAuthGrants = $oauthGrants
                RawHighRiskPermissions = $highRiskPermissions
            }

            $nhiFindings += $nhiObject
        } catch {
            Write-Warning "Failed to process service principal $($sp.DisplayName): $_"
        }
    }

    # Process applications (similar structure)
    Write-DecomInfo "Processing $($applications.Count) applications..."
    foreach ($app in $applications) {
        try {
            # Get related data
            $owners = Get-DecomNhiOwners -ObjectId $app.Id -ObjectType 'Application'
            $credentials = Get-DecomNhiCredentials -ServicePrincipalOrApp $app
            # Note: Applications don't have app role assignments or OAuth grants in the same way
            $appRoleAssignments = @()
            $oauthGrants = @()
            $highRiskPermissions = @()
            $normalizedIdentity = Get-DecomNormalizedNhiIdentity -InputObject $app
            $isVerifiedPublisher = Get-DecomNhiPublisherVerification -PublisherName $normalizedIdentity.PublisherName -VerifiedPublisher $app.VerifiedPublisher
            $platformClassification = Test-DecomMicrosoftPlatformIdentity -NhiObject $app

            # Build NHI object
            $nhiObject = [PSCustomObject]@{
                # Basic identification
                ObjectId = $app.Id
                AppId = $app.AppId
                DisplayName = if ($normalizedIdentity.DisplayName) { $normalizedIdentity.DisplayName } else { $app.DisplayName }
                AppDisplayName = $normalizedIdentity.AppDisplayName
                ObjectType = 'Application'
                ServicePrincipalType = $null  # Applications don't have service principal type

                # Publisher info
                PublisherName = $normalizedIdentity.PublisherName
                VerifiedPublisherName = $normalizedIdentity.VerifiedPublisherName
                IsVerifiedPublisher = $isVerifiedPublisher

                # Other properties
                SignInAudience = $app.signInAudience
                AccountEnabled = $true  # Applications don't have disabled state in Graph
                CreatedDateTime = $app.createdDateTime
                Tags = $normalizedIdentity.Tags
                Homepage = $app.homepage
                AppOwnerOrganizationId = $normalizedIdentity.AppOwnerOrganizationId

                # Classification (to be filled by analysis)
                NhiCandidate = $false
                AgenticCandidate = $false
                AutomationCandidate = $false
                WorkloadCandidate = $false
                Classification = 'UnclassifiedApplication'
                ClassificationConfidence = 'Unknown'
                ClassificationSignals = @()
                ClassificationSource = 'Discovery/Application'
                ClassificationScore = 0
                MicrosoftPlatformReason = $platformClassification.Reason
                NormalizedAppId = $normalizedIdentity.AppId
                NormalizedPublisherName = $normalizedIdentity.PublisherName
                NormalizedVerifiedPublisherName = $normalizedIdentity.VerifiedPublisherName
                NormalizedAppOwnerOrganizationId = $normalizedIdentity.AppOwnerOrganizationId
                NormalizedServicePrincipalType = $normalizedIdentity.ServicePrincipalType
                NormalizedTags = $normalizedIdentity.Tags

                # Evidence and risk
                OwnerCount = $owners.Count
                CredentialCount = $credentials.Count
                ExpiredCredentialCount = 0  # Will be calculated in analysis
                ExpiringCredentialCount = 0  # Will be calculated in analysis
                HighRiskPermissionCount = 0  # Applications don't have app role assignments
                HighRiskOAuthGrantCount = 0  # Will be calculated in analysis
                TenantWideConsent = $false  # Will be calculated in analysis
                FirstPartyMicrosoftApp = $platformClassification.MicrosoftFirstParty
                MicrosoftFirstParty = $platformClassification.MicrosoftFirstParty
                MicrosoftPlatform = $platformClassification.MicrosoftPlatform
                SuppressCustomerRemediation = $platformClassification.SuppressCustomerRemediation

                # Risk and coverage
                RiskScore = 0  # Will be calculated in analysis
                Severity = 'Informational'
                CoverageMode = 'Full'
                CoverageLimitations = @()
                RiskScoreMayBeUnderstated = $false
                EvidenceSource = 'graph'
                EvidenceConfidence = 'High'

                # Raw data for correlation
                RawApplication = $app
                RawOwners = $owners
                RawCredentials = $credentials
                RawAppRoleAssignments = $appRoleAssignments
                RawOAuthGrants = $oauthGrants
                RawHighRiskPermissions = $highRiskPermissions
            }

            $nhiFindings += $nhiObject
        } catch {
            Write-Warning "Failed to process application $($app.DisplayName): $_"
        }
    }

    Write-DecomOk "NHI discovery complete — $($nhiFindings.Count) NHI object(s) discovered"
    return $nhiFindings
}

Export-ModuleMember -Function Invoke-DecomNhiDiscovery, Get-DecomNhiServicePrincipals, Get-DecomNhiApplications, Get-DecomNhiOwners, Get-DecomNhiCredentials, Get-DecomNhiAppRoleAssignments, Get-DecomNhiOAuthGrants, Get-DecomNhiPublisherVerification, Get-DecomNhiHighRiskPermissions, New-DecomNhiSyntheticData
