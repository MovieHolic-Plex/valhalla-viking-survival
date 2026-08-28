# Deliberate Gameplay, UI, and UX Improvement Plan

## Summary
Transform the current technically broad but poorly communicated survival sandbox into a legible, learnable, responsive game whose first 30 minutes teach and reward the core loop—gather, eat, craft, shelter, fight, recover, progress—without flattening its Valheim-inspired identity. The plan favors a vertical-slice UX pass over adding content: establish progression guidance and interaction contracts, improve combat/survival feedback, rebuild information hierarchy and responsive UI, then tune/verify the complete play flow. Existing procedural systems, 7-biome progression, content databases, save model, and multiplayer authority remain the foundation.

Repository evidence: `scenes/main.tscn` is only a scripted root and nearly every interface is generated in GDScript. `project.godot` defines keyboard/mouse actions but no controller bindings or remapping. `scripts/main.gd` gives a club, 10 wood, 6 stone, and berries, then emits only a 4.0-second welcome message. `scripts/core/recipe_db.gd` exposes hammer/torch/club/stone axe immediately, but there is no persisted objective/tutorial state. `scripts/ui/hud.gd` displays vital bars, three unlabeled food icons, plain-text statuses, notifications, clock/biome/weather, hotbar and boss HP, but no objective, enemy threat/target identity, cooldown, low-resource urgency, or contextual action state. `scripts/player/player.gd` contains broad movement/combat/survival mechanics and 0.35-second dodge iframes / 0.35-second parry window, yet failed stamina actions mostly play a generic error sound and bow/fishing/boat state is minimally surfaced. `scripts/entities/enemy.gd` uses a fixed 0.42-second telegraph and transient world-space HP; player damage type effectiveness is not communicated. `scripts/world/spawn_manager.gd` can start a 6+tier*2 raid with one generic message and no persistent event state. `scripts/ui/ui_root.gd` has mutually exclusive modal panels and pause controls, but controls are a static paragraph; no settings, remapping, UI scaling, or accessibility. `scripts/ui/map_ui.gd` is a fixed 880x860 map without zoom, pan, legend, pin editing, or explicit death recovery guidance. `scripts/ui/inventory_ui.gd` uses mouse-only pick/place and hover details, while all theme buttons set `FOCUS_NONE`. `scripts/building/build_system.gd` uses only red/green validity and returns no reason when placement fails; `_tint_support` is a no-op despite structural integrity being a stated feature. Existing 1600x900 screenshots confirm sparse/no-navigation HUD, small text and statuses, large dead panel space, low-contrast black/brown panels, ambiguous item/equipment states, world readability issues, a boss screenshot where the enemy overlaps the player, and sailing with no rudder/speed/wind HUD. Screenshot automation already covers 34 scenes but stages inventory with 1806/300 weight and grants late-game items, so it is not a truthful first-play acceptance path.

## Intent Diff
- From a content-complete demonstration to a guided, measurable play experience.
- From transient generic messages to layered persistent objectives, contextual prompts, consequences, and resolution feedback.
- From one-size fixed 1600x900 layouts to a coherent visual system verified at 1280x720, 1600x900, 1920x1080, and ultrawide safe areas.
- From hidden combat/survival/building rules to readable state and actionable failure reasons.
- From screenshot showcases populated by debug grants to deterministic first-play, combat, survival, build, death/recovery, navigation, and late-game capture scenarios.
- Preserve the broad sandbox and emergent systems; do not turn it into a linear quest game.

## RALPLAN-DR
### Principles
1. **Teach through the real loop:** onboarding actions must use ordinary inventory, crafting, building, combat, death, and map systems; no tutorial-only fake mechanics.
2. **Every input has legible intent and result:** before action, show context/cost/validity; on action, show audiovisual confirmation; on failure, show a specific reason and recovery.
3. **Progressive disclosure over permanent clutter:** persistent HUD carries only immediate survival/threat/objective state; deeper comparisons and lore live in modal surfaces.
4. **One visual and interaction grammar:** shared tokens, icon/state semantics, navigation behavior, localization, safe-area rules, and input glyph resolution apply to every screen.
5. **Tune via observed player outcomes:** fixed-seed captures, instrumentation and fresh-player playtests—not subjective polish alone—gate each phase.

