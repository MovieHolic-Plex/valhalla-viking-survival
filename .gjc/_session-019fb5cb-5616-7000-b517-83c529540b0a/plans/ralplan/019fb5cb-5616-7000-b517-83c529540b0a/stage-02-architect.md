# Architecture Review — Consensus Pass 2

Reviewed immutable revision: `.gjc/_session-019fb5c8-5727-7000-99ee-aa38bfbacf6c/plans/ralplan/019fb5c8-5727-7000-99ee-aa38bfbacf6c/stage-02-revision.md`, SHA-256 `dcc9e60a3f7f98d798177d5b79567cb31dd8c617ee9c983ce0064e820c194438`, `stage_n=2`.

## Summary
The revision materially improves every pass-1 concern: domains are separated, host acknowledgement precedes client commit, onboarding evidence has provenance, one interaction owner is named, persistence is transactional, rollback is coherent, tests have native seams, and the release train is sharply narrower. It is still not implementable safely: the replay contract contradicts itself, the host has no specified authoritative player/inventory registry, durable identity and onboarding storage are undefined, the starter loop cannot afford its required shelter, and raid acceptance crosses the declared deferred cut line.

## Claims
- Pass-1 save safety is resolved at plan level: detached parse/migrate/validate/apply, future-version rejection, temp validation, backup rotation, atomic replacement, backup recovery, immutable fixtures, and writer-last activation are explicit (`stage-02-revision.md:98-104,124-127,146-150`). This directly repairs the current loader, which mutates `GameState` before validating the complete payload (`scripts/core/save_system.gd:61-91`).
- Pass-1 interaction ownership is directionally resolved with a typed priority model and deterministic pairwise tests (`stage-02-revision.md:69-71,145`). Current writes are distributed across `UIRoot`, title/world transitions, and dev tooling (`scripts/ui/ui_root.gd:124-137,245-250`; `scripts/main.gd:218,375`; `scripts/dev/net_probe.gd:23-25`; `scripts/dev/screenshot_director.gd:212-213,387-400`), so the migration responsibility is not yet complete.
- Pass-1 optimistic building is correctly rejected: the plan requires pending-only client presentation, canonical host validation, atomic consume/create, authoritative deltas, and reconciliation (`stage-02-revision.md:74-84`). This addresses the current client-first consume/success and unchecked host `place_remote()` path (`scripts/building/build_system.gd:191-225,239-244`; `scripts/core/net.gd:399-428`).
- Pass-1 starter-grant ambiguity is substantially resolved by source-tagged events, durable predicates, an idempotent grant service, monotonic cursor, and legacy behavior (`stage-02-revision.md:86-96`). Current grants occur unconditionally during player construction (`scripts/player/player.gd:126-130`).
- Pass-1 broad scope is mostly resolved: RT1 is solo keyboard/mouse, two locales, two resolutions, shelter, one Greyling, and save/reload; map, controller, boat/fishing, broad raids, late game, and multiplayer polish are explicitly deferred (`stage-02-revision.md:36-58,129-137`).
- Pass-1 rollback and test-seam concerns are resolved in design: no dual live UI, coherent release rollback, reader-before-writer ordering, and filesystem/clock/RNG/input/network seams with pure, scene, two-process, and visual suites are explicit (`stage-02-revision.md:102-104,124-127,165-171,179-184`).

## Analysis
### Stage 1 — Spec compliance
The revision now answers the requested boundaries, authority, interaction state, save safety, execution ordering, test seams, and deferred-work cut line in concrete terms. Phase 0 is a real freeze gate with named artifacts and approvals, Phase 1 establishes safety foundations before presentation, Phase 2 wires only the RT1 loop, and Phase 3 prevents deferred findings from expanding scope.

Compliance still fails in the executable details. The RT1 grant and objective copy do not supply or teach acquisition of enough materials for the mandatory structure. Current recipes require 3 wood/2 stone for the hammer, 2 wood/5 stone for the campfire, 10 wood for the workbench, and 12 wood for one floor, three walls, and two roofs (`scripts/core/recipe_db.gd:48,313-316,335-342`): 27 wood/7 stone versus the retained 10 wood/6 stone, before any bed. The revision mentions gathering only missing hammer materials, yet requires the complete loop without external instruction (`stage-02-revision.md:40-44,90-94,141`).

