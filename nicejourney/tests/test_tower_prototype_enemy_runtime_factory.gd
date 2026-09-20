extends SceneTree

const ENEMY_TUNING: TowerPrototypeEnemyRuntimeTuning = preload("res://src/data/tuning/tower_prototype_enemy_runtime_default.tres")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_floor_scaled_states()
    _test_live_elite_encounter_activation(5)
    _test_live_elite_encounter_activation(10)
    if _failures == 0:
        print("TOWER PROTOTYPE ENEMY RUNTIME FACTORY TEST PASS")
    else:
        push_error("TOWER PROTOTYPE ENEMY RUNTIME FACTORY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_floor_scaled_states() -> void:
    _expect(ENEMY_TUNING.validate_tuning().is_empty(), "default prototype enemy runtime tuning validates")
    var floor1 := _floor_state(1)
    var plan1 := TowerPrototypeEncounterContentCatalog.build_plan(floor1)
    var states1 := TowerPrototypeEnemyRuntimeFactory.build_states(floor1, plan1, ENEMY_TUNING)
    _expect(states1.size() == (plan1.get("placements", []) as Array).size(), "Floor 1 runtime factory realizes every authored placement")
    var first1 := states1.values()[0] as CombatantRuntimeState
    _expect(first1 != null and first1.max_hp == ENEMY_TUNING.base_hp, "Floor 1 resident uses explicit base HP tuning")

    var floor5 := _floor_state(5)
    var plan5 := TowerPrototypeEncounterContentCatalog.build_plan(floor5)
    var states5 := TowerPrototypeEnemyRuntimeFactory.build_states(floor5, plan5, ENEMY_TUNING)
    _expect(states5.size() == (plan5.get("placements", []) as Array).size(), "Floor 5 runtime factory realizes every authored placement")
    var expected_normal_hp := ENEMY_TUNING.base_hp + ENEMY_TUNING.hp_per_floor * 4
    var elite_count := 0
    for raw_placement: Variant in plan5.get("placements", []) as Array:
        var placement := raw_placement as Dictionary
        var actor_id := StringName(String(placement["actor_id"]))
        var state := states5.get(actor_id) as CombatantRuntimeState
        _expect(state != null, "runtime state exists for %s" % String(actor_id))
        if state == null:
            continue
        if bool(placement.get("elite", false)):
            elite_count += 1
            _expect(state.max_hp == roundi(float(expected_normal_hp) * ENEMY_TUNING.elite_hp_multiplier), "elite %s receives explicit HP modifier" % String(actor_id))
            _expect(is_equal_approx(state.physical_defense, ENEMY_TUNING.base_physical_defense + ENEMY_TUNING.elite_defense_bonus), "elite %s receives explicit physical-defense modifier" % String(actor_id))
            _expect(is_equal_approx(state.arcane_defense, ENEMY_TUNING.base_arcane_defense + ENEMY_TUNING.elite_defense_bonus), "elite %s receives explicit Arcane-defense modifier" % String(actor_id))
            var expected_poise := (ENEMY_TUNING.base_poise_threshold + ENEMY_TUNING.poise_per_floor * 4.0) * ENEMY_TUNING.elite_poise_multiplier
            _expect(is_equal_approx(state.poise_threshold, expected_poise), "elite %s receives explicit poise modifier" % String(actor_id))
        else:
            _expect(state.max_hp == expected_normal_hp, "normal %s uses floor-authored HP scaling only" % String(actor_id))
        var archetype_id := StringName(String(placement["archetype_id"]))
        _expect(state.block_supported == (archetype_id == &"defender"), "only Defender state exposes its authored frontal-guard capability")
        _expect(not state.parry_supported, "reusable enemy runtime does not invent a parry subsystem")
    _expect(elite_count == 3, "Floor 5 runtime data preserves exactly three elite modifiers")

func _test_live_elite_encounter_activation(floor_id: int) -> void:
    var floor := _floor_state(floor_id)
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor)
    var states := TowerPrototypeEnemyRuntimeFactory.build_states(floor, plan, ENEMY_TUNING)
    var elite_encounter_id: StringName = &""
    for raw_placement: Variant in plan.get("placements", []) as Array:
        var placement := raw_placement as Dictionary
        if bool(placement.get("elite", false)):
            elite_encounter_id = StringName(String(placement.get("encounter_id", &"")))
            break
    _expect(elite_encounter_id != &"", "Floor %d exposes an encounter containing the three required elites" % floor_id)
    if elite_encounter_id == &"":
        return
    var active := ActiveCombatRegistry.new()
    var full_ai := FullAiSimulationLedger.new()
    var pressure := AttackPressureLedger.new()
    var player := CombatantRuntimeState.new()
    _expect(player.configure(StringName("player:elite_runtime_f%02d" % floor_id), 100, 100.0, 0.0, 0.0, 20.0, true, false, false), "Floor %d elite activation player validates" % floor_id)
    var activation := TowerEncounterRuntimeFactory.activate(
        floor,
        plan,
        elite_encounter_id,
        player,
        states,
        active,
        full_ai,
        pressure
    )
    _expect(bool(activation.get("accepted", false)) and not bool(activation.get("resolved", true)), "Floor %d elite encounter activates through the normal runtime owner" % floor_id)
    if not bool(activation.get("accepted", false)):
        return
    var placements := activation.get("placements", []) as Array
    var elite_count := 0
    for raw_placement: Variant in placements:
        var placement := raw_placement as Dictionary
        if bool(placement.get("elite", false)):
            elite_count += 1
        _expect(StringName(String(placement.get("room_instance_id", &""))) != &"room:boss", "Floor %d reusable encounter resident stays outside the boss-owned Sanctum" % floor_id)
    _expect(elite_count == 3, "Floor %d activated encounter preserves exactly the approved three elite identities" % floor_id)
    _expect(full_ai.get_admitted_count() == placements.size() and full_ai.get_admitted_count() <= FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS, "Floor %d every active resident, elite or normal, consumes one ordinary FULL-AI slot under the global cap" % floor_id)
    _expect(pressure.get_active_count() == 0, "Floor %d elite identity alone does not fabricate committed attack pressure" % floor_id)
    var encounter := activation.get("encounter_runtime") as CombatEncounterRuntime
    if encounter != null:
        encounter.end_encounter()
    _expect(full_ai.get_admitted_count() == 0, "Floor %d elite encounter exit releases its counted FULL-AI ownership" % floor_id)

func _floor_state(floor_id: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        91000 + floor_id,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:runtime_tuning_v01",
        StringName("quest_flags:enemy_runtime_f%02d" % floor_id)
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:enemy_runtime_f%02d" % floor_id),
        manifest
    )

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
