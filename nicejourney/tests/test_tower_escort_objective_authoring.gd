extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_primary_escort_floors()
    _test_non_escort_and_bad_binding_reject()
    if _failures == 0:
        print("TOWER ESCORT OBJECTIVE AUTHORING TEST PASS")
    else:
        push_error("TOWER ESCORT OBJECTIVE AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_primary_escort_floors() -> void:
    for floor_id: int in [2, 6, 8]:
        var quest_id := StringName("primary_floor_%d" % floor_id)
        var request := TowerFloorGenerationCommitService.build_request(
            floor_id,
            5000 + floor_id,
            TowerGenerationIdentityFactory.GENERATOR_VERSION,
            TowerGenerationIdentityFactory.MODULE_CONTENT_VERSION,
            TowerGenerationIdentityFactory.ENCOUNTER_CONFIG_ID,
            &"quest_flags:escort_authoring_test"
        )
        var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
        _expect(not manifest.is_empty(), "Floor %d fallback manifest builds for escort authoring" % floor_id)
        var floor := _state_from_manifest(floor_id, manifest)
        var authored := TowerEscortObjectiveAuthoring.build(floor, quest_id)
        _expect(not authored.is_empty(), "Floor %d primary escort derives deterministic authored objective data" % floor_id)
        if authored.is_empty():
            continue
        _expect(StringName(authored.get("content_status", &"")) == TowerEscortObjectiveAuthoring.CONTENT_STATUS, "Floor %d escort authoring stays explicitly playtest-placeholder content" % floor_id)
        var config := authored.get("objective_config", {}) as Dictionary
        var route_ids := config.get("route_node_ids", []) as Array
        var waypoints := authored.get("waypoints", []) as Array
        _expect(not route_ids.is_empty() and route_ids.size() == waypoints.size(), "Floor %d escort route IDs correspond one-to-one with physical authored waypoints" % floor_id)
        _expect(StringName(config.get("failure_policy_id", &"")) == TowerEscortObjectiveAuthoring.FAILURE_POLICY_ACTOR_DEFEAT, "Floor %d escort uses explicit actor-defeat failure policy identity" % floor_id)
        _expect(authored.get("safe_retry_world_tile", Vector2i(-1, -1)) == authored.get("spawn_world_tile", Vector2i.ZERO), "Floor %d safe retry origin resolves to the authored entrance-route spawn tile" % floor_id)
        var objective := EscortObjectiveState.new()
        _expect(objective.configure(
            StringName(config.get("actor_id", &"")),
            _names(route_ids),
            StringName(config.get("goal_id", &"")),
            StringName(config.get("safe_retry_origin_id", &"")),
            StringName(config.get("failure_policy_id", &""))
        ), "Floor %d derived escort config satisfies the authoritative objective state contract" % floor_id)
        _expect((authored.get("room_path", []) as Array)[0] == &"room:entrance", "Floor %d escort route starts from the committed entrance room" % floor_id)
        _expect((authored.get("room_path", []) as Array)[-1] == StringName(String((manifest.get("objective_bindings", {}) as Dictionary)[String(quest_id)])), "Floor %d escort route terminates at its reserved objective room" % floor_id)


func _test_non_escort_and_bad_binding_reject() -> void:
    var request := TowerFloorGenerationCommitService.build_request(
        4, 5004, TowerGenerationIdentityFactory.GENERATOR_VERSION, TowerGenerationIdentityFactory.MODULE_CONTENT_VERSION,
        TowerGenerationIdentityFactory.ENCOUNTER_CONFIG_ID, &"quest_flags:escort_authoring_non_escort"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var floor := _state_from_manifest(4, manifest)
    _expect(TowerEscortObjectiveAuthoring.build(floor, &"primary_floor_4").is_empty(), "non-Escort objective cannot obtain escort authoring")

    request = TowerFloorGenerationCommitService.build_request(
        2, 5002, TowerGenerationIdentityFactory.GENERATOR_VERSION, TowerGenerationIdentityFactory.MODULE_CONTENT_VERSION,
        TowerGenerationIdentityFactory.ENCOUNTER_CONFIG_ID, &"quest_flags:escort_authoring_missing_binding"
    )
    manifest = TowerPrevalidatedFallbackFactory.build_for_request(request)
    floor = _state_from_manifest(2, manifest)
    floor.layout_manifest["objective_bindings"] = {}
    _expect(TowerEscortObjectiveAuthoring.build(floor, &"primary_floor_2").is_empty(), "escort authoring fails closed when the committed manifest lacks its reserved objective binding")


func _state_from_manifest(floor_id: int, manifest: Dictionary) -> FloorInstanceState:
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:escort_authoring_f%02d" % floor_id),
        manifest
    )


func _names(values: Array) -> Array[StringName]:
    var result: Array[StringName] = []
    for value: Variant in values:
        result.append(StringName(String(value)))
    return result


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
