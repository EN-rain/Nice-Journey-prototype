extends SceneTree

const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const STORAGE_INTERACTION_SCRIPT: Script = preload("res://src/world/region3/interactions/region3_storage_service_interaction.gd")

var _failures := 0
var _request_count := 0
var _last_structure_id: StringName = &""
var _last_role_id: StringName = &""


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    var player := PLAYER_SCENE.instantiate() as PlayerController
    var ownership := InputOwnership.new()
    var guard := GameplayOperationGuard.new()
    root.add_child(town)
    root.add_child(player)
    root.add_child(ownership)
    root.add_child(guard)
    await process_frame

    var storage_anchor := town.get_node_or_null("StorageHouse") as Region3TownStructureAnchor
    var interaction := town.get_node_or_null("StorageHouse/StorageServiceInteraction") as Area2D
    _expect(storage_anchor != null, "authored Region 3 town exposes the functional Storage House anchor")
    _expect(interaction != null and interaction.get_script() == STORAGE_INTERACTION_SCRIPT, "Storage House owns the dedicated service interaction trigger")
    if storage_anchor == null or interaction == null:
        _finish(town, player, ownership, guard)
        return

    _expect(storage_anchor.structure_id == &"r3:functional:06" and storage_anchor.role_id == &"storage_house", "storage service trigger remains bound to exact authored Storage House identity")
    _expect((interaction.call("validate_authored_binding") as PackedStringArray).is_empty(), "Storage House service interaction validates against its authored functional anchor")
    var expected_approach := storage_anchor.approach_world_position(float(town.tile_size))
    _expect(interaction.global_position.is_equal_approx(town.to_global(expected_approach)), "Storage House interaction position derives exactly from the authored approach tile")
    _expect((interaction.call("authored_approach_world_position") as Vector2).is_equal_approx(expected_approach), "Storage House service exposes the same authored approach position without duplicating coordinates")
    var shape_node := interaction.get_node("CollisionShape2D") as CollisionShape2D
    _expect(shape_node != null and shape_node.shape is CircleShape2D, "Storage House interaction owns a concrete circular proximity shape")
    if shape_node != null and shape_node.shape is CircleShape2D:
        _expect(is_equal_approx((shape_node.shape as CircleShape2D).radius, float(town.tile_size) * 0.75), "Storage interaction radius remains a tile-relative initial tuning value")
    _expect(interaction.collision_layer == 0 and interaction.collision_mask == 1 and interaction.monitoring and not interaction.monitorable, "Storage interaction observes the live player body without becoming world collision")

    _expect(bool(interaction.call("bind_runtime", ownership, guard)), "Storage House service binds shared input and operation-guard owners")
    interaction.connect(&"service_requested", Callable(self, "_on_service_requested"))

    var out_of_range: Dictionary = interaction.call("request_service", &"interaction:storage:out_of_range") as Dictionary
    _expect(not bool(out_of_range.get("admitted", true)) and StringName(out_of_range.get("reason_id", &"")) == InteractionCommitAdmission.REASON_OUT_OF_RANGE, "Storage service rejects Interact outside its authored approach range")
    _expect(_request_count == 0, "out-of-range service request emits no storage-service action")

    interaction.call("_on_body_entered", player)
    _expect(bool(interaction.call("is_player_in_range")), "Storage interaction tracks a PlayerController entering its authored proximity")

    ownership.open_modal(&"ui:test_modal")
    var modal_blocked: Dictionary = interaction.call("request_service", &"interaction:storage:modal_blocked") as Dictionary
    _expect(not bool(modal_blocked.get("admitted", true)) and StringName(modal_blocked.get("reason_id", &"")) == InteractionCommitAdmission.REASON_MENU_OWNERSHIP_BLOCKED, "open modal ownership blocks Storage House service admission")
    ownership.close_modal(&"ui:test_modal")

    var combat_token := guard.acquire_blocker(
        &"combat:storage_interaction_test",
        GameplayOperationGuard.REASON_ACTIVE_COMBAT,
        "Storage unavailable during active combat.",
        [GameplayOperationGuard.OP_SERVICE]
    )
    _expect(combat_token != 0, "Storage interaction fixture acquires authoritative Active Combat service blocker")
    var combat_blocked: Dictionary = interaction.call("request_service", &"interaction:storage:combat_blocked") as Dictionary
    _expect(not bool(combat_blocked.get("admitted", true)) and StringName(combat_blocked.get("reason_id", &"")) == InteractionCommitAdmission.REASON_COMBAT_OWNERSHIP_BLOCKED, "Active Combat blocks Storage House service admission through the shared service guard")
    guard.release_blocker(combat_token)

    var admitted: Dictionary = interaction.call("request_service", &"interaction:storage:accepted") as Dictionary
    _expect(bool(admitted.get("admitted", false)), "ordinary press interaction admits the authored Storage House service when range/modal/combat ownership are valid")
    _expect(StringName(admitted.get("structure_id", &"")) == &"r3:functional:06" and StringName(admitted.get("role_id", &"")) == &"storage_house", "accepted Storage interaction preserves exact structure and service-role identity")
    _expect(_request_count == 1 and _last_structure_id == &"r3:functional:06" and _last_role_id == &"storage_house", "accepted interaction emits exactly one Storage House service request")

    var duplicate: Dictionary = interaction.call("request_service", &"interaction:storage:accepted") as Dictionary
    _expect(not bool(duplicate.get("admitted", true)) and StringName(duplicate.get("reason_id", &"")) == InteractionCommitAdmission.REASON_DUPLICATE_COMMIT, "same logical Storage interaction commit cannot fire twice")
    _expect(_request_count == 1, "duplicate Storage interaction emits no second service request")

    interaction.call("_on_body_exited", player)
    _expect(not bool(interaction.call("is_player_in_range")), "Storage interaction clears range ownership when the player leaves")
    var after_exit: Dictionary = interaction.call("request_service", &"interaction:storage:after_exit") as Dictionary
    _expect(not bool(after_exit.get("admitted", true)) and StringName(after_exit.get("reason_id", &"")) == InteractionCommitAdmission.REASON_OUT_OF_RANGE, "Storage service cannot be invoked remotely after leaving the authored approach")

    _finish(town, player, ownership, guard)


func _on_service_requested(structure_id: StringName, role_id: StringName) -> void:
    _request_count += 1
    _last_structure_id = structure_id
    _last_role_id = role_id


func _finish(town: Node, player: Node, ownership: Node, guard: Node) -> void:
    town.queue_free()
    player.queue_free()
    ownership.queue_free()
    guard.queue_free()
    await process_frame
    if _failures == 0:
        print("REGION 3 STORAGE SERVICE INTERACTION TEST PASS")
    else:
        push_error("REGION 3 STORAGE SERVICE INTERACTION TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
