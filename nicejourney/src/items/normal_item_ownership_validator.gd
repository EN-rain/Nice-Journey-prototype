extends RefCounted

# An item may have quick-slot/equipment references, but exactly one normal
# ownership location: portable inventory, storage, or a persisted player drop.
const PLAYER_DROP_STATE_VALIDATOR: Script = preload("res://src/items/player_drop_state_validator.gd")


static func validate_profile_dictionary(profile_data: Dictionary) -> PackedStringArray:
    var errors := PackedStringArray()
    var first_owner_by_instance: Dictionary = {}

    _record_normal_slots(profile_data.get("item_state", null), "item_state", first_owner_by_instance, errors)
    _record_normal_slots(profile_data.get("storage_state", null), "storage_state", first_owner_by_instance, errors)

    var region_state: Variant = profile_data.get("region_state", null)
    if region_state is Dictionary:
        _record_player_drops(
            (region_state as Dictionary).get("loose_items", null),
            "region_state.loose_items",
            first_owner_by_instance,
            errors
        )

    var raw_floors: Variant = profile_data.get("tower_floor_states", null)
    if raw_floors is Dictionary:
        for raw_floor_id: Variant in (raw_floors as Dictionary).keys():
            var floor_state: Variant = (raw_floors as Dictionary)[raw_floor_id]
            if not floor_state is Dictionary:
                continue
            _record_player_drops(
                (floor_state as Dictionary).get("loose_items", null),
                "tower_floor_states[%s].loose_items" % String(raw_floor_id),
                first_owner_by_instance,
                errors
            )
    return errors


static func _record_normal_slots(
    raw_state: Variant,
    owner_path: String,
    first_owner_by_instance: Dictionary,
    errors: PackedStringArray
) -> void:
    if not raw_state is Dictionary:
        return
    var slots: Variant = (raw_state as Dictionary).get("normal_slots", null)
    if not slots is Array:
        return
    for index: int in range((slots as Array).size()):
        var slot: Variant = (slots as Array)[index]
        if not slot is Dictionary:
            continue
        _record_instance(
            (slot as Dictionary).get("item_instance_id", null),
            "%s.normal_slots[%d]" % [owner_path, index],
            first_owner_by_instance,
            errors
        )


static func _record_player_drops(
    raw_loose_items: Variant,
    owner_path: String,
    first_owner_by_instance: Dictionary,
    errors: PackedStringArray
) -> void:
    if not raw_loose_items is Dictionary:
        return
    for raw_source_id: Variant in (raw_loose_items as Dictionary).keys():
        var raw_entry: Variant = (raw_loose_items as Dictionary)[raw_source_id]
        if not PLAYER_DROP_STATE_VALIDATOR.should_validate_entry(raw_source_id, raw_entry):
            continue # Ordinary resolved loot is not a player-owned item instance.
        if not raw_entry is Dictionary:
            continue
        var item: Variant = (raw_entry as Dictionary).get("item", null)
        if not item is Dictionary:
            continue
        _record_instance(
            (item as Dictionary).get("item_instance_id", null),
            "%s[%s].item" % [owner_path, String(raw_source_id)],
            first_owner_by_instance,
            errors
        )


static func _record_instance(
    raw_instance_id: Variant,
    owner_path: String,
    first_owner_by_instance: Dictionary,
    errors: PackedStringArray
) -> void:
    var instance_id := String(raw_instance_id)
    if not StableId.is_valid(instance_id):
        return # The local owner validator reports missing/malformed IDs.
    if first_owner_by_instance.has(instance_id):
        errors.append(
            "item_instance_id %s has multiple normal owners: %s and %s" %
            [instance_id, String(first_owner_by_instance[instance_id]), owner_path]
        )
        return
    first_owner_by_instance[instance_id] = owner_path
