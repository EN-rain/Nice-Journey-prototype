class_name QuestCatalog
extends RefCounted

const FLOOR_PRIMARY_IDS: Array[StringName] = [
    &"primary_floor_1", &"primary_floor_2", &"primary_floor_3", &"primary_floor_4", &"primary_floor_5",
    &"primary_floor_6", &"primary_floor_7", &"primary_floor_8", &"primary_floor_9", &"primary_floor_10",
]
const SIDE_IDS: Array[StringName] = [
    &"side_region3_escort",
    &"side_region3_annihilation",
    &"side_region3_defense",
    &"side_tower_floor4_escort",
    &"side_tower_floor7_annihilation",
]
const REGION3_QUEST_HALL_ANCHOR_ID: StringName = &"r3:functional:02"

const FLOOR_PRIMARY_FAMILIES: Array[StringName] = [
    QuestDefinition.FAMILY_ANNIHILATION,
    QuestDefinition.FAMILY_ESCORT,
    QuestDefinition.FAMILY_TOWER_DEFENSE,
    QuestDefinition.FAMILY_ANNIHILATION,
    QuestDefinition.FAMILY_ANNIHILATION,
    QuestDefinition.FAMILY_ESCORT,
    QuestDefinition.FAMILY_TOWER_DEFENSE,
    QuestDefinition.FAMILY_ESCORT,
    QuestDefinition.FAMILY_TOWER_DEFENSE,
    QuestDefinition.FAMILY_ANNIHILATION,
]


static func all_definitions() -> Array[QuestDefinition]:
    var result: Array[QuestDefinition] = []
    for index: int in 10:
        var floor_id: int = index + 1
        var stages: Array[StringName] = [&"floor_objective"]
        var includes_preparation: bool = floor_id == 1
        var grants_sigil: bool = floor_id == 1
        var unlocks_floor: int = 1 if floor_id == 1 else 0
        if floor_id == 1:
            stages = [&"region3_preparation", &"tower_access_commit", &"floor_objective"]
        var definition := _make(
            FLOOR_PRIMARY_IDS[index],
            QuestDefinition.KIND_PRIMARY,
            FLOOR_PRIMARY_FAMILIES[index],
            floor_id,
            StringName("tower:floor_%d" % floor_id),
            stages,
            includes_preparation,
            grants_sigil,
            unlocks_floor,
            true
        )
        # §24.12 / §25 bind quest acceptance and turn-in to the Quest Hall;
        # the authored Region 3 layout binds that functional structure to
        # r3:functional:02. This is authoritative for the ten primary quests,
        # while the remaining per-floor production policy stays undeclared.
        definition.acceptance_anchor_declared = true
        definition.acceptance_anchor_id = REGION3_QUEST_HALL_ANCHOR_ID
        definition.turn_in_anchor_declared = true
        definition.turn_in_anchor_id = REGION3_QUEST_HALL_ANCHOR_ID
        if floor_id >= 2:
            definition = PrimaryQuestProductionV01.apply(definition)
        result.append(definition)

    result.append(_make(&"side_region3_escort", QuestDefinition.KIND_SIDE, QuestDefinition.FAMILY_ESCORT, 0, &"region3:south_outskirts", [&"escort_objective"], false, false, 0, true))
    result.append(_make(&"side_region3_annihilation", QuestDefinition.KIND_SIDE, QuestDefinition.FAMILY_ANNIHILATION, 0, &"region3:west_road", [&"annihilation_objective"], false, false, 0, true))
    result.append(_make(&"side_region3_defense", QuestDefinition.KIND_SIDE, QuestDefinition.FAMILY_TOWER_DEFENSE, 0, &"region3:north_quest_site", [&"defense_objective"], false, false, 0, true))
    # §53.1 reserves two tower-side sockets but leaves their exact family reversible.
    # These family bindings are explicit playtest placeholders, not narrative canon.
    result.append(_make(&"side_tower_floor4_escort", QuestDefinition.KIND_SIDE, QuestDefinition.FAMILY_ESCORT, 4, &"tower:floor_4", [&"escort_objective"], false, false, 0, true))
    result.append(_make(&"side_tower_floor7_annihilation", QuestDefinition.KIND_SIDE, QuestDefinition.FAMILY_ANNIHILATION, 7, &"tower:floor_7", [&"annihilation_objective"], false, false, 0, true))
    return result


static func get_definition(quest_id: StringName) -> QuestDefinition:
    for definition: QuestDefinition in all_definitions():
        if definition.quest_id == quest_id:
            return definition
    return null


