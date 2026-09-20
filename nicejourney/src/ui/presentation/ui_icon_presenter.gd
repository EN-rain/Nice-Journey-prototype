class_name UiIconPresenter
extends TextureRect

@export var profile: UiIconProfile
@export var force_nearest_filtering: bool = true

func _ready() -> void:
    apply_profile()

func configure_profile(new_profile: UiIconProfile) -> bool:
    profile = new_profile
    return apply_profile()

func apply_profile() -> bool:
    if profile == null or not profile.validate_profile().is_empty():
        return false
    texture = profile.texture
    custom_minimum_size = profile.minimum_size
    expand_mode = profile.expand_mode
    stretch_mode = profile.stretch_mode
    if force_nearest_filtering:
        texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    return true
