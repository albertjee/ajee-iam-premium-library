# Release Validation Report

**SchemaVersion:** 3.0
**ToolVersion:** Rev3.1
**GeneratedUtc:** 2026-06-01T19:05:05.3665526Z
**Result:** FAIL

## Checks

| Check | Result |
|---|---|
| Version Consistent | False |
| Safety Invariants OK | False |
| No Unexpected Write Scope | True |
| No Unexpected Write Cmdlet | True |
## Errors
- Entry point does not declare ToolVersion = Rev3.0
- Remediation.psm1 contains unexpected write action: RemoveAccessPackageAssignment
- Remediation.psm1 contains unexpected write action: RemovePimEligibleAssignment

---
© 2026 Albert Jee. All rights reserved.
