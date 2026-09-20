extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    for class_id: String in ["melee", "ranged", "mage"]:
        await _check_class(class_id)

    if _failures == 0:
        print("GAMEPLAY ACTIVE SKILL CLOCK PLAYTEST TEST PASS")
    else:
        push_error("GAMEPLAY ACTIVE SKILL CLOCK PLAYTEST TEST FAILURES: %d" % _failures)
    quit(_failures)


func _check_class(class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Skill Clock " + class_id, class_id)
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    var machine := game.combat_runtime.action_state_machine
    var content := game.active_skills_playtest
    _expect(content != null and content.validate_content().is_empty(), "%s nine-skill playtest bundle is valid" % class_id)
    var active := (profile.skill_state["active_slots"] as Array)
    var skill_id := StringName(String(active[0]))
    var skill := SkillCatalog.get_definition(skill_id)
    var action := (content.action_definitions_by_mechanic().get(skill.mechanic_id, null) as ActionDefinition)
    _expect(action != null and action.action_id == StringName("action:playtest:%s" % String(skill_id)), "%s first equipped skill maps to its Inspector-authored action" % class_id)
    if action == null:
        game.queue_free()
        await process_frame
        return
    game.combat_hud.call("refresh_from_runtime")
    var initial_hud := (game.combat_hud.call("current_snapshot") as Dictionary).get("skill_loadout", {}) as Dictionary
    _expect(bool(initial_hud.get("runtime_action_available", false)) and bool(((initial_hud.get("active_slots", []) as Array)[0] as Dictionary).get("runtime_action_available", false)), "%s shipped HUD shows equipped playtest skills as executable" % class_id)
    var mana_before := game.combat_runtime.get_mana()
    var stamina_before := game.player.stamina.current_stamina
    var q_event := InputEventAction.new()
    q_event.action = &"skill_1"
    q_event.pressed = true
    game._unhandled_input(q_event)
    var start := game.last_active_skill_request.duplicate(true)
    var effective_action := game._passive_skill_runtime.modify_action(start.get("action_definition") as ActionDefinition)
    _expect(bool(start.get("accepted", false)) and start.get("action_id", &"") == action.action_id and bool(start.get("playtest_placeholder", false)) and bool(start.get("effect_delivery_available", false)), "%s Q starts the Inspector-authored provisional attack delivery without claiming production authority" % class_id)
    _expect(machine.get_phase() == ActionStateMachine.Phase.STARTUP, "%s skill action starts in Startup" % class_id)
    _expect(is_equal_approx(game.player.stamina.current_stamina, stamina_before) and is_equal_approx(game.combat_runtime.get_mana(), mana_before), "%s startup does not spend resources early" % class_id)
    for _tick: int in action.startup_ticks:
        machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.COMMIT and machine.get_cooldown_ticks(action.action_id) > 0, "%s skill pays its cost and sets cooldown at commit, not startup" % class_id)
    game.combat_hud.call("refresh_from_runtime")
    var cooling_hud := (game.combat_hud.call("current_snapshot") as Dictionary).get("skill_loadout", {}) as Dictionary
    var cooling_slot := (cooling_hud.get("active_slots", []) as Array)[0] as Dictionary
    _expect(bool(cooling_slot.get("cooldown_state_available", false)) and int(cooling_slot.get("cooldown_ticks", 0)) > 0, "%s shipped HUD shows actual playtest action cooldown ticks" % class_id)
    if class_id == "mage":
        _expect(is_equal_approx(game.combat_runtime.get_mana(), mana_before - effective_action.cost_amount) and is_equal_approx(game.player.stamina.current_stamina, stamina_before), "mage spends actual rank/passive-adjusted mana without consuming stamina")
    else:
        _expect(is_equal_approx(game.player.stamina.current_stamina, stamina_before - effective_action.cost_amount) and is_equal_approx(game.combat_runtime.resource_pool.get_value(&"stamina"), game.player.stamina.current_stamina), "%s spends the effective rank/passive-adjusted stamina once; action pool does not drift" % class_id)
    machine.force_interrupt(&"test:reset")
    var unavailable := game.request_active_skill_slot(2)
    _expect(not bool(unavailable.get("accepted", true)), "%s out-of-range action slot rejects safely" % class_id)
    var cooling := game.request_active_skill_slot(0)
    _expect(not bool(cooling.get("accepted", true)), "%s same skill cannot be restarted during cooldown" % class_id)

    var second_skill := StringName(String(active[1]))
    var second_def := SkillCatalog.get_definition(second_skill)
    var second_action := content.action_definitions_by_mechanic().get(second_def.mechanic_id) as ActionDefinition
    var r_event := InputEventAction.new()
    r_event.action = &"skill_2"
    r_event.pressed = true
    game._unhandled_input(r_event)
    var second := game.last_active_skill_request.duplicate(true)
    _expect(bool(second.get("accepted", false)) and machine.get_current_action_id() == second_action.action_id, "%s R selects the second equipped skill" % class_id)
    if class_id == "mage":
        _expect(game.combat_runtime.resource_pool.set_value(&"mana", 0.0), "mage test can spend remaining mana during startup")
    else:
        _expect(game.player.stamina.apply_combat_value(0.0, false), "%s external dodge/stamina spend can occur during startup" % class_id)
    for _tick: int in second_action.startup_ticks:
        machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.IDLE and machine.get_cooldown_ticks(second_action.action_id) == 0, "%s insufficient live resource at commit cancels the skill before cooldown or effect" % class_id)
    _expect(not bool(game.request_active_skill_slot(1).get("accepted", true)), "%s empty live resource rejects the next skill request" % class_id)
    machine.force_interrupt(&"test:reset")
    game.queue_free()
    await process_frame


func _expect(ok: bool, name: String) -> void:
    if ok:
        print("PASS: %s" % name)
    else:
        _failures += 1
        push_error("FAIL: %s" % name)
