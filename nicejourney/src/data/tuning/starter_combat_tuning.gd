class_name StarterCombatTuning
extends Resource

@export_category("Melee basic")
@export_range(0.0, 10000.0, 0.1) var melee_basic_damage: float = 10.0
@export_range(0.0, 10000.0, 0.1) var melee_guard_pressure: float = 10.0
@export_range(0.0, 10000.0, 0.1) var melee_poise_damage: float = 10.0
@export_range(0, 600, 1) var melee_startup_ticks: int = 4
@export_range(1, 600, 1) var melee_commit_ticks: int = 1
@export_range(1, 600, 1) var melee_active_ticks: int = 3
@export_range(0, 600, 1) var melee_recovery_ticks: int = 6

@export_category("Ranged basic")
@export_range(0.0, 10000.0, 0.1) var ranged_basic_damage: float = 9.0
@export_range(0.0, 10000.0, 0.1) var ranged_guard_pressure: float = 8.0
@export_range(0.0, 10000.0, 0.1) var ranged_poise_damage: float = 6.0
@export_range(0, 600, 1) var ranged_startup_ticks: int = 6
@export_range(1, 600, 1) var ranged_commit_ticks: int = 1
@export_range(1, 600, 1) var ranged_active_ticks: int = 2
@export_range(0, 600, 1) var ranged_recovery_ticks: int = 8

@export_category("Mage basic")
@export_range(0.0, 10000.0, 0.1) var mage_basic_damage: float = 9.0
@export_range(0.0, 10000.0, 0.1) var mage_guard_pressure: float = 7.0
@export_range(0.0, 10000.0, 0.1) var mage_poise_damage: float = 5.0
@export_range(0, 600, 1) var mage_startup_ticks: int = 7
@export_range(1, 600, 1) var mage_commit_ticks: int = 1
@export_range(1, 600, 1) var mage_active_ticks: int = 2
@export_range(0, 600, 1) var mage_recovery_ticks: int = 8

@export_category("Melee defense")
@export_range(1, 120, 1) var melee_parry_window_ticks: int = 4
@export_range(0, 120, 1) var melee_parry_recovery_ticks: int = 8

@export_category("Mage mana")
@export_range(1.0, 10000.0, 0.1) var mage_max_mana: float = 100.0
@export_range(0, 3600, 1) var mage_regeneration_delay_ticks: int = 60
@export_range(0.0, 1000.0, 0.01) var mage_regeneration_per_tick: float = 0.5


func validate_tuning() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    var finite_nonnegative: Array[float] = [
        melee_basic_damage,
        melee_guard_pressure,
        melee_poise_damage,
        ranged_basic_damage,
        ranged_guard_pressure,
        ranged_poise_damage,
        mage_basic_damage,
        mage_guard_pressure,
        mage_poise_damage,
        mage_regeneration_per_tick,
    ]
    for value: float in finite_nonnegative:
        if not is_finite(value) or value < 0.0:
            errors.append("combat tuning numeric values must be finite and nonnegative")
            break
    if not is_finite(mage_max_mana) or mage_max_mana <= 0.0:
        errors.append("mage_max_mana must be finite and positive")
    if mage_regeneration_delay_ticks < 0:
        errors.append("mage_regeneration_delay_ticks cannot be negative")
    if melee_startup_ticks < 0 or ranged_startup_ticks < 0 or mage_startup_ticks < 0:
        errors.append("starter basic startup ticks cannot be negative")
    if melee_commit_ticks <= 0 or ranged_commit_ticks <= 0 or mage_commit_ticks <= 0:
        errors.append("starter basic commit ticks must be positive")
    if melee_active_ticks <= 0 or ranged_active_ticks <= 0 or mage_active_ticks <= 0:
        errors.append("starter basic active ticks must be positive")
    if melee_recovery_ticks < 0 or ranged_recovery_ticks < 0 or mage_recovery_ticks < 0:
        errors.append("starter basic recovery ticks cannot be negative")
    if melee_parry_window_ticks <= 0 or melee_parry_recovery_ticks < 0:
        errors.append("Melee parry window must be positive and recovery cannot be negative")
    return errors
