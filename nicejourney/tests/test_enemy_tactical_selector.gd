extends SceneTree
var failures := 0
func _init() -> void:
    call_deferred(&"_run")
func _run() -> void:
    var duelist := EnemyArchetypeCatalog.get_first_slice(&"duelist")
    _check(EnemyTacticalSelector.select_tactic(duelist, _ctx(&"close", true, false, true, true, false, true))["tactic_id"] == &"tactic:hold_observe", "reaction delay holds")
    _check(EnemyTacticalSelector.select_tactic(duelist, _ctx(&"mid", false, true, true, true, false, false, 0.5))["tactic_id"] == &"tactic:reposition_last_known", "lost sight uses last-known")
    _check(EnemyTacticalSelector.select_tactic(duelist, _ctx(&"long", true, true, true, true, false, false))["tactic_id"] == &"tactic:approach", "duelist approaches")
    var marksman := EnemyArchetypeCatalog.get_first_slice(&"marksman")
    _check(EnemyTacticalSelector.select_tactic(marksman, _ctx(&"close", true, true, true, true, false, false))["tactic_id"] == &"tactic:withdraw", "marksman withdraws")
    _check(EnemyTacticalSelector.select_tactic(marksman, _ctx(&"long", true, true, true, true, false, true))["tactic_id"] == marksman.signature_action_id, "marksman uses authored commitment")
    if failures == 0: print("ENEMY TACTICAL SELECTOR TEST PASS")
    quit(failures)
func _ctx(distance: StringName, visible: bool, ready: bool, reservation: bool, cooldown: bool, objective: bool, recovering: bool, confidence := 1.0) -> Dictionary:
    return {"distance_band":distance,"target_visible":visible,"reaction_delay_satisfied":ready,"reservation_available":reservation,"cooldown_ready":cooldown,"objective_contested":objective,"observed_player_recovering":recovering,"observed_player_committed":false,"observation_confidence":confidence,"observation_age_ticks":0}
func _check(ok: bool, label: String) -> void:
    if ok: print("PASS: %s" % label)
    else:
        failures += 1
        push_error("FAIL: %s" % label)
