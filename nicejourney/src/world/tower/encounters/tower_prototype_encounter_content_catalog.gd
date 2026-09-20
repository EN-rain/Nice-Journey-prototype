class_name TowerPrototypeEncounterContentCatalog
extends RefCounted

# Reversible greybox/playtest allocation for §53. It supplies mechanical content to the
# already-authoritative encounter/runtime boundaries without establishing narrative canon
# or final balance. Floor 10's count excludes The Tenth Warden, which remains boss-owned.
const REUSABLE_ENEMY_TARGETS: Dictionary = {
    1: 3,
    2: 4,
    3: 4,
    4: 5,
    5: 6,
    6: 6,
    7: 6,
    8: 7,
    9: 8,
    10: 7,
}
const DEFENSE_OBJECTIVE_MAX_HP_INITIAL_TUNING: int = 100

static func build_plan(floor_state: FloorInstanceState) -> Dictionary:
    if floor_state == null or not FloorInstanceState.validate_dictionary(floor_state.to_dictionary()).is_empty():
        return {}
    if floor_state.layout_manifest.is_empty():
        return {}
    var floor_id := floor_state.floor_id
    if not REUSABLE_ENEMY_TARGETS.has(floor_id):
        return {}

    var eligible_rooms := _eligible_rooms(floor_state)
    if eligible_rooms.is_empty():
        return {}
    var target_count := int(REUSABLE_ENEMY_TARGETS[floor_id])
    var elite_target := int(PrototypeTowerFloorCatalog.get_entry(floor_id).get("elite_target", 0))
    var elite_room_id := _elite_room_id(eligible_rooms) if elite_target > 0 else &""
    if elite_target > 0 and elite_room_id == &"":
        return {}

    var room_tiles: Dictionary = {}
    for room: Dictionary in eligible_rooms:
        var room_id := StringName(String(room.get("room_instance_id", &"")))
        var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room.get("module_id", &""))))
        if definition == null:
            return {}
        room_tiles[room_id] = _spawn_tiles(definition)
        if (room_tiles[room_id] as Array).is_empty():
            return {}

    var placements: Array[Dictionary] = []
    var archetype_pool := _archetype_pool_for_floor(floor_id)
    var room_cursor := 0
    var room_use_counts: Dictionary = {}
    for index: int in range(target_count):
        var elite := index < elite_target
        var room := _room_for_index(eligible_rooms, elite_room_id, elite, room_cursor)
        if room.is_empty():
            return {}
        if not elite:
            room_cursor += 1
        var room_id := StringName(String(room["room_instance_id"]))
        var used := int(room_use_counts.get(room_id, 0))
        var tiles := room_tiles[room_id] as Array
        if used >= tiles.size():
            return {}
        var archetype_offset := (floor_id - 1) % archetype_pool.size()
        var archetype_id: StringName = archetype_pool[(archetype_offset + index) % archetype_pool.size()]
        placements.append({
            "actor_id": StringName("enemy:tower_f%02d_%02d_%s" % [floor_id, index + 1, String(archetype_id)]),
            "archetype_id": archetype_id,
            "encounter_id": _encounter_id(floor_id, room_id),
            "room_instance_id": room_id,
            "local_tile": tiles[used] as Vector2i,
            "elite": elite,
        })
        room_use_counts[room_id] = used + 1

    var plan := {
        "plan_id": StringName("encounter_plan:tower_floor_%02d_playtest_v01" % floor_id),
        "floor_id": floor_id,
        "complete_floor_plan": true,
        "placements": placements,
        "content_status": &"playtest_placeholder",
        "boss_owned_separately": floor_id == 10,
    }
    if not TowerEncounterPlanValidator.validate(plan, floor_state).is_empty():
        return {}
    return plan

static func objective_configs(floor_state: FloorInstanceState, plan: Dictionary) -> Dictionary:
    if floor_state == null or not TowerEncounterPlanValidator.validate(plan, floor_state).is_empty():
        return {}
    var result: Dictionary = {}
    var bindings := floor_state.layout_manifest.get("objective_bindings", {}) as Dictionary
    for raw_quest_id: Variant in bindings.keys():
        var quest_id := StringName(String(raw_quest_id))
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null:
            continue
        var room_id := StringName(String(bindings[raw_quest_id]))
        var actor_ids := _actor_ids_for_room(plan, room_id)
        match definition.family:
            QuestDefinition.FAMILY_ANNIHILATION:
                if not actor_ids.is_empty():
                    result[quest_id] = {"required_actor_ids": actor_ids}
            QuestDefinition.FAMILY_TOWER_DEFENSE:
                if not actor_ids.is_empty():
                    var wave_id := StringName("wave:%s_01" % String(quest_id))
                    result[quest_id] = {
                        "objective_id": StringName("objective:%s" % String(quest_id)),
                        "objective_max_hp": DEFENSE_OBJECTIVE_MAX_HP_INITIAL_TUNING,
                        "required_actor_ids_by_wave": {wave_id: actor_ids},
                    }
            QuestDefinition.FAMILY_ESCORT:
                var authored := TowerEscortObjectiveAuthoring.build(floor_state, quest_id)
                var objective_config_variant: Variant = authored.get("objective_config", null)
                if objective_config_variant is Dictionary and not (objective_config_variant as Dictionary).is_empty():
                    result[quest_id] = (objective_config_variant as Dictionary).duplicate(true)
    return result

