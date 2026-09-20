extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_plan_validation()
    _test_runtime_activation_and_persistent_defeat()
    _test_shared_cap_across_activated_tower_encounters()
    if _failures == 0:
        print("TOWER ENCOUNTER RUNTIME FACTORY TEST PASS")
    else:
        push_error("TOWER ENCOUNTER RUNTIME FACTORY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_plan_validation() -> void:
    var floor1 := _floor_state(1, 11001)
    var valid := _plan(1, [
        _placement(&"enemy:f1_duelist", &"duelist", &"encounter:f1_main", &"room:objective_00", Vector2i(2, 2), false),
        _placement(&"enemy:f1_marksman", &"marksman", &"encounter:f1_main", &"room:objective_00", Vector2i(3, 2), false),
    ], true)
    _expect(TowerEncounterPlanValidator.validate(valid, floor1).is_empty(), "complete Floor 1 encounter plan validates inside authored spawn regions")
    var world_tile: Variant = TowerEncounterPlanValidator.world_tile_for_placement(floor1, valid["placements"][0])
    _expect(world_tile is Vector2i and (world_tile as Vector2i) == Vector2i(14, 20), "encounter placement resolves from room-local tile into committed floor-world tile")

    var duplicate := valid.duplicate(true)
    duplicate["placements"][1]["actor_id"] = &"enemy:f1_duelist"
    _expect(_contains(TowerEncounterPlanValidator.validate(duplicate, floor1), "duplicates actor_id"), "encounter plan rejects duplicate persistent actor identity")

    var blocked := valid.duplicate(true)
    blocked["placements"][0]["local_tile"] = Vector2i(0, 0)
    _expect(_contains(TowerEncounterPlanValidator.validate(blocked, floor1), "authored spawn region"), "encounter plan rejects placement outside authored spawn region")

    var floor5 := _floor_state(5, 55005)
    var wrong_elites := _plan(5, [
        _placement(&"enemy:f5_elite_a", &"bruiser", &"encounter:f5_elites", &"room:objective_00", Vector2i(2, 2), true),
        _placement(&"enemy:f5_elite_b", &"defender", &"encounter:f5_elites", &"room:objective_00", Vector2i(3, 2), true),
    ], true)
    _expect(_contains(TowerEncounterPlanValidator.validate(wrong_elites, floor5), "elite count"), "complete Floor 5 plan enforces exactly the approved three-elite target")

    var floor2 := _floor_state(2, 22002)
    var crowd: Array = []
    for index: int in range(13):
        var x := 2 + (index % 6)
        var y := 2 + (index / 6)
        crowd.append(_placement(
            StringName("enemy:f2_crowd_%02d" % index),
            &"skirmisher",
            &"encounter:f2_overcap",
            &"room:objective_00",
            Vector2i(x, y),
            false
        ))
    var overcap := _plan(2, crowd, false)
    _expect(_contains(TowerEncounterPlanValidator.validate(overcap, floor2), "simultaneous FULL-AI cap"), "one activation group cannot encode thirteen simultaneous FULL-AI enemies even when floor population budget allows it")

func _test_runtime_activation_and_persistent_defeat() -> void:
    var floor1 := _floor_state(1, 11101)
    var plan := _plan(1, [
        _placement(&"enemy:f1_runtime_duelist", &"duelist", &"encounter:f1_runtime", &"room:objective_00", Vector2i(2, 2), false),
        _placement(&"enemy:f1_runtime_marksman", &"marksman", &"encounter:f1_runtime", &"room:objective_00", Vector2i(3, 2), false),
    ], true)
    var player := _combatant(&"player:tower_runtime")
    var states := {
        &"enemy:f1_runtime_duelist": _combatant(&"enemy:f1_runtime_duelist"),
        &"enemy:f1_runtime_marksman": _combatant(&"enemy:f1_runtime_marksman"),
    }
    var shared_combat := ActiveCombatRegistry.new()
    var shared_full_ai := FullAiSimulationLedger.new()
    var result := TowerEncounterRuntimeFactory.activate(
        floor1, plan, &"encounter:f1_runtime", player, states, shared_combat, shared_full_ai
    )
    _expect(bool(result.get("accepted", false)) and not bool(result.get("resolved", false)), "validated tower encounter activates into live combat runtime")
    var encounter := result.get("encounter_runtime") as CombatEncounterRuntime
    _expect(encounter != null and encounter.get_active_enemy_count() == 2, "live tower encounter registers exactly the authored active placements")
    _expect(shared_full_ai.get_admitted_count() == 2, "tower encounter consumes the shared FULL-AI ledger")
    var runtimes := result.get("archetype_runtimes", {}) as Dictionary
    _expect(runtimes.size() == 2, "each activated placement receives a configured archetype runtime")
    for actor_variant: Variant in runtimes.keys():
        var runtime := runtimes[actor_variant] as EnemyArchetypeRuntime
        _expect(runtime != null and runtime.is_configured(), "archetype runtime is configured for %s" % String(actor_variant))
    if encounter != null:
        encounter.end_encounter()

    _expect(floor1.mark_actor_defeated(&"enemy:f1_runtime_duelist"), "persistent floor state records an authored enemy defeat")
    var revisit_states := {&"enemy:f1_runtime_marksman": _combatant(&"enemy:f1_runtime_marksman")}
    var revisit := TowerEncounterRuntimeFactory.activate(
        floor1, plan, &"encounter:f1_runtime", player, revisit_states, shared_combat, shared_full_ai
    )
    _expect(bool(revisit.get("accepted", false)), "ordinary revisit can reactivate unresolved members of the same encounter")
    _expect((revisit.get("skipped_defeated_actor_ids", []) as Array).has(&"enemy:f1_runtime_duelist"), "ordinary revisit never respawns a persistently defeated resident")
    var revisit_encounter := revisit.get("encounter_runtime") as CombatEncounterRuntime
    _expect(revisit_encounter != null and revisit_encounter.get_active_enemy_count() == 1, "revisit activates only the unresolved authored resident")
    if revisit_encounter != null:
        revisit_encounter.end_encounter()

    _expect(floor1.mark_actor_defeated(&"enemy:f1_runtime_marksman"), "second persistent defeat records")
    var resolved := TowerEncounterRuntimeFactory.activate(
        floor1, plan, &"encounter:f1_runtime", player, {}, shared_combat, shared_full_ai
    )
    _expect(bool(resolved.get("accepted", false)) and bool(resolved.get("resolved", false)) and resolved.get("encounter_runtime") == null, "fully defeated encounter stays resolved on revisit without creating a combat runtime")

func _test_shared_cap_across_activated_tower_encounters() -> void:
    var floor2 := _floor_state(2, 22201)
    var placements_a: Array = []
    var placements_b: Array = []
    var states: Dictionary = {}
    for index: int in range(6):
        var actor_a := StringName("enemy:tower_overlap_a_%02d" % index)
        var actor_b := StringName("enemy:tower_overlap_b_%02d" % index)
        placements_a.append(_placement(actor_a, &"duelist", &"encounter:tower_overlap_a", &"room:objective_00", Vector2i(2 + index, 2), false))
        placements_b.append(_placement(actor_b, &"marksman", &"encounter:tower_overlap_b", &"room:objective_00", Vector2i(2 + index, 3), false))
        states[actor_a] = _combatant(actor_a)
        states[actor_b] = _combatant(actor_b)
    var plan := _plan(2, placements_a + placements_b, false)
    var player_a := _combatant(&"player:tower_overlap_a")
    var player_b := _combatant(&"player:tower_overlap_b")
    var shared_combat := ActiveCombatRegistry.new()
    var shared_full_ai := FullAiSimulationLedger.new()
    var first := TowerEncounterRuntimeFactory.activate(floor2, plan, &"encounter:tower_overlap_a", player_a, states, shared_combat, shared_full_ai)
    var second := TowerEncounterRuntimeFactory.activate(floor2, plan, &"encounter:tower_overlap_b", player_b, states, shared_combat, shared_full_ai)
    _expect(bool(first.get("accepted", false)) and bool(second.get("accepted", false)), "two six-enemy tower encounters may overlap at exactly the global cap")
    _expect(shared_full_ai.get_admitted_count() == 12, "overlapping tower encounter factory instances share exactly twelve FULL-AI admissions")
    var first_runtime := first.get("encounter_runtime") as CombatEncounterRuntime
    var second_runtime := second.get("encounter_runtime") as CombatEncounterRuntime
    if first_runtime != null:
        first_runtime.end_encounter()
    if second_runtime != null:
        second_runtime.end_encounter()

func _floor_state(floor_id: int, seed: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id, seed, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:encounter_factory_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:encounter_factory_%d_%d" % [floor_id, seed]), manifest
    )
    _expect(state != null, "Floor %d encounter fixture builds from validated fallback" % floor_id)
    return state

func _plan(floor_id: int, placements: Array, complete: bool) -> Dictionary:
    return {
        "plan_id": StringName("encounter_plan:floor_%d_fixture_%d" % [floor_id, placements.size()]),
        "floor_id": floor_id,
        "complete_floor_plan": complete,
        "placements": placements,
    }

func _placement(
    actor_id: StringName,
    archetype_id: StringName,
    encounter_id: StringName,
    room_id: StringName,
    local_tile: Vector2i,
    elite: bool
) -> Dictionary:
    return {
        "actor_id": actor_id,
        "archetype_id": archetype_id,
        "encounter_id": encounter_id,
        "room_instance_id": room_id,
        "local_tile": local_tile,
        "elite": elite,
    }

func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 10.0, true, false, false), "combatant fixture configures: %s" % String(actor_id))
    return state

func _contains(errors: PackedStringArray, needle: String) -> bool:
    for error: String in errors:
        if error.contains(needle):
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
