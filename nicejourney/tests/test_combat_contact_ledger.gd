extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var ledger: CombatContactLedger = CombatContactLedger.new()
    var action_instance_a: int = 101
    var action_instance_b: int = 102
    var target_a: StringName = &"enemy:test:a"
    var target_b: StringName = &"enemy:test:b"

    _expect(ledger.try_admit_contact(action_instance_a, target_a, 0), "first contact for an action-target interval is admitted")
    _expect(not ledger.try_admit_contact(action_instance_a, target_a, 0), "duplicate contact for the same action-target interval is rejected")
    _expect(ledger.try_admit_contact(action_instance_a, target_a, 1), "a distinct authored hit interval remains eligible for the same action and target")
    _expect(ledger.try_admit_contact(action_instance_a, target_b, 0), "different stable targets remain independent within one action instance")
    _expect(ledger.try_admit_contact(action_instance_b, target_a, 0), "the same target remains independent across action instances")
    _expect(not ledger.try_admit_contact(0, target_a, 0), "invalid action instance IDs are rejected")
    _expect(not ledger.try_admit_contact(action_instance_a, &"bad target", 0), "invalid stable target IDs are rejected")
    _expect(not ledger.try_admit_contact(action_instance_a, target_a, -1), "negative authored hit interval indexes are rejected")

    _expect(ledger.clear_action_instance(action_instance_a), "one action instance contact history can be cleared explicitly")
    _expect(not ledger.has_contact(action_instance_a, target_a, 0), "cleared action instance no longer retains its contacts")
    _expect(ledger.has_contact(action_instance_b, target_a, 0), "clearing one action instance cannot erase another instance's contact records")

    if _failures == 0:
        print("COMBAT CONTACT LEDGER TEST PASS")
    else:
        push_error("COMBAT CONTACT LEDGER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