The raid gate also exceeds its stated cut line. The summary promises only a correctness guard/ownership boundary, while acceptance requires persisted lifecycle, cancellation, reconnect snapshots, and epochs (`stage-02-revision.md:5-8,45-47,112,145`). Current raid state is transient inside `SpawnManager` and absent from the world save (`scripts/world/spawn_manager.gd:12-19,116-152`; `scripts/core/save_system.gd:21-46`), so this is a new subsystem contract, not merely a guard.

### Stage 2 — Architecture
The domain split is sound, but two boundaries remain unresolved. First, `OnboardingStore` is called local/non-replicated while its storage is described as a world-associated section and later as optional world-save metadata (`stage-02-revision.md:62-67,98-103`). A host-owned world save cannot safely own each client's private local progress. Second, all idempotency keys and onboarding indices require durable world/player identity, but the plan does not define creation, persistence, v1 migration, or reconnect binding for either. The current repository has only seed/name for world identity and ephemeral peer ID/name for networking (`scripts/core/game_state.gd:7-9`; `scripts/core/net.gd:27-28,65-72,225-244`).

The authoritative command model has two load-bearing contradictions. `Command` omits the `session_epoch` used by the dedupe key and stale-session rule (`stage-02-revision.md:74-78`). It also says retries return the exact final ack while defining a new `DUPLICATE` status and grouping duplicate handling with ghost removal (`stage-02-revision.md:76-82`). An accepted ack lost in transit can therefore replay as a semantically ambiguous duplicate, leaving client deltas unapplied or applied twice.

The strongest antithesis is that host-authoritative build repair quietly requires authoritative player-state architecture that RT1 does not assign. The host is supposed to derive inventory and position from its peer registry, but current remote proxies contain only interpolated position/animation/HP and no inventory (`scripts/entities/remote_player.gd:9-64`); clients author their own position stream (`scripts/core/net.gd:255-301`). Until Phase 0 defines authenticated sender-to-player/session binding and Phase 1 constructs host-owned inventory revision and a movement/range trust boundary, `NOT_OWNER`, `MISSING_MATERIALS`, and `OUT_OF_RANGE` are not implementable as claimed.

### Stage 3 — Constructive synthesis
Keep the selected architecture, but freeze four additional artifacts before implementation: (1) an identity/registration schema with host-issued session epoch and durable local player/world IDs; (2) a host player-state registry contract defining inventory authority, revision, movement trust, and reconnect snapshot; (3) an immutable command outcome model where replay metadata is separate from accepted/rejected outcome and client application is idempotent; and (4) a separate transactional local onboarding store keyed by the durable IDs. These additions repair the design without broadening UI scope.

For the gameplay cut, add explicit material-acquisition rows and copy for every required build cost, then choose whether the shelter anchor is the player position, a new marker, or a bed. If it is a bed, include its 10-wood cost and interaction in the objective/fixture; otherwise remove the undefined `bed/rest point` language. For raids, choose the narrow guard: host/offline-only RNG/spawn and rejection/no-op tests now; move persistence, cancellation, reconnect snapshot, and lifecycle epoch to the named raid follow-up.

### Stage 4 — Quality, security, and performance
The performance and visual gates are reproducible and appropriately bounded for RT1. Security remains blocked by sender identity and authoritative state provenance, not by missing validation reason coverage. Save safety is well specified, but onboarding must receive equivalent local transactional I/O semantics once its storage boundary is chosen.

## Root Cause
The revision repaired presentation-facing contracts faster than the underlying identity and authority substrate. It assumes a durable player/world identity and a host peer registry with authoritative inventory/position even though neither exists or is assigned, then layers replay, onboarding, and acceptance semantics on those assumptions. A second root cause is a mismatch between the declared narrow cut line and acceptance rows that still pull in full raid lifecycle behavior and an under-specified resource economy.

