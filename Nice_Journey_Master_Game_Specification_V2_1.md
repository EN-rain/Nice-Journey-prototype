# Nice Journey — Master Game Specification V2.1

> **Status:** Design consistency pass complete; implementation contracts specified; DR-01 through DR-08 resolved and approved in §58  
> **Working title:** `Nice Journey`  
> **Development model:** Solo developer; specification by Game Director; later implementation by GPT-5.6 Sol + specialist subagents  
> **Engine:** Godot 4.5+  
> **Prototype platform:** Windows x64  
> **Prototype scope:** Region 3 hub/overworld + first 10 tower floors  
> **Specification date:** 2026-09-14 (project local date)
> **Current phase:** Implementation active. This master remains the design authority while production code, scenes, tests and evidence are developed incrementally.
> **Handoff:** DR-01 through DR-08 are resolved as of 2026-09-14 by direct developer instruction; dependent implementation may proceed in milestone order with executable Dev→QA gates.

---

## Master Rule — No Silent Guessing

Agency Agents must not silently invent major game-design requirements.

Agents may decide minor implementation details only when all of the following are true:

- the decision is mechanically constrained by this specification;
- it does not materially change the player's experience;
- it does not create new story canon;
- it does not add a major system;
- it is logged in implementation notes.

For a missing consequential decision or conflicting approved requirements, record a numbered `DECISION REQUIRED` entry with the conflict, viable options, recommendation, affected work, and approval state. Continue all independent specification work. Only the implementation dependent on that unresolved choice remains blocked.

The previously approved V2 decisions remain approved. This V2.1 director pass adds constrained design contracts under the current task authorization; recommendations and playtest hypotheses are not retrospectively labeled developer-approved.

## Reading and status conventions

Sections 1–50 specify the game and system contracts. §52 indexes inherited decisions; §53 specializes floor progression; §54 records authority/history; §58 owns unresolved consequential choices; §59 defines the later production sequence; §§61–62 define cross-system acceptance and tuning controls.

Scope and authority are separate fields:

| Label | Meaning |
|---|---|
| `LOCKED` | Approved direction; change only through an approved change request. |
| `PROTOTYPE LOCKED` | Approved commitment for this prototype. Legacy “LOCKED FOR PROTOTYPE” wording has the same meaning. |
| `PROTOTYPE REQUIRED` | Work necessary to demonstrate the approved prototype; newly specified constrained contracts are required, but do not validate their tuning values. |
| `LONG-TERM APPROVED` | Approved direction outside first-prototype implementation. It is not a task to implement now. |
| `DEFERRED / OPTIONAL` | No first-prototype dependency may assume this work exists. |
| `[PLACEHOLDER — PLAYTEST]` / `[INITIAL TUNING HYPOTHESIS]` | Proposed starting content or tuning, unvalidated and changeable through recorded playtest evidence. |
| `TBD` | Intentionally unresolved detail; canon uses `TBD — DEVELOPER DECISION`. |
| `DECISION REQUIRED` | Material alternative needing developer choice. A recommendation is not approval. |

Working narrative names other than the established working title/planet name are marked `[PLACEHOLDER NAME — CAN CHANGE]`. Mechanical IDs are stable identifiers, not lore.

**Instruction authority for this pass:** current user task and direct developer instructions → explicitly approved master decisions → astra_guide.md → applicable project instructions → relevant Agency guidance → recommendations. Advisory demands for extra spreadsheets, middleware, new canon, or unrelated implementation do not expand this task. No Agency profile can waive the no-implementation boundary.

---

# 0. Agency Agents Operating Context

## 0.1 Studio roles

Recommended studio agents:

- Studio Producer
- Game Director
- Game Designer
- Technical Director
- Gameplay Engineer
- AI / Enemy Behavior Engineer
- Combat Designer
- Level Designer
- Narrative Designer
- Technical Artist
- Pixel Artist / Animation Specialist
- UI/UX Designer
- Audio Designer
- QA Lead
- Performance Engineer
- Build / Release Engineer

## 0.2 Quality loop

`SPEC → TASK → IMPLEMENT → BUILD → RUN → TEST → VISUAL CHECK → QA REVIEW → PASS / FAIL`

A failed QA review returns work to the responsible implementation agent.

## 0.3 Department boundaries

Specialist agents must not silently rewrite another department's approved requirements.

Examples:

- AI engineer cannot change combat rules to make AI easier to implement.
- Technical artist cannot change the pixel-art identity to simplify effects.
- Narrative agent cannot create permanent canon to solve a level-design problem.
- Gameplay engineer cannot introduce a hard level gate when this specification requires soft level requirements.

Status: `LOCKED`

---

# 1. Current Project Definition

## 1.1 Working title

**Nice Journey**

The title is temporary and may change later.

Status: `LOCKED FOR PROTOTYPE`

## 1.2 Genre

- top-down fantasy action RPG;
- tower-climbing structure;
- story- and quest-driven progression;
- real-time combat;
- character classes and skills;
- gear progression;
- variable quest objectives;
- procedural floor layouts built from validated authored room modules.

Approved quest families:

- Escort
- Tower Defense
- Annihilation

Additional quest families may be added later only after approval.

Status: `LOCKED AT HIGH LEVEL`

## 1.3 Player count

Prototype:

**Single-player**

Long-term:

**Multiplayer planned later**

Rules:

- no multiplayer implementation is required for the prototype;
- networking must not be added speculatively;
- gameplay state should be kept reasonably separable from presentation so future networking is not unnecessarily blocked;
- do not sacrifice prototype velocity for premature multiplayer architecture.

Status: `LOCKED`

## 1.4 Player fantasy

The player is an adventurer climbing a dangerous tower during a world-threatening crisis.

Core player activities:

- accept and complete quests;
- enter increasingly dangerous floors;
- fight highly capable enemies;
- level up;
- acquire and upgrade gear;
- develop class skills;
- defeat floor milestones and bosses;
- advance the larger tower progression.

Status: `LOCKED`

---

# 2. Core Design Pillars

Production pillars:

1. **Every fight demands attention.**
2. **Every floor provides meaningful progression.**
3. **Every quest changes what the player is being asked to do.**

Supporting pillars:

- quest-driven progression;
- character growth through levels, gear, and skills;
- intelligent enemy behavior;
- tower progression;
- player freedom to enter dangerous content while underleveled;
- compact, readable 16-bit pixel-art presentation.

Status: `LOCKED`

---

## 2.1 Experience and decision loop

| Scale | Player decision | Feedback and payoff | Failure to avoid |
|---|---|---|---|
| Moment to moment | Read enemy intent; choose spacing, defense, commitment, and target. | Legible windup, hit/defense result, recovery opportunity, resource change. | Winning by stat checks alone or losing to unreadable counters. |
| Encounter | Isolate a threat, interrupt support, protect an objective, or withdraw when legal. | Enemy behavior reacts to observable play; objective progress is visible. | Every enemy committing simultaneously; objectives hidden behind combat noise. |
| Expedition | Prepare class skills, gear, and consumables; accept a quest; choose an unlocked floor despite its warning. | Persistent quest/floor progress and meaningful character growth. | Grinding mandatory filler kills or unexplained access denial. |
| Region loop | Return through a valid route; use town services; pursue regional opportunities; attempt a harder floor. | Town service and map state remain dependable. | Rebuilding the overworld between visits or making all side content mandatory. |

No session-length or completion-time claim is validated. The first playable tests must establish whether preparation changes choices and whether attentive play can outperform a modest level deficit. The 2–3 week goal is a desired schedule, not evidence that the full locked content target is deliverable in that time.

## 2.2 Scope separation

| PROTOTYPE REQUIRED | LONG-TERM APPROVED | DEFERRED / OPTIONAL |
|---|---|---|
| Region 3, central town, 10 floors, three class choices, intelligent combat, quests, gear/skills, persistence, maps, required art/audio/UI | Multiplayer direction, wider Luminar, tower milestones above Floor 10, future character roster, controller support, cloud saves | Actual networking; Regions 1–2/4–12 content; advanced crafting; extra quest families; voice acting; platform integration; final release/monetization; optional floor vendors |

A milestone slice can contain fewer floors/archetypes for validation. It must not be reported as completion of the approved 10-floor, 12-archetype-plus-boss prototype.

---

# 3. Enemy Philosophy — Critical Rule

## 3.1 No filler mobs

The game must **not** contain intentionally weak, stupid, passive, or meaningless filler enemies.

Possible combat tiers:

- dangerous standard enemy;
- elite;
- mini-boss;
- boss.

Even the lowest combat tier must be capable of threatening a careless player.

Status: `LOCKED`

## 3.2 Intelligence target

Enemy behavior should use combinations of:

- positioning;
- spacing;
- pressure;
- prediction;
- punish windows;
- defensive choices;
- attack sequencing;
- coordination;
- contextual reactions;
- lightweight memory of recent player behavior;
- phase- or state-specific patterns.

Enemies should not exist only to:

- walk directly toward the player;
- attack on one fixed timer forever;
- repeat one action indefinitely;
- wait harmlessly to be killed;
- inflate kill counts.

Status: `LOCKED`

## 3.3 Fairness rule — intelligent, not cheating

Enemy intelligence must come from decision-making, not hidden input cheating.

Enemies may:

- observe player position;
- observe visible player animation/state;
- remember recent player actions;
- infer repeated dodge direction;
- react to healing/casting;
- reposition based on allies and terrain;
- vary authored timing;
- use explicit authored feints;
- punish repeated habits.

Enemies must not:

- read raw player button presses before the action becomes observable;
- react before a player action has visually or mechanically begun;
- ignore their own cooldown/action limits;
- instantly counter every valid player choice;
- cancel every committed telegraphed action with no authored rule;
- use impossible knowledge solely to create difficulty.

Reaction delay and telegraph readability must exist per enemy/attack design.

Status: `LOCKED`

---

# 4. Prototype Scope

## 4.1 Tower scope

Prototype target:

**10 floors**

Status: `LOCKED`

## 4.2 Development strategy

Phase 1:

**Prototype the core game.**

Phase 2:

**Expand only after combat, enemy AI, progression, quest flow, and procedural floor generation prove viable.**

Status: `LOCKED`

## 4.3 Team

**Solo developer using Agency Agents**

Status: `LOCKED`

## 4.4 Schedule

Desired prototype target:

**2–3 weeks, preferably earlier if quality permits.**

Schedule rule:

- cut nonessential content before reducing combat/AI quality;
- reusable systems are preferred over large amounts of one-off content;
- prototype completion means proving the systems, not shipping the final game.

Status: `LOCKED`

## 4.5 Prototype scope guardrail

Required for prototype:

- one protagonist;
- one chosen class per save;
- melee, ranged, and mage class paths available as prototype choices;
- side-only player sprite presentation;
- real-time combat;
- **Planet Luminar high-level world-map context with 12 regions;**
- **Region 3 as the only fully implemented prototype region;**
- **Region 3 main town/hub, surrounding explorable environment, and local region map;**
- **20 total built structures in the Region 3 town, including the central tower;**
- **main-story Tower Sigil access/teleport item;**
- 10 procedural tower floors;
- three approved quest families;
- enemy AI architecture;
- danger/soft-level system for tower floors and overworld danger zones;
- leveling;
- five equipment slots;
- inventory;
- loot;
- shops;
- gear upgrading;
- skill tree;
- save/load;
- hub;
- one Floor 10 boss;
- core UI/HUD;
- core audio/VFX;
- QA and performance validation.

Explicitly **not required** for first prototype:

- multiplayer;
- 100-floor implementation;
- multiple playable protagonists;
- voice acting;
- alchemy;
- cooking;
- full crafting system;
- modding;
- mobile/console ports;
- PvP;
- procedural story generation;
- full achievement/platform integration;
- playable implementation of Luminar Regions 1–2 or 4–12;
- paid monetization systems;
- final release storefront integration.

Status: `LOCKED`

---

# 5. Art Direction

## 5.1 General style

**16-bit-inspired pixel art**

Status: `LOCKED`

## 5.2 Character sprite size

Base character sprite target:

**32×32 pixels**

Status: `LOCKED FOR PROTOTYPE`

## 5.3 Rendering

**Raster pixel art**

Status: `LOCKED`

## 5.4 Anti-aliasing

Anti-aliasing is allowed only when it preserves pixel-art readability.

Rules:

- manually authored pixel AA is allowed;
- sprite texture filtering must use nearest-neighbor behavior;
- runtime sprite smoothing must not blur pixel boundaries;
- pixel sprites should not use accidental linear filtering;
- VFX/lighting may use smoother edges only when combat readability remains clear.

Status: `LOCKED`

## 5.5 Character outlines

**Yes**

Status: `LOCKED`

## 5.6 Palette

Use a controlled project palette appropriate for 16-bit-inspired pixel art.

Prototype rule:

- palette may expand for VFX/lighting;
- character identity colors must remain stable;
- agents must not introduce uncontrolled hue/noise variation between animation frames.

Exact master palette remains an art-production deliverable.

Status: `PARTIALLY LOCKED`

## 5.7 Lighting

Dynamic lighting:

**Yes**

Lighting must not destroy sprite readability or create frame-to-frame color instability.

Status: `LOCKED`

## 5.8 Character shadows

Character shadows:

**Yes**

Use a readable stylized ground/contact shadow rather than physically complex shadowing unless specifically required.

Status: `LOCKED`

---

# 6. Character Direction & Sprite Orientation

## 6.1 Player character direction

The player character uses **side-only body art**.

There is no required front-facing or back-facing player sprite set.

Implementation:

- author one right-facing side body set;
- mirror it horizontally for left-facing presentation;
- do not author separate front/back player body animations for the prototype;
- body facing is based primarily on horizontal aim direction;
- when the cursor is nearly vertical relative to the player, retain the most recent left/right body facing to prevent rapid flip jitter;
- use a small facing hysteresis/dead zone around the vertical axis.

Status: `LOCKED`

## 6.2 Weapon and attack direction

Weapons are rendered separately from the character body.

The weapon/attack layer may aim continuously toward the mouse cursor even while the body remains a side profile.

This allows:

- 360° free aim;
- side-only character animation production;
- independent projectile direction;
- weapon-specific attack arcs;
- lower sprite workload.

Status: `LOCKED`

---

# 7. Character Animation

## 7.1 Animation method

Primary prototype method:

**Frame-based pixel animation**

Skeletal animation is not required for the 32×32 player body during the prototype.

Transform animation may still be used for:

- weapons;
- projectiles;
- VFX;
- UI;
- selected secondary objects.

Status: `LOCKED FOR PROTOTYPE`

## 7.2 Frame budget

General frame budget:

**4–12 frames depending on the animation.**

Recommended ranges:

| Animation | Frame target |
|---|---:|
| Idle | 4–6 |
| Walk | 6–8 |
| Run | 6–8 |
| Attack | 4–8 |
| Heavy Attack | 6–10 |
| Dash | 4–6 |
| Dodge | 4–6 |
| Block | 2–4 + held pose |
| Parry | 4–6 |
| Cast | 6–10 |
| Hit | 3–5 |
| Death | 8–12 |
| Interact | 4–6 |
| Pickup | 4–6 |
| Use Item | 4–6 |
| Climb | 6–8 |
| Sleep | 4–6 |

These are production targets, not hard equality requirements.

Status: `LOCKED AT RANGE LEVEL`

## 7.3 Required animation list

- Idle
- Walk
- Run
- Attack
- Heavy Attack
- Dash
- Dodge
- Block
- Parry
- Cast
- Hit
- Death
- Interact
- Pickup
- Use Item
- Climb
- Sleep

Status: `LOCKED`

## 7.4 Animation priority

Recommended prototype priority:

`Death > Hit/Forced Reaction > Parry/Dodge > Block > Attack/Cast > Interact/Use > Run/Walk > Idle`

Individual skills may override this only through authored state rules.

Status: `LOCKED FOR PROTOTYPE`

## 7.5 Cancel and commitment model

Combat actions use:

`Startup → Commit → Active → Recovery`

Rules:

- startup may allow specifically authored cancels;
- commit phase normally cannot be cancelled;
- active attack frames normally cannot be freely cancelled;
- recovery may expose an authored cancel window;
- dodge/parry emergency cancels are allowed only where explicitly authored;
- input buffering stores the next valid action without automatically cancelling the current committed action.

Status: `LOCKED`

---

## 7.6 Action legality precedes visual priority

Animation priority chooses the presentation of an already valid gameplay state; it cannot authorize cancellation. Resolve death, authored forced interruption, voluntary cancellation eligibility, and normal completion before choosing the visible animation. Hit reactions interrupt only when the attack/poise contract allows them; a damage flash may acknowledge a hit without canceling a committed action.

The Heavy Attack animation supports an uncharged authored heavy action. Its existence does not introduce hold-to-charge behavior or an additional attack binding. Dash and Dodge are distinct actions and neither is a roll. Climb uses authored interaction links; Sleep belongs to rest-service presentation. All listed animations remain required, but can be produced after the first combat slice.

Body, weapon, attack geometry, and effects use a shared action timeline. Visual frames never independently award damage, consume resources, or decide whether a parry succeeded.

---

# 8. Asset Source Rules

Allowed prototype sources:

- AI-generated assets;
- CC0/Public Domain assets;
- free assets explicitly licensed for commercial game use;
- CC-BY assets when attribution requirements can be satisfied and logged.

Not allowed without explicit approval:

- non-commercial-only assets;
- assets with unclear ownership/licensing;
- paid marketplace packs;
- licenses whose redistribution obligations are not understood;
- assets whose terms prohibit intended commercial use.

Rules:

- provenance/source must be recorded;
- license must be recorded;
- AI generator/source must be recorded when practical;
- AI output must pass the same quality review as manually sourced art;
- low-quality generic AI appearance is not acceptable merely because the asset is technically usable.

AI-generated audio and writing are permitted for prototype work if their terms allow the intended use and they pass quality review.

Status: `LOCKED`

---

# 9. Playable Character & Class Structure

## 9.1 Prototype roster

**1 protagonist**

Status: `LOCKED`

## 9.2 Player name

At new game creation, the player enters the protagonist/save name.

That entered name is used as the protagonist name for the current progression/save profile.

Status: `LOCKED`

## 9.3 Classes

Prototype class choices:

- Melee
- Ranged
- Mage

The same protagonist body/sprite identity is used regardless of class.

Class affects:

- starting weapon;
- class resource behavior;
- active skills;
- passive skills;
- skill tree;
- preferred combat range;
- class-specific balance.

Prototype rule:

**The player chooses one class for a save. Class switching/respec is not required for the prototype.**

Status: `LOCKED FOR PROTOTYPE`

## 9.4 Future characters

Long-term game may include multiple playable characters.

Future switching/party systems remain TBD and are outside prototype scope.

Status: `LOCKED LONG-TERM INTENT`

---

# 10. Character Resources

## 10.1 Shared resources

All classes use:

- HP;
- Stamina.

Status: `LOCKED`

## 10.2 Class-dependent resource model

### Melee

- HP
- Stamina
- active skills use cooldowns and may consume stamina;
- no separate mana bar required.

### Ranged

- HP
- Stamina
- weapon attacks may use ammunition where appropriate;
- active skills use cooldowns and may use stamina/ammunition depending on the skill;
- no universal mana bar required.

### Mage

- HP
- Stamina
- Mana
- active magic skills use cooldowns and mana.

This resolves the earlier cooldown/resource contradiction: **resource cost depends on class and skill design.**

Status: `LOCKED FOR PROTOTYPE`

---

## 10.3 Resource contract — PROTOTYPE REQUIRED

HP reaching zero enters the death resolution flow. Stamina is the common mobility/defense resource for **all** classes, including Mage. Mana is additional for Mage. An ammunition display exists only when the equipped Ranged weapon actually uses ammunition.

Each action definition must identify eligibility, cost resource, cost amount, spending point, cooldown start, interruption/refund rule, and regeneration suppression. Insufficient resources reject the action before spawning an attack, with a short reason on the relevant HUD slot. Repeated/buffered inputs cannot spend twice.

Recommended first-pass transaction rule: reserve eligibility at startup, revalidate and spend once at commitment, and start cooldown at the same commitment. An interruption before commitment releases the reservation; after commitment it does not refund by default. This is a reversible contract refinement; skill exceptions must explicitly declare their spending/refund policy.

Resource values are clamped to valid bounds. Regeneration uses simulation time, stops while paused, and cannot exploit UI opening, render rate, equipment swapping, or repeated checkpoint loading. Max-resource changes do not grant repeated free refills. Recovery after death comes from the selected checkpoint policy, not from an unrelated class script.

**DR-04** owns the unresolved starter weapons, basic-attack resource costs, ranged ammunition model, and in-combat mana recovery. Until approved, no production encounter or economy assumes infinite arrows, consumable arrows, free spells, mana regeneration, or universal shield access. Each approved class must have an explicit depletion/recovery route that cannot make a required quest permanently unwinnable.

---

# 11. Movement

Movement target:

**Fast and responsive.**

Available actions:

- walk;
- run;
- dash;
- dodge;
- climb.

Excluded:

- crouch;
- jump;
- swim;
- roll.

## 11.1 Dash vs dodge

### Dash

Purpose:

- fast traversal;
- repositioning;
- closing/opening distance.

Dash should have longer movement than dodge and should not be the primary defensive invulnerability tool.

### Dodge

Purpose:

- short evasive movement;
- combat defense;
- contains authored invulnerability frames.

Status: `LOCKED`

## 11.2 Movement implementation rules

- normalize diagonal movement speed;
- avoid sluggish acceleration unless explicitly used for a special effect;
- collision response must not trap the player on simple corners;
- movement should remain responsive at target frame rate;
- dash/dodge consume stamina;
- exact speeds/distances are balance values stored in data, not hard-coded across gameplay scripts.

Status: `LOCKED AT SYSTEM LEVEL`

