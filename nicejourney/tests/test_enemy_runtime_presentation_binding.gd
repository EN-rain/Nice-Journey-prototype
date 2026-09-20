extends SceneTree

const SCENE_PATHS: Array[String] = [
    "res://src/enemies/presentation/scenes/duelist_visual.tscn",
    "res://src/enemies/presentation/scenes/bruiser_visual.tscn",
    "res://src/enemies/presentation/scenes/defender_visual.tscn",
    "res://src/enemies/presentation/scenes/marksman_visual.tscn",
    "res://src/enemies/presentation/scenes/skirmisher_visual.tscn",
    "res://src/enemies/presentation/scenes/assassin_visual.tscn",
    "res://src/enemies/presentation/scenes/mobile_ranged_visual.tscn",
    "res://src/enemies/presentation/scenes/caster_visual.tscn",
    "res://src/enemies/presentation/scenes/support_visual.tscn",
    "res://src/enemies/presentation/scenes/summoner_visual.tscn",
    "res://src/enemies/presentation/scenes/flying_harrier_visual.tscn",
    "res://src/enemies/presentation/scenes/controller_disruptor_visual.tscn",
]
const DEFENDER_SCENE: PackedScene = preload("res://src/enemies/presentation/scenes/defender_visual.tscn")

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    await _test_all_enemy_visuals_own_runtime_binder()
    await _test_contact_and_defeat_events_drive_semantic_presentation()
    await _test_archetype_action_phases_drive_semantic_presentation()

    if _failures == 0:
        print("ENEMY RUNTIME PRESENTATION BINDING TEST PASS")
    else:
        push_error("ENEMY RUNTIME PRESENTATION BINDING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_all_enemy_visuals_own_runtime_binder() -> void:
    for scene_path: String in SCENE_PATHS:
        var packed := load(scene_path) as PackedScene
        _expect(packed != null, "%s loads" % scene_path)
        if packed == null:
            continue
        var visual := packed.instantiate() as EnemyVisualController
        root.add_child(visual)
        await process_frame
        var binder := visual.get_node_or_null("RuntimePresentationBinder") as EnemyRuntimePresentationBinder
        _expect(binder != null, "%s owns the shared runtime/presentation binder" % String(visual.profile.archetype_id))
        _expect(binder != null and binder.visual == visual, "%s binder resolves its inspector-authored visual target" % String(visual.profile.archetype_id))
        visual.queue_free()
        await process_frame


func _test_contact_and_defeat_events_drive_semantic_presentation() -> void:
    var visual := DEFENDER_SCENE.instantiate() as EnemyVisualController
    root.add_child(visual)
    await process_frame
    var binder := visual.get_node_or_null("RuntimePresentationBinder") as EnemyRuntimePresentationBinder

    var runtime := CombatEncounterRuntime.new()
    _expect(runtime.configure(&"encounter:enemy_presentation_fixture"), "enemy presentation fixture configures genuine encounter runtime")
    var player := _combatant(&"player:enemy_presentation_fixture", 100, 0.0, false)
    var defender := _combatant(&"enemy:defender_presentation_fixture", 20, 20.0, true)
    _expect(runtime.register_player(player), "presentation fixture registers player")
    _expect(runtime.register_enemy(defender), "presentation fixture registers enemy through normal lifecycle")
    _expect(binder.bind_runtime(runtime, defender.actor_id), "enemy visual binder accepts genuine runtime and stable actor identity")

    var blocked := runtime.resolve_direct_contact(
        player.actor_id,
        defender.actor_id,
        4101,
        0,
        _attack(5.0, 5.0),
        false,
        DirectHitResolver.DEFENSE_BLOCK,
        true
    )
    _expect(blocked["accepted"] and blocked["outcome"] == DirectHitResolver.OUTCOME_BLOCKED, "fixture produces authoritative block outcome")
    _expect(visual.animation_player.current_animation == &"block", "authoritative block outcome drives configured block animation")

    var hit := runtime.resolve_direct_contact(
        player.actor_id,
        defender.actor_id,
        4102,
        0,
        _attack(5.0, 0.0),
        false,
        DirectHitResolver.DEFENSE_NONE,
        true
    )
    _expect(hit["accepted"] and hit["hp_damage"] == 5 and not hit["target_defeated"], "fixture produces nonfatal authoritative hit")
    _expect(visual.animation_player.current_animation == visual.profile.hit_animation, "nonfatal damage drives inspector-owned hit animation")

    var fatal := runtime.resolve_direct_contact(
        player.actor_id,
        defender.actor_id,
        4103,
        0,
        _attack(50.0, 0.0),
        false,
        DirectHitResolver.DEFENSE_NONE,
        true
    )
    _expect(fatal["accepted"] and fatal["target_defeated"], "fixture produces authoritative enemy defeat")
    _expect(visual.animation_player.current_animation == visual.profile.death_animation, "enemy defeat event drives inspector-owned death animation without transient hit override")

    binder.unbind_runtime()
    _expect(binder.bound_runtime == null and binder.bound_actor_id == &"", "explicit unbind clears runtime presentation ownership")

    var binder_source := FileAccess.get_file_as_string("res://src/enemies/presentation/enemy_runtime_presentation_binder.gd")
    _expect(not binder_source.contains("res://assets/art"), "enemy runtime binder contains no hardcoded art paths")
    _expect(not binder_source.contains(".frame =") and not binder_source.contains("frame_coords"), "enemy runtime binder does not manually step sprite frames")

    runtime.end_encounter()
    visual.queue_free()
    await process_frame


func _test_archetype_action_phases_drive_semantic_presentation() -> void:
    var visual := DEFENDER_SCENE.instantiate() as EnemyVisualController
    root.add_child(visual)
    await process_frame
    var binder := visual.get_node_or_null("RuntimePresentationBinder") as EnemyRuntimePresentationBinder

    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(&"encounter:enemy_action_presentation"), "action-presentation fixture configures encounter")
    var player := _combatant(&"player:enemy_action_presentation", 100, 0.0, false)
    var defender := _combatant(&"enemy:defender_action_presentation", 20, 20.0, true)
    _expect(encounter.register_player(player), "action-presentation fixture registers player")
    _expect(encounter.register_enemy(defender), "action-presentation fixture registers enemy")
    _expect(binder.bind_runtime(encounter, defender.actor_id), "binder owns authoritative contact runtime before action binding")

    var archetype_runtime := EnemyArchetypeRuntime.new()
    _expect(archetype_runtime.configure(encounter, defender.actor_id, player.actor_id, &"defender"), "Defender archetype runtime composes the same encounter owner")
    _expect(binder.bind_archetype_runtime(archetype_runtime), "visual binder accepts matching archetype runtime")

    var context := _selector_context()
    context["distance_band"] = EnemyArchetypeDefinition.RANGE_MID
    var selection: Dictionary = archetype_runtime.choose_tactic(context)
    _expect(StringName(selection.get("tactic_id", &"")) == &"action:defender_guard_counter", "Defender selects authored signature action")
    var commit: Dictionary = archetype_runtime.begin_signature_action(selection, 51001)
    _expect(bool(commit.get("accepted", false)), "Defender signature commits through shared reservation owner")
    _expect(visual.animation_player.current_animation == visual.profile.windup_animation, "committed windup drives inspector-owned windup animation")
    _expect(archetype_runtime.begin_active(51001), "Defender action enters active phase")
    _expect(visual.animation_player.current_animation == visual.profile.release_animation, "active phase drives inspector-owned release animation")
    _expect(archetype_runtime.begin_recovery(51001), "Defender action enters recovery")
    _expect(visual.animation_player.current_animation == visual.profile.release_animation, "recovery holds release pose instead of inventing a missing recovery animation")
    _expect(archetype_runtime.finish_recovery(51001), "Defender recovery completes")
    _expect(visual.animation_player.current_animation == visual.profile.idle_animation, "completed action returns visual to idle")

    _expect(archetype_runtime.mark_cooldown_ready(), "fixture reopens cooldown for movement-intent check")
    var movement_context := _selector_context()
    movement_context["distance_band"] = EnemyArchetypeDefinition.RANGE_LONG
    var movement: Dictionary = archetype_runtime.choose_tactic(movement_context)
    _expect(StringName(movement.get("tactic_id", &"")) == &"tactic:approach", "Defender chooses authored approach when too far")
    _expect(archetype_runtime.request_non_attack_tactic(movement), "runtime emits non-attack movement intent")
    _expect(visual.animation_player.current_animation == visual.profile.move_animation, "movement intent drives inspector-owned move animation")

    binder.unbind_runtime()
    _expect(binder.bound_archetype_runtime == null, "runtime unbind also clears archetype action presentation binding")
    encounter.end_encounter()
    visual.queue_free()
    await process_frame


func _selector_context() -> Dictionary:
    return {
        "target_visible": true,
        "observation_confidence": 1.0,
        "reaction_delay_satisfied": true,
        "distance_band": EnemyArchetypeDefinition.RANGE_CLOSE,
        "reservation_available": true,
        "cooldown_ready": true,
        "objective_contested": false,
        "observed_player_recovering": true,
        "observed_player_committed": false,
        "observation_age_ticks": 0,
    }


func _combatant(actor_id: StringName, hp: int, stamina: float, block_supported: bool) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    var accepted := state.configure(actor_id, hp, stamina, 0.0, 0.0, 20.0, true, block_supported, false)
    _expect(accepted, "%s combatant validates" % String(actor_id))
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
