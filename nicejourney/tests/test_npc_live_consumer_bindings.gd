extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const TOWER_VISUALS: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const ESCORT_PROFILE: NpcVisualProfile = preload("res://src/world/npc/presentation/profiles/temporary_escort.tres")

var failures := 0

func _init() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    if not condition:
        failures += 1
        push_error("FAIL: " + description)

func _check_actor_visual(presenter: NpcVisualPresenter, profile: NpcVisualProfile, label: String) -> void:
    _check(presenter != null, label + " owns its single presenter")
    if presenter == null:
        return
    _check(presenter.profile == profile, label + " resolves accepted Inspector identity")
    _check(presenter.sprite != null and presenter.sprite.texture == profile.texture, label + " displays the production texture")
    if presenter.sprite != null:
        _check(presenter.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, label + " preserves pixel filtering")
        _check(presenter.sprite.position.is_equal_approx(Vector2(profile.frame_size) * 0.5 - profile.ground_anchor), label + " preserves the (16,29) ground anchor")

func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    _check(town != null, "real Region 3 town scene loads")
    if town == null:
        quit(1)
        return
    root.add_child(town)
    await process_frame
    _check(town.validate_layout().is_empty(), "town retains authored 20-structure layout and routes")
    var cases: Array[Dictionary] = [
        {"node": "QuestHall", "profile": "tower_quest_coordinator"},
        {"node": "Blacksmith", "profile": "blacksmith_upgrader"},
        {"node": "GeneralMerchant", "profile": "merchant"},
    ]
    for case: Dictionary in cases:
        var path := String(case["node"]) + "/ServiceInteraction"
        var service := town.get_node_or_null(path) as Region3FunctionalServiceInteraction
        _check(service != null, path + " exists at the authored site")
        if service == null:
            continue
        var presenters := 0
        for child: Node in service.get_children():
            if child is NpcVisualPresenter:
                presenters += 1
        _check(presenters == 1, path + " has exactly one identity, no NPC duplicate")
        var presenter := service.get_node_or_null("NpcVisualPresenter") as NpcVisualPresenter
        var profile := load("res://src/world/npc/presentation/profiles/" + String(case["profile"]) + ".tres") as NpcVisualProfile
        _check(profile != null, path + " profile loads")
        if profile == null:
            continue
        _check_actor_visual(presenter, profile, path)
        if presenter != null:
            _check(presenter.position == Vector2.ZERO, path + " introduces no new placement offset")
            _check(presenter.global_position.is_equal_approx(service.authored_approach_world_position()), path + " shares exact pre-existing service approach anchor")
    town.queue_free()
    await process_frame

    var regional := Region3EscortActor.new()
    root.add_child(regional)
    _check(regional.npc_visual_profile == ESCORT_PROFILE, "Region 3 escort defaults to the approved static identity")
    _check_actor_visual(regional.get_node_or_null("NpcVisualPresenter") as NpcVisualPresenter, ESCORT_PROFILE, "Region 3 live escort")
    var initial_hp := regional.current_hp
    _check(regional.apply_damage(5) and regional.current_hp == initial_hp - 5, "adding the sprite preserves escort HP and damage")
    regional.queue_free()
    await process_frame

    var host := TowerFloorSessionHost.new()
    root.add_child(host)
    _check(host.escort_npc_visual_profile == ESCORT_PROFILE, "Tower escort host owns approved Inspector profile")
    var fixture := _tower_fixture()
    _check(bool(fixture.get("accepted", false)), "real Tower floor fixture composes")
    if bool(fixture.get("accepted", false)):
        var player := PLAYER_SCENE.instantiate() as PlayerController
        root.add_child(player)
        await process_frame
        var activated_floor := host.activate(fixture["runtime_root"] as Node2D, fixture["arrival"] as Dictionary, player, player.camera)
        _check(activated_floor, "Tower floor activates with live player")
        if activated_floor:
            var profile := ProfileCreationService.create_profile(1, "NPC visual consumer", "melee")
            profile.quest_progress["primary_floor_2"] = {
                "state": QuestProgressState.STATE_ACTIVE,
                "stage_id": QuestCatalog.get_definition(&"primary_floor_2").stage_ids[-1],
                "attempt_id": &"attempt:npc_visual_consumer",
                "attempt_history": ["attempt:npc_visual_consumer"],
                "objective_state": {},
            }
            var tuning := _escort_tuning()
            _check(tuning.validate_tuning().is_empty(), "test escort tuning is valid")
            var activation := host.activate_escort(profile, fixture["floor_state"] as FloorInstanceState, &"primary_floor_2", tuning)
            _check(bool(activation.get("accepted", false)), "Tower spawns live escort with existing authored route")
            var runtime := host.get_escort_runtime(&"primary_floor_2")
            _check(runtime != null and runtime.npc_visual_profile == ESCORT_PROFILE, "Tower actor receives its host-owned visual profile")
            if runtime != null and runtime.actor != null:
                runtime.set_physics_process(false)
                _check_actor_visual(runtime.actor.get_node_or_null("NpcVisualPresenter") as NpcVisualPresenter, ESCORT_PROFILE, "Tower live escort")
        player.queue_free()
    host.queue_free()
    await process_frame
    print("NPC LIVE CONSUMER BINDING FAILURES: ", failures)
    quit(0 if failures == 0 else 1)

func _tower_fixture() -> Dictionary:
    var request := TowerFloorGenerationCommitService.build_request(
        2, 91202, TowerGenerationIdentityFactory.GENERATOR_VERSION,
        TowerGenerationIdentityFactory.MODULE_CONTENT_VERSION,
        TowerGenerationIdentityFactory.ENCOUNTER_CONFIG_ID,
        &"quest_flags:npc_visual_consumer_test"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return {"accepted": false}
    var compose := TowerFloorRuntimeComposer.build(manifest, TOWER_VISUALS)
    if not bool(compose.get("accepted", false)):
        return {"accepted": false}
    var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:npc_escort_visual_f2", manifest)
    if floor == null:
        (compose["root"] as Node2D).free()
        return {"accepted": false}
    var arrival := TowerArrivalResolver.resolve_entrance(floor)
    if not bool(arrival.get("accepted", false)):
        (compose["root"] as Node2D).free()
        return {"accepted": false}
    return {"accepted": true, "runtime_root": compose["root"], "floor_state": floor, "arrival": arrival}

func _escort_tuning() -> TowerEscortRuntimeTuning:
    var tuning := TowerEscortRuntimeTuning.new()
    tuning.authored = true
    tuning.speed_px_per_second = 64.0
    tuning.arrival_tolerance_px = 2.0
    var shape := RectangleShape2D.new()
    shape.size = Vector2(12.0, 10.0)
    tuning.collision_shape = shape
    tuning.collision_layer = 1
    tuning.collision_mask = 1
    tuning.max_hp = 100
    tuning.health_policy_id = &"health:escort_runtime_hp_v01"
    tuning.failure_policy_id = TowerEscortObjectiveAuthoring.FAILURE_POLICY_ACTOR_DEFEAT
    tuning.separation_policy_id = &"separation:nonterminal_route_owned_v01"
    tuning.repath_policy_id = &"repath:collision_retry_same_route_v01"
    tuning.save_policy_id = &"save:escort_exact_safe_state_v01"
    return tuning