### Top 3 decision drivers
1. First-session comprehension and momentum: a new player must independently form and complete the core survival loop.
2. Moment-to-moment readability and agency under combat, weather, building and death pressure.
3. Change safety across save/load, Korean/English localization, deterministic generation, multiplayer authority and the large existing content surface.

### Options
**Option A — Focused vertical-slice overhaul (chosen):** polish title/settings, first 30 minutes, HUD, early combat/survival/building, death recovery, inventory/crafting/map, then propagate shared patterns to boats/fishing/bosses. Pros: validates one coherent end-to-end experience early, limits balance blast radius, creates reusable UI primitives, gives executors objective gates. Cons: later-biome presentation temporarily trails the early game; requires disciplined non-goals. Chosen because the current weakness is discoverability and feedback rather than lack of systems, and an end-to-end slice gives the fastest credible quality signal.

**Option B — Surface-by-surface visual reskin:** redesign all panels/HUD/screenshots first, then gameplay feedback. Pros: fast visual impact across README imagery; parallelizable. Cons: preserves broken play flow, hides rather than fixes interaction ambiguity, creates rework once state contracts change. Rejected as primary strategy; visual foundations are part of Phase 1 but must serve the gameplay contract.

**Option C — System-by-system mechanics rebalance:** tune movement, stamina, enemies, raids, food and progression before UI. Pros: can improve game feel and difficulty. Cons: players still cannot understand outcomes, telemetry is insufficient, wide balance changes risk progression/save regressions. Rejected until feedback and observability make tuning evidence-based.

## Decision Drivers
- Assume desktop keyboard/mouse is the release-critical input for this pass because only those bindings exist; controller support is an additive option behind the risk gate, not implied complete support.
- Assume both Korean (configured fallback/test locale) and English are acceptance-critical; all new player-facing copy must have both entries and be checked for clipping.
- Keep current no-editor-scene architecture: add/refactor GDScript UI classes and data contracts rather than introducing parallel `.tscn` UI conventions unless an architect explicitly approves migration.
- Keep the existing save version readable. New tutorial/settings/objective data must default safely for old saves and must not reset world/player progression.
- Survival remains food-driven rather than adding conventional hunger/thirst meters. Improve explanation and feedback; do not invent new depletion systems.
- Difficulty tuning must separate first-session safety from global trivialization; spawn/raid/combat values must be profileable and measured.

## In scope / out of scope
### In scope
- Complete play flow: title/new/continue/loading, spawn, first objective chain, early gather/craft/equip/eat/build/fight/rest, biome/boss direction, death/respawn/tomb recovery, save/continue.
- Controls: action-centric input prompts, conflict-safe action map usage, sensitivity/settings, keyboard navigation; controller feasibility gate.
- Feedback: interaction, pickup, equipment, stamina failure, damage/effectiveness, block/parry/dodge, enemy telegraphs, death, raid, build validity/support, crafting, boat/fishing states.
- Readability: camera/target composition, world interaction highlighting, HUD priorities, icons/text contrast, status timers, screen-space collisions and localization.
- Information architecture: title separation, pause/settings/controls, inventory/crafting/equipment comparisons, build categories and requirements, map navigation/legend/pins/objectives/tomb.
- Visual consistency: reusable tokens/components/states, typography, spacing, focus/hover/pressed/disabled, semantic colors plus non-color cues, dimming and safe areas.
- Onboarding: resumable/skippable objective chain, contextual hints, glossary/help/controls reference, progression prompts driven by real game state.
- Combat and survival loop tuning, bounded to early-game vertical slice first and propagated only after observed success.
- Deterministic screenshot scenarios, playtest rubric, observability events, unit/integration/e2e tests and docs/control references.

### Out of scope
- New biomes, bosses, large item/recipe expansions, trading NPCs, cinematic story campaign, Steam services/matchmaking, backend analytics, new art pipeline, wholesale procedural-generation rewrite.
- A full controller release unless the input/navigation prototype passes the risk gate on all modal and gameplay surfaces.
- Save-format rewrite or multiplayer architecture rewrite.
- Pixel-copying Valheim or replacing the existing Korean/Norse identity.
- Broad late-game balance changes before early-loop metrics and playtests establish a baseline.

