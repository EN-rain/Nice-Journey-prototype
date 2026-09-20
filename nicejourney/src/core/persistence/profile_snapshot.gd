class_name ProfileSnapshot
extends RefCounted

const SCHEMA_VERSION: int = 1
const MIN_LEVEL: int = 1
const MAX_LEVEL: int = 10
const CLASS_IDS: Array[String] = ["melee", "ranged", "mage"]
const NORMAL_ITEM_OWNERSHIP_VALIDATOR: Script = preload("res://src/items/normal_item_ownership_validator.gd")

var profile_id: String = ""
var protagonist_name: String = ""
var class_id: String = ""
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var automatic_stats: Dictionary = {}
var skill_state: Dictionary = {}
var item_state: Dictionary = {}
var storage_state: Dictionary = {}
var equipment_state: Dictionary = {}
var economy_state: Dictionary = {}
var region_state: Dictionary = {}
var tower_floor_states: Dictionary = {}
var safe_state: Dictionary = {}
var quest_progress: Dictionary = {}
var permanent_flags: Dictionary = {}
var claimed_transactions: Dictionary = {}

func to_dictionary() -> Dictionary:
    return {
        "schema_version": SCHEMA_VERSION,
        "profile_id": profile_id,
        "protagonist_name": protagonist_name,
        "class_id": class_id,
        "level": level,
        "xp": xp,
        "skill_points": skill_points,
        "automatic_stats": automatic_stats.duplicate(true),
        "skill_state": skill_state.duplicate(true),
        "item_state": item_state.duplicate(true),
        "storage_state": storage_state.duplicate(true),
        "equipment_state": equipment_state.duplicate(true),
        "economy_state": economy_state.duplicate(true),
        "region_state": region_state.duplicate(true),
        "tower_floor_states": tower_floor_states.duplicate(true),
        "safe_state": safe_state.duplicate(true),
        "quest_progress": quest_progress.duplicate(true),
        "permanent_flags": permanent_flags.duplicate(true),
        "claimed_transactions": claimed_transactions.duplicate(true),
    }

static func from_dictionary(data: Dictionary) -> ProfileSnapshot:
    var snapshot: ProfileSnapshot = ProfileSnapshot.new()
    snapshot.profile_id = String(data.get("profile_id", ""))
    snapshot.protagonist_name = String(data.get("protagonist_name", ""))
    snapshot.class_id = String(data.get("class_id", ""))
    snapshot.level = int(data.get("level", MIN_LEVEL))
    snapshot.xp = int(data.get("xp", 0))
    snapshot.skill_points = int(data.get("skill_points", 0))
    var raw_automatic_stats: Variant = data.get("automatic_stats", {})
    if raw_automatic_stats is Dictionary:
        snapshot.automatic_stats = AutomaticStatState.normalize_dictionary(raw_automatic_stats)
    var raw_skill_state: Variant = data.get("skill_state", {})
    if raw_skill_state is Dictionary:
        snapshot.skill_state = (raw_skill_state as Dictionary).duplicate(true)
    var raw_item_state: Variant = data.get("item_state", {})
    if raw_item_state is Dictionary:
        snapshot.item_state = (raw_item_state as Dictionary).duplicate(true)
    var raw_storage_state: Variant = data.get("storage_state", {})
    if raw_storage_state is Dictionary:
        snapshot.storage_state = (raw_storage_state as Dictionary).duplicate(true)
    var raw_equipment_state: Variant = data.get("equipment_state", {})
    if raw_equipment_state is Dictionary:
        snapshot.equipment_state = (raw_equipment_state as Dictionary).duplicate(true)
    var raw_economy_state: Variant = data.get("economy_state", {})
    if raw_economy_state is Dictionary:
        snapshot.economy_state = (raw_economy_state as Dictionary).duplicate(true)
    var raw_region_state: Variant = data.get("region_state", {})
    if raw_region_state is Dictionary:
        snapshot.region_state = (raw_region_state as Dictionary).duplicate(true)
    var raw_floor_states: Variant = data.get("tower_floor_states", {})
    if raw_floor_states is Dictionary:
        snapshot.tower_floor_states = (raw_floor_states as Dictionary).duplicate(true)
    var raw_safe_state: Variant = data.get("safe_state", {})
    if raw_safe_state is Dictionary:
        snapshot.safe_state = (raw_safe_state as Dictionary).duplicate(true)
    var raw_quest_progress: Variant = data.get("quest_progress", {})
    if raw_quest_progress is Dictionary:
        snapshot.quest_progress = (raw_quest_progress as Dictionary).duplicate(true)
    var raw_flags: Variant = data.get("permanent_flags", {})
    if raw_flags is Dictionary:
        snapshot.permanent_flags = (raw_flags as Dictionary).duplicate(true)
    var raw_claims: Variant = data.get("claimed_transactions", {})
    if raw_claims is Dictionary:
        snapshot.claimed_transactions = (raw_claims as Dictionary).duplicate(true)
    return snapshot

