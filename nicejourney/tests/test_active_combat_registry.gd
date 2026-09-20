extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var registry: ActiveCombatRegistry = ActiveCombatRegistry.new()
    _expect(not registry.is_active() and registry.get_active_reason_count() == 0, "active-combat registry starts inactive")

    _expect(not registry.acquire(&"", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "empty source IDs are rejected")
    _expect(not registry.acquire(&"encounter:bad id", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "malformed source IDs are rejected")
    _expect(not registry.acquire(&"encounter:a", &"distance_only"), "unlocked combat reasons are rejected")
    _expect(not registry.is_active(), "rejected acquisitions cannot activate combat")

    _expect(registry.acquire(&"encounter:b", ActiveCombatRegistry.REASON_UNRESOLVED_ATTACK_THREAT), "unresolved attack threat can activate combat")
    _expect(registry.acquire(&"boss:a", ActiveCombatRegistry.REASON_BOSS_PHASE_OR_COMMITTED_ATTACK), "boss phase or committed attack can activate combat")
    _expect(registry.acquire(&"encounter:a", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "engaged hostile encounter can activate combat")
    _expect(registry.acquire(&"encounter:a", ActiveCombatRegistry.REASON_CONTESTED_ENCOUNTER_OBJECTIVE), "one source can hold an independent contested-objective cause")
    _expect(registry.is_active() and registry.get_active_reason_count() == 4, "all locked §23.1 causes compose into one active-combat answer")

    _expect(not registry.acquire(&"encounter:a", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "duplicate source/reason acquisition is rejected without double-counting")
    _expect(registry.get_active_reason_count() == 4, "duplicate acquisition leaves active-cause accounting unchanged")

    var ordered_snapshot: Dictionary = registry.get_debug_snapshot()
    var ordered_reasons: Array = ordered_snapshot.get("reasons", []) as Array
    _expect(_is_sorted(ordered_reasons), "debug reasons are deterministic by stable source then reason ID")

    _expect(registry.release(&"encounter:a", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "one explicit source/reason entry can release")
    _expect(registry.is_active() and registry.get_active_reason_count() == 3, "releasing one cause cannot clear unrelated active causes")
    _expect(not registry.release(&"encounter:a", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER), "duplicate release is a safe no-op")
    _expect(registry.release_source(&"encounter:a") == 1, "explicit source release removes only that source's remaining causes")
    _expect(registry.is_active() and registry.get_active_reason_count() == 2, "removing one source leaves unrelated sources active")
    _expect(registry.release_source(&"encounter:missing") == 0, "unknown source release is a safe no-op")

    var snapshot: Dictionary = registry.get_debug_snapshot()
    var reasons: Array = snapshot.get("reasons", []) as Array
    _expect(bool(snapshot.get("active", false)) and int(snapshot.get("reason_count", -1)) == 2, "debug snapshot exposes active state and cause count")
    _expect(_contains_reason(reasons, &"boss:a", ActiveCombatRegistry.REASON_BOSS_PHASE_OR_COMMITTED_ATTACK), "debug reasons expose boss-phase/committed-attack ownership")
    _expect(_contains_reason(reasons, &"encounter:b", ActiveCombatRegistry.REASON_UNRESOLVED_ATTACK_THREAT), "debug reasons expose unresolved attack-threat ownership")

    snapshot["active"] = false
    snapshot["reason_count"] = 0
    if not reasons.is_empty():
        (reasons[0] as Dictionary)["source_id"] = &"mutated"
    reasons.clear()
    _expect(registry.is_active() and registry.get_active_reason_count() == 2, "mutating detached debug data cannot mutate active-combat state")

    _expect(registry.release(&"boss:a", ActiveCombatRegistry.REASON_BOSS_PHASE_OR_COMMITTED_ATTACK), "boss-phase/committed-attack cause releases explicitly")
    _expect(registry.is_active(), "remaining unresolved attack threat keeps combat active")
    _expect(registry.release(&"encounter:b", ActiveCombatRegistry.REASON_UNRESOLVED_ATTACK_THREAT), "final active cause releases explicitly")
    _expect(not registry.is_active() and registry.get_active_reason_count() == 0, "combat becomes inactive only after the final explicit cause releases")

    if _failures == 0:
        print("ACTIVE COMBAT REGISTRY TEST PASS")
    else:
        push_error("ACTIVE COMBAT REGISTRY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _is_sorted(reasons: Array) -> bool:
    var prior_source: String = ""
    var prior_reason: String = ""
    for reason_variant: Variant in reasons:
        if not reason_variant is Dictionary:
            return false
        var reason: Dictionary = reason_variant as Dictionary
        var source_id: String = String(reason.get("source_id", &""))
        var reason_id: String = String(reason.get("reason_id", &""))
        if source_id < prior_source or (source_id == prior_source and reason_id < prior_reason):
            return false
        prior_source = source_id
        prior_reason = reason_id
    return true

func _contains_reason(reasons: Array, source_id: StringName, reason_id: StringName) -> bool:
    for reason_variant: Variant in reasons:
        if not reason_variant is Dictionary:
            continue
        var reason: Dictionary = reason_variant as Dictionary
        if StringName(reason.get("source_id", &"")) == source_id and StringName(reason.get("reason_id", &"")) == reason_id:
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
