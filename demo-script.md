# Demo Script — Identity Attack & Recovery Simulator
**Version:** v0.1  
**Date:** 2026-05-22  
**Author:** Albert Jee  
**Simulator:** identity-attack-recovery-simulator-v02.html  
**Mode:** Mode 1 — Visual Simulator (no live tenant)

---

## Before You Start

- Open `identity-attack-recovery-simulator-v02.html` in any modern browser
- No internet connection required
- No credentials required
- All state is local to the browser session
- Use **↺ Reset to Baseline** at any time to start over

Estimated run time: 8–12 minutes end to end. Shorter if skipping narration.

---

## Opening Frame

**Tab:** Overview

**Say:**
> "Today's demo is not about malware. It is about what happens when an attacker gains trusted identity and delegated application access inside your environment. Once that happens, the attack does not look like an attack. It looks like normal business activity — authorized apps, legitimate logins, routine API calls. The only way to recover is to restore more than files. You have to restore trust, authorization state, policy state, and forensic continuity."

**Point to:**
- The **Identity Control Plane** node map — Entra ID at the center, connecting M365, Salesforce, Workday, app registrations, and CA policies
- The **Trust Score bar** — currently 100, all green
- The **3 users, 1 app, 3 CA policies** shown in the object grid — this is the known-good baseline

**Pause point:** Let the audience absorb the clean state before moving.

---

## Part 1 — Known-Good State

**Tab:** Overview

**What to show:**
- Three clean users: Ethan Hunt (Global Admin), Mia Chen (Exchange Admin), Raj Patel (User)
- One approved app: Veeam Backup Agent
- Three CA policies all marked Clean
- Event console showing two baseline log entries

**Say:**
> "This is the known-good state — a snapshot of what the tenant looks like before anything goes wrong. Three users, known roles, three Conditional Access policies enforcing MFA and device compliance, and one approved application. This is the baseline we will recover to."

**Transition:**
> "Now let me show you how quickly this falls apart."

**Click:** Tab → **Attack Simulation**

---

## Part 2 — The Attack

### Stage 1 — Consent Granted

**Tab:** Attack Simulation

**Point to the Stage 1 panel before clicking.**

**Say:**
> "Someone on the team clicked an ad on LinkedIn. It looked legitimate — a company called NovaSync AI, employee profiles copied from a real AI startup, targeted at people with admin-level access. The ad led to a standard Microsoft OAuth consent page. Nothing looked wrong."

**Click:** ▶ Run Stage 1 — Consent Granted

**Watch for:**
- NovaSync AI appears in the app list with status Suspicious
- OAuth grant appears in the object grid
- Console logs: `[SIM] OAuth consent granted to NovaSync AI — delegated read access acquired`
- Trust Score drops
- Risk Level increases
- Status badge changes to **Under Attack**

**Say:**
> "That one click issued a token. The attacker now has delegated read access to email, files, and user profile data — without ever knowing the user's password. No malware. No suspicious domain. Just a legitimate-looking OAuth flow."

**Pause.** Let the console log sink in.

---

### Stage 2 — Persistence Established

**Say:**
> "Now watch what happens next. The app does not stop at read access."

**Click:** ▶ Run Stage 2 — Persistence Established

**Watch for:**
- NovaSync AI service principal appears with status Compromised
- Console logs: `[SIM] Persistence established — service principal registered with application-level admin consent`
- Console logs: `[SIM] App credential secret added — persists beyond MFA/password resets`
- Risk Level climbs further

**Say:**
> "The attacker has now registered a service principal with Directory.ReadWrite.All — application-level permission, not delegated. This means if you reset the user's password or enforce MFA right now, the attacker does not lose access. The app's credential still works. This is why identity recovery is not just resetting passwords."

---

### Stage 3 — Identity Control Plane Damaged

**Say:**
> "Stage three is where the real damage happens."

**Click:** ▶ Run Stage 3 — Identity Damaged

**Watch for:**
- Backdoor user humphrey.dumpty appears with status Compromised and role Global Admin
- Ethan Hunt's status changes to Compromised, role shows DELETED
- CA Policy "Require MFA — All Admins" changes to Compromised
- Node map: Users & Roles and Conditional Access nodes turn red with propagation animation
- Console logs three critical events

**Say:**
> "Three things just happened simultaneously. A backdoor Global Admin account was created. The legitimate Global Admin was deleted. And the Conditional Access policy requiring MFA for admins was disabled."
>
> "The attacker now owns the identity control plane. SSO works against you at this point — one identity unlocks everything."

**Navigate to:** Tab → **Blast Radius**

**Click any changed object card to expand the before/after diff.**

**Say:**
> "Look at the blast radius. Objects have drifted from baseline. Click any card to see exactly what changed — field by field, baseline value on the left, current compromised value on the right."

**Navigate back to:** Tab → **Attack Simulation**

---

### Stage 4 — Lateral SaaS Movement

**Say:**
> "Stage four is where the business impact becomes visible."

**Click:** ▶ Run Stage 4 — Lateral Movement

**Watch for:**
- M365 files Q1-Strategy.docx and Board-Deck-May.pptx change to Compromised
- Salesforce opportunity Contoso Deal $2.4M changes to Compromised
- Workday HR Record changes to Suspicious
- Node map: SaaS nodes ripple red one after another
- Console logs four events including SSO movement confirmation

**Navigate to:** Tab → **Blast Radius**

**Say:**
> "The blast radius now spans identity, M365, and Salesforce. The attacker reached Salesforce through SSO — not by attacking Salesforce directly. They used the trusted identity layer."

---

## Part 3 — Detection and Forensics

**Tab:** Evidence

**Say:**
> "Before we touch anything in recovery, we preserve evidence. This is non-negotiable."

**Click:** ↓ Export JSON  
**Click:** ↓ Export CSV

---

## Part 4 — Recovery

**Tab:** Recovery

**Run Steps 01–05 in order. Export Recovery Report when complete.**

---

## Closing

**Tab:** Overview

**Say:**
> "Four things to take away. The threat is real. Shared responsibility means shared action. Treat identity as infrastructure. And recovery must restore more than files — in that order."

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Buttons stay disabled | Run stages in order — each stage unlocks the next |
| State looks wrong mid-demo | Click **↺ Reset to Baseline** and start over |
| Export does nothing | Check browser download permissions |
| Node map not updating | Navigate away and back to the tab |

---

## Quick-Reference Checklist

- [ ] Open file in browser — confirm baseline state
- [ ] Tab: Overview — show known-good state
- [ ] Tab: Attack — run Stage 1, confirm NovaSync AI appears
- [ ] Tab: Attack — run Stage 2, confirm service principal appears
- [ ] Tab: Attack — run Stage 3, confirm backdoor admin and CA policy change
- [ ] Tab: Blast Radius — expand a diff card, show before/after fields
- [ ] Tab: Attack — run Stage 4, confirm M365 and Salesforce drift
- [ ] Tab: Evidence — show audit log, export JSON and CSV
- [ ] Tab: Recovery — run Steps 01–05 in order
- [ ] Tab: Overview — show recovered state
- [ ] Tab: Recovery — export recovery report

---

## Change Log

| Revision | Date | Change |
|---|---|---|
| v0.1 | 2026-05-22 | Initial demo script |
| v0.2 | 2026-05-22 | Updated for v0.2 simulator — node animation and diff view callouts added |
