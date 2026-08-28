# Consensus Revision Pass 3 — Deliberate Gameplay/UI/UX MVP

## Summary
Deliver one bounded Release Train 1 (RT1): solo keyboard/mouse from New World through starter onboarding, eating, gathering the complete material budget, crafting/equipping a hammer, building a campfire-anchored shelter, receiving Rested, defeating one Greyling, and save/reload. RT1 also repairs only the load-bearing contracts it touches: durable world/player identity, authenticated host player state, immutable command outcomes with epoch-safe replay, separated world/onboarding/profile/presentation authority, one interaction-mode owner, transactional save/settings/onboarding I/O, semantic onboarding events, idempotent host-authoritative building, and a host/offline raid mutation guard.

Deferred to named follow-ups: map redesign/pins, controller support and release UI, boats, fishing, full raid lifecycle persistence/cancellation/reconnect snapshots/raid epochs, raid UX/tuning, late-game propagation, broad combat/balance changes, multiplayer UX polish, death/tomb redesign, inventory/container redesign beyond the RT1 matrix, and the full four-resolution release matrix. No deferred raid lifecycle behavior is an RT1 acceptance gate.

Estimated effort remains 18–25 engineer-days plus 3 moderated playtest days after Phase 0 approval; Phase 0 must revalidate the estimate once identity/registry schemas and Windows replacement behavior are frozen. Stop RT1 after the acceptance evidence below passes; do not pull deferred work forward to consume remaining schedule.

## Intent Diff
- Replace assumed ephemeral identity with persisted UUID world/player IDs and deterministic, collision-safe migration for legacy data.
- Establish an authenticated host peer registry before any gameplay-command validation; bind RPC sender, durable player, host-issued session epoch, authoritative inventory revision, and trusted movement snapshot.
- Replace optimistic mutation with correlated host commands. A final outcome is only `ACCEPTED` or `REJECTED`; retries return the immutable original outcome, with `replayed` as separate transport metadata, and never reapply deltas.
- Carry the host-issued `session_epoch` in both command and acknowledgement; rotate it on reconnect while retaining the old epoch ledger for bounded dedupe and stale-packet rejection.
- Keep the existing starter grant, record its provenance, and teach real gathering for the full canonical RT1 cost rather than only hammer shortfalls.
- Define the campfire—not a bed—as the shelter rest milestone/reference point; `RESTED_APPLIED` counts only when the exact shelter predicate holds.
- Store onboarding in a separate local transactional user store keyed by durable IDs; never place private onboarding state in the replicated world document.
- Route `main.gd`, `net_probe.gd`, and `screenshot_director.gd`, as well as UI surfaces, through the sole `InteractionModeController`.
- Narrow raid work to a host/offline mutation guard and client no-op/rejection tests; defer lifecycle persistence and reconnect behavior.
- Preserve detached save validation, transactional replacement, bounded responsive UI, screenshots, playtests, rollback, decision record, and pre-mortem.

## Decision Drivers
1. **Correct ownership before presentation:** authentication, identity, state lifetime, replication, and mutation authority must be explicit before gameplay validation or UI branches.
2. **A feasible first-session loop:** objectives must teach every material acquisition needed by canonical RT1 recipes without changing the starter grant or economy.
3. **No loss, duplication, or false success:** saves, local user data, and authoritative outcomes are harder gates than visual polish.
4. **Bounded solo release:** network contracts touched by RT1 must be safe, but multiplayer presentation and unrelated command kinds remain deferred or explicitly rejected.
5. **Repository-native execution:** programmatic GDScript UI and Godot headless tests, with no third-party dependency.
6. **Objective evidence:** fixed fixtures, operational rubrics, screenshots, and fresh-player sessions decide completion.

Assumptions: desktop keyboard/mouse only; Korean and English required; existing programmatic UI remains; starter grant remains club/10 wood/6 stone/5 raspberries; Greyling is the one RT1 enemy; current world save `VERSION` remains 1 because IDs and grant records are additive/defaulted. Any incompatible serialized change requires Maintainer approval and a version increase.

