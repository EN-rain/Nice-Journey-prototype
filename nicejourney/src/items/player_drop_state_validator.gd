extends RefCounted

const ENTRY_KIND: StringName = &"player_drop"
const SOURCE_PREFIX: String = "player_drop:"


static func validate_entry(entry_variant: Variant, expected_source_id: StringName) -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(expected_source_id)) or not String(expected_source_id).begins_with(SOURCE_PREFIX):
        errors.append("player drop source ID must be a stable player_drop:* ID")
        return errors
    if not entry_variant is Dictionary:
        errors.append("player drop entry must be a dictionary")
        return errors
    var entry := entry_variant as Dictionary
    if StringName(String(entry.get("entry_kind", &""))) != ENTRY_KIND:
        errors.append("player drop entry_kind must be player_drop")
    if StringName(String(entry.get("source_id", &""))) != expected_source_id:
        errors.append("player drop source_id must match its loose_items key")

    var item_variant: Variant = entry.get("item", null)
    if not item_variant is Dictionary:
        errors.append("player drop item must be a dictionary")
    else:
        var item := item_variant as Dictionary
        var standalone_inventory := {
            "gold": 0,
            "normal_slots": [item.duplicate(true)],
            "protected_items": {},
            "quick_slots": ["", "", "", ""],
        }
        var item_errors := InventoryState.validate_dictionary(standalone_inventory)
        for item_error: String in item_errors:
            errors.append("player drop item: %s" % item_error)

    var position_variant: Variant = entry.get("world_position", null)
    if not position_variant is Dictionary:
        errors.append("player drop world_position must be a dictionary")
    else:
        var position := position_variant as Dictionary
        if not _finite_number(position.get("x", null)) or not _finite_number(position.get("y", null)):
            errors.append("player drop world_position must contain finite numeric x/y")
    return errors


static func should_validate_entry(source_key: Variant, entry_variant: Variant) -> bool:
    var source_text := String(source_key)
    if source_text.begins_with(SOURCE_PREFIX):
        return true
    if entry_variant is Dictionary:
        return StringName(String((entry_variant as Dictionary).get("entry_kind", &""))) == ENTRY_KIND
    return false


static func _finite_number(value: Variant) -> bool:
    var value_type := typeof(value)
    return (value_type == TYPE_INT or value_type == TYPE_FLOAT) and is_finite(float(value))
