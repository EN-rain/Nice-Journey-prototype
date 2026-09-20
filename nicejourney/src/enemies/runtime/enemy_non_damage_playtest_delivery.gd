class_name EnemyNonDamagePlaytestDelivery
extends Node2D

# Non-damaging signature owner. The same authenticated active-window signal
# used by enemy attacks drives these effects; no AI decision implies a hit.
signal non_damage_resolved(encounter_id: StringName, actor_id: StringName, result: Dictionary)

const REASON_INVALID_CONTEXT: StringName = &"non_damage_invalid_context"
const REASON_NO_ALLY: StringName = &"non_damage_no_eligible_ally"
const REASON_UNBUDGETED_SUMMON: StringName = &"non_damage_reinforcement_budget_unavailable"

@export var content: EnemyNonDamagePlaytestTuning
@export var status_tuning: StatusPlaytestTuning

var host: TowerEncounterSessionHost
var player: PlayerController
var last_result: Dictionary = {}
var _wards: Dictionary = {}
var _fields: Dictionary = {}
var _processed_actions: Dictionary = {}


func configure(source_host: TowerEncounterSessionHost, source_player: PlayerController) -> bool:
    if (
        source_host == null or source_player == null or content == null
        or not content.validate_tuning(status_tuning).is_empty()
    ):
        return false
    if not source_host.set_reinforcement_tuning(content.reinforcement_tuning):
        return false
    reset()
    host = source_host
    player = source_player
    host.enemy_active_delivery_window_opened.connect(_on_active_window)
    return true


func reset() -> void:
    if host != null and is_instance_valid(host) and host.enemy_active_delivery_window_opened.is_connected(_on_active_window):
        host.enemy_active_delivery_window_opened.disconnect(_on_active_window)
    for key: Variant in _wards.keys():
        _release_ward(key)
    for entry: Dictionary in _fields.values():
        _dispose_marker(entry.get("marker") as Node2D)
    _fields.clear()
    _processed_actions.clear()
    host = null
    player = null


func _on_active_window(encounter_id: StringName, context: Dictionary) -> void:
    last_result = resolve_active_window(encounter_id, context)
    if bool(last_result.get("attempted", false)):
        non_damage_resolved.emit(encounter_id, StringName(String(context.get("actor_id", &""))), last_result.duplicate(true))


func resolve_active_window(encounter_id: StringName, context: Dictionary) -> Dictionary:
    if host == null or player == null or not bool(context.get("accepted", false)) or not host.is_encounter_active(encounter_id):
        return _rejected(REASON_INVALID_CONTEXT)
    if StringName(String(context.get("encounter_id", &""))) != encounter_id:
        return _rejected(REASON_INVALID_CONTEXT)
    var actor_id := StringName(String(context.get("actor_id", &"")))
    var action_id := StringName(String(context.get("action_id", &"")))
    var action_instance_id := int(context.get("action_instance_id", 0))
    var runtime := host.get_archetype_runtime(encounter_id, actor_id)
    var encounter := host.get_encounter_runtime(encounter_id)
    var driver := host.get_action_phase_driver(encounter_id, actor_id)
    var visual := host.get_visuals_by_actor(encounter_id).get(actor_id) as Node2D
    if (
        runtime == null or encounter == null or driver == null or visual == null
        or not is_instance_valid(visual) or runtime.definition == null
        or runtime.phase_id != EnemyArchetypeRuntime.PHASE_ACTIVE
        or action_instance_id <= 0 or driver.action_instance_id != action_instance_id
        or runtime.definition.signature_action_id != action_id
        or encounter.get_combatant(actor_id) == null
        or encounter.get_combatant(actor_id).is_defeated()
    ):
        return _rejected(REASON_INVALID_CONTEXT)
    var ticket := "%s/%s" % [String(encounter_id), String(actor_id)]
    var last := _processed_actions.get(ticket, {}) as Dictionary
    if last.get("encounter") == encounter and int(last.get("instance_id", 0)) == action_instance_id:
        return _rejected(&"non_damage_duplicate_action")
    _processed_actions[ticket] = {"encounter": encounter, "instance_id": action_instance_id}
    match runtime.definition.archetype_id:
        &"support":
            if action_id == &"action:support_ally_ward":
                return _apply_support_ward(encounter_id, actor_id, encounter, visual.global_position)
        &"controller_disruptor":
            if action_id == &"action:controller_slow_field":
                if not bool(context.get("has_committed_observation_position", false)):
                    return _rejected(&"non_damage_observation_missing")
                var target: Variant = context.get("committed_observation_position", null)
                if not target is Vector2 or not (target as Vector2).is_finite():
                    return _rejected(&"non_damage_observation_invalid")
                return _start_controller_field(encounter_id, actor_id, runtime.target_id, encounter, visual.global_position, target as Vector2)
        &"summoner":
            if action_id == &"action:summoner_reinforcement_call":
                if not host.has_reinforcement_budget(encounter_id, actor_id):
                    return _rejected(REASON_UNBUDGETED_SUMMON)
                var spawned := host.spawn_summoner_reinforcement(encounter_id, actor_id, context)
                spawned["attempted"] = true
                return spawned
    return _rejected(&"non_damage_unrecognized_signature")


