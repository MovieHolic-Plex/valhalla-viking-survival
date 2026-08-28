## Summary
Pass 5 is materially executable and safe to enter Phase 0. It closes the earlier remote-authority blockers by removing remote build mutation from RT1 rather than masking them, and it now gives executable contracts for zero-shortfall onboarding, continuous Rested qualification, duplicate-key rejection, and atomic local placement. No blocking architecture or specification issue remains.

## Claims
- RT1 is a coherent solo authority slice: offline and host-local building are supported, while every remote placement, removal, refund, and mutating piece interaction terminates as `REJECTED/UNSUPPORTED_IN_RT1` before mutation. This directly addresses the currently unsafe paths in `scripts/building/build_system.gd:196-262` and `scripts/core/net.gd:399-454`.
- Host-to-client placement is retained only as authority projection, with the plan requiring the current `place_remote` path (`scripts/building/build_system.gd:243-247`) to be renamed/restricted and `_place_piece` (`scripts/core/net.gd:417-428`) to remain authority-only.
- The frozen economy is repository-backed: `scripts/core/recipe_db.gd:48` defines hammer 3 wood/2 stone; `scripts/core/recipe_db.gd:313-316` defines campfire 2 wood/5 stone and workbench 10 wood; `scripts/core/recipe_db.gd:335-342` defines the six shelter pieces at 12 wood. The total 27 wood/7 stone and nominal starter shortfall 17 wood/1 stone are correct against the current starter grant in `scripts/player/player.gd:126-130`.
- The four Pass-4 contracts are explicit and testable: zero hammer shortfall completes by possession without fabricated gather evidence; Rested requires one uninterrupted five-second qualified interval with all enumerated resets and one-shot emission; duplicate keys are lexically rejected before parsing, including escaped-equivalent keys; local placement uses detached creation plus silent reservation and a non-yielding guarded commit with reserve/create/attach/evidence fault seams.
- Phase ordering is safe: additive readers and schemas precede stores/controller/validator, callsites cut over before writers activate, Windows replacement is a Phase-0 stop gate, and rollback keeps fail-closed remote behavior.

## Analysis
### Spec compliance
The plan delivers the requested first-session chain without importing MAR1. The objective sequence is arithmetically feasible with the unchanged starter grant: hammer readiness begins at zero shortfall, hammer crafting spends 3 wood/2 stone, the subsequent canonical rows require exactly the remaining 17 wood/1 stone over the complete chain. Positive shortfalls retain source-and-amount evidence requirements, so the zero exception cannot silently waive real gathering.

The earlier remote protocol blockers are closed by coherent scope removal. The plan neither claims peer identity as durable ownership nor introduces partial epoch/replay/capacity semantics. It inventories the actual unsafe request, projection, destruction/refund, and interaction surfaces and requires both callsite and RPC-ingress rejection. The two-process fixture checks normal, direct, forged, replayed, malformed, and burst attempts against host inventory, piece set, save revision, stats, and onboarding evidence, which is sufficient proof of the negative contract.

### Architecture and safety
Authority boundaries are singular and durable: world mutation belongs to offline/host-local authority; onboarding, identity, and settings are separate transactional local stores; presentation is non-authoritative; interaction mode has one writer. This corrects current direct interaction writers in `scripts/main.gd:218,375` and `scripts/ui/ui_root.gd:129-137,248-250` without creating a parallel controller.

The local build design repairs the current consume-then-spawn sequence in `scripts/building/build_system.gd:196-229` and the immediately-signaling inventory API in `scripts/player/inventory.gd:45-139`. Detached creation, silent reservation, staged evidence, non-yielding/reentrancy-guarded commit, consolidated postcommit publication, and exact rollback invariants form an implementable transaction boundary. Phase 0 correctly blocks execution if attach/evidence cannot be made observationally atomic.

Persistence fixes the current parse-and-live-apply path in `scripts/core/save_system.gd:53-104`. Byte bounds, duplicate-aware lexical scanning, detached parse/migration/validation, one apply, same-volume replacement, valid backup preservation, and writer-last activation are ordered to prevent corruption. Scanner uncertainty and bound exhaustion fail closed.

Rested is deterministic: its reference point, structural predicate, qualification states, reset set, pause/loading behavior, threshold boundary, and duplicate suppression are all frozen. The current repository has the named 20-HP Greyling fixture at `scripts/entities/enemy_db.gd:48-56`, so the encounter acceptance is grounded.

### Constructive synthesis
No additional subsystem is needed. The Phase-0 artifacts already name the remaining implementation decisions that must be frozen rather than guessed: Windows replacement primitive, scanner bounds/grammar, provisional attach behavior, movement epsilon, RPC sink/version choice, and UI wireframes. Their stop gates are appropriate and prevent those decisions from becoming silent fallbacks.

The top-level 14-20 engineer-day estimate is lower than the sum of owner estimates, but the plan explicitly requires Phase 0 to reaffirm or revise it after the highest-uncertainty spikes. This is a scheduling calibration item, not an architecture blocker or an excuse to weaken acceptance.

## Root Cause
Earlier revisions coupled a solo release to an incomplete remote mutation protocol and left four edge contracts underspecified. Pass 5 fixes the root cause by removing remote mutation support as one coherent capability and by defining authoritative state transitions at the ambiguity boundaries, rather than adding compatibility fallbacks or weakening evidence.

## Findings
No CRITICAL, HIGH, MEDIUM, or LOW correctness findings. The prior authority, evidence, timing, parsing, and placement-atomicity blockers are closed in the final revision.

## Recommendations
1. Approve Pass 5 and execute Phase 0 exactly as gated; do not activate writers or remote mutation paths before its exit evidence passes.
2. Treat the remote ingress inventory and detached-placement state diagram as hard implementation contracts, not illustrative guidance.
3. Reconcile the calendar/engineer-day estimate during the already-required Phase-0 revalidation; do not change RT1 scope or acceptance to fit the current headline estimate.
4. Keep MAR1 wholly deferred. Any attempt to enable one remote mutation path reopens the credential, authoritative inventory, epoch/replay, capacity, compatibility, and adversarial-proof contract together.

## Architectural Status
`CLEAR`

## Code Review Recommendation
`APPROVE`

## Tradeoffs
- **Chosen solo fail-closed cut:** smallest safe release boundary and eliminates incomplete remote identity/replay dependencies; cost is an explicit remote-build limitation.
- **Chosen detached/reserved local transaction:** stronger no-loss/no-duplication guarantees and deterministic fault evidence; cost is a deliberate inventory/scene transaction seam.
- **Chosen bounded lexical pre-scan:** preserves duplicate-key evidence before parser normalization; cost is a small, rigorously bounded scanner and corpus.
- **Chosen exact Rested state machine:** deterministic onboarding and replay behavior; cost is centralized reset-event wiring.
- **Deferred MAR1:** avoids hidden security and persistence debt in RT1; cost is no remote gameplay mutation guarantee in this release.
