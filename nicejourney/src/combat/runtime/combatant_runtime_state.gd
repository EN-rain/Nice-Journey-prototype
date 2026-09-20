class_name CombatantRuntimeState
extends RefCounted

var actor_id: StringName = &""
var max_hp: int = 0
var current_hp: int = 0
var current_stamina: float = 0.0
var physical_defense: float = 0.0
var arcane_defense: float = 0.0
var block_supported: bool = false
var parry_supported: bool = false
var accumulated_poise: float = 0.0
var poise_threshold: float = 1.0
var interruptible: bool = true
var _status_states: Array = []


func configure(
    new_actor_id: StringName,
    authored_max_hp: int,
    authored_stamina: float,
    authored_physical_defense: float,
    authored_arcane_defense: float,
    authored_poise_threshold: float,
    authored_interruptible: bool,
    authored_block_supported: bool,
    authored_parry_supported: bool
) -> bool:
    if not StableId.is_valid(String(new_actor_id)):
        return false
    if authored_max_hp <= 0:
        return false
    for numeric: float in [authored_stamina, authored_physical_defense, authored_arcane_defense, authored_poise_threshold]:
        if not is_finite(numeric):
            return false
    if authored_stamina < 0.0 or authored_poise_threshold <= 0.0:
        return false
    actor_id = new_actor_id
    max_hp = authored_max_hp
    current_hp = authored_max_hp
    current_stamina = authored_stamina
    physical_defense = authored_physical_defense
    arcane_defense = authored_arcane_defense
    poise_threshold = authored_poise_threshold
    interruptible = authored_interruptible
    block_supported = authored_block_supported
    parry_supported = authored_parry_supported
    accumulated_poise = 0.0
    _status_states.clear()
    return true


func make_defender_snapshot(evade_window_active: bool, defense_mode: StringName, facing_covered: bool) -> Dictionary:
    return {
        "evade_window_active": evade_window_active,
        "defense_mode": defense_mode,
        "block_supported": block_supported,
        "parry_supported": parry_supported,
        "facing_covered": facing_covered,
        "current_stamina": current_stamina,
        "physical_defense": physical_defense,
        "arcane_defense": arcane_defense,
    }


func apply_direct_hit_result(result: Dictionary) -> bool:
    if is_defeated() or not bool(result.get("accepted", false)):
        return false
    var outcome: StringName = StringName(String(result.get("outcome", &"")))
    if outcome == DirectHitResolver.OUTCOME_BLOCKED or outcome == DirectHitResolver.OUTCOME_GUARD_BROKEN:
        var stamina_after: float = float(result.get("stamina_after", current_stamina))
        if not is_finite(stamina_after) or stamina_after < 0.0:
            return false
        current_stamina = stamina_after
    var hp_damage: int = int(result.get("hp_damage", 0))
    if hp_damage < 0:
        return false
    if hp_damage > 0:
        current_hp = maxi(0, current_hp - hp_damage)
    return true


func apply_poise_damage(poise_damage: float) -> Dictionary:
    if is_defeated():
        return {"accepted": false, "reason_id": &"defeated"}
    var result: Dictionary = PoiseResolver.apply_hit(
        {
            "accumulated_poise": accumulated_poise,
            "threshold": poise_threshold,
            "interruptible": interruptible,
        },
        {"poise_damage": poise_damage}
    )
    if bool(result.get("accepted", false)):
        accumulated_poise = float(result.get("accumulated_poise", accumulated_poise))
    return result


func recover_poise(recovery_amount: float, recovery_allowed: bool) -> Dictionary:
    if is_defeated():
        return {"accepted": false, "reason_id": &"defeated"}
    var result: Dictionary = PoiseResolver.recover(
        {
            "accumulated_poise": accumulated_poise,
            "threshold": poise_threshold,
            "interruptible": interruptible,
        },
        {
            "recovery_allowed": recovery_allowed,
            "recovery_amount": recovery_amount,
        }
    )
    if bool(result.get("accepted", false)):
        accumulated_poise = float(result.get("accumulated_poise", accumulated_poise))
    return result


func apply_status(application: Variant) -> Dictionary:
    if is_defeated():
        return {
            "accepted": false,
            "reason_id": &"defeated",
            "outcome": PrototypeStatusResolver.OUTCOME_REJECTED,
            "states": get_status_states(),
        }
    var result: Dictionary = PrototypeStatusResolver.apply_status(_status_states, application)
    if bool(result.get("accepted", false)):
        _status_states = (result.get("states", []) as Array).duplicate(true)
    return result.duplicate(true)


func apply_production_status(application: Variant) -> Dictionary:
    if is_defeated():
        return {
            "accepted": false,
            "reason_id": &"defeated",
            "outcome": PrototypeStatusResolver.OUTCOME_REJECTED,
            "states": get_status_states(),
            "production_missing_fields": PackedStringArray(),
            "production_known_semantics": {},
        }
    var result := PrototypeStatusResolver.apply_production_status(_status_states, application)
    if bool(result.get("accepted", false)):
        _status_states = (result.get("states", []) as Array).duplicate(true)
    return result.duplicate(true)


func advance_status_duration(elapsed_ticks: int) -> Dictionary:
    var result: Dictionary = PrototypeStatusResolver.advance_duration(_status_states, elapsed_ticks)
    if bool(result.get("accepted", false)):
        _status_states = (result.get("states", []) as Array).duplicate(true)
    return result.duplicate(true)


func restore_status_states(raw_states: Variant) -> Dictionary:
    var result: Dictionary = PrototypeStatusResolver.normalize_states(raw_states)
    if not bool(result.get("accepted", false)):
        return result.duplicate(true)
    _status_states = (result.get("states", []) as Array).duplicate(true)
    return {
        "accepted": true,
        "reason_id": &"",
        "states": get_status_states(),
    }


func get_status_states() -> Array:
    return _status_states.duplicate(true)


func get_status_execution_requests() -> Dictionary:
    return PrototypeStatusResolver.build_execution_requests(_status_states).duplicate(true)


func get_production_status_execution_requests() -> Dictionary:
    return PrototypeStatusResolver.build_production_execution_requests(_status_states).duplicate(true)


func is_defeated() -> bool:
    return current_hp <= 0


func get_debug_snapshot() -> Dictionary:
    return {
        "actor_id": actor_id,
        "max_hp": max_hp,
        "current_hp": current_hp,
        "current_stamina": current_stamina,
        "physical_defense": physical_defense,
        "arcane_defense": arcane_defense,
        "block_supported": block_supported,
        "parry_supported": parry_supported,
        "accumulated_poise": accumulated_poise,
        "poise_threshold": poise_threshold,
        "interruptible": interruptible,
        "statuses": get_status_states(),
        "defeated": is_defeated(),
    }
