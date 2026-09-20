class_name TowerEncounterProgressBinder
extends RefCounted

signal progress_committed(result: Dictionary)

var _profile: ProfileSnapshot = null
var _floor_state: FloorInstanceState = null
var _encounter: CombatEncounterRuntime = null
var _quest_bindings_by_actor: Dictionary = {}

func bind(
    profile: ProfileSnapshot,
    floor_state: FloorInstanceState,
    encounter: CombatEncounterRuntime,
    quest_bindings_by_actor: Dictionary = {}
) -> bool:
    unbind()
    if profile == null or floor_state == null or encounter == null or encounter.encounter_id == &"":
        return false
    if not FloorInstanceState.validate_dictionary(floor_state.to_dictionary()).is_empty():
        return false
    var normalized: Dictionary = {}
    for actor_variant: Variant in quest_bindings_by_actor.keys():
        var actor_id := StringName(String(actor_variant))
        var raw_bindings: Variant = quest_bindings_by_actor[actor_variant]
        if not StableId.is_valid(String(actor_id)) or not raw_bindings is Array:
            return false
        normalized[actor_id] = (raw_bindings as Array).duplicate(true)
    _profile = profile
    _floor_state = floor_state
    _encounter = encounter
    _quest_bindings_by_actor = normalized
    if not _encounter.enemy_defeated.is_connected(_on_enemy_defeated):
        _encounter.enemy_defeated.connect(_on_enemy_defeated)
    return true

func unbind() -> void:
    if _encounter != null and _encounter.enemy_defeated.is_connected(_on_enemy_defeated):
        _encounter.enemy_defeated.disconnect(_on_enemy_defeated)
    _profile = null
    _floor_state = null
    _encounter = null
    _quest_bindings_by_actor = {}

func is_bound() -> bool:
    return _profile != null and _floor_state != null and _encounter != null

func _on_enemy_defeated(actor_id: StringName) -> void:
    if not is_bound():
        return
    var bindings_variant: Variant = _quest_bindings_by_actor.get(actor_id, [])
    var bindings: Array = (bindings_variant as Array).duplicate(true) if bindings_variant is Array else []
    var result := TowerEncounterProgressService.record_enemy_defeat(
        _profile,
        _floor_state,
        actor_id,
        bindings
    )
    progress_committed.emit(result.duplicate(true))
