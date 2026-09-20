class_name ClassCombatRuntime
extends Node

signal defense_mode_changed(mode: StringName)
signal parry_started(window_ticks: int)
signal parry_ended()

const RESOURCE_MANA: StringName = &"mana"

@export var action_state_machine_path: NodePath
@export var action_intent_controller_path: NodePath
@export var tuning: StarterCombatTuning
@export var equipment_playtest_tuning: PlayerEquipmentPlaytestTuning

var action_state_machine: ActionStateMachine = null
var action_intent_controller: ActionIntentController = null
var starter_kit: StarterKitDefinition = null
var resource_pool: ResourcePool = PlayerStaminaResourcePool.new()
var mana_regenerator: DelayedResourceRegenerator = DelayedResourceRegenerator.new()
var _configured_class_id: StringName = &""
var _defense_mode: StringName = DirectHitResolver.DEFENSE_NONE
var _parry_window_ticks_remaining: int = 0
var _parry_recovery_ticks_remaining: int = 0
# Aegis Ward is an expiring playtest-only magic block, not permanent mage
# shield equipment or a parry capability. It is never serialized as defense.
var _playtest_ward_ticks_remaining: int = 0
var _status_safe_states: Array = []
var _equipped_starter_item_ids: Dictionary = {}
var _equipped_weapon_upgrade_rank: int = 0
var _equipment_state_bound: bool = false
var _passive_skill_runtime: PassiveSkillRuntime = null



func _ready() -> void:
    if action_state_machine == null and not action_state_machine_path.is_empty():
        action_state_machine = get_node_or_null(action_state_machine_path) as ActionStateMachine
    if action_intent_controller == null and not action_intent_controller_path.is_empty():
        action_intent_controller = get_node_or_null(action_intent_controller_path) as ActionIntentController
    _bind_action_machine()


func bind_runtime(machine: ActionStateMachine, intent_controller: ActionIntentController = null) -> void:
    action_state_machine = machine
    action_intent_controller = intent_controller
    _bind_action_machine()


func configure_class(class_id: StringName) -> bool:
    if tuning == null or not tuning.validate_tuning().is_empty():
        return false
    var candidate: StarterKitDefinition = StarterKitCatalog.create(class_id, tuning)
    if candidate == null or not StarterKitCatalog.validate_locked_contract(candidate).is_empty():
        return false

    starter_kit = candidate
    _configured_class_id = class_id
    _clear_defense_state()
    _status_safe_states.clear()
    _equipped_starter_item_ids.clear()
    _equipped_weapon_upgrade_rank = 0
    _equipment_state_bound = false
    _passive_skill_runtime = null
    resource_pool = PlayerStaminaResourcePool.new()
    if starter_kit.has_mana:
        if not resource_pool.define_resource(RESOURCE_MANA, tuning.mage_max_mana):
            starter_kit = null
            _configured_class_id = &""
            return false
        if not mana_regenerator.configure(tuning.mage_regeneration_delay_ticks, tuning.mage_regeneration_per_tick):
            starter_kit = null
            _configured_class_id = &""
            return false
    else:
        mana_regenerator.configure(0, 0.0)
    if action_state_machine != null:
        action_state_machine.set_resource_pool(resource_pool)
    return true


func bind_equipment_state(data: Dictionary) -> bool:
    if starter_kit == null or not EquipmentState.validate_dictionary(data).is_empty():
        return false
    var source_slots := data.get("slots", {}) as Dictionary
    var weapon := source_slots.get(String(EquipmentSlotIdentityValidator.SLOT_WEAPON), {}) as Dictionary
    var off_hand := source_slots.get(String(EquipmentSlotIdentityValidator.SLOT_OFF_HAND), {}) as Dictionary
    _equipped_starter_item_ids = {
        "weapon": StringName(String(weapon.get("definition_id", &""))),
        "off_hand": StringName(String(off_hand.get("definition_id", &""))),
    }
    _equipped_weapon_upgrade_rank = int(weapon.get("upgrade_rank", 0))
    _equipment_state_bound = true
    if not supports_block() and _defense_mode != DirectHitResolver.DEFENSE_NONE:
        _clear_defense_state()
    return true


