# Nice Journey — Image Generation Failure Recovery & Asset Acceptance Protocol

Updated: 2026-09-15
Status: ACTIVE HANDOFF / REQUIRED PROCESS

## 1. Purpose

This document exists because image-generation attempts for Nice Journey have occasionally returned the **wrong subject entirely**—most notably project-progress dashboards/status panels when the request was for isolated game art such as a Skirmisher sprite sheet or Region 3 buildings.

That failure mode must never be handled by repeatedly generating images and hoping one happens to work. The project must use a controlled **generate → inspect → accept/reject → transfer → derive → integrate → validate** pipeline.

A generated file is not a production asset merely because an image exists.

---

## 2. Known failure mode

Observed bad result pattern:

- requested: isolated game-art sprite/reference sheet;
- received: project-progress dashboard, validation report, integration status panel, developer infographic, editor-like composition, or other unrelated status imagery.

Examples of content that are automatically wrong for production asset requests:

- progress dashboards;
- checklists/checkmarks;
- test counts;
- file paths;
- "integration progress" text;
- project status labels;
- Godot editor chrome;
- code screenshots;
- documentation layouts;
- roadmap/next-step panels;
- unrelated character/environment compositions.

**Rule:** these outputs are rejected immediately. Do not crop them, recolor them, trace them, or treat them as an acceptable source asset.

---

## 3. Likely cause and practical mitigation

The image-generation system may infer intent from the surrounding conversation. A long coding/integration conversation can contaminate the generation context and bias it toward status/dashboard imagery even when the immediate request says "sprite sheet" or "building sheet."

Therefore the asset-generation process must actively minimize contextual contamination.

### Required mitigation

1. Before generating, write one short subject-only generation instruction.
2. Do **not** include project progress, validation counts, file paths, wave numbers, implementation status, or recent coding results in that generation instruction.
3. Describe only the visible art that should appear.
4. Explicitly exclude dashboards/editor/UI/status content.
5. After generation, visually inspect the entire image before any transfer or project mutation.
6. If the output is unrelated, reject it immediately.
7. Make at most **one controlled retry in the same conversation context**.
8. If the second attempt is still unrelated, **stop generating in that context**. Move the generation task to a fresh/clean image-generation conversation or otherwise isolated generation context containing only the asset brief and necessary visual references.

Do not burn attempts by repeatedly changing tiny prompt wording inside a contaminated conversation.

---

## 4. Clean-context rule

When the current conversation contains a large amount of:

- coding discussion;
- wave progress;
- QA summaries;
- dashboards/screenshots;
- file listings;
- performance numbers;
- implementation handoffs;

then a new production-art batch should preferably be generated in a **clean image-focused context**.

The clean context should contain only:

- the Nice Journey art-direction requirements relevant to that asset;
- an accepted visual reference if one is needed;
- the exact asset subject;
- pose/view/grid requirements;
- palette/style constraints;
- background/transparency requirements;
- explicit negative constraints.

It should **not** include project progress or engineering status unless the image itself is supposed to depict that, which production game assets are not.

---

## 5. Generation brief template

Use a compact brief like this:

```text
Create only a production game-art sprite/reference sheet.

Subject: [ASSET NAME / ROLE]
Game: Nice Journey
Style: 16-bit-inspired pixel art, crisp nearest-neighbor-style pixel edges.
View: [side / top-down 3/4 / etc.]
Gameplay target: readable at [32x32 / 48x48 / 96x96] scale.

Required content:
- [POSE / OBJECT 1]
- [POSE / OBJECT 2]
- [...]

Consistency:
- same character/object proportions across cells;
- same palette/material language;
- isolated subjects;
- no accidental cropping;
- no text crossing the artwork.

Background: plain neutral background or transparent, as specified.

DO NOT CREATE:
- progress dashboard;
- project-status panel;
- validation report;
- UI mockup;
- Godot/editor screenshot;
- file paths;
- test counts;
- checklists;
- roadmap;
- unrelated scenes.
```

Do not append coding progress after this prompt.

---

## 6. Example — remaining enemy archetype

### Skirmisher

```text
Create only a game-art sprite reference sheet.

Subject: Nice Journey — Skirmisher enemy.
16-bit-inspired pixel art, side-view action-RPG enemy, agile lightly armored melee fighter with a short blade and compact readable silhouette.

One plain neutral-background sheet with six separated gameplay poses in one horizontal row:
1. idle
2. move
3. attack windup
4. attack release
5. hit reaction
6. death

Keep identical character scale, palette and equipment across all six cells. Crisp pixel edges. Must remain readable when reduced to a 48x48 gameplay cell.

No prose, no project status, no dashboard, no menus, no checkmarks, no code, no Godot UI, no progress information.
```

