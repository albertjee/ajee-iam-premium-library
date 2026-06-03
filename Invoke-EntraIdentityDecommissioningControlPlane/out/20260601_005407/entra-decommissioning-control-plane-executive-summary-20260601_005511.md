# Executive Summary — Entra Identity Decommissioning Control Plane

## Engagement Context

| Field | Value |
|-------|-------|
| Client | Newport High PTSA |
| Engagement ID | ENG-002 |
| Assessor | Albert Jee |
| Tenant ID | NewportHighPTSA.onmicrosoft.com |
| Generated | 2026-06-01T07:55:11.9053417Z |
| Tool Version | Rev2.5 |

## Executive Risk Posture

**ELEVATED**

The tenant has elevated identity governance risk with several high-severity findings. Governance coverage gaps and unreviewed privileged assignments require prioritized attention.

## Key Findings

The assessment identified 40 total findings: 0 Critical, 12 High, 26 Medium. These findings span user lifecycle management, guest identity governance, privileged access, and access review coverage. Findings are prioritized by risk score and remediation impact.

## Top 10 Risks

| # | Finding ID | Severity | Risk Score | Description |
|---|-----------|----------|------------|-------------|
| 1 | DEC-CA-003 | High | 68 | CA policy exclusion group 'Exclude from CA' has no correlated access review d... |
| 2 | DEC-APP-005 | High | 68 | Client secret 'albert demo secret' expired 1272 days ago (2022-12-07) — still... |
| 3 | DEC-GOV-001 | Informational | 18 | Access review API cmdlets unavailable — review governance coverage could not ... |
| 4 | DEC-CA-001 | High | 65 | CA policy excludes 1 user(s) and 0 group(s) from policy scope |
| 5 | DEC-CA-001 | High | 65 | CA policy excludes 1 user(s) and 0 group(s) from policy scope |
| 6 | DEC-CA-001 | High | 65 | CA policy excludes 0 user(s) and 1 group(s) from policy scope |
| 7 | DEC-CA-001 | High | 65 | CA policy excludes 2 user(s) and 0 group(s) from policy scope |
| 8 | DEC-CA-001 | High | 65 | CA policy excludes 2 user(s) and 1 group(s) from policy scope |
| 9 | DEC-CA-001 | High | 65 | CA policy excludes 1 user(s) and 1 group(s) from policy scope |
| 10 | DEC-CA-001 | High | 65 | CA policy excludes 2 user(s) and 0 group(s) from policy scope |


## Governance Evidence Coverage

| Coverage Area | Status |
|--------------|--------|
| EntitlementManagement | Partial/Unavailable |
| Applications | Full |
| AccessReviewInstances | Partial/Unavailable |
| AuditLogs | Full |
| GuestReviewCorrelation | Partial/Unavailable |
| Users | Full |
| AccessReviews | Partial/Unavailable |
| Groups | Full |
| AccessPackageReviewCorrelation | Partial/Unavailable |
| GovernanceEvidenceLimitations | Unknown |
| PimActivationEvidence | Partial/Unavailable |
| PimEligibleAssignments | Partial/Unavailable |
| EntitlementAssignments | Partial/Unavailable |
| SignInLogs | Full |
| DirectoryRoles | Full |
| ConditionalAccess | Full |
| AccessPackagePolicies | Partial/Unavailable |
| ServicePrincipals | Full |
| PimReviewCorrelation | Partial/Unavailable |
| AccessReviewDefinitions | Partial/Unavailable |
| AccessReviewScheduleEvidence | Partial/Unavailable |
| AccessReviewDecisions | Partial/Unavailable |
| CAExclusionReviewCorrelation | Full |


## Baseline Movement

No baseline provided. Trend comparison not available for this run.


## Recommended Next Actions

- 1. Close critical disabled-user and privileged-role residue first.
- 2. Review guest privileged access and sponsor ownership.
- 3. Validate access review coverage for CA exclusion groups.
- 4. Establish review cadence for PIM eligible assignments.
- 5. Confirm access package review schedules and expiration policy.
- 6. Re-run assessment after remediation to prove risk reduction.

## Consultant Notes and Limitations

- Assessment performed in read-only mode. No tenant modifications were made.
- Coverage may be partial depending on Graph permissions and license availability.
- Access review correlation requires AccessReview.Read.All permission.
- PIM data requires PrivilegedAccess.Read.AzureAD or equivalent.

---

*© 2026 Albert Jee. All rights reserved.*
