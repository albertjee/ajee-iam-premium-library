# Build Spec — Identity Attack & Recovery Simulator Demo

**Project name:** Identity Attack & Recovery Simulator  
**Working title:** *Under Attack: Simulating, Surviving, and Recovering the Identity Control Plane*  
**Author/producer:** Albert Jee  
**Revision:** v0.1 Build Spec  
**Date:** 2026-05-22  
**Status:** Draft for review

---

## 1. Executive Summary

This project will build a safe, controlled demo that mirrors the high-level story in the Veeam *Under Attack* presentation:

1. A user grants consent to a fake SaaS/AI application.
2. A malicious application or service principal gains persistence.
3. Identity-control-plane objects are modified or damaged.
4. Trusted SaaS applications are affected through SSO and delegated access.
5. The environment is compared against a known-good state.
6. Identity, authorization, SaaS data, and forensic evidence are recovered.

The demo must **not** implement real phishing, credential theft, token interception, stealth persistence, or destructive behavior against a production tenant. It will simulate the observable effects of an identity attack in a disposable lab environment and provide a boardroom-ready UI for explaining blast radius and recovery.

---

## 2. Purpose

The goal is to create a practitioner-grade demo showing that modern identity compromise is not merely an authentication event. It is a control-plane failure that can affect:

- Microsoft Entra ID
- Microsoft 365
- SaaS applications such as Salesforce, Workday, or ServiceNow
- OAuth consent grants
- App registrations and service principals
- Conditional Access policies
- Admin roles and privileged assignments
- Audit evidence and recovery readiness

The demo should support executive storytelling, technical architecture review, and future GitHub publication.

---

## 3. Demo Thesis

> Identity is the control plane.  
> If an attacker gains trusted identity or delegated application access, recovery must restore more than files. It must restore trust, authorization state, SaaS data, and forensic continuity.

---

## 4. Source Inspiration

The uploaded Veeam slide deck frames the demo as a live authentication-consent attack that compromises a SaaS environment and is then recovered through Veeam Data Cloud. It presents Entra ID as the foundation trusted by M365, Salesforce, Workday, and ServiceNow, and describes identity objects such as users, roles, policies, and app registrations as the customer’s responsibility to protect.

The deck’s attack-chain model is:

1. Consent granted
2. Persistence established
3. Identity destroyed
4. Lateral movement

The recap slide describes recovery as:

- Recovering Entra ID to a pre-attack state
- Granular recovery of Microsoft 365 data
- Salesforce record restoration
- Audit-log export for forensic investigation
- Operations resuming without full tenant restore

This build spec uses that narrative pattern but implements it as a safe simulator and optional controlled Microsoft Graph lab.

---

## 5. Design Principles

### 5.1 Safety First

The demo must not include:

- Credential harvesting
- Token capture
- Real phishing pages
- Malicious OAuth flows
- Instructions for stealth persistence
- Bypassing MFA
- Production-tenant destructive operations

The simulator may show these events as **pre-modeled state changes** and **audit events**.

### 5.2 Reversible State

Every simulated “attack” action must have a corresponding recovery action.

Examples:

| Simulated attack state | Recovery state |
|---|---|
| Unauthorized app appears | App removed or quarantined |
| Conditional Access policy disabled | Policy restored from baseline |
| Backdoor admin user appears | User disabled/removed |
| Role assignment changed | Known-good role assignment restored |
| M365 sample file corrupted | File restored from clean copy |
| SaaS record modified | Record restored from backup/mock data |

### 5.3 Executive-Friendly UI

The UI should clearly show:

- Attack stage
- Changed objects
- Blast radius
- Recovery action
- Before/after state
- Evidence preserved

### 5.4 Technical Credibility

The demo should be credible to IAM architects. It should include realistic object types and terminology:

- Users
- Groups
- Administrative units
- Directory roles
- Privileged assignments
- App registrations
- Enterprise applications / service principals
- OAuth permission grants
- Conditional Access policies
- Sign-in logs
- Audit logs
- Microsoft 365 content
- SaaS records

---

## 6. Target Audience

Primary:

- CISOs
- IAM architects
- Microsoft 365 / Entra architects
- Zero Trust program owners
- Identity governance teams
- SaaS security owners
- Audit/compliance stakeholders

Secondary:

- Technical recruiters and hiring managers evaluating identity-architecture depth
- Consulting prospects
- LinkedIn / Medium audience

---

