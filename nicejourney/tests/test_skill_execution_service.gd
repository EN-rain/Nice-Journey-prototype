extends SceneTree

var _failures: int = 0
var _requested_action_id: StringName = &""


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_authored_definition_boundary()
    _test_prerequisite_boundary()

    if _failures == 0:
        print("SKILL EXECUTION SERVICE TEST PASS")
    else:
        push_error("SKILL EXECUTION SERVICE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_authored_definition_boundary() -> void:
    var profile := ProfileCreationService.create_profile(1, "Execution", "mage")
    var missing := SkillExecutionService.resolve_equipped_action(profile, 0, {})
    _expect(not bool(missing.get("accepted", true)) and StringName(missing.get("reason_id", &"")) == SkillExecutionService.REASON_ACTION_DEFINITION_REQUIRED, "equipped active skill cannot execute from mechanic identity alone when timing/effect ActionDefinition is unauthored")

    var action := _action(&"skill_action:arcane_lance", &"mana")
    var authored := SkillExecutionService.resolve_equipped_action(profile, 0, {
        &"focused_arcane_projectile": action,
    })
    _expect(bool(authored.get("accepted", false)) and authored.get("action_definition") == action, "execution boundary resolves the caller-owned authored definition by SkillCatalog mechanic ID")

    var mismatch := SkillExecutionService.resolve_equipped_action(profile, 0, {
        &"focused_arcane_projectile": _action(&"skill_action:wrong_resource", &"stamina"),
    })
    _expect(not bool(mismatch.get("accepted", true)) and StringName(mismatch.get("reason_id", &"")) == SkillExecutionService.REASON_ACTION_DEFINITION_MISMATCH, "execution boundary rejects an action definition whose resource identity conflicts with the skill catalog")

    _requested_action_id = &""
    var requested := SkillExecutionService.request_active(
        profile,
        0,
        {&"focused_arcane_projectile": action},
        Callable(self, &"_accept_action"),
        &"skill_slot_1",
        Vector2(8.0, 3.0)
    )
    _expect(bool(requested.get("accepted", false)) and _requested_action_id == action.action_id, "execution boundary can forward a resolved authored definition into the existing action request callable")


func _test_prerequisite_boundary() -> void:
    var profile := ProfileCreationService.create_profile(1, "Riposte", "melee")
    profile.skill_points = 1
    _expect(SkillProgressionService.purchase_rank(profile, &"riposte", &"skill_exec:riposte_rank"), "execution prerequisite fixture learns Riposte")
    _expect(SkillProgressionService.equip_active(profile, 0, &"riposte", true, false), "execution prerequisite fixture equips Riposte at a safe interaction")
    var actions := {
        &"supported_parry_counter": _action(&"skill_action:riposte", &"stamina"),
    }
    var unknown := SkillExecutionService.resolve_equipped_action(profile, 0, actions)
    _expect(not bool(unknown.get("accepted", true)) and StringName(unknown.get("reason_id", &"")) == SkillExecutionService.REASON_PREREQUISITE_STATE_REQUIRED, "Riposte fails closed when the successful-parry runtime event state has no owner")
    var unmet := SkillExecutionService.resolve_equipped_action(profile, 0, actions, {&"successful_parry": false})
    _expect(not bool(unmet.get("accepted", true)) and StringName(unmet.get("reason_id", &"")) == SkillExecutionService.REASON_PREREQUISITE_UNSATISFIED, "Riposte rejects execution when its authored successful-parry prerequisite is false")
    var met := SkillExecutionService.resolve_equipped_action(profile, 0, actions, {&"successful_parry": true})
    _expect(bool(met.get("accepted", false)), "Riposte resolves only when the caller supplies the authored successful-parry prerequisite as satisfied")


func _action(action_id: StringName, resource_id: StringName) -> ActionDefinition:
    var action := ActionDefinition.new()
    action.action_id = action_id
    action.startup_ticks = 2
    action.commit_ticks = 1
    action.active_ticks = 1
    action.recovery_ticks = 2
    action.cooldown_ticks = 10
    action.buffer_lifetime_ticks = 8
    action.cost_resource = resource_id
    action.cost_amount = 5.0
    action.uses_aim = true
    action.aim_lock_point = ActionDefinition.AimLockPoint.COMMIT
    return action


func _accept_action(_input_action_id: StringName, action: ActionDefinition, _aim_sample: Vector2) -> bool:
    _requested_action_id = action.action_id
    return true


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