### Deliberate decision record (DR-RT1)
- **Decision:** ship a contract-first solo MVP while making touched authority, identity, replay, interaction, and persistence seams safe.
- **Rejected:** expanded `GameState`/one-file ownership; client prediction with inventory rollback; `DUPLICATE` as a third outcome; private onboarding in host world saves; parallel old/new UI; full raid lifecycle in RT1; third-party test addons; increased starter grants; undefined bed/rest anchors.
- **Consequences:** Phase 0/1 adds explicit identity and registry substrate; multiplayer command breadth stays bounded; replay handling and client delta application are idempotent by request ID; local onboarding has independent recovery.
- **Revisit triggers:** native tests cannot express a required seam; additive v1 defaults are unsafe; authoritative inventory cannot bind to authenticated players; target OS cannot guarantee replacement/recovery; or measured starter gathering prevents completion despite provenance-aware objectives.

## Options
| Option | Benefit | Cost/risk | Decision |
|---|---|---|---|
| Broad UI/gameplay overhaul | Maximum surface coverage | No credible cut line | Reject |
| Visual reskin first | Fast screenshots | Leaves authority and false feedback broken | Reject |
| Contract-first shelter/Greyling/save slice | Coherent and measurable | Defers visible breadth | **Choose** |
| Third `DUPLICATE` status | Easy replay visibility | Changes original outcome and risks missed/double deltas | Reject; immutable outcome + `replayed` |
| World-owned onboarding | One file | Wrong privacy/lifetime for clients | Reject; separate local store |
| Full raid lifecycle now | Stronger reconnect semantics | New persistence/network subsystem | Defer |
| Host/offline raid guard only | Prevents client mutation | Leaves lifecycle follow-up | **Choose** |
| Increase starter grant | Quick feasibility | Balance and legacy change | Reject; teach exact gathering |

## In scope / out of scope
### In scope
- New/continue/loading for clean and legacy-v1 worlds; durable UUID identities and deterministic migration.
- Persistent, skippable onboarding: orient/move; obtain or possess food; eat; gather the outstanding materials for the **entire** canonical RT1 build; craft/equip hammer; place campfire/workbench/basic shelter; receive Rested at the campfire shelter milestone; prepare for/defeat one Greyling; save/reload.
- Canonical current cost baseline frozen from recipes: hammer 3 wood/2 stone, campfire 2 wood/5 stone, workbench 10 wood, and basic shelter 12 wood (one floor, three walls, two roofs), total 27 wood/7 stone. With untouched starter resources the nominal outstanding amount is 17 wood/1 stone; objectives compute remaining amounts from authoritative inventory and actual prior spending rather than hard-code the nominal shortfall.
- Starter-grant provenance, semantic event cursor, separate transactional onboarding store.
- Authenticated host player registry, host-owned inventory/revision, trusted movement snapshot boundary, command/session binding, retained dedupe ledger, and authoritative build transaction.
- Required HUD/objective/action/survival feedback, focused inventory/craft/build interactions, KO/EN copy, keyboard focus, 1280×720 and 1600×900 at 100% UI scale.
- Transactional world/settings/onboarding persistence; profile settings for locale, UI scale, master/SFX/ambient, sensitivity, invert Y, and reduced shake.
- Raid host/offline ownership guard only.
- Native pure, scene, two-process network, and visual acceptance seams.

### Out of scope / deferred backlog
- Map work; controller bindings/remapping/release UI; boats/fishing; raid lifecycle serialization, cancellation, reconnect snapshots, raid-specific epoch, UX, timing, and tuning; late game/biomes/bosses; multiplayer chat/status/polish; broad inventory/container/tomb UX; death recovery; all-biome tuning; 1920×1080/2560×1080 and 125% UI-scale release matrix.
- Remote multiplayer support for command kinds explicitly marked `REJECT/DEFER` below; no direct mutation fallback is allowed.
- New content/art/dependencies, world generation rewrite, global recipe/economy changes, analytics transmission, or save-format rewrite.
- Controller is unsupported and not advertised in RT1.

