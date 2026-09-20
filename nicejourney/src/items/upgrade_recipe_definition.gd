class_name UpgradeRecipeDefinition
extends Resource

@export var recipe_id: StringName = &""
@export var compatible_definition_ids: Array[StringName] = []
@export var compatible_rarities: Array[StringName] = []
@export_range(0, 99, 1) var source_rank: int = 0
@export var source_rank_declared: bool = false
@export_range(1, 99, 1) var result_rank: int = 1
@export var result_rank_declared: bool = false
@export_range(1, 99, 1) var maximum_rank: int = 1
@export var maximum_rank_declared: bool = false
@export_range(0, 2147483647, 1) var gold_cost: int = 0
@export var gold_cost_declared: bool = false
@export var material_costs: Dictionary = {}
@export var stat_changes: Dictionary = {}
@export var prerequisite_condition_ids: Array[StringName] = []
@export var prerequisites_declared: bool = false

func validate_definition() -> PackedStringArray:
    var errors := PackedStringArray()
    if not StableId.is_valid(String(recipe_id)):
        errors.append("recipe_id must be a stable ID")
    if compatible_definition_ids.is_empty():
        errors.append("compatible_definition_ids must not be empty")
    else:
        var seen_definitions: Dictionary = {}
        for definition_id: StringName in compatible_definition_ids:
            if not StableId.is_valid(String(definition_id)):
                errors.append("compatible_definition_ids require stable IDs")
            if seen_definitions.has(definition_id):
                errors.append("compatible_definition_ids must be unique")
            seen_definitions[definition_id] = true
    if compatible_rarities.is_empty():
        errors.append("compatible_rarities must not be empty")
    else:
        var seen_rarities: Dictionary = {}
        for rarity: StringName in compatible_rarities:
            if not InventoryState.RARITY_AFFIX_TARGETS.has(String(rarity)):
                errors.append("compatible_rarities contains unsupported rarity %s" % String(rarity))
            if seen_rarities.has(rarity):
                errors.append("compatible_rarities must be unique")
            seen_rarities[rarity] = true
    if source_rank < 0 or result_rank != source_rank + 1:
        errors.append("result_rank must be exactly source_rank + 1")
    if maximum_rank < result_rank:
        errors.append("maximum_rank must be at least result_rank")
    if gold_cost < 0:
        errors.append("gold_cost cannot be negative")
    if material_costs.is_empty():
        errors.append("material_costs must declare at least one upgrade material")
    else:
        for raw_id: Variant in material_costs.keys():
            var material_id := String(raw_id)
            if not StableId.is_valid(material_id):
                errors.append("material_costs keys require stable definition IDs")
            var raw_count: Variant = material_costs[raw_id]
            if typeof(raw_count) != TYPE_INT or int(raw_count) <= 0:
                errors.append("material_costs values must be positive integers")
    if stat_changes.is_empty():
        errors.append("stat_changes must declare the exact deterministic upgrade delta")
    else:
        for raw_stat: Variant in stat_changes.keys():
            var stat_id := String(raw_stat)
            if not StableId.is_valid(stat_id):
                errors.append("stat_changes keys require stable stat IDs")
            var raw_delta: Variant = stat_changes[raw_stat]
            if not (typeof(raw_delta) == TYPE_INT or typeof(raw_delta) == TYPE_FLOAT) or not is_finite(float(raw_delta)):
                errors.append("stat_changes values must be finite numbers")
    var seen_prerequisites: Dictionary = {}
    for condition_id: StringName in prerequisite_condition_ids:
        if not StableId.is_valid(String(condition_id)):
            errors.append("prerequisite_condition_ids require stable IDs")
        elif seen_prerequisites.has(condition_id):
            errors.append("prerequisite_condition_ids must be unique")
        seen_prerequisites[condition_id] = true
    return errors


func validate_authored_definition() -> PackedStringArray:
    var errors := validate_definition()
    if not source_rank_declared:
        errors.append("source_rank must be explicitly authored")
    if not result_rank_declared:
        errors.append("result_rank must be explicitly authored")
    if not maximum_rank_declared:
        errors.append("maximum_rank must be explicitly authored")
    if not gold_cost_declared:
        errors.append("gold_cost must be explicitly authored")
    if not prerequisites_declared:
        errors.append("prerequisites must be explicitly authored, including an explicit empty set")
    return errors


func unauthored_fields() -> PackedStringArray:
    var fields := PackedStringArray()
    if compatible_definition_ids.is_empty():
        fields.append("compatible_definition_ids")
    if compatible_rarities.is_empty():
        fields.append("compatible_rarities")
    if not source_rank_declared:
        fields.append("source_rank")
    if not result_rank_declared:
        fields.append("result_rank")
    if not maximum_rank_declared:
        fields.append("maximum_rank")
    if not gold_cost_declared:
        fields.append("gold_cost")
    if material_costs.is_empty():
        fields.append("material_costs")
    if stat_changes.is_empty():
        fields.append("stat_changes")
    if not prerequisites_declared:
        fields.append("prerequisites")
    return fields


func is_compatible(definition_id: StringName, rarity: StringName, rank: int) -> bool:
    return (
        validate_definition().is_empty()
        and compatible_definition_ids.has(definition_id)
        and compatible_rarities.has(rarity)
        and rank == source_rank
        and rank < maximum_rank
    )

func preview(definition_id: StringName, rarity: StringName, rank: int) -> Dictionary:
    return {
        "compatible": is_compatible(definition_id, rarity, rank),
        "recipe_id": recipe_id,
        "definition_id": definition_id,
        "rarity": rarity,
        "before_rank": rank,
        "after_rank": result_rank,
        "maximum_rank": maximum_rank,
        "gold_cost": gold_cost,
        "material_costs": material_costs.duplicate(true),
        "stat_changes": stat_changes.duplicate(true),
    }
