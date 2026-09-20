extends SceneTree

const SANCTUM_SCENE: PackedScene = preload("res://src/world/tower/boss/tenth_warden_sanctum.tscn")

var _failures := 0
var _terminal_outcomes: Array[StringName] = []

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var sanctum := SANCTUM_SCENE.instantiate() as TenthWardenSanctum
    root.add_child(sanctum)
    await process_frame

    _expect(sanctum != null, "Boss Sanctum uses the dedicated authored arena owner")
    _expect(sanctum.validate_authoring().is_empty(), "Boss Sanctum inspector authoring validates")
    _expect(sanctum.get_arena_rect() == Rect2(Vector2(-224, -128), Vector2(448, 256)), "Boss Sanctum owns one fixed readable arena rectangle")
    _expect(sanctum.player_spawn.position == Vector2(-128, 0), "player spawn is inspector-authored inside the sanctum")
    _expect(sanctum.boss_spawn.position == Vector2(128, 0), "boss spawn is inspector-authored inside the sanctum")
    _expect(sanctum.boss_visual.position == sanctum.boss_spawn.position, "Tenth Warden presentation is anchored to the authored boss spawn")

    _expect(_boundary_matches(sanctum.get_node("TopBoundary") as StaticBody2D, Vector2(448, 16), Vector2(0, -120)), "top fixed boundary matches authored arena")
    _expect(_boundary_matches(sanctum.get_node("BottomBoundary") as StaticBody2D, Vector2(448, 16), Vector2(0, 120)), "bottom fixed boundary matches authored arena")
    _expect(_boundary_matches(sanctum.get_node("LeftBoundary") as StaticBody2D, Vector2(16, 224), Vector2(-216, 0)), "left fixed boundary matches authored arena")
    _expect(_boundary_matches(sanctum.get_node("RightBoundary") as StaticBody2D, Vector2(16, 224), Vector2(216, 0)), "right fixed boundary matches authored arena")
    _expect(_count_nodes_of_type(sanctum, "Area2D") == 0, "Boss Sanctum introduces no ambient-damage or pit Area2D hazards")

    var player := _combatant(&"player:boss_sanctum_fixture", 100, true, true)
    var boss := _combatant(&"enemy:tenth_warden_sanctum", 60, false, false)
    var shared_active := ActiveCombatRegistry.new()
    var shared_full_ai := FullAiSimulationLedger.new()
    var shared_attack_pressure := AttackPressureLedger.new()
    _expect(sanctum.prepare_encounter(player, boss, shared_active, shared_full_ai, shared_attack_pressure), "Boss Sanctum prepares the genuine combat runtime without a second encounter manager")
    _expect(sanctum.encounter_runtime != null and sanctum.boss_runtime != null, "Boss Sanctum owns the live generic encounter plus boss-specific composition")
    _expect(sanctum.encounter_runtime.full_ai == shared_full_ai and sanctum.encounter_runtime.attack_pressure == shared_attack_pressure, "Boss Sanctum reuses the Tower session's shared FULL-AI and attack-pressure ledgers")
    _expect(sanctum.encounter_runtime.full_ai.get_admitted_count() == 1, "sanctum boss consumes exactly one FULL-AI admission")
    _expect(shared_active.is_active(), "sanctum preparation raises the shared Active Combat cause")

    var binder := sanctum.boss_visual.get_node_or_null("StatePresentationBinder") as TenthWardenPresentationStateBinder
    var boss_status := sanctum.boss_visual.get_node_or_null("CombatStatus") as EnemyCombatStatusPresenter
    _expect(binder != null and binder.bound_state == sanctum.boss_runtime.state, "Boss Sanctum binds authoritative boss state to inspector-owned presentation")
    _expect(boss_status != null and is_equal_approx(boss_status.get_health_ratio(), 1.0), "Boss Sanctum exposes an authoritative boss health presentation")
    _expect(binder != null and binder.bound_combat_runtime == sanctum.encounter_runtime and binder.bound_actor_id == boss.actor_id, "Boss Sanctum binds genuine combat outcomes to the boss presentation actor")
    _expect(sanctum.boss_runtime.begin_move(TenthWardenEncounterState.MOVE_TWIN_CUT, 7001), "sanctum boss begins an approved committed move")
    _expect(sanctum.boss_visual.animation_player.current_animation == &"twin_cut", "live sanctum move event drives the Tenth Warden AnimationPlayer")
    _expect(sanctum.boss_runtime.begin_recovery(false) and sanctum.boss_runtime.finish_recovery(), "sanctum move recovery returns normal ownership")

    var player_hit := sanctum.boss_runtime.resolve_player_contact(8001, 0, _attack(30.0))
    _expect(player_hit["accepted"] and boss.current_hp == 30, "sanctum live boss HP reaches the approved transition threshold through shared DR-06 resolution")
    _expect(boss_status != null and is_equal_approx(boss_status.get_health_ratio(), 0.5), "boss health presentation reads the same post-hit authoritative HP")
    _expect(boss_status != null and boss_status.get_damage_number_count() == 1, "boss damage emits one bounded damage-number presentation")
    _expect(sanctum.boss_visual.animation_player.current_animation == &"hit", "nonlethal live boss damage drives the configured hit presentation")
    _expect(sanctum.boss_runtime.state.transition_action_requested, "sanctum requests phase transition only from authoritative live HP")
    _expect(sanctum.boss_runtime.commit_phase_transition(), "sanctum commits the irreversible non-damaging phase transition")
    _expect(sanctum.boss_visual.animation_player.current_animation == &"phase_two", "phase transition drives phase-two presentation without changing arena geometry")
    _expect(boss.current_hp == 30, "sanctum phase transition does not heal or reset boss HP")

    var final_hit := sanctum.boss_runtime.resolve_player_contact(8002, 0, _attack(30.0))
    _expect(final_hit["accepted"] and final_hit["target_defeated"], "live sanctum boss defeat resolves through the shared encounter owner")
    _expect(boss_status != null and is_equal_approx(boss_status.get_health_ratio(), 0.0), "boss health presentation reaches zero from authoritative defeat")
    _expect(sanctum.boss_runtime.evaluate_live_outcome() == TenthWardenEncounterState.OUTCOME_VICTORY, "boss defeat commits victory only while the player remains alive")
    _expect(sanctum.boss_visual.animation_player.current_animation == &"death", "authoritative enemy defeat drives the configured Tenth Warden death presentation")
    _expect(binder.bound_state == null, "boss defeat detaches move-state presentation so recovery cannot overwrite death")

    sanctum.terminal_outcome_committed.connect(_on_terminal_outcome_committed)
    _expect(sanctum.commit_terminal_outcome(), "Boss Sanctum commits the authoritative terminal victory exactly once")
    _expect(sanctum.committed_terminal_outcome == TenthWardenEncounterState.OUTCOME_VICTORY, "Boss Sanctum records committed victory without granting reward itself")
    _expect(_terminal_outcomes == [TenthWardenEncounterState.OUTCOME_VICTORY], "terminal victory emits one explicit outcome event for the external progression owner")
    _expect(sanctum.encounter_runtime == null and sanctum.boss_runtime == null, "terminal commit closes encounter ownership immediately")
    _expect(boss_status != null and boss_status.bound_runtime == null, "terminal commit unbinds boss health/damage presentation ownership")
    _expect(not sanctum.commit_terminal_outcome(), "terminal outcome cannot commit twice")

    var top_before := (sanctum.get_node("TopBoundary") as StaticBody2D).position
    await process_frame
    _expect((sanctum.get_node("TopBoundary") as StaticBody2D).position == top_before, "sanctum boundaries do not shrink or move during runtime")

    _expect(not shared_active.is_active(), "terminal commit releases shared Active Combat ownership")
    _expect(binder.bound_state == null and binder.bound_combat_runtime == null, "terminal commit unbinds boss state and combat presentation sources")

    var tie_sanctum := SANCTUM_SCENE.instantiate() as TenthWardenSanctum
    root.add_child(tie_sanctum)
    await process_frame
    var tie_player := _combatant(&"player:boss_sanctum_tie", 100, true, true)
    var tie_boss := _combatant(&"enemy:tenth_warden_sanctum_tie", 100, false, false)
    _expect(tie_sanctum.prepare_encounter(tie_player, tie_boss), "tie sanctum prepares the genuine encounter runtime")
    tie_player.current_hp = 0
    tie_boss.current_hp = 0
    tie_sanctum.terminal_outcome_committed.connect(_on_terminal_outcome_committed)
    _expect(tie_sanctum.commit_terminal_outcome(), "simultaneous end-of-tick defeat facts commit one terminal result")
    _expect(tie_sanctum.committed_terminal_outcome == TenthWardenEncounterState.OUTCOME_FAILED_ATTEMPT, "simultaneous player/boss defeat commits failed attempt under DR-02")
    _expect(_terminal_outcomes == [TenthWardenEncounterState.OUTCOME_VICTORY, TenthWardenEncounterState.OUTCOME_FAILED_ATTEMPT], "terminal event stream distinguishes victory from failed attempt exactly once")
    tie_sanctum.queue_free()

    var source := FileAccess.get_file_as_string("res://src/world/tower/boss/tenth_warden_sanctum.gd")
    _expect(not source.contains("spawn_add") and not source.contains("heal") and not source.contains("hazard_damage"), "Boss Sanctum does not invent adds, healing, or unavoidable ambient damage")
    _expect(not source.contains("grant_reward") and not source.contains("award_reward") and not source.contains("loot"), "Boss Sanctum terminal boundary does not invent or grant boss rewards")
    _expect(not source.contains("res://assets/art"), "Boss Sanctum runtime contains no hardcoded art paths")

    sanctum.queue_free()
    await process_frame

    if _failures == 0:
        print("TENTH WARDEN SANCTUM INTEGRATION TEST PASS")
    else:
        push_error("TENTH WARDEN SANCTUM INTEGRATION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _combatant(actor_id: StringName, hp: int, block_supported: bool, parry_supported: bool) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, hp, 30.0, 0.0, 0.0, 30.0, true, block_supported, parry_supported), "%s combatant validates" % String(actor_id))
    return state

func _attack(raw_damage: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 5.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }

func _boundary_matches(body: StaticBody2D, expected_size: Vector2, expected_position: Vector2) -> bool:
    if body == null or body.position != expected_position:
        return false
    var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
    if collision == null:
        return false
    var rectangle := collision.shape as RectangleShape2D
    return rectangle != null and rectangle.size == expected_size

func _count_nodes_of_type(node: Node, class_name_to_match: String) -> int:
    var count := 0
    for child: Node in node.get_children():
        if child.is_class(class_name_to_match):
            count += 1
        count += _count_nodes_of_type(child, class_name_to_match)
    return count

func _on_terminal_outcome_committed(outcome_id: StringName) -> void:
    _terminal_outcomes.append(outcome_id)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
