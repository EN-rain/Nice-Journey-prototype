class_name ClaimLedger
extends RefCounted

var _claims: Dictionary = {}

func is_claimed(claim_id: StringName) -> bool:
    return _claims.has(String(claim_id))

func try_claim(claim_id: StringName, source_id: StringName = &"") -> bool:
    var claim_text: String = String(claim_id)
    if not StableId.is_valid(claim_text):
        return false
    if is_claimed(claim_id):
        return false
    var source_text: String = String(source_id)
    if not source_text.is_empty() and not StableId.is_valid(source_text):
        return false
    _claims[claim_text] = {
        "source_id": source_text,
    }
    return true

func get_source_id(claim_id: StringName) -> StringName:
    var entry: Variant = _claims.get(String(claim_id), {})
    if not entry is Dictionary:
        return &""
    return StringName(String((entry as Dictionary).get("source_id", "")))

func to_dictionary() -> Dictionary:
    return _claims.duplicate(true)

func load_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = validate_dictionary(data)
    if not errors.is_empty():
        return errors
    _claims = data.duplicate(true)
    return errors

static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    for claim_variant: Variant in data.keys():
        var claim_id: String = String(claim_variant)
        if not StableId.is_valid(claim_id):
            errors.append("invalid claim_id: %s" % claim_id)
            continue
        var entry: Variant = data[claim_variant]
        if not entry is Dictionary:
            errors.append("claim entry must be a dictionary: %s" % claim_id)
            continue
        var source_id: String = String((entry as Dictionary).get("source_id", ""))
        if not source_id.is_empty() and not StableId.is_valid(source_id):
            errors.append("invalid source_id for claim: %s" % claim_id)
    return errors
