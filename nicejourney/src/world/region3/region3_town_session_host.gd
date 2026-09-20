class_name Region3TownSessionHost
extends Node2D

const START_ROLE_ID: StringName = &"quest_hall"

var active_runtime_root: Region3AuthoredTownLayout = null
var _suspended: bool = false


func activate(
    runtime_root: Region3AuthoredTownLayout,
    player: PlayerController,
    camera: PixelCamera,
    arrival_position: Vector2
) -> bool:
    if runtime_root == null or player == null or camera == null:
        return false
    if runtime_root.get_parent() != null or not runtime_root.validate_layout().is_empty():
        return false
    if not _finite_position(arrival_position):
        return false
    if not _local_position_within_layout(runtime_root, arrival_position):
        return false

    clear_loaded_region()
    active_runtime_root = runtime_root
    active_runtime_root.name = "ActiveRegion3Town"
    add_child(active_runtime_root)
    _suspended = false
    _apply_player_and_camera(player, camera, arrival_position)
    return true


func suspend() -> bool:
    if not has_active_region():
        return false
    remove_child(active_runtime_root)
    _suspended = true
    return true


func resume(player: PlayerController, camera: PixelCamera, arrival_position: Vector2) -> bool:
    if not has_loaded_region() or not _suspended or player == null or camera == null:
        return false
    if not _finite_position(arrival_position) or not _local_position_within_layout(active_runtime_root, arrival_position):
        return false
    add_child(active_runtime_root)
    _suspended = false
    _apply_player_and_camera(player, camera, arrival_position)
    return true


func clear_loaded_region() -> void:
    _suspended = false
    if active_runtime_root != null and is_instance_valid(active_runtime_root):
        if active_runtime_root.get_parent() == self:
            remove_child(active_runtime_root)
        active_runtime_root.free()
    active_runtime_root = null


func has_loaded_region() -> bool:
    return active_runtime_root != null and is_instance_valid(active_runtime_root)


func has_active_region() -> bool:
    return has_loaded_region() and active_runtime_root.get_parent() == self and not _suspended


func is_suspended() -> bool:
    return has_loaded_region() and _suspended


func get_world_bounds() -> Rect2:
    if not has_loaded_region():
        return Rect2()
    return Rect2(to_global(Vector2.ZERO), _layout_world_size(active_runtime_root))


func resolve_start_position(runtime_root: Region3AuthoredTownLayout = null) -> Vector2:
    var layout := runtime_root if runtime_root != null else active_runtime_root
    if layout == null:
        return Vector2.INF
    for child: Node in layout.get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor == null:
            continue
        if anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            continue
        if anchor.role_id == START_ROLE_ID:
            return anchor.approach_world_position(float(layout.tile_size))
    return Vector2.INF


func get_storage_interaction() -> Region3StorageServiceInteraction:
    if not has_loaded_region():
        return null
    return active_runtime_root.get_node_or_null("StorageHouse/StorageServiceInteraction") as Region3StorageServiceInteraction


func get_functional_service_interactions() -> Array[Region3FunctionalServiceInteraction]:
    var result: Array[Region3FunctionalServiceInteraction] = []
    if not has_loaded_region():
        return result
    for child: Node in active_runtime_root.get_children():
        var anchor := child as Region3TownStructureAnchor
        if anchor == null or anchor.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            continue
        var interaction := anchor.get_node_or_null("ServiceInteraction") as Region3FunctionalServiceInteraction
        if interaction != null:
            result.append(interaction)
    return result


func _apply_player_and_camera(player: PlayerController, camera: PixelCamera, local_position: Vector2) -> void:
    player.global_position = to_global(local_position)
    player.velocity = Vector2.ZERO
    camera.set_world_bounds(Rect2(to_global(Vector2.ZERO), _layout_world_size(active_runtime_root)))
    camera.reset_after_teleport()


func _layout_world_size(layout: Region3AuthoredTownLayout) -> Vector2:
    return Vector2(layout.map_size_tiles * layout.tile_size)


func _local_position_within_layout(layout: Region3AuthoredTownLayout, local_position: Vector2) -> bool:
    var size := _layout_world_size(layout)
    return local_position.x >= 0.0 and local_position.y >= 0.0 and local_position.x < size.x and local_position.y < size.y


func _finite_position(position: Vector2) -> bool:
    return is_finite(position.x) and is_finite(position.y)


func _exit_tree() -> void:
    clear_loaded_region()
