# Nice Journey — Region 3 Decorative / Support V02 Production Batch

Updated: 2026-09-15
Status: BATCH 1 INTEGRATED / BATCH 2 GENERATION PENDING
Authority: master §24.4 / §24.12, current authored Region 3 layout, `REGION3_VISUAL_BIBLE.md`, `SPRITE_GEN_BUILDING_ASSET_GUIDE.md`, `IMAGE_GENERATION_FAILURE_RECOVERY_AND_ASSET_ACCEPTANCE_PROTOCOL.md`

## 1. Purpose

This is the next coherent production-art batch after the eight Region 3 functional landmarks reached generated V02, in-engine integration and full validation.

**Current checkpoint:** decorative structures 01–10 are accepted, preserved from `D:/nicejourney/Nice_Journey_Region3_Decorative_V02_Batch1.zip`, deterministically derived to 160×160 V02 gameplay sprites, wired through Inspector-owned decorative profiles, visually reviewed in the authored town, and broad-regression validated. Decorative 11–12 plus props/ground-road/ruins/outskirts/risk-zone remain the required Batch 2 generation target. Do not regenerate 01–10 unless a later visual defect is proven.

The batch contains exactly:

- 12 decorative town structures matching the master-authored identities;
- one town/route prop source sheet;
- one ground/road source sheet;
- one ruins-module source sheet;
- one south-outskirts support source sheet;
- one east-risk-zone support source sheet.

That is a 17-source production packet. It is one coherent visual batch even if the image system returns the outputs as separate files.

Do not mix tower, boss, UI, player, enemy, implementation-progress, test-result or documentation imagery into this batch.

## 2. Required visual anchor

Use the already accepted Region 3 V02 functional-building art as the only architectural style anchor.

Primary anchor:

```text
res://assets/art/environments/region3/functional_buildings/region3_central_tower_exterior_v02.png
```

Useful whole-town reference:

```text
res://docs/evidence/renderer/region3-authored-town-layout-v02-functional-buildings.png
```

The generated decorative/support batch must match the accepted V02 functional set in:

- fixed 3/4 top-down gameplay perspective;
- 16-bit-inspired pixel-art edge language;
- stone/timber/roof/metal material family;
- implied light direction;
- pixel density after deterministic reduction;
- overall palette discipline.

The Central Tower must remain the strongest landmark. Decorative buildings must be quieter, smaller and less service-coded than the functional landmarks.

## 3. Clean-context generation rule

Use this document in a clean image-focused generation context.

Do not include coding progress, wave numbers, performance figures, file trees, test counts, editor screenshots or status summaries in the generation request.

If the first output is a dashboard/status/editor image, reject it immediately. Make at most one controlled retry in that contaminated context. If the second attempt is also wrong-subject, stop and move to a fresh image-generation context.

Every accepted source must be visually inspected before it is transferred to the project.

## 4. Shared building prompt

For each decorative structure, use the accepted Region 3 V02 functional-building reference and this shared prompt shape:

```text
Create only one production game-art environment sprite for Nice Journey.

Subject: [DECORATIVE STRUCTURE VARIANT]
Style: match the attached accepted Region 3 V02 architecture exactly — coherent 16-bit-inspired fantasy-town pixel art with crisp pixel edges.
View: fixed 3/4 top-down gameplay perspective, same camera/perspective as the attached reference.
Materials: same stone, timber, roof, trim and metal family as the accepted Region 3 V02 town kit.
Lighting: same implied light direction as the accepted reference.

Gameplay role:
- decorative, non-enterable town structure;
- must NOT read as a functional service destination;
- no glowing interaction marker, open invitation portal, quest icon, shop UI, readable sign text or service-specific branding;
- no people.

Composition:
- one isolated whole structure;
- entire roof, walls and ground-contact footprint visible;
- generous transparent/chroma margin on every side;
- no cropping or edge contact;
- silhouette readable when reduced for 640x360 gameplay;
- visually subordinate to the Central Tower and major service buildings.

Background: genuine transparency when reliable; otherwise one flat chroma key that does not collide with the building palette.

Do not create a dashboard, progress report, editor screenshot, UI panel, validation result, roadmap, file path, labels, text, character showcase or unrelated scene.
```