## File-level changes
### Entry, state, localization, input
- `project.godot`: define any new semantic actions (help/objective dismiss/pin/settings navigation), add supported device bindings only after the controller gate, and add documented display/accessibility defaults. Never hard-code display keys in UI strings.
- `scripts/main.gd`: restructure title information hierarchy (singleplayer vs multiplayer advanced section), loading/error states, safe transition into onboarding, and first-run versus continue behavior. Keep CLI paths (`--auto`, `--shots`, `--uionly`, `--quick`) intact.
- `scripts/core/game_state.gd`: own objective/tutorial/event progress and explicit current raid/progression signals; expose read-only state needed by HUD rather than UI polling internals.
- `scripts/core/save_system.gd`: serialize new progression/settings fields with migration defaults while maintaining version-1 load behavior; include objective/death recovery markers only when meaningful.
- `scripts/core/loc.gd`: Korean/English copy for objectives, reasons, settings, legends, actions, combat/survival feedback; remove embedded duplicate `[E]` from `PROMPT_READ_RUNESTONE` so glyph formatting is centralized.
- New focused services under existing conventions if needed, e.g. `scripts/core/input_prompts.gd` for action→current-glyph text and `scripts/core/onboarding.gd` for declarative objective prerequisites/completion. Do not put progression policy in `hud.gd`.

### UI shell and visual language
- `scripts/ui/ui_theme.gd`: promote spacing, type scale, safe margins, semantic surfaces, contrast-tested colors, icon/badge/button/focus/disabled styles, and reduced-motion timing into reusable tokens/components. Restore keyboard focus; `FOCUS_NONE` cannot remain the universal button default.
- `scripts/ui/ui_root.gd`: make modal routing explicit (gameplay, overlay, pause, death), add Settings/Controls/Help, focus restore, input capture rules, responsive panel containers, raid/objective/death overlays, and live relocalization. Keep only one primary modal open and never allow hidden held inventory state.
- `scripts/ui/hud.gd`: reorganize into survival cluster, contextual action/reticle, objective/event card, hotbar/equipment action state, environment/status chips, combat feedback and boss/raid region. Show food name/remaining-strength affordance, status duration/severity, stamina rejection, active power/cooldown, boat/fishing/build mode when applicable; avoid showing raw clock/weather above immediate threats.
- `scripts/ui/inventory_ui.gd`: clearer equipment/inventory hierarchy, selected-state details instead of hover-only dependency, compare deltas, explicit equip/use/drop/split/quick-transfer actions, capacity cause/recovery, keyboard navigation, visible slot semantics, robust held-item cancellation.
- `scripts/ui/craft_ui.gd`: category/search/filter or at minimum craftable/unavailable grouping, persistent selection, missing-resource breakdown, station/level prerequisite, quantity/output clarity, disabled craft state with reason, keyboard focus and post-craft confirmation.
- `scripts/ui/build_ui.gd`: reduce horizontal scan, make category/current piece/requirements persistent, display placement reason from build-system contract and structural support legend; provide selected and unavailable patterns beyond color.
- `scripts/ui/map_ui.gd`: responsive viewport, zoom/pan/reset, legend, player orientation, discovered-only marker policy, pin add/edit/remove, objective and tomb emphasis, unclipped map at all target resolutions.
- Add focused UI classes only when a surface has independent lifecycle/state (objective widget, settings, action prompt, event banner); avoid one giant `ui_root.gd` extension.

