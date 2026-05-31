# Consultant Runbook — Entra Identity Decommissioning Control Plane

**Rev1.4 | Assessment-first identity governance for Microsoft Entra ID**

---

## Pre-Engagement Checklist

Before running the assessment tool on a client tenant:

- [ ] Confirm tenant scope — single tenant or multi-tenant engagement
- [ ] Confirm the assessment is authorized by the client's IT or security team
- [ ] Request read-only Graph permissions (see Required-Permissions.md)
- [ ] Confirm whether sign-in/audit logs are available (AuditLog.Read.All)
- [ ] Confirm whether guest and app ownership analysis is in scope
- [ ] Confirm whether Conditional Access analysis is in scope (Policy.Read.All)
- [ ] Confirm whether IGA/Entitlement Management is in scope (P3 license required)
- [ ] Run demo mode locally to confirm tooling is working before the engagement call
- [ ] Agree on output handling — where reports will be stored and who will have access

---

## Execution

### Step 1 — Run demo mode first

Always run demo mode before connecting to a client tenant. Confirms tooling is working
and gives you a preview of the report format to share with the client.

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 -DemoMode
```

### Step 2 — Run live assessment

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -TenantId     "client.onmicrosoft.com" `
    -EngagementId "ENG-001" `
    -ClientName   "Client Name" `
    -Assessor     "Your Name" `
    -OutputPath   ".\out"
```

Sign in with a read-only account that has the required Graph permissions.
The tool will prompt for interactive authentication.

### Step 3 — Review coverage warnings

Check the console output for `[WARN]` lines. These indicate areas where Graph
permissions were unavailable and coverage is partial. Common examples:

- `AuditLog.Read.All` not granted → sign-in activity unavailable
- `EntitlementManagement.Read.All` not granted → IGA coverage incomplete
- `Policy.Read.All` not granted → CA analysis unavailable

Document coverage gaps in your engagement notes. The run manifest JSON also records
which coverage areas succeeded and which were unavailable.

### Step 4 — Review findings

Open the HTML report in a browser. Review:
1. Critical and High findings first — these drive the remediation plan
2. Medium findings — governance hygiene items
3. Coverage summary — what was and was not assessed
4. Assumptions and Limitations section

---

## Client Workshop

### Opening the conversation

Start with the HTML executive scorecard:
- Show the KPI grid: total findings, Critical+High count, protected objects, coverage mode
- Explain the safety model: "This tool ran in read-only mode — nothing was changed"
- Walk through finding categories before diving into specific findings

### Working through findings

For each Critical and High finding:
1. Confirm the finding is accurate (not a false positive)
2. Identify the business owner for the affected object
3. Agree on the recommended action
4. Confirm whether the finding is a true risk or an approved exception
5. Assign ownership and timeline

### Common client questions

**"Is this tool making any changes to our environment?"**
No. Assessment mode is read-only. The safety banner confirms this on every run.
ExecuteRemediation is blocked until Rev2.0 and requires an approved remediation manifest.

**"Why does a disabled user still have these permissions?"**
This is the most common finding. Offboarding workflows often miss app role assignments,
group memberships, and privileged roles when disabling accounts.

**"What is a protected object?"**
Accounts matching break-glass, emergency, sync, or service account patterns are
classified as protected. The tool flags them but never recommends automatic remediation.

**"What does 'access review status unknown' mean for CA exclusions?"**
The tool detects that a CA exclusion group has members, but does not yet query
access review history. This is a coverage limitation, not a finding error.

---

## Post-Workshop

1. Export the remediation plan in WhatIfRemediation mode if needed
2. Update the plan with client-confirmed approvals
3. Mark findings as: Approved for Remediation / Approved Exception / Deferred
4. Store the signed remediation plan as the approval artifact for Rev2.0 execution
5. Schedule a follow-up assessment 30-60 days after remediation to verify closure

---

## Execution Workflow (Rev2.1)

### Full engagement sequence

```
1. Assessment run — read-only, identify findings
2. WhatIfRemediation run with -GenerateApprovalTemplate — generates action plan
3. Review action plan with client — confirm each action by ObjectId and DisplayName
4. Client signs approval manifest — set ApprovalStatus=Approved, ApprovedBy, ApprovedUtc
5. Run Update-DecomApprovalManifestHash to recompute integrity hashes
6. ExecuteRemediation run — three-gate validation, preflight summary, execution, evidence pack
7. Deliver evidence pack to client — execution report HTML, evidence CSV, execution manifest
```

### ExecuteRemediation command

```powershell
.\Invoke-EntraIdentityDecommissioningControlPlane.ps1 `
    -Mode                 ExecuteRemediation `
    -TenantId             "client.onmicrosoft.com" `
    -EngagementId         "ENG-001" `
    -ClientName           "Client Name" `
    -Assessor             "Your Name" `
    -WhatIfManifestPath   ".\out\<timestamp>\entra-decommissioning-control-plane-run-manifest-*.json" `
    -ApprovalManifestPath ".\out\<timestamp>\whatif-action-plan-*.json" `
    -OutputPath           ".\out"
```

### Max action guardrail

Default `-MaxActions` is 25. To execute more than 25 approved actions:

```powershell
-MaxActions 50
```

To execute a specific subset of actions:

```powershell
-ActionId ACT-001,ACT-002,ACT-005
```

### Approval manifest optional fields (Rev2.1)

The approval manifest now supports these optional fields for enterprise governance:

```json
"ApprovalTicket": "CHG123456",
"ApprovalSystem": "ServiceNow",
"BusinessOwner": "Jane Smith",
"TechnicalOwner": "Alex Chen",
"ApprovalNotes": "Approved for leaver cleanup wave 1",
"ExecutionWindowStartUtc": "2026-06-01T08:00:00Z",
"ExecutionWindowEndUtc": "2026-06-01T18:00:00Z"
```

If `ExecutionWindowStartUtc` and `ExecutionWindowEndUtc` are both present,
execution is blocked outside that window.

---

## Known Limitations (Rev1.4)

- Assessment mode is read-only — no changes are made to the tenant
- Sign-in activity requires `AuditLog.Read.All` — unavailable without this scope
- IGA/Entitlement Management requires `EntitlementManagement.Read.All` and a P3 license
- CA exclusion review status is not verified against access review history (Rev1.4)
- DEC-ROLE-001 detects disabled privileged users only — stale sign-in privileged role detection is planned
- PIM eligible role assignments are not yet analyzed (planned)
- Hybrid / on-premises AD DS environments are not in scope
- Multi-tenant assessment requires running the tool separately per tenant

---

## Troubleshooting

**Tool opens in Notepad instead of running:**
Run explicitly with pwsh:
```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ".\Invoke-EntraIdentityDecommissioningControlPlane.ps1" -DemoMode
```

**Graph connection fails:**
Confirm the account has the required permissions and the tenant ID is correct.
Check for conditional access policies blocking the sign-in.

**Coverage: Partial in the report:**
One or more Graph areas returned 403. Check the `[WARN]` lines in the console output
for which permissions are missing.

**0 findings on live tenant:**
Check coverage warnings. If all discovery areas succeeded but 0 findings were returned,
the tenant may be well-governed — or the disabled user set may be empty.
Run with `-DemoMode` to confirm the tool is generating findings correctly.
