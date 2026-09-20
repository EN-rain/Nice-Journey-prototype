extends SceneTree

const LAYOUT_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var layout := LAYOUT_SCENE.instantiate() as Region3AuthoredTownLayout
    var profile := ProfileCreationService.create_profile(1, "Region Discovery", "melee")
    _expect(layout != null and profile != null, "Region discovery fixture creates authoritative layout/profile")
    if layout == null or profile == null:
        quit(1)
        return

    _expect(profile.region_state.is_empty(), "new profile does not fabricate Region discovery before physical traversal")
    var read_only_before := Region3SubzoneDiscoveryService.explored_zone_entries(profile, layout)
    _expect(
        not bool(read_only_before.get("accepted", true))
        and StringName(String(read_only_before.get("reason_id", &""))) == Region3SubzoneDiscoveryService.REASON_STATE_UNINITIALIZED,
        "read-only map discovery query reports uninitialized state"
    )
    _expect(profile.region_state.is_empty(), "read-only discovery query cannot initialize or mutate profile state")

    var town_position := Vector2(60, 80) * float(layout.tile_size)
    var town_mark := Region3SubzoneDiscoveryService.mark_local_position_explored(profile, layout, town_position)
    _expect(bool(town_mark.get("accepted", false)) and bool(town_mark.get("changed", false)), "physical town position initializes and marks Region discovery")
    _expect(StringName(String(town_mark.get("zone_id", &""))) == &"R3-TOWN", "Quest Hall approach resolves to the authored R3-TOWN reservation")
    _expect(int(profile.region_state.get("region_id", 0)) == 3, "Region discovery state preserves Region 3 identity")
    _expect(StringName(String(profile.region_state.get("map_revision_id", &""))) == layout.map_revision_id, "Region discovery state is bound to the authored map revision")
    _expect((profile.region_state.get("loose_items", {}) as Dictionary).is_empty(), "new Region state initializes an explicit empty loose-item owner")

    var town_entries := Region3SubzoneDiscoveryService.explored_zone_entries(profile, layout)
    var entries := town_entries.get("entries", []) as Array
    _expect(bool(town_entries.get("accepted", false)) and entries.size() == 1, "only the physically entered town subzone is explored")
    if entries.size() == 1:
        var entry := entries[0] as Dictionary
        _expect(StringName(String(entry.get("zone_id", &""))) == &"R3-TOWN", "explored entry preserves stable zone identity")
        _expect(entry.get("tile_rect", Rect2i()) == Rect2i(48, 48, 64, 64), "explored entry exposes the existing authored town geometry")

    var repeat := Region3SubzoneDiscoveryService.mark_local_position_explored(profile, layout, town_position)
    _expect(bool(repeat.get("accepted", false)) and not bool(repeat.get("changed", true)), "re-entering an explored zone is idempotent")

    var outskirts_position := Vector2(70, 120) * float(layout.tile_size)
    var outskirts_mark := Region3SubzoneDiscoveryService.mark_local_position_explored(profile, layout, outskirts_position)
    _expect(bool(outskirts_mark.get("accepted", false)) and StringName(String(outskirts_mark.get("zone_id", &""))) == &"R3-OUTSKIRTS", "physical south traversal marks the authored outskirts zone")
    entries = (Region3SubzoneDiscoveryService.explored_zone_entries(profile, layout).get("entries", []) as Array)
    _expect(entries.size() == 2, "subzone discovery accumulates distinct physically explored zones only")

    var serialized := profile.to_dictionary()
    _expect(ProfileSnapshot.validate_dictionary(serialized).is_empty(), "profile validation accepts authoritative Region discovery state")
    var restored := ProfileSnapshot.from_dictionary(serialized)
    _expect(restored.region_state == profile.region_state, "Region discovery state round-trips through ProfileSnapshot serialization")

    var unknown := serialized.duplicate(true)
    (unknown["region_state"] as Dictionary)["explored_zone_ids"] = ["R3-TOWN", "R3-INVENTED"]
    _expect(_contains(ProfileSnapshot.validate_dictionary(unknown), "unknown Region 3 zone"), "profile validation rejects invented explored-zone IDs")

    var malformed_loose := serialized.duplicate(true)
    (malformed_loose["region_state"] as Dictionary)["loose_items"] = {
        "random_loot:invalid_region_owner": {
            "entry_kind": "random_loot",
        },
    }
    _expect(_contains(ProfileSnapshot.validate_dictionary(malformed_loose), "supports only validated player_drop records"), "Region persistence rejects unauthorised loose-item record families")

    var wrong_revision := ProfileSnapshot.from_dictionary(serialized)
    wrong_revision.region_state["map_revision_id"] = "region3_town_layout_v99"
    var mismatch := Region3SubzoneDiscoveryService.explored_zone_entries(wrong_revision, layout)
    _expect(
        not bool(mismatch.get("accepted", true))
        and StringName(String(mismatch.get("reason_id", &""))) == Region3SubzoneDiscoveryService.REASON_MAP_REVISION_MISMATCH,
        "Region discovery fails closed when persisted discovery belongs to another authored map revision"
    )

    layout.free()
    if _failures == 0:
        print("REGION 3 SUBZONE DISCOVERY TEST PASS")
    else:
        push_error("REGION 3 SUBZONE DISCOVERY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _contains(errors: PackedStringArray, fragment: String) -> bool:
    for error: String in errors:
        if error.contains(fragment):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
