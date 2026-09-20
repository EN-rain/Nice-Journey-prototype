extends SceneTree

const TUNING: EnemyPrototypeDecisionTuning = preload("res://src/data/tuning/enemy_prototype_decision_default.tres")
var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_reaction_delay_and_visible_commit()
    _test_lost_sight_uses_last_known_without_attack()
    _test_shared_observation_preserves_age_without_attack()
    _test_signature_fairness_facts_remain_enforced()
    _test_signature_repeat_suppression()
    if _failures == 0:
        print("ENEMY PROTOTYPE DECISION DRIVER TEST PASS")
    else:
        push_error("ENEMY PROTOTYPE DECISION DRIVER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_reaction_delay_and_visible_commit() -> void:
    _expect(TUNING.validate_tuning().is_empty(), "default prototype decision tuning validates")
    var fixture := _fixture(&"marksman", &"encounter:decision_visible", &"enemy:decision_marksman")
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var phase_driver := fixture["phase_driver"] as EnemySignatureActionPhaseDriver
    var driver := fixture["driver"] as EnemyPrototypeDecisionDriver
    var first := driver.observe_and_decide(0, Vector2.ZERO, Vector2(300, 0), true, 71001)
    _expect(bool(first.get("accepted", false)), "first visible observation evaluates legally")
    _expect(not bool(first.get("committed", false)), "enemy cannot react on the same tick that sight is first acquired")
    _expect(runtime.tactical_state_id == EnemyArchetypeRuntime.TACTICAL_OBSERVE, "reaction delay keeps first observation in tactical Observe")
    var early := driver.observe_and_decide(6, Vector2.ZERO, Vector2(300, 0), true, 71001)
    _expect(bool(early.get("accepted", false)) and not bool(early.get("committed", false)), "utility reevaluation before minimum reaction time still cannot commit")
    var ready := driver.observe_and_decide(12, Vector2.ZERO, Vector2(300, 0), true, 71001)
    _expect(bool(ready.get("committed", false)), "visible target can commit signature only after authored reaction delay")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_WINDUP, "decision commitment enters readable windup rather than instant active damage")
    _expect(bool((ready.get("signature_facts", {}) as Dictionary).get("line_of_sight_observed", false)), "Marksman commit carries observed LOS fairness fact")
    _expect(Vector2((ready.get("signature_facts", {}) as Dictionary).get("observed_target_position", Vector2.ZERO)) == Vector2(300, 0), "signature commitment carries the exact admitted target-position observation")
    var windup_ticks := int(EnemySignatureActionTimingCatalog.get_timing(&"marksman").get("windup_ticks", 0))
    for _index: int in range(windup_ticks):
        _expect(phase_driver.advance_fixed_tick(), "commit-observation fixture windup tick advances")
    var active_context := runtime.get_active_delivery_context(71001)
    _expect(bool(active_context.get("accepted", false)) and bool(active_context.get("has_committed_observation_position", false)), "ACTIVE delivery context preserves whether a committed observation snapshot exists")
    _expect(Vector2(active_context.get("committed_observation_position", Vector2.ZERO)) == Vector2(300, 0), "ACTIVE delivery context preserves the admitted position captured at commitment")
    driver.observe_and_decide(18, Vector2.ZERO, Vector2(500, 0), true, 71002)
    var unchanged_context := runtime.get_active_delivery_context(71001)
    _expect(Vector2(unchanged_context.get("committed_observation_position", Vector2.ZERO)) == Vector2(300, 0), "later visible target movement cannot rewrite the already-committed observation snapshot")

func _test_lost_sight_uses_last_known_without_attack() -> void:
    var fixture := _fixture(&"duelist", &"encounter:decision_lost_sight", &"enemy:decision_duelist")
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var driver := fixture["driver"] as EnemyPrototypeDecisionDriver
    driver.observe_and_decide(0, Vector2.ZERO, Vector2(180, 0), true, 72001)
    var early_lost := driver.observe_and_decide(6, Vector2.ZERO, Vector2(500, 0), false, 72001)
    _expect(bool(early_lost.get("accepted", false)) and not bool(early_lost.get("committed", false)), "lost sight before minimum reaction delay remains noncommitting")
    var lost := driver.observe_and_decide(12, Vector2.ZERO, Vector2(700, 0), false, 72001)
    var selection := lost.get("selection", {}) as Dictionary
    _expect(bool(lost.get("accepted", false)), "lost-sight evaluation remains legal while observation memory is alive")
    _expect(StringName(String(selection.get("tactic_id", &""))) == &"tactic:reposition_last_known", "lost sight uses last-known observation instead of invisible live pursuit")
    _expect(not bool(lost.get("committed", false)), "last-known movement intent cannot become an unseen signature attack")
    _expect(runtime.tactical_state_id == EnemyArchetypeRuntime.TACTICAL_REPOSITION, "last-known utility result maps to tactical Reposition")
    var snapshot := driver.memory.latest_for_source(runtime.target_id, 12, TUNING.confidence_decay_per_tick)
    _expect(Vector2(snapshot.get("observed_position", Vector2.ZERO)) == Vector2(180, 0), "memory retains last actually observed position rather than unseen target movement")