---

## 11.3 Movement state contract — PROTOTYPE REQUIRED

Input selects a normalized ground-plane direction. Walk/Run move through collision; Dash/Dodge run an authored movement curve and end in a valid ground position; Climb is entered only at a compatible interaction link and exits at a validated landing anchor. No diagonal bonus, collision bypass, falling, jumping, swimming, or player object-pushing is introduced.

Dash has no default invulnerability. Dodge's authored invulnerability interval applies only to damage tagged as dodgeable; it does not erase hazard/objective state. Movement restrictions during attacks/casts are explicit per action. Rooted or staggered states suppress only the inputs declared by the effect.

A blocked dash/dodge stops safely along its traversable segment, never through a wall or inside another footprint. Climb is not a universal teleport: escort-compatible quest paths cannot require links that the escort cannot traverse. The input buffer may retain a legal next action; it cannot queue unlimited movement bursts.

Speeds, displacement, invulnerability durations, and stamina costs are tuning variables. Acceptance requires equal displacement for cardinal/diagonal motion, reliable corner traversal, visibly distinct dash/dodge roles, and identical game-time timing at different render rates.

---

# 12. Player Collision / World Interaction

Player collision:

**Rectangle**

The collision should represent the lower body/ground footprint rather than the full visible sprite where appropriate for top-down movement.

Player pushing objects:

**No**

Falling off edges:

**No**

Environmental damage:

**Yes**

Prototype hazard examples may include:

- floor damage zones;
- timed hazard zones;
- environmental projectiles if explicitly part of a level mechanic.

Hazards require readable telegraphs.

Status: `LOCKED`

---

# 13. Controls

Prototype input:

**Keyboard + mouse**

Movement:

**WASD**

Aiming:

**Mouse free aim**

Click-to-move:

**No**

Lock-on:

**No**

Controller:

**Not required for prototype; future support planned.**

## 13.1 Input requirements

- controls are rebindable;
- hold/toggle alternatives are supported where relevant;
- attack/cast direction uses mouse aim;
- character body side-facing is separate from the exact 360° weapon/skill aim;
- input buffering is supported for combat;
- input buffering duration is a tunable data value;
- UI input and combat input must not fire simultaneously when a menu owns input focus.

Status: `LOCKED`

---

## 13.2 Input ownership and proposed binding pass

Action names are authoritative; these default keys are `[PLACEHOLDER — PLAYTEST]` and remain rebindable.

| Input | Action |
|---|---|
| WASD / mouse | Move / aim (approved) |
| Left mouse | Equipped basic attack |
| Right mouse | Supported block |
| F | Supported parry |
| Shift hold/toggle | Run |
| Space | Dodge |
| Left Ctrl | Dash |
| Q / R | Active slots 1 / 2 |
| E | Prioritized interaction; climb at a valid link |
| 1–4 | Consumable quick slots |
| I / K / J | Inventory/equipment / skills / quest log |
| M / T / Esc | Map layers / Tower Sigil menu / pause-back |

A kit lacking a supported block/parry shows that limitation rather than accepting a nonfunctional input. The approval of those capabilities belongs to DR-04. Map controls switch World, Region, and current Tower Floor views without changing travel eligibility.

A modal UI exclusively owns input. Opening/closing it clears obsolete attack-use intents, and the closing click cannot pass through into combat. Single-player pause freezes gameplay timers, AI, movement, quest timers, and combat; UI remains operable. Pausing does not convert an active encounter into an out-of-combat state or authorize saving/teleporting. Application focus loss pauses the prototype.

Input buffering retains one replaceable intended action with an expiry measured in gameplay time. Aim is sampled at the action's declared aim-lock point; tracking after that point is allowed only where authored.

---

# 14. Quest System — Core Feature

The game is explicitly **story- and quest-driven**.

Status: `LOCKED`

## 14.1 Approved quest types

- Escort
- Tower Defense
- Annihilation

Status: `LOCKED`

## 14.2 Prototype quest volume

Recommended/approved prototype target:

- **10 primary floor quests/objectives** — at least one main progression objective per floor;
- **5 optional side quests** distributed across the prototype;
- **15 authored quest definitions total** as the initial production target.

A floor may contain multiple quests.

Status: `LOCKED FOR PROTOTYPE`

## 14.3 Quest rules

- quests are required for primary floor progression;
- floors may contain multiple quests;
- side quests are allowed;
- quests can fail;
- failed quests can be retried;
- quests can change floor state;
- quests can have branching outcomes;
- timed quests are allowed;
- quests are handcrafted, not procedurally written;
- quest outcomes may affect future floors;
- branching is stored as deterministic quest/world flags;
- prototype branching does not require fully separate campaign routes.

Status: `LOCKED`

## 14.4 Escort rule

Escort NPCs are allowed and required by the approved Escort quest family.

Escort NPCs are:

- temporary quest actors;
- not permanent party companions;
- not required to be full combat-capable allies;
- allowed to have authored movement, panic, wait, follow, flee, or objective behavior.

Status: `LOCKED`

---

## 14.5 Quest state and objective contracts — PROTOTYPE REQUIRED

| State | Entry / permitted transition | Required effect |
|---|---|---|
| Unavailable | Prerequisites unmet; becomes Available when flags permit. | Explain known prerequisites without offering an invalid start. |
| Available | Player accepts authored quest. | Create one attempt ID; bind actors/objectives; enter Active. |
| Active | Objectives progress from authoritative gameplay events. | Display target, location, progress, timer/failure condition where relevant. |
| Suspended | Only if this quest explicitly supports a serializable pause. | Record actor/objective state and resume condition; not a universal free pause escape. |
| Failed / Abandoned | Declared failure event or confirmed player leave action. | Explain what failed, what persists, and the available retry. |
| Retry-ready | Failure recovery conditions satisfied. | New attempt ID; reset only declared attempt state under DR-01/02. |
| ObjectivesComplete | All required predicates met. | Allow declared turn-in or automatic completion; do not grant twice. |
| Completed | Completion transaction committed. | Grant reward, branch flag, floor clear/unlock changes atomically. |

A definition declares family, prerequisites, acceptance/turn-in anchors, required and optional objectives, instance bindings, leave rule, failure rule, retry/reset set, branch effects, rewards, and completion conditions. Talk, travel, delivery, and service interactions may be **steps** of an approved family; they do not silently create new quest families.

Permanent profile flags, floor-instance state, and quest-attempt state have separate ownership. A retry cannot erase a previously committed primary clear, Sigil ownership, or unrelated quest outcome. Completed content has an explicit replay/reward policy under DR-01. Progress uses stable objective and event IDs, so duplicate delivery of a kill/interaction event cannot duplicate progress.

| Family | Required setup and progress | Failure / important edge case |
|---|---|---|
| Annihilation | Bind designated enemy/group IDs; show remaining required threats; required actors must be reachable. | Optional inhabitants do not enter the count. Despawn/unload is not death. Summoned actors count only if explicitly part of the objective. |
| Escort | Bind NPC, route nodes, goal, wait/follow interaction, health/failure policy, and safe retry origin. | Separation normally invokes wait/repath feedback; it is not instant failure unless declared. Actor death or explicit condition may fail. Blocked navigation cannot silently teleport the NPC. |
| Tower Defense | Bind defended objective, health/failure state, admitted attacker groups/waves, and completion condition. | Spawn only through valid routes and budget admission. Wave completion counts its required actors, not every resident of the floor. No buildable-turret/crafting subsystem is implied by the name. |

Timed stages start at an explicit activation event after instructions are shown. Timers use game time and remain consistent through pause/save. A timed quest cannot require inaccessible rooms or unaffordable mandatory items.

Branching is bounded, deterministic, and reconvergent in the prototype: consequences can alter dialogue, a later encounter condition, or an optional objective, but cannot accidentally remove every path to required floor progression. Narrative consequences remain TBD where they imply new canon.

## 14.6 Quest production allocation

The approved target remains 10 primary floor objectives and 5 side quests. **DR-03** resolves whether Region 3 main-story stages are included inside those 15 definitions or require a separately counted prelude. Do not silently increase the approved count.

For greybox coverage, use three regional side-quest slots and two tower side-quest slots as a `[PLACEHOLDER — PLAYTEST]` allocation. Their mechanical proposals are listed in §24.12; exact narrative text and any unapproved stakes remain `TBD — DEVELOPER DECISION`.

A temporary combat skill replaces an existing active slot and restores its prior assignment on every exit path **only if the DR-05 recommendation is approved**. Do not implement a hidden third combat slot. Noncombat quest interactions can use the universal interact action without altering the combat loadout.

---

# 15. Tower Structure

## 15.1 Prototype floors

**10 floors**

Each floor is one generated level composed of multiple rooms/areas.

Status: `LOCKED`

## 15.2 Floor dimensions

Prototype generation footprint:

**up to 50×50 logical world tiles per floor**

Prototype tile basis:

**32×32 source pixels per world tile**

A floor may use room modules that occupy multiple logical tiles.

Status: `LOCKED FOR PROTOTYPE`

## 15.3 Floor themes

Prototype visual theme pool:

- Stone Citadel
- Overgrown Ruins
- Arcane Vault

The procedural generator may select among the theme pool while avoiding excessive immediate repetition.

Floor 10 uses a dedicated **Boss Sanctum** presentation.

These are visual/environment themes and do not establish deeper story canon by themselves.

Status: `LOCKED FOR PROTOTYPE ART DIRECTION`

## 15.4 Floor layout generation

Floor layouts are **procedural**, but constructed from authored, validated room modules.

Generator requirements:

- deterministic seed support;
- guaranteed connected critical path;
- quest-objective reservation before optional-room placement;
- guaranteed valid spawn positions;
- guaranteed reachable exit;
- no quest objective behind an impossible dependency;
- safe handling of escort pathing;
- boss floors use validated boss-room templates;
- generator output must pass automated structural validation.

Status: `LOCKED`

## 15.5 Floor features

Prototype supports:

- multiple rooms;
- checkpoints;
- stairs/elevator/portal-style transitions as presentation permits;
- optional encounters;
- secret rooms at low frequency;
- safe/rest rooms where generated;
- shops through designated vendor/safe rooms or hub access;
- floor-specific hazards;
- floor modifiers when explicitly authored.

Floor replay is allowed after a floor has been unlocked.

Status: `LOCKED AT SYSTEM LEVEL`

## 15.6 Tower access quest item — Tower Sigil

The player earns a permanent main-story quest item that enables free tower access.

Working item name: **Tower Sigil [PLACEHOLDER NAME — CAN CHANGE]**. The name may change later without changing the system.

Rules:

- acquired through the Region 3 main story;
- permanent once obtained;
- cannot be dropped, sold, destroyed, or lost;
- does not occupy a normal inventory slot;
- can be used from anywhere **outside active combat**;
- physical entry through the central tower remains available;
- opens the **Tower Access Menu** rather than instantly teleporting;
- does not bypass story/quest floor unlock requirements.

Tower Access Menu entries show:

- every cleared floor;
- every currently unlocked but uncleared floor the player may attempt;
- Recommended Level;
- current Danger rank;
- clear/incomplete state;
- active quest indicators;
- boss/elite warning when applicable.

Teleport rules:

- cleared floors may be revisited directly through a validated entry/checkpoint target;
- an unlocked uncleared floor may be entered at its approved floor-entry point;
- locked floors cannot be selected;
- teleport is blocked during active combat;
- if a non-portable quest state is active (for example, an escort actor is following the player), the menu must warn the player and apply that quest's authored leave/abandon/pause rule before teleporting;
- arrival must never place the player inside an active attack, blocked tile, invalid generated room, or unresolved boss phase.

Status: `LOCKED`

---

## 15.7 Floor state, clear, unlock, and arrival

A floor has separate discovered/unlocked, current-instance, primary-clear, and active-quest state. Reaching a Recommended Level never changes unlock eligibility. Floor 1's initial eligibility and any Region 3 prerequisite remain subject to DR-03. Sigil acquisition does not independently establish a prerequisite for physical tower entry.

Completing the required primary objective and its declared turn-in commits the floor-clear flag and unlocks the next prototype floor. Optional quests and incidental survivors do not block this unless explicitly listed as required primary objectives. Floor 10 clears the prototype milestone; it does not generate Floor 11, grant the final wish, end the world crisis, or establish the campaign ending.

Every floor provides a validated entrance/exit and a reachable authored return route through accessible tower passages to the tower's ground-level town exit. A direct town-return facility on every floor is not added. The Sigil menu lists eligible **floors**; it does not invent an additional anywhere-to-town teleport destination. Physical traversal follows its declared encounter-continuity and quest-leave rules; the Sigil prohibition does not by itself add a combat lock to ordinary walking passage. A reached checkpoint may become a cleared-floor arrival target only if it remains safe and valid in the saved instance.

**DR-01** owns repeat-visit/reset/reward semantics. Geometry is never regenerated merely because a menu is opened or a scene is loaded. Any approved reset operation must be explicit and preserve required permanent progression.

## 15.8 Tower travel transaction — PROTOTYPE REQUIRED

1. Request physical entry/passage, Sigil access, or floor selection. Check ownership where relevant, destination unlock, and source quest leave rules. Teleport requests require the shared out-of-combat guard. Ordinary physical traversal follows its authored passage/encounter-continuity rules and is not automatically blocked by the Sigil restriction.
2. Present destination, clear state, Recommended Level, Danger, required warnings, and the exact consequence for an active non-portable quest.
3. Player cancels without state changes, or confirms the requested transition. DANGER III–V confirmation is a warning, never a level gate.
4. Prepare/validate the destination instance and arrival anchor without destroying the source state. Recheck eligibility at commit; a stale teleport menu cannot bypass newly active combat, and no transition can bypass changed quest state or an invalid target.
5. Apply the quest leave rule and transfer as one transaction. Commit arrival/checkpoint/save changes only once the destination is valid. On failure, retain the source instance and progression and give a recoverable reason.

Quest leave behavior is data-bound to `block with reason`, `confirm abandon/fail`, or `serialize and suspend`; there is no implicit universal escort teleport. If a rule would make a mandatory quest impossible to retry, its definition fails validation.

Safe arrival includes a clear ground footprint, reachable egress, no intersecting active attacks/hazards, and separation from unresolved boss combat. An invalid remembered checkpoint falls back to the valid floor entrance with notification; it does not move the player into arbitrary geometry.

---

# 16. Danger System & Soft Level Requirements

## 16.1 Core rule

Every floor has a **Soft Level Requirement**, presented to the player as a **Recommended Level**.

The player may still enter an unlocked floor while below the recommendation.

**Level does not hard-lock entry.**

Story/quest progression may still determine whether a floor is discovered/unlocked.

Status: `LOCKED`

## 16.2 Prototype recommended levels

| Floor | Recommended Level | Maximum Floor Population Budget | Elite Target | Boss |
|---:|---:|---:|---:|---:|
| 1 | 1 | 10 | 0 | No |
| 2 | 2 | 20 | 0 | No |
| 3 | 3 | 30 | 0 | No |
| 4 | 4 | 40 | 0 | No |
| 5 | 5 | 50 | 3 | No |
| 6 | 6 | 60 | 0 | No |
| 7 | 7 | 70 | 0 | No |
| 8 | 8 | 80 | 0 | No |
| 9 | 9 | 90 | 0 | No |
| 10 | 10 | 100 | 3 | Yes — 1 boss |

**Population budget means the maximum population available across the whole generated floor, not enemies simultaneously active on screen.**

Not every quest requires killing every floor inhabitant.

Status: `LOCKED FOR PROTOTYPE`

## 16.3 Danger rating

Prototype danger rating compares player level to the floor recommendation.

| Level relationship | Danger display |
|---|---|
| Player at/above recommendation | DANGER I — Dangerous |
| 1 level below | DANGER II — Severe |
| 2 levels below | DANGER III — Extreme |
| 3–4 levels below | DANGER IV — Lethal |
| 5+ levels below | DANGER V — Catastrophic |

Rules:

- even DANGER I is not intended to mean easy;
- entering underleveled content is always permitted once the floor is unlocked;
- the system must show the warning before entry;
- there is no hidden debuff simply because the player is underleveled;
- difficulty comes from the floor's native enemy stats, AI, compositions, hazards, and boss rules;
- boss/elite-heavy quests may display an additional encounter warning without changing the floor's base Recommended Level.

Status: `LOCKED`

## 16.4 Danger UI

Display at minimum:

- current player level;
- recommended floor level;
- danger rank;
- boss/elite warning when applicable;
- confirmation prompt for DANGER III–V entry.

The player must still be allowed to continue.

Status: `LOCKED`

## 16.5 Region 3 danger zones

Region 3 uses the same **soft-requirement philosophy** as tower floors. The overworld is divided into authored subzones, each with its own Recommended Level.

Rules:

- the town core is a **SAFE ZONE** while hostile events are inactive;
- hostile overworld subzones display Recommended Level + DANGER I–V using the same level-deficit table as tower floors;
- the player may enter an unlocked overworld subzone while underleveled;
- no artificial underlevel debuff is applied;
- difficulty comes from actual enemy composition, hazards, quest state, and encounter design;
- World Map/Region Map markers must communicate danger before travel;
- temporary quest encounters may add an encounter-specific warning.

Recommended initial Region 3 greybox bands:

| Area type | Recommended Level | Purpose |
|---|---:|---|
| Central Town | Safe | services, story, preparation |
| Near Outskirts | 1–2 | onboarding and early quests |
| Main Roads / Fields | 2–4 | roaming quests and resource routes |
| Remote / Ruined Zones | 4–7 | harder regional quests |
| High-Risk Quest Pockets | 8–10 | optional late-prototype challenges |

These are tuning targets, not lore. Exact borders may change after traversal/combat playtests.

Status: `LOCKED SYSTEM / TUNING SUBJECT TO PLAYTEST`

---

## 16.6 Exact evaluation and presentation contract

For hostile content, let deficit = max(0, Recommended Level − Player Level). Use exactly the §16.3 mapping: 0 → I, 1 → II, 2 → III, 3–4 → IV, 5 or more → V. Gear, player skill, native enemy stats, quest modifiers, and boss presence do not silently change this locked ordinal. They affect actual risk and appear as separate content warnings.

Label the relationship clearly: **“Danger warning based on your level; equipment, enemies and hazards also affect risk.”** DANGER I never means harmless. Town safety is a separate zone state, not “Danger 0.”

Before floor entry, show player level, destination Recommended Level, Danger name/rank, main objective, known special hazards, and boss/elite warnings. Unknown specifics remain “Unknown” where appropriate; do not expose undiscovered secret-room contents. Recompute when level/destination/state changes and at travel commit.

Region map and boundary signage show the same data before crossing. Continuous overworld movement uses a nonmodal boundary warning; it is not interrupted by a confirmation on every step. Explicit menu-based travel into DANGER III–V uses the required confirmation. Story locks explain their quest reason independently from the level warning.

Acceptance: identical floor content has identical native stats for two differently leveled visitors, aside from legitimate player/build differences. Deficit boundary cases 0, 1, 2, 3, 4, and 5 display the prescribed rank and allow every story-unlocked entry.

---

# 17. Combat System

## 17.1 Core combat

- real-time combat: **Yes**
- melee: **Yes**
- ranged: **Yes**
- magic: **Yes**
- multiple weapon types long-term: **Yes**
- prototype starter weapon set: at least one supported weapon path per class
- formal combo-chain system: **Not required for prototype**
- short authored attack sequences are allowed without becoming a full combo system
- charged attacks: **No**
- active skills: **Yes**
- passive skills: **Yes**
- ultimates: **No**
- perfect-block subsystem: **No**
- perfect-parry subsystem: **No**
- block: **Yes**
- parry: **Yes**
- stagger/poise: **Yes**
- knockback: **Yes**
- critical hits: **Yes**
- weak points: **Yes**
- elemental damage system: **No**
- status effects: **Yes**
- damage types: **Yes, kept simple for prototype**
- armor: **Yes**
- shield: **Yes**
- lock-on: **No**
- free aiming: **Yes**
- enemy health bars: **Yes**
- damage numbers: **Yes**
- future multiplayer friendly fire: **No by default**
- boss phases: **Yes**
- cancel windows: **Yes**
- hit-stop: **Yes**
- input buffering: **Yes**
- attack commitment: **Yes**
- authored animation canceling: **Yes**

Status: `LOCKED`

## 17.2 Prototype damage categories

Keep the first implementation simple:

- Physical
- Arcane

Weapons/skills may carry tags such as melee, projectile, weak-point-capable, shield-breaking, or status-applying without creating a large elemental matrix.

Status: `LOCKED FOR PROTOTYPE`

## 17.3 Defensive action rules

Block:

- sustained defensive state where supported;
- consumes stamina when absorbing pressure/damage;
- can be broken by stamina depletion or specific attacks.

Parry:

- timing-based defensive action;
- has one authored success window;
- there is no separate "perfect parry" tier in the prototype.

Dodge:

- short movement;
- contains authored invulnerability frames.

Dash:

- longer repositioning action;
- should not duplicate dodge's defensive role.

Status: `LOCKED`

---

## 17.4 Combat action contract — PROTOTYPE REQUIRED

Every attack, skill, defense, and interrupting item use declares: action ID; eligible states; movement/aim rules; Startup/Commit/Active/Recovery timing; cost transaction; cooldown; attack shape; target mask; damage category/tags; hit count; poise/knockback effects; permitted cancels; forced-interruption rules; and required cues. Data validates that attack and feedback windows agree.

A successful hit is resolved once per permitted action-target hit interval. Collision/hit queries operate on authoritative gameplay positions, not camera-snapped sprite locations. Fast projectiles need continuous/swept collision or an equivalent validated solution; lowering render FPS must not let them tunnel through thin blockers.

