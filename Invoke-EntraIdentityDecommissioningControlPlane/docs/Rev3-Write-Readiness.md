# Rev3.x Write-Readiness

**SchemaVersion:** 3.2  
**Rev:** 3.2

---

## Current Status: Rev3.2 Implemented and QA-Certified

Rev3.2 adds `RemoveExpiredApplicationCredential` as a controlled write action for DEC-APP-005. The write-readiness arc from Rev2.5 → Rev3.0 → Rev3.1 → Rev3.2 is now complete.

### Rev3.2 Write Expansion

| FindingId | ActionType | Write Scope | Status |
|---|---|---|---|
| DEC-APP-005 | `RemoveExpiredApplicationCredential` | `Application.ReadWrite.All` | **Implemented — Rev3.2** |

Safety constraints: exact KeyId required, credential must be expired, ProtectedObject blocks unconditionally, CredentialType mismatch blocks, null EndDateTime blocks, application read failure blocks.

### Prior Rev Status: ReadyForRev3Design (Rev2.5)

Rev2.5 established the formal write-readiness assessment. At that point, recommendation was **ReadyForRev3Design**:
- Rev2.x safety architecture sufficiently mature
- Four Rev2.0 executable actions stable
- Three-gate controlled remediation model proven

---

## Rev2.0 Executable Scope (Unchanged in Rev2.5)

| FindingId | Action | Write Scope |
|---|---|---|
| DEC-USER-001 | Remove guest group membership | GroupMember.ReadWrite.All |
| DEC-USER-002 | Remove group membership (non-guest) | GroupMember.ReadWrite.All |
| DEC-USER-003 | Remove group membership (disabled user) | GroupMember.ReadWrite.All |
| DEC-ROLE-001 | Remove directory role assignment | RoleManagement.ReadWrite.Directory |

No other write actions exist in this tool.

---

## Rev3.0 Write Candidates

The following actions have been identified as candidates for Rev3.0 design consideration. None are implemented.

### NeedsDesign (feasible, design required)

| FindingId | Proposed Action | Proposed Scope | Risk Level |
|---|---|---|---|
| DEC-AP-001 | RemoveAccessPackageAssignment | EntitlementManagement.ReadWrite.All | Medium |
| DEC-PIM-001 | RemovePimEligibleAssignment | PrivilegedAccess.ReadWrite.All | High |
| DEC-GUEST-002 | RemoveGuestGroupMembership | GroupMember.ReadWrite.All | Medium |
| DEC-ROLE-001 | RemovePimActiveAssignment | PrivilegedAccess.ReadWrite.All | High |

### Deferred (feasible, architectural decision pending)

| FindingId | Proposed Action | Reason |
|---|---|---|
| DEC-CA-002 | AddApplicationOwner | Requires owner-addition safety pattern |
| DEC-CA-003 | RemoveCAExclusionGroupMember | CA policy impact analysis needed |

### Unsafe (additional safety research required)

| FindingId | Proposed Action | Why Unsafe |
|---|---|---|
| DEC-APP-001 | DeleteOrDisableApp | Irreversible; no pre-flight verification for dependent services |
| DEC-SPN-001 | DeleteServicePrincipal | Irreversible; tenant-wide service disruption risk without dependency check |

`Unsafe` candidates will remain `Unsafe` until a pre-flight dependency verification framework is designed and validated.

---

## What Rev3.0 Design Must Address

Before implementing any new write action:

1. **Rollback design** — every write action must have a documented, tested rollback procedure
2. **Pre-flight checks** — verify target object state before writing; abort if unexpected state detected
3. **Post-write evidence** — capture evidence that the write succeeded and matches intent
4. **Approval scope** — approval manifest must explicitly enumerate the FindingId being acted on
5. **Expanded safety scan** — `Test-DecomSafetyInvariant` must be updated to allow the new scope in the executing module only

---

## Decision Timeline

Rev3.0 write expansion is not scheduled. This document tracks the readiness assessment as of Rev2.5. A Rev3.0 design gate must be passed before any implementation begins.

---

© 2026 Albert Jee. All rights reserved.
