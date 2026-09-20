"""Accept seven already-live source-faithful NEAREST player states, no image edits.

Only the source/runtime evidence gate is closed. Ten V03/V04 R2 states remain
unbound candidates. Real gloved-hand and aesthetic approval are not invented.
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

from reconcile_current_ui_icon_inventory import corrected_counts, replace_object
from reconcile_region3_decorative_11_12_acceptance import digest


PROJECT = Path(__file__).resolve().parents[2]
INVENTORIES = (PROJECT.parent / "Nice_Journey_Asset_Handoff_Manifest.json",
               PROJECT / "docs/art/ASSET_PRODUCTION_MANIFEST.json")
NEAREST = PROJECT / "docs/evidence/art/nearest_candidates/player_main_character_v03_nearest_derivation_manifest.json"
CAPTURES = PROJECT / "assets/art/player/animations/review_clean_v03_engine/clean_v03_real_renderer_evidence.json"
LIBRARY = PROJECT / "src/player/presentation/player_body_animation_library.tres"
SCENE = PROJECT / "src/player/player.tscn"
STATES = ("idle", "walk", "run", "dash", "climb", "pickup", "sleep")


def validate_source_renderer() -> tuple[dict, dict]:
    manifest = json.loads(NEAREST.read_text(encoding="utf-8"))
    captures = json.loads(CAPTURES.read_text(encoding="utf-8"))
    if captures["page_count"] != len(captures["pages"]):
        raise ValueError("incorrect clean live player capture count")
    if captures["page_count"] != 84 or captures["display"] != "Windows" or captures["rendering_method"] != "gl_compatibility":
        raise ValueError("actual GL Compatibility native render is required")
    if digest(LIBRARY) != captures["production_library_sha256"] or "player_body_animation_library.tres" not in SCENE.read_text(encoding="utf-8"):
        raise ValueError("live player animation library changed")
    actual_pages = {(p["state"], p["class"], p["zoom"], p["equipped"]) for p in captures["pages"]}
    required = {(name, cls, zoom, equipped) for name in STATES for cls in ("melee", "ranged", "mage") for zoom in (1, 2) for equipped in (False, True)}
    if actual_pages != required:
        raise ValueError("missing class/facing/scaled renderer evidence")
    for name in STATES:
        record = manifest["animations"][name]
        production = PROJECT / record["output"].removeprefix("res://")
        source_file = record["source_file"]
        source = PROJECT / "assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources" / source_file
        if digest(production) != record["output_sha256"] or digest(source) != manifest["sources"][source_file]["sha256"]:
            raise ValueError(f"live/source PNG changed: {name}")
    return manifest, captures


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    opts = parser.parse_args()
    manifest, captures = validate_source_renderer()
    screenshots_hash = digest(CAPTURES)
    root = json.loads(INVENTORIES[0].read_text(encoding="utf-8"))
    authoritative = {item["stable_asset_id"]: item for item in root["assets"]}
    changes = {}
    for name in STATES:
        asset_id = f"asset:player/animations/player_body_{name}_sheet"
        item = authoritative[asset_id].copy()
        record = manifest["animations"][name]
        if item["classification"] not in ("EXISTS_NEEDS_REVISION", "ACCEPTED_DO_NOT_REGENERATE") or item["current_existing_asset"] != record["output"]:
            raise ValueError(f"unexpected player identity: {name}")
        expected_source_sha = manifest["sources"][record["source_file"]]["sha256"]
        if item["verified_evidence"]["source_sha256"] != expected_source_sha:
            raise ValueError(f"player source authority changed: {name}")
        original_evidence = item["verified_evidence"].copy()
        item["classification"] = "ACCEPTED_DO_NOT_REGENERATE"
        item["generation_revision_requirement"] = "NONE: preserve current live NEAREST V03 sheet and Inspector AnimationLibrary; no source regeneration or R2 replacement"
        item["current_implementation_status"] = "Source-exact clean V03 NEAREST sheet is already live; native Godot 84-page all-class/right-left/body+equipment renderer validation passed"
        item["acceptance_scope"] = "Existing clean source/runtime/frame/equipment-layer evidence; no independent subjective glove/anatomical grip or style approval asserted"
        item["verified_evidence"] = {
            **original_evidence,
            "sha256": record["output_sha256"],
            "output_sha256": record["output_sha256"],
            "source_sha256": expected_source_sha,
            "source": "res://assets/art/generated_sources/imagegen/player/main_character_batches_v03/exact_sources/" + record["source_file"],
            "output_dimensions": record["output_dimensions"],
            "frame_count": record["frame_count"],
            "nearest_derivation_manifest": "res://docs/evidence/art/nearest_candidates/player_main_character_v03_nearest_derivation_manifest.json",
            "production_animation_library": "res://src/player/presentation/player_body_animation_library.tres",
            "production_animation_library_sha256": captures["production_library_sha256"],
            "real_renderer_evidence": "res://assets/art/player/animations/review_clean_v03_engine/clean_v03_real_renderer_evidence.json",
            "real_renderer_evidence_sha256": screenshots_hash,
            "real_renderer_page_count_all_states": 84,
            "real_renderer_source_pixel_verifier": "res://tools/art/check_player_clean_v03_real_renderer.py",
            "review_qualification": "Source pixel/equipment presence and nearest-grip proximity objectively verified; subjective anatomical grip not independently approved",
        }
        item["issues"] = []
        changes[asset_id] = item
    for inventory in INVENTORIES:
        before = inventory.read_bytes()
        text = before.decode("utf-8")
        current = {item["stable_asset_id"]: item for item in json.loads(text)["assets"]}
        for asset_id, item in changes.items():
            if current[asset_id]["current_existing_asset"] != item["current_existing_asset"]:
                raise ValueError(f"root/project player art path mismatch: {asset_id}")
            text = replace_object(text, asset_id, item)
        text, counts = corrected_counts(text)
        if opts.apply:
            if before != inventory.read_bytes():
                raise ValueError(f"concurrent inventory edit: {inventory}")
            temp = inventory.with_name(inventory.name + ".player-seven-tmp")
            temp.write_bytes(text.encode("utf-8"))
            os.replace(temp, inventory)
        print(f"{'UPDATED' if opts.apply else 'READY'} {inventory}: 7 clean V03 states source/runtime accepted; accepted={counts['ACCEPTED_DO_NOT_REGENERATE']} revision={counts['EXISTS_NEEDS_REVISION']}")


if __name__ == "__main__":
    main()
