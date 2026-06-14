#Requires -Version 5.1

#Requires -Version 5.1

if (-not (Get-Command Get-DecomToolVersion -ErrorAction SilentlyContinue)) {
    function Get-DecomToolVersion { 'Rev4.10' }
}

function New-DecomRev3CapabilityMatrix {
    [CmdletBinding()]
    param(
        [PSCustomObject]$Context
    )

    $actions = @(
        # Rev2.0
        [PSCustomObject]@{ Release='Rev2.0'; FindingId='DEC-USER-001'; ActionType='RemoveGroupMembership';            WriteScope='GroupMember.ReadWrite.All';                Status='Executable';          RiskLevel='Medium'; Notes='Remove group membership for disabled/stale user' }
        [PSCustomObject]@{ Release='Rev2.0'; FindingId='DEC-USER-002'; ActionType='RevokeAppRoleAssignment';          WriteScope='AppRoleAssignment.ReadWrite.All';           Status='Executable';          RiskLevel='Medium'; Notes='Revoke app role assignment for stale user' }
        [PSCustomObject]@{ Release='Rev2.0'; FindingId='DEC-USER-003'; ActionType='RemoveDirectoryRoleAssignment';    WriteScope='RoleManagement.ReadWrite.Directory';        Status='Executable';          RiskLevel='High';   Notes='Remove directory role assignment' }
        [PSCustomObject]@{ Release='Rev2.0'; FindingId='DEC-ROLE-001'; ActionType='RemoveDirectoryRoleAssignment';    WriteScope='RoleManagement.ReadWrite.Directory';        Status='Executable';          RiskLevel='High';   Notes='Remove stale directory role assignment' }
        # Rev3.0
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-AP-001';   ActionType='RemoveAccessPackageAssignment';    WriteScope='EntitlementManagement.ReadWrite.All';       Status='Executable';          RiskLevel='High';   Notes='Remove access package assignment via entitlement management' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-AP-002';   ActionType='RemoveAccessPackageAssignment';    WriteScope='EntitlementManagement.ReadWrite.All';       Status='Executable';          RiskLevel='High';   Notes='Remove access package assignment' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-AP-007';   ActionType='RemoveAccessPackageAssignment';    WriteScope='EntitlementManagement.ReadWrite.All';       Status='Executable';          RiskLevel='High';   Notes='Remove stale entitlement assignment' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-AP-008';   ActionType='RemoveAccessPackageAssignment';    WriteScope='EntitlementManagement.ReadWrite.All';       Status='Executable';          RiskLevel='High';   Notes='Remove entitlement assignment' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-PIM-001';  ActionType='RemovePimEligibleAssignment';      WriteScope='RoleManagement.ReadWrite.Directory';        Status='Executable';          RiskLevel='High';   Notes='Remove PIM eligible assignment' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-PIM-002';  ActionType='RemovePimEligibleAssignment';      WriteScope='RoleManagement.ReadWrite.Directory';        Status='Executable';          RiskLevel='High';   Notes='Remove PIM eligible assignment' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-PIM-003';  ActionType='RemovePimEligibleAssignment';      WriteScope='RoleManagement.ReadWrite.Directory';        Status='Executable';          RiskLevel='High';   Notes='Remove PIM eligible assignment' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-PIM-004';  ActionType='RemovePimEligibleAssignment';      WriteScope='RoleManagement.ReadWrite.Directory';        Status='Executable';          RiskLevel='High';   Notes='Remove PIM eligible assignment' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-PIM-005';  ActionType='RemovePimEligibleAssignment';      WriteScope='RoleManagement.ReadWrite.Directory';        Status='Executable';          RiskLevel='High';   Notes='Remove PIM eligible assignment' }
        [PSCustomObject]@{ Release='Rev3.0'; FindingId='DEC-PIM-006';  ActionType='RemovePimEligibleAssignment';      WriteScope='RoleManagement.ReadWrite.Directory';        Status='Executable';          RiskLevel='High';   Notes='Remove PIM eligible assignment' }
        # Rev3.1
        [PSCustomObject]@{ Release='Rev3.1'; FindingId='DEC-GUEST-001'; ActionType='RemoveGuestGroupMembership';     WriteScope='GroupMember.ReadWrite.All';                 Status='ExecutableWhenExactTargetPresent'; RiskLevel='High'; Notes='Remove guest from group' }
        [PSCustomObject]@{ Release='Rev3.1'; FindingId='DEC-GUEST-002'; ActionType='RemoveGuestGroupMembership';     WriteScope='GroupMember.ReadWrite.All';                 Status='ExecutableWhenExactTargetPresent'; RiskLevel='High'; Notes='Remove guest from group' }
        [PSCustomObject]@{ Release='Rev3.1'; FindingId='DEC-GUEST-002'; ActionType='RevokeGuestAppRoleAssignment';   WriteScope='AppRoleAssignment.ReadWrite.All';            Status='ExecutableWhenExactTargetPresent'; RiskLevel='High'; Notes='Revoke guest app role' }
        [PSCustomObject]@{ Release='Rev3.1'; FindingId='DEC-GUEST-003'; ActionType='RemoveGuestGroupMembership';     WriteScope='GroupMember.ReadWrite.All';                 Status='ExecutableWhenExactTargetPresent'; RiskLevel='High'; Notes='Remove guest from group' }
        [PSCustomObject]@{ Release='Rev3.1'; FindingId='DEC-GREV-001';  ActionType='RemoveGuestGroupMembership';     WriteScope='GroupMember.ReadWrite.All';                 Status='ExecutableWhenExactTargetPresent'; RiskLevel='High'; Notes='Remove guest from group (review)' }
        [PSCustomObject]@{ Release='Rev3.1'; FindingId='DEC-GREV-002';  ActionType='RemoveGuestGroupMembership';     WriteScope='GroupMember.ReadWrite.All';                 Status='ExecutableWhenExactTargetPresent'; RiskLevel='High'; Notes='Remove guest from group (review)' }
        [PSCustomObject]@{ Release='Rev3.1'; FindingId='DEC-GREV-003';  ActionType='RemoveGuestGroupMembership';     WriteScope='GroupMember.ReadWrite.All';                 Status='ExecutableWhenExactTargetPresent'; RiskLevel='High'; Notes='Remove guest from group (review)' }
        [PSCustomObject]@{ Release='Rev3.1'; FindingId='DEC-GREV-003';  ActionType='RevokeGuestAppRoleAssignment';   WriteScope='AppRoleAssignment.ReadWrite.All';            Status='ExecutableWhenExactTargetPresent'; RiskLevel='High'; Notes='Revoke guest app role (review)' }
        # Rev3.2
        [PSCustomObject]@{ Release='Rev3.2'; FindingId='DEC-APP-005';  ActionType='RemoveExpiredApplicationCredential'; WriteScope='Application.ReadWrite.All';             Status='ExecutableWhenExactExpiredCredentialKeyIdPresent'; RiskLevel='High'; Notes='Remove expired credential (password or key)' }
        # Rev3.3
        [PSCustomObject]@{ Release='Rev3.3'; FindingId='DEC-APP-001';  ActionType='AddApplicationOwner';             WriteScope='Application.ReadWrite.All';                 Status='ExecutableWhenExactOwnerObjectIdPresent'; RiskLevel='High'; Notes='Add owner to ownerless application' }
        [PSCustomObject]@{ Release='Rev3.3'; FindingId='DEC-APP-002';  ActionType='AddApplicationOwner';             WriteScope='Application.ReadWrite.All';                 Status='ExecutableWhenExactOwnerObjectIdPresent'; RiskLevel='High'; Notes='Add owner — all current owners disabled' }
        [PSCustomObject]@{ Release='Rev3.3'; FindingId='DEC-APP-003';  ActionType='AddApplicationOwner';             WriteScope='Application.ReadWrite.All';                 Status='ExecutableWhenExactOwnerObjectIdPresent'; RiskLevel='High'; Notes='Add owner — fragile single-owner state' }
        [PSCustomObject]@{ Release='Rev3.3'; FindingId='DEC-SPN-001';  ActionType='AddApplicationOwner';             WriteScope='Application.ReadWrite.All';                 Status='ExecutableWhenExactOwnerObjectIdPresent'; RiskLevel='High'; Notes='Add owner to ownerless service principal' }
        [PSCustomObject]@{ Release='Rev3.3'; FindingId='DEC-CA-002';   ActionType='RemoveCAExclusionGroupMember';    WriteScope='GroupMember.ReadWrite.All + Policy.Read.All'; Status='ExecutableWhenExactTargetPresent'; RiskLevel='Critical'; Notes='Remove principal from CA exclusion group' }
        [PSCustomObject]@{ Release='Rev3.3'; FindingId='DEC-CA-003';   ActionType='RemoveCAExclusionGroupMember';    WriteScope='GroupMember.ReadWrite.All + Policy.Read.All'; Status='ExecutableWhenExactTargetPresent'; RiskLevel='Critical'; Notes='Remove principal from CA exclusion group (no review evidence)' }
        [PSCustomObject]@{ Release='Rev3.3'; FindingId='DEC-CA-004';   ActionType='RemoveCAExclusionGroupMember';    WriteScope='GroupMember.ReadWrite.All + Policy.Read.All'; Status='ExecutableWhenExactTargetPresent'; RiskLevel='Critical'; Notes='Remove principal — review decision conflicts with exclusion' }
    )

    $planOnly = @(
        [PSCustomObject]@{ Release='Rev3.3'; FindingId='DEC-APP-002'; ActionType='RemoveDisabledApplicationOwner'; Status='PlanOnly'; Notes='Disabled owner removal requires confirmed replacement owner — deferred to future release' }
        [PSCustomObject]@{ FindingId='*'; ActionType='RemoveNonExpiredCredentialAfterRotationEvidence'; Status='ReadinessOnly'; Notes='Non-expired credential removal requires rotation evidence — readiness guidance only' }
    )

    $deferred = @(
        [PSCustomObject]@{ ActionType='DisableApplication';                Status='Unsafe/Deferred'; Notes='Application disable is irreversible without owner coordination — deferred' }
        [PSCustomObject]@{ ActionType='DisableServicePrincipal';           Status='Unsafe/Deferred'; Notes='Service principal disable may break integrations — deferred' }
        [PSCustomObject]@{ ActionType='ModifyConditionalAccessPolicy';     Status='Unsafe/Deferred'; Notes='CA policy mutation requires Policy.ReadWrite.* — never allowed in this tool' }
        [PSCustomObject]@{ ActionType='ApplyAccessReviewDecision';         Status='Deferred';         Notes='Access review decision application requires AccessReview.ReadWrite.All — deferred' }
        [PSCustomObject]@{ ActionType='DeleteApplication';                 Status='Unsafe/Never';     Notes='Application deletion is permanent and out of scope for this tool' }
        [PSCustomObject]@{ ActionType='DeleteServicePrincipal';            Status='Unsafe/Never';     Notes='Service principal deletion is permanent and out of scope for this tool' }
        [PSCustomObject]@{ ActionType='DeleteUser';                        Status='Unsafe/Never';     Notes='User deletion is out of scope for this tool' }
    )

    $requiredScopes = @(
        [PSCustomObject]@{ Mode='Assessment';         Scopes=@('User.Read.All','Group.Read.All','Application.Read.All','Policy.Read.All','AuditLog.Read.All'); Notes='Read-only assessment' }
        [PSCustomObject]@{ Mode='WhatIfRemediation';  Scopes=@('User.Read.All','Group.Read.All','Application.Read.All','Policy.Read.All'); Notes='Read-only — generates plan and approval template' }
        [PSCustomObject]@{ Mode='ExportPlan';         Scopes=@('User.Read.All','Group.Read.All','Application.Read.All'); Notes='Read-only export' }
        [PSCustomObject]@{ Mode='ExecuteRemediation'; Scopes=@('GroupMember.ReadWrite.All','AppRoleAssignment.ReadWrite.All','RoleManagement.ReadWrite.Directory','EntitlementManagement.ReadWrite.All','Application.ReadWrite.All'); Notes='Write scopes requested only after Gate A and Gate B pass' }
    )

    return [PSCustomObject]@{
        SchemaVersion    = '3.6'
        GeneratedUtc     = (Get-Date).ToUniversalTime().ToString('o')
        ToolVersion = Get-DecomToolVersion
        ExecutableActions = $actions
        PlanOnlyActions  = $planOnly
        DeferredActions  = $deferred
        RequiredScopesByMode = $requiredScopes
        RollbackModel    = 'All write operations are logged with before/after state. Re-query confirms success. No auto-rollback. Manual re-add required.'
        PostWriteEvidenceModel = 'Re-query after every write. Outcome = Executed only when post-write re-query confirms expected state.'
        UnsupportedOperations = @('CA policy mutation','Application deletion','Service principal deletion','User deletion','Access review write','Non-expired credential removal')
    }
}

