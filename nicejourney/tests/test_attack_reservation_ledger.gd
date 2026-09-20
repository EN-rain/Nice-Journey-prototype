extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var ledger: AttackReservationLedger = AttackReservationLedger.new()
    _expect(ledger.get_active_count() == 0, "attack reservation ledger starts empty")

    _expect(ledger.try_reserve(&"", &"player:1", &"encounter:a", 1) == 0, "empty actor identity is rejected")
    _expect(ledger.try_reserve(&"enemy:1", &"bad target", &"encounter:a", 1) == 0, "malformed target identity is rejected")
    _expect(ledger.try_reserve(&"enemy:1", &"player:1", &"bad encounter", 1) == 0, "malformed encounter identity is rejected")
    _expect(ledger.try_reserve(&"enemy:1", &"player:1", &"encounter:a", 0) == 0, "non-positive action-instance identity is rejected")
    _expect(ledger.get_active_count() == 0, "rejected reservations cannot mutate the ledger")

    var first: int = ledger.try_reserve(&"enemy:1", &"player:1", &"encounter:a", 11)
    var second: int = ledger.try_reserve(&"enemy:2", &"player:1", &"encounter:a", 12)
    var third: int = ledger.try_reserve(&"enemy:3", &"player:2", &"encounter:b", 13)
    _expect(first > 0 and second > first and third > second, "valid attack reservations receive unique monotonic tokens")
    _expect(ledger.get_active_count() == 3, "reservations compose without choosing a pressure cap")
    _expect(ledger.has_reservation(&"enemy:1", 11), "actor/action reservation identity is queryable")
    _expect(ledger.matches_reservation(first, &"enemy:1", &"player:1", &"encounter:a", 11), "exact reservation token ownership is queryable without exposing mutable ledger state")
    _expect(not ledger.matches_reservation(first, &"enemy:1", &"player:2", &"encounter:a", 11), "reservation ownership query rejects a mismatched target")

    _expect(ledger.try_reserve(&"enemy:1", &"player:1", &"encounter:a", 11) == 0, "duplicate actor/action reservation is rejected")
    _expect(ledger.try_reserve(&"enemy:1", &"player:2", &"encounter:b", 11) == 0, "existing actor/action identity cannot silently remap target or encounter")
    _expect(ledger.get_active_count() == 3, "duplicate or remap attempts cannot double-count reservations")

    _expect(not ledger.release(first, &"distance_only"), "unlocked release reasons are rejected")
    _expect(ledger.has_reservation(&"enemy:1", 11), "rejected release cannot mutate reservation state")
    _expect(ledger.release(first, AttackReservationLedger.RELEASE_COMPLETION), "action completion releases its reservation explicitly")
    _expect(not ledger.matches_reservation(first, &"enemy:1", &"player:1", &"encounter:a", 11), "released token no longer reports reservation ownership")
    _expect(not ledger.release(first, AttackReservationLedger.RELEASE_COMPLETION), "duplicate token release is a safe no-op")
    _expect(not ledger.has_reservation(&"enemy:1", 11) and ledger.get_active_count() == 2, "completed reservation releases exactly once")

    var cancelled: int = ledger.try_reserve(&"enemy:1", &"player:1", &"encounter:a", 21)
    _expect(cancelled > 0 and ledger.release(cancelled, AttackReservationLedger.RELEASE_CANCELLATION), "authored cancellation releases an individual reservation")
    var interrupted: int = ledger.try_reserve(&"enemy:1", &"player:1", &"encounter:a", 22)
    _expect(interrupted > 0 and ledger.release(interrupted, AttackReservationLedger.RELEASE_INTERRUPTION), "interruption releases an individual reservation")

    var death_a: int = ledger.try_reserve(&"enemy:dead", &"player:1", &"encounter:a", 31)
    var death_b: int = ledger.try_reserve(&"enemy:dead", &"player:2", &"encounter:b", 32)
    _expect(death_a > 0 and death_b > 0, "one actor may hold distinct action-instance reservations without a pressure-policy assumption")
    _expect(ledger.release_actor(&"enemy:dead", AttackReservationLedger.RELEASE_CANCELLATION) == 0, "actor bulk release requires the death lifecycle reason")
    _expect(ledger.release_actor(&"enemy:dead", AttackReservationLedger.RELEASE_DEATH) == 2, "death releases all reservations owned by that actor")

    var target_a: int = ledger.try_reserve(&"enemy:4", &"player:gone", &"encounter:a", 41)
    var target_b: int = ledger.try_reserve(&"enemy:5", &"player:gone", &"encounter:b", 42)
    _expect(target_a > 0 and target_b > 0, "multiple actors may reserve the same target without inventing a pressure cap")
    _expect(ledger.release_target(&"player:gone", AttackReservationLedger.RELEASE_TARGET_INVALIDATION) == 2, "target invalidation releases every reservation for that target")

    var exit_a: int = ledger.try_reserve(&"enemy:6", &"player:1", &"encounter:exit", 51)
    var exit_b: int = ledger.try_reserve(&"enemy:7", &"player:2", &"encounter:exit", 52)
    var retained: int = ledger.try_reserve(&"enemy:8", &"player:2", &"encounter:stay", 53)
    _expect(exit_a > 0 and exit_b > 0 and retained > 0, "encounter-exit fixture admits independent reservations")
    _expect(ledger.release_encounter(&"encounter:exit", AttackReservationLedger.RELEASE_ENCOUNTER_EXIT) == 2, "encounter exit releases only reservations owned by that encounter")
    _expect(ledger.has_reservation(&"enemy:8", 53), "encounter cleanup cannot clear another encounter's reservation")

    var snapshot: Dictionary = ledger.get_debug_snapshot(1)
    var records: Array = snapshot.get("reservations", []) as Array
    _expect(int(snapshot.get("active_count", -1)) == ledger.get_active_count(), "debug snapshot reports truthful total reservation count")
    _expect(records.size() == 1, "debug reservation enumeration is bounded by the requested maximum")
    if not records.is_empty():
        (records[0] as Dictionary)["actor_id"] = &"mutated"
    records.clear()
    snapshot["active_count"] = 0
    _expect(ledger.has_reservation(&"enemy:8", 53), "mutating detached debug data cannot mutate reservation state")

    _expect(ledger.release(retained, AttackReservationLedger.RELEASE_ENCOUNTER_EXIT), "individual encounter-exit cleanup may release the remaining reservation")
    _expect(ledger.release(second, AttackReservationLedger.RELEASE_DEATH), "individual death cleanup is accepted")
    _expect(ledger.release(third, AttackReservationLedger.RELEASE_TARGET_INVALIDATION), "individual target-invalidation cleanup is accepted")
    _expect(ledger.get_active_count() == 0, "all explicit lifecycle releases return the reservation ledger to empty")

    if _failures == 0:
        print("ATTACK RESERVATION LEDGER TEST PASS")
    else:
        push_error("ATTACK RESERVATION LEDGER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
