# Stage 2 Revision — Deliberate Gameplay/UI/UX MVP

## Summary
Deliver one bounded Release Train 1 (RT1): solo keyboard/mouse from New World through starter onboarding, eating, crafting/equipping a hammer, building a valid shelter, defeating one Greyling, and save/reload. RT1 also repairs the load-bearing contracts it touches: separated world/onboarding/profile/presentation authority, one interaction-mode owner, transactional save/settings I/O, semantic onboarding events, and idempotent host-authoritative build commands. It does not attempt a general UI overhaul.

Deferred to named follow-ups: map redesign/pins, controller support and release UI, boats, fishing, raids, late-game propagation, broad combat/balance changes, multiplayer UX polish, death/tomb redesign, inventory/container redesign beyond required atomic mutations, and the full four-resolution release matrix. Raid code receives only a correctness guard/ownership boundary now; raid UX and balancing remain deferred.

Estimated effort is 18–25 engineer-days plus 3 moderated playtest days after Phase 0 approval. Stop RT1 after the acceptance evidence below passes; do not pull deferred work forward to consume remaining schedule.

## Intent Diff
- Replace one expanded `GameState` concept with five explicit domains: authoritative world, per-player/per-world onboarding, profile settings, transient presentation, and a single interaction mode.
- Replace optimistic client mutation with correlated, idempotent host commands; clients show pending state and commit inventory/UI only from host acknowledgement.
- Keep the existing starter grant, but record its provenance and begin onboarding from semantic acquisition events after spawn; inventory count can satisfy preparedness, never prove gathering.
- Replace direct save truncation with detached parse/migrate/validate/apply and temp/backup/atomic replacement.
- Cut the original broad first-30-minute overhaul to shelter + one Greyling + save/reload at two resolutions and two locales.
- Replace dual old/new live surfaces with coherent contract-first commits and release rollback of the RT1 commit set.

## Decision Drivers
1. **Correct ownership before presentation:** state lifetime, replication, and mutation authority must be explicit before UI branches begin.
2. **A shippable first-session loop:** one independently testable path is more valuable than incomplete improvements across all systems.
3. **No loss, duplication, or false success:** saves and authoritative commands are harder gates than visual polish.
4. **Repository-native execution:** programmatic GDScript UI and Godot headless tests, with no third-party dependency.
5. **Objective evidence:** fixed fixtures, operational rubrics, screenshots, and fresh-player sessions decide completion.

Assumptions: desktop keyboard/mouse only; Korean and English are required; existing programmatic UI architecture remains; current starter grant remains for compatibility; Greyling is the one RT1 Meadows enemy; current save `VERSION` remains 1 because all RT1 world additions are optional/defaulted. Any incompatible schema change requires a separate maintainer decision to raise the version.

### Deliberate decision record (DR-RT1)
- **Decision:** ship a contract-first solo MVP while making every touched mutation safe for host/client use.
- **Alternatives rejected:** (A) expanded `GameState` and one world save, because profile/local/host lifetimes conflict; (B) client prediction with inventory rollback, because rejection/disconnect creates loss/duplication risk; (C) old/new UI implementations behind flags, because shared contracts would diverge; (D) third-party Godot test addon, because RT1 needs no capability it uniquely supplies; (E) removing starter resources, because that silently changes balance and legacy expectations.
- **Consequences:** more explicit services and adapters now; multiplayer presentation and broad systems remain deferred; host command tests are required even though RT1 playtest is solo.
- **Revisit triggers:** a required pure/scene/network test cannot be expressed in the native harness; additive defaults cannot represent the schema safely; or measured starter grants prevent the loop from being learned despite provenance-aware objectives.

## Options
| Option | Benefit | Cost/risk | Decision |
|---|---|---|---|
| Broad UI/gameplay overhaul | Maximum surface coverage | Moving contracts, no credible cut line | Reject for RT1 |
| Visual reskin first | Fast screenshots | Leaves false feedback and broken authority | Reject |
| Contract-first shelter/Greyling/save slice | Coherent, measurable, rollback-safe | Defers visible breadth | **Choose** |
| Solo-only code with later network repair | Lower initial effort | Bakes unsafe mutations into new UI | Reject; commands touched by RT1 are safe now |

