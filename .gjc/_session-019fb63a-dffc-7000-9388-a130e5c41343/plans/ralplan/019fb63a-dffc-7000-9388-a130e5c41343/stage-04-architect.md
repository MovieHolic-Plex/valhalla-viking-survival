## Summary
Pass 4 coherently removes remote building from RT1 and replaces the pass-3 protocol with fail-closed client, host-RPC, replication, interaction, and UI boundaries. That resolves the remote identity/epoch/replay/ledger blockers without sacrificing the solo product loop, but four material contract gaps make the plan not yet executable as written: zero-shortfall onboarding, shelter rest timing, duplicate-key validation, and the atomic local build commit seam.

## Claims
- Remote build mutation is removed rather than hidden behind a fallback. The plan names current mutable ingress in `scripts/building/build_system.gd` and `scripts/core/net.gd`, requires client short-circuiting before spend, reject-only legacy host sinks, and authority-only snapshot projection. This matches inspected code: `BuildSystem.try_place()` currently consumes before `Net.request_place()` (`scripts/building/build_system.gd:196-228`), `_request_place()` currently calls `place_remote()` and broadcasts (`scripts/core/net.gd:399-425`), and `_request_remove()` currently destroys/refunds (`scripts/core/net.gd:438-450`).
- The remote protocol deferral is coherent. RT1 no longer depends on durable remote identity, registration, session epochs, replay/final-outcome storage, remote inventory, or movement trust; all are moved as one contract to MAR1. A typed `REJECTED/UNSUPPORTED_IN_RT1` result preserves visible product feedback and negative verification.
- Read-only authority projection is correctly distinguished from command ingress. Current `_place_piece()` is authority RPC and uses `place_remote()` (`scripts/core/net.gd:417-425`); the planned rename/restriction plus spoof test makes that boundary explicit without disabling host-created piece replication.
- State/UI sequencing is broadly sound: additive readers and safety guards precede writers and gameplay, the sole interaction controller includes title and dev scripts, and evidence/release follows a runnable solo loop. Inspected direct writers in `scripts/main.gd:218,375`, `scripts/ui/ui_root.gd:129-137,247-250`, `scripts/dev/net_probe.gd:24`, and `scripts/dev/screenshot_director.gd:213,388,400,511` justify the explicit cutover inventory.
- Canonical product costs match the repository: hammer is 3 wood/2 stone (`scripts/core/recipe_db.gd:48`); campfire 2 wood/5 stone and workbench 10 wood (`scripts/core/recipe_db.gd:313-316`); one floor, three walls, and two roofs are 12 wood (`scripts/core/recipe_db.gd:335-342`). Total 27 wood/7 stone and starter 10 wood/6 stone (`scripts/player/player.gd:126-130`) yield 17 wood/1 stone outstanding.
- The raid boundary is appropriately narrow and repository-backed. Raid RNG and spawning currently run unguarded in `scripts/world/spawn_manager.gd:21-36,116-152`; host/offline gating and a remote no-spawn fixture repair that mutation boundary without introducing deferred lifecycle semantics.

## Analysis
### Spec compliance
The requested bounded solo RT1 remains intact: new/continue, onboarding, food, gathering, crafting/equipping, campfire/workbench/shelter, Rested, Greyling, and save/reload all have owners, phase gates, and objective evidence. KO/EN feedback, two supported resolutions, accessibility assertions, fixed fixtures, performance markers, and moderated outcomes preserve visible product value rather than reducing the release to security work.

The pass-3 blockers are resolved at their source by removing the dependent remote mutation feature. In particular, the plan does not claim that peer IDs authenticate durable users, does not accept remote inventory as authoritative, and does not retain a partial command/epoch/ledger path. The compatibility sink is narrow, observable, and forbidden from touching lookups or writers. This satisfies the root-cause fallback policy: the guard does not silently downgrade a supported feature; it makes an explicitly unsupported boundary stable and tested.

### Architecture and failure modes
The authority matrix, owner table, and shared-file handoff order are strong. Separating `IdentityStore`, `OnboardingStore`, `SettingsStore`, world authority, presentation, and `InteractionModeController` avoids making `GameState` a global write owner. Writers-last sequencing and detached world validation are appropriate for the currently direct, partially applying save path in `scripts/core/save_system.gd:53-91`.

The negative network fixture is objective and attacks the real current side doors: normal UI, direct sender, forged legacy RPC, replay, malformed transform/piece, burst, remove/refund, piece interaction, and authority-RPC spoof. Hashing host inventory, piece set, revision/dirty state, stats, evidence, and client materials before and after drain plus reload is sufficient to distinguish visible rejection from accidental mutation. Repository guard search is necessary because current `BuildPiece.interact()` mutates door, bed/spawn, storage, cooking, smelting, crops, and portal state (`scripts/building/build_piece.gd:229-274`) and `destroy(true)` refunds (`scripts/building/build_piece.gd:361-378`).

