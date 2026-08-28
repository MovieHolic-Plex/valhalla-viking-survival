# Consensus Revision Pass 4 — Solo Gameplay/UI/UX RT1, Remote Builds Fail Closed

## Summary
Deliver one bounded Release Train 1 (RT1): a solo keyboard/mouse first session from New World through starter onboarding, eating, gathering the complete material budget, crafting/equipping a hammer, building a campfire-anchored shelter, receiving Rested, defeating one Greyling, and save/reload. The release remains a visible gameplay/UI/UX overhaul with bilingual, responsive feedback and objective evidence.

RT1 has **no remote gameplay-command protocol and no remote build support**. Offline authority and the host's local player may use the validated placement transaction. A remote client cannot place, remove, refund, or interactively mutate a build: client callsites fail before inventory/world mutation, and legacy/forged host RPC requests terminate in a stable `REJECTED/UNSUPPORTED_IN_RT1` response without reaching placement, inventory, validation, or replication. Host-to-client piece snapshot/event projection remains read-only replication and is not a client mutation path. This cut removes every RT1 dependency on durable remote-player ownership, session epochs, old-epoch replay, outcome ledgers, ledger capacity, retry semantics, or remote inventory authority.

Authenticated durable-player registration, proof-of-possession and recovery, session epochs, replay/final-outcome retention, capacity/backpressure semantics, authoritative remote inventory, trusted movement, and remote multiplayer builds move together to the named **Multiplayer Authority Release (MAR1)**. They must not be partially introduced or claimed by RT1.

RT1 still repairs touched local contracts: durable local world/player identity for save/onboarding keys, separated world/onboarding/profile/presentation authority, one interaction-mode owner, transactional save/settings/onboarding I/O, semantic onboarding events, an atomic offline/host-local build transaction, and a host/offline raid mutation guard.

Estimated effort is 14–20 engineer-days plus 3 moderated playtest days after Phase 0 approval. Phase 0 must revalidate the estimate after Windows replacement behavior, local identity migration, remote-build rejection surfaces, and UI wireframes freeze. Stop after the exit evidence passes; do not pull MAR1 or other deferred work forward.

## Intent Diff
- **Replace pass-3 remote protocol design with coherent deferral:** remove the RT1 `Command`, `CommandAck`, registration, session-epoch, replay-ledger, rate-limit-ledger, remote inventory, trusted-movement, and pending authoritative-build-ghost contracts.
- **Fail closed at every existing remote build ingress:** guard `BuildSystem.try_place()` before `Inventory.consume()`, guard `BuildSystem.try_remove()` before destruction/refund, guard mutating `BuildPiece.interact()` branches for remote clients, turn `Net.request_place()`/remote remove requests into stable local rejections, and make host `_request_place()`/`_request_remove()` reject-only compatibility sinks or remove their RPC exposure when protocol-version gating proves old clients cannot call them.
- Preserve `_place_piece()` only as authority-to-client replication of already-authoritative pieces. It must never be callable by a client, consume/refund inventory, increment authoritative stats, or serve as evidence that remote building is supported.
- Show a localized multiplayer limitation in build selection/preview/action feedback: `Remote building is unavailable in this release` / `이 릴리스에서는 원격 건축을 지원하지 않습니다`. Do not show pending/success feedback or spend materials.
- Keep the existing starter grant but make it transactional and provenance-tagged; teach real gathering for the complete canonical RT1 cost.
- Define the campfire—not a bed—as the shelter rest milestone/reference point; `RESTED_APPLIED` counts only when the exact shelter predicate holds.
- Keep onboarding in a separate local transactional user store keyed by durable local IDs; never replicate it.
- Route `main.gd`, `ui_root.gd`, `net_probe.gd`, and `screenshot_director.gd` through the sole `InteractionModeController`.
- Narrow raid work to host/offline mutation guard plus remote rejection/no-op; defer raid lifecycle.
- Correct canonical build-cost ownership to `RecipeDB`.
- Bound identity to the current one-slot product: no world browser, duplicate/delete/multi-save discovery, remote identity, or cross-install account semantics in RT1.
- Preserve detached save validation, transactional replacement, settings/audio routing, bounded responsive UI, screenshots, operational playtests/performance gates, rollback, decision record, and pre-mortem.

## Decision Drivers
1. **Accepted product slice over premature protocol:** RT1 is explicitly solo. A visibly unsupported remote build path is safer and smaller than an incomplete security protocol.
2. **Fail closed:** no remote request may consume/refund inventory, create/destroy a host piece, increment authoritative progress, or produce false success.
3. **A feasible first-session loop:** onboarding teaches every material acquisition required by frozen recipes without changing starter contents or the economy.
4. **No loss, duplication, or false local success:** persistence, onboarding, build transactions, and UI feedback are hard gates.
5. **Clear ownership:** local/offline/host authority, local private stores, presentation, and interaction mode have one writer each.
6. **Repository-native execution:** programmatic GDScript UI and native Godot test entrypoints; no third-party dependency.
7. **Objective evidence:** fixed fixtures, explicit semantic screenshot assertions, trace markers, and fresh-player sessions decide completion.

