#Requires -Version 5.1
# INTENTIONAL_HISTORICAL_VERSION: Rev3.5 references are for historical test fixtures

Describe 'ApprovalManifest.Rev33 — Rev3.3 Action Type Validation' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking

        $script:appObjId    = [guid]::NewGuid().Guid
        $script:ownerObjId  = [guid]::NewGuid().Guid
        $script:principalId = [guid]::NewGuid().Guid
        $script:groupId     = [guid]::NewGuid().Guid
        $script:policyId    = [guid]::NewGuid().Guid

        $script:testOutputDir = Join-Path $env:TEMP "Decom-Rev33-AM-$(([guid]::NewGuid().Guid))"
        New-Item -ItemType Directory -Path $script:testOutputDir -Force | Out-Null

        function Build-MinimalManifest {
            param([hashtable]$Override = @{})
            $actions = @([PSCustomObject]@{
                ActionId  = 'ACT-001'
                FindingId = 'DEC-APP-001'
                ObjectId  = $script:appObjId
                ObjectType = 'Application'
                DisplayName = 'Test App'
                ActionType = 'AddApplicationOwner'
                TargetObjectIds = @($script:ownerObjId)
                ProtectedObject = $false
                Ownership = [ordered]@{
                    NewOwnerObjectId           = $script:ownerObjId
                    NewOwnerUserPrincipalName = 'owner@contoso.com'
                    NewOwnerType               = 'User'
                    OwnerSource                = 'ApprovalManifest'
                    BusinessJustification     = 'Application requires active owner'
                    AllowGuestOwner           = $false
                }
            })
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $manifest = [ordered]@{
                SchemaVersion       = '3.3'
                ToolVersion         = 'Rev3.5'
                GeneratedUtc        = (Get-Date).ToUniversalTime().ToString('o')
                EngagementId        = 'ENG-33-AM'
                ClientName          = 'TestClient'
                WhatIfRunId         = [guid]::NewGuid().Guid
                ApprovalStatus      = 'Approved'
                ApprovedBy          = 'Jane Approver, CISO'
                ApprovedUtc         = (Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc          = (Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive = $false
                ApprovedActionsHash  = ''
                ApprovalEnvelopeHash = ''
                ApprovedActions     = $actions
            }
            foreach ($k in $Override.Keys) { $manifest[$k] = $Override[$k] }
            $actionsHash2 = Get-DecomApprovedActionsHash -ApprovedActions $manifest.ApprovedActions
            $manifest.ApprovedActionsHash = $actionsHash2
            $obj = [PSCustomObject]$manifest
            $envHash = Get-DecomApprovalEnvelopeHash -Manifest $obj -ActionsHash $actionsHash2
            $manifest.ApprovalEnvelopeHash = $envHash
            $path = Join-Path $script:testOutputDir "manifest-$([guid]::NewGuid().Guid).json"
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            return $path
        }
    }

    AfterAll {
        if (Test-Path $script:testOutputDir) { Remove-Item $script:testOutputDir -Recurse -Force }
        foreach ($m in @('ApprovalManifest','Utilities')) { Remove-Module $m -Force -ErrorAction SilentlyContinue }
    }

    Context 'AddApplicationOwner — canonical hash changes with owner fields' {

        It 'Hash changes when NewOwnerObjectId changes' {
            $a1 = [PSCustomObject]@{ ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                                     ActionType='AddApplicationOwner'; TargetObjectIds=@($script:ownerObjId)
                                     NewOwnerObjectId=$script:ownerObjId; BusinessJustification='test'
                                     ProtectedObject=$false }
            $a2 = [PSCustomObject]@{ ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                                     ActionType='AddApplicationOwner'; TargetObjectIds=@([guid]::NewGuid().Guid)
                                     NewOwnerObjectId=[guid]::NewGuid().Guid; BusinessJustification='test'
                                     ProtectedObject=$false }
            $h1 = Get-DecomApprovedActionsHash -ApprovedActions @($a1)
            $h2 = Get-DecomApprovedActionsHash -ApprovedActions @($a2)
            $h1 | Should -Not -Be $h2
        }

        It 'Hash changes when BusinessJustification changes' {
            $a1 = [PSCustomObject]@{ ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                                     ActionType='AddApplicationOwner'; TargetObjectIds=@($script:ownerObjId)
                                     NewOwnerObjectId=$script:ownerObjId; BusinessJustification='JustificationA'
                                     ProtectedObject=$false }
            $a2 = $a1 | Select-Object *
            $a2 = [PSCustomObject]@{ ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                                     ActionType='AddApplicationOwner'; TargetObjectIds=@($script:ownerObjId)
                                     NewOwnerObjectId=$script:ownerObjId; BusinessJustification='JustificationB'
                                     ProtectedObject=$false }
            $h1 = Get-DecomApprovedActionsHash -ApprovedActions @($a1)
            $h2 = Get-DecomApprovedActionsHash -ApprovedActions @($a2)
            $h1 | Should -Not -Be $h2
        }
    }

    Context 'AddApplicationOwner — approval manifest validation' {

        It 'Valid AddApplicationOwner passes approval validation' {
            $path = Build-MinimalManifest
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }

        It 'Missing NewOwnerObjectId in approved action fails' {
            $actions = @([PSCustomObject]@{
                ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                ObjectType='Application'; ActionType='AddApplicationOwner'
                TargetObjectIds=@($script:ownerObjId); NewOwnerObjectId=''
                BusinessJustification='test'; ProtectedObject=$false
            })
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $path = Join-Path $script:testOutputDir "manifest-missing-owner-$([guid]::NewGuid().Guid).json"
            $manifest = [ordered]@{
                SchemaVersion='3.3'; EngagementId='ENG-33-AM'; ClientName='TestClient'
                WhatIfRunId=[guid]::NewGuid().Guid; ApprovalStatus='Approved'
                ApprovedBy='Jane CISO'; ApprovedUtc=(Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc=(Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive=$false; ApprovedActionsHash=$actionsHash
                ApprovalEnvelopeHash='placeholder'; ApprovedActions=$actions
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'NewOwnerObjectId' }) | Should -Not -BeNullOrEmpty
        }

        It 'Missing BusinessJustification fails' {
            $actions = @([PSCustomObject]@{
                ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                ObjectType='Application'; ActionType='AddApplicationOwner'
                TargetObjectIds=@($script:ownerObjId); NewOwnerObjectId=$script:ownerObjId
                BusinessJustification=''; ProtectedObject=$false
            })
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $path = Join-Path $script:testOutputDir "manifest-no-bizjust-$([guid]::NewGuid().Guid).json"
            $manifest = [ordered]@{
                SchemaVersion='3.3'; EngagementId='ENG-33-AM'; ClientName='TestClient'
                WhatIfRunId=[guid]::NewGuid().Guid; ApprovalStatus='Approved'
                ApprovedBy='Jane CISO'; ApprovedUtc=(Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc=(Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive=$false; ApprovedActionsHash=$actionsHash
                ApprovalEnvelopeHash='placeholder'; ApprovedActions=$actions
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'BusinessJustification' }) | Should -Not -BeNullOrEmpty
        }

        It 'Invalid FindingId for AddApplicationOwner fails' {
            $actions = @([PSCustomObject]@{
                ActionId='ACT-001'; FindingId='DEC-USER-001'; ObjectId=$script:appObjId
                ObjectType='Application'; ActionType='AddApplicationOwner'
                TargetObjectIds=@($script:ownerObjId); NewOwnerObjectId=$script:ownerObjId
                BusinessJustification='test'; ProtectedObject=$false
            })
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $path = Join-Path $script:testOutputDir "manifest-bad-fid-$([guid]::NewGuid().Guid).json"
            $manifest = [ordered]@{
                SchemaVersion='3.3'; EngagementId='ENG-33-AM'; ClientName='TestClient'
                WhatIfRunId=[guid]::NewGuid().Guid; ApprovalStatus='Approved'
                ApprovedBy='Jane CISO'; ApprovedUtc=(Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc=(Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive=$false; ApprovedActionsHash=$actionsHash
                ApprovalEnvelopeHash='placeholder'; ApprovedActions=$actions
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
        }

        It 'SchemaVersion 3.2 rejects AddApplicationOwner' {
            $path = Build-MinimalManifest -Override @{ SchemaVersion = '3.2' }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match '3\.3' }) | Should -Not -BeNullOrEmpty
        }

        It 'ProtectedObject action fails for AddApplicationOwner' {
            $actions = @([PSCustomObject]@{
                ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                ObjectType='Application'; ActionType='AddApplicationOwner'
                TargetObjectIds=@($script:ownerObjId); NewOwnerObjectId=$script:ownerObjId
                BusinessJustification='test'; ProtectedObject=$true
            })
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $path = Join-Path $script:testOutputDir "manifest-protected-$([guid]::NewGuid().Guid).json"
            $manifest = [ordered]@{
                SchemaVersion='3.3'; EngagementId='ENG-33-AM'; ClientName='TestClient'
                WhatIfRunId=[guid]::NewGuid().Guid; ApprovalStatus='Approved'
                ApprovedBy='Jane CISO'; ApprovedUtc=(Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc=(Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive=$false; ApprovedActionsHash=$actionsHash
                ApprovalEnvelopeHash='placeholder'; ApprovedActions=$actions
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'ProtectedObject' }) | Should -Not -BeNullOrEmpty
        }

        It 'AddApplicationOwner rejected when NewOwnerObjectId not in TargetObjectIds' {
            $differentObjId = [guid]::NewGuid().Guid
            $actions = @([PSCustomObject]@{
                ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                ObjectType='Application'; ActionType='AddApplicationOwner'
                TargetObjectIds=@($script:ownerObjId)
                NewOwnerObjectId=$differentObjId
                BusinessJustification='test owner'; ProtectedObject=$false
            })
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $path = Join-Path $script:testOutputDir "manifest-ownerid-mismatch-$([guid]::NewGuid().Guid).json"
            $manifest = [ordered]@{
                SchemaVersion='3.3'; EngagementId='ENG-33-AM'; ClientName='TestClient'
                WhatIfRunId=[guid]::NewGuid().Guid; ApprovalStatus='Approved'
                ApprovedBy='Jane CISO'; ApprovedUtc=(Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc=(Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive=$false; ApprovedActionsHash=$actionsHash
                ApprovalEnvelopeHash='placeholder'; ApprovedActions=$actions
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'NewOwnerObjectId.*TargetObjectIds|TargetObjectIds.*NewOwnerObjectId' }) | Should -Not -BeNullOrEmpty
        }

        It 'AddApplicationOwner accepted when NewOwnerObjectId matches TargetObjectIds' {
            # Already covered by 'Valid AddApplicationOwner passes' but make explicit
            $path = Build-MinimalManifest
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $true
        }

        It 'Duplicate owner-add operation fails' {
            $actions = @(
                [PSCustomObject]@{
                    ActionId='ACT-001'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                    ObjectType='Application'; ActionType='AddApplicationOwner'
                    TargetObjectIds=@($script:ownerObjId); NewOwnerObjectId=$script:ownerObjId
                    BusinessJustification='test'; ProtectedObject=$false },
                [PSCustomObject]@{
                    ActionId='ACT-002'; FindingId='DEC-APP-001'; ObjectId=$script:appObjId
                    ObjectType='Application'; ActionType='AddApplicationOwner'
                    TargetObjectIds=@($script:ownerObjId); NewOwnerObjectId=$script:ownerObjId
                    BusinessJustification='test2'; ProtectedObject=$false }
            )
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $path = Join-Path $script:testOutputDir "manifest-dup-$([guid]::NewGuid().Guid).json"
            $manifest = [ordered]@{
                SchemaVersion='3.3'; EngagementId='ENG-33-AM'; ClientName='TestClient'
                WhatIfRunId=[guid]::NewGuid().Guid; ApprovalStatus='Approved'
                ApprovedBy='Jane CISO'; ApprovedUtc=(Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc=(Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive=$false; ApprovedActionsHash=$actionsHash
                ApprovalEnvelopeHash='placeholder'; ApprovedActions=$actions
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-AM' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
        }
    }

    Context 'RemoveCAExclusionGroupMember — approval manifest validation' {

        BeforeAll {
        function Build-CAManifest {
            param([hashtable]$Override = @{}, [hashtable]$ActionOverride = @{})
            $baseAction = @{
                ActionId    = 'ACT-001'
                FindingId   = 'DEC-CA-002'
                ObjectId    = $script:principalId
                ObjectType  = 'User'
                ActionType  = 'RemoveCAExclusionGroupMember'
                TargetObjectIds = @($script:groupId)
                ProtectedObject = $false
                CAExclusion = [ordered]@{
                    PolicyId                 = $script:policyId
                    ExclusionGroupId         = $script:groupId
                    ExcludedPrincipalId      = $script:principalId
                    EmergencyAccessIndicator = $false
                    BreakGlassIndicator      = $false
                }
            }
            # Apply top-level overrides; also propagate CAExclusion field overrides so that
            # e.g. ActionOverride @{ PolicyId = '' } updates CAExclusion.PolicyId.
            $caExclKeys = @('PolicyId','ExclusionGroupId','ExcludedPrincipalId',
                            'EmergencyAccessIndicator','BreakGlassIndicator')
            foreach ($k in $ActionOverride.Keys) {
                if ($caExclKeys -contains $k) {
                    $baseAction.CAExclusion[$k] = $ActionOverride[$k]
                } else {
                    $baseAction[$k] = $ActionOverride[$k]
                }
            }
            $actions = @([PSCustomObject]$baseAction)
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $manifest = [ordered]@{
                SchemaVersion='3.3'; EngagementId='ENG-33-CA'; ClientName='TestClient'
                WhatIfRunId=[guid]::NewGuid().Guid; ApprovalStatus='Approved'
                ApprovedBy='Jane CISO'; ApprovedUtc=(Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc=(Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive=$false; ApprovedActionsHash=$actionsHash
                ApprovalEnvelopeHash='placeholder'; ApprovedActions=$actions
            }
            foreach ($k in $Override.Keys) { $manifest[$k] = $Override[$k] }
            $manifest.ApprovedActionsHash = Get-DecomApprovedActionsHash -ApprovedActions $manifest.ApprovedActions
            $obj = [PSCustomObject]$manifest
            $manifest.ApprovalEnvelopeHash = Get-DecomApprovalEnvelopeHash -Manifest $obj -ActionsHash $manifest.ApprovedActionsHash
            $path = Join-Path $script:testOutputDir "manifest-ca-$([guid]::NewGuid().Guid).json"
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            return $path
        }
        } # end BeforeAll

        It 'Valid RemoveCAExclusionGroupMember passes approval validation' {
            $path = Build-CAManifest
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }

        It 'Missing PolicyId fails' {
            $path = Build-CAManifest -ActionOverride @{ PolicyId = '' }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'PolicyId' }) | Should -Not -BeNullOrEmpty
        }

        It 'ProtectedObject fails for CA exclusion removal' {
            $path = Build-CAManifest -ActionOverride @{ ProtectedObject = $true }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'ProtectedObject' }) | Should -Not -BeNullOrEmpty
        }

        It 'EmergencyAccessIndicator true fails' {
            $path = Build-CAManifest -ActionOverride @{ EmergencyAccessIndicator = $true }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'Emergency' }) | Should -Not -BeNullOrEmpty
        }

        It 'BreakGlassIndicator true fails' {
            $path = Build-CAManifest -ActionOverride @{ BreakGlassIndicator = $true }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'BreakGlass' }) | Should -Not -BeNullOrEmpty
        }

        It 'SchemaVersion 3.2 rejects RemoveCAExclusionGroupMember' {
            $path = Build-CAManifest -Override @{ SchemaVersion = '3.2' }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match '3\.3' }) | Should -Not -BeNullOrEmpty
        }

        It 'Invalid FindingId for RemoveCAExclusionGroupMember fails' {
            $path = Build-CAManifest -ActionOverride @{ FindingId = 'DEC-USER-001' }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
        }

        It 'RemoveCAExclusionGroupMember rejected when ExcludedPrincipalId missing' {
            $path = Build-CAManifest -ActionOverride @{ ExcludedPrincipalId = '' }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'ExcludedPrincipalId' }) | Should -Not -BeNullOrEmpty
        }

        It 'RemoveCAExclusionGroupMember rejected when ObjectId != ExcludedPrincipalId' {
            $differentPrincipal = [guid]::NewGuid().Guid
            $path = Build-CAManifest -ActionOverride @{ ObjectId = $differentPrincipal }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'ObjectId.*ExcludedPrincipalId|ExcludedPrincipalId.*ObjectId' }) | Should -Not -BeNullOrEmpty
        }

        It 'RemoveCAExclusionGroupMember rejected when ExclusionGroupId not in TargetObjectIds' {
            $differentGroup = [guid]::NewGuid().Guid
            $path = Build-CAManifest -ActionOverride @{ ExclusionGroupId = $differentGroup }
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
            ($result.Errors | Where-Object { $_ -match 'ExclusionGroupId.*TargetObjectIds|TargetObjectIds.*ExclusionGroupId' }) | Should -Not -BeNullOrEmpty
        }

        It 'Valid exact-bound CA exclusion approval passes' {
            # Baseline: valid manifest where ObjectId == ExcludedPrincipalId and ExclusionGroupId in TargetObjectIds
            $path = Build-CAManifest
            $manifest = Get-Content $path -Raw | ConvertFrom-Json
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $true
            $result.Errors.Count | Should -Be 0
        }

        It 'Duplicate CA exclusion removal operation fails' {
            $actions = @(
                [PSCustomObject]@{
                    ActionId    = 'ACT-001'
                    FindingId   = 'DEC-CA-002'
                    ObjectId    = $script:principalId
                    ObjectType  = 'User'
                    ActionType  = 'RemoveCAExclusionGroupMember'
                    TargetObjectIds = @($script:groupId)
                    ProtectedObject = $false
                    CAExclusion = [ordered]@{
                        PolicyId                 = $script:policyId
                        ExclusionGroupId          = $script:groupId
                        ExcludedPrincipalId       = $script:principalId
                        EmergencyAccessIndicator  = $false
                        BreakGlassIndicator       = $false
                    }
                },
                [PSCustomObject]@{
                    ActionId    = 'ACT-002'
                    FindingId   = 'DEC-CA-003'
                    ObjectId    = $script:principalId
                    ObjectType  = 'User'
                    ActionType  = 'RemoveCAExclusionGroupMember'
                    TargetObjectIds = @($script:groupId)
                    ProtectedObject = $false
                    CAExclusion = [ordered]@{
                        PolicyId                 = $script:policyId
                        ExclusionGroupId          = $script:groupId
                        ExcludedPrincipalId       = $script:principalId
                        EmergencyAccessIndicator  = $false
                        BreakGlassIndicator       = $false
                    }
                }
            )
            $actionsHash = Get-DecomApprovedActionsHash -ApprovedActions $actions
            $path = Join-Path $script:testOutputDir "manifest-dup-ca-$([guid]::NewGuid().Guid).json"
            $manifest = [ordered]@{
                SchemaVersion='3.3'; EngagementId='ENG-33-CA'; ClientName='TestClient'
                WhatIfRunId=[guid]::NewGuid().Guid; ApprovalStatus='Approved'
                ApprovedBy='Jane CISO'; ApprovedUtc=(Get-Date).ToUniversalTime().ToString('o')
                ExpiresUtc=(Get-Date).AddDays(3).ToUniversalTime().ToString('o')
                AllowNonInteractive=$false; ApprovedActionsHash=$actionsHash
                ApprovalEnvelopeHash='placeholder'; ApprovedActions=$actions
            }
            $manifest | ConvertTo-Json -Depth 10 | Set-Content $path -Encoding UTF8
            $result = Test-DecomApprovalManifest -ManifestPath $path -CurrentEngagementId 'ENG-33-CA' `
                -CurrentClientName 'TestClient' -WhatIfRunId $manifest.WhatIfRunId
            $result.Valid | Should -Be $false
        }
    }
}