## In scope / out of scope
### In scope
- New/continue/loading path; clean and legacy-v1 world load.
- Persistent, skippable onboarding through: orient/move; obtain or already possess food; eat; obtain missing hammer materials through real acquisition; craft/equip hammer; place campfire, workbench, and an explicit basic shelter; receive Rested; prepare for and defeat one Greyling; save/reload.
- Starter-grant provenance and monotonic semantic event cursor.
- Required HUD objective/action/survival feedback, focused inventory/craft/build interactions, KO/EN copy, keyboard focus, 1280x720 and 1600x900 at 100% UI scale.
- Build command authority, inventory consumption, interaction-mode ownership, transactional saves, independent profile settings.
- Profile settings: locale=`ko`, UI scale=`1.0`, master/SFX/ambient=`0.8`, mouse sensitivity=`0.0026`, invert Y=`false`, reduced shake=`false`; live apply all except none require restart.
- Raid host/offline ownership guard and lifecycle contract tests only; no RT1 raid presentation or tuning.
- Native pure, scene, two-process network, and visual acceptance seams.

### Out of scope / deferred backlog
- Map zoom/pan/pins/legend/objective work; controller bindings, remapping, controller feasibility and controller-facing release UI; boat/fishing HUD; raid UX/tuning; late-game/biome/boss propagation; multiplayer chat/status/polish; broad inventory/container/tomb UX; death-recovery redesign; all-biome tuning; 1920x1080/2560x1080 and 125% UI-scale release matrix.
- New content, art pipeline, dependencies, world-generation rewrite, global recipe/economy changes, analytics transmission, or a save-format rewrite.
- Controller status for RT1 is explicitly **unsupported and not advertised**; keyboard/mouse focus is required.

## Authority and contract model
| Domain | Sole mutation owner | Lifetime/storage | Replication | UI access |
|---|---|---|---|---|
| World: pieces, enemies, raid lifecycle, shared outcomes | Offline world or host | world save | host snapshots/events | read-only snapshots/signals |
| Onboarding | local `OnboardingStore`, keyed by world ID + local player ID | world-associated local section | never transmitted; shared outcomes arrive as semantic evidence only | read-only objective snapshot and commands to skip/help |
| Profile settings | `SettingsStore` | independent `user://settings.json` | never transmitted | typed getters/setters/signals |
| Presentation | owning UI component | memory only | never | direct local state |
| Interaction mode | one `InteractionModeController` under `UIRoot` | memory only | only resulting gameplay commands replicate | mode snapshot/signals |

`GameState` remains a world façade; it does not own onboarding, settings, transient UI, or client command pending state. Domain schemas are typed/tagged classes/enums rather than one unbounded dictionary.

### InteractionMode contract
Modes: `GAMEPLAY`, `INVENTORY`, `CRAFT`, `BUILD_MENU`, `PAUSE`, `SETTINGS`, `HELP`, `CHAT`, `DEATH`, `DISCONNECTED`, `TRANSITION`. The controller alone writes `player.input_locked`, `SceneTree.paused`, mouse mode, active primary modal, focus stack, and held-item resolution. Priority for same-frame requests: `DISCONNECTED > TRANSITION > DEATH > PAUSE > SETTINGS/HELP > CHAT > INVENTORY/CRAFT/BUILD_MENU > GAMEPLAY`. Higher-priority entry closes or suspends lower modes, performs one declared held-stack commit/cancel, and restores the prior valid focus when unwinding. In multiplayer, pause UI locks local gameplay but does not pause the tree; offline pause may pause it. Tests inject simultaneous events and assert one deterministic final state and no attack/build leak.

### Authoritative command protocol
All cross-authority mutations use:

`Command {protocol_version, request_id: UUID, actor_peer_id, actor_player_id, kind, expected_world_revision, payload}`

`CommandAck {request_id, status: ACCEPTED|REJECTED|DUPLICATE, reason, authoritative_revision, inventory_delta, world_delta}`

Host keeps a bounded per-peer dedupe ledger of `(session_epoch, request_id) -> final ack` until disconnect plus 60 seconds; retries return the exact ack and never reapply mutation. Reject stale session epochs. Rate-limit outstanding commands to 8 per peer. Timeout is 5 seconds: client clears pending presentation, shows `TIMEOUT`, requests an authoritative inventory/world snapshot, and never guesses whether to spend. Disconnect clears pending ghosts and reconciles on reconnect.