func _apply_support_ward(encounter_id: StringName, caster_id: StringName, encounter: CombatEncounterRuntime, origin: Vector2) -> Dictionary:
    var visuals := host.get_visuals_by_actor(encounter_id)
    var closest := INF
    var selected: StringName = &""
    var selected_visual: Node2D
    var sorted_ids := visuals.keys()
    sorted_ids.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
    for raw_id: Variant in sorted_ids:
        var candidate := StringName(String(raw_id))
        var ally := encounter.get_combatant(candidate)
        var ally_visual := visuals.get(raw_id) as Node2D
        var key := "%s/%s" % [String(encounter_id), String(candidate)]
        if (
            candidate == caster_id or ally == null or ally.is_defeated()
            or ally_visual == null or not is_instance_valid(ally_visual) or _wards.has(key)
        ):
            continue
        var distance := origin.distance_to(ally_visual.global_position)
        if distance <= content.ward_range_px and distance < closest:
            closest = distance
            selected = candidate
            selected_visual = ally_visual
    if selected == &"":
        return _rejected(REASON_NO_ALLY)
    var target := encounter.get_combatant(selected)
    var marker := content.ward_marker_scene.instantiate() as Node2D
    if marker == null:
        return _rejected(&"non_damage_ward_marker_invalid")
    add_child(marker)
    marker.global_position = selected_visual.global_position
    target.physical_defense += content.ward_defense_bonus
    target.arcane_defense += content.ward_defense_bonus
    var ticket := "%s/%s" % [String(encounter_id), String(selected)]
    _wards[ticket] = {
        "encounter_id": encounter_id, "caster_id": caster_id, "target_id": selected,
        "target": target, "visual": selected_visual, "marker": marker,
        "bonus": content.ward_defense_bonus, "ticks": content.ward_duration_ticks,
    }
    return {"accepted": true, "attempted": true, "mode": &"ward", "target_id": selected,
        "defense_bonus": content.ward_defense_bonus, "duration_ticks": content.ward_duration_ticks}


func _start_controller_field(encounter_id: StringName, caster_id: StringName, player_id: StringName, encounter: CombatEncounterRuntime,
    origin: Vector2, target: Vector2) -> Dictionary:
    if origin.distance_to(target) > content.control_cast_range_px or not target.is_finite() or encounter.get_combatant(player_id) == null:
        return _rejected(&"non_damage_target_out_of_range")
    var key := "%s/%s" % [String(encounter_id), String(caster_id)]
    if _fields.has(key):
        _dispose_marker((_fields[key] as Dictionary).get("marker") as Node2D)
        _fields.erase(key)
    var marker := content.control_field_marker_scene.instantiate() as Node2D
    if marker == null:
        return _rejected(&"non_damage_field_marker_invalid")
    add_child(marker)
    marker.global_position = target
    marker.scale = Vector2.ONE * (content.control_field_radius_px / 50.0)
    _fields[key] = {
        "encounter_id": encounter_id, "caster_id": caster_id, "target": target,
        "player_id": player_id,
        "marker": marker, "ticks": content.control_field_duration_ticks, "since_apply": content.control_slow_apply_interval_ticks,
    }
    return {"accepted": true, "attempted": true, "mode": &"slow_field",
        "center": target, "radius_px": content.control_field_radius_px,
        "duration_ticks": content.control_field_duration_ticks}


