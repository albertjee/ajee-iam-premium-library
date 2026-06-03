# Release Validation Report

**SchemaVersion:** 3.0
**ToolVersion:** Rev3.2
**GeneratedUtc:** 2026-06-02T00:12:37.5165961Z
**Result:** FAIL

## Checks

| Check | Result |
|---|---|
| Version Consistent | False |
| Safety Invariants OK | False |
| No Unexpected Write Scope | True |
| No Unexpected Write Cmdlet | True |
## Errors
- Entry point does not declare ToolVersion = Rev3.1
- Provided ToolVersion 'Rev3.2' does not match expected Rev3.1
- Remediation.psm1 contains unexpected write action: RemoveAccessPackageAssignment
- Remediation.psm1 contains unexpected write action: RemovePimEligibleAssignment
- Remediation.psm1 contains unexpected write action: RemoveGuestGroupMembership
- Remediation.psm1 contains unexpected write action: RevokeGuestAppRoleAssignment

---
© 2026 Albert Jee. All rights reserved.
