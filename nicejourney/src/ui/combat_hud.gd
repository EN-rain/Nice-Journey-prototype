class_name CombatHud
extends CanvasLayer

const QUEST_TRACKER_VIEW_SERVICE_SCRIPT: Script = preload("res://src/ui/quest_tracker_view_service.gd")
const SKILL_HUD_VIEW_SERVICE_SCRIPT: Script = preload("res://src/ui/skill_hud_view_service.gd")
const MAP_VIEW_SERVICE_SCRIPT: Script = preload("res://src/world/map_view_service.gd")
const UI_ICON_CATALOG: Resource = preload("res://src/ui/presentation/ui_icon_catalog.tres")

@onready var root_control: Control = $Root
@onready var context_label: Label = $Root/Panel/Layout/Context
@onready var hp_row: HBoxContainer = $Root/Panel/Layout/HPRow
@onready var hp_bar: ProgressBar = $Root/Panel/Layout/HPRow/Bar
@onready var hp_value: Label = $Root/Panel/Layout/HPRow/Value
@onready var stamina_row: HBoxContainer = $Root/Panel/Layout/StaminaRow
@onready var stamina_bar: ProgressBar = $Root/Panel/Layout/StaminaRow/Bar
@onready var stamina_value: Label = $Root/Panel/Layout/StaminaRow/Value
@onready var mana_row: HBoxContainer = $Root/Panel/Layout/ManaRow
@onready var mana_bar: ProgressBar = $Root/Panel/Layout/ManaRow/Bar
@onready var mana_value: Label = $Root/Panel/Layout/ManaRow/Value
@onready var state_label: Label = $Root/Panel/Layout/State
@onready var cooldown_label: Label = $Root/Panel/Layout/Cooldowns
@onready var burn_status_row: HBoxContainer = $Root/Panel/Layout/BurnStatus
@onready var burn_status_icon: TextureRect = $Root/Panel/Layout/BurnStatus/Icon
@onready var burn_status_label: Label = $Root/Panel/Layout/BurnStatus/Label
@onready var slow_status_row: HBoxContainer = $Root/Panel/Layout/SlowStatus
@onready var slow_status_icon: TextureRect = $Root/Panel/Layout/SlowStatus/Icon
@onready var slow_status_label: Label = $Root/Panel/Layout/SlowStatus/Label
@onready var quest_label: Label = $Root/Panel/Layout/Quest
@onready var skills_header: Label = $Root/Panel/Layout/SkillsHeader
@onready var active_skill_1_icon: TextureRect = $Root/Panel/Layout/ActiveSkill1/Icon
@onready var active_skill_1_label: Label = $Root/Panel/Layout/ActiveSkill1/Label
@onready var active_skill_2_icon: TextureRect = $Root/Panel/Layout/ActiveSkill2/Icon
@onready var active_skill_2_label: Label = $Root/Panel/Layout/ActiveSkill2/Label
@onready var minimap_panel: PanelContainer = $Root/MinimapPanel
@onready var minimap_canvas: Control = $Root/MinimapPanel/Layout/Canvas

var _profile: ProfileSnapshot = null
var _player: PlayerController = null
var _combat_runtime: ClassCombatRuntime = null
var _tower_floor_session_host: Node = null
var _catalog_valid: bool = false
var _playtest_skills: ActiveSkillsPlaytest = null
var _skill_prerequisites_provider: Callable = Callable()
var _last_snapshot: Dictionary = {}


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    _catalog_valid = PrototypeTowerFloorCatalog.validate_catalog().is_empty()
    _reset_presentation()


func configure(
    player: PlayerController,
    combat_runtime: ClassCombatRuntime,
    tower_floor_session_host: Node,
    profile: ProfileSnapshot = null,
    playtest_skills: ActiveSkillsPlaytest = null,
    skill_prerequisites_provider: Callable = Callable()
) -> bool:
    if player == null or combat_runtime == null or tower_floor_session_host == null:
        return false
    _player = player
    _combat_runtime = combat_runtime
    _tower_floor_session_host = tower_floor_session_host
    _profile = profile
    _playtest_skills = playtest_skills if playtest_skills != null and playtest_skills.validate_content().is_empty() else null
    _skill_prerequisites_provider = skill_prerequisites_provider
    refresh_from_runtime()
    return true


