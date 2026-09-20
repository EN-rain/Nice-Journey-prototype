extends SceneTree

const DEFAULT_SCENE: String = "res://src/app/main.tscn"
const DEFAULT_OUTPUT: String = "res://docs/evidence/visual/internal-canvas-640x360.png"
const DEFAULT_WIDTH: int = 640
const DEFAULT_HEIGHT: int = 360

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var options: Dictionary = _parse_options(OS.get_cmdline_user_args())
    var scene_path: String = String(options.get("scene", DEFAULT_SCENE))
    var output_path: String = String(options.get("out", DEFAULT_OUTPUT))
    var width: int = maxi(int(options.get("width", DEFAULT_WIDTH)), 1)
    var height: int = maxi(int(options.get("height", DEFAULT_HEIGHT)), 1)

    var packed: PackedScene = load(scene_path) as PackedScene
    if packed == null:
        push_error("Visual evidence capture failed: scene could not be loaded: %s" % scene_path)
        quit(1)
        return

    root.size = Vector2i(width, height)
    DisplayServer.window_set_size(Vector2i(width, height))
    var instance: Node = packed.instantiate()
    root.add_child(instance)
    current_scene = instance

    await process_frame
    await process_frame
    _apply_optional_presentation_fixture(instance, options)
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw

    var actual_window_size: Vector2i = DisplayServer.window_get_size()
    var image: Image = root.get_texture().get_image()
    if image == null or image.is_empty():
        push_error("Visual evidence capture failed: root viewport image is unavailable")
        quit(1)
        return

    var output_absolute: String = ProjectSettings.globalize_path(output_path)
    var output_dir: String = output_absolute.get_base_dir()
    var mkdir_error: int = DirAccess.make_dir_recursive_absolute(output_dir)
    if mkdir_error != OK and mkdir_error != ERR_ALREADY_EXISTS:
        push_error("Visual evidence capture failed: cannot create output directory (%d)" % mkdir_error)
        quit(1)
        return

    var save_error: int = image.save_png(output_absolute)
    if save_error != OK:
        push_error("Visual evidence capture failed: PNG save error %d" % save_error)
        quit(1)
        return

    var metadata_path: String = output_absolute.get_basename() + ".json"
    var metadata: Dictionary = {
        "scene": scene_path,
        "requested_window_size": {"width": width, "height": height},
        "actual_window_size": {"width": actual_window_size.x, "height": actual_window_size.y},
        "captured_image_size": {"width": image.get_width(), "height": image.get_height()},
        "renderer_method": String(ProjectSettings.get_setting("rendering/renderer/rendering_method", "")),
        "stretch_mode": String(ProjectSettings.get_setting("display/window/stretch/mode", "")),
        "stretch_scale_mode": String(ProjectSettings.get_setting("display/window/stretch/scale_mode", "")),
        "fixture": {
            "ui_scale": options.get("ui-scale", null),
            "text_scale": options.get("text-scale", null),
            "open_settings": bool(options.get("open-settings", false)),
        },
    }
    var metadata_file: FileAccess = FileAccess.open(metadata_path, FileAccess.WRITE)
    if metadata_file == null:
        push_error("Visual evidence capture failed: metadata file could not be opened")
        quit(1)
        return
    metadata_file.store_string(JSON.stringify(metadata, "\t", true))
    metadata_file.close()
    _cleanup_optional_presentation_fixture(options)

    print("VISUAL EVIDENCE CAPTURE PASS: %s | window=%dx%d | image=%dx%d" % [
        output_path,
        actual_window_size.x,
        actual_window_size.y,
        image.get_width(),
        image.get_height(),
    ])
    quit(0)

func _parse_options(args: PackedStringArray) -> Dictionary:
    var options: Dictionary = {}
    for argument: String in args:
        if not argument.begins_with("--") or not argument.contains("="):
            continue
        var separator: int = argument.find("=")
        var key: String = argument.substr(2, separator - 2)
        var value: String = argument.substr(separator + 1)
        match key:
            "scene", "out":
                options[key] = value
            "width", "height":
                if value.is_valid_int():
                    options[key] = int(value)
            "ui-scale", "text-scale":
                if value.is_valid_float():
                    options[key] = float(value)
            "open-settings":
                options[key] = value.to_lower() == "true" or value == "1"
    return options

func _apply_optional_presentation_fixture(instance: Node, options: Dictionary) -> void:
    var wants_scale: bool = options.has("ui-scale") or options.has("text-scale")
    if wants_scale:
        var settings: Node = root.get_node_or_null("AccessibilitySettings")
        if settings != null:
            var fixture_path: String = "user://visual_evidence_capture_settings.cfg"
            if FileAccess.file_exists(fixture_path):
                DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
            settings.call("set_storage_path", fixture_path)
            if options.has("ui-scale"):
                settings.call("set_ui_scale", float(options["ui-scale"]))
            if options.has("text-scale"):
                settings.call("set_text_scale", float(options["text-scale"]))
    if bool(options.get("open-settings", false)):
        var settings_button: Button = instance.get_node_or_null("FrontEnd/Panel/Scroller/Layout/SettingsButton") as Button
        if settings_button != null:
            settings_button.pressed.emit()

func _cleanup_optional_presentation_fixture(options: Dictionary) -> void:
    if not options.has("ui-scale") and not options.has("text-scale"):
        return
    var fixture_path: String = "user://visual_evidence_capture_settings.cfg"
    if FileAccess.file_exists(fixture_path):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))
