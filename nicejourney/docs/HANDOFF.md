# Nice Journey Development Handoff

Updated: 2026-09-17

## Workspace

- Root workspace: `D:\nicejourney`
- Godot project: `D:\nicejourney\nicejourney`
- Engine baseline: Godot `4.6.2.stable.mono.official.71f334935`
- Renderer: `gl_compatibility`
- Master specification: `D:\nicejourney\Nice_Journey_Master_Game_Specification_V2_1.md`
- Current implementation docs: `docs/IMPLEMENTATION_STATE.md` and `docs/NEXT_DEVELOPMENT_SEQUENCE.md`
- Follow `nicejourney/AGENTS.md` before further edits.

## Latest verified gate

Latest repository-wide reference validation completed successfully:

- Tests: **159 dynamically discovered**
- Failures: **0**
- Renderer/reference smoke: p50 **16.656 ms**, p95 **17.440 ms**, p99 **18.370 ms**, max **34.451 ms**
- Peak static memory reported by the latest gate: **54,566,315 bytes**
- The recurring `Save rejected: invalid profile_id` line is an intentional negative-test fixture when the suite still reports zero failures.

Run the broad gate from `D:\nicejourney\nicejourney` with:

```powershell
powershell -ExecutionPolicy Bypass -File tools\reference_validation.ps1
```

## Most recent implementation slice

Storage/economy ownership is now persistence-safe and ready for the authored Region 3 service boundary without inventing portable storage access.

New/updated files:

- `src/items/storage_state.gd`
- `src/items/profile_storage_transaction_service.gd`
- `src/core/persistence/profile_creation_service.gd`
- `src/world/region3/interactions/region3_storage_service_interaction.gd`
- `src/world/region3/layout/region3_authored_town_layout.tscn`
- `tests/test_storage_json_round_trip.gd`
- `tests/test_profile_storage_transaction.gd`
- `tests/test_region3_storage_service_interaction.gd`

Behavior now covered:

- New profiles explicitly own empty hub storage with the declared **64-slot initial tuning capacity**; older schema-v1 profiles that lack `storage_state` remain load-compatible.
- Persisted storage accepts only finite integral JSON numeric representations for capacity, stack quantities and upgrade ranks, canonicalizing them back to integers on load; fractional/nonfinite data remains invalid and live item APIs remain integer-only.
- `ProfileStorageTransactionService` stages inventory, storage and claim-ledger state together, validates the whole candidate profile before commit, preserves exact realized item metadata/provenance, supports compatible-stack merges, and leaves rejected operations bit-for-bit non-mutating. These live mutations remain DR-02-unbanked until the next coherent safe snapshot.
- The authored `r3:functional:06` Storage House now owns `Region3StorageServiceInteraction` at its existing authored approach tile. It uses `InteractionCommitAdmission`, shared `InputOwnership`, and `GameplayOperationGuard.OP_SERVICE`; modal ownership and Active Combat block admission, ordinary press interaction emits exactly one storage-service request, duplicate logical commits are rejected, and leaving range prevents remote invocation.
- The real Main create/load path now enters the authored Region 3 town through `Region3TownSessionHost`. New profiles start at the authored `R3-MAIN-START` Quest Hall approach and atomically commit `safe:region3_start` using the existing `region:3` / `checkpoint:region3_town` identities plus captured live player/resource/combat state. Existing Region 3 safe snapshots restore their saved player location. Tower entry suspends the same Region 3 runtime and Tower exit resumes it at the recorded pre-entry position rather than rebuilding the overworld or falling back to the development greybox. The Storage House trigger is therefore now a genuine live hub-service owner; deposit/withdraw UI binding is the next slice.

## Prior reusable-enemy movement slice

The reusable enemy runtime now has real prototype movement execution instead of presentation-only movement intent.

New files:

- `src/data/tuning/enemy_prototype_movement_tuning.gd`
- `src/data/tuning/enemy_prototype_movement_default.tres`
- `src/enemies/runtime/enemy_prototype_movement_driver.gd`
- `tests/test_enemy_prototype_movement_driver.gd`

