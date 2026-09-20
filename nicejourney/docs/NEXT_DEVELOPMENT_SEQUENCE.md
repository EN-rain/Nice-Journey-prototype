# Nice Journey — Next Development Sequence

Updated: 2026-09-20

> Navigation note: this file is the current dependency/order plan, not implementation history. Completed-wave detail belongs in `IMPLEMENTATION_STATE.md`. Read only the current priority relevant to the task.

## Authority

- Design authority: `../../Nice_Journey_Master_Game_Specification_V2_1.md`.
- Current implementation truth: `IMPLEMENTATION_STATE.md`.
- Documentation router: `INDEX.md`.
- DR-01 through DR-08 are resolved and approved. Do not recreate old decision holds from historical text.

## Verified current baseline

- Godot 4.6.2 stable Mono, `gl_compatibility`; internal canvas 640×360 and minimum supported output 1280×720.
- Latest broad integration gate: `docs/evidence/reference-validation-latest.json` reports **271 dynamically discovered tests, 0 failures** on 2026-09-20; the suite includes status player/enemy parity and production readiness, Warden authored contact-tick admission, Region saved-safe-location map/UI, economy/side-quest cross-resource integrity, all twelve archetype stat records, Region 3 live quest/restore/retry, Summoner, nine active PLAYTEST skill effects and finite-route progression. Headless editor parse, configured main-scene smoke and renderer-active reference smoke are green. Reference-machine frame/memory measurements remain greybox evidence only, not final DR-08/minimum-hardware acceptance. The recurring `Save rejected: invalid profile_id` line is the intentional negative fixture.
- Save flow: Pause exposes player-facing manual save; Region 3/Tower safe saves restore exact supported player position; Active Combat, death/retry and transient movement/action states reject manual save. Production Tower Escort save/load is supported only when exact actor position, HP, route index and wait state are serializable; unsupported Escort contexts still fail closed. Autosave/checkpoint coverage includes initial hub, unlocked-floor entry, Floor 10 pre-boss, floor completion exit, Region 3 hub re-entry after completed-floor exit, and accepted pending-reward claims.
- Tower progression: live Floors 1–9 can complete their current primary objective, exit safely, return to Region 3, turn in at Quest Hall, clear the floor and unlock exactly the next floor. Floor 10 turn-in ends the prototype milestone with no Floor 11. Floors 2–10 now have complete production-v01 primary quest contracts/objective allocation at Quest Hall `r3:functional:02`; prior-floor turn-in exposes the next primary as `Available`, and a separate Quest Hall interaction explicitly accepts it into `Active`. Floor 10 boss combat is now wired with explicit PLAYTEST placeholder stats, five-move hit/timing/payload definitions and player defender tuning; final gameplay balancing remains separate.
- Floor 10: GameplayRoot's conditional Sanctum caller, shared combat/FULL-AI ownership, live authored contact-delivery driver and `Floor10BossProgressionBridge` binding are green. `PlayerDefenderFactsProvider` now supplies the production defender-facts ownership path from live dodge/defense/aim state when a valid `PlayerDefenderFactsTuning` resource is assigned. The shipped Floor 10 boss-room trigger now starts the assigned, validated PLAYTEST boss/defender resources. Its boss sprite is hidden behind a native ColorRect; Phase 2 and the authored heavy-recovery weak point have distinct colors. Boss stamina recovers deterministically after move costs; Sanctum exit releases live combat owners. All provisional values are explicitly flagged as placeholders rather than final production balance.
- Region 3 services: live service interactions mark exact discovered service identities. Storage, Quest Hall, Training Hall, merchant, Blacksmith and recovery integration boundaries are wired. Shipped Inspector PLAYTEST resources provide General Merchant and Clinic stock, three starter-weapon upgrade recipes and Inn/Clinic atomic Gold/resource/save recovery; cross-resource validator checks Clinic category, material source/stock, recipe coverage and recovery mappings, and the vendor catalog rejects cross-vendor arbitrage. Production-approved stock/prices, recipes and recovery numbers remain unauthored; do not equate playable provisional values with final balance.
- UI Inspector authoring: `tools/audit_ui_layout.py` protects against wrapped Label/container minimum-size warnings; 28 scene Labels, including Quest Log Detail, now have Inspector-owned nonzero minimums. Inventory and Tower runtime buttons use Inspector-assigned PackedScene templates, and Tenth Warden placeholder node/color presentation is Inspector-owned. Preserve authored gameplay constants and runtime text logic instead of indiscriminately externalizing every literal.
- Inventory: Equip/unequip, confirmed Destroy, Tower and Region 3 full-stack Drop/pickup reconstruction, four quick-slot bind/clear actions, and 1–4 consumable input/use are wired. The Inspector-owned PLAYTEST tonic heals 25 live HP when missing health and consumes one owned unit with exact stack/quick-reference cleanup; full HP, modal/death suppression, material/gear and unauthored items reject. Use is unbanked until the next safe snapshot. New quick-slot binding requires explicit `ItemCategoryCatalog` proof that the item definition is `consumable`; gear/material/unauthored categories reject, while legacy persisted references remain load-compatible.
- Status: Burn/Slow HUD rows read the authoritative live player runtime. Supported status states are normalized, serialized in class combat safe state, handed off before normal encounter teardown, restored after save/load and imported into the next encounter. Production Burn cadence/damage and Slow aggregation/application values are still absent. Flagged playtest values now drive enemy and player movement Slow (walk/run/dash velocity only) with strongest-only clamping and immediate speed restoration on expiration; dodge/action clocks are unchanged.
- Escort/side quests: production Tower Escort is live for Floors 2/6/8 with authored 80 px/s speed, 2 px tolerance, 12×10 collision, 100 HP, route/wait/failure/retry policy and exact save/restore state. Region 3 R3-SIDE-A/B/C now execute through the live quest host with PLAYTEST counts 3 / 5 / 2+2+2, physical escort/defense actors, durable failure/retry/restore, and separately claimed Quest Hall XP 40/60/80; final content/balance approval remains open.
- Region map/state: the authored `Region3WorldLayoutDefinition` supplies the validated R3-TOWN/OUTSKIRTS/ROADS/RUINS/RISK zone reservations and stable quest-anchor identities. `ProfileSnapshot.region_state` persists the Region 3 map revision, physically explored zone IDs and validated Region-local `player_drop:*` loose-item records. GameplayRoot records only actual zone entry; read-only map opening cannot discover zones; map-revision mismatch fails closed. `MapRegionCanvas` renders only validated explored rectangles. Region Drop now stages Inventory + ClaimLedger + Region loose-item state together, rejects out-of-bounds/nonfinite Region-local coordinates before mutation, validates restored coordinates against the active authored layout before activation/map exposure/pickup, reconstructs fresh/restored pickups, preserves sources on capacity rejection and never writes Tower floor state. The dedicated Region transaction gate covers real JSON save/load, metadata, exact ownership, invalid-state and duplicate-transaction rejection. A profile-wide normal-item ownership gate now rejects duplicated instance IDs across inventory, storage, Region player drops and all Tower floors while preserving legitimate non-owning references and resolved-loot compatibility. Used services remain independently revealable from live service discovery. Exact quest-marker tiles, Region checkpoint geometry and concrete per-hostile-subzone Recommended Levels remain withheld with explicit reason IDs.
- Art: Region 3 functional landmarks and decorative 01–10 are accepted V02. Batch 2 remains blocked because `D:/nicejourney/Nice_Journey_Region3_Decorative_V02_Batch2.zip` is truncated/corrupt and the seven exact source PNGs are absent; existing preview derivatives are not accepted provenance.
- Audio: native playback/lifecycle and GameplayRoot music-state routing are green. Exploration/combat follow shared Active Combat; boss/recovery are explicit overrides; teardown releases persistent music. Final production routing data/streams and representative mix evidence remain absent.
- QA-PERF-WORST historical quick-smoke evidence exists from an earlier exported run, but export/package testing is now deferred during normal development. Keep `final_hardware_acceptance=false` and `certification_blocked=true`. Current Godot work should use editor/headless/runtime evidence only; any future full release/minimum-hardware protocol must be a separately requested certification task after representative projectile/audio/boss load exists.