### Gameplay and feedback contracts
- `scripts/player/player.gd`: emit structured action-state/failure/combat events (stamina cost, bow charge, block/parry window result, dodge denial, swimming danger, fishing phase, boat ownership) and add target/interactable highlight hooks. Preserve authority and damage logic; do not duplicate mechanics in UI.
- `scripts/player/player_stats.gd`: expose normalized vitality/food/status/power state and meaningful reason codes; ensure state changes emit once when values meaningfully change rather than requiring HUD polling. Tune early stamina/regen only after baseline playtests.
- `scripts/player/inventory.gd`: support UI actions atomically (move/split/equip/use/drop), preserve equipped indices on moves, and return result/reason values so UI never guesses. Add tests around full/overweight/equipped/container edge cases.
- `scripts/entities/enemy.gd`: separate wind-up/readability values from damage execution, add archetype-scaled telegraph signals, clearer aggro/stagger/death/hit feedback, damage effectiveness messaging, and maintain remote-client behavior. Fix combat composition/target identity before broad numerical difficulty changes.
- `scripts/entities/boss.gd`, `scripts/entities/altar.gd`, `scripts/entities/tombstone.gd`, `scripts/entities/boat.gd`, `scripts/entities/bobber.gd`: propagate common event/prompt contracts for boss phase/special, offering requirements, partial/full tomb recovery, boat speed/rudder/wind/dismount, and fishing charge/bite/hook/reel/break states.
- `scripts/world/spawn_manager.gd`: make raid lifecycle explicit (warning, active goal/state, remaining/time/end) and postpone first-session raids until the onboarding/shelter gate; log spawn/raid outcomes. Preserve base spawn blocking and biome/night pools.
- `scripts/building/build_system.gd`: replace boolean-only `_valid` with validity result/reason, surface snap/range/workbench/material/overlap/water/ground/support causes, implement `_tint_support` with icon/pattern/text redundancy, and keep host-authoritative placement.
- `scripts/building/build_piece.gd`: expose piece support/health/interactions to shared prompts without leaking internal node details.
- `scripts/world/world_gen.gd` / `scripts/world/chunk_manager.gd`: change only if fixed-seed playtests prove spawn terrain or first-resource access blocks onboarding; otherwise no generation rewrite.

### Validation, tooling, docs
- `scripts/dev/screenshot_director.gd`: retain existing marketing sequence but add deterministic acceptance scenarios with separate setup profiles: fresh spawn (no grants), early-loop milestones, low-health combat, parry/dodge, invalid/valid build, raid, death/tomb, inventory/craft/map/settings at four resolutions, Korean/English, and late-game systems. Ensure UI captures do not stage 1806/300 carry weight unless intentionally testing overburdened state.
- Add a lightweight test harness in the repo-native Godot approach selected by the executor (headless scripts or a pinned Godot test addon after dependency review), covering pure state and scene integration. No framework currently exists; architecture review chooses the least invasive route.
- `README.md`: update controls, onboarding, settings/accessibility and screenshot command/scenario documentation after behavior lands; replace screenshots only after comparison review.
- `docs/screenshots/`: keep baseline set until explicit visual approval; new captures use stable names/manifests and are reviewed before replacement.

## Sequencing and dependencies
### Phase 0 — Baseline and contracts (planner + architect + QA, no tuning)
1. Record fixed seed `12345`, clean-save profile, current 1600x900 screenshot set and a 20-minute first-play observation. Capture time-to-first food eaten, axe/hammer crafted, shelter built, first enemy hit/kill, first death/recovery; record all confusion/failure points.
2. Define shared gameplay event/result contracts: `ActionResult {ok, reason, cost, context}`, objective state, prompt action IDs, raid state and UI semantic tokens. Decide settings persistence boundary and old-save defaults.
3. Prototype responsive HUD regions and modal navigation in annotated wireframes using existing screenshot composition; approve hierarchy before code.
Dependency: objective/UI work must consume these contracts rather than inspect arbitrary node internals.

### Phase 1 — Foundations and first-session vertical slice
1. Implement input prompt resolution, localization copy, objective state machine and save migration.
2. Implement theme tokens, responsive UI shell, focus/navigation, settings/controls/help, first-run title/loading hierarchy.
3. Implement HUD objective/action/survival hierarchy and first milestones: move/look → gather wood/stone/berries → eat → craft/equip stone axe or hammer → build campfire/workbench/shelter → rest → prepare for first foe → locate/prepare first altar. Hints complete from real inventory/build/status/events, can be dismissed/skipped, and resume correctly.
4. Tune only spawn safety/resource access/message duration needed to make this path reliable; never grant hidden tutorial resources.
Gate: 4/5 fresh players complete food, first tool and basic shelter in ≤20 minutes without external instruction; no critical UI clipping at target resolutions/locales.

### Phase 2 — Core interaction surfaces
1. Inventory/equipment/container atomic actions and selected-state details.
2. Crafting prerequisites, availability grouping, missing-resource guidance and feedback.
3. Building validity reason/support visualization and compact category navigation.
4. Map zoom/pan/legend/pins/objective/tomb path plus death UI recovery guidance.
Dependency: atomic inventory results before inventory/crafting UI; validity result before build UI; objective state before map marker.
Gate: keyboard-only completion of inventory→craft→equip→build and death→respawn→map→tomb recovery; no item loss/duplication.

