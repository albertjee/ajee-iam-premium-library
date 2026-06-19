#Requires -Modules Pester
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '', Scope='Function')]
param()

Describe 'Rev4.10 NHI Controlled Removal Simulation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'

        foreach ($m in @('Utilities', 'ApprovalManifest', 'NhiControlledDecommission')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }

        $script:UtilitiesModule = Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1') -Force -DisableNameChecking -PassThru
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'NhiControlledDecommission.psm1') -Force -DisableNameChecking
        $script:NewDecomFindingCommand = $script:UtilitiesModule.ExportedFunctions['New-DecomFinding']

        function script:New-TestFinding {
            param(
                [string]$FindingId,
                [string]$DisplayName,
                [string]$Classification,
                [bool]$MicrosoftPlatform,
                [bool]$FirstPartyMicrosoftApp,
                [bool]$SuppressCustomerRemediation,
                [string]$RemediationMode,
                [string]$RecommendedAction,
                [string]$TargetObjectId = ([guid]::NewGuid().Guid),
                [string]$ApprovalStatus = 'Approved',
                [string]$ApprovalSchemaVersion = '4.2',
                [string]$ClassificationSource = 'Catalog',
                [object[]]$ClassificationSignals = @('catalog')
            )

            $finding = & $script:NewDecomFindingCommand `
                -FindingId $FindingId `
                -Category 'Application' `
                -Severity 'High' `
                -RiskScore 85 `
                -Confidence 'High' `
                -ObjectType 'ServicePrincipal' `
                -ObjectId $TargetObjectId `
                -DisplayName $DisplayName `
                -Evidence "Synthetic finding for $DisplayName" `
                -EvidenceSource 'unit-test' `
                -RecommendedAction $RecommendedAction `
                -RemediationMode $RemediationMode

            foreach ($pair in @(
                @{ Name = 'Classification'; Value = $Classification },
                @{ Name = 'ClassificationConfidence'; Value = 'High' },
                @{ Name = 'ClassificationSource'; Value = $ClassificationSource },
                @{ Name = 'ClassificationSignals'; Value = $ClassificationSignals },
                @{ Name = 'MicrosoftPlatform'; Value = $MicrosoftPlatform },
                @{ Name = 'FirstPartyMicrosoftApp'; Value = $FirstPartyMicrosoftApp },
                @{ Name = 'SuppressCustomerRemediation'; Value = $SuppressCustomerRemediation },
                @{ Name = 'EvidenceOnly'; Value = [string]$RemediationMode -in @('InformationOnly','EvidenceOnly') }
            )) {
                $finding | Add-Member -NotePropertyName $pair.Name -NotePropertyValue $pair.Value -Force
            }

            return $finding
        }

        function script:New-Approval {
            param(
                [string]$RunId,
                [string[]]$TargetObjectIds,
                [string[]]$ApprovedActions,
                [string]$ApprovedBy = 'unit-test',
                [string]$Status = 'Approved',
                [string]$SchemaVersion = '4.2',
                [string]$ExpiresUtc = ([DateTime]::UtcNow.AddDays(1).ToString('o'))
            )

            [PSCustomObject]@{
                SchemaVersion    = $SchemaVersion
                ApprovedBy       = $ApprovedBy
                Status           = $Status
                RunId            = $RunId
                WhatIfRunId      = $RunId
                ApprovalStatus   = $Status
                ApprovedUtc      = [DateTime]::UtcNow.ToString('o')
                Reusable         = $false
                ExpiresUtc       = $ExpiresUtc
                TargetObjectIds  = @($TargetObjectIds)
                ApprovedActions  = @($ApprovedActions)
                PlanOnlyActions  = @()
                SkippedActions   = @()
                AllowNonInteractive = $false
            }
        }

        function script:Resolve-ExecutableTargetsOffline {
            param(
                [object[]]$Findings,
                [object]$Approval
            )

            $candidateNames = @(
                'Resolve-DecomExecutableTargets',
                'New-DecomWhatIfActionPlan'
            )
            $cmd = $null
            foreach ($candidate in $candidateNames) {
                $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
                if ($null -ne $cmd) { break }
            }
            if ($null -eq $cmd) {
                throw 'No controlled planning/executable-target function is available for this test.'
            }

            $parameters = $cmd.Parameters.Keys
            $splat = @{}

            foreach ($name in @('Findings','InputFindings','Finding','ApprovedFindings','WhatIfFindings')) {
                if ($parameters -contains $name) { $splat[$name] = $Findings; break }
            }
            foreach ($name in @('Approval','ApprovalManifest','ApprovedManifest','Manifest','ApprovalInput')) {
                if ($parameters -contains $name) { $splat[$name] = $Approval; break }
            }

            if ($parameters -contains 'Context') {
                $splat['Context'] = [PSCustomObject]@{ Mode = 'WhatIfRemediation'; OutputPath = $env:TEMP }
            }
            if ($parameters -contains 'WhatIfExecution') {
                $splat['WhatIfExecution'] = $true
            }
            if ($parameters -contains 'NonInteractive') {
                $splat['NonInteractive'] = $true
            }

            if ($splat.Count -eq 0) {
                throw 'Resolve-DecomExecutableTargets parameter surface could not be mapped for this test.'
            }

            $result = & $cmd @splat

            if ($null -eq $result) { return @() }
            if ($result -is [System.Collections.IEnumerable] -and -not ($result -is [string])) {
                $items = @()
                foreach ($item in @($result)) {
                    if ($null -eq $item) { continue }
                    foreach ($propertyName in @('Actions', 'ExecutableTargets', 'PlannedActions', 'ApprovedActions')) {
                        $nested = $item.PSObject.Properties[$propertyName]
                        if ($null -ne $nested -and $null -ne $nested.Value) {
                            $items += @($nested.Value)
                            continue 2
                        }
                    }
                    $items += $item
                }
                return @($items)
            }

            foreach ($propertyName in @('Actions', 'ExecutableTargets', 'PlannedActions', 'ApprovedActions')) {
                $nested = $result.PSObject.Properties[$propertyName]
                if ($null -ne $nested -and $null -ne $nested.Value) {
                    return @($nested.Value)
                }
            }

            return @($result)
        }

        function script:Invoke-WhatIfPlanOffline {
            param(
                [object[]]$Findings
            )

            $candidateNames = @(
                'New-DecomWhatIfActionPlan',
                'Resolve-DecomExecutableTargets'
            )
            $cmd = $null
            foreach ($candidate in $candidateNames) {
                $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
                if ($null -ne $cmd) { break }
            }
            if ($null -eq $cmd) {
                throw 'No WhatIf/plan function is available for this test.'
            }

            $parameters = $cmd.Parameters.Keys
            $splat = @{}
            foreach ($name in @('Findings','InputFindings','Finding','WhatIfFindings')) {
                if ($parameters -contains $name) { $splat[$name] = $Findings; break }
            }
            $tempPath = Join-Path $env:TEMP ("rev410-whatif-plan-{0}" -f ([guid]::NewGuid().Guid))
            New-Item -ItemType Directory -Path $tempPath -Force | Out-Null
            if ($parameters -contains 'Path') {
                $splat['Path'] = $tempPath
            } elseif ($parameters -contains 'OutputPath') {
                $splat['OutputPath'] = $tempPath
            } elseif ($parameters -contains 'WhatIfManifestPath') {
                $splat['WhatIfManifestPath'] = $tempPath
            }
            if ($parameters -contains 'Context') {
                $splat['Context'] = [PSCustomObject]@{ Mode = 'WhatIfRemediation'; OutputPath = $env:TEMP }
            }
            if ($parameters -contains 'WhatIfExecution') {
                $splat['WhatIfExecution'] = $true
            }
            if ($splat.Count -eq 0) {
                throw 'WhatIf plan parameter surface could not be mapped for this test.'
            }

            $result = & $cmd @splat
            if ($result -is [string] -and (Test-Path $result)) {
                $result = Get-Content -LiteralPath $result -Raw
            } elseif ($null -ne $result -and $result.PSObject.Properties['Path'] -and (Test-Path $result.Path)) {
                $result = Get-Content -LiteralPath $result.Path -Raw
            } elseif (Test-Path $tempPath) {
                $candidate = Get-ChildItem -LiteralPath $tempPath -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($null -ne $candidate) {
                    $result = Get-Content -LiteralPath $candidate.FullName -Raw
                }
            }
            Remove-Item -LiteralPath $tempPath -Recurse -Force -ErrorAction SilentlyContinue
            if ($null -eq $result) { return @() }
            if ($result -is [System.Collections.IEnumerable] -and -not ($result -is [string])) {
                return @($result)
            }
            return @($result)
        }

        function script:Get-ActionText {
            param([object]$Action)
            if ($null -eq $Action) { return '' }
            if ($Action.PSObject.Properties['Action']) { return [string]$Action.Action }
            if ($Action.PSObject.Properties['ActionType']) { return [string]$Action.ActionType }
            if ($Action.PSObject.Properties['RecommendedAction']) { return [string]$Action.RecommendedAction }
            return ($Action | Out-String)
        }
    }

    AfterAll {
        foreach ($m in @('NhiControlledDecommission', 'ApprovalManifest', 'Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    Context 'Module safety' {
        It 'exports controlled planning and approval helpers' {
            Get-Command Test-NhiControlledTarget -ErrorAction Stop | Should -Not -BeNullOrEmpty
            Get-Command Confirm-NhiControlledApproval -ErrorAction Stop | Should -Not -BeNullOrEmpty
            Get-Command Resolve-DecomExecutableTargets -ErrorAction Stop | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Fail-closed simulation for platform identities and approvals' {
        BeforeAll {
            $script:RunId = 'RUN-REV410-SIM-001'
            $script:ApprovedTargetId = [guid]::NewGuid().Guid
            $script:UnapprovedTargetId = [guid]::NewGuid().Guid

            $script:MicrosoftFinding = New-TestFinding `
                -FindingId 'SIM-MS-001' `
                -DisplayName 'Microsoft Graph PowerShell' `
                -Classification 'MicrosoftPlatform' `
                -MicrosoftPlatform $true `
                -FirstPartyMicrosoftApp $true `
                -SuppressCustomerRemediation $true `
                -RemediationMode 'InformationOnly' `
                -RecommendedAction 'Assign owner using AddApplicationOwner action'

            $script:AppleFinding = New-TestFinding `
                -FindingId 'SIM-APPLE-001' `
                -DisplayName 'iOS Accounts' `
                -Classification 'ExternalVendorPlatform' `
                -MicrosoftPlatform $false `
                -FirstPartyMicrosoftApp $false `
                -SuppressCustomerRemediation $true `
                -RemediationMode 'InformationOnly' `
                -RecommendedAction 'Verify publisher through Microsoft Partner Center'

            $script:ApprovedCustomerFinding = New-TestFinding `
                -FindingId 'SIM-CUST-001' `
                -DisplayName 'Contoso App' `
                -Classification 'CustomerOwned' `
                -MicrosoftPlatform $false `
                -FirstPartyMicrosoftApp $false `
                -SuppressCustomerRemediation $false `
                -RemediationMode 'ManualApprovalRequired' `
                -RecommendedAction 'Assign owner using AddApplicationOwner action' `
                -TargetObjectId $script:ApprovedTargetId `
                -ApprovalStatus 'Approved'

            $script:UnapprovedCustomerFinding = New-TestFinding `
                -FindingId 'SIM-CUST-002' `
                -DisplayName 'Unapproved App' `
                -Classification 'CustomerOwned' `
                -MicrosoftPlatform $false `
                -FirstPartyMicrosoftApp $false `
                -SuppressCustomerRemediation $false `
                -RemediationMode 'ManualApprovalRequired' `
                -RecommendedAction 'Assign owner using AddApplicationOwner action' `
                -TargetObjectId $script:UnapprovedTargetId `
                -ApprovalStatus 'Pending'

            $script:ApprovedManifest = New-Approval `
                -RunId $script:RunId `
                -TargetObjectIds @($script:ApprovedTargetId) `
                -ApprovedActions @('AddApplicationOwner') `
                -ApprovedBy 'unit-test'

            $script:IncompleteManifest = [PSCustomObject]@{
                SchemaVersion   = '4.2'
                ApprovedBy      = 'unit-test'
                Status          = 'Approved'
                RunId           = $script:RunId
                Reusable        = $false
                ExpiresUtc      = [DateTime]::UtcNow.AddDays(1).ToString('o')
                TargetObjectIds = @($script:ApprovedTargetId)
                ApprovedActions = @()
            }

            $script:MissingMetadataManifest = [PSCustomObject]@{
                SchemaVersion   = '4.2'
                Status          = 'Approved'
                RunId           = $script:RunId
                Reusable        = $false
                ExpiresUtc      = $null
                TargetObjectIds = @($script:ApprovedTargetId)
                ApprovedActions = @('AddApplicationOwner')
            }
        }

        It 'blocks Microsoft platform findings from executable target resolution' {
            $microsoft = @(Resolve-ExecutableTargetsOffline -Findings @($script:MicrosoftFinding) -Approval $script:ApprovedManifest)
            $ios = @(Resolve-ExecutableTargetsOffline -Findings @($script:AppleFinding) -Approval $script:ApprovedManifest)
            $approved = @(Resolve-ExecutableTargetsOffline -Findings @($script:ApprovedCustomerFinding) -Approval $script:ApprovedManifest)
            $unapproved = @(Resolve-ExecutableTargetsOffline -Findings @($script:UnapprovedCustomerFinding) -Approval $script:ApprovedManifest)

            $microsoft.Count | Should -Be 1
            $microsoft[0].Resolved | Should -Be $false
            $microsoft[0].TargetObjects.Count | Should -Be 0
            ($microsoft[0].ErrorDetail | Out-String) | Should -Match 'Microsoft platform identity is evidence-only|suppressed'

            $ios.Count | Should -Be 1
            $ios[0].Resolved | Should -Be $false
            $ios[0].TargetObjects.Count | Should -Be 0
            ($ios[0].ErrorDetail | Out-String) | Should -Match 'evidence-only|suppressed'

            $approved.Count | Should -Be 1
            $approved[0].Resolved | Should -Be $false
            ($approved[0].ErrorDetail | Out-String) | Should -Not -Match 'Microsoft platform identity is evidence-only|suppressed|final delete|AllowFinalDelete'

            $unapproved.Count | Should -Be 1
            $unapproved[0].Resolved | Should -Be $false
            $unapproved[0].TargetObjects.Count | Should -Be 0
            ($unapproved[0].ErrorDetail | Out-String) | Should -Match 'not in execution scope|Target is not approved|approved'

            $rendered = (@($microsoft, $ios, $approved, $unapproved) | Out-String)
            $rendered | Should -Not -Match 'final delete|AllowFinalDelete|Remove-MgServicePrincipal|Remove-MgApplication'
        }

        It 'returns explainable suppression signals for platform findings' {
            $script:MicrosoftFinding.SuppressCustomerRemediation | Should -Be $true
            $script:MicrosoftFinding.RemediationMode | Should -Be 'InformationOnly'
            $script:MicrosoftFinding.Classification | Should -Be 'MicrosoftPlatform'

            $script:AppleFinding.SuppressCustomerRemediation | Should -Be $true
            $script:AppleFinding.RemediationMode | Should -Be 'InformationOnly'
            $script:AppleFinding.Classification | Should -Be 'ExternalVendorPlatform'
        }

        It 'approval validation fails closed when required approval metadata is missing' {
            $missingMetadata = Confirm-NhiControlledApproval -Approval $script:MissingMetadataManifest -RunId $script:RunId -TargetId $script:ApprovedTargetId -ActionType 'AddApplicationOwner'
            $missingMetadata.Passed | Should -Be $false
            $missingMetadata.Reasons | Should -Contain 'ApprovedBy is required.'
            $missingMetadata.Reasons | Should -Contain 'Approval ExpiresUtc is required.'

            $result = Confirm-NhiControlledApproval -Approval $script:IncompleteManifest -RunId $script:RunId -TargetId $script:ApprovedTargetId -ActionType 'AddApplicationOwner'
            $result.Passed | Should -Be $false
            $result.Reasons | Should -Contain 'Action is not approved.'
        }

        It 'approved customer target passes validation while unapproved target does not' {
            $approved = Confirm-NhiControlledApproval -Approval $script:ApprovedManifest -RunId $script:RunId -TargetId $script:ApprovedTargetId -ActionType 'AddApplicationOwner'
            $approved.Passed | Should -Be $true

            $unapproved = Confirm-NhiControlledApproval -Approval $script:ApprovedManifest -RunId $script:RunId -TargetId $script:UnapprovedTargetId -ActionType 'AddApplicationOwner'
            $unapproved.Passed | Should -Be $false
            $unapproved.Reasons | Should -Contain 'Target is not approved.'
        }

        It 'Test-NhiControlledTarget blocks platform identities and allows the approved customer target' {
            $blockedMicrosoft = Test-NhiControlledTarget -Target ([PSCustomObject]@{
                ObjectId              = $script:MicrosoftFinding.ObjectId
                ObjectType            = 'ServicePrincipal'
                ProtectedObject        = $false
                MicrosoftFirstParty    = $true
                EmergencyAccessIndicator = $false
                BreakGlassIndicator    = $false
                HighConfidenceActive   = $false
                Ambiguous              = $false
            })
            $blockedMicrosoft.Passed | Should -Be $false

            $blockedApple = Test-NhiControlledTarget -Target ([PSCustomObject]@{
                ObjectId              = $script:AppleFinding.ObjectId
                ObjectType            = 'ServicePrincipal'
                ProtectedObject        = $false
                MicrosoftFirstParty    = $false
                EmergencyAccessIndicator = $false
                BreakGlassIndicator    = $false
                HighConfidenceActive   = $false
                Ambiguous              = $false
            })
            $blockedApple.Passed | Should -Be $true

            $approvedTarget = Test-NhiControlledTarget -Target ([PSCustomObject]@{
                ObjectId              = $script:ApprovedTargetId
                ObjectType            = 'ServicePrincipal'
                ProtectedObject        = $false
                MicrosoftFirstParty    = $false
                EmergencyAccessIndicator = $false
                BreakGlassIndicator    = $false
                HighConfidenceActive   = $false
                Ambiguous              = $false
            })
            $approvedTarget.Passed | Should -Be $true
        }
    }
}
