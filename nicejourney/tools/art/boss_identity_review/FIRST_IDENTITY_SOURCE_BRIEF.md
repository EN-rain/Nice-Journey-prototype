# Tenth Warden — first identity source candidate (review only)

**Stable target:** `asset:enemies/boss_tenth_warden/tenth_warden_idle`. Generate ONE
isolated neutral boss identity image first, **not** the nine-pose replacement,
core sheet, telegraphs, room background, or a production asset. No source exists
for this candidate yet. Do not mark a manifest record accepted from this brief.

## Fresh-image-only prompt — one boss, one pose

Use a **new image-only conversation**. Provide *only* the short prompt below and,
if visual reference is necessary, the isolated 96×96 V01 idle PNG. Do not supply
the nine-cell core sheet, any escort image, previous failed generation, project
status, or the longer boss telegraph packet to the image generator. Those
multi-pose and adjacent escort cues are not authority for this first image.

> ONE isolated fantasy milestone-boss character: **The Tenth Warden**, an
> imposing armored adaptive duelist holding one clearly readable directional
> weapon in a still, neutral ready stance. Full body and feet visible; crisp
> 16-bit-inspired pixel art, restrained cool palette, strong head/armor/weapon
> silhouette, side-biased top-down 3/4 game view, true transparent background.
> Compose ONE complete figure suitable for later fitting into ONE 96×96 game
> sprite. No companion or escort, no walking
> cycle, no repeated figures or frames, no strip/grid/sprite sheet, no “Idle” or
> “Walk” labels or any text, no UI/scenery/VFX/attack geometry/faction emblem.

**Only optional visual staging reference:**
`res://assets/art/enemies/boss_tenth_warden/tenth_warden_idle_v01.png`
(96×96, SHA-256 `9ebc89eade1df590bb09009b554352eb11ad7c7a6b865a3f22fb24e359cdb85d`).
This procedural placeholder gives scale/composition only; it does not fix the
final boss's gender, costume, face, weapon design, palette or lore.

**Rejected output, not an intake source:** the latest result was reported as a
female escort-like **4-idle/6-walk labeled strip**. It is the wrong subject and
layout regardless of alpha, file dimensions, or mechanical intake success.
No exact source bytes/hash were supplied for it here. Do not salvage frames or
add that image to generated-source provenance. If the fresh attempt again
produces an escort or a character strip, stop in that context rather than
iterating minor wording in the same contaminated conversation.

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
