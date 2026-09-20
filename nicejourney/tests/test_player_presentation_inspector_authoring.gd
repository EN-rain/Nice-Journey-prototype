extends SceneTree

const PLAYER_SCENE: PackedScene = preload("res://src/player/player.tscn")
const EXPECTED_ANIMATIONS: Array[StringName] = [
    &"idle",
    &"walk",
    &"run",
    &"dash",
    &"dodge",
    &"attack",
    &"heavy_attack",
    &"block",
    &"parry",
    &"cast",
    &"hit",
    &"death",
    &"interact",
    &"pickup",
    &"use_item",
    &"climb",
    &"sleep",
]

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var player: PlayerController = PLAYER_SCENE.instantiate() as PlayerController
    root.add_child(player)
    await process_frame

    var body: Sprite2D = player.get_node_or_null("BodyVisual/Body") as Sprite2D
    var animation_player: AnimationPlayer = player.get_node_or_null("BodyAnimationPlayer") as AnimationPlayer
    var animator: PlayerBodyAnimator = player.get_node_or_null("PlayerBodyAnimator") as PlayerBodyAnimator
    var weapon_visual: StarterWeaponVisual = player.get_node_or_null("StarterWeaponVisual") as StarterWeaponVisual

    _expect(body != null, "player presentation uses a Sprite2D body")
    _expect(animation_player != null, "player presentation uses an AnimationPlayer")
    _expect(animator != null, "semantic body animator controller exists")
    _expect(weapon_visual != null, "starter weapon visual controller exists")

    if animator != null:
        _expect(animator.get_animation_player() == animation_player, "animator binds the scene-authored AnimationPlayer")
        _expect(animator.validate_animation_setup().is_empty(), "required inspector-authored animation bindings validate")

    if animation_player != null:
        for animation_name: StringName in EXPECTED_ANIMATIONS:
            _expect(animation_player.has_animation(animation_name), "AnimationPlayer owns %s" % String(animation_name))
        _expect(animation_player.get_animation(&"idle") != null, "idle is stored as an editable Animation resource")
        _expect(animation_player.get_animation(&"attack") != null, "attack is stored as an editable Animation resource")
        _expect(animation_player.get_animation(&"cast") != null, "cast is stored as an editable Animation resource")

    if weapon_visual != null:
        _expect(weapon_visual.class_profiles.size() == 3, "starter weapon visuals use three inspector-authored class profiles")
        var melee: StarterWeaponVisualProfile = weapon_visual.get_profile(&"melee")
        var ranged: StarterWeaponVisualProfile = weapon_visual.get_profile(&"ranged")
        var mage: StarterWeaponVisualProfile = weapon_visual.get_profile(&"mage")
        _expect(melee != null and melee.validate_profile().is_empty(), "Melee visual profile is inspector-authored and valid")
        _expect(ranged != null and ranged.validate_profile().is_empty(), "Ranged visual profile is inspector-authored and valid")
        _expect(mage != null and mage.validate_profile().is_empty(), "Mage visual profile is inspector-authored and valid")
        if melee != null:
            _expect(melee.main_hand_texture != null and melee.shield_texture != null and melee.shield_visible, "Melee textures and shield visibility live in the profile")
        if ranged != null:
            _expect(ranged.main_hand_texture != null and not ranged.shield_visible, "Ranged texture/off-hand presentation lives in the profile")
        if mage != null:
            _expect(mage.main_hand_texture != null and not mage.shield_visible, "Mage texture/off-hand presentation lives in the profile")

    _expect(_script_avoids_runtime_frame_stepping("res://src/player/presentation/player_body_animator.gd"), "player animator contains no manual Sprite2D frame stepping")
    _expect(_script_avoids_hardcoded_art_preloads("res://src/player/presentation/player_body_animator.gd"), "player animator contains no hardcoded art preload paths")
    _expect(_script_avoids_hardcoded_art_preloads("res://src/player/presentation/starter_weapon_visual.gd"), "starter weapon runtime contains no hardcoded art preload paths")

    player.queue_free()
    if _failures == 0:
        print("PLAYER PRESENTATION INSPECTOR AUTHORING TEST PASS")
    else:
        push_error("PLAYER PRESENTATION INSPECTOR AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)


func _script_avoids_runtime_frame_stepping(path: String) -> bool:
    var source: String = _read_text(path)
    if source.is_empty():
        return false
    return (
        source.find(".frame =") == -1
        and source.find("hframes =") == -1
        and source.find("_update_frame") == -1
        and source.find("_action_elapsed") == -1
    )


func _script_avoids_hardcoded_art_preloads(path: String) -> bool:
    var source: String = _read_text(path)
    if source.is_empty():
        return false
    return source.find("preload(\"res://assets/art") == -1 and source.find("load(\"res://assets/art") == -1


func _read_text(path: String) -> String:
    var file: FileAccess = FileAccess.open(path, FileAccess.READ)
    if file == null:
        return ""
    return file.get_as_text()


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
