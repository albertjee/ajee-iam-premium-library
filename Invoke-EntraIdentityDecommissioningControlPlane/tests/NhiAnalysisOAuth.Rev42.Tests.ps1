# NhiAnalysisOAuth.Rev42.Tests.ps1
# Rev4.2 bug fix: NhiAnalysis.psm1 referenced $script:HighRiskDelegatedScopes without ever
# defining it (always $null), so HighRiskOAuthGrantCount was always 0 regardless of grants.
# Fix wires the canonical catalog (NhiScopeCatalog.psm1, Discovery delegated list) into
# NhiAnalysis. These tests exercise the previously dead code path end to end.

BeforeAll {
    $script:ToolRoot = Split-Path -Parent $PSScriptRoot
    $script:ModulesPath = Join-Path $script:ToolRoot 'src\Modules'

    Remove-Module Utilities, NhiAnalysis, NhiScopeCatalog -Force -ErrorAction SilentlyContinue
    Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking
    Import-Module (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Force -DisableNameChecking

    function script:New-OAuthTestNhiObject {
        param(
            [string]$DisplayName = 'oauth-test-sp',
            [object[]]$RawOAuthGrants = @()
        )
        [PSCustomObject]@{
            ObjectId              = 'sp-oauth-001'
            ObjectType            = 'ServicePrincipal'
            DisplayName           = $DisplayName
            ServicePrincipalType  = 'Application'
            AccountEnabled        = $true
            PublisherName         = 'Contoso Ltd'
            VerifiedPublisherName = $null
            AppOwnerOrganizationId = 'external-tenant-id'
            Tags                  = @()
            OwnerCount            = 2
            CredentialCount       = 0
            ExpiredCredentialCount = 0
            ExpiringCredentialCount = 0
            HighRiskPermissionCount = 0
            RawOAuthGrants        = $RawOAuthGrants
            RiskScoreMayBeUnderstated = $false
            CoverageLimitations   = @()
        }
    }
}

Describe 'NhiAnalysis high-risk OAuth grant counting (Rev4.2 bug fix)' {

    It 'NhiAnalysis.psm1 imports the scope catalog and defines the delegated list' {
        $content = Get-Content (Join-Path $script:ModulesPath 'NhiAnalysis.psm1') -Raw
        $content | Should -Match "Import-Module \(Join-Path \`$PSScriptRoot 'NhiScopeCatalog\.psm1'\)"
        $content | Should -Match '\$script:HighRiskDelegatedScopes\s*='
    }

    It 'counts a grant with a high-risk delegated scope (previously always 0)' {
        $grant = [PSCustomObject]@{ ConsentType = 'Principal'; Scope = 'Directory.ReadWrite.All' }
        $obj = script:New-OAuthTestNhiObject -RawOAuthGrants @($grant)
        $ctx = [PSCustomObject]@{ DemoMode = $false }
        $results = Invoke-DecomNhiAnalysis -NhiObjects @($obj) -Context $ctx
        $results[0].HighRiskOAuthGrantCount | Should -Be 1
    }

    It 'counts User.Read.All as high-risk (Discovery delegated list semantics)' {
        $grant = [PSCustomObject]@{ ConsentType = 'SpecificPrincipals'; Scope = 'User.Read.All' }
        $obj = script:New-OAuthTestNhiObject -RawOAuthGrants @($grant)
        $ctx = [PSCustomObject]@{ DemoMode = $false }
        $results = Invoke-DecomNhiAnalysis -NhiObjects @($obj) -Context $ctx
        $results[0].HighRiskOAuthGrantCount | Should -Be 1
    }

    It 'does not count grants with only low-risk scopes' {
        $grant = [PSCustomObject]@{ ConsentType = 'Principal'; Scope = 'User.Read openid profile' }
        $obj = script:New-OAuthTestNhiObject -RawOAuthGrants @($grant)
        $ctx = [PSCustomObject]@{ DemoMode = $false }
        $results = Invoke-DecomNhiAnalysis -NhiObjects @($obj) -Context $ctx
        $results[0].HighRiskOAuthGrantCount | Should -Be 0
    }

    It 'counts each grant at most once even with multiple high-risk scopes in one grant' {
        $grant = [PSCustomObject]@{ ConsentType = 'Principal'; Scope = 'Directory.ReadWrite.All Mail.ReadWrite Files.ReadWrite.All' }
        $obj = script:New-OAuthTestNhiObject -RawOAuthGrants @($grant)
        $ctx = [PSCustomObject]@{ DemoMode = $false }
        $results = Invoke-DecomNhiAnalysis -NhiObjects @($obj) -Context $ctx
        $results[0].HighRiskOAuthGrantCount | Should -Be 1
    }

    It 'counts multiple grants independently' {
        $grants = @(
            [PSCustomObject]@{ ConsentType = 'Principal'; Scope = 'Directory.ReadWrite.All' },
            [PSCustomObject]@{ ConsentType = 'AllPrincipals'; Scope = 'Mail.ReadWrite' },
            [PSCustomObject]@{ ConsentType = 'Principal'; Scope = 'User.Read' }
        )
        $obj = script:New-OAuthTestNhiObject -RawOAuthGrants $grants
        $ctx = [PSCustomObject]@{ DemoMode = $false }
        $results = Invoke-DecomNhiAnalysis -NhiObjects @($obj) -Context $ctx
        $results[0].HighRiskOAuthGrantCount | Should -Be 2
    }

    It 'high-risk grant now contributes +8 to classification score via analysis pipeline' {
        $grant = [PSCustomObject]@{ ConsentType = 'Principal'; Scope = 'Directory.ReadWrite.All' }
        $withGrant = script:New-OAuthTestNhiObject -RawOAuthGrants @($grant)
        $withoutGrant = script:New-OAuthTestNhiObject -RawOAuthGrants @()
        $ctx = [PSCustomObject]@{ DemoMode = $false }
        $scoreWith = (Invoke-DecomNhiAnalysis -NhiObjects @($withGrant) -Context $ctx)[0].ClassificationScore
        $scoreWithout = (Invoke-DecomNhiAnalysis -NhiObjects @($withoutGrant) -Context $ctx)[0].ClassificationScore
        ($scoreWith - $scoreWithout) | Should -Be 8
    }
}
