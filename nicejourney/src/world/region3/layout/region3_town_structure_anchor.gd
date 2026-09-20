class_name Region3TownStructureAnchor
extends Node2D

@export var structure_id: StringName = &""
@export var category: StringName = &""
@export var role_id: StringName = &""
@export var lot_min: Vector2i = Vector2i.ZERO
@export var lot_max: Vector2i = Vector2i.ZERO
@export var door_facing: StringName = &"south"
@export var entrance_tile: Vector2i = Vector2i(-1, -1)
@export var approach_tile: Vector2i = Vector2i(-1, -1)
@export var functional_profile: Region3FunctionalBuildingVisualProfile
@export var decorative_profile: Region3DecorativeBuildingVisualProfile
@export_node_path("Sprite2D") var sprite_path: NodePath = NodePath("Sprite")
@export var force_nearest_filtering: bool = true

@onready var sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D

func _ready() -> void:
    apply_visual()

func validate_anchor() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(structure_id)):
        errors.append("structure_id must be a stable ID")
    if category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL and category != Region3TownStructureManifestValidator.CATEGORY_DECORATIVE:
        errors.append("category must be functional or decorative")
    if lot_min.x > lot_max.x or lot_min.y > lot_max.y:
        errors.append("lot bounds must be ordered")
    if door_facing not in [&"north", &"south", &"east", &"west"]:
        errors.append("door_facing must be north/south/east/west")
    if category == Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
        if not _is_entrance_on_facing_boundary():
            errors.append("entrance_tile must sit on the declared door-facing lot boundary")
        if approach_tile != _expected_approach_tile():
            errors.append("approach_tile must be exactly one tile outward from entrance_tile")
        if functional_profile == null:
            errors.append("functional_profile is required for functional structures")
        else:
            if role_id != functional_profile.role_id:
                errors.append("role_id must match functional_profile.role_id")
            for profile_error: String in functional_profile.validate_profile():
                errors.append("functional_profile: %s" % profile_error)
        if decorative_profile != null:
            errors.append("functional structures must not use decorative_profile")
    elif category == Region3TownStructureManifestValidator.CATEGORY_DECORATIVE:
        if role_id != &"":
            errors.append("decorative structures must not claim a functional role_id")
        if decorative_profile == null:
            errors.append("decorative_profile is required for decorative structures")
        else:
            if structure_id != decorative_profile.structure_id:
                errors.append("structure_id must match decorative_profile.structure_id")
            for profile_error: String in decorative_profile.validate_profile():
                errors.append("decorative_profile: %s" % profile_error)
        if functional_profile != null:
            errors.append("decorative structures must not use functional_profile")
    return errors

func expected_world_position(tile_size: float) -> Vector2:
    var center := (Vector2(lot_min) + Vector2(lot_max)) * 0.5
    return center * tile_size

func entrance_world_position(tile_size: float) -> Vector2:
    return Vector2(entrance_tile) * tile_size

func approach_world_position(tile_size: float) -> Vector2:
    return Vector2(approach_tile) * tile_size

func _is_entrance_on_facing_boundary() -> bool:
    if entrance_tile.x < lot_min.x or entrance_tile.x > lot_max.x or entrance_tile.y < lot_min.y or entrance_tile.y > lot_max.y:
        return false
    match door_facing:
        &"north":
            return entrance_tile.y == lot_min.y
        &"south":
            return entrance_tile.y == lot_max.y
        &"west":
            return entrance_tile.x == lot_min.x
        &"east":
            return entrance_tile.x == lot_max.x
        _:
            return false

func _expected_approach_tile() -> Vector2i:
    match door_facing:
        &"north":
            return entrance_tile + Vector2i.UP
        &"south":
            return entrance_tile + Vector2i.DOWN
        &"west":
            return entrance_tile + Vector2i.LEFT
        &"east":
            return entrance_tile + Vector2i.RIGHT
        _:
            return Vector2i(-1, -1)

func apply_visual() -> bool:
    if sprite == null or not validate_anchor().is_empty():
        return false
    if category == Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
        sprite.texture = functional_profile.texture
        sprite.position = functional_profile.sprite_offset
        sprite.scale = functional_profile.sprite_scale
        sprite.z_index = functional_profile.z_index
        sprite.modulate = functional_profile.modulate
    else:
        sprite.texture = decorative_profile.texture
        sprite.position = decorative_profile.sprite_offset
        sprite.scale = decorative_profile.sprite_scale
        sprite.z_index = decorative_profile.z_index
        sprite.modulate = decorative_profile.modulate
    if force_nearest_filtering:
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return true