## Authority and data contracts
### Durable identities
- New worlds receive a UUIDv4 `world_id` before first save; it is stored in the additive world header and never changes on rename, move, save, or load. An explicit in-app duplicate-world operation allocates a fresh UUID and does not copy onboarding/grant completion. Deleting a world removes its save and transactionally removes local onboarding rows for that world only after deletion succeeds.
- A local user receives a UUIDv4 `local_player_id` in `user://identity.json` before world entry. It remains stable across worlds and reconnects. Reset/import is an explicit future account operation, not inferred from display name or peer ID.
- Legacy worlds derive `world_id = UUIDv5(WORLD_LEGACY_NAMESPACE, canonical_source_fingerprint)`, where the fingerprint is canonical slot identity + original seed + normalized original world name. A legacy installation derives `local_player_id = UUIDv5(PLAYER_LEGACY_NAMESPACE, persisted installation_id)`; if installation ID is absent, create and transactionally persist one before deriving.
- Migration is detached and persisted before any starter/onboarding transaction. If multiple discovered documents produce one candidate ID, lexicographically smallest canonical source fingerprint retains it; each other source deterministically receives `UUIDv5(COLLISION_NAMESPACE, candidate_id + source_fingerprint + stable_ordinal)`. Validate uniqueness against all known world IDs, incrementing the ordinal deterministically until unique. Persist the resolved mapping so scan order cannot change it. Fixtures cover rename/move, duplicate legacy names/seeds, repeated migration, collision, copy, delete, and reload.

### Domain ownership
| Domain | Sole mutation owner | Storage/lifetime | Replication |
|---|---|---|---|
| World, pieces, enemies, authoritative inventory/grants | Offline authority or authenticated host | transactional world save | host snapshots/events |
| Onboarding | local `OnboardingStore` | `user://onboarding.json`, keyed by `(world_id, local_player_id)` | never transmitted |
| Local identity | `IdentityStore` | `user://identity.json` | durable player ID sent only during authenticated registration |
| Profile settings | `SettingsStore` | `user://settings.json` | never transmitted |
| Presentation/pending command UI | owning UI component | memory only | never transmitted |
| Interaction mode | sole `InteractionModeController` under `UIRoot` | memory only | only resulting commands replicate |

`GameState` remains a world façade and does not own onboarding, settings, identity, transient UI, or pending command state. Schemas use typed/tagged records/enums.

### Authenticated host player registry
Registration precedes command admission. The transport authenticates the RPC sender, resolves or creates the durable `player_id`, rejects a claimed player already bound to another live peer, and only then creates:

`HostPlayerState {peer_id, player_id, session_epoch, auth_state=AUTHENTICATED, authoritative_inventory, inventory_revision, trusted_position, movement_revision, connected_at}`.

The host player is registered through the same path before local host commands. Join initializes inventory from the authoritative world player record or an explicit new-player transaction; it never copies client inventory. Save/load owns inventory under durable `player_id`. A reconnect authenticates the same durable player, rotates to a new random 128-bit `session_epoch`, binds the new peer, returns a full authoritative inventory/world snapshot, and retains old epoch ledgers for dedupe. Position/range validation uses the last host-accepted movement snapshot with maximum age/displacement rules frozen in Phase 0; raw command payload position is never trusted. Missing registry, forged actor/peer, unauthenticated sender, stale epoch, and player already bound are rejected before gameplay validation. Sequence fixtures cover offline host, remote join, reconnect, missing registry, forged actor, stale packet, and save/load.

### Command, epoch, replay, and rate limits
`Command {protocol_version, request_id: UUID, session_epoch, actor_peer_id, actor_player_id, kind, expected_world_revision, expected_inventory_revision, payload}`

`CommandAck {request_id, session_epoch, outcome: ACCEPTED|REJECTED, reason, authoritative_world_revision, authoritative_inventory_revision, inventory_delta, world_delta, replayed: bool}`

The immutable final outcome consists of every acknowledgement field except `replayed`. The first response has `replayed=false`; a retry with the same authenticated `(player_id, session_epoch, request_id)` returns the original accepted/rejected outcome and exact original deltas/revisions with only `replayed=true`. There is no `DUPLICATE` outcome or reason. Clients key outcome/delta application by `(session_epoch, request_id)`, apply it at most once, and may display replay telemetry without changing success/failure behavior.