Damage resolution order is explicit and shared by player/enemy attacks: valid target/contact → applicable invulnerability → block/parry result → approved mitigation/crit/weak-point calculation → HP/poise/status/knockback changes → death/objective events → feedback. No reward/UI script independently awards a second hit. Random combat outcomes use the encounter's reproducible gameplay random stream.

Equipment/skill definitions must specify block coverage, blockable/parryable tags, chip damage, stamina drain, break reaction, status eligibility, poise thresholds/recovery, weak-point geometry/exposure, and critical-hit interaction. **DR-06** owns the recommended shared first-pass semantics; these labels are not enough to infer a complete damage model.

Successful parry has one success tier and recognizable feedback. A failed parry has an authored recovery window. Unblockable/unparryable or dodge-ignoring attacks require consistent warning cues. Defensive enemy moves follow the same commitment/action-budget principles without requiring visible enemy stamina bars.

Hit-stop is a bounded presentation/game-time effect with explicit participants and pause-clock behavior. It cannot extend only the player's advantage, consume buffers while action time is frozen, or change projectile damage rate. Its amount is a tuning hypothesis.

Required outcomes: responsive legal actions; clear rejection/cooldown feedback; predictable commitment; readable stagger/knockback; meaningful class depletion management; no animation-only damage; and no infinite block/parry/dodge chain.

---

# 18. Character Skills

Each class equips:

- **2 active skills**
- **2 passive skills**

Systems:

- skill tree: **Yes**
- active slots: **2**
- passive slots: **2**
- cooldowns: **Yes**
- resource costs: **Class/skill dependent**
- skill upgrades: **Yes**
- skill levels: **Yes**
- skill unlocks: **Yes**
- quest-specific temporary skills: **Yes**
- class system: **Yes**
- character/class skill identity: **Yes**
- respec: **No for prototype**
- saved build loadouts: **No for prototype**

## 18.1 Resource behavior by class

- Melee: cooldown + stamina where appropriate
- Ranged: cooldown + stamina/ammunition where appropriate
- Mage: cooldown + mana

Status: `LOCKED`

---

## 18.2 Skill progression contract

Separate learned skills, spent progression, equipped active/passive IDs, and temporary overrides. Exactly two active and two passive combat slots are supported; empty slots are represented honestly. A grant or upgrade has a unique progression transaction ID and cannot be repeated through dialogue reload.

A tree node declares class, prerequisites, cost, maximum rank, resulting change, and incompatibilities. The UI previews effects and prerequisites before irreversible spending. No respec means purchased ranks/choices cannot be refunded by ordinary slot changes; whether learned skills may be swapped at safe locations is a separate DR-05 choice.

Persistent state includes class, unlocks, node ranks, unspent points, equipped IDs, and any serializable temporary override with its restoration record. A missing/invalid skill ID on load invokes a visible compatibility failure or explicit migration, not a random replacement.

**DR-05** resolves starting coverage, selection-pool size, concrete skill effects, upgrade paths, swap rules, and temporary-skill delivery. Skill names remain `[PLACEHOLDER NAME — CAN CHANGE]` until approved. Do not disguise an invented class kit as a routine tuning value.

---

# 19. Leveling & Progression

## 19.1 Prototype level cap

**Level 10**

Status: `LOCKED`

## 19.2 XP sources

Primary:

- main quests;
- side quests;
- boss completion.

Secondary:

- combat encounters;
- elites;
- exploration objectives when explicitly authored.

Normal enemies do not respawn. No farming loop is assumed. Cleared-floor replay and failed-attempt restoration must follow the explicit policy selected in DR-01; “replay” alone does not authorize renewable rewards or enemy respawning.

Status: `LOCKED`

## 19.3 Stat growth

Prototype rule:

- base stats grow automatically with level;
- player receives skill-tree progression through level/quest progression;
- manual allocation of core STR/DEX/etc. points is not required for the prototype.

Status: `LOCKED FOR PROTOTYPE`

## 19.4 Floor access

- floors have recommended levels, not hard level gates;
- a lower-level player may enter an unlocked high-level floor;
- underleveled entry triggers Danger warnings;
- player power is earned through level, gear, upgrades, skills, and player execution.

Status: `LOCKED`

---

## 19.5 Progression and finite-content solvability

Maintain one level-threshold table, automatic stat-growth table, and skill-point/grant schedule through Level 10. Level-up commits new level, permitted stat growth, and progression grants together; it does not automatically clear quests, unlock floors, or refill resources unless an approved rule says so.

XP sources have stable claim IDs. Boss kill XP and boss quest rewards are separately declared so their combined award is intentional. Annihilation counters, combat XP, and primary rewards are not independently reissued when a room reloads.

**[INITIAL TUNING HYPOTHESIS]** for the first balance worksheet within implementation data: XP required for level L→L+1 = 100×L, for L=1…9 (4,500 total to Level 10). Treat this as a transparent starting curve, not validated pacing. Allocate enough guaranteed required-encounter/main-quest XP to support the intended route; optional quests can bring the player to the cap earlier. Do not rely on every optional floor inhabitant being killed or on repeat farming.

Validate three trajectories: main route with minimal optional combat, optional regional/tower quest completion, and skilled underleveled advancement. Report level/gear/resource state at each floor entry. Reaching Floor 10 below Level 10 is permitted; proving the progression system reaches Level 10 through the finite authored content is still required.

Skill-point quantities, stat increases, quest XP, enemy XP and cap overflow behavior are tuning data. Once capped, extra XP cannot create Level 11; no unapproved prestige conversion is introduced. If the finite route becomes impossible after poor loot or spending choices, adjust approved rewards/costs/content rather than secretly spawning a farm.

---

# 20. Gear & Equipment

## 20.1 Equipment slots

Prototype uses **5 equipment slots**:

1. Weapon
2. Armor
3. Off-hand
4. Accessory 1
5. Accessory 2

Status: `LOCKED`

## 20.2 Gear rarity

- Common
- Rare
- Epic
- Legendary

Status: `LOCKED`

## 20.3 Random stat model

Gear uses random stats/affixes within controlled item-specific pools.

Prototype affix target:

| Rarity | Random affix target |
|---|---:|
| Common | 0 |
| Rare | 1 |
| Epic | 2 |
| Legendary | 3 |

Balance values and exact affix pools are data-driven.

Status: `LOCKED FOR PROTOTYPE`

## 20.4 Visual rule

- weapon is visually rendered separately;
- clothing remains fixed to the protagonist sprite;
- armor/accessories/off-hand do not require full character visual swaps;
- off-hand may render only when needed for combat readability, e.g. shield/focus.

Status: `LOCKED`

## 20.5 Gear upgrading

Gear upgrading is available through the blacksmith/upgrader system.

No item durability system is required.

Status: `LOCKED FOR PROTOTYPE`

---

## 20.6 Item and equipment contract

Every item instance stores definition ID, unique instance ID, realized rarity/affixes, upgrade rank and provenance/source claim. Save/load, storage moves, selling or equipping cannot reroll affixes. Validate affix applicability and exclusions; do not roll irrelevant ammo affixes on a weapon that has no ammunition resource.

Keep the approved 0/1/2/3 affix targets by rarity. Rarity is not a minimum-level gate. Equipment compatibility is explicit by slot/class/weapon capability; do not add equip-level restrictions simply because content has Recommended Levels.

Equipping an item atomically replaces the prior occupant and moves it to valid inventory/storage disposition. If no valid destination exists, reject before changing stats. Two accessories remain two actual slots; allowed duplicate/unique restrictions are declared by the item definition.

Armor/defense and upgrade parameters must be inspectable in the tooltip. Max-HP/resource changes clamp current state without repeated equip-refill exploits. Stat recalculation uses actual equipment once; sprites/UI do not contribute a second copy of an effect.

A shield in Off-hand may be visible during its action for readability while clothing remains fixed. A two-handed path must explicitly declare off-hand compatibility; that choice is part of the starter-kit/content approval in DR-04.

---

# 21. Enemy System

## 21.1 Prototype archetype recommendation

Use **12 reusable enemy archetypes + 1 prototype boss** across the first 10 floors.

Suggested mechanical archetypes:

1. Duelist
2. Bruiser
3. Defender
4. Skirmisher
5. Assassin
6. Marksman
7. Mobile Ranged
8. Caster
9. Support
10. Summoner
11. Flying Harrier
12. Controller/Disruptor
13. Floor 10 Boss

These are mechanical roles, not final lore names.

Variants may change:

- weapon;
- attack pattern;
- timing;
- stats;
- skill loadout;
- visual treatment;
- elite modifiers.

Do not create 100 completely unique enemy AIs merely because Floor 10 has a population budget of 100.

Status: `LOCKED FOR PROTOTYPE CONTENT TARGET`

## 21.2 Elites and bosses

- Floor 5: 3 elite targets across the floor population
- Floor 10: 3 elite targets + 1 boss
- boss every 10 floors in the long-term structure
- prototype implements only the Floor 10 boss

Long-term concept:

- Floor 10: 1 boss encounter
- Floor 20 milestone may contain 2 boss-level opponents/phases
- progression can escalate toward multi-boss milestone encounters
- exact Floor 100 ten-boss implementation is a long-term design target and must be validated before production, not implemented in the prototype.

Status: `LOCKED FOR PROTOTYPE / LONG-TERM ESCALATION INTENT`

## 21.3 Enemy abilities

Enemies may:

- coordinate;
- flank;
- bait attacks;
- retreat;
- guard allies;
- use terrain;
- react to repeated player behavior;
- interrupt healing/casting where authored;
- adapt patterns during the same fight;
- block;
- parry;
- dodge;
- use authored cancels;
- feint;
- vary attack timing;
- transition phases;
- use ranged attacks;
- cast spells;
- support allies;
- summon;
- fly.

Not required:

- enemy stamina bars;
- trap enemies;
- environmental attackers;
- enemy-vs-enemy faction combat;
- normal respawning.

Status: `LOCKED`

## 21.4 Enemy action-budget rule

Enemies do not require a visible stamina system, but they must have internal limits:

- cooldowns;
- action locks;
- recovery windows;
- utility-score suppression after repeated use;
- anti-spam rules for dodge/parry/block/feint.

This prevents infinite defensive spam while preserving the decision to avoid enemy stamina bars.

Status: `LOCKED`

---

# 22. Enemy AI Architecture

Prototype architecture:

**Hierarchical State Machine + Utility AI + Authored Pattern Controller + Lightweight Memory + Encounter Blackboard**

Status: `LOCKED`

## 22.1 Tactical state layer

Possible states:

- Observe
- Pursue
- Disengage
- Reposition
- Defend
- Pressure
- Attack
- Punish
- Recover
- Objective
- Support

## 22.2 Utility evaluation

Utility scoring may evaluate:

- distance;
- line of sight;
- player current action;
- player recent action history;
- player resource state when legitimately observable/inferred;
- enemy cooldowns;
- terrain;
- ally positions;
- encounter objective;
- recent failed/successful tactics;
- repeated player habits.

## 22.3 Pattern controller

Controls:

- attack sequences;
- timing variation;
- mix-ups;
- authored feints;
- punish windows;
- boss phases;
- recovery rules.

## 22.4 Memory

Prototype memory may track a limited recent window of:

- dodge directions;
- repeated attacks;
- healing/casting frequency;
- preferred range;
- block/parry habit;
- repeated escape direction.

Memory must decay/reset according to encounter design and must not become hidden omniscient tracking.

## 22.5 Encounter blackboard

Group coordination uses shared encounter facts such as:

- number of attackers currently committed;
- flank occupancy;
- support target;
- pressure role;
- ranged line-of-fire conflicts;
- objective state.

This prevents every enemy from choosing the same action simultaneously.

## 22.6 No machine learning requirement

Do not use machine learning, model inference, or expensive adaptive training for runtime enemy AI unless explicitly approved later.

Status: `LOCKED`

---

## 22.7 Responsibility and fairness contract — PROTOTYPE REQUIRED

| Layer | Owns | Must not do |
|---|---|---|
| Perception | Cue type, source, observed position/state, observation timestamp, confidence, expiry. | Publish raw input or unjustified exact hidden HP/resources/cooldowns. |
| Hierarchical state machine | Life/encounter/tactical states, legal transitions, action eligibility. | Allow utility or animation priority to bypass commitment. |
| Utility selection | Rank currently eligible tactics; expose chosen score and reason. | Execute illegal actions or replace the pattern mid-commit without an authored interrupt. |
| Pattern controller | Action phases, aim lock, feint branch, recovery, boss phase patterns. | Retarget or cancel outside declared readable windows. |
| Lightweight memory | Bounded recent observations and habit estimates; decay/reset. | Track an unseen player's live position or turn prediction into certainty. |
| Encounter blackboard | Observed shared facts, role/attack reservations, objective coordination. | Share omniscient facts or create uncounted attacks. |

Root lifecycle distinguishes Dormant, Active, Defeated, and Returning/Resolved encounter states; tactical states operate only where eligible. A dead actor cannot hold a flank or attack reservation. Utility changes do not resurrect an actor or reset its cooldown.

A reactive decision must satisfy `eligible reaction time >= observation time + authored reaction delay`. After losing line of sight/another justified sensing cue, the enemy uses last-known facts with age/confidence, rather than following invisible live movement. Shared facts retain their observation age and uncertainty. If an attack predicts movement, its aim-lock/retarget limit must be specified and visible.

Decision frequency and reaction latency are distinct: throttling utility evaluation may delay a response, never make it occur before the minimum cue delay. Memory holds a bounded window, decays, and resets with the approved encounter reset policy. No runtime machine learning is required.

Attack reservations are admitted atomically before commitment, and released on completion, cancellation, interruption, death, target invalidation, or encounter exit. Authored feints count against action/cooldown and pressure budgets; they cannot endlessly postpone every punish window.

Every archetype needs a threat card: preferred range; observable triggers; signature commitment; recovery opportunity; defensive limits; weakness/counterplay; group role; objective behavior; and allowed difficulty variants. The 12 approved archetype names remain mechanical roles. Summoners require bounded, budgeted reinforcements; flying enemies still need visible targeting/hit rules and cannot evade all three starter classes indefinitely.

---

# 23. Enemy Concurrency & Simulation


The floor population budget is not the full active simulation count. Per-floor targets in §53 take precedence over general typical-encounter ranges here; the combined hard active-AI cap remains 12.

Prototype target:

- normal full-simulation enemies in one active encounter: **6–8**;
- late-floor normal encounter target: **8–10**;
- exceptional hard cap: **12** full-AI combatants at once;
- enemies outside the active room/encounter use reduced simulation or dormancy;
- boss adds must still respect the active-AI budget unless the encounter is explicitly profiled and approved.

The goal is to preserve intelligent combat rather than degrade into unreadable crowd spam.

Status: `LOCKED FOR PROTOTYPE PERFORMANCE/DESIGN`

---

## 23.1 Active combat and encounter boundaries — PROTOTYPE REQUIRED

“Active combat” is a shared gameplay state used by travel, saving, services, quests, and music. It remains active while a hostile encounter is engaged, the player/quest actor is under an unresolved attack threat, an encounter objective is actively contested, or a boss phase/committed attack is unresolved. A short authored grace period may prevent boundary flicker; its duration is `[INITIAL TUNING HYPOTHESIS]`.

Distance or loss of sight alone does not instantly clear combat. Disengagement requires a validated end condition, no pending relevant damaging attacks, and resolution of objective/pursuit state. A quiescent environmental hazard zone does not make every floor permanently “in combat”; active exposure/pending damage and arrival safety are checked separately.

The 12 full-AI cap applies across simultaneous overlapping encounters, including bosses, elites, summons, adds, and pursuers. Per-floor encounter targets in §53 specialize the general §23 targets. A dormant/reduced-simulation actor cannot attack an engaged player as an uncounted combatant.

Population budgets include elites and the boss; authored reinforcements and summons are charged to the floor's finite encounter allocation. The cap is a maximum, never a kill quota. Retry/restoration accounting belongs to DR-01/02.

An authored admission schedule must preserve the active cap without freezing a visibly engaged enemy into a helpless target. Prefer preventable encounter overlap, bounded reinforcements, and visible delayed entry. If content cannot admit its required attackers fairly, validation fails instead of silently dropping required actors.

Concurrency is separate from pressure: simultaneous committed attacks, projectile lanes, disabling effects, and hazards also require a readable budget. These limits are playtest variables; a cap of 12 actors does not approve 12 simultaneous strikes.

---

# 24. World / Level Structure

## 24.1 Planet — Luminar

The game takes place on the planet **Luminar**.

`Luminar` is a working name and may be changed later through the Change Request Log.

Luminar contains **12 world regions**. A region number is geographic/organizational only; it does **not** define class, faction, biome, difficulty, or story role by itself.

Prototype implementation focuses **only on Region 3**. The other 11 regions may appear on the World Map as locked/future locations, but their gameplay content is out of prototype scope.

Status: `LOCKED HIGH LEVEL / NAME CHANGE ALLOWED LATER`

## 24.2 Placeholder region names

All names in this table: **[PLACEHOLDER NAME — CAN CHANGE]**. Preserve numeric region IDs.

These names are development placeholders and may be replaced later without changing region IDs:

| Region | Placeholder name | Prototype state |
|---:|---|---|
| 1 | Asterreach | Future / locked |
| 2 | Velmora | Future / locked |
| 3 | **Solmere** | **Prototype starting region** |
| 4 | Caelwyn | Future / locked |
| 5 | Duskharbor | Future / locked |
| 6 | Myrden | Future / locked |
| 7 | Orellis | Future / locked |
| 8 | Thornvale | Future / locked |
| 9 | Nareth | Future / locked |
| 10 | Evershade | Future / locked |
| 11 | Caldris | Future / locked |
| 12 | Vaelora | Future / locked |

Do not create detailed lore, quests, architecture, enemies, or implementation work for Regions 1–2 or 4–12 during the prototype.

Status: `PLACEHOLDER NAMES APPROVED FOR DEVELOPMENT`

## 24.3 Region 3 — prototype overworld

Region 3 is the player's **starting region** and the only fully playable world region required for the first prototype.

Region 3 includes:

- a central town/hub;
- surrounding explorable environment;
- roads and quest routes;
- hostile overworld subzones;
- quest-specific locations;
- a central tower integrated into the town;
- a local Region Map;
- links to the separate World Map UI.

The region should feel wide enough for exploration and regional quests, but it is a **bounded authored prototype region**, not an infinite open-world simulation.

Recommended first greybox target:

- approximately **160×160 logical 32 px tiles** for the full Region 3 traversal space;
- tune size after measuring traversal time and quest pacing;
- use chunked culling/activation where useful so the whole region does not fully simulate at once.

The numeric map size is a production target, not story canon.

Status: `LOCKED CONTENT SCOPE / SIZE TUNABLE`

## 24.4 Region 3 town structure

The Region 3 town contains **20 total built structures, including the central tower**.

Only important gameplay buildings need interiors. Decorative structures establish a believable town without creating unnecessary interior-production cost.

### Enterable / functional structures — 8 total

1. **Central Tower** — tower access and physical entrance;
2. **Quest Hall** — main/side quest coordination and key NPC services;
3. **Blacksmith** — equipment upgrading;
4. **General Merchant** — buying/selling core goods;
5. **Inn / Rest House** — rest, recovery, and save-related service presentation;
6. **Storage House** — player storage;
7. **Training Hall** — tutorial/combat practice/skill-system presentation;
8. **Clinic / Apothecary** — consumable/healing service; no full alchemy crafting required.

### Decorative structures — 12 total

Examples include homes, workshops, stalls, storehouses, civic facades, and other non-enterable town structures.

Decorative structures may visually use doors/windows/signage but must not imply enterability unless interaction is actually implemented.

Status: `LOCKED FOR PROTOTYPE`

## 24.5 Central tower placement

The tower is the **primary central landmark of the Region 3 town**. The town is spatially organized around it so the player can re-orient toward it from major town routes.

Requirements:

- strong silhouette from multiple town approaches;
- clear physical entrance;
- surrounding plaza/approach space suitable for NPCs, quest staging, and onboarding;
- town navigation must not require passing through the tower;
- tower remains physically accessible after teleport access is unlocked.

Status: `LOCKED`

## 24.6 World Map vs Region Map

The game uses separate map layers.

### World Map

Shows:

- Luminar;
- the 12 region locations/boundaries at strategic scale;
- current region;
- quest-unlocked travel state;
- locked/future regions.

For the prototype, only Region 3 requires full travel implementation.

### Region Map

Shows Region 3 at local gameplay scale:

- town;
- tower;
- roads;
- explored subzones;
- quest markers;
- discovered services;
- checkpoints/fast-travel points when unlocked;
- Recommended Level / Danger information for hostile zones.

### Tower Floor Map

Tower floors use their own floor-map data and do not replace the Region Map.

Status: `LOCKED`

## 24.7 Region travel and unlock rules

Travel to other Luminar regions is **quest-gated** in the long-term game.

Prototype rule:

- Region 3 starts unlocked;
- no other region requires playable implementation;
- World Map entries for other regions may display as locked/future;
- Agency Agents must not invent the quests, travel methods, or content for those regions yet.

Status: `LOCKED FOR PROTOTYPE`

## 24.8 Overworld combat and NPC population

Region 3 supports combat outside the tower.

Rules:

- hostile overworld enemies follow the same **no weak/stupid filler enemy** philosophy as tower enemies;
- civilians and ambient NPCs are allowed and are **not** combat filler;
- ambient NPCs do not require full daily schedules in the prototype;
- regional enemies may patrol, guard, pursue quest objectives, or occupy authored encounter zones;
- full-AI concurrency limits still apply;
- overworld quest encounters use spawn/activation boundaries so the entire region does not run combat AI simultaneously.

Status: `LOCKED`

## 24.9 Region quest structure

Region 3 has its own main-story and side-quest content in addition to tower-floor quests.

