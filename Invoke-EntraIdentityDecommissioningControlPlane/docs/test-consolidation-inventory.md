# Test Consolidation Inventory - M7.1

> Status: **M7.2 EXECUTED (2026-07-05)** - all 48 SubSumed rows below resolved by reading actual
> assertion bodies (not just names) in every file they appeared in. 28 source files replaced by
> 3 consolidated files; old files removed via `git rm`. Final verified count: 2418/2418, 0 failures
> (down from 2430/2430 baseline). See `docs/refactoring-plan.md` section 5.9 for the full writeup.
> Generated: 2026-07-04 22:52 | Resolved: 2026-07-05
> Branch: refactor/phase1-cleanup | HEAD at generation: 599d2af

---

## Summary

| Group | Files | Total | Unique names | SubSumed | Unique (1-file) | Actual merges | Result |
|---|---|---|---|---|---|---|---|
| Safety.Rev4x | 8->1 | 66 | 57 | 7 | 50 | 7 (all true dupes/semantic dupes) | 54 tests (-12) |
| NhiRun4C | 12->1 | 230 | 180 (est.) | 27 | 153 | 0 (all 27 were false positives - different function per rev) | 230 tests (unchanged) |
| NhiControlledDecommission.Rev4x | 8->1 | 215 (static It count; actual discovered = 315 due to `-ForEach`) | 186 (est.) | 14 | 172 | 2 (12 were false positives) | 315 tests (unchanged) |
| **TOTAL** | **28->3** | **511 (static) / 611 (discovered)** | n/a | **48** | **375** | **9** | **2418 tests (-12 net from 2430 baseline)** |

**Key finding:** the mechanical name-matching used to generate this inventory could not distinguish
"same assertion text, genuinely duplicated" from "same `It` name reused across revisions, testing a
different underlying function/fixture." Of 48 flagged SubSumed names, only 9 were real duplicates
safe to merge; the other 39 were false positives and were correctly kept as separate tests to avoid
silent coverage loss.

---

## Consolidation Verdicts

- **SubSumed**: same It name appears in multiple files (typically per-rev test files with same invariant). Likely can be consolidated into one file per invariant group.
- **Unique (1-file)**: It name appears in exactly one file. Almost always worth keeping.

---

## Safety.Rev4x

**Files:** Safety.Rev42.Tests.ps1, Safety.Rev43.Tests.ps1, Safety.Rev44.Tests.ps1, Safety.Rev45.Tests.ps1, Safety.Rev46.Tests.ps1, Safety.Rev47.Tests.ps1, Safety.Rev48.Tests.ps1, Safety.Rev49.Tests.ps1

### SubSumed It-blocks (7 names appear in multiple files)

| It-name | Files (and their counts) | Rev-decls | Verdict |
|---|---|---|---|
| contains no Application delete cmdlet invocation | Safety.Rev43.Tests.ps1 [1], Safety.Rev44.Tests.ps1 [1] | 2 | MERGED - byte-identical body confirmed in both files; kept once (Rev4.3 block), duplicate removed |
| contains no ServicePrincipal delete cmdlet invocation | Safety.Rev43.Tests.ps1 [1], Safety.Rev44.Tests.ps1 [1] | 2 | MERGED - byte-identical body confirmed in both files; kept once (Rev4.3 block), duplicate removed |
| keeps SelfTest before controlled and Graph paths | Safety.Rev43.Tests.ps1 [1], Safety.Rev44.Tests.ps1 [1] | 2 | MERGED - single occurrence retained |
| keeps SelfTest before the controlled execution branch | Safety.Rev45.Tests.ps1 [1], Safety.Rev46.Tests.ps1 [1] | 2 | MERGED - single occurrence retained |
| keeps the additive module free of live Graph write/delete cmdlets | Safety.Rev45.Tests.ps1 [1], Safety.Rev46.Tests.ps1 [1] | 2 | MERGED - single occurrence retained; also absorbs the semantically-identical "controlled module...patterns" row below |
| keeps the controlled branch free of live Graph write/delete patterns | Safety.Rev47.Tests.ps1 [1], Safety.Rev48.Tests.ps1 [1], Safety.Rev49.Tests.ps1 [1] | 3 | MERGED - single occurrence retained (tests $script:ControlledBranch) |
| keeps the controlled module free of live Graph write/delete patterns | Safety.Rev47.Tests.ps1 [1], Safety.Rev48.Tests.ps1 [1], Safety.Rev49.Tests.ps1 [1] | 3 | MERGED INTO ROW ABOVE ("additive module...cmdlets") - verified same $script:Module/$script:ModuleSource regex-list check under different phrasing; not a separate assertion |

