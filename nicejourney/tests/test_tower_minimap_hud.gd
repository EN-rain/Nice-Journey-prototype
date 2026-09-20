extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const DISCOVERY_SERVICE_SCRIPT: Script = preload("res://src/world/tower/tower_floor_discovery_service.gd")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var profile := ProfileCreationService.create_profile(1, "Minimap", "melee")
    var request := TowerFloorGenerationCommitService.build_request(
        1,
        20461,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:minimap_fixture"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    _expect(not manifest.is_empty(), "Tower minimap fixture builds a validated floor manifest")
    var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:minimap_floor1", manifest)
    _expect(floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "Tower minimap fixture commits persistent floor state")
    if floor == null:
        quit(1)
        return

    var entrance_id := StringName(String(manifest.get("entrance_room_id", &"")))
    var entrance_rect := _room_rect(manifest, entrance_id)
    _expect(entrance_rect.size.x > 0 and entrance_rect.size.y > 0, "Tower minimap fixture resolves the authored entrance room geometry")
    var first_discovery: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 1, entrance_id)
    _expect(bool(first_discovery.get("accepted", false)), "Tower minimap fixture marks only the entrance room discovered")

    var hidden_room_id: StringName = &""
    var hidden_rect := Rect2i()
    for raw_room: Variant in manifest.get("rooms", []) as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        var room_id := StringName(String(room.get("room_instance_id", &"")))
        if room_id == entrance_id:
            continue
        var rect_variant: Variant = room.get("rect", null)
        if rect_variant is Rect2i:
            hidden_room_id = room_id
            hidden_rect = rect_variant as Rect2i
            break
    _expect(hidden_room_id != &"" and hidden_rect.size.x > 0 and hidden_rect.size.y > 0, "Tower minimap fixture resolves one still-undiscovered room")

    var gameplay := GAMEPLAY_SCENE.instantiate() as Node2D
    gameplay.call("set_profile", profile)
    root.add_child(gameplay)
    await process_frame

    var hud: Node = gameplay.get_node("CombatHUD")
    var floor_host := gameplay.get_node("TowerFloorSessionHost") as TowerFloorSessionHost
    var player := gameplay.get_node("Player") as PlayerController
    var minimap_panel := gameplay.get_node("CombatHUD/Root/MinimapPanel") as Control
    var minimap_canvas := gameplay.get_node("CombatHUD/Root/MinimapPanel/Layout/Canvas") as Control
    floor_host.active_floor_id = 1

    var entrance_center := Vector2(entrance_rect.position) + Vector2(entrance_rect.size) * 0.5
    player.global_position = floor_host.to_global(entrance_center * float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE))
    hud.call("refresh_from_runtime")
    _expect(minimap_panel.visible, "Tower minimap appears only while an active Tower floor has discovered geometry")
    _expect(int(minimap_canvas.call("visible_room_count")) == 1, "Tower minimap initially renders only the discovered entrance room")
    _expect(bool(minimap_canvas.call("player_marker_visible")), "Tower minimap shows the real player marker inside a discovered room")
    _expect((minimap_canvas.call("player_marker_tile") as Vector2).is_equal_approx(entrance_center), "Tower minimap player marker uses the real floor tile position")

    var before_hidden: Dictionary = hud.call("current_snapshot")
    var minimap_before := before_hidden.get("minimap", {}) as Dictionary
    _expect(not _contains_room(minimap_before.get("room_entries", []) as Array, hidden_room_id), "Tower minimap snapshot contains no undiscovered room identity")

    var hidden_center := Vector2(hidden_rect.position) + Vector2(hidden_rect.size) * 0.5
    player.global_position = floor_host.to_global(hidden_center * float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE))
    hud.call("refresh_from_runtime")
    _expect(int(minimap_canvas.call("visible_room_count")) == 1, "moving into an undiscovered room does not reveal its geometry through the minimap")
    _expect(not bool(minimap_canvas.call("player_marker_visible")), "player marker is withheld while the player position is outside all discovered-room geometry")

    var reveal: Dictionary = DISCOVERY_SERVICE_SCRIPT.mark_room_discovered(profile, 1, hidden_room_id)
    _expect(bool(reveal.get("accepted", false)) and bool(reveal.get("changed", false)), "authoritative room discovery makes the hidden room eligible for map presentation")
    hud.call("refresh_from_runtime")
    _expect(int(minimap_canvas.call("visible_room_count")) == 2, "Tower minimap adds the room only after persistent discovery")
    _expect(bool(minimap_canvas.call("player_marker_visible")), "player marker becomes visible once its current room is authoritatively discovered")
    _expect((minimap_canvas.call("player_marker_tile") as Vector2).is_equal_approx(hidden_center), "revealed minimap marker still preserves the real player tile position")

    var settings: Node = root.get_node_or_null("AccessibilitySettings")
    if settings != null:
        settings.call("set_ui_scale", 1.25)
        settings.call("set_text_scale", 1.25)
        await process_frame
        var minimap_rect := minimap_panel.get_global_rect()
        _expect(minimap_rect.position.x >= 0.0 and minimap_rect.position.y >= 0.0 and minimap_rect.end.x <= 640.0 and minimap_rect.end.y <= 360.0, "largest supported UI/text scale keeps the Tower minimap inside the 640x360 minimum canvas")
        settings.call("set_ui_scale", 1.0)
        settings.call("set_text_scale", 1.0)

    gameplay.queue_free()
    await process_frame
    if _failures == 0:
        print("TOWER MINIMAP HUD TEST PASS")
    else:
        push_error("TOWER MINIMAP HUD TEST FAILURES: %d" % _failures)
    quit(_failures)


func _room_rect(manifest: Dictionary, room_id: StringName) -> Rect2i:
    for raw_room: Variant in manifest.get("rooms", []) as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        if StringName(String(room.get("room_instance_id", &""))) != room_id:
            continue
        var rect_variant: Variant = room.get("rect", null)
        if rect_variant is Rect2i:
            return rect_variant as Rect2i
    return Rect2i()


func _contains_room(entries: Array, room_id: StringName) -> bool:
    for raw_entry: Variant in entries:
        if raw_entry is Dictionary and StringName(String((raw_entry as Dictionary).get("room_instance_id", &""))) == room_id:
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
