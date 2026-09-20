extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
const TUNING: ActiveSkillsPlaytest = preload("res://src/data/tuning/active_skills_playtest_v01.tres")
const ATTACKS: PlayerPlaytestAttackContent = preload("res://src/data/tuning/player_attacks_playtest_v01.tres")
const SANCTUM: PackedScene = preload("res://src/world/tower/boss/tenth_warden_sanctum.tscn")
const WARDEN_AUTHORING: TenthWardenProductionAuthoring = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_playtest_v01.tres")


class ProbePassive:
    extends RefCounted
    var calls: Array[Dictionary] = []

    func modify_attack_payload(authored: Dictionary, origin: Vector2, target: Vector2, visible_weak_point: bool) -> Dictionary:
        calls.append({"origin": origin, "target": target, "visible": visible_weak_point,
            "weak_triggered": authored.get("weak_point_triggered", false)})
        var result := authored.duplicate(true)
        result["raw_damage"] = float(result["raw_damage"]) * 2.0
        return result

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _check_nine_authored_rank_paths()
    _check_invalid_adjustment_fails_closed()
    _check_cross_resource_delivery_authoring()
    for class_id: String in ["melee", "ranged", "mage"]:
        await _check_live_class_rank(class_id)
    await _check_live_aegis_rank()
    await _check_contact_passives_and_poise()
    if _failures == 0:
        print("ACTIVE SKILL RANK PLAYTEST TEST PASS")
    else:
        push_error("ACTIVE SKILL RANK PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _check_nine_authored_rank_paths() -> void:
    _expect(TUNING.validate_content().is_empty(), "shipped active rank records validate")
    _expect(ATTACKS.validate_content().is_empty(), "shipped nine active skill effects validate")
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        for skill_id: StringName in SkillCatalog.ACTIVE_IDS_BY_CLASS[class_id]:
            var definition := SkillCatalog.get_definition(skill_id)
            var profile := ProfileCreationService.create_profile(1, "Rank %s" % String(skill_id), String(class_id))
            profile.skill_points = 3
            var slot_index := 0
            if not definition.starting_grant:
                _expect(SkillProgressionService.purchase_rank(profile, skill_id, StringName("rank_test:%s:1" % String(skill_id))), "%s alternative learns rank 1" % skill_id)
                _expect(SkillProgressionService.equip_active(profile, 0, skill_id, true, false), "%s alternative equips" % skill_id)
            else:
                slot_index = (profile.skill_state["active_slots"] as Array).find(String(skill_id))
            var base_action := TUNING.action_for_rank(skill_id, 1)
            var base_effect := ATTACKS.skill_for(skill_id)
            _expect(base_action != null and not base_effect.is_empty(), "%s has base action and effect" % skill_id)
            if base_action == null or base_effect.is_empty():
                continue
            var previous_cost := base_action.cost_amount
            var previous_recovery := base_action.recovery_ticks
            var previous_magnitude := float(base_effect["ward_ticks"] if skill_id == &"aegis_ward" else base_effect["raw_damage"])
            for rank: int in [2, 3]:
                _expect(SkillProgressionService.purchase_rank(profile, skill_id, StringName("rank_test:%s:%d" % [String(skill_id), rank])), "%s rank %d spends a point" % [skill_id, rank])
                var action := TUNING.action_for_rank(skill_id, rank)
                var effect := TUNING.effect_for_rank(skill_id, rank, base_effect)
                _expect(action != null and not effect.is_empty(), "%s rank %d resolves ranked content" % [skill_id, rank])
                if action == null or effect.is_empty():
                    continue
                _expect(action.action_id == base_action.action_id and action.cooldown_ticks == base_action.cooldown_ticks and action.startup_ticks == base_action.startup_ticks and action.active_ticks == base_action.active_ticks,
                    "%s rank %d preserves identity and committed clock" % [skill_id, rank])
                _expect(action.cost_amount < previous_cost and action.recovery_ticks < previous_recovery,
                    "%s rank %d reduces authored cost and recovery" % [skill_id, rank])
                var magnitude := float(effect["ward_ticks"] if skill_id == &"aegis_ward" else effect["raw_damage"])
                _expect(magnitude > previous_magnitude, "%s rank %d increases effect magnitude" % [skill_id, rank])
                var geometry_unchanged := true
                for key: String in ["mode", "range_px", "half_angle_degrees", "max_targets", "projectile_count", "movement_distance_px", "evade_window_ticks", "sequence_interval_ticks"]:
                    geometry_unchanged = geometry_unchanged and effect.get(key, null) == base_effect.get(key, null)
                _expect(geometry_unchanged, "%s rank %d preserves authored geometry and delivery identity" % [skill_id, rank])
                var resolved := SkillExecutionService.resolve_equipped_action(profile, slot_index, TUNING.action_definitions_by_mechanic(),
                    {&"successful_parry": true}, TUNING)
                _expect(bool(resolved.get("accepted", false)) and int(resolved.get("rank", 0)) == rank
                    and is_equal_approx((resolved.get("action_definition") as ActionDefinition).cost_amount, action.cost_amount),
                    "%s rank %d resolves through equipped progression state" % [skill_id, rank])
                previous_cost = action.cost_amount
                previous_recovery = action.recovery_ticks
                previous_magnitude = magnitude
            _expect(is_equal_approx(TUNING.action_for_rank(skill_id, 1).cost_amount, base_action.cost_amount)
                and ATTACKS.skill_for(skill_id) == base_effect, "%s ranking does not mutate shared base content" % skill_id)


func _check_invalid_adjustment_fails_closed() -> void:
    var invalid := TUNING.duplicate(true) as ActiveSkillsPlaytest
    var changed := invalid.rank_adjustments.duplicate(true)
    changed["arc_cleave"]["rank_2"]["cost_multiplier"] = -1.0
    invalid.rank_adjustments = changed
    _expect(not invalid.validate_content().is_empty() and invalid.action_for_rank(&"arc_cleave", 2) == null,
        "invalid or missing rank content cannot silently execute")
    for field: String in ["magnitude_multiplier", "cost_multiplier", "recovery_ticks_delta"]:
        invalid = TUNING.duplicate(true) as ActiveSkillsPlaytest
        changed = invalid.rank_adjustments.duplicate(true)
        changed["arc_cleave"]["rank_3"][field] = changed["arc_cleave"]["rank_2"][field]
        invalid.rank_adjustments = changed
        # One equal field is allowed when other rank-three fields still improve.
        _expect(invalid.validate_content().is_empty(), "rank 3 may hold %s when other authored fields improve" % field)
    invalid = TUNING.duplicate(true) as ActiveSkillsPlaytest
    changed = invalid.rank_adjustments.duplicate(true)
    changed["arc_cleave"]["rank_3"]["magnitude_multiplier"] = 1.0
    invalid.rank_adjustments = changed
    _expect(not invalid.validate_content().is_empty(), "rank 3 cannot regress magnitude below rank 2")
    invalid = TUNING.duplicate(true) as ActiveSkillsPlaytest
    changed = invalid.rank_adjustments.duplicate(true)
    changed["arc_cleave"]["rank_3"]["cost_multiplier"] = 1.0
    invalid.rank_adjustments = changed
    _expect(not invalid.validate_content().is_empty(), "rank 3 cannot regress resource cost")
    invalid = TUNING.duplicate(true) as ActiveSkillsPlaytest
    changed = invalid.rank_adjustments.duplicate(true)
    changed["arc_cleave"]["rank_3"]["recovery_ticks_delta"] = -20
    invalid.rank_adjustments = changed
    _expect(not invalid.validate_content().is_empty(), "rank 3 cannot erase an authored recovery window")
    invalid = TUNING.duplicate(true) as ActiveSkillsPlaytest
    changed = invalid.rank_adjustments.duplicate(true)
    changed["arc_cleave"]["rank_3"] = changed["arc_cleave"]["rank_2"].duplicate(true)
    invalid.rank_adjustments = changed
    _expect(not invalid.validate_content().is_empty(), "rank 3 must improve at least one dimension beyond rank 2")


func _check_cross_resource_delivery_authoring() -> void:
    _expect(TUNING.validate_delivery_content(ATTACKS).is_empty(), "shipped action clocks admit every authored projectile and evade window")
    var invalid := TUNING.duplicate(true) as ActiveSkillsPlaytest
    var actions: Array[ActionDefinition] = invalid.actions.duplicate(true)
    actions[4] = actions[4].duplicate(true) as ActionDefinition
    actions[4].active_ticks = 4
    invalid.actions = actions
    _expect(not invalid.validate_delivery_content(ATTACKS).is_empty(), "Fan Shot refuses an ACTIVE window that clips its last sequential projectile")
    invalid = TUNING.duplicate(true) as ActiveSkillsPlaytest
    actions = invalid.actions.duplicate(true)
    actions[5] = actions[5].duplicate(true) as ActionDefinition
    actions[5].active_ticks = 3
    invalid.actions = actions
    _expect(not invalid.validate_delivery_content(ATTACKS).is_empty(), "Backstep refuses an evade duration longer than its ACTIVE phase")
    invalid = TUNING.duplicate(true) as ActiveSkillsPlaytest
    actions = invalid.actions.duplicate(true)
    actions[6] = actions[6].duplicate(true) as ActionDefinition
    actions[6].uses_aim = false
    invalid.actions = actions
    _expect(not invalid.validate_delivery_content(ATTACKS).is_empty(), "Arcane Lance refuses an un-aimed committed projectile action")
    var malformed := ATTACKS.duplicate(true) as PlayerPlaytestAttackContent
    malformed.basic_by_class = ATTACKS.basic_by_class.duplicate(true)
    malformed.basic_by_class["mage"]["domain"] = &"physical"
    _expect(not malformed.validate_content().is_empty(), "resource-free Mage basic must retain Arcane domain")
    malformed = ATTACKS.duplicate(true) as PlayerPlaytestAttackContent
    malformed.basic_by_class = ATTACKS.basic_by_class.duplicate(true)
    malformed.basic_by_class["ranged"]["projectile_count"] = 3
    _expect(not malformed.validate_content().is_empty(), "resource-free bow basic cannot become a multi-projectile skill")
    malformed = ATTACKS.duplicate(true) as PlayerPlaytestAttackContent
    malformed.active_skill_effects = ATTACKS.active_skill_effects.duplicate(true)
    malformed.active_skill_effects["arcane_lance"]["domain"] = &"physical"
    _expect(not malformed.validate_content().is_empty(), "Arcane Lance cannot switch damage domain through PLAYTEST geometry")
    _expect(TUNING.effect_for_rank(&"unknown_skill", 2, ATTACKS.skill_for(&"arc_cleave")).is_empty(),
        "unknown skill rank requests fail closed without accessing absent adjustments")
    invalid = TUNING.duplicate(true) as ActiveSkillsPlaytest
    var adjustments := invalid.rank_adjustments.duplicate(true)
    adjustments["aegis_ward"]["rank_3"]["magnitude_multiplier"] = 10.0
    invalid.rank_adjustments = adjustments
    _expect(invalid.validate_content().is_empty() and not invalid.validate_delivery_content(ATTACKS).is_empty(),
        "ranked ward duration cannot exceed the existing 600-tick authoring bound")


func _check_live_class_rank(class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Live ranked " + class_id, class_id)
    profile.skill_points = 2
    var skill_id := StringName(String((profile.skill_state["active_slots"] as Array)[0]))
    for rank: int in [2, 3]:
        _expect(SkillProgressionService.purchase_rank(profile, skill_id, StringName("rank_live:%s:%d" % [class_id, rank])), "%s live rank %d learned" % [class_id, rank])
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    # Isolate the one commit from unrelated automatic stamina/mana regeneration.
    game.player.stamina.set_physics_process(false)
    game.combat_runtime.set_physics_process(false)
    var delivery := game.player_playtest_attack_delivery
    var action := TUNING.action_for_rank(skill_id, 3)
    var final_action := game.combat_runtime.get_passive_skill_runtime().modify_action(action)
    var effect := TUNING.effect_for_rank(skill_id, 3, ATTACKS.skill_for(skill_id))
    var before := game.combat_runtime.get_mana() if class_id == "mage" else game.player.stamina.current_stamina
    _expect(is_equal_approx(float(delivery.effect_for_action(action.action_id)["raw_damage"]), float(effect["raw_damage"])),
        "%s live delivery reads rank-3 damage" % class_id)
    var started := game.request_active_skill_slot(0)
    _expect(bool(started.get("accepted", false)) and int(started.get("rank", 0)) == 3,
        "%s live Q requests rank-3 action" % class_id)
    var machine := game.combat_runtime.action_state_machine
    for _tick: int in action.startup_ticks:
        machine.advance_fixed_tick()
    var after := game.combat_runtime.get_mana() if class_id == "mage" else game.player.stamina.current_stamina
    _expect(is_equal_approx(before - after, final_action.cost_amount), "%s rank-3 cost commits once after equipped passive (actual %.3f, combined %.3f)" % [class_id, before - after, final_action.cost_amount])
    for _tick: int in action.commit_ticks + action.active_ticks:
        machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.RECOVERY and machine.get_phase_duration_ticks() == final_action.recovery_ticks,
        "%s rank-3 and passive recovery execute in action machine" % class_id)
    game.queue_free()
    await process_frame


func _check_live_aegis_rank() -> void:
    var profile := ProfileCreationService.create_profile(1, "Ranked ward", "mage")
    profile.skill_points = 3
    for rank: int in [1, 2, 3]:
        _expect(SkillProgressionService.purchase_rank(profile, &"aegis_ward", StringName("rank_ward:%d" % rank)), "ward rank %d learned" % rank)
    _expect(SkillProgressionService.equip_active(profile, 0, &"aegis_ward", true, false), "ward rank 3 equipped")
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    var duration := int(TUNING.effect_for_rank(&"aegis_ward", 3, ATTACKS.skill_for(&"aegis_ward"))["ward_ticks"])
    var action := TUNING.action_for_rank(&"aegis_ward", 3)
    _expect(bool(game.request_active_skill_slot(0).get("accepted", false)), "ranked ward starts")
    for _tick: int in action.startup_ticks + action.commit_ticks:
        game.combat_runtime.action_state_machine.advance_fixed_tick()
    _expect(game.combat_runtime.get_playtest_ward_ticks_remaining() == duration,
        "rank-3 ward magnitude is live authored duration")
    game.queue_free()
    await process_frame


func _check_contact_passives_and_poise() -> void:
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(ProfileCreationService.create_profile(1, "Passive contact", "melee"))
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false)
    var delivery := game.player_playtest_attack_delivery
    var probe := ProbePassive.new()
    delivery.set_passive_skill_runtime(probe)
    var encounter := CombatEncounterRuntime.new()
    var player_state := CombatantRuntimeState.new()
    var enemy_state := CombatantRuntimeState.new()
    _expect(player_state.configure(&"player:local", 100, 100.0, 0.0, 0.0, 100.0, true, false, false)
        and enemy_state.configure(&"enemy:rank_poise", 100, 100.0, 0.0, 0.0, 100.0, true, false, false),
        "passive target fixture configures real player and enemy")
    _expect(encounter.configure(&"encounter:rank_poise") and encounter.register_player(player_state)
        and encounter.register_enemy(enemy_state), "passive target fixture registers canonical encounter")
    var normal_target := {"encounter_id": encounter.encounter_id, "actor_id": enemy_state.actor_id,
        "position": Vector2(300.0, 200.0), "encounter": encounter, "boss": false}
    var skill_effect := ATTACKS.skill_for(&"arc_cleave")
    var payload := PlayerPlaytestAttackContent.make_payload(skill_effect)
    var initial_poise := float(payload["poise_damage"])
    _expect(initial_poise > 0.0 and is_equal_approx(float(TUNING.effect_for_rank(&"arc_cleave", 3, skill_effect)["poise_damage"]),
        initial_poise * float(TUNING.adjustment_for_rank(&"arc_cleave", 3)["magnitude_multiplier"])),
        "melee active skill has Inspector-authored poise which scales with active rank")
    var origin := Vector2(40.0, 50.0)
    game.player.global_position = Vector2(280.0, 200.0)
    var hit := delivery._resolve_target(normal_target, 70001, 0, payload, origin)
    _expect(bool(hit.get("accepted", false)) and enemy_state.current_hp == 76,
        "per-target passive modification doubles actual resolved normal enemy raw damage")
    _expect(is_equal_approx(enemy_state.accumulated_poise, initial_poise),
        "valid normal enemy contact applies authored poise once")
    _expect(probe.calls.size() == 1 and probe.calls[0]["origin"] == origin and not bool(probe.calls[0]["visible"]),
        "normal target receives launch origin and no visible weak-point fact")
    var duplicate := delivery._resolve_target(normal_target, 70001, 0, payload, origin)
    _expect(not bool(duplicate.get("accepted", false)) and is_equal_approx(enemy_state.accumulated_poise, initial_poise),
        "duplicate contact cannot apply duplicate poise")
    _expect(is_equal_approx(float(payload["raw_damage"]), float(skill_effect["raw_damage"])),
        "passive contact does not mutate the shared authored payload")

    var real_passives := game.combat_runtime.get_passive_skill_runtime()
    delivery.set_passive_skill_runtime(real_passives)
    var breaker := real_passives.preview_for_skill(&"breaker", real_passives.rank_for(&"breaker"))
    _expect(bool(breaker.get("accepted", false)), "live Melee profile has learned equipped Breaker")
    var breaker_multiplier := float((breaker.get("values", {}) as Dictionary).get("poise_multiplier", 1.0))
    var second_poise := delivery._resolve_target(normal_target, 70006, 0, payload, origin)
    _expect(bool(second_poise.get("accepted", false)) and is_equal_approx(
        enemy_state.accumulated_poise, initial_poise * (1.0 + breaker_multiplier)),
        "equipped Breaker changes actual canonical enemy poise accumulation")
    var starter_payload := game.combat_runtime.make_basic_attack_payload()
    starter_payload["poise_damage"] = game.combat_runtime.starter_kit.basic_poise_damage
    _expect(float(starter_payload["poise_damage"]) > 0.0
        and is_equal_approx(float(ATTACKS.basic_for(&"melee")["poise_damage"]), float(starter_payload["poise_damage"])),
        "basic Melee poise comes from authored starter tuning and agrees with PLAYTEST geometry resource")
    var basic_hit := delivery._resolve_target(normal_target, 70007, 0, starter_payload, origin)
    _expect(bool(basic_hit.get("accepted", false)) and is_equal_approx(enemy_state.accumulated_poise,
        initial_poise * (1.0 + breaker_multiplier) + float(starter_payload["poise_damage"]) * breaker_multiplier),
        "equipped Breaker also changes live basic-attack poise without mutating starter tuning")
    delivery.set_passive_skill_runtime(probe)

    game.player.global_position = origin
    var projectile_effect := ATTACKS.skill_for(&"piercing_shot")
    delivery._spawn_projectile(projectile_effect, PlayerPlaytestAttackContent.make_payload(projectile_effect),
        Vector2.RIGHT, 70002, 0)
    var projectile_records := delivery.get("_projectiles") as Array
    _expect(projectile_records.size() > 0 and projectile_records[-1]["launch_origin"] == origin,
        "projectile snapshots its caster position when fired")
    game.player.global_position = Vector2(200.0, 200.0)
    _expect(projectile_records[-1]["launch_origin"] == origin,
        "projectile launch origin survives subsequent player movement")

    var sanctum := SANCTUM.instantiate() as TenthWardenSanctum
    game.add_child(sanctum)
    await process_frame
    sanctum.set_physics_process(false)
    var boss_player := CombatantRuntimeState.new()
    _expect(boss_player.configure(&"player:local", 100, 100.0, 0.0, 0.0, 100.0, true, true, true),
        "boss fixture player combatant configures")
    _expect(sanctum.prepare_production_encounter(boss_player, WARDEN_AUTHORING, game.shared_active_combat,
        game.shared_full_ai, game.tower_encounter_session_host.shared_attack_pressure),
        "passive contact fixture configures real authored Warden")
    var boss_target := {"encounter_id": sanctum.encounter_id, "actor_id": sanctum.boss_runtime.boss_id,
        "position": sanctum.boss_visual.global_position, "encounter": sanctum.encounter_runtime,
        "boss": true, "sanctum": sanctum}
    var boss_hit := delivery._resolve_target(boss_target, 70003, 0, payload, origin)
    _expect(bool(boss_hit.get("accepted", false)) and probe.calls.size() >= 2 and not bool(probe.calls[-1]["visible"]),
        "ordinary boss body contact passes through passive hook without Expose")
    var weak_target := boss_target.duplicate(true)
    weak_target["weak_point"] = true
    var blocked := delivery._resolve_target(weak_target, 70004, 0, payload, origin)
    _expect(not bool(blocked.get("accepted", false)) and probe.calls.size() == 3,
        "closed boss weak point is rejected before passive modifier")
    sanctum.boss_runtime.state.phase = TenthWardenEncounterState.PHASE_TWO
    _expect(sanctum.boss_runtime.state.begin_committed_move(TenthWardenEncounterState.MOVE_TWIN_CUT),
        "boss committed move authorizes recovery")
    _expect(sanctum.boss_runtime.state.begin_recovery(true), "boss heavy recovery opens authored weak point")
    weak_target["position"] = sanctum.get_exposed_weak_point_position()
    var exposed := delivery._resolve_target(weak_target, 70005, 0, payload, origin)
    _expect(bool(exposed.get("accepted", false)) and bool(probe.calls[-1]["visible"])
        and bool(probe.calls[-1]["weak_triggered"]),
        "confirmed exposed boss weak point reaches passive hook after authoritative injection")
    sanctum.end_encounter()
    game.queue_free()
    await process_frame


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