### Unique It-blocks (50 names, one file each)

| It-name | File | Verdict |
|---|---|---|
| Application FinalDelete remains blocked without AllowFinalDelete | Safety.Rev44.Tests.ps1 | KEEP |
| blocks AllowFinalDelete outside FinalDelete stage | Safety.Rev43.Tests.ps1 | KEEP |
| blocks FinalDelete and AllowFinalDelete | Safety.Rev42.Tests.ps1 | KEEP |
| classifies Application live delete as unavailable | Safety.Rev44.Tests.ps1 | KEEP |
| classifies live delete as unavailable in the gate model | Safety.Rev43.Tests.ps1 | KEEP |
| contains no Graph call in the additive module | Safety.Rev44.Tests.ps1 | KEEP |
| contains no Graph connection in the controlled branch | Safety.Rev42.Tests.ps1 | KEEP |
| contains no Graph connection or request in the additive module | Safety.Rev43.Tests.ps1 | KEEP |
| contains no Graph mutation command in the controlled branch | Safety.Rev42.Tests.ps1 | KEEP |
| contains no prohibited Graph mutation command names in the sample or module | Safety.Rev49.Tests.ps1 | KEEP |
| contains no secret-like values in the production readiness sample | Safety.Rev49.Tests.ps1 | KEEP |
| default source path contains no Application gate invocation before controlled branch | Safety.Rev44.Tests.ps1 | KEEP |
| defines the Rev4.2-S1 parameter contract | Safety.Rev42.Tests.ps1 | KEEP |
| dispatches Application readiness separately from ServicePrincipal gate | Safety.Rev44.Tests.ps1 | KEEP |
| does not invoke prohibited deletion commands anywhere in the entry point | Safety.Rev42.Tests.ps1 | KEEP |
| does not reference any live Graph write/delete cmdlet anywhere in the entry point AST | Safety.Rev49.Tests.ps1 | KEEP |
| does not schedule live merge or push operations | Safety.Rev49.Tests.ps1 | KEEP |
| does not synthesize managed identity evidence defaults in the controlled branch | Safety.Rev47.Tests.ps1 | KEEP |
| exports five local evidence artifacts and exits before existing execution flow | Safety.Rev42.Tests.ps1 | KEEP |
| exposes the Rev4.5 metadata cleanup stage string | Safety.Rev45.Tests.ps1 | KEEP |
| exposes the Rev4.6 grants cleanup stage string | Safety.Rev46.Tests.ps1 | KEEP |
| exposes the Rev4.7 stage string and sample schema | Safety.Rev47.Tests.ps1 | KEEP |
| exposes the Rev4.8 stage string and sample schema | Safety.Rev48.Tests.ps1 | KEEP |
| fails closed when the approval manifest is missing | Safety.Rev42.Tests.ps1 | KEEP |
| fails closed when the decommission plan is missing | Safety.Rev42.Tests.ps1 | KEEP |
| FinalDelete remains blocked by default | Safety.Rev43.Tests.ps1 | KEEP |
| keeps the controlled branch on the guarded production-readiness path | Safety.Rev49.Tests.ps1 | KEEP |
| keeps the entry point from exposing production readiness in default Assessment flow | Safety.Rev49.Tests.ps1 | KEEP |
| keeps the production readiness sample local only | Safety.Rev49.Tests.ps1 | KEEP |
| keeps the Rev4.5 controlled branch free of live Graph write/delete patterns | Safety.Rev45.Tests.ps1 | KEEP |
| keeps the Rev4.6 controlled branch free of live Graph write/delete patterns | Safety.Rev46.Tests.ps1 | KEEP |
| loads the additive controlled decommission module | Safety.Rev42.Tests.ps1 | KEEP |
| parses the entry point without syntax errors | Safety.Rev49.Tests.ps1 | KEEP |
| parses the Rev4.5 sample JSON | Safety.Rev45.Tests.ps1 | KEEP |
| parses the Rev4.6 sample JSON | Safety.Rev46.Tests.ps1 | KEEP |
| parses the Rev4.7 sample JSON and keeps it local-only | Safety.Rev47.Tests.ps1 | KEEP |
| parses the Rev4.8 sample JSON and keeps it local-only | Safety.Rev48.Tests.ps1 | KEEP |
| parses without errors | Safety.Rev42.Tests.ps1 | KEEP |
| places SelfTest before controlled decommission and Graph connection paths | Safety.Rev42.Tests.ps1 | KEEP |
| requires AllowFinalDelete for FinalDelete simulation | Safety.Rev43.Tests.ps1 | KEEP |
| requires WhatIfExecution or DemoMode | Safety.Rev42.Tests.ps1 | KEEP |
| requires WhatIfExecution or DemoMode before controlled processing | Safety.Rev43.Tests.ps1 | KEEP |
| retains a single ApprovalManifestPath parameter | Safety.Rev42.Tests.ps1 | KEEP |
| retains the controlled entry point before the execution flow | Safety.Rev49.Tests.ps1 | KEEP |
| sample Application readiness produces five local evidence files only | Safety.Rev44.Tests.ps1 | KEEP |
| sample FinalDelete invocation fails closed | Safety.Rev42.Tests.ps1 | KEEP |
| sample planner invocation succeeds without a Graph connection | Safety.Rev42.Tests.ps1 | KEEP |
| sample simulation produces local evidence and never reports mutation | Safety.Rev43.Tests.ps1 | KEEP |
| uses Rev4.10 tool version for centralized release-validation compatibility | Safety.Rev42.Tests.ps1 | KEEP |
| WhatIf source path contains no mutation cmdlet | Safety.Rev44.Tests.ps1 | KEEP |

