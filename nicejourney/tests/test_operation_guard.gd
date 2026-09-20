extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var guard: GameplayOperationGuard = GameplayOperationGuard.new()
    _expect(guard.is_allowed(GameplayOperationGuard.OP_MANUAL_SAVE), "manual save is allowed without blockers")
    _expect(guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL), "Sigil travel is allowed without blockers")

    var combat_ops: Array[StringName] = [
        GameplayOperationGuard.OP_MANUAL_SAVE,
        GameplayOperationGuard.OP_SIGIL_TRAVEL,
        GameplayOperationGuard.OP_SERVICE,
    ]
    var combat_token: int = guard.acquire_blocker(
        &"encounter:test",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Active combat is unresolved.",
        combat_ops
    )
    _expect(combat_token > 0, "valid blocker acquisition returns a token")
    _expect(not guard.is_allowed(GameplayOperationGuard.OP_MANUAL_SAVE), "active combat blocks manual save")
    _expect(not guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL), "active combat blocks Sigil travel")
    _expect(not guard.is_allowed(GameplayOperationGuard.OP_SERVICE), "active combat can block services")

    var generation_ops: Array[StringName] = [GameplayOperationGuard.OP_MANUAL_SAVE]
    var generation_token: int = guard.acquire_blocker(
        &"generator:floor",
        GameplayOperationGuard.REASON_GENERATOR_CONSTRUCTION,
        "Floor generation is not serializable yet.",
        generation_ops
    )
    _expect(generation_token > combat_token, "blocker tokens are unique and monotonic")
    _expect(guard.get_blocking_reasons(GameplayOperationGuard.OP_MANUAL_SAVE).size() == 2, "multiple independent blockers compose for one operation")
    _expect(guard.get_blocking_reasons(GameplayOperationGuard.OP_SIGIL_TRAVEL).size() == 1, "operation-specific reasons do not leak to unrelated operations")

    _expect(guard.release_blocker(combat_token), "blocker releases by token")
    _expect(guard.is_allowed(GameplayOperationGuard.OP_SIGIL_TRAVEL), "travel becomes allowed once its blocker is removed")
    _expect(not guard.is_allowed(GameplayOperationGuard.OP_MANUAL_SAVE), "save remains blocked by an independent transient state")
    _expect(not guard.release_blocker(combat_token), "double release is rejected without side effects")

    _expect(guard.release_source(&"generator:floor") == 1, "all blockers owned by a source can be released coherently")
    _expect(guard.is_allowed(GameplayOperationGuard.OP_MANUAL_SAVE), "manual save is restored after the final relevant blocker clears")

    guard.free()
    if _failures == 0:
        print("OPERATION GUARD TEST PASS")
    else:
        push_error("OPERATION GUARD TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
