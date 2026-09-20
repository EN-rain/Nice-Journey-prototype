# Region 3 scope

Read this only for work under `src/world/region3/`.

- Preserve exactly 20 town structure identities: 8 functional roles + 12 decorative structures.
- Keep structure identity/layout data scene/resource owned; do not hardcode art paths or decorative placement into gameplay scripts.
- Preserve one connected authored circulation graph and validate route changes instead of mutating around failures.
- Functional/decorative visuals use Inspector-owned profile/catalog resources.
- For current asset status, read only the matching entries in `docs/INDEX.md` and the relevant Region 3 manifest; do not infer status from filename version alone.
- New environment art follows `docs/art/ART_INTEGRATION_RULES.md` and the Region 3 visual bible.
- Search the Region 3 layout/visual tests before changing anchors, entrances, routes, or profiles.
