# Final Pending-Approval Plan — Solo Gameplay/UI/UX RT1 (Stage 5)

## Status
**PENDING USER APPROVAL. EXECUTION HAS NOT STARTED.** This is the self-contained execution-handoff plan derived from clean pass 5 (SHA-256 `3da0dc25fe2a8d35a355b0e0c34e1225b8fa125751e9660dba07827a1a58c078`), the confirmed interview decision, Architect `CLEAR/APPROVE`, and Critic `OKAY`.

## Summary
Deliver one bounded Release Train 1 (RT1): a polished solo keyboard/mouse first 20 minutes from New World through onboarding, eating, gathering the complete canonical material budget, crafting/equipping a hammer, building a campfire-anchored shelter, receiving Rested, defeating one Greyling, and save/reload. The release is a visible bilingual gameplay/UI/UX overhaul with responsive feedback and objective evidence.

RT1 supports offline and host-local authoritative building only. Every remote placement, removal/refund, and mutating build-piece interaction must fail before inventory/world mutation with `REJECTED/UNSUPPORTED_IN_RT1`. Host-to-client piece snapshots/events remain read-only authority projection, never a client mutation path. Durable remote identity, credentials, authoritative remote inventory, session epochs, replay/outcome retention, capacity/backpressure, retry semantics, trusted movement, and remote builds move together to MAR1.

RT1 repairs touched local contracts: durable one-slot local world/player identity, separate world/onboarding/profile/presentation authority, one interaction-mode writer, transactional save/settings/onboarding I/O, semantic onboarding events, atomic local placement, and a host/offline raid mutation guard. Estimated effort is 14–20 engineer-days plus 3 moderated playtest days, subject to Phase-0 revalidation. Do not pull deferred scope forward.

## Intent Reconciliation
### Confirmed decision
Prioritize the polished **solo keyboard/mouse first 20 minutes**. **Multiplayer, controller support, and late-game content are follow-up goals.**

### Applied interpretation
- The solo/offline or host-local first-session chain is the release target and receives the quality, accessibility, safety, and evidence budget.
- Multiplayer remains fail-closed. RT1 may explain that remote building is unavailable but must not claim multiplayer gameplay support. MAR1 owns the complete remote-authority contract.
- Controller bindings, remapping, controller UI, and controller acceptance are deferred and must not be advertised.
- Late-game systems, additional biomes/bosses, full raid lifecycle, and progression beyond the prepared Greyling encounter are deferred.
- The prioritization does not weaken atomic placement, transactional persistence, duplicate-key rejection before parse, zero/positive evidence semantics, continuous Rested qualification, sole interaction ownership, or release evidence.
- No prior deep-interview specification was found, so this confirmed decision is the controlling reconciliation.

## Intent Diff
- Replace the earlier partial remote command design with coherent MAR1 deferral and exhaustive fail-closed RT1 guards.
- Preserve `_place_piece()` only as authority-to-client projection of already-authoritative state; rename/restrict `place_remote()` accordingly.
- Localize the visible limitation: `Remote building is unavailable in this release` / `이 릴리스에서는 원격 건축을 지원하지 않습니다`; show no pending/success state and spend nothing.
- Keep the starter grant unchanged but make it transactional and provenance-tagged. A zero hammer shortfall is possession/preparation and needs no gather event; every positive per-resource shortfall needs eligible amount-covering evidence.
- Campfire, not bed, anchors the shelter Rested milestone. Require five uninterrupted qualified seconds and reset on movement, range/shelter loss, damage, attack, or build.
- Reject duplicate JSON object keys through a bounded lexical scan before parser invocation, including escaped-key-equivalent duplicates.
- Implement local placement as detached candidate plus silent exact-material reservation and one guarded non-yielding commit; discard both on reserve/create/attach/evidence faults.
- Keep onboarding in a private transactional local store keyed by durable local IDs.
- Route `main.gd`, `ui_root.gd`, `net_probe.gd`, and `screenshot_director.gd` through one `InteractionModeController`.
- Limit raid work to host/offline mutation guard and remote reject/no-op.
- Keep `RecipeDB` canonical for costs and retain the one-slot identity boundary.

