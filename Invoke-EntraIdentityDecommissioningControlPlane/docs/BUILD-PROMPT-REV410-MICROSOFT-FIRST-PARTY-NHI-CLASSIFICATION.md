# Rev4.10 Build Prompt: Microsoft First-Party NHI Classification

## Objective
Implement Rev4.10 for `Invoke-EntraIdentityDecommissioningControlPlane` with a narrow focus on:

- Microsoft first-party and Microsoft platform NHI classification
- Remediation suppression for Microsoft platform identities
- Client handoff and redaction package repair
- Replay validation no-input semantics
- Version metadata consistency
- NHI export JSON depth fix

## Non-Goals

- Do not add or run any tenant write, delete, cleanup, rollback, or decommission behavior.
- Do not run `ExecuteNhiDecommission`, controlled decommission, grant cleanup, metadata cleanup, rollback, or `AllowFinalDelete`.
- Do not weaken safety, execution, rollback, approval, final-delete, WhatIf, or no-write guardrails.
- Do not push, merge, tag, or delete branches.
- Do not make broad refactors outside the Rev4.10 scope.

## Implementation Prompt

Make the following changes conservatively:

1. Add metadata-based Microsoft first-party and Microsoft platform classification before findings are emitted.
2. Preserve Microsoft platform identities as evidence-only, but suppress customer-actionable remediation for owner, publisher, agent, write-readiness, and decommission paths.
3. Keep fake, customer-owned, and third-party Microsoft-looking applications actionable unless the metadata-based Microsoft platform criteria are met.
4. Repair client handoff sections so generated artifacts are listed.
5. Repair redacted file handling so successful redaction marks client-safe outputs correctly.
6. Make replay validation return `SkippedNoReplayInputs` when no replay inputs are supplied, with `Passed = $null` and `CheckCount = 0`.
7. Centralize tool version metadata as `Rev4.10`.
8. Increase NHI/export JSON `ConvertTo-Json` depth to avoid truncation.
9. Add focused Pester coverage for all Rev4.10 behavior.

## Acceptance Checklist

- [ ] Microsoft first-party classification is metadata-based and conservative.
- [ ] Microsoft platform identities are detected before findings generation.
- [ ] Microsoft platform identities are emitted as evidence-only.
- [ ] Microsoft platform identities do not produce customer-actionable owner, publisher, agent, write-readiness, or decommission remediation.
- [ ] Fake/customer/third-party Microsoft-looking apps remain actionable when they do not meet the Microsoft platform metadata criteria.
- [ ] Client handoff output lists generated artifacts from the package path.
- [ ] Redacted outputs are classified as `ClientSafe`.
- [ ] Output manifest redacted entries are classified as `ClientSafe`.
- [ ] Replay validation returns `SkippedNoReplayInputs` when no replay inputs are present.
- [ ] Replay validation no-input results set `Passed = $null`.
- [ ] Replay validation no-input results set `CheckCount = 0`.
- [ ] Tool version metadata is consistent and reports `Rev4.10` across Rev4.10 paths.
- [ ] NHI/export JSON uses sufficient `ConvertTo-Json` depth to avoid truncation.
- [ ] Focused Pester tests cover all Rev4.10 behavior.
- [ ] No tenant write/delete/cleanup/decommission behavior was added or executed.
- [ ] No safety or guardrail behavior was weakened.

## Verification Expectations

- Run the focused Rev4.10 Pester slice after changes.
- If feasible, run the full Pester suite, but do not treat legacy unrelated failures as Rev4.10 regressions without evidence.
- Report:
  - Files changed
  - Tests run
  - PASS / PARTIAL / FAIL for each requirement
  - Remaining risks or gaps

