class_name HealthComponent
extends Node

signal health_changed(current: int, maximum: int)
signal defeated()

@export var tuning: HealthTuning

var current_hp: int = 0

func _ready() -> void:
    if tuning == null or tuning.max_hp <= 0:
        push_error("HealthComponent requires valid HealthTuning data")
        return
    current_hp = tuning.max_hp
    health_changed.emit(current_hp, tuning.max_hp)

func get_max_hp() -> int:
    return 0 if tuning == null else tuning.max_hp

func set_current_hp(value: int) -> bool:
    if tuning == null or tuning.max_hp <= 0 or value < 0:
        return false
    var before := current_hp
    current_hp = clampi(value, 0, tuning.max_hp)
    health_changed.emit(current_hp, tuning.max_hp)
    if before > 0 and current_hp == 0:
        defeated.emit()
    return true

func apply_damage(amount: int) -> bool:
    if amount < 0 or current_hp <= 0:
        return false
    return set_current_hp(maxi(0, current_hp - amount))

func restore_full() -> void:
    if tuning == null:
        return
    set_current_hp(tuning.max_hp)

func is_defeated() -> bool:
    return current_hp <= 0

func capture_safe_state() -> Dictionary:
    return {
        "current": current_hp,
        "maximum_at_capture": get_max_hp(),
    }

func restore_safe_state(data: Dictionary) -> bool:
    if tuning == null or tuning.max_hp <= 0:
        return false
    var current_variant: Variant = data.get("current", null)
    if typeof(current_variant) != TYPE_INT and typeof(current_variant) != TYPE_FLOAT:
        return false
    var current_float := float(current_variant)
    if not is_finite(current_float) or current_float < 0.0 or not is_equal_approx(current_float, round(current_float)):
        return false
    return set_current_hp(int(current_float))
