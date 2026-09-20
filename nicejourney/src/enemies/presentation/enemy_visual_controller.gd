class_name EnemyVisualController
extends Node2D

@export var profile: EnemyVisualProfile
@export_node_path("Sprite2D") var body_path: NodePath = NodePath("Body")
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export_node_path("EffectSpritePresenter") var telegraph_presenter_path: NodePath = NodePath("Telegraph")

@onready var body: Sprite2D = get_node_or_null(body_path) as Sprite2D
@onready var animation_player: AnimationPlayer = get_node_or_null(animation_player_path) as AnimationPlayer
@onready var telegraph_presenter: EffectSpritePresenter = get_node_or_null(telegraph_presenter_path) as EffectSpritePresenter


func _ready() -> void:
    apply_profile()


func apply_profile() -> bool:
    if profile == null or body == null or animation_player == null:
        return false
    if not profile.validate_profile().is_empty():
        return false
    if animation_player.has_animation_library(&""):
        animation_player.remove_animation_library(&"")
    animation_player.add_animation_library(&"", profile.animation_library)
    body.position = profile.body_offset
    body.scale = profile.body_scale
    body.z_index = profile.body_z_index
    body.flip_h = profile.default_facing_left
    if telegraph_presenter != null:
        telegraph_presenter.visible = false
        if profile.telegraph_profile != null:
            if not telegraph_presenter.configure_profile(profile.telegraph_profile, false):
                return false
            telegraph_presenter.position = profile.telegraph_offset
            telegraph_presenter.scale = profile.telegraph_scale
            telegraph_presenter.rotation_degrees = profile.telegraph_rotation_degrees
    animation_player.play(profile.idle_animation)
    return true


func play_semantic(animation_name: StringName) -> bool:
    if animation_player == null or animation_name == &"" or not animation_player.has_animation(animation_name):
        return false
    if profile != null and animation_name == profile.windup_animation:
        show_telegraph()
    elif profile != null and animation_name in [profile.release_animation, profile.hit_animation, profile.death_animation]:
        hide_telegraph()
    animation_player.play(animation_name)
    return true


func set_facing_left(facing_left: bool) -> void:
    if body != null:
        body.flip_h = facing_left


func show_telegraph() -> bool:
    if profile == null or profile.telegraph_profile == null or telegraph_presenter == null:
        return false
    telegraph_presenter.visible = true
    return telegraph_presenter.replay()


func hide_telegraph() -> void:
    if telegraph_presenter != null:
        telegraph_presenter.visible = false
