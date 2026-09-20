class_name PrimaryFloorExitCommitProof
extends RefCounted

const PROOF_KEY: String = "primary_exit_commit"
const REGION3_MAP_ID: StringName = &"region:3"
const REGION3_TOWN_CHECKPOINT_ID: StringName = &"checkpoint:region3_town"


static func mark_committed_exit(
    floor_state: FloorInstanceState,
    quest_id: StringName,
    checkpoint_id: StringName,
    snapshot_sequence: int
) -> bool:
    if (
        floor_state == null
        or not StableId.is_valid(String(quest_id))
        or not StableId.is_valid(String(checkpoint_id))
        or snapshot_sequence < 1
    ):
        return false
    var exit_room_id := StringName(String(floor_state.layout_manifest.get("exit_room_id", &"")))
    if checkpoint_id != exit_room_id or floor_state.get_checkpoint_anchor(checkpoint_id).is_empty():
        return false
    var next_quest_state := floor_state.quest_state.duplicate(true)
    next_quest_state[PROOF_KEY] = {
        "committed": true,
        "quest_id": String(quest_id),
        "checkpoint_id": String(checkpoint_id),
        "snapshot_sequence": snapshot_sequence,
    }
    floor_state.quest_state = next_quest_state
    return true


static func is_valid_floor_proof(floor_data: Dictionary, floor_id: int, quest_id: StringName) -> bool:
    if floor_id < 1 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT or not StableId.is_valid(String(quest_id)):
        return false
    var floor_state := FloorInstanceState.new()
    if not floor_state.load_dictionary(floor_data).is_empty() or floor_state.floor_id != floor_id:
        return false
    var raw_proof: Variant = floor_state.quest_state.get(PROOF_KEY, null)
    if not raw_proof is Dictionary:
        return false
    var proof := raw_proof as Dictionary
    if typeof(proof.get("committed", null)) != TYPE_BOOL or not bool(proof.get("committed", false)):
        return false
    if StringName(String(proof.get("quest_id", &""))) != quest_id:
        return false
    var checkpoint_id := StringName(String(proof.get("checkpoint_id", &"")))
    if not StableId.is_valid(String(checkpoint_id)):
        return false
    var sequence_variant: Variant = proof.get("snapshot_sequence", null)
    if not _is_integral(sequence_variant) or int(sequence_variant) < 1:
        return false
    var exit_room_id := StringName(String(floor_state.layout_manifest.get("exit_room_id", &"")))
    return checkpoint_id == exit_room_id and not floor_state.get_checkpoint_anchor(checkpoint_id).is_empty()


static func is_turn_in_safe_context(
    floor_data: Dictionary,
    floor_id: int,
    quest_id: StringName,
    safe_state: Dictionary
) -> bool:
    if not SafeCheckpointState.validate_dictionary(safe_state).is_empty():
        return false
    if int(safe_state.get("floor_id", -1)) == floor_id:
        return true
    if (
        int(safe_state.get("floor_id", -1)) != 0
        or StringName(String(safe_state.get("map_id", &""))) != REGION3_MAP_ID
        or StringName(String(safe_state.get("checkpoint_anchor_id", &""))) != REGION3_TOWN_CHECKPOINT_ID
    ):
        return false
    return is_valid_floor_proof(floor_data, floor_id, quest_id)


static func _is_integral(value: Variant) -> bool:
    if typeof(value) == TYPE_INT:
        return true
    if typeof(value) != TYPE_FLOAT:
        return false
    var number := float(value)
    return is_finite(number) and is_equal_approx(number, round(number))
