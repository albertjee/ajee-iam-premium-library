#Requires -Version 5.1

Describe 'Rev4.10 platform identity catalog' {
    BeforeAll {
        Remove-Module Utilities -Force -ErrorAction SilentlyContinue
        Import-Module (Join-Path $PSScriptRoot '..\src\Modules\Utilities.psm1') -Force -DisableNameChecking
        $script:CatalogPath = Get-DecomPlatformIdentityCatalogPath
        $script:Catalog = Get-DecomPlatformIdentityCatalog
        $script:Validation = Test-DecomPlatformIdentityCatalog -Catalog $script:Catalog
    }

    AfterAll {
        Remove-Module Utilities -Force -ErrorAction SilentlyContinue
    }

    It 'Loads the catalog from config/platform-identity-catalog.json' {
        $script:CatalogPath | Should -Match 'config\\platform-identity-catalog\.json$'
        Test-Path -LiteralPath $script:CatalogPath | Should -Be $true
    }

    It 'Catalog schema and identities validate cleanly' {
        $script:Validation.Valid | Should -Be $true
        $script:Validation.DuplicateAppIds.Count | Should -Be 0
        $script:Validation.IdentityCount | Should -Be 4
    }

    It 'Classifies Microsoft live metadata as MicrosoftPlatform' {
        $sp = [pscustomobject]@{
            appId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
            appOwnerOrganizationId = '72f988bf-86f1-41af-91ab-2d7cd011db47'
            verifiedPublisher = [pscustomobject]@{ displayName = 'Microsoft Corporation' }
            displayName = 'Microsoft Graph PowerShell'
            appDisplayName = 'Microsoft Graph PowerShell'
            servicePrincipalType = 'Application'
            tags = @('WindowsAzureActiveDirectoryIntegratedApp')
        }

        $result = Test-DecomMicrosoftPlatformIdentity -NhiObject $sp
        $result.Classification | Should -Be 'MicrosoftPlatform'
        $result.MicrosoftPlatform | Should -Be $true
        $result.MicrosoftFirstParty | Should -Be $true
        $result.Reason | Should -Not -BeNullOrEmpty
    }

    It 'Classifies Microsoft Tech Community and Flipgrid through the catalog' {
        foreach ($sp in @(
            [pscustomobject]@{
                appId = '09213cdc-9f30-4e82-aa6f-9b6e8d82dab3'
                appOwnerOrganizationId = 'cdc5aeea-15c5-4db6-b079-fcadd2505dc2'
                verifiedPublisher = $null
                displayName = 'Microsoft Tech Community'
                appDisplayName = 'Microsoft Tech Community'
                servicePrincipalType = 'Application'
                tags = @()
            },
            [pscustomobject]@{
                appId = 'f1143447-b07a-4557-b878-b78df8d45c13'
                appOwnerOrganizationId = '1bf12738-0df6-4c07-97c3-0b0642a2f1a0'
                verifiedPublisher = $null
                displayName = 'Flipgrid'
                appDisplayName = 'Flipgrid'
                servicePrincipalType = 'Application'
                tags = @()
            }
        )) {
            $result = Test-DecomMicrosoftPlatformIdentity -NhiObject $sp
            $result.Classification | Should -Be 'MicrosoftPlatform'
            $result.MicrosoftPlatform | Should -Be $true
            $result.MicrosoftFirstParty | Should -Be $true
            $result.CatalogSource | Should -Be 'PlatformCatalog'
            $result.Reason | Should -Not -BeNullOrEmpty
        }
    }

    It 'Classifies iOS Accounts as ExternalVendorPlatform and not MicrosoftPlatform' {
        $sp = [pscustomobject]@{
            appId = 'f8d98a96-0999-43f5-8af3-69971c7bb423'
            appOwnerOrganizationId = 'e0fad04c-a04c-41ab-b35e-dc523af755a1'
            verifiedPublisher = [pscustomobject]@{ displayName = 'Apple Inc.' }
            displayName = 'iOS Accounts'
            appDisplayName = 'iOS Accounts'
            servicePrincipalType = 'Application'
            tags = @()
        }

        $result = Test-DecomMicrosoftPlatformIdentity -NhiObject $sp
        $result.Classification | Should -Be 'ExternalVendorPlatform'
        $result.MicrosoftPlatform | Should -Be $false
        $result.MicrosoftFirstParty | Should -Be $false
        $result.Reason | Should -Not -BeNullOrEmpty
    }
}
