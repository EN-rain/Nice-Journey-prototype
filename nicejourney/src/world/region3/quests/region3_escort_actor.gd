class_name Region3EscortActor
extends CharacterBody2D

signal health_changed(current_hp: int, max_hp: int)
signal actor_defeated

@export_range(1, 1000, 1) var max_hp: int = 90
@export var body_color: Color = Color(0.31, 0.83, 0.72, 1.0)
@export_range(2.0, 28.0, 0.1) var body_radius_px: float = 10.0
@export var npc_visual_profile: NpcVisualProfile = preload("res://src/world/npc/presentation/profiles/temporary_escort.tres")
var current_hp: int = 0

func _ready() -> void:
    if current_hp <= 0:
        current_hp = max_hp
    if _has_accepted_visual_profile():
        var presenter := NpcVisualPresenter.new()
        presenter.name = "NpcVisualPresenter"
        presenter.profile = npc_visual_profile
        add_child(presenter)
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
    var health_y := -body_radius_px - 8.0
    if _has_accepted_visual_profile():
        # Keep the existing HP presentation above the accepted 32px actor body.
        health_y = -npc_visual_profile.ground_anchor.y - 6.0
    else:
        draw_circle(Vector2.ZERO, body_radius_px, body_color)
        draw_arc(Vector2.ZERO, body_radius_px + 1.0, 0.0, TAU, 16, Color(0.09, 0.22, 0.22), 2.0)
    var health_width := body_radius_px * 2.4
    draw_rect(Rect2(-health_width * 0.5, health_y, health_width, 3.0), Color(0.15, 0.17, 0.17))
    draw_rect(Rect2(-health_width * 0.5, health_y, health_width * float(current_hp) / float(maxi(1, max_hp)), 3.0), Color(0.3, 0.92, 0.52))

func _has_accepted_visual_profile() -> bool:
    return npc_visual_profile != null and npc_visual_profile.texture != null and npc_visual_profile.validate_presentation().is_empty()
