class_name EffectSpritePresenter
extends Node2D

@export var profile: EffectVisualProfile
@export_node_path("Sprite2D") var sprite_path: NodePath = NodePath("Sprite")
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export var force_nearest_filtering: bool = true

@onready var sprite: Sprite2D = get_node_or_null(sprite_path) as Sprite2D
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer

func _ready() -> void:
    apply_profile()

func apply_profile() -> bool:
    if profile == null or sprite == null or animation_player == null:
        return false
    if not profile.validate_profile().is_empty():
        return false
    sprite.texture = profile.texture
    sprite.position = profile.sprite_offset
    sprite.scale = profile.sprite_scale
    sprite.rotation_degrees = profile.rotation_degrees
    sprite.z_index = profile.z_index
    sprite.modulate = profile.modulate
    if force_nearest_filtering:
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    if animation_player.has_animation_library(&""):
        animation_player.remove_animation_library(&"")
    animation_player.add_animation_library(&"", profile.animation_library)
    animation_player.play(profile.default_animation)
    return true

func configure_profile(new_profile: EffectVisualProfile, play_immediately: bool = true) -> bool:
    profile = new_profile
    if not apply_profile():
        return false
    if not play_immediately:
        animation_player.stop()
    return true

func replay() -> bool:
    if profile == null or animation_player == null or not animation_player.has_animation(profile.default_animation):
        return false
    animation_player.play(profile.default_animation)
    return true
