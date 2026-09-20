class_name StarterKitDefinition
extends Resource

@export var class_id: StringName = &""
@export var main_hand_id: StringName = &""
@export var off_hand_id: StringName = &""
@export var two_handed: bool = false
@export var off_hand_allowed: bool = true
@export var tracks_ammunition: bool = false
@export var has_mana: bool = false
@export var supports_block: bool = false
@export var supports_parry: bool = false
@export var basic_action: ActionDefinition = null
@export var basic_damage_domain: StringName = &"physical"
@export var basic_delivery: StringName = &"contact"
@export var basic_raw_damage: float = 0.0
@export var basic_guard_pressure: float = 0.0
@export var basic_poise_damage: float = 0.0
@export var basic_dodgeable: bool = true
@export var basic_blockable: bool = true
@export var basic_parryable: bool = true


func validate_definition() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if not StableId.is_valid(String(class_id)):
        errors.append("class_id must be a stable ID")
    if not StableId.is_valid(String(main_hand_id)):
        errors.append("main_hand_id must be a stable ID")
    if not String(off_hand_id).is_empty() and not StableId.is_valid(String(off_hand_id)):
        errors.append("off_hand_id must be empty or a stable ID")
    if two_handed and off_hand_allowed:
        errors.append("two-handed starter weapons cannot allow an off-hand item")
    if not off_hand_allowed and not String(off_hand_id).is_empty():
        errors.append("off_hand_id must be empty when off-hand equipment is not allowed")
    if basic_action == null:
        errors.append("basic_action is required")
    else:
        for action_error: String in basic_action.validate_definition():
            errors.append("basic_action: %s" % action_error)
        if basic_action.cost_amount != 0.0 or basic_action.cost_resource != &"":
            errors.append("starter basic attack must be resource-free")
    if basic_damage_domain != DirectHitResolver.DOMAIN_PHYSICAL and basic_damage_domain != DirectHitResolver.DOMAIN_ARCANE:
        errors.append("basic_damage_domain must be physical or arcane")
    if basic_delivery != DirectHitResolver.DELIVERY_CONTACT and basic_delivery != DirectHitResolver.DELIVERY_PROJECTILE:
        errors.append("basic_delivery must be contact or projectile")
    if not _is_nonnegative_finite(basic_raw_damage):
        errors.append("basic_raw_damage must be finite and nonnegative")
    if not _is_nonnegative_finite(basic_guard_pressure):
        errors.append("basic_guard_pressure must be finite and nonnegative")
    if not _is_nonnegative_finite(basic_poise_damage):
        errors.append("basic_poise_damage must be finite and nonnegative")
    if basic_delivery == DirectHitResolver.DELIVERY_PROJECTILE and basic_parryable:
        errors.append("prototype projectiles cannot be parryable")
    return errors


func make_basic_attack_payload() -> Dictionary:
    if not validate_definition().is_empty():
        return {}
    return {
        "domain": basic_damage_domain,
        "delivery": basic_delivery,
        "raw_damage": basic_raw_damage,
        "dodgeable": basic_dodgeable,
        "blockable": basic_blockable,
        "parryable": basic_parryable,
        "guard_pressure": basic_guard_pressure,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }


func _is_nonnegative_finite(value: float) -> bool:
    return is_finite(value) and value >= 0.0
