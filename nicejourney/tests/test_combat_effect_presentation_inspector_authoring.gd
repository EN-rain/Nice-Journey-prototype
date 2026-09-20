extends SceneTree

const PRESENTER_SCENE: PackedScene = preload("res://src/presentation/effects/effect_sprite_presenter.tscn")
const CATALOG: EffectVisualCatalog = preload("res://src/presentation/effects/combat_effect_visual_catalog.tres")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(CATALOG != null, "combat effect visual catalog loads")
    if CATALOG != null:
        _expect(CATALOG.profiles.size() == 19, "catalog exposes all 6 generated player VFX plus 13 generated telegraph profiles")
        _expect(CATALOG.validate_catalog().is_empty(), "all inspector-authored effect profiles validate")
        for effect_id: StringName in [&"vfx_light_slash_trail", &"vfx_arcane_cast_burst", &"telegraph_narrow_line", &"telegraph_guard_break"]:
            var profile: EffectVisualProfile = CATALOG.get_profile(effect_id)
            _expect(profile != null, "catalog resolves %s" % String(effect_id))
            if profile != null:
                _expect(profile.texture != null, "%s profile owns an inspector-assigned generated texture" % String(effect_id))
                _expect(profile.animation_library != null and profile.animation_library.has_animation(profile.default_animation), "%s profile owns inspector-editable AnimationPlayer data" % String(effect_id))

    var presenter: EffectSpritePresenter = PRESENTER_SCENE.instantiate() as EffectSpritePresenter
    root.add_child(presenter)
    await process_frame
    _expect(presenter != null, "generic effect Sprite2D + AnimationPlayer presenter instantiates")
    if presenter != null and CATALOG != null:
        var telegraph: EffectVisualProfile = CATALOG.get_profile(&"telegraph_cone")
        _expect(presenter.configure_profile(telegraph), "presenter accepts inspector-authored telegraph profile")
        _expect(presenter.sprite != null and presenter.sprite.texture == telegraph.texture, "presenter displays the profile texture on Sprite2D")
        _expect(presenter.sprite.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "effect presenter enforces nearest filtering")
        _expect(presenter.animation_player != null and presenter.animation_player.has_animation(&"default"), "effect presenter installs the profile AnimationLibrary")
        _expect(presenter.replay(), "effect animation can be replayed semantically")
        presenter.queue_free()

    var presenter_source: String = FileAccess.get_file_as_string("res://src/presentation/effects/effect_sprite_presenter.gd")
    _expect(not presenter_source.contains("res://assets/art/"), "effect runtime contains no hardcoded art paths")
    _expect(not presenter_source.contains(".frame =") and not presenter_source.contains("frame +="), "effect runtime contains no manual sprite-frame stepping")

    if _failures == 0:
        print("COMBAT EFFECT PRESENTATION INSPECTOR AUTHORING TEST PASS")
    else:
        push_error("COMBAT EFFECT PRESENTATION INSPECTOR AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
