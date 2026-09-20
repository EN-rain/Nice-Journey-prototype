extends SceneTree

const SHOWCASE: PackedScene = preload("res://src/world/tower/presentation/tower_room_visual_showcase.tscn")

var _failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var showcase := SHOWCASE.instantiate() as Node2D
    root.add_child(showcase)
    await process_frame

    _expect(showcase != null, "tower room visual showcase instantiates")
    if showcase != null:
        var expected := {
            "Combat": &"combat",
            "Safe": &"safe",
            "Reward": &"reward",
            "Vendor": &"vendor",
            "Secret": &"secret",
            "Elite": &"elite",
            "Objective": &"objective",
            "Boss": &"boss",
        }
        var seen: Dictionary = {}
        for node_name: String in expected.keys():
            var visual := showcase.get_node_or_null(node_name) as TowerRoomVisual
            _expect(visual != null, "%s showcase presenter exists" % node_name)
            if visual != null:
                _expect(visual.profile != null, "%s showcase profile is inspector assigned" % node_name)
                if visual.profile != null:
                    _expect(visual.profile.room_type == expected[node_name], "%s showcase preserves semantic room identity" % node_name)
                    _expect(visual.profile.validate_profile().is_empty(), "%s showcase profile validates" % node_name)
                    _expect(visual.sprite != null and visual.sprite.texture == visual.profile.texture, "%s showcase Sprite2D consumes the inspector profile texture" % node_name)
                    _expect(visual.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s showcase preserves nearest filtering" % node_name)
                    seen[visual.profile.room_type] = true
        _expect(seen.size() == TowerRoomVisualProfile.ROOM_TYPES.size(), "showcase covers all eight unique tower visual room categories")
        showcase.queue_free()

    if _failures == 0:
        print("TOWER ROOM VISUAL SHOWCASE TEST PASS")
    else:
        push_error("TOWER ROOM VISUAL SHOWCASE TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
