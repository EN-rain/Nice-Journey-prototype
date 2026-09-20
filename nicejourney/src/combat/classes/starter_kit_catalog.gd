class_name StarterKitCatalog
extends RefCounted

const CLASS_MELEE: StringName = &"melee"
const CLASS_RANGED: StringName = &"ranged"
const CLASS_MAGE: StringName = &"mage"

const WEAPON_MELEE_SWORD: StringName = &"starter_sword"
const OFF_HAND_MELEE_SHIELD: StringName = &"starter_shield"
const WEAPON_RANGED_BOW: StringName = &"starter_bow"
const WEAPON_MAGE_STAFF: StringName = &"starter_staff"

const BASIC_MELEE: StringName = &"basic_attack_melee"
const BASIC_RANGED: StringName = &"basic_attack_ranged"
const BASIC_MAGE: StringName = &"basic_attack_mage"


static func create(class_id: StringName, tuning: StarterCombatTuning) -> StarterKitDefinition:
    if tuning == null or not tuning.validate_tuning().is_empty():
        return null
    match class_id:
        CLASS_MELEE:
            return _make_melee(tuning)
        CLASS_RANGED:
            return _make_ranged(tuning)
        CLASS_MAGE:
            return _make_mage(tuning)
        _:
            return null


static func validate_locked_contract(kit: StarterKitDefinition) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if kit == null:
        errors.append("starter kit is required")
        return errors
    for base_error: String in kit.validate_definition():
        errors.append(base_error)
    if not errors.is_empty():
        return errors

    match kit.class_id:
        CLASS_MELEE:
            if kit.main_hand_id != WEAPON_MELEE_SWORD or kit.off_hand_id != OFF_HAND_MELEE_SHIELD:
                errors.append("Melee starter kit must use sword plus shield")
            if kit.two_handed or not kit.off_hand_allowed:
                errors.append("Melee starter sword must remain one-handed with off-hand support")
            if kit.tracks_ammunition or kit.has_mana:
                errors.append("Melee starter kit cannot track ammunition or mana")
            if not kit.supports_block or not kit.supports_parry:
                errors.append("Melee starter shield must support block and parry")
            if kit.basic_damage_domain != DirectHitResolver.DOMAIN_PHYSICAL or kit.basic_delivery != DirectHitResolver.DELIVERY_CONTACT:
                errors.append("Melee basic must be a Physical contact attack")
            if kit.basic_action.action_id != BASIC_MELEE:
                errors.append("Melee basic action ID is invalid")
        CLASS_RANGED:
            if kit.main_hand_id != WEAPON_RANGED_BOW or kit.off_hand_id != &"":
                errors.append("Ranged starter kit must use a bow with empty off-hand")
            if not kit.two_handed or kit.off_hand_allowed:
                errors.append("Ranged starter bow must be two-handed and forbid off-hand equipment")
            if kit.tracks_ammunition:
                errors.append("Ranged prototype starter kit cannot track ammunition")
            if kit.has_mana or kit.supports_block or kit.supports_parry:
                errors.append("Ranged starter kit has no mana or baseline block/parry")
            if kit.basic_damage_domain != DirectHitResolver.DOMAIN_PHYSICAL or kit.basic_delivery != DirectHitResolver.DELIVERY_PROJECTILE:
                errors.append("Ranged basic must be a Physical projectile")
            if kit.basic_action.action_id != BASIC_RANGED:
                errors.append("Ranged basic action ID is invalid")
        CLASS_MAGE:
            if kit.main_hand_id != WEAPON_MAGE_STAFF or kit.off_hand_id != &"":
                errors.append("Mage starter kit must use a staff with empty off-hand")
            if not kit.two_handed or kit.off_hand_allowed:
                errors.append("Mage starter staff must be two-handed and forbid off-hand equipment")
            if kit.tracks_ammunition or not kit.has_mana:
                errors.append("Mage starter kit uses mana and no ammunition")
            if kit.supports_block or kit.supports_parry:
                errors.append("Mage starter kit has no baseline block/parry")
            if kit.basic_damage_domain != DirectHitResolver.DOMAIN_ARCANE or kit.basic_delivery != DirectHitResolver.DELIVERY_PROJECTILE:
                errors.append("Mage basic must be an Arcane projectile")
            if kit.basic_action.action_id != BASIC_MAGE:
                errors.append("Mage basic action ID is invalid")
        _:
            errors.append("unknown starter-kit class")
    return errors


