extends SceneTree

const VISUAL_CATALOG: EnemyVisualSceneCatalog = preload("res://src/enemies/presentation/enemy_visual_scene_catalog.tres")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _test_catalog()
    _test_live_presentation_factory()
    if _failures == 0:
        print("TOWER ENCOUNTER PRESENTATION FACTORY TEST PASS")
    else:
        push_error("TOWER ENCOUNTER PRESENTATION FACTORY TEST FAILURES: %d" % _failures)
    quit(_failures)

func _test_catalog() -> void:
    _expect(VISUAL_CATALOG != null, "enemy visual scene catalog resource loads")
    _expect(VISUAL_CATALOG.validate_catalog().is_empty(), "enemy visual scene catalog maps all twelve archetypes to matching presentation scenes")
    for archetype_id: StringName in EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS:
        _expect(VISUAL_CATALOG.get_scene(archetype_id) != null, "visual scene catalog resolves %s" % String(archetype_id))

func _test_live_presentation_factory() -> void:
    var floor := _floor_state()
    var actor_a := &"enemy:presentation_duelist"
    var actor_b := &"enemy:presentation_marksman"
    var plan := {
        "plan_id": &"encounter_plan:presentation_fixture",
        "floor_id": 1,
        "complete_floor_plan": true,
        "placements": [
            _placement(actor_a, &"duelist", Vector2i(2, 2)),
            _placement(actor_b, &"marksman", Vector2i(3, 2)),
        ],
    }
    var player := _combatant(&"player:presentation_fixture")
    var states := {
        actor_a: _combatant(actor_a),
        actor_b: _combatant(actor_b),
    }
    var activation := TowerEncounterRuntimeFactory.activate(
        floor,
        plan,
        &"encounter:presentation_fixture",
        player,
        states,
        ActiveCombatRegistry.new(),
        FullAiSimulationLedger.new()
    )
    _expect(bool(activation.get("accepted", false)), "presentation fixture activates authoritative tower encounter runtime")
    var presentation := TowerEncounterPresentationFactory.build(activation, VISUAL_CATALOG)
    _expect(bool(presentation.get("accepted", false)), "tower encounter presentation factory instantiates and binds live visuals")
    var presentation_root := presentation.get("root") as Node2D
    _expect(presentation_root != null and presentation_root.get_child_count() == 2, "presentation root owns exactly one visual node per live placement")
    if presentation_root == null:
        return
    get_root().add_child(presentation_root)

    var visuals := presentation.get("visuals_by_actor", {}) as Dictionary
    for actor_id: StringName in [actor_a, actor_b]:
        var visual := visuals.get(actor_id) as EnemyVisualController
        _expect(visual != null, "presentation factory resolves visual for %s" % String(actor_id))
        if visual == null:
            continue
        var expected_archetype := &"duelist" if actor_id == actor_a else &"marksman"
        _expect(visual.profile != null and visual.profile.archetype_id == expected_archetype, "live visual profile matches authored archetype for %s" % String(actor_id))
        var binder := visual.get_node_or_null("RuntimePresentationBinder") as EnemyRuntimePresentationBinder
        _expect(binder != null and binder.bound_runtime == activation["encounter_runtime"], "visual runtime binder owns authoritative encounter for %s" % String(actor_id))
        _expect(binder != null and binder.bound_archetype_runtime == (activation["archetype_runtimes"] as Dictionary).get(actor_id), "visual binder owns matching archetype action runtime for %s" % String(actor_id))
        var placement: Dictionary = _placement_for_actor(activation["placements"] as Array, actor_id)
        var expected_position := (Vector2(placement["world_tile"] as Vector2i) + Vector2(0.5, 0.5)) * float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE)
        _expect(visual.position == expected_position, "visual placement uses committed world tile for %s" % String(actor_id))
        var status := visual.get_node_or_null("CombatStatus") as EnemyCombatStatusPresenter
        _expect(status != null and is_equal_approx(status.get_health_ratio(), 1.0), "live visual owns an authoritative full-health status presenter for %s" % String(actor_id))

    var encounter := activation.get("encounter_runtime") as CombatEncounterRuntime
    var duelist_status := (presentation.get("status_by_actor", {}) as Dictionary).get(actor_a) as EnemyCombatStatusPresenter
    var damage_result := encounter.resolve_direct_contact(player.actor_id, actor_a, 71001, 0, _attack(25.0), false, DirectHitResolver.DEFENSE_NONE, false)
    _expect(bool(damage_result.get("accepted", false)) and int(damage_result.get("hp_damage", 0)) == 25, "authoritative presentation fixture damage resolves against live enemy state")
    _expect(duelist_status != null and is_equal_approx(duelist_status.get_health_ratio(), 0.75), "enemy health bar reads the post-hit authoritative HP ratio")
    _expect(duelist_status != null and duelist_status.get_damage_number_count() == 1, "accepted HP damage emits one bounded damage-number presentation")
    if duelist_status != null:
        for _tick: int in range(EnemyCombatStatusPresenter.DAMAGE_LIFETIME_TICKS):
            duelist_status.advance_fixed_tick()
        _expect(duelist_status.get_damage_number_count() == 0, "damage-number presentation expires after its bounded display lifetime")

    var duelist_runtime := (activation["archetype_runtimes"] as Dictionary).get(actor_a) as EnemyArchetypeRuntime
    var duelist_visual := visuals.get(actor_a) as EnemyVisualController
    _expect(duelist_runtime.request_non_attack_tactic({"accepted": true, "tactic_id": &"tactic:approach"}), "live archetype runtime emits movement presentation request")
    _expect(duelist_visual.animation_player.current_animation == String(duelist_visual.profile.move_animation), "bound tower enemy visual responds to live movement tactic")

    presentation_root.free()
    if encounter != null:
        encounter.end_encounter()

func _floor_state() -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        1, 11991, &"tower_generator:v01", &"tower_modules:v01", &"encounters:v01", &"quest_flags:presentation_factory_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    var state := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:presentation_factory", manifest)
    _expect(state != null, "presentation factory floor fixture builds")
    return state

func _placement(actor_id: StringName, archetype_id: StringName, local_tile: Vector2i) -> Dictionary:
    return {
        "actor_id": actor_id,
        "archetype_id": archetype_id,
        "encounter_id": &"encounter:presentation_fixture",
        "room_instance_id": &"room:objective_00",
        "local_tile": local_tile,
        "elite": false,
    }

func _placement_for_actor(placements: Array, actor_id: StringName) -> Dictionary:
    for raw: Variant in placements:
        if raw is Dictionary and StringName(String((raw as Dictionary).get("actor_id", &""))) == actor_id:
            return raw as Dictionary
    return {}

func _attack(raw_damage: float) -> Dictionary:
    return {
        "domain": DirectHitResolver.DOMAIN_PHYSICAL,
        "delivery": DirectHitResolver.DELIVERY_CONTACT,
        "raw_damage": raw_damage,
        "dodgeable": true,
        "blockable": true,
        "parryable": true,
        "guard_pressure": 0.0,
        "critical_triggered": false,
        "critical_multiplier": 1.0,
        "weak_point_triggered": false,
        "weak_point_multiplier": 1.0,
    }

func _combatant(actor_id: StringName) -> CombatantRuntimeState:
    var state := CombatantRuntimeState.new()
    _expect(state.configure(actor_id, 100, 100.0, 0.0, 0.0, 10.0, true, false, false), "presentation combatant configures: %s" % String(actor_id))
    return state

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
    else:
        _failures += 1
        push_error("FAIL: %s" % message)