## 2026-09-20 status / Warden / Region 3 map completion status

Status code now validates source-scoped strongest/refresh against live player/enemy parity, and the generator reproduces the *existing* PLAYTEST 180/30/2 Burn and 150/0.25/0.4 Slow resource instead of overwriting it with obsolete content. An unassigned Inspector production-authoring template records missing approval; final numeric authority is not enabled. The Tenth Warden enforces per-hit authored ACTIVE tick contact, valid move costs/regeneration/telegraphs, projectile/movement data and irreversible phase-transition semantics. Existing five moves/two phases and every shipped numeric stat/shape remain PLAYTEST, subject to three-class manual fairness and final signoff. Region 3 layout validates any future exact quest/checkpoint authoring; current exact tiles/checkpoints and four zone-level choices remain withheld because §24.12 supplies bands and greybox footprints only. A validated saved safe *position* is now mapped separately from fixed checkpoints/fast travel, but only for physically explored Region 3 geometry. The superseding broad gate passed **271 tests, 0 failures**. See the top `IMPLEMENTATION_STATE.md` closure for exact ownership and tests.

## 2026-09-20 code-only completion status

All three user-selected work areas are integrated with PLAYTEST content: R3-SIDE-A/B/C live quests with recovery and once-only 40/60/80 XP claims; bounded persistent Summoner reinforcement with shared FULL-AI registration and cleanup; and Tenth Warden movement, locked targeting, directional attacks, traveling Arc Volley and positional Punishing Step. See `IMPLEMENTATION_STATE.md` for exact ownership, scope and focused verification. Do not reopen these runtime foundations without a regression. Provisional art/balance and final manual readability remain separate.

