class_name EnemyAttackPayloadAuthoring
extends Resource

@export var authored: bool = false
@export var damage_domain: StringName = &""
@export var delivery: StringName = &""
@export var raw_damage: float = 0.0
@export var guard_pressure: float = 0.0
@export var dodgeable: bool = false
@export var blockable: bool = false
@export var parryable: bool = false
@export var critical_multiplier: float = 1.0
@export var weak_point_multiplier: float = 1.0


func validate_authoring() -> PackedStringArray:
    var errors := PackedStringArray()
    if not authored:
        errors.append("attack payload is not authored")
        return errors
    if not [DirectHitResolver.DOMAIN_PHYSICAL, DirectHitResolver.DOMAIN_ARCANE].has(damage_domain):
        errors.append("damage_domain must be physical or arcane")
    if not [DirectHitResolver.DELIVERY_CONTACT, DirectHitResolver.DELIVERY_PROJECTILE].has(delivery):
        errors.append("delivery must be contact or projectile")
    if not _is_nonnegative_finite(raw_damage):
        errors.append("raw_damage must be finite and nonnegative")
    if not _is_nonnegative_finite(guard_pressure):
        errors.append("guard_pressure must be finite and nonnegative")
    if not _is_multiplier(critical_multiplier):
        errors.append("critical_multiplier must be finite and at least 1")
    if not _is_multiplier(weak_point_multiplier):
        errors.append("weak_point_multiplier must be finite and at least 1")
    if delivery == DirectHitResolver.DELIVERY_PROJECTILE and parryable:
        errors.append("prototype projectiles cannot be parryable")
    return errors


func make_payload(critical_triggered: bool, weak_point_triggered: bool) -> Dictionary:
    if not validate_authoring().is_empty():
        return {}
    return {
        "domain": damage_domain,
        "delivery": delivery,
        "raw_damage": raw_damage,
        "dodgeable": dodgeable,
        "blockable": blockable,
        "parryable": parryable,
        "guard_pressure": guard_pressure,
        "critical_triggered": critical_triggered,
        "critical_multiplier": critical_multiplier,
        "weak_point_triggered": weak_point_triggered,
        "weak_point_multiplier": weak_point_multiplier,
    }


func _is_nonnegative_finite(value: float) -> bool:
    return is_finite(value) and value >= 0.0


func _is_multiplier(value: float) -> bool:
    return is_finite(value) and value >= 1.0

