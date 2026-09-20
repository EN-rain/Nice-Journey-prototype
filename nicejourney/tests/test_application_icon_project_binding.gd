extends SceneTree

const PROJECT_ICON := "res://assets/art/ui/application/application_icon_tower_sigil_v02.png"
const ACCEPTED_SOURCE := "res://assets/art/ui/markers/tower_sigil_icon_v01.png"
const EXPECTED_SOURCE_SHA := "1dfeea179a0df7320388fcfadba55e715d367656be4e6585a756b14b99a70b39"
const EXPECTED_ICON_SHA := "26d6b6318856e04bae3b2c32adbce24e5f0c79fa411b9fa7706d2b03fee9f185"
var failures := 0


func _init() -> void:
    call_deferred("_run")


func _run() -> void:
    _check(String(ProjectSettings.get_setting("application/config/icon", "")) == PROJECT_ICON, "actual Godot project points to new source-backed icon")
    _check(FileAccess.file_exists("res://icon.svg"), "original Godot SVG remains preserved, not silently deleted")
    var icon := load(PROJECT_ICON) as Texture2D
    var source := load(ACCEPTED_SOURCE) as Texture2D
    _check(icon != null and icon.get_size() == Vector2(128, 128), "project icon loads at required 128x128")
    _check(source != null and source.get_size() == Vector2(32, 32), "accepted generated Tower Sigil source remains 32x32")
    _check(FileAccess.get_sha256(ProjectSettings.globalize_path(PROJECT_ICON)) == EXPECTED_ICON_SHA, "production PNG SHA-256 unchanged")
    _check(FileAccess.get_sha256(ProjectSettings.globalize_path(ACCEPTED_SOURCE)) == EXPECTED_SOURCE_SHA, "accepted Tower Sigil source SHA-256 unchanged")
    if icon != null and source != null:
        var output_image := icon.get_image()
        var source_image := source.get_image()
        _check(output_image != null and source_image != null and not output_image.is_empty() and not source_image.is_empty(), "Godot imported both source and derivative")
        if output_image != null and source_image != null and not output_image.is_empty() and not source_image.is_empty():
            output_image.convert(Image.FORMAT_RGBA8)
            source_image.convert(Image.FORMAT_RGBA8)
            var alpha_failures := 0
            var opaque_rgb_failures := 0
            var opaque_count := 0
            for y in range(128):
                for x in range(128):
                    var produced := output_image.get_pixel(x, y)
                    var original := source_image.get_pixel(x / 4, y / 4)
                    var alpha_delta := absi(int(produced.a8) - int(original.a8))
                    if alpha_delta > 1:
                        alpha_failures += 1
                    # Godot's PNG import may normalize RGB under partial
                    # alpha. Original PNG bytes are verified separately by
                    # the Python source-derivation gate; native fully opaque
                    # visible color must remain correct in this resource test.
                    if original.a8 >= 245:
                        opaque_count += 1
                        var rgb_delta := maxi(
                            maxi(absi(int(produced.r8) - int(original.r8)), absi(int(produced.g8) - int(original.g8))),
                            absi(int(produced.b8) - int(original.b8))
                        )
                        if rgb_delta > 5:
                            opaque_rgb_failures += 1
            _check(alpha_failures == 0 and opaque_count >= 2000 and opaque_rgb_failures == 0, "all 16384 imported output alpha pixels plus readable opaque RGBA preserve the 4x accepted-source icon")
    print("APPLICATION ICON PROJECT BINDING FAILURES: ", failures)
    quit(failures)


func _check(ok: bool, message: String) -> void:
    if not ok:
        failures += 1
        push_error("FAIL: " + message)