### Acceptance requirements

- exactly one recognizable Skirmisher identity;
- six distinct poses;
- no pose merges;
- no status/dashboard content;
- no labels touching the sprite;
- enough separation to crop six independent 48×48 derivatives;
- no different armor/weapon identity between frames;
- no obvious AI-generated anatomy/equipment mutation that destroys frame continuity.

---

## 7. Example — Region 3 functional building batch

```text
Create only a production pixel-art environment reference sheet for Nice Journey.

Show exactly eight Region 3 functional building exteriors:
1. Central Tower
2. Quest Hall
3. Blacksmith
4. General Merchant
5. Inn / Rest House
6. Storage House
7. Training Hall
8. Clinic / Apothecary

Use one coherent 16-bit-inspired top-down 3/4 fantasy-town architectural language: matching stone, timber, roofing, trim, scale and lighting. Each building must be isolated in its own cell with a readable entrance. Central Tower is the strongest landmark.

Plain neutral background. No people. No status panels. No project dashboard. No editor UI. No implementation text. No test counts. No file paths.
```

Generated buildings must be inspected for consistent perspective before any crop/integration work.

---

## 8. Automatic rejection gate

Reject the output before transfer if **any** of these are true:

- wrong subject;
- dashboard/status/report composition;
- missing required poses/objects;
- unexpected extra characters/buildings;
- inconsistent character identity between animation poses;
- inconsistent building perspective between cells;
- weapon/equipment changes between required poses;
- impossible anatomy that will not survive gameplay scale;
- unreadable silhouette at intended gameplay size;
- text overlaps source art and cannot be cleanly excluded;
- source cells overlap so heavily that safe crops are impossible;
- output contains a polished illustration but no usable gameplay poses;
- result would require redrawing most of the asset procedurally to become usable.

If rejected, the file does **not** enter `assets/art/` and does **not** enter the provenance manifest as an accepted production source.

A rejected output may be noted in development history, but never presented as integrated production art.

---

## 9. Retry limit

For this specific failure mode:

- attempt 1: normal clean subject-only generation;
- attempt 2: one stricter subject-only retry;
- if both are unrelated: **stop**.

Do not perform attempt 3, 4, 5, etc. in the same contaminated context.

At that point use a fresh image-generation context and carry only the asset brief/reference forward.

This rule exists to prevent mindless image generation and wasted review time.

---

## 10. Accepted-source transfer procedure

Only after visual approval:

1. preserve the exact generated source image;
2. transfer it into the local workspace through `@a` binary file transfer;
3. store the untouched source under:

```text
res://assets/art/generated_sources/imagegen/
```

with a category-specific subfolder where useful;

4. compute SHA-256 for the exact source;
5. record source filename, hash and generation role;
6. inspect dimensions/alpha/pixel-art suitability;
7. derive gameplay crops with deterministic crop rectangles;
8. use nearest-neighbor scaling for pixel-art gameplay derivatives;
9. save crop coordinates and derivative hashes in a derivation manifest;
10. update `docs/ASSET_PROVENANCE_MANIFEST.json`;
11. only then wire the derivative into inspector-owned presentation resources.

The untouched source must remain available even after gameplay derivatives are produced.

---

## 11. Derivation rules

Generated reference sheets are often larger than gameplay assets. A derived asset is acceptable when the transformation is mechanically documented and does not secretly replace the source artwork.

Allowed operations include:

- exact crop;
- neutral-background removal;
- alpha cleanup;
- removal of disconnected label/header components outside the actual sprite;
- nearest-neighbor resize into the approved gameplay cell;
- assembly of accepted cells into a core sheet.

Do not claim "generated-source-derived" if the derivative was substantially redrawn from scratch.

Every derivative should record:

- source path;
- source SHA-256;
- crop rectangle;
- output dimensions;
- derivative SHA-256;
- cleanup/scaling note.

---

## 12. In-engine integration rule

Nice Journey production sprite presentation must follow the current project architecture:

- `Sprite2D` for sprite presentation;
- `AnimationPlayer` / external `AnimationLibrary` for animation state/frame ownership;
- inspector-editable `.tres` resources for textures, offsets, scale, z-order, bindings and other authored visual data;
- runtime code selects semantic states/events only;
- no dynamic frame scanning/loading loop;
- no hardcoded `res://assets/art/...` texture paths inside gameplay/combat/AI runtime code when an inspector/resource reference can own the value.

