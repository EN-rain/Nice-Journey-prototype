class_name AssetProvenanceManifest
extends RefCounted

const SCHEMA_VERSION: int = 1
const KIND_PIXEL_ART: StringName = &"pixel_art"
const KIND_AUDIO: StringName = &"audio"
const KIND_OTHER: StringName = &"other"
const VALID_KINDS: Array[StringName] = [KIND_PIXEL_ART, KIND_AUDIO, KIND_OTHER]

const LICENSE_CC0_PUBLIC_DOMAIN: StringName = &"cc0_public_domain"
const LICENSE_CC_BY: StringName = &"cc_by"
const LICENSE_FREE_COMMERCIAL_USE: StringName = &"free_commercial_use"
const LICENSE_AI_TERMS_PERMIT: StringName = &"ai_generated_terms_permit"
const ALLOWED_LICENSE_CATEGORIES: Array[StringName] = [
    LICENSE_CC0_PUBLIC_DOMAIN,
    LICENSE_CC_BY,
    LICENSE_FREE_COMMERCIAL_USE,
    LICENSE_AI_TERMS_PERMIT,
]

const REQUIRED_ENTRY_FIELDS: Array[String] = [
    "asset_name",
    "project_path",
    "source",
    "creator_source",
    "license_category",
    "license_text",
    "attribution_text",
    "modifications",
    "date_imported",
    "responsible_agent",
    "kind",
]

const REQUIRED_PIXEL_METADATA_FIELDS: Array[String] = [
    "dimensions",
    "palette_material_ramp",
    "pivot_ground_anchor",
    "frame_order_timing",
    "transparent_bounds",
    "intended_render_layers",
]

