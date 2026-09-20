extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_all_nine_authority_records()
    _test_resource_rejection_and_cooldown_commit()
    _test_riposte_prerequisite()
    _test_duplicate_contact_protection()

    if _failures == 0:
        print("ACTIVE SKILL PRODUCTION CONTRACT TEST PASS")
    else:
        push_error("ACTIVE SKILL PRODUCTION CONTRACT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_all_nine_authority_records() -> void:
    var status := ActiveSkillProductionAuthority.catalog_readiness()
    _expect(bool(status.get("accepted", false)), "active-skill production catalog aligns with the approved SkillCatalog")
    _expect(int(status.get("approved_active_count", 0)) == 9, "production catalog contains exactly nine approved active identities")
    _expect(int(status.get("production_ready_count", -1)) == 0, "no active action is falsely production-ready without authoritative tuning/effect data")

    for skill_id: StringName in [
        &"arc_cleave",
        &"driving_thrust",
        &"riposte",
        &"piercing_shot",
        &"fan_shot",
        &"backstep_shot",
        &"arcane_lance",
        &"delayed_pulse",
        &"aegis_ward",
    ]:
        var authority := ActiveSkillProductionAuthority.readiness(skill_id)
        _expect(bool(authority.get("accepted", false)), "%s has an aligned authority record" % String(skill_id))
        _expect(not bool(authority.get("production_ready", true)), "%s remains fail-closed until exact production values are authored" % String(skill_id))
        var missing := authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray
        _expect(
            missing.has("startup_ticks")
            and missing.has("resource_cost_amount")
            and missing.has("cue_event_identities_and_feedback_alignment"),
            "%s reports unresolved timing/resource/cue authoring" % String(skill_id)
        )

    for projectile_skill: StringName in [&"piercing_shot", &"fan_shot", &"backstep_shot", &"arcane_lance"]:
        var authority := ActiveSkillProductionAuthority.readiness(projectile_skill)
        var semantics := authority.get("known_semantics", {}) as Dictionary
        var missing := authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray
        _expect(
            StringName(semantics.get("delivery_family", &"")) == &"projectile"
            and not bool(semantics.get("parryable", true)),
            "%s preserves the DR-06 no-projectile-parry rule" % String(projectile_skill)
        )
        _expect(
            missing.has("projectile_speed")
            and missing.has("projectile_range_or_lifetime")
            and missing.has("projectile_count")
            and missing.has("projectile_hit_policy")
            and missing.has("projectile_cleanup_policy")
            and missing.has("projectile_concurrency_cap_or_budget"),
            "%s cannot instantiate projectile ownership before speed/range/count/hit/cleanup/cap data exists" % String(projectile_skill)
        )


func _test_resource_rejection_and_cooldown_commit() -> void:
    var machine := ActionStateMachine.new()
    root.add_child(machine)
    machine.set_physics_process(false)
    var resources := ResourcePool.new()
    _expect(resources.define_resource(&"mana", 10.0, 2.0), "resource fixture defines exact live mana")
    machine.set_resource_pool(resources)

    var action := _production_shape_action(
        &"skill_action:test_arcane_lance",
        &"focused_arcane_projectile",
        &"mana",
        5.0
    )
    _expect(not machine.request_action(action, Vector2.RIGHT), "resource-insufficient active action is rejected before startup")
    _expect(not machine.is_busy() and is_equal_approx(resources.get_value(&"mana"), 2.0), "resource rejection is non-mutating")

    _expect(resources.set_value(&"mana", 10.0), "fixture restores enough mana")
    _expect(machine.request_action(action, Vector2.RIGHT), "resource-satisfied fixture action enters startup")
    _expect(machine.get_cooldown_ticks(action.action_id) == 0, "cooldown is not started at startup")
    machine.advance_fixed_tick()
    _expect(machine.get_cooldown_ticks(action.action_id) == 0, "cooldown remains absent before the commit boundary")
    machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.COMMIT, "second startup tick reaches commit")
    _expect(machine.get_cooldown_ticks(action.action_id) == action.cooldown_ticks, "cooldown starts exactly at commit")
    _expect(is_equal_approx(resources.get_value(&"mana"), 5.0), "resource cost is spent once at commit")
    machine.queue_free()