Generated replacement work should normally be a resource/texture swap, not a new code architecture.

---

## 13. V01 removal rule

Do **not** delete a provisional V01 asset immediately after generation.

Delete a V01 category only when all of the following are true:

1. replacement source was visually accepted;
2. production derivative exists;
3. provenance/derivation records are written;
4. inspector resource points to the new asset;
5. scene/runtime presentation loads the new asset;
6. relevant focused test passes;
7. project resource-path test passes;
8. no live production reference to the replaced V01 remains;
9. broad repository validation passes.

Then remove the replaced V01 asset and stale import/reference files.

Never destroy working provisional content merely because generation is planned.

---

## 14. Visual acceptance after integration

After integration, capture the actual running Godot scene and inspect:

- gameplay-scale readability;
- baseline/ground anchoring;
- cropping;
- nearest filtering;
- pose consistency;
- mirroring behavior where applicable;
- weapon/effect alignment;
- telegraph clarity;
- building scale and entrance readability;
- no source-sheet text/header artifacts;
- no unintended background rectangles;
- no frame drift.

A unit test passing does not prove that a sprite is visually usable.

---

## 15. Failure handling after integration

If a generated derivative looks wrong in-engine:

1. identify whether the defect comes from the source, crop, alpha cleanup, resize, pivot, offset, scale, frame order or presentation resource;
2. fix the smallest responsible layer;
3. do not regenerate art automatically if the source itself is still usable;
4. rerun the focused presentation test;
5. recapture the affected scene;
6. run the broad validation gate after the integrated batch is stable.

The corrected Duelist V02 crop is the precedent: source sheet was retained, crop boundaries were corrected, derivative hashes/provenance were updated, and the result was rechecked in-engine.

---

## 16. What not to do

Never:

- keep generating blindly after repeated unrelated outputs;
- call a dashboard an asset;
- crop a progress dashboard into game sprites;
- claim a generated replacement exists when the source was rejected;
- delete V01 before the replacement is live and validated;
- redraw a rejected image procedurally and still call it the generated source;
- hardcode replacement texture paths into runtime combat/AI code;
- skip provenance because the image came from ChatGPT;
- treat a PNG inventory count as art completion;
- mark final-art acceptance from automated tests alone.

---

## 17. Recommended batch order after generator recovery

Once a clean generation context reliably returns the requested subject:

1. Region 3 functional buildings;
2. Region 3 decorative/environment supporting set;
3. tower modular room/environment art;
4. Skirmisher;
5. Assassin;
6. Mobile Ranged;
7. Caster;
8. Support;
9. Summoner;
10. Flying Harrier;
11. Controller / Disruptor;
12. The Tenth Warden;
13. final UI replacement batch.

Do not generate the entire remaining catalog in one enormous prompt. Generate coherent reviewable batches.

---

## 18. Required completion evidence per batch

A batch is complete only when there is:

- accepted exact generated source;
- source SHA-256;
- derivation manifest where crops/resizes are used;
- updated provenance;
- inspector-owned production references;
- focused tests green;
- resource-path validation green;
- live renderer capture reviewed;
- broad validation green after meaningful integrated changes;
- replaced V01 removed only when safe.

---

## 19. Current project-specific status

At the time this protocol was created:

- exact generated-source V02 player animations/equipment/projectiles/VFX/telegraphs are already integrated;
- Duelist/Bruiser/Defender/Marksman have accepted generated-reference-derived V02 gameplay art;
- the corrected Duelist crop has been visually rechecked in-engine;
- all twelve reusable enemy archetypes now use accepted generated-source-derived V02 gameplay art; the former remaining-eight enemy batch is complete and visually reviewed in-engine;
- Region 3, tower, Tenth Warden and most UI art still contain provisional V01 imagery;
- earlier attempts to generate Region 3/Skirmisher art incorrectly produced project-progress/dashboard imagery and were rejected; subsequent accepted enemy generation did not retroactively make those rejected dashboard outputs valid;
- those bad outputs were **not integrated into the game**;
- generation should resume only under the clean-context/retry-limit rules in this document.

---

## 20. Final rule

**Generate deliberately, inspect every result, and stop when the generator is clearly producing the wrong class of image.**

The project prefers one accepted, provenance-tracked, in-engine-validated asset over twenty unrelated generations.
