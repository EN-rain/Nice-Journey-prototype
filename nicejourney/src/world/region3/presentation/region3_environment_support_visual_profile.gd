class_name Region3EnvironmentSupportVisualProfile
extends Resource

@export var profile_id: StringName = &"region3:environment_support:v02"
@export var town_props: Texture2D
@export var ground_road: Texture2D
@export var ruins_modules: Texture2D
@export var south_outskirts_support: Texture2D
@export var east_risk_zone_support: Texture2D
@export var town_props_source_evidence_accepted: bool = false
@export var ground_road_source_evidence_accepted: bool = false
@export var ruins_modules_source_evidence_accepted: bool = false
@export var south_outskirts_source_evidence_accepted: bool = false
@export var east_risk_zone_source_evidence_accepted: bool = false

func validate_profile() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(profile_id)):
        errors.append("profile_id must be a stable ID")
    if town_props == null:
        errors.append("town_props texture is required")
    if ground_road == null:
        errors.append("ground_road texture is required")
    if ruins_modules == null:
        errors.append("ruins_modules texture is required")
    if south_outskirts_support == null:
        errors.append("south_outskirts_support texture is required")
    if east_risk_zone_support == null:
        errors.append("east_risk_zone_support texture is required")
    return errors


func has_complete_source_evidence() -> bool:
    return (
        town_props_source_evidence_accepted
        and ground_road_source_evidence_accepted
        and ruins_modules_source_evidence_accepted
        and south_outskirts_source_evidence_accepted
        and east_risk_zone_source_evidence_accepted
        and validate_profile().is_empty()
    )
