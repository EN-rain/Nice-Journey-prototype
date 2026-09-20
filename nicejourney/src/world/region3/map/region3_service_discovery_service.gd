class_name Region3ServiceDiscoveryService
extends RefCounted

const FLAG_PREFIX: String = "region3_service_discovered:"
const STRUCTURE_ID_BY_ROLE: Dictionary = {
    &"central_tower": &"r3:functional:01",
    &"quest_hall": &"r3:functional:02",
    &"blacksmith": &"r3:functional:03",
    &"general_merchant": &"r3:functional:04",
    &"inn_rest_house": &"r3:functional:05",
    &"storage_house": &"r3:functional:06",
    &"training_hall": &"r3:functional:07",
    &"clinic_apothecary": &"r3:functional:08",
}


static func mark_discovered(profile: ProfileSnapshot, structure_id: StringName, role_id: StringName) -> Dictionary:
    if profile == null or not StableId.is_valid(String(structure_id)) or not StableId.is_valid(String(role_id)):
        return _result(false, &"invalid_context", structure_id, role_id, false)
    if not Region3TownStructureManifestValidator.REQUIRED_FUNCTIONAL_ROLES.has(role_id):
        return _result(false, &"unsupported_role", structure_id, role_id, false)
    var expected_structure_id := _structure_id_for_role(role_id)
    if expected_structure_id == &"" or expected_structure_id != structure_id:
        return _result(false, &"structure_role_mismatch", structure_id, role_id, false)
    var flag_id := discovery_flag_id(structure_id)
    var already_discovered := bool(profile.permanent_flags.get(String(flag_id), false))
    if already_discovered:
        return _result(true, &"", structure_id, role_id, false)
    profile.permanent_flags[String(flag_id)] = true
    return _result(true, &"", structure_id, role_id, true)


static func is_discovered(profile: ProfileSnapshot, structure_id: StringName) -> bool:
    if profile == null or not StableId.is_valid(String(structure_id)):
        return false
    return bool(profile.permanent_flags.get(String(discovery_flag_id(structure_id)), false))


static func discovery_flag_id(structure_id: StringName) -> StringName:
    if not StableId.is_valid(String(structure_id)):
        return &""
    return StringName("%s%s" % [FLAG_PREFIX, String(structure_id)])


static func _structure_id_for_role(role_id: StringName) -> StringName:
    return StringName(String(STRUCTURE_ID_BY_ROLE.get(role_id, &"")))


static func _result(
    accepted: bool,
    reason_id: StringName,
    structure_id: StringName,
    role_id: StringName,
    mutated: bool
) -> Dictionary:
    return {
        "accepted": accepted,
        "reason_id": reason_id,
        "structure_id": structure_id,
        "role_id": role_id,
        "flag_id": discovery_flag_id(structure_id),
        "mutated": mutated,
        "durable": false,
    }