The host retains a per-player ledger across disconnect/reconnect for at least 60 seconds, keyed by `(session_epoch, request_id)`, with a ceiling of 1,024 final outcomes or 4 MiB per player, whichever is reached first. Entries younger than 60 seconds and in-flight entries are not evicted; at capacity, new unique commands receive `REJECTED/RATE_LIMITED` without execution until capacity is available. Reconnect rotates epoch but does not relabel or clear old ledger entries. Delayed old-epoch commands receive `REJECTED/STALE_SESSION` and cannot mutate; a client uncertain about an old request obtains a snapshot rather than resending it under the new epoch. Ledger persistence across process restart is deferred because RT1 does not support live-session restoration.

Outstanding unique commands are capped at 8 per authenticated session from admission until final outcome is recorded. Replays do not increment the count. Validation order is: envelope/protocol → authenticated sender/registry binding → session epoch → actor ownership → replay lookup → capacity/outstanding rate limit → expected revisions → kind-specific checks. This makes rate-limit fixtures deterministic without performing world-sensitive work.

For `PLACE_BUILD`, payload is `{piece_id, transform, selected_slot_revision}`. After common admission, dominant kind reasons are `UNKNOWN_PIECE > OUT_OF_RANGE > PIECE_LIMIT > MISSING_STATION > MISSING_MATERIALS > INVALID_WATER > INVALID_GROUND > OVERLAP > UNSUPPORTED > ACCEPTED`. The host derives inventory/position from the registry, canonical cost from `ItemDB`, and placement validity from one pure validator. One transaction consumes materials, creates the piece, advances revisions, and records the final outcome before send. Failure changes nothing. Client preview is advisory; a request creates one pending ghost but does not spend or announce success. Accepted outcome applies deltas once and replaces the ghost; rejection/timeout removes it and snapshots reconcile uncertainty.

### RT1 mutation matrix
| Mutation/callsite area | Offline/host owner | Remote-client RT1 behavior | RT1 decision |
|---|---|---|---|
| Build placement/removal in `build_system.gd`, `build_piece.gd`, `inventory.gd`, `net.gd` | authoritative build transaction | `PLACE_BUILD` implemented; removal/refund rejected `UNSUPPORTED` | Implement placement only |
| Gather/resource pickup/drop recovery in resource/item-drop adapters | authority emits source-tagged acquisition and inventory transaction | existing host-owned path may deliver snapshot/event; direct client inventory write rejected | Support tutorial evidence without broad pickup UX |
| Craft hammer in craft/player/inventory adapters | offline/host inventory transaction | remote command rejected `UNSUPPORTED` | Solo RT1 only |
| Equip hammer, eat food in player/inventory adapters | offline/host inventory transaction | remote command rejected `UNSUPPORTED` | Solo RT1 only |
| Inventory move/container/tomb/remove-refund | authority only | reject `UNSUPPORTED`; no fallback write | Defer |
| Combat/ammo/cooking/smelting/altar | existing host/offline ownership unchanged unless adapter detects direct client mutation, then reject | no new RT1 command | Defer |
| Raid RNG/eligibility/spawn | host/offline guard | client call rejected/no-op | Guard only; lifecycle deferred |
| Save/load | world/settings/onboarding store owners | clients cannot write host world | Existing scope with transactional repair |

Phase 0 must enumerate concrete functions found in each area and prove every touched direct mutation is routed or rejected; this matrix is the scope boundary, not permission to generalize multiplayer.

### Interaction mode contract
Modes and priority remain: `DISCONNECTED > TRANSITION > DEATH > PAUSE > SETTINGS/HELP > CHAT > INVENTORY/CRAFT/BUILD_MENU > GAMEPLAY`. The controller alone writes input lock, offline tree pause, mouse mode, active primary modal, focus stack, and held-item resolution. Multiplayer pause locks local gameplay without pausing the tree. `ui_root.gd`, `main.gd` title/world transitions, `net_probe.gd` automation, and `screenshot_director.gd` automation emit typed mode requests; none write those effects directly. Dev-only override requests are explicit, unavailable in release builds, and use the same transition/effect path. Title ownership is created before `UIRoot`; world transition hands the same controller to `UIRoot` without a second writer. Same-frame requests resolve once by priority and declared held-stack commit/cancel.

