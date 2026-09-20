# Nice Journey — UI Visual Bible v0.1

Authority: master UI/accessibility requirements and `docs/art/ART_INTEGRATION_RULES.md`.

## Baseline

The prototype renders on a 640×360 internal canvas with 1280×720 reference output. UI art must survive supported scaling and remain crisp. Use restrained pixel frames and icons rather than high-detail illustrations that collapse at small sizes.

## Current local icon inventory

- 18 skill icons under `res://assets/art/ui/skills/`.
- class icons for Melee, Ranged and Mage under `ui/classes/`.
- Tower Sigil and map marker sheet under `ui/markers/`.
- quest-family icons for Escort, Tower Defense and Annihilation under `ui/quests/`.
- Burn and Slow icons under `ui/status/`.

## Icon grammar

Icons use dark outlines, a compact 32×32 canvas for most gameplay symbols, and shape-first recognition. Avoid words inside small icons. Active skills emphasize action geometry; passives use stable symbolic motifs. Class identity may use danger/teal/arcane accents but must also differ by glyph shape.

## HUD

Health, stamina and Mage mana must be readable independently. Mage mana appears only where the class owns mana. Do not fabricate ammo UI because prototype Ranged tracks no ammunition.

## Inventory/equipment

Five equipment-slot identities remain: weapon, armor, off-hand, accessory 1, accessory 2. UI art must not imply unsupported additional slots. Two-handed bow/staff presentation should visually communicate occupied main-hand behavior without inventing an off-hand item.

## Skills

Loadout UI must visually support exactly two active and two passive equipped skills, while the class pool contains three active + three passive definitions. Rank display supports ranks 1–3 and locked rank 0. Temporary combat skills should be visually distinguishable without pretending they are permanently learned.

## Quest/map

Quest-family markers must distinguish Escort, Tower Defense and Annihilation. The permanent Tower Sigil needs a stable travel icon. Map markers must remain readable at world-map, region-map and tower-floor-map layers.

## Accessibility

Do not use color alone for critical state. Pair color with shape, iconography, text or border pattern. Reduced-motion mode should never depend on animated icon motion for comprehension. UI backgrounds must preserve sufficient contrast under varied gameplay lighting.

## Acceptance

UI assets are accepted only when consumed by actual UI scenes, tested at supported canvas/scaling settings, keyboard/mouse focus remains clear, critical states survive color-independent review, and no icon implies unsupported mechanics.