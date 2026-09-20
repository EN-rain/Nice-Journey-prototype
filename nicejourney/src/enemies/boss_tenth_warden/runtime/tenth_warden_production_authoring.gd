class_name TenthWardenProductionAuthoring
extends Resource

const STAMINA_RESOURCE_ID: StringName = &"stamina"

@export var authored: bool = false
@export var playtest_placeholder: bool = false
@export_range(1, 2147483647, 1) var max_hp: int = 1
@export var stamina: float = 0.0
# Deterministic boss-only replenishment; without it authored move costs can exhaust
# the pool permanently and leave the autonomous controller with no legal move.
@export_range(0.0, 10000.0, 0.01) var stamina_recovery_per_tick: float = 0.0
@export var physical_defense: float = 0.0
@export var arcane_defense: float = 0.0
@export var poise_threshold: float = 1.0
@export var interruptible_declared: bool = false
@export var interruptible: bool = true
@export var block_supported_declared: bool = false
@export var block_supported: bool = false
@export var parry_supported_declared: bool = false
@export var parry_supported: bool = false

# Phase 1 teaches the five approved move families. Phase 2 reuses those same
# families with separately authored timing and an explicitly authored cadence.
@export var move_actions: Array[ActionDefinition] = []
@export var phase_two_move_actions: Array[ActionDefinition] = []
@export var move_attacks: Array[EnemySignatureAttackAuthoring] = []
@export var phase_transition_action: ActionDefinition = null
@export var phase_one_move_order: Array[StringName] = []
@export var phase_two_move_order: Array[StringName] = []
@export var phase_two_heavy_move_ids: Array[StringName] = []


func validate_authoring() -> PackedStringArray:
    var errors := PackedStringArray()
    if not authored:
        errors.append("Tenth Warden production combat authoring is not enabled")
        return errors
    if max_hp <= 0:
        errors.append("max_hp must be positive")
    for entry: Array in [
        ["stamina", stamina],
        ["stamina_recovery_per_tick", stamina_recovery_per_tick],
        ["physical_defense", physical_defense],
        ["arcane_defense", arcane_defense],
        ["poise_threshold", poise_threshold],
    ]:
        var value := float(entry[1])
        if not is_finite(value):
            errors.append("%s must be finite" % String(entry[0]))
    if stamina < 0.0:
        errors.append("stamina cannot be negative")
    if stamina_recovery_per_tick < 0.0:
        errors.append("stamina_recovery_per_tick cannot be negative")
    if poise_threshold <= 0.0:
        errors.append("poise_threshold must be positive")
    if physical_defense < 0.0 or arcane_defense < 0.0:
        errors.append("physical and arcane defense cannot be negative")
    if not interruptible_declared:
        errors.append("interruptible must be explicitly declared")
    if not block_supported_declared:
        errors.append("block_supported must be explicitly declared")
    if not parry_supported_declared:
        errors.append("parry_supported must be explicitly declared")

    _validate_moves(errors)
    _validate_transition_action(errors)
    _validate_move_order(phase_one_move_order, "phase_one_move_order", errors)
    _validate_move_order(phase_two_move_order, "phase_two_move_order", errors)
    _validate_phase_two_heavy_moves(errors)
    if _has_positive_move_cost() and stamina_recovery_per_tick <= 0.0:
        errors.append("costed boss moves require positive authored stamina recovery to prevent permanent action starvation")
    return errors


func build_boss_state() -> CombatantRuntimeState:
    if not validate_authoring().is_empty():
        return null
    var state := CombatantRuntimeState.new()
    if not state.configure(
        Floor10PrimaryBossObjectiveService.BOSS_ACTOR_ID,
        max_hp,
        stamina,
        physical_defense,
        arcane_defense,
        poise_threshold,
        interruptible,
        block_supported,
        parry_supported
    ):
        return null
    return state


func action_for_move(move_id: StringName, phase: int = TenthWardenEncounterState.PHASE_ONE) -> ActionDefinition:
    if not TenthWardenEncounterState.MOVE_IDS.has(move_id):
        return null
    var source: Array[ActionDefinition] = move_actions if phase == TenthWardenEncounterState.PHASE_ONE else phase_two_move_actions
    for action: ActionDefinition in source:
        if action != null and action.action_id == move_id:
            return action
    return null


func attack_for_move(move_id: StringName) -> EnemySignatureAttackAuthoring:
    if not TenthWardenEncounterState.MOVE_IDS.has(move_id):
        return null
    for attack: EnemySignatureAttackAuthoring in move_attacks:
        if attack != null and attack.action_id == move_id:
            return attack
    return null