The authored frontage listed below is a layout cue, not permission to change the camera perspective. Preserve the same gameplay camera. If a north/east/west frontage cannot be shown cleanly without perspective drift, prioritize coherent architecture and a non-interactive façade; the final decorative placement may be adjusted during in-engine art review because these structures have no functional entrance interaction.

## 5. Twelve decorative structure variants

| Source | Stable ID | Master identity | Visual brief | Current authored frontage |
|---|---|---|---|---|
| `region3_decorative_01_source_v02.png` | `r3:decorative:01` | R3-B09 Decorative home | compact ordinary home; no service cues | south |
| `region3_decorative_02_source_v02.png` | `r3:decorative:02` | R3-B10 Decorative home | second home variant; noticeably different roof/body silhouette but same kit | south |
| `region3_decorative_03_source_v02.png` | `r3:decorative:03` | R3-B11 Decorative workshop | restrained work-yard/workshop cues; must not imply crafting service | south |
| `region3_decorative_04_source_v02.png` | `r3:decorative:04` | R3-B12 Decorative storehouse | utility storage silhouette; must not imply player-storage interaction | south |
| `region3_decorative_05_source_v02.png` | `r3:decorative:05` | R3-B13 Decorative home | third home variant; compact and quieter than service buildings | west |
| `region3_decorative_06_source_v02.png` | `r3:decorative:06` | R3-B14 Decorative stall structure | closed/ambient stall structure; no merchant inventory or active-shop cue | west |
| `region3_decorative_07_source_v02.png` | `r3:decorative:07` | R3-B15 Decorative home | fourth home variant; same town kit, distinct roof/porch rhythm | west |
| `region3_decorative_08_source_v02.png` | `r3:decorative:08` | R3-B16 Decorative civic façade | modest civic-looking façade; no faction heraldry or unapproved institution identity | west |
| `region3_decorative_09_source_v02.png` | `r3:decorative:09` | R3-B17 Decorative workshop | second workshop variant; non-enterable and not a smith/crafting destination | north |
| `region3_decorative_10_source_v02.png` | `r3:decorative:10` | R3-B18 Decorative home | fifth home variant; compact ordinary residence | north |
| `region3_decorative_11_source_v02.png` | `r3:decorative:11` | R3-B19 Decorative stall structure | second ambient stall; must not block frontage or imply extra service | east |
| `region3_decorative_12_source_v02.png` | `r3:decorative:12` | R3-B20 Decorative home | sixth home variant; same materials with clearly distinct silhouette | east |

Home variants should look related but not be twelve recolors of one identical shell. Variation should come from roofline, footprint proportion, timber rhythm, shutters, porch/awning treatment and small non-service architectural details rather than new lore.

## 6. Town / route prop source

Source name:

```text
region3_town_props_source_v02.png
```

Generation brief:

```text
Create only a production game-art prop source sheet for Nice Journey Region 3.

Match the attached accepted Region 3 V02 town architecture: same 16-bit-inspired pixel-art density, palette, material language and implied light direction.
Fixed 3/4 top-down gameplay view.

Place cleanly separated, individually crop-safe town/route props on transparent or flat chroma background. Include useful variants from this approved vocabulary:
- crates and storage stacks;
- barrels;
- small cart;
- bench;
- signpost with NO readable text;
- lantern/fixture;
- planter/shrub;
- fence sections and posts;
- banner shape with NO faction emblem or readable text;
- road marker;
- restrained training dummy;
- restrained forge/merchant/apothecary support objects only as generic environmental props, not as new service interactions.

Keep every prop isolated with generous spacing. No people. No labels. No UI. No dashboard. No editor screenshot. No project-status content.
```

