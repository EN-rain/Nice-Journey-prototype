class_name AudioEventDefinition
extends Resource

enum Priority {
    CRITICAL,
    GAMEPLAY,
    DECORATIVE,
}

enum Lifecycle {
    ONE_SHOT,
    LOOP,
}

const REQUIRED_BUSES: Array[StringName] = [
    &"Master",
    &"Music",
    &"Gameplay SFX",
    &"UI",
    &"Ambience",
]

@export var event_id: StringName = &""
@export var bus: StringName = &"Gameplay SFX"
@export var priority: Priority = Priority.GAMEPLAY
@export var positional: bool = true
@export_range(1, 32, 1) var overlap_limit: int = 1
@export var lifecycle: Lifecycle = Lifecycle.ONE_SHOT
@export_range(0.0, 600.0, 0.01) var duration_hint_seconds: float = 0.0
@export var variation_allowed: bool = false
@export var stop_on_owner_exit: bool = true
@export var stop_condition_id: StringName = &""
@export var stream: AudioStream = null

func validate_definition() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not StableId.is_valid(event_id):
        errors.append("event_id must be a valid stable ID")
    if not REQUIRED_BUSES.has(bus):
        errors.append("bus must be one of the required prototype audio buses")
    if overlap_limit <= 0 or overlap_limit > 32:
        errors.append("overlap_limit must be between 1 and 32")
    if duration_hint_seconds < 0.0:
        errors.append("duration_hint_seconds cannot be negative")
    if (bus == &"Music" or bus == &"UI") and positional:
        errors.append("Music and UI events must be non-positional")
    if lifecycle == Lifecycle.LOOP and not stop_on_owner_exit and String(stop_condition_id).strip_edges().is_empty():
        errors.append("looping events require an owner-exit stop or explicit stop condition")
    return errors
