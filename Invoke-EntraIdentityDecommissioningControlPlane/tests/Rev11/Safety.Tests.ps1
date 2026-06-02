#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev1.1 Safety Tests' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\modules'

        Remove-Module Utilities       -Force -ErrorAction SilentlyContinue
        Remove-Module Discovery       -Force -ErrorAction SilentlyContinue
        Remove-Module Analysis        -Force -ErrorAction SilentlyContinue
        Remove-Module Reporting       -Force -ErrorAction SilentlyContinue
        Remove-Module RemediationPlan -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Discovery.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Analysis.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Reporting.psm1')       -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'RemediationPlan.psm1') -Force -DisableNameChecking
    }

    Context 'Default mode is Assessment' {
        It 'Entry point parameter default for Mode is Assessment' {
            $ep = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($ep, [ref]$null, [ref]$null)
            $paramBlock = $ast.ParamBlock
            $modeParam = $paramBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Mode' }
            $modeParam | Should -Not -BeNullOrEmpty
            $defaultValue = $modeParam.DefaultValue.Value
            $defaultValue | Should -Be 'Assessment'
        }
    }

    Context 'Assessment mode does not expose remediation execution functions' {
        It 'ExecuteRemediation is not a public function exported by any module' {
            $remediationFns = Get-Command -Name '*ExecuteRemediation*' -ErrorAction SilentlyContinue
            $remediationFns | Should -BeNullOrEmpty
        }
    }

    Context 'ExecuteRemediation requires explicit parameter' {
        It 'Entry point ValidateSet for Mode includes ExecuteRemediation but is not default' {
            $ep = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            $content = Get-Content $ep -Raw
            $content | Should -Match "ExecuteRemediation"
            $content | Should -Match "Mode.*=.*'Assessment'"
        }
    }

    Context 'New-DecomFinding ProtectedObject flag' {
        It 'New-DecomFinding with ProtectedObject=$true sets flag correctly' {
            $finding = New-DecomFinding `
                -FindingId 'TEST-001' `
                -Category 'Test' `
                -Severity 'Low' `
                -RiskScore 25 `
                -Confidence 'Low' `
                -ObjectType 'User' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'TestUser' `
                -Evidence 'Test evidence' `
                -EvidenceSource 'test' `
                -RecommendedAction 'Test action' `
                -RemediationMode 'ManualApprovalRequired' `
                -ProtectedObject $true
            $finding.ProtectedObject | Should -Be $true
        }
    }

    Context 'Protected pattern classification' {
        It 'DisplayName containing breakglass is classified ProtectedObject by Invoke-DecomAnalysis' {
            $finding = New-DecomFinding `
                -FindingId 'TEST-BG-001' `
                -Category 'User Lifecycle' `
                -Severity 'Critical' `
                -RiskScore 95 `
                -Confidence 'High' `
                -ObjectType 'User' `
                -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'breakglass-admin' `
                -Evidence 'Protected account in privileged role' `
                -EvidenceSource 'test' `
                -RecommendedAction 'Review' `
                -RemediationMode 'ProtectedObject'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].ProtectedObject | Should -Be $true
        }
    }

    Context 'Discovery module does not call destructive verbs' {
        It 'Discovery.psm1 source contains no Remove-, Set-, or Disable- calls' {
            $discoveryPath = Join-Path $script:ModulesPath 'Discovery.psm1'
            $content = Get-Content $discoveryPath -Raw
            $content | Should -Not -Match '\bRemove-Mg'
            $content | Should -Not -Match '\bSet-Mg'
            $content | Should -Not -Match '\bDisable-Mg'
        }
    }

    Context 'Rev1.2 ExecuteRemediation guard and pattern classification' {
        It 'ExecuteRemediation mode is blocked in entry point source when DemoMode is used' {
            $ep = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            $content = Get-Content $ep -Raw
            $content | Should -Match 'ExecuteRemediation'
            $content | Should -Match 'ExecuteRemediation cannot run in DemoMode'
        }

        It 'Protected pattern svc- is classified as ProtectedObject' {
            $finding = New-DecomFinding `
                -FindingId 'SVC-001' -Category 'User Lifecycle' -Severity 'Medium' -RiskScore 50 `
                -Confidence 'High' -ObjectType 'User' -ObjectId ([guid]::NewGuid().Guid) `
                -DisplayName 'svc-automation-account' -UserPrincipalName 'svc-auto@contoso.com' `
                -Evidence 'Service account test' -EvidenceSource 'test' `
                -RecommendedAction 'Review' -RemediationMode 'ManualApprovalRequired'
            $result = Invoke-DecomAnalysis -Findings @($finding)
            $result[0].ProtectedObject | Should -Be $true
        }
    }
}

Describe 'Rev2.0 Safety Tests' {

    BeforeAll {
        $script:ModulesPath2 = Join-Path $PSScriptRoot '..\..\src\Modules'

        Remove-Module ApprovalManifest -Force -ErrorAction SilentlyContinue
        Remove-Module ExecutionLog     -Force -ErrorAction SilentlyContinue

        Import-Module (Join-Path $script:ModulesPath2 'ApprovalManifest.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath2 'ExecutionLog.psm1')     -Force -DisableNameChecking

        function script:New-TestApprovalManifest {
            param(
                [string]$EngagementId      = 'ENG-001',
                [string]$ClientName        = 'Contoso',
                [string]$WhatIfRunId       = [guid]::NewGuid().ToString(),
                [object[]]$Actions         = $null,
                [bool]$AllowNonInteractive = $false
            )
            if ($null -eq $Actions) {
                $Actions = @(
                    [ordered]@{
                        ActionId='ACT-001'; FindingId='DEC-USER-001'; ObjectId='user-001'; ObjectType='User'
                        DisplayName='Test User'; UserPrincipalName='test@contoso.com'
                        ActionType='RemoveGroupMembership'; TargetObjectIds=@('group-001')
                        TargetDisplayNames=@('Group 1'); Evidence='test'; RiskScore=50
                        ProtectedObject=$false; RoleAssignmentId=''; RoleDefinitionId=''; RoleDisplayName=''
                    }
                )
            }
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $Actions
            $expiresUtc  = (Get-Date).AddDays(3).ToUniversalTime().ToString('o')
            $envInput = [PSCustomObject]@{
                EngagementId=$EngagementId; ClientName=$ClientName; WhatIfRunId=$WhatIfRunId
                ApprovedBy='Jane Smith, CISO'; ApprovedUtc='2026-05-30T10:00:00Z'
                ExpiresUtc=$expiresUtc; AllowNonInteractive=$AllowNonInteractive
            }
            $envHash = Get-DecomApprovalEnvelopeHash -Manifest $envInput -ActionsHash $actionsHash
            return [ordered]@{
                SchemaVersion='2.0'; EngagementId=$EngagementId; ClientName=$ClientName
                WhatIfRunId=$WhatIfRunId; ApprovalStatus='Approved'
                ApprovedBy='Jane Smith, CISO'; ApprovedUtc='2026-05-30T10:00:00Z'
                ExpiresUtc=$expiresUtc; AllowNonInteractive=$AllowNonInteractive
                ApprovedActionsHash=$actionsHash; ApprovalEnvelopeHash=$envHash
                ApprovedActions=$Actions; PlanOnlyActions=@(); SkippedActions=@()
            }
        }
    }

    Context 'Hash determinism and canonicalization' {

        It 'Get-DecomApprovedActionsHash returns same hash for identical input' {
            $a = [ordered]@{
                ActionId='ACT-001'; FindingId='DEC-USER-001'; ObjectId='u1'; ObjectType='User'
                DisplayName='T'; UserPrincipalName='t@c.com'; ActionType='RemoveGroupMembership'
                TargetObjectIds=@('g1'); TargetDisplayNames=@('G1'); Evidence='e'; RiskScore=50
                ProtectedObject=$false; RoleAssignmentId=''; RoleDefinitionId=''; RoleDisplayName=''
            }
            $h1 = Get-DecomApprovedActionsHash -ApprovedActions @($a)
            $h2 = Get-DecomApprovedActionsHash -ApprovedActions @($a)
            $h1 | Should -Be $h2
            $h1 | Should -Not -BeNullOrEmpty
        }

        It 'ApprovalEnvelopeHash changes when AllowNonInteractive changes' {
            $aHash = Get-DecomSha256 -InputString 'determinism-test-payload'
            $m1 = [PSCustomObject]@{ EngagementId='ENG-001'; ClientName='Contoso'; WhatIfRunId='r1'
                ApprovedBy='J'; ApprovedUtc='2026-05-30T10:00:00Z'; ExpiresUtc='2026-06-02T10:00:00Z'
                AllowNonInteractive=$false }
            $m2 = [PSCustomObject]@{ EngagementId='ENG-001'; ClientName='Contoso'; WhatIfRunId='r1'
                ApprovedBy='J'; ApprovedUtc='2026-05-30T10:00:00Z'; ExpiresUtc='2026-06-02T10:00:00Z'
                AllowNonInteractive=$true }
            $e1 = Get-DecomApprovalEnvelopeHash -Manifest $m1 -ActionsHash $aHash
            $e2 = Get-DecomApprovalEnvelopeHash -Manifest $m2 -ActionsHash $aHash
            $e1 | Should -Not -Be $e2
        }

        It 'Convert-DecomActionToCanonical sorts TargetObjectIds ascending' {
            $a = [ordered]@{
                ActionId='ACT-001'; FindingId='DEC-USER-001'; ObjectId='u'; ObjectType='User'
                DisplayName='T'; UserPrincipalName='t@c.com'; ActionType='RemoveGroupMembership'
                TargetObjectIds=@('zzz','aaa','mmm'); TargetDisplayNames=@('Z','A','M')
                Evidence='e'; RiskScore=50; ProtectedObject=$false
                RoleAssignmentId=''; RoleDefinitionId=''; RoleDisplayName=''
            }
            $canon = Convert-DecomActionToCanonical -Action $a
            $canon.TargetObjectIds | Should -Be @('aaa','mmm','zzz')
        }
    }

    Context 'Test-DecomWhatIfManifest' {

        It 'Valid WhatIf manifest passes' {
            $m = @{ RunId=[guid]::NewGuid().ToString(); Mode='WhatIfRemediation'
                    EngagementId='ENG-001'; GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o') }
            $p = Join-Path $TestDrive 'whatif-valid.json'
            $m | ConvertTo-Json | Set-Content $p -Encoding UTF8
            $r = Test-DecomWhatIfManifest -ManifestPath $p -CurrentEngagementId 'ENG-001'
            $r.Valid | Should -Be $true
        }

        It 'Missing WhatIf manifest file fails' {
            $r = Test-DecomWhatIfManifest -ManifestPath 'C:\NoSuchPath\x.json' -CurrentEngagementId 'ENG-001'
            $r.Valid | Should -Be $false
        }

        It 'RunId not a GUID fails' {
            $m = @{ RunId='not-a-guid'; Mode='WhatIfRemediation'
                    EngagementId='ENG-001'; GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o') }
            $p = Join-Path $TestDrive 'whatif-badguid.json'
            $m | ConvertTo-Json | Set-Content $p -Encoding UTF8
            $r = Test-DecomWhatIfManifest -ManifestPath $p -CurrentEngagementId 'ENG-001'
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match 'GUID' }) | Should -Not -BeNullOrEmpty
        }

        It 'Mode not WhatIfRemediation fails' {
            $m = @{ RunId=[guid]::NewGuid().ToString(); Mode='Assessment'
                    EngagementId='ENG-001'; GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o') }
            $p = Join-Path $TestDrive 'whatif-badmode.json'
            $m | ConvertTo-Json | Set-Content $p -Encoding UTF8
            $r = Test-DecomWhatIfManifest -ManifestPath $p -CurrentEngagementId 'ENG-001'
            $r.Valid | Should -Be $false
        }

        It 'EngagementId mismatch fails' {
            $m = @{ RunId=[guid]::NewGuid().ToString(); Mode='WhatIfRemediation'
                    EngagementId='ENG-999'; GeneratedUtc=(Get-Date).ToUniversalTime().ToString('o') }
            $p = Join-Path $TestDrive 'whatif-engmismatch.json'
            $m | ConvertTo-Json | Set-Content $p -Encoding UTF8
            $r = Test-DecomWhatIfManifest -ManifestPath $p -CurrentEngagementId 'ENG-001'
            $r.Valid | Should -Be $false
        }

        It 'GeneratedUtc older than 7 days fails' {
            $m = @{ RunId=[guid]::NewGuid().ToString(); Mode='WhatIfRemediation'
                    EngagementId='ENG-001'
                    GeneratedUtc=(Get-Date).AddDays(-8).ToUniversalTime().ToString('o') }
            $p = Join-Path $TestDrive 'whatif-stale.json'
            $m | ConvertTo-Json | Set-Content $p -Encoding UTF8
            $r = Test-DecomWhatIfManifest -ManifestPath $p -CurrentEngagementId 'ENG-001'
            $r.Valid | Should -Be $false
        }
    }

    Context 'Test-DecomApprovalManifest' {

        BeforeAll {
            $script:sharedRunId = [guid]::NewGuid().ToString()
        }

        It 'Valid approval manifest passes' {
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId
            $p = Join-Path $TestDrive 'appr-valid.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId
            $r.Valid | Should -Be $true
        }

        It 'ApprovalStatus not Approved fails' {
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId
            $m['ApprovalStatus'] = 'PendingSignature'
            $p = Join-Path $TestDrive 'appr-notapproved.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match 'ApprovalStatus' }) | Should -Not -BeNullOrEmpty
        }

        It 'Duplicate ActionId rejected' {
            $acts = @(
                [ordered]@{ ActionId='ACT-001'; FindingId='DEC-USER-001'; ObjectId='u1'; ObjectType='User'
                  DisplayName='T'; UserPrincipalName='t@c.com'; ActionType='RemoveGroupMembership'
                  TargetObjectIds=@('g1'); TargetDisplayNames=@('G1'); Evidence='e'; RiskScore=50
                  ProtectedObject=$false; RoleAssignmentId=''; RoleDefinitionId=''; RoleDisplayName='' },
                [ordered]@{ ActionId='ACT-001'; FindingId='DEC-USER-001'; ObjectId='u1'; ObjectType='User'
                  DisplayName='T'; UserPrincipalName='t@c.com'; ActionType='RemoveGroupMembership'
                  TargetObjectIds=@('g2'); TargetDisplayNames=@('G2'); Evidence='e'; RiskScore=50
                  ProtectedObject=$false; RoleAssignmentId=''; RoleDefinitionId=''; RoleDisplayName='' }
            )
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId -Actions $acts
            $p = Join-Path $TestDrive 'appr-dupid.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match '[Dd]uplicate' -and $_ -match 'ActionId' }) | Should -Not -BeNullOrEmpty
        }

        It 'Duplicate target operation rejected' {
            $acts = @(
                [ordered]@{ ActionId='ACT-001'; FindingId='DEC-USER-001'; ObjectId='u1'; ObjectType='User'
                  DisplayName='T'; UserPrincipalName='t@c.com'; ActionType='RemoveGroupMembership'
                  TargetObjectIds=@('grp-001','grp-001'); TargetDisplayNames=@('G','G')
                  Evidence='e'; RiskScore=50; ProtectedObject=$false
                  RoleAssignmentId=''; RoleDefinitionId=''; RoleDisplayName='' }
            )
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId -Actions $acts
            $p = Join-Path $TestDrive 'appr-dupop.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match '[Dd]uplicate' }) | Should -Not -BeNullOrEmpty
        }

        It 'ActionType/FindingId mismatch rejected' {
            $acts = @(
                [ordered]@{ ActionId='ACT-001'; FindingId='DEC-USER-001'; ObjectId='u1'; ObjectType='User'
                  DisplayName='T'; UserPrincipalName='t@c.com'; ActionType='RevokeAppRoleAssignment'
                  TargetObjectIds=@('g1'); TargetDisplayNames=@('G1'); Evidence='e'; RiskScore=50
                  ProtectedObject=$false; RoleAssignmentId=''; RoleDefinitionId=''; RoleDisplayName='' }
            )
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId -Actions $acts
            $p = Join-Path $TestDrive 'appr-typemismatch.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match 'ActionType' }) | Should -Not -BeNullOrEmpty
        }

        It 'Role action with multiple TargetObjectIds rejected' {
            $acts = @(
                [ordered]@{ ActionId='ACT-001'; FindingId='DEC-USER-003'; ObjectId='u1'; ObjectType='User'
                  DisplayName='T'; UserPrincipalName='t@c.com'; ActionType='RemoveDirectoryRoleAssignment'
                  TargetObjectIds=@('ra-001','ra-002'); TargetDisplayNames=@('R1','R2')
                  Evidence='e'; RiskScore=90; ProtectedObject=$false
                  RoleAssignmentId='ra-001'; RoleDefinitionId='rd-001'; RoleDisplayName='Role' }
            )
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId -Actions $acts
            $p = Join-Path $TestDrive 'appr-multirole.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId
            $r.Valid | Should -Be $false
        }

        It 'RoleAssignmentId not equal to TargetObjectIds[0] rejected' {
            $acts = @(
                [ordered]@{ ActionId='ACT-001'; FindingId='DEC-USER-003'; ObjectId='u1'; ObjectType='User'
                  DisplayName='T'; UserPrincipalName='t@c.com'; ActionType='RemoveDirectoryRoleAssignment'
                  TargetObjectIds=@('ra-001'); TargetDisplayNames=@('R1')
                  Evidence='e'; RiskScore=90; ProtectedObject=$false
                  RoleAssignmentId='ra-DIFFERENT'; RoleDefinitionId='rd-001'; RoleDisplayName='Role' }
            )
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId -Actions $acts
            $p = Join-Path $TestDrive 'appr-roleassignmismatch.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match 'RoleAssignmentId' }) | Should -Not -BeNullOrEmpty
        }

        It 'WhatIfRunId mismatch rejected' {
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId
            $p = Join-Path $TestDrive 'appr-runidmismatch.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId 'completely-different-run-id'
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match 'WhatIfRunId' }) | Should -Not -BeNullOrEmpty
        }

        It 'ApprovedActionsHash mismatch rejected' {
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId
            $m['ApprovedActionsHash'] = 'aabbcc1122tampered'
            $p = Join-Path $TestDrive 'appr-badhash.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match '[Hh]ash' }) | Should -Not -BeNullOrEmpty
        }

        It 'NonInteractive without AllowNonInteractive rejected' {
            $m = New-TestApprovalManifest -WhatIfRunId $script:sharedRunId -AllowNonInteractive $false
            $p = Join-Path $TestDrive 'appr-noninteractive.json'
            $m | ConvertTo-Json -Depth 10 | Set-Content $p -Encoding UTF8
            $r = Test-DecomApprovalManifest -ManifestPath $p -CurrentEngagementId 'ENG-001' `
                -CurrentClientName 'Contoso' -WhatIfRunId $script:sharedRunId -NonInteractive
            $r.Valid | Should -Be $false
            ($r.Errors | Where-Object { $_ -match 'NonInteractive' -or $_ -match 'AllowNonInteractive' }) | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Entry point ExecuteRemediation branch ordering' {

        BeforeAll {
            $script:epPath = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
            $script:epText = Get-Content $script:epPath -Raw
        }

        It 'Gate A and Gate B validated before Connect-MgGraph' {
            $posA    = $script:epText.IndexOf('Test-DecomWhatIfManifest')
            $posB    = $script:epText.IndexOf('Test-DecomApprovalManifest')
            $posConn = $script:epText.IndexOf('Connect-MgGraph')
            $posA    | Should -BeGreaterThan 0
            $posB    | Should -BeGreaterThan 0
            $posConn | Should -BeGreaterThan 0
            $posA    | Should -BeLessThan $posConn
            $posB    | Should -BeLessThan $posConn
        }

        It 'ExecuteRemediation branch exits before discovery' {
            $posExit = $script:epText.IndexOf('exit 0')
            $posDisc = $script:epText.IndexOf('Invoke-DecomAssessmentDiscovery')
            $posExit | Should -BeGreaterThan 0
            $posDisc | Should -BeGreaterThan 0
            $posExit | Should -BeLessThan $posDisc
        }

        It 'DemoMode guard blocks ExecuteRemediation' {
            $script:epText | Should -Match 'ExecuteRemediation cannot run in DemoMode'
        }
    }
}

