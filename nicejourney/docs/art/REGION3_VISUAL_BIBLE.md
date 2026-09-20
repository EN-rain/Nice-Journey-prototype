# Nice Journey — Region 3 Visual Bible v0.1

Authority: master Region 3/town contracts and `docs/art/ART_INTEGRATION_RULES.md`.

## Environment goal

Region 3 must read as a compact handcrafted prototype overworld with a strong hub landmark, clear service buildings, readable quest routes, and enough environmental variation to distinguish safe town, roads, outskirts, ruins and risk areas without drowning combat readability.

## Town count contract

Exactly **20** structures are represented: **8 functional + 12 decorative**. Decorative buildings must not visually promise services they do not provide.

Functional landmark identities:

1. Central Tower
2. Quest Hall
3. Blacksmith
4. General Merchant
5. Inn / Rest House
6. Storage House
7. Training Hall
8. Clinic / Apothecary

Current local exteriors are under `res://assets/art/environments/region3/functional_buildings/`; decorative structures are under `decorative_buildings/`.

## Landmark hierarchy

The **Central Tower** is the strongest silhouette and navigation landmark. Quest Hall and service buildings use smaller role cues such as signage, forge/chimney, merchant stall, inn sign, storage crates, training implements and clinic cross/apothecary cue. These cues are readability devices, not new lore.

## Ground/material language

The current ground/road atlas provides first-pass grass, road/dirt, stone/plaza, risk-tone and fence/material strips. Use 32-pixel grid compatibility where practical, but world collision and traversal remain authoritative in scenes rather than in decorative pixels.

## Props

The first prop sheet includes crates, barrels, signs, lantern/fixture language, bench, vegetation and related hub dressing. Props should cluster around function and route readability rather than uniformly filling empty space.

## Subzones

- **Town/hub:** safest, clearest values, strongest service signage.
- **Roads/outskirts:** less dense architecture, more ground/vegetation rhythm.
- **Ruins:** broken stone modules, stronger shadow/age contrast.
- **Risk zones:** stronger danger accents while still preserving enemy telegraph contrast.

## Interiors

Only important functional buildings need production interiors in the prototype. Do not create 20 separate interiors. Interior art should reuse the same palette/material family and provide obvious interaction points.

## Lighting

Dynamic lighting may tint the world but source assets must remain readable without it. Avoid baking strong directional lighting into tiles that conflicts when repeated.

## Acceptance

Region 3 art is not complete until all 20 structures are placed appropriately in a real world layout, functional buildings are unmistakable at gameplay scale, routes remain navigable, collision matches visible geometry, important interiors exist, and screenshots/renderer evidence confirm readability.