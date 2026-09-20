extends SceneTree

const TOWN: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const MARKERS: PackedScene = preload("res://src/world/region3/quests/region3_side_quest_authored_markers.tscn")
const PLAYER: PackedScene = preload("res://src/player/player.tscn")
const TOWER_VISUALS: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const OUTPUT := "res://assets/art/npc/review/live_consumer_v01/"

func _init() -> void:
    call_deferred("_capture")

func _capture() -> void:
    root.size = Vector2i(640, 360)
    root.content_scale_size = Vector2i(640, 360)
    var town := TOWN.instantiate() as Region3AuthoredTownLayout
    if town == null:
        push_error("Unable to instantiate real Region 3 scene")
        quit(1)
        return
    root.add_child(town)
    var camera := Camera2D.new()
    camera.name = "CaptureCamera"
    camera.zoom = Vector2(2.0, 2.0)
    root.add_child(camera)
    camera.make_current()
    var folder := ProjectSettings.globalize_path(OUTPUT)
    if DirAccess.make_dir_recursive_absolute(folder) != OK:
        push_error("Cannot create NPC review folder")
        quit(1)
        return
    var sites: Array[Dictionary] = [
        {"node": "QuestHall/ServiceInteraction/NpcVisualPresenter", "file": "quest_hall_coordinator.png"},
        {"node": "Blacksmith/ServiceInteraction/NpcVisualPresenter", "file": "blacksmith.png"},
        {"node": "GeneralMerchant/ServiceInteraction/NpcVisualPresenter", "file": "merchant.png"},
    ]
    for site: Dictionary in sites:
        var presenter := town.get_node_or_null(String(site["node"])) as NpcVisualPresenter
        if presenter == null or presenter.sprite == null:
            push_error("Missing live visual: " + String(site["node"]))
            quit(1)
            return
        camera.global_position = presenter.global_position
        await process_frame
        await RenderingServer.frame_post_draw
        var path := ProjectSettings.globalize_path(OUTPUT + String(site["file"]))
        var capture := root.get_texture().get_image()
        if capture.is_empty() or capture.save_png(path) != OK:
            push_error("Unable to save renderer capture: " + path)
            quit(1)
            return
        print("NPC REAL SCENE RENDER PASS: ", site["node"], " | ", capture.get_size(), " | ", path)
    var markers := MARKERS.instantiate() as Region3SideQuestPlaytestAnchorLayer
    town.add_child(markers)
    var actor := Region3EscortActor.new()
    actor.name = "RegionalEscortCapture"
    town.add_child(actor)
    actor.global_position = markers.marker_world_position(markers.escort_start_path)
    var escort_presenter := actor.get_node_or_null("NpcVisualPresenter") as NpcVisualPresenter
    if escort_presenter == null or escort_presenter.sprite == null:
        push_error("Region 3 Escort actor does not display its approved profile")
        quit(1)
        return
    camera.global_position = actor.global_position
    await process_frame
    await RenderingServer.frame_post_draw
    var escort_path := ProjectSettings.globalize_path(OUTPUT + "region3_escort_at_authored_start.png")
    var escort_capture := root.get_texture().get_image()
    if escort_capture.is_empty() or escort_capture.save_png(escort_path) != OK:
        push_error("Unable to save Region 3 escort capture")
        quit(1)
        return
    print("NPC AUTHORED ESCORT RENDER PASS: ", markers.escort_start_path, " | ", escort_capture.get_size(), " | ", escort_path)
    town.visible = false
    var fixture := _tower_fixture()
    if not bool(fixture.get("accepted", false)):
        push_error("Cannot compose Tower floor for escort presentation")
        quit(1)
        return
    var player := PLAYER.instantiate() as PlayerController
    var host := TowerFloorSessionHost.new()
    root.add_child(player)
    root.add_child(host)
    await process_frame
    if not host.activate(fixture["runtime_root"] as Node2D, fixture["arrival"] as Dictionary, player, player.camera):
        push_error("Cannot activate real Tower floor")
        quit(1)
        return
    var progress := ProfileCreationService.create_profile(1, "NPC renderer capture", "melee")
    progress.quest_progress["primary_floor_2"] = {
        "state": QuestProgressState.STATE_ACTIVE,
        "stage_id": QuestCatalog.get_definition(&"primary_floor_2").stage_ids[-1],
        "attempt_id": &"attempt:npc_renderer",
        "attempt_history": ["attempt:npc_renderer"],
        "objective_state": {},
    }
    var activation := host.activate_escort(progress, fixture["floor_state"] as FloorInstanceState, &"primary_floor_2", _escort_tuning())
    var runtime := host.get_escort_runtime(&"primary_floor_2")
    if not bool(activation.get("accepted", false)) or runtime == null or runtime.actor == null:
        push_error("Cannot activate live Tower escort for renderer capture: " + str(activation))
        quit(1)
        return
    runtime.set_physics_process(false)
    var tower_presenter := runtime.actor.get_node_or_null("NpcVisualPresenter") as NpcVisualPresenter
    if tower_presenter == null or tower_presenter.sprite == null:
        push_error("Tower escort missing approved static body")
        quit(1)
        return
    camera.make_current()
    camera.global_position = runtime.actor.global_position
    await process_frame
    await RenderingServer.frame_post_draw
    var tower_path := ProjectSettings.globalize_path(OUTPUT + "tower_escort_on_real_floor.png")
    var tower_capture := root.get_texture().get_image()
    if tower_capture.is_empty() or tower_capture.save_png(tower_path) != OK:
        push_error("Unable to save Tower escort capture")
        quit(1)
        return
    print("NPC TOWER ESCORT RENDER PASS: ", runtime.quest_id, " | ", tower_capture.get_size(), " | ", tower_path)
    quit(0)

func _tower_fixture() -> Dictionary:
    var request := TowerFloorGenerationCommitService.build_request(
        2, 91202, TowerGenerationIdentityFactory.GENERATOR_VERSION,
        TowerGenerationIdentityFactory.MODULE_CONTENT_VERSION,
        TowerGenerationIdentityFactory.ENCOUNTER_CONFIG_ID,
        &"quest_flags:npc_renderer_capture"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return {"accepted": false}
    var compose := TowerFloorRuntimeComposer.build(manifest, TOWER_VISUALS)
    if not bool(compose.get("accepted", false)):
        return {"accepted": false}
    var floor := TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:npc_renderer_f2", manifest)
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