### Phase 3 — Combat, survival and event feel
1. Player action state feedback: attacks/charge/stamina rejection, block/parry/dodge, hit direction/severity, low health, damage type/effectiveness, death.
2. Enemy readability: aggro, target identity, archetype wind-up, attack execution, stagger, health/damage, boss phase/special. Tune telegraph/damage/cooldowns per archetype after capture data; remove fixed 0.42-second assumption where silhouette requires more.
3. Survival readability: food falloff/empty slots, status severity/timers and recovery hint, swim exhaustion, rest/comfort; maintain food-driven design.
4. Raid lifecycle and first-session protection; boat/fishing mode HUD.
Gate: players correctly identify why 9/10 sampled actions succeeded/failed, survive a prepared early encounter at target rate, and can describe status recovery and raid objective.

### Phase 4 — Propagation, polish and release validation
1. Apply contracts and visual patterns to powers, skills, bosses, dungeons, boats, fishing, multiplayer chat/status and late-game biomes without changing unrelated content balance.
2. Run full screenshot matrix and side-by-side review; fix hierarchy, occlusion, contrast, localization, safe areas and motion issues.
3. Run fresh/returning/death recovery/multiplayer playtests, save migration and deterministic fixed-seed e2e. Update README and approved screenshots.
4. Balance council reviews metrics and only then approves global changes to stamina, damage, spawn, raid or recipes.

### Parallel execution roster and review boundaries
- **Architect:** event/state ownership, save migration, UI decomposition, input/settings persistence; must approve new services and test framework/dependency.
- **Gameplay executor:** `player`, `player_stats`, enemy/boss, spawn/raid and tuning. May not redesign UI or alter global progression without the balance gate.
- **UI/UX executor:** theme, root, HUD, inventory/crafting/build/map/settings and localization wiring. May not reimplement gameplay calculations.
- **Progression executor:** onboarding/objectives, map direction and progression copy. May not add resources or bypass actual game predicates.
- **Tools/QA executor:** screenshot director, test harness, capture manifests, telemetry summaries. Must keep marketing and acceptance profiles separate.
- **Visual critic/accessibility reviewer:** screenshot comparison, contrast, hierarchy, safe zones, color-independent cues, motion and locale checks; findings block visual acceptance but do not directly edit gameplay rules.
- **Playtest coordinator:** fresh-player protocol and metric synthesis; no coaching during measured tasks.
- **Main/maintainer:** owns scope/balance decisions, asset replacement and phase gates. Use a team across Phase 1–3; critic reviews each phase; ultragoal only for cross-phase execution. Single executor is appropriate only for bounded component slices after contracts are stable.

## Acceptance criteria
### Play flow and onboarding
- A clean save presents a clear primary New World action and keeps multiplayer/configuration secondary; errors/loading are visible and recoverable.
- The objective chain is persistent, skippable, non-blocking and derived from actual state. Reload at every milestone resumes at the correct objective with no duplicate grants/messages.
- In moderated no-coaching tests, at least 4/5 new keyboard/mouse players eat food, craft/equip a useful tool, construct a campfire/workbench/basic covered rest area, and understand the next progression goal within 20 minutes. Median idle/confused interval never exceeds 90 seconds.
- Returning players can suppress completed onboarding and still access Help/Controls.

### Controls and navigation
- Every displayed gameplay key is resolved from input actions, not hard-coded; prompt changes are reflected everywhere in the same frame/session.
- All modal UI is operable with keyboard: enter/open, move focus, activate, back/close, and restore prior focus. No focus trap or click-only critical action.
- Mouse sensitivity, camera inversion, UI scale, master/SFX/ambient volume, reduced camera shake, and locale persist across restart. Remapping/controller is either fully validated or explicitly excluded from release UI.
- Opening inventory/map/settings/chat pauses or locks input according to documented singleplayer/multiplayer rules; no attack/build action leaks through.

