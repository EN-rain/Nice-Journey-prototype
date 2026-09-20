extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_authoritative_status_ownership()
    _test_rejections_and_detached_snapshots()
    _test_fail_closed_status_restore()

    if _failures == 0:
        print("STATUS RUNTIME OWNERSHIP TEST PASS")
    else:
        push_error("STATUS RUNTIME OWNERSHIP TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_authoritative_status_ownership() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:status_runtime"), "status fixture configures")
    var player := _combatant(&"player:status_fixture")
    var enemy := _combatant(&"enemy:status_fixture")
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "status fixture registers combatants")

    var changes: Array[Dictionary] = []
    encounter.status_state_changed.connect(func(actor_id: StringName, result: Dictionary) -> void:
        changes.append({"actor_id": actor_id, "result": result.duplicate(true)})
    )

    var burn := encounter.apply_status_to_target(player.actor_id, {
        "status_id": &"burn:test",
        "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
        "magnitude": 3.0,
        "duration_ticks": 3,
    })
    _expect(bool(burn.get("accepted", false)), "runtime admits approved Burn application")
    var slow := encounter.apply_status_to_target(player.actor_id, {
        "status_id": &"slow:test",
        "behavior": PrototypeStatusResolver.BEHAVIOR_SLOW,
        "magnitude": 0.25,
        "duration_ticks": 5,
    })
    _expect(bool(slow.get("accepted", false)), "runtime admits approved Slow application")
    _expect(encounter.get_status_states(player.actor_id).size() == 2, "runtime owns both active status IDs")
    var execution_boundary := encounter.get_status_execution_requests(player.actor_id)
    _expect(bool(execution_boundary.get("accepted", false)) and (execution_boundary.get("requests", []) as Array).size() == 2, "encounter owner exposes parameterized status execution requests without executing balance semantics")
    var missing_execution := encounter.get_status_execution_requests(&"enemy:missing")
    _expect(not bool(missing_execution.get("accepted", true)) and StringName(missing_execution.get("reason_id", &"")) == &"unknown_combatant", "status execution requests remain owned by registered combatants")

    var reapplied := encounter.apply_status_to_target(player.actor_id, {
        "status_id": &"burn:test",
        "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
        "magnitude": 4.0,
        "duration_ticks": 2,
    })
    var burn_state := (reapplied.get("states", []) as Array)[0] as Dictionary
    _expect(StringName(reapplied.get("outcome", &"")) == PrototypeStatusResolver.OUTCOME_REAPPLIED, "runtime preserves resolver reapplication outcome")
    _expect(is_equal_approx(float(burn_state.get("magnitude", 0.0)), 4.0) and int(burn_state.get("remaining_ticks", 0)) == 3, "runtime keeps stronger Burn magnitude without shortening duration")

    var advanced := encounter.advance_status_ticks(3)
    _expect(bool(advanced.get("accepted", false)), "runtime advances status duration by explicit fixed ticks")
    var remaining := encounter.get_status_states(player.actor_id)
    _expect(remaining.size() == 1 and StringName((remaining[0] as Dictionary).get("status_id", &"")) == &"slow:test", "expired Burn is removed while longer Slow remains")
    _expect(int((remaining[0] as Dictionary).get("remaining_ticks", 0)) == 2, "remaining Slow duration advances exactly")
    _expect(changes.size() == 4, "accepted applications and changed duration each emit one authoritative status event")


func _test_rejections_and_detached_snapshots() -> void:
    var encounter := CombatEncounterRuntime.new()
    encounter.configure(&"encounter:status_validation")
    var player := _combatant(&"player:status_validation")
    encounter.register_player(player)

    var invalid := encounter.apply_status_to_target(player.actor_id, {
        "status_id": &"poison:test",
        "behavior": &"poison",
        "magnitude": 1.0,
        "duration_ticks": 10,
    })
    _expect(not bool(invalid.get("accepted", false)), "runtime rejects status behavior outside Burn/Slow")
    _expect(encounter.get_status_states(player.actor_id).is_empty(), "rejected application cannot mutate authoritative status state")

    encounter.apply_status_to_target(player.actor_id, {
        "status_id": &"slow:copy_test",
        "behavior": PrototypeStatusResolver.BEHAVIOR_SLOW,
        "magnitude": 0.2,
        "duration_ticks": 8,
    })
    var snapshot := encounter.get_status_states(player.actor_id)
    (snapshot[0] as Dictionary)["remaining_ticks"] = 999
    _expect(int((encounter.get_status_states(player.actor_id)[0] as Dictionary).get("remaining_ticks", 0)) == 8, "callers cannot mutate authoritative status state through snapshots")
    _expect(not bool(encounter.advance_status_ticks(-1).get("accepted", true)), "negative fixed-tick advance is rejected before mutation")
    _expect(not bool(encounter.advance_status_ticks(1.0).get("accepted", true)), "non-integer fixed-tick advance is rejected before mutation")
    _expect(not bool(encounter.apply_status_to_target(&"enemy:missing", {
        "status_id": &"burn:missing",
        "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
        "magnitude": 1.0,
        "duration_ticks": 1,
    }).get("accepted", true)), "unknown combatant status application is rejected")


func _test_fail_closed_status_restore() -> void:
    var state := _combatant(&"player:status_restore")
    var restored := state.restore_status_states([
        {
            "status_id": &"slow:restore",
            "behavior": PrototypeStatusResolver.BEHAVIOR_SLOW,
            "magnitude": 0.2,
            "remaining_ticks": 45,
        },
        {
            "status_id": &"burn:restore",
            "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
            "magnitude": 3.0,
            "remaining_ticks": 30,
        },
    ])
    _expect(bool(restored.get("accepted", false)), "combatant runtime accepts a valid restored Burn/Slow state collection")
    var statuses := state.get_status_states()
    _expect(statuses.size() == 2 and StringName((statuses[0] as Dictionary).get("status_id", &"")) == &"burn:restore", "restored runtime state is normalized deterministically")

    var before := state.get_status_states()
    var rejected := state.restore_status_states([
        {
            "status_id": &"burn:restore",
            "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
            "magnitude": 3.0,
            "remaining_ticks": 0,
        },
    ])
    _expect(not bool(rejected.get("accepted", true)) and StringName(rejected.get("reason_id", &"")) == PrototypeStatusResolver.REASON_INVALID_STATES, "invalid restored status state is rejected by the shared resolver contract")
    _expect(state.get_status_states() == before, "failed status restore leaves authoritative runtime state unchanged")

    var cleared := state.restore_status_states([])
    _expect(bool(cleared.get("accepted", false)) and state.get_status_states().is_empty(), "validated empty restore clears status state without a special bypass")


func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 50.0, true, false, false), "%s fixture validates" % String(actor_id))
    return state


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
