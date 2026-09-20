extends SceneTree

const BOSS_PLAYTEST: TenthWardenProductionAuthoring = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_playtest_v01.tres")
const ENCOUNTER_TUNING: TenthWardenEncounterTuning = preload("res://src/enemies/boss_tenth_warden/runtime/tenth_warden_encounter_default.tres")
var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var player := CombatantRuntimeState.new()
    var boss := BOSS_PLAYTEST.build_boss_state()
    var encounter := CombatEncounterRuntime.new()
    _expect(player.configure(&"player:warden_tick_test", 200, 100.0, 0.0, 0.0, 10.0, true, true, true), "tick test player configures")
    _expect(boss != null and encounter.configure(&"encounter:warden_tick_test")
        and encounter.register_player(player) and encounter.register_enemy(boss), "single boss and player share live encounter ownership")
    var runtime := TenthWardenCombatRuntime.new()
    var controller := TenthWardenEncounterController.new()
    if boss == null or not runtime.configure(encounter, player.actor_id, boss.actor_id, ENCOUNTER_TUNING) or not controller.configure(runtime, BOSS_PLAYTEST):
        _expect(false, "boss action clock and contact owner configure")
        encounter.end_encounter()
        quit(_failures)
        return
    _expect(controller.advance_fixed_tick(false), "first approved move begins")
    for tick: int in 60:
        if controller.action_machine.get_phase() == ActionStateMachine.Phase.ACTIVE:
            break
        controller.advance_fixed_tick(false)
    var machine := controller.action_machine
    _expect(machine.get_current_action_id() == TenthWardenEncounterState.MOVE_TWIN_CUT
        and machine.get_phase() == ActionStateMachine.Phase.ACTIVE
        and machine.get_phase_elapsed_ticks() == 0, "Twin Cut enters ACTIVE at the first clock tick")
    var attack := BOSS_PLAYTEST.attack_for_move(TenthWardenEncounterState.MOVE_TWIN_CUT)
    var facts := {
        "actor_id": boss.actor_id,
        "target_id": player.actor_id,
        "action_id": TenthWardenEncounterState.MOVE_TWIN_CUT,
        "action_instance_id": machine.get_current_instance_id(),
        "hit_interval_index": 0,
        "geometry_id": attack.geometry.geometry_id,
        "contact_confirmed": true,
        "critical_triggered": false,
        "weak_point_triggered": false,
    }
    var initial_hp := player.current_hp
    var early := controller.resolve_authored_contact(facts, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not bool(early.get("accepted", false))
        and early.get("reason_id", &"") == TenthWardenEncounterController.REASON_HIT_INTERVAL_NOT_SCHEDULED
        and player.current_hp == initial_hp, "authenticated geometry cannot deliver first Twin Cut hit before its Inspector-authored tick")
    controller.advance_fixed_tick(false)
    var first := controller.resolve_authored_contact(facts, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(first.get("accepted", false)) and player.current_hp < initial_hp, "first Twin Cut hit resolves on its scheduled active tick")
    facts["hit_interval_index"] = 1
    var hp_after_first := player.current_hp
    var premature_second := controller.resolve_authored_contact(facts, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(not bool(premature_second.get("accepted", false))
        and premature_second.get("reason_id", &"") == TenthWardenEncounterController.REASON_HIT_INTERVAL_NOT_SCHEDULED
        and player.current_hp == hp_after_first, "second Twin Cut hit cannot be pulled forward to the first interval")
    for tick: int in 4:
        controller.advance_fixed_tick(false)
    _expect(machine.get_phase_elapsed_ticks() == 5, "second Inspector hit interval is reached in ACTIVE")
    var second := controller.resolve_authored_contact(facts, false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(second.get("accepted", false)) and player.current_hp < hp_after_first,
        "second Twin Cut hit resolves at its separate authored interval")
    controller.reset()
    runtime.end_encounter()
    if _failures == 0:
        print("TENTH WARDEN CONTACT TICK ADMISSION TEST PASS")
    else:
        push_error("TENTH WARDEN CONTACT TICK ADMISSION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, label: String) -> void:
    if condition:
        print("PASS: %s" % label)
    else:
        _failures += 1
        push_error("FAIL: %s" % label)
