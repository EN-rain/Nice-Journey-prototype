class_name CombatBalanceTelemetry
extends RefCounted

# Opt-in, read-only instrumentation. Never mutates combat or awards rewards.
# Call advance_fixed_tick once per simulated physics tick, and sample_resources
# when live stamina/mana meters are available. No wall-clock dependency.
const SCHEMA_VERSION: int = 1
const TICKS_PER_SECOND: float = 60.0

var _encounter: CombatEncounterRuntime = null
var _machine: ActionStateMachine = null
var _player_id: StringName = &""
var _class_id: StringName = &""
var _scenario_id: StringName = &""
var _tick: int = 0
var _started_tick: int = 0
var _last_damage_tick: int = -1
var _first_action_tick: int = -1
var _defeat_tick: int = -1
var _enemy_max_hp: int = 0
var _enemy_count: int = 0
var _hp_by_actor: Dictionary = {}
var _overkill_damage: int = 0
var _action_counts: Dictionary = {}
var _action_by_instance: Dictionary = {}
var _damage_by_action: Dictionary = {}
var _hits_by_action: Dictionary = {}
var _cooldown_ticks: Dictionary = {}
var _resource_spent: Dictionary = {"mana": 0.0, "stamina": 0.0}
var _resource_minima: Dictionary = {}
var _defense_counts: Dictionary = {"dodged": 0, "blocked": 0, "parried": 0, "guard_broken": 0}
var _status_damage_taken: int = 0
var _status_damage_dealt: int = 0
var _damage_dealt: int = 0
var _damage_taken: int = 0
var _player_deaths: int = 0
var _enemy_defeats: int = 0
var _rejected_actions: int = 0
var _is_active: bool = false


func begin(encounter: CombatEncounterRuntime, player_id: StringName, class_id: StringName,
        scenario_id: StringName, action_machine: ActionStateMachine = null) -> bool:
    stop()
    if (encounter == null or encounter.get_combatant(player_id) == null
        or class_id not in [&"melee", &"ranged", &"mage"]
        or not StableId.is_valid(String(scenario_id))):
        return false
    _encounter = encounter
    _machine = action_machine
    _player_id = player_id
    _class_id = class_id
    _scenario_id = scenario_id
    _tick = 0
    _started_tick = 0
    _last_damage_tick = -1
    _first_action_tick = -1
    _defeat_tick = -1
    _enemy_max_hp = 0
    _enemy_count = 0
    _hp_by_actor = {}
    _overkill_damage = 0
    _action_counts = {}
    _action_by_instance = {}
    _damage_by_action = {}
    _hits_by_action = {}
    _cooldown_ticks = {}
    _resource_spent = {"mana": 0.0, "stamina": 0.0}
    _resource_minima = {}
    _defense_counts = {"dodged": 0, "blocked": 0, "parried": 0, "guard_broken": 0}
    _status_damage_taken = 0
    _status_damage_dealt = 0
    _damage_dealt = 0
    _damage_taken = 0
    _player_deaths = 0
    _enemy_defeats = 0
    _rejected_actions = 0
    for actor_id: Variant in encounter.get_registered_combatant_ids():
        var state := encounter.get_combatant(StringName(String(actor_id)))
        if state != null:
            _hp_by_actor[String(state.actor_id)] = state.current_hp
            if state.actor_id != player_id:
                _enemy_max_hp += state.max_hp
                _enemy_count += 1
    encounter.direct_contact_resolved.connect(_on_contact)
    encounter.status_damage_resolved.connect(_on_status_damage)
    encounter.enemy_defeated.connect(_on_enemy_defeated)
    encounter.player_defeated.connect(_on_player_defeated)
    if _machine != null:
        _machine.action_started.connect(_on_action_started)
        _machine.action_rejected.connect(_on_action_rejected)
        _machine.action_commit_point_reached.connect(_on_action_commit)
    _is_active = true
    return true


func stop() -> void:
    if _encounter != null:
        if _encounter.direct_contact_resolved.is_connected(_on_contact):
            _encounter.direct_contact_resolved.disconnect(_on_contact)
        if _encounter.status_damage_resolved.is_connected(_on_status_damage):
            _encounter.status_damage_resolved.disconnect(_on_status_damage)
        if _encounter.enemy_defeated.is_connected(_on_enemy_defeated):
            _encounter.enemy_defeated.disconnect(_on_enemy_defeated)
        if _encounter.player_defeated.is_connected(_on_player_defeated):
            _encounter.player_defeated.disconnect(_on_player_defeated)
    if _machine != null:
        if _machine.action_started.is_connected(_on_action_started):
            _machine.action_started.disconnect(_on_action_started)
        if _machine.action_rejected.is_connected(_on_action_rejected):
            _machine.action_rejected.disconnect(_on_action_rejected)
        if _machine.action_commit_point_reached.is_connected(_on_action_commit):
            _machine.action_commit_point_reached.disconnect(_on_action_commit)
    _is_active = false
    _encounter = null
    _machine = null


func advance_fixed_tick() -> void:
    if not _is_active:
        return
    _tick += 1
    if _machine != null:
        for action_id: Variant in _action_counts.keys():
            if _machine.get_cooldown_ticks(StringName(String(action_id))) > 0:
                _cooldown_ticks[String(action_id)] = int(_cooldown_ticks.get(String(action_id), 0)) + 1