Describe 'Rev2.2 Safety Tests' {

    BeforeAll {
        $script:epPath22   = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
        $script:discPath22 = Join-Path $PSScriptRoot '..\..\src\Modules\Discovery.psm1'
        $script:remPath22  = Join-Path $PSScriptRoot '..\..\src\Modules\Remediation.psm1'
    }

    Context 'Rev2.2 write scope safety' {
        It 'Entry point does not add PrivilegedAccess.ReadWrite scope' {
            $content = Get-Content $script:epPath22 -Raw
            $content | Should -Not -Match 'PrivilegedAccess\.ReadWrite'
        }

        It 'Rev3.0: Entry point EntitlementManagement.ReadWrite scope, if present, is bounded to ExecuteRemediation' {
            $content = Get-Content $script:epPath22 -Raw
            if ($content -match 'EntitlementManagement\.ReadWrite') {
                $posEM   = $content.IndexOf('EntitlementManagement.ReadWrite')
                $posExec = $content.IndexOf('ExecuteRemediation')
                $posEM | Should -BeGreaterThan $posExec
            }
        }

        It 'Entry point does not add AccessReview.ReadWrite scope' {
            $content = Get-Content $script:epPath22 -Raw
            $content | Should -Not -Match 'AccessReview\.ReadWrite'
        }
    }

    Context 'Rev2.2 Discovery.psm1 write verb safety' {
        It 'Discovery.psm1 contains no Update-Mg calls' {
            $content = Get-Content $script:discPath22 -Raw
            $content | Should -Not -Match '\bUpdate-Mg'
        }

        It 'Rev3.0: Remediation.psm1 contains authorized DEC-AP and DEC-PIM write action registrations' {
            $content = Get-Content $script:remPath22 -Raw
            $content | Should -Match 'DEC-AP-001'
            $content | Should -Match 'DEC-PIM-001'
        }
    }
}

