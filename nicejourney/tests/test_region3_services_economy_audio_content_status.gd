extends SceneTree

const GAMEPLAY_SCENE: PackedScene = preload("res://src/app/gameplay.tscn")

var _failures: int = 0


func _init() -> void:
    call_deferred(&"_run")


func _run() -> void:
    var gameplay := GAMEPLAY_SCENE.instantiate() as GameplayRoot
    gameplay.region3_playtest_content = null # Explicit missing-production-content negative fixture.
    root.add_child(gameplay)
    await process_frame

    var status := gameplay.get_region3_services_economy_audio_content_status()
    _expect(not bool(status.get("complete", true)), "shipped Region 3 production content status remains incomplete while authoritative content is absent")

    var merchant := status.get("merchant", {}) as Dictionary
    var merchant_missing := merchant.get("missing_fields", PackedStringArray()) as PackedStringArray
    _expect(
        not bool(merchant.get("available", true))
        and merchant_missing.has("stock_manifest")
        and merchant_missing.has("restock_policy")
        and merchant_missing.has("item_category_catalog"),
        "General Merchant status reports exact production stock/restock/category blockers"
    )

    var blacksmith := status.get("blacksmith", {}) as Dictionary
    var blacksmith_missing := blacksmith.get("missing_fields", PackedStringArray()) as PackedStringArray
    _expect(
        not bool(blacksmith.get("available", true))
        and blacksmith_missing.has("compatible_definition_ids")
        and blacksmith_missing.has("material_costs")
        and blacksmith_missing.has("stat_changes")
        and blacksmith_missing.has("prerequisites"),
        "Blacksmith status reports exact recipe-content blockers instead of promoting test recipes"
    )

    var inn := status.get("inn", {}) as Dictionary
    _expect(
        not bool(inn.get("available", true))
        and StringName(inn.get("service_mode", &"")) == Region3RecoveryServiceDefinition.MODE_UNRESOLVED,
        "Inn production status remains unresolved until an exact production definition is assigned"
    )

    var clinic := status.get("clinic", {}) as Dictionary
    _expect(
        not bool(clinic.get("available", true))
        and StringName(clinic.get("expected_mode", &"")) == Region3RecoveryServiceDefinition.MODE_UNRESOLVED,
        "unassigned Clinic does not fabricate stock or recovery values"
    )

    var audio := status.get("audio", {}) as Dictionary
    var audio_missing := audio.get("missing_fields", PackedStringArray()) as PackedStringArray
    _expect(
        not bool(audio.get("available", true))
        and audio_missing.has("exploration_stream")
        and audio_missing.has("combat_stream")
        and audio_missing.has("boss_stream")
        and audio_missing.has("recovery_stream"),
        "music readiness reports all four missing production streams and keeps routing unassigned"
    )
    _expect(gameplay.music_routing_definition == null, "shipped GameplayRoot does not assign generated test tones as production music")

    gameplay.queue_free()
    await process_frame

    if _failures == 0:
        print("REGION 3 SERVICES ECONOMY AUDIO CONTENT STATUS TEST PASS")
    else:
        push_error("REGION 3 SERVICES ECONOMY AUDIO CONTENT STATUS TEST FAILURES: %d" % _failures)
    quit(_failures)


func _expect(condition: bool, message: String) -> void:
    if condition:
        print("PASS: %s" % message)
        return
    _failures += 1
    push_error("FAIL: %s" % message)
