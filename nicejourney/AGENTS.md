# Nice Journey Godot project

Godot 4.6.2 project. Treat the repository as the source of truth and use progressive disclosure: read only the context required for the task.

## Navigation

- Documentation router: `docs/INDEX.md`
- Design authority: `../Nice_Journey_Master_Game_Specification_V2_1.md`
- Current implementation truth: `docs/IMPLEMENTATION_STATE.md`
- Dependency/order plan: `docs/NEXT_DEVELOPMENT_SEQUENCE.md`
- Art integration rules: `docs/art/ART_INTEGRATION_RULES.md`
- Broad validation: `tools/reference_validation.ps1`

## Source map

- `src/player/` player movement/actions/presentation
- `src/combat/` authoritative combat/action/contact systems
- `src/enemies/`, `src/ai/` enemy/boss/AI runtime and presentation
- `src/world/` Region 3, tower, traversal and world presentation
- `src/core/` persistence, input, accessibility and shared services
- `src/items/`, `src/progression/`, `src/quests/` durable gameplay state/content rules
- `src/ui/`, `src/audio/`, `src/presentation/` presentation-facing systems
- `tests/` deterministic executable gates
- `assets/art/generated_sources/` preserved accepted source evidence; do not casually delete

## Working method

1. Search for the requested subsystem/symbol first.
2. Read the relevant code, neighboring tests, and only the matching doc sections.
3. Do not read the 100KB+ state/spec files end-to-end unless performing an explicit audit.
4. Make the smallest coherent change consistent with existing architecture.
5. Run focused Godot editor/headless tests first. Run `powershell -ExecutionPolicy Bypass -File tools\reference_validation.ps1` after meaningful integrated changes when a broad Godot regression is warranted.
6. Do **not** run release exports, export smoke tests, packaged-build QA, or edit export presets during normal development. Export/release validation is deferred unless the user explicitly asks for it as a separate task.
7. Update durable state docs only when implementation and validation are green.

## Project invariants

- The master specification is authoritative for gameplay/design contracts. DR-01 through DR-08 are resolved; do not resurrect old decision holds from stale prose.
- Do not fabricate mechanics, content, rewards, geometry, test results, or completed art.
- Presentation values belong in Inspector/resources when reasonable; gameplay code owns authoritative semantics.
- For sprite presentation prefer `Sprite2D + AnimationPlayer + external resources`; do not reintroduce runtime frame stepping or hardcoded art paths.
- Preserve exact accepted generated sources, hashes, derivation/provenance, and renderer evidence before removing superseded assets.
- The recurring `Save rejected: invalid profile_id` log in validation is an intentional negative-test fixture when the suite still reports zero failures.

## Token discipline

- `docs/INDEX.md` tells you which large document/section to retrieve for each task.
- Search large JSON/provenance files by asset path or hash instead of reading them whole.
- Avoid broad repository scans when a known path/symbol is available.
- Do not repeat project history in new Markdown files; link to the existing authority instead.
