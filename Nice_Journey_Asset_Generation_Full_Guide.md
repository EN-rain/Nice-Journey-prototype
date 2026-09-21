# Nice Journey — Complete Visual Asset Production and Prompting Guide

**Final user instruction:** stop image generation; create this guide using the existing generated images. No additional image is required to produce or read this handoff. Future asset work should reuse these sources and match their visual identity, not redesign the style.

Prepared 2026-09-20 for an agent continuing the visual-asset work in `D:\nicejourney`. This is a handoff and production manual, not a claim that all assets are finished. The user first asked to finish the current work and prepare a handoff, then explicitly narrowed the turn to stopping image generation and producing this guide from existing images. Remaining technical work is recorded rather than presented as complete.

## How to read this handoff without overloading context

- Read sections1–5 for scope, authority and style locks.
- Read section14 for the actual frozen status, source-image index and prompts already used.
- Choose one category or stable ID in section15, then retrieve only its detailed record in section16.
- Use sections6–12 as a reference for the stage you are executing.
- Do not ingest all223 detailed records into every worker or paste this entire document into imagegen. The long appendix is a complete archive, not an image prompt.

## 1. Mission and boundaries

Determine the visual assets the implemented prototype actually needs; preserve accepted work; finish missing or defective assets; integrate and verify them in Godot. An image being generated is only one stage of this task.

Work in `D:\nicejourney` through the direct Auvrynt connection. The Godot project is `D:\nicejourney\nicejourney`. `res://` paths in this document are relative to that inner directory. The user authorized either accessible Auvrynt connection and the available built-in image generator even when its underlying model version cannot be verified. Do not label outputs “GPT Image 2.5 verified”: the tool does not expose that evidence.

The user explicitly authorized narrow Luna subagents for this asset task. Give each one a bounded domain and disjoint writable paths. They must inspect actual files. Do not send every agent the whole repository. One coordinator owns shared production/provenance manifests and durable state documents. Do not use the separate Codex orchestrator; the workspace instructions prohibit it.

Do not invent new mechanics, classes, regions, NPC biographies, enemy abilities, item lists, map-marker meanings, combat geometry, or final balance values in order to justify more images. A missing gameplay specification is an authoring dependency, not an invitation to generate arbitrary art. Art-direction decisions may be proposed explicitly without presenting them as master-spec facts.

### Definition of done for one asset

1. Its requirement and target consumer are established.
2. Its exact source is visually reviewed, preserved, and identified by SHA-256.
3. A reproducible derivation records crop rectangles, frame order, scale, alpha processing, padding, pivot, dimensions, and output hashes.
4. The actual resource/scene references the intended derivative.
5. A fresh or hash-correlated, complete Godot renderer capture shows the relevant result at gameplay scale.
6. Focused tests pass; a broad integration gate passes for the completed slice, or remaining failures are explicitly documented without declaring full acceptance.
7. Both production and provenance records match the actual files.

Do not replace an accepted production asset merely because a new prompt might look better. A revision requires a verified defect and a controlled comparison.

## 2. Authority and first reads

Read the workspace root `AGENTS.md`, then `nicejourney/AGENTS.md`, then any nested instructions for the area you will edit. Read these visual documents only for the relevant category:

| Authority | Purpose |
| --- | --- |
| `Nice_Journey_Master_Game_Specification_V2_1.md` | Locked design contracts; search exact relevant sections rather than loading everything |
| `nicejourney/docs/IMPLEMENTATION_STATE.md` | Current implementation record; historical paragraphs can be stale |
| `nicejourney/docs/NEXT_DEVELOPMENT_SEQUENCE.md` | Dependency ordering and pending work |
| `nicejourney/docs/art/ART_INTEGRATION_RULES.md` | Sprite/resource architecture, acceptance, provenance and validation |
| `nicejourney/docs/art/IMAGE_GENERATION_FAILURE_RECOVERY_AND_ASSET_ACCEPTANCE_PROTOCOL.md` | Wrong-subject recovery and generation acceptance |
| `nicejourney/docs/art/ASSET_PRODUCTION_MANIFEST.json` | Complete audited asset inventory and classifications |
| `nicejourney/docs/ASSET_PROVENANCE_MANIFEST.json` | Source/license/derivation metadata for registered project assets |
| `nicejourney/docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md` | Body/weapon layering, frame canvas, anchor and animation ranges |
| `nicejourney/docs/art/NPC_VISUAL_DESIGN_BIBLE.md` | Explicitly proposed NPC presentation decisions and escort mapping |
| `nicejourney/docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md` | Enemy silhouettes, pose baseline and readability |
| `nicejourney/docs/art/REGION3_VISUAL_BIBLE.md` | Town, environment, interiors and material language |
| `nicejourney/docs/art/TOWER_VISUAL_BIBLE.md` | Shared tower kit, room roles and boss arena |
| `nicejourney/docs/art/UI_VISUAL_BIBLE.md` | Icon inventory, HUD, scale and accessibility |
| `nicejourney/docs/art/VFX_VISUAL_BIBLE.md` | Telegraph, feedback and status semantics |

Resolve conflicts by inspecting the current source image, consumer, resource values, hash records and runtime. A version suffix, filename, old comment, or prior assistant report is not acceptance evidence. For example, the preserved player file named `05_climb_sleep_death.png` actually supplies dodge/attack/heavy-attack/block rows. The manifest's visually classified crop mapping is intentional.

Never treat a remembered unresolved design decision as current without checking the repository. Project instructions state DR-01 through DR-08 are resolved at the contract level; individual production numbers or art details may still be provisional. These are different questions.

## 3. Inventory model and status vocabulary

The inventory below reproduces every record from the consolidated manifest. A record may describe a sheet, kit, integration gap, animation set, or individual image; record count is not an image count.

Required record fields: stable asset ID, category, subject, gameplay purpose, required views/directions, animation states, frame counts if specified, gameplay dimensions, source-generation dimensions if different, transparency, style authority, references, target resource/scene if known, existing asset, implementation status, generation/revision requirement, dependencies, priority, and acceptance criteria.

| Classification | Meaning and next action |
| --- | --- |
| `ACCEPTED_DO_NOT_REGENERATE` | Preserve the accepted source and derivative; only revise after proving a defect |
| `EXISTS_NEEDS_REVISION` | Diagnose the defect; determine whether source editing, deterministic derivation, or wiring alone solves it |
| `PLACEHOLDER` | A consumer has provisional art; replace through the current resource architecture after acceptance |
| `MISSING_GENERATE` | Required visual is absent; resolve its brief and dependencies before generating |
| `ANIMATION_REQUIRED` | Identity or static art exists but motion/state frames remain unfinished |
| `TEXTURE_TILE_REQUIRED` | Needs a tiling/material solution, edge tests and real world coverage |
| `VFX_REQUIRED` | Needs an event/geometry-bound effect or telegraph; check existing primitives before generating |

Keep classification separate from pipeline stage. Useful stages are `brief_pending`, `source_candidate`, `source_reviewed`, `source_preserved`, `derived`, `integrated_pending_review`, `renderer_reviewed`, `focused_validated`, and `accepted`. These stage names are workflow guidance, not replacements for the seven required classifications. An exact source can be accepted for derivation while the runtime derivative remains unaccepted.

Unknown values must remain null or explicitly unknown. Measured current dimensions do not become a newly approved source-resolution requirement. Proposed frame counts must be identified as presentation decisions.

## 4. Shared art direction and dimensions

The project is crisp, 16-bit-inspired pixel raster art with controlled palette ramps and readable silhouettes. Runtime filtering is nearest-neighbor. Transparent actors/props must use real alpha. Avoid painterly gradients, bloom, soft scaling, excessive miniature detail, frame-to-frame color noise and large disconnected outlines.

| Domain | Verified canvas/convention | Caution |
| --- | --- | --- |
| Player body | 32×32 per frame; source ground anchor `(16,29)`; right-authored, left mirrored | Weapons, projectile art and VFX are separate layers |
| NPC body | Proposed 32×32; same anchor and direction convention | Proposal is not a master-spec fact; inspect implemented profiles |
| Reusable enemy | 48×48 baseline | Six canonical poses do not imply a full animated walk or attack cycle |
| Tenth Warden | 96×96 baseline | Preserve boss mechanics and five move families |
| Functional buildings | Existing Central Tower 224×224; seven service buildings 192×192 | Preserve accepted sources and individual profile anchors |
| Decorative buildings | Existing V02 derivatives 160×160 | Exactly twelve decorative identities |
| UI standalone icon | Mostly 32×32 | Check native size and UI scaling, not only enlarged source |
| Map sheet | Existing 128×32, four cells | Cell meaning and live consumers must be authored before replacement |
| Region ground | 32-pixel grid compatibility | Atlas cell size and material repetition must match actual resources |
| Game canvas/output | Internal 640×360; minimum/reference output 1280×720 | Review world art at real gameplay zoom |

### Current player identity

Use the actual user-supplied V03 character: spiky brown hair, blue scarf, cream sleeves, brown leather vest and gloves, blue trousers, brown boots. Do not revert to the older slate-coat/teal V01 identity. The player bible was corrected to make that distinction explicit. Keep identity stable across all new frames. Enemy/NPC characters may share production style and scale, but must not become clones of the player.

### Player animation contract

| State | Bible range |
| --- | --- |
| Idle | 4–6 |
| Walk | 6–8 |
| Run | 6–8 |
| Dash | 4–6 |
| Dodge | 4–6; not a roll |
| Attack | 4–8 |
| Block | 2–4 plus held pose |
| Parry | 4–6 |
| Cast | 6–10 |
| Hit | 3–5 |
| Heavy attack | 6–10 |
| Death | 8–12 |
| Interact | 4–6 |
| Pickup | 4–6 |
| Use item | 4–6 |
| Climb | 6–8 |
| Sleep | 4–6 |

A duration change is not a new frame. Duplicating identical poses does not resolve a missing motion phase. If selecting fewer source poses resolves a count mismatch, record exact indices, visual justification and preserved/re-authored timing. Do not change gameplay action timing merely to match a generated image.

## 5. Keep generation context clean

The project has previously received unrelated dashboards/status illustrations when it requested game art. Treat this as a real production failure mode. Prompt isolation reduces risk; it is not a guarantee of output quality.

Separate investigation from image prompting. The researcher supplies a compact, verified asset brief and exact reference images. The image-generating agent receives only the visual subject, reference roles, constraints, and desired output. Do not paste repository trees, tests, progress reports, filenames, tool logs, coding discussions, or this entire guide into the image prompt.

Use one coherent asset or tightly related sheet per generation call. Do not mix a building, character and UI set into one sheet. Do not ask the generator to design the production dashboard. No text inside sprites/icons unless the specification actually needs readable in-world text.

If an output is an unrelated dashboard/editor/report, reject it completely. Do not crop it into usable-looking fragments or register it as accepted. Make at most one controlled retry in the same context. If that is still unrelated, switch to a fresh image-focused context with only the brief and references. Do not repeatedly burn attempts in the contaminated conversation.

### Minimal agent packet

```text
Asset ID and scope: [stable ID; one exact asset or coherent sheet]
Verified subject: [...]
Reference images: [attach actual pixels; label anchor/edit target/style reference]
Required output: [views, state order, count, layout, transparent/opaque]
Gameplay target: [measured or specified size]
Identity locks: [silhouette, proportions, palette, clothing, equipment separation]
Allowed change: [one specific defect or new motion]
Must not change: [...]
Acceptance checks: [visual checks only, concise]
Return: source candidate; do not claim project integration.
```

Keep the full engineering contract outside the image prompt. The coordinating agent retains it for validation and integration.

## 6. Prompting templates

These templates are starting points, not new asset requirements. Fill placeholders from an actual inventory record and current consumer. Do not submit brackets or inferred numbers as if verified.

### A. Isolated character anchor

```text
Create only an isolated game-art character sprite.
Subject: [verified role and visible clothing/tool cues].
Reference image 1 is the style/scale anchor, not a request to copy its identity.
16-bit-inspired pixel art; crisp edges, controlled color ramps.
View: [verified direction]. Full body, clear feet, no cropping.
Readable when reduced to [gameplay canvas].
Background: genuinely transparent.
No text, labels, grid, border, scenery, glow, dashboard, editor or UI.
```

### B. Controlled animation from an anchor

```text
Create a [N]-frame [state] animation strip of the exact reference character.
Use the attached character as the identity anchor. Preserve head/body ratio,
hair silhouette, face, clothing layers, palette, equipment rules and outline style.
[N] full-body frames in one horizontal row, evenly spaced, same canvas per cell,
consistent feet baseline, transparent margins, no cropping.
Motion order: [specific verified phases].
Keep scale consistent; do not independently resize each pose.
Background: real transparency. No labels, separators or unrelated effects.
```

For a locomotion loop, specify contact → down → passing → up → opposite contact and a clean loop closure, with only the phases/count the chosen contract supports. Check feet sliding and repeated poses. Do not impose “static arms” globally from an unrelated sprite request; follow this project's actual asset brief.

### C. Body-only correction of an existing sheet

```text
Edit the attached [state] sprite strip.
Remove only [baked weapon / shield arc / particles / slash effects].
Reconstruct the empty gloved hand or cloth that was obscured.
Preserve every body pose, motion order, face, proportions, clothing,
palette, canvas layout and ground baseline.
Keep exactly [N] full-body frames with genuine transparent background.
No replacement weapon, no glow, no text, no UI.
```

This session used that pattern for basic attack, heavy attack, block, and the parry/cast/hit sheet. Exact prompts, reference regions, source identities and hashes are saved in `assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json`.

### D. Building exterior

```text
Create one isolated [verified building role] exterior for a pixel-art RPG.
Match the attached accepted building's perspective, material ramps,
roof/stone/timber language, outline density and light direction.
Show the [authored entrance side] entrance clearly.
Full building silhouette with transparent padding; no cut-off roof or base.
Readable at [target size]. [Landmark hierarchy requirement].
Transparent background. No ground scene, captions, HUD or extra buildings.
```

Do not generate an exterior before checking entrance direction and lot/collision constraints. Do not silently move gameplay entrances to fit a new drawing.

### E. Seamless ground/material tile

```text
Create only a seamless [material] ground texture for the attached pixel-art style.
Top surface, uniform scale and lighting; no perspective-object silhouette.
Opposite edges must continue naturally when tiled in both axes.
No vignette, border, cast shadow, isolated island, labels or props.
[Opaque background/material coverage, if this is a ground-fill texture].
Readable at [tile dimensions], restrained contrast beneath combat telegraphs.
```

“Seamless” in a prompt is not proof. Inspect a 2×2 and preferably 3×3 repeated render, edge discontinuities, scale and frequency. A sheet of sample patches is not a finished world ground layer.

### F. Prop/ruin module sheet

```text
Create a coherent sheet containing exactly: [ordered verified subject list].
[Columns] by [rows] layout, one isolated object per cell, consistent camera/materials.
Even empty margins; every object complete, no shadows or fragments crossing cells.
Objects should remain readable at [per-subject gameplay size].
Transparent background. No labels, grid lines, borders, additional objects or scenery.
```

Explicit ordered subjects prevent swapped meanings and omitted modules. Record crop rectangles from the actual result rather than assuming the generator obeyed the grid.

### G. UI icon/class skill sheet

```text
Create [N] distinct pixel-art icons in [layout], one symbol per cell.
Subjects in order: [implemented skill names with concise visual meanings].
Use the attached accepted icon sheet for outline, palette, weight and scale.
Each must read at 32×32; favor large silhouettes and few details.
Active skills show action geometry; passives use stable symbolic motifs.
Transparent background, no words, letters, labels, frames or UI mockup.
```

Never map icons by visual plausibility alone when the sheet order is undocumented. Compare each symbol to the implemented skill semantics. Verify distinct bytes and distinct native-scale silhouettes; unique hashes alone do not prove meaningful distinction.

### H. VFX / telegraph

```text
Create only the [verified effect] sprite sequence.
[N] frames in [layout], same pivot and extent per cell.
Visual phases: [preparation / active / contact / recovery as appropriate].
Shape: [geometry already authored by gameplay].
Clear boundary, restrained interior detail, transparent background.
Match the attached effect palette and outline language.
No character, scenery, text or extra attack geometry.
```

Use this only when counts and visual geometry are established. Existing line/cone/circle/arc/lane primitives may already suffice. An integration-only telegraph record must not trigger needless generation.

## 7. Source intake and interruption recovery

Save exact generated PNG bytes before deriving or cleaning them. Compute SHA-256 of the local source, transfer, then compute/verify the destination hash. Retain the generator source identity, actual dimensions, prompt, references, date, model-version uncertainty, and acceptance stage.

Observed transfer behavior in this session: a single roughly 625 KB Auvrynt binary call failed even though the advertised tool limit was larger. Sequential 65,536-character base64 chunks worked, corresponding to 49,152 decoded bytes for each full chunk. Use the returned `nextOffset`, not assumptions, and check the final file SHA-256. A text response saying “transferred” without final verification is insufficient.

Do not use a preview, screenshot, recompressed JPEG, derived atlas, or corrupt ZIP as a substitute for the original PNG. JPEG review previews can help inspect large sources that exceed the MCP inline limit; label that role and preserve the exact PNG separately.

If interrupted or quota-limited:

1. Check the saved source and recorded hash first.
2. Check whether a transfer is complete or partial. Resume only from the confirmed byte offset.
3. Search the available saved image artifact if the destination is incomplete; do not regenerate automatically.
4. Re-run deterministic derivation and compare hashes.
5. Verify actual consumer bindings and renderer evidence, then resume at the first incomplete stage.
6. Never infer acceptance from elapsed time, previous narrative, or a partially written checkpoint.

A future agent may not inherit in-memory tool variables, workspace IDs, agents, or image references. Reopen the project when needed, read current instructions and durable files, and explicitly attach the correct image reference. No workflow here depends on the next agent remembering this conversation.

## 8. Deterministic derivation and quality control

Use a checked-in derivation script and a machine-readable manifest. Original source stays unchanged. Typical permitted derivation steps are explicit cropping, transparent padding, documented alpha cleanup, nearest-neighbor resize, integer translation and atlas packing. Use the image generator for substantive repainting/redrawing unless the user specifically authorizes another editing method.

Do not apply LANCZOS/bicubic smoothing to gameplay pixel sprites. Do not derive frame size independently from each pose's total bounding box: a raised hand, slash arc, or scarf can otherwise shrink the body differently between frames. Establish a shared scale from the stable body/head, then position each pose relative to the common pivot. Compare native-size head height, shoulder width and feet baseline across frames.

### Required measurements

- Source/derivative byte hashes and dimensions.
- RGBA mode or indexed transparency; a format heuristic alone can be wrong.
- Alpha minimum/maximum and occupied bounds; inspect low-alpha haze separately.
- Exact cell/crop rectangles and frame count/order.
- Shared scale, integer placement and ground anchor.
- No clipping at cell edges, no neighboring-frame fragments, no labels.
- Palette/outline stability and body proportion stability.
- No baked weapons/effects in shared player body art.
- Tile repetition and edge continuity when relevant.

Do not threshold alpha blindly. It can erase cloth/hair detail or preserve diffuse halos. Record the threshold and verify the resulting edges against dark, light and checkerboard backgrounds at native and integer-upscaled size. Do not treat a checkerboard pattern painted into RGB as transparency.

Derivation manifests must reference permanent source and output paths. Temporary review directories are not the sole durable owner of accepted evidence. Backups may remain, but live profiles should point to intended production texture locations.

## 9. Godot integration

For entities use `Sprite2D + AnimationPlayer + external AnimationLibrary/resources`. Semantic runtime state selects the animation. Animation resources own texture assignment, frames, timing and presentation transforms. No manual runtime frame stepping or hardcoded image paths when existing resource ownership can do it.

Use Inspector-owned profiles/catalogs for buildings, NPCs, UI icons and effects. Use editor-authored `TileSet/TileMapLayer`, material resources, and scene composition for environments. Authoritative collision, navigation, action timing, damage and legal contacts remain independent of image pixels.

Keep aimable player weapons separate. After replacing body art, inspect sword/shield, bow and staff alignment in right and mirrored left presentation; a body-only atlas showcase does not prove hand/grip alignment. Check attack preparation/active/recovery, and compare the image to actual action events.

Atlas textures and repeating road materials need special care. Previous road attempts produced stretched bands. Standalone tile derivatives were used to avoid atlas-repetition problems; verify actual texture mode, UV scale, route width and joins. Preserve authored route geometry unless a separately verified layout defect requires change.

Do not change the world's structure count, path graph, collision, service anchors, or travel/discovery behavior merely to make a screenshot look populated. Ground coverage and prop placement remain explicit integration tasks even after the source sheet is accepted.

## 10. Renderer review and validation

The verified Windows binary for this workspace is:

```powershell
$GodotPath = 'C:\Users\LENOVO\Desktop\GodotC#\Godot_v4.6.2-stable_mono_win64_console.exe'
& $GodotPath --version
Set-Location 'D:\nicejourney\nicejourney'
& $GodotPath --headless --path . --editor --quit
& $GodotPath --headless --path . --script res://tests/test_project_resource_paths.gd
& $GodotPath --headless --path . --script res://tests/test_asset_provenance_manifest.gd
```

At verification it reported `4.6.2.stable.mono.official.71f334935`. Recheck availability in a new environment. A disconnected editor bridge or missing `godot` PATH command is not proof that Godot cannot run. The existing `tools/reference_validation.ps1` contains the configured executable path.

Headless tests and actual raster renderer checks serve different purposes. A static validation tool that reports no missing resources is not a rendering pass. Run renderer captures without `--headless`, allow import to finish, wait for rendering, and save the viewport image. Existing project capture scripts demonstrate this. Check the saved image itself. A tracked process may not expose a capturable top-level OS window; that does not prevent viewport capture.

Every capture needs the exact scene/resource, sprite/frame names, scale, engine/render mode, output dimensions and relevant asset hashes recorded. Show all reviewed subjects without clipping. Use multiple screens/pages instead of shrinking everything to illegibility. A screenshot containing one grass patch cannot validate six outskirts props. An old flat-color road screenshot cannot validate a newly textured road.

Run focused tests for the changed domain, then the broad gate after the integrated slice:

```powershell
powershell -ExecutionPolicy Bypass -File tools\reference_validation.ps1
```

Do not run release exports, packaged-build QA, or alter export presets for this asset task. A recurring invalid-profile save message is an intentional negative fixture only when the associated suite finishes successfully; do not generalize that exception to other errors.

The provenance test checks metadata schema and recorded paths. It does not prove every live PNG is registered, source hashes match, or the art looks correct. Add explicit hash/consumer coverage checks for the current slice. Never call a failure “pre-existing” without before/after evidence or a direct source-backed diagnosis.

## 11. Category-specific remaining-work guidance

### Player

Preserve the accepted identity and clean source rows. The seven clean nearest-neighbor states are idle, walk, run, dash, climb, pickup and sleep. Revised source candidates for attack, heavy attack, block, parry, cast and hit are recorded in the current-work section. Follow the final acceptance status there; generation alone is not integration.

Audit remaining dodge/interact/use-item/death states separately. Historical issues include baked effects and use-item/death frame-count discrepancies. Check the actual latest outputs before making a new revision. Keep held block state behavior distinct from its transition frames. Do not turn dodge into a roll.

### NPCs

Five recurring roles plus temporary escort identity are required: coordinator, merchant, blacksmith/upgrader, lore/story, variable quest actor, escort. The NPC bible is explicitly a proposed presentation decision. Recurring characters begin as one identity frame each. Proposed escort art uses four idle and six walk frames; wait→idle, follow/panic→walk are visual mappings, not new AI rules. Static identity acceptance does not finish escort animation or place every NPC into live service scenes.

### Enemies and boss

Preserve the twelve accepted archetype identities and existing generated sources. Their six canonical single-pose states are idle/move/windup/release/hit/death; Defender also has block. Do not claim they already have multi-frame motion, and do not invent mandatory frame counts absent authority.

The Tenth Warden uses two phases and five move families: Twin Cut, Warden Lunge, Arc Volley, Crescent Sweep, Punishing Step. Do not invent adds or healing. Verify current runtime bindings and approved geometry before drawing telegraphs. Arc Volley is dodgeable/blockable but not parryable; Crescent Sweep is unblockable and dodgeable. Recheck current source because combat implementation may advance independently of art work.

### Region 3 and interiors

Exactly eight functional and twelve decorative structures. Preserve the accepted building sources; decorative 11–12 have replacement exact sources rather than a repaired original corrupt ZIP. Props, ground/roads, ruins, outskirts and risk-zone sources exist, but source acceptance must be distinguished from complete world coverage.

Eight functional interior records remain distinct from façades and service menus. Before generation, define only the required reusable floor/wall/door/interactable kit and actual target scenes; do not create twenty bespoke interiors or arbitrary decorative rooms. Keep material consistency with accepted exteriors and route/collision readability.

### UI, items, weapons

There are 27 standalone class/quest/status/sigil/skill icons and one map sheet in the audited catalog. The eighteen skill icons must follow actual implemented names and meanings. Map sheet cells remain unresolved until their semantics and consumers are verified. Existing starter sword/shield/bow/staff art is not missing. Existing arrow/arcane projectile art may need a consumer rather than new generation. Do not invent equipment icons for a text-only UI without an actual requirement.

### Tower and VFX

Use one modular tower kit, with combat/safe/reward/vendor/secret/elite/objective/boss room language. Nine base tower visual records do not mean nine unrelated full scenes or ten separate tilesets. Validate floor composition and telegraph contrast.

Reuse accepted VFX primitives where possible. Five boss telegraph gaps in the original audit may be wiring gaps, not image gaps. Status visuals must represent Burn and movement Slow without implying unsupported critical multipliers, global time stop, cast slowdown or AI slowdown.

## 12. Agent coordination and failure prevention

| Risk | Required prevention |
| --- | --- |
| Whole-repository context overload | Assign a narrow category, exact paths, acceptance task and bounded reads |
| Identity/style drift | Attach accepted pixels; state identity locks; compare at gameplay scale |
| Prompt polluted by coding/status context | Use the minimal visual packet and subject-only prompt |
| Filename mistaken for semantics | Inspect source pixels and crop mapping |
| Replacing already accepted art | Require a proven defect and preserve before/after hashes |
| Color/scale noise across frames | Shared scale and palette checks, contact sheet and loop playback |
| Baked equipment/VFX | Separate body, weapon, projectile and effect ownership |
| Missing or truncated source | Verify source and destination hashes; recover exact saved bytes |
| Fake alpha or halos | Inspect alpha channel and contrasting backgrounds |
| Atlas/cell contamination | Explicit actual crop rectangles, gutters and complete edge inspection |
| Repeating texture bands/seams | Standalone tile where needed; repeated renderer review |
| Sparse/clipped evidence | Full native-scale showcases plus actual consumer captures |
| Simultaneous shared writes | Single coordinator for manifest/provenance/state; bounded file ownership |
| Import races | Coordinate editor import, then run domain tests against settled files |
| False test success | Record actual command/exit/log; distinguish static, headless and renderer checks |
| Premature cleanup | Retain source, backup and evidence until consumer and gate acceptance |
| Legal/provenance overclaim | Record real source terms/category; schema acceptance is not legal review |

Each agent returns exact changed paths, source/output hashes, crop/derivation data, actual tests and exit codes, complete renderer captures, acceptance decision, remaining blockers and next action. A confident summary without those artifacts is not a production handoff.

## 13. Resume procedure for the next agent

1. Read this guide's current-work snapshot and the records for the domain you will own.
2. Open the actual project and read instructions. Check for newer files or concurrent work before editing.
3. Reconcile current consumer paths and hashes with the attached manifest; treat this guide as a dated snapshot.
4. Select the highest-priority record whose dependencies are satisfied. Do not reopen completed art merely to generate something.
5. Prepare one verified visual brief and attach exact reference pixels.
6. Generate/edit; inspect; preserve; derive; integrate; render; test; update records.
7. On interruption, persist the exact incomplete stage and recover bytes before regenerating.
8. Continue until the user's current scope is complete; report remaining work truthfully.

The complete inventory appendix follows the verified current-work snapshot. All retained fields are included so another agent can continue without guessing missing details. Historical values are separated under `prior_audit_snapshot` when this handoff corrects them. The companion JSON is the same dated inventory in machine-readable form.


## 14. Final current-work snapshot and existing-image authority

This section controls interpretation of older inventory prose. It records the final inspected state, not an assertion that all223 assets are complete. No more image generation was performed after the user's stop instruction. Work stopped at the guide handoff boundary.

| Slice | Final verified state | Next action, without regenerating existing sources |
| --- | --- | --- |
| Region3 five support atlases | Exact sources and derivatives preserved; complete fresh Godot catalog reviewed; four focused gates passed; provenance registered | Finish complete world coverage/placements separately. Do not replace accepted atlases. |
| Six NPC identity anchors | Production textures/profiles live; source derivation reproduced6/6 byte-identically; both-facing presenter/resource test passed; fresh640×360 renderer reviewed | Verify live NPC placement/quest/service consumers. Escort idle/walk animation remains separate. |
| Eighteen skill icons | Distinct32×32 V02 icons wired through profiles; real28-profile UI catalog reviewed; focused tests passed; provenance registered | Preserve artwork. Review future real-screen layouts independently. |
| Nine core UI icons | Generated source already exists and live icons are visible; old backup hashes differ from current output hashes | Fix source-to-derivative metadata using the actual core source. Do not treat old backup PNGs as original generated sources. |
| Seven clean player states | Runtime V03 files equal NEAREST candidates; old LANCZOS bytes preserved | Preserve. Complete representative current weapon/runtime acceptance as necessary. |
| Six revised player states | Four clean body-only source images exist, covering attack/heavy/block/parry/cast/hit. V04 derivatives staged; original V03 runtime bindings retained | Current reviewed derivation is rejected: neighboring blue fragments and per-pose body-size changes. Re-crop/rederive at common scale from the existing sources. Do not regenerate them to fix derivation errors. |
| Decorative buildings11–12 | Exact replacement sources, derivatives and provenance exist; earlier work reported focused success | Reconcile complete acceptance evidence against actual current hashes; do not regenerate accepted-looking originals or claim the old corrupt ZIP was recovered. |
| Remaining tower/boss/interiors/escort/map and other audit records | See all223 records below; not finished in this slice | Resolve per-record dependencies, then continue only when tasked. |

The obsolete `ACCEPTED_CANDIDATE_STAGED_V04` wording in a player slice registry is not production acceptance. Root visual review rejected those gameplay derivatives. The complete source PNGs remain useful and must be retained.

### Concrete evidence and limitations

- Support full catalog: `res://docs/evidence/art/region3_support_v02/renderer/region3_support_catalog_complete.png`; all16 props,7 ground tiles,7 ruins,6 outskirts and6 risk subjects are visible. The eighth ground/ruin atlas cells are empty. Captured with the real Godot4.6.2 Compatibility/OpenGL renderer. Atlas review does not certify full world ground coverage.
- Support focused passes: `test_region3_environment_dressing.gd`, `test_region3_authored_town_layout.gd`, `test_project_resource_paths.gd`, `test_visual_asset_inventory.gd`. Logs and hash records are in `docs/evidence/art/region3_support_v02/`.
- NPC evidence: `res://docs/evidence/renderer/npc_identity_anchors_v01.png`; actual640×360. `res://tests/test_npc_identity_anchor_resources.gd` passed with0 failures. `res://tools/art/derive_npc_identity_anchors_v01.py` exists and reproduced the six production hashes. An earlier subagent statement that the script was missing was wrong and the metadata was corrected.
- UI renderer: `res://artifacts/ui/ui_icon_catalog_showcase_v02.png`,1280×720; screenshot includes28 catalog entries, including the still-provisional map sheet. Skill derivation script: `res://tools/art/derive_ui_skill_icons_v02.py`.
- UI focused results include catalog/showcase, inspector authoring, skills menu, skill HUD, skill tree and resource-path passes. The HUD regression's expected text was corrected to reflect executable **PLAYTEST Ready** skills; root reran `test_combat_hud_ui.gd` and observed `COMBAT HUD UI TEST PASS`. Do not repeat the older failed assertion as the current result.
- Player rejected review: `res://docs/evidence/renderer/player-v04-revised-renderer-review.png`. This is diagnostic evidence, not the style anchor. Use the preserved full-resolution source PNGs listed below as edit/reference inputs.
- No fresh complete repository-wide regression was completed for this final frozen slice. Do not claim a new all-tests-green gate. No release export was run.

### Reference-selection rules specific to the existing images

1. **Player:** attach the exact V03 source row/identity plus the relevant body-only V04 source when correcting its derivative. Preserve the brown-haired, blue-scarf character. Do not attach the rejected tiny gameplay derivative as the only image reference.
2. **NPC:** attach `npc_identity_anchors_source_v01.png`; for a future escort animation, isolate the actual escort identity in the sixth cell as the identity anchor. The player reference supplies scale/style only, not the escort's face/clothing.
3. **Region3 buildings:** use accepted functional/decorative exact sources from the inventory, matching roof, timber and stone materials and authored perspective. Use11–12 sources for those exact buildings, not as permission to replace01–10.
4. **Environment:** use the existing town props, ground/roads, ruins, outskirts and risk sheets below. Ground-repeat/coverage bugs are integration/derivation tasks first.
5. **UI:** attach the existing class sheet for the relevant skill set or the core9 sheet. Match glyph weight, palette and silhouette; do not redesign the icon family.
6. **Enemy/VFX/tower:** use per-record `reference_assets` and actual accepted source pixels. A placeholder tower sheet is a layout/material constraint, not proof of accepted final style.
7. If source bytes are unavailable to the next agent, recover the saved image/source from the repository or user-provided artifacts. Do not invent a visual identity from this text alone and call it a match.

No workflow can guarantee that a different generator/context will reproduce an image exactly. The reliable controls are real image references, narrowly specified allowed changes, immutable sources, deterministic derivation, side-by-side checks and rejection of drift. Similar wording alone is insufficient.

### Preserved source index

The following files were directly checked for existence, dimensions and SHA-256 during guide preparation. The index includes the previously accepted decorative01–10 sources and the later generated sources. Source presence is not blanket production acceptance; use the status table and detailed record.

| Exact existing source path | Pixels | SHA-256 |
| --- | --- | --- |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_01_source_v02.png` | 1254×1254 | `9ad69a1efd6cbcdc37e2c06d0aeb310999eec4bb398ded4c46b39289a443041e` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_02_source_v02.png` | 1254×1254 | `d02d43a1b5c403ab55748c1f85785fe1718a1f7356c4de964dac767542527b72` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_03_source_v02.png` | 1254×1254 | `10249f6c32ae4753bb4a7742df0c9e6f4a52a5fb1953c66360bca074bbe53962` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_04_source_v02.png` | 1254×1254 | `bf940a38c76b3c3bd02eb6ebac52b1a2e1846d19d798547c97e96290b129b934` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_05_source_v02.png` | 1254×1254 | `0cac7e66753cc3ff6693eb0a8d84b7cd01af32a75893a0c33114aaf130893f39` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_06_source_v02.png` | 1254×1254 | `6172462564d60088d6aa2fcedec99dbb08d94e9e7e3e926456a7bea589b85ba1` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_07_source_v02.png` | 1254×1254 | `a4de40b0f5322a18a6ca25f75f762358a093f7f8e8144e07eb3f626100a880b1` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_08_source_v02.png` | 1254×1254 | `e4309c59f5a61b7b781adb84ff574d0fa453af3965e71b413f40893e40743b46` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_09_source_v02.png` | 1254×1254 | `08725d8a0384ea841dc5e52d075f141b6d10c36db91ca31ba81c59d988ea8e0f` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_10_source_v02.png` | 1254×1254 | `a766705bbdbca6cc53b7e528525742d2443ba3284e7d63b9e77c69ad6347d0f1` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_11_source_v02.png` | 1254×1254 | `aabb161d761c8c5ab1cb6900f1833313ec3fecebddcfffb38d70a0aec87495ae` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_12_source_v02.png` | 1254×1254 | `b0cab34d330b0a4b9b9bcf1eb4b638d39ac5d68efb4e0f47b213f9a0f9ed641d` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_ground_road_source_v02.png` | 1536×1024 | `fc91162145aa62a96bfb27feb492ed633a5f8406626b932cdc1d99b0c5a179c6` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_outskirts_support_source_v02.png` | 1536×1024 | `a15113a146175dd2a3402426ff0609adc98b50a60da7cd2fb21044398d510e23` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_risk_zone_support_source_v02.png` | 1536×1024 | `aa015bd738d5f6396a107b8bce8a9fdfc1ec3237c8a7e5b34d8f5755ef8afe88` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_ruins_modules_source_v02.png` | 1536×1024 | `22c4ef9a95c2606a69673b19fa951f10adf2a88d7324b5c7d04b7ebc4a59b715` |
| `res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_town_props_source_v02.png` | 1254×1254 | `81dbc0dbc6d55550e902a1ade7eb7981de77853fbbab2e661200ef90042880e4` |
| `res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png` | 1254×1254 | `bd0cb8c1895eeb855b53a79ca0676c17222737c62fe0f74915d0b07a9290465c` |
| `res://assets/art/generated_sources/imagegen/ui/ui_mage_skills_source_v02.png` | 1536×1024 | `08d734d828d7830e3a2ee213be860ff3b05b0262ef72373236d354ee3c72ef48` |
| `res://assets/art/generated_sources/imagegen/ui/ui_melee_skills_source_v02.png` | 1536×1024 | `8968ffc7e582a396feed57625d556dbc64f12a532757a3ed3ec9cf66b135cb34` |
| `res://assets/art/generated_sources/imagegen/ui/ui_ranged_skills_source_v02.png` | 1254×1254 | `683bdd6a113d9f052b10b4dd285f0e6ec3a4d68bb5f20fc4002a91aa22890467` |
| `res://assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png` | 1536×1024 | `81f13fa706293b678f64d2f4bb163324b02c7b036eadf59dd3b80b6af551e23b` |
| `res://assets/art/generated_sources/imagegen/player/body_only_v04/player_attack_body_only_source.png` | 2171×724 | `07da238fa35537841cfc7f6ae2b014b90261329e8f605a2b1de92e3648564fb7` |
| `res://assets/art/generated_sources/imagegen/player/body_only_v04/player_block_body_only_source.png` | 2171×724 | `6aa6886811226d155c1a088f328ee2b07ceb9f551f95b9b546865189974887bf` |
| `res://assets/art/generated_sources/imagegen/player/body_only_v04/player_heavy_attack_body_only_source.png` | 2171×724 | `af670f93bfc622ed45d76e96227b8710662a17380ed69346171151f5e5abe3df` |
| `res://assets/art/generated_sources/imagegen/player/body_only_v04/player_parry_cast_hit_body_only_source.png` | 1448×1086 | `514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef` |