## Decision Drivers
1. Ship an accepted solo product slice rather than an incomplete remote security protocol.
2. Fail closed: no remote request may consume/refund inventory, create/destroy a host piece, advance progress, or produce false success.
3. Make the first-session economy feasible without changing starter contents or recipes.
4. Prevent loss, duplication, partial local success, corrupt persistence, and ambiguous UI feedback.
5. Maintain one mutation owner for each authority domain and interaction mode.
6. Reuse programmatic GDScript UI and native Godot entrypoints; add no dependency.
7. Decide completion with fixed fixtures, semantic screenshots, traces, fault injection, and fresh-player sessions.
8. Make duplicate handling and Rested timing deterministic.

Assumptions: desktop keyboard/mouse; Korean and English; existing programmatic UI; fixed save slot `world1`; starter grant club/10 wood/6 stone/5 raspberries; Greyling is the sole RT1 enemy; save `VERSION=1` remains only if additive fields validate safely. Online legacy observation/combat may remain but is outside RT1 acceptance except negative build/raid guards.

## ADR — DR-RT1-P5
### Decision
Ship a satisfying solo shelter/Greyling/save first-session slice with offline/host-local validated building. Fail closed on all remote build mutation and defer the complete remote-authority protocol to MAR1. Prioritize keyboard/mouse polish in the first 20 minutes; treat multiplayer, controller, and late game as follow-ups.

### Drivers
- Confirmed product priority is the polished solo keyboard/mouse first 20 minutes.
- Remote ownership, epoch/replay, bounded outcome retention, retry, and authoritative inventory cannot safely be implemented as isolated patches.
- Local placement, persistence, progression evidence, and interaction ownership are load-bearing correctness boundaries.
- The onboarding economy must use current canonical recipes and starter contents.
- Release claims need observable, reproducible evidence.

### Alternatives considered
- **Keep the earlier remote command protocol:** rejected because ownership, replay ordering, and ledger-full invariants remain unresolved and are unnecessary for solo acceptance.
- **Add credentials/epochs/ledgers now:** deferred because it creates account recovery, compatibility, storage, threat-model, and adversarial-test scope.
- **Silently ignore remote mutation:** rejected because it creates false feedback and unstable behavior.
- **Visual reskin only:** rejected because onboarding, authority, save, and feedback defects remain.
- **Increase starter grant:** rejected because it changes balance and masks gathering instruction.
- **Require gathering at zero shortfall:** rejected because it fabricates work/evidence.
- **Accumulate Rested across interrupted intervals:** rejected because invalid periods can carry progress.
- **Detect duplicate keys after parse:** rejected because parser normalization may already erase ambiguity.
- **Sequential consume/spawn placement:** rejected because faults expose partial inventory/world/evidence state.
- **Full raid lifecycle, controller, or late game now:** deferred because they do not serve the confirmed first-20-minute target.

### Why chosen
It is the smallest coherent release boundary that produces a polished, teachable, measurable solo experience without shipping partial authority or transactional semantics. It closes remote risk by removing the dependent capability, not by weakening invariants, and directs effort to the user-confirmed priority.

### Consequences
- Remote building is explicitly unavailable in RT1 and returns a stable localized rejection.
- RT1 makes no durable remote identity, epoch, replay, retry, capacity, or remote inventory claim.
- Local placement gains an explicit reservation/commit seam and fault-injection burden.
- Persistence gains bounded pre-parse duplicate detection and transactional replacement requirements.
- Controller, multiplayer breadth, full raid lifecycle, and late game are absent from release acceptance.
- Phase 0 must freeze platform/scanner/geometry/UI values before implementation.