## 2026-09-20 skills / combat / progression completion status

The three user-selected code-only areas now have live PLAYTEST execution and broad regression: nine active skills retain Q/R clock/cost/ward/damage behavior, with collision-aware Driving Thrust and Backstep motion, distinct sequential Fan Shot, Backstep dodgeable-only evasion wired into enemy/boss defender facts, and obstacle-limited projectiles; Controller Slow and Burn support validated independent caster/source identities without changing their provisional magnitudes; primary Quest Hall XP is provisionally 80 × floor number, so the ten finite primaries plus the separately claimed 160-XP boss reward reach the existing 4,500-XP Level-10 cap without optional farming. Side A/B/C stay at 40/60/80 XP. The Inspector-owned required-route audit rejects underfunded bundles. Existing safe-save/claim-ledger guards and 2+2 loadout ownership remain in effect. Rank-2/3 magnitudes/costs/recovery and all nine equipped passive effects are now live through dedicated PLAYTEST Inspector resources, profile-bound reapplication, real player movement/resource/poise/damage delivery and HUD preview; stat-mirror XP commits roll back failed partial application and check live readback before saving. The superseding 2026-09-20 broad gate discovered **266 tests, 0 failures**. Production-approved action/stat/reward authority, exact numerical balance and manual readability/fairness remain open; the values are not final simply because the runtime is green.

## 2026-09-20 economy / Region 3 exploration / UI completion status

The selected code-only areas now include strict persisted vendor number/quantity bounds and JSON integrity; the existing Inspector PLAYTEST stock, starter upgrades and Inn/Clinic service transactions remain live without fabricated final prices. Region 3 world zones can own a single exact Inspector Recommended Level within their master bands, and discovered-only risk markers use live player level plus existing DangerEvaluator, but shipped exact levels remain -1 until explicitly authored. Exact quest-marker tiles and checkpoint coordinates are also still withheld. Merchant and Blacksmith now provide non-mutating affordability/missing-resource previews; Quest Log preserves pending-claim selection; Region Map presents source-backed risk via text and shape; Merchant, Blacksmith and Storage now consume global accessibility UI/text scale. Economy/map/UI focused tests and the 261-test broad Godot reference gate pass. See `IMPLEMENTATION_STATE.md` for exact code and limitations. Final economy/region content approval, complete accessibility readability under representative content and manual playtest remain separate.

## Current priority order

The expanded `test_three_class_required_route_live_qa.gd` now exercises each class's actual basic-attack HP delivery against the first live resident of every Floor 1–9 encounter, all real resident/primary objective bindings, physical Escort waypoints and goal on 2/6/8, defense wave defeats on 3/7/9, annihilation on 4/5 and seven real Floor-10 residents (including exactly three elites) outside the boss, then each class's normal basic hit against the live Warden, irreversible Phase 2 and terminal progression bridge. All three classes return through actual exits, persist/check each checkpoint, turn in at Quest Hall, reach finite Level 10 and reject duplicate XP. Controlled positioning and fatal finishing damage remain test fixtures; normal-damage full-route survival, under-pressure escort/defense, boss five-move human-input fairness, approved final balance and visual readability remain open. The test's process-specific save root and complete action recovery prevent parallel-suite collisions and blocked safe-boundary travel. The rerun `tools/reference_validation.ps1` passed 273/0 with editor parse, main-scene and GL Compatibility renderer-active reference smoke (`docs/evidence/reference-validation-latest.json`, generated `2026-09-20T08:14:11Z`); this working-tree gate includes concurrent uncommitted art and is not a minimum-hardware certification.

