# Nice Journey — Sprite-Gen Building Asset Guide

Updated: 2026-09-15
Status: ACTIVE / REQUIRED FOR REGION 3 BUILDING PRODUCTION

## 1. Installed guide/tooling

The project now vendors the upstream sprite-generation guide/tooling at:

```text
D:\nicejourney\tools\sprite-gen
```

Installed upstream repository:

```text
https://github.com/aldegad/sprite-gen
commit: ed960ac2e8c61b34e34dd47650e4a7a0182cbc0f
SKILL.md version: 2.2.0
```

A dedicated Python environment is installed at:

```text
D:\nicejourney\tools\sprite-gen\.venv
```

Verified environment:

```text
Python 3.13.5
numpy 2.5.3
Pillow 12.3.0
sprite-gen 2.2.0 editable install
```

Windows CLI entry point:

```text
D:\nicejourney\tools\sprite-gen\.venv\Scripts\sprite-gen.exe
```

Use this venv only. Do not silently fall back to a global Python interpreter.

## 2. Current generation-provider status

The local `sprite-gen workflow --kind image` probe currently reports:

- Codex provider unavailable because the Codex CLI is not installed;
- Grok provider unavailable because no readable Grok credential is configured;
- therefore the vendored repository is presently used as the **workflow/processing/QA guide and utility set**, not as the image-provider transport.

This project must **not** enable or use the Codex orchestrator to work around that limitation. The user explicitly requires the Codex orchestrator to remain disabled. When ChatGPT native image generation is used, follow the same source/QA discipline from this guide, then transfer only accepted source images into the local project.

Current provisional-building baseline evidence is recorded at `docs/evidence/art/region3-functional-buildings-v01-baseline.json`; the current eight V01 functional textures are all 96×96 RGBA placeholders. This is a comparison baseline, **not** a declaration that 96×96 is the final production footprint.

## 3. Why this guide is used for buildings

The Region 3 production pass needs static environment sprites rather than a character animation cycle. The useful `sprite-gen` contracts are therefore:

- clean one-subject image generation discipline;
- alpha/background truth checking;
- deterministic cutout where needed;
- pixel-grid / pixel-unfake principles;
- source preservation;
- curation before publication;
- deterministic derivation and engine export;
- fail-loud QA instead of accepting a visually wrong source.

The component-row animation pipeline remains the correct route for animated characters. Do not force static buildings into an animation-row workflow merely because the tool supports it.

The functional-landmark generation history is maintained in `docs/art/REGION3_FUNCTIONAL_BUILDING_V02_BATCH.md`, with the validated mapping in `docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json`.

The next Region 3 production packet is now pinned in `docs/art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md` and `docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json`. It covers the exact 12 decorative structure anchors plus props, ground/road, ruins, outskirts and risk-zone support. The decorative manifest has been mechanically checked against the authored town scene; its status is generation-prep only and does not claim that V02 sources have been generated or integrated.

## 4. Region 3 building production strategy

Produce the eight functional landmarks as **eight individually accepted building sources**, not as a single irreversible giant atlas. A shared reference sheet may be generated first for visual-direction approval, but final building sources should remain individually reviewable and replaceable.

Locked roles:

1. Central Tower
2. Quest Hall
3. Blacksmith
4. General Merchant
5. Inn / Rest House
6. Storage House
7. Training Hall
8. Clinic / Apothecary

### Recommended order

1. Central Tower — establish the visual language.
2. Quest Hall — prove civic timber/stone vocabulary.
3. Blacksmith — prove industrial cues without character clutter.
4. General Merchant — prove commercial cues.
5. Inn / Rest House — prove hospitality silhouette.
6. Storage House — prove utilitarian silhouette.
7. Training Hall — prove martial/training identity.
8. Clinic / Apothecary — prove healing/apothecary identity.

The accepted Central Tower source becomes the main style anchor for the remaining seven. If a later source drifts in perspective, palette, pixel density, roof language or material language, reject/regenerate that source rather than compensating in Godot.

## 5. Visual contract

All functional buildings must share:

- 16-bit-inspired pixel-art presentation;
- crisp nearest-neighbor-readable edges;
- fixed 3/4 top-down gameplay perspective;
- coherent stone, timber, roof, metal and trim palette;
- one consistent implied light direction;
- strong entrance readability;
- strong ground-contact footprint;
- no people baked into the building sprite;
- no labels, file names, status text, checkmarks or UI;
- no perspective changes between buildings;
- no painted shadow that conflicts with the game's ground/shadow strategy unless intentionally approved;
- no anti-aliased illustration look presented as finished pixel art.