For `PLACE_BUILD`, payload is `{piece_id, transform, selected_slot_revision}`. Host validates in this fixed dominant-reason precedence: `PROTOCOL > UNKNOWN_ACTOR > NOT_OWNER > STALE_REVISION > RATE_LIMITED > UNKNOWN_PIECE > OUT_OF_RANGE > PIECE_LIMIT > MISSING_STATION > MISSING_MATERIALS > INVALID_WATER > INVALID_GROUND > OVERLAP > UNSUPPORTED > ACCEPTED`. The host derives actor inventory and position from its peer registry, canonical piece data from `ItemDB`, and validity from the shared pure validator; it never trusts client cost, range, or validity. Only after all checks pass does one transaction consume authoritative materials, create the piece, advance revision, and emit the ack/event. On any failure, neither inventory nor world changes.

Client preview runs the same validator over its snapshot but is advisory. Placement creates one pending ghost keyed by `request_id`; it does not consume inventory or announce success. Accepted ack applies authoritative deltas and replaces the pending ghost; rejected/duplicate-timeout handling removes it, refreshes preview, and presents the host reason. `DUPLICATE` carries the original accepted/rejected result.

Use the same envelope/idempotency rules for later container, tomb, raid, and combat commands. RT1 implements build plus any inventory mutation crossing authority. Tomb/raid/combat remain existing host-owned flows unless touched, but adapters must reject direct client world mutation. Reason precedence and fixtures are contract artifacts, not UI policy.

### Onboarding starter-grant and event cursor
Keep current spawn grant (club, 10 wood, 6 stone, five raspberries) but issue it once through `StarterGrantService` with idempotency key `starter/v1/<world>/<player>`, persisted before delivery and reconciled against inventory on interrupted load. It emits `ITEM_ACQUIRED {event_id, source=STARTER_GRANT, item_id, amount}`. Ordinary pickup/gather emits the same event with `source=GATHER|PICKUP|DROP_RECOVERY|CRAFT`.

`OnboardingStore` persists `{schema=1, objective_version=1, cursor, completed_ids, skipped, evidence_ids}`. It consumes stable `event_id`s exactly once and advances objectives monotonically. Durable predicates allow out-of-order recovery after load; semantic source requirements prevent a granted item from pretending the player gathered it. RT1 wording follows actual grants: “Eat food you carry”; then “Gather any missing wood/stone for a hammer” only when counts are insufficient. Owning enough material satisfies preparedness, not the gather event. No objective grants rewards.

Shelter completion is testable: one player-owned workbench and campfire; at least one connected floor, three wall segments, and two roof segments within 6 m of the bed/rest point; roof ray coverage above the point; then a successful `RESTED_APPLIED` event while inside. Enemy completion requires host/offline `ENEMY_DEFEATED(enemy_id=greyling, credited_player)`; inventory drops do not substitute.

Legacy policy: a v1 world with no onboarding data starts at the earliest incomplete durable predicate, marks prior evidence as `LEGACY_INFERRED`, shows no duplicate completion messages, and grants nothing. A player may skip all onboarding; Help remains available and durable game mechanics are unchanged.

### Persistence and rollback
`SettingsStore` is profile-global `user://settings.json`, independent from world save. Unknown additive keys are ignored; missing keys take defaults; type/range-invalid keys fall back individually and generate a local warning. A wholly corrupt file is renamed to `.corrupt-<timestamp>` and defaults load. Writes serialize canonical data to `.tmp`, flush/close, parse and validate the temp, rotate valid current file to `.bak`, then atomically replace. On startup, invalid/missing current recovers from valid `.bak`, else defaults. Settings apply live.

World loading is two-phase: read bytes; parse into detached data; reject malformed/future version; migrate additive defaults into detached DTO; validate types/ranges/references; only then apply one snapshot to live world. Failure leaves the running world untouched. World saving uses the same temp validation, backup rotation, and atomic replace. `SaveSystem.VERSION` stays 1 for optional onboarding metadata; future versions are rejected without mutation. Downgrade is unsupported: preserve the file and show a recoverable error.

Rollback is a coherent RT1 commit/release set: contracts and additive readers first, implementation second, writer activation last. No parallel old/new live UI. Rollback disables the new writer, reverts the coherent set, and reads the prior/additive data; it never deletes user saves. Immutable clean, v1, corrupt, future, interrupted-write, and backup fixtures are retained. Balance constants are isolated so tuning rollback does not remove feedback/contracts.

