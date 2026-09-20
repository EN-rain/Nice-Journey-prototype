class_name PlayerDefenderFactsProvider
extends RefCounted

const REASON_NOT_CONFIGURED: StringName = &"not_configured"
const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_INVALID_TUNING: StringName = &"invalid_tuning"

var player: PlayerController = null
var combat_runtime: ClassCombatRuntime = null
var tuning: PlayerDefenderFactsTuning = null
var _configured: bool = false
var _skill_evade_window_provider: Callable = Callable()


func set_skill_evade_window_provider(provider: Callable) -> void:
    _skill_evade_window_provider = provider


func configure(
    source_player: PlayerController,
    source_combat_runtime: ClassCombatRuntime,
    source_tuning: PlayerDefenderFactsTuning
) -> PackedStringArray:
    _configured = false
    player = null
    combat_runtime = null
    tuning = null
    _skill_evade_window_provider = Callable()

    var errors := PackedStringArray()
    if source_player == null or source_combat_runtime == null or source_tuning == null:
        errors.append("player defender-facts context is incomplete")
        return errors
    if source_player.movement == null or source_player.movement.tuning == null:
        errors.append("player movement tuning is unavailable")
        return errors

    errors = source_tuning.validate_tuning(source_player.movement.tuning)
    if not errors.is_empty():
        return errors

    player = source_player
    combat_runtime = source_combat_runtime
    tuning = source_tuning
    _configured = true
    return errors


func is_configured() -> bool:
    return (
        _configured
        and player != null
        and is_instance_valid(player)
        and player.movement != null
        and is_instance_valid(player.movement)
        and player.movement.tuning != null
        and combat_runtime != null
        and is_instance_valid(combat_runtime)
        and tuning != null
    )


func make_snapshot(attacker_position: Vector2, target_position: Vector2) -> Dictionary:
    # Inspector data and movement settings can change after configure();
    # never grant an evade/parry/block snapshot from a now-invalid interval.
    if not is_configured() or not tuning.validate_tuning(player.movement.tuning).is_empty():
        return {}

    var defense_mode := combat_runtime.get_defense_mode()
    if not [
        DirectHitResolver.DEFENSE_NONE,
        DirectHitResolver.DEFENSE_BLOCK,
        DirectHitResolver.DEFENSE_PARRY,
    ].has(defense_mode):
        return {}

    return {
        "evade_window_active": _dodge_window_active(),
        "defense_mode": defense_mode,
        "playtest_ward_active": combat_runtime.has_active_playtest_ward(),
        "facing_covered": is_facing_covered(
            player.get_aim_direction(),
            attacker_position,
            target_position,
            tuning.frontal_coverage_degrees
        ),
    }


func _dodge_window_active() -> bool:
    if _skill_evade_window_provider.is_valid():
        var active: Variant = _skill_evade_window_provider.call()
        if active is bool and bool(active):
            return true
    if player == null or player.movement == null or not player.is_dodging():
        return false
    var elapsed := player.movement.get_dodge_elapsed_seconds()
    return is_dodge_window_active(
        elapsed,
        tuning.dodge_invulnerability_start_seconds,
        tuning.dodge_invulnerability_duration_seconds
    )


static func is_dodge_window_active(
    dodge_elapsed_seconds: float,
    start_seconds: float,
    duration_seconds: float
) -> bool:
    if (
        not is_finite(dodge_elapsed_seconds)
        or not is_finite(start_seconds)
        or not is_finite(duration_seconds)
        or dodge_elapsed_seconds < 0.0
        or start_seconds < 0.0
        or duration_seconds <= 0.0
    ):
        return false
    var end_seconds := start_seconds + duration_seconds
    return dodge_elapsed_seconds + 0.000001 >= start_seconds and dodge_elapsed_seconds < end_seconds - 0.000001


static func is_facing_covered(
    defender_forward: Vector2,
    attacker_position: Vector2,
    target_position: Vector2,
    coverage_degrees: float
) -> bool:
    if not is_finite(coverage_degrees) or coverage_degrees <= 0.0 or coverage_degrees > 180.0:
        return false
    if (not is_finite(defender_forward.x) or not is_finite(defender_forward.y)
        or not is_finite(attacker_position.x) or not is_finite(attacker_position.y)
        or not is_finite(target_position.x) or not is_finite(target_position.y)):
        return false
    if defender_forward.length_squared() <= 0.000001:
        return false
    var to_attacker := attacker_position - target_position
    if to_attacker.length_squared() <= 0.000001:
        return false

    var forward := defender_forward.normalized()
    var direction := to_attacker.normalized()
    var half_angle_radians := deg_to_rad(coverage_degrees * 0.5)
    return forward.dot(direction) + 0.000001 >= cos(half_angle_radians)
