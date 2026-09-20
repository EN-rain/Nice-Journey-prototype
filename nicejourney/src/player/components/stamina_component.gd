class_name StaminaComponent
extends Node

signal stamina_changed(current: float, maximum: float)

@export var tuning: StaminaTuning

var current_stamina: float = 0.0
var _regeneration_block_time: float = 0.0
var _regeneration_modifier: Callable = Callable()


func set_regeneration_modifier(modifier: Callable) -> void:
    _regeneration_modifier = modifier

func _ready() -> void:
    if tuning == null:
        push_error("StaminaComponent requires StaminaTuning data")
        return
    current_stamina = tuning.max_stamina
    stamina_changed.emit(current_stamina, tuning.max_stamina)

func _physics_process(delta: float) -> void:
    if tuning == null:
        return
    if _regeneration_block_time > 0.0:
        _regeneration_block_time = maxf(0.0, _regeneration_block_time - delta)
        return
    if current_stamina >= tuning.max_stamina:
        return
    var regeneration := tuning.regeneration_per_second
    if _regeneration_modifier.is_valid():
        var modified: Variant = _regeneration_modifier.call(regeneration)
        if not (typeof(modified) == TYPE_INT or typeof(modified) == TYPE_FLOAT) or not is_finite(float(modified)) or float(modified) < 0.0:
            return
        regeneration = float(modified)
    if regeneration <= 0.0:
        return
    current_stamina = minf(tuning.max_stamina, current_stamina + regeneration * delta)
    stamina_changed.emit(current_stamina, tuning.max_stamina)

func can_spend(amount: float) -> bool:
    return tuning != null and amount >= 0.0 and current_stamina + 0.0001 >= amount

func try_spend(amount: float) -> bool:
    if not can_spend(amount):
        return false
    current_stamina = clampf(current_stamina - amount, 0.0, tuning.max_stamina)
    _regeneration_block_time = tuning.regeneration_delay
    stamina_changed.emit(current_stamina, tuning.max_stamina)
    return true

func restore_full() -> void:
    if tuning == null:
        return
    current_stamina = tuning.max_stamina
    _regeneration_block_time = 0.0
    stamina_changed.emit(current_stamina, tuning.max_stamina)

func apply_combat_value(value: float, suppress_regeneration: bool = true) -> bool:
    if tuning == null or not is_finite(value) or value < 0.0:
        return false
    current_stamina = clampf(value, 0.0, tuning.max_stamina)
    if suppress_regeneration:
        _regeneration_block_time = maxf(_regeneration_block_time, tuning.regeneration_delay)
    stamina_changed.emit(current_stamina, tuning.max_stamina)
    return true

func get_max_stamina() -> float:
    return 0.0 if tuning == null else tuning.max_stamina

func capture_safe_state() -> Dictionary:
    return {
        "current": current_stamina,
        "maximum_at_capture": get_max_stamina(),
        "regeneration_block_time": _regeneration_block_time,
    }

func restore_safe_state(data: Dictionary) -> bool:
    if tuning == null:
        return false
    var current_variant: Variant = data.get("current", null)
    var block_variant: Variant = data.get("regeneration_block_time", 0.0)
    if not (typeof(current_variant) == TYPE_INT or typeof(current_variant) == TYPE_FLOAT):
        return false
    if not (typeof(block_variant) == TYPE_INT or typeof(block_variant) == TYPE_FLOAT):
        return false
    var current := float(current_variant)
    var block_time := float(block_variant)
    if not is_finite(current) or not is_finite(block_time) or current < 0.0 or block_time < 0.0:
        return false
    current_stamina = clampf(current, 0.0, tuning.max_stamina)
    _regeneration_block_time = block_time
    stamina_changed.emit(current_stamina, tuning.max_stamina)
    return true
