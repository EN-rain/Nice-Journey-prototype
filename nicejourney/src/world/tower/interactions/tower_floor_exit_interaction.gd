class_name TowerFloorExitInteraction
extends Area2D

signal player_entered(floor_id: int, room_instance_id: StringName)
signal player_exited(floor_id: int, room_instance_id: StringName)

var floor_id: int = 0
var room_instance_id: StringName = &""

func configure(new_floor_id: int, new_room_instance_id: StringName) -> bool:
    if new_floor_id < 1 or new_floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return false
    if not StableId.is_valid(String(new_room_instance_id)):
        return false
    floor_id = new_floor_id
    room_instance_id = new_room_instance_id
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    monitorable = false
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)
    if not body_exited.is_connected(_on_body_exited):
        body_exited.connect(_on_body_exited)
    return true

func _on_body_entered(body: Node2D) -> void:
    if floor_id <= 0 or room_instance_id == &"" or not body is PlayerController:
        return
    player_entered.emit(floor_id, room_instance_id)

func _on_body_exited(body: Node2D) -> void:
    if floor_id <= 0 or room_instance_id == &"" or not body is PlayerController:
        return
    player_exited.emit(floor_id, room_instance_id)
