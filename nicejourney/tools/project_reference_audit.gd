class_name ProjectReferenceAudit
extends RefCounted

const REFERENCE_PATTERN: String = "res://[^\"'\\r\\n\\t]+?\\.[A-Za-z0-9_]+(?=[\"'\\)\\]\\},]|\\s+res://|\\s*$)"

static func collect_references_from_text(text: String) -> PackedStringArray:
    var regex: RegEx = RegEx.new()
    var compile_error: int = regex.compile(REFERENCE_PATTERN)
    if compile_error != OK:
        return PackedStringArray()
    var unique: Dictionary = {}
    for match: RegExMatch in regex.search_all(text):
        var reference: String = match.get_string()
        unique[reference] = true
    var references: PackedStringArray = PackedStringArray()
    for reference_variant: Variant in unique.keys():
        references.append(String(reference_variant))
    references.sort()
    return references

static func validate_source_files(source_paths: PackedStringArray) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    var referenced_by: Dictionary = {}
    for source_path: String in source_paths:
        if not FileAccess.file_exists(source_path):
            errors.append("source file missing: %s" % source_path)
            continue
        var file: FileAccess = FileAccess.open(source_path, FileAccess.READ)
        if file == null:
            errors.append("source file unreadable: %s" % source_path)
            continue
        var text: String = file.get_as_text()
        file.close()
        for reference: String in collect_references_from_text(text):
            var owners: PackedStringArray = referenced_by.get(reference, PackedStringArray())
            owners.append(source_path)
            referenced_by[reference] = owners

    errors.append_array(_validate_reference_owners(referenced_by))
    return errors

static func validate_reference_paths(reference_paths: PackedStringArray, owner_label: String = "fixture") -> PackedStringArray:
    var referenced_by: Dictionary = {}
    for reference: String in reference_paths:
        if not referenced_by.has(reference):
            referenced_by[reference] = PackedStringArray()
        var owners: PackedStringArray = referenced_by[reference]
        owners.append(owner_label)
        referenced_by[reference] = owners
    return _validate_reference_owners(referenced_by)

static func collect_production_source_files() -> PackedStringArray:
    var result: PackedStringArray = PackedStringArray(["res://project.godot"])
    _collect_directory_files("res://src", result)
    result.sort()
    return result

static func validate_production_references() -> PackedStringArray:
    return validate_source_files(collect_production_source_files())

static func _collect_directory_files(directory_path: String, output: PackedStringArray) -> void:
    var directory: DirAccess = DirAccess.open(directory_path)
    if directory == null:
        return
    directory.list_dir_begin()
    var entry: String = directory.get_next()
    while not entry.is_empty():
        if entry == "." or entry == "..":
            entry = directory.get_next()
            continue
        var child_path: String = "%s/%s" % [directory_path, entry]
        if directory.current_is_dir():
            _collect_directory_files(child_path, output)
        elif entry.ends_with(".gd") or entry.ends_with(".tscn") or entry.ends_with(".tres"):
            output.append(child_path)
        entry = directory.get_next()
    directory.list_dir_end()

static func _validate_reference_owners(referenced_by: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    var references: Array = referenced_by.keys()
    references.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
    for reference_variant: Variant in references:
        var reference: String = String(reference_variant)
        if _is_safe_project_reference(reference) and FileAccess.file_exists(reference):
            continue
        var owners: PackedStringArray = referenced_by[reference]
        errors.append("missing or unsafe project reference: %s <- %s" % [reference, ", ".join(owners)])
    return errors

static func _is_safe_project_reference(reference: String) -> bool:
    if not reference.begins_with("res://"):
        return false
    var relative_path: String = reference.trim_prefix("res://")
    if relative_path.is_empty() or relative_path.contains("\\"):
        return false
    for segment: String in relative_path.split("/", true):
        if segment.is_empty() or segment == "." or segment == ".." or not segment.is_valid_filename():
            return false
    return true
