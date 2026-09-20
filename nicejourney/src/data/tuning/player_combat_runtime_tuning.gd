class_name PlayerCombatRuntimeTuning
extends Resource

# Initial prototype combat-state tuning. Equipment/stat progression may replace these
# values through authored data later; presentation never owns them.
@export_range(0.0, 10000.0, 0.1) var base_physical_defense: float = 0.0
@export_range(0.0, 10000.0, 0.1) var base_arcane_defense: float = 0.0
@export_range(0.1, 10000.0, 0.1) var poise_threshold: float = 50.0
@export var interruptible: bool = true

func validate_tuning() -> PackedStringArray:
    var errors := PackedStringArray()
    if not is_finite(base_physical_defense) or base_physical_defense < 0.0:
        errors.append("base_physical_defense must be finite and nonnegative")
    if not is_finite(base_arcane_defense) or base_arcane_defense < 0.0:
        errors.append("base_arcane_defense must be finite and nonnegative")
    if not is_finite(poise_threshold) or poise_threshold <= 0.0:
        errors.append("poise_threshold must be finite and positive")
    return errors