Central Tower may be taller and more visually dominant, but its materials and perspective still belong to the same town kit.

## 6. Source-generation contract

For production sources, prefer one isolated building per generated source image.

Subject-only prompt shape:

```text
Create only one production game-art environment sprite.

Game: Nice Journey
Subject: [BUILDING ROLE]
Style: coherent 16-bit-inspired fantasy-town pixel art.
View: fixed 3/4 top-down gameplay view.
Materials: stone foundation, timber construction, coherent roof/trim language matching the accepted Region 3 style anchor.
Entrance: clearly readable from gameplay camera.
Composition: whole building fully visible, isolated, generous margin, no people, no props crossing the source boundary.
Pixel target: readable after deterministic reduction to the approved gameplay footprint.
Background: transparent when reliable; otherwise a flat chroma key suitable for deterministic cutout.

Do not create a dashboard, progress report, editor screenshot, UI panel, test result, roadmap, file path, labels, text, character showcase or unrelated scene.
```

When a visual reference is attached and native alpha becomes unreliable, follow the upstream guide's chroma strategy rather than accepting a checkerboard drawing as alpha.

## 7. Clean-context rule remains mandatory

`IMAGE_GENERATION_FAILURE_RECOVERY_AND_ASSET_ACCEPTANCE_PROTOCOL.md` remains authoritative for the known contaminated-context failure.

For Region 3 buildings:

- first wrong-subject/dashboard output: reject immediately;
- one controlled stricter retry at most in the same contaminated context;
- second wrong-subject result: stop generation in that context;
- never crop game assets out of a status dashboard;
- never add rejected output to provenance as an accepted production source.

The sprite-gen installation does not override this rule.

## 8. Alpha/background handling

### Native transparent source

If the accepted generated PNG has genuine alpha:

- measure that alpha before publication;
- scrub non-zero RGB under fully transparent pixels if needed;
- reject a fake checkerboard or an RGB-only image claimed to be transparent.

### Chroma source

If a reference-assisted generation needs a chroma background:

- use a key color that does not collide with the building palette;
- use `sprite-gen cutout` / the canonical matte path instead of ad-hoc flood fill;
- inspect roof gaps, windows, arches and under-eave pockets after removal;
- reject sources where background color is entangled with important material colors.

Do not use white/cream flood-fill removal for light stone/plaster buildings.

## 9. Pixel-art truth / pixel-unfake rule

AI-generated "pixel art" may contain antialiasing and an inconsistent implied pixel lattice. The upstream `pixel-unfake` guidance is relevant even for static buildings.

Project rule:

- source generation establishes composition and visual identity;
- deterministic pixel cleanup establishes a stable pixel lattice;
- final game derivatives use integer / nearest-neighbor scaling only;
- do not use Lanczos/Bicubic on accepted pixel-art derivatives;
- do not repeatedly resample a source; derive from the untouched accepted source every time;
- do not destroy details merely to force a nominal logical size.

For a static building, prefer a single deterministic lattice for the entire source. If the source already has a convincing stable grid at the desired density, avoid unnecessary second-pass degradation.

## 10. Source storage

Accepted untouched generated sources go under:

```text
res://assets/art/generated_sources/imagegen/region3/buildings/
```

Suggested names:

```text
region3_central_tower_source_v02.png
region3_quest_hall_source_v02.png
region3_blacksmith_source_v02.png
region3_general_merchant_source_v02.png
region3_inn_rest_house_source_v02.png
region3_storage_house_source_v02.png
region3_training_hall_source_v02.png
region3_clinic_apothecary_source_v02.png
```

Never overwrite an accepted exact source. A corrected/regenerated source gets a new source revision.

## 11. Deterministic derivation

Each gameplay derivative must record:

- exact source path;
- source SHA-256;
- source dimensions and alpha mode;
- crop rectangle if cropped;
- cleanup operation;
- pixel-grid/pixel-unfake operation if used;
- nearest-neighbor target size / scale;
- output path;
- output dimensions;
- derivative SHA-256.

Recommended manifest:

```text
res://assets/art/generated_sources/imagegen/region3/buildings/region3_building_v02_derivation_manifest.json
```

Do not substantially redraw a derivative and still call it a source-derived crop.