function Export-DecomRev3CapabilityMatrixMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Matrix,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Rev3 Remediation Capability Matrix")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Generated:** $($Matrix.GeneratedUtc)")
    $null = $sb.AppendLine("**Tool Version:** $($Matrix.ToolVersion)")
    $null = $sb.AppendLine("**Schema Version:** $($Matrix.SchemaVersion)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Executable Actions")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Release | FindingId | ActionType | WriteScope | Status | Notes |")
    $null = $sb.AppendLine("|---------|-----------|------------|------------|--------|-------|")
    foreach ($a in $Matrix.ExecutableActions) {
        $null = $sb.AppendLine("| $($a.Release) | $($a.FindingId) | $($a.ActionType) | $($a.WriteScope) | $($a.Status) | $($a.Notes) |")
    }
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Plan-Only / Readiness-Only Actions")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Release | FindingId | ActionType | Status | Notes |")
    $null = $sb.AppendLine("|---------|-----------|------------|--------|-------|")
    foreach ($a in $Matrix.PlanOnlyActions) {
        $null = $sb.AppendLine("| $($a.Release) | $($a.FindingId) | $($a.ActionType) | $($a.Status) | $($a.Notes) |")
    }
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Deferred / Unsafe Actions")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| ActionType | Status | Notes |")
    $null = $sb.AppendLine("|------------|--------|-------|")
    foreach ($a in $Matrix.DeferredActions) {
        $null = $sb.AppendLine("| $($a.ActionType) | $($a.Status) | $($a.Notes) |")
    }
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Required Scopes by Mode")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Mode | Scopes | Notes |")
    $null = $sb.AppendLine("|------|--------|-------|")
    foreach ($s in $Matrix.RequiredScopesByMode) {
        $scopeStr = $s.Scopes -join ', '
        $null = $sb.AppendLine("| $($s.Mode) | $scopeStr | $($s.Notes) |")
    }
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Rollback Model")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine($Matrix.RollbackModel)
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Post-Write Evidence Model")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine($Matrix.PostWriteEvidenceModel)
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Unsupported Operations")
    $null = $sb.AppendLine("")
    foreach ($op in $Matrix.UnsupportedOperations) {
        $null = $sb.AppendLine("- $op")
    }

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $Path -Value $sb.ToString() -Encoding UTF8
}