static func quest_bindings_by_actor(floor_state: FloorInstanceState, plan: Dictionary) -> Dictionary:
    if floor_state == null or not TowerEncounterPlanValidator.validate(plan, floor_state).is_empty():
        return {}
    var result: Dictionary = {}
    var objective_bindings := floor_state.layout_manifest.get("objective_bindings", {}) as Dictionary
    for raw_quest_id: Variant in objective_bindings.keys():
        var quest_id := StringName(String(raw_quest_id))
        var definition := QuestCatalog.get_definition(quest_id)
        if definition == null or definition.family == QuestDefinition.FAMILY_ESCORT:
            continue
        var room_id := StringName(String(objective_bindings[raw_quest_id]))
        var wave_id := StringName("wave:%s_01" % String(quest_id))
        for actor_id: StringName in _actor_ids_for_room(plan, room_id):
            var entry := {"quest_id": quest_id}
            if definition.family == QuestDefinition.FAMILY_TOWER_DEFENSE:
                entry["wave_id"] = wave_id
            var actor_bindings: Array = result.get(actor_id, []) as Array
            actor_bindings.append(entry)
            result[actor_id] = actor_bindings
    return result

static func encounter_ids(plan: Dictionary) -> Array[StringName]:
    var result: Array[StringName] = []
    var seen: Dictionary = {}
    var placements_variant: Variant = plan.get("placements", null)
    if not placements_variant is Array:
        return result
    for raw_placement: Variant in placements_variant as Array:
        if not raw_placement is Dictionary:
            continue
        var encounter_id := StringName(String((raw_placement as Dictionary).get("encounter_id", &"")))
        if StableId.is_valid(String(encounter_id)) and not seen.has(encounter_id):
            seen[encounter_id] = true
            result.append(encounter_id)
    result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
    return result

static func _eligible_rooms(floor_state: FloorInstanceState) -> Array[Dictionary]:
    var result: Array[Dictionary] = []
    for raw_room: Variant in floor_state.layout_manifest.get("rooms", []) as Array:
        if not raw_room is Dictionary:
            continue
        var room := raw_room as Dictionary
        var tags := room.get("tags", []) as Array
        if floor_state.floor_id == 10 and tags.has(TowerFloorLayoutManifestValidator.TAG_BOSS):
            continue
        var definition := TowerPrototypeModuleCatalog.get_definition(StringName(String(room.get("module_id", &""))))
        if definition != null and not definition.spawn_regions.is_empty():
            result.append(room.duplicate(true))
    result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
        return String(left.get("room_instance_id", "")) < String(right.get("room_instance_id", ""))
    )
    return result

static func _elite_room_id(rooms: Array[Dictionary]) -> StringName:
    for room: Dictionary in rooms:
        if int(room.get("elite_capacity", 0)) >= 3:
            return StringName(String(room.get("room_instance_id", &"")))
    return &""

static func _room_for_index(rooms: Array[Dictionary], elite_room_id: StringName, elite: bool, cursor: int) -> Dictionary:
    if elite:
        for room: Dictionary in rooms:
            if StringName(String(room.get("room_instance_id", &""))) == elite_room_id:
                return room
        return {}
    var non_elite_rooms: Array[Dictionary] = []
    for room: Dictionary in rooms:
        if StringName(String(room.get("room_instance_id", &""))) != elite_room_id or rooms.size() == 1:
            non_elite_rooms.append(room)
    if non_elite_rooms.is_empty():
        non_elite_rooms = rooms.duplicate(true)
    return non_elite_rooms[cursor % non_elite_rooms.size()]

static func _spawn_tiles(definition: TowerRoomModuleDefinition) -> Array[Vector2i]:
    var result: Array[Vector2i] = []
    for rect: Rect2i in definition.spawn_regions:
        for y: int in range(rect.position.y, rect.end.y):
            for x: int in range(rect.position.x, rect.end.x):
                var tile := Vector2i(x, y)
                var blocked := false
                for collision: Rect2i in definition.collision_rects:
                    if collision.has_point(tile):
                        blocked = true
                        break
                if not blocked:
                    result.append(tile)
    return result

static func _archetype_pool_for_floor(floor_id: int) -> Array[StringName]:
    var count := clampi(floor_id + 2, 3, EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS.size())
    var result: Array[StringName] = []
    for index: int in range(count):
        result.append(EnemyArchetypeCatalog.ALL_ARCHETYPE_IDS[index])
    return result

static func _actor_ids_for_room(plan: Dictionary, room_id: StringName) -> Array[StringName]:
    var result: Array[StringName] = []
    for raw_placement: Variant in plan.get("placements", []) as Array:
        if not raw_placement is Dictionary:
            continue
        var placement := raw_placement as Dictionary
        if StringName(String(placement.get("room_instance_id", &""))) == room_id:
            result.append(StringName(String(placement.get("actor_id", &""))))
    result.sort_custom(func(left: StringName, right: StringName) -> bool: return String(left) < String(right))
    return result

static func _encounter_id(floor_id: int, room_id: StringName) -> StringName:
    var room_component := String(room_id).replace(":", "_").replace("/", "_").replace(".", "_").replace("-", "_")
    return StringName("encounter:tower_f%02d_%s" % [floor_id, room_component])
