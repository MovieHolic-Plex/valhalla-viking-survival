## Verdict
**ITERATE**

## Claim Checks
- The immutable stage-2 revision was read at the supplied path; `index.jsonl` records SHA-256 `dcc9e60a3f7f98d798177d5b79567cb31dd8c617ee9c983ce0064e820c194438`.
- Scope, authority domains, interaction priority, build rejection precedence, onboarding event semantics, transactional persistence policy, phase dependencies, screenshot matrix, moderated-playtest rubric, and release evidence are substantially more explicit and measurable than a typical execution plan.
- Referenced existing product files were verified: `game_state.gd`, `save_system.gd`, `net.gd`, `build_system.gd`, `build_piece.gd`, `inventory.gd`, `player.gd`, `ui_root.gd`, `hud.gd`, `craft_ui.gd`, `loc.gd`, `spawn_manager.gd`, `enemy.gd`, `screenshot_director.gd`, and `README.md` exist. The proposed focused stores, event types, interaction controller, schemas, manifests, and native test entry/adapters are intentionally new Phase 0/implementation artifacts.
- Representative simulation 1 (authoritative build) exposes a material contract gap: the existing client owns a full `Player`/`Inventory`, while the host registry has only `RemotePlayer` position/HP and no authoritative per-peer inventory. The plan says the host derives inventory from its peer registry, but does not specify how host-authoritative inventory is initialized, synchronized, persisted, or mapped to `actor_player_id`. Executors cannot safely implement `PLACE_BUILD` without choosing a player-inventory authority architecture.
- Representative simulation 2 (onboarding persistence) exposes an identifier/storage gap: the repository has one fixed save slot and no stable world ID or local player ID. `OnboardingStore` is said to be keyed by world ID + local player ID and stored in a “world-associated local section,” while `SaveSystem.VERSION` remains 1 and starter idempotency also depends on those IDs. Their generation, legacy derivation, collision policy, and exact persistence location are unspecified.
- Representative simulation 3 (shelter/Rested) exposes a predicate contradiction: the chain and acceptance say campfire/workbench/shelter then Rested, but the stated shelter predicate measures around a “bed/rest point” and requires player-owned pieces. A bed is not listed as required, build pieces currently carry no owner, and current Rested is granted from any comfort source without roof/shelter. The event trigger and ownership data contract therefore remain ambiguous.
- DR consistency is otherwise good: contract-first implementation, no optimistic spending, no parallel old/new UI, native harness, and bounded RT1 are consistently reflected in phases and gates.

## Missing Evidence
- Definitely missing: authoritative player/inventory registry and lifecycle contract for host, offline, reconnect, save/load, and `actor_peer_id`/`actor_player_id` binding.
- Definitely missing: stable world/player identity contract and exact onboarding/starter transaction storage schema. The text alternates between an independent `OnboardingStore`, a world-associated local section, and optional world-save metadata without resolving whether onboarding is copied, deleted, or reset with slots/worlds.
- Definitely missing: exact shelter reference point and ownership model, plus the precise conditions that emit `RESTED_APPLIED`. Bed required versus optional is unresolved.
- Definitely inconsistent: `DUPLICATE` is both a top-level ack status carrying the original result and described as returning the exact ack. A duplicate of an accepted command cannot satisfy “exact ack” if status changes. This must be one normative wire behavior.
- Definitely inconsistent: the fixed dominant rejection precedence puts `RATE_LIMITED` after `STALE_REVISION`, while rate limiting generally must be checked before expensive/world-sensitive validation; more importantly, “outstanding commands ≤8” is not enough to objectively produce `RATE_LIMITED` for a reliable request after prior requests finish. Ledger capacity/eviction and outstanding decrement rules are absent despite bounded-dedupe claims.
- Thin: “any inventory mutation crossing authority” is open-ended against existing craft, equip, eat, container, pickup/drop, ammo, cooking, smelting, altar, tomb, and building paths. The plan needs an explicit RT1 command-kind/callsite matrix stating which become authoritative now and which are excluded/read-only in network play.
- Thin: rollback calls the work a coherent commit set, but file ownership and phase ordering place shared files (`player.gd`, event adapters, UI modes) across executors without a concrete merge/cutover order. One-owner-at-a-time is not enough to prevent cross-phase branch conflicts.
- Thin: settings require master/SFX/ambient channels, but current SFX and ambient playback both use `Master`; the plan does not identify bus creation/routing or acceptance probes per channel. UI scale live application also lacks a defined root/theme mechanism.
- Thin: atomic replace is a hard gate yet no target-platform primitive/API or fallback decision is selected; Phase 0 explicitly postpones this. This is acceptable as a gated prerequisite only if Phase 0 must produce a signed implementation decision before estimates/branches are approved, not merely a DR.
- Prior-review resolution cannot be fully verified because no stage-1 critic/review artifact is present in the supplied ralplan directory or session state; only stage-2 revision is available.

