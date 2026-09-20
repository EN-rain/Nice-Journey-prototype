# Nice Journey — VFX Visual Bible v0.1

Authority: master combat/readability requirements, DR-06, and `docs/art/ART_INTEGRATION_RULES.md`.

## Priority

Gameplay information has priority over spectacle. Telegraphs, attack direction, player/enemy silhouette, objective markers and recovery timing must remain visible through all effects.

## Current primitive library

Telegraphs under `res://assets/art/vfx/telegraphs/`:

- narrow line
- wide line
- cone
- short melee arc
- wide sweep
- circle
- delayed circle
- projectile lane
- lunge path

Player combat effects under `res://assets/art/player/vfx/`:

- light slash trail
- heavy slash trail
- block spark
- parry spark
- ranged release flash
- Arcane cast burst

## Phase grammar

Every committed hostile attack should make these phases visually separable when applicable:

1. **Preparation / windup:** warning geometry or pose builds before active danger.
2. **Active danger:** strongest readable boundary; should agree with actual hit geometry.
3. **Defense/contact result:** block, parry, guard break or hit feedback appears only after authoritative resolution.
4. **Recovery:** warning fades and the enemy pose clearly settles into punish/recovery state.

Do not use the same visual intensity for preparation and active danger.

## Defense cues

Block feedback is a compact impact cue. Parry feedback is sharper/brighter and must never imply that projectiles are parryable, because prototype projectiles are not. Guard-break feedback should be heavier than a normal block and should not appear when sufficient stamina produced a successful block.

## Status cues

- **Burn:** warm restrained fire cue; no visual implication of crit/weak-point multiplication.
- **Slow:** cool movement-resistance cue; do not imply global time stop, cast slow or AI-thinking slowdown.

## Boss cues

The Tenth Warden requires especially clear telegraphs. Arc Volley must read as dodgeable/blockable but not parryable. Crescent Sweep must read as unblockable and dodgeable. Boss-warning visuals must not pre-announce victory or a phase result before runtime commits it.

## Density limits

Prefer a few high-signal particles over dense noise. Do not stack slash trail, hit flash, status particles, damage numbers and environment particles so heavily that attack recovery or floor hazards disappear. Disable/reduce decorative layers before reducing critical telegraph clarity.

## Acceptance

VFX are accepted only after actual runtime geometry and timing are known, effects are attached to authoritative events rather than guessed timers, representative combat screenshots/video remain readable, reduced-motion/accessibility behavior is verified, and overdraw/performance stays within the final benchmark budget.