func set_profile(profile: ProfileSnapshot) -> void:
    _profile = profile
    refresh_from_runtime()


func current_snapshot() -> Dictionary:
    return _last_snapshot.duplicate(true)


func refresh_from_runtime() -> bool:
    if _player == null or _combat_runtime == null or _tower_floor_session_host == null:
        _last_snapshot.clear()
        _reset_presentation()
        return false

    var floor_id := _active_floor_id()
    var cooldowns: Dictionary = {}
    if _combat_runtime.action_state_machine != null:
        cooldowns = _combat_runtime.action_state_machine.capture_cooldown_state()

    var snapshot: Dictionary = {
        "hp": _player.health.current_hp,
        "hp_max": _player.health.get_max_hp(),
        "stamina": _player.stamina.current_stamina,
        "stamina_max": _player.stamina.get_max_stamina(),
        "mana_visible": _combat_runtime.has_mana(),
        "mana": _combat_runtime.get_mana(),
        "mana_max": _combat_runtime.get_max_mana(),
        "defense_mode": _combat_runtime.get_defense_mode(),
        "cooldowns": cooldowns.duplicate(true),
        "statuses": _player_status_states(),
        "floor_id": floor_id,
        "recommended_level": 0,
        "danger_display": "",
        "quest_tracker": {},
        "skill_loadout": {},
        "minimap": {},
    }

    if _profile != null:
        snapshot["quest_tracker"] = QUEST_TRACKER_VIEW_SERVICE_SCRIPT.build_current_tower_primary(_profile, floor_id)
        var actions := _playtest_skills.action_definitions_by_mechanic() if _playtest_skills != null else {}
        var prereqs: Dictionary = {}
        if _skill_prerequisites_provider.is_valid():
            var raw: Variant = _skill_prerequisites_provider.call()
            if raw is Dictionary:
                prereqs = raw as Dictionary
        snapshot["skill_loadout"] = SKILL_HUD_VIEW_SERVICE_SCRIPT.build_active_slots(
            _profile, actions, prereqs, _combat_runtime.action_state_machine,
            _playtest_skills, _combat_runtime.get_passive_skill_runtime()
        )
        snapshot["minimap"] = _build_minimap_snapshot(floor_id)

    if floor_id > 0 and _catalog_valid and _profile != null:
        var entry := PrototypeTowerFloorCatalog.get_entry(floor_id)
        if not entry.is_empty():
            var recommended_level := int(entry.get("recommended_level", 0))
            if recommended_level > 0:
                var rank: DangerEvaluator.Rank = DangerEvaluator.evaluate_rank(_profile.level, recommended_level)
                snapshot["recommended_level"] = recommended_level
                snapshot["danger_display"] = DangerEvaluator.display_name(rank)

    _last_snapshot = snapshot.duplicate(true)
    _apply_snapshot(snapshot)
    return true


func _process(_delta: float) -> void:
    refresh_from_runtime()


func _active_floor_id() -> int:
    if _tower_floor_session_host == null or not is_instance_valid(_tower_floor_session_host):
        return 0
    var value: Variant = _tower_floor_session_host.get("active_floor_id")
    return int(value) if typeof(value) == TYPE_INT else 0


