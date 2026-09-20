extends SceneTree

const ARCHETYPES: Array[String] = [
    "skirmisher",
    "assassin",
    "mobile_ranged",
    "caster",
    "support",
    "summoner",
    "flying_harrier",
    "controller_disruptor",
]
const REQUIRED_ANIMATIONS: Array[StringName] = [&"idle", &"move", &"windup", &"release", &"hit", &"death"]

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    for archetype: String in ARCHETYPES:
        var scene_path: String = "res://src/enemies/presentation/scenes/%s_visual.tscn" % archetype
        var packed: PackedScene = load(scene_path) as PackedScene
        _expect(packed != null, "%s generated V02 visual scene loads" % archetype)
        if packed == null:
            continue
        var controller: EnemyVisualController = packed.instantiate() as EnemyVisualController
        root.add_child(controller)
        await process_frame
        _expect(controller.profile != null, "%s profile is inspector assigned" % archetype)
        if controller.profile != null:
            _expect(controller.profile.archetype_id == StringName(archetype), "%s stable identity matches profile" % archetype)
            _expect(controller.profile.validate_profile().is_empty(), "%s profile validates" % archetype)
            _expect(controller.profile.telegraph_profile == null, "%s does not invent a final telegraph before authoritative attack geometry exists" % archetype)
        var library_source: String = FileAccess.get_file_as_string("res://src/enemies/presentation/libraries/%s_animation_library.tres" % archetype)
        var scene_source: String = FileAccess.get_file_as_string(scene_path)
        _expect(library_source.contains("_v02.png"), "%s AnimationLibrary references generated V02 gameplay derivatives" % archetype)
        _expect(not library_source.contains("_v01.png"), "%s AnimationLibrary has no replaced V01 texture references" % archetype)
        _expect(scene_source.contains("_v02.png"), "%s scene default body texture is V02" % archetype)
        _expect(not scene_source.contains("_v01.png"), "%s scene has no replaced V01 texture reference" % archetype)
        _expect(controller.body is Sprite2D, "%s uses Sprite2D body" % archetype)
        _expect(controller.animation_player is AnimationPlayer, "%s uses AnimationPlayer" % archetype)
        for animation_name: StringName in REQUIRED_ANIMATIONS:
            _expect(controller.animation_player.has_animation(animation_name), "%s owns %s presentation" % [archetype, String(animation_name)])
        controller.queue_free()
        await process_frame

    if _failures == 0:
        print("REMAINING ENEMY PRESENTATION INSPECTOR AUTHORING TEST PASS")
    else:
        push_error("REMAINING ENEMY PRESENTATION INSPECTOR AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