### Exact prompts for the four latest body-only sources

These are the recorded prompts actually used, not requests to generate them again. Original source identities and reference regions remain in `source_intake.json`. Original prompts for older sheets are not reconstructed or fabricated.

#### `player_attack_body_only_source.png`

Source identity: `exec-c1feb7d2-9448-4453-bace-d26074b87683.png`. SHA-256: `07da238fa35537841cfc7f6ae2b014b90261329e8f605a2b1de92e3648564fb7`. Reference: `../main_character_batches_v03/exact_sources/05_climb_sleep_death.png`. Reference crop XYXY: `[0, 300, 1448, 535]`.

```text
Edit the referenced six-frame pixel-art character attack strip. Remove only every sword blade, hilt and blue-white slash trail; reconstruct empty brown-gloved hands where hilts were held. Keep the exact same six body poses, brown spiky hair, face, blue scarf, cream sleeves, brown leather vest and gloves, blue trousers, brown boots, proportions and palette. All six face right. Preserve the attack progression, with distinct preparation, extension and recovery. Six evenly spaced full-body frames in one horizontal row, aligned feet baseline, no cropping, generous transparent margins. Real transparent background instead of grey. Crisp 16-bit-inspired pixel art. No weapons, shields, magic, particles, glow, text, labels, borders, dashboard or UI. Body-only sprite animation strip.
```

#### `player_heavy_attack_body_only_source.png`

Source identity: `exec-302ff3ff-952c-46b2-bc10-53f319ab29a3.png`. SHA-256: `af670f93bfc622ed45d76e96227b8710662a17380ed69346171151f5e5abe3df`. Reference: `../main_character_batches_v03/exact_sources/05_climb_sleep_death.png`. Reference crop XYXY: `[0, 545, 1448, 815]`.

```text
Edit this six-frame pixel-art heavy-attack character strip: erase every sword blade, hilt, blue-white slash arc, ground impact and spark. Reconstruct empty brown-gloved hands only where weapons were held. Preserve the same six full-body poses and their motion: raised-hand preparation, overhead windup, downward swing, low follow-through, recovery, idle. Preserve brown spiky hair, face, blue scarf, cream sleeves, brown leather vest/gloves, blue trousers/boots, palette, proportions and head size. Six evenly spaced right-facing sprites in one horizontal row, same ground baseline, fully uncropped with transparent margins. Transparent background, crisp pixel art, body only. No weapons, effects, glow, text, labels, borders, dashboards or UI.
```

#### `player_parry_cast_hit_body_only_source.png`

Source identity: `exec-1baccda5-161d-42c4-a822-33e5a277d374.png`. SHA-256: `514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef`. Reference: `../main_character_batches_v03/exact_sources/03_parry_cast_hit.png`.

```text
Edit this pixel-art sprite sheet by removing ONLY the visual effects: all blue-white shields, arcs, magic orbs, projectiles, particles and yellow hit stars. Preserve ALL body poses exactly and reconstruct any obscured glove/cloth behind effects. Same brown-haired traveler, blue scarf, cream sleeves, leather vest, gloves, trousers, boots, palette and proportions. Keep three horizontal rows: top six parry poses, middle seven casting poses, bottom six hit-reaction poses. Preserve original pose count and motion order, even spacing and ground baseline in each row. Real transparent background instead of grey. Full characters uncropped, crisp pixel edges. No weapons, glow, effects, particles, text, labels, borders, dashboards or UI.
```

#### `player_block_body_only_source.png`

Source identity: `exec-f1524c55-bbe9-43fc-8d15-7c9190c57952.png`. SHA-256: `6aa6886811226d155c1a088f328ee2b07ceb9f551f95b9b546865189974887bf`. Reference: `../main_character_batches_v03/exact_sources/05_climb_sleep_death.png`. Reference crop XYXY: `[0, 840, 1448, 1070]`.

```text
Edit this seven-frame pixel-art blocking character strip. Remove ONLY every blue translucent shield arc and glow. Preserve all seven body poses, gloved hands, face, brown spiky hair, blue scarf, cream sleeves, brown leather vest, blue trousers and brown boots exactly. Same right-facing traveler and same proportions, colors and motion sequence. Seven evenly spaced full-body sprites in one horizontal row with consistent baseline and transparent margins, no cropping. True transparent background instead of grey. Crisp pixel art. No shield, weapons, effects, magic, particles, text, labels, borders, dashboard or UI.
```


## 14A. Resumed-production delta — 2026-09-20 (supersedes the frozen counts below)

**Use `Nice_Journey_Asset_Handoff_Manifest.json` and `nicejourney/docs/art/ASSET_PRODUCTION_MANIFEST.json` for CURRENT classifications.** The original §14 and §15–appendix remain a dated source/audit snapshot; their `152 accepted / 36 revisions` numbers and their “no broad gate” sentence are no longer current. The two mutable JSON inventories have 223 identical stable IDs, identical per-ID classification, and current counts: **178 ACCEPTED_DO_NOT_REGENERATE; 12 EXISTS_NEEDS_REVISION; 18 PLACEHOLDER; 8 MISSING_GENERATE; 1 ANIMATION_REQUIRED; 1 TEXTURE_TILE_REQUIRED; 5 VFX_REQUIRED.** Run `python tools/art/check_asset_handoff_inventory_alignment.py` from the inner Godot project after every change. No already accepted generated-source PNG was replaced in the resumed work.

The resumed run closed **nine UI-core source-provenance revisions**, **two Region 3 decorative 11/12 revisions**, **four live static-NPC consumer revisions**, and **seven clean player NEAREST source/runtime revisions**. Core UI icons now reproduce exact current PNG bytes **9/9** from the immutable 1254×1254 generated source: row-major full 418×418 cell, direct PIL RGBA NEAREST downsample 32×32, PNG `optimize=False`; unlike the separate 18 skill icons, no alpha-bounding, 28px thumbnail or added padding. The `ui_skill_icon_v02_derivation_manifest.json`, source-path provenance and both 223-entry inventories were reconciled. Verification: `tools/art/verify_ui_core9_exact_derivation.py`, `tools/art/reconcile_core9_exact_acceptance.py`, UI catalog renderer and focused tests. Decorative 11/12 exact source/160×160 output hashes, live profiles and fresh 640×360 renderer captures are recorded by `tools/art/reconcile_region3_decorative_11_12_acceptance.py`. Actual static NPC images are visible at the existing Quest Hall, Blacksmith and Merchant service anchors and in both Region3 and Tower escort consumers; `tools/art/check_npc_live_renderer_v01.py` checks **5/5** real captures against source pixels. Story/lore and variable-quest actors remain unplaced; do not invent their anchors.

The tower **existing placeholder** 4×4 atlas is now a real Inspector-owned TileSet/TileMapLayer consumer on rooms **and graph-link routes**. `src/world/tower/presentation/tower_common_floor_tileset_v01.tres`, `tools/art/build_tower_floor_tileset.gd`, and the renderer captures `docs/evidence/renderer/tower-floor-atlas-v01-review.png` and `tower-floor-1-connected-route-review.png` document it. This is **not** visual acceptance of a new tower atlas or the eight 96×96 provisional room stamps; `TEXTURE_TILE_REQUIRED` and eight `PLACEHOLDER` records remain open. The actual Ranged and Mage projectile sprites have distinct Inspector scenes and pass action/scene checks. The **precise normal-live visibility blocker** is `combat_hud.tscn`'s CanvasLayer 20 Panel x8–348/y8–244 covering projectile screen positions x286–307/y180; test-only hiding that panel proves real-live source pixels 20/20 arrow and 119/119 arcane, without changing gameplay or HUD. Both projectile revisions remain open until the actual HUD occlusion/layout is resolved and reviewed, not because new sprite generation is needed. The ten player R2 candidate states have 50 real native Godot comparison renders with correct pixels/equipment layers, but body/weapon/effect quality and frame-count compatibility are unapproved; **10 player animation revision records remain open**. The seven live clean NEAREST idle/walk/run/dash/climb/pickup/sleep states have **84** actual Godot renderer pages, 341,730/341,730 near-opaque source-pixel matches and full right/left equipped coverage. Their obsolete LANCZOS manifest hashes were corrected, and their existing clean source/runtime art slices accepted, without asserting independent subjective glove/anatomical grip approval. Neither rejected V04 art nor unreviewed R2 art was bound to the live player.

**Projectile acceptance correction to the preceding historical paragraph:** Ranged and Mage projectile source/presentation art is accepted on actual HUD-intact basic/Q travel *outside* the HUD rectangle, not blocked on generation or renderer verification: Ranged centers (366.67,180)/(408.33,180) each source pixel check 20/20; Mage (366,180)/(419.17,180) each 119/119, all before range/lifetime expiry. The HUD still occludes launch x250–307/y180 and remains a separate HUD-layout issue. `tools/art/reconcile_projectile_normal_hud_acceptance.py` and `artifacts/combat/player_projectile_{ranged,mage}_v02_normal_hud_clear_renderer_evidence.png` record the limited acceptance; no source PNG or combat/HUD code changed.

Eight Region3 interiors still need actual material art and explicit room/door/return/interactable geometry before playable scene claims; `tools/art/region3_interiors/interior_art_packet_draft_v01.json` contains eight exact source-backed IDs and clearly **PROPOSED** target paths, with unavailable geometry null. Escort has a live static anchor, **not** the required genuine 4-idle/6-walk animation; animation remains P0 open. Five Tenth Warden telegraphs are visual-only candidates in `tools/art/boss_telegraph_review/`, **not** final production bindings; all five lack approved final timing/geometry. The ten boss identity/motion pictures still lack an approved generated character source. The four-cell map sheet requires approved cell semantics/consumer; the application icon lacks a product brief. None of these open items should be marked accepted just because a fixture exists.

The later map-marker **review-only** sheet `res://assets/art/ui/markers/review/map_marker_quest_sigil_v02_candidate.png` is 128×32, SHA-256 `e918f083ae5e1110faed8538112a2b6bb5f973bc367d19234aa26ac7ad5eeb94`. Its four unchanged 32px cells link exactly to the accepted ImageGen core9 Escort, Tower Defense, Annihilation, and Tower Sigil icons, in that order; provenance and unresolved semantic availability are in the adjacent JSON. `tools/art/build_map_marker_quest_sigil_candidate.py` reproduces exact bytes, and `tools/art/verify_map_marker_quest_sigil_candidate_native.py` checks 1,539/1,539 alpha≥192 source-composited pixels (max RGB deviation 1) against a real GL Compatibility 640×360 preview in `docs/evidence/renderer/`. This is neither an approved four-cell live mapping nor acceptance of the original `map_marker_sheet_v01.png` PLACEHOLDER: Region3 quest-marker coordinates are still unauthored and map travel remains unavailable. Two unplaced NPC roles have Inspector proposal resources under `src/world/npc/presentation/profiles/`; their validation explicitly requires a valid authored town, actual static 32px NPC art, independent actor/quest authority and a distinct live scene-owned actor. They remain unplaced. The latest completed broad-gate evidence `docs/evidence/reference-validation-latest.json` records **283 test manifest entries, 285 validation result entries, zero failing results**; these are different counts, and the focused map/NPC tests and native review ran afterward.

The latest player R2 art verification regenerated its own objective renderer evidence and rechecked six V04 and four V03-derived candidate sheets. The exact 32px source slices and 50 captured native renderer combinations agree, but those comparisons do not prove that body-connected effects, anatomy, hand grip, or final movement quality are approved. None of ten is newly promoted. Current concurrently edited `player_body_animation_library_v04.tres` has **five hit frames**, unlike the historical six; block still has seven while the isolated R2 block candidate has only three. A separate 8–12-frame death source, clean unique block poses, and art-level review of other revision states remain required. Do not reclassify source integrity as final visual acceptance.

After meaningful integration, `tools/reference_validation.ps1` completed **282 tests, 0 failures**, Godot 4.6.2 GL Compatibility editor parse and renderer smoke PASS; machine-readable results are in `docs/evidence/reference-validation-latest.json`. Later focused source/runtime metadata checks also passed. Reference performance is not final minimum-hardware or image-quality certification. The past failed assertions and provenance ambiguities documented in §14 are historical only and are not new acceptance evidence.

Following the 2026-09-20 GitHub sync (`main` commit `1dc3706`), Tower escort presentation now selects `wait` or `follow` from the existing persisted wait request and actual physical movement, mirrors on real horizontal travel, and avoids replaying the same looping animation every physics tick. This **does not** generate escort motion: `temporary_escort.tres` still references a single accepted static 32×32 source, the runtime does not fabricate idle/walk frames, and `npc.temporary_escort_actor.animation` remains P0 `ANIMATION_REQUIRED`. `test_tower_escort_runtime.gd`, `test_npc_identity_anchor_resources.gd` and `test_npc_live_consumer_bindings.gd` passed after this code change; the follow-up `tools/reference_validation.ps1` gate subsequently completed **283 tests, zero failures**, Godot 4.6.2 GL Compatibility, with evidence in `docs/evidence/reference-validation-latest.json`. Two attempted tower-material image-generation calls produced dashboard/infographic images instead of tile art; both were rejected and **never transferred, accepted or committed**. Per the generation failure protocol, move that next art generation to a fresh image-only context with the exact accepted visual reference; do not keep retrying in this contaminated engineering chat.

**Map marker sheet V02 acceptance (supersedes the review-only verdict in the earlier paragraph):** `res://assets/art/ui/markers/map_marker_quest_sigil_v02.png`, SHA-256 `e918f083ae5e1110faed8538112a2b6bb5f973bc367d19234aa26ac7ad5eeb94`, is the unchanged 128×32 exact-source derivative of four accepted ImageGen core9 glyphs. `tools/art/promote_map_marker_quest_sigil_v02.py` checks deterministic original-source identity; its adjacent JSON records provenance and semantic cell ownership. Both `src/ui/presentation/profiles/map_marker_sheet.tres` and **actual** `src/ui/map_menu.tscn` now Inspector-bind this production sheet; the latter draws four independent NEAREST 32px `AtlasTexture` cells with readable Escort, Defense, Annihilation, Sigil labels and an explicit legend-only/unavailable-location/travel notice across map layers. Actual Godot 4.6.2 GL Compatibility Region-map 640×360 capture: `docs/evidence/renderer/map-marker-live-menu-native.png` and adjacent JSON; `tools/art/verify_map_marker_live_menu_native.py` checks **1,515/1,515** near-opaque source pixels, maximum RGB deviation 3. The separate legacy `map_marker_sheet_v01.png` and original review source remain preserved; `tools/art/audit_ui_map_marker_placeholder.py` verifies the historical V01 while acknowledging its replacement in the live profile/catalog. One previously `PLACEHOLDER` visual record is now **ACCEPTED_DO_NOT_REGENERATE for source art plus real read-only legend only**. Region3 quest-marker coordinates/discovery remain unauthored and the map still cannot execute travel; neither geographic marker placement nor travel was promoted. Current totals: **177 accepted / 46 open**. The historical §15–appendix remains a frozen audit; both mutable JSON manifests have the revised per-ID status. `tools/art/reconcile_map_marker_legend_acceptance.py` and `tools/art/check_asset_handoff_inventory_alignment.py` verify the acceptance boundary. Following this exact integrated slice, `tools/reference_validation.ps1` completed **283 tests, zero failures**, on Godot 4.6.2 GL Compatibility, with latest results in `docs/evidence/reference-validation-latest.json`; no release export was run.

**P0 escort-animation intake update (generation still required):** Exact accepted static identity is both `res://assets/art/npc/escort_anchor_v01.png` and its preserved `res://assets/art/generated_sources/imagegen/npc/review/npc_escort_anchor_v01.png`, SHA-256 `2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e`. Provide the **actual static image** as an image-only visual reference for controlled generation in a fresh art context: same distinct civilian/traveler identity, coat/body/hair colors, silhouettes and 32px ground/side-facing convention; two independent source outputs, genuine **four-frame idle** and **six-frame walk**, ordered, even-spaced, right-authored/left-mirrored, transparent RGBA, no text, frames, background, dashboard, unrelated figures, decorative weapons, fake duplicate poses, or per-frame color noise. Inspect true motion/loop and original character likeness manually; preserve each generated source with SHA-256 before deriving. The proposed gameplay derivative convention is 320×32 (32×32 idle cells 0–3, walk cells 4–9) with stable ground anchor (16,29); do not demand an arbitrary image-generation source resolution. `NpcVisualProfile` now rejects the wrong ten-cell sheet geometry, missing/extra/non-looping or incorrectly timed `NpcSprite:frame` animations, wrong wait/follow/panic state maps, duplicate body images, one-pixel pose noise, empty bodies and nontransparent corners **only when an animation is assigned**. `tests/test_escort_animation_intake_gate.gd` exercises those failures with SYNTHETIC TEST-ONLY graphics; it is **not** evidence of accepted animation. `tools/art/reconcile_escort_animation_readiness.py` records the proposed intake and static hash in both manifests while leaving `npc.temporary_escort_actor.animation` at P0 `ANIMATION_REQUIRED`; the real live sprite still has no animation library. Completion additionally requires real-source visual acceptance, source/derivative SHA/provenance, Inspector-bound external AnimationLibrary, actual Tower/Region gameplay renderer review and final Godot tests. Do not substitute generated stand-ins from this synthetic test, stretch the single accepted anchor into repeated cells, or confuse mechanical follow/wait state with body motion.

**Application icon V02 acceptance (prototype identity only):** The project previously used the default `res://icon.svg`; this file is preserved untouched for regression. `res://assets/art/ui/application/application_icon_tower_sigil_v02.png` is an exact 4× nearest-neighbor 128×128 RGBA enlargement of the accepted 32×32 generated-core9 `res://assets/art/ui/markers/tower_sigil_icon_v01.png`, source SHA-256 `1dfeea179a0df7320388fcfadba55e715d367656be4e6585a756b14b99a70b39`, output SHA-256 `26d6b6318856e04bae3b2c32adbce24e5f0c79fa411b9fa7706d2b03fee9f185`. There is no invented brand art, repainting, new symbol or typography. The existing project application icon setting now references this PNG; its exact derivation and transparent pixels are reproduced by `tools/art/build_application_tower_sigil_icon.py`, and actual Godot 4.6.2 GL Compatibility native 128×128 evidence is `docs/evidence/renderer/application-icon-tower-sigil-v02-native.png` plus adjacent JSON. `tools/art/verify_application_icon_native.py` checked **5,104** opaque source pixels (maximum RGB deviation **3**) and preserved source alpha across the screenshot. `tests/test_application_icon_project_binding.gd` verifies the live project setting, imported original/sigils and legacy SVG preservation. Both mutable manifests and provenance recognize **`application.icon` accepted for reversible source-backed Godot prototype project icon only**. This does **not** approve a final product logo, trademark, multi-size platform icon, OS-packaged executable, release export, or final branding. The total is now **178 accepted / 45 open**; the 45 remaining records still need their genuine art sources or independent geometry/placement/timing authority.

The completed project-wide `tools/reference_validation.ps1` gate **after** the application-icon integration discovered **285 tests with zero failures**, Godot 4.6.2 GL Compatibility. Machine-readable results: `res://docs/evidence/reference-validation-latest.json`. No export preset, release build, packaged application icon or `.gitignore` modification was performed.

**Player interact/use-item R3 partial-source recovery (review only):** `tools/art/derive_player_detached_vfx_v03_r3.py` verifies the preserved immutable generated V03 source and unchanged V03 R2 derivatives before isolating only demonstrably detached pixels: interact frame **2** has three orange spark components totaling **10 pixels**, and use_item frame **5** has two cyan particle components totaling **10 pixels**. The separate RGBA body/VFX review PNGs and exact per-file SHA-256s are in `res://assets/art/player/animations/review_r3/player_detached_vfx_v03_r3_candidate_manifest.json`; neither the five interact nor seven use_item frame counts was altered. `tools/art/check_player_detached_vfx_v03_r3.py` independently verifies every source/derivative hash and exact full-sheet lossless RGBA recomposition. `tools/art/capture_player_detached_vfx_v03_r3.gd` renders **eight** non-headless Godot 4.6.2 GL Compatibility pages from isolated copies of the **actual Player scene** with body and separate effect layered at the body pose, with no equipment and actual melee equipment, right/left, at 1×/2×. `tools/art/check_player_detached_vfx_v03_r3_native.py` verified **245,760/245,760 exact source-versus-split screenshot RGBA pixels** and independently matched **35,360** near-opaque source pixels. These results establish a lossless separable *candidate*, not independent sprite/anatomy/pose approval or a newly approved effect trigger/timing. The separate layers were **not** bound to gameplay; no live AnimationLibrary or accepted/generated source PNG was replaced. Both records remain `EXISTS_NEEDS_REVISION`; use_item still has seven frames versus its 4–6-frame visual-bible range, and other player state defects remain. `tools/art/reconcile_player_detached_vfx_r3_readiness.py` records only candidate evidence in both current manifests; totals remain **178 accepted / 45 open**.

**V04 R2 six-state source-boundary audit:** `python -B tools/art/audit_player_v04_r2_detached_components.py` verifies immutable generated-source and candidate SHA-256 identities before inspecting every 32px `attack`, `heavy_attack`, `block`, `parry`, `cast`, and `hit` candidate frame. At alpha ≥24 each of the **33** selected source-backed frames has exactly one 8-connected foreground region, with **zero** low-alpha or detached pixel islands. Thus the safe R3 *detached-island* method cannot separate any marks still connected to the actor in these six candidates; **do not apply a blue/color-wide eraser to the shared scarf/trousers, or assert that a connected weapon/effect was removed**. This is a connectivity finding, not proof that the six bodies are visually clean or completed. `block` retains three selected R2 source poses (out of seven source poses), `hit` five (out of six); neither is padded to match historical runtime counts. Genuine controlled visual source revision or independently reviewed surgical reconstruction is still required where art defects are present. No production textures or inventory classifications changed.

**Unselected real V04 pose recovery — candidate only:** The preserved V04 ImageGen body-only originals contain **seven** `block` body poses and **six** `hit` body poses; the earlier R2 sheets had selected only indices `[2,3,4]` and `[1,2,3,4,5]` respectively. `tools/art/derive_player_v04_omitted_source_pose_review.py` now exposes **all 13 original source poses** in two separately named 32px, uniformly scaled nearest-neighbor **review-only** sheets in `res://assets/art/player/animations/review_v04_full_source/`. The five previously unselected generated poses are block indices `[0,1,5,6]` and hit index `[0]`—none is interpolated, duplicated, or painted in. The original eight selected R2 pose pixels remain exact; all 13 exposed frame RGBA hashes are distinct. `tools/art/capture_player_v04_omitted_source_review.gd` captured **eight actual Windows GL Compatibility Player-scene pages**, right/left at 1×/2× with/without real melee equipment. `tools/art/check_player_v04_omitted_source_review.py` checks **41,620** alpha≥245 source pixels within bounded native rendering tolerance (maximum RGB delta 7.8824/8, **100** fully opaque pixels exactly matching) and **52** real equipment-overlay frame samples; this is a rendering/source-integrity result, not artistic pose/weapon acceptance. Exact original/generated/R2/output hashes and renderer evidence are in `player_v04_full_source_pose_review_manifest.json` and `engine/player_v04_full_source_native_evidence.json`. `tools/art/reconcile_player_v04_omitted_source_review.py` records only this partial evidence in both mutable manifests: `block` and `hit` remain `EXISTS_NEEDS_REVISION`, their live AnimationLibrary is unchanged, unselected pose art/timing need independent visual approval, and totals remain **178 accepted / 45 open**. Do not bind the full sheets, append them to live hit/block timing, or claim the five poses solve connected VFX/anatomy concerns simply because they came from an actual generated source.

## 14B. 2026-09-21 resumed production — source candidates and verified review boundary

The later user instruction to continue asset generation supersedes the historical stop-image-generation instruction in the 2026-09-20 handoff. Continue to use the current 223-ID mutable JSON manifests and the source/consumer/renderer acceptance gate, rather than interpreting newly generated pixels as an automatically accepted production asset.

**Code and tower review already delivered:** GitHub `main` commit `6123c11` adds Region 3 escort `wait`/`follow` presentation driven by real physical displacement, left mirroring, and focused behavioral checks; the native Tower V01 floor-rim derivation remains explicitly review-only and unbound. The post-change Godot 4.6.2 GL Compatibility reference gate discovered 286 tests, reported zero failing results, and recorded evidence in `nicejourney/docs/evidence/reference-validation-latest.json`. The tower derivative cannot resolve the still-provisional final tower floor kit. No original accepted V01 image, TileSet, master contract, or `.gitignore` was replaced.

**P0 escort source candidates:** two genuine ImageGen outputs are a right-authored four-idle strip (2172×724 RGBA, original SHA-256 `c5277c8808795b1e04976abceafd5f2d13d7060d74d824dbc86ed8a3870b2535`, gen_id `41bf0a9a-c5c6-4257-930f-1642d69c556f`) and six-walk strip (2172×724 RGBA, original SHA-256 `fdac1a8dc4987fea6ff039f238151a6ce9230ef526df9e96b696715b3df03c70`, gen_id `42221c7f-ba3a-4ac8-aa4d-e130d0ac8110`). They are preserved in the ChatGPT-generated `escort_animation_intake_candidate_20260921.zip` source handoff (1,348,574 bytes; SHA-256 `83e47ae896201c05f417808278e0db5349998ae9e249846b1eeda9ed6e06e9bf`). The image model's version is not verified. The exact full-resolution generated PNG bytes have **not** been transferred into the Windows repository; do not write that they have, or create replacements from the static actor.

The genuine ten-pose **review derivative** `res://assets/art/generated_sources/imagegen/npc/review/escort_idle_walk_320x32_review_20260921.png` was transferred in sequential binary chunks with its complete SHA-256 checked: `184ef03d9b91f1f1d5b31361a02d22da6e4c5162a0d66c528a9326113c923054`. It has four 32×32 idle cells followed by six walk cells. `tools/art/escort_animation_review/capture_escort_animation_candidate.gd` invokes the **actual NpcVisualPresenter**, with a temporary external two-clip AnimationLibrary solely for native review. Four 640×360 GL Compatibility pages cover right/left idle/walk at 1×/2×; `verify_escort_animation_candidate_native.py` verified 40 frame/direction samples and 21,740 nearly opaque source pixels (maximum RGB deviation 3/8). This is a rendering/pixel-integrity result, **not** independent artistic loop/identity approval, accepted source provenance, approved playback timing, or production integration. The live `temporary_escort.tres` remains the accepted static 32×32 anchor; `npc.temporary_escort_actor.animation` stays P0 `ANIMATION_REQUIRED`.

To complete source intake after obtaining the **exact** generated ZIP in the Windows workspace, run the fail-closed `tools/art/escort_animation_review/intake_escort_animation_sources.py` with its required `--zip` and separately source-checked `--recipe` arguments. It must verify the archive, both original PNG bytes, accepted static anchor, reproducible nearest-neighbor derivative and immutable original destination **before** source-preservation claims. Only then review genuine body motion/loop/identity, bind Inspector-owned texture and external AnimationLibrary, capture actual Tower **and** Region 3 gameplay with facing/goal/wait, rerun focused/broad Godot checks, and promote the manifest. The other 44 open IDs require their own exact asset or authoring acceptance; no unapproved interior dimensions, independent NPC actor coordinates, boss attack geometry, or final move timings have been invented.

**Player INTERACT partial review:** a separate five-frame source-backed review compares actual scene-bound V03 against the R3 body+detached sparks with real Player scene, none/melee, right/left and 1×/2×. This supplies an art-comparison input, not a replacement gameplay AnimationLibrary or approved effect timing. Ten player revisions remain open.

## 15. Complete inventory — historical quick index

The table has **223 stable records**. The detailed appendix preserves **every field**, including exact paths, dimensions, views, frame counts, dependencies, acceptance criteria and verification issues. Counts include sheet/kit/integration records, not223 individual PNGs. Older untouched audit entries remain dated audit findings, not newly executed verification.

| Classification | Records |
| --- | ---: |
| `ACCEPTED_DO_NOT_REGENERATE` | 152 |
| `ANIMATION_REQUIRED` | 1 |
| `EXISTS_NEEDS_REVISION` | 36 |
| `MISSING_GENERATE` | 8 |
| `PLACEHOLDER` | 20 |
| `TEXTURE_TILE_REQUIRED` | 1 |
| `VFX_REQUIRED` | 5 |

| Stable asset ID | Category | Subject | Classification | Priority |
| --- | --- | --- | --- | --- |
| asset:palettes/master_palette | art_reference | Master Palette v01 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/player_side_idle_ref | art_reference | Player Side Idle Reference v01 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/player_side_reference_sheet | art_reference | Player Side Reference Review Sheet v01 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/boss_tenth_warden/tenth_warden_arc_volley | boss | Tenth Warden Arc Volley V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_core_sheet | boss | Tenth Warden Core Sheet V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_crescent_sweep | boss | Tenth Warden Crescent Sweep V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_death | boss | Tenth Warden Death V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_hit | boss | Tenth Warden Hit V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_idle | boss | Tenth Warden Idle V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_phase_two | boss | Tenth Warden Phase Two V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_punishing_step | boss | Tenth Warden Punishing Step V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_twin_cut | boss | Tenth Warden Twin Cut V01 | PLACEHOLDER | P1 |
| asset:enemies/boss_tenth_warden/tenth_warden_warden_lunge | boss | Tenth Warden Warden Lunge V01 | PLACEHOLDER | P1 |
| boss.tenth_warden.telegraph.arc_volley | combat_telegraph | arc volley warning presentation | VFX_REQUIRED | P1 |
| boss.tenth_warden.telegraph.crescent_sweep | combat_telegraph | crescent sweep warning presentation | VFX_REQUIRED | P1 |
| boss.tenth_warden.telegraph.punishing_step | combat_telegraph | punishing step warning presentation | VFX_REQUIRED | P1 |
| boss.tenth_warden.telegraph.twin_cut | combat_telegraph | twin cut warning presentation | VFX_REQUIRED | P1 |
| boss.tenth_warden.telegraph.warden_lunge | combat_telegraph | warden lunge warning presentation | VFX_REQUIRED | P1 |
| asset:player/vfx/arcane_cast_burst | combat_vfx_telegraph | Arcane Cast Burst V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/vfx/block_spark | combat_vfx_telegraph | Block Spark V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/vfx/heavy_slash_trail | combat_vfx_telegraph | Heavy Slash Trail V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/vfx/light_slash_trail | combat_vfx_telegraph | Light Slash Trail V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/vfx/parry_spark | combat_vfx_telegraph | Parry Spark V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/vfx/ranged_release_flash | combat_vfx_telegraph | Ranged Release Flash V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_block_cue | combat_vfx_telegraph | Telegraph Block Cue V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_boss_warning | combat_vfx_telegraph | Telegraph Boss Warning V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_circle | combat_vfx_telegraph | Telegraph Circle V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_cone | combat_vfx_telegraph | Telegraph Cone V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_delayed_circle | combat_vfx_telegraph | Telegraph Delayed Circle V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_guard_break | combat_vfx_telegraph | Telegraph Guard Break V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_lunge_path | combat_vfx_telegraph | Telegraph Lunge Path V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_narrow_line | combat_vfx_telegraph | Telegraph Narrow Line V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_parry_cue | combat_vfx_telegraph | Telegraph Parry Cue V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_projectile_lane | combat_vfx_telegraph | Telegraph Projectile Lane V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_short_arc | combat_vfx_telegraph | Telegraph Short Arc V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_wide_line | combat_vfx_telegraph | Telegraph Wide Line V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:vfx/telegraphs/telegraph_wide_sweep | combat_vfx_telegraph | Telegraph Wide Sweep V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/assassin/enemy_assassin_core_sheet | enemy | Assassin Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/assassin/enemy_assassin_death | enemy | Assassin Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/assassin/enemy_assassin_hit | enemy | Assassin Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/assassin/enemy_assassin_idle | enemy | Assassin Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/assassin/enemy_assassin_move | enemy | Assassin Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/assassin/enemy_assassin_release | enemy | Assassin Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/assassin/enemy_assassin_windup | enemy | Assassin Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/bruiser/enemy_bruiser_core_sheet | enemy | Bruiser Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/bruiser/enemy_bruiser_death | enemy | Bruiser Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/bruiser/enemy_bruiser_hit | enemy | Bruiser Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/bruiser/enemy_bruiser_idle | enemy | Bruiser Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/bruiser/enemy_bruiser_move | enemy | Bruiser Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/bruiser/enemy_bruiser_release | enemy | Bruiser Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/bruiser/enemy_bruiser_windup | enemy | Bruiser Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/caster/enemy_caster_core_sheet | enemy | Caster Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/caster/enemy_caster_death | enemy | Caster Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/caster/enemy_caster_hit | enemy | Caster Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/caster/enemy_caster_idle | enemy | Caster Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/caster/enemy_caster_move | enemy | Caster Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/caster/enemy_caster_release | enemy | Caster Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/caster/enemy_caster_windup | enemy | Caster Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/controller_disruptor/enemy_controller_disruptor_core_sheet | enemy | Controller Disruptor Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/controller_disruptor/enemy_controller_disruptor_death | enemy | Controller Disruptor Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/controller_disruptor/enemy_controller_disruptor_hit | enemy | Controller Disruptor Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/controller_disruptor/enemy_controller_disruptor_idle | enemy | Controller Disruptor Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/controller_disruptor/enemy_controller_disruptor_move | enemy | Controller Disruptor Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/controller_disruptor/enemy_controller_disruptor_release | enemy | Controller Disruptor Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/controller_disruptor/enemy_controller_disruptor_windup | enemy | Controller Disruptor Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/defender/enemy_defender_block | enemy | Defender Block v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/defender/enemy_defender_core_sheet | enemy | Defender Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/defender/enemy_defender_death | enemy | Defender Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/defender/enemy_defender_hit | enemy | Defender Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/defender/enemy_defender_idle | enemy | Defender Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/defender/enemy_defender_move | enemy | Defender Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/defender/enemy_defender_release | enemy | Defender Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/defender/enemy_defender_windup | enemy | Defender Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/duelist/enemy_duelist_core_sheet | enemy | Duelist Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/duelist/enemy_duelist_death | enemy | Duelist Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/duelist/enemy_duelist_hit | enemy | Duelist Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/duelist/enemy_duelist_idle | enemy | Duelist Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/duelist/enemy_duelist_move | enemy | Duelist Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/duelist/enemy_duelist_release | enemy | Duelist Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/duelist/enemy_duelist_windup | enemy | Duelist Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/flying_harrier/enemy_flying_harrier_core_sheet | enemy | Flying Harrier Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/flying_harrier/enemy_flying_harrier_death | enemy | Flying Harrier Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/flying_harrier/enemy_flying_harrier_hit | enemy | Flying Harrier Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/flying_harrier/enemy_flying_harrier_idle | enemy | Flying Harrier Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/flying_harrier/enemy_flying_harrier_move | enemy | Flying Harrier Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/flying_harrier/enemy_flying_harrier_release | enemy | Flying Harrier Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/flying_harrier/enemy_flying_harrier_windup | enemy | Flying Harrier Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/marksman/enemy_marksman_core_sheet | enemy | Marksman Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/marksman/enemy_marksman_death | enemy | Marksman Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/marksman/enemy_marksman_hit | enemy | Marksman Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/marksman/enemy_marksman_idle | enemy | Marksman Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/marksman/enemy_marksman_move | enemy | Marksman Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/marksman/enemy_marksman_release | enemy | Marksman Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/marksman/enemy_marksman_windup | enemy | Marksman Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/mobile_ranged/enemy_mobile_ranged_core_sheet | enemy | Mobile Ranged Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/mobile_ranged/enemy_mobile_ranged_death | enemy | Mobile Ranged Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/mobile_ranged/enemy_mobile_ranged_hit | enemy | Mobile Ranged Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/mobile_ranged/enemy_mobile_ranged_idle | enemy | Mobile Ranged Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/mobile_ranged/enemy_mobile_ranged_move | enemy | Mobile Ranged Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/mobile_ranged/enemy_mobile_ranged_release | enemy | Mobile Ranged Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/mobile_ranged/enemy_mobile_ranged_windup | enemy | Mobile Ranged Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/skirmisher/enemy_skirmisher_core_sheet | enemy | Skirmisher Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/skirmisher/enemy_skirmisher_death | enemy | Skirmisher Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/skirmisher/enemy_skirmisher_hit | enemy | Skirmisher Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/skirmisher/enemy_skirmisher_idle | enemy | Skirmisher Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/skirmisher/enemy_skirmisher_move | enemy | Skirmisher Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/skirmisher/enemy_skirmisher_release | enemy | Skirmisher Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/skirmisher/enemy_skirmisher_windup | enemy | Skirmisher Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/summoner/enemy_summoner_core_sheet | enemy | Summoner Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/summoner/enemy_summoner_death | enemy | Summoner Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/summoner/enemy_summoner_hit | enemy | Summoner Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/summoner/enemy_summoner_idle | enemy | Summoner Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/summoner/enemy_summoner_move | enemy | Summoner Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/summoner/enemy_summoner_release | enemy | Summoner Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/summoner/enemy_summoner_windup | enemy | Summoner Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/support/enemy_support_core_sheet | enemy | Support Core Sheet v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/support/enemy_support_death | enemy | Support Death v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/support/enemy_support_hit | enemy | Support Hit v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/support/enemy_support_idle | enemy | Support Idle v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/support/enemy_support_move | enemy | Support Move v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/support/enemy_support_release | enemy | Support Release v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:enemies/support/enemy_support_windup | enemy | Support Windup v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/weapons/starter_bow | equipment | Starter Bow V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/weapons/starter_shield | equipment | Starter Shield V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/weapons/starter_staff | equipment | Starter Staff V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:player/weapons/starter_sword | equipment | Starter Sword V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:interior:functional:01 | functional_interior | Central Tower interior visual destination | MISSING_GENERATE | P1 |
| r3:interior:functional:02 | functional_interior | Quest Hall interior visual destination | MISSING_GENERATE | P1 |
| r3:interior:functional:03 | functional_interior | Blacksmith interior visual destination | MISSING_GENERATE | P1 |
| r3:interior:functional:04 | functional_interior | General Merchant interior visual destination | MISSING_GENERATE | P1 |
| r3:interior:functional:05 | functional_interior | Inn / Rest House interior visual destination | MISSING_GENERATE | P1 |
| r3:interior:functional:06 | functional_interior | Storage House interior visual destination | MISSING_GENERATE | P1 |
| r3:interior:functional:07 | functional_interior | Training Hall interior visual destination | MISSING_GENERATE | P1 |
| r3:interior:functional:08 | functional_interior | Clinic / Apothecary interior visual destination | MISSING_GENERATE | P1 |
| npc.blacksmith_upgrader | npc | Blacksmith/upgrader | EXISTS_NEEDS_REVISION | P1 |
| npc.merchant | npc | Merchant | EXISTS_NEEDS_REVISION | P1 |
| npc.story_lore | npc | Story/lore NPC | EXISTS_NEEDS_REVISION | P1 |
| npc.temporary_escort_actor | npc | Temporary escort actor | EXISTS_NEEDS_REVISION | P0 |
| npc.tower_quest_coordinator | npc | Tower/quest coordinator | EXISTS_NEEDS_REVISION | P1 |
| npc.variable_quest_actor | npc | Variable quest NPC | EXISTS_NEEDS_REVISION | P1 |
| npc.temporary_escort_actor.animation | npc_animation | Escort actor movement/wait presentation | ANIMATION_REQUIRED | P0 |
| asset:player/animations/player_body_attack_sheet | player_character_animation | Player Body Attack Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_block_sheet | player_character_animation | Player Body Block Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_cast_sheet | player_character_animation | Player Body Cast Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_climb_sheet | player_character_animation | Player Body Climb Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_dash_sheet | player_character_animation | Player Body Dash Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_death_sheet | player_character_animation | Player Body Death Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_dodge_sheet | player_character_animation | Player Body Dodge Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_heavy_attack_sheet | player_character_animation | Player Body Heavy Attack Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_hit_sheet | player_character_animation | Player Body Hit Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_idle_sheet | player_character_animation | Player Body Idle Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_interact_sheet | player_character_animation | Player Body Interact Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_parry_sheet | player_character_animation | Player Body Parry Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_pickup_sheet | player_character_animation | Player Body Pickup Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_run_sheet | player_character_animation | Player Body Run Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_sleep_sheet | player_character_animation | Player Body Sleep Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_use_item_sheet | player_character_animation | Player Body Use Item Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/animations/player_body_walk_sheet | player_character_animation | Player Body Walk Sheet v03 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/weapons/arcane_projectile | projectile | Arcane Projectile V02 | EXISTS_NEEDS_REVISION | P1 |
| asset:player/weapons/arrow_projectile | projectile | Arrow Projectile V02 | EXISTS_NEEDS_REVISION | P1 |
| asset:environments/region3/functional_buildings/region3_blacksmith_exterior | region3_building | Region 3 Blacksmith Exterior v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:environments/region3/functional_buildings/region3_central_tower_exterior | region3_building | Region 3 Central Tower Exterior v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:environments/region3/functional_buildings/region3_clinic_exterior | region3_building | Region 3 Clinic / Apothecary Exterior v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:environments/region3/functional_buildings/region3_inn_exterior | region3_building | Region 3 Inn / Rest House Exterior v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:environments/region3/functional_buildings/region3_merchant_exterior | region3_building | Region 3 General Merchant Exterior v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:environments/region3/functional_buildings/region3_quest_hall_exterior | region3_building | Region 3 Quest Hall Exterior v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:environments/region3/functional_buildings/region3_storage_exterior | region3_building | Region 3 Storage House Exterior v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| asset:environments/region3/functional_buildings/region3_training_exterior | region3_building | Region 3 Training Hall Exterior v02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:01 | region3_building | Region3 Decorative Building 01 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:02 | region3_building | Region3 Decorative Building 02 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:03 | region3_building | Region3 Decorative Building 03 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:04 | region3_building | Region3 Decorative Building 04 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:05 | region3_building | Region3 Decorative Building 05 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:06 | region3_building | Region3 Decorative Building 06 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:07 | region3_building | Region3 Decorative Building 07 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:08 | region3_building | Region3 Decorative Building 08 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:09 | region3_building | Region3 Decorative Building 09 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:10 | region3_building | Region3 Decorative Building 10 V02 | ACCEPTED_DO_NOT_REGENERATE | P2 |
| r3:decorative:11 | region3_environment | Ambient stall, east frontage | EXISTS_NEEDS_REVISION | P1 |
| r3:decorative:12 | region3_environment | Decorative home, east frontage | EXISTS_NEEDS_REVISION | P1 |
| region3_ground_road | region3_environment | Ground and road material tiles | ACCEPTED_DO_NOT_REGENERATE | P1 |
| region3_outskirts_support | region3_environment | South-outskirts route support | ACCEPTED_DO_NOT_REGENERATE | P1 |
| region3_risk_zone_support | region3_environment | East high-risk pocket dressing | ACCEPTED_DO_NOT_REGENERATE | P1 |
| region3_ruins_modules | region3_environment | North ruins broken-stone kit | ACCEPTED_DO_NOT_REGENERATE | P1 |
| region3_town_props | region3_environment | Town and route prop source sheet | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:environments/tower/rooms/tower_room_boss | tower_environment | Tower Room Boss V01 | PLACEHOLDER | P1 |
| asset:environments/tower/rooms/tower_room_combat | tower_environment | Tower Room Combat V01 | PLACEHOLDER | P1 |
| asset:environments/tower/rooms/tower_room_elite | tower_environment | Tower Room Elite V01 | PLACEHOLDER | P1 |
| asset:environments/tower/rooms/tower_room_objective | tower_environment | Tower Room Objective V01 | PLACEHOLDER | P1 |
| asset:environments/tower/rooms/tower_room_reward | tower_environment | Tower Room Reward V01 | PLACEHOLDER | P1 |
| asset:environments/tower/rooms/tower_room_safe | tower_environment | Tower Room Safe V01 | PLACEHOLDER | P1 |
| asset:environments/tower/rooms/tower_room_secret | tower_environment | Tower Room Secret V01 | PLACEHOLDER | P1 |
| asset:environments/tower/rooms/tower_room_vendor | tower_environment | Tower Room Vendor V01 | PLACEHOLDER | P1 |
| asset:environments/tower/tiles/tower_common_tileset | tower_environment | Tower Common Tileset V01 | TEXTURE_TILE_REQUIRED | P1 |
| asset:ui/classes/class_mage_icon | ui | Class Mage Icon V01 | EXISTS_NEEDS_REVISION | P1 |
| asset:ui/classes/class_melee_icon | ui | Class Melee Icon V01 | EXISTS_NEEDS_REVISION | P1 |
| asset:ui/classes/class_ranged_icon | ui | Class Ranged Icon V01 | EXISTS_NEEDS_REVISION | P1 |
| asset:ui/markers/map_marker_sheet | ui | Map Marker Sheet V01 | PLACEHOLDER | P1 |
| asset:ui/markers/tower_sigil_icon | ui | Tower Sigil Icon V01 | EXISTS_NEEDS_REVISION | P1 |
| asset:ui/quests/quest_family_annihilation | ui | Quest Family Annihilation V01 | EXISTS_NEEDS_REVISION | P1 |
| asset:ui/quests/quest_family_escort | ui | Quest Family Escort V01 | EXISTS_NEEDS_REVISION | P1 |
| asset:ui/quests/quest_family_tower_defense | ui | Quest Family Tower Defense V01 | EXISTS_NEEDS_REVISION | P1 |
| asset:ui/skills/skill_aegis_ward | ui | Skill Aegis Ward V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_arc_cleave | ui | Skill Arc Cleave V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_arcane_lance | ui | Skill Arcane Lance V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_backstep_shot | ui | Skill Backstep Shot V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_breaker | ui | Skill Breaker V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_delayed_pulse | ui | Skill Delayed Pulse V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_driving_thrust | ui | Skill Driving Thrust V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_efficient_footwork | ui | Skill Efficient Footwork V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_expose | ui | Skill Expose V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_fan_shot | ui | Skill Fan Shot V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_fleet_recovery | ui | Skill Fleet Recovery V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_flow_recovery | ui | Skill Flow Recovery V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_longshot | ui | Skill Longshot V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_mana_weave | ui | Skill Mana Weave V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_parry_recovery | ui | Skill Parry Recovery V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_piercing_shot | ui | Skill Piercing Shot V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_riposte | ui | Skill Riposte V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/skills/skill_stable_casting | ui | Skill Stable Casting V01 | ACCEPTED_DO_NOT_REGENERATE | P1 |
| asset:ui/status/status_burn | ui | Status Burn V01 | EXISTS_NEEDS_REVISION | P1 |
| asset:ui/status/status_slow | ui | Status Slow V01 | EXISTS_NEEDS_REVISION | P1 |
| application.icon | ui_application_icon | Application icon | PLACEHOLDER | P3 |