## 12. Mechanical source intake

Before a visually accepted source is copied into production art paths, run the project intake reporter with the vendored sprite-gen Python environment:

```text
D:\nicejourney\tools\sprite-gen\.venv\Scripts\python.exe D:\nicejourney\nicejourney\tools\art\region3_building_source_intake.py --role central_tower --source <accepted-source.png> --require-alpha --report <report.json>
```

This reporter records exact SHA-256, source dimensions, alpha statistics, visible bounding box and edge contact. It deliberately does **not** approve art direction; visual inspection remains mandatory. Chroma-key sources should be cut out first, then the cleaned RGBA derivative can be checked with `--require-alpha`.

## 13. Godot integration

Existing architecture already supports resource-only replacement.

Production path:

```text
Region3FunctionalBuildingVisualProfile (.tres)
    -> Texture2D
    -> Region3TownStructureAnchor / generic Sprite2D presentation
```

For each accepted replacement:

1. import the derivative into `res://assets/art/environments/region3/...`;
2. keep texture filtering nearest;
3. update the correct `Region3FunctionalBuildingVisualProfile` texture in the Inspector/resource;
4. adjust sprite offset/scale/z-index in the `.tres` resource, not gameplay code;
5. verify the authored entrance tile still visually matches the actual door;
6. capture the real Region 3 authored-town renderer scene;
7. only remove the replaced V01 after tests/resource paths/provenance/broad validation are green.

Do not hardcode new building paths, scale or offsets in Region 3 gameplay scripts.

## 14. Building-specific acceptance gate

Reject a building source or derivative when any of the following is true:

- wrong role identity;
- perspective differs materially from the accepted Region 3 anchor;
- door cannot be read from gameplay scale;
- building is cropped;
- roof/eaves visually obscure the door in a way incompatible with the authored entrance tile;
- silhouette collapses at gameplay scale;
- material palette visibly drifts from the Region 3 kit;
- background is still present after cutout;
- text/labels overlap the asset;
- antialiasing creates a non-pixel-art edge language after reduction;
- projected shadow implies a different light direction than the town;
- source would require major manual repainting to become usable.

## 15. In-engine acceptance

For each integrated building verify:

- exact inspector profile points to V02;
- V01 is no longer referenced by live production resources before deletion;
- nearest filtering is active;
- sprite footprint is visually appropriate for its reserved lot;
- door aligns with the authored `entrance_tile` / `door_facing` intent;
- service connector approaches the readable entrance rather than a side wall;
- no source-background rectangle appears;
- tower/plaza hierarchy still reads;
- routes remain readable around the sprite;
- no building overlaps another reserved structure unexpectedly;
- town composition remains legible at 640×360 internal canvas and 1280×720 output.

## 16. Local sprite-gen commands used by this project

Set an explicit root in shell scripts/notes:

```text
SPRITE_GEN_ROOT=D:\nicejourney\tools\sprite-gen
```

Read-only workflow probe on this Windows installation:

```text
set PYTHONIOENCODING=utf-8
D:\nicejourney\tools\sprite-gen\.venv\Scripts\sprite-gen.exe workflow --kind image
```

Useful local utility discovery:

```text
D:\nicejourney\tools\sprite-gen\.venv\Scripts\sprite-gen.exe --help
D:\nicejourney\tools\sprite-gen\.venv\Scripts\sprite-gen.exe cutout --help
D:\nicejourney\tools\sprite-gen\.venv\Scripts\sprite-gen.exe background-tile --help
D:\nicejourney\tools\sprite-gen\.venv\Scripts\sprite-gen.exe scene-inspect --help
```

Generation through sprite-gen itself must not be attempted until an explicitly chosen provider is actually available. Do not silently install/enable the Codex orchestrator or switch providers to make generation succeed.

## 17. Completion evidence for the Region 3 functional batch

The batch is complete only after all eight have:

- accepted exact source images;
- SHA-256 source identity;
- derivation records;
- provenance records;
- V02 derivatives under production art paths;
- inspector profile integration;
- no live V01 reference for replaced roles;
- `test_region3_functional_building_visuals.gd` PASS;
- `test_region3_authored_town_layout.gd` PASS;
- `test_region3_route_connectivity.gd` PASS;
- `test_project_resource_paths.gd` PASS;
- asset provenance test PASS;
- real renderer capture reviewed;
- full reference validation PASS.

Only then may the Region 3 functional-building asset slice be called productionized.
