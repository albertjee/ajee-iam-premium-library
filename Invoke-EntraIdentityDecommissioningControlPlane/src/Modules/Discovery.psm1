$script:ProtectedPatterns = @(
    'breakglass','break-glass','emergency','sync',
    'aadconnect','cloudsync','svc-','service-'
)

function Get-DecomAvailableCommand {
    param([string[]]$Names)

    foreach ($name in $Names) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($null -ne $cmd) { return $name }
    }

    return $null
}

function New-DecomCoverage {
    [ordered]@{
        Users                        = $false
        Groups                       = $false
        Applications                 = $false
        ServicePrincipals            = $false
        DirectoryRoles               = $false
        SignInLogs                   = $false
        AuditLogs                    = $false
        ConditionalAccess            = $false
        EntitlementManagement        = $false
        PimEligibleAssignments       = $false
        PimActivationEvidence        = $false
        EntitlementAssignments       = $false
        AccessPackagePolicies        = $false
        AccessReviewScheduleEvidence = $false
        AccessReviews                  = $false
        AccessReviewDefinitions        = $false
        AccessReviewInstances          = $false
        AccessReviewDecisions          = $false
        GuestReviewCorrelation         = $false
        PimReviewCorrelation           = $false
        AccessPackageReviewCorrelation = $false
        CAExclusionReviewCorrelation   = $false
        GovernanceEvidenceLimitations  = @()
    }
}

