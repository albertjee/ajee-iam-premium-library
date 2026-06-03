# Consultant Evidence Appendix — Entra Identity Decommissioning Control Plane

**Client:** Newport High PTSA
**Engagement ID:** ENG-002
**Assessor:** Albert Jee
**Generated:** 2026-06-01T08:37:41.3486196Z
**Tool Version:** Rev3.0
**Schema Version:** 2.4

---

## 1. Methodology

This assessment uses the Entra Identity Decommissioning Control Plane tool, which queries Microsoft Graph APIs to identify identity governance gaps across user lifecycle, guest lifecycle, privileged access, application ownership, Conditional Access, PIM, access reviews, and entitlement management. All data collection is read-only. No tenant modifications are performed during assessment mode.

## 2. Graph Permissions and Coverage

The following Graph permission scopes are required for full coverage:

- User.Read.All — User lifecycle and disabled account detection
- AuditLog.Read.All — Sign-in activity (optional, enhances detection)
- Directory.Read.All — Directory roles, groups, service principals
- Application.Read.All — Application registration and ownership
- Policy.Read.All — Conditional Access policy enumeration
- PrivilegedAccess.Read.AzureAD — PIM eligible assignments
- EntitlementManagement.Read.All — Access packages and assignments
- AccessReview.Read.All — Access review definitions, instances, decisions

Missing permissions result in partial coverage. Findings for unavailable areas are omitted, not fabricated.

## 3. Finding Schema

Each finding includes:
- **FindingId**: Unique detector identifier (e.g., DEC-USER-001)
- **Category**: Risk domain classification
- **Severity**: Critical / High / Medium / Low / Informational
- **RiskScore**: 0–100 numeric risk indicator
- **Confidence**: High / Medium / Low
- **ObjectType**: Type of affected object
- **ObjectId**: Entra object GUID
- **DisplayName**: Human-readable name
- **Evidence**: Specific evidence string
- **EvidenceSource**: Graph API endpoint or data source
- **RecommendedAction**: Remediation guidance

## 4. Coverage Limitations

- AuditLog.Read.All is optional. Without it, last sign-in data may be unavailable.
- PIM data requires PrivilegedAccess.Read.AzureAD or equivalent modern scope.
- Access review correlation requires AccessReview.Read.All.
- Entitlement Management requires EntitlementManagement.Read.All and an active Microsoft Entra ID Governance license.
- Guest review correlation uses review definition matching, not identity-level linking.
- Findings reflect point-in-time assessment state only.

## 5. Detector Families Included

| Prefix | Domain |
|--------|--------|
| DEC-USER | User Lifecycle |
| DEC-GUEST | Guest Lifecycle |
| DEC-GREV | Guest Review Governance |
| DEC-APP | Application Ownership |
| DEC-SP | Service Principal |
| DEC-CA | Conditional Access |
| DEC-PIM | Privileged Identity Management |
| DEC-ROLE | Directory Role Residue |
| DEC-REV | Access Review Governance |
| DEC-AP | Entitlement Management / Access Packages |

## 6. Access Review Correlation Limitations

Access review correlation links review definitions and instances to identity objects (guests, CA exclusion groups, access packages) using Entra review definition IDs. Limitations include:

- Instance-level matching depends on review scope configuration.
- Stale instance detection uses a 90-day threshold.
- Review decisions may reflect partial reviewer completion.
- Organizations without Entra ID Governance licensing may see limited review data.

## 7. Baseline Comparison Methodology

When a baseline findings JSON is provided via -BaselinePath, the tool:

1. Loads prior findings from the JSON export (SchemaVersion 2.3 or 2.4).
2. Generates a stable key per finding: FindingId|ObjectType|ObjectId|DisplayName.
3. Compares current findings against baseline using stable keys.
4. Classifies each finding as: New, Persisting, Resolved, ChangedSeverity, ChangedRiskScore, ChangedEvidence, or Unchanged.
5. Computes risk movement summary including NetRiskDelta.

Resolved findings (in baseline but not current run) may reflect true remediation or coverage gaps. Interpret in context of current coverage flags.

## 8. Safety Model Statement

Assessment, WhatIfRemediation, ExportPlan, and Rev2.4 executive pack generation are read-only operations. ExecuteRemediation remains governed by the existing Rev2.x three-gate safety model:

1. Gate 1: Approval manifest hash validation (HMAC-SHA256)
2. Gate 2: Preflight confirmation (interactive or -RequirePreflightConfirm flag)
3. Gate 3: Per-action revalidation before Graph write execution

Rev2.4 does not modify ExecuteRemediation behavior. No new write scopes or tenant-modifying Graph calls were added.

## 9. Export File Inventory

- **Html**: .\out\20260601_013629\entra-decommissioning-control-plane-report-20260601_013629.html
- **Json**: .\out\20260601_013629\entra-decommissioning-control-plane-findings-20260601_013629.json
- **RemediationPlan**: .\out\20260601_013629\entra-decommissioning-control-plane-remediation-plan-20260601_013629.md
- **Csv**: .\out\20260601_013629\entra-decommissioning-control-plane-assessment-20260601_013629.csv
- **Manifest**: .\out\20260601_013629\entra-decommissioning-control-plane-run-manifest-20260601_013629.json


## 10. Recommended Validation Steps

1. Verify findings against Entra admin center for critical and high severity items.
2. Confirm disabled user accounts flagged as having privileged roles or sign-in activity.
3. Validate guest accounts flagged for missing sponsors or stale review coverage.
4. Cross-reference PIM eligible assignments with privileged access policy.
5. Review CA exclusion groups for access review evidence before remediation.
6. Re-run assessment after remediation wave to confirm risk reduction.

---

*© 2026 Albert Jee. All rights reserved.*