func _apply_snapshot(snapshot: Dictionary) -> void:
    var hp_max := maxi(1, int(snapshot.get("hp_max", 1)))
    var hp := clampi(int(snapshot.get("hp", 0)), 0, hp_max)
    hp_bar.max_value = hp_max
    hp_bar.value = hp
    hp_value.text = "%d/%d" % [hp, hp_max]

    var stamina_max := maxf(0.001, float(snapshot.get("stamina_max", 0.001)))
    var stamina := clampf(float(snapshot.get("stamina", 0.0)), 0.0, stamina_max)
    stamina_bar.max_value = stamina_max
    stamina_bar.value = stamina
    stamina_value.text = "%d/%d" % [roundi(stamina), roundi(stamina_max)]

    var mana_visible := bool(snapshot.get("mana_visible", false))
    mana_row.visible = mana_visible
    if mana_visible:
        var mana_max := maxf(0.001, float(snapshot.get("mana_max", 0.001)))
        var mana := clampf(float(snapshot.get("mana", 0.0)), 0.0, mana_max)
        mana_bar.max_value = mana_max
        mana_bar.value = mana
        mana_value.text = "%d/%d" % [roundi(mana), roundi(mana_max)]

    var floor_id := int(snapshot.get("floor_id", 0))
    var recommended_level := int(snapshot.get("recommended_level", 0))
    var danger_display := String(snapshot.get("danger_display", ""))
    if floor_id > 0:
        if recommended_level > 0 and not danger_display.is_empty():
            context_label.text = tr("Tower Floor %d | Recommended Lv.%d | %s") % [floor_id, recommended_level, danger_display]
        else:
            context_label.text = tr("Tower Floor %d") % floor_id
    else:
        context_label.text = tr("Exploration")

    var defense_mode := StringName(snapshot.get("defense_mode", DirectHitResolver.DEFENSE_NONE))
    state_label.text = tr("Defense: %s") % String(defense_mode).to_upper()
    cooldown_label.text = _cooldown_text(snapshot.get("cooldowns", {}) as Dictionary)
    _apply_statuses(snapshot.get("statuses", []) as Array)
    _apply_quest_tracker(snapshot.get("quest_tracker", {}) as Dictionary)
    _apply_skill_loadout(snapshot.get("skill_loadout", {}) as Dictionary)
    _apply_minimap(snapshot.get("minimap", {}) as Dictionary)


func _apply_quest_tracker(tracker: Dictionary) -> void:
    if tracker.is_empty() or not bool(tracker.get("available", false)):
        quest_label.visible = false
        quest_label.text = ""
        return
    quest_label.visible = true
    var quest_id := String(tracker.get("quest_id", &""))
    var stage_id := String(tracker.get("stage_id", &""))
    var prefix := tr("Objective: %s | %s") % [quest_id, stage_id]
    var progress_kind := StringName(tracker.get("progress_kind", QUEST_TRACKER_VIEW_SERVICE_SCRIPT.PROGRESS_UNBOUND))
    match progress_kind:
        QUEST_TRACKER_VIEW_SERVICE_SCRIPT.PROGRESS_OBJECTIVES_COMPLETE:
            quest_label.text = "%s | %s" % [prefix, tr("Objectives complete")]
        QUEST_TRACKER_VIEW_SERVICE_SCRIPT.PROGRESS_ANNIHILATION:
            quest_label.text = "%s | %s" % [prefix, tr("Defeated %d/%d") % [int(tracker.get("defeated_count", 0)), int(tracker.get("required_count", 0))]]
        QUEST_TRACKER_VIEW_SERVICE_SCRIPT.PROGRESS_ESCORT:
            var escort_text := tr("Route %d/%d") % [int(tracker.get("next_route_index", 0)), int(tracker.get("route_count", 0))]
            if bool(tracker.get("wait_requested", false)):
                escort_text += tr(" | Wait")
            quest_label.text = "%s | %s" % [prefix, escort_text]
        QUEST_TRACKER_VIEW_SERVICE_SCRIPT.PROGRESS_TOWER_DEFENSE:
            quest_label.text = "%s | %s" % [prefix, tr("Waves %d/%d | Objective HP %d/%d") % [
                int(tracker.get("completed_wave_count", 0)),
                int(tracker.get("wave_count", 0)),
                int(tracker.get("objective_current_hp", 0)),
                int(tracker.get("objective_max_hp", 0)),
            ]]
        QUEST_TRACKER_VIEW_SERVICE_SCRIPT.PROGRESS_BOSS:
            quest_label.text = "%s | %s" % [prefix, tr("Boss defeated: %s") % (tr("Yes") if bool(tracker.get("boss_defeated", false)) else tr("No"))]
        _:
            quest_label.text = "%s | %s" % [prefix, tr("Objective state pending")]


