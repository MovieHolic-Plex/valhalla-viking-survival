# Architecture Review — Deliberate Gameplay, UI, and UX Improvement Plan

Reviewed immutable planner artifact: `.gjc/_session-019fb529-64a9-7000-884c-fad9579e6032/plans/ralplan/019fb529-64a9-7000-884c-fad9579e6032/stage-01-planner.md`, planner SHA-256 `adf77e211e0abd19d57f9c81a4f52ea6115ce596e78d8b52f1b20e6ffe3cd357`, planner `stage_n=1`.

## Summary
The planner correctly identifies the product problem and proposes strong UX principles, contract-first sequencing, deterministic QA, localization/accessibility gates, and a vertical-slice strategy. It is not yet executable safely: it combines incompatible state/authority domains, does not explicitly repair existing multiplayer command trust, defines onboarding that conflicts with starter grants, lacks a single interaction-mode owner, and expands the alleged slice into a near-total release overhaul. Revise Phase 0 around ownership and transactional contracts, then cut the first release train before implementation.

## Claims
- The current game is predominantly code-generated UI and centralizes mutable world data in the `GameState` autoload; `GameState.new_world()` resets world progression (`scripts/core/game_state.gd:40-56`).
- The current world save is a single-slot JSON writer. It truncates the live file directly and the loader never validates `version` before mutating live state (`scripts/core/save_system.gd:21-91`).
- UI interaction state is currently distributed across open-panel membership, chat visibility, `player.input_locked`, mouse capture, and `SceneTree.paused` (`scripts/ui/ui_root.gd:119-138,139-250`).
- Inventory UI directly removes and writes slots while carrying a hidden held stack, rather than using an atomic domain transaction (`scripts/ui/inventory_ui.gd:215-266`); the plan is right to require a contract repair.
- Multiplayer building is not presently host-authoritative in the security/correctness sense: the client consumes materials and reports success before acknowledgement (`scripts/building/build_system.gd:191-225`), while the host accepts `piece_id`, position, and yaw and calls unchecked `place_remote()` (`scripts/core/net.gd:399-414`).
- Every player construction grants club, wood, stone, and berries (`scripts/player/player.gd:126-130`); the proposed gather-first objective cannot infer actual gathering from inventory counts.
- Raid RNG/timing runs in every `SpawnManager`, with no host guard, and uses a 120-second await (`scripts/world/spawn_manager.gd:17-36,116-152`).
- The plan's screenshot, playtest, locale, resolution, UI-scale, gameplay-system, and multiplayer matrix is valuable release validation, but exceeds a focused first-30-minute implementation slice.

## Analysis
### Spec compliance
The plan covers the requested gameplay/UI/UX dimensions and preserves the existing identity and content foundation. Its explicit non-goals, early-loop metrics, Korean/English acceptance, keyboard navigation, deterministic scenarios, and no-hidden-tutorial-mechanics principle are aligned with the goal.

Compliance breaks at execution boundaries. A local tutorial cannot safely share one owner with authoritative raids and world progression. A build preview cannot agree with the host result while the host trusts unchecked client placement and the client spends resources optimistically. A gather milestone cannot mean actual gathering when all required resources are granted on construction. These are contract defects, not polish details.

### Architecture and strongest antithesis
The strongest case against the chosen plan is that it labels a broad product rewrite as a vertical slice. Phases 1–3 rebuild entry, settings, localization, input prompts, modal routing, HUD, inventory, crafting, building, map, death, combat feedback, raids, boat/fishing state, saves, and tests; Phase 4 then propagates to all late-game systems and multiplayer. Shared-theme and shared-contract changes make the stated per-surface fallback unrealistic. Without a cut line, parallel executors will stabilize moving interfaces rather than deliver a coherent slice.

The constructive path is to retain Option A but narrow its first release train: solo keyboard/mouse, clean/legacy save, title-to-spawn, eat, craft/equip, shelter/rest, one early encounter, death/recovery, save/reload, KO/EN at 1280x720 and 1600x900. Build shared primitives only as required by that flow. Map pin editing, controller prototyping, raids, boat/fishing HUD, late-game propagation, four-resolution full matrices, and broad multiplayer UX become named follow-ups unless baseline evidence proves they block the slice.

