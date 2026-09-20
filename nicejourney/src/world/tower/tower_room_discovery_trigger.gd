class_name TowerRoomDiscoveryTrigger
extends Area2D

signal player_entered(room_instance_id: StringName)

var room_instance_id: StringName = &""


func configure(new_room_instance_id: StringName) -> bool:
    if not StableId.is_valid(String(new_room_instance_id)):
        return false
    room_instance_id = new_room_instance_id
    collision_layer = 0
    collision_mask = 1
    monitoring = true
    monitorable = false
    if not body_entered.is_connected(_on_body_entered):
        body_entered.connect(_on_body_entered)
    return true


func _on_body_entered(body: Node2D) -> void:
    if room_instance_id == &"" or not body is PlayerController:
        return
    player_entered.emit(room_instance_id)