### Follow-ups
- MAR1 must be separately approved with threat model, credential lifecycle, authoritative remote player/inventory, trusted movement, epoch/replay ordering, recordable capacity semantics, retry/reconnect/restart behavior, remote placement transaction, compatibility, adversarial evidence, migration, and rollback.
- A later controller release owns bindings/remapping/UI and its acceptance matrix.
- Late-game and full raid lifecycle receive separate progression/lifecycle plans.
- A future world manager must define multi-slot, copy, rename, delete, collision, and cross-install identity behavior.

## Options
| Option | Benefit | Cost/risk | Decision |
|---|---|---|---|
| Partial remote protocol | Potential remote builds | Unsafe unresolved authority semantics | Reject RT1 |
| Stable fail-closed remote guard | Safe and testable | Remote build unavailable | Choose |
| Solo contract-first loop | Coherent measurable release | Defers breadth | Choose |
| Full raid lifecycle | Richer online behavior | New persistence/network subsystem | Defer |
| Host/offline raid guard | Prevents remote mutation | Lifecycle remains follow-up | Choose |
| Zero-shortfall possession branch | Honest authoritative readiness | Explicit branch required | Choose |
| Continuous five-second Rested | Deterministic/readable | Central reset wiring | Choose |
| Bounded lexical duplicate scan | Rejects ambiguity before parse | Scanner corpus/bounds required | Choose |
| Detached candidate + reservation | All-or-nothing local result | Transaction seam required | Choose |

## In scope / out of scope
### In scope
- Clean and legacy-v1 `world1` new/continue/loading; additive durable local world/player IDs and deterministic one-slot migration.
- Persistent, skippable chain: orient/move; possess/eat food; gather outstanding canonical costs; craft/equip hammer; place campfire/workbench/six-piece shelter; receive Rested; prepare for/defeat Greyling; save/reload.
- Frozen costs: hammer 3 wood/2 stone; campfire 2 wood/5 stone; workbench 10 wood; one floor/three walls/two roofs 12 wood; total 27 wood/7 stone; nominal starter shortfall 17 wood/1 stone.
- Starter provenance, semantic event cursor, separate transactional onboarding store.
- One local placement validator and detached/reserved atomic placement transaction with reserve/create/attach/evidence fault seams.
- Exact campfire Rested predicate, five-second timer, resets, and one-shot emission.
- Bounded duplicate-aware lexical scan before parse.
- Remote build fail-closed UI/callsite/RPC behavior and two-process negative fixture.
- Bilingual HUD/objective/action/survival feedback; inventory/craft/build focus; 1280x720 and 1600x900 at 100% UI scale.
- Transactional world/settings/identity/onboarding persistence; locale, UI scale, Master/SFX/Ambient, sensitivity, invert Y, reduced shake.
- Host/offline raid guard; native pure/scene/two-process/visual/performance/moderated evidence.

### Out of scope
- MAR1 and every remote credential, inventory, command, epoch, replay, retry, capacity, prediction, placement/removal/refund, compatibility, or multiplayer-polish contract.
- Controller bindings/remapping/UI/acceptance; late game, new biomes/bosses; map, boats, fishing; full raid lifecycle; chat/status; broad inventory/container/tomb/death recovery.
- 1920x1080/2560x1080 and 125% UI-scale release matrix.
- World browser, duplicate/rename/delete/import, multiple slots, copied-save collision semantics, cross-install/account recovery.
- New content/art/dependencies, world-generation rewrite, economy rewrite, analytics transmission, or save-format rewrite.

## Authority and data contracts
### Identity and ownership
New worlds get persisted UUIDv4 `world_id`; `user://identity.json` gets UUIDv4 `local_player_id` before entry. Legacy `world_id` is deterministic UUIDv5 from namespace plus `world1:<seed>`; legacy player ID is UUIDv5 from namespace plus persisted installation ID. Repeat migration, restart, persisted-name change, missing installation ID, malformed/future data, interruption, and backup recovery need fixtures. IDs are never remote credentials.

