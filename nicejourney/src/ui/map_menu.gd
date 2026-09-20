class_name MapMenu
extends CanvasLayer

const MODAL_ID: StringName = &"ui:map"

@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/Panel/Layout/Title
@onready var world_button: Button = $Overlay/Panel/Layout/Layers/World
@onready var region_button: Button = $Overlay/Panel/Layout/Layers/Region
@onready var tower_button: Button = $Overlay/Panel/Layout/Layers/TowerFloor
@onready var status_label: Label = $Overlay/Panel/Layout/Status
@onready var region_canvas: Control = $Overlay/Panel/Layout/RegionCanvas
@onready var room_canvas: Control = $Overlay/Panel/Layout/RoomCanvas
@onready var content_label: Label = $Overlay/Panel/Layout/Scroll/Content
@onready var back_button: Button = $Overlay/Panel/Layout/Back

var _profile: ProfileSnapshot = null
var _input_ownership: InputOwnership = null
var _tower_floor_session_host: Node = null
var _operation_guard: GameplayOperationGuard = null
var _current_layer_id: StringName = MapLayerIdentityValidator.LAYER_WORLD_MAP
var _current_layer_data: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    overlay.visible = false
    world_button.set_meta(&"layer_id", MapLayerIdentityValidator.LAYER_WORLD_MAP)
    region_button.set_meta(&"layer_id", MapLayerIdentityValidator.LAYER_REGION_MAP)
    tower_button.set_meta(&"layer_id", MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP)
    world_button.pressed.connect(_on_layer_pressed.bind(MapLayerIdentityValidator.LAYER_WORLD_MAP))
    region_button.pressed.connect(_on_layer_pressed.bind(MapLayerIdentityValidator.LAYER_REGION_MAP))
    tower_button.pressed.connect(_on_layer_pressed.bind(MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP))
    back_button.pressed.connect(_on_back_pressed)


func configure(profile: ProfileSnapshot, input_ownership: InputOwnership, tower_floor_session_host: Node = null, operation_guard: GameplayOperationGuard = null) -> bool:
    if profile == null or input_ownership == null:
        return false
    _profile = profile
    _input_ownership = input_ownership
    _tower_floor_session_host = tower_floor_session_host
    _operation_guard = operation_guard
    return true


func _unhandled_input(event: InputEvent) -> void:
    if not event.is_action_pressed(&"map"):
        return
    if overlay.visible:
        close_menu(&"map")
        get_viewport().set_input_as_handled()
        return
    if _input_ownership != null and _input_ownership.is_modal_open():
        return
    if open_menu():
        get_viewport().set_input_as_handled()


func open_menu() -> bool:
    if _profile == null or _input_ownership == null:
        return false
    if _input_ownership.is_modal_open() and _input_ownership.current_modal() != MODAL_ID:
        return false
    if not MapViewService.validate_layer_descriptors().is_empty():
        return false
    overlay.visible = true
    _input_ownership.open_modal(MODAL_ID)
    if not select_layer(_current_layer_id):
        close_menu()
        return false
    _button_for_layer(_current_layer_id).grab_focus()
    return true


func close_menu(triggering_action: StringName = &"") -> void:
    if not overlay.visible:
        return
    overlay.visible = false
    if _input_ownership != null:
        _input_ownership.close_modal(MODAL_ID, triggering_action)


func is_open() -> bool:
    return overlay.visible


func current_layer_id() -> StringName:
    return _current_layer_id


func current_layer_data() -> Dictionary:
    return _current_layer_data.duplicate(true)


func select_layer(layer_id: StringName) -> bool:
    if _profile == null or not MapLayerIdentityValidator.REQUIRED_LAYER_IDS.has(layer_id):
        return false
    var data := MapViewService.build_layer(_profile, layer_id, _active_floor_id(), _operation_guard)
    if not bool(data.get("accepted", false)):
        return false
    _current_layer_id = layer_id
    _current_layer_data = data.duplicate(true)
    _render_layer(data)
    return true


func _active_floor_id() -> int:
    if _tower_floor_session_host == null or not is_instance_valid(_tower_floor_session_host):
        return 0
    var value: Variant = _tower_floor_session_host.get("active_floor_id")
    return int(value) if typeof(value) == TYPE_INT else 0