### Onboarding, full costs, and campfire rest milestone
Starter delivery is an authoritative world transaction keyed `starter/v1/<world_id>/<player_id>`, persisted in the world player record before inventory delivery, then reconciled after interruption. It emits source-tagged stable acquisition events. This grant record is distinct from private onboarding progress.

`OnboardingStore` is a separate transactional local document containing `{schema=1, records: [{world_id, local_player_id, objective_version, cursor, completed_ids, skipped, evidence_ids}]}`. It uses temp validation, backup rotation, atomic replacement, and recovery equal to settings. New world creates a blank row after IDs persist; rename/move preserves it; duplicate world gets no copied row; successful world delete removes matching rows; corrupt onboarding never mutates world/inventory and recovers backup or starts earliest durable predicate with a warning.

The objective table explicitly includes: possess/eat carried food; gather outstanding hammer cost; craft/equip hammer; gather outstanding campfire cost; place campfire; gather outstanding workbench cost; place workbench; gather outstanding six-piece shelter cost; build one floor/three walls/two roofs around the campfire; enter the completed shelter and receive Rested; defeat Greyling; save/reload. Each gather row displays authoritative remaining item/amount and completes only from `GATHER|PICKUP|DROP_RECOVERY` events plus the authoritative inventory predicate; starter provenance can satisfy possession/preparedness but never the semantic gathering evidence. Costs are read from frozen canonical recipes, and a fixture proves total 27 wood/7 stone and nominal post-grant need 17 wood/1 stone.

The **campfire is the rest point and milestone; no bed is required in RT1**. Shelter completion requires one player-owned campfire and workbench, one connected floor, three wall segments, and two roof segments within 6 m of the campfire center; piece owner IDs persist/replicate. Roof coverage uses upward rays from the campfire center and four fixed 0.5 m horizontal offsets, with at least 4/5 hitting connected player-owned roof pieces. Walls/floor/roof must belong to one adjacency component connected to the floor nearest the campfire. `RESTED_APPLIED` onboarding evidence is emitted only when the authoritative player is within 3 m of that campfire, all predicate checks pass, and the normal rest duration threshold completes; generic comfort elsewhere does not emit this milestone. Exact ray masks, adjacency tolerance, and duration are frozen in Phase 0 fixtures.

Events are consumed once by stable `event_id`; cursor is monotonic; durable predicates recover out of order. Legacy worlds start at earliest incomplete predicate with `LEGACY_INFERRED`, no duplicate messages, grants, or rewards. Skip persists locally and changes no game state; Help remains available.

### Persistence, settings, and rollback
World load remains read → detached parse → reject malformed/future → additive migration → full validation → one apply. Failure leaves live state untouched. World/settings/identity/onboarding writes use canonical `.tmp`, flush/close, reparse/validate, rotate valid current to `.bak`, then Windows same-volume atomic replacement. Phase 0 must select and spike the exact Godot/.NET/native primitive; replacement failure preserves current or backup, reports a recoverable error, and never activates new writers until interruption fixtures pass. `VERSION=1` remains only if additive IDs/grant records validate safely.

Settings remain profile-global with live locale/UI scale/master/SFX/ambient/sensitivity/invert/reduced-shake application. Phase 0 freezes creation/routing of Master, SFX, and Ambient buses and a root/theme UI-scale mechanism; channel probes must show SFX and ambient isolation rather than both using Master.

Rollback is one coherent RT1 set: contract/schema and additive readers first, stores/registry/controller second, callsite cutover third, writers last. Disable new writers before reverting; retain additive readers and never delete user files. No dual live UI or direct-mutation fallback. Immutable clean/v1/corrupt/future/interrupted/backup fixtures remain release artifacts.

## File-level changes
One owner edits a shared file at a time; ownership transfers are explicit.