Updated integration:

- `src/enemies/runtime/enemy_prototype_decision_driver.gd`
- `src/world/tower/encounters/tower_encounter_session_host.gd`

Behavior now covered:

- `approach`, `withdraw`, and `reposition_last_known` produce incremental navigation movement through a real `NavigationAgent2D`.
- Lost-sight movement uses only admitted last-known observation data; it does not chase the unseen live target.
- `hold_observe` clears movement immediately.
- Requested movement destinations are projected onto synchronized authored navigation, including generated tower-room wall/boundary cases; arrival tolerance prevents close-range jitter.
- Tower encounter sessions construct and advance movement drivers alongside decision/action-phase drivers.
- Signature actions now expose a verified `ACTIVE` delivery window only while the exact reservation and shared attack-pressure commitment still belong to the same actor/target/encounter/action-instance. The session host forwards that context without fabricating damage, delivery type, hit geometry, or timing.
- `EnemyActiveAttackDeliveryExecutor` now binds that window to the existing DR-06 direct-contact resolver only when a caller supplies an authoritative payload/contact/defense fact set. It rejects non-ACTIVE delivery, preserves duplicate-contact identity, does not consume contact identity on invalid payloads, routes successful parry interruption through the authoritative phase driver, and closes immediately on fatal target invalidation.
- Movement and signature clocks use initial reversible tuning data; they must not be treated as final balance.
- Floors 5 and 10 now have explicit live regression coverage proving exactly three elite identities retain the existing reversible HP/Physical-defense/Arcane-defense/poise modifiers, while every active resident—elite or normal—uses ordinary counted FULL-AI ownership and no elite identity fabricates committed attack pressure.
- ACTIVE delivery windows are also proven closed after interruption or target invalidation, so obsolete committed actions cannot leak attack-delivery authority.
- Tenth Warden contact delivery is now explicitly closed once its existing recovery state begins; successful DR-06 parry of a parryable boss contact forces that same authoritative recovery state, so a parried boss cannot continue delivering contacts during recovery.
- The reusable-enemy decision driver now implements the locked action-budget repeat-suppression requirement with reversible tuning: after two successful signature commitments, one otherwise-legal signature evaluation is suppressed only after the action has fully recovered and cooldown is ready. Movement/objective priorities remain available and no new defense action is invented.
- Successful signature commitment now retains the exact admitted target-position observation as read-only delivery context. Later visible or unseen target movement cannot rewrite that committed snapshot; it is preserved for future authored retarget/geometry rules without declaring a universal aim-lock policy.
- Region 3 structure collision now matches the authored inclusive tile convention physically: all 20 structure rectangles cover the full minimum-through-maximum tile footprints, all eight functional entrance/approach centers remain open, route centerlines remain clear, and collision-aware route/service traversal stays reachable. This corrects the former one-tile physical-size mismatch without moving authored anchors.
- Region 3 traversal QA now samples the actual player collision shape along every authored route plus all functional entrance/approach centers, so the accepted route centerlines are proven physically usable by the live 12×10 player collider rather than only by tile-center occupancy.
- `Region3RouteNavigationGraph` and the scene-owned `RouteNavigator` compile the 13 inspector-authored route lines into one deterministic runtime path graph, splitting circulation segments where authored connector/approach points touch them. All eight functional approaches and all four main approach endpoints have paths to the Central Tower approach; disconnected geometry is rejected and ordinary off-network starts return no path instead of silently snapping/teleporting. For explicit escort-style re-pathing, callers may request a bounded rejoin plan: the navigator returns the nearest route position, physical rejoin distance and onward path, rejects over-distance/unauthored-goal cases, and never mutates actor position or the persistent authored graph.
- `Region3RouteFollowDriver` now physically moves a caller-owned `CharacterBody2D` through those authored route/rejoin waypoints using caller-supplied speed, arrival tolerance and maximum rejoin distance. Wait state stops movement, physical collision emits explicit repath feedback without deciding quest failure, blocked actors cannot teleport through obstacles, and callers can replan from the actor's real post-collision position after the blocker changes. Failed/off-network configuration cannot retain a half-valid movement plan. This is generic movement infrastructure only; no Region 3 escort actor, goal or failure policy is invented.
- `MapViewService` + the GameplayRoot-owned `MapMenu` provide the locked three-layer map shell: World, Region and Tower Floor. World exposes exactly 12 region identities with only Region 3 playable and the other 11 future-locked; Region exposes the authored Region 3 revision/160×160/20-structure contract; Tower exposes current floor identity/revision/clear/checkpoint metadata and only physically discovered room geometry. `FloorInstanceState.discovered_room_ids`, `TowerFloorDiscoveryService`, and all-room walkable-geometry discovery triggers now own that state: activation marks only the exact arrival room, later physical room entry records that room idempotently, legacy floor saves without the field load as undiscovered, and map summaries exclude undiscovered room IDs plus semantic tags/module IDs. Region quest/risk discovery remains unauthored. For Tower rooms, discovered `combat`/`elite`/`boss` tags are reduced to stable `risk:*` marker IDs only after the room is discovered; no unrelated tags or module metadata are exposed. The Tower Floor layer renders only filtered discovered-room rectangles through `MapRoomCanvas`; anchored checkpoint markers remain position-hidden until their room is discovered, and authored room connections remain absent until both endpoints are discovered. The canvas independently rejects markers/connections outside the visible discovered-room set and uses distinct risk-marker shapes instead of color alone. Tower travel eligibility is also exposed read-only through the existing `TowerAccessMenuService` + `GameplayOperationGuard`: selectable floors and authoritative Sigil/operation-blocked reasons can be inspected, while `travel_action_available` remains false and the map cannot invoke or bypass travel. The same read-only snapshot now preserves player level, destination Recommended Level/Danger, actually-active primary objective ID, elite target and boss warning; special hazards remain explicitly `Unknown` because the current floor catalog has no authored hazard owner. World remains textual because the compact 12-region list already satisfies the prototype World-map view contract. Region now has a separate graphical canvas generated from the validated authored scene: it renders the exact 160×160 reservation, town/plaza bounds, all 13 inspector-owned road/connector polylines and only the fixed public Central Tower landmark. It deliberately withholds service identities, quest markers, explored-subzone state, Region checkpoints and Region danger markers until those states have genuine owners. Modal ownership, layer switching and Map-key close suppression are executable-test covered. `PauseCoordinator` now routes `Esc` as modal-back before opening Pause even while the tree is unpaused; GameplayRoot closes Map/Tower Access/Quest Log/Skills through that shared signal, suppresses the triggering Escape until release, preserves nested accessibility-settings back behavior, and retains ordinary Pause when no other modal owns input.
- The old debug-only top text block has been replaced by a live `CombatHUD` surface backed only by authoritative runtime owners. HP and stamina are always present, Mage alone receives a mana row, the approved prototype creates no ammunition row, defense state mirrors `ClassCombatRuntime`, active cooldowns come from `ActionStateMachine`, and Tower context shows current floor, authored Recommended Level and the shared `DangerEvaluator` result. Bars always include numeric text rather than color-only state. `QuestTrackerViewService` now adds only the current Tower floor's active primary objective: generic Annihilation reports defeated/required counts, Escort reports route progress + wait state, Tower Defense reports completed waves + objective HP, and Floor 10 uses its dedicated Tenth Warden boss-completion state. Completed objectives report completion; malformed objective state fails closed; unrelated side quests cannot become the current Tower tracker; and no timer is invented because no current timer owner exists. The HUD participates in the existing 100/112.5/125% UI/text scaling layer and remains inside the 640×360 minimum canvas at the largest supported setting. `SkillHudViewService` also renders the profile's exact two persisted active-skill loadout slots through the existing skill icon catalog, authored display names and ranks. These slots are explicitly labeled loadout-only: active skill execution is not yet wired, so no fake action-ready state, cost amount or per-skill cooldown is shown; temporary quest-skill overrides preserve their exact stable ID and fabricate neither catalog metadata nor an icon. Status-effect display remains absent until a live status-state owner exists. A distinct Tower minimap now reuses the already-filtered discovered-room map snapshot: it shows only discovered room rectangles/connections/risk/checkpoint data and the player's real floor tile while that tile lies inside discovered room geometry. Moving into an undiscovered room cannot reveal that room or even the player marker; after authoritative room discovery the geometry and marker become visible. The compact minimap remains inside the 640×360 minimum canvas at 125% UI/text scale.
- `QuestLogViewService` + the GameplayRoot-owned `QuestLogMenu` expose persisted quest ownership plus the persistent §26.2 pending-normal-reward queue. Unaccepted catalog definitions are not exposed as accepted quests. Each persisted quest reports exact quest/kind/family/state/stage identity, authored scope/floor location, family-specific objective progress, recorded leave/failure reason IDs when present, and completed objective/quest outcome state. Pending reward entries preserve exact claim/source/item IDs and quantities even after the original NPC/source is gone. The Quest Log now has the locked outside-Active-Combat Claim interaction through `PendingRewardClaimTransactionService`: capacity is revalidated, repeat clicks cannot duplicate value, Active Combat disables Claim through the shared service guard, and a successful claim mutates only live profile item/economy/claim state. Per DR-02 it is explicitly **unbanked** until the next legitimate coherent safe snapshot; dying first restores the pending claim together with removing its unbanked item, while a later safe commit banks both sides together. No ad-hoc save is created by Claim. Because no production acceptance-rule or quest-to-leave/retry-policy catalog exists yet, those policy owners remain explicitly unavailable. Malformed objective/economy state fails closed. The modal uses shared `InputOwnership`/`PauseCoordinator`, suppresses `J`/Escape until release, blocks modal stacking, returns detached snapshots, and stays inside 640×360 at 125% UI/text scale.
- `SkillTreeViewService` + the GameplayRoot-owned `SkillsMenu` now provide the authored `K` read-only skill-tree/loadout surface. The view exposes exactly the current class's six approved skills, persistent ranks, learned state, exact two-active/two-passive equipped IDs, authored names/mechanic IDs/resource type/prerequisite-event IDs, max rank 3, and the locked one-skill-point rank cost. Temporary quest-skill override state is preserved exactly. The surface resolves existing skill icons, uses stable-ID selection, modal ownership, `K`/Escape release suppression, and global 100/112.5/125% UI/text scaling. Purchase and loadout-swap actions remain deliberately unavailable because GameplayRoot still lacks a durable skill-purchase save transaction and an authoritative safe-town/rest interaction owner; prerequisite-event satisfaction is likewise not guessed.
- New-profile item ownership now matches the locked DR-04 starter kits instead of leaving persistence empty while the character visibly holds starter gear. `StarterEquipmentCatalog` + `StarterInventoryInitializationService` persist only the approved identities/handedness: Melee `starter_sword` + `starter_shield`, Ranged `starter_bow`, Mage `starter_staff`; all 16 normal slots, Gold, protected items, quick references, armor/accessories and unauthored rarity/affix/upgrade metadata remain empty. Existing/legacy item ownership is never rewritten. Enabling this exposed a latent JSON normalization defect: Godot JSON parses integral numbers as floats, so persisted `InventoryState`/`EquipmentState` validation now accepts only finite integral numeric representations while live item APIs still keep the stricter integer-only `NormalStackQuantityValidator` contract.
- `InventoryViewService` + the GameplayRoot-owned `InventoryMenu` provide the `I` Inventory/Equipment surface over persisted state. It renders exactly 16 normal slots, all five fixed equipment slots, Gold, protected quest/key ownership, four consumable quick references and only metadata that is actually persisted. Search can match stable IDs/rarity/affixes and sorting can order by definition or quantity, but both are presentation-only and proven non-mutating. Missing item flavor/display metadata is not fabricated; absent rarity/affix/upgrade/source data is explicitly unavailable. Confirmed Destroy is now live for selected normal stacks only; equipped/protected ownership never exposes the destructive control, cancel is non-mutating, accepted destruction cleans stale quick references, and DR-02 leaves the mutation unbanked until the next committed safe snapshot. Tower-floor Drop is also live for selected normal stacks: `InventoryDropTransactionService` moves the exact full stack into validated floor-local `player_drop` persistence, `TowerPlayerDropPickup` reconstructs fresh/restored world pickups from that record, immediate self-repickup is suppressed until the player exits, capacity rejection leaves both live pickup and saved source intact, and successful pickup restores the exact instance/metadata through the reverse transaction. Region/world Drop stays disabled because no Region 3 persistent loose-item owner exists yet. Equip/use/sell and quick-slot assignment remain withheld where their authoritative mutation/content owner is absent. Inventory shares modal exclusivity, `I`/Escape release suppression, detached snapshots and the global 100/112.5/125% accessibility scaling; its fixed shell + internal scroll remains inside the 640×360 minimum canvas at 125%.