Regional quests may:

- introduce the protagonist and class systems;
- unlock town services;
- unlock the Tower Sigil;
- teach the Danger system;
- direct the player toward or away from tower content;
- unlock regional checkpoints;
- create temporary hostile/defense/escort states in the overworld.

Tower progression remains the central long-term progression structure. Regional quests support and contextualize that loop rather than replacing it.

Status: `LOCKED`

## 24.10 AI-assisted map generation rule

AI may be used during development to generate **map concepts, environment layouts, building-placement drafts, terrain ideas, and visual references** for Region 3.

The runtime game does **not** need AI-generated overworld layouts.

Production rule:

1. AI/agents may generate candidate Region 3 layouts;
2. the Level Designer validates traversal, building placement, quest routes, danger-zone separation, and tower visibility;
3. one approved layout becomes the saved authored Region 3 map;
4. quest-critical coordinates/IDs remain stable;
5. later regeneration is treated as a map revision and must be revalidated.

This keeps town and regional quests deterministic while allowing AI-assisted production.

Status: `LOCKED`

## 24.11 Tower floor procedural generation model

Tower floors remain procedural and use authored room modules with tags such as:

- Entrance
- Combat
- Escort Route
- Defense Arena
- Objective
- Elite
- Reward
- Safe
- Vendor
- Secret
- Exit
- Boss

Quest generator consumes compatible room sockets instead of placing objectives blindly after generation.

Status: `LOCKED`

---

## 24.12 Region 3 authored layout brief — PROTOTYPE REQUIRED

Region identity beyond approved geographic facts remains `TBD — DEVELOPER DECISION`. The following is a buildable **greybox layout hypothesis**, not newly locked biome/lore. Use stable IDs, validate it in greybox, then freeze one authored map revision. Logical coordinates use tile units, origin at the northwest, +X east and +Y south; they are not 3D world coordinates.

**[INITIAL TUNING HYPOTHESIS]**: 160×160 total tiles; central town within x48–111/y48–111. A tower-centered plaza connects a circulation loop, eight functional destinations, and outward quest routes. Main paths target four tiles of clear width and escort routes at least three, subject to actual player/NPC footprints and combat tests. No width is validated merely by this number.

| Zone ID | Initial position / link | Gameplay function and navigation | Recommended Level hypothesis |
|---|---|---|---|
| R3-TOWN | Central x48–111/y48–111 | Stable services and preparation; ring route around tower. Four signed approaches; no tower transit required to cross town. | SAFE while no authored hostile event is active |
| R3-OUTSKIRTS | South approach x48–111/y112–143 | First external read of danger; short return route and visible town gate. | 1–2 |
| R3-ROADS | West x16–47/y64–127 and connecting outer path | Road/field encounters and regional side objectives; landmark at each quest fork. | 2–4 |
| R3-RUINS | North x40–111/y16–47 | Harder regional quest locations; clear return corridor and authored climb link on an optional route. | 4–7 |
| R3-RISK | East x112–143/y40–111 | Optional late-prototype encounter pockets with explicit entry warnings. | 8–10 |
| R3-EDGE | Outer margins and nontraversable terrain | Clear authored boundary; no fall/swim traversal and no implied route to another playable region. | Not a travel destination |

These are footprint reservations; walkable zones need not fill every rectangle. Each concrete hostile subzone receives one Recommended Level from its proposed band before it enters a build; the UI must not attempt to evaluate a range. Zone boundaries have unambiguous ownership and no overlapping conflicting Danger values. “Ruins,” “road,” and “field” describe the approved environment vocabulary and do not assert a historical event or named faction. Main regional progression must have a route that does not require crossing the optional high-risk pocket.

Critical topology: town circulation loop joins all services; the south approach reaches early objectives; west road and north approach reach regional side content; an optional outer connection can shorten return travel after authored discovery. Such connections are walking routes, not an unapproved general fast-travel network. Regional checkpoints may be saved respawn anchors; map markers do not by themselves grant teleport ability.

### Town structure manifest

Exactly these 20 building identities are counted. Footprints are **reserved lots** in the initial greybox, not final building dimensions. Their doors face the circulation/service approach. No final architecture style is invented.

| ID | Structure / initial lot (x range; y range) | Gameplay anchor and staffing |
|---|---|---|
| R3-B01 | Central Tower (75–85; 67–80) | Entrance faces south into plaza; tower menu/physical access; counted once. |
| R3-B02 | Quest Hall (55–65; 69–79) | Quest acceptance/turn-in board and coordinator; story NPC may appear here. |
| R3-B03 | Blacksmith (94–104; 69–79) | Upgrade preview/commit and recurring blacksmith. |
| R3-B04 | General Merchant (55–65; 87–97) | Buy/sell core stock and recurring merchant. |
| R3-B05 | Inn / Rest House (94–104; 87–97) | Bed/rest interaction, recovery presentation and save feedback. |
| R3-B06 | Storage House (55–65; 53–63) | Deposit/withdraw storage interaction; no extra major NPC required. |
| R3-B07 | Training Hall (94–104; 53–63) | Safe instruction area, practice interaction and skill-system explanation. |
| R3-B08 | Clinic / Apothecary (75–85; 97–107) | Healing/consumable service point; shared stock/service role can avoid a sixth major NPC. |
| R3-B09 | Decorative home (49–53; 49–53) | Non-enterable façade. |
| R3-B10 | Decorative home (69–73; 49–53) | Non-enterable façade. |
| R3-B11 | Decorative workshop (79–83; 49–53) | No implied crafting service. |
| R3-B12 | Decorative storehouse (87–91; 49–53) | No implied player storage interaction. |
| R3-B13 | Decorative home (107–111; 55–59) | Non-enterable façade. |
| R3-B14 | Decorative stall structure (107–111; 65–69) | No separate shop/merchant inventory. |
| R3-B15 | Decorative home (107–111; 81–85) | Non-enterable façade. |
| R3-B16 | Decorative civic façade (107–111; 99–103) | No unapproved faction identity. |
| R3-B17 | Decorative workshop (95–99; 107–111) | Non-enterable façade. |
| R3-B18 | Decorative home (61–65; 107–111) | Non-enterable façade. |
| R3-B19 | Decorative stall structure (49–53; 97–101) | No extra service or blocking frontage. |
| R3-B20 | Decorative home (49–53; 61–65) | Non-enterable façade. |

Reserve the tower plaza primarily at x69–91/y81–93 with circulation continuing around the tower sides. Service connectors, actor staging and sightlines take precedence over decorative lot shape. Roof overhangs cannot hide the player, interactive doors, or quest markers.

The eight functional buildings retain the approved important-interior scope; use compact reusable interior layouts. This is not approval for 20 interiors. Props, walls, roofs, signs, furniture and interior rooms do not increase the structure count. Five recurring major NPC roles remain the target; service stations and temporary quest actors may cover the other locations. The variable quest NPC is placed at the current quest's declared anchor, never duplicated as two simultaneous “same” actors.

### Regional quest and encounter anchors

All labels below are mechanical placeholders, not final quest titles.

| Slot / anchor | Authored purpose | Required behavior |
|---|---|---|
| R3-MAIN-START, Quest Hall | Region 3 main-story onboarding and preparation | Introduce class, town, Danger, physical tower approach, and Sigil acquisition. Packaging awaits DR-03; story explanation is TBD. |
| R3-SIDE-A, south outskirts | Escort-family side objective | Short safe staging → visible encounter read → destination outside the combat corridor; demonstrates wait/follow and retry. |
| R3-SIDE-B, west road/field | Annihilation-family side objective | Explicit designated group; optional tactical approach; visible return landmark. |
| R3-SIDE-C, north quest site | Defense-family side objective | Protected objective, validated wave paths, readable objective health and leave rule. |
| R3-RISK-OPTIONAL, east pocket | Optional high-risk encounter | Warning before entry; no mandatory progression item exclusive to this pocket. |

This allocates three of the five side slots provisionally; tower slots are specified in §53. Final quest count/packaging remains DR-03. Regional enemies are authored placements using the approved archetype pool; they do not require a separate enemy roster.

Interaction points include functional entrances, service stations, quest actor starts/ends, declared checkpoints, a tutorial practice anchor, permitted climb links, loot/objective sockets, and map/danger signposts. Stable IDs bind these to quests and saves.

Training uses a non-enemy practice target or demonstration before a real fight. Any actual combat opponent follows the intelligent-enemy rules; “tutorial” is not permission to create a harmless filler enemy. Climb and environmental hazards are introduced at controlled authored points with visible landing/damage warnings.

### Town safety and navigation acceptance

The prototype needs a safe preparation hub; a mandatory town siege is not implied. If a later authored quest temporarily activates hostiles in town, its zone flag, affected service behavior, civilians, combat admission, and restoration to SAFE must be explicit.

From each main approach and the plaza, the player can identify the tower or a clear directional landmark. The Region Map supplements this readable environment. Working entrances use one consistent affordance; decorative doors do not show interaction prompts. All eight functional entrances and every quest-critical anchor must remain reachable with actual collision.

Freeze the map revision after greybox traversal, escort-route, tower-silhouette, danger-boundary, and service-entrance validation. Saving/loading or visiting a tower floor cannot move these anchors. A later map edit requires reference validation and explicit save migration where coordinates change.

## 24.13 Procedural generation contract — PROTOTYPE REQUIRED

Generation input includes floor ID, generation seed, generator version, module/content version, approved encounter configuration, and generation-relevant quest/world flags. Return a validated immutable layout manifest plus initial instance state. Seed alone does not describe a played floor.

A room module declares footprint, connectors and allowed transforms, walkable/collision data, compatible actor clearance, objective socket capacities, spawn regions, hazard exclusions, arrival candidates, and supported state variants. Theme tags do not replace geometric validation. Connectors must match after transformation; room rotation/mirroring cannot reverse a required one-way link or invalidate art/navigation.

Generation order:
1. Resolve the required primary objective, relevant branch conditions, and reservation requirements for every authored side quest assigned to this floor that can become available, including unaccepted quests.
2. Reserve entrance, objective rooms, connecting routes, defense/escort space, required elites, boss template where applicable, and exit. Required side-quest reservations survive optional-content reduction and fallback; accepting/completing those side quests remains optional.
3. Construct the connected critical graph and verify its objective/gate dependency graph.
4. Add optional rooms, secrets, vendors, hazards, and encounters only from remaining spatial/population capacity.
5. Bind actor/objective IDs, valid spawn locations, navigation and safe arrivals.
6. Validate the complete candidate; only then commit the floor instance and entry save state.

The entire occupied footprint stays within 50×50 logical tiles. The exit must be structurally reachable and its activation predicate achievable; validation does not disable the quest clear gate. Mandatory rooms never require finding a secret, buying a random item, a future skill, or an escort-incompatible climb link.

| Validator | Required proof |
|---|---|
| Critical connectivity | Player footprint can traverse entrance → every required objective → exit in a satisfiable gate order. |
| Escort | NPC footprint and supported movement can traverse every route state, waiting/turning point and destination. |
| Defense | Each admitted wave spawn can reach the objective; player can defend/access it; deadlocked attackers have a visible safe recovery or invalid-layout failure. |
| Spawn/arrival | No blocked footprint, active damage volume, immediate unseen strike, or unresolved phase overlap. |
| Encounter budget | Required enemies, elites, boss, adds and waves fit population and simultaneous-admission rules. |
| Hazards | Warnings and a viable response path exist; mandatory quest space is not permanently inaccessible. |
| Boss | Validated Boss Sanctum; all class movement/aim ranges tested; safe pre-boss checkpoint and post-clear exit. |
| Navigation/readability | Doors, primary route and objective affordances survive theme/lighting variation. |
| Identity | Every persistent room, objective, actor and loot source has a unique stable instance ID. |

Use deterministic ordering and separate generation, encounter, and loot random streams; cosmetic variation cannot consume gameplay randomness. Reproduction requires the same full input tuple and versions. Save the resolved room placements, objective bindings and persistent deltas, not just a seed that might mean something else after a content update.

Try a finite configured number of deterministic candidates, then a prevalidated fallback compatible with the **same required objectives and state**. `[INITIAL TUNING HYPOTHESIS]`: 8 candidates before fallback. Optional rooms/population may be reduced; required objectives, Floor 5/10 elites, boss, footprint, and fairness constraints cannot be dropped.

If no compatible fallback validates, retain the source/last committed state, report the exact validation failure and reproducibility tuple, and do not expose the partial level. Every shipped quest/floor configuration needs a validated fallback.

An active floor is never silently rebuilt because a quest flag changes. Apply a supported authored state variant, or use an explicitly approved reset policy under DR-01. Persistence and retry semantics cannot be solved by generating a fresh seed.

---

# 25. Interaction System

Interact targets may include:

- NPCs;
- doors;
- chests;
- switches;
- levers;
- pickups;
- shops;
- blacksmith/upgrader;
- beds/rest points;
- ladders/climb points;
- lore objects;
- quest objects.

Prototype rules:

- one universal interact action: **Yes**
- context prompt: **Yes**
- hold interaction: **Yes where action is destructive/committing or long**
- simple talk/open interactions may use press rather than forced hold
- interaction priority system: **Yes**
- base interaction range: **2 logical world units/tiles-equivalent tuning value**, exposed to data and adjusted during playtest

The original blanket `hold` requirement is refined so ordinary dialogue/chest interactions do not feel unnecessarily slow.

Status: `LOCKED FOR PROTOTYPE`

---

## 25.1 Interaction arbitration

Choose one eligible nearby target using explicit priority: active quest-critical interaction when valid, aimed/nearest supported interaction, then stable tie-breaker. Show the target name and actual action. Occluded or out-of-range interactions cannot activate through walls merely because their sprite is near the player.

At commit, revalidate range, target state, required item/quest flag, menu/combat ownership, and any hold completion. A repeated input or duplicate animation event cannot open two shops, claim a chest twice, or advance two dialogue branches.

Ordinary talk/open is a press. Destruction, irreversible skill spending, and authored quest abandonment show the consequence and require confirmation or deliberate hold. The interaction-range value remains `[INITIAL TUNING HYPOTHESIS]`.

## 25.2 Service responsibilities

The Quest Hall accepts/turns in quests; the General Merchant owns normal buy/sell transactions; the Blacksmith upgrades; Storage deposits/withdraws; Training presents mechanics/build information; Inn and Clinic present recovery/consumable functions without adding alchemy or new resource systems.

A service definition states availability, combat restriction, price if any, recovery amount if any, stock reference, and resulting save event. Recovery prices/amounts are `[INITIAL TUNING HYPOTHESIS]`, never a new punitive death fee. Essential quest progress cannot require an unaffordable optional service. NPC staffing and service ownership are independent, preserving the five-major-NPC target.

---

# 26. Inventory

Prototype inventory:

- required: **Yes**
- layout: **Grid**
- normal inventory slots: **16**
- weight system: **No**
- normal stack limit: **99**
- categories:
  - weapons;
  - armor;
  - consumables;
  - materials;
  - quest/key items.
- quick slots: **Yes**
- quick-slot target: **4 consumable slots**
- hotbar: **Yes**
- item tooltips: **Yes**
- storage: **Yes, in hub**
- auto-sort: **Yes**
- search: **Yes**
- drop normal items: **Yes**
- destroy normal items: **Yes with confirmation**

## 26.1 Quest item protection

Critical quest/key items:

- do not consume the normal 16-slot capacity;
- cannot be dropped;
- cannot be destroyed;
- must persist correctly through save/load;
- may be removed only by quest logic.

Status: `LOCKED`

---

## 26.2 Capacity, ownership and overflow contract

The grid represents 16 normal item/stack slots; do not introduce multi-cell inventory packing. A nonstackable item uses one slot; compatible normal stacks cap at 99. Gold and protected quest/key ownership are separate from normal grid capacity. Four consumable quick slots reference owned stacks/items; they do not duplicate inventory.

Storage has a declared tunable capacity, initially `64 normal slots [INITIAL TUNING HYPOTHESIS]`, accessible through the hub service. Full storage rejects deposits without losing items. This is a capacity starting value, not a new portable storage ability.

A normal world drop remains at its saved source/location when no valid normal slot exists. Only normal-capacity item components of full-inventory quest rewards use pending reward claims; gold, protected quest/key entitlements and progression flags do not depend on normal inventory space. Completion flags and reward entitlement commit together. Pending normal rewards remain claimable through a persistent quest-log claim interaction outside combat, with capacity revalidation, even after the original NPC leaves, the quest closes or the instance unloads/resets. Show “Reward waiting — inventory full.” No invisible deletion, unbounded auto-vacuum, or permanent loss of a critical item is permitted.

Normal dropped items preserve item identity and pickup state. Destroy uses explicit confirmation; destructive input is disabled for protected items. Search and sort affect presentation/order only and never change ownership or quick-slot references.

The Tower Sigil is a special permanent entitlement: even ordinary quest-item-removal logic cannot remove it once granted. Acquire it at an out-of-combat story transaction with a coherent safe snapshot; a failed save leaves the grant transaction visibly pending/retryable rather than claiming durable acquisition. A deliberately loaded older save represents its older timeline, not loss/removal within the current saved progression. All critical quest/key items are protected from sale as well as drop/destruction.

---

# 27. Loot

Prototype supports:

- random drops;
- fixed drops;
- loot tables;
- gear rarity;
- random affixes;
- gold;
- consumables;
- upgrade materials;
- quest items;
- collectibles;
- auto-pickup on contact/proximity where appropriate;
- no long-range loot vacuum.

If inventory is full:

- normal items remain in the world or use an explicit overflow rule;
- quest items must never be permanently lost because of a full inventory.

Status: `LOCKED`

---

## 27.1 Loot resolution contract

Each source declares fixed rewards plus an optional weighted table with legal item/affix pools. Resolve once for its claim ID using the gameplay loot stream, and persist the rolled results before allowing collection. Save/reload, inventory overflow, vendor visits and scene unloading cannot reroll a known source.

Quest-critical rewards are guaranteed by quest logic, not chance. Required class viability does not depend on a Legendary drop or an optional generated vendor. Auto-pickup applies only within the authored contact/proximity range; it validates capacity and source ownership before consuming the source.

Unclaimed normal loot survives permitted unload/save through persistent item/source IDs under DR-01/02. A retry/death policy cannot both restore an unclaimed source and keep its previously collected reward.

---

# 28. Economy

Prototype currency:

**Gold**

Systems:

- shops: **Yes**
- buy/sell: **Yes**
- upgrade costs: **Yes**
- multiple currencies: **No**
- economy sinks: **Yes**
- crafting economy: **Upgrade materials only in prototype**
- hub merchant: **Yes**
- floor vendors: **Optional generated service-room content, not guaranteed every floor**

Status: `LOCKED FOR PROTOTYPE`

---

## 28.1 Economy contract and tuning ledger — PROTOTYPE REQUIRED

| Source | Sink / use | Required constraint |
|---|---|---|
| Primary/side quest rewards | Consumables, selected gear, upgrades, declared recovery services | Guaranteed progression remains solvent without optional random sources. |
| Finite combat/elite/boss gold and materials | Upgrade recipes | Count each source once; intentional boss-plus-quest awards are visible in the budget. |
| Sale of normal items | Alternate purchases/upgrades | No buy→sell profit loop; protected quest items cannot be sold. |
| Authored chest/exploration rewards | Build alternatives and preparation | Optional discovery cannot be the sole source of a mandatory key/resource. |

A vendor has a stock manifest with item IDs, prices, quantities, and an explicit restock rule. Start testing with fixed authored stock; if restocking is approved later it needs a named event and source accounting, not reload-based regeneration. Optional floor vendors use the same transactions and are not required to complete the game.

Buy/sell/upgrade operations revalidate price, stock, funds, materials and capacity, then commit all deductions/results once. On rejection, change nothing. A failed save cannot leave gold deducted without its item or upgrade.

First-pass price/reward/range values are `[INITIAL TUNING HYPOTHESIS]`. Track guaranteed versus random gold/material income and optional versus mandatory spending by floor band. Do not add durability/repair, a second currency, dismantling, monetization, or an infinite enemy loop to repair poor tuning.

Acceptance requires a finite main-route ledger, poor-drop scenario, full-inventory purchase rejection, capped-stack handling, repeat-click resistance, interruption recovery, and at least two affordable meaningful preparation choices rather than a compulsory spend on every visit.

---

# 29. Crafting / Upgrading

Prototype scope:

**Gear upgrading only.**

Required:

- blacksmith/upgrader: **Yes**
- upgrade materials: **Yes**
- upgrade costs: **Yes**
- recipe/data definitions for upgrade requirements: **Yes**

Deferred:

- full item crafting;
- alchemy;
- cooking;
- dismantling.

This resolves the previous contradiction between "upgrading only" and simultaneously requiring full blacksmith/alchemy/cooking systems.

Status: `LOCKED FOR PROTOTYPE`

---

## 29.1 Upgrade contract

A recipe declares compatible item definitions/rarity, source rank, resulting rank/stat changes, gold cost, material IDs/counts, and maximum rank. Preview the exact before/after item and costs. Confirming creates one transaction against the existing item ID; no duplicate item or affix reroll is allowed.

**[INITIAL TUNING HYPOTHESIS]**: start with three upgrade ranks per eligible item and deterministic success, adjusting rank benefits/costs through playtests. This starting recommendation adds no durability, random destruction, failure fee, or crafting profession. Any proposed failure/destruction system would be a consequential change needing approval.

At max rank or insufficient funds/materials, show the reason and leave state unchanged. An equipped upgrade recalculates stats once; a stored/inventory upgrade preserves location. Guaranteed material sources must support intended progress under DR-01's chosen finite/repeatable economy.

---

# 30. NPCs

Prototype major recurring NPC target:

**5 major recurring NPC roles**

