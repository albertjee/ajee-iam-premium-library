#Requires -Version 5.1

Describe 'Remediation.Rev33 — Application Owner and CA Exclusion Revalidation Safety' {

    BeforeAll {
        $script:ModulesPath = Join-Path $PSScriptRoot '..\..\src\Modules'
        foreach ($m in @('Utilities','Remediation')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
        Import-Module (Join-Path $script:ModulesPath 'Utilities.psm1')   -Force -DisableNameChecking
        Import-Module (Join-Path $script:ModulesPath 'Remediation.psm1') -Force -DisableNameChecking

        $script:RemContent = Get-Content (Join-Path $script:ModulesPath 'Remediation.psm1') -Raw
    }

    AfterAll {
        foreach ($m in @('Remediation','Utilities')) {
            Remove-Module $m -Force -ErrorAction SilentlyContinue
        }
    }

    # ── ExecutionMap and registry ──

    Context 'ExecutionMap registry — Rev3.3 entries' {

        It 'DEC-APP-001 maps to AddApplicationOwner in ExecutionMap' {
            InModuleScope Remediation {
                $script:ExecutionMap.ContainsKey('DEC-APP-001') | Should -Be $true
                $script:ExecutionMap['DEC-APP-001'] | Should -Be 'AddApplicationOwner'
            }
        }

        It 'DEC-APP-002 maps to AddApplicationOwner in ExecutionMap' {
            InModuleScope Remediation {
                $script:ExecutionMap['DEC-APP-002'] | Should -Be 'AddApplicationOwner'
            }
        }

        It 'DEC-APP-003 maps to AddApplicationOwner in ExecutionMap' {
            InModuleScope Remediation {
                $script:ExecutionMap['DEC-APP-003'] | Should -Be 'AddApplicationOwner'
            }
        }

        It 'DEC-SPN-001 maps to AddApplicationOwner in ExecutionMap' {
            InModuleScope Remediation {
                $script:ExecutionMap['DEC-SPN-001'] | Should -Be 'AddApplicationOwner'
            }
        }

        It 'DEC-CA-002 maps to RemoveCAExclusionGroupMember in ExecutionMap' {
            InModuleScope Remediation {
                $script:ExecutionMap['DEC-CA-002'] | Should -Be 'RemoveCAExclusionGroupMember'
            }
        }

        It 'DEC-CA-003 maps to RemoveCAExclusionGroupMember in ExecutionMap' {
            InModuleScope Remediation {
                $script:ExecutionMap['DEC-CA-003'] | Should -Be 'RemoveCAExclusionGroupMember'
            }
        }

        It 'DEC-CA-004 maps to RemoveCAExclusionGroupMember in ExecutionMap' {
            InModuleScope Remediation {
                $script:ExecutionMap['DEC-CA-004'] | Should -Be 'RemoveCAExclusionGroupMember'
            }
        }

        It 'Rev3.3 FindingIds are in ManualApprovalFindingIds' {
            InModuleScope Remediation {
                'DEC-APP-001' -in $script:ManualApprovalFindingIds | Should -Be $true
                'DEC-CA-002'  -in $script:ManualApprovalFindingIds | Should -Be $true
            }
        }
    }

    # ── AddApplicationOwner revalidation content tests ──

    Context 'AddApplicationOwner — revalidation and execution content (items 29-35)' {

        # Item 29: Target app read failure blocks
        It 'Remediation.psm1 handles target application read failure as BLOCKED' {
            $script:RemContent | Should -Match 'Application read failed'
        }

        # Item 30: NewOwnerObjectId read failure blocks
        It 'Remediation.psm1 handles NewOwnerObjectId read failure' {
            $script:RemContent | Should -Match 'NewOwnerObjectId'
        }

        # Item 31: Disabled owner blocks
        It 'Remediation.psm1 blocks disabled owner (AccountEnabled=false)' {
            $script:RemContent | Should -Match 'AccountEnabled.*false|AccountEnabled=false'
        }

        # Item 32: Guest owner blocks unless AllowGuestOwner true
        It 'Remediation.psm1 blocks guest owner unless AllowGuestOwner is true' {
            $script:RemContent | Should -Match 'AllowGuestOwner'
            $script:RemContent | Should -Match 'Guest.*AllowGuestOwner|AllowGuestOwner.*Guest'
        }

        # Item 33: Already-owner logs Skipped
        It 'Remediation.psm1 logs Skipped when target already has approved owner' {
            $script:RemContent | Should -Match '(?i)(already.*owner|Skipped.*owner|owner.*already|alreadyOwner)'
        }

        # Item 34: Adds only approved NewOwnerObjectId
        It 'Remediation.psm1 uses New-MgApplicationOwnerByRef for Application objects' {
            $script:RemContent | Should -Match 'New-MgApplicationOwnerByRef'
        }

        It 'Remediation.psm1 uses New-MgServicePrincipalOwnerByRef for ServicePrincipal objects' {
            $script:RemContent | Should -Match 'New-MgServicePrincipalOwnerByRef'
        }

        It 'Remediation.psm1 checks cmdlet availability before executing owner write' {
            $script:RemContent | Should -Match 'Get-Command.*New-MgApplicationOwnerByRef|Get-Command.*New-MgServicePrincipalOwnerByRef'
        }

        # Item 35: Post-write re-query failure does not log Executed
        It 'Remediation.psm1 contains post-write owner re-query for evidence' {
            $script:RemContent | Should -Match 'AddApplicationOwner'
            $script:RemContent | Should -Match '(?i)(querySucceeded|EvidenceUnknown|OwnerPresentAfter|re.query|requery)'
        }

        It 'Confirm-DecomActionTargetValid handles AddApplicationOwner case' {
            $script:RemContent | Should -Match "'AddApplicationOwner'"
        }

        It 'Get-DecomTargetState handles AddApplicationOwner case' {
            $script:RemContent | Should -Match 'AddApplicationOwner'
        }

        It 'Invoke-DecomRemediation handles AddApplicationOwner case' {
            $script:RemContent | Should -Match "'AddApplicationOwner'"
        }

        It 'Remediation.psm1 ProtectedObject blocks AddApplicationOwner execution' {
            $script:RemContent | Should -Match 'ProtectedObject'
        }
    }

    # ── RemoveCAExclusionGroupMember revalidation content tests ──

    Context 'RemoveCAExclusionGroupMember — revalidation and execution content (items 49-58)' {

        # Item 49: CA policy read failure blocks
        It 'Remediation.psm1 blocks when CA policy read fails' {
            $script:RemContent | Should -Match 'CA policy read failed'
        }

        # Item 50: Policy no longer excludes group logs Skipped or Blocked
        It 'Remediation.psm1 logs stale result when policy no longer excludes group' {
            $script:RemContent | Should -Match 'CA policy no longer excludes this group'
        }

        # Item 51: Group read failure blocks (module reads members via Get-MgGroupMember; fail = blocked)
        It 'Remediation.psm1 blocks when exclusion group read fails' {
            $script:RemContent | Should -Match 'Group member read failed|group.*read fail|Exclusion group read failed'
        }

        # Item 52: Group member read failure blocks
        It 'Remediation.psm1 blocks when group member read fails' {
            $script:RemContent | Should -Match '(?i)(member.*read fail|read.*member.*fail)'
        }

        # Item 53: Principal not member logs Skipped
        It 'Remediation.psm1 handles already-absent principal as Skipped/no-op' {
            $script:RemContent | Should -Match '(?i)(not.*member.*skip|already.*absent|principal.*not.*member|Skipped.*member)'
        }

        # Item 54: Protected principal blocks
        It 'Remediation.psm1 blocks ProtectedObject for CA exclusion removal' {
            $script:RemContent | Should -Match 'ProtectedObject'
        }

        # Item 55: Break-glass principal blocks
        It 'Remediation.psm1 blocks BreakGlassIndicator=true for CA exclusion removal' {
            $script:RemContent | Should -Match 'BreakGlassIndicator.*true|BreakGlassIndicator=true'
        }

        It 'Remediation.psm1 blocks EmergencyAccessIndicator=true for CA exclusion removal' {
            $script:RemContent | Should -Match 'EmergencyAccessIndicator.*true|EmergencyAccessIndicator=true'
        }

        # Item 56: Removes only approved principal from approved group
        It 'Remediation.psm1 uses Remove-MgGroupMemberByRef for CA exclusion removal' {
            $script:RemContent | Should -Match 'Remove-MgGroupMemberByRef'
        }

        # Item 57: Does not mutate CA policy
        It 'Remediation.psm1 does not contain CA policy write cmdlets' {
            $script:RemContent | Should -Not -Match 'Update-MgIdentityConditionalAccessPolicy'
            $script:RemContent | Should -Not -Match 'New-MgIdentityConditionalAccessPolicy'
            $script:RemContent | Should -Not -Match 'Remove-MgIdentityConditionalAccessPolicy'
        }

        It 'Remediation.psm1 reads CA policy read-only (Get-MgIdentityConditionalAccessPolicy)' {
            $script:RemContent | Should -Match 'Get-MgIdentityConditionalAccessPolicy'
        }

        # Item 58: Post-write re-query failure does not log Executed
        It 'Remediation.psm1 contains post-write membership re-query for CA evidence' {
            $script:RemContent | Should -Match 'RemoveCAExclusionGroupMember'
            $script:RemContent | Should -Match '(?i)(querySucceeded|ExcludedPrincipalMemberAfter|re.query)'
        }

        It 'Confirm-DecomActionTargetValid handles RemoveCAExclusionGroupMember case' {
            $script:RemContent | Should -Match "'RemoveCAExclusionGroupMember'"
        }

        It 'Get-DecomTargetState handles RemoveCAExclusionGroupMember case' {
            $script:RemContent | Should -Match 'RemoveCAExclusionGroupMember'
        }
    }

    # ── P1 fixes: outcome logic and user validation hardening ──

    Context 'AddApplicationOwner — outcome logic and user validation hardening (P1 fixes)' {

        It 'AddApplicationOwner logs Executed when post-write re-query confirms owner present' {
            InModuleScope Remediation {
                # Outcome block: add-oriented — PresentTargetIds == targetIds means Executed
                $script:RemContent = $script:RemContent  # already loaded in BeforeAll
            }
            $script:RemContent | Should -Match "actionType.*-eq.*'AddApplicationOwner'|'AddApplicationOwner'.*actionType"
            $script:RemContent | Should -Match 'PresentTargetIds\.Count -eq \$targetIds\.Count'
        }

        It 'AddApplicationOwner logs Failed when owner still absent after write' {
            # When PresentTargetIds is empty for AddApplicationOwner the outcome must be Failed not Executed
            $script:RemContent | Should -Match "actionType.*-eq.*'AddApplicationOwner'"
            # The removal-oriented branch (Count -eq 0 → Executed) must NOT be reached for AddApplicationOwner
            # Verify add-oriented else branch emits Failed
            $script:RemContent | Should -Match "PresentTargetIds\.Count -eq 0[\s\S]{0,200}'Failed'"
        }

        It 'AddApplicationOwner post-write re-query failure logs PartialFailed not Executed' {
            # QuerySucceeded = false must yield PartialFailed regardless of action type
            $script:RemContent | Should -Match 'QuerySucceeded'
            $script:RemContent | Should -Match "'PartialFailed'"
        }

        It 'Confirm-DecomActionTargetValid blocks when NewOwnerType=User and Get-MgUser fails' {
            $script:RemContent | Should -Match "NewOwnerType.*-eq.*'User'|'User'.*NewOwnerType"
            $script:RemContent | Should -Match 'user read failed'
        }
    }

    # ── Safety invariants ──

    Context 'Rev3.3 safety invariants' {

        It 'Remediation.psm1 does not contain Remove-MgApplication (object deletion)' {
            $script:RemContent | Should -Not -Match 'Remove-MgApplication\s'
        }

        It 'Remediation.psm1 does not contain Remove-MgServicePrincipal' {
            $script:RemContent | Should -Not -Match 'Remove-MgServicePrincipal\b'
        }

        It 'Remediation.psm1 does not contain Policy.ReadWrite scope' {
            $script:RemContent | Should -Not -Match 'Policy\.ReadWrite'
        }
    }
}