## 7. Demo Modes

The project should support three build modes.

---

### Mode 1 — Visual Simulator

**Purpose:** Fastest version. Safe for public demos, screenshots, LinkedIn posts, and boardroom storytelling.

**Behavior:**

- No live Graph permissions
- No real tenant mutation
- Uses static JSON state
- UI animates attack and recovery
- Generates synthetic audit log
- Exports recovery report

**Deliverable:** Browser-based static app or lightweight React app.

---

### Mode 2 — Semi-Live Entra Lab

**Purpose:** Technical credibility demo using a disposable Microsoft 365 / Entra developer tenant.

**Behavior:**

- Uses Microsoft Graph PowerShell
- Exports known-good state
- Applies safe reversible changes
- Compares current state to baseline
- Restores baseline state
- Exports audit/recovery report

**Hard guardrails:**

- Must require explicit `-LabTenantConfirmed` or equivalent safety flag.
- Must block execution if tenant domain is not on an allow-list.
- Must never run against production tenant.
- Must log all actions locally.

---

### Mode 3 — Multi-Workload Recovery Demo

**Purpose:** Full story with identity, M365 content, and mock or developer-SaaS records.

**Behavior:**

- Entra state snapshot/restore
- Microsoft 365 sample file corruption/restore
- Mock Salesforce record modification/restore
- Optional dashboard showing recovery across workloads

---

## 8. Recommended Initial Build

Start with **Mode 1 — Visual Simulator**.

Rationale:

- Locks story and UI before scripting Graph changes
- Safer and faster
- Easier to iterate
- Produces usable artifacts immediately
- Can be published without tenant secrets or admin permissions

Mode 2 and Mode 3 should be treated as follow-on milestones.

---

## 9. High-Level User Experience

### 9.1 Main UI Layout

```text
+--------------------------------------------------------------------------------+
| Identity Attack & Recovery Simulator                                            |
| Known Good State | Attack Simulation | Blast Radius | Recovery | Evidence       |
+--------------------------------------------------------------------------------+
| Attack Timeline        | Identity Control Plane Map          | Risk / Status    |
|------------------------|--------------------------------------|------------------|
| 1 Consent Granted      | Users          Apps                  | Current Risk     |
| 2 Persistence          | Roles          Service Principals    | Changed Objects  |
| 3 Identity Damage      | Groups         Conditional Access    | Recovery Score   |
| 4 Lateral Movement     | M365           SaaS Records          | Evidence Status  |
+--------------------------------------------------------------------------------+
| Event Console / Audit Timeline                                                  |
+--------------------------------------------------------------------------------+
```

### 9.2 UI Tabs

1. **Overview**
   - Demo premise
   - Known-good identity posture
   - Current risk posture

2. **Attack Simulation**
   - Stage-by-stage identity attack simulation
   - “Run Stage” buttons
   - Clear SIMULATED labels

3. **Blast Radius**
   - Changed users, roles, apps, policies, files, records
   - Impact scoring
   - Identity-control-plane dependency map

4. **Recovery**
   - Restore identity objects
   - Restore authorization assignments
   - Restore M365 sample files
   - Restore SaaS records
   - Validate recovery

5. **Evidence**
   - Audit timeline
   - Recovery report
   - JSON/CSV export
   - Hash of exported evidence file, optional future feature

---

## 10. Visual Style

Recommended style: **Albert Style 106_I adapted for demo UI**

Visual principles:

- Dark midnight navy background
- Brushed gold and restrained blue/teal accents
- High-contrast text
- Enterprise architecture aesthetic
- No cyberpunk clutter
- Clear state transitions
- Boardroom-readable labels

Suggested palette:

| Element | Color |
|---|---|
| Background | `#0F172A` |
| Card background | `#111827` |
| Primary text | `#F8FAFC` |
| Secondary text | `#CBD5E1` |
| Gold accent | `#C6A75E` |
| Teal/restore accent | `#2DD4BF` |
| Warning accent | `#F59E0B` |
| Critical accent | `#EF4444` |
| Success accent | `#22C55E` |

---

## 11. Data Model

### 11.1 Known-Good State

File: `data/known-good-state.json`

Example object categories:

```json
{
  "tenant": {
    "name": "Contoso Identity Lab",
    "mode": "simulated",
    "baselineCapturedAt": "2026-05-22T00:00:00Z"
  },
  "users": [],
  "groups": [],
  "roles": [],
  "roleAssignments": [],
  "applications": [],
  "servicePrincipals": [],
  "oauthGrants": [],
  "conditionalAccessPolicies": [],
  "m365Files": [],
  "saasRecords": []
}
```

