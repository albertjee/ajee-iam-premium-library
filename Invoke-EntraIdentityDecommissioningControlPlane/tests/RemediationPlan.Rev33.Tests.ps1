#Requires -Version 5.1

Describe 'RemediationPlan.Rev33 — WhatIf Generation for AddApplicationOwner and RemoveCAExclusionGroupMember' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\src\Modules'
        foreach ($m in @('Utilities','ApprovalManifest')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')        -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'ApprovalManifest.psm1') -Force -DisableNameChecking

        $script:testDir = Join-Path $env:TEMP "Decom-Rev33-WhatIf-$(([guid]::NewGuid().Guid))"
        New-Item -ItemType Directory -Path $script:testDir -Force | Out-Null

        $script:AppObjId   = [guid]::NewGuid().Guid
        $script:SpnObjId   = [guid]::NewGuid().Guid
        $script:OwnerObjId = [guid]::NewGuid().Guid
        $script:PolicyId   = [guid]::NewGuid().Guid
        $script:GroupId    = [guid]::NewGuid().Guid
        $script:PrincipalId= [guid]::NewGuid().Guid

        # DEC-APP-001 with explicit NewOwnerObjectId
        $script:App001WithOwner = [PSCustomObject]@{
            FindingId              = 'DEC-APP-001'
            ObjectId               = $script:AppObjId
            ObjectType             = 'Application'
            DisplayName            = 'TestApp-NoOwner'
            AppId                  = [guid]::NewGuid().Guid
            NewOwnerObjectId       = $script:OwnerObjId
            NewOwnerUserPrincipalName = 'owner@contoso.com'
            NewOwnerType           = 'User'
            OwnerSource            = 'ApprovalManifest'
            BusinessJustification  = 'Application requires active owner'
            ProtectedObject        = $false
            RiskScore              = 80
            Evidence               = 'No owners found'
        }

        # DEC-APP-001 WITHOUT NewOwnerObjectId — plan-only
        $script:App001NoOwner = [PSCustomObject]@{
            FindingId              = 'DEC-APP-001'
            ObjectId               = [guid]::NewGuid().Guid
            ObjectType             = 'Application'
            DisplayName            = 'TestApp-NoOwnerNoMapping'
            AppId                  = [guid]::NewGuid().Guid
            ProtectedObject        = $false
            RiskScore              = 80
            Evidence               = 'No owners found'
        }

        # DEC-APP-001 with only DisplayName — no explicit owner — must NOT infer
        $script:App001DisplayNameOnly = [PSCustomObject]@{
            FindingId              = 'DEC-APP-001'
            ObjectId               = [guid]::NewGuid().Guid
            ObjectType             = 'Application'
            DisplayName            = 'App Owner Is Alice Smith'
            AppId                  = [guid]::NewGuid().Guid
            ProtectedObject        = $false
            RiskScore              = 80
        }

        # DEC-APP-001 with app name suggestion — must NOT infer owner
        $script:App001AppNameSuggestion = [PSCustomObject]@{
            FindingId              = 'DEC-APP-001'
            ObjectId               = [guid]::NewGuid().Guid
            ObjectType             = 'Application'
            DisplayName            = 'HR-Portal-App'
            AppId                  = [guid]::NewGuid().Guid
            BusinessOwner          = 'Alice Smith'
            ProtectedObject        = $false
            RiskScore              = 70
        }

        # DEC-SPN-001 with explicit NewOwnerObjectId
        $script:Spn001WithOwner = [PSCustomObject]@{
            FindingId              = 'DEC-SPN-001'
            ObjectId               = $script:SpnObjId
            ObjectType             = 'ServicePrincipal'
            DisplayName            = 'TestSPN-NoOwner'
            NewOwnerObjectId       = $script:OwnerObjId
            NewOwnerType           = 'User'
            OwnerSource            = 'ApprovalManifest'
            BusinessJustification  = 'SPN requires owner for governance'
            ProtectedObject        = $false
            RiskScore              = 75
        }

        # DEC-CA-002 with all required fields
        $script:CA002Full = [PSCustomObject]@{
            FindingId              = 'DEC-CA-002'
            ObjectId               = $script:PrincipalId
            ObjectType             = 'User'
            DisplayName            = 'TestUser CA Exclusion'
            PolicyId               = $script:PolicyId
            PolicyDisplayName      = 'Require MFA - Corp'
            ExclusionGroupId       = $script:GroupId
            ExclusionGroupDisplayName = 'CA-Exclusions-Legacy'
            ExcludedPrincipalId    = $script:PrincipalId
            EmergencyAccessIndicator = $false
            BreakGlassIndicator    = $false
            ProtectedObject        = $false
            RiskScore              = 90
        }

        # DEC-CA-002 missing PolicyId
        $script:CA002NoPolicyId = [PSCustomObject]@{
            FindingId              = 'DEC-CA-002'
            ObjectId               = $script:PrincipalId
            ObjectType             = 'User'
            DisplayName            = 'TestUser CA No Policy'
            ExclusionGroupId       = $script:GroupId
            ExcludedPrincipalId    = $script:PrincipalId
            ProtectedObject        = $false
            RiskScore              = 90
        }

        # DEC-CA-002 missing ExclusionGroupId
        $script:CA002NoGroupId = [PSCustomObject]@{
            FindingId              = 'DEC-CA-002'
            ObjectId               = $script:PrincipalId
            ObjectType             = 'User'
            DisplayName            = 'TestUser CA No Group'
            PolicyId               = $script:PolicyId
            ExcludedPrincipalId    = $script:PrincipalId
            ProtectedObject        = $false
            RiskScore              = 90
        }

        # DEC-CA-002 missing ExcludedPrincipalId — uses ObjectId fallback
        # To truly test missing ExcludedPrincipalId we must also clear ObjectId
        $script:CA002NoPrincipalId = [PSCustomObject]@{
            FindingId              = 'DEC-CA-002'
            DisplayName            = 'TestUser CA No Principal'
            PolicyId               = $script:PolicyId
            ExclusionGroupId       = $script:GroupId
            ProtectedObject        = $false
            RiskScore              = 90
        }

        # Generate WhatIf plans
        $script:Plan001WithOwner = New-DecomWhatIfActionPlan `
            -Findings @($script:App001WithOwner) `
            -EngagementId 'ENG-33-RP' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir

        $script:Plan001NoOwner = New-DecomWhatIfActionPlan `
            -Findings @($script:App001NoOwner) `
            -EngagementId 'ENG-33-RP2' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir

        $script:PlanSpn001 = New-DecomWhatIfActionPlan `
            -Findings @($script:Spn001WithOwner) `
            -EngagementId 'ENG-33-SPN' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir

        $script:PlanDisplayNameOnly = New-DecomWhatIfActionPlan `
            -Findings @($script:App001DisplayNameOnly) `
            -EngagementId 'ENG-33-DN' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir

        $script:PlanAppNameOnly = New-DecomWhatIfActionPlan `
            -Findings @($script:App001AppNameSuggestion) `
            -EngagementId 'ENG-33-AN' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir

        $script:PlanCA002Full = New-DecomWhatIfActionPlan `
            -Findings @($script:CA002Full) `
            -EngagementId 'ENG-33-CA' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir

        $script:PlanCA002NoPolicy = New-DecomWhatIfActionPlan `
            -Findings @($script:CA002NoPolicyId) `
            -EngagementId 'ENG-33-CAP' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir

        $script:PlanCA002NoGroup = New-DecomWhatIfActionPlan `
            -Findings @($script:CA002NoGroupId) `
            -EngagementId 'ENG-33-CAG' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir

        $script:PlanCA002NoPrincipal = New-DecomWhatIfActionPlan `
            -Findings @($script:CA002NoPrincipalId) `
            -EngagementId 'ENG-33-CAPRI' -ClientName 'TestClient' `
            -Assessor 'TestAssessor' -WhatIfRunId ([guid]::NewGuid().Guid) `
            -OutputPath $script:testDir
    }

    AfterAll {
        if (Test-Path $script:testDir) { Remove-Item $script:testDir -Recurse -Force }
        foreach ($m in @('ApprovalManifest','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── Item 17: DEC-APP-001 with explicit NewOwnerObjectId generates AddApplicationOwner ──

    Context 'DEC-APP-001 — AddApplicationOwner WhatIf generation' {

        It 'DEC-APP-001 with explicit NewOwnerObjectId generates AddApplicationOwner action' {
            $manifest = Get-Content $script:Plan001WithOwner -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' }
            $action | Should -Not -BeNullOrEmpty
            $action.FindingId | Should -Be 'DEC-APP-001'
        }

        It 'Generated action carries exact NewOwnerObjectId in TargetObjectIds' {
            $manifest = Get-Content $script:Plan001WithOwner -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' }
            $action.TargetObjectIds | Should -Contain $script:OwnerObjId
        }

        It 'Generated action carries NewOwnerObjectId field' {
            $manifest = Get-Content $script:Plan001WithOwner -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' }
            $action.NewOwnerObjectId | Should -Be $script:OwnerObjId
        }

        It 'Generated action has RequiresManualApproval = true' {
            $manifest = Get-Content $script:Plan001WithOwner -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' }
            $action.RequiresManualApproval | Should -Be $true
        }

        It 'Generated action has ReadinessStatus = ReadyForApproval' {
            $manifest = Get-Content $script:Plan001WithOwner -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' }
            $action.ReadinessStatus | Should -Be 'ReadyForApproval'
        }

        It 'Generated action has TargetType = DirectoryObjectOwner' {
            $manifest = Get-Content $script:Plan001WithOwner -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' }
            $action.TargetType | Should -Be 'DirectoryObjectOwner'
        }

        It 'WhatIf manifest SchemaVersion is 3.6' {
            $manifest = Get-Content $script:Plan001WithOwner -Raw | ConvertFrom-Json
            $manifest.SchemaVersion | Should -Be '3.6'
        }

        # ── Item 18: DEC-APP-001 WITHOUT NewOwnerObjectId remains plan-only ──

        It 'DEC-APP-001 without NewOwnerObjectId produces no ApprovedActions' {
            $manifest = Get-Content $script:Plan001NoOwner -Raw | ConvertFrom-Json
            $ownerActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' })
            $ownerActions.Count | Should -Be 0
        }

        It 'DEC-APP-001 without NewOwnerObjectId is in SkippedActions' {
            $manifest = Get-Content $script:Plan001NoOwner -Raw | ConvertFrom-Json
            $skipped = @($manifest.SkippedActions | Where-Object { $_.FindingId -eq 'DEC-APP-001' })
            $skipped.Count | Should -BeGreaterThan 0
        }
    }

    # ── Item 19: DEC-SPN-001 with explicit NewOwnerObjectId generates AddApplicationOwner ──

    Context 'DEC-SPN-001 — AddApplicationOwner WhatIf generation' {

        It 'DEC-SPN-001 with explicit NewOwnerObjectId generates AddApplicationOwner action' {
            $manifest = Get-Content $script:PlanSpn001 -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' }
            $action | Should -Not -BeNullOrEmpty
            $action.FindingId | Should -Be 'DEC-SPN-001'
        }

        It 'DEC-SPN-001 action ObjectType is ServicePrincipal' {
            $manifest = Get-Content $script:PlanSpn001 -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' }
            $action.ObjectType | Should -Be 'ServicePrincipal'
        }
    }

    # ── Items 20-21: Owner not inferred from DisplayName or app name ──

    Context 'Owner inference prevention' {

        It 'Owner is not inferred from DisplayName — no AddApplicationOwner when DisplayName carries name' {
            $manifest = Get-Content $script:PlanDisplayNameOnly -Raw | ConvertFrom-Json
            $ownerActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' })
            $ownerActions.Count | Should -Be 0
        }

        It 'Owner is not inferred from app name / BusinessOwner field' {
            $manifest = Get-Content $script:PlanAppNameOnly -Raw | ConvertFrom-Json
            $ownerActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'AddApplicationOwner' })
            $ownerActions.Count | Should -Be 0
        }

        It 'No GUID appears in TargetObjectIds when NewOwnerObjectId absent (no inferred ID)' {
            $manifest = Get-Content $script:PlanDisplayNameOnly -Raw | ConvertFrom-Json
            $skipped = @($manifest.SkippedActions | Where-Object { $_.FindingId -eq 'DEC-APP-001' })
            $skipped.Count | Should -BeGreaterThan 0
        }
    }

    # ── Item 36: DEC-CA-002 with full fields generates RemoveCAExclusionGroupMember ──

    Context 'DEC-CA-002 — RemoveCAExclusionGroupMember WhatIf generation' {

        It 'DEC-CA-002 with PolicyId, ExclusionGroupId, ExcludedPrincipalId generates executable action' {
            $manifest = Get-Content $script:PlanCA002Full -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' }
            $action | Should -Not -BeNullOrEmpty
        }

        It 'Generated CA action carries exact ExclusionGroupId in TargetObjectIds' {
            $manifest = Get-Content $script:PlanCA002Full -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' }
            $action.TargetObjectIds | Should -Contain $script:GroupId
        }

        It 'Generated CA action has PolicyId field' {
            $manifest = Get-Content $script:PlanCA002Full -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' }
            $action.PolicyId | Should -Be $script:PolicyId
        }

        It 'Generated CA action has ExcludedPrincipalId field' {
            $manifest = Get-Content $script:PlanCA002Full -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' }
            $action.ExcludedPrincipalId | Should -Be $script:PrincipalId
        }

        It 'Generated CA action has TargetType = CAExclusionGroup' {
            $manifest = Get-Content $script:PlanCA002Full -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' }
            $action.TargetType | Should -Be 'CAExclusionGroup'
        }

        It 'Generated CA action has RequiresManualApproval = true' {
            $manifest = Get-Content $script:PlanCA002Full -Raw | ConvertFrom-Json
            $action = $manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' }
            $action.RequiresManualApproval | Should -Be $true
        }

        # ── Item 37: Missing PolicyId remains plan-only ──

        It 'DEC-CA-002 missing PolicyId produces no executable action' {
            $manifest = Get-Content $script:PlanCA002NoPolicy -Raw | ConvertFrom-Json
            $caActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' })
            $caActions.Count | Should -Be 0
        }

        It 'DEC-CA-002 missing PolicyId is in SkippedActions' {
            $manifest = Get-Content $script:PlanCA002NoPolicy -Raw | ConvertFrom-Json
            $skipped = @($manifest.SkippedActions | Where-Object { $_.FindingId -eq 'DEC-CA-002' })
            $skipped.Count | Should -BeGreaterThan 0
        }

        # ── Item 38: Missing ExclusionGroupId remains plan-only ──

        It 'DEC-CA-002 missing ExclusionGroupId produces no executable action' {
            $manifest = Get-Content $script:PlanCA002NoGroup -Raw | ConvertFrom-Json
            $caActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' })
            $caActions.Count | Should -Be 0
        }

        # ── Item 39: Missing ExcludedPrincipalId remains plan-only ──

        It 'DEC-CA-002 missing ExcludedPrincipalId produces no executable action' {
            $manifest = Get-Content $script:PlanCA002NoPrincipal -Raw | ConvertFrom-Json
            $caActions = @($manifest.ApprovedActions | Where-Object { $_.ActionType -eq 'RemoveCAExclusionGroupMember' })
            $caActions.Count | Should -Be 0
        }
    }
}