func _test_shared_observation_preserves_age_without_attack() -> void:
    var fixture := _fixture(&"duelist", &"encounter:decision_shared", &"enemy:decision_shared")
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var driver := fixture["driver"] as EnemyPrototypeDecisionDriver
    var blackboard := EncounterBlackboard.new()
    _expect(blackboard.configure(&"encounter:decision_shared"), "shared-observation fixture blackboard configures")
    _expect(blackboard.publish_observed_fact(
        runtime.target_id,
        Vector2(240, 16),
        EnemyPrototypeDecisionDriver.OBSERVED_TARGET_STATE,
        0,
        0.8,
        TUNING.observation_lifetime_ticks,
        0
    ), "blackboard accepts a justified shared sight fact")
    var shared := blackboard.latest_fact(runtime.target_id, 12, 0.0)
    _expect(driver.admit_shared_observation(shared, 12), "enemy admits shared observation without rewriting its source timestamp")
    var result := driver.observe_and_decide(12, Vector2.ZERO, Vector2(900, 900), false, 72501)
    var selection := result.get("selection", {}) as Dictionary
    _expect(bool(result.get("accepted", false)), "shared observation can inform a legal unseen-target decision")
    _expect(StringName(String(selection.get("tactic_id", &""))) == &"tactic:reposition_last_known", "shared observation permits only last-known reposition while target remains unseen")
    _expect(not bool(result.get("committed", false)), "shared observation cannot authorize an unseen signature attack")
    var snapshot := driver.memory.latest_for_source(runtime.target_id, 12, 0.0)
    _expect(StringName(String(snapshot.get("cue_id", &""))) == AiObservationAdmission.CUE_SHARED, "local memory retains shared-cue provenance")
    _expect(int(snapshot.get("observed_tick", -1)) == 0 and int(snapshot.get("age_ticks", -1)) == 12, "shared observation preserves original observation age")
    _expect(is_equal_approx(float(snapshot.get("confidence", -1.0)), 0.8), "shared observation preserves source confidence before local decay")

func _test_signature_fairness_facts_remain_enforced() -> void:
    var assassin_fixture := _fixture(&"assassin", &"encounter:decision_assassin", &"enemy:decision_assassin")
    var assassin := assassin_fixture["runtime"] as EnemyArchetypeRuntime
    var assassin_driver := assassin_fixture["driver"] as EnemyPrototypeDecisionDriver
    assassin_driver.observe_and_decide(0, Vector2.ZERO, Vector2(32, 0), true, 73001)
    assassin_driver.observe_and_decide(6, Vector2.ZERO, Vector2(32, 0), true, 73001)
    var no_flank := assassin_driver.observe_and_decide(12, Vector2.ZERO, Vector2(32, 0), true, 73001)
    _expect(not bool(no_flank.get("committed", false)), "Assassin cannot invent an observed flank from proximity alone")
    _expect(StringName(String((no_flank.get("selection", {}) as Dictionary).get("tactic_id", &""))) == &"tactic:hold_observe", "failed Assassin flank fairness check degrades to noncommitting observation")
    _expect(assassin.phase_id == EnemyArchetypeRuntime.PHASE_IDLE, "failed Assassin fairness check consumes no action phase")

    var summoner_fixture := _fixture(&"summoner", &"encounter:decision_summoner", &"enemy:decision_summoner")
    var summoner_driver := summoner_fixture["driver"] as EnemyPrototypeDecisionDriver
    summoner_driver.observe_and_decide(0, Vector2.ZERO, Vector2(300, 0), true, 74001)
    summoner_driver.observe_and_decide(6, Vector2.ZERO, Vector2(300, 0), true, 74001)
    var no_budget := summoner_driver.observe_and_decide(12, Vector2.ZERO, Vector2(300, 0), true, 74001)
    _expect(not bool(no_budget.get("committed", false)), "Summoner cannot fabricate reinforcement budget when no budget owner supplied one")

