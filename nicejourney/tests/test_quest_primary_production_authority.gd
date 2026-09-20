extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_floor_2_through_10_production_authority()
    _test_locked_floor_population_and_boss_facts()
    _test_escort_production_authoring()
    _test_no_floor_11_authority()
    if _failures == 0:
        print("QUEST PRIMARY PRODUCTION AUTHORITY TEST PASS")
    else:
        push_error("QUEST PRIMARY PRODUCTION AUTHORITY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_floor_2_through_10_production_authority() -> void:
    for floor_id: int in range(2, 11):
        var definition := QuestCatalog.get_definition(StringName("primary_floor_%d" % floor_id))
        _expect(definition != null, "Floor %d has a primary definition" % floor_id)
        if definition == null:
            continue

        var status := QuestCatalog.primary_production_status(floor_id)
        var authority := status.get("objective_authority", {}) as Dictionary
        var known := authority.get("known_semantics", {}) as Dictionary
        _expect(bool(authority.get("accepted", false)), "Floor %d production authority recognizes the definition" % floor_id)
        _expect(bool(status.get("production_ready", false)), "Floor %d primary production contract is ready" % floor_id)
        _expect(not bool(status.get("playtest_placeholder", true)), "Floor %d primary definition is production-v01 rather than placeholder" % floor_id)
        _expect((status.get("unauthored_contract_fields", PackedStringArray()) as PackedStringArray).is_empty(), "Floor %d has no missing quest-contract fields" % floor_id)
        _expect((status.get("objective_missing_authoritative_fields", PackedStringArray()) as PackedStringArray).is_empty(), "Floor %d has no missing quest-objective authority fields" % floor_id)
        _expect((status.get("objective_external_runtime_missing_authoritative_fields", PackedStringArray()) as PackedStringArray).is_empty(), "Floor %d primary contract has no external authority blocker" % floor_id)
        _expect(StringName(known.get("floor_family_allocation_status", &"")) == PrimaryQuestProductionAuthority.CONTENT_STATUS_PRODUCTION_V01, "Floor %d family allocation is explicitly production-v01" % floor_id)
        _expect(StringName(known.get("required_objective_id", &"")) == PrimaryQuestProductionV01.required_objective_id(floor_id, definition.family), "Floor %d exposes its exact required objective identity" % floor_id)
        _expect(definition.prerequisite_ids == [PrimaryQuestProductionV01.unlocked_fact_id(floor_id)], "Floor %d production acceptance is gated by its floor-unlock fact" % floor_id)


func _test_locked_floor_population_and_boss_facts() -> void:
    for floor_id: int in [5, 10]:
        var authority := QuestCatalog.primary_production_status(floor_id).get("objective_authority", {}) as Dictionary
        var known := authority.get("known_semantics", {}) as Dictionary
        _expect(int(known.get("floor_population_required_elite_count", 0)) == 3, "Floor %d preserves the locked three-elite floor-population fact" % floor_id)
        _expect(bool(authority.get("production_ready", false)), "Floor %d production authority remains ready with the locked elite population" % floor_id)

    var floor10 := QuestCatalog.primary_production_status(10).get("objective_authority", {}) as Dictionary
    var floor10_known := floor10.get("known_semantics", {}) as Dictionary
    _expect(bool(floor10_known.get("boss_required", false)), "Floor 10 preserves the approved boss requirement")
    _expect(StringName(floor10_known.get("boss_actor_id", &"")) == PrimaryQuestProductionAuthority.TENTH_WARDEN_ACTOR_ID, "Floor 10 preserves the stable Tenth Warden boss identity")
    _expect(not bool(floor10_known.get("floor_11_permitted", true)), "Floor 10 production authority explicitly forbids Floor 11")


func _test_escort_production_authoring() -> void:
    for floor_id: int in [2, 6, 8]:
        var request := TowerFloorGenerationCommitService.build_request(
            floor_id,
            7200 + floor_id,
            TowerGenerationIdentityFactory.GENERATOR_VERSION,
            TowerGenerationIdentityFactory.MODULE_CONTENT_VERSION,
            TowerGenerationIdentityFactory.ENCOUNTER_CONFIG_ID,
            &"quest_flags:production_authority_test"
        )
        var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
        var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(
            StringName("floor_instance:production_authority_f%02d" % floor_id),
            manifest
        )
        _expect(floor != null, "Floor %d fixture creates a valid committed floor state" % floor_id)
        if floor == null:
            continue

        var quest_id := StringName("primary_floor_%d" % floor_id)
        var readiness := TowerEscortObjectiveAuthoring.production_readiness(floor, quest_id)
        _expect(bool(readiness.get("accepted", false)), "Floor %d Escort production-readiness boundary accepts production authoring" % floor_id)
        _expect(bool(readiness.get("production_ready", false)), "Floor %d Escort quest authoring reports production-ready" % floor_id)
        _expect(StringName(readiness.get("content_status", &"")) == TowerEscortObjectiveAuthoring.PRODUCTION_V01_CONTENT_STATUS, "Floor %d Escort content is explicitly production-v01" % floor_id)
        _expect(bool(readiness.get("production_config_available", false)), "Floor %d exposes its production Escort config" % floor_id)
        var config := readiness.get("production_config", {}) as Dictionary
        _expect(StableId.is_valid(String(config.get("actor_id", &""))), "Floor %d Escort owns a stable actor identity" % floor_id)
        _expect(not (config.get("route_node_ids", []) as Array).is_empty(), "Floor %d Escort owns a non-empty validated route" % floor_id)
        _expect(StringName(config.get("failure_policy_id", &"")) == TowerEscortObjectiveAuthoring.FAILURE_POLICY_ACTOR_DEFEAT, "Floor %d Escort owns the production actor-defeat failure policy" % floor_id)


func _test_no_floor_11_authority() -> void:
    var status := QuestCatalog.primary_production_status(11)
    var authority := status.get("objective_authority", {}) as Dictionary
    _expect(StringName(status.get("quest_id", &"")) == &"", "Floor 11 has no quest identity")
    _expect(not bool(authority.get("accepted", true)), "Floor 11 has no objective production authority")
    _expect(not bool(status.get("production_ready", true)), "Floor 11 cannot become production-ready")


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
