extends SceneTree

# Normal-damage *controlled* baseline: action startup/commit/active/recovery,
# authoritative encounter HP/mitigation and shipped per-role Inspector stats.
# Guaranteed unobstructed contact, fixed Floor 5 and stationary nonretaliating
# enemy: NO geometry, tactical AI, boss, survival or human-input fairness claim.
const STARTER: StarterCombatTuning = preload("res://src/data/tuning/starter_combat_default.tres")
const ENEMIES: TowerPrototypeEnemyRuntimeTuning = preload("res://src/data/tuning/tower_prototype_enemy_runtime_default.tres")
const ATTACKS: EnemyPlaytestAttackCatalog = preload("res://src/data/tuning/enemy_attacks_playtest_v01.tres")
const FLOOR_ID: int = 5
const LIMIT_TICKS: int = 3600
const REPORT_PATH: String = "res://docs/evidence/combat_balance_baseline_local.json"

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _expect(STARTER.validate_tuning().is_empty() and ENEMIES.validate_tuning().is_empty()
        and ATTACKS.validate_catalog().is_empty(), "shipped class and enemy playtest tuning validate")
    var rows: Array[Dictionary] = []
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
            var row := _run_pair(class_id, archetype_id)
            if not row.is_empty():
                rows.append(row)
    _expect(rows.size() == 36, "exactly three classes by twelve authored archetype identities")
    # A deterministic replay is an additional guard against hidden random damage,
    # clocks or resource mutation in this fixed controlled scenario.
    var again := _run_pair(&"mage", &"duelist")
    var original := {}
    for row: Dictionary in rows:
        if row["class_id"] == "mage" and row["archetype_id"] == "duelist":
            original = row
    _expect(not original.is_empty() and JSON.stringify(original) == JSON.stringify(again),
        "repeat of the same class/archetype seed produces identical telemetry")
    var report := {
        "schema_version": CombatBalanceTelemetry.SCHEMA_VERSION,
        "label": "PLAYTEST controlled normal-damage baseline, NOT approved final balance",
        "scenario": "floor_5_stationary_nonretaliating_unobstructed_guaranteed_contact",
        "limitations": [
            "No actual movement, physics hit probability, AI retaliation, skills, passives, upgrades or boss.",
            "No player survival, human-input fairness, drop economy or final numerical approval.",
            "HP uses the shipped floor-scaled role-stat formula, not a generated floor placement.",
            "Time to defeat is action-clock ticks measured from the first basic request.",
        ],
        "floor_id": FLOOR_ID,
        "class_count": 3,
        "archetype_count": 12,
        "rows": rows,
    }
    if OS.get_cmdline_user_args().has("--write-balance-evidence") and _failures == 0:
        var file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
        _expect(file != null, "output evidence file opens")
        if file != null:
            file.store_string(JSON.stringify(report, "\t") + "\n")
            file.close()
            print("BALANCE EVIDENCE: " + ProjectSettings.globalize_path(REPORT_PATH))
    if _failures == 0:
        print("THREE CLASS COMBAT BALANCE BASELINE TEST PASS (36 normal-damage controlled scenarios)")
    else:
        push_error("THREE CLASS COMBAT BALANCE BASELINE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _run_pair(class_id: StringName, archetype_id: StringName) -> Dictionary:
    var machine := ActionStateMachine.new()
    var runtime := ClassCombatRuntime.new()
    runtime.tuning = STARTER
    runtime.bind_runtime(machine)
    if not _expect(runtime.configure_class(class_id),
            "%s/%s: configured starter class" % [String(class_id), String(archetype_id)]):
        runtime.free()
        machine.free()
        return {}
    var stats := ENEMIES.archetype_stats.stats_for(archetype_id)
    if not _expect(stats != null, "%s: real Inspector role stats assigned" % String(archetype_id)):
        runtime.free()
        machine.free()
        return {}
    var base_hp := ENEMIES.base_hp + ENEMIES.hp_per_floor * (FLOOR_ID - 1)
    var enemy_hp := maxi(1, roundi(float(base_hp) * stats.hp_multiplier))
    var player := CombatantRuntimeState.new()
    var enemy := CombatantRuntimeState.new()
    var player_id := StringName("player:baseline:%s" % String(class_id))
    var enemy_id := StringName("enemy:baseline:%s" % String(archetype_id))
    var player_valid := player.configure(player_id, 100, 100.0, 0.0, 0.0, 50.0, true,
        runtime.supports_block(), runtime.supports_parry())
    var enemy_valid := enemy.configure(enemy_id, enemy_hp,
        (ENEMIES.defender_stamina if archetype_id == &"defender" else ENEMIES.base_stamina) + stats.stamina_bonus,
        ENEMIES.base_physical_defense + stats.physical_defense_bonus,
        ENEMIES.base_arcane_defense + stats.arcane_defense_bonus,
        (ENEMIES.base_poise_threshold + ENEMIES.poise_per_floor * float(FLOOR_ID - 1)) * stats.poise_multiplier,
        true, archetype_id == &"defender", false)
    var encounter := CombatEncounterRuntime.new()
    if not _expect(player_valid and enemy_valid
        and encounter.configure(StringName("encounter:baseline:%s:%s" % [String(class_id), String(archetype_id)]))
        and encounter.register_player(player) and encounter.register_enemy(enemy),
        "%s/%s: registered shipped-stat encounter" % [String(class_id), String(archetype_id)]):
        runtime.free()
        machine.free()
        return {}
    var observer := CombatBalanceTelemetry.new()
    var scenario_id := StringName("baseline:floor5:%s:%s" % [String(class_id), String(archetype_id)])
    _expect(observer.begin(encounter, player_id, class_id, scenario_id, machine),
        "read-only signal telemetry binds to live encounter/action machine")
    var last_hit_instance := 0
    var total_hits := 0
    var hit_was_valid := true
    while enemy.current_hp > 0 and observer.snapshot()["ticks"] < LIMIT_TICKS:
        if not machine.is_busy():
            if not runtime.request_basic_attack(Vector2.RIGHT):
                hit_was_valid = false
                break
        machine.advance_fixed_tick()
        observer.advance_fixed_tick()
        if machine.get_phase() == ActionStateMachine.Phase.ACTIVE:
            var instance_id := machine.get_current_instance_id()
            if instance_id != last_hit_instance:
                last_hit_instance = instance_id
                var result := encounter.resolve_direct_contact(
                    player_id, enemy_id, instance_id, 0, runtime.make_basic_attack_payload(),
                    false, DirectHitResolver.DEFENSE_NONE, false)
                if not bool(result.get("accepted", false)):
                    hit_was_valid = false
                    break
                total_hits += 1
    var sample := observer.snapshot()
    observer.stop()
    encounter.end_encounter()
    runtime.free()
    machine.free()
    var label := "%s/%s" % [String(class_id), String(archetype_id)]
    _expect(hit_was_valid and enemy.current_hp == 0 and sample["enemy_defeats"] == 1
        and sample["player_deaths"] == 0, "%s: ordinary hit delivery defeats one role without fatal fixture" % label)
    _expect(sample["damage_dealt"] == enemy_hp and total_hits >= 1
        and sample["time_to_defeat_ticks"] > 0, "%s: normal damage and timed defeat recorded" % label)
    _expect(sample["damage_taken"] == 0 and sample["committed_resource_costs"]["mana"] == 0.0
        and sample["committed_resource_costs"]["stamina"] == 0.0,
        "%s: nonretaliating, resource-free basics represented honestly" % label)
    sample["archetype_id"] = String(archetype_id)
    sample["floor_id"] = FLOOR_ID
    sample["basic_hit_count"] = total_hits
    sample["enemy_hp_from_shipped_role_formula"] = enemy_hp
    sample["normal_basic_raw_damage"] = runtime_damage_for_class(class_id)
    sample["signature_damage_available"] = ATTACKS.attack_for(archetype_id) != null
    sample["model"] = "controlled_stationary_guaranteed_hit_nonretaliating"
    return sample


func runtime_damage_for_class(class_id: StringName) -> float:
    match class_id:
        &"melee":
            return STARTER.melee_basic_damage
        &"ranged":
            return STARTER.ranged_basic_damage
        &"mage":
            return STARTER.mage_basic_damage
    return -1.0


func _expect(condition: bool, message: String) -> bool:
    if not condition:
        _failures += 1
        push_error("FAIL: " + message)
    return condition