## File-level changes and responsibility matrix
Before implementation, Phase 0 contracts must be approved and frozen. One owner edits each file at a time.

| Owner (estimate) | Files/contract | Change | Integration reviewer |
|---|---|---|---|
| Architect (2d) | `docs` contract artifacts; service boundaries | authority matrix, typed enums/schemas, interaction transition table, sequence diagram, save/settings schemas | Maintainer |
| Core/state executor (3–4d) | `scripts/core/game_state.gd`, `scripts/core/save_system.gd`, new focused `settings_store.gd`, `onboarding_store.gd`, event types | separated stores, detached migration/application, transactional I/O, objective cursor | Architect |
| Network/build executor (4–5d) | `scripts/core/net.gd`, `scripts/building/build_system.gd`, `scripts/building/build_piece.gd`, `scripts/player/inventory.gd` | command envelope/dedupe/ack, canonical validation/transaction, pending ghost, atomic inventory deltas | Architect + QA network owner |
| UI executor (4–5d) | `scripts/ui/ui_root.gd`, `hud.gd`, `inventory_ui.gd`, `craft_ui.gd`, `build_ui.gd`, `ui_theme.gd` | sole interaction-mode controller; bounded responsive objective/action/survival and required focus/reasons | Accessibility/visual reviewer |
| Progression executor (2–3d) | `scripts/player/player.gd`, onboarding definitions, `scripts/core/loc.gd`, required recipe/build event adapters | starter grant provenance; semantic evidence; shelter/Greyling chain; KO/EN copy | Core owner + gameplay reviewer |
| World/gameplay executor (1–2d) | `scripts/world/spawn_manager.gd`, `scripts/entities/enemy.gd` only as required | host/offline raid guard and epoch owner; Greyling fixture/readability event, no broad rebalance | Architect |
| Tools/QA executor (3–4d) | `scripts/dev/screenshot_director.gd`, native headless test entry/adapters, manifests | fresh acceptance profile, deterministic clock/RNG/input/network/filesystem adapters, four suites | All integration reviewers |
| Docs owner (0.5d) | `README.md` | RT1 controls/settings/test/capture instructions after behavior is accepted | Maintainer |

Integration owner is the Architect until contract freeze, then Maintainer for merge sequencing. Parallel feature branches may begin only after all Phase 0 artifacts have approval receipts; network/build cannot branch before command and inventory transaction schemas freeze, and UI/progression cannot branch before event/objective/interaction schemas freeze.

## Sequencing and dependencies
### Phase 0 — Contract freeze (Architect owner, 2–3 days)
Artifacts: `baseline-manifest.json` (commit, Godot version, seed 12345, fixture hashes, hardware/build mode, existing screenshot IDs, milestone times/failures); `authority.md`; typed `command-result-event-schema.md` with complete enums/precedence; `objective-table.md`; `interaction-modes.md`; `persistence-DR.md`; command sequence diagrams; annotated 1280x720/1600x900 KO/EN wireframes; owner/approver table.

**Exit:** Architect, network owner, core owner, UI owner, QA owner, and Maintainer record approval; every enum has an unknown/future policy; every state field has owner/lifetime/storage/replication; all objective rows specify predicate, evidence, legacy, duplicate, out-of-order, and skip behavior. No Phase 1–3 branch starts from provisional contracts. Stop and escalate if build inventory cannot commit atomically, world replacement is not atomic on a target OS, or starter grant cannot be made idempotent without incompatible schema change.

### Phase 1 — Safety foundations (Core + network/build, 7–9 days)
Implement native adapters/test seam, detached transactional persistence/settings, starter grant/event cursor, InteractionModeController, build validator/command/ack/dedupe, and raid host/offline guard. Land additive readers before writers.

**Exit:** pure and network fixtures pass; duplicate build requests consume once/create once; reject/timeout/disconnect consume nothing and reconcile; malformed/future saves leave a sentinel live world unchanged; backup recovery succeeds; same-frame mode precedence is deterministic. Stop after two failed design iterations on atomic replacement or peer ownership and request an architect review rather than adding fallback mutation paths.

### Phase 2 — RT1 player loop (Progression + UI + gameplay, 6–8 days)
Wire objective chain and only the UI required for eat/craft/equip/build/rest/Greyling/save. Apply KO/EN and responsive rules. Do not add map/controller/raid/boat/fishing/late-game work.

