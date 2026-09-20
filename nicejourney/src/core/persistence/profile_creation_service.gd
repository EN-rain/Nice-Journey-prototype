class_name ProfileCreationService
extends RefCounted

const STARTER_INVENTORY_INITIALIZATION_SERVICE: Script = preload("res://src/items/starter_inventory_initialization_service.gd")
const STORAGE_STATE_SCRIPT: Script = preload("res://src/items/storage_state.gd")

static func create_profile(slot_index: int, protagonist_name: String, class_id: String) -> ProfileSnapshot:
    if slot_index < 1 or slot_index > SaveService.SLOT_COUNT:
        return null
    var profile: ProfileSnapshot = ProfileSnapshot.new()
    profile.profile_id = "profile:slot_%d" % slot_index
    profile.protagonist_name = protagonist_name.strip_edges()
    profile.class_id = class_id.to_lower()
    profile.level = ProfileSnapshot.MIN_LEVEL
    profile.xp = 0
    profile.skill_points = 0
    profile.permanent_flags = {}
    if not SkillProgressionService.ensure_initialized(profile):
        return null
    if not STARTER_INVENTORY_INITIALIZATION_SERVICE.initialize_new_profile(profile):
        return null
    var storage := STORAGE_STATE_SCRIPT.new() as StorageState
    if storage == null or not StorageState.validate_dictionary(storage.to_dictionary()).is_empty():
        return null
    profile.storage_state = storage.to_dictionary()
    if not ProfileSnapshot.validate_dictionary(profile.to_dictionary()).is_empty():
        return null
    return profile