World/pieces/enemies/local inventory are mutated only by offline or host-local authority and stored in transactional `world1`. `OnboardingStore` (`user://onboarding.json` keyed by world/player IDs), `IdentityStore`, and `SettingsStore` are private local owners. Presentation is memory-only. `InteractionModeController` is the sole interaction writer. `GameState` remains a world facade, not owner of private stores or transient UI.

Every JSON document follows: byte bound -> bounded lexical scanner with object scope/string/escape/array tracking and per-object key sets -> detached parse -> schema/migration/full validation -> one live apply. Reject malformed encoding/escapes, duplicate same-object keys, escaped-equivalent duplicates, bound exhaustion, future schema, non-finite values, and invalid enums/types without parser invocation or live mutation where applicable. Freeze depth/key-count/key-length/token/byte limits in Phase 0.

### Local placement transaction
`RecipeDB` owns piece definitions/costs. Remote callers return unsupported before local validation. Local dominant reason order is `UNKNOWN_PIECE > OUT_OF_RANGE > PIECE_LIMIT > MISSING_STATION > MISSING_MATERIALS > INVALID_WATER > INVALID_GROUND > OVERLAP > UNSUPPORTED_IN_RT1 > ACCEPTED` where applicable.

After validation, create a detached candidate outside scene/authoritative registries and acquire a silent exact-material reservation that changes no visible count, signal, dirty flag, revision, stat, or evidence. With both available, run one guarded non-yielding commit that attaches/registers the entity and commits inventory, world/inventory revisions, stats, onboarding evidence, and dirty state as one result. Emit consolidated piece/inventory/progress/success signals and SFX only after success. Any reserve/create/attach/evidence fault removes provisional attachment, discards candidate, cancels reservation, restores pretransaction revisions/stats/evidence/dirty state, emits exactly one failure and no success, and leaves no scene/physics/support/registry residue. Retry after clearing a fault succeeds once.

### Remote guard surfaces
1. `build_system.gd::try_place()` rejects remote before recipe validation, reservation, creation, attach, evidence, SFX, support work, or networking.
2. `try_remove()` rejects before lookup, destruction, refund, support, stats, or evidence.
3. Rename/restrict `place_remote()` to authority snapshot projection reachable only from authority-origin `_place_piece()`; it never consumes/refunds or advances authoritative evidence.
4. `net.gd::request_place()` and remove sender transmit nothing and return typed unsupported results.
5. Delete `_request_place()`/`_request_remove()` RPC exposure only with protocol-version proof; otherwise retain minimal reject-only sinks that reply and return without build-system, piece, inventory, stat, save, or broadcast calls.
6. Guard door, bed, container, cooking, smelting/kiln, crop, portal, and build-menu mutations in `BuildPiece.interact()`.
7. Reject remote invocation of authority `_place_piece()`; legitimate host projection changes only replicas.
8. Remote confirm shows one localized text+icon limitation, no pending ghost, success SFX, material delta, or objective advance.
9. Phase 0 inventories all spawn/place/remove/destroy/refund/interact callsites and routes any additional ingress to rejection or removal.

### Interaction, onboarding, Rested, persistence
Interaction priority is `DISCONNECTED > TRANSITION > DEATH > PAUSE > SETTINGS/HELP > CHAT > INVENTORY/CRAFT/BUILD_MENU > GAMEPLAY`. The controller alone writes input lock, offline tree pause, mouse mode, primary modal, focus stack, and held-item resolution. Online pause locks local gameplay without pausing the tree. Title hands the same controller to world UI. Same-frame priority and focus restoration are deterministic; no gameplay input leaks through modals; dev overrides are unavailable in release.

Starter delivery is a world transaction keyed `starter/v1/<world_id>/<local_player_id>`, persisted before inventory delivery and reconciled after interruption. Remove unconditional `_ready()` grants only after migration. Onboarding schema 1 stores objective version, monotonic cursor, completed IDs, skip state, and evidence IDs. Corruption recovers backup or restarts at earliest durable predicate with one warning and never changes world/inventory.

