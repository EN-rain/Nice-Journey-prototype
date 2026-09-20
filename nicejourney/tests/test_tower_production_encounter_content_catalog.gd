extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_all_production_floor_plans()
    _test_family_objective_configs()
    if _failures == 0:
        print("TOWER PRODUCTION ENCOUNTER CONTENT CATALOG TEST PASS")
    else:
        push_error("TOWER PRODUCTION ENCOUNTER CONTENT CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_all_production_floor_plans() -> void:
    for floor_id: int in range(2, 11):
        var floor := _floor_state(floor_id)
        _expect(floor != null, "Floor %d production encounter fixture builds" % floor_id)
        if floor == null:
            continue
        var first := TowerProductionEncounterContentCatalog.build_plan(floor)
        var second := TowerProductionEncounterContentCatalog.build_plan(floor)
        _expect(not first.is_empty() and first == second, "Floor %d production-v01 encounter plan is deterministic" % floor_id)
        _expect(StringName(first.get("content_status", &"")) == TowerProductionEncounterContentCatalog.CONTENT_STATUS, "Floor %d plan is tagged production-v01" % floor_id)
        _expect(TowerEncounterPlanValidator.validate(first, floor).is_empty(), "Floor %d production plan satisfies encounter validation" % floor_id)
        var placements := first.get("placements", []) as Array
        _expect(placements.size() == int(TowerProductionEncounterContentCatalog.REUSABLE_ENEMY_TARGETS[floor_id]), "Floor %d uses the explicit production-v01 resident count" % floor_id)
        var elite_count := 0
        for raw: Variant in placements:
            var placement := raw as Dictionary
            if bool(placement.get("elite", false)):
                elite_count += 1
            if floor_id == 10:
                _expect(StringName(placement.get("room_instance_id", &"")) != &"room:boss", "Floor 10 reusable residents remain outside the no-add Boss Sanctum")
        _expect(elite_count == int(PrototypeTowerFloorCatalog.get_entry(floor_id).get("elite_target", 0)), "Floor %d production plan preserves the approved elite count" % floor_id)
        _expect(TowerProductionEncounterContentCatalog.validate_floor_content(floor).is_empty(), "Floor %d production content passes its dedicated validator" % floor_id)


func _test_family_objective_configs() -> void:
    for floor_id: int in range(2, 10):
        var floor := _floor_state(floor_id)
        if floor == null:
            continue
        var quest_id := StringName("primary_floor_%d" % floor_id)
        var definition := QuestCatalog.get_definition(quest_id)
        var plan := TowerProductionEncounterContentCatalog.build_plan(floor)
        var configs := TowerProductionEncounterContentCatalog.objective_configs(floor, plan)
        _expect(configs.has(quest_id), "Floor %d production plan owns its primary objective config" % floor_id)
        if not configs.has(quest_id) or definition == null:
            continue
        var config := configs[quest_id] as Dictionary
        match definition.family:
            QuestDefinition.FAMILY_ANNIHILATION:
                _expect(not (config.get("required_actor_ids", []) as Array).is_empty(), "Floor %d Annihilation owns explicit required resident IDs" % floor_id)
                var bindings := TowerProductionEncounterContentCatalog.quest_bindings_by_actor(floor, plan)
                _expect(_binding_count(bindings, quest_id) > 0, "Floor %d required resident defeats bind to the primary Annihilation objective" % floor_id)
            QuestDefinition.FAMILY_TOWER_DEFENSE:
                _expect(StringName(config.get("objective_id", &"")) == definition.required_objective_ids[0], "Floor %d Tower Defense uses the primary required objective identity" % floor_id)
                _expect(int(config.get("objective_max_hp", 0)) == TowerProductionEncounterContentCatalog.DEFENSE_OBJECTIVE_MAX_HP, "Floor %d Tower Defense uses production-v01 objective HP" % floor_id)
                var waves := config.get("required_actor_ids_by_wave", {}) as Dictionary
                _expect(waves.size() == 1 and not (waves.values()[0] as Array).is_empty(), "Floor %d Tower Defense owns one explicit required production wave" % floor_id)
            QuestDefinition.FAMILY_ESCORT:
                _expect(StringName(config.get("content_status", &"")) == TowerProductionEncounterContentCatalog.CONTENT_STATUS, "Floor %d Escort config is tagged production-v01" % floor_id)
                _expect(StableId.is_valid(String(config.get("actor_id", &""))) and not (config.get("route_node_ids", []) as Array).is_empty(), "Floor %d Escort owns explicit actor and route identities" % floor_id)
                var bindings := TowerProductionEncounterContentCatalog.quest_bindings_by_actor(floor, plan)
                _expect(_binding_count(bindings, quest_id) == 0, "Floor %d generic resident defeats cannot progress Escort" % floor_id)

    var floor10 := _floor_state(10)
    var plan10 := TowerProductionEncounterContentCatalog.build_plan(floor10)
    _expect(not TowerProductionEncounterContentCatalog.objective_configs(floor10, plan10).has(&"primary_floor_10"), "Floor 10 generic residents do not steal Tenth Warden primary ownership")


func _floor_state(floor_id: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        93000 + floor_id,
        TowerGenerationIdentityFactory.GENERATOR_VERSION,
        TowerGenerationIdentityFactory.MODULE_CONTENT_VERSION,
        TowerGenerationIdentityFactory.ENCOUNTER_CONFIG_ID,
        StringName("quest_flags:production_content_f%02d" % floor_id)
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:production_content_f%02d" % floor_id),
        manifest
    )


func _binding_count(bindings: Dictionary, quest_id: StringName) -> int:
    var count := 0
    for raw_list: Variant in bindings.values():
        if not raw_list is Array:
            continue
        for raw_binding: Variant in raw_list as Array:
            if raw_binding is Dictionary and StringName(String((raw_binding as Dictionary).get("quest_id", &""))) == quest_id:
                count += 1
    return count


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