Focused movement, reservation/pressure ownership, signature-phase, ACTIVE-delivery, elite-runtime activation, session-host, automatic encounter-preparation, Region 3 collision/navigation/follow plus authored Storage House interaction admission, tower discovery/map-data/UI/canvas boundaries, the dedicated **QA-MAPS navigation/UI scenario**, live combat-HUD/resource/objective/active-loadout/minimap/Quest-Log/Skills/Inventory integration/accessibility, starter-equipment persistence/JSON round-trip, economy/storage JSON normalization, explicit empty 64-slot storage for new profiles plus profile-level atomic deposit/withdraw ownership, persistent pending-reward visibility + live DR-02-safe Claim, confirmed normal-item destruction, live Tower full-stack Drop/pickup reconstruction plus save-time player-drop schema validation, Level 1–10 XP-threshold tuning, editor-parse and broad validation all pass at **158/0**.

## Important enemy-runtime fixes immediately before this

The reusable enemy action runtime was hardened for external invalidation:

- Actor death or target death now reconciles stale action ownership instead of leaving local phase state desynchronized.
- Attack reservations are rejected against defeated targets.
- Target defeat releases attack-pressure/reservation ownership.
- Fixed-tick phase drivers tolerate authoritative death/target invalidation without continuing obsolete committed actions.

