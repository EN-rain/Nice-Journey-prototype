extends SceneTree

const GAMEPLAY: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    for class_id: String in ["melee", "ranged", "mage"]:
        await _check_live_attack(class_id)
    if _failures == 0:
        print("PLAYER PLAYTEST LIVE ATTACK DELIVERY TEST PASS")
    else:
        push_error("PLAYER PLAYTEST LIVE ATTACK DELIVERY TEST FAILURES: %d" % _failures)
    quit(_failures)


func _check_live_attack(class_id: String) -> void:
    var profile := ProfileCreationService.create_profile(1, "Live Hit " + class_id, class_id)
    var game := GAMEPLAY.instantiate() as GameplayRoot
    game.set_profile(profile)
    root.add_child(game)
    await process_frame
    game._set_foundation_world_enabled(false) # Real Tower entry disables the greybox center obstacle.
    game.player.global_position = Vector2(250, 180)
    var enemy := Node2D.new()
    enemy.name = "PlaytestTarget_" + class_id
    enemy.position = Vector2(306, 180) if class_id == "melee" else Vector2(400, 180)
    game.tower_encounter_session_host.add_child(enemy)

    var encounter := CombatEncounterRuntime.new()
    var encounter_id := StringName("encounter:playtest_delivery_%s" % class_id)
    var enemy_id := StringName("enemy:playtest_delivery_%s" % class_id)
    var player_state := _combatant(&"player:local", 100)
    var enemy_state := _combatant(enemy_id, 100)
    _expect(encounter.configure(encounter_id, game.shared_active_combat, game.shared_full_ai) and encounter.register_player(player_state) and encounter.register_enemy(enemy_state), "%s fixture has a genuine active encounter runtime" % class_id)
    game.tower_encounter_session_host._sessions[encounter_id] = {
        "encounter_runtime": encounter,
        "visuals_by_actor": {enemy_id: enemy},
    }
    var delivered := game.player_playtest_attack_delivery
    _expect(delivered != null and delivered.content != null and delivered.content.validate_content().is_empty(), "%s uses shipped Inspector-authored placeholder geometry and actual combat runtime" % class_id)
    var machine := game.combat_runtime.action_state_machine
    var basic := game.combat_runtime.starter_kit.basic_action
    _expect(game.combat_runtime.request_basic_attack(Vector2.RIGHT), "%s basic attack starts through standard action owner" % class_id)
    for _tick: int in basic.startup_ticks + basic.commit_ticks:
        machine.advance_fixed_tick()
    _expect(machine.get_phase() == ActionStateMachine.Phase.ACTIVE, "%s basic attack reaches authorized ACTIVE phase" % class_id)
    if class_id != "melee":
        _expect(enemy_state.current_hp == 100, "%s projectile does not teleport damage at the ACTIVE phase" % class_id)
        for _tick: int in 80:
            await physics_frame
            if enemy_state.current_hp < 100:
                break
    _expect(enemy_state.current_hp < 100 and bool(delivered.last_contact_result.get("accepted", false)), "%s visual-world contact delivers real mitigated HP damage" % class_id)
    var after_first := enemy_state.current_hp
    for _tick: int in 14:
        await physics_frame
    _expect(enemy_state.current_hp == after_first, "%s one hit instance cannot damage the same target repeatedly" % class_id)

    machine.force_interrupt(&"test:skill_start")
    game.player.apply_aim_direction(Vector2.RIGHT)
    var started := game.request_active_skill_slot(0)
    _expect(bool(started.get("accepted", false)) and bool(started.get("effect_delivery_available", false)), "%s Q is attached to its provisional active-skill delivery" % class_id)
    var action := started.get("action_definition") as ActionDefinition
    if action != null:
        for _tick: int in action.startup_ticks + action.commit_ticks:
            machine.advance_fixed_tick()
    if class_id != "melee":
        _expect(enemy_state.current_hp == after_first, "%s Q projectile cannot damage before travel" % class_id)
        for _tick: int in 90:
            await physics_frame
            if enemy_state.current_hp < after_first:
                break
    _expect(enemy_state.current_hp < after_first, "%s Q reaches the existing damage resolver only after the ACTIVE delivery geometry confirms contact" % class_id)

    machine.force_interrupt(&"test:second_skill")
    game.player.apply_aim_direction(Vector2.RIGHT)
    var before_second := enemy_state.current_hp
    var second := game.request_active_skill_slot(1)
    _expect(bool(second.get("accepted", false)) and bool(second.get("effect_delivery_available", false)), "%s R is linked to a distinct provisional effect definition" % class_id)
    var second_action := second.get("action_definition") as ActionDefinition
    if second_action != null:
        for _tick: int in second_action.startup_ticks + second_action.commit_ticks:
            machine.advance_fixed_tick()
    if class_id != "melee":
        _expect(enemy_state.current_hp == before_second, "%s R spread or delayed area effect does not teleport damage at ACTIVE" % class_id)
        for _tick: int in 90:
            await physics_frame
            if enemy_state.current_hp < before_second:
                break
    _expect(enemy_state.current_hp < before_second, "%s R delivers its independent provisional effect to real enemy HP" % class_id)

    game.tower_encounter_session_host.end_encounter(encounter_id)
    game.queue_free()
    await process_frame


func _combatant(actor_id: StringName, hp: int) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, 100.0, 0.0, 0.0, 10.0, true, false, false), "configured combatant %s" % String(actor_id))
    return state


func _expect(ok: bool, message: String) -> void:
    if ok:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
