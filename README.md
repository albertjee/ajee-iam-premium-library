# Identity Attack & Recovery Simulator

A single-file HTML simulator demonstrating a real-world OAuth consent attack chain
against Microsoft Entra ID, with animated blast radius and guided recovery.

## What it demonstrates

- Four-stage attack: consent granted → persistence → identity damaged → lateral SaaS movement
- Before/after diff view per changed object
- Presenter mode for boardroom delivery
- Lure flow showing the three-screen social engineering sequence
- Five-step guided recovery with forensic audit export

## Usage

Open \identity-attack-recovery-simulator-v04.html\ in any modern browser.
No build step. No server. No credentials required.

## Files

| File | Purpose |
|---|---|
| \identity-attack-recovery-simulator-v04.html\ | Primary simulator — current version |
| \simulator-config.json\ | Scenario text and image asset paths |
| \demo-script.md\ | Full presenter script with stage-by-stage narration |
| \ssets/screenshots/\ | Lure flow screenshots |
| \identity_attack_recovery_simulator_build_spec_v0_1.md\ | Original build specification |

## Version history

| Version | Key additions |
|---|---|
| v0.1 | Four-stage attack, recovery, audit export |
| v0.2 | Animated node propagation, before/after diff view |
| v0.3 | Presenter mode, lure flow modal, UTF-8 BOM fix |
| v0.4 | Adele Vance cross-user movement, property-level modify/restore, peak drift fix |

## Status

Simulated — no real tenant is connected. All state is local to the browser session.