### 1. Tenth Warden playtest and final balance

The shipped boss encounter is now playable through the normal Floor 10 trigger using `src/enemies/boss_tenth_warden/runtime/tenth_warden_playtest_v01.tres` and `src/data/tuning/player_defender_facts_playtest_v01.tres`. Both are inspector-editable, explicitly `playtest_placeholder = true` and reproducible by `tools/create_tenth_warden_playtest_tuning.gd`. Their stats, phase cadence/timing, move costs/payloads, temporary shared hit geometries, 50% transition, heavy-recovery weak-point and 0.12-second-dodge-compatible defense window are **provisional playtest hypotheses**, not approved final balancing.

Provisional movement, locked aim, directional melee, actual Arc Volley projectile travel and Phase-2 weak-point timing have focused Godot coverage. Punishing Step now uses a scene-authored PLAYTEST rear/proximity condition during live action selection. Next collect representative in-engine/manual play readability, telegraph alignment and dodge/parry fairness evidence; final attack geometry and balancing still require approval. Preserve two phases, exactly five move families, no adds/healing, no extra boss reward, and no Floor 11. Replace placeholder resources with genuinely approved tuning after playtest evidence; retain the `playtest_placeholder` diagnostic until that replacement.

### 2. Promote provisional Region 3 / economy / progression content after live evidence

The user-requested code-only playtest pass is inspector-assigned in the shipped Gameplay scene: `region3_services_playtest_v01.tres` (General Merchant, Clinic stock/Recover, three Blacksmith starter-weapon upgrades, Inn/Clinic costs), `progression_playtest_v01.tres` (Level 1–10 policy, nine stat/skill-point growth entries, class baselines and 14 separately claimed finite quest/boss XP definitions), `region3_side_quests_playtest_v01.tres` (A/B/C counts 3 / 5 / 2+2+2 and provisional reward/retry/leave data), `active_skills_playtest_v01.tres` (nine action clocks and rank-2/3 adjustments), and `passive_skills_playtest_v01.tres` (nine equipped-passive rank effects). All remain explicitly provisional; no final balance authority is inferred. Ten primary Quest Hall turn-ins pay provisional XP through separately persisted claims with no duplicate payout, real HP/stamina-cap/skill-point growth, failure rollback and Quest Hall retry; the Region 3 side quest sources use actual `QuestCatalog` IDs and are earned through the live quest host with durable once-only Quest Hall XP claims. The separately claimed boss XP follows verified durable Floor 10 turn-in; ranked active-skill Q/R clocks and provisional player melee/projectile/pulse/ward effects are live. Aegis Ward blocks through the existing defender snapshot during its Inspector-authored window without enabling mage parry or permanent shield controls. Starter-weapon Blacksmith ranks affect real basic and active-skill attack payloads via Inspector-authored playtest tuning. Side quest actor anchors, attributed spawn/wave delivery, escort/defense runtime and finite budgeted Summoner reinforcement are live with focused tests. Final skill/boss balance, representative readability and final production content approval remain open.

Next complete real data and runtime integration:

- General Merchant stock/prices;
- Blacksmith `UpgradeRecipeDefinition` set;
- Inn/Clinic prices, recovery payloads, stock/save-event data;
- R3-SIDE-A/B/C final production-approved enemy/wave/objective/retry/leave balance (live PLAYTEST execution is complete);
- production skill `ActionDefinition` resources;
- production `LevelProgressionPolicy` data: persisted XP semantics, Level-10 overflow behavior, per-transition skill-point grants, exact automatic-stat field/base/growth values;
- concrete stable XP reward definitions/source IDs and amounts for main quests, side quests, boss completion, and only explicitly authored encounter/elite/exploration rewards before wiring any live award caller.