Assumptions: desktop keyboard/mouse only; Korean and English required; existing programmatic UI remains; current single save slot is `world1`; starter grant remains club/10 wood/6 stone/5 raspberries; Greyling is the sole RT1 enemy; current world save `VERSION` remains 1 only if additive local IDs and grant fields validate safely. Any incompatible serialized change requires Maintainer approval and a version increase. Online sessions may still exist for legacy observation/combat paths, but RT1 advertises no multiplayer gameplay guarantee; remote building is explicitly unavailable and the entire multiplayer surface is outside RT1 acceptance except the negative mutation guards.

### Deliberate decision record (DR-RT1-P4)
- **Decision:** ship the satisfying solo shelter/Greyling/save slice and fail closed on remote build mutation. Keep only offline/host-local validated building. Defer the complete remote authority protocol to MAR1.
- **Rejected:** claiming ENet peer identity proves ownership of a durable player UUID; retaining old-epoch outcomes without reachable replay order; final rate-limit outcomes without storage; a partial remote placement protocol; silent remote no-op; optimistic remote inventory spending; parallel old/new UI; full raid lifecycle; increased starter grants; undefined bed/rest anchors.
- **Consequences:** all three pass-3 protocol blockers disappear because the dependent feature is removed, not papered over. RT1 has no durable remote identity, epochs, replay, retry, or capacity claims. Remote users receive a stable limitation result. The local gameplay budget can focus on onboarding, presentation, persistence, and playtest quality.
- **Revisit trigger:** MAR1 is separately approved with threat model, credential lifecycle, authenticated registration, authoritative player/inventory state, epoch and replay ordering, recordable capacity semantics, retry behavior, remote placement transaction, compatibility/versioning, and multi-process adversarial evidence as one contract.

## Options
| Option | Benefit | Cost/risk | Decision |
|---|---|---|---|
| Keep pass-3 remote command protocol | Possible remote building | Unresolved ownership, replay ordering, and ledger-full invariants; not needed for solo acceptance | Reject for RT1 |
| Add credentials/epoch/ledger now | Could close protocol gaps | Creates account recovery, storage, compatibility, and adversarial test scope | Defer together to MAR1 |
| Silently ignore remote mutation | Small patch | False feedback and no stable behavior | Reject |
| Fail-closed remote build guard with stable result | Safe, testable, right-sized | Remote building unavailable | **Choose** |
| Visual reskin only | Fast screenshots | Leaves onboarding, ownership, save, and feedback defects | Reject |
| Solo contract-first shelter/Greyling/save slice | Coherent and measurable | Defers multiplayer breadth | **Choose** |
| Full raid lifecycle now | Stronger reconnect semantics | New persistence/network subsystem | Defer |
| Host/offline raid guard only | Prevents remote mutation | Leaves lifecycle follow-up | **Choose** |
| Increase starter grant | Quick feasibility | Changes balance and masks gathering teaching | Reject |

## In scope / out of scope
### In scope
- New/continue/loading for clean and legacy-v1 `world1`; additive durable local world/player IDs and deterministic one-slot migration.
- Persistent, skippable onboarding: orient/move; obtain or possess food; eat; gather outstanding materials for the entire canonical RT1 build; craft/equip hammer; place campfire/workbench/basic shelter; receive Rested at the campfire shelter milestone; prepare for/defeat one Greyling; save/reload.
- Frozen `RecipeDB` baseline: hammer 3 wood/2 stone, campfire 2 wood/5 stone, workbench 10 wood, basic shelter 12 wood (one floor, three walls, two roofs), total 27 wood/7 stone. With starter resources, nominal outstanding is 17 wood/1 stone; objectives derive remaining cost from authoritative local inventory and actual spending.
- Starter-grant provenance, semantic event cursor, separate transactional onboarding store.
- One offline/host-local placement validator and atomic consume/create/revision/progress transaction.
- Remote build fail-closed behavior at UI/callsite/RPC ingress; stable localized `REJECTED/UNSUPPORTED_IN_RT1`; two-process adversarial negative fixture.
- Required HUD/objective/action/survival feedback; focused inventory/craft/build interactions; KO/EN copy; keyboard focus; 1280x720 and 1600x900 at 100% UI scale.
- Transactional world/settings/identity/onboarding persistence; profile locale, UI scale, master/SFX/ambient, sensitivity, invert Y, and reduced shake.
- Host/offline raid mutation guard only.
- Native pure, scene, two-process negative, visual, performance, and moderated evidence seams.

