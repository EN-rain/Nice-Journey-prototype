extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    await _test_actual_gameplay_input_wiring()

    var player := PLAYER_SCENE.instantiate() as PlayerController
    root.add_child(player)
    await process_frame
    var animator := player.body_animator
    _expect(animator != null and animator.validate_animation_setup().is_empty(), "live player owns all 17 validated body animations")
    _test_all_body_animation_texture_switches(player)

    for kind: StringName in [&"interact", &"pickup", &"use_item", &"sleep"]:
        _expect(player.present_committed_interaction(kind), "%s presentation is available to its committed gameplay owner" % String(kind))
        _expect(animator.get_visible_semantic_animation() == kind, "%s selects its visually verified ZIP animation" % String(kind))

    var tuning := StarterCombatTuning.new()
    tuning.melee_parry_window_ticks = 3
    tuning.melee_parry_recovery_ticks = 2
    var machine := ActionStateMachine.new()
    var class_runtime := ClassCombatRuntime.new()
    class_runtime.tuning = tuning
    class_runtime.bind_runtime(machine)
    _expect(class_runtime.configure_class(&"melee"), "Melee runtime configures for live defense presentation")
    _expect(player.configure_starter_visuals(&"melee", machine, class_runtime), "player binds action and defense presentation to live class runtime")
    _expect(class_runtime.request_block(true), "live Melee block input state is admitted")
    _expect(animator.get_visible_semantic_animation() == &"block", "sustained block uses visually verified ZIP block animation")
    _expect(class_runtime.request_block(false), "block release is admitted")
    _expect(class_runtime.request_parry(), "live Melee parry timing state is admitted")
    _expect(animator.get_visible_semantic_animation() == &"parry", "parry state uses visually verified ZIP parry animation")
    await create_timer(0.35).timeout

    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:player_body_binding_fixture"), "genuine encounter runtime configures")
    var player_state := _combatant(&"player:body_binding_fixture", 30, 20.0, true, true)
    var enemy_state := _combatant(&"enemy:body_binding_fixture", 30, 0.0, false, false)
    _expect(encounter.register_player(player_state), "fixture registers player combatant")
    _expect(encounter.register_enemy(enemy_state), "fixture registers enemy combatant")
    _expect(player.bind_combat_runtime(encounter, player_state.actor_id), "player presentation binds to genuine combat runtime")

    var blocked := encounter.resolve_direct_contact(enemy_state.actor_id, player_state.actor_id, 7001, 0, _attack(5.0, 2.0), false, DirectHitResolver.DEFENSE_BLOCK, true)
    _expect(blocked["outcome"] == DirectHitResolver.OUTCOME_BLOCKED, "authoritative block outcome resolves")
    _expect(animator.get_visible_semantic_animation() == &"block", "authoritative block outcome drives ZIP block body animation")

    var parried := encounter.resolve_direct_contact(enemy_state.actor_id, player_state.actor_id, 7002, 0, _attack(5.0, 0.0), false, DirectHitResolver.DEFENSE_PARRY, true)
    _expect(parried["outcome"] == DirectHitResolver.OUTCOME_PARRIED, "authoritative parry outcome resolves")
    _expect(animator.get_visible_semantic_animation() == &"parry", "authoritative parry outcome drives ZIP parry body animation")

    var hit := encounter.resolve_direct_contact(enemy_state.actor_id, player_state.actor_id, 7003, 0, _attack(5.0, 0.0), false, DirectHitResolver.DEFENSE_NONE, true)
    _expect(hit["outcome"] == DirectHitResolver.OUTCOME_HIT, "authoritative damaging hit resolves")
    _expect(animator.get_visible_semantic_animation() == &"hit", "authoritative damage drives ZIP hit body animation")

    var fatal := encounter.resolve_direct_contact(enemy_state.actor_id, player_state.actor_id, 7004, 0, _attack(100.0, 0.0), false, DirectHitResolver.DEFENSE_NONE, true)
    _expect(bool(fatal.get("target_defeated", false)), "authoritative fatal hit defeats player combatant")
    _expect(animator.get_visible_semantic_animation() == &"death", "authoritative defeat drives terminal ZIP death body animation")

    encounter.end_encounter()
    player.unbind_combat_runtime()
    player.queue_free()
    class_runtime.free()
    machine.free()
    await process_frame
    if _failures == 0:
        print("PLAYER RUNTIME BODY ANIMATION BINDING TEST PASS")
    else:
        push_error("PLAYER RUNTIME BODY ANIMATION BINDING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_all_body_animation_texture_switches(player: PlayerController) -> void:
    var body := player.get_node_or_null("BodyVisual/Body") as Sprite2D
    var animation_player := player.get_node_or_null("BodyAnimationPlayer") as AnimationPlayer
    _expect(body != null and animation_player != null, "live player resolves its body Sprite2D and body AnimationPlayer")
    if body == null or animation_player == null:
        return
    var names: Array[StringName] = [
        &"idle", &"walk", &"run", &"dash", &"dodge", &"attack", &"heavy_attack",
        &"block", &"parry", &"cast", &"hit", &"death", &"interact", &"pickup",
        &"use_item", &"climb", &"sleep",
    ]
    for name: StringName in names:
        animation_player.play(name)
        animation_player.advance(0.001)
        var expected := "res://assets/art/player/animations/player_body_%s_sheet_v03.png" % String(name)
        var actual := body.texture.resource_path if body.texture != null else ""
        _expect(actual == expected, "%s changes the live body Sprite2D to the verified V03 sheet" % String(name))


func _test_actual_gameplay_input_wiring() -> void:
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    # Exercise real starter equipment ownership; an uninitialized bare
    # snapshot is not a valid player-loadout fixture for shipped gameplay.
    var profile := ProfileCreationService.create_profile(1, "Animation Fixture", "melee")
    gameplay.set_profile(profile)
    root.add_child(gameplay)
    await process_frame

    _expect(gameplay.player != null and gameplay.combat_runtime != null, "actual gameplay scene resolves player and class-combat runtime")
    var animator := gameplay.player.body_animator
    _expect(animator != null, "actual gameplay player owns body animator")

    var block_press := InputEventAction.new()
    block_press.action = &"block"
    block_press.pressed = true
    gameplay._unhandled_input(block_press)
    _expect(gameplay.combat_runtime.get_defense_mode() == DirectHitResolver.DEFENSE_BLOCK, "actual gameplay RMB/block route enters authoritative block state")
    _expect(animator != null and animator.get_visible_semantic_animation() == &"block", "actual gameplay block route displays verified ZIP block animation")

    var block_release := InputEventAction.new()
    block_release.action = &"block"
    block_release.pressed = false
    gameplay._unhandled_input(block_release)
    _expect(gameplay.combat_runtime.get_defense_mode() == DirectHitResolver.DEFENSE_NONE, "actual gameplay block release clears authoritative block state")

    var parry_press := InputEventAction.new()
    parry_press.action = &"parry"
    parry_press.pressed = true
    gameplay._unhandled_input(parry_press)
    _expect(gameplay.combat_runtime.get_defense_mode() == DirectHitResolver.DEFENSE_PARRY, "actual gameplay F/parry route enters authoritative parry window")
    _expect(animator != null and animator.get_visible_semantic_animation() == &"parry", "actual gameplay parry route displays verified ZIP parry animation")

    gameplay.queue_free()
    await process_frame


func _combatant(actor_id: StringName, hp: int, stamina: float, block_supported: bool, parry_supported: bool) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, stamina, 0.0, 0.0, 20.0, true, block_supported, parry_supported), "%s combatant validates" % String(actor_id))
    return state


func _attack(raw_damage: float, guard_pressure: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": guard_pressure,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
