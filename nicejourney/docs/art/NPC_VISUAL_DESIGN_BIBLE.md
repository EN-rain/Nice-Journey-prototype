# Nice Journey — NPC Visual Presentation Decision (Proposed)

Status: **presentation decision for review; not preexisting gameplay authority**  
Scope: the five recurring NPC roles and the temporary escort actor.

## Current V03 character anchor

The live player scene uses:

- texture: `res://assets/art/player/animations/player_body_idle_sheet_v03.png`
- source resource: `res://src/player/presentation/player_body_animation_library.tres`
- current idle sheet: four 32×32 cells (128×32 output)
- body canvas: 32×32 per frame
- right-facing side profile, mirrored for left-facing presentation
- ground anchor: source pixel (16,29)
- nearest-neighbor pixel presentation

The V03 derivation records bottom-center anchoring and 32×32 normalization. This decision uses those current V03 presentation conventions; the older V01 idle reference is not the authority.

## Proposed NPC canvas and direction

Each NPC frame should use an exact transparent **32×32 px** canvas, with the same (16,29) ground anchor and right-authored/left-mirrored direction convention as V03. NPCs share the canvas and anchor only; they do not copy the protagonist’s identity, clothing, palette accent, or weapons.

The image-generation source sheet dimensions are intentionally left open until generation. Accepted source bytes, source dimensions, crop rectangles, and hashes must be recorded after visual acceptance in the normal provenance/derivation manifest. Gameplay derivatives remain exact 32×32 cells.

## Proposed first NPC art slice

The slice contains six isolated identities, each with a readable silhouette at 32×32:

1. **Tower/quest coordinator** — practical town coordinator silhouette; compact travel coat or tabard with a restrained tower/quest marker shape. No lore, faction, or combat implication.
2. **Merchant** — approachable trader silhouette with a small satchel or compact goods bundle; no extra inventory mechanics implied.
3. **Blacksmith/upgrader** — sturdy workwear silhouette with apron and a restrained smithing-tool cue; no weapon baked into an attack animation.
4. **Story/lore NPC** — visually distinct composed civilian silhouette with a scroll/book or lore-token cue; no invented biography or faction.
5. **Variable quest NPC** — neutral adaptable quest-giver silhouette with one small removable quest cue; do not duplicate the same actor simultaneously at multiple anchors.
6. **Temporary escort actor** — readable civilian/traveler silhouette distinct from the five recurring roles; no permanent-companion or combat-ally implication.

These are art-direction briefs only. Runtime identity, stable IDs, dialogue, quest flags, services, health and failure policies remain owned by existing systems.

## Proposed presentation states

Recurring roles begin with **one static identity-anchor frame each**. No recurring-NPC animation set is required for this first slice.

The escort receives:

- **idle: 4 frames**, matching the current V03 idle cadence as a presentation shape;
- **walk: 6 frames**, matching the current V03 walk cadence as a presentation shape.

Semantic escort states reuse those authored visuals through AnimationPlayer/resource mapping:

- wait → idle;
- follow → walk;
- panic → walk.

The mappings are visual state mappings only. They do not add movement rules, panic logic, speed, timing, health behavior, or failure conditions. No separate wait/follow/panic frame sets are generated in this slice.

## Integration target

When accepted, NPC presentation should be attached to the escort/actor scenes through `Sprite2D` plus an external `AnimationLibrary`/AnimationPlayer and inspector-owned texture/profile references. Runtime code should select semantic visual state names; it should not load texture paths or step frames manually.

The authored escort collision footprint currently tested by runtime code is 12×10; that gameplay shape is independent of the proposed 32×32 art canvas.
