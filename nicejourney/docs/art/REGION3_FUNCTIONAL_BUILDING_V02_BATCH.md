# Nice Journey — Region 3 Functional Building V02 Production Batch

Updated: 2026-09-15
Status: INTEGRATED AND VALIDATED
Authority: master §24.4 / §24.12, current authored Region 3 layout, `SPRITE_GEN_BUILDING_ASSET_GUIDE.md`

## 1. Purpose

This is the clean generation brief for the eight Region 3 functional landmarks. It intentionally contains **no coding progress, test counts, wave status, file-tree screenshots, dashboards or editor UI** so it can be copied into a clean image-focused context without contamination.

The final sources must be individually reviewable. A single eight-building contact sheet may be used only as an art-direction study; production integration requires accepted per-building source images.

## 2. Post-integration entrance reconciliation

The generation brief below records the pre-generation entrance-direction hypotheses that existed before the accepted V02 source batch was integrated. Those east/west/north suggestions for non-tower service buildings are now **superseded** by the validated authored layout.

Current authoritative integration state:

- Central Tower remains south-facing, matching the master-locked direction.
- Quest Hall, Blacksmith, General Merchant, Inn / Rest House, Storage House, Training Hall and Clinic / Apothecary now use readable south/front-facing entrances in the authored town layout.
- Their entrance tiles and service-connector endpoints were deliberately realigned to the generated facades, and the resulting route-connectivity validation is green.
- Do not restore the old east/west/north service-door suggestions merely because they remain visible in the historical generation text below.

## 3. Shared visual anchor

Generate and approve **Central Tower first**. After approval, use that exact accepted source as the visual anchor for the remaining seven buildings.

Shared visual language:

- 16-bit-inspired fantasy-town pixel art;
- 3/4 top-down gameplay perspective;
- coherent stone foundation + timber/stone wall construction;
- one coherent roof/material family established by the accepted Central Tower anchor;
- dark readable outline language;
- controlled town palette consistent with `REGION3_VISUAL_BIBLE.md`, without introducing new lore-coded colors;
- one consistent implied light direction;
- whole structure fully visible;
- strong readable ground contact;
- crisp pixel edges;
- no people;
- no signs containing readable text;
- no baked UI/status graphics;
- no floating labels;
- no background scene behind the building;
- no isometric diamond-tile perspective drift;
- no side-view facade perspective.

The role should read from silhouette, roofline, entrance treatment and architectural props rather than from written labels.

## 4. Background rule

Preferred source: genuine transparent PNG.

If a visual reference is attached and transparency becomes unreliable, use a flat chroma key background chosen not to collide with the building palette, then perform deterministic cutout. Do not accept a drawn checkerboard as transparency.

## 5. Central Tower

Authored gameplay entrance intent: **south-facing**.

Generation brief:

```text
Create only one production game-art environment sprite.

Game: Nice Journey
Subject: Region 3 Central Tower
Style: 16-bit-inspired fantasy-town pixel art, crisp nearest-neighbor-readable edges.
View: fixed 3/4 top-down gameplay view.

Design:
- strongest landmark in the Region 3 town;
- tall compact stone-and-timber tower with a clear civic/fantasy identity;
- coherent roof/material language suitable to become the anchor for the rest of the town kit;
- readable SOUTH-facing entrance centered toward the lower/front side of the sprite;
- readable base/plinth so the structure feels grounded;
- enough architectural detail to read as the town's central tower without becoming cathedral-scale;
- no people and no surrounding street scene.

Composition:
- entire building fully visible with generous transparent/chroma margin;
- no cropping;
- isolated single building;
- one consistent light direction;
- no labels or text.

Do not create a dashboard, project status panel, editor screenshot, UI mockup, test report, roadmap, file path, character showcase or unrelated scene.
```

Acceptance focus:

- unmistakably the strongest landmark;
- south/front entrance readable at gameplay scale;
- perspective suitable as style anchor;
- materials reusable across the seven other buildings.

## 6. Quest Hall

Validated integrated entrance: **south/front-facing**. This supersedes the pre-generation east-facing hypothesis.

Generation brief:

```text
Create only one production game-art environment sprite matching the attached/accepted Region 3 Central Tower visual language exactly.

Subject: Quest Hall
Style: same 16-bit-inspired pixel density, palette, outline, roof, stone and timber language as the Region 3 anchor.
View: same fixed 3/4 top-down gameplay perspective.

Design:
- civic hall / adventurer-contract hall identity through architecture only;
- broader, lower silhouette than Central Tower;
- visible notice-board-like architectural element may exist, but it must contain no readable text;
- readable EAST-facing entrance on the right side of the gameplay footprint;
- no people.

Whole building fully visible, isolated, generous margin, transparent/chroma background, no labels.
No dashboard, status UI, editor, progress text, roadmap, test counts or unrelated scene.
```

## 7. Blacksmith

Validated integrated entrance: **south/front-facing**. This supersedes the pre-generation west-facing hypothesis.

Generation brief:

```text
Create only one production game-art environment sprite matching the accepted Region 3 style anchor.

Subject: Blacksmith
Style/View: same 16-bit-inspired 3/4 top-down town architecture, palette and pixel density as the Region 3 anchor.

Design:
- sturdy workshop silhouette;
- stone lower structure with timber/metal details;
- chimney/forge identity and restrained smithing props integrated into the architecture;
- readable WEST-facing entrance on the left side of the gameplay footprint;
- no active fire plume large enough to obscure the silhouette;
- no person, smith or customer baked into the sprite.

Whole building fully visible, isolated, generous margin, transparent/chroma background, no labels.
No dashboard, status UI, editor, project progress, code, test report or unrelated scene.
```