## NhiRun4C

**Files:** NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1, NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1, NhiRun4CControlledRollbackPath.Rev420.Tests.ps1, NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1, NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1, NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1, NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1, NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1, NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1, NhiRun4CPostDisableObservation.Rev418.Tests.ps1, NhiRun4CPostRollbackValidation.Rev427.Tests.ps1, NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1

### SubSumed It-blocks (27 names appear in multiple files)

All 27 rows below: **KEPT SEPARATE - verified false positive.** Every occurrence was read in full and
found to invoke a different underlying `New-NhiRun4C*`/`Invoke-NhiControlledLab*` function per
revision (same `It` name reused across per-Rev files, different property/function actually under
test - e.g. "Package writes JSON artifact locally" checks 9 different artifact-id properties across
its 9 files). Merging any of these would have silently dropped real coverage. None were merged;
all 230 original test executions are preserved verbatim in `tests/NhiRun4C.Consolidated.Tests.ps1`.

| It-name | Files (and their counts) | Rev-decls | Verdict |
|---|---|---|---|
| App role assignment count changed returns Failed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Credential change request is blocked | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Credential count changed returns Failed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Credential deletion request is blocked | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1], NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Delete observed returns Failed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Delete request is blocked | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| EvidenceOnly target is blocked | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1], NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 [1], NhiRun4CPostDisableObservation.Rev418.Tests.ps1 [1], NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 [1] | 5 | KEPT SEPARATE - different function |
| ExternalVendorPlatform target is blocked | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Final delete request is blocked | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1], NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 [1] | 3 | KEPT SEPARATE - different function |
| Grant cleanup observed returns Failed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Grant cleanup request is blocked | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1], NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 [1] | 4 | KEPT SEPARATE - different function |
| Metadata cleanup request is blocked | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1] | 3 | KEPT SEPARATE - different function |
| MicrosoftPlatform target is blocked | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1], NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1], NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 [1], NhiRun4CPostDisableObservation.Rev418.Tests.ps1 [1], NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 [1] | 6 | KEPT SEPARATE - different function |
| Missing original disable evidence returns NotReady | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Missing pre-action snapshot returns Incomplete | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Missing rollback drill package returns NotReady | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1], NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 [1] | 3 | KEPT SEPARATE - different function |
| Missing rollback preview package returns NotReady | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Missing rollback readiness package returns NotReady | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| OAuth grant count changed returns Failed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Owner count changed returns Failed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Package does not execute rollback | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different property (RollbackPerformed vs RollbackPerformedByThisPackage) |
| Package does not perform delete or final delete | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Package states TenantWritePerformed=false, DisablePerformed=false, RollbackPerformed=false, FinalDeleteAllowed=false | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 [1], NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function (FinalGoNoGoReview vs RollbackExecutionReadiness) |
| Package writes JSON artifact locally | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1], NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 [1], NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 [1], NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 [1], NhiRun4CPostDisableObservation.Rev418.Tests.ps1 [1], NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 [1], NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 [1] | 9 | KEPT SEPARATE - 9 different functions, 9 different artifact-id properties |
| Recreate request is blocked | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1] | 2 | KEPT SEPARATE - different function |
| Remove request is blocked | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 [1], NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1] | 3 | KEPT SEPARATE - different function |
| Suppressed target is blocked | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 [1], NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 [1], NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 [1], NhiRun4CPostDisableObservation.Rev418.Tests.ps1 [1], NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 [1] | 5 | KEPT SEPARATE - different function |