Resource rows recompute `shortfall=max(0, canonical remaining requirement-authoritative available inventory)` after prior spending. Zero hammer shortfall renders/completes as possession/preparation without gather evidence. Every positive per-resource amount requires authoritative inventory/spend predicate plus stable amount-covering `GATHER|PICKUP|DROP_RECOVERY` evidence; starter provenance never counts. Mixed rows waive evidence only for zero resources.

Shelter requires one owned campfire/workbench, connected floor/three walls/two roofs within 6 m of campfire, connected to nearest floor, and at least 4/5 upward rays from center plus four fixed 0.5 m offsets hitting connected owned roof. Rested advances only while alive, below frozen movement epsilon, within 3 m comfort range, and sheltered. Movement, range loss, shelter/comfort loss, damage, attack, or build immediately resets to zero; pause/loading/death do not advance. First crossing `<5.0` to `>=5.0` emits one stable `RESTED_APPLIED`; continued qualification and leave/re-enter after completion do not duplicate. Generic comfort and split intervals do not count.

World/settings/identity/onboarding writes use same-volume `.tmp`, flush/close, pre-scan plus reparse/validate, valid-current rotation to `.bak`, then the Phase-0-selected Windows atomic replacement primitive. Failure preserves a valid current or backup. Writers activate last. Settings apply live with channel isolation and one reduced-shake setting across all inventoried writers. Rollback disables writers first, retains additive readers/files and immutable fixtures, and never restores unsafe remote requests or unconditional starter grants.

## File-level changes
| Owner | Files/contracts | Change |
|---|---|---|
| Architect (2d) | contracts, fixtures, diagrams | Freeze authority, rejection, identity, evidence, Rested, scanner, transaction, interaction, persistence, UI, and MAR1 contracts |
| Core/state (3–4d) | `game_state.gd`, `save_system.gd`, identity/settings/onboarding stores/events | Add IDs, scanner, detached migration, transactional stores, grant/cursor |
| Network/build (2–3d) | `net.gd`, `build_system.gd`, `build_piece.gd`, `inventory.gd` | Disable unsafe requests, reject-only sinks, authority projection, silent reservation/atomic local placement, remote guards |
| Interaction/UI (3–4d) | controller, `ui_root.gd`, `main.gd`, `hud.gd`, inventory/craft/build/theme | Sole interaction owner, title handoff, responsive bilingual UX, limitation/reason/focus feedback |
| Progression (2–3d) | `player.gd`, objectives, `loc.gd`, `recipe_db.gd`, gather/rest/enemy adapters | Canonical costs, evidence semantics, provenance, exact Rested state machine, Greyling chain |
| Settings/audio (1–2d) | `sfx.gd`, `main.gd`, `player.gd`, shake sites, `project.godot`/bus artifact | Bus isolation, sensitivity/invert, reduced shake, live application |
| World/gameplay (1d) | `spawn_manager.gd`, `enemy.gd` | Host/offline raid guard; Greyling event/fixture |
| Tools/QA (3–4d) | `net_probe.gd`, `screenshot_director.gd`, native adapters/manifests | Typed dev requests, two-process negative tests, scanner/fault/Rested/objective fixtures, captures/traces |
| Docs (0.5d) | `README.md` | Solo scope, remote limitation, controls/settings/evidence guidance, deferrals |

Shared-file order: Core additive readers/stores; Network/build guards and transaction; Progression inventory/player adapters; Settings/audio player/main pass; Interaction controller and final main/UI cutover; Tools dev cutovers; world guard/docs. One owner per shared file; no parallel edits or dead aliases.

## Sequencing and dependencies
### Phase 0 — Contract freeze (2 days)
Freeze baseline; exhaustive remote ingress matrix; reject-only RPC/version choice; typed result/copy; identity schema/migration; exact cost/objective/evidence table; Rested transition/reset table; scanner grammar/bounds; placement transaction state diagram/fault seams; shelter geometry; interaction/handoff table; persistence schemas/bounds; Windows replacement primitive; audio/UI-scale/shake design; wireframes; performance markers; screenshot assertions; playtest rubric; owner/approvers; MAR1 contract.

