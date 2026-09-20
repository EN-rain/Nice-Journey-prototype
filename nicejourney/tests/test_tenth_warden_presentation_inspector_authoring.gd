extends SceneTree

const SCENE: PackedScene = preload("res://src/enemies/boss_tenth_warden/presentation/tenth_warden_visual.tscn")
const REQUIRED_ANIMATIONS: Array[StringName] = [
    &"idle", &"phase_two", &"twin_cut", &"warden_lunge", &"arc_volley",
    &"crescent_sweep", &"punishing_step", &"hit", &"death",
]
const REQUIRED_MOVES: Array[StringName] = [
    &"twin_cut", &"warden_lunge", &"arc_volley", &"crescent_sweep", &"punishing_step",
]

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var visual: TenthWardenVisualController = SCENE.instantiate() as TenthWardenVisualController
    root.add_child(visual)
    await process_frame

    _expect(visual != null, "Tenth Warden visual scene uses the dedicated controller")
    if visual != null:
        _expect(visual.profile != null, "Tenth Warden visual profile is inspector assigned")
        _expect(visual.body is Sprite2D, "Tenth Warden body uses Sprite2D")
        _expect(visual.animation_player is AnimationPlayer, "Tenth Warden presentation uses AnimationPlayer")
        _expect(visual.telegraph_presenter is EffectSpritePresenter, "Tenth Warden owns the shared inspector-driven telegraph presenter")
        if visual.profile != null:
            _expect(visual.profile.validate_profile().is_empty(), "Tenth Warden visual profile validates")
            _expect(visual.profile.boss_id == &"tenth_warden", "Tenth Warden stable visual identity is preserved")
            _expect(visual.profile.move_visuals.size() == 5, "all five approved named boss moves have inspector-authored visual bindings")
            for move_id: StringName in REQUIRED_MOVES:
                var binding := visual.profile.find_move(move_id)
                _expect(binding != null, "boss move binding exists: %s" % String(move_id))
                if binding != null:
                    _expect(binding.telegraph_profile == null, "%s does not guess final attack geometry before runtime alignment" % String(move_id))
                    _expect(visual.play_move(move_id), "%s presentation can be selected semantically" % String(move_id))
        for animation_name: StringName in REQUIRED_ANIMATIONS:
            _expect(visual.animation_player.has_animation(animation_name), "AnimationPlayer owns %s" % String(animation_name))
        _expect(visual.body.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "boss sprite preserves nearest filtering")

    var controller_source := FileAccess.get_file_as_string("res://src/enemies/boss_tenth_warden/presentation/tenth_warden_visual_controller.gd")
    _expect(not controller_source.contains("preload(\"res://assets/art") and not controller_source.contains("load(\"res://assets/art"), "boss runtime contains no hardcoded art load paths")
    _expect(not controller_source.contains(".frame =") and not controller_source.contains("frame_coords"), "boss runtime contains no manual sprite-frame stepping")

    visual.queue_free()
    await process_frame
    if _failures == 0:
        print("TENTH WARDEN PRESENTATION INSPECTOR AUTHORING TEST PASS")
    else:
        push_error("TENTH WARDEN PRESENTATION INSPECTOR AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