### Unique It-blocks (153 names, one file each)

| It-name | File | Verdict |
|---|---|---|
| AppId changed returns Failed | NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 | KEEP |
| Bundle contains consultant summary | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Bundle contains no secrets or live credentials | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Bundle states no tenant write by bundle | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Complete approved dev/test lab target returns Go with RequiredHumanDecision=true and HumanDecisionCaptured=false | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Complete approved dev/test rollback inputs return Ready with RequiredHumanDecision=true and HumanDecisionCaptured=false | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Complete approved dev/test target creates evidence capture package | NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 | KEEP |
| Complete approved dev/test target creates observation package | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Complete artifact chain creates final controlled disable test package | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Complete artifact chain creates final evidence bundle | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Complete artifact chain generates rehearsal report | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Complete clean post-disable evidence returns Passed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| Complete clean rollback evidence returns Passed | NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 | KEEP |
| Complete rollback artifact chain creates rollback execution test package | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 | KEEP |
| Complete rollback-ready dev/test target produces rollback preview package | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Credential change observed returns Failed | NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 | KEEP |
| Credential change request returns NotReady | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Credential deletion observed returns Failed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| Delete request returns NotReady | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Enabled state not restored returns Failed | NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 | KEEP |
| EvidenceOnly=true returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| EvidenceOnly=true target is blocked | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Expected account-enabled change not observed returns Failed | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| Expired approval returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| ExternalVendorPlatform target returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| FirstPartyMicrosoftApp boolean target with CustomerOwned classification is blocked | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| FirstPartyMicrosoftApp boolean target with CustomerOwned classification returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Grant cleanup request returns NotReady | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Guide contains no live credentials | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide contains no secrets | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide contains no tokens | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide does not emit executable delete command | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide does not emit executable final delete command | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide includes client-safe narrative | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide includes executive summary | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide includes required artifacts | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide includes roles and responsibilities | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide includes runbook phases | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide includes safety boundaries | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide includes scope | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide includes title | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide states Microsoft/platform identities are evidence-only | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide states no final delete | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide states no production tenant write | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide states one approved lab NHI only | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide states rollback requires separate approval | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Guide writes Markdown artifact locally | NhiRun4CConsultantOperatingGuide.Rev423.Tests.ps1 | KEEP |
| Human go/no-go is required and not auto-captured | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Human rollback approval required and not auto-captured | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 | KEEP |
| InformationOnly boolean target is blocked | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| InformationOnly boolean target returns NoGo even when RemediationMode is ManualApprovalRequired | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| InformationOnly target is blocked | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Live command block is emitted only as a template and is marked DO NOT RUN | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| MicrosoftPlatform boolean target with CustomerOwned classification is blocked | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| MicrosoftPlatform boolean target with CustomerOwned classification returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| MicrosoftPlatform target returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Missing approval manifest returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Missing approval manifest returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing consultant guide returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing dry-run package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing dry-run package returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Missing dry-run package returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing evidence capture package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing evidence capture package returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing execution evidence returns Incomplete | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| Missing final delete simulation package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing go/no-go package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing go/no-go package returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing human rollback approval remains preview-only and not executed | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Missing lab/dev-test marker returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Missing monitoring owner fails closed | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Missing observation failure or manual trigger returns NotReady | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Missing observation package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing observation package returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing observation plan returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Missing observation result returns Incomplete | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| Missing observation trigger returns NotReady | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 | KEEP |
| Missing observation window fails closed | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Missing original disable evidence fails closed | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Missing post-action snapshot returns Incomplete | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| Missing post-disable validation package returns NotReady | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 | KEEP |
| Missing post-rollback snapshot returns Incomplete | NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 | KEEP |
| Missing pre-action snapshot fails closed | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Missing pre-action snapshot returns NotReady | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Missing readiness package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing readiness verdict returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Missing readiness verdict returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing rehearsal report returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing Rev4.24 package makes chain incomplete | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Missing Rev4.25 package makes chain incomplete | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Missing Rev4.26 package makes chain incomplete | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Missing Rev4.27 package makes chain incomplete | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Missing rollback contact fails closed | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Missing rollback drill package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing rollback execution evidence returns Incomplete | NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 | KEEP |
| Missing rollback package returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Missing rollback preview package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing rollback readiness package fails closed | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Missing rollback readiness package makes report Incomplete | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Missing rollback trigger fails closed | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Missing snapshot returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Missing snapshot returns NotReady | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Missing target returns fail-closed package or throws controlled error | NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 | KEEP |
| More than one target returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Non-reenable rollback action returns NotReady | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Non-reversible approved action returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| ObjectId changed returns Failed | NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 | KEEP |
| Observation failure triggers RollbackRecommended=true | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| Optional Markdown artifact writes if implemented | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Optional Markdown writes if implemented | NhiRun4CFinalEvidenceBundle.Rev428.Tests.ps1 | KEEP |
| Package declares TenantWritePerformed=false and DisablePerformed=false | NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 | KEEP |
| Package declares TenantWritePerformed=false and RollbackPerformed=false | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Package declares TenantWritePerformed=false, DisablePerformed=false, RollbackPerformed=false | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Package includes failure criteria | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Package includes monitoring owner | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Package includes observation window | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Package includes rollback contact | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Package includes rollback trigger criteria | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Package includes success criteria | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Package requires exactly one target | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Package requires execution evidence placeholders | NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 | KEEP |
| Package requires post-action evidence placeholders | NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 | KEEP |
| Package requires pre-action snapshot | NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 | KEEP |
| Package states observation only and no tenant mutation | NhiRun4CPostDisableObservation.Rev418.Tests.ps1 | KEEP |
| Package states prohibited changes for grants, credentials, owners, metadata, service principal deletion, application deletion | NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 | KEEP |
| Package states RollbackPerformed=false | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 | KEEP |
| Package states TenantWritePerformed=false | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| Package states TenantWritePerformed=false and DisablePerformed=false | NhiRun4CFinalControlledDisableTestPackage.Rev424.Tests.ps1 | KEEP |
| Package states WhatChanged = AccountEnabled only | NhiRun4CLiveEvidenceCapture.Rev417.Tests.ps1 | KEEP |
| Readiness verdict Ready=false returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Recreate observed returns Failed | NhiRun4CPostRollbackValidation.Rev427.Tests.ps1 | KEEP |
| Recreate request returns NotReady | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Remove request returns NotReady | NhiRun4CRollbackExecutionReadiness.Rev419.Tests.ps1 | KEEP |
| Report states DeletePerformed=false | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Report states DisablePerformed=false | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Report states FinalDeleteAllowed=false | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Report states RollbackPerformed=false | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Report states TenantWritePerformed=false | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Report writes JSON artifact locally | NhiRun4CEndToEndLabRehearsalReport.Rev422.Tests.ps1 | KEEP |
| Requested credential deletion returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Requested final delete returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Requested grant cleanup returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Requested metadata cleanup returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Requested remove returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| Rollback action other than re-enable is blocked | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Rollback action other than re-enable returns NotReady | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 | KEEP |
| Rollback is not executed by tests | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Rollback live command block is emitted only as a template and marked DO NOT RUN | NhiRun4CControlledRollbackExecutionTestPackage.Rev426.Tests.ps1 | KEEP |
| Rollback readiness NotReady fails closed | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| Rollback trigger detected returns RollbackRecommended=true | NhiRun4CPostDisableEvidenceValidation.Rev425.Tests.ps1 | KEEP |
| SuppressCustomerRemediation=true returns NoGo | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |
| SuppressCustomerRemediation=true target is blocked | NhiRun4CControlledRollbackPath.Rev420.Tests.ps1 | KEEP |
| writes JSON artifact locally | NhiRun4CFinalGoNoGoReview.Rev416.Tests.ps1 | KEEP |

