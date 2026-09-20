class_name PassiveSkillRuntime
extends RefCounted

# Effect application is derived from the equipped loadout, never accumulated
# onto base stats, stored attack resources, or the durable profile snapshot.
var content: PassiveSkillsPlaytestContent = null
var _class_id: StringName = &""
var _equipped_ranks: Dictionary = {}


func bind_profile(profile: ProfileSnapshot, authored: PassiveSkillsPlaytestContent) -> bool:
    if profile == null or authored == null or not authored.validate_content().is_empty():
        return false
    if profile.skill_state.is_empty() or StringName(profile.class_id) == &"":
        return false
    var state := SkillLoadoutState.new()
    if not state.load_dictionary(profile.skill_state).is_empty() or state.class_id != StringName(profile.class_id):
        return false
    var candidate: Dictionary = {}
    for skill_id: StringName in state.passive_slots:
        var definition := SkillCatalog.get_definition(skill_id)
        if definition == null or definition.class_id != state.class_id or definition.kind != SkillDefinition.KIND_PASSIVE:
            return false
        var rank: int = state.get_rank(skill_id)
        if rank < 1 or rank > 3 or candidate.has(skill_id):
            return false
        candidate[skill_id] = rank
    if candidate.size() != SkillLoadoutState.PASSIVE_SLOT_COUNT:
        return false
    content = authored
    _class_id = state.class_id
    _equipped_ranks = candidate
    return true


func clear() -> void:
    content = null
    _class_id = &""
    _equipped_ranks.clear()


func rank_for(skill_id: StringName) -> int:
    return int(_equipped_ranks.get(skill_id, 0)) if content != null else 0


func preview_for_skill(skill_id: StringName, rank: int) -> Dictionary:
    if content == null or not content.validate_content().is_empty() or rank < 1 or rank > 3:
        return {"accepted": false, "reason_id": &"passive_content_or_rank_unavailable"}
    var definition := SkillCatalog.get_definition(skill_id)
    if definition == null or definition.kind != SkillDefinition.KIND_PASSIVE or definition.class_id != _class_id:
        return {"accepted": false, "reason_id": &"wrong_class_or_skill_kind"}
    var values: Dictionary = {}
    match skill_id:
        &"efficient_footwork":
            values = {"stamina_cost_multiplier": _at(content.efficient_footwork_stamina_cost_multiplier, rank, 1.0)}
        &"breaker":
            values = {"poise_multiplier": _at(content.breaker_poise_multiplier, rank, 1.0)}
        &"parry_recovery":
            values = {"stamina_restore_per_successful_parry": _at(content.parry_recovery_stamina_restore, rank, 0.0)}
        &"longshot":
            values = {
                "minimum_distance_px": _at(content.longshot_minimum_distance_px, rank, INF),
                "damage_multiplier": _at(content.longshot_damage_multiplier, rank, 1.0),
            }
        &"fleet_recovery":
            values = {
                "movement_stamina_cost_multiplier": _at(content.fleet_recovery_movement_stamina_cost_multiplier, rank, 1.0),
                "stamina_regeneration_multiplier": _at(content.fleet_recovery_stamina_regeneration_multiplier, rank, 1.0),
            }
        &"expose":
            values = {"visible_weak_point_multiplier": _at(content.expose_visible_weak_point_multiplier, rank, 1.0)}
        &"mana_weave":
            values = {"mana_cost_multiplier": _at(content.mana_weave_mana_cost_multiplier, rank, 1.0)}
        &"flow_recovery":
            values = {"mana_regeneration_multiplier": _at(content.flow_recovery_mana_regeneration_multiplier, rank, 1.0)}
        &"stable_casting":
            values = {"recovery_ticks_multiplier": _at(content.stable_casting_recovery_ticks_multiplier, rank, 1.0)}
    if values.is_empty():
        return {"accepted": false, "reason_id": &"passive_effect_unavailable"}
    return {
        "accepted": true,
        "playtest_placeholder": true,
        "skill_id": skill_id,
        "class_id": _class_id,
        "rank": rank,
        "values": values,
    }


