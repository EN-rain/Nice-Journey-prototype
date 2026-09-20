extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(DangerEvaluator.evaluate_rank(10, 10) == DangerEvaluator.Rank.I, "deficit 0 maps to DANGER I")
    _expect(DangerEvaluator.evaluate_rank(4, 5) == DangerEvaluator.Rank.II, "deficit 1 maps to DANGER II")
    _expect(DangerEvaluator.evaluate_rank(3, 5) == DangerEvaluator.Rank.III, "deficit 2 maps to DANGER III")
    _expect(DangerEvaluator.evaluate_rank(2, 5) == DangerEvaluator.Rank.IV, "deficit 3 maps to DANGER IV")
    _expect(DangerEvaluator.evaluate_rank(1, 5) == DangerEvaluator.Rank.IV, "deficit 4 maps to DANGER IV")
    _expect(DangerEvaluator.evaluate_rank(1, 6) == DangerEvaluator.Rank.V, "deficit 5 maps to DANGER V")
    _expect(DangerEvaluator.evaluate_rank(10, 1) == DangerEvaluator.Rank.I, "overleveled content remains DANGER I, not a hidden lower rank")
    _expect(not DangerEvaluator.requires_explicit_travel_confirmation(DangerEvaluator.Rank.II), "DANGER II does not require the III-V explicit travel confirmation")
    _expect(DangerEvaluator.requires_explicit_travel_confirmation(DangerEvaluator.Rank.III), "DANGER III requires explicit menu-travel confirmation")
    _expect(DangerEvaluator.requires_explicit_travel_confirmation(DangerEvaluator.Rank.V), "DANGER V requires explicit menu-travel confirmation")
    _expect(DangerEvaluator.display_name(DangerEvaluator.Rank.V) == "DANGER V - Catastrophic", "locked danger label is stable")

    if _failures == 0:
        print("DANGER TEST PASS")
    else:
        push_error("DANGER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