## NhiControlledDecommission.Rev4x

**Files:** NhiControlledDecommission.Rev42.Tests.ps1, NhiControlledDecommission.Rev43.Tests.ps1, NhiControlledDecommission.Rev44.Tests.ps1, NhiControlledDecommission.Rev45.Tests.ps1, NhiControlledDecommission.Rev46.Tests.ps1, NhiControlledDecommission.Rev47.Tests.ps1, NhiControlledDecommission.Rev48.Tests.ps1, NhiControlledDecommission.Rev49.Tests.ps1

### SubSumed It-blocks (14 names appear in multiple files)

| It-name | Files (and their counts) | Rev-decls | Verdict |
|---|---|---|---|
| blocks <Name> | NhiControlledDecommission.Rev43.Tests.ps1 [1], NhiControlledDecommission.Rev44.Tests.ps1 [1], NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1], NhiControlledDecommission.Rev47.Tests.ps1 [1], NhiControlledDecommission.Rev49.Tests.ps1 [1] | 6 | KEPT SEPARATE - each is a distinct `-ForEach` against a different gate (SP-FinalDelete, App-readiness, Metadata-cleanup, Grant-cleanup, ManagedIdentity-readiness, ProductionReadiness) |
| blocks approval action missing | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1], NhiControlledDecommission.Rev47.Tests.ps1 [1] | 3 | KEPT SEPARATE - different private gate function per rev, different Plan/Approval field names |
| blocks approval id missing | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1] | 2 | KEPT SEPARATE - different private gate function per rev |
| blocks approval not approved | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1] | 2 | KEPT SEPARATE - different private gate function per rev |
| blocks approval target mismatch | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1] | 2 | KEPT SEPARATE - different private gate function per rev |
| blocks approval type mismatch | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1] | 2 | KEPT SEPARATE - different private gate function per rev |
| blocks snapshot mismatch | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1] | 2 | KEPT SEPARATE - different private gate function per rev |
| contains no secret-like values or delete cmdlet names | NhiControlledDecommission.Rev43.Tests.ps1 [1], NhiControlledDecommission.Rev44.Tests.ps1 [1], NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1], NhiControlledDecommission.Rev47.Tests.ps1 [1], NhiControlledDecommission.Rev48.Tests.ps1 [1] | 6 | MERGED - byte-identical 2-line check against each rev's own sample file; collapsed into one `-ForEach` (Rev4.7/4.8 correctly kept their wider `...\|Remove-Az` delete-pattern per-case, not backported/narrowed) |
| exists and parses as JSON | NhiControlledDecommission.Rev43.Tests.ps1 [1], NhiControlledDecommission.Rev44.Tests.ps1 [1] | 2 | MERGED - byte-identical `Should -Not -BeNullOrEmpty` check against two different sample files; collapsed into one `-ForEach` |
| keeps post-cleanup validation simulated or not run only | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1] | 2 | KEPT SEPARATE - different private gate function per rev |
| keeps the private evaluator hidden and export contract frozen | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1], NhiControlledDecommission.Rev47.Tests.ps1 [1] | 3 | KEPT SEPARATE - different private gate function per rev |
| satisfies readiness only as simulation when every gate passes | NhiControlledDecommission.Rev44.Tests.ps1 [1], NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1], NhiControlledDecommission.Rev47.Tests.ps1 [1] | 4 | KEPT SEPARATE - different private gate function per rev |
| supports DemoMode readiness simulation only | NhiControlledDecommission.Rev44.Tests.ps1 [1], NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1], NhiControlledDecommission.Rev47.Tests.ps1 [1] | 4 | KEPT SEPARATE - different private gate function per rev |
| supports WhatIf readiness simulation only | NhiControlledDecommission.Rev45.Tests.ps1 [1], NhiControlledDecommission.Rev46.Tests.ps1 [1], NhiControlledDecommission.Rev47.Tests.ps1 [1] | 3 | KEPT SEPARATE - different private gate function per rev |