func bind_passive_skill_runtime(runtime: PassiveSkillRuntime) -> void:
    _passive_skill_runtime = runtime
    # Always derive the regen rate from the class's authored base: repeated
    # rank changes and restores must never compound the previous bonus.
    if has_mana() and tuning != null:
        var base_rate := tuning.mage_regeneration_per_tick
        mana_regenerator.amount_per_tick = (
            base_rate if runtime == null else runtime.modify_mana_regeneration(base_rate)
        )


func has_usable_starter_weapon() -> bool:
    return starter_kit != null and (
        not _equipment_state_bound
        or _equipped_starter_item_ids.get("weapon", &"") == starter_kit.main_hand_id
    )


func request_basic_attack(aim_sample: Vector2) -> bool:
    if starter_kit == null or starter_kit.basic_action == null or not has_usable_starter_weapon():
        return false
    if _defense_mode != DirectHitResolver.DEFENSE_NONE or _parry_recovery_ticks_remaining > 0:
        return false
    var action := _modified_action(starter_kit.basic_action)
    if action_intent_controller != null:
        return action_intent_controller.request_action(&"basic_attack", action, aim_sample)
    if action_state_machine != null:
        return action_state_machine.request_action(action, aim_sample)
    return false


func bind_player_stamina(source: StaminaComponent) -> bool:
    var player_pool := resource_pool as PlayerStaminaResourcePool
    return player_pool != null and player_pool.bind_stamina_source(source)


func request_active_skill_action(input_action_id: StringName, action: ActionDefinition, aim_sample: Vector2) -> bool:
    if starter_kit == null or action == null or not has_usable_starter_weapon():
        return false
    if _defense_mode != DirectHitResolver.DEFENSE_NONE or _parry_recovery_ticks_remaining > 0:
        return false
    var modified_action := _modified_action(action)
    if action_intent_controller != null:
        return action_intent_controller.request_action(input_action_id, modified_action, aim_sample)
    if action_state_machine != null:
        return action_state_machine.request_action(modified_action, aim_sample)
    return false


func _modified_action(authored: ActionDefinition) -> ActionDefinition:
    return authored if _passive_skill_runtime == null else _passive_skill_runtime.modify_action(authored)


func get_passive_skill_runtime() -> PassiveSkillRuntime:
    return _passive_skill_runtime


func get_playtest_weapon_attack_bonus() -> float:
    if not has_usable_starter_weapon() or equipment_playtest_tuning == null or not equipment_playtest_tuning.validate_tuning().is_empty():
        return 0.0
    if not _equipment_state_bound or _equipped_weapon_upgrade_rank <= 0:
        return 0.0
    return equipment_playtest_tuning.attack_bonus_for(starter_kit.main_hand_id, _equipped_weapon_upgrade_rank)


func make_basic_attack_payload() -> Dictionary:
    if not has_usable_starter_weapon():
        return {}
    var payload := starter_kit.make_basic_attack_payload()
    payload["raw_damage"] = float(payload.get("raw_damage", 0.0)) + get_playtest_weapon_attack_bonus()
    return payload


func resolve_basic_hit(defender: Dictionary) -> Dictionary:
    var payload: Dictionary = make_basic_attack_payload()
    if payload.is_empty():
        return DirectHitResolver.resolve(null, defender)
    return DirectHitResolver.resolve(payload, defender)


func get_class_id() -> StringName:
    return _configured_class_id


func tracks_ammunition() -> bool:
    return starter_kit != null and starter_kit.tracks_ammunition


func has_mana() -> bool:
    return starter_kit != null and starter_kit.has_mana


func supports_block() -> bool:
    return starter_kit != null and starter_kit.supports_block and (
        not _equipment_state_bound
        or _equipped_starter_item_ids.get("off_hand", &"") == starter_kit.off_hand_id
    )


func supports_parry() -> bool:
    return starter_kit != null and starter_kit.supports_parry and (
        not _equipment_state_bound
        or _equipped_starter_item_ids.get("off_hand", &"") == starter_kit.off_hand_id
    )


func request_block(active: bool) -> bool:
    if not supports_block():
        return false
    if not active:
        if _defense_mode == DirectHitResolver.DEFENSE_BLOCK:
            _set_defense_mode(DirectHitResolver.DEFENSE_NONE)
        return true
    if _parry_window_ticks_remaining > 0 or _parry_recovery_ticks_remaining > 0:
        return false
    if action_state_machine != null and action_state_machine.is_busy():
        return false
    _set_defense_mode(DirectHitResolver.DEFENSE_BLOCK)
    return true


