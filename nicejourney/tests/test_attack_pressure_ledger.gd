extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_global_capacity_and_release_scopes()
    if _failures == 0:
        print("ATTACK PRESSURE LEDGER TEST PASS")
    else:
        push_error("ATTACK PRESSURE LEDGER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_global_capacity_and_release_scopes() -> void:
    var ledger := AttackPressureLedger.new(3)
    var a := ledger.try_admit(&"enemy:pressure_a", &"player:pressure", &"encounter:pressure_a", 1)
    var b := ledger.try_admit(&"enemy:pressure_b", &"player:pressure", &"encounter:pressure_a", 2)
    var c := ledger.try_admit(&"enemy:pressure_c", &"player:pressure", &"encounter:pressure_b", 3)
    _expect(a > 0 and b > 0 and c > 0, "shared pressure ledger admits committed attacks up to authored capacity across encounters")
    _expect(ledger.matches_commitment(a, &"enemy:pressure_a", &"player:pressure", &"encounter:pressure_a", 1), "exact committed-pressure token ownership is queryable")
    _expect(not ledger.matches_commitment(a, &"enemy:pressure_a", &"player:pressure", &"encounter:pressure_b", 1), "pressure ownership query rejects a mismatched encounter")
    _expect(ledger.get_active_count() == 3 and not ledger.has_capacity(), "shared pressure budget becomes saturated at its configured cap")
    _expect(ledger.try_admit(&"enemy:pressure_d", &"player:pressure", &"encounter:pressure_b", 4) == 0, "fourth simultaneous committed attack is rejected even from an overlapping encounter")
    _expect(ledger.try_admit(&"enemy:pressure_a", &"player:pressure", &"encounter:pressure_a", 1) == 0, "duplicate actor/action commitment cannot double-count pressure")
    _expect(ledger.release(a, AttackReservationLedger.RELEASE_COMPLETION), "completion releases one pressure slot")
    _expect(not ledger.matches_commitment(a, &"enemy:pressure_a", &"player:pressure", &"encounter:pressure_a", 1), "released pressure token no longer reports ownership")
    _expect(ledger.has_capacity(), "released pressure capacity becomes available again")
    var d := ledger.try_admit(&"enemy:pressure_d", &"player:pressure", &"encounter:pressure_b", 4)
    _expect(d > 0 and ledger.get_active_count() == 3, "new commitment can use explicitly released pressure capacity")
    _expect(ledger.release_actor(&"enemy:pressure_b", AttackReservationLedger.RELEASE_DEATH) == 1, "death releases only the defeated actor pressure ownership")
    _expect(ledger.release_encounter(&"encounter:pressure_b", AttackReservationLedger.RELEASE_ENCOUNTER_EXIT) == 2, "encounter exit releases only remaining commitments from that encounter")
    _expect(ledger.get_active_count() == 0, "scoped release paths leave no pressure leak")

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