### 11.2 Attack Events

File: `data/attack-events.json`

Required fields:

```json
{
  "eventId": "EVT-001",
  "stage": "Consent Granted",
  "severity": "High",
  "objectType": "OAuthPermissionGrant",
  "objectName": "NovaSync AI",
  "action": "Simulated delegated consent granted",
  "impact": "Read access to email, files, and user profile data",
  "timestamp": "2026-05-22T00:01:00Z"
}
```

### 11.3 Recovery Actions

File: `data/recovery-actions.json`

Required fields:

```json
{
  "actionId": "REC-001",
  "category": "Application Governance",
  "action": "Remove unauthorized service principal",
  "targetObject": "NovaSync AI",
  "status": "Pending",
  "validation": "Unauthorized app no longer present"
}
```

---

## 12. Simulated Attack Stages

### Stage 1 — Consent Granted

**Narrative:** A user authorizes a fake SaaS/AI app named **NovaSync AI**.

**Visible UI changes:**

- New application appears
- New OAuth grant appears
- Risk score increases
- Audit event added

**Simulated object types:**

- App registration
- Enterprise application / service principal
- OAuth permission grant
- Delegated permissions

**No real credential or token capture is implemented.**

---

### Stage 2 — Persistence Established

**Narrative:** The unauthorized app receives elevated or durable access.

**Visible UI changes:**

- Unauthorized app persists in application list
- Service principal marked “High Risk”
- Admin consent indicator appears
- Persistence warning appears

**Simulated object types:**

- Service principal
- Application permission grant
- App role assignment
- Credential/secret metadata placeholder

**Safety boundary:** Do not create real high-privilege app grants in a production tenant.

---

### Stage 3 — Identity Control Plane Damaged

**Narrative:** Identity objects and policies are changed.

**Visible UI changes:**

- Conditional Access policy disabled
- Backdoor admin user appears
- Legitimate admin role assignment removed
- MFA/strong-auth posture marked weakened
- Risk score becomes critical

**Simulated object types:**

- User
- Directory role
- Role assignment
- Conditional Access policy
- Authentication method state placeholder

---

### Stage 4 — Lateral SaaS Movement

**Narrative:** Connected SaaS and M365 workloads are affected through trusted identity.

**Visible UI changes:**

- M365 files modified/deleted
- Mock Salesforce records changed
- SaaS workload status becomes impacted
- Blast-radius panel expands

**Simulated object types:**

- SharePoint/OneDrive sample documents
- Teams/Exchange placeholder items, optional
- Salesforce mock records
- SSO trust dependency

---

## 13. Detection and Blast-Radius View

The blast-radius page should include:

- Changed object count
- Privileged object count
- Apps with risky grants
- Conditional Access policies changed
- SaaS workloads affected
- Data objects modified
- Recovery readiness score

### Sample Metrics

| Metric | Description |
|---|---|
| Identity Drift Count | Number of identity objects changed from baseline |
| Privilege Drift Count | Number of role/app permission changes |
| Policy Drift Count | Number of CA or governance policy changes |
| SaaS Impact Count | Number of SaaS/M365 objects changed |
| Evidence Completeness | Whether audit timeline and export are available |
| Recovery Confidence | Whether baseline restore validation passes |

---

## 14. Recovery Workflow

### Step 1 — Freeze and Preserve Evidence

Actions:

- Stop simulation clock
- Export audit timeline
- Export changed-object diff
- Generate evidence package

Output:

- `evidence/audit-log.json`
- `evidence/changed-objects.json`
- `evidence/recovery-report.md`

### Step 2 — Remove Unauthorized Application Access

Actions:

- Remove/quarantine NovaSync AI
- Remove simulated OAuth grant
- Remove app role assignment
- Mark service principal as remediated

Validation:

- Unauthorized app no longer appears in active app list
- OAuth grant count returns to baseline

### Step 3 — Restore Identity State

Actions:

- Restore legitimate admin
- Disable/remove backdoor admin
- Restore role assignments
- Restore group membership

Validation:

- Role-assignment diff returns to zero
- Backdoor user no longer active

### Step 4 — Restore Policy State

Actions:

- Re-enable Conditional Access policy
- Restore policy JSON from known-good baseline
- Validate policy state