function Export-DecomRev3CapabilityMatrixJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Matrix,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $Matrix | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}

function Export-DecomRev34ProductionReadinessMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Matrix,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine("# Rev3.4 Production-Hardening Readiness Report")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("**Generated:** $($Matrix.GeneratedUtc)")
    $null = $sb.AppendLine("**Tool Version:** $($Matrix.ToolVersion)")
    $null = $sb.AppendLine("**Schema Version:** $($Matrix.SchemaVersion)")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Rev3 Write Expansion Summary")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("Rev3.0 through Rev3.3 expanded controlled write behavior in four increments:")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| Release | New Write Actions |")
    $null = $sb.AppendLine("|---------|------------------|")
    $null = $sb.AppendLine("| Rev3.0  | RemoveAccessPackageAssignment, RemovePimEligibleAssignment |")
    $null = $sb.AppendLine("| Rev3.1  | RemoveGuestGroupMembership, RevokeGuestAppRoleAssignment |")
    $null = $sb.AppendLine("| Rev3.2  | RemoveExpiredApplicationCredential |")
    $null = $sb.AppendLine("| Rev3.3  | AddApplicationOwner, RemoveCAExclusionGroupMember |")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Rev3.4 Candidates")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("The following actions are NOT implemented in Rev3.3 and remain candidates for Rev3.4 production hardening:")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("| ActionType | Blocker / Prerequisite |")
    $null = $sb.AppendLine("|------------|------------------------|")
    $null = $sb.AppendLine("| RemoveDisabledApplicationOwner | Requires confirmed replacement owner before removal — owner pairing gate needed |")
    $null = $sb.AppendLine("| ApplyAccessReviewDecision | Requires AccessReview.ReadWrite.All — scope governance review needed |")
    $null = $sb.AppendLine("| RemoveNonExpiredCredentialAfterRotationEvidence | Requires verified rotation evidence chain — evidence validation gate needed |")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Permanent Non-Goals")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("The following operations will NEVER be implemented in this tool:")
    $null = $sb.AppendLine("")
    foreach ($op in $Matrix.UnsupportedOperations) {
        $null = $sb.AppendLine("- $op")
    }
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("---")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("## Safety Invariants That Must Be Preserved in Rev3.4")
    $null = $sb.AppendLine("")
    $null = $sb.AppendLine("1. All writes occur only in Remediation.psm1")
    $null = $sb.AppendLine("2. Write scopes requested only in ExecuteRemediation after Gate A and Gate B")
    $null = $sb.AppendLine("3. No write without exact approved ObjectId and TargetObjectIds")
    $null = $sb.AppendLine("4. ProtectedObject blocks all write actions")
    $null = $sb.AppendLine("5. EmergencyAccessIndicator/BreakGlassIndicator blocks CA exclusion removal")
    $null = $sb.AppendLine("6. No CA policy mutation — only group membership write")
    $null = $sb.AppendLine("7. Post-write re-query required for evidence")
    $null = $sb.AppendLine("8. Approval manifest SchemaVersion must match or exceed action type minimum")

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    Set-Content -Path $Path -Value $sb.ToString() -Encoding UTF8
}

