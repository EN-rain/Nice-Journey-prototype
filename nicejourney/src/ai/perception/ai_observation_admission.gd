class_name AiObservationAdmission
extends RefCounted

const CUE_SIGHT: StringName = &"sight"
const CUE_SOUND: StringName = &"sound"
const CUE_SHARED: StringName = &"shared"

var _memory: AiObservationMemory

func _init(memory: AiObservationMemory) -> void:
    _memory = memory

func admit_sight(
    source_id: StringName,
    observed_position: Vector2,
    observed_state: StringName,
    observed_tick: int,
    confidence: float,
    lifetime_ticks: int,
    admission_tick: int
) -> bool:
    return _admit(CUE_SIGHT, source_id, observed_position, observed_state, observed_tick, confidence, lifetime_ticks, admission_tick)

func admit_sound(
    source_id: StringName,
    observed_position: Vector2,
    observed_state: StringName,
    observed_tick: int,
    confidence: float,
    lifetime_ticks: int,
    admission_tick: int
) -> bool:
    return _admit(CUE_SOUND, source_id, observed_position, observed_state, observed_tick, confidence, lifetime_ticks, admission_tick)

func admit_shared_fact(
    source_id: StringName,
    observed_position: Vector2,
    observed_state: StringName,
    observed_tick: int,
    confidence: float,
    lifetime_ticks: int,
    admission_tick: int
) -> bool:
    return _admit(CUE_SHARED, source_id, observed_position, observed_state, observed_tick, confidence, lifetime_ticks, admission_tick)

func _admit(
    cue_id: StringName,
    source_id: StringName,
    observed_position: Vector2,
    observed_state: StringName,
    observed_tick: int,
    confidence: float,
    lifetime_ticks: int,
    admission_tick: int
) -> bool:
    if _memory == null:
        return false
    if not StableId.is_valid(String(source_id)) or not StableId.is_valid(String(observed_state)):
        return false
    if observed_tick < 0 or admission_tick < observed_tick or lifetime_ticks <= 0:
        return false
    if not observed_position.is_finite() or not is_finite(confidence) or confidence < 0.0 or confidence > 1.0:
        return false
    if admission_tick >= observed_tick + lifetime_ticks:
        return false
    return _memory.record_observation(
        cue_id,
        source_id,
        observed_position,
        observed_state,
        observed_tick,
        confidence,
        lifetime_ticks
    )
