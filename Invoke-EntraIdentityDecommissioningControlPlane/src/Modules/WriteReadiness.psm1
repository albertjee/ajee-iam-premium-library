Import-Module (Join-Path $PSScriptRoot 'Utilities.psm1') -Force -DisableNameChecking

function Get-DecomExecutionScopeRegistry {
    [CmdletBinding()]
    param()

    # Rev2.0 controlled remediation scope - these are the only executable actions
    return @(
        [PSCustomObject]@{
            FindingId = 'DEC-USER-001'
            ActionType = 'RemoveGroupMembership'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'Group'
            TargetObjectIdsRepresent = 'Group IDs'
            RequiresPerActionPrompt = $false
            IntroducedIn = 'Rev2.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-USER-002'
            ActionType = 'RevokeAppRoleAssignment'
            WriteScope = 'AppRoleAssignment.ReadWrite.All'
            TargetType = 'AppRoleAssignment'
            TargetObjectIdsRepresent = 'App role assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev2.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-USER-003'
            ActionType = 'RemoveDirectoryRoleAssignment'
            WriteScope = 'RoleManagement.ReadWrite.Directory'
            TargetType = 'DirectoryRoleAssignment'
            TargetObjectIdsRepresent = 'Directory role assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev2.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-ROLE-001'
            ActionType = 'RemoveDirectoryRoleAssignment'
            WriteScope = 'RoleManagement.ReadWrite.Directory'
            TargetType = 'DirectoryRoleAssignment'
            TargetObjectIdsRepresent = 'Directory role assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev2.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-AP-001'
            ActionType = 'RemoveAccessPackageAssignment'
            WriteScope = 'EntitlementManagement.ReadWrite.All'
            TargetType = 'AccessPackageAssignment'
            TargetObjectIdsRepresent = 'Access package assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-001'
            ActionType = 'RemovePimEligibleAssignment'
            WriteScope = 'RoleManagement.ReadWrite.Directory'
            TargetType = 'PrivilegedAccessAssignment'
            TargetObjectIdsRepresent = 'PIM eligible assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-AP-002'
            ActionType = 'RemoveAccessPackageAssignment'
            WriteScope = 'EntitlementManagement.ReadWrite.All'
            TargetType = 'AccessPackageAssignment'
            TargetObjectIdsRepresent = 'Access package assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-AP-007'
            ActionType = 'RemoveAccessPackageAssignment'
            WriteScope = 'EntitlementManagement.ReadWrite.All'
            TargetType = 'AccessPackageAssignment'
            TargetObjectIdsRepresent = 'Access package assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-AP-008'
            ActionType = 'RemoveAccessPackageAssignment'
            WriteScope = 'EntitlementManagement.ReadWrite.All'
            TargetType = 'AccessPackageAssignment'
            TargetObjectIdsRepresent = 'Access package assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-002'
            ActionType = 'RemovePimEligibleAssignment'
            WriteScope = 'RoleManagement.ReadWrite.Directory'
            TargetType = 'PrivilegedAccessAssignment'
            TargetObjectIdsRepresent = 'PIM eligible assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-003'
            ActionType = 'RemovePimEligibleAssignment'
            WriteScope = 'RoleManagement.ReadWrite.Directory'
            TargetType = 'PrivilegedAccessAssignment'
            TargetObjectIdsRepresent = 'PIM eligible assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-004'
            ActionType = 'RemovePimEligibleAssignment'
            WriteScope = 'RoleManagement.ReadWrite.Directory'
            TargetType = 'PrivilegedAccessAssignment'
            TargetObjectIdsRepresent = 'PIM eligible assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-005'
            ActionType = 'RemovePimEligibleAssignment'
            WriteScope = 'RoleManagement.ReadWrite.Directory'
            TargetType = 'PrivilegedAccessAssignment'
            TargetObjectIdsRepresent = 'PIM eligible assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-006'
            ActionType = 'RemovePimEligibleAssignment'
            WriteScope = 'RoleManagement.ReadWrite.Directory'
            TargetType = 'PrivilegedAccessAssignment'
            TargetObjectIdsRepresent = 'PIM eligible assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.0'
            Status = 'Executable'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GUEST-001'
            ActionType = 'RemoveGuestGroupMembership'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'Group'
            TargetObjectIdsRepresent = 'Group IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.1'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'High'
            GuestOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GUEST-002'
            ActionType = 'RemoveGuestGroupMembership'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'Group'
            TargetObjectIdsRepresent = 'Group IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.1'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'High'
            GuestOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GUEST-002'
            ActionType = 'RevokeGuestAppRoleAssignment'
            WriteScope = 'AppRoleAssignment.ReadWrite.All'
            TargetType = 'AppRoleAssignment'
            TargetObjectIdsRepresent = 'App role assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.1'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'High'
            GuestOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GUEST-003'
            ActionType = 'RemoveGuestGroupMembership'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'Group'
            TargetObjectIdsRepresent = 'Group IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.1'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'High'
            GuestOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GREV-001'
            ActionType = 'RemoveGuestGroupMembership'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'Group'
            TargetObjectIdsRepresent = 'Group IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.1'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'High'
            GuestOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GREV-002'
            ActionType = 'RemoveGuestGroupMembership'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'Group'
            TargetObjectIdsRepresent = 'Group IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.1'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'High'
            GuestOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GREV-003'
            ActionType = 'RemoveGuestGroupMembership'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'Group'
            TargetObjectIdsRepresent = 'Group IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.1'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'High'
            GuestOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GREV-003'
            ActionType = 'RevokeGuestAppRoleAssignment'
            WriteScope = 'AppRoleAssignment.ReadWrite.All'
            TargetType = 'AppRoleAssignment'
            TargetObjectIdsRepresent = 'App role assignment IDs'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.1'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'High'
            GuestOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-APP-005'
            ActionType = 'RemoveExpiredApplicationCredential'
            WriteScope = 'Application.ReadWrite.All'
            TargetType = 'ApplicationCredential'
            TargetObjectIdsRepresent = 'Credential KeyIds'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.2'
            Status = 'ExecutableWhenExactExpiredCredentialKeyIdPresent'
            RiskLevel = 'High'
            ApplicationOnly = $true
            CredentialType = 'PasswordCredential or KeyCredential'
        },
        # Rev3.3 — AddApplicationOwner
        [PSCustomObject]@{
            FindingId = 'DEC-APP-001'
            ActionType = 'AddApplicationOwner'
            WriteScope = 'Application.ReadWrite.All'
            TargetType = 'DirectoryObjectOwner'
            TargetObjectIdsRepresent = 'NewOwnerObjectId values'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.3'
            Status = 'ExecutableWhenExactOwnerObjectIdPresent'
            RiskLevel = 'High'
            ApplicationOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-APP-002'
            ActionType = 'AddApplicationOwner'
            WriteScope = 'Application.ReadWrite.All'
            TargetType = 'DirectoryObjectOwner'
            TargetObjectIdsRepresent = 'NewOwnerObjectId values'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.3'
            Status = 'ExecutableWhenExactOwnerObjectIdPresent'
            RiskLevel = 'High'
            ApplicationOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-APP-003'
            ActionType = 'AddApplicationOwner'
            WriteScope = 'Application.ReadWrite.All'
            TargetType = 'DirectoryObjectOwner'
            TargetObjectIdsRepresent = 'NewOwnerObjectId values'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.3'
            Status = 'ExecutableWhenExactOwnerObjectIdPresent'
            RiskLevel = 'High'
            ApplicationOnly = $true
        },
        [PSCustomObject]@{
            FindingId = 'DEC-SPN-001'
            ActionType = 'AddApplicationOwner'
            WriteScope = 'Application.ReadWrite.All'
            TargetType = 'DirectoryObjectOwner'
            TargetObjectIdsRepresent = 'NewOwnerObjectId values'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.3'
            Status = 'ExecutableWhenExactOwnerObjectIdPresent'
            RiskLevel = 'High'
            ApplicationOnly = $false
        },
        # Rev3.3 — RemoveCAExclusionGroupMember
        [PSCustomObject]@{
            FindingId = 'DEC-CA-002'
            ActionType = 'RemoveCAExclusionGroupMember'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'CAExclusionGroup'
            TargetObjectIdsRepresent = 'ExclusionGroupId values'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.3'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'Critical'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-CA-003'
            ActionType = 'RemoveCAExclusionGroupMember'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'CAExclusionGroup'
            TargetObjectIdsRepresent = 'ExclusionGroupId values'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.3'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'Critical'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-CA-004'
            ActionType = 'RemoveCAExclusionGroupMember'
            WriteScope = 'GroupMember.ReadWrite.All'
            TargetType = 'CAExclusionGroup'
            TargetObjectIdsRepresent = 'ExclusionGroupId values'
            RequiresPerActionPrompt = $true
            IntroducedIn = 'Rev3.3'
            Status = 'ExecutableWhenExactTargetPresent'
            RiskLevel = 'Critical'
        }
    )
}

