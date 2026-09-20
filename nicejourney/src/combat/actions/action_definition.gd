class_name ActionDefinition
extends Resource

enum AimLockPoint {
    STARTUP,
    COMMIT,
    ACTIVE,
}

@export var action_id: StringName = &""
@export_range(0, 600, 1) var startup_ticks: int = 1
@export_range(0, 600, 1) var commit_ticks: int = 1
@export_range(0, 600, 1) var active_ticks: int = 1
@export_range(0, 600, 1) var recovery_ticks: int = 1
@export_range(0, 600, 1) var cooldown_ticks: int = 0
@export_range(1, 120, 1) var buffer_lifetime_ticks: int = 8
@export var cost_resource: StringName = &""
@export_range(0.0, 100000.0, 0.1) var cost_amount: float = 0.0
@export var uses_aim: bool = false
@export var aim_lock_point: AimLockPoint = AimLockPoint.COMMIT
@export var allow_aim_tracking_after_lock: bool = false
@export_flags("Startup", "Commit", "Active", "Recovery") var cancellable_phase_mask: int = 0
@export var permitted_cancel_action_ids: Array[StringName] = []

@export_category("Production Skill Authoring Boundary")
@export var production_mechanic_id: StringName = &""
@export var eligible_states_profile_id: StringName = &""
@export var movement_aim_profile_id: StringName = &""
@export var effect_profile_id: StringName = &""
@export var forced_interruption_profile_id: StringName = &""
@export var cue_profile_id: StringName = &""

func validate_definition() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if String(action_id).strip_edges().is_empty():
        errors.append("action_id is required")
    if commit_ticks <= 0:
        errors.append("commit_ticks must be at least 1 so the commit boundary is observable")
    if active_ticks <= 0:
        errors.append("active_ticks must be at least 1")
    if recovery_ticks < 0 or startup_ticks < 0 or cooldown_ticks < 0:
        errors.append("action tick counts cannot be negative")
    if cost_amount < 0.0:
        errors.append("cost_amount cannot be negative")
    if cost_amount > 0.0 and String(cost_resource).is_empty():
        errors.append("cost_resource is required when cost_amount is positive")
    if not uses_aim and allow_aim_tracking_after_lock:
        errors.append("allow_aim_tracking_after_lock requires uses_aim")
    if cancellable_phase_mask < 0 or cancellable_phase_mask > 15:
        errors.append("cancellable_phase_mask contains unsupported phase bits")
    var seen_cancel_ids: Dictionary = {}
    for cancel_action_id: StringName in permitted_cancel_action_ids:
        if String(cancel_action_id).strip_edges().is_empty():
            errors.append("permitted cancel action IDs must not be empty")
        elif seen_cancel_ids.has(cancel_action_id):
            errors.append("permitted cancel action IDs must be unique")
        else:
            seen_cancel_ids[cancel_action_id] = true
    return errors

func validate_production_skill_authoring(expected_mechanic_id: StringName) -> PackedStringArray:
    var errors := validate_definition()
    if not StableId.is_valid(String(expected_mechanic_id)):
        errors.append("expected production skill mechanic_id must be a stable ID")
    if not StableId.is_valid(String(production_mechanic_id)):
        errors.append("production_mechanic_id must be explicitly authored as a stable ID")
    elif StableId.is_valid(String(expected_mechanic_id)) and production_mechanic_id != expected_mechanic_id:
        errors.append("production_mechanic_id must match the SkillDefinition mechanic_id")
    _require_profile_id(errors, eligible_states_profile_id, "eligible_states_profile_id")
    _require_profile_id(errors, movement_aim_profile_id, "movement_aim_profile_id")
    _require_profile_id(errors, effect_profile_id, "effect_profile_id")
    _require_profile_id(errors, forced_interruption_profile_id, "forced_interruption_profile_id")
    _require_profile_id(errors, cue_profile_id, "cue_profile_id")
    return errors

static func production_skill_authoring_contract() -> Dictionary:
    return {
        "eligible_states_profile_id": PackedStringArray(["eligible_states"]),
        "movement_aim_profile_id": PackedStringArray(["movement_rules", "aim_rules"]),
        "effect_profile_id": PackedStringArray([
            "attack_shape",
            "target_mask",
            "damage_category_and_tags",
            "hit_count",
            "poise_and_knockback_effects",
            "status_eligibility",
            "critical_and_weak_point_interaction",
        ]),
        "forced_interruption_profile_id": PackedStringArray(["forced_interruption_rules"]),
        "cue_profile_id": PackedStringArray(["required_cues", "attack_feedback_window_alignment"]),
    }

func production_skill_authoring_manifest(expected_mechanic_id: StringName) -> Dictionary:
    var errors := validate_production_skill_authoring(expected_mechanic_id)
    if not errors.is_empty():
        return {
            "accepted": false,
            "errors": errors.duplicate(),
        }
    return {
        "accepted": true,
        "errors": PackedStringArray(),
        "action_id": action_id,
        "mechanic_id": production_mechanic_id,
        "eligible_states_profile_id": eligible_states_profile_id,
        "movement_aim_profile_id": movement_aim_profile_id,
        "effect_profile_id": effect_profile_id,
        "forced_interruption_profile_id": forced_interruption_profile_id,
        "cue_profile_id": cue_profile_id,
        "profile_responsibilities": production_skill_authoring_contract().duplicate(true),
    }

func permits_cancel_from_phase(phase_index: int, incoming_action_id: StringName) -> bool:
    if incoming_action_id == &"" or not permitted_cancel_action_ids.has(incoming_action_id):
        return false
    if phase_index < 1 or phase_index > 4:
        return false
    var phase_bit: int = 1 << (phase_index - 1)
    return (cancellable_phase_mask & phase_bit) != 0

func _require_profile_id(errors: PackedStringArray, value: StringName, field_name: String) -> void:
    if not StableId.is_valid(String(value)):
        errors.append("%s must be explicitly authored as a stable ID" % field_name)
