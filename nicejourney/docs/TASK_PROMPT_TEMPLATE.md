# Compact task prompt template

Use this only when a task benefits from explicit scoping. Do not paste project history that `AGENTS.md` or `docs/INDEX.md` already routes to.

```text
TASK: <one concrete outcome>

SCOPE:
- <subsystem/path if known>

REQUIREMENTS:
- <task-specific behavior/constraint>

DO NOT:
- <only important task-specific exclusions>

ACCEPTANCE:
- <observable result/test/evidence>

REFERENCES:
- <only exact docs/files needed; omit if AGENTS.md routing is enough>
```

Good prompt: `TASK: wire the accepted Region 3 Batch 2 into the existing profiles/TileSet. ACCEPTANCE: focused Region 3 tests + broad validation green. Use docs/INDEX.md for references.`

Avoid prompts that repeat the master spec, implementation history, generic coding rules, or large logs already stored in the repository.