func selection_order_for_phase(phase: int) -> Array[StringName]:
    var result: Array[StringName] = []
    var source: Array[StringName] = phase_one_move_order if phase == TenthWardenEncounterState.PHASE_ONE else phase_two_move_order
    for move_id: StringName in source:
        result.append(move_id)
    return result


func is_phase_two_heavy_move(move_id: StringName) -> bool:
    return phase_two_heavy_move_ids.has(move_id)


func _validate_moves(errors: PackedStringArray) -> void:
    var phase_one_actions := _validated_actions_by_id(move_actions, "move_actions", errors)
    var phase_two_actions := _validated_actions_by_id(phase_two_move_actions, "phase_two_move_actions", errors)

    if move_attacks.size() != TenthWardenEncounterState.MOVE_IDS.size():
        errors.append("move_attacks must author exactly the five approved Tenth Warden moves")

    var attacks_by_id: Dictionary = {}
    for attack: EnemySignatureAttackAuthoring in move_attacks:
        if attack == null:
            errors.append("move_attacks cannot contain null")
            continue
        var attack_errors := attack.validate_authoring()
        if not attack_errors.is_empty():
            errors.append("move attack %s is invalid" % String(attack.action_id))
            continue
        if not TenthWardenEncounterState.MOVE_IDS.has(attack.action_id):
            errors.append("move_attacks contains an unapproved move: %s" % String(attack.action_id))
            continue
        if attacks_by_id.has(attack.action_id):
            errors.append("move_attacks contains a duplicate move: %s" % String(attack.action_id))
            continue
        if not _locked_semantics_match(attack.action_id, attack):
            errors.append("move attack %s violates the locked Tenth Warden delivery semantics" % String(attack.action_id))
            continue
        attacks_by_id[attack.action_id] = attack

    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        if not phase_one_actions.has(move_id):
            errors.append("missing phase-one action timing for approved move: %s" % String(move_id))
        if not phase_two_actions.has(move_id):
            errors.append("missing phase-two action timing for approved move: %s" % String(move_id))
        if not attacks_by_id.has(move_id):
            errors.append("missing attack authoring for approved move: %s" % String(move_id))
        var phase_one_action: ActionDefinition = phase_one_actions.get(move_id, null) as ActionDefinition
        var phase_two_action: ActionDefinition = phase_two_actions.get(move_id, null) as ActionDefinition
        var attack: EnemySignatureAttackAuthoring = attacks_by_id.get(move_id, null) as EnemySignatureAttackAuthoring
        if phase_one_action != null and phase_two_action != null and phase_two_action.recovery_ticks >= phase_one_action.recovery_ticks:
            errors.append("phase-two recovery must be tighter than phase one for move: %s" % String(move_id))
        if phase_two_action != null and phase_two_heavy_move_ids.has(move_id) and phase_two_action.recovery_ticks <= 0:
            errors.append("phase-two heavy move must expose a positive recovery window: %s" % String(move_id))
        if attack != null and attack.geometry != null:
            var ticks := attack.geometry.hit_active_ticks
            if move_id == TenthWardenEncounterState.MOVE_ARC_VOLLEY:
                for index: int in range(1, ticks.size()):
                    if ticks[index] <= ticks[index - 1]:
                        errors.append("Arc Volley pressure sequence requires strictly advancing projectile launch intervals")
                        break
            if phase_one_action != null:
                for live_error: String in attack.geometry.validate_live_delivery(phase_one_action.active_ticks):
                    errors.append("phase-one live delivery %s: %s" % [String(move_id), live_error])
            if phase_two_action != null:
                for live_error: String in attack.geometry.validate_live_delivery(phase_two_action.active_ticks):
                    errors.append("phase-two live delivery %s: %s" % [String(move_id), live_error])


func _validated_actions_by_id(
    source: Array[ActionDefinition],
    label: String,
    errors: PackedStringArray
) -> Dictionary:
    if source.size() != TenthWardenEncounterState.MOVE_IDS.size():
        errors.append("%s must author exactly the five approved Tenth Warden moves" % label)
    var actions_by_id: Dictionary = {}
    for action: ActionDefinition in source:
        if action == null:
            errors.append("%s cannot contain null" % label)
            continue
        if not action.validate_definition().is_empty():
            errors.append("%s action %s is invalid" % [label, String(action.action_id)])
            continue
        if not TenthWardenEncounterState.MOVE_IDS.has(action.action_id):
            errors.append("%s contains an unapproved move: %s" % [label, String(action.action_id)])
            continue
        if not _action_resource_mapping_supported(action):
            errors.append("%s action %s uses an unsupported boss resource" % [label, String(action.action_id)])
            continue
        if not is_finite(action.cost_amount) or action.cost_amount > stamina:
            errors.append("%s action %s has a nonfinite or unpayable stamina cost" % [label, String(action.action_id)])
            continue
        if action.startup_ticks <= 0:
            errors.append("%s action %s needs a readable positive startup telegraph" % [label, String(action.action_id)])
            continue
        if actions_by_id.has(action.action_id):
            errors.append("%s contains a duplicate move: %s" % [label, String(action.action_id)])
            continue
        actions_by_id[action.action_id] = action
    return actions_by_id


func _validate_transition_action(errors: PackedStringArray) -> void:
    if phase_transition_action == null:
        errors.append("phase_transition_action is required")
        return
    if phase_transition_action.action_id != TenthWardenEncounterState.ACTION_PHASE_TRANSITION:
        errors.append("phase_transition_action must use the locked phase transition action ID")
    if not phase_transition_action.validate_definition().is_empty():
        errors.append("phase_transition_action is invalid")
    if not _action_resource_mapping_supported(phase_transition_action):
        errors.append("phase_transition_action uses an unsupported boss resource")
    if phase_transition_action.cost_amount != 0.0 or phase_transition_action.cooldown_ticks != 0:
        errors.append("non-damaging irreversible phase transition cannot require stamina or cooldown")
    if phase_transition_action.cancellable_phase_mask != 0 or not phase_transition_action.permitted_cancel_action_ids.is_empty():
        errors.append("irreversible phase transition cannot author voluntary cancellation")


func _validate_move_order(order: Array[StringName], label: String, errors: PackedStringArray) -> void:
    if order.is_empty():
        errors.append("%s must be explicitly authored" % label)
        return
    var seen: Dictionary = {}
    for move_id: StringName in order:
        if not TenthWardenEncounterState.MOVE_IDS.has(move_id):
            errors.append("%s contains an unapproved move: %s" % [label, String(move_id)])
            continue
        seen[move_id] = true
    for move_id: StringName in TenthWardenEncounterState.MOVE_IDS:
        if not seen.has(move_id):
            errors.append("%s must include approved move: %s" % [label, String(move_id)])


func _validate_phase_two_heavy_moves(errors: PackedStringArray) -> void:
    if phase_two_heavy_move_ids.is_empty():
        errors.append("phase_two_heavy_move_ids must explicitly identify at least one heavy committed move")
        return
    var seen: Dictionary = {}
    for move_id: StringName in phase_two_heavy_move_ids:
        if not TenthWardenEncounterState.MOVE_IDS.has(move_id):
            errors.append("phase_two_heavy_move_ids contains an unapproved move: %s" % String(move_id))
        elif seen.has(move_id):
            errors.append("phase_two_heavy_move_ids contains a duplicate move: %s" % String(move_id))
        else:
            seen[move_id] = true


func _action_resource_mapping_supported(action: ActionDefinition) -> bool:
    if action == null or action.cost_amount <= 0.0:
        return true
    return action.cost_resource == STAMINA_RESOURCE_ID


func _has_positive_move_cost() -> bool:
    for action: ActionDefinition in move_actions + phase_two_move_actions:
        if action != null and action.cost_amount > 0.0:
            return true
    return false


func _locked_semantics_match(move_id: StringName, attack: EnemySignatureAttackAuthoring) -> bool:
    if attack == null or attack.geometry == null or attack.payload == null:
        return false
    var payload := attack.payload
    match move_id:
        TenthWardenEncounterState.MOVE_TWIN_CUT:
            return payload.delivery == DirectHitResolver.DELIVERY_CONTACT and attack.geometry.hit_interval_count == 2
        TenthWardenEncounterState.MOVE_WARDEN_LUNGE:
            return payload.delivery == DirectHitResolver.DELIVERY_CONTACT
        TenthWardenEncounterState.MOVE_ARC_VOLLEY:
            return (
                payload.delivery == DirectHitResolver.DELIVERY_PROJECTILE
                and payload.dodgeable
                and payload.blockable
                and not payload.parryable
            )
        TenthWardenEncounterState.MOVE_CRESCENT_SWEEP:
            return payload.delivery == DirectHitResolver.DELIVERY_CONTACT and payload.dodgeable and not payload.blockable
        TenthWardenEncounterState.MOVE_PUNISHING_STEP:
            return payload.delivery == DirectHitResolver.DELIVERY_CONTACT
        _:
            return false