func _render_layer(data: Dictionary) -> void:
    status_label.text = tr("Map information only. Map views do not grant travel or bypass access rules.")
    match _current_layer_id:
        MapLayerIdentityValidator.LAYER_WORLD_MAP:
            region_canvas.visible = false
            region_canvas.call("clear_geometry")
            room_canvas.visible = false
            room_canvas.call("clear_rooms")
            title_label.text = tr("World Map")
            content_label.text = _world_text(data)
        MapLayerIdentityValidator.LAYER_REGION_MAP:
            room_canvas.visible = false
            room_canvas.call("clear_rooms")
            region_canvas.visible = true
            region_canvas.call(
                "configure_geometry",
                data.get("map_size_tiles", Vector2i.ZERO),
                data.get("town_tile_rect", Rect2i()),
                data.get("plaza_tile_rect", Rect2i()),
                data.get("route_polylines", []),
                data.get("public_landmarks", []),
                data.get("explored_subzones", [])
            )
            region_canvas.call("set_risk_markers", data.get("risk_markers", []))
            title_label.text = tr("Region Map")
            content_label.text = _region_text(data)
        MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP:
            region_canvas.visible = false
            region_canvas.call("clear_geometry")
            room_canvas.visible = true
            room_canvas.call("set_room_entries", data.get("room_entries", []))
            room_canvas.call("set_room_connections", data.get("room_connections", []))
            room_canvas.call("set_risk_markers", data.get("risk_markers", []))
            room_canvas.call("set_checkpoint_markers", data.get("checkpoint_markers", []))
            title_label.text = tr("Tower Floor Map")
            content_label.text = _tower_text(data)


func _world_text(data: Dictionary) -> String:
    var lines := PackedStringArray()
    lines.append(tr("World context — 12 region identities"))
    for raw_region: Variant in data.get("regions", []) as Array:
        if not raw_region is Dictionary:
            continue
        var region := raw_region as Dictionary
        var region_id := int(region.get("region_id", 0))
        var state := StringName(region.get("state", &""))
        var state_text := tr("Playable prototype") if state == WorldRegionCatalogValidator.STATE_PROTOTYPE_STARTING_REGION else tr("Future locked")
        lines.append(tr("Region %d — %s") % [region_id, state_text])
    lines.append("")
    lines.append(tr("Per-region discovery data is not authored yet; no hidden map content is exposed."))
    return "\n".join(lines)


func _region_text(data: Dictionary) -> String:
    var routes := data.get("route_polylines", []) as Array
    var landmarks := data.get("public_landmarks", []) as Array
    var services := data.get("discovered_services", []) as Array
    var unavailable_state := PackedStringArray()
    if not bool(data.get("explored_subzone_state_available", false)):
        unavailable_state.append(
            tr("explored subzones [%s]") % String(data.get("explored_subzone_unavailable_reason_id", &""))
        )
    if not bool(data.get("quest_marker_state_available", false)):
        unavailable_state.append(
            tr("quest markers [%s]") % String(data.get("quest_marker_unavailable_reason_id", &""))
        )
    if not bool(data.get("checkpoint_marker_state_available", false)):
        unavailable_state.append(
            tr("Region checkpoints [%s]") % String(data.get("checkpoint_marker_unavailable_reason_id", &""))
        )
    if not bool(data.get("risk_marker_state_available", false)):
        unavailable_state.append(
            tr("Region danger/risk [%s]") % String(data.get("risk_marker_unavailable_reason_id", &""))
        )
    var lines := PackedStringArray()
    lines.append(tr("Region %d") % int(data.get("region_id", 0)))
    lines.append(tr("Revision: %s") % String(data.get("map_revision_id", &"")))
    lines.append(tr("Map reservation: %d × %d tiles") % [
        int((data.get("map_size_tiles", Vector2i.ZERO) as Vector2i).x),
        int((data.get("map_size_tiles", Vector2i.ZERO) as Vector2i).y),
    ])
    lines.append(tr("Structures: %d total — %d functional / %d decorative") % [
        int(data.get("structure_count", 0)),
        int(data.get("functional_structure_count", 0)),
        int(data.get("decorative_structure_count", 0)),
    ])
    lines.append(tr("Authored road polylines: %d") % routes.size())
    lines.append(tr("Visible landmarks: %d — Central Tower + discovered services") % landmarks.size())
    lines.append(tr("Discovered services: %d") % services.size())
    var explored_subzones := data.get("explored_subzones", []) as Array
    lines.append(tr("Explored subzones: %d") % explored_subzones.size())
    if bool(data.get("risk_marker_state_available", false)):
        var risk_markers := data.get("risk_markers", []) as Array
        lines.append(tr("Visible explored danger markers: %d") % risk_markers.size())
        for raw_risk: Variant in risk_markers:
            if not raw_risk is Dictionary:
                continue
            var risk := raw_risk as Dictionary
            lines.append(tr("• %s — Recommended Lv %d — Player Lv %d — %s%s") % [
                String(risk.get("zone_id", &"")),
                int(risk.get("recommended_level", 0)),
                int(risk.get("player_level", 0)),
                String(risk.get("danger_display", "")),
                tr(" — confirm before travel") if bool(risk.get("requires_danger_confirmation", false)) else "",
            ])
    lines.append(
        tr("Authored world-layout definition: %s")
        % (tr("Available") if bool(data.get("world_layout_definition_available", false)) else tr("Unavailable"))
    )
    for raw_service: Variant in services:
        if not raw_service is Dictionary:
            continue
        var service := raw_service as Dictionary
        lines.append(tr("• %s — %s") % [String(service.get("landmark_kind", &"")), String(service.get("landmark_id", &""))])
    for raw_subzone: Variant in explored_subzones:
        if not raw_subzone is Dictionary:
            continue
        lines.append(tr("• explored — %s") % String((raw_subzone as Dictionary).get("zone_id", &"")))
    lines.append("")
    if not unavailable_state.is_empty():
        lines.append(tr("Map state currently unavailable: %s. This view keeps those entries withheld.") % ", ".join(unavailable_state))
    return "\n".join(lines)