**Exit:** Architect, network, core, UI, QA, and Maintainer approve artifacts; remote requests cannot reach mutation; costs equal 27 wood/7 stone; evidence branches are exact; Rested is continuous five seconds with six resets; duplicates reject before parse; placement diagram proves no visible precommit effect; one-slot migration inputs exist; Windows spike preserves valid data; estimates are reaffirmed/revised. Stop on any unresolved authority, atomicity, pre-parse, authoritative-reset, or replacement blocker.

### Phase 1 — Safety foundations (5–7 days)
Land additive IDs/readers/stores/scanner; remote rejections and projection split; local transaction/fault seams; interaction controller/cutovers; settings/audio substrate; native seams; raid guard. Activate writers last.

**Exit:** IDs are stable; duplicates never reach parser/apply; normal/forged remote mutations change zero host state; local placement mutates once; each injected fault restores exact hashes and leaves no orphan/signal; interruption recovery passes; one interaction writer remains; no remote mutation path or client raid spawn exists.

### Phase 2 — Gameplay/UI/UX loop (5–7 days)
Wire gathering, starter provenance, eat/craft/equip, campfire/workbench/shelter/Rested, Greyling, save/reload, settings, and bilingual responsive UI. No MAR1/controller/late-game work.

**Exit:** clean/legacy fixtures pass both resolutions/locales; positive shortfalls require evidence and zero hammer shortfall does not; one uninterrupted qualified interval alone emits Rested once; every reset zeros timing; cursors reload monotonically; no duplicate grants/messages; focus/action/survival/save feedback works; remote limitation is clear with no false success.

### Phase 3 — Evidence/release (3 QA days)
Run automated suites, 52-shot manifest, accessibility review, measured traces, moderated sessions, rollback/save rehearsal, placement faults, scanner corpus, and two-process negative tests. Fix only RT1 failures.

**Exit:** every acceptance item passes and Maintainer signs go/no-go. Data loss/duplication, remote mutation, partial local side effects, parser duplicate acceptance, incorrect evidence/Rested behavior, false success, interaction ownership, clipping/accessibility, or solo-loop failure blocks release.

## Acceptance criteria
### Authority and transactions
- Successful local placement creates/commits exactly one piece and exact material/revision/stat/evidence deltas, publishing only postcommit.
- Every validation or reserve/create/attach/evidence failure leaves inventory, scene/physics/registry/support graph, dirty/revisions, stats, evidence, replication, and success feedback unchanged; cleared retry succeeds once.
- Two-process normal/direct/forged/replayed/malformed/out-of-range/unknown/burst placement, removal/refund, representative interaction, and authority-RPC spoof all return unsupported and preserve host/client hashes through drain and reload. Legitimate host projection replicates once without client spend or remote-success semantics.
- Remote UI shows one localized non-color limitation and no pending/success feedback or progression.

### Identity, progression, Rested, interaction, raid
- UUIDv4 new IDs and deterministic UUIDv5 legacy migration remain stable across repeats, restart, and persisted-name change; interruption recovers; IDs make no authentication claim.
- Canonical cost fixture proves 27 wood/7 stone and every outstanding acquisition is taught.
- Zero hammer shortfall completes by possession without synthetic gathering. Each positive/mixed resource requires eligible evidence covering only positive amounts plus authoritative predicate. Starter events never satisfy positive gathering.
- Starter delivery occurs exactly once across create/load/interruption.
- Shelter ownership/connectivity/distance/rays and player qualification must all pass. No event at 4.999 seconds; first 5.0 crossing emits once. Each of movement, range loss, shelter/comfort loss, damage, attack, and build resets immediately; split intervals, generic comfort, continued qualification, and re-entry do not duplicate/advance incorrectly.
- Cursor/evidence are monotonic and idempotent; skip is local/persistent and non-mutating.
- The interaction controller is the only production writer, including title/world and dev automation. Priority pairs leak no gameplay input; release cannot invoke dev override.
- Raid RNG/eligibility/spawn is host/offline only; remote invocation rejects/no-ops.