### HUD and visual readability
- At 1280x720, 1600x900, 1920x1080 and 2560x1080, 100% and 125% UI scale, Korean and English, all critical HUD regions remain within safe margins, no text clips/overlaps, and the objective/action prompt never obscures the reticle/target.
- Body text is at least 16 px effective at 1600x900; critical values at least 18 px; primary text and controls meet WCAG-style 4.5:1 contrast where applicable, large text 3:1. World-overlay text has background/outline sufficient in snow, fog, night and fire scenes.
- Color is never the sole carrier of health/validity/equipment/support/status; icons, labels, patterns or shapes distinguish states.
- HUD exposes actionable low-health/stamina/swim/food/status warnings without flashing continuously; reduced-motion disables or attenuates shake/pulsing.

### Information surfaces
- Inventory supports move, merge, split, quick-transfer, equip/use, drop/cancel with explicit outcomes; closing any panel with a held stack never loses or duplicates it. Equipped references remain correct after moves/swaps.
- Crafting clearly distinguishes craftable, missing materials, wrong station and insufficient station level; button enablement and stated reason agree with actual craft result.
- Building invalid state states one dominant reason; placement preview and eventual host result agree. Structural support is visible with non-color cue, and removing support produces understandable collapse feedback.
- Map zoom/pan/reset/pins work within discovered-space policy. Tomb, bed, portal, altar/objective markers have a legend and remain distinguishable. Death screen and map direct the player toward recoverable tomb contents and warn when inventory capacity blocks full recovery.

### Combat, survival and traversal
- Input-to-animation/audio/feedback starts within 100 ms at 60 fps for local attack/block/dodge/interact; authoritative multiplayer result may arrive later but pending/rejected state is visible.
- Early melee enemies provide a visually/audibly readable wind-up of at least the approved archetype value; in blinded review 4/5 players correctly identify attack onset in ≥8/10 clips. Ranged and boss specials have distinct cues.
- Parry, normal block, stamina-break/failed action, dodge iframe, stagger, resistant/weak hit and kill each produce distinct non-text feedback plus optional text; no generic error sound is the only explanation.
- In fixed starter-gear encounters against the chosen Meadows enemy: target success band is 65–85% first-attempt survival after onboarding, median encounter 20–60 seconds, and deaths are attributable in post-test responses. Boss tuning has separate criteria and is not inferred from starter enemies.
- Food slots show benefit and decay/re-eat state; wet/cold/freezing/poison/burning/rested state communicates severity and at least one recovery action. A player with no prior explanation can state why max HP/stamina changed in 4/5 tests.
- Boat HUD exposes speed step, rudder, wind relationship and dismount; fishing HUD exposes cast charge, bait, bite, hook, reel stamina/tension and break/cancel state.
- Raid warning remains visible until acknowledged/active, raid state and completion are explicit, and no raid starts before the onboarding shelter gate or configured grace period.

### Persistence, localization and multiplayer
- Existing version-1 saves load with objective/settings defaults and preserve inventory, position, world changes, discoveries, pieces, tombs, bosses and powers.
- Saving/loading at each first-loop milestone and during death recovery produces no progression rollback or repeated rewards.
- Every new user-facing key exists in Korean and English; automated missing-key scan is zero and visual review finds no critical clipping.
- Host and client agree on build validity outcome, enemy damage/death, raid state, tomb ownership/recovery and objective completion where state is shared; local-only tutorials do not mutate authoritative gameplay.

## Verification
No tests/formatters are run during this planning stage. Executors must verify incrementally rather than waiting for final screenshots.

Recommended command families after implementation (adapt executable name to workstation installation):
- Import/parse smoke: `godot4 --headless --path . --editor --quit`
- Fixed-seed launch smoke: `godot4 --path . -- --auto --seed=12345`
- Existing screenshot regression: `godot4 --path . -- --shots=<artifact-dir> --seed=12345`
- Focused UI captures: `godot4 --path . -- --shots=<artifact-dir> --uionly --seed=12345`
- Quick world/UI composition: `godot4 --path . -- --shots=<artifact-dir> --quick --seed=12345`
- New acceptance profile(s): add CLI flags such as `--shot-profile=fresh|combat|survival|death|responsive` rather than overloading debug grant behavior.
- Tests: run the selected headless Godot test entry by suite and full set; do not add an unpinned dependency.

## Escalation/Risk Gate
Architecture/maintainer approval is required before:
- adding a third-party test/input/UI dependency;
- increasing save `VERSION` or changing existing serialized field meaning;
- adding controller as a supported release mode;
- changing world generation/spawn topology, global recipe/resource economy, base combat constants, day length or all-biome spawn/damage curves;
- changing multiplayer authority or transmitting tutorial/analytics data;
- replacing baseline README screenshots or deleting existing CLI screenshot modes.

