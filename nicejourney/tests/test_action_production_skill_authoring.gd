extends SceneTree

var _failures: int = 0
var _requested_action_id: StringName = &""


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_generic_action_remains_content_neutral()
    _test_production_skill_authoring_fails_closed()
    _test_all_approved_active_skill_mechanics_fit_boundary()
    _test_strict_skill_execution_path()

    if _failures == 0:
        print("ACTION PRODUCTION SKILL AUTHORING TEST PASS")
    else:
        push_error("ACTION PRODUCTION SKILL AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_generic_action_remains_content_neutral() -> void:
    var action := _base_action(&"fixture_action:generic", &"mana")
    _expect(action.validate_definition().is_empty(), "generic ActionDefinition remains valid without invented production effect data")
    var production_errors := action.validate_production_skill_authoring(&"focused_arcane_projectile")
    _expect(not production_errors.is_empty(), "generic timing/cost data alone is not production-skill authoring")
    _expect(_contains(production_errors, "production_mechanic_id"), "production skill boundary requires explicit mechanic identity")
    _expect(_contains(production_errors, "eligible_states_profile_id"), "production skill boundary requires caller-owned eligible-state authoring")
    _expect(_contains(production_errors, "movement_aim_profile_id"), "production skill boundary requires caller-owned movement/aim authoring")
    _expect(_contains(production_errors, "effect_profile_id"), "production skill boundary requires caller-owned attack/effect authoring")
    _expect(_contains(production_errors, "forced_interruption_profile_id"), "production skill boundary requires caller-owned forced-interruption authoring")
    _expect(_contains(production_errors, "cue_profile_id"), "production skill boundary requires caller-owned cue authoring")


func _test_production_skill_authoring_fails_closed() -> void:
    var action := _production_action(
        &"fixture_action:arcane_lance",
        &"focused_arcane_projectile",
        &"mana"
    )
    _expect(action.validate_production_skill_authoring(&"focused_arcane_projectile").is_empty(), "complete structural production-skill authoring validates without assigning balance values")

    var manifest := action.production_skill_authoring_manifest(&"focused_arcane_projectile")
    _expect(bool(manifest.get("accepted", false)), "validated production skill exposes an integration manifest")
    _expect(StringName(manifest.get("mechanic_id", &"")) == &"focused_arcane_projectile", "production manifest binds the action to the approved skill mechanic identity")
    var responsibilities := manifest.get("profile_responsibilities", {}) as Dictionary
    var effect_requirements := responsibilities.get("effect_profile_id", PackedStringArray()) as PackedStringArray
    _expect(effect_requirements.has("attack_shape") and effect_requirements.has("target_mask") and effect_requirements.has("damage_category_and_tags") and effect_requirements.has("hit_count") and effect_requirements.has("poise_and_knockback_effects") and effect_requirements.has("status_eligibility") and effect_requirements.has("critical_and_weak_point_interaction"), "effect profile boundary names the complete content-owned combat effect responsibilities from the master")
    _expect(not manifest.has("raw_damage") and not manifest.has("guard_pressure") and not manifest.has("poise_damage") and not manifest.has("status_magnitude"), "production action boundary does not fabricate damage, defense pressure, poise, or status numbers")

    var mismatch := action.validate_production_skill_authoring(&"telegraphed_delayed_arcane_area_hit")
    _expect(_contains(mismatch, "must match"), "production action cannot be silently rebound to a different approved skill mechanic")

    var missing_effect := _production_action(
        &"fixture_action:missing_effect",
        &"focused_arcane_projectile",
        &"mana"
    )
    missing_effect.effect_profile_id = &""
    _expect(_contains(missing_effect.validate_production_skill_authoring(&"focused_arcane_projectile"), "effect_profile_id"), "missing attack/effect authoring fails closed")


func _test_all_approved_active_skill_mechanics_fit_boundary() -> void:
    var active_count := 0
    for definition: SkillDefinition in SkillCatalog.all_definitions():
        if definition.kind != SkillDefinition.KIND_ACTIVE:
            continue
        active_count += 1
        var action := _production_action(
            StringName("fixture_action:%s" % String(definition.skill_id)),
            definition.mechanic_id,
            definition.cost_resource
        )
        _expect(
            action.validate_production_skill_authoring(definition.mechanic_id).is_empty(),
            "%s can use the shared production action authoring boundary without invented skill tuning" % definition.display_name
        )
    _expect(active_count == 9, "all nine approved active skills were audited through the shared production action boundary")


func _test_strict_skill_execution_path() -> void:
    var profile := ProfileCreationService.create_profile(1, "Production Action Boundary", "mage")
    var incomplete := _base_action(&"fixture_action:incomplete_arcane_lance", &"mana")
    var incomplete_result := SkillExecutionService.resolve_equipped_production_action(
        profile,
        0,
        {&"focused_arcane_projectile": incomplete}
    )
    _expect(
        not bool(incomplete_result.get("accepted", true))
        and StringName(incomplete_result.get("reason_id", &"")) == SkillExecutionService.REASON_PRODUCTION_AUTHORING_INCOMPLETE,
        "strict production skill resolution rejects a generic ActionDefinition with no production authoring profiles"
    )
    _expect(not (incomplete_result.get("production_authoring_errors", PackedStringArray()) as PackedStringArray).is_empty(), "strict rejection exposes exact missing production authoring fields")

    var zero_cost := _production_action(
        &"fixture_action:zero_cost_arcane_lance",
        &"focused_arcane_projectile",
        &"mana"
    )
    zero_cost.cost_amount = 0.0
    var zero_cost_result := SkillExecutionService.resolve_equipped_production_action(
        profile,
        0,
        {&"focused_arcane_projectile": zero_cost}
    )
    _expect(
        not bool(zero_cost_result.get("accepted", true))
        and StringName(zero_cost_result.get("reason_id", &"")) == SkillExecutionService.REASON_PRODUCTION_AUTHORING_INCOMPLETE,
        "strict production path rejects a resource-labelled active skill that does not actually spend its approved resource"
    )
    _expect(_contains(zero_cost_result.get("production_authoring_errors", PackedStringArray()) as PackedStringArray, "positive authored cost_amount"), "resource-spending rejection reports the exact missing positive cost contract")

    var action := _production_action(
        &"fixture_action:production_arcane_lance",
        &"focused_arcane_projectile",
        &"mana"
    )
    var resolved := SkillExecutionService.resolve_equipped_production_action(
        profile,
        0,
        {&"focused_arcane_projectile": action}
    )
    _expect(
        not bool(resolved.get("accepted", true))
        and StringName(resolved.get("reason_id", &"")) == SkillExecutionService.REASON_PRODUCTION_AUTHORITY_INCOMPLETE,
        "strict production skill resolution distinguishes structural authoring from authoritative production tuning/effects"
    )
    var authority_missing := resolved.get("production_missing_fields", PackedStringArray()) as PackedStringArray
    _expect(authority_missing.has("raw_damage") and authority_missing.has("projectile_speed") and authority_missing.has("cooldown_ticks"), "strict production resolution exposes the exact unresolved Arcane Lance combat fields")
    _expect((resolved.get("production_known_semantics", {}) as Dictionary).get("damage_domain", &"") == &"arcane", "strict rejection still exposes the master-authored Arcane Lance semantics")

    _requested_action_id = &""
    var requested := SkillExecutionService.request_active_production(
        profile,
        0,
        {&"focused_arcane_projectile": action},
        Callable(self, &"_accept_action"),
        &"skill_1",
        Vector2.RIGHT
    )
    _expect(not bool(requested.get("accepted", true)) and _requested_action_id == &"", "strict production request path never forwards an incomplete production action")


func _base_action(action_id: StringName, resource_id: StringName) -> ActionDefinition:
    var action := ActionDefinition.new()
    action.action_id = action_id
    action.startup_ticks = 2
    action.commit_ticks = 1
    action.active_ticks = 1
    action.recovery_ticks = 2
    action.cooldown_ticks = 3
    action.buffer_lifetime_ticks = 8
    action.cost_resource = resource_id
    action.cost_amount = 1.0 if resource_id != &"" else 0.0
    action.uses_aim = true
    action.aim_lock_point = ActionDefinition.AimLockPoint.COMMIT
    return action


func _production_action(action_id: StringName, mechanic_id: StringName, resource_id: StringName) -> ActionDefinition:
    var action := _base_action(action_id, resource_id)
    action.production_mechanic_id = mechanic_id
    action.eligible_states_profile_id = StringName("action_states:%s" % String(mechanic_id))
    action.movement_aim_profile_id = StringName("movement_aim:%s" % String(mechanic_id))
    action.effect_profile_id = StringName("effect:%s" % String(mechanic_id))
    action.forced_interruption_profile_id = StringName("interrupt:%s" % String(mechanic_id))
    action.cue_profile_id = StringName("cue:%s" % String(mechanic_id))
    return action


func _accept_action(_input_action_id: StringName, action: ActionDefinition, _aim_sample: Vector2) -> bool:
    _requested_action_id = action.action_id
    return true


func _contains(errors: PackedStringArray, fragment: String) -> bool:
    for error: String in errors:
        if error.contains(fragment):
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
