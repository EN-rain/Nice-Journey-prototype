# Tenth Warden — first identity source candidate (review only)

**Stable target:** `asset:enemies/boss_tenth_warden/tenth_warden_idle`. Generate ONE
isolated neutral boss identity image first, **not** the nine-pose replacement,
core sheet, telegraphs, room background, or a production asset. No source exists
for this candidate yet. Do not mark a manifest record accepted from this brief.

## Clean-context image prompt

> A single full-body fantasy adaptive-duelist milestone boss, The Tenth Warden,
> in a neutral ready stance. Crisp 16-bit-inspired pixel art with controlled
> palette ramps and a strong, readable head, armor, and directional weapon
> silhouette, for a side-biased top-down 3/4 orthographic pixel game. One
> consistent whole figure at a fixed scale, feet visible with generous margins,
> isolated on real transparent RGBA. Design an original coherent identity,
> readable when fitted into one **96×96 gameplay sprite**, not a tiny figure
> on a full illustration canvas. No text, labels, grid, sprite sheet, extra
> poses, VFX, baked telegraph, hit box, scenery, arena, UI, status dashboard,
> faction insignia, lore, named person, adds, or healing imagery.

Supply these **reference images** to the art generator for *staging/size only*:

- `res://assets/art/enemies/boss_tenth_warden/tenth_warden_idle_v01.png`
  (96×96, SHA-256 `9ebc89eade1df590bb09009b554352eb11ad7c7a6b865a3f22fb24e359cdb85d`)
- `res://assets/art/enemies/boss_tenth_warden/tenth_warden_core_sheet_v01.png`
  (864×96, nine 96×96 cells, SHA-256
  `eb9991a07b697abf5ef3e346f5897fcddce1155a59b64a5028a8385d6c87c8f5`)

The procedural V01 costume, face, palette, main weapon geometry, and weak-point
location **are not approved identity facts**. The game approves exactly two boss
phases and five move *families*, but this first source must depict no moves or
phase result. No move durations, hit areas, projectile paths, animation frames,
attachment sockets, or telegraph positions are approved by making an image.

## Handoff and gated acceptance

1. Preserve the **exact original generated PNG** with its own SHA-256, without
   overwriting either V01 reference or extracting a gameplay derivative first.
   Source-generation resolution is not prescribed; 96×96 is the **derived
   gameplay frame**, not a demand that the image generator emit 96×96.
2. Before copying the source into any permanent accepted-source directory, run
   `python -B tools/art/boss_identity_review/intake_identity_source.py --source
   "PATH_TO_REAL_ORIGINAL_GENERATED_SOURCE.png"`. It reads only and reports
   mechanical checks and exact SHA. It does **not** establish visual acceptance.
3. Manually inspect the *actual* source: one whole body, clear feet and margins,
   transparent background (no checkerboard painted into the pixels), correct
   game view, no unrelated object/text/UI, clean silhouette and direction at
   96×96. The tool cannot establish any of those semantic properties.
4. After identity approval, separately authorize a deterministic 96×96 RGBA
   crop/fit with **nearest-neighbor**, recorded source/derivative hashes and
   reviewed pivot/foot baseline. Current presentation owns 96px textures in
   external `tenth_warden_animation_library.tres`; visual profile body offset is
   `(0,-48)`, nearest filtering. The real boss scene initially has `Body`
   hidden and `PlaytestBody` visible, so replacing a texture alone does not
   prove in-game visibility. First use an isolated native review; do not alter
   this live scene/profile/animation library in the identity-intake stage.
5. Only later, with approved consistent identity, request the other poses and
   authored timings. Five production telegraph bindings remain unassigned until
   authoritative combat geometry and phase timing are final.

**Review status:** SOURCE_NOT_RECEIVED; NOT_ACCEPTED; NOT_LIVE. This brief and
intake script never mutate production art, resources, or manifests.