### Out of scope / deferred backlog
- **MAR1:** durable remote-player registration; credentials/proof-of-possession; rotation/revocation/recovery; authoritative remote inventory/player records; trusted movement; command envelopes/acks; session epochs; old-epoch replay; immutable outcome/rejection ledgers; capacity and retry semantics; remote placement/removal/refund/interactions; process-restart session restoration; compatibility negotiation; remote prediction/rollback; multiplayer UX polish.
- Map work; controller bindings/remapping/release UI; boats/fishing; full raid lifecycle serialization/cancellation/reconnect snapshots/raid epochs/UX/tuning; late game/biomes/bosses; chat/status; broad inventory/container/tomb/death recovery; all-biome tuning; 1920x1080/2560x1080 and 125% UI-scale release matrix.
- World browser, in-app duplicate/rename/delete/import, multiple-slot discovery, copied-save collision handling, cross-install identity, and account recovery. Existing persisted world name may change without changing an already-migrated ID; moving/renaming raw pre-migration files outside managed `world1` is unsupported.
- Remote support for craft/equip/eat/gather/inventory/container/combat/cooking/smelting/altar/raid mutations. Existing code outside the build/raid guards is not promoted to an RT1 multiplayer guarantee.
- New content/art/dependencies, world-generation rewrite, global recipe/economy changes, analytics transmission, or save-format rewrite.
- Controller is unsupported and not advertised.

## Authority and data contracts
### Local durable identities
- Before first save, a new world receives UUIDv4 `world_id` in its additive header. `user://identity.json` receives UUIDv4 `local_player_id` before world entry. Both are transactionally persisted and stable across ordinary reload and in-app world-name changes.
- For the one existing legacy slot, derive `world_id = UUIDv5(WORLD_LEGACY_NAMESPACE, "world1:" + decimal_seed)` from repository-available immutable inputs, then persist it in the migrated save before starter/onboarding writes. Derive legacy `local_player_id = UUIDv5(PLAYER_LEGACY_NAMESPACE, installation_id)`; if absent, generate and transactionally persist `installation_id` first.
- Because RT1 owns one fixed slot, it makes no collision-scan, duplicate-world, raw-file-copy, pre-migration move/rename, delete-cleanup, or multi-save claim. Those lifecycle semantics must be designed with a world manager before expansion.
- Fixtures cover new IDs, repeat migration, persisted-name change after migration, restart, missing installation ID, malformed/future identity, interrupted write, and backup recovery. No ID is sent as proof of remote ownership.

### Domain ownership
| Domain | Sole mutation owner | Storage/lifetime | Replication |
|---|---|---|---|
| World, pieces, enemies, local authoritative inventory/grant | Offline authority or host's local authority | transactional `world1` save | authority snapshots/events only; no remote request mutates it |
| Onboarding | local `OnboardingStore` | `user://onboarding.json`, keyed `(world_id, local_player_id)` | never transmitted |
| Local identity | `IdentityStore` | `user://identity.json` | never treated as remote credential |
| Profile settings | `SettingsStore` | `user://settings.json` | never transmitted |
| Presentation/limitation feedback | owning UI component | memory only | never authoritative |
| Interaction mode | sole `InteractionModeController` under title/UI root handoff | memory only | only local effects |

`GameState` remains a world facade and does not own onboarding, settings, identity, transient feedback, or interaction state. Schemas use tagged records/enums with exact required types, bounded strings/arrays, finite numeric checks, known enum checks, duplicate-key rejection after parse normalization, and a maximum document size frozen in Phase 0.

### Offline/host-local build transaction
- `RecipeDB` is the canonical piece/cost owner. Client preview is advisory. `BuildSystem` performs the existing geometric checks plus canonical recipe, range, piece limit, station, materials, water, ground, and overlap validation from local authoritative state.
- Dominant reason order is `UNKNOWN_PIECE > OUT_OF_RANGE > PIECE_LIMIT > MISSING_STATION > MISSING_MATERIALS > INVALID_WATER > INVALID_GROUND > OVERLAP > UNSUPPORTED_IN_RT1 > ACCEPTED` for applicable local requests; remote callers short-circuit to `UNSUPPORTED_IN_RT1` before this validator, so they cannot use validation as a mutation or authority oracle.
- One synchronous local transaction validates, consumes exact materials, creates the piece, updates support/revisions/stats/onboarding evidence, and emits success. Any failure creates no piece, consumes no materials, changes no revisions/stats/evidence, and emits one localized reason. Boat and all non-RT1 recipes remain outside acceptance.
- Removal/refund is allowed only for offline/host-local authority under existing local policy. Remote removal is rejected before lookup/destruction/refund.

