extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_all_floor_fallbacks()
    _test_invalid_request_rejected()
    if _failures == 0:
        print("TOWER PREVALIDATED FALLBACK TEST PASS")
    else:
        push_error("TOWER PREVALIDATED FALLBACK TEST FAILURES: %d" % _failures)
    quit(_failures)

func _request(floor_id: int) -> Dictionary:
    return TowerFloorGenerationCommitService.build_request(
        floor_id,
        90000 + floor_id,
        &"generator:prototype_v01",
        &"modules:prototype_v01",
        &"encounters:prototype_v01",
        &"quest_flags:fixture"
    )

func _test_all_floor_fallbacks() -> void:
    for floor_id: int in range(1, 11):
        var request := _request(floor_id)
        _expect(TowerFloorGenerationCommitService.validate_request(request).is_empty(), "Floor %d fallback request validates" % floor_id)
        var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
        _expect(not manifest.is_empty(), "Floor %d has a deterministic compatible fallback manifest" % floor_id)
        if manifest.is_empty():
            continue
        var errors := TowerFloorLayoutManifestValidator.validate_manifest(manifest, request)
        _expect(errors.is_empty(), "Floor %d fallback passes the authoritative complete-manifest validator" % floor_id)
        _expect(int(manifest["generation_seed"]) == int(request["generation_seed"]), "Floor %d fallback preserves the exact generation seed" % floor_id)
        _expect(StringName(String(manifest["layout_revision_id"])) == StringName("fallback:prototype_v01:floor_%d" % floor_id), "Floor %d fallback has a stable authored layout revision" % floor_id)
        _expect((manifest["reserved_quest_ids"] as Array).size() == (request["required_quest_ids"] as Array).size(), "Floor %d fallback reserves every approved quest socket" % floor_id)
        var binding_count := (manifest["objective_bindings"] as Dictionary).size()
        _expect(binding_count == (request["required_quest_ids"] as Array).size(), "Floor %d fallback binds every required objective" % floor_id)
        _expect(_all_rooms_in_bounds(manifest["rooms"] as Array), "Floor %d fallback remains inside the 50x50 footprint" % floor_id)

        var choice := TowerFloorGenerationCommitService.choose_valid_manifest(request, [], manifest)
        _expect(bool(choice["accepted"]) and bool(choice["used_fallback"]), "Floor %d fallback is consumable by the commit service when candidates are unavailable" % floor_id)
        var state := TowerFloorGenerationCommitService.floor_state_from_manifest(StringName("floor_instance:fallback_%02d" % floor_id), manifest)
        _expect(state != null and state.floor_id == floor_id, "Floor %d fallback commits into persistent floor-instance state" % floor_id)

        if floor_id in [4, 7]:
            _expect((request["required_quest_ids"] as Array).size() == 2, "Floor %d retains its unaccepted tower-side quest reservation" % floor_id)
            var bound_rooms: Array = (manifest["objective_bindings"] as Dictionary).values()
            _expect(bound_rooms.size() == 2 and String(bound_rooms[0]) != String(bound_rooms[1]), "Floor %d gives primary and side objectives independent socket capacity" % floor_id)
        if floor_id == 5:
            _expect(_elite_capacity(manifest["rooms"] as Array) >= 3, "Floor 5 fallback reserves all three required elite slots")
        if floor_id == 10:
            _expect(_elite_capacity(manifest["rooms"] as Array) >= 3, "Floor 10 fallback reserves all three required elite slots")
            _expect(_room_count_with_tag(manifest["rooms"] as Array, TowerFloorLayoutManifestValidator.TAG_BOSS) == 1, "Floor 10 fallback contains exactly one Boss Sanctum")
            _expect(_rooms_directly_connected(manifest["edges"] as Array, &"room:preboss_safe", &"room:boss"), "Floor 10 fallback connects the safe pre-boss checkpoint directly to the Boss Sanctum")

func _test_invalid_request_rejected() -> void:
    var invalid := _request(4)
    invalid["required_quest_ids"] = [&"primary_floor_4"]
    _expect(TowerPrevalidatedFallbackFactory.build_for_request(invalid).is_empty(), "fallback factory refuses a request that drops reserved tower-side quest state")

func _all_rooms_in_bounds(rooms: Array) -> bool:
    for raw_room: Variant in rooms:
        var room := raw_room as Dictionary
        var rect := room["rect"] as Rect2i
        if rect.position.x < 0 or rect.position.y < 0 or rect.end.x > 50 or rect.end.y > 50:
            return false
    return true

func _elite_capacity(rooms: Array) -> int:
    var total := 0
    for raw_room: Variant in rooms:
        var room := raw_room as Dictionary
        var tags := room["tags"] as Array
        if tags.has(TowerFloorLayoutManifestValidator.TAG_ELITE):
            total += int(room["elite_capacity"])
    return total

func _room_count_with_tag(rooms: Array, tag: StringName) -> int:
    var count := 0
    for raw_room: Variant in rooms:
        var room := raw_room as Dictionary
        if (room["tags"] as Array).has(tag):
            count += 1
    return count

func _rooms_directly_connected(edges: Array, left: StringName, right: StringName) -> bool:
    for raw_edge: Variant in edges:
        var edge := raw_edge as Dictionary
        var from_id := StringName(String(edge["from_room_id"]))
        var to_id := StringName(String(edge["to_room_id"]))
        if (from_id == left and to_id == right) or (from_id == right and to_id == left):
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
