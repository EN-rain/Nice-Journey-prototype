class_name ForegroundOccluder
extends Node2D

@export var target_path: NodePath
@export var visual_path: NodePath
@export var local_occlusion_rect: Rect2 = Rect2(-32.0, -64.0, 64.0, 64.0)
@export_range(0.1, 1.0, 0.05) var occluded_alpha: float = 0.35

var _target: Node2D = null
var _visual: CanvasItem = null
var _base_modulate: Color = Color.WHITE
var _occluded: bool = false

func _ready() -> void:
    _target = get_node_or_null(target_path) as Node2D
    _visual = get_node_or_null(visual_path) as CanvasItem
    if _visual != null:
        _base_modulate = _visual.modulate

func _process(_delta: float) -> void:
    if _target == null or not is_instance_valid(_target):
        return
    update_occlusion_for_world_point(_target.global_position)

func update_occlusion_for_world_point(world_point: Vector2) -> void:
    set_occluded(local_occlusion_rect.has_point(to_local(world_point)))

func set_occluded(occluded: bool) -> void:
    _occluded = occluded
    if _visual == null:
        return
    var next_modulate: Color = _base_modulate
    next_modulate.a = _base_modulate.a * (occluded_alpha if _occluded else 1.0)
    _visual.modulate = next_modulate

func is_occluded() -> bool:
    return _occluded