### Persistence and settings
- Onboarding exists only in its private local file keyed by IDs and survives restart; corruption/recovery never mutates world/inventory.
- Same-object top-level/nested/escaped-equivalent duplicates reject before parser; keys in distinct objects may repeat. Scanner bounds and malformed cases terminate deterministically without unbounded work/live mutation.
- Clean/v1/missing-additive/corrupt/future/oversize/non-finite/duplicate/temp-interrupted/backup fixtures leave sentinel state unchanged on failure and recover complete old or new bytes, never hybrids.
- Settings apply live; Master affects both channels, SFX/Ambient isolate, sensitivity/invert reach player control, reduced shake covers every inventoried source, and UI scale uses one root/theme path.
- Rollback preserves saves, IDs, onboarding, settings, fixtures, and fail-closed behavior.

### UX, performance, and moderated outcome
- At 1280x720 and 1600x900, KO/EN, 100%: safe margins >=24/32 px; centered 240x160 reticle exclusion; no critical overlap; scrolling instead of undersized body text; normal contrast >=4.5:1 and large/non-text >=3:1; focus/validity/status/limitation have non-color cues.
- Windows 11 reference hardware release build: after 30-second warm-up, 200 local actions have first-rendered-feedback P95 <=100 ms and none >150 ms; 200 local unsupported confirmations have rendered rejection P95 <=100 ms, with host round trip separately reported; fixed 120-second combat trace has frame P95 <=16.67 ms and P99 <=25 ms.
- Fresh N=10: >=8 finish and identify save/continue within 20 minutes, >=8 explain next action/purpose, >=7 survive Greyling, median encounter 20–60 seconds, median longest confusion <=90 seconds. Returning N=5 all continue without duplicate grant/reward and find Help. Moderator gives no hint for 120 seconds, codes interventions, and independent blinded review resolves disagreements.

## Verification
Planning makes no product edits and runs no tests/gates/formatters. After approved implementation, executors use native Godot import/parse, pure, scene, two-process seed-12345 negative, visual capture, performance trace, and fixed-seed manual smoke entrypoints. No addon is introduced.

## Escalation/Risk Gate
Maintainer + Architect approval is required to increase save version, change serialized meaning, starter contents/recipes/combat, evidence or Rested rules, scanner bounds/pre-parse rejection, placement atomicity, dependencies/controller/world generation, any remote mutation support, reject-sink removal without version proof, MAR1/raid lifecycle, baselines, or deferred scope. Data loss/duplication, remote-to-host mutation, visible precommit side effects, false remote success, duplicate input reaching parse, non-atomic migration, or a second interaction writer is a hard block.

Execution handoff after approval: bounded Executors by owner; Architect for authority/Windows/schema/atomic-commit decisions; Critic at phase exits; Team for Phase-1 shared-file integration; Ultragoal only for explicitly expanded cross-phase/MAR1 scope.

## Verification Plan
### Automated
- **Pure:** identity lifecycle; scanner corpus/every bound; schemas; local validator/reason precedence; placement commit/four rollback invariants; exact costs; zero/positive evidence; objective ordering/reload/skip; shelter/rays; Rested threshold/resets/one-shot; store recovery; interaction transitions; settings; typed unsupported result.
- **Scene:** starter interruption; evidence variants; gather/eat/craft/equip; local build reasons/faults/retry; remote-disabled presentation; Rested 4.999/5.0, each reset, split intervals, duplicate suppression, generic-comfort negative; Greyling; title handoff/focus; KO/EN; every-cursor reload.
- **Two-process:** normal/direct/forged/replayed/malformed/burst placement; remove/refund; representative interaction; authority spoof; before/after state hashes; legitimate projection; client raid no-op. No epoch/replay/capacity fixture.
- **Visual:** 13 semantic states x 2 resolutions x 2 locales = 52 PNGs, with safe-margin, reticle, font, truncation, focus, contrast, semantic-key, and expected-state assertions.

