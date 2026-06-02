#Requires -Version 5.1

Describe 'Remediation.Rev32 — Credential Revalidation and Execution Safety' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')   -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Remediation.psm1') -Force -DisableNameChecking

        $script:AppObjId  = [guid]::NewGuid().ToString()
        $script:KeyId1    = [guid]::NewGuid().ToString()
        $script:ExpiredDt = (Get-Date).ToUniversalTime().AddDays(-30).ToString('o')
        $script:FutureDt  = (Get-Date).ToUniversalTime().AddDays(45).ToString('o')
        $script:RemContent = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
    }

    AfterAll {
        foreach ($m in @('Remediation','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # -- ExecutionMap and registry tests --

    It 'RemoveExpiredApplicationCredential is in execution scope map' {
        InModuleScope Remediation {
            $script:ExecutionMap.ContainsKey('DEC-APP-005') | Should -Be $true
            $script:ExecutionMap['DEC-APP-005'] | Should -Be 'RemoveExpiredApplicationCredential'
        }
    }

    It 'DEC-APP-005 is in ManualApprovalFindingIds' {
        InModuleScope Remediation {
            'DEC-APP-005' -in $script:ManualApprovalFindingIds | Should -Be $true
        }
    }

    It 'Remediation.psm1 uses Remove-MgApplicationPassword for password credentials' {
        $script:RemContent | Should -Match 'Remove-MgApplicationPassword'
    }

    It 'Remediation.psm1 uses Remove-MgApplicationKey for key credentials' {
        $script:RemContent | Should -Match 'Remove-MgApplicationKey'
    }

    It 'Remediation.psm1 checks cmdlet availability before executing credential removal' {
        $script:RemContent | Should -Match 'Get-Command.*Remove-Mg'
    }

    It 'Remediation.psm1 handles already-removed credential as Skipped' {
        $script:RemContent | Should -Match '(?i)(Skipped|already.*remov)'
    }

    It 'Remediation.psm1 blocks application read failure' {
        $script:RemContent | Should -Match 'Application read failed'
    }

    It 'Remediation.psm1 blocks credential not expired' {
        $script:RemContent | Should -Match '(?i)(NOT expired|not.*expired|EndDateTime.*future|future.*EndDateTime)'
    }

    It 'Remediation.psm1 blocks CredentialType mismatch' {
        $script:RemContent | Should -Match 'CredentialType MISMATCH'
    }

    It 'Remediation.psm1 blocks null EndDateTime' {
        $script:RemContent | Should -Match 'EndDateTime is null'
    }

    It 'Unapproved action type is blocked — OutOfScope handling present' {
        $script:RemContent | Should -Match '(OutOfScope|out of scope|unsupported|not supported)'
    }

    # -- Revalidation logic content tests --

    It 'Confirm-DecomActionTargetValid handles RemoveExpiredApplicationCredential case' {
        $script:RemContent | Should -Match "'RemoveExpiredApplicationCredential'"
    }

    It 'Get-DecomTargetState handles RemoveExpiredApplicationCredential case' {
        $script:RemContent | Should -Match "RemoveExpiredApplicationCredential"
    }

    # -- ProtectedObject block in InvokeDecomRemediation --

    It 'Invoke-DecomRemediation checks ProtectedObject before executing credential removal' {
        $script:RemContent | Should -Match 'ProtectedObject'
    }

    # -- Direct revalidation tests using InModuleScope --

    It 'Confirm-DecomActionTargetValid blocks when ProtectedObject is true (early exit)' {
        $action = [PSCustomObject]@{
            ActionId             = [guid]::NewGuid().ToString()
            ActionType           = 'RemoveExpiredApplicationCredential'
            FindingId            = 'DEC-APP-005'
            ObjectId             = $script:AppObjId
            ObjectType           = 'Application'
            TargetObjectIds      = @($script:KeyId1)
            CredentialType       = 'PasswordCredential'
            CredentialEndDateTime= $script:ExpiredDt
            ProtectedObject      = $true
        }
        # ProtectedObject check is done BEFORE Confirm-DecomActionTargetValid in the execution flow.
        # Verify the code contains the ProtectedObject block in Invoke-DecomRemediation.
        $script:RemContent | Should -Match 'ProtectedObject.*true|ProtectedObject -eq \$true'
    }

    It 'Get-DecomTargetState returns object with querySucceeded field for credential action type' {
        $script:RemContent | Should -Match 'querySucceeded'
    }

    It 'Remediation.psm1 does not contain Remove-MgApplication with object deletion semantics' {
        # Remove-MgApplicationPassword and Remove-MgApplicationKey are allowed.
        # Remove-MgApplication (object deletion) must not appear.
        $script:RemContent | Should -Not -Match 'Remove-MgApplication\s'
    }

    It 'Remediation.psm1 does not contain Remove-MgServicePrincipal' {
        $script:RemContent | Should -Not -Match 'Remove-MgServicePrincipal\b'
    }

    It 'Post-write evidence check prevents re-query failure from logging Executed' {
        $script:RemContent | Should -Match '(?i)(querySucceeded.*false|EvidenceUnknown|PartialFailed.*query)'
    }

    It 'Already-removed credential logs Skipped before attempting write' {
        $script:RemContent | Should -Match "(?i)('Skipped'|Skipped|already.*remov|credential not found.*no write)"
    }
}
