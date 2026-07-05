# Rev4.46 Lab Readiness Evidence

Rev4.46 adds an evidence-only readiness layer for the known lab target:

- TenantId: `3177c971-05c9-4b7b-93a1-0edf6fd7237d`
- TargetObjectId: `7b972582-4b35-4fd4-b4c9-1ef2dd3a0c8b`
- TargetDisplayName: `AJEE-LAB-NHI-DISABLE-ROLLBACK`
- AppId: `48deb98d-78c4-49b0-8c56-eed1bb5732c0`

## Purpose

The goal of Rev4.46 is to let an operator record explicit, auditable human readiness evidence for a known lab target that is still blocked by Rev4.41 planning because it is ownerless and has unknown observed activity.

Rev4.46 is intentionally evidence-only:

- It does not connect to Microsoft Graph for mutation.
- It does not mutate the tenant.
- It does not bypass Rev4.41, Rev4.42, Rev4.43, or Rev4.44.
- It does not auto-mark ownerless or unknown-activity objects as safe.
- It does not authorize a future Execute path by itself.

## Required Inputs

The tool accepts:

- `TenantId`
- `TargetObjectId`
- `TargetDisplayName`
- `AppId`
- `OutputRoot`
- `EvidenceMode`
- `OwnerEvidence`
- `ActivityEvidence`
- `RiskAcceptance`
- `ApprovedBy`
- `ApprovalPhrase`
- `ExpiresUtc`
- optional `AllowListPath`

## Required Phrase

The approval phrase must match exactly:

`APPROVE REV4.46 LAB READINESS EVIDENCE ONLY`

## Evidence Expectations

### Owner evidence

Owner evidence must explain why `OwnerStatus = NoOwners` is acceptable for this lab target.
It must include:

- a human-readable owner, approver, or team name
- a rationale
- a timestamp

### Activity evidence

Activity evidence must explain why `LastObservedActivity = Unknown` is acceptable for this lab target.
It must include:

- a rationale
- a timestamp

### Risk acceptance

Risk acceptance must explicitly be lab-only.
It must not approve:

- production use
- final delete
- cleanup
- broad batch execution

It must also expire.

## Outputs

Rev4.46 writes only local artifacts:

- `rev446-lab-readiness-evidence.json`
- `rev446-lab-readiness-summary.json`
- `rev446-operator-runbook.md`

## Future Use

Rev4.46 is meant to prepare the lab for a future separately approved one-object Execute test.
That future test must be approved independently and should continue to obey the existing safety gates.
