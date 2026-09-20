# Nice Journey — Player Visual Design Bible v0.1

Authority: master §§5–7 and §38.1. This document converts the locked art contract into production-ready player asset constraints without changing narrative canon.

## Core identity

The prototype uses one shared protagonist body for Melee, Ranged and Mage. Class identity comes from the separately rendered weapon, skill/VFX language and combat behavior, not from three different bodies.

Production body style: compact 16-bit-inspired traveler silhouette, right-facing side profile authored once and mirrored for left-facing presentation. The current user-supplied V03 anchor has spiky brown hair, a blue scarf, cream sleeves, a brown leather vest and gloves, blue trousers, and brown boots. Exact sources and visually classified motion rows are recorded in `assets/art/generated_sources/imagegen/player/main_character_batches_v03/player_main_character_v03_derivation_manifest.json`; retained ZIP filenames are not semantic authority. Preserve this identity during revisions. The earlier slate-coat/teal reference and palette below are historical V01 reference art, not a direction to recolor or replace the V03 character. These visual choices do not establish faction, culture, biography or lore.

## Canvas, anchors and bounds

- Body canvas: exactly **32×32 px** for every player body frame.
- Texture filtering: nearest-neighbor; no runtime smoothing.
- Ground anchor/pivot: **(16, 29)** in source-pixel coordinates.
- Primary right-facing grip reference: **(23, 17)**. Mirrored left-facing presentation uses the corresponding mirrored grip transform rather than a separately authored body set.
- Current idle-reference transparent bounds: **x 8–24, y 2–29** (Pillow bbox `(8, 2, 25, 30)`).
- Body frames never resize the body canvas between actions. Weapons, projectiles and effects may extend outside the body canvas in separate assets/layers.
- Authoritative collision remains the ground footprint; visible body pixels do not define combat range.

## Production palette v1

This table records the historical Wave 29/V01 palette. Current V03 body revisions inherit the exact accepted V03 source colors without recoloring to this table. VFX/lighting may expand their own palette, but body identity colors must stay stable across frames.

| Role | Hex |
|---|---|
| Outline 0 | `#16151F` |
| Outline 1 | `#282637` |
| Shadow | `#34384B` |
| Stone Dark | `#40465A` |
| Stone Mid | `#596277` |
| Stone Light | `#7B879C` |
| Paper | `#D8D2C4` |
| Highlight | `#F1E9D8` |
| Skin Shadow | `#9B604F` |
| Skin Base | `#C98568` |
| Skin Light | `#E3B28C` |
| Hair Dark | `#241F2B` |
| Hair Base | `#3B3142` |
| Cloth Dark | `#314256` |
| Cloth Base | `#4E6A7F` |
| Cloth Light | `#7293A4` |
| Accent Teal Dark | `#1D746E` |
| Accent Teal | `#35B7A7` |
| Accent Teal Light | `#72E0CB` |
| Danger Dark | `#8A3A3A` |
| Danger | `#D85B52` |
| Gold Dark | `#8F6A2D` |
| Gold | `#D6A84C` |
| Arcane | `#8D6CCF` |

Palette strip: `res://assets/art/palettes/master_palette_v01.png`.

## Body silhouette rules

- Head/hair read must remain distinct from shoulders at 1× source scale.
- Front arm reaches the common grip reference without drawing a permanent weapon into the body sprite.
- Legs keep two separate readable feet at the ground line; no single fused lower-body block in locomotion frames.
- The current blue scarf is a shared body identity cue, not a class color. It may move with cloth motion but must not change hue from frame to frame.
- Outline thickness is normally one source pixel. Two-pixel masses are reserved for silhouette-critical edges, never soft anti-aliased blur.
- Manual pixel AA is allowed only if it improves readability at 1× and survives nearest-neighbor scaling.

## Weapon and class shape language

Weapons are separate from the body and rotate/aim independently toward the cursor.

- **Melee:** one-handed sword uses a straight, compact blade silhouette; shield uses a broad readable defensive face. The shield may appear only when equipped/action presentation requires it.
- **Ranged:** two-handed bow uses a tall crescent silhouette with a clearly readable string/limb direction. No quiver/ammo-stock visual is required because prototype ammunition is not tracked.
- **Mage:** two-handed staff uses a long shaft and a compact arcane focus shape. Arcane effects may use the Arcane palette role plus controlled VFX expansion.

Weapon art must never be baked into the shared protagonist body sheet.

## Required body animation production order

Wave 30 should author the body in this order so the highest-value movement/combat readability is validated first:

1. Idle — 4–6 frames.
2. Walk — 6–8 frames.
3. Run — 6–8 frames.
4. Dash — 4–6 frames.
5. Dodge — 4–6 frames; this is not a roll.
6. Attack — 4–8 frames.
7. Block — 2–4 frames plus held pose.
8. Parry — 4–6 frames.
9. Cast — 6–10 frames.
10. Hit — 3–5 frames.
11. Heavy Attack — 6–10 frames.
12. Death — 8–12 frames.
13. Interact — 4–6 frames.
14. Pickup — 4–6 frames.
15. Use Item — 4–6 frames.
16. Climb — 6–8 frames.
17. Sleep — 4–6 frames.

Body animation is presentation only. Gameplay action legality, contact, damage, spending, block/parry results and interruption remain owned by runtime systems.

## Shared combat cue grammar

Every production attack presentation must make four phases visually distinguishable: preparation/windup, active danger, defense/contact outcome and recovery. Critical telegraphs have visual priority over trails, hit flashes, particles, numbers and decorative lighting.

## Source assets created in Wave 29

- `res://assets/art/player/player_side_idle_ref_v01.png` — 32×32 transparent right-facing body reference.
- `res://assets/art/player/player_side_reference_sheet_v01.png` — enlarged review sheet with anchor markers and palette strip; documentation/reference only.
- `res://assets/art/palettes/master_palette_v01.png` — controlled palette swatch.

These are production-reference assets, not a claim that all required animation frames are finished. Wave 30 expands the approved body reference into the full animation set.