func _apply_skill_loadout(loadout: Dictionary) -> void:
    var accepted := bool(loadout.get("accepted", false))
    skills_header.visible = accepted
    var rows: Array[Dictionary] = [
        {"icon": active_skill_1_icon, "label": active_skill_1_label},
        {"icon": active_skill_2_icon, "label": active_skill_2_label},
    ]
    var slots := loadout.get("active_slots", []) as Array
    for slot_index: int in range(rows.size()):
        var icon := rows[slot_index]["icon"] as TextureRect
        var label := rows[slot_index]["label"] as Label
        var row := icon.get_parent() as Control
        if not accepted or slot_index >= slots.size() or not slots[slot_index] is Dictionary:
            row.visible = false
            icon.texture = null
            label.text = ""
            continue
        row.visible = true
        var slot := slots[slot_index] as Dictionary
        var skill_id := StringName(slot.get("skill_id", &""))
        var display_name := String(slot.get("display_name", String(skill_id)))
        var rank := int(slot.get("rank", 0))
        var temporary := bool(slot.get("temporary", false))
        var runtime_suffix := tr(" — Unavailable")
        if bool(slot.get("runtime_action_available", false)):
            if bool(slot.get("cooldown_state_available", false)) and int(slot.get("cooldown_ticks", 0)) > 0:
                runtime_suffix = tr(" — PLAYTEST Cooldown %dt") % int(slot.get("cooldown_ticks", 0))
            else:
                runtime_suffix = tr(" — PLAYTEST Ready")
        elif bool(slot.get("production_runtime_action_available", false)):
            runtime_suffix = tr(" — Production ready")
        label.text = tr("Active %d — %s R%d%s%s") % [
            slot_index + 1,
            display_name,
            rank,
            tr(" — Temporary") if temporary else "",
            runtime_suffix,
        ]
        icon.texture = null
        var icon_id := StringName(slot.get("icon_id", &""))
        if icon_id != &"":
            var icon_profile: Variant = UI_ICON_CATALOG.call("get_profile", icon_id)
            if icon_profile != null:
                var texture_variant: Variant = icon_profile.get("texture")
                if texture_variant is Texture2D:
                    icon.texture = texture_variant as Texture2D


func _build_minimap_snapshot(floor_id: int) -> Dictionary:
    if _profile == null or floor_id <= 0 or _player == null or _tower_floor_session_host == null:
        return {}
    if not _tower_floor_session_host is Node2D:
        return {}
    var tower_map: Dictionary = MAP_VIEW_SERVICE_SCRIPT.build_layer(
        _profile,
        MapLayerIdentityValidator.LAYER_TOWER_FLOOR_MAP,
        floor_id
    )
    if not bool(tower_map.get("accepted", false)) or not bool(tower_map.get("available", false)):
        return {}
    var host := _tower_floor_session_host as Node2D
    var local_position := host.to_local(_player.global_position)
    var tile_size := float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE)
    if tile_size <= 0.0:
        return {}
    return {
        "available": true,
        "room_entries": (tower_map.get("room_entries", []) as Array).duplicate(true),
        "room_connections": (tower_map.get("room_connections", []) as Array).duplicate(true),
        "risk_markers": (tower_map.get("risk_markers", []) as Array).duplicate(true),
        "checkpoint_markers": (tower_map.get("checkpoint_markers", []) as Array).duplicate(true),
        "player_tile": local_position / tile_size,
    }


func _apply_minimap(snapshot: Dictionary) -> void:
    if minimap_panel == null or minimap_canvas == null:
        return
    minimap_panel.visible = false
    minimap_canvas.call("clear_rooms")
    if snapshot.is_empty() or not bool(snapshot.get("available", false)):
        return
    var room_entries := snapshot.get("room_entries", []) as Array
    if room_entries.is_empty() or not bool(minimap_canvas.call("set_room_entries", room_entries)):
        return
    if not bool(minimap_canvas.call("set_room_connections", snapshot.get("room_connections", []) as Array)):
        minimap_canvas.call("clear_rooms")
        return
    if not bool(minimap_canvas.call("set_risk_markers", snapshot.get("risk_markers", []) as Array)):
        minimap_canvas.call("clear_rooms")
        return
    if not bool(minimap_canvas.call("set_checkpoint_markers", snapshot.get("checkpoint_markers", []) as Array)):
        minimap_canvas.call("clear_rooms")
        return
    minimap_canvas.call("clear_player_marker")
    var player_tile: Variant = snapshot.get("player_tile", null)
    if player_tile is Vector2 or player_tile is Vector2i:
        minimap_canvas.call("set_player_marker", player_tile)
    minimap_panel.visible = true