Rollback policy: each phase lands behind coherent state boundaries and is independently revertible. Preserve old-save fixtures and baseline screenshots. Keep balance constants grouped so tuning can roll back without undoing feedback/UI. New onboarding defaults to inactive for completed/legacy worlds if migration confidence is low, with Help still accessible. If responsive UI fails a target resolution, retain prior surface rather than ship clipped hybrid screens. Never rewrite or delete user saves during migration; backup/atomic write behavior remains required.

## Verification Plan
### Unit tests
- Objective predicates/transitions: each prerequisite, skip, reload, old-save default, out-of-order action, duplicate event, completion idempotency.
- Input prompt resolver: bound/unbound action, keyboard/mouse glyph, remap/conflict, locale formatting and no embedded duplicate key labels.
- Player stats: food add/refresh/falloff/removal, max HP/stamina emissions, stamina rejection, status add/refresh/expiry/lethal/nonlethal DOT, revive.
- Inventory: stack merge/split/full, swap equipped slot indices, two-hand conflicts, quick transfer partial capacity, weight threshold, close-held rollback, serialization.
- Craft/build action result reasons and precedence; no resource consumption on rejected operations.
- Combat math/events: mitigation/resistance, block/parry thresholds, stamina failure, dodge iframe boundaries, telegraph→single attack, stagger and damage effectiveness.
- Raid lifecycle/grace/progression eligibility and deterministic objective-visible state.
- Map conversion/bounds/pin serialization/discovered marker policy.
- Save migration and localization-key completeness.

### Integration tests
- New-world start creates player/UI/objectives in correct mode; first real gather/eat/craft/build events advance once.
- UI modal router, input lock/pause, chat exception, focus restoration, live locale and UI-scale changes.
- Inventory↔HUD/equipment/crafting/container synchronization; partial tomb recovery with full inventory.
- Build ghost validity reason agrees with `try_place`, including range/material/workbench/overlap/ground/water and host rejection.
- Enemy wind-up/hit/block/parry/dodge/stagger/death signal ordering; remote client does not simulate AI/damage twice.
- Spawn/raid state drives banner/objective and save/continue without premature first-session raid.
- Death→tomb→respawn→map marker→recovery; marker removed only when recovery completes.
- Boat/fishing gameplay state drives HUD and closes cleanly on dismount/cancel/death.
- Screenshot director acceptance profile uses deterministic setup and does not contaminate save or marketing profile.

### E2E/playtest matrix
1. **Fresh solo, KO and EN:** clean save, seed 12345, 1280x720/1600x900; complete the first 20-minute loop with no coaching.
2. **Returning solo:** existing v1 fixture and mid-objective new save; continue, settings persistence, no tutorial replay/reward duplication.
3. **Combat:** starter gear versus passive prey, Greyling/Greydwarf, ranged enemy, group, boss; daylight/night/rain, low stamina/health, block/parry/dodge/resistance.
4. **Survival:** no food, three foods decaying, wet+cold, freezing, poison/burning, swim exhaustion, rest/comfort; verify cause and recovery.
5. **Build/craft:** missing resource, missing/wrong-level station, valid snap, overlap/range/water/support failure, collapse, inventory full/overweight.
6. **Death/recovery:** death near spawn and remote biome, partially full inventory, reload before/after tomb pickup.
7. **Navigation:** discovery, pins, altar/objective, portal/bed/tomb markers, zoom/pan at all resolutions.
8. **Traversal systems:** boat wind/speed, fishing full sequence, dungeon enter/exit.
9. **Multiplayer:** host+one client join, chat, shared combat/build/raid/death, client disconnect/rejoin, local objective independence.
10. **Accessibility/locale:** KO/EN, 100/125% UI, keyboard-only, reduced shake, high-motion combat, color-blind simulation review.

For moderated sessions log task start/end, interventions, deaths, error actions, settings used and a 1–5 confidence rating. At least five fresh players and three returning players gate Phase 4; no facilitator instruction during measured tasks.