func modify_action(authored: ActionDefinition) -> ActionDefinition:
    if authored == null or content == null:
        return authored
    var stamina_multiplier := _stamina_cost_multiplier()
    var mana_multiplier := _mana_cost_multiplier()
    var recovery_multiplier := 1.0
    if _class_id == &"mage" and String(authored.action_id).begins_with("action:playtest:"):
        var name := StringName(String(authored.action_id).trim_prefix("action:playtest:"))
        var definition := SkillCatalog.get_definition(name)
        if definition != null and definition.class_id == &"mage" and definition.kind == SkillDefinition.KIND_ACTIVE:
            recovery_multiplier = _at(content.stable_casting_recovery_ticks_multiplier, rank_for(&"stable_casting"), 1.0)
    var cost_multiplier := 1.0
    if authored.cost_resource == &"stamina":
        cost_multiplier = stamina_multiplier
    elif authored.cost_resource == &"mana":
        cost_multiplier = mana_multiplier
    if is_equal_approx(cost_multiplier, 1.0) and is_equal_approx(recovery_multiplier, 1.0):
        return authored
    var result := authored.duplicate(true) as ActionDefinition
    result.cost_amount = authored.cost_amount * cost_multiplier
    if authored.recovery_ticks > 0 and not is_equal_approx(recovery_multiplier, 1.0):
        result.recovery_ticks = maxi(1, roundi(float(authored.recovery_ticks) * recovery_multiplier))
    return result


func modify_movement_stamina_cost(base_cost: float) -> float:
    if not is_finite(base_cost) or base_cost < 0.0:
        return base_cost
    if _class_id == &"melee":
        return base_cost * _at(content.efficient_footwork_stamina_cost_multiplier if content != null else PackedFloat32Array(), rank_for(&"efficient_footwork"), 1.0)
    if _class_id == &"ranged":
        return base_cost * _at(content.fleet_recovery_movement_stamina_cost_multiplier if content != null else PackedFloat32Array(), rank_for(&"fleet_recovery"), 1.0)
    return base_cost


func modify_stamina_regeneration(base_per_second: float) -> float:
    if not is_finite(base_per_second) or base_per_second < 0.0 or content == null:
        return base_per_second
    return base_per_second * _at(content.fleet_recovery_stamina_regeneration_multiplier, rank_for(&"fleet_recovery"), 1.0)


func modify_mana_regeneration(base_per_tick: float) -> float:
    if not is_finite(base_per_tick) or base_per_tick < 0.0 or content == null:
        return base_per_tick
    return base_per_tick * _at(content.flow_recovery_mana_regeneration_multiplier, rank_for(&"flow_recovery"), 1.0)


func parry_recovery_stamina_gain() -> float:
    if content == null:
        return 0.0
    return _at(content.parry_recovery_stamina_restore, rank_for(&"parry_recovery"), 0.0)


func modify_attack_payload(authored_payload: Dictionary, origin: Vector2,
    target: Vector2, visible_weak_point: bool) -> Dictionary:
    var payload := authored_payload.duplicate(true)
    if content == null:
        return payload
    if _class_id == &"melee" and rank_for(&"breaker") > 0 and payload.has("poise_damage"):
        payload["poise_damage"] = float(payload["poise_damage"]) * _at(content.breaker_poise_multiplier, rank_for(&"breaker"), 1.0)
    if _class_id == &"ranged":
        var longshot_rank := rank_for(&"longshot")
        if longshot_rank > 0 and origin.is_finite() and target.is_finite():
            var minimum := _at(content.longshot_minimum_distance_px, longshot_rank, INF)
            if origin.distance_squared_to(target) >= minimum * minimum and payload.has("raw_damage"):
                payload["raw_damage"] = float(payload["raw_damage"]) * _at(content.longshot_damage_multiplier, longshot_rank, 1.0)
        if visible_weak_point and bool(payload.get("weak_point_triggered", false)) and rank_for(&"expose") > 0:
            payload["weak_point_multiplier"] = float(payload.get("weak_point_multiplier", 1.0)) * _at(content.expose_visible_weak_point_multiplier, rank_for(&"expose"), 1.0)
    return payload


func _stamina_cost_multiplier() -> float:
    if content == null or _class_id != &"melee":
        return 1.0
    return _at(content.efficient_footwork_stamina_cost_multiplier, rank_for(&"efficient_footwork"), 1.0)


func _mana_cost_multiplier() -> float:
    if content == null or _class_id != &"mage":
        return 1.0
    return _at(content.mana_weave_mana_cost_multiplier, rank_for(&"mana_weave"), 1.0)


static func _at(values: PackedFloat32Array, rank: int, fallback: float) -> float:
    return values[rank - 1] if rank >= 1 and rank <= values.size() else fallback
