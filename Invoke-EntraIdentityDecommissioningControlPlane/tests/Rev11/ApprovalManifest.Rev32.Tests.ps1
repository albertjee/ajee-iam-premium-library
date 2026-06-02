#Requires -Version 5.1

Describe 'ApprovalManifest.Rev32 — Credential ExecutionMap and Registry' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking

        $script:AppObjId  = [guid]::NewGuid().ToString()
        $script:KeyId1    = [guid]::NewGuid().ToString()
        $script:KeyId2    = [guid]::NewGuid().ToString()
        $script:ExpiredDt = (Get-Date).ToUniversalTime().AddDays(-30).ToString('o')
        $script:engId     = 'ENG-32-APPMFST'
        $script:clientName= 'TestClient'
    }

    AfterAll {
        foreach ($m in @('ApprovalManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'ExecutionMap contains DEC-APP-005 mapped to RemoveExpiredApplicationCredential' {
        InModuleScope ApprovalManifest {
            $script:ExecutionMap['DEC-APP-005'] | Should -Be 'RemoveExpiredApplicationCredential'
        }
    }

    It 'CredentialFindingIds contains DEC-APP-005' {
        InModuleScope ApprovalManifest {
            $script:CredentialFindingIds.Contains('DEC-APP-005') | Should -Be $true
        }
    }

    It 'Approval manifest rejects credential action with invalid FindingId (not in scope)' {
        InModuleScope ApprovalManifest {
            $script:ExecutionMap.ContainsKey('DEC-APP-001') | Should -Be $false
        }
    }

    It 'Approval manifest rejects missing TargetObjectIds for credential action' {
        $testRunId = [guid]::NewGuid().ToString()
        $path = Join-Path $TestDrive 'cred-no-targets.json'
        @{
            SchemaVersion        = '3.2'
            EngagementId         = $script:engId
            ClientName           = $script:clientName
            WhatIfRunId          = $testRunId
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'Test Approver (Admin)'
            ApprovedUtc          = (Get-Date).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(7).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            ApprovedActionsHash  = 'placeholder'
            ApprovalEnvelopeHash = 'placeholder'
            ApprovedActions      = @(@{
                ActionId        = [guid]::NewGuid().ToString()
                FindingId       = 'DEC-APP-005'
                ActionType      = 'RemoveExpiredApplicationCredential'
                ObjectId        = $script:AppObjId
                ObjectType      = 'Application'
                TargetObjectIds = @()
                ProtectedObject = $false
            })
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $testRunId
        $result.Valid | Should -Be $false
        ($result.Errors -join ' ') | Should -Match '(TargetObjectIds|target)'
    }

    It 'Approval manifest rejects duplicate credential target operation' {
        $testRunId = [guid]::NewGuid().ToString()
        $path = Join-Path $TestDrive 'cred-dup.json'
        @{
            SchemaVersion        = '3.2'
            EngagementId         = $script:engId
            ClientName           = $script:clientName
            WhatIfRunId          = $testRunId
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'Test Approver (Admin)'
            ApprovedUtc          = (Get-Date).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(7).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            ApprovedActionsHash  = 'placeholder'
            ApprovalEnvelopeHash = 'placeholder'
            ApprovedActions      = @(
                @{
                    ActionId        = [guid]::NewGuid().ToString()
                    FindingId       = 'DEC-APP-005'
                    ActionType      = 'RemoveExpiredApplicationCredential'
                    ObjectId        = $script:AppObjId
                    ObjectType      = 'Application'
                    TargetObjectIds = @($script:KeyId1)
                    ProtectedObject = $false
                },
                @{
                    ActionId        = [guid]::NewGuid().ToString()
                    FindingId       = 'DEC-APP-005'
                    ActionType      = 'RemoveExpiredApplicationCredential'
                    ObjectId        = $script:AppObjId
                    ObjectType      = 'Application'
                    TargetObjectIds = @($script:KeyId1)
                    ProtectedObject = $false
                }
            )
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $testRunId
        $result.Valid | Should -Be $false
        ($result.Errors -join ' ') | Should -Match '(uplicate|duplicate)'
    }

    It 'Approval manifest rejects SchemaVersion older than 3.2 for credential action' {
        $testRunId = [guid]::NewGuid().ToString()
        $path = Join-Path $TestDrive 'cred-old-schema.json'
        @{
            SchemaVersion        = '3.1'
            EngagementId         = $script:engId
            ClientName           = $script:clientName
            WhatIfRunId          = $testRunId
            ApprovalStatus       = 'Approved'
            ApprovedBy           = 'Test Approver (Admin)'
            ApprovedUtc          = (Get-Date).ToUniversalTime().ToString('o')
            ExpiresUtc           = (Get-Date).AddDays(7).ToUniversalTime().ToString('o')
            AllowNonInteractive  = $false
            ApprovedActionsHash  = 'placeholder'
            ApprovalEnvelopeHash = 'placeholder'
            ApprovedActions      = @(@{
                ActionId        = [guid]::NewGuid().ToString()
                FindingId       = 'DEC-APP-005'
                ActionType      = 'RemoveExpiredApplicationCredential'
                ObjectId        = $script:AppObjId
                ObjectType      = 'Application'
                TargetObjectIds = @($script:KeyId1)
                ProtectedObject = $false
            })
        } | ConvertTo-Json -Depth 10 | Set-Content -Path $path -Encoding UTF8
        $result = Test-DecomApprovalManifest -ManifestPath $path `
            -CurrentEngagementId $script:engId -CurrentClientName $script:clientName `
            -WhatIfRunId $testRunId
        $result.Valid | Should -Be $false
        ($result.Errors -join ' ') | Should -Match '(SchemaVersion|3\.2)'
    }

    It 'Approval hash changes when CredentialType changes' {
        $action1 = [PSCustomObject]@{
            ActionType = 'RemoveExpiredApplicationCredential'; FindingId = 'DEC-APP-005'
            ObjectId = $script:AppObjId; TargetObjectIds = @($script:KeyId1)
            CredentialType = 'PasswordCredential'; CredentialKeyId = $script:KeyId1
            CredentialEndDateTime = $script:ExpiredDt; CredentialExpired = $true
            ApplicationId = $script:AppObjId; AppId = ''; OwnerCount = 1; HasOwner = $true
        }
        $action2 = [PSCustomObject]@{
            ActionType = 'RemoveExpiredApplicationCredential'; FindingId = 'DEC-APP-005'
            ObjectId = $script:AppObjId; TargetObjectIds = @($script:KeyId1)
            CredentialType = 'KeyCredential'; CredentialKeyId = $script:KeyId1
            CredentialEndDateTime = $script:ExpiredDt; CredentialExpired = $true
            ApplicationId = $script:AppObjId; AppId = ''; OwnerCount = 1; HasOwner = $true
        }
        $hash1 = Convert-DecomActionToCanonical -Action $action1
        $hash2 = Convert-DecomActionToCanonical -Action $action2
        $hash1 | Should -Not -Be $hash2 -Because "Changing CredentialType must change the approval hash"
    }

    It 'Approval hash changes when CredentialEndDateTime changes' {
        $action1 = [PSCustomObject]@{
            ActionType = 'RemoveExpiredApplicationCredential'; FindingId = 'DEC-APP-005'
            ObjectId = $script:AppObjId; TargetObjectIds = @($script:KeyId1)
            CredentialType = 'PasswordCredential'; CredentialKeyId = $script:KeyId1
            CredentialEndDateTime = $script:ExpiredDt; CredentialExpired = $true
            ApplicationId = $script:AppObjId; AppId = ''; OwnerCount = 1; HasOwner = $true
        }
        $action2 = [PSCustomObject]@{
            ActionType = 'RemoveExpiredApplicationCredential'; FindingId = 'DEC-APP-005'
            ObjectId = $script:AppObjId; TargetObjectIds = @($script:KeyId1)
            CredentialType = 'PasswordCredential'; CredentialKeyId = $script:KeyId1
            CredentialEndDateTime = (Get-Date).ToUniversalTime().AddDays(-60).ToString('o')
            CredentialExpired = $true
            ApplicationId = $script:AppObjId; AppId = ''; OwnerCount = 1; HasOwner = $true
        }
        $hash1 = Convert-DecomActionToCanonical -Action $action1
        $hash2 = Convert-DecomActionToCanonical -Action $action2
        $hash1 | Should -Not -Be $hash2 -Because "Changing CredentialEndDateTime must change the approval hash"
    }

    It 'Approval hash changes when TargetObjectIds changes' {
        $action1 = [PSCustomObject]@{
            ActionType = 'RemoveExpiredApplicationCredential'; FindingId = 'DEC-APP-005'
            ObjectId = $script:AppObjId; TargetObjectIds = @($script:KeyId1)
            CredentialType = 'PasswordCredential'; CredentialKeyId = $script:KeyId1
            CredentialEndDateTime = $script:ExpiredDt; CredentialExpired = $true
            ApplicationId = $script:AppObjId; AppId = ''; OwnerCount = 1; HasOwner = $true
        }
        $action2 = [PSCustomObject]@{
            ActionType = 'RemoveExpiredApplicationCredential'; FindingId = 'DEC-APP-005'
            ObjectId = $script:AppObjId; TargetObjectIds = @($script:KeyId2)
            CredentialType = 'PasswordCredential'; CredentialKeyId = $script:KeyId2
            CredentialEndDateTime = $script:ExpiredDt; CredentialExpired = $true
            ApplicationId = $script:AppObjId; AppId = ''; OwnerCount = 1; HasOwner = $true
        }
        $hash1 = Convert-DecomActionToCanonical -Action $action1
        $hash2 = Convert-DecomActionToCanonical -Action $action2
        $hash1 | Should -Not -Be $hash2 -Because "Changing TargetObjectIds must change the approval hash"
    }

    It 'Approval manifest validation logic contains Rev3.2 schema gate for credential action types' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Raw
        $content | Should -Match 'Rev3\.2 credential action types require approval manifest SchemaVersion 3\.2'
    }

    It 'Approval manifest validation enforces DEC-APP-005 FindingId for credential removal' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Raw
        $content | Should -Match "FindingId must be DEC-APP-005"
    }

    It 'Approval manifest validation detects duplicate credential removal operations' {
        $content = Get-Content (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Raw
        $content | Should -Match 'Duplicate credential removal operation'
    }
}