### Unique It-blocks (172 names, one file each)

| It-name | File | Verdict |
|---|---|---|
| advertises the Rev4.9 schema contract | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| allows an explicitly approved scream-test override | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| allows explicitly approved active credential override | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| allows explicitly approved scream-test override | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| binds approval and plan to the same RunId and target | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks <Name> through target validation | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| blocks active and ambiguous targets | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks approval id mismatch | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| blocks approval metadata mismatch | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| blocks approval related mismatch | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| blocks break-glass target | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks critical dependency and recent activity | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks emergency target | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks exact target binding missing | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| blocks expired approval | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks FinalDelete even when approval includes it | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks FinalDelete for WhatIf Demo and live-mode plan requests | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks FinalDelete in all S1 plans | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks managed identity approval type mismatch | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| blocks managed identity type mismatch | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| blocks Microsoft first-party target | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks missing approver and non-approved status | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks missing ObjectId | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks missing snapshot | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| blocks multi-tenant and live delete defaults | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| blocks permission name mismatch | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| blocks plans for protected targets | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks principal mismatch | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| blocks protected target | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks readiness when FullPesterEvidence is explicitly failed | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| blocks resource app mismatch | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| blocks RunId mismatch unless reusable | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks schema mismatch | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks scope mismatch | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| blocks target and action mismatches | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| blocks target mismatch | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| blocks unattended non-WhatIf non-Demo requests | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| blocks unresolved P0 findings | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| blocks unresolved P1 findings | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| blocks unsupported user target | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| builds a blocked gate when the input is empty | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| builds a QA handoff manifest with the required fields | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| builds a ready-for-review gate with complete local evidence | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| builds an operator decision log with the required fields | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| builds metadata cleanup plan and action log objects | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| captures credential metadata and owner evidence in the sample | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| captures evidence pack input identity and counts | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| captures exact related-object evidence in the sample | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| captures managed identity evidence in the sample | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| captures publisher and ownership evidence | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| changes when input changes | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| classifies a user-assigned managed identity | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| classifies an unknown managed identity type | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| classifies evidence-only rollback limitation | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| classifies limited rollback limitation | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| classifies managed identity type from the plan | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| classifies not available rollback limitation | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| classifies reversible rollback limitation | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| contains a blocked FinalDelete action in the plan sample | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| contains clean relationship evidence | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| contains exact Application FinalDelete approval | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| contains exact FinalDelete approval | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| contains no Graph request calls | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| contains no live Graph write/delete cmdlet references | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| contains no prohibited Graph delete cmdlet names | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| contains no secret token or certificate values | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| contains test-tenant guard metadata | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| creates planning-only snapshot plan | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| creates rollback plan linked to snapshot hash | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| creates versioned snapshot with hash | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| exports the production readiness evidence pack through the entry point | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| exports the required public functions and keeps private helpers hidden | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| exports UTF-8 JSON evidence | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| fails closed from the entry point when system-assigned parent evidence is missing | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| fails closed from the entry point when user-assigned attachment evidence is missing | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| fails closed to Unknown when query failed | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| fails closed when dependency query fails | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| fails closed when the production readiness plan omits FullPesterEvidence | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| fails closed when the production readiness plan omits Rev42PlannerEvidence | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| generates grants cleanup plan and action log objects | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| imports successfully | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| includes both required sample files | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| includes owner evidence and rollback limitation in the inventory | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| includes the known warning list and simulation-only evidence state | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| is deterministic | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| is ServicePrincipal-only | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| keeps approval sample evidence-only | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| keeps default Assessment out of the controlled readiness path | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| keeps live execution flags false in the final safety assertions | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| keeps live mutation and delete disabled | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| keeps plan sample WhatIf Demo and planning-only | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| keeps production unlock disabled | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| keeps readiness simulation-only and non-executable | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| keeps SelfTest before the controlled Graph connection path | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| keeps simulation-only flags false for live execution | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| keeps the approval target object ids stable in the sample | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| keeps the evaluator private and public export contract frozen | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| keeps the merge gate documentation-only | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| keeps the private builders hidden and exports the required public contract | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| keeps the private helpers hidden and exports the required public contract | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| keeps the Rev4.3 gate evaluator private to preserve the frozen public contract | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| keeps the safety assertions false for live execution | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| keeps the sample free of secret-like fields and live delete commands | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| lists FinalDelete but blocks live mutation | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| marks production execution as disabled even when review-ready | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| never enables Application deletion when every gate passes | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| never enables FinalDelete in plan readiness evidence | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| never enables live delete when all gates pass | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| never enables live FinalDelete | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| never enables live grant cleanup when every gate passes | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| never enables live metadata cleanup when every gate passes | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| normalizes missing evidence to incomplete statuses | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| normalizes the sample warning inventory | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| parses both samples as valid JSON | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| parses the E2E sample JSON | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| parses the grants cleanup sample JSON | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| parses the managed identity sample JSON | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| parses the metadata sample JSON | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| parses the production readiness sample JSON | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| passes a supported unprotected target | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| passes clean dependency evidence | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| passes exact valid approval | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| passes the entry point when supplied managed identity evidence is present | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| passes with a user-assigned attachment and parent evidence present | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| passes with system-assigned parent evidence present | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| preserves approval target object ids and readiness contract fields | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| preserves non-sensitive target state | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| preserves the QA handoff evidence artifact list | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| produces evidence-only WhatIf and Demo plans | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| produces managed identity plan and action log objects | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| produces sanitized credential inventory evidence | NhiControlledDecommission.Rev45.Tests.ps1 | KEEP |
| produces the expected release manifest and merge gate states | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| records operator merge decision without executing it | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| records the expected branch and commit in the release manifest | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| records the expected branch, commit, and local-only evidence flags | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| records the known warning inventory with severity and disposition | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| redacts nested secrets in AdditionalProperties | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| rejects sample approval for FinalDelete | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| removes secret and token properties | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| reports summary field <Name> | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| reports the snapshot hash from the pack | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| reports validation result fields individually | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| requires explicit status normalization for missing text | NhiControlledDecommission.Rev47.Tests.ps1 | KEEP |
| requires external QA approval evidence | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| requires frozen-file diff evidence | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| requires full Pester evidence | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| requires git status evidence | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| requires P2 findings to be documented with disposition | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| requires safety scan evidence | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| retains credential metadata only | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| returns 64 lowercase hexadecimal characters | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| returns Active before window completes | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| returns Blocked for dependency or recent activity | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| returns Complete after window completes | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| returns Ready only when every gate passes | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| returns target counts by type from the module helper | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| returns the expected dependency recheck statuses | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| returns the expected post-cleanup validation states | NhiControlledDecommission.Rev46.Tests.ps1 | KEEP |
| returns the required final safety assertions | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| satisfies gates only as simulation when all required inputs pass | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| sets live-delete and live-cleanup flags false | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| summarizes approval coverage, snapshot coverage, and scream-test status | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| summarizes dependency recheck, delete readiness, and cleanup readiness | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| summarizes rollback limitation and validation results | NhiControlledDecommission.Rev48.Tests.ps1 | KEEP |
| supports DemoMode simulation only through the entry point | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |
| supports DemoMode simulation without live delete | NhiControlledDecommission.Rev43.Tests.ps1 | KEEP |
| supports only NHI target types | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| targets an Application | NhiControlledDecommission.Rev44.Tests.ps1 | KEEP |
| uses Rev4.2 schema in both samples | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| uses schema version 4.2 | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| validates sample approval for DeleteReadinessOnly | NhiControlledDecommission.Rev42.Tests.ps1 | KEEP |
| writes JSON artifacts that parse cleanly | NhiControlledDecommission.Rev49.Tests.ps1 | KEEP |

