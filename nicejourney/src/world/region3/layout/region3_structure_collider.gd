class_name Region3StructureCollider
extends StaticBody2D

@export var structure_id: StringName = &""
@export var collision_tile_min: Vector2i = Vector2i.ZERO
@export var collision_tile_max: Vector2i = Vector2i.ZERO
@export_range(1, 128, 1) var tile_size: int = 32
@export_node_path("CollisionShape2D") var collision_shape_path: NodePath = NodePath("CollisionShape2D")

@onready var collision_shape: CollisionShape2D = get_node_or_null(collision_shape_path) as CollisionShape2D

func _ready() -> void:
    apply_geometry()

func validate_collider() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(structure_id)):
        errors.append("structure_id must be a stable ID")
    if tile_size <= 0:
        errors.append("tile_size must be positive")
    if collision_tile_min.x >= collision_tile_max.x or collision_tile_min.y >= collision_tile_max.y:
        errors.append("collision tile bounds must describe a positive rectangle")
    if collision_shape == null:
        errors.append("collision_shape is required")
    else:
        var rectangle := collision_shape.shape as RectangleShape2D
        if rectangle == null:
            errors.append("collision_shape must use RectangleShape2D")
        else:
            var expected_size := _expected_collision_size()
            if not rectangle.size.is_equal_approx(expected_size):
                errors.append("collision shape size must match authored tile bounds")
    if not position.is_equal_approx(expected_world_position()):
        errors.append("collider world position must match authored tile bounds")
    return errors

func expected_world_position() -> Vector2:
    return (Vector2(collision_tile_min) + Vector2(collision_tile_max)) * 0.5 * float(tile_size)

func contains_tile(tile: Vector2i) -> bool:
    return (
        tile.x >= collision_tile_min.x
        and tile.x <= collision_tile_max.x
        and tile.y >= collision_tile_min.y
        and tile.y <= collision_tile_max.y
    )

func apply_geometry() -> bool:
    if collision_shape == null or tile_size <= 0:
        return false
    if collision_tile_min.x >= collision_tile_max.x or collision_tile_min.y >= collision_tile_max.y:
        return false
    var rectangle := collision_shape.shape as RectangleShape2D
    if rectangle == null:
        rectangle = RectangleShape2D.new()
        collision_shape.shape = rectangle
    rectangle.size = _expected_collision_size()
    position = expected_world_position()
    return true

func _expected_collision_size() -> Vector2:
    # collision_tile_min/max identify inclusive tile centers. The physical rectangle must
    # cover the complete footprint of every authored tile, including both endpoints.
    return Vector2(collision_tile_max - collision_tile_min + Vector2i.ONE) * float(tile_size)
