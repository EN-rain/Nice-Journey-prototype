class_name TowerFloorSessionHost
extends Node2D

const TILE_SIZE: int = TowerFloorRuntimeComposer.DEFAULT_TILE_SIZE
const WORLD_TILES: int = TowerFloorLayoutManifestValidator.MAX_FOOTPRINT_TILES
const WORLD_SIZE_PIXELS: int = TILE_SIZE * WORLD_TILES
const UNCONFIGURED_ESCORT_TUNING: TowerEscortRuntimeTuning = preload("res://src/data/tuning/tower_escort_runtime_unconfigured.tres")

@export var escort_tuning: TowerEscortRuntimeTuning = UNCONFIGURED_ESCORT_TUNING
@export var escort_npc_visual_profile: NpcVisualProfile = preload("res://src/world/npc/presentation/profiles/temporary_escort.tres")

var active_floor_id: int = 0
var active_arrival: Dictionary = {}
var active_runtime_root: Node2D = null
var _escort_runtimes: Dictionary = {}

func activate(
    runtime_root: Node2D,
    arrival: Dictionary,
    player: PlayerController,
    camera: PixelCamera
) -> bool:
    if runtime_root == null or player == null or camera == null:
        return false
    if runtime_root.get_parent() != null:
        return false
    var floor_id := int(runtime_root.get_meta(&"floor_id", 0))
    if floor_id < 1 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return false
    if not _valid_arrival(arrival):
        return false
    var world_tile := arrival["world_tile"] as Vector2i
    var arrival_position := (Vector2(world_tile) + Vector2(0.5, 0.5)) * float(TILE_SIZE)
    if arrival_position.x < 0.0 or arrival_position.y < 0.0 or arrival_position.x >= WORLD_SIZE_PIXELS or arrival_position.y >= WORLD_SIZE_PIXELS:
        return false

    clear_active_floor()
    active_floor_id = floor_id
    active_arrival = arrival.duplicate(true)
    active_runtime_root = runtime_root
    active_runtime_root.name = "ActiveTowerFloor"
    add_child(active_runtime_root)

    player.global_position = to_global(arrival_position)
    player.velocity = Vector2.ZERO
    camera.set_world_bounds(Rect2(to_global(Vector2.ZERO), Vector2(WORLD_SIZE_PIXELS, WORLD_SIZE_PIXELS)))
    camera.reset_after_teleport()
    return true

func clear_active_floor() -> void:
    _escort_runtimes.clear()
    active_floor_id = 0
    active_arrival = {}
    if active_runtime_root != null and is_instance_valid(active_runtime_root):
        if active_runtime_root.get_parent() == self:
            remove_child(active_runtime_root)
        active_runtime_root.free()
    active_runtime_root = null

func has_active_floor() -> bool:
    return active_floor_id >= 1 and active_runtime_root != null and is_instance_valid(active_runtime_root)


func activate_escort(
    profile: ProfileSnapshot,
    floor_state: FloorInstanceState,
    quest_id: StringName,
    authored_tuning: TowerEscortRuntimeTuning = null,
    restored_safe_state: Dictionary = {}
) -> Dictionary:
    if not has_active_floor() or profile == null or floor_state == null or floor_state.floor_id != active_floor_id:
        return {"accepted": false, "reason_id": TowerEscortRuntime.REASON_INVALID_CONTEXT}
    if _escort_runtimes.has(quest_id):
        return {"accepted": false, "reason_id": &"escort_already_active", "quest_id": quest_id}
    var tuning := authored_tuning if authored_tuning != null else escort_tuning
    var runtime := TowerEscortRuntime.new()
    runtime.npc_visual_profile = escort_npc_visual_profile
    runtime.name = _node_name("Escort_%s" % String(quest_id))
    active_runtime_root.add_child(runtime)
    var result := runtime.configure(profile, floor_state, quest_id, tuning, TILE_SIZE, restored_safe_state)
    if not bool(result.get("accepted", false)):
        active_runtime_root.remove_child(runtime)
        runtime.free()
        return result
    _escort_runtimes[quest_id] = runtime
    return result


func has_restorable_escort_tuning() -> bool:
    return escort_tuning != null and escort_tuning.validate_tuning().is_empty()