1. Tower/quest coordinator
2. Merchant
3. Blacksmith/upgrader
4. Story/lore NPC
5. Variable quest NPC

Additional temporary quest NPCs are allowed.

Systems:

- quest givers: **Yes**
- merchants: **Yes**
- permanent companion NPCs: **No**
- escort NPCs: **Yes**
- permanent combat-capable companion NPCs: **No**
- relationship system: **No**
- daily schedules: **No**
- reputation system: **No**
- dialogue choices: **Yes**
- NPC memory: **Yes, deterministic flag/state memory**

## 30.1 NPC memory implementation

Prototype NPC memory uses saved state/flags, for example:

- quest completed/failed;
- player helped/ignored NPC;
- NPC witnessed event;
- prior dialogue branch;
- item delivered;
- floor milestone reached.

Do not implement free-form LLM memory as a requirement.

Status: `LOCKED`

---

## 30.2 Dialogue and quest actor contract

Dialogue reads declared quest/world/NPC flags, presents authored text/choices, and writes only the selected branch's declared effects. Conversations must not invent canon dynamically. Save the choice outcome and any reward grant together where coupled; revisiting a line does not repeat its reward.

The five recurring roles can share service spaces; temporary escorts/defense quest actors do not silently become permanent companions. One stable actor ID resolves to one current location/state. Despawning for scene transitions is distinct from death.

Every branch has a valid continuation or explicit conclusion. Failed/abandoned quests must still leave access to required services and the primary tower route. Consequential narrative branches, faction creation, final wish effects and NPC histories remain `TBD — DEVELOPER DECISION`.

---

# 31. Narrative

Known high-level narrative:

- fantasy world on the planet **Luminar**;
- Luminar contains 12 regions at world-map scale;
- the prototype begins in **Region 3 / Solmere** (placeholder regional name);
- Region 3 is a geographic starting place and does not inherently define the player's class, faction, difficulty, or identity;
- a tower crisis is tied to potential world destruction;
- the protagonist climbs the tower as part of stopping/surviving that crisis;
- fame and treasure are major motivations/rewards;
- a powerful wish is associated with reaching the tower's true summit;
- the wish can support exceptional stats/skills and future sequel progression;
- multiple towers exist in the broader long-term setting;
- the first 10 floors are only the prototype slice, not the full tower journey.

Player failure:

- no permadeath;
- player respawns at the latest valid checkpoint/save state.

Still intentionally TBD because it is story canon:

- exact tower origin;
- exact mechanism of world destruction;
- central antagonist identity;
- factions and lore;
- detailed themes;
- final ending structure;
- exact wish rules;
- sequel canon.

Agency Agents must not invent these without approval.

Status: `LOCKED HIGH LEVEL / CANON DETAILS TBD`

---

# 32. Save System

Prototype save requirements:

- autosave: **Yes**
- manual save: **Yes**
- checkpoints: **Yes**
- save slots: **3**
- save after major floor progression: **Yes**
- checkpoint before boss: **Yes**
- cloud save later: **Yes**
- Steam Cloud later: **Yes**

## 32.1 Save restrictions

Manual saving is allowed outside active combat and outside states where serialization would create invalid quest/combat state.

Do not allow manual saving:

- during an active attack exchange when critical transient state cannot be restored safely;
- during boss phase transitions;
- during non-serializable cinematic transitions;
- during generator construction.

Autosave triggers:

- enter hub;
- enter unlocked floor;
- major quest checkpoint;
- floor completion;
- before boss encounter;
- major reward/state transition.

Death:

- respawn at latest valid checkpoint;
- no permadeath.

## 32.2 Compatibility

Save files use explicit format versioning.

During prototype development, migrations should be provided when reasonable, but breaking experimental builds may invalidate saves if clearly documented.

Status: `LOCKED`

---

## 32.3 Persistence ownership and coherent snapshots — PROTOTYPE REQUIRED

| Saved group | Required state |
|---|---|
| Profile | Save slot/profile ID, entered protagonist name, chosen class, level/XP, automatic stats, skill unlocks/ranks/points/equipment. |
| Items/economy | Gold, inventory/storage item identities, realized affixes/upgrades, quick-slot references, vendor stock, material balances, pending reward claims. |
| Permanent progression | Sigil entitlement, floor discovered/unlocked/cleared flags, committed quest outcomes and NPC/world flags. |
| Region | Authored map revision, discovery, checkpoint IDs, encounter outcomes, loose loot and declared quest state changes. |
| Tower | Instance identity, seed and generator/content versions, resolved layout manifest, objective bindings, defeated actors, loot claims, checkpoints and supported room state variants. |
| Current safe snapshot | Map/instance, player position/facing/resources, valid checkpoint anchor, supported cooldown/status durations, serializable quest attempts/timers/actors. |
| Integrity | Schema/build/content versions, coherent transaction/checkpoint sequence, validation metadata and recoverable prior save generation. |

A manual **load** restores the supported out-of-combat snapshot, including its valid player location. The **death respawn anchor** is a separate field. DR-02 decides which state survives death; this pass does not pretend that recording an anchor decides retention policy.

Only serialize supported safe states. Autosave requests during combat, generation, phase transitions or unsupported quest transitions are queued; take a fresh coherent snapshot when a safe boundary occurs. Show pending/succeeded/failed save state accurately. A pending request is not advertised as durable progress.

Manual save during an escort is allowed only if the complete supported attempt/actor state is serializable and the shared safety guard passes; otherwise explain the specific state restriction. Loading is never a way to omit an active escort actor while keeping its progress.

Save atomically: construct and validate a complete snapshot, write a temporary generation, verify it, replace the slot's current generation safely, and retain the previous valid generation for recovery. Disk failure or interruption leaves a valid older save available. Three slots are independent; no write can corrupt a different slot.

Validate referenced content IDs, protected items, unique claims, quest/floor dependencies, item ownership and arrival coordinates before applying a load. Use an explicit migration for changed versions or present a clear incompatibility error; never silently regenerate the region/floor to hide missing data.

## 32.4 Checkpoint and failure boundaries

A checkpoint records a coherent safe snapshot and a valid respawn anchor. Floor entry, supported safe/rest points, before-boss staging and major progression use explicit checkpoint/save events; they are not arbitrary coordinates inside a live attack.

Death immediately blocks new combat/service/travel actions, resolves the attempt result, and offers the latest valid checkpoint flow. Simultaneous boss/player defeat is resolved once from the authoritative end-of-tick outcome under the selected DR-02 policy; no partial boss reward can be granted before a rollback decision. The concrete success-vs-failure tie rule is part of DR-02.

Quest failure and death are different events. A failed escort may offer retry without a player death; a death may invalidate an active defense attempt. The definition enumerates which attempt state resets; no attempt-local reset can erase permanent Sigil ownership or unrelated completed quests. Death and manual-load restoration use the selected snapshot policy. Within the restored timeline, attempt-local reset cannot erase unrelated permanent progression. Permanent ownership protection does not authorize mixing flags from one snapshot with rewards or source state from another.

On interrupted travel/generation, load either the complete source state or complete validated arrival state. Never combine destination coordinates with the source floor manifest. On repeated reward events, the committed claim ID prevents duplicates.

Required evidence: load after purchase/upgrade/quest reward; fail/retry an escort; reload a modified seeded floor; interrupt each save stage; resolve boss/player simultaneous death; and verify the same approved policy for all three classes.

---

# 33. UI / UX

Prototype requires:

- main menu;
- save selection;
- class selection;
- pause menu;
- settings;
- HUD;
- HP bar;
- stamina bar;
- mana bar only for Mage;
- ammunition indicator when a ranged weapon requires it;
- 2 active skill slots;
- cooldown indicators;
- status effect display;
- quest tracker;
- inventory;
- equipment screen;
- character/progression screen;
- skill tree;
- minimap;
- dialogue UI;
- item tooltips;
- damage numbers;
- enemy health bars;
- boss health bar;
- floor indicator;
- Recommended Level display;
- Danger Rank display;
- objective indicators;
- interaction prompts;
- tutorial prompts;
- shop UI;
- blacksmith/upgrade UI.

The World Map **view** is required by §§4/24/56; a dedicated full-screen presentation is optional. A compact map tab satisfies that presentation choice if it displays Luminar's 12 regions and their travel state. Region Map, current Tower Floor Map data/view, and minimap remain distinct. Only Region 3 is playable.

Status: `LOCKED FOR PROTOTYPE`

---

## 33.1 Screen responsibilities and feedback

| Surface | Must communicate / allow |
|---|---|
| New game / three saves | Entered protagonist name, class choice and its permanence; accurate slot identity; explicit overwrite confirmation. |
| Combat HUD | HP/stamina, Mage mana or applicable ammo, active cooldowns, statuses, current objective/timer, interaction target, danger/floor identity. No unused resource bar. |
| Build/inventory | Five equipment slots, two active/two passive slots, four consumable shortcuts, learned-vs-equipped skills, costs/prerequisites, protected items and pending rewards. |
| Quest log/tracker | Acceptance conditions, current required step, map location, failure/retry/leave consequences and completed outcome. |
| Tower menu | Every eligible cleared/uncleared floor, unavailable state/reason, Recommended Level, Danger, quest indicators, boss/elite warnings, safe destination and confirmation. |
| Maps | World context, authored Region 3, and current generated floor in separate layers; navigation and risk information use stable IDs. |
| Services | Price/cost, stock/capacity, before/after upgrade or recovery result, rejection reason. |
| Save/pause | Paused state, persistent combat restriction, pending/success/failure save indication, valid return action. |

Minimap and floor maps expose only the intended discovered/known information. Distinguish unknown space from locked quest access; neither means a hidden level gate. Tooltips may describe nonportable quest state before travel.

Use a separately scalable UI layer over the low-resolution world as a reversible implementation baseline. Pixel-art icons stay crisp; text size/UI scale changes must not require changing combat zoom. All required actions remain reachable at minimum output and largest supported UI/text setting.

Critical feedback is redundant: shape/icon/text or audio accompanies color where relevant. Damage numbers and low-priority status text can be reduced under load; windups, attack cues and objective health cannot disappear behind them.

---

# 34. Camera

Presentation:

**Orthographic 3/4 angled top-down.**

For the 2D implementation this means:

- use a 2D orthographic camera/presentation;
- environment and sprite art visually imply a 3/4 top-down angle;
- no perspective scaling based on depth;
- objects should not become larger because they are visually lower on screen;
- maintain pixel consistency.

Camera features:

- follow smoothing: **Yes, subtle**
- dead zone: **Yes, small**
- mouse/look-ahead: **Yes, capped**
- shake: **Yes, intensity-limited and accessibility-toggleable**
- zoom: **Yes**
- player-controlled zoom: **Yes, discrete pixel-safe steps only**
- room locking: **Yes where useful**
- wall transparency: **Yes when walls obscure the player/objective**
- camera boundaries: **Yes**

Status: `LOCKED`

---

## 34.1 Presentation coordinate contract

Keep authoritative ground position, ground-footprint collision, body facing, continuous aim, grip/weapon transform, and attack geometry distinct. Camera motion changes presentation, never combat range or collision.

Body facing uses horizontal aim with normalized/angular hysteresis around vertical; the cursor's distance and camera zoom must not change the flip threshold. At zero-length aim retain the last valid aim. Mirror the visual body/grip layout without mirroring the world collision or reversing a projectile twice.

Order the actor composite against walls/other actors using its ground anchor. Inside the composite, use authored behind-body/front-body weapon layers by aim/action. An attached weapon must not draw globally over an unrelated foreground wall just to appear in front of its owner. Body and weapon timing/aim stay aligned with attack geometry.

Continuous raster weapon rotation can produce changing stair-step silhouettes. Nearest filtering alone does not solve this; inspect grip stability and silhouettes at representative angles before approving assets. Do not add front/back protagonist bodies as a workaround.

## 34.2 Pixel-safe camera and zoom baseline

Use the recommended 640×360 world canvas with nearest-neighbor integer output scaling and a stable aspect ratio. Letterbox where necessary rather than distorting pixels or revealing extra off-room information. UI is independently scalable as described in §33.1.

Use discrete integer world-camera magnifications as the initial zoom policy: `1× and 2× [INITIAL TUNING HYPOTHESIS]`. This is a starting implementation choice, not a new content lock. Validate combat framing at every offered step; never offer a step that hides necessary danger cues without a readable warning. Fractional zoom is not pixel-safe just because output scaling is integer. Zooming out below the source baseline requires separate art/framing approval.

Combine subtle smoothing, dead zone, capped look-ahead and reduced-motion settings in one final camera solution. Quantize presentation where needed, leaving gameplay positions unrounded. Clamp the **final visible rectangle**, including shake/look-ahead, to intended bounds. Reset interpolation/history after teleport to avoid a streak from the previous location.

Wall transparency preserves the wall's collision/door affordance and reveals the player/objective without leaking undiscovered rooms. Test aim-coordinate conversion, occlusion and weapon sorting at each zoom, boundary and resize.

---

# 35. Accessibility

Prototype supports:

- remappable controls;
- UI scaling;
- text-size options;
- screen-shake toggle/intensity;
- flash reduction;
- color-blind-support strategy for critical information;
- hold/toggle alternatives;
- subtitle options;
- motion reduction;
- accessibility assists.

Accessibility assists are separate from the core difficulty selection and do not automatically make enemy AI stupid.

Status: `LOCKED`

---

## 35.1 Required access tests

Rebinding detects conflicting bindings and permits recovery to defaults. Hold/toggle alternatives preserve action commitments and costs. Text/UI scaling cannot clip a required confirmation or block quest progression.

Screen shake, motion reduction, flash reduction and color-independent critical cues do not modify enemy intelligence. Subtitle/text presentation covers any authored spoken/tutorial information; voice acting is not required.

Gameplay assists remain an approved category whose concrete factors/ranges must be declared before they ship. Do not silently implement extra difficulty modes, automatic perfect counters, new progression gates, or deliberately weaker AI. The prototype can first validate the required presentation/input accessibility features while specific gameplay-assist settings are specified with the developer.

---

# 36. Difficulty

Core game difficulty:

**One intended baseline difficulty: Hellmode.**

There are no Easy/Normal/Hard menu modes in the prototype.

Rules:

- enemy AI does not become intentionally stupid;
- floor stats naturally scale with progression;
- Recommended Level/Danger system communicates risk;
- underleveled entry is allowed;
- accessibility assists may adjust specific player-facing factors without becoming a separate campaign difficulty mode;
- no permadeath.

## 36.1 Scaling

Allowed:

- enemy HP/damage scaling by authored floor/enemy data;
- elite/boss modifiers;
- quest modifiers;
- later multiplayer scaling when multiplayer exists.

Not allowed:

- hidden dynamic rubber-banding solely because the player performs well;
- invisible underleveled penalties beyond the floor's native tuning.

## 36.2 Hardcore mode

**Deferred from prototype.**

The previous `hardcore = yes` entry conflicted with the single Hellmode/no-permadeath design and is therefore removed from prototype scope.

Status: `LOCKED`

---

# 37. Audio

Prototype audio baseline:

- exploration music: **Yes**
- combat music: **Yes**
- boss music: **Yes**
- simple adaptive transition between exploration/combat: **Yes**
- floor ambience: **Yes**
- UI SFX: **Yes**
- footsteps: **Yes**
- weapon SFX: **Yes**
- impact/hit SFX: **Yes**
- spell/skill SFX: **Yes**
- environmental hazard SFX: **Yes**
- basic positional audio where useful: **Yes**
- voice acting: **Deferred**

Audio must support combat readability; dangerous attacks should have recognizable cues where appropriate.

Status: `LOCKED FOR PROTOTYPE`

---

## 37.1 Native audio contract — PROTOTYPE REQUIRED

Use named gameplay audio events and native Godot audio as the prototype baseline; FMOD/Wwise, 3D occlusion and elaborate music stems are not required. UI/music are non-positional; world threat/impact sounds use 2D position where useful. Prefer a player-centered listener so camera look-ahead does not distort threat location/loudness.

Required buses: Master, Music, Gameplay SFX, UI, Ambience; expose volume/mute controls. Music state follows the shared encounter state: exploration → combat → boss where applicable → victory/recovery/exploration, with bounded fades and debounce. Loading/pausing/death cannot start duplicate persistent music instances.

| Event priority | Examples | Under load |
|---|---|---|
| Critical | Dangerous windup, imminent hazard, defense success/failure, boss phase cue | Reserve audible capacity; pair with visual cue. |
| Gameplay | Player attacks, impacts, skill use, objective feedback | Limit repeated same-event overlap while preserving result recognition. |
| Decorative | Ambient details, extra footsteps, low-value distant impacts | Reduce/steal first. |

The existing target of ≤32 simultaneous important positional SFX requires aggregate admission; per-emitter limits alone do not enforce it. Each event defines priority, overlap limit, duration/lifecycle, variation allowance and stop condition. Dormant/unloaded actors stop their owned loops.

Sonic identity is `[PLACEHOLDER — PLAYTEST]`: clear, tense, responsive. Variation must preserve attack-cue identity and timing. Test music transitions, mono output, sound-off visual comprehension, maximum overlap, and threat audibility with accessibility settings. No final music, sounds, or voice files are created in this specification pass.

---

# 38. VFX

Prototype VFX requires:

- hit sparks;
- slash trails;
- projectile effects;
- magic effects;
- enemy attack telegraphs;
- block effect;
- parry effect;
- dash trail;
- damage flash;
- death effect;
- boss phase effects;
- hazard telegraphs.

Priority rule:

**Gameplay telegraphs always have visual priority over decorative VFX.**

VFX must remain readable around a 32×32 character and must not obscure enemy windups, projectiles, or quest objectives.

Status: `LOCKED FOR PROTOTYPE`

---

## 38.1 Pixel-art asset and readability contract

Asset metadata records source, license, dimensions, palette/material ramp, pivot/ground anchor, frame order/timing, transparent bounds and intended render layers. The character uses a stable 32×32 body canvas and common ground/grip reference; effects/weapons may extend separately without resizing the body between actions.

Required visual tests compare identity colors and silhouette across frames, side mirroring, all actions, representative aim angles, and lighting conditions. Lighting may produce consistent authored modulation; source colors cannot drift/noise independently between animation frames. Preserve clean alpha edges and nearest sprite sampling; no accidental blur or noisy generated frames.

Combat cue grammar is shared: preparation/windup, active danger region, defense outcome and recovery remain distinguishable. Critical telegraphs have priority over trails, hit flashes, particles, damage numbers and decorative lights. Effects must show actual attack direction, width, timing and hazard state sufficiently accurately for player decisions.

Dynamic 2D lights, selected occluders and stylized contact shadows satisfy the approved direction. Profile light coverage, shadow casters, blending/overdraw and simultaneous effects as well as particle count. Reduce decoration/light complexity before reducing critical cues or enemy behavior quality.

Art production order: approved side-body reference/palette/pivots → movement/aim/defense/combat animations → one readable enemy set and telegraphs → reusable environment modules → remaining required actions/archetypes/effects → polish. All final asset generation lies in the later implementation phase.

---

# 39. Technical Platform

## 39.1 Engine

**Godot 4.5+**

Rules:

- 4.5 is the minimum project compatibility target;
- the project repository must pin/document the exact stable Godot version actually used for production builds;
- do not silently depend on a later-version-only API without documenting the version requirement.

Status: `LOCKED`

## 39.2 Prototype OS

**Windows x64**

Other platforms are deferred.

Status: `LOCKED`

## 39.3 Frame rate

- design/QA target: **60 FPS**
- fixed gameplay/physics target: **60 Hz** where appropriate
- minimum acceptable floor on minimum target hardware: **25 FPS**
- combat timing must be time-based/fixed-step safe and must not become faster/slower with render FPS.

Status: `LOCKED`

## 39.4 Resolution

- minimum supported output target: **1280×720**
- recommended internal pixel canvas: **640×360**
- scale to output using integer/pixel-safe scaling where possible;
- support resolutions above 720p;
- fullscreen and windowed modes: **Yes**
- ultrawide: maintain playable viewport and UI anchoring; do not expose unintended off-room information.

Status: `LOCKED FOR PROTOTYPE`

## 39.5 Renderer

Default toward a renderer/configuration that performs well on modest Windows hardware and supports required 2D lighting/VFX.

Do not choose a more expensive renderer solely for unused 3D features.

Exact renderer backend is an implementation choice to validate against the required lighting/VFX and target hardware.

Status: `IMPLEMENTATION DECISION — MUST BE BENCHMARKED`

---

## 39.6 Godot feasibility and responsibility boundaries

Official Godot 4.5 documentation supports the selected 2D approach. Engine capabilities establish feasibility, not measured project performance.

