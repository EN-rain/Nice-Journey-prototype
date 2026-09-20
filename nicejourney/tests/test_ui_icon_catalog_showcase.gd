extends SceneTree

const SHOWCASE_SCENE: PackedScene = preload("res://src/ui/presentation/ui_icon_catalog_showcase.tscn")

var failures := 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var showcase := SHOWCASE_SCENE.instantiate() as UiIconCatalogShowcase
    root.add_child(showcase)
    # The headless test runner has a dummy renderer without a framebuffer.
    # Structural/Inspector assertions run in both modes; capture evidence only
    # when a real display is available, never fabricate a headless PNG.
    for _i in range(12):
        await process_frame
        if showcase.grid != null and showcase.grid.get_child_count() == 28:
            break
    if DisplayServer.get_name() != "headless":
        var frame_drawn := false
        var mark_frame_drawn := func() -> void: frame_drawn = true
        RenderingServer.frame_post_draw.connect(mark_frame_drawn, CONNECT_ONE_SHOT)
        RenderingServer.force_draw(false)
        for _i in range(6):
            if frame_drawn:
                break
            await process_frame
        # Some Windows bridge builds do not deliver frame_post_draw to the
        # script even though the real OpenGL framebuffer is available. The
        # saved viewport image is the acceptance evidence.
        var evidence_path := "res://artifacts/ui/ui_icon_catalog_showcase_v02.png"
        DirAccess.make_dir_recursive_absolute("res://artifacts/ui")
        var viewport_image := root.get_viewport().get_texture().get_image()
        var evidence_saved := viewport_image != null and viewport_image.save_png(evidence_path) == OK
        _expect(evidence_saved, "renderer-active showcase saves a real viewport PNG")
        if viewport_image != null:
            _expect(viewport_image.get_width() == 1280 and viewport_image.get_height() == 720, "showcase viewport evidence uses the configured 1280x720 output")

    _expect(showcase != null, "UI icon catalog showcase instantiates")
    if showcase != null:
        _expect(showcase.icon_catalog != null and showcase.icon_catalog.validate_catalog().is_empty(), "showcase consumes the validated inspector-owned icon catalog")
        _expect(showcase.presenter_scene != null, "showcase presenter scene is inspector assigned")
        _expect(showcase.grid != null and showcase.grid.columns == 7, "showcase uses inspector-authored seven-column comparison layout")
        if showcase.grid != null:
            _expect(showcase.grid.get_child_count() == 28, "showcase renders all 28 current UI icon profiles")
            var seen: Dictionary = {}
            for tile: Node in showcase.grid.get_children():
                _expect(tile.get_child_count() >= 1, "showcase tile contains an icon presenter")
                if tile.get_child_count() < 1:
                    continue
                var presenter := tile.get_child(0) as UiIconPresenter
                _expect(presenter != null and presenter.profile != null, "showcase tile uses UiIconPresenter with inspector/catalog profile data")
                if presenter == null or presenter.profile == null:
                    continue
                _expect(presenter.texture == presenter.profile.texture, "%s presenter uses its profile texture" % String(presenter.profile.icon_id))
                _expect(presenter.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s presenter preserves nearest filtering" % String(presenter.profile.icon_id))
                _expect(not seen.has(presenter.profile.icon_id), "%s appears once in the comparison surface" % String(presenter.profile.icon_id))
                seen[presenter.profile.icon_id] = true
            _expect(seen.size() == 28, "comparison surface covers exactly 28 unique icon identities")

    var presenter_source := FileAccess.get_file_as_string("res://src/ui/presentation/ui_icon_presenter.gd")
    var showcase_source := FileAccess.get_file_as_string("res://src/ui/presentation/ui_icon_catalog_showcase.gd")
    _expect(not presenter_source.contains("res://assets/art") and not showcase_source.contains("res://assets/art"), "UI showcase/presenter runtime contains no hardcoded art paths")

    if showcase != null:
        showcase.queue_free()
    await process_frame
    if failures == 0:
        print("UI ICON CATALOG SHOWCASE TEST PASS")
    else:
        push_error("UI ICON CATALOG SHOWCASE TEST FAILURES: %d" % failures)
    quit(failures)

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    failures += 1
    push_error("FAIL: %s" % message)