Relevant files:

- `src/enemies/runtime/enemy_archetype_runtime.gd`
- `src/enemies/runtime/enemy_signature_action_phase_driver.gd`
- `src/combat/runtime/combat_encounter_runtime.gd`
- `tests/test_enemy_signature_action_phase_driver.gd`

## Current major implemented systems

The project currently includes, with focused/broad regression coverage where already accepted:

- Atomic three-slot persistence and save coordination.
- WASD movement, dodge/dash, stamina, camera, side-only facing, accessibility/control settings and audio buses.
- M2 action phases, cooldowns, input buffer, aim locks, interruption, contact identity and DR-06 damage/defense foundations.
- All 12 reusable enemy archetypes, V02 visuals, threat cards, decision/reaction timing, observed-fact memory, encounter blackboards, action reservations, global FULL-AI cap, attack-pressure budget, fixed-tick signature phases, and now prototype navigation movement.
- Deterministic quest-aware tower floor generation/validation, persistent floor instances, travel planning/commit, safe checkpoints, save/load restoration, death/retry rollback, live floor session hosting and automatic room-entry encounter realization.
- Tower Access Menu with Recommended Level/Danger confirmation rules and Sigil/combat checks.
- Prototype Floors 1-10 encounter content/runtime allocation, including required Floor 5/10 elite counts.
- Quest-family runtime support for Annihilation, Escort and Tower Defense plus leave-rule infrastructure.
- Inventory, storage, Gold economy, merchant stock, atomic buy/sell, deterministic loot, quest-reward overflow claims and Blacksmith upgrade transaction foundations.
- Region 3 authored town structure/collision/traversal validation and functional building approach checks.
- Tenth Warden runtime/presentation foundation, two-phase contract and Floor-10 clear boundary.

