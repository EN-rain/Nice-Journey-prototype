extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_request_reserves_unaccepted_tower_side_quests()
    _test_candidate_validation_and_fallback()
    _test_floor10_special_contract()
    _test_no_valid_layout_never_commits_partial_manifest()
    if _failures == 0:
        print("TOWER FLOOR GENERATION COMMIT TEST PASS")
    else:
        push_error("TOWER FLOOR GENERATION COMMIT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_request_reserves_unaccepted_tower_side_quests() -> void:
    var floor4 := _request(4, 44004)
    _expect(TowerFloorGenerationCommitService.validate_request(floor4).is_empty(), "Floor 4 generation request validates")
    var floor4_ids: Array = floor4["required_quest_ids"] as Array
    _expect(floor4_ids.has(&"primary_floor_4") and floor4_ids.has(&"side_tower_floor4_escort") and floor4_ids.size() == 2, "Floor 4 reserves primary plus unaccepted side-quest socket before generation")

    var floor7 := _request(7, 77007)
    var floor7_ids: Array = floor7["required_quest_ids"] as Array
    _expect(floor7_ids.has(&"primary_floor_7") and floor7_ids.has(&"side_tower_floor7_annihilation") and floor7_ids.size() == 2, "Floor 7 reserves primary plus unaccepted side-quest socket before generation")

    var tampered := floor4.duplicate(true)
    tampered["required_quest_ids"] = [&"primary_floor_4"]
    _expect(not TowerFloorGenerationCommitService.validate_request(tampered).is_empty(), "generator cannot silently drop reserved side-quest requirements")


func _test_candidate_validation_and_fallback() -> void:
    var request := _request(1, 10101)
    var valid := _floor1_manifest(request, &"layout:floor1_valid")
    var invalid := valid.duplicate(true)
    invalid["layout_revision_id"] = "layout:floor1_invalid"
    invalid["edges"] = []

    var result: Dictionary = TowerFloorGenerationCommitService.choose_valid_manifest(request, [invalid, valid], {})
    _expect(result["accepted"] and not result["used_fallback"] and result["candidate_index"] == 1, "finite candidate sequence rejects invalid connectivity and commits the first complete valid candidate")
    _expect((result["candidate_failures"] as Array).size() == 1, "rejected candidate validation evidence is preserved")
    var returned: Dictionary = result["manifest"] as Dictionary
    returned["floor_id"] = 9
    _expect(int(valid["floor_id"]) == 1, "returned manifest is detached and cannot mutate source candidate data")

    var fallback_result: Dictionary = TowerFloorGenerationCommitService.choose_valid_manifest(request, [invalid], valid)
    _expect(fallback_result["accepted"] and fallback_result["used_fallback"] and fallback_result["candidate_index"] == -1, "compatible validated fallback is used only after deterministic candidates fail")
    var identity: Dictionary = TowerFloorGenerationCommitService.floor_state_identity_from_manifest(fallback_result["manifest"])
    _expect(identity["floor_id"] == 1 and identity["seed"] == 10101 and identity["layout_revision_id"] == &"layout:floor1_valid", "committed manifest exposes the exact persistent floor identity tuple")
    var floor_state: FloorInstanceState = TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:floor1_fixture", fallback_result["manifest"])
    _expect(floor_state != null, "validated committed manifest creates persistent floor-instance state")
    if floor_state != null:
        var stored: Dictionary = floor_state.to_dictionary()
        _expect(FloorInstanceState.validate_dictionary(stored).is_empty(), "generated floor state remains valid under persistence schema")
        _expect(not (stored["layout_manifest"] as Dictionary).is_empty(), "floor persistence stores resolved room placements/objective bindings instead of seed alone")
        var restored := FloorInstanceState.new()
        _expect(restored.load_dictionary(stored).is_empty(), "resolved layout manifest round-trips through floor persistence")
        _expect(restored.layout_manifest == floor_state.layout_manifest, "floor layout manifest survives persistence round-trip exactly")


func _test_floor10_special_contract() -> void:
    var request := _request(10, 101010)
    var valid := _floor10_manifest(request, &"layout:floor10_valid")
    var errors: PackedStringArray = TowerFloorLayoutManifestValidator.validate_manifest(valid, request)
    _expect(errors.is_empty(), "Floor 10 manifest validates with three elite capacity, one boss and direct safe pre-boss room")

    var missing_elites := valid.duplicate(true)
    var rooms: Array = missing_elites["rooms"] as Array
    for index: int in range(rooms.size()):
        var room: Dictionary = (rooms[index] as Dictionary).duplicate(true)
        if (room["tags"] as Array).has(&"elite"):
            room["elite_capacity"] = 2
            rooms[index] = room
    missing_elites["rooms"] = rooms
    _expect(_contains(TowerFloorLayoutManifestValidator.validate_manifest(missing_elites, request), "three required elites"), "Floor 10 cannot drop required elite capacity")

    var unsafe_boss := valid.duplicate(true)
    unsafe_boss["edges"] = [
        _edge(&"room:entrance", &"room:elite"),
        _edge(&"room:elite", &"room:safe"),
        _edge(&"room:elite", &"room:boss"),
        _edge(&"room:boss", &"room:exit"),
    ]
    _expect(_contains(TowerFloorLayoutManifestValidator.validate_manifest(unsafe_boss, request), "safe pre-boss"), "Floor 10 boss cannot bypass the required safe pre-boss checkpoint connection")


func _test_no_valid_layout_never_commits_partial_manifest() -> void:
    var request := _request(2, 20202)
    var invalid := _floor2_manifest(request, &"layout:floor2_invalid")
    invalid["objective_bindings"] = {}
    var mismatched_fallback := _floor2_manifest(request, &"layout:floor2_wrong_tuple")
    mismatched_fallback["generation_seed"] = 99999
    var result: Dictionary = TowerFloorGenerationCommitService.choose_valid_manifest(request, [invalid], mismatched_fallback)
    _expect(not result["accepted"] and result["reason_id"] == TowerFloorGenerationCommitService.REASON_NO_COMPATIBLE_LAYOUT, "no compatible candidate/fallback reports generation failure instead of exposing a partial floor")
    _expect((result["manifest"] as Dictionary).is_empty(), "failed generation returns no committed manifest")

    var too_many: Array = []
    for _index: int in range(TowerFloorGenerationCommitService.MAX_DETERMINISTIC_CANDIDATES + 1):
        too_many.append(invalid)
    var count_reject: Dictionary = TowerFloorGenerationCommitService.choose_valid_manifest(request, too_many, {})
    _expect(not count_reject["accepted"] and count_reject["reason_id"] == TowerFloorGenerationCommitService.REASON_INVALID_CANDIDATE_LIST, "candidate attempts remain finitely bounded at the configured eight-candidate hypothesis")


func _request(floor_id: int, seed: int) -> Dictionary:
    return TowerFloorGenerationCommitService.build_request(
        floor_id,
        seed,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:fixture"
    )


func _floor1_manifest(request: Dictionary, layout_id: StringName) -> Dictionary:
    var rooms: Array = [
        _room(&"room:entrance", &"module:entrance", Rect2i(0, 0, 6, 6), [&"entrance", &"safe"], 0, 0, true),
        _room(&"room:objective", &"module:combat_objective", Rect2i(8, 0, 8, 8), [&"combat", &"objective"], 1, 0, false),
        _room(&"room:exit", &"module:exit", Rect2i(18, 0, 6, 6), [&"exit"], 0, 0, false),
    ]
    return _manifest(request, layout_id, rooms, [
        _edge(&"room:entrance", &"room:objective"),
        _edge(&"room:objective", &"room:exit"),
    ], {"primary_floor_1": &"room:objective"}, &"room:entrance", &"room:exit")


func _floor2_manifest(request: Dictionary, layout_id: StringName) -> Dictionary:
    var rooms: Array = [
        _room(&"room:entrance", &"module:entrance", Rect2i(0, 0, 6, 6), [&"entrance", &"safe"], 0, 0, true),
        _room(&"room:escort", &"module:escort_route", Rect2i(8, 0, 10, 6), [&"escort_route", &"objective"], 1, 0, false),
        _room(&"room:exit", &"module:exit", Rect2i(20, 0, 6, 6), [&"exit"], 0, 0, false),
    ]
    return _manifest(request, layout_id, rooms, [
        _edge(&"room:entrance", &"room:escort"),
        _edge(&"room:escort", &"room:exit"),
    ], {"primary_floor_2": &"room:escort"}, &"room:entrance", &"room:exit")


func _floor10_manifest(request: Dictionary, layout_id: StringName) -> Dictionary:
    var rooms: Array = [
        _room(&"room:entrance", &"module:entrance", Rect2i(0, 0, 6, 6), [&"entrance", &"safe"], 0, 0, true),
        _room(&"room:elite", &"module:elite", Rect2i(8, 0, 8, 8), [&"combat", &"elite"], 0, 3, false),
        _room(&"room:safe", &"module:preboss_safe", Rect2i(18, 0, 6, 6), [&"safe"], 0, 0, true),
        _room(&"room:boss", &"module:boss", Rect2i(26, 0, 12, 12), [&"combat", &"objective", &"boss"], 1, 0, false),
        _room(&"room:exit", &"module:exit", Rect2i(40, 0, 6, 6), [&"exit"], 0, 0, false),
    ]
    return _manifest(request, layout_id, rooms, [
        _edge(&"room:entrance", &"room:elite"),
        _edge(&"room:elite", &"room:safe"),
        _edge(&"room:safe", &"room:boss"),
        _edge(&"room:boss", &"room:exit"),
    ], {"primary_floor_10": &"room:boss"}, &"room:entrance", &"room:exit")


func _manifest(
    request: Dictionary,
    layout_id: StringName,
    rooms: Array,
    edges: Array,
    bindings: Dictionary,
    entrance_id: StringName,
    exit_id: StringName
) -> Dictionary:
    return {
        "floor_id": request["floor_id"],
        "generation_seed": request["generation_seed"],
        "generator_version": request["generator_version"],
        "module_content_version": request["module_content_version"],
        "encounter_config_id": request["encounter_config_id"],
        "quest_world_flags_signature": request["quest_world_flags_signature"],
        "reserved_quest_ids": (request["required_quest_ids"] as Array).duplicate(),
        "layout_revision_id": layout_id,
        "rooms": rooms,
        "edges": edges,
        "objective_bindings": bindings,
        "entrance_room_id": entrance_id,
        "exit_room_id": exit_id,
    }


func _room(
    room_id: StringName,
    module_id: StringName,
    rect: Rect2i,
    tags: Array,
    objective_capacity: int,
    elite_capacity: int,
    safe_arrival: bool
) -> Dictionary:
    return {
        "room_instance_id": room_id,
        "module_id": module_id,
        "rect": rect,
        "tags": tags,
        "objective_socket_capacity": objective_capacity,
        "elite_capacity": elite_capacity,
        "safe_arrival": safe_arrival,
    }


func _edge(from_id: StringName, to_id: StringName) -> Dictionary:
    return {"from_room_id": from_id, "to_room_id": to_id}


func _contains(errors: PackedStringArray, needle: String) -> bool:
    for error: String in errors:
        if error.contains(needle):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
