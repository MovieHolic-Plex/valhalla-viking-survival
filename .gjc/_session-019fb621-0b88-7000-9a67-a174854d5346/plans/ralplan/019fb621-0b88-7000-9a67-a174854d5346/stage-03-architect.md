# Architecture Review — Consensus Pass 3

Reviewed immutable revision: `.gjc/_session-019fb61a-e358-7000-ae21-4ba14e45d87e/plans/ralplan/019fb61a-e358-7000-ae21-4ba14e45d87e/stage-03-revision.md`, SHA-256 `8e1ef94159d9d97aaa94db8e33a852abcd6ecab36b45d76d4cbb405aeee21e95`, `stage_n=3`.

## Summary
Pass 3 resolves six of the prior eight blockers and substantially repairs the other two, but three load-bearing protocol gaps remain. The plan must define proof of durable-player ownership, make retained old-epoch outcomes reachable before stale-session rejection, and guarantee immutable rate-limit outcomes when the ledger is full.

## Claims
- Resource feasibility is resolved: the canonical RT1 total is frozen at 27 wood/7 stone, the nominal shortfall is 17 wood/1 stone, and each acquisition stage derives remaining cost from authoritative state (`stage-03-revision.md:61-64,136-140,179-181`).
- Raid scope is resolved: RT1 is explicitly limited to a host/offline mutation guard and client rejection/no-op; lifecycle persistence, cancellation, reconnect snapshots, raid epochs, UX, and tuning are deferred and excluded from acceptance (`stage-03-revision.md:7-8,65-67,115-116,183-185`).
- Durable identity and local onboarding ownership are resolved at storage/lifecycle level: UUIDv4 new identities, deterministic UUIDv5 legacy migration/collision mapping, independent `identity.json` and `onboarding.json`, and copy/delete/rename behavior are specified (`stage-03-revision.md:69-80,128-134`).
- Interaction-writer migration is resolved: `ui_root.gd`, `main.gd`, `net_probe.gd`, and `screenshot_director.gd` route typed requests through one controller, with title/world handoff and a release-disabled dev override (`stage-03-revision.md:119-121`).
- Session epoch is now present in command and acknowledgement; replay outcome has only `ACCEPTED|REJECTED`, with `replayed` separated and client delta application keyed by epoch/request (`stage-03-revision.md:94-103`).
- The host registry now assigns authoritative inventory/revision, durable save ownership, session rotation, snapshots, and a bounded trusted-movement seam (`stage-03-revision.md:87-92`).

## Analysis
### Stage 1 — Spec compliance
The bounded RT1 is coherent at the product level. It teaches acquisition for every required recipe, defines the campfire as the unambiguous rest anchor, limits remote mutation support through an explicit matrix, separates private onboarding from world replication, and keeps raid lifecycle outside the release gate. Six prior blockers—resource budget, raid cut line, durable ID generation/persistence, interaction writer coverage, onboarding storage ownership, and epoch carriage—are resolved.

The replay and registry blockers are not fully resolved. The plan says transport authenticates the RPC sender and then resolves a client-provided durable ID, but transport identity alone does not prove ownership of an arbitrary durable player record. Separately, its validation order rejects stale epochs before consulting the retained old-epoch ledger, contradicting both immutable retry semantics and the named old-ledger replay test.

### Stage 2 — Architecture
The proposed domain boundaries and phased cutover are sound. Focused stores, host-owned world/player records, writer-last activation, one interaction controller, a pure placement validator, and explicit rejection of unsupported remote commands are maintainable boundaries rather than broad compatibility shims.

The strongest antithesis is that the plan labels registration “authenticated” without defining the trust root. A malicious remote peer can claim another known `local_player_id`; successful transport authentication proves which peer sent the claim, not that the peer owns that durable identity. Because join loads authoritative inventory by that ID, this is an account/state takeover boundary, not a documentation nicety.

The ledger cap also has an internal finalization hole. Once all entries are protected and the ledger reaches its count/byte ceiling, a new request is promised `REJECTED/RATE_LIMITED`, but there is nowhere specified to retain that final outcome. If unrecorded, the same request can later execute after capacity clears, violating the immutable-outcome invariant.

### Stage 3 — Constructive synthesis
Keep the architecture and freeze three narrow protocol amendments in Phase 0:
1. Define the registration trust model. Either add a host-verifiable credential/proof-of-possession bound to `player_id`, with lifecycle and reconnect rules, or explicitly prohibit remote durable-player claims in RT1 and constrain networking to host-local/offline fixtures.
2. After sender/player authentication, consult a finalized ledger entry for the supplied old epoch/request before current-epoch rejection. Return the original outcome when found; return `STALE_SESSION` only for an unknown old-epoch request.
3. Make capacity rejection replay-stable through reserved ledger capacity, a separate bounded rejection ledger, or a clearly non-final admission response outside `CommandAck`; test retry before and after capacity clears.

### Stage 4 — Quality, security, and performance
Visual, accessibility, performance, persistence, rollback, migration, and fixed-fixture gates are concrete and appropriately bounded. The remaining defects are security/correctness issues in the normative command contract and cannot be delegated to implementation choice.

## Root Cause
Pass 3 added the right identity and replay objects but did not completely connect their trust and ordering invariants. It conflates authenticated transport with authenticated ownership of durable identity, and it specifies ledger retention/capacity independently from the validation/finalization paths that must preserve immutable outcomes.

## Findings
1. **HIGH — Define proof of durable-player ownership** (`stage-03-revision.md:80-92`). A peer can claim another durable player record because no credential or trust boundary binds the remotely supplied ID. Freeze a proof mechanism or reject remote durable claims in RT1.
2. **HIGH — Look up finalized old-epoch requests before stale-session rejection** (`stage-03-revision.md:99-103`). Current ordering makes retained old-epoch outcomes unreachable and changes a retry's outcome. Replay a known finalized outcome first; reject only unknown old-epoch requests.
3. **HIGH — Make rate-limit rejection durable at ledger capacity** (`stage-03-revision.md:101-103`). A full protected ledger cannot record the promised final rejection, allowing later outcome drift. Reserve capacity, separate rejection retention, or use a non-final admission response, with retry fixtures.

## Recommendations
1. Block Phase 0 approval and implementation branching until the three protocol amendments above are normative and covered by sequence/pure/two-process fixtures.
2. Preserve the current scope, ownership matrix, identity migration, local-store separation, campfire predicate, exact cost table, raid deferral, writer cutover, persistence design, and evidence gates.
3. Add explicit tests for stolen/unknown durable ID, old-epoch replay of both accepted and rejected outcomes, unknown old-epoch request, and a rate-limited request retried before and after ledger capacity clears.

## Architectural Status
`BLOCK`

## Code Review Recommendation
`REQUEST CHANGES`

## Tradeoffs
| Option | Benefit | Cost/Risk | Recommendation |
|---|---|---|---|
| Durable-ID credential/proof | Supports real remote reconnect identity safely | Adds credential lifecycle and recovery | Required if remote durable registration remains |
| Host-local/offline-only identity | Keeps RT1 smaller and avoids false authentication claim | Defers remote reconnect behavior | Acceptable bounded alternative |
| Replay lookup before epoch rejection | Preserves immutable known outcomes across reconnect | Requires authenticated lookup across retained epoch ledgers | Required |
| Separate/reserved rate-limit records | Preserves bounded memory and immutable rejection | Slight accounting complexity | Required |
| Unrecorded `RATE_LIMITED` final ack | Simplest implementation | Same request can later change outcome and mutate | Reject |

Planning-only review; no product edits, tests, gates, or formatters were run.
