class_name PrototypeTowerFloorCatalog
extends RefCounted

const FLOOR_COUNT: int = 10

static func all_entries() -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for floor_id: int in range(1, FLOOR_COUNT + 1):
        result.append({
            "floor_id": floor_id,
            "recommended_level": floor_id,
            "population_budget": floor_id * 10,
            "elite_target": 3 if floor_id == 5 or floor_id == 10 else 0,
            "boss": floor_id == 10,
        })
    return result

static func get_entry(floor_id: int) -> Dictionary:
    if floor_id < 1 or floor_id > FLOOR_COUNT:
        return {}
    return all_entries()[floor_id - 1].duplicate(true)

static func validate_catalog() -> PackedStringArray:
    var errors := PrototypeTowerFloorCatalogValidator.validate_entries(all_entries())
    for entry: Dictionary in all_entries():
        var floor_id := int(entry["floor_id"])
        if int(entry.get("recommended_level", 0)) != floor_id:
            errors.append("Floor %d recommended_level must equal the approved prototype value" % floor_id)
        if int(entry.get("population_budget", 0)) != floor_id * 10:
            errors.append("Floor %d population_budget must equal the approved prototype value" % floor_id)
        var expected_elites := 3 if floor_id == 5 or floor_id == 10 else 0
        if int(entry.get("elite_target", -1)) != expected_elites:
            errors.append("Floor %d elite_target does not match the approved prototype table" % floor_id)
        if bool(entry.get("boss", false)) != (floor_id == 10):
            errors.append("only Floor 10 may carry the prototype boss warning")
    return errors
