extends SceneTree

var _failures := 0


func _init() -> void:
    var source := FileAccess.get_file_as_string("res://tools/reference_validation.ps1")
    _expect(source.contains("script_error_count"), "reference validation records Godot script-error output separately from process exit codes")
    _expect(source.contains("SCRIPT ERROR:"), "reference validation detects explicit Godot SCRIPT ERROR diagnostics")
    _expect(source.contains("Parse Error:"), "reference validation detects Godot parse diagnostics even when editor exit code is zero")
    _expect(source.contains("Failed to load script"), "reference validation detects script-load failure diagnostics")
    _expect(source.contains("$_.exit_code -ne 0 -or $_.script_error_count -gt 0"), "final broad gate fails on either nonzero exit or script-error diagnostics")

    if _failures == 0:
        print("REFERENCE VALIDATION CONTRACT TEST PASS")
    else:
        push_error("REFERENCE VALIDATION CONTRACT TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