## Highest-priority continuation

Continue from the enemy/runtime integration lane without redoing already-green systems.

1. Add authoritative per-archetype attack execution/geometry only where the master or a combat-authority resource supplies the missing payload/shape data. Do **not** derive gameplay geometry from presentation telegraphs or guess damage timing.
2. Bind the now-verified `ACTIVE` delivery window to actual DR-06 attack delivery only for archetypes whose authoritative payload/geometry becomes available; reservation and shared pressure ownership are already enforced at the window boundary.
3. Continue elite content and remaining encounter composition only within existing floor population/FULL-AI constraints and only where modifiers/content are authored rather than inferred.
4. After each coherent slice: focused tests, editor parse/import, then `tools/reference_validation.ps1`.

Do not silently lower the global 12 FULL-AI limit, bypass attack reservations, or use raw player inputs/unseen live positions for AI decisions.

## Region 3 Batch 2 art/provenance status

Do not mark Region 3 Batch 2 final yet. V02 preview derivatives for decorative 11–12 and the five support categories are currently wired into inspector-owned profiles and mechanically validate, but they are not accepted production sources because the exact generated-source package/hashes/provenance are still unresolved. A root-level `Nice_Journey_Region3_Decorative_V02_Batch2.zip` exists but is only **14,913 bytes**, SHA-256 `bedd828af892f70e8604c36eee9ad9452757e988c88f729dcc238194f673ad1e`, and has no readable ZIP central directory; exact source PNGs are not present elsewhere in the workspace. Treat that archive as corrupt evidence only, never accepted provenance.

