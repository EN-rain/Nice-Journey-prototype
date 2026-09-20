extends SceneTree

const WORLD: Region3WorldLayoutDefinition = preload("res://src/world/region3/layout/region3_world_layout_definition.tres")
const TOWN_SCENE: PackedScene = preload("res://src/world/region3/layout/region3_authored_town_layout.tscn")
const STORY: NpcPlacementAuthoring = preload("res://src/world/npc/presentation/profiles/story_lore_placement_proposal.tres")
const VARIABLE: NpcPlacementAuthoring = preload("res://src/world/npc/presentation/profiles/variable_quest_placement_proposal.tres")

var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _expect(condition: bool, message: String) -> void:
    if not condition:
        failures += 1
        push_error(message)

func _run() -> void:
    var town := TOWN_SCENE.instantiate() as Region3AuthoredTownLayout
    root.add_child(town)
    await process_frame
    _expect(town.validate_layout().is_empty(), "unchanged authored town is valid")
    _expect(WORLD.get_quest_anchor(&"R3-MAIN-START").structure_id == &"r3:functional:02", "source-based Quest Hall candidate")
    var coordinator := town.get_node_or_null("QuestHall/ServiceInteraction/NpcVisualPresenter") as NpcVisualPresenter
    _expect(coordinator != null and coordinator.profile.role_id == &"npc:tower_quest_coordinator", "Quest Hall approach is already coordinator-owned")
    for placement: NpcPlacementAuthoring in [STORY, VARIABLE]:
        _expect(placement != null, "proposal resource loads")
        if placement == null:
            continue
        _expect(placement.validate_proposal(WORLD, town).is_empty(), "proposal references only existing semantic anchors")
        var no_art := placement.duplicate() as NpcPlacementAuthoring
        no_art.npc_visual_profile = placement.npc_visual_profile.duplicate() as NpcVisualProfile
        no_art.npc_visual_profile.texture = null
        _expect(_has_reason(no_art.validate_proposal(WORLD, town), "actual accepted static"), "role and frame metadata alone cannot certify accepted art")
        town.structure_count_expected = 19
        _expect(_has_reason(placement.validate_proposal(WORLD, town), "20-structure town"), "world anchor IDs cannot certify an invalid authored town")
        town.structure_count_expected = 20
        var blocked := placement.validate_live_placement(WORLD, town)
        _expect(not blocked.is_empty(), "proposal is not falsely called a live NPC")
        _expect(_has_reason(blocked, "independent developer-approved"), "independent actor placement approval missing")
        _expect(_has_reason(blocked, "separate scene-owned actor path"), "dedicated live actor is missing")
        _expect(_has_reason(blocked, "one approved current quest anchor"), "no chosen current quest anchor can be inferred from proposal")
        var pretend := placement.duplicate(true) as NpcPlacementAuthoring
        pretend.approved_placement = true
        pretend.placement_authority_ref = "unsupported claimed approval"
        pretend.approved_actor_id = &"npc:unverified"
        pretend.selected_quest_anchor_id = placement.proposed_quest_anchor_ids[0]
        pretend.unique_actor_node_path = NodePath("QuestHall/ServiceInteraction/NpcVisualPresenter")
        var still_blocked := pretend.validate_live_placement(WORLD, town)
        _expect(_has_reason(still_blocked, "quest-marker geometry"), "false approval cannot synthesize exact actor tile")
        _expect(_has_reason(still_blocked, "distinct existing live visual consumer"), "cannot reuse already occupied coordinator presenter")
        if placement.npc_visual_profile.role_id == &"npc:variable_quest":
            _expect(_has_reason(blocked, "current approved quest ID"), "variable actor must bind actual current quest")
    town.queue_free()
    await process_frame
    print("NPC UNPLACED ROLE PROPOSALS FAILURES: ", failures)
    quit(0 if failures == 0 else 1)

func _has_reason(errors: PackedStringArray, text: String) -> bool:
    for error: String in errors:
        if error.contains(text):
            return true
    return false