### Exact remote-build removal/guard surfaces
1. **`scripts/building/build_system.gd::try_place()`**: first branch after local input eligibility checks is `Net.remote_build_block_reason()`. When remote, return a typed rejection and show the limitation before `RecipeDB` validation, `Inventory.consume()`, boat creation, `_spawn_piece()`, stats/evidence, SFX success, support recompute, or `Net.piece_placed()`.
2. **`BuildSystem.try_remove()`**: remote branch occurs before target authority lookup, `Net.piece_removed()`, `destroy(true)`, refund, support recompute, stats, or evidence.
3. **`BuildSystem.place_remote()`**: rename/restrict to an authority-snapshot projection such as `apply_authority_piece_snapshot()`; it is reachable only from authority-origin `_place_piece()` after Godot RPC authority checks. It cannot consume/refund, increment authoritative stats/evidence, or be called by remote request handlers.
4. **`scripts/core/net.gd::request_place()` and remote remove sender**: no request is sent. Return `RemoteMutationResult {outcome=REJECTED, reason=UNSUPPORTED_IN_RT1, mutation_kind}` to UI. A release build has no hidden/dev bypass.
5. **`Net._request_place()` and `Net._request_remove()`**: delete RPC exposure if protocol/version disconnect guarantees make them unreachable. Otherwise retain minimal reject-only legacy sinks through RT1: verify host context, capture sender solely for the reply, send `_remote_mutation_rejected(kind, UNSUPPORTED_IN_RT1)`, and return. They MUST NOT call `_build_system()`, `place_remote`, `piece_placed`, net-piece lookup/erase, inventory, stats, save, or broadcast. The sink is not a command protocol and stores no identity, epoch, retry, or ledger state.
6. **`BuildPiece.interact(player)` mutating branches** (door state, bed/spawn, container, cooking, smelting/kiln, crop harvest, portal) and any build-menu action: a remote-client guard produces the same limitation before mutation. Station UI may be inspected only where it cannot mutate; RT1 acceptance assumes solo use.
7. **Host-to-client `_place_piece()`/initial piece roster**: remains authority-only replication of host-created state. Assert remote sender cannot invoke it. Applying a snapshot changes only the replica, never host inventory/world, and never displays client-request success.
8. **UI/UX:** build menu and preview may remain visible to explain the limitation, but confirm input yields one toast/status reason, red/disabled non-color iconography, no pending ghost, no success SFX, no material delta, and no objective advance. Help/multiplayer panel states the same limitation in KO/EN.
9. **Repository guard search:** Phase 0 inventories all direct callers of `_spawn_piece`, `place_remote`, `piece_placed`, `_request_place`, `_request_remove`, `destroy(true)`/refund paths, and mutating `BuildPiece.interact` branches. Any additional remote ingress is routed to the same rejection or removed; no fallback write is allowed.

### RT1 mutation matrix
| Area | Offline/host-local | Remote-client RT1 behavior | Decision |
|---|---|---|---|
| Placement | atomic validated transaction | `REJECTED/UNSUPPORTED_IN_RT1`; zero host/client authoritative mutation | Local only |
| Removal/refund | local authority policy | same stable rejection before lookup/refund | Local only |
| Piece interactions | local authority behavior | same stable rejection before mutation | Local only |
| Gather/pickup/drop recovery | local authority emits source-tagged event | no new remote command; no direct authoritative client write | Solo evidence only |
| Craft/equip/eat | local inventory transaction | stable unsupported where invoked remotely | Solo only |
| Inventory/container/tomb | local authority | unsupported; no fallback | Defer |
| Combat/ammo/cooking/smelting/altar | existing local ownership unchanged | no RT1 remote guarantee | Defer |
| Raid RNG/eligibility/spawn | host/offline guard | remote call rejected/no-op | Guard only |
| Save/load | store owners | remote cannot write host world | Transactional repair |

### Interaction mode contract
Priority remains `DISCONNECTED > TRANSITION > DEATH > PAUSE > SETTINGS/HELP > CHAT > INVENTORY/CRAFT/BUILD_MENU > GAMEPLAY`. The controller alone writes input lock, offline tree pause, mouse mode, active primary modal, focus stack, and held-item resolution. Online pause locks local gameplay without pausing the tree.

`ui_root.gd`, `main.gd` title/world transitions, `net_probe.gd`, and `screenshot_director.gd` emit typed requests; none directly set these effects. Dev override requests are explicit, unavailable in release builds, and traverse the same transition path. Title ownership exists before `UIRoot`; transition hands the same controller to the world UI without a second writer. Same-frame requests resolve by priority, release closes/restores focus deterministically, and no attack/build input leaks through a modal.

### Onboarding, full costs, and campfire milestone
- Starter delivery is an authoritative local world transaction keyed `starter/v1/<world_id>/<local_player_id>`, persisted before inventory delivery and reconciled after interruption. It emits stable, source-tagged acquisition events. Existing unconditional `_ready()` grants in `player.gd` are removed after migration.
- `OnboardingStore` schema 1 contains records keyed by `(world_id, local_player_id)` with `objective_version`, monotonic cursor, completed IDs, skip state, and evidence IDs. It uses validated temp, backup rotation, same-volume replacement, and recovery like settings. Corruption never changes world/inventory; recover backup or restart at earliest durable predicate with one warning.
- Objectives: orient/move; possess food; eat; gather outstanding hammer cost; craft/equip hammer; gather campfire cost; place campfire; gather workbench cost; place workbench; gather six-piece shelter cost; build one floor/three walls/two roofs around campfire; enter and receive Rested; defeat Greyling; save/reload. Every gather row shows authoritative remaining amount and requires both inventory predicate and `GATHER|PICKUP|DROP_RECOVERY` evidence. Starter provenance may satisfy possession/preparation, never gather-only evidence.
- `RecipeDB` fixtures prove 27 wood/7 stone total and 17 wood/1 stone nominal shortfall. Actual rows recalculate after prior spending; there is no hidden grant or hard-coded shortfall.
- Campfire is the sole RT1 rest reference; no bed is required. Predicate: one player-owned campfire and workbench, one connected floor, three walls, two roofs within 6 m of campfire center; persisted owner ID; one adjacency component connected to nearest floor; upward rays at center and four fixed 0.5 m horizontal offsets with at least 4/5 hitting connected player-owned roof pieces. `RESTED_APPLIED` emits only when the local authoritative player is within 3 m, all checks pass, and normal rest duration completes. Generic comfort elsewhere does not advance.
- Stable `event_id` consumption is once-only; cursor monotonic; durable predicates recover out of order. Legacy world starts at earliest incomplete predicate with `LEGACY_INFERRED`, without duplicate grant/message/reward. Skip persists locally and changes no game state; Help remains available.

