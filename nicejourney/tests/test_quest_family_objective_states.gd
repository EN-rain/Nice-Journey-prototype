extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_annihilation()
    _test_escort()
    _test_defense()
    if _failures == 0:
        print("QUEST FAMILY OBJECTIVE STATES TEST PASS")
    else:
        push_error("QUEST FAMILY OBJECTIVE STATES TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_annihilation() -> void:
    var state := AnnihilationObjectiveState.new()
    _expect(state.configure([&"enemy:a", &"enemy:b"]), "annihilation binds designated group")
    _expect(not bool(state.record_actor_defeated(&"enemy:optional")["accepted"]), "optional inhabitants never enter annihilation count")
    _expect(bool(state.record_actor_defeated(&"enemy:a")["accepted"]), "required actor defeat records")
    _expect(not state.is_complete() and state.remaining_actor_ids() == [&"enemy:b"], "annihilation reports visible remaining required threats")
    _expect(state.record_actor_defeated(&"enemy:a")["reason_id"] == &"duplicate_ignored", "duplicate death event is idempotent")
    _expect(bool(state.record_actor_defeated(&"enemy:b")["complete"]), "annihilation completes only after every designated actor is defeated")
    var restored := AnnihilationObjectiveState.new()
    _expect(restored.load_dictionary(state.to_dictionary()).is_empty() and restored.is_complete(), "annihilation state round-trips")

func _test_escort() -> void:
    var state := EscortObjectiveState.new()
    _expect(state.configure(&"npc:escort", [&"route:start", &"route:turn", &"route:goal_approach"], &"goal:escort", &"retry:escort_start", &"failure:authored_policy"), "escort binds actor, route, goal, failure policy and safe retry origin")
    _expect(not bool(state.record_route_node_reached(&"route:turn")["accepted"]), "escort cannot silently skip an authored route node")
    _expect(state.set_wait_requested(true) and state.wait_requested, "escort exposes explicit wait/follow state without teleporting actor progress")
    _expect(bool(state.record_route_node_reached(&"route:start")["accepted"]), "escort reaches first route node")
    _expect(state.record_route_node_reached(&"route:start")["reason_id"] == &"duplicate_ignored", "duplicate route event is idempotent")
    _expect(not bool(state.record_goal_reached(&"goal:escort")["accepted"]), "escort cannot complete before traversing its full route")
    state.record_route_node_reached(&"route:turn")
    state.record_route_node_reached(&"route:goal_approach")
    _expect(bool(state.record_goal_reached(&"goal:escort")["complete"]), "escort completes at authored goal after route traversal")
    var restored := EscortObjectiveState.new()
    _expect(restored.load_dictionary(state.to_dictionary()).is_empty() and restored.is_complete(), "escort state round-trips with route progress")
    var serialized := state.to_dictionary()
    serialized["next_route_index"] = float(serialized["next_route_index"])
    var serialized_restored := EscortObjectiveState.new()
    _expect(serialized_restored.load_dictionary(serialized).is_empty() and serialized_restored.is_complete(), "escort state accepts integral numeric route progress after save/load normalization")

    var failed := EscortObjectiveState.new()
    failed.configure(&"npc:escort2", [&"route:a"], &"goal:b", &"retry:b", &"failure:policy")
    _expect(bool(failed.record_failure(&"failure:actor_death")["accepted"]), "caller-authored escort failure can be recorded explicitly")
    _expect(failed.failed and not failed.is_complete(), "failed escort is terminal without silently granting completion")

func _test_defense() -> void:
    var state := TowerDefenseObjectiveState.new()
    var waves := {
        "wave:1": [&"enemy:w1a", &"enemy:w1b"],
        "wave:2": [&"enemy:w2a"],
    }
    _expect(state.configure(&"objective:defense", 100, waves), "tower defense binds defended objective, health and required wave actors")
    _expect(not bool(state.record_actor_defeated(&"wave:1", &"enemy:resident")["accepted"]), "unrelated floor residents do not count toward defense waves")
    _expect(bool(state.record_actor_defeated(&"wave:1", &"enemy:w1a")["accepted"]), "required defense actor defeat records")
    _expect(not state.is_wave_complete(&"wave:1"), "wave remains incomplete while a required actor remains")
    state.record_actor_defeated(&"wave:1", &"enemy:w1b")
    _expect(state.is_wave_complete(&"wave:1") and not state.is_complete(), "completed wave does not skip remaining required waves")
    _expect(bool(state.apply_objective_damage(25)["accepted"]) and state.objective_current_hp == 75, "defense objective health is persistent objective state")
    _expect(bool(state.record_actor_defeated(&"wave:2", &"enemy:w2a")["complete"]), "defense completes only after all required waves while objective survives")
    var restored := TowerDefenseObjectiveState.new()
    _expect(restored.load_dictionary(state.to_dictionary()).is_empty() and restored.is_complete(), "tower defense state round-trips")

    var failed := TowerDefenseObjectiveState.new()
    failed.configure(&"objective:defense2", 10, {"wave:1": [&"enemy:x"]})
    _expect(bool(failed.apply_objective_damage(10)["accepted"]) and failed.failed, "defended objective reaching zero records failure")
    _expect(not bool(failed.record_actor_defeated(&"wave:1", &"enemy:x")["accepted"]), "failed defense cannot later complete from stale defeat events")

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
