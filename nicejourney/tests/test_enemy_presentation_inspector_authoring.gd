extends SceneTree

var _failures: int = 0

const FIRST_FOUR: Array[String] = ["duelist", "bruiser", "defender", "marksman"]
const REQUIRED_ANIMATIONS: Array[StringName] = [&"idle", &"move", &"windup", &"release", &"hit", &"death"]


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    for archetype: String in FIRST_FOUR:
        var scene_path: String = "res://src/enemies/presentation/scenes/%s_visual.tscn" % archetype
        var packed: PackedScene = load(scene_path) as PackedScene
        _expect(packed != null, "%s generated-asset visual scene loads" % archetype)
        if packed == null:
            continue
        var visual: Node2D = packed.instantiate() as Node2D
        root.add_child(visual)
        await process_frame
        var controller: EnemyVisualController = visual as EnemyVisualController
        _expect(controller != null, "%s visual uses EnemyVisualController" % archetype)
        if controller != null:
            _expect(controller.profile != null, "%s visual profile is inspector assigned" % archetype)
            if controller.profile != null:
                _expect(controller.profile.validate_profile().is_empty(), "%s visual profile validates" % archetype)
                _expect(controller.profile.archetype_id == StringName(archetype), "%s profile stable ID matches scene" % archetype)
            _expect(controller.body is Sprite2D, "%s body is Sprite2D" % archetype)
            _expect(controller.animation_player is AnimationPlayer, "%s presentation uses AnimationPlayer" % archetype)
            for animation_name: StringName in REQUIRED_ANIMATIONS:
                _expect(controller.animation_player.has_animation(animation_name), "%s AnimationPlayer owns %s" % [archetype, String(animation_name)])
            if archetype == "defender":
                _expect(controller.animation_player.has_animation(&"block"), "defender AnimationPlayer owns block")
            _expect(controller.telegraph_presenter is EffectSpritePresenter, "%s owns the shared generated-telegraph presenter" % archetype)
            _expect(controller.profile != null and controller.profile.telegraph_profile != null, "%s telegraph profile is inspector assigned" % archetype)
            if controller.telegraph_presenter != null and controller.profile != null and controller.profile.telegraph_profile != null:
                _expect(not controller.telegraph_presenter.visible, "%s telegraph starts hidden" % archetype)
                _expect(controller.play_semantic(controller.profile.windup_animation), "%s windup semantic animation plays" % archetype)
                _expect(controller.telegraph_presenter.visible, "%s windup automatically shows its inspector-authored generated telegraph" % archetype)
                _expect(controller.play_semantic(controller.profile.release_animation), "%s release semantic animation plays" % archetype)
                _expect(not controller.telegraph_presenter.visible, "%s release automatically hides the telegraph without AI art-path logic" % archetype)
        visual.queue_free()
        await process_frame

    var controller_source := FileAccess.get_file_as_string("res://src/enemies/presentation/enemy_visual_controller.gd")
    _expect(not controller_source.contains(".frame =") and not controller_source.contains("frame_coords"), "enemy presentation contains no manual sprite frame stepping")
    _expect(not controller_source.contains("preload(\"res://assets/art") and not controller_source.contains("load(\"res://assets/art"), "enemy presentation contains no hardcoded art load paths")

    if _failures == 0:
        print("ENEMY PRESENTATION INSPECTOR AUTHORING TEST PASS")
    else:
        push_error("ENEMY PRESENTATION INSPECTOR AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