static func _make_melee(tuning: StarterCombatTuning) -> StarterKitDefinition:
    var kit: StarterKitDefinition = StarterKitDefinition.new()
    kit.class_id = CLASS_MELEE
    kit.main_hand_id = WEAPON_MELEE_SWORD
    kit.off_hand_id = OFF_HAND_MELEE_SHIELD
    kit.two_handed = false
    kit.off_hand_allowed = true
    kit.tracks_ammunition = false
    kit.has_mana = false
    kit.supports_block = true
    kit.supports_parry = true
    kit.basic_action = _make_action(BASIC_MELEE, tuning.melee_startup_ticks, tuning.melee_commit_ticks, tuning.melee_active_ticks, tuning.melee_recovery_ticks)
    kit.basic_damage_domain = DirectHitResolver.DOMAIN_PHYSICAL
    kit.basic_delivery = DirectHitResolver.DELIVERY_CONTACT
    kit.basic_raw_damage = tuning.melee_basic_damage
    kit.basic_guard_pressure = tuning.melee_guard_pressure
    kit.basic_poise_damage = tuning.melee_poise_damage
    kit.basic_parryable = true
    return kit


static func _make_ranged(tuning: StarterCombatTuning) -> StarterKitDefinition:
    var kit: StarterKitDefinition = StarterKitDefinition.new()
    kit.class_id = CLASS_RANGED
    kit.main_hand_id = WEAPON_RANGED_BOW
    kit.off_hand_id = &""
    kit.two_handed = true
    kit.off_hand_allowed = false
    kit.tracks_ammunition = false
    kit.has_mana = false
    kit.supports_block = false
    kit.supports_parry = false
    kit.basic_action = _make_action(BASIC_RANGED, tuning.ranged_startup_ticks, tuning.ranged_commit_ticks, tuning.ranged_active_ticks, tuning.ranged_recovery_ticks)
    kit.basic_damage_domain = DirectHitResolver.DOMAIN_PHYSICAL
    kit.basic_delivery = DirectHitResolver.DELIVERY_PROJECTILE
    kit.basic_raw_damage = tuning.ranged_basic_damage
    kit.basic_guard_pressure = tuning.ranged_guard_pressure
    kit.basic_poise_damage = tuning.ranged_poise_damage
    kit.basic_parryable = false
    return kit


static func _make_mage(tuning: StarterCombatTuning) -> StarterKitDefinition:
    var kit: StarterKitDefinition = StarterKitDefinition.new()
    kit.class_id = CLASS_MAGE
    kit.main_hand_id = WEAPON_MAGE_STAFF
    kit.off_hand_id = &""
    kit.two_handed = true
    kit.off_hand_allowed = false
    kit.tracks_ammunition = false
    kit.has_mana = true
    kit.supports_block = false
    kit.supports_parry = false
    kit.basic_action = _make_action(BASIC_MAGE, tuning.mage_startup_ticks, tuning.mage_commit_ticks, tuning.mage_active_ticks, tuning.mage_recovery_ticks)
    kit.basic_damage_domain = DirectHitResolver.DOMAIN_ARCANE
    kit.basic_delivery = DirectHitResolver.DELIVERY_PROJECTILE
    kit.basic_raw_damage = tuning.mage_basic_damage
    kit.basic_guard_pressure = tuning.mage_guard_pressure
    kit.basic_poise_damage = tuning.mage_poise_damage
    kit.basic_parryable = false
    return kit


static func _make_action(action_id: StringName, startup_ticks: int, commit_ticks: int, active_ticks: int, recovery_ticks: int) -> ActionDefinition:
    var action: ActionDefinition = ActionDefinition.new()
    action.action_id = action_id
    action.startup_ticks = startup_ticks
    action.commit_ticks = commit_ticks
    action.active_ticks = active_ticks
    action.recovery_ticks = recovery_ticks
    action.cooldown_ticks = 0
    action.cost_resource = &""
    action.cost_amount = 0.0
    action.uses_aim = true
    action.aim_lock_point = ActionDefinition.AimLockPoint.COMMIT
    action.allow_aim_tracking_after_lock = false
    return action