## Findings
1. **HIGH — Define one immutable replay outcome** (`stage-02-revision.md:78-82`). Exact-ack replay conflicts with `DUPLICATE`, and an originally accepted replay can be mishandled as rejection. Return the original accepted/rejected outcome byte-equivalently (with separate replay metadata) and make client delta application idempotent by request ID.
2. **HIGH — Make the onboarding loop resource-feasible** (`stage-02-revision.md:87-96`). The required path costs at least 27 wood/7 stone against a 10 wood/6 stone grant, while copy only mentions missing hammer materials. Add explicit build-resource acquisition objectives and define/cost the rest anchor.
3. **HIGH — Establish the authoritative peer registry first** (`stage-02-revision.md:74-80`). The current host has no authoritative remote inventory and only client-authored remote position. Define authenticated session/player binding, host inventory revision/transactions, movement trust, and reconnect state before build commands.
4. **HIGH — Align raid acceptance with the deferred cut line** (`stage-02-revision.md:112-145`). Persistence, cancellation, reconnect snapshots, and epochs are not a guard. Defer them, or explicitly assign and sequence a typed raid world snapshot; the narrow RT1 choice is recommended.
5. **HIGH — Define durable world and player identities** (`stage-02-revision.md:62-89`). World/player IDs used by onboarding and starter idempotency lack creation, persistence, legacy, collision, and reconnect policy. Add them to Phase 0 persistence and registration schemas.
6. **MEDIUM — Include every interaction-state writer in migration** (`stage-02-revision.md:69-113`). `main.gd` and dev tools bypass the proposed sole owner but are not assigned. Add them to the responsibility matrix and define title-to-`UIRoot` ownership handoff and test override commands.
7. **HIGH — Resolve onboarding persistence ownership** (`stage-02-revision.md:62-104`). Local/non-replicated onboarding conflicts with world-save-associated storage. Use a separate transactional local file keyed by durable world/player IDs, or change the authority/replication model explicitly.
8. **HIGH — Carry the session epoch in the command contract** (`stage-02-revision.md:74-78`). The stale-session and dedupe rules use an epoch absent from the envelope. Add a host-issued epoch bound to the RPC sender and test delayed packets from prior sessions.

## Recommendations
1. Block Phase 0 approval until findings 1, 3, 5, 7, and 8 are incorporated into command, identity, registration, persistence, and host-player-state artifacts.
2. Repair the exact RT1 objective/resource table and shelter anchor before freezing copy or fixtures; verify costs directly from canonical recipes.
3. Narrow raid RT1 acceptance to host/offline ownership guard plus no-client-spawn tests; retain full raid lifecycle as a named follow-up.
4. Expand the interaction migration owner list to all direct writers and require a repository search gate proving production code has one writer after Phase 1.
5. Preserve the revision's save strategy, phased ordering, native seams, visual/performance gates, rollback model, and deferred backlog unchanged.

## Architectural Status
`BLOCK`

## Code Review Recommendation
`REQUEST CHANGES`

## Tradeoffs
| Option | Benefit | Cost/Risk | Recommendation |
|---|---|---|---|
| Keep `DUPLICATE` as a third outcome | Easy replay visibility | Ambiguous original result and unsafe delta application | Reject; use immutable outcome plus replay flag |
| Add host-owned peer gameplay state | Makes ownership, inventory, range, and reconnect checks real | More Phase 0/1 substrate work | Required for touched cross-authority mutations |
| Store onboarding in world save | One file | Violates local/non-replicated ownership for clients | Reject |
| Separate local onboarding file | Correct privacy/lifetime and independent recovery | Requires durable IDs and another transactional store | Recommended |
| Full raid lifecycle in RT1 | Stronger multiplayer consistency | Expands scope into persistence/network subsystem | Defer |
| Host/offline raid guard only | Repairs current duplicate-client mutation risk | Leaves lifecycle UX/reconnect for follow-up | Recommended |
| Increase starter grant | Fast fixture feasibility | Changes balance/legacy expectations | Use only through stated balance approval |
| Teach gathering for exact build costs | Preserves grant/economy and teaches the real loop | Adds objective rows/copy | Recommended |