Four gaps remain material. First, the ordered objective list requests a gather row for the hammer even though starter resources fully satisfy it, while all gather rows require source evidence and starter evidence is forbidden. Second, `RESTED_APPLIED` waits for an undefined “normal rest duration”; the current game applies Rested immediately on any positive comfort (`scripts/player/player.gd:402-424`), so there is no existing contract to inherit. Third, duplicate-key rejection cannot be performed after `JSON.parse_string()` has collapsed object members (`scripts/core/save_system.gd:62`). Fourth, the local build transaction promises atomic consume/create/revision/evidence, but current inventory consumption emits per-item observable mutations (`scripts/player/inventory.gd:126-131`) and the plan does not define reservation, commit, rollback, or failure injection.

### Constructive synthesis
Retain the pass-4 authority and phase structure. Amend Phase 0 with four frozen micro-contracts: (1) zero-shortfall preparation rows auto-resolve from possession without being labeled gathering, and source evidence applies only to positive remaining amounts; (2) a concrete shelter rest timer with accumulation/reset semantics; (3) either a bounded duplicate-aware pre-parser or an explicit deterministic JSON duplicate policy; and (4) a build commit protocol using detached construction and unobservable material reservation followed by a single consolidated commit signal. These changes fit existing owners and do not expand MAR1 or product scope.

## Root Cause
Pass 4 correctly removes the prior remote protocol root cause: RT1 was trying to support remote mutation without authenticated durable ownership and complete epoch/replay/capacity semantics. The remaining blockers are specification discontinuities at observable transaction boundaries—objective completion, timed state transition, parsing, and local mutation commit—where the plan states invariants but does not yet define executable transition rules.

## Findings
1. **MEDIUM — stage-04-revision.md:136-137 — Define zero-shortfall gather-row completion.** Hammer materials have zero outstanding cost after the starter grant, but the row simultaneously requires non-starter gather evidence. Specify a possession/preparation auto-resolution for zero remaining and require source evidence only when remaining is positive.
2. **MEDIUM — stage-04-revision.md:138 — Specify the shelter rest-duration contract.** Freeze an exact duration, accumulation condition, reset/pause behavior when range/shelter predicates fail, and one-shot emission; test duration minus epsilon and duration.
3. **MEDIUM — stage-04-revision.md:96 — Choose an implementable duplicate-key policy.** `JSON.parse_string()` cannot expose duplicate members after parsing. Add a bounded duplicate-aware tokenization seam before normal parsing or explicitly adopt and test deterministic last-key semantics; do not claim post-parse duplicate detection.
4. **MEDIUM — stage-04-revision.md:101-104 — Define the local build transaction commit seam.** Preconstruct/validate a detached entity, reserve materials without emitting observable inventory changes, commit entity/inventory/revision/evidence together, then emit consolidated signals. Add injected failure cases for reserve, create, attach, and evidence stages.

## Recommendations
1. Amend the objective table so a zero-shortfall row is `prepare/possess hammer materials`, not `gather`; record the exact positive remaining sequence after spend: campfire 1 stone, workbench 5 wood, shelter 12 wood under the frozen starter order.
2. Freeze a named shelter-rest state machine in Phase 0: `INELIGIBLE -> RESTING -> APPLIED`, an exact number of continuous eligible seconds, reset behavior, event identity, and reload behavior.
3. Decide the parser policy alongside maximum document size. If duplicate rejection is retained, assign the duplicate-aware bounded parser/tokenizer to Core/state and fixture duplicate keys at every object depth.
4. Add `BuildTransaction` as a narrow orchestration contract, not a broad framework: validate canonical data; create detached piece/boat; reserve exact material deltas; attach and update revision/evidence; publish one inventory/world/UI result. Define rollback before commit and make post-commit notifications non-failing.
5. Keep all pass-4 remote boundaries unchanged. Do not reintroduce registration, command acknowledgements, epochs, replay, or ledgers to close these local gaps.
6. After these amendments, Phase 0 can objectively approve the plan without implementation tests; implementation retains the listed native pure, scene, two-process, visual, performance, and playtest evidence.

## Architectural Status
`BLOCK`

## Code Review Recommendation
`REQUEST CHANGES`

## Tradeoffs
| Option | Benefit | Cost/risk | Recommendation |
|---|---|---|---|
| Keep the pass-4 remote fail-closed cut | Eliminates incomplete security protocol while preserving host/offline solo value and read-only replication | Remote building is unavailable and must be communicated | Keep |
| Reintroduce a partial remote protocol | Superficially restores remote building | Reopens all pass-3 ownership, epoch, replay, ledger, and inventory blockers | Reject; MAR1 only |
| Treat zero outstanding as gathered | Minimal onboarding logic | Falsifies acquisition evidence and conflicts with provenance rules | Reject; use preparation/possession semantics |
| Freeze a timed shelter state machine | Deterministic UX and tests | Small new local state seam | Choose |
| Retain duplicate rejection with bounded pre-parse scan | Strong corruption policy | More parser code and nested-object fixtures | Viable if explicitly owned |
| Adopt deterministic JSON duplicate semantics | Simpler implementation | Weaker malformed-input defense; schema claim must change | Viable for local-only files if documented |
| Detached build plus reservation/commit | Meets no-loss/no-duplication contract and supports failure tests | Requires focused inventory signaling changes | Choose |
| Reorder consume and spawn only | Small patch | Still cannot roll back attach/evidence failures and leaks intermediate signals | Reject |
