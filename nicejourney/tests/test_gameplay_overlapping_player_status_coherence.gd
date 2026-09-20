extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const PLAYER_COMBAT_TUNING: PlayerCombatRuntimeTuning = preload("res://src/data/tuning/player_combat_runtime_default.tres")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Overlap Status", "melee")
    _expect(profile != null, "overlap status fixture creates profile")
    if profile == null:
        quit(1)
        return

    var floor := _floor_state(4, 44093)
    _expect(floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "overlap status fixture commits Floor 4")
    if floor == null:
        quit(1)
        return

    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    _expect(bool(build.get("accepted", false)) and bool(arrival.get("accepted", false)), "overlap status fixture builds live Floor 4")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame
    _expect(
        gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": build.get("root"), "arrival": arrival}),
        "overlap status fixture activates Tower floor"
    )
    gameplay.tower_encounter_session_host.set_physics_process(false)

    var plan := {
        "plan_id": &"encounter_plan:overlap_player_status",
        "floor_id": 4,
        "complete_floor_plan": false,
        "placements": [
            _placement(&"enemy:overlap_status_a", &"duelist", &"encounter:overlap_status_a", Vector2i(2, 2)),
            _placement(&"enemy:overlap_status_b", &"marksman", &"encounter:overlap_status_b", Vector2i(3, 2)),
        ],
    }
    var enemy_states := {
        &"enemy:overlap_status_a": _combatant(&"enemy:overlap_status_a", 20),
        &"enemy:overlap_status_b": _combatant(&"enemy:overlap_status_b", 20),
    }

    var player_a := PlayerCombatantRuntimeBinding.create_state(
        gameplay.player,
        gameplay.combat_runtime,
        PLAYER_COMBAT_TUNING,
        &"player:local"
    )
    _expect(player_a != null, "first live player encounter state creates")
    var activate_a := gameplay.activate_tower_encounter(
        plan,
        &"encounter:overlap_status_a",
        player_a,
        enemy_states
    )
    _expect(bool(activate_a.get("accepted", false)), "first overlapping encounter activates")
    var encounter_a := gameplay.tower_encounter_session_host.get_encounter_runtime(&"encounter:overlap_status_a")
    _expect(encounter_a != null, "first overlapping encounter runtime is live")
    if encounter_a == null:
        gameplay.queue_free()
        await process_frame
        quit(1)
        return

    _expect(bool(encounter_a.apply_status_to_target(&"player:local", {
        "status_id": &"burn:overlap_status",
        "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
        "magnitude": 2.0,
        "duration_ticks": 90,
    }).get("accepted", false)), "first encounter applies supported Burn")
    _expect(bool(encounter_a.advance_status_ticks(30).get("accepted", false)), "first encounter advances Burn to a live 60-tick remainder")
    _expect(_remaining(encounter_a.get_status_states(&"player:local"), &"burn:overlap_status") == 60, "first encounter owns exact 60-tick Burn remainder")

    _expect(gameplay.combat_runtime.store_status_safe_states([{
        "status_id": &"burn:overlap_status",
        "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
        "magnitude": 2.0,
        "remaining_ticks": 90,
    }]), "fixture seeds an intentionally stale class safe-state duration")
    var player_b := PlayerCombatantRuntimeBinding.create_state(
        gameplay.player,
        gameplay.combat_runtime,
        PLAYER_COMBAT_TUNING,
        &"player:local"
    )
    _expect(player_b != null and _remaining(player_b.get_status_states(), &"burn:overlap_status") == 90, "second state initially imports the intentionally stale safe-state duration")

    var activate_b := gameplay.activate_tower_encounter(
        plan,
        &"encounter:overlap_status_b",
        player_b,
        enemy_states
    )
    _expect(bool(activate_b.get("accepted", false)), "second overlapping encounter activates")
    var encounter_b := gameplay.tower_encounter_session_host.get_encounter_runtime(&"encounter:overlap_status_b")
    _expect(encounter_b != null, "second overlapping encounter runtime is live")
    if encounter_b == null:
        gameplay.queue_free()
        await process_frame
        quit(1)
        return

    _expect(
        _remaining(encounter_b.get_status_states(&"player:local"), &"burn:overlap_status") == 60,
        "new overlapping encounter takes current live Burn duration instead of resurrecting stale safe-state ticks"
    )
    _expect(bool(encounter_b.apply_status_to_target(&"player:local", {
        "status_id": &"slow:overlap_status",
        "behavior": PrototypeStatusResolver.BEHAVIOR_SLOW,
        "magnitude": 0.25,
        "duration_ticks": 75,
    }).get("accepted", false)), "second encounter applies supported Slow")

    _expect(bool(gameplay.call("_sync_overlapping_player_status_states")), "GameplayRoot synchronizes player statuses across overlapping encounter owners")
    var states_a := encounter_a.get_status_states(&"player:local")
    var states_b := encounter_b.get_status_states(&"player:local")
    _expect(
        _remaining(states_a, &"burn:overlap_status") == 60
        and _remaining(states_b, &"burn:overlap_status") == 60
        and _remaining(states_a, &"slow:overlap_status") == 75
        and _remaining(states_b, &"slow:overlap_status") == 75,
        "both encounter owners converge on the same Burn/Slow state without inventing aggregation semantics"
    )

    _expect(
        gameplay.player.runtime_presentation_binder.bound_runtime == encounter_a,
        "first encounter initially owns player runtime presentation"
    )
    _expect(gameplay.end_tower_encounter(&"encounter:overlap_status_a"), "first overlapping encounter ends normally")
    _expect(
        gameplay.player.runtime_presentation_binder.bound_runtime == encounter_b,
        "player runtime presentation transfers to the surviving encounter before the original owner closes"
    )
    _expect(
        _remaining(encounter_b.get_status_states(&"player:local"), &"burn:overlap_status") == 60
        and _remaining(encounter_b.get_status_states(&"player:local"), &"slow:overlap_status") == 75,
        "surviving encounter retains the complete synchronized player status state"
    )

    _expect(gameplay.end_tower_encounter(&"encounter:overlap_status_b"), "final overlapping encounter ends normally")
    var safe_statuses := gameplay.combat_runtime.get_status_safe_states()
    _expect(
        _remaining(safe_statuses, &"burn:overlap_status") == 60
        and _remaining(safe_statuses, &"slow:overlap_status") == 75,
        "final encounter teardown hands the complete coherent status set to the safe-state owner"
    )
    _expect(
        gameplay.player.runtime_presentation_binder.bound_runtime == null,
        "player runtime presentation unbinds only after the final encounter closes"
    )

    gameplay.queue_free()
    await process_frame

    if _failures == 0:
        print("GAMEPLAY OVERLAPPING PLAYER STATUS COHERENCE TEST PASS")
    else:
        push_error("GAMEPLAY OVERLAPPING PLAYER STATUS COHERENCE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        seed,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:overlap_player_status"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:overlap_player_status_%d_%d" % [floor_id, seed]),
        manifest
    )


func _placement(actor_id: StringName, archetype_id: StringName, encounter_id: StringName, local_tile: Vector2i) -> Dictionary:
    return {
        "actor_id": actor_id,
        "archetype_id": archetype_id,
        "encounter_id": encounter_id,
        "room_instance_id": &"room:objective_00",
        "local_tile": local_tile,
        "elite": false,
    }


func _combatant(actor_id: StringName, hp: int) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    if not state.configure(actor_id, hp, 100.0, 0.0, 0.0, 10.0, true, false, false):
        return null
    return state


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
