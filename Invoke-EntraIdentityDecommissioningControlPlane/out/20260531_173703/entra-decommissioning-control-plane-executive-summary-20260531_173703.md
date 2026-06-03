# Executive Summary — Entra Identity Decommissioning Control Plane

## Engagement Context

| Field | Value |
|-------|-------|
| Client | Unknown |
| Engagement ID |  |
| Assessor |  |
| Tenant ID | contoso.onmicrosoft.com |
| Generated | 2026-06-01T00:37:03.7831628Z |
| Tool Version | Rev2.4 |

## Executive Risk Posture

**CRITICAL**

The tenant exhibits critical identity governance gaps requiring immediate remediation. Multiple high-severity findings indicate significant exposure across privileged access, guest lifecycle, and access review governance.

## Key Findings

The assessment identified 38 total findings: 6 Critical, 14 High, 12 Medium. These findings span user lifecycle management, guest identity governance, privileged access, and access review coverage. Findings are prioritized by risk score and remediation impact.

## Top 10 Risks

| # | Finding ID | Severity | Risk Score | Description |
|---|-----------|----------|------------|-------------|
| 1 | DEC-USER-003 | Critical | 92 | Disabled user retains Global Administrator role assignment |
| 2 | DEC-ROLE-001 | Critical | 90 | Disabled user holds active Privileged Role Administrator assignment — account... |
| 3 | DEC-APP-002 | Critical | 88 | Application owned exclusively by disabled user alex.mercer@contoso.com — no a... |
| 4 | DEC-GUEST-002 | Critical | 85 | Guest account holds User Administrator role — no sponsor metadata |
| 5 | DEC-CA-004 | High | 70 | CA policy exclusion group last reviewed 2025-08-01 — more than 90 days ago. R... |
| 6 | DEC-AP-001 | High | 70 | Disabled user retains access package assignment. Review Entitlement Managemen... |
| 7 | DEC-REV-001 | Informational | 20 | Access review definitions found but no review decision records returned — cov... |
| 8 | DEC-GOV-001 | Informational | 18 | Access review API cmdlets unavailable — review governance coverage could not ... |
| 9 | DEC-PIM-001 | Critical | 86 | Disabled user retains eligible privileged role assignment. Eligibility should... |
| 10 | DEC-PIM-002 | Critical | 84 | Guest identity retains eligible privileged role assignment. Review external p... |


## Governance Evidence Coverage

| Coverage Area | Status |
|--------------|--------|
| ConditionalAccess | Full |
| EntitlementAssignments | Full |
| DirectoryRoles | Full |
| GuestReviewCorrelation | Full |
| PimEligibleAssignments | Full |
| Users | Full |
| Groups | Full |
| AccessPackagePolicies | Partial/Unavailable |
| AccessReviews | Full |
| Applications | Full |
| AuditLogs | Partial/Unavailable |
| ServicePrincipals | Full |
| PimActivationEvidence | Partial/Unavailable |
| EntitlementManagement | Partial/Unavailable |
| AccessReviewInstances | Partial/Unavailable |
| SignInLogs | Partial/Unavailable |
| AccessReviewDecisions | Partial/Unavailable |
| GovernanceEvidenceLimitations | Unknown |
| AccessReviewScheduleEvidence | Partial/Unavailable |
| AccessReviewDefinitions | Full |
| CAExclusionReviewCorrelation | Full |
| AccessPackageReviewCorrelation | Full |
| PimReviewCorrelation | Full |


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