| Owner (estimate) | Files/contracts | Change |
|---|---|---|
| Architect (2–3d) | contract docs/fixtures | identity, registration, command/outcome, objective/cost, shelter, interaction, persistence, settings bus, matrix, sequence diagrams |
| Core/state (3–4d) | `game_state.gd`, `save_system.gd`, new focused identity/settings/onboarding stores and event types | durable IDs, detached migration, transactional stores, grant records, cursor |
| Network/build (4–5d) | `net.gd`, new host registry, `build_system.gd`, `build_piece.gd`, `inventory.gd` | authenticated registration, epoch/ledger/outcome, inventory authority, validator/transaction/ghost |
| Interaction/UI (4–5d) | new controller, `ui_root.gd`, `main.gd`, `hud.gd`, inventory/craft/build/theme UI | sole interaction owner, handoff, bounded responsive UX, reasons/focus |
| Progression (2–3d) | `player.gd`, objective definitions, `loc.gd`, recipe/gather/rest/enemy adapters | exact costs/copy, provenance, campfire shelter, Greyling chain |
| World/gameplay (1–2d) | `spawn_manager.gd`, `enemy.gd` | host/offline raid guard only; Greyling event/fixture |
| Tools/QA (3–4d) | `net_probe.gd`, `screenshot_director.gd`, native test entry/adapters/manifests | typed dev mode requests, deterministic seams, four suites, captures |
| Docs (0.5d) | `README.md` | accepted controls/settings/test/capture guidance |

Shared-file cutover order: Core lands additive IDs/readers/stores; Network owns and lands registry/envelope/inventory transaction; Progression then owns `inventory.gd`/`player.gd` adapters; Interaction owns and lands controller plus `main.gd`/UI cutover; Tools land both dev-script cutovers after controller API freezes; world guard and docs follow. No parallel edits to `net.gd`, `inventory.gd`, `player.gd`, `main.gd`, or controller callsites.

## Sequencing and dependencies
### Phase 0 — Contract freeze (2–3 days)
Freeze baseline manifest; authority/identity/registration schemas; host/remote/reconnect/forged/missing-registry sequence diagrams; command/outcome/epoch/ledger limits and precedence; exhaustive mutation callsite matrix; exact recipe-cost/objective table; campfire shelter geometry; interaction transition/handoff table; onboarding/settings/world schemas; Windows replacement decision; bus/UI-scale design; KO/EN wireframes; owner/approver table.

**Exit gate:** Architect, network, core, UI, QA, and Maintainer approve every artifact; every field has owner/lifetime/storage/replication/future policy; canonical cost fixture is 27 wood/7 stone; identity collision and reconnect fixtures are unambiguous; estimate is reaffirmed or revised before branches. Stop if inventory cannot be authoritative/atomic, authenticated binding cannot precede validation, or replacement cannot preserve valid data.

### Phase 1 — Safety foundations (7–9 days)
Land additive identity/readers, local stores, authenticated registry, epoch/ledger/outcome protocol, inventory/build transaction, interaction controller and all direct-writer cutovers, native seams, and raid guard. Writers activate last.

**Exit gate:** identity migration is stable/collision-safe; missing/forged/stale actors cannot reach gameplay validation; replay changes only `replayed` and mutates once; reconnect rotates epoch while retaining ledger; transactional interruption recovery succeeds; one-writer repository search passes; client raid calls cannot mutate.

### Phase 2 — RT1 loop (6–8 days)
Wire exact gather rows, starter provenance, eat/craft/equip, campfire/workbench/shelter/Rested, Greyling, save/reload, bilingual responsive UI. No deferred command or raid work.

**Exit gate:** clean and legacy fixtures complete at both resolutions/locales; every cost is taught and acquired; campfire predicate alone gates milestone `RESTED_APPLIED`; reload at every cursor is monotonic; no duplicate grant/message; keyboard focus and reason feedback work.

### Phase 3 — Evidence/release (3 QA days)
Run automated suites, 52-shot manifest, accessibility review, moderated sessions, performance captures, save/rollback rehearsal. Fix only RT1 failures and backlog deferred findings.

**Exit gate:** all acceptance/evidence pass and Maintainer signs go/no-go. Data-integrity, authentication/authority, replay, interaction ownership, or clipping failures block release; deferred raid lifecycle does not.

