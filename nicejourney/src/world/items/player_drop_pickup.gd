class_name PlayerDropPickup
extends Area2D

signal pickup_requested(source_id: StringName, pickup: Area2D)

var source_id: StringName = &""
var item_instance_id: StringName = &""
var definition_id: StringName = &""
var quantity: int = 0
var _requires_player_exit: bool = true
var _request_in_flight: bool = false


func configure(
    new_source_id: StringName,
    new_item_instance_id: StringName,
    new_definition_id: StringName,
    new_quantity: int,
    local_position: Vector2,
    require_player_exit: bool = true
) -> bool:
    if not StableId.is_valid(String(new_source_id)):
        return false
    if not StableId.is_valid(String(new_item_instance_id)) or not StableId.is_valid(String(new_definition_id)):
        return false
    if new_quantity <= 0 or not is_finite(local_position.x) or not is_finite(local_position.y):
        return false
    source_id = new_source_id
    item_instance_id = new_item_instance_id
    definition_id = new_definition_id
    quantity = new_quantity
    position = local_position
    _requires_player_exit = require_player_exit
    _request_in_flight = false
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    monitorable = false
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)
    if not body_exited.is_connected(_on_body_exited):
        body_exited.connect(_on_body_exited)
    return true


func resolve_pickup_attempt(collected: bool) -> void:
    if collected:
        monitoring = false
        queue_free()
        return
    _request_in_flight = false


func requires_player_exit() -> bool:
    return _requires_player_exit


func _on_body_entered(body: Node2D) -> void:
    if source_id == &"" or not body is PlayerController:
        return
    if _requires_player_exit or _request_in_flight:
        return
    _request_in_flight = true
    pickup_requested.emit(source_id, self)


func _on_body_exited(body: Node2D) -> void:
    if not body is PlayerController:
        return
    _requires_player_exit = false
