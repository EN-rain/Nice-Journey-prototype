extends SceneTree

var _failures: int = 0

func _init() -> void:
    call_deferred(&"_run")

func _run() -> void:
    var manifest_path: String = "res://docs/ASSET_PROVENANCE_MANIFEST.json"
    var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
    _expect(file != null, "asset provenance manifest exists in the repository")
    if file == null:
        quit(1)
        return
    var parser: JSON = JSON.new()
    _expect(parser.parse(file.get_as_text()) == OK and parser.data is Dictionary, "asset provenance manifest is valid JSON")
    file.close()
    if not parser.data is Dictionary:
        quit(1)
        return
    var manifest: Dictionary = parser.data as Dictionary
    _expect(AssetProvenanceManifest.validate_manifest(manifest).is_empty(), "current provenance manifest satisfies the locked metadata contract")
    var current_assets: Array = manifest.get("assets", []) as Array
    _expect(current_assets.size() >= 3, "manifest records the original Wave 29 art seed plus any later production assets that actually exist")
    for entry_variant: Variant in current_assets:
        if not entry_variant is Dictionary:
            continue
        var project_path: String = String((entry_variant as Dictionary).get("project_path", ""))
        _expect(ResourceLoader.exists(project_path) or FileAccess.file_exists(project_path), "recorded provenance path exists: %s" % project_path)
    _expect(String(manifest.get("policy_note", "")).contains("does not replace human review of license terms"), "manifest explicitly avoids claiming legal sufficiency")

    var valid_cc0: Dictionary = _base_entry()
    valid_cc0["license_category"] = AssetProvenanceManifest.LICENSE_CC0_PUBLIC_DOMAIN
    valid_cc0["license_text"] = "CC0 1.0 / Public Domain"
    var valid_cc0_before_validation: Dictionary = valid_cc0.duplicate(true)
    _expect(AssetProvenanceManifest.validate_entry(valid_cc0).is_empty(), "complete CC0/Public Domain entry validates")
    _expect(valid_cc0 == valid_cc0_before_validation, "validation records errors only and never fabricates or mutates provenance fields")

    var required_text_cases: Dictionary = {
        "creator_source": "creator/source is required",
        "license_text": "license_text is required",
        "modifications": "modifications record is required",
        "responsible_agent": "responsible_agent is required",
    }
    for field_variant: Variant in required_text_cases.keys():
        var field: String = String(field_variant)
        var missing_required_record: Dictionary = _base_entry()
        missing_required_record[field] = ""
        _expect(_contains(AssetProvenanceManifest.validate_entry(missing_required_record), String(required_text_cases[field])), "%s provenance record cannot be blank" % field)

    var valid_cc_by: Dictionary = _base_entry()
    valid_cc_by["project_path"] = "res://assets/fixture/attributed.png"
    valid_cc_by["license_category"] = AssetProvenanceManifest.LICENSE_CC_BY
    valid_cc_by["license_text"] = "CC BY 4.0"
    valid_cc_by["attribution_text"] = "Fixture Artist — Example Asset — CC BY 4.0"
    _expect(AssetProvenanceManifest.validate_entry(valid_cc_by).is_empty(), "CC-BY entry validates when attribution text is recorded")

    var missing_attribution: Dictionary = valid_cc_by.duplicate(true)
    missing_attribution["attribution_text"] = ""
    _expect(_contains(AssetProvenanceManifest.validate_entry(missing_attribution), "CC-BY assets require attribution_text"), "CC-BY entry without attribution is rejected")

    var prohibited_license: Dictionary = _base_entry()
    prohibited_license["license_category"] = &"non_commercial"
    prohibited_license["license_text"] = "CC BY-NC"
    _expect(_contains(AssetProvenanceManifest.validate_entry(prohibited_license), "license_category is not allowed by the prototype asset policy"), "non-commercial license category is rejected by the locked prototype policy")

    var unknown_license: Dictionary = _base_entry()
    unknown_license["license_category"] = &"unknown"
    unknown_license["license_text"] = "Unknown"
    _expect(_contains(AssetProvenanceManifest.validate_entry(unknown_license), "license_category is not allowed by the prototype asset policy"), "unclear/unknown license category is rejected")

    var paid_marketplace: Dictionary = _base_entry()
    paid_marketplace["license_category"] = &"paid_marketplace"
    paid_marketplace["license_text"] = "Paid marketplace fixture"
    _expect(_contains(AssetProvenanceManifest.validate_entry(paid_marketplace), "license_category is not allowed by the prototype asset policy"), "paid marketplace category is rejected without explicit approval")

    var copied_copyrighted: Dictionary = _base_entry()
    copied_copyrighted["license_category"] = &"copied_copyrighted_game_asset"
    copied_copyrighted["license_text"] = "Copied copyrighted fixture"
    _expect(_contains(AssetProvenanceManifest.validate_entry(copied_copyrighted), "license_category is not allowed by the prototype asset policy"), "copied copyrighted game-asset category is rejected")

    var ai_entry: Dictionary = _base_entry()
    ai_entry["project_path"] = "res://assets/fixture/ai_generated.png"
    ai_entry["source"] = "https://example.invalid/ai-generation-record"
    ai_entry["creator_source"] = "Fixture AI Generator"
    ai_entry["license_category"] = AssetProvenanceManifest.LICENSE_AI_TERMS_PERMIT
    ai_entry["license_text"] = "Fixture generator terms permit intended prototype use; human terms review still required"
    _expect(AssetProvenanceManifest.validate_entry(ai_entry).is_empty(), "AI-generated entry records generator/source evidence without claiming legal review is complete")
    var ai_missing_generator_source: Dictionary = ai_entry.duplicate(true)
    ai_missing_generator_source["creator_source"] = ""
    _expect(_contains(AssetProvenanceManifest.validate_entry(ai_missing_generator_source), "creator/source is required"), "AI-generated entry cannot omit the available creator/generator source record")

    var missing_source: Dictionary = _base_entry()
    missing_source["source"] = ""
    _expect(_contains(AssetProvenanceManifest.validate_entry(missing_source), "source URL/path is required"), "missing provenance source is rejected")

    var bad_date: Dictionary = _base_entry()
    bad_date["date_imported"] = "2026/09/14"
    _expect(_contains(AssetProvenanceManifest.validate_entry(bad_date), "date_imported must use YYYY-MM-DD"), "import date must use the manifest ISO format")
    var impossible_date: Dictionary = _base_entry()
    impossible_date["date_imported"] = "2026-02-31"
    _expect(_contains(AssetProvenanceManifest.validate_entry(impossible_date), "date_imported must use YYYY-MM-DD"), "calendar-impossible import dates are rejected")

    var pixel_entry: Dictionary = _base_entry()
    pixel_entry["kind"] = AssetProvenanceManifest.KIND_PIXEL_ART
    pixel_entry["project_path"] = "res://assets/fixture/pixel.png"
    pixel_entry["pixel_metadata"] = {
        "dimensions": "32x32 body canvas",
        "palette_material_ramp": "fixture palette",
        "pivot_ground_anchor": "ground center; grip fixture",
        "frame_order_timing": "fixture: 6 frames @ authored ticks",
        "transparent_bounds": "32x32 source body bounds",
        "intended_render_layers": ["actor_body"],
    }
    _expect(AssetProvenanceManifest.validate_entry(pixel_entry).is_empty(), "pixel-art entry validates only with the locked readability metadata recorded")
    var incomplete_pixel: Dictionary = pixel_entry.duplicate(true)
    (incomplete_pixel["pixel_metadata"] as Dictionary)["pivot_ground_anchor"] = ""
    _expect(_contains(AssetProvenanceManifest.validate_entry(incomplete_pixel), "pixel_metadata.pivot_ground_anchor is required"), "pixel-art entry missing anchor metadata is rejected")
    var malformed_pixel_metadata: Dictionary = pixel_entry.duplicate(true)
    (malformed_pixel_metadata["pixel_metadata"] as Dictionary)["dimensions"] = 32
    (malformed_pixel_metadata["pixel_metadata"] as Dictionary)["intended_render_layers"] = "actor_body"
    var malformed_pixel_errors: PackedStringArray = AssetProvenanceManifest.validate_entry(malformed_pixel_metadata)
    _expect(_contains(malformed_pixel_errors, "pixel_metadata.dimensions must be a string") and _contains(malformed_pixel_errors, "pixel_metadata.intended_render_layers must be an array"), "pixel-art metadata rejects malformed field types")

    var duplicate_path_manifest: Dictionary = {
        "schema_version": AssetProvenanceManifest.SCHEMA_VERSION,
        "assets": [valid_cc0.duplicate(true), valid_cc0.duplicate(true)],
    }
    _expect(_contains_substring(AssetProvenanceManifest.validate_manifest(duplicate_path_manifest), "duplicate project_path"), "duplicate project asset paths are rejected")

    var unsupported_schema: Dictionary = {
        "schema_version": 999,
        "assets": [],
    }
    _expect(_contains(AssetProvenanceManifest.validate_manifest(unsupported_schema), "unsupported schema_version"), "unsupported provenance manifest schema is rejected")

    var wrong_schema_type: Dictionary = {
        "schema_version": "1",
        "assets": [],
    }
    _expect(_contains(AssetProvenanceManifest.validate_manifest(wrong_schema_type), "schema_version must be an integer number"), "schema version string coercion is rejected")

    var wrong_assets_type: Dictionary = {
        "schema_version": AssetProvenanceManifest.SCHEMA_VERSION,
        "assets": {},
    }
    _expect(_contains(AssetProvenanceManifest.validate_manifest(wrong_assets_type), "assets must be an array"), "manifest assets field rejects malformed container types")

    var nondictionary_asset_manifest: Dictionary = {
        "schema_version": AssetProvenanceManifest.SCHEMA_VERSION,
        "assets": ["not-an-entry"],
    }
    _expect(_contains(AssetProvenanceManifest.validate_manifest(nondictionary_asset_manifest), "assets[0] must be a dictionary"), "manifest rejects non-dictionary asset entries")

    var wrong_field_type: Dictionary = _base_entry()
    wrong_field_type["asset_name"] = 123
    wrong_field_type["source"] = true
    wrong_field_type["date_imported"] = 20260914
    wrong_field_type["license_category"] = 42
    wrong_field_type["kind"] = []
    var wrong_field_errors: PackedStringArray = AssetProvenanceManifest.validate_entry(wrong_field_type)
    _expect(_contains(wrong_field_errors, "asset_name must be a string") and _contains(wrong_field_errors, "source must be a string") and _contains(wrong_field_errors, "date_imported must be a string") and _contains(wrong_field_errors, "license_category must be a string") and _contains(wrong_field_errors, "kind must be a string"), "malformed entry field types are rejected without runtime conversion errors")

    if _failures == 0:
        print("ASSET PROVENANCE MANIFEST TEST PASS")
    else:
        push_error("ASSET PROVENANCE MANIFEST TEST FAILURES: %d" % _failures)
    quit(_failures)

func _base_entry() -> Dictionary:
    return {
        "asset_name": "Fixture Asset",
        "project_path": "res://assets/fixture/example.dat",
        "source": "https://example.invalid/fixture",
        "creator_source": "Fixture Creator",
        "license_category": AssetProvenanceManifest.LICENSE_FREE_COMMERCIAL_USE,
        "license_text": "Fixture free commercial-use license",
        "attribution_text": "",
        "modifications": "none",
        "date_imported": "2026-09-14",
        "responsible_agent": "test-fixture",
        "kind": AssetProvenanceManifest.KIND_OTHER,
    }

func _contains(errors: PackedStringArray, expected: String) -> bool:
    for error: String in errors:
        if error == expected:
            return true
    return false

func _contains_substring(errors: PackedStringArray, expected: String) -> bool:
    for error: String in errors:
        if error.contains(expected):
            return true
    return false

func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
