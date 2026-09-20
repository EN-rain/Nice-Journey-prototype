# Persistence scope

Read this only for work under `src/core/persistence/`.

- Preserve the typed `ProfileSnapshot` schema and three-slot model.
- Durable saves remain atomic: stage/temp -> verify -> commit, with prior-valid-generation fallback.
- Never fabricate a profile when stored data is missing, corrupt, or incompatible.
- `SaveRequestCoordinator` owns safe-boundary admission/coalescing and captures a fresh snapshot at commit time; do not bypass it with stale state.
- Failure/retry restoration uses one coherent durable safe snapshot so related persisted state restores together.
- Search `tests/` for persistence/save/rollback coverage before changing behavior.
- Run focused persistence tests first; use the repository-wide validation gate after meaningful cross-system changes.
