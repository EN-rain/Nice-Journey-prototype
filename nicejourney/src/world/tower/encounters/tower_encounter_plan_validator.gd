class_name TowerEncounterPlanValidator
extends RefCounted

const MAX_SIMULTANEOUS_FULL_AI: int = FullAiSimulationLedger.MAX_FULL_AI_COMBATANTS

static func validate(raw_plan: Variant, floor_state: FloorInstanceState) -> PackedStringArray:
    var errors := PackedStringArray()
    if floor_state == null or not FloorInstanceState.validate_dictionary(floor_state.to_dictionary()).is_empty():
        errors.append("valid floor_state is required")
        return errors
    if floor_state.layout_manifest.is_empty():
        errors.append("floor_state requires a committed layout manifest")
        return errors
    if not raw_plan is Dictionary:
        errors.append("encounter plan must be a dictionary")
        return errors
    var plan := raw_plan as Dictionary
    if not StableId.is_valid(String(plan.get("plan_id", ""))):
        errors.append("plan_id must be a stable ID")
    if typeof(plan.get("floor_id", null)) != TYPE_INT or int(plan.get("floor_id", -1)) != floor_state.floor_id:
        errors.append("plan floor_id must match floor_state")
    if typeof(plan.get("complete_floor_plan", null)) != TYPE_BOOL:
        errors.append("complete_floor_plan must be boolean")
    if not plan.get("placements", null) is Array:
        errors.append("placements must be an array")
        return errors

    var manifest := floor_state.layout_manifest
    var room_by_id: Dictionary = {}
    for raw_room: Variant in manifest.get("rooms", []) as Array:
        if raw_room is Dictionary:
            var room := raw_room as Dictionary
            room_by_id[StringName(String(room.get("room_instance_id", &"")))] = room

    var placements := plan["placements"] as Array
    var floor_entry := PrototypeTowerFloorCatalog.get_entry(floor_state.floor_id)
    var population_budget := int(floor_entry.get("population_budget", 0))
    if placements.size() > population_budget:
        errors.append("placements exceed the approved floor population budget")

    var seen_actors: Dictionary = {}
    var encounter_counts: Dictionary = {}
    var elite_count := 0
    for index: int in range(placements.size()):
        var raw_placement: Variant = placements[index]
        if not raw_placement is Dictionary:
            errors.append("placements[%d] must be a dictionary" % index)
            continue
        var placement := raw_placement as Dictionary
        var actor_id := StringName(String(placement.get("actor_id", &"")))
        if not StableId.is_valid(String(actor_id)):
            errors.append("placements[%d] actor_id must be a stable ID" % index)
        elif seen_actors.has(actor_id):
            errors.append("placements[%d] duplicates actor_id %s" % [index, String(actor_id)])
        else:
            seen_actors[actor_id] = true

        var archetype_id := StringName(String(placement.get("archetype_id", &"")))
        if EnemyArchetypeCatalog.get_definition(archetype_id) == null:
            errors.append("placements[%d] references unknown archetype_id %s" % [index, String(archetype_id)])

        var encounter_id := StringName(String(placement.get("encounter_id", &"")))
        if not StableId.is_valid(String(encounter_id)):
            errors.append("placements[%d] encounter_id must be a stable ID" % index)
        else:
            encounter_counts[encounter_id] = int(encounter_counts.get(encounter_id, 0)) + 1

        var room_id := StringName(String(placement.get("room_instance_id", &"")))
        if not room_by_id.has(room_id):
            errors.append("placements[%d] references unknown room_instance_id" % index)
        else:
            var local_tile_variant: Variant = placement.get("local_tile", null)
            if not local_tile_variant is Vector2i:
                errors.append("placements[%d] local_tile must be Vector2i" % index)
            else:
                var room := room_by_id[room_id] as Dictionary
                var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room.get("module_id", &""))))
                if definition == null:
                    errors.append("placements[%d] room module is unavailable" % index)
                elif not _spawn_tile_allowed(definition, local_tile_variant as Vector2i):
                    errors.append("placements[%d] local_tile must lie in an authored spawn region and outside collision" % index)

        if typeof(placement.get("elite", null)) != TYPE_BOOL:
            errors.append("placements[%d] elite must be boolean" % index)
        elif bool(placement["elite"]):
            elite_count += 1

    for encounter_variant: Variant in encounter_counts.keys():
        if int(encounter_counts[encounter_variant]) > MAX_SIMULTANEOUS_FULL_AI:
            errors.append("encounter %s exceeds the global simultaneous FULL-AI cap" % String(encounter_variant))

    if bool(plan.get("complete_floor_plan", false)):
        var expected_elites := int(floor_entry.get("elite_target", 0))
        if elite_count != expected_elites:
            errors.append("complete floor plan elite count must equal the approved floor elite target")
    return errors

static func placements_for_encounter(plan: Dictionary, encounter_id: StringName) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    var raw_placements: Variant = plan.get("placements", null)
    if not raw_placements is Array:
        return result
    for raw_placement: Variant in raw_placements as Array:
        if not raw_placement is Dictionary:
            continue
        var placement := raw_placement as Dictionary
        if StringName(String(placement.get("encounter_id", &""))) == encounter_id:
            result.append(placement.duplicate(true))
    result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return String(left.get("actor_id", "")) < String(right.get("actor_id", ""))
    )
    return result

static func world_tile_for_placement(floor_state: FloorInstanceState, placement: Dictionary) -> Variant:
    if floor_state == null or floor_state.layout_manifest.is_empty() or not placement.get("local_tile", null) is Vector2i:
        return null
    var room_id := StringName(String(placement.get("room_instance_id", &"")))
    for raw_room: Variant in floor_state.layout_manifest.get("rooms", []) as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        if StringName(String(room.get("room_instance_id", &""))) != room_id:
            continue
        if not room.get("rect", null) is Rect2i:
            return null
        return (room["rect"] as Rect2i).position + (placement["local_tile"] as Vector2i)
    return null

static func _spawn_tile_allowed(definition: TowerRoomModuleDefinition, local_tile: Vector2i) -> bool:
    var in_spawn_region := false
    for rect: Rect2i in definition.spawn_regions:
        if rect.has_point(local_tile):
            in_spawn_region = true
            break
    if not in_spawn_region:
        return false
    var walkable := false
    for rect: Rect2i in definition.walkable_rects:
        if rect.has_point(local_tile):
            walkable = true
            break
    if not walkable:
        return false
    for rect: Rect2i in definition.collision_rects:
        if rect.has_point(local_tile):
            return false
    return true
