extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var admission: AttackParticipationAdmission = AttackParticipationAdmission.new()
    var full_ai: FullAiSimulationLedger = FullAiSimulationLedger.new()
    var reservations: AttackReservationLedger = AttackReservationLedger.new()
    var lifecycle: EnemyRootLifecycle = EnemyRootLifecycle.new()

    _expect(
        admission.try_admit(lifecycle, full_ai, reservations, &"enemy:1", &"player:1", &"encounter:a", 1) == 0,
        "Dormant lifecycle cannot enter attack participation"
    )
    _expect(_sources_unchanged(lifecycle, full_ai, reservations, EnemyRootLifecycle.State.DORMANT, 0, 0), "Dormant rejection cannot mutate source boundaries")

    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "fixture lifecycle activates explicitly")
    _expect(
        admission.try_admit(lifecycle, full_ai, reservations, &"enemy:1", &"player:1", &"encounter:a", 2) == 0,
        "Active actor without FULL-AI membership cannot reserve an attack"
    )
    _expect(_sources_unchanged(lifecycle, full_ai, reservations, EnemyRootLifecycle.State.ACTIVE, 0, 0), "missing FULL-AI rejection cannot mutate lifecycle, simulation, or reservations")

    _expect(full_ai.try_admit(&"enemy:1", &"encounter:a"), "fixture actor acquires FULL-AI membership for encounter A")
    _expect(
        admission.try_admit(lifecycle, full_ai, reservations, &"enemy:1", &"player:1", &"encounter:b", 3) == 0,
        "same actor cannot participate through an encounter that does not own its FULL-AI admission"
    )
    _expect(_sources_unchanged(lifecycle, full_ai, reservations, EnemyRootLifecycle.State.ACTIVE, 1, 0), "encounter mismatch rejection cannot mutate any composed source")

    var first_token: int = admission.try_admit(lifecycle, full_ai, reservations, &"enemy:1", &"player:1", &"encounter:a", 4)
    _expect(first_token > 0, "Active same-encounter FULL-AI actor delegates to reservation admission")
    _expect(reservations.has_reservation(&"enemy:1", 4), "successful participation preserves actor/action reservation identity")
    _expect(full_ai.get_admitted_count() == 1 and lifecycle.get_state() == EnemyRootLifecycle.State.ACTIVE, "successful participation does not mutate lifecycle or FULL-AI membership")

    _expect(
        admission.try_admit(lifecycle, full_ai, reservations, &"enemy:1", &"player:1", &"encounter:a", 4) == 0,
        "duplicate actor/action participation is rejected by reservation delegation"
    )
    _expect(
        admission.try_admit(lifecycle, full_ai, reservations, &"enemy:1", &"player:2", &"encounter:a", 4) == 0,
        "existing actor/action participation cannot remap its target"
    )
    _expect(reservations.get_active_count() == 1 and reservations.has_reservation(&"enemy:1", 4), "duplicate/remap rejection preserves the original reservation only")

    _expect(reservations.release(first_token, AttackReservationLedger.RELEASE_COMPLETION), "fixture releases the delegated reservation")
    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.DEFEATED, &"encounter:defeated"), "fixture enters Defeated")
    _expect(_rejects_current_lifecycle(admission, lifecycle, full_ai, reservations, 5, "Defeated"), "Defeated lifecycle cannot participate")
    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.RETURNING, &"encounter:return_authorized"), "fixture enters Returning explicitly")
    _expect(_rejects_current_lifecycle(admission, lifecycle, full_ai, reservations, 6, "Returning"), "Returning lifecycle cannot participate")
    _expect(lifecycle.request_transition(EnemyRootLifecycle.State.RESOLVED, &"encounter:resolved"), "fixture enters Resolved")
    _expect(_rejects_current_lifecycle(admission, lifecycle, full_ai, reservations, 7, "Resolved"), "Resolved lifecycle cannot participate")

    var malformed_lifecycle: EnemyRootLifecycle = EnemyRootLifecycle.new()
    _expect(malformed_lifecycle.request_transition(EnemyRootLifecycle.State.ACTIVE, &"encounter:activate"), "malformed-input fixture activates")
    _expect(full_ai.try_admit(&"enemy:2", &"encounter:a"), "malformed-input fixture acquires same-encounter FULL-AI membership")
    _expect(
        admission.try_admit(malformed_lifecycle, full_ai, reservations, &"enemy:2", &"bad target", &"encounter:a", 8) == 0,
        "target identity validation remains delegated to the reservation ledger"
    )
    _expect(
        admission.try_admit(malformed_lifecycle, full_ai, reservations, &"enemy:2", &"player:1", &"encounter:a", 0) == 0,
        "action-instance validation remains delegated to the reservation ledger"
    )
    _expect(reservations.get_active_count() == 0 and full_ai.get_admitted_count() == 2 and malformed_lifecycle.get_state() == EnemyRootLifecycle.State.ACTIVE, "delegated identity rejection leaves every source boundary unchanged")

    if _failures == 0:
        print("ATTACK PARTICIPATION ADMISSION TEST PASS")
    else:
        push_error("ATTACK PARTICIPATION ADMISSION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _rejects_current_lifecycle(
    admission: AttackParticipationAdmission,
    lifecycle: EnemyRootLifecycle,
    full_ai: FullAiSimulationLedger,
    reservations: AttackReservationLedger,
    action_instance_id: int,
    _state_name: String
) -> bool:
    var state_before: EnemyRootLifecycle.State = lifecycle.get_state()
    var generation_before: int = lifecycle.get_transition_generation()
    var full_ai_before: int = full_ai.get_admitted_count()
    var reservations_before: int = reservations.get_active_count()
    var token: int = admission.try_admit(lifecycle, full_ai, reservations, &"enemy:1", &"player:1", &"encounter:a", action_instance_id)
    return token == 0 \
        and lifecycle.get_state() == state_before \
        and lifecycle.get_transition_generation() == generation_before \
        and full_ai.get_admitted_count() == full_ai_before \
        and reservations.get_active_count() == reservations_before

func _sources_unchanged(
    lifecycle: EnemyRootLifecycle,
    full_ai: FullAiSimulationLedger,
    reservations: AttackReservationLedger,
    expected_state: EnemyRootLifecycle.State,
    expected_full_ai_count: int,
    expected_reservation_count: int
) -> bool:
    return lifecycle.get_state() == expected_state \
        and full_ai.get_admitted_count() == expected_full_ai_count \
        and reservations.get_active_count() == expected_reservation_count

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
