#Requires -Version 5.1

Describe 'RemediationPlan.Rev32 — WhatIf Generation for Expired Application Credentials' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking

        $script:testDir = Join-Path $env:TEMP 'Decom-Rev32-WhatIfTest'
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $expiredDt  = (Get-Date).ToUniversalTime().AddDays(-30).ToString('o')
        $futureDt   = (Get-Date).ToUniversalTime().AddDays(45).ToString('o')
        $pwdKeyId   = [guid]::NewGuid().ToString()
        $keyKeyId   = [guid]::NewGuid().ToString()
        $appObjId   = [guid]::NewGuid().ToString()

        $script:PwdKeyId  = $pwdKeyId
        $script:KeyKeyId  = $keyKeyId
        $script:AppObjId  = $appObjId
        $script:ExpiredDt = $expiredDt
        $script:FutureDt  = $futureDt

        $expiredPwdFinding = [PSCustomObject]@{
            FindingId            = 'DEC-APP-005'
            ObjectId             = $appObjId
            ObjectType           = 'Application'
            DisplayName          = 'TestApp-ExpiredPwd'
            AppId                = [guid]::NewGuid().ToString()
            CredentialKeyId      = $pwdKeyId
            CredentialType       = 'PasswordCredential'
            CredentialEndDateTime= $expiredDt
            OwnerCount           = 1
            HasOwner             = $true
            ProtectedObject      = $false
        }

        $expiredKeyFinding = [PSCustomObject]@{
            FindingId            = 'DEC-APP-005'
            ObjectId             = $appObjId
            ObjectType           = 'Application'
            DisplayName          = 'TestApp-ExpiredKey'
            AppId                = [guid]::NewGuid().ToString()
            CredentialKeyId      = $keyKeyId
            CredentialType       = 'KeyCredential'
            CredentialEndDateTime= $expiredDt
            OwnerCount           = 1
            HasOwner             = $true
            ProtectedObject      = $false
        }

        $noKeyIdFinding = [PSCustomObject]@{
            FindingId            = 'DEC-APP-005'
            ObjectId             = $appObjId
            ObjectType           = 'Application'
            DisplayName          = 'TestApp-NoKeyId'
            AppId                = [guid]::NewGuid().ToString()
            CredentialType       = 'PasswordCredential'
            CredentialEndDateTime= $expiredDt
            OwnerCount           = 1
            HasOwner             = $true
            ProtectedObject      = $false
        }

        $app004Finding = [PSCustomObject]@{
            FindingId            = 'DEC-APP-004'
            ObjectId             = $appObjId
            ObjectType           = 'Application'
            DisplayName          = 'TestApp-Expiring'
            CredentialKeyId      = [guid]::NewGuid().ToString()
            CredentialType       = 'PasswordCredential'
            CredentialEndDateTime= $futureDt
            ProtectedObject      = $false
        }

        $nonExpiredFinding = [PSCustomObject]@{
            FindingId            = 'DEC-APP-005'
            ObjectId             = $appObjId
            ObjectType           = 'Application'
            DisplayName          = 'TestApp-NotExpired'
            CredentialKeyId      = [guid]::NewGuid().ToString()
            CredentialType       = 'PasswordCredential'
            CredentialEndDateTime= $futureDt
            ProtectedObject      = $false
        }

        $script:PwdPlan = New-DecomWhatIfActionPlan `
            -Findings @($expiredPwdFinding) `
            -EngagementId 'ENG-32-PWD' `
            -ClientName 'TestClient' `
            -Assessor 'TestAssessor' `
            -WhatIfRunId ([guid]::NewGuid().ToString()) `
            -OutputPath $script:testDir

        $script:KeyPlan = New-DecomWhatIfActionPlan `
            -Findings @($expiredKeyFinding) `
            -EngagementId 'ENG-32-KEY' `
            -ClientName 'TestClient' `
            -Assessor 'TestAssessor' `
            -WhatIfRunId ([guid]::NewGuid().ToString()) `
            -OutputPath $script:testDir

        $script:NoKeyPlan = New-DecomWhatIfActionPlan `
            -Findings @($noKeyIdFinding) `
            -EngagementId 'ENG-32-NOKEY' `
            -ClientName 'TestClient' `
            -Assessor 'TestAssessor' `
            -WhatIfRunId ([guid]::NewGuid().ToString()) `
            -OutputPath $script:testDir

        $script:App004Plan = New-DecomWhatIfActionPlan `
            -Findings @($app004Finding) `
            -EngagementId 'ENG-32-004' `
            -ClientName 'TestClient' `
            -Assessor 'TestAssessor' `
            -WhatIfRunId ([guid]::NewGuid().ToString()) `
            -OutputPath $script:testDir

        $script:NonExpiredPlan = New-DecomWhatIfActionPlan `
            -Findings @($nonExpiredFinding) `
            -EngagementId 'ENG-32-NOTEXP' `
            -ClientName 'TestClient' `
            -Assessor 'TestAssessor' `
            -WhatIfRunId ([guid]::NewGuid().ToString()) `
            -OutputPath $script:testDir
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('ApprovalManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    It 'DEC-APP-005 with exact expired password credential KeyId generates RemoveExpiredApplicationCredential' {
        $plan = Get-Content $script:PwdPlan -Raw | ConvertFrom-Json
        $actions = @($plan.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveExpiredApplicationCredential' })
        $actions.Count | Should -BeGreaterThan 0
    }

    It 'DEC-APP-005 with exact expired key credential KeyId generates RemoveExpiredApplicationCredential' {
        $plan = Get-Content $script:KeyPlan -Raw | ConvertFrom-Json
        $actions = @($plan.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveExpiredApplicationCredential' })
        $actions.Count | Should -BeGreaterThan 0
    }

    It 'DEC-APP-005 without KeyId does not generate executable RemoveExpiredApplicationCredential' {
        $plan = Get-Content $script:NoKeyPlan -Raw | ConvertFrom-Json
        $executable = @($plan.ApprovedActions | Where-Object {
            $_.ActionType -eq 'RemoveExpiredApplicationCredential' -and
            $_.TargetObjectIds -and $_.TargetObjectIds.Count -gt 0
        })
        $executable.Count | Should -Be 0
    }

    It 'DEC-APP-004 expiring credential remains plan-only' {
        $plan = Get-Content $script:App004Plan -Raw | ConvertFrom-Json
        $executable = @($plan.ApprovedActions | Where-Object {
            $_.ActionType -eq 'RemoveExpiredApplicationCredential' -and
            $_.FindingId -eq 'DEC-APP-004'
        })
        $executable.Count | Should -Be 0
    }

    It 'Non-expired credential does not generate executable RemoveExpiredApplicationCredential' {
        $plan = Get-Content $script:NonExpiredPlan -Raw | ConvertFrom-Json
        $executable = @($plan.ApprovedActions | Where-Object {
            $_.ActionType -eq 'RemoveExpiredApplicationCredential' -and
            $_.TargetObjectIds -and $_.TargetObjectIds.Count -gt 0
        })
        $executable.Count | Should -Be 0
    }

    It 'Credential action rollback guidance says secret value cannot be recovered' {
        $plan = Get-Content $script:PwdPlan -Raw | ConvertFrom-Json
        $action = $plan.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveExpiredApplicationCredential' } |
            Select-Object -First 1
        $action | Should -Not -BeNullOrEmpty
        $action.RollbackGuidance | Should -Match '(?i)(cannot be recover|no.*(auto.*rollback|secret.*material)|manual.*new.*credential)'
    }

    It 'Credential action requires manual approval' {
        $plan = Get-Content $script:PwdPlan -Raw | ConvertFrom-Json
        $action = $plan.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveExpiredApplicationCredential' } |
            Select-Object -First 1
        $action.RequiresManualApproval | Should -Be $true
    }

    It 'WhatIf action has ReadinessStatus field' {
        $plan = Get-Content $script:PwdPlan -Raw | ConvertFrom-Json
        $action = $plan.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveExpiredApplicationCredential' } |
            Select-Object -First 1
        $action.PSObject.Properties.Name | Should -Contain 'ReadinessStatus'
    }

    It 'WhatIf credential action contains CredentialExpired = true' {
        $plan = Get-Content $script:PwdPlan -Raw | ConvertFrom-Json
        $action = $plan.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveExpiredApplicationCredential' } |
            Select-Object -First 1
        $action.CredentialExpired | Should -Be $true
    }

    It 'WhatIf credential action FindingId is DEC-APP-005' {
        $plan = Get-Content $script:PwdPlan -Raw | ConvertFrom-Json
        $action = $plan.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveExpiredApplicationCredential' } |
            Select-Object -First 1
        $action.FindingId | Should -Be 'DEC-APP-005'
    }

    It 'WhatIf plan SchemaVersion is 3.2' {
        $plan = Get-Content $script:PwdPlan -Raw | ConvertFrom-Json
        $plan.SchemaVersion | Should -Be '3.2'
    }
}
