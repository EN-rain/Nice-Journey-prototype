extends SceneTree

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_all_floor_plans()
    _test_objective_bindings()
    if _failures == 0:
        print("TOWER PROTOTYPE ENCOUNTER CONTENT CATALOG TEST PASS")
    else:
        push_error("TOWER PROTOTYPE ENCOUNTER CONTENT CATALOG TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_all_floor_plans() -> void:
    var seen_archetypes: Dictionary = {}
    for floor_id: int in range(1, 11):
        var floor_state := _floor_state(floor_id)
        _expect(floor_state != null, "Floor %d encounter-content fixture builds" % floor_id)
        if floor_state == null:
            continue
        var first := TowerPrototypeEncounterContentCatalog.build_plan(floor_state)
        var second := TowerPrototypeEncounterContentCatalog.build_plan(floor_state)
        _expect(not first.is_empty() and first == second, "Floor %d playtest encounter plan is deterministic" % floor_id)
        _expect(TowerEncounterPlanValidator.validate(first, floor_state).is_empty(), "Floor %d complete encounter plan satisfies runtime placement/cap rules" % floor_id)
        var placements := first.get("placements", []) as Array
        _expect(placements.size() == int(TowerPrototypeEncounterContentCatalog.REUSABLE_ENEMY_TARGETS[floor_id]), "Floor %d uses its declared reversible reusable-enemy target" % floor_id)
        var elite_count := 0
        var actor_ids: Dictionary = {}
        for raw: Variant in placements:
            var placement := raw as Dictionary
            var actor_id := StringName(String(placement.get("actor_id", &"")))
            var archetype_id := StringName(String(placement.get("archetype_id", &"")))
            actor_ids[actor_id] = true
            seen_archetypes[archetype_id] = true
            if bool(placement.get("elite", false)):
                elite_count += 1
            if floor_id == 10:
                _expect(StringName(String(placement.get("room_instance_id", &""))) != &"room:boss", "Floor 10 reusable enemy %s stays outside the no-add Boss Sanctum" % String(actor_id))
        _expect(actor_ids.size() == placements.size(), "Floor %d plan has unique persistent actor identity" % floor_id)
        _expect(elite_count == int(PrototypeTowerFloorCatalog.get_entry(floor_id).get("elite_target", 0)), "Floor %d plan matches the approved elite target" % floor_id)
        var encounter_ids := TowerPrototypeEncounterContentCatalog.encounter_ids(first)
        _expect(not encounter_ids.is_empty(), "Floor %d plan exposes stable room-scoped encounter identities" % floor_id)
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        _expect(seen_archetypes.has(archetype_id), "playtest floor allocation exercises archetype %s somewhere in Floors 1-10" % String(archetype_id))

func _test_objective_bindings() -> void:
    var floor4 := _floor_state(4)
    var plan4 := TowerPrototypeEncounterContentCatalog.build_plan(floor4)
    var configs4 := TowerPrototypeEncounterContentCatalog.objective_configs(floor4, plan4)
    _expect(configs4.has(&"primary_floor_4"), "Floor 4 primary Annihilation receives deterministic required-actor content")
    _expect(configs4.has(&"side_tower_floor4_escort"), "Floor 4 side Escort receives its separately authored actor/route objective config")
    if configs4.has(&"side_tower_floor4_escort"):
        var escort := configs4[&"side_tower_floor4_escort"] as Dictionary
        _expect(StableId.is_valid(String(escort.get("actor_id", &""))) and not (escort.get("route_node_ids", []) as Array).is_empty(), "Floor 4 side Escort config preserves authored actor and route identity")
    var bindings4 := TowerPrototypeEncounterContentCatalog.quest_bindings_by_actor(floor4, plan4)
    _expect(_binding_count(bindings4, &"primary_floor_4") > 0, "Floor 4 combat residents bind to the primary Annihilation objective")
    _expect(_binding_count(bindings4, &"side_tower_floor4_escort") == 0, "Floor 4 generic enemy defeats cannot masquerade as escort progress")

    var floor2 := _floor_state(2)
    var plan2 := TowerPrototypeEncounterContentCatalog.build_plan(floor2)
    var configs2 := TowerPrototypeEncounterContentCatalog.objective_configs(floor2, plan2)
    _expect(configs2.has(&"primary_floor_2"), "Floor 2 primary Escort receives deterministic authored objective content")
    var bindings2 := TowerPrototypeEncounterContentCatalog.quest_bindings_by_actor(floor2, plan2)
    _expect(_binding_count(bindings2, &"primary_floor_2") == 0, "Floor 2 generic enemy defeats remain separate from primary Escort progress")

    var floor7 := _floor_state(7)
    var plan7 := TowerPrototypeEncounterContentCatalog.build_plan(floor7)
    var configs7 := TowerPrototypeEncounterContentCatalog.objective_configs(floor7, plan7)
    _expect(configs7.has(&"primary_floor_7"), "Floor 7 Tower Defense receives an authored mechanical objective config")
    _expect(configs7.has(&"side_tower_floor7_annihilation"), "Floor 7 reserved side Annihilation receives required-actor content")
    if configs7.has(&"primary_floor_7"):
        var defense := configs7[&"primary_floor_7"] as Dictionary
        _expect(int(defense.get("objective_max_hp", 0)) == TowerPrototypeEncounterContentCatalog.DEFENSE_OBJECTIVE_MAX_HP_INITIAL_TUNING, "Floor 7 defense HP is explicit tunable data rather than hidden runtime state")
        var waves := defense.get("required_actor_ids_by_wave", {}) as Dictionary
        _expect(waves.size() == 1 and not (waves.values()[0] as Array).is_empty(), "Floor 7 playtest defense has one explicit required wave")
    var bindings7 := TowerPrototypeEncounterContentCatalog.quest_bindings_by_actor(floor7, plan7)
    _expect(_binding_count(bindings7, &"primary_floor_7") > 0, "Floor 7 defense residents carry wave-aware quest bindings")
    _expect(_binding_count(bindings7, &"side_tower_floor7_annihilation") > 0, "Floor 7 side-room residents bind independently to side Annihilation")
    _expect(_all_defense_bindings_have_wave(bindings7, &"primary_floor_7"), "every Floor 7 Tower Defense defeat binding carries an explicit wave ID")

    var floor10 := _floor_state(10)
    var plan10 := TowerPrototypeEncounterContentCatalog.build_plan(floor10)
    var configs10 := TowerPrototypeEncounterContentCatalog.objective_configs(floor10, plan10)
    _expect(not configs10.has(&"primary_floor_10"), "generic Floor 10 plan does not steal objective ownership from the authoritative Tenth Warden milestone")

func _floor_state(floor_id: int) -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        floor_id,
        80000 + floor_id,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:playtest_v01",
        StringName("quest_flags:encounter_content_f%02d" % floor_id)
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(
        StringName("floor_instance:encounter_content_f%02d" % floor_id),
        manifest
    )

func _binding_count(bindings: Dictionary, quest_id: StringName) -> int:
    var count := 0
    for raw_bindings: Variant in bindings.values():
        if not raw_bindings is Array:
            continue
        for raw_binding: Variant in raw_bindings as Array:
            if raw_binding is Dictionary and StringName(String((raw_binding as Dictionary).get("quest_id", &""))) == quest_id:
                count += 1
    return count

func _all_defense_bindings_have_wave(bindings: Dictionary, quest_id: StringName) -> bool:
    var found := false
    for raw_bindings: Variant in bindings.values():
        if not raw_bindings is Array:
            continue
        for raw_binding: Variant in raw_bindings as Array:
            if not raw_binding is Dictionary:
                continue
            var binding := raw_binding as Dictionary
            if StringName(String(binding.get("quest_id", &""))) != quest_id:
                continue
            found = true
            if not StableId.is_valid(String(binding.get("wave_id", &""))):
                return false
    return found

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