static func validate_manifest(manifest: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    var raw_schema_version: Variant = manifest.get("schema_version", null)
    if not (raw_schema_version is int or raw_schema_version is float) or not is_finite(float(raw_schema_version)) or not is_equal_approx(float(raw_schema_version), float(int(raw_schema_version))):
        errors.append("schema_version must be an integer number")
    elif int(raw_schema_version) != SCHEMA_VERSION:
        errors.append("unsupported schema_version")
    var raw_assets: Variant = manifest.get("assets", null)
    if not raw_assets is Array:
        errors.append("assets must be an array")
        return errors

    var seen_paths: Dictionary = {}
    for index: int in range((raw_assets as Array).size()):
        var raw_entry: Variant = (raw_assets as Array)[index]
        if not raw_entry is Dictionary:
            errors.append("assets[%d] must be a dictionary" % index)
            continue
        var entry_errors: PackedStringArray = validate_entry(raw_entry as Dictionary)
        for error: String in entry_errors:
            errors.append("assets[%d]: %s" % [index, error])
        var raw_project_path: Variant = (raw_entry as Dictionary).get("project_path", null)
        if not (raw_project_path is String or raw_project_path is StringName):
            continue
        var project_path: String = String(raw_project_path).strip_edges()
        if project_path.is_empty():
            continue
        if seen_paths.has(project_path):
            errors.append("assets[%d]: duplicate project_path %s" % [index, project_path])
        else:
            seen_paths[project_path] = true
    return errors

static func validate_entry(entry: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    for field: String in REQUIRED_ENTRY_FIELDS:
        if not entry.has(field):
            errors.append("missing %s" % field)

    var asset_name: String = _read_text_field(entry, "asset_name", errors)
    var project_path: String = _read_text_field(entry, "project_path", errors)
    var source: String = _read_text_field(entry, "source", errors)
    var creator_source: String = _read_text_field(entry, "creator_source", errors)
    var license_category: StringName = _read_string_name_field(entry, "license_category", errors)
    var license_text: String = _read_text_field(entry, "license_text", errors)
    var attribution_text: String = _read_text_field(entry, "attribution_text", errors)
    var modifications: String = _read_text_field(entry, "modifications", errors)
    var date_imported: String = _read_text_field(entry, "date_imported", errors)
    var responsible_agent: String = _read_text_field(entry, "responsible_agent", errors)
    var kind: StringName = _read_string_name_field(entry, "kind", errors)

    if asset_name.is_empty():
        errors.append("asset_name is required")
    if project_path.is_empty() or not project_path.begins_with("res://"):
        errors.append("project_path must be a res:// path")
    if source.is_empty():
        errors.append("source URL/path is required")
    if creator_source.is_empty():
        errors.append("creator/source is required")
    if not ALLOWED_LICENSE_CATEGORIES.has(license_category):
        errors.append("license_category is not allowed by the prototype asset policy")
    if license_text.is_empty():
        errors.append("license_text is required")
    if license_category == LICENSE_CC_BY and attribution_text.is_empty():
        errors.append("CC-BY assets require attribution_text")
    if modifications.is_empty():
        errors.append("modifications record is required")
    if not _looks_like_iso_date(date_imported):
        errors.append("date_imported must use YYYY-MM-DD")
    if responsible_agent.is_empty():
        errors.append("responsible_agent is required")
    if not VALID_KINDS.has(kind):
        errors.append("kind must be pixel_art, audio, or other")

    if kind == KIND_PIXEL_ART:
        var pixel_metadata: Variant = entry.get("pixel_metadata", null)
        if not pixel_metadata is Dictionary:
            errors.append("pixel_art requires pixel_metadata")
        else:
            for field: String in REQUIRED_PIXEL_METADATA_FIELDS:
                if not (pixel_metadata as Dictionary).has(field) or _metadata_value_is_empty((pixel_metadata as Dictionary).get(field)):
                    errors.append("pixel_metadata.%s is required" % field)
            for field: String in ["dimensions", "palette_material_ramp", "pivot_ground_anchor", "frame_order_timing", "transparent_bounds"]:
                if (pixel_metadata as Dictionary).has(field):
                    var value: Variant = (pixel_metadata as Dictionary).get(field)
                    if not (value is String or value is StringName):
                        errors.append("pixel_metadata.%s must be a string" % field)
            if (pixel_metadata as Dictionary).has("intended_render_layers") and not (pixel_metadata as Dictionary).get("intended_render_layers") is Array:
                errors.append("pixel_metadata.intended_render_layers must be an array")
    return errors

static func _looks_like_iso_date(value: String) -> bool:
    if value.length() != 10 or value[4] != "-" or value[7] != "-":
        return false
    var parts: PackedStringArray = value.split("-")
    if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
        return false
    var year: int = parts[0].to_int()
    var month: int = parts[1].to_int()
    var day: int = parts[2].to_int()
    if year < 1 or month < 1 or month > 12 or day < 1:
        return false
    var days_in_month: Array[int] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    var leap_year: bool = year % 400 == 0 or (year % 4 == 0 and year % 100 != 0)
    if leap_year:
        days_in_month[1] = 29
    return day <= days_in_month[month - 1]

static func _read_text_field(entry: Dictionary, field: String, errors: PackedStringArray) -> String:
    if not entry.has(field):
        return ""
    var value: Variant = entry.get(field)
    if not (value is String or value is StringName):
        errors.append("%s must be a string" % field)
        return ""
    return String(value).strip_edges()

static func _read_string_name_field(entry: Dictionary, field: String, errors: PackedStringArray) -> StringName:
    if not entry.has(field):
        return &""
    var value: Variant = entry.get(field)
    if not (value is String or value is StringName):
        errors.append("%s must be a string" % field)
        return &""
    return StringName(value)

static func _metadata_value_is_empty(value: Variant) -> bool:
    if value == null:
        return true
    if value is String or value is StringName:
        return String(value).strip_edges().is_empty()
    if value is Array:
        return (value as Array).is_empty()
    if value is Dictionary:
        return (value as Dictionary).is_empty()
    return false