Describe 'Rev2.4 Safety Tests' {

    BeforeAll {
        $script:epPath24       = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
        $script:baselinePath24 = Join-Path $PSScriptRoot '..\..\src\Modules\Baseline.psm1'
        $script:execPackPath24 = Join-Path $PSScriptRoot '..\..\src\Modules\ExecutivePack.psm1'
        $script:remPath24      = Join-Path $PSScriptRoot '..\..\src\Modules\Remediation.psm1'
    }

    Context 'Rev2.4 write scope safety' {

        It 'Entry point contains no unauthorized ReadWrite scope additions' {
            $content = Get-Content $script:epPath24 -Raw
            $content | Should -Not -Match 'AccessReview\.ReadWrite'
            $content | Should -Not -Match 'PrivilegedAccess\.ReadWrite'
            $content | Should -Not -Match 'Directory\.ReadWrite'
            $content | Should -Not -Match 'User\.ReadWrite'
            $content | Should -Not -Match 'Group\.ReadWrite'
        }

        It 'Baseline.psm1 contains no Graph write cmdlets' {
            $content = Get-Content $script:baselinePath24 -Raw
            $content | Should -Not -Match '\bRemove-Mg'
            $content | Should -Not -Match '\bUpdate-Mg'
            $content | Should -Not -Match '\bSet-Mg'
            $content | Should -Not -Match '\bNew-Mg'
            $content | Should -Not -Match '\bInvoke-Mg'
        }

        It 'ExecutivePack.psm1 contains no Graph write cmdlets' {
            $content = Get-Content $script:execPackPath24 -Raw
            $content | Should -Not -Match '\bRemove-Mg'
            $content | Should -Not -Match '\bUpdate-Mg'
            $content | Should -Not -Match '\bSet-Mg'
            $content | Should -Not -Match '\bNew-Mg'
            $content | Should -Not -Match '\bInvoke-Mg'
        }

        It 'ExecutivePack.psm1 contains no ReadWrite scope references' {
            $content = Get-Content $script:execPackPath24 -Raw
            $content | Should -Not -Match 'ReadWrite'
        }

        It 'Baseline.psm1 contains no ReadWrite scope references' {
            $content = Get-Content $script:baselinePath24 -Raw
            $content | Should -Not -Match 'ReadWrite'
        }
    }

    Context 'Rev2.4 Remediation.psm1 unchanged' {

        It 'Remediation.psm1 exists and is loadable' {
            Test-Path $script:remPath24 | Should -Be $true
        }

        It 'Remediation.psm1 does not reference Baseline or ExecutivePack functions' {
            $content = Get-Content $script:remPath24 -Raw
            $content | Should -Not -Match 'Import-DecomBaselineFindings'
            $content | Should -Not -Match 'New-DecomExecutiveSummaryModel'
            $content | Should -Not -Match 'Export-DecomExecutiveSummary'
        }
    }

    Context 'Rev2.4 ExecuteRemediation branch unchanged' {

        It 'ExecuteRemediation guard still present in entry point' {
            $content = Get-Content $script:epPath24 -Raw
            $content | Should -Match 'ExecuteRemediation cannot run in DemoMode'
        }

        It 'Gate ordering unchanged — WhatIf and Approval gates before Connect-MgGraph' {
            $content = Get-Content $script:epPath24 -Raw
            $posA    = $content.IndexOf('Test-DecomWhatIfManifest')
            $posB    = $content.IndexOf('Test-DecomApprovalManifest')
            $posConn = $content.IndexOf('Connect-MgGraph')
            $posA    | Should -BeGreaterThan 0
            $posB    | Should -BeGreaterThan 0
            $posConn | Should -BeGreaterThan 0
            $posA    | Should -BeLessThan $posConn
            $posB    | Should -BeLessThan $posConn
        }

        It 'ToolVersion is Rev3.4 in entry point' {
            $content = Get-Content $script:epPath24 -Raw
            $content | Should -Match "\`$script:ToolVersion\s*=\s*'Rev3\.4'"
        }
    }

    Context 'Rev2.4 catalog conformance — no new unapproved finding IDs in Baseline or ExecutivePack' {

        It 'Baseline.psm1 does not define new DEC- finding IDs' {
            $content = Get-Content $script:baselinePath24 -Raw
            $content | Should -Not -Match "'DEC-[A-Z]+-\d{3}'"
        }

        It 'ExecutivePack.psm1 does not define new DEC- finding IDs' {
            $content = Get-Content $script:execPackPath24 -Raw
            $content | Should -Not -Match "'DEC-[A-Z]+-\d{3}'"
        }
    }
}

