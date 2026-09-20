class_name Region3FunctionalBuildingVisual
extends Node2D

@export var profile: Region3FunctionalBuildingVisualProfile
@export_node_path("Sprite2D") var sprite_path: NodePath = NodePath("Sprite")
@export var force_nearest_filtering: bool = true

@onready var sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D

func _ready() -> void:
    apply_profile()

func apply_profile() -> bool:
    if profile == null or sprite == null:
        return false
    if not profile.validate_profile().is_empty():
        return false
    sprite.texture = profile.texture
    sprite.position = profile.sprite_offset
    sprite.scale = profile.sprite_scale
    sprite.z_index = profile.z_index
    sprite.modulate = profile.modulate
    if force_nearest_filtering:
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return true
