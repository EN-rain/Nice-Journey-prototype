extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var source_files: PackedStringArray = ProjectReferenceAudit.collect_production_source_files()
    _expect(source_files.has("res://project.godot"), "audit includes project settings")
    _expect(source_files.has("res://src/app/main.tscn"), "audit includes production scenes")
    _expect(source_files.has("res://src/app/main.gd"), "audit includes production scripts")
    _expect(_is_strictly_sorted(source_files), "production source collection is deterministic and duplicate-free")
    _expect(_contains_only_production_sources(source_files), "production source collection excludes docs, tests, tools, and generated output")

    var validation_errors: PackedStringArray = ProjectReferenceAudit.validate_production_references()
    _expect(validation_errors.is_empty(), "production resource paths resolve to existing project files")
    for message: String in validation_errors:
        push_error(message)

    var sample: PackedStringArray = ProjectReferenceAudit.collect_references_from_text("res://src/app/main.tscn res://src/app/main.tscn res://src/audio/audio_service.gd")
    _expect(sample.size() == 2, "resource-path extraction de-duplicates repeated paths")
    _expect(sample[0] == "res://src/app/main.tscn" and sample[1] == "res://src/audio/audio_service.gd", "resource-path extraction is deterministic")

    var spaced_sample: PackedStringArray = ProjectReferenceAudit.collect_references_from_text("preload(\"res://src/example folder/example scene.tscn\") load(\"res://src/characters/角色 data.tres\")")
    _expect(spaced_sample.has("res://src/example folder/example scene.tscn") and spaced_sample.has("res://src/characters/角色 data.tres"), "resource-path extraction preserves legal spaces and Unicode path segments")
    _expect(ProjectReferenceAudit._is_safe_project_reference("res://src/example folder/example scene.tscn"), "legal internal spaces remain safe project references")
    _expect(ProjectReferenceAudit._is_safe_project_reference("res://src/example..scene.tscn"), "double dots inside a filename are not treated as traversal")
    _expect(not ProjectReferenceAudit._is_safe_project_reference("res://src/../project.godot"), "parent-directory traversal segments are rejected")

    var missing_errors: PackedStringArray = ProjectReferenceAudit.validate_reference_paths(PackedStringArray(["res://src/reference_fixture_missing.gd"]), "focused fixture")
    _expect(missing_errors.size() == 1 and missing_errors[0].contains("reference_fixture_missing.gd") and missing_errors[0].contains("focused fixture"), "missing project paths are reported with their owner label")
    var existing_errors: PackedStringArray = ProjectReferenceAudit.validate_reference_paths(PackedStringArray(["res://src/app/main.gd", "res://src/app/main.gd"]), "focused fixture")
    _expect(existing_errors.is_empty(), "existing duplicate fixture paths do not fabricate validation failures")

    if _failures == 0:
        print("PROJECT RESOURCE PATH TEST PASS")
    else:
        push_error("PROJECT RESOURCE PATH TEST FAILURES: %d" % _failures)
    quit(_failures)

func _is_strictly_sorted(paths: PackedStringArray) -> bool:
    for index: int in range(1, paths.size()):
        if paths[index - 1] >= paths[index]:
            return false
    return true

func _contains_only_production_sources(paths: PackedStringArray) -> bool:
    for path: String in paths:
        if path == "res://project.godot":
            continue
        if not path.begins_with("res://src/"):
            return false
        if not (path.ends_with(".gd") or path.ends_with(".tscn") or path.ends_with(".tres")):
            return false
    return true

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
