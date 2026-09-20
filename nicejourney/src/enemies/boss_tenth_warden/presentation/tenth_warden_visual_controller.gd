class_name TenthWardenVisualController
extends Node2D

@export var profile: TenthWardenVisualProfile
@export_node_path("Sprite2D") var body_path: NodePath = NodePath("Body")
@export_node_path("ColorRect") var playtest_body_path: NodePath = NodePath("PlaytestBody")
@export_node_path("ColorRect") var weak_point_marker_path: NodePath = NodePath("WeakPointMarker")
@export var playtest_phase_one_color: Color = Color(0.25, 0.65, 0.9, 1.0)
@export var playtest_phase_two_color: Color = Color(0.95, 0.45, 0.3, 1.0)
@export var playtest_weak_point_color: Color = Color(1.0, 0.92, 0.25, 1.0)
@export_node_path("AnimationPlayer") var animation_player_path: NodePath = NodePath("AnimationPlayer")
@export_node_path("EffectSpritePresenter") var telegraph_presenter_path: NodePath = NodePath("TelegraphPresenter")

@onready var body: Sprite2D = get_node_or_null(body_path) as Sprite2D
@onready var playtest_body: ColorRect = get_node_or_null(playtest_body_path) as ColorRect
@onready var weak_point_marker: ColorRect = get_node_or_null(weak_point_marker_path) as ColorRect
var _playtest_phase_two: bool = false
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
    _playtest_phase_two = false
    if playtest_body != null:
        playtest_body.visible = true
        playtest_body.color = playtest_phase_one_color
    if weak_point_marker != null:
        weak_point_marker.visible = false
    hide_telegraph()
    return play_semantic(profile.idle_animation)

func play_semantic(animation_name: StringName) -> bool:
    if animation_player == null or animation_name == &"" or not animation_player.has_animation(animation_name):
        return false
    hide_telegraph()
    animation_player.play(animation_name)
    if playtest_body != null:
        if animation_name == profile.phase_two_animation:
            _playtest_phase_two = true
            playtest_body.color = playtest_phase_two_color
        elif animation_name == profile.death_animation:
            playtest_body.visible = false
    return true

func set_weak_point_exposed(exposed: bool) -> void:
    if weak_point_marker != null:
        weak_point_marker.visible = exposed
    if playtest_body != null:
        playtest_body.color = playtest_weak_point_color if exposed else (playtest_phase_two_color if _playtest_phase_two else playtest_phase_one_color)

func play_move(move_id: StringName) -> bool:
    if profile == null:
        return false
    var binding: TenthWardenMoveVisualBinding = profile.find_move(move_id)
    if binding == null:
        return false
    if not play_semantic(binding.animation_name):
        return false
    if telegraph_presenter != null and binding.telegraph_profile != null:
        if telegraph_presenter.configure_profile(binding.telegraph_profile, true):
            telegraph_presenter.visible = true
    return true

func hide_telegraph() -> void:
    if telegraph_presenter != null:
        telegraph_presenter.visible = false
        if telegraph_presenter.animation_player != null:
            telegraph_presenter.animation_player.stop()