## Acceptance criteria
### Identity, authority, and replay
- New IDs are valid UUIDv4 and stable; legacy UUIDv5 migration is deterministic under rename/reload/scan reorder; forced collisions deterministically rekey one source and persist the mapping; duplicate-world gets a new world ID and blank onboarding, while move/rename preserves both.
- Host/offline player state exists before command validation. Missing registry, unauthenticated sender, forged peer/player, duplicate live binding, stale epoch, stale revisions, and out-of-range commands produce the specified dominant rejection and zero inventory/world mutation.
- Reconnect rotates `session_epoch`, returns a snapshot, and retains old ledgers. Delayed prior-epoch packets mutate zero; they are not relabeled into the new epoch.
- Across 100 duplicate/reordered/retried build requests, the original `ACCEPTED` or `REJECTED` outcome, reason, revisions, and deltas remain identical; only `replayed` changes false→true. Accepted placement creates/consumes once; all rejection/timeout/forgery cases create/consume zero; client applies deltas once.
- Eight unique outstanding commands are admitted; the ninth deterministically returns `RATE_LIMITED`; replay does not consume a slot. Capacity never evicts an in-flight or <60-second final outcome.

### Tutorial, shelter, interaction, and raid boundary
- Objective/cost fixture proves hammer + campfire + workbench + shelter = 27 wood/7 stone and explicitly teaches acquisition for each outstanding cost; no hidden grant or external instruction is needed.
- Starter grant occurs once across create/load/reconnect/interruption. Starter evidence cannot satisfy gather-only rows.
- Campfire is the only RT1 rest reference; no bed is required. Exact ownership, adjacency, distance, five-ray coverage, and rest-duration predicate must pass before milestone `RESTED_APPLIED`; ordinary Rested elsewhere does not advance onboarding.
- Cursor/evidence are monotonic/idempotent under duplicate/out-of-order events and every reload point; skip is local/persistent and changes no game state.
- `InteractionModeController` is the sole production writer, including title/world transitions and both dev automation scripts. Every same-frame pair resolves by priority with no leaked attack/build input; release builds cannot invoke dev overrides.
- Raid RNG/eligibility/spawn mutation executes only host/offline. Client invocation is rejected/no-op with no spawn. Raid persistence, cancellation, reconnect snapshot, and lifecycle epoch have no RT1 implementation or acceptance dependency and remain named follow-up work.

### Persistence/settings
- Onboarding is stored only in separate `user://onboarding.json`, keyed by durable IDs, and survives restart; corrupt/current/backup/interrupted/copy/delete behaviors match the lifecycle above without changing world or inventory.
- Clean/current-v1/missing-additive/corrupt/future/temp-interrupted/valid-backup world and identity/settings fixtures leave preloaded sentinel state unchanged on failure and always recover either prior or new valid bytes.
- Settings apply live and remain profile-global. Master, SFX, and Ambient probes isolate channels; UI scale applies through the frozen root/theme path.
- Rollback rehearsal preserves saves, IDs, onboarding, settings, ledgers needed for the live process, and all immutable fixtures.

### UI, performance, screenshots, and playtests
- Preserve numeric UI gates: at 1280×720/1600×900, KO/EN, 100%, safe margins ≥24/32 px; centered 240×160 reticle exclusion; no critical overlap; scrolling instead of text below 16 px body/18 px critical; contrast ≥4.5:1 normal and ≥3:1 large/non-text; non-color cues for validity/focus/status.
- Preserve performance gates on the stated Windows 11/Ryzen AI MAX+ 395/Radeon 8060S release setup: local action P95 ≤100 ms/no sample >150 ms; pending network visual P95 ≤100 ms with authoritative latency reported separately; combat P95 frame ≤16.67 ms/P99 ≤25 ms over 120 seconds.
- Preserve fresh cohort N=10: ≥8/10 independently finish the RT1 chain and identify save/continue within 20 minutes; ≥8/10 explain next action/purpose; prepared Greyling survival 7–8/10; median encounter 20–60 seconds; median maximum confused interval ≤90 seconds. Returning N=5 all continue without duplicate grant/reward and find Help. Preserve blinded coding and intervention rules.

## Verification
Planning performs no product edits, tests, gates, or formatters. Executors use native Godot entrypoints after implementation: import/parse; pure; scene; two-process network with seed 12345; visual shot profile; fixed-seed manual smoke. No addon is introduced.

## Escalation/Risk Gate
Maintainer + Architect approval is required to increase save version, alter serialized meaning, change starter contents/recipes/global combat, add dependencies/controller/world generation, broaden remote command support, implement deferred raid lifecycle, replace baselines, or pull any deferred surface into RT1. Data loss/duplication, unauthenticated mutation, outcome drift on replay, non-atomic migration, or a second interaction writer blocks release. Use bounded Executors by owner after freeze, Architect for ownership/OS primitive decisions, Critic at phase exits, Team for Phase 1 integration, and Ultragoal only for an explicitly expanded cross-phase scope.

