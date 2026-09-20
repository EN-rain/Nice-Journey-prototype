extends SceneTree

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_structural_catalog_stays_valid()
    _test_production_contract_fails_closed_on_unauthored_policy()
    _test_floor_2_through_10_gap_reporting_is_exact()
    _test_declared_empty_sets_are_distinct_from_missing_authoring()
    _test_invalid_authored_ids_fail_validation()

    if _failures == 0:
        print("QUEST DEFINITION CONTRACT TEST PASS")
    else:
        push_error("QUEST DEFINITION CONTRACT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_structural_catalog_stays_valid() -> void:
    _expect(QuestCatalog.validate_catalog().is_empty(), "existing 15-definition structural manifest remains valid")
    var floor1 := QuestCatalog.get_definition(&"primary_floor_1")
    _expect(floor1 != null, "Floor 1 definition exists")
    if floor1 != null:
        _expect(floor1.acceptance_anchor_declared, "Floor 1 declares the authoritative Region 3 acceptance anchor")
        _expect(floor1.acceptance_anchor_id == QuestCatalog.REGION3_QUEST_HALL_ANCHOR_ID, "Floor 1 acceptance binds to the authored Quest Hall structure")
        _expect(floor1.turn_in_anchor_declared and floor1.turn_in_anchor_id == QuestCatalog.REGION3_QUEST_HALL_ANCHOR_ID, "Floor 1 turn-in binds to the authored Quest Hall structure")
    for floor_id: int in range(2, 11):
        var definition := QuestCatalog.get_definition(StringName("primary_floor_%d" % floor_id))
        _expect(definition != null and definition.acceptance_anchor_declared and definition.acceptance_anchor_id == QuestCatalog.REGION3_QUEST_HALL_ANCHOR_ID, "Floor %d primary acceptance uses the authoritative Quest Hall anchor" % floor_id)
        _expect(definition != null and definition.turn_in_anchor_declared and definition.turn_in_anchor_id == QuestCatalog.REGION3_QUEST_HALL_ANCHOR_ID, "Floor %d primary turn-in uses the authoritative Quest Hall anchor" % floor_id)


func _test_production_contract_fails_closed_on_unauthored_policy() -> void:
    var errors := QuestCatalog.validate_authored_contracts()
    _expect(not errors.is_empty(), "production quest-contract validation fails closed while required per-definition policy is unauthored")
    _expect(_contains(errors, "primary_floor_1: prerequisites must be explicitly declared"), "Floor 1 missing prerequisite authoring is explicit")
    _expect(_contains(errors, "primary_floor_1: required_objective_ids must be explicitly declared"), "Floor 1 missing required-objective declaration is explicit")
    _expect(_contains(errors, "primary_floor_1: optional_objective_ids must be explicitly declared"), "Floor 1 missing optional-objective declaration is explicit")
    _expect(_contains(errors, "primary_floor_1: instance_binding_ids must be explicitly declared"), "Floor 1 missing instance-binding declaration is explicit")
    _expect(_contains(errors, "primary_floor_1: leave_rule_id must be explicitly declared"), "Floor 1 missing leave policy is explicit")
    _expect(_contains(errors, "primary_floor_1: failure_rule_id must be explicitly declared"), "Floor 1 missing failure policy is explicit")
    _expect(_contains(errors, "primary_floor_1: retry_reset_ids must be explicitly declared"), "Floor 1 missing retry/reset authoring is explicit")
    _expect(_contains(errors, "primary_floor_1: rewards must be explicitly declared"), "Floor 1 missing reward authoring is explicit")
    _expect(_contains(errors, "primary_floor_1: branch_effects must be explicitly declared"), "Floor 1 missing branch-effect authoring is explicit")
    _expect(_contains(errors, "primary_floor_1: completion_conditions must be explicitly declared"), "Floor 1 missing completion conditions are explicit")
    _expect(_contains(errors, "side_tower_floor4_escort: acceptance_anchor_id must be explicitly declared"), "placeholder tower-side acceptance anchor remains visibly unauthored")
    _expect(QuestCatalog.get_definition(&"primary_floor_2").validate_production_contract().is_empty(), "Floor 2 now owns a complete production-v01 contract")


func _test_floor_2_through_10_gap_reporting_is_exact() -> void:
    for floor_id: int in range(2, 11):
        var definition := QuestCatalog.get_definition(StringName("primary_floor_%d" % floor_id))
        _expect(definition != null, "Floor %d production definition exists" % floor_id)
        if definition == null:
            continue
        _expect(definition.unauthored_contract_fields().is_empty(), "Floor %d production-v01 declares every required quest-contract field" % floor_id)
        _expect(not definition.playtest_placeholder, "Floor %d primary is no longer a playtest-placeholder definition" % floor_id)
        _expect(definition.prerequisite_ids == [PrimaryQuestProductionV01.unlocked_fact_id(floor_id)], "Floor %d acceptance requires its durable floor-unlock fact" % floor_id)
        _expect(definition.required_objective_ids == [PrimaryQuestProductionV01.required_objective_id(floor_id, definition.family)], "Floor %d owns exactly one production-v01 required objective identity" % floor_id)
        _expect(definition.optional_objective_ids.is_empty(), "Floor %d primary optional objective set is explicitly empty" % floor_id)
        _expect(definition.branch_effect_ids.is_empty(), "Floor %d primary v01 branch-effect set is explicitly empty" % floor_id)
        var status := QuestCatalog.primary_production_status(floor_id)
        _expect(bool(status.get("production_ready", false)) and not bool(status.get("playtest_placeholder", true)), "Floor %d primary contract reports production-ready" % floor_id)
        _expect((status.get("unauthored_contract_fields", PackedStringArray()) as PackedStringArray).is_empty(), "Floor %d production status has no unauthored contract fields" % floor_id)
        _expect((status.get("contract_errors", PackedStringArray()) as PackedStringArray).is_empty(), "Floor %d production status has no contract errors" % floor_id)
    var floor11 := QuestCatalog.primary_production_status(11)
    _expect(not bool(floor11.get("production_ready", true)) and StringName(floor11.get("quest_id", &"")) == &"", "production status has no Floor 11 identity")


func _test_declared_empty_sets_are_distinct_from_missing_authoring() -> void:
    var definition := _complete_fixture()
    _expect(definition.validate_authored_contract().is_empty(), "explicitly declared empty prerequisite/branch sets are accepted without inventing content")

    definition.prerequisites_declared = false
    var errors := definition.validate_authored_contract()
    _expect(_contains(errors, "prerequisites must be explicitly declared"), "missing prerequisite authoring is distinguishable from an explicitly authored no-prerequisite declaration")

    definition = _complete_fixture()
    definition.reward_ids.clear()
    definition.retry_reset_ids.clear()
    errors = definition.validate_authored_contract()
    _expect(not _contains(errors, "rewards must contain at least one stable ID"), "an explicitly authored no-reward policy remains valid")
    _expect(_contains(errors, "retry_reset_ids must contain at least one stable ID"), "an authored retry/reset declaration still requires an actual reset-state identity")

    definition = _complete_fixture()
    definition.playtest_placeholder = true
    _expect(_contains(definition.validate_production_contract(), "playtest placeholder is not production-authoritative"), "production validation cannot promote a playtest placeholder")


func _test_invalid_authored_ids_fail_validation() -> void:
    var definition := _complete_fixture()
    definition.completion_condition_ids = [&"bad condition"]
    definition.retry_reset_ids = [&"attempt:state", &"attempt:state"]
    definition.optional_objective_ids = [&"objective:required"]
    var errors := definition.validate_authored_contract()
    _expect(_contains(errors, "completion_conditions must contain only stable IDs"), "completion conditions reject invalid stable IDs")
    _expect(_contains(errors, "retry_reset_ids must not contain duplicate IDs"), "retry/reset declarations reject duplicate state identities")
    _expect(_contains(errors, "objective ID cannot be both required and optional"), "required and optional objective declarations cannot overlap")


func _complete_fixture() -> QuestDefinition:
    var definition := QuestDefinition.new()
    definition.prerequisites_declared = true
    definition.required_objectives_declared = true
    definition.required_objective_ids = [&"objective:required"]
    definition.optional_objectives_declared = true
    definition.instance_bindings_declared = true
    definition.instance_binding_ids = [&"binding:fixture"]
    definition.acceptance_anchor_declared = true
    definition.acceptance_anchor_id = &"anchor:accept"
    definition.turn_in_anchor_declared = true
    definition.turn_in_anchor_id = &"anchor:turn_in"
    definition.leave_rule_declared = true
    definition.leave_rule_id = &"leave:fixture"
    definition.failure_rule_declared = true
    definition.failure_rule_id = &"failure:fixture"
    definition.retry_reset_declared = true
    definition.retry_reset_ids = [&"reset:attempt_state"]
    definition.rewards_declared = true
    definition.reward_ids = [&"reward:fixture"]
    definition.branch_effects_declared = true
    definition.completion_conditions_declared = true
    definition.completion_condition_ids = [&"completion:fixture"]
    return definition


func _contains(errors: PackedStringArray, expected: String) -> bool:
    for error: String in errors:
        if error == expected:
            return true
    return false


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