function Get-DecomRev3WriteCandidateRegistry {
    [CmdletBinding()]
    param()

    # Candidate write actions for Rev3.0 consideration - NOT implemented in Rev2.5
    return @(
        [PSCustomObject]@{
            FindingId = 'DEC-AP-001'
            CandidateActionType = 'RemoveAccessPackageAssignment'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'EntitlementManagement.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Access package assignment IDs'
            RequiredApprovalEvidence = 'Client signed approval with business justification'
            RequiredRollbackDesign = 'Plan to reassign access package if needed'
            RequiredPreflightChecks = 'Validate no active assignments, check expiration dates'
            RequiredPostWriteEvidence = 'Confirmation of assignment removal, audit logs'
            RecommendedRev = 'Rev3.0'
            Notes = 'Access package assignments require careful review due to potential business impact'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-AP-002'
            CandidateActionType = 'RemoveAccessPackageAssignment'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'EntitlementManagement.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Access package assignment IDs'
            RequiredApprovalEvidence = 'Client signed approval with business justification'
            RequiredRollbackDesign = 'Plan to reassign access package if needed'
            RequiredPreflightChecks = 'Validate no active assignments, check expiration dates'
            RequiredPostWriteEvidence = 'Confirmation of assignment removal, audit logs'
            RecommendedRev = 'Rev3.0'
            Notes = 'Access package assignments require careful review due to potential business impact'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-001'
            CandidateActionType = 'RemovePimEligibleAssignment'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'PrivilegedAccess.ReadWrite.AzureAD'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'PIM eligible assignment IDs'
            RequiredApprovalEvidence = 'Client signed approval with business justification'
            RequiredRollbackDesign = 'Document original assignment settings for restoration'
            RequiredPreflightChecks = 'Validate assignment is active, check expiration, notify stakeholders'
            RequiredPostWriteEvidence = 'Confirmation of assignment removal, audit logs showing PIM changes'
            RecommendedRev = 'Rev3.0'
            Notes = 'PIM eligible assignments require elevated approval due to security implications'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-002'
            CandidateActionType = 'RemovePimEligibleAssignment'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'PrivilegedAccess.ReadWrite.AzureAD'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'PIM eligible assignment IDs'
            RequiredApprovalEvidence = 'Client signed approval with business justification'
            RequiredRollbackDesign = 'Document original assignment settings for restoration'
            RequiredPreflightChecks = 'Validate assignment is active, check expiration, notify stakeholders'
            RequiredPostWriteEvidence = 'Confirmation of assignment removal, audit logs showing PIM changes'
            RecommendedRev = 'Rev3.0'
            Notes = 'PIM eligible assignments require elevated approval due to security implications'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-004'
            CandidateActionType = 'RemovePimEligibleAssignment'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'PrivilegedAccess.ReadWrite.AzureAD'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'PIM eligible assignment IDs'
            RequiredApprovalEvidence = 'Client signed approval with business justification'
            RequiredRollbackDesign = 'Document original assignment settings for restoration'
            RequiredPreflightChecks = 'Validate assignment is active, check expiration, notify stakeholders'
            RequiredPostWriteEvidence = 'Confirmation of assignment removal, audit logs showing PIM changes'
            RecommendedRev = 'Rev3.0'
            Notes = 'PIM eligible assignments require elevated approval due to security implications'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-PIM-005'
            CandidateActionType = 'RemovePimEligibleAssignment'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'PrivilegedAccess.ReadWrite.AzureAD'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'PIM eligible assignment IDs'
            RequiredApprovalEvidence = 'Client signed approval with business justification'
            RequiredRollbackDesign = 'Document original assignment settings for restoration'
            RequiredPreflightChecks = 'Validate assignment is active, check expiration, notify stakeholders'
            RequiredPostWriteEvidence = 'Confirmation of assignment removal, audit logs showing PIM changes'
            RecommendedRev = 'Rev3.0'
            Notes = 'PIM eligible assignments require elevated approval due to security implications'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GUEST-001'
            CandidateActionType = 'RemoveGuestGroupMembership'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'GroupMember.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Group IDs'
            RequiredApprovalEvidence = 'Client signed approval'
            RequiredRollbackDesign = 'Manual re-addition through governance process'
            RequiredPreflightChecks = 'Validate guest status and exact group membership'
            RequiredPostWriteEvidence = 'Post-write re-query confirmation'
            RecommendedRev = 'Rev3.1'
            Notes = 'Remove guest from group by exact group ID'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GUEST-002'
            CandidateActionType = 'RemoveGuestGroupMembership'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'GroupMember.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Group IDs'
            RequiredApprovalEvidence = 'Client signed approval'
            RequiredRollbackDesign = 'Manual re-addition through governance process'
            RequiredPreflightChecks = 'Validate guest status and exact group membership'
            RequiredPostWriteEvidence = 'Post-write re-query confirmation'
            RecommendedRev = 'Rev3.1'
            Notes = 'Remove guest from group by exact group ID'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GUEST-002'
            CandidateActionType = 'RevokeGuestAppRoleAssignment'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'AppRoleAssignment.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'App role assignment IDs'
            RequiredApprovalEvidence = 'Client signed approval'
            RequiredRollbackDesign = 'Manual re-grant through application owner'
            RequiredPreflightChecks = 'Validate guest status and exact app role assignment'
            RequiredPostWriteEvidence = 'Post-write re-query confirmation'
            RecommendedRev = 'Rev3.1'
            Notes = 'Revoke guest app role assignment by exact assignment ID'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GUEST-003'
            CandidateActionType = 'RemoveGuestGroupMembership'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'GroupMember.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Group IDs'
            RequiredApprovalEvidence = 'Client signed approval'
            RequiredRollbackDesign = 'Manual re-addition through governance process'
            RequiredPreflightChecks = 'Validate guest status and exact group membership'
            RequiredPostWriteEvidence = 'Post-write re-query confirmation'
            RecommendedRev = 'Rev3.1'
            Notes = 'Remove guest from group by exact group ID'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GREV-001'
            CandidateActionType = 'RemoveGuestGroupMembership'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'GroupMember.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Group IDs'
            RequiredApprovalEvidence = 'Client signed approval'
            RequiredRollbackDesign = 'Manual re-addition through governance process'
            RequiredPreflightChecks = 'Validate guest status and exact group membership'
            RequiredPostWriteEvidence = 'Post-write re-query confirmation'
            RecommendedRev = 'Rev3.1'
            Notes = 'Remove guest from group by exact group ID'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GREV-002'
            CandidateActionType = 'RemoveGuestGroupMembership'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'GroupMember.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Group IDs'
            RequiredApprovalEvidence = 'Client signed approval'
            RequiredRollbackDesign = 'Manual re-addition through governance process'
            RequiredPreflightChecks = 'Validate guest status and exact group membership'
            RequiredPostWriteEvidence = 'Post-write re-query confirmation'
            RecommendedRev = 'Rev3.1'
            Notes = 'Remove guest from group by exact group ID'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GREV-003'
            CandidateActionType = 'RemoveGuestGroupMembership'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'GroupMember.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Group IDs'
            RequiredApprovalEvidence = 'Client signed approval'
            RequiredRollbackDesign = 'Manual re-addition through governance process'
            RequiredPreflightChecks = 'Validate guest status and exact group membership'
            RequiredPostWriteEvidence = 'Post-write re-query confirmation'
            RecommendedRev = 'Rev3.1'
            Notes = 'Remove guest from group by exact group ID'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-GREV-003'
            CandidateActionType = 'RevokeGuestAppRoleAssignment'
            CandidateStatus = 'Candidate'
            ProposedWriteScope = 'AppRoleAssignment.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'App role assignment IDs'
            RequiredApprovalEvidence = 'Client signed approval'
            RequiredRollbackDesign = 'Manual re-grant through application owner'
            RequiredPreflightChecks = 'Validate guest status and exact app role assignment'
            RequiredPostWriteEvidence = 'Post-write re-query confirmation'
            RecommendedRev = 'Rev3.1'
            Notes = 'Revoke guest app role assignment by exact assignment ID'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-APP-003'
            CandidateActionType = 'AddApplicationOwner'
            CandidateStatus = 'NeedsDesign'
            ProposedWriteScope = 'Application.ReadWrite.All'
            RiskLevel = 'Medium'
            TargetObjectIdsWouldRepresent = 'Application object IDs'
            RequiredApprovalEvidence = 'Client signed approval, security team review'
            RequiredRollbackDesign = 'Ability to remove newly added owner'
            RequiredPreflightChecks = 'Validate application status, check existing owners, notify stakeholders'
            RequiredPostWriteEvidence = 'Confirmation of new owner in application properties, audit logs'
            RecommendedRev = 'Rev3.1'
            Notes = 'Adding application owners requires careful privilege escalation considerations'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-APP-005'
            CandidateActionType = 'RemoveExpiredCredential'
            CandidateStatus = 'Deferred'
            ProposedWriteScope = 'Application.ReadWrite.All'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Application credential IDs'
            RequiredApprovalEvidence = 'Client signed approval with security validation'
            RequiredRollbackDesign = 'Credential vault recovery process if available'
            RequiredPreflightChecks = 'Validate credential is expired, check usage, backup if possible'
            RequiredPostWriteEvidence = 'Confirmation of credential removal, audit logs, application functionality validation'
            RecommendedRev = 'Rev3.2'
            Notes = 'Credential removal requires validation that credentials are truly expired and unused'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-CA-002'
            CandidateActionType = 'RemoveCAExclusionGroupMember'
            CandidateStatus = 'Deferred'
            ProposedWriteScope = 'Policy.ReadWrite.ConditionalAccess'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Conditional Access policy IDs'
            RequiredApprovalEvidence = 'Client signed approval, security team review'
            RequiredRollbackDesign = 'Document original exclusion settings'
            RequiredPreflightChecks = 'Validate CA policy status, test impact in report-only mode'
            RequiredPostWriteEvidence = 'Confirmation of exclusion removal, audit logs, policy validation'
            RecommendedRev = 'Rev3.2+'
            Notes = 'CA exclusion modifications require careful testing due to potential access impacts'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-CA-003'
            CandidateActionType = 'RemoveCAExclusionGroupMember'
            CandidateStatus = 'Deferred'
            ProposedWriteScope = 'Policy.ReadWrite.ConditionalAccess'
            RiskLevel = 'High'
            TargetObjectIdsWouldRepresent = 'Conditional Access policy IDs'
            RequiredApprovalEvidence = 'Client signed approval, security team review'
            RequiredRollbackDesign = 'Document original exclusion settings'
            RequiredPreflightChecks = 'Validate CA policy status, test impact in report-only mode'
            RequiredPostWriteEvidence = 'Confirmation of exclusion removal, audit logs, policy validation'
            RecommendedRev = 'Rev3.2+'
            Notes = 'CA exclusion modifications require careful testing due to potential access impacts'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-APP-001'
            CandidateActionType = 'DeleteOrDisableApp'
            CandidateStatus = 'Unsafe'
            ProposedWriteScope = 'Application.ReadWrite.All'
            RiskLevel = 'Critical'
            TargetObjectIdsWouldRepresent = 'Application object IDs'
            RequiredApprovalEvidence = 'Not recommended for implementation'
            RequiredRollbackDesign = 'Application recreation from backup if possible'
            RequiredPreflightChecks = 'Extensive validation of application dependencies and usage'
            RequiredPostWriteEvidence = 'Not applicable - action is destructive'
            RecommendedRev = 'Not recommended'
            Notes = 'Application deletion/disable is unsafe due to potential service disruption and data loss'
        },
        [PSCustomObject]@{
            FindingId = 'DEC-SPN-001'
            CandidateActionType = 'DeleteServicePrincipal'
            CandidateStatus = 'Unsafe'
            ProposedWriteScope = 'Application.ReadWrite.All'
            RiskLevel = 'Critical'
            TargetObjectIdsWouldRepresent = 'Service principal object IDs'
            RequiredApprovalEvidence = 'Not recommended for implementation'
            RequiredRollbackDesign = 'Service principal recreation from backup if possible'
            RequiredPreflightChecks = 'Extensive validation of service principal dependencies and usage'
            RequiredPostWriteEvidence = 'Not applicable - action is destructive'
            RecommendedRev = 'Not recommended'
            Notes = 'Service principal deletion is unsafe due to potential service disruption and data loss'
        }
    )
}

