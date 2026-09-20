extends SceneTree

const TUNING: TowerPrototypeEnemyRuntimeTuning = preload("res://src/data/tuning/tower_prototype_enemy_runtime_default.tres")
const ATTACKS: EnemyPlaytestAttackCatalog = preload("res://src/data/tuning/enemy_attacks_playtest_v01.tres")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_shipped_role_data()
    _test_invalid_roles_and_non_damage_attack_boundaries()
    _test_role_stats_reach_real_factory()
    if _failures == 0:
        print("ENEMY ARCHETYPE PLAYTEST STATS TEST PASS")
    else:
        push_error("ENEMY ARCHETYPE PLAYTEST STATS FAILURES: %d" % _failures)
    quit(_failures)


func _test_shipped_role_data() -> void:
    _expect(TUNING.validate_tuning().is_empty(), "shipped floor tuning and role catalog validate")
    var catalog := TUNING.archetype_stats
    _expect(catalog != null and catalog.playtest_placeholder, "twelve-role Inspector resource remains explicitly provisional")
    if catalog == null:
        return
    _expect(catalog.stats_by_archetype.size() == 12, "all twelve mechanical roles have explicit stat records")
    var readiness := catalog.production_readiness_errors()
    _expect(readiness.has("all enemy roles still share one neutral stat profile")
        and readiness.has("duelist difficulty is unauthored")
        and readiness.has("approved per-role balance evidence reference is missing"),
        "neutral roles and unauthored difficulty remain explicit production blockers")
    _expect(ATTACKS.production_readiness_errors().has("approved enemy attack balance/contact evidence reference is missing"),
        "playtest attack catalog cannot be presented as approved final contact balance")
    for id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        var stats := catalog.stats_for(id)
        _expect(stats != null and stats.archetype_id == id, "%s has canonical independent Inspector stats" % String(id))
        if stats == null:
            continue
        _expect(stats.difficulty_rating == -1 and stats.xp_reward == -1 and stats.gold_reward == -1, "%s leaves difficulty, XP and Gold unauthored" % String(id))
        _expect(is_equal_approx(stats.hp_multiplier, 1.0) and is_equal_approx(stats.poise_multiplier, 1.0), "%s preserves current baseline until role tuning is approved" % String(id))
        stats.hp_multiplier = 3.0
        _expect(is_equal_approx(catalog.stats_for(id).hp_multiplier, 1.0), "%s callers cannot mutate Inspector source" % String(id))


func _test_invalid_roles_and_non_damage_attack_boundaries() -> void:
    var missing := EnemyArchetypePlaytestStatsCatalog.new()
    missing.stats_by_archetype = TUNING.archetype_stats.stats_by_archetype.duplicate()
    missing.stats_by_archetype.erase("support")
    _expect(not missing.validate_catalog().is_empty() and missing.stats_for(&"duelist") == null, "missing Support stats fail closed for every role")
    var wrong := EnemyArchetypePlaytestStatsCatalog.new()
    wrong.stats_by_archetype = TUNING.archetype_stats.stats_by_archetype.duplicate()
    var wrong_stat := TUNING.archetype_stats.stats_for(&"support")
    wrong_stat.archetype_id = &"duelist"
    wrong.stats_by_archetype["support"] = wrong_stat
    _expect(not wrong.validate_catalog().is_empty(), "mismatched role identity rejects the catalog")
    var invalid := EnemyArchetypePlaytestStats.new()
    invalid.archetype_id = &"duelist"
    invalid.hp_multiplier = INF
    _expect(not invalid.validate_authoring().is_empty(), "nonfinite role stats reject")
    invalid.hp_multiplier = 1.0
    invalid.difficulty_rating = 0
    _expect(not invalid.validate_authoring().is_empty(), "difficulty must be positive or explicitly unauthored")
    invalid.difficulty_rating = -1
    invalid.xp_reward = -2
    _expect(not invalid.validate_authoring().is_empty(), "unapproved negative rewards reject")
    invalid.xp_reward = 1000001
    _expect(not invalid.validate_authoring().is_empty(), "out-of-range reward rejects even when bypassing Inspector")
    invalid.xp_reward = -1
    invalid.difficulty_rating = 101
    _expect(not invalid.validate_authoring().is_empty(), "out-of-range difficulty rejects even when bypassing Inspector")

    _expect(ATTACKS.validate_catalog().is_empty(), "shipped nine hits and three special actions validate")
    var modified := ATTACKS.duplicate(true) as EnemyPlaytestAttackCatalog
    modified.attack_by_archetype["support"] = ATTACKS.attack_for(&"duelist")
    modified.deferred_non_damage_archetypes.erase(&"support")
    _expect(not modified.validate_catalog().is_empty(), "Support cannot be converted into a damaging signature by removing its deferment")
    var repeated := ATTACKS.duplicate(true) as EnemyPlaytestAttackCatalog
    repeated.deferred_non_damage_archetypes.append(&"support")
    _expect(not repeated.validate_catalog().is_empty(), "duplicated non-damaging signature records reject")
    var zero_damage := ATTACKS.duplicate(true) as EnemyPlaytestAttackCatalog
    var duelist := ATTACKS.attack_for(&"duelist")
    duelist.payload.raw_damage = 0.0
    zero_damage.attack_by_archetype["duelist"] = duelist
    _expect(not zero_damage.validate_catalog().is_empty(), "nine damaging signatures cannot silently become zero damage")
    _expect(zero_damage.attack_for(&"marksman") == null,
        "invalid attack manifest fails closed for all live archetypes, even otherwise valid records")
    var unsupported_tick := ATTACKS.duplicate(true) as EnemyPlaytestAttackCatalog
    var altered_hit := ATTACKS.attack_for(&"duelist")
    altered_hit.geometry.hit_active_ticks = PackedInt32Array([1])
    unsupported_tick.attack_by_archetype["duelist"] = altered_hit
    _expect(not unsupported_tick.validate_catalog().is_empty(),
        "a second ACTIVE tick cannot be authored while live delivery emits only at tick zero")
    var unsupported_delivery := ATTACKS.duplicate(true) as EnemyPlaytestAttackCatalog
    var altered_shot := ATTACKS.attack_for(&"marksman")
    altered_shot.payload.delivery = DirectHitResolver.DELIVERY_CONTACT
    unsupported_delivery.attack_by_archetype["marksman"] = altered_shot
    _expect(not unsupported_delivery.validate_catalog().is_empty(),
        "ranged signature cannot silently lose its live projectile delivery mode")
    var invalid_shape := ATTACKS.duplicate(true) as EnemyPlaytestAttackCatalog
    var altered_shape := ATTACKS.attack_for(&"bruiser")
    var empty_rectangle := RectangleShape2D.new()
    empty_rectangle.size = Vector2.ZERO
    altered_shape.geometry.query_shape = empty_rectangle
    invalid_shape.attack_by_archetype["bruiser"] = altered_shape
    _expect(not invalid_shape.validate_catalog().is_empty(), "degenerate attack physics shapes reject")


