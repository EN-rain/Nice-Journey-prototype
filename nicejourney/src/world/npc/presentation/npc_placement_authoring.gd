@tool
class_name NpcPlacementAuthoring
extends Resource

# PROPOSAL ONLY: choosing an existing region/structure is not permission to
# spawn an actor, reuse an occupied service approach, or assign a quest.
@export var npc_visual_profile: NpcVisualProfile
@export var proposed_quest_anchor_ids: Array[StringName] = []
@export var proposed_structure_id: StringName = &""

# Final integration requires independent owner approval and an actually
# authored unique actor + quest binding; do not infer these from geography.
@export var approved_placement: bool = false
@export var placement_authority_ref: String = ""
@export var approved_actor_id: StringName = &""
@export var approved_quest_id: StringName = &""
@export var selected_quest_anchor_id: StringName = &""
@export var unique_actor_node_path: NodePath = NodePath("")

const ROLE_STORY: StringName = &"npc:story_lore"
const ROLE_VARIABLE: StringName = &"npc:variable_quest"

func validate_proposal(world: Region3WorldLayoutDefinition, town: Region3AuthoredTownLayout) -> PackedStringArray:
    var errors := PackedStringArray()
    if npc_visual_profile == null or not npc_visual_profile.validate_presentation().is_empty():
        errors.append("accepted static 32px NPC visual profile required")
        return errors
    if npc_visual_profile.texture == null or npc_visual_profile.texture.get_size() != Vector2(32, 32) or npc_visual_profile.animation_library != null:
        errors.append("proposal requires one actual accepted static 32px NPC identity frame")
    if npc_visual_profile.role_id not in [ROLE_STORY, ROLE_VARIABLE]:
        errors.append("placement role must be one of the two unplaced recurring NPC identities")
    if world == null or town == null:
        errors.append("real authored Region 3 world and 20-structure town required")
        return errors
    if not town.validate_layout().is_empty() or not world.validate_definition(_structure_ids(town)).is_empty():
        errors.append("real authored Region 3 world and 20-structure town required")
        return errors
    if proposed_quest_anchor_ids.is_empty():
        errors.append("at least one existing proposed quest marker is required")
    var seen: Dictionary = {}
    for id: StringName in proposed_quest_anchor_ids:
        if seen.has(id) or world.get_quest_anchor(id) == null:
            errors.append("missing/duplicate proposal anchor: %s" % String(id))
        seen[id] = true
    if proposed_structure_id != &"":
        var structure := _get_structure(town, proposed_structure_id)
        if structure == null or structure.category != Region3TownStructureManifestValidator.CATEGORY_FUNCTIONAL:
            errors.append("proposed structure must be an existing functional town anchor")
        elif npc_visual_profile.role_id == ROLE_STORY and structure.role_id != Region3TownStructureManifestValidator.ROLE_QUEST_HALL:
            errors.append("story/lore proposal is permitted only as Quest Hall CANDIDATE")
    if npc_visual_profile.role_id == ROLE_STORY:
        if proposed_structure_id != &"r3:functional:02" or not proposed_quest_anchor_ids.has(&"R3-MAIN-START"):
            errors.append("story/lore may be proposed for Quest Hall R3-MAIN-START only")
    if npc_visual_profile.role_id == ROLE_VARIABLE and proposed_structure_id != &"":
        errors.append("variable quest role must not adopt any structure without its current quest's declared actor anchor")
    return errors

func validate_live_placement(
    world: Region3WorldLayoutDefinition, town: Region3AuthoredTownLayout,
    already_bound_actor_ids: Dictionary = {}
) -> PackedStringArray:
    var errors := validate_proposal(world, town)
    if not approved_placement or placement_authority_ref.strip_edges().is_empty():
        errors.append("independent developer-approved actor/quest placement authority missing")
    if not StableId.is_valid(String(approved_actor_id)) or already_bound_actor_ids.has(approved_actor_id):
        errors.append("unique approved actor ID required; no duplicate of an existing actor")
    if selected_quest_anchor_id == &"" or not proposed_quest_anchor_ids.has(selected_quest_anchor_id):
        errors.append("one approved current quest anchor must be selected from valid proposals")
    elif world != null:
        var anchor := world.get_quest_anchor(selected_quest_anchor_id)
        if anchor == null or not anchor.exact_tile_authored:
            errors.append("quest-marker geometry is not explicitly authored; no invented exact NPC tile")
    if npc_visual_profile != null and npc_visual_profile.role_id == ROLE_VARIABLE and not StableId.is_valid(String(approved_quest_id)):
        errors.append("variable NPC requires current approved quest ID; zone marker alone is insufficient")
    if unique_actor_node_path.is_empty():
        errors.append("separate scene-owned actor path missing; do not reuse the coordinator presenter")
    elif town != null:
        var actor := town.get_node_or_null(unique_actor_node_path)
        if not actor is NpcVisualPresenter or (actor as NpcVisualPresenter).profile != npc_visual_profile:
            errors.append("distinct existing live visual consumer of this profile missing")
    return errors

func _structure_ids(town: Region3AuthoredTownLayout) -> Dictionary:
    var ids := {}
    for child: Node in town.get_children():
        if child is Region3TownStructureAnchor:
            ids[(child as Region3TownStructureAnchor).structure_id] = true
    return ids

func _get_structure(town: Region3AuthoredTownLayout, id: StringName) -> Region3TownStructureAnchor:
    for child: Node in town.get_children():
        if child is Region3TownStructureAnchor and (child as Region3TownStructureAnchor).structure_id == id:
            return child as Region3TownStructureAnchor
    return null