static func validate_dictionary(data: Dictionary) -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    if int(data.get("schema_version", -1)) != SCHEMA_VERSION:
        errors.append("unsupported schema_version")

    var candidate_profile_id: String = String(data.get("profile_id", ""))
    if not StableId.is_valid(candidate_profile_id):
        errors.append("invalid profile_id")

    var candidate_name: String = String(data.get("protagonist_name", "")).strip_edges()
    if candidate_name.is_empty() or candidate_name.length() > 40:
        errors.append("protagonist_name must contain 1-40 non-edge-whitespace characters")

    var candidate_class: String = String(data.get("class_id", ""))
    if not CLASS_IDS.has(candidate_class):
        errors.append("class_id must be melee, ranged, or mage")

    var candidate_level: int = int(data.get("level", 0))
    if candidate_level < MIN_LEVEL or candidate_level > MAX_LEVEL:
        errors.append("level must be between 1 and 10")

    if int(data.get("xp", -1)) < 0:
        errors.append("xp cannot be negative")
    if int(data.get("skill_points", -1)) < 0:
        errors.append("skill_points cannot be negative")

    var raw_automatic_stats: Variant = data.get("automatic_stats", {})
    var automatic_stat_errors := AutomaticStatState.validate_dictionary(raw_automatic_stats)
    for automatic_stat_error: String in automatic_stat_errors:
        errors.append("automatic_stats: %s" % automatic_stat_error)

    var raw_skill_state: Variant = data.get("skill_state", {})
    if not raw_skill_state is Dictionary:
        errors.append("skill_state must be a dictionary")
    elif not (raw_skill_state as Dictionary).is_empty():
        var skill_errors: PackedStringArray = SkillLoadoutState.validate_dictionary(raw_skill_state as Dictionary)
        for skill_error: String in skill_errors:
            errors.append("skill_state: %s" % skill_error)
        if String((raw_skill_state as Dictionary).get("class_id", "")) != candidate_class:
            errors.append("skill_state class_id must match profile class_id")

    var raw_item_state: Variant = data.get("item_state", {})
    if not raw_item_state is Dictionary:
        errors.append("item_state must be a dictionary")
    elif not (raw_item_state as Dictionary).is_empty():
        var item_errors: PackedStringArray = InventoryState.validate_dictionary(raw_item_state as Dictionary)
        for item_error: String in item_errors:
            errors.append("item_state: %s" % item_error)

    var raw_storage_state: Variant = data.get("storage_state", {})
    if not raw_storage_state is Dictionary:
        errors.append("storage_state must be a dictionary")
    elif not (raw_storage_state as Dictionary).is_empty():
        var storage_errors: PackedStringArray = StorageState.validate_dictionary(raw_storage_state as Dictionary)
        for storage_error: String in storage_errors:
            errors.append("storage_state: %s" % storage_error)

    var raw_equipment_state: Variant = data.get("equipment_state", {})
    if not raw_equipment_state is Dictionary:
        errors.append("equipment_state must be a dictionary")
    elif not (raw_equipment_state as Dictionary).is_empty():
        var equipment_errors: PackedStringArray = EquipmentState.validate_dictionary(raw_equipment_state as Dictionary)
        for equipment_error: String in equipment_errors:
            errors.append("equipment_state: %s" % equipment_error)

    var raw_economy_state: Variant = data.get("economy_state", {})
    if not raw_economy_state is Dictionary:
        errors.append("economy_state must be a dictionary")
    elif not (raw_economy_state as Dictionary).is_empty():
        var economy_errors: PackedStringArray = EconomyState.validate_dictionary(raw_economy_state as Dictionary)
        for economy_error: String in economy_errors:
            errors.append("economy_state: %s" % economy_error)

    var raw_region_state: Variant = data.get("region_state", {})
    var region_errors := Region3SubzoneDiscoveryService.validate_state_dictionary(raw_region_state)
    for region_error: String in region_errors:
        errors.append("region_state: %s" % region_error)

    var raw_floor_states: Variant = data.get("tower_floor_states", {})
    if not raw_floor_states is Dictionary:
        errors.append("tower_floor_states must be a dictionary")
    else:
        for floor_key: Variant in (raw_floor_states as Dictionary).keys():
            var floor_data: Variant = (raw_floor_states as Dictionary)[floor_key]
            if not floor_data is Dictionary:
                errors.append("tower_floor_states entry must be a dictionary: %s" % String(floor_key))
                continue
            var floor_errors: PackedStringArray = FloorInstanceState.validate_dictionary(floor_data as Dictionary)
            for floor_error: String in floor_errors:
                errors.append("tower_floor_states[%s]: %s" % [String(floor_key), floor_error])
            if str(int((floor_data as Dictionary).get("floor_id", 0))) != String(floor_key):
                errors.append("tower_floor_states key must match entry floor_id: %s" % String(floor_key))

    var raw_safe_state: Variant = data.get("safe_state", {})
    if not raw_safe_state is Dictionary:
        errors.append("safe_state must be a dictionary")
    elif not (raw_safe_state as Dictionary).is_empty():
        var safe_errors: PackedStringArray = SafeCheckpointState.validate_dictionary(raw_safe_state as Dictionary)
        for safe_error: String in safe_errors:
            errors.append("safe_state: %s" % safe_error)
        if safe_errors.is_empty():
            var safe_floor_id := int((raw_safe_state as Dictionary).get("floor_id", 0))
            if safe_floor_id > 0 and raw_floor_states is Dictionary:
                var floor_key := str(safe_floor_id)
                var referenced_floor: Variant = (raw_floor_states as Dictionary).get(floor_key, null)
                if not referenced_floor is Dictionary:
                    errors.append("safe_state references missing tower_floor_states[%s]" % floor_key)
                elif int((referenced_floor as Dictionary).get("floor_id", 0)) != safe_floor_id:
                    errors.append("safe_state floor_id must match referenced tower floor state")

    var raw_quest_progress: Variant = data.get("quest_progress", {})
    if not raw_quest_progress is Dictionary:
        errors.append("quest_progress must be a dictionary")
    else:
        var quest_errors: PackedStringArray = QuestProgressState.validate_dictionary(raw_quest_progress as Dictionary)
        for quest_error: String in quest_errors:
            errors.append("quest_progress: %s" % quest_error)

    var raw_flags: Variant = data.get("permanent_flags", {})
    if not raw_flags is Dictionary:
        errors.append("permanent_flags must be a dictionary")

    var raw_claims: Variant = data.get("claimed_transactions", {})
    if not raw_claims is Dictionary:
        errors.append("claimed_transactions must be a dictionary")
    else:
        var claim_errors: PackedStringArray = ClaimLedger.validate_dictionary(raw_claims as Dictionary)
        for claim_error: String in claim_errors:
            errors.append("claimed_transactions: %s" % claim_error)

    for ownership_error: String in NORMAL_ITEM_OWNERSHIP_VALIDATOR.validate_profile_dictionary(data):
        errors.append("normal_item_ownership: %s" % ownership_error)

    return errors
