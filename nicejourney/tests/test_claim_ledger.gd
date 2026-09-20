extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var ledger: ClaimLedger = ClaimLedger.new()
    _expect(not ledger.is_claimed(&"reward:quest_01"), "new claim ledger starts unclaimed")
    _expect(ledger.try_claim(&"reward:quest_01", &"quest:01"), "first valid claim commits")
    _expect(ledger.is_claimed(&"reward:quest_01"), "committed claim becomes visible")
    _expect(ledger.get_source_id(&"reward:quest_01") == &"quest:01", "claim preserves its source identity")
    _expect(not ledger.try_claim(&"reward:quest_01", &"quest:01"), "duplicate claim is rejected")
    _expect(not ledger.try_claim(&"bad claim", &"quest:01"), "invalid claim IDs are rejected")
    _expect(not ledger.try_claim(&"reward:quest_02", &"bad source"), "invalid source IDs are rejected")

    var snapshot: Dictionary = ledger.to_dictionary()
    var restored: ClaimLedger = ClaimLedger.new()
    var restore_errors: PackedStringArray = restored.load_dictionary(snapshot)
    _expect(restore_errors.is_empty(), "valid claim ledger snapshot restores")
    _expect(restored.is_claimed(&"reward:quest_01"), "restored ledger preserves one-shot ownership")

    var malformed: Dictionary = {"bad claim": {"source_id": "quest:01"}}
    var malformed_errors: PackedStringArray = restored.load_dictionary(malformed)
    _expect(not malformed_errors.is_empty(), "malformed persistent claim data is rejected")
    _expect(restored.is_claimed(&"reward:quest_01"), "failed ledger load leaves prior valid state unchanged")

    if _failures == 0:
        print("CLAIM LEDGER TEST PASS")
    else:
        push_error("CLAIM LEDGER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
