class_name TowerGenerationIdentityFactory
extends RefCounted

const GENERATOR_VERSION: StringName = &"tower_generator:v01"
const MODULE_CONTENT_VERSION: StringName = &"tower_modules:v01"
const ENCOUNTER_CONFIG_ID: StringName = &"encounters:prototype_v01"

static func generation_seed(profile: ProfileSnapshot, floor_id: int) -> int:
    if profile == null or not StableId.is_valid(profile.profile_id) or floor_id < 1 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return -1
    var bytes := ("%s|tower-floor|%d" % [profile.profile_id, floor_id]).to_utf8_buffer()
    var hash_value: int = 2166136261
    for byte_value: int in bytes:
        hash_value = (hash_value ^ byte_value) * 16777619
        hash_value &= 0x7fffffff
    return hash_value

static func quest_world_flags_signature(profile: ProfileSnapshot, floor_id: int) -> StringName:
    if profile == null or floor_id < 1 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return &""
    var parts: PackedStringArray = PackedStringArray()
    var flag_keys: Array = profile.permanent_flags.keys()
    flag_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
    for raw_key: Variant in flag_keys:
        parts.append("f:%s=%s" % [String(raw_key), str(profile.permanent_flags[raw_key])])
    var quest_keys: Array = profile.quest_progress.keys()
    quest_keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
    for raw_key: Variant in quest_keys:
        var raw_entry: Variant = profile.quest_progress[raw_key]
        if not raw_entry is Dictionary:
            continue
        var entry := raw_entry as Dictionary
        parts.append("q:%s:%s:%s" % [
            String(raw_key),
            String(entry.get("state", &"")),
            String(entry.get("stage_id", &"")),
        ])
    var digest := ("floor=%d|%s" % [floor_id, "|".join(parts)]).sha256_text()
    return StringName("quest_flags:%s" % digest.substr(0, 24))

static func instance_id(profile: ProfileSnapshot, floor_id: int) -> StringName:
    if profile == null or not StableId.is_valid(profile.profile_id) or floor_id < 1 or floor_id > PrototypeTowerFloorCatalog.FLOOR_COUNT:
        return &""
    return StringName("floor_instance:%s:floor_%d" % [profile.profile_id, floor_id])

static func build_tuple(profile: ProfileSnapshot, floor_id: int) -> Dictionary:
    var seed := generation_seed(profile, floor_id)
    var signature := quest_world_flags_signature(profile, floor_id)
    var instance := instance_id(profile, floor_id)
    if seed < 0 or signature == &"" or instance == &"":
        return {}
    return {
        "generation_seed": seed,
        "generator_version": GENERATOR_VERSION,
        "module_content_version": MODULE_CONTENT_VERSION,
        "encounter_config_id": ENCOUNTER_CONFIG_ID,
        "quest_world_flags_signature": signature,
        "instance_id": instance,
    }