## Approval Boundary
Phase 0 contract elaboration may proceed. Product implementation, objective effort approval, and Phase 1–3 branching remain outside approval until the missing identity/inventory authority, shelter/Rested, duplicate-ack, command-scope, and persistence-location contracts are resolved and reflected in acceptance fixtures.

## Summary
- Clarity: Strong at phase and feature level; weak at three load-bearing seams.
- Verifiability: Strong screenshots/playtests/layout/data-integrity criteria; wire and identity semantics still prevent deterministic fixtures.
- Completeness: Broadly complete, but missing host inventory lifecycle, stable identity/storage, and precise shelter event semantics.
- Big Picture: Coherent bounded RT1, though 18–25 engineer-days is not objectively defensible until Phase 0 resolves the new host-player authority substrate.
- Principle/Option Consistency: Strong, except the duplicate-ack contradiction and unresolved atomic-replace choice.
- Alternatives Depth: Adequate at product/architecture level; host inventory and onboarding storage alternatives are absent.
- Risk/Verification Rigor: Strong overall; dedupe bounds, settings channel isolation, and cross-authority mutation coverage need exact fixtures.

## Required Changes
1. Add a normative host player-state model: stable player identity, peer/session binding, authoritative inventory location, initialization on host/join, command lookup, revision ownership, reconnect/rejoin behavior, and save/load ownership. Include sequence diagrams and fixtures for host player, remote client, reconnect, forged actor, and missing registry entry.
2. Define stable `world_id` and `local_player_id` generation/legacy derivation and name the exact onboarding/starter persistence document and lifecycle. Specify slot copy/delete/new-world behavior, crash boundaries for “persisted before delivery,” and why it is v1-additive.
3. Resolve shelter semantics: state whether a bed is required; define the rest point when no bed exists; define piece owner persistence/replication; define roof ray origin/directions and connectedness; and make `RESTED_APPLIED` emission conditional on the exact shelter predicate rather than generic comfort.
4. Make duplicate replay wire semantics singular: either replay the byte-equivalent original `CommandAck` with original status or return a `DUPLICATE` wrapper containing a normative nested original result. Update acceptance wording and tests accordingly. Specify ledger maximum entries/bytes, eviction behavior, session-epoch creation, outstanding accounting, and deterministic rate-limit fixtures.
5. Add an exhaustive RT1 cross-authority mutation matrix for build, craft hammer, equip, eat, pickups/gathers, inventory moves, remove/refund, save/load, and deferred container/tomb/raid/combat paths. Name each command/event, owner, repository callsites, and whether multiplayer use is implemented, rejected, or unchanged.
6. Expand Phase 0 outputs with selected settings bus/UI-scale application design, Windows atomic-replace primitive and failure semantics, and a shared-file merge/cutover sequence. Require approval of these decisions before Phase 1 estimates and branches.
7. Attach or summarize each prior review issue with its stage-2 resolution so the requested “all prior review resolutions” check is auditable.