## 16. Complete inventory — all detailed records

Each record is preserved as JSON for unambiguous nested values and exact copy/paste. `prior_audit_snapshot` is historical context only. Current-work corrections above and the current record fields supersede those historical values. Null values remain unknown.

### 001. asset:palettes/master_palette

```json
{
  "stable_asset_id": "asset:palettes/master_palette",
  "category": "art_reference",
  "subject": "Master Palette v01",
  "gameplay_purpose": "Preserved reference/palette; not a new production-generation target",
  "required_views_directions": [
    "Static view"
  ],
  "required_animation_states": [],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      16
    ],
    "cell": [
      96,
      16
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Reference-specific",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/palettes/master_palette_v01.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "bc434a7b67de64fa628c9ee19dc53cbb2a58f1f3209a87e70c9ea9ccaa4afb03",
    "dimensions": [
      96,
      16
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      255,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": []
}
```

### 002. asset:player/player_side_idle_ref

```json
{
  "stable_asset_id": "asset:player/player_side_idle_ref",
  "category": "art_reference",
  "subject": "Player Side Idle Reference v01",
  "gameplay_purpose": "Preserved reference/palette; not a new production-generation target",
  "required_views_directions": [
    "Static view"
  ],
  "required_animation_states": [],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Reference-specific",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/player/player_side_idle_ref_v01.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "133ddb50c0643d3b8fb9a9a41b61b5de65ec753488f828f4110039e402e099ac",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": []
}
```

### 003. asset:player/player_side_reference_sheet

```json
{
  "stable_asset_id": "asset:player/player_side_reference_sheet",
  "category": "art_reference",
  "subject": "Player Side Reference Review Sheet v01",
  "gameplay_purpose": "Preserved reference/palette; not a new production-generation target",
  "required_views_directions": [
    "Static view"
  ],
  "required_animation_states": [],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      320,
      320
    ],
    "cell": [
      320,
      320
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Reference-specific",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/player/player_side_reference_sheet_v01.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "2a83e01a89c0e08af4a84752ad7009f8709a6b32ee291988cf6dba676516dd0b",
    "dimensions": [
      320,
      320
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      255,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": []
}
```

