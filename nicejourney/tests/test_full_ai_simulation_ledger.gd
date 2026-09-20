extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var ledger: FullAiSimulationLedger = FullAiSimulationLedger.new()
    _expect(FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS == 12, "full-AI hard cap matches master §23")
    _expect(ledger.get_admitted_count() == 0, "full-AI ledger starts empty")

    _expect(not ledger.try_admit(&"", &"encounter:a"), "empty actor ID is rejected")
    _expect(not ledger.try_admit(&"actor:bad id", &"encounter:a"), "malformed actor ID is rejected")
    _expect(not ledger.try_admit(&"actor:valid", &""), "empty encounter ID is rejected")
    _expect(not ledger.try_admit(&"actor:valid", &"encounter:bad id"), "malformed encounter ID is rejected")
    _expect(ledger.get_admitted_count() == 0, "invalid admissions do not change global accounting")

    for index: int in range(6):
        _expect(
            ledger.try_admit(StringName("actor:a:%02d" % index), &"encounter:a"),
            "encounter A admits FULL-AI actor %d" % (index + 1)
        )
    _expect(ledger.get_admitted_count() == 6, "first encounter contributes six actors to the shared ledger")

    _expect(not ledger.try_admit(&"actor:a:00", &"encounter:a"), "duplicate actor admission is rejected")
    _expect(not ledger.try_admit(&"actor:a:00", &"encounter:b"), "same actor cannot be double-counted through another encounter")
    _expect(ledger.get_admitted_count() == 6, "duplicate admissions cannot change the shared count")

    for index: int in range(6):
        _expect(
            ledger.try_admit(StringName("actor:b:%02d" % index), &"encounter:b"),
            "overlapping encounter B admits FULL-AI actor %d" % (index + 7)
        )
    _expect(ledger.get_admitted_count() == 12, "overlapping encounters share one global 12-actor FULL-AI cap")
    _expect(not ledger.try_admit(&"actor:c:00", &"encounter:c"), "13th FULL-AI combatant is rejected globally")
    _expect(ledger.get_admitted_count() == 12, "rejected 13th combatant does not change accounting")

    _expect(ledger.release(&"actor:a:02"), "explicit release frees one FULL-AI admission")
    _expect(not ledger.release(&"actor:a:02"), "releasing an already-released actor is a safe no-op")
    _expect(not ledger.release(&"actor:missing"), "releasing an unknown actor is a safe no-op")
    _expect(ledger.get_admitted_count() == 11, "duplicate or unknown release cannot under-count active FULL-AI actors")
    _expect(ledger.try_admit(&"actor:c:00", &"encounter:c"), "released FULL-AI capacity can be reused by another encounter")
    _expect(ledger.get_admitted_count() == 12 and ledger.is_admitted(&"actor:c:00"), "replacement admission restores the global count to 12")

    var snapshot: Dictionary = ledger.get_debug_snapshot()
    var admissions: Array = snapshot.get("admissions", []) as Array
    _expect(int(snapshot.get("active_count", -1)) == 12 and int(snapshot.get("hard_cap", -1)) == 12, "debug snapshot exposes current global accounting and locked cap")
    _expect(admissions.size() == 12, "debug snapshot enumerates each admitted actor once")
    _expect(_is_sorted_by_actor_id(admissions), "debug snapshot admission order is deterministic by stable actor ID")
    _expect(_contains_pair(admissions, &"actor:a:00", &"encounter:a") and _contains_pair(admissions, &"actor:b:00", &"encounter:b") and _contains_pair(admissions, &"actor:c:00", &"encounter:c"), "debug snapshot preserves cross-encounter actor ownership metadata")

    snapshot["active_count"] = 0
    if not admissions.is_empty():
        (admissions[0] as Dictionary)["actor_id"] = &"actor:mutated"
    admissions.clear()
    _expect(ledger.get_admitted_count() == 12 and ledger.is_admitted(&"actor:a:00"), "mutating detached debug data cannot change ledger accounting")

    if _failures == 0:
        print("FULL AI SIMULATION LEDGER TEST PASS")
    else:
        push_error("FULL AI SIMULATION LEDGER TEST FAILURES: %d" % _failures)
    quit(_failures)

func _is_sorted_by_actor_id(admissions: Array) -> bool:
    var prior: String = ""
    for admission_variant: Variant in admissions:
        if not admission_variant is Dictionary:
            return false
        var actor_id: String = String((admission_variant as Dictionary).get("actor_id", &""))
        if not prior.is_empty() and actor_id < prior:
            return false
        prior = actor_id
    return true

func _contains_pair(admissions: Array, actor_id: StringName, encounter_id: StringName) -> bool:
    for admission_variant: Variant in admissions:
        if not admission_variant is Dictionary:
            continue
        var admission: Dictionary = admission_variant as Dictionary
        if StringName(admission.get("actor_id", &"")) == actor_id and StringName(admission.get("encounter_id", &"")) == encounter_id:
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
