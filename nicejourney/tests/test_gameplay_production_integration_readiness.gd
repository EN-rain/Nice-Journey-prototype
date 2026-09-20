extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const REGION3_TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    _test_shipped_gameplay_assigns_explicit_boss_playtest_content()
    _test_production_readiness_and_remaining_blockers_are_explicit()
    _test_region3_authoritative_world_data_and_withheld_state()

    if _failures == 0:
        print("GAMEPLAY PRODUCTION INTEGRATION READINESS TEST PASS")
    else:
        push_error("GAMEPLAY PRODUCTION INTEGRATION READINESS TEST FAILURES: %d" % _failures)
    quit(_failures)


func _test_shipped_gameplay_assigns_explicit_boss_playtest_content() -> void:
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    _expect(gameplay != null, "shipped GameplayRoot scene instantiates")
    if gameplay == null:
        return

    _expect(gameplay.tenth_warden_production_authoring != null and gameplay.tenth_warden_production_authoring.resource_name.begins_with("PLAYTEST "), "shipped GameplayRoot explicitly labels its assigned boss balance as playtest-only")
    _expect(gameplay.player_defender_facts_tuning != null and gameplay.player_defender_facts_tuning.resource_name.begins_with("PLAYTEST "), "shipped defender timing is explicitly labeled as provisional")
    var boss_status := gameplay.get_floor10_boss_production_status()
    _expect(bool(boss_status.get("authoring_ready", false)) and (boss_status.get("authoring_errors", PackedStringArray()) as PackedStringArray).is_empty(), "assigned provisional boss combat resource passes structural validation")
    _expect(gameplay.player_defender_facts_tuning.validate_tuning(load("res://src/data/tuning/movement_default.tres") as MovementTuning).is_empty(), "assigned provisional defender resource fits the existing authored dodge duration")
    _expect(not bool(boss_status.get("production_ready", true)) and not bool(boss_status.get("defender_facts_ready", true)), "before entering the scene tree, defender-facts readiness correctly requires a live player and combat runtime")
    _expect(gameplay.level_progression_policy == null, "shipped GameplayRoot does not assign an unauthoritative level progression policy")
    _expect(gameplay.vendor_stock_catalog == null, "shipped GameplayRoot does not assign fixture merchant stock as production content")
    _expect(gameplay.blacksmith_recipe_catalog == null, "shipped GameplayRoot does not assign fixture Blacksmith recipes as production content")
    _expect(gameplay.item_category_catalog == null, "shipped GameplayRoot does not assign a fixture item-category catalog as production authority")
    _expect(gameplay.region3_inn_recovery_definition.is_empty(), "shipped GameplayRoot does not invent Inn recovery content")
    _expect(gameplay.region3_clinic_recovery_definition.is_empty(), "shipped GameplayRoot does not invent Clinic recovery content")
    _expect(gameplay.region3_recovery_resource_mapping.is_empty(), "shipped GameplayRoot does not invent recovery-resource mappings")
    _expect(gameplay.music_routing_definition == null, "shipped GameplayRoot does not assign fixture/generated test audio as production music")

    var services_status := gameplay.get_region3_services_economy_audio_content_status()
    _expect(not bool(services_status.get("complete", true)), "shared service/economy/audio integration remains fail-closed while production content is absent")
    gameplay.free()


func _test_production_readiness_and_remaining_blockers_are_explicit() -> void:
    for floor_id: int in range(2, 11):
        var status := QuestCatalog.primary_production_status(floor_id)
        _expect(bool(status.get("production_ready", false)), "Floor %d primary quest reports production-v01 ready" % floor_id)
        _expect(not bool(status.get("playtest_placeholder", true)), "Floor %d primary quest is not a playtest placeholder" % floor_id)
        var missing := status.get("objective_missing_authoritative_fields", PackedStringArray()) as PackedStringArray
        var external_missing := status.get("objective_external_runtime_missing_authoritative_fields", PackedStringArray()) as PackedStringArray
        var contract_errors := status.get("contract_errors", PackedStringArray()) as PackedStringArray
        _expect(
            missing.is_empty() and external_missing.is_empty() and contract_errors.is_empty(),
            "Floor %d primary quest has no remaining quest/objective production blockers" % floor_id
        )

    var active_count := 0
    for class_id: StringName in [&"melee", &"ranged", &"mage"]:
        for skill_id: StringName in SkillCatalog.ACTIVE_IDS_BY_CLASS[class_id]:
            active_count += 1
            var readiness := ActiveSkillProductionAuthority.readiness(skill_id)
            _expect(bool(readiness.get("accepted", false)), "%s has a production-authority record aligned with the approved skill catalog" % String(skill_id))
            _expect(not bool(readiness.get("production_ready", true)), "%s remains unavailable for shared player input until authoritative combat authoring exists" % String(skill_id))
            _expect(
                not (readiness.get("missing_authoritative_fields", PackedStringArray()) as PackedStringArray).is_empty(),
                "%s reports exact missing production fields" % String(skill_id)
            )
    _expect(active_count == 9, "shared integration audits exactly the nine approved active skills")


func _test_region3_authoritative_world_data_and_withheld_state() -> void:
    var profile := ProfileCreationService.create_profile(1, "Region Integration", "melee")
    _expect(profile != null, "Region 3 integration fixture creates a valid profile")
    if profile == null:
        return

    var map_data := MapViewService.build_layer(profile, MapLayerIdentityValidator.LAYER_REGION_MAP)
    _expect(bool(map_data.get("accepted", false)), "Region Map consumes the validated authored Region 3 layout")
    _expect(bool(map_data.get("world_layout_definition_available", false)), "Region Map exposes the authored world-layout definition")
    _expect(int(map_data.get("structure_count", 0)) == 20, "Region Map preserves exactly 20 town structure identities")
    _expect(
        int(map_data.get("functional_structure_count", 0)) == 8
        and int(map_data.get("decorative_structure_count", 0)) == 12,
        "Region Map preserves the 8 functional + 12 decorative structure split"
    )
    _expect(bool(map_data.get("explored_subzone_geometry_available", false)), "Region Map recognizes the authoritative five subzone rectangles")
    _expect(not bool(map_data.get("explored_subzone_state_available", true)), "fresh profile keeps explored-subzone state unavailable until physical Region 3 traversal initializes discovery")
    _expect(StringName(String(map_data.get("explored_subzone_unavailable_reason_id", &""))) == Region3SubzoneDiscoveryService.REASON_STATE_UNINITIALIZED, "fresh profile exposes the exact uninitialized Region discovery reason")
    _expect(not bool(map_data.get("quest_marker_state_available", true)), "quest-marker geometry remains withheld without exact authored tiles")
    _expect(not bool(map_data.get("checkpoint_marker_state_available", true)), "Region checkpoint markers remain withheld without exact authored coordinates")
    _expect(not bool(map_data.get("risk_marker_state_available", true)), "Region risk markers remain withheld until a concrete Recommended Level is authored for each hostile subzone")

    var town := REGION3_TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    _expect(town != null and town.validate_layout().is_empty(), "Region 3 authored town and world-layout data validate together")
    if town != null:
        _expect(
            town.environment_support_profile != null
            and not town.environment_support_profile.has_complete_source_evidence(),
            "Batch 2 dressing remains explicitly preview-only until the seven exact generated source files are recovered"
        )
        town.free()


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
