class_name TowerPrototypeEnemyRuntimeFactory
extends RefCounted

static func build_states(
    floor_state: FloorInstanceState,
    plan: Dictionary,
    tuning: TowerPrototypeEnemyRuntimeTuning
) -> Dictionary:
    if floor_state == null or tuning == null or not tuning.validate_tuning().is_empty():
        return {}
    if not TowerEncounterPlanValidator.validate(plan, floor_state).is_empty():
        return {}
    var floor_id := floor_state.floor_id
    var states: Dictionary = {}
    for raw_placement: Variant in plan.get("placements", []) as Array:
        if not raw_placement is Dictionary:
            return {}
        var placement := raw_placement as Dictionary
        var actor_id := StringName(String(placement.get("actor_id", &"")))
        var archetype_id := StringName(String(placement.get("archetype_id", &"")))
        var definition := EnemyArchetypeCatalog.get_definition(archetype_id)
        if definition == null or states.has(actor_id):
            return {}
        var role_stats: EnemyArchetypePlaytestStats = null
        if tuning.archetype_stats != null:
            role_stats = tuning.archetype_stats.stats_for(archetype_id)
            if role_stats == null:
                return {}
        var elite := bool(placement.get("elite", false))
        var hp_base := tuning.base_hp + tuning.hp_per_floor * (floor_id - 1)
        var hp_multiplier := role_stats.hp_multiplier if role_stats != null else 1.0
        var hp := maxi(1, roundi(float(hp_base) * hp_multiplier * (tuning.elite_hp_multiplier if elite else 1.0)))
        var stamina := (tuning.defender_stamina if archetype_id == &"defender" else tuning.base_stamina) + (role_stats.stamina_bonus if role_stats != null else 0.0)
        var physical_defense := tuning.base_physical_defense + (role_stats.physical_defense_bonus if role_stats != null else 0.0) + (tuning.elite_defense_bonus if elite else 0.0)
        var arcane_defense := tuning.base_arcane_defense + (role_stats.arcane_defense_bonus if role_stats != null else 0.0) + (tuning.elite_defense_bonus if elite else 0.0)
        var poise := tuning.base_poise_threshold + tuning.poise_per_floor * float(floor_id - 1)
        if role_stats != null:
            poise *= role_stats.poise_multiplier
        if elite:
            poise *= tuning.elite_poise_multiplier
        var state := CombatantRuntimeState.new()
        if not state.configure(
            actor_id,
            hp,
            stamina,
            physical_defense,
            arcane_defense,
            poise,
            true,
            archetype_id == &"defender",
            false
        ):
            return {}
        states[actor_id] = state
    return states
