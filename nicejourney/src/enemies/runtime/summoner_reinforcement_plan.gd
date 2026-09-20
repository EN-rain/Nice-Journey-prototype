class_name SummonerReinforcementPlan
extends RefCounted

# Reserve fixed actor IDs and collision-free tiles in authored room spawn regions.
# Every Summoner on the floor is counted, including ones in another encounter.
static func build(plan: Dictionary, floor_state: FloorInstanceState, encounter_id: StringName,
    tuning: SummonerReinforcementPlaytestTuning) -> Dictionary:
    if (
        floor_state == null or tuning == null or not tuning.validate_tuning().is_empty()
        or not TowerEncounterPlanValidator.validate(plan, floor_state).is_empty()
    ):
        return _rejected(&"reinforcement_invalid_authoring")
    var placements := plan.get("placements", []) as Array
    var summoners: Array[Dictionary] = []
    var occupied: Dictionary = {}
    var seen_ids: Dictionary = {}
    for raw_placement: Variant in placements:
        var placement := raw_placement as Dictionary
        var room_id := StringName(String(placement["room_instance_id"]))
        occupied[_tile_key(room_id, placement["local_tile"] as Vector2i)] = true
        seen_ids[StringName(String(placement["actor_id"]))] = true
        if StringName(String(placement["archetype_id"])) == &"summoner":
            summoners.append(placement)
    var population_budget := int(PrototypeTowerFloorCatalog.get_entry(floor_state.floor_id).get("population_budget", 0))
    if placements.size() + summoners.size() * tuning.calls_per_summoner > population_budget:
        return _rejected(&"reinforcement_floor_population_budget")
    summoners.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return String(a["actor_id"]) < String(b["actor_id"]))
    var rooms: Dictionary = {}
    for raw_room: Variant in floor_state.layout_manifest.get("rooms", []) as Array:
        var room := raw_room as Dictionary
        rooms[StringName(String(room.get("room_instance_id", &"")))] = room
    var slots_by_summoner: Dictionary = {}
    for summoner: Dictionary in summoners:
        var summoner_id := StringName(String(summoner["actor_id"]))
        var room_id := StringName(String(summoner["room_instance_id"]))
        var room := rooms.get(room_id, {}) as Dictionary
        var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room.get("module_id", &""))))
        if definition == null:
            return _rejected(&"reinforcement_room_missing")
        var candidates: Array[Vector2i] = []
        var candidate_keys: Dictionary = {}
        for rect: Rect2i in definition.spawn_regions:
            for y: int in range(rect.position.y, rect.end.y):
                for x: int in range(rect.position.x, rect.end.x):
                    var tile := Vector2i(x, y)
                    var tile_key := _tile_key(room_id, tile)
                    if occupied.has(tile_key) or candidate_keys.has(tile_key) or not _is_safe_tile(definition, tile):
                        continue
                    candidate_keys[tile_key] = true
                    candidates.append(tile)
        var origin := summoner["local_tile"] as Vector2i
        candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
            var da := (a - origin).length_squared()
            var db := (b - origin).length_squared()
            return da < db if da != db else (a.y < b.y if a.y != b.y else a.x < b.x))
        if candidates.size() < tuning.calls_per_summoner:
            return _rejected(&"reinforcement_spawn_space_unavailable")
        var slots: Array[Dictionary] = []
        for index: int in tuning.calls_per_summoner:
            var actor_id := StringName("enemy:summon_%s_%02d" % [String(summoner_id).replace(":", "_"), index + 1])
            if not StableId.is_valid(String(actor_id)) or seen_ids.has(actor_id):
                return _rejected(&"reinforcement_actor_id_collision")
            seen_ids[actor_id] = true
            var local_tile := candidates[index]
            occupied[_tile_key(room_id, local_tile)] = true
            if StringName(String(summoner["encounter_id"])) != encounter_id:
                continue
            slots.append({
                "actor_id": actor_id,
                "summoner_id": summoner_id,
                "archetype_id": tuning.reinforcement_archetype_id,
                "encounter_id": encounter_id,
                "room_instance_id": room_id,
                "local_tile": local_tile,
                "world_tile": (room["rect"] as Rect2i).position + local_tile,
                "elite": false,
            })
        if not slots.is_empty():
            slots_by_summoner[summoner_id] = slots
    return {"accepted": true, "reason_id": &"", "slots_by_summoner": slots_by_summoner,
        "floor_reserved_count": placements.size() + summoners.size() * tuning.calls_per_summoner}


static func _is_safe_tile(definition: TowerRoomModuleDefinition, tile: Vector2i) -> bool:
    var walkable := false
    for rect: Rect2i in definition.walkable_rects:
        if rect.has_point(tile):
            walkable = true
            break
    if not walkable:
        return false
    for rect: Rect2i in definition.collision_rects:
        if rect.has_point(tile):
            return false
    for rect: Rect2i in definition.hazard_exclusion_regions:
        if rect.has_point(tile):
            return false
    return true


static func _tile_key(room_id: StringName, tile: Vector2i) -> String:
    return "%s/%d/%d" % [String(room_id), tile.x, tile.y]


static func _rejected(reason_id: StringName) -> Dictionary:
    return {"accepted": false, "reason_id": reason_id, "slots_by_summoner": {}, "floor_reserved_count": 0}