The generated source is a visual source sheet, not the final atlas. Final atlas packing must be deterministic after accepted-source preservation.

## 7. Ground / road source

Source name:

```text
region3_ground_road_source_v02.png
```

Generation brief:

```text
Create only a production pixel-art material/tile reference sheet for Nice Journey Region 3.

Match the accepted Region 3 V02 palette and lighting while keeping source tiles usable without baked dramatic directional lighting.
Top-down gameplay ground materials only.

Required material vocabulary:
- safe-town grass/ground;
- dirt/road surface;
- worn road edge transition;
- stone/plaza surface;
- restrained fence/material strip language;
- subtle neutral transition material that can support outskirts;
- danger-zone accent material that remains visually quieter than enemy attack telegraphs.

Use crisp repeating tile logic and obvious isolated tile samples with enough spacing for deterministic extraction. Avoid perspective-painted road scenes; this is source material for authored TileSet/scene composition.

No buildings, people, text, UI, dashboard, editor, project status, test counts or roadmap.
```

Do not assume the current 256×32 V01 atlas geometry must be preserved. Preserve the exact accepted source first; derive an engine atlas only after tileability and gameplay-scale review.

## 8. Ruins module source

Source name:

```text
region3_ruins_modules_source_v02.png
```

Generation brief:

```text
Create only a production game-art ruins-module source sheet for Nice Journey Region 3.

Match the accepted Region 3 V02 stone/material language and pixel density.
Fixed 3/4 top-down gameplay perspective.

Show cleanly separated reusable broken-stone modules suitable for the north ruins zone:
- partial low wall;
- broken wall corner;
- cracked pillar or short column remnant;
- collapsed arch fragment;
- broken foundation/plinth;
- small rubble cluster;
- damaged stone marker with NO readable text or faction symbol.

The modules must suggest age/damage without inventing a named civilization, historical event, religion or faction.
Keep silhouettes low enough not to hide combat telegraphs or the player excessively.
Transparent/chroma background, generous crop-safe spacing, no people, no UI, no dashboard, no labels.
```

## 9. South-outskirts support source

Source name:

```text
region3_outskirts_support_source_v02.png
```

Generation brief:

```text
Create only a production game-art environment-support source sheet for the south outskirts of Nice Journey Region 3.

Match the accepted Region 3 V02 palette, pixel density and light direction.
Top-down/3/4 gameplay-compatible environmental props and ground accents only.

Visual purpose:
- lighter environmental complexity than town or ruins;
- clear route readability;
- visible visual language that leads back toward the town;
- early-danger area without looking like the late-prototype risk pocket.

Include cleanly separated crop-safe support elements such as sparse shrubs/grass clumps, simple fence/gate fragments, roadside stones, small route markers with no readable text, and modest ground-edge accents.

No new lore symbols, no people, no enemies, no buildings, no UI, no dashboard, no project status.
```

## 10. East risk-zone support source

Source name:

```text
region3_risk_zone_support_source_v02.png
```

Generation brief:

```text
Create only a production game-art environment-support source sheet for the optional east high-risk pocket of Nice Journey Region 3.

Match the accepted Region 3 V02 palette/material family and pixel density.
Top-down/3/4 gameplay-compatible environmental props and ground accents only.

Visual purpose:
- unmistakably higher-risk than ordinary roads/outskirts before combat starts;
- no implication that mandatory progression or a unique required item is hidden here;
- danger accents must remain less visually dominant than enemy telegraphs, attack indicators and quest-critical markers.

Use generic environmental warning language only: harsher ground breaks, restrained hazard-colored material accents, worn warning posts without readable text, broken barriers, rock/terrain accents, sparse ominous vegetation treatment.
Do not invent faction symbols, magical lore, poison mechanics, lava, radiation, named curses or any unsupported hazard system.

No people, enemies, UI, dashboard, editor screenshot, labels, test counts or project-status content.
```

## 11. Required source names and destination

All 17 accepted exact generated sources must be preserved under:

```text
res://assets/art/generated_sources/imagegen/region3/decorative_support_v02/
```

Required filenames:

```text
region3_decorative_01_source_v02.png
region3_decorative_02_source_v02.png
region3_decorative_03_source_v02.png
region3_decorative_04_source_v02.png
region3_decorative_05_source_v02.png
region3_decorative_06_source_v02.png
region3_decorative_07_source_v02.png
region3_decorative_08_source_v02.png
region3_decorative_09_source_v02.png
region3_decorative_10_source_v02.png
region3_decorative_11_source_v02.png
region3_decorative_12_source_v02.png
region3_town_props_source_v02.png
region3_ground_road_source_v02.png
region3_ruins_modules_source_v02.png
region3_outskirts_support_source_v02.png
region3_risk_zone_support_source_v02.png
```

Do not rename an unrelated generated image to satisfy these names. The filename is assigned only after visual acceptance.

## 12. Production derivatives

Planned V02 derivative paths:

```text
res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_01_v02.png
...
res://assets/art/environments/region3/decorative_buildings/region3_decorative_building_12_v02.png
res://assets/art/environments/region3/props/region3_prop_sheet_v02.png
res://assets/art/environments/region3/roads/region3_ground_road_tileset_v02.png
res://assets/art/environments/region3/ruins/region3_ruins_module_sheet_v02.png
res://assets/art/environments/region3/outskirts/region3_outskirts_support_sheet_v02.png
res://assets/art/environments/region3/risk_zone/region3_risk_zone_support_sheet_v02.png
```

Do not pre-lock derivative canvas sizes merely because V01 used 96×96 decorative buildings, 128×64 props, 256×32 roads or 128×96 ruins. The accepted V02 source should be preserved first, then reduced/pixel-cleaned/packed deterministically after gameplay-scale review.

## 13. Acceptance gate before transfer

Reject any generated source before project transfer when:

- the subject is wrong or mixed with unrelated imagery;
- any part is accidentally cropped;
- perspective drifts away from the accepted V02 Region 3 town kit;
- architecture looks substantially more important than the functional landmarks;
- a decorative building appears to advertise an unavailable service;
- a civic façade introduces faction/religion/state lore not approved by the master;
- a support sheet contains enemies, characters or gameplay mechanics not requested;
- background is presented as fake checkerboard instead of real alpha;
- text, labels or UI overlap the artwork;
- tiles/modules overlap so badly they cannot be deterministically separated;
- risk-zone accents compete with combat telegraph readability;
- the source would require major manual repainting rather than deterministic derivation.

## 14. Integration sequence after the generated ZIP exists

1. Preserve the user-provided ZIP byte-for-byte and record its SHA-256.
2. Extract the exact 17 accepted source files into a raw preservation folder.
3. Run mechanical source-intake reporting for dimensions, alpha, visible bounds and edge contact.
4. If needed, normalize source edge contact using transparent padding only; do not repaint accepted art during normalization.
5. Derive V02 gameplay assets from untouched/normalized sources using nearest-neighbor-safe deterministic tooling.
6. Record source, normalized-source and derivative SHA-256 values in a derivation manifest.
7. Register accurate provenance without claiming legal sufficiency.
8. Integrate decorative buildings through scene/Inspector-owned presentation; integrate roads/ground through TileSet/scene-owned data rather than gameplay-code paths.
9. Add outskirts/risk/ruins/prop presentation only where it improves the authored Region 3 layout and does not fabricate mechanics.
10. Visually inspect the real 640×360 / 1280×720 renderer output.
11. Run focused Region 3/art/resource/provenance tests and full `tools/reference_validation.ps1`.
12. Delete replaced V01 art only after V02 is live, paths/provenance are correct and broad validation is green.

## 15. Current stop condition

This batch is **not yet generated**. Do not claim V02 decorative/support integration until the exact accepted generated source ZIP exists and the intake/derivation/in-engine validation sequence above has completed.