### Screenshot matrix
Capture fixed-seed before/after pairs with safe-area guides and no debug overlays:
- Resolutions: 1280x720, 1600x900, 1920x1080, 2560x1080.
- Locales/UI: KO+EN; 100%+125% at minimum for HUD, inventory, crafting, map, settings, death.
- World conditions: meadow noon, forest dusk, swamp rain, mountain snow, night torch, dungeon dark.
- States: clean spawn objective, interact prompt, pickup/equip, low health/stamina, food/status, enemy wind-up/hit/parry/dodge, boss special, raid, valid/invalid/support build, inventory/craft/map, death/tomb, boat/fishing.
- Review each for hierarchy at thumbnail size, critical text at native scale, reticle/target occlusion, character/enemy silhouette, contrast, clipping, semantic-state distinction and consistent margins. Maintain a manifest recording seed, profile, locale, resolution, UI scale, time/weather and expected state.

### Observability
Local/developer-only structured events (console and optional `user://` QA log, never external transmission): `session_start`, `objective_shown/completed/skipped`, `action_rejected(reason, action, stamina)`, `damage_dealt/taken(type, amount, blocked, parried)`, `dodge`, `death(cause, biome, objective)`, `tomb_recovered(partial)`, `craft_attempt(result, reason)`, `build_attempt(result, reason)`, `raid_start/end`, `panel_open/close`, `locale/ui_scale`, and milestone timestamps. Aggregate per test run: time-to-milestone, rejection counts by reason, encounter duration/survival, deaths by cause, tomb recovery rate, modal abandonment and screenshot-state assertions. Logs must omit IP, nickname/chat, seed only when the test manifest already treats it as public, and any user-authored text. Disable or rotate logs outside QA builds.

## 3-scenario pre-mortem
1. **Polished HUD, unchanged confusion.** Failure: screenshots improve but first players still wander because objectives are generic text disconnected from inventory/build state. Early warning: repeated Help opens, >90-second idle gaps, objectives completed out of order or not at all. Mitigation: predicates consume real events/state, instrument milestone time, gate Phase 1 on observed no-coaching completion rather than review screenshots.
2. **Feedback makes combat noisy but not fair.** Failure: floating text, shake, bars and alerts obscure enemy silhouettes while fixed/short telegraphs and group spawns still cause unexplained deaths. Early warning: players cannot name the fatal attack, reticle/target occlusion in combat captures, high rejection/death rate despite seeing UI. Mitigation: prioritize animation/sound silhouette and attack timing before overlays, cap concurrent notifications, reduced-shake setting, archetype-specific clip tests and combat success bands.
3. **UI/state refactor breaks saves or multiplayer.** Failure: objective/inventory/build events double-fire, legacy saves replay rewards, clients consume resources on rejected placement, held stacks disappear. Early warning: differing host/client inventories, duplicate completion logs, migration fixture diffs, tomb/build mismatch after reconnect. Mitigation: authoritative action-result contracts, idempotent objective transitions, versioned default-only migration, atomic inventory operations, host/client integration tests, old-save fixtures and phase rollback boundaries.

## Risks and mitigations
- **Scope explosion across 190+ items and 7 biomes:** polish the early vertical slice and reusable primitives first; late-game receives pattern propagation, not independent redesign.
- **Programmatic UI monolith:** decompose only surfaces with independent state/lifecycle; architect reviews ownership before adding classes.
- **Fixed absolute sizes and Korean/English expansion:** use containers/safe margins, explicit minimum/maximum bounds, locale screenshot matrix and pseudo-long-string test.
- **Color-heavy Valheim palette and world overlays:** contrast tokens, backdrop/outline and redundant shape/icon/text semantics.
- **Balance changes invalidated by poor baseline:** freeze broad tuning until feedback/observability and baseline metrics are available.
- **Screenshot automation masks reality:** separate fresh acceptance profiles from granted marketing profiles; declare every injected state in manifest.
- **Controller ambition delays core quality:** prototype one gameplay/modal slice; support fully or leave explicitly out of scope.
- **Accessibility becomes cosmetic:** reduced shake, scalable UI, focus, non-color cues and keyboard completion are acceptance gates, not options.
- **Runtime/performance regression from polling and dynamic UI recreation:** prefer signals and dirty updates, pool transient messages where useful, profile 60-fps frame time during combat/raid, and avoid per-frame texture regeneration except bounded existing cases.
- **No existing test framework:** architect chooses a pinned low-dependency Godot-native harness; pure state tests begin before broad UI work.