Validation:

- CA policy count and enabled state match baseline

### Step 5 — Restore SaaS/M365 Data

Actions:

- Restore sample M365 files from clean copy
- Restore mock Salesforce records from backup JSON/CSV

Validation:

- File hash matches clean baseline
- SaaS record values match baseline

### Step 6 — Produce Recovery Report

Report should include:

- Attack timeline
- Changed objects
- Recovery actions
- Validation results
- Remaining risks
- Lessons learned

---

## 15. Repository Structure

```text
identity-attack-recovery-simulator/
│
├─ README.md
├─ LICENSE
├─ .gitignore
│
├─ docs/
│  ├─ build-spec.md
│  ├─ demo-script.md
│  ├─ architecture.md
│  ├─ safety-boundaries.md
│  ├─ recovery-model.md
│  └─ glossary.md
│
├─ simulator-ui/
│  ├─ index.html
│  ├─ app.js
│  ├─ styles.css
│  └─ data/
│     ├─ known-good-state.json
│     ├─ current-state.json
│     ├─ attack-events.json
│     └─ recovery-actions.json
│
├─ graph-lab/
│  ├─ README.md
│  ├─ config.sample.json
│  ├─ Export-KnownGoodState.ps1
│  ├─ Invoke-SimulatedIdentityChange.ps1
│  ├─ Compare-IdentityState.ps1
│  ├─ Restore-IdentityState.ps1
│  └─ Test-LabTenantGuardrail.ps1
│
├─ m365-lab/
│  ├─ README.md
│  ├─ sample-files/
│  ├─ clean-backup/
│  ├─ Invoke-SimulatedM365DataChange.ps1
│  └─ Restore-SampleM365Data.ps1
│
├─ saas-mock/
│  ├─ salesforce-records-baseline.json
│  ├─ salesforce-records-current.json
│  ├─ Invoke-SimulatedSaaSChange.ps1
│  └─ Restore-SaaSRecords.ps1
│
├─ evidence/
│  ├─ audit-log-sample.json
│  ├─ changed-objects-sample.json
│  └─ recovery-report-sample.md
│
└─ exports/
   └─ screenshots/
```

---

## 16. MVP Scope

The first working version should include:

- Static browser UI
- Known-good state JSON
- Current-state JSON
- Four attack-stage buttons
- Recovery buttons
- Blast-radius panel
- Audit event timeline
- Export recovery report as Markdown or JSON
- No external dependencies required

### MVP Exclusions

Do not include in v0.1:

- Real Microsoft Graph mutations
- Real OAuth consent flow
- Real Salesforce API integration
- Real token handling
- Real phishing simulation
- Real production backup/restore

---

## 17. Milestones

### Milestone 1 — Build Spec and Demo Narrative

Deliverables:

- `docs/build-spec.md`
- `docs/demo-script.md`
- Attack/recovery storyline
- UI wireframe

Acceptance criteria:

- Narrative maps cleanly to consent, persistence, identity damage, lateral movement, and recovery.
- Safety boundaries are explicit.

---

### Milestone 2 — Static Simulator UI

Deliverables:

- `simulator-ui/index.html`
- `simulator-ui/app.js`
- `simulator-ui/styles.css`
- Sample JSON data

Acceptance criteria:

- User can run all four attack stages.
- UI shows changed objects and risk posture.
- User can run recovery and return to known-good state.
- Evidence log can be exported.

---

### Milestone 3 — Recovery Report Generator

Deliverables:

- Recovery report export
- Audit timeline export
- Changed-object diff export

Acceptance criteria:

- Report includes attack stages, changed objects, remediation actions, and validation results.

---

### Milestone 4 — Graph Lab Read-Only Baseline

Deliverables:

- `Export-KnownGoodState.ps1`
- Read-only Graph export for users, groups, apps, service principals, roles, and CA policies

Acceptance criteria:

- Script exports baseline JSON.
- No tenant changes are made.
- Permissions are documented.

---

### Milestone 5 — Controlled Graph Lab Restore

Deliverables:

- `Compare-IdentityState.ps1`
- `Restore-IdentityState.ps1`
- Lab guardrail script

Acceptance criteria:

- Script refuses to run without lab confirmation.
- Restore targets only allow-listed lab objects.
- Recovery validation report is produced.

---

### Milestone 6 — M365 and SaaS Mock Recovery

Deliverables:

- Sample M365 file restore
- Mock Salesforce record restore
- Unified recovery dashboard

