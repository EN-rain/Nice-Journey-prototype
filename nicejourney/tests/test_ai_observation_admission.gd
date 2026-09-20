extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var memory: AiObservationMemory = AiObservationMemory.new(4)
    var admission: AiObservationAdmission = AiObservationAdmission.new(memory)

    _expect(admission.admit_sight(&"actor:player", Vector2(12, 8), &"moving", 10, 0.9, 20, 10), "fixture sight cue is admitted")
    var sight: Dictionary = memory.latest_for_source(&"actor:player", 12)
    _expect(StringName(sight.get("cue_id", &"")) == AiObservationAdmission.CUE_SIGHT, "sight admission normalizes to the canonical cue identity")
    _expect(Vector2(sight.get("observed_position", Vector2.ZERO)) == Vector2(12, 8) and StringName(sight.get("observed_state", &"")) == &"moving", "admitted sight retains only the observed position and state")
    _expect(int(sight.get("observed_tick", -1)) == 10 and int(sight.get("lifetime_ticks", -1)) == 20 and int(sight.get("expiry_tick", -1)) == 30, "admitted sight carries original tick plus lifetime/expiry metadata")

    var unseen_live_position: Vector2 = Vector2(99, 99)
    var remembered_without_new_cue: Dictionary = memory.latest_for_source(&"actor:player", 13)
    _expect(unseen_live_position != Vector2(remembered_without_new_cue.get("observed_position", Vector2.ZERO)) and Vector2(remembered_without_new_cue.get("observed_position", Vector2.ZERO)) == Vector2(12, 8), "unseen movement cannot update last-known position without a new admitted cue")

    _expect(admission.admit_sound(&"actor:ally", Vector2(20, 5), &"attacking", 11, 0.8, 12, 11), "fixture sound cue is admitted")
    var sound: Dictionary = memory.latest_for_source(&"actor:ally", 12)
    _expect(StringName(sound.get("cue_id", &"")) == AiObservationAdmission.CUE_SOUND, "sound admission normalizes to the canonical cue identity")

    _expect(admission.admit_shared_fact(&"actor:rival", Vector2(4, 4), &"casting", 4, 0.6, 20, 10), "explicit shared fact may arrive later while still valid")
    var shared: Dictionary = memory.latest_for_source(&"actor:rival", 10)
    _expect(StringName(shared.get("cue_id", &"")) == AiObservationAdmission.CUE_SHARED, "shared admission normalizes to the canonical cue identity")
    _expect(int(shared.get("observed_tick", -1)) == 4 and int(shared.get("age_ticks", -1)) == 6, "shared fact preserves original observation time instead of refreshing to delivery time")
    _expect(is_equal_approx(float(shared.get("confidence", -1.0)), 0.6), "shared fact preserves original confidence instead of refreshing to certainty")
    _expect(int(shared.get("lifetime_ticks", -1)) == 20 and int(shared.get("expiry_tick", -1)) == 24, "shared fact preserves lifetime and expiry derived from the original observation")
    var decayed_shared: Dictionary = memory.latest_for_source(&"actor:rival", 10, 0.05)
    _expect(is_equal_approx(float(decayed_shared.get("confidence", -1.0)), 0.3), "shared-fact confidence decay is measured from original age")

    _expect(admission.admit_shared_fact(&"actor:stale", Vector2(1, 1), &"moving", 20, 0.5, 6, 24), "stale but still-valid shared fact can be admitted with original metadata")
    var stale_shared: Dictionary = memory.latest_for_source(&"actor:stale", 24)
    _expect(not memory.can_react_to(stale_shared, 26, 3), "expired shared fact cannot authorize reaction even if its authored delay has elapsed")

    var size_before_rejections: int = memory.size()
    _expect(not admission.admit_shared_fact(&"actor:expired", Vector2.ZERO, &"idle", 2, 0.5, 3, 5), "shared fact expired at admission is rejected deterministically")
    _expect(not admission.admit_sight(&"bad source", Vector2.ZERO, &"idle", 12, 1.0, 10, 12), "malformed source identity is rejected")
    _expect(not admission.admit_sound(&"actor:bad", Vector2(INF, 0), &"idle", 12, 1.0, 10, 12), "non-finite observed position is rejected at admission")
    _expect(not admission.admit_sound(&"actor:bad", Vector2.ZERO, &"idle", 12, NAN, 10, 12), "non-finite confidence is rejected at admission")
    _expect(not admission.admit_sight(&"actor:bad", Vector2.ZERO, &"", 12, 1.0, 10, 12), "missing observed state is rejected at admission")
    _expect(not admission.admit_sight(&"actor:future", Vector2.ZERO, &"idle", 13, 1.0, 10, 12), "future observation timestamp is rejected at admission")
    _expect(memory.size() == size_before_rejections, "malformed or expired facts cannot mutate observation memory")

    var debug_facts: Array[Dictionary] = memory.get_debug_observations(24, 4)
    _expect(debug_facts.size() <= 4, "admitted facts retain bounded debug enumeration")
    _expect(not _contains_forbidden_key(debug_facts), "admitted/debug facts expose no hidden/live/tactical/combat-resolution fields")

    if _failures == 0:
        print("AI OBSERVATION ADMISSION TEST PASS")
    else:
        push_error("AI OBSERVATION ADMISSION TEST FAILURES: %d" % _failures)
    quit(_failures)

func _contains_forbidden_key(value: Variant) -> bool:
    var forbidden: Array[String] = ["raw_input", "live_target", "current_hidden_state", "tactics", "threat", "damage", "defense", "attack_selection", "pursuit", "boss"]
    if value is Dictionary:
        for key: Variant in (value as Dictionary).keys():
            if forbidden.has(String(key)) or _contains_forbidden_key((value as Dictionary)[key]):
                return true
    elif value is Array:
        for item: Variant in value as Array:
            if _contains_forbidden_key(item):
                return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