### Persistence, settings, and rollback
- World load is read -> detached parse -> reject malformed/future/oversize/non-finite -> additive migration -> full validation -> one apply. Failure leaves preloaded sentinel state untouched.
- World/settings/identity/onboarding writes use canonical `.tmp`, flush/close, reparse/validate, rotate a valid current file to `.bak`, then a Phase-0-selected Windows same-volume atomic replacement primitive. Replacement failure preserves current or backup and reports recoverable error. Writers stay disabled until interruption fixtures pass.
- `VERSION=1` remains only if IDs/grant fields are safe additive defaults. Onboarding row cleanup for world deletion is not an RT1 operation because world deletion is out of scope.
- Settings are profile-global and apply live: locale, UI scale, Master/SFX/Ambient, sensitivity, invert Y, reduced shake. Phase 0 inventories/assigns `sfx.gd` routing, wind/ambient creation in `main.gd`, bus artifact/runtime setup in `project.godot` or the selected bus layout, sensitivity/invert consumption in `player.gd`, and every camera/FX shake writer. Channel probes must isolate SFX and Ambient from each other while Master affects both. Reduced shake scales every inventoried source through one setting.
- Rollback is coherent: additive readers/schemas first, stores/controller/local validator second, callsite cutover third, writers last. Disable new writers before code rollback; retain additive readers and user files. Never restore unsafe remote request handlers or unconditional starter writes. Immutable clean/v1/corrupt/future/interrupted/backup fixtures remain release artifacts.

## File-level changes
One owner edits a shared file at a time; ownership transfer is explicit.

| Owner (estimate) | Files/contracts | Change |
|---|---|---|
| Architect (2d) | contracts, fixtures, sequence diagrams | solo authority, exact remote rejection surface, one-slot identity, objective/cost/shelter, interaction, persistence, settings, MAR1 follow-up |
| Core/state (3–4d) | `game_state.gd`, `save_system.gd`, focused identity/settings/onboarding stores and event records | additive IDs, detached migration, transactional stores, grant/cursor |
| Network/build (2–3d) | `net.gd`, `build_system.gd`, `build_piece.gd`, `inventory.gd` | delete/disable unsafe requests, reject-only sink, authority-only projection, local atomic validator/transaction, remote guards |
| Interaction/UI (3–4d) | controller, `ui_root.gd`, `main.gd`, `hud.gd`, inventory/craft/build/theme UI | sole interaction owner, handoff, responsive UX, limitation/reason/focus feedback |
| Progression (2–3d) | `player.gd`, objectives, `loc.gd`, `recipe_db.gd`, gather/rest/enemy adapters | exact cost copy, provenance, campfire shelter, Greyling chain |
| Settings/audio (1–2d, coordinated) | `sfx.gd`, `main.gd`, `player.gd`, camera/FX shake sites, `project.godot`/bus artifact | bus isolation, sensitivity/invert, reduced shake, live profile application |
| World/gameplay (1d) | `spawn_manager.gd`, `enemy.gd` | host/offline raid guard; Greyling event/fixture |
| Tools/QA (3–4d) | `net_probe.gd`, `screenshot_director.gd`, native test entry/adapters/manifests | typed dev mode requests, adversarial two-process rejection, deterministic suites/captures/traces |
| Docs (0.5d) | `README.md` | solo scope, remote-build limitation, controls/settings/test/capture guidance, MAR1 deferral |

Shared-file order: Core lands additive readers/stores; Network/build owns and lands fail-closed guards plus local transaction; Progression then owns inventory/player adapters; Settings/audio owns its listed `player.gd`/`main.gd` pass; Interaction owns controller plus final `main.gd`/UI cutover; Tools land dev-script cutovers after controller freeze; world guard/docs follow. No parallel edits to `net.gd`, `inventory.gd`, `player.gd`, `main.gd`, `build_system.gd`, or controller callsites.