static func validate_catalog() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    var definitions: Array[QuestDefinition] = all_definitions()
    if definitions.size() != 15:
        errors.append("quest manifest must contain exactly 15 definitions")

    var seen_ids: Dictionary = {}
    var primary_floors: Dictionary = {}
    var primary_count: int = 0
    var side_count: int = 0
    var preparation_count: int = 0
    var sigil_grant_count: int = 0
    var floor1_unlock_count: int = 0

    for definition: QuestDefinition in definitions:
        for definition_error: String in definition.validate_definition():
            errors.append("%s: %s" % [String(definition.quest_id), definition_error])
        if seen_ids.has(definition.quest_id):
            errors.append("duplicate quest_id: %s" % String(definition.quest_id))
        seen_ids[definition.quest_id] = true
        if definition.kind == QuestDefinition.KIND_PRIMARY:
            primary_count += 1
            if primary_floors.has(definition.floor_id):
                errors.append("duplicate primary floor binding: %d" % definition.floor_id)
            primary_floors[definition.floor_id] = true
        else:
            side_count += 1
        if definition.includes_region3_preparation:
            preparation_count += 1
        if definition.grants_tower_sigil:
            sigil_grant_count += 1
        if definition.unlocks_floor_id == 1:
            floor1_unlock_count += 1

    if primary_count != 10 or side_count != 5:
        errors.append("quest manifest must contain exactly ten primary and five side definitions")
    for floor_id: int in range(1, 11):
        if not primary_floors.has(floor_id):
            errors.append("missing primary definition for floor %d" % floor_id)
    for required_id: StringName in FLOOR_PRIMARY_IDS + SIDE_IDS:
        if not seen_ids.has(required_id):
            errors.append("missing required quest_id: %s" % String(required_id))

    var floor1: QuestDefinition = get_definition(&"primary_floor_1")
    if floor1 == null:
        errors.append("primary_floor_1 is required")
    else:
        var expected_stages: Array[StringName] = [&"region3_preparation", &"tower_access_commit", &"floor_objective"]
        if floor1.stage_ids != expected_stages:
            errors.append("Floor 1 primary must package Region 3 preparation, access commit and Floor 1 objective in one definition")
        if floor1.family != QuestDefinition.FAMILY_ANNIHILATION:
            errors.append("Floor 1 primary family must follow the approved Annihilation allocation")
        if not floor1.grants_tower_sigil or floor1.unlocks_floor_id != 1:
            errors.append("Floor 1 primary must own the initial Sigil + Floor 1 unlock chain")
    if preparation_count != 1 or sigil_grant_count != 1 or floor1_unlock_count != 1:
        errors.append("regional preparation/Sigil/Floor 1 unlock must occur exactly once in the 15-definition manifest")
    return errors


static func validate_authored_contracts() -> PackedStringArray:
    var errors: PackedStringArray = PackedStringArray()
    for definition: QuestDefinition in all_definitions():
        for contract_error: String in definition.validate_production_contract():
            errors.append("%s: %s" % [String(definition.quest_id), contract_error])
    return errors


static func primary_production_status(floor_id: int) -> Dictionary:
    if floor_id < 1 or floor_id > FLOOR_PRIMARY_IDS.size():
        return {
            "floor_id": floor_id,
            "quest_id": &"",
            "production_ready": false,
            "playtest_placeholder": false,
            "unauthored_contract_fields": PackedStringArray(),
            "contract_errors": PackedStringArray(["invalid primary floor id"]),
            "objective_authority": PrimaryQuestProductionAuthority.rejected_status(&"invalid_primary_floor_id"),
            "objective_missing_authoritative_fields": PackedStringArray(),
            "objective_external_runtime_missing_authoritative_fields": PackedStringArray(),
        }
    var definition := get_definition(FLOOR_PRIMARY_IDS[floor_id - 1])
    if definition == null:
        return {
            "floor_id": floor_id,
            "quest_id": FLOOR_PRIMARY_IDS[floor_id - 1],
            "production_ready": false,
            "playtest_placeholder": false,
            "unauthored_contract_fields": PackedStringArray(),
            "contract_errors": PackedStringArray(["primary quest definition missing"]),
            "objective_authority": PrimaryQuestProductionAuthority.rejected_status(&"definition_missing"),
            "objective_missing_authoritative_fields": PackedStringArray(),
            "objective_external_runtime_missing_authoritative_fields": PackedStringArray(),
        }
    var errors := definition.validate_production_contract()
    var objective_authority := PrimaryQuestProductionAuthority.readiness(definition)
    var objective_missing := (
        objective_authority.get("quest_missing_authoritative_fields", PackedStringArray()) as PackedStringArray
    )
    var external_missing := (
        objective_authority.get("external_runtime_missing_authoritative_fields", PackedStringArray()) as PackedStringArray
    )
    return {
        "floor_id": floor_id,
        "quest_id": definition.quest_id,
        "production_ready": errors.is_empty() and bool(objective_authority.get("production_ready", false)),
        "playtest_placeholder": definition.playtest_placeholder,
        "unauthored_contract_fields": definition.unauthored_contract_fields(),
        "contract_errors": errors.duplicate(),
        "objective_authority": objective_authority.duplicate(true),
        "objective_missing_authoritative_fields": objective_missing.duplicate(),
        "objective_external_runtime_missing_authoritative_fields": external_missing.duplicate(),
    }


static func _make(
    quest_id: StringName,
    kind: StringName,
    family: StringName,
    floor_id: int,
    scope_id: StringName,
    stage_ids: Array[StringName],
    includes_region3_preparation: bool,
    grants_tower_sigil: bool,
    unlocks_floor_id: int,
    playtest_placeholder: bool
) -> QuestDefinition:
    var definition: QuestDefinition = QuestDefinition.new()
    definition.quest_id = quest_id
    definition.kind = kind
    definition.family = family
    definition.floor_id = floor_id
    definition.scope_id = scope_id
    definition.stage_ids = stage_ids.duplicate()
    definition.includes_region3_preparation = includes_region3_preparation
    definition.grants_tower_sigil = grants_tower_sigil
    definition.unlocks_floor_id = unlocks_floor_id
    definition.playtest_placeholder = playtest_placeholder
    return definition