function New-DecomRev3WriteReadinessReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $executionScope = Get-DecomExecutionScopeRegistry
    $rev3Candidates = Get-DecomRev3WriteCandidateRegistry

    $report = [PSCustomObject]@{
        SchemaVersion = '3.0'
        ToolVersion = $Context.ToolVersion
        GeneratedUtc = (Get-Date).ToUniversalTime().ToString('o')
        EngagementId = $Context.EngagementId
        ClientName = $Context.ClientName
        Assessor = $Context.Assessor
        ExecutionScopeRegistry = $executionScope
        Rev3Candidates = $rev3Candidates
        Recommendation = 'ReadyForRev3Design'
        Sections = @(
            @{ Title = '1. Current executable scope'; Content = $executionScope }
            @{ Title = '2. Rev3.0 candidate write actions'; Content = ($rev3Candidates | Where-Object { $_.CandidateStatus -eq 'Candidate' }) }
            @{ Title = '3. Deferred write actions'; Content = ($rev3Candidates | Where-Object { $_.CandidateStatus -eq 'Deferred' }) }
            @{ Title = '4. Unsafe write actions'; Content = ($rev3Candidates | Where-Object { $_.CandidateStatus -eq 'Unsafe' }) }
            @{ Title = '5. Required approval model enhancements'; Content = 'Multi-level approval workflows, automated policy checks, timeout escalations' }
            @{ Title = '6. Required target-resolution model'; Content = 'Improved object resolution for bulk operations, conflict handling' }
            @{ Title = '7. Required rollback guidance'; Content = 'Automated rollback triggers, manual intervention procedures, validation checkpoints' }
            @{ Title = '8. Required post-write evidence'; Content = 'Audit log validation, object state verification, notification confirmation' }
            @{ Title = '9. Required tests before Rev3.0'; Content = 'Safety invariant testing, scope creep detection, approval workflow validation' }
            @{ Title = '10. Final recommendation'; Content = 'Proceed to Rev3.0 design phase with current findings' }
        )
    }

    return $report
}

