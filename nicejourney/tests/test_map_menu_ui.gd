extends SceneTree

const MENU_SCENE: PackedScene = preload("res://src/ui/map_menu.tscn")
const MAP_MENU_SCRIPT: Script = preload("res://src/ui/map_menu.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Map UI", "melee")
    profile.permanent_flags[Region3PreparationCommitService.FLAG_TOWER_SIGIL_OWNED] = true
    profile.permanent_flags["tower_floor_4_unlocked"] = true
    profile.quest_progress["primary_floor_4"] = {"state": QuestProgressState.STATE_ACTIVE}
    var floor := FloorInstanceState.new()
    floor.floor_id = 4
    floor.instance_id = &"floor_instance:map_ui:floor_4"
    floor.seed = 404
    floor.layout_revision_id = &"tower_layout:test_floor_4"
    floor.layout_manifest = {
        "rooms": [
            {"room_instance_id": &"room:map_visible", "rect": Rect2i(4, 6, 8, 6), "tags": [&"safe"]},
            {"room_instance_id": &"room:map_visible_two", "rect": Rect2i(14, 6, 6, 6), "tags": [&"combat"]},
            {"room_instance_id": &"room:map_hidden", "rect": Rect2i(24, 6, 10, 8), "tags": [&"boss"]},
        ],
        "edges": [
            {"from_room_id": &"room:map_visible", "to_room_id": &"room:map_visible_two"},
            {"from_room_id": &"room:map_visible_two", "to_room_id": &"room:map_hidden"},
        ],
    }
    floor.mark_room_discovered(&"room:map_visible")
    floor.mark_room_discovered(&"room:map_visible_two")
    floor.add_checkpoint_anchor(&"checkpoint:map_visible", &"room:map_visible", Vector2i(1, 1))
    floor.add_checkpoint_anchor(&"checkpoint:map_hidden", &"room:map_hidden", Vector2i(1, 1))
    profile.tower_floor_states["4"] = floor.to_dictionary()
    profile.safe_state = {
        "checkpoint_id": "safe:test_region3",
        "map_id": "region3:prototype",
        "floor_id": 0,
        "checkpoint_anchor_id": "anchor:test_region3",
        "player_state": {},
        "quest_attempt_state": {},
        "snapshot_sequence": 1,
    }

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

    _expect(menu.configure(profile, ownership, host, guard), "map menu configures from profile/input/current-floor/travel-guard owners")
    _expect(menu.open_menu(), "map menu opens from a configured context")
    _expect(menu.is_open() and ownership.current_modal() == &"ui:map", "map menu owns modal input while open")
    _expect(menu.current_layer_id() == MapLayerIdentityValidator.LAYER_WORLD_MAP, "map menu opens on the World layer by default")
    _expect(menu.title_label.text == "World Map", "World layer renders a distinct title")
    _expect(menu.content_label.text.contains("Region 3 — Playable prototype"), "World layer identifies Region 3 as the playable prototype")
    _expect(menu.content_label.text.contains("Region 1 — Future locked"), "World layer keeps other regions explicitly future-locked")
    _expect(menu.status_label.text.contains("do not grant travel"), "map UI states that it cannot bypass travel/access rules")

    _expect(menu.select_layer(MapLayerIdentityValidator.LAYER_REGION_MAP), "Region layer can be selected explicitly")
    _expect(menu.current_layer_id() == MapLayerIdentityValidator.LAYER_REGION_MAP and menu.title_label.text == "Region Map", "Region layer selection updates identity and title")
    _expect(menu.region_canvas.visible and int(menu.region_canvas.call("route_count")) == 13, "Region layer renders all authored road/connector polylines on its graphical canvas")
    _expect(int(menu.region_canvas.call("landmark_count")) == 1, "Region layer renders only the fixed Central Tower landmark before service discovery exists")
    _expect(menu.content_label.text.contains("160 × 160") and menu.content_label.text.contains("20 total"), "Region layer renders the authored Region 3 size and structure contract")
    _expect(menu.content_label.text.contains("Authored road polylines: 13") and menu.content_label.text.contains("Central Tower"), "Region layer text reports only source-backed public geometry")
    _expect(menu.content_label.text.contains("Authored world-layout definition: Available"), "Region layer distinguishes validated world-layout data from withheld live map state")
    _expect(menu.content_label.text.contains("Map state currently unavailable") and menu.content_label.text.contains("explored subzones") and menu.content_label.text.contains("quest markers") and menu.content_label.text.contains("Region checkpoints") and menu.content_label.text.contains("Region danger/risk"), "Region layer explicitly identifies each currently unavailable state family")
    _expect(
        menu.content_label.text.contains("region_discovery_state_uninitialized")
        and menu.content_label.text.contains("quest_marker_geometry_unauthored")
        and menu.content_label.text.contains("checkpoint_geometry_unauthored")
        and menu.content_label.text.contains("region_danger_concrete_level_unauthored"),
        "Region layer visibly reports the exact blocker reason for every withheld map family"
    )
    var region_data: Dictionary = menu.current_layer_data()
    var authored_risk_preview := region_data.duplicate(true)
    authored_risk_preview["risk_marker_state_available"] = true
    authored_risk_preview["risk_markers"] = [{"zone_id": &"R3-OUTSKIRTS", "recommended_level": 3, "player_level": 1, "danger_display": "High", "requires_danger_confirmation": true}]
    var risk_readout := String(menu.call("_region_text", authored_risk_preview))
    _expect(risk_readout.contains("Visible explored danger markers: 1") and risk_readout.contains("R3-OUTSKIRTS")
        and risk_readout.contains("Recommended Lv 3") and risk_readout.contains("Player Lv 1")
        and risk_readout.contains("confirm before travel"), "Region UI shows text-backed discovered-risk recommendations and travel confirmation instead of color-only warning")
    _expect((region_data.get("explored_subzones", []) as Array).is_empty() and (region_data.get("quest_markers", []) as Array).is_empty() and (region_data.get("checkpoint_markers", []) as Array).is_empty() and (region_data.get("risk_markers", []) as Array).is_empty(), "Region layer returns empty state arrays instead of inferred map content")

    profile.region_state = {
        "region_id": 3,
        "map_revision_id": String(Region3AuthoredTownLayout.MAP_REVISION_ID),
        "explored_zone_ids": ["R3-TOWN"],
    }
    _expect(menu.select_layer(MapLayerIdentityValidator.LAYER_WORLD_MAP), "Region discovery UI fixture can switch away before refresh")
    _expect(menu.select_layer(MapLayerIdentityValidator.LAYER_REGION_MAP), "Region discovery UI fixture refreshes from the live profile state")
    _expect(int(menu.region_canvas.call("explored_subzone_count")) == 1, "Region graphical canvas renders exactly the physically explored subzone")
    _expect(menu.content_label.text.contains("Explored subzones: 1") and menu.content_label.text.contains("R3-TOWN"), "Region text exposes the exact explored subzone identity")
    var explored_region_data: Dictionary = menu.current_layer_data()
    _expect(bool(explored_region_data.get("explored_subzone_state_available", false)) and (explored_region_data.get("explored_subzones", []) as Array).size() == 1, "Region UI snapshot carries only the validated explored-zone state")

    _expect(menu.select_layer(MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP), "Tower Floor layer can be selected explicitly")
    _expect(menu.current_layer_id() == MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP and menu.title_label.text == "Tower Floor Map", "Tower layer selection updates identity and title")
    _expect(not menu.region_canvas.visible and int(menu.region_canvas.call("route_count")) == 0, "switching to Tower clears and hides Region-only geometry")
    var tower_data: Dictionary = menu.current_layer_data()
    _expect(bool(tower_data.get("available", false)) and int(tower_data.get("floor_id", 0)) == 4, "Tower layer reflects the live active floor identity")
    var tower_rooms := tower_data.get("room_entries", []) as Array
    _expect(tower_rooms.size() == 2, "Tower UI receives only the two discovered room geometries")
    _expect(int(menu.room_canvas.call("visible_room_count")) == 2 and menu.room_canvas.visible, "Tower layer renders discovered geometry on the graphical room canvas")
    var canvas_connections := menu.room_canvas.call("room_connections") as Array
    _expect(canvas_connections.size() == 1, "Tower canvas renders only the connection whose two endpoints are discovered")
    var canvas_risks := menu.room_canvas.call("risk_markers") as Array
    _expect(canvas_risks.size() == 1 and StringName((canvas_risks[0] as Dictionary).get("risk_id", &"")) == &"risk:combat", "Tower canvas renders only risk owned by a discovered room")
    var canvas_markers := menu.room_canvas.call("checkpoint_markers") as Array
    _expect(canvas_markers.size() == 1 and StringName((canvas_markers[0] as Dictionary).get("checkpoint_id", &"")) == &"checkpoint:map_visible", "Tower canvas renders only the checkpoint anchored in the discovered room")
    _expect(menu.content_label.text.contains("Visible discovered checkpoints: 1"), "Tower UI reports only discovered checkpoint markers")
    _expect(menu.content_label.text.contains("Visible discovered connections: 1"), "Tower UI reports only connections between discovered rooms")
    _expect(menu.content_label.text.contains("Visible discovered risk markers: 1") and menu.content_label.text.contains("risk:combat"), "Tower UI reports discovered risk through a stable risk ID plus text")
    var eligible := tower_data.get("eligible_travel_floors", []) as Array
    _expect(bool(tower_data.get("travel_eligibility_available", false)) and eligible.size() == 1 and int((eligible[0] as Dictionary).get("floor_id", 0)) == 4, "Tower UI consumes authoritative read-only eligible travel data")
    _expect(menu.content_label.text.contains("Eligible Tower destinations (read-only)") and menu.content_label.text.contains("Floor 4") and menu.content_label.text.contains("This map view cannot execute travel"), "Tower UI communicates eligible travel without exposing an action")
    _expect(menu.content_label.text.contains("Player Level: 1") and menu.content_label.text.contains("Recommended Lv 4"), "Tower UI shows authoritative player and destination Recommended Levels before travel")
    _expect(menu.content_label.text.contains("Main objective: primary_floor_4"), "Tower UI shows the actually-active primary objective before travel")
    _expect(menu.content_label.text.contains("Hazards: Unknown"), "Tower UI keeps special hazards explicitly Unknown when no authored hazard owner exists")
    _expect(not bool(tower_data.get("travel_action_available", true)), "Tower map data remains non-actionable even when eligibility is visible")
    _expect(menu.content_label.text.contains("Discovered rooms: 2") and menu.content_label.text.contains("room:map_visible") and menu.content_label.text.contains("room:map_visible_two"), "Tower UI lists the exact discovered room identities")
    _expect(not menu.content_label.text.contains("room:map_hidden") and not str(tower_data).contains("room:map_hidden") and not str(tower_data).contains("checkpoint:map_hidden") and not str(tower_data).contains("risk:boss"), "Tower UI leaks neither undiscovered room identity nor its checkpoint/risk marker")
    _expect(menu.content_label.text.contains("Undiscovered generated rooms remain withheld"), "Tower UI explains the undiscovered-room boundary")

    var travel_blocker := guard.acquire_blocker(&"test:map_ui_combat", GameplayOperationGuard.REASON_ACTIVE_COMBAT, "Active combat", [GameplayOperationGuard.OP_SIGIL_TRAVEL])
    _expect(travel_blocker > 0 and menu.select_layer(MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP), "map remains inspectable while shared travel eligibility becomes blocked")
    var blocked_data: Dictionary = menu.current_layer_data()
    _expect(not bool(blocked_data.get("travel_eligibility_available", true)) and StringName(blocked_data.get("travel_eligibility_reason_id", &"")) == TowerAccessMenuService.REASON_OPERATION_BLOCKED, "Tower UI shows authoritative operation-blocked travel reason")
    _expect(menu.content_label.text.contains("operation_blocked") and menu.content_label.text.contains("cannot execute travel"), "blocked travel remains visible as read-only status, not an action")
    guard.release_blocker(travel_blocker)
    _expect(menu.select_layer(MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP) and bool(menu.current_layer_data().get("travel_eligibility_available", false)), "travel eligibility refreshes after the shared blocker releases")

    _expect(not menu.select_layer(&"minimap"), "map menu rejects unknown layer identities")
    _expect(menu.current_layer_id() == MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP, "rejected layer selection leaves the active map layer unchanged")

    menu.close_menu(&"map")
    _expect(not menu.is_open() and not ownership.is_modal_open(), "closing map menu releases modal ownership")
    _expect(not ownership.can_route_gameplay_action(&"map"), "closing Map action is suppressed until release to prevent key-through")
    ownership.notify_action_released(&"map")
    _expect(ownership.can_route_gameplay_action(&"map"), "Map action suppression clears after release")

    ownership.open_modal(&"ui:test_other")
    _expect(not menu.open_menu(), "map menu cannot steal modal ownership from another open UI")
    _expect(ownership.current_modal() == &"ui:test_other", "rejected map open leaves the existing modal owner unchanged")
    ownership.close_modal(&"ui:test_other")

    var returned: Dictionary = menu.current_layer_data()
    returned["floor_id"] = 99
    _expect(int(menu.current_layer_data().get("floor_id", 0)) == 4, "callers cannot mutate the map menu's current layer snapshot")

    menu.queue_free()
    host.queue_free()
    guard.queue_free()
    ownership.queue_free()
    await process_frame

    if _failures == 0:
        print("MAP MENU UI TEST PASS")
    else:
        push_error("MAP MENU UI TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