Required V02 source categories remain centered on:

- decorative structures 11-12
- town props
- ground/road
- ruins modules
- outskirts support
- risk-zone support

Known image-generation failure mode: the image generator repeatedly produced dashboard/catalogue/presentation-board output instead of raw game art. Those outputs are rejected and must never be cropped/reused as production sources.

The accepted workflow is:

`generate -> visually inspect -> accept/reject -> transfer exact source -> SHA256 -> deterministic derivation -> provenance -> inspector/resource integration -> validation`

A temp clean prompt exists at:

`tmp/imagegen/region3_batch2_clean_prompt.txt`

The image-generation protocol explicitly prevents repeatedly burning attempts in a contaminated image context. Use a clean image-generation context for another attempt, keep the art simple/not over-detailed, and keep it strictly pixel art with no dashboard/UI/text/labels/panels.

The exact accepted Batch 2 source package/provenance remains unresolved. Do not treat a truncated/corrupt local archive as accepted provenance.

## Still open / not final

- Exact per-archetype attack geometry and telegraph-to-hit alignment for the reusable enemy roster.
- Full elite behavior/content pass.
- Final Tenth Warden art and final authoritative telegraph/timing tuning.
- Complete Region 3 Batch 2 exact-source provenance.
- Broader production UI/theme consumption, including inventory/quest/map/service surfaces.
- Final audio/accessibility production pass and stress verification.
- Complete authored quest packaging/leave consequences where still intentionally unassigned.
- Full finite-route progression/economy balancing evidence.
- DR-08 final minimum-hardware certification on the specified i5-8250U/UHD-620-class reference configuration. Current developer-machine smoke evidence does not substitute for that certification.

## Guardrails

- Master spec is authoritative; do not invent lore, mechanics, geometry, quest outcomes, combat numbers or test evidence.
- Preserve exact accepted generated sources, hashes, deterministic derivation records and provenance before deleting/replacing V01 material.
- Sprite/gameplay presentation stays inspector/resource owned; avoid hardcoded asset-path/frame hacks where a profile/resource already owns the data.
- A generated floor must validate completely before exposure/commit. Never expose a partial invalid floor.
- Ordinary revisits preserve persistent defeated actors/rewards; failed-attempt retry restores the latest committed safe snapshot and never chooses a new seed.
- Underleveled floor entry remains allowed; Danger III-V requires warning/confirmation, not a hidden hard gate.