func _cooldown_text(cooldowns: Dictionary) -> String:
    if cooldowns.is_empty():
        return tr("Cooldowns: Ready")
    var action_ids: Array = cooldowns.keys()
    action_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    var entries := PackedStringArray()
    for raw_id: Variant in action_ids:
        var action_id := StringName(String(raw_id))
        var remaining := int(cooldowns.get(raw_id, 0))
        if not StableId.is_valid(String(action_id)) or remaining <= 0:
            continue
        entries.append("%s %dt" % [String(action_id), remaining])
    return tr("Cooldowns: Ready") if entries.is_empty() else tr("Cooldowns: %s") % ", ".join(entries)


func _player_status_states() -> Array:
    if _player == null or _player.runtime_presentation_binder == null:
        return []
    var binder: PlayerRuntimePresentationBinder = _player.runtime_presentation_binder
    if binder.bound_runtime == null or binder.bound_actor_id == &"":
        return []
    return binder.bound_runtime.get_status_states(binder.bound_actor_id)


func _apply_statuses(statuses: Array) -> void:
    _apply_status_behavior(
        PrototypeStatusResolver.BEHAVIOR_BURN,
        &"status_burn",
        tr("Burn"),
        statuses,
        burn_status_row,
        burn_status_icon,
        burn_status_label
    )
    _apply_status_behavior(
        PrototypeStatusResolver.BEHAVIOR_SLOW,
        &"status_slow",
        tr("Slow"),
        statuses,
        slow_status_row,
        slow_status_icon,
        slow_status_label
    )


func _apply_status_behavior(
    behavior: StringName,
    icon_id: StringName,
    display_name: String,
    statuses: Array,
    row: HBoxContainer,
    icon: TextureRect,
    label: Label
) -> void:
    var matching: Array[Dictionary] = []
    for raw_state: Variant in statuses:
        if not raw_state is Dictionary:
            continue
        var state := raw_state as Dictionary
        if StringName(String(state.get("behavior", &""))) == behavior:
            matching.append(state.duplicate(true))
    row.visible = not matching.is_empty()
    icon.texture = null
    label.text = ""
    if matching.is_empty():
        return
    var icon_profile: Variant = UI_ICON_CATALOG.call("get_profile", icon_id)
    if icon_profile != null:
        var texture_variant: Variant = icon_profile.get("texture")
        if texture_variant is Texture2D:
            icon.texture = texture_variant as Texture2D
    var entries := PackedStringArray()
    for state: Dictionary in matching:
        entries.append("%s %dt" % [
            String(state.get("status_id", &"")),
            int(state.get("remaining_ticks", 0)),
        ])
    label.text = "%s: %s" % [display_name, ", ".join(entries)]


func _reset_presentation() -> void:
    context_label.text = tr("Exploration")
    hp_bar.max_value = 1.0
    hp_bar.value = 0.0
    hp_value.text = "0/0"
    stamina_bar.max_value = 1.0
    stamina_bar.value = 0.0
    stamina_value.text = "0/0"
    mana_row.visible = false
    mana_bar.max_value = 1.0
    mana_bar.value = 0.0
    mana_value.text = "0/0"
    state_label.text = tr("Defense: NONE")
    cooldown_label.text = tr("Cooldowns: Ready")
    burn_status_row.visible = false
    burn_status_icon.texture = null
    burn_status_label.text = ""
    slow_status_row.visible = false
    slow_status_icon.texture = null
    slow_status_label.text = ""
    quest_label.visible = false
    quest_label.text = ""
    skills_header.visible = false
    active_skill_1_icon.get_parent().visible = false
    active_skill_1_icon.texture = null
    active_skill_1_label.text = ""
    active_skill_2_icon.get_parent().visible = false
    active_skill_2_icon.texture = null
    active_skill_2_label.text = ""
    if minimap_panel != null:
        minimap_panel.visible = false
    if minimap_canvas != null:
        minimap_canvas.call("clear_rooms")
