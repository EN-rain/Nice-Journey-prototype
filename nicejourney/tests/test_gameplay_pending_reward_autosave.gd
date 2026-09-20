extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")
const SAVE_ROOT := "user://tests/gameplay_pending_reward_autosave"

var _failures := 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var save_service := SaveService.new(SAVE_ROOT)
    save_service.delete_slot(1)

    var profile := ProfileCreationService.create_profile(1, "Reward Autosave", "melee")
    _expect(profile != null, "major-reward autosave fixture creates a profile")
    if profile == null:
        quit(1)
        return

    var economy := EconomyState.new()
    if not profile.economy_state.is_empty():
        _expect(economy.load_dictionary(profile.economy_state).is_empty(), "fixture loads existing persisted economy state")
    _expect(
        economy.add_pending_reward(
            &"claim:major_reward_autosave",
            &"reward_source:major_reward_autosave",
            [{
                "item_instance_id": &"item:major_reward_autosave",
                "definition_id": &"itemdef:major_reward_autosave",
                "stackable": true,
                "quantity": 2,
            }]
        ),
        "fixture authors one valid pending normal reward"
    )
    profile.economy_state = economy.to_dictionary()
    _expect(save_service.save_profile(1, profile) == OK, "fixture persists pending reward before gameplay")

    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.set_profile(profile)
    _expect(gameplay.set_save_context(save_service, 1), "GameplayRoot accepts autosave slot context")
    root.add_child(gameplay)
    await process_frame
    _expect(gameplay.ensure_starting_world() and gameplay.is_region3_active(), "fixture enters the authored Region 3 hub")
    var sequence_before := int(profile.safe_state.get("snapshot_sequence", 0))

    var claim := gameplay.request_pending_reward_claim(&"claim:major_reward_autosave")
    var autosave := claim.get("autosave_status", {}) as Dictionary
    _expect(bool(claim.get("accepted", false)), "pending major reward claim commits live profile mutation")
    _expect(
        StringName(String(autosave.get("request_kind", &""))) == SaveRequestCoordinator.REQUEST_AUTOSAVE
        and StringName(String(autosave.get("state", &""))) == SaveRequestCoordinator.STATE_SUCCEEDED,
        "accepted major reward immediately uses the shared autosave trigger"
    )
    _expect(
        bool(claim.get("durable", false))
        and StringName(String(claim.get("durability_boundary", &""))) == &"autosave_committed",
        "major reward reports durable only after autosave succeeds"
    )
    _expect(
        String(profile.safe_state.get("snapshot_id", "")).begins_with("safe:autosave_region3_")
        and int(profile.safe_state.get("floor_id", -1)) == 0
        and int(profile.safe_state.get("snapshot_sequence", 0)) > sequence_before,
        "major reward autosave advances a coherent Region 3 safe snapshot"
    )

    var durable := save_service.load_profile(1)
    _expect(durable != null, "major reward autosave reloads durably")
    if durable != null:
        var durable_inventory := InventoryState.new()
        var durable_economy := EconomyState.new()
        _expect(durable_inventory.load_dictionary(durable.item_state).is_empty(), "durable reward inventory reloads")
        _expect(durable_economy.load_dictionary(durable.economy_state).is_empty(), "durable reward economy reloads")
        var reward_item := durable_inventory.get_normal_slot(&"item:major_reward_autosave")
        _expect(
            not reward_item.is_empty()
            and StringName(String(reward_item.get("definition_id", &""))) == &"itemdef:major_reward_autosave"
            and int(reward_item.get("quantity", 0)) == 2,
            "autosave persists exact claimed item identity and quantity"
        )
        _expect(
            durable_economy.get_pending_reward(&"claim:major_reward_autosave").is_empty(),
            "autosave persists consumption of the pending reward source"
        )
        _expect(
            durable.claimed_transactions.has("transaction:pending_reward_claim:claim:major_reward_autosave"),
            "autosave persists the duplicate-resistant claim transaction"
        )

    gameplay.queue_free()
    await process_frame
    save_service.delete_slot(1)

    if _failures == 0:
        print("GAMEPLAY PENDING REWARD AUTOSAVE TEST PASS")
    else:
        push_error("GAMEPLAY PENDING REWARD AUTOSAVE TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
