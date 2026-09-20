extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const PLAYER_COMBAT_TUNING: PlayerCombatRuntimeTuning = preload("res://src/data/tuning/player_combat_runtime_default.tres")
const SAVE_ROOT := "user://test_player_status_safe_persistence_boundary"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var player := PLAYER_SCENE.instantiate() as PlayerController
    root.add_child(player)
    await process_frame

    var class_runtime := _class_runtime(&"mage")
    _expect(class_runtime != null, "player status persistence fixture configures class safe-state owner")
    if class_runtime == null:
        player.queue_free()
        quit(1)
        return

    var player_state := PlayerCombatantRuntimeBinding.create_state(
        player,
        class_runtime,
        PLAYER_COMBAT_TUNING,
        &"player:status_persistence"
    )
    _expect(player_state != null, "player encounter state creates from class-owned safe status store")
    if player_state == null:
        player.queue_free()
        class_runtime.free()
        quit(1)
        return

    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:status_persistence") and encounter.register_player(player_state), "status persistence fixture registers player encounter state")
    var binding := PlayerCombatantRuntimeBinding.new()
    _expect(binding.bind(player, encounter, player_state), "status persistence fixture binds live player state")

    _expect(bool(encounter.apply_status_to_target(player_state.actor_id, {
        "status_id": &"burn:persist",
        "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
        "magnitude": 3.0,
        "duration_ticks": 90,
    }).get("accepted", false)), "fixture applies supported Burn without inventing persistence semantics")
    _expect(bool(encounter.apply_status_to_target(player_state.actor_id, {
        "status_id": &"slow:persist",
        "behavior": PrototypeStatusResolver.BEHAVIOR_SLOW,
        "magnitude": 0.25,
        "duration_ticks": 120,
    }).get("accepted", false)), "fixture applies supported Slow without inventing persistence semantics")
    _expect(bool(encounter.advance_status_ticks(30).get("accepted", false)), "fixture advances only existing authored remaining-tick state")

    _expect(class_runtime.get_status_safe_states().is_empty(), "encounter status remains encounter-owned until an explicit safe-state handoff")
    _expect(binding.persist_status_safe_states(class_runtime), "binding can explicitly hand the authoritative player status snapshot to the existing combat safe-state owner")
    var stored := class_runtime.get_status_safe_states()
    _expect(stored.size() == 2, "safe-state owner stores both supported statuses")
    _expect(_remaining(stored, &"burn:persist") == 60 and _remaining(stored, &"slow:persist") == 90, "safe-state owner preserves exact remaining status durations")

    var captured := class_runtime.capture_safe_state()
    _expect((captured.get("status_states", []) as Array).size() == 2, "combat safe snapshot now serializes supported status durations")
    var parsed_variant: Variant = JSON.parse_string(JSON.stringify(captured))
    _expect(parsed_variant is Dictionary, "combat safe status payload survives JSON serialization")

    var save_service := SaveService.new(SAVE_ROOT)
    save_service.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Status Persistence", "mage")
    profile.safe_state = SafeCheckpointState.make(
        &"safe:status_persistence",
        &"region:3",
        0,
        &"checkpoint:status_persistence",
        {"combat_state": captured.duplicate(true)},
        {},
        1
    )
    _expect(not profile.safe_state.is_empty() and save_service.save_profile(1, profile) == OK, "project SaveService persists the combat status safe payload inside a coherent profile snapshot")
    var loaded := save_service.load_profile(1)
    _expect(loaded != null, "profile with supported status durations reloads through SaveService")
    var loaded_combat: Dictionary = {}
    if loaded != null:
        loaded_combat = ((loaded.safe_state.get("player_state", {}) as Dictionary).get("combat_state", {}) as Dictionary).duplicate(true)
        _expect((loaded_combat.get("status_states", []) as Array).size() == 2, "SaveService round trip preserves the serialized status collection")

    binding.unbind()
    encounter.end_encounter()

    var restored_runtime := _class_runtime(&"mage")
    _expect(restored_runtime != null and not loaded_combat.is_empty() and restored_runtime.restore_safe_state(loaded_combat), "fresh class runtime restores Burn/Slow from the real profile save/load path")
    if restored_runtime != null:
        var restored_state := PlayerCombatantRuntimeBinding.create_state(
            player,
            restored_runtime,
            PLAYER_COMBAT_TUNING,
            &"player:status_restored"
        )
        _expect(restored_state != null, "new encounter state imports restored class-owned status durations")
        if restored_state != null:
            var restored_statuses := restored_state.get_status_states()
            _expect(_remaining(restored_statuses, &"burn:persist") == 60 and _remaining(restored_statuses, &"slow:persist") == 90, "restored encounter state preserves exact remaining Burn/Slow ticks")

        var before := restored_runtime.get_status_safe_states()
        var malformed := restored_runtime.capture_safe_state()
        malformed["status_states"] = [{
            "status_id": "burn:bad",
            "behavior": "burn",
            "magnitude": 1.0,
            "remaining_ticks": 0,
        }]
        _expect(not restored_runtime.restore_safe_state(malformed), "invalid persisted status duration fails closed")
        _expect(restored_runtime.get_status_safe_states() == before, "failed status restore does not replace prior safe status ownership")

        var legacy := restored_runtime.capture_safe_state()
        legacy.erase("status_states")
        _expect(restored_runtime.restore_safe_state(legacy) and restored_runtime.get_status_safe_states().is_empty(), "legacy combat safe snapshots without status_states remain load-compatible")

    player.queue_free()
    class_runtime.free()
    if restored_runtime != null:
        restored_runtime.free()
    save_service.delete_slot(1)
    await process_frame

    if _failures == 0:
        print("PLAYER STATUS SAFE PERSISTENCE BOUNDARY TEST PASS")
    else:
        push_error("PLAYER STATUS SAFE PERSISTENCE BOUNDARY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _class_runtime(class_id: StringName) -> ClassCombatRuntime:
    var runtime := ClassCombatRuntime.new()
    runtime.tuning = StarterCombatTuning.new()
    if not runtime.configure_class(class_id):
        runtime.free()
        return null
    return runtime


func _remaining(states: Array, status_id: StringName) -> int:
    for raw_state: Variant in states:
        if not raw_state is Dictionary:
            continue
        var state := raw_state as Dictionary
        if StringName(String(state.get("status_id", &""))) == status_id:
            return int(state.get("remaining_ticks", -1))
    return -1


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
