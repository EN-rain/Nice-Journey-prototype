# Nice Journey workspace router

This workspace wraps the real Godot project at `nicejourney/`. Keep this file short: it is a navigation map, not project history.

## Start here

- Game code/assets/docs: read `nicejourney/AGENTS.md` next.
- Design contract questions: search `Nice_Journey_Master_Game_Specification_V2_1.md` for the exact topic; do not read the whole file by default.
- Extended autonomous-work guidance: consult `astra_guide.md` only when workflow behavior itself is relevant.
- `agency-agents/` is a specialist reference library. Open only the exact role file needed; never ingest the library wholesale.
- `tools/` contains external/support tooling. Inspect only when the task uses it.

## Context discipline

- Prefer `search -> small read range -> edit -> focused verification`.
- Do not load large state docs, manifests, ZIPs, generated sources, evidence folders, or role libraries wholesale.
- Reuse facts already established in the current task instead of rereading them.
- Do not create handoff/status Markdown files. Durable state belongs in the existing project state/sequence docs.

## Workspace constraints

- Use direct `@a`/Auvrynt project tools for local work.
- Do not use the Codex orchestrator.
- Preserve authoritative source/evidence before deleting generated inputs or replacements.
- Default project validation is Godot editor/headless/test work only. Do **not** run release exports, export smoke tests, packaged-build QA, or modify export presets unless the user explicitly requests a dedicated export/release task.
- Do not modify third-party `agency-agents/` or vendored tooling unless the task specifically targets them.
