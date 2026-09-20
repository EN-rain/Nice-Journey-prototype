# Nice Journey — Enemy Visual Design Bible v0.1

Authority: master enemy/combat readability rules, `docs/art/ART_INTEGRATION_RULES.md`, and the existing fair-observation/encounter runtime contracts. Visual presentation never grants AI hidden information and never changes combat resolution.

## Shared visual language

All prototype enemies use crisp 16-bit-inspired raster art with nearest-neighbor filtering, strong silhouettes, controlled palette ramps, explicit windup/active/recovery readability, and transparent backgrounds. Enemy body art must remain subordinate to gameplay telegraphs. Decorative particles must never hide the player, weapon direction, danger geometry, or recovery windows.

The reusable enemy frame canvas baseline is **48×48 px**. The Floor 10 boss uses **96×96 px**. The current production inventory exposes six baseline poses per reusable archetype: idle, move, windup, release, hit, death. Role-specific actions may add frames later without changing the canonical archetype identity.

## Archetype silhouette grammar

- **Duelist:** thin/agile profile, long sword direction, fast precise commitment.
- **Bruiser:** broad upper body, heavy club mass, deliberate windup and large recovery.
- **Defender:** shield-first silhouette; guarded posture must be obvious before contact.
- **Marksman:** bow/quiver profile; aim/windup must visibly precede release.
- **Skirmisher:** compact spear user, mobile pressure and reposition shape.
- **Assassin:** low narrow silhouette, twin short blades, burst/recovery contrast.
- **Mobile Ranged:** lighter ranged silhouette distinct from stationary Marksman identity.
- **Caster:** staff/orb read, clear spell buildup independent from projectile telegraph.
- **Support:** banner/ward focus, non-damage support output must read differently from hostile cast buildup.
- **Summoner:** staff plus detached arcane motes; summon preparation must be readable before spawned-threat ownership begins.
- **Flying Harrier:** airborne wing silhouette, visibly different ground footprint from humanoids.
- **Controller / Disruptor:** forked control focus/arc language, distinct from direct-damage caster.

Local art lives under `res://assets/art/enemies/<archetype>/`.

## First production combat slice

Duelist, Bruiser, Defender and Marksman already have mechanical threat-card/runtime coverage. Their current art set is suitable for first-pass gameplay integration and visual iteration, but should not be treated as final polish. Their windup/release assets must be aligned to actual encounter action ranges before final acceptance.

## Remaining eight archetypes

The remaining eight currently have local visual inventory only. Their existence does **not** claim runtime enemy behavior is implemented. When mechanics are added, preserve the existing silhouette role unless a readability defect is proven.

## Hit, death and recovery

Hit frames must communicate interruption without changing authoritative poise/interruption rules. Death frames are presentation after authoritative defeat only. A death pose must not be shown before runtime defeat is committed. Recovery readability is part of combat fairness: the final attack frames should visibly settle before returning to neutral.

## Palette differentiation

Use controlled role accents rather than full random palettes. Avoid encoding required combat information by color alone. Silhouette, pose and telegraph geometry must remain sufficient for accessibility.

## Acceptance

An enemy visual set is accepted only after: local files exist, provenance validates, Godot imports succeed, role silhouette is readable at gameplay zoom, windup/release agrees with actual action geometry, and encounter-scale clutter has been reviewed.