**Exit:** deterministic clean and v1 fixtures complete the entire chain at 1280x720 and 1600x900; reload at every cursor is monotonic; no duplicate grant/message; all required keyboard focus and reason feedback work. Stop tuning Greyling once the playtest band is met; do not generalize to other enemies.

### Phase 3 — Evidence and release gate (QA + visual reviewer + playtest coordinator, 3 QA days)
Run required automated suites, screenshot manifest, accessibility review, and moderated sessions. Fix only RT1 acceptance failures; classify other findings into deferred backlog.

**Exit:** all acceptance criteria and evidence records pass, Maintainer signs the release checklist, and rollback rehearsal recovers both current and backup saves. A failed data-integrity, authority, or clipping gate blocks release; a deferred-surface issue does not expand RT1.

## Acceptance criteria
### Functional and authority
- Clean and legacy-v1 worlds complete New World/Continue → eat → craft/equip hammer → campfire/workbench/shelter → Rested → kill one Greyling → save/reload with no external instruction or hidden grant.
- Starter grant executes exactly once under new world, reload, reconnect, and duplicate delivery. Its source cannot satisfy a gather-only semantic criterion.
- Objective cursor is monotonic and idempotent under duplicate/out-of-order events and reload at every milestone; skip is persistent and never changes game state.
- Each build request has one final ack. Across 100 duplicate/reordered/retried requests, accepted placement creates exactly one piece and consumes one cost; rejected, timed-out, stale, forged-owner, out-of-range, overlap, unsupported, and missing-material requests consume/create zero. Host reason precedence is exact.
- Raid RNG, eligibility, spawn, persistence, cancellation, reconnect snapshot, and lifecycle epoch can mutate only on host/offline world. A client invocation is rejected/no-op with no spawn. Raid play/UX is not an RT1 gate.
- InteractionModeController is the only writer of pause/input lock/mouse/focus/modal/held-stack state. Every pair of same-frame mode requests resolves by the declared priority with no leaked attack/build command.

### Persistence/settings
- Settings defaults and fields above persist across process restart, apply live, and remain profile-global across world creation/deletion. Corrupt field/file and backup recovery behavior matches policy.
- Clean, current-v1, missing-additive-field, corrupt JSON, future-version, temp-interrupted, and valid-backup fixtures are covered. Failed loads leave a preloaded sentinel world byte-for-byte/logically unchanged.
- Save write interruption leaves either the prior valid file or new valid file recoverable, never a half-applied world. Rollback rehearsal preserves all fixtures and user files.

### Measurable UI/visual
- At 1280x720 and 1600x900, 100% scale, KO and EN: outer safe margin is at least 24 px at 1280 and 32 px at 1600; reticle exclusion is a centered 240×160 px rectangle; HUD regions do not overlap it or each other. Modal maximum is viewport minus twice the safe margin, uses internal scrolling when content exceeds height, wraps labels at word boundaries, and never scales text below 16 effective px body/18 px critical.
- Text/control contrast is measured from exported PNG samples with a WCAG contrast calculator: normal text ≥4.5:1, large text/non-text controls ≥3:1. Build valid/invalid, focus, selected, disabled, and status severity use icon/label/shape in addition to color.
- Automated layout assertions require every visible critical control rect inside the safe rect, non-negative sizes, no critical sibling intersection beyond 1 px rounding tolerance, and a visible focused control. Manual sign-off records reviewer, build SHA, manifest SHA, locale/resolution, contrast values, and pass/fail notes.

### Performance
- Reference: Windows 11, Ryzen AI MAX+ 395 integrated Radeon 8060S, release/export build, VSync off, 1600x900, 60-second warm-up. Capture 300 samples per local action across attack/block/dodge/interact/build preview. Start timestamp is `_input` receipt; endpoint is first submitted frame containing animation state change, audio playback request, or visible UI/ghost state. P95 ≤100 ms and no sample >150 ms; report each channel separately.
- Network fixture adds deterministic 80 ms RTT/1% reorder: start at command send; pending visual P95 ≤100 ms locally, authoritative ack latency reported separately and excluded from the local threshold. Rejection appears on the first frame after ack.
- RT1 combat fixture (one player, one Greyling, shelter nearby) holds P95 frame time ≤16.67 ms and P99 ≤25 ms over 120 seconds after warm-up. Deferred stress budgets (18 enemies/raid/3,000 pieces) are recorded but do not gate RT1.