func _test_riposte_prerequisite() -> void:
    var profile := ProfileCreationService.create_profile(1, "Production Riposte", "melee")
    _expect(profile != null, "Riposte fixture creates a melee profile")
    if profile == null:
        return
    profile.skill_points = 1
    _expect(SkillProgressionService.purchase_rank(profile, &"riposte", &"skill_production:riposte_rank"), "Riposte fixture learns the alternative active")
    _expect(SkillProgressionService.equip_active(profile, 0, &"riposte", true, false), "Riposte fixture equips only at an allowed safe interaction")

    var action := _production_shape_action(
        &"skill_action:test_riposte",
        &"supported_parry_counter",
        &"stamina",
        5.0
    )
    var actions := {&"supported_parry_counter": action}

    var no_owner := SkillExecutionService.resolve_equipped_production_action(profile, 0, actions)
    _expect(
        not bool(no_owner.get("accepted", true))
        and StringName(no_owner.get("reason_id", &"")) == SkillExecutionService.REASON_PREREQUISITE_STATE_REQUIRED,
        "Riposte production resolution requires an explicit successful-parry state owner"
    )

    var unmet := SkillExecutionService.resolve_equipped_production_action(
        profile,
        0,
        actions,
        {&"successful_parry": false}
    )
    _expect(
        not bool(unmet.get("accepted", true))
        and StringName(unmet.get("reason_id", &"")) == SkillExecutionService.REASON_PREREQUISITE_UNSATISFIED,
        "Riposte production resolution rejects a false successful-parry prerequisite"
    )

    var met := SkillExecutionService.resolve_equipped_production_action(
        profile,
        0,
        actions,
        {&"successful_parry": true}
    )
    _expect(
        not bool(met.get("accepted", true))
        and StringName(met.get("reason_id", &"")) == SkillExecutionService.REASON_PRODUCTION_AUTHORITY_INCOMPLETE,
        "successful parry clears the prerequisite gate but cannot bypass missing production combat values"
    )


func _test_duplicate_contact_protection() -> void:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:active_skill_contact"), "contact fixture configures")
    var player := _combatant(&"player:active_skill_contact", 100)
    var enemy := _combatant(&"enemy:active_skill_contact", 100)
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "contact fixture registers both combatants")

    var payload := {
        "domain": DirectHitResolver.DOMAIN_ARCANE,
        "delivery": DirectHitResolver.DELIVERY_PROJECTILE,
        "raw_damage": 9.0,
        "dodgeable": true,
        "blockable": true,
        "parryable": false,
        "guard_pressure": 1.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }
    var first := encounter.resolve_direct_contact(
        player.actor_id,
        enemy.actor_id,
        9101,
        0,
        payload,
        false,
        DirectHitResolver.DEFENSE_NONE,
        false
    )
    _expect(bool(first.get("accepted", false)) and enemy.current_hp == 91, "first skill contact mutates HP once")
    var duplicate := encounter.resolve_direct_contact(
        player.actor_id,
        enemy.actor_id,
        9101,
        0,
        payload,
        false,
        DirectHitResolver.DEFENSE_NONE,
        false
    )
    _expect(
        not bool(duplicate.get("accepted", true))
        and StringName(duplicate.get("reason_id", &"")) == &"duplicate_contact"
        and enemy.current_hp == 91,
        "same action-instance/target/hit interval cannot apply a duplicate skill contact"
    )
    encounter.end_encounter()


func _production_shape_action(
    action_id: StringName,
    mechanic_id: StringName,
    resource_id: StringName,
    cost_amount: float
) -> ActionDefinition:
    var action := ActionDefinition.new()
    action.action_id = action_id
    action.startup_ticks = 2
    action.commit_ticks = 1
    action.active_ticks = 1
    action.recovery_ticks = 2
    action.cooldown_ticks = 6
    action.buffer_lifetime_ticks = 8
    action.cost_resource = resource_id
    action.cost_amount = cost_amount
    action.uses_aim = true
    action.aim_lock_point = ActionDefinition.AimLockPoint.COMMIT
    action.production_mechanic_id = mechanic_id
    action.eligible_states_profile_id = StringName("states:%s" % String(mechanic_id))
    action.movement_aim_profile_id = StringName("movement:%s" % String(mechanic_id))
    action.effect_profile_id = StringName("effect:%s" % String(mechanic_id))
    action.forced_interruption_profile_id = StringName("interrupt:%s" % String(mechanic_id))
    action.cue_profile_id = StringName("cue:%s" % String(mechanic_id))
    return action


func _combatant(actor_id: StringName, hp: int) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(
        state.configure(actor_id, hp, 100.0, 0.0, 0.0, 50.0, true, false, false),
        "%s combatant fixture validates" % String(actor_id)
    )
    return state


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