## Sequencing and dependencies
### Phase 0 — Contract freeze (2 days)
Freeze baseline manifest; solo authority and remote-rejection diagrams; exhaustive mutation ingress/callsite matrix; reject-only RPC/version decision; typed limitation result and KO/EN copy; one-slot identity schemas/migration; exact `RecipeDB` cost/objective table; campfire geometry; interaction transition/handoff table; world/onboarding/settings schemas and bounds; Windows replacement decision; audio bus/UI-scale/reduced-shake design; UI wireframes; performance markers; screenshot assertions; playtest rubric; owner/approver table; MAR1 follow-up contract.

**Exit gate:** Architect, network, core, UI, QA, and Maintainer approve every artifact; `request_place` can no longer reach `place_remote`; every remote build ingress terminates before mutation; canonical fixture is 27 wood/7 stone; identity uses available one-slot inputs; Windows replacement spike preserves a valid copy; settings callsites have owners; estimate is reaffirmed/revised. Stop if remote ingress cannot be fail-closed, local consume/create cannot be atomic, or replacement cannot preserve valid data.

### Phase 1 — Safety foundations (5–7 days)
Land additive local identity/readers/stores, remote-build rejection and authority-only replication split, local placement transaction, interaction controller and direct-writer cutovers, settings/audio substrate, native seams, and raid guard. Writers activate last.

**Exit gate:** local identity migration is stable; direct and forged remote placement/removal/piece-interaction requests mutate zero host inventory/world/stats/evidence and visibly reject; offline/host-local placement validates and mutates once; transactional interruption recovery passes; repository search finds one interaction writer and no remote build-to-mutation path; client raid call cannot spawn.

### Phase 2 — RT1 gameplay/UI/UX loop (5–7 days)
Wire exact gather rows, starter provenance, eat/craft/equip, campfire/workbench/shelter/Rested, Greyling, save/reload, live settings, and bilingual responsive UI. No MAR1 or deferred raid work.

**Exit gate:** clean and legacy fixtures complete at both resolutions/locales; every recipe cost is taught/acquired; campfire predicate alone gates `RESTED_APPLIED`; reload at every cursor is monotonic; no duplicate grant/message; keyboard focus, action reasons, survival feedback, and save status are usable; remote limitation is clear without false success.

### Phase 3 — Evidence/release (3 QA days)
Run automated suites, 52-shot manifest, accessibility review, measured performance traces, moderated sessions, save/rollback rehearsal, and the two-process remote-build negative test. Fix only RT1 failures; backlog deferred findings.

**Exit gate:** all acceptance/evidence passes and Maintainer signs go/no-go. Data loss/duplication, any remote build mutation, false success, interaction ownership, clipping, accessibility, or solo loop failure blocks release. MAR1 and deferred raid lifecycle do not.

## Acceptance criteria
### Solo authority and remote fail-closed behavior
- Offline and host-local placement uses `RecipeDB`, creates exactly one valid piece, consumes exact materials once, increments stats/evidence once, and returns one reason. Every rejection leaves inventory, world, revisions, stats, and onboarding unchanged.
- In a two-process host/client fixture, snapshot host inventory hash, piece-set hash/count, save-dirty/revision, build stat, and onboarding evidence; snapshot client material count. A normal remote UI placement attempt, direct `Net.request_place`, forged legacy `_request_place.rpc_id(1, ...)`, replayed request, malformed/unknown piece, out-of-range transform, and 100-request burst each return/display `REJECTED/UNSUPPORTED_IN_RT1`. After idle/network drain and save/reload, every host snapshot is byte/semantically unchanged and client materials/evidence are unchanged; no host broadcast/success sound occurs.
- The same fixture covers remote remove/refund and one representative mutating `BuildPiece.interact` branch. Existing host piece remains identical; no refund, door/state change, container/cook/smelt/crop mutation, save revision, or evidence change occurs.
- Authority `_place_piece` projection cannot be invoked by a remote sender. A legitimate host-local placement may replicate once to the client, but the client projection does not spend client materials or count as remote-request success.
- UI build confirm in a remote session gives one KO/EN limitation message with disabled/error icon plus text, no pending/success ghost, no success SFX, and no tutorial advance. Help states multiplayer building is deferred.
- No RT1 schema, test, UI claim, or exit gate names/depends on remote durable identity, registration credentials, authoritative remote inventory, session epoch, stale-epoch replay, retry ledger, or capacity ledger.

### Identity, tutorial, shelter, interaction, and raid
- New IDs are UUIDv4 and stable. One-slot legacy UUIDv5 migration repeats deterministically, persists before dependent writes, remains stable after persisted world-name changes/restart, and recovers interrupted identity/save writes. No remote-authentication claim is made.
- Cost fixture proves hammer + campfire + workbench + shelter = 27 wood/7 stone and onboarding teaches each outstanding acquisition. No hidden grant/external instruction is needed.
- Starter grant occurs exactly once across create/load/interruption. Starter events cannot satisfy gather-only rows.
- Campfire is the only RT1 rest reference; no bed required. Exact ownership, adjacency, distance, five-ray coverage, and rest-duration predicate pass before `RESTED_APPLIED`; generic Rested elsewhere does not advance.
- Cursor/evidence are monotonic/idempotent under duplicate/out-of-order events and reload at every objective. Skip is local/persistent and changes no game state.
- `InteractionModeController` is sole production writer, including title/world transition and both dev automation scripts. Every same-frame priority pair leaks no attack/build input; release cannot invoke dev override.
- Raid RNG/eligibility/spawn runs only host/offline. Remote invocation rejects/no-ops and spawns nothing. Raid persistence/cancellation/reconnect/epoch/UX/tuning have no RT1 implementation or acceptance dependency.