## Verification
Planning stage runs no tests, gates, formatters, or product changes. Executors use the existing Godot runtime only; no addon. Add adapters for filesystem, monotonic clock, RNG, input events, and loopback/network transport so pure tests do not require a scene and network tests can run two headless processes.

Suggested native entrypoints after implementation:
- Import/parse: `godot4 --headless --path . --editor --quit`
- Pure: `godot4 --headless --path . -- --test-suite=pure`
- Scene: `godot4 --headless --path . -- --test-suite=scene`
- Two-process host/client: `godot4 --headless --path . -- --test-suite=network --seed=12345`
- Visual/layout: `godot4 --headless --path . -- --test-suite=visual --shot-profile=rt1 --seed=12345`
- Manual fixed-seed smoke: `godot4 --path . -- --auto --seed=12345`

## Escalation/Risk Gate
Maintainer + Architect approval is required to raise save version, alter existing serialized meaning, change starter contents/recipe economy/global combat constants, add dependencies, add controller support, change world generation, expand multiplayer authority beyond the command contract, replace baseline screenshots, or pull a deferred system into RT1. Any data loss/duplication, unauthenticated mutation, non-atomic migration, or inability to establish a single interaction owner is a release blocker. Scope pressure is not sufficient reason to weaken these gates.

Escalate to Architect when a state has two plausible owners, a host validator cannot derive its inputs, or OS atomic-replace behavior differs. Use Executor agents for bounded file groups after freeze, Critic after each phase gate, a Team for Phase 1 integration, and Ultragoal only if the Maintainer explicitly expands cross-phase execution.

## Verification Plan
### Automated tests
- **Pure:** command serialization/future protocol; complete reason precedence; dedupe/replay/session epoch; build validator edges; atomic inventory delta; objective duplicate/out-of-order/legacy/skip/starter-source matrix; shelter predicate; settings defaults/ranges; save migration/validation; interaction transition table.
- **Scene:** New World starter grant; eat/craft/equip; pending/accepted/rejected build ghost; shelter/Rested; Greyling defeat evidence; focus restore; modal held-stack cancel; locale live apply; save/reload at every cursor.
- **Two-process:** forged actor, stale revision, request replay before/after ack, packet reorder, timeout, disconnect/rejoin, host inventory insufficiency after client preview, simultaneous placement, client raid invocation, snapshot reconciliation.
- **Visual:** required screenshot state assertions, safe rects, focus, overflow/scroll, missing localization keys, deterministic manifest/hash generation.

### Exact gameplay fixtures and rubrics
- Seed `12345`; Meadows spawn fixture selected in Phase 0 and recorded as coordinates plus world-fixture hash; noon, clear weather, no raid, 100% UI scale, keyboard/mouse; starter grant exactly club/10 wood/6 stone/5 raspberries. The one enemy is `greyling` (20 HP, current tier-0 data); spawn one at a recorded point 12 m from shelter only after Rested. No debug combat buffs.
- Fresh cohort: age-eligible participants familiar with third-person PC controls but with no prior project build/video exposure; minimum N=10. Exclude only crashes/hardware failures before task start and replace exclusions. Disconnects are failures unless proven harness failures. Facilitator gives setup/safety instructions only; any gameplay hint is an intervention and that participant fails independence for that task.
- “Understands next goal” passes only when the participant states both the next action and purpose without choosing from options; two blinded coders must agree, resolving disagreement with a third. “Attributable death” passes only when the participant names the fatal enemy action and one viable prevention/recovery.
- Idle/confused interval begins after 10 seconds with no goal-progressing input plus observed searching/repeated ineffective action or an unsolicited “what now”; ends on a productive action. Two coders annotate video; use adjudicated intervals and report median participant maximum. Gate: median maximum ≤90 seconds.
- Fresh-player gate: ≥8/10 independently eat, craft/equip hammer, satisfy shelter/Rested, defeat Greyling, and identify save/continue in ≤20 minutes; ≥8/10 state next action+purpose; prepared Greyling first-attempt survival must be 7 or 8 of 10 (70–80%, within the intended 65–85% band), median encounter 20–60 seconds, and all deaths attributable. If survival is outside band, change only Greyling fixture/readability or RT1 starter-loop values through balance approval, then rerun a new N=10 cohort.
- Returning cohort: N=5 using immutable v1 and mid-objective fixtures; all five continue without duplicate grant/objective reward and locate Help; no more than one requires an intervention.
- Ten action-attribution cases, one attempt each: insufficient-stamina attack; insufficient-stamina dodge; normal block; timed parry; dodge iframe hit avoidance; resistant hit; effective hit; build missing materials; build missing workbench; build overlap rejection. Pass is ≥9/10 correct cause/recovery answers per participant for ≥8/10 fresh participants after exposure. Question: “What happened, why, and what can you do next?” Scorer requires correct outcome + cause; recovery is required for failures. No coaching/replay before answer.

