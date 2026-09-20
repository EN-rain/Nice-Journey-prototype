extends SceneTree

const CATALOG: UiIconCatalog = preload("res://src/ui/presentation/ui_icon_catalog.tres")
const MAIN_SCENE: PackedScene = preload("res://src/app/main.tscn")

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    _expect(CATALOG != null, "UI icon catalog loads")
    if CATALOG != null:
        _expect(CATALOG.profiles.size() == 28, "all 28 current UI image assets are represented by inspector-editable profiles")
        _expect(CATALOG.validate_catalog().is_empty(), "UI icon catalog validates")
        for icon_id: StringName in [&"class_melee", &"class_ranged", &"class_mage", &"tower_sigil", &"status_burn", &"status_slow", &"skill_arc_cleave"]:
            var profile := CATALOG.get_profile(icon_id)
            _expect(profile != null, "UI catalog resolves %s" % String(icon_id))
            if profile != null:
                _expect(profile.texture != null, "%s texture is inspector assigned" % String(icon_id))

    var main: Node = MAIN_SCENE.instantiate()
    main.set("save_root", "user://test_ui_icon_catalog_saves")
    root.add_child(main)
    await process_frame
    await process_frame

    var visual: ClassSelectionVisual = main.get_node("ClassSelectionVisual") as ClassSelectionVisual
    var option: OptionButton = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel/ClassOption") as OptionButton
    var icon: TextureRect = main.get_node("FrontEnd/Panel/Scroller/Layout/CreationPanel/ClassIcon") as TextureRect
    _expect(visual != null, "main scene owns inspector-authored class selection visual controller")
    _expect(option != null and option.item_count == 3, "main scene exposes the three locked class choices")
    _expect(icon != null and icon.texture != null, "class selection visibly consumes the UI icon catalog")
    if visual != null and option != null and icon != null:
        _expect(visual.validate_setup().is_empty(), "class selection visual setup validates")
        _expect(icon.texture == CATALOG.get_profile(&"class_melee").texture, "default Melee selection uses the inspector-assigned Melee icon")
        option.select(1)
        _expect(visual.refresh(), "class selection visual refreshes from semantic selection")
        _expect(icon.texture == CATALOG.get_profile(&"class_ranged").texture, "Ranged selection uses the inspector-assigned Ranged icon")
        option.select(2)
        _expect(visual.refresh(), "Mage class icon refresh succeeds")
        _expect(icon.texture == CATALOG.get_profile(&"class_mage").texture, "Mage selection uses the inspector-assigned Mage icon")
        _expect(icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "UI pixel icon presentation preserves nearest filtering")

    var visual_source := FileAccess.get_file_as_string("res://src/ui/presentation/class_selection_visual.gd")
    _expect(not visual_source.contains("preload(\"res://assets/art") and not visual_source.contains("load(\"res://assets/art"), "UI class presentation contains no hardcoded art load paths")

    main.queue_free()
    await process_frame
    if _failures == 0:
        print("UI ICON CATALOG INSPECTOR AUTHORING TEST PASS")
    else:
        push_error("UI ICON CATALOG INSPECTOR AUTHORING TEST FAILURES: %d" % _failures)
    quit(_failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
