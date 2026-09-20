extends SceneTree

const MENU_SCENE: PackedScene = preload("res://src/ui/map_menu.tscn")
const DISCOVERY_SERVICE_SCRIPT: Script = preload("res://src/world/tower/tower_floor_discovery_service.gd")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "QA Maps", "melee")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_1_unlocked"] = true
    profile.permanent_flags["tower_floor_4_unlocked"] = true

    var floor := FloorInstanceState.new()
    floor.floor_id = 4
    floor.instance_id = &"floor_instance:qa_maps:floor_4"
    floor.seed = 40404
    floor.layout_revision_id = &"tower_layout:qa_maps_floor_4"
    floor.layout_manifest = {
        "rooms": [
            {"room_instance_id": &"room:qa_entry", "rect": Rect2i(2, 4, 7, 6), "tags": [&"safe"]},
            {"room_instance_id": &"room:qa_combat", "rect": Rect2i(12, 4, 8, 7), "tags": [&"combat"]},
            {"room_instance_id": &"room:qa_boss_hidden", "rect": Rect2i(24, 4, 10, 9), "tags": [&"combat", &"boss"]},
        ],
        "edges": [
            {"from_room_id": &"room:qa_entry", "to_room_id": &"room:qa_combat"},
            {"from_room_id": &"room:qa_combat", "to_room_id": &"room:qa_boss_hidden"},
        ],
    }
    floor.mark_room_discovered(&"room:qa_entry")
    floor.mark_room_discovered(&"room:qa_combat")
    floor.add_checkpoint_anchor(&"checkpoint:qa_entry", &"room:qa_entry", Vector2i(1, 1))
    floor.add_checkpoint_anchor(&"checkpoint:qa_hidden", &"room:qa_boss_hidden", Vector2i(1, 1))
    profile.tower_floor_states["4"] = floor.to_dictionary()

    var ownership := InputOwnership.new()
    root.add_child(ownership)
    var guard := GameplayOperationGuard.new()
    root.add_child(guard)
    var host := TowerFloorSessionHost.new()
    host.active_floor_id = 4
    root.add_child(host)
    var menu: Variant = MENU_SCENE.instantiate()
    root.add_child(menu)
    await process_frame

    _expect(menu.configure(profile, ownership, host, guard), "QA-MAPS menu configures from authoritative owners")
    _expect(menu.open_menu(), "QA-MAPS opens the map surface")

    var world_data: Dictionary = menu.current_layer_data()
    _expect(menu.current_layer_id() == MapLayerIdentityValidator.LAYER_WORLD_MAP, "QA-MAPS starts on the World layer")
    var regions := world_data.get("regions", []) as Array
    var playable_count := 0
    var future_locked_count := 0
    for raw_region: Variant in regions:
        var region := raw_region as Dictionary
        if bool(region.get("playable", false)):
            playable_count += 1
            _expect(int(region.get("region_id", 0)) == 3, "QA-MAPS keeps only Region 3 playable")
        elif StringName(region.get("state", &"")) == WorldRegionCatalogValidator.STATE_FUTURE_LOCKED:
            future_locked_count += 1
    _expect(regions.size() == 12 and playable_count == 1 and future_locked_count == 11, "QA-MAPS keeps the other eleven regions as future placeholders")

    _expect(menu.select_layer(MapLayerIdentityValidator.LAYER_REGION_MAP), "QA-MAPS switches to Region layer")
    var region_data: Dictionary = menu.current_layer_data()
    _expect(int(region_data.get("region_id", 0)) == 3 and region_data.get("map_size_tiles", Vector2i.ZERO) == Vector2i(160, 160), "QA-MAPS Region layer exposes the authored Region 3 context")

    _expect(menu.select_layer(MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP), "QA-MAPS switches to Tower layer")
    var tower_data: Dictionary = menu.current_layer_data()
    _expect(int(tower_data.get("floor_id", 0)) == 4 and bool(tower_data.get("available", false)), "QA-MAPS Tower layer exposes the current generated floor identity")
    _expect(int(tower_data.get("discovered_room_count", 0)) == 2, "QA-MAPS exposes exactly physically discovered rooms")
    _expect(int(tower_data.get("visible_connection_count", 0)) == 1, "QA-MAPS exposes navigation only between discovered room endpoints")
    _expect(int(tower_data.get("visible_checkpoint_count", 0)) == 1, "QA-MAPS exposes checkpoint positions only inside discovered rooms")
    _expect(int(tower_data.get("visible_risk_marker_count", 0)) == 1 and str(tower_data.get("risk_markers", [])).contains("risk:combat"), "QA-MAPS exposes discovered combat risk through a stable risk ID")
    _expect(not str(tower_data).contains("room:qa_boss_hidden") and not str(tower_data).contains("risk:boss") and not str(tower_data).contains("checkpoint:qa_hidden"), "QA-MAPS keeps undiscovered room identity, risk and checkpoint position unknown")
    _expect(not bool(tower_data.get("travel_action_available", true)), "QA-MAPS map markers cannot grant travel")

    var eligible := tower_data.get("eligible_travel_floors", []) as Array
    _expect(bool(tower_data.get("travel_eligibility_available", false)) and eligible.size() == 2, "QA-MAPS exposes authoritative eligible Tower travel as read-only data")
    _expect(str(eligible).contains("DANGER I") and str(eligible).contains("DANGER IV"), "QA-MAPS eligible travel preserves authoritative danger information")

    var discover_boss: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 4, &"room:qa_boss_hidden")
    _expect(bool(discover_boss.get("accepted", false)) and bool(discover_boss.get("changed", false)), "QA-MAPS physical discovery updates the hidden-room boundary")
    _expect(menu.select_layer(MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP), "QA-MAPS refreshes Tower layer after discovery")
    tower_data = menu.current_layer_data()
    _expect(int(tower_data.get("discovered_room_count", 0)) == 3 and int(tower_data.get("visible_connection_count", 0)) == 2, "QA-MAPS reveals newly known geometry/navigation only after discovery")
    _expect(str(tower_data.get("risk_markers", [])).contains("risk:boss") and str(tower_data.get("checkpoint_markers", [])).contains("checkpoint:qa_hidden"), "QA-MAPS reveals boss risk/checkpoint only after the room becomes known")

    var blocker := guard.acquire_blocker(&"qa:maps_active_combat", GameplayOperationGuard.REASON_ACTIVE_COMBAT, "Active combat", [GameplayOperationGuard.OP_SIGIL_TRAVEL])
    _expect(blocker > 0 and menu.select_layer(MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP), "QA-MAPS remains inspectable while travel is blocked")
    var blocked_data: Dictionary = menu.current_layer_data()
    _expect(not bool(blocked_data.get("travel_eligibility_available", true)) and StringName(blocked_data.get("travel_eligibility_reason_id", &"")) == TowerAccessMenuService.REASON_OPERATION_BLOCKED, "QA-MAPS reports authoritative blocked travel state")
    _expect((blocked_data.get("eligible_travel_floors", []) as Array).is_empty() and not bool(blocked_data.get("travel_action_available", true)), "QA-MAPS cannot bypass active-combat travel restrictions")
    guard.release_blocker(blocker)

    menu.close_menu(&"map")
    _expect(not menu.is_open() and not ownership.is_modal_open(), "QA-MAPS closes without leaving modal ownership")

    menu.queue_free()
    host.queue_free()
    guard.queue_free()
    ownership.queue_free()
    await process_frame

    if _failures == 0:
        print("QA-MAPS NAVIGATION/UI TEST PASS")
    else:
        push_error("QA-MAPS NAVIGATION/UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