func _test_role_stats_reach_real_factory() -> void:
    var floor := _floor_state(5)
    var plan := TowerPrototypeEncounterContentCatalog.build_plan(floor)
    var original := TowerPrototypeEnemyRuntimeFactory.build_states(floor, plan, TUNING)
    _expect(not original.is_empty(), "original floor-five states build")
    var custom := TUNING.duplicate(true) as TowerPrototypeEnemyRuntimeTuning
    var custom_catalog := EnemyArchetypePlaytestStatsCatalog.new()
    custom_catalog.stats_by_archetype = {}
    for id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        custom_catalog.stats_by_archetype[String(id)] = TUNING.archetype_stats.stats_for(id)
    custom.archetype_stats = custom_catalog
    var changed := custom_catalog.stats_by_archetype["marksman"] as EnemyArchetypePlaytestStats
    changed.hp_multiplier = 1.25
    changed.stamina_bonus = 4.0
    changed.physical_defense_bonus = 7.0
    changed.arcane_defense_bonus = 3.0
    changed.poise_multiplier = 1.2
    _expect(custom.validate_tuning().is_empty(), "per-role Inspector adjustments are valid")
    var adjusted := TowerPrototypeEnemyRuntimeFactory.build_states(floor, plan, custom)
    _expect(adjusted.size() == original.size(), "role tuning preserves all encounter residents")
    var observed_marksman := false
    for raw_placement: Variant in plan.get("placements", []):
        var placement := raw_placement as Dictionary
        var actor_id := StringName(String(placement["actor_id"]))
        var before := original.get(actor_id) as CombatantRuntimeState
        var after := adjusted.get(actor_id) as CombatantRuntimeState
        if before == null or after == null:
            _expect(false, "existing placement survives role adjustment")
            continue
        if StringName(String(placement["archetype_id"])) != &"marksman":
            _expect(before.max_hp == after.max_hp and is_equal_approx(before.physical_defense, after.physical_defense), "unmodified archetypes retain existing health and defense")
            continue
        observed_marksman = true
        _expect(after.max_hp == maxi(1, roundi((TUNING.base_hp + TUNING.hp_per_floor * 4) * 1.25 * TUNING.elite_hp_multiplier)), "Marksman HP multiplier reaches the real elite stat factory")
        _expect(is_equal_approx(after.physical_defense, before.physical_defense + 7.0), "Marksman Physical Defense reaches the real stat factory")
        _expect(is_equal_approx(after.arcane_defense, before.arcane_defense + 3.0), "Marksman Arcane Defense reaches the real stat factory")
        _expect(is_equal_approx(after.current_stamina, before.current_stamina + 4.0), "Marksman stamina addition reaches the real stat factory")
        _expect(is_equal_approx(after.poise_threshold, before.poise_threshold * 1.2), "Marksman poise multiplier reaches the real stat factory")
    _expect(observed_marksman, "Floor 5 has an actual Marksman elite to exercise role data")
    _expect(TUNING.validate_tuning().is_empty(), "custom fixture leaves shipped tuning unchanged")


func _floor_state(floor_id: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id, 93000 + floor_id, &"tower_generator:v01", &"tower_modules:v01",
        &"encounters:role_stats_playtest", StringName("quest_flags:role_stats_f%02d" % floor_id))
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:role_stats_f%02d" % floor_id),
        TowerPrevalidatedFallbackFactory.build_for_request(request))


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