### Screenshot manifest and sign-off
Required captures (not combinatorial): each at 1280x720 and 1600x900, KO and EN, 100% scale: clean spawn/objective; food/status; craft selected + missing reason; inventory equipped state; build valid; each of missing-workbench/overlap/unsupported invalid reasons; completed shelter/Rested; Greyling wind-up; low stamina rejection; pause/settings with keyboard focus; save/load error. That is 13 states × 2 resolutions × 2 locales = 52 PNGs. Optional captures may cover 1920x1080, ultrawide, 125%, map, raid, boats, fishing, and late game but cannot block or substitute required captures.

Manifest fields: schema, build SHA, Godot version, profile, fixture hash, seed, coordinate, state ID, expected semantic assertions, locale, resolution, UI scale, input device, time/weather, injected state/grants, PNG SHA-256, baseline PNG SHA-256, capture timestamp. Retain baseline and candidate sets; never overwrite baseline. Automated pixel diff is advisory because rendering may vary; semantic/layout assertions and named visual/accessibility sign-off are authoritative.

### Release evidence packet
Contract approvals; test reports with fixture hashes; performance traces; save/rollback rehearsal; 52-image manifest; contrast worksheet; visual/accessibility sign-off; coded playtest sheets and anonymized aggregate; known deferred issues; Maintainer go/no-go receipt.

## 3-scenario pre-mortem
1. **Authority repair appears correct but duplicates under packet replay.** Early warning: host/client revision mismatch or two inventory deltas for one request ID. Mitigation: final-ack dedupe ledger, host-owned inventory lookup, chaos tests with retries/reorder/disconnect, and release block on any mismatch.
2. **Onboarding advances from starter inventory and teaches nothing.** Early warning: zero acquisition events but gather-like copy completes, or legacy users see repeated milestones. Mitigation: source-tagged idempotent events, durable predicates separated from semantic evidence, provenance-aware copy, cursor reload matrix, and fresh-player rubric.
3. **Polish ships while saves or modal state corrupt.** Early warning: live state changes after failed load, temp file cannot recover, held item survives hidden modal, attack leaks while settings open. Mitigation: detached load/apply, temp validation/backup/atomic replace, one interaction state machine, same-frame transition tests, coherent rollback rehearsal.

## Risks and mitigations
- **Contract breadth consumes MVP:** freeze only contracts touched by RT1; use envelopes for deferred domains without implementing their UX. Stop at explicit phase exits.
- **Save atomic replacement differs on Windows:** filesystem adapter and interruption fixtures; document platform primitive; block writer activation until proven.
- **Starter grant reconciliation duplicates partial delivery:** persist grant transaction/idempotency record, reconcile item deltas, and test interruption at each step.
- **Shared validator drifts between preview and host:** one pure validator implementation with explicit context; host supplies canonical state and always wins.
- **Pending UI feels sluggish:** immediate pending ghost/feedback, measured separately from authoritative ack; never trade correctness for optimistic spending.
- **Programmatic UI overflows KO/EN:** numeric safe-area/layout assertions, scroll policy, fixed required matrix, and bilingual sign-off.
- **Single interaction owner becomes a monolith:** controller owns transitions/effects only; surfaces own content and emit requests.
- **Greyling tuning generalizes accidentally:** fixture-specific gate and isolated approved constants; no other enemy/broad balance edits.
- **Raid correctness guard changes behavior:** host/offline lifecycle tests and epoch snapshot; no UX/timing rebalance in RT1.
- **Deferred scope sneaks back through acceptance:** optional screenshots and backlog never block RT1; pull-in requires the documented gate and revised estimate.