func sample_resources(stamina: float, mana: float = -1.0) -> void:
    if not _is_active:
        return
    for pair: Array in [["stamina", stamina], ["mana", mana]]:
        var amount := float(pair[1])
        if is_finite(amount) and amount >= 0.0:
            var key := String(pair[0])
            _resource_minima[key] = minf(float(_resource_minima.get(key, amount)), amount)


func snapshot() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "source": "observed_combat_signals",
        "class_id": String(_class_id),
        "scenario_id": String(_scenario_id),
        "ticks": _tick,
        "seconds": float(_tick) / TICKS_PER_SECOND,
        "first_action_tick": _first_action_tick,
        "last_damage_tick": _last_damage_tick,
        "all_enemies_defeated": _enemy_count > 0 and _enemy_defeats == _enemy_count,
        "time_to_defeat_ticks": -1 if _enemy_count <= 0 or _enemy_defeats != _enemy_count or _first_action_tick < 0 else _defeat_tick - _first_action_tick,
        "enemy_max_hp": _enemy_max_hp,
        "enemy_defeats": _enemy_defeats,
        "player_deaths": _player_deaths,
        "damage_dealt": _damage_dealt,
        "damage_taken": _damage_taken,
        "overkill_damage": _overkill_damage,
        "status_damage_dealt": _status_damage_dealt,
        "status_damage_taken": _status_damage_taken,
        "action_counts": _action_counts.duplicate(true),
        "damage_by_action": _damage_by_action.duplicate(true),
        "successful_contacts_by_action": _hits_by_action.duplicate(true),
        "rejected_actions": _rejected_actions,
        "cooldown_active_ticks": _cooldown_ticks.duplicate(true),
        "committed_resource_costs": _resource_spent.duplicate(true),
        "observed_resource_minima": _resource_minima.duplicate(true),
        "defense_outcomes": _defense_counts.duplicate(true),
    }


func _on_contact(attacker_id: StringName, target_id: StringName, instance_id: int,
        _interval: int, result: Dictionary) -> void:
    if not _is_active or not bool(result.get("accepted", false)):
        return
    var damage := maxi(0, int(result.get("hp_damage", 0)))
    var target_key := String(target_id)
    var hp_before := int(_hp_by_actor.get(target_key, damage))
    var applied := mini(damage, maxi(0, hp_before))
    _hp_by_actor[target_key] = int(result.get("target_hp_after", maxi(0, hp_before - applied)))
    _overkill_damage += damage - applied
    if attacker_id == _player_id and target_id != _player_id:
        _damage_dealt += applied
        var action_id := String(_action_by_instance.get(instance_id, &""))
        if not action_id.is_empty():
            _damage_by_action[action_id] = int(_damage_by_action.get(action_id, 0)) + applied
            _hits_by_action[action_id] = int(_hits_by_action.get(action_id, 0)) + 1
        if damage > 0:
            _last_damage_tick = _tick
    elif target_id == _player_id:
        _damage_taken += applied
        match StringName(String(result.get("outcome", &""))):
            DirectHitResolver.OUTCOME_DODGED:
                _defense_counts["dodged"] += 1
            DirectHitResolver.OUTCOME_BLOCKED:
                _defense_counts["blocked"] += 1
            DirectHitResolver.OUTCOME_PARRIED:
                _defense_counts["parried"] += 1
            DirectHitResolver.OUTCOME_GUARD_BROKEN:
                _defense_counts["guard_broken"] += 1


func _on_status_damage(actor_id: StringName, damage: int, _hp_after: int) -> void:
    if not _is_active or damage <= 0:
        return
    var key := String(actor_id)
    var applied := mini(damage, maxi(0, int(_hp_by_actor.get(key, damage))))
    _hp_by_actor[key] = maxi(0, _hp_by_actor.get(key, applied) - applied)
    _overkill_damage += damage - applied
    if actor_id == _player_id:
        _status_damage_taken += applied
        _damage_taken += applied
    else:
        _status_damage_dealt += applied
        _damage_dealt += applied
        _last_damage_tick = _tick


func _on_enemy_defeated(_actor_id: StringName) -> void:
    if _is_active:
        _enemy_defeats += 1
        _defeat_tick = _tick


func _on_player_defeated(_actor_id: StringName) -> void:
    if _is_active:
        _player_deaths += 1


func _on_action_started(action_id: StringName, instance_id: int) -> void:
    if not _is_active:
        return
    if _first_action_tick < 0:
        _first_action_tick = _tick
    var key := String(action_id)
    _action_by_instance[instance_id] = action_id
    _action_counts[key] = int(_action_counts.get(key, 0)) + 1


func _on_action_rejected(_action_id: StringName, _reason: String) -> void:
    if _is_active:
        _rejected_actions += 1


func _on_action_commit(action: ActionDefinition, _instance_id: int) -> void:
    if not _is_active or action == null or action.cost_amount <= 0.0:
        return
    var key := String(action.cost_resource)
    if _resource_spent.has(key):
        _resource_spent[key] = float(_resource_spent[key]) + action.cost_amount
