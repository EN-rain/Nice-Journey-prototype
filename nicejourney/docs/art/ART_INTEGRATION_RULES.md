# Nice Journey — Art Integration Rules

Updated: 2026-09-15

## Authority

- Master game authority: `D:\nicejourney\Nice_Journey_Master_Game_Specification_V2_1.md`
- Current implementation truth: `res://docs/IMPLEMENTATION_STATE.md`
- Current dependency order: `res://docs/NEXT_DEVELOPMENT_SEQUENCE.md`
- Image-generation acceptance/failure handling: `res://docs/art/IMAGE_GENERATION_FAILURE_RECOVERY_AND_ASSET_ACCEPTANCE_PROTOCOL.md`
- Category-specific visual bibles live under `res://docs/art/`.

This document contains permanent integration rules only. It is not a status handoff.

## 1. Presentation architecture

For normal character/entity sprite presentation:

- use `Sprite2D`;
- use `AnimationPlayer` with external/editor-authored `AnimationLibrary` resources;
- gameplay code chooses semantic animation/state names;
- animation resources own texture assignment, frame sequence, timing, looping and presentation transforms;
- do not add runtime manual frame stepping when `Sprite2D + AnimationPlayer` is appropriate.

## 2. Inspector-first ownership

Presentation and tuning values should be editor/resource owned whenever reasonable.

Prefer, in order:

1. exported `Resource` profiles;
2. exported scene/node properties;
3. exported node references / `NodePath` values;
4. `AnimationPlayer` / `AnimationLibrary` resources;
5. tuning `.tres` resources;
6. code constants only for real invariants, semantic IDs and authoritative rules.

Typical Inspector/resource-owned values include textures, animation names/timing, sprite/VFX offsets, scale, rotation, z-index, presentation colors/alpha, telegraph presentation, audio streams and UI icon references.

Keep stable IDs, persistence contracts, transaction semantics, exact validation rules and authoritative combat/gameplay rules in code.

## 3. Generated-source acceptance

Do not claim an image-generation replacement is integrated until all applicable steps are complete:

1. visually accept the exact generated source;
2. preserve the exact source bytes;
3. record SHA-256/source identity;
4. derive gameplay assets deterministically;
5. record derivation/provenance;
6. wire the derivative through Inspector/resource/TileSet/scene ownership;
7. inspect the result in the real Godot renderer at gameplay scale;
8. run focused validation;
9. run repository-wide regression after a meaningful integrated slice;
10. remove superseded V01 assets only after the replacement is genuinely live and validation is green.

Rejected dashboard/catalogue/status-board outputs never enter production assets or provenance as accepted sources.

## 4. Environment integration

Prefer editor-authored environment composition:

- `TileSet` / `TileMapLayer` resources;
- scene-instanced structures and props;
- texture/material resources;
- collision/navigation scene resources;
- Inspector-authored occlusion/fade/presentation configuration.

Do not hardcode building/prop sprite paths, decorative placement or visual colors in gameplay scripts when scene/resource authoring is the correct owner.

## 5. Combat/VFX/telegraph boundary

Authoritative gameplay code owns legality, contact geometry, timing windows and combat resolution.

Presentation resources own texture/material, animation, color, alpha, scale, pulse/fade behavior, offsets and layer/z-order. Semantic gameplay events may trigger presentation, but presentation must not become the source of gameplay truth.

Boss telegraphs must not be bound to guessed geometry/timing; they are wired only when authoritative attack geometry/timing exists.

## 6. UI integration

Prefer `Theme`, `StyleBox`, `UiIconProfile`/catalog resources and exported UI configuration over hardcoded asset paths, font sizes, colors or panel constants where practical. UI transitions may use `AnimationPlayer`.

## 7. Validation gate for each art slice

Before completion, verify as applicable:

- exact source identity/hash is recorded;
- derivation and provenance are recorded;
- target assets exist under `res://`;
- Godot imports/scene/resource parsing succeed;
- nearest filtering/pixel-art settings are correct;
- expected animations/resources are Inspector-editable;
- no runtime frame-stepping or hardcoded art-path regression was introduced;
- gameplay-scale readability, baseline/pivot, mirroring, weapon alignment and telegraph clarity are visually checked;
- focused presentation/resource tests pass;
- `test_project_resource_paths.gd` and `test_asset_provenance_manifest.gd` pass where applicable;
- `tools/reference_validation.ps1` passes after meaningful integrated batches.

## 8. Cleanup rule

Temporary intake folders, review renders, duplicated source ZIPs and superseded handoff/status documents may be deleted once the authoritative source/evidence is preserved in its permanent project location. Do not delete live source evidence, current V01 placeholders that still have no accepted replacement, or files referenced by current resources/tests.