### 004. asset:enemies/boss_tenth_warden/tenth_warden_arc_volley

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_arc_volley",
  "category": "boss",
  "subject": "Tenth Warden Arc Volley V01",
  "gameplay_purpose": "Tenth Warden Arc Volley V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "arc_volley"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_arc_volley_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "9adb19e06d53e4be4cac6371753e9b1d8844fc4506042cc55d67472c37c11068",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 005. asset:enemies/boss_tenth_warden/tenth_warden_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_core_sheet",
  "category": "boss",
  "subject": "Tenth Warden Core Sheet V01",
  "gameplay_purpose": "Tenth Warden Core Sheet V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "phase_two",
    "twin_cut",
    "warden_lunge",
    "arc_volley",
    "crescent_sweep",
    "punishing_step",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 9
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      864,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_core_sheet_v01.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "eb9991a07b697abf5ef3e346f5897fcddce1155a59b64a5028a8385d6c87c8f5",
    "dimensions": [
      864,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 006. asset:enemies/boss_tenth_warden/tenth_warden_crescent_sweep

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_crescent_sweep",
  "category": "boss",
  "subject": "Tenth Warden Crescent Sweep V01",
  "gameplay_purpose": "Tenth Warden Crescent Sweep V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "crescent_sweep"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_crescent_sweep_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "87b37a7d675267fa9596b6c9bc5dc42f5e3857ab01eb62d1b6fa6730df13e6ff",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 007. asset:enemies/boss_tenth_warden/tenth_warden_death

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_death",
  "category": "boss",
  "subject": "Tenth Warden Death V01",
  "gameplay_purpose": "Tenth Warden Death V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_death_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "76d9c997ce5cf03e6a8551c9ff09bef8ee7ec0e87d179eefd7ae99fb695cf396",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 008. asset:enemies/boss_tenth_warden/tenth_warden_hit

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_hit",
  "category": "boss",
  "subject": "Tenth Warden Hit V01",
  "gameplay_purpose": "Tenth Warden Hit V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_hit_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f9940462f97efea19caa3d052fa411234d39bb1f959356be3b9191c5c460b665",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 009. asset:enemies/boss_tenth_warden/tenth_warden_idle

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_idle",
  "category": "boss",
  "subject": "Tenth Warden Idle V01",
  "gameplay_purpose": "Tenth Warden Idle V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres",
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_idle_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "9ebc89eade1df590bb09009b554352eb11ad7c7a6b865a3f22fb24e359cdb85d",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 010. asset:enemies/boss_tenth_warden/tenth_warden_phase_two

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_phase_two",
  "category": "boss",
  "subject": "Tenth Warden Phase Two V01",
  "gameplay_purpose": "Tenth Warden Phase Two V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "phase_two"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_phase_two_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "d2eaa5f4236a70fdddafa3f4c39e4da3d88cbe55c3aea64ca08b3357efe7db71",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 011. asset:enemies/boss_tenth_warden/tenth_warden_punishing_step

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_punishing_step",
  "category": "boss",
  "subject": "Tenth Warden Punishing Step V01",
  "gameplay_purpose": "Tenth Warden Punishing Step V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "punishing_step"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_punishing_step_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "e8395c2a2a89d40d45c76462be33411da1ae05d71f342c0fb7f5ea97c5a45c49",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 012. asset:enemies/boss_tenth_warden/tenth_warden_twin_cut

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_twin_cut",
  "category": "boss",
  "subject": "Tenth Warden Twin Cut V01",
  "gameplay_purpose": "Tenth Warden Twin Cut V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "twin_cut"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_twin_cut_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "205a9eb9341a2c27831e4fc36de270f598b70581b079ac7aee8f271960902250",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 013. asset:enemies/boss_tenth_warden/tenth_warden_warden_lunge

```json
{
  "stable_asset_id": "asset:enemies/boss_tenth_warden/tenth_warden_warden_lunge",
  "category": "boss",
  "subject": "Tenth Warden Warden Lunge V01",
  "gameplay_purpose": "Tenth Warden Warden Lunge V01",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "warden_lunge"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/tenth_warden_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/boss_tenth_warden/tenth_warden_warden_lunge_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent boss identity anchor and controlled required poses; retain V01 until replacement validates.",
  "dependencies": [
    "Authored boss attack geometry/timing for final alignment; do not invent absent tuning"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "d6362001108006e68498a953719a313ef60cdaa52d26057f54e54dff0ab0047b",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Procedural V01 boss imagery; runtime libraries assign single static poses."
  ]
}
```

### 014. boss.tenth_warden.telegraph.arc_volley

```json
{
  "stable_asset_id": "boss.tenth_warden.telegraph.arc_volley",
  "category": "combat_telegraph",
  "subject": "arc volley warning presentation",
  "gameplay_purpose": "arc volley warning presentation",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "res://docs/art/VFX_VISUAL_BIBLE.md",
    "res://docs/art/ART_INTEGRATION_RULES.md"
  ],
  "reference_assets": [
    "res://assets/art/player/vfx/arcane_cast_burst_v02.png",
    "res://assets/art/player/vfx/block_spark_v02.png",
    "res://assets/art/player/vfx/heavy_slash_trail_v02.png",
    "res://assets/art/player/vfx/light_slash_trail_v02.png",
    "res://assets/art/player/vfx/parry_spark_v02.png",
    "res://assets/art/player/vfx/ranged_release_flash_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_block_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_boss_warning_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_cone_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_delayed_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_guard_break_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_lunge_path_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_narrow_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_parry_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_projectile_lane_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_short_arc_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_sweep_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/arc_volley_visual_binding.tres"
  ],
  "current_existing_asset": null,
  "current_implementation_status": "Move visual binding omits telegraph_profile; boss presenter supports a profile.",
  "classification": "VFX_REQUIRED",
  "generation_revision_requirement": "Prefer existing accepted primitives. Bind/scale/time only after authoritative attack geometry/timing is assigned; new image generation is conditional, not automatically required.",
  "dependencies": [
    "TenthWardenProductionAuthoring production values",
    "PlayerDefenderFactsTuning production values",
    "Authoritative geometry and phase timing"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Do not substitute fixture/guessed geometry to make visuals active."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 015. boss.tenth_warden.telegraph.crescent_sweep

```json
{
  "stable_asset_id": "boss.tenth_warden.telegraph.crescent_sweep",
  "category": "combat_telegraph",
  "subject": "crescent sweep warning presentation",
  "gameplay_purpose": "crescent sweep warning presentation",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "res://docs/art/VFX_VISUAL_BIBLE.md",
    "res://docs/art/ART_INTEGRATION_RULES.md"
  ],
  "reference_assets": [
    "res://assets/art/player/vfx/arcane_cast_burst_v02.png",
    "res://assets/art/player/vfx/block_spark_v02.png",
    "res://assets/art/player/vfx/heavy_slash_trail_v02.png",
    "res://assets/art/player/vfx/light_slash_trail_v02.png",
    "res://assets/art/player/vfx/parry_spark_v02.png",
    "res://assets/art/player/vfx/ranged_release_flash_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_block_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_boss_warning_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_cone_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_delayed_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_guard_break_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_lunge_path_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_narrow_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_parry_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_projectile_lane_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_short_arc_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_sweep_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/crescent_sweep_visual_binding.tres"
  ],
  "current_existing_asset": null,
  "current_implementation_status": "Move visual binding omits telegraph_profile; boss presenter supports a profile.",
  "classification": "VFX_REQUIRED",
  "generation_revision_requirement": "Prefer existing accepted primitives. Bind/scale/time only after authoritative attack geometry/timing is assigned; new image generation is conditional, not automatically required.",
  "dependencies": [
    "TenthWardenProductionAuthoring production values",
    "PlayerDefenderFactsTuning production values",
    "Authoritative geometry and phase timing"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Do not substitute fixture/guessed geometry to make visuals active."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 016. boss.tenth_warden.telegraph.punishing_step

```json
{
  "stable_asset_id": "boss.tenth_warden.telegraph.punishing_step",
  "category": "combat_telegraph",
  "subject": "punishing step warning presentation",
  "gameplay_purpose": "punishing step warning presentation",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "res://docs/art/VFX_VISUAL_BIBLE.md",
    "res://docs/art/ART_INTEGRATION_RULES.md"
  ],
  "reference_assets": [
    "res://assets/art/player/vfx/arcane_cast_burst_v02.png",
    "res://assets/art/player/vfx/block_spark_v02.png",
    "res://assets/art/player/vfx/heavy_slash_trail_v02.png",
    "res://assets/art/player/vfx/light_slash_trail_v02.png",
    "res://assets/art/player/vfx/parry_spark_v02.png",
    "res://assets/art/player/vfx/ranged_release_flash_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_block_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_boss_warning_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_cone_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_delayed_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_guard_break_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_lunge_path_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_narrow_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_parry_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_projectile_lane_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_short_arc_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_sweep_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/punishing_step_visual_binding.tres"
  ],
  "current_existing_asset": null,
  "current_implementation_status": "Move visual binding omits telegraph_profile; boss presenter supports a profile.",
  "classification": "VFX_REQUIRED",
  "generation_revision_requirement": "Prefer existing accepted primitives. Bind/scale/time only after authoritative attack geometry/timing is assigned; new image generation is conditional, not automatically required.",
  "dependencies": [
    "TenthWardenProductionAuthoring production values",
    "PlayerDefenderFactsTuning production values",
    "Authoritative geometry and phase timing"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Do not substitute fixture/guessed geometry to make visuals active."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 017. boss.tenth_warden.telegraph.twin_cut

```json
{
  "stable_asset_id": "boss.tenth_warden.telegraph.twin_cut",
  "category": "combat_telegraph",
  "subject": "twin cut warning presentation",
  "gameplay_purpose": "twin cut warning presentation",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "res://docs/art/VFX_VISUAL_BIBLE.md",
    "res://docs/art/ART_INTEGRATION_RULES.md"
  ],
  "reference_assets": [
    "res://assets/art/player/vfx/arcane_cast_burst_v02.png",
    "res://assets/art/player/vfx/block_spark_v02.png",
    "res://assets/art/player/vfx/heavy_slash_trail_v02.png",
    "res://assets/art/player/vfx/light_slash_trail_v02.png",
    "res://assets/art/player/vfx/parry_spark_v02.png",
    "res://assets/art/player/vfx/ranged_release_flash_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_block_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_boss_warning_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_cone_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_delayed_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_guard_break_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_lunge_path_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_narrow_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_parry_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_projectile_lane_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_short_arc_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_sweep_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/twin_cut_visual_binding.tres"
  ],
  "current_existing_asset": null,
  "current_implementation_status": "Move visual binding omits telegraph_profile; boss presenter supports a profile.",
  "classification": "VFX_REQUIRED",
  "generation_revision_requirement": "Prefer existing accepted primitives. Bind/scale/time only after authoritative attack geometry/timing is assigned; new image generation is conditional, not automatically required.",
  "dependencies": [
    "TenthWardenProductionAuthoring production values",
    "PlayerDefenderFactsTuning production values",
    "Authoritative geometry and phase timing"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Do not substitute fixture/guessed geometry to make visuals active."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 018. boss.tenth_warden.telegraph.warden_lunge

```json
{
  "stable_asset_id": "boss.tenth_warden.telegraph.warden_lunge",
  "category": "combat_telegraph",
  "subject": "warden lunge warning presentation",
  "gameplay_purpose": "warden lunge warning presentation",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "res://docs/art/VFX_VISUAL_BIBLE.md",
    "res://docs/art/ART_INTEGRATION_RULES.md"
  ],
  "reference_assets": [
    "res://assets/art/player/vfx/arcane_cast_burst_v02.png",
    "res://assets/art/player/vfx/block_spark_v02.png",
    "res://assets/art/player/vfx/heavy_slash_trail_v02.png",
    "res://assets/art/player/vfx/light_slash_trail_v02.png",
    "res://assets/art/player/vfx/parry_spark_v02.png",
    "res://assets/art/player/vfx/ranged_release_flash_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_block_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_boss_warning_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_cone_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_delayed_circle_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_guard_break_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_lunge_path_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_narrow_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_parry_cue_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_projectile_lane_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_short_arc_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_line_v02.png",
    "res://assets/art/vfx/telegraphs/telegraph_wide_sweep_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/boss_tenth_warden/presentation/warden_lunge_visual_binding.tres"
  ],
  "current_existing_asset": null,
  "current_implementation_status": "Move visual binding omits telegraph_profile; boss presenter supports a profile.",
  "classification": "VFX_REQUIRED",
  "generation_revision_requirement": "Prefer existing accepted primitives. Bind/scale/time only after authoritative attack geometry/timing is assigned; new image generation is conditional, not automatically required.",
  "dependencies": [
    "TenthWardenProductionAuthoring production values",
    "PlayerDefenderFactsTuning production values",
    "Authoritative geometry and phase timing"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Do not substitute fixture/guessed geometry to make visuals active."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 019. asset:player/vfx/arcane_cast_burst

```json
{
  "stable_asset_id": "asset:player/vfx/arcane_cast_burst",
  "category": "combat_vfx_telegraph",
  "subject": "Arcane Cast Burst V02",
  "gameplay_purpose": "Arcane Cast Burst V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/vfx_arcane_cast_burst.tres"
  ],
  "current_existing_asset": "res://assets/art/player/vfx/arcane_cast_burst_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "99b6087c7889adbf8c5d83a921c4821b1aea25ab6373177aa1a33d617ca804d5",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 020. asset:player/vfx/block_spark

```json
{
  "stable_asset_id": "asset:player/vfx/block_spark",
  "category": "combat_vfx_telegraph",
  "subject": "Block Spark V02",
  "gameplay_purpose": "Block Spark V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/vfx_block_spark.tres"
  ],
  "current_existing_asset": "res://assets/art/player/vfx/block_spark_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "9b8bb9c2cc78d4610516a4271d46032fdb4a1cb274ebf2d18384a610a6505b9e",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 021. asset:player/vfx/heavy_slash_trail

```json
{
  "stable_asset_id": "asset:player/vfx/heavy_slash_trail",
  "category": "combat_vfx_telegraph",
  "subject": "Heavy Slash Trail V02",
  "gameplay_purpose": "Heavy Slash Trail V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/vfx_heavy_slash_trail.tres"
  ],
  "current_existing_asset": "res://assets/art/player/vfx/heavy_slash_trail_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "e3e2c49ced640e86b6cb948ba5487ecaa30977083503e8f13f25d3fc501de777",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open.",
    "No genuine heavy-action binding found; retain asset, do not invent action."
  ]
}
```

### 022. asset:player/vfx/light_slash_trail

```json
{
  "stable_asset_id": "asset:player/vfx/light_slash_trail",
  "category": "combat_vfx_telegraph",
  "subject": "Light Slash Trail V02",
  "gameplay_purpose": "Light Slash Trail V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/vfx_light_slash_trail.tres"
  ],
  "current_existing_asset": "res://assets/art/player/vfx/light_slash_trail_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f1a6111f456eece96bb888f72d7253cd247f1de0082de42ac81f55de9fc39d57",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 023. asset:player/vfx/parry_spark

```json
{
  "stable_asset_id": "asset:player/vfx/parry_spark",
  "category": "combat_vfx_telegraph",
  "subject": "Parry Spark V02",
  "gameplay_purpose": "Parry Spark V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/vfx_parry_spark.tres"
  ],
  "current_existing_asset": "res://assets/art/player/vfx/parry_spark_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "16e063c72c056fecd3cc2f974113ad139f9423d3aaa421cffd0d4ace9c237e21",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 024. asset:player/vfx/ranged_release_flash

```json
{
  "stable_asset_id": "asset:player/vfx/ranged_release_flash",
  "category": "combat_vfx_telegraph",
  "subject": "Ranged Release Flash V02",
  "gameplay_purpose": "Ranged Release Flash V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/vfx_ranged_release_flash.tres"
  ],
  "current_existing_asset": "res://assets/art/player/vfx/ranged_release_flash_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "bffd1e809828284bf57686571bbb2467d08e32592ed9d0ba58e54743c73cba87",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 025. asset:vfx/telegraphs/telegraph_block_cue

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_block_cue",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Block Cue V02",
  "gameplay_purpose": "Telegraph Block Cue V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_block_cue.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_block_cue_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "063e196bebc0cb6063050ee13d5a3bcb5d275ec6ae74c1dc4149ff872ff6aba2",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 026. asset:vfx/telegraphs/telegraph_boss_warning

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_boss_warning",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Boss Warning V02",
  "gameplay_purpose": "Telegraph Boss Warning V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_boss_warning.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_boss_warning_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "467b78b51baecefd16dd1abeea35b5b3670fb74d54fa614cd8e31c78495e54b7",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 027. asset:vfx/telegraphs/telegraph_circle

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_circle",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Circle V02",
  "gameplay_purpose": "Telegraph Circle V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_circle.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_circle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "05379773732b9a4999e6f204f17cf25256d2efdc5cc1ccbeffbce18fba1cfb9c",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 028. asset:vfx/telegraphs/telegraph_cone

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_cone",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Cone V02",
  "gameplay_purpose": "Telegraph Cone V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_cone.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_cone_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "fa5405813dcaf904d975d3669394067a2c6b0365625454d46a5254a939dd9ac2",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 029. asset:vfx/telegraphs/telegraph_delayed_circle

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_delayed_circle",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Delayed Circle V02",
  "gameplay_purpose": "Telegraph Delayed Circle V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_delayed_circle.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_delayed_circle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "db68e672af9a023bd46fd1c521d90a6038a10694faabc6d076b563db3867245a",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 030. asset:vfx/telegraphs/telegraph_guard_break

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_guard_break",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Guard Break V02",
  "gameplay_purpose": "Telegraph Guard Break V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_guard_break.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_guard_break_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "30029c6225f450615646669efab10f825dfad5cec7a675bc8c1565d950eb2ff0",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 031. asset:vfx/telegraphs/telegraph_lunge_path

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_lunge_path",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Lunge Path V02",
  "gameplay_purpose": "Telegraph Lunge Path V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_lunge_path.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_lunge_path_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a18c17f55b5b1b420ef8fe5ed637a14cd14a5bc9486f03219a6b21e1eccfde94",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 032. asset:vfx/telegraphs/telegraph_narrow_line

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_narrow_line",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Narrow Line V02",
  "gameplay_purpose": "Telegraph Narrow Line V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_narrow_line.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_narrow_line_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "4ec99836500577cd6f456de0fddd8c85e5693bde28381fc0cb51ed82af76a32c",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 033. asset:vfx/telegraphs/telegraph_parry_cue

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_parry_cue",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Parry Cue V02",
  "gameplay_purpose": "Telegraph Parry Cue V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_parry_cue.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_parry_cue_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "45436f3c8a1af26c9cc698e1c2503f2f7186def30237a8f098654d17411deed1",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 034. asset:vfx/telegraphs/telegraph_projectile_lane

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_projectile_lane",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Projectile Lane V02",
  "gameplay_purpose": "Telegraph Projectile Lane V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_projectile_lane.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_projectile_lane_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "9c9210fd4106aad9ff370ce9756e58ec4586198a9b47d5d33f7ce2739ad8cc85",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 035. asset:vfx/telegraphs/telegraph_short_arc

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_short_arc",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Short Arc V02",
  "gameplay_purpose": "Telegraph Short Arc V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_short_arc.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_short_arc_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "36ce06bcde3e5aca6ed0867c44d9779bf8ff9999747cb712e835df6d22bfe54f",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 036. asset:vfx/telegraphs/telegraph_wide_line

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_wide_line",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Wide Line V02",
  "gameplay_purpose": "Telegraph Wide Line V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_wide_line.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_wide_line_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f7260a4c877bb4149714db32a34fa0df0f0baa5f5669cd3090b738fdf94ef3fa",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      251
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 037. asset:vfx/telegraphs/telegraph_wide_sweep

```json
{
  "stable_asset_id": "asset:vfx/telegraphs/telegraph_wide_sweep",
  "category": "combat_vfx_telegraph",
  "subject": "Telegraph Wide Sweep V02",
  "gameplay_purpose": "Telegraph Wide Sweep V02",
  "required_views_directions": [
    "Centered effect/telegraph plane"
  ],
  "required_animation_states": [
    "Static primitive; resource pulse/burst animation"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      64,
      64
    ],
    "cell": [
      64,
      64
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/VFX_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png"
  ],
  "target_godot_resource_scene": [
    "res://src/presentation/effects/profiles/telegraph_wide_sweep.tres"
  ],
  "current_existing_asset": "res://assets/art/vfx/telegraphs/telegraph_wide_sweep_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [
    "Authoritative geometry/timing and semantic owner"
  ],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "063243436290e00193ce234ce148e53f52dac3f0838a7d11a70f3dfd7ac19bdb",
    "dimensions": [
      64,
      64
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      247
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_transparent_background_pixel_art_sprite_sheet_5_batch_4.png",
    "source_sha256": "cf22d1bbb51ddb275028b6e94240d88e7b9d6dfd9902e69b026b6058c77048d8",
    "source_file_exists": true
  },
  "issues": [
    "Source/derivative integrity verified; representative current gameplay-scale phase/geometry/reduced-motion acceptance remains open."
  ]
}
```

### 038. asset:enemies/assassin/enemy_assassin_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/assassin/enemy_assassin_core_sheet",
  "category": "enemy",
  "subject": "Assassin Core Sheet v02",
  "gameplay_purpose": "Assassin Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/assassin/enemy_assassin_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "3a9e6dcb69422745392c3212f62d5dc2a35cadd50043a8357605fb64a29f386c",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png",
    "source_sha256": "685a14d0087d5119acb3426c607a0b6c8fc8e681cd8d133cfd4389413c067509",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 039. asset:enemies/assassin/enemy_assassin_death

```json
{
  "stable_asset_id": "asset:enemies/assassin/enemy_assassin_death",
  "category": "enemy",
  "subject": "Assassin Death v02",
  "gameplay_purpose": "Assassin Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/assassin_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/assassin/enemy_assassin_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "8b9fb806e546db82c95bc897f38c2bb2bfb6f61f88d4ae043bea0a85e34fdeac",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png",
    "source_sha256": "685a14d0087d5119acb3426c607a0b6c8fc8e681cd8d133cfd4389413c067509",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 040. asset:enemies/assassin/enemy_assassin_hit

```json
{
  "stable_asset_id": "asset:enemies/assassin/enemy_assassin_hit",
  "category": "enemy",
  "subject": "Assassin Hit v02",
  "gameplay_purpose": "Assassin Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/assassin_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/assassin/enemy_assassin_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a6043bccc3fea343889265a11df7e976f59ba5b4f9ea93287be3847ad903b224",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png",
    "source_sha256": "685a14d0087d5119acb3426c607a0b6c8fc8e681cd8d133cfd4389413c067509",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 041. asset:enemies/assassin/enemy_assassin_idle

```json
{
  "stable_asset_id": "asset:enemies/assassin/enemy_assassin_idle",
  "category": "enemy",
  "subject": "Assassin Idle v02",
  "gameplay_purpose": "Assassin Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/assassin_animation_library.tres",
    "res://src/enemies/presentation/scenes/assassin_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/assassin/enemy_assassin_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a198a4454335229e4389813d08bb0275f5b91524b61b9db129389d8858d9a60a",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png",
    "source_sha256": "685a14d0087d5119acb3426c607a0b6c8fc8e681cd8d133cfd4389413c067509",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 042. asset:enemies/assassin/enemy_assassin_move

```json
{
  "stable_asset_id": "asset:enemies/assassin/enemy_assassin_move",
  "category": "enemy",
  "subject": "Assassin Move v02",
  "gameplay_purpose": "Assassin Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/assassin_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/assassin/enemy_assassin_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "c4a8a940e7c698b3af47ee673cc2759a25ee358380b6d79ab6a5a410d3456576",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png",
    "source_sha256": "685a14d0087d5119acb3426c607a0b6c8fc8e681cd8d133cfd4389413c067509",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 043. asset:enemies/assassin/enemy_assassin_release

```json
{
  "stable_asset_id": "asset:enemies/assassin/enemy_assassin_release",
  "category": "enemy",
  "subject": "Assassin Release v02",
  "gameplay_purpose": "Assassin Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/assassin_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/assassin/enemy_assassin_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "75124a2705037a21a662d9b9d36929591296ff538da051a9a0e7f66840b0561c",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png",
    "source_sha256": "685a14d0087d5119acb3426c607a0b6c8fc8e681cd8d133cfd4389413c067509",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 044. asset:enemies/assassin/enemy_assassin_windup

```json
{
  "stable_asset_id": "asset:enemies/assassin/enemy_assassin_windup",
  "category": "enemy",
  "subject": "Assassin Windup v02",
  "gameplay_purpose": "Assassin Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/assassin_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/assassin/enemy_assassin_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "71bae06fb689a0fdc7caa179d036796b277449447211ea75ccad537c9ddd111c",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/assassin_pixel_art_sprite_sheet.png",
    "source_sha256": "685a14d0087d5119acb3426c607a0b6c8fc8e681cd8d133cfd4389413c067509",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 045. asset:enemies/bruiser/enemy_bruiser_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/bruiser/enemy_bruiser_core_sheet",
  "category": "enemy",
  "subject": "Bruiser Core Sheet v02",
  "gameplay_purpose": "Bruiser Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/bruiser/enemy_bruiser_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "7d8da87418e7c4afcb2b2d6fbc14a4dda80f1d0393c83942edea4f71e6deca7a",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png",
    "source_sha256": "beee795c56e75e6a31829770ad67354b8bdc13e70328c6e82c82ca6f14a20aa1",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 046. asset:enemies/bruiser/enemy_bruiser_death

```json
{
  "stable_asset_id": "asset:enemies/bruiser/enemy_bruiser_death",
  "category": "enemy",
  "subject": "Bruiser Death v02",
  "gameplay_purpose": "Bruiser Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/bruiser_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/bruiser/enemy_bruiser_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "ad16d37779e94113f92c5011c44211ac8c9e0fbd6317668688a55e33bbccd51e",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png",
    "source_sha256": "beee795c56e75e6a31829770ad67354b8bdc13e70328c6e82c82ca6f14a20aa1",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 047. asset:enemies/bruiser/enemy_bruiser_hit

```json
{
  "stable_asset_id": "asset:enemies/bruiser/enemy_bruiser_hit",
  "category": "enemy",
  "subject": "Bruiser Hit v02",
  "gameplay_purpose": "Bruiser Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/bruiser_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/bruiser/enemy_bruiser_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a651f5b8a5bbb1be957736ac0c9ca3077e3ce504d40b86f370054aa9a25dcad2",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png",
    "source_sha256": "beee795c56e75e6a31829770ad67354b8bdc13e70328c6e82c82ca6f14a20aa1",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 048. asset:enemies/bruiser/enemy_bruiser_idle

```json
{
  "stable_asset_id": "asset:enemies/bruiser/enemy_bruiser_idle",
  "category": "enemy",
  "subject": "Bruiser Idle v02",
  "gameplay_purpose": "Bruiser Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/bruiser_animation_library.tres",
    "res://src/enemies/presentation/scenes/bruiser_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/bruiser/enemy_bruiser_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "23210b9f06e00b00fb15b4d09722f3d0dd35516a0a5522dd277aaeeaf4fb2f12",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png",
    "source_sha256": "beee795c56e75e6a31829770ad67354b8bdc13e70328c6e82c82ca6f14a20aa1",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 049. asset:enemies/bruiser/enemy_bruiser_move

```json
{
  "stable_asset_id": "asset:enemies/bruiser/enemy_bruiser_move",
  "category": "enemy",
  "subject": "Bruiser Move v02",
  "gameplay_purpose": "Bruiser Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/bruiser_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/bruiser/enemy_bruiser_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "008c35ea0944f0a02a4a32b879ad3efed9d14ec86a6c7c7401d73c3c5f9e3f9f",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png",
    "source_sha256": "beee795c56e75e6a31829770ad67354b8bdc13e70328c6e82c82ca6f14a20aa1",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 050. asset:enemies/bruiser/enemy_bruiser_release

```json
{
  "stable_asset_id": "asset:enemies/bruiser/enemy_bruiser_release",
  "category": "enemy",
  "subject": "Bruiser Release v02",
  "gameplay_purpose": "Bruiser Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/bruiser_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/bruiser/enemy_bruiser_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "cdbcbd41d893f8bc2714f07314b5fa5947e06c0f09dc79a8e3b1f2a3fc7d6954",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png",
    "source_sha256": "beee795c56e75e6a31829770ad67354b8bdc13e70328c6e82c82ca6f14a20aa1",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 051. asset:enemies/bruiser/enemy_bruiser_windup

```json
{
  "stable_asset_id": "asset:enemies/bruiser/enemy_bruiser_windup",
  "category": "enemy",
  "subject": "Bruiser Windup v02",
  "gameplay_purpose": "Bruiser Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/bruiser_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/bruiser/enemy_bruiser_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "c1a773a99ae3bf1e1d84ed35f0d3e6ecb940e0ef1885117d6d6d14c4859accd0",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/bruiser_enemy_pixel_art_sprite_sheet.png",
    "source_sha256": "beee795c56e75e6a31829770ad67354b8bdc13e70328c6e82c82ca6f14a20aa1",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 052. asset:enemies/caster/enemy_caster_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/caster/enemy_caster_core_sheet",
  "category": "enemy",
  "subject": "Caster Core Sheet v02",
  "gameplay_purpose": "Caster Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/caster/enemy_caster_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f6f46764b376e37162d8d0a118a091bbe8efaa589f53cd006e80565631e8353c",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png",
    "source_sha256": "f468eca15a8a6e3c7e548c2629cccffa7ced72be24bc9e5560c00c0385d6d843",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 053. asset:enemies/caster/enemy_caster_death

```json
{
  "stable_asset_id": "asset:enemies/caster/enemy_caster_death",
  "category": "enemy",
  "subject": "Caster Death v02",
  "gameplay_purpose": "Caster Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/caster_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/caster/enemy_caster_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "5399f0498cbd9d2118e538bde896ca6189bec3ce211f5154337725d6ac861c40",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png",
    "source_sha256": "f468eca15a8a6e3c7e548c2629cccffa7ced72be24bc9e5560c00c0385d6d843",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 054. asset:enemies/caster/enemy_caster_hit

```json
{
  "stable_asset_id": "asset:enemies/caster/enemy_caster_hit",
  "category": "enemy",
  "subject": "Caster Hit v02",
  "gameplay_purpose": "Caster Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/caster_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/caster/enemy_caster_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "fe5714deb4687fb98b57ea5e03040d7b08de72f26ca6c06b4cdd15ea249c8a29",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png",
    "source_sha256": "f468eca15a8a6e3c7e548c2629cccffa7ced72be24bc9e5560c00c0385d6d843",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 055. asset:enemies/caster/enemy_caster_idle

```json
{
  "stable_asset_id": "asset:enemies/caster/enemy_caster_idle",
  "category": "enemy",
  "subject": "Caster Idle v02",
  "gameplay_purpose": "Caster Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/caster_animation_library.tres",
    "res://src/enemies/presentation/scenes/caster_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/caster/enemy_caster_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "18f0a8bd6fa29657a41298e71f15cb16c9aef032971647bc6ccbc81ff4592efc",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png",
    "source_sha256": "f468eca15a8a6e3c7e548c2629cccffa7ced72be24bc9e5560c00c0385d6d843",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 056. asset:enemies/caster/enemy_caster_move

```json
{
  "stable_asset_id": "asset:enemies/caster/enemy_caster_move",
  "category": "enemy",
  "subject": "Caster Move v02",
  "gameplay_purpose": "Caster Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/caster_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/caster/enemy_caster_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "5bc32532fe50c051494bc627355ace3f93cd9e5bc078251e8cceceb2737dd075",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png",
    "source_sha256": "f468eca15a8a6e3c7e548c2629cccffa7ced72be24bc9e5560c00c0385d6d843",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 057. asset:enemies/caster/enemy_caster_release

```json
{
  "stable_asset_id": "asset:enemies/caster/enemy_caster_release",
  "category": "enemy",
  "subject": "Caster Release v02",
  "gameplay_purpose": "Caster Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/caster_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/caster/enemy_caster_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f2ac93f688c43c935b126c692869b1dad4258f24aeadf9a5e7a6b658013e6987",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png",
    "source_sha256": "f468eca15a8a6e3c7e548c2629cccffa7ced72be24bc9e5560c00c0385d6d843",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 058. asset:enemies/caster/enemy_caster_windup

```json
{
  "stable_asset_id": "asset:enemies/caster/enemy_caster_windup",
  "category": "enemy",
  "subject": "Caster Windup v02",
  "gameplay_purpose": "Caster Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/caster_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/caster/enemy_caster_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "7a0c2ec87f4f73c4821d3631d55617bf3e55918b5d2216fd411bbc5a7184121d",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/caster_pixel_art_sprite_sheet.png",
    "source_sha256": "f468eca15a8a6e3c7e548c2629cccffa7ced72be24bc9e5560c00c0385d6d843",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 059. asset:enemies/controller_disruptor/enemy_controller_disruptor_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/controller_disruptor/enemy_controller_disruptor_core_sheet",
  "category": "enemy",
  "subject": "Controller Disruptor Core Sheet v02",
  "gameplay_purpose": "Controller Disruptor Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/controller_disruptor/enemy_controller_disruptor_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "78de8a6955f7f1f56563e4a3c41a17d41b4bf76f9fdf7f85c00004e027fae1e0",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png",
    "source_sha256": "7c98a953287fa8ed7119fb8ee9076a24b6a94d60c540054856eb6057842d8741",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 060. asset:enemies/controller_disruptor/enemy_controller_disruptor_death

```json
{
  "stable_asset_id": "asset:enemies/controller_disruptor/enemy_controller_disruptor_death",
  "category": "enemy",
  "subject": "Controller Disruptor Death v02",
  "gameplay_purpose": "Controller Disruptor Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/controller_disruptor_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/controller_disruptor/enemy_controller_disruptor_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "6b7ee2fdb46128b45f62042ce56f83ac9871b549356b046cbae1a60e84f55ea7",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png",
    "source_sha256": "7c98a953287fa8ed7119fb8ee9076a24b6a94d60c540054856eb6057842d8741",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 061. asset:enemies/controller_disruptor/enemy_controller_disruptor_hit

```json
{
  "stable_asset_id": "asset:enemies/controller_disruptor/enemy_controller_disruptor_hit",
  "category": "enemy",
  "subject": "Controller Disruptor Hit v02",
  "gameplay_purpose": "Controller Disruptor Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/controller_disruptor_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/controller_disruptor/enemy_controller_disruptor_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a3da9ae10aecdbd741e894d1475244d5b3a5ca741d25e9154ca0d2d511d6af0f",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png",
    "source_sha256": "7c98a953287fa8ed7119fb8ee9076a24b6a94d60c540054856eb6057842d8741",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 062. asset:enemies/controller_disruptor/enemy_controller_disruptor_idle

```json
{
  "stable_asset_id": "asset:enemies/controller_disruptor/enemy_controller_disruptor_idle",
  "category": "enemy",
  "subject": "Controller Disruptor Idle v02",
  "gameplay_purpose": "Controller Disruptor Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/controller_disruptor_animation_library.tres",
    "res://src/enemies/presentation/scenes/controller_disruptor_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/controller_disruptor/enemy_controller_disruptor_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "c24b146891c1c0523976297ecfb8ba469e9525d629bee15c4e66e89d658c2c3e",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png",
    "source_sha256": "7c98a953287fa8ed7119fb8ee9076a24b6a94d60c540054856eb6057842d8741",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 063. asset:enemies/controller_disruptor/enemy_controller_disruptor_move

```json
{
  "stable_asset_id": "asset:enemies/controller_disruptor/enemy_controller_disruptor_move",
  "category": "enemy",
  "subject": "Controller Disruptor Move v02",
  "gameplay_purpose": "Controller Disruptor Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/controller_disruptor_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/controller_disruptor/enemy_controller_disruptor_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "018c1a52a743790ac5dce0e1f18c8448aca48110ff50c507025ecc771e416e33",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png",
    "source_sha256": "7c98a953287fa8ed7119fb8ee9076a24b6a94d60c540054856eb6057842d8741",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 064. asset:enemies/controller_disruptor/enemy_controller_disruptor_release

```json
{
  "stable_asset_id": "asset:enemies/controller_disruptor/enemy_controller_disruptor_release",
  "category": "enemy",
  "subject": "Controller Disruptor Release v02",
  "gameplay_purpose": "Controller Disruptor Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/controller_disruptor_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/controller_disruptor/enemy_controller_disruptor_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f1ca7d746e5f3375a36be5295d19c9dec08c30379aee27555e52e110ae18b96b",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png",
    "source_sha256": "7c98a953287fa8ed7119fb8ee9076a24b6a94d60c540054856eb6057842d8741",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 065. asset:enemies/controller_disruptor/enemy_controller_disruptor_windup

```json
{
  "stable_asset_id": "asset:enemies/controller_disruptor/enemy_controller_disruptor_windup",
  "category": "enemy",
  "subject": "Controller Disruptor Windup v02",
  "gameplay_purpose": "Controller Disruptor Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/controller_disruptor_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/controller_disruptor/enemy_controller_disruptor_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "451f9f84aaba504f7ba95f2a2d1ee1dcc06ff6edba9cfad0d749e9a34eea8e3e",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/controller_disruptor_pixel_art_sprite_sheet.png",
    "source_sha256": "7c98a953287fa8ed7119fb8ee9076a24b6a94d60c540054856eb6057842d8741",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 066. asset:enemies/defender/enemy_defender_block

```json
{
  "stable_asset_id": "asset:enemies/defender/enemy_defender_block",
  "category": "enemy",
  "subject": "Defender Block v02",
  "gameplay_purpose": "Defender Block v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "block"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/defender_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/defender/enemy_defender_block_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "9a9014b65ae2fccf60dc9448e8f22f9afe8f2438414ec5a2bd405797685d9d2c",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png",
    "source_sha256": "ba01b2ff770328a70643aeddae4fcbbebe379337fedbbf22080c543654cf6be5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 067. asset:enemies/defender/enemy_defender_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/defender/enemy_defender_core_sheet",
  "category": "enemy",
  "subject": "Defender Core Sheet v02",
  "gameplay_purpose": "Defender Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/defender/enemy_defender_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "decdaf8f0dafd3fff799a27070fe14362a423e277b660f83ac63d02bd42e7f33",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png",
    "source_sha256": "ba01b2ff770328a70643aeddae4fcbbebe379337fedbbf22080c543654cf6be5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 068. asset:enemies/defender/enemy_defender_death

```json
{
  "stable_asset_id": "asset:enemies/defender/enemy_defender_death",
  "category": "enemy",
  "subject": "Defender Death v02",
  "gameplay_purpose": "Defender Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/defender_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/defender/enemy_defender_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "5e7cb168fc8161dff2c71a61ec0a33c5bc46677bce725d1741d0e777f77e60d8",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png",
    "source_sha256": "ba01b2ff770328a70643aeddae4fcbbebe379337fedbbf22080c543654cf6be5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 069. asset:enemies/defender/enemy_defender_hit

```json
{
  "stable_asset_id": "asset:enemies/defender/enemy_defender_hit",
  "category": "enemy",
  "subject": "Defender Hit v02",
  "gameplay_purpose": "Defender Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/defender_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/defender/enemy_defender_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "9b4c9859790a293a44c1a2f136cfcb544a7feb5542c2eaeb363e5d367ee1e354",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png",
    "source_sha256": "ba01b2ff770328a70643aeddae4fcbbebe379337fedbbf22080c543654cf6be5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 070. asset:enemies/defender/enemy_defender_idle

```json
{
  "stable_asset_id": "asset:enemies/defender/enemy_defender_idle",
  "category": "enemy",
  "subject": "Defender Idle v02",
  "gameplay_purpose": "Defender Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/defender_animation_library.tres",
    "res://src/enemies/presentation/scenes/defender_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/defender/enemy_defender_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f710aa3505d177f7d22a828bd14b37adb175e17a6aa6d6aece557f99cfa0a629",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png",
    "source_sha256": "ba01b2ff770328a70643aeddae4fcbbebe379337fedbbf22080c543654cf6be5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 071. asset:enemies/defender/enemy_defender_move

```json
{
  "stable_asset_id": "asset:enemies/defender/enemy_defender_move",
  "category": "enemy",
  "subject": "Defender Move v02",
  "gameplay_purpose": "Defender Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/defender_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/defender/enemy_defender_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "777205284bd72a57402b5a83f8494dcd2d47f333215545b0e10fc50b5099fcd8",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png",
    "source_sha256": "ba01b2ff770328a70643aeddae4fcbbebe379337fedbbf22080c543654cf6be5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 072. asset:enemies/defender/enemy_defender_release

```json
{
  "stable_asset_id": "asset:enemies/defender/enemy_defender_release",
  "category": "enemy",
  "subject": "Defender Release v02",
  "gameplay_purpose": "Defender Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/defender_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/defender/enemy_defender_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "ed73f2f43140dfe66c54c1b817bd0e6d9668ae1a140ad979d80bd4d2bc6116b2",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png",
    "source_sha256": "ba01b2ff770328a70643aeddae4fcbbebe379337fedbbf22080c543654cf6be5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 073. asset:enemies/defender/enemy_defender_windup

```json
{
  "stable_asset_id": "asset:enemies/defender/enemy_defender_windup",
  "category": "enemy",
  "subject": "Defender Windup v02",
  "gameplay_purpose": "Defender Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/defender_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/defender/enemy_defender_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "9a9014b65ae2fccf60dc9448e8f22f9afe8f2438414ec5a2bd405797685d9d2c",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/defender_enemy_pixel_art_reference_sheet.png",
    "source_sha256": "ba01b2ff770328a70643aeddae4fcbbebe379337fedbbf22080c543654cf6be5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 074. asset:enemies/duelist/enemy_duelist_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/duelist/enemy_duelist_core_sheet",
  "category": "enemy",
  "subject": "Duelist Core Sheet v02",
  "gameplay_purpose": "Duelist Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/duelist/enemy_duelist_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "42fb1f638a3af0d2fc6805682f3beeb441214535c7f8573170dbfad0a0d4dfa0",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png",
    "source_sha256": "12f57864b099fdbf4a4cc480dfa12ad88a3b665cfa71c39b458fa3faeb255176",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 075. asset:enemies/duelist/enemy_duelist_death

```json
{
  "stable_asset_id": "asset:enemies/duelist/enemy_duelist_death",
  "category": "enemy",
  "subject": "Duelist Death v02",
  "gameplay_purpose": "Duelist Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/duelist_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/duelist/enemy_duelist_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "fd591d3d8bcabda9617c69366820a64ba79134de973adf7a04c8d28d50683f78",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png",
    "source_sha256": "12f57864b099fdbf4a4cc480dfa12ad88a3b665cfa71c39b458fa3faeb255176",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 076. asset:enemies/duelist/enemy_duelist_hit

```json
{
  "stable_asset_id": "asset:enemies/duelist/enemy_duelist_hit",
  "category": "enemy",
  "subject": "Duelist Hit v02",
  "gameplay_purpose": "Duelist Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/duelist_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/duelist/enemy_duelist_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "c7e31965d46ee99dd9f97a026c4b29982518bc6531d9ce6841f21d2496cfa2f1",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png",
    "source_sha256": "12f57864b099fdbf4a4cc480dfa12ad88a3b665cfa71c39b458fa3faeb255176",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 077. asset:enemies/duelist/enemy_duelist_idle

```json
{
  "stable_asset_id": "asset:enemies/duelist/enemy_duelist_idle",
  "category": "enemy",
  "subject": "Duelist Idle v02",
  "gameplay_purpose": "Duelist Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/duelist_animation_library.tres",
    "res://src/enemies/presentation/scenes/duelist_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/duelist/enemy_duelist_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "93e765426a3903380a4e36bf05aa4b8f30838e8e6bf95fd884e50c1375f073a0",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png",
    "source_sha256": "12f57864b099fdbf4a4cc480dfa12ad88a3b665cfa71c39b458fa3faeb255176",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 078. asset:enemies/duelist/enemy_duelist_move

```json
{
  "stable_asset_id": "asset:enemies/duelist/enemy_duelist_move",
  "category": "enemy",
  "subject": "Duelist Move v02",
  "gameplay_purpose": "Duelist Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/duelist_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/duelist/enemy_duelist_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "fe81a6711fddc861df3c850fe8e7fa941d04e0284e0d798ccb946dfbca09d10f",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png",
    "source_sha256": "12f57864b099fdbf4a4cc480dfa12ad88a3b665cfa71c39b458fa3faeb255176",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 079. asset:enemies/duelist/enemy_duelist_release

```json
{
  "stable_asset_id": "asset:enemies/duelist/enemy_duelist_release",
  "category": "enemy",
  "subject": "Duelist Release v02",
  "gameplay_purpose": "Duelist Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/duelist_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/duelist/enemy_duelist_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "9ec6a94645addb233833e22c5f3628d06f3bd03db52bddf3fb29b959df77c734",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png",
    "source_sha256": "12f57864b099fdbf4a4cc480dfa12ad88a3b665cfa71c39b458fa3faeb255176",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 080. asset:enemies/duelist/enemy_duelist_windup

```json
{
  "stable_asset_id": "asset:enemies/duelist/enemy_duelist_windup",
  "category": "enemy",
  "subject": "Duelist Windup v02",
  "gameplay_purpose": "Duelist Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/duelist_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/duelist/enemy_duelist_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "8f43d4dd1381288c3f7e81ec7b93191c629eeb0e6c2757b94fda6086bc58b616",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/duelist_pixel_art_reference_sheet.png",
    "source_sha256": "12f57864b099fdbf4a4cc480dfa12ad88a3b665cfa71c39b458fa3faeb255176",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 081. asset:enemies/flying_harrier/enemy_flying_harrier_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/flying_harrier/enemy_flying_harrier_core_sheet",
  "category": "enemy",
  "subject": "Flying Harrier Core Sheet v02",
  "gameplay_purpose": "Flying Harrier Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/flying_harrier/enemy_flying_harrier_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "133cca449061b42226433e0ce631c64335c9253b7041e6546d43af63c1083f21",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png",
    "source_sha256": "75a84c5eb2b240735eca219dcfe42bec5da919ba397b504aa32befec0e58f803",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 082. asset:enemies/flying_harrier/enemy_flying_harrier_death

```json
{
  "stable_asset_id": "asset:enemies/flying_harrier/enemy_flying_harrier_death",
  "category": "enemy",
  "subject": "Flying Harrier Death v02",
  "gameplay_purpose": "Flying Harrier Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/flying_harrier_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/flying_harrier/enemy_flying_harrier_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "ce0364840b896677ecd94cd66b7249cccc7d47f23f67f96d7ed43df9bd8849e7",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png",
    "source_sha256": "75a84c5eb2b240735eca219dcfe42bec5da919ba397b504aa32befec0e58f803",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 083. asset:enemies/flying_harrier/enemy_flying_harrier_hit

```json
{
  "stable_asset_id": "asset:enemies/flying_harrier/enemy_flying_harrier_hit",
  "category": "enemy",
  "subject": "Flying Harrier Hit v02",
  "gameplay_purpose": "Flying Harrier Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/flying_harrier_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/flying_harrier/enemy_flying_harrier_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "2d617fbfd3c94f9ee66e606be0dc8fa396510d26265419e7e26b902041573259",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png",
    "source_sha256": "75a84c5eb2b240735eca219dcfe42bec5da919ba397b504aa32befec0e58f803",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 084. asset:enemies/flying_harrier/enemy_flying_harrier_idle

```json
{
  "stable_asset_id": "asset:enemies/flying_harrier/enemy_flying_harrier_idle",
  "category": "enemy",
  "subject": "Flying Harrier Idle v02",
  "gameplay_purpose": "Flying Harrier Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/flying_harrier_animation_library.tres",
    "res://src/enemies/presentation/scenes/flying_harrier_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/flying_harrier/enemy_flying_harrier_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "0370bec56241da57ffefbc284f148b5b381c8822089ab711edb3d530348cbd0d",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png",
    "source_sha256": "75a84c5eb2b240735eca219dcfe42bec5da919ba397b504aa32befec0e58f803",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 085. asset:enemies/flying_harrier/enemy_flying_harrier_move

```json
{
  "stable_asset_id": "asset:enemies/flying_harrier/enemy_flying_harrier_move",
  "category": "enemy",
  "subject": "Flying Harrier Move v02",
  "gameplay_purpose": "Flying Harrier Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/flying_harrier_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/flying_harrier/enemy_flying_harrier_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "e006d0c1cfda551bb49294e87fd6c1903632503dd5c0d9e09f31f1f1e8c99af4",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png",
    "source_sha256": "75a84c5eb2b240735eca219dcfe42bec5da919ba397b504aa32befec0e58f803",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 086. asset:enemies/flying_harrier/enemy_flying_harrier_release

```json
{
  "stable_asset_id": "asset:enemies/flying_harrier/enemy_flying_harrier_release",
  "category": "enemy",
  "subject": "Flying Harrier Release v02",
  "gameplay_purpose": "Flying Harrier Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/flying_harrier_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/flying_harrier/enemy_flying_harrier_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f77e3d4136e0b3bb6bf7f03f257d1e8cbad30360b5f3d28893a4d7af342f6ce4",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png",
    "source_sha256": "75a84c5eb2b240735eca219dcfe42bec5da919ba397b504aa32befec0e58f803",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 087. asset:enemies/flying_harrier/enemy_flying_harrier_windup

```json
{
  "stable_asset_id": "asset:enemies/flying_harrier/enemy_flying_harrier_windup",
  "category": "enemy",
  "subject": "Flying Harrier Windup v02",
  "gameplay_purpose": "Flying Harrier Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/flying_harrier_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/flying_harrier/enemy_flying_harrier_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "af41e02b7d7e8009e2f392bbc085d344f33bcc283872874690ee19b72bcfde8e",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/flying_harrier_pixel_art_sprite_sheet.png",
    "source_sha256": "75a84c5eb2b240735eca219dcfe42bec5da919ba397b504aa32befec0e58f803",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 088. asset:enemies/marksman/enemy_marksman_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/marksman/enemy_marksman_core_sheet",
  "category": "enemy",
  "subject": "Marksman Core Sheet v02",
  "gameplay_purpose": "Marksman Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/marksman/enemy_marksman_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "2ffa9882170eaa9a466caa51890a780ef522064c3864fb823f2c663095ce0d5a",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png",
    "source_sha256": "d1a04a7d3bafaac2ce903ab9ff2395ceac5b9e41c376068ec32fb2a0d92f9d27",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 089. asset:enemies/marksman/enemy_marksman_death

```json
{
  "stable_asset_id": "asset:enemies/marksman/enemy_marksman_death",
  "category": "enemy",
  "subject": "Marksman Death v02",
  "gameplay_purpose": "Marksman Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/marksman_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/marksman/enemy_marksman_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "ba3e5736d492e25f57199ec1077f2a7a0123cb8c5276db7cd4a7f79808d129d8",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png",
    "source_sha256": "d1a04a7d3bafaac2ce903ab9ff2395ceac5b9e41c376068ec32fb2a0d92f9d27",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 090. asset:enemies/marksman/enemy_marksman_hit

```json
{
  "stable_asset_id": "asset:enemies/marksman/enemy_marksman_hit",
  "category": "enemy",
  "subject": "Marksman Hit v02",
  "gameplay_purpose": "Marksman Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/marksman_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/marksman/enemy_marksman_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a38b28b1d07c35cdc9891cc22ea1e3055a3afd97045a11232084b5401fd771c8",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png",
    "source_sha256": "d1a04a7d3bafaac2ce903ab9ff2395ceac5b9e41c376068ec32fb2a0d92f9d27",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 091. asset:enemies/marksman/enemy_marksman_idle

```json
{
  "stable_asset_id": "asset:enemies/marksman/enemy_marksman_idle",
  "category": "enemy",
  "subject": "Marksman Idle v02",
  "gameplay_purpose": "Marksman Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/marksman_animation_library.tres",
    "res://src/enemies/presentation/scenes/marksman_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/marksman/enemy_marksman_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a6d950e3e6648f2a3d301bf98194b59f7eba0562618b18ed646daaafec2c4074",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png",
    "source_sha256": "d1a04a7d3bafaac2ce903ab9ff2395ceac5b9e41c376068ec32fb2a0d92f9d27",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 092. asset:enemies/marksman/enemy_marksman_move

```json
{
  "stable_asset_id": "asset:enemies/marksman/enemy_marksman_move",
  "category": "enemy",
  "subject": "Marksman Move v02",
  "gameplay_purpose": "Marksman Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/marksman_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/marksman/enemy_marksman_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "5304d08180192339b6cf02316bcc99d7932a24deaffaa901c616cf98611bddd6",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png",
    "source_sha256": "d1a04a7d3bafaac2ce903ab9ff2395ceac5b9e41c376068ec32fb2a0d92f9d27",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 093. asset:enemies/marksman/enemy_marksman_release

```json
{
  "stable_asset_id": "asset:enemies/marksman/enemy_marksman_release",
  "category": "enemy",
  "subject": "Marksman Release v02",
  "gameplay_purpose": "Marksman Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/marksman_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/marksman/enemy_marksman_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "d1d6638653cce402861bfdebe30ce1dfa465b3c50d71ee9e06b0215ac2948428",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png",
    "source_sha256": "d1a04a7d3bafaac2ce903ab9ff2395ceac5b9e41c376068ec32fb2a0d92f9d27",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 094. asset:enemies/marksman/enemy_marksman_windup

```json
{
  "stable_asset_id": "asset:enemies/marksman/enemy_marksman_windup",
  "category": "enemy",
  "subject": "Marksman Windup v02",
  "gameplay_purpose": "Marksman Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/marksman_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/marksman/enemy_marksman_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a0d2d94aadf42f994902e1d7fab75b22169dd6c08258fc59f6971835c83a22e5",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/16_bit_marksman_enemy_reference_sheet.png",
    "source_sha256": "d1a04a7d3bafaac2ce903ab9ff2395ceac5b9e41c376068ec32fb2a0d92f9d27",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 095. asset:enemies/mobile_ranged/enemy_mobile_ranged_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/mobile_ranged/enemy_mobile_ranged_core_sheet",
  "category": "enemy",
  "subject": "Mobile Ranged Core Sheet v02",
  "gameplay_purpose": "Mobile Ranged Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/mobile_ranged/enemy_mobile_ranged_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "8ddc2f71043a6e2c3b797162f5ed277e496b4fc45aab3a8dc165a82e1bb59542",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png",
    "source_sha256": "d02850f41a2730ca01b75a95e238d7f7a05abe15be34ad477b2a0cc584e9df3e",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 096. asset:enemies/mobile_ranged/enemy_mobile_ranged_death

```json
{
  "stable_asset_id": "asset:enemies/mobile_ranged/enemy_mobile_ranged_death",
  "category": "enemy",
  "subject": "Mobile Ranged Death v02",
  "gameplay_purpose": "Mobile Ranged Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/mobile_ranged_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/mobile_ranged/enemy_mobile_ranged_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "6bdda5b6fb4753df1965c779630c7711c492b6f108cc51736ca0ad8629973459",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png",
    "source_sha256": "d02850f41a2730ca01b75a95e238d7f7a05abe15be34ad477b2a0cc584e9df3e",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 097. asset:enemies/mobile_ranged/enemy_mobile_ranged_hit

```json
{
  "stable_asset_id": "asset:enemies/mobile_ranged/enemy_mobile_ranged_hit",
  "category": "enemy",
  "subject": "Mobile Ranged Hit v02",
  "gameplay_purpose": "Mobile Ranged Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/mobile_ranged_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/mobile_ranged/enemy_mobile_ranged_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "85521311dc28da1459160a24fb9bf8605ecee52339a6a908c68e9c84a9982b0a",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png",
    "source_sha256": "d02850f41a2730ca01b75a95e238d7f7a05abe15be34ad477b2a0cc584e9df3e",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 098. asset:enemies/mobile_ranged/enemy_mobile_ranged_idle

```json
{
  "stable_asset_id": "asset:enemies/mobile_ranged/enemy_mobile_ranged_idle",
  "category": "enemy",
  "subject": "Mobile Ranged Idle v02",
  "gameplay_purpose": "Mobile Ranged Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/mobile_ranged_animation_library.tres",
    "res://src/enemies/presentation/scenes/mobile_ranged_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/mobile_ranged/enemy_mobile_ranged_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "5fc51cc4b5987302b0e497139b6fcd112a5a183ea441dd45c7a3b94df0628cd2",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png",
    "source_sha256": "d02850f41a2730ca01b75a95e238d7f7a05abe15be34ad477b2a0cc584e9df3e",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 099. asset:enemies/mobile_ranged/enemy_mobile_ranged_move

```json
{
  "stable_asset_id": "asset:enemies/mobile_ranged/enemy_mobile_ranged_move",
  "category": "enemy",
  "subject": "Mobile Ranged Move v02",
  "gameplay_purpose": "Mobile Ranged Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/mobile_ranged_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/mobile_ranged/enemy_mobile_ranged_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "8983a705d5da9f44b5ccd09b8a20612ce095f3d3fd036e9659a82f065a74dc84",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png",
    "source_sha256": "d02850f41a2730ca01b75a95e238d7f7a05abe15be34ad477b2a0cc584e9df3e",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 100. asset:enemies/mobile_ranged/enemy_mobile_ranged_release

```json
{
  "stable_asset_id": "asset:enemies/mobile_ranged/enemy_mobile_ranged_release",
  "category": "enemy",
  "subject": "Mobile Ranged Release v02",
  "gameplay_purpose": "Mobile Ranged Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/mobile_ranged_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/mobile_ranged/enemy_mobile_ranged_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a1d43e8f2579357efc38c6b5d79ea814df9f1f2b413d757a01ebe01ad11e6b67",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png",
    "source_sha256": "d02850f41a2730ca01b75a95e238d7f7a05abe15be34ad477b2a0cc584e9df3e",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 101. asset:enemies/mobile_ranged/enemy_mobile_ranged_windup

```json
{
  "stable_asset_id": "asset:enemies/mobile_ranged/enemy_mobile_ranged_windup",
  "category": "enemy",
  "subject": "Mobile Ranged Windup v02",
  "gameplay_purpose": "Mobile Ranged Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/mobile_ranged_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/mobile_ranged/enemy_mobile_ranged_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "bce6fce8caa7426f8a3ab07f6ce2ea5ba6d3ff6721824641b163ed129f0ee8ae",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/mobile_ranged_pixel_art_sprite_sheet.png",
    "source_sha256": "d02850f41a2730ca01b75a95e238d7f7a05abe15be34ad477b2a0cc584e9df3e",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 102. asset:enemies/skirmisher/enemy_skirmisher_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/skirmisher/enemy_skirmisher_core_sheet",
  "category": "enemy",
  "subject": "Skirmisher Core Sheet v02",
  "gameplay_purpose": "Skirmisher Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    2172,
    724
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/skirmisher/enemy_skirmisher_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "0e202650fe256472af47234a8c271f1bec0198fb1ea4f2c2c47b9d5b5f0eed15",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png",
    "source_sha256": "0710294750946b7bfb07a6e5ed33278afaaead4f483b66d09dc2c785f7663fe5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 103. asset:enemies/skirmisher/enemy_skirmisher_death

```json
{
  "stable_asset_id": "asset:enemies/skirmisher/enemy_skirmisher_death",
  "category": "enemy",
  "subject": "Skirmisher Death v02",
  "gameplay_purpose": "Skirmisher Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    2172,
    724
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/skirmisher_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/skirmisher/enemy_skirmisher_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "87326c26472350bf098fc9dbd79825e4043774e8172f7a7e5de8c2f53196d792",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png",
    "source_sha256": "0710294750946b7bfb07a6e5ed33278afaaead4f483b66d09dc2c785f7663fe5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 104. asset:enemies/skirmisher/enemy_skirmisher_hit

```json
{
  "stable_asset_id": "asset:enemies/skirmisher/enemy_skirmisher_hit",
  "category": "enemy",
  "subject": "Skirmisher Hit v02",
  "gameplay_purpose": "Skirmisher Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    2172,
    724
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/skirmisher_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/skirmisher/enemy_skirmisher_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "61f1efaac54e4e3c58632300171c4d46d3b61f8e368d47db65df97546054327b",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png",
    "source_sha256": "0710294750946b7bfb07a6e5ed33278afaaead4f483b66d09dc2c785f7663fe5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 105. asset:enemies/skirmisher/enemy_skirmisher_idle

```json
{
  "stable_asset_id": "asset:enemies/skirmisher/enemy_skirmisher_idle",
  "category": "enemy",
  "subject": "Skirmisher Idle v02",
  "gameplay_purpose": "Skirmisher Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    2172,
    724
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/skirmisher_animation_library.tres",
    "res://src/enemies/presentation/scenes/skirmisher_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/skirmisher/enemy_skirmisher_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "bc81986bfda17340796f0abaddd89bb094525b5ed52dd4c0adc7b603bb366b15",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png",
    "source_sha256": "0710294750946b7bfb07a6e5ed33278afaaead4f483b66d09dc2c785f7663fe5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 106. asset:enemies/skirmisher/enemy_skirmisher_move

```json
{
  "stable_asset_id": "asset:enemies/skirmisher/enemy_skirmisher_move",
  "category": "enemy",
  "subject": "Skirmisher Move v02",
  "gameplay_purpose": "Skirmisher Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    2172,
    724
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/skirmisher_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/skirmisher/enemy_skirmisher_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "2e99e892d680050c50a448275ec05c3aaa0221e5dff662f501a46f1e685d7c34",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png",
    "source_sha256": "0710294750946b7bfb07a6e5ed33278afaaead4f483b66d09dc2c785f7663fe5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 107. asset:enemies/skirmisher/enemy_skirmisher_release

```json
{
  "stable_asset_id": "asset:enemies/skirmisher/enemy_skirmisher_release",
  "category": "enemy",
  "subject": "Skirmisher Release v02",
  "gameplay_purpose": "Skirmisher Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    2172,
    724
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/skirmisher_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/skirmisher/enemy_skirmisher_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "804e8c0406c3b93d5c5a1df66c52fc5c323d4b309493f023e9c01438faca84db",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png",
    "source_sha256": "0710294750946b7bfb07a6e5ed33278afaaead4f483b66d09dc2c785f7663fe5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 108. asset:enemies/skirmisher/enemy_skirmisher_windup

```json
{
  "stable_asset_id": "asset:enemies/skirmisher/enemy_skirmisher_windup",
  "category": "enemy",
  "subject": "Skirmisher Windup v02",
  "gameplay_purpose": "Skirmisher Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    2172,
    724
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/skirmisher_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/skirmisher/enemy_skirmisher_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "d831bf01825ad1f3e67094a3a2d7e69d74289c907e97152f8c6ce535d851af83",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/skirmisher_pixel_art_sprite_sheet.png",
    "source_sha256": "0710294750946b7bfb07a6e5ed33278afaaead4f483b66d09dc2c785f7663fe5",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 109. asset:enemies/summoner/enemy_summoner_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/summoner/enemy_summoner_core_sheet",
  "category": "enemy",
  "subject": "Summoner Core Sheet v02",
  "gameplay_purpose": "Summoner Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/summoner/enemy_summoner_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "e28456c170ff3c7b5c4259bb755b850109c4a9acb875b354b2655d5535b00be7",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png",
    "source_sha256": "35f8115f71555a21c27e2bb0b21c429f72c5a6b77004884a30557e2fc2cb1fe0",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 110. asset:enemies/summoner/enemy_summoner_death

```json
{
  "stable_asset_id": "asset:enemies/summoner/enemy_summoner_death",
  "category": "enemy",
  "subject": "Summoner Death v02",
  "gameplay_purpose": "Summoner Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/summoner_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/summoner/enemy_summoner_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "67edfa1f18e28acb31555733bd69fbb001f56d3b5f25af7bb26b7d4e1cf4bf2d",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png",
    "source_sha256": "35f8115f71555a21c27e2bb0b21c429f72c5a6b77004884a30557e2fc2cb1fe0",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 111. asset:enemies/summoner/enemy_summoner_hit

```json
{
  "stable_asset_id": "asset:enemies/summoner/enemy_summoner_hit",
  "category": "enemy",
  "subject": "Summoner Hit v02",
  "gameplay_purpose": "Summoner Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/summoner_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/summoner/enemy_summoner_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "2f84a1109a1c252257e0801a9536573ccf8f6606292376691a198d7c1acd52f5",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png",
    "source_sha256": "35f8115f71555a21c27e2bb0b21c429f72c5a6b77004884a30557e2fc2cb1fe0",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 112. asset:enemies/summoner/enemy_summoner_idle

```json
{
  "stable_asset_id": "asset:enemies/summoner/enemy_summoner_idle",
  "category": "enemy",
  "subject": "Summoner Idle v02",
  "gameplay_purpose": "Summoner Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/summoner_animation_library.tres",
    "res://src/enemies/presentation/scenes/summoner_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/summoner/enemy_summoner_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "35f5d5838cae92d292e8f7ce1bad9d7a26fa36a55cd426ca895abd755882150f",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png",
    "source_sha256": "35f8115f71555a21c27e2bb0b21c429f72c5a6b77004884a30557e2fc2cb1fe0",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 113. asset:enemies/summoner/enemy_summoner_move

```json
{
  "stable_asset_id": "asset:enemies/summoner/enemy_summoner_move",
  "category": "enemy",
  "subject": "Summoner Move v02",
  "gameplay_purpose": "Summoner Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/summoner_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/summoner/enemy_summoner_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "368a5642cc8b76a61081dbe06744f81ec318d448329f2c40cc277c83ec8095d9",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png",
    "source_sha256": "35f8115f71555a21c27e2bb0b21c429f72c5a6b77004884a30557e2fc2cb1fe0",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 114. asset:enemies/summoner/enemy_summoner_release

```json
{
  "stable_asset_id": "asset:enemies/summoner/enemy_summoner_release",
  "category": "enemy",
  "subject": "Summoner Release v02",
  "gameplay_purpose": "Summoner Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/summoner_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/summoner/enemy_summoner_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "d6a6019fc9ff0debfb801ae580102362462a8862ad299188c1dee80de99424b7",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png",
    "source_sha256": "35f8115f71555a21c27e2bb0b21c429f72c5a6b77004884a30557e2fc2cb1fe0",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 115. asset:enemies/summoner/enemy_summoner_windup

```json
{
  "stable_asset_id": "asset:enemies/summoner/enemy_summoner_windup",
  "category": "enemy",
  "subject": "Summoner Windup v02",
  "gameplay_purpose": "Summoner Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/summoner_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/summoner/enemy_summoner_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f3a432ac32f7734068fa5024066dcf042262b85e0398a47e94d57991b20ace98",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/summoner_pixel_art_sprite_sheet.png",
    "source_sha256": "35f8115f71555a21c27e2bb0b21c429f72c5a6b77004884a30557e2fc2cb1fe0",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 116. asset:enemies/support/enemy_support_core_sheet

```json
{
  "stable_asset_id": "asset:enemies/support/enemy_support_core_sheet",
  "category": "enemy",
  "subject": "Support Core Sheet v02",
  "gameplay_purpose": "Support Core Sheet v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle",
    "move",
    "windup",
    "release",
    "hit",
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 6
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      288,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/enemies/support/enemy_support_core_sheet_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "6eb96c42450e7dee29ee78cde63379b223918af8a83da913539c09e2f0c5eaf4",
    "dimensions": [
      288,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png",
    "source_sha256": "903ac291b0ffaddcbda4d236d9a91a8c64af14ffa15fa7c653964ce6d889a05c",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 117. asset:enemies/support/enemy_support_death

```json
{
  "stable_asset_id": "asset:enemies/support/enemy_support_death",
  "category": "enemy",
  "subject": "Support Death v02",
  "gameplay_purpose": "Support Death v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/support_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/support/enemy_support_death_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "ada83ff9d5e469090b68186077d2ff3e5cad9a4558bbe45fb02590317319acac",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png",
    "source_sha256": "903ac291b0ffaddcbda4d236d9a91a8c64af14ffa15fa7c653964ce6d889a05c",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 118. asset:enemies/support/enemy_support_hit

```json
{
  "stable_asset_id": "asset:enemies/support/enemy_support_hit",
  "category": "enemy",
  "subject": "Support Hit v02",
  "gameplay_purpose": "Support Hit v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/support_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/support/enemy_support_hit_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "f54b5f296a01f65fabcf7d0ec707b46cc38515b2db0829356e7efb97ffd70b16",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png",
    "source_sha256": "903ac291b0ffaddcbda4d236d9a91a8c64af14ffa15fa7c653964ce6d889a05c",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 119. asset:enemies/support/enemy_support_idle

```json
{
  "stable_asset_id": "asset:enemies/support/enemy_support_idle",
  "category": "enemy",
  "subject": "Support Idle v02",
  "gameplay_purpose": "Support Idle v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/support_animation_library.tres",
    "res://src/enemies/presentation/scenes/support_visual.tscn"
  ],
  "current_existing_asset": "res://assets/art/enemies/support/enemy_support_idle_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a56db61dfa08450ef43d5f0654437b82bc031337eaceb556bd44e1841c93c9e2",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png",
    "source_sha256": "903ac291b0ffaddcbda4d236d9a91a8c64af14ffa15fa7c653964ce6d889a05c",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 120. asset:enemies/support/enemy_support_move

```json
{
  "stable_asset_id": "asset:enemies/support/enemy_support_move",
  "category": "enemy",
  "subject": "Support Move v02",
  "gameplay_purpose": "Support Move v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "move"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/support_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/support/enemy_support_move_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "ab4d295124eada28176f75cf90d7cd56485a7a98af259f52e38c4166eb3b1921",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png",
    "source_sha256": "903ac291b0ffaddcbda4d236d9a91a8c64af14ffa15fa7c653964ce6d889a05c",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 121. asset:enemies/support/enemy_support_release

```json
{
  "stable_asset_id": "asset:enemies/support/enemy_support_release",
  "category": "enemy",
  "subject": "Support Release v02",
  "gameplay_purpose": "Support Release v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "release"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/support_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/support/enemy_support_release_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a7c1c2d76b40d8116d08a98d0a74a9bddc08684d496c5d7352b06d511cd5baf4",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png",
    "source_sha256": "903ac291b0ffaddcbda4d236d9a91a8c64af14ffa15fa7c653964ce6d889a05c",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 122. asset:enemies/support/enemy_support_windup

```json
{
  "stable_asset_id": "asset:enemies/support/enemy_support_windup",
  "category": "enemy",
  "subject": "Support Windup v02",
  "gameplay_purpose": "Support Windup v02",
  "required_views_directions": [
    "Side gameplay view; validate mirroring in current presenter"
  ],
  "required_animation_states": [
    "windup"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      48,
      48
    ],
    "cell": [
      48,
      48
    ]
  },
  "source_generation_dimensions": [
    1672,
    941
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/ENEMY_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png"
  ],
  "target_godot_resource_scene": [
    "res://src/enemies/presentation/libraries/support_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/enemies/support/enemy_support_windup_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "58573a796cb584177e6db181fcfb0b06ad86ce889934cdf811177323d1d16ed8",
    "dimensions": [
      48,
      48
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/enemy_refs/remaining8/support_pixel_art_sprite_sheet.png",
    "source_sha256": "903ac291b0ffaddcbda4d236d9a91a8c64af14ffa15fa7c653964ce6d889a05c",
    "source_file_exists": true
  },
  "issues": [
    "Current library uses one pose per semantic state. Bible specifies six baseline poses, no multi-frame per-state count; do not invent extra animation requirement or regenerate accepted poses."
  ]
}
```

### 123. asset:player/weapons/starter_bow

```json
{
  "stable_asset_id": "asset:player/weapons/starter_bow",
  "category": "equipment",
  "subject": "Starter Bow V02",
  "gameplay_purpose": "Starter Bow V02",
  "required_views_directions": [
    "Independent weapon/projectile plane, authored orientation with runtime aim"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/profiles/starter_weapon_ranged.tres"
  ],
  "current_existing_asset": "res://assets/art/player/weapons/starter_bow_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "fa68aa546304a6a25193fa4ec6d369a26255682292287859cc0a8ebe8bc945cc",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png",
    "source_sha256": "53168a6b9bf9b89a9cfe64e068730d56754a9a2a09838776bbe66c5cf70b14f4",
    "source_file_exists": true
  },
  "issues": []
}
```

### 124. asset:player/weapons/starter_shield

```json
{
  "stable_asset_id": "asset:player/weapons/starter_shield",
  "category": "equipment",
  "subject": "Starter Shield V02",
  "gameplay_purpose": "Starter Shield V02",
  "required_views_directions": [
    "Independent weapon/projectile plane, authored orientation with runtime aim"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/profiles/starter_weapon_melee.tres"
  ],
  "current_existing_asset": "res://assets/art/player/weapons/starter_shield_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "50c7faceb01f8d04508ff0615bcbdf960e45ba285dd4c96a5277a6ce2b325b69",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png",
    "source_sha256": "53168a6b9bf9b89a9cfe64e068730d56754a9a2a09838776bbe66c5cf70b14f4",
    "source_file_exists": true
  },
  "issues": []
}
```

### 125. asset:player/weapons/starter_staff

```json
{
  "stable_asset_id": "asset:player/weapons/starter_staff",
  "category": "equipment",
  "subject": "Starter Staff V02",
  "gameplay_purpose": "Starter Staff V02",
  "required_views_directions": [
    "Independent weapon/projectile plane, authored orientation with runtime aim"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/profiles/starter_weapon_mage.tres"
  ],
  "current_existing_asset": "res://assets/art/player/weapons/starter_staff_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "27c4c7472516cdf3c6cc5b48fba053ac5ed52975d928fab7eb1c3ce247538fda",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png",
    "source_sha256": "53168a6b9bf9b89a9cfe64e068730d56754a9a2a09838776bbe66c5cf70b14f4",
    "source_file_exists": true
  },
  "issues": []
}
```

### 126. asset:player/weapons/starter_sword

```json
{
  "stable_asset_id": "asset:player/weapons/starter_sword",
  "category": "equipment",
  "subject": "Starter Sword V02",
  "gameplay_purpose": "Starter Sword V02",
  "required_views_directions": [
    "Independent weapon/projectile plane, authored orientation with runtime aim"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/profiles/starter_weapon_melee.tres"
  ],
  "current_existing_asset": "res://assets/art/player/weapons/starter_sword_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "3a07e1d48073b665923953aa14bb8d0bed80bc16bca9613f126dc2da390d3e57",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png",
    "source_sha256": "53168a6b9bf9b89a9cfe64e068730d56754a9a2a09838776bbe66c5cf70b14f4",
    "source_file_exists": true
  },
  "issues": []
}
```

### 127. r3:interior:functional:01

```json
{
  "stable_asset_id": "r3:interior:functional:01",
  "category": "functional_interior",
  "subject": "Central Tower interior visual destination",
  "gameplay_purpose": "Central Tower interior visual destination",
  "required_views_directions": [
    "World-compatible 3/4 top-down"
  ],
  "required_animation_states": [
    "static environment; interaction animation not specified"
  ],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §24.12; functional interiors scope",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": null,
  "current_implementation_status": "Exterior/service UI exists; no interior scene/layout/art found.",
  "classification": "MISSING_GENERATE",
  "generation_revision_requirement": "Author compact reusable interior kit/layout and required interaction points before source generation. Reuse materials; eight destinations do not imply eight unrelated kits.",
  "dependencies": [
    "Room dimensions, collision, entry/exit and interaction anchors",
    "Concrete reusable kit bill of materials"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Specific furniture counts/atlas sizes are not authored; do not present example furnishings as locked requirements."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 128. r3:interior:functional:02

```json
{
  "stable_asset_id": "r3:interior:functional:02",
  "category": "functional_interior",
  "subject": "Quest Hall interior visual destination",
  "gameplay_purpose": "Quest Hall interior visual destination",
  "required_views_directions": [
    "World-compatible 3/4 top-down"
  ],
  "required_animation_states": [
    "static environment; interaction animation not specified"
  ],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §24.12; functional interiors scope",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": null,
  "current_implementation_status": "Exterior/service UI exists; no interior scene/layout/art found.",
  "classification": "MISSING_GENERATE",
  "generation_revision_requirement": "Author compact reusable interior kit/layout and required interaction points before source generation. Reuse materials; eight destinations do not imply eight unrelated kits.",
  "dependencies": [
    "Room dimensions, collision, entry/exit and interaction anchors",
    "Concrete reusable kit bill of materials"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Specific furniture counts/atlas sizes are not authored; do not present example furnishings as locked requirements."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 129. r3:interior:functional:03

```json
{
  "stable_asset_id": "r3:interior:functional:03",
  "category": "functional_interior",
  "subject": "Blacksmith interior visual destination",
  "gameplay_purpose": "Blacksmith interior visual destination",
  "required_views_directions": [
    "World-compatible 3/4 top-down"
  ],
  "required_animation_states": [
    "static environment; interaction animation not specified"
  ],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §24.12; functional interiors scope",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": null,
  "current_implementation_status": "Exterior/service UI exists; no interior scene/layout/art found.",
  "classification": "MISSING_GENERATE",
  "generation_revision_requirement": "Author compact reusable interior kit/layout and required interaction points before source generation. Reuse materials; eight destinations do not imply eight unrelated kits.",
  "dependencies": [
    "Room dimensions, collision, entry/exit and interaction anchors",
    "Concrete reusable kit bill of materials"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Specific furniture counts/atlas sizes are not authored; do not present example furnishings as locked requirements."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 130. r3:interior:functional:04

```json
{
  "stable_asset_id": "r3:interior:functional:04",
  "category": "functional_interior",
  "subject": "General Merchant interior visual destination",
  "gameplay_purpose": "General Merchant interior visual destination",
  "required_views_directions": [
    "World-compatible 3/4 top-down"
  ],
  "required_animation_states": [
    "static environment; interaction animation not specified"
  ],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §24.12; functional interiors scope",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": null,
  "current_implementation_status": "Exterior/service UI exists; no interior scene/layout/art found.",
  "classification": "MISSING_GENERATE",
  "generation_revision_requirement": "Author compact reusable interior kit/layout and required interaction points before source generation. Reuse materials; eight destinations do not imply eight unrelated kits.",
  "dependencies": [
    "Room dimensions, collision, entry/exit and interaction anchors",
    "Concrete reusable kit bill of materials"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Specific furniture counts/atlas sizes are not authored; do not present example furnishings as locked requirements."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 131. r3:interior:functional:05

```json
{
  "stable_asset_id": "r3:interior:functional:05",
  "category": "functional_interior",
  "subject": "Inn / Rest House interior visual destination",
  "gameplay_purpose": "Inn / Rest House interior visual destination",
  "required_views_directions": [
    "World-compatible 3/4 top-down"
  ],
  "required_animation_states": [
    "static environment; interaction animation not specified"
  ],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §24.12; functional interiors scope",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": null,
  "current_implementation_status": "Exterior/service UI exists; no interior scene/layout/art found.",
  "classification": "MISSING_GENERATE",
  "generation_revision_requirement": "Author compact reusable interior kit/layout and required interaction points before source generation. Reuse materials; eight destinations do not imply eight unrelated kits.",
  "dependencies": [
    "Room dimensions, collision, entry/exit and interaction anchors",
    "Concrete reusable kit bill of materials"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Specific furniture counts/atlas sizes are not authored; do not present example furnishings as locked requirements."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 132. r3:interior:functional:06

```json
{
  "stable_asset_id": "r3:interior:functional:06",
  "category": "functional_interior",
  "subject": "Storage House interior visual destination",
  "gameplay_purpose": "Storage House interior visual destination",
  "required_views_directions": [
    "World-compatible 3/4 top-down"
  ],
  "required_animation_states": [
    "static environment; interaction animation not specified"
  ],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §24.12; functional interiors scope",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": null,
  "current_implementation_status": "Exterior/service UI exists; no interior scene/layout/art found.",
  "classification": "MISSING_GENERATE",
  "generation_revision_requirement": "Author compact reusable interior kit/layout and required interaction points before source generation. Reuse materials; eight destinations do not imply eight unrelated kits.",
  "dependencies": [
    "Room dimensions, collision, entry/exit and interaction anchors",
    "Concrete reusable kit bill of materials"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Specific furniture counts/atlas sizes are not authored; do not present example furnishings as locked requirements."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 133. r3:interior:functional:07

```json
{
  "stable_asset_id": "r3:interior:functional:07",
  "category": "functional_interior",
  "subject": "Training Hall interior visual destination",
  "gameplay_purpose": "Training Hall interior visual destination",
  "required_views_directions": [
    "World-compatible 3/4 top-down"
  ],
  "required_animation_states": [
    "static environment; interaction animation not specified"
  ],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §24.12; functional interiors scope",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": null,
  "current_implementation_status": "Exterior/service UI exists; no interior scene/layout/art found.",
  "classification": "MISSING_GENERATE",
  "generation_revision_requirement": "Author compact reusable interior kit/layout and required interaction points before source generation. Reuse materials; eight destinations do not imply eight unrelated kits.",
  "dependencies": [
    "Room dimensions, collision, entry/exit and interaction anchors",
    "Concrete reusable kit bill of materials"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Specific furniture counts/atlas sizes are not authored; do not present example furnishings as locked requirements."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 134. r3:interior:functional:08

```json
{
  "stable_asset_id": "r3:interior:functional:08",
  "category": "functional_interior",
  "subject": "Clinic / Apothecary interior visual destination",
  "gameplay_purpose": "Clinic / Apothecary interior visual destination",
  "required_views_directions": [
    "World-compatible 3/4 top-down"
  ],
  "required_animation_states": [
    "static environment; interaction animation not specified"
  ],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §24.12; functional interiors scope",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": null,
  "current_implementation_status": "Exterior/service UI exists; no interior scene/layout/art found.",
  "classification": "MISSING_GENERATE",
  "generation_revision_requirement": "Author compact reusable interior kit/layout and required interaction points before source generation. Reuse materials; eight destinations do not imply eight unrelated kits.",
  "dependencies": [
    "Room dimensions, collision, entry/exit and interaction anchors",
    "Concrete reusable kit bill of materials"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Specific furniture counts/atlas sizes are not authored; do not present example furnishings as locked requirements."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

### 135. npc.blacksmith_upgrader

```json
{
  "stable_asset_id": "npc.blacksmith_upgrader",
  "category": "npc",
  "subject": "Blacksmith/upgrader",
  "gameplay_purpose": "Blacksmith/upgrader",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": {
    "frame": [
      32,
      32
    ],
    "ground_anchor": [
      16,
      29
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §30/§30.2",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/npc/presentation/profiles/blacksmith_upgrader.tres",
    "res://src/world/npc/presentation/npc_visual_presenter.gd"
  ],
  "current_existing_asset": "res://assets/art/npc/blacksmith_anchor_v01.png",
  "current_implementation_status": "Static32x32 identity texture and Inspector profile/presenter verified. Six source derivations reproduced byte-identically; both-facing resource test passed. Live NPC placement/service/quest integration is not certified by this slice.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate the identity. Finish/verify live actor placement and semantic consumers; escort motion remains its separate ANIMATION_REQUIRED record.",
  "dependencies": [
    "NPC_VISUAL_DESIGN_BIBLE.md defines 32x32 canvas, (16,29) anchor, mirrored side direction, and static identity-anchor scope",
    "Stable actor/location/interaction binding; no duplicate variable NPC"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Static identity acceptance does not imply completed NPC placement or escort animation."
  ],
  "verified_evidence": {
    "role": "blacksmith",
    "review_source": "res://assets/art/generated_sources/imagegen/npc/review/npc_blacksmith_anchor_v01.png",
    "production_path": "res://assets/art/npc/blacksmith_anchor_v01.png",
    "operation": "byte_preserving_copy",
    "crop_rect_px": [
      1024,
      0,
      1536,
      512
    ],
    "dimensions": [
      32,
      32
    ],
    "alpha_bbox_xyxy": [
      5,
      5,
      28,
      31
    ],
    "review_sha256": "e02ebf564d0b44a5a07a2920f21055f45f14c8ec4acaa6d149713bad950fb9fa",
    "production_sha256": "e02ebf564d0b44a5a07a2920f21055f45f14c8ec4acaa6d149713bad950fb9fa",
    "same_bytes_as_review": true,
    "ground_anchor": [
      16,
      29
    ],
    "alpha_bbox_convention": "PIL getbbox xyxy; max y is exclusive",
    "last_opaque_pixel_index": 30,
    "anchor_relation": "last opaque pixel index 30; ground_anchor.y 29 matches the existing player V03 body convention",
    "project_path": "res://assets/art/npc/blacksmith_anchor_v01.png",
    "modifications": "512x512 grid cell; nearest-neighbor resize to32x32; integer translation from measured alpha bbox center/bottom to x16,last occupied y30 (same existing player convention); fully transparent RGB zeroed. Exact algorithm in derivation script. Reproduced byte-identical.",
    "acceptance_status": "ACCEPTED_FOR_STATIC_NPC_ANCHOR_INTEGRATION",
    "renderer_evidence": {
      "path": "res://docs/evidence/renderer/npc_identity_anchors_v01.png",
      "sha256": "81449a6dca061e04b50cfe02e9a8ee8f8ea0cc90f0e3a66caec41388c46090e0",
      "dimensions": [
        640,
        360
      ],
      "godot": "4.6.2.stable.mono.official.71f334935",
      "renderer": "Compatibility/OpenGL 3.3 Intel Iris Xe",
      "verified": "fresh capture after production path wiring; six NPC profiles rendered through NpcVisualPresenter; nearest filtering; baseline lines aligned"
    },
    "source": "res://assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png",
    "source_sha256": "81f13fa706293b678f64d2f4bb163324b02c7b036eadf59dd3b80b6af551e23b",
    "output_sha256": "e02ebf564d0b44a5a07a2920f21055f45f14c8ec4acaa6d149713bad950fb9fa",
    "derivation_manifest": "res://assets/art/npc/npc_identity_anchors_derivation_manifest.json"
  },
  "required_content": null,
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_blacksmith_anchor_v01.png",
    "source_identity": "generated NPC identity-anchor review source; exact runtime PNG preserved",
    "exact_bytes_preserved_and_verified": true,
    "source_visual_review": "present in repository; focused renderer acceptance pending",
    "final_acceptance": "pending focused renderer/runtime validation"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "32x32 generated identity anchor exists and is referenced by Inspector profile; focused gameplay-scale renderer acceptance remains pending.",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Preserve current identity-anchor source; complete focused renderer review and runtime presenter acceptance before promotion.",
    "issues": [
      "Audit stable ID for production tracking; not claimed as existing game actor ID.",
      "No mandatory frame count or sprite direction inferred from absent NPC bible."
    ],
    "verified_evidence": {
      "project_path": "res://assets/art/npc/blacksmith_anchor_v01.png",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "sha256": "e02ebf564d0b44a5a07a2920f21055f45f14c8ec4acaa6d149713bad950fb9fa",
      "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_blacksmith_anchor_v01.png",
      "source_file_exists": true,
      "profile": "res://src/world/npc/presentation/profiles/blacksmith_upgrader.tres",
      "ground_anchor": [
        16,
        29
      ],
      "mirror_left": true
    }
  },
  "acceptance_scope": "Static artwork accepted; whole NPC runtime integration remains open."
}
```

### 136. npc.merchant

```json
{
  "stable_asset_id": "npc.merchant",
  "category": "npc",
  "subject": "Merchant",
  "gameplay_purpose": "Merchant",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": {
    "frame": [
      32,
      32
    ],
    "ground_anchor": [
      16,
      29
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §30/§30.2",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/npc/presentation/profiles/merchant.tres",
    "res://src/world/npc/presentation/npc_visual_presenter.gd"
  ],
  "current_existing_asset": "res://assets/art/npc/merchant_anchor_v01.png",
  "current_implementation_status": "Static32x32 identity texture and Inspector profile/presenter verified. Six source derivations reproduced byte-identically; both-facing resource test passed. Live NPC placement/service/quest integration is not certified by this slice.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate the identity. Finish/verify live actor placement and semantic consumers; escort motion remains its separate ANIMATION_REQUIRED record.",
  "dependencies": [
    "NPC_VISUAL_DESIGN_BIBLE.md defines 32x32 canvas, (16,29) anchor, mirrored side direction, and static identity-anchor scope",
    "Stable actor/location/interaction binding; no duplicate variable NPC"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Static identity acceptance does not imply completed NPC placement or escort animation."
  ],
  "verified_evidence": {
    "role": "merchant",
    "review_source": "res://assets/art/generated_sources/imagegen/npc/review/npc_merchant_anchor_v01.png",
    "production_path": "res://assets/art/npc/merchant_anchor_v01.png",
    "operation": "byte_preserving_copy",
    "crop_rect_px": [
      512,
      0,
      1024,
      512
    ],
    "dimensions": [
      32,
      32
    ],
    "alpha_bbox_xyxy": [
      9,
      5,
      23,
      31
    ],
    "review_sha256": "a669f3d415361dc446468c872dcb2010708e2e66a0df9f44e713cf4ad71b4583",
    "production_sha256": "a669f3d415361dc446468c872dcb2010708e2e66a0df9f44e713cf4ad71b4583",
    "same_bytes_as_review": true,
    "ground_anchor": [
      16,
      29
    ],
    "alpha_bbox_convention": "PIL getbbox xyxy; max y is exclusive",
    "last_opaque_pixel_index": 30,
    "anchor_relation": "last opaque pixel index 30; ground_anchor.y 29 matches the existing player V03 body convention",
    "project_path": "res://assets/art/npc/merchant_anchor_v01.png",
    "modifications": "512x512 grid cell; nearest-neighbor resize to32x32; integer translation from measured alpha bbox center/bottom to x16,last occupied y30 (same existing player convention); fully transparent RGB zeroed. Exact algorithm in derivation script. Reproduced byte-identical.",
    "acceptance_status": "ACCEPTED_FOR_STATIC_NPC_ANCHOR_INTEGRATION",
    "renderer_evidence": {
      "path": "res://docs/evidence/renderer/npc_identity_anchors_v01.png",
      "sha256": "81449a6dca061e04b50cfe02e9a8ee8f8ea0cc90f0e3a66caec41388c46090e0",
      "dimensions": [
        640,
        360
      ],
      "godot": "4.6.2.stable.mono.official.71f334935",
      "renderer": "Compatibility/OpenGL 3.3 Intel Iris Xe",
      "verified": "fresh capture after production path wiring; six NPC profiles rendered through NpcVisualPresenter; nearest filtering; baseline lines aligned"
    },
    "source": "res://assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png",
    "source_sha256": "81f13fa706293b678f64d2f4bb163324b02c7b036eadf59dd3b80b6af551e23b",
    "output_sha256": "a669f3d415361dc446468c872dcb2010708e2e66a0df9f44e713cf4ad71b4583",
    "derivation_manifest": "res://assets/art/npc/npc_identity_anchors_derivation_manifest.json"
  },
  "required_content": null,
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_merchant_anchor_v01.png",
    "source_identity": "generated NPC identity-anchor review source; exact runtime PNG preserved",
    "exact_bytes_preserved_and_verified": true,
    "source_visual_review": "present in repository; focused renderer acceptance pending",
    "final_acceptance": "pending focused renderer/runtime validation"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "32x32 generated identity anchor exists and is referenced by Inspector profile; focused gameplay-scale renderer acceptance remains pending.",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Preserve current identity-anchor source; complete focused renderer review and runtime presenter acceptance before promotion.",
    "issues": [
      "Audit stable ID for production tracking; not claimed as existing game actor ID.",
      "No mandatory frame count or sprite direction inferred from absent NPC bible."
    ],
    "verified_evidence": {
      "project_path": "res://assets/art/npc/merchant_anchor_v01.png",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "sha256": "a669f3d415361dc446468c872dcb2010708e2e66a0df9f44e713cf4ad71b4583",
      "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_merchant_anchor_v01.png",
      "source_file_exists": true,
      "profile": "res://src/world/npc/presentation/profiles/merchant.tres",
      "ground_anchor": [
        16,
        29
      ],
      "mirror_left": true
    }
  },
  "acceptance_scope": "Static artwork accepted; whole NPC runtime integration remains open."
}
```

### 137. npc.story_lore

```json
{
  "stable_asset_id": "npc.story_lore",
  "category": "npc",
  "subject": "Story/lore NPC",
  "gameplay_purpose": "Story/lore NPC",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": {
    "frame": [
      32,
      32
    ],
    "ground_anchor": [
      16,
      29
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §30/§30.2",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/npc/presentation/profiles/story_lore.tres",
    "res://src/world/npc/presentation/npc_visual_presenter.gd"
  ],
  "current_existing_asset": "res://assets/art/npc/lore_elder_anchor_v01.png",
  "current_implementation_status": "Static32x32 identity texture and Inspector profile/presenter verified. Six source derivations reproduced byte-identically; both-facing resource test passed. Live NPC placement/service/quest integration is not certified by this slice.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate the identity. Finish/verify live actor placement and semantic consumers; escort motion remains its separate ANIMATION_REQUIRED record.",
  "dependencies": [
    "NPC_VISUAL_DESIGN_BIBLE.md defines 32x32 canvas, (16,29) anchor, mirrored side direction, and static identity-anchor scope",
    "Stable actor/location/interaction binding; no duplicate variable NPC"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Static identity acceptance does not imply completed NPC placement or escort animation."
  ],
  "verified_evidence": {
    "role": "lore_elder",
    "review_source": "res://assets/art/generated_sources/imagegen/npc/review/npc_lore_elder_anchor_v01.png",
    "production_path": "res://assets/art/npc/lore_elder_anchor_v01.png",
    "operation": "byte_preserving_copy",
    "crop_rect_px": [
      0,
      512,
      512,
      1024
    ],
    "dimensions": [
      32,
      32
    ],
    "alpha_bbox_xyxy": [
      10,
      5,
      23,
      31
    ],
    "review_sha256": "a3910dcf1e8284b9ec2062d6092f837e0c2a886605e2fb3534c6b066e3535de9",
    "production_sha256": "a3910dcf1e8284b9ec2062d6092f837e0c2a886605e2fb3534c6b066e3535de9",
    "same_bytes_as_review": true,
    "ground_anchor": [
      16,
      29
    ],
    "alpha_bbox_convention": "PIL getbbox xyxy; max y is exclusive",
    "last_opaque_pixel_index": 30,
    "anchor_relation": "last opaque pixel index 30; ground_anchor.y 29 matches the existing player V03 body convention",
    "project_path": "res://assets/art/npc/lore_elder_anchor_v01.png",
    "modifications": "512x512 grid cell; nearest-neighbor resize to32x32; integer translation from measured alpha bbox center/bottom to x16,last occupied y30 (same existing player convention); fully transparent RGB zeroed. Exact algorithm in derivation script. Reproduced byte-identical.",
    "acceptance_status": "ACCEPTED_FOR_STATIC_NPC_ANCHOR_INTEGRATION",
    "renderer_evidence": {
      "path": "res://docs/evidence/renderer/npc_identity_anchors_v01.png",
      "sha256": "81449a6dca061e04b50cfe02e9a8ee8f8ea0cc90f0e3a66caec41388c46090e0",
      "dimensions": [
        640,
        360
      ],
      "godot": "4.6.2.stable.mono.official.71f334935",
      "renderer": "Compatibility/OpenGL 3.3 Intel Iris Xe",
      "verified": "fresh capture after production path wiring; six NPC profiles rendered through NpcVisualPresenter; nearest filtering; baseline lines aligned"
    },
    "source": "res://assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png",
    "source_sha256": "81f13fa706293b678f64d2f4bb163324b02c7b036eadf59dd3b80b6af551e23b",
    "output_sha256": "a3910dcf1e8284b9ec2062d6092f837e0c2a886605e2fb3534c6b066e3535de9",
    "derivation_manifest": "res://assets/art/npc/npc_identity_anchors_derivation_manifest.json"
  },
  "required_content": null,
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_lore_elder_anchor_v01.png",
    "source_identity": "generated NPC identity-anchor review source; exact runtime PNG preserved",
    "exact_bytes_preserved_and_verified": true,
    "source_visual_review": "present in repository; focused renderer acceptance pending",
    "final_acceptance": "pending focused renderer/runtime validation"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "32x32 generated identity anchor exists and is referenced by Inspector profile; focused gameplay-scale renderer acceptance remains pending.",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Preserve current identity-anchor source; complete focused renderer review and runtime presenter acceptance before promotion.",
    "issues": [
      "Audit stable ID for production tracking; not claimed as existing game actor ID.",
      "No mandatory frame count or sprite direction inferred from absent NPC bible."
    ],
    "verified_evidence": {
      "project_path": "res://assets/art/npc/lore_elder_anchor_v01.png",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "sha256": "a3910dcf1e8284b9ec2062d6092f837e0c2a886605e2fb3534c6b066e3535de9",
      "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_lore_elder_anchor_v01.png",
      "source_file_exists": true,
      "profile": "res://src/world/npc/presentation/profiles/story_lore.tres",
      "ground_anchor": [
        16,
        29
      ],
      "mirror_left": true
    }
  },
  "acceptance_scope": "Static artwork accepted; whole NPC runtime integration remains open."
}
```

### 138. npc.temporary_escort_actor

```json
{
  "stable_asset_id": "npc.temporary_escort_actor",
  "category": "npc",
  "subject": "Temporary escort actor",
  "gameplay_purpose": "Temporary escort actor",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": {
    "frame": [
      32,
      32
    ],
    "ground_anchor": [
      16,
      29
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §30/§30.2",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/npc/presentation/profiles/temporary_escort.tres",
    "res://src/world/npc/presentation/npc_visual_presenter.gd"
  ],
  "current_existing_asset": "res://assets/art/npc/escort_anchor_v01.png",
  "current_implementation_status": "Static32x32 identity texture and Inspector profile/presenter verified. Six source derivations reproduced byte-identically; both-facing resource test passed. Live NPC placement/service/quest integration is not certified by this slice.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate the identity. Finish/verify live actor placement and semantic consumers; escort motion remains its separate ANIMATION_REQUIRED record.",
  "dependencies": [
    "NPC_VISUAL_DESIGN_BIBLE.md defines 32x32 canvas, (16,29) anchor, mirrored side direction, and static identity-anchor scope",
    "Stable actor/location/interaction binding; no duplicate variable NPC"
  ],
  "priority": "P0",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Static identity acceptance does not imply completed NPC placement or escort animation."
  ],
  "verified_evidence": {
    "role": "escort",
    "review_source": "res://assets/art/generated_sources/imagegen/npc/review/npc_escort_anchor_v01.png",
    "production_path": "res://assets/art/npc/escort_anchor_v01.png",
    "operation": "byte_preserving_copy",
    "crop_rect_px": [
      1024,
      512,
      1536,
      1024
    ],
    "dimensions": [
      32,
      32
    ],
    "alpha_bbox_xyxy": [
      7,
      4,
      27,
      31
    ],
    "review_sha256": "2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e",
    "production_sha256": "2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e",
    "same_bytes_as_review": true,
    "ground_anchor": [
      16,
      29
    ],
    "alpha_bbox_convention": "PIL getbbox xyxy; max y is exclusive",
    "last_opaque_pixel_index": 30,
    "anchor_relation": "last opaque pixel index 30; ground_anchor.y 29 matches the existing player V03 body convention",
    "project_path": "res://assets/art/npc/escort_anchor_v01.png",
    "modifications": "512x512 grid cell; nearest-neighbor resize to32x32; integer translation from measured alpha bbox center/bottom to x16,last occupied y30 (same existing player convention); fully transparent RGB zeroed. Exact algorithm in derivation script. Reproduced byte-identical.",
    "acceptance_status": "ACCEPTED_FOR_STATIC_NPC_ANCHOR_INTEGRATION",
    "renderer_evidence": {
      "path": "res://docs/evidence/renderer/npc_identity_anchors_v01.png",
      "sha256": "81449a6dca061e04b50cfe02e9a8ee8f8ea0cc90f0e3a66caec41388c46090e0",
      "dimensions": [
        640,
        360
      ],
      "godot": "4.6.2.stable.mono.official.71f334935",
      "renderer": "Compatibility/OpenGL 3.3 Intel Iris Xe",
      "verified": "fresh capture after production path wiring; six NPC profiles rendered through NpcVisualPresenter; nearest filtering; baseline lines aligned"
    },
    "source": "res://assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png",
    "source_sha256": "81f13fa706293b678f64d2f4bb163324b02c7b036eadf59dd3b80b6af551e23b",
    "output_sha256": "2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e",
    "derivation_manifest": "res://assets/art/npc/npc_identity_anchors_derivation_manifest.json"
  },
  "required_content": null,
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_escort_anchor_v01.png",
    "source_identity": "generated NPC identity-anchor review source; exact runtime PNG preserved",
    "exact_bytes_preserved_and_verified": true,
    "source_visual_review": "present in repository; focused renderer acceptance pending",
    "final_acceptance": "pending focused renderer/runtime validation"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "32x32 generated identity anchor exists and is referenced by Inspector profile; focused gameplay-scale renderer acceptance remains pending.",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Preserve current identity-anchor source; complete focused renderer review and runtime presenter acceptance before promotion.",
    "issues": [
      "Audit stable ID for production tracking; not claimed as existing game actor ID.",
      "No mandatory frame count or sprite direction inferred from absent NPC bible."
    ],
    "verified_evidence": {
      "project_path": "res://assets/art/npc/escort_anchor_v01.png",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "sha256": "2cfa01c99e1716c168a69aff61cda8593c9ebac7e06e4ba39aa23d764aafd84e",
      "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_escort_anchor_v01.png",
      "source_file_exists": true,
      "profile": "res://src/world/npc/presentation/profiles/temporary_escort.tres",
      "ground_anchor": [
        16,
        29
      ],
      "mirror_left": true
    }
  },
  "acceptance_scope": "Static artwork accepted; whole NPC runtime integration remains open."
}
```

### 139. npc.tower_quest_coordinator

```json
{
  "stable_asset_id": "npc.tower_quest_coordinator",
  "category": "npc",
  "subject": "Tower/quest coordinator",
  "gameplay_purpose": "Tower/quest coordinator",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": {
    "frame": [
      32,
      32
    ],
    "ground_anchor": [
      16,
      29
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §30/§30.2",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/npc/presentation/profiles/tower_quest_coordinator.tres",
    "res://src/world/npc/presentation/npc_visual_presenter.gd"
  ],
  "current_existing_asset": "res://assets/art/npc/coordinator_anchor_v01.png",
  "current_implementation_status": "Static32x32 identity texture and Inspector profile/presenter verified. Six source derivations reproduced byte-identically; both-facing resource test passed. Live NPC placement/service/quest integration is not certified by this slice.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate the identity. Finish/verify live actor placement and semantic consumers; escort motion remains its separate ANIMATION_REQUIRED record.",
  "dependencies": [
    "NPC_VISUAL_DESIGN_BIBLE.md defines 32x32 canvas, (16,29) anchor, mirrored side direction, and static identity-anchor scope",
    "Stable actor/location/interaction binding; no duplicate variable NPC"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Static identity acceptance does not imply completed NPC placement or escort animation."
  ],
  "verified_evidence": {
    "role": "coordinator",
    "review_source": "res://assets/art/generated_sources/imagegen/npc/review/npc_coordinator_anchor_v01.png",
    "production_path": "res://assets/art/npc/coordinator_anchor_v01.png",
    "operation": "byte_preserving_copy",
    "crop_rect_px": [
      0,
      0,
      512,
      512
    ],
    "dimensions": [
      32,
      32
    ],
    "alpha_bbox_xyxy": [
      6,
      5,
      26,
      31
    ],
    "review_sha256": "0eb90067315b125bb74e9a2c87466d99a1f41cd2a39374b956fb17c9a205f83b",
    "production_sha256": "0eb90067315b125bb74e9a2c87466d99a1f41cd2a39374b956fb17c9a205f83b",
    "same_bytes_as_review": true,
    "ground_anchor": [
      16,
      29
    ],
    "alpha_bbox_convention": "PIL getbbox xyxy; max y is exclusive",
    "last_opaque_pixel_index": 30,
    "anchor_relation": "last opaque pixel index 30; ground_anchor.y 29 matches the existing player V03 body convention",
    "project_path": "res://assets/art/npc/coordinator_anchor_v01.png",
    "modifications": "512x512 grid cell; nearest-neighbor resize to32x32; integer translation from measured alpha bbox center/bottom to x16,last occupied y30 (same existing player convention); fully transparent RGB zeroed. Exact algorithm in derivation script. Reproduced byte-identical.",
    "acceptance_status": "ACCEPTED_FOR_STATIC_NPC_ANCHOR_INTEGRATION",
    "renderer_evidence": {
      "path": "res://docs/evidence/renderer/npc_identity_anchors_v01.png",
      "sha256": "81449a6dca061e04b50cfe02e9a8ee8f8ea0cc90f0e3a66caec41388c46090e0",
      "dimensions": [
        640,
        360
      ],
      "godot": "4.6.2.stable.mono.official.71f334935",
      "renderer": "Compatibility/OpenGL 3.3 Intel Iris Xe",
      "verified": "fresh capture after production path wiring; six NPC profiles rendered through NpcVisualPresenter; nearest filtering; baseline lines aligned"
    },
    "source": "res://assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png",
    "source_sha256": "81f13fa706293b678f64d2f4bb163324b02c7b036eadf59dd3b80b6af551e23b",
    "output_sha256": "0eb90067315b125bb74e9a2c87466d99a1f41cd2a39374b956fb17c9a205f83b",
    "derivation_manifest": "res://assets/art/npc/npc_identity_anchors_derivation_manifest.json"
  },
  "required_content": null,
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_coordinator_anchor_v01.png",
    "source_identity": "generated NPC identity-anchor review source; exact runtime PNG preserved",
    "exact_bytes_preserved_and_verified": true,
    "source_visual_review": "present in repository; focused renderer acceptance pending",
    "final_acceptance": "pending focused renderer/runtime validation"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "32x32 generated identity anchor exists and is referenced by Inspector profile; focused gameplay-scale renderer acceptance remains pending.",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Preserve current identity-anchor source; complete focused renderer review and runtime presenter acceptance before promotion.",
    "issues": [
      "Audit stable ID for production tracking; not claimed as existing game actor ID.",
      "No mandatory frame count or sprite direction inferred from absent NPC bible."
    ],
    "verified_evidence": {
      "project_path": "res://assets/art/npc/coordinator_anchor_v01.png",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "sha256": "0eb90067315b125bb74e9a2c87466d99a1f41cd2a39374b956fb17c9a205f83b",
      "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_coordinator_anchor_v01.png",
      "source_file_exists": true,
      "profile": "res://src/world/npc/presentation/profiles/tower_quest_coordinator.tres",
      "ground_anchor": [
        16,
        29
      ],
      "mirror_left": true
    }
  },
  "acceptance_scope": "Static artwork accepted; whole NPC runtime integration remains open."
}
```

### 140. npc.variable_quest_actor

```json
{
  "stable_asset_id": "npc.variable_quest_actor",
  "category": "npc",
  "subject": "Variable quest NPC",
  "gameplay_purpose": "Variable quest NPC",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": {
    "frame": [
      32,
      32
    ],
    "ground_anchor": [
      16,
      29
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md §30/§30.2",
    "res://docs/art/REGION3_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/npc/presentation/profiles/variable_quest.tres",
    "res://src/world/npc/presentation/npc_visual_presenter.gd"
  ],
  "current_existing_asset": "res://assets/art/npc/variable_quest_anchor_v01.png",
  "current_implementation_status": "Static32x32 identity texture and Inspector profile/presenter verified. Six source derivations reproduced byte-identically; both-facing resource test passed. Live NPC placement/service/quest integration is not certified by this slice.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate the identity. Finish/verify live actor placement and semantic consumers; escort motion remains its separate ANIMATION_REQUIRED record.",
  "dependencies": [
    "NPC_VISUAL_DESIGN_BIBLE.md defines 32x32 canvas, (16,29) anchor, mirrored side direction, and static identity-anchor scope",
    "Stable actor/location/interaction binding; no duplicate variable NPC"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Static identity acceptance does not imply completed NPC placement or escort animation."
  ],
  "verified_evidence": {
    "role": "variable_quest",
    "review_source": "res://assets/art/generated_sources/imagegen/npc/review/npc_variable_quest_anchor_v01.png",
    "production_path": "res://assets/art/npc/variable_quest_anchor_v01.png",
    "operation": "byte_preserving_copy",
    "crop_rect_px": [
      512,
      512,
      1024,
      1024
    ],
    "dimensions": [
      32,
      32
    ],
    "alpha_bbox_xyxy": [
      8,
      5,
      26,
      31
    ],
    "review_sha256": "6dc9da24b3508ea440d221bdcac865060a7c1ab5d358aa4f053738f8e9ffd1bb",
    "production_sha256": "6dc9da24b3508ea440d221bdcac865060a7c1ab5d358aa4f053738f8e9ffd1bb",
    "same_bytes_as_review": true,
    "ground_anchor": [
      16,
      29
    ],
    "alpha_bbox_convention": "PIL getbbox xyxy; max y is exclusive",
    "last_opaque_pixel_index": 30,
    "anchor_relation": "last opaque pixel index 30; ground_anchor.y 29 matches the existing player V03 body convention",
    "project_path": "res://assets/art/npc/variable_quest_anchor_v01.png",
    "modifications": "512x512 grid cell; nearest-neighbor resize to32x32; integer translation from measured alpha bbox center/bottom to x16,last occupied y30 (same existing player convention); fully transparent RGB zeroed. Exact algorithm in derivation script. Reproduced byte-identical.",
    "acceptance_status": "ACCEPTED_FOR_STATIC_NPC_ANCHOR_INTEGRATION",
    "renderer_evidence": {
      "path": "res://docs/evidence/renderer/npc_identity_anchors_v01.png",
      "sha256": "81449a6dca061e04b50cfe02e9a8ee8f8ea0cc90f0e3a66caec41388c46090e0",
      "dimensions": [
        640,
        360
      ],
      "godot": "4.6.2.stable.mono.official.71f334935",
      "renderer": "Compatibility/OpenGL 3.3 Intel Iris Xe",
      "verified": "fresh capture after production path wiring; six NPC profiles rendered through NpcVisualPresenter; nearest filtering; baseline lines aligned"
    },
    "source": "res://assets/art/generated_sources/imagegen/npc/npc_identity_anchors_source_v01.png",
    "source_sha256": "81f13fa706293b678f64d2f4bb163324b02c7b036eadf59dd3b80b6af551e23b",
    "output_sha256": "6dc9da24b3508ea440d221bdcac865060a7c1ab5d358aa4f053738f8e9ffd1bb",
    "derivation_manifest": "res://assets/art/npc/npc_identity_anchors_derivation_manifest.json"
  },
  "required_content": null,
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_variable_quest_anchor_v01.png",
    "source_identity": "generated NPC identity-anchor review source; exact runtime PNG preserved",
    "exact_bytes_preserved_and_verified": true,
    "source_visual_review": "present in repository; focused renderer acceptance pending",
    "final_acceptance": "pending focused renderer/runtime validation"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "32x32 generated identity anchor exists and is referenced by Inspector profile; focused gameplay-scale renderer acceptance remains pending.",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Preserve current identity-anchor source; complete focused renderer review and runtime presenter acceptance before promotion.",
    "issues": [
      "Audit stable ID for production tracking; not claimed as existing game actor ID.",
      "No mandatory frame count or sprite direction inferred from absent NPC bible."
    ],
    "verified_evidence": {
      "project_path": "res://assets/art/npc/variable_quest_anchor_v01.png",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "sha256": "6dc9da24b3508ea440d221bdcac865060a7c1ab5d358aa4f053738f8e9ffd1bb",
      "source": "res://assets/art/generated_sources/imagegen/npc/review/npc_variable_quest_anchor_v01.png",
      "source_file_exists": true,
      "profile": "res://src/world/npc/presentation/profiles/variable_quest.tres",
      "ground_anchor": [
        16,
        29
      ],
      "mirror_left": true
    }
  },
  "acceptance_scope": "Static artwork accepted; whole NPC runtime integration remains open."
}
```

### 141. npc.temporary_escort_actor.animation

```json
{
  "stable_asset_id": "npc.temporary_escort_actor.animation",
  "category": "npc_animation",
  "subject": "Escort actor movement/wait presentation",
  "gameplay_purpose": "Escort actor movement/wait presentation",
  "required_views_directions": null,
  "required_animation_states": [],
  "required_frame_counts": null,
  "expected_gameplay_dimensions": null,
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "Nice_Journey_Master_Game_Specification_V2_1.md Escort family and §30.2"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/escorts/tower_escort_runtime.gd"
  ],
  "current_existing_asset": null,
  "current_implementation_status": "Escort mechanical route/wait/failure states exist, visual presenter absent.",
  "classification": "ANIMATION_REQUIRED",
  "generation_revision_requirement": "Establish accepted character anchor before controlled animation; map only genuine runtime states.",
  "dependencies": [
    "npc.temporary_escort_actor",
    "Author state-to-animation mapping; frame counts unspecified",
    "NPC_VISUAL_DESIGN_BIBLE.md static-anchor scope does not authorize movement animation yet"
  ],
  "priority": "P0",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [],
  "verified_evidence": {},
  "required_content": null
}
```

### 142. asset:player/animations/player_body_attack_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_attack_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Attack Sheet v03",
  "gameplay_purpose": "Shared protagonist attack presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "attack"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      8
    ],
    "current": 6,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/05_climb_sleep_death.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_attack_sheet_v03.png",
  "current_implementation_status": "Original V03 remains runtime-bound. Exact body-only V04 generated source preserved; V04 derivatives staged only. Root rejected the reviewed derivation for neighbor fragments and inconsistent body scale. No V04 texture binding was present in the runtime AnimationLibrary at final inspection.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Reuse the existing body-only source. Repair crop/component selection and shared scale/pivot deterministically; then inspect native-scale animation and weapon alignment before resource integration. No new image generation is needed for the observed derivation defects.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance",
    "body_only_v04 source intake; derive only after focused source review and preserve V03 identity anchor"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source candidate reviewed/preserved; derived gameplay sheet NOT ACCEPTED.",
  "verified_evidence": {
    "source_intake": {
      "file": "player_attack_body_only_source.png",
      "sha256": "07da238fa35537841cfc7f6ae2b014b90261329e8f605a2b1de92e3648564fb7",
      "source_identity": "exec-c1feb7d2-9448-4453-bace-d26074b87683.png",
      "dimensions": [
        2171,
        724
      ],
      "reference": "../main_character_batches_v03/exact_sources/05_climb_sleep_death.png",
      "reference_region": [
        0,
        300,
        1448,
        535
      ],
      "prompt": "Edit the referenced six-frame pixel-art character attack strip. Remove only every sword blade, hilt and blue-white slash trail; reconstruct empty brown-gloved hands where hilts were held. Keep the exact same six body poses, brown spiky hair, face, blue scarf, cream sleeves, brown leather vest and gloves, blue trousers, brown boots, proportions and palette. All six face right. Preserve the attack progression, with distinct preparation, extension and recovery. Six evenly spaced full-body frames in one horizontal row, aligned feet baseline, no cropping, generous transparent margins. Real transparent background instead of grey. Crisp 16-bit-inspired pixel art. No weapons, shields, magic, particles, glow, text, labels, borders, dashboard or UI. Body-only sprite animation strip."
    },
    "source_intake_path": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "rejected_review": "res://docs/evidence/renderer/player-v04-revised-renderer-review.png",
    "runtime_binding_check": "No _v04 reference in src/player/presentation/player_body_animation_library.tres at snapshot."
  },
  "issues": [
    "Detached neighboring blue pixels visible in attack/block candidate review.",
    "Per-pose bbox normalization enlarges crouched hit poses and shrinks overhead bodies; use a shared scale.",
    "Block held-state/timing and hit frame-count selection must remain explicitly authored."
  ],
  "production_progress": {
    "source_intake": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "source": "res://assets/art/generated_sources/imagegen/player/body_only_v04/player_attack_body_only_source.png",
    "source_sha256": "07da238fa35537841cfc7f6ae2b014b90261329e8f605a2b1de92e3648564fb7",
    "source_identity": "built-in imagegen body-only replacement source; model version not exposed",
    "intake_status": "source_visually_reviewed_derivatives_pending",
    "exact_bytes_preserved_and_verified": true,
    "derivative_status": "pending deterministic derivation and gameplay-scale renderer validation",
    "final_acceptance": "pending"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
      "Silver sword and blue slash arcs baked into body."
    ],
    "verified_evidence": {
      "sha256": "6137a21748faf6ad5e2dbc13ed22dff49b98dc2c3a27d0496d4628f6aaf2c97b",
      "dimensions": [
        192,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/05_climb_sleep_death.png",
      "source_sha256": "020580789050e784d4dbe389d7bd93bb3041e7948cccef209a259b2f150410e7",
      "source_file_exists": true
    }
  }
}
```

### 143. asset:player/animations/player_body_block_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_block_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Block Sheet v03",
  "gameplay_purpose": "Shared protagonist block presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "block"
  ],
  "required_frame_counts": {
    "specified": [
      2,
      4
    ],
    "current": 7,
    "held_pose": "Required plus held pose"
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      224,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/05_climb_sleep_death.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_block_sheet_v03.png",
  "current_implementation_status": "Original V03 remains runtime-bound. Exact body-only V04 generated source preserved; V04 derivatives staged only. Root rejected the reviewed derivation for neighbor fragments and inconsistent body scale. No V04 texture binding was present in the runtime AnimationLibrary at final inspection.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Reuse the existing body-only source. Repair crop/component selection and shared scale/pivot deterministically; then inspect native-scale animation and weapon alignment before resource integration. No new image generation is needed for the observed derivation defects.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source candidate reviewed/preserved; derived gameplay sheet NOT ACCEPTED.",
  "verified_evidence": {
    "source_intake": {
      "file": "player_block_body_only_source.png",
      "sha256": "6aa6886811226d155c1a088f328ee2b07ceb9f551f95b9b546865189974887bf",
      "source_identity": "exec-f1524c55-bbe9-43fc-8d15-7c9190c57952.png",
      "dimensions": [
        2171,
        724
      ],
      "reference": "../main_character_batches_v03/exact_sources/05_climb_sleep_death.png",
      "reference_region": [
        0,
        840,
        1448,
        1070
      ],
      "prompt": "Edit this seven-frame pixel-art blocking character strip. Remove ONLY every blue translucent shield arc and glow. Preserve all seven body poses, gloved hands, face, brown spiky hair, blue scarf, cream sleeves, brown leather vest, blue trousers and brown boots exactly. Same right-facing traveler and same proportions, colors and motion sequence. Seven evenly spaced full-body sprites in one horizontal row with consistent baseline and transparent margins, no cropping. True transparent background instead of grey. Crisp pixel art. No shield, weapons, effects, magic, particles, text, labels, borders, dashboard or UI."
    },
    "source_intake_path": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "rejected_review": "res://docs/evidence/renderer/player-v04-revised-renderer-review.png",
    "runtime_binding_check": "No _v04 reference in src/player/presentation/player_body_animation_library.tres at snapshot."
  },
  "issues": [
    "Detached neighboring blue pixels visible in attack/block candidate review.",
    "Per-pose bbox normalization enlarges crouched hit poses and shrinks overhead bodies; use a shared scale.",
    "Block held-state/timing and hit frame-count selection must remain explicitly authored."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
      "Blue defensive arc baked into body.",
      "Actual frame count conflicts with visual bible range; implementation completeness claim does not resolve conflict."
    ],
    "verified_evidence": {
      "sha256": "eddb0968400b75c344faa4477ff22697fdbebaacc0de485001a16024fbdfece1",
      "dimensions": [
        224,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/05_climb_sleep_death.png",
      "source_sha256": "020580789050e784d4dbe389d7bd93bb3041e7948cccef209a259b2f150410e7",
      "source_file_exists": true
    }
  }
}
```

### 144. asset:player/animations/player_body_cast_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_cast_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Cast Sheet v03",
  "gameplay_purpose": "Shared protagonist cast presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "cast"
  ],
  "required_frame_counts": {
    "specified": [
      6,
      10
    ],
    "current": 7,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      224,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/03_parry_cast_hit.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_cast_sheet_v03.png",
  "current_implementation_status": "Original V03 remains runtime-bound. Exact body-only V04 generated source preserved; V04 derivatives staged only. Root rejected the reviewed derivation for neighbor fragments and inconsistent body scale. No V04 texture binding was present in the runtime AnimationLibrary at final inspection.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Reuse the existing body-only source. Repair crop/component selection and shared scale/pivot deterministically; then inspect native-scale animation and weapon alignment before resource integration. No new image generation is needed for the observed derivation defects.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance",
    "body_only_v04 source intake; derive only after focused source review and preserve V03 identity anchor"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source candidate reviewed/preserved; derived gameplay sheet NOT ACCEPTED.",
  "verified_evidence": {
    "source_intake": {
      "file": "player_parry_cast_hit_body_only_source.png",
      "sha256": "514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef",
      "source_identity": "exec-1baccda5-161d-42c4-a822-33e5a277d374.png",
      "dimensions": [
        1448,
        1086
      ],
      "reference": "../main_character_batches_v03/exact_sources/03_parry_cast_hit.png",
      "prompt": "Edit this pixel-art sprite sheet by removing ONLY the visual effects: all blue-white shields, arcs, magic orbs, projectiles, particles and yellow hit stars. Preserve ALL body poses exactly and reconstruct any obscured glove/cloth behind effects. Same brown-haired traveler, blue scarf, cream sleeves, leather vest, gloves, trousers, boots, palette and proportions. Keep three horizontal rows: top six parry poses, middle seven casting poses, bottom six hit-reaction poses. Preserve original pose count and motion order, even spacing and ground baseline in each row. Real transparent background instead of grey. Full characters uncropped, crisp pixel edges. No weapons, glow, effects, particles, text, labels, borders, dashboards or UI."
    },
    "source_intake_path": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "rejected_review": "res://docs/evidence/renderer/player-v04-revised-renderer-review.png",
    "runtime_binding_check": "No _v04 reference in src/player/presentation/player_body_animation_library.tres at snapshot."
  },
  "issues": [
    "Detached neighboring blue pixels visible in attack/block candidate review.",
    "Per-pose bbox normalization enlarges crouched hit poses and shrinks overhead bodies; use a shared scale.",
    "Block held-state/timing and hit frame-count selection must remain explicitly authored."
  ],
  "production_progress": {
    "source_intake": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "source": "res://assets/art/generated_sources/imagegen/player/body_only_v04/player_parry_cast_hit_body_only_source.png",
    "source_sha256": "514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef",
    "source_identity": "built-in imagegen body-only replacement source; model version not exposed",
    "intake_status": "source_visually_reviewed_derivatives_pending",
    "exact_bytes_preserved_and_verified": true,
    "derivative_status": "pending deterministic derivation and gameplay-scale renderer validation",
    "final_acceptance": "pending"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
      "Blue magic orb/ring/projectile pixels baked into body."
    ],
    "verified_evidence": {
      "sha256": "9ac16c478b368b425fdd396c82ad84645de6219ba6899befb0a7a76c84093e9d",
      "dimensions": [
        224,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/03_parry_cast_hit.png",
      "source_sha256": "900014457b6334bc1536a74beffe17c9223abbd66d01075cd5079bdc4ca0573d",
      "source_file_exists": true
    }
  }
}
```

### 145. asset:player/animations/player_body_climb_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_climb_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Climb Sheet v03",
  "gameplay_purpose": "Shared protagonist climb presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "climb"
  ],
  "required_frame_counts": {
    "specified": [
      6,
      8
    ],
    "current": 6,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/04_interact_pickup_use_item.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_climb_sheet_v03.png",
  "current_implementation_status": "Live V03 path matches its NEAREST candidate hash; previous LANCZOS derivative retained. Existing character identity preserved. This guide does not claim complete current gameplay/weapon alignment acceptance.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate. Preserve source and current nearest derivative; finish representative runtime/weapon alignment acceptance if not already documented by newer evidence.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "5028aae84d4e733617e39832bca324fc0ed3751cd158b3af7973b72c22705593",
    "dimensions": [
      192,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/04_interact_pickup_use_item.png",
    "source_sha256": "ed20954b4a208024da52cfce195d0298558a4f7d26d985155bceaa134067368c",
    "source_file_exists": true
  },
  "issues": [
    "Runtime acceptance scope must be checked separately from source/derivative hash matching."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "No new generation justified; first resolve derivation-method conflict using existing source.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration."
    ],
    "verified_evidence": {
      "sha256": "5028aae84d4e733617e39832bca324fc0ed3751cd158b3af7973b72c22705593",
      "dimensions": [
        192,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/04_interact_pickup_use_item.png",
      "source_sha256": "ed20954b4a208024da52cfce195d0298558a4f7d26d985155bceaa134067368c",
      "source_file_exists": true
    }
  }
}
```

### 146. asset:player/animations/player_body_dash_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_dash_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Dash Sheet v03",
  "gameplay_purpose": "Shared protagonist dash presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "dash"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      6
    ],
    "current": 4,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      128,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_dash_sheet_v03.png",
  "current_implementation_status": "Live V03 path matches its NEAREST candidate hash; previous LANCZOS derivative retained. Existing character identity preserved. This guide does not claim complete current gameplay/weapon alignment acceptance.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate. Preserve source and current nearest derivative; finish representative runtime/weapon alignment acceptance if not already documented by newer evidence.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "ac8eede2d6fdc84987a035573e8c4d891dbbfe686d83619a3ab17d004f1330d8",
    "dimensions": [
      128,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png",
    "source_sha256": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
    "source_file_exists": true
  },
  "issues": [
    "Runtime acceptance scope must be checked separately from source/derivative hash matching."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "No new generation justified; first resolve derivation-method conflict using existing source.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration."
    ],
    "verified_evidence": {
      "sha256": "ac8eede2d6fdc84987a035573e8c4d891dbbfe686d83619a3ab17d004f1330d8",
      "dimensions": [
        128,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png",
      "source_sha256": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
      "source_file_exists": true
    }
  }
}
```

### 147. asset:player/animations/player_body_death_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_death_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Death Sheet v03",
  "gameplay_purpose": "Shared protagonist death presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "death"
  ],
  "required_frame_counts": {
    "specified": [
      8,
      12
    ],
    "current": 6,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/04_interact_pickup_use_item.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_death_sheet_v03.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "bdc067805e431809328edcc3856f7ec27eabcc33b4773983ded971cdb218d044",
    "dimensions": [
      192,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/04_interact_pickup_use_item.png",
    "source_sha256": "ed20954b4a208024da52cfce195d0298558a4f7d26d985155bceaa134067368c",
    "source_file_exists": true
  },
  "issues": [
    "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
    "Actual frame count conflicts with visual bible range; implementation completeness claim does not resolve conflict."
  ]
}
```

### 148. asset:player/animations/player_body_dodge_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_dodge_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Dodge Sheet v03",
  "gameplay_purpose": "Shared protagonist dodge presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "dodge"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      6
    ],
    "current": 4,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      128,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/05_climb_sleep_death.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_dodge_sheet_v03.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "22c0e2b5f39810181236542f8422c1a1401a64bd97c1b97f15388fc15fa44d5c",
    "dimensions": [
      128,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/05_climb_sleep_death.png",
    "source_sha256": "020580789050e784d4dbe389d7bd93bb3041e7948cccef209a259b2f150410e7",
    "source_file_exists": true
  },
  "issues": [
    "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
    "Pale blue movement swoosh baked into body."
  ]
}
```

### 149. asset:player/animations/player_body_heavy_attack_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_heavy_attack_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Heavy Attack Sheet v03",
  "gameplay_purpose": "Shared protagonist heavy_attack presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "heavy_attack"
  ],
  "required_frame_counts": {
    "specified": [
      6,
      10
    ],
    "current": 6,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/05_climb_sleep_death.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_heavy_attack_sheet_v03.png",
  "current_implementation_status": "Original V03 remains runtime-bound. Exact body-only V04 generated source preserved; V04 derivatives staged only. Root rejected the reviewed derivation for neighbor fragments and inconsistent body scale. No V04 texture binding was present in the runtime AnimationLibrary at final inspection.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Reuse the existing body-only source. Repair crop/component selection and shared scale/pivot deterministically; then inspect native-scale animation and weapon alignment before resource integration. No new image generation is needed for the observed derivation defects.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance",
    "body_only_v04 source intake; derive only after focused source review and preserve V03 identity anchor"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source candidate reviewed/preserved; derived gameplay sheet NOT ACCEPTED.",
  "verified_evidence": {
    "source_intake": {
      "file": "player_heavy_attack_body_only_source.png",
      "sha256": "af670f93bfc622ed45d76e96227b8710662a17380ed69346171151f5e5abe3df",
      "source_identity": "exec-302ff3ff-952c-46b2-bc10-53f319ab29a3.png",
      "dimensions": [
        2171,
        724
      ],
      "reference": "../main_character_batches_v03/exact_sources/05_climb_sleep_death.png",
      "reference_region": [
        0,
        545,
        1448,
        815
      ],
      "prompt": "Edit this six-frame pixel-art heavy-attack character strip: erase every sword blade, hilt, blue-white slash arc, ground impact and spark. Reconstruct empty brown-gloved hands only where weapons were held. Preserve the same six full-body poses and their motion: raised-hand preparation, overhead windup, downward swing, low follow-through, recovery, idle. Preserve brown spiky hair, face, blue scarf, cream sleeves, brown leather vest/gloves, blue trousers/boots, palette, proportions and head size. Six evenly spaced right-facing sprites in one horizontal row, same ground baseline, fully uncropped with transparent margins. Transparent background, crisp pixel art, body only. No weapons, effects, glow, text, labels, borders, dashboards or UI."
    },
    "source_intake_path": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "rejected_review": "res://docs/evidence/renderer/player-v04-revised-renderer-review.png",
    "runtime_binding_check": "No _v04 reference in src/player/presentation/player_body_animation_library.tres at snapshot."
  },
  "issues": [
    "Detached neighboring blue pixels visible in attack/block candidate review.",
    "Per-pose bbox normalization enlarges crouched hit poses and shrinks overhead bodies; use a shared scale.",
    "Block held-state/timing and hit frame-count selection must remain explicitly authored."
  ],
  "production_progress": {
    "source_intake": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "source": "res://assets/art/generated_sources/imagegen/player/body_only_v04/player_heavy_attack_body_only_source.png",
    "source_sha256": "af670f93bfc622ed45d76e96227b8710662a17380ed69346171151f5e5abe3df",
    "source_identity": "built-in imagegen body-only replacement source; model version not exposed",
    "intake_status": "source_visually_reviewed_derivatives_pending",
    "exact_bytes_preserved_and_verified": true,
    "derivative_status": "pending deterministic derivation and gameplay-scale renderer validation",
    "final_acceptance": "pending"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
      "Silver sword and blue slash/impact arcs baked into body."
    ],
    "verified_evidence": {
      "sha256": "d3023989d2bd9a38d6b708574ff0b50606a12a2a9dd269095c4669ae4b7a28af",
      "dimensions": [
        192,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/05_climb_sleep_death.png",
      "source_sha256": "020580789050e784d4dbe389d7bd93bb3041e7948cccef209a259b2f150410e7",
      "source_file_exists": true
    }
  }
}
```

### 150. asset:player/animations/player_body_hit_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_hit_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Hit Sheet v03",
  "gameplay_purpose": "Shared protagonist hit presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "hit"
  ],
  "required_frame_counts": {
    "specified": [
      3,
      5
    ],
    "current": 6,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/03_parry_cast_hit.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_hit_sheet_v03.png",
  "current_implementation_status": "Original V03 remains runtime-bound. Exact body-only V04 generated source preserved; V04 derivatives staged only. Root rejected the reviewed derivation for neighbor fragments and inconsistent body scale. No V04 texture binding was present in the runtime AnimationLibrary at final inspection.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Reuse the existing body-only source. Repair crop/component selection and shared scale/pivot deterministically; then inspect native-scale animation and weapon alignment before resource integration. No new image generation is needed for the observed derivation defects.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance",
    "body_only_v04 source intake; derive only after focused source review and preserve V03 identity anchor"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source candidate reviewed/preserved; derived gameplay sheet NOT ACCEPTED.",
  "verified_evidence": {
    "source_intake": {
      "file": "player_parry_cast_hit_body_only_source.png",
      "sha256": "514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef",
      "source_identity": "exec-1baccda5-161d-42c4-a822-33e5a277d374.png",
      "dimensions": [
        1448,
        1086
      ],
      "reference": "../main_character_batches_v03/exact_sources/03_parry_cast_hit.png",
      "prompt": "Edit this pixel-art sprite sheet by removing ONLY the visual effects: all blue-white shields, arcs, magic orbs, projectiles, particles and yellow hit stars. Preserve ALL body poses exactly and reconstruct any obscured glove/cloth behind effects. Same brown-haired traveler, blue scarf, cream sleeves, leather vest, gloves, trousers, boots, palette and proportions. Keep three horizontal rows: top six parry poses, middle seven casting poses, bottom six hit-reaction poses. Preserve original pose count and motion order, even spacing and ground baseline in each row. Real transparent background instead of grey. Full characters uncropped, crisp pixel edges. No weapons, glow, effects, particles, text, labels, borders, dashboards or UI."
    },
    "source_intake_path": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "rejected_review": "res://docs/evidence/renderer/player-v04-revised-renderer-review.png",
    "runtime_binding_check": "No _v04 reference in src/player/presentation/player_body_animation_library.tres at snapshot."
  },
  "issues": [
    "Detached neighboring blue pixels visible in attack/block candidate review.",
    "Per-pose bbox normalization enlarges crouched hit poses and shrinks overhead bodies; use a shared scale.",
    "Block held-state/timing and hit frame-count selection must remain explicitly authored."
  ],
  "production_progress": {
    "source_intake": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "source": "res://assets/art/generated_sources/imagegen/player/body_only_v04/player_parry_cast_hit_body_only_source.png",
    "source_sha256": "514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef",
    "source_identity": "built-in imagegen body-only replacement source; model version not exposed",
    "intake_status": "source_visually_reviewed_derivatives_pending",
    "exact_bytes_preserved_and_verified": true,
    "derivative_status": "pending deterministic derivation and gameplay-scale renderer validation",
    "final_acceptance": "pending"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
      "Orange impact spark baked into body.",
      "Actual frame count conflicts with visual bible range; implementation completeness claim does not resolve conflict."
    ],
    "verified_evidence": {
      "sha256": "ff6c95a96de393db13d850b47484e801912e6b7b45bfe175ffbf6e41d4750d29",
      "dimensions": [
        192,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/03_parry_cast_hit.png",
      "source_sha256": "900014457b6334bc1536a74beffe17c9223abbd66d01075cd5079bdc4ca0573d",
      "source_file_exists": true
    }
  }
}
```

### 151. asset:player/animations/player_body_idle_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_idle_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Idle Sheet v03",
  "gameplay_purpose": "Shared protagonist idle presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "idle"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      6
    ],
    "current": 4,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      128,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/player.tscn",
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_idle_sheet_v03.png",
  "current_implementation_status": "Live V03 path matches its NEAREST candidate hash; previous LANCZOS derivative retained. Existing character identity preserved. This guide does not claim complete current gameplay/weapon alignment acceptance.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate. Preserve source and current nearest derivative; finish representative runtime/weapon alignment acceptance if not already documented by newer evidence.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "afef13e374f484bebdcea056e606932a63016112e1f1dc91eee5575a6b678c3a",
    "dimensions": [
      128,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png",
    "source_sha256": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
    "source_file_exists": true
  },
  "issues": [
    "Runtime acceptance scope must be checked separately from source/derivative hash matching."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "No new generation justified; first resolve derivation-method conflict using existing source.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration."
    ],
    "verified_evidence": {
      "sha256": "afef13e374f484bebdcea056e606932a63016112e1f1dc91eee5575a6b678c3a",
      "dimensions": [
        128,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png",
      "source_sha256": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
      "source_file_exists": true
    }
  }
}
```

### 152. asset:player/animations/player_body_interact_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_interact_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Interact Sheet v03",
  "gameplay_purpose": "Shared protagonist interact presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "interact"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      6
    ],
    "current": 5,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/02_dodge_attack_heavy_block.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_interact_sheet_v03.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "6df0a03f1b64154ca3ec3e36093167fa0778335cf6aeb83cf4ea88b444f05443",
    "dimensions": [
      160,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/02_dodge_attack_heavy_block.png",
    "source_sha256": "04821bcbf1f6805ab1ca17f9f34a77e205f3cd4ae3371b1720c308ba631ccc51",
    "source_file_exists": true
  },
  "issues": [
    "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
    "Orange interaction spark baked into body."
  ]
}
```

### 153. asset:player/animations/player_body_parry_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_parry_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Parry Sheet v03",
  "gameplay_purpose": "Shared protagonist parry presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "parry"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      6
    ],
    "current": 6,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/03_parry_cast_hit.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_parry_sheet_v03.png",
  "current_implementation_status": "Original V03 remains runtime-bound. Exact body-only V04 generated source preserved; V04 derivatives staged only. Root rejected the reviewed derivation for neighbor fragments and inconsistent body scale. No V04 texture binding was present in the runtime AnimationLibrary at final inspection.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Reuse the existing body-only source. Repair crop/component selection and shared scale/pivot deterministically; then inspect native-scale animation and weapon alignment before resource integration. No new image generation is needed for the observed derivation defects.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance",
    "body_only_v04 source intake; derive only after focused source review and preserve V03 identity anchor"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source candidate reviewed/preserved; derived gameplay sheet NOT ACCEPTED.",
  "verified_evidence": {
    "source_intake": {
      "file": "player_parry_cast_hit_body_only_source.png",
      "sha256": "514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef",
      "source_identity": "exec-1baccda5-161d-42c4-a822-33e5a277d374.png",
      "dimensions": [
        1448,
        1086
      ],
      "reference": "../main_character_batches_v03/exact_sources/03_parry_cast_hit.png",
      "prompt": "Edit this pixel-art sprite sheet by removing ONLY the visual effects: all blue-white shields, arcs, magic orbs, projectiles, particles and yellow hit stars. Preserve ALL body poses exactly and reconstruct any obscured glove/cloth behind effects. Same brown-haired traveler, blue scarf, cream sleeves, leather vest, gloves, trousers, boots, palette and proportions. Keep three horizontal rows: top six parry poses, middle seven casting poses, bottom six hit-reaction poses. Preserve original pose count and motion order, even spacing and ground baseline in each row. Real transparent background instead of grey. Full characters uncropped, crisp pixel edges. No weapons, glow, effects, particles, text, labels, borders, dashboards or UI."
    },
    "source_intake_path": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "rejected_review": "res://docs/evidence/renderer/player-v04-revised-renderer-review.png",
    "runtime_binding_check": "No _v04 reference in src/player/presentation/player_body_animation_library.tres at snapshot."
  },
  "issues": [
    "Detached neighboring blue pixels visible in attack/block candidate review.",
    "Per-pose bbox normalization enlarges crouched hit poses and shrinks overhead bodies; use a shared scale.",
    "Block held-state/timing and hit frame-count selection must remain explicitly authored."
  ],
  "production_progress": {
    "source_intake": "res://assets/art/generated_sources/imagegen/player/body_only_v04/source_intake.json",
    "source": "res://assets/art/generated_sources/imagegen/player/body_only_v04/player_parry_cast_hit_body_only_source.png",
    "source_sha256": "514c5fb3427bce3a84641f7687c595e950a43afe94fdc0bfce9819750fbd43ef",
    "source_identity": "built-in imagegen body-only replacement source; model version not exposed",
    "intake_status": "source_visually_reviewed_derivatives_pending",
    "exact_bytes_preserved_and_verified": true,
    "derivative_status": "pending deterministic derivation and gameplay-scale renderer validation",
    "final_acceptance": "pending"
  },
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
      "Blue parry arc baked into body."
    ],
    "verified_evidence": {
      "sha256": "033ddc57f3f950836b283b01a9e853172760c4b61ffb216010caa7dd4264a5fa",
      "dimensions": [
        192,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/03_parry_cast_hit.png",
      "source_sha256": "900014457b6334bc1536a74beffe17c9223abbd66d01075cd5079bdc4ca0573d",
      "source_file_exists": true
    }
  }
}
```

### 154. asset:player/animations/player_body_pickup_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_pickup_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Pickup Sheet v03",
  "gameplay_purpose": "Shared protagonist pickup presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "pickup"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      6
    ],
    "current": 5,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/02_dodge_attack_heavy_block.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_pickup_sheet_v03.png",
  "current_implementation_status": "Live V03 path matches its NEAREST candidate hash; previous LANCZOS derivative retained. Existing character identity preserved. This guide does not claim complete current gameplay/weapon alignment acceptance.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate. Preserve source and current nearest derivative; finish representative runtime/weapon alignment acceptance if not already documented by newer evidence.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "bb0d643cbc3e1bec9c8d6014867620ebde40bef9ddb660cc6e7c5205f33eb7e7",
    "dimensions": [
      160,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/02_dodge_attack_heavy_block.png",
    "source_sha256": "04821bcbf1f6805ab1ca17f9f34a77e205f3cd4ae3371b1720c308ba631ccc51",
    "source_file_exists": true
  },
  "issues": [
    "Runtime acceptance scope must be checked separately from source/derivative hash matching."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "No new generation justified; first resolve derivation-method conflict using existing source.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration."
    ],
    "verified_evidence": {
      "sha256": "bb0d643cbc3e1bec9c8d6014867620ebde40bef9ddb660cc6e7c5205f33eb7e7",
      "dimensions": [
        160,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/02_dodge_attack_heavy_block.png",
      "source_sha256": "04821bcbf1f6805ab1ca17f9f34a77e205f3cd4ae3371b1720c308ba631ccc51",
      "source_file_exists": true
    }
  }
}
```

### 155. asset:player/animations/player_body_run_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_run_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Run Sheet v03",
  "gameplay_purpose": "Shared protagonist run presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "run"
  ],
  "required_frame_counts": {
    "specified": [
      6,
      8
    ],
    "current": 6,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_run_sheet_v03.png",
  "current_implementation_status": "Live V03 path matches its NEAREST candidate hash; previous LANCZOS derivative retained. Existing character identity preserved. This guide does not claim complete current gameplay/weapon alignment acceptance.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate. Preserve source and current nearest derivative; finish representative runtime/weapon alignment acceptance if not already documented by newer evidence.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "4e97306e00fd71d792e733511db1713fdd3d73fec5d39d2f8afdc9d65cd61230",
    "dimensions": [
      192,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png",
    "source_sha256": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
    "source_file_exists": true
  },
  "issues": [
    "Runtime acceptance scope must be checked separately from source/derivative hash matching."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "No new generation justified; first resolve derivation-method conflict using existing source.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration."
    ],
    "verified_evidence": {
      "sha256": "4e97306e00fd71d792e733511db1713fdd3d73fec5d39d2f8afdc9d65cd61230",
      "dimensions": [
        192,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png",
      "source_sha256": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
      "source_file_exists": true
    }
  }
}
```

### 156. asset:player/animations/player_body_sleep_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_sleep_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Sleep Sheet v03",
  "gameplay_purpose": "Shared protagonist sleep presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "sleep"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      6
    ],
    "current": 4,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      128,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/04_interact_pickup_use_item.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_sleep_sheet_v03.png",
  "current_implementation_status": "Live V03 path matches its NEAREST candidate hash; previous LANCZOS derivative retained. Existing character identity preserved. This guide does not claim complete current gameplay/weapon alignment acceptance.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate. Preserve source and current nearest derivative; finish representative runtime/weapon alignment acceptance if not already documented by newer evidence.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "b814da9a3f7c5a94e427abc904c794a1541cb83d828ec8603bf5420317dea5e4",
    "dimensions": [
      128,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/04_interact_pickup_use_item.png",
    "source_sha256": "ed20954b4a208024da52cfce195d0298558a4f7d26d985155bceaa134067368c",
    "source_file_exists": true
  },
  "issues": [
    "Runtime acceptance scope must be checked separately from source/derivative hash matching."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "No new generation justified; first resolve derivation-method conflict using existing source.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration."
    ],
    "verified_evidence": {
      "sha256": "b814da9a3f7c5a94e427abc904c794a1541cb83d828ec8603bf5420317dea5e4",
      "dimensions": [
        128,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/04_interact_pickup_use_item.png",
      "source_sha256": "ed20954b4a208024da52cfce195d0298558a4f7d26d985155bceaa134067368c",
      "source_file_exists": true
    }
  }
}
```

### 157. asset:player/animations/player_body_use_item_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_use_item_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Use Item Sheet v03",
  "gameplay_purpose": "Shared protagonist use_item presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "use_item"
  ],
  "required_frame_counts": {
    "specified": [
      4,
      6
    ],
    "current": 7,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      224,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/02_dodge_attack_heavy_block.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_use_item_sheet_v03.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Controlled revision only if source-level defect cannot be fixed by permitted deterministic derivation; preserve V03 identity anchor.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "6db3f4970e0b74f2f4f25c9124b5e8f87a922187076ad8c56ff3dda3094b02b2",
    "dimensions": [
      224,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/02_dodge_attack_heavy_block.png",
    "source_sha256": "04821bcbf1f6805ab1ca17f9f34a77e205f3cd4ae3371b1720c308ba631ccc51",
    "source_file_exists": true
  },
  "issues": [
    "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration.",
    "Blue item/particle pixels baked into sequence; separate item pose may be intentional, isolate VFX review.",
    "Actual frame count conflicts with visual bible range; implementation completeness claim does not resolve conflict."
  ]
}
```

### 158. asset:player/animations/player_body_walk_sheet

```json
{
  "stable_asset_id": "asset:player/animations/player_body_walk_sheet",
  "category": "player_character_animation",
  "subject": "Player Body Walk Sheet v03",
  "gameplay_purpose": "Shared protagonist walk presentation",
  "required_views_directions": [
    "Right-facing side profile; runtime mirror for left"
  ],
  "required_animation_states": [
    "walk"
  ],
  "required_frame_counts": {
    "specified": [
      6,
      8
    ],
    "current": 6,
    "held_pose": null
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      32
    ],
    "cell": [
      32,
      32
    ],
    "pivot": [
      16,
      29
    ],
    "grip": [
      23,
      17
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png"
  ],
  "target_godot_resource_scene": [
    "res://src/player/presentation/player_body_animation_library.tres"
  ],
  "current_existing_asset": "res://assets/art/player/animations/player_body_walk_sheet_v03.png",
  "current_implementation_status": "Live V03 path matches its NEAREST candidate hash; previous LANCZOS derivative retained. Existing character identity preserved. This guide does not claim complete current gameplay/weapon alignment acceptance.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Do not regenerate. Preserve source and current nearest derivative; finish representative runtime/weapon alignment acceptance if not already documented by newer evidence.",
  "dependencies": [
    "Preserve current V03 user-supplied character identity; older slate/teal bible identity conflicts with current brown/blue anchor",
    "Separate weapons/VFX; do not infer new gameplay actions",
    "Resolve frame-count and derivation conflicts before acceptance"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "48965f63398d6cc167f45127fff61d168e8d396145fde1d11f604fff50a99dbe",
    "dimensions": [
      192,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png",
    "source_sha256": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
    "source_file_exists": true
  },
  "issues": [
    "Runtime acceptance scope must be checked separately from source/derivative hash matching."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "EXISTS_NEEDS_REVISION",
    "generation_revision_requirement": "No new generation justified; first resolve derivation-method conflict using existing source.",
    "issues": [
      "V03 derivation records LANCZOS reduction; integration protocol specifies nearest-neighbor. Preserve approved source; review/rederive before considering regeneration."
    ],
    "verified_evidence": {
      "sha256": "48965f63398d6cc167f45127fff61d168e8d396145fde1d11f604fff50a99dbe",
      "dimensions": [
        192,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/01_idle_walk_run_dash.png",
      "source_sha256": "1090071689bd5071522832b0e156ac5ecf7b290273c93d250fa0b2b62467a997",
      "source_file_exists": true
    }
  }
}
```

### 159. asset:player/weapons/arcane_projectile

```json
{
  "stable_asset_id": "asset:player/weapons/arcane_projectile",
  "category": "projectile",
  "subject": "Arcane Projectile V02",
  "gameplay_purpose": "Arcane Projectile V02",
  "required_views_directions": [
    "Independent weapon/projectile plane, authored orientation with runtime aim"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      16
    ],
    "cell": [
      32,
      16
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/player/weapons/arcane_projectile_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "NONE: preserve existing generated sprite; wire presentation only after actual projectile runtime owner is established.",
  "dependencies": [],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "5ef936c9b85ccfc190a72fabd55e8d1a78683bf7c2cd696433888e28f48cef30",
    "dimensions": [
      32,
      16
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png",
    "source_sha256": "53168a6b9bf9b89a9cfe64e068730d56754a9a2a09838776bbe66c5cf70b14f4",
    "source_file_exists": true
  },
  "issues": [
    "No consuming texture reference found anywhere in src .gd/.tscn/.tres; semantic delivery contracts are not a visual consumer."
  ]
}
```

### 160. asset:player/weapons/arrow_projectile

```json
{
  "stable_asset_id": "asset:player/weapons/arrow_projectile",
  "category": "projectile",
  "subject": "Arrow Projectile V02",
  "gameplay_purpose": "Arrow Projectile V02",
  "required_views_directions": [
    "Independent weapon/projectile plane, authored orientation with runtime aim"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      16
    ],
    "cell": [
      32,
      16
    ]
  },
  "source_generation_dimensions": [
    1448,
    1086
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/PLAYER_VISUAL_DESIGN_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/player/weapons/arrow_projectile_v02.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "NONE: preserve existing generated sprite; wire presentation only after actual projectile runtime owner is established.",
  "dependencies": [],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "c860c37bb98562a6080e81a172d63e1880486d99dc9f011693093d64c097d25a",
    "dimensions": [
      32,
      16
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      252
    ],
    "source": "res://assets/art/generated_sources/imagegen/exact_sources/q_a_clean_transparent_background_sprite_sheet_gam_4_batch_3.png",
    "source_sha256": "53168a6b9bf9b89a9cfe64e068730d56754a9a2a09838776bbe66c5cf70b14f4",
    "source_file_exists": true
  },
  "issues": [
    "No consuming texture reference found anywhere in src .gd/.tscn/.tres; semantic delivery contracts are not a visual consumer."
  ]
}
```

### 161. asset:environments/region3/functional_buildings/region3_blacksmith_exterior

```json
{
  "stable_asset_id": "asset:environments/region3/functional_buildings/region3_blacksmith_exterior",
  "category": "region3_building",
  "subject": "Region 3 Blacksmith Exterior v02",
  "gameplay_purpose": "Region 3 Blacksmith Exterior v02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      192
    ],
    "cell": [
      192,
      192
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/isometric_pixel_art_blacksmith_forge.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/blacksmith_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/functional_buildings/region3_blacksmith_exterior_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "af0e7b72d00909e2f6b56697166c75270b2ff2247cace154992497f91fbd9f88",
    "dimensions": [
      192,
      192
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/isometric_pixel_art_blacksmith_forge.png",
    "source_sha256": "bc60c515486bdf4c77288df87482a43dac8b206fdfda998b3ab624381585a006",
    "source_file_exists": true
  },
  "issues": []
}
```

### 162. asset:environments/region3/functional_buildings/region3_central_tower_exterior

```json
{
  "stable_asset_id": "asset:environments/region3/functional_buildings/region3_central_tower_exterior",
  "category": "region3_building",
  "subject": "Region 3 Central Tower Exterior v02",
  "gameplay_purpose": "Region 3 Central Tower Exterior v02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      224,
      224
    ],
    "cell": [
      224,
      224
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/isometric_fantasy_tower_keep.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/central_tower_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "3f77b84bad24542f5948bec6f80e737c6f074d47830a76dc7056022aecb61d4f",
    "dimensions": [
      224,
      224
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/isometric_fantasy_tower_keep.png",
    "source_sha256": "9509fbdccc81f8d63b30fbf9441eb3b73e8bc9bd0e51652d1d2cda7e01c32f33",
    "source_file_exists": true
  },
  "issues": []
}
```

### 163. asset:environments/region3/functional_buildings/region3_clinic_exterior

```json
{
  "stable_asset_id": "asset:environments/region3/functional_buildings/region3_clinic_exterior",
  "category": "region3_building",
  "subject": "Region 3 Clinic / Apothecary Exterior v02",
  "gameplay_purpose": "Region 3 Clinic / Apothecary Exterior v02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      192
    ],
    "cell": [
      192,
      192
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/pixel_art_fantasy_apothecary_clinic.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/clinic_apothecary_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/functional_buildings/region3_clinic_exterior_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "4b523dd4a07f800fc4f849bbf692291081f472159bc776571e7051575d701a34",
    "dimensions": [
      192,
      192
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/pixel_art_fantasy_apothecary_clinic.png",
    "source_sha256": "69ecbf50536c8c6b38a2aaf34a39691182f16a0a9a2105fe00beb1b53731fe92",
    "source_file_exists": true
  },
  "issues": []
}
```

### 164. asset:environments/region3/functional_buildings/region3_inn_exterior

```json
{
  "stable_asset_id": "asset:environments/region3/functional_buildings/region3_inn_exterior",
  "category": "region3_building",
  "subject": "Region 3 Inn / Rest House Exterior v02",
  "gameplay_purpose": "Region 3 Inn / Rest House Exterior v02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      192
    ],
    "cell": [
      192,
      192
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/cozy_fantasy_inn_pixel_art_asset.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/inn_rest_house_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/functional_buildings/region3_inn_exterior_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "8fd1b63c615e71da031f5de90f67394e61967d6dbb32c91d03c0bb0902b3097c",
    "dimensions": [
      192,
      192
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/cozy_fantasy_inn_pixel_art_asset.png",
    "source_sha256": "d7754b0cfcb369745fa02d99ad52135a417c0a04c4e568e410b12ad84d641e52",
    "source_file_exists": true
  },
  "issues": []
}
```

### 165. asset:environments/region3/functional_buildings/region3_merchant_exterior

```json
{
  "stable_asset_id": "asset:environments/region3/functional_buildings/region3_merchant_exterior",
  "category": "region3_building",
  "subject": "Region 3 General Merchant Exterior v02",
  "gameplay_purpose": "Region 3 General Merchant Exterior v02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      192
    ],
    "cell": [
      192,
      192
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/pixel_merchant_shop_sprite.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/general_merchant_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/functional_buildings/region3_merchant_exterior_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "f3affe2eb495c849c346b36aadb730cf0e95b67b21288d18d5d6e45d17d13fa9",
    "dimensions": [
      192,
      192
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/pixel_merchant_shop_sprite.png",
    "source_sha256": "a82c6bd38becb20635b78ae2add3bbdcef74e701280f047879f0eb246c68b0ab",
    "source_file_exists": true
  },
  "issues": []
}
```

### 166. asset:environments/region3/functional_buildings/region3_quest_hall_exterior

```json
{
  "stable_asset_id": "asset:environments/region3/functional_buildings/region3_quest_hall_exterior",
  "category": "region3_building",
  "subject": "Region 3 Quest Hall Exterior v02",
  "gameplay_purpose": "Region 3 Quest Hall Exterior v02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      192
    ],
    "cell": [
      192,
      192
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/pixel_art_adventurers_guild_hall.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/quest_hall_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/functional_buildings/region3_quest_hall_exterior_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "81856279e1a548fc3fc10886144ffad0521c08e87adc996dae3814a9d029f4a2",
    "dimensions": [
      192,
      192
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/pixel_art_adventurers_guild_hall.png",
    "source_sha256": "6197332d5daacc0cb3aa3d14a3fef12273df66bc9a2d4bf2afc6921ede2723fb",
    "source_file_exists": true
  },
  "issues": []
}
```

### 167. asset:environments/region3/functional_buildings/region3_storage_exterior

```json
{
  "stable_asset_id": "asset:environments/region3/functional_buildings/region3_storage_exterior",
  "category": "region3_building",
  "subject": "Region 3 Storage House Exterior v02",
  "gameplay_purpose": "Region 3 Storage House Exterior v02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      192
    ],
    "cell": [
      192,
      192
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/isometric_fantasy_warehouse_sprite.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/storage_house_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/functional_buildings/region3_storage_exterior_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "2df33a4587073349c8f0357dc260f7c6d226b908c03a80e368d75d1cb574decb",
    "dimensions": [
      192,
      192
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/isometric_fantasy_warehouse_sprite.png",
    "source_sha256": "8fdeee3d722d55ec9df2b75bbc04c7b990ecaa017552041696154e0c2e35fcfc",
    "source_file_exists": true
  },
  "issues": []
}
```

### 168. asset:environments/region3/functional_buildings/region3_training_exterior

```json
{
  "stable_asset_id": "asset:environments/region3/functional_buildings/region3_training_exterior",
  "category": "region3_building",
  "subject": "Region 3 Training Hall Exterior v02",
  "gameplay_purpose": "Region 3 Training Hall Exterior v02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      192,
      192
    ],
    "cell": [
      192,
      192
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/pixel_art_fantasy_training_hall.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/training_hall_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/functional_buildings/region3_training_exterior_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "6a16278a77eeb2c30d2c78ac7520876696e28436e24e7cc8f0da26a0bc743db9",
    "dimensions": [
      192,
      192
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/functional_buildings_v02/pixel_art_fantasy_training_hall.png",
    "source_sha256": "aef2c05e262968c7a57a135de91aa056f2a94315e508587e5683f92819b2be59",
    "source_file_exists": true
  },
  "issues": []
}
```

### 169. r3:decorative:01

```json
{
  "stable_asset_id": "r3:decorative:01",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 01 V02",
  "gameplay_purpose": "Region3 Decorative Building 01 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_01_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_01_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_01_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "787327da18265677910be24fc6e08cf886a83ae3d57d3dce52cb0da4d46074d1",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_01_source_v02.png",
    "source_sha256": "9ad69a1efd6cbcdc37e2c06d0aeb310999eec4bb398ded4c46b39289a443041e",
    "source_file_exists": true
  },
  "issues": []
}
```

### 170. r3:decorative:02

```json
{
  "stable_asset_id": "r3:decorative:02",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 02 V02",
  "gameplay_purpose": "Region3 Decorative Building 02 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_02_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_02_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_02_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "5f5197e0d82d00c4db4377d2911901acee488239d859498948fd857c2134c94e",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_02_source_v02.png",
    "source_sha256": "d02d43a1b5c403ab55748c1f85785fe1718a1f7356c4de964dac767542527b72",
    "source_file_exists": true
  },
  "issues": []
}
```

### 171. r3:decorative:03

```json
{
  "stable_asset_id": "r3:decorative:03",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 03 V02",
  "gameplay_purpose": "Region3 Decorative Building 03 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_03_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_03_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_03_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "b254d3a2b38272a45e6cf879f41b06841d8afbec79a201b61d5bd63fee0575c0",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_03_source_v02.png",
    "source_sha256": "10249f6c32ae4753bb4a7742df0c9e6f4a52a5fb1953c66360bca074bbe53962",
    "source_file_exists": true
  },
  "issues": []
}
```

### 172. r3:decorative:04

```json
{
  "stable_asset_id": "r3:decorative:04",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 04 V02",
  "gameplay_purpose": "Region3 Decorative Building 04 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_04_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_04_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_04_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "c525d58c2b381aeec795f9766deaf2936145f8e49e4bec74e7141e863e6fa3fb",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_04_source_v02.png",
    "source_sha256": "bf940a38c76b3c3bd02eb6ebac52b1a2e1846d19d798547c97e96290b129b934",
    "source_file_exists": true
  },
  "issues": []
}
```

### 173. r3:decorative:05

```json
{
  "stable_asset_id": "r3:decorative:05",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 05 V02",
  "gameplay_purpose": "Region3 Decorative Building 05 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_05_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_05_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_05_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "9825eca365d6f9ed0affe0d2f604fe3eb27687af028b4ae9e76e03d3399a2a0c",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_05_source_v02.png",
    "source_sha256": "0cac7e66753cc3ff6693eb0a8d84b7cd01af32a75893a0c33114aaf130893f39",
    "source_file_exists": true
  },
  "issues": []
}
```

### 174. r3:decorative:06

```json
{
  "stable_asset_id": "r3:decorative:06",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 06 V02",
  "gameplay_purpose": "Region3 Decorative Building 06 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_06_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_06_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_06_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "ff2f3fbec117d9df91745b505985652ed473ec73670cb1e5ad98419749f6aa6c",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_06_source_v02.png",
    "source_sha256": "6172462564d60088d6aa2fcedec99dbb08d94e9e7e3e926456a7bea589b85ba1",
    "source_file_exists": true
  },
  "issues": []
}
```

### 175. r3:decorative:07

```json
{
  "stable_asset_id": "r3:decorative:07",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 07 V02",
  "gameplay_purpose": "Region3 Decorative Building 07 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_07_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_07_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_07_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "3295636b2eede0cf677a2021a231edab14f4b5f9b1bb9abfb3d5907cf7b63b98",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_07_source_v02.png",
    "source_sha256": "a4de40b0f5322a18a6ca25f75f762358a093f7f8e8144e07eb3f626100a880b1",
    "source_file_exists": true
  },
  "issues": []
}
```

### 176. r3:decorative:08

```json
{
  "stable_asset_id": "r3:decorative:08",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 08 V02",
  "gameplay_purpose": "Region3 Decorative Building 08 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_08_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_08_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_08_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "347bc9efe8c43ef3700bc619a5579a7b75dcc9035ac72b5c2a7d2e1161745b39",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_08_source_v02.png",
    "source_sha256": "e4309c59f5a61b7b781adb84ff574d0fa453af3965e71b413f40893e40743b46",
    "source_file_exists": true
  },
  "issues": []
}
```

### 177. r3:decorative:09

```json
{
  "stable_asset_id": "r3:decorative:09",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 09 V02",
  "gameplay_purpose": "Region3 Decorative Building 09 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_09_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_09_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_09_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "da8970e42066a861751f7ae2b256b34383c26ba852174a2f18d9b09dabfddfa7",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_09_source_v02.png",
    "source_sha256": "08725d8a0384ea841dc5e52d075f141b6d10c36db91ca31ba81c59d988ea8e0f",
    "source_file_exists": true
  },
  "issues": []
}
```

### 178. r3:decorative:10

```json
{
  "stable_asset_id": "r3:decorative:10",
  "category": "region3_building",
  "subject": "Region3 Decorative Building 10 V02",
  "gameplay_purpose": "Region3 Decorative Building 10 V02",
  "required_views_directions": [
    "Fixed 3/4 top-down"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      160,
      160
    ],
    "cell": [
      160,
      160
    ]
  },
  "source_generation_dimensions": [
    1254,
    1254
  ],
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/REGION3_VISUAL_BIBLE.md",
    "res://docs/art/REGION3_FUNCTIONAL_BUILDING_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_10_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/world/region3/presentation/profiles/decorative_10_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_10_v02.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve current art",
  "dependencies": [],
  "priority": "P2",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "18 buildings: recorded acceptance corroborated by 54 matching raw/normalized/derivative hashes, profile wiring and reviewed renderer evidence.",
  "verified_evidence": {
    "sha256": "366bd736cdec79e0c7fabe1f20a68715414c451d94763f5ae7af2547c3d666b9",
    "dimensions": [
      160,
      160
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_10_source_v02.png",
    "source_sha256": "a766705bbdbca6cc53b7e528525742d2443ba3284e7d63b9e77c69ad6347d0f1",
    "source_file_exists": true
  },
  "issues": []
}
```

### 179. r3:decorative:11

```json
{
  "stable_asset_id": "r3:decorative:11",
  "category": "region3_environment",
  "subject": "Ambient stall, east frontage",
  "gameplay_purpose": "Ambient stall, east frontage",
  "required_views_directions": [
    "Fixed 3/4 top-down; decorative11–12 east frontage"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": 1,
  "expected_gameplay_dimensions": {
    "existing_preview": [
      128,
      128
    ],
    "required_grid": [
      32,
      32
    ],
    "final_atlas": "Not fixed; author deterministic extraction after source review"
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Genuine transparent surround on isolated subjects; ground interiors opaque as needed",
  "visual_style_authority": [
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_11_v02.png",
  "current_implementation_status": "Generated source, deterministic derivative, and provenance evidence exist; final acceptance remains pending fresh gameplay-scale showcase/renderer validation.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "No new generation required for current source; complete deterministic derivation, fresh renderer review, provenance validation, and integration acceptance.",
  "dependencies": [
    "Authored crop/tile layout and deterministic atlas packing",
    "Fresh gameplay-scale showcase and tile/crop review"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Batch2 ZIP fails zipfile parser: BadZipFile. Preview appearance and PNG filename do not establish acceptance."
  ],
  "verified_evidence": {
    "project_path": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_11_v02.png",
    "dimensions": [
      128,
      128
    ],
    "mode": "P",
    "sha256": "4ad2a6ba2ce9f012f8d8a1a1fa0ca29eccf699f8edecd4fcfd9097e144f4f86c",
    "decoded_alpha_extrema": [
      0,
      255
    ],
    "palette_transparency": true
  },
  "required_content": null,
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_11_source_v02.png",
    "source_sha256": "aabb161d761c8c5ab1cb6900f1833313ec3fecebddcfffb38d70a0aec87495ae",
    "source_identity": "new built-in imagegen result; exact source preserved and provenance entry present",
    "exact_bytes_preserved_and_verified": true,
    "source_visual_review": "passed",
    "final_acceptance": "pending fresh showcase/renderer/provenance validation",
    "renderer_review": "passed: docs/evidence/renderer/region3-decorative-11-gameplay-review.png"
  }
}
```

### 180. r3:decorative:12

```json
{
  "stable_asset_id": "r3:decorative:12",
  "category": "region3_environment",
  "subject": "Decorative home, east frontage",
  "gameplay_purpose": "Decorative home, east frontage",
  "required_views_directions": [
    "Fixed 3/4 top-down; decorative11–12 east frontage"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": 1,
  "expected_gameplay_dimensions": {
    "existing_preview": [
      128,
      128
    ],
    "required_grid": [
      32,
      32
    ],
    "final_atlas": "Not fixed; author deterministic extraction after source review"
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Genuine transparent surround on isolated subjects; ground interiors opaque as needed",
  "visual_style_authority": [
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_12_v02.png",
  "current_implementation_status": "Generated source, deterministic derivative, and provenance evidence exist; final acceptance remains pending fresh gameplay-scale showcase/renderer validation.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "No new generation required for current source; complete deterministic derivation, fresh renderer review, provenance validation, and integration acceptance.",
  "dependencies": [
    "Authored crop/tile layout and deterministic atlas packing",
    "Fresh gameplay-scale showcase and tile/crop review"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Batch2 ZIP fails zipfile parser: BadZipFile. Preview appearance and PNG filename do not establish acceptance."
  ],
  "verified_evidence": {
    "project_path": "res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_12_v02.png",
    "dimensions": [
      128,
      128
    ],
    "mode": "P",
    "sha256": "c4c8a2102aad9b2572959a14085de4b54d7b165b931f628d8f95c400634623aa",
    "decoded_alpha_extrema": [
      0,
      255
    ],
    "palette_transparency": true
  },
  "required_content": null,
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_decorative_12_source_v02.png",
    "source_sha256": "b0cab34d330b0a4b9b9bcf1eb4b638d39ac5d68efb4e0f47b213f9a0f9ed641d",
    "source_identity": "new built-in imagegen result; exact source preserved and provenance entry present",
    "exact_bytes_preserved_and_verified": true,
    "source_visual_review": "passed",
    "final_acceptance": "pending fresh showcase/renderer/provenance validation",
    "renderer_review": "passed: docs/evidence/renderer/region3-decorative-12-gameplay-review.png"
  }
}
```

### 181. region3_ground_road

```json
{
  "stable_asset_id": "region3_ground_road",
  "category": "region3_environment",
  "subject": "Ground and road material tiles",
  "gameplay_purpose": "Ground and road material tiles",
  "required_views_directions": [
    "Top-down ground tiles"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": 1,
  "expected_gameplay_dimensions": {
    "existing_preview": [
      300,
      29
    ],
    "required_grid": [
      32,
      32
    ],
    "final_atlas": "Not fixed; author deterministic extraction after source review"
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Genuine transparent surround on isolated subjects; ground interiors opaque as needed",
  "visual_style_authority": [
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/environments/region3/roads/region3_ground_road_tileset_v02.png",
  "current_implementation_status": "Accepted atlas asset: source and derivative bytes preserved; complete atlas visual review and focused Godot/resource gates passed. Full Region 3 placement/coverage remains a separate integration task.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve accepted source and derivative; only revise if a verified integration defect requires it.",
  "dependencies": [
    "Authored crop/tile layout and deterministic atlas packing",
    "Full Region 3 placement/coverage integration remains separately uncertified"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Batch2 ZIP fails zipfile parser: BadZipFile. Preview appearance and PNG filename do not establish acceptance."
  ],
  "verified_evidence": {
    "project_path": "res://assets/art/environments/region3/roads/region3_ground_road_tileset_v02.png",
    "dimensions": [
      128,
      64
    ],
    "mode": "RGBA",
    "sha256": "b03fa58ba34e3673fee1e5ba003b66bbeab3fd645e0ced9b484996ae263cbb0d",
    "alpha_extrema": [
      0,
      254
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_ground_road_source_v02.png",
    "source_sha256": "fc91162145aa62a96bfb27feb492ed633a5f8406626b932cdc1d99b0c5a179c6",
    "source_file_exists": true,
    "derivation_manifest": "res://docs/evidence/art/region3_support_v02/derivation_manifests/region3_ground_road_tileset_v02.manifest.json",
    "derivation_manifest_sha256": "ea0ae3755668719db30514a397cdb92ef1841cfd496d0e7b568803bbfcd8842c",
    "acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "renderer_capture": "res://docs/evidence/art/region3_support_v02/renderer/region3_support_catalog_complete.png",
    "renderer_capture_sha256": "edec64eddd64d6ffc525446dbd30d1f06c4abf3a93f06397ccfaa6080f38393c"
  },
  "required_content": [
    "safe-town grass/ground",
    "dirt/road surface",
    "worn road edge transition",
    "stone/plaza surface",
    "restrained fence/material strip",
    "neutral outskirts transition",
    "quiet danger-zone accent"
  ],
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_ground_road_source_v02.png",
    "source_sha256": "fc91162145aa62a96bfb27feb492ed633a5f8406626b932cdc1d99b0c5a179c6",
    "source_identity": "exact generated source preserved",
    "exact_bytes_preserved_and_verified": true,
    "derivative": "res://assets/art/environments/region3/roads/region3_ground_road_tileset_v02.png",
    "derivative_sha256": "b03fa58ba34e3673fee1e5ba003b66bbeab3fd645e0ced9b484996ae263cbb0d",
    "final_acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "acceptance_evidence": "res://docs/evidence/art/region3_support_v02/REGION3_SUPPORT_V02_ACCEPTANCE.json"
  }
}
```

### 182. region3_outskirts_support

```json
{
  "stable_asset_id": "region3_outskirts_support",
  "category": "region3_environment",
  "subject": "South-outskirts route support",
  "gameplay_purpose": "South-outskirts route support",
  "required_views_directions": [
    "Fixed 3/4 top-down; decorative11–12 east frontage"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": 1,
  "expected_gameplay_dimensions": {
    "existing_preview": [
      300,
      80
    ],
    "required_grid": [
      32,
      32
    ],
    "final_atlas": "Not fixed; author deterministic extraction after source review"
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Genuine transparent surround on isolated subjects; ground interiors opaque as needed",
  "visual_style_authority": [
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/environments/region3/outskirts/region3_outskirts_support_sheet_v02.png",
  "current_implementation_status": "Accepted atlas asset: source and derivative bytes preserved; complete atlas visual review and focused Godot/resource gates passed. Full Region 3 placement/coverage remains a separate integration task.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve accepted source and derivative; only revise if a verified integration defect requires it.",
  "dependencies": [
    "Authored crop/tile layout and deterministic atlas packing",
    "Full Region 3 placement/coverage integration remains separately uncertified"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Batch2 ZIP fails zipfile parser: BadZipFile. Preview appearance and PNG filename do not establish acceptance."
  ],
  "verified_evidence": {
    "project_path": "res://assets/art/environments/region3/outskirts/region3_outskirts_support_sheet_v02.png",
    "dimensions": [
      192,
      128
    ],
    "mode": "RGBA",
    "sha256": "dc5a6360cf3853d0ad80b8544588ed901f985d7b1c6a3b3aacc78536e0101e60",
    "alpha_extrema": [
      0,
      254
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_outskirts_support_source_v02.png",
    "source_sha256": "a15113a146175dd2a3402426ff0609adc98b50a60da7cd2fb21044398d510e23",
    "source_file_exists": true,
    "derivation_manifest": "res://docs/evidence/art/region3_support_v02/derivation_manifests/region3_outskirts_support_sheet_v02.manifest.json",
    "derivation_manifest_sha256": "aefa0288897522df9588a7a171a89a1804d012230ccca345782f46774fa3389e",
    "acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "renderer_capture": "res://docs/evidence/art/region3_support_v02/renderer/region3_support_catalog_complete.png",
    "renderer_capture_sha256": "edec64eddd64d6ffc525446dbd30d1f06c4abf3a93f06397ccfaa6080f38393c"
  },
  "required_content": [
    "sparse shrub/grass vocabulary",
    "fence/gate fragments",
    "roadside stones",
    "unlettered route markers",
    "ground-edge accents; variant counts not specified"
  ],
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_outskirts_support_source_v02.png",
    "source_sha256": "a15113a146175dd2a3402426ff0609adc98b50a60da7cd2fb21044398d510e23",
    "source_identity": "exact generated source preserved",
    "exact_bytes_preserved_and_verified": true,
    "derivative": "res://assets/art/environments/region3/outskirts/region3_outskirts_support_sheet_v02.png",
    "derivative_sha256": "dc5a6360cf3853d0ad80b8544588ed901f985d7b1c6a3b3aacc78536e0101e60",
    "final_acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "acceptance_evidence": "res://docs/evidence/art/region3_support_v02/REGION3_SUPPORT_V02_ACCEPTANCE.json"
  }
}
```

### 183. region3_risk_zone_support

```json
{
  "stable_asset_id": "region3_risk_zone_support",
  "category": "region3_environment",
  "subject": "East high-risk pocket dressing",
  "gameplay_purpose": "East high-risk pocket dressing",
  "required_views_directions": [
    "Fixed 3/4 top-down; decorative11–12 east frontage"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": 1,
  "expected_gameplay_dimensions": {
    "existing_preview": [
      300,
      102
    ],
    "required_grid": [
      32,
      32
    ],
    "final_atlas": "Not fixed; author deterministic extraction after source review"
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Genuine transparent surround on isolated subjects; ground interiors opaque as needed",
  "visual_style_authority": [
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/environments/region3/risk_zone/region3_risk_zone_support_sheet_v02.png",
  "current_implementation_status": "Accepted atlas asset: source and derivative bytes preserved; complete atlas visual review and focused Godot/resource gates passed. Full Region 3 placement/coverage remains a separate integration task.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve accepted source and derivative; only revise if a verified integration defect requires it.",
  "dependencies": [
    "Authored crop/tile layout and deterministic atlas packing",
    "Full Region 3 placement/coverage integration remains separately uncertified"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Batch2 ZIP fails zipfile parser: BadZipFile. Preview appearance and PNG filename do not establish acceptance."
  ],
  "verified_evidence": {
    "project_path": "res://assets/art/environments/region3/risk_zone/region3_risk_zone_support_sheet_v02.png",
    "dimensions": [
      192,
      128
    ],
    "mode": "RGBA",
    "sha256": "3970b501faecdd966cd82cc18273a27788a60e8fd7ef34ff68b81c98ff23b733",
    "alpha_extrema": [
      0,
      254
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_risk_zone_support_source_v02.png",
    "source_sha256": "aa015bd738d5f6396a107b8bce8a9fdfc1ec3237c8a7e5b34d8f5755ef8afe88",
    "source_file_exists": true,
    "derivation_manifest": "res://docs/evidence/art/region3_support_v02/derivation_manifests/region3_risk_zone_support_sheet_v02.manifest.json",
    "derivation_manifest_sha256": "03e5ef8b0a016d445838eec854bc5df5e032bcdc8f00867f943ee192a95d79b5",
    "acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "renderer_capture": "res://docs/evidence/art/region3_support_v02/renderer/region3_support_catalog_complete.png",
    "renderer_capture_sha256": "edec64eddd64d6ffc525446dbd30d1f06c4abf3a93f06397ccfaa6080f38393c"
  },
  "required_content": [
    "ground breaks",
    "restrained hazard-colored material",
    "unlettered warning posts",
    "broken barriers",
    "rock/terrain accents",
    "sparse vegetation; no invented hazard mechanics"
  ],
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_risk_zone_support_source_v02.png",
    "source_sha256": "aa015bd738d5f6396a107b8bce8a9fdfc1ec3237c8a7e5b34d8f5755ef8afe88",
    "source_identity": "exact generated source preserved",
    "exact_bytes_preserved_and_verified": true,
    "derivative": "res://assets/art/environments/region3/risk_zone/region3_risk_zone_support_sheet_v02.png",
    "derivative_sha256": "3970b501faecdd966cd82cc18273a27788a60e8fd7ef34ff68b81c98ff23b733",
    "final_acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "acceptance_evidence": "res://docs/evidence/art/region3_support_v02/REGION3_SUPPORT_V02_ACCEPTANCE.json"
  }
}
```

### 184. region3_ruins_modules

```json
{
  "stable_asset_id": "region3_ruins_modules",
  "category": "region3_environment",
  "subject": "North ruins broken-stone kit",
  "gameplay_purpose": "North ruins broken-stone kit",
  "required_views_directions": [
    "Fixed 3/4 top-down; decorative11–12 east frontage"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": 1,
  "expected_gameplay_dimensions": {
    "existing_preview": [
      300,
      49
    ],
    "required_grid": [
      32,
      32
    ],
    "final_atlas": "Not fixed; author deterministic extraction after source review"
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Genuine transparent surround on isolated subjects; ground interiors opaque as needed",
  "visual_style_authority": [
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/environments/region3/ruins/region3_ruins_module_sheet_v02.png",
  "current_implementation_status": "Accepted atlas asset: source and derivative bytes preserved; complete atlas visual review and focused Godot/resource gates passed. Full Region 3 placement/coverage remains a separate integration task.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve accepted source and derivative; only revise if a verified integration defect requires it.",
  "dependencies": [
    "Authored crop/tile layout and deterministic atlas packing",
    "Full Region 3 placement/coverage integration remains separately uncertified"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Batch2 ZIP fails zipfile parser: BadZipFile. Preview appearance and PNG filename do not establish acceptance."
  ],
  "verified_evidence": {
    "project_path": "res://assets/art/environments/region3/ruins/region3_ruins_module_sheet_v02.png",
    "dimensions": [
      256,
      128
    ],
    "mode": "RGBA",
    "sha256": "f38c64b0009b53c2e8c437053663d9479db2354d107961d6bca248654bbf919a",
    "alpha_extrema": [
      0,
      253
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_ruins_modules_source_v02.png",
    "source_sha256": "22c4ef9a95c2606a69673b19fa951f10adf2a88d7324b5c7d04b7ebc4a59b715",
    "source_file_exists": true,
    "derivation_manifest": "res://docs/evidence/art/region3_support_v02/derivation_manifests/region3_ruins_module_sheet_v02.manifest.json",
    "derivation_manifest_sha256": "48a34b63bd33da6b5285bc3ede4dc223e22bfb08e60cfd92bbadb9c59ba08f0c",
    "acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "renderer_capture": "res://docs/evidence/art/region3_support_v02/renderer/region3_support_catalog_complete.png",
    "renderer_capture_sha256": "edec64eddd64d6ffc525446dbd30d1f06c4abf3a93f06397ccfaa6080f38393c"
  },
  "required_content": [
    "partial low wall",
    "broken wall corner",
    "cracked pillar/column remnant",
    "collapsed arch fragment",
    "broken foundation/plinth",
    "small rubble cluster",
    "unmarked damaged stone marker"
  ],
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_ruins_modules_source_v02.png",
    "source_sha256": "22c4ef9a95c2606a69673b19fa951f10adf2a88d7324b5c7d04b7ebc4a59b715",
    "source_identity": "exact generated source preserved",
    "exact_bytes_preserved_and_verified": true,
    "derivative": "res://assets/art/environments/region3/ruins/region3_ruins_module_sheet_v02.png",
    "derivative_sha256": "f38c64b0009b53c2e8c437053663d9479db2354d107961d6bca248654bbf919a",
    "final_acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "acceptance_evidence": "res://docs/evidence/art/region3_support_v02/REGION3_SUPPORT_V02_ACCEPTANCE.json"
  }
}
```

### 185. region3_town_props

```json
{
  "stable_asset_id": "region3_town_props",
  "category": "region3_environment",
  "subject": "Town and route prop source sheet",
  "gameplay_purpose": "Town and route prop source sheet",
  "required_views_directions": [
    "Fixed 3/4 top-down; decorative11–12 east frontage"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": 1,
  "expected_gameplay_dimensions": {
    "existing_preview": [
      320,
      118
    ],
    "required_grid": [
      32,
      32
    ],
    "final_atlas": "Not fixed; author deterministic extraction after source review"
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Genuine transparent surround on isolated subjects; ground interiors opaque as needed",
  "visual_style_authority": [
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_MANIFEST.json",
    "res://docs/art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md"
  ],
  "reference_assets": [
    "res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png"
  ],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/environments/region3/props/region3_prop_sheet_v02.png",
  "current_implementation_status": "Accepted atlas asset: source and derivative bytes preserved; complete atlas visual review and focused Godot/resource gates passed. Full Region 3 placement/coverage remains a separate integration task.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE: preserve accepted source and derivative; only revise if a verified integration defect requires it.",
  "dependencies": [
    "Authored crop/tile layout and deterministic atlas packing",
    "Full Region 3 placement/coverage integration remains separately uncertified"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Batch2 ZIP fails zipfile parser: BadZipFile. Preview appearance and PNG filename do not establish acceptance."
  ],
  "verified_evidence": {
    "project_path": "res://assets/art/environments/region3/props/region3_prop_sheet_v02.png",
    "dimensions": [
      256,
      256
    ],
    "mode": "RGBA",
    "sha256": "a5e8ddd8d5094bc7a704dd9b1ba73a49dbc1fda7c66dafcdb544c1dee7fb35e8",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_town_props_source_v02.png",
    "source_sha256": "81dbc0dbc6d55550e902a1ade7eb7981de77853fbbab2e661200ef90042880e4",
    "source_file_exists": true,
    "derivation_manifest": "res://docs/evidence/art/region3_support_v02/derivation_manifests/region3_prop_sheet_v02.manifest.json",
    "derivation_manifest_sha256": "5873c9bdb8499c99e4de8ac823a0ca83bbed5e0c4c7eaa42ef247f1c9033cbb3",
    "acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "renderer_capture": "res://docs/evidence/art/region3_support_v02/renderer/region3_support_catalog_complete.png",
    "renderer_capture_sha256": "edec64eddd64d6ffc525446dbd30d1f06c4abf3a93f06397ccfaa6080f38393c"
  },
  "required_content": [
    "crates/storage stacks",
    "barrels",
    "small cart",
    "bench",
    "unlettered signpost",
    "lantern/fixture",
    "planter/shrub",
    "fence sections/posts",
    "unmarked banner",
    "road marker",
    "training dummy",
    "generic forge/merchant/apothecary support props; no new service"
  ],
  "production_progress": {
    "source": "res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/region3_town_props_source_v02.png",
    "source_sha256": "81dbc0dbc6d55550e902a1ade7eb7981de77853fbbab2e661200ef90042880e4",
    "source_identity": "exact generated source preserved",
    "exact_bytes_preserved_and_verified": true,
    "derivative": "res://assets/art/environments/region3/props/region3_prop_sheet_v02.png",
    "derivative_sha256": "a5e8ddd8d5094bc7a704dd9b1ba73a49dbc1fda7c66dafcdb544c1dee7fb35e8",
    "final_acceptance": "ACCEPTED_ATLAS_FOCUSED_VALIDATED",
    "acceptance_evidence": "res://docs/evidence/art/region3_support_v02/REGION3_SUPPORT_V02_ACCEPTANCE.json"
  }
}
```

### 186. asset:environments/tower/rooms/tower_room_boss

```json
{
  "stable_asset_id": "asset:environments/tower/rooms/tower_room_boss",
  "category": "tower_environment",
  "subject": "Tower Room Boss V01",
  "gameplay_purpose": "Tower Room Boss V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/presentation/profiles/boss_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/tower/rooms/tower_room_boss_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "04581a9d31dec69835e26d514972b990b3ecffa8b80e9c61b1001e5e7c8bc8a3",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 187. asset:environments/tower/rooms/tower_room_combat

```json
{
  "stable_asset_id": "asset:environments/tower/rooms/tower_room_combat",
  "category": "tower_environment",
  "subject": "Tower Room Combat V01",
  "gameplay_purpose": "Tower Room Combat V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/presentation/profiles/combat_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/tower/rooms/tower_room_combat_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "02ae209249219c9e0839b528d2b4c0acd51e5d3a03418d285f6b21e2e18224a7",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 188. asset:environments/tower/rooms/tower_room_elite

```json
{
  "stable_asset_id": "asset:environments/tower/rooms/tower_room_elite",
  "category": "tower_environment",
  "subject": "Tower Room Elite V01",
  "gameplay_purpose": "Tower Room Elite V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/presentation/profiles/elite_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/tower/rooms/tower_room_elite_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "7c3b645897706ed1a79ead8f83aebb579f632add633d2e1c0a6c1d3f242049af",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 189. asset:environments/tower/rooms/tower_room_objective

```json
{
  "stable_asset_id": "asset:environments/tower/rooms/tower_room_objective",
  "category": "tower_environment",
  "subject": "Tower Room Objective V01",
  "gameplay_purpose": "Tower Room Objective V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/presentation/profiles/objective_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/tower/rooms/tower_room_objective_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "633ee7ae37e00651f061dc435d5d3ad12c4c49a899871f4c0bee88e2419e73d3",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 190. asset:environments/tower/rooms/tower_room_reward

```json
{
  "stable_asset_id": "asset:environments/tower/rooms/tower_room_reward",
  "category": "tower_environment",
  "subject": "Tower Room Reward V01",
  "gameplay_purpose": "Tower Room Reward V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/presentation/profiles/reward_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/tower/rooms/tower_room_reward_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "67082972a2efd8862993f5791fba01b98622041dda5176022e77acfb207be729",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 191. asset:environments/tower/rooms/tower_room_safe

```json
{
  "stable_asset_id": "asset:environments/tower/rooms/tower_room_safe",
  "category": "tower_environment",
  "subject": "Tower Room Safe V01",
  "gameplay_purpose": "Tower Room Safe V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/presentation/profiles/safe_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/tower/rooms/tower_room_safe_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a0f25b76b8798297003c8c2814c9923c38232b7989c24f0e4a8fe27f7f661b59",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 192. asset:environments/tower/rooms/tower_room_secret

```json
{
  "stable_asset_id": "asset:environments/tower/rooms/tower_room_secret",
  "category": "tower_environment",
  "subject": "Tower Room Secret V01",
  "gameplay_purpose": "Tower Room Secret V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/presentation/profiles/secret_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/tower/rooms/tower_room_secret_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "12cbe48112da3a9318d20e3a5fd6ab96241402c033b4321d89a4ad9260a1ab07",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 193. asset:environments/tower/rooms/tower_room_vendor

```json
{
  "stable_asset_id": "asset:environments/tower/rooms/tower_room_vendor",
  "category": "tower_environment",
  "subject": "Tower Room Vendor V01",
  "gameplay_purpose": "Tower Room Vendor V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      96,
      96
    ],
    "cell": [
      96,
      96
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/world/tower/presentation/profiles/vendor_visual_profile.tres"
  ],
  "current_existing_asset": "res://assets/art/environments/tower/rooms/tower_room_vendor_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "b97bdfa83fe86fb27aae30e56c26e58ec34ea265f581fd8a580ae8638df5afb8",
    "dimensions": [
      96,
      96
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 194. asset:environments/tower/tiles/tower_common_tileset

```json
{
  "stable_asset_id": "asset:environments/tower/tiles/tower_common_tileset",
  "category": "tower_environment",
  "subject": "Tower Common Tileset V01",
  "gameplay_purpose": "Tower Common Tileset V01",
  "required_views_directions": [
    "Top-down 3/4 world view"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      128,
      128
    ],
    "cell": [
      128,
      128
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Tile coverage/alpha per module",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/TOWER_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [],
  "current_existing_asset": "res://assets/art/environments/tower/tiles/tower_common_tileset_v01.png",
  "current_implementation_status": "Present on disk; no direct src texture reference found",
  "classification": "TEXTURE_TILE_REQUIRED",
  "generation_revision_requirement": "Generate reusable dark stone/metal kit or room-category visual replacement through existing profiles.",
  "dependencies": [
    "Reusable module geometry/TileSet mapping",
    "Floor1–10 room generation and telegraph readability"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "b4851c0ba3a7b674c730fcdd756c8e21f256094b651a3958f6130dc525193129",
    "dimensions": [
      128,
      128
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      255,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Current procedural V01 assets are provisional; atlas dimensions are measured current dimensions, not a complete final atlas specification."
  ]
}
```

### 195. asset:ui/classes/class_mage_icon

```json
{
  "stable_asset_id": "asset:ui/classes/class_mage_icon",
  "category": "ui",
  "subject": "Class Mage Icon V01",
  "gameplay_purpose": "Class Mage Icon V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/class_mage.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/classes/class_mage_icon_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "d20392819069848194fbd0b60e3040a73460469bbfc454d1cbd327dd92974eb3",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "d20392819069848194fbd0b60e3040a73460469bbfc454d1cbd327dd92974eb3",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 196. asset:ui/classes/class_melee_icon

```json
{
  "stable_asset_id": "asset:ui/classes/class_melee_icon",
  "category": "ui",
  "subject": "Class Melee Icon V01",
  "gameplay_purpose": "Class Melee Icon V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/class_melee.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/classes/class_melee_icon_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "8ab161b8cba3ca73852ccc5794750b92e6589047f39806ad901d19a84e4dce56",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "8ab161b8cba3ca73852ccc5794750b92e6589047f39806ad901d19a84e4dce56",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 197. asset:ui/classes/class_ranged_icon

```json
{
  "stable_asset_id": "asset:ui/classes/class_ranged_icon",
  "category": "ui",
  "subject": "Class Ranged Icon V01",
  "gameplay_purpose": "Class Ranged Icon V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/class_ranged.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/classes/class_ranged_icon_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "a282e762fdcb0191395a8823c217abdd9de5990fa92dd6278c942485b9f983e1",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "a282e762fdcb0191395a8823c217abdd9de5990fa92dd6278c942485b9f983e1",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 198. asset:ui/markers/map_marker_sheet

```json
{
  "stable_asset_id": "asset:ui/markers/map_marker_sheet",
  "category": "ui",
  "subject": "Map Marker Sheet V01",
  "gameplay_purpose": "Map Marker Sheet V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": null,
    "current": 4
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      128,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/map_marker_sheet.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/markers/map_marker_sheet_v01.png",
  "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "7c3c5f62fc5bcd370ea4fe1d0515e177908236396f1131062fa0842437e1a859",
    "dimensions": [
      128,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": []
}
```

### 199. asset:ui/markers/tower_sigil_icon

```json
{
  "stable_asset_id": "asset:ui/markers/tower_sigil_icon",
  "category": "ui",
  "subject": "Tower Sigil Icon V01",
  "gameplay_purpose": "Tower Sigil Icon V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/tower_sigil.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/markers/tower_sigil_icon_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "78d8c1059dbd772ce914a7945cb0b7f2ea2fe16c4ac773b4a5882774d494e4bf",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "78d8c1059dbd772ce914a7945cb0b7f2ea2fe16c4ac773b4a5882774d494e4bf",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 200. asset:ui/quests/quest_family_annihilation

```json
{
  "stable_asset_id": "asset:ui/quests/quest_family_annihilation",
  "category": "ui",
  "subject": "Quest Family Annihilation V01",
  "gameplay_purpose": "Quest Family Annihilation V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/quest_family_annihilation.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/quests/quest_family_annihilation_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "8edd30b5fe2002f336f910c7266f7777c9c5d371b853b241088b30e0c2c18018",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "8edd30b5fe2002f336f910c7266f7777c9c5d371b853b241088b30e0c2c18018",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 201. asset:ui/quests/quest_family_escort

```json
{
  "stable_asset_id": "asset:ui/quests/quest_family_escort",
  "category": "ui",
  "subject": "Quest Family Escort V01",
  "gameplay_purpose": "Quest Family Escort V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/quest_family_escort.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/quests/quest_family_escort_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "0579bc3f0a4b87e0961b7e5ac86858dfe6480c565bbe0d98da3a981d7b18c4f8",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "0579bc3f0a4b87e0961b7e5ac86858dfe6480c565bbe0d98da3a981d7b18c4f8",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 202. asset:ui/quests/quest_family_tower_defense

```json
{
  "stable_asset_id": "asset:ui/quests/quest_family_tower_defense",
  "category": "ui",
  "subject": "Quest Family Tower Defense V01",
  "gameplay_purpose": "Quest Family Tower Defense V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/quest_family_tower_defense.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/quests/quest_family_tower_defense_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "d6fcbbefd1e77989edde7e1b88c53e6685900fb7a84acd8efd485bb9a98fca5f",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "d6fcbbefd1e77989edde7e1b88c53e6685900fb7a84acd8efd485bb9a98fca5f",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 203. asset:ui/skills/skill_aegis_ward

```json
{
  "stable_asset_id": "asset:ui/skills/skill_aegis_ward",
  "category": "ui",
  "subject": "Skill Aegis Ward V01",
  "gameplay_purpose": "Skill Aegis Ward V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_aegis_ward.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_aegis_ward_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_aegis_ward_v02",
    "class": "mage",
    "skill_id": "aegis_ward",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_mage_skills_source_v02.png",
    "source_sha256": "08d734d828d7830e3a2ee213be860ff3b05b0262ef72373236d354ee3c72ef48",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 2,
    "cell_rect": [
      1024,
      0,
      1536,
      512
    ],
    "alpha_bbox_in_cell": [
      93,
      91,
      403,
      473
    ],
    "alpha_threshold": 8,
    "padding": 38,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_aegis_ward_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "06a2d8e6ade57a0848fa745c64f5061b539923304614e60159e1077935b37e04",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "4854d6e933665bf556853fbb2d08c1c0af1f13a5e9d5948b26228ab9eac7d63b",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 204. asset:ui/skills/skill_arc_cleave

```json
{
  "stable_asset_id": "asset:ui/skills/skill_arc_cleave",
  "category": "ui",
  "subject": "Skill Arc Cleave V01",
  "gameplay_purpose": "Skill Arc Cleave V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_arc_cleave.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_arc_cleave_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_arc_cleave_v02",
    "class": "melee",
    "skill_id": "arc_cleave",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_melee_skills_source_v02.png",
    "source_sha256": "8968ffc7e582a396feed57625d556dbc64f12a532757a3ed3ec9cf66b135cb34",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 0,
    "cell_rect": [
      0,
      0,
      512,
      512
    ],
    "alpha_bbox_in_cell": [
      56,
      69,
      456,
      501
    ],
    "alpha_threshold": 8,
    "padding": 43,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_arc_cleave_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "08fa5fd7bf07ee0c49fcbbccf3a874d51f33af32b68d96a5990a72ad01bbf29e",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "ede831262ca34db6095547fa49009b6748c5e62e5bf6b4d9d935b8727145fbcc",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 205. asset:ui/skills/skill_arcane_lance

```json
{
  "stable_asset_id": "asset:ui/skills/skill_arcane_lance",
  "category": "ui",
  "subject": "Skill Arcane Lance V01",
  "gameplay_purpose": "Skill Arcane Lance V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_arcane_lance.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_arcane_lance_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_arcane_lance_v02",
    "class": "mage",
    "skill_id": "arcane_lance",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_mage_skills_source_v02.png",
    "source_sha256": "08d734d828d7830e3a2ee213be860ff3b05b0262ef72373236d354ee3c72ef48",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 0,
    "cell_rect": [
      0,
      0,
      512,
      512
    ],
    "alpha_bbox_in_cell": [
      109,
      202,
      501,
      426
    ],
    "alpha_threshold": 8,
    "padding": 39,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_arcane_lance_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "50363626864dc2ef047a1a540ac853edb8f9b2091b75cd328787d4e715568095",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "1af8a2df2cadb355060740b7e8493c6a24d7cd38b4a4aa1fe27cab47e1b3c657",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 206. asset:ui/skills/skill_backstep_shot

```json
{
  "stable_asset_id": "asset:ui/skills/skill_backstep_shot",
  "category": "ui",
  "subject": "Skill Backstep Shot V01",
  "gameplay_purpose": "Skill Backstep Shot V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_backstep_shot.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_backstep_shot_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_backstep_shot_v02",
    "class": "ranged",
    "skill_id": "backstep_shot",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_ranged_skills_source_v02.png",
    "source_sha256": "683bdd6a113d9f052b10b4dd285f0e6ec3a4d68bb5f20fc4002a91aa22890467",
    "source_dimensions": [
      1254,
      1254
    ],
    "cell_index": 2,
    "cell_rect": [
      836,
      0,
      1254,
      627
    ],
    "alpha_bbox_in_cell": [
      0,
      207,
      406,
      596
    ],
    "alpha_threshold": 8,
    "padding": 41,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_backstep_shot_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "fb6bd0d4ed46176a8bcac8bf21781dc2585258a4a343746eef0b4589aa4b9184",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "b055d35373d862e4c26df047bfc6b75d844f418958276b80c94081e871c51664",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 207. asset:ui/skills/skill_breaker

```json
{
  "stable_asset_id": "asset:ui/skills/skill_breaker",
  "category": "ui",
  "subject": "Skill Breaker V01",
  "gameplay_purpose": "Skill Breaker V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_breaker.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_breaker_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_breaker_v02",
    "class": "melee",
    "skill_id": "breaker",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_melee_skills_source_v02.png",
    "source_sha256": "8968ffc7e582a396feed57625d556dbc64f12a532757a3ed3ec9cf66b135cb34",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 2,
    "cell_rect": [
      1024,
      0,
      1536,
      512
    ],
    "alpha_bbox_in_cell": [
      76,
      61,
      457,
      483
    ],
    "alpha_threshold": 8,
    "padding": 42,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_breaker_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "b22ee46948fef78b41b3b8c143c32cedd27a7388fdda4a5d586bd87e307a8c2c",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "2c6b1d5b1f2b351149672ff989a48d344fda3e0fb2079ec47d436e1cdbbf7e97",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 208. asset:ui/skills/skill_delayed_pulse

```json
{
  "stable_asset_id": "asset:ui/skills/skill_delayed_pulse",
  "category": "ui",
  "subject": "Skill Delayed Pulse V01",
  "gameplay_purpose": "Skill Delayed Pulse V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_delayed_pulse.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_delayed_pulse_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_delayed_pulse_v02",
    "class": "mage",
    "skill_id": "delayed_pulse",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_mage_skills_source_v02.png",
    "source_sha256": "08d734d828d7830e3a2ee213be860ff3b05b0262ef72373236d354ee3c72ef48",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 1,
    "cell_rect": [
      512,
      0,
      1024,
      512
    ],
    "alpha_bbox_in_cell": [
      81,
      88,
      431,
      461
    ],
    "alpha_threshold": 8,
    "padding": 37,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_delayed_pulse_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "29bc45d233cdd6d6f92708ad0a6d85754e2b06d870d8563345fe0760a885a8a6",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "a349c0fa1e992b2fa8dee311616098e468ba863b28a36f077c3b3a323f658383",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 209. asset:ui/skills/skill_driving_thrust

```json
{
  "stable_asset_id": "asset:ui/skills/skill_driving_thrust",
  "category": "ui",
  "subject": "Skill Driving Thrust V01",
  "gameplay_purpose": "Skill Driving Thrust V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_driving_thrust.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_driving_thrust_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_driving_thrust_v02",
    "class": "melee",
    "skill_id": "driving_thrust",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_melee_skills_source_v02.png",
    "source_sha256": "8968ffc7e582a396feed57625d556dbc64f12a532757a3ed3ec9cf66b135cb34",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 1,
    "cell_rect": [
      512,
      0,
      1024,
      512
    ],
    "alpha_bbox_in_cell": [
      12,
      216,
      484,
      375
    ],
    "alpha_threshold": 8,
    "padding": 47,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_driving_thrust_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "521dfc7322cbdf9b2ab14c405d40eaa62b6e12b521223da18bbf7169905b3e77",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "2d60d384807be2737955d97dc1d4ab3e9a27eeac24bc6a5c0a391533d5e9df98",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 210. asset:ui/skills/skill_efficient_footwork

```json
{
  "stable_asset_id": "asset:ui/skills/skill_efficient_footwork",
  "category": "ui",
  "subject": "Skill Efficient Footwork V01",
  "gameplay_purpose": "Skill Efficient Footwork V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_efficient_footwork.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_efficient_footwork_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_efficient_footwork_v02",
    "class": "melee",
    "skill_id": "efficient_footwork",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_melee_skills_source_v02.png",
    "source_sha256": "8968ffc7e582a396feed57625d556dbc64f12a532757a3ed3ec9cf66b135cb34",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 3,
    "cell_rect": [
      0,
      512,
      512,
      1024
    ],
    "alpha_bbox_in_cell": [
      69,
      38,
      450,
      401
    ],
    "alpha_threshold": 8,
    "padding": 38,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_efficient_footwork_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "09de44d8cfafd21f34ebf6fd56333e43f8556b9b9bf0ae7d84c911293cb0f1ef",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "2c6b1d5b1f2b351149672ff989a48d344fda3e0fb2079ec47d436e1cdbbf7e97",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 211. asset:ui/skills/skill_expose

```json
{
  "stable_asset_id": "asset:ui/skills/skill_expose",
  "category": "ui",
  "subject": "Skill Expose V01",
  "gameplay_purpose": "Skill Expose V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_expose.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_expose_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_expose_v02",
    "class": "ranged",
    "skill_id": "expose",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_ranged_skills_source_v02.png",
    "source_sha256": "683bdd6a113d9f052b10b4dd285f0e6ec3a4d68bb5f20fc4002a91aa22890467",
    "source_dimensions": [
      1254,
      1254
    ],
    "cell_index": 5,
    "cell_rect": [
      836,
      627,
      1254,
      1254
    ],
    "alpha_bbox_in_cell": [
      28,
      86,
      395,
      423
    ],
    "alpha_threshold": 8,
    "padding": 37,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_expose_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "05242d3ebdb4b55723110b333562737f88f25c347e378adf4d26599851fd9316",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "4ef2693fcf3f1f1bd7d7542af43f3b1c686c73e7d200a10ac94e8b8fce1710e4",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 212. asset:ui/skills/skill_fan_shot

```json
{
  "stable_asset_id": "asset:ui/skills/skill_fan_shot",
  "category": "ui",
  "subject": "Skill Fan Shot V01",
  "gameplay_purpose": "Skill Fan Shot V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_fan_shot.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_fan_shot_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_fan_shot_v02",
    "class": "ranged",
    "skill_id": "fan_shot",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_ranged_skills_source_v02.png",
    "source_sha256": "683bdd6a113d9f052b10b4dd285f0e6ec3a4d68bb5f20fc4002a91aa22890467",
    "source_dimensions": [
      1254,
      1254
    ],
    "cell_index": 1,
    "cell_rect": [
      418,
      0,
      836,
      627
    ],
    "alpha_bbox_in_cell": [
      43,
      241,
      391,
      560
    ],
    "alpha_threshold": 8,
    "padding": 35,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_fan_shot_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "e5625f435aefe1897fb8392af8565d49fe077a9332571946979fccb4c17f93c1",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "2b4779015ca49d5c0c4ec77ec4960bcc352e561e70a732a549a0ea695f0799fd",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 213. asset:ui/skills/skill_fleet_recovery

```json
{
  "stable_asset_id": "asset:ui/skills/skill_fleet_recovery",
  "category": "ui",
  "subject": "Skill Fleet Recovery V01",
  "gameplay_purpose": "Skill Fleet Recovery V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_fleet_recovery.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_fleet_recovery_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_fleet_recovery_v02",
    "class": "ranged",
    "skill_id": "fleet_recovery",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_ranged_skills_source_v02.png",
    "source_sha256": "683bdd6a113d9f052b10b4dd285f0e6ec3a4d68bb5f20fc4002a91aa22890467",
    "source_dimensions": [
      1254,
      1254
    ],
    "cell_index": 4,
    "cell_rect": [
      418,
      627,
      836,
      1254
    ],
    "alpha_bbox_in_cell": [
      32,
      56,
      389,
      428
    ],
    "alpha_threshold": 8,
    "padding": 37,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_fleet_recovery_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "6ae6000dfea8368e035a9d7c90d1ad9ce8b8337afb95f4735cdf7099079c1b6d",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "4ef2693fcf3f1f1bd7d7542af43f3b1c686c73e7d200a10ac94e8b8fce1710e4",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 214. asset:ui/skills/skill_flow_recovery

```json
{
  "stable_asset_id": "asset:ui/skills/skill_flow_recovery",
  "category": "ui",
  "subject": "Skill Flow Recovery V01",
  "gameplay_purpose": "Skill Flow Recovery V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_flow_recovery.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_flow_recovery_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_flow_recovery_v02",
    "class": "mage",
    "skill_id": "flow_recovery",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_mage_skills_source_v02.png",
    "source_sha256": "08d734d828d7830e3a2ee213be860ff3b05b0262ef72373236d354ee3c72ef48",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 4,
    "cell_rect": [
      512,
      512,
      1024,
      1024
    ],
    "alpha_bbox_in_cell": [
      74,
      65,
      428,
      437
    ],
    "alpha_threshold": 8,
    "padding": 37,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_flow_recovery_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "d46b202faec4b078e6195fdfb6771f8b1e5ac407042a89237478db573ae7ca3e",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "7bc4120f0f63f5c731b3cb4f475e64b07c85c84fd423f7ccb9d7daeaf77f7f28",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 215. asset:ui/skills/skill_longshot

```json
{
  "stable_asset_id": "asset:ui/skills/skill_longshot",
  "category": "ui",
  "subject": "Skill Longshot V01",
  "gameplay_purpose": "Skill Longshot V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_longshot.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_longshot_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_longshot_v02",
    "class": "ranged",
    "skill_id": "longshot",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_ranged_skills_source_v02.png",
    "source_sha256": "683bdd6a113d9f052b10b4dd285f0e6ec3a4d68bb5f20fc4002a91aa22890467",
    "source_dimensions": [
      1254,
      1254
    ],
    "cell_index": 3,
    "cell_rect": [
      0,
      627,
      418,
      1254
    ],
    "alpha_bbox_in_cell": [
      44,
      55,
      379,
      421
    ],
    "alpha_threshold": 8,
    "padding": 37,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_longshot_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "2543cb227f8547678f4c6efa93371706f97038e8d7ca908cae6fc728baa0a5f5",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "4ef2693fcf3f1f1bd7d7542af43f3b1c686c73e7d200a10ac94e8b8fce1710e4",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 216. asset:ui/skills/skill_mana_weave

```json
{
  "stable_asset_id": "asset:ui/skills/skill_mana_weave",
  "category": "ui",
  "subject": "Skill Mana Weave V01",
  "gameplay_purpose": "Skill Mana Weave V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_mana_weave.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_mana_weave_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_mana_weave_v02",
    "class": "mage",
    "skill_id": "mana_weave",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_mage_skills_source_v02.png",
    "source_sha256": "08d734d828d7830e3a2ee213be860ff3b05b0262ef72373236d354ee3c72ef48",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 3,
    "cell_rect": [
      0,
      512,
      512,
      1024
    ],
    "alpha_bbox_in_cell": [
      118,
      84,
      460,
      418
    ],
    "alpha_threshold": 8,
    "padding": 34,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_mana_weave_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "d1d2f7fe6a116b051e28a87daac9563b61fdc01c8510f2fe976aeaf64696e6da",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "7bc4120f0f63f5c731b3cb4f475e64b07c85c84fd423f7ccb9d7daeaf77f7f28",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 217. asset:ui/skills/skill_parry_recovery

```json
{
  "stable_asset_id": "asset:ui/skills/skill_parry_recovery",
  "category": "ui",
  "subject": "Skill Parry Recovery V01",
  "gameplay_purpose": "Skill Parry Recovery V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_parry_recovery.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_parry_recovery_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_parry_recovery_v02",
    "class": "melee",
    "skill_id": "parry_recovery",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_melee_skills_source_v02.png",
    "source_sha256": "8968ffc7e582a396feed57625d556dbc64f12a532757a3ed3ec9cf66b135cb34",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 4,
    "cell_rect": [
      512,
      512,
      1024,
      1024
    ],
    "alpha_bbox_in_cell": [
      94,
      26,
      418,
      415
    ],
    "alpha_threshold": 8,
    "padding": 39,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_parry_recovery_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "f41cc6a044ad3cba2b246c629c4214f94b7406666db6442670cbe0483ee03e05",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "2c6b1d5b1f2b351149672ff989a48d344fda3e0fb2079ec47d436e1cdbbf7e97",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 218. asset:ui/skills/skill_piercing_shot

```json
{
  "stable_asset_id": "asset:ui/skills/skill_piercing_shot",
  "category": "ui",
  "subject": "Skill Piercing Shot V01",
  "gameplay_purpose": "Skill Piercing Shot V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_piercing_shot.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_piercing_shot_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_piercing_shot_v02",
    "class": "ranged",
    "skill_id": "piercing_shot",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_ranged_skills_source_v02.png",
    "source_sha256": "683bdd6a113d9f052b10b4dd285f0e6ec3a4d68bb5f20fc4002a91aa22890467",
    "source_dimensions": [
      1254,
      1254
    ],
    "cell_index": 0,
    "cell_rect": [
      0,
      0,
      418,
      627
    ],
    "alpha_bbox_in_cell": [
      28,
      250,
      404,
      559
    ],
    "alpha_threshold": 8,
    "padding": 38,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_piercing_shot_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "a7dac80364a86c124806d8a5a1b90ca815b1a27f5220c3d7da5677bc2c61b396",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "f96f7bafa1628038bd4c74ba2e3b464ec7449e271c1fda7dc1cca0d699c7eee1",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 219. asset:ui/skills/skill_riposte

```json
{
  "stable_asset_id": "asset:ui/skills/skill_riposte",
  "category": "ui",
  "subject": "Skill Riposte V01",
  "gameplay_purpose": "Skill Riposte V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_riposte.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_riposte_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_riposte_v02",
    "class": "melee",
    "skill_id": "riposte",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_melee_skills_source_v02.png",
    "source_sha256": "8968ffc7e582a396feed57625d556dbc64f12a532757a3ed3ec9cf66b135cb34",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 5,
    "cell_rect": [
      1024,
      512,
      1536,
      1024
    ],
    "alpha_bbox_in_cell": [
      95,
      16,
      413,
      433
    ],
    "alpha_threshold": 8,
    "padding": 42,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_riposte_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "ef188a4af055bfaaab325d9f5d58fbb01c8df4da19381b739983e5ad57070934",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "b80e88fbbb5d579da83422647d72136c57d8be279784ba79abcc6a51d1f4e2da",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 220. asset:ui/skills/skill_stable_casting

```json
{
  "stable_asset_id": "asset:ui/skills/skill_stable_casting",
  "category": "ui",
  "subject": "Skill Stable Casting V01",
  "gameplay_purpose": "Skill Stable Casting V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/skill_stable_casting.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/skills/skill_stable_casting_v02.png",
  "current_implementation_status": "Distinct generated-source32x32 V02 icon wired into existing UiIconProfile. Complete28-profile renderer catalog reviewed; focused skill/catalog/resource tests passed.",
  "classification": "ACCEPTED_DO_NOT_REGENERATE",
  "generation_revision_requirement": "NONE for this icon artwork: preserve exact generated source and V02 derivative. Check any future UI layout/accessibility change separately.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Source/derivative/icon-profile artwork slice; not certification of every gameplay screen.",
  "verified_evidence": {
    "asset_id": "ui_skill_stable_casting_v02",
    "class": "mage",
    "skill_id": "stable_casting",
    "source": "res://assets/art/generated_sources/imagegen/ui/ui_mage_skills_source_v02.png",
    "source_sha256": "08d734d828d7830e3a2ee213be860ff3b05b0262ef72373236d354ee3c72ef48",
    "source_dimensions": [
      1536,
      1024
    ],
    "cell_index": 5,
    "cell_rect": [
      1024,
      512,
      1536,
      1024
    ],
    "alpha_bbox_in_cell": [
      67,
      41,
      427,
      426
    ],
    "alpha_threshold": 8,
    "padding": 38,
    "scale_filter": "nearest",
    "output": "res://assets/art/ui/skills/skill_stable_casting_v02.png",
    "output_dimensions": [
      32,
      32
    ],
    "output_sha256": "2246f58899fe71161dde5443f0e7b86814092e27c56c0a8a2b85c1f350da8807",
    "mapping_authority": "src/combat/skills/skill_catalog.gd"
  },
  "issues": [],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "7bc4120f0f63f5c731b3cb4f475e64b07c85c84fd423f7ccb9d7daeaf77f7f28",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 221. asset:ui/status/status_burn

```json
{
  "stable_asset_id": "asset:ui/status/status_burn",
  "category": "ui",
  "subject": "Status Burn V01",
  "gameplay_purpose": "Status Burn V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/status_burn.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/status/status_burn_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "7cc37d2212eb6ad25e8e12cb08ef5afa6b26e1e4df6e5cf8dc44117f2f8f7477",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "7cc37d2212eb6ad25e8e12cb08ef5afa6b26e1e4df6e5cf8dc44117f2f8f7477",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 222. asset:ui/status/status_slow

```json
{
  "stable_asset_id": "asset:ui/status/status_slow",
  "category": "ui",
  "subject": "Status Slow V01",
  "gameplay_purpose": "Status Slow V01",
  "required_views_directions": [
    "Flat UI icon"
  ],
  "required_animation_states": [
    "static"
  ],
  "required_frame_counts": {
    "specified": 1,
    "current": 1
  },
  "expected_gameplay_dimensions": {
    "sheet": [
      32,
      32
    ],
    "cell": [
      32,
      32
    ]
  },
  "source_generation_dimensions": null,
  "transparency_requirement": "Transparent surrounding pixels",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md",
    "res://docs/art/UI_VISUAL_BIBLE.md"
  ],
  "reference_assets": [
    "res://assets/art/generated_sources/imagegen/ui/ui_core_icons_source_v02.png"
  ],
  "target_godot_resource_scene": [
    "res://src/ui/presentation/profiles/status_slow.tres"
  ],
  "current_existing_asset": "res://assets/art/ui/status/status_slow_v01.png",
  "current_implementation_status": "Generated core icon artwork is already present in live PNGs and visible in the catalog. The attempted core9 provenance records incorrectly identify old procedural backup bytes as their source; all nine backup/output hashes differ.",
  "classification": "EXISTS_NEEDS_REVISION",
  "generation_revision_requirement": "Recover/document the actual crop and derivation from ui_core_icons_source_v02.png, or deterministically rederive from that preserved source. Do not generate another source image.",
  "dependencies": [
    "Existing UiIconProfile/catalog ownership and actual consuming UI"
  ],
  "priority": "P1",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "acceptance_scope": "Existing source/art preservation; this does not claim representative final combat or all-screen acceptance.",
  "verified_evidence": {
    "sha256": "903a1cf89887ddf9569588b7484748296e5e299d17e2112d24ab27d3c770ea66",
    "dimensions": [
      32,
      32
    ],
    "mode": "RGBA",
    "alpha_extrema": [
      0,
      255
    ],
    "source": "project-local procedural pixel authoring",
    "source_sha256": null,
    "source_file_exists": false
  },
  "issues": [
    "Core9 source-chain metadata incomplete. Existing v01 suffix does not mean live pixels are the original procedural V01."
  ],
  "prior_audit_snapshot": {
    "current_implementation_status": "Texture reference exists in listed source resource(s); state reachability separately audited",
    "classification": "PLACEHOLDER",
    "generation_revision_requirement": "Generate coherent crisp replacement icon batch, preserving exact semantic IDs.",
    "issues": [],
    "verified_evidence": {
      "sha256": "903a1cf89887ddf9569588b7484748296e5e299d17e2112d24ab27d3c770ea66",
      "dimensions": [
        32,
        32
      ],
      "mode": "RGBA",
      "alpha_extrema": [
        0,
        255
      ],
      "source": "project-local procedural pixel authoring",
      "source_sha256": null,
      "source_file_exists": false
    }
  }
}
```

### 223. application.icon

```json
{
  "stable_asset_id": "application.icon",
  "category": "ui_application_icon",
  "subject": "Application icon",
  "gameplay_purpose": "Application icon",
  "required_views_directions": [
    "Flat icon"
  ],
  "required_animation_states": [],
  "required_frame_counts": 1,
  "expected_gameplay_dimensions": [
    128,
    128
  ],
  "source_generation_dimensions": null,
  "transparency_requirement": "Not authored; resolve in asset brief",
  "visual_style_authority": [
    "res://docs/art/ART_INTEGRATION_RULES.md"
  ],
  "reference_assets": [],
  "target_godot_resource_scene": [
    "res://project.godot"
  ],
  "current_existing_asset": "res://icon.svg",
  "current_implementation_status": "Project config references default Godot SVG icon; no Nice Journey branding authority located.",
  "classification": "PLACEHOLDER",
  "generation_revision_requirement": "Retain until a concrete product-icon brief is authored; no release/export changes authorized.",
  "dependencies": [],
  "priority": "P3",
  "acceptance_criteria": [
    "Inspect exact source visually against subject/style reference",
    "Preserve untouched source and SHA-256",
    "Document deterministic crop/alpha cleanup/nearest-neighbor derivation and derivative hashes",
    "Use Inspector-owned resources; Sprite2D + external AnimationLibrary when animated",
    "Review actual Godot renderer at gameplay scale, baseline/pivot and nearest filtering",
    "Run focused resource/presentation/provenance validation; broad Godot gate after meaningful integration"
  ],
  "issues": [
    "Not a gameplay art blocker; brand identity unspecified."
  ],
  "verified_evidence": {},
  "required_content": null
}
```

## 17. Files to give the next agent

- This Markdown guide: complete procedures, existing-image source index, exact latest prompts and all223 asset records.
- `Nice_Journey_Asset_Handoff_Manifest.json`: same dated inventory for programmatic filtering and updates.
- Access to `D:\nicejourney` or the exact source/evidence files referenced in the chosen records. The guide does not embed or replace the original PNG bytes.

The next agent should not generate anything just to read this handoff. Start by choosing a current incomplete record and checking whether its next step is metadata, derivation or integration. Many current gaps require no new image source.