function Export-DecomRev34ProductionReadinessJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSCustomObject]$Matrix,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $readiness = [PSCustomObject]@{
        SchemaVersion = '3.6'
        GeneratedUtc  = $Matrix.GeneratedUtc
        ToolVersion   = $Matrix.ToolVersion
        Rev3WriteSummary = @(
            [PSCustomObject]@{ Release='Rev3.0'; Actions=@('RemoveAccessPackageAssignment','RemovePimEligibleAssignment') }
            [PSCustomObject]@{ Release='Rev3.1'; Actions=@('RemoveGuestGroupMembership','RevokeGuestAppRoleAssignment') }
            [PSCustomObject]@{ Release='Rev3.2'; Actions=@('RemoveExpiredApplicationCredential') }
            [PSCustomObject]@{ Release='Rev3.3'; Actions=@('AddApplicationOwner','RemoveCAExclusionGroupMember') }
        )
        Rev34Candidates = @(
            [PSCustomObject]@{ ActionType='RemoveDisabledApplicationOwner'; Blocker='Requires confirmed replacement owner before removal' }
            [PSCustomObject]@{ ActionType='ApplyAccessReviewDecision';      Blocker='Requires AccessReview.ReadWrite.All scope review' }
            [PSCustomObject]@{ ActionType='RemoveNonExpiredCredentialAfterRotationEvidence'; Blocker='Requires verified rotation evidence chain' }
        )
        PermanentNonGoals = $Matrix.UnsupportedOperations
        SafetyInvariants = @(
            'All writes in Remediation.psm1 only'
            'Write scopes after Gate A/B only'
            'Exact approved ObjectId and TargetObjectIds required'
            'ProtectedObject blocks all writes'
            'EmergencyAccessIndicator blocks CA exclusion removal'
            'No CA policy mutation'
            'Post-write re-query required'
            'Approval manifest SchemaVersion must meet action type minimum'
        )
    }

    $dir = Split-Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $readiness | ConvertTo-Json -Depth 8 | Set-Content -Path $Path -Encoding UTF8
}
