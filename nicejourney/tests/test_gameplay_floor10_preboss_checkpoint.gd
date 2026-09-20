extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const TOWER_VISUAL_CATALOG: TowerRoomVisualCatalog = preload("res://src/world/tower/presentation/tower_room_visual_catalog.tres")
const TEST_SAVE_ROOT := "user://tests/gameplay_floor10_preboss_checkpoint"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(TEST_SAVE_ROOT)
    save_service.delete_slot(1)
    var profile := ProfileCreationService.create_profile(1, "Preboss Checkpoint", "melee")
    _expect(profile != null and save_service.save_profile(1, profile) == OK, "Floor 10 pre-boss fixture creates and persists")
    if profile == null:
        quit(1)
        return

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "Floor 10 pre-boss fixture supplies save ownership")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world(), "Floor 10 pre-boss fixture starts in Region 3")

    var floor := _floor10_state()
    _expect(floor != null and TowerFloorStateService.commit_floor_state(profile, floor), "Floor 10 fixture commits generated state with authored pre-boss checkpoint")
    if floor == null:
        gameplay.queue_free()
        await process_frame
        quit(1)
        return
    var checkpoint_id: StringName = &"checkpoint:floor10_preboss"
    var anchor := floor.get_checkpoint_anchor(checkpoint_id)
    var preboss_room_id := StringName(String(anchor.get("room_instance_id", &"")))
    _expect(preboss_room_id != &"", "Floor 10 checkpoint has an unambiguous authored room owner")
    var checkpoint_arrival := TowerArrivalResolver.resolve_checkpoint(floor, checkpoint_id)
    _expect(bool(checkpoint_arrival.get("accepted", false)) and StringName(String(checkpoint_arrival.get("room_instance_id", &""))) == preboss_room_id, "Floor 10 pre-boss anchor resolves through the existing arrival validator")

    var build := TowerFloorRuntimeComposer.build(floor.layout_manifest, TOWER_VISUAL_CATALOG)
    var entrance := TowerArrivalResolver.resolve_entrance(floor)
    _expect(bool(build.get("accepted", false)) and bool(entrance.get("accepted", false)), "Floor 10 live runtime composes")
    _expect(gameplay.activate_committed_tower_travel({"accepted": true, "runtime_root": build.get("root"), "arrival": entrance}), "Floor 10 live runtime activates")
    var trigger := _discovery_trigger(gameplay.tower_floor_session_host.active_runtime_root, preboss_room_id)
    _expect(trigger != null, "authored pre-boss safe room has a physical discovery trigger")
    if trigger != null and bool(checkpoint_arrival.get("accepted", false)):
        var world_tile := checkpoint_arrival.get("world_tile", Vector2i.ZERO) as Vector2i
        gameplay.player.global_position = gameplay.tower_floor_session_host.to_global((Vector2(world_tile) + Vector2(0.5, 0.5)) * float(TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE))
        gameplay.player.velocity = Vector2.ZERO

        gameplay.shared_active_combat.acquire(&"encounter:preboss_entry_test", ActiveCombatRegistry.REASON_ENGAGED_HOSTILE_ENCOUNTER)
        trigger.emit_signal(&"player_entered", preboss_room_id)
        _expect(
            StringName(String(gameplay.last_floor10_preboss_checkpoint_result.get("reason_id", &""))) == GameplayOperationGuard.REASON_ACTIVE_COMBAT,
            "pre-boss checkpoint does not commit while Active Combat is unresolved"
        )
        _expect(StringName(String(profile.safe_state.get("checkpoint_anchor_id", &""))) != checkpoint_id, "combat-blocked pre-boss entry does not advance the safe snapshot")
        gameplay.shared_active_combat.release_source(&"encounter:preboss_entry_test")

        trigger.emit_signal(&"player_entered", preboss_room_id)
        var committed := gameplay.last_floor10_preboss_checkpoint_result
        _expect(bool(committed.get("accepted", false)) and bool(committed.get("changed", false)), "first physical pre-boss room entry outside combat commits the checkpoint")
        _expect(int(profile.safe_state.get("floor_id", 0)) == 10 and StringName(String(profile.safe_state.get("checkpoint_anchor_id", &""))) == checkpoint_id, "live profile advances to the exact authored pre-boss checkpoint")
        var sequence := int(profile.safe_state.get("snapshot_sequence", -1))
        var durable := save_service.load_profile(1)
        _expect(durable != null and StringName(String(durable.safe_state.get("checkpoint_anchor_id", &""))) == checkpoint_id, "pre-boss checkpoint is durable through SaveService")

        trigger.emit_signal(&"player_entered", preboss_room_id)
        _expect(
            bool(gameplay.last_floor10_preboss_checkpoint_result.get("accepted", false))
            and StringName(String(gameplay.last_floor10_preboss_checkpoint_result.get("reason_id", &""))) == &"already_committed"
            and int(profile.safe_state.get("snapshot_sequence", -1)) == sequence,
            "re-entering the pre-boss room is idempotent and does not create another checkpoint generation"
        )

    gameplay.queue_free()
    await process_frame
    save_service.delete_slot(1)
    if _failures == 0:
        print("GAMEPLAY FLOOR 10 PREBOSS CHECKPOINT TEST PASS")
    else:
        push_error("GAMEPLAY FLOOR 10 PREBOSS CHECKPOINT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _floor10_state() -> FloorInstanceState:
    var request := TowerFloorGenerationCommitService.build_request(
        10,
        101010,
        &"tower_generator:v01",
        &"tower_modules:v01",
        &"encounters:v01",
        &"quest_flags:manual_save_preboss"
    )
    var manifest := TowerPrevalidatedFallbackFactory.build_for_request(request)
    if manifest.is_empty():
        return null
    return TowerFloorGenerationCommitService.floor_state_from_manifest(&"floor_instance:manual_save_preboss", manifest)


func _discovery_trigger(root_node: Node2D, room_instance_id: StringName) -> Node:
    if root_node == null:
        return null
    var rooms := root_node.get_node_or_null("Rooms")
    if rooms == null:
        return null
    for room_node: Node in rooms.get_children():
        if StringName(String(room_node.get_meta(&"room_instance_id", &""))) != room_instance_id:
            continue
        return room_node.get_node_or_null("DiscoveryTrigger")
    return null


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