## Verification Plan
### Automated
- **Pure:** UUID generation/migration/collision; identity lifecycle; command serialization/future protocol; registry binding; epoch rotation; immutable replay; ledger TTL/cap/outstanding; full reason precedence; validator/inventory transaction; exact recipe total; objective source/duplicate/out-of-order/legacy/skip; shelter adjacency/rays; stores/migration; interaction table; settings bus/scale.
- **Scene:** starter grant interruption; gather each cost; eat/craft/equip; pending/accepted/rejected ghost; campfire shelter/Rested positive and generic-comfort negative; Greyling evidence; title-to-world mode handoff; focus restore; KO/EN; save/reload every cursor.
- **Two-process:** unauthenticated/missing registry/forged actor; host and remote initialization; stale epoch; reconnect rotation/snapshot; old-ledger replay; packet loss/reorder/timeout; rate/cap pressure; simultaneous placement; inventory insufficiency; direct deferred mutation rejection; client raid no-op.
- **Visual:** 13 required states × 2 resolutions × 2 locales = 52 PNGs: spawn/objective, food/status, craft missing reason, equipped inventory, build valid, missing-workbench, overlap, unsupported, shelter/Rested, Greyling wind-up, low-stamina, pause/settings focus, save/load error. Manifest retains baseline/candidate hashes and semantic/layout assertions.

### Fixed fixture and evidence
Seed 12345, recorded Meadows coordinates/hash, noon/clear/no raid, starter grant exactly club/10 wood/6 stone/5 raspberries, one 20-HP Greyling 12 m from shelter after Rested, no debug buffs. Manifest records schema/build/Godot/profile/fixture/seed/coordinate/state/semantic assertions/locale/resolution/scale/input/time/weather/injections/PNG and baseline hashes/timestamp. Release packet contains approvals, reports, traces, rollback rehearsal, 52 images, contrast worksheet, visual/accessibility sign-off, anonymized playtest aggregates, deferred list, and Maintainer receipt.

## 3-scenario pre-mortem
1. **Replay/reconnect duplicates a build.** Warning: revision mismatch, second delta, or old epoch accepted. Mitigation: outcome recorded before send, retained epoch-keyed ledger, snapshot-on-uncertainty, chaos fixtures, hard release block.
2. **Tutorial still skips real gathering or Rested triggers elsewhere.** Warning: starter events complete gather rows, displayed remaining cost diverges, or generic comfort advances. Mitigation: canonical summed-cost fixture, per-cost source evidence, campfire-only shelter predicate, reload matrix, fresh-player rubric.
3. **Identity/local data or mode cutover corrupts state.** Warning: IDs change after move/reload, onboarding appears in world replication, failed load mutates sentinel, or `main.gd`/dev scripts directly set mouse/pause/input. Mitigation: deterministic migration/collision mapping, separate transactional store, detached apply, repository writer search, coherent rollback.

## Risks and mitigations
- **Identity substrate expands MVP:** freeze only fields needed for binding, persistence, starter/onboarding, and build; reject unrelated remote commands.
- **Host position remains client-influenced:** freeze age/displacement trust bounds and reject stale/outlier snapshots; do not claim anti-cheat beyond RT1.
- **Ledger limits conflict with retention:** backpressure new commands rather than evict protected outcomes; expose local diagnostics.
- **Windows replacement differs:** select/prove one same-volume primitive through adapter interruption fixtures before writer activation.
- **Starter transaction and local onboarding diverge:** authoritative grant record and local evidence are separate, idempotent, and reconciled by stable event IDs.
- **Shared files conflict:** enforce ordered ownership transfer and writer-last cutover; no parallel edits or dead aliases.
- **Programmatic KO/EN UI overflows:** numeric layout assertions, fixed matrix, bilingual sign-off.
- **Scope creep through raids/multiplayer:** guard/reject only; lifecycle and unsupported command kinds stay in deferred backlog and cannot block RT1.
