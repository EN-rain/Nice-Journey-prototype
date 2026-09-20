# Nice Journey specialist-role workflow

Use `../../agency-agents/` only as a task-specific reference library. It does not override the master specification, project code/tests, or current implementation state.

## Rules

- DR-01 through DR-08 are resolved. Do not resurrect historical decision holds.
- Direct `@a`/Auvrynt work is preferred. Do not use the Codex orchestrator.
- Never scan or load the whole agency library. Open only the exact role file needed for the current work or review.
- Keep each specialist assignment narrow and non-overlapping.
- The main implementation owner integrates results and owns final verification.

## Role router

| Task | Useful role references |
|---|---|
| Godot gameplay/combat | `game-development/godot/godot-gameplay-scripter.md`, `game-development/game-designer.md` |
| Region/level/traversal | `game-development/level-designer.md`, `game-development/game-designer.md` |
| AI/runtime architecture | `game-development/game-designer.md`, `engineering/engineering-software-architect.md` |
| Technical art/rendering | `game-development/technical-artist.md`, `game-development/godot/godot-shader-developer.md` |
| Audio | `game-development/game-audio-engineer.md` |
| UX/accessibility | `design/design-ux-architect.md`, `testing/testing-accessibility-auditor.md` |
| Persistence/workflows | `engineering/engineering-software-architect.md`, `specialized/specialized-codebase-archaeologist.md` |
| Minimal-change/code review | `engineering/engineering-code-reviewer.md`, `engineering/engineering-minimal-change-engineer.md` |
| Performance/evidence | `testing/testing-performance-benchmarker.md`, `testing/testing-evidence-collector.md` |

## Minimal workflow

1. Identify the exact subsystem and authoritative project docs using `docs/INDEX.md`.
2. Load at most the role(s) needed for that subsystem.
3. Implement the smallest dependency-safe slice.
4. Use a reviewer role only when it adds a distinct QA lens.
5. Run focused verification, then the broad gate after meaningful integration.
6. Record durable facts only after validation is green.
