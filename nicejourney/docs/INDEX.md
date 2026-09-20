# Nice Journey documentation index

Use this file as the documentation router. Search large documents for the relevant subsystem/heading and read small ranges; do not ingest them wholesale by default.

## Core authorities

| Need | Read | Retrieval rule |
|---|---|---|
| Gameplay/design contract | `../../Nice_Journey_Master_Game_Specification_V2_1.md` | Large (~197 KB). Search exact mechanic/section first. |
| What is implemented now | `IMPLEMENTATION_STATE.md` | Large (~104 KB). Search subsystem name, wave, asset, or test. |
| What should be done next | `NEXT_DEVELOPMENT_SEQUENCE.md` | Medium (~37 KB). Read the opening/current-priority section, then only relevant wave. |
| Broad test/performance evidence | `REFERENCE_PERFORMANCE_EVIDENCE.md` | Read when changing performance/acceptance claims. |
| Visual evidence status | `VISUAL_EVIDENCE_PROVISIONAL.md` | Read for screenshot/manual visual acceptance work. |
| Specialist-role workflow | `AGENCY_AGENT_WORKFLOW.md` | Read only when selecting a specialist role/reviewer. |
| Compact task prompt | `TASK_PROMPT_TEMPLATE.md` | Optional; use when a task needs explicit scope/acceptance without repeating repo history. |
| Asset provenance | `ASSET_PROVENANCE_MANIFEST.json` | Very large (~396 KB). Search by production path, source filename, or hash; never read whole by default. |

## Art router

Start with `art/ART_INTEGRATION_RULES.md` for permanent presentation/provenance rules, then load only the task-specific file:

| Art task | Additional document |
|---|---|
| Player | `art/PLAYER_VISUAL_DESIGN_BIBLE.md` |
| Enemies | `art/ENEMY_VISUAL_DESIGN_BIBLE.md` |
| Region 3 general | `art/REGION3_VISUAL_BIBLE.md` |
| Region 3 decorative/support generation | `art/REGION3_DECORATIVE_SUPPORT_V02_BATCH.md` + matching manifest |
| Region 3 functional buildings | `art/REGION3_FUNCTIONAL_BUILDING_V02_BATCH.md` + matching manifest |
| Building processing/tooling | `art/SPRITE_GEN_BUILDING_ASSET_GUIDE.md` |
| Tower | `art/TOWER_VISUAL_BIBLE.md` |
| UI | `art/UI_VISUAL_BIBLE.md` |
| VFX/telegraphs | `art/VFX_VISUAL_BIBLE.md` |
| Image generation/acceptance failure | `art/IMAGE_GENERATION_FAILURE_RECOVERY_AND_ASSET_ACCEPTANCE_PROTOCOL.md` |

Do not load every visual bible for one art task.

## Code router

- Player/actions: `src/player/`, then `src/combat/` only when authoritative combat ownership is involved.
- Combat resolution/contact/action state: `src/combat/`.
- Enemy/AI: `src/enemies/` and `src/ai/`; boss-specific code is under the Tenth Warden area.
- Persistence/settings/input: `src/core/`.
- Region 3/tower/world traversal: `src/world/`.
- Quests/progression/items: `src/quests/`, `src/progression/`, `src/items/`.
- UI/audio/effects: `src/ui/`, `src/audio/`, `src/presentation/`.
- Tests: search `tests/` for the subsystem name before inventing a new test harness.

## Retrieval pattern

1. Start from the user task and known path/symbol.
2. Search code and this index before opening broad docs.
3. Retrieve only the matching sections from the master/state/sequence docs.
4. Inspect neighboring implementation and tests.
5. Expand scope only when a dependency or contradiction is proven.

## Validation

- Prefer the narrowest meaningful test while iterating.
- Repository-wide gate after meaningful integration: `powershell -ExecutionPolicy Bypass -File tools\reference_validation.ps1`.
- Do not rerun the broad gate repeatedly without intervening changes or a new risk.

## Documentation maintenance

- Do not create handoff/status Markdown files.
- Put durable implementation facts in `IMPLEMENTATION_STATE.md` and dependency-order changes in `NEXT_DEVELOPMENT_SEQUENCE.md`.
- Put permanent reusable rules in a focused existing guide, not in current-state history.
- Prefer updating/deleting stale duplicate docs over adding another summary.
- Keep `AGENTS.md` files as maps and invariants, not changelogs.