### Required boundary model
1. **Authoritative world state:** world progression, raid lifecycle/RNG, shared tomb/build/enemy outcomes. Owned by offline world or host and replicated as snapshots/events.
2. **Local player/onboarding state:** objective cursor, evidence, skip/dismiss/help state, local hint throttles. Keyed by player/world and unable to mutate authoritative mechanics.
3. **Profile settings:** locale, audio, UI scale, input/camera/accessibility preferences. Stored independently under `user://`; survives world deletion/change and is not transmitted.
4. **Presentation state:** selected tabs, focus stack, transient banners and pending commands. Never serialized into world progression.
5. **Interaction mode:** one state machine owns pause, gameplay locks, mouse mode, focus restoration, chat/death/modal precedence, and held-item cancellation/commit.

### Command and event shape
Use domain-specific result types or a tagged result—not one unbounded dictionary everywhere. Every mutating multiplayer command needs request ID, actor, expected revision/context, canonical server validation, exactly-once commit, and accepted/rejected acknowledgement. The UI may present optimistic pending feedback but may not consume inventory or claim success until authoritative acceptance. Events used for onboarding need stable semantic IDs and idempotency keys; inventory counts are durable predicates, not evidence that a gather action occurred.

### Gameplay-loop sequencing
Define objective semantics for already-owned items, first-run starter grants, out-of-order actions, legacy worlds, reconnects, shared container transfers, multiplayer pickups, repeated signals, and skipped objectives. A safe model records semantic evidence and re-evaluates durable predicates, advances monotonically, and never grants rewards. Shelter/rest needs an explicit predicate—required pieces, nearby fire/comfort, and successful rested/sleep state—rather than an ambiguous visual structure check.

### Performance
Signals/dirty updates are appropriate, but event volume needs budgets: aggregate stamina/status updates to meaningful changes; cap/pool combat notifications; avoid rebuilding generated UI trees on locale/scale changes; avoid per-frame glyph resolution and texture generation. Structural-support recomputation currently scans pieces and neighbor cells (`scripts/building/build_system.gd:274-329`); support visualization must not add per-frame full-set material churn. Define target frame budgets and profile worst cases (18 enemies, raid, 3,000 pieces, modal overlay) on minimum target hardware.

### Rollback
Do not retain old and new live UI implementations as a fallback after shared contracts diverge. Use small contract-first commits, additive readers before writer changes, coherent vertical-slice feature flags only where both paths share one domain contract, immutable fixtures, and release rollback by reverting a coherent commit set. Save writes require temp-file validation, flush/close, backup rotation, atomic rename, and backup recovery. Future-version saves must be rejected without mutating the running world; downgrade behavior must be declared.

## Root Cause
The plan treats a presentation overhaul as if a shared `ActionResult` and `GameState` expansion can bridge world authority, per-player progression, profile preferences, UI navigation, and network acknowledgement. Those domains have different owners, lifetimes, replication rules, and rollback requirements. Until Phase 0 separates them and defines transactional boundaries, later UI work will either poll internals, duplicate gameplay policy, or display success before authoritative completion.