### Persistence and settings
- Onboarding exists only in `user://onboarding.json`, keyed by local durable IDs, and survives restart. Corrupt/current/backup/interrupted behavior never changes world/inventory.
- Clean/current-v1/missing-additive/corrupt/future/oversize/non-finite/temp-interrupted/valid-backup world and identity/settings/onboarding fixtures leave sentinel live state unchanged on failure and recover either complete prior or complete new bytes, never a hybrid.
- Settings apply live and remain profile-global. Master affects both channels; SFX and Ambient probes isolate their own channel. Sensitivity/invert update the player path. Reduced shake measurably reduces every inventoried source without suppressing essential non-color cues. UI scale uses the frozen root/theme path.
- Rollback rehearsal preserves saves, IDs, onboarding, settings, immutable fixtures, and fail-closed remote behavior.

### UI, accessibility, performance, screenshots, and playtests
- At 1280x720 and 1600x900, KO/EN, 100%: safe margins >=24/32 px; centered 240x160 reticle exclusion; no critical overlap; scroll instead of body text below 16 px/critical below 18 px; contrast >=4.5:1 normal and >=3:1 large/non-text; validity/focus/status/limitation have non-color cues.
- Performance on Windows 11/Ryzen AI MAX+ 395/Radeon 8060S release build: discard first 30 seconds; use engine monotonic trace markers. For 200 local actions, start at input dispatch and end at first rendered feedback, P95 <=100 ms and none >150 ms. For 200 remote unsupported build attempts, start at confirm/RPC receipt and end at rendered rejection, P95 <=100 ms locally and host rejection round-trip is reported separately. For a 120-second fixed combat run after warm-up, frame P95 <=16.67 ms and P99 <=25 ms from engine frame traces; record build/hash/background load.
- Fresh cohort N=10: >=8 independently finish the chain and identify save/continue within 20 minutes; >=8 explain next action/purpose; >=7 survive the prepared Greyling; median encounter 20–60 seconds; median per-participant longest confused interval <=90 seconds. Returning N=5 all continue without duplicate grant/reward and find Help.
- Moderator reads a fixed neutral intro, gives no hint for 120 seconds, then records coded intervention `navigation|objective|control|system|bug` with timestamp; an independent reviewer blinded to participant/session labels codes video/notes, disagreements resolve before aggregate. Any intervention means the affected objective was not independent.

## Verification
Planning performs no product edits, tests, gates, or formatters. Executors use native Godot entrypoints after implementation: import/parse, pure, scene, two-process negative with seed 12345, visual shot profile, performance trace, and fixed-seed manual smoke. No addon is introduced.

## Escalation/Risk Gate
Maintainer + Architect approval is required to increase save version, alter serialized meaning, change starter contents/recipes/global combat, add dependencies/controller/world generation, broaden any remote mutation support, remove the reject-only compatibility sink without version proof, implement MAR1/raid lifecycle, replace baselines, or pull deferred surfaces into RT1. Data loss/duplication, any remote request reaching host build mutation, false remote success, non-atomic migration, or a second interaction writer blocks release.

Use bounded Executors by owner after freeze; Architect for authority/Windows primitive/schema decisions; Critic at phase exits; Team for Phase-1 shared-file integration; Ultragoal only for explicitly expanded cross-phase or MAR1 scope.

## Verification Plan
### Automated
- **Pure:** UUIDv4/one-slot UUIDv5 migration; identity lifecycle; schema bounds/future rejection; local validator/reason precedence/atomic transaction; exact `RecipeDB` total; objective source/duplicate/out-of-order/legacy/skip; shelter adjacency/rays; store recovery; interaction transition table; settings bus/scale/shake; typed `UNSUPPORTED_IN_RT1` result.
- **Scene:** starter interruption; gather each cost; eat/craft/equip; local build valid/invalid reasons; remote build disabled/rejected presentation; campfire shelter/Rested positive and generic-comfort negative; Greyling evidence; title-world handoff; focus restore; KO/EN; save/reload every cursor.
- **Two-process:** normal/direct/forged/replayed/malformed/burst remote placement; remove/refund; representative piece interaction; authority-RPC spoof; before/after host inventory/world/save/stat/evidence hashes; legitimate authority snapshot projection; client raid no-op. There is deliberately no epoch/replay/capacity fixture.
- **Visual:** 13 states x 2 resolutions x 2 locales = 52 PNGs. Assertions per state: spawn/objective has readable next action and safe reticle; food/status shows icon+label+duration; craft-missing names item/count; equipped inventory shows slot+focus; build-valid has shape+text cue; remote/unsupported has limitation reason and no success/pending cue; missing-workbench names station; overlap names collision; shelter/Rested shows predicate completion/status; Greyling wind-up remains visible outside HUD; low stamina uses text/icon; pause/settings restores focus and exposes live values; save/load error names recoverable action. Each image asserts safe margins, reticle exclusion, font minimum, no truncation, focus marker, contrast class, and expected semantic keys. Manifest stores baseline/candidate hashes and layout assertions.