function Get-DecomSyntheticFindings {
    @(
        (New-DecomFinding `
            -FindingId 'DEC-USER-003' `
            -Category 'User Lifecycle' `
            -Severity 'Critical' `
            -RiskScore 92 `
            -Confidence 'High' `
            -ObjectType 'User' `
            -ObjectId 'a1b2c3d4-0001-0001-0001-000000000001' `
            -DisplayName 'Alex Mercer' `
            -UserPrincipalName 'alex.mercer@contoso.com' `
            -Evidence 'Disabled user retains Global Administrator role assignment' `
            -EvidenceSource 'directoryRoles' `
            -GraphEndpoint '/v1.0/directoryRoles/{id}/members' `
            -RecommendedAction 'Remove Global Administrator role assignment from disabled user alex.mercer@contoso.com' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Confirm no pending IT tasks before removing role'),

        (New-DecomFinding `
            -FindingId 'DEC-APP-002' `
            -Category 'Application' `
            -Severity 'Critical' `
            -RiskScore 88 `
            -Confidence 'High' `
            -ObjectType 'Application' `
            -ObjectId 'a1b2c3d4-0002-0002-0002-000000000002' `
            -DisplayName 'Contoso Analytics API' `
            -UserPrincipalName '' `
            -Evidence 'Application owned exclusively by disabled user alex.mercer@contoso.com — no active owner remains' `
            -EvidenceSource 'applications/{id}/owners' `
            -GraphEndpoint '/v1.0/applications/{id}/owners' `
            -RecommendedAction 'Assign active owner to Contoso Analytics API; remove disabled user alex.mercer@contoso.com as owner' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'App is effectively unmanaged — disabled sole owner creates governance gap'),

        (New-DecomFinding `
            -FindingId 'DEC-GUEST-002' `
            -Category 'Guest Lifecycle' `
            -Severity 'Critical' `
            -RiskScore 85 `
            -Confidence 'High' `
            -ObjectType 'User' `
            -ObjectId 'a1b2c3d4-0003-0003-0003-000000000003' `
            -DisplayName 'ext_partner@fabrikam.com' `
            -UserPrincipalName 'ext_partner_fabrikam.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence 'Guest account holds User Administrator role — no sponsor metadata' `
            -EvidenceSource 'directoryRoles' `
            -GraphEndpoint '/v1.0/directoryRoles/{id}/members' `
            -RecommendedAction 'Review guest privileged access; assign sponsor; consider role removal' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Guest with privileged role requires explicit business justification'),

        (New-DecomFinding `
            -FindingId 'DEC-USER-001' `
            -Category 'User Lifecycle' `
            -Severity 'High' `
            -RiskScore 65 `
            -Confidence 'High' `
            -ObjectType 'User' `
            -ObjectId 'a1b2c3d4-0004-0004-0004-000000000004' `
            -DisplayName 'Jordan Riley' `
            -UserPrincipalName 'jordan.riley@contoso.com' `
            -Evidence 'Disabled user retains membership in 4 groups including IT-Admins' `
            -EvidenceSource 'users/{id}/memberOf' `
            -GraphEndpoint '/v1.0/users/{id}/memberOf' `
            -RecommendedAction 'Remove jordan.riley@contoso.com from all group memberships' `
            -RemediationMode 'AutoRemediable' `
            -ConsultantNote 'Standard group cleanup for disabled user'),

        (New-DecomFinding `
            -FindingId 'DEC-APP-001' `
            -Category 'Application' `
            -Severity 'Medium' `
            -RiskScore 51 `
            -Confidence 'High' `
            -ObjectType 'Application' `
            -ObjectId 'a1b2c3d4-0005-0005-0005-000000000005' `
            -DisplayName 'Reporting Daemon SP' `
            -UserPrincipalName '' `
            -Evidence 'Application has no owner assigned' `
            -EvidenceSource 'applications/{id}/owners' `
            -GraphEndpoint '/v1.0/applications/{id}/owners' `
            -RecommendedAction 'Assign accountable owner to Reporting Daemon SP' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Ownerless service principals are a governance gap'),

        (New-DecomFinding `
            -FindingId 'DEC-CA-001' `
            -Category 'Conditional Access' `
            -Severity 'High' `
            -RiskScore 65 `
            -Confidence 'Medium' `
            -ObjectType 'Policy' `
            -ObjectId 'a1b2c3d4-0006-0006-0006-000000000006' `
            -DisplayName 'Require MFA' `
            -UserPrincipalName '' `
            -Evidence 'CA policy excludes 3 users and 2 groups from MFA requirement — exclusions require review' `
            -EvidenceSource 'identity/conditionalAccess/policies' `
            -GraphEndpoint '/v1.0/identity/conditionalAccess/policies/{id}' `
            -RecommendedAction 'Review and reduce exclusions in policy; initiate access review for excluded identities' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'CA policy exclusions should be time-bound and reviewed quarterly'),

        (New-DecomFinding `
            -FindingId 'DEC-GUEST-001' `
            -Category 'Guest Lifecycle' `
            -Severity 'Low' `
            -RiskScore 32 `
            -Confidence 'Medium' `
            -ObjectType 'User' `
            -ObjectId 'a1b2c3d4-0007-0007-0007-000000000007' `
            -DisplayName 'ext_vendor@tailspin.com' `
            -UserPrincipalName 'ext_vendor_tailspin.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence 'Guest last sign-in 210 days ago — no access review coverage' `
            -EvidenceSource 'signInLogs' `
            -GraphEndpoint '/v1.0/auditLogs/signIns' `
            -RecommendedAction 'Initiate access review for stale guest ext_vendor@tailspin.com' `
            -RemediationMode 'ManualApprovalRequired' `
            -ConsultantNote 'Stale guest — review with business owner for continued need'),

        (New-DecomFinding `
            -FindingId 'DEC-IGA-001' `
            -Category 'Governance' `
            -Severity 'Informational' `
            -RiskScore 18 `
            -Confidence 'Low' `
            -ObjectType 'TenantScope' `
            -ObjectId 'contoso.onmicrosoft.com' `
            -DisplayName 'Entitlement Management' `
            -UserPrincipalName '' `
            -Evidence 'AuditLog.Read.All scope unavailable — IGA coverage assessment incomplete' `
            -EvidenceSource 'graphPermissions' `
            -GraphEndpoint '/v1.0/identityGovernance/entitlementManagement' `
            -RecommendedAction 'Request AuditLog.Read.All and EntitlementManagement.Read.All for full IGA coverage' `
            -RemediationMode 'InformationOnly' `
            -ConsultantNote 'Coverage gap — not a finding against tenant configuration'),

        # DEC-APP-003 — Single owner (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-APP-003' `
            -Category          'Application' `
            -Severity          'Medium' `
            -RiskScore         45 `
            -Confidence        'High' `
            -ObjectType        'Application' `
            -ObjectId          'a1b2c3d4-0010-0010-0010-000000000010' `
            -DisplayName       'Finance Reporting App' `
            -UserPrincipalName '' `
            -Evidence          'Application has only 1 owner — single point of failure for ownership continuity' `
            -EvidenceSource    'applications/{id}/owners' `
            -GraphEndpoint     '/v1.0/applications/{id}/owners' `
            -RecommendedAction 'Add a second owner to Finance Reporting App to ensure ownership continuity' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Single-owner apps are a governance risk if that owner leaves or is disabled'),

        # DEC-APP-004 — Expiring credential (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-APP-004' `
            -Category          'Application' `
            -Severity          'Medium' `
            -RiskScore         48 `
            -Confidence        'High' `
            -ObjectType        'Application' `
            -ObjectId          'a1b2c3d4-0011-0011-0011-000000000011' `
            -DisplayName       'DevOps Pipeline SP' `
            -UserPrincipalName '' `
            -Evidence          'Client secret expires in 14 days (2026-06-13) — renewal not confirmed' `
            -EvidenceSource    'applications/{id}/passwordCredentials' `
            -GraphEndpoint     '/v1.0/applications/{id}?$select=passwordCredentials,keyCredentials' `
            -RecommendedAction 'Rotate expiring client secret for DevOps Pipeline SP before 2026-06-13' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Expiring secrets cause integration failures and may trigger emergency access patterns'),

        # DEC-APP-005 — Expired credential (High)
        (New-DecomFinding `
            -FindingId         'DEC-APP-005' `
            -Category          'Application' `
            -Severity          'High' `
            -RiskScore         68 `
            -Confidence        'High' `
            -ObjectType        'Application' `
            -ObjectId          'a1b2c3d4-0012-0012-0012-000000000012' `
            -DisplayName       'Legacy SSO Connector' `
            -UserPrincipalName '' `
            -Evidence          'Client secret expired 47 days ago (2026-04-13) — credential still attached to application' `
            -EvidenceSource    'applications/{id}/passwordCredentials' `
            -GraphEndpoint     '/v1.0/applications/{id}?$select=passwordCredentials,keyCredentials' `
            -RecommendedAction 'Remove expired credential from Legacy SSO Connector and rotate if integration still active' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Expired credentials are a hygiene issue; confirm whether integration is still in use'),

        # DEC-SPN-001 — Ownerless service principal (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-SPN-001' `
            -Category          'Application' `
            -Severity          'Medium' `
            -RiskScore         44 `
            -Confidence        'High' `
            -ObjectType        'ServicePrincipal' `
            -ObjectId          'a1b2c3d4-0013-0013-0013-000000000013' `
            -DisplayName       'Azure Backup Agent SP' `
            -UserPrincipalName '' `
            -Evidence          'Service principal has no owner assigned — accountability gap for this enterprise application' `
            -EvidenceSource    'servicePrincipals/{id}/owners' `
            -GraphEndpoint     '/v1.0/servicePrincipals/{id}/owners' `
            -RecommendedAction 'Assign accountable owner to Azure Backup Agent SP' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Ownerless service principals with active permissions are ungoverned'),

        # DEC-USER-002 — Disabled user retains app role assignments (High)
        (New-DecomFinding `
            -FindingId         'DEC-USER-002' `
            -Category          'User Lifecycle' `
            -Severity          'High' `
            -RiskScore         72 `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0014-0014-0014-000000000014' `
            -DisplayName       'Morgan Chen' `
            -UserPrincipalName 'morgan.chen@contoso.com' `
            -Evidence          'Disabled user retains 3 app role assignments: Salesforce Admin, SAP HR Read, Workday Integrations' `
            -EvidenceSource    'users/{id}/appRoleAssignments' `
            -GraphEndpoint     '/v1.0/users/{id}/appRoleAssignments' `
            -RecommendedAction 'Revoke all app role assignments for disabled user morgan.chen@contoso.com' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'App role assignments for disabled users represent residual SaaS access risk'),

        # DEC-GUEST-003 — Guest lacks sponsor metadata (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-GUEST-003' `
            -Category          'Guest Lifecycle' `
            -Severity          'Medium' `
            -RiskScore         47 `
            -Confidence        'Medium' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0015-0015-0015-000000000015' `
            -DisplayName       'ext_contractor@northwind.com' `
            -UserPrincipalName 'ext_contractor_northwind.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Guest account has no manager assigned and no department metadata — sponsor cannot be determined' `
            -EvidenceSource    'users/{id}?$select=manager,department,jobTitle' `
            -GraphEndpoint     '/v1.0/users/{id}?$select=manager,department,jobTitle' `
            -RecommendedAction 'Assign a sponsor (manager) and department to ext_contractor@northwind.com or initiate offboarding' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Guest without sponsor metadata cannot be traced to a business owner'),

        # DEC-ROLE-001 — Disabled identity holds privileged role (Critical)
        (New-DecomFinding `
            -FindingId         'DEC-ROLE-001' `
            -Category          'Privileged Access' `
            -Severity          'Critical' `
            -RiskScore         90 `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0016-0016-0016-000000000016' `
            -DisplayName       'Sam Okafor' `
            -UserPrincipalName 'sam.okafor@contoso.com' `
            -Evidence          'Disabled user holds active Privileged Role Administrator assignment — account is disabled' `
            -EvidenceSource    'roleManagement/directory/roleAssignments' `
            -GraphEndpoint     '/v1.0/roleManagement/directory/roleAssignments' `
            -RecommendedAction 'Remove Privileged Role Administrator assignment from disabled user sam.okafor@contoso.com immediately' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Privileged role held by disabled user is a critical security gap'),

        # DEC-CA-002 — CA exclusion group requires review (High)
        (New-DecomFinding `
            -FindingId         'DEC-CA-002' `
            -Category          'Conditional Access' `
            -Severity          'High' `
            -RiskScore         62 `
            -Confidence        'Medium' `
            -ObjectType        'Group' `
            -ObjectId          'a1b2c3d4-0018-0018-0018-000000000018' `
            -DisplayName       'CA-MFA-Exclusion-VendorAccounts' `
            -UserPrincipalName '' `
            -Evidence          'CA exclusion group CA-MFA-Exclusion-VendorAccounts has 8 members — access review status unknown' `
            -EvidenceSource    'identity/conditionalAccess/policies' `
            -GraphEndpoint     '/v1.0/groups/{id}/members' `
            -RecommendedAction 'Create access review for CA-MFA-Exclusion-VendorAccounts; validate all 8 members still require CA exclusion' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'CA exclusion groups with unverified review status expand the attack surface'),

        # DEC-PIM-001 — Disabled user has eligible privileged role (Critical)
        (New-DecomFinding `
            -FindingId         'DEC-PIM-001' `
            -Category          'Privileged Access' `
            -Severity          'Critical' `
            -RiskScore         86 `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0019-0019-0019-000000000019' `
            -DisplayName       'Disabled Admin (PIM)' `
            -UserPrincipalName 'disabled.admin@contoso.com' `
            -Evidence          'Disabled user retains eligible privileged role assignment. Eligibility should be reviewed before account closure is considered complete.' `
            -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
            -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
            -RecommendedAction 'Review and remove eligible privileged role assignment from disabled user disabled.admin@contoso.com' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'PIM eligible assignment on disabled user is a governance gap requiring explicit closure'),

        # DEC-PIM-002 — Guest has eligible privileged role (Critical)
        (New-DecomFinding `
            -FindingId         'DEC-PIM-002' `
            -Category          'Privileged Access' `
            -Severity          'Critical' `
            -RiskScore         84 `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0020-0020-0020-000000000020' `
            -DisplayName       'ext_privileged@fabrikam.com' `
            -UserPrincipalName 'ext_privileged_fabrikam.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Guest identity retains eligible privileged role assignment. Review external privileged access governance and sponsor approval.' `
            -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
            -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
            -RecommendedAction 'Review and remove eligible privileged role from guest; confirm sponsor approval for any continued access' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'External identity with eligible privileged role requires explicit governance justification'),

        # DEC-PIM-003 — PIM activation/review evidence unavailable (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-PIM-003' `
            -Category          'Privileged Access' `
            -Severity          'Medium' `
            -RiskScore         46 `
            -Confidence        'Low' `
            -ObjectType        'Tenant' `
            -ObjectId          'contoso.onmicrosoft.com' `
            -DisplayName       'PIM Coverage' `
            -UserPrincipalName '' `
            -Evidence          'PIM activation and review evidence could not be confirmed from available Graph data. Coverage may be partial.' `
            -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
            -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
            -RecommendedAction 'Grant PrivilegedAccess.Read.AzureAD permission and re-run assessment for full PIM coverage' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'PIM evidence gap — not a finding against tenant configuration'),

        # DEC-AP-001 — Disabled user has active access package assignment (High)
        (New-DecomFinding `
            -FindingId         'DEC-AP-001' `
            -Category          'Governance' `
            -Severity          'High' `
            -RiskScore         70 `
            -Confidence        'High' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0021-0021-0021-000000000021' `
            -DisplayName       'Offboarded Employee' `
            -UserPrincipalName 'offboarded.employee@contoso.com' `
            -Evidence          'Disabled user retains access package assignment. Review Entitlement Management lifecycle closure.' `
            -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
            -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
            -RecommendedAction 'Review and remove access package assignment from disabled user offboarded.employee@contoso.com' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Active access package assignment for disabled user represents lifecycle closure gap'),

        # DEC-AP-002 — Guest has access package assignment requiring sponsor review (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-AP-002' `
            -Category          'Governance' `
            -Severity          'Medium' `
            -RiskScore         52 `
            -Confidence        'Medium' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0022-0022-0022-000000000022' `
            -DisplayName       'ext_vendor2@tailspin.com' `
            -UserPrincipalName 'ext_vendor2_tailspin.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Guest has access package assignment; sponsor or review status requires validation.' `
            -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
            -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
            -RecommendedAction 'Confirm sponsor approval and review status for guest access package assignment' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Guest access package requires explicit sponsor validation'),

        # DEC-AP-003 — Assignment has no visible expiration evidence (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-AP-003' `
            -Category          'Governance' `
            -Severity          'Medium' `
            -RiskScore         48 `
            -Confidence        'Medium' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0023-0023-0023-000000000023' `
            -DisplayName       'contractor@northwind.com' `
            -UserPrincipalName 'contractor_northwind.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Access package assignment does not expose expiration evidence; review assignment lifecycle policy.' `
            -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
            -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
            -RecommendedAction 'Review access package lifecycle policy and set expiration for assignment' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Assignment without expiration evidence requires lifecycle review'),

        # DEC-AP-004 — Access package review coverage could not be confirmed (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-AP-004' `
            -Category          'Governance' `
            -Severity          'Medium' `
            -RiskScore         44 `
            -Confidence        'Low' `
            -ObjectType        'Tenant' `
            -ObjectId          'contoso.onmicrosoft.com' `
            -DisplayName       'Access Package Review Coverage' `
            -UserPrincipalName '' `
            -Evidence          'Access package review coverage could not be confirmed from available Graph data.' `
            -EvidenceSource    'identityGovernance/entitlementManagement/accessPackages' `
            -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/accessPackages' `
            -RecommendedAction 'Grant AccessReview.Read.All and re-run assessment for full access review coverage' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Access review coverage gap — not a finding against tenant configuration'),

        # DEC-AP-005 — Assignment linked to sensitive resource/group (High)
        (New-DecomFinding `
            -FindingId         'DEC-AP-005' `
            -Category          'Governance' `
            -Severity          'High' `
            -RiskScore         68 `
            -Confidence        'Medium' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0024-0024-0024-000000000024' `
            -DisplayName       'contractor2@fabrikam.com' `
            -UserPrincipalName 'contractor2_fabrikam.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Access package assignment appears linked to sensitive resource or group based on resource metadata/name heuristic.' `
            -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
            -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
            -RecommendedAction 'Review access package assignment linked to sensitive resource; confirm business justification and governance approval' `
            -RemediationMode   'ManualApprovalRequired' `
            -ConsultantNote    'Sensitive resource heuristic match — Confidence: Medium'),

        # --- Rev2.3 synthetic findings ---

        # DEC-REV-001 — Access review data available but no decisions recorded (Informational)
        (New-DecomFinding `
            -FindingId         'DEC-REV-001' `
            -Category          'Access Review Governance' `
            -Severity          'Informational' `
            -RiskScore         20 `
            -Confidence        'Low' `
            -ObjectType        'TenantScope' `
            -ObjectId          'tenant-scope' `
            -DisplayName       'Access Review Decision Coverage' `
            -UserPrincipalName '' `
            -Evidence          'Access review definitions found but no review decision records returned — coverage may be partial or reviews may be newly configured.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Verify access review schedules are producing decisions; check reviewer assignments and completion status.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'No decisions recorded — review schedules may be new or incomplete'),

        # DEC-GREV-001 — Guest without recent review evidence (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-GREV-001' `
            -Category          'Guest Lifecycle' `
            -Severity          'Medium' `
            -RiskScore         48 `
            -Confidence        'Low' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0030-0030-0030-000000000030' `
            -DisplayName       'ext_review_missing@fabrikam.com' `
            -UserPrincipalName 'ext_review_missing_fabrikam.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Guest account has no access review decision found within the last 90 days — review coverage cannot be confirmed.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Schedule or confirm access review for guest ext_review_missing@fabrikam.com and ensure decision is recorded.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Guest access review coverage gap — no decision evidence within threshold'),

        # DEC-GREV-002 — Guest without sponsor and without review evidence (High)
        (New-DecomFinding `
            -FindingId         'DEC-GREV-002' `
            -Category          'Guest Lifecycle' `
            -Severity          'High' `
            -RiskScore         63 `
            -Confidence        'Medium' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0031-0031-0031-000000000031' `
            -DisplayName       'ext_unsponsored@tailspin.com' `
            -UserPrincipalName 'ext_unsponsored_tailspin.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Guest account lacks sponsor metadata and no access review decision found — business justification cannot be confirmed.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Assign a sponsor to ext_unsponsored@tailspin.com and create access review; consider offboarding if no sponsor can be identified.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Unsponsored guest without review evidence — elevated governance risk'),

        # DEC-GREV-003 — Privileged guest without review evidence (High)
        (New-DecomFinding `
            -FindingId         'DEC-GREV-003' `
            -Category          'Guest Lifecycle' `
            -Severity          'High' `
            -RiskScore         72 `
            -Confidence        'Medium' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0032-0032-0032-000000000032' `
            -DisplayName       'ext_privileged_norev@fabrikam.com' `
            -UserPrincipalName 'ext_privileged_norev_fabrikam.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Guest holds privileged access (PIM eligible or directory role) and no access review decision found — privileged external access is ungoverned.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Immediately create access review for privileged guest ext_privileged_norev@fabrikam.com; escalate to security team.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Privileged guest without review evidence — highest risk GREV category'),

        # DEC-PIM-005 — PIM eligible user without review evidence (High)
        (New-DecomFinding `
            -FindingId         'DEC-PIM-005' `
            -Category          'Privileged Access' `
            -Severity          'High' `
            -RiskScore         70 `
            -Confidence        'Low' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0033-0033-0033-000000000033' `
            -DisplayName       'eligible.noreview@contoso.com' `
            -UserPrincipalName 'eligible.noreview@contoso.com' `
            -Evidence          'PIM eligible privileged role assignment found but no access review decision evidence detected — governance review cannot be confirmed.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Create access review for PIM eligible assignment for eligible.noreview@contoso.com and confirm review completion.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'PIM eligible assignment without review evidence — governance gap'),

        # DEC-PIM-006 — PIM eligible user with stale review evidence (High)
        (New-DecomFinding `
            -FindingId         'DEC-PIM-006' `
            -Category          'Privileged Access' `
            -Severity          'High' `
            -RiskScore         73 `
            -Confidence        'Medium' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0034-0034-0034-000000000034' `
            -DisplayName       'eligible.stalereview@contoso.com' `
            -UserPrincipalName 'eligible.stalereview@contoso.com' `
            -Evidence          'PIM eligible privileged role assignment last reviewed 2025-09-15 — more than 180 days ago. Review has lapsed.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Initiate new access review for PIM eligible assignment for eligible.stalereview@contoso.com.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Stale PIM review — last decision beyond 180-day threshold'),

        # DEC-PIM-007 — PIM review correlation unavailable (Informational)
        (New-DecomFinding `
            -FindingId         'DEC-PIM-007' `
            -Category          'Privileged Access' `
            -Severity          'Informational' `
            -RiskScore         22 `
            -Confidence        'Low' `
            -ObjectType        'TenantScope' `
            -ObjectId          'tenant-scope' `
            -DisplayName       'PIM Review Correlation' `
            -UserPrincipalName '' `
            -Evidence          'PIM eligible assignment findings detected but access review data unavailable — review correlation could not be performed.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Grant AccessReview.Read.All permission and re-run assessment to enable PIM review correlation.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'PIM review correlation skipped — no AR data available'),

        # DEC-AP-006 — Access package without review schedule (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-AP-006' `
            -Category          'Governance' `
            -Severity          'Medium' `
            -RiskScore         50 `
            -Confidence        'Low' `
            -ObjectType        'TenantScope' `
            -ObjectId          'tenant-scope' `
            -DisplayName       'Access Package Review Coverage' `
            -UserPrincipalName '' `
            -Evidence          'Access package assignments found but no access review definition correlated to entitlement management scope — review coverage cannot be confirmed.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Create access review definitions scoped to entitlement management access packages.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'No AR definition found for entitlement management — coverage gap'),

        # DEC-AP-007 — Access package assignment with stale or unavailable review (Medium)
        (New-DecomFinding `
            -FindingId         'DEC-AP-007' `
            -Category          'Governance' `
            -Severity          'Medium' `
            -RiskScore         54 `
            -Confidence        'Low' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0035-0035-0035-000000000035' `
            -DisplayName       'contractor_stale_review@northwind.com' `
            -UserPrincipalName 'contractor_stale_review_northwind.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Access package assignment has no review decision within 180 days — review evidence stale or unavailable.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Initiate access review for access package assignment for contractor_stale_review@northwind.com.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Stale or missing review decision for access package assignment'),

        # DEC-AP-008 — Access package with incomplete review decision (High)
        (New-DecomFinding `
            -FindingId         'DEC-AP-008' `
            -Category          'Governance' `
            -Severity          'High' `
            -RiskScore         66 `
            -Confidence        'Medium' `
            -ObjectType        'User' `
            -ObjectId          'a1b2c3d4-0036-0036-0036-000000000036' `
            -DisplayName       'contractor_pending@northwind.com' `
            -UserPrincipalName 'contractor_pending_northwind.com#EXT#@contoso.onmicrosoft.com' `
            -Evidence          'Access package assignment review decision is incomplete or not reviewed — reviewer action required.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Follow up with reviewer to complete access review decision for contractor_pending@northwind.com.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Pending review decision requires reviewer action'),

        # DEC-CA-003 — CA exclusion group without review evidence (High)
        (New-DecomFinding `
            -FindingId         'DEC-CA-003' `
            -Category          'Conditional Access' `
            -Severity          'High' `
            -RiskScore         68 `
            -Confidence        'Low' `
            -ObjectType        'Group' `
            -ObjectId          'a1b2c3d4-0037-0037-0037-000000000037' `
            -DisplayName       'CA-MFA-Exclusion-NoReview' `
            -UserPrincipalName '' `
            -Evidence          'CA policy exclusion group has no correlated access review definition — members are excluded from policy without review governance.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Create access review definition scoped to CA-MFA-Exclusion-NoReview group to govern CA exclusion membership.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'CA exclusion group without review governance — attack surface is ungoverned'),

        # DEC-CA-004 — CA exclusion group with stale review (High)
        (New-DecomFinding `
            -FindingId         'DEC-CA-004' `
            -Category          'Conditional Access' `
            -Severity          'High' `
            -RiskScore         70 `
            -Confidence        'Low' `
            -ObjectType        'Group' `
            -ObjectId          'a1b2c3d4-0038-0038-0038-000000000038' `
            -DisplayName       'CA-MFA-Exclusion-StaleReview' `
            -UserPrincipalName '' `
            -Evidence          'CA policy exclusion group last reviewed 2025-08-01 — more than 90 days ago. Review has lapsed for CA exclusion governance.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Initiate new access review for CA-MFA-Exclusion-StaleReview to re-validate CA exclusion membership.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Stale CA exclusion review — last decision beyond 90-day threshold'),

        # DEC-GOV-001 — Access review API unavailable (Informational)
        (New-DecomFinding `
            -FindingId         'DEC-GOV-001' `
            -Category          'Governance' `
            -Severity          'Informational' `
            -RiskScore         18 `
            -Confidence        'Low' `
            -ObjectType        'TenantScope' `
            -ObjectId          'tenant-scope' `
            -DisplayName       'Access Review API Coverage' `
            -UserPrincipalName '' `
            -Evidence          'Access review API cmdlets unavailable — review governance coverage could not be assessed. AccessReview.Read.All permission may be missing.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Grant AccessReview.Read.All permission and re-run assessment to enable access review governance coverage.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Coverage gap — access review API not available in this environment'),

        # DEC-GOV-002 — Access review cmdlet unavailable (Informational)
        (New-DecomFinding `
            -FindingId         'DEC-GOV-002' `
            -Category          'Governance' `
            -Severity          'Informational' `
            -RiskScore         16 `
            -Confidence        'Low' `
            -ObjectType        'TenantScope' `
            -ObjectId          'tenant-scope' `
            -DisplayName       'Access Review Cmdlet Coverage' `
            -UserPrincipalName '' `
            -Evidence          'Access review cmdlet (Get-MgIdentityGovernanceAccessReviewDefinition) is not available in the installed Graph module version — upgrade may be required.' `
            -EvidenceSource    'identityGovernance/accessReviews/definitions' `
            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
            -RecommendedAction 'Upgrade Microsoft.Graph.Identity.Governance module and re-run assessment to enable access review coverage.' `
            -RemediationMode   'InformationOnly' `
            -ConsultantNote    'Module version gap — cmdlet not available in current Graph module')
    )
}

function Invoke-DecomAssessmentDiscovery {
    param(
        [pscustomobject]$Context,
        [switch]$DemoMode
    )

    $coverage = New-DecomCoverage

    if ($DemoMode) {
        $coverage.Users                          = $true
        $coverage.Groups                         = $true
        $coverage.Applications                   = $true
        $coverage.ServicePrincipals              = $true
        $coverage.DirectoryRoles                 = $true
        $coverage.ConditionalAccess              = $true
        $coverage.PimEligibleAssignments         = $true
        $coverage.EntitlementAssignments         = $true
        $coverage.AccessReviews                  = $true
        $coverage.AccessReviewDefinitions        = $true
        $coverage.GuestReviewCorrelation         = $true
        $coverage.PimReviewCorrelation           = $true
        $coverage.AccessPackageReviewCorrelation = $true
        $coverage.CAExclusionReviewCorrelation   = $true
        if ($Context) { $Context | Add-Member -NotePropertyName Coverage -NotePropertyValue $coverage -Force }
        [object[]]$synth = @(Get-DecomSyntheticFindings)
        Write-Output -NoEnumerate $synth
        return
    }

    $findings      = [System.Collections.Generic.List[object]]::new()
    $staleThreshold = (Get-Date).AddDays(-90)
    $disabledUsers = @()
    $apps          = @()

    # --- DEC-USER-001: Disabled users with group memberships ---
    try {
        $disabledUsers = @(Get-MgUser `
            -Filter "accountEnabled eq false" `
            -Select Id,DisplayName,UserPrincipalName,AccountEnabled `
            -All -ErrorAction Stop)
        $coverage.Users = $true
        Write-DecomInfo "User discovery: OK ($($disabledUsers.Count) disabled users)"

        foreach ($user in $disabledUsers) {
            try {
                $memberOf    = @(Get-MgUserMemberOf -UserId $user.Id -All -ErrorAction Stop)
                $memberships = @($memberOf | Where-Object {
                    $_.AdditionalProperties -and
                    $_.AdditionalProperties['@odata.type'] -eq '#microsoft.graph.group'
                })
                if ($memberships.Count -gt 0) {
                    $groupNames = (@($memberships | ForEach-Object {
                        if ($_.AdditionalProperties -and $_.AdditionalProperties['displayName']) {
                            $_.AdditionalProperties['displayName']
                        }
                    } | Where-Object { $_ }) -join ', ')
                    $evidence = "Disabled user retains direct membership in $($memberships.Count) group(s)"
                    if ($groupNames) { $evidence += ": $groupNames" }
                    $findings.Add((New-DecomFinding `
                        -FindingId    'DEC-USER-001' `
                        -Category     'User Lifecycle' `
                        -Severity     'Medium' `
                        -RiskScore    55 `
                        -Confidence   'High' `
                        -ObjectType   'User' `
                        -ObjectId     $user.Id `
                        -DisplayName  $user.DisplayName `
                        -UserPrincipalName $user.UserPrincipalName `
                        -Evidence     $evidence `
                        -EvidenceSource 'users/{id}/memberOf' `
                        -GraphEndpoint  '/v1.0/users/{id}/memberOf' `
                        -RecommendedAction "Remove $($user.UserPrincipalName) from all group memberships" `
                        -RemediationMode 'AutoRemediable' `
                        -ConsultantNote  'Standard group cleanup for disabled user'))
                }
            } catch {
                Write-DecomWarn "Group membership check failed for $($user.UserPrincipalName): $_"
            }
        }
    } catch {
        Write-DecomWarn "User discovery unavailable: $_"
    }

    # --- DEC-APP-001: Applications with no owner ---
    try {
        $apps = @(Get-MgApplication -Select Id,DisplayName,AppId -All -ErrorAction Stop)
        $coverage.Applications = $true
        Write-DecomInfo "Application discovery: OK ($($apps.Count) applications)"

        foreach ($app in $apps) {
            try {
                $owners = @(Get-MgApplicationOwner -ApplicationId $app.Id -ErrorAction Stop | Where-Object { $null -ne $_ })
                if ($owners.Count -eq 0) {
                    $findings.Add((New-DecomFinding `
                        -FindingId    'DEC-APP-001' `
                        -Category     'Application' `
                        -Severity     'Medium' `
                        -RiskScore    51 `
                        -Confidence   'High' `
                        -ObjectType   'Application' `
                        -ObjectId     $app.Id `
                        -DisplayName  $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence     'Application has no owner assigned' `
                        -EvidenceSource 'applications/{id}/owners' `
                        -GraphEndpoint  '/v1.0/applications/{id}/owners' `
                        -RecommendedAction "Assign accountable owner to application '$($app.DisplayName)'" `
                        -RemediationMode 'ManualApprovalRequired' `
                        -ConsultantNote  'Ownerless applications are a governance gap'))
                }
            } catch {
                Write-DecomWarn "Owner check failed for application '$($app.DisplayName)': $_"
            }
        }
    } catch {
        Write-DecomWarn "Application discovery unavailable: $_"
    }

    # --- DEC-GUEST-001: Guests with stale sign-in (SignInActivity property) ---
    try {
        $guests = @(Get-MgUser `
            -Filter "userType eq 'Guest'" `
            -Property Id,DisplayName,UserPrincipalName,SignInActivity `
            -All -ErrorAction Stop)
        $coverage.SignInLogs = $true
        Write-DecomInfo "Guest sign-in discovery: OK ($($guests.Count) guest accounts)"

        $guestStaleThreshold = (Get-Date).AddDays(-180)
        foreach ($guest in $guests) {
            $lastSignIn    = $null
            $hasSignInData = $false

            try {
                if ($guest.SignInActivity -and $guest.SignInActivity.LastSignInDateTime) {
                    $hasSignInData = $true
                    $lastSignIn    = [datetime]$guest.SignInActivity.LastSignInDateTime
                }
            } catch { $hasSignInData = $false }

            if (-not $hasSignInData) { continue }

            if ($null -eq $lastSignIn) {
                $daysStr = 'never signed in'
            } elseif ($lastSignIn -lt $guestStaleThreshold) {
                $daysStr = "$([int]((Get-Date) - $lastSignIn).TotalDays) days ago"
            } else {
                continue
            }

            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-GUEST-001' `
                -Category          'Guest Lifecycle' `
                -Severity          'Low' `
                -RiskScore         32 `
                -Confidence        'Medium' `
                -ObjectType        'User' `
                -ObjectId          $guest.Id `
                -DisplayName       $guest.DisplayName `
                -UserPrincipalName $guest.UserPrincipalName `
                -Evidence          "Guest last sign-in: $daysStr — review for continued access need" `
                -EvidenceSource    'signInActivity' `
                -GraphEndpoint     '/v1.0/users/{id}?$select=signInActivity' `
                -RecommendedAction "Initiate access review for stale guest $($guest.UserPrincipalName)" `
                -RemediationMode   'ManualApprovalRequired' `
                -ConsultantNote    'Confirm with business owner whether guest access is still required'))
        }
    } catch {
        Write-DecomWarn "Guest sign-in discovery unavailable (SignInActivity permission required): $_"
    }

    # --- Extended application analysis (DEC-APP-002, 003, 004, 005) ---
    if ($apps.Count -gt 0) {
    $disabledUserIds = if ($disabledUsers) {
        [System.Collections.Generic.HashSet[string]]@($disabledUsers | ForEach-Object { $_.Id })
    } else {
        [System.Collections.Generic.HashSet[string]]::new()
    }

    $warningDays = 90
    $today       = Get-Date

    foreach ($app in $apps) {
        try {
            $owners = @(Get-MgApplicationOwner -ApplicationId $app.Id -ErrorAction Stop | Where-Object { $null -ne $_ })

            # DEC-APP-002: All owners are disabled users
            if ($owners.Count -gt 0) {
                $activeOwners = @($owners | Where-Object {
                    -not $disabledUserIds.Contains($_.Id)
                })
                if ($activeOwners.Count -eq 0) {
                    $disabledOwnerNames = ($owners | ForEach-Object {
                        $_.AdditionalProperties['userPrincipalName']
                    } | Where-Object { $_ }) -join ', '
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-APP-002' `
                        -Category          'Application' `
                        -Severity          'Critical' `
                        -RiskScore         88 `
                        -Confidence        'High' `
                        -ObjectType        'Application' `
                        -ObjectId          $app.Id `
                        -DisplayName       $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          "Application owned exclusively by disabled user(s): $disabledOwnerNames — no active owner remains" `
                        -EvidenceSource    'applications/{id}/owners' `
                        -GraphEndpoint     '/v1.0/applications/{id}/owners' `
                        -RecommendedAction "Assign active owner to '$($app.DisplayName)'; remove disabled user(s) as owner" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'App is effectively unmanaged — sole owner is disabled'))
                }
            }

            # DEC-APP-003: Exactly one owner (fragile ownership)
            if ($owners.Count -eq 1) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-APP-003' `
                    -Category          'Application' `
                    -Severity          'Medium' `
                    -RiskScore         45 `
                    -Confidence        'High' `
                    -ObjectType        'Application' `
                    -ObjectId          $app.Id `
                    -DisplayName       $app.DisplayName `
                    -UserPrincipalName '' `
                    -Evidence          'Application has only 1 owner — single point of failure for ownership continuity' `
                    -EvidenceSource    'applications/{id}/owners' `
                    -GraphEndpoint     '/v1.0/applications/{id}/owners' `
                    -RecommendedAction "Add a second owner to '$($app.DisplayName)' to ensure ownership continuity" `
                    -RemediationMode   'ManualApprovalRequired' `
                    -ConsultantNote    'Single-owner apps are a governance risk'))
            }

        } catch {
            Write-DecomWarn "Owner check failed for '$($app.DisplayName)': $_"
        }

        # DEC-APP-004 and DEC-APP-005: Credential expiry analysis
        try {
            $appDetail = Get-MgApplication -ApplicationId $app.Id `
                -Select Id,DisplayName,PasswordCredentials,KeyCredentials -ErrorAction Stop

            $allCreds = @()
            if ($appDetail.PasswordCredentials) { $allCreds += $appDetail.PasswordCredentials }
            if ($appDetail.KeyCredentials)      { $allCreds += $appDetail.KeyCredentials }

            foreach ($cred in $allCreds) {
                if (-not $cred.EndDateTime) { continue }
                $expiry    = [datetime]$cred.EndDateTime
                $daysToExp = [int]($expiry - $today).TotalDays
                $credType  = if ($cred.PSObject.Properties.Name -contains 'SecretText') { 'Client secret' } else { 'Certificate' }
                $credHint  = if ($cred.DisplayName) { $cred.DisplayName } else { $cred.KeyId }

                if ($daysToExp -lt 0) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-APP-005' `
                        -Category          'Application' `
                        -Severity          'High' `
                        -RiskScore         68 `
                        -Confidence        'High' `
                        -ObjectType        'Application' `
                        -ObjectId          $app.Id `
                        -DisplayName       $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          "$credType '$credHint' expired $([Math]::Abs($daysToExp)) days ago ($($expiry.ToString('yyyy-MM-dd'))) — still attached to application" `
                        -EvidenceSource    'applications/{id}/passwordCredentials' `
                        -GraphEndpoint     '/v1.0/applications/{id}?$select=passwordCredentials,keyCredentials' `
                        -RecommendedAction "Remove expired $credType from '$($app.DisplayName)' and rotate if integration still active" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Expired credentials are a hygiene issue; confirm whether integration is still in use'))

                } elseif ($daysToExp -le $warningDays) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-APP-004' `
                        -Category          'Application' `
                        -Severity          'Medium' `
                        -RiskScore         48 `
                        -Confidence        'High' `
                        -ObjectType        'Application' `
                        -ObjectId          $app.Id `
                        -DisplayName       $app.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          "$credType '$credHint' expires in $daysToExp days ($($expiry.ToString('yyyy-MM-dd'))) — renewal not confirmed" `
                        -EvidenceSource    'applications/{id}/passwordCredentials' `
                        -GraphEndpoint     '/v1.0/applications/{id}?$select=passwordCredentials,keyCredentials' `
                        -RecommendedAction "Rotate expiring $credType for '$($app.DisplayName)' before $($expiry.ToString('yyyy-MM-dd'))" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Expiring credentials cause integration failures'))
                }
            }
        } catch {
            Write-DecomWarn "Credential check failed for '$($app.DisplayName)': $_"
        }
    }
    } # end if ($apps.Count -gt 0)

    # --- DEC-SPN-001: Service principals with no owner ---
    try {
        $spns = @(Get-MgServicePrincipal `
            -Filter "tags/any(t:t eq 'WindowsAzureActiveDirectoryIntegratedApp')" `
            -Select Id,DisplayName,AppId,Tags `
            -All -ErrorAction Stop)

        if ($spns.Count -eq 0) {
            $spns = @(Get-MgServicePrincipal -Select Id,DisplayName,AppId,Tags -All -ErrorAction Stop |
                Where-Object { $_.Tags -contains 'WindowsAzureActiveDirectoryIntegratedApp' })
        }

        $coverage.ServicePrincipals = $true
        Write-DecomInfo "Service principal discovery: OK ($($spns.Count) enterprise applications)"

        foreach ($spn in $spns) {
            try {
                $spOwners = @(Get-MgServicePrincipalOwner -ServicePrincipalId $spn.Id -ErrorAction Stop)
                if ($spOwners.Count -eq 0) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-SPN-001' `
                        -Category          'Application' `
                        -Severity          'Medium' `
                        -RiskScore         44 `
                        -Confidence        'High' `
                        -ObjectType        'ServicePrincipal' `
                        -ObjectId          $spn.Id `
                        -DisplayName       $spn.DisplayName `
                        -UserPrincipalName '' `
                        -Evidence          'Service principal has no owner assigned — accountability gap for this enterprise application' `
                        -EvidenceSource    'servicePrincipals/{id}/owners' `
                        -GraphEndpoint     '/v1.0/servicePrincipals/{id}/owners' `
                        -RecommendedAction "Assign accountable owner to service principal '$($spn.DisplayName)'" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Ownerless service principals with active permissions are ungoverned'))
                }
            } catch {
                Write-DecomWarn "Owner check failed for SP '$($spn.DisplayName)': $_"
            }
        }
    } catch {
        Write-DecomWarn "Service principal discovery unavailable: $_"
    }

    # --- DEC-USER-002: Disabled users with app role assignments ---
    if ($disabledUsers.Count -gt 0) {
    foreach ($user in $disabledUsers) {
        try {
            $appRoles = @(Get-MgUserAppRoleAssignment -UserId $user.Id -All -ErrorAction Stop)
            if ($appRoles.Count -gt 0) {
                $resourceNames = ($appRoles | ForEach-Object {
                    $_.ResourceDisplayName
                } | Select-Object -Unique | Where-Object { $_ }) -join ', '

                $evidence = "Disabled user retains $($appRoles.Count) app role assignment(s)"
                if ($resourceNames) { $evidence += ": $resourceNames" }

                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-USER-002' `
                    -Category          'User Lifecycle' `
                    -Severity          'High' `
                    -RiskScore         72 `
                    -Confidence        'High' `
                    -ObjectType        'User' `
                    -ObjectId          $user.Id `
                    -DisplayName       $user.DisplayName `
                    -UserPrincipalName $user.UserPrincipalName `
                    -Evidence          $evidence `
                    -EvidenceSource    'users/{id}/appRoleAssignments' `
                    -GraphEndpoint     '/v1.0/users/{id}/appRoleAssignments' `
                    -RecommendedAction "Revoke all app role assignments for disabled user $($user.UserPrincipalName)" `
                    -RemediationMode   'ManualApprovalRequired' `
                    -ConsultantNote    'App role assignments for disabled users represent residual SaaS access risk'))
            }
        } catch {
            Write-DecomWarn "App role assignment check failed for $($user.UserPrincipalName): $_"
        }
    }
    } # end if ($disabledUsers.Count -gt 0)

    # --- DEC-GUEST-002 and DEC-GUEST-003: Guest privilege and sponsor checks ---
    try {
        $guestsFull = @(Get-MgUser `
            -Filter "userType eq 'Guest'" `
            -Property Id,DisplayName,UserPrincipalName,Department,JobTitle `
            -All -ErrorAction Stop)

        Write-DecomInfo "Guest metadata discovery: OK ($($guestsFull.Count) guest accounts)"

        $privilegedRoleNames = @(
            'Global Administrator','Privileged Role Administrator','Security Administrator',
            'Exchange Administrator','SharePoint Administrator','Teams Administrator',
            'User Administrator','Helpdesk Administrator','Application Administrator',
            'Cloud Application Administrator','Compliance Administrator',
            'Conditional Access Administrator','Directory Writers'
        )

        $privilegedRoleMembers = [System.Collections.Generic.HashSet[string]]::new()
        try {
            $dirRoles = @(Get-MgDirectoryRole -ErrorAction Stop)
            foreach ($role in $dirRoles) {
                if ($privilegedRoleNames -contains $role.DisplayName) {
                    $members = @(Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -ErrorAction Stop | Where-Object { $null -ne $_ })
                    foreach ($m in $members) {
                        [void]$privilegedRoleMembers.Add($m.Id)
                    }
                }
            }
            $coverage.DirectoryRoles = $true
        } catch {
            Write-DecomWarn "Privileged role member lookup unavailable: $_"
        }

        foreach ($guest in $guestsFull) {

            # DEC-GUEST-002: Guest holds privileged role
            if ($privilegedRoleMembers.Contains($guest.Id)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GUEST-002' `
                    -Category          'Guest Lifecycle' `
                    -Severity          'Critical' `
                    -RiskScore         85 `
                    -Confidence        'High' `
                    -ObjectType        'User' `
                    -ObjectId          $guest.Id `
                    -DisplayName       $guest.DisplayName `
                    -UserPrincipalName $guest.UserPrincipalName `
                    -Evidence          'Guest account holds active privileged directory role — explicit business justification required' `
                    -EvidenceSource    'directoryRoles/{id}/members' `
                    -GraphEndpoint     '/v1.0/directoryRoles/{id}/members' `
                    -RecommendedAction "Review privileged role assignment for guest $($guest.UserPrincipalName); assign sponsor; consider role removal" `
                    -RemediationMode   'ManualApprovalRequired' `
                    -ConsultantNote    'Guest with privileged role requires explicit business justification and named sponsor'))
            }

            # DEC-GUEST-003: Guest lacks sponsor metadata
            $hasDepartment = ($null -ne $guest.Department -and $guest.Department -ne '')
            $hasManager    = $false
            try {
                $mgr        = Get-MgUserManager -UserId $guest.Id -ErrorAction Stop
                $hasManager = ($null -ne $mgr)
            } catch { $hasManager = $false }

            if (-not $hasManager -and -not $hasDepartment) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GUEST-003' `
                    -Category          'Guest Lifecycle' `
                    -Severity          'Medium' `
                    -RiskScore         47 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $guest.Id `
                    -DisplayName       $guest.DisplayName `
                    -UserPrincipalName $guest.UserPrincipalName `
                    -Evidence          'Guest account has no manager assigned and no department metadata — sponsor cannot be determined' `
                    -EvidenceSource    'users/{id}?$select=manager,department' `
                    -GraphEndpoint     '/v1.0/users/{id}?$select=manager,department' `
                    -RecommendedAction "Assign a sponsor (manager) and department to $($guest.UserPrincipalName) or initiate offboarding" `
                    -RemediationMode   'ManualApprovalRequired' `
                    -ConsultantNote    'Guest without sponsor metadata cannot be traced to a business owner'))
            }
        }
    } catch {
        Write-DecomWarn "Guest metadata discovery unavailable: $_"
    }

    # --- DEC-ROLE-001 and DEC-USER-003: Privileged role residue on disabled users ---
    try {
        $allRoles = @(Get-MgDirectoryRole -ErrorAction Stop)
        $coverage.DirectoryRoles = $true
        Write-DecomInfo "Directory role residue discovery: OK ($($allRoles.Count) active roles)"

        $disabledUserIdSet = if ($disabledUsers.Count -gt 0) {
            [System.Collections.Generic.HashSet[string]]@($disabledUsers | ForEach-Object { $_.Id })
        } else {
            [System.Collections.Generic.HashSet[string]]::new()
        }

        foreach ($role in $allRoles) {
            try {
                $roleMembers = @(Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -ErrorAction Stop | Where-Object { $null -ne $_ })
                foreach ($member in $roleMembers) {
                    if ($member.AdditionalProperties['@odata.type'] -ne '#microsoft.graph.user') { continue }
                    if (-not $disabledUserIdSet.Contains($member.Id)) { continue }

                    # PS5.1-safe null guards
                    $memberUpn  = if ($member.AdditionalProperties['userPrincipalName']) {
                        $member.AdditionalProperties['userPrincipalName']
                    } else { '' }
                    $memberName = if ($member.AdditionalProperties['displayName']) {
                        $member.AdditionalProperties['displayName']
                    } else { 'Unknown' }

                    # DEC-USER-003: lifecycle closure failure
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-USER-003' `
                        -Category          'User Lifecycle' `
                        -Severity          'Critical' `
                        -RiskScore         92 `
                        -Confidence        'High' `
                        -ObjectType        'User' `
                        -ObjectId          $member.Id `
                        -DisplayName       $memberName `
                        -UserPrincipalName $memberUpn `
                        -Evidence          "Disabled user retains $($role.DisplayName) role assignment" `
                        -EvidenceSource    'directoryRoles/{id}/members' `
                        -GraphEndpoint     '/v1.0/directoryRoles/{id}/members' `
                        -RecommendedAction "Remove $($role.DisplayName) role assignment from disabled user $memberUpn immediately" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Disabled user with privileged role — lifecycle closure incomplete'))

                    # DEC-ROLE-001: privileged access residue
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-ROLE-001' `
                        -Category          'Privileged Access' `
                        -Severity          'Critical' `
                        -RiskScore         90 `
                        -Confidence        'High' `
                        -ObjectType        'User' `
                        -ObjectId          $member.Id `
                        -DisplayName       $memberName `
                        -UserPrincipalName $memberUpn `
                        -Evidence          "Disabled identity holds active $($role.DisplayName) privileged role — account is disabled" `
                        -EvidenceSource    'roleManagement/directory/roleAssignments' `
                        -GraphEndpoint     '/v1.0/roleManagement/directory/roleAssignments' `
                        -RecommendedAction "Remove $($role.DisplayName) assignment from $memberUpn; escalate to security team" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Privileged role held by disabled identity — escalate immediately'))
                }
            } catch {
                Write-DecomWarn "Role member check failed for '$($role.DisplayName)': $_"
            }
        }
    } catch {
        Write-DecomWarn "Directory role discovery unavailable (RoleManagement.Read.Directory required): $_"
    }

    # --- DEC-CA-001 and DEC-CA-002: Conditional Access exclusion analysis ---
    try {
        $caPolicies = @(Get-MgIdentityConditionalAccessPolicy -ErrorAction Stop)
        $coverage.ConditionalAccess = $true
        Write-DecomInfo "Conditional access discovery: OK ($($caPolicies.Count) policies)"

        foreach ($policy in $caPolicies) {
            if ($policy.State -eq 'disabled') { continue }

            $excludedUsers  = @($policy.Conditions.Users.ExcludeUsers  | Where-Object { $_ })
            $excludedGroups = @($policy.Conditions.Users.ExcludeGroups | Where-Object { $_ })

            $totalExclusions = $excludedUsers.Count + $excludedGroups.Count
            if ($totalExclusions -eq 0) { continue }

            # DEC-CA-001: Policy has user/group exclusions
            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-CA-001' `
                -Category          'Conditional Access' `
                -Severity          'High' `
                -RiskScore         65 `
                -Confidence        'Medium' `
                -ObjectType        'Policy' `
                -ObjectId          $policy.Id `
                -DisplayName       $policy.DisplayName `
                -UserPrincipalName '' `
                -Evidence          "CA policy excludes $($excludedUsers.Count) user(s) and $($excludedGroups.Count) group(s) from policy scope" `
                -EvidenceSource    'identity/conditionalAccess/policies' `
                -GraphEndpoint     '/v1.0/identity/conditionalAccess/policies/{id}' `
                -RecommendedAction "Review and reduce exclusions in '$($policy.DisplayName)'; initiate access review for excluded identities" `
                -RemediationMode   'ManualApprovalRequired' `
                -ConsultantNote    'CA policy exclusions should be time-bound and reviewed quarterly'))

            # DEC-CA-002: Analyze excluded groups for membership
            foreach ($groupId in $excludedGroups) {
                try {
                    $group   = Get-MgGroup -GroupId $groupId -Select Id,DisplayName -ErrorAction Stop
                    $members = @(Get-MgGroupMember -GroupId $groupId -All -ErrorAction Stop)

                    if ($members.Count -gt 0) {
                        $findings.Add((New-DecomFinding `
                            -FindingId         'DEC-CA-002' `
                            -Category          'Conditional Access' `
                            -Severity          'High' `
                            -RiskScore         62 `
                            -Confidence        'Medium' `
                            -ObjectType        'Group' `
                            -ObjectId          $groupId `
                            -DisplayName       $group.DisplayName `
                            -UserPrincipalName '' `
                            -Evidence          "CA exclusion group '$($group.DisplayName)' has $($members.Count) members in policy '$($policy.DisplayName)' — access review status unknown" `
                            -EvidenceSource    'identity/conditionalAccess/policies' `
                            -GraphEndpoint     '/v1.0/groups/{id}/members' `
                            -RecommendedAction "Create access review for '$($group.DisplayName)'; validate all $($members.Count) members still require CA exclusion" `
                            -RemediationMode   'ManualApprovalRequired' `
                            -ConsultantNote    'CA exclusion group members require periodic attestation'))
                    }
                } catch {
                    Write-DecomWarn "CA exclusion group check failed for group $groupId`: $_"
                }
            }
        }
    } catch {
        Write-DecomWarn "Conditional access discovery unavailable (Policy.Read.All required): $_"
    }

    # --- Rev2.2 PIM: Eligible privileged assignment visibility ---
    try {
        $pimCmdlet = Get-Command 'Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance' -ErrorAction SilentlyContinue
        if ($null -eq $pimCmdlet) {
            Write-DecomWarn 'PIM eligible assignment cmdlet unavailable in installed Graph module'
        } else {
            $eligibleAssignments = @(Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -All -ErrorAction Stop)
            $coverage.PimEligibleAssignments = $true
            Write-DecomInfo "PIM eligible assignment discovery: OK ($($eligibleAssignments.Count) eligible assignments)"

            # Build lookup sets for disabled and guest users (reuse from earlier in function)
            $pimDisabledIdSet = [System.Collections.Generic.HashSet[string]]::new()
            if ($disabledUsers -and $disabledUsers.Count -gt 0) {
                foreach ($u in $disabledUsers) { if ($u -and $u.Id) { [void]$pimDisabledIdSet.Add([string]$u.Id) } }
            }
            $pimGuestIdSet = [System.Collections.Generic.HashSet[string]]::new()
            if ($null -ne $guestsFull -and $guestsFull.Count -gt 0) {
                foreach ($g in $guestsFull) { if ($g -and $g.Id) { [void]$pimGuestIdSet.Add([string]$g.Id) } }
            }

            $pim003Emitted = $false

            foreach ($assignment in $eligibleAssignments) {
                $principalId = $assignment.PrincipalId
                if (-not $principalId) { continue }

                $roleDefId   = if ($assignment.RoleDefinitionId) { $assignment.RoleDefinitionId } else { '' }
                $roleName    = if ($assignment.RoleDefinition -and $assignment.RoleDefinition.DisplayName) {
                    $assignment.RoleDefinition.DisplayName
                } else { $roleDefId }

                # Resolve display name from disabled/guest lookups
                $principalName = ''
                $principalUpn  = ''
                if ($disabledUsers) {
                    $matchUser = $disabledUsers | Where-Object { $_.Id -eq $principalId } | Select-Object -First 1
                    if ($matchUser) {
                        $principalName = $matchUser.DisplayName
                        $principalUpn  = $matchUser.UserPrincipalName
                    }
                }
                if (-not $principalName -and $null -ne $guestsFull) {
                    $matchGuest = $guestsFull | Where-Object { $_.Id -eq $principalId } | Select-Object -First 1
                    if ($matchGuest) {
                        $principalName = $matchGuest.DisplayName
                        $principalUpn  = $matchGuest.UserPrincipalName
                    }
                }
                if (-not $principalName) { $principalName = $principalId }

                # DEC-PIM-001: Disabled user has eligible privileged role
                if ($pimDisabledIdSet.Contains($principalId)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-PIM-001' `
                        -Category          'Privileged Access' `
                        -Severity          'Critical' `
                        -RiskScore         86 `
                        -Confidence        'High' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Disabled user retains eligible privileged role assignment$(if ($roleName) {" for role: $roleName"}). Eligibility should be reviewed before account closure is considered complete." `
                        -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
                        -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
                        -RecommendedAction "Review and remove eligible privileged role assignment from disabled user $principalUpn" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'PIM eligible assignment on disabled user is a governance gap requiring explicit closure'))
                }
                # DEC-PIM-002: Guest has eligible privileged role
                elseif ($pimGuestIdSet.Contains($principalId)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-PIM-002' `
                        -Category          'Privileged Access' `
                        -Severity          'Critical' `
                        -RiskScore         84 `
                        -Confidence        'High' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Guest identity retains eligible privileged role assignment$(if ($roleName) {" for role: $roleName"}). Review external privileged access governance and sponsor approval." `
                        -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
                        -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
                        -RecommendedAction "Review and remove eligible privileged role from guest $principalUpn; confirm sponsor approval for any continued access" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'External identity with eligible privileged role requires explicit governance justification'))
                }
                # DEC-PIM-004: Eligible privileged assignment requires governance review
                else {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-PIM-004' `
                        -Category          'Privileged Access' `
                        -Severity          'High' `
                        -RiskScore         66 `
                        -Confidence        'Medium' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Eligible privileged role assignment$(if ($roleName) {" for role: $roleName"}) — activation and review status unknown." `
                        -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
                        -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
                        -RecommendedAction "Review governance controls for eligible privileged assignment for principal $principalId" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Eligible privileged assignment requires governance review; activation evidence unavailable'))
                }
            }

            # DEC-PIM-003: Emit at most once if eligible assignments exist but activation evidence unavailable
            if ($eligibleAssignments.Count -gt 0 -and -not $pim003Emitted) {
                $pim003Emitted = $true
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-PIM-003' `
                    -Category          'Privileged Access' `
                    -Severity          'Medium' `
                    -RiskScore         46 `
                    -Confidence        'Low' `
                    -ObjectType        'Tenant' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'PIM Coverage' `
                    -UserPrincipalName '' `
                    -Evidence          'PIM activation and review evidence could not be confirmed from available Graph data. Coverage may be partial.' `
                    -EvidenceSource    'roleManagement/directory/roleEligibilityScheduleInstances' `
                    -GraphEndpoint     '/v1.0/roleManagement/directory/roleEligibilityScheduleInstances' `
                    -RecommendedAction 'Grant PrivilegedAccess.Read.AzureAD permission and re-run assessment for full PIM coverage' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'PIM evidence gap — not a finding against tenant configuration'))
            }
        }
    } catch {
        Write-DecomWarn "PIM eligible assignment discovery unavailable: $_"
    }

    # --- Coverage probes for remaining areas (no detection logic yet) ---
    try {
        $null = Get-MgGroup -Top 1 -ErrorAction Stop
        $coverage.Groups = $true
        Write-DecomInfo "Group discovery: OK"
    } catch {
        Write-DecomWarn "Group discovery unavailable: $_"
    }

    try {
        $null = Get-MgServicePrincipal -Top 1 -ErrorAction Stop
        $coverage.ServicePrincipals = $true
        Write-DecomInfo "Service principal discovery: OK"
    } catch {
        Write-DecomWarn "Service principal discovery unavailable: $_"
    }


    try {
        $null = Get-MgAuditLogSignIn -Top 1 -ErrorAction Stop
        $coverage.AuditLogs = $true
        Write-DecomInfo "Audit log discovery: OK"
    } catch {
        Write-DecomWarn "Audit log discovery unavailable (AuditLog.Read.All required): $_"
    }

    # --- Rev2.2 AP: Access Package assignment visibility ---
    try {
        # Check cmdlet availability first
        $apAssignCmdlet  = Get-Command 'Get-MgEntitlementManagementAssignment' -ErrorAction SilentlyContinue
        $apAssignCmdlet2 = Get-Command 'Get-MgIdentityGovernanceEntitlementManagementAccessPackageAssignment' -ErrorAction SilentlyContinue

        $apAssignments = $null
        if ($null -ne $apAssignCmdlet) {
            $apAssignments = @(Get-MgEntitlementManagementAssignment -All -ErrorAction Stop)
        } elseif ($null -ne $apAssignCmdlet2) {
            $apAssignments = @(Get-MgIdentityGovernanceEntitlementManagementAccessPackageAssignment -All -ErrorAction Stop)
        }

        if ($null -ne $apAssignments) {
            $coverage.EntitlementManagement  = $true
            $coverage.EntitlementAssignments = $true
            Write-DecomInfo "Access package assignment discovery: OK ($($apAssignments.Count) assignments)"

            # Build lookup sets
            $apDisabledIdSet = [System.Collections.Generic.HashSet[string]]::new()
            if ($disabledUsers -and $disabledUsers.Count -gt 0) {
                foreach ($u in $disabledUsers) { if ($u -and $u.Id) { [void]$apDisabledIdSet.Add([string]$u.Id) } }
            }
            $apGuestIdSet = [System.Collections.Generic.HashSet[string]]::new()
            if ($null -ne $guestsFull -and $guestsFull.Count -gt 0) {
                foreach ($g in $guestsFull) { if ($g -and $g.Id) { [void]$apGuestIdSet.Add([string]$g.Id) } }
            }

            $sensitiveKeywords = @('admin','privileged','global','security','breakglass','break-glass',
                                   'tier0','tier-0','pim','identity','entra')

            $ap004Emitted = $false

            foreach ($assignment in $apAssignments) {
                # Resolve principal ID
                $principalId = ''
                if ($assignment.AccessPackageSubject -and $assignment.AccessPackageSubject.ObjectId) {
                    $principalId = $assignment.AccessPackageSubject.ObjectId
                } elseif ($assignment.TargetId) {
                    $principalId = $assignment.TargetId
                }
                if (-not $principalId) { continue }

                # Resolve state — active if Delivered, active, or no state
                $state = if ($assignment.State) { $assignment.State.ToLower() } else { 'active' }
                if ($state -notin @('delivered','active','pendingdelivery','')) {
                    if ($state -in @('expired','canceled','rejected')) { continue }
                }

                # Resolve display name
                $principalName = ''
                $principalUpn  = ''
                if ($assignment.AccessPackageSubject) {
                    if ($assignment.AccessPackageSubject.DisplayName) { $principalName = $assignment.AccessPackageSubject.DisplayName }
                    if ($assignment.AccessPackageSubject.Email)       { $principalUpn  = $assignment.AccessPackageSubject.Email }
                }
                if (-not $principalName) { $principalName = $principalId }

                # Resolve access package name
                $pkgName = ''
                if ($assignment.AccessPackage -and $assignment.AccessPackage.DisplayName) {
                    $pkgName = $assignment.AccessPackage.DisplayName
                }

                # DEC-AP-001: Disabled user has active access package assignment
                if ($principalId -and $apDisabledIdSet.Contains($principalId)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-AP-001' `
                        -Category          'Governance' `
                        -Severity          'High' `
                        -RiskScore         70 `
                        -Confidence        'High' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Disabled user retains access package assignment$(if ($pkgName) {" for package: $pkgName"}). Review Entitlement Management lifecycle closure." `
                        -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
                        -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
                        -RecommendedAction "Review and remove access package assignment from disabled user $principalUpn" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Active access package assignment for disabled user represents lifecycle closure gap'))
                }
                # DEC-AP-002: Guest has access package assignment
                elseif ($principalId -and $apGuestIdSet.Contains($principalId)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-AP-002' `
                        -Category          'Governance' `
                        -Severity          'Medium' `
                        -RiskScore         52 `
                        -Confidence        'Medium' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Guest has access package assignment$(if ($pkgName) {" for package: $pkgName"}); sponsor or review status requires validation." `
                        -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
                        -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
                        -RecommendedAction "Confirm sponsor approval and review status for guest $principalUpn access package assignment" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Guest access package requires explicit sponsor validation'))
                }

                # DEC-AP-003: Assignment has no visible expiration evidence
                $hasExpiry = $false
                if ($assignment.Schedule -and $assignment.Schedule.Expiration) {
                    if ($assignment.Schedule.Expiration.EndDateTime -or
                        $assignment.Schedule.Expiration.Duration) {
                        $hasExpiry = $true
                    }
                }
                if (-not $hasExpiry -and $assignment.ExpiredDateTime) { $hasExpiry = $true }
                if (-not $hasExpiry) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-AP-003' `
                        -Category          'Governance' `
                        -Severity          'Medium' `
                        -RiskScore         48 `
                        -Confidence        'Medium' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Access package assignment$(if ($pkgName) {" for package: $pkgName"}) does not expose expiration evidence; review assignment lifecycle policy." `
                        -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
                        -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
                        -RecommendedAction 'Review access package lifecycle policy and set expiration for this assignment' `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Assignment without expiration evidence requires lifecycle review'))
                }

                # DEC-AP-005: Assignment linked to sensitive resource (heuristic)
                $isSensitive = $false
                if ($pkgName) {
                    foreach ($kw in $sensitiveKeywords) {
                        if ($pkgName.ToLower().Contains($kw)) { $isSensitive = $true; break }
                    }
                }
                if ($isSensitive) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-AP-005' `
                        -Category          'Governance' `
                        -Severity          'High' `
                        -RiskScore         68 `
                        -Confidence        'Medium' `
                        -ObjectType        'User' `
                        -ObjectId          $principalId `
                        -DisplayName       $principalName `
                        -UserPrincipalName $principalUpn `
                        -Evidence          "Access package assignment appears linked to sensitive resource or group based on resource metadata/name heuristic." `
                        -EvidenceSource    'identityGovernance/entitlementManagement/assignments' `
                        -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/assignments' `
                        -RecommendedAction "Review access package assignment linked to sensitive resource '$pkgName'; confirm business justification and governance approval" `
                        -RemediationMode   'ManualApprovalRequired' `
                        -ConsultantNote    'Sensitive resource heuristic match — Confidence: Medium'))
                }
            }

            # DEC-AP-004: Emit once — access review coverage could not be confirmed
            if (-not $ap004Emitted) {
                $ap004Emitted = $true
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-AP-004' `
                    -Category          'Governance' `
                    -Severity          'Medium' `
                    -RiskScore         44 `
                    -Confidence        'Low' `
                    -ObjectType        'Tenant' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'Access Package Review Coverage' `
                    -UserPrincipalName '' `
                    -Evidence          'Access package review coverage could not be confirmed from available Graph data.' `
                    -EvidenceSource    'identityGovernance/entitlementManagement/accessPackages' `
                    -GraphEndpoint     '/v1.0/identityGovernance/entitlementManagement/accessPackages' `
                    -RecommendedAction 'Grant AccessReview.Read.All and re-run assessment for full access review coverage' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Access review coverage gap — not a finding against tenant configuration'))
            }

        } else {
            Write-DecomWarn 'Access package assignment cmdlets unavailable in installed Graph module'
        }
    } catch {
        Write-DecomWarn "Access package assignment discovery unavailable (EntitlementManagement.Read.All required): $_"
    }

    # =========================================================================
    # Rev2.3 — Access Review Governance Sections
    # =========================================================================

    # Dedup HashSet for all Rev2.3 findings
    $emittedRev23 = [System.Collections.Generic.HashSet[string]]::new()

    # --- Rev2.3 M2: Access review data collection ---
    $govApiAvailable    = $false
    $accessReviewData   = $null
    $arDefinitions      = @()
    $arInstances        = @()
    $arDecisions        = @()

    $arDefCmdlet = Get-DecomAvailableCommand -Names @(
        'Get-MgIdentityGovernanceAccessReviewDefinition',
        'Get-MgAccessReviewDefinition'
    )

    if ($null -eq $arDefCmdlet) {
        Write-DecomWarn 'Access review definition cmdlet unavailable in installed Graph module'
        $govApiAvailable = $false
        $govKey = 'DEC-GOV-002|tenant-scope'
        if ($emittedRev23.Add($govKey)) {
            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-GOV-002' `
                -Category          'Governance' `
                -Severity          'Informational' `
                -RiskScore         16 `
                -Confidence        'Low' `
                -ObjectType        'TenantScope' `
                -ObjectId          'tenant-scope' `
                -DisplayName       'Access Review Cmdlet Coverage' `
                -UserPrincipalName '' `
                -Evidence          'Access review cmdlet (Get-MgIdentityGovernanceAccessReviewDefinition) is not available in the installed Graph module version.' `
                -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                -RecommendedAction 'Upgrade Microsoft.Graph.Identity.Governance module and re-run assessment to enable access review coverage.' `
                -RemediationMode   'InformationOnly' `
                -ConsultantNote    'Module version gap — cmdlet not available in current Graph module'))
        }
    } else {
        try {
            $arDefinitions = @(& $arDefCmdlet -All -ErrorAction Stop)
            $coverage.AccessReviews           = $true
            $coverage.AccessReviewDefinitions = $true
            Write-DecomInfo "Access review definition discovery: OK ($($arDefinitions.Count) definitions)"
            $govApiAvailable  = $true
            $accessReviewData = [PSCustomObject]@{ Definitions=$arDefinitions; Instances=@(); Decisions=@() }

            # Try to collect instances
            $arInstCmdlet = Get-DecomAvailableCommand -Names @(
                'Get-MgIdentityGovernanceAccessReviewDefinitionInstance',
                'Get-MgAccessReviewDefinitionInstance'
            )
            if ($null -ne $arInstCmdlet -and $arDefinitions.Count -gt 0) {
                $allInstances = [System.Collections.Generic.List[object]]::new()
                foreach ($def in $arDefinitions) {
                    try {
                        $defInst = @(& $arInstCmdlet -AccessReviewScheduleDefinitionId $def.Id -All -ErrorAction Stop)
                        foreach ($inst in $defInst) { $allInstances.Add($inst) }
                    } catch {
                        Write-DecomWarn "Access review instance collection failed for definition $($def.Id): $_"
                    }
                }
                $arInstances = @($allInstances)
                $coverage.AccessReviewInstances = $true
                $accessReviewData.Instances = $arInstances
                Write-DecomInfo "Access review instance discovery: OK ($($arInstances.Count) instances)"
            }

            # Try to collect decisions
            $arDecCmdlet = Get-DecomAvailableCommand -Names @(
                'Get-MgIdentityGovernanceAccessReviewDefinitionInstanceDecision',
                'Get-MgAccessReviewDefinitionInstanceDecision'
            )
            if ($null -ne $arDecCmdlet -and $arInstances.Count -gt 0) {
                $allDecisions = [System.Collections.Generic.List[object]]::new()
                foreach ($def in $arDefinitions) {
                    foreach ($inst in ($arInstances | Where-Object { $_.AccessReviewScheduleDefinitionId -eq $def.Id -or $null -ne $_ })) {
                        try {
                            $instId = if ($inst.Id) { $inst.Id } else { continue }
                            $decs = @(& $arDecCmdlet `
                                -AccessReviewScheduleDefinitionId $def.Id `
                                -AccessReviewInstanceId $instId `
                                -All -ErrorAction Stop)
                            foreach ($d in $decs) { $allDecisions.Add($d) }
                        } catch {
                            Write-DecomWarn "Access review decision collection failed: $_"
                        }
                    }
                }
                $arDecisions = @($allDecisions)
                $coverage.AccessReviewDecisions = $true
                $accessReviewData.Decisions = $arDecisions
                Write-DecomInfo "Access review decision discovery: OK ($($arDecisions.Count) decisions)"
            }

            # DEC-REV-001: Definitions exist but no decisions
            if ($arDefinitions.Count -gt 0 -and $arDecisions.Count -eq 0) {
                $rev001Key = 'DEC-REV-001|tenant-scope'
                if ($emittedRev23.Add($rev001Key)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-001' `
                        -Category          'Access Review Governance' `
                        -Severity          'Informational' `
                        -RiskScore         20 `
                        -Confidence        'Low' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          'tenant-scope' `
                        -DisplayName       'Access Review Decision Coverage' `
                        -UserPrincipalName '' `
                        -Evidence          "Access review definitions found ($($arDefinitions.Count)) but no review decision records returned — coverage may be partial or reviews newly configured." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                        -RecommendedAction 'Verify access review schedules are producing decisions; check reviewer assignments and completion status.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'No decisions recorded — review schedules may be new or incomplete'))
                }
            }

        } catch {
            Write-DecomWarn "Access review data collection failed: $_"
            $govApiAvailable = $false
            $govKey = 'DEC-GOV-002|tenant-scope'
            if ($emittedRev23.Add($govKey)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GOV-002' `
                    -Category          'Governance' `
                    -Severity          'Informational' `
                    -RiskScore         16 `
                    -Confidence        'Low' `
                    -ObjectType        'TenantScope' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'Access Review Cmdlet Coverage' `
                    -UserPrincipalName '' `
                    -Evidence          'Access review data collection failed — review governance coverage could not be assessed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction 'Verify AccessReview.Read.All permission and re-run assessment.' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Access review collection error'))
            }
        }
    }

    # DEC-GOV-001: Emit once if govApiAvailable is false (covers both cmdlet-unavailable and exception paths)
    if (-not $govApiAvailable) {
        $gov001Key = 'DEC-GOV-001|tenant-scope'
        if ($emittedRev23.Add($gov001Key)) {
            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-GOV-001' `
                -Category          'Governance' `
                -Severity          'Informational' `
                -RiskScore         18 `
                -Confidence        'Low' `
                -ObjectType        'TenantScope' `
                -ObjectId          'tenant-scope' `
                -DisplayName       'Access Review API Coverage' `
                -UserPrincipalName '' `
                -Evidence          'Access review API cmdlets unavailable — review governance coverage could not be assessed. AccessReview.Read.All permission may be missing.' `
                -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                -RecommendedAction 'Grant AccessReview.Read.All permission and re-run assessment to enable access review governance coverage.' `
                -RemediationMode   'InformationOnly' `
                -ConsultantNote    'Coverage gap — access review API not available in this environment'))
        }
    }

    # DEC-GOV-003: Licensing may limit evidence coverage — emit when API available but 0 definitions returned
    if ($govApiAvailable -and $arDefinitions.Count -eq 0) {
        $gov003Key = 'DEC-GOV-003|tenant-scope'
        if ($emittedRev23.Add($gov003Key)) {
            $findings.Add((New-DecomFinding `
                -FindingId         'DEC-GOV-003' `
                -Category          'Governance' `
                -Severity          'Informational' `
                -RiskScore         14 `
                -Confidence        'Low' `
                -ObjectType        'TenantScope' `
                -ObjectId          'tenant-scope' `
                -DisplayName       'Access Review Licensing Coverage' `
                -UserPrincipalName '' `
                -Evidence          'Access review API cmdlet is available but returned 0 review definitions. Entra ID Governance licensing (P2 or Governance SKU) may be absent or limited.' `
                -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                -RecommendedAction 'Verify Entra ID Governance or P2 licensing is assigned and access review definitions exist before concluding no reviews are configured.' `
                -RemediationMode   'InformationOnly' `
                -ConsultantNote    'Zero definitions returned — licensing gap or reviews not yet configured'))
        }
    }

    # --- Rev2.3 M2B: Live review decision findings (DEC-REV-002/003/004/005) ---
    if ($govApiAvailable -and $null -ne $accessReviewData) {

        $staleReviewThreshold90 = (Get-Date).AddDays(-90)

        # DEC-REV-002: Instances where EndDateTime is older than 90 days
        foreach ($inst in $arInstances) {
            $instEnd = $null
            try {
                if ($inst.EndDateTime) { $instEnd = [datetime]$inst.EndDateTime }
            } catch { $instEnd = $null }
            if ($null -ne $instEnd -and $instEnd -lt $staleReviewThreshold90) {
                $defId    = if ($inst.AccessReviewScheduleDefinitionId) { $inst.AccessReviewScheduleDefinitionId } else { 'unknown' }
                $rev002Key = "DEC-REV-002|$defId|$($inst.Id)"
                if ($emittedRev23.Add($rev002Key)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-002' `
                        -Category          'Access Review Governance' `
                        -Severity          'Medium' `
                        -RiskScore         45 `
                        -Confidence        'Medium' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          $defId `
                        -DisplayName       'Stale Access Review Instance' `
                        -UserPrincipalName '' `
                        -Evidence          "Access review instance ended $($instEnd.ToString('yyyy-MM-dd')) — more than 90 days ago. Review cadence may have lapsed." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions/{id}/instances' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions/{id}/instances' `
                        -RecommendedAction 'Verify review schedule and create new review instance to maintain governance cadence.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'Review instance ended >90 days ago — cadence may have lapsed'))
                }
            }
        }

        # DEC-REV-003: Instances with incomplete/pending status OR decisions with NotReviewed
        $incompleteInstIds = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($inst in $arInstances) {
            $instStatus = if ($inst.Status) { $inst.Status.ToLower() } else { '' }
            if ($instStatus -in @('inprogress','notstarted','starting')) {
                $defId    = if ($inst.AccessReviewScheduleDefinitionId) { $inst.AccessReviewScheduleDefinitionId } else { 'unknown' }
                $rev003Key = "DEC-REV-003|$defId|$($inst.Id)"
                if ($emittedRev23.Add($rev003Key)) {
                    [void]$incompleteInstIds.Add($inst.Id)
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-003' `
                        -Category          'Access Review Governance' `
                        -Severity          'Medium' `
                        -RiskScore         50 `
                        -Confidence        'Medium' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          $defId `
                        -DisplayName       'Incomplete Access Review' `
                        -UserPrincipalName '' `
                        -Evidence          "Access review instance has status '$($inst.Status)' — review is not yet complete. Pending reviewer action required." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions/{id}/instances' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions/{id}/instances' `
                        -RecommendedAction 'Follow up with reviewers to complete pending access review decisions.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'Incomplete review instance — reviewer action required'))
                }
            }
        }
        foreach ($dec in $arDecisions) {
            $decDecision = if ($dec.Decision) { $dec.Decision.ToLower() } else { '' }
            if ($decDecision -in @('notreviewed','')) {
                $instId   = if ($dec.AccessReviewInstanceId) { $dec.AccessReviewInstanceId } else { 'unknown' }
                $defId    = if ($dec.AccessReviewScheduleDefinitionId) { $dec.AccessReviewScheduleDefinitionId } else { 'unknown' }
                $rev003DecKey = "DEC-REV-003|dec|$defId|$instId"
                if ($emittedRev23.Add($rev003DecKey)) {
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-003' `
                        -Category          'Access Review Governance' `
                        -Severity          'Medium' `
                        -RiskScore         50 `
                        -Confidence        'Medium' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          $defId `
                        -DisplayName       'Pending Review Decision' `
                        -UserPrincipalName '' `
                        -Evidence          "Access review decision has not been completed (Decision: '$($dec.Decision)') — reviewer action required." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions/{id}/instances/{id}/decisions' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions/{id}/instances/{id}/decisions' `
                        -RecommendedAction 'Follow up with reviewer to complete the pending access review decision.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'NotReviewed decision — reviewer has not acted'))
                }
            }
        }

        # DEC-REV-004: Definitions where scope can't correlate to any finding ObjectId
        $findingObjectIds = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($f in $findings) {
            if ($f.ObjectId -and $f.ObjectId -ne 'tenant-scope' -and $f.ObjectId -ne 'contoso.onmicrosoft.com') {
                [void]$findingObjectIds.Add($f.ObjectId)
            }
        }
        foreach ($def in $arDefinitions) {
            $defId = if ($def.Id) { $def.Id } else { 'unknown' }
            $scopeId   = ''
            $scopeType = ''
            try {
                if ($def.Scope -and $def.Scope.Query)     { $scopeId = $def.Scope.Query }
                if ($def.Scope -and $def.Scope.QueryType) { $scopeType = $def.Scope.QueryType }
            } catch { $scopeId = '' }

            $correlated = $false
            if ($scopeId) {
                foreach ($oid in $findingObjectIds) {
                    if ($scopeId.Contains($oid)) { $correlated = $true; break }
                }
            }
            if (-not $correlated) {
                $rev004Key = "DEC-REV-004|$defId"
                if ($emittedRev23.Add($rev004Key)) {
                    $defName = if ($def.DisplayName) { $def.DisplayName } else { $defId }
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-REV-004' `
                        -Category          'Access Review Governance' `
                        -Severity          'Medium' `
                        -RiskScore         46 `
                        -Confidence        'Low' `
                        -ObjectType        'TenantScope' `
                        -ObjectId          $defId `
                        -DisplayName       $defName `
                        -UserPrincipalName '' `
                        -Evidence          "Access review definition '$defName' scope could not be correlated to any detected finding — scope mapping is unclear." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                        -RecommendedAction 'Review scope configuration for this access review definition to ensure it covers relevant identities.' `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'Low-confidence scope correlation — review definition may cover undetected scope'))
                }
            }
        }

        # DEC-REV-005: Decisions with Deny/NotApproved where principal still has residual access
        $findingPrincipalIds = [System.Collections.Generic.HashSet[string]]::new()
        foreach ($f in $findings) {
            if ($f.ObjectId -and $f.ObjectId -ne 'tenant-scope' -and $f.ObjectId -ne 'contoso.onmicrosoft.com') {
                [void]$findingPrincipalIds.Add($f.ObjectId)
            }
        }
        foreach ($dec in $arDecisions) {
            $decDecision = if ($dec.Decision) { $dec.Decision.ToLower() } else { '' }
            if ($decDecision -in @('deny','notapproved','remove')) {
                $principalId = if ($dec.Principal -and $dec.Principal.Id) { $dec.Principal.Id } else { '' }
                if ($principalId -and $findingPrincipalIds.Contains($principalId)) {
                    $rev005Key = "DEC-REV-005|$principalId"
                    if ($emittedRev23.Add($rev005Key)) {
                        $principalName = if ($dec.Principal -and $dec.Principal.DisplayName) { $dec.Principal.DisplayName } else { $principalId }
                        $findings.Add((New-DecomFinding `
                            -FindingId         'DEC-REV-005' `
                            -Category          'Access Review Governance' `
                            -Severity          'High' `
                            -RiskScore         67 `
                            -Confidence        'High' `
                            -ObjectType        'User' `
                            -ObjectId          $principalId `
                            -DisplayName       $principalName `
                            -UserPrincipalName '' `
                            -Evidence          "Access review decision '$($dec.Decision)' recorded for $principalName but residual access findings still detected — review action may not have been enforced." `
                            -EvidenceSource    'identityGovernance/accessReviews/definitions/{id}/instances/{id}/decisions' `
                            -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions/{id}/instances/{id}/decisions' `
                            -RecommendedAction "Enforce review decision for $principalName — verify access has been removed as directed by reviewer." `
                            -RemediationMode   'InformationOnly' `
                            -ConsultantNote    'Review decision conflict — deny/remove recorded but residual access still detected'))
                    }
                }
            }
        }
    }

    # --- Rev2.3 M3: Guest review correlation ---
    $guestFindings = @($findings | Where-Object { $_.FindingId -in @('DEC-GUEST-001','DEC-GUEST-002','DEC-GUEST-003') })
    if ($guestFindings.Count -gt 0) { $coverage.GuestReviewCorrelation = $true }

    # Build PIM-002 principal lookup for privileged guest detection
    $pim002PrincipalIds = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($f in $findings) {
        if ($f.FindingId -eq 'DEC-PIM-002' -and $f.ObjectId) {
            [void]$pim002PrincipalIds.Add($f.ObjectId)
        }
    }

    foreach ($gf in $guestFindings) {
        $guestId = $gf.ObjectId
        if (-not $guestId) { continue }

        $isPrivileged    = $false
        $lacksSponsorship = $false

        if ($gf.FindingId -eq 'DEC-GUEST-002') {
            $isPrivileged     = $true
            $lacksSponsorship = $true
        } elseif ($gf.FindingId -eq 'DEC-GUEST-003') {
            $lacksSponsorship = $true
            if ($pim002PrincipalIds.Contains($guestId)) { $isPrivileged = $true }
        } elseif ($gf.FindingId -eq 'DEC-GUEST-001') {
            if ($pim002PrincipalIds.Contains($guestId)) { $isPrivileged = $true }
            if ($gf.Evidence -match 'Administrator|privileged|Global|role') { $isPrivileged = $true }
        }

        # Try to correlate review decision for this guest
        $reviewResult = [PSCustomObject]@{
            Found           = $false
            Confidence      = 'Low'
            ReviewId        = ''
            ReviewName      = ''
            LastDecisionUtc = $null
            Status          = ''
            DecisionSummary = ''
            Evidence        = ''
        }

        if ($null -ne $accessReviewData) {
            foreach ($dec in $arDecisions) {
                $decPrincipalId = if ($dec.Principal -and $dec.Principal.Id) { $dec.Principal.Id } else { '' }
                if ($decPrincipalId -eq $guestId) {
                    $reviewResult.Found = $true
                    $reviewResult.DecisionSummary = if ($dec.Decision) { $dec.Decision } else { 'Unknown' }
                    try {
                        if ($dec.ReviewedDateTime) {
                            $reviewResult.LastDecisionUtc = [datetime]$dec.ReviewedDateTime
                        }
                    } catch { }
                    break
                }
            }
        }

        # Check if review decision is recent (within 90 days)
        $guestReviewThreshold90 = (Get-Date).AddDays(-90)
        $hasRecentGuestReview = $false
        if ($reviewResult.Found -and $null -ne $reviewResult.LastDecisionUtc) {
            $hasRecentGuestReview = ($reviewResult.LastDecisionUtc -ge $guestReviewThreshold90)
        }

        $grevKey = ''
        if ($isPrivileged -and -not $hasRecentGuestReview) {
            $grevKey = "DEC-GREV-003|$guestId"
            if ($emittedRev23.Add($grevKey)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GREV-003' `
                    -Category          'Guest Lifecycle' `
                    -Severity          'High' `
                    -RiskScore         72 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $guestId `
                    -DisplayName       $gf.DisplayName `
                    -UserPrincipalName $gf.UserPrincipalName `
                    -Evidence          'Guest holds privileged access (PIM eligible or directory role) and no access review decision found — privileged external access is ungoverned.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Immediately create access review for privileged guest $($gf.UserPrincipalName); escalate to security team." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Privileged guest without review evidence — highest risk GREV category'))
            }
        } elseif ($lacksSponsorship -and -not $hasRecentGuestReview) {
            $grevKey = "DEC-GREV-002|$guestId"
            if ($emittedRev23.Add($grevKey)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GREV-002' `
                    -Category          'Guest Lifecycle' `
                    -Severity          'High' `
                    -RiskScore         63 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $guestId `
                    -DisplayName       $gf.DisplayName `
                    -UserPrincipalName $gf.UserPrincipalName `
                    -Evidence          'Guest account lacks sponsor metadata and no access review decision found — business justification cannot be confirmed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Assign a sponsor to $($gf.UserPrincipalName) and create access review; consider offboarding if no sponsor can be identified." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Unsponsored guest without review evidence — elevated governance risk'))
            }
        } elseif (-not $hasRecentGuestReview) {
            $grevKey = "DEC-GREV-001|$guestId"
            if ($emittedRev23.Add($grevKey)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-GREV-001' `
                    -Category          'Guest Lifecycle' `
                    -Severity          'Medium' `
                    -RiskScore         48 `
                    -Confidence        'Low' `
                    -ObjectType        'User' `
                    -ObjectId          $guestId `
                    -DisplayName       $gf.DisplayName `
                    -UserPrincipalName $gf.UserPrincipalName `
                    -Evidence          'Guest account has no access review decision found within the last 90 days — review coverage cannot be confirmed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Schedule or confirm access review for guest $($gf.UserPrincipalName) and ensure decision is recorded." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Guest access review coverage gap — no decision evidence within threshold'))
            }
        }
    }

    # --- Rev2.3 M4: PIM review correlation ---
    $pimFindings = @($findings | Where-Object { $_.FindingId -in @('DEC-PIM-001','DEC-PIM-002','DEC-PIM-004') })
    if ($pimFindings.Count -gt 0) { $coverage.PimReviewCorrelation = $true }

    $pimReviewThreshold180 = (Get-Date).AddDays(-180)

    foreach ($pf in $pimFindings) {
        $principalId = $pf.ObjectId
        if (-not $principalId -or $principalId -eq 'tenant-scope') { continue }

        # Safe variable guard for eligibleAssignments
        $eligVarCheck   = Get-Variable 'eligibleAssignments' -ErrorAction SilentlyContinue
        $safeEligible   = if ($null -ne $eligVarCheck -and $null -ne $eligVarCheck.Value) { @($eligVarCheck.Value) } else { @() }

        $roleDefId = ''
        $matchAssignment = $safeEligible | Where-Object { $_.PrincipalId -eq $principalId } | Select-Object -First 1
        if ($matchAssignment -and $matchAssignment.RoleDefinitionId) {
            $roleDefId = $matchAssignment.RoleDefinitionId
        }

        $dedupSuffix = if ($roleDefId) { "$principalId|$roleDefId" } else { $principalId }

        # Try to find review decision for this principal
        $pimReviewFound    = $false
        $pimLastDecision   = $null
        if ($null -ne $accessReviewData) {
            foreach ($dec in $arDecisions) {
                $decPrincipalId = if ($dec.Principal -and $dec.Principal.Id) { $dec.Principal.Id } else { '' }
                if ($decPrincipalId -eq $principalId) {
                    $pimReviewFound = $true
                    try {
                        if ($dec.ReviewedDateTime) { $pimLastDecision = [datetime]$dec.ReviewedDateTime }
                    } catch { }
                    break
                }
            }
        }

        if ($null -eq $accessReviewData) {
            # DEC-PIM-007: emit once — no AR data at all
            $pim007Key = 'DEC-PIM-007|tenant-scope'
            if ($emittedRev23.Add($pim007Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-PIM-007' `
                    -Category          'Privileged Access' `
                    -Severity          'Informational' `
                    -RiskScore         22 `
                    -Confidence        'Low' `
                    -ObjectType        'TenantScope' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'PIM Review Correlation' `
                    -UserPrincipalName '' `
                    -Evidence          'PIM eligible assignment findings detected but access review data unavailable — review correlation could not be performed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction 'Grant AccessReview.Read.All permission and re-run assessment to enable PIM review correlation.' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'PIM review correlation skipped — no AR data available'))
            }
        } elseif ($pimReviewFound -and $null -ne $pimLastDecision -and $pimLastDecision -lt $pimReviewThreshold180) {
            # DEC-PIM-006: review found but older than 180 days
            $pim006Key = "DEC-PIM-006|$dedupSuffix"
            if ($emittedRev23.Add($pim006Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-PIM-006' `
                    -Category          'Privileged Access' `
                    -Severity          'High' `
                    -RiskScore         73 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $principalId `
                    -DisplayName       $pf.DisplayName `
                    -UserPrincipalName $pf.UserPrincipalName `
                    -Evidence          "PIM eligible privileged role assignment last reviewed $($pimLastDecision.ToString('yyyy-MM-dd')) — more than 180 days ago. Review has lapsed." `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Initiate new access review for PIM eligible assignment for $($pf.UserPrincipalName)." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Stale PIM review — last decision beyond 180-day threshold'))
            }
        } elseif (-not $pimReviewFound) {
            # DEC-PIM-005: no review evidence found
            $pim005Key = "DEC-PIM-005|$dedupSuffix"
            if ($emittedRev23.Add($pim005Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-PIM-005' `
                    -Category          'Privileged Access' `
                    -Severity          'High' `
                    -RiskScore         70 `
                    -Confidence        'Low' `
                    -ObjectType        'User' `
                    -ObjectId          $principalId `
                    -DisplayName       $pf.DisplayName `
                    -UserPrincipalName $pf.UserPrincipalName `
                    -Evidence          'PIM eligible privileged role assignment found but no access review decision evidence detected — governance review cannot be confirmed.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Create access review for PIM eligible assignment for $($pf.UserPrincipalName) and confirm review completion." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'PIM eligible assignment without review evidence — governance gap'))
            }
        }
    }

    # --- Rev2.3 M5: Access package review correlation ---
    $apFindings = @($findings | Where-Object {
        $_.FindingId -in @('DEC-AP-001','DEC-AP-002','DEC-AP-003','DEC-AP-004','DEC-AP-005') -and
        $_.ObjectId -ne 'tenant-scope' -and $_.ObjectId -ne 'contoso.onmicrosoft.com'
    })
    if ($apFindings.Count -gt 0) { $coverage.AccessPackageReviewCorrelation = $true }

    # DEC-AP-006: emit once if no AR definition correlated to entitlement management
    if ($apFindings.Count -gt 0) {
        $emDefForAP = $false
        foreach ($def in $arDefinitions) {
            $scopeQuery = ''
            try { if ($def.Scope -and $def.Scope.Query) { $scopeQuery = $def.Scope.Query } } catch { }
            if ($scopeQuery -match 'entitlementManagement|accessPackage') {
                $emDefForAP = $true
                break
            }
        }
        if (-not $emDefForAP) {
            $ap006Key = 'DEC-AP-006|tenant-scope'
            if ($emittedRev23.Add($ap006Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-AP-006' `
                    -Category          'Governance' `
                    -Severity          'Medium' `
                    -RiskScore         50 `
                    -Confidence        'Low' `
                    -ObjectType        'TenantScope' `
                    -ObjectId          'tenant-scope' `
                    -DisplayName       'Access Package Review Coverage' `
                    -UserPrincipalName '' `
                    -Evidence          'Access package assignment findings found but no access review definition correlated to entitlement management scope.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction 'Create access review definitions scoped to entitlement management access packages.' `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'No AR definition found for entitlement management — coverage gap'))
            }
        }
    }

    # Per-principal AP review correlation: DEC-AP-008 (incomplete) > DEC-AP-007 (stale/unavailable)
    $apReviewThreshold180 = (Get-Date).AddDays(-180)
    foreach ($apf in $apFindings) {
        $apPrincipalId = $apf.ObjectId
        if (-not $apPrincipalId) { continue }

        $apDecisionFound    = $false
        $apDecisionComplete = $false
        $apLastDecision     = $null
        if ($null -ne $accessReviewData) {
            foreach ($dec in $arDecisions) {
                $decPrincipalId = if ($dec.Principal -and $dec.Principal.Id) { $dec.Principal.Id } else { '' }
                if ($decPrincipalId -eq $apPrincipalId) {
                    $apDecisionFound = $true
                    $decVal = if ($dec.Decision) { $dec.Decision.ToLower() } else { '' }
                    if ($decVal -notin @('notreviewed','')) { $apDecisionComplete = $true }
                    try {
                        if ($dec.ReviewedDateTime) { $apLastDecision = [datetime]$dec.ReviewedDateTime }
                    } catch { }
                    break
                }
            }
        }

        if ($apDecisionFound -and -not $apDecisionComplete) {
            # DEC-AP-008: incomplete decision
            $ap008Key = "DEC-AP-008|$apPrincipalId"
            if ($emittedRev23.Add($ap008Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-AP-008' `
                    -Category          'Governance' `
                    -Severity          'High' `
                    -RiskScore         66 `
                    -Confidence        'Medium' `
                    -ObjectType        'User' `
                    -ObjectId          $apPrincipalId `
                    -DisplayName       $apf.DisplayName `
                    -UserPrincipalName $apf.UserPrincipalName `
                    -Evidence          'Access package assignment review decision is incomplete or not reviewed — reviewer action required.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Follow up with reviewer to complete access review decision for $($apf.UserPrincipalName)." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Pending review decision requires reviewer action'))
            }
        } elseif (-not $apDecisionFound -or ($null -ne $apLastDecision -and $apLastDecision -lt $apReviewThreshold180)) {
            # DEC-AP-007: stale or unavailable
            $ap007Key = "DEC-AP-007|$apPrincipalId"
            if ($emittedRev23.Add($ap007Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-AP-007' `
                    -Category          'Governance' `
                    -Severity          'Medium' `
                    -RiskScore         54 `
                    -Confidence        'Low' `
                    -ObjectType        'User' `
                    -ObjectId          $apPrincipalId `
                    -DisplayName       $apf.DisplayName `
                    -UserPrincipalName $apf.UserPrincipalName `
                    -Evidence          'Access package assignment has no review decision within 180 days — review evidence stale or unavailable.' `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Initiate access review for access package assignment for $($apf.UserPrincipalName)." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'Stale or missing review decision for access package assignment'))
            }
        }
    }

    # --- Rev2.3 M6: CA exclusion review correlation ---
    $caFindings = @($findings | Where-Object { $_.FindingId -in @('DEC-CA-001','DEC-CA-002') })
    if ($caFindings.Count -gt 0) { $coverage.CAExclusionReviewCorrelation = $true }

    $caGroupFindings = @($caFindings | Where-Object { $_.FindingId -eq 'DEC-CA-002' -and $_.ObjectType -eq 'Group' })
    $caStaleThreshold90 = (Get-Date).AddDays(-90)

    foreach ($caf in $caGroupFindings) {
        $caGroupId   = $caf.ObjectId
        $caGroupName = $caf.DisplayName
        if (-not $caGroupId) { continue }

        # Check if any AR definition scope references this group ID or name
        $matchedDef = $null
        foreach ($def in $arDefinitions) {
            $scopeQuery = ''
            try { if ($def.Scope -and $def.Scope.Query) { $scopeQuery = $def.Scope.Query } } catch { }
            if ($scopeQuery.Contains($caGroupId)) {
                $matchedDef = $def
                break
            }
            # Name match fallback
            if ($caGroupName -and $def.DisplayName -and $def.DisplayName -match [regex]::Escape($caGroupName)) {
                $matchedDef = $def
                break
            }
        }

        if ($null -eq $matchedDef) {
            # No match — DEC-CA-003
            $ca003Key = "DEC-CA-003|$caGroupId"
            if ($emittedRev23.Add($ca003Key)) {
                $findings.Add((New-DecomFinding `
                    -FindingId         'DEC-CA-003' `
                    -Category          'Conditional Access' `
                    -Severity          'High' `
                    -RiskScore         68 `
                    -Confidence        'Low' `
                    -ObjectType        'Group' `
                    -ObjectId          $caGroupId `
                    -DisplayName       $caGroupName `
                    -UserPrincipalName '' `
                    -Evidence          "CA policy exclusion group '$caGroupName' has no correlated access review definition — members excluded without review governance." `
                    -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                    -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                    -RecommendedAction "Create access review definition scoped to '$caGroupName' group to govern CA exclusion membership." `
                    -RemediationMode   'InformationOnly' `
                    -ConsultantNote    'CA exclusion group without review governance — attack surface is ungoverned'))
            }
        } else {
            # Matched definition — check if instances are all stale (>90 days)
            $matchedDefId = $matchedDef.Id
            $defInstances = @($arInstances | Where-Object {
                $_.AccessReviewScheduleDefinitionId -eq $matchedDefId
            })
            $hasRecentInstance = $false
            foreach ($inst in $defInstances) {
                $instEnd = $null
                try { if ($inst.EndDateTime) { $instEnd = [datetime]$inst.EndDateTime } } catch { }
                if ($null -ne $instEnd -and $instEnd -ge $caStaleThreshold90) {
                    $hasRecentInstance = $true
                    break
                }
            }
            if (-not $hasRecentInstance -and $defInstances.Count -gt 0) {
                # All instances older than 90 days — DEC-CA-004
                $ca004Key = "DEC-CA-004|$caGroupId"
                if ($emittedRev23.Add($ca004Key)) {
                    $lastInstEnd = $null
                    foreach ($inst in $defInstances) {
                        try {
                            if ($inst.EndDateTime) {
                                $ie = [datetime]$inst.EndDateTime
                                if ($null -eq $lastInstEnd -or $ie -gt $lastInstEnd) { $lastInstEnd = $ie }
                            }
                        } catch { }
                    }
                    $lastStr = if ($null -ne $lastInstEnd) { $lastInstEnd.ToString('yyyy-MM-dd') } else { 'unknown' }
                    $findings.Add((New-DecomFinding `
                        -FindingId         'DEC-CA-004' `
                        -Category          'Conditional Access' `
                        -Severity          'High' `
                        -RiskScore         70 `
                        -Confidence        'Low' `
                        -ObjectType        'Group' `
                        -ObjectId          $caGroupId `
                        -DisplayName       $caGroupName `
                        -UserPrincipalName '' `
                        -Evidence          "CA policy exclusion group '$caGroupName' last reviewed $lastStr — more than 90 days ago. Review has lapsed for CA exclusion governance." `
                        -EvidenceSource    'identityGovernance/accessReviews/definitions' `
                        -GraphEndpoint     '/v1.0/identityGovernance/accessReviews/definitions' `
                        -RecommendedAction "Initiate new access review for '$caGroupName' to re-validate CA exclusion membership." `
                        -RemediationMode   'InformationOnly' `
                        -ConsultantNote    'Stale CA exclusion review — last decision beyond 90-day threshold'))
                }
            }
        }
    }

    # =========================================================================
    # End of Rev2.3 sections
    # =========================================================================

    if ($Context) { $Context | Add-Member -NotePropertyName Coverage -NotePropertyValue $coverage -Force }
    [object[]]$result = @($findings)
    Write-Output -NoEnumerate $result
}