### Fixed fixture and evidence
Seed 12345; recorded Meadows location/hash; noon/clear/no raid; exact starter grant; one 20-HP Greyling 12 m from shelter after Rested; no debug buffs. Manifest records build/schema/Godot/profile/fixture/seed/location/state/assertions/locale/resolution/scale/input/time/weather/injections/hashes/timestamp. Release packet contains approvals, reports, scanner corpus, transaction hashes/signal trace, Rested trace, evidence report, two-process traces/hashes, rollback rehearsal, 52 images, contrast/accessibility sign-off, anonymized playtest aggregates, deferred list, MAR1 contract, and Maintainer receipt.

## Risks and mitigations
- **Missed remote ingress:** exhaustive sender/receiver and spawn/destroy/refund/interact inventory; reject-only handling; adversarial hashes and burst test.
- **Projection mistaken for authority:** rename/restrict API, authority RPC checks, and assert no inventory/stat/evidence effects.
- **Placement rollback leaks state:** detached candidate, silent reservation, guarded non-yielding commit, postcommit publication, four fault seams, full hash/orphan checks.
- **Evidence cannot commit atomically:** stage evidence inside the commit boundary; abort attachment/reservation before publication on failure.
- **Zero exception leaks:** branch per resource and require amount-covered event IDs for every positive amount; mixed-row tests.
- **Rested accumulates/duplicates:** centralized state machine, all reset events, 4.999/5.0/split/re-entry tests, stable one-shot ID.
- **Scanner/parser divergence:** freeze accepted grammar, compare valid corpus, fail closed on malformed/unsupported/bounds, never accept uncertainty.
- **Windows replacement differs:** spike one same-volume primitive and interruption cases before writer activation.
- **Identity limits future world management:** persist UUID now and defer multi-slot/copy lifecycle explicitly.
- **Starter/onboarding divergence:** separate authoritative grant record from local idempotent evidence, linked by stable IDs.
- **Shared-file conflicts:** ordered owner transfer, writers last, no parallel shared-file edits or aliases.
- **KO/EN overflow/accessibility:** numeric layout assertions, semantic screenshots, bilingual sign-off.
- **Scope creep:** remote guard and raid guard only; controller, MAR1, late game, and full raid lifecycle cannot enter without escalation.

## MAR1 follow-up contract
Before enabling any remote build mutation, MAR1 must jointly define/prove: threat model and host-verifiable credential; registration/reconnect/storage/rotation/revocation/recovery/live-binding; authoritative remote inventory/player persistence; trusted movement; versioned command/ack/rejection precedence; epoch issuance/rotation and old-epoch ordering; bounded recordable outcomes or explicit transport backpressure; retry/timeout/disconnect/restart/snapshot reconciliation; atomic remote placement/removal/refund and exactly-once client deltas; fail-closed compatibility; pure/sequence/two-process adversarial stolen-ID/epoch/capacity/reconnect/loss/reorder evidence; security approval, migration, and rollback. Until all are approved, `UNSUPPORTED_IN_RT1` remains normative.

## Pre-mortem
1. A legacy RPC mutates host state or a local fault exposes half a build. Detect via call graph, before/after hashes, orphan/signal traces; mitigate with reject-only ingress, detached reservation transaction, and hard release block.
2. Tutorial skips gathering or Rested triggers incorrectly. Detect via cost/evidence and timing/reset traces; mitigate with canonical fixtures, per-resource evidence, centralized continuous timer, and moderated first-session rubric.
3. Identity/local data or interaction cutover corrupts state. Detect via interrupted/duplicate/sentinel fixtures and writer search; mitigate with lexical pre-scan, detached apply, deterministic migration, separate stores, writer-last cutover, and coherent rollback.