func _tower_text(data: Dictionary) -> String:
    var lines := PackedStringArray()
    if not bool(data.get("available", false)):
        lines.append(tr("No valid current generated tower floor is available for this view."))
        lines.append(tr("Hidden floor geometry remains withheld."))
        _append_travel_eligibility(lines, data)
        return "\n".join(lines)
    lines.append_array(PackedStringArray([
        tr("Current Floor: %d") % int(data.get("floor_id", 0)),
        tr("Instance: %s") % String(data.get("instance_id", &"")),
        tr("Layout revision: %s") % String(data.get("layout_revision_id", &"")),
        tr("Primary clear: %s") % (tr("Yes") if bool(data.get("primary_cleared", false)) else tr("No")),
        tr("Registered checkpoints: %d") % int(data.get("checkpoint_count", 0)),
        tr("Visible discovered checkpoints: %d") % int(data.get("visible_checkpoint_count", 0)),
        tr("Visible discovered connections: %d") % int(data.get("visible_connection_count", 0)),
        tr("Visible discovered risk markers: %d") % int(data.get("visible_risk_marker_count", 0)),
        tr("Discovered rooms: %d") % int(data.get("discovered_room_count", 0)),
    ]))
    for raw_risk: Variant in data.get("risk_markers", []) as Array:
        if not raw_risk is Dictionary:
            continue
        var risk := raw_risk as Dictionary
        lines.append(tr("%s — %s") % [String(risk.get("risk_id", &"")), String(risk.get("room_instance_id", &""))])
    for raw_room: Variant in data.get("room_entries", []) as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        var rect_variant: Variant = room.get("rect", null)
        if not rect_variant is Rect2i:
            continue
        var rect := rect_variant as Rect2i
        lines.append(tr("%s — x%d y%d, %d×%d tiles") % [
            String(room.get("room_instance_id", &"")), rect.position.x, rect.position.y, rect.size.x, rect.size.y,
        ])
    lines.append("")
    lines.append(tr("Only discovered room geometry is shown. Undiscovered generated rooms remain withheld."))
    _append_travel_eligibility(lines, data)
    return "\n".join(lines)


func _append_travel_eligibility(lines: PackedStringArray, data: Dictionary) -> void:
    lines.append("")
    if not bool(data.get("travel_eligibility_available", false)):
        lines.append(tr("Tower travel eligibility unavailable: %s") % String(data.get("travel_eligibility_reason_id", &"")))
        lines.append(tr("This map view cannot execute travel."))
        return
    lines.append(tr("Eligible Tower destinations (read-only):"))
    lines.append(tr("Player Level: %d") % int(data.get("travel_player_level", 0)))
    for raw_entry: Variant in data.get("eligible_travel_floors", []) as Array:
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        var main_objective_id := StringName(String(entry.get("main_objective_quest_id", &"")))
        var main_objective := String(main_objective_id) if main_objective_id != &"" else tr("Unknown")
        var hazards := tr("Unknown")
        if bool(entry.get("special_hazard_state_available", false)):
            var hazard_ids := PackedStringArray()
            for raw_hazard_id: Variant in entry.get("known_special_hazards", []) as Array:
                hazard_ids.append(String(raw_hazard_id))
            hazards = tr("None known") if hazard_ids.is_empty() else ", ".join(hazard_ids)
        var warning_parts := PackedStringArray()
        if bool(entry.get("elite_warning", false)):
            warning_parts.append(tr("Elite warning ×%d") % int(entry.get("elite_target", 0)))
        if bool(entry.get("boss_warning", false)):
            warning_parts.append(tr("Boss warning"))
        var warnings := ""
        if not warning_parts.is_empty():
            warnings = " | %s" % " + ".join(warning_parts)
        var confirmation := tr(" | confirmation required") if bool(entry.get("requires_danger_confirmation", false)) else ""
        lines.append(tr("Floor %d | %s | Recommended Lv %d | %s | Main objective: %s | Hazards: %s%s%s") % [
            int(entry.get("floor_id", 0)),
            String(entry.get("state", &"")),
            int(entry.get("recommended_level", 0)),
            String(entry.get("danger_display", "")),
            main_objective,
            hazards,
            warnings,
            confirmation,
        ])
    lines.append(tr("This map view cannot execute travel."))


func _button_for_layer(layer_id: StringName) -> Button:
    match layer_id:
        MapLayerIdentityValidator.LAYER_REGION_MAP:
            return region_button
        MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP:
            return tower_button
        _:
            return world_button


func _on_layer_pressed(layer_id: StringName) -> void:
    if select_layer(layer_id):
        _button_for_layer(layer_id).grab_focus()


func _on_back_pressed() -> void:
    close_menu()
