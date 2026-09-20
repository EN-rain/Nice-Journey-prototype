class_name NpcVisualPresenter
extends Node2D

@export var profile: NpcVisualProfile = null
@export var semantic_state: StringName = &"idle"
@export var facing_right: bool = true

var sprite: Sprite2D = null
var animation_player: AnimationPlayer = null

func _ready() -> void:
    if profile == null or not profile.validate_presentation().is_empty(): return
    if profile.texture != null:
        sprite = Sprite2D.new()
        sprite.name = "NpcSprite"
        sprite.texture = profile.texture
        sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        sprite.flip_h = not facing_right and profile.mirror_left
        sprite.hframes = maxi(1, profile.texture.get_width() / profile.frame_size.x)
        sprite.vframes = maxi(1, profile.texture.get_height() / profile.frame_size.y)
        # Parent origin is the gameplay ground anchor; offset the centered sprite so
        # source pixel (16,29) lands exactly at the parent origin.
        sprite.position = Vector2(profile.frame_size) * 0.5 - profile.ground_anchor
        add_child(sprite)
    if profile.animation_library != null:
        animation_player = AnimationPlayer.new()
        animation_player.name = "NpcAnimationPlayer"
        animation_player.add_animation_library(&"", profile.animation_library)
        add_child(animation_player)
        play_semantic_state(semantic_state)

func set_semantic_state(next_state: StringName) -> void:
    # Replaying a looping walk every physics tick would freeze it on frame zero.
    if semantic_state == next_state:
        return
    semantic_state = next_state
    play_semantic_state(next_state)

func play_semantic_state(state: StringName) -> void:
    if animation_player == null or profile == null: return
    var animation_name := profile.animation_for_semantic_state(state)
    if animation_player.has_animation(animation_name): animation_player.play(animation_name)