func advance_fixed_tick() -> void:
    for key: Variant in _wards.keys():
        var ward := _wards.get(key, {}) as Dictionary
        if ward.is_empty():
            continue
        var visual := ward.get("visual") as Node2D
        var marker := ward.get("marker") as Node2D
        var encounter_id := StringName(String(ward.get("encounter_id", &"")))
        if host == null or not host.is_encounter_active(encounter_id) or visual == null or not is_instance_valid(visual):
            _release_ward(key)
            continue
        if marker != null and is_instance_valid(marker):
            marker.global_position = visual.global_position
        ward["ticks"] = int(ward["ticks"]) - 1
        if int(ward["ticks"]) <= 0:
            _release_ward(key)
    for key: Variant in _fields.keys():
        var field := _fields.get(key, {}) as Dictionary
        if field.is_empty():
            continue
        var encounter_id := StringName(String(field.get("encounter_id", &"")))
        var encounter := host.get_encounter_runtime(encounter_id) if host != null else null
        var caster := encounter.get_combatant(StringName(String(field.get("caster_id", &"")))) if encounter != null else null
        var target_id := StringName(String(field.get("player_id", &"")))
        var target := encounter.get_combatant(target_id) if encounter != null else null
        if (
            host == null or not host.is_encounter_active(encounter_id)
            or caster == null or caster.is_defeated() or target == null or target.is_defeated()
            or player == null or not is_instance_valid(player)
        ):
            _dispose_marker(field.get("marker") as Node2D)
            _fields.erase(key)
            continue
        field["ticks"] = int(field["ticks"]) - 1
        field["since_apply"] = int(field["since_apply"]) + 1
        if (
            player.global_position.distance_to(field.get("target", Vector2.INF)) <= content.control_field_radius_px
            and int(field["since_apply"]) >= content.control_slow_apply_interval_ticks
        ):
            # Source-scoped identity preserves separate Controller fields while
            # using the same Inspector-authored Slow strength and duration.
            var application := status_tuning.application(
                PrototypeStatusResolver.BEHAVIOR_SLOW, StringName(String(field["caster_id"])))
            application["duration_ticks"] = content.control_slow_refresh_ticks
            var status_result := encounter.apply_status_to_target(target_id, application)
            if bool(status_result.get("accepted", false)):
                field["since_apply"] = 0
        if int(field["ticks"]) <= 0:
            _dispose_marker(field.get("marker") as Node2D)
            _fields.erase(key)


func _physics_process(_delta: float) -> void:
    if host != null:
        advance_fixed_tick()


func _release_ward(key: Variant) -> void:
    var ward := _wards.get(key, {}) as Dictionary
    if ward.is_empty():
        return
    var target := ward.get("target") as CombatantRuntimeState
    if target != null:
        target.physical_defense -= float(ward.get("bonus", 0.0))
        target.arcane_defense -= float(ward.get("bonus", 0.0))
    _dispose_marker(ward.get("marker") as Node2D)
    _wards.erase(key)


func _dispose_marker(marker: Node2D) -> void:
    if marker != null and is_instance_valid(marker):
        marker.queue_free()


func _rejected(reason_id: StringName) -> Dictionary:
    return {"accepted": false, "attempted": true, "reason_id": reason_id}


func _exit_tree() -> void:
    reset()