Acceptance criteria:

- Demo shows identity + data recovery together.
- No production SaaS integration required.

---

## 18. PowerShell / Graph Lab Guardrails

Every write-capable script must include:

- `-WhatIf` support where feasible
- `-Confirm` behavior for risky operations
- Explicit lab tenant allow-list
- Tenant ID/domain verification
- Dry-run mode
- Local transcript logging
- Object-name prefix requirement, such as `LAB-`
- Refusal to operate on untagged/non-lab objects

Example required config field:

```json
{
  "allowedTenantIds": ["00000000-0000-0000-0000-000000000000"],
  "allowedDomains": ["contoso-lab.onmicrosoft.com"],
  "labObjectPrefix": "LAB-",
  "requireLabConfirmation": true
}
```

---

## 19. Proposed Commands for Future Graph Lab

Read-only baseline:

```powershell
.\Export-KnownGoodState.ps1 -ConfigPath .\config.json -OutputPath .\baseline\known-good-state.json
```

Compare current state:

```powershell
.\Compare-IdentityState.ps1 -BaselinePath .\baseline\known-good-state.json -OutputPath .\evidence\changed-objects.json
```

Simulate safe lab drift:

```powershell
.\Invoke-SimulatedIdentityChange.ps1 -ConfigPath .\config.json -LabTenantConfirmed -WhatIf
```

Restore lab state:

```powershell
.\Restore-IdentityState.ps1 -ConfigPath .\config.json -BaselinePath .\baseline\known-good-state.json -LabTenantConfirmed -WhatIf
```

---

## 20. Demo Script Outline

### Opening

“Today’s demo shows why identity recovery is now part of data resilience. We are not simulating malware. We are simulating what happens when trusted identity and delegated application access are abused.”

### Baseline

“Here is our known-good identity control plane: users, roles, applications, Conditional Access policies, M365 content, and SaaS records.”

### Stage 1

“A user consents to NovaSync AI. In a real attack, this may appear normal. In our simulator, we show the resulting delegated-access object.”

### Stage 2

“The application now has persistence. Password resets and MFA changes do not automatically remove application grants or service-principal access.”

### Stage 3

“The identity control plane is damaged: roles change, a backdoor admin appears, and Conditional Access protection weakens.”

### Stage 4

“The blast radius moves into SaaS. M365 files and Salesforce-style records are modified because those workloads trust the identity layer.”

### Recovery

“Recovery starts by preserving evidence. Then we remove unauthorized access, restore identity state, restore policy state, restore SaaS data, and validate the control plane against the known-good baseline.”

### Closing

“The lesson is simple: backup is not enough unless identity trust, authorization state, and audit evidence can also be restored.”

---

## 21. Acceptance Criteria

The project is acceptable when:

- The UI clearly shows the four-stage attack chain.
- The simulator avoids unsafe behavior.
- Recovery returns all modeled objects to baseline.
- The evidence export works.
- The recovery report is readable by both executives and technical reviewers.
- The repo is clean enough for future GitHub publication.
- The demo can be run locally without cloud credentials in Mode 1.

---

## 22. Open Questions for Albert Review

1. Should the fake app name remain **NovaSync AI**?
2. Should the demo use **Salesforce** specifically, or use a generic “CRM SaaS” mock first?
3. Should the UI be plain HTML/JS for portability, or React for a more polished demo?
4. Should the first GitHub version include only Mode 1, with Graph lab scripts staged but not active?
5. Should the branding use **Albert Style 106_I** or a more neutral open-source theme?
6. Should we include a one-page executive PDF later as a demo leave-behind?

---

## 23. Recommended Next Step

Build **Milestone 2: Static Simulator UI** as the first code milestone.

Recommended instruction for Codex:

> Build the Mode 1 static simulator from `docs/build-spec.md`. Use plain HTML, CSS, and JavaScript unless React is explicitly requested. Implement the four attack stages, known-good/current state comparison, recovery workflow, audit timeline, and exportable recovery report. Do not implement real phishing, token capture, OAuth flows, Graph write operations, or production-tenant integrations. Keep all state in local JSON/JavaScript objects. Use a dark enterprise UI with high contrast and executive readability.

---

## 24. Change Log

| Revision | Date | Change |
|---|---:|---|
| v0.1 | 2026-05-22 | Initial build spec created from uploaded Veeam demo deck and Albert’s requested simulator direction. |