| Responsibility | Contract / feasible baseline | Verification source |
|---|---|---|
| World rendering | 2D canvas, nearest textures, integer output scale, separately scalable UI. | [Multiple resolutions](https://docs.godotengine.org/en/4.5/tutorials/rendering/multiple_resolutions.html) |
| Actor ordering | Ground-anchor world Y order plus local body/weapon ordering; consistent Z policy. | [CanvasItem Y-sorting](https://docs.godotengine.org/en/4.5/classes/class_canvasitem.html#class-canvasitem-property-y-sort-enabled) |
| Camera | Final bounds include offsets; avoid enabling both pixel-snap modes blindly; reset interpolation after travel. | [Camera2D](https://docs.godotengine.org/en/4.5/classes/class_camera2d.html), [2D interpolation](https://docs.godotengine.org/en/4.5/tutorials/physics/interpolation/2d_and_3d_physics_interpolation.html) |
| Lighting/backend | Evaluate Compatibility first for modest Windows/2D use, then pin the measured renderer/version. | [Renderers](https://docs.godotengine.org/en/4.5/tutorials/rendering/renderers.html), [2D lights and shadows](https://docs.godotengine.org/en/4.5/tutorials/2d/2d_lights_and_shadows.html) |
| Input | Gate global polled input as well as UI events; UI event handling alone does not change global input state. | [Input](https://docs.godotengine.org/en/4.5/classes/class_input.html) |
| Audio | Native positioned 2D playback and explicit aggregate priority/voice policy. | [AudioStreamPlayer2D](https://docs.godotengine.org/en/4.5/classes/class_audiostreamplayer2d.html) |
| Timing | Shared 60 Hz simulation clock; do not equate short Timer callbacks with precise combat windows. | [Timer](https://docs.godotengine.org/en/4.5/classes/class_timer.html), [Engine physics-step limits](https://docs.godotengine.org/en/4.5/classes/class_engine.html#class-engine-property-max-physics-steps-per-frame) |

The implementation owns input/action admission, combat resolution, perception/AI, quest progression, level instances, inventory/economy and persistence as separable responsibilities. Presentation consumes their state/events. Stable IDs and explicit transactions matter; an elaborate framework, specific directory tree or speculative networking layer does not.

At each fixed tick, admit eligible intents, establish action states and windows for that tick, resolve movement and valid contacts/defense, apply damage/status/poise, resolve deaths/objectives, then emit feedback. Advance action age for the next tick only after evaluating the current tick. Boundaries use a documented start-inclusive/end-exclusive interval convention. Same-tick events use stable ordering. Deduplicate by action-instance ID, target ID, and authored hit-interval/index; separate permitted hits of a multi-hit action remain eligible.

Use shared combat hit-stop as the reversible first-pass baseline: freeze the active gameplay simulation together, including actors, projectiles, hazards, status ticks, cooldowns, resource regeneration, and quest timers. Retain buffer lifetime and release through a bounded independent clock while UI remains responsive. Do not implement actor-local freezes that leave unseen threats moving without a separate fairness review.

Fixed stepping improves consistency but cannot guarantee real-time fidelity under arbitrary machine stalls. Observe physics backlog and injected stalls; do not claim the 25 FPS floor proves equal cue readability. The exact production engine version and renderer are later measured/pinned choices.

The Agency Godot profile's `@tool` example is not a requirement for gameplay scripts: `@tool` enables editor execution, not a typing strict mode. Its RefCounted/signal workaround is also unnecessary. Follow verified engine semantics, not erroneous profile examples. [Editor execution](https://docs.godotengine.org/en/4.5/tutorials/plugins/running_code_in_the_editor.html), [RefCounted](https://docs.godotengine.org/en/4.5/classes/class_refcounted.html).

---

# 40. Multiplayer — Future

Prototype:

**No multiplayer implementation required.**

Long-term:

**Multiplayer planned.**

Future TBD:

- co-op vs PvP;
- maximum players;
- shared tower rules;
- quest synchronization;
- host/dedicated model;
- matchmaking;
- lobbies;
- drop-in/out;
- loot ownership;
- revive system;
- anti-cheat;
- save ownership;
- latency handling.

Prototype architecture guidance only:

- separate persistent game state from visuals where practical;
- use stable IDs for persistent entities/quests/items;
- avoid gameplay logic that exists only inside UI nodes;
- do not add network code yet.

Status: `LOCKED FUTURE INTENT`

---

# 41. Performance Budget

Prototype performance targets:

| System | Target |
|---|---|
| Full-intelligence enemies active | 6–8 typical |
| Late-floor active enemies | 8–10 typical |
| Hard active-AI cap | 12 |
| Nearby reduced-simulation enemies | up to ~24 before profiling review |
| Remaining floor population | dormant/room scoped |
| Simultaneous projectiles | target ≤128 |
| High-cost transient particles | target ≤400 active before profiling review |
| Simultaneous important positional SFX | target ≤32 |
| Major NPCs visible in hub | target ≤12 |
| Target render rate | 60 FPS |
| Minimum acceptable rate | 25 FPS on minimum target hardware |
| Normal floor transition/load | target under 5 seconds on SSD-class storage |
| Prototype RAM target | under 2 GB where practical |

Budgets are soft engineering targets until profiling proves a better number.

No agent may increase a budget materially without profiling evidence.

Status: `LOCKED FOR PROTOTYPE ENGINEERING`

---

## 41.1 Measurement and acceptance basis

The active-AI cap of 12 is a hard prototype design guardrail; the other budgets remain engineering/tuning targets until measured. Renderer choice, simultaneous light/occluder coverage, effect overdraw, pathfinding demand, voice admission and UI load must be profiled together.

**DR-08** owns the minimum/reference hardware basis. Record CPU, GPU, RAM, driver/API, storage, engine/build/renderer, output resolution, zoom and accessibility settings with every benchmark. Do not report “25 FPS on minimum hardware” without a named machine and a reproducible scene.

Capture frame-time distribution, long stalls, physics backlog, peak memory, transition time, active/dormant actors, navigation requests, projectiles, particles/lights and audio voices. The locked 60 FPS target corresponds to approximately 16.7 ms per rendered frame; the locked 25 FPS minimum corresponds to 40 ms. Report percentiles and worst hitches separately; acceptance thresholds remain in DR-08.

Worst-case scenarios include Floor 10 boss/three-elite content in its authored sequencing, admitted adds up to the cap, a defense wave plus adjacent pursuers, maximum readable effects, and town services at maximum UI scale. Test the actual allowed composition; do not manufacture 100 active enemies from Floor 10's population budget.

If the normal target fails, first reduce decorative effects and unnecessary active work, then optimize measured hotspots. Do not lower intelligence/readability or silently revise locked content targets to make a benchmark pass.

---

# 42. Modding

**No mod support for prototype.**

Do not build Workshop, script modding, custom maps, or custom-character pipelines as prototype requirements.

Status: `LOCKED`

---

# 43. Localization

Prototype language:

**English only.**

Engineering rule:

- player-facing strings should still be separated from gameplay logic where practical;
- do not hard-code important UI text into textures;
- future localization remains possible.

CJK, RTL, and voice localization are deferred.

Status: `LOCKED FOR PROTOTYPE`

---

# 44. Tutorial / Onboarding

Prototype onboarding:

- training section in the hub;
- contextual prompts on Floor 1;
- tutorial can be skipped after the player understands/has previously completed it;
- teach movement;
- teach mouse aiming;
- teach dash vs dodge;
- teach block;
- teach parry;
- teach skills/resources for selected class;
- teach Danger/Recommended Level system;
- teach enemy pattern recognition rather than encouraging button mashing.

A separate full tutorial floor is not required.

Status: `LOCKED FOR PROTOTYPE`

---

# 45. Analytics / Telemetry

The prototype may use online services for:

- crash reporting;
- anonymous gameplay telemetry;
- balance analytics;
- quest completion/failure data;
- death-location heatmaps;
- performance diagnostics.

Rules:

- core single-player gameplay should not require a constant internet connection;
- telemetry must not block offline play;
- privacy requirements must be documented before public distribution;
- do not collect unnecessary personally identifying data;
- public builds should expose appropriate consent/opt-out behavior based on the actual telemetry service used.

Status: `LOCKED AT POLICY LEVEL`

---

# 46. Achievements / Platform Features

Deferred until after the core prototype unless needed for a specific test build.

Possible future systems:

- Steam achievements;
- Steam Cloud;
- Rich Presence;
- Steam Input;
- leaderboards;
- trading cards.

Steam Workshop remains excluded while modding is excluded.

Status: `DEFERRED`

---

# 47. Monetization

**Skipped for prototype planning.**

Do not add monetization systems without explicit approval.

Status: `DEFERRED`

---

# 48. Release Plan

**Skipped for prototype planning.**

Do not assume itch.io, Steam Early Access, demo, or full release until approved.

Status: `DEFERRED`

---

# 49. Legal / Asset Licensing

Prototype asset policy:

Allowed:

- CC0/Public Domain;
- CC-BY with attribution tracking;
- other explicitly free commercial-use licenses whose obligations are understood;
- AI-generated assets where terms permit intended use.

Not allowed without review:

- non-commercial licenses;
- unclear/unknown licenses;
- copied copyrighted game assets;
- paid assets not explicitly approved;
- licenses with obligations the project is not prepared to satisfy.

Maintain an asset provenance manifest containing:

- asset name;
- source URL/path;
- creator/source;
- license;
- attribution text if required;
- modifications;
- date imported;
- responsible agent.

Status: `LOCKED`

---

# 50. QA Requirements

No major feature is complete without executable evidence.

Prototype QA requires:

- build validation;
- scene/load validation;
- input smoke tests;
- movement tests;
- combat smoke tests;
- class-resource tests;
- quest-state tests;
- quest failure/retry tests;
- escort path tests;
- procedural floor connectivity tests;
- deterministic-seed reproduction tests;
- Danger/Recommended Level UI tests;
- enemy AI behavior tests;
- anti-cheating AI tests;
- active-enemy concurrency tests;
- animation-state tests;
- cancel/input-buffer tests;
- inventory overflow tests;
- quest-item protection tests;
- loot tests;
- save/load tests;
- death/checkpoint tests;
- 32×32 sprite readability checks;
- lighting/VFX readability checks;
- performance checks;
- screenshot/video evidence;
- regression checklist;
- independent QA review when practical.

Status: `LOCKED`

---

# 51. Agency Agents Decision Governance

## 51.1 Major decisions

Require explicit developer approval unless the approved master already resolves them. Track pending alternatives in §58; continue all independent work under the current task's autonomy rule.

## 51.2 Minor implementation details

Agents may decide only when fully constrained, low-impact, and logged.

## 51.3 Ambiguity

Major ambiguity must be escalated.

Do not block work for trivial values that can safely be data-driven and tuned later; use a clearly marked prototype value and log it.

## 51.4 Conflicts

Conflicts between locked requirements are recorded with exact affected requirements, options and recommendation in §58. Escalation blocks dependent implementation, not the remainder of this specification pass.

## 51.5 Producer

Producer maintains this master specification, decision log, TBD register, and change requests.

## 51.6 QA independence

QA should be performed by an agent/process other than the implementing agent when practical.

## 51.7 Failed QA

Failed QA returns the task to the responsible implementation role with evidence.

## 51.8 Decision log

Maintain permanent approved decisions.

## 51.9 TBD register

Do not convert a major TBD into canon or a major feature requirement without approval.

Status: `LOCKED`

---

# 52. Current Locked Decisions Summary

| Area | Current decision |
|---|---|
| Working title | Nice Journey |
| Engine | Godot 4.5+ |
| Prototype platform | Windows x64 |
| Presentation | Orthographic 3/4 angled top-down |
| Genre | Tower-climbing fantasy action RPG |
| Structure | Story/quest driven |
| Prototype players | Single-player |
| Multiplayer | Planned later, not prototype |
| Core progression | Quests + levels + skills + gear |
| Prototype world | Region 3 overworld/town + first 10 tower floors |
| Planet | Luminar (working name; can change later) |
| World regions | 12 total; only Region 3 implemented for prototype |
| Starting region | Region 3 / Solmere placeholder |
| World Map | Separate strategic map; 12 regions visible/lockable |
| Region Map | Separate local map for Region 3 |
| Region 3 town | 20 total built structures including central tower |
| Functional interiors | 8 important structures; 12 decorative structures |
| Tower position | Central landmark of Region 3 town |
| Tower access item | Permanent main-story Tower Sigil |
| Tower teleport | Menu-based; cleared + unlocked uncleared floors; outside combat |
| Overworld combat | Yes; same no-filler enemy philosophy |
| Region danger | Soft Recommended Level + DANGER system by subzone |
| Prototype floors | 10 |
| Long-term tower milestones | Every 10 floors |
| Prototype level cap | 10 |
| Floor level gates | Soft recommendation only; underleveled entry allowed |
| Danger system | DANGER I–V based on level deficit |
| Team | Solo developer + Agency Agents |
| Prototype target | 2–3 weeks, quality-first |
| Enemy philosophy | No weak/stupid filler mobs |
| Enemy AI | HSM + Utility + Patterns + Memory + Blackboard |
| Enemy fairness | No raw-input cheating |
| Enemy archetypes | 12 + 1 boss target |
| Active enemy cap | 12 hard prototype target |
| Art | 16-bit-inspired pixel art |
| Character sprite | 32×32 |
| Player body directions | Side only; mirror left/right |
| Front/back body sprites | Not required |
| Aim | 360° mouse free aim |
| Weapon | Separate render/aim layer |
| Animation | Frame-based, 4–12 frames |
| Classes | Melee / Ranged / Mage |
| Class switching | Not required; one class per save |
| Shared resources | HP + Stamina |
| Mage resource | Mana |
| Ranged resource | Ammo where applicable |
| Skills equipped | 2 active + 2 passive |
| Formal combo system | Not required for prototype |
| Dash | Traversal/repositioning |
| Dodge | Defensive move with authored iframes |
| Crouch | No |
| Jump | No |
| Swim | No |
| Roll | No |
| Push objects | No |
| Fall off edges | No |
| Environmental damage | Yes |
| Collision | Rectangle/ground footprint |
| Controls | Keyboard + mouse |
| Movement | WASD |
| Click-to-move | No |
| Lock-on | No |
| Quests | Handcrafted |
| Prototype quest target | 10 main + 5 side |
| Escort NPCs | Yes |
| Floor generation | Procedural from authored modules |
| Floor footprint | Up to 50×50 32px logical tiles |
| Hub | Yes |
| Shops | Yes |
| Inventory | 16 normal slots + separate key items |
| Gear slots | 5 |
| Gear rarity | Common/Rare/Epic/Legendary |
| Gear stats | Random controlled affixes |
| Crafting | Gear upgrading only in prototype |
| Major recurring NPCs | 5 target |
| Save | Auto + manual outside invalid combat states |
| Save slots | 3 |
| Death | Last valid checkpoint; no permadeath |
| Difficulty | Single Hellmode baseline |
| Hardcore mode | Deferred |
| Target FPS | 60 |
| Minimum FPS floor | 25 |
| Output | 1280×720 minimum, higher supported |
| Internal canvas | 640×360 recommended |
| Modding | No prototype support |
| Localization | English only initially |
| Tutorial | Hub training + contextual Floor 1 |
| Asset sources | AI + CC0 + approved free commercial-use licenses |
| QA | Executable evidence required |

---

# 53. Prototype Floor Progression Table

| Floor | Recommended Level | Population Budget | Typical Full-AI Encounter | Special |
|---:|---:|---:|---:|---|
| 1 | 1 | 10 | 3–5 | onboarding |
| 2 | 2 | 20 | 4–6 | normal |
| 3 | 3 | 30 | 4–6 | normal |
| 4 | 4 | 40 | 5–7 | normal |
| 5 | 5 | 50 | 6–8 | 3 elites |
| 6 | 6 | 60 | 6–8 | normal |
| 7 | 7 | 70 | 6–9 | normal |
| 8 | 8 | 80 | 7–9 | normal |
| 9 | 9 | 90 | 8–10 | pre-boss escalation |
| 10 | 10 | 100 | 8–10, hard cap 12 | 3 elites + 1 boss |

Notes:

- population budget is not simultaneous active count;
- encounters are room/objective scoped;
- Annihilation quests target designated encounter groups and do not automatically require killing every possible floor entity unless the quest specifically says so;
- the generator can spawn below budget when quest/room composition requires it;
- quality of enemy behavior takes priority over filling the numeric population cap.

Status: `LOCKED FOR PROTOTYPE`

---

## 53.1 Primary objective coverage — [PLACEHOLDER — PLAYTEST]

This is a reversible mechanical allocation for greybox validation, not new canon or validated encounter balance. Each floor keeps one required primary objective; DR-03 determines definition packaging.

| Floor | Primary family / mechanical objective | Generation and escalation purpose |
|---:|---|---|
| 1 | Annihilation of designated onboarding group. | Teach readable commitments and return/clear flow; regional prelude stages only if DR-03 A is approved. |
| 2 | Escort to a reserved destination. | Validate follow/wait, spacing and route safety with early archetypes. |
| 3 | Tower Defense of a bound objective. | Validate objective priority, admitted groups and clear wave completion. |
| 4 | Annihilation across linked required rooms. | Combine pressure/support roles and optional route choice. |
| 5 | Annihilation including the three required elite targets. | Stage elites across the floor; do not infer three simultaneous elite commitments. |
| 6 | Escort through a longer/varied valid route. | Combine mobility pressure with explicit wait points and compatible hazards. |
| 7 | Tower Defense with composed encounter groups. | Validate cooperation, interruptions and bounded reinforcements. |
| 8 | Escort with a readable optional route tradeoff. | Test advanced enemies without making escort pathing a source of unfair damage. |
| 9 | Tower Defense under late-floor pressure. | Test final pre-boss resource/build readiness and concurrency/readability. |
| 10 | Annihilation milestone including required elites and approved multi-phase boss. | Boss Sanctum, safe pre-boss checkpoint, validated phase/exit rules; DR-07 sets encounter design. |

Two remaining optional side slots may bind to compatible Floor 4/7 sockets as a `[PLACEHOLDER — PLAYTEST]` allocation. Later side-quest acceptance binds to those reserved sockets and declared target state. Missing required reservations are a content-validation failure, not an indefinite player-facing prerequisite; acceptance cannot reroll the live floor.

A finite required target killed before quest acceptance must have declared retrospective credit or protected activation ordering. It cannot permanently invalidate the quest. Optional rewards/outcomes never silently hard-lock primary floor progression.

---

# 54. Decision Log

```text
[2026-09-13]
AREA: Engine
DECISION: Godot 4.5+ compatibility target.
WHY: Developer requirement.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-13]
AREA: Camera / Presentation
DECISION: Orthographic 3/4 angled top-down presentation.
WHY: Developer requirement and compatibility with readable top-down pixel art.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-13]
AREA: Character Sprite Direction
DECISION: Side-only body art; one side authored and mirrored; no front/back body set required.
WHY: Developer requirement and reduced animation workload.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-13]
AREA: Floor Level Requirements
DECISION: Every floor has a Recommended Level but unlocked floors can be entered while underleveled.
WHY: Preserve player agency and high-risk progression.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-13]
AREA: Danger System
DECISION: DANGER I–V warning based on player-level deficit; warnings do not hard-lock entry.
WHY: Clearly communicate risk without artificial access gates.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-13]
AREA: Escort Quests
DECISION: Escort NPCs are allowed as temporary quest actors.
WHY: Required by approved Escort quest type.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-13]
AREA: Class Resources
DECISION: Resource/cooldown behavior depends on class. Melee uses stamina; Ranged may use stamina/ammo; Mage uses mana; cooldowns remain skill-specific.
WHY: Resolves previous resource contradiction while preserving class identity.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-13]
AREA: Prototype Enemy Content
DECISION: 12 reusable mechanical archetypes + 1 Floor 10 boss target; population scales 10 to 100 across Floors 1–10, but only a limited encounter group uses full AI simultaneously.
WHY: Maintains intelligent-enemy pillar without requiring hundreds of unique AIs or unmanageable concurrency.
STATUS: LOCKED
APPROVED BY: Developer via delegated design resolution
```

```text
[2026-09-13]
AREA: Crafting Scope
DECISION: Prototype contains gear upgrading only; alchemy/cooking/full crafting deferred.
WHY: Resolve contradiction and protect 2–3 week scope.
STATUS: LOCKED FOR PROTOTYPE
APPROVED BY: Developer via delegated design resolution
```

```text
[2026-09-13]
AREA: Combat Combos
DECISION: Formal combo-chain system is not required for prototype; short authored attack sequences are allowed.
WHY: Resolve conflicting yes/no answers and reduce prototype complexity.
STATUS: LOCKED FOR PROTOTYPE
APPROVED BY: Developer via delegated design resolution
```

```text
[2026-09-14]
AREA: World Structure
DECISION: Planet Luminar contains 12 regions; Region 3 is the starting region and the only fully implemented prototype region.
WHY: Developer requirement; prevents premature scope expansion into the other 11 regions.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-14]
AREA: Region 3 Environment
DECISION: Region 3 includes a wide authored overworld, a 20-structure town with the tower at the center, separate World/Region maps, ambient civilians, overworld combat, and regional quests.
WHY: Developer requirement.
STATUS: LOCKED FOR PROTOTYPE
APPROVED BY: Developer
```

```text
[2026-09-14]
AREA: Tower Access
DECISION: Main story grants a permanent Tower Sigil that opens a floor-selection teleport menu anywhere outside combat. Cleared floors and unlocked uncleared floors may be selected; locked floors cannot be bypassed.
WHY: Developer requirement for free tower re-entry without removing quest progression.
STATUS: LOCKED
APPROVED BY: Developer
```

```text
[2026-09-13]
AREA: Difficulty
DECISION: One Hellmode baseline; Hardcore mode deferred; accessibility assists remain available.
WHY: Remove conflict between one difficulty and separate Hardcore mode without permadeath.
STATUS: LOCKED FOR PROTOTYPE
APPROVED BY: Developer via delegated design resolution
```

---

## V2.1 director pass — 2026-09-14

Authority: current developer task authorized design/specification refinement only. Added player-experience loop, scoped operational contracts, stable Region 3 greybox brief, quest-aware generation validation, transactional travel/economy/persistence, fair AI ownership, evidence requirements, production gates and explicit consequential-decision register.

Previously approved entries above remain historical approval records. DR-01 through DR-08 are now resolved and approved in §58 by direct developer instruction on 2026-09-14. Numeric balance/timing values explicitly labeled as tuning or playtest variables remain tunable and are not frozen merely by resolving the mechanic.

---

# 55. Change Request Log

Use this format for any future change to a locked requirement:

```text
CHANGE REQUEST:
Current requirement:
Requested change:
Reason:
Systems affected:
Art impact:
Code impact:
QA impact:
Schedule impact:
Decision: APPROVED / REJECTED / TBD
```

---

# 56. Prototype Success Criteria

The prototype succeeds if it demonstrates:

1. stable top-down movement and mouse-aim combat;
2. one complete protagonist with side-only 32×32 animation;
3. a playable authored Region 3 hub/overworld with a readable central tower landmark;
4. separate World Map and Region Map flows;
5. permanent Tower Sigil quest unlock and safe floor-selection teleport menu;
6. selectable Melee/Ranged/Mage class paths;
7. class-appropriate resource handling;
8. readable separate weapon rendering;
9. 10 functional procedurally generated tower floors;
10. valid quest-aware procedural generation;
11. 10 main floor objectives plus the target side-quest set and the regional main-story packaging approved under DR-03;
12. escort, tower-defense, and annihilation quest flows;
13. level and gear progression to Level 10;
14. Danger/Recommended Level system with underleveled entry for floors and regional hostile zones;
15. inventory, loot, shop, and gear upgrade loop;
16. enemies demonstrably more capable than chase-and-hit mobs;
17. fair AI with no raw-input cheating;
18. reliable encounter concurrency and AI performance;
19. at least one strong multi-phase Floor 10 boss encounter;
20. reliable save/checkpoint/death progression;
21. readable HUD/UI at 720p and above;
22. stable 60 FPS target behavior on intended hardware where possible, with 25 FPS as minimum acceptance floor;
23. repeatable QA evidence and regression validation.

Status: `LOCKED FOR PROTOTYPE`

---

# 57. Hard Non-Negotiables

Unless explicitly changed by approved Change Request:

- Do not add weak/stupid filler mobs.
- Do not create difficulty by reading raw player inputs.
- Do not remove meaningful enemy recovery/telegraph windows.
- Do not add random major features.
- Do not silently resolve major canon/design ambiguity.
- Do not change the game away from quest-driven tower progression.
- Do not hard-lock a discovered/unlocked floor purely because the player is under the Recommended Level.
- Do show danger warnings for underleveled floors.
- Do not require front/back player body sprites in the prototype.
- Keep the player body side-only and weapon/attack aiming independent.
- Do not inflate sprite detail beyond the approved 32×32 presentation.
- Do not blur pixel sprites through accidental texture filtering.
- Do not visually swap every gear item onto the player.
- Do not add jumping, swimming, crouching, or rolling.
- Do not implement multiplayer in the prototype.
- Do not expand prototype implementation beyond Region 3 into the other 11 Luminar regions.
- Do not runtime-regenerate the approved Region 3 town/quest-critical map without a validated map revision.
- Do not allow the Tower Sigil to bypass locked story progression or teleport during active combat.
- Do not implement full alchemy/cooking/crafting in the prototype.
- Do not require mod support in the prototype.
- Do not claim a system is complete without executable evidence.
- Do not let floor population budgets become simultaneous full-AI crowd counts.
- Do not sacrifice combat readability for decorative VFX.
- Do not allow critical quest items to be permanently destroyed or lost.

---

# 58. Decision Register and Intentional TBDs

DR-01 through DR-08 below are **RESOLVED AND APPROVED** as of 2026-09-14 by direct developer instruction. The approved-resolution paragraphs are authoritative; the older conflict/options text is retained only as decision history. Numeric values explicitly described as tuning/playtest variables remain adjustable without reopening the resolved mechanic.

## DR-01 — Revisit, retry, regenerated floors and rewards — RESOLVED

**Approved choice: A — persistent revisits with coherent failed-attempt rollback.** The prototype has one persistent generated instance per save/floor. Ordinary revisits preserve the seed/layout, defeated normal enemies/elites/boss, quest state, opened/claimed sources, loose-item identity, vendor state and one-time rewards. Cleared floors may be revisited for navigation, remaining unclaimed content and story/service purposes, but they do **not** regenerate combat or become renewable farms.

**Retry/reset matrix:** ordinary revisit = preserve current committed floor state; failed attempt retry = restore the latest committed safe/attempt snapshot for that floor and the profile state coherently associated with it; player-triggered fresh floor reset/regeneration = **not supported in the prototype**. A failed retry never chooses a new seed. Rewards, purchases, consumptions, claims, enemy outcomes and quest-attempt changes after the restored snapshot roll back together so inputs cannot be restored while derived value is retained. Bosses and ordinary enemies do not respawn merely because the floor is re-entered. Any future repeatable challenge mode is a post-prototype feature with its own reward budget and is not implied by replay.

**Conflict:** §§14/15 allow retries and replay of cleared floors; §19 prohibits ordinary enemy respawning. The source does not say whether “replay” restores combat, changes geometry, or repeats rewards.

- **A — Persistent revisits with bounded failed-attempt rollback.** One generated instance per save/floor. Ordinary revisits retain geometry, defeated residents, claims and completed quests. Retry restores an authored attempt snapshot, reversing its rewards/spending with its source. Cleared floors are revisitable, but not automatically a renewable combat farm.
- **B — Repeatable challenge runs.** Explicit fresh/reset instances restore enemies and specified repeatable rewards while preserving campaign clear/unlock flags. This requires an approved exception to the no-normal-respawn rule and a new repeat-economy budget.
- **Recommendation:** A for the prototype's finite economy and reliable quest/checkpoint references. If the developer intends replay to mean fighting a cleared floor again, choose B explicitly rather than presenting A as equivalent.
- **Previously blocked — now unblocked by the approved choice above:** floor instance reset/re-entry policy, completed-boss replay, reward repetition, retry reset sets and final finite-source economy.
- **Required approval record:** for enemies/elites/boss/summons, quest actors, timers/objectives, loose loot/chests, vendor stock, seed/layout and rewards, state exactly what ordinary revisit, failed retry and explicit reset preserve. Specify how attempt rollback handles transactions whose items, funds or effects were subsequently consumed outside that attempt: include dependent results in the reset set or use a coherent retry boundary. Never restore inputs while retaining their derived value.

## DR-02 — Death retention and checkpoint restoration — RESOLVED

**Approved choice: A — coherent whole-state rollback, with no death fee.** Death restores the latest fully committed safe snapshot and relocates to that snapshot's valid checkpoint/death anchor. Everything committed after that snapshot is rolled back together: HP/resources/cooldowns, consumables, inventory/equipment changes, gold/XP/skill-point state, purchases/upgrades, enemy outcomes, loot/claim state and quest-attempt progress. Nothing earned after the snapshot survives while its source is restored.

Manual load returns to the saved safe location represented by the loaded snapshot. Autosaves/checkpoints only count if a complete coherent snapshot was actually committed. Simultaneous player/boss defeat is resolved as player death/failure: no boss-clear flag or boss-clear reward is committed, then the safe snapshot is restored. There is no added currency loss, durability loss or death tax.

**Conflict:** “respawn at latest valid checkpoint/save state” does not specify whether earned/spent state since that snapshot survives death.

- **A — Coherent whole-state rollback.** Restore the latest committed safe snapshot, use its valid death anchor, and roll back all later rewards, spending, enemy outcomes and quest-attempt changes together.
- **B — Retain progress and relocate.** Keep earned/spent persistent state and respawn at the checkpoint; explicitly reset selected encounter/quest state without duplicating claims or making depleted attempts impossible.
- **Recommendation:** A, with no added death fee. Restore saved resources/cooldowns consistently. Manual load returns to the saved safe location; death uses the saved checkpoint anchor. For simultaneous player/boss defeat, treat the attempt as death/failure and restore the snapshot without a new boss-clear reward.
- **Previously blocked — now unblocked by the approved choice above:** death/retry retention, boss/player simultaneous defeat, recovery values and post-death economy validation.
- **Required approval record:** what happens to unbanked XP/gold/loot, consumed items, purchases, completed stages, enemies and branch flags. Autosaves only count when the complete safe snapshot was actually committed.

## DR-03 — Regional main story versus 15 quest definitions — RESOLVED

**Approved choice: A — exactly 15 quest definitions with regional stages.** The prototype contains exactly ten primary definitions and five side definitions. The Floor 1 primary definition begins with the Region 3 regional-story/preparation sequence, includes Tower Sigil acquisition and Floor 1 access authorization, and then continues into the Floor 1 primary objective; this does not create a sixteenth quest definition. Other primary definitions may contain regional context/turn-in stages without changing the count.

**Initial prerequisite chain:** completing the required Region 3 story/preparation stage atomically grants the permanent Tower Sigil and the initial Floor 1 unlock. Physical Floor 1 entry and Sigil travel are unavailable before that stage is committed. The five side definitions are distributed across Region 3 and the tower. Travel/talk/service stages remain stages inside the three approved quest families rather than creating another family.

**Conflict:** §14 approves 10 primary floor objectives + 5 side quests = 15 definitions; §24 additionally requires Region 3 main-story content and Sigil acquisition.

- **A — Fifteen definitions with regional stages.** The Floor 1 primary definition starts with Region 3 story/preparation/Sigil stages and ends with its floor objective. Other main definitions may contain regional turn-in/context stages. Five side definitions are distributed across Region 3/tower.
- **B — Separately counted regional prelude.** Add one Region 3 main definition before the ten floor definitions, retaining five side quests: 16 definitions total. Further regional main definitions require an explicit new count.
- **Recommendation:** A to preserve the existing total and reduce production work. “Regional content in addition to floor content” need not mean an extra definition if approved this way.
- **Previously blocked — now unblocked by the approved choice above:** final quest manifest count, prelude packaging and the initial Floor 1/Sigil prerequisite chain. Physical Floor 1 access does not predate the committed stage that grants the permanent Sigil and initial floor unlock.
- **Both options preserve:** regional main/side gameplay, all ten primary floor objectives and the three approved quest families. Travel/talk/service stages do not establish a fourth family.

## DR-04 — Starter weapons, basic attacks, depletion and defenses — RESOLVED

**Approved choice: A — minimal renewable starter kits with no basic-attack softlock.** Melee starts with a one-handed sword plus shield; Ranged starts with a two-handed bow and empty off-hand; Mage starts with a two-handed staff and empty off-hand. Bow and staff do not permit an off-hand item while equipped. All three classes have a resource-free basic attack, so the player always retains a usable combat action.

Ranged uses no tracked ammunition or ammunition inventory in the prototype. Mage has the only mana bar: mana-spending active magic starts a configurable regeneration delay, after which mana recovers over time even during combat unless another mana-spending action restarts the delay. Stamina remains the shared movement/defense resource: running/dodge use it; Melee shield block/parry and declared Melee/Ranged stamina skills may use it. Melee's starter shield supports directional block/parry. Ranged and Mage starter kits rely on dodge and have no baseline block/parry; a learned Mage ward may later provide its explicitly authored defensive window. Exact timings/costs/rates are tuning data, not new design decisions.

**Conflict:** the class paths, HP/stamina and Mage mana are approved; exact starter weapons, basic-attack costs, ammunition/recovery, and which equipment supports block/parry are not.

- **A — Minimal renewable basic-attack kit.** Melee sword/shield; Ranged bow without tracked ammo; Mage staff with a resource-free Arcane basic bolt. Stamina funds mobility/defense and declared Melee/Ranged skills; Mage active magic spends mana with delayed time-based recovery. Melee shield supports block/parry; Ranged/Mage starter kits use dodge without block/parry. No universal mana, ammo, or extra resource bar.
- **B — Resource-consuming basics and broader defensive access.** Approve a concrete stamina/ammo/mana model for basic attacks, guaranteed replenishment, and equipment/skill-supported defenses for each class. Consumable ammo and out-of-combat-only mana recovery materially alter expedition pressure and finite economy requirements.
- **Historical recommendation:** A was preferred for the first playable kit because it tests class identity with fewer softlock and supply dependencies; it is now the approved choice above.
- **Previously blocked — now unblocked by the approved choice above:** production starter kits, basic-attack resource rules, mana recovery behavior and class-specific defense tutorials. The approved prototype has no ammunition UI/stock.
- **Either option must specify:** startup/commit/recovery and aim behavior, costs and recovery conditions, range/collision, supported off-hand, valid defense actions, and a clear exhausted-resource route.

## DR-05 — Skill pool, initial loadout, progression and temporary skills — RESOLVED

**Approved choice: B — bounded build choices.** Each class has exactly three active and three passive prototype skills, can equip any learned two actives plus two passives, and may change that learned loadout only at safe town/rest interactions while not in Active Combat. Progression spending is permanent; there is no respec in the prototype. Every skill has three ranks. Rank 1 unlocks/activates the skill; ranks 2–3 improve only authored magnitude/cost/recovery values without changing the skill's identity. Each rank costs one skill point. The two starting actives and two starting passives listed below are granted at rank 1; each alternative begins locked and is learned at rank 1 by spending one skill point.

| Class | Starting actives | Alternative active | Starting passives | Alternative passive |
|---|---|---|---|---|
| Melee | **Arc Cleave** — wide committed melee sweep; **Driving Thrust** — narrow advancing strike | **Riposte** — counter available only after a successful supported parry | **Efficient Footwork** — improves authored stamina efficiency; **Breaker** — increases poise pressure | **Parry Recovery** — successful parry grants an authored recovery benefit |
| Ranged | **Piercing Shot** — committed line shot that may pierce authored targets; **Fan Shot** — short spread sequence | **Backstep Shot** — authored evasive movement plus committed shot | **Longshot** — improves authored long-range effectiveness; **Fleet Recovery** — improves movement/recovery efficiency | **Expose** — improves authored visible weak-point payoff |
| Mage | **Arcane Lance** — focused Arcane projectile; **Delayed Pulse** — telegraphed delayed area hit | **Aegis Ward** — brief mana-spending defensive window using DR-06 block-style semantics without parry | **Mana Weave** — improves authored mana efficiency; **Flow Recovery** — improves mana recovery behavior | **Stable Casting** — improves authored casting/recovery efficiency without removing commitment |

Temporary combat skills occupy one active slot and store the displaced learned skill ID plus slot index. While a temporary skill is active, that slot cannot be manually remapped. When the temporary skill ends, the stored learned skill is restored deterministically. Temporary skills never spend permanent skill points and do not alter learned-skill ownership. Exact magnitudes, cooldowns, timings and rank scaling remain tuning values.

**Conflict:** two active/two passive equipped slots, trees/unlocks/ranks and no respec are approved; the actual skill roster, selection pool and slot-changing rules are not.

- **A — Fixed small kit.** Two actives and two passives per class, all initially usable, with rank upgrades but no alternative skills competing for slots.
- **B — Bounded build choices.** Three actives and three passives per class; start with two of each and unlock alternatives. Equip any learned 2+2 only at safe town/rest interactions; spent progression is permanent. Temporary combat skills replace one active with a stored restoration record; contextual noncombat verbs use Interact.
- **Recommendation:** B, because it gives the skill tree an actual build choice. Its additional six class skills across the three classes must be included in the production estimate.
- **Historical role palette that informed the approved skill identities above:**

| Class | Active-role candidates (3) | Passive-role candidates (3) |
|---|---|---|
| Melee | Committed cleave; advancing thrust; counter after a successful supported defense. | Stamina efficiency; poise pressure; recovery benefit after a successful parry. |
| Ranged | Piercing line shot; evasive shot with explicit commitment; short spread sequence. | Range specialization; movement/recovery benefit; exposed weak-point specialization. |
| Mage | Focused Arcane lance; delayed area pulse; brief defensive ward. | Mana efficiency; recovery specialization; casting/commitment specialization. |

These historical role candidates are superseded by the named approved skill set above. They do not authorize extra resource/status systems; the approved ward/counter/evasive skills use DR-06 semantics.
- **Previously blocked — now unblocked by the approved choice above:** final skill implementation, rank progression, starting coverage, learned-skill swapping and temporary-skill restoration.
- **Required approval record:** exact effects and dependencies, not just names. Timing/cost/magnitude numbers may remain tunable once the mechanics are approved.

## DR-06 — Shared defense, damage, weak-point and status semantics — RESOLVED

**Approved choice: A — one small readable shared ruleset.** Direct attacks declare explicit `dodgeable`, `blockable` and `parryable` eligibility; authored warnings communicate unblockable/unparryable threats rather than relying on hidden exceptions. Dodge ignores a hit only during its authored evade window and only when that hit is dodgeable.

**Block:** only supported defenses may block. A block succeeds only against a blockable hit inside the defender's authored frontal coverage. A successful block deals zero HP damage and instead applies authored stamina/guard pressure. If the defender lacks the stamina required to absorb the hit, stamina becomes zero, guard break is triggered, and that hit resolves to HP damage normally. Block coverage angle and stamina costs are tuning data.

**Parry:** only explicitly parryable melee/contact attacks may be parried during one authored parry window and inside valid facing coverage. Successful parry negates that hit and triggers the attacker's authored parry-interrupt/recovery response. Prototype projectiles are not parried or reflected. There is no perfect-parry tier.

**Damage/mitigation:** damage domains are Physical and Arcane. For a positive direct hit, first apply the single chosen offensive multiplier, then mitigation: `mitigated = raw_after_bonus * 100 / (100 + max(0, applicable_mitigation_rating))`. Round to the nearest integer with .5 upward and clamp a successful damaging hit to at least 1 HP. Non-damaging results remain 0. Physical Defense mitigates Physical; Arcane Defense mitigates Arcane.

**Critical/weak point:** direct-hit critical chance and multiplier are authored data. Weak points are visible authored exposure regions/states with their own bonus multiplier. If one hit is both critical and weak-point eligible, use the **greater** of the two bonus multipliers; never multiply them together. Damage-over-time ticks cannot crit or weak-point.

**Poise:** attacks may deal authored poise damage. Reaching the target's poise threshold triggers its authored interruption/recovery if that state is interruptible, then resets accumulated poise. Poise recovery delay/rate and thresholds are tuning data; guard break is a separate defense outcome.

**Prototype statuses:** exactly two initial shared status behaviors are authorized: **Burn** (damage over time) and **Slow** (movement-speed reduction only; it does not alter action clocks or AI reaction timing). Reapplying the same status never sums magnitude: keep the strongest magnitude and refresh remaining duration to the greater of current remaining duration or the new authored duration. Different status IDs may coexist. No elemental matrix, projectile-reflect subsystem or hidden stacking tier is introduced.

**Conflict:** §17 approves these systems but leaves materially different possible rules for chip damage, directional blocking, parry eligibility, poise, mitigation and crit/weak-point stacking.

- **A — Small shared readable rule set.** Directional block where supported; zero HP chip on successfully blockable hits but stamina pressure and guard break; single-window parry only for tagged attacks; attack-specific dodgeable/unblockable/unparryable warnings; poise threshold triggers authored interruption/recovery. Physical/Arcane mitigation uses one documented calculation with data-defined ratings. Weak points are visible authored exposure regions/states, and use the greater of weak-point/critical bonus rather than multiplying both. Start status content with one damage-over-time effect and one slow using declared strongest/refresh rules.
- **B — Attack/category-specific defense rules.** Add differentiated chip/penetration, broader projectile deflection, multiplicative weak-point/crit rewards and more stacking exceptions. Requires a larger authoring and QA matrix.
- **Recommendation:** A. Example first-pass mitigation formula: damage after mitigation = raw damage × 100 / (100 + nonnegative applicable mitigation rating), with explicit rounding/minimum rules; all magnitudes are `[INITIAL TUNING HYPOTHESIS]`, not approved balance.
- **Previously blocked — now unblocked by the approved choice above:** complete damage/defense implementation and enemy/skill balance beyond isolated test fixtures.
- **Required approval record:** block facing/coverage, attack tags, parry result for melee/projectiles, guard-break/poise recovery, crit chance/bonus policy, visible weak-point eligibility, status stacking/reapplication, hazard interaction with dodge and bounded knockback. No elemental matrix or perfect-parry tier is introduced.

## DR-07 — Floor 10 boss encounter identity — RESOLVED

**Approved choice: A — adaptive duelist milestone.** The prototype Floor 10 boss's working gameplay-canon encounter name is **The Tenth Warden**. Narrative true name/origin may remain a later lore decision; the gameplay identity and mechanics are fixed here. The fight has exactly **two phases**, no mandatory adds and no healing/reset between phases. The three required Floor 10 elites remain outside the boss encounter.

**Phase 1 (100% to 50% HP):** teach five readable move families: (1) **Twin Cut**, a close committed two-hit melee string; (2) **Warden Lunge**, a telegraphed straight advancing strike; (3) **Arc Volley**, a telegraphed ranged pressure sequence that is dodgeable/blockable but not parryable; (4) **Crescent Sweep**, a wide positional sweep that is unblockable but dodgeable; and (5) **Punishing Step**, a short reposition-and-strike used only when the player's positioning creates the authored condition. These moves use the common DR-06 tags and normal commitment/recovery rules.

At 50% HP or below, after the current committed action finishes recovery, the boss performs one non-damaging irreversible phase-transition action. Phase 2 recombines the same learned move families with authored follow-ups and tighter recovery without introducing a new hidden ruleset. Heavy committed Phase-2 actions expose one clearly visible weak point during their authored recovery window; the weak point uses normal DR-06 weak-point semantics. The arena is a fixed Boss Sanctum with readable boundaries, no pits, no shrinking walls and no unavoidable ambient damage. The boss is one FULL-AI combatant and all global combat/pressure caps still apply.

Victory commits only when the boss defeat is valid while the player remains alive. Simultaneous player/boss defeat follows DR-02 and is a failed attempt with no clear reward. HP values, the exact 50% transition threshold if playtest adjustment is needed, telegraph lengths, follow-up probabilities, cooldowns, weak-point duration and damage numbers are tuning values; phase count, move-family identities, no-add rule and fairness semantics are not.

**Conflict:** one multi-phase boss in Boss Sanctum is approved, but its mechanical encounter is not authored. Choosing the climax's behavior is consequential creative design.

- **A — Adaptive duelist-style milestone.** One boss using readable close-range commitments, a ranged pressure pattern and positional punish behavior, with a second phase recombining learned patterns and a visible weak-point opportunity. Stage the three required floor elites outside the boss fight; no mandatory boss adds.
- **B — Command/arena-control milestone.** Boss coordinates bounded adds and arena hazards, with objective/space control carrying more of the difficulty. Uses the same global actor/pressure cap.
- **Recommendation:** A to prove the combat/AI pillars with lower production and readability risk. Phase count/thresholds, move timing and statistics are `[PLACEHOLDER — PLAYTEST]` until authored and tested.
- **Previously blocked — now unblocked by the approved choice above:** boss implementation, phase behavior, arena production and full Floor 10 acceptance.
- **Canon status after resolution:** the gameplay encounter identity/title **The Tenth Warden** and its mechanics are approved. Its true personal name, motive and relationship to tower origins remain narrative TBD and are not required to implement the prototype milestone.

## DR-08 — Minimum hardware and measurable performance floor — RESOLVED

**Approved choice: A — named integrated-GPU minimum.** Minimum supported Windows x64 reference configuration for final prototype acceptance: **Intel Core i5-8250U (4C/8T) or equivalent, Intel UHD 620-class integrated graphics or equivalent with OpenGL 3.3 support, 8 GiB system RAM, SSD storage, Windows 10/11 x64, `gl_compatibility`, 1280×720 output at 60 Hz**. This is the minimum acceptance class, not the current developer machine. The existing Lenovo 82H7 / i5-1135G7 / Iris Xe / ~16 GiB machine remains a separate developer/reference-performance machine.

**Benchmark protocol:** use an exported non-editor build after a 60-second warm-up; then record at least 10 continuous minutes of a deterministic `QA-PERF-WORST` gameplay route at 1280×720. The route must include the prototype's maximum 12 FULL-AI combatants across overlapping encounters where valid, representative navigation/AI, projectiles/VFX, foreground occlusion, UI, audio load and a representative boss-pattern segment. Scene loads/intentional loading screens are measured separately and are not mixed into steady-state gameplay percentiles.

**Steady-state acceptance on the minimum configuration:** target 60 FPS remains the design goal; median frame time `p50 <= 16.67 ms`; `p95 <= 25 ms`; `p99 <= 33.33 ms`; frames slower than 40 ms must be <= 0.5% of measured gameplay frames; no steady-state gameplay frame may exceed 100 ms; and no rolling one-second gameplay window may average below 25 FPS. Any reproducible sustained breach of the 25 FPS floor fails acceptance. These are final prototype performance criteria; higher-end/reference-machine measurements are evidence but cannot substitute for a run on the minimum class.

**Conflict:** 60 FPS target/25 FPS minimum are approved, but the minimum Windows machine and percentile/stall criteria are unspecified.

- **A — Named integrated-GPU baseline.** Select an actual modest Windows x64 machine and record CPU/GPU/RAM/driver/API/storage/output settings.
- **B — Named discrete-GPU baseline.** Define a higher minimum machine and acknowledge the changed hardware target.
- **Historical recommendation:** A was selected and is now approved above. The current developer/reference machine remains separate from the approved minimum acceptance class.
- **Previously blocked — now unblocked by the approved choice above:** final performance acceptance and minimum-support certification. Actual final acceptance still requires executing the approved benchmark on the minimum-class machine after representative content exists.
- **Required approval record:** named benchmark configuration, worst-case scene/run length and acceptable frame-time percentile/hitch thresholds. Preserve the declared 60 FPS target and 25 FPS floor.

## Intentional TBD — not blockers for prototype foundations

**Narrative canon — TBD — DEVELOPER DECISION:** exact tower origin, destruction mechanism, antagonist, factions, detailed history/themes of Luminar, final ending, exact wish rules and sequel canon. No faction/history is inferred from region numbers, visual themes, architecture or temporary names.

**Long-term multiplayer — LONG-TERM APPROVED direction; details TBD:** co-op/PvP model, player count, host/server ownership, matchmaking, quest sync, loot ownership, saves, anti-cheat and latency behavior. No prototype networking.

**Long-term content — TBD:** gameplay/lore for Regions 1–2 and 4–12; inter-region travel method/quests; floors above 10; final Floor 100 and multi-boss structure; future characters/switching; class respec; extra quest families.

**Deferred / optional:** advanced crafting/alchemy/cooking/dismantling, voice acting, achievements/platform integration, telemetry service choice, modding, monetization/storefront/release model. Specific gameplay accessibility assists beyond the required presentation/input features need explicit settings/ranges before implementation.

**Art production TBD:** final controlled palette, licensed assets, approved regional dressing and names. The placeholders in this document may guide greybox work; they do not establish canon or create final assets.

---

# 59. Implementation Plan

This is the active dependency plan for the authorized implementation phase. Production code, scenes, tests and evidence are now being developed incrementally; every dependent slice must follow the approved §58 resolutions and its observable exit gate.

| Milestone | Scope and ownership | Depends on | Observable exit gate |
|---|---|---|---|
| M0 — Contract/data baseline | Pin exact Godot stable build; basic project/input/display configuration; stable IDs and minimal save schema; data validation boundaries. | Current specification. | Boot/build works; tiny profile round-trips; no production claim beyond executable evidence. |
| M1 — Movement and presentation | WASD, aim, side-only body facing, separate weapon/grip ordering, collision, dash/dodge, stamina, camera. | M0 | Cursor/zoom/occlusion tests and responsive movement pass using temporary art. |
| M2 — Combat and class foundation | Action phases, input ownership/buffer, legal cancels, damage/defenses, resource transactions; one playable starter kit per class. | M1; DR-04/06; DR-05 for real skill content. | Each class completes the same controlled encounter; exhausted-resource behavior is valid. |
| M3 — Intelligent enemy slice | HSM/utility/patterns/perception/memory/blackboard; 3–4 distinct archetypes first. | M2 | Observation/reaction/commitment/cap traces and readable counterplay pass. |
| M4 — Quest and retry contracts | All three approved families in authored test spaces; progress/leave/claim transactions; escort navigation; save/death boundaries. | M2–3; DR-01/02/03; DR-05 temporary-skill rule if used. | Fail/retry/load/leave tests pass for each family before generation depends on them. |
| M5 — Region 3 loop and tower access | Authored town/region greybox, required service anchors, 20-structure manifest, main/side quest staging, three map layers, Sigil and physical entry. | M4; regional prelude packaging DR-03. | Prepare → accept → encounter → turn in → acquire/use Sigil → safe return is coherent. |
| M6 — Quest-aware tower generation | Authored modules and sockets, critical paths, seeded manifests, finite retries/fallback, safe arrivals, encounter activation. | M3–5 and frozen quest/generation contracts; DR-01. | All three quest families work on valid generated/fallback floors without impossible objectives. |
| M7 — Progression and economy | XP/stat/skill growth, equipment/affixes, 16-slot inventory/storage, loot, shops and upgrades, danger warning integration. | M2/M4/M6; DR-01/04/05/06. | Finite route, poor-drop, capacity and transactional reward tests pass; underleveled entry works. |
| M8 — Escalation and complete content | Extend to all 10 floors, 12 archetypes, required Floor 5/10 elites, approved quest count, multi-phase Floor 10 boss. | M3/M6/M7; DR-07. | Complete run through the approved content with all three classes; no placeholder objective gaps. |
| M9 — Presentation, accessibility and persistence closure | Complete required animations, art/audio/VFX, UI/settings/tutorial and save compatibility; integrate throughout earlier milestones. | M1–8; approved assets and content. | All required flows readable and restorable; no identity-color drift or lost quest state. |
| M10 — Profile and independent QA | Fixed-step/low-FPS behavior, worst-case encounter/generation/save/UI tests and evidence review. | All prior gates; DR-08 for final hardware acceptance. | §56/§61 coverage complete with reproducible build evidence and no unresolved release-blocking defects. |

Do not postpone persistence architecture until content completion: IDs, reward claims and safe snapshots start early and are tested with quests/generation. Likewise, placeholder UI/telegraphs are necessary to judge combat from M1 onward; “polish later” does not mean “feedback later.”

The desired 2–3 weeks is an aspiration with substantial content risk: 18 required body actions, three class kits/trees, 12 enemy archetypes, ten floors, three quest families, regional services and a boss remain real production work. Reuse modules/roles and validate small slices before expansion. Measure throughput after M3/M4; estimate the remaining work then.

If capacity is insufficient, present a concrete tradeoff to the developer: extend the schedule, reduce optional dressing/vendor/secret-room variations, or approve a named content-target change. Do not silently drop locked classes, structures, quests, animations, floors, archetypes or enemy quality.

Later subagent ownership should be narrow: movement/presentation, combat/resources, AI, quests/persistence, generation/Region 3, economy/build progression, and technical-art/audio/QA. Each task cites its contracts, dependency inputs and acceptance IDs. One integration owner controls shared state/transaction changes; specialists cannot independently redefine the master.

---

# 60. Authority and Handoff Rule

Current direct task/developer instructions and approved change requests take precedence. Otherwise preserve explicitly approved decisions in this master, apply constrained contracts defined here, and escalate consequential gaps through §58 while continuing independent work.

This specification is authoritative for the Nice Journey design within its stated status boundaries. Recommendations, unresolved choices, tuning values and placeholder canon do not become approved merely because they appear in this file.

**Current handoff state:** implementation is active. DR-01 through DR-08 are resolved, so their dependent milestones are no longer decision-blocked; work still proceeds in dependency order with executable Dev→QA evidence, and tunable values remain subject to playtest where the resolved contracts say so.

---

# 61. System Acceptance and Observability Matrix

All evidence below is required for the active implementation and final acceptance. A listed requirement is not automatically a pass claim: every accepted artifact records build/engine/renderer, content versions, scenario ID, relevant seed/instance, steps, expected/actual result and capture/log where appropriate.

| Scenario ID / system | Required observable test | Pass condition |
|---|---|---|
| QA-MOVE — movement/aim | Cardinal/diagonal movement, corners, blocked dash/dodge, climb landing, full aim sweep and vertical dead zone. | No speed bonus, wall penetration, stuck landing, flip chatter, reversed projectile or body-scale change. |
| QA-ACT — actions/cancel | Queue dodge/parry during commit; test startup/recovery cancels and input expiry; repeat contacts; force interruption/death. | Only authored transitions occur; one cost/hit where specified; animation priority never grants cancellation. |
| QA-TICK — timing | Reproduce tick-stamped inputs at 25/30/60/high render FPS; test defense interval boundaries ±1 tick, pause, hit-stop and injected stalls. | Same simulation outcomes within declared determinism scope; backlog/stalls reported; no false readability claim. |
| QA-CLASS — class/resources | Use each approved starter kit; deplete all relevant resources; swap allowed equipment; cast/use skills; fail interrupted actions. | Correct bars/costs/recovery; no resource softlock, duplicate charge, equip-refill exploit, universal mana or invented defense. |
| QA-SKILL — progression | Unlock/rank/equip, reject invalid prerequisites, grant/remove temporary skill through complete/fail/abandon/load. | Exactly supported slots, preserved permanent spend, correct restoration, no duplicate grant. |
| QA-AI — fair intelligence | Observe healing/casting; hide then change direction; repeat then vary a habit; test cooldown/action locks. | Trace identifies cue/time/delay/confidence; no raw input/unseen live tracking; bounded memory and recoveries remain. |
| QA-GROUP — coordination | Simultaneous attack choices, interrupted reservation owner, summons and adjacent pursuers at cap. | Atomic admitted commitments; no leaked reservations; ≤12 engaged full-AI actors; pressure/readability budget honored. |
| QA-DANGER — warning/access | Deficits 0/1/2/3/4/5; equipment changes; boss warning; safe/hostile zone changes; locked vs underleveled destinations. | Exact locked rank table; separate content warnings; no hidden debuff or level gate; III–V confirmation permits travel. |
| QA-REGION — authored map | Count structures/interiors; traverse all services/routes/quest anchors; revisit after tower/save/load; inspect main tower sightlines. | 20 identities, 8 functional and 12 decorative; stable Region 3 coordinates/revision; no other playable region. |
| QA-MAPS — navigation/UI | Switch World/Region/Tower views, inspect discovered/unknown state, danger markers and eligible travel. | Separate correct map data; other 11 regions are future placeholders; map markers cannot bypass access rules. |
| QA-GEN — procedural validity | Repeat full generation tuple; validate accepted quest combinations; force candidate/fallback failure; inspect escort/defense/boss paths. | Same structural manifest; all required predicates reachable; valid compatible fallback or safe noncommit; never partial floor exposure. |
| QA-QUEST — quest family/state | Complete/fail/retry all families; duplicate objective event; finite target killed before acceptance; timer pause/load; branch continuation. | Required actor/group semantics, visible progress, valid retry and deterministic flags; no permanent progression dead end. |
| QA-ESCORT — movement/leave | Block an NPC-sized passage, separate/rejoin, traverse a gate, teleport request/cancel/confirm and save if supported. | Honest wait/repath/failure handling; declared departure rule; no silent NPC teleport or lost actor. |
| QA-TRAVEL — Sigil/arrival | Full inventory Sigil grant; select cleared/unlocked/locked floor; invalidate arrival; combat begins before commit. | Permanent protected Sigil, shared eligibility, no active-combat travel, valid fallback entrance or retained source state. |
| QA-REPLAY — revisit/reset | Revisit clear; retry failure; re-enter partial floor; test seed/enemy/loot/vendor/quest changes. | Exactly the approved DR-01 matrix; no unapproved respawn, reroll, repeated reward or lost campaign clear. |
| QA-ECON — inventory/loot/shops | Poor drops, no optional vendor, full grid/storage, capped stacks, repeated buy/upgrade clicks, interrupted transaction. | Valid finite progression; no partial deduction/duplicate ownership; preserved affixes and pending quest rewards. |
| QA-SAVE — persistence | Interrupt every write stage; load each slot after major transitions; reject incompatible content; corrupt newest generation in test. | Complete new or prior valid state; independent slots; protected items/claims/quest bindings/arrivals valid. |
| QA-DEATH — checkpoint | Die after spending/looting/quest change; fail escort; simultaneous boss/player death. | Approved DR-02 retention/tie outcome applied coherently; no reward restored with its unclaimed source. |
| QA-BOSS — climax | Each class completes approved phases; inspect telegraphs, arena egress, elite/add staging and post-clear state. | Fair viable responses, cap compliance, Floor 10 complete; no Floor 11/final wish/final-ending implementation. |
| QA-PIXEL — visual identity | Compare all body frames, aim angles, occlusion, extreme light/effects, 720p/1080p/1366×768/ultrawide, every zoom. | Stable palette/source pixels, body scale/grip/sorting, crisp supported scaling, clear actual attack cues. |
| QA-ACCESS — UI/accessibility | Rebind/conflicts, largest UI/text scale, flash/shake/motion reduction, color-independent information, sound-off/mono tests. | All required controls/content readable; no hidden input pass-through or new difficulty/AI changes. |
| QA-AUDIO — audio lifecycle | Maximum admitted encounter SFX, repeated combat/boss transitions, pause/load/unload and cue overlap. | Critical cues retain priority, aggregate budget observed, no leaking loops or duplicate music. |
| QA-PERF — performance | Recorded DR-08 machine and repeated worst-case scenes; transitions, memory, frame times, physics backlog and active counts. | Approved measurement thresholds met with honest frame-time/hitch evidence; no readability/AI cuts disguised as optimization. |
| QA-SCOPE — production boundary | Compare delivered manifest to locked content and out-of-scope list. | Approved counts/requirements preserved; no other-region gameplay, speculative networking, full crafting or fabricated canon. |

## 61.1 Required debug views

Expose readable player action/phase, remaining resource/cooldown, allowed cancel, aim lock, attack/target ID, hit/defense result, and current combat guard reason. AI inspection shows observed facts with timestamps/confidence, tactical/action state, top eligible utility choices, suppression reason, memory summary and group reservations.

Quest inspection shows definition/attempt/instance IDs, state, objective bindings/counters, failure/leave policy, claimed reward transaction and relevant flags. Generation inspection shows the reproducibility tuple, selected modules/connectors, reserved sockets, validation failures and fallback choice. Save inspection shows supported safe-state reason, queued/committed snapshot sequence and compatibility/claim validation.

Diagnostics are development-only and bounded. No online telemetry, personal data collection, external account, or free-form LLM memory is necessary for these tests. Screenshots/video support visual judgments; logs alone cannot prove combat feels fair or pixel art is readable.

## 61.2 Cross-system invariants

- A level warning never becomes an access gate or hidden damage modifier.
- Animation, lighting, camera and UI never own authoritative combat or inventory outcomes.
- A reward and its source cannot both remain claimable after retry/load/death.
- Procedural state and quest bindings always refer to the same committed instance/version.
- Sigil possession survives inventory pressure and all ordinary quest-item operations.
- Nonportable quest state has an explicit leave/save/retry policy before travel is permitted.
- Every counted enemy can threaten through fair authored behavior; simulation culling is never permission for a hidden attacker.
- Region 3 remains authored; procedural tower generation never becomes procedural story canon.
- Future multiplayer separation never requires network code in the single-player prototype.

---

# 62. Tuning Register and Director-Pass Audit

## 62.1 Tuning ownership

Approved content/structure counts remain commitments: 10 floors, Level 10 cap, 20 town structures/8 functional/12 decorative, 12 enemy archetypes plus one boss, three class choices, five equipment slots, 16 normal inventory slots, stack 99, four consumable slots, two active/two passive slots, three save slots, 50×50 floor limit and 32 px source tile/body targets. A numerical value is not automatically a hypothesis when the developer explicitly locked it.

Combat magnitudes, timings, XP/stat growth, drop probabilities, affix ranges, prices, recipe costs, reaction/memory delays, attack pressure slots, recommended regional borders/size and performance estimates are **not validated balance**.

| Tuning group | Initial basis / variables | Evidence that should drive revision |
|---|---|---|
| Player motion | Walk/run speed, dash/dodge displacement/cost, facing dead zone, camera follow/zoom. | Traversal/collision clips and observed control mistakes. |
| Combat | HP/damage, phase times, input buffer, hit-stop, i-frames, parry/guard windows, poise/knockback and status amounts. | Hit readability, legal response opportunity, class completion and defense boundary tests. |
| AI | Observation delay, memory decay, utility weights, action suppression, commitment/pressure admission. | Observable reaction traces, behavior variation, counterplay and simultaneous-cue readability. |
| Progression | Example 100×L next-level XP curve, reward distribution, stat increments, point grants. | Main/optional/underleveled trajectories through finite content. |
| Economy | Prices, income, stock quantities, affix ranges/chances and upgrade magnitudes/costs. | Poor-drop/spending scenarios, useful alternatives and duplication checks. |
| Level pacing | Region 160×160 hypothesis, reserved lots/roads, encounter composition, optional density, floor theme selection. | Traversal time, escort clearance, tower reorientation, objective comprehension. |
| Capacity/engineering | Storage 64-slot hypothesis, generation 8-candidate hypothesis, effect/light/audio limits. | Failure recovery, inventory friction and measured performance. |

Every eventual tuning dataset records its version, units, rationale and evidence state. Early values may be replaced without claiming player validation; changes to explicitly locked counts/rules need approval.

## 62.2 Consistency findings incorporated in V2.1

| Previous ambiguity / collision | Resolution or explicit boundary |
|---|---|
| Master governance said STOP for every major gap. | Record a decision and block only dependent implementation; finish independent specification work. |
| Side-only sprite versus 360° aim. | Separate ground/body/aim/grip/attack transforms and local/world sorting; no front/back body set. |
| Animation priority versus attack commitment. | Gameplay legality precedes animation selection; authored voluntary/forced interruption rules. |
| Heavy Attack animation versus no charged attacks. | Uncharged authored action; no inferred hold-to-charge system. |
| Class-dependent resources versus shared stamina. | All classes retain stamina; Mage additionally has mana; exact kits remain DR-04/05. |
| Enemy population versus intelligent concurrency. | Inclusive population accounting; per-floor encounter sizes; global engaged cap and separate pressure budget. |
| Level-based Danger versus content-based actual risk. | Preserve the exact deficit table and add separate content warnings; no hidden penalties. |
| Procedural generation versus authored quests/escorts. | Reserve and validate required sockets/routes/dependencies before optional content; compatible deterministic fallback. |
| Sigil travel versus combat/nonportable quests. | Shared guard and revalidation at transactional commit; explicit quest-leave outcome and safe arrival. |
| Inventory versus quest rewards/Sigil. | Protected entitlements and durable pending rewards; no loss or reroll from capacity. |
| World Map required versus full-screen map optional. | Required map view, optional dedicated full-screen presentation. |
| 20 structures versus interior/NPC cost. | 8 functional interior destinations, 12 decorative identities; five recurring major roles plus stations/temporary actors. |
| Stable authored overworld versus AI concepts. | One validated map revision with stable anchors; development concepts never imply runtime regeneration. |
| Late save implementation versus procedural/quest state. | Identity/snapshot contracts from the foundation milestone; integrate persistence with quests and generation. |
| Replay/death/quest count ambiguity. | Explicit DR-01/02/03 options; no silent choice or partial-state retention. |
| “Implementation-ready at high level” versus missing class/boss rules. | Readiness stated honestly; concrete DR-04–07 choices gate dependent content. |
| 25 FPS minimum versus unspecified machine. | DR-08 benchmark basis; no unmeasured performance claim. |
| Generic Agency advice versus actual project scope. | Selective guidance only; no forced middleware, 3D pipeline, speculative canon or production implementation. |

This pass preserves the previously approved decisions, separates scope/status, specifies constrained operational behavior, and leaves consequential alternatives visible. No executable gameplay validation or balance proof is claimed by a document review.

**End of Nice Journey — Master Game Specification V2.1.**

