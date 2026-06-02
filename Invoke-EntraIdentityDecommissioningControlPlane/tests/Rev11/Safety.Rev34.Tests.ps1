#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev3.4 Safety Tests' {

    BeforeAll {
        $script:Root        = Join-Path $PSScriptRoot '..\..'
        $script:ModPath     = Join-Path $script:Root 'src\Modules'
        $script:EntryPoint  = Join-Path $script:Root 'Invoke-EntraIdentityDecommissioningControlPlane.ps1'

        $script:WriteCmdletPattern = 'Remove-Mg[A-Za-z]|Update-Mg[A-Za-z]|New-Mg[A-Za-z]|Set-Mg[A-Za-z]|Invoke-MgGraphRequest'
        $script:WriteScope1        = 'Policy\.ReadWrite'
        $script:WriteScope2        = 'Directory\.ReadWrite\.All'
        $script:DeletionPattern    = 'Remove-MgApplication\b|Remove-MgServicePrincipal\b|Remove-MgUser\b|Remove-MgGroup\b'
        $script:NhiPattern         = 'DEC-NHI-'
        $script:AgentPattern       = 'DEC-AGENT-'
    }

    Context 'No new write scopes in Rev3.4 hardening modules' {

        It 'Rev3.4 hardening modules add no new write scope strings' {
            $newMods = @(
                'OutputManifest','EvidenceBundle','Redaction','ReplayValidation',
                'ApprovalDiff','Traceability','ClientHandoff','Rev35Readiness'
            )
            foreach ($mod in $newMods) {
                $p = Join-Path $script:ModPath "$mod.psm1"
                if (Test-Path $p) {
                    $c = Get-Content $p -Raw
                    ($c -match 'ReadWrite') | Should -Be $false -Because "$mod.psm1 must not contain ReadWrite scope strings"
                }
            }
        }

        It 'Rev3.4 hardening modules add no new remediation action types' {
            $existingActionTypes = 'RemoveExpiredApplicationCredential|AddApplicationOwner|RemoveCAExclusionGroupMember|RemoveGuestUser|RemoveAppRoleAssignment|RemoveGroupMembership|RemovePimEligibility|RevokeSignInSession'
            $newMods = @(
                'OutputManifest','EvidenceBundle','Redaction','ReplayValidation',
                'ApprovalDiff','Traceability','ClientHandoff','Rev35Readiness'
            )
            foreach ($mod in $newMods) {
                $p = Join-Path $script:ModPath "$mod.psm1"
                if (Test-Path $p) {
                    $c = Get-Content $p -Raw
                    ($c -match $existingActionTypes) | Should -Be $false -Because "$mod.psm1 must not define new remediation action types"
                }
            }
        }
    }

    Context 'No write cmdlets in Rev3.4 hardening modules' {

        It 'OutputManifest.psm1 contains no write cmdlets' {
            $p = Join-Path $script:ModPath 'OutputManifest.psm1'
            $p | Should -Exist
            $c = Get-Content $p -Raw
            ($c -match $script:WriteCmdletPattern) | Should -Be $false
        }

        It 'EvidenceBundle.psm1 contains no write cmdlets' {
            $p = Join-Path $script:ModPath 'EvidenceBundle.psm1'
            $p | Should -Exist
            $c = Get-Content $p -Raw
            ($c -match $script:WriteCmdletPattern) | Should -Be $false
        }

        It 'Redaction.psm1 contains no write cmdlets' {
            $p = Join-Path $script:ModPath 'Redaction.psm1'
            $p | Should -Exist
            $c = Get-Content $p -Raw
            ($c -match $script:WriteCmdletPattern) | Should -Be $false
        }

        It 'ReplayValidation.psm1 contains no write cmdlets' {
            $p = Join-Path $script:ModPath 'ReplayValidation.psm1'
            $p | Should -Exist
            $c = Get-Content $p -Raw
            ($c -match $script:WriteCmdletPattern) | Should -Be $false
        }

        It 'ApprovalDiff.psm1 contains no write cmdlets' {
            $p = Join-Path $script:ModPath 'ApprovalDiff.psm1'
            $p | Should -Exist
            $c = Get-Content $p -Raw
            ($c -match $script:WriteCmdletPattern) | Should -Be $false
        }

        It 'Traceability.psm1 contains no write cmdlets' {
            $p = Join-Path $script:ModPath 'Traceability.psm1'
            $p | Should -Exist
            $c = Get-Content $p -Raw
            ($c -match $script:WriteCmdletPattern) | Should -Be $false
        }

        It 'ClientHandoff.psm1 contains no write cmdlets' {
            $p = Join-Path $script:ModPath 'ClientHandoff.psm1'
            $p | Should -Exist
            $c = Get-Content $p -Raw
            ($c -match $script:WriteCmdletPattern) | Should -Be $false
        }

        It 'Rev35Readiness.psm1 contains no write cmdlets' {
            $p = Join-Path $script:ModPath 'Rev35Readiness.psm1'
            $p | Should -Exist
            $c = Get-Content $p -Raw
            ($c -match $script:WriteCmdletPattern) | Should -Be $false
        }
    }

    Context 'Entry point mode safety' {

        It 'Assessment mode is the default Mode parameter' {
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:EntryPoint, [ref]$null, [ref]$null)
            $modeParam = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Mode' }
            $modeParam | Should -Not -BeNullOrEmpty
            $modeParam.DefaultValue.Value | Should -Be 'Assessment'
        }

        It 'DemoMode does not appear in write scope Connect-MgGraph calls' {
            $c = Get-Content $script:EntryPoint -Raw
            $c | Should -Match '-DemoMode'
            $c | Should -Not -Match 'DemoMode.*ReadWrite|ReadWrite.*DemoMode'
        }

        It 'WhatIfRemediation does not trigger ExecuteRemediation' {
            $c = Get-Content $script:EntryPoint -Raw
            $c | Should -Match 'WhatIfRemediation'
            $c | Should -Match 'ExecuteRemediation'
        }
    }

    Context 'No forbidden scope patterns' {

        It 'No Policy.ReadWrite.* in Rev3.4 hardening modules' {
            $newMods = @(
                'OutputManifest','EvidenceBundle','Redaction','ReplayValidation',
                'ApprovalDiff','Traceability','ClientHandoff','Rev35Readiness'
            )
            foreach ($mod in $newMods) {
                $p = Join-Path $script:ModPath "$mod.psm1"
                if (Test-Path $p) {
                    $c = Get-Content $p -Raw
                    ($c -match $script:WriteScope1) | Should -Be $false -Because "$mod.psm1 must not reference Policy.ReadWrite"
                }
            }
        }

        It 'No Directory.ReadWrite.All in Rev3.4 hardening modules' {
            $newMods = @(
                'OutputManifest','EvidenceBundle','Redaction','ReplayValidation',
                'ApprovalDiff','Traceability','ClientHandoff','Rev35Readiness'
            )
            foreach ($mod in $newMods) {
                $p = Join-Path $script:ModPath "$mod.psm1"
                if (Test-Path $p) {
                    $c = Get-Content $p -Raw
                    ($c -match $script:WriteScope2) | Should -Be $false -Because "$mod.psm1 must not reference Directory.ReadWrite.All"
                }
            }
        }

        It 'No app/SP/user/guest deletion cmdlets in Rev3.4 hardening modules' {
            $newMods = @(
                'OutputManifest','EvidenceBundle','Redaction','ReplayValidation',
                'ApprovalDiff','Traceability','ClientHandoff','Rev35Readiness'
            )
            foreach ($mod in $newMods) {
                $p = Join-Path $script:ModPath "$mod.psm1"
                if (Test-Path $p) {
                    $c = Get-Content $p -Raw
                    ($c -match $script:DeletionPattern) | Should -Be $false -Because "$mod.psm1 must not contain deletion cmdlets"
                }
            }
        }
    }

    Context 'No NHI or agentic identity findings emitted in Rev3.4' {

        It 'No DEC-NHI-* findings emitted in Rev3.4 hardening modules' {
            # Rev35Readiness.psm1 legitimately documents DEC-NHI-* as a reserved namespace — exclude it
            $newMods = @(
                'OutputManifest','EvidenceBundle','Redaction','ReplayValidation',
                'ApprovalDiff','Traceability','ClientHandoff'
            )
            foreach ($mod in $newMods) {
                $p = Join-Path $script:ModPath "$mod.psm1"
                if (Test-Path $p) {
                    $c = Get-Content $p -Raw
                    ($c -match $script:NhiPattern) | Should -Be $false -Because "$mod.psm1 must not emit DEC-NHI-* findings"
                }
            }
            # Rev35Readiness specifically: only documents the namespace, does not emit findings
            $rp = Join-Path $script:ModPath 'Rev35Readiness.psm1'
            if (Test-Path $rp) {
                $rc = Get-Content $rp -Raw
                ($rc -match 'NhiDetectorsImplemented.*=.*\$true') | Should -Be $false -Because 'Rev35Readiness must keep NhiDetectorsImplemented=$false'
                ($rc -match 'NhiFindings.*=.*@\(.*DEC-NHI') | Should -Be $false -Because 'Rev35Readiness must not populate NhiFindings with DEC-NHI-* IDs'
            }
        }

        It 'No DEC-AGENT-* findings emitted in Rev3.4 hardening modules' {
            # Rev35Readiness.psm1 legitimately documents DEC-AGENT-* as a reserved namespace — exclude it
            $newMods = @(
                'OutputManifest','EvidenceBundle','Redaction','ReplayValidation',
                'ApprovalDiff','Traceability','ClientHandoff'
            )
            foreach ($mod in $newMods) {
                $p = Join-Path $script:ModPath "$mod.psm1"
                if (Test-Path $p) {
                    $c = Get-Content $p -Raw
                    ($c -match $script:AgentPattern) | Should -Be $false -Because "$mod.psm1 must not emit DEC-AGENT-* findings"
                }
            }
            # Rev35Readiness specifically: only documents the namespace, does not emit findings
            $rp = Join-Path $script:ModPath 'Rev35Readiness.psm1'
            if (Test-Path $rp) {
                $rc = Get-Content $rp -Raw
                ($rc -match 'AgentFindings.*=.*@\(.*DEC-AGENT') | Should -Be $false -Because 'Rev35Readiness must not populate AgentFindings with DEC-AGENT-* IDs'
            }
        }
    }
}