func capture_escort_safe_states() -> Dictionary:
    var states: Dictionary = {}
    var quest_ids: Array = _escort_runtimes.keys()
    quest_ids.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_quest_id: Variant in quest_ids:
        var quest_id := StringName(String(raw_quest_id))
        var runtime := get_escort_runtime(quest_id)
        if runtime == null:
            return {"accepted": false, "reason_id": &"escort_runtime_missing", "states": {}}
        var safe_state := runtime.capture_safe_state()
        if safe_state.is_empty():
            return {"accepted": false, "reason_id": &"escort_safe_state_unavailable", "quest_id": quest_id, "states": {}}
        states[String(quest_id)] = safe_state.duplicate(true)
    return {"accepted": true, "reason_id": &"", "states": states}


func restore_escort_safe_states(profile: ProfileSnapshot, floor_state: FloorInstanceState, raw_states: Variant) -> Dictionary:
    if not has_active_floor() or profile == null or floor_state == null or floor_state.floor_id != active_floor_id:
        return {"accepted": false, "reason_id": TowerEscortRuntime.REASON_INVALID_CONTEXT}
    if not has_restorable_escort_tuning():
        return {"accepted": false, "reason_id": TowerEscortRuntime.REASON_TUNING_UNAVAILABLE}
    if not raw_states is Dictionary:
        return {"accepted": false, "reason_id": TowerEscortRuntime.REASON_SAFE_STATE_INVALID}
    var states := raw_states as Dictionary
    var restored_ids: Array[StringName] = []
    var keys: Array = states.keys()
    keys.sort_custom(func(left: Variant, right: Variant) -> bool: return String(left) < String(right))
    for raw_key: Variant in keys:
        var quest_id := StringName(String(raw_key))
        var state_variant: Variant = states.get(raw_key, null)
        if not state_variant is Dictionary:
            _clear_restored_escorts(restored_ids)
            return {"accepted": false, "reason_id": TowerEscortRuntime.REASON_SAFE_STATE_INVALID, "quest_id": quest_id}
        var result := activate_escort(profile, floor_state, quest_id, null, state_variant as Dictionary)
        if not bool(result.get("accepted", false)):
            _clear_restored_escorts(restored_ids)
            return result
        restored_ids.append(quest_id)
    return {"accepted": true, "reason_id": &"", "restored_quest_ids": restored_ids.duplicate()}


func get_escort_runtime(quest_id: StringName) -> TowerEscortRuntime:
    var runtime := _escort_runtimes.get(quest_id) as TowerEscortRuntime
    if runtime == null or not is_instance_valid(runtime):
        _escort_runtimes.erase(quest_id)
        return null
    return runtime


func set_escort_wait_requested(quest_id: StringName, wait_requested: bool) -> Dictionary:
    var runtime := get_escort_runtime(quest_id)
    return runtime.set_wait_requested(wait_requested) if runtime != null else {"accepted": false, "reason_id": &"escort_not_active"}


func report_escort_actor_defeated(quest_id: StringName, actor_id: StringName) -> Dictionary:
    var runtime := get_escort_runtime(quest_id)
    return runtime.report_actor_defeated(actor_id) if runtime != null else {"accepted": false, "reason_id": &"escort_not_active"}


func retry_escort(
    quest_id: StringName,
    new_attempt_id: StringName,
    recovery_conditions_satisfied: bool
) -> Dictionary:
    var runtime := get_escort_runtime(quest_id)
    return runtime.retry(new_attempt_id, recovery_conditions_satisfied) if runtime != null else {"accepted": false, "reason_id": &"escort_not_active"}

func _clear_restored_escorts(quest_ids: Array[StringName]) -> void:
    for quest_id: StringName in quest_ids:
        var runtime := get_escort_runtime(quest_id)
        if runtime != null:
            _escort_runtimes.erase(quest_id)
            runtime.queue_free()


func get_world_bounds() -> Rect2:
    return Rect2(to_global(Vector2.ZERO), Vector2(WORLD_SIZE_PIXELS, WORLD_SIZE_PIXELS))

func _exit_tree() -> void:
    clear_active_floor()

func _valid_arrival(arrival: Dictionary) -> bool:
    if not bool(arrival.get("accepted", false)):
        return false
    var arrival_kind := StringName(String(arrival.get("arrival_kind", &"")))
    if not [&"entrance", &"checkpoint"].has(arrival_kind):
        return false
    if not StableId.is_valid(String(arrival.get("arrival_anchor_id", &""))):
        return false
    if not StableId.is_valid(String(arrival.get("room_instance_id", &""))):
        return false
    return arrival.get("world_tile", null) is Vector2i


func _node_name(value: String) -> String:
    return value.replace(":", "_").replace("/", "_").replace("-", "_").replace(".", "_")