function Export-DecomRev3WriteReadinessJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Report,
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fileBase   = "rev3-write-readiness-report"
    $JsonPath   = Join-Path $Context.OutputPath "$fileBase-$Timestamp.json"

    $json = $Report | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $JsonPath -Encoding UTF8
    Write-DecomOk "Rev3 write-readiness JSON: $JsonPath"
}

function Export-DecomRev3WriteReadinessMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Report,
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fileBase   = "rev3-write-readiness-report"
    $MdPath     = Join-Path $Context.OutputPath "$fileBase-$Timestamp.md"

    $markdown = @"
# Rev3.0 Write-Readiness Report

**SchemaVersion:** 2.5
**ToolVersion:** $($Report.ToolVersion)
**GeneratedUtc:** $([DateTime]::UtcNow.ToString('o'))
**EngagementId:** $($Report.EngagementId)
**ClientName:** $($Report.ClientName)
**Assessor:** $($Report.Assessor)

## Executive Summary
**Recommendation:** $($Report.Recommendation)

## Sections
"@

    foreach ($section in $Report.Sections) {
        $markdown += "### $($section.Title)`n"
        if ($section.Content -is [PSObject]) {
            $markdown += "$($section.Content | Format-List | Out-String)`n"
        } elseif ($section.Content -is [Array]) {
            if ($section.Content.Count -gt 0) {
                $markdown += "$($section.Content | Format-List | Out-String)`n"
            } else {
                $markdown += "*No items in this category*`n"
            }
        } else {
            $markdown += "$($section.Content)`n"
        }
        $markdown += "`n"
    }

    $markdown += @"
---
© 2026 Albert Jee. All rights reserved.
"@

    $markdown | Out-File -FilePath $MdPath -Encoding UTF8
    Write-DecomOk "Rev3 write-readiness Markdown: $MdPath"
}

function Export-DecomExecutionScopeRegistryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [PSObject]$Registry,
        [Parameter(Mandatory = $true)]
        [PSObject]$Context
    )

    $Timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $fileBase   = "execution-scope-registry"
    $JsonPath   = Join-Path $Context.OutputPath "$fileBase-$Timestamp.json"

    $jsonObject = [PSCustomObject]@{
        SchemaVersion = '3.0'
        ToolVersion   = $Context.ToolVersion
        GeneratedUtc  = (Get-Date).ToUniversalTime().ToString('o')
        EngagementId  = $Context.EngagementId
        ClientName    = $Context.ClientName
        Assessor      = $Context.Assessor
        Registry      = $Registry
    }

    $json = $jsonObject | ConvertTo-Json -Depth 10
    $json | Out-File -FilePath $JsonPath -Encoding UTF8
    Write-DecomOk "Execution scope registry JSON: $JsonPath"
}
