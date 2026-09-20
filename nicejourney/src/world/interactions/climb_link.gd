class_name ClimbLink
extends Area2D

@export var landing_path: NodePath = ^"Landing"
@export var player_compatible: bool = true

var _landing: Marker2D = null

func _ready() -> void:
    _landing = get_node_or_null(landing_path) as Marker2D
    body_entered.connect(_on_body_entered)
    body_exited.connect(_on_body_exited)

func get_landing_global_position() -> Vector2:
    if _landing == null:
        return global_position
    return _landing.global_position

func has_valid_landing() -> bool:
    return _landing != null

func can_player_use(player: PlayerController) -> bool:
    if not player_compatible or _landing == null or player == null:
        return false
    return player.can_occupy_global_position(_landing.global_position)

func _on_body_entered(body: Node) -> void:
    var player: PlayerController = body as PlayerController
    if player != null:
        player.set_active_climb_link(self)

func _on_body_exited(body: Node) -> void:
    var player: PlayerController = body as PlayerController
    if player != null:
        player.clear_active_climb_link(self)
