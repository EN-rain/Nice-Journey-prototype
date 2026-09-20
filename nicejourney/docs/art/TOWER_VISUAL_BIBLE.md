# Nice Journey — Tower Visual Bible v0.1

Authority: master tower/Floor 1–10 contracts and `docs/art/ART_INTEGRATION_RULES.md`.

## Core approach

The prototype tower uses a reusable modular pixel-art kit rather than ten unrelated tilesets. Combat readability, telegraph contrast and deterministic room ownership outrank decorative complexity.

Current base visual assets:

- `res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png`
- `res://assets/art/environments/tower/rooms/tower_room_combat_v01.png`
- `tower_room_safe_v01.png`
- `tower_room_reward_v01.png`
- `tower_room_vendor_v01.png`
- `tower_room_secret_v01.png`
- `tower_room_elite_v01.png`
- `tower_room_objective_v01.png`
- `tower_room_boss_v01.png`

## Material language

Use dark stone/metal architecture with controlled cool values. Gold marks rewards/objectives, teal marks safe/checkpoint language, danger red marks hostile/hazard identity, and arcane violet may identify boss/occult features. Required information must still remain distinguishable by shape and placement, not color alone.

## Room grammar

- **Combat:** open readable floor, low clutter, clear enemy approach paths.
- **Safe/checkpoint:** calm symmetric marker and low visual noise.
- **Reward:** unmistakable positive focal point after successful completion.
- **Vendor:** service/readability language distinct from rewards.
- **Secret:** subtle but discoverable contrast; never required for main progression.
- **Elite:** stronger danger identity without visually implying boss ownership.
- **Objective:** obvious objective socket/marker that stays visible during combat.
- **Boss:** larger compositional focus with enough empty floor for major telegraphs.

## Floor differentiation

Different floors should primarily vary through dressing, palette emphasis, prop/hazard selection and room composition. Do not require a fully unique tileset per floor unless later playtesting proves necessary.

## Hazards and telegraphs

Floor hazard art must use the same warning grammar as combat telegraphs and cannot be confused with decoration. Hazard collision/activation remains owned by gameplay runtime, not image pixels.

## The Tenth Warden arena

The boss room must support Twin Cut, Warden Lunge, Arc Volley, Crescent Sweep and Punishing Step without occluding their danger geometry. The room must not imply add-spawn sockets because the approved boss is no-add.

## Acceptance

The tower visual kit is accepted only after live room generation/layout uses it across Floors 1–10, room categories remain visually distinct, pathing/collision matches rendered geometry, telegraphs remain visible, and representative combat/boss-room evidence has been captured.