func request_parry() -> bool:
    if not supports_parry() or tuning == null:
        return false
    if _parry_window_ticks_remaining > 0 or _parry_recovery_ticks_remaining > 0:
        return false
    if _defense_mode == DirectHitResolver.DEFENSE_BLOCK:
        return false
    if action_state_machine != null and action_state_machine.is_busy():
        return false
    _parry_window_ticks_remaining = tuning.melee_parry_window_ticks
    _set_defense_mode(DirectHitResolver.DEFENSE_PARRY)
    parry_started.emit(_parry_window_ticks_remaining)
    return true


func get_defense_mode() -> StringName:
    return DirectHitResolver.DEFENSE_BLOCK if has_active_playtest_ward() else _defense_mode


func has_active_playtest_ward() -> bool:
    return _configured_class_id == StarterKitCatalog.CLASS_MAGE and _playtest_ward_ticks_remaining > 0


func activate_playtest_ward(duration_ticks: int) -> bool:
    if _configured_class_id != StarterKitCatalog.CLASS_MAGE or duration_ticks <= 0 or duration_ticks > 600:
        return false
    if action_state_machine == null or action_state_machine.get_phase() != ActionStateMachine.Phase.ACTIVE:
        return false
    if action_state_machine.get_current_action_id() != &"action:playtest:aegis_ward":
        return false
    _playtest_ward_ticks_remaining = duration_ticks
    defense_mode_changed.emit(get_defense_mode())
    return true


func get_playtest_ward_ticks_remaining() -> int:
    return _playtest_ward_ticks_remaining


func get_parry_window_ticks_remaining() -> int:
    return _parry_window_ticks_remaining


func get_parry_recovery_ticks_remaining() -> int:
    return _parry_recovery_ticks_remaining


func cancel_defense() -> void:
    _clear_defense_state()


func get_mana() -> float:
    if not has_mana():
        return 0.0
    return resource_pool.get_value(RESOURCE_MANA)


func get_max_mana() -> float:
    if not has_mana():
        return 0.0
    return resource_pool.get_maximum(RESOURCE_MANA)

func capture_safe_state() -> Dictionary:
    var result := {
        "class_id": String(_configured_class_id),
        "defense_mode": String(_defense_mode),
        "parry_window_ticks_remaining": _parry_window_ticks_remaining,
        "parry_recovery_ticks_remaining": _parry_recovery_ticks_remaining,
        "action_cooldowns": action_state_machine.capture_cooldown_state() if action_state_machine != null else {},
        "status_states": get_status_safe_states(),
    }
    if has_mana():
        result["mana"] = get_mana()
        result["mana_maximum_at_capture"] = get_max_mana()
        result["mana_regeneration_delay_ticks"] = mana_regenerator.get_remaining_delay_ticks()
    return result

func restore_safe_state(data: Dictionary) -> bool:
    if starter_kit == null or StringName(String(data.get("class_id", &""))) != _configured_class_id:
        return false
    var status_result := _normalize_persisted_status_states(data.get("status_states", []))
    if not bool(status_result.get("accepted", false)):
        return false
    var cooldowns: Variant = data.get("action_cooldowns", {})
    if action_state_machine != null and not action_state_machine.restore_cooldown_state(cooldowns):
        return false
    var defense_mode := StringName(String(data.get("defense_mode", DirectHitResolver.DEFENSE_NONE)))
    var parry_window := int(data.get("parry_window_ticks_remaining", 0))
    var parry_recovery := int(data.get("parry_recovery_ticks_remaining", 0))
    if parry_window < 0 or parry_recovery < 0:
        return false
    if defense_mode == DirectHitResolver.DEFENSE_BLOCK and not supports_block():
        return false
    if defense_mode == DirectHitResolver.DEFENSE_PARRY and (not supports_parry() or parry_window <= 0):
        return false
    if not [DirectHitResolver.DEFENSE_NONE, DirectHitResolver.DEFENSE_BLOCK, DirectHitResolver.DEFENSE_PARRY].has(defense_mode):
        return false
    if has_mana():
        var mana_variant: Variant = data.get("mana", get_mana())
        var delay_variant: Variant = data.get("mana_regeneration_delay_ticks", 0)
        if not (typeof(mana_variant) == TYPE_INT or typeof(mana_variant) == TYPE_FLOAT) or not _is_integral_nonnegative(delay_variant):
            return false
        var mana_value := float(mana_variant)
        if not is_finite(mana_value) or mana_value < 0.0:
            return false
        if not resource_pool.set_value(RESOURCE_MANA, mana_value):
            return false
        if not mana_regenerator.restore_remaining_delay_ticks(int(delay_variant)):
            return false
    _parry_window_ticks_remaining = parry_window
    _parry_recovery_ticks_remaining = parry_recovery
    _set_defense_mode(defense_mode)
    _status_safe_states = (status_result.get("states", []) as Array).duplicate(true)
    return true


func store_status_safe_states(raw_states: Variant) -> bool:
    var result := PrototypeStatusResolver.normalize_states(raw_states)
    if not bool(result.get("accepted", false)):
        return false
    _status_safe_states = (result.get("states", []) as Array).duplicate(true)
    return true


func get_status_safe_states() -> Array:
    return _status_safe_states.duplicate(true)


func _normalize_persisted_status_states(raw_states: Variant) -> Dictionary:
    if not raw_states is Array:
        return {"accepted": false, "reason_id": PrototypeStatusResolver.REASON_INVALID_STATES, "states": []}
    var normalized_input: Array = []
    for raw_state: Variant in raw_states as Array:
        if not raw_state is Dictionary:
            return {"accepted": false, "reason_id": PrototypeStatusResolver.REASON_INVALID_STATES, "states": []}
        var state := (raw_state as Dictionary).duplicate(true)
        var remaining_variant: Variant = state.get("remaining_ticks", null)
        if typeof(remaining_variant) == TYPE_FLOAT:
            var remaining_number := float(remaining_variant)
            if not is_finite(remaining_number) or not is_equal_approx(remaining_number, round(remaining_number)):
                return {"accepted": false, "reason_id": PrototypeStatusResolver.REASON_INVALID_STATES, "states": []}
            state["remaining_ticks"] = int(remaining_number)
        normalized_input.append(state)
    return PrototypeStatusResolver.normalize_states(normalized_input)


func _is_integral_nonnegative(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return int(value) >= 0
    if typeof(value) != TYPE_FLOAT:
        return false
    var number := float(value)
    return is_finite(number) and number >= 0.0 and is_equal_approx(number, round(number))


func _physics_process(_delta: float) -> void:
    advance_resource_tick()


func advance_resource_tick() -> void:
    if has_mana():
        mana_regenerator.advance_fixed_tick(resource_pool, RESOURCE_MANA)
    _advance_defense_tick()


func _advance_defense_tick() -> void:
    if _playtest_ward_ticks_remaining > 0:
        _playtest_ward_ticks_remaining -= 1
        if _playtest_ward_ticks_remaining == 0:
            defense_mode_changed.emit(get_defense_mode())
    if _parry_window_ticks_remaining > 0:
        _parry_window_ticks_remaining -= 1
        if _parry_window_ticks_remaining == 0:
            _set_defense_mode(DirectHitResolver.DEFENSE_NONE)
            _parry_recovery_ticks_remaining = 0 if tuning == null else tuning.melee_parry_recovery_ticks
            parry_ended.emit()
        return
    if _parry_recovery_ticks_remaining > 0:
        _parry_recovery_ticks_remaining -= 1


func _clear_defense_state() -> void:
    _playtest_ward_ticks_remaining = 0
    _parry_window_ticks_remaining = 0
    _parry_recovery_ticks_remaining = 0
    _set_defense_mode(DirectHitResolver.DEFENSE_NONE)


func _set_defense_mode(mode: StringName) -> void:
    if _defense_mode == mode:
        return
    _defense_mode = mode
    defense_mode_changed.emit(_defense_mode)


func _bind_action_machine() -> void:
    if action_state_machine == null:
        return
    action_state_machine.set_resource_pool(resource_pool)
    if not action_state_machine.action_commit_point_reached.is_connected(_on_action_commit_point_reached):
        action_state_machine.action_commit_point_reached.connect(_on_action_commit_point_reached)


func _on_action_commit_point_reached(action: ActionDefinition, _action_instance_id: int) -> void:
    if action == null or action.cost_amount <= 0.0:
        return
    if action.cost_resource == RESOURCE_MANA and has_mana():
        mana_regenerator.notify_spend()
