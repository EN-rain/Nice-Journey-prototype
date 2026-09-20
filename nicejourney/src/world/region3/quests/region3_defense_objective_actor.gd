class_name Region3DefenseObjectiveActor
extends Node2D

signal health_changed(current_hp: int, max_hp: int)
signal destroyed

@export_range(1, 1000, 1) var max_hp: int = 120
@export var body_color: Color = Color(0.48, 0.75, 0.99, 1.0)
@export var body_size: Vector2 = Vector2(26.0, 30.0)
var current_hp: int = 0
var _health_label: Label = null

func _ready() -> void:
    if current_hp <= 0:
        current_hp = max_hp
    _health_label = Label.new()
    _health_label.name = "ObjectiveHealth"
    _health_label.position = Vector2(-40.0, -55.0)
    _health_label.z_index = 20
    add_child(_health_label)
    _refresh()

func configure(new_max_hp: int) -> bool:
    if new_max_hp <= 0:
        return false
    max_hp = new_max_hp
    current_hp = max_hp
    health_changed.emit(current_hp, max_hp)
    _refresh()
    return true

func apply_damage(amount: int) -> bool:
    if amount <= 0 or current_hp <= 0:
        return false
    current_hp = maxi(0, current_hp - amount)
    health_changed.emit(current_hp, max_hp)
    _refresh()
    if current_hp == 0:
        destroyed.emit()
    return true

func _refresh() -> void:
    if _health_label != null and is_instance_valid(_health_label):
        _health_label.text = "DEFEND %d/%d" % [current_hp, max_hp]
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(-body_size * 0.5, body_size), body_color, true)
    draw_rect(Rect2(-body_size * 0.5, body_size), Color(0.08, 0.13, 0.29), false, 2.0)
    draw_rect(Rect2(-20.0, -28.0, 40.0, 4.0), Color(0.15, 0.17, 0.17))
    draw_rect(Rect2(-20.0, -28.0, 40.0 * float(current_hp) / float(maxi(1, max_hp)), 4.0), Color(0.24, 0.91, 0.64))
