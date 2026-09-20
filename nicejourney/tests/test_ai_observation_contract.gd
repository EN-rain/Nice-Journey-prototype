extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var memory: AiObservationMemory = AiObservationMemory.new(2)

    _expect(not memory.record_observation(&"", &"actor:player", Vector2.ZERO, &"idle", 0, 1.0, 10), "empty cue is rejected")
    _expect(not memory.record_observation(&"sight", &"actor:player", Vector2.ZERO, &"idle", 0, 1.1, 10), "out-of-range confidence is rejected")
    _expect(not memory.record_observation(&"sight", &"actor:player", Vector2.ZERO, &"idle", 0, NAN, 10), "non-finite confidence is rejected")
    _expect(not memory.record_observation(&"sight", &"actor:player", Vector2(INF, 0.0), &"idle", 0, 1.0, 10), "non-finite observed position is rejected")

    _expect(memory.record_observation(&"cast", &"actor:player", Vector2(12, 8), &"casting", 10, 0.9, 20), "observed cue is recorded")
    var remembered: Dictionary = memory.latest_for_source(&"actor:player", 15, 0.05)
    _expect(Vector2(remembered.get("observed_position", Vector2.ZERO)) == Vector2(12, 8), "last-known position remains the observed position instead of following unseen live movement")
    _expect(StringName(remembered.get("observed_state", &"")) == &"casting", "last-known state is the observed state")
    _expect(int(remembered.get("age_ticks", -1)) == 5, "observation age is explicit")
    _expect(is_equal_approx(float(remembered.get("confidence", -1.0)), 0.65), "confidence decay is caller-authored and deterministic")
    _expect(memory.latest_for_source(&"actor:player", 15, NAN).is_empty(), "non-finite confidence decay is rejected")
    _expect(not memory.can_react_to(remembered, 15, 6), "reaction cannot occur before observation tick plus authored delay")
    _expect(memory.can_react_to(remembered, 16, 6), "reaction becomes eligible exactly at the authored delay boundary")
    _expect(not memory.can_react_to(remembered, 30, 6), "expired observed facts cannot authorize a delayed reaction")

    remembered["observed_position"] = Vector2(999, 999)
    var remembered_again: Dictionary = memory.latest_for_source(&"actor:player", 15)
    _expect(Vector2(remembered_again.get("observed_position", Vector2.ZERO)) == Vector2(12, 8), "debug/read snapshots cannot mutate stored observed facts")
    _expect(not remembered_again.has("raw_input") and not remembered_again.has("live_target"), "observation surface exposes facts rather than raw input or a live target handle")

    _expect(memory.record_observation(&"move", &"actor:ally", Vector2(1, 1), &"moving", 11, 0.8, 30), "second source can be observed")
    _expect(memory.record_observation(&"move", &"actor:rival", Vector2(2, 2), &"moving", 12, 0.7, 30), "bounded memory accepts a newer observation")
    _expect(memory.size() == 2, "memory remains bounded to its authored capacity")
    _expect(memory.latest_for_source(&"actor:player", 15).is_empty(), "oldest observation is evicted when bounded capacity is exceeded")

    _expect(memory.record_observation(&"shared", &"actor:rival", Vector2(-5, -5), &"older_shared_fact", 9, 0.4, 30), "older shared facts may arrive later without becoming newer facts")
    var rival_latest: Dictionary = memory.latest_for_source(&"actor:rival", 15)
    _expect(Vector2(rival_latest.get("observed_position", Vector2.ZERO)) == Vector2(2, 2), "late delivery preserves the most recent observation timestamp")
    _expect(memory.size() == 2, "late older facts do not grow bounded memory")

    var shared_memory: AiObservationMemory = AiObservationMemory.new(2)
    _expect(shared_memory.record_observation(&"shared", &"actor:rival", Vector2(4, 4), &"shared_fact", 4, 0.75, 20), "shared facts retain their original observation metadata")
    var shared_fact: Dictionary = shared_memory.latest_for_source(&"actor:rival", 10, 0.05)
    _expect(int(shared_fact.get("age_ticks", -1)) == 6, "shared-fact age is measured from the original observation time")
    _expect(is_equal_approx(float(shared_fact.get("confidence", -1.0)), 0.45), "shared-fact uncertainty decays from the shared observation confidence")

    _expect(memory.record_observation(&"sight", &"actor:player", Vector2(20, 20), &"idle", 20, 1.0, 5), "source can be observed again after eviction")
    _expect(not memory.latest_for_source(&"actor:player", 24).is_empty(), "observation remains available before expiry")
    _expect(memory.latest_for_source(&"actor:player", 25).is_empty(), "observation expires at its declared expiry boundary")
    _expect(memory.purge_expired(50) == 2 and memory.size() == 0, "expired observations can be purged without encounter-policy assumptions")

    memory.record_observation(&"sight", &"actor:player", Vector2.ZERO, &"idle", 60, 1.0, 10)
    memory.clear()
    _expect(memory.size() == 0, "memory reset is explicit and does not choose an encounter reset policy")

    if _failures == 0:
        print("AI OBSERVATION CONTRACT TEST PASS")
    else:
        push_error("AI OBSERVATION CONTRACT TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