## 8. General Merchant

Validated integrated entrance: **south/front-facing**. This supersedes the pre-generation east-facing hypothesis.

Generation brief:

```text
Create only one production game-art environment sprite matching the accepted Region 3 style anchor.

Subject: General Merchant
Style/View: same 16-bit-inspired 3/4 top-down town architecture, palette and pixel density as the Region 3 anchor.

Design:
- compact shop silhouette;
- merchant identity through awning, small display/crate architecture or hanging emblem shapes, with no readable words;
- readable EAST-facing entrance on the right side of the gameplay footprint;
- approachable but not visually louder than Central Tower;
- no merchant/customer characters.

Whole building fully visible, isolated, generous margin, transparent/chroma background, no labels.
No dashboard, editor UI, status card, project text, roadmap or unrelated scene.
```

## 9. Inn / Rest House

Validated integrated entrance: **south/front-facing**. This supersedes the pre-generation west-facing hypothesis.

Generation brief:

```text
Create only one production game-art environment sprite matching the accepted Region 3 style anchor.

Subject: Inn / Rest House
Style/View: same 16-bit-inspired 3/4 top-down fantasy-town architecture, palette and pixel density as the Region 3 anchor.

Design:
- broader welcoming silhouette than a storage house;
- hospitality identity through roofline, covered entry, warm windows or restrained hanging emblem shape;
- readable WEST-facing entrance on the left side of the gameplay footprint;
- no readable sign text;
- no people.

Whole building fully visible, isolated, generous margin, transparent/chroma background, no labels.
No dashboard, editor UI, project status, checklists, test report or unrelated scene.
```

## 10. Storage House

Authored gameplay entrance intent: **south-facing**.

Generation brief:

```text
Create only one production game-art environment sprite matching the accepted Region 3 style anchor.

Subject: Storage House
Style/View: same 16-bit-inspired 3/4 top-down fantasy-town architecture, palette and pixel density as the Region 3 anchor.

Design:
- utilitarian warehouse/storage silhouette;
- reinforced timber door and restrained crate/barrel cues may be integrated near the wall without cluttering the footprint;
- readable SOUTH-facing entrance on the lower/front side;
- less ornate than Quest Hall, Inn or Central Tower;
- no people.

Whole building fully visible, isolated, generous margin, transparent/chroma background, no labels.
No dashboard, editor UI, status report, file paths, test counts or unrelated scene.
```

## 11. Training Hall

Authored gameplay entrance intent: **south-facing**.

Generation brief:

```text
Create only one production game-art environment sprite matching the accepted Region 3 style anchor.

Subject: Training Hall
Style/View: same 16-bit-inspired 3/4 top-down fantasy-town architecture, palette and pixel density as the Region 3 anchor.

Design:
- martial/training identity through sturdy openable hall architecture, reinforced beams and restrained practice-weapon emblem shapes;
- readable SOUTH-facing entrance on the lower/front side;
- broad practical footprint, not a fortress;
- no characters, training dummies or fighters detached outside the building sprite.

Whole building fully visible, isolated, generous margin, transparent/chroma background, no labels.
No dashboard, editor UI, project status, roadmap, code screenshot or unrelated scene.
```

## 12. Clinic / Apothecary

Validated integrated entrance: **south/front-facing**. This supersedes the pre-generation north-facing hypothesis.

Generation brief:

```text
Create only one production game-art environment sprite matching the accepted Region 3 style anchor.

Subject: Clinic / Apothecary
Style/View: same 16-bit-inspired 3/4 top-down fantasy-town architecture, palette and pixel density as the Region 3 anchor.

Design:
- small clinic/apothecary identity through restrained herbal/medical emblem shapes and clean architectural detailing;
- do not use modern hospital signage;
- readable NORTH-facing entrance on the upper/back side of the gameplay footprint;
- the door must remain visually readable despite the 3/4 top-down roof plane;
- no people.

Whole building fully visible, isolated, generous margin, transparent/chroma background, no labels.
No dashboard, editor UI, status panel, project progress, test report or unrelated scene.
```

## 13. Production-source names

Use these accepted exact-source names:

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

Store under:

```text
res://assets/art/generated_sources/imagegen/region3/buildings/
```

## 14. Derivative naming

Production derivatives should use the current semantic naming convention:

```text
region3_central_tower_exterior_v02.png
region3_quest_hall_exterior_v02.png
region3_blacksmith_exterior_v02.png
region3_merchant_exterior_v02.png
region3_inn_exterior_v02.png
region3_storage_exterior_v02.png
region3_training_exterior_v02.png
region3_clinic_exterior_v02.png
```

Do not assume the existing 96×96 V01 canvas is the final ideal production footprint. Preserve the accepted high-resolution source, then choose the derivative canvas/scale only after gameplay-scale review against the authored lots. Any final offset/scale belongs in the corresponding `Region3FunctionalBuildingVisualProfile` resource.

## 15. Required review after every source

Before source transfer/integration verify:

- role identity is correct;
- perspective matches Central Tower anchor;
- entrance faces the authored direction;
- entire structure is present;
- no text/status/dashboard contamination;
- no character baked into sprite;
- no opaque background rectangle;
- consistent pixel density and palette;
- no impossible roof/door geometry;
- enough margin for deterministic crop/cutout;
- source is worth preserving without major repaint.

If any item fails, reject the source rather than hiding the problem in Godot offsets.
