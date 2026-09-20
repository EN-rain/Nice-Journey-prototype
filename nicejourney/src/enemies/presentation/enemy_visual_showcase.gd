extends Node2D

@export var preview_animation: StringName = &"windup"

func _ready() -> void:
    for child: Node in $EnemyRow.get_children():
        var visual := child as EnemyVisualController
        if visual != null:
            visual.play_semantic(preview_animation)
