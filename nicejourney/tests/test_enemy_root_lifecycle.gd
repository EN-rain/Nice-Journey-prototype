extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var lifecycle: EnemyRootLifecycle = EnemyRootLifecycle.new()
    _expect(lifecycle.get_state() == EnemyRootLifecycle.State.DORMANT, "enemy root lifecycle begins Dormant")
    _expect(not lifecycle.is_tactical_eligible() and not lifecycle.can_hold_group_reservation(), "Dormant actor cannot run tactics or hold a group reservation")
    _expect(lifecycle.get_transition_generation() == 0 and lifecycle.get_last_transition_reason_id() == &"", "initial lifecycle has no fabricated transition history")

    _expect(not lifecycle.request_transition(EnemyRootLifecycle.State.DEFEATED, &"encounter:skip"), "Dormant cannot skip directly to Defeated")
    _expect(not lifecycle.request_transition(EnemyRootLifecycle.State.ACTIVE, &"bad reason"), "malformed transition reason is rejected")
    _expect(lifecycle.get_state() == EnemyRootLifecycle.State.DORMANT and lifecycle.get_transition_generation() == 0, "rejected transition leaves source lifecycle unchanged")

    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "external encounter owner can activate a Dormant actor")
    _expect(lifecycle.is_tactical_eligible() and lifecycle.can_hold_group_reservation(), "only Active lifecycle is tactically and reservation eligible")
    _expect(lifecycle.get_transition_generation() == 1 and lifecycle.get_last_transition_reason_id() == &"encounter:activate", "accepted transition records explicit reason and generation")

    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.DEFEATED, &"encounter:defeated"), "Active actor can enter Defeated root state")
    _expect(not lifecycle.is_tactical_eligible() and not lifecycle.can_hold_group_reservation(), "Defeated actor cannot run tactics or retain group-reservation eligibility")
    var defeated_generation: int = lifecycle.get_transition_generation()
    _expect(not lifecycle.request_transition(EnemyRootLifecycle.State.ACTIVE, &"utility:resurrect"), "Defeated actor cannot be resurrected directly by a tactical or utility transition")
    _expect(lifecycle.get_state() == EnemyRootLifecycle.State.DEFEATED and lifecycle.get_transition_generation() == defeated_generation, "rejected Defeated-to-Active transition cannot mutate lifecycle history")

    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.RETURNING, &"encounter:return_authorized"), "caller may explicitly enter the locked Returning lifecycle without choosing when replay/death uses it")
    _expect(not lifecycle.is_tactical_eligible() and not lifecycle.can_hold_group_reservation(), "Returning remains ineligible for tactics/reservations until explicitly Active")
    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.DORMANT, &"encounter:return_staged"), "Returning actor can be staged Dormant without auto-activating")
    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:reactivate"), "caller may explicitly reactivate a staged actor")

    var snapshot: Dictionary = lifecycle.get_debug_snapshot()
    _expect(StringName(snapshot.get("state_name", &"")) == &"ACTIVE", "debug snapshot exposes readable root lifecycle")
    _expect(bool(snapshot.get("tactical_eligible", false)) and bool(snapshot.get("group_reservation_eligible", false)), "debug snapshot exposes eligibility derived from the root state")
    var generation_before_snapshot_mutation: int = lifecycle.get_transition_generation()
    snapshot["state_name"] = &"DEFEATED"
    snapshot["transition_generation"] = -1
    _expect(lifecycle.get_state() == EnemyRootLifecycle.State.ACTIVE and lifecycle.get_transition_generation() == generation_before_snapshot_mutation, "mutating detached debug snapshot cannot mutate lifecycle source")

    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.RESOLVED, &"encounter:resolved"), "external encounter owner can finalize an Active actor as Resolved")
    _expect(not lifecycle.is_tactical_eligible() and not lifecycle.can_hold_group_reservation(), "Resolved actor cannot run tactics or hold reservations")
    var resolved_generation: int = lifecycle.get_transition_generation()
    _expect(not lifecycle.request_transition(EnemyRootLifecycle.State.RETURNING, &"encounter:reopen"), "Resolved root state is terminal in this instance and cannot be silently reopened")
    _expect(lifecycle.get_state() == EnemyRootLifecycle.State.RESOLVED and lifecycle.get_transition_generation() == resolved_generation, "rejected Resolved transition leaves source state unchanged")

    var defeated_to_resolved: EnemyRootLifecycle = EnemyRootLifecycle.new()
    _expect(defeated_to_resolved.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "second fixture activates")
    _expect(defeated_to_resolved.request_transition(EnemyRootLifecycle.State.DEFEATED, &"encounter:defeated"), "second fixture defeats")
    _expect(defeated_to_resolved.request_transition(EnemyRootLifecycle.State.RESOLVED, &"encounter:resolved"), "Defeated may be finalized directly as Resolved by the external encounter owner")
    _expect(not defeated_to_resolved.is_tactical_eligible(), "finalized defeated fixture remains tactically ineligible")

    var dormant_to_resolved: EnemyRootLifecycle = EnemyRootLifecycle.new()
    _expect(dormant_to_resolved.request_transition(EnemyRootLifecycle.State.RESOLVED, &"encounter:retired"), "Dormant actor may be finalized directly as Resolved without becoming tactically active")

    var active_to_dormant: EnemyRootLifecycle = EnemyRootLifecycle.new()
    _expect(active_to_dormant.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "matrix fixture activates before explicit dormancy")
    _expect(active_to_dormant.request_transition(EnemyRootLifecycle.State.DORMANT, &"encounter:dormant"), "Active actor may return to Dormant through an explicit encounter-owner transition")
    _expect(not active_to_dormant.is_tactical_eligible(), "explicit Active-to-Dormant transition removes tactical eligibility")

    var returning_to_active: EnemyRootLifecycle = EnemyRootLifecycle.new()
    _expect(returning_to_active.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "return-to-active fixture activates")
    _expect(returning_to_active.request_transition(EnemyRootLifecycle.State.DEFEATED, &"encounter:defeated"), "return-to-active fixture defeats")
    _expect(returning_to_active.request_transition(EnemyRootLifecycle.State.RETURNING, &"encounter:return_authorized"), "return-to-active fixture enters Returning explicitly")
    _expect(returning_to_active.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:return_active"), "Returning may become Active only through an explicit caller transition")

    var returning_to_resolved: EnemyRootLifecycle = EnemyRootLifecycle.new()
    _expect(returning_to_resolved.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "return-to-resolved fixture activates")
    _expect(returning_to_resolved.request_transition(EnemyRootLifecycle.State.DEFEATED, &"encounter:defeated"), "return-to-resolved fixture defeats")
    _expect(returning_to_resolved.request_transition(EnemyRootLifecycle.State.RETURNING, &"encounter:return_authorized"), "return-to-resolved fixture enters Returning explicitly")
    _expect(returning_to_resolved.request_transition(EnemyRootLifecycle.State.RESOLVED, &"encounter:resolved"), "Returning may be finalized as Resolved without auto-activation")

    var same_state_generation: int = returning_to_resolved.get_transition_generation()
    _expect(not returning_to_resolved.request_transition(EnemyRootLifecycle.State.RESOLVED, &"encounter:duplicate"), "same-state lifecycle requests are rejected")
    _expect(returning_to_resolved.get_transition_generation() == same_state_generation, "same-state rejection cannot advance lifecycle history")

    if _failures == 0:
        print("ENEMY ROOT LIFECYCLE TEST PASS")
    else:
        push_error("ENEMY ROOT LIFECYCLE TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
