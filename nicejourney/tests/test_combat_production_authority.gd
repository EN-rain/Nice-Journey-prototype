extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_active_skill_authority_alignment()
    _test_known_skill_semantics()
    _test_status_authority()
    _test_strict_execution_rejects_placeholder_authoring()

    if _failures == 0:
        print("COMBAT PRODUCTION AUTHORITY TEST PASS")
    else:
        push_error("COMBAT PRODUCTION AUTHORITY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_active_skill_authority_alignment() -> void:
    _expect(ActiveSkillProductionAuthority.validate_catalog_alignment().is_empty(), "all nine active production authority records align with the approved SkillCatalog identities")
    var active_count := 0
    for definition: SkillDefinition in SkillCatalog.all_definitions():
        if definition.kind != SkillDefinition.KIND_ACTIVE:
            continue
        active_count += 1
        var readiness := ActiveSkillProductionAuthority.readiness(definition.skill_id)
        _expect(bool(readiness.get("accepted", false)), "%s has a valid production authority record" % definition.display_name)
        _expect(not bool(readiness.get("production_ready", true)), "%s is not falsely production-ready while required tuning/effect fields are unauthored" % definition.display_name)
        var missing := readiness.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray
        _expect(missing.has("startup_ticks") and missing.has("cooldown_ticks") and missing.has("resource_cost_amount"), "%s reports the unresolved common action tuning fields" % definition.display_name)
        _expect(StringName(readiness.get("mechanic_id", &"")) == definition.mechanic_id and StringName(readiness.get("resource_id", &"")) == definition.cost_resource, "%s authority preserves the approved mechanic/resource identities" % definition.display_name)
    _expect(active_count == 9, "production authority covers exactly the nine approved active skills")
    var catalog_status := ActiveSkillProductionAuthority.catalog_readiness()
    _expect(bool(catalog_status.get("accepted", false)) and int(catalog_status.get("approved_active_count", 0)) == 9, "production catalog readiness audits exactly the nine approved active skills")
    _expect(not bool(catalog_status.get("production_ready", true)) and int(catalog_status.get("production_ready_count", -1)) == 0, "no active skill is falsely promoted while production combat values remain unauthored")
    _expect((catalog_status.get("missing_by_skill", {}) as Dictionary).size() == 9, "catalog readiness exposes an explicit missing-field set for every approved active skill")
    _expect(not bool(ActiveSkillProductionAuthority.readiness(&"breaker").get("accepted", true)), "passive skills cannot be promoted to active production actions")


func _test_known_skill_semantics() -> void:
    var riposte := ActiveSkillProductionAuthority.readiness(&"riposte")
    _expect(StringName(riposte.get("prerequisite_event_id", &"")) == &"successful_parry", "Riposte preserves its successful-supported-parry prerequisite")
    var progression := ((riposte.get("known_semantics", {}) as Dictionary).get("rank_progression", {}) as Dictionary)
    _expect(int(progression.get("maximum_rank", 0)) == 3 and int(progression.get("skill_point_cost_per_rank", 0)) == 1, "active production authority preserves the approved three-rank/one-point progression contract")
    _expect((progression.get("rank_two_three_change_scope", []) as Array) == ["magnitude", "cost", "recovery"], "rank 2-3 authority is restricted to authored magnitude/cost/recovery changes")
    _expect(bool((riposte.get("known_semantics", {}) as Dictionary).get("requires_successful_supported_parry", false)), "Riposte authority records only the approved counter semantic")

    for skill_id: StringName in [&"piercing_shot", &"fan_shot", &"backstep_shot", &"arcane_lance"]:
        var semantics := (ActiveSkillProductionAuthority.readiness(skill_id).get("known_semantics", {}) as Dictionary)
        _expect(StringName(semantics.get("delivery_family", &"")) == &"projectile" and not bool(semantics.get("parryable", true)), "%s preserves the DR-06 no-projectile-parry rule" % String(skill_id))

    var lance_semantics := (ActiveSkillProductionAuthority.readiness(&"arcane_lance").get("known_semantics", {}) as Dictionary)
    _expect(StringName(lance_semantics.get("damage_domain", &"")) == &"arcane", "Arcane Lance preserves its explicitly authored Arcane damage domain")

    var ward_semantics := (ActiveSkillProductionAuthority.readiness(&"aegis_ward").get("known_semantics", {}) as Dictionary)
    _expect(bool(ward_semantics.get("uses_dr06_block_style_semantics", false)) and not bool(ward_semantics.get("parryable_defense", true)), "Aegis Ward preserves block-style defense without parry")


func _test_status_authority() -> void:
    var burn := PrototypeStatusProductionAuthority.readiness(PrototypeStatusResolver.BEHAVIOR_BURN)
    _expect(bool(burn.get("accepted", false)) and not bool(burn.get("production_ready", true)), "Burn authority is recognized but remains non-production without authored cadence/damage")
    var burn_semantics := burn.get("known_semantics", {}) as Dictionary
    _expect(bool(burn_semantics.get("damage_over_time", false)) and not bool(burn_semantics.get("can_crit", true)) and not bool(burn_semantics.get("can_weak_point", true)), "Burn preserves DoT and the DR-06 no-crit/no-weak-point rule")
    _expect(StringName(burn_semantics.get("reapplication_magnitude_policy", &"")) == &"strongest" and StringName(burn_semantics.get("reapplication_duration_policy", &"")) == &"greatest_remaining_or_new_duration", "Burn preserves strongest-magnitude/max-duration reapplication")
    var burn_missing := burn.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray
    _expect(burn_missing.has("tick_interval_ticks") and burn_missing.has("damage_per_tick") and burn_missing.has("damage_domain") and burn_missing.has("mitigation_or_defense_interaction"), "Burn reports the exact unresolved execution semantics rather than interpreting generic magnitude")

    var slow := PrototypeStatusProductionAuthority.readiness(PrototypeStatusResolver.BEHAVIOR_SLOW)
    _expect(bool(slow.get("accepted", false)) and not bool(slow.get("production_ready", true)), "Slow authority is recognized but remains non-production without authored magnitude/application rules")
    var slow_semantics := slow.get("known_semantics", {}) as Dictionary
    _expect(bool(slow_semantics.get("movement_speed_reduction_only", false)) and not bool(slow_semantics.get("affects_action_clocks", true)) and not bool(slow_semantics.get("affects_ai_reaction_timing", true)), "Slow preserves movement-only behavior without action/AI clock changes")
    var slow_missing := slow.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray
    _expect(slow_missing.has("magnitude_semantics_percent_or_multiplier") and slow_missing.has("affected_movement_domains") and slow_missing.has("minimum_or_maximum_speed_clamp_policy"), "Slow reports unresolved magnitude/domain/clamp semantics")
    _expect(burn_missing.has("encounter_handoff_policy") and slow_missing.has("encounter_handoff_policy"), "status production remains fail-closed because encounter handoff is not specified by the master")

    var strict_burn := PrototypeStatusResolver.validate_production_application({
        "status_id": &"burn:authority_gate",
        "behavior": PrototypeStatusResolver.BEHAVIOR_BURN,
        "magnitude": 3.0,
        "duration_ticks": 60,
    })
    _expect(not bool(strict_burn.get("accepted", true)) and StringName(strict_burn.get("reason_id", &"")) == PrototypeStatusResolver.REASON_PRODUCTION_AUTHORITY_INCOMPLETE, "strict Burn application refuses opaque fixture magnitude while cadence/damage authority is missing")
    _expect((strict_burn.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).has("first_tick_timing"), "strict Burn rejection exposes exact missing first-tick authority")

    _expect(not bool(PrototypeStatusProductionAuthority.readiness(&"poison").get("accepted", true)), "unapproved status behavior has no production authority")


func _test_strict_execution_rejects_placeholder_authoring() -> void:
    var profile := ProfileCreationService.create_profile(1, "Authority Gate", "mage")
    var action := _structurally_authored_action(
        &"fixture_action:arcane_lance_authority_gate",
        &"focused_arcane_projectile",
        &"mana"
    )
    var result := SkillExecutionService.resolve_equipped_production_action(
        profile,
        0,
        {&"focused_arcane_projectile": action}
    )
    _expect(not bool(result.get("accepted", true)) and StringName(result.get("reason_id", &"")) == SkillExecutionService.REASON_PRODUCTION_AUTHORITY_INCOMPLETE, "strict production execution rejects structurally complete placeholders when authoritative combat values are absent")
    var missing := result.get("production_missing_fields", PackedStringArray()) as PackedStringArray
    _expect(missing.has("raw_damage") and missing.has("projectile_speed") and missing.has("cooldown_ticks"), "strict rejection exposes unresolved Arcane Lance damage/projectile/timing fields")


func _structurally_authored_action(action_id: StringName, mechanic_id: StringName, resource_id: StringName) -> ActionDefinition:
    var action := ActionDefinition.new()
    action.action_id = action_id
    action.startup_ticks = 1
    action.commit_ticks = 1
    action.active_ticks = 1
    action.recovery_ticks = 1
    action.cooldown_ticks = 1
    action.cost_resource = resource_id
    action.cost_amount = 1.0
    action.uses_aim = true
    action.production_mechanic_id = mechanic_id
    action.eligible_states_profile_id = StringName("states:%s" % String(mechanic_id))
    action.movement_aim_profile_id = StringName("movement:%s" % String(mechanic_id))
    action.effect_profile_id = StringName("effect:%s" % String(mechanic_id))
    action.forced_interruption_profile_id = StringName("interrupt:%s" % String(mechanic_id))
    action.cue_profile_id = StringName("cue:%s" % String(mechanic_id))
    return action


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
