# Consultant Runbook — Entra Identity Decommissioning Control Plane

## Pre-Engagement

- Confirm tenant scope and read-only permissions
- Confirm whether sign-in/audit logs are available
- Confirm whether guest and app ownership analysis is in scope
- Confirm whether remediation planning is in scope

## Execution

1. Run assessment mode (no parameters required)
2. Validate coverage warnings in console output
3. Review critical and high findings
4. Export CSV, JSON, HTML, and Markdown outputs
5. Review exceptions with client

## Client Workshop

- Start with executive scorecard (HTML report)
- Explain residual access risk by category
- Review critical findings
- Separate true risks from approved exceptions
- Agree on remediation ownership and timeline

## Post-Workshop

- Update remediation plan with approvals
- Mark findings as Approved / Rejected / Deferred
- Prepare optional controlled ExecuteRemediation phase for Rev2.0

## Known Limitations

- Assessment mode reads only — no changes to tenant
- Sign-in log analysis requires AuditLog.Read.All scope
- IGA coverage requires EntitlementManagement.Read.All scope
- Rev1.1 does not support hybrid or on-premises AD DS environments
