extends SceneTree

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var empty := StatusProductionTuning.new()
    for behavior: StringName in [
        PrototypeStatusResolver.BEHAVIOR_BURN,
        PrototypeStatusResolver.BEHAVIOR_SLOW,
    ]:
        var pending := empty.authoring_readiness(behavior)
        _expect(not bool(pending.get("authoring_ready", true)), "unassigned %s production Inspector data remains unavailable" % behavior)
        _expect((pending.get("missing_fields", PackedStringArray()) as PackedStringArray).has("approval_reference_id"), "%s requires explicit approval evidence identity" % behavior)
        _expect(not bool(PrototypeStatusProductionAuthority.readiness(behavior, empty).get("production_ready", true)), "%s cannot become production-ready through unassigned template" % behavior)

    var ready := _authored_fixture()
    for behavior: StringName in [
        PrototypeStatusResolver.BEHAVIOR_BURN,
        PrototypeStatusResolver.BEHAVIOR_SLOW,
    ]:
        var authored := ready.authoring_readiness(behavior)
        _expect(bool(authored.get("authoring_ready", false)), "%s explicit authoring fixture validates without shipping a final resource" % behavior)
        var authority := PrototypeStatusProductionAuthority.readiness(behavior, ready)
        _expect(
            bool(authority.get("authoring_ready", false))
            and not bool(authority.get("production_ready", true))
            and (authority.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).has("production_execution_owner"),
            "%s authored values remain non-production until the matching live execution owner is implemented" % behavior
        )
    ready.burn_tick_interval_ticks = ready.burn_duration_ticks + 1
    _expect(not bool(ready.authoring_readiness(&"burn").get("authoring_ready", true)), "authored Burn interval longer than duration is rejected")
    ready = _authored_fixture()
    ready.slow_reduction_fraction = INF
    _expect(not bool(ready.authoring_readiness(&"slow").get("authoring_ready", true)), "nonfinite final Slow magnitude is rejected")
    ready = _authored_fixture()
    ready.approved_final_values = false
    _expect(not bool(ready.authoring_readiness(&"burn").get("authoring_ready", true)), "populated numeric data without approval cannot become final")

    if _failures == 0:
        print("STATUS PRODUCTION INSPECTOR AUTHORING TEST PASS")
    else:
        push_error("STATUS PRODUCTION INSPECTOR AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _authored_fixture() -> StatusProductionTuning:
    var content := StatusProductionTuning.new()
    content.approved_final_values = true
    content.approval_reference_id = &"approval:fixture"
    content.burn_source_identity_policy_id = &"status_policy:source_fixture"
    content.burn_duration_ticks = 120
    content.burn_tick_interval_ticks = 30
    content.burn_damage_per_tick = 2
    content.burn_first_tick_policy_id = &"status_policy:first_tick_fixture"
    content.burn_damage_domain_policy_id = &"status_policy:damage_domain_fixture"
    content.burn_mitigation_policy_id = &"status_policy:mitigation_fixture"
    content.burn_cross_source_aggregation_policy_id = &"status_policy:burn_aggregation_fixture"
    content.burn_encounter_handoff_policy_id = &"status_policy:burn_handoff_fixture"
    content.slow_source_identity_policy_id = &"status_policy:slow_source_fixture"
    content.slow_duration_ticks = 150
    content.slow_reduction_fraction = 0.25
    content.slow_speed_floor_multiplier = 0.4
    content.slow_movement_domains_policy_id = &"status_policy:movement_fixture"
    content.slow_cross_source_aggregation_policy_id = &"status_policy:slow_aggregation_fixture"
    content.slow_encounter_handoff_policy_id = &"status_policy:slow_handoff_fixture"
    return content


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