func _test_signature_repeat_suppression() -> void:
    var fixture := _fixture(&"duelist", &"encounter:decision_repeat_suppression", &"enemy:decision_repeat_duelist")
    var runtime := fixture["runtime"] as EnemyArchetypeRuntime
    var phase_driver := fixture["phase_driver"] as EnemySignatureActionPhaseDriver
    var driver := fixture["driver"] as EnemyPrototypeDecisionDriver

    driver.observe_and_decide(0, Vector2.ZERO, Vector2(32, 0), true, 75001)
    driver.observe_and_decide(6, Vector2.ZERO, Vector2(32, 0), true, 75001)
    var first := driver.observe_and_decide(12, Vector2.ZERO, Vector2(32, 0), true, 75001)
    _expect(bool(first.get("committed", false)), "repeat-suppression fixture commits the first otherwise-legal signature")
    _complete_signature_cycle(phase_driver, &"duelist")

    var second := driver.observe_and_decide(18, Vector2.ZERO, Vector2(32, 0), true, 75002)
    _expect(bool(second.get("committed", false)), "repeat-suppression fixture permits the second signature before the authored repeat limit")
    _complete_signature_cycle(phase_driver, &"duelist")

    var suppressed := driver.observe_and_decide(24, Vector2.ZERO, Vector2(32, 0), true, 75003)
    var suppressed_selection := suppressed.get("selection", {}) as Dictionary
    _expect(bool(suppressed.get("accepted", false)) and not bool(suppressed.get("committed", false)), "repeat-suppression evaluation remains a legal noncommitting AI decision")
    _expect(StringName(String(suppressed_selection.get("tactic_id", &""))) == &"tactic:hold_observe" and StringName(String(suppressed_selection.get("reason_id", &""))) == &"reason:signature_repeat_suppression", "two consecutive completed signatures suppress exactly the next otherwise-legal signature evaluation")
    _expect(runtime.phase_id == EnemyArchetypeRuntime.PHASE_IDLE and runtime.encounter.reservations.get_active_count() == 0, "repeat suppression consumes no action phase or reservation")

    var reopened := driver.observe_and_decide(30, Vector2.ZERO, Vector2(32, 0), true, 75003)
    _expect(bool(reopened.get("committed", false)), "signature eligibility returns after the configured suppression evaluation is consumed")

func _complete_signature_cycle(phase_driver: EnemySignatureActionPhaseDriver, archetype_id: StringName) -> void:
    var timing := EnemySignatureActionTimingCatalog.get_timing(archetype_id)
    var ticks := int(timing.get("windup_ticks", 0)) \
        + int(timing.get("active_ticks", 0)) \
        + int(timing.get("recovery_ticks", 0)) \
        + int(timing.get("cooldown_ticks", 0))
    for _index: int in range(ticks):
        _expect(phase_driver.advance_fixed_tick(), "repeat-suppression phase/cooldown tick advances")

func _fixture(archetype_id: StringName, encounter_id: StringName, enemy_id: StringName) -> Dictionary:
    var encounter := CombatEncounterRuntime.new()
    _expect(encounter.configure(encounter_id), "decision fixture encounter configures")
    var player := _combatant(&"player:decision_target")
    var enemy := _combatant(enemy_id)
    _expect(encounter.register_player(player) and encounter.register_enemy(enemy), "decision fixture registers player and enemy")
    var runtime := EnemyArchetypeRuntime.new()
    _expect(runtime.configure(encounter, enemy.actor_id, player.actor_id, archetype_id), "decision fixture archetype runtime configures")
    var phase_driver := EnemySignatureActionPhaseDriver.new()
    _expect(phase_driver.configure(runtime, EnemySignatureActionTimingCatalog.get_timing(archetype_id)), "decision fixture phase driver configures")
    var driver := EnemyPrototypeDecisionDriver.new()
    _expect(driver.configure(runtime, phase_driver, TUNING), "prototype decision driver configures")
    return {"encounter": encounter, "runtime": runtime, "phase_driver": phase_driver, "driver": driver}

func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 20.0, true, false, false), "%s combatant validates" % String(actor_id))
    return state

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
