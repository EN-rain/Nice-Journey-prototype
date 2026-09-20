class_name StarterWeaponVisual
extends Node2D

@export_node_path("Sprite2D") var main_hand_path: NodePath = NodePath("../WeaponPivot/MainHand")
@export_node_path("Sprite2D") var shield_visual_path: NodePath = NodePath("../BodyVisual/ShieldVisual")
@export var class_profiles: Array[StarterWeaponVisualProfile] = []
@export var force_nearest_filtering: bool = true

@onready var main_hand: Sprite2D = get_node_or_null(main_hand_path) as Sprite2D
@onready var shield_visual: Sprite2D = get_node_or_null(shield_visual_path) as Sprite2D

var _class_id: StringName = &""


func _ready() -> void:
    _apply_filtering()


func configure_class(class_id: StringName) -> bool:
    if main_hand == null or shield_visual == null:
        return false
    var profile: StarterWeaponVisualProfile = _find_profile(class_id)
    if profile == null or not profile.validate_profile().is_empty():
        _clear_visuals()
        return false

    _class_id = class_id
    main_hand.texture = profile.main_hand_texture
    main_hand.position = profile.main_hand_position
    main_hand.rotation_degrees = profile.main_hand_rotation_degrees
    main_hand.scale = profile.main_hand_scale

    shield_visual.texture = profile.shield_texture
    shield_visual.position = profile.shield_position
    shield_visual.rotation_degrees = profile.shield_rotation_degrees
    shield_visual.scale = profile.shield_scale
    shield_visual.visible = profile.shield_visible

    _apply_filtering()
    return true


func get_class_id() -> StringName:
    return _class_id


func get_main_hand_texture() -> Texture2D:
    return main_hand.texture if main_hand != null else null


func has_visible_shield() -> bool:
    return shield_visual != null and shield_visual.visible and shield_visual.texture != null


func get_profile(class_id: StringName) -> StarterWeaponVisualProfile:
    return _find_profile(class_id)


func _find_profile(class_id: StringName) -> StarterWeaponVisualProfile:
    for profile: StarterWeaponVisualProfile in class_profiles:
        if profile != null and profile.class_id == class_id:
            return profile
    return null


func _clear_visuals() -> void:
    _class_id = &""
    if main_hand != null:
        main_hand.texture = null
        main_hand.position = Vector2.ZERO
        main_hand.rotation = 0.0
        main_hand.scale = Vector2.ONE
    if shield_visual != null:
        shield_visual.texture = null
        shield_visual.visible = false
        shield_visual.position = Vector2.ZERO
        shield_visual.rotation = 0.0
        shield_visual.scale = Vector2.ONE


func _apply_filtering() -> void:
    if not force_nearest_filtering:
        return
    if main_hand != null:
        main_hand.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    if shield_visual != null:
        shield_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
