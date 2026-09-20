class_name Region3EscortActor
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal actor_defeated

@export_range(1, 1000, 1) var max_hp: int = 90
@export var body_color: Color = Color(0.31, 0.83, 0.72, 1.0)
@export_range(2.0, 28.0, 0.1) var body_radius_px: float = 10.0
var current_hp: int = 0

func _ready() -> void:
    if current_hp <= 0:
        current_hp = max_hp
    queue_redraw()

func configure(new_max_hp: int) -> bool:
    if new_max_hp <= 0:
        return false
    max_hp = new_max_hp
    current_hp = max_hp
    health_changed.emit(current_hp, max_hp)
    queue_redraw()
    return true

func apply_damage(amount: int) -> bool:
    if amount <= 0 or current_hp <= 0:
        return false
    current_hp = maxi(0, current_hp - amount)
    health_changed.emit(current_hp, max_hp)
    queue_redraw()
    if current_hp == 0:
        actor_defeated.emit()
    return true

func _draw() -> void:
    draw_circle(Vector2.ZERO, body_radius_px, body_color)
    draw_arc(Vector2.ZERO, body_radius_px + 1.0, 0.0, TAU, 16, Color(0.09, 0.22, 0.22), 2.0)
    var health_width := body_radius_px * 2.4
    draw_rect(Rect2(-health_width * 0.5, -body_radius_px - 8.0, health_width, 3.0), Color(0.15, 0.17, 0.17))
    draw_rect(Rect2(-health_width * 0.5, -body_radius_px - 8.0, health_width * float(current_hp) / float(maxi(1, max_hp)), 3.0), Color(0.3, 0.92, 0.52))