The provisional values above are explicitly for the requested playtest pass and not source-of-truth production balance. Verify and replace them with approved numbers/content before final acceptance; preserve durability, duplicate-claim and safe-state guards.

### 3. Validate and replace provisional combat/status content

`enemy_attacks_playtest_v01.tres` supplies validated temporary DR-06 geometry/payloads to live Tower encounter residents for nine damaging archetypes; Support/Summoner/Controller retain their non-damage signature boundaries. `status_effects_playtest_v01.tres` applies temporary Burn HP/defeat ticks and strongest-only Slow to enemy movement. These are not final production combat/status authorities. Live player Burn HP/fatal-defeat mirrors and separate caster/source Slow/Burn reapplication and cadence are now covered by focused regressions; next obtain manual contact physics/aim/dodge-window fairness evidence and approved final numeric values.

- supply final per-archetype DR-06 attack payloads/hit geometry from accepted combat data;
- finalize Burn cadence/damage and Slow aggregation/application rules before production use;
- add defensive enemy action anti-spam only when genuine dodge/parry/block/feint actions exist;
- keep presentation telegraphs non-authoritative.

### 4. Region 3 map/content/art completion

- add exact quest-marker tiles, Region checkpoint geometry and concrete Region danger data only when genuine authority exists;
- recover/provide the seven exact Batch 2 generated source PNGs before accepting decorative 11–12/support V02;
- then finish ground/road/ruins/outskirts/risk-zone dressing and selected functional interiors;
- keep the already-green 20-structure, route graph, collision, service discovery and side-quest staging foundations.

### 5. Tower/UI/audio production content

- replace provisional Tower room art through existing inspector/resource presentation boundaries;
- add final UI art/theme consumption where still provisional;
- assign representative/final audio streams and routing content through the existing gameplay music-state wiring, then collect mix and sound-off/mono evidence;
- continue non-basic action/skill VFX only when real action owners exist.

### 6. Representative final performance/readability pass

After representative projectile/audio/boss-content load exists:

- renderer-active combat/readability captures;
- supported aspect-ratio and raster alignment review;
- final placeholder cleanup/provenance audit;
- Godot editor/runtime performance and readability evidence only during normal development;
- final repository regression.

Release-export and packaged-build performance validation are explicitly deferred. Do not run export testing unless the user separately requests a release/certification task.

### 7. DR-08 minimum-hardware certification

This remains a future release/certification task, not part of normal Godot development QA. Run it only when the user explicitly requests minimum-hardware/release certification. Until then, keep `final_hardware_acceptance=false` and do not run export/package testing as a side effect of unrelated development work.

## Open process gate

Wave 24B poise/Burn/Slow implementation is prime-validated, but its deferred independent read-only QA pass remains open when the approved non-Codex review path is available. This is a review/process gate, not a reason to reimplement the feature.

## Closed areas — do not redelegate without a regression

Do not casually redo these established foundations:

- M0 persistence/recovery and safe-boundary save coordination;
- M1 movement/camera/climb/modal foundations;
- action-state/contact/input contracts;
- DR-04 starter runtime, DR-05 skill/loadout foundations and DR-06 shared combat resolver/status semantics;
- retry/failure rollback and quest/Tower Sigil/Floor progression foundations;
- global FULL-AI, Active Combat, attack reservation and attack-participation contracts;
- player V03 body integration and current V02 equipment/VFX/telegraphs;
- all twelve enemy V02 presentation scenes and threat-card identities;
- Region 3 eight functional landmarks and decorative 01–10 V02 integration;
- inspector/resource presentation architecture for Region 3, tower, Tenth Warden and UI.

## Validation policy

- Iterate with the narrowest meaningful focused Godot test.
- Normal validation is editor/headless/runtime inside the Godot project; do not add release export or packaged-build tests unless explicitly requested.
- Do not repeatedly rerun broad validation without an intervening change or new risk.
- After a meaningful integrated change, run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\reference_validation.ps1
```

- Update `IMPLEMENTATION_STATE.md` only after implementation and applicable evidence are green.
- Visual/manual claims remain open until direct visual/manual evidence exists.

## Definition of done for a slice

A slice is complete when the approved contract is implemented without adding undeclared mechanics, relevant deterministic tests pass, required visual/manual evidence exists, provenance is truthful where assets changed, and the appropriate regression gate remains green.