## Findings
1. **HIGH — Separate world, player, and profile state ownership** (`stage-01-planner.md:67-70`). `GameState` cannot coherently own local tutorial state, host-authoritative raid state, and profile settings. Split stores and expose snapshots/signals.
2. **HIGH — Make authoritative command repair an explicit prerequisite** (`stage-01-planner.md:89-90`). Replace unchecked build replay with host-side canonical validation and acknowledged, idempotent commit before UI claims success or inventory changes.
3. **HIGH — Resolve onboarding predicates against starter grants** (`stage-01-planner.md:109-111`). Define first-run grant policy and distinguish semantic event evidence from inventory predicates, including out-of-order and legacy cases.
4. **HIGH — Specify a single interaction-mode owner** (`stage-01-planner.md:74-75`). Centralize pause/input/mouse/focus/chat/death/modal/held-item transitions and test same-frame precedence.
5. **HIGH — Cut the vertical slice to an executable release train** (`stage-01-planner.md:128-131`). Move raids, boat/fishing, controller, pin editing, late game, and full release matrix behind the first-session MVP unless evidence makes one blocking.
6. **HIGH — Define transactional save migration before adding fields** (`stage-01-planner.md:68-69`). Parse/migrate/validate detached data before application; use temp, backup, atomic replace, recovery, and future/corrupt-version tests.
7. **HIGH — Assign raid lifecycle exclusively to host world state** (`stage-01-planner.md:88-89`). Host/offline owner controls RNG, eligibility, spawning, persistence, cancellation, reconnect snapshots, and lifecycle epochs.
8. **MEDIUM — Replace dual-surface fallback with coherent rollback** (`stage-01-planner.md:205`). Revert coherent commit sets instead of preserving parallel old/new UI paths after shared contract changes.
9. **MEDIUM — Choose the test seam before contract implementation** (`stage-01-planner.md:98`). Default to a no-third-party headless runner with filesystem/clock/RNG/input/network adapters; separate pure, scene, two-process network, and visual suites.

## Recommendations
1. Rewrite Phase 0 deliverables as signed-off architecture artifacts: ownership/lifetime/replication matrix; typed action/result/event schemas; interaction-mode transition table; objective predicate/evidence table; save/settings schemas and migration/rollback policy; host/client command sequence diagrams.
2. Repair building authority before adding reason-rich UI. The canonical validator must be shared by local preview and host commit but run against each side's state; host outcome wins and returns a dominant reason plus authoritative deltas.
3. Make `SettingsStore` independent of `SaveSystem`; make onboarding per player/world; keep raids/world progression host-owned. `GameState` may be a façade but must not become an untyped owner of all three.
4. Specify objective IDs, versions, prerequisite alternatives, evidence sources, monotonic transitions, skip semantics, and legacy default policy. Decide whether starter grants remain; acceptance and copy must match that decision.
5. Introduce the interaction-mode controller before Settings/Help/keyboard navigation. Use a focus stack and explicit transition priority: death/disconnect/transition outrank chat and ordinary modals.
6. Establish transactional save I/O and fixtures before persisting objectives. Failed/future/corrupt loads must leave the current world untouched.
7. Cut Release Train 1 to the solo early loop and two core resolutions. Keep full matrix as release validation after the slice works; track deferred surfaces explicitly rather than implicitly carrying them in Phase 4.
8. Add performance budgets: no full UI rebuild per frame; bounded event coalescing; pooled transient feedback; support updates only on topology change; 60-fps profiling at 18 enemies/raid and 3,000 pieces.
9. Use the existing Godot runtime as the initial test harness to avoid dependency risk. Add a pinned addon only after a short capability gap record and architecture approval.

## Architectural Status
`BLOCK`

## Code Review Recommendation
`REQUEST CHANGES`

## Tradeoffs
| Option | Benefit | Cost/Risk | Recommendation |
|---|---|---|---|
| One expanded `GameState` + world save | Few files, fast initial wiring | Conflates profile/local/authority state; migration and multiplayer defects | Reject |
| Separate world, onboarding, settings stores | Correct lifetime/authority, focused tests, safer migration | More explicit interfaces | Required |
| Generic dictionary `ActionResult` everywhere | Quick prototyping | Weak schema, typo-prone reasons/context, hard evolution | Use only as a prototype; prefer tagged typed/domain results |
| Client optimistic placement with rollback | Immediate feel | Duplication/loss and misleading UX under rejection/latency | Pending visual only; commit on host acknowledgement |
| Keep old/new UI paths as fallback | Superficial rollback | Duplicate execution paths and divergent state contracts | Reject; coherent commit/release rollback |
| Full plan in one release | Broad transformation | High integration risk and no credible cut line | Reject |
| Early-loop release train then follow-ups | Delivers measurable value and stabilizes contracts | Deferred late-game consistency | Recommended |