Describe 'Rev2.5 Safety Tests' {

    BeforeAll {
        $script:epPath25             = Join-Path $PSScriptRoot '..\..\Invoke-EntraIdentityDecommissioningControlPlane.ps1'
        $script:remPath25            = Join-Path $PSScriptRoot '..\..\src\Modules\Remediation.psm1'
        $script:catalogValPath25     = Join-Path $PSScriptRoot '..\..\src\Modules\CatalogValidation.psm1'
        $script:schemaContractsPath25= Join-Path $PSScriptRoot '..\..\src\Modules\SchemaContracts.psm1'
        $script:writeReadinessPath25 = Join-Path $PSScriptRoot '..\..\src\Modules\WriteReadiness.psm1'
        $script:releaseValPath25     = Join-Path $PSScriptRoot '..\..\src\Modules\ReleaseValidation.psm1'
        $script:releasePkgPath25     = Join-Path $PSScriptRoot '..\..\src\Modules\ReleasePackaging.psm1'
    }

    Context 'Rev2.5 new modules contain no write verbs' {

        It 'CatalogValidation.psm1 contains no Graph write cmdlets' {
            $content = Get-Content $script:catalogValPath25 -Raw
            $content | Should -Not -Match '\bRemove-Mg'
            $content | Should -Not -Match '\bUpdate-Mg'
            $content | Should -Not -Match '\bSet-Mg'
            $content | Should -Not -Match '\bNew-Mg'
            $content | Should -Not -Match '\bInvoke-MgGraphRequest'
        }

        It 'SchemaContracts.psm1 contains no Graph write cmdlets' {
            $content = Get-Content $script:schemaContractsPath25 -Raw
            $content | Should -Not -Match '\bRemove-Mg'
            $content | Should -Not -Match '\bUpdate-Mg'
            $content | Should -Not -Match '\bSet-Mg'
            $content | Should -Not -Match '\bNew-Mg'
            $content | Should -Not -Match '\bInvoke-MgGraphRequest'
        }

        It 'ReleasePackaging.psm1 contains no Graph write cmdlets' {
            $content = Get-Content $script:releasePkgPath25 -Raw
            $content | Should -Not -Match '\bRemove-Mg'
            $content | Should -Not -Match '\bUpdate-Mg'
            $content | Should -Not -Match '\bSet-Mg'
            $content | Should -Not -Match '\bNew-Mg'
            $content | Should -Not -Match '\bInvoke-MgGraphRequest'
        }
    }

    Context 'Rev2.5 new modules contain no unexpected write scopes' {

        It 'CatalogValidation.psm1 contains no ReadWrite scope references' {
            $content = Get-Content $script:catalogValPath25 -Raw
            $content | Should -Not -Match 'ReadWrite'
        }

        It 'SchemaContracts.psm1 contains no ReadWrite scope references' {
            $content = Get-Content $script:schemaContractsPath25 -Raw
            $content | Should -Not -Match 'ReadWrite'
        }

        It 'ReleasePackaging.psm1 contains no ReadWrite scope references' {
            $content = Get-Content $script:releasePkgPath25 -Raw
            $content | Should -Not -Match 'ReadWrite'
        }
    }

    Context 'Rev2.5 Remediation.psm1 executable scope unchanged' {

        It 'Remediation.psm1 does not reference Rev2.5 validation modules' {
            $content = Get-Content $script:remPath25 -Raw
            $content | Should -Not -Match 'CatalogValidation'
            $content | Should -Not -Match 'SchemaContracts'
            $content | Should -Not -Match 'WriteReadiness'
            $content | Should -Not -Match 'ReleaseValidation'
        }

        It 'Remediation.psm1 contains authorized action types and excludes permanently unauthorized ones' {
            $content = Get-Content $script:remPath25 -Raw
            $content | Should -Match 'RemoveAccessPackageAssignment'
            $content | Should -Match 'RemovePimEligibleAssignment'
            $content | Should -Match 'RemoveGuestGroupMembership'
            $content | Should -Match 'AddApplicationOwner'           # authorized Rev3.3
            $content | Should -Match 'RemoveCAExclusionGroupMember'  # authorized Rev3.3
            $content | Should -Not -Match 'RemoveExpiredCredential'  # not a valid action name
            $content | Should -Not -Match 'DeleteOrDisableApp'
            $content | Should -Not -Match 'DeleteServicePrincipal'
        }
    }

    Context 'Rev2.5 ApprovalManifest execution map unchanged' {

        It 'Entry point ApprovalManifest processing still guards on ApprovedActions' {
            $content = Get-Content $script:epPath25 -Raw
            $content | Should -Match 'ApprovedActions'
        }

        It 'Entry point does not add new ExecuteRemediation action types' {
            $content = Get-Content $script:epPath25 -Raw
            $content | Should -Not -Match 'RemoveAccessPackageAssignment'
            $content | Should -Not -Match 'RemovePimEligibleAssignment'
            $content | Should -Not -Match 'DeleteOrDisableApp'
            $content | Should -Not -Match 'DeleteServicePrincipal'
        }
    }

    Context 'Rev2.5 ExecuteRemediation branch ordering unchanged' {

        It 'SelfTest exits before Connect-MgGraph in entry point' {
            $content = Get-Content $script:epPath25 -Raw
            $posSelfTest = $content.IndexOf('if ($SelfTest)')
            $posConnect  = $content.IndexOf('Connect-MgGraph')
            $posSelfTest | Should -BeGreaterThan 0
            $posConnect  | Should -BeGreaterThan 0
            $posSelfTest | Should -BeLessThan $posConnect
        }

        It 'ExecuteRemediation guard still present in Rev2.5 entry point' {
            $content = Get-Content $script:epPath25 -Raw
            $content | Should -Match 'ExecuteRemediation cannot run in DemoMode'
        }

        It 'Entry point contains no unauthorized write scope additions' {
            $content = Get-Content $script:epPath25 -Raw
            $content | Should -Not -Match 'AccessReview\.ReadWrite'
            $content | Should -Not -Match 'PrivilegedAccess\.ReadWrite'
            $content | Should -Not -Match 'Directory\.ReadWrite'
            $content | Should -Not -Match 'User\.ReadWrite'
        }
    }
}