### Fixed fixture and evidence
Seed 12345, recorded Meadows coordinates/hash, noon/clear/no raid, starter exactly club/10 wood/6 stone/5 raspberries, one 20-HP Greyling 12 m from shelter after Rested, no debug buffs. Manifest records schema/build/Godot/profile/fixture/seed/coordinate/state/assertions/locale/resolution/scale/input/time/weather/injections/PNG hashes/timestamp. Performance traces record markers/sample count/warm-up/hardware/build hash. Release packet contains approvals, test reports, negative-test host/client traces and hashes, rollback rehearsal, 52 images, contrast worksheet, visual/accessibility sign-off, anonymized playtest coding/aggregates, deferred list, MAR1 contract, and Maintainer receipt.

## MAR1 follow-up contract
MAR1 is one release-level design/implementation gate, not a menu of independent RT1 patches. Before any remote build mutation is enabled it MUST define and prove:
1. threat model and host-verifiable durable-player credential/proof-of-possession;
2. first registration, reconnect challenge, credential storage/rotation/revocation/recovery, duplicate-live-binding, and host-local path;
3. authoritative remote inventory/player ownership and save lifecycle;
4. trusted movement and placement-validation boundary;
5. versioned command/ack schema and deterministic rejection precedence;
6. session-epoch issuance/rotation and a rule that consults authenticated retained finalized outcomes before unknown stale-epoch rejection, if old-epoch replay is supported;
7. bounded final-outcome retention whose count/byte accounting can always record admission/capacity outcomes, or explicitly non-final transport backpressure;
8. retry, timeout, disconnect, process-restart, and snapshot reconciliation semantics;
9. atomic placement/removal/refund and exactly-once client delta application;
10. compatibility negotiation that keeps RT1 peers fail-closed;
11. pure, sequence, two-process, adversarial stolen-ID, old-epoch accepted/rejected/unknown, count/byte-capacity, reconnect, packet loss/reorder, and mutation invariants;
12. Maintainer/Architect security approval and migration/rollback plan.

Until all twelve are approved and pass, `UNSUPPORTED_IN_RT1` remains normative and no remote build writer is activated.

## 3-scenario pre-mortem
1. **A legacy RPC still creates/removes a host piece.** Warning: `_request_place` reaches `_build_system`, host piece hash/revision changes, or remote sees success. Mitigation: reject-only ingress, sender/authority test, 100-request burst, repository call graph/search, hard release block.
2. **Tutorial skips gathering or Rested triggers elsewhere.** Warning: starter events complete gather rows, displayed remainder diverges from `RecipeDB`, or generic comfort advances. Mitigation: canonical summed-cost fixture, per-cost source evidence, campfire-only predicate, reload matrix, fresh-player rubric.
3. **Identity/local data or mode cutover corrupts state.** Warning: IDs change after migration/reload, onboarding enters world replication, failed load mutates sentinel, or `main.gd`/dev scripts directly set mouse/pause/input. Mitigation: one-slot deterministic migration, separate transactional store, detached apply, repository writer search, coherent rollback.

## Risks and mitigations
- **Remote guard misses a side door:** enumerate sender and receiver callsites plus direct spawn/destroy/refund/interact methods; adversarial two-process hashes; no fallback.
- **Reject-only sink is mistaken for supported protocol:** name only the stable limitation result, store no command state, document it as compatibility guard, and forbid product success/pending UI.
- **Host replication confused with client authority:** split/rename projection API, authority RPC annotation, assert no inventory/stats/evidence effects.
- **Solo scope feels infrastructure-heavy:** Phase 2 and visual/playtest gates remain dominant release evidence; no MAR1 implementation consumes RT1 schedule.
- **One-slot identity limits future world management:** state the boundary, use persisted UUID now, and defer copied/multi-slot lifecycle to world-manager design.
- **Windows replacement differs:** prove one same-volume primitive with interruption fixtures before writer activation.
- **Starter transaction/onboarding diverge:** separate authoritative grant record and local idempotent evidence linked by stable event IDs.
- **Shared-file conflicts:** ordered owner transfer, writer-last cutover, no parallel edits/dead aliases.
- **KO/EN overflow/accessibility:** numeric layout assertions, semantic screenshot checks, bilingual sign-off.
- **Scope creep through multiplayer/raids:** stable reject/guard only; MAR1 and raid lifecycle cannot block or enter RT1 without escalation.
