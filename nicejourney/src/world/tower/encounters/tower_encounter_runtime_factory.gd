class_name TowerEncounterRuntimeFactory
extends RefCounted

const REASON_INVALID_CONTEXT: StringName = &"invalid_context"
const REASON_PLAN_INVALID: StringName = &"plan_invalid"
const REASON_ENCOUNTER_MISSING: StringName = &"encounter_missing"
const REASON_PLAYER_INVALID: StringName = &"player_invalid"
const REASON_ENEMY_STATE_MISSING: StringName = &"enemy_state_missing"
const REASON_REGISTRATION_FAILED: StringName = &"registration_failed"
const REASON_ARCHETYPE_RUNTIME_FAILED: StringName = &"archetype_runtime_failed"

static func activate(
    floor_state: FloorInstanceState,
    plan: Dictionary,
    encounter_id: StringName,
    player_state: CombatantRuntimeState,
    enemy_states: Dictionary,
    shared_active_combat: ActiveCombatRegistry = null,
    shared_full_ai: FullAiSimulationLedger = null,
    shared_attack_pressure: AttackPressureLedger = null
) -> Dictionary:
    if floor_state == null or player_state == null or not StableId.is_valid(String(encounter_id)):
        return _rejected(REASON_INVALID_CONTEXT)
    var plan_errors := TowerEncounterPlanValidator.validate(plan, floor_state)
    if not plan_errors.is_empty():
        var rejected := _rejected(REASON_PLAN_INVALID)
        rejected["errors"] = plan_errors.duplicate()
        return rejected
    if player_state.actor_id == &"" or player_state.is_defeated():
        return _rejected(REASON_PLAYER_INVALID)

    var all_placements := TowerEncounterPlanValidator.placements_for_encounter(plan, encounter_id)
    if all_placements.is_empty():
        return _rejected(REASON_ENCOUNTER_MISSING)

    var active_placements: Array[Dictionary] = []
    var skipped_defeated: Array[StringName] = []
    for placement: Dictionary in all_placements:
        var actor_id := StringName(String(placement["actor_id"]))
        if floor_state.defeated_actor_ids.has(actor_id):
            skipped_defeated.append(actor_id)
            continue
        var resolved := placement.duplicate(true)
        var world_tile: Variant = TowerEncounterPlanValidator.world_tile_for_placement(floor_state, placement)
        if not world_tile is Vector2i:
            return _rejected(REASON_PLAN_INVALID)
        resolved["world_tile"] = world_tile
        active_placements.append(resolved)

    if active_placements.is_empty():
        return {
            "accepted": true,
            "reason_id": &"encounter_already_resolved",
            "resolved": true,
            "encounter_id": encounter_id,
            "encounter_runtime": null,
            "archetype_runtimes": {},
            "placements": [],
            "skipped_defeated_actor_ids": skipped_defeated.duplicate(),
        }

    var encounter := CombatEncounterRuntime.new()
    if not encounter.configure(encounter_id, shared_active_combat, shared_full_ai, shared_attack_pressure):
        return _rejected(REASON_REGISTRATION_FAILED)
    if not encounter.register_player(player_state):
        encounter.end_encounter()
        return _rejected(REASON_PLAYER_INVALID)

    var archetype_runtimes: Dictionary = {}
    for placement: Dictionary in active_placements:
        var actor_id := StringName(String(placement["actor_id"]))
        var state_variant: Variant = enemy_states.get(actor_id, enemy_states.get(String(actor_id), null))
        if not state_variant is CombatantRuntimeState:
            encounter.end_encounter()
            return _rejected_with_actor(REASON_ENEMY_STATE_MISSING, actor_id)
        var enemy_state := state_variant as CombatantRuntimeState
        if enemy_state.actor_id != actor_id or enemy_state.is_defeated():
            encounter.end_encounter()
            return _rejected_with_actor(REASON_ENEMY_STATE_MISSING, actor_id)
        if not encounter.register_enemy(enemy_state):
            encounter.end_encounter()
            return _rejected_with_actor(REASON_REGISTRATION_FAILED, actor_id)
        var runtime := EnemyArchetypeRuntime.new()
        if not runtime.configure(encounter, actor_id, player_state.actor_id, StringName(String(placement["archetype_id"]))):
            encounter.end_encounter()
            return _rejected_with_actor(REASON_ARCHETYPE_RUNTIME_FAILED, actor_id)
        archetype_runtimes[actor_id] = runtime

    return {
        "accepted": true,
        "reason_id": &"",
        "resolved": false,
        "encounter_id": encounter_id,
        "encounter_runtime": encounter,
        "archetype_runtimes": archetype_runtimes,
        "placements": active_placements.duplicate(true),
        "skipped_defeated_actor_ids": skipped_defeated.duplicate(),
    }

static func _rejected(reason_id: StringName) -> Dictionary:
    return {
        "accepted": false,
        "reason_id": reason_id,
        "resolved": false,
        "encounter_id": &"",
        "encounter_runtime": null,
        "archetype_runtimes": {},
        "placements": [],
        "skipped_defeated_actor_ids": [],
        "actor_id": &"",
        "errors": PackedStringArray(),
    }

static func _rejected_with_actor(reason_id: StringName, actor_id: StringName) -> Dictionary:
    var result := _rejected(reason_id)
    result["actor_id"] = actor_id
    